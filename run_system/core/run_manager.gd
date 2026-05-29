extends Node

# --- Signals ---
signal health_changed(current: int, maximum: int)
signal resources_changed(gold: int, core: int)
signal deck_updated
signal items_updated
signal equipment_changed
signal relics_updated
## Emitted when the run ends, win or lose. `summary` is the run-history
## payload for MetaProgress (and any future listener):
##   { hero_id: String, floor: int, core_earned: int, outcome: String,
##     timestamp: int (unix seconds) }
## outcome is one of "victory" (final boss kill), "extracted", "defeat".
signal run_ended(victory: bool, summary: Dictionary)

# --- Run State ---
var is_run_active: bool = false
var current_hero_id: String = ""
## Loaded hero JSON, populated by start_new_run. Empty until first run.
var current_hero_data: Dictionary = {}
## Active difficulty modifier this run (0..5). Stored on RunManager so any
## subsystem can read it without going back to MetaProgress.
var ascension: int = 0

# Base Stats
var max_health: int = 50
var current_health: int = 50

# Resources
var gold: int = 0
var core: int = 0

# Progression
var current_floor: int = 0
var player_deck: Array = []  # Array of Dictionaries (uid, card_id, bonus_attack, bonus_health)

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
const MAX_INVENTORY: int = 20
const EQUIPMENT_SLOTS: Array[String] = ["head", "chest", "weapon", "hands", "accessory"]
const DEFAULT_STARTER_DECK = [
	"strike",
	"strike",
	"strike",
	"strike",
	"weak_strike",
	"defend",
	"defend",
	"defend",
	"defend",
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

## Enemy IDs to encounter in the next battle (set by MapScene before loading battle).
## Example: ["trash_robot", "wasteland_killer"]
var current_encounter: Array[String] = ["trash_robot"]

## Set by map_scene before launching a battle. Used by loot_reward to decide
## drop rules. Values: "enemy" | "elite" | "boss".
var last_battle_node_type: String = "enemy"

## Encounter pools by node type and floor band.
## MapScene calls `select_encounter(type, floor)` before loading the battle scene
## to populate `current_encounter`.
const ENCOUNTER_POOLS_EARLY = [
	["scrap_rat"],
	["trash_robot"],
	["scrap_rat", "scrap_rat"],
	["wasteland_killer"],
]
const ENCOUNTER_POOLS_MID = [
	["riot_hound"],
	["rust_brute"],
	["trash_robot", "scrap_rat"],
	["mortar_cart"],
	["wasteland_killer", "scrap_rat"],
	["slag_walker"],
	["acid_spitter", "scrap_rat"],
]
const ENCOUNTER_POOLS_LATE = [
	["riot_hound", "riot_hound"],
	["rust_brute", "scrap_rat"],
	["mortar_cart", "scrap_rat"],
	["rust_brute", "riot_hound"],
	["chrome_hound"],
	["chrome_hound", "scrap_rat"],
	["slag_walker", "acid_spitter"],
]
const ELITE_ROSTER: Array = ["armored_patrol"]
## Boss per "act". Maps the boss floor index → enemy id. Final-floor boss
## stays junkyard_tyrant; mid-act bosses use placeholder sprites (rust_brute
## and armored_patrol re-skins) until codex generates dedicated art.
##
## Single source of truth for boss floors. `is_boss_floor()` and
## `select_encounter()` both read from this; map_gen forces single-node
## generation for any floor in this dict's keys. To add a mid-boss, add
## the entry here only.
const BOSS_BY_FLOOR: Dictionary = {
	4: "rust_titan",
	8: "ash_warden",
	11: "junkyard_tyrant",
}
## Legacy alias — some pre-multi-boss code paths still read BOSS_ROSTER.
## Returns the final boss only; intermediate bosses use BOSS_BY_FLOOR lookup.
const BOSS_ROSTER: Array = ["junkyard_tyrant"]


## True when a floor index is one of the designed boss floors.
func is_boss_floor(floor_idx: int) -> bool:
	return BOSS_BY_FLOOR.has(floor_idx)


const BATTLE_SCENE: String = "res://battle_scene/battle_scene.tscn"
const MAP_SCENE: String = "res://run_system/ui/map_scene.tscn"
const RELIC_DATA_DIR: String = "res://run_system/data/relics/"
const EQUIPMENT_DATA_DIR: String = "res://run_system/data/equipment/"
const EQUIPMENT_SET_DATA_DIR: String = "res://run_system/data/equipment_sets/"
const FIRST_MERCHANT_FLOOR_INDEX: int = 5  # Human-facing layer 6.
const GUARANTEED_TREASURE_FLOOR_INDEX: int = 6  # Human-facing layer 7.
## Floors 1..EARLY_FLOOR_LAST roll combat-only (no rest / treasure / merchant).
const EARLY_FLOOR_LAST: int = 4
## At most this many treasures spawn outside the guaranteed floor-6 chest.
const MAX_EXTRA_TREASURES: int = 2
## Map fan-out cap — each node connects to at most this many child nodes
## on the next floor. Keeps the route readable and matches the STS shape.
const MAX_CHILDREN_PER_NODE: int = 3

# --- Map State ---
## Each entry: { "id": String, "floor": int, "slot": int, "type": String, "children": Array[String] }
var map_data: Array = []
var current_node_id: String = ""  ## "" means player hasn't chosen a floor-0 node yet
## IDs of nodes the player has actually entered, in walk order. Used by
## map_renderer to highlight the walked path (vs. nodes merely "below current floor").
var visited_node_ids: Array[String] = []
var _node_index: Dictionary = {}

const DATA_VALIDATOR = preload("res://battle_scene/data_validator.gd")


func _ready() -> void:
	# Load-time schema check for all card / enemy / relic JSON. Fails loud in
	# debug builds so typos surface at startup instead of in playtest.
	var failures = DATA_VALIDATOR.validate_all_data_at_startup()
	assert(
		failures == 0, "DataValidator: %d JSON schema failure(s) — see editor output." % failures
	)


# --- Map Generation ---


## Generates a procedural map with the given number of rows and max width.
## Rules:
##   Floor 0       → 1 node: "relic" (choose starting relic)
##   Floor N-1     → 1 node: "boss"
##   Floor N-2     → all nodes are "rest" (pre-boss campfire)
##   Middle floors → 3-5 random nodes
##   Floor 6       -> all nodes are "treasure" (human-facing layer 7)
##   Merchants     -> only appear from floor 4 onward (human-facing layer 5+)
func generate_map(num_floors: int = 12, width: int = 4) -> void:
	map_data.clear()
	_node_index.clear()
	current_node_id = ""
	visited_node_ids.clear()

	for f in range(num_floors):
		# Determine how many nodes on this floor
		var num_nodes: int
		if f == 0 or f == num_floors - 1 or is_boss_floor(f):
			num_nodes = 1  # Start (relic), mid-act bosses, and end (final boss) are single nodes
		else:
			num_nodes = randi_range(2, 4)
			num_nodes = mini(num_nodes, width)  # Can't exceed +---available slots
			# Floors directly adjacent to a single-node floor must fit within
			# the MAX_CHILDREN_PER_NODE cap of that single node, otherwise the
			# orphan-fallback at _attach_orphan_to_under_cap_parent silently
			# blows past the cap. Floor 1 sits below the start (relic),
			# floor N-2 sits above the pre-boss-rest, and any floor sitting
			# directly above a mid-boss does too.
			if f == 1 or is_boss_floor(f - 1):
				num_nodes = mini(num_nodes, MAX_CHILDREN_PER_NODE)

		# Pick unique random slots — single nodes always go in the center
		var slots: Array[int] = []
		if num_nodes == 1:
			@warning_ignore("integer_division")
			slots.append(width / 2)
		else:
			var available: Array[int] = []
			for s in range(width):
				available.append(s)
			available.shuffle()
			for i in range(num_nodes):
				slots.append(available[i])
			slots.sort()

		# Assign node types — track treasure count across the whole run so we
		# can enforce MAX_EXTRA_TREASURES.
		for slot in slots:
			var node_type = _pick_node_type(f, num_floors, _count_extra_treasures())
			var node = {
				"id": "f%d_s%d" % [f, slot],
				"floor": f,
				"slot": slot,
				"type": node_type,
				"children": [] as Array[String]
			}
			map_data.append(node)

	# Connect nodes floor by floor — every node has at most MAX_CHILDREN_PER_NODE
	# outgoing edges (fan-out cap). Convergence (many parents per child) is fine.
	for f in range(num_floors - 1):
		var current_nodes = _get_nodes_on_floor(f)
		var next_nodes = _get_nodes_on_floor(f + 1)

		# Single-node current → next floor: connect to up to MAX closest by slot.
		# (floor-1 was already width-capped above so this should reach every node.)
		if current_nodes.size() == 1:
			for nn in _closest_n_by_slot(next_nodes, current_nodes[0].slot, MAX_CHILDREN_PER_NODE):
				current_nodes[0].children.append(nn.id)
			continue

		# Single-node next: all current nodes converge on it (fan-IN, no cap).
		if next_nodes.size() == 1:
			for cn in current_nodes:
				cn.children.append(next_nodes[0].id)
			continue

		# Normal: each current node gets up to MAX closest within ±2 slot distance.
		var fresh_children: Array[String] = []
		for node in current_nodes:
			fresh_children = []
			for nn in _closest_n_by_slot_within(next_nodes, node.slot, MAX_CHILDREN_PER_NODE, 2):
				fresh_children.append(nn.id)
			# Fallback: distance cap rejected everyone — take single closest.
			if fresh_children.is_empty():
				var closest = _closest_n_by_slot(next_nodes, node.slot, 1)
				if closest.size() > 0:
					fresh_children.append(closest[0].id)
			node.children = fresh_children

		# Ensure every next-floor node has at least one parent. Prefer a parent
		# that's still under the fan-out cap so we don't break it.
		for next_node in next_nodes:
			var has_parent = false
			for node in current_nodes:
				if next_node.id in node.children:
					has_parent = true
					break
			if has_parent:
				continue
			_attach_orphan_to_under_cap_parent(next_node, current_nodes)

	for node in map_data:
		_node_index[node.id] = node


## Returns up to `count` nodes from `candidates`, ordered by slot distance to
## `origin_slot` (closest first).
static func _closest_n_by_slot(candidates: Array, origin_slot: int, count: int) -> Array:
	var with_dist: Array = []
	for c in candidates:
		with_dist.append({"node": c, "dist": abs(int(c.slot) - origin_slot)})
	with_dist.sort_custom(func(a, b): return a.dist < b.dist)
	var out: Array = []
	var take = mini(count, with_dist.size())
	for i in range(take):
		out.append(with_dist[i].node)
	return out


## Same as _closest_n_by_slot but additionally requires slot distance <= max_dist.
static func _closest_n_by_slot_within(
	candidates: Array, origin_slot: int, count: int, max_dist: int
) -> Array:
	var with_dist: Array = []
	for c in candidates:
		var d = abs(int(c.slot) - origin_slot)
		if d <= max_dist:
			with_dist.append({"node": c, "dist": d})
	with_dist.sort_custom(func(a, b): return a.dist < b.dist)
	var out: Array = []
	var take = mini(count, with_dist.size())
	for i in range(take):
		out.append(with_dist[i].node)
	return out


## Attach an orphan child to the closest parent that still has room under the
## fan-out cap. Falls back to closest parent overall if all are at cap (rare).
static func _attach_orphan_to_under_cap_parent(orphan: Dictionary, current_nodes: Array) -> void:
	var sorted: Array = current_nodes.duplicate()
	sorted.sort_custom(
		func(a, b): return abs(int(a.slot) - int(orphan.slot)) < abs(int(b.slot) - int(orphan.slot))
	)
	for parent in sorted:
		if parent.children.size() < MAX_CHILDREN_PER_NODE:
			parent.children.append(orphan.id)
			return
	# All at cap — rare; allow the closest to exceed cap so no orphan exists.
	if sorted.size() > 0:
		sorted[0].children.append(orphan.id)


func _pick_node_type(floor_idx: int, total: int, treasure_extras_used: int = 0) -> String:
	# Floor 0: starting relic choice
	if floor_idx == 0:
		return "relic"
	# Last floor: final boss fight
	if floor_idx == total - 1:
		return "boss"
	# Mid-act boss floors: force a single boss node so the route narrows
	# (the slots-assignment code above already gives floors with one node
	# the center slot — we just declare the type here).
	if is_boss_floor(floor_idx):
		return "boss"
	# Pre-boss floor: always rest (campfire before the boss)
	if floor_idx == total - 2:
		return "rest"
	# Human-facing layer 7: guaranteed relic chest layer.
	if floor_idx == GUARANTEED_TREASURE_FLOOR_INDEX:
		return "treasure"

	var roll = randf()

	# Ascension A5+: bias mid/late rolls into the high (elite/treasure)
	# tail by compressing the roll range. Squashes 0..1 into 0.5..1.0,
	# pushing most rolls past the elite threshold in the mid/late table.
	if ascension >= 5:
		roll = roll * 0.5 + 0.5

	# Early floors (1..EARLY_FLOOR_LAST): combat-only — no rest, no treasure,
	# no merchant. Player gets ramped up on encounters before resources/shops
	# come online.
	if floor_idx <= EARLY_FLOOR_LAST:
		if roll < 0.65:
			return "enemy"
		if roll < 0.85:
			return "unknown"
		return "elite"

	# Mid/late floors: full pool with reduced treasure rate + global treasure cap.
	if roll < 0.40:
		return "enemy"
	if roll < 0.55:
		return "unknown"
	if roll < 0.70:  # merchant always available here (floor >= EARLY_FLOOR_LAST + 1)
		return "merchant"
	if roll < 0.88:  # widened rest band (formerly 0.55-0.82 = 27%, now 0.70-0.88 = 18%)
		return "rest"
	# Treasure: ~5% nominal AND gated by MAX_EXTRA_TREASURES so a run never
	# rolls more than guaranteed-floor-6 + N extras.
	if roll < 0.93 and treasure_extras_used < MAX_EXTRA_TREASURES:
		return "treasure"
	return "elite"


## Counts treasure nodes generated so far that are NOT on the guaranteed
## treasure floor — used to enforce MAX_EXTRA_TREASURES during generation.
func _count_extra_treasures() -> int:
	var count = 0
	for node in map_data:
		if node.type == "treasure" and node.floor != GUARANTEED_TREASURE_FLOOR_INDEX:
			count += 1
	return count


func _get_nodes_on_floor(f: int) -> Array:
	var result: Array = []
	for node in map_data:
		if node.floor == f:
			result.append(node)
	return result


func get_node_by_id(id: String) -> Dictionary:
	return _node_index.get(id, {})


# --- Encounter Selection ---


## Picks an enemy roster based on node type and floor index.
## Called by MapScene before transitioning to the battle scene.
func select_encounter(node_type: String, floor_idx: int) -> Array[String]:
	var result: Array[String] = []
	match node_type:
		"boss":
			# Per-floor boss table. Falls back to BOSS_ROSTER if floor isn't
			# in the table (lets future-added boss floors degrade gracefully).
			if BOSS_BY_FLOOR.has(floor_idx):
				result.append(str(BOSS_BY_FLOOR[floor_idx]))
			else:
				for id in BOSS_ROSTER:
					result.append(str(id))
		"elite":
			for id in ELITE_ROSTER:
				result.append(str(id))
		"enemy", "unknown":
			var pool: Array
			if floor_idx <= 3:
				pool = ENCOUNTER_POOLS_EARLY
			elif floor_idx <= 7:
				pool = ENCOUNTER_POOLS_MID
			else:
				pool = ENCOUNTER_POOLS_LATE
			var pick = pool[randi() % pool.size()]
			for id in pick:
				result.append(str(id))
		_:
			result.append("trash_robot")
	if result.is_empty():
		result.append("trash_robot")
	return result


# --- Run Initialization ---


func get_default_starter_deck() -> Array[String]:
	var deck: Array[String] = []
	for card_id in DEFAULT_STARTER_DECK:
		deck.append(card_id)
	return deck


## Called after hero selection to begin a new run.
func start_new_run(hero_id: String, starter_deck: Array[String] = [], asc: int = 0) -> void:
	current_hero_id = hero_id
	current_hero_data = _load_hero_def(hero_id)
	ascension = clampi(asc, 0, 5)

	player_deck.clear()
	# Prefer the hero's starter deck if present; fall back to the explicit
	# argument; fall back to DEFAULT_STARTER_DECK if neither given.
	var deck_to_use: Array = starter_deck
	if current_hero_data.has("starter_deck") and current_hero_data["starter_deck"] is Array:
		deck_to_use = current_hero_data["starter_deck"]
	if deck_to_use.is_empty():
		deck_to_use = DEFAULT_STARTER_DECK
	for card_id in deck_to_use:
		add_card_to_deck(str(card_id))

	# Reset resources and health (hero max_health overrides default 50).
	gold = 0
	core = 0
	current_floor = 0
	max_health = int(current_hero_data.get("max_health", 50))
	current_health = max_health
	for slot in EQUIPMENT_SLOTS:
		equipped_items[slot] = ""
	inventory_items.clear()
	relics.clear()
	current_encounter = ["trash_robot"]
	last_battle_node_type = "enemy"
	generate_map(12, 4)

	# Base attributes: hero JSON's starting_attributes overrides the default.
	var attrs: Dictionary = current_hero_data.get("starting_attributes", {})
	base_attributes = {
		"strength": int(attrs.get("strength", 3)),
		"constitution": int(attrs.get("constitution", 3)),
		"intelligence": int(attrs.get("intelligence", 3)),
		"luck": int(attrs.get("luck", 3)),
		"charm": int(attrs.get("charm", 3)),
	}
	player_attributes = base_attributes.duplicate()
	is_run_active = true
	_apply_meta_upgrades()
	_emit_all_state()


# --- Deck Management ---


func add_card_to_deck(card_id: String) -> void:
	var uid = str(Time.get_ticks_usec()) + "_" + str(randi_range(1000, 9999))
	var card_data = {"uid": uid, "card_id": card_id}
	player_deck.append(card_data)
	emit_signal("deck_updated")


## Returns true if the card was successfully removed
func remove_card_from_deck_by_uid(uid: String) -> bool:
	for i in range(player_deck.size()):
		if player_deck[i]["uid"] == uid:
			player_deck.remove_at(i)
			emit_signal("deck_updated")
			return true
	return false


# --- Shop purchases (gold-gated wrappers) -----------------------------------


## Spend gold to add a card to the deck. Returns false on insufficient gold.
func purchase_card(card_id: String, cost: int) -> bool:
	if gold < cost or card_id == "":
		return false
	add_resources(-cost, 0)
	add_card_to_deck(card_id)
	return true


## Spend gold to add equipment to inventory. Returns false on insufficient
## gold OR inventory full (caller should show inventory-full UI if relevant).
func purchase_equipment(item_id: String, cost: int) -> bool:
	if gold < cost or item_id == "":
		return false
	if inventory_items.size() >= MAX_INVENTORY:
		return false  # caller handles UI; we don't auto-overflow paid purchases
	add_resources(-cost, 0)
	add_to_inventory(item_id)
	return true


## Spend gold to add a relic. Returns false on insufficient gold or duplicate.
func purchase_relic(relic_id: String, cost: int) -> bool:
	if gold < cost or relic_id == "":
		return false
	if relic_id in relics:
		return false  # already owned
	add_resources(-cost, 0)
	add_relic(relic_id)
	return true


## Spend gold to remove a card from the deck. Returns false on insufficient
## gold or unknown uid.
func purchase_card_removal(uid: String, cost: int) -> bool:
	if gold < cost or uid == "":
		return false
	if not remove_card_from_deck_by_uid(uid):
		return false
	add_resources(-cost, 0)
	return true


## Upgrade the deck entry matching uid: swap card_id from "X" to "X_plus".
## Returns false if uid not found, already upgraded, or no _plus JSON exists.
## Card upgrade is one-shot per card within a run.
func upgrade_card_by_uid(uid: String) -> bool:
	for i in range(player_deck.size()):
		if player_deck[i]["uid"] != uid:
			continue
		var current_id: String = str(player_deck[i]["card_id"])
		if current_id.ends_with("_plus"):
			return false
		var upgraded_id := current_id + "_plus"
		# Defensive: confirm a _plus variant file exists before swapping
		var path := "res://battle_scene/card_info/player/" + upgraded_id + ".json"
		if not FileAccess.file_exists(path):
			push_warning("upgrade_card_by_uid: no _plus variant for '%s'" % current_id)
			return false
		player_deck[i]["card_id"] = upgraded_id
		emit_signal("deck_updated")
		return true
	return false


# --- Health & Damage ---


func modify_health(amount: int) -> void:
	current_health += amount
	current_health = clampi(current_health, 0, max_health)
	emit_signal("health_changed", current_health, max_health)

	if current_health <= 0 and is_run_active:
		_handle_run_loss()


func set_max_health(amount: int, heal_to_full: bool = false) -> void:
	max_health = amount
	if heal_to_full:
		current_health = max_health
	else:
		current_health = clampi(current_health, 0, max_health)
	emit_signal("health_changed", current_health, max_health)


# --- Resources ---


func add_resources(g: int, c: int) -> void:
	gold = max(0, gold + g)
	core = max(0, core + c)
	emit_signal("resources_changed", gold, core)


# --- Items ---


## Recompute player_attributes = base_attributes + sum of every equipped item's
## bonuses. Idempotent. Emits equipment_changed.
func recompute_attributes() -> void:
	var totals: Dictionary = base_attributes.duplicate()
	for slot in EQUIPMENT_SLOTS:
		var item_id: String = equipped_items.get(slot, "")
		if item_id == "":
			continue
		var data: Dictionary = get_equipment_data(item_id)
		var bonuses: Variant = data.get("bonuses", {})
		if typeof(bonuses) != TYPE_DICTIONARY:
			continue
		for attr in bonuses.keys():
			if attr in totals:
				totals[attr] = int(totals[attr]) + int(bonuses[attr])
	player_attributes = totals
	emit_signal("equipment_changed")


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
	var data: Dictionary = get_equipment_data(item_id)
	if data.is_empty():
		push_error("equip_to_slot: no JSON for item '%s'" % item_id)
		return false
	if str(data.get("slot", "")) != slot:
		push_error(
			(
				"equip_to_slot: item '%s' is slot '%s', cannot fit into '%s'"
				% [item_id, data.get("slot", ""), slot]
			)
		)
		return false

	var prev: String = equipped_items.get(slot, "")
	var item_already_in_bag := item_id in inventory_items
	if prev != "":
		# Skip the full-bag check when we're swapping with a bag item — that
		# case is a net-zero change to bag size (remove item_id, add prev).
		if not item_already_in_bag and inventory_items.size() >= MAX_INVENTORY:
			return false
		inventory_items.append(prev)

	# Remove item_id from inventory if it was there (equipping from bag is common path)
	var bag_idx = inventory_items.find(item_id)
	if bag_idx >= 0:
		inventory_items.remove_at(bag_idx)

	equipped_items[slot] = item_id
	recompute_attributes()
	return true


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


## Up to one disk read per occupied slot — call only on equip/snapshot events,
## not per frame.
## Returns { set_id: piece_count } over currently equipped items.
## Sets with zero equipped pieces are omitted.
func get_active_set_tiers() -> Dictionary:
	var counts: Dictionary = {}
	for slot in EQUIPMENT_SLOTS:
		var item_id: String = equipped_items.get(slot, "")
		if item_id == "":
			continue
		var data: Dictionary = get_equipment_data(item_id)
		var set_id: String = str(data.get("set_id", ""))
		if set_id == "":
			continue
		counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts


# --- Relics ---


func add_relic(relic_id: String) -> bool:
	if relic_id.is_empty() or relic_id in relics:
		return false
	relics.append(relic_id)
	emit_signal("relics_updated")
	return true


func has_relic(relic_id: String) -> bool:
	return relic_id in relics


func remove_relic(relic_id: String) -> bool:
	var index = relics.find(relic_id)
	if index == -1:
		return false
	relics.remove_at(index)
	emit_signal("relics_updated")
	return true


## Private helper: open dir_path+id+".json", parse and return the Dictionary.
## Returns {} if id is empty, file is missing, or JSON is not a Dictionary.
## Load a hero definition JSON. Returns {} if missing/invalid.
func _load_hero_def(id: String) -> Dictionary:
	var path := "res://run_system/data/heroes/" + id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("RunManager: hero JSON not found at %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Load a base-upgrade definition JSON. Returns {} if missing/invalid.
func _load_upgrade_def(id: String) -> Dictionary:
	var path := "res://run_system/data/base_upgrades/" + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Resolve an upgrade's current-tier effect_value dictionary, or {} if not owned.
func _get_meta_effect_value(upgrade_id: String) -> Dictionary:
	var lvl := MetaProgress.get_upgrade_level(upgrade_id)
	if lvl <= 0:
		return {}
	var def := _load_upgrade_def(upgrade_id)
	if def.is_empty():
		return {}
	var tiers: Array = def.get("tiers", [])
	if lvl > tiers.size():
		return {}
	var tier: Dictionary = tiers[lvl - 1]
	return tier.get("effect_value", {})


func _load_json_by_id(dir_path: String, id: String) -> Dictionary:
	if id == "":
		return {}
	var file = FileAccess.open(dir_path + id + ".json", FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Returns a default-populated dict for relic_id, with any JSON fields merged in.
func get_relic_data(relic_id: String) -> Dictionary:
	var data: Dictionary = {
		"id": relic_id,
		"title": _humanize_id(relic_id),
		"description": "",
		"icon": "",
		"rarity": "common",
		"effects": [],
	}
	var parsed: Dictionary = _load_json_by_id(RELIC_DATA_DIR, relic_id)
	for key in parsed.keys():
		data[key] = parsed[key]
	return data


## Load equipment JSON by id. Returns empty dict on miss.
func get_equipment_data(item_id: String) -> Dictionary:
	return _load_json_by_id(EQUIPMENT_DATA_DIR, item_id)


## Load equipment set JSON by id. Returns empty dict on miss.
func get_equipment_set_data(set_id: String) -> Dictionary:
	return _load_json_by_id(EQUIPMENT_SET_DATA_DIR, set_id)


## Returns a random equipment id matching the given rarity. Returns "" if none.
## rarity: "common" | "uncommon" | "rare"
func roll_equipment_drop(rarity: String) -> String:
	var dir = DirAccess.open(EQUIPMENT_DATA_DIR)
	if dir == null:
		return ""
	var candidates: Array[String] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var item_id = file_name.get_basename()
		var data = get_equipment_data(item_id)
		if str(data.get("rarity", "")) == rarity:
			candidates.append(item_id)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]


func get_unowned_relic_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir = DirAccess.open(RELIC_DATA_DIR)
	if not dir:
		return ids

	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var relic_id = file_name.get_basename()
		if not has_relic(relic_id):
			ids.append(relic_id)
	ids.sort()
	return ids


func roll_relic_choices(count: int = 3) -> Array[String]:
	var pool = get_unowned_relic_ids()
	pool.shuffle()
	var choices: Array[String] = []
	for i in range(mini(count, pool.size())):
		choices.append(pool[i])
	return choices


# --- Internal Events ---


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


## Apply all owned meta-progression upgrades to the freshly-reset run state.
## Called at the END of start_new_run (after defaults are set so we can add
## on top of them). Pure additive — never reduces a base value.
func _apply_meta_upgrades() -> void:
	# Ascension A2+: -5 max HP per level. Applied BEFORE Med Bay so the
	# upgrade can partially offset the penalty (intentional — investing
	# in meta unlocks softer ramps).
	if ascension >= 2:
		var penalty: int = (ascension - 1) * 5  # A2=-5, A3=-10, A4=-15, A5=-20
		max_health = max(10, max_health - penalty)
		current_health = max_health

	# Med Bay → +max HP
	var hp := int(_get_meta_effect_value("med_bay").get("hp", 0))
	if hp > 0:
		max_health += hp
		current_health = max_health

	# Command Center → +starting gold
	var bonus_gold := int(_get_meta_effect_value("command_center").get("gold", 0))
	if bonus_gold > 0:
		gold += bonus_gold

	# Arsenal → starter inventory items
	var arsenal := _get_meta_effect_value("arsenal")
	if not arsenal.is_empty():
		var commons := int(arsenal.get("commons", 0))
		var uncommons := int(arsenal.get("uncommons", 0))
		for i in range(commons):
			var item_id := roll_equipment_drop("common")
			if item_id != "":
				add_to_inventory(item_id)
		for i in range(uncommons):
			var item_id := roll_equipment_drop("uncommon")
			if item_id != "":
				add_to_inventory(item_id)
	# Starter Boost → +N random attribute points (each picks a random
	# attribute from STR/CON/INT/LCK/CHA and increments by 1).
	var starter := _get_meta_effect_value("starter_boost")
	if not starter.is_empty():
		var points: int = int(starter.get("points", 0))
		var attr_keys: Array = ["strength", "constitution", "intelligence", "luck", "charm"]
		for i in range(points):
			var pick: String = attr_keys[randi() % attr_keys.size()]
			base_attributes[pick] = int(base_attributes.get(pick, 3)) + 1
		# Recompute derived stats after attribute mutation.
		player_attributes = base_attributes.duplicate()

	# (loot_rarity_bias + shop_discount are read on-demand by loot_reward / shop_scene;
	# nothing to apply here.)


func _handle_run_loss(core_earned: int = 0) -> void:
	_teardown_run(false, "defeat", core_earned)
	# TODO: Trigger base-building retention logic (e.g. keep 30% of Core)
	print("Player Hero defeated! Run ended.")


## Mark the run as ended cleanly. `core_earned` is the Core grant for
## THIS run (e.g. 150 for final boss, 50 for extract). `outcome` is
## "victory" for final boss kill, "extracted" for mid-act extract.
## Idempotent — calling twice is a no-op the second time.
func end_run_victory(core_earned: int = 0, outcome: String = "victory") -> void:
	_teardown_run(true, outcome, core_earned)


## Shared run-teardown. Builds the summary dict, flips is_run_active false,
## emits run_ended(victory, summary). Both win and loss paths funnel here
## so future bookkeeping added once applies to both outcomes. Idempotent.
func _teardown_run(victory: bool, outcome: String, core_earned: int) -> void:
	if not is_run_active:
		return
	is_run_active = false
	var summary := {
		"hero_id": current_hero_id,
		"floor": current_floor,
		"core_earned": core_earned,
		"outcome": outcome,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	emit_signal("run_ended", victory, summary)


func _emit_all_state() -> void:
	emit_signal("health_changed", current_health, max_health)
	emit_signal("resources_changed", gold, core)
	emit_signal("deck_updated")
	emit_signal("items_updated")
	emit_signal("relics_updated")


## Debug tool testing
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F9:
				print("--- DEBUG: RUN MANAGER STATE ---")
				print("Deck Size: ", player_deck.size())
				print("Deck Contents: ", player_deck)
				print("Health: ", current_health, "/", max_health)
				print("Resources - Gold: ", gold, " Core: ", core)
				print("Items: ", equipped_items, " Inventory: ", inventory_items)
				print("Relics: ", relics)
			KEY_F10:
				print("DEBUG: +100 Gold")
				add_resources(100, 0)
			KEY_F11:
				print("DEBUG: Take 5 Damage")
				modify_health(-5)
			KEY_F12:
				print("DEBUG: +test_relic")
				add_relic("test_relic")
