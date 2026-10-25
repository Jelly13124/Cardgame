## Load-time validation for card, enemy, and relic JSON files.
## Catches typos in keys, effect types, status names, and enemy action types
## before they cause silent bugs in playtest.
##
## Called from `RunManager._ready()`. In debug builds, asserts on any failure
## so the dev sees a stack trace immediately. In release builds, push_error()
## logs to the console but lets the game continue with potentially broken data.
extends RefCounted
class_name DataValidator

# ─── Core resolvers ───────────────────────────────────────────────────────────
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://run_system/core/card_upgrade.gd

# ─── Content ──────────────────────────────────────────────────────────────────
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

const REQUIRED_TOOL_KEYS = ["id", "title", "effects"]
const ALLOWED_TOOL_TARGETS = ["enemy", "self", "none"]

# ─── Bounty schema ───────────────────────────────────────────────────────────
# Objective `type`s come from the bounty tracker (core/listeners/bounty_tracker.gd),
# which maps typed run events onto them.
const REQUIRED_BOUNTY_KEYS = ["id", "title", "objective", "reward", "tier"]
# `price` is a legacy field from the market's paid-bounty model — bounty taking
# is free since 2026-07-07, so the field is OPTIONAL and ignored at runtime
# (still type-checked when present so a typo'd contract fails loud).
const OPTIONAL_BOUNTY_KEYS = ["price"]
const BOUNTY_TRACKER = preload("uid://dufyeowl6elem")  # res://core/listeners/bounty_tracker.gd


## Objective types the bounty tracker counts (core/listeners/bounty_tracker.gd).
static func allowed_bounty_objectives() -> Array:
	return BOUNTY_TRACKER.OBJECTIVES
const ALLOWED_BOUNTY_TIERS = ["standard", "hard"]
# Reward keys a bounty may grant. caps/scrap are currency ints; `equipment`
# names a drop tier fed to RunManager.roll_shell_drop. (Core removed 2026-07-07.)
const ALLOWED_BOUNTY_REWARD_CURRENCIES = ["caps", "scrap"]
const ALLOWED_BOUNTY_EQUIPMENT_TIERS = ["common", "uncommon", "rare"]

# ─── Card schema ──────────────────────────────────────────────────────────────
const REQUIRED_CARD_KEYS = ["id", "title", "type", "cost", "effects"]
const ALLOWED_CARD_TYPES = ["attack", "skill", "ability", "curse"]
# "unique" = hero-starting relics (e.g. crit_clip). Drop/shop pools bucket by
# common/uncommon/rare and must never surface a unique relic (see
# get_unowned_relic_ids / shop_scene._list_unowned_relics, which exclude it).
const ALLOWED_RARITIES = ["common", "uncommon", "rare", "unique", "curse"]
const EFFECT_CATALOG = preload("uid://880atc7mnnie")  # res://battle_scene/combat/effect_catalog.gd


## Card effect types: every combat type whose definition does not say `card: false`.
static func allowed_card_effect_types() -> PackedStringArray:
	var out := PackedStringArray()
	for type in EFFECT_CATALOG.registry().types("combat"):
		if bool(EFFECT_CATALOG.registry().definition(type).get("card", true)):
			out.append(type)
	return out
## Runtime status keys of every status definition (content/statuses).
static func allowed_status_names() -> Array:
	return MODEL_DB.ids("status").map(func(i): return MODEL_ID.key_entry(i))
# Effect types that require a `status` field
const STATUS_BEARING_EFFECTS = [
	"apply_status",
	"apply_status_self",
	"apply_status_all",
]
# Optional flags that are allowed at the card root level
const KNOWN_OPTIONAL_CARD_KEYS = [
	"description",
	"vars",
	"effects_template",
	"front_image",
	"side",
	"rarity",
	"ui_skin",
	"retain",
	"polarity",
	"matched_bonus",
	"unplayable",
	"end_turn_in_hand",
	"tags",
	"upgrade",
]
# Yin/Yang polarity values a card may declare (absent = treated as "neutral")
const ALLOWED_CARD_POLARITIES = ["yin", "yang", "neutral"]

# ─── Relic schema ─────────────────────────────────────────────────────────────
# Effect `type`s a relic effect may declare. Each is handled by
# `relic_effect_system` at its trigger point (the two-place rule).
const ALLOWED_RELIC_EFFECT_TYPES = [
	"add_damage",
	"add_short_circuit",
	"attack_replay",
	"attack_limit",
	"thorns_short_circuit",
	"add_card",
	"add_card_to_hand",
	"apply_self_status",
	"apply_status",
	"gain_temp_strength",
	"block_gain_damage",
	"crit_chance",
	"deal_damage_all",
	"gain_block",
	"gain_block_crit",
	"gain_energy",
	"gain_gold",
	"gain_strength",
	"heal",
	"reduce_damage",
	"set_polarity_alternating",
	"set_strength",
	"crit_mult",
	"auto_crit",
	"bonus_allowance",
	"tool_slots",  # bare-ok: effect key
]

# ─── Enemy schema ─────────────────────────────────────────────────────────────
const REQUIRED_ENEMY_KEYS = ["id", "name", "sprite_id", "tier", "max_health", "action_pattern"]
const ALLOWED_ENEMY_TIERS = ["minion", "normal", "heavy", "elite", "boss"]
const ENCOUNTER_BUDGETS := {
	"ENCOUNTER_POOLS_OPENING": Vector2i(12, 18),
	"ENCOUNTER_POOLS_EARLY": Vector2i(20, 30),
	"ENCOUNTER_POOLS_MID": Vector2i(25, 34),
	"ENCOUNTER_POOLS_LATE": Vector2i(34, 50),
}
const ALLOWED_ENEMY_ACTION_TYPES = [
	"attack",
	"attack_ramp",
	"attack_status",
	"attack_all",
	"block",
	"breakable_block",
	"reflective_plating",
	"heal",
	"telegraph",
	"summon",
	"buff_self",
	"add_curse",
]
# Action types that require a `status` field
const STATUS_BEARING_ACTIONS = ["attack_status", "breakable_block"]

# ─── Equipment schema ────────────────────────────────────────────────────────
const REQUIRED_EQUIPMENT_KEYS = ["id", "name", "slot", "rarity", "bonuses", "description", "sprite"]
const ALLOWED_EQUIPMENT_SLOTS = ["head", "chest", "weapon", "hands", "accessory"]
const ALLOWED_ATTRIBUTE_KEYS = ["strength", "constitution", "intelligence", "luck", "charm"]
const KNOWN_OPTIONAL_EQUIPMENT_KEYS = ["set_id"]
## Affix `type` strings rolled at RUNTIME by affix_pool.gd (Phase 2 affix model).
## Affixes are not shipped in JSON, so they are not boot-validated; this list
## exists to honor the two-place rule — when E_B/E_C consume affix types they are
## documented/enumerated here alongside the affix pool definitions.
const ALLOWED_AFFIX_TYPES = [
	"attr_strength",
	"attr_constitution",
	"attr_intelligence",
	"attr_luck",
	"attr_charm",
	"crit_pct",
	"max_hp",
	"curse_attr_strength",
	"curse_attr_constitution",
	"curse_attr_intelligence",
	"curse_attr_luck",
	"curse_attr_charm",
	"curse_max_hp",
	"curse_crit",
]

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
	"starting_gold",
	"reroll_tokens",  # bare-ok: effect key
	"tool_slots",  # bare-ok: effect key
	"safe_cells_bonus",
	"backpack_cells",
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
	"gain_scrap",
	"gain_relic",
	"gain_equipment",
	"gain_attribute",
	"add_curse",
]


## Validate every ModelDb entry with its category's schema, report ModelDb load
## errors (bad JSON, id/file mismatch, unresolved references), and cross-check
## that every enemy ID referenced by RunManager's encounter pools / elite / boss
## rosters exists. Returns the number of validation failures.
static func validate_all_data_at_startup() -> int:
	var failures = 0
	for error in MODEL_DB.load_errors():
		push_error("DataValidator: %s" % error)
		failures += 1
	failures += _validate_category("card", Callable(DataValidator, "validate_card"))
	failures += _validate_category("monster", Callable(DataValidator, "validate_enemy"))
	failures += _validate_category("relic", Callable(DataValidator, "validate_relic"))
	failures += _validate_category("equipment", Callable(DataValidator, "validate_equipment"))
	failures += _validate_category("equipment_set", Callable(DataValidator, "validate_equipment_set"))
	failures += _validate_category("base_upgrade", Callable(DataValidator, "validate_base_upgrade"))
	failures += _validate_category("character", Callable(DataValidator, "validate_hero"))
	failures += _validate_category("event", Callable(DataValidator, "validate_event"))
	failures += _validate_category("tool", Callable(DataValidator, "validate_tool"))
	failures += _validate_category("bounty", Callable(DataValidator, "validate_bounty"))
	# Cross-check encounter pools so a typo in RunManager constants fails at
	# startup instead of crashing the player mid-combat in enemy_entity.create().
	failures += validate_encounter_pools()

	if failures > 0:
		push_error("DataValidator: %d validation failure(s). See errors above." % failures)
	else:
		print("DataValidator: all card/enemy/relic/equipment/set JSON files passed schema check.")
	return failures


## Validate every explicit encounter roster against enemy identity and base-HP
## budgets so invalid combinations fail before a battle can load.
static func validate_encounter_pools() -> int:
	var failures = 0
	var enemies: Dictionary = _load_enemy_summaries()
	var normal_sources: Dictionary = {
		"ENCOUNTER_POOLS_OPENING": RunManager.ENCOUNTER_POOLS_OPENING,
		"ENCOUNTER_POOLS_EARLY": RunManager.ENCOUNTER_POOLS_EARLY,
		"ENCOUNTER_POOLS_MID": RunManager.ENCOUNTER_POOLS_MID,
		"ENCOUNTER_POOLS_LATE": RunManager.ENCOUNTER_POOLS_LATE,
	}
	for source_name in normal_sources:
		var pools: Array = normal_sources[source_name]
		var budget: Vector2i = ENCOUNTER_BUDGETS[source_name]
		for pool in pools:
			var total_hp := 0
			var tiers: Array[String] = []
			for enemy_id in pool:
				var id := str(enemy_id)
				if not enemies.has(id):
					push_error(
						(
							"DataValidator: %s references unknown enemy id '%s' — add content/monsters or fix the constant."
							% [source_name, id]
						)
					)
					failures += 1
					continue
				var summary: Dictionary = enemies[id]
				total_hp += int(summary.get("max_health", 0))
				tiers.append(str(summary.get("tier", "")))
			if total_hp < budget.x or total_hp > budget.y:
				push_error(
					"DataValidator: %s encounter %s has %d base HP; expected %d-%d."
					% [source_name, pool, total_hp, budget.x, budget.y]
				)
				failures += 1
			if "elite" in tiers or "boss" in tiers:
				push_error("DataValidator: %s encounter %s contains elite/boss enemies." % [source_name, pool])
				failures += 1
			if "heavy" in tiers and pool.size() != 1:
				push_error("DataValidator: heavy encounter %s must contain exactly one enemy." % [pool])
				failures += 1
			if source_name != "ENCOUNTER_POOLS_OPENING" and "minion" in tiers:
				if pool.size() != 2:
					push_error("DataValidator: post-opening minion encounter %s must contain two enemies." % [pool])
					failures += 1
				elif tiers.count("minion") == 1:
					for tier in tiers:
						if tier != "minion" and tier != "normal":
							push_error("DataValidator: minion support encounter %s must pair with a normal enemy." % [pool])
							failures += 1
				elif tiers.count("minion") != 2:
					push_error("DataValidator: invalid minion composition %s." % [pool])
					failures += 1

	failures += _validate_tier_roster("ELITE_ROSTER", RunManager.ELITE_ROSTER, "elite", enemies)
	failures += _validate_tier_roster("ACT_BOSSES", RunManager.ACT_BOSSES, "boss", enemies)
	return failures


static func _validate_tier_roster(
	source_name: String, roster: Array, required_tier: String, enemies: Dictionary
) -> int:
	var failures := 0
	for enemy_id in roster:
		var id := str(enemy_id)
		if not enemies.has(id):
			push_error("DataValidator: %s references unknown enemy id '%s'." % [source_name, id])
			failures += 1
			continue
		var summary: Dictionary = enemies[id]
		var actual := str(summary.get("tier", ""))
		if actual != required_tier:
			push_error(
				"DataValidator: %s enemy '%s' has tier '%s'; expected '%s'."
				% [source_name, id, actual, required_tier]
			)
			failures += 1
	return failures


static func _load_enemy_summaries() -> Dictionary:
	var result: Dictionary = {}
	for model in MODEL_DB.models("monster"):
		result[model.id] = {
			"tier": str(model.data.get("tier", "")),
			"max_health": int(model.data.get("max_health", 0)),
		}
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
		if not _validate_card_effect(effects[i], prefix, "effect", i):
			ok = false

	# Curse cards must be unplayable; their optional end-of-turn-in-hand penalties
	# reuse the same effect validator as normal card effects.
	if str(data.get("type", "")) == "curse" and not bool(data.get("unplayable", false)):
		push_error('%s: curse cards must set "unplayable": true' % prefix)
		ok = false
	if data.has("end_turn_in_hand"):
		if typeof(data["end_turn_in_hand"]) != TYPE_ARRAY:
			push_error("%s: end_turn_in_hand must be an Array" % prefix)
			ok = false
		else:
			for i in range(data["end_turn_in_hand"].size()):
				if not _validate_card_effect(
					data["end_turn_in_hand"][i], prefix, "end_turn_in_hand", i
				):
					ok = false

	# Optional `polarity` (Yin/Yang hero). Absent = neutral; validate only if present.
	if data.has("polarity") and not str(data["polarity"]) in ALLOWED_CARD_POLARITIES:
		push_error(
			"%s: polarity '%s' not in %s" % [prefix, data["polarity"], ALLOWED_CARD_POLARITIES]
		)
		ok = false

	# Optional `matched_bonus`: effects applied only when the card resolves matched.
	# Same shape/validation as the `effects` array.
	if data.has("matched_bonus"):
		var bonus = data["matched_bonus"]
		if typeof(bonus) != TYPE_ARRAY:
			push_error("%s: matched_bonus must be an Array, got %s" % [prefix, typeof(bonus)])
			ok = false
		else:
			for i in range(bonus.size()):
				if not _validate_card_effect(bonus[i], prefix, "matched_bonus", i):
					ok = false

	# Optional bespoke `upgrade` block (consumed by card_upgrade.resolve). When
	# present it overrides cost/title/description/effects on the upgraded card.
	# Each override field is validated to the same shape as its base counterpart;
	# `upgrade.effects` reuses the same per-effect validator as the main array.
	if data.has("upgrade"):
		var upgrade = data["upgrade"]
		if typeof(upgrade) != TYPE_DICTIONARY:
			push_error("%s: upgrade must be a Dictionary, got %s" % [prefix, typeof(upgrade)])
			ok = false
		else:
			if upgrade.has("cost"):
				if typeof(upgrade["cost"]) != TYPE_INT and typeof(upgrade["cost"]) != TYPE_FLOAT:
					push_error(
						(
							"%s: upgrade.cost must be a number, got %s"
							% [prefix, typeof(upgrade["cost"])]
						)
					)
					ok = false
			if upgrade.has("title") and typeof(upgrade["title"]) != TYPE_STRING:
				push_error("%s: upgrade.title must be a String" % prefix)
				ok = false
			if upgrade.has("description") and typeof(upgrade["description"]) != TYPE_STRING:
				push_error("%s: upgrade.description must be a String" % prefix)
				ok = false
			# upgrade.vars: numeric deltas to the card's vars (unknown names are
			# ModelDb load errors).
			if upgrade.has("vars"):
				if typeof(upgrade["vars"]) != TYPE_DICTIONARY:
					push_error("%s: upgrade.vars must be a Dictionary" % prefix)
					ok = false
				else:
					for var_name in upgrade["vars"]:
						if not _is_whole_number(upgrade["vars"][var_name]):
							push_error("%s: upgrade.vars.%s must be a whole number" % [prefix, var_name])
							ok = false
			if upgrade.has("effects"):
				if typeof(upgrade["effects"]) != TYPE_ARRAY:
					push_error("%s: upgrade.effects must be an Array" % prefix)
					ok = false
				else:
					for i in range(upgrade["effects"].size()):
						if not _validate_card_effect(
							upgrade["effects"][i], prefix, "upgrade.effects", i
						):
							ok = false

	# Coverage warning (non-fatal): a card with neither a bespoke upgrade block nor
	# a formula-bumpable effect resolves to a no-op upgrade. Phase 5 closes the gap.
	if str(data.get("type", "")) != "curse" and not CARD_UPGRADE.is_upgradeable(data):
		push_warning(
			(
				"Card '%s' has no bespoke upgrade and no formula-bumpable effect — upgrade is a no-op"
				% str(data.get("id", source_path))
			)
		)

	# Unknown top-level keys → warn (not fatal) — helps catch typos like "retian"
	var known_keys = REQUIRED_CARD_KEYS + KNOWN_OPTIONAL_CARD_KEYS
	for key in data.keys():
		if not key in known_keys:
			push_warning("%s: unknown top-level key '%s' (typo?)" % [prefix, key])

	return ok


## Validate one card effect dictionary (shared by the `effects` array and the
## Yin/Yang `matched_bonus` array). `label`/`i` build the error location, e.g.
## "effect[2]" or "matched_bonus[0]". Returns true on success.
##
## Field-less effects (exhaust_self, flip_polarity, …) only need a valid `type`;
## the per-type checks below add requirements only for the effects that need them.
static func _validate_card_effect(effect: Variant, prefix: String, label: String, i: int) -> bool:
	var ok := true
	if typeof(effect) != TYPE_DICTIONARY:
		push_error("%s: %s[%d] is not a Dictionary" % [prefix, label, i])
		return false
	if not effect.has("type"):
		push_error("%s: %s[%d] is missing 'type'" % [prefix, label, i])
		return false
	var etype = str(effect["type"])
	if not etype in allowed_card_effect_types():
		push_error(
			"%s: %s[%d] type '%s' not in %s" % [prefix, label, i, etype, allowed_card_effect_types()]
		)
		ok = false
	# Required params from the type's definition must be present and non-empty.
	for param in EFFECT_CATALOG.registry().definition(etype).get("params", []):
		if str(effect.get(param, "")).strip_edges() == "":
			push_error("%s: %s[%d] %s is missing a non-empty '%s'" % [prefix, label, i, etype, param])
			ok = false
	# Discover: `count` (if present) must be a positive int.
	if etype == "discover":
		if effect.has("count") and int(effect.get("count", 0)) <= 0:
			push_error("%s: %s[%d] discover 'count' must be a positive int" % [prefix, label, i])
			ok = false
	# Effects that reference a status name must carry a valid status
	if etype in STATUS_BEARING_EFFECTS:
		if not effect.has("status"):
			push_error("%s: %s[%d] (%s) is missing 'status'" % [prefix, label, i, etype])
			ok = false
		elif not str(effect["status"]) in allowed_status_names():
			push_error(
				(
					"%s: %s[%d] status '%s' not in %s"
					% [prefix, label, i, effect["status"], allowed_status_names()]
				)
			)
			ok = false
	# Stun is enemy-only. Reject applying it to the player.
	if etype == "apply_status_self" and str(effect.get("status", "")) == "stun":
		push_error(
			(
				"%s: %s[%d] tries to apply 'stun' to self — stun is enemy-only"
				% [prefix, label, i]
			)
		)
		ok = false
	# `scale_damage_by_attacks` needs explicit base + per (both ints/floats)
	if etype == "scale_damage_by_attacks":
		for required_key in ["base", "per"]:
			if not effect.has(required_key):
				push_error(
					(
						"%s: %s[%d] (scale_damage_by_attacks) is missing '%s'"
						% [prefix, label, i, required_key]
					)
				)
				ok = false
	# `apply_stun` / `apply_stun_all` need stacks (or amount as fallback)
	if etype in ["apply_stun", "apply_stun_all"]:
		if not effect.has("stacks") and not effect.has("amount"):
			push_error("%s: %s[%d] (%s) needs 'stacks' (or 'amount')" % [prefix, label, i, etype])
			ok = false
	# `deal_damage_str_mult` requires base + numeric mult (damage = base + strength * mult).
	# Godot's JSON parser yields every number as a float, so accept TYPE_INT or
	# a whole-valued TYPE_FLOAT and reject only non-numeric / fractional values.
	if etype == "deal_damage_str_mult":
		if not effect.has("base"):
			push_error("%s: %s[%d] (deal_damage_str_mult) is missing 'base'" % [prefix, label, i])
			ok = false
		if not effect.has("mult"):
			push_error("%s: %s[%d] (deal_damage_str_mult) is missing 'mult'" % [prefix, label, i])
			ok = false
		else:
			var mult_val = effect["mult"]
			var mult_ok: bool = (
				typeof(mult_val) == TYPE_INT
				or (typeof(mult_val) == TYPE_FLOAT and mult_val == floor(mult_val))
			)
			if not mult_ok:
				push_error(
					(
						"%s: %s[%d] (deal_damage_str_mult) 'mult' must be a whole number, got %s"
						% [prefix, label, i, mult_val]
					)
				)
				ok = false
	# Overload is always global. A card may amplify every discharge, but the
	# multiplier must stay a positive whole number so preview and runtime agree.
	if etype == "overload" and effect.has("charge_multiplier"):
		var charge_multiplier = effect["charge_multiplier"]
		var multiplier_ok: bool = (
			typeof(charge_multiplier) == TYPE_INT
			or (
				typeof(charge_multiplier) == TYPE_FLOAT
				and charge_multiplier == floor(charge_multiplier)
			)
		)
		if not multiplier_ok or int(charge_multiplier) < 1:
			push_error(
				"%s: %s[%d] overload 'charge_multiplier' must be a positive whole number"
				% [prefix, label, i]
			)
			ok = false
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

	var tier := str(data["tier"])
	if not tier in ALLOWED_ENEMY_TIERS:
		push_error(
			"%s: tier '%s' is invalid; expected one of %s" % [prefix, tier, ALLOWED_ENEMY_TIERS]
		)
		ok = false

	var pattern = data["action_pattern"]
	if typeof(pattern) != TYPE_ARRAY:
		push_error("%s: action_pattern must be an Array" % prefix)
		return false

	if not _validate_enemy_actions(pattern, prefix, "action"):
		ok = false

	# Optional `phases`: HP-threshold phase transitions (spec A2). Each entry needs
	# `hp_below` in (0,1] and an `action_pattern` (validated like the top-level one);
	# `on_enter` is optional and validated as actions too.
	if data.has("phases"):
		if typeof(data["phases"]) != TYPE_ARRAY:
			push_error("%s: phases must be an Array" % prefix)
			ok = false
		else:
			var phases = data["phases"]
			for pi in range(phases.size()):
				var phase = phases[pi]
				var pprefix := "%s phase[%d]" % [prefix, pi]
				if typeof(phase) != TYPE_DICTIONARY:
					push_error("%s: phase is not a Dictionary" % pprefix)
					ok = false
					continue
				if not phase.has("hp_below"):
					push_error("%s: missing 'hp_below'" % pprefix)
					ok = false
				else:
					var hb := float(phase["hp_below"])
					if hb <= 0.0 or hb > 1.0:
						push_error("%s: hp_below %s must be in (0, 1]" % [pprefix, hb])
						ok = false
				if not phase.has("action_pattern"):
					push_error("%s: missing 'action_pattern'" % pprefix)
					ok = false
				elif typeof(phase["action_pattern"]) != TYPE_ARRAY:
					push_error("%s: action_pattern must be an Array" % pprefix)
					ok = false
				elif not _validate_enemy_actions(phase["action_pattern"], pprefix, "action"):
					ok = false
				if phase.has("on_enter"):
					if typeof(phase["on_enter"]) != TYPE_ARRAY:
						push_error("%s: on_enter must be an Array" % pprefix)
						ok = false
					elif not _validate_enemy_actions(phase["on_enter"], pprefix, "on_enter"):
						ok = false

	return ok


## Validates an array of enemy actions (used by both `action_pattern` and phase
## `on_enter`/`action_pattern`). `label` is used in error messages (e.g. "action"
## or "on_enter"). Returns true when all entries are valid.
static func _validate_enemy_actions(actions: Array, prefix: String, label: String) -> bool:
	var ok := true
	for i in range(actions.size()):
		var action = actions[i]
		if typeof(action) != TYPE_DICTIONARY:
			push_error("%s: %s[%d] is not a Dictionary" % [prefix, label, i])
			ok = false
			continue
		if not action.has("type"):
			push_error("%s: %s[%d] is missing 'type'" % [prefix, label, i])
			ok = false
			continue
		var atype = str(action["type"])
		if not atype in ALLOWED_ENEMY_ACTION_TYPES:
			push_error(
				(
					"%s: %s[%d] type '%s' not in %s"
					% [prefix, label, i, atype, ALLOWED_ENEMY_ACTION_TYPES]
				)
			)
			ok = false
		if atype in STATUS_BEARING_ACTIONS:
			if not action.has("status"):
				push_error("%s: %s[%d] (%s) is missing 'status'" % [prefix, label, i, atype])
				ok = false
			elif not str(action["status"]) in allowed_status_names():
				push_error(
					(
						"%s: %s[%d] status '%s' not in %s"
						% [prefix, label, i, action["status"], allowed_status_names()]
					)
				)
				ok = false
		if atype == "attack_ramp":
			if int(action.get("amount", 0)) <= 0:
				push_error("%s: %s[%d] (attack_ramp) needs a positive 'amount'" % [prefix, label, i])
				ok = false
			if int(action.get("multiplier", 0)) <= 1:
				push_error("%s: %s[%d] (attack_ramp) 'multiplier' must be greater than 1" % [prefix, label, i])
				ok = false
		if atype == "breakable_block" and int(action.get("amount", 0)) <= 0:
			push_error("%s: %s[%d] (breakable_block) needs a positive 'amount'" % [prefix, label, i])
			ok = false
		if atype == "reflective_plating":
			if int(action.get("amount", 0)) <= 0:
				push_error("%s: %s[%d] (reflective_plating) needs positive Block 'amount'" % [prefix, label, i])
				ok = false
			if int(action.get("thorns", 0)) <= 0:
				push_error("%s: %s[%d] (reflective_plating) needs positive 'thorns'" % [prefix, label, i])
				ok = false
		# `buff_self` applies a status to the acting enemy → needs a valid status.
		if atype == "buff_self":
			if not action.has("status"):
				push_error("%s: %s[%d] (buff_self) is missing 'status'" % [prefix, label, i])
				ok = false
			elif not str(action["status"]) in allowed_status_names():
				push_error(
					(
						"%s: %s[%d] (buff_self) status '%s' not in %s"
						% [prefix, label, i, action["status"], allowed_status_names()]
					)
				)
				ok = false
		# `summon` needs a non-empty `enemy_ids` array of strings.
		if atype == "summon":
			if not action.has("enemy_ids"):
				push_error("%s: %s[%d] (summon) is missing 'enemy_ids'" % [prefix, label, i])
				ok = false
			elif typeof(action["enemy_ids"]) != TYPE_ARRAY or action["enemy_ids"].is_empty():
				push_error(
					"%s: %s[%d] (summon) 'enemy_ids' must be a non-empty Array" % [prefix, label, i]
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
	# Escape hatch: a relic may name its own listener script.
	if data.has("script") and not ResourceLoader.exists(str(data["script"])):
		push_error("%s: script '%s' does not exist" % [prefix, data["script"]])
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
		# Effect `type` (when present) must be a handled relic effect type.
		if effect.has("type") and not str(effect["type"]) in ALLOWED_RELIC_EFFECT_TYPES:
			push_error(
				(
					"%s: effect[%d] type '%s' not in %s"
					% [prefix, i, effect["type"], ALLOWED_RELIC_EFFECT_TYPES]
				)
			)
			ok = false
	return ok


## Validate a single tool JSON dictionary (one-time consumable). Effects reuse the
## card effect handlers; `target` is enemy/self/none. Returns true on success.
static func validate_tool(data: Dictionary, source_path: String) -> bool:
	var prefix := "Tool '%s'" % source_path
	var ok := true
	for key in REQUIRED_TOOL_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false
	if data.has("target") and not str(data["target"]) in ALLOWED_TOOL_TARGETS:
		push_error("%s: target '%s' not in %s" % [prefix, data["target"], ALLOWED_TOOL_TARGETS])
		ok = false
	if typeof(data.get("effects", null)) == TYPE_ARRAY:
		for i in range(data["effects"].size()):
			if not _validate_card_effect(data["effects"][i], prefix, "effects", i):
				ok = false
	return ok


## Validate a single bounty contract JSON dictionary. Returns true on success.
## Shape: { id, title, objective: {type, count}, reward: {caps/scrap/equipment},
## tier [, price] }. Reward must carry at least one entry; currency values are
## positive ints, `equipment` names a shell-drop tier.
static func validate_bounty(data: Dictionary, source_path: String) -> bool:
	var prefix := "Bounty '%s'" % source_path
	var ok := true

	for key in REQUIRED_BOUNTY_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false
	if not ok:
		return false

	if typeof(data["id"]) != TYPE_STRING or str(data["id"]).strip_edges() == "":
		push_error("%s: 'id' must be a non-empty String" % prefix)
		ok = false
	if typeof(data["title"]) != TYPE_STRING or str(data["title"]).strip_edges() == "":
		push_error("%s: 'title' must be a non-empty String" % prefix)
		ok = false

	# objective: { type: allowed_bounty_objectives(), count: int >= 1 }
	var objective = data["objective"]
	if typeof(objective) != TYPE_DICTIONARY:
		push_error("%s: 'objective' must be a Dictionary" % prefix)
		ok = false
	else:
		if not str(objective.get("type", "")) in allowed_bounty_objectives():
			push_error(
				(
					"%s: objective type '%s' not in %s"
					% [prefix, objective.get("type", ""), allowed_bounty_objectives()]
				)
			)
			ok = false
		if not _is_whole_number(objective.get("count")) or int(objective.get("count", 0)) < 1:
			push_error("%s: objective 'count' must be an int >= 1" % prefix)
			ok = false

	# reward: at least one entry; currencies are positive ints, equipment is a tier.
	var reward = data["reward"]
	if typeof(reward) != TYPE_DICTIONARY:
		push_error("%s: 'reward' must be a Dictionary" % prefix)
		ok = false
	elif (reward as Dictionary).is_empty():
		push_error("%s: 'reward' must carry at least one entry" % prefix)
		ok = false
	else:
		for rkey in reward.keys():
			if str(rkey) in ALLOWED_BOUNTY_REWARD_CURRENCIES:
				if not _is_whole_number(reward[rkey]) or int(reward[rkey]) <= 0:
					push_error("%s: reward '%s' must be an int > 0" % [prefix, rkey])
					ok = false
			elif str(rkey) == "equipment":
				if not str(reward[rkey]) in ALLOWED_BOUNTY_EQUIPMENT_TIERS:
					push_error(
						(
							"%s: reward equipment tier '%s' not in %s"
							% [prefix, reward[rkey], ALLOWED_BOUNTY_EQUIPMENT_TIERS]
						)
					)
					ok = false
			else:
				push_error(
					(
						"%s: unknown reward key '%s' (allowed: %s + 'equipment')"
						% [prefix, rkey, ALLOWED_BOUNTY_REWARD_CURRENCIES]
					)
				)
				ok = false

	# Optional legacy `price` (ignored at runtime — taking is free) — still
	# type-checked when present.
	if data.has("price") and (not _is_whole_number(data["price"]) or int(data["price"]) < 0):
		push_error("%s: 'price' must be an int >= 0" % prefix)
		ok = false

	if not str(data["tier"]) in ALLOWED_BOUNTY_TIERS:
		push_error("%s: tier '%s' not in %s" % [prefix, data["tier"], ALLOWED_BOUNTY_TIERS])
		ok = false

	# Unknown top-level keys → warn (helps catch typos)
	for key in data.keys():
		if not key in REQUIRED_BOUNTY_KEYS and not key in OPTIONAL_BOUNTY_KEYS:
			push_warning("%s: unknown top-level key '%s' (typo?)" % [prefix, key])

	return ok


## True when `value` is an int, or a whole-valued float (Godot's JSON parser
## yields every number as a float, so 2.0 must count as the int 2).
static func _is_whole_number(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_INT
		or (typeof(value) == TYPE_FLOAT and float(value) == floor(float(value)))
	)


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
			elif not str(effect["status"]) in allowed_status_names():
				push_error(
					(
						"%s: tier[%d] status '%s' not in %s"
						% [prefix, i, effect["status"], allowed_status_names()]
					)
				)
				ok = false

	# Unknown top-level keys → warn (helps catch typos)
	for key in data.keys():
		if not key in REQUIRED_SET_KEYS:
			push_warning("%s: unknown top-level key '%s' (typo?)" % [prefix, key])

	return ok


# ─── Internal ─────────────────────────────────────────────────────────────────


## Shipped categories must not be empty (fail loud, per the shipped-data rule).
static func _validate_category(category: String, validator: Callable) -> int:
	var models: Array = MODEL_DB.models(category)
	if models.is_empty():
		push_error("DataValidator: no %s content loaded" % category)
		return 1
	var failures = 0
	for model in models:
		if not validator.call(model.data, model.id):
			failures += 1
	return failures


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
	if data.has("animate_idle") and typeof(data["animate_idle"]) != TYPE_BOOL:
		push_error("%s: animate_idle must be a bool" % prefix)
		ok = false
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
