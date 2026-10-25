# DiagnoseThat installation

## Recommended

1. Download `DiagnoseThat-Setup-1.5.0-windows-x64.exe` from [GitHub Releases](https://github.com/Lianhahaha/DiagnoseThat/releases/tag/v1.5.0)
2. Run the Setup (UAC). It installs Visual C++ runtime, registers PulseService, and launches DiagnoseThat.
3. Optional: install Ollama or LM Studio yourself to use the local **Assistant**.

## Portable payload

Advanced users can use the `dist\DiagnoseThat\` folder (or ZIP of that tree) from packaging:

- `DiagnoseThat.exe` — UI
- `service\PulseService.exe --install-start` (elevated) — **required**; unzip alone is not enough

This is **not** a true portable edition. PulseService must be registered with Windows (SCM). Prefer the Setup installer for stable installs. Details: [40 — Portable ZIP vs Windows Service](../architecture/40-portable-vs-service.md).

## Uninstall

Use Windows Apps & features / the Start menu Uninstall entry. Uninstall:

- Stops and removes PulseService
- Leaves `%LOCALAPPDATA%\DiagnoseThat\` logs unless you delete them manually
