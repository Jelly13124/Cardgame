extends Node

# --- Signals ---
signal health_changed(current: int, maximum: int)
signal resources_changed(gold: int, scrap: int)
signal deck_updated
signal items_updated
signal equipment_changed
signal relics_updated
## Emitted when the run ends, win or lose. `summary` is the run-history
## payload for MetaProgress (and any future listener):
##   { hero_id: String, floor: int, act: int, scrap_earned: int,
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

## Run-scoped INTENT set by base building screens (warehouse hero-select / outpost
## difficulty) before a run starts. NOT persisted — cleared after start_new_run
## consumes them. They are FALLBACKS only: an explicit hero_id / asc passed into
## start_new_run (e.g. from home_base_scene._on_start_pressed) always wins.
## "" / -1 mean "unset".
var pending_hero_id: String = ""
var pending_ascension: int = -1

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
## Vestigial in-run counter (kept for add_resources compat; callers always pass 0).
## Run-scrap that matters lives in the backpack as scrap stacks; see total_run_scrap().
var _run_scrap_counter: int = 0

# Progression
var current_floor: int = 0
## Which act (大层) the player is on, 1..acts_total(). Each act is its own
## FLOORS_PER_ACT-tall map ending in a single boss. Reset to 1 by start_new_run.
## advance_act() is retained for the full-game build; the one-act demo cannot
## advance beyond act 1.
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
##   null | {"kind":"equip","item":<instance>} | {"kind":"gold","amount":int} | {"kind":"scrap","amount":int}
## Equip cells now carry a full instance dict under "item"; the legacy
## {"kind":"equip","id":String} form is still READ (converted via
## as_equip_instance) for back-compat. Gold / Scrap / equipment share these cells.
## (The in-run resource stack was "core" before 2026-07-07; it is now "scrap",
## banking to MetaProgress.scrap on extract/victory.)
var backpack: Array = []
signal backpack_changed
signal tools_changed
const GOLD_PER_CELL := 100
const SCRAP_PER_CELL := 30

## ── Caps (瓶盖) earning — Phase E2 ──────────────────────────────────────────
## Caps accrue into a run-scoped counter during the run and are banked to
## MetaProgress ONLY on extract / full victory (see _settle_backpack). A death
## banks nothing — unbanked caps are lost, the same rule backpack scrap follows
## outside the safe cells.
## Tunables (grouped for easy balance):
const CAPS_PER_COMBAT := 6  # normal (non-elite, non-boss) combat win
const CAPS_PER_ELITE := 18  # elite win
const CAPS_PER_BOSS := 45  # boss win (granted alongside BOSS_VICTORY_SCRAP)
const GOLD_PER_CAP := 10  # extraction: floor(run gold / GOLD_PER_CAP) → caps
const STARTING_GOLD := 99  # baseline purse every run begins with (Command Center stacks on top)
## Run-scoped caps accrued so far this run (banked on extract/victory only).
var _run_caps: int = 0
## Equipment physically owned by the base backpack between runs. Each entry is
## an equip instance dict (or a legacy item_id String, tolerated through
## as_equip_instance). Unlike the old reference model, these entries are NOT
## duplicates/references of MetaProgress.stash: dragging between the two moves
## ownership atomically. MetaProgress persists this array in the active profile.
## start_new_run consumes it into the real run backpack.
var pending_loadout: Array = []

## Equipment physically worn at the base and carried into the next run already
## equipped. Maps slot (one of EQUIPMENT_SLOTS) to an owned instance (or legacy
## String). It is persisted beside pending_loadout and is disjoint from the
## permanent stash; only an explicit drag into StashWindow stores it there.
var pending_equipped: Dictionary = {}

## Compatibility read-only view: the equip item_ids currently in the backpack
## (cell order). Mutate via add_to_inventory/discard_from_inventory/equip_to_slot.
var inventory_items: Array[String]:
	get:
		return backpack_equip_ids()

var relics: Array[String] = []
## Run-scoped one-time tools (StS2-style top-bar consumables). NOT in the backpack.
var tool_inventory: Array[String] = []
var _tool_cache: Dictionary = {}

## In-run XP/level. Killing enemies grants XP; each level-up queues an attribute
## point (consumed by the loot screen via pending_attr_points). Reset in start_new_run.
var xp: int = 0
var level: int = 1
## Unspent attribute points from level-ups (each → a 3-of-5 attribute pick, surfaced
## by the loot screen). Cards come from combat drafts; attributes come from leveling.
var pending_attr_points: int = 0
## Reward-screen card-draft rerolls available this run (default 0). Granted by the
## Reroll Tokens base upgrade; spent in loot_reward; reset each run.
var reward_rerolls: int = 0
const XP_PER_KILL := {"enemy": 6, "elite": 14, "boss": 30}

## Wall-clock tick (msec) when the current run started — drives the top-bar run
## timer (StS-style clock). 0 = no run started this session.
var run_started_msec: int = 0


## XP needed to go from `lvl` to `lvl+1`. Gentle curve → ~1 level per 1-2 fights.
func xp_to_next(lvl: int) -> int:
	# Charm lowers the per-level XP wall (faster leveling): -4%/point, floored at -40%.
	var mult := clampf(1.0 - 0.04 * float(_attr("charm")), 0.60, 1.0)
	return int(round((10 + lvl * 4) * mult))


## Award XP for a combat win by node type; rolls up level-ups and returns how many
## levels were gained (→ that many attribute picks). Intelligence no longer touches
## XP (it scales tools + Short Circuit cards now); Charm lowers the wall via xp_to_next.
func gain_xp(node_type: String) -> int:
	var base: int = int(XP_PER_KILL.get(node_type, XP_PER_KILL["enemy"]))
	xp += base
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	pending_attr_points += gained
	if gained > 0:
		AudioManager.play_sfx("level_up")
	return gained


## Hard ceiling on backpack cells. The backpack ARRAY is always this length (so
## cell/safe-cell indices stay stable across saves); the USABLE cell count is the
## dynamic effective_backpack_size() below, which grows from BASE_BACKPACK toward
## this cap via the Outpost "backpack" upgrade.
const MAX_INVENTORY: int = 20
## Base usable backpack cells with no Outpost backpack upgrade purchased.
const BASE_BACKPACK: int = 10
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
	"strength": 0,
	"constitution": 0,
	"intelligence": 0,
	"luck": 0,
	"charm": 0,
}
var player_attributes: Dictionary = {
	"strength": 0,
	"constitution": 0,
	"intelligence": 0,
	"luck": 0,
	"charm": 0,
}
## Cached equipment-affix totals, refreshed by recompute_attributes(). max_hp
## feeds the player's effective max-health (see equipment_max_hp_bonus);
## crit_pct feeds crit_chance().
var _equipment_max_hp_bonus: int = 0
var _equipment_crit_pct_bonus: int = 0

## Cached random-event definitions (loaded from RANDOM_EVENT_DATA_DIR). Each entry
## is the parsed JSON Dictionary. Populated by load_random_events().
var _random_events: Array = []
## Events already dealt during this run. The one-act demo uses a no-replacement
## event deck so a route cannot repeat the same vignette.
var _seen_random_event_ids: Array[String] = []

## Demo-only set onboarding track. Three milestone combat rewards offer distinct
## pieces from one featured set, ensuring the equipment differentiator becomes
## playable before the boss instead of existing only as a rare random drop.
const DEMO_SET_TRACK_FLOORS: Array[int] = [2, 5, 8]
const DEMO_FEATURED_SET_IDS: Array[String] = ["weak_hunter", "tank_engineer", "warden"]
var demo_featured_set_id: String = ""
var demo_set_piece_ids_claimed: Array[String] = []

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
const ENCOUNTER_POOLS_OPENING = [
	["scrap_rat"],
	["hex_drone"],
	["acid_spitter"],
]
const ENCOUNTER_POOLS_EARLY = [
	["wasteland_killer"],
	["scrap_rat", "scrap_rat"],
	["riot_hound"],
	["mortar_cart"],
	["trash_robot"],
]
const ENCOUNTER_POOLS_MID = [
	["riot_hound"],
	["mortar_cart"],
	["slag_walker"],
	["acid_spitter", "scrap_rat"],
	["wasteland_killer", "scrap_rat"],
	["chrome_hound"],
	["riot_hound_alpha"],
]
const ENCOUNTER_POOLS_LATE = [
	["riot_hound_alpha"],
	["rust_brute"],
	["mortar_cart", "scrap_rat"],
	["chrome_hound", "scrap_rat"],
	["mortar_cart_siege", "scrap_rat"],
	["slag_walker", "acid_spitter"],
	["riot_hound", "riot_hound"],
]
const ELITE_ROSTER: Array = ["armored_patrol", "chrome_warden", "siege_breaker"]
## Acts (大层). Each act is its OWN FLOORS_PER_ACT-tall map ending in a single
## boss at the top floor — there are no mid-map bosses. Clearing a non-final
## act's boss offers an extract choice; clearing the final act's boss wins the
## run. ACT_BOSSES[i] is the boss enemy id for act i+1. To retune, edit here.
const ACTS_TOTAL: int = 3
const ACT_BOSSES: Array[String] = ["rust_titan", "ash_warden", "junkyard_tyrant"]
## Floors per act map (indices 0..FLOORS_PER_ACT-1); the top floor is the boss.
const FLOORS_PER_ACT: int = 12

## ── DEMO BUILD ────────────────────────────────────────────────────────────
## Flip DEMO_BUILD to false to restore the planned 3-act, all-heroes game.
## The public demo is one authored 12-floor act, always ending at Rust Titan.
## acts_total() is the demo-aware cap used by is_final_act()/advance_act();
## DEMO_ALLOWED_HEROES filters the Warehouse hero picker.
const DEMO_BUILD: bool = true
const DEMO_MAX_ACTS: int = 1
const DEMO_BOSS: String = "rust_titan"
const DEMO_ALLOWED_HEROES: Array[String] = ["cowboy_bill"]


## Demo-aware act count. The full game has ACTS_TOTAL acts; the demo caps at one
## act, so its boss victory ends and banks the run without a push-on choice.
func acts_total() -> int:
	return DEMO_MAX_ACTS if DEMO_BUILD else ACTS_TOTAL


## True when a floor index is the boss floor — always the top floor of an act.
func is_boss_floor(floor_idx: int) -> bool:
	return floor_idx == FLOORS_PER_ACT - 1


## The boss enemy id for the act the player is currently on. Demo selection is
## explicit so stale act state can never substitute a later full-game boss.
func current_act_boss() -> String:
	if DEMO_BUILD:
		return DEMO_BOSS
	var idx: int = clampi(current_act - 1, 0, ACT_BOSSES.size() - 1)
	return ACT_BOSSES[idx]


## True when the player is on the final act (its boss wins the run — no extract).
func is_final_act() -> bool:
	return current_act >= acts_total()


## Advance to the next act: bump current_act, reset map position, and generate a
## fresh map for the new act. Returns false (no-op) if already on the final act.
func advance_act() -> bool:
	if current_act >= acts_total():
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

	# Early floors (1..EARLY_FLOOR_LAST): combat-only ramp — no rest, treasure,
	# merchant, OR elite. Elites only appear from floor EARLY_FLOOR_LAST + 1 on
	# (the mid/late table below), so the first 4 floors stay beginner-safe.
	if floor_idx <= EARLY_FLOOR_LAST:
		if roll < 0.65:
			return "enemy"
		if roll < 0.85:
			return "unknown"
		return "enemy"

	# Mid/late floors: full pool with reduced treasure rate + global treasure cap.
	# (Event "?" band widened 0.37-0.55 = 18%, taken from the plentiful enemy band, so
	# the authored random events show up more without shrinking merchant/rest/elite.)
	if roll < 0.37:
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
			# Pick ONE elite at random so elite nodes vary across a run (and across the
			# two acts) instead of every elite being the same fight.
			result.append(str(ELITE_ROSTER[randi() % ELITE_ROSTER.size()]))
		"enemy", "unknown":
			var pool: Array
			var tier_floor: int = floor_idx + (current_act - 1) * ACT_POOL_OFFSET
			if tier_floor <= 1:
				pool = ENCOUNTER_POOLS_OPENING
			elif tier_floor <= 3:
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
## `hero_id` "" falls back to RunManager.pending_hero_id (set by the warehouse
## hero-select screen). `asc` < 0 falls back to pending_ascension (set by the
## outpost difficulty selector). An explicit hero_id / asc from the caller (e.g.
## home_base_scene._on_start_pressed) always wins. Both pending_* are consumed
## (reset) here.
func start_new_run(hero_id: String, starter_deck: Array[String] = [], asc: int = -1) -> void:
	# A fresh run invalidates any prior in-run save (can't resume the old one).
	clear_run_save()
	# Fallback to the warehouse-screen intent only when no hero was passed.
	if hero_id == "" and pending_hero_id != "":
		hero_id = pending_hero_id
	# Fallback to the outpost-screen intent only when the caller left asc unset
	# (< 0). The start button passes its resolved value (>= 0), so it wins.
	var resolved_asc: int = asc
	if resolved_asc < 0:
		resolved_asc = pending_ascension if pending_ascension >= 0 else 0
	# Consume the run-scoped intent so it never leaks into a later run.
	pending_hero_id = ""
	pending_ascension = -1

	current_hero_id = hero_id
	current_hero_data = _load_hero_def(hero_id)
	ascension = clampi(resolved_asc, 0, 5)

	player_deck.clear()
	tool_inventory.clear()
	xp = 0
	level = 1
	pending_attr_points = 0
	reward_rerolls = 0
	run_started_msec = Time.get_ticks_msec()
	_seen_random_event_ids.clear()
	demo_set_piece_ids_claimed.clear()
	demo_featured_set_id = (
		DEMO_FEATURED_SET_IDS[randi() % DEMO_FEATURED_SET_IDS.size()] if DEMO_BUILD else ""
	)
	# Base deck = explicit `starter_deck` arg, else hero JSON's starter_deck, else
	# DEFAULT_STARTER_DECK. The removed deck-editor override is intentionally not
	# read: old profiles are cleaned/refunded by MetaProgress's schema migration.
	var deck_to_use: Array = starter_deck
	if (
		deck_to_use.is_empty()
		and current_hero_data.has("starter_deck")
		and current_hero_data["starter_deck"] is Array
	):
		deck_to_use = current_hero_data["starter_deck"]
	if deck_to_use.is_empty():
		deck_to_use = DEFAULT_STARTER_DECK
	for card_id in deck_to_use:
		add_card_to_deck(str(card_id))

	# Reset resources and health (hero max_health overrides default 50).
	# gold is derived from the backpack — clearing the backpack zeroes it.
	_run_scrap_counter = 0
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
	# Consume the owned base backpack into the run backpack. Gear is injected
	# before starting Gold so a full carry can never silently delete equipment;
	# physical currencies simply fill whatever cells remain.
	var base_carry: Array = pending_loadout.duplicate(true)
	pending_loadout.clear()
	for entry in base_carry:
		if not add_equip_to_backpack(entry):
			# Defensive only (the base UI caps this list to effective backpack size):
			# retain an overflow/corrupt-save item at base rather than destroying it.
			pending_loadout.append(entry)
	# Inject the base's slot loadout: each pending_equipped entry starts the
	# run already EQUIPPED into its slot (not in the backpack), so it is never
	# double-granted. We write the slot DIRECTLY rather than via equip_to_slot:
	# the slots were reset to {} just above (no prev to bounce) and the queued item
	# is NOT in the backpack, so a direct assignment equips the EXACT queued instance
	# (with its rolled affixes) instead of equip_to_slot's base-id bag-search, which
	# could otherwise grab a same-base loadout copy from the backpack. We re-validate
	# the JSON slot here (the UI gates it, but start_new_run is the trust boundary)
	# and consume the exact owned instance exactly once.
	var equipped_any := false
	var base_equipped: Dictionary = pending_equipped.duplicate(true)
	pending_equipped.clear()
	for slot in EQUIPMENT_SLOTS:
		var queued: Variant = base_equipped.get(slot, null)
		if queued == null:
			continue
		var inst := as_equip_instance(queued)
		if inst.is_empty():
			pending_equipped[slot] = queued
			continue
		var base_id := equip_base(inst)
		var data: Dictionary = get_equipment_data(base_id)
		if str(data.get("slot", "")) != slot:
			pending_equipped[slot] = queued
			continue  # slot mismatch / unknown item: preserve it at base
		equipped_items[slot] = inst
		equipped_any = true
	# Consuming base-owned gear changes profile state. One save covers both arrays
	# and any defensive overflow retained above.
	MetaProgress.save_progress()
	# Every run starts with a baseline purse so the merchant is usable from floor 1.
	# (Command Center's +starting-gold meta upgrade stacks on top in _apply_meta_upgrades.)
	add_gold(STARTING_GOLD)
	# NOTE: equipment attributes are folded in by recompute_attributes() further
	# below — AFTER player_attributes is reset from base_attributes — so we do NOT
	# recompute here (it would be clobbered by that reset).
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
		"strength": int(attrs.get("strength", 0)),
		"constitution": int(attrs.get("constitution", 0)),
		"intelligence": int(attrs.get("intelligence", 0)),
		"luck": int(attrs.get("luck", 0)),
		"charm": int(attrs.get("charm", 0)),
	}
	# Cyber Doctor caps perks → permanent +1 per level to the mapped attribute.
	# Applied after the hero's starting_attributes baseline, before recompute.
	for perk_id in MetaProgress.CYBER_DOC_PERKS:
		var attr := str(MetaProgress.CYBER_DOC_PERKS[perk_id])
		var lvl := MetaProgress.get_caps_perk_level(perk_id)
		if lvl > 0 and attr in base_attributes:
			base_attributes[attr] = int(base_attributes[attr]) + lvl
	player_attributes = base_attributes.duplicate()
	# Fold in any warehouse-loadout gear equipped above: recompute rebuilds
	# player_attributes from base + equipped affixes and applies the equipment
	# max_hp/crit bonuses (its delta math starts clean — _equipment_*_bonus were
	# zeroed before the slot reset). A no-op when no gear was placed.
	if equipped_any:
		recompute_attributes()
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
	if free_cells() <= 0:
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


# --- Bounty tracking (悬赏) ---


## Single in-run entry point for bounty progress. Battle / reward paths call
## this with an event kind (must be in data_validator.ALLOWED_BOUNTY_OBJECTIVES,
## e.g. "kill_elites", "earn_gold") and an amount; forwarded to MetaProgress
## only while a run is active — base-screen / menu activity never ticks bounties.
func bounty_event(kind: String, amount: int = 1) -> void:
	if not is_run_active:
		return
	MetaProgress.bounty_progress_add(kind, amount)


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


## Adjust run resources. `g` = gold delta (routed through the backpack). The
## second arg is the vestigial in-run counter (all callers pass 0 — the meaningful
## run-scrap lives in the backpack as scrap stacks). Kept for call-site compat.
func add_resources(g: int, c: int) -> void:
	# Gold now lives in the backpack; route through add_gold/spend_gold.
	if g > 0:
		add_gold(g)
	elif g < 0:
		spend_gold(-g)
	_run_scrap_counter = max(0, _run_scrap_counter + c)
	emit_signal("resources_changed", total_gold(), _run_scrap_counter)


# --- Backpack (cell model) -------------------------------------------------


func _ensure_backpack() -> void:
	if backpack.size() != MAX_INVENTORY:
		backpack.resize(MAX_INVENTORY)  # new slots are null-filled


## Usable backpack cell count this run: BASE_BACKPACK plus the purchased Outpost
## "backpack" upgrade's cells, clamped to [BASE_BACKPACK, MAX_INVENTORY]. The
## underlying array is always MAX_INVENTORY long; only cells [0, size) are usable.
## Read on-demand (no per-run snapshot) like other meta effects, so buying the
## upgrade between runs takes effect immediately. Old saves without the upgrade
## return BASE_BACKPACK.
func effective_backpack_size() -> int:
	var bonus := int(_get_meta_effect_value("backpack").get("cells", 0))
	return clampi(BASE_BACKPACK + bonus, BASE_BACKPACK, MAX_INVENTORY)


func _first_null_cell() -> int:
	for i in range(effective_backpack_size()):
		if backpack[i] == null:
			return i
	return -1


func free_cells() -> int:
	var n := 0
	for i in range(effective_backpack_size()):
		if backpack[i] == null:
			n += 1
	return n


func backpack_count_used() -> int:
	return effective_backpack_size() - free_cells()


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


## Total scrap carried in the backpack this run (banks to MetaProgress.scrap on
## extract/victory). Was total_run_core() before the 2026-07-07 Core removal.
func total_run_scrap() -> int:
	var t := 0
	for c in backpack:
		if c != null and c.get("kind") == "scrap":
			t += int(c["amount"])
	return t


## Add gold to the backpack (fills partial stacks, then opens new cells).
## Returns the amount actually stored (< n if the backpack ran out of room).
func add_gold(n: int) -> int:
	var stored := _add_stacked("gold", n, GOLD_PER_CELL)
	# Bounty: earn_gold counts only gold that actually entered the backpack
	# (positive deltas; spend_gold is a separate path and never counts).
	if stored > 0:
		bounty_event("earn_gold", stored)
	return stored


## Add run-scrap to the backpack (≤SCRAP_PER_CELL per cell). Returns amount stored.
## Was add_core_to_backpack() before the 2026-07-07 Core removal.
func add_scrap_to_backpack(n: int) -> int:
	return _add_stacked("scrap", n, SCRAP_PER_CELL)


## ── Caps earning helpers (Phase E2) ─────────────────────────────────────────
## Accrue caps into the run-scoped counter. Banked to MetaProgress only at
## extract / victory (see _settle_backpack) — mirrors the backpack-scrap banking.
func award_run_caps(n: int) -> void:
	if n <= 0:
		return
	_run_caps += n


## Award caps for a combat win, sized by the battle node type. Called from the
## victory path the same way scrap is dropped per fight type, so a boss fight
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
	var size := effective_backpack_size()
	var idx := 0
	while g > 0 and idx < size:
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
			return _normalize_set_equip_instance(x)
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
		return _normalize_set_equip_instance({
			"base": item_id,
			"rarity": str(data.get("rarity", "common")),
			"affixes": affixes,
			"cursed": false,
			"set_id": str(data.get("set_id", "")),
		})
	return {}


## Compatibility repair for the retired "ordinary set" state. Early profiles
## may hold either a bare set item id or an instance minted before set rarity was
## centralized. Keep any valid positive affixes, then deterministically fill to
## three so repeated reads of a legacy string never reroll the player's stats.
func _normalize_set_equip_instance(instance: Dictionary) -> Dictionary:
	var base_id := str(instance.get("base", ""))
	if base_id == "":
		return instance
	var data := get_equipment_data(base_id)
	var set_id := str(instance.get("set_id", data.get("set_id", "")))
	if set_id == "":
		return instance

	var source_affixes: Variant = instance.get("affixes", [])
	var affixes: Array = []
	var used_types := {}
	if typeof(source_affixes) == TYPE_ARRAY:
		for entry in source_affixes:
			if typeof(entry) != TYPE_DICTIONARY or AFFIX_POOL.is_curse(entry):
				continue
			var affix_type := str(entry.get("type", ""))
			if affix_type == "" or used_types.has(affix_type):
				continue
			affixes.append((entry as Dictionary).duplicate(true))
			used_types[affix_type] = true
			if affixes.size() == 3:
				break
	for template in AFFIX_POOL.POSITIVE:
		if affixes.size() == 3:
			break
		var affix_type := str(template.get("type", ""))
		if used_types.has(affix_type):
			continue
		affixes.append((template as Dictionary).duplicate(true))
		used_types[affix_type] = true

	if (
		str(instance.get("rarity", "")) == "set"
		and str(instance.get("set_id", "")) == set_id
		and not bool(instance.get("cursed", false))
		and instance.get("affixes", []) == affixes
	):
		return instance
	var normalized := instance.duplicate(true)
	normalized["rarity"] = "set"
	normalized["set_id"] = set_id
	normalized["cursed"] = false
	normalized["affixes"] = affixes
	return normalized


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
	# Owner's 5-tier model: a set piece (has set_id) always reads as the green "set" tier;
	# a cursed item reads as the red "cursed" tier. Both grant 3 positives (cursed +1 curse).
	if cursed:
		resolved_rarity = "cursed"
	elif str(data.get("set_id", "")) != "":
		resolved_rarity = "set"
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

## Crit is a Luck-driven BASE mechanic (any character): each Luck gives
## CRIT_PER_LUCK crit chance. The Crit Clip relic adds CRIT_CLIP_BASE flat AND
## doubles Luck's contribution (CRIT_PER_LUCK_CLIP). No cap — high Luck can reach
## guaranteed crits. Default crit multiplier is 1.5x (powers like All In override).
const CRIT_PER_LUCK := 0.02
const CRIT_PER_LUCK_CLIP := 0.04
const CRIT_CLIP_BASE := 0.05
const CRIT_MULT := 1.5
const RARITY_PER_LUCK := 0.015
const SHOP_PER_CHARM := 0.02
const SHOP_FLOOR := 0.60


func _attr(attr_name: String) -> int:
	return int(player_attributes.get(attr_name, 0))


## Equipment-affix max-HP bonus currently applied to max_health (cached by
## recompute_attributes). Exposed for UI / debugging; the value is already
## folded into max_health.
func equipment_max_hp_bonus() -> int:
	return _equipment_max_hp_bonus


## Equipment-affix crit bonus as a fraction (e.g. +5% crit → 0.05). Summed from
## crit_pct affixes and folded into crit_chance().
func equipment_crit_pct_bonus() -> float:
	return float(_equipment_crit_pct_bonus) / 100.0


## Crit chance — Luck-driven, applied to every player attack (no relic needed).
## Crit Clip adds a flat base and doubles Luck's contribution. Equipment crit_pct
## affixes fold in. Uncapped: stacking Luck can push past 100% (guaranteed crits).
func crit_chance() -> float:
	var per_luck := CRIT_PER_LUCK
	var base := 0.0
	if has_crit_clip():
		per_luck = CRIT_PER_LUCK_CLIP
		base = CRIT_CLIP_BASE
	return max(0.0, base + _attr("luck") * per_luck + equipment_crit_pct_bonus())


## True if any held relic grants the Crit Clip profile — the base `crit_clip` or an
## upgraded variant (Volatile / Deadeye). Detected via the `crit_chance` marker
## effect so an upgrade that REPLACES the base clip keeps Luck→crit coupling without
## hardcoding relic ids.
func has_crit_clip() -> bool:
	for relic_id in relics:
		var effects = get_relic_data(str(relic_id)).get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue
		for e in effects:
			if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "crit_chance":
				return true
	return false


func luck_rarity_bonus() -> float:
	return _attr("luck") * RARITY_PER_LUCK


## Luck-scaled chance for a normal (non-elite, non-boss) combat to also drop a tool.
## Elites give an equipment chance instead; bosses give guaranteed equipment.
## [tunable]
func luck_tool_chance() -> float:
	return clampf(0.25 + 0.03 * float(_attr("luck")), 0.0, 0.60)


## Luck-scaled chance for a normal / elite combat to drop equipment (normal = common,
## elite = uncommon; rolled independently of the tool drop). Bosses always drop a rare
## (granted in battle_scene). Tuned lower than the tool chance so gear stays the rarer,
## more exciting find. [tunable]
func luck_equip_chance() -> float:
	return clampf(0.12 + 0.02 * float(_attr("luck")), 0.0, 0.35)


func charm_shop_mult() -> float:
	return maxf(SHOP_FLOOR, 1.0 - _attr("charm") * SHOP_PER_CHARM)


## Permanently raise a BASE attribute by `amount` and refresh derived totals.
## Single-sources the "bump a base attribute" idiom used by random events.
func grant_attribute(attr: String, amount: int) -> void:
	if attr == "":
		return
	base_attributes[attr] = int(base_attributes.get(attr, 0)) + amount
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


## Deal a random event without replacement for the current run. Once every event
## has been seen, start a fresh deck as a defensive fallback for unusually long
## custom runs. Returns {} when none are loaded.
func pick_random_event() -> Dictionary:
	if _random_events.is_empty():
		return {}
	var available: Array = []
	for event in _random_events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if not str(event.get("id", "")) in _seen_random_event_ids:
			available.append(event)
	if available.is_empty():
		_seen_random_event_ids.clear()
		available = _random_events.duplicate()
	var picked: Dictionary = available[randi() % available.size()]
	var picked_id := str(picked.get("id", ""))
	if picked_id != "":
		_seen_random_event_ids.append(picked_id)
	return picked


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
			"gain_scrap":
				add_scrap_to_backpack(int(effect.get("amount", 0)))
			"gain_relic":
				add_relic(str(effect.get("id", "")))
			"gain_equipment":
				var rarity := str(effect.get("rarity", ""))
				if rarity != "":
					add_equip_to_backpack(roll_shell_drop(rarity))
			"gain_attribute":
				grant_attribute(str(effect.get("attr", "")), int(effect.get("amount", 0)))
			"add_curse":
				# Permanent curse onto the run deck (clearable at the shop's card removal).
				add_card_to_deck(str(effect.get("curse", "radiation_dust")))


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
	_apply_relic_on_pickup(relic_id)
	emit_signal("relics_updated")
	return true


## Run any `on_pickup`-triggered relic effects the moment the relic is acquired
## (outside combat). bounty_tags grants a one-time gold windfall via `gain_gold`.
func _apply_relic_on_pickup(relic_id: String) -> void:
	var data := get_relic_data(relic_id)
	for e in data.get("effects", []):
		if typeof(e) != TYPE_DICTIONARY or str(e.get("trigger", "")) != "on_pickup":
			continue
		match str(e.get("type", "")):
			"gain_gold":
				add_gold(int(e.get("amount", 0)))
			"add_card":
				# Inject N copies of a card into the deck (double-fire clip → 2 Reloads).
				var card_id := str(e.get("card", ""))
				if card_id != "":
					for _i in range(maxi(1, int(e.get("amount", 1)))):
						add_card_to_deck(card_id)


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


const TOOL_DATA_DIR := "res://run_system/data/tools/"


## Load a tool JSON by id (cached). Returns {} on miss.
func get_tool_data(tool_id: String) -> Dictionary:
	if _tool_cache.has(tool_id):
		return _tool_cache[tool_id]
	var data := _load_json_by_id(TOOL_DATA_DIR, tool_id)
	_tool_cache[tool_id] = data
	return data


## All tool ids that have a JSON file (the shop / drop pool).
func tool_pool() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(TOOL_DATA_DIR)
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				ids.append(f.trim_suffix(".json"))
	return ids


## Equipped tool slots (top-bar usable): 1 base + the Outpost "Tool Rack" upgrade +
## any +1-tool-slot relic. Tools are HELD in the backpack and equipped into a slot.
func tool_slots() -> int:
	return 1 + int(_get_meta_effect_value("tool_slots").get("slots", 0)) + relic_tool_slot_bonus()


## Total +tool-slot bonus from held relics (passive effect type "tool_slots").
func relic_tool_slot_bonus() -> int:
	var bonus := 0
	for relic_id in relics:
		var effects = get_relic_data(str(relic_id)).get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue
		for e in effects:
			if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "tool_slots":
				bonus += int(e.get("amount", 0))
	return bonus


## Acquire a tool (drop / event): it goes into the BACKPACK now — equip it into a
## slot from the character panel. Returns false when the backpack is full.
func add_tool(tool_id: String) -> bool:
	return add_tool_to_backpack(tool_id)


## Put a tool into the first free backpack cell (1 tool = 1 cell, like equipment). Returns
## false when the backpack is full (the caller shows the inventory-full toast).
func add_tool_to_backpack(tool_id: String) -> bool:
	if tool_id == "":
		return false
	_ensure_backpack()
	var idx := _first_null_cell()
	if idx == -1:
		return false
	backpack[idx] = {"kind": "tool", "id": tool_id}
	emit_signal("backpack_changed")
	return true


## Tool ids currently held in the backpack (cell order).
func backpack_tool_ids() -> Array[String]:
	var out: Array[String] = []
	for c in backpack:
		if typeof(c) == TYPE_DICTIONARY and c.get("kind") == "tool":
			out.append(str(c.get("id", "")))
	return out


## Equip the backpack tool at cell `index`. A filled target slot is replaced
## atomically: the displaced tool returns to the source backpack cell. Without an
## explicit target, use the first free slot or replace slot zero when all are full.
func equip_tool_from_backpack(index: int, target_slot: int = -1) -> bool:
	_ensure_backpack()
	if index < 0 or index >= backpack.size():
		return false
	var c = backpack[index]
	if typeof(c) != TYPE_DICTIONARY or c.get("kind") != "tool":
		return false
	var slot_count := tool_slots()
	if slot_count <= 0:
		return false
	var resolved_slot := target_slot
	if resolved_slot < 0:
		resolved_slot = tool_inventory.size() if tool_inventory.size() < slot_count else 0
	if resolved_slot < 0 or resolved_slot >= slot_count:
		return false
	# tool_inventory is dense; dropping onto a later empty visual slot still fills
	# the first available position instead of creating holes in the array.
	resolved_slot = mini(resolved_slot, tool_inventory.size())
	var incoming_id := str(c.get("id", ""))
	if resolved_slot < tool_inventory.size():
		var displaced_id := tool_inventory[resolved_slot]
		tool_inventory[resolved_slot] = incoming_id
		backpack[index] = {"kind": "tool", "id": displaced_id}
	else:
		tool_inventory.append(incoming_id)
		backpack[index] = null
	emit_signal("backpack_changed")
	tools_changed.emit()
	return true


## Unequip the tool in slot `index` back into the backpack. Returns false when the
## backpack is full (the tool stays equipped).
func unequip_tool(index: int) -> bool:
	_ensure_backpack()
	if index < 0 or index >= tool_inventory.size():
		return false
	var backpack_index := _first_null_cell()
	if backpack_index == -1:
		return false
	backpack[backpack_index] = {"kind": "tool", "id": tool_inventory[index]}
	tool_inventory.remove_at(index)
	backpack_changed.emit()
	tools_changed.emit()
	return true


## Unequip a tool into the exact empty backpack cell selected by a drag target.
## Unlike unequip_tool(), this never falls back to another free cell.
func unequip_tool_to_backpack(tool_index: int, backpack_index: int) -> bool:
	_ensure_backpack()
	if tool_index < 0 or tool_index >= tool_inventory.size():
		return false
	if backpack_index < 0 or backpack_index >= effective_backpack_size():
		return false
	if backpack[backpack_index] != null:
		return false
	backpack[backpack_index] = {"kind": "tool", "id": tool_inventory[tool_index]}
	tool_inventory.remove_at(tool_index)
	backpack_changed.emit()
	tools_changed.emit()
	return true


## Remove (consume) the tool at `index` from the inventory; emits tools_changed.
func consume_tool(index: int) -> void:
	if index >= 0 and index < tool_inventory.size():
		tool_inventory.remove_at(index)
		tools_changed.emit()


## Pick a random tool id for a drop — uniform over the whole pool (tools have no
## rarity tiers).
func roll_tool_drop(_node_type: String = "") -> String:
	var pool := tool_pool()
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()])


## Spend gold to add a tool to the top-bar inventory. Returns false on insufficient
## gold, an unknown id, or no free tool slot (caller handles the UI in each case).
func purchase_tool(tool_id: String, cost: int) -> bool:
	if tool_id == "" or gold < cost:
		return false
	if backpack_count_used() >= effective_backpack_size():
		return false  # no room in the bag for the tool
	add_resources(-cost, 0)
	add_tool_to_backpack(tool_id)
	return true


## Load equipment JSON by id. Returns empty dict on miss.
func get_equipment_data(item_id: String) -> Dictionary:
	return _load_json_by_id(EQUIPMENT_DATA_DIR, item_id)


## Load equipment set JSON by id. Returns empty dict on miss.
func get_equipment_set_data(set_id: String) -> Dictionary:
	return _load_json_by_id(EQUIPMENT_SET_DATA_DIR, set_id)


## Ascension >= 3: a dropped GENERIC shell has this chance to roll as a cursed
## variant (3 positives incl. 1 attribute + 1 curse). [tunable]
const CURSE_DROP_CHANCE := 0.15
## A drop has this chance to be a SET PIECE of the tier instead of a generic shell
## (keeps sets collectible; shells are the mainline). [tunable]
const SET_PIECE_DROP_CHANCE := 0.15
const EQUIP_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]


## Roll a full equipment INSTANCE for a drop of the given tier (common/uncommon/rare).
## ~15% chance it's a set piece of that tier (keeps sets collectible); otherwise a
## generic shell. At Ascension >= 3 a generic shell may come out cursed (set pieces
## are never cursed). This is the single entry point for all random equipment drops.
func roll_shell_drop(tier: String) -> Dictionary:
	if randf() < SET_PIECE_DROP_CHANCE:
		var piece := _random_set_piece(tier)
		if piece != "":
			return make_equip_instance(piece, tier)
	var slot: String = EQUIP_SLOTS[randi() % EQUIP_SLOTS.size()]
	var base_id: String = "gear_%s_%s" % [slot, tier]
	var is_cursed: bool = ascension >= 3 and randf() < CURSE_DROP_CHANCE
	return make_equip_instance(base_id, tier, is_cursed)


## Random set-piece base id whose rarity matches `tier` (set_id != ""). "" if none.
func _random_set_piece(tier: String) -> String:
	var dir := DirAccess.open(EQUIPMENT_DATA_DIR)
	if dir == null:
		return ""
	var cands: Array[String] = []
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		var d := get_equipment_data(id)
		if str(d.get("set_id", "")) != "" and str(d.get("rarity", "")) == tier:
			cands.append(id)
	if cands.is_empty():
		return ""
	return cands[randi() % cands.size()]


## True when the next non-boss combat reward should advance the demo's featured
## three-piece set track. Floor values are zero-based map indices.
func should_offer_demo_set_piece() -> bool:
	if not DEMO_BUILD or current_act != 1 or demo_featured_set_id == "":
		return false
	var milestone := demo_set_piece_ids_claimed.size()
	if milestone >= DEMO_SET_TRACK_FLOORS.size():
		return false
	return current_floor >= DEMO_SET_TRACK_FLOORS[milestone]


## Roll the next distinct piece from the run's featured set, preferring common
## pieces so the reward remains legible as onboarding. Progress is recorded only
## after the player actually takes it; skipping a drop repeats that milestone.
func roll_demo_set_piece() -> Dictionary:
	if not should_offer_demo_set_piece():
		return {}
	var candidates: Array[String] = []
	var dir := DirAccess.open(EQUIPMENT_DATA_DIR)
	if dir == null:
		return {}
	for rarity in ["common", "uncommon", "rare"]:
		var rarity_candidates: Array[String] = []
		for file_name in dir.get_files():
			if not file_name.ends_with(".json"):
				continue
			var item_id := file_name.get_basename()
			if item_id in demo_set_piece_ids_claimed:
				continue
			var data := get_equipment_data(item_id)
			if (
				str(data.get("set_id", "")) == demo_featured_set_id
				and str(data.get("rarity", "common")) == rarity
			):
				rarity_candidates.append(item_id)
		rarity_candidates.sort()
		candidates.append_array(rarity_candidates)
	if candidates.is_empty():
		return {}
	var chosen := candidates[0]
	var chosen_data := get_equipment_data(chosen)
	return make_equip_instance(chosen, str(chosen_data.get("rarity", "common")))


func mark_demo_set_piece_claimed(instance: Dictionary) -> void:
	if not DEMO_BUILD or instance.is_empty():
		return
	var item_id := equip_base(instance)
	var data := get_equipment_data(item_id)
	if str(data.get("set_id", "")) != demo_featured_set_id:
		return
	if item_id not in demo_set_piece_ids_claimed:
		demo_set_piece_ids_claimed.append(item_id)


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
	# Ascension A2+: -5 max HP per level.
	if ascension >= 2:
		var penalty: int = (ascension - 1) * 5  # A2=-5, A3=-10, A4=-15, A5=-20
		max_health = max(10, max_health - penalty)
		current_health = max_health

	# Reroll Tokens → N reward-screen card rerolls this run.
	reward_rerolls = int(_get_meta_effect_value("reroll_tokens").get("rerolls", 0))

	# Clinic Max-HP caps perk (cyber_hp) → +CYBER_HP_PER_LEVEL max HP per level.
	# Applied here so it is consumed
	# exactly once per run — start_new_run calls _apply_meta_upgrades() once.
	var cyber_hp_lvl := MetaProgress.get_caps_perk_level(MetaProgress.CYBER_HP_PERK)
	if cyber_hp_lvl > 0:
		max_health += cyber_hp_lvl * MetaProgress.CYBER_HP_PER_LEVEL
		current_health = max_health

	# Command Center → +starting gold
	var bonus_gold := int(_get_meta_effect_value("command_center").get("gold", 0))
	if bonus_gold > 0:
		add_gold(bonus_gold)

	# backpack_cells is read on-demand by effective_backpack_size().


func _handle_run_loss(scrap_earned: int = 0) -> void:
	_teardown_run(false, "defeat", scrap_earned)
	# TODO: Trigger base-building retention logic (e.g. keep 30% of scrap)
	print("Player Hero defeated! Run ended.")


## Mark the run as ended cleanly. `scrap_earned` is a display-only summary figure
## (actual banking happens in _settle_backpack, so callers pass 0). `outcome` is
## "victory" for final boss kill, "extracted" for mid-act extract.
## Idempotent — calling twice is a no-op the second time.
## Voluntarily give up the run (pause-menu Abandon): settled as a loss like death
## (no rewards, backpack forfeit except safe cells); the pause panel then routes to base.
func abandon_run() -> void:
	_teardown_run(false, "abandoned", 0)


func end_run_victory(scrap_earned: int = 0, outcome: String = "victory") -> void:
	_teardown_run(true, outcome, scrap_earned)


## Shared run-teardown. Builds the summary dict, flips is_run_active false,
## emits run_ended(victory, summary). Both win and loss paths funnel here
## so future bookkeeping added once applies to both outcomes. Idempotent.
func _teardown_run(victory: bool, outcome: String, scrap_earned: int) -> void:
	if not is_run_active:
		return
	# Bounty: successful extraction settles HERE, not at the UI call site —
	# every extract path funnels into this teardown. Must fire BEFORE the
	# is_run_active=false flip below or the gated bounty_event() would no-op.
	# The idempotency guard above makes it exactly-once.
	if outcome == "extracted":
		bounty_event("extract_alive")
	_settle_backpack(victory, outcome)
	is_run_active = false
	# The run is over (death / extract / victory): drop any resumable save so the
	# title screen's Continue can't reload a finished run.
	clear_run_save()
	var summary := {
		"hero_id": current_hero_id,
		"floor": current_floor,
		"act": current_act,
		"scrap_earned": scrap_earned,
		"outcome": outcome,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	emit_signal("run_ended", victory, summary)


# ─── In-run save / resume ──────────────────────────────────────────────────
## Saved at map (non-battle) checkpoints; loaded by the title "Continue" button.
## Quitting mid-battle loses that battle and resumes at the last map checkpoint.
## In-run save is namespaced to the active save slot (Settings.active_slot), so
## each profile resumes its own run. Slot 0 (none) falls back to slot 1.
func _run_save_path() -> String:
	var s: int = Settings.active_slot
	if s < 1:
		s = 1
	return "user://slot_%d/run_save.json" % s


## True when a resumable in-run save exists on disk (for the active slot).
func has_run_save() -> bool:
	return FileAccess.file_exists(_run_save_path())


## Serialize the full run state to disk. Cheap to call repeatedly. Mirrors the
## MetaProgress JSON pattern (FileAccess + JSON.stringify). No-op outside a run.
func save_run() -> void:
	if not is_run_active:
		return
	var payload := {
		"v": 1,
		"is_run_active": is_run_active,
		"current_hero_id": current_hero_id,
		"current_hero_data": current_hero_data,
		"ascension": ascension,
		"max_health": max_health,
		"current_health": current_health,
		"run_scrap": _run_scrap_counter,
		"run_caps": _run_caps,
		"current_floor": current_floor,
		"current_act": current_act,
		"player_deck": player_deck,
		"equipped_items": equipped_items,
		"backpack": backpack,
		"relics": relics,
		"tool_inventory": tool_inventory,
		"xp": xp,
		"level": level,
		"pending_attr_points": pending_attr_points,
		"reward_rerolls": reward_rerolls,
		# Monotonic tick timestamps are process-local. Persist elapsed duration so
		# continuing a run after restarting the game cannot jump the HUD timer.
		"run_elapsed_msec": (
			maxi(0, Time.get_ticks_msec() - run_started_msec)
			if run_started_msec > 0
			else 0
		),
		# Kept for tolerant reads by older builds; new loads use run_elapsed_msec.
		"run_started_msec": run_started_msec,
		"base_attributes": base_attributes,
		"player_attributes": player_attributes,
		"current_encounter": current_encounter,
		"last_battle_node_type": last_battle_node_type,
		"seen_random_event_ids": _seen_random_event_ids,
		"demo_featured_set_id": demo_featured_set_id,
		"demo_set_piece_ids_claimed": demo_set_piece_ids_claimed,
		"map_data": map_data,
		"current_node_id": current_node_id,
		"visited_node_ids": visited_node_ids,
	}
	var path := _run_save_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("RunManager: could not write %s" % path)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()


## Load a saved run from disk into RunManager state. Returns false if no valid
## save exists (state left untouched). Rebuilds derived caches (node index +
## attributes). On a corrupt/partial save, returns false rather than half-loading.
func load_run() -> bool:
	var path := _run_save_path()
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("RunManager: run save corrupt — ignoring")
		return false
	if not bool(data.get("is_run_active", false)):
		return false

	current_hero_id = str(data.get("current_hero_id", ""))
	current_hero_data = data.get("current_hero_data", {})
	ascension = int(data.get("ascension", 0))
	max_health = int(data.get("max_health", 50))
	current_health = int(data.get("current_health", max_health))
	# Fault-tolerant on the old "core" run-save key (discarded; runs' banked scrap
	# lives in the backpack cells, which round-trip under "backpack").
	_run_scrap_counter = int(data.get("run_scrap", 0))
	_run_caps = int(data.get("run_caps", 0))
	current_floor = int(data.get("current_floor", 0))
	current_act = int(data.get("current_act", 1))
	player_deck = data.get("player_deck", [])
	# Migrate legacy gem saves: gems were removed, so strip any leftover `gems`
	# field from deck entries (fault-tolerant — old saves must load, not crash).
	for e in player_deck:
		if e is Dictionary:
			e.erase("gems")
	equipped_items = data.get("equipped_items", {})
	backpack = data.get("backpack", [])
	# Legacy gem backpack cells no longer exist — null them out so the bag is clean.
	for i in range(backpack.size()):
		var c = backpack[i]
		if c is Dictionary and c.get("kind") == "gem":
			backpack[i] = null
	relics = _to_string_array(data.get("relics", []))
	tool_inventory = _to_string_array(data.get("tool_inventory", []))
	xp = int(data.get("xp", 0))
	level = int(data.get("level", 1))
	pending_attr_points = int(data.get("pending_attr_points", 0))
	reward_rerolls = int(data.get("reward_rerolls", 0))
	var saved_elapsed_msec := int(data.get("run_elapsed_msec", -1))
	if saved_elapsed_msec >= 0:
		run_started_msec = Time.get_ticks_msec() - saved_elapsed_msec
	else:
		# Old saves only stored a process-local tick timestamp. It cannot be
		# reconstructed safely after a restart, so resume their timer from zero.
		run_started_msec = Time.get_ticks_msec()
	base_attributes = data.get("base_attributes", base_attributes)
	player_attributes = data.get("player_attributes", player_attributes)
	current_encounter = _to_string_array(data.get("current_encounter", []))
	last_battle_node_type = str(data.get("last_battle_node_type", "enemy"))
	_seen_random_event_ids = _to_string_array(data.get("seen_random_event_ids", []))
	demo_featured_set_id = str(data.get("demo_featured_set_id", ""))
	demo_set_piece_ids_claimed = _to_string_array(
		data.get("demo_set_piece_ids_claimed", data.get("demo_set_piece_ids_offered", []))
	)
	if DEMO_BUILD and demo_featured_set_id == "":
		demo_featured_set_id = DEMO_FEATURED_SET_IDS[0]
	map_data = _normalize_map(data.get("map_data", []))
	current_node_id = str(data.get("current_node_id", ""))
	visited_node_ids = _to_string_array(data.get("visited_node_ids", []))

	_reindex_map()
	recompute_attributes()
	is_run_active = true
	return true


## Delete any in-run save (on run end, or when a fresh run starts).
func clear_run_save() -> void:
	var path := _run_save_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _reindex_map() -> void:
	_node_index.clear()
	for node in map_data:
		if typeof(node) == TYPE_DICTIONARY and node.has("id"):
			_node_index[str(node.id)] = node


func _to_string_array(v) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for e in v:
			out.append(str(e))
	return out


## Re-coerce JSON-parsed map nodes: numeric fields come back as floats, and
## children must be a String array for id lookups to match. Extra generator
## fields are preserved as-is.
func _normalize_map(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for node in raw:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var n := {
			"id": str(node.get("id", "")),
			"floor": int(node.get("floor", 0)),
			"slot": int(node.get("slot", 0)),
			"type": str(node.get("type", "enemy")),
			"children": _to_string_array(node.get("children", [])),
		}
		for k in node.keys():
			if not n.has(k):
				n[k] = node[k]
		out.append(n)
	return out


## Settle the backpack at run end. Currency banks automatically; equipment never
## enters MetaProgress.stash here. Successful runs recover every backpack
## equipment item plus worn gear into the owned base backpack/loadout. On defeat,
## only equipment in safe cells survives (worn gear and unsafe cells are lost).
func _settle_backpack(victory: bool, outcome: String) -> void:
	# A valid run start consumes these collections completely. If a corrupt or
	# over-cap profile left a defensive remainder, merge the returned gear into it
	# rather than turning settlement into a deletion path.
	if victory or outcome == "extracted":
		# Extract / final victory: bank all carried currency. Equipment remains
		# player-carried and is persisted separately from the warehouse.
		var carried := total_run_scrap()
		if carried > 0:
			MetaProgress.add_scrap(carried)
		# Caps bank alongside scrap: accrued per-fight caps + leftover run gold
		# converted at GOLD_PER_CAP (floor). Banked on extract / victory only; a
		# death (else-branch below) banks no caps.
		var banked_caps := _run_caps + int(total_gold() / GOLD_PER_CAP)
		if banked_caps > 0:
			MetaProgress.add_caps(banked_caps)
		_run_caps = 0
		for c in backpack:
			var inst := _cell_equip_instance(c)
			if not inst.is_empty():
				pending_loadout.append(inst.duplicate(true))
		for slot in EQUIPMENT_SLOTS:
			var eq := as_equip_instance(equipped_items.get(slot, {}))
			if not eq.is_empty():
				pending_equipped[slot] = eq.duplicate(true)
	else:
		# Death: ONLY safe-cell contents (index 0..safe-1) survive. Scrap banks;
		# equipment returns to the base backpack. Everything else + worn gear is lost.
		# Safe cells can never exceed the usable backpack size (or the array length).
		var safe := mini(MetaProgress.effective_safe_cells(), effective_backpack_size())
		var saved := 0
		for i in range(safe):
			var c = backpack[i]
			if c == null:
				continue
			if c.get("kind") == "scrap":
				saved += int(c["amount"])
			elif c.get("kind") == "equip":
				var safe_inst := _cell_equip_instance(c)
				if not safe_inst.is_empty():
					pending_loadout.append(safe_inst.duplicate(true))
		if saved > 0:
			MetaProgress.add_scrap(saved)
	# MetaProgress owns the profile file even though RunManager owns the live
	# arrays. Persist after currency calls so the saved base inventory is the final
	# post-settlement state and never relies on the now-deleted run save.
	MetaProgress.save_progress()


func _emit_all_state() -> void:
	emit_signal("health_changed", current_health, max_health)
	emit_signal("resources_changed", gold, _run_scrap_counter)
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
				print("Resources - Gold: ", gold, " Scrap(bank): ", total_run_scrap())
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
