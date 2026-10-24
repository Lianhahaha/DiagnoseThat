#include "collectors/hardware_sensors_collector.hpp"

#include "collectors/disk_health.hpp"

#include <chrono>
#include <mutex>
#include <vector>

namespace pulse {
namespace {

/// Disk health changes slowly. Querying it once a second would also keep
/// asking every drive, including hard disks that may be spun down, so the
/// result is cached and refreshed at this interval.
constexpr std::chrono::minutes kDiskHealthRefresh{5};

struct DiskHealthCache {
  std::mutex mutex;
  bool loaded = false;
  std::chrono::steady_clock::time_point read_at;
  std::vector<ipc::HealthDiskHealth> disks;
};

std::vector<ipc::HealthDiskHealth> CachedDiskHealth() {
  static DiskHealthCache cache;
  std::lock_guard lock(cache.mutex);
  const auto now = std::chrono::steady_clock::now();
  if (!cache.loaded || now - cache.read_at >= kDiskHealthRefresh) {
    cache.disks = ReadDiskHealth();
    cache.read_at = now;
    cache.loaded = true;
  }
  return cache.disks;
}

/// Older clients and the System Health overview read single-disk fields;
/// fill them from the per-disk list. SMART is OK only when no disk predicts a
/// failure, so a warning on any disk shows. Lifetime totals come from the
/// first disk, the temperature from the first disk that reports one.
void FillSingleDiskFields(const std::vector<ipc::HealthDiskHealth>& disks,
                          ipc::HealthSample* out) {
  for (const auto& disk : disks) {
    if (!out->has_ssd_temp_c && disk.has_temp_c) {
      out->has_ssd_temp_c = true;
      out->ssd_temp_c = disk.temp_c;
    }
    if (disk.has_failure_predicted) {
      out->disk_smart_ok = out->has_disk_smart_ok
                               ? out->disk_smart_ok && !disk.failure_predicted
                               : !disk.failure_predicted;
      out->has_disk_smart_ok = true;
    }
  }
  if (disks.empty()) {
    return;
  }
  const auto& first = disks.front();
  if (first.has_power_on_hours) {
    out->has_disk_power_on_hours = true;
    out->disk_power_on_hours = first.power_on_hours;
  }
  if (first.has_bytes_read) {
    out->has_disk_total_bytes_read = true;
    out->disk_total_bytes_read = first.bytes_read;
  }
  if (first.has_bytes_written) {
    out->has_disk_total_bytes_written = true;
    out->disk_total_bytes_written = first.bytes_written;
  }
}

}  // namespace

void SampleHardwareSensors(ipc::HealthSample* out) {
  if (out == nullptr) return;

  // CPU package temperature: intentionally unset.
  // CallNtPowerInformation thermal levels and ACPI thermal-zone enumeration
  // are not reliable public userspace package-temp sources without vendor
  // APIs / WMI heuristics. Prefer honest Not supported.

  // Motherboard / chassis fans: no documented Win32 path without vendor SDKs.
  // GPU FanRPM remains via SampleGpuD3dkmtTelemetry when the driver reports it.

  out->disk_health = CachedDiskHealth();
  FillSingleDiskFields(out->disk_health, out);
}

}  // namespace pulse
