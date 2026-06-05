# Base Buildings Refactor — Plan

> Executes 2026-06-05-base-buildings-refactor-design.md. PHASE 0 (foundation) is
> SERIAL and must land first. PHASES 1a–1e (the 5 building screens) are isolated
> scenes that only read the MetaProgress building API + edit their own file +
> their own i18n key block → runnable in PARALLEL (worktree isolation). Gate each:
> `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`. No push.

## PHASE 0 — Foundation (SERIAL — everything depends on it)
- [ ] F0a — MetaProgress building data model: `buildings` dict, `BUILDING_DEFS`
  (unlock + tier costs + tier→function gating per the spec table), `get_building_tier`/
  `unlock_building`/`upgrade_building`/`building_can`, `buildings_changed` signal,
  save/load back-compat, and the one-time normalize that seeds `buildings` from the
  old `facilities`/`upgrades` (cyber_doc→Clinic, blacksmith→Outpost safe cells) so
  no progress is lost. gdscript-reviewer (migration) + smoke + commit.
- [ ] F0b — Base UI shell: home_base_scene becomes a building SELECTOR (5 placeholder
  building tiles with lock/tier badges + Core/Caps/Scrap top bar) that opens a
  per-building screen overlay. Define the building-screen base interface
  (run_system/ui/buildings/building_screen_base.gd: shows tier + unlock/upgrade
  buttons + a content area) so each building extends it. Placeholder sprites =
  themed Panel + label. smoke + commit. (Owner verifies visually.)

## PHASE 1 — Building screens (PARALLEL after F0; worktree isolation)
Each = a new scene/script under run_system/ui/buildings/ + its own UI_BUILD_<ID>_* i18n
block. Reads MetaProgress building API; spends the right currency; respects tier gating.
- [ ] 1a — Forge screen: dismantle (T1) / craft + reforge (T2) / curse (T3) over stash;
  Scrap costs per spec. (Port the existing Blacksmith station dismantle/reforge.)
- [ ] 1b — Clinic screen: attribute perks + Max-HP (Caps); tier-cap 3→5 at T3. (Port
  Cyber Doctor perk model.)
- [ ] 1c — Market screen: equipment shop (Caps) + card unlock (Core, 40/card); card
  shop at T3 (Caps).
- [ ] 1d — Outpost screen: gold / merchant-discount / safe-cell Core tracks + difficulty
  selector + deck editor (T3, ≤2 swaps from unlocked pool).
- [ ] 1e — Warehouse screen: hero select + departure equipment loadout + more slots
  (T2) + resource conversion (T3, with tax).

## PHASE 2 — Cleanup
- [ ] C0 — Remove the now-superseded standalone panels (old 5 upgrade panels, the
  inline Cyber Doctor panel, the Blacksmith station) once their functions live in
  buildings. Keep the underlying meta state. smoke + commit.

## Final
- [ ] Full smoke green. Regen HTML catalogs if any data changed. Morning summary:
  done/deferred, owner-verify (all base UI), Codex art TODOs (5 building sprites,
  currency icons).
