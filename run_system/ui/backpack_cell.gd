## Interaction wrapper for one equipment slot / backpack cell. Owns drag-and-drop
## (Godot native _get_drag_data / _can_drop_data / _drop_data), click fallback,
## and the hover tooltip. The visual (EquipmentIcon, resource labels, or empty
## panel) is added as a mouse-ignoring child — this node receives all input.
##
## The owning EquipmentPanel configures behaviour via callables so all game logic
## (equip / unequip / move_cell) stays in the panel:
##   drag_payload   : Dictionary  — {} means "not draggable" (empty cells)
##   can_accept     : func(data:Dictionary) -> bool
##   perform_drop   : func(data:Dictionary) -> void
##   click_handler  : func(button_index:int) -> void
##   hover_tip      : String      — "" disables hover tooltip
##   preview_text   : String / preview_color : Color — drag-preview glyph
## NOTE: no `class_name` — referenced via preload (ADR-0006: cold editor scans
## fail on class_name for custom types).
extends Control

var drag_payload: Dictionary = {}
var can_accept: Callable = Callable()
var perform_drop: Callable = Callable()
var click_handler: Callable = Callable()
var hover_tip: String = ""
var preview_text: String = ""
var preview_color: Color = Color(1, 1, 1)
var preview_tex: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	# Force-hide on tree exit so a freed cell (panel rebuild) can't strand its tooltip.
	tree_exited.connect(_on_exit)


func _on_enter() -> void:
	if hover_tip != "" and is_inside_tree():
		Tooltip.show(hover_tip, global_position + Vector2(size.x * 0.5, 0), get_instance_id())


func _on_exit() -> void:
	Tooltip.hide_if_owner(get_instance_id())


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	set_drag_preview(_make_preview())
	return drag_payload.duplicate(true)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not can_accept.is_valid():
		return false
	return bool(can_accept.call(data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and perform_drop.is_valid():
		perform_drop.call(data)


## Fire click on RELEASE (not press): a press that turns into a drag never
## delivers its release to this source node, so a drag won't also count as a
## click. A plain click (no drag) gets both press and release here.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and click_handler.is_valid():
		click_handler.call(event.button_index)


func _make_preview() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(60, 60)
	p.size = Vector2(60, 60)
	p.modulate = Color(1, 1, 1, 0.85)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	sb.border_color = preview_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	# Prefer the real sprite; fall back to the letter glyph when there's no art.
	if preview_tex:
		var tr := TextureRect.new()
		tr.texture = preview_tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4
		tr.offset_top = 4
		tr.offset_right = -4
		tr.offset_bottom = -4
		p.add_child(tr)
	else:
		var l := Label.new()
		l.text = preview_text
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", preview_color)
		p.add_child(l)
	return p
