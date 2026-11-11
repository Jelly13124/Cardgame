extends Node

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_asset_contract()
	_test_button_states()
	_test_form_controls()
	await _test_tooltip_layers_and_ownership()
	if failures.is_empty():
		print("[OK] shared original UI skin contract")
		get_tree().quit(0)
		return
	push_error("shared UI skin contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_asset_contract() -> void:
	var dimensions := {
		"panel_hard_9slice": Vector2i(96, 96),
		"panel_soft_9slice": Vector2i(96, 96),
		"tooltip_panel_9slice": Vector2i(320, 96),
		"tooltip_shadow_9slice": Vector2i(320, 96),
		"banner_long": Vector2i(652, 162),
		"banner_short": Vector2i(360, 96),
		"divider": Vector2i(256, 8),
		"corner": Vector2i(32, 32),
		"dropdown_9slice": Vector2i(192, 64),
		"dropdown_arrow": Vector2i(32, 32),
		"input_9slice": Vector2i(192, 64),
	}
	for kind in ["primary", "secondary"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			dimensions["button_%s_%s" % [kind, state]] = Vector2i(192, 64)
	for name in ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]:
		dimensions["checkbox_" + name] = Vector2i(32, 32)
	for name in dimensions:
		var texture := T.kit_tex(name)
		_expect(texture != null, "%s is available through the shared theme" % name)
		if texture != null:
			_expect(Vector2i(texture.get_size()) == dimensions[name], "%s keeps its delivery size" % name)

	var panel := T.panel_textured()
	var soft := T.panel_textured("soft")
	_expect(panel.texture.resource_path.ends_with("/panel_hard_9slice.png"), "normal panels use the shared hard skin")
	_expect(soft.texture.resource_path.ends_with("/panel_soft_9slice.png"), "soft panels use the shared paper skin")
	_expect(
		panel.texture_margin_left == 24 and panel.texture_margin_right == 24
		and panel.texture_margin_top == 24 and panel.texture_margin_bottom == 24,
		"shared panel corners keep their native 24 px patches"
	)
	panel.content_margin_left = 3
	_expect(T.panel_textured().content_margin_left == 16, "customizing one panel leaves other callers independent")


func _test_button_states() -> void:
	for primary in [true, false]:
		var paths: Array[String] = []
		var pixels: Array[PackedByteArray] = []
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := T.ll_button(state) if primary else T.ll_button_olive(state)
			_expect(box is StyleBoxTexture and box.texture != null, "%s has a textured button state" % state)
			if box.texture == null:
				continue
			paths.append(box.texture.resource_path)
			var data := box.texture.get_image().get_data()
			_expect(not pixels.has(data), "%s uses separately drawn button feedback" % state)
			pixels.append(data)
			_expect(
				box.texture_margin_left == 20 and box.texture_margin_right == 20
				and box.texture_margin_top == 16 and box.texture_margin_bottom == 16,
				"button feedback preserves 20×16 patches"
			)
		_expect(paths.size() == 4 and _unique_count(paths) == 4, "four interaction states resolve to four original textures")
	var choice := Button.new()
	T.apply_choice_button(choice)
	_expect(choice.get_theme_stylebox("disabled") is StyleBoxTexture, "shared decisions provide the disabled state")
	_expect_thin_outline(choice.get_theme_stylebox("focus"), 2, "choice focus")  # bare-ok: Godot button theme state
	choice.free()


func _test_form_controls() -> void:
	var input := T.input_box()
	var invalid := T.input_box(true)
	_expect(input.texture == invalid.texture, "invalid input preserves the same field geometry")
	_expect(input.modulate_color != invalid.modulate_color, "invalid seed input stays visibly distinct")
	var picker := OptionButton.new()
	var popup := picker.get_popup()
	var original_panel := popup.get_theme_stylebox("panel")
	var original_hover := popup.get_theme_stylebox("hover")
	var original_font_size := popup.get_theme_font_size("font_size")
	T.apply_dropdown_theme(picker)
	_expect(picker.get_theme_icon("arrow").get_size() == Vector2(32, 32), "dropdown keeps its original separate arrow")
	_expect(picker.get_theme_stylebox("disabled") is StyleBoxTexture, "dropdown has a shared disabled surface")
	var popup_panel := popup.get_theme_stylebox("panel") as StyleBoxTexture
	var popup_hover := popup.get_theme_stylebox("hover") as StyleBoxTexture
	_expect(
		popup_panel != null and popup_panel.texture.resource_path.ends_with("/panel_hard_9slice.png")
		and popup_panel.get_minimum_size() == original_panel.get_minimum_size(),
		"opened dropdown uses the common panel while preserving its menu padding"
	)
	_expect(
		popup_hover != null and popup_hover.texture.resource_path.ends_with("/button_secondary_hover.png")
		and popup_hover.get_minimum_size() == original_hover.get_minimum_size()
		and popup.get_theme_font_size("font_size") == original_font_size,
		"opened dropdown uses the common hover state with its original item spacing and type size"
	)
	_expect(popup.get_theme_color("font_hover_color") == T.LEATHER_DARK, "dropdown hover text keeps dark ink contrast on the light state")
	picker.free()
	var checkbox := CheckBox.new()
	T.apply_checkbox_theme(checkbox)
	for icon in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		_expect(checkbox.get_theme_icon(icon).get_size() == Vector2(32, 32), "checkbox keeps the 32 px %s art" % icon)
	_expect_thin_outline(checkbox.get_theme_stylebox("focus"), 2, "checkbox focus")  # bare-ok: Godot button theme state
	checkbox.free()


func _test_tooltip_layers_and_ownership() -> void:
	Tooltip.show("[b]废土物资[/b]\n在这里核对同一套皮肤的提示文本与边缘留白。", Vector2(1910, 90), 101)
	for frame in range(3):
		await get_tree().process_frame
	var panel := Tooltip.get("_panel") as PanelContainer
	var shadow := Tooltip.get("_shadow") as NinePatchRect
	var label := Tooltip.get("_label") as RichTextLabel
	_expect(panel.visible and shadow.visible, "tooltip main surface and shadow appear together")
	_expect(shadow.get_parent() == panel.get_parent() and shadow.get_index() < panel.get_index(), "tooltip shadow is a separate lower layer")
	_expect(shadow.size == panel.size, "tooltip layers retain the same measured size")
	_expect(panel.size.x >= 400 and panel.size.y >= 118, "tooltip starts at the reference 400×118 footprint")
	_expect(label.get_theme_font_size("normal_font_size") == 22, "tooltip hierarchy uses 22 px body type")
	var margins := panel.get_node("ContentMargins") as MarginContainer
	_expect(
		margins.get_theme_constant("margin_left") == 22
		and margins.get_theme_constant("margin_top") == 16
		and margins.get_theme_constant("margin_right") == 45
		and margins.get_theme_constant("margin_bottom") == 28,
		"tooltip keeps the reference text insets"
	)
	var viewport := get_viewport().get_visible_rect()
	_expect(viewport.encloses(panel.get_global_rect()), "tooltip flips and clamps near the viewport edge")
	_expect(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and shadow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tooltip layers preserve click-through behavior")
	Tooltip.show("新提示", Vector2(960, 500), 202)
	Tooltip.hide_if_owner(101)
	_expect(panel.visible and shadow.visible, "a stale owner cannot dismiss the new tooltip")
	Tooltip.hide_if_owner(202)
	_expect(not panel.visible and not shadow.visible, "current owner dismisses both tooltip layers")
	var owner := Button.new()
	add_child(owner)
	Tooltip.bind_hover(owner, "Initial hint")
	owner.mouse_entered.emit()
	await get_tree().process_frame
	Tooltip.bind_hover(owner, "Updated hint")
	_expect(label.text == "Updated hint" and panel.visible and shadow.visible, "rebinding the active owner refreshes both layers immediately")
	Tooltip.bind_hover(owner, "")
	_expect(not panel.visible and not shadow.visible, "clearing the active reason immediately hides both layers")
	_expect(owner.tooltip_text.is_empty(), "binding keeps the native tooltip disabled")
	Tooltip.bind_hover(owner, "Final hint")
	owner.mouse_entered.emit()
	_expect(label.text == "Final hint" and panel.visible, "the same control can show a fresh reason after a clear")
	owner.queue_free()
	await get_tree().process_frame
	_expect(not panel.visible and not shadow.visible, "freeing the active owner dismisses both layers")



func _expect_thin_outline(style: StyleBox, maximum_width: int, description: String) -> void:
	var painted_width := INF
	var clear_center := false
	if style is StyleBoxFlat:
		var flat := style as StyleBoxFlat
		clear_center = is_zero_approx(flat.bg_color.a)
		painted_width = maxf(maxf(flat.get_border_width(SIDE_LEFT), flat.get_border_width(SIDE_RIGHT)),
			maxf(flat.get_border_width(SIDE_TOP), flat.get_border_width(SIDE_BOTTOM)))
	elif style is StyleBoxTexture:
		var texture := style as StyleBoxTexture
		clear_center = not texture.draw_center
		painted_width = maxf(maxf(texture.texture_margin_left, texture.texture_margin_right),
			maxf(texture.texture_margin_top, texture.texture_margin_bottom))
	_expect(clear_center and painted_width <= maximum_width,
		"%s stays a thin %d px outline without opaque patches over content" % [description, maximum_width])


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("[FAIL] ", message)
