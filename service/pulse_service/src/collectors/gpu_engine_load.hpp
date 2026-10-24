#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace pulse {

/// One PDH counter instance and its value, e.g.
/// "pid_1234_luid_0x00000000_0x0000F21B_phys_0_eng_0_engtype_3D" = 12.5.
struct GpuCounterValue {
  std::wstring instance;
  double value = 0.0;
};

/// Load of one GPU adapter, computed the way Task Manager does: an engine's
/// utilization is the sum over the processes using it, and the adapter's
/// utilization is that of its busiest engine. Per type (3D, Copy, ...) is
/// the busiest engine of that type. has_* is false when no engine of that
/// type reported a value.
struct GpuAdapterLoad {
  bool has_overall = false;
  double overall = 0.0;
  bool has_3d = false;
  double util_3d = 0.0;
  bool has_compute = false;
  double compute = 0.0;
  bool has_copy = false;
  double copy = 0.0;
  bool has_video_decode = false;
  double video_decode = 0.0;
  bool has_video_encode = false;
  double video_encode = 0.0;
  bool has_video_processing = false;
  double video_processing = 0.0;
};

/// "luid_0xHHHHHHHH_0xLLLLLLLL", the adapter part of PDH GPU instance names.
[[nodiscard]] std::wstring GpuLuidToken(int32_t luid_high, uint32_t luid_low);

/// The adapter token of a PDH GPU instance name, upper-cased so tokens from
/// different counters compare equal. Empty when the name has no LUID.
[[nodiscard]] std::wstring GpuLuidTokenOfInstance(const std::wstring& instance);

/// "\GPU Engine(*)\Utilization Percentage" values → load per adapter token
/// (upper-cased). Values are clamped to 0..100.
[[nodiscard]] std::map<std::wstring, GpuAdapterLoad> SumGpuEngineLoad(
    const std::vector<GpuCounterValue>& engines);

/// "\GPU Adapter Memory(*)\..." values → bytes per adapter token
/// (upper-cased), summed over the adapter's physical parts ("phys_N").
[[nodiscard]] std::map<std::wstring, uint64_t> SumGpuAdapterMemory(
    const std::vector<GpuCounterValue>& memory);

}  // namespace pulse
