#pragma once

#include "intelligence/event_intelligence.hpp"
#include "pulse_wire.hpp"

#include <cstdint>
#include <optional>
#include <string_view>

namespace pulse {

/// Explains what woke the PC from sleep, using the event's own data.
///
/// Power-Troubleshooter event 1 ("The system has returned from a low power
/// state") carries, per its manifest:
///  - WakeSourceText: the wake source as Windows names it (a device name,
///    for example)
///  - WakeTimerOwner / WakeTimerContext (manifest version 1 and later): the
///    program and task behind a wake timer
///
/// WakeSourceType is deliberately not used: Microsoft does not document what
/// its values mean, and Pulse does not guess.
///
/// Needs TimelineEvent::raw_xml; the collector renders it when
/// IsWakeDiagnosticEvent() is true. Returns nullopt without event data or
/// without a wake source, so the generic catalog rule still applies.
[[nodiscard]] std::optional<EventInsight> ExplainWakeEvent(
    const ipc::TimelineEvent& event);

/// True for the wake event whose explanation needs its EventData.
[[nodiscard]] bool IsWakeDiagnosticEvent(std::string_view provider_name,
                                         std::uint32_t win_event_id);

}  // namespace pulse
