# Pulse Windows installer

End-user deliverable is built with **Inno Setup 6**:

```text
tools/installer/Pulse.iss  →  dist/Pulse-Setup-1.5.0-windows-x64.exe
```

## Behavior

1. UAC elevation (`PrivilegesRequired=admin`)
2. Install files under `%ProgramFiles%\Pulse`
3. Quiet `VC_redist.x64.exe` when present
4. `PulseService.exe --install-start` (SCM register + start + verify RUNNING)
5. Launch `Pulse.exe`

No PowerShell scripts are required for installation.

## Build

```powershell
.\tools\scripts\package_beta.ps1
```

Requires `ISCC.exe` (Inno Setup 6).

Requires Inno Setup **6.7 or later** for the dark wizard style.

## Branding

The wizard uses the Midnight look (forced dark style, `#08080A` background,
lime Pulse mark). Images live in `branding/` and are generated, not drawn by
hand:

```powershell
python tools\installer\make_wizard_images.py
```

The script writes one side-panel and one small image per DPI scale (100–250 %)
from the app's theme colors and bundled Geist font (requires Pillow).
