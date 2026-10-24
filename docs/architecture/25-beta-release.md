# Pulse release packaging

## Goal

Ship a **normal Windows installer** so a clean PC reaches Connected without PowerShell.

## Primary deliverable

`dist/Pulse-Setup-1.5.0-windows-x64.exe` (Inno Setup)

The installer (admin / UAC):

1. Copies Pulse into `Program Files\Pulse`
2. Quietly installs `VC_redist.x64.exe` when present
3. Runs `PulseService.exe --install-start` (register auto-start service + start + verify)
4. Offers to launch `Pulse.exe`

No `.ps1`. No ExecutionPolicy. No manual service steps.

## Produce a package

Prerequisites: Flutter, VS C++ Build Tools, [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`winget install JRSoftware.InnoSetup`).

```powershell
.\tools\scripts\package_beta.ps1
```

| Output | Role |
|--------|------|
| `dist/Pulse-Setup-1.5.0-windows-x64.exe` | **End-user installer** |
| `dist/Pulse/` | Payload used by Inno |
| `dist/Pulse-1.5.0-windows-x64.zip` | Optional payload archive (**not** a true portable SKU — see [40](40-portable-vs-service.md)) |

The script finds Visual Studio, the MSVC runtime and `vc_redist.x64.exe` through `vswhere`, so it works with Build Tools locally and with the Enterprise edition on GitHub runners.

## Release workflow (GitHub Actions)

[`.github/workflows/release.yml`](../../.github/workflows/release.yml) runs the same script on a clean `windows-latest` runner (Flutter pinned, Inno Setup installed if missing):

| Trigger | Result |
|---------|--------|
| **Actions → Release → Run workflow** | Setup.exe, zip and `SHA256SUMS.txt` as a workflow artifact (for testing) |
| Push tag `vX.Y.Z` | Same artifact, plus a **draft** GitHub release with the files attached and `docs/releases/vX.Y.Z.md` as notes |

The workflow fails when `package_beta.ps1`, `Pulse.iss` and the tag disagree on the version. A draft is never published automatically: download it, install it on a test machine, then publish.

## Signing releases (SignPath Foundation)

Not wired in yet; the application to SignPath Foundation is in review. Once approved:

1. In SignPath, create the project with an artifact configuration that signs `Pulse.exe` and `service\PulseService.exe` inside the payload zip, and one for the Setup.exe. Use a signing policy that only accepts builds from this repository's `release.yml` (GitHub trusted build system).
2. Add the repository secret `SIGNPATH_API_TOKEN` and the organization id as a variable.
3. Split `package_beta.ps1` into payload and installer stages, then in `release.yml`: upload the unsigned payload, sign it with `signpath/github-action-submit-signing-request` (wait for completion), build Setup.exe from the signed payload, and sign Setup.exe the same way.
4. When releases are signed, move the default export folder back to Documents (`apps/pulse_app/lib/platform/export_writer.dart`; Controlled folder access blocks unsigned apps there).

## Fresh machine checklist

1. Copy **only** the Setup `.exe` to a clean Windows 10/11 PC
2. Double-click Setup → UAC Yes
3. Finish wizard (Launch Pulse checked)
4. Confirm status shows Connected / Live within a few seconds
5. If Offline: use in-app **Start PulseService** / **Repair / Install** (UAC) — do not require Services.msc
6. Timeline, System Health, Inventory, and Reports populate as expected
7. Reboot → PulseService still Running (auto-start) → Pulse reconnects
8. Optional: install Ollama or LM Studio for the local **Assistant**
9. Open **Diagnostics** → confirm service version **1.5.0**

Full stability procedures: [35-product-stability.md](35-product-stability.md). Release notes: [v1.5.0.md](../releases/v1.5.0.md).

## Service CLI (developers)

```text
PulseService.exe --install-start   Elevate: install/update auto-start + start + wait RUNNING
PulseService.exe --uninstall       Elevate: stop + delete service
PulseService.exe --console         Dev foreground mode (no SCM)
```

## Runtime dependencies

See [26-windows-runtime-deps.md](26-windows-runtime-deps.md).

## Timeline channels (current)

Timeline uses the **diagnostics multi-channel set** (not System-only). Clients that still send `channel=System` receive that multi-channel diagnostics snapshot; see [21-event-viewer-integration.md](21-event-viewer-integration.md) and [07-timeline-engine.md](07-timeline-engine.md).

## Known limits (stable)

- Not code-signed yet (SmartScreen may warn)
- `flutter build windows --release` may need ASCII staging path (`package_beta.ps1` handles this)
- Pulse is distributed via **GitHub Releases**, not the Microsoft Store
- ZIP payload is not a true portable SKU ([40](40-portable-vs-service.md))
