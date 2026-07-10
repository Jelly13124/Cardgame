extends Node

const DATA_VALIDATOR = preload("res://battle_scene/data_validator.gd")
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
	_expect(DATA_VALIDATOR.validate_encounter_pools() == 0, "encounter pool validator accepts the approved pools")

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
