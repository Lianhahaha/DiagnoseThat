#pragma once

#include "collectors/event_log_collector.hpp"
#include "models/event_record.hpp"

#include <cstddef>
#include <string>
#include <vector>

namespace pulse {

/// Events read from an exported .evtx file, newest first.
struct EvtxFileContents {
  std::vector<EventRecord> events;
  /// True when the file holds more events than were read.
  bool truncated = false;
};

/// Reads an exported Event Log file (for example System.evtx copied from
/// another PC) with EvtQuery(EvtQueryFilePath). Read-only: the file is never
/// modified. Every event includes its raw XML, because the file may come from
/// another machine and cannot be looked up again by record id.
///
/// Messages are formatted with this PC's provider resources; events from a
/// provider that is not installed here keep their XML but have no message.
[[nodiscard]] CollectResult<EvtxFileContents> ReadEvtxFile(
    const std::wstring& path, std::size_t max_events);

}  // namespace pulse
