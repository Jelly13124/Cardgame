extends Node

const DATA_VALIDATOR = preload("res://battle_scene/data_validator.gd")
const ENEMY_ENTITY_SCRIPT = preload("res://battle_scene/enemy_entity.gd")
const ENEMY_DIR := "res://battle_scene/card_info/enemy/"
const ALLOWED_TIERS := ["minion", "normal", "heavy", "elite", "boss"]
const EXPECTED_TIERS := {
	"ember_wisp": "minion",
	"scrap_shard": "minion",
	"scrap_rat": "minion",
	"acid_spitter": "normal",
	"chrome_hound": "normal",
	"hex_drone": "normal",
	"mortar_cart": "normal",
	"mortar_cart_siege": "normal",
	"riot_hound": "normal",
	"riot_hound_alpha": "normal",
	"slag_walker": "normal",
	"trash_robot": "normal",
	"wasteland_killer": "normal",
	"rust_brute": "heavy",
	"armored_patrol": "elite",
	"chrome_warden": "elite",
	"siege_breaker": "elite",
	"ash_warden": "boss",
	"junkyard_tyrant": "boss",
	"rust_titan": "boss",
}
const EXPECTED_POOLS := {
	"ENCOUNTER_POOLS_OPENING": [["scrap_rat"], ["hex_drone"], ["acid_spitter"]],
	"ENCOUNTER_POOLS_EARLY": [
		["wasteland_killer"],
		["scrap_rat", "scrap_rat"],
		["riot_hound"],
		["mortar_cart"],
		["trash_robot"],
	],
	"ENCOUNTER_POOLS_MID": [
		["riot_hound"],
		["mortar_cart"],
		["slag_walker"],
		["acid_spitter", "scrap_rat"],
		["wasteland_killer", "scrap_rat"],
		["chrome_hound"],
		["riot_hound_alpha"],
	],
	"ENCOUNTER_POOLS_LATE": [
		["riot_hound_alpha"],
		["rust_brute"],
		["mortar_cart", "scrap_rat"],
		["chrome_hound", "scrap_rat"],
		["mortar_cart_siege", "scrap_rat"],
		["slag_walker", "acid_spitter"],
		["riot_hound", "riot_hound"],
	],
}
const BUDGETS := {
	"ENCOUNTER_POOLS_OPENING": Vector2i(12, 18),
	"ENCOUNTER_POOLS_EARLY": Vector2i(20, 30),
	"ENCOUNTER_POOLS_MID": Vector2i(25, 34),
	"ENCOUNTER_POOLS_LATE": Vector2i(34, 50),
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

	var run_script := RunManager.get_script() as Script
	var run_constants: Dictionary = run_script.get_script_constant_map()
	for pool_name in EXPECTED_POOLS:
		_expect(run_constants.has(pool_name), "%s exists" % pool_name)
		if not run_constants.has(pool_name):
			continue
		var actual: Array = run_constants[pool_name]
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
	var dir := DirAccess.open(ENEMY_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_DIR + file_name))
		if typeof(parsed) == TYPE_DICTIONARY:
			out[file_name.get_basename()] = parsed
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
		if pool_name != "ENCOUNTER_POOLS_OPENING" and "minion" in tiers:
			_expect(encounter.size() == 2, "post-opening minion encounter %s has exactly two enemies" % [encounter])
			_expect(tiers.count("minion") == 1 or tiers.count("minion") == 2, "post-opening minion role is valid")


func _test_enemy_identities(enemies: Dictionary) -> void:
	var killer := ENEMY_ENTITY_SCRIPT.create("wasteland_killer")
	for expected_damage in [2, 4, 8, 16, 32]:
		var preview: Dictionary = killer.peek_next_action()
		_expect(str(preview.get("type", "")) == "attack_ramp", "Wasteland Killer uses its ramp attack")
		_expect(int(preview.get("amount", 0)) == expected_damage, "Wasteland Killer intent reaches %d" % expected_damage)
		var consumed: Dictionary = killer.consume_next_action()
		_expect(int(consumed.get("amount", 0)) == expected_damage, "Wasteland Killer executes the displayed %d damage" % expected_damage)
	killer.free()

	var armored := ENEMY_ENTITY_SCRIPT.create("armored_patrol")
	armored.add_breakable_armor(14, "vulnerable", 2)
	armored.take_damage(14, true, {"source": "player"})
	_expect(armored.block == 0, "Armored Patrol's armor can be fully broken")
	_expect(armored.get_status_stacks("vulnerable") == 2, "breaking armor exposes Armored Patrol for two turns")
	armored.free()

	var armored_pattern: Array = enemies.get("armored_patrol", {}).get("action_pattern", [])
	_expect(
		armored_pattern.any(func(action): return str(action.get("type", "")) == "breakable_block"),
		"Armored Patrol exposes a breakable armor window"
	)
	var chrome_pattern: Array = enemies.get("chrome_warden", {}).get("action_pattern", [])
	_expect(
		chrome_pattern.any(func(action): return str(action.get("type", "")) == "reflective_plating"),
		"Chrome Warden uses reflective plating"
	)
	var siege_pattern: Array = enemies.get("siege_breaker", {}).get("action_pattern", [])
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


func _test_selection_bands() -> void:
	var original_act := RunManager.current_act
	var samples := [
		[1, 0, "ENCOUNTER_POOLS_OPENING"],
		[1, 2, "ENCOUNTER_POOLS_EARLY"],
		[1, 4, "ENCOUNTER_POOLS_MID"],
		[1, 8, "ENCOUNTER_POOLS_LATE"],
		[2, 0, "ENCOUNTER_POOLS_MID"],
		[3, 0, "ENCOUNTER_POOLS_LATE"],
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
