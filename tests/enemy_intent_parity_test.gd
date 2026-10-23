extends Node

## Parity: the number on an enemy's intent badge must equal the damage its
## attack actually deals. Known to fail today (finding S4-01: the intent rounds
## while resolution truncates, and the intent skips damage-reduction relics and
## the act multiplier). Listed in tests/expected_failures.txt until phase 1.
##
## This node stands in for battle_scene (EnemyAI and EnemyEntity read
## `main.player`, `main.combat_engine`, `get_tree().current_scene.player`);
## modify_enemy_attack_damage is delegated to a real battle_scene.gd instance.

const BATTLE_SCENE_SCRIPT = preload("res://battle_scene/battle_scene.gd")
const COMBAT_ENGINE_SCRIPT = preload("res://battle_scene/combat_engine.gd")
const ENEMY_AI_SCRIPT = preload("res://battle_scene/enemy_ai.gd")
const ENEMY_ENTITY_SCRIPT = preload("res://battle_scene/enemy_entity.gd")
const RELIC_EFFECT_SYSTEM = preload("res://battle_scene/relic_effect_system.gd")
const STATUS_SYSTEM = preload("res://battle_scene/status_effect_system.gd")
const ENEMY_DIR := "res://battle_scene/card_info/enemy/"
const ATTACK_TYPES := ["attack", "attack_status", "attack_all"]
const REDUCTION_RELIC := "bulwark_plating"


class FakePlayer:
	extends Node2D
	var status_system = STATUS_SYSTEM.new()
	var health := 999
	var max_health := 999
	var block := 0
	var damage_received := 0

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)

	func get_outgoing_multiplier() -> float:
		return status_system.get_outgoing_multiplier()

	func get_incoming_attack_multiplier() -> float:
		return status_system.get_incoming_attack_multiplier()

	func heal(_amount: int) -> void:
		pass

	func take_damage(amount: int, _silent: bool = false, _tags: Dictionary = {}) -> void:
		damage_received += amount


# battle_scene stand-in surface read by EnemyAI / EnemyEntity / CombatEngine.
var player: FakePlayer
var enemy_container := Node2D.new()
var relic_effect_system = null
var equipment_set_system = null
var is_game_over := false
var combat_engine: Node
var enemy_ai: Node
var _battle_logic: Node

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func show_notification(_text: String, _color: Color = Color.WHITE) -> void:
	pass


func modify_enemy_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	return _battle_logic.modify_enemy_attack_damage(amount, attacker, defender)


func _run() -> void:
	Engine.time_scale = 20.0
	var saved_active: bool = RunManager.is_run_active
	var saved_relics: Array[String] = RunManager.relics.duplicate()
	var saved_act: int = RunManager.current_act
	add_child(enemy_container)
	combat_engine = COMBAT_ENGINE_SCRIPT.new()
	add_child(combat_engine)
	enemy_ai = ENEMY_AI_SCRIPT.new()
	add_child(enemy_ai)
	_battle_logic = BATTLE_SCENE_SCRIPT.new()  # never enters the tree: no _ready
	player = FakePlayer.new()
	add_child(player)
	_battle_logic.player = player

	var mismatches := 0
	for enemy_id in _enemy_ids():
		for action in _attack_actions(enemy_id):
			for vulnerable in [false, true]:
				for weak in [false, true]:
					for relic in [false, true]:
						for act in [1, 2]:
							var result := await _compare(enemy_id, action, vulnerable, weak, relic, act)
							if result[0] != result[1]:
								mismatches += 1
								print(
									"MISMATCH %s:%s amount=%d vulnerable=%s weak=%s relic=%s act=%d intent=%d actual=%d"
									% [enemy_id, action.get("type"), int(action.get("amount", 0)),
										vulnerable, weak, relic, act, result[0], result[1]]
								)

	RunManager.is_run_active = saved_active
	RunManager.relics.clear()
	RunManager.relics.append_array(saved_relics)
	RunManager.current_act = saved_act
	Engine.time_scale = 1.0
	_battle_logic.free()
	if mismatches > 0:
		failures.append("%d intent/actual mismatches" % mismatches)
	if failures.is_empty():
		print("[OK] enemy intent parity")
		get_tree().quit(0)
		return
	print("[FAIL] ", "; ".join(failures))
	get_tree().quit(1)


func _enemy_ids() -> Array:
	var ids: Array = []
	for file_name in DirAccess.get_files_at(ENEMY_DIR):
		if file_name.ends_with(".json"):
			ids.append(file_name.get_basename())
	ids.sort()
	return ids


func _attack_actions(enemy_id: String) -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_DIR + enemy_id + ".json"))
	var actions: Array = []
	if typeof(data) != TYPE_DICTIONARY:
		return actions
	var patterns: Array = [data.get("action_pattern", [])]
	for phase in data.get("phases", []):
		if typeof(phase) == TYPE_DICTIONARY:
			patterns.append(phase.get("action_pattern", []))
	for pattern in patterns:
		for action in pattern:
			if typeof(action) == TYPE_DICTIONARY and str(action.get("type", "")) in ATTACK_TYPES:
				var plain: Dictionary = action.duplicate(true)
				plain.erase("interruptible")  # resolve the hit, not the stun-cancel path
				actions.append(plain)
	return actions


## Returns [intent, actual] for one action under one state combination.
func _compare(enemy_id: String, action: Dictionary, vulnerable: bool, weak: bool, relic: bool, act: int) -> Array:
	RunManager.is_run_active = relic  # relic hooks only read relics during a run
	RunManager.relics.clear()
	if relic:
		RunManager.relics.append(REDUCTION_RELIC)
	RunManager.current_act = act
	_battle_logic.relic_effect_system = RELIC_EFFECT_SYSTEM.new() if relic else null
	if relic:
		_battle_logic.relic_effect_system.setup(_battle_logic)

	player.status_system = STATUS_SYSTEM.new()
	player.damage_received = 0
	if vulnerable:
		player.add_status("vulnerable", 1)

	var enemy = ENEMY_ENTITY_SCRIPT.create(enemy_id)
	enemy_container.add_child(enemy)
	if weak:
		enemy.add_status("weak", 1)

	var intent: int = enemy._compute_display_attack(int(action.get("amount", 0)))
	await enemy_ai._execute_action(enemy, action)
	var actual := player.damage_received

	# The await above resumes inside the enemy's attack_animation_finished
	# emission; let it unwind before releasing the node.
	await get_tree().process_frame
	enemy_container.remove_child(enemy)
	enemy.queue_free()
	return [intent, actual]
