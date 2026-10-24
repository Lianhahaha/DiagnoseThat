# ADR-014: Open exported .evtx files

**Status:** **Accepted** (2026-10-14)

**Date:** 2026-10-14

---

## Context

People who support other PCs asked to open an event log exported from another machine (for example `System.evtx`) and read it in plain language, the same way Pulse explains live events.

Constraints:

- The explanation logic (crash explainer, intelligence catalog) lives in the C++ service.
- PulseService runs as **LocalService**. It cannot read files in a user's profile (Downloads, Desktop), and it must not gain broader file access for this.
- AGENTS.md: read-only, local, no new privileges.

## Decision

1. Add a one-shot command to the service binary:

   ```text
   PulseService.exe --read-evtx <file.evtx> --out <result>
   ```

   The **Pulse app** runs it as the signed-in user, so it can read any file the user can, and needs neither the running service nor elevation.
2. The command opens the file with `EvtQuery(..., EvtQueryFilePath | EvtQueryReverseDirection)` and reads at most `kEvtxImportMaxEvents` (20,000) events, newest first. Each event goes through the same `ToTimelineEvent` → `EventIntelligence` path as live events. Every event carries its raw XML, because a record id from another PC cannot be looked up again.
3. The result is written as wire frames: one `Envelope{TimelineEvent}` per event, then a closing `Envelope{TimelineSnapshot}` with no events that carries the event limit. The command writes to `<result>.partial` and renames it at the end, so a failed run never leaves a partial result. Events whose frame would exceed 2 MB drop only their raw XML.
4. Imported event ids are prefixed with `evtx:`. They never collide with live events (bookmarks, pins), and the details panel never asks the service for their XML.
5. While a file is open, the Timeline shows its events instead of live ones, with a banner (file, count, computer) and **Back to live**. Filters, search, incidents and export work unchanged. Opening a file also works while PulseService is offline.

## Consequences

- New: `collectors/evtx_file_reader`, `commands/read_evtx_command`, app `EvtxImportController`, `EvtxFileReader`, and the `file_selector` plugin for the Windows open dialog.
- Messages are formatted with **this** PC's provider resources. Events from providers that are not installed here keep their XML and Event ID but have no message text; the explanation still works for known Event IDs.
- Exit codes: `0` ok, `2` usage, `3` the file could not be read as an event log, `4` the result could not be written. The reason goes to stderr.
- The file is never modified or uploaded; the result file lives in a per-import temp folder that is deleted afterwards.

## Limitations and future work

- Only the newest 20,000 events per file.
- No "Open with Pulse" file association or drag-and-drop yet.
- One file at a time; no merged view with live events.

## References

- [EvtQuery](https://learn.microsoft.com/windows/win32/api/winevt/nf-winevt-evtquery) — `EvtQueryFilePath`
- [ADR-007](ADR-007-event-log-only-v1.md) — Event Log as the v1 source
