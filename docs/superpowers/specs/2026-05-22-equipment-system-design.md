# Equipment System v1 — Design Spec

**Date:** 2026-05-22
**Branch:** `hero-refinement-v2`
**Status:** Design approved, ready for implementation planning
**Scope:** MVP + set bonuses + loot drops (no shop, no upgrades, no per-hero starter gear)

---

## 1. Context

PRD Phase 3 calls for an equipment system: gear the player equips between battles to boost
the five attributes (strength / constitution / intelligence / luck / charm). The system
skeleton already exists in `RunManager` (`equipped_items: Array[String]`, `MAX_ITEMS=5`,
`equip_item()` stub, `player_attributes` dict) but has no data, no UI, no combat
integration, and no loot hooks.

This spec layers a usable v1 on top of that skeleton — including **set bonuses** so
equipment isn't only stat sticks. The user wants equipment to feel like build decisions,
not just incremental damage buffs.

### Existing relevant code

- `run_system/core/run_manager.gd:26` — `equipped_items: Array[String]` (will be refactored to Dict)
- `run_system/core/run_manager.gd:36-42` — `player_attributes` dict
- `battle_scene/battle_scene.gd:242-247` — reads `RunManager.player_attributes` into `player.X` at battle start
- `battle_scene/combat_engine.gd:71-72` — supports `scaling: "strength"` on card effects (card damage += player.strength)
- `battle_scene/relic_effect_system.gd` — pattern to mirror for set effects
- `run_system/data/relics/` — pattern for equipment/set JSON data files
- `run_system/ui/map_scene.gd` — where the equipment panel + treasure-drop logic lives
- `run_system/ui/loot_reward.gd` — where post-battle equipment drops integrate

### Out of scope for this slice

- Shop (buying/selling equipment)
- Equipment upgrades / rerolling
- Per-hero starter equipment combos
- Equipment tooltip with full set-tier preview tree
- Real PNG sprites (codex's domain; placeholder rendering for now)
- Save/load persistence (no save file exists; don't add one for this)
- Multi-hero separate inventories
- Deck-composition restrictions ("set only enables attack-only decks" etc.)

---

## 2. Data Model

### 2.1 Equipment JSON

Path: `run_system/data/equipment/{id}.json`

```json
{
  "id": "weak_hunter_gloves",
  "name": "Weak Hunter Gloves",
  "slot": "hands",
  "rarity": "common",
  "set_id": "weak_hunter",
  "bonuses": { "strength": 1, "luck": 1 },
  "description": "Worn leather gloves stained with bad luck.",
  "sprite": "equipment/weak_hunter_gloves.png"
}
```

Field semantics:

| Field | Type | Allowed values | Required |
|---|---|---|---|
| `id` | String | unique, snake_case | yes |
| `name` | String | display name | yes |
| `slot` | String | `head` \| `chest` \| `weapon` \| `hands` \| `accessory` | yes |
| `rarity` | String | `common` \| `uncommon` \| `rare` | yes |
| `set_id` | String | references a `equipment_sets/{set_id}.json` file, OR empty/missing = no set | no |
| `bonuses` | Dict | keys ⊂ `{strength, constitution, intelligence, luck, charm}`, values int | yes (can be empty `{}`) |
| `description` | String | flavor text | yes |
| `sprite` | String | path relative to `battle_scene/assets/images/`; loader falls back to placeholder if file missing | yes (path is required even if file doesn't exist yet) |

### 2.2 Set JSON

Path: `run_system/data/equipment_sets/{id}.json`

```json
{
  "id": "weak_hunter",
  "name": "Weak Hunter",
  "description": "Equipment that punishes vulnerability.",
  "tiers": [
    {
      "count": 3,
      "label": "+1 Block on defense cards",
      "effect": { "type": "skill_block_bonus", "amount": 1 }
    },
    {
      "count": 5,
      "label": "Attack cards apply Weak 1",
      "effect": { "type": "attack_apply_status", "status": "weak", "stacks": 1 }
    }
  ]
}
```

Rules:

- Exactly **2 tiers** per set, with `count` 3 and 5.
- A piece belongs to **at most one** set (no multi-set membership).
- A piece may belong to no set (just a stat stick).

### 2.3 Supported set effect types (MVP: 6)

| `type` | Trigger point | Payload |
|---|---|---|
| `start_turn_block` | player turn start | `amount: int` |
| `start_turn_energy` | player turn start | `amount: int` |
| `start_battle_block` | battle start | `amount: int` |
| `skill_block_bonus` | inside `_apply_effect` when card type is `skill` and effect is `gain_block` | `amount: int` |
| `attack_damage_bonus` | inside `_apply_effect` when card type is `attack` and effect is `deal_damage` (pre-mitigation) | `amount: int` |
| `attack_apply_status` | inside `_apply_effect` after `deal_damage` resolves on a target | `status: String, stacks: int` |

`status` values for `attack_apply_status` must already be supported by `status_system` (`weak`, `vulnerable`, `poison`, `burn`, `shock`).

### 2.4 MVP content

- **2 sets**, 5 pieces each (one per slot) — 10 set pieces total
  - `weak_hunter` — penalty/debuff theme (uses `attack_apply_status` weak)
  - `tank_engineer` — defense theme (uses `start_turn_block`, `skill_block_bonus`)
- **4–5 plain pieces** — no set, just stat bonuses, spread across slots and rarities
- **Target: 14–15 equipment JSON files**

---

## 3. RunManager Changes

### 3.1 Field additions and changes

```gdscript
# === NEW ===
const MAX_INVENTORY: int = 8
var inventory_items: Array[String] = []
var base_attributes: Dictionary = {
    "strength": 3, "constitution": 3,
    "intelligence": 3, "luck": 3, "charm": 3
}

# === CHANGED ===
# Before: var equipped_items: Array[String] = []
# After:
var equipped_items: Dictionary = {
    "head": "", "chest": "", "weapon": "", "hands": "", "accessory": ""
}

# player_attributes stays as-is BUT becomes a computed value
# (base + sum of equipment bonuses), refreshed by recompute_attributes()
# instead of being directly mutated.
```

### 3.2 New methods

```gdscript
## Recomputes player_attributes from base_attributes + sum of every equipped
## item's bonuses. Emits equipment_changed signal. Call after every equip/unequip.
func recompute_attributes() -> void

## Equip item_id into slot. If slot is occupied, the previous occupant moves
## to inventory. Returns false (no-op) if slot is occupied AND inventory is
## full — caller is responsible for showing the inventory-full modal first.
## Calls recompute_attributes() on success. Returns true on success.
func equip_to_slot(item_id: String, slot: String) -> bool

## Move the item in slot back into inventory. Returns false if inventory is
## full. Calls recompute_attributes() on success. Returns true on success.
func unequip_slot(slot: String) -> bool

## Append to inventory. Returns false if at MAX_INVENTORY (caller handles UI).
func add_to_inventory(item_id: String) -> bool

## Discard inventory[index]. Frees a slot.
func discard_from_inventory(index: int) -> void

## Returns { set_id: piece_count } across currently equipped items
## (only sets with >= 1 equipped piece appear).
func get_active_set_tiers() -> Dictionary

signal equipment_changed
```

### 3.3 Removed / migrated

- Delete `func equip_item(item_id: String) -> bool` (stub, replaced by `equip_to_slot`).
- Update **7 callsites** referencing `equipped_items` (grep before S1 starts). All currently treat it as Array; need migration.
- `reset_run()` initializes the new Dict shape and empty `inventory_items`.

---

## 4. Battle Integration

### 4.1 New module: `battle_scene/equipment_set_system.gd`

Mirrors `relic_effect_system.gd`'s shape. Owned by battle_scene; instantiated in
`_start_new_game()`. Reads `RunManager.equipped_items` + `RunManager.get_active_set_tiers()`
to compute active tier effects at battle start (snapshot — does NOT re-read during combat).

Methods:

```gdscript
func setup(battle_scene: Node) -> void
func on_battle_started(player: Node) -> void                    # start_battle_block
func on_player_turn_started(player: Node, round_number: int) -> void  # start_turn_block, start_turn_energy
func modify_card_block(card: Card, amount: int) -> int          # skill_block_bonus
func modify_card_damage(card: Card, amount: int) -> int         # attack_damage_bonus
func on_card_damage_resolved(card: Card, target: Node) -> void  # attack_apply_status
```

### 4.2 battle_scene hook additions

| Existing call | New call (added immediately after) |
|---|---|
| `relic_effect_system.on_player_turn_started(player, round)` | `equipment_set_system.on_player_turn_started(player, round)` |
| `relic_effect_system.on_combat_victory(player)` | (no equipment hook on victory) |
| (battle start path) | `equipment_set_system.on_battle_started(player)` after attribute injection |

### 4.3 combat_engine modifications

Three insertion points in `_apply_effect`:

**A) Before `gain_block` resolves** (and only if `card_info.type == "skill"`):

```gdscript
"gain_block":
    var card = main.current_resolving_card  # see 4.4
    if card and card.card_info.get("type") == "skill" and main.equipment_set_system:
        amount = main.equipment_set_system.modify_card_block(card, amount)
    player.add_block(amount)
```

**B) Before `deal_damage` calculates outgoing damage** (only if `card_info.type == "attack"`):

```gdscript
"deal_damage":
    var card = main.current_resolving_card
    if card and card.card_info.get("type") == "attack" and main.equipment_set_system:
        amount = main.equipment_set_system.modify_card_damage(card, amount)
    var outgoing = calculate_attack_damage(amount, player, target)
    target.take_damage(outgoing)
    # NEW:
    if card and card.card_info.get("type") == "attack" and main.equipment_set_system:
        main.equipment_set_system.on_card_damage_resolved(card, target)
```

**C) Same insertion for `deal_damage_all`** (loop body).

### 4.4 Tracking the current resolving card

`combat_engine` currently doesn't know which card triggered an effect. Add to `play_spell`:

```gdscript
main.current_resolving_card = card
# ... existing _apply_effect calls ...
main.current_resolving_card = null
```

Where `main.current_resolving_card: Card = null` is a new var declared at the top of
`battle_scene.gd`. Set in `play_spell` immediately before the `_apply_effect` loop,
cleared in the `finally`-equivalent path (after the loop, regardless of outcome).
Read-only inside `combat_engine`.

### 4.5 Snapshot semantics

Equipment loadout is **frozen at battle start**. Any equipment change mid-battle is
disallowed (PRD: "Equipment cannot be swapped during combat"). The set system caches
its active-effect list in `setup()` / `on_battle_started()` and ignores
`RunManager.equipment_changed` until the next battle.

---

## 5. UI

### 5.1 Equipment panel (map screen modal)

Triggered by an `[⚔ EQUIPMENT]` button added to the map_scene top bar (next to existing
deck / relic buttons). Opens a full-overlay modal styled with `T.panel_textured("dark")`
matching the relic_choice_modal pattern.

**Layout** (single panel, 2 columns):

```
┌──────────────────────────────────────────────────────────────┐
│ EQUIPMENT                                            [X]     │
├──────────────────────────────────────────────────────────────┤
│  ─── SLOTS ───                ─── INVENTORY (n/8) ───        │
│  [H] HEAD  Weak Hat  +1str    [H] Weak Hat  +1str            │
│           [weak_hunter]              [weak_hunter]  [EQUIP]  │
│                                                  [DISCARD]   │
│  [C] CHEST  (empty)           [C] Scrap Vest +2con           │
│                                      [tank_engineer]         │
│  [W] WEAPON Tank Hammer +2str        [EQUIP] [DISCARD]       │
│                                                              │
│  [Hd] HANDS  (empty)                                         │
│                                                              │
│  [Ac] ACCESSORY (empty)                                      │
├──────────────────────────────────────────────────────────────┤
│ ACTIVE SETS                                                  │
│  weak_hunter      1/5 ▓░░░░  tier 3: ─   tier 5: ─           │
│  tank_engineer    2/5 ▓▓░░░  tier 3: ─   tier 5: ─           │
├──────────────────────────────────────────────────────────────┤
│ STATS  STR:3+0=3  CON:3+2=5  INT:3  LUC:3  CHA:3             │
└──────────────────────────────────────────────────────────────┘
```

**Interaction**:

- Click a filled slot → shows `[UNEQUIP]` action (moves to inventory; errors if inventory full).
- Click an inventory item's `[EQUIP]` → moves to its slot. If slot occupied, prev item auto-swaps to inventory. If inventory would overflow, blocks with "INVENTORY FULL" toast.
- Click `[DISCARD]` → confirm modal → removes from inventory.
- Active set tier rows highlight gold + show tier label when count threshold is reached.

### 5.2 Placeholder sprite renderer

New file: `run_system/ui/equipment_icon.gd` (extends `Panel`).

```gdscript
@export var slot: String
@export var label: String     # usually item name first letter or 2 letters
@export var sprite_path: String  # tries to load; falls back to colored panel
```

Slot color map:

| slot | color (hex approx) |
|---|---|
| `head` | `#a83232` (rust red) |
| `chest` | `#2c5a8a` (steel blue) |
| `weapon` | `#c2a83a` (brass yellow) |
| `hands` | `#3e7a3e` (olive green) |
| `accessory` | `#7a3a8e` (faded violet) |

Default size 48×48 with `texture_filter = NEAREST` for pixel-art consistency. Reused by
both the equipment panel and loot_reward drop UI.

### 5.3 Loot reward integration

In `loot_reward.gd`, between the gold row and card draft row, conditionally insert:

```
┌─── EQUIPMENT DROP ─────────────────────────┐
│  [H] Reinforced Helm  +2 constitution      │
│      [tank_engineer set]                   │
│      [TAKE]  [SKIP]                        │
└────────────────────────────────────────────┘
```

Drop rules:

| Battle source | Drop |
|---|---|
| Regular `enemy` battle | (none — no equipment drop) |
| `elite` battle | 1× uncommon equipment (always) |
| `boss` battle | 1× rare equipment (always) |

`[TAKE]` → calls `RunManager.add_to_inventory(item_id)`. If returns false, opens the
**Inventory Full** sub-modal (5.4). `[SKIP]` → discards the offered item.

### 5.4 Inventory full modal

```
┌─── INVENTORY FULL ──────────────────────────┐
│ Pick something to discard, or skip the new │
│ equipment:                                  │
│                                             │
│ [Weak Hat]  [Scrap Vest]  [Lucky Tag]      │
│ [Tank Hammer]  [Old Boots]  [Coil]         │
│ [Spool]  [Goggles]                          │
│                                             │
│ ─── INCOMING ─── Reinforced Helm +2con      │
│                                             │
│ [DISCARD SELECTED]  [SKIP NEW ITEM]         │
└─────────────────────────────────────────────┘
```

Single-select highlight on click. `[DISCARD SELECTED]` discards highlighted →
adds incoming. `[SKIP NEW ITEM]` discards incoming.

### 5.5 Treasure node — 50/50 split

Current: `treasure` always opens `_open_relic_choice("Choose a Relic", "treasure")`.

New: 50% chance to open relic choice (existing behavior), 50% chance to grant equipment
via the same inventory-full-aware path as loot drops. Equipment rarity roll for treasure:
70% uncommon / 30% rare.

---

## 6. Implementation Slices

Smallest / safest first. Each slice is independently shippable.

| # | Slice | Files touched | Risk |
|---|---|---|---|
| **S1** | RunManager refactor + new API | `run_system/core/run_manager.gd`, 7 callsites | medium |
| **S2** | Equipment + set JSON + schema validator | `run_system/data/equipment/*.json`, `run_system/data/equipment_sets/*.json`, `battle_scene/data_validator.gd` | low |
| **S3** | `equipment_set_system.gd` + basic hooks | new file, `battle_scene/battle_scene.gd` | low |
| **S4** | Combat hooks (card-value & on-resolved) | `battle_scene/combat_engine.gd`, `battle_scene/equipment_set_system.gd`, `battle_scene/battle_scene.gd` (current_resolving_card) | medium |
| **S5** | Equipment panel modal + placeholder icons | new `run_system/ui/equipment_icon.gd`, new `run_system/ui/equipment_panel.gd`, `run_system/ui/map_scene.gd` | medium |
| **S6** | Loot reward + inventory full + treasure split | `run_system/ui/loot_reward.gd`, `run_system/ui/map_scene.gd`, possibly new `run_system/ui/inventory_full_modal.gd` | medium |
| **S7** | End-to-end smoke playthrough | — | — |

### 6.1 Dependency graph

```
S1 (RunManager) ──► S2 (data) ──┬─► S3 (basic system) ──► S4 (combat hooks)
                                 ├─► S5 (UI) ──────────────────────────┐
                                 └─────────────────────────────────────┴─► S6 (loot) ──► S7 (smoke)
```

S3 and S5 can run in parallel after S1+S2 land. S6 needs S5 (reuses UI components for
the inventory-full modal) and S2 (loads equipment data to display drops).

---

## 7. Testing

| Layer | Method |
|---|---|
| Schema typos | `DataValidator.validate_all_data_at_startup()` — already wired; extend to cover equipment + sets |
| Parse errors | `godot --headless --path . --quit-after 3` before every commit |
| Set hook firing | After S3/S4: wear 3 weak_hunter pieces, start a battle, confirm `skill_block_bonus` adds +1 to a played `defend` |
| UI smoke | After S5: open equipment panel, equip/unequip, confirm stat row updates, set tier indicator advances |
| Loot smoke | After S6: clear an elite battle → drop appears → take → enters inventory; fill inventory to 8 → 9th drop triggers full-modal |
| End-to-end | S7: new run, complete floor 1 with ≥1 treasure + ≥1 elite + boss; zero `push_error` / `push_warning` in console |

No GUT/gd-unit harness — manual smoke + DataValidator + headless parse only.

---

## 8. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| `equipped_items` Array→Dict break callers | grep `equipped_items` exhaustively in S1; headless parse after each callsite update |
| combat_engine card-type detection wrong | Verify `card_info["type"]` actually contains `"attack"` / `"skill"` for all 17 existing cards before S4; add assert if missing |
| Set system mid-battle desync (player changes gear during combat somehow) | Snapshot in `on_battle_started`; don't listen to `equipment_changed` during a battle |
| Inventory full UI confusing | Single-select highlight + explicit `[SKIP NEW ITEM]` button to avoid "must accept" pressure |
| Placeholder icons too ugly to ID equipment | Show slot letter (H/C/W/Hd/Ac) + slot color + item name to the right; ID via text, not visuals |

---

## 9. Open follow-ups (not this slice)

- Shop (Phase 3 continuation)
- Equipment upgrades
- Per-hero starter equipment
- Real PNG icons (codex)
- Tooltip preview tree
- More set effect types as content grows (e.g., `enemy_status_damage_bonus` for poison/burn builds)
