#include "collectors/gpu_engine_load.hpp"

#include <algorithm>
#include <cwchar>

// PDH GPU instance names, as emitted by dxgkrnl:
//   GPU Engine:          pid_<pid>_luid_0x<high>_0x<low>_phys_<n>_eng_<n>_engtype_<type>
//   GPU Adapter Memory:  luid_0x<high>_0x<low>_phys_<n>
// The engine counters are per process, so one engine appears once for every
// process using it. Task Manager adds those up per engine and shows the
// busiest engine as the GPU's utilization (DirectX Developer Blog, "GPUs in
// the Task Manager", 2017).

namespace pulse {
namespace {

constexpr wchar_t kLuidPrefix[] = L"LUID_0X";
constexpr wchar_t kEngineTypeMarker[] = L"_ENGTYPE_";
// "luid_0x" + 8 hex + "_0x" + 8 hex.
constexpr size_t kLuidTokenLength = 7 + 8 + 3 + 8;

std::wstring AsciiUpper(std::wstring text) {
  for (wchar_t& c : text) {
    if (c >= L'a' && c <= L'z') c = static_cast<wchar_t>(c - L'a' + L'A');
  }
  return text;
}

bool StartsWith(const std::wstring& text, const wchar_t* prefix) {
  return text.rfind(prefix, 0) == 0;
}

double ClampPercent(double value) {
  return (std::min)((std::max)(value, 0.0), 100.0);
}

void RaiseTo(bool* has, double* current, double value) {
  *current = *has ? (std::max)(*current, value) : value;
  *has = true;
}

/// Adds one engine's summed utilization to its adapter, by engine type.
void AddEngine(const std::wstring& engine_type, double percent,
               GpuAdapterLoad* load) {
  RaiseTo(&load->has_overall, &load->overall, percent);
  if (StartsWith(engine_type, L"3D")) {
    RaiseTo(&load->has_3d, &load->util_3d, percent);
  } else if (StartsWith(engine_type, L"VIDEODECODE")) {
    RaiseTo(&load->has_video_decode, &load->video_decode, percent);
  } else if (StartsWith(engine_type, L"VIDEOENCODE")) {
    RaiseTo(&load->has_video_encode, &load->video_encode, percent);
  } else if (StartsWith(engine_type, L"VIDEOPROCESSING")) {
    RaiseTo(&load->has_video_processing, &load->video_processing, percent);
  } else if (StartsWith(engine_type, L"COPY")) {
    RaiseTo(&load->has_copy, &load->copy, percent);
  } else if (StartsWith(engine_type, L"COMPUTE")) {
    RaiseTo(&load->has_compute, &load->compute, percent);
  }
  // Other engines (Security, LegacyOverlay, ...) only count toward overall.
}

}  // namespace

std::wstring GpuLuidToken(int32_t luid_high, uint32_t luid_low) {
  wchar_t token[32]{};
  swprintf_s(token, L"luid_0x%08X_0x%08X", static_cast<unsigned>(luid_high),
             static_cast<unsigned>(luid_low));
  return token;
}

std::wstring GpuLuidTokenOfInstance(const std::wstring& instance) {
  const std::wstring upper = AsciiUpper(instance);
  const size_t start = upper.find(kLuidPrefix);
  if (start == std::wstring::npos ||
      upper.size() < start + kLuidTokenLength) {
    return {};
  }
  return upper.substr(start, kLuidTokenLength);
}

std::map<std::wstring, GpuAdapterLoad> SumGpuEngineLoad(
    const std::vector<GpuCounterValue>& engines) {
  struct Engine {
    std::wstring adapter;
    std::wstring type;
    double sum = 0.0;
  };
  // Keyed by "LUID_..._PHYS_n_ENG_n", the same engine across processes.
  std::map<std::wstring, Engine> by_engine;
  for (const GpuCounterValue& counter : engines) {
    const std::wstring upper = AsciiUpper(counter.instance);
    const size_t start = upper.find(kLuidPrefix);
    if (start == std::wstring::npos ||
        upper.size() < start + kLuidTokenLength) {
      continue;
    }
    const size_t type_at = upper.find(kEngineTypeMarker, start);
    const std::wstring engine_key = upper.substr(
        start, type_at == std::wstring::npos ? std::wstring::npos
                                             : type_at - start);
    Engine& engine = by_engine[engine_key];
    if (engine.adapter.empty()) {
      engine.adapter = upper.substr(start, kLuidTokenLength);
      if (type_at != std::wstring::npos) {
        engine.type = upper.substr(type_at + std::wcslen(kEngineTypeMarker));
      }
    }
    engine.sum += (std::max)(counter.value, 0.0);
  }

  std::map<std::wstring, GpuAdapterLoad> by_adapter;
  for (const auto& [key, engine] : by_engine) {
    AddEngine(engine.type, ClampPercent(engine.sum),
              &by_adapter[engine.adapter]);
  }
  return by_adapter;
}

std::map<std::wstring, uint64_t> SumGpuAdapterMemory(
    const std::vector<GpuCounterValue>& memory) {
  std::map<std::wstring, uint64_t> by_adapter;
  for (const GpuCounterValue& counter : memory) {
    const std::wstring adapter = GpuLuidTokenOfInstance(counter.instance);
    if (adapter.empty() || counter.value <= 0.0) {
      if (!adapter.empty()) by_adapter.try_emplace(adapter, 0);
      continue;
    }
    by_adapter[adapter] += static_cast<uint64_t>(counter.value);
  }
  return by_adapter;
}

}  // namespace pulse
