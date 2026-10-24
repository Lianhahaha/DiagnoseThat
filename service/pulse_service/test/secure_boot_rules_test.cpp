#include "intelligence/event_intelligence.hpp"

#include <cstdint>
#include <cstdlib>
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

EventInsight Analyze(const std::string& provider, std::uint32_t id,
                     ipc::Severity severity) {
  ipc::TimelineEvent e;
  e.provider_name = provider;
  e.win_event_id = id;
  e.severity = severity;
  return EventIntelligence().Analyze(e);
}

constexpr const char* kTpmWmi = "Microsoft-Windows-TPM-WMI";

void TestSbatFailureIsExplainedNotAlarming() {
  // Issue #25: "Failed to update the SBAT in FW" is TPM-WMI 1796.
  const auto insight = Analyze(kTpmWmi, 1796, ipc::Severity::Error);
  CHECK(insight.title == "Secure Boot Update Failed");
  CHECK(insight.summary.find("SBAT") != std::string::npos);
  CHECK(insight.summary.find("next restart") != std::string::npos);
  CHECK(insight.importance == Importance::Medium);
  CHECK(!insight.action_required);
  CHECK(insight.category == InsightCategory::Security);
}

void TestSuccessEventsAreLowImportance() {
  for (const std::uint32_t id : {1034u, 1036u, 1037u, 1042u, 1043u, 1044u,
                                 1045u, 1799u, 1808u, 1797u, 1798u}) {
    const auto insight = Analyze(kTpmWmi, id, ipc::Severity::Info);
    CHECK(insight.importance == Importance::Low);
    CHECK(!insight.action_required);
    CHECK(insight.category == InsightCategory::Security);
  }
}

void TestEventsThatNeedTheUser() {
  CHECK(Analyze(kTpmWmi, 1801, ipc::Severity::Error).action_required);
  CHECK(Analyze(kTpmWmi, 1795, ipc::Severity::Error).recommendation.find(
            "firmware") != std::string::npos);
  CHECK(Analyze(kTpmWmi, 1032, ipc::Severity::Error).recommendation.find(
            "BitLocker") != std::string::npos);
  CHECK(Analyze(kTpmWmi, 1800, ipc::Severity::Warning).recommendation.find(
            "Restart") != std::string::npos);
}

void TestOtherProvidersWithTheSameIdsAreNotMatched() {
  // The TPM driver provider is "TPM", not "TPM-WMI".
  CHECK(Analyze("TPM", 1796, ipc::Severity::Error).title !=
        "Secure Boot Update Failed");
  CHECK(Analyze("Application Error", 1034, ipc::Severity::Info).title !=
        "Secure Boot Blocklist Updated");
}

}  // namespace

int main() {
  TestSbatFailureIsExplainedNotAlarming();
  TestSuccessEventsAreLowImportance();
  TestEventsThatNeedTheUser();
  TestOtherProvidersWithTheSameIdsAreNotMatched();
  std::cout << "secure_boot_rules_tests passed\n";
  return 0;
}
