extends Node

const MAP_SCENE = preload("res://run_system/ui/map_scene.tscn")
const BATTLE_SCENE = preload("res://battle_scene/battle_scene.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _capture(MAP_SCENE, "res://tmp/ui-map-runtime.png")
	await _capture(BATTLE_SCENE, "res://tmp/ui-battle-runtime.png")
	get_tree().quit(0)


func _capture(packed: PackedScene, path: String) -> void:
	var scene := packed.instantiate()
	add_child(scene)
	for _i in range(12):
		await get_tree().process_frame
	var player := scene.get_node_or_null("Player")
	if player != null and player.has_method("take_damage"):
		player.call("take_damage", 37, true)
		await get_tree().create_timer(0.65).timeout
	if player != null and player.has_method("add_block"):
		player.call("add_block", 6)
		await get_tree().process_frame
	var enemy_container := scene.get_node_or_null("EnemyContainer")
	if enemy_container != null and enemy_container.get_child_count() > 0:
		var enemy: Node = enemy_container.get_child(0)
		enemy.set(
			"action_pattern",
			[{"type": "attack_status", "amount": 4, "status": "burn", "stacks": 2}]
		)
		enemy.set("_action_index", 0)
		enemy.call("update_intent_display")
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save visual capture %s: %s" % [path, error])
	scene.queue_free()
	for _i in range(3):
		await get_tree().process_frame
