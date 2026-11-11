extends Node

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_asset_contract()
	_test_button_states()
	await _test_layered_action_buttons()
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
		for layer in ["base", "outline"]:
			dimensions["button_%s_%s" % [kind, layer]] = Vector2i(320, 96)
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
		var tints: Array[Color] = []
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := T.ll_button(state) if primary else T.ll_button_olive(state)
			_expect(box is StyleBoxTexture and box.texture != null, "%s has a textured button state" % state)
			if box.texture == null:
				continue
			paths.append(box.texture.resource_path)
			var tint := box.modulate_color
			_expect(not tints.has(tint), "%s stays visibly distinct on the shared base" % state)
			tints.append(tint)
			_expect(
				box.texture_margin_left == 20 and box.texture_margin_right == 20
				and box.texture_margin_top == 16 and box.texture_margin_bottom == 16,
				"button feedback preserves 20 by 16 px patches"
			)
		_expect(paths.size() == 4 and _unique_count(paths) == 1, "four legacy states reuse one original base without changing its silhouette")
	var choice := Button.new()
	T.apply_choice_button(choice)
	_expect(choice.get_theme_stylebox("disabled") is StyleBoxEmpty, "shared decisions leave their background to the visual layers")
	var choice_visual := choice.get_node_or_null("ActionVisuals")
	_expect(choice_visual != null and choice_visual.get("role") == "list", "shared decisions use the fixed-layout list role")
	choice.free()


func _test_layered_action_buttons() -> void:
	var theme := T.new()
	var has_action_button := false
	for method in theme.get_script().get_script_method_list():
		if method.name == "apply_action_button":
			has_action_button = true
			break
	_expect(has_action_button, "shared action buttons provide layered feedback without changing their input bounds")
	if not has_action_button:
		return
	for role in ["primary", "secondary", "menu", "list"]:
		await _test_action_role(theme, role)
	_test_action_padding(theme)
	await _test_action_role_rebinding(theme)
	await _test_action_drag_out_and_back(theme)
	await _test_action_hidden_press(theme)
	await _test_action_lifecycle(theme)


func _test_action_role(theme: RefCounted, role: String) -> void:
	var button := Button.new()
	button.name = "Action_" + role
	button.text = "Original action"
	button.position = Vector2(180, 220)
	button.custom_minimum_size = Vector2(320, 96)
	button.size = Vector2(320, 96)
	button.focus_mode = Control.FOCUS_ALL
	var content := Label.new()
	content.name = "CustomContent"
	content.text = "42"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	add_child(button)
	theme.call("apply_action_button", button, role)
	for frame in range(3):
		await get_tree().process_frame
	var visual := button.get_node_or_null("ActionVisuals") as Control
	_expect(visual != null, "%s uses one visual group separate from the input control" % role)
	if visual == null:
		button.queue_free()
		await get_tree().process_frame
		return
	_expect(visual.get("role") == role, "%s keeps its own presentation role" % role)
	_expect(visual.show_behind_parent, "%s artwork stays behind native text and custom content" % role)
	_expect(button.text == "Original action" and content.get_parent() == button,
		"%s keeps the caller's native text and custom content" % role)
	_expect(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"%s visual group does not intercept the button's input" % role)
	var layers: Array[NinePatchRect] = []
	for layer_name in ["Shadow", "Face", "Outline"]:
		var layer := visual.get_node_or_null(layer_name) as NinePatchRect
		_expect(layer != null, "%s has a separate %s layer" % [role, layer_name])
		if layer != null:
			layers.append(layer)
			_expect(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"%s %s layer stays click-through" % [role, layer_name])
	if layers.size() == 3:
		_expect(layers[0].get_index() < layers[1].get_index() and layers[1].get_index() < layers[2].get_index(),
			"%s orders the shadow below the face and the outline above it" % role)
		if role == "menu":
			_expect(not layers[0].visible and not layers[1].visible and not layers[2].visible,
				"menu actions remain text-first without stacked backing plates")
		if role == "list":
			_expect(not layers[0].visible, "list rows use a quiet fixed surface without a raised shadow")
		if role in ["primary", "secondary"]:
			_expect(layers[0].texture == layers[1].texture,
				"%s reuses its silhouette for the independent shadow" % role)
			_expect(layers[1].texture != layers[2].texture,
				"%s highlight uses separate outline art" % role)
			for layer in layers:
				_expect(layer.texture != null and layer.texture.get_size() == Vector2(320, 96),
					"%s layers use their delivered 320 by 96 px canvas" % role)
				_expect(layer.patch_margin_left == 20 and layer.patch_margin_right == 20
					and layer.patch_margin_top == 16 and layer.patch_margin_bottom == 16,
					"%s layers preserve the shared patch geometry" % role)
	var original_rect := button.get_global_rect()
	var original_minimum := button.get_combined_minimum_size()
	var original_content_position := content.position
	var resting_face_tint := layers[1].modulate * layers[1].self_modulate if layers.size() == 3 else Color.WHITE
	var resting_text_color := button.get_theme_color("font_color")
	var connections := _action_connection_counts(button)
	var menu_marker := visual.get_node_or_null("MenuMarker") as TextureRect
	if role == "menu":
		_expect(menu_marker != null and menu_marker.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"menu focus marker is a separate click-through graphic")
		if menu_marker != null:
			_expect(menu_marker.size == Vector2(24, 24) and is_equal_approx(menu_marker.rotation, -PI / 2.0),
				"menu marker keeps its small rotated-arrow footprint")
	theme.call("apply_action_button", button, role)
	theme.call("apply_action_button", button, role)
	_expect(button.get_node("ActionVisuals") == visual and button.get_child_count() == 2,
		"%s repeated styling reuses the visual group and preserves custom content" % role)
	_expect(_action_connection_counts(button) == connections,
		"%s repeated styling does not multiply interaction callbacks" % role)
	var hover_scale := 1.05 if role == "primary" else 1.025 if role == "secondary" else 1.0
	var pressed_scale := 0.95 if role == "primary" else 0.975 if role == "secondary" else 1.0
	var profile: Dictionary = theme.call("button_feedback_profile", role)
	_expect(is_equal_approx(float(profile.get("hover_scale", 0.0)), hover_scale)
		and is_equal_approx(float(profile.get("pressed_scale", 0.0)), pressed_scale),
		"%s exposes its role-specific motion targets" % role)
	_expect(profile.get("hover_seconds") == 0.05 and profile.get("exit_seconds") == 0.5
		and profile.get("press_seconds") == 0.5 and profile.get("release_seconds") == 0.5,
		"%s retains the reviewed hover and recovery timing" % role)
	button.mouse_entered.emit()
	await get_tree().create_timer(0.09).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE * hover_scale), "%s hover reaches its visual-only target in 0.05 seconds (state=%s, scale=%s)" % [role, visual.get("feedback_state"), visual.scale])
	if layers.size() == 3 and role != "menu":
		_expect(layers[2].is_visible_in_tree() and layers[2].modulate.a * layers[2].self_modulate.a > 0.0,
			"%s hover exposes the independent close outline" % role)
		if role == "list":
			_expect(layers[1].modulate * layers[1].self_modulate != resting_face_tint,
				"list hover changes surface brightness without moving the row")
	if role == "menu":
		_expect(button.get_theme_color("font_hover_color") == T.UI_HEADER_GOLD
			and button.get_theme_color("font_focus_color") == T.UI_HEADER_GOLD
			and button.get_theme_color("font_hover_color") != resting_text_color,
			"menu hover has distinct live text feedback without a backing plate")
		if menu_marker != null:
			_expect(menu_marker.is_visible_in_tree() and menu_marker.modulate.a * menu_marker.self_modulate.a > 0.0,
				"menu hover exposes its independent selection marker")
	_expect(button.get_global_rect() == original_rect and button.scale == Vector2.ONE
		and button.get_combined_minimum_size() == original_minimum,
		"%s hover preserves layout and the clickable bounds" % role)
	_expect(content.position == original_content_position and content.scale == Vector2.ONE,
		"%s feedback preserves caller content geometry" % role)
	button.button_down.emit()
	await get_tree().create_timer(0.55).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE * pressed_scale), "%s press feedback affects only the art group" % role)
	button.button_up.emit()
	button.mouse_exited.emit()
	await get_tree().create_timer(0.6).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "%s release and exit restore the resting visual size" % role)
	button.grab_focus()
	await get_tree().create_timer(0.09).timeout
	_expect(button.has_focus() and visual.scale.is_equal_approx(Vector2.ONE * hover_scale),
		"%s keyboard focus receives the same feedback as hover" % role)
	button.disabled = true
	visual.call("sync_state")
	await get_tree().process_frame
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "%s disabling immediately cancels enlargement and press feedback" % role)
	if layers.size() == 3:
		_expect(not layers[2].is_visible_in_tree() or is_zero_approx(layers[2].modulate.a),
			"%s disabling clears the active outline" % role)
	if role == "menu" and menu_marker != null:
		_expect(not menu_marker.is_visible_in_tree() or is_zero_approx(menu_marker.modulate.a * menu_marker.self_modulate.a),
			"disabled menu actions hide the selection marker")
	button.mouse_entered.emit()
	button.button_down.emit()
	await get_tree().create_timer(0.09).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "%s disabled input cannot restart feedback" % role)
	var activations := [0]
	button.pressed.connect(func() -> void: activations[0] += 1)
	await _send_accept()
	_expect(activations[0] == 0, "%s disabled keyboard input cannot activate the action" % role)
	button.disabled = false
	visual.call("sync_state")
	button.grab_focus()
	await get_tree().create_timer(0.09).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE * hover_scale), "%s re-enabling restores focus feedback" % role)
	await _send_accept()
	_expect(activations[0] == 1, "%s styling preserves one native keyboard activation" % role)
	_expect(button.get_global_rect() == original_rect, "%s state changes never move the input area" % role)
	button.queue_free()
	await get_tree().process_frame


func _test_action_padding(theme: RefCounted) -> void:
	var button := Button.new()
	theme.call("apply_action_button", button, "primary")
	var style := button.get_theme_stylebox("normal")
	_expect(_content_margins(style) == Vector4(18, 10, 18, 12),
		"fresh action buttons receive deliberate shared content padding")
	button.free()
	button = Button.new()
	var original := StyleBoxEmpty.new()
	original.content_margin_left = 7
	original.content_margin_top = 8
	original.content_margin_right = 9
	original.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", original)
	theme.call("apply_action_button", button, "secondary")
	for state in ["normal", "hover", "pressed", "disabled"]:
		_expect(_content_margins(button.get_theme_stylebox(state)) == Vector4(7, 8, 9, 10),
			"restyling preserves the caller's resolved %s content geometry" % state)
	theme.call("apply_action_button", button, "primary", Vector4(3, 4, 5, 6))
	_expect(_content_margins(button.get_theme_stylebox("normal")) == Vector4(3, 4, 5, 6),
		"explicit content padding wins when a caller intentionally changes it")
	button.free()


func _content_margins(style: StyleBox) -> Vector4:
	return Vector4(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP),
		style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM))


func _test_action_role_rebinding(theme: RefCounted) -> void:
	var button := Button.new()
	button.size = Vector2(320, 96)
	add_child(button)
	theme.call("apply_action_button", button, "secondary")
	var visual := button.get_node_or_null("ActionVisuals") as Control
	if visual == null:
		button.queue_free()
		await get_tree().process_frame
		return
	button.mouse_entered.emit()
	theme.call("apply_action_button", button, "primary")
	await get_tree().create_timer(0.09).timeout
	var face := visual.get_node_or_null("Face") as NinePatchRect
	_expect(button.get_node("ActionVisuals") == visual and visual.get("role") == "primary",
		"changing roles reuses the control without leaving a stale feedback owner")
	_expect(face != null and face.texture != null and face.texture.resource_path.ends_with("/button_primary_base.png"),
		"changing roles updates the visible art rather than retaining the previous skin")
	_expect(visual.scale.is_equal_approx(Vector2(1.05, 1.05)), "changing roles during hover uses the new role's target")
	button.mouse_exited.emit()
	await get_tree().create_timer(0.12).timeout
	_expect(visual.scale.x > 1.0 and visual.scale.x < 1.025,
		"exit eases most of the way back early instead of using a linear recovery")
	await get_tree().create_timer(0.45).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "exit reaches rest by the end of its half-second recovery")
	button.queue_free()
	await get_tree().process_frame


func _test_action_lifecycle(theme: RefCounted) -> void:
	var button := Button.new()
	button.size = Vector2(320, 96)
	add_child(button)
	theme.call("apply_action_button", button, "primary")
	var visual := button.get_node_or_null("ActionVisuals") as Control
	if visual == null:
		button.queue_free()
		await get_tree().process_frame
		return
	button.mouse_entered.emit()
	await get_tree().process_frame
	remove_child(button)
	var detached_scale := visual.scale
	await get_tree().create_timer(0.12).timeout
	_expect(visual.scale == detached_scale, "leaving the tree stops an in-flight action tween")
	add_child(button)
	button.mouse_exited.emit()
	await get_tree().create_timer(0.6).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "re-entering the tree can restore the action normally")
	button.mouse_entered.emit()
	button.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	_expect(not is_instance_valid(button), "an action can be freed while its feedback is in flight")


func _test_action_drag_out_and_back(theme: RefCounted) -> void:
	await _move_pointer(Vector2(20, 20))
	var button := Button.new()
	button.position = Vector2(180, 220)
	button.size = Vector2(320, 96)
	var activations := [0]
	button.pressed.connect(func() -> void: activations[0] += 1)
	add_child(button)
	theme.call("apply_action_button", button, "primary")
	for frame in range(3):
		await get_tree().process_frame
	var visual := button.get_node_or_null("ActionVisuals") as Control
	if visual == null:
		button.queue_free()
		await get_tree().process_frame
		return
	var center := button.get_global_rect().get_center()
	await _move_pointer(center)
	await _send_mouse_button(center, true)
	await get_tree().create_timer(0.55).timeout
	_expect(visual.scale.is_equal_approx(Vector2(0.95, 0.95)), "native mouse press uses the shared pressed feedback")
	await _move_pointer(Vector2(20, 20), true)
	await get_tree().create_timer(0.55).timeout
	var outside_scale := 1.05 if button.has_focus() else 1.0
	_expect(visual.scale.is_equal_approx(Vector2.ONE * outside_scale), "holding the mouse outside clears pressed feedback while retaining keyboard focus")
	await _move_pointer(center, true)
	await get_tree().create_timer(0.55).timeout
	_expect(visual.scale.is_equal_approx(Vector2(0.95, 0.95)), "returning while held restores armed press rather than hover feedback")
	await _send_mouse_button(center, false)
	_expect(activations[0] == 1, "dragging out and returning releases one native action")
	button.release_focus()
	await _move_pointer(Vector2(20, 20))
	await get_tree().create_timer(0.55).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "mouse release and exit leave no stale pressed feedback")
	button.queue_free()
	await get_tree().process_frame


func _move_pointer(point: Vector2, held: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(motion, true)
	await get_tree().process_frame


func _test_action_hidden_press(theme: RefCounted) -> void:
	await _move_pointer(Vector2(20, 20))
	var button := Button.new()
	button.position = Vector2(180, 220)
	button.size = Vector2(320, 96)
	button.focus_mode = Control.FOCUS_NONE
	var activations := [0]
	button.pressed.connect(func() -> void: activations[0] += 1)
	add_child(button)
	theme.call("apply_action_button", button, "primary")
	for frame in range(3):
		await get_tree().process_frame
	var visual := button.get_node_or_null("ActionVisuals") as Control
	if visual == null:
		button.queue_free()
		await get_tree().process_frame
		return
	var center := button.get_global_rect().get_center()
	await _move_pointer(center)
	await _send_mouse_button(center, true)
	await get_tree().create_timer(0.55).timeout
	_expect(visual.scale.is_equal_approx(Vector2(0.95, 0.95)), "focus-free actions still show native press feedback")
	button.hide()
	await get_tree().process_frame
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "hiding a held action immediately cancels its feedback tween")
	button.show()
	await get_tree().create_timer(0.55).timeout
	var native_pressed := button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var shown_scale := 0.95 if native_pressed else 1.05 if button.is_hovered() else 1.0
	_expect(visual.scale.is_equal_approx(Vector2.ONE * shown_scale),
		"showing a held focus-free action follows the native armed state")
	await _move_pointer(Vector2(20, 20), true)
	await _send_mouse_button(Vector2(20, 20), false)
	_expect(activations[0] == 0, "the hidden press does not activate after releasing outside")
	await _move_pointer(center)
	await _send_mouse_button(center, true)
	await _send_mouse_button(center, false)
	await get_tree().create_timer(0.55).timeout
	_expect(activations[0] == 1 and visual.scale.is_equal_approx(Vector2(1.05, 1.05)),
		"a fresh click after hide/show activates once and returns to hover")
	await _move_pointer(Vector2(20, 20))
	await get_tree().create_timer(0.55).timeout
	_expect(visual.scale.is_equal_approx(Vector2.ONE), "focus-free hide/show leaves no stale pressed state")
	button.queue_free()
	await get_tree().process_frame


func _send_mouse_button(point: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	get_viewport().push_input(click, true)
	await get_tree().process_frame


func _action_connection_counts(button: Button) -> PackedInt32Array:
	var counts := PackedInt32Array()
	for signal_name in ["mouse_entered", "mouse_exited", "focus_entered", "focus_exited", "button_down", "button_up", "toggled", "draw", "visibility_changed", "tree_exiting"]:
		counts.append(button.get_signal_connection_list(signal_name).size())
	return counts


func _send_accept() -> void:
	for pressed in [true, false]:
		var accept := InputEventAction.new()
		accept.action = &"ui_accept"
		accept.pressed = pressed
		get_viewport().push_input(accept)
		await get_tree().process_frame


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
		popup_hover != null and popup_hover.texture.resource_path.ends_with("/button_secondary_base.png")
		and popup_hover.get_minimum_size() == original_hover.get_minimum_size()
		and popup.get_theme_font_size("font_size") == original_font_size,
		"opened dropdown uses the common hover state with its original item spacing and type size"
	)
	_expect(popup.get_theme_color("font_hover_color") == T.TEXT_MAIN, "dropdown hover text keeps light ink contrast on the dark shared surface")
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
