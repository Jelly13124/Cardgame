extends Node

## Ascension levels are named content (content/ascension): rules ask
## RunManager.has_ascension(id) / ascension_param(id, key) instead of numeric
## thresholds, and the A3 first-turn energy penalty is a combat listener.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ENEMY_ENTITY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_expect(MODEL_DB.ids("ascension").size() == 6, "six named ascension rules")
	RunManager.ascension = 2
	_expect(RunManager.has_ascension("base:a1_tough_enemies"), "A1 rule active at 2")
	_expect(not RunManager.has_ascension("base:a3_cold_start"), "A3 rule inactive at 2")
	RunManager.ascension = 3
	_expect(RunManager.has_ascension("base:a3_cold_start"), "A3 rule active at 3")
	_expect(int(RunManager.ascension_param("base:a3_cold_start", "energy", 0)) == 1, "A3 energy param")

	RunManager.ascension = 2
	var enemy = ENEMY_ENTITY.create("base:scrap_rat")
	var base_hp := int(MODEL_DB.data("monster", "base:scrap_rat")["max_health"])
	var expected := RunManager.scale_enemy_hp(int(round(base_hp * 1.2)), "base:scrap_rat")
	_expect(enemy.max_health == expected, "A2 enemy HP = base x1.2 (%d vs %d)" % [enemy.max_health, expected])
	enemy.free()

	RunManager.start_new_run("base:cowboy_bill", [], 3, "ASCTEST001")
	_expect(RunManager.max_health == 50 - 10, "A3 max HP penalty (got %d)" % RunManager.max_health)
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(30):
		await get_tree().process_frame
	_expect(battle.player.energy == battle.player.max_energy - 1, "A3 first turn starts with 1 less energy (%d/%d)" % [battle.player.energy, battle.player.max_energy])
	get_tree().current_scene = null
	battle.queue_free()
	await get_tree().process_frame
	RunManager.is_run_active = false
	RunManager.ascension = 0
	RunManager.clear_run_save()

	if failures.is_empty():
		print("[OK] ascension contract passed")
		get_tree().quit(0)
		return
	push_error("ascension contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
