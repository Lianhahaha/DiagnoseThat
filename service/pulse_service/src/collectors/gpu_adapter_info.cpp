#include "collectors/gpu_adapter_info.hpp"

#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>
#include <winternl.h>  // NTSTATUS for d3dkmthk.h under WIN32_LEAN_AND_MEAN

#include <Pdh.h>
#include <PdhMsg.h>
#include <SetupAPI.h>
#include <d3d12.h>
#include <d3dkmthk.h>
#include <dxgi.h>
#include <initguid.h>
#include <devguid.h>
#include <devpkey.h>
#include <pciprop.h>

#include <algorithm>
#include <cstdio>
#include <iomanip>
#include <sstream>
#include <vector>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "d3d12.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "setupapi.lib")

// Read-only sources for this module (see gpu_adapter_info.hpp):
//   - DXGI (CreateDXGIFactory1 / IDXGIAdapter1) for identity + VRAM capacity.
//   - Registry (Class GUID + GraphicsDrivers) for driver + HW scheduling.
//   - D3D12CreateDevice(..., ppDevice = nullptr) to probe max feature level
//     without ever creating a device.
//   - D3DKMT (d3dkmthk.h / gdi32) for WDDM version, PCI location, and live
//     adapter/node perf telemetry when the driver exposes non-zero values.
//   - SetupAPI + pciprop.h for current PCIe link speed/width (matched by
//     display-adapter description to the DXGI model).
//   - PDH "\GPU Engine(*)\Utilization Percentage" for per-engine live load.
// Resizable BAR has no reliable public Win32 detection path — left unset.
// Live VRAM usage is sampled elsewhere (health_metrics_collector PDH path).

namespace pulse {
namespace {

constexpr NTSTATUS kNtStatusSuccess = 0;

std::string NarrowFromWide(const wchar_t* wide) {
  if (wide == nullptr || wide[0] == L'\0') return {};
  const int needed =
      WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (needed <= 1) return {};
  std::string out(static_cast<size_t>(needed - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, out.data(), needed, nullptr,
                      nullptr);
  return out;
}

std::string AsciiUpperCopy(std::string s) {
  for (char& c : s) {
    if (c >= 'a' && c <= 'z') c = static_cast<char>(c - 'a' + 'A');
  }
  return s;
}

bool AsciiContainsIgnoreCase(const std::string& haystack,
                             const std::string& needle) {
  if (haystack.empty() || needle.empty()) return false;
  return AsciiUpperCopy(haystack).find(AsciiUpperCopy(needle)) !=
         std::string::npos;
}

bool ReadRegistryStringValue(HKEY root, const std::wstring& subkey,
                             const wchar_t* value, std::wstring* out) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(root, subkey.c_str(), 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  wchar_t buffer[512]{};
  DWORD type = 0;
  DWORD size = sizeof(buffer);
  const LONG rc = RegQueryValueExW(key, value, nullptr, &type,
                                   reinterpret_cast<LPBYTE>(buffer), &size);
  RegCloseKey(key);
  if (rc != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ)) {
    return false;
  }
  *out = buffer;
  return true;
}

bool ReadRegistryDwordValue(HKEY root, const std::wstring& subkey,
                            const wchar_t* value, DWORD* out) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(root, subkey.c_str(), 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  DWORD data = 0;
  DWORD type = 0;
  DWORD size = sizeof(data);
  const LONG rc = RegQueryValueExW(key, value, nullptr, &type,
                                   reinterpret_cast<LPBYTE>(&data), &size);
  RegCloseKey(key);
  if (rc != ERROR_SUCCESS || type != REG_DWORD) return false;
  *out = data;
  return true;
}

/// Re-enumerate DXGI adapters to find the one matching a previously
/// selected LUID. Returns an AddRef'd adapter (caller must Release), or
/// nullptr if not found.
IDXGIAdapter1* FindDxgiAdapterByLuid(int32_t luid_high, uint32_t luid_low) {
  IDXGIFactory1* factory = nullptr;
  if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                reinterpret_cast<void**>(&factory))) ||
      factory == nullptr) {
    return nullptr;
  }

  IDXGIAdapter1* found = nullptr;
  for (UINT i = 0;; ++i) {
    IDXGIAdapter1* adapter = nullptr;
    const HRESULT hr = factory->EnumAdapters1(i, &adapter);
    if (hr == DXGI_ERROR_NOT_FOUND || adapter == nullptr) break;

    DXGI_ADAPTER_DESC1 desc{};
    if (SUCCEEDED(adapter->GetDesc1(&desc)) &&
        desc.AdapterLuid.HighPart == luid_high &&
        static_cast<uint32_t>(desc.AdapterLuid.LowPart) == luid_low) {
      found = adapter;
      break;
    }
    adapter->Release();
  }
  factory->Release();
  return found;
}

/// Probe the highest D3D feature level the adapter supports without ever
/// creating a device (ppDevice == nullptr is a documented support-only
/// query for D3D12CreateDevice).
std::string DetectDirectXVersion(const GpuAdapterSelection& adapter) {
  IDXGIAdapter1* matched = nullptr;
  if (adapter.has_luid) {
    matched = FindDxgiAdapterByLuid(adapter.luid_high, adapter.luid_low);
  }

  struct LevelName {
    D3D_FEATURE_LEVEL level;
    const char* name;
  };
  const LevelName levels[] = {
#if defined(D3D_FEATURE_LEVEL_12_2)
      {D3D_FEATURE_LEVEL_12_2, "12_2"},
#endif
      {D3D_FEATURE_LEVEL_12_1, "12_1"},
      {D3D_FEATURE_LEVEL_12_0, "12_0"},
      {D3D_FEATURE_LEVEL_11_1, "11_1"},
      {D3D_FEATURE_LEVEL_11_0, "11_0"},
  };

  std::string result;
  IUnknown* target = matched;
  for (const auto& lvl : levels) {
    if (SUCCEEDED(D3D12CreateDevice(target, lvl.level,
                                    __uuidof(ID3D12Device), nullptr))) {
      result = lvl.name;
      break;
    }
  }

  if (matched != nullptr) matched->Release();
  return result;
}

/// Registry-only driver identification. Class GUID {4d36e968-...} is the
/// documented "Display adapters" device setup class; instance subkeys are
/// decimal "0000".."0016". Matches by DriverDesc containing (or contained
/// by) the DXGI adapter description — never guessed if the model is empty.
void EnrichGpuDriverInfo(const GpuAdapterSelection& adapter,
                         ipc::HealthStaticInfo* info) {
  if (adapter.model.empty()) return;

  static constexpr wchar_t kDisplayClassGuid[] =
      L"{4d36e968-e325-11ce-bfc1-08002be10318}";

  for (unsigned i = 0; i <= 16; ++i) {
    wchar_t subkey[256]{};
    swprintf_s(subkey,
               L"SYSTEM\\CurrentControlSet\\Control\\Class\\%s\\%04u",
               kDisplayClassGuid, i);

    std::wstring driver_desc_w;
    if (!ReadRegistryStringValue(HKEY_LOCAL_MACHINE, subkey, L"DriverDesc",
                                 &driver_desc_w)) {
      continue;
    }
    const std::string driver_desc = NarrowFromWide(driver_desc_w.c_str());
    if (driver_desc.empty()) continue;

    const bool matches =
        AsciiContainsIgnoreCase(driver_desc, adapter.model) ||
        AsciiContainsIgnoreCase(adapter.model, driver_desc);
    if (!matches) continue;

    std::wstring version_w;
    if (ReadRegistryStringValue(HKEY_LOCAL_MACHINE, subkey, L"DriverVersion",
                                &version_w)) {
      info->gpu_driver_version = NarrowFromWide(version_w.c_str());
    }
    std::wstring date_w;
    if (ReadRegistryStringValue(HKEY_LOCAL_MACHINE, subkey, L"DriverDate",
                                &date_w)) {
      info->gpu_driver_date = NarrowFromWide(date_w.c_str());
    }
    break;
  }
}

void EnrichGpuHardwareScheduling(ipc::HealthStaticInfo* info) {
  DWORD hw_sch_mode = 0;
  if (ReadRegistryDwordValue(HKEY_LOCAL_MACHINE,
                             L"SYSTEM\\CurrentControlSet\\Control\\"
                             L"GraphicsDrivers",
                             L"HwSchMode", &hw_sch_mode)) {
    info->has_gpu_hardware_scheduling = true;
    info->gpu_hardware_scheduling = (hw_sch_mode == 2);
  }
}

bool OpenAdapterFromLuid(const GpuAdapterSelection& adapter,
                         D3DKMT_HANDLE* out_handle) {
  if (!adapter.has_luid || out_handle == nullptr) return false;

  D3DKMT_OPENADAPTERFROMLUID open{};
  open.AdapterLuid.HighPart = adapter.luid_high;
  open.AdapterLuid.LowPart = static_cast<LONG>(adapter.luid_low);

  const NTSTATUS status = D3DKMTOpenAdapterFromLuid(&open);
  if (status != kNtStatusSuccess || open.hAdapter == 0) return false;

  *out_handle = open.hAdapter;
  return true;
}

void CloseAdapterHandle(D3DKMT_HANDLE handle) {
  if (handle == 0) return;
  D3DKMT_CLOSEADAPTER close{};
  close.hAdapter = handle;
  D3DKMTCloseAdapter(&close);
}

/// WDDM version + PCI bus location via D3DKMT when the adapter LUID is known.
void EnrichGpuD3dkmtStatic(const GpuAdapterSelection& adapter,
                           ipc::HealthStaticInfo* info) {
  if (!adapter.has_luid || info == nullptr) return;

  D3DKMT_HANDLE h_adapter = 0;
  if (!OpenAdapterFromLuid(adapter, &h_adapter)) return;

  D3DKMT_DRIVERVERSION driver_version{};
  D3DKMT_QUERYADAPTERINFO query{};
  query.hAdapter = h_adapter;
  query.Type = KMTQAITYPE_DRIVERVERSION;
  query.pPrivateDriverData = &driver_version;
  query.PrivateDriverDataSize = sizeof(driver_version);
  if (D3DKMTQueryAdapterInfo(&query) == kNtStatusSuccess) {
    const std::string formatted =
        FormatWddmVersion(static_cast<int>(driver_version));
    if (!formatted.empty()) info->gpu_wddm_version = formatted;
  }

  D3DKMT_ADAPTERADDRESS address{};
  query = {};
  query.hAdapter = h_adapter;
  query.Type = KMTQAITYPE_ADAPTERADDRESS;
  query.pPrivateDriverData = &address;
  query.PrivateDriverDataSize = sizeof(address);
  if (D3DKMTQueryAdapterInfo(&query) == kNtStatusSuccess) {
    char location[64]{};
    sprintf_s(location, "PCI %u:%u.%u", address.BusNumber, address.DeviceNumber,
              address.FunctionNumber);
    info->gpu_pci_location = location;
  }

  CloseAdapterHandle(h_adapter);

  // has_gpu_resizable_bar left unset: there is no reliable public Win32 /
  // SetupAPI / D3DKMT property for Resizable BAR detection without vendor
  // SDKs or undocumented paths.
}

std::string FormatPcieLinkSpeed(ULONG speed_code) {
  switch (speed_code) {
    case 1:
      return "Gen1 (2.5 GT/s)";
    case 2:
      return "Gen2 (5.0 GT/s)";
    case 3:
      return "Gen3 (8.0 GT/s)";
    case 4:
      return "Gen4 (16.0 GT/s)";
    case 5:
      return "Gen5 (32.0 GT/s)";
    case 6:
      return "Gen6 (64.0 GT/s)";
    default:
      break;
  }
  return {};
}

/// Match a present display-class device to the DXGI model description and
/// read current PCIe link speed/width. Leaves fields empty on any failure.
void EnrichGpuPcieLinkInfo(const GpuAdapterSelection& adapter,
                           ipc::HealthStaticInfo* info) {
  if (adapter.model.empty() || info == nullptr) return;

  const HDEVINFO devs = SetupDiGetClassDevsW(
      &GUID_DEVCLASS_DISPLAY, nullptr, nullptr, DIGCF_PRESENT);
  if (devs == INVALID_HANDLE_VALUE) return;

  SP_DEVINFO_DATA device_info{};
  device_info.cbSize = sizeof(device_info);

  for (DWORD index = 0; SetupDiEnumDeviceInfo(devs, index, &device_info);
       ++index) {
    wchar_t description[512]{};
    if (!SetupDiGetDeviceRegistryPropertyW(
            devs, &device_info, SPDRP_DEVICEDESC, nullptr,
            reinterpret_cast<PBYTE>(description), sizeof(description),
            nullptr)) {
      continue;
    }

    const std::string desc = NarrowFromWide(description);
    if (desc.empty()) continue;
    const bool matches = AsciiContainsIgnoreCase(desc, adapter.model) ||
                         AsciiContainsIgnoreCase(adapter.model, desc);
    if (!matches) continue;

    DEVPROPTYPE prop_type = 0;
    ULONG link_speed = 0;
    if (SetupDiGetDevicePropertyW(
            devs, &device_info, &DEVPKEY_PciDevice_CurrentLinkSpeed, &prop_type,
            reinterpret_cast<PBYTE>(&link_speed), sizeof(link_speed), nullptr,
            0) &&
        prop_type == DEVPROP_TYPE_UINT32 && link_speed > 0) {
      const std::string speed = FormatPcieLinkSpeed(link_speed);
      if (!speed.empty()) info->gpu_pcie_link_speed = speed;
    }

    prop_type = 0;
    ULONG link_width = 0;
    if (SetupDiGetDevicePropertyW(
            devs, &device_info, &DEVPKEY_PciDevice_CurrentLinkWidth, &prop_type,
            reinterpret_cast<PBYTE>(&link_width), sizeof(link_width), nullptr,
            0) &&
        prop_type == DEVPROP_TYPE_UINT32 && link_width > 0) {
      char width_buf[16]{};
      sprintf_s(width_buf, "x%u", link_width);
      info->gpu_pcie_link_width = width_buf;
    }

    break;
  }

  SetupDiDestroyDeviceInfoList(devs);
}

GpuAdapterSelection SelectionFromDesc(const DXGI_ADAPTER_DESC1& desc) {
  GpuAdapterSelection sel;
  sel.model = NarrowFromWide(desc.Description);
  sel.vendor = GpuVendorNameFromPciId(desc.VendorId);
  sel.dedicated_bytes = desc.DedicatedVideoMemory;
  sel.shared_bytes = desc.SharedSystemMemory;
  sel.has_luid = true;
  sel.luid_high = desc.AdapterLuid.HighPart;
  sel.luid_low = static_cast<uint32_t>(desc.AdapterLuid.LowPart);
  sel.luid_pdh_token = GpuLuidToken(sel.luid_high, sel.luid_low);
  return sel;
}

}  // namespace

GpuAdapterSelection QueryPrimaryGpuAdapter() {
  GpuAdapterSelection sel;

  IDXGIFactory1* factory = nullptr;
  if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                reinterpret_cast<void**>(&factory))) ||
      factory == nullptr) {
    return sel;
  }

  bool have_preferred = false;
  DXGI_ADAPTER_DESC1 preferred_desc{};
  bool have_fallback = false;
  DXGI_ADAPTER_DESC1 fallback_desc{};

  for (UINT i = 0;; ++i) {
    IDXGIAdapter1* adapter = nullptr;
    const HRESULT hr = factory->EnumAdapters1(i, &adapter);
    if (hr == DXGI_ERROR_NOT_FOUND || adapter == nullptr) break;

    DXGI_ADAPTER_DESC1 desc{};
    if (SUCCEEDED(adapter->GetDesc1(&desc))) {
      if (!have_fallback) {
        fallback_desc = desc;
        have_fallback = true;
      }
      const bool is_software =
          (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0;
      if (!have_preferred && !is_software && desc.DedicatedVideoMemory > 0) {
        preferred_desc = desc;
        have_preferred = true;
      }
    }
    adapter->Release();
    if (have_preferred) break;
  }
  factory->Release();

  if (!have_preferred && !have_fallback) return sel;
  return SelectionFromDesc(have_preferred ? preferred_desc : fallback_desc);
}

std::vector<GpuAdapterSelection> QueryHardwareGpuAdapters() {
  std::vector<GpuAdapterSelection> adapters;
  IDXGIFactory1* factory = nullptr;
  if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                reinterpret_cast<void**>(&factory))) ||
      factory == nullptr) {
    return adapters;
  }
  for (UINT i = 0;; ++i) {
    IDXGIAdapter1* adapter = nullptr;
    const HRESULT hr = factory->EnumAdapters1(i, &adapter);
    if (hr == DXGI_ERROR_NOT_FOUND || adapter == nullptr) break;
    DXGI_ADAPTER_DESC1 desc{};
    if (SUCCEEDED(adapter->GetDesc1(&desc)) &&
        (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) == 0) {
      adapters.push_back(SelectionFromDesc(desc));
    }
    adapter->Release();
  }
  factory->Release();
  return adapters;
}

std::string GpuVendorNameFromPciId(uint32_t vendor_id) {
  switch (vendor_id) {
    case 0x10DE:
      return "NVIDIA";
    case 0x1002:
      return "AMD";
    case 0x8086:
      return "Intel";
    default:
      break;
  }
  if (vendor_id == 0) return {};
  std::ostringstream oss;
  oss << "PCI 0x" << std::hex << std::uppercase << std::setfill('0')
      << std::setw(4) << vendor_id;
  return oss.str();
}

std::string FormatWddmVersion(int driver_version_enum) {
  if (driver_version_enum <= 0) return {};

  // D3DKMT_DRIVERVERSION encodings: major*1000 + minor*100 (e.g. 3100 → 3.1).
  // 1105 / 1102 are the documented WDDM 1.1 values (non-round minor part).
  const int major = driver_version_enum / 1000;
  const int remainder = driver_version_enum % 1000;
  const bool known_shape =
      (remainder % 100 == 0) || driver_version_enum == 1105 ||
      driver_version_enum == 1102;
  if (major >= 1 && known_shape) {
    const int minor = remainder / 100;
    std::ostringstream oss;
    oss << major << '.' << minor;
    return oss.str();
  }

  return "WDDM " + std::to_string(driver_version_enum);
}

void EnrichGpuStaticInfo(const GpuAdapterSelection& adapter,
                         ipc::HealthStaticInfo* info) {
  if (info == nullptr) return;

  if (!adapter.model.empty()) info->gpu_model = adapter.model;
  if (!adapter.vendor.empty()) info->gpu_vendor = adapter.vendor;
  if (adapter.dedicated_bytes > 0) {
    info->gpu_dedicated_bytes = adapter.dedicated_bytes;
  }
  if (adapter.shared_bytes > 0) info->gpu_shared_bytes = adapter.shared_bytes;
  if (adapter.has_luid) {
    info->has_gpu_luid = true;
    info->gpu_luid_high = adapter.luid_high;
    info->gpu_luid_low = adapter.luid_low;
  }

  EnrichGpuDriverInfo(adapter, info);
  EnrichGpuHardwareScheduling(info);

  const std::string dx_version = DetectDirectXVersion(adapter);
  if (!dx_version.empty()) info->gpu_directx_version = dx_version;

  EnrichGpuD3dkmtStatic(adapter, info);
  EnrichGpuPcieLinkInfo(adapter, info);
}

void SampleGpuExtended(const GpuAdapterSelection& adapter,
                       const std::map<std::wstring, GpuAdapterLoad>& loads,
                       ipc::HealthSample* out) {
  if (out == nullptr || !adapter.has_luid) return;
  const auto found = loads.find(GpuLuidTokenOfInstance(adapter.luid_pdh_token));
  if (found == loads.end() || !found->second.has_overall) return;
  const GpuAdapterLoad& load = found->second;

  out->has_gpu_percent = true;
  out->gpu_percent = load.overall;
  out->has_gpu_util_3d = load.has_3d;
  out->gpu_util_3d = load.util_3d;
  out->has_gpu_util_compute = load.has_compute;
  out->gpu_util_compute = load.compute;
  out->has_gpu_util_copy = load.has_copy;
  out->gpu_util_copy = load.copy;
  out->has_gpu_util_video_decode = load.has_video_decode;
  out->gpu_util_video_decode = load.video_decode;
  out->has_gpu_util_video_encode = load.has_video_encode;
  out->gpu_util_video_encode = load.video_encode;
  out->has_gpu_util_video_processing = load.has_video_processing;
  out->gpu_util_video_processing = load.video_processing;
}

void SampleGpuD3dkmtTelemetry(const GpuAdapterSelection& adapter,
                              ipc::HealthSample* out) {
  if (out == nullptr || !adapter.has_luid) return;

  D3DKMT_HANDLE h_adapter = 0;
  if (!OpenAdapterFromLuid(adapter, &h_adapter)) return;

  D3DKMT_ADAPTER_PERFDATA adapter_perf{};
  adapter_perf.PhysicalAdapterIndex = 0;
  D3DKMT_QUERYADAPTERINFO query{};
  query.hAdapter = h_adapter;
  query.Type = KMTQAITYPE_ADAPTERPERFDATA;
  query.pPrivateDriverData = &adapter_perf;
  query.PrivateDriverDataSize = sizeof(adapter_perf);
  if (D3DKMTQueryAdapterInfo(&query) == kNtStatusSuccess) {
    if (adapter_perf.Temperature > 0) {
      out->has_gpu_temp_c = true;
      out->gpu_temp_c = static_cast<double>(adapter_perf.Temperature) / 10.0;
    }
    if (adapter_perf.FanRPM > 0) {
      out->has_gpu_fan_rpm = true;
      out->gpu_fan_rpm = static_cast<double>(adapter_perf.FanRPM);
    }
    if (adapter_perf.Power > 0) {
      out->has_gpu_power_percent = true;
      out->gpu_power_percent = static_cast<double>(adapter_perf.Power) / 10.0;
    }
    if (adapter_perf.MemoryFrequency > 0) {
      out->has_gpu_memory_clock_mhz = true;
      out->gpu_memory_clock_mhz =
          static_cast<double>(adapter_perf.MemoryFrequency) / 1e6;
    }
  }

  D3DKMT_NODE_PERFDATA node_perf{};
  node_perf.NodeOrdinal = 0;
  node_perf.PhysicalAdapterIndex = 0;
  query = {};
  query.hAdapter = h_adapter;
  query.Type = KMTQAITYPE_NODEPERFDATA;
  query.pPrivateDriverData = &node_perf;
  query.PrivateDriverDataSize = sizeof(node_perf);
  if (D3DKMTQueryAdapterInfo(&query) == kNtStatusSuccess &&
      node_perf.Frequency > 0) {
    out->has_gpu_clock_mhz = true;
    out->gpu_clock_mhz = static_cast<double>(node_perf.Frequency) / 1e6;
  }

  CloseAdapterHandle(h_adapter);
}

bool GpuInstanceMatchesLuid(const wchar_t* instance_name,
                            const std::wstring& luid_token) {
  if (instance_name == nullptr || luid_token.empty()) return false;

  std::wstring haystack(instance_name);
  std::wstring needle(luid_token);
  auto to_upper_ascii = [](wchar_t c) -> wchar_t {
    return (c >= L'a' && c <= L'z') ? static_cast<wchar_t>(c - L'a' + L'A')
                                    : c;
  };
  std::transform(haystack.begin(), haystack.end(), haystack.begin(),
                 to_upper_ascii);
  std::transform(needle.begin(), needle.end(), needle.begin(),
                 to_upper_ascii);
  return haystack.find(needle) != std::wstring::npos;
}

}  // namespace pulse
