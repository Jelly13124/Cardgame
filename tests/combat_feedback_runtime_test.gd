extends Node

const BATTLE_SCENE = preload("res://battle_scene/battle_scene.tscn")
const FEEDBACK_CONTROLLER = preload("res://battle_scene/combat_feedback_controller.gd")
const ENEMY_ENTITY = preload("res://battle_scene/enemy_entity.gd")

var _failures: PackedStringArray = []
var _profiles: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	for _frame in range(14):
		await get_tree().process_frame

	_expect(battle.player != null, "battle exposes a live player")
	_expect(battle.enemy_container.get_child_count() > 0, "battle spawns an enemy")
	if battle.player == null or battle.enemy_container.get_child_count() == 0:
		_finish()
		return

	var enemy = battle.enemy_container.get_child(0)
	var controller: Node = FEEDBACK_CONTROLLER.ensure(battle)
	controller.feedback_started.connect(
		func(profile: String) -> void: _profiles.append(profile)
	)

	# No-await calls are intentional here. Damage owners promise that logical HP
	# and Block mutate before their first presentation await.
	enemy.health = 30
	enemy.block = 0
	enemy.take_damage(5, false, {"source": "test"})
	_expect(enemy.health == 25, "normal hit mutates HP synchronously")
	await _real_seconds(0.08)

	enemy.block = 5
	var hp_before_block: int = enemy.health
	enemy.take_damage(5, false, {"source": "test"})
	_expect(enemy.health == hp_before_block, "fully blocked hit preserves HP")
	_expect(enemy.block == 0, "fully blocked hit consumes Block synchronously")
	await _real_seconds(0.08)
	await _capture_if_rendered(
		"res://tmp/combat-feedback-blocked-runtime.png", "blocked feedback"
	)

	enemy.health = 30
	enemy.take_damage(
		12,
		false,
		{"source": "test", "heavy": false, "critical": true}
	)
	_expect(enemy.health == 18, "heavy/critical hit mutates HP synchronously")
	await _real_seconds(0.11)
	for _frame in range(2):
		await get_tree().process_frame
	await _capture_if_rendered(
		"res://tmp/combat-feedback-heavy-runtime.png", "heavy feedback"
	)
	await _real_seconds(0.12)

	battle.player.health = 50
	battle.player.block = 0
	battle.player.take_damage(
		12,
		false,
		{"source": "enemy", "heavy": true, "critical": false}
	)
	_expect(battle.player.health == 38, "enemy heavy hit mutates player HP synchronously")
	await _real_seconds(0.11)

	# Let prior floating numbers clear so the kill capture judges the kill tier by
	# itself rather than a stack of earlier test readouts.
	await _real_seconds(0.70)
	var clean_death_count := [0]
	enemy.died.connect(func() -> void: clean_death_count[0] += 1)
	enemy.health = 5
	enemy.block = 0
	enemy.take_damage(20, false, {"source": "test", "heavy": true})
	_expect(enemy.health == 0, "lethal hit mutates HP synchronously")
	await _real_seconds(0.14)
	# In headless mode `_capture_if_rendered()` returns without yielding. Give
	# queue_free() its frame boundary before asserting physical deletion; rendered
	# runs already get this boundary from `frame_post_draw` inside the capture.
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	await _capture_if_rendered("res://tmp/combat-feedback-kill-runtime.png", "kill feedback")
	_expect(not is_instance_valid(enemy), "kill feedback completes before enemy frees")
	_expect(clean_death_count[0] == 1, "lethal hit settles death once")

	var parallel_enemy = ENEMY_ENTITY.create("trash_robot")
	battle.enemy_container.add_child(parallel_enemy)
	var parallel_death_count := [0]
	parallel_enemy.died.connect(func() -> void: parallel_death_count[0] += 1)
	parallel_enemy.health = 20
	parallel_enemy.block = 0
	# Deliberately overlap a non-lethal coroutine with the lethal one. Only the
	# call that captured will_kill may settle rewards/signals/deletion.
	parallel_enemy.take_damage(5, false, {"source": "test"})
	parallel_enemy.take_damage(20, false, {"source": "test", "heavy": true})
	_expect(parallel_enemy.health == 0, "overlapping lethal hit mutates HP synchronously")
	await _real_seconds(0.18)
	var parallel_kill_complete := (
		not is_instance_valid(parallel_enemy) or parallel_enemy.is_queued_for_deletion()
	)
	_expect(parallel_kill_complete, "overlapping kill feedback completes")
	_expect(
		parallel_death_count[0] == 1,
		"overlapping hit coroutines settle death exactly once"
	)
	_expect(
		_profiles == ["normal", "blocked", "heavy", "heavy", "kill", "normal", "kill"],
		"runtime emits four tiers and reuses heavy for enemy hits; got %s" % [_profiles]
	)

	# A boss death ends the encounter and may free its summons on the next frame.
	# AoE must stop at the boss instead of awaiting a soon-to-be-freed add.
	var boss = ENEMY_ENTITY.create("junkyard_tyrant")
	var add = ENEMY_ENTITY.create("scrap_rat")
	battle.enemy_container.add_child(boss)
	battle.enemy_container.add_child(add)
	var add_hp_before: int = add.health
	await battle.combat_engine._apply_effect(
		{"type": "deal_damage_all", "amount": 999, "no_str": true},
		null,
		battle.player,
		1.0,
		null
	)
	_expect(add.health == add_hp_before, "AoE stops after a lethal boss hit")
	if is_instance_valid(add):
		add.queue_free()

	var status_enemy = ENEMY_ENTITY.create("scrap_rat")
	battle.enemy_container.add_child(status_enemy)
	status_enemy.health = 3
	var status_death_count := [0]
	status_enemy.died.connect(func() -> void: status_death_count[0] += 1)
	status_enemy.take_damage(3, false, {"source": "status", "status": "burn"})
	_expect(status_enemy.health == 0, "detached status feedback applies HP synchronously")
	_expect(status_enemy.is_queued_for_deletion(), "lethal status damage settles immediately")
	_expect(status_death_count[0] == 1, "lethal status damage emits death immediately")
	await _real_seconds(0.10)

	var self_cost_death_count := [0]
	battle.player.died.connect(func() -> void: self_cost_death_count[0] += 1)
	battle.player.health = 3
	battle.player.lose_hp(3)
	battle.player.lose_hp(3)
	_expect(self_cost_death_count[0] == 1, "parallel self-cost death emits exactly once")
	battle.queue_free()
	for _frame in range(3):
		await get_tree().process_frame
	_expect(is_equal_approx(Engine.time_scale, 1.0), "leaving battle restores normal time scale")

	_finish()


func _real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _capture_if_rendered(path: String, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var viewport_texture := get_viewport().get_texture()
	var capture_image := viewport_texture.get_image() if viewport_texture else null
	if capture_image:
		var capture_error := capture_image.save_png(ProjectSettings.globalize_path(path))
		_expect(capture_error == OK, "%s runtime capture saves" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("[OK] Combat feedback runtime passed")
		get_tree().quit(0)
		return
	push_error("Combat feedback runtime failed: %s" % "; ".join(_failures))
	get_tree().quit(1)
