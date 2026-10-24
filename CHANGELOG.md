# Changelog

All notable changes to Pulse are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] — 2026-10-20

### Added

- System Health lists every GPU (for example integrated + dedicated) with its load and memory; the Assistant and health reports include them (#9)
- Timeline: "Hide events like this" hides an event type (provider + Event ID) from the list and its counts; a "hidden events" counter shows them on demand and Settings → Timeline → Hidden events brings them back. Reports and exports are unchanged (#25)
- Starting Pulse while it runs brings the running window forward instead of opening a second one

### Changed

- GPU load is computed like Task Manager: each engine summed over its processes, the GPU showing its busiest engine. Pulse used the busiest single process, which read low when several shared an engine (#9)
- A critical event of a hidden type raises no desktop notification (#25)

## [1.4.3] — 2026-10-18

### Added

- Timeline date filter: *Custom…* picks a from / to date and time; kept in saved searches (#15)
- Assistant replies render Markdown: bold, italic, inline code, headings, lists and code blocks (links are not clickable)

### Fixed

- Pulse could crash in flutter_windows.dll when it closed (#32)
- Resizable BAR showed "Not supported" although Windows offers no way to read it; it now shows *Unknown* (#31)
- Assistant: Enter now sends the message; Shift+Enter adds a line
- Uninstalling left a running Pulse in the tray and its files behind; the uninstaller now closes it first
- Task Manager listed Pulse as "Windows Diagnostics"; it now shows *Pulse*
- Disk health: "Power-On Hours" is now labelled *Power-on time*, matching its days-and-hours value

## [1.4.2] — 2026-10-18

### Fixed

- Disk panel header and overview showed only the system drive's capacity; they now total every local drive (#29)
- Disk identity (interface, model, serial, firmware, partition style, sector size, TRIM) was blank because the disk was opened with read access; it is now read without it (#29)
- Disk identity now describes the disk holding Windows instead of PhysicalDrive0, titled *System disk* (#29)
- Logs showed localized text as mojibake in Notepad and PowerShell 5; new service and app log files start with a UTF-8 byte order mark (#29)

## [1.4.1] — 2026-10-18

### Added

- **Health for every disk** in System Health → Storage → SMART: model, bus, health and temperature for each disk; for NVMe drives also wear, spare capacity, power-on hours, unsafe shutdowns, media errors and data read / written. NVMe critical warnings are spelled out (#12, #20)
- **What woke the PC**: the wake event names the device ("PC Woke Up: Intel(R) Ethernet Connection") or the scheduled task behind a wake timer, with how to stop it
- **Secure Boot update events explained** (TPM-WMI): applied updates are marked as routine, and errors such as the SBAT update failure (1796) say that Windows retries at the next restart. Follows Microsoft's Secure Boot DB and DBX update events article (#25)
- **Deeper Assistant diagnostics** (#17): process details include command line, elevation, architecture, start time and total CPU time; processes can be ranked by private bytes; new read-only `windows_services` tool (for example "is Windows Search running?")
- **Assistant ports and LM Studio API key** (Settings → Privacy → Assistant): change the Ollama or LM Studio port on this PC; the optional key is kept in Windows Credential Manager, never in settings, logs or exports (#21)
- "Local AI not found" now lists what Pulse checked, e.g. *LM Studio server is not running on 127.0.0.1:1234. Start it in LM Studio → Developer.*

### Fixed

- Disk temperature and SMART data were missing: the service opened disks with read access, which the LocalService account does not have. Disk health is now read without it and refreshed every 5 minutes
- Assistant replies from Ollama repeated themselves ("HelloHello!Hello! I…"); LM Studio could drop text split across network packets
- The Assistant kept showing "Connected" after Ollama or LM Studio was closed; a failed send now re-checks the runtime

### Security

- The Assistant connects only to `127.0.0.1` / `::1`: `localhost` is refused, redirects are never followed and proxies are ignored. There is no option to reach another computer or a cloud service

## [1.4.0] — 2026-10-14

### Added

- **Blue screen and sudden restart explanations** from the event data: Kernel-Power 41 tells a blue screen (with stop code name), a forced power-off and a power loss apart; bug check 1001 shows the stop code, usual cause and dump path (works on any Windows language); WHEA-Logger fatal vs corrected hardware errors. Timeline groups Kernel-Power 41 with its bug check as one incident
- **Open an .evtx from another PC** on the Timeline (`PulseService.exe --read-evtx`, run as the user; works while the service is offline) ([ADR-014](docs/architecture/decisions/ADR-014-open-exported-evtx.md))
- **Mask personal details in exports** (Settings → Privacy, on by default): user and computer names, profile paths, account SIDs, e-mail, IP and MAC addresses, serial numbers
- **Update notice** for the GitHub edition (Settings → Updates): manual check plus an optional weekly check, off by default; never downloads anything
- Release workflow in GitHub Actions (draft release with SHA-256 checksums)

### Changed

- Product version stamped **1.4.0** across UI, PulseService, installer and MSIX
- Exports go to **Downloads\Pulse** by default (Documents is blocked for unsigned apps by Controlled folder access)
- Default notification repeat interval 15 → 60 minutes; one toast per alert kind on screen
- README: privacy first, comparison with Event Viewer / Reliability Monitor, how Pulse is built; new security guide
- Packaging finds Visual Studio and the MSVC runtime with vswhere

### Fixed

- Timeline order: days-old events could appear above recent ones (unstable sort past 32 events)
- Exports failed with `PathNotFoundException` under Controlled folder access
- Store edition notifications showed a raw package id instead of the app name
- A stuck start-up step could skip the start-with-Windows setup on the first launch after Setup

## [1.3.0] — 2026-10-13

### Removed

- **AI Integration (PulseMCP)** — the MCP bridge for Claude Desktop, Cursor, VS Code, Windsurf and Cline, its private Node runtime (~100 MB), Settings → AI Integration and Diagnose → MCP ([ADR-013](docs/architecture/decisions/ADR-013-remove-pulsemcp.md)). The local Assistant (Ollama / LM Studio) stays. On first launch Pulse removes the client entries it had added (backed up first); Setup deletes the old files

### Changed

- Product version stamped **1.3.0** across UI, PulseService, installer and MSIX
- Lime Midnight app icon for Pulse.exe, taskbar, tray and Store tile
- Midnight-styled installer: dark wizard, lime Pulse mark
- The app log is written to `%LOCALAPPDATA%\Pulse\logs\app\` (JSON lines, 14 days) and records uncaught errors
- Assistant status tool renamed `mcp_self` → `pulse_status`
- The UAC prompt for Start / Stop / Restart service opens in front of Pulse; a cancelled prompt and a blocked request (error 5) now show different messages
- Inventory state traces moved to debug logging
- LICENSE is detected as MIT on GitHub; README documents the code signing policy

### Fixed

- Pulse.exe could crash (`flutter_windows.dll`, 0xc0000005) after **Start / Stop / Restart service**: the UAC launch and wait ran on the UI thread
- PulseService connections leaked until the service logged "pipe slots exhausted" and Diagnose → Connected clients kept climbing (PulseMCP handshake failures; Restart IPC Connection)
- "Latest" badge went to a pinned event instead of the newest one
- Setup left ~41 MB behind on upgrade (`PulseService.pdb`, `redist\VC_redist.x64.exe`) and an empty `redist` folder; the taskbar icon could stay blank after an icon change
- Packaging could hang on a leftover smoke-test process

## [1.2.0] — 2026-10-12

### Changed

- Product version stamped **1.2.0** across UI, PulseService, installer, MSIX and PulseMCP
- **Midnight visual identity** ([ADR-012](docs/architecture/decisions/ADR-012-midnight-visual-identity.md)): near-black canvas, flat panels, lime signature accent, bundled Geist and Geist Mono fonts
- Icon rail replaces the sidebar; command search moves into the title bar
- Timeline: plain-language hero for the last hour, 24-hour activity strip, story-feed rows, and an Explained / Technical / Raw XML inspector
- System Health: Overview bento with system pulse, memory ring, CPU, GPU and network tiles
- Reports, Assistant, segmented controls and form fields restyled for Midnight

### Fixed

- System Health showed "Windows 10" on Windows 11 because the registry ProductName was never updated by Windows
- Assistant send icon was white on the accent fill and hard to read
- PulseService registered an unquoted image path (`C:\Program Files\…`), the classic unquoted service path issue; the path is now quoted and Diagnose no longer reports a path mismatch
- Diagnose showed build version 1.1.0 for the 1.2.0 service
- Microsoft Store package now embeds the full PulseMCP payload (launcher, private Node runtime and server); earlier Store builds could miss the server files

### Upgrade notes

- The accent preference is re-keyed: every install starts on the new lime accent once; pick another under Settings → Appearance
- Install over 1.1.0 using `Pulse-Setup-1.2.0-windows-x64.exe`
- See [docs/releases/v1.2.0.md](docs/releases/v1.2.0.md) and [docs/guides/upgrade-notes.md](docs/guides/upgrade-notes.md)

## [1.1.0] — 2026-08-13

### Added

- **Local AI Assistant** — Ollama / LM Studio chat with read-only diagnostic tools (no cloud AI, no system modification)
- Background mode with system tray, monitoring, and local Windows notifications for critical conditions
- System Health semantic utilization colors (green 0–49%, yellow 50–69%, orange 70–89%, red 90–100%)
- Assistant sidebar navigation, manual model selection, streaming replies, and session-only history
- Microsoft Store MSIX packaging with packaged `PulseService` (`desktop6:Service` / `packagedServices`)

### Changed

- Product version stamped **1.1.0** across UI, PulseService, installer, and PulseMCP
- Improved switch interaction, navigation, and System Health visualization

### Fixed

- Assistant composer clears after a successful send
- Persisted Local AI model can be changed from the chat header

### Upgrade notes

- Install over 1.0.0 using `Pulse-Setup-1.1.0-windows-x64.exe`
- Confirm Diagnostics → App / Service show **1.1.0**
- If you use MCP: **Settings → AI Integration → Unregister → Register**
- See [docs/releases/v1.1.0.md](docs/releases/v1.1.0.md) and [docs/guides/upgrade-notes.md](docs/guides/upgrade-notes.md)

## [1.0.0] — 2026-08-03

### Added

- First **stable** public release of Pulse for Windows 10/11
- Timeline with human-readable Event Log events, live monitoring, search, filters, and date presets
- System Health (CPU, memory, GPU, disk, network) with live charts
- Inventory (system, devices, software) via read-only Windows APIs
- Reports export (JSON, CSV, HTML, PDF)
- Diagnostics for PulseService, IPC, collectors, and PulseMCP
- Settings including optional **AI Integration** (PulseMCP) for Cursor and Claude Desktop
- Inno Setup installer that registers and starts PulseService

### Changed

- Product version stamped **1.0.0** (no beta channel label in UI or binaries)
- PulseMCP aligned to **1.0.0** with the product line
- Documentation and packaging updated from beta wording to stable release

### Security

- Observation-only: no injection, hooks, or OS modification
- Local-first: no telemetry, cloud, or accounts
- Elevation only for explicit service install / repair actions

### Upgrade notes

- Install over a previous beta using `Pulse-Setup-1.0.0-windows-x64.exe`
- Re-register AI clients after upgrade: **Settings → AI Integration → Unregister → Register**
- See [docs/releases/v1.0.0.md](docs/releases/v1.0.0.md) and [docs/guides/upgrade-notes.md](docs/guides/upgrade-notes.md)

## Prior pre-releases

Beta trains (`0.1.x-beta` … `0.3.2-beta`) are documented under [docs/releases/](docs/releases/).
