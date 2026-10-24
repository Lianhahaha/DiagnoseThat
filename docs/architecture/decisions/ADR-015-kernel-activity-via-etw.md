# ADR-015: Kernel activity in the Timeline via ETW

**Status:** **Proposed** (2026-10-14) — accept after the prototype in *Validation* passes

**Date:** 2026-10-14

**Amends:** [ADR-007](ADR-007-event-log-only-v1.md) for the Timeline (Event Log stays the default source). Builds on [ADR-009](ADR-009-health-network-etw.md), which already runs one ETW session for System Health.

---

## Context

The long-term goal is to explain what Windows does below the Event Log: processes starting and exiting, drivers and devices misbehaving, why the PC froze for two seconds. ADR-007 kept v1 on the Event Log only.

Three ways to see kernel activity were compared:

| | ETW, tier 1 | ETW, tier 2 | Own kernel driver |
|---|---|---|---|
| Sees | Process / thread / image load, file, registry, network events from manifest providers (e.g. `Microsoft-Windows-Kernel-Process`) | Tier 1 + context switches, DPC/ISR, disk latency, sampled stacks (system logger) | Everything |
| Runs as | LocalService (today's service) | Administrator or LocalSystem | Kernel |
| Effect on Windows | Read-only | Read-only | A bug is a blue screen |
| Store | Same packaged service as today | Needs elevation or a restricted capability | MSIX cannot ship drivers |
| AGENTS.md | Fits | Fits with explicit user action | Conflicts (hooks, signing, risk) |

Evidence: `PulseHealthNet` (ADR-009) already runs a real-time session with `Microsoft-Windows-Kernel-Network` under LocalService and passed Store certification.

A kernel driver needs a company EV certificate, Microsoft attestation signing, HVCI compatibility and carries BSOD and privilege-escalation risk. It is **out of scope** unless a concrete gap that ETW cannot cover is documented.

## Decision

1. **ETW only. No kernel driver.**
2. **Tier 1 first** (target 1.5): a Pulse-owned real-time session under LocalService for process lifecycle (`Microsoft-Windows-Kernel-Process`: start, exit with exit code, image load), shown as human Timeline events ("Chrome started", "Chrome exited (code 0)") and correlated with crash events (WER, bug checks; see the crash explainer).
3. **Later tier 1 domains** (file, registry, network activity) are opt-in per domain, filtered by keywords and process, and off by default.
4. **Tier 2 is on demand only:** the user starts a time-boxed "deep capture" (for example 30–60 s) that asks for UAC, records, stops and is explained. No permanent LocalSystem service; `localSystemServices` is not requested for the Store.
5. **Session rules** (same as ADR-009): Pulse-named sessions, at most two at a time (trace sessions are a limited resource shared by every app; only 8 system logger sessions can run, two of them reserved by Windows); stop an orphaned session by name on start; per-instance names so two Pulse processes never stop each other's session.
6. **Budgets** (AGENTS.md): idle CPU near zero, RAM < 150 MB. Lost events (buffer overruns) are counted and shown in Diagnostics, never hidden. Event decoding happens off the ETW callback thread.
7. **Privacy:** file paths, registry keys and command lines are personal data; they stay on the PC and go through the export masking (`PersonalDataRedactor`, Settings → Privacy).
8. Decode events through TDH with field names, never fixed offsets: kernel event layouts differ between Windows 10 and 11.

## Validation (prototype before Accepted)

- [ ] `Microsoft-Windows-Kernel-Process` can be enabled from a LocalService session on Windows 10 and 11 (Kernel-Network can; each provider has its own security descriptor).
- [ ] Measured CPU / RAM / events per second with process lifecycle on, on a busy desktop.
- [ ] Lost-event counter visible in Diagnostics.
- [ ] Store build with the session still passes local MSIX validation.

## Consequences

- New collector beside `network_etw_engine`; new humanizer rules for kernel events; Timeline sources get an "ETW" kind.
- Docs 20 (ETW integration) and 24 updated when tier 1 lands.

## References

- [StartTrace](https://learn.microsoft.com/windows/win32/api/evntrace/nf-evntrace-starttracea) — who can control sessions
- [Configuring and starting a system logger session](https://learn.microsoft.com/windows/win32/etw/configuring-and-starting-a-systemtraceprovider-session)
- [ADR-007](ADR-007-event-log-only-v1.md), [ADR-009](ADR-009-health-network-etw.md)
