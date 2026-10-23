extends Node

## Parity: the number on an enemy's intent badge must equal the damage its
## attack actually deals (finding S4-01). Both run the shared pipeline; this
## test keeps it that way across Vulnerable, Weak, damage-reduction relics
## (including a once-per-combat one, checked on a second attack), the act
## damage multiplier and Intangible.

const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd
const ENEMY_AI_SCRIPT = preload("uid://4dtggr10j47s")  # res://battle_scene/enemy_ai.gd
const ENEMY_ENTITY_SCRIPT = preload("uid://qtp7jvjqfbou")  # res://battle_scene/enemy_entity.gd
const RELIC_EFFECT_SYSTEM = preload("uid://b4d2o08tofxey")  # res://battle_scene/relic_effect_system.gd
const ENEMY_DIR := "res://battle_scene/card_info/enemy/"
const ATTACK_TYPES := ["attack", "attack_status", "attack_all", "attack_ramp"]
const REDUCTION_RELICS := ["bulwark_plating", "signal_jammer"]

var failures: PackedStringArray = []
var battle


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 60.0
	var saved_active: bool = RunManager.is_run_active
	var saved_relics: Array[String] = RunManager.relics.duplicate()
	var saved_act: int = RunManager.current_act

	var mismatches := 0
	var compared := 0
	for enemy_id in _enemy_ids():
		for action in _attack_actions(enemy_id):
			for vulnerable in [false, true]:
				for weak in [false, true]:
					for relic in [false, true]:
						for act in [1, 2]:
							for intangible in [false, true]:
								var state := [vulnerable, weak, relic, act, intangible]
								for pair in await _compare(enemy_id, action, state):
									compared += 1
									if pair[0] != pair[1]:
										mismatches += 1
										print(
											"MISMATCH %s:%s amount=%d vulnerable=%s weak=%s relic=%s act=%d intangible=%s intent=%d actual=%d"
											% ([enemy_id, action.get("type"), int(action.get("amount", 0))] + state + pair)
										)

	RunManager.is_run_active = saved_active
	RunManager.relics.clear()
	RunManager.relics.append_array(saved_relics)
	RunManager.current_act = saved_act
	Engine.time_scale = 1.0
	print("compared %d intent/actual pairs" % compared)
	if compared < 200:
		failures.append("expected at least 200 intent/actual pairs (got %d)" % compared)
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


## Returns [[intent, actual], [intent, actual]] for two attacks in a row
## (the second checks once-per-combat relics are spent by the real hit only).
func _compare(enemy_id: String, action: Dictionary, state: Array) -> Array:
	RunManager.is_run_active = state[2]  # relic hooks only read relics during a run
	RunManager.relics.clear()
	if state[2]:
		RunManager.relics.append_array(REDUCTION_RELICS)
	RunManager.current_act = state[3]

	if battle and is_instance_valid(battle):
		battle.free()
	battle = FAKE_BATTLE.new()
	add_child(battle)
	if state[2]:
		battle.relic_effect_system = RELIC_EFFECT_SYSTEM.new()
		battle.relic_effect_system.setup(battle)
	battle.setup()
	var enemy_ai = ENEMY_AI_SCRIPT.new()
	battle.add_child(enemy_ai)
	battle.enemy_ai = enemy_ai

	var player = battle.player
	if state[0]:
		player.add_status("vulnerable", 2)
	if state[4]:
		player.add_status("intangible", 2)
	var enemy = ENEMY_ENTITY_SCRIPT.create(enemy_id)
	battle.enemy_container.add_child(enemy)
	battle.combat_commands.attach(enemy)
	if state[1]:
		enemy.add_status("weak", 2)

	var pairs: Array = []
	for _attack in range(2):
		var intent: int = enemy.intent_attack_damage(action)
		var before: int = player.damage_received
		await enemy_ai.execute_action(enemy, action)
		pairs.append([intent, player.damage_received - before])
	# The await above resumes inside the enemy's attack_animation_finished
	# emission; let it unwind before releasing the node.
	await get_tree().process_frame
	return pairs
