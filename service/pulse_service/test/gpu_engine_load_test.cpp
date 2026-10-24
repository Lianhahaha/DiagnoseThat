#include "collectors/gpu_engine_load.hpp"

#include <cstdlib>
#include <iostream>

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

// Instance names as PDH reports them on the test PC (RTX 3060 at LUID
// 0x0000F21B, plus an integrated GPU invented at LUID 0x0000A001).
constexpr wchar_t kDedicated3dEngine0[] =
    L"pid_1200_luid_0x00000000_0x0000F21B_phys_0_eng_0_engtype_3D";

void TestLuidToken() {
  CHECK(GpuLuidToken(0, 0xF21B) == L"luid_0x00000000_0x0000F21B");
  CHECK(GpuLuidToken(-1, 0x1) == L"luid_0xFFFFFFFF_0x00000001");
  CHECK(GpuLuidTokenOfInstance(kDedicated3dEngine0) ==
        L"LUID_0X00000000_0X0000F21B");
  CHECK(GpuLuidTokenOfInstance(L"luid_0x00000000_0x0000f21b_phys_0") ==
        L"LUID_0X00000000_0X0000F21B");
  CHECK(GpuLuidTokenOfInstance(L"_Total").empty());
  CHECK(GpuLuidTokenOfInstance(L"luid_0x0000").empty());
}

void TestEngineIsSummedOverProcesses() {
  // Two processes on the same 3D engine add up, as in Task Manager.
  const auto loads = SumGpuEngineLoad({
      {kDedicated3dEngine0, 30.0},
      {L"pid_4400_luid_0x00000000_0x0000F21B_phys_0_eng_0_engtype_3D", 25.0},
      {L"pid_4400_luid_0x00000000_0x0000F21B_phys_0_eng_2_engtype_VideoDecode",
       10.0},
  });
  const auto it = loads.find(L"LUID_0X00000000_0X0000F21B");
  CHECK(it != loads.end());
  CHECK(it->second.has_overall && it->second.overall == 55.0);
  CHECK(it->second.has_3d && it->second.util_3d == 55.0);
  CHECK(it->second.has_video_decode && it->second.video_decode == 10.0);
  CHECK(!it->second.has_copy && !it->second.has_compute);
}

void TestBusiestEngineWinsPerType() {
  // Separate copy engines are not added together; the busiest one counts.
  const auto loads = SumGpuEngineLoad({
      {L"pid_8_luid_0x00000000_0x0000F21B_phys_0_eng_3_engtype_Copy", 20.0},
      {L"pid_8_luid_0x00000000_0x0000F21B_phys_0_eng_4_engtype_Copy", 35.0},
      {L"pid_8_luid_0x00000000_0x0000F21B_phys_0_eng_5_engtype_Security", 70.0},
  });
  const auto& load = loads.at(L"LUID_0X00000000_0X0000F21B");
  CHECK(load.has_copy && load.copy == 35.0);
  // Engines of other types still count toward the overall figure.
  CHECK(load.overall == 70.0);
}

void TestAdaptersStaySeparate() {
  const auto loads = SumGpuEngineLoad({
      {kDedicated3dEngine0, 40.0},
      {L"pid_77_luid_0x00000000_0x0000A001_phys_0_eng_0_engtype_3D", 15.0},
      {L"pid_77_luid_0x00000000_0x0000A001_phys_0_eng_1_engtype_"
       L"VideoProcessing",
       5.0},
  });
  CHECK(loads.size() == 2);
  CHECK(loads.at(L"LUID_0X00000000_0X0000F21B").overall == 40.0);
  const auto& integrated = loads.at(L"LUID_0X00000000_0X0000A001");
  CHECK(integrated.overall == 15.0);
  CHECK(integrated.has_video_processing &&
        integrated.video_processing == 5.0);
}

void TestEngineSumIsClampedTo100() {
  const auto loads = SumGpuEngineLoad({
      {kDedicated3dEngine0, 80.0},
      {L"pid_9_luid_0x00000000_0x0000F21B_phys_0_eng_0_engtype_3D", 45.0},
      {L"pid_10_luid_0x00000000_0x0000F21B_phys_0_eng_0_engtype_3D", -3.0},
  });
  CHECK(loads.at(L"LUID_0X00000000_0X0000F21B").overall == 100.0);
}

void TestIdleEngineStillReports() {
  // An idle adapter reports 0 %, which is different from "not reported".
  const auto loads = SumGpuEngineLoad({{kDedicated3dEngine0, 0.0}});
  const auto& load = loads.at(L"LUID_0X00000000_0X0000F21B");
  CHECK(load.has_overall && load.overall == 0.0);
}

void TestNamesWithoutLuidAreIgnored() {
  const auto loads = SumGpuEngineLoad({{L"_Total", 50.0}, {L"", 10.0}});
  CHECK(loads.empty());
}

void TestAdapterMemoryIsSummedPerAdapter() {
  const auto used = SumGpuAdapterMemory({
      {L"luid_0x00000000_0x0000F21B_phys_0", 1'000'000'000.0},
      {L"luid_0x00000000_0x0000F21B_phys_1", 500'000'000.0},
      {L"luid_0x00000000_0x0000A001_phys_0", 0.0},
  });
  CHECK(used.at(L"LUID_0X00000000_0X0000F21B") == 1'500'000'000ULL);
  // Zero is a real reading and is kept.
  CHECK(used.count(L"LUID_0X00000000_0X0000A001") == 1);
  CHECK(used.at(L"LUID_0X00000000_0X0000A001") == 0);
}

}  // namespace

int main() {
  TestLuidToken();
  TestEngineIsSummedOverProcesses();
  TestBusiestEngineWinsPerType();
  TestAdaptersStaySeparate();
  TestEngineSumIsClampedTo100();
  TestIdleEngineStillReports();
  TestNamesWithoutLuidAreIgnored();
  TestAdapterMemoryIsSummedPerAdapter();
  std::cout << "gpu_engine_load_tests passed\n";
  return 0;
}
