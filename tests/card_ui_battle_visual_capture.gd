extends Node

const BATTLE_SCENE = preload("res://battle_scene/battle_scene.tscn")
const OUTPUT_PATH = "res://tmp/card-ui-battle-runtime-imagegen-v3.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	RunManager.is_run_active = false
	RunManager.current_hero_id = "cowboy_bill"
	RunManager.current_hero_data = {"card_ui_skin": "cowboy_bill"}
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	for _i in range(45):
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save battle card UI capture: %s" % error)
		get_tree().quit(1)
		return
	get_tree().quit(0)
