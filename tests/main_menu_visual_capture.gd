extends Node

const MAIN_MENU = preload("res://run_system/ui/main_menu.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_language := Settings.language
	Settings.language = "zh"
	var menu := MAIN_MENU.instantiate()
	add_child(menu)
	Input.warp_mouse(Vector2(2, 2))
	for _i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://tmp/main-menu-runtime.png"))
	Settings.language = original_language
	if error != OK:
		push_error("Could not save main menu capture: %s" % error)
		get_tree().quit(1)
		return
	get_tree().quit(0)
