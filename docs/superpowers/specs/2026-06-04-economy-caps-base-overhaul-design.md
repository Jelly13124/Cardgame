# Economy Overhaul — Caps Currency + Two-Layer Base — Design

> Overnight build. HIGH RISK: touches `MetaProgress` save format and the home
> base scene UI. All save changes MUST be backward-compatible (missing keys
> default; never wipe an existing `user://meta.json`). UI is owner-verified in the
> morning — build it, smoke-gate boot, but it can't be visually verified headless.

**Goal:** Add a second permanent currency, **Caps (瓶盖)**, and restructure the
base into two layers: **Core builds/unlocks facilities** (structural, expensive,
harder to earn), **Caps buy granular tiered perks inside unlocked facilities**.
Add a new facility **义体医生 (Cyber Doctor)** that sells permanent attribute
boosts for Caps. Make Core meaningfully harder to acquire so maxing the base is
no longer trivial.

**Architecture:** `MetaProgress` owns both currencies and all base state
(facility unlock levels via Core + per-facility Caps-perk levels), persisted with
back-compat defaults. `RunManager` awards Caps from multiple sources during a run
and on extraction. The home base scene renders the two-layer UI. A run-start
consumer applies purchased Caps perks (e.g. attribute boosts) the same way
existing base upgrades already feed `start_new_run`.

**Tech Stack:** Godot 4.6, GDScript, JSON/const data, CSV i18n.

**Implementer note:** before editing, READ `run_system/core/meta_progress.gd`,
`run_system/core/run_manager.gd`, and `run_system/ui/home_base_scene.gd` to match
existing patterns (UPGRADE_ORDER, upgrade cost tables, save/load, the 5 current
facilities: Med Bay / Arsenal / Research Lab / Scrap Workshop / Command Center).

---

## Phase E1 — Caps currency plumbing (`meta_progress.gd`)

- Add `var caps: int = 0` to MetaProgress; persist in `save_progress` /
  `load_progress` with default 0 when absent (back-compat).
- `add_caps(n: int)`, `spend_caps(n: int) -> bool` (false if insufficient),
  `signal caps_changed(caps: int)` emitted on change.
- Smoke. No UI yet.

## Phase E2 — Caps earning (multi-source, `run_manager.gd`)

Wire Caps awards (caps accrue during the run into a run-scoped counter, banked to
MetaProgress on extract/victory so a death loses unbanked caps — mirror how Core
is handled; confirm against existing Core flow):
- **Combat win:** small fixed award (normal fight ~6, configurable const).
- **Elite / Boss:** larger (elite ~18, boss ~45, consts).
- **Extraction / victory:** convert leftover run **gold → caps** at a ratio
  (`GOLD_PER_CAP := 10`, floor division), banked alongside Core.
- Banking: extend the existing run-end/extract path that grants Core to also
  grant Caps. Death (no extract) banks nothing (same rule as Core safe-cells —
  confirm).
- Constants grouped + commented for easy tuning. Smoke.

## Phase E3 — Core harder (data retune)

- Raise existing base-upgrade Core costs (the 5 facilities) — roughly ~1.6–2×
  current per tier; keep monotonic. (Implementer: update the cost table in
  `meta_progress.gd` / wherever costs live.)
- Lower Core income: reduce the per-boss Core reward (the main Core source) by
  ~30–40% so the new Caps + higher costs make maxing a long-term goal.
- Keep changes in data/consts; document old→new in the commit. Smoke +
  `content-balance` sanity note (economy curve).

## Phase E4 — Cyber Doctor facility + Caps-perk model

- **Facility unlock (Core):** new facility `cyber_doc` (义体医生) unlocked for
  **300 Core** (one-time structural unlock). Stored as a facility-unlocked flag
  in MetaProgress (back-compat default locked).
- **Caps perks (per facility):** a perk = a repeatable purchase priced in Caps
  with an escalating cost. Model generically so other facilities can adopt it:
  `caps_perk_levels: Dictionary` in MetaProgress (perk_id → level), with
  `caps_perk_cost(perk_id, level)` (e.g. base 300 caps, +150 per level) and
  `buy_caps_perk(perk_id) -> bool` (checks facility unlocked + caps, increments).
- **Cyber Doctor perks:** `cyber_str`, `cyber_con`, `cyber_int`, `cyber_luck`,
  `cyber_charm` — each level grants +1 to that base attribute at run start.
  Optional per-perk level cap (e.g. 3) to bound power.
- **Run-start consumer:** in `RunManager.start_new_run`, after applying hero
  `starting_attributes` + existing Starter Boost, add the purchased Cyber Doctor
  attribute levels to `base_attributes` (then `recompute_attributes`). This is the
  effect-consumer half of the wiring rule.
- Smoke.

## Phase E5 — Home base UI (two-layer)

`run_system/ui/home_base_scene.gd` (UI — **owner verifies in the morning**):
- Show both balances in the top bar: **Core** and **Caps** (with icons/labels;
  caps icon art may be a placeholder — Codex will redo caps art per owner).
- Facility panels show a **lock/unlock state**: locked facilities show their Core
  unlock cost + an Unlock button (spends Core); unlocked facilities show their
  Caps-perk options.
- **Cyber Doctor panel:** once unlocked, list the 5 attribute perks with current
  level, next-level Caps cost, and a Buy button (spends Caps, calls
  `buy_caps_perk`). Disable/grey when unaffordable or at cap.
- Keep the existing 5 facilities working; render their Core upgrades as before but
  reflect the new (higher) costs. Adding Caps-perks to the existing 5 is OPTIONAL
  stretch — Cyber Doctor is the required Caps sink for this pass.
- Live-refresh on `caps_changed` / existing core/upgrade signals.
- Smoke (boot clean); visual correctness deferred to owner.

## Save migration

`load_progress` must tolerate an old `meta.json` with none of the new keys: `caps`
defaults 0, `cyber_doc` locked, `caps_perk_levels` empty, raised costs apply
going forward. Never delete/overwrite the file on read. Write the new keys on next
`save_progress`. Add a one-line migration comment.

## Smoke / gates
`bash scripts/smoke_test.sh` after each phase. `gdscript-reviewer` on the
MetaProgress save/migration + RunManager earning changes before commit. Commit per
phase. No push.

## Out of scope
- Final Caps/icon art (Codex). - Spending Caps anywhere other than facilities.
- Reworking the extraction-backpack economy itself (only the Core/Caps banking
  hooks are touched).
