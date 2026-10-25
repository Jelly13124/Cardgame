extends Node

## Enemy actions carry no hand-written `label`: the interrupt message uses the
## generated intent text (numbers from the action itself).

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var labelled: Array = []
	for id in MODEL_DB.ids("monster"):
		if JSON.stringify(MODEL_DB.data("monster", id)).contains("\"label\""):
			labelled.append(id)
	_expect(labelled.is_empty(), "no monster action has a hand-written label: %s" % [labelled])

	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(4):
		await get_tree().process_frame
	var enemy = battle.enemy_container.get_child(0)
	var action := {"type": "attack", "amount": 14, "interruptible": true}
	var text: String = battle.enemy_ai.interrupt_message(enemy, action)
	_expect(text.contains(str(enemy.intent_attack_damage(action))), "interrupt text shows the move's damage: %s" % text)
	_expect(not text.contains("\n") and not text.contains(tr("UI_COMBAT_INTENT_TIP_INTERRUPTIBLE")),
		"interrupt text is one line without the 'can be interrupted' tip: %s" % text)
	get_tree().current_scene = null
	battle.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[OK] intent text passed")
		get_tree().quit(0)
		return
	push_error("intent text failed: %s" % "; ".join(failures))
	get_tree().quit(1)
