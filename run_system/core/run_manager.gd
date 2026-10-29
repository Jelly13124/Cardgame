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
## floors_per_act()-tall map ending in a single boss. Reset to 1 by start_new_run.
## advance_act() is retained for the full-game build; the one-act demo cannot
## advance beyond act 1.
var current_act: int = 1
var player_deck: Array = []  # Array of Dictionaries (uid, card_id, bonus_attack, bonus_health)
## Cards removed from the live design. Old run saves may still contain these bare
## pre-namespace IDs (save migration keeps unresolvable refs verbatim);
## load_run strips them before any card factory tries to instantiate missing data.
const RETIRED_CARD_IDS := [
	"crowbar_smash",
	"pipe_swing",
	"breach_charge",
	"bulkhead_bleed",
	"combat_stim",  # bare-ok: retired card id from v1 saves (a tool shares the name)
	"focusing_blow",
	"hemo_drive",
	"last_breath",
	"siphon_valve",
]
const CARD_ID_MIGRATIONS := {
	"vent_plating": "base:kinetic_baffle",
}

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
	"base:strike",
	"base:strike",
	"base:strike",
	"base:strike",
	"base:weak_strike",
	"base:defend",
	"base:defend",
	"base:defend",
	"base:defend",
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

## Random-event definitions (read-only ModelDb data). Populated by
## load_random_events().
var _random_events: Array = []
## Events already dealt during this run. The one-act demo uses a no-replacement
## event deck so a route cannot repeat the same vignette.
var _seen_random_event_ids: Array[String] = []

## Demo-only set onboarding track. Three milestone combat rewards offer distinct
## pieces from one featured set, ensuring the equipment differentiator becomes
## playable before the boss instead of existing only as a rare random drop.
const DEMO_SET_TRACK_FLOORS: Array[int] = [2, 5, 8]
const DEMO_FEATURED_SET_IDS: Array[String] = ["base:weak_hunter", "base:tank_engineer", "base:warden"]
var demo_featured_set_id: String = ""
var demo_set_piece_ids_claimed: Array[String] = []

## Memoized relic view by id (ModelDb data with defaults filled in). Relic data is
## immutable at runtime; the relic effect system reads this per attack hit.
var _relic_data_cache: Dictionary = {}

## Enemy IDs to encounter in the next battle (set by MapScene before loading battle).
## Example: ["trash_robot", "wasteland_killer"]
var current_encounter: Array[String] = ["base:trash_robot"]

## Set by map_scene before launching a battle. Used by loot_reward to decide
## drop rules. Values: "enemy" | "elite" | "boss".
var last_battle_node_type: String = "enemy"

## Acts, their encounters and the map rules are content (content/acts,
## content/encounters, content/runs) read through core/run/acts.gd.

## Acts in this run (the active run configuration's act list).
func acts_total() -> int:
	return ACTS.count()


## Demo build: the active run configuration is the demo one.
func is_demo() -> bool:
	return ACTS.is_demo()


## Floors of the current act's map; the top floor is the boss.
func floors_per_act() -> int:
	return ACTS.floors(current_act)


## True when a floor index is the boss floor — always the top floor of an act.
func is_boss_floor(floor_idx: int) -> bool:
	return floor_idx == floors_per_act() - 1


## The boss enemy id for the act the player is currently on (the run's last
## act's boss past the end of the run).
func current_act_boss() -> String:
	var monsters: Array = MODEL_DB.data("encounter", ACTS.boss_encounter(current_act)).get("monsters", [])
	return str(monsters[0]) if not monsters.is_empty() else ""


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
	generate_map()
	return true


func act_hp_mult() -> float:
	return float(ACTS.act(current_act).get("hp_mult", 1.0))


func act_dmg_mult() -> float:
	return float(ACTS.act(current_act).get("dmg_mult", 1.0))


## Scale a non-boss enemy's base HP by the current act multiplier. Bosses pass
## through unchanged. Stacks multiplicatively with ascension scaling, which is
## applied separately at the spawn site.
func scale_enemy_hp(base_hp: int, enemy_id: String) -> int:
	if ACTS.monster_in_room(enemy_id, "boss"):
		return base_hp
	return int(round(base_hp * act_hp_mult()))


## Scale a non-boss enemy's outgoing attack damage by the current act
## multiplier. Bosses pass through unchanged.
func scale_enemy_damage(amount: int, enemy_id: String) -> int:
	if ACTS.monster_in_room(enemy_id, "boss"):
		return amount
	return int(round(amount * act_dmg_mult()))


const BATTLE_SCENE: String = "uid://dnhj5pp3c1v2l"  # res://ui/battle/battle_screen.tscn
const MAP_SCENE: String = "uid://d3x5b8wvg2q"  # res://ui/map/map_scene.tscn

# --- Map State ---
## Each entry: { "id": String, "floor": int, "slot": int, "type": String, "children": Array[String] }
var map_data: Array = []
var current_node_id: String = ""  ## "" means player hasn't chosen a floor-0 node yet
## IDs of nodes the player has actually entered, in walk order. Used by
## map_renderer to highlight the walked path (vs. nodes merely "below current floor").
var visited_node_ids: Array[String] = []
var _node_index: Dictionary = {}

const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://core/content/data_validator.gd
const EFFECT_REGISTRY = preload("uid://7gab4te60cto")  # res://core/effects/effect_registry.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const RUN_EFFECTS = preload("uid://divb5pd0mx4cc")  # res://core/effects/run_effects.gd
## Run-context effect registry, built on first use.
var _run_effects = null
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
const AFFIX_POOL = preload("uid://dvbrdiqme425c")  # res://run_system/core/affix_pool.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const ENCOUNTERS = preload("uid://mlx3xqfjwlpq")  # res://core/run/encounters.gd
const MAP_GENERATOR = preload("uid://gi3vuuinl2vb")  # res://core/run/map_generator.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const SAVE_MIGRATION = preload("uid://27jpcb0ubw68")  # res://core/content/save_migration.gd
const BOUNTY_TRACKER = preload("uid://dufyeowl6elem")  # res://core/listeners/bounty_tracker.gd
## Run listeners (STS2-style hooks at run level): the bounty tracker.
var run_listeners: Array = [_make_bounty_tracker()]
const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd
## Seeded streams of the current run (RunRngSet); null outside a run.
var run_rng = null
## Stream of the act map being generated (derived from the seed per act).
var _map_rng = null
## Session-only streams for draws outside a run (home-base market, forge, menus).
var _scratch_rng = null
## Seed of the run that just ended, for the result screen.
var _last_run_seed: String = ""


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
func generate_map() -> void:
	# Each act's map comes from its own stream derived from the seed, so it does
	# not depend on how many rolls the previous act used (STS2 builds act maps
	# up front).
	_map_rng = rng_for_act_map(current_act)
	current_node_id = ""
	visited_node_ids.clear()
	var elite_bias := 0.0
	if has_ascension("base:a5_elite_bias"):
		elite_bias = float(ascension_param("base:a5_elite_bias", "roll_floor", 0.5))
	map_data = MAP_GENERATOR.generate(ACTS.act(current_act), _map_rng, elite_bias)
	_node_index.clear()
	for node in map_data:
		_node_index[node.id] = node


func get_node_by_id(id: String) -> Dictionary:
	return _node_index.get(id, {})


# --- Encounter Selection ---


## Picks an enemy roster for a map node of `node_type` on `floor_idx` from the
## current act's encounter data. Called by MapScene before the battle.
func select_encounter(node_type: String, floor_idx: int) -> Array[String]:
	return ENCOUNTERS.select(ACTS.act(current_act), ACTS.boss_encounter(current_act), node_type, floor_idx, rng)


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
func start_new_run(
	hero_id: String, starter_deck: Array[String] = [], asc: int = -1, seed_string: String = ""
) -> void:
	# A fresh run invalidates any prior in-run save (can't resume the old one).
	clear_run_save()
	# Seed first: every roll below draws from the run's streams. An empty or
	# invalid seed (callers validate typed seeds) picks a random one.
	run_rng = RUN_RNG_SET.new(
		seed_string if RUN_RNG_SET.is_valid_seed(seed_string) else RUN_RNG_SET.random_seed_string()
	)
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
		rng("up_front").pick(DEMO_FEATURED_SET_IDS) if is_demo() else ""
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
	current_encounter = ["base:trash_robot"]
	last_battle_node_type = "enemy"
	generate_map()

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
	var uid = str(Time.get_ticks_usec()) + "_" + str(randi_range(1000, 9999))  # rng-ok: deck entry uid uniqueness, not gameplay
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


# --- Run events (run listeners: bounty tracker) ----------------------------
# Typed events owned by the code that changes run state; every run listener
# defining `after_<event>` hears them while a run is active.

func enemy_killed(enemy) -> void:
	_emit_run_event("after_enemy_killed", enemy)


func combat_won(node_type: String) -> void:
	_emit_run_event("after_combat_won", node_type)


func card_played(card_info: Dictionary) -> void:
	_emit_run_event("after_card_played", card_info)


func gold_earned(amount: int) -> void:
	_emit_run_event("after_gold_earned", amount)


func card_upgraded(entry: Dictionary) -> void:
	_emit_run_event("after_card_upgraded", entry)


func run_extracted() -> void:
	_emit_run_event("after_run_extracted", null)


## Mark a run-deck entry upgraded and report it (the one owner of upgrades).
func upgrade_card(entry: Dictionary) -> void:
	entry["upgraded"] = true
	card_upgraded(entry)


func _emit_run_event(method: String, arg) -> void:
	if not is_run_active:
		return
	for listener in run_listeners:
		if not listener.has_method(method):
			continue
		if listener.get_method_argument_count(method) == 0:
			listener.call(method)
		else:
			listener.call(method, arg)


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
	var bonus := int(_get_meta_effect_value("base:backpack").get("cells", 0))
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
		gold_earned(stored)
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


## Collect every random-event definition from ModelDb (read-only data).
func load_random_events() -> void:
	_random_events = []
	for model in MODEL_DB.models("event"):
		_random_events.append(model.data)


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
	var picked: Dictionary = rng("up_front").pick(available)
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


## Apply an event option's effects through the shared effect registry ("run"
## context; see core/effects/run_effects.gd). Run handlers are synchronous, so
## every effect has been applied when this returns.
func apply_event_effects(effects: Array) -> void:
	if _run_effects == null:
		_run_effects = EFFECT_REGISTRY.new()
		RUN_EFFECTS.register_into(_run_effects)
	var ctx = EFFECT_CONTEXT.new()
	ctx.kind = "run"
	for effect in effects:
		if typeof(effect) == TYPE_DICTIONARY:
			_run_effects.execute(ctx, effect)


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


## A writable copy of a character definition. Returns {} if missing.
func _load_hero_def(id: String) -> Dictionary:
	var data := MODEL_DB.mutable("character", id)
	if data.is_empty():
		push_warning("RunManager: unknown character %s" % id)
	return data


## Read-only base-upgrade definition. Returns {} if missing.
func _load_upgrade_def(id: String) -> Dictionary:
	return MODEL_DB.data("base_upgrade", id)


## Full card ids offered to the current character (STS2 CharacterModel.CardPool).
func current_card_pool() -> Array[String]:
	return _pool_ids("card_pool", "cards")


## Full relic ids offered to the current character (CharacterModel.RelicPool).
func current_relic_pool() -> Array[String]:
	return _pool_ids("relic_pool", "relics")


func _pool_ids(pool_category: String, key: String) -> Array[String]:
	var hero := MODEL_DB.data("character", current_hero_id)
	var pool := MODEL_DB.data(pool_category, str(hero.get(pool_category, "")))
	var out: Array[String] = []
	for id in pool.get(key, []):
		out.append(str(id))
	return out


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


## Returns a default-populated dict for relic_id, with any JSON fields merged in.
func get_relic_data(relic_id: String) -> Dictionary:
	if _relic_data_cache.has(relic_id):
		return _relic_data_cache[relic_id]
	var data: Dictionary = {
		"id": relic_id,
		"title": _humanize_id(MODEL_ID.entry_of(relic_id)),
		"description": "",
		"icon": "",
		"rarity": "common",
		"effects": [],
	}
	var parsed: Dictionary = MODEL_DB.data("relic", relic_id)
	for key in parsed.keys():
		data[key] = parsed[key]
	_relic_data_cache[relic_id] = data
	return data


## Read-only tool definition. Returns {} on miss.
func get_tool_data(tool_id: String) -> Dictionary:
	return MODEL_DB.data("tool", tool_id)


## Every tool id (the shop / drop pool).
func tool_pool() -> Array[String]:
	return MODEL_DB.ids("tool")


## Equipped tool slots (top-bar usable): 1 base + the Outpost "Tool Rack" upgrade +
## any +1-tool-slot relic. Tools are HELD in the backpack and equipped into a slot.
func tool_slots() -> int:
	return 1 + int(_get_meta_effect_value("base:tool_slots").get("slots", 0)) + relic_tool_slot_bonus()


## Total +tool-slot bonus from held relics (passive effect type "tool_slots").
func relic_tool_slot_bonus() -> int:
	var bonus := 0
	for relic_id in relics:
		var effects = get_relic_data(str(relic_id)).get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue
		for e in effects:
			if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "tool_slots":  # bare-ok: effect type
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
	return str(rng("rewards").pick(pool))


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


## Read-only equipment definition. Returns {} on miss.
func get_equipment_data(item_id: String) -> Dictionary:
	return MODEL_DB.data("equipment", item_id)


## Read-only equipment set definition. Returns {} on miss.
func get_equipment_set_data(set_id: String) -> Dictionary:
	return MODEL_DB.data("equipment_set", set_id)


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
	if rng("rewards").chance(SET_PIECE_DROP_CHANCE):
		var piece := _random_set_piece(tier)
		if piece != "":
			return make_equip_instance(piece, tier)
	var slot: String = rng("rewards").pick(EQUIP_SLOTS)
	var base_id: String = "base:gear_%s_%s" % [slot, tier]
	var is_cursed: bool = has_ascension("base:a3_cursed_gear") and rng("rewards").chance(CURSE_DROP_CHANCE)
	return make_equip_instance(base_id, tier, is_cursed)


## Random set-piece base id whose rarity matches `tier` (set_id != ""). "" if none.
func _random_set_piece(tier: String) -> String:
	var cands: Array[String] = []
	for id in MODEL_DB.ids("equipment"):
		var d := get_equipment_data(id)
		if str(d.get("set_id", "")) != "" and str(d.get("rarity", "")) == tier:
			cands.append(id)
	if cands.is_empty():
		return ""
	return rng("rewards").pick(cands)


## True when the next non-boss combat reward should advance the demo's featured
## three-piece set track. Floor values are zero-based map indices.
func should_offer_demo_set_piece() -> bool:
	if not is_demo() or current_act != 1 or demo_featured_set_id == "":
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
	for rarity in ["common", "uncommon", "rare"]:
		var rarity_candidates: Array[String] = []
		for item_id in MODEL_DB.ids("equipment"):
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
	if not is_demo() or instance.is_empty():
		return
	var item_id := equip_base(instance)
	var data := get_equipment_data(item_id)
	if str(data.get("set_id", "")) != demo_featured_set_id:
		return
	if item_id not in demo_set_piece_ids_claimed:
		demo_set_piece_ids_claimed.append(item_id)


func get_unowned_relic_ids() -> Array[String]:
	var ids: Array[String] = []
	for relic_id in current_relic_pool():
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
	rng("rewards").shuffle(pool)
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
	# Frail start: less max HP per ascension level above 1 (A2=-5 … A5=-20).
	if has_ascension("base:a2_frail_start"):
		var per_level := int(ascension_param("base:a2_frail_start", "hp_penalty_per_level", 5))
		var floor_hp := int(ascension_param("base:a2_frail_start", "min_max_hp", 10))
		max_health = max(floor_hp, max_health - (ascension - 1) * per_level)
		current_health = max_health

	# Reroll Tokens → N reward-screen card rerolls this run.
	reward_rerolls = int(_get_meta_effect_value("base:reroll_tokens").get("rerolls", 0))

	# Clinic Max-HP caps perk (cyber_hp) → +CYBER_HP_PER_LEVEL max HP per level.
	# Applied here so it is consumed
	# exactly once per run — start_new_run calls _apply_meta_upgrades() once.
	var cyber_hp_lvl := MetaProgress.get_caps_perk_level(MetaProgress.CYBER_HP_PERK)
	if cyber_hp_lvl > 0:
		max_health += cyber_hp_lvl * MetaProgress.CYBER_HP_PER_LEVEL
		current_health = max_health

	# Command Center → +starting gold
	var bonus_gold := int(_get_meta_effect_value("base:command_center").get("gold", 0))
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
	# is_run_active=false flip below or the gated run event would no-op.
	# The idempotency guard above makes it exactly-once.
	if outcome == "extracted":
		run_extracted()
	_settle_backpack(victory, outcome)
	is_run_active = false
	_last_run_seed = run_seed()
	run_rng = null
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
	return "slot_%d/run_save.json" % s


## True when a resumable in-run save exists on disk (for the active slot).
func has_run_save() -> bool:
	return SAVE_IO.exists(_run_save_path())


## Serialize the full run state to disk. Cheap to call repeatedly. Mirrors the
## MetaProgress JSON pattern (FileAccess + JSON.stringify). No-op outside a run.
func save_run() -> void:
	if not is_run_active:
		return
	var payload := {
		"v": SAVE_MIGRATION.RUN_VERSION,
		"rng": run_rng.to_dict() if run_rng != null else {},
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
		"backpack": backpack,  # bare-ok: save key
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
	var err := SAVE_IO.write_json(_run_save_path(), payload)
	if err != OK:
		push_warning("RunManager: could not write run save (%s)" % error_string(err))


## Load a saved run from disk into RunManager state. Returns false if no valid
## save exists (state left untouched). Rebuilds derived caches (node index +
## attributes). On a corrupt/partial save, returns false rather than half-loading.
func load_run() -> bool:
	var result: Dictionary = SAVE_IO.read_json(_run_save_path())
	var status: int = int(result.get("status", SAVE_IO.MISSING))
	if status == SAVE_IO.MISSING:
		return false
	var data: Variant = result.get("data", {})
	if status == SAVE_IO.CORRUPT or typeof(data) != TYPE_DICTIONARY:
		push_warning("RunManager: run save corrupt — ignoring")
		return false
	if status == SAVE_IO.RECOVERED:
		push_warning("RunManager: run save was corrupt, resumed from %s" % result.get("source", ""))
	if not bool(data.get("is_run_active", false)):
		return false
	if SAVE_MIGRATION.run_needs_id_migration(data):
		SAVE_MIGRATION.backup_once(_run_save_path(), data)
	data = SAVE_MIGRATION.migrate_run(data)
	var saved_rng: Variant = data.get("rng", {})
	if typeof(saved_rng) == TYPE_DICTIONARY and RUN_RNG_SET.is_valid_seed(str(saved_rng.get("seed_string", ""))):
		run_rng = RUN_RNG_SET.from_dict(saved_rng)
	else:
		# Saves from before seeded streams: the run continues on a fresh seed.
		run_rng = RUN_RNG_SET.new(RUN_RNG_SET.random_seed_string())

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
	for i in range(player_deck.size()):
		var entry: Variant = player_deck[i]
		var old_card_id := str(entry.get("card_id", "")) if entry is Dictionary else str(entry)
		if not CARD_ID_MIGRATIONS.has(old_card_id):
			continue
		var current_card_id: String = str(CARD_ID_MIGRATIONS[old_card_id])
		if entry is Dictionary:
			entry["card_id"] = current_card_id
		else:
			player_deck[i] = current_card_id
	# Removed cards are intentionally not replaced: keeping a stale ID would make
	# the card factory skip an invisible deck entry on every resumed battle.
	player_deck = player_deck.filter(
		func(entry: Variant) -> bool:
			var card_id := str(entry.get("card_id", "")) if entry is Dictionary else str(entry)
			return card_id not in RETIRED_CARD_IDS
	)
	# Migrate legacy gem saves: gems were removed, so strip any leftover `gems`
	# field from deck entries (fault-tolerant — old saves must load, not crash).
	for e in player_deck:
		if e is Dictionary:
			e.erase("gems")
	equipped_items = data.get("equipped_items", {})
	backpack = data.get("backpack", [])  # bare-ok: save key
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
	if is_demo() and demo_featured_set_id == "":
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
	SAVE_IO.delete(_run_save_path())


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


## The named seeded stream of the current run (see RunRngSet.STREAMS). Outside a
## run it returns a session-only, never-saved stream so callers need no guard.
func rng(stream_name: String):
	if run_rng != null:
		return run_rng.stream(stream_name)
	if _scratch_rng == null:
		_scratch_rng = RUN_RNG_SET.new(RUN_RNG_SET.random_seed_string())
	return _scratch_rng.stream(stream_name)


## Seed string of the current run, or of the run that just ended.
func run_seed() -> String:
	return run_rng.seed_string if run_rng != null else _last_run_seed


## Fresh, unsaved stream for `act`'s map; same seed and act give the same map.
func rng_for_act_map(act: int):
	if run_rng == null:
		return rng("niche")
	return run_rng.derived("map_act_%d" % act)


## True when the run's ascension level reaches the named rule's level
## (content/ascension).
func has_ascension(rule_id: String) -> bool:
	var rule := MODEL_DB.data("ascension", rule_id)
	return not rule.is_empty() and ascension >= int(rule.get("level", 999))


## A numeric parameter of an ascension rule (its `params`), or `default`.
func ascension_param(rule_id: String, key: String, default: Variant) -> Variant:
	return MODEL_DB.data("ascension", rule_id).get("params", {}).get(key, default)


static func _make_bounty_tracker():
	var tracker = load("uid://dufyeowl6elem").new()  # res://core/listeners/bounty_tracker.gd
	tracker.progress = func(kind: String, amount: int) -> void: MetaProgress.bounty_progress_add(kind, amount)
	return tracker
