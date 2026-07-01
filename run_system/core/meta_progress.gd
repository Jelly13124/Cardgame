## Persistent meta-progression. Survives across runs. Loaded from
## user://meta.json at autoload _ready; saved on every mutation.
##
## Schema: { "core": int, "caps": int, "scrap": int, "upgrades": { "<id>": int } }
##   - core: current spendable Core currency
##   - caps: current spendable Caps currency (second permanent currency)
##   - scrap: current spendable Scrap currency (third permanent currency; earned by
##     dismantling equipment at the blacksmith, spent on reforging)
##   - upgrades: id → current level (0..3)
extends Node

## Save slots. Each slot is an independent profile under user://slot_{n}/. The
## active slot lives in Settings.active_slot (set by the slot-select screen).
## Legacy global user://meta.json is no longer read (the slot system supersedes it).
const SLOT_COUNT := 3
const LEGACY_SAVE_PATH := "user://meta.json"


## meta.json path for a slot (defaults to the active slot). Slot 0 (none chosen)
## falls back to slot 1 so direct save/load never writes to a slotless root.
func _meta_path(slot: int = -1) -> String:
	var s: int = Settings.active_slot if slot < 0 else slot
	if s < 1:
		s = 1
	return "user://slot_%d/meta.json" % s


func _ensure_slot_dir(slot: int = -1) -> void:
	var s: int = Settings.active_slot if slot < 0 else slot
	if s < 1:
		s = 1
	DirAccess.make_dir_recursive_absolute("user://slot_%d" % s)


## Activate a slot: set it globally (persisted via Settings) and load that slot's
## profile into MetaProgress. Used by the slot-select screen's Continue.
func set_active_slot(slot: int) -> void:
	Settings.set_active_slot(slot)
	_reset_to_defaults()
	load_progress()


## True if slot N has a saved profile on disk.
func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_meta_path(slot))


## First slot (1..N) with no save, or 0 if all slots are full.
func first_empty_slot() -> int:
	for n in range(1, SLOT_COUNT + 1):
		if not slot_exists(n):
			return n
	return 0


## The most-recently-played slot to resume: the active slot if it has a save,
## else the lowest-numbered existing slot, else 0 (no saves at all).
func most_recent_slot() -> int:
	if Settings.active_slot >= 1 and slot_exists(Settings.active_slot):
		return Settings.active_slot
	for n in range(1, SLOT_COUNT + 1):
		if slot_exists(n):
			return n
	return 0


## Permanently delete slot N's files (meta + in-run save).
func delete_slot(slot: int) -> void:
	var dir := "user://slot_%d" % slot
	for f in ["meta.json", "meta.json.bak", "run_save.json"]:
		var path: String = dir + "/" + str(f)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Lightweight read of a slot's profile for the menu summary, WITHOUT changing the
## active slot or MetaProgress state. Returns {} for an empty slot.
func peek_slot(slot: int) -> Dictionary:
	var path := _meta_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return {
		"core": int(parsed.get("core", 0)),
		"caps": int(parsed.get("caps", 0)),
		"scrap": int(parsed.get("scrap", 0)),
		"runs": (parsed.get("run_history", []) as Array).size(),
		"max_ascension": int(parsed.get("max_ascension", 0)),
	}


## Start a brand-new profile in `slot`: wipe its files, reset state to defaults,
## and write a fresh meta.json. Also clears that slot's in-run save.
func reset_for_new_game(slot: int) -> void:
	Settings.set_active_slot(slot)
	_ensure_slot_dir(slot)
	var meta := _meta_path(slot)
	if FileAccess.file_exists(meta):
		DirAccess.remove_absolute(meta)
	_reset_to_defaults()
	if RunManager.has_method("clear_run_save"):
		RunManager.clear_run_save()
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("caps_changed", caps)
	emit_signal("scrap_changed", scrap)
	emit_signal("buildings_changed")


## Reset all persisted profile state to first-boot defaults (no disk I/O). Used by
## set_active_slot before a load and by reset_for_new_game.
func _reset_to_defaults() -> void:
	core = 0
	caps = 0
	scrap = 0
	upgrades = {}
	facilities = {}
	caps_perk_levels = {}
	run_history = []
	max_ascension = 0
	tutorial_seen = false
	unlocked_cards = []
	purchased_cards = []
	starter_deck_override = {}
	stash = []
	buildings = {}


signal core_changed(new_value: int)
signal caps_changed(new_value: int)
signal scrap_changed(new_value: int)
signal upgrades_changed
## Emitted when a building's tier changes (unlock/upgrade/reset/migration).
signal buildings_changed

var core: int = 0
## Second permanent currency. Spent at base facilities; earned via E2.
var caps: int = 0
## Third permanent currency. Earned by dismantling equipment at the blacksmith;
## spent on reforging.
var scrap: int = 0
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
## True once the player has seen the first-battle tutorial tips. Persisted so the
## tips show exactly once across all runs. Set via mark_tutorial_seen().
var tutorial_seen: bool = false
## Card ids unlocked beyond the INITIAL_CARD_POOL (added via the Market screen's
## per-card unlock, MetaProgress.unlock_card).
var unlocked_cards: Array[String] = []
## Cards bought (with Caps) at the market T3 card shop. Persistent; appended to
## the run deck at start_new_run (on TOP of the starter/override deck). Back-compat
## default []. These are permanent extra deck cards, NOT consumed on use.
var purchased_cards: Array = []
## Per-hero starter-deck override set by the outpost deck editor. hero_id → Array
## of card_id Strings (the full, ≤2-swap deck). When non-empty for the run's hero,
## start_new_run uses it instead of the hero JSON / DEFAULT_STARTER_DECK. Persistent;
## back-compat default {}.
var starter_deck_override: Dictionary = {}
## Permanent equipment stash — gear carried out by extracting/surviving (in a
## safe cell). Persists across runs; loaded into a run via the loadout step.
## Each entry is an equip INSTANCE dict (see RunManager.as_equip_instance), or a
## legacy item_id String from an older save — both are tolerated on read.
var stash: Array = []
## Buildings refactor (5 clickable base buildings). building_id → tier int
## (0=locked, 1=unlocked, 2, 3). Persisted; back-compat default {}. Warehouse
## reads as tier 1 by default (free) via get_building_tier even when absent here.
var buildings: Dictionary = {}

const RUN_HISTORY_CAP := 50
const ASCENSION_CAP := 5
## Two-layer base model: facilities are unlocked once with Core, then Caps buy
## tiered perks inside them.
const FACILITY_UNLOCK_COSTS := {"cyber_doc": 300}
const CAPS_PERK_BASE_COST := 300
const CAPS_PERK_COST_STEP := 150
const CAPS_PERK_MAX_LEVEL := 3
## Per-perk base-cost overrides for caps_perk_cost. Perks absent here use
## CAPS_PERK_BASE_COST (300). The clinic Max-HP perk (cyber_hp) is cheaper (200).
const CAPS_PERK_BASE_BY_ID := {"cyber_hp": 200}
## Cyber Doctor perks: perk_id → the base attribute each level boosts by +1.
const CYBER_DOC_PERKS := {
	"cyber_str": "strength",
	"cyber_con": "constitution",
	"cyber_int": "intelligence",
	"cyber_luck": "luck",
	"cyber_charm": "charm",
}
## Clinic Max-HP caps perk. Bought with Caps in the clinic (facility "clinic"),
## each level grants +5 max HP at run start (consumed in RunManager.start_new_run).
## Costs 200 + 150*level (cheaper base than the attribute perks). Capped by
## attr_perk_cap() (3 by default, 5 once the clinic reaches T3 high_cap), same as
## the attribute perks — a single tier-aware cap keeps the clinic's perk model uniform.
const CYBER_HP_PERK := "cyber_hp"
const CYBER_HP_PER_LEVEL := 5
## --- Buildings refactor: single source of truth for the 5 base buildings ---
## Each entry: unlock_cost (Core to go locked→T1), tier_costs ([T2 cost, T3 cost]
## in Core), functions (function key → minimum tier that gates it). Warehouse
## unlock_cost is 0 (free) and it defaults to tier 1 via get_building_tier.
const BUILDING_DEFS := {
	"forge":
	{
		"unlock_cost": 60,
		"tier_costs": [100, 180],
		"functions": {"dismantle": 1, "craft": 2, "reforge": 2, "curse": 3},
	},
	"clinic":
	{
		"unlock_cost": 80,
		"tier_costs": [120, 200],
		"functions": {"attr_perks": 1, "max_hp_perk": 2, "high_cap": 3},
	},
	"market":
	{
		"unlock_cost": 100,
		"tier_costs": [140, 240],
		"functions": {"equip_shop": 1, "card_unlock": 1, "better_stock": 2, "card_shop": 3},
	},
	"outpost":
	{
		"unlock_cost": 70,
		"tier_costs": [100, 180],
		"functions":
		{
			"gold": 1,
			"discount": 1,
			"difficulty": 1,
			"safe_cells": 2,
			"deck_editor": 3,
		},
	},
	"warehouse":
	{
		"unlock_cost": 0,
		"tier_costs": [80, 150],
		"functions": {"hero_select": 1, "loadout": 1, "more_slots": 2, "conversion": 3},
	},
}
## Building tier bounds. Tier 0 = locked, MAX_BUILDING_TIER = fully upgraded.
const MAX_BUILDING_TIER := 3
## Safe-cell baseline; effective count = this + the blacksmith upgrade level.
const SAFE_CELLS_BASE := 2
## Permanent equipment stash capacity (gear carried out of runs).
const STASH_CAP := 40
## Blacksmith: scrap yielded by dismantling a stash item, by rarity. Cursed items
## yield +5 extra (the curse is "recycled").
const DISMANTLE_SCRAP := {"common": 5, "uncommon": 12, "rare": 25}
## Blacksmith: scrap cost to reforge (reroll one affix on) a stash item, by rarity.
const REFORGE_COST := {"common": 15, "uncommon": 30, "rare": 50}
## Affix roller (per-instance equipment); used by reforge_stash_item.
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
## Cards available before any are unlocked at the Market. The omitted
## ids (bone_breaker, last_breath, preemptive_strike, chain_link, last_stand)
## unlock via the Market screen's per-card unlock (unlock_card).
# NOTE: strike + defend are basic starter cards (in hero starter decks) and are
# deliberately NOT in the reward/draft pool — getting more of them as rewards is
# pointless and dilutes the pool.
const INITIAL_CARD_POOL: Array[String] = [
	"weak_strike",
	"stun_baton",
	"hot_swap",
	"adrenaline",
	"brace",
	"siphon",
	"charged_shot",
	"cascade",
	"acid_splash",
	"focus",
	"chain_link",
	"deflector",
	"spiked_guard",
	"corrode",
	"venom_coat",
	"purge",
	"smoke_step",
	# StS2 port — colourless (no attribute lean, draftable by every hero).
	"rebar_wave",
	"recoil_shot",
	"arc_flash",
	"vent_plating",
	"brace_protocol",
	"static_shout",
	"data_dump",
	"sweep_arc",
	"tape_patch",
	"crowbar_smash",
	# Build-enabler additions: a second Burn source (AoE) + an in-pool crit-rate source.
	"wildfire",
	"lucky_streak",
]

## Hero-exclusive draft cards: only offered (loot/shop) when that hero is active, so
## a hero's signature cards never roll in another hero's rewards.
const HERO_EXCLUSIVE_CARDS := {
	# Cowboy Bill — the StS2 Ironclad bruiser kit (strength / blood / exhaust).
	"cowboy_bill":
	[
		"piston_jab",
		"pipe_swing",
		"combat_stim",
		"load_up",
		"coagulate",
		"dissect",
		"hot_streak",
		"all_in",
		"hemorrhage",
		"covering_reload",
		"incinerate",
		"focusing_blow",
		"siphon_valve",
		"bulkhead_bleed",
		"hemo_drive",
		"breach_charge",
		"limit_break",
	],
}


## One-shot migration: a pre-slots profile lived at user://meta.json. If it exists and
## slot 1 has no save yet, import it into slot 1 so a returning tester keeps their banked
## Core / stash / unlocks instead of booting an empty profile after the slots update.
func _migrate_legacy_save() -> void:
	if slot_exists(1) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var src := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var text := src.get_as_text()
	src.close()
	if text.strip_edges() == "":
		return
	_ensure_slot_dir(1)
	var dst := FileAccess.open(_meta_path(1), FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(text)
	dst.close()
	push_warning("MetaProgress: migrated legacy user://meta.json -> slot 1")


func _ready() -> void:
	_migrate_legacy_save()
	# Slot system: only load at boot if a slot is already active (e.g. relaunch
	# remembering the last slot). A fresh boot lands on the menu with no slot; the
	# slot-select screen calls set_active_slot() to load the chosen profile.
	if Settings.active_slot >= 1:
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
## exclusive cards (a hero's signature cards are draftable only while he is active).
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


## --- Market: card unlock (Core) + card shop (Caps) + starter-deck override ---


## Spend Core to permanently unlock a card (market T1 card_unlock). Returns false
## if the id is empty, already unlocked (present in unlocked_cards), already part
## of the base pool, or Core is insufficient. Cost is a flat 40 Core.
func unlock_card(id: String) -> bool:
	if id == "":
		return false
	if id in unlocked_cards or id in INITIAL_CARD_POOL:
		return false
	if not spend_core(40):  # saves + emits core_changed
		return false
	unlocked_cards.append(id)
	save_progress()
	emit_signal("upgrades_changed")
	return true


## Spend Caps to buy a card onto the permanent run deck (market T3 card_shop). The
## bought id is appended to purchased_cards and injected into every future run's
## deck at start_new_run. Returns false on insufficient Caps. Duplicates are
## allowed (buying the same card twice adds two copies). Cost is caller-supplied
## (rarity-priced in the market screen).
func buy_card_caps(id: String, cost: int) -> bool:
	if id == "":
		return false
	if not spend_caps(cost):  # saves + emits caps_changed
		return false
	purchased_cards.append(id)
	save_progress()
	emit_signal("upgrades_changed")
	return true


## Persist a per-hero starter-deck override (outpost deck editor). `deck` is the
## full edited deck (Array of card_id Strings, encoding ≤2 swaps off the hero
## default). Stored under hero_id; consumed by start_new_run. An empty `deck`
## clears the override for that hero.
func set_starter_deck_override(hero_id: String, deck: Array) -> void:
	if hero_id == "":
		return
	if deck.is_empty():
		starter_deck_override.erase(hero_id)
	else:
		var out: Array = []
		for c in deck:
			out.append(str(c))
		starter_deck_override[hero_id] = out
	save_progress()


func add_core(amount: int) -> void:
	core = max(0, core + amount)
	save_progress()
	emit_signal("core_changed", core)


## Spend Core (symmetric to spend_caps). Returns false if balance < amount.
func spend_core(amount: int) -> bool:
	if core < amount:
		return false
	core -= amount
	save_progress()
	emit_signal("core_changed", core)
	return true


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


func add_scrap(amount: int) -> void:
	scrap = max(0, scrap + amount)
	save_progress()
	emit_signal("scrap_changed", scrap)


func spend_scrap(amount: int) -> bool:
	if scrap < amount:
		return false
	scrap -= amount
	save_progress()
	emit_signal("scrap_changed", scrap)
	return true


func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


## --- Two-layer base model: facilities (Core) + caps perks (Caps) ---


func is_facility_unlocked(id: String) -> bool:
	return bool(facilities.get(id, false))


func get_caps_perk_level(perk_id: String) -> int:
	return int(caps_perk_levels.get(perk_id, 0))


func caps_perk_cost(perk_id: String) -> int:
	var base := int(CAPS_PERK_BASE_BY_ID.get(perk_id, CAPS_PERK_BASE_COST))
	return base + CAPS_PERK_COST_STEP * get_caps_perk_level(perk_id)


## The effective level cap for clinic caps perks (attribute perks AND the Max-HP
## perk). The clinic's T3 high_cap function raises it from 3 to 5; below T3 it is
## the const default. buy_caps_perk gates every clinic perk by this so the cap is
## tier-aware and single-sourced (the const CAPS_PERK_MAX_LEVEL remains the floor).
func attr_perk_cap() -> int:
	return 5 if building_can("clinic", "high_cap") else CAPS_PERK_MAX_LEVEL


## Returns the facility id a perk belongs to, or "" if unknown. Both the Cyber
## Doctor attribute perks and the Max-HP perk live in the "clinic" facility (the
## ported Cyber Doctor model — facility id "cyber_doc" for the attribute perks,
## building id "clinic" for tier gating; they refer to the same base building).
func _facility_for_perk(perk_id: String) -> String:
	if perk_id in CYBER_DOC_PERKS:
		return "cyber_doc"
	if perk_id == CYBER_HP_PERK:
		return "clinic"
	return ""


## Spend Caps to buy one level of a perk. Requires the perk's facility unlocked,
## the perk below its (tier-aware) max level, and enough Caps. Returns false
## otherwise. The attribute perks live under the "cyber_doc" facility (Core-
## unlocked); the Max-HP perk (cyber_hp) lives under the "clinic" building and
## requires it at T2 (max_hp_perk). Both share the attr_perk_cap() level ceiling.
func buy_caps_perk(perk_id: String) -> bool:
	var facility := _facility_for_perk(perk_id)
	if facility == "":
		return false
	if facility == "clinic":
		# cyber_hp: gated by the clinic building's max_hp_perk function (T2).
		if not building_can("clinic", "max_hp_perk"):
			return false
	elif not is_facility_unlocked(facility):
		return false
	if get_caps_perk_level(perk_id) >= attr_perk_cap():
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


## --- Buildings refactor: tiered Core-gated buildings ---


## Current tier of a building (0=locked, 1=unlocked, 2, 3). Warehouse defaults to
## tier 1 (free) when absent; all others default to 0 (locked).
func get_building_tier(id: String) -> int:
	return int(buildings.get(id, 1 if id == "warehouse" else 0))


func is_building_unlocked(id: String) -> bool:
	return get_building_tier(id) >= 1


## Spend Core to unlock a building (locked → T1). Idempotent (returns true if
## already unlocked). Returns false on unknown id or insufficient Core.
func unlock_building(id: String) -> bool:
	if not BUILDING_DEFS.has(id):
		return false
	if is_building_unlocked(id):
		return true
	var cost := int(BUILDING_DEFS[id].get("unlock_cost", -1))
	if cost < 0 or core < cost:
		return false
	core -= cost
	buildings[id] = 1
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("buildings_changed")
	return true


## Spend Core to upgrade a building one tier (T1→T2 or T2→T3). Returns false if
## locked, already maxed, unknown id, or insufficient Core.
func upgrade_building(id: String) -> bool:
	if not BUILDING_DEFS.has(id):
		return false
	var cur := get_building_tier(id)
	if cur < 1 or cur >= MAX_BUILDING_TIER:
		return false
	var tier_costs: Array = BUILDING_DEFS[id].get("tier_costs", [])
	if cur - 1 >= tier_costs.size():
		return false
	var cost := int(tier_costs[cur - 1])
	if core < cost:
		return false
	core -= cost
	buildings[id] = cur + 1
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("buildings_changed")
	return true


## True if the building's current tier is high enough to gate `function`. Unknown
## functions are treated as ungated-by-an-impossible-tier (never available).
func building_can(id: String, function: String) -> bool:
	if not BUILDING_DEFS.has(id):
		return false
	var functions: Dictionary = BUILDING_DEFS[id].get("functions", {})
	return get_building_tier(id) >= int(functions.get(function, 99))


## Cost (Core) of the next action on a building: its unlock cost if locked, else
## the next tier-up cost, else -1 if maxed or unknown. For UI button labels.
func next_building_cost(id: String) -> int:
	if not BUILDING_DEFS.has(id):
		return -1
	var cur := get_building_tier(id)
	if cur < 1:
		return int(BUILDING_DEFS[id].get("unlock_cost", -1))
	if cur >= MAX_BUILDING_TIER:
		return -1
	var tier_costs: Array = BUILDING_DEFS[id].get("tier_costs", [])
	if cur - 1 >= tier_costs.size():
		return -1
	return int(tier_costs[cur - 1])


## One-time migration: seed `buildings` from legacy facility/upgrade state so no
## progress is lost when the buildings refactor lands. Idempotent — only ever
## RAISES a building's tier (never lowers it). Legacy fields are NOT deleted (the
## Phase-1 building screens still read caps_perk_levels / upgrades).
func _normalize_buildings() -> void:
	# Cyber Doctor facility unlocked → Clinic is at least tier 1.
	if bool(facilities.get("cyber_doc", false)):
		buildings["clinic"] = maxi(get_building_tier("clinic"), 1)
	# Blacksmith safe-cell upgrade owned → Outpost at least tier 2 (safe_cells is
	# an Outpost T2 function).
	if get_upgrade_level("blacksmith") > 0:
		buildings["outpost"] = maxi(get_building_tier("outpost"), 2)


## Effective permanent-stash capacity. Derived from the warehouse building tier so
## there is no separate persistent field to migrate: T1 (default) = STASH_CAP, each
## tier above T1 adds 5 slots (T2 → +5, T3 → +10). The warehouse "more_slots"
## function (T2) is exactly this raise, so upgrading the warehouse IS the slot raise.
func effective_stash_cap() -> int:
	return STASH_CAP + 5 * max(0, get_building_tier("warehouse") - 1)


## Add an equip to the permanent stash. Accepts an instance dict or a legacy
## item_id String; an empty instance / "" is rejected. Returns false if the
## stash is full (effective_stash_cap) or the entry is empty.
func add_to_stash(item: Variant) -> bool:
	if stash.size() >= effective_stash_cap():
		return false
	if typeof(item) == TYPE_STRING:
		if str(item) == "":
			return false
	elif typeof(item) == TYPE_DICTIONARY:
		if (item as Dictionary).is_empty():
			return false
	else:
		return false
	stash.append(item)
	save_progress()
	return true


## Remove one occurrence of `item` from the stash. Matches instances by VALUE
## (and legacy strings by equality). Returns false if absent.
func remove_from_stash(item: Variant) -> bool:
	var idx := stash.find(item)
	if idx < 0:
		return false
	stash.remove_at(idx)
	save_progress()
	return true


## --- Blacksmith: dismantle (→ scrap) + reforge (spend scrap, reroll affix) ---


## Dismantle stash item `index`: remove it and grant scrap based on its rarity
## (+5 if cursed). Emits scrap_changed (via add_scrap) and upgrades_changed so the
## blacksmith panel rebuilds. Returns false for an out-of-range index.
func dismantle_stash_item(index: int) -> bool:
	if index < 0 or index >= stash.size():
		return false
	var inst: Dictionary = RunManager.as_equip_instance(stash[index])
	var rarity: String = str(inst.get("rarity", "common"))
	var amount: int = int(DISMANTLE_SCRAP.get(rarity, DISMANTLE_SCRAP["common"]))
	if bool(inst.get("cursed", false)):
		amount += 5
	stash.remove_at(index)
	add_scrap(amount)  # saves + emits scrap_changed
	save_progress()
	emit_signal("upgrades_changed")
	return true


## Scrap cost of the NEXT reforge on this instance: rarity base × (reforge_count + 1),
## so the price climbs each time the SAME item is reforged (15→30→45… for common).
func reforge_cost_for(inst: Dictionary) -> int:
	var rarity: String = str(inst.get("rarity", "common"))
	var base: int = int(REFORGE_COST.get(rarity, REFORGE_COST["common"]))
	var count: int = int(inst.get("reforge_count", 0))
	return base * (count + 1)


## Forge reforge with a SINGLE-affix lock + escalating cost (the owner's rule):
##   - First reforge on an item rerolls affix `affix_index` AND locks the item to it
##     (stored as reforge_index).
##   - Every later reforge MUST target that same locked index — a different index is
##     refused. Cost escalates via reforge_cost_for (reforge_count grows each time).
## Curses are never reforgeable. Returns false on a bad index, a curse target, a
## mismatched index after lock, or insufficient scrap. reforge_index/reforge_count
## persist on the instance dict (legacy string entries get upgraded to a dict here).
func reforge_stash_item_locked(item_index: int, affix_index: int) -> bool:
	if item_index < 0 or item_index >= stash.size():
		return false
	var inst: Dictionary = RunManager.as_equip_instance(stash[item_index])
	if inst.is_empty():
		return false
	var affixes: Array = RunManager.equip_affixes(inst)
	if affix_index < 0 or affix_index >= affixes.size():
		return false
	if AFFIX_POOL.is_curse(affixes[affix_index]):
		return false  # curses can't be reforged
	var locked: int = int(inst.get("reforge_index", -1))
	if locked >= 0 and affix_index != locked:
		return false  # already locked to a different affix
	var cost: int = reforge_cost_for(inst)
	if scrap < cost:
		return false
	spend_scrap(cost)  # saves + emits scrap_changed
	inst["affixes"] = AFFIX_POOL.reroll_at(affixes, affix_index)
	inst["reforge_index"] = affix_index
	inst["reforge_count"] = int(inst.get("reforge_count", 0)) + 1
	stash[item_index] = inst
	save_progress()
	emit_signal("upgrades_changed")
	return true


## Curse stash item `index` (forge T3): spend 100 scrap to re-roll its affixes as
## a cursed set for its rarity and flag cursed=true. Stores the result back as a
## full instance dict (converts legacy strings). Returns false on bad index, an
## already-cursed item, or insufficient scrap. Emits scrap_changed (via spend_scrap).
const CURSE_SCRAP_COST := 100


func curse_stash_item(index: int) -> bool:
	if index < 0 or index >= stash.size():
		return false
	var inst: Dictionary = RunManager.as_equip_instance(stash[index])
	if inst.is_empty():
		return false
	if bool(inst.get("cursed", false)):
		return false
	if not spend_scrap(CURSE_SCRAP_COST):  # saves + emits scrap_changed
		return false
	inst["affixes"] = AFFIX_POOL.roll("cursed")
	inst["cursed"] = true
	inst["rarity"] = "cursed"  # red cursed tier — 3 positives + 1 curse
	stash[index] = inst
	save_progress()
	emit_signal("upgrades_changed")
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

	# All surviving base upgrades' effects are read on demand at run start; none
	# carry a purchase-time side effect anymore.

	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")
	return true


func reset_all() -> void:
	core = 0
	caps = 0
	scrap = 0
	upgrades.clear()
	facilities.clear()
	caps_perk_levels.clear()
	buildings.clear()
	purchased_cards.clear()
	starter_deck_override.clear()
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("caps_changed", caps)
	emit_signal("scrap_changed", scrap)
	emit_signal("upgrades_changed")
	emit_signal("buildings_changed")


## Mark the first-battle tutorial as seen and persist, so the tips never show
## again. Idempotent — a no-op once already set.
func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	save_progress()


func save_progress() -> void:
	_ensure_slot_dir()
	var f := FileAccess.open(_meta_path(), FileAccess.WRITE)
	if not f:
		push_warning("MetaProgress: failed to open save file for write")
		return
	var payload := {
		"core": core,
		"caps": caps,
		"scrap": scrap,
		"upgrades": upgrades,
		"facilities": facilities,
		"caps_perk_levels": caps_perk_levels,
		"run_history": run_history,
		"max_ascension": max_ascension,
		"unlocked_cards": unlocked_cards,
		"purchased_cards": purchased_cards,
		"starter_deck_override": starter_deck_override,
		"stash": stash,
		"buildings": buildings,
		"tutorial_seen": tutorial_seen,
	}
	f.store_string(JSON.stringify(payload, "  "))
	f.close()


func load_progress() -> void:
	var path := _meta_path()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MetaProgress: corrupt save file at %s, renaming to .bak" % path)
		DirAccess.rename_absolute(path, path + ".bak")
		return
	core = int(parsed.get("core", 0))
	caps = int(parsed.get("caps", 0))
	scrap = int(parsed.get("scrap", 0))
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
	tutorial_seen = bool(parsed.get("tutorial_seen", false))
	var raw_unlocked = parsed.get("unlocked_cards", [])
	if typeof(raw_unlocked) == TYPE_ARRAY:
		unlocked_cards.clear()
		for c in raw_unlocked:
			unlocked_cards.append(str(c))
	# Back-compat: old saves predate the market card-shop / deck-override. Missing
	# keys → empty (no purchased cards, no per-hero deck overrides).
	var raw_purchased = parsed.get("purchased_cards", [])
	purchased_cards.clear()
	if typeof(raw_purchased) == TYPE_ARRAY:
		for c in raw_purchased:
			purchased_cards.append(str(c))
	var raw_override = parsed.get("starter_deck_override", {})
	starter_deck_override.clear()
	if typeof(raw_override) == TYPE_DICTIONARY:
		for hid in raw_override:
			var deck = raw_override[hid]
			if typeof(deck) == TYPE_ARRAY:
				var out: Array = []
				for c in deck:
					out.append(str(c))
				starter_deck_override[str(hid)] = out
	# Stash entries may be equip INSTANCE dicts (new) or legacy item_id Strings
	# (old saves). Preserve both as-is — RunManager.as_equip_instance converts
	# strings on read; no normalization needed here (lower-risk than rewriting
	# the save). Anything that isn't a dict/string is coerced to a string id.
	var raw_stash = parsed.get("stash", [])
	if typeof(raw_stash) == TYPE_ARRAY:
		stash.clear()
		for s in raw_stash:
			if typeof(s) == TYPE_DICTIONARY or typeof(s) == TYPE_STRING:
				stash.append(s)
			else:
				stash.append(str(s))
	# Back-compat: old saves predate the buildings refactor. Missing key →
	# empty {} (all locked except warehouse, which reads tier 1 by default).
	# JSON int keys round-trip as Strings; values may parse as float, so coerce.
	var raw_buildings = parsed.get("buildings", {})
	buildings.clear()
	if typeof(raw_buildings) == TYPE_DICTIONARY:
		for bid in raw_buildings:
			buildings[str(bid)] = int(raw_buildings[bid])
	# One-time migration: seed building tiers from legacy facility/upgrade state
	# so no progress is lost. Idempotent (only raises tiers); legacy fields kept.
	_normalize_buildings()


# --- Card-info cache (loading optimization, Phase 5) -----------------------
#
# The vendored json_card_factory re-parses every card JSON each time a battle (or
# the shop) builds a factory — ~50 file reads + JSON parses per battle. This
# session-level cache parses each card's JSON ONCE; cached_card_factory.gd reads
# from it instead of re-scanning. (Addon untouched per ADR-0005.)

const _CARD_INFO_ROOT := "res://battle_scene/card_info"
var _card_info_cache: Dictionary = {}  # card_name -> parsed info Dictionary


## Parsed card-info for every card JSON under card_info/, built once and reused
## for the rest of the session. Returns {card_name: info_dict}. Callers must NOT
## mutate the returned dicts — the factory deep-copies per card when it builds a
## battle's cards.
func get_card_info_cache() -> Dictionary:
	if _card_info_cache.is_empty():
		_build_card_info_cache(_CARD_INFO_ROOT)
		print("CardInfoCache: parsed %d card JSONs once." % _card_info_cache.size())
	return _card_info_cache


func _build_card_info_cache(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_build_card_info_cache(path + "/" + file_name)
		elif file_name.ends_with(".json"):
			var info := _parse_card_json(path + "/" + file_name)
			if not info.is_empty():
				_card_info_cache[file_name.get_basename()] = info
		file_name = dir.get_next()


func _parse_card_json(full_path: String) -> Dictionary:
	if not FileAccess.file_exists(full_path):
		return {}
	var f := FileAccess.open(full_path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
