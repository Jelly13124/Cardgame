## DraggableWindow — base for the floating base-UI windows (character / forge).
## Title-bar drag (clamped to viewport), ✕ close, click-to-front. Subclass via
## `extends "res://run_system/ui/window/draggable_window.gd"` (no class_name,
## ADR-0006), call `init_window(title, size)` in _ready, then add content into
## `content_root`. Hosted by window_layer.gd (which owns z-order + ESC-close).
extends PanelContainer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal closed

var content_root: VBoxContainer
var _drag_active := false
var _drag_offset := Vector2.ZERO
var _title_bar: PanelContainer


func init_window(title: String, win_size: Vector2) -> void:
	custom_minimum_size = win_size
	size = win_size
	add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.09, 0.07, 0.05, 0.98), Color(0.55, 0.38, 0.18), 2, 4)
	)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	_title_bar = PanelContainer.new()
	_title_bar.custom_minimum_size = Vector2(0, 42)
	_title_bar.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.14, 0.10, 0.06, 1.0), Color(0.45, 0.30, 0.14), 1, 0)
	)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_title_input)
	vbox.add_child(_title_bar)

	var bar := HBoxContainer.new()
	_title_bar.add_child(bar)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(close)
	bar.add_child(x)

	content_root = VBoxContainer.new()
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_root)

	# Click anywhere on the window body → bring to front.
	gui_input.connect(_on_window_input)


func close() -> void:
	closed.emit()
	queue_free()


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var wl := get_parent()
		if wl and wl.has_method("bring_to_front"):
			wl.bring_to_front(self)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
		_drag_offset = get_global_mouse_position() - global_position
		if event.pressed:
			var wl := get_parent()
			if wl and wl.has_method("bring_to_front"):
				wl.bring_to_front(self)
	elif event is InputEventMouseMotion and _drag_active:
		var vp := get_viewport_rect().size
		global_position = (get_global_mouse_position() - _drag_offset).clamp(
			Vector2.ZERO, vp - size
		)
