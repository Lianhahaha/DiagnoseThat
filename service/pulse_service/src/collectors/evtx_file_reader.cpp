#include "collectors/evtx_file_reader.hpp"

#include "windows/wevt_helpers.hpp"

#include <algorithm>

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <winevt.h>

namespace pulse {
namespace {

// Events requested from EvtNext per call.
constexpr DWORD kEvtxBatchSize = 256;

}  // namespace

CollectResult<EvtxFileContents> ReadEvtxFile(const std::wstring& path,
                                             std::size_t max_events) {
  if (path.empty()) {
    return CollectResult<EvtxFileContents>::Failure("No file was given");
  }
  if (max_events == 0) {
    return CollectResult<EvtxFileContents>::Failure("max_events must be > 0");
  }

  EVT_HANDLE raw = EvtQuery(nullptr, path.c_str(), L"*",
                            EvtQueryFilePath | EvtQueryReverseDirection);
  if (raw == nullptr) {
    return CollectResult<EvtxFileContents>::Failure(
        "Could not open the event log file: " +
        wevt::FormatWin32Error(GetLastError()));
  }
  wevt::EvtHandle query{raw};

  DWORD context_error = ERROR_SUCCESS;
  wevt::EvtHandle context = wevt::CreateSystemRenderContext(&context_error);
  if (!context) {
    return CollectResult<EvtxFileContents>::Failure(
        "EvtCreateRenderContext failed: " +
        wevt::FormatWin32Error(context_error));
  }

  EvtxFileContents contents;
  while (contents.events.size() < max_events) {
    const auto wanted = static_cast<DWORD>(
        std::min<std::size_t>(kEvtxBatchSize, max_events - contents.events.size()));
    DWORD next_error = ERROR_SUCCESS;
    auto batch = wevt::NextEvents(query.get(), wanted, &next_error);
    if (batch.empty()) {
      if (next_error != ERROR_NO_MORE_ITEMS && next_error != ERROR_SUCCESS &&
          contents.events.empty()) {
        return CollectResult<EvtxFileContents>::Failure(
            "Could not read events from the file: " +
            wevt::FormatWin32Error(next_error));
      }
      return CollectResult<EvtxFileContents>::Success(std::move(contents));
    }
    for (const auto& handle : batch) {
      auto record = EventLogCollector::ParseEvtHandle(handle.get(), context.get());
      if (!record) {
        continue;  // One unreadable record must not hide the rest.
      }
      if (record->raw_xml.empty()) {
        record->raw_xml = wevt::RenderEventXml(handle.get());
      }
      contents.events.push_back(std::move(*record));
    }
  }

  // Stopped at the limit: check whether anything is left.
  DWORD probe_error = ERROR_SUCCESS;
  contents.truncated = !wevt::NextEvents(query.get(), 1, &probe_error).empty();
  return CollectResult<EvtxFileContents>::Success(std::move(contents));
}

}  // namespace pulse
