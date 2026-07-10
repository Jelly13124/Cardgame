extends Node

const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var window := CHARACTER_WINDOW.new()
	window.mode = "map"
	add_child(window)
	for _i in range(3):
		await get_tree().process_frame

	_expect(window.custom_minimum_size.x <= 600.0, "character window is no wider than 600 px")
	_expect(
		not _has_label_text(window, tr("UI_EQUIP_ACTIVE_SETS")),
		"character window removes the active-set section"
	)
	_expect(
		not _has_label_text(window, tr("UI_EQUIP_RELICS")),
		"character window removes the relic section"
	)

	var portrait := window.find_child("HeroPortrait", true, false) as TextureRect
	_expect(portrait != null, "character window exposes the cropped HeroPortrait")
	if portrait:
		_expect(
			not _has_panel_ancestor_before(portrait, window),
			"HeroPortrait has no inset black panel around it"
		)

	var grid := window.find_child("BackpackGrid", true, false) as GridContainer
	_expect(grid != null, "character window exposes BackpackGrid")
	if grid:
		_expect(grid.columns == 7, "backpack uses seven columns")
		_expect(grid.get_child_count() == 21, "backpack renders three rows of seven cells")

	window.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[OK] Character window layout contract passed")
		get_tree().quit(0)
		return
	push_error("Character window layout contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _has_label_text(root: Node, target: String) -> bool:
	for child in root.find_children("*", "Label", true, false):
		if (child as Label).text == target:
			return true
	return false


func _has_panel_ancestor_before(node: Node, stop: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != stop:
		if parent is PanelContainer:
			return true
		parent = parent.get_parent()
	return false
