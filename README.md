# DiagnoseThat

**See what Windows is really doing.**

A Windows diagnostics app that turns the Event Log into plain language. Crashes, blue screens, unexpected restarts and service failures — explained. Fully offline: no telemetry, no account, nothing leaves your PC.

> **Based on [Pulse](https://github.com/Regncreative/Pulse) by [Regncreative](https://github.com/Regncreative).**
> Original code © 2026 Regncreative, licensed under the [MIT License](LICENSE).
> This repository is a fork/refactor; all original copyright and permission notices are retained in `LICENSE`.

## Status

Work in progress. Upstream code imported; UI refactor and improvements in progress.

## Features

- **Timeline** — live Windows Event Log feed in plain language, with correlated incidents (app crash + its report, blue screen + restart)
- **Crash Detective** — blue screens and sudden restarts explained: stop code name, usual causes, what to check
- **System Health** — CPU, memory, GPU, disk and network monitoring, per-process breakdown
- **Inventory** — motherboard, BIOS, hardware, drivers, installed software, Windows services
- **Reports** — export health and diagnostics reports as JSON, CSV, HTML or PDF (personal data masked)
- **Assistant (optional)** — ask about this PC in plain language via a local model in Ollama or LM Studio (localhost only)

Read-only by design: no cleaner, optimizer, or system-modifying features.

## Build from source

Prerequisites: Visual Studio 2022+ Build Tools with C++ (CMake, Ninja), Flutter (stable), Inno Setup 6.

See [BUILD.md](BUILD.md) and [DEVELOPMENT.md](DEVELOPMENT.md).

```
# Service in console mode (no installation needed)
.\tools\scripts\run_service_console.ps1

# App, in a second terminal
.\tools\scripts\run_app.ps1
```

## Documentation

- Product principles and development rules: [AGENTS.md](AGENTS.md)
- Architecture and ADRs: `docs/architecture/`
- Installation, troubleshooting, security: `docs/guides/`
- Version history: [CHANGELOG.md](CHANGELOG.md)

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) first. Changes must stay observation-only (see "What DiagnoseThat is NOT" in AGENTS.md).

## License

[MIT](LICENSE) © 2026 [Regncreative](https://github.com/Regncreative).
