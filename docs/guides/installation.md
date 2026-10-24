# Pulse installation

## Recommended

1. Download `Pulse-Setup-1.5.0-windows-x64.exe` from [GitHub Releases](https://github.com/Regncreative/Pulse/releases/tag/v1.5.0)
2. Run the Setup (UAC). It installs Visual C++ runtime, registers PulseService, and launches Pulse.
3. Optional: install Ollama or LM Studio yourself to use the local **Assistant**.

## Portable payload

Advanced users can use the `dist\Pulse\` folder (or ZIP of that tree) from packaging:

- `Pulse.exe` — UI
- `service\PulseService.exe --install-start` (elevated) — **required**; unzip alone is not enough

This is **not** a true portable edition. PulseService must be registered with Windows (SCM). Prefer the Setup installer for stable installs. Details: [40 — Portable ZIP vs Windows Service](../architecture/40-portable-vs-service.md).

## Uninstall

Use Windows Apps & features / the Start menu Uninstall entry. Uninstall:

- Stops and removes PulseService
- Leaves `%LOCALAPPDATA%\Pulse\` logs unless you delete them manually
