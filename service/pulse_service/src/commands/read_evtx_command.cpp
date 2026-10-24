#include "commands/read_evtx_command.hpp"

#include "collectors/evtx_file_reader.hpp"
#include "ipc/event_mapper.hpp"
#include "pulse_wire.hpp"
#include "windows/wevt_helpers.hpp"

#include <chrono>
#include <fstream>
#include <vector>

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

namespace pulse {
namespace {

// Imported events get their own id space so they never collide with live
// events (bookmarks and pins are keyed by event id).
constexpr char kImportedEventIdPrefix[] = "evtx:";

// PulseService.exe is a GUI-subsystem binary, so write to the inherited
// stderr handle directly instead of relying on the CRT streams.
void WriteError(const std::string& message) {
  const HANDLE err = GetStdHandle(STD_ERROR_HANDLE);
  if (err == nullptr || err == INVALID_HANDLE_VALUE) {
    return;
  }
  const std::string line = message + "\n";
  DWORD written = 0;
  WriteFile(err, line.data(), static_cast<DWORD>(line.size()), &written,
            nullptr);
}

std::int64_t NowUnixMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

bool AppendFrame(const ipc::Envelope& envelope, std::ofstream* out) {
  std::vector<std::uint8_t> payload;
  std::vector<std::uint8_t> frame;
  if (!ipc::EncodeEnvelope(envelope, &payload) ||
      !ipc::EncodeFrame(payload, &frame)) {
    return false;
  }
  out->write(reinterpret_cast<const char*>(frame.data()),
             static_cast<std::streamsize>(frame.size()));
  return static_cast<bool>(*out);
}

/// Frames are capped at kMaxFramePayloadBytes; an event with a huge payload
/// keeps its explanation and loses only its raw XML.
bool AppendEvent(ipc::TimelineEvent event, std::ofstream* out) {
  ipc::Envelope envelope;
  envelope.body = event;
  if (AppendFrame(envelope, out)) {
    return true;
  }
  if (!*out) {
    return false;
  }
  event.raw_xml.clear();
  envelope.body = std::move(event);
  return AppendFrame(envelope, out);
}

}  // namespace

int RunReadEvtxCommand(const std::wstring& input_path,
                       const std::wstring& output_path) {
  if (input_path.empty() || output_path.empty()) {
    WriteError("Usage: PulseService.exe --read-evtx <file.evtx> --out <file>");
    return kReadEvtxUsage;
  }

  auto contents = ReadEvtxFile(input_path, kEvtxImportMaxEvents);
  if (!contents) {
    WriteError(contents.error());
    return kReadEvtxReadFailed;
  }

  // Write next to the target and rename at the end, so a failed run never
  // leaves a half-written file the app could mistake for a result.
  const std::wstring partial_path = output_path + L".partial";
  {
    std::ofstream out(partial_path, std::ios::binary | std::ios::trunc);
    bool ok = static_cast<bool>(out);
    for (const EventRecord& record : contents.value().events) {
      if (!ok) {
        break;
      }
      ipc::TimelineEvent event = ToTimelineEvent(record);
      event.event_id = kImportedEventIdPrefix + event.event_id;
      ok = AppendEvent(std::move(event), &out);
    }
    if (ok) {
      ipc::TimelineSnapshot end;
      end.requested_limit = static_cast<std::uint32_t>(kEvtxImportMaxEvents);
      end.collected_unix_ms = NowUnixMs();
      ipc::Envelope envelope;
      envelope.body = std::move(end);
      ok = AppendFrame(envelope, &out);
    }
    out.close();
    if (!ok || !out) {
      DeleteFileW(partial_path.c_str());
      WriteError("Could not write the result file");
      return kReadEvtxWriteFailed;
    }
  }

  if (!MoveFileExW(partial_path.c_str(), output_path.c_str(),
                   MOVEFILE_REPLACE_EXISTING)) {
    const DWORD error = GetLastError();
    DeleteFileW(partial_path.c_str());
    WriteError("Could not write the result file: " +
               wevt::FormatWin32Error(error));
    return kReadEvtxWriteFailed;
  }
  return kReadEvtxOk;
}

}  // namespace pulse
