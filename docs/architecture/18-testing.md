# 18 — Testing Strategy

## Principles

- Fast, deterministic CI
- Golden fixtures for Event Log → PulseEvent Level 1/2
- No live ETW/kernel in CI
- No WMI indication tests in v1 CI
- No fabricated metrics in tests or fixtures

## CI (`.github/workflows/ci.yml`)

Runs on `push` to `master`/`main` and on pull requests:

| Job | Commands |
|-----|----------|
| **service** | CMake configure + Release build + `ctest -C Release` (all registered service tests) |
| **flutter** | `flutter analyze` + `flutter test` in `apps/pulse_app` |
| **store_msix** | Builds and validates the Store MSIX (`package_msix_store.ps1`) |

Service `ctest` targets today include `pulse_wire_tests`, `event_humanizer_tests`, `event_intelligence_tests`, `crash_explainer_tests`, the inventory collector tests and `ipc_client_thread_lifetime_test`. Release packages are built by `release.yml` (see [25](25-beta-release.md)), not by CI. Optional IPC ping tools are build artifacts, not CI gates.

## Unit

- EventLogNormalizer + Enricher (embedded rules)
- Frame codec / wire tests
- MPSC / live queue drop behavior
- Dedup by channel+record_id
- Event humanizer + intelligence rules
- Crash explainer: Kernel-Power 41, bug check 1001, WHEA (`crash_explainer_tests`)

## Integration

- Pipe handshake
- SubscribeLive + QueryRange with fixture-backed store
- Slow-client live drop does not block writer/ingest (simulated)

## Flutter

- Controllers with mock IPC
- Timeline shows Level 1 only
- I/O isolate boundary covered by unit/integration where practical

## Manual pre-release

- Service install, app connect, Application Error appears as human summary
- Detail Level 2 / expand Level 3
- Kill service → reconnect + gap fill
- Idle CPU near zero with Event Log only
- Multi-channel Timeline populates (not System-only)
- R1: Diagnostics budgets card; advanced toggle; soak script dry-run sample; see [35](35-product-stability.md)

## Related Documents

- [21 — Event Viewer Integration](21-event-viewer-integration.md)
- [33 — PulseMCP](33-mcp-bridge.md) (historical; removed in 1.3, ADR-013)
- [34 — Engineering roadmap](34-engineering-roadmap.md)
