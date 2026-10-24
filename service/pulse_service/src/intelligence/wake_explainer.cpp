#include "intelligence/wake_explainer.hpp"

#include "intelligence/crash_explainer.hpp"
#include "util/text_match.hpp"

#include <cctype>
#include <string>

namespace pulse {
namespace {

constexpr std::string_view kWakeProvider = "Power-Troubleshooter";
constexpr std::uint32_t kWakeEventId = 1;

/// U+2026, spelled as UTF-8 bytes so it does not depend on the compiler's
/// source code page.
constexpr const char* kEllipsis = "\xE2\x80\xA6";

/// Longest wake source shown in a title; the full text stays in the summary.
constexpr std::size_t kMaxTitleSourceLength = 48;

std::string Trimmed(const std::optional<std::string>& value) {
  if (!value) {
    return {};
  }
  std::size_t start = 0;
  std::size_t end = value->size();
  while (start < end && std::isspace(static_cast<unsigned char>((*value)[start]))) {
    ++start;
  }
  while (end > start &&
         std::isspace(static_cast<unsigned char>((*value)[end - 1]))) {
    --end;
  }
  return value->substr(start, end - start);
}

std::string ShortenForTitle(const std::string& text) {
  if (text.size() <= kMaxTitleSourceLength) {
    return text;
  }
  // Cut on a space so a word is not split; UTF-8 stays intact because spaces
  // are single bytes.
  std::size_t cut = text.rfind(' ', kMaxTitleSourceLength);
  if (cut == std::string::npos || cut == 0) {
    cut = kMaxTitleSourceLength;
    while (cut > 0 && (static_cast<unsigned char>(text[cut]) & 0xC0) == 0x80) {
      --cut;  // Do not split a multi-byte UTF-8 character.
    }
  }
  return text.substr(0, cut) + kEllipsis;
}

std::string WithFullStop(std::string text) {
  if (!text.empty() && text.back() != '.') {
    text.push_back('.');
  }
  return text;
}

}  // namespace

bool IsWakeDiagnosticEvent(std::string_view provider_name,
                           std::uint32_t win_event_id) {
  return win_event_id == kWakeEventId &&
         ContainsIgnoreCase(provider_name, kWakeProvider);
}

std::optional<EventInsight> ExplainWakeEvent(const ipc::TimelineEvent& event) {
  if (!IsWakeDiagnosticEvent(event.provider_name, event.win_event_id) ||
      event.raw_xml.empty()) {
    return std::nullopt;
  }
  const std::string source =
      Trimmed(FindEventDataValue(event.raw_xml, "WakeSourceText"));
  const std::string timer_context =
      Trimmed(FindEventDataValue(event.raw_xml, "WakeTimerContext"));
  const std::string timer_owner =
      Trimmed(FindEventDataValue(event.raw_xml, "WakeTimerOwner"));
  if (source.empty() && timer_context.empty() && timer_owner.empty()) {
    return std::nullopt;  // Nothing recorded: keep the catalog wording.
  }

  EventInsight out;
  out.importance = Importance::Low;
  out.category = InsightCategory::Power;
  out.action_required = false;

  if (!timer_context.empty() || !timer_owner.empty()) {
    out.title = "PC Woke Up for a Scheduled Task";
    out.summary = "A wake timer woke the PC from sleep.";
    if (!timer_context.empty()) {
      out.summary += " " + WithFullStop(timer_context);
    }
    if (!timer_owner.empty()) {
      out.summary += " Requested by: " + WithFullStop(timer_owner);
    }
    out.recommendation =
        "If you do not want this, look up the task in Task Scheduler, or turn "
        "off \"Allow wake timers\" in Power Options.";
    return out;
  }

  out.title = "PC Woke Up: " + ShortenForTitle(source);
  out.summary = "Windows reports the wake source as: " + WithFullStop(source);
  out.recommendation =
      "If the PC wakes up on its own and this is a device such as a network "
      "adapter, mouse or keyboard, open it in Device Manager and clear "
      "\"Allow this device to wake the computer\" under Power Management.";
  return out;
}

}  // namespace pulse
