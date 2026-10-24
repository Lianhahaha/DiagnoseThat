#include "collectors/disk_health.hpp"

#include <cstdint>
#include <cstring>
#include <string>

namespace pulse {
namespace {

constexpr int kMaxPhysicalDrives = 16;
/// Stop scanning after this many missing drive numbers in a row.
constexpr int kMaxConsecutiveMisses = 4;
constexpr DWORD kDescriptorBufferBytes = 1024;
constexpr DWORD kTemperatureBufferBytes = 512;
constexpr int kKelvinOffset = 273;
constexpr int kTempMinC = -40;
constexpr int kTempMaxC = 125;
/// NVMe "data units" are thousands of 512-byte blocks.
constexpr uint64_t kBytesPerDataUnit = 1000ULL * 512ULL;

HANDLE OpenDriveForQueries(int index) {
  wchar_t path[64];
  swprintf_s(path, L"\\\\.\\PhysicalDrive%d", index);
  // Desired access 0: enough for the queries below, and allowed for
  // non-administrator accounts such as LocalService.
  return CreateFileW(path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                     OPEN_EXISTING, 0, nullptr);
}

/// Little-endian 128-bit NVMe counter; false when it does not fit in 64 bits.
bool ReadNvmeCounter(const UCHAR bytes[16], uint64_t* out) {
  uint64_t low = 0;
  uint64_t high = 0;
  std::memcpy(&low, bytes, sizeof(low));
  std::memcpy(&high, bytes + 8, sizeof(high));
  if (high != 0) {
    return false;
  }
  *out = low;
  return true;
}

std::string TrimmedAscii(const char* text) {
  std::string value(text);
  const auto first = value.find_first_not_of(' ');
  if (first == std::string::npos) {
    return {};
  }
  const auto last = value.find_last_not_of(' ');
  return value.substr(first, last - first + 1);
}

void ReadDescriptor(HANDLE disk, ipc::HealthDiskHealth* out) {
  STORAGE_PROPERTY_QUERY query{};
  query.PropertyId = StorageDeviceProperty;
  query.QueryType = PropertyStandardQuery;
  std::vector<BYTE> buffer(kDescriptorBufferBytes, 0);
  DWORD returned = 0;
  if (!DeviceIoControl(disk, IOCTL_STORAGE_QUERY_PROPERTY, &query,
                       sizeof(query), buffer.data(),
                       static_cast<DWORD>(buffer.size()), &returned, nullptr) ||
      returned < sizeof(STORAGE_DEVICE_DESCRIPTOR)) {
    return;
  }
  const auto* descriptor =
      reinterpret_cast<const STORAGE_DEVICE_DESCRIPTOR*>(buffer.data());
  const auto string_at = [&](DWORD offset) -> std::string {
    if (offset == 0 || offset >= returned) {
      return {};
    }
    // The descriptor's strings are NUL-terminated inside the buffer.
    buffer.back() = 0;
    return TrimmedAscii(reinterpret_cast<const char*>(buffer.data() + offset));
  };
  const std::string vendor = string_at(descriptor->VendorIdOffset);
  const std::string product = string_at(descriptor->ProductIdOffset);
  out->model = (!vendor.empty() && product.find(vendor) == std::string::npos)
                   ? vendor + " " + product
                   : product;
  out->bus = StorageBusName(descriptor->BusType);
}

void ReadTemperature(HANDLE disk, ipc::HealthDiskHealth* out) {
  STORAGE_PROPERTY_QUERY query{};
  query.PropertyId = StorageDeviceTemperatureProperty;
  query.QueryType = PropertyStandardQuery;
  std::vector<BYTE> buffer(kTemperatureBufferBytes, 0);
  DWORD returned = 0;
  if (!DeviceIoControl(disk, IOCTL_STORAGE_QUERY_PROPERTY, &query,
                       sizeof(query), buffer.data(),
                       static_cast<DWORD>(buffer.size()), &returned, nullptr)) {
    return;
  }
  const auto* descriptor =
      reinterpret_cast<const STORAGE_TEMPERATURE_DATA_DESCRIPTOR*>(
          buffer.data());
  const DWORD needed =
      offsetof(STORAGE_TEMPERATURE_DATA_DESCRIPTOR, TemperatureInfo) +
      sizeof(STORAGE_TEMPERATURE_INFO);
  if (returned < needed || descriptor->InfoCount == 0) {
    return;
  }
  // Index 0 is the device's composite temperature.
  const SHORT celsius = descriptor->TemperatureInfo[0].Temperature;
  if (celsius >= kTempMinC && celsius <= kTempMaxC) {
    out->has_temp_c = true;
    out->temp_c = static_cast<double>(celsius);
  }
}

bool ReadNvmeHealthLog(HANDLE disk, ipc::HealthDiskHealth* out) {
  // One buffer for the query, the protocol data and the log page (Microsoft
  // "Working with NVMe drives" pattern).
  constexpr DWORD kLogSize = sizeof(NVME_HEALTH_INFO_LOG);
  const DWORD buffer_length =
      FIELD_OFFSET(STORAGE_PROPERTY_QUERY, AdditionalParameters) +
      sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA) + kLogSize;
  std::vector<BYTE> buffer(buffer_length, 0);
  auto* query = reinterpret_cast<STORAGE_PROPERTY_QUERY*>(buffer.data());
  auto* request = reinterpret_cast<STORAGE_PROTOCOL_SPECIFIC_DATA*>(
      query->AdditionalParameters);
  query->PropertyId = StorageDeviceProtocolSpecificProperty;
  query->QueryType = PropertyStandardQuery;
  request->ProtocolType = ProtocolTypeNvme;
  request->DataType = NVMeDataTypeLogPage;
  request->ProtocolDataRequestValue = NVME_LOG_PAGE_HEALTH_INFO;
  request->ProtocolDataOffset = sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA);
  request->ProtocolDataLength = kLogSize;

  DWORD returned = 0;
  if (!DeviceIoControl(disk, IOCTL_STORAGE_QUERY_PROPERTY, buffer.data(),
                       buffer_length, buffer.data(), buffer_length, &returned,
                       nullptr) ||
      returned < sizeof(STORAGE_PROTOCOL_DATA_DESCRIPTOR)) {
    return false;
  }
  const auto* descriptor =
      reinterpret_cast<const STORAGE_PROTOCOL_DATA_DESCRIPTOR*>(buffer.data());
  if (descriptor->Version != sizeof(STORAGE_PROTOCOL_DATA_DESCRIPTOR) ||
      descriptor->Size != sizeof(STORAGE_PROTOCOL_DATA_DESCRIPTOR)) {
    return false;
  }
  const auto* data = &descriptor->ProtocolSpecificData;
  if (data->ProtocolDataOffset < sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA) ||
      data->ProtocolDataLength < kLogSize ||
      FIELD_OFFSET(STORAGE_PROTOCOL_DATA_DESCRIPTOR, ProtocolSpecificData) +
              data->ProtocolDataOffset + kLogSize >
          returned) {
    return false;
  }
  const auto* log = reinterpret_cast<const NVME_HEALTH_INFO_LOG*>(
      reinterpret_cast<const BYTE*>(data) + data->ProtocolDataOffset);
  ApplyNvmeHealthLog(*log, out);
  return true;
}

void ReadPredictFailure(HANDLE disk, ipc::HealthDiskHealth* out) {
  STORAGE_PREDICT_FAILURE predict{};
  DWORD returned = 0;
  if (!DeviceIoControl(disk, IOCTL_STORAGE_PREDICT_FAILURE, nullptr, 0,
                       &predict, sizeof(predict), &returned, nullptr) ||
      returned < sizeof(predict.PredictFailure)) {
    return;
  }
  out->has_failure_predicted = true;
  out->failure_predicted = predict.PredictFailure != 0;
}

}  // namespace

const char* StorageBusName(STORAGE_BUS_TYPE bus) {
  switch (bus) {
    case BusTypeNvme:
      return "NVMe";
    case BusTypeSata:
      return "SATA";
    case BusTypeAta:
      return "ATA";
    case BusTypeUsb:
      return "USB";
    case BusTypeSas:
      return "SAS";
    case BusTypeScsi:
      return "SCSI";
    case BusTypeRAID:
      return "RAID";
    case BusTypeSd:
      return "SD";
    case BusTypeMmc:
      return "MMC";
    case BusTypeVirtual:
    case BusTypeFileBackedVirtual:
      return "Virtual";
    case BusTypeSpaces:
      return "Storage Spaces";
    default:
      return "Other";
  }
}

void ApplyNvmeHealthLog(const NVME_HEALTH_INFO_LOG& log,
                        ipc::HealthDiskHealth* out) {
  out->has_critical_warning = true;
  out->critical_warning = log.CriticalWarning.AsUchar;
  out->has_failure_predicted = true;
  out->failure_predicted = log.CriticalWarning.AsUchar != 0;

  out->has_percentage_used = true;
  out->percentage_used = log.PercentageUsed;
  out->has_available_spare = true;
  out->available_spare = log.AvailableSpare;
  out->available_spare_threshold = log.AvailableSpareThreshold;

  if (!out->has_temp_c) {
    const int kelvin = static_cast<int>(log.Temperature[0]) |
                       (static_cast<int>(log.Temperature[1]) << 8);
    const int celsius = kelvin - kKelvinOffset;
    if (kelvin != 0 && celsius >= kTempMinC && celsius <= kTempMaxC) {
      out->has_temp_c = true;
      out->temp_c = static_cast<double>(celsius);
    }
  }

  uint64_t value = 0;
  if (ReadNvmeCounter(log.PowerOnHours, &value)) {
    out->has_power_on_hours = true;
    out->power_on_hours = value;
  }
  if (ReadNvmeCounter(log.UnsafeShutdowns, &value)) {
    out->has_unsafe_shutdowns = true;
    out->unsafe_shutdowns = value;
  }
  if (ReadNvmeCounter(log.MediaErrors, &value)) {
    out->has_media_errors = true;
    out->media_errors = value;
  }
  if (ReadNvmeCounter(log.DataUnitRead, &value) &&
      value <= UINT64_MAX / kBytesPerDataUnit) {
    out->has_bytes_read = true;
    out->bytes_read = value * kBytesPerDataUnit;
  }
  if (ReadNvmeCounter(log.DataUnitWritten, &value) &&
      value <= UINT64_MAX / kBytesPerDataUnit) {
    out->has_bytes_written = true;
    out->bytes_written = value * kBytesPerDataUnit;
  }
}

std::vector<ipc::HealthDiskHealth> ReadDiskHealth() {
  std::vector<ipc::HealthDiskHealth> disks;
  int misses = 0;
  for (int index = 0; index < kMaxPhysicalDrives; ++index) {
    HANDLE disk = OpenDriveForQueries(index);
    if (disk == INVALID_HANDLE_VALUE) {
      // Drive numbers can have gaps (a removed USB disk).
      if (++misses >= kMaxConsecutiveMisses) {
        break;
      }
      continue;
    }
    misses = 0;
    ipc::HealthDiskHealth health;
    health.index = static_cast<uint32_t>(index);
    ReadDescriptor(disk, &health);
    ReadTemperature(disk, &health);
    if (!ReadNvmeHealthLog(disk, &health)) {
      ReadPredictFailure(disk, &health);
    }
    CloseHandle(disk);
    disks.push_back(std::move(health));
  }
  return disks;
}

}  // namespace pulse
