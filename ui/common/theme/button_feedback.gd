## Draws shared button feedback behind the native label and fixed input rectangle.
extends Control

var role: String = "secondary"
var feedback_state: String = "normal"
var target_scale: float = 1.0

var _button: Button
var _profile: Dictionary = {}
var _shadow: NinePatchRect
var _face: NinePatchRect
var _outline: NinePatchRect
var _marker: TextureRect
var _motion: Tween
var _mouse_inside := false
var _focused := false
var _pressed := false
var _disabled := false
var _connected := false
var _native_pressed := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(_layout_layers)


func configure(button: Button, profile: Dictionary) -> void:
	_kill_motion()
	var first_application := _button == null
	_button = button
	_profile = profile
	role = str(profile["role"])
	if first_application:
		_mouse_inside = button.is_hovered()
		_focused = button.has_focus()
		_shadow = _new_layer("Shadow")
		_face = _new_layer("Face")
		_outline = _new_layer("Outline")
	if role == "menu" and _marker == null:
		_marker = TextureRect.new()
		_marker.name = "MenuMarker"
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_marker)
	elif role != "menu" and _marker != null:
		_marker.free()
		_marker = null
	if _marker != null:
		_marker.texture = profile["marker_texture"]
		_marker.size = profile["marker_size"]
		_marker.pivot_offset = _marker.size * 0.5
		_marker.rotation = float(profile["marker_rotation"])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var patches: Vector4 = profile["patch_margins"]
	for layer in [_shadow, _face, _outline]:
		layer.patch_margin_left = int(patches.x)
		layer.patch_margin_top = int(patches.y)
		layer.patch_margin_right = int(patches.z)
		layer.patch_margin_bottom = int(patches.w)
	_shadow.texture = profile["base_texture"]
	_face.texture = profile["base_texture"]
	_outline.texture = profile["outline_texture"]
	_layout_layers()
	if is_inside_tree():
		_connect_signals()
	sync_state(true)


func _enter_tree() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _button != null:
		_mouse_inside = _button.is_hovered()
		_focused = _button.has_focus()
		_connect_signals()
		call_deferred("sync_state", true)


func _exit_tree() -> void:
	_kill_motion()
	_disconnect_signals()
	_mouse_inside = false
	_focused = false
	_pressed = false
	scale = Vector2.ONE


func _process(_delta: float) -> void:
	if is_instance_valid(_button) and _disabled != _button.disabled:
		sync_state()


func _new_layer(layer_name: String) -> NinePatchRect:
	var layer := NinePatchRect.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(layer)
	return layer


func _layout_layers() -> void:
	if _button == null or _shadow == null:
		return
	pivot_offset = size * 0.5
	_shadow.position = _profile["shadow_offset"]
	_shadow.size = size
	_face.position = Vector2.ZERO
	_face.size = size
	_outline.position = Vector2.ZERO
	_outline.size = size
	if _marker != null:
		_layout_menu_marker()


func _layout_menu_marker() -> void:
	var style := _button.get_theme_stylebox("normal")
	var font := _button.get_theme_font("font")
	var font_size := _button.get_theme_font_size("font_size")
	var text := _button.tr(_button.text)
	var available := maxf(0.0, size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT))
	var text_width := minf(available, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var text_left := style.get_margin(SIDE_LEFT)
	if _button.alignment == HORIZONTAL_ALIGNMENT_CENTER:
		text_left += (available - text_width) * 0.5
	elif _button.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		text_left += available - text_width
	var text_center_y := (size.y + style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM)) * 0.5
	_marker.position = Vector2(
		text_left - float(_profile["marker_gap"]) - _marker.size.x,
		text_center_y - _marker.size.y * 0.5
	)


func _connect_signals() -> void:
	if _connected:
		return
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.focus_entered.connect(_on_focus_entered)
	_button.focus_exited.connect(_on_focus_exited)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.toggled.connect(_on_toggled)
	_button.draw.connect(_on_draw)
	_button.visibility_changed.connect(_on_visibility_changed)
	_connected = true


func _disconnect_signals() -> void:
	if not _connected or not is_instance_valid(_button):
		return
	_button.mouse_entered.disconnect(_on_mouse_entered)
	_button.mouse_exited.disconnect(_on_mouse_exited)
	_button.focus_entered.disconnect(_on_focus_entered)
	_button.focus_exited.disconnect(_on_focus_exited)
	_button.button_down.disconnect(_on_button_down)
	_button.button_up.disconnect(_on_button_up)
	_button.toggled.disconnect(_on_toggled)
	_button.draw.disconnect(_on_draw)
	_button.visibility_changed.disconnect(_on_visibility_changed)
	_connected = false


func sync_state(immediate: bool = false) -> void:
	if not is_instance_valid(_button) or _profile.is_empty():
		return
	var native_pressed := _button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	if not _button.is_visible_in_tree():
		_pressed = false
		_native_pressed = false
	else:
		if native_pressed:
			_pressed = true
		elif _native_pressed:
			_pressed = false
		_native_pressed = native_pressed
	var disabled_changed := _disabled != _button.disabled
	_disabled = _button.disabled
	if _disabled:
		_pressed = false
	var next_state := "normal"
	if _disabled:
		next_state = "disabled"
	elif _pressed or (_button.toggle_mode and _button.button_pressed):
		next_state = "pressed"
	elif _mouse_inside or _focused:
		next_state = "hover"
	if next_state == feedback_state and not immediate and not disabled_changed:
		return
	var previous_state := feedback_state
	feedback_state = next_state
	_present_state(immediate or disabled_changed or not is_inside_tree(), previous_state)


func _present_state(immediate: bool, previous_state: String) -> void:
	_kill_motion()
	target_scale = 1.0
	if feedback_state == "hover":
		target_scale = float(_profile["hover_scale"])
	elif feedback_state == "pressed":
		target_scale = float(_profile["pressed_scale"])
	var face_tints: Dictionary = _profile["face_tints"]
	var face_tint: Color = face_tints[feedback_state]
	var marker_tint: Color = _profile["marker_tint"]
	if feedback_state not in ["hover", "pressed"] or _button.text.is_empty():
		marker_tint.a = 0.0
	if _marker != null:
		_marker.visible = marker_tint.a > 0.0 or _marker.modulate.a > 0.0
	var outline_tint: Color = _profile["outline_tint"]
	if feedback_state not in ["hover", "pressed"] or not bool(_profile["show_outline"]):
		outline_tint.a = 0.0
	_shadow.visible = bool(_profile["show_shadow"])
	_shadow.modulate = _profile["shadow_tint"]
	_face.visible = bool(_profile["show_face"])
	_outline.visible = outline_tint.a > 0.0 or _outline.modulate.a > 0.0
	if immediate:
		scale = Vector2.ONE * target_scale
		_face.modulate = face_tint
		_outline.modulate = outline_tint
		_outline.visible = outline_tint.a > 0.0
		if _marker != null:
			_marker.modulate = marker_tint
			_marker.visible = marker_tint.a > 0.0
		return
	var seconds := float(_profile["exit_seconds"])
	var transition: Tween.TransitionType = _profile["exit_trans"]
	var easing: Tween.EaseType = _profile["exit_ease"]
	if feedback_state == "hover" and previous_state != "pressed":
		seconds = float(_profile["hover_seconds"])
		transition = _profile["hover_trans"]
		easing = _profile["hover_ease"]
	elif feedback_state == "pressed":
		seconds = float(_profile["press_seconds"])
		transition = _profile["press_trans"]
		easing = _profile["press_ease"]
	elif previous_state == "pressed":
		seconds = float(_profile["release_seconds"])
	_motion = create_tween().set_parallel(true).set_trans(transition).set_ease(easing)
	_motion.tween_property(self, "scale", Vector2.ONE * target_scale, seconds)
	_motion.tween_property(_face, "modulate", face_tint, seconds)
	_motion.tween_property(_outline, "modulate", outline_tint, seconds)
	if _marker != null:
		_motion.tween_property(_marker, "modulate", marker_tint, seconds)
	_motion.finished.connect(_on_motion_finished)


func _kill_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _on_motion_finished() -> void:
	_motion = null
	if feedback_state in ["normal", "disabled"]:
		_outline.visible = false
		if _marker != null:
			_marker.visible = false


func _on_mouse_entered() -> void:
	_mouse_inside = true
	_pressed = not _button.disabled and _button.is_pressed()
	if not _button.disabled and not _focused:
		AudioManager.play_sfx(str(_profile["hover_sound"]))
	sync_state()


func _on_mouse_exited() -> void:
	_mouse_inside = false
	_pressed = false
	sync_state()


func _on_focus_entered() -> void:
	_focused = true
	_pressed = not _button.disabled and _button.is_pressed()
	if not _button.disabled and not _mouse_inside:
		AudioManager.play_sfx(str(_profile["hover_sound"]))
	sync_state()


func _on_focus_exited() -> void:
	_focused = false
	_pressed = false
	sync_state()


func _on_button_down() -> void:
	_pressed = not _button.disabled
	sync_state()


func _on_button_up() -> void:
	_pressed = false
	sync_state()


func _on_toggled(_active: bool) -> void:
	sync_state()


func _on_draw() -> void:
	_layout_layers()
	sync_state()


func _on_visibility_changed() -> void:
	if not _button.is_visible_in_tree():
		_mouse_inside = false
		_focused = false
		_pressed = false
	sync_state(true)
