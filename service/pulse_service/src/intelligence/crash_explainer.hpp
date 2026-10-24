#pragma once

#include "intelligence/event_intelligence.hpp"
#include "pulse_wire.hpp"

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace pulse {

/// Explains blue screens, sudden restarts and hardware errors in plain
/// language, using the event's own data:
///
///  - Kernel-Power 41: BugcheckCode / PowerButtonTimestamp / SleepInProgress
///    tell a blue screen, a forced power-off and a power loss apart
///    (learn.microsoft.com/troubleshoot/windows-client/performance/event-id-41-restart).
///  - WER-SystemErrorReporting 1001 ("BugCheck"): the stop code and dump path.
///  - WHEA-Logger: fatal (Error / Critical level) vs corrected (Warning).
///
/// Needs TimelineEvent::raw_xml for Kernel-Power 41; the collector renders it
/// for every event where IsCrashDiagnosticEvent() is true. Returns nullopt
/// when the event data is missing, so the generic catalog rule still applies.
[[nodiscard]] std::optional<EventInsight> ExplainCrashEvent(
    const ipc::TimelineEvent& event);

/// True for events whose explanation needs their EventData (raw XML).
[[nodiscard]] bool IsCrashDiagnosticEvent(std::string_view provider_name,
                                          std::uint32_t win_event_id);

/// Value of <Data Name='name'> in event XML; nullopt when absent.
[[nodiscard]] std::optional<std::string> FindEventDataValue(
    std::string_view event_xml, std::string_view name);

}  // namespace pulse
