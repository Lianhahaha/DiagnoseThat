# ADR-012: Midnight visual identity and shell redesign

**Status:** **Accepted** (2026-10-12)

**Date:** 2026-10-12

**Revises:** [34-engineering-roadmap.md](../34-engineering-roadmap.md) — "Theme redesign (excluded)" non-goal

**Builds on:** [31-ui-design-system.md](../31-ui-design-system.md) (ThemeExtension, `PulseThemeScope`), [32-ux-redesign-milestone.md](../32-ux-redesign-milestone.md)

---

## Context

The frozen engineering roadmap keeps theme redesign out of scope until an ADR changes direction. The product owner reviewed two visual directions as clickable mockups:

1. A faithful Windows 11 Fluent reskin (Mica, 4 px controls, Segoe UI Variable). Rejected: too close to the current UI.
2. **Midnight**: a dark-first identity with a signature accent, pill controls, an icon rail, a story-style Timeline and a bento Overview. Approved.

Mockups: the Pulse Redesign design canvas (Timeline, Overview, Inventory, Reports, Diagnose, Assistant, Settings).

The constitution in [AGENTS.md](../../../AGENTS.md) is unchanged: read-only, local-first, human language first, Level 1 → 2 → 3 hierarchy.

---

## Decision

### D1 — Tokens, not rewrites

Midnight ships through the existing `PulseThemeData` / `PulseTokens` system. Pages keep reading ambient tokens; the palette, radii, typography and accent presets change underneath them. Layout changes land page by page in separate commits.

### D2 — Palette (dark)

| Token | Value | Role |
|-------|-------|------|
| `canvas` | `#08080A` | Window background |
| `surface` | `#111114` | Panels and cards |
| `surfaceElevated` | `#17171B` | Selected rows, nested panels |
| `surfaceHover` | `#1E1E23` | Hover, chips |
| `stroke` | white at 8 % | Panel borders |
| `textPrimary` / `Secondary` / `Tertiary` | `#F4F4F5` / `#A1A1AA` / `#8B8B94` | Text (all ≥ 4.5:1 on `surface`) |
| `accent` (default) | `#C8F04A` lime | Live state, selection, primary actions only |
| Severity | critical `#FF4D5E`, error `#FF6B6B`, warning `#FFB224`, info `#6BA4FF`, success `#34D399` | Events and status |

Information severity is blue, not the accent, so the signature color never reads as an event level. Light mode stays first-class with a neutral zinc palette and a darkened accent for contrast.

### D3 — Accent presets

New `lime` preset becomes the default. `blue`, `green`, `purple`, `orange` and `custom` remain available. The preference moves to a new key (`appearance.accent_preset.midnight`), so every install starts on lime after the upgrade: accents chosen against the old palette were tuned for different surfaces, and the old default was saved for most users without an explicit choice. The old key is left untouched and ignored.

### D4 — Typography

Geist (UI) and Geist Mono (numbers, identifiers, XML) are bundled under `apps/pulse_app/assets/fonts/` with their SIL Open Font License. Fonts are never fetched at runtime (offline-capable, no network).

### D5 — Shape

Panels 18 px, cards 18 px, rows 12 px, controls pill-shaped. Elevation is flat in dark mode: separation comes from surface steps and hairline borders, not shadows.

### D6 — Shell

The 256 px sidebar becomes a 76 px icon rail with labels under icons. Pages sit in rounded panels on the canvas with a 12 px gutter. Keyboard shortcuts, command palette and page indices are unchanged.

### D7 — Page layouts (phased)

| Page | Midnight layout |
|------|-----------------|
| Timeline | Plain-language hero, activity strip, story feed with incidents, Explained / Technical / Raw XML inspector |
| System Health → Overview | Bento grid: health summary, CPU chart, memory ring, GPU, network, storage, last-hour summary |
| Inventory, Reports, Diagnose, Assistant, Settings | Restyled in place; structure follows the mockups |

Every layout keeps data honest: no fabricated metrics, empty states when PulseService is offline.

---

## Consequences

- Visual regressions are expected in screenshots; README images must be refreshed after the page phases land.
- `PulseTokens` radii change globally; widgets that hard-code radii or colors should migrate to tokens when touched.
- Font assets add about 800 KB to the installer and MSIX.
- Roadmap waves are not reordered; this ADR only lifts the theme exclusion.

## Rejected alternatives

| Alternative | Why not |
|-------------|---------|
| Fluent reskin only | Product owner judged it not modern enough |
| `google_fonts` package | Downloads fonts at runtime; violates offline and no-network principles |
| Rewrite every page at once | Too risky for 25k lines of UI; token-first keeps every commit shippable |
