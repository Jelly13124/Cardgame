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
const CARD_DIR = "res://battle_scene/card_info/player/"
const ENEMY_DIR = "res://battle_scene/card_info/enemy/"
const RELIC_DIR = "res://run_system/data/relics/"
const EQUIPMENT_DIR = "res://run_system/data/equipment/"
const SET_DIR = "res://run_system/data/equipment_sets/"
const BASE_UPGRADE_DIR = "res://run_system/data/base_upgrades/"
const HERO_DIR = "res://run_system/data/heroes/"
const RANDOM_EVENT_DIR = "res://run_system/data/random_events/"

# ─── Card schema ──────────────────────────────────────────────────────────────
const REQUIRED_CARD_KEYS = ["name", "title", "type", "cost", "effects"]
const ALLOWED_CARD_TYPES = ["attack", "skill", "ability"]
const ALLOWED_RARITIES = ["common", "uncommon", "rare"]
const ALLOWED_EFFECT_TYPES = [
	"deal_damage",
	"deal_damage_all",
	"scale_damage_by_attacks",
	"gain_block",
	"gain_energy",
	"draw_cards",
	"gain_strength",
	"gain_constitution",
	"gain_intelligence",
	"gain_luck",
	"gain_charm",
	"apply_status",
	"apply_status_self",
	"apply_status_all",
	"apply_shock",
	"apply_shock_all",
	"exhaust_self",
]
const ALLOWED_STATUS_NAMES = [
	"poison",
	"burn",
	"weak",
	"vulnerable",
	"strength_up",
	"double_damage",
	"shock",
]
# Effect types that require a `status` field
const STATUS_BEARING_EFFECTS = [
	"apply_status",
	"apply_status_self",
	"apply_status_all",
]
# Optional flags that are allowed at the card root level
const KNOWN_OPTIONAL_CARD_KEYS = [
	"description",
	"front_image",
	"side",
	"rarity",
	"retain",
]

# ─── Enemy schema ─────────────────────────────────────────────────────────────
const REQUIRED_ENEMY_KEYS = ["id", "name", "sprite_id", "max_health", "action_pattern"]
const ALLOWED_ENEMY_ACTION_TYPES = [
	"attack",
	"attack_status",
	"attack_all",
	"block",
	"heal",
	"telegraph",
]
# Action types that require a `status` field
const STATUS_BEARING_ACTIONS = ["attack_status"]

# ─── Equipment schema ────────────────────────────────────────────────────────
const REQUIRED_EQUIPMENT_KEYS = ["id", "name", "slot", "rarity", "bonuses", "description", "sprite"]
const ALLOWED_EQUIPMENT_SLOTS = ["head", "chest", "weapon", "hands", "accessory"]
const ALLOWED_ATTRIBUTE_KEYS = ["strength", "constitution", "intelligence", "luck", "charm"]
const KNOWN_OPTIONAL_EQUIPMENT_KEYS = ["set_id"]

# ─── Equipment set schema ────────────────────────────────────────────────────
const REQUIRED_SET_KEYS = ["id", "name", "description", "tiers"]
const REQUIRED_TIER_KEYS = ["count", "label", "effect"]
const ALLOWED_SET_EFFECT_TYPES = [
	"start_turn_block",
	"start_turn_energy",
	"start_battle_block",
	"skill_block_bonus",
	"attack_damage_bonus",
	"attack_apply_status",
]
const STATUS_BEARING_SET_EFFECTS = ["attack_apply_status"]

# ─── Base upgrade schema ─────────────────────────────────────────────────────
const REQUIRED_BASE_UPGRADE_KEYS = ["id", "name", "description", "effect_key", "tiers"]
const REQUIRED_BASE_UPGRADE_TIER_KEYS = ["level", "cost", "effect_value", "effect_text"]
const ALLOWED_BASE_UPGRADE_EFFECT_KEYS = [
	"max_hp_bonus",
	"starter_inventory",
	"loot_rarity_bias",
	"shop_discount",
	"starting_gold",
	"unlock_hero",
	"starter_attributes",
	"card_pool_unlock",
	"safe_cells_bonus",
]

# ─── Hero schema ─────────────────────────────────────────────────────────────
const REQUIRED_HERO_KEYS = [
	"id", "name", "sprite_id", "max_health", "starter_deck", "starting_attributes"
]
const HERO_ATTRIBUTE_KEYS = ["strength", "constitution", "intelligence", "luck", "charm"]

# ─── Random event schema ─────────────────────────────────────────────────────
const REQUIRED_EVENT_KEYS = ["id", "title", "options"]
const ALLOWED_EVENT_EFFECT_TYPES = [
	"gain_gold",
	"lose_hp",
	"heal",
	"gain_core",
	"gain_relic",
	"gain_equipment",
	"gain_attribute",
]


## Scan all card / enemy / relic directories and validate every JSON file,
## plus cross-check that every enemy ID referenced by RunManager's encounter
## pools / elite / boss rosters has a JSON file backing it.
## Returns the number of validation failures.
static func validate_all_data_at_startup() -> int:
	var failures = 0
	failures += _validate_dir(CARD_DIR, Callable(DataValidator, "validate_card"))
	failures += _validate_dir(ENEMY_DIR, Callable(DataValidator, "validate_enemy"))
	# Relic files are very small and well-tested; only validate their existence.
	failures += _validate_dir(RELIC_DIR, Callable(DataValidator, "validate_relic"))
	failures += _validate_dir(EQUIPMENT_DIR, Callable(DataValidator, "validate_equipment"))
	failures += _validate_dir(SET_DIR, Callable(DataValidator, "validate_equipment_set"))
	failures += _validate_dir(BASE_UPGRADE_DIR, Callable(DataValidator, "validate_base_upgrade"))
	failures += _validate_dir(HERO_DIR, Callable(DataValidator, "validate_hero"))
	# Random events are optional content (the "?" node falls back gracefully when
	# none exist); only validate the dir when it is present so a missing/empty dir
	# does not fail boot. _validate_dir reports a missing dir as a failure.
	if DirAccess.dir_exists_absolute(RANDOM_EVENT_DIR):
		failures += _validate_dir(RANDOM_EVENT_DIR, Callable(DataValidator, "validate_event"))
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
		"ENCOUNTER_POOLS_MID": RunManager.ENCOUNTER_POOLS_MID,
		"ENCOUNTER_POOLS_LATE": RunManager.ENCOUNTER_POOLS_LATE,
		"ELITE_ROSTER": [RunManager.ELITE_ROSTER],
		"BOSS_ROSTER": [RunManager.BOSS_ROSTER],
		"ACT_BOSSES": [RunManager.ACT_BOSSES],
	}
	for source_name in sources:
		var pools = sources[source_name]
		for pool in pools:
			for enemy_id in pool:
				if not known_ids.has(str(enemy_id)):
					push_error(
						(
							"DataValidator: %s references unknown enemy id '%s' — add %s%s.json or fix the constant."
							% [source_name, enemy_id, ENEMY_DIR, enemy_id]
						)
					)
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
			push_error(
				"%s: effect[%d] type '%s' not in %s" % [prefix, i, etype, ALLOWED_EFFECT_TYPES]
			)
			ok = false
		# Effects that reference a status name must carry a valid status
		if etype in STATUS_BEARING_EFFECTS:
			if not effect.has("status"):
				push_error("%s: effect[%d] (%s) is missing 'status'" % [prefix, i, etype])
				ok = false
			elif not str(effect["status"]) in ALLOWED_STATUS_NAMES:
				push_error(
					(
						"%s: effect[%d] status '%s' not in %s"
						% [prefix, i, effect["status"], ALLOWED_STATUS_NAMES]
					)
				)
				ok = false
		# ADR-0004: shock is enemy-only. Reject applying it to the player.
		if etype == "apply_status_self" and str(effect.get("status", "")) == "shock":
			push_error(
				(
					"%s: effect[%d] tries to apply 'shock' to self — shock is enemy-only (see docs/adr/0004-shock-enemy-only.md)"
					% [prefix, i]
				)
			)
			ok = false
		# `scale_damage_by_attacks` needs explicit base + per (both ints/floats)
		if etype == "scale_damage_by_attacks":
			for required_key in ["base", "per"]:
				if not effect.has(required_key):
					push_error(
						(
							"%s: effect[%d] (scale_damage_by_attacks) is missing '%s'"
							% [prefix, i, required_key]
						)
					)
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
			push_error(
				(
					"%s: action[%d] type '%s' not in %s"
					% [prefix, i, atype, ALLOWED_ENEMY_ACTION_TYPES]
				)
			)
			ok = false
		if atype in STATUS_BEARING_ACTIONS:
			if not action.has("status"):
				push_error("%s: action[%d] (%s) is missing 'status'" % [prefix, i, atype])
				ok = false
			elif not str(action["status"]) in ALLOWED_STATUS_NAMES:
				push_error(
					(
						"%s: action[%d] status '%s' not in %s"
						% [prefix, i, action["status"], ALLOWED_STATUS_NAMES]
					)
				)
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
				push_error(
					(
						"%s: bonus '%s' must be a number, got %s"
						% [prefix, attr, typeof(bonuses[attr])]
					)
				)
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
			push_error(
				(
					"%s: tier[%d] effect type '%s' not in %s"
					% [prefix, i, etype, ALLOWED_SET_EFFECT_TYPES]
				)
			)
			ok = false
		if etype in STATUS_BEARING_SET_EFFECTS:
			if not effect.has("status"):
				push_error("%s: tier[%d] effect (%s) missing 'status'" % [prefix, i, etype])
				ok = false
			elif not str(effect["status"]) in ALLOWED_STATUS_NAMES:
				push_error(
					(
						"%s: tier[%d] status '%s' not in %s"
						% [prefix, i, effect["status"], ALLOWED_STATUS_NAMES]
					)
				)
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


static func validate_base_upgrade(data: Dictionary, path: String) -> bool:
	var prefix := "BaseUpgrade '%s'" % path
	var ok := true
	for key in REQUIRED_BASE_UPGRADE_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false
	if not ok:
		return false
	if not data["effect_key"] in ALLOWED_BASE_UPGRADE_EFFECT_KEYS:
		push_error(
			(
				"%s: unknown effect_key '%s' (allowed: %s)"
				% [prefix, data["effect_key"], ALLOWED_BASE_UPGRADE_EFFECT_KEYS]
			)
		)
		ok = false
	var tiers = data.get("tiers", [])
	if typeof(tiers) != TYPE_ARRAY or tiers.size() == 0:
		push_error("%s: 'tiers' must be a non-empty array" % prefix)
		return false
	for i in range(tiers.size()):
		var tier = tiers[i]
		if typeof(tier) != TYPE_DICTIONARY:
			push_error("%s: tier %d is not a dictionary" % [prefix, i])
			ok = false
			continue
		for key in REQUIRED_BASE_UPGRADE_TIER_KEYS:
			if not tier.has(key):
				push_error("%s: tier %d missing required key '%s'" % [prefix, i, key])
				ok = false
		if tier.has("effect_value") and typeof(tier["effect_value"]) != TYPE_DICTIONARY:
			push_error("%s: tier %d 'effect_value' must be a dictionary" % [prefix, i])
			ok = false
	return ok


static func validate_hero(data: Dictionary, path: String) -> bool:
	var prefix := "Hero '%s'" % path
	var ok := true
	for key in REQUIRED_HERO_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false
	if not ok:
		return false

	if typeof(data["max_health"]) != TYPE_FLOAT and typeof(data["max_health"]) != TYPE_INT:
		push_error("%s: max_health must be a number" % prefix)
		ok = false
	if typeof(data["starter_deck"]) != TYPE_ARRAY:
		push_error("%s: starter_deck must be an Array" % prefix)
		ok = false
	if typeof(data["starting_attributes"]) != TYPE_DICTIONARY:
		push_error("%s: starting_attributes must be a Dictionary" % prefix)
		return false
	for attr in HERO_ATTRIBUTE_KEYS:
		if not data["starting_attributes"].has(attr):
			push_error("%s: starting_attributes missing '%s'" % [prefix, attr])
			ok = false
	return ok


## Validate a single random-event JSON dictionary. Returns true on success.
## Requires id/title/options; each option needs `text` and either an `effects`
## array OR the luck_check trio (effects_success + effects_fail). Every effect's
## `type` must be in ALLOWED_EVENT_EFFECT_TYPES with its required params present.
static func validate_event(data: Dictionary, source_path: String) -> bool:
	var prefix := "Event '%s'" % source_path
	var ok := true

	for key in REQUIRED_EVENT_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false

	if not ok:
		return false

	var options = data["options"]
	if typeof(options) != TYPE_ARRAY or options.is_empty():
		push_error("%s: 'options' must be a non-empty Array" % prefix)
		return false

	for i in range(options.size()):
		var option = options[i]
		if typeof(option) != TYPE_DICTIONARY:
			push_error("%s: option[%d] is not a Dictionary" % [prefix, i])
			ok = false
			continue
		if not option.has("text"):
			push_error("%s: option[%d] is missing 'text'" % [prefix, i])
			ok = false

		var has_effects: bool = option.has("effects")
		var has_luck_trio: bool = option.has("effects_success") and option.has("effects_fail")
		if not has_effects and not has_luck_trio:
			push_error(
				(
					"%s: option[%d] needs 'effects' OR both 'effects_success' and 'effects_fail'"
					% [prefix, i]
				)
			)
			ok = false

		for effect_key in ["effects", "effects_success", "effects_fail"]:
			if not option.has(effect_key):
				continue
			var effects = option[effect_key]
			if typeof(effects) != TYPE_ARRAY:
				push_error("%s: option[%d] '%s' must be an Array" % [prefix, i, effect_key])
				ok = false
				continue
			for j in range(effects.size()):
				if not _validate_event_effect(
					effects[j], "%s option[%d] %s[%d]" % [prefix, i, effect_key, j]
				):
					ok = false

	return ok


## Validate a single event effect dictionary. Returns true on success.
static func _validate_event_effect(effect: Variant, prefix: String) -> bool:
	var ok := true
	if typeof(effect) != TYPE_DICTIONARY:
		push_error("%s: effect is not a Dictionary" % prefix)
		return false
	var etype := str(effect.get("type", ""))
	if not etype in ALLOWED_EVENT_EFFECT_TYPES:
		push_error("%s: effect type '%s' not in %s" % [prefix, etype, ALLOWED_EVENT_EFFECT_TYPES])
		return false
	match etype:
		"gain_relic":
			if not effect.has("id"):
				push_error("%s: gain_relic effect is missing 'id'" % prefix)
				ok = false
		"gain_equipment":
			if not effect.has("rarity"):
				push_error("%s: gain_equipment effect is missing 'rarity'" % prefix)
				ok = false
		"gain_attribute":
			for required_key in ["attr", "amount"]:
				if not effect.has(required_key):
					push_error("%s: gain_attribute effect is missing '%s'" % [prefix, required_key])
					ok = false
	return ok
