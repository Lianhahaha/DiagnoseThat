#include "collectors/disk_health.hpp"

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>

// CI builds Release, where assert() is compiled out; fail loudly instead.
#define CHECK(condition)                                                  \
  do {                                                                    \
    if (!(condition)) {                                                   \
      std::cerr << __FILE__ << ":" << __LINE__ << " CHECK failed: "       \
                << #condition << "\n";                                    \
      std::exit(1);                                                       \
    }                                                                     \
  } while (false)

namespace {

using namespace pulse;

void SetCounter(UCHAR (&field)[16], uint64_t low, uint64_t high = 0) {
  std::memcpy(field, &low, sizeof(low));
  std::memcpy(field + 8, &high, sizeof(high));
}

/// A healthy drive like the Samsung SSD 980 read on the test PC.
NVME_HEALTH_INFO_LOG HealthyLog() {
  NVME_HEALTH_INFO_LOG log{};
  log.CriticalWarning.AsUchar = 0;
  const int kelvin = 34 + 273;
  log.Temperature[0] = static_cast<UCHAR>(kelvin & 0xFF);
  log.Temperature[1] = static_cast<UCHAR>(kelvin >> 8);
  log.AvailableSpare = 100;
  log.AvailableSpareThreshold = 10;
  log.PercentageUsed = 7;
  SetCounter(log.DataUnitRead, 2000);     // 2000 * 512 000 bytes
  SetCounter(log.DataUnitWritten, 4000);
  SetCounter(log.PowerOnHours, 5321);
  SetCounter(log.UnsafeShutdowns, 42);
  SetCounter(log.MediaErrors, 0);
  return log;
}

void TestHealthyNvmeLog() {
  ipc::HealthDiskHealth disk;
  ApplyNvmeHealthLog(HealthyLog(), &disk);
  CHECK(disk.has_critical_warning && disk.critical_warning == 0);
  CHECK(disk.has_failure_predicted && !disk.failure_predicted);
  CHECK(disk.has_temp_c && disk.temp_c == 34.0);
  CHECK(disk.has_percentage_used && disk.percentage_used == 7);
  CHECK(disk.has_available_spare && disk.available_spare == 100 &&
        disk.available_spare_threshold == 10);
  CHECK(disk.has_power_on_hours && disk.power_on_hours == 5321);
  CHECK(disk.has_unsafe_shutdowns && disk.unsafe_shutdowns == 42);
  CHECK(disk.has_media_errors && disk.media_errors == 0);
  CHECK(disk.has_bytes_read && disk.bytes_read == 2000ULL * 512000ULL);
  CHECK(disk.has_bytes_written && disk.bytes_written == 4000ULL * 512000ULL);
}

void TestCriticalWarningMeansFailurePredicted() {
  NVME_HEALTH_INFO_LOG log = HealthyLog();
  log.CriticalWarning.AsUchar = 0x01;  // available spare below threshold
  log.AvailableSpare = 5;
  ipc::HealthDiskHealth disk;
  ApplyNvmeHealthLog(log, &disk);
  CHECK(disk.failure_predicted);
  CHECK(disk.critical_warning == 0x01);
}

void TestTemperatureFromPropertyWins() {
  // StorageDeviceTemperatureProperty is read first; the log does not
  // overwrite it.
  ipc::HealthDiskHealth disk;
  disk.has_temp_c = true;
  disk.temp_c = 40.0;
  ApplyNvmeHealthLog(HealthyLog(), &disk);
  CHECK(disk.temp_c == 40.0);
}

void TestUnreportedTemperatureStaysUnset() {
  NVME_HEALTH_INFO_LOG log = HealthyLog();
  log.Temperature[0] = 0;
  log.Temperature[1] = 0;
  ipc::HealthDiskHealth disk;
  ApplyNvmeHealthLog(log, &disk);
  CHECK(!disk.has_temp_c);
}

void TestCountersTooLargeForUint64AreLeftUnset() {
  NVME_HEALTH_INFO_LOG log = HealthyLog();
  SetCounter(log.PowerOnHours, 1, 1);
  SetCounter(log.DataUnitWritten, UINT64_MAX);  // would overflow in bytes
  ipc::HealthDiskHealth disk;
  ApplyNvmeHealthLog(log, &disk);
  CHECK(!disk.has_power_on_hours);
  CHECK(!disk.has_bytes_written);
  CHECK(disk.has_bytes_read);
}

void TestBusNames() {
  CHECK(std::string(StorageBusName(BusTypeNvme)) == "NVMe");
  CHECK(std::string(StorageBusName(BusTypeSata)) == "SATA");
  CHECK(std::string(StorageBusName(BusTypeUsb)) == "USB");
  CHECK(std::string(StorageBusName(BusTypeUnknown)) == "Other");
}

void TestWireRoundTrip() {
  ipc::HealthSample sample;
  ipc::HealthDiskHealth nvme;
  nvme.index = 2;
  nvme.model = "Samsung SSD 980 500GB";
  nvme.bus = "NVMe";
  ApplyNvmeHealthLog(HealthyLog(), &nvme);
  ipc::HealthDiskHealth sata;
  sata.index = 0;
  sata.model = "MSI S270 480GB";
  sata.bus = "SATA";
  sata.has_temp_c = true;
  sata.temp_c = 50.0;
  sata.has_failure_predicted = true;
  sata.failure_predicted = false;
  sample.disk_health = {sata, nvme};

  ipc::HealthUpdate update;
  update.sample = sample;
  ipc::Envelope envelope;
  envelope.body = update;
  std::vector<uint8_t> bytes;
  CHECK(ipc::EncodeEnvelope(envelope, &bytes));
  ipc::Envelope decoded;
  CHECK(ipc::DecodeEnvelope(bytes.data(), bytes.size(), &decoded));
  const auto& back = std::get<ipc::HealthUpdate>(decoded.body).sample;
  CHECK(back.disk_health.size() == 2);
  CHECK(back.disk_health[0].model == "MSI S270 480GB");
  CHECK(!back.disk_health[0].has_percentage_used);
  CHECK(back.disk_health[1].index == 2);
  CHECK(back.disk_health[1].bus == "NVMe");
  CHECK(back.disk_health[1].percentage_used == 7);
  CHECK(back.disk_health[1].power_on_hours == 5321);
  CHECK(back.disk_health[1].bytes_written == 4000ULL * 512000ULL);
}

}  // namespace

int main() {
  TestHealthyNvmeLog();
  TestCriticalWarningMeansFailurePredicted();
  TestTemperatureFromPropertyWins();
  TestUnreportedTemperatureStaysUnset();
  TestCountersTooLargeForUint64AreLeftUnset();
  TestBusNames();
  TestWireRoundTrip();
  std::cout << "disk_health_tests passed\n";
  return 0;
}
