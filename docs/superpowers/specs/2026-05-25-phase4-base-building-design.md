# Phase 4 — Base Building MVP + Extract Choice

**Status:** Approved 2026-05-25 — ready for implementation plan
**Owner:** Claude (overnight autonomous execution)
**Scope:** MVP base-building loop + Floor 1/2 extract choice. Single iteration; ships independently.

## Why

PRD Phase 3 (card upgrade + shop + rest) shipped on 2026-05-25. PRD Phase 4 (base building + meta-progression) is the next milestone. Currently `RunManager.core` exists as an unused field — there is no persistence layer, no home base scene, no extraction flow, no upgrade effects.

Phase 4 MVP closes the meta-progression loop so the game becomes a roguelite (runs feed permanent progress) instead of a pure roguelike (one-and-done). It also gives every run a reason to attempt extraction at Floor 1/2 boss rather than always pushing for Floor 3.

## Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Scope | MVP + extract choice | User wants overnight-completable scope with full loop verifiable next morning |
| Upgrade tiers | 3 levels per upgrade (Lv1/Lv2/Lv3) | More "progress feel" than single-purchase; modest extra UI cost |
| Core economy | F1 boss kill = +25 (continue) / +50 (extract); F2 = +50 / +90; F3 = +150 full victory; death = 0 | Extract should be a real choice (50 now vs 90 risked); F3 completion is biggest reward |
| Upgrade pricing | Lv1=30, Lv2=60, Lv3=100 (total 190 per upgrade × 5 upgrades = 950 Core for full unlock ≈ 10 successful runs) | Long enough horizon to feel meta, short enough that early upgrades arrive in 2-3 runs |
| Upgrade effects | See table below; all 5 PRD upgrades land in MVP | Cuts to a single playable loop with full breadth |
| Hero unlock | Out of scope — cowboy_bill and jerry both already selectable | Avoids touching hero_select; revisit when adding new heroes |
| Save format | `user://meta.json` (FileAccess JSON) | Simplest possible; only ~50 bytes of state |

## Upgrade effects (locked)

| Upgrade | Effect key | Lv1 | Lv2 | Lv3 |
|---|---|---|---|---|
| **Med Bay** | `max_hp_bonus` | +10 max HP | +20 max HP | +30 max HP |
| **Arsenal** | `starter_inventory` | 1 random common equipment in inventory at run start | 2 random commons | 2 commons + 1 uncommon |
| **Research Lab** | `loot_rarity_bias` | Loot draft cards: +5% chance to promote one slot to uncommon | +10% promote | +15% uncommon + 5% rare |
| **Scrap Workshop** | `shop_discount` | All shop prices ×0.90 | ×0.80 | ×0.70 |
| **Command Center** | `map_reveal` | Reveal node types 1 floor ahead | 2 floors ahead | All floors revealed |

## Architecture

Four new components, one modified RunManager hook, one modified battle-end flow:

### 1. `run_system/core/meta_progress.gd` (NEW, autoload)

Source of truth for permanent progress. Loaded at app start, auto-saved on every mutation.

```gdscript
extends Node
# Autoload as "MetaProgress" in project.godot

const SAVE_PATH := "user://meta.json"

signal core_changed(new_value: int)
signal upgrades_changed()

var core: int = 0
var upgrades: Dictionary = {}  # id (String) → level (int 0..3)

func _ready() -> void:
    load_progress()

func add_core(amount: int) -> void:
    core = max(0, core + amount)
    save_progress()
    emit_signal("core_changed", core)

func get_upgrade_level(id: String) -> int:
    return int(upgrades.get(id, 0))

func can_purchase(id: String, definition: Dictionary) -> bool:
    var lvl := get_upgrade_level(id)
    if lvl >= definition["tiers"].size():
        return false
    return core >= int(definition["tiers"][lvl]["cost"])

func purchase_upgrade(id: String, definition: Dictionary) -> bool:
    if not can_purchase(id, definition):
        return false
    var lvl := get_upgrade_level(id)
    var cost := int(definition["tiers"][lvl]["cost"])
    core -= cost
    upgrades[id] = lvl + 1
    save_progress()
    emit_signal("core_changed", core)
    emit_signal("upgrades_changed")
    return true

func reset_all() -> void:
    # Debug helper — wipes meta state. Not exposed in UI.
    core = 0
    upgrades.clear()
    save_progress()
    emit_signal("core_changed", core)
    emit_signal("upgrades_changed")

func save_progress() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if not f:
        push_warning("MetaProgress: failed to open save file for write")
        return
    f.store_string(JSON.stringify({"core": core, "upgrades": upgrades}, "  "))
    f.close()

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not f:
        return
    var raw := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("MetaProgress: corrupt save, starting fresh")
        DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
        return
    core = int(parsed.get("core", 0))
    upgrades = parsed.get("upgrades", {})
```

### 2. `run_system/data/base_upgrades/*.json` (NEW, 5 files)

One file per upgrade. Schema:

```json
{
  "id": "med_bay",
  "name": "MED BAY",
  "description": "Permanently increase starting max HP.",
  "effect_key": "max_hp_bonus",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"hp": 10}, "effect_text": "+10 max HP at run start"},
    {"level": 2, "cost": 60, "effect_value": {"hp": 20}, "effect_text": "+20 max HP at run start"},
    {"level": 3, "cost": 100, "effect_value": {"hp": 30}, "effect_text": "+30 max HP at run start"}
  ]
}
```

`effect_value` is always a JSON object whose keys are interpreted by the specific consumer for that `effect_key`. Examples:
- `max_hp_bonus` → `{"hp": 10}` (consumer reads `hp`)
- `starter_inventory` → `{"commons": 2, "uncommons": 1}`
- `loot_rarity_bias` → `{"uncommon": 0.15, "rare": 0.05}`
- `shop_discount` → `{"multiplier": 0.70}`
- `map_reveal` → `{"floors_ahead": 2}` (or `{"floors_ahead": -1}` for "all")

DataValidator will get a `base_upgrade` validator that checks the top-level shape (id, name, tiers array, each tier has level/cost/effect_value/effect_text) but does not enforce inner effect_value shape (per-effect consumers handle it).

Five files: `med_bay.json`, `arsenal.json`, `research_lab.json`, `scrap_workshop.json`, `command_center.json`.

### 3. `run_system/ui/home_base_scene.gd` + `home_base_scene.tscn` (NEW)

Home base UI. Loaded on game start (replaces current direct-to-hero-select boot) and after every run ends (death OR victory OR extraction).

Layout:
```
┌─ HOME BASE ───────────────────  CORE: 234 ─┐
│                                            │
│  ┌─ MED BAY ──────────┐ ┌─ ARSENAL ──────┐│
│  │ Level: ●●○        │ │ Level: ●○○     ││
│  │ Next: +30 max HP  │ │ Next: 2 commons││
│  │ Cost: 100 Core    │ │ Cost: 60 Core  ││
│  │      [BUY]        │ │     [BUY]      ││
│  └───────────────────┘ └────────────────┘│
│  ┌─ RESEARCH LAB ────┐ ┌─ SCRAP WORKSHOP┐│
│  │ ...               │ │ ...            ││
│  └───────────────────┘ └────────────────┘│
│  ┌─ COMMAND CENTER ──┐                   │
│  │ ...               │                   │
│  └───────────────────┘                   │
│                                            │
│                       [ START NEW RUN ]   │
└────────────────────────────────────────────┘
```

- Grid of 5 UpgradePanel widgets (3 + 2)
- Each panel: title, level dots (●●○ shows 2/3), next-tier preview, cost, BUY button (disabled if can't afford or already Lv3)
- Top-right Core counter listens to `MetaProgress.core_changed`
- Bottom START NEW RUN → `get_tree().change_scene_to_file("res://run_system/ui/hero_select.tscn")`

### 4. Extract choice modal (NEW, inline in `battle_scene.gd`)

After F1 or F2 boss is killed, before normal loot reward:

```
┌─ EXTRACT? ─────────────────────────────────┐
│  You killed the Floor 1 boss.              │
│                                            │
│  [ EXTRACT NOW: +50 Core, end run ]        │
│  [ CONTINUE TO FLOOR 2: +25 Core, push on ]│
└────────────────────────────────────────────┘
```

- F3 boss kill → no choice, +150 Core, game-over-victory back to home base
- Player death → game-over-defeat back to home base, 0 Core
- F1/F2 normal map nodes → no change

### 5. Hooks in `run_system/core/run_manager.gd` (MODIFY)

`reset_run()` (currently zeros everything) gains a "read MetaProgress and apply" pass:

```gdscript
func reset_run() -> void:
    # ... existing zero-out ...
    # NEW: apply meta progress
    _apply_meta_upgrades()

func _apply_meta_upgrades() -> void:
    # Med Bay
    var hp_bonus := _get_meta_effect_value("med_bay") as int
    max_health += hp_bonus
    current_health = max_health
    # Arsenal — grants starter inventory
    var arsenal_level := MetaProgress.get_upgrade_level("arsenal")
    if arsenal_level > 0:
        _grant_starter_equipment(arsenal_level)
    # Other effects (loot bias, shop discount, map reveal) are read on-demand
    # by their respective systems (loot_reward, shop_scene, map_renderer).
```

Other systems pull on demand:
- `loot_reward.gd` — at draft roll, reads `MetaProgress.get_upgrade_level("research_lab")` → adjusts pool
- `shop_scene.gd` — at price display, reads `scrap_workshop` level → multiplies prices
- `map_renderer.gd` — at render, reads `command_center` level → unhides far-future nodes' icons

### 6. Boot entry point (MODIFY)

`project.godot` `[application]` `run/main_scene` → `res://run_system/ui/home_base_scene.tscn`.

Existing `hero_select.tscn` keeps current behavior — just no longer the first scene.

## Data flow (complete loop)

```
APP BOOT
  ↓
MetaProgress autoload _ready() → load user://meta.json (or init to 0/{})
  ↓
home_base_scene → display Core + 5 upgrade panels
  ↓
Player buys 0-N upgrades (or doesn't)
  ↓
Player clicks START NEW RUN
  ↓
hero_select_scene (existing)
  ↓
Player picks hero
  ↓
RunManager.reset_run() → applies meta upgrades (max_hp, starter inventory)
  ↓
map_scene → battles → loot → ...
  ↓
F1 BOSS DEFEATED
  ↓ extract choice modal
  ├── EXTRACT → MetaProgress.add_core(50) → home_base_scene
  └── CONTINUE → MetaProgress.add_core(25) → F2 map_scene
                  ↓
                  F2 BOSS DEFEATED
                  ↓ extract choice modal
                  ├── EXTRACT → MetaProgress.add_core(90) → home_base_scene
                  └── CONTINUE → MetaProgress.add_core(50) → F3 map_scene
                                  ↓
                                  F3 BOSS DEFEATED
                                  ↓ (no choice)
                                  MetaProgress.add_core(150) → home_base_scene

PLAYER DEATH (any floor)
  ↓
game_over_screen (existing) → home_base_scene (no Core gained)
```

## Edge cases

| Case | Behavior |
|---|---|
| First boot (no save file) | meta.json absent → MetaProgress initializes to `core=0, upgrades={}` → home base shows "CORE: 0" |
| Corrupt save | JSON.parse fails → push_warning, rename to `.bak`, start fresh |
| Try to buy when broke | BUY button disabled (visual: greyed) — purchase_upgrade returns false defensively |
| Try to buy Lv3 upgrade | BUY button shows "MAXED", disabled |
| Player quits during run | Run progress lost (no in-run save) — meta progress unchanged (already saved at last home base purchase) |
| Arsenal fills inventory beyond 5 | Same as treasure overflow — current inventory_full_modal handles, but at run start we just stop adding when inventory.size() == 5 |
| Inventory hits cap during Arsenal Lv3 grant | Silently stop at 5; no modal popup at run start |
| Player picks "EXTRACT" but already on F3 | Not reachable — F3 has no extract modal |

## Out of scope (explicit)

- **Hero unlock via upgrades**: PRD mentioned but won't ship in MVP. Both heroes already selectable.
- **Multi-save-slot**: Single `meta.json` only.
- **Upgrade prerequisite tree**: All 5 upgrades available from start.
- **Base building visual art**: Codex asset hand-off is a separate slice after MVP ships.
- **Achievement tracking**: Run history / win count not stored.
- **In-run save** (resume mid-run after quit): Not in MVP.
- **Reset progress UI**: `MetaProgress.reset_all()` exists for debug but no in-game button.
- **Migration from saves that pre-date this system**: There are no prior saves; clean slate.

## Testing

### Headless smoke (automated)
- `godot --headless --path . --quit-after 3` boots home_base_scene cleanly — no push_error/push_warning
- DataValidator validates 5 `base_upgrades/*.json` against new schema
- MetaProgress unit-style: write → read round-trip via temp meta.json

### Manual smoke (next morning)
1. Cold boot → home_base shows CORE: 0, all upgrades at Lv0, BUY disabled (broke)
2. Click START NEW RUN → hero select → battle 1 plays normally
3. Beat F1 boss → extract modal shows
4. Click EXTRACT → return to home_base, CORE: 50
5. Buy Med Bay Lv1 (cost 30) → CORE: 20, Med Bay shows Lv1, BUY shows Lv2 cost 60
6. START NEW RUN again → enter battle 1 → check player max HP = base + 10
7. Beat F1, click CONTINUE → CORE: 45 (had 20, +25) → F2 map opens
8. Beat F2 boss, click EXTRACT → +90 → home with 135
9. Restart Godot → home_base shows CORE: 135, Med Bay still Lv1 (persistence verified)
10. Open `user://meta.json` manually → verify `{"core":135,"upgrades":{"med_bay":1}}`

### Acceptance bar
- All headless tests pass
- Manual smoke 1-10 all behave as listed
- Zero push_error in console during smoke
- meta.json round-trips through editor close/reopen

## Risks

| Risk | Mitigation |
|---|---|
| Boot scene change breaks existing hero_select flow | Test in editor after change; if broken, revert to hero_select as first scene + add manual home_base button there |
| Save corruption from concurrent write | Single-writer (MetaProgress) — no concurrent risk in single-process Godot |
| Arsenal's "random common equipment" creates duplicates | Tolerable for MVP — equipment system already handles duplicate IDs in inventory |
| Loot rarity bias math interaction with existing draft pool | Implement as post-roll re-roll: roll normally, then with N% chance, re-roll specific slot at higher rarity |
| Extract modal blocks existing post-boss loot screen | Insert modal BEFORE loot screen; CONTINUE flows into normal loot, EXTRACT skips loot (loot is implicit in the +50 Core) |

## Reusable patterns

- `run_manager.gd` autoload pattern → `meta_progress.gd` copies it
- `wasteland_theme.gd` styling → all UI uses it
- `data_validator.gd` JSON schema validation → adds `base_upgrade` validator alongside existing validators
- `home_base_scene.tscn` mirrors `hero_select.tscn` structural shape
- Extract modal mirrors `_open_rest_choice` modal pattern from `map_scene.gd`
- UpgradePanel widget mirrors `EquipmentIcon`'s build-once / connect-signals pattern

## Open questions

None — all locked during brainstorming.
