# Equipment System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the equipment system MVP — 5 body-part slots, capped inventory, 2 sets with 3/5-piece tier bonuses, loot drops on elite/boss/treasure — wired into combat so set tiers actually modify card behavior.

**Architecture:** Mirror the existing `relic_effect_system` for set-tier effects. RunManager owns persistent state (equipped dict, inventory, base/effective attributes). A new `equipment_set_system` reads `RunManager.get_active_set_tiers()`, snapshots active effects at battle start, hooks into `combat_engine._apply_effect` via three insertion points (gain_block, deal_damage pre, deal_damage post) and shared turn/battle hooks. A single map-screen modal handles equip/unequip/inventory. Loot drops reuse the same equipment icon component.

**Tech Stack:** GDScript (Godot 4.6), JSON for data, headless Godot for parse checks, existing `DataValidator` for schema enforcement. No GUT/gd-unit test framework — verification via headless parse + DataValidator + manual smoke per task.

**Spec:** [`docs/superpowers/specs/2026-05-22-equipment-system-design.md`](../specs/2026-05-22-equipment-system-design.md)

---

## File Structure

**New files:**

| Path | Responsibility |
|---|---|
| `run_system/data/equipment/*.json` (14 files) | One per equipment piece |
| `run_system/data/equipment_sets/*.json` (2 files) | One per set with tiered bonuses |
| `battle_scene/equipment_set_system.gd` | Snapshot active set tiers at battle start; expose hooks called by battle_scene + combat_engine |
| `run_system/ui/equipment_icon.gd` | Reusable placeholder renderer (colored panel + slot-letter label) — used by panel and loot UI |
| `run_system/ui/equipment_panel.gd` | Map-screen modal: 5 slots + inventory + active sets + stat row |
| `run_system/ui/inventory_full_modal.gd` | "Discard-or-skip" prompt when inventory hits MAX_INVENTORY |

**Modified files:**

| Path | What changes |
|---|---|
| `run_system/core/run_manager.gd` | `equipped_items` Array→Dict; add `base_attributes`, `inventory_items`, `MAX_INVENTORY`, new methods, equipment data loader, `equipment_changed` signal |
| `battle_scene/data_validator.gd` | Add `EQUIPMENT_DIR`, `SET_DIR`, schemas + validators; extend `validate_all_data_at_startup` |
| `battle_scene/battle_scene.gd` | Instantiate `equipment_set_system`; call `on_battle_started` + `on_player_turn_started`; declare `current_resolving_card`; set/clear in `play_spell` |
| `battle_scene/combat_engine.gd` | Read `main.current_resolving_card`; insert modify-block, modify-damage, post-damage hooks |
| `run_system/ui/map_scene.gd` | Add `[⚔ EQUIPMENT]` top-bar button; treasure node 50/50 split; route equipment grants to the same path used by loot |
| `run_system/ui/loot_reward.gd` | Equipment drop row for elite/boss; route to inventory-full modal when needed |

---

## Tasks

### Task 1: RunManager structural refactor

Convert `equipped_items` from `Array[String]` to `Dictionary` keyed by slot, add new fields, update `reset_run`, and migrate the 3 callsites inside run_manager.gd itself. Standalone (no API methods yet — those come in Task 2). Goal: project still boots green after this task.

**Files:**
- Modify: `run_system/core/run_manager.gd:20-46`, `:355-374`, `:422-430`, `:520-525`

- [ ] **Step 1: Read current state of the affected lines**

Open `run_system/core/run_manager.gd` and confirm the fields at 20-46 match the spec assumption (`equipped_items: Array[String] = []`, `MAX_ITEMS: int = 5`, `player_attributes` dict with 5 keys). If diverged, adjust replacements accordingly.

- [ ] **Step 2: Replace field declarations**

Edit `run_system/core/run_manager.gd`, replace the block from line 20 onward:

```gdscript
var gold: int = 0
var core: int = 0

# Progression
var current_floor: int = 0
var player_deck: Array = [] # Array of Dictionaries (uid, card_id, bonus_attack, bonus_health)

## Equipped gear, one slot per body part. Empty string = empty slot.
var equipped_items: Dictionary = {
	"head": "",
	"chest": "",
	"weapon": "",
	"hands": "",
	"accessory": "",
}

## Unequipped equipment held by the player. Capped at MAX_INVENTORY.
var inventory_items: Array[String] = []

var relics: Array[String] = []
const MAX_INVENTORY: int = 8
const EQUIPMENT_SLOTS: Array[String] = ["head", "chest", "weapon", "hands", "accessory"]
const DEFAULT_STARTER_DECK = [
	"strike", "strike", "strike", "strike",
	"weak_strike",
	"defend", "defend", "defend", "defend",
]

## Five-dimension RPG attributes. base_attributes is the unchanging baseline
## set at run start; player_attributes is the COMPUTED total (base + bonuses
## from equipped items), refreshed by recompute_attributes() — never mutated
## directly by gameplay code outside RunManager.
var base_attributes: Dictionary = {
	"strength": 3,
	"constitution": 3,
	"intelligence": 3,
	"luck": 3,
	"charm": 3,
}
var player_attributes: Dictionary = {
	"strength": 3,
	"constitution": 3,
	"intelligence": 3,
	"luck": 3,
	"charm": 3,
}
```

Note: the old `MAX_ITEMS: int = 5` constant is gone — replaced by `EQUIPMENT_SLOTS.size()` semantically + `MAX_INVENTORY` for the bag cap.

- [ ] **Step 3: Add the new signal**

Inside `run_system/core/run_manager.gd`, find the existing signal declarations (search `signal `). Add this signal alongside them (at the top of the file's signal block, exact location depends on current state):

```gdscript
signal equipment_changed
```

- [ ] **Step 4: Update `reset_run` to reset the new shape**

Find the block in `reset_run()` that currently has `equipped_items.clear()` (around line 362). Replace surrounding lines:

```gdscript
# Reset resources and health
gold = 0
core = 0
current_floor = 0
current_health = max_health
for slot in EQUIPMENT_SLOTS:
	equipped_items[slot] = ""
inventory_items.clear()
relics.clear()
current_encounter = ["trash_robot"]
generate_map(12, 4)
base_attributes = {
	"strength": 3, "constitution": 3,
	"intelligence": 3, "luck": 3, "charm": 3,
}
player_attributes = base_attributes.duplicate()
is_run_active = true
_emit_all_state()
```

- [ ] **Step 5: Delete the obsolete `equip_item` stub**

Find and delete the function (currently around lines 424-430):

```gdscript
# DELETE THIS:
## Returns true if the item was successfully equipped
func equip_item(item_id: String) -> bool:
	if equipped_items.size() < MAX_ITEMS:
		equipped_items.append(item_id)
		emit_signal("items_updated")
		return true
	return false
```

(Will be replaced by `equip_to_slot` in Task 2.)

- [ ] **Step 6: Fix the debug print**

Find the line `print("Items: ", equipped_items)` (around line 524). Update so the dict prints cleanly:

```gdscript
print("Items: ", equipped_items, " Inventory: ", inventory_items)
```

- [ ] **Step 7: Headless parse check**

Run from project root:

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected output: exactly one line — `DataValidator: all card/enemy/relic JSON files passed schema check.` No other errors. If there are parse errors, fix them before continuing.

- [ ] **Step 8: Commit**

```
git add run_system/core/run_manager.gd
git commit -m "Refactor RunManager equipment state: dict by slot + inventory + base_attributes"
```

---

### Task 2: RunManager equipment API

Add the 6 new methods + equipment-data loader. No callers exist yet; this just makes the API available.

**Files:**
- Modify: `run_system/core/run_manager.gd` (add methods + constant)

- [ ] **Step 1: Add the equipment data directory constant**

Find the block of const directory paths (search `RELIC_DATA_DIR`). Add:

```gdscript
const EQUIPMENT_DATA_DIR: String = "res://run_system/data/equipment/"
const EQUIPMENT_SET_DATA_DIR: String = "res://run_system/data/equipment_sets/"
```

- [ ] **Step 2: Add the equipment-data loader methods**

Find `get_relic_data` (line ~452). Add immediately after it:

```gdscript
## Load equipment JSON by id. Returns empty dict on miss.
func get_equipment_data(item_id: String) -> Dictionary:
	if item_id == "":
		return {}
	var path = EQUIPMENT_DATA_DIR + item_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Load equipment set JSON by id. Returns empty dict on miss.
func get_equipment_set_data(set_id: String) -> Dictionary:
	if set_id == "":
		return {}
	var path = EQUIPMENT_SET_DATA_DIR + set_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
```

- [ ] **Step 3: Add `recompute_attributes`**

In `# --- Items ---` section (line ~422), add:

```gdscript
## Recompute player_attributes = base_attributes + sum of every equipped item's
## bonuses. Idempotent. Emits equipment_changed.
func recompute_attributes() -> void:
	var totals = base_attributes.duplicate()
	for slot in EQUIPMENT_SLOTS:
		var item_id: String = equipped_items.get(slot, "")
		if item_id == "":
			continue
		var data = get_equipment_data(item_id)
		var bonuses = data.get("bonuses", {})
		if typeof(bonuses) != TYPE_DICTIONARY:
			continue
		for attr in bonuses.keys():
			if attr in totals:
				totals[attr] = int(totals[attr]) + int(bonuses[attr])
	player_attributes = totals
	emit_signal("equipment_changed")
```

- [ ] **Step 4: Add `equip_to_slot`**

```gdscript
## Equip item_id into slot. If slot is occupied, the previous occupant moves
## to inventory. Returns false (no-op) if slot is occupied AND inventory is
## full. Caller must show the inventory-full modal before retrying.
## Calls recompute_attributes() on success.
func equip_to_slot(item_id: String, slot: String) -> bool:
	if not slot in EQUIPMENT_SLOTS:
		push_error("equip_to_slot: unknown slot '%s'" % slot)
		return false
	if item_id == "":
		push_error("equip_to_slot: item_id is empty")
		return false
	var data = get_equipment_data(item_id)
	if data.is_empty():
		push_error("equip_to_slot: no JSON for item '%s'" % item_id)
		return false
	if str(data.get("slot", "")) != slot:
		push_error("equip_to_slot: item '%s' is slot '%s', cannot fit into '%s'" % [item_id, data.get("slot", ""), slot])
		return false

	var prev: String = equipped_items.get(slot, "")
	if prev != "":
		if inventory_items.size() >= MAX_INVENTORY:
			return false
		inventory_items.append(prev)

	# Remove item_id from inventory if it was there (equipping from bag is common path)
	var bag_idx = inventory_items.find(item_id)
	if bag_idx >= 0:
		inventory_items.remove_at(bag_idx)

	equipped_items[slot] = item_id
	recompute_attributes()
	return true
```

- [ ] **Step 5: Add `unequip_slot`**

```gdscript
## Move the item in slot to inventory. Returns false if inventory is full.
## Calls recompute_attributes() on success.
func unequip_slot(slot: String) -> bool:
	if not slot in EQUIPMENT_SLOTS:
		push_error("unequip_slot: unknown slot '%s'" % slot)
		return false
	var item_id: String = equipped_items.get(slot, "")
	if item_id == "":
		return true  # already empty, treat as success no-op
	if inventory_items.size() >= MAX_INVENTORY:
		return false
	inventory_items.append(item_id)
	equipped_items[slot] = ""
	recompute_attributes()
	return true
```

- [ ] **Step 6: Add `add_to_inventory` and `discard_from_inventory`**

```gdscript
## Append to inventory. Returns false at MAX_INVENTORY (caller handles UI).
func add_to_inventory(item_id: String) -> bool:
	if item_id == "":
		return false
	if inventory_items.size() >= MAX_INVENTORY:
		return false
	inventory_items.append(item_id)
	emit_signal("equipment_changed")
	return true


## Discard inventory[index]. Out-of-range = silent no-op.
func discard_from_inventory(index: int) -> void:
	if index < 0 or index >= inventory_items.size():
		return
	inventory_items.remove_at(index)
	emit_signal("equipment_changed")
```

- [ ] **Step 7: Add `get_active_set_tiers`**

```gdscript
## Returns { set_id: piece_count } over currently equipped items.
## Sets with zero equipped pieces are omitted.
func get_active_set_tiers() -> Dictionary:
	var counts: Dictionary = {}
	for slot in EQUIPMENT_SLOTS:
		var item_id: String = equipped_items.get(slot, "")
		if item_id == "":
			continue
		var data = get_equipment_data(item_id)
		var set_id: String = str(data.get("set_id", ""))
		if set_id == "":
			continue
		counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts
```

- [ ] **Step 8: Headless parse check**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: only the DataValidator success line.

- [ ] **Step 9: Commit**

```
git add run_system/core/run_manager.gd
git commit -m "Add RunManager equipment API (equip/unequip/inventory/sets/recompute)"
```

---

### Task 3: DataValidator equipment + set schemas

Wire schema enforcement BEFORE the JSON files exist — that way Task 4's first invalid file fails loudly.

**Files:**
- Modify: `battle_scene/data_validator.gd`

- [ ] **Step 1: Add directory + schema constants**

Open `battle_scene/data_validator.gd`. Find the `# ─── Paths ───` block (line 11). Append the equipment paths:

```gdscript
const EQUIPMENT_DIR = "res://run_system/data/equipment/"
const SET_DIR       = "res://run_system/data/equipment_sets/"
```

After the existing `STATUS_BEARING_ACTIONS` block (line ~46), add the equipment block:

```gdscript
# ─── Equipment schema ────────────────────────────────────────────────────────
const REQUIRED_EQUIPMENT_KEYS = ["id", "name", "slot", "rarity", "bonuses", "description", "sprite"]
const ALLOWED_EQUIPMENT_SLOTS = ["head", "chest", "weapon", "hands", "accessory"]
const ALLOWED_ATTRIBUTE_KEYS  = ["strength", "constitution", "intelligence", "luck", "charm"]
const KNOWN_OPTIONAL_EQUIPMENT_KEYS = ["set_id"]

# ─── Equipment set schema ────────────────────────────────────────────────────
const REQUIRED_SET_KEYS = ["id", "name", "description", "tiers"]
const REQUIRED_TIER_KEYS = ["count", "label", "effect"]
const ALLOWED_SET_EFFECT_TYPES = [
	"start_turn_block", "start_turn_energy", "start_battle_block",
	"skill_block_bonus", "attack_damage_bonus", "attack_apply_status",
]
const STATUS_BEARING_SET_EFFECTS = ["attack_apply_status"]
```

- [ ] **Step 2: Wire equipment + set validation into `validate_all_data_at_startup`**

Find `validate_all_data_at_startup` (line ~52). Add two more `_validate_dir` calls before the encounter pool check:

```gdscript
static func validate_all_data_at_startup() -> int:
	var failures = 0
	failures += _validate_dir(CARD_DIR,  Callable(DataValidator, "validate_card"))
	failures += _validate_dir(ENEMY_DIR, Callable(DataValidator, "validate_enemy"))
	failures += _validate_dir(RELIC_DIR, Callable(DataValidator, "validate_relic"))
	failures += _validate_dir(EQUIPMENT_DIR, Callable(DataValidator, "validate_equipment"))
	failures += _validate_dir(SET_DIR,       Callable(DataValidator, "validate_equipment_set"))
	failures += validate_encounter_pools()

	if failures > 0:
		push_error("DataValidator: %d validation failure(s). See errors above." % failures)
	else:
		print("DataValidator: all card/enemy/relic/equipment JSON files passed schema check.")
	return failures
```

- [ ] **Step 3: Add `validate_equipment`**

Add after `validate_relic` (line ~248):

```gdscript
## Validate a single equipment JSON dictionary. Returns true on success.
static func validate_equipment(data: Dictionary, source_path: String) -> bool:
	var prefix := "Equipment '%s'" % source_path
	var ok := true

	for key in REQUIRED_EQUIPMENT_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false

	if not ok:
		return false

	if not str(data["slot"]) in ALLOWED_EQUIPMENT_SLOTS:
		push_error("%s: slot '%s' not in %s" % [prefix, data["slot"], ALLOWED_EQUIPMENT_SLOTS])
		ok = false

	if not str(data["rarity"]) in ALLOWED_RARITIES:
		push_error("%s: rarity '%s' not in %s" % [prefix, data["rarity"], ALLOWED_RARITIES])
		ok = false

	var bonuses = data["bonuses"]
	if typeof(bonuses) != TYPE_DICTIONARY:
		push_error("%s: bonuses must be a Dictionary" % prefix)
		ok = false
	else:
		for attr in bonuses.keys():
			if not str(attr) in ALLOWED_ATTRIBUTE_KEYS:
				push_error("%s: bonus attr '%s' not in %s" % [prefix, attr, ALLOWED_ATTRIBUTE_KEYS])
				ok = false
			elif typeof(bonuses[attr]) != TYPE_INT and typeof(bonuses[attr]) != TYPE_FLOAT:
				push_error("%s: bonus '%s' must be a number, got %s" % [prefix, attr, typeof(bonuses[attr])])
				ok = false

	# Unknown top-level keys → warn (helps catch typos)
	var known_keys = REQUIRED_EQUIPMENT_KEYS + KNOWN_OPTIONAL_EQUIPMENT_KEYS
	for key in data.keys():
		if not key in known_keys:
			push_warning("%s: unknown top-level key '%s' (typo?)" % [prefix, key])

	return ok
```

- [ ] **Step 4: Add `validate_equipment_set`**

```gdscript
## Validate a single equipment set JSON dictionary. Returns true on success.
static func validate_equipment_set(data: Dictionary, source_path: String) -> bool:
	var prefix := "Set '%s'" % source_path
	var ok := true

	for key in REQUIRED_SET_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false

	if not ok:
		return false

	var tiers = data["tiers"]
	if typeof(tiers) != TYPE_ARRAY:
		push_error("%s: tiers must be an Array" % prefix)
		return false

	for i in range(tiers.size()):
		var tier = tiers[i]
		if typeof(tier) != TYPE_DICTIONARY:
			push_error("%s: tier[%d] is not a Dictionary" % [prefix, i])
			ok = false
			continue
		for key in REQUIRED_TIER_KEYS:
			if not tier.has(key):
				push_error("%s: tier[%d] missing key '%s'" % [prefix, i, key])
				ok = false

		var effect = tier.get("effect", {})
		if typeof(effect) != TYPE_DICTIONARY:
			push_error("%s: tier[%d] effect is not a Dictionary" % [prefix, i])
			ok = false
			continue
		var etype = str(effect.get("type", ""))
		if not etype in ALLOWED_SET_EFFECT_TYPES:
			push_error("%s: tier[%d] effect type '%s' not in %s" % [prefix, i, etype, ALLOWED_SET_EFFECT_TYPES])
			ok = false
		if etype in STATUS_BEARING_SET_EFFECTS:
			if not effect.has("status"):
				push_error("%s: tier[%d] effect (%s) missing 'status'" % [prefix, i, etype])
				ok = false
			elif not str(effect["status"]) in ALLOWED_STATUS_NAMES:
				push_error("%s: tier[%d] status '%s' not in %s" % [prefix, i, effect["status"], ALLOWED_STATUS_NAMES])
				ok = false

	return ok
```

- [ ] **Step 5: Headless parse check**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: success line (now also mentions equipment), AND a `cannot open directory 'res://run_system/data/equipment/'` push_error because the dirs don't exist yet. That's fine — Task 4 creates them.

If the `cannot open directory` message ranks as a `failures += 1` (it does — see `_validate_dir`), you should see total failure count increment. That's acceptable for this commit because the next task creates the dirs. If you'd rather avoid the noise, **create the empty directories now**:

```
mkdir -p run_system/data/equipment run_system/data/equipment_sets
```

- [ ] **Step 6: Commit**

```
git add battle_scene/data_validator.gd run_system/data/equipment run_system/data/equipment_sets
git commit -m "Add equipment + set schema validators (no data yet)"
```

If you used `mkdir` and the dirs are empty, also add `.gitkeep` files or git will skip them:

```
touch run_system/data/equipment/.gitkeep run_system/data/equipment_sets/.gitkeep
git add run_system/data/equipment/.gitkeep run_system/data/equipment_sets/.gitkeep
git commit --amend --no-edit
```

---

### Task 4: Equipment + set JSON content

Create 14 equipment files (10 set pieces + 4 plain) and 2 set files. Validator runs on each save.

**Files:**
- Create: `run_system/data/equipment_sets/weak_hunter.json`
- Create: `run_system/data/equipment_sets/tank_engineer.json`
- Create: `run_system/data/equipment/weak_hunter_{helm,vest,gun,gloves,trinket}.json` (5 pieces, slots head/chest/weapon/hands/accessory)
- Create: `run_system/data/equipment/tank_engineer_{helm,vest,hammer,gauntlets,coil}.json` (5 pieces)
- Create: `run_system/data/equipment/{old_hat,scrap_breastplate,rusted_dagger,lucky_charm}.json` (4 plain)

- [ ] **Step 1: Create `weak_hunter` set file**

`run_system/data/equipment_sets/weak_hunter.json`:

```json
{
  "id": "weak_hunter",
  "name": "Weak Hunter",
  "description": "A scavenged kit that punishes the vulnerable.",
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

- [ ] **Step 2: Create `tank_engineer` set file**

`run_system/data/equipment_sets/tank_engineer.json`:

```json
{
  "id": "tank_engineer",
  "name": "Tank Engineer",
  "description": "Heavy plating welded from junkyard salvage.",
  "tiers": [
    {
      "count": 3,
      "label": "+1 Block at the start of every turn",
      "effect": { "type": "start_turn_block", "amount": 1 }
    },
    {
      "count": 5,
      "label": "+2 Damage on attack cards",
      "effect": { "type": "attack_damage_bonus", "amount": 2 }
    }
  ]
}
```

- [ ] **Step 3: Create the 5 `weak_hunter` set pieces**

`run_system/data/equipment/weak_hunter_helm.json`:

```json
{
  "id": "weak_hunter_helm",
  "name": "Hunter's Visor",
  "slot": "head",
  "rarity": "common",
  "set_id": "weak_hunter",
  "bonuses": { "luck": 1 },
  "description": "Cracked goggles that see what others ignore.",
  "sprite": "equipment/weak_hunter_helm.png"
}
```

`run_system/data/equipment/weak_hunter_vest.json`:

```json
{
  "id": "weak_hunter_vest",
  "name": "Stalker's Vest",
  "slot": "chest",
  "rarity": "common",
  "set_id": "weak_hunter",
  "bonuses": { "luck": 1, "charm": 1 },
  "description": "Lightweight. Smells of dust and old oil.",
  "sprite": "equipment/weak_hunter_vest.png"
}
```

`run_system/data/equipment/weak_hunter_gun.json`:

```json
{
  "id": "weak_hunter_gun",
  "name": "Marked Sidearm",
  "slot": "weapon",
  "rarity": "uncommon",
  "set_id": "weak_hunter",
  "bonuses": { "strength": 2 },
  "description": "Notched grip — one notch per failed target.",
  "sprite": "equipment/weak_hunter_gun.png"
}
```

`run_system/data/equipment/weak_hunter_gloves.json`:

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

`run_system/data/equipment/weak_hunter_trinket.json`:

```json
{
  "id": "weak_hunter_trinket",
  "name": "Faded Sigil",
  "slot": "accessory",
  "rarity": "common",
  "set_id": "weak_hunter",
  "bonuses": { "intelligence": 1, "charm": 1 },
  "description": "A pendant carved from chipped bone.",
  "sprite": "equipment/weak_hunter_trinket.png"
}
```

- [ ] **Step 4: Create the 5 `tank_engineer` set pieces**

`run_system/data/equipment/tank_engineer_helm.json`:

```json
{
  "id": "tank_engineer_helm",
  "name": "Reinforced Hardhat",
  "slot": "head",
  "rarity": "common",
  "set_id": "tank_engineer",
  "bonuses": { "constitution": 2 },
  "description": "Steel-banded. Heavy. Reliable.",
  "sprite": "equipment/tank_engineer_helm.png"
}
```

`run_system/data/equipment/tank_engineer_vest.json`:

```json
{
  "id": "tank_engineer_vest",
  "name": "Plated Vest",
  "slot": "chest",
  "rarity": "uncommon",
  "set_id": "tank_engineer",
  "bonuses": { "constitution": 3 },
  "description": "Welded scrap iron over a leather core.",
  "sprite": "equipment/tank_engineer_vest.png"
}
```

`run_system/data/equipment/tank_engineer_hammer.json`:

```json
{
  "id": "tank_engineer_hammer",
  "name": "Pipe Hammer",
  "slot": "weapon",
  "rarity": "common",
  "set_id": "tank_engineer",
  "bonuses": { "strength": 2 },
  "description": "Heavy enough to discourage second hits.",
  "sprite": "equipment/tank_engineer_hammer.png"
}
```

`run_system/data/equipment/tank_engineer_gauntlets.json`:

```json
{
  "id": "tank_engineer_gauntlets",
  "name": "Iron Gauntlets",
  "slot": "hands",
  "rarity": "common",
  "set_id": "tank_engineer",
  "bonuses": { "constitution": 1, "strength": 1 },
  "description": "Better than no gauntlets.",
  "sprite": "equipment/tank_engineer_gauntlets.png"
}
```

`run_system/data/equipment/tank_engineer_coil.json`:

```json
{
  "id": "tank_engineer_coil",
  "name": "Power Coil",
  "slot": "accessory",
  "rarity": "uncommon",
  "set_id": "tank_engineer",
  "bonuses": { "constitution": 2, "intelligence": 1 },
  "description": "Hums with stored kinetic energy.",
  "sprite": "equipment/tank_engineer_coil.png"
}
```

- [ ] **Step 5: Create the 4 plain (no-set) pieces**

`run_system/data/equipment/old_hat.json`:

```json
{
  "id": "old_hat",
  "name": "Old Wasteland Hat",
  "slot": "head",
  "rarity": "common",
  "bonuses": { "charm": 1 },
  "description": "Looks better than nothing.",
  "sprite": "equipment/old_hat.png"
}
```

`run_system/data/equipment/scrap_breastplate.json`:

```json
{
  "id": "scrap_breastplate",
  "name": "Scrap Breastplate",
  "slot": "chest",
  "rarity": "common",
  "bonuses": { "constitution": 1 },
  "description": "Rivets going every which way.",
  "sprite": "equipment/scrap_breastplate.png"
}
```

`run_system/data/equipment/rusted_dagger.json`:

```json
{
  "id": "rusted_dagger",
  "name": "Rusted Dagger",
  "slot": "weapon",
  "rarity": "common",
  "bonuses": { "strength": 1, "luck": 1 },
  "description": "Sharp where it counts. Mostly.",
  "sprite": "equipment/rusted_dagger.png"
}
```

`run_system/data/equipment/lucky_charm.json`:

```json
{
  "id": "lucky_charm",
  "name": "Lucky Charm",
  "slot": "accessory",
  "rarity": "uncommon",
  "bonuses": { "luck": 2 },
  "description": "Definitely magic. Probably.",
  "sprite": "equipment/lucky_charm.png"
}
```

- [ ] **Step 6: Headless validation**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: success line (now with equipment), zero errors.

If you see a slot mismatch or unknown attribute error: open the offending file and fix the typo. The validator names the file in the error message.

- [ ] **Step 7: Commit**

```
git add run_system/data/equipment run_system/data/equipment_sets
git commit -m "Add 14 equipment + 2 set JSON files (weak_hunter, tank_engineer)"
```

---

### Task 5: `equipment_set_system` module + basic hooks

Build the new module mirroring `relic_effect_system`. Wire battle_scene to call it at battle start + turn start. Implement the 3 simple effect types only (`start_turn_block`, `start_turn_energy`, `start_battle_block`). The 3 combat-coupled effect types come in Task 6.

**Files:**
- Create: `battle_scene/equipment_set_system.gd`
- Modify: `battle_scene/battle_scene.gd` (constant, var, setup, hook calls)

- [ ] **Step 1: Create `equipment_set_system.gd`**

`battle_scene/equipment_set_system.gd`:

```gdscript
## EquipmentSetSystem snapshots active set tiers at battle start and applies
## the resulting "virtual relic-like" effects via the same trigger model as
## relic_effect_system. Reads RunManager.equipped_items + .get_active_set_tiers().
##
## Snapshot semantics: equipment cannot change during a battle (PRD), so we
## resolve which tiers are active in `on_battle_started()` and ignore later
## changes to RunManager.equipped_items.
extends RefCounted
class_name EquipmentSetSystem

var _battle_scene: Node
## Each entry: { "set_id": String, "tier_label": String, "effect": Dictionary }
var _active_effects: Array = []


func setup(battle_scene: Node) -> void:
	_battle_scene = battle_scene
	_active_effects.clear()


## Resolve active tier effects from RunManager and notify each one. Call once
## at battle start, after attribute injection.
func on_battle_started(player: Node) -> void:
	_active_effects.clear()
	if not RunManager.is_run_active:
		return

	var tiers: Dictionary = RunManager.get_active_set_tiers()
	for set_id in tiers.keys():
		var count: int = int(tiers[set_id])
		var set_data: Dictionary = RunManager.get_equipment_set_data(str(set_id))
		var tier_list = set_data.get("tiers", [])
		if typeof(tier_list) != TYPE_ARRAY:
			continue
		for tier in tier_list:
			if typeof(tier) != TYPE_DICTIONARY:
				continue
			if count >= int(tier.get("count", 999)):
				_active_effects.append({
					"set_id": str(set_id),
					"tier_label": str(tier.get("label", "")),
					"effect": tier.get("effect", {}),
				})

	# Apply start_battle_block effects right now
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "start_battle_block":
			var amount = int(effect.get("amount", 0))
			if player and player.has_method("add_block"):
				player.add_block(amount)
				_notify("%s: +%d Block (battle start)" % [entry["tier_label"], amount], Color(0.45, 0.7, 1.0))


## Apply start_turn_block / start_turn_energy effects.
func on_player_turn_started(player: Node, _round_number: int) -> void:
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		var amount = int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"start_turn_block":
				if player and player.has_method("add_block"):
					player.add_block(amount)
					_notify("%s: +%d Block" % [entry["tier_label"], amount], Color(0.45, 0.7, 1.0))
			"start_turn_energy":
				if player and player.has_method("pay_energy"):
					player.pay_energy(-amount)
					_notify("%s: +%d Energy" % [entry["tier_label"], amount], Color(0.95, 0.9, 0.25))


## Hooks for Task 6 (placeholders so combat_engine compiles after that task).
func modify_card_block(_card: Node, amount: int) -> int:
	return amount


func modify_card_damage(_card: Node, amount: int) -> int:
	return amount


func on_card_damage_resolved(_card: Node, _target: Node) -> void:
	pass


func _notify(text: String, color: Color) -> void:
	if _battle_scene and _battle_scene.has_method("show_notification"):
		_battle_scene.show_notification(text, color)
```

- [ ] **Step 2: Wire the system into `battle_scene.gd`**

In `battle_scene/battle_scene.gd`, find `const RELIC_EFFECT_SYSTEM = preload(...)` (line ~31). Add immediately below:

```gdscript
const EQUIPMENT_SET_SYSTEM = preload("res://battle_scene/equipment_set_system.gd")
```

Find `var relic_effect_system: RefCounted` (line ~18). Add immediately below:

```gdscript
var equipment_set_system: RefCounted  # EquipmentSetSystem (equipment_set_system.gd) instance
```

- [ ] **Step 3: Instantiate + setup**

Find `relic_effect_system = RELIC_EFFECT_SYSTEM.new()` (line ~235). Add immediately after `relic_effect_system.setup(self)`:

```gdscript
equipment_set_system = EQUIPMENT_SET_SYSTEM.new()
equipment_set_system.setup(self)
```

- [ ] **Step 4: Call `on_battle_started` at battle start**

In the same `_start_new_game` function, find the block that reads `player.strength = int(attrs.get(...))` etc. (line ~243). Add immediately AFTER the attribute block and before the deck/turn block:

```gdscript
# Snapshot active equipment set tiers (and apply start_battle_block)
if equipment_set_system:
	equipment_set_system.on_battle_started(player)
```

- [ ] **Step 5: Call `on_player_turn_started` each player turn**

Find the existing `relic_effect_system.on_player_turn_started(player, turn_manager.current_round)` call (line ~163). Add immediately after:

```gdscript
if equipment_set_system:
	equipment_set_system.on_player_turn_started(player, turn_manager.current_round)
```

- [ ] **Step 6: Headless parse + DataValidator check**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: success line, zero parse errors.

- [ ] **Step 7: Manual smoke (optional but recommended)**

If you can, run the editor: launch game, start a run, on the map screen open the GDScript console (F8) and run:

```
RunManager.equip_to_slot("tank_engineer_helm", "head")
RunManager.equip_to_slot("tank_engineer_vest", "chest")
RunManager.equip_to_slot("tank_engineer_hammer", "weapon")
print(RunManager.get_active_set_tiers())  # → { "tank_engineer": 3 }
```

Then go into a battle. On player turn 1, you should see the "Tank Engineer ... +1 Block" notification. If not, debug-print inside `on_player_turn_started` to verify `_active_effects` has the entry.

Skip this smoke if you don't have access to a desktop session — Task 11 covers end-to-end.

- [ ] **Step 8: Commit**

```
git add battle_scene/equipment_set_system.gd battle_scene/battle_scene.gd
git commit -m "Add equipment_set_system: snapshot at battle start + turn-start hooks"
```

---

### Task 6: Combat hooks for card-modifying set effects

Wire `current_resolving_card` tracking into `battle_scene.play_spell`. Insert three hooks into `combat_engine._apply_effect`. Replace the Task 5 placeholder method bodies with real logic for `skill_block_bonus`, `attack_damage_bonus`, `attack_apply_status`.

**Files:**
- Modify: `battle_scene/battle_scene.gd` (`current_resolving_card` var + set/clear in `play_spell`)
- Modify: `battle_scene/combat_engine.gd` (three hook insertions in `_apply_effect`)
- Modify: `battle_scene/equipment_set_system.gd` (real method bodies)

- [ ] **Step 1: Declare `current_resolving_card` on battle_scene**

In `battle_scene/battle_scene.gd`, find the var declaration block (search for `var equipment_set_system`). Add:

```gdscript
var current_resolving_card: Node = null  # Set by play_spell during _apply_effect; combat_engine reads it.
```

- [ ] **Step 2: Set / clear it in `play_spell`**

In `battle_scene/battle_scene.gd`, find `play_spell` (line ~326). Locate the existing line:

```gdscript
# Resolve combat effects (may await animations)
await combat_engine.resolve_card_effect(card, target_node, player)
```

Replace with:

```gdscript
# Resolve combat effects (may await animations). current_resolving_card
# lets combat_engine + equipment_set_system identify the card behind each
# effect (needed to know whether a gain_block came from a "skill" card etc.).
current_resolving_card = card
await combat_engine.resolve_card_effect(card, target_node, player)
current_resolving_card = null
```

- [ ] **Step 3: Replace the placeholder bodies in `equipment_set_system.gd`**

In `battle_scene/equipment_set_system.gd`, replace the three placeholder methods with real implementations:

```gdscript
## Add skill_block_bonus to gain_block amount when card is a skill.
func modify_card_block(card: Node, amount: int) -> int:
	if card == null or not card.card_info.get("type", "") == "skill":
		return amount
	var result = amount
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "skill_block_bonus":
			result += int(effect.get("amount", 0))
	return result


## Add attack_damage_bonus to deal_damage amount when card is an attack.
func modify_card_damage(card: Node, amount: int) -> int:
	if card == null or not card.card_info.get("type", "") == "attack":
		return amount
	var result = amount
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "attack_damage_bonus":
			result += int(effect.get("amount", 0))
	return result


## Apply attack_apply_status to target after damage resolves on an attack card.
func on_card_damage_resolved(card: Node, target: Node) -> void:
	if card == null or not card.card_info.get("type", "") == "attack":
		return
	if target == null or not is_instance_valid(target):
		return
	for entry in _active_effects:
		var effect: Dictionary = entry["effect"]
		if str(effect.get("type", "")) == "attack_apply_status":
			var status = str(effect.get("status", ""))
			var stacks = int(effect.get("stacks", 0))
			if status == "" or stacks <= 0:
				continue
			if target.has_method("add_status"):
				target.add_status(status, stacks)
				_notify("%s: %s +%d on target" % [entry["tier_label"], status.to_upper(), stacks], Color(0.85, 0.6, 1.0))
```

- [ ] **Step 4: Hook combat_engine `gain_block`**

In `battle_scene/combat_engine.gd`, find the `"gain_block":` case (line ~100). Replace:

```gdscript
"gain_block":
	player.add_block(amount)
	main.show_notification("+%d BLOCK" % amount, Color(0.4, 0.6, 1.0))
	await get_tree().create_timer(0.2).timeout
```

with:

```gdscript
"gain_block":
	if main.equipment_set_system and main.current_resolving_card:
		amount = main.equipment_set_system.modify_card_block(main.current_resolving_card, amount)
	player.add_block(amount)
	main.show_notification("+%d BLOCK" % amount, Color(0.4, 0.6, 1.0))
	await get_tree().create_timer(0.2).timeout
```

- [ ] **Step 5: Hook combat_engine `deal_damage`**

Find the `"deal_damage":` case (line ~91). Replace:

```gdscript
"deal_damage":
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var outgoing = calculate_attack_damage(amount, player, target)
		target.take_damage(outgoing)
		_register_player_attack()
		main.show_notification("DEALT %d DAMAGE" % outgoing, Color(1.0, 0.4, 0.3))
	else:
		main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))
```

with:

```gdscript
"deal_damage":
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		if main.equipment_set_system and main.current_resolving_card:
			amount = main.equipment_set_system.modify_card_damage(main.current_resolving_card, amount)
		var outgoing = calculate_attack_damage(amount, player, target)
		target.take_damage(outgoing)
		_register_player_attack()
		main.show_notification("DEALT %d DAMAGE" % outgoing, Color(1.0, 0.4, 0.3))
		if main.equipment_set_system and main.current_resolving_card:
			main.equipment_set_system.on_card_damage_resolved(main.current_resolving_card, target)
	else:
		main.show_notification("NO TARGET!", Color(1, 0.5, 0.5))
```

- [ ] **Step 6: Hook combat_engine `deal_damage_all`**

Find the `"deal_damage_all":` case (line ~115). Replace:

```gdscript
"deal_damage_all":
	for enemy in main.enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(calculate_attack_damage(amount, player, enemy))
	_register_player_attack()
```

with:

```gdscript
"deal_damage_all":
	var per_target_amount = amount
	if main.equipment_set_system and main.current_resolving_card:
		per_target_amount = main.equipment_set_system.modify_card_damage(main.current_resolving_card, per_target_amount)
	for enemy in main.enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(calculate_attack_damage(per_target_amount, player, enemy))
			if main.equipment_set_system and main.current_resolving_card:
				main.equipment_set_system.on_card_damage_resolved(main.current_resolving_card, enemy)
	_register_player_attack()
```

- [ ] **Step 7: Headless parse**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: success line, no errors.

- [ ] **Step 8: Regression check — existing cards must still work**

Open the editor, start a quick playtest:

1. New run, into the first battle
2. Play a `strike` (attack card) → confirm damage dealt is whatever the strike normally does (no equipment yet → no bonus → unchanged from before)
3. Play a `defend` (skill/block) → confirm block applied is whatever defend normally does

If anything changed unexpectedly, the issue is most likely the `current_resolving_card` check missing — verify it's actually being set before each effect resolves.

- [ ] **Step 9: Smoke — set tier actually fires**

Open the editor console (F8), run:

```
RunManager.equip_to_slot("weak_hunter_helm", "head")
RunManager.equip_to_slot("weak_hunter_vest", "chest")
RunManager.equip_to_slot("weak_hunter_gloves", "hands")
print(RunManager.get_active_set_tiers())  # → { "weak_hunter": 3 } → tier 3 active
```

Enter battle, play a `defend` card. Block applied should be `defend_base + 1` (skill_block_bonus +1). Confirm via the "+N BLOCK" notification.

Then run the same setup but with 5 weak_hunter pieces, attack an enemy, confirm enemy gains Weak.

- [ ] **Step 10: Commit**

```
git add battle_scene/battle_scene.gd battle_scene/combat_engine.gd battle_scene/equipment_set_system.gd
git commit -m "Wire equipment set effects into combat (block/damage/status hooks)"
```

---

### Task 7: Placeholder equipment icon renderer

Reusable component used by both the equipment panel and the loot drop UI. Renders a colored panel with a slot-letter label; falls back to a real PNG when the sprite path resolves.

**Files:**
- Create: `run_system/ui/equipment_icon.gd`

- [ ] **Step 1: Create the file**

`run_system/ui/equipment_icon.gd`:

```gdscript
## Reusable equipment icon. Pass slot + item_name (used to derive a 1-2 letter
## label). If sprite_path resolves to a real file, renders that instead.
extends Panel
class_name EquipmentIcon

const SLOT_COLORS := {
	"head":      Color(0.66, 0.20, 0.20, 1.0),  # rust red
	"chest":     Color(0.17, 0.35, 0.54, 1.0),  # steel blue
	"weapon":    Color(0.76, 0.66, 0.23, 1.0),  # brass yellow
	"hands":     Color(0.24, 0.48, 0.24, 1.0),  # olive green
	"accessory": Color(0.48, 0.23, 0.56, 1.0),  # faded violet
}
const SLOT_LETTERS := {
	"head": "H",
	"chest": "C",
	"weapon": "W",
	"hands": "Hd",
	"accessory": "Ac",
}

var _label: Label
var _texture_rect: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	_build()


func _build() -> void:
	# Background style — slot color
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 1.0)
	style.border_color = Color(0.4, 0.32, 0.22, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	add_theme_stylebox_override("panel", style)

	# Label — slot letter
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

	# Texture (hidden until set)
	_texture_rect = TextureRect.new()
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.visible = false
	add_child(_texture_rect)


## Populate the icon. Call after _ready.
func set_equipment(slot: String, item_name: String, sprite_path: String = "") -> void:
	# Style update
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = SLOT_COLORS.get(slot, Color(0.3, 0.3, 0.3))

	# Label = SLOT_LETTERS preferred, else first char of item name
	_label.text = str(SLOT_LETTERS.get(slot, item_name.substr(0, 1).to_upper()))
	_label.visible = true
	_texture_rect.visible = false

	# Try to load the real texture (fallback to placeholder if missing)
	if sprite_path != "":
		var full_path = "res://battle_scene/assets/images/" + sprite_path
		if ResourceLoader.exists(full_path):
			var tex = load(full_path) as Texture2D
			if tex:
				_texture_rect.texture = tex
				_texture_rect.visible = true
				_label.visible = false


## Render an "empty slot" appearance.
func set_empty(slot: String) -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var color: Color = SLOT_COLORS.get(slot, Color(0.3, 0.3, 0.3))
		color.a = 0.3
		style.bg_color = color
	_label.text = str(SLOT_LETTERS.get(slot, "?"))
	_label.modulate = Color(1, 1, 1, 0.4)
	_label.visible = true
	_texture_rect.visible = false
```

- [ ] **Step 2: Headless parse**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: clean.

- [ ] **Step 3: Commit**

```
git add run_system/ui/equipment_icon.gd
git commit -m "Add EquipmentIcon placeholder renderer (slot color + letter, PNG fallback)"
```

---

### Task 8: Equipment panel modal on map screen

The map's `[⚔ EQUIPMENT]` button → opens a full-screen overlay with 5 slots, inventory, active set tiers, and stat row.

**Files:**
- Create: `run_system/ui/equipment_panel.gd`
- Modify: `run_system/ui/map_scene.gd` (add the button + open handler)

- [ ] **Step 1: Create the panel script**

`run_system/ui/equipment_panel.gd`:

```gdscript
## Map-screen equipment management modal. Built dynamically; attached to a
## CanvasLayer. Listens to RunManager.equipment_changed for live refresh.
extends Control
class_name EquipmentPanel

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

var _slot_rows: Dictionary = {}        # slot → { icon, name_label, action_button }
var _inventory_container: VBoxContainer
var _sets_container: VBoxContainer
var _stats_label: Label
var _status_label: Label                # transient "INVENTORY FULL" etc.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	RunManager.equipment_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Central panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(900, 640)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 12)
	margin.add_child(vroot)

	# Title + close
	var header := HBoxContainer.new()
	vroot.add_child(header)
	var title := Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	header.add_child(title)
	header.add_child(_spacer())
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)

	# Two-column body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	vroot.add_child(body)

	# Left column: slots
	var slots_col := VBoxContainer.new()
	slots_col.add_theme_constant_override("separation", 8)
	slots_col.custom_minimum_size = Vector2(420, 0)
	body.add_child(slots_col)
	var slots_title := Label.new()
	slots_title.text = "── SLOTS ──"
	slots_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	slots_col.add_child(slots_title)
	for slot in RunManager.EQUIPMENT_SLOTS:
		_slot_rows[slot] = _build_slot_row(slot, slots_col)

	# Right column: inventory
	var inv_col := VBoxContainer.new()
	inv_col.add_theme_constant_override("separation", 8)
	inv_col.custom_minimum_size = Vector2(420, 0)
	body.add_child(inv_col)
	var inv_title := Label.new()
	inv_title.name = "InventoryTitle"
	inv_title.text = "── INVENTORY (0/8) ──"
	inv_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	inv_col.add_child(inv_title)
	_inventory_container = VBoxContainer.new()
	_inventory_container.add_theme_constant_override("separation", 6)
	inv_col.add_child(_inventory_container)

	# Active sets section
	var sep1 := HSeparator.new()
	vroot.add_child(sep1)
	var sets_title := Label.new()
	sets_title.text = "── ACTIVE SETS ──"
	sets_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vroot.add_child(sets_title)
	_sets_container = VBoxContainer.new()
	_sets_container.add_theme_constant_override("separation", 4)
	vroot.add_child(_sets_container)

	# Stats row
	var sep2 := HSeparator.new()
	vroot.add_child(sep2)
	_stats_label = Label.new()
	_stats_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vroot.add_child(_stats_label)

	# Transient status (errors)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	vroot.add_child(_status_label)


func _build_slot_row(slot: String, parent: VBoxContainer) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var icon := EQUIPMENT_ICON.new()
	row.add_child(icon)

	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)

	var unequip := Button.new()
	unequip.text = "UNEQUIP"
	unequip.pressed.connect(_on_unequip_pressed.bind(slot))
	row.add_child(unequip)

	return { "icon": icon, "name_label": label, "action_button": unequip }


func _refresh() -> void:
	# Slots
	for slot in RunManager.EQUIPMENT_SLOTS:
		var row = _slot_rows[slot]
		var item_id: String = RunManager.equipped_items.get(slot, "")
		if item_id == "":
			row["icon"].set_empty(slot)
			row["name_label"].text = "%s — (empty)" % slot.to_upper()
			row["action_button"].visible = false
		else:
			var data = RunManager.get_equipment_data(item_id)
			row["icon"].set_equipment(slot, str(data.get("name", item_id)), str(data.get("sprite", "")))
			row["name_label"].text = "%s — %s\n%s" % [
				slot.to_upper(),
				str(data.get("name", item_id)),
				_format_bonuses(data.get("bonuses", {})),
			]
			row["action_button"].visible = true

	# Inventory title — find by name since the layout is nested
	var title_label := _find_label_by_name(self, "InventoryTitle")
	if title_label:
		title_label.text = "── INVENTORY (%d/%d) ──" % [RunManager.inventory_items.size(), RunManager.MAX_INVENTORY]

	# Inventory rows (rebuild every refresh — simpler than diffing)
	for child in _inventory_container.get_children():
		child.queue_free()
	for i in range(RunManager.inventory_items.size()):
		var item_id: String = RunManager.inventory_items[i]
		_inventory_container.add_child(_build_inventory_row(item_id, i))

	# Active sets
	for child in _sets_container.get_children():
		child.queue_free()
	var active_tiers: Dictionary = RunManager.get_active_set_tiers()
	# Show ALL known sets present in equipped items + all sets (if you want them
	# always visible, list every set file; for MVP show only sets with >=1 piece).
	for set_id in active_tiers.keys():
		_sets_container.add_child(_build_set_row(str(set_id), int(active_tiers[set_id])))

	# Stats
	var p = RunManager.player_attributes
	_stats_label.text = "STR:%d  CON:%d  INT:%d  LUC:%d  CHA:%d" % [
		int(p.get("strength", 0)), int(p.get("constitution", 0)),
		int(p.get("intelligence", 0)), int(p.get("luck", 0)), int(p.get("charm", 0)),
	]
	_status_label.text = ""


func _build_inventory_row(item_id: String, index: int) -> HBoxContainer:
	var data = RunManager.get_equipment_data(item_id)
	var slot = str(data.get("slot", "head"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon := EQUIPMENT_ICON.new()
	icon.set_equipment(slot, str(data.get("name", item_id)), str(data.get("sprite", "")))
	row.add_child(icon)

	var info := Label.new()
	info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.custom_minimum_size = Vector2(200, 0)
	var set_tag = ""
	if str(data.get("set_id", "")) != "":
		set_tag = "  [%s]" % str(data.get("set_id"))
	info.text = "%s\n%s%s" % [str(data.get("name", item_id)), _format_bonuses(data.get("bonuses", {})), set_tag]
	row.add_child(info)

	var equip_btn := Button.new()
	equip_btn.text = "EQUIP"
	equip_btn.pressed.connect(_on_equip_pressed.bind(item_id, slot, index))
	row.add_child(equip_btn)

	var discard_btn := Button.new()
	discard_btn.text = "DISCARD"
	discard_btn.pressed.connect(_on_discard_pressed.bind(index))
	row.add_child(discard_btn)

	return row


func _build_set_row(set_id: String, count: int) -> HBoxContainer:
	var set_data = RunManager.get_equipment_set_data(set_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %d/5" % [str(set_data.get("name", set_id)), count]
	name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	name_lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(name_lbl)

	# Tier descriptions, highlighted if active
	var tier_list = set_data.get("tiers", [])
	if typeof(tier_list) == TYPE_ARRAY:
		for tier in tier_list:
			if typeof(tier) != TYPE_DICTIONARY:
				continue
			var threshold = int(tier.get("count", 0))
			var label = Label.new()
			label.text = "[%d] %s" % [threshold, str(tier.get("label", ""))]
			if count >= threshold:
				label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			else:
				label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(label)

	return row


func _on_equip_pressed(item_id: String, slot: String, _inventory_index: int) -> void:
	if not RunManager.equip_to_slot(item_id, slot):
		_status_label.text = "INVENTORY FULL — discard something first to swap"
		# (Inventory-full modal for incoming drops is in Task 9; for slot-swap
		# we just message; user can discard then retry.)


func _on_unequip_pressed(slot: String) -> void:
	if not RunManager.unequip_slot(slot):
		_status_label.text = "INVENTORY FULL — discard something first to unequip"


func _on_discard_pressed(index: int) -> void:
	RunManager.discard_from_inventory(index)


func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return "(no bonuses)"
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)


func _spacer() -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


## Recursively find a Label child by name. Needed because the nested layout
## makes hardcoded paths brittle.
func _find_label_by_name(root: Node, target_name: String) -> Label:
	if root.name == target_name and root is Label:
		return root
	for child in root.get_children():
		var found = _find_label_by_name(child, target_name)
		if found:
			return found
	return null
```

- [ ] **Step 2: Add the EQUIPMENT button to map_scene**

In `run_system/ui/map_scene.gd`, find where existing top-bar buttons are built. (Search for the relic / deck buttons — they're built around lines 90-110 by the existing `_ready` code, after `_build_relic_choice_layer()`.) Add an equipment button. Exact insertion depends on current top-bar layout; the goal: a button at the top, near the deck button, that calls `_open_equipment_panel`.

Roughly (adapt to actual layout):

```gdscript
var equip_btn := Button.new()
equip_btn.text = "⚔ EQUIPMENT"
equip_btn.add_theme_font_size_override("font_size", 16)
equip_btn.pressed.connect(_open_equipment_panel)
top_bar.add_child(equip_btn)
```

- [ ] **Step 3: Add the open handler**

In `run_system/ui/map_scene.gd`, add at the bottom of the file:

```gdscript
const EQUIPMENT_PANEL_SCRIPT = preload("res://run_system/ui/equipment_panel.gd")

func _open_equipment_panel() -> void:
	var existing = get_node_or_null("EquipmentPanel")
	if existing:
		existing.queue_free()
		return
	var panel = EQUIPMENT_PANEL_SCRIPT.new()
	panel.name = "EquipmentPanel"
	add_child(panel)
```

- [ ] **Step 4: Headless parse**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: clean.

- [ ] **Step 5: Smoke test**

1. Launch the game in editor.
2. Start a new run → map screen.
3. Click the `⚔ EQUIPMENT` button → panel opens.
4. Open the GDScript console (F8): `RunManager.add_to_inventory("weak_hunter_helm")` and re-open the panel → see the item in the inventory list.
5. Click `[EQUIP]` next to it → confirm it moves to the HEAD slot, stat row updates (+1 luck).
6. Click `[UNEQUIP]` on the head slot → confirm it returns to inventory.
7. Equip 3 weak_hunter pieces → active set tier 3 should highlight green.
8. Click `X` to close.

- [ ] **Step 6: Commit**

```
git add run_system/ui/equipment_panel.gd run_system/ui/map_scene.gd
git commit -m "Add equipment panel modal on map screen (5 slots + inventory + sets)"
```

---

### Task 9: Loot reward equipment drops + inventory full modal

Add equipment drop section to `loot_reward.gd` for elite/boss. When inventory is full, show the discard-or-skip modal.

**Files:**
- Create: `run_system/ui/inventory_full_modal.gd`
- Modify: `run_system/ui/loot_reward.gd` (add drop section)
- Modify: `run_system/core/run_manager.gd` (add `roll_equipment_drop(rarity)` helper)

- [ ] **Step 1: Add `roll_equipment_drop` to RunManager**

In `run_system/core/run_manager.gd`, add a method near the existing equipment methods:

```gdscript
## Returns a random equipment id matching the given rarity. Returns "" if none.
## rarity: "common" | "uncommon" | "rare"
func roll_equipment_drop(rarity: String) -> String:
	var dir = DirAccess.open(EQUIPMENT_DATA_DIR)
	if dir == null:
		return ""
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and not dir.current_is_dir():
			var item_id = file_name.get_basename()
			var data = get_equipment_data(item_id)
			if str(data.get("rarity", "")) == rarity:
				candidates.append(item_id)
		file_name = dir.get_next()
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]
```

- [ ] **Step 2: Create inventory full modal**

`run_system/ui/inventory_full_modal.gd`:

```gdscript
## Modal shown when an incoming equipment drop would overflow inventory.
## Player picks one bag item to discard, or skips the new item.
extends Control
class_name InventoryFullModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

signal resolved(took_item: bool)

var _incoming_item_id: String
var _selected_bag_index: int = -1
var _bag_buttons: Array[Button] = []


func setup(incoming_item_id: String) -> void:
	_incoming_item_id = incoming_item_id


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(680, 480)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTORY FULL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick something to discard, or skip the new equipment:"
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	var bag_grid := GridContainer.new()
	bag_grid.columns = 4
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(bag_grid)
	for i in range(RunManager.inventory_items.size()):
		var btn := Button.new()
		var data = RunManager.get_equipment_data(RunManager.inventory_items[i])
		btn.text = str(data.get("name", RunManager.inventory_items[i]))
		btn.toggle_mode = true
		btn.pressed.connect(_on_bag_pressed.bind(i, btn))
		bag_grid.add_child(btn)
		_bag_buttons.append(btn)

	var incoming_box := HBoxContainer.new()
	incoming_box.add_theme_constant_override("separation", 8)
	vbox.add_child(incoming_box)
	var inc_label_l := Label.new()
	inc_label_l.text = "── INCOMING ──"
	inc_label_l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	incoming_box.add_child(inc_label_l)
	var inc_data = RunManager.get_equipment_data(_incoming_item_id)
	var inc_icon = EQUIPMENT_ICON.new()
	inc_icon.set_equipment(str(inc_data.get("slot", "head")), str(inc_data.get("name", _incoming_item_id)), str(inc_data.get("sprite", "")))
	incoming_box.add_child(inc_icon)
	var inc_label := Label.new()
	inc_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	var set_tag := ""
	if str(inc_data.get("set_id", "")) != "":
		set_tag = "  [%s]" % str(inc_data.get("set_id"))
	inc_label.text = "%s%s" % [str(inc_data.get("name", _incoming_item_id)), set_tag]
	incoming_box.add_child(inc_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	vbox.add_child(actions)
	var discard_btn := Button.new()
	discard_btn.text = "DISCARD SELECTED"
	discard_btn.pressed.connect(_on_discard_selected)
	actions.add_child(discard_btn)
	var skip_btn := Button.new()
	skip_btn.text = "SKIP NEW ITEM"
	skip_btn.pressed.connect(_on_skip)
	actions.add_child(skip_btn)


func _on_bag_pressed(index: int, btn: Button) -> void:
	_selected_bag_index = index
	# Single-select: clear others
	for other in _bag_buttons:
		if other != btn and other.button_pressed:
			other.set_pressed_no_signal(false)


func _on_discard_selected() -> void:
	if _selected_bag_index < 0:
		return  # nothing selected, ignore
	RunManager.discard_from_inventory(_selected_bag_index)
	RunManager.add_to_inventory(_incoming_item_id)
	emit_signal("resolved", true)
	queue_free()


func _on_skip() -> void:
	emit_signal("resolved", false)
	queue_free()
```

- [ ] **Step 3: Wire equipment drops into loot_reward**

Open `run_system/ui/loot_reward.gd`. Find where the existing reward layout is built (look for the function that builds the gold + card draft rows). Add a method to determine drop rules and a row builder.

Determining battle source: `loot_reward` needs to know whether the just-finished battle was an enemy/elite/boss. The cleanest plumbing is via `RunManager`. Check whether `RunManager` already stores the source node type after `_on_node_clicked` (search `current_node_id` and the node type lookup). If not, add a field:

```gdscript
# In run_manager.gd, near current_encounter:
var last_battle_node_type: String = "enemy"  # "enemy" | "elite" | "boss"
```

Then in `map_scene.gd` at the point where battle is launched (lines ~215-217):

```gdscript
"enemy", "elite", "boss":
	rm.current_encounter = rm.select_encounter(node.type, int(node.floor))
	rm.last_battle_node_type = node.type   # <-- ADD
	get_tree().change_scene_to_file(rm.BATTLE_SCENE)
```

- [ ] **Step 4: Add the equipment drop row to loot_reward**

In `run_system/ui/loot_reward.gd`, add near the existing gold/card sections:

```gdscript
const INVENTORY_FULL_MODAL = preload("res://run_system/ui/inventory_full_modal.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")

## Returns "" if no drop. Otherwise an equipment id.
func _roll_drop_for_node_type(node_type: String) -> String:
	match node_type:
		"elite":
			return RunManager.roll_equipment_drop("uncommon")
		"boss":
			return RunManager.roll_equipment_drop("rare")
		_:
			return ""

## Build the equipment drop row. Append into the existing reward layout VBox.
## Pass the parent VBox where rewards live.
func _build_equipment_drop_row(parent: VBoxContainer) -> void:
	var drop_id = _roll_drop_for_node_type(RunManager.last_battle_node_type)
	if drop_id == "":
		return

	var data = RunManager.get_equipment_data(drop_id)
	var slot = str(data.get("slot", "head"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var icon := EQUIPMENT_ICON.new()
	icon.set_equipment(slot, str(data.get("name", drop_id)), str(data.get("sprite", "")))
	row.add_child(icon)

	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	var set_tag := ""
	if str(data.get("set_id", "")) != "":
		set_tag = "  [%s set]" % str(data.get("set_id"))
	label.text = "EQUIPMENT DROP: %s%s\n%s" % [
		str(data.get("name", drop_id)),
		set_tag,
		_format_bonuses(data.get("bonuses", {})),
	]
	row.add_child(label)

	var take_btn := Button.new()
	take_btn.text = "TAKE"
	take_btn.pressed.connect(_on_take_equipment.bind(drop_id, take_btn, row))
	row.add_child(take_btn)

	var skip_btn := Button.new()
	skip_btn.text = "SKIP"
	skip_btn.pressed.connect(func():
		take_btn.disabled = true
		skip_btn.disabled = true
		take_btn.text = "SKIPPED"
	)
	row.add_child(skip_btn)


func _on_take_equipment(item_id: String, take_btn: Button, row: HBoxContainer) -> void:
	if RunManager.add_to_inventory(item_id):
		take_btn.disabled = true
		take_btn.text = "TAKEN"
		# Hide skip button if it exists
		for child in row.get_children():
			if child is Button and child != take_btn:
				child.disabled = true
		return
	# Inventory full → open modal
	var modal = INVENTORY_FULL_MODAL.new()
	modal.setup(item_id)
	modal.resolved.connect(func(took_item: bool):
		if took_item:
			take_btn.disabled = true
			take_btn.text = "TAKEN"
		for child in row.get_children():
			if child is Button and child != take_btn:
				child.disabled = true
	)
	add_child(modal)


func _format_bonuses(bonuses) -> String:
	if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
		return "(no bonuses)"
	var parts: Array = []
	for attr in bonuses.keys():
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)
```

Then find the function in `loot_reward.gd` that builds the rewards (it probably has a clear name like `_build_rewards` or is in `_ready`). Add a call to `_build_equipment_drop_row(reward_vbox)` between the gold row and the card draft row (find the spot by reading the file).

- [ ] **Step 5: Headless parse**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: clean.

- [ ] **Step 6: Smoke test**

This requires a full playthrough to reach an elite or boss. As a shortcut, you can temporarily force the test from the editor console:

1. Start a run, enter a regular battle, win it.
2. On loot_reward, open the console: `RunManager.last_battle_node_type = "elite"` and force a redraw. (Or just visually verify the loot screen DOESN'T show equipment for an enemy battle.)
3. Reach an elite battle for real → win → loot screen should show equipment drop.
4. Take it → opens equipment panel later → it's in inventory.
5. Fill inventory to 8, then trigger another drop → confirm `InventoryFullModal` opens, single-select works, "DISCARD SELECTED" discards + takes.

- [ ] **Step 7: Commit**

```
git add run_system/ui/inventory_full_modal.gd run_system/ui/loot_reward.gd run_system/ui/map_scene.gd run_system/core/run_manager.gd
git commit -m "Add equipment loot drops (elite/boss) + inventory full modal"
```

---

### Task 10: Treasure node 50/50 split (relic or equipment)

Change `treasure` to roll 50/50 between the existing relic choice and an equipment grant.

**Files:**
- Modify: `run_system/ui/map_scene.gd` (treasure case in `_on_node_clicked`)

- [ ] **Step 1: Find the treasure handler**

In `run_system/ui/map_scene.gd`, locate (line ~224):

```gdscript
"treasure":
	_open_relic_choice("Choose a Relic", "treasure")
```

- [ ] **Step 2: Replace with the 50/50 split**

```gdscript
"treasure":
	if randf() < 0.5:
		_open_relic_choice("Choose a Relic", "treasure")
	else:
		_grant_treasure_equipment()
```

- [ ] **Step 3: Add the equipment grant helper**

At the bottom of `run_system/ui/map_scene.gd`, add:

```gdscript
const INVENTORY_FULL_MODAL_FOR_TREASURE = preload("res://run_system/ui/inventory_full_modal.gd")

## Treasure equipment drop: 70% uncommon / 30% rare. Either adds directly to
## inventory or opens the inventory-full modal.
func _grant_treasure_equipment() -> void:
	var rarity := "uncommon" if randf() < 0.7 else "rare"
	var item_id = RunManager.roll_equipment_drop(rarity)
	if item_id == "":
		_show_popup("The crate was empty.")
		return
	var data = RunManager.get_equipment_data(item_id)
	var name = str(data.get("name", item_id))
	if RunManager.add_to_inventory(item_id):
		_show_popup("Found %s!" % name)
		return
	# Inventory full → modal
	var modal = INVENTORY_FULL_MODAL_FOR_TREASURE.new()
	modal.setup(item_id)
	modal.resolved.connect(func(took: bool):
		if took:
			_show_popup("Took %s." % name)
		else:
			_show_popup("Left %s behind." % name)
	)
	add_child(modal)
```

- [ ] **Step 4: Headless parse**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: clean.

- [ ] **Step 5: Smoke**

Open editor, start a run, navigate to a treasure node (you may need a couple of tries to get the right RNG). Click → see either relic choice (existing behavior) or "Found X" popup (new). Open equipment panel after a successful equipment grant → confirm it's in inventory.

- [ ] **Step 6: Commit**

```
git add run_system/ui/map_scene.gd
git commit -m "Treasure node: 50/50 relic or equipment (70/30 uncommon/rare)"
```

---

### Task 11: End-to-end smoke playthrough

No code changes. Run the full integrated experience and confirm the slice is shippable.

**Files:** none (verification only)

- [ ] **Step 1: Cold start**

```
godot --headless --path . --quit-after 3 2>&1 | grep -E "ERROR|SCRIPT|Parse|DataValidator"
```

Expected: one line — `DataValidator: all card/enemy/relic/equipment JSON files passed schema check.` Zero other errors.

- [ ] **Step 2: New run, hit each surface**

Open the game in the editor. Run through this checklist, marking each:

- [ ] Hero select → enter map
- [ ] Floor 0 relic choice (existing) still works
- [ ] Click `[⚔ EQUIPMENT]` button → modal opens with 5 empty slots, 0/8 inventory, "STR:3 CON:3 INT:3 LUC:3 CHA:3"
- [ ] Close panel with X
- [ ] Navigate to a regular enemy battle → win → loot_reward shows NO equipment drop section
- [ ] Navigate to a treasure node → either relic choice OR "Found X" popup (50/50)
- [ ] If equipment popped: open panel → confirm in inventory
- [ ] Navigate to an elite battle → win → loot_reward DOES show equipment drop. Click TAKE → enters inventory
- [ ] Navigate to boss battle → win → loot_reward shows RARE equipment drop. TAKE
- [ ] Open equipment panel → equip 3 weak_hunter pieces → active set tier 3 highlights green
- [ ] Re-enter a battle (if available) → play a defend card → +1 block applied beyond normal (from skill_block_bonus)
- [ ] Equip 5 weak_hunter pieces → tier 5 also highlights → re-enter battle → attack card applies Weak 1 to enemy
- [ ] Equip 3 tank_engineer pieces → on player turn start, "Tank Engineer: +1 Block" notification fires
- [ ] Fill inventory to 8, take a 9th drop → InventoryFullModal opens, single-select works
- [ ] No `push_error` / `push_warning` lines in the editor's Output console for the entire run

- [ ] **Step 3: If any checkbox fails**

Triage:
- **Panel doesn't open** → check map_scene button wiring (Task 8 step 2)
- **Equipment drop doesn't appear** → check `last_battle_node_type` is being set on map_scene battle launch (Task 9 step 3)
- **Set tier doesn't fire in combat** → debug-print inside `equipment_set_system.on_battle_started` to confirm `_active_effects` is populated; check `current_resolving_card` is set during `play_spell`
- **Block bonus not applied** → check `card.card_info.get("type")` returns `"skill"` for defend cards (open `battle_scene/card_info/player/defend.json`, confirm `"type": "skill"`)

- [ ] **Step 4: Mark plan complete**

If all checkboxes pass, the slice is shippable. No commit needed for this task (verification only).

---

## Summary

After all 11 tasks: equipment system live with 14 items, 2 sets, full UI, loot drops on
elite/boss/treasure, working set bonuses that modify card behavior. Total ~11 commits on
`hero-refinement-v2` branch. Each task independently revertable.

**Not in this plan (future slices):**
- Shop buying/selling
- Equipment upgrades
- Per-hero starter combos
- Real PNG sprites (codex's domain — drop into `battle_scene/assets/images/equipment/<id>.png` and they auto-render)
- Tooltip preview tree
- Compare-on-hover (before/after stats)
