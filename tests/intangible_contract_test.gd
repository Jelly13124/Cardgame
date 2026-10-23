extends Node

## Intangible replaces Dodge: each hit deals at most 1 (pipeline tests cover
## that); a stack lasts until the end of the opponent's turn. Checked on the
## real battle scene through TurnManager's turn_ended signal.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn
const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://battle_scene/data_validator.gd
const CARD_DIR := "res://battle_scene/card_info/"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_expect(DATA_VALIDATOR.ALLOWED_STATUS_NAMES.has("intangible"), "Intangible is a known status")
	_expect(not DATA_VALIDATOR.ALLOWED_STATUS_NAMES.has("dodge"), "Dodge is retired")
	var smoke_step: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + "player/smoke_step.json"))
	_expect(str(smoke_step["effects"][0].get("status", "")) == "intangible", "Smoke Step grants Intangible")
	var hound: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + "enemy/chrome_hound.json"))
	var hound_statuses: Array = []
	for action in hound.get("action_pattern", []):
		hound_statuses.append(str(action.get("status", "")))
	_expect(hound_statuses.has("intangible") and not hound_statuses.has("dodge"), "Chrome Hound turns Intangible")

	var battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	for _i in range(4):
		await get_tree().process_frame
	var enemy: Node = battle.enemy_container.get_child(0)
	battle.player.add_status("intangible", 1)
	enemy.add_status("intangible", 1)
	battle.turn_manager.turn_ended.emit("player")
	_expect(battle.player.get_status_stacks("intangible") == 1, "player Intangible lasts through the player's own turn end")
	_expect(enemy.get_status_stacks("intangible") == 0, "enemy Intangible ends with the player's turn")
	battle.turn_manager.turn_ended.emit("enemy")
	_expect(battle.player.get_status_stacks("intangible") == 0, "player Intangible ends with the enemy turn")
	battle.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[OK] intangible contract passed")
		get_tree().quit(0)
		return
	push_error("intangible contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
