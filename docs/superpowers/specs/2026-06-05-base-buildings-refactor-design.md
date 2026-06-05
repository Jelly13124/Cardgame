# Base Buildings Refactor — Design

> Restructure the home base into 5 clickable functional BUILDINGS, each gated by
> Core (unlock + tier upgrades that progressively unlock functions); services
> inside spend Caps/Scrap. Reorganizes existing systems (Cyber Doctor, Blacksmith
> station, caps shop, deck editor) into buildings and adds new functions (craft /
> curse equipment, card shop, resource conversion). Multi-night effort. Building
> art is Codex's — ship with PLACEHOLDER sprites (colored panel + label) first.

**Architecture for parallelism:** a serial FOUNDATION (building data model in
MetaProgress + a clickable base screen that loads per-building screens + the
shared building-tier API + placeholder sprites) lands first. Then each building is
its OWN scene/script under `run_system/ui/buildings/` that only reads the shared
MetaProgress API and edits its own file + its own i18n key block — so the 5
building screens can be built in parallel (worktree isolation) without conflict.

## Currencies
- **Core** — unlock buildings + buy tier upgrades (T2/T3). Scarce (post-E3).
- **Caps** — spend inside Clinic (attribute/HP perks) and Market (buy equipment / cards).
- **Scrap** — spend inside Forge (reforge / craft / curse).

## The 5 buildings (Core unlock → Core tiers unlock functions)

| Building | T1 (on unlock) | T2 | T3 |
|---|---|---|---|
| **🔨 Forge 铁匠铺** | Dismantle (→scrap) | Craft + Reforge | Curse equipment |
| **🩺 Clinic 义体诊所** | Attribute perks (Caps) | Max-HP perk | Attribute level cap 3→5 |
| **🏪 Market 黑市** | Buy equipment (Caps) + Unlock cards (Core) | More stock / higher rarity | Card shop (buy cards, Caps) |
| **🏛 Outpost 前哨站** | Starting gold + In-run shop discount + Difficulty select | Safe-cell upgrades | Starter-deck editor |
| **🏚 Warehouse 仓库** | (free, default unlocked) Pick hero + departure equipment | More warehouse slots | Resource conversion |

### Proposed numbers (conservative; tune in review)
- **Unlock (Core):** Forge 60 · Clinic 80 · Market 100 · Outpost 70 · Warehouse 0 (free).
- **Tier costs (Core):** Forge 100/180 · Clinic 120/200 · Market 140/240 · Outpost 100/180 · Warehouse T2 80 / T3 150.
- **Forge (Scrap):** dismantle yields 5/12/25 by rarity (+5 if cursed); reforge cost 15/30/50; craft cost 40/80/140 (target rarity); curse cost 100 (re-rolls a chosen item to cursed: 1 curse + AFFIX_COUNT+1 positives).
- **Clinic (Caps):** attribute perk 300 + 150/level (existing); Max-HP perk (+5 HP/level) 200 + 150/level; T3 raises every perk's level cap 3→5.
- **Market (Caps):** equipment 60/140/280 by rarity; T3 card shop sells unlocked cards at 200/350/600 by rarity. Card **unlock** (T1, Core): 40 Core per card (cards outside the base/hero pool).
- **Outpost (Core tracks):** starting gold (+50/120/200 at 50/110/180 Core — absorbs Command Center); in-run merchant discount (10/20/30% at 50/110/180 — absorbs Scrap Workshop); T2 safe cells (+1/2/3, absorbs the old blacksmith upgrade); difficulty select (free, sets ascension); T3 deck editor (free, swap ≤2 starting cards from unlocked pool).
- **Warehouse:** hero select + equipment loadout (free); T2 +5 stash slots/level (≤STASH_CAP+15); T3 conversion: Core→Caps 1:2, Caps→Scrap 4:1, with a ~10% tax (round down) to discourage infinite grinding.

## Data model (MetaProgress) — the foundation
- `var buildings: Dictionary = {}` — `building_id → tier (0=locked, 1=unlocked, 2, 3)`. Back-compat default {} (all locked except warehouse which is tier 1 by default).
- `const BUILDING_DEFS` — for each building: unlock cost, tier costs, the function each tier gates. Single source of truth the base UI + buildings read.
- `get_building_tier(id)`, `unlock_building(id)` (spend unlock cost, tier→1), `upgrade_building(id)` (spend next tier cost, tier+1), `building_can(id, function)` (does the current tier gate this function?). Emits `buildings_changed`.
- MIGRATION: existing `facilities`/`caps_perk_levels`/`upgrades` (blacksmith safe-cells, cyber_doc) map onto the new buildings — Cyber Doctor unlocked → Clinic tier≥1; existing `cyber_*` perk levels keep working under Clinic. blacksmith upgrade level → Outpost safe-cell track. Provide a one-time normalize on load that seeds `buildings` from old state so nobody loses progress. Never wipe saves.
- Add Forge/Outpost/Market/Warehouse-specific persistent state as needed (e.g. card-unlock list reuses `unlocked_cards`; deck override per hero; warehouse extra slots; difficulty selection is per-run not persisted).

## Base UI (the foundation, serial)
`home_base_scene.gd` becomes a **building selector**: a base background with 5 building tiles (placeholder = a themed Panel + building name + lock/tier badge; Codex art later swaps the sprite). Clicking a building opens its **building screen** (a scene under `run_system/ui/buildings/<id>_screen.gd|tscn`) as an overlay. Each building screen shows: its tier + unlock/upgrade buttons (Core), and its tier-gated functions. Top bar shows Core / Caps / Scrap balances. Live-refresh on currency + `buildings_changed`.

## Per-building screens (parallelizable after foundation)
Each is an isolated scene/script reading the MetaProgress building API:
- **Forge:** dismantle (T1) / craft + reforge (T2) / curse (T3) over stash items; spends Scrap. (Extends the existing Blacksmith station logic.)
- **Clinic:** attribute perks + Max-HP (Caps); reuses existing Cyber Doctor perk model under the building.
- **Market:** equipment shop (Caps) + card unlock (Core); card shop at T3 (Caps).
- **Outpost:** gold/discount/safe-cell Core tracks + difficulty selector + deck editor (T3).
- **Warehouse:** hero select + equipment loadout + more slots (T2) + conversion (T3).

## Out of scope
Final building art (Codex); the in-combat economy; rebalancing existing content.

## Gates
Smoke after each task; gdscript-reviewer on the MetaProgress migration + currency math; content-balance not needed (no card/enemy content). Commit per task. No push.
