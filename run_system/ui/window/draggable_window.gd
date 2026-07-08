## DraggableWindow — base for the floating base-UI windows (character / forge).
## Title-bar drag (clamped to viewport), ✕ close, click-to-front, optional
## title-bar icon buttons (add_title_button). Subclass via
## `extends "res://run_system/ui/window/draggable_window.gd"` (no class_name,
## ADR-0006), call `init_window(title, size)` in _ready, then add content into
## `content_root`. Hosted by window_layer.gd (which owns z-order + ESC-close).
## Chrome uses the v2 scrap-brown + brass theme (T.ui_panel / T.ui_titlebar —
## programmatic fallbacks until the Codex ui_kit lands).
extends PanelContainer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal closed

var content_root: VBoxContainer
var _drag_active := false
var _drag_offset := Vector2.ZERO
var _title_bar: PanelContainer
var _title_bar_box: HBoxContainer
var _close_btn: Button


func init_window(title: String, win_size: Vector2, show_title_bar: bool = true) -> void:
	custom_minimum_size = win_size
	size = win_size
	add_theme_stylebox_override("panel", T.ui_panel())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)
	if not show_title_bar:
		content_root = VBoxContainer.new()
		content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(content_root)
		gui_input.connect(_on_window_input)
		return

	_title_bar = PanelContainer.new()
	_title_bar.custom_minimum_size = Vector2(0, 42)
	_title_bar.add_theme_stylebox_override("panel", T.ui_titlebar())
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_title_input)
	vbox.add_child(_title_bar)

	_title_bar_box = HBoxContainer.new()
	_title_bar.add_child(_title_bar_box)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_bar_box.add_child(lbl)
	# Square lightline ✕ at its native aspect (owner: no stretched close buttons).
	_close_btn = T.ll_close_button(32.0)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(close)
	_title_bar_box.add_child(_close_btn)

	content_root = VBoxContainer.new()
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_root)

	# Click anywhere on the window body → bring to front.
	gui_input.connect(_on_window_input)


## Insert a small flat icon button into the title bar, BEFORE the ✕ close
## button (e.g. the CharacterWindow's Stash toggle). `text_or_icon` is a short
## glyph string ("▣"); `tooltip` is already-translated hover text. Returns the
## Button so callers can rename / restyle it. Call AFTER init_window.
func add_title_button(text_or_icon: String, tooltip: String, cb: Callable) -> Button:
	var b := Button.new()
	if _title_bar_box == null:
		push_warning("add_title_button called on a window without a title bar.")
		return b
	b.text = text_or_icon
	b.tooltip_text = tooltip
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(34, 0)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	b.add_theme_color_override("font_hover_color", T.UI_BRASS_LIGHT)
	b.pressed.connect(cb)
	_title_bar_box.add_child(b)
	if is_instance_valid(_close_btn):
		_title_bar_box.move_child(b, _close_btn.get_index())
	return b


func bind_drag_area(area: Control) -> void:
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_on_title_input)


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
