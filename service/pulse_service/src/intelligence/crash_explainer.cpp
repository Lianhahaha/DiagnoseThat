#include "intelligence/crash_explainer.hpp"

#include "intelligence/bugcheck_catalog.hpp"
#include "util/text_match.hpp"

#include <cctype>
#include <charconv>
#include <limits>

namespace pulse {
namespace {

constexpr std::string_view kKernelPowerProvider = "Kernel-Power";
constexpr std::uint32_t kUnexpectedRestartEventId = 41;
constexpr std::string_view kBugcheckProvider = "WER-SystemErrorReporting";
constexpr std::uint32_t kBugcheckEventId = 1001;
constexpr std::string_view kWheaProvider = "WHEA-Logger";

constexpr std::string_view kDumpExtension = ".dmp";

bool IsKernelPower41(const ipc::TimelineEvent& event) {
  return event.win_event_id == kUnexpectedRestartEventId &&
         ContainsIgnoreCase(event.provider_name, kKernelPowerProvider);
}

bool IsBugcheck1001(const ipc::TimelineEvent& event) {
  return event.win_event_id == kBugcheckEventId &&
         ContainsIgnoreCase(event.provider_name, kBugcheckProvider);
}

std::string DecodeXmlEntities(std::string_view text) {
  struct Entity {
    std::string_view encoded;
    char decoded;
  };
  constexpr Entity kEntities[] = {{"&amp;", '&'},  {"&lt;", '<'},
                                  {"&gt;", '>'},   {"&quot;", '"'},
                                  {"&apos;", '\''}};
  std::string out;
  out.reserve(text.size());
  for (std::size_t i = 0; i < text.size();) {
    bool replaced = false;
    if (text[i] == '&') {
      for (const auto& entity : kEntities) {
        if (text.substr(i, entity.encoded.size()) == entity.encoded) {
          out.push_back(entity.decoded);
          i += entity.encoded.size();
          replaced = true;
          break;
        }
      }
    }
    if (!replaced) {
      out.push_back(text[i]);
      ++i;
    }
  }
  return out;
}

std::optional<std::uint64_t> ParseUnsigned(std::string_view text, int base) {
  while (!text.empty() && std::isspace(static_cast<unsigned char>(text.front()))) {
    text.remove_prefix(1);
  }
  while (!text.empty() && std::isspace(static_cast<unsigned char>(text.back()))) {
    text.remove_suffix(1);
  }
  if (base == 16 && text.size() > 2 && text[0] == '0' &&
      (text[1] == 'x' || text[1] == 'X')) {
    text.remove_prefix(2);
  }
  std::uint64_t value = 0;
  const auto* end = text.data() + text.size();
  const auto result = std::from_chars(text.data(), end, value, base);
  if (text.empty() || result.ec != std::errc() || result.ptr != end) {
    return std::nullopt;
  }
  return value;
}

/// "true"/"1" style flags; anything else (including absent) is false.
bool IsTruthy(const std::optional<std::string>& value) {
  if (!value) {
    return false;
  }
  if (ContainsIgnoreCase(*value, "true")) {
    return true;
  }
  const auto number = ParseUnsigned(*value, 10);
  return number.has_value() && *number != 0;
}

/// First "0x<hex> (" in text: the stop code in a bugcheck message, e.g.
/// "0x0000009f (0x0000000000000003, ...)". The pattern does not depend on the
/// Windows display language, unlike the surrounding sentence.
std::optional<std::uint32_t> FindStopCode(std::string_view text) {
  for (std::size_t at = text.find("0x"); at != std::string_view::npos;
       at = text.find("0x", at + 2)) {
    std::size_t end = at + 2;
    while (end < text.size() &&
           std::isxdigit(static_cast<unsigned char>(text[end]))) {
      ++end;
    }
    std::size_t paren = end;
    while (paren < text.size() && text[paren] == ' ') {
      ++paren;
    }
    if (end == at + 2 || paren >= text.size() || text[paren] != '(') {
      continue;
    }
    const auto value = ParseUnsigned(text.substr(at, end - at), 16);
    if (value && *value != 0 &&
        *value <= std::numeric_limits<std::uint32_t>::max()) {
      return static_cast<std::uint32_t>(*value);
    }
  }
  return std::nullopt;
}

/// First "X:\...\name.dmp" path in text.
std::optional<std::string> FindDumpPath(std::string_view text) {
  constexpr std::string_view kPathStops = "<>\"'\r\n|?*";
  for (std::size_t ext = 0; ext + kDumpExtension.size() <= text.size(); ++ext) {
    if (!ContainsIgnoreCase(text.substr(ext, kDumpExtension.size()),
                            kDumpExtension)) {
      continue;
    }
    std::size_t start = ext;
    while (start > 0 && kPathStops.find(text[start - 1]) == std::string_view::npos) {
      --start;
    }
    // Trim to the drive letter: "...was saved in: C:\Windows\MEMORY.DMP".
    const std::size_t drive = text.find(":\\", start);
    if (drive == std::string_view::npos || drive == 0 || drive - 1 < start ||
        drive > ext ||
        !std::isalpha(static_cast<unsigned char>(text[drive - 1]))) {
      continue;
    }
    const std::size_t path_start = drive - 1;
    return std::string(
        text.substr(path_start, ext + kDumpExtension.size() - path_start));
  }
  return std::nullopt;
}

/// "Stop code: NAME (0x0000000A). <why>" — the shared blue-screen sentence.
std::string DescribeStopCode(std::uint32_t code) {
  const BugcheckInfo* info = FindBugcheck(code);
  std::string text = "Stop code: ";
  if (info != nullptr) {
    text += std::string(info->name) + " (" + FormatBugcheckCode(code) + "). ";
    text += std::string(BugcheckCauseExplanation(info->cause));
  } else {
    text += FormatBugcheckCode(code) + ".";
  }
  return text;
}

std::string StopCodeRecommendation(std::uint32_t code) {
  const BugcheckInfo* info = FindBugcheck(code);
  if (info != nullptr) {
    return std::string(BugcheckCauseRecommendation(info->cause));
  }
  return "Look up this stop code in Microsoft's Bug Check Code Reference and "
         "check recently installed drivers or hardware.";
}

EventInsight BlueScreenInsight(std::string title, std::uint32_t code) {
  EventInsight out;
  out.title = std::move(title);
  out.summary = DescribeStopCode(code);
  out.recommendation = StopCodeRecommendation(code);
  out.action_required = !out.recommendation.empty();
  out.importance = Importance::Critical;
  out.category = InsightCategory::Crash;
  return out;
}

std::optional<EventInsight> ExplainUnexpectedRestart(
    const ipc::TimelineEvent& event) {
  const auto bugcheck_value = FindEventDataValue(event.raw_xml, "BugcheckCode");
  if (!bugcheck_value) {
    return std::nullopt;  // No event data: keep the generic catalog wording.
  }
  const auto bugcheck = ParseUnsigned(*bugcheck_value, 10).value_or(0);
  const auto power_button =
      FindEventDataValue(event.raw_xml, "PowerButtonTimestamp");
  const bool power_button_held =
      IsTruthy(power_button) ||
      IsTruthy(FindEventDataValue(event.raw_xml, "LongPowerButtonPressDetected"));
  const bool during_sleep =
      IsTruthy(FindEventDataValue(event.raw_xml, "SleepInProgress"));

  EventInsight out;
  if (bugcheck != 0 && bugcheck <= std::numeric_limits<std::uint32_t>::max()) {
    // Event 41 stores the stop code in decimal (159 = 0x9F).
    out = BlueScreenInsight("Windows Restarted After a Blue Screen",
                            static_cast<std::uint32_t>(bugcheck));
  } else if (power_button_held) {
    out.title = "PC Was Forced Off With the Power Button";
    out.summary =
        "The power button was held down to turn the PC off, usually because "
        "it had stopped responding.";
    out.recommendation =
        "If Windows had frozen, look at the events just before this restart.";
    out.action_required = false;
    out.importance = Importance::High;
    out.category = InsightCategory::Power;
  } else {
    out.title = "PC Lost Power or Stopped Suddenly";
    out.summary =
        "The PC turned off without recording an error. This usually means a "
        "power cut, a drained battery, a faulty or underpowered power supply, "
        "overheating, or a complete freeze.";
    out.recommendation =
        "If it repeats, check the power supply and cables, temperatures and "
        "any overclocking. New hardware such as a CPU or graphics card may "
        "need a stronger power supply.";
    out.action_required = true;
    out.importance = Importance::Critical;
    out.category = InsightCategory::Power;
  }
  if (during_sleep) {
    out.summary += " It happened while the PC was going to sleep or waking up.";
  }
  return out;
}

std::optional<EventInsight> ExplainBugcheck(const ipc::TimelineEvent& event) {
  auto code = FindStopCode(event.raw_xml);
  if (!code) {
    code = FindStopCode(event.message);
  }
  if (!code) {
    return std::nullopt;
  }
  EventInsight out = BlueScreenInsight("Windows Crashed With a Blue Screen", *code);
  auto dump = FindDumpPath(event.raw_xml);
  if (!dump) {
    dump = FindDumpPath(event.message);
  }
  if (dump) {
    out.summary += " A crash dump was saved to " + DecodeXmlEntities(*dump) + ".";
  }
  return out;
}

std::optional<EventInsight> ExplainHardwareError(
    const ipc::TimelineEvent& event) {
  EventInsight out;
  out.category = InsightCategory::Device;
  switch (event.severity) {
    case ipc::Severity::Critical:
    case ipc::Severity::Error:
      out.title = "Hardware Reported a Fatal Error";
      out.summary =
          "A hardware component (processor, memory, a PCIe device or the "
          "motherboard) reported an error it could not fix. Windows usually "
          "stops with a blue screen when this happens.";
      out.recommendation =
          "Remove any overclock, check temperatures and the power supply, and "
          "run Windows Memory Diagnostic. The event details name the "
          "component that reported it.";
      out.action_required = true;
      out.importance = Importance::Critical;
      return out;
    case ipc::Severity::Warning:
      out.title = "Hardware Corrected an Error";
      out.summary =
          "A hardware component detected an error and fixed it on its own. "
          "One is harmless; many in a short time can point to failing "
          "hardware, an unstable overclock or a loose card.";
      out.recommendation =
          "Only worth checking if it keeps repeating. The event details name "
          "the component.";
      out.action_required = false;
      out.importance = Importance::Medium;
      return out;
    default:
      return std::nullopt;
  }
}

}  // namespace

std::optional<std::string> FindEventDataValue(std::string_view event_xml,
                                              std::string_view name) {
  // Windows renders <Data Name='X'>; accept double quotes as well.
  for (const char quote : {'\'', '"'}) {
    std::string attribute = "Name=";
    attribute += quote;
    attribute += name;
    attribute += quote;
    const std::size_t at = event_xml.find(attribute);
    if (at == std::string_view::npos) {
      continue;
    }
    const std::size_t tag_end = event_xml.find('>', at + attribute.size());
    if (tag_end == std::string_view::npos) {
      return std::nullopt;
    }
    if (event_xml[tag_end - 1] == '/') {
      return std::string();  // <Data Name='X'/>
    }
    const std::size_t close = event_xml.find("</Data>", tag_end);
    if (close == std::string_view::npos) {
      return std::nullopt;
    }
    return DecodeXmlEntities(
        event_xml.substr(tag_end + 1, close - tag_end - 1));
  }
  return std::nullopt;
}

bool IsCrashDiagnosticEvent(std::string_view provider_name,
                            std::uint32_t win_event_id) {
  return (win_event_id == kUnexpectedRestartEventId &&
          ContainsIgnoreCase(provider_name, kKernelPowerProvider)) ||
         (win_event_id == kBugcheckEventId &&
          ContainsIgnoreCase(provider_name, kBugcheckProvider));
}

std::optional<EventInsight> ExplainCrashEvent(const ipc::TimelineEvent& event) {
  if (IsKernelPower41(event)) {
    return ExplainUnexpectedRestart(event);
  }
  if (IsBugcheck1001(event)) {
    return ExplainBugcheck(event);
  }
  if (ContainsIgnoreCase(event.provider_name, kWheaProvider)) {
    return ExplainHardwareError(event);
  }
  return std::nullopt;
}

}  // namespace pulse
