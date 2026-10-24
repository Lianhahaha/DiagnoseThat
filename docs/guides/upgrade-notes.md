# Upgrade notes

## To 1.5.0

- Installer: `Pulse-Setup-1.5.0-windows-x64.exe`
- Product stamp is **`1.5.0`** (UI, PulseService)
- GPU load can read higher than in 1.4: it is now summed per engine like Task Manager
- Only one Pulse runs per Windows session; starting it again shows the running one

## To 1.4.3

- Installer: `Pulse-Setup-1.4.3-windows-x64.exe`
- Product stamp is **`1.4.3`** (UI, PulseService)
- The uninstaller now closes a running Pulse from the install folder before removing it

## To 1.4.2

- Installer: `Pulse-Setup-1.4.2-windows-x64.exe`
- Product stamp is **`1.4.2`** (UI, PulseService)
- New log files start with a UTF-8 byte order mark; today's existing file is unchanged

## To 1.4.1

- Installer: `Pulse-Setup-1.4.1-windows-x64.exe`
- Product stamp is **`1.4.1`** (UI, PulseService)
- Assistant ports: defaults 11434 (Ollama) and 1234 (LM Studio); change them in Settings → Privacy → Assistant
- Disk health is refreshed every 5 minutes, so it can take a moment to appear after the service starts

## To 1.4.0

- Installer: `Pulse-Setup-1.4.0-windows-x64.exe`
- Product stamp is **`1.4.0`** (UI, PulseService)
- Exports are written to **Downloads\Pulse** (earlier ones stay in Documents\Pulse)
- *Mask personal details in exports* is on by default (Settings → Privacy)
- Notification repeat interval default is 60 minutes; a value you set yourself is kept

## To 1.3.0

- Installer: `Pulse-Setup-1.3.0-windows-x64.exe`
- Product stamp is **`1.3.0`** (UI, PulseService)
- **AI Integration (PulseMCP) is removed** ([ADR-013](../architecture/decisions/ADR-013-remove-pulsemcp.md)); the local **Assistant** stays
- Setup closes any running PulseMCP and deletes `PulseMCP.exe`, `runtime\` and `mcp\` (~100 MB)
- On first launch Pulse removes the `pulse` entries it had added to AI client configs (backups are kept next to each file)
- Leftovers from earlier installs are cleaned up: `service\PulseService.pdb` and `redist\`

## To 1.2.0

- Installer: `Pulse-Setup-1.2.0-windows-x64.exe`
- Product stamp is **`1.2.0`** (UI, PulseService, PulseMCP)
- Midnight redesign ([ADR-012](../architecture/decisions/ADR-012-midnight-visual-identity.md)); no settings migration required
- After upgrading from **1.1.0**:
  1. Confirm Diagnose → Service shows **1.2.0**
  2. The accent starts on lime once; pick another under **Settings → Appearance** if you prefer
  3. If you use MCP: **Settings → AI Integration → Unregister → Register**

## To 1.1.0

- Installer: `Pulse-Setup-1.1.0-windows-x64.exe`
- Product stamp is **`1.1.0`** (UI, PulseService, PulseMCP)
- After upgrading from **1.0.0**:
  1. Confirm Diagnostics → App / Service show **1.1.0**
  2. Open **Assistant** from the sidebar to select Local AI provider/model if desired
  3. If you use MCP: **Settings → AI Integration → Unregister → Register**

## To 1.0.0 (stable)

- Installer: `Pulse-Setup-1.0.0-windows-x64.exe`
- Product stamp is **`1.0.0`** (no beta label)
- PulseMCP **1.0.0** (bundled private Node — no system Node.js)
- After upgrading from any **0.3.x-beta**:
  1. Confirm PulseService is Running (Diagnostics → Service)
  2. **Settings → AI Integration → Unregister → Register** so Cursor / Claude point at the new `PulseMCP.exe`
  3. Fully quit and reopen AI clients

## Historical betas

### 0.3.2-beta

- PulseMCP `0.7.2`: named-pipe instance limit 32, Claude Store config path, underscore MCP tool wire names

### 0.3.1-beta

- PulseMCP private Node runtime — **no system Node.js**. Re-Register after upgrading from **0.3.0-beta**

### 0.3.0-beta

- MCP M2–M7 productization (AI Integration page, policy file, registration)

Full notes: [docs/releases/](../releases/).
