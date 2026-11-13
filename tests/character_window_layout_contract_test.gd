extends Node

const CHARACTER_WINDOW = preload("uid://ba0f3y5ua1p6o")  # res://ui/windows/character_window.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var original_backpack := RunManager.backpack.duplicate(true)
	RunManager.backpack = [{"kind": "gold", "amount": 100}, {"kind": "gold", "amount": 64}]
	RunManager.backpack.resize(RunManager.MAX_INVENTORY)
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
		_test_safe_resource_labels(grid)

	var strip := window.find_child("RunAttributeStrip", true, false)
	_expect(strip != null, "run character window has a named attribute strip")
	if strip != null:
		for attribute in ["STRENGTH", "CONSTITUTION", "INTELLIGENCE", "LUCK", "CHARM"]:
			_expect(_has_label_text(strip, tr("UI_EQUIP_ATTR_SHORT_" + attribute)),
				"attribute %s has a visible localized label" % attribute)

	window.queue_free()
	await get_tree().process_frame
	RunManager.backpack = original_backpack
	if failures.is_empty():
		print("[OK] Character window layout contract passed")
		get_tree().quit(0)
		return
	push_error("Character window layout contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_safe_resource_labels(grid: GridContainer) -> void:
	for index in range(2):
		var cell := grid.get_child(index) as Control
		_expect(cell.size == Vector2(64, 64), "safe currency cells retain their 64 px footprint")
		var border := cell.get_node_or_null("SafeCellBorder") as Panel
		_expect(border != null, "safe currency cells retain the survival-state marker")
		if border == null:
			continue
		var clear_rect := _outline_clear_rect(border.get_theme_stylebox("panel"), border.get_global_rect())
		for label_name in ["ResourceKind", "ResourceAmount"]:
			var label := cell.find_child(label_name, true, false) as Label
			_expect(label != null, "currency cell exposes %s" % label_name)
			if label != null:
				_expect(clear_rect.encloses(_label_text_rect(label)),
					"safe marker leaves the complete %s text readable" % label.text)
		var amount := cell.find_child("ResourceAmount", true, false) as Label
		_expect(amount != null and amount.text == ("x100" if index == 0 else "x64"),
			"currency stack amount preserves every digit")


func _outline_clear_rect(style: StyleBox, bounds: Rect2) -> Rect2:
	var edges := Vector4.ZERO
	if style is StyleBoxFlat:
		var flat := style as StyleBoxFlat
		_expect(is_zero_approx(flat.bg_color.a), "safe marker keeps a transparent center")
		edges = Vector4(flat.get_border_width(SIDE_LEFT), flat.get_border_width(SIDE_TOP),
			flat.get_border_width(SIDE_RIGHT), flat.get_border_width(SIDE_BOTTOM))
	elif style is StyleBoxTexture:
		var texture := style as StyleBoxTexture
		_expect(not texture.draw_center, "safe marker keeps a transparent center")
		edges = Vector4(texture.texture_margin_left, texture.texture_margin_top,
			texture.texture_margin_right, texture.texture_margin_bottom)
	else:
		_expect(false, "safe marker exposes measurable outline geometry")
	return bounds.grow_individual(-edges.x, -edges.y, -edges.z, -edges.w)


func _label_text_rect(label: Label) -> Rect2:
	var text_size := label.get_theme_font("font").get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
	var origin := label.global_position + Vector2((label.size.x - text_size.x) * 0.5, 0)
	return Rect2(origin, text_size)


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
