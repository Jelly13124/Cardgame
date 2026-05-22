## Load-time validation for card, enemy, and relic JSON files.
## Catches typos in keys, effect types, status names, and enemy action types
## before they cause silent bugs in playtest.
##
## Called from `RunManager._ready()`. In debug builds, asserts on any failure
## so the dev sees a stack trace immediately. In release builds, push_error()
## logs to the console but lets the game continue with potentially broken data.
extends RefCounted
class_name DataValidator

# ─── Paths ────────────────────────────────────────────────────────────────────
const CARD_DIR      = "res://battle_scene/card_info/player/"
const ENEMY_DIR     = "res://battle_scene/card_info/enemy/"
const RELIC_DIR     = "res://run_system/data/relics/"
const EQUIPMENT_DIR = "res://run_system/data/equipment/"
const SET_DIR       = "res://run_system/data/equipment_sets/"

# ─── Card schema ──────────────────────────────────────────────────────────────
const REQUIRED_CARD_KEYS = ["name", "title", "type", "cost", "effects"]
const ALLOWED_CARD_TYPES = ["attack", "skill", "ability"]
const ALLOWED_RARITIES   = ["common", "uncommon", "rare"]
const ALLOWED_EFFECT_TYPES = [
	"deal_damage", "deal_damage_all", "scale_damage_by_attacks",
	"gain_block", "gain_energy", "draw_cards",
	"gain_strength", "gain_constitution", "gain_intelligence", "gain_luck", "gain_charm",
	"apply_status", "apply_status_self", "apply_status_all",
	"apply_shock", "apply_shock_all", "exhaust_self",
]
const ALLOWED_STATUS_NAMES = [
	"poison", "burn", "weak", "vulnerable", "strength_up", "double_damage", "shock",
]
# Effect types that require a `status` field
const STATUS_BEARING_EFFECTS = [
	"apply_status", "apply_status_self", "apply_status_all",
]
# Optional flags that are allowed at the card root level
const KNOWN_OPTIONAL_CARD_KEYS = [
	"description", "front_image", "side", "rarity", "retain",
]

# ─── Enemy schema ─────────────────────────────────────────────────────────────
const REQUIRED_ENEMY_KEYS = ["id", "name", "sprite_id", "max_health", "action_pattern"]
const ALLOWED_ENEMY_ACTION_TYPES = [
	"attack", "attack_status", "attack_all", "block", "heal", "telegraph",
]
# Action types that require a `status` field
const STATUS_BEARING_ACTIONS = ["attack_status"]

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


## Scan all card / enemy / relic directories and validate every JSON file,
## plus cross-check that every enemy ID referenced by RunManager's encounter
## pools / elite / boss rosters has a JSON file backing it.
## Returns the number of validation failures.
static func validate_all_data_at_startup() -> int:
	var failures = 0
	failures += _validate_dir(CARD_DIR,  Callable(DataValidator, "validate_card"))
	failures += _validate_dir(ENEMY_DIR, Callable(DataValidator, "validate_enemy"))
	# Relic files are very small and well-tested; only validate their existence.
	failures += _validate_dir(RELIC_DIR, Callable(DataValidator, "validate_relic"))
	failures += _validate_dir(EQUIPMENT_DIR, Callable(DataValidator, "validate_equipment"))
	failures += _validate_dir(SET_DIR,       Callable(DataValidator, "validate_equipment_set"))
	# Cross-check encounter pools so a typo in RunManager constants fails at
	# startup instead of crashing the player mid-combat in enemy_entity.create().
	failures += validate_encounter_pools()

	if failures > 0:
		push_error("DataValidator: %d validation failure(s). See errors above." % failures)
	else:
		print("DataValidator: all card/enemy/relic/equipment/set JSON files passed schema check.")
	return failures


## Walk every enemy ID referenced by RunManager's encounter constants and
## confirm a matching JSON file exists. Catches typos like "scrap_rats" vs
## "scrap_rat" before they crash a battle.
static func validate_encounter_pools() -> int:
	var failures = 0
	var known_ids: Dictionary = _list_enemy_ids()

	var sources = {
		"ENCOUNTER_POOLS_EARLY": RunManager.ENCOUNTER_POOLS_EARLY,
		"ENCOUNTER_POOLS_MID":   RunManager.ENCOUNTER_POOLS_MID,
		"ENCOUNTER_POOLS_LATE":  RunManager.ENCOUNTER_POOLS_LATE,
		"ELITE_ROSTER":          [RunManager.ELITE_ROSTER],
		"BOSS_ROSTER":           [RunManager.BOSS_ROSTER],
	}
	for source_name in sources:
		var pools = sources[source_name]
		for pool in pools:
			for enemy_id in pool:
				if not known_ids.has(str(enemy_id)):
					push_error("DataValidator: %s references unknown enemy id '%s' — add %s%s.json or fix the constant." % [source_name, enemy_id, ENEMY_DIR, enemy_id])
					failures += 1
	return failures


static func _list_enemy_ids() -> Dictionary:
	var result: Dictionary = {}
	var dir = DirAccess.open(ENEMY_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and not dir.current_is_dir():
			result[file_name.get_basename()] = true
		file_name = dir.get_next()
	return result


## Validate a single card JSON dictionary. Returns true on success.
static func validate_card(data: Dictionary, source_path: String) -> bool:
	var prefix := "Card '%s'" % source_path
	var ok := true

	# Required top-level keys
	for key in REQUIRED_CARD_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false

	if not ok:
		return false

	# Enumerated fields
	if not data["type"] in ALLOWED_CARD_TYPES:
		push_error("%s: type '%s' not in %s" % [prefix, data["type"], ALLOWED_CARD_TYPES])
		ok = false

	if data.has("rarity") and not str(data["rarity"]) in ALLOWED_RARITIES:
		push_error("%s: rarity '%s' not in %s" % [prefix, data["rarity"], ALLOWED_RARITIES])
		ok = false

	if typeof(data["cost"]) != TYPE_INT and typeof(data["cost"]) != TYPE_FLOAT:
		push_error("%s: cost must be a number, got %s" % [prefix, typeof(data["cost"])])
		ok = false

	# Effects array
	var effects = data["effects"]
	if typeof(effects) != TYPE_ARRAY:
		push_error("%s: effects must be an Array, got %s" % [prefix, typeof(effects)])
		return false

	for i in range(effects.size()):
		var effect = effects[i]
		if typeof(effect) != TYPE_DICTIONARY:
			push_error("%s: effect[%d] is not a Dictionary" % [prefix, i])
			ok = false
			continue
		if not effect.has("type"):
			push_error("%s: effect[%d] is missing 'type'" % [prefix, i])
			ok = false
			continue
		var etype = str(effect["type"])
		if not etype in ALLOWED_EFFECT_TYPES:
			push_error("%s: effect[%d] type '%s' not in %s" % [prefix, i, etype, ALLOWED_EFFECT_TYPES])
			ok = false
		# Effects that reference a status name must carry a valid status
		if etype in STATUS_BEARING_EFFECTS:
			if not effect.has("status"):
				push_error("%s: effect[%d] (%s) is missing 'status'" % [prefix, i, etype])
				ok = false
			elif not str(effect["status"]) in ALLOWED_STATUS_NAMES:
				push_error("%s: effect[%d] status '%s' not in %s" % [prefix, i, effect["status"], ALLOWED_STATUS_NAMES])
				ok = false
		# ADR-0004: shock is enemy-only. Reject applying it to the player.
		if etype == "apply_status_self" and str(effect.get("status", "")) == "shock":
			push_error("%s: effect[%d] tries to apply 'shock' to self — shock is enemy-only (see docs/adr/0004-shock-enemy-only.md)" % [prefix, i])
			ok = false
		# `scale_damage_by_attacks` needs explicit base + per (both ints/floats)
		if etype == "scale_damage_by_attacks":
			for required_key in ["base", "per"]:
				if not effect.has(required_key):
					push_error("%s: effect[%d] (scale_damage_by_attacks) is missing '%s'" % [prefix, i, required_key])
					ok = false
		# `apply_shock` / `apply_shock_all` need stacks (or amount as fallback)
		if etype in ["apply_shock", "apply_shock_all"]:
			if not effect.has("stacks") and not effect.has("amount"):
				push_error("%s: effect[%d] (%s) needs 'stacks' (or 'amount')" % [prefix, i, etype])
				ok = false

	# Unknown top-level keys → warn (not fatal) — helps catch typos like "retian"
	var known_keys = REQUIRED_CARD_KEYS + KNOWN_OPTIONAL_CARD_KEYS
	for key in data.keys():
		if not key in known_keys:
			push_warning("%s: unknown top-level key '%s' (typo?)" % [prefix, key])

	return ok


## Validate a single enemy JSON dictionary. Returns true on success.
static func validate_enemy(data: Dictionary, source_path: String) -> bool:
	var prefix := "Enemy '%s'" % source_path
	var ok := true

	for key in REQUIRED_ENEMY_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false

	if not ok:
		return false

	var pattern = data["action_pattern"]
	if typeof(pattern) != TYPE_ARRAY:
		push_error("%s: action_pattern must be an Array" % prefix)
		return false

	for i in range(pattern.size()):
		var action = pattern[i]
		if typeof(action) != TYPE_DICTIONARY:
			push_error("%s: action[%d] is not a Dictionary" % [prefix, i])
			ok = false
			continue
		if not action.has("type"):
			push_error("%s: action[%d] is missing 'type'" % [prefix, i])
			ok = false
			continue
		var atype = str(action["type"])
		if not atype in ALLOWED_ENEMY_ACTION_TYPES:
			push_error("%s: action[%d] type '%s' not in %s" % [prefix, i, atype, ALLOWED_ENEMY_ACTION_TYPES])
			ok = false
		if atype in STATUS_BEARING_ACTIONS:
			if not action.has("status"):
				push_error("%s: action[%d] (%s) is missing 'status'" % [prefix, i, atype])
				ok = false
			elif not str(action["status"]) in ALLOWED_STATUS_NAMES:
				push_error("%s: action[%d] status '%s' not in %s" % [prefix, i, action["status"], ALLOWED_STATUS_NAMES])
				ok = false

	return ok


## Minimal relic validation — only check that required keys exist and effects[]
## entries have a trigger.
static func validate_relic(data: Dictionary, source_path: String) -> bool:
	var prefix := "Relic '%s'" % source_path
	var ok := true
	for key in ["id", "title", "effects"]:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false
	if not ok or typeof(data.get("effects", null)) != TYPE_ARRAY:
		return ok
	for i in range(data["effects"].size()):
		var effect = data["effects"][i]
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if not effect.has("trigger"):
			push_error("%s: effect[%d] is missing 'trigger'" % [prefix, i])
			ok = false
	return ok


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

		if not tier.has("effect"):
			continue  # Missing effect already reported above; skip sub-validation to avoid double errors.

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

	# Unknown top-level keys → warn (helps catch typos)
	for key in data.keys():
		if not key in REQUIRED_SET_KEYS:
			push_warning("%s: unknown top-level key '%s' (typo?)" % [prefix, key])

	return ok


# ─── Internal ─────────────────────────────────────────────────────────────────

static func _validate_dir(dir_path: String, validator: Callable) -> int:
	var failures = 0
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_error("DataValidator: cannot open directory '%s'" % dir_path)
		return 1
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and not dir.current_is_dir():
			var full_path = dir_path + file_name
			var data = _read_json(full_path)
			if data.is_empty():
				push_error("DataValidator: failed to parse '%s'" % full_path)
				failures += 1
			elif not validator.call(data, full_path):
				failures += 1
		file_name = dir.get_next()
	return failures


static func _read_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
