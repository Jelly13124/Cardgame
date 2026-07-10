extends Node

const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_tools: Array[String] = RunManager.tool_inventory.duplicate()
	RunManager.tool_inventory.clear()
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#171a19")
	add_child(backdrop)

	var window := CHARACTER_WINDOW.new()
	window.mode = "map"
	add_child(window)
	for _i in range(8):
		await get_tree().process_frame
	window.position = (get_viewport().get_visible_rect().size - window.size) * 0.5
	for _i in range(3):
		await get_tree().process_frame

	if not _save_capture("res://tmp/character-window-runtime-empty-tool.png"):
		get_tree().quit(1)
		return

	window.queue_free()
	for _i in range(3):
		await get_tree().process_frame
	RunManager.tool_inventory.assign(["med_kit"])
	var filled_window := CHARACTER_WINDOW.new()
	filled_window.mode = "map"
	add_child(filled_window)
	for _i in range(8):
		await get_tree().process_frame
	filled_window.position = (get_viewport().get_visible_rect().size - filled_window.size) * 0.5
	for _i in range(3):
		await get_tree().process_frame
	if not _save_capture("res://tmp/character-window-runtime-filled-tool.png"):
		get_tree().quit(1)
		return

	RunManager.tool_inventory.assign(original_tools)
	get_tree().quit(0)


func _save_capture(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Could not save character window capture %s: %s" % [path, error])
		return false
	print("[OK] Character window capture saved: ", absolute_path)
	return true
