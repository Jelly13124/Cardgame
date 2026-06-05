## Persistent meta-progression. Survives across runs. Loaded from
## user://meta.json at autoload _ready; saved on every mutation.
##
## Schema: { "core": int, "caps": int, "upgrades": { "<id>": int } }
##   - core: current spendable Core currency
##   - caps: current spendable Caps currency (second permanent currency)
##   - upgrades: id → current level (0..3)
extends Node

const SAVE_PATH := "user://meta.json"

signal core_changed(new_value: int)
signal caps_changed(new_value: int)
signal upgrades_changed

var core: int = 0
## Second permanent currency. Spent at base facilities; earned via E2.
var caps: int = 0
var upgrades: Dictionary = {}
## Facilities unlocked with Core (one-time). facility_id → true once unlocked.
var facilities: Dictionary = {}
## Tiered perks bought with Caps inside a facility. perk_id → int level.
var caps_perk_levels: Dictionary = {}
## Last 50 run summaries (newest at end). Persisted to meta.json.
## Each entry: { hero_id, floor, core_earned, outcome, timestamp }
var run_history: Array = []
## Highest difficulty completed. 0 means no ascension cleared.
var max_ascension: int = 0
## Card ids unlocked beyond the INITIAL_CARD_POOL (added via card_research).
var unlocked_cards: Array[String] = []
## Permanent equipment stash — gear carried out by extracting/surviving (in a
## safe cell). Persists across runs; loaded into a run via the loadout step.
var stash: Array[String] = []

const RUN_HISTORY_CAP := 50
const ASCENSION_CAP := 5
## Two-layer base model: facilities are unlocked once with Core, then Caps buy
## tiered perks inside them.
const FACILITY_UNLOCK_COSTS := {"cyber_doc": 300}
const CAPS_PERK_BASE_COST := 300
const CAPS_PERK_COST_STEP := 150
const CAPS_PERK_MAX_LEVEL := 3
## Cyber Doctor perks: perk_id → the base attribute each level boosts by +1.
const CYBER_DOC_PERKS := {
	"cyber_str": "strength",
	"cyber_con": "constitution",
	"cyber_int": "intelligence",
	"cyber_luck": "luck",
	"cyber_charm": "charm",
}
## Safe-cell baseline; effective count = this + the blacksmith upgrade level.
const SAFE_CELLS_BASE := 2
## Permanent equipment stash capacity (gear carried out of runs).
const STASH_CAP := 40
## Cards available before any card_research is purchased. The omitted
## ids (bone_breaker, last_breath, preemptive_strike, chain_link, last_stand)
## unlock via the card_research upgrade.
const INITIAL_CARD_POOL: Array[String] = [
	"strike",
	"weak_strike",
	"defend",
	"stun_baton",
	"hot_swap",
	"adrenaline",
	"brace",
	"double_tap",
	"siphon",
	"charged_shot",
	"cascade",
	"last_stand",
	"acid_splash",
	"focus",
	"chain_link",
	"reinforce",
	"deflector",
	"bulwark",
	"patch_kit",
	"spiked_guard",
	"corrode",
	"venom_coat",
	"purge",
	"second_wind",
	"smoke_step",
]

## Hero-exclusive draft cards: only offered (loot/shop) when that hero is active.
## The Feng Shui Master's yin/yang/flip cards make no sense for a non-polarity
## hero (Cowboy Bill), so they must NOT roll in his card rewards.
const HERO_EXCLUSIVE_CARDS := {
	"hero_fengshui_master":
	[
		"yin_crescent_cut",
		"yin_still_water",
		"yang_solar_strike",
		"yang_ember_will",
		"taiji_shift",
		"taiji_pivot",
	],
}


func _ready() -> void:
	load_progress()
	RunManager.run_ended.connect(_on_run_ended)


func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	append_run_history(summary)
	# Bump max_ascension only on FULL victory (final boss kill, not extract).
	# Compare RunManager.ascension to current max so unlocking requires
	# clearing at the highest unlocked difficulty.
	if victory and str(summary.get("outcome", "")) == "victory":
		var run_asc: int = int(RunManager.ascension)
		if run_asc >= max_ascension and max_ascension < ASCENSION_CAP:
			max_ascension = run_asc + 1
			save_progress()


func append_run_history(entry: Dictionary) -> void:
	run_history.append(entry)
	while run_history.size() > RUN_HISTORY_CAP:
		run_history.pop_front()
	save_progress()


## Returns the union of INITIAL_CARD_POOL, unlocked_cards, and the ACTIVE hero's
## exclusive cards (so e.g. the Feng Shui Master's yin/yang cards are draftable
## for him but never for Cowboy Bill).
func get_unlocked_card_pool() -> Array[String]:
	var pool: Array[String] = INITIAL_CARD_POOL.duplicate()
	for c in unlocked_cards:
		if not c in pool:
			pool.append(c)
	var hero_id: String = str(RunManager.current_hero_id) if RunManager else ""
	for c in HERO_EXCLUSIVE_CARDS.get(hero_id, []):
		if not str(c) in pool:
			pool.append(str(c))
	return pool


func add_core(amount: int) -> void:
	core = max(0, core + amount)
	save_progress()
	emit_signal("core_changed", core)


func add_caps(amount: int) -> void:
	caps = max(0, caps + amount)
	save_progress()
	emit_signal("caps_changed", caps)


func spend_caps(amount: int) -> bool:
	if caps < amount:
		return false
	caps -= amount
	save_progress()
	emit_signal("caps_changed", caps)
	return true


func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


## --- Two-layer base model: facilities (Core) + caps perks (Caps) ---


func is_facility_unlocked(id: String) -> bool:
	return bool(facilities.get(id, false))


## Spend Core to permanently unlock a facility. Idempotent (returns true if
## already unlocked). Returns false if the id is unknown or Core is insufficient.
func unlock_facility(id: String) -> bool:
	if is_facility_unlocked(id):
		return true
	var cost := int(FACILITY_UNLOCK_COSTS.get(id, -1))
	if cost < 0 or core < cost:
		return false
	core -= cost
	facilities[id] = true
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")
	return true


func get_caps_perk_level(perk_id: String) -> int:
	return int(caps_perk_levels.get(perk_id, 0))


func caps_perk_cost(perk_id: String) -> int:
	return CAPS_PERK_BASE_COST + CAPS_PERK_COST_STEP * get_caps_perk_level(perk_id)


## Returns the facility id a perk belongs to, or "" if unknown.
func _facility_for_perk(perk_id: String) -> String:
	if perk_id in CYBER_DOC_PERKS:
		return "cyber_doc"
	return ""


## Spend Caps to buy one level of a perk. Requires the perk's facility unlocked,
## the perk below its max level, and enough Caps. Returns false otherwise.
func buy_caps_perk(perk_id: String) -> bool:
	var facility := _facility_for_perk(perk_id)
	if facility == "" or not is_facility_unlocked(facility):
		return false
	if get_caps_perk_level(perk_id) >= CAPS_PERK_MAX_LEVEL:
		return false
	var cost := caps_perk_cost(perk_id)
	if caps < cost:
		return false
	caps -= cost
	caps_perk_levels[perk_id] = get_caps_perk_level(perk_id) + 1
	save_progress()
	emit_signal("caps_changed", caps)
	emit_signal("upgrades_changed")
	return true


## Number of safe backpack cells (index 0..N-1) whose contents survive death.
## Derived from the blacksmith upgrade level (persisted in `upgrades`).
func effective_safe_cells() -> int:
	return SAFE_CELLS_BASE + get_upgrade_level("blacksmith")


## Add an item to the permanent stash. Returns false if the stash is full.
func add_to_stash(item_id: String) -> bool:
	if item_id == "" or stash.size() >= STASH_CAP:
		return false
	stash.append(item_id)
	save_progress()
	return true


## Remove one occurrence of item_id from the stash. Returns false if absent.
func remove_from_stash(item_id: String) -> bool:
	var idx := stash.find(item_id)
	if idx < 0:
		return false
	stash.remove_at(idx)
	save_progress()
	return true


func can_purchase(id: String, definition: Dictionary) -> bool:
	var tiers: Array = definition.get("tiers", [])
	var lvl := get_upgrade_level(id)
	if lvl >= tiers.size():
		return false
	return core >= int(tiers[lvl].get("cost", 999999))


func purchase_upgrade(id: String, definition: Dictionary) -> bool:
	if not can_purchase(id, definition):
		return false
	var lvl := get_upgrade_level(id)
	var tier: Dictionary = definition["tiers"][lvl]
	var cost := int(tier["cost"])
	core -= cost
	upgrades[id] = lvl + 1

	# Apply purchase-time side effects (currently just card_pool_unlock —
	# everything else is read on demand at run start).
	var effect_key: String = str(definition.get("effect_key", ""))
	if effect_key == "card_pool_unlock":
		var effect_value: Dictionary = tier.get("effect_value", {})
		var unlocks: Array = effect_value.get("unlocks", [])
		for c in unlocks:
			if not str(c) in unlocked_cards:
				unlocked_cards.append(str(c))

	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")
	return true


func reset_all() -> void:
	core = 0
	caps = 0
	upgrades.clear()
	facilities.clear()
	caps_perk_levels.clear()
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("caps_changed", caps)
	emit_signal("upgrades_changed")


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("MetaProgress: failed to open save file for write")
		return
	var payload := {
		"core": core,
		"caps": caps,
		"upgrades": upgrades,
		"facilities": facilities,
		"caps_perk_levels": caps_perk_levels,
		"run_history": run_history,
		"max_ascension": max_ascension,
		"unlocked_cards": unlocked_cards,
		"stash": stash,
	}
	f.store_string(JSON.stringify(payload, "  "))
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
		push_warning("MetaProgress: corrupt save file at %s, renaming to .bak" % SAVE_PATH)
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		return
	core = int(parsed.get("core", 0))
	caps = int(parsed.get("caps", 0))
	var raw_upgrades = parsed.get("upgrades", {})
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		upgrades = raw_upgrades
	# Back-compat: old saves predate the two-layer base model. Missing keys →
	# empty (cyber_doc locked, no perks bought).
	var rf = parsed.get("facilities", {})
	if typeof(rf) == TYPE_DICTIONARY:
		facilities = rf
	var rp = parsed.get("caps_perk_levels", {})
	if typeof(rp) == TYPE_DICTIONARY:
		caps_perk_levels = rp
	var raw_history = parsed.get("run_history", [])
	if typeof(raw_history) == TYPE_ARRAY:
		run_history = raw_history
	max_ascension = clampi(int(parsed.get("max_ascension", 0)), 0, ASCENSION_CAP)
	var raw_unlocked = parsed.get("unlocked_cards", [])
	if typeof(raw_unlocked) == TYPE_ARRAY:
		unlocked_cards.clear()
		for c in raw_unlocked:
			unlocked_cards.append(str(c))
	var raw_stash = parsed.get("stash", [])
	if typeof(raw_stash) == TYPE_ARRAY:
		stash.clear()
		for s in raw_stash:
			stash.append(str(s))
