extends Control

## Slay-the-Spire style procedural map drawn over a pixel-art wasteland map.
## The route remains data-driven; only the presentation is custom-drawn here.

const MAP_BACKGROUND_PATH = "res://run_system/assets/images/map/wasteland_route_map_pixel_bg.png"
const NODE_ICON_DIR = "res://run_system/assets/images/map/nodes/"

const MAP_LEFT: float = 180.0
const MAP_TOP: float = 155.0
const MAP_BOTTOM_PADDING: float = 210.0
const FLOOR_SPACING: float = 310.0
const NODE_RADIUS: float = 34.0
const NODE_ICON_SIZE: float = 64.0
const LEGEND_NODE_ICON_SIZE: float = 20.0

const TYPE_COLORS = {
	"relic": Color(0.35, 0.95, 1.0),
	"unknown": Color(0.72, 0.82, 0.9),
	"merchant": Color(1.0, 0.82, 0.18),
	"treasure": Color(0.34, 1.0, 0.46),
	"rest": Color(1.0, 0.56, 0.2),
	"enemy": Color(1.0, 0.22, 0.26),
	"elite": Color(1.0, 0.18, 0.72),
	"boss": Color(1.0, 0.08, 0.12),
}

const LEGEND_ENTRIES = [
	["relic", "Relic"],
	["unknown", "Unknown"],
	["merchant", "Merchant"],
	["treasure", "Treasure"],
	["rest", "Rest"],
	["enemy", "Enemy"],
	["elite", "Elite"],
	["boss", "Boss"],
]

var rm: Node
var map_background_tex: Texture2D
var _node_icon_textures: Dictionary = {}
var _font: Font
var _node_positions: Dictionary = {}
var _hovered_node_id: String = ""
var _scroll_offset: float = 0.0
var _max_scroll: float = 0.0
var _is_dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_scroll: float = 0.0
var _relic_choice_layer: CanvasLayer
var _relic_choice_box: VBoxContainer
var _is_relic_choice_open: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_background_tex = _load_texture(MAP_BACKGROUND_PATH)
	_load_node_icons()
	_font = ThemeDB.fallback_font

	rm = get_node_or_null("/root/RunManager")
	if not rm:
		push_error("MapScene: RunManager not found!")
		return

	if rm.map_data.is_empty():
		rm.generate_map(12, 4)

	_compute_positions()
	_max_scroll = max(0.0, _get_total_width() - get_viewport_rect().size.x)
	_scroll_to_current()

	rm.health_changed.connect(func(_c, _m): queue_redraw())
	rm.resources_changed.connect(func(_g, _co): queue_redraw())
	rm.relics_updated.connect(func(): queue_redraw())
	get_viewport().size_changed.connect(_on_viewport_resized)
	_build_relic_choice_layer()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	push_warning("MapScene: missing texture '%s'" % path)
	return null


func _load_node_icons() -> void:
	_node_icon_textures.clear()
	for entry in LEGEND_ENTRIES:
		var node_type = str(entry[0])
		_node_icon_textures[node_type] = _load_texture(NODE_ICON_DIR + node_type + ".png")


func _on_viewport_resized() -> void:
	_compute_positions()
	_max_scroll = max(0.0, _get_total_width() - get_viewport_rect().size.x)
	_scroll_offset = clampf(_scroll_offset, 0.0, _max_scroll)
	queue_redraw()


func _compute_positions() -> void:
	_node_positions.clear()
	if not rm:
		return

	var vp = get_viewport_rect().size
	var max_slot = max(1, _get_max_slot())
	var map_height = maxf(260.0, vp.y - MAP_TOP - MAP_BOTTOM_PADDING)
	var slot_spacing = map_height / float(max_slot)

	for node in rm.map_data:
		var x = MAP_LEFT + node.floor * FLOOR_SPACING
		var y = MAP_TOP + node.slot * slot_spacing
		_node_positions[node.id] = Vector2(x, y)


func _get_max_floor() -> int:
	var result = 0
	for node in rm.map_data:
		if node.floor > result:
			result = node.floor
	return result


func _get_max_slot() -> int:
	var result = 0
	for node in rm.map_data:
		if node.slot > result:
			result = node.slot
	return result


func _get_total_width() -> float:
	return MAP_LEFT + (_get_max_floor() + 2) * FLOOR_SPACING + 200.0


func _scroll_to_current() -> void:
	if rm.current_node_id == "":
		_scroll_offset = 0.0
		return

	var node = rm.get_node_by_id(rm.current_node_id)
	if not node.is_empty():
		var target = MAP_LEFT + node.floor * FLOOR_SPACING - get_viewport_rect().size.x * 0.35
		_scroll_offset = clampf(target, 0.0, _max_scroll)


func _get_screen_pos(node_id: String) -> Vector2:
	if node_id in _node_positions:
		return _node_positions[node_id] - Vector2(_scroll_offset, 0)
	return Vector2.ZERO


func _draw() -> void:
	var vp = get_viewport_rect().size
	_draw_map_background(vp)

	if not rm or rm.map_data.is_empty():
		return

	_draw_all_paths(vp)
	_draw_all_nodes(vp)
	_draw_legend(vp)
	_draw_top_bar(vp)


func _draw_map_background(vp: Vector2) -> void:
	if map_background_tex:
		draw_texture_rect(map_background_tex, Rect2(Vector2.ZERO, vp), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.08, 0.08, 0.1, 1.0))
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.018, 0.01, 0.12))


func _draw_all_paths(vp: Vector2) -> void:
	var current_floor = -1
	if rm.current_node_id != "":
		var cur = rm.get_node_by_id(rm.current_node_id)
		if not cur.is_empty():
			current_floor = cur.floor

	for node in rm.map_data:
		if node.children.is_empty():
			continue

		var from = _get_screen_pos(node.id)
		for child_id in node.children:
			var to = _get_screen_pos(child_id)
			if from.x < -70 and to.x < -70:
				continue
			if from.x > vp.x + 70 and to.x > vp.x + 70:
				continue

			var color = Color(0.18, 0.72, 1.0, 0.82)
			if node.id == rm.current_node_id:
				color = Color(0.55, 0.95, 1.0, 0.98)
			elif current_floor >= 0 and node.floor < current_floor:
				color = Color(0.16, 0.44, 0.68, 0.58)

			_draw_pixel_dashed_line(from, to, Color(0.02, 0.05, 0.08, color.a * 0.62), 3.2, 22.0, 12.0, Vector2(1, 2))
			_draw_pixel_dashed_line(from, to, color, 2.1, 22.0, 12.0, Vector2.ZERO)


func _draw_all_nodes(vp: Vector2) -> void:
	var current_floor = -1
	if rm.current_node_id != "":
		var cur = rm.get_node_by_id(rm.current_node_id)
		if not cur.is_empty():
			current_floor = cur.floor

	for node in rm.map_data:
		var pos = _get_screen_pos(node.id)
		if pos.x < -60 or pos.x > vp.x + 60:
			continue

		var accessible = _is_accessible(node)
		var is_current = node.id == rm.current_node_id
		var visited = is_current or (current_floor >= 0 and node.floor < current_floor)
		var hovered = node.id == _hovered_node_id and accessible

		var alpha = 1.0
		if visited and not is_current:
			alpha = 0.52
		elif not accessible and not visited:
			alpha = 0.74

		var radius = NODE_RADIUS + (4.0 if hovered else 0.0)
		_draw_map_node(pos, node.type, radius, alpha, accessible, visited, is_current, hovered)


func _draw_map_node(pos: Vector2, node_type: String, radius: float, alpha: float, accessible: bool, visited: bool, is_current: bool, hovered: bool) -> void:
	var icon_size = NODE_ICON_SIZE + (4.0 if hovered else 0.0) + (4.0 if is_current else 0.0)
	var tint = Color(1.0, 1.0, 1.0, alpha)
	if not accessible and not visited:
		tint = Color(0.88, 0.84, 0.76, alpha)
	elif visited and not is_current:
		tint = Color(0.80, 0.76, 0.66, maxf(alpha, 0.62))

	if is_current:
		_draw_pixel_selection(pos, radius + 10.0, Color(1.0, 0.92, 0.25, 1.0))
	elif hovered:
		_draw_pixel_selection(pos, radius + 9.0, Color(0.45, 0.95, 1.0, 0.95))
	elif accessible and not visited:
		draw_rect(Rect2(pos + Vector2(-2, radius + 7.0), Vector2(4, 4)), Color(0.45, 0.95, 1.0, 0.9))

	_draw_node_texture(pos, node_type, icon_size, tint)


func _draw_node_texture(pos: Vector2, node_type: String, icon_size: float, tint: Color) -> void:
	var texture: Texture2D = _node_icon_textures.get(node_type, null)
	if texture:
		var rect = Rect2(pos - Vector2(icon_size * 0.5, icon_size * 0.5), Vector2(icon_size, icon_size))
		var outline = Color(0.04, 0.025, 0.012, tint.a * 0.58)
		_draw_node_texture_rect(texture, rect, Vector2(2, 2), outline)
		_draw_node_texture_rect(texture, rect, Vector2(-1, 0), outline)
		_draw_node_texture_rect(texture, rect, Vector2(1, 0), outline)
		_draw_node_texture_rect(texture, rect, Vector2(0, -1), outline)
		_draw_node_texture_rect(texture, rect, Vector2(0, 1), outline)
		draw_texture_rect(texture, rect, false, tint)
		return

	var type_color: Color = TYPE_COLORS.get(node_type, Color.GRAY)
	draw_string(_font, pos + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(icon_size), Color(type_color.r, type_color.g, type_color.b, tint.a))


func _draw_node_texture_rect(texture: Texture2D, rect: Rect2, offset: Vector2, tint: Color) -> void:
	draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, tint)


func _draw_pixel_selection(center: Vector2, radius: float, color: Color) -> void:
	var left = center.x - radius
	var right = center.x + radius
	var top = center.y - radius
	var bottom = center.y + radius
	var corner = minf(8.0, radius * 0.38)
	var width = 2.0

	draw_line(Vector2(left, top), Vector2(left + corner, top), color, width)
	draw_line(Vector2(left, top), Vector2(left, top + corner), color, width)
	draw_line(Vector2(right, top), Vector2(right - corner, top), color, width)
	draw_line(Vector2(right, top), Vector2(right, top + corner), color, width)
	draw_line(Vector2(left, bottom), Vector2(left + corner, bottom), color, width)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - corner), color, width)
	draw_line(Vector2(right, bottom), Vector2(right - corner, bottom), color, width)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - corner), color, width)


func _draw_legend(vp: Vector2) -> void:
	var pw = 150.0
	var ph = 238.0
	var px = vp.x - pw - 18.0
	var py = 68.0
	var rect = Rect2(px, py, pw, ph)

	draw_rect(Rect2(rect.position + Vector2(5, 6), rect.size), Color(0.02, 0.012, 0.006, 0.42))
	draw_rect(rect, Color(0.70, 0.58, 0.39, 0.92))
	draw_rect(rect, Color(0.22, 0.16, 0.10, 0.9), false, 2.0)

	var y = py + 26.0
	draw_string(_font, Vector2(px + 45, y), "Legend", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.18, 0.12, 0.08))
	y += 8.0
	draw_line(Vector2(px + 10, y), Vector2(px + pw - 10, y), Color(0.26, 0.18, 0.11, 0.78), 2.0)
	y += 18.0

	for entry in LEGEND_ENTRIES:
		_draw_node_texture(Vector2(px + 22, y - 6), str(entry[0]), LEGEND_NODE_ICON_SIZE, Color(1.0, 1.0, 1.0, 1.0))
		draw_string(_font, Vector2(px + 38, y), str(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.18, 0.12, 0.08))
		y += 26.0


func _draw_top_bar(vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, 52), Color(0.05, 0.028, 0.018, 0.94))
	draw_rect(Rect2(0, 50, vp.x, 4), Color(0.62, 0.42, 0.2, 0.78))

	draw_string(_font, Vector2(20, 35), "HP: %d/%d" % [rm.current_health, rm.max_health], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.42, 0.34))
	draw_string(_font, Vector2(200, 35), "Gold: %d" % rm.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.86, 0.24))
	draw_string(_font, Vector2(380, 35), "Floor: %d" % rm.current_floor, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.82, 0.72))


func _draw_pixel_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float, offset: Vector2) -> void:
	var length = from.distance_to(to)
	if length < 1.0:
		return
	var dir = (to - from).normalized()
	var distance = 0.0
	while distance < length:
		var start = from + dir * distance + offset
		var end = from + dir * minf(distance + dash, length) + offset
		draw_line(start, end, color, width)
		distance += dash + gap


func _is_accessible(node_data: Dictionary) -> bool:
	if node_data.floor == 0 and rm.current_node_id == "":
		return true
	if rm.current_node_id != "":
		var current = rm.get_node_by_id(rm.current_node_id)
		if not current.is_empty() and node_data.id in current.children:
			return true
	return false


func _get_node_at(pos: Vector2) -> Dictionary:
	for node in rm.map_data:
		var sp = _get_screen_pos(node.id)
		if pos.distance_to(sp) <= NODE_RADIUS + 8:
			return node
	return {}


func _input(event: InputEvent) -> void:
	if _is_relic_choice_open:
		return

	if event is InputEventMouseMotion:
		var node = _get_node_at(event.position)
		var new_id = node.get("id", "") if not node.is_empty() else ""
		if new_id != _hovered_node_id:
			_hovered_node_id = new_id
			queue_redraw()
		if _is_dragging:
			_scroll_offset = clampf(_drag_start_scroll - (event.position.x - _drag_start_x), 0.0, _max_scroll)
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var node = _get_node_at(event.position)
				if not node.is_empty() and _is_accessible(node):
					_on_node_clicked(node)
				else:
					_is_dragging = true
					_drag_start_x = event.position.x
					_drag_start_scroll = _scroll_offset
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = clampf(_scroll_offset + 50.0, 0.0, _max_scroll)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset = clampf(_scroll_offset - 50.0, 0.0, _max_scroll)
			queue_redraw()


func _on_node_clicked(node: Dictionary) -> void:
	rm.current_node_id = node.id
	rm.current_floor = node.floor
	queue_redraw()

	await get_tree().create_timer(0.35).timeout

	match node.type:
		"relic":
			_open_relic_choice("Choose Your Starting Relic", "starting")
		"enemy", "elite", "boss":
			get_tree().change_scene_to_file(rm.BATTLE_SCENE)
		"rest":
			var heal = int(rm.max_health * 0.25)
			rm.modify_health(heal)
			_show_popup("Rested. Healed %d HP." % heal)
		"merchant":
			_show_popup("The merchant waves... nothing to sell yet.")
		"treasure":
			_open_relic_choice("Choose a Relic", "treasure")
		"unknown":
			if randf() < 0.5:
				get_tree().change_scene_to_file(rm.BATTLE_SCENE)
			else:
				var gold = randi_range(5, 20)
				rm.add_resources(gold, 0)
				_show_popup("Scavenged %d gold." % gold)


func _show_popup(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.y += 80
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(1.5)
	tween.tween_callback(label.queue_free)
	queue_redraw()


func _build_relic_choice_layer() -> void:
	_relic_choice_layer = CanvasLayer.new()
	_relic_choice_layer.name = "RelicChoiceLayer"
	_relic_choice_layer.layer = 80
	_relic_choice_layer.visible = false
	add_child(_relic_choice_layer)

	var root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_relic_choice_layer.add_child(root)

	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.56)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	var center = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(720, 410)
	panel.add_theme_stylebox_override("panel", _make_relic_panel_style())
	center.add_child(panel)

	_relic_choice_box = VBoxContainer.new()
	_relic_choice_box.name = "Choices"
	_relic_choice_box.add_theme_constant_override("separation", 14)
	panel.add_child(_relic_choice_box)


func _open_relic_choice(title: String, source_type: String) -> void:
	if not rm:
		return

	var choices: Array[String] = rm.roll_relic_choices(3)
	if choices.is_empty():
		if source_type == "treasure":
			var gold = randi_range(20, 45)
			rm.add_resources(gold, 0)
			_show_popup("No relics remain. Found %d gold!" % gold)
		else:
			_show_popup("No relics remain.")
		return

	for child in _relic_choice_box.get_children():
		child.queue_free()

	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_relic_choice_box.add_child(title_label)

	var hint = Label.new()
	hint.text = "Pick one. Relics are unique for this run."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	_relic_choice_box.add_child(hint)

	for relic_id in choices:
		_relic_choice_box.add_child(_make_relic_choice_button(relic_id, source_type))

	_is_relic_choice_open = true
	_relic_choice_layer.visible = true


func _make_relic_choice_button(relic_id: String, source_type: String) -> Button:
	var data = rm.get_relic_data(relic_id)
	var title = str(data.get("title", _humanize_id(relic_id)))
	var description = str(data.get("description", ""))

	var button = Button.new()
	button.custom_minimum_size = Vector2(620, 82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _make_relic_button_style(Color(0.10, 0.075, 0.055, 0.96)))
	button.add_theme_stylebox_override("hover", _make_relic_button_style(Color(0.17, 0.12, 0.075, 0.98)))
	button.add_theme_stylebox_override("pressed", _make_relic_button_style(Color(0.23, 0.16, 0.08, 1.0)))
	button.pressed.connect(_on_relic_choice_selected.bind(relic_id, source_type))

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)

	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon_path = str(data.get("icon", ""))
	var icon_texture = _load_texture(icon_path) if not icon_path.is_empty() else null
	if icon_texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(58, 58)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	else:
		var icon = Label.new()
		icon.custom_minimum_size = Vector2(54, 54)
		icon.text = title.substr(0, 1).to_upper()
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 28)
		icon.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		row.add_child(icon)

	var text_box = VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title_text = Label.new()
	title_text.text = title
	title_text.add_theme_font_size_override("font_size", 22)
	title_text.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	text_box.add_child(title_text)

	var desc_text = Label.new()
	desc_text.text = description
	desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_text.add_theme_font_size_override("font_size", 15)
	desc_text.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70))
	text_box.add_child(desc_text)

	return button


func _on_relic_choice_selected(relic_id: String, _source_type: String) -> void:
	_is_relic_choice_open = false
	_relic_choice_layer.visible = false

	if rm.add_relic(relic_id):
		var data = rm.get_relic_data(relic_id)
		_show_popup("Gained relic: %s" % str(data.get("title", _humanize_id(relic_id))))
	else:
		_show_popup("Already have that relic.")
	queue_redraw()


func _make_relic_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.038, 0.026, 0.98)
	style.border_color = Color(0.74, 0.52, 0.24, 0.92)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 28
	style.content_margin_top = 24
	style.content_margin_right = 28
	style.content_margin_bottom = 24
	return style


func _make_relic_button_style(bg: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.38, 0.86, 1.0, 0.58)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()
