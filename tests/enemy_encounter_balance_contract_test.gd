extends Node

const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://core/content/data_validator.gd
const ENEMY_ENTITY_SCRIPT = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ALLOWED_TIERS := ["minion", "normal", "heavy", "elite", "boss"]
const EXPECTED_TIERS := {
	"base:ember_wisp": "minion",
	"base:scrap_shard": "minion",
	"base:scrap_rat": "minion",
	"base:acid_spitter": "normal",
	"base:chrome_hound": "normal",
	"base:hex_drone": "normal",
	"base:mortar_cart": "normal",
	"base:mortar_cart_siege": "normal",
	"base:riot_hound": "normal",
	"base:riot_hound_alpha": "normal",
	"base:slag_walker": "normal",
	"base:trash_robot": "normal",
	"base:wasteland_killer": "normal",
	"base:rust_brute": "heavy",
	"base:armored_patrol": "elite",
	"base:chrome_warden": "elite",
	"base:siege_breaker": "elite",
	"base:ash_warden": "boss",
	"base:junkyard_tyrant": "boss",
	"base:rust_titan": "boss",
}
const EXPECTED_POOLS := {
	"opening": [["base:scrap_rat"], ["base:hex_drone"], ["base:acid_spitter"]],
	"early": [
		["base:wasteland_killer"],
		["base:scrap_rat", "base:scrap_rat"],
		["base:riot_hound"],
		["base:mortar_cart"],
		["base:trash_robot"],
	],
	"mid": [
		["base:riot_hound"],
		["base:mortar_cart"],
		["base:slag_walker"],
		["base:acid_spitter", "base:scrap_rat"],
		["base:wasteland_killer", "base:scrap_rat"],
		["base:chrome_hound"],
		["base:riot_hound_alpha"],
	],
	"late": [
		["base:riot_hound_alpha"],
		["base:rust_brute"],
		["base:mortar_cart", "base:scrap_rat"],
		["base:chrome_hound", "base:scrap_rat"],
		["base:mortar_cart_siege", "base:scrap_rat"],
		["base:slag_walker", "base:acid_spitter"],
		["base:riot_hound", "base:riot_hound"],
	],
}
const BUDGETS := {
	"opening": Vector2i(12, 18),
	"early": Vector2i(20, 30),
	"mid": Vector2i(25, 34),
	"late": Vector2i(34, 50),
}

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var enemies := _load_enemies()
	_expect(enemies.size() == 20, "enemy catalog contains exactly 20 JSON entries")
	for enemy_id in EXPECTED_TIERS:
		_expect(enemies.has(enemy_id), "%s exists" % enemy_id)
		if enemies.has(enemy_id):
			var tier := str(enemies[enemy_id].get("tier", ""))
			_expect(tier in ALLOWED_TIERS, "%s has a legal tier" % enemy_id)
			_expect(tier == EXPECTED_TIERS[enemy_id], "%s has the approved tier" % enemy_id)

	# Act 1 holds every band (content/acts/act1.json); later acts reuse them.
	var bands := {}
	for band in MODEL_DB.data("act", "base:act1").get("encounters", []):
		bands[str(band.get("name", ""))] = band.get("pool", []).map(
			func(e): return MODEL_DB.data("encounter", str(e)).get("monsters", [])
		)
	for pool_name in EXPECTED_POOLS:
		_expect(bands.has(pool_name), "act 1 has the %s band" % pool_name)
		if not bands.has(pool_name):
			continue
		var actual: Array = bands[pool_name]
		_expect(actual == EXPECTED_POOLS[pool_name], "%s matches the approved roster" % pool_name)
		_validate_pool(pool_name, actual, enemies)

	var validator := DATA_VALIDATOR.new()
	var validator_constants: Dictionary = validator.get_script().get_script_constant_map()
	var required: Array = validator_constants.get("REQUIRED_ENEMY_KEYS", [])
	_expect("tier" in required, "enemy schema requires tier")
	var allowed: Array = validator_constants.get("ALLOWED_ENEMY_TIERS", [])
	_expect(allowed == ALLOWED_TIERS, "validator exposes the exact allowed enemy tiers")
	var action_types: Array = validator_constants.get("ALLOWED_ENEMY_ACTION_TYPES", [])
	for action_type in ["attack_ramp", "breakable_block", "reflective_plating"]:
		_expect(action_type in action_types, "enemy schema allows %s" % action_type)
	_expect(DATA_VALIDATOR.validate_encounter_pools() == 0, "encounter pool validator accepts the approved pools")
	_test_enemy_identities(enemies)
	_test_selection_bands()

	if failures.is_empty():
		print("[OK] Enemy tier and encounter balance contract passed")
		get_tree().quit(0)
		return
	push_error("Enemy encounter balance contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _load_enemies() -> Dictionary:
	var out := {}
	for model in MODEL_DB.models("monster"):
		out[model.id] = model.data
	return out


func _validate_pool(pool_name: String, pools: Array, enemies: Dictionary) -> void:
	var budget: Vector2i = BUDGETS[pool_name]
	for encounter in pools:
		var hp := 0
		var tiers: Array[String] = []
		for enemy_id in encounter:
			var data: Dictionary = enemies.get(str(enemy_id), {})
			hp += int(data.get("max_health", 0))
			tiers.append(str(data.get("tier", "")))
		_expect(hp >= budget.x and hp <= budget.y, "%s encounter %s stays within HP budget" % [pool_name, encounter])
		_expect(not "elite" in tiers and not "boss" in tiers, "%s contains no elite or boss" % str(encounter))
		if "heavy" in tiers:
			_expect(encounter.size() == 1, "heavy encounter %s is solo" % [encounter])
		if pool_name != "opening" and "minion" in tiers:
			_expect(encounter.size() == 2, "post-opening minion encounter %s has exactly two enemies" % [encounter])
			_expect(tiers.count("minion") == 1 or tiers.count("minion") == 2, "post-opening minion role is valid")


func _test_enemy_identities(enemies: Dictionary) -> void:
	var killer := ENEMY_ENTITY_SCRIPT.create("base:wasteland_killer")
	for expected_damage in [2, 4, 8, 16, 32]:
		var preview: Dictionary = killer.peek_next_action()
		_expect(str(preview.get("type", "")) == "attack_ramp", "Wasteland Killer uses its ramp attack")
		_expect(int(preview.get("amount", 0)) == expected_damage, "Wasteland Killer intent reaches %d" % expected_damage)
		var consumed: Dictionary = killer.creature.moves.consume()
		_expect(int(consumed.get("amount", 0)) == expected_damage, "Wasteland Killer executes the displayed %d damage" % expected_damage)
	killer.free()

	var armored := ENEMY_ENTITY_SCRIPT.create("base:armored_patrol")
	armored.creature.add_block(14)
	armored.creature.arm_breakable_armor("vulnerable", 2)
	armored.creature.apply_damage(14, true)
	_expect(armored.block == 0, "Armored Patrol's armor can be fully broken")
	_expect(armored.get_status_stacks("vulnerable") == 2, "breaking armor exposes Armored Patrol for two turns")
	armored.free()

	var armored_pattern: Array = enemies.get("base:armored_patrol", {}).get("action_pattern", [])
	_expect(
		armored_pattern.any(func(action): return str(action.get("type", "")) == "breakable_block"),
		"Armored Patrol exposes a breakable armor window"
	)
	var chrome_pattern: Array = enemies.get("base:chrome_warden", {}).get("action_pattern", [])
	_expect(
		chrome_pattern.any(func(action): return str(action.get("type", "")) == "reflective_plating"),
		"Chrome Warden uses reflective plating"
	)
	var siege_pattern: Array = enemies.get("base:siege_breaker", {}).get("action_pattern", [])
	var telegraph_index := -1
	var payoff_index := -1
	for i in range(siege_pattern.size()):
		var action: Dictionary = siege_pattern[i]
		if str(action.get("type", "")) == "telegraph":
			telegraph_index = i
		if bool(action.get("interruptible", false)) and bool(action.get("heavy", false)):
			payoff_index = i
	_expect(telegraph_index >= 0, "Siege Breaker visibly telegraphs its siege round")
	_expect(payoff_index == telegraph_index + 1, "Siege Breaker's interruptible heavy hit immediately follows its telegraph")
	_expect_vulnerable_duration(enemies, "base:slag_walker", 2)
	_expect_vulnerable_duration(enemies, "base:mortar_cart_siege", 3)
	_expect_vulnerable_duration(enemies, "base:rust_titan", 3)
	_expect_vulnerable_duration(enemies, "base:ash_warden", 3)
	var ash_phases: Array = enemies.get("base:ash_warden", {}).get("phases", [])
	_expect(not ash_phases.is_empty(), "Ash Warden keeps its second phase")
	if not ash_phases.is_empty():
		_expect_status_duration(
			ash_phases[0].get("action_pattern", []),
			"vulnerable",
			4,
			"Ash Warden phase-two Vulnerable survives its block and summon setup"
		)


func _expect_vulnerable_duration(enemies: Dictionary, enemy_id: String, expected: int) -> void:
	var pattern: Array = enemies.get(enemy_id, {}).get("action_pattern", [])
	_expect_status_duration(
		pattern,
		"vulnerable",
		expected,
		"%s Vulnerable lasts until its intended payoff attack" % enemy_id
	)


func _expect_status_duration(
	pattern: Array, status_id: String, expected: int, message: String
) -> void:
	for action in pattern:
		if (
			str(action.get("type", "")) == "attack_status"
			and str(action.get("status", "")) == status_id
		):
			_expect(int(action.get("stacks", 0)) == expected, message)
			return
	_expect(false, "%s (status action missing)" % message)


func _test_selection_bands() -> void:
	var original_act := RunManager.current_act
	var samples := [
		[1, 0, "opening"],
		[1, 2, "early"],
		[1, 4, "mid"],
		[1, 8, "late"],
		[2, 0, "mid"],
		[3, 0, "late"],
	]
	for sample in samples:
		RunManager.current_act = int(sample[0])
		var floor_idx := int(sample[1])
		var pool_name := str(sample[2])
		var allowed: Array = EXPECTED_POOLS[pool_name]
		for _i in range(24):
			var encounter := RunManager.select_encounter("enemy", floor_idx)
			_expect(
				allowed.has(encounter),
				"act %d floor %d selects only from %s" % [RunManager.current_act, floor_idx, pool_name]
			)
	RunManager.current_act = original_act
