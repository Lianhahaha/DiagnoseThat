#include "intelligence/bugcheck_catalog.hpp"
#include "intelligence/crash_explainer.hpp"
#include "intelligence/event_intelligence.hpp"

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

bool Contains(const std::string& text, const std::string& part) {
  return text.find(part) != std::string::npos;
}

std::string KernelPower41Xml(const std::string& bugcheck,
                             const std::string& power_button,
                             const std::string& sleep) {
  return "<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'>"
         "<System><Provider Name='Microsoft-Windows-Kernel-Power'/>"
         "<EventID>41</EventID><Keywords>0x8000400000000002</Keywords></System>"
         "<EventData>"
         "<Data Name='BugcheckCode'>" + bugcheck + "</Data>"
         "<Data Name='BugcheckParameter1'>0x3</Data>"
         "<Data Name='SleepInProgress'>" + sleep + "</Data>"
         "<Data Name='PowerButtonTimestamp'>" + power_button + "</Data>"
         "<Data Name='BootAppStatus'>0</Data>"
         "</EventData></Event>";
}

ipc::TimelineEvent KernelPower41(const std::string& xml) {
  ipc::TimelineEvent e;
  e.provider_name = "Microsoft-Windows-Kernel-Power";
  e.win_event_id = 41;
  e.severity = ipc::Severity::Critical;
  e.raw_xml = xml;
  return e;
}

void TestEventDataParsing() {
  const std::string xml =
      "<EventData><Data Name='A'>1</Data><Data Name=\"B\">x &amp; y</Data>"
      "<Data Name='Empty'/></EventData>";
  CHECK(FindEventDataValue(xml, "A") == std::string("1"));
  CHECK(FindEventDataValue(xml, "B") == std::string("x & y"));
  CHECK(FindEventDataValue(xml, "Empty") == std::string());
  CHECK(!FindEventDataValue(xml, "Missing").has_value());
}

void TestCatalog() {
  const BugcheckInfo* info = FindBugcheck(0x9F);
  CHECK(info != nullptr);
  CHECK(info->name == "DRIVER_POWER_STATE_FAILURE");
  CHECK(FindBugcheck(0x12345678) == nullptr);
  CHECK(FormatBugcheckCode(0xA) == "0x0000000A");
  CHECK(FormatBugcheckCode(0xC000021A) == "0xC000021A");
}

void TestKernelPowerBlueScreen() {
  // Microsoft's example: BugcheckCode 159 is 0x9F.
  const auto insight =
      ExplainCrashEvent(KernelPower41(KernelPower41Xml("159", "0", "false")));
  CHECK(insight.has_value());
  CHECK(insight->title == "Windows Restarted After a Blue Screen");
  CHECK(Contains(insight->summary, "DRIVER_POWER_STATE_FAILURE (0x0000009F)"));
  CHECK(insight->importance == Importance::Critical);
  CHECK(insight->category == InsightCategory::Crash);
  CHECK(!insight->recommendation.empty());
}

void TestKernelPowerPowerButton() {
  const auto insight = ExplainCrashEvent(
      KernelPower41(KernelPower41Xml("0", "131728546170882432", "0")));
  CHECK(insight.has_value());
  CHECK(insight->title == "PC Was Forced Off With the Power Button");
  CHECK(insight->category == InsightCategory::Power);
}

void TestKernelPowerPowerLoss() {
  const auto insight =
      ExplainCrashEvent(KernelPower41(KernelPower41Xml("0", "0", "0")));
  CHECK(insight.has_value());
  CHECK(insight->title == "PC Lost Power or Stopped Suddenly");
  CHECK(Contains(insight->summary, "power supply"));
  CHECK(!Contains(insight->summary, "sleep"));

  const auto during_sleep =
      ExplainCrashEvent(KernelPower41(KernelPower41Xml("0", "0", "1")));
  CHECK(during_sleep.has_value());
  CHECK(Contains(during_sleep->summary, "going to sleep"));
}

void TestKernelPowerWithoutEventData() {
  // Live events without XML fall back to the catalog's generic rule.
  CHECK(!ExplainCrashEvent(KernelPower41("")).has_value());

  EventIntelligence engine;
  const auto insight = engine.Analyze(KernelPower41(""));
  CHECK(insight.title == "Windows Restarted Unexpectedly");
}

void TestBugcheck1001() {
  ipc::TimelineEvent e;
  e.provider_name = "Microsoft-Windows-WER-SystemErrorReporting";
  e.win_event_id = 1001;
  e.severity = ipc::Severity::Error;
  e.raw_xml =
      "<Event><System><Keywords>0x80000000000000</Keywords></System><EventData>"
      "<Data Name='param1'>0x0000000a (0xfffff80000000000, 0x0000000000000002, "
      "0x0000000000000000, 0xfffff80312345678)</Data>"
      "<Data Name='param2'>C:\\WINDOWS\\Minidump\\101426-12345-01.dmp</Data>"
      "<Data Name='param3'>1b2c3d4e</Data></EventData></Event>";
  const auto insight = ExplainCrashEvent(e);
  CHECK(insight.has_value());
  CHECK(insight->title == "Windows Crashed With a Blue Screen");
  CHECK(Contains(insight->summary, "IRQL_NOT_LESS_OR_EQUAL (0x0000000A)"));
  CHECK(Contains(insight->summary, "driver"));
  CHECK(Contains(insight->summary,
                 "C:\\WINDOWS\\Minidump\\101426-12345-01.dmp"));
}

void TestBugcheckFromLocalizedMessage() {
  // No XML yet: the stop code pattern is the same in every language.
  ipc::TimelineEvent e;
  e.provider_name = "Microsoft-Windows-WER-SystemErrorReporting";
  e.win_event_id = 1001;
  e.message =
      "Bilgisayar bir hata denetiminden sonra yeniden baslatildi. Hata "
      "denetimi: 0x00000133 (0x0000000000000001, 0x0000000000001e00, "
      "0xfffff8063c4fb320, 0x0000000000000000). Bir dokum suraya kaydedildi: "
      "C:\\WINDOWS\\MEMORY.DMP. Rapor Kimligi: abc.";
  const auto insight = ExplainCrashEvent(e);
  CHECK(insight.has_value());
  CHECK(Contains(insight->summary, "DPC_WATCHDOG_VIOLATION (0x00000133)"));
  CHECK(Contains(insight->summary, "C:\\WINDOWS\\MEMORY.DMP"));
}

void TestUnknownStopCode() {
  ipc::TimelineEvent e;
  e.provider_name = "Microsoft-Windows-WER-SystemErrorReporting";
  e.win_event_id = 1001;
  e.message = "The bugcheck was: 0x00000999 (0x0, 0x0, 0x0, 0x0).";
  const auto insight = ExplainCrashEvent(e);
  CHECK(insight.has_value());
  CHECK(Contains(insight->summary, "Stop code: 0x00000999."));
  CHECK(Contains(insight->recommendation, "Bug Check Code Reference"));
}

void TestWerAppReportIsNotABlueScreen() {
  // Windows Error Reporting 1001 is an app problem report, not a bug check.
  ipc::TimelineEvent e;
  e.provider_name = "Windows Error Reporting";
  e.win_event_id = 1001;
  e.message = "Fault bucket 0x1234 (type 5)";
  CHECK(!ExplainCrashEvent(e).has_value());
  CHECK(!IsCrashDiagnosticEvent(e.provider_name, e.win_event_id));
}

void TestWhea() {
  ipc::TimelineEvent fatal;
  fatal.provider_name = "Microsoft-Windows-WHEA-Logger";
  fatal.win_event_id = 18;
  fatal.severity = ipc::Severity::Error;
  const auto fatal_insight = ExplainCrashEvent(fatal);
  CHECK(fatal_insight.has_value());
  CHECK(fatal_insight->title == "Hardware Reported a Fatal Error");
  CHECK(fatal_insight->importance == Importance::Critical);

  ipc::TimelineEvent corrected = fatal;
  corrected.win_event_id = 19;
  corrected.severity = ipc::Severity::Warning;
  const auto corrected_insight = ExplainCrashEvent(corrected);
  CHECK(corrected_insight.has_value());
  CHECK(corrected_insight->title == "Hardware Corrected an Error");
  CHECK(!corrected_insight->action_required);

  ipc::TimelineEvent info = fatal;
  info.severity = ipc::Severity::Info;
  CHECK(!ExplainCrashEvent(info).has_value());
}

void TestDiagnosticEventSelection() {
  CHECK(IsCrashDiagnosticEvent("Microsoft-Windows-Kernel-Power", 41));
  CHECK(IsCrashDiagnosticEvent("Microsoft-Windows-WER-SystemErrorReporting",
                               1001));
  CHECK(!IsCrashDiagnosticEvent("Microsoft-Windows-Kernel-Power", 42));
  CHECK(!IsCrashDiagnosticEvent("Service Control Manager", 41));
}

}  // namespace

int main() {
  TestEventDataParsing();
  TestCatalog();
  TestKernelPowerBlueScreen();
  TestKernelPowerPowerButton();
  TestKernelPowerPowerLoss();
  TestKernelPowerWithoutEventData();
  TestBugcheck1001();
  TestBugcheckFromLocalizedMessage();
  TestUnknownStopCode();
  TestWerAppReportIsNotABlueScreen();
  TestWhea();
  TestDiagnosticEventSelection();
  std::cout << "crash_explainer_tests: all passed\n";
  return 0;
}
