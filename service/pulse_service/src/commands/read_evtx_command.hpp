#pragma once

#include <cstddef>
#include <string>

namespace pulse {

/// Most events one import reads (newest first). Keeps the output file and the
/// Timeline responsive for multi-year System logs.
inline constexpr std::size_t kEvtxImportMaxEvents = 20000;

enum ReadEvtxExitCode : int {
  kReadEvtxOk = 0,
  kReadEvtxUsage = 2,
  kReadEvtxReadFailed = 3,
  kReadEvtxWriteFailed = 4,
};

/// `PulseService.exe --read-evtx <file.evtx> --out <result.bin>`
///
/// Runs as the calling user (no service, no pipe, no elevation): the Pulse app
/// starts it to open an .evtx exported from another PC. Each event is
/// explained exactly like a live event and written to `out` as wire frames:
///
///   frame(Envelope{TimelineEvent}) ... frame(Envelope{TimelineSnapshot})
///
/// The closing TimelineSnapshot has no events: it marks a complete file and
/// carries the event limit (`requested_limit`), so the app can say "newest
/// 20,000 events" when the limit was reached.
///
/// Returns 0 on success. On failure writes the reason to stderr, returns a
/// ReadEvtxExitCode and leaves no output file behind.
int RunReadEvtxCommand(const std::wstring& input_path,
                       const std::wstring& output_path);

}  // namespace pulse
