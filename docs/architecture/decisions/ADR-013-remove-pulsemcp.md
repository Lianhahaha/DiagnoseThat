# ADR-013: Remove AI Integration (PulseMCP)

**Status:** **Accepted** (2026-10-13)

**Date:** 2026-10-13

**Supersedes:** [ADR-010](ADR-010-mcp-first-class-product.md) — PulseMCP as a first-class product component

---

## Context

Pulse has two AI features:

| Feature | What it does | Runtime |
|---------|--------------|---------|
| **Assistant** | In-app chat with a local model (Ollama / LM Studio), localhost only | Dart, inside `Pulse.exe` |
| **AI Integration (PulseMCP)** | MCP server so external clients (Claude Desktop, Cursor, VS Code, Windsurf, Cline) can query Pulse diagnostics | Node.js, shipped as a private runtime |

PulseMCP accounted for about **100 MB** of the ~150 MB install (Node runtime 68 MB, server and dependencies 34 MB) and for a large share of packaging, CI and support work: a second IPC client, a status daemon, client registration in third-party config files, and recurring bugs (pipe-slot leaks, daemon lifecycle, path quoting).

The product owner decided that the local Assistant is the AI story for Pulse, and that the MCP bridge does not justify its size and maintenance cost.

## Decision

1. Remove PulseMCP from the product: no Node runtime, no MCP server, no Settings → AI Integration, no Diagnose → MCP.
2. Remove `apps/pulse_mcp`, the `PulseMCP.exe` launcher, its packaging and verification scripts, and the CI job. The code remains in git history (tag `v1.2.0`).
3. Keep the **Assistant** unchanged. Its status tool is renamed `mcp_self` → `pulse_status`.
4. Migrate existing installs cleanly:
   - **Setup (classic):** closes running PulseMCP processes (Restart Manager via `RegisterExtraCloseApplicationsResource`) and deletes `PulseMCP.exe`, `PulseMCP.cmd`, `runtime\` and `mcp\`.
   - **App, first launch (classic and Store):** `LegacyMcpCleanup` removes the `pulse` server entries Pulse added to AI client configs — only entries recorded as `registeredByPulse` in `%LOCALAPPDATA%\Pulse\mcp\client-registrations.json`, after backing up each file — then deletes `%LOCALAPPDATA%\Pulse\mcp` and `logs\pulsemcp`.
   - **Store build:** strips any stale PulseMCP files from the MSIX staging folder.

## Consequences

**Positive**

- Install size drops by ~100 MB (classic) and the Store package shrinks accordingly.
- One IPC client (the app) instead of three kinds; fewer moving parts in packaging and CI.
- No third-party config files are written by Pulse any more.

**Negative**

- Users of Claude Desktop, Cursor, VS Code, Windsurf or Cline lose the Pulse tools in those apps. The local Assistant remains.
- Reports first-class work (R4) can no longer reuse the PulseMCP TypeScript report writers; Reports stay on the Dart generators.

**Neutral**

- If an external integration is wanted again, a future ADR should prefer an approach without a bundled runtime (for example a small native MCP server) over reintroducing Node.js.

## Related

- [ADR-010](ADR-010-mcp-first-class-product.md) (superseded)
- [33 — MCP bridge](../33-mcp-bridge.md) (historical)
- `apps/pulse_app/lib/application/legacy_mcp_cleanup.dart`
