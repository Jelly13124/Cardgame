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
##   { hero_id: String, floor: int, act: int, core_earned: int,
##     outcome: String, timestamp: int (unix seconds) }
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
## Gold is derived from the backpack now. Read-only computed property kept for
## compatibility (UI reads RunManager.gold); mutate via add_gold()/spend_gold().
var gold: int:
	get:
		return total_gold()
	set(_v):
		push_warning("RunManager.gold is read-only — use add_gold()/spend_gold()")
## Vestigial in-run core counter (kept for add_resources compat). Run-core that
## matters now lives in the backpack as core stacks; see total_run_core().
var core: int = 0

# Progression
var current_floor: int = 0
## Which act (大层) the player is on, 1..ACTS_TOTAL. Each act is its own
## FLOORS_PER_ACT-tall map ending in a single boss. Reset to 1 by start_new_run,
## bumped by advance_act() after a mid-act extract "push on".
var current_act: int = 1
var player_deck: Array = []  # Array of Dictionaries (uid, card_id, bonus_attack, bonus_health)

## Equipped gear, one slot per body part. Each value is an equipment INSTANCE
## dict (see as_equip_instance) or {} when the slot is empty. Legacy saves may
## still hold a plain item_id String here — every READ routes through
## as_equip_instance() so old strings convert on access (and re-save as
## instances on the next mutation). See migration note on as_equip_instance.
var equipped_items: Dictionary = {
	"head": {},
	"chest": {},
	"weapon": {},
	"hands": {},
	"accessory": {},
}

## Backpack — the definitive store for unequipped loot. Fixed length
## MAX_INVENTORY. Each cell is one of:
##   null | {"kind":"equip","item":<instance>} | {"kind":"gold","amount":int} | {"kind":"core","amount":int}
## Equip cells now carry a full instance dict under "item"; the legacy
## {"kind":"equip","id":String} form is still READ (converted via
## as_equip_instance) for back-compat. Gold / Core / equipment share these cells.
var backpack: Array = []
signal backpack_changed
const GOLD_PER_CELL := 100
const CORE_PER_CELL := 30

## ── Caps (瓶盖) earning — Phase E2 ──────────────────────────────────────────
## Caps mirror Core's banking semantics: they accrue into a run-scoped counter
## during the run and are banked to MetaProgress ONLY on extract / full victory
## (see _settle_backpack). A death banks nothing — unbanked caps are lost, the
## same rule Core follows for everything outside the safe cells.
## Tunables (grouped for easy balance):
const CAPS_PER_COMBAT := 6  # normal (non-elite, non-boss) combat win
const CAPS_PER_ELITE := 18  # elite win
const CAPS_PER_BOSS := 45  # boss win (granted alongside BOSS_VICTORY_CORE)
const GOLD_PER_CAP := 10  # extraction: floor(run gold / GOLD_PER_CAP) → caps
## Run-scoped caps accrued so far this run (banked on extract/victory only).
var _run_caps: int = 0
## Equipment queued (from the base stash) to inject into the backpack at the
## next start_new_run. Each entry is an equip instance dict (or a legacy item_id
## String — tolerated via as_equip_instance). Filled by the Phase-3 loadout UI.
var pending_loadout: Array = []

## Compatibility read-only view: the equip item_ids currently in the backpack
## (cell order). Mutate via add_to_inventory/discard_from_inventory/equip_to_slot.
var inventory_items: Array[String]:
	get:
		return backpack_equip_ids()

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
## Cached equipment-affix totals, refreshed by recompute_attributes(). max_hp
## feeds the player's effective max-health (see equipment_max_hp_bonus);
## crit_pct feeds crit_chance().
var _equipment_max_hp_bonus: int = 0
var _equipment_crit_pct_bonus: int = 0

## Cached random-event definitions (loaded from RANDOM_EVENT_DATA_DIR). Each entry
## is the parsed JSON Dictionary. Populated by load_random_events().
var _random_events: Array = []

## Memoized relic JSON by id. Relic data is immutable at runtime, so get_relic_data
## parses each file at most once — the relic effect system reads this per attack hit.
var _relic_data_cache: Dictionary = {}

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
## Acts (大层). Each act is its OWN FLOORS_PER_ACT-tall map ending in a single
## boss at the top floor — there are no mid-map bosses. Clearing a non-final
## act's boss offers an extract choice; clearing the final act's boss wins the
## run. ACT_BOSSES[i] is the boss enemy id for act i+1. To retune, edit here.
const ACTS_TOTAL: int = 3
const ACT_BOSSES: Array[String] = ["rust_titan", "ash_warden", "junkyard_tyrant"]
## Floors per act map (indices 0..FLOORS_PER_ACT-1); the top floor is the boss.
const FLOORS_PER_ACT: int = 12
## Legacy alias — some pre-act code paths still read BOSS_ROSTER as a fallback.
const BOSS_ROSTER: Array = ["junkyard_tyrant"]


## True when a floor index is the boss floor — always the top floor of an act.
func is_boss_floor(floor_idx: int) -> bool:
	return floor_idx == FLOORS_PER_ACT - 1


## The boss enemy id for the act the player is currently on.
func current_act_boss() -> String:
	var idx: int = clampi(current_act - 1, 0, ACT_BOSSES.size() - 1)
	return ACT_BOSSES[idx]


## True when the player is on the final act (its boss wins the run — no extract).
func is_final_act() -> bool:
	return current_act >= ACTS_TOTAL


## Advance to the next act: bump current_act, reset map position, and generate a
## fresh map for the new act. Returns false (no-op) if already on the final act.
func advance_act() -> bool:
	if current_act >= ACTS_TOTAL:
		return false
	current_act += 1
	current_floor = 0
	current_node_id = ""
	visited_node_ids.clear()
	generate_map(FLOORS_PER_ACT, 4)
	return true


## Per-act enemy stat multipliers (index = act-1). Bosses (ids in ACT_BOSSES)
## are exempt — their power is tuned per-boss in sub-project C, not this curve.
const ACT_HP_MULT: Array[float] = [1.0, 1.25, 1.5]
const ACT_DMG_MULT: Array[float] = [1.0, 1.15, 1.30]
## Enemy-pool tier offset per act: act N draws from a tier `(N-1)*offset` floors
## deeper, so act 2 opens at the MID pool and act 3 at the LATE pool.
const ACT_POOL_OFFSET: int = 4


func act_hp_mult() -> float:
	return ACT_HP_MULT[clampi(current_act - 1, 0, ACT_HP_MULT.size() - 1)]


func act_dmg_mult() -> float:
	return ACT_DMG_MULT[clampi(current_act - 1, 0, ACT_DMG_MULT.size() - 1)]


## Scale a non-boss enemy's base HP by the current act multiplier. Bosses pass
## through unchanged. Stacks multiplicatively with ascension scaling, which is
## applied separately at the enemy_entity spawn site.
func scale_enemy_hp(base_hp: int, enemy_id: String) -> int:
	if enemy_id in ACT_BOSSES:
		return base_hp
	return int(round(base_hp * act_hp_mult()))


## Scale a non-boss enemy's outgoing attack damage by the current act
## multiplier. Bosses pass through unchanged.
func scale_enemy_damage(amount: int, enemy_id: String) -> int:
	if enemy_id in ACT_BOSSES:
		return amount
	return int(round(amount * act_dmg_mult()))


const BATTLE_SCENE: String = "res://battle_scene/battle_scene.tscn"
const MAP_SCENE: String = "res://run_system/ui/map_scene.tscn"
const RELIC_DATA_DIR: String = "res://run_system/data/relics/"
const EQUIPMENT_DATA_DIR: String = "res://run_system/data/equipment/"
const EQUIPMENT_SET_DATA_DIR: String = "res://run_system/data/equipment_sets/"
const RANDOM_EVENT_DATA_DIR: String = "res://run_system/data/random_events/"
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
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")


func _ready() -> void:
	# Load-time schema check for all card / enemy / relic JSON. Fails loud in
	# debug builds so typos surface at startup instead of in playtest.
	var failures = DATA_VALIDATOR.validate_all_data_at_startup()
	assert(
		failures == 0, "DataValidator: %d JSON schema failure(s) — see editor output." % failures
	)
	load_random_events()
	_ensure_backpack()


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
			# Boss is the current act's boss (floor_idx is always the top floor).
			result.append(current_act_boss())
		"elite":
			for id in ELITE_ROSTER:
				result.append(str(id))
		"enemy", "unknown":
			var pool: Array
			var tier_floor: int = floor_idx + (current_act - 1) * ACT_POOL_OFFSET
			if tier_floor <= 3:
				pool = ENCOUNTER_POOLS_EARLY
			elif tier_floor <= 7:
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
	# gold is derived from the backpack — clearing the backpack zeroes it.
	core = 0
	_run_caps = 0
	current_floor = 0
	current_act = 1
	max_health = int(current_hero_data.get("max_health", 50))
	current_health = max_health
	for slot in EQUIPMENT_SLOTS:
		equipped_items[slot] = {}
	# No gear equipped yet → no equipment max_hp/crit bonus carried into the run.
	# Reset the cache so recompute_attributes' delta math starts from a clean base.
	_equipment_max_hp_bonus = 0
	_equipment_crit_pct_bonus = 0
	_ensure_backpack()
	for i in range(MAX_INVENTORY):
		backpack[i] = null
	# Inject the pending loadout (selected from the base stash) into the backpack,
	# removing each taken entry from the permanent stash so it isn't duplicated.
	# Entries are instances (or legacy strings, tolerated by add_equip_to_backpack).
	for entry in pending_loadout:
		if add_equip_to_backpack(entry):
			MetaProgress.remove_from_stash(entry)
	pending_loadout.clear()
	relics.clear()
	var starting_relic: String = str(current_hero_data.get("starting_relic", ""))
	if starting_relic != "":
		add_relic(starting_relic)
	current_encounter = ["trash_robot"]
	last_battle_node_type = "enemy"
	generate_map(FLOORS_PER_ACT, 4)

	# Base attributes: hero JSON's starting_attributes overrides the default.
	var attrs: Dictionary = current_hero_data.get("starting_attributes", {})
	base_attributes = {
		"strength": int(attrs.get("strength", 3)),
		"constitution": int(attrs.get("constitution", 3)),
		"intelligence": int(attrs.get("intelligence", 3)),
		"luck": int(attrs.get("luck", 3)),
		"charm": int(attrs.get("charm", 3)),
	}
	# Cyber Doctor caps perks → permanent +1 per level to the mapped attribute.
	# Applied after the hero's starting_attributes baseline, before recompute.
	for perk_id in MetaProgress.CYBER_DOC_PERKS:
		var attr := str(MetaProgress.CYBER_DOC_PERKS[perk_id])
		var lvl := MetaProgress.get_caps_perk_level(perk_id)
		if lvl > 0 and attr in base_attributes:
			base_attributes[attr] = int(base_attributes[attr]) + lvl
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
	# Gold now lives in the backpack; route through add_gold/spend_gold.
	if g > 0:
		add_gold(g)
	elif g < 0:
		spend_gold(-g)
	core = max(0, core + c)
	emit_signal("resources_changed", total_gold(), core)


# --- Backpack (cell model) -------------------------------------------------


func _ensure_backpack() -> void:
	if backpack.size() != MAX_INVENTORY:
		backpack.resize(MAX_INVENTORY)  # new slots are null-filled


func _first_null_cell() -> int:
	for i in range(MAX_INVENTORY):
		if backpack[i] == null:
			return i
	return -1


func free_cells() -> int:
	var n := 0
	for c in backpack:
		if c == null:
			n += 1
	return n


func backpack_count_used() -> int:
	return MAX_INVENTORY - free_cells()


## Base item_ids of every equip cell (cell order). Tolerant of both the new
## instance form and the legacy {"id":String} cell form.
func backpack_equip_ids() -> Array[String]:
	var out: Array[String] = []
	for c in backpack:
		var inst := _cell_equip_instance(c)
		if not inst.is_empty():
			out.append(equip_base(inst))
	return out


## Every equip cell's instance dict (in backpack cell order). Tolerant of legacy
## string cells (converted on read).
func backpack_equip_instances() -> Array:
	var out: Array = []
	for c in backpack:
		var inst := _cell_equip_instance(c)
		if not inst.is_empty():
			out.append(inst)
	return out


## First cell index holding an equip whose BASE item_id matches. -1 if none.
func _find_equip_cell(item_id: String) -> int:
	for i in range(MAX_INVENTORY):
		var inst := _cell_equip_instance(backpack[i])
		if not inst.is_empty() and equip_base(inst) == item_id:
			return i
	return -1


func total_gold() -> int:
	var t := 0
	for c in backpack:
		if c != null and c.get("kind") == "gold":
			t += int(c["amount"])
	return t


func total_run_core() -> int:
	var t := 0
	for c in backpack:
		if c != null and c.get("kind") == "core":
			t += int(c["amount"])
	return t


## Add gold to the backpack (fills partial stacks, then opens new cells).
## Returns the amount actually stored (< n if the backpack ran out of room).
func add_gold(n: int) -> int:
	return _add_stacked("gold", n, GOLD_PER_CELL)


## Add run-core to the backpack (≤CORE_PER_CELL per cell). Returns amount stored.
func add_core_to_backpack(n: int) -> int:
	return _add_stacked("core", n, CORE_PER_CELL)


## ── Caps earning helpers (Phase E2) ─────────────────────────────────────────
## Accrue caps into the run-scoped counter. Banked to MetaProgress only at
## extract / victory (see _settle_backpack) — mirrors Core's backpack semantics.
func award_run_caps(n: int) -> void:
	if n <= 0:
		return
	_run_caps += n


## Award caps for a combat win, sized by the battle node type. Called from the
## victory path the same way Core is dropped per fight type, so a boss fight
## grants the boss award only (never boss + normal).
func award_caps_for_combat(node_type: String) -> void:
	match node_type:
		"boss":
			award_run_caps(CAPS_PER_BOSS)
		"elite":
			award_run_caps(CAPS_PER_ELITE)
		_:
			award_run_caps(CAPS_PER_COMBAT)


func _add_stacked(kind: String, n: int, per: int) -> int:
	_ensure_backpack()
	var remaining := n
	for c in backpack:
		if remaining <= 0:
			break
		if c != null and c.get("kind") == kind and int(c["amount"]) < per:
			var room := per - int(c["amount"])
			var put := mini(room, remaining)
			c["amount"] = int(c["amount"]) + put
			remaining -= put
	while remaining > 0:
		var idx := _first_null_cell()
		if idx == -1:
			break
		var put := mini(per, remaining)
		backpack[idx] = {"kind": kind, "amount": put}
		remaining -= put
	if remaining != n:
		emit_signal("backpack_changed")
	return n - remaining


## Spend gold from the backpack, then re-normalize to fewest cells (the result
## of "making change"). Returns false if the player can't afford `cost`.
func spend_gold(cost: int) -> bool:
	if cost <= 0:
		return true
	if total_gold() < cost:
		return false
	var remaining := cost
	for i in range(MAX_INVENTORY):
		if remaining <= 0:
			break
		var c = backpack[i]
		if c != null and c.get("kind") == "gold":
			var take := mini(int(c["amount"]), remaining)
			c["amount"] = int(c["amount"]) - take
			remaining -= take
			if int(c["amount"]) <= 0:
				backpack[i] = null
	_normalize_gold()
	emit_signal("backpack_changed")
	return true


## Compact all gold into the fewest cells.
func _normalize_gold() -> void:
	var g := total_gold()
	for i in range(MAX_INVENTORY):
		if backpack[i] != null and backpack[i].get("kind") == "gold":
			backpack[i] = null
	var idx := 0
	while g > 0 and idx < MAX_INVENTORY:
		if backpack[idx] == null:
			var put := mini(GOLD_PER_CELL, g)
			backpack[idx] = {"kind": "gold", "amount": put}
			g -= put
		idx += 1


## Put an equipment into the first free cell. Accepts either a String item_id
## (built into an instance) or an instance dict (stored as-is). Returns false if
## the backpack is full or the input is empty.
func add_equip_to_backpack(item: Variant) -> bool:
	var inst := as_equip_instance(item)
	if inst.is_empty():
		return false
	_ensure_backpack()
	var idx := _first_null_cell()
	if idx == -1:
		return false
	backpack[idx] = {"kind": "equip", "item": inst}
	emit_signal("backpack_changed")
	return true


## Swap two backpack cells (panel uses this to move an item into/out of a safe
## cell). Safe-cell range is index 0..safe_cells-1.
func move_cell(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or to_idx < 0 or from_idx >= MAX_INVENTORY or to_idx >= MAX_INVENTORY:
		return
	var tmp = backpack[from_idx]
	backpack[from_idx] = backpack[to_idx]
	backpack[to_idx] = tmp
	emit_signal("backpack_changed")


# --- Items ---

# --- Equipment instances (per-instance affixes + back-compat) ---------------
#
# An equipment INSTANCE is a Dictionary:
#   { "base": <item_id>, "rarity": <r>, "affixes": [ {type,value}, .. ],
#     "cursed": bool, "set_id": <id or ""> }
#
# Migration note: there is NO explicit migration pass. Every READ of a stored
# equip (slot value or backpack equip cell) routes through as_equip_instance(),
# so a legacy save holding plain item_id Strings converts those strings to
# instances on access (deriving affixes from the item's JSON `bonuses` so its
# exact stats are preserved). The next mutation that writes the slot/cell back
# stores the instance form, so old saves silently upgrade over normal play.


## Central converter: normalize anything stored as "an equipment" into an
## instance dict. Accepts an instance (returned as-is), a legacy item_id String
## (built into an instance with affixes derived from the JSON `bonuses`), or the
## empty/"" / null case (returns {}).
func as_equip_instance(x: Variant) -> Dictionary:
	if typeof(x) == TYPE_DICTIONARY:
		if x.has("base"):
			return x  # already an instance
		return {}
	if typeof(x) == TYPE_STRING:
		var item_id: String = x
		if item_id == "":
			return {}
		var data: Dictionary = get_equipment_data(item_id)
		var affixes: Array = []
		var bonuses: Variant = data.get("bonuses", {})
		if typeof(bonuses) == TYPE_DICTIONARY:
			for attr in bonuses.keys():
				affixes.append({"type": "attr_" + str(attr), "value": int(bonuses[attr])})
		return {
			"base": item_id,
			"rarity": str(data.get("rarity", "common")),
			"affixes": affixes,
			"cursed": false,
			"set_id": str(data.get("set_id", "")),
		}
	return {}


## Build a FRESH rolled equipment instance for a base item_id. Reads slot/set_id
## from the item JSON and rolls real affixes via AFFIX_POOL.roll(rarity, cursed).
## This is the grant path (drops / events / starter inventory) — unlike
## as_equip_instance (which derives affixes from legacy `bonuses` for back-compat),
## here affixes are rolled anew. Returns {} for an empty/unknown base.
func make_equip_instance(base_id: String, rarity: String, cursed: bool = false) -> Dictionary:
	if base_id == "":
		return {}
	var data: Dictionary = get_equipment_data(base_id)
	var resolved_rarity: String = rarity if rarity != "" else str(data.get("rarity", "common"))
	return {
		"base": base_id,
		"rarity": resolved_rarity,
		"affixes": AFFIX_POOL.roll(resolved_rarity, cursed),
		"cursed": cursed,
		"set_id": str(data.get("set_id", "")),
	}


## The base item_id of an equip (instance / String / {}). "" when empty.
func equip_base(inst: Variant) -> String:
	var d := as_equip_instance(inst)
	return str(d.get("base", ""))


## The affix list of an equip (instance / String / {}). [] when empty.
func equip_affixes(inst: Variant) -> Array:
	var d := as_equip_instance(inst)
	var a: Variant = d.get("affixes", [])
	return a if typeof(a) == TYPE_ARRAY else []


## The rarity of an equip (instance / String / {}). "" when empty.
func equip_rarity(inst: Variant) -> String:
	var d := as_equip_instance(inst)
	return str(d.get("rarity", ""))


## Read the equip instance stored in backpack cell `cell` (tolerant of both the
## new {"kind":"equip","item":<instance>} form and the legacy
## {"kind":"equip","id":<string>} form). Returns {} if not an equip cell.
func _cell_equip_instance(cell: Variant) -> Dictionary:
	if typeof(cell) != TYPE_DICTIONARY or cell.get("kind") != "equip":
		return {}
	return as_equip_instance(cell.get("item", cell.get("id", "")))


## Recompute player_attributes = base_attributes + the summed attribute affixes
## of every equipped instance. Idempotent (rebuilds from base_attributes each
## call). Also refreshes the cached equipment max_hp / crit_pct bonuses. Emits
## equipment_changed.
func recompute_attributes() -> void:
	var totals: Dictionary = base_attributes.duplicate()
	var max_hp_bonus := 0
	var crit_pct_bonus := 0
	for slot in EQUIPMENT_SLOTS:
		var inst := as_equip_instance(equipped_items.get(slot, {}))
		if inst.is_empty():
			continue
		var t: Dictionary = AFFIX_POOL.attribute_totals(equip_affixes(inst))
		for attr in ["strength", "constitution", "intelligence", "luck", "charm"]:
			if attr in totals:
				totals[attr] = int(totals[attr]) + int(t.get(attr, 0))
		max_hp_bonus += int(t.get("max_hp", 0))
		crit_pct_bonus += int(t.get("crit_pct", 0))
	player_attributes = totals
	_equipment_crit_pct_bonus = crit_pct_bonus
	# Apply the change in equipment max_hp to the live max-health pool. We track
	# the previously-applied bonus and adjust by the DELTA so recompute is
	# idempotent (re-running with the same gear is a no-op) and stacks correctly
	# on top of base/meta max_health. current_health rises with a positive delta
	# (free heal for new +HP gear) and is clamped down on a negative delta.
	var delta := max_hp_bonus - _equipment_max_hp_bonus
	_equipment_max_hp_bonus = max_hp_bonus
	if delta != 0:
		max_health = max(1, max_health + delta)
		if delta > 0:
			current_health += delta
		current_health = clampi(current_health, 0, max_health)
		emit_signal("health_changed", current_health, max_health)
	emit_signal("equipment_changed")


# --- Attribute gameplay helpers (luck/charm) ---
# Pure, single-sourced so consumers (crit/loot/gold/shop) stay testable.

const CRIT_PER_LUCK := 0.03
const CRIT_CAP := 0.40
const CRIT_MULT := 1.5
const GOLD_PER_LUCK := 0.03
const RARITY_PER_LUCK := 0.015
const SHOP_PER_CHARM := 0.02
const SHOP_FLOOR := 0.60


func _attr(name: String) -> int:
	return int(player_attributes.get(name, 0))


## Equipment-affix max-HP bonus currently applied to max_health (cached by
## recompute_attributes). Exposed for UI / debugging; the value is already
## folded into max_health.
func equipment_max_hp_bonus() -> int:
	return _equipment_max_hp_bonus


## Equipment-affix crit bonus as a fraction (e.g. +5% crit → 0.05). Summed from
## crit_pct affixes and folded into crit_chance().
func equipment_crit_pct_bonus() -> float:
	return _equipment_crit_pct_bonus / 100.0


func crit_chance() -> float:
	return clampf(_attr("luck") * CRIT_PER_LUCK + equipment_crit_pct_bonus(), 0.0, CRIT_CAP)


func luck_gold_mult() -> float:
	return 1.0 + _attr("luck") * GOLD_PER_LUCK


func luck_rarity_bonus() -> float:
	return _attr("luck") * RARITY_PER_LUCK


func charm_shop_mult() -> float:
	return maxf(SHOP_FLOOR, 1.0 - _attr("charm") * SHOP_PER_CHARM)


## Permanently raise a BASE attribute by `amount` and refresh derived totals.
## Single-sources the "bump a base attribute" idiom (random events + starter_boost).
func grant_attribute(attr: String, amount: int) -> void:
	if attr == "":
		return
	base_attributes[attr] = int(base_attributes.get(attr, 3)) + amount
	recompute_attributes()


# --- Random events (luck/charm driven "?" node) ----------------------------
# Data schema + validator live in data_validator.gd. Effect types are dispatched
# by apply_event_effects() to the matching RunManager mutation.

const EVENT_LUCK_CHECK_BASE := 0.35
const EVENT_LUCK_CHECK_PER_LUCK := 0.04
const EVENT_LUCK_CHECK_CAP := 0.90


## Load (and cache) every random-event JSON from RANDOM_EVENT_DATA_DIR.
## Gracefully no-ops if the directory is missing or empty.
func load_random_events() -> void:
	_random_events = []
	if not DirAccess.dir_exists_absolute(RANDOM_EVENT_DATA_DIR):
		return
	var dir = DirAccess.open(RANDOM_EVENT_DATA_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path: String = RANDOM_EVENT_DATA_DIR + file_name
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var raw := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(raw)
		if typeof(parsed) == TYPE_DICTIONARY:
			_random_events.append(parsed)


## Pick a uniformly random cached event. Returns {} when none are loaded.
func pick_random_event() -> Dictionary:
	if _random_events.is_empty():
		return {}
	return _random_events[randi() % _random_events.size()]


## True if an event option's `requires` (luck/charm) gate is met by current
## attributes. Options with no `requires` are always unlocked.
func option_unlocked(option: Dictionary) -> bool:
	var requires: Variant = option.get("requires", {})
	if typeof(requires) != TYPE_DICTIONARY:
		return true
	for attr in requires.keys():
		if _attr(str(attr)) < int(requires[attr]):
			return false
	return true


## Success probability for a luck_check option. clamp(0.35 + luck*0.04, 0, 0.9).
func luck_check_chance() -> float:
	return clampf(
		EVENT_LUCK_CHECK_BASE + _attr("luck") * EVENT_LUCK_CHECK_PER_LUCK, 0.0, EVENT_LUCK_CHECK_CAP
	)


## Apply each effect in an event option's effects array to the matching
## RunManager mutation. Unknown effect types are ignored (validator gates them).
func apply_event_effects(effects: Array) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var etype := str(effect.get("type", ""))
		match etype:
			"gain_gold":
				add_gold(int(effect.get("amount", 0)))
			"lose_hp":
				modify_health(-int(effect.get("amount", 0)))
			"heal":
				modify_health(int(effect.get("amount", 0)))
			"gain_core":
				add_core_to_backpack(int(effect.get("amount", 0)))
			"gain_relic":
				add_relic(str(effect.get("id", "")))
			"gain_equipment":
				var rarity := str(effect.get("rarity", ""))
				var item_id := roll_equipment_drop(rarity)
				if item_id != "":
					add_equip_to_backpack(make_equip_instance(item_id, rarity))
			"gain_attribute":
				grant_attribute(str(effect.get("attr", "")), int(effect.get("amount", 0)))


## Equip item_id into slot. If slot is occupied, the previous occupant moves
## to inventory. Returns false (no-op) if slot is occupied AND inventory is
## full. Caller must show the inventory-full modal before retrying.
## Calls recompute_attributes() on success.
func equip_to_slot(item: Variant, slot: String) -> bool:
	if not slot in EQUIPMENT_SLOTS:
		push_error("equip_to_slot: unknown slot '%s'" % slot)
		return false
	# `item` may be a base item_id String (the common UI path) or an instance.
	var item_id := equip_base(item)
	if item_id == "":
		push_error("equip_to_slot: item is empty")
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

	var prev := as_equip_instance(equipped_items.get(slot, {}))
	# Prefer the actual instance sitting in the backpack (it carries the rolled
	# affixes); fall back to building one from `item` if it's not in the bag.
	var bag_idx := _find_equip_cell(item_id)
	var to_equip: Dictionary
	if bag_idx >= 0:
		to_equip = _cell_equip_instance(backpack[bag_idx])
	else:
		to_equip = as_equip_instance(item)
	# Equipping from the backpack frees that cell, so swapping with a slot item
	# is net-zero; only a NEW item (not already in the bag) needs a free cell
	# to receive `prev`.
	if not prev.is_empty() and bag_idx == -1 and free_cells() <= 0:
		return false
	if bag_idx >= 0:
		backpack[bag_idx] = null  # take the chosen item out of the bag
	equipped_items[slot] = to_equip
	if not prev.is_empty():
		add_equip_to_backpack(prev)  # space guaranteed (freed bag_idx or checked free_cells)
	emit_signal("backpack_changed")
	recompute_attributes()
	return true


## Move the item in slot back to the backpack. Returns false if the backpack
## is full. Calls recompute_attributes() on success.
func unequip_slot(slot: String) -> bool:
	if not slot in EQUIPMENT_SLOTS:
		push_error("unequip_slot: unknown slot '%s'" % slot)
		return false
	var inst := as_equip_instance(equipped_items.get(slot, {}))
	if inst.is_empty():
		return true  # already empty, treat as success no-op
	if not add_equip_to_backpack(inst):
		return false  # backpack full
	equipped_items[slot] = {}
	recompute_attributes()
	return true


## Add an equipment to the backpack. Accepts a String item_id or an instance.
## Returns false at capacity.
func add_to_inventory(item: Variant) -> bool:
	return add_equip_to_backpack(item)


## Clear backpack cell `index` (only if it holds equipment). NOTE: `index` is a
## backpack CELL index (0..MAX_INVENTORY-1), not a position in the equip list.
## Out-of-range or non-equip cells are a silent no-op.
func discard_from_inventory(index: int) -> void:
	if index < 0 or index >= MAX_INVENTORY:
		return
	var c = backpack[index]
	if c != null and c.get("kind") == "equip":
		backpack[index] = null
		emit_signal("backpack_changed")


## Up to one disk read per occupied slot — call only on equip/snapshot events,
## not per frame.
## Returns { set_id: piece_count } over currently equipped items.
## Sets with zero equipped pieces are omitted.
func get_active_set_tiers() -> Dictionary:
	var counts: Dictionary = {}
	for slot in EQUIPMENT_SLOTS:
		var inst := as_equip_instance(equipped_items.get(slot, {}))
		if inst.is_empty():
			continue
		# Prefer the instance's set_id (rolled per-instance); fall back to the
		# base item's JSON for legacy/derived instances with no set_id.
		var set_id: String = str(inst.get("set_id", ""))
		if set_id == "":
			set_id = str(get_equipment_data(equip_base(inst)).get("set_id", ""))
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
	if _relic_data_cache.has(relic_id):
		return _relic_data_cache[relic_id]
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
	_relic_data_cache[relic_id] = data
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
		if has_relic(relic_id):
			continue
		# "unique" relics are hero-starting only and must never roll as loot/
		# relic-choice. They are not part of the common/uncommon/rare buckets.
		if str(get_relic_data(relic_id).get("rarity", "common")) == "unique":
			continue
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
		add_gold(bonus_gold)

	# Arsenal → starter inventory items
	var arsenal := _get_meta_effect_value("arsenal")
	if not arsenal.is_empty():
		var commons := int(arsenal.get("commons", 0))
		var uncommons := int(arsenal.get("uncommons", 0))
		for i in range(commons):
			var item_id := roll_equipment_drop("common")
			if item_id != "":
				add_to_inventory(make_equip_instance(item_id, "common"))
		for i in range(uncommons):
			var item_id := roll_equipment_drop("uncommon")
			if item_id != "":
				add_to_inventory(make_equip_instance(item_id, "uncommon"))
	# Starter Boost → +N random attribute points (each picks a random
	# attribute from STR/CON/INT/LCK/CHA and increments by 1).
	var starter := _get_meta_effect_value("starter_boost")
	if not starter.is_empty():
		var points: int = int(starter.get("points", 0))
		var attr_keys: Array = ["strength", "constitution", "intelligence", "luck", "charm"]
		for i in range(points):
			var pick: String = attr_keys[randi() % attr_keys.size()]
			grant_attribute(pick, 1)

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
	_settle_backpack(victory, outcome)
	is_run_active = false
	var summary := {
		"hero_id": current_hero_id,
		"floor": current_floor,
		"act": current_act,
		"core_earned": core_earned,
		"outcome": outcome,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	emit_signal("run_ended", victory, summary)


## Settle the backpack at run end.
## Phase 1: extract/victory banks ALL carried run-core into permanent
## MetaProgress.core; death banks nothing. (Phase 2 adds safe-cell survival on
## death; Phase 3 adds the permanent equipment stash.)
func _settle_backpack(victory: bool, outcome: String) -> void:
	if victory or outcome == "extracted":
		# Extract / final victory: ALL carried Core banks, ALL backpack equipment
		# AND all equipped gear are carried out into the permanent stash.
		var carried := total_run_core()
		if carried > 0:
			MetaProgress.add_core(carried)
		# Caps bank alongside Core: accrued per-fight caps + leftover run gold
		# converted at GOLD_PER_CAP (floor). Mirrors Core — banked on extract /
		# victory only; a death (else-branch below) banks no caps.
		var banked_caps := _run_caps + int(total_gold() / GOLD_PER_CAP)
		if banked_caps > 0:
			MetaProgress.add_caps(banked_caps)
		_run_caps = 0
		for c in backpack:
			var inst := _cell_equip_instance(c)
			if not inst.is_empty():
				MetaProgress.add_to_stash(inst)
		for slot in EQUIPMENT_SLOTS:
			var eq := as_equip_instance(equipped_items.get(slot, {}))
			if not eq.is_empty():
				MetaProgress.add_to_stash(eq)
	else:
		# Death: ONLY safe-cell contents (index 0..safe-1) survive — Core banks,
		# equipment goes to the stash. Everything else + all equipped gear is lost.
		var safe := mini(MetaProgress.effective_safe_cells(), MAX_INVENTORY)
		var saved := 0
		for i in range(safe):
			var c = backpack[i]
			if c == null:
				continue
			if c.get("kind") == "core":
				saved += int(c["amount"])
			elif c.get("kind") == "equip":
				MetaProgress.add_to_stash(_cell_equip_instance(c))
		if saved > 0:
			MetaProgress.add_core(saved)


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
