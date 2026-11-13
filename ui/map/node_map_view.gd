extends Control

## The act map as a scrollable parchment chart: floor 0 on the left, the boss on
## the right, one MapNodeButton per node, dashed ink paths between them, the
## walked path in solid orange and the current node's choices in orange dashes,
## an orange start flag and a legend card. Scroll with the wheel or by dragging
## empty map. The layout is a pure function of the map, so the same seed always
## draws the same chart.

signal node_chosen(node_id: String)

const MAP_NODE_BUTTON = preload("uid://dxs0bi6rnni22")  # res://ui/map/map_node_button.gd
const ICON_DIR := "res://run_system/assets/images/map/nodes/"
const PARCHMENT_PATH := "res://run_system/assets/images/map/route_parchment.png"
const FLAG_PATH := "res://run_system/assets/images/map/start_flag.png"
const LEGEND_CARD_PATH := "res://run_system/assets/images/map/legend_card.png"
const LEFT := 170.0
const RIGHT_PAD := 260.0
const FLOOR_SPACING := 300.0
const TOP := 180.0
const BOTTOM_MARGIN := 160.0
const JITTER := 18.0
const DASH := 14.0
const GAP := 10.0
const LINE_WIDTH := 4.0
const INK := Color(0.23, 0.18, 0.15, 0.85)
const ORANGE := Color("#e8742a")
const LEGEND_TYPES := ["enemy", "elite", "unknown", "merchant", "treasure", "rest", "relic", "boss"]

var fallback_background: Texture2D
var _map: Array = []
var _by_id: Dictionary = {}
var _current := ""
var _visited: Array = []
var _buttons: Dictionary = {}
var _positions: Dictionary = {}
var _scroll := 0.0
var _max_scroll := 0.0
var _dragging := false
var _drag_from := 0.0
var _drag_scroll := 0.0
var _canvas: Control
var _background: TextureRect
var _paths: Control
var _legend_entries: VBoxContainer
var _focus_id := ""


func _init() -> void:
	name = "NodeMapView"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_background = TextureRect.new()
	_background.name = "Parchment"
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_background)
	_paths = Control.new()
	_paths.name = "Paths"
	_paths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paths.draw.connect(_draw_paths)
	_canvas.add_child(_paths)
	_build_legend()
	resized.connect(_relayout)


## Draws `map_data` with the player on `current_id` ("" at the act start),
## `visited` the walked node ids; nodes are clickable only when `interactive`.
func setup(map_data: Array, current_id: String, visited: Array, interactive: bool) -> void:
	_map = map_data
	_current = current_id
	_visited = visited.duplicate()
	_by_id.clear()
	for n in _map:
		_by_id[str(n.id)] = n
	for b in _buttons.values():
		b.queue_free()
	_buttons.clear()
	var choices := _choice_ids()
	for n in _map:
		var id := str(n.id)
		var button = MAP_NODE_BUTTON.new()
		button.name = "Node_%s" % id
		_canvas.add_child(button)
		var node_state := "unreachable"
		if id == _current:
			node_state = "current"
		elif id in choices:
			node_state = "available"
		elif id in _visited:
			node_state = "visited"
		button.setup(n, node_state, interactive)
		button.chosen.connect(func(nid): node_chosen.emit(nid))
		_buttons[id] = button
	_focus_id = _current if _current != "" else _first_id()
	_relayout()


func node_button(id: String) -> Control:
	return _buttons.get(id)


## Scrolls so `id` sits about a third from the left (clamped to the ends).
func scroll_to_node(id: String) -> void:
	if not _positions.has(id):
		return
	_set_scroll(_positions[id].x - size.x / 3.0)


func _choice_ids() -> Array:
	if _current == "":
		return _map.filter(func(n): return int(n.floor) == 0).map(func(n): return str(n.id))
	return Array(_by_id.get(_current, {}).get("children", [])).map(func(c): return str(c))


func _first_id() -> String:
	for n in _map:
		if int(n.floor) == 0:
			return str(n.id)
	return ""


func _relayout() -> void:
	if _map.is_empty() or size.y <= 0.0:
		return
	var floors := 0
	var per_floor := {}
	for n in _map:
		floors = maxi(floors, int(n.floor) + 1)
		per_floor[int(n.floor)] = per_floor.get(int(n.floor), []) + [n]
	var width := LEFT + float(floors - 1) * FLOOR_SPACING + RIGHT_PAD
	var band_top := TOP
	var band_bottom := maxf(band_top + 200.0, size.y - BOTTOM_MARGIN)
	_canvas.size = Vector2(width, size.y)
	_background.size = _canvas.size
	_background.texture = MAP_NODE_BUTTON._load(PARCHMENT_PATH)
	if _background.texture == null:
		_background.texture = fallback_background
	_paths.size = _canvas.size
	_positions.clear()
	for f in per_floor:
		var nodes: Array = per_floor[f]
		nodes.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
		for i in nodes.size():
			var n: Dictionary = nodes[i]
			var y := (band_top + band_bottom) / 2.0
			if nodes.size() > 1:
				y = band_top + (band_bottom - band_top) * float(i) / float(nodes.size() - 1)
			var h := hash(str(n.id))
			var jitter := Vector2(float(h % 37) / 36.0 - 0.5, float((h / 37) % 37) / 36.0 - 0.5) * 2.0 * JITTER
			if int(n.floor) == 0 or n.type == "boss":
				jitter = Vector2.ZERO
			_positions[str(n.id)] = Vector2(LEFT + float(f) * FLOOR_SPACING, y) + jitter
	for id in _buttons:
		var b: Control = _buttons[id]
		b.position = _positions[id] - b.size / 2.0
	_max_scroll = maxf(0.0, width - size.x)
	if _focus_id != "":
		scroll_to_node(_focus_id)
	else:
		_set_scroll(_scroll)
	_paths.queue_redraw()


func _set_scroll(value: float) -> void:
	_scroll = clampf(value, 0.0, _max_scroll)
	_canvas.position.x = -_scroll


func _draw_paths() -> void:
	for n in _map:
		var a := str(n.id)
		for child in n.get("children", []):
			var b := str(child)
			if not _positions.has(a) or not _positions.has(b):
				continue
			var walked: bool = a in _visited and b in _visited
			var choice: bool = a == _current
			var color := ORANGE if walked or choice else INK
			if walked:
				_paths.draw_line(_positions[a], _positions[b], color, LINE_WIDTH, true)
			else:
				_dashed(_positions[a], _positions[b], color)
	var start := _first_id()
	if _positions.has(start):
		var flag := MAP_NODE_BUTTON._load(FLAG_PATH)
		var base: Vector2 = _positions[start] + Vector2(-64.0, -40.0)
		if flag != null:
			_paths.draw_texture_rect(flag, Rect2(base - Vector2(32, 32), Vector2(64, 64)), false)
		else:
			_paths.draw_line(base + Vector2(0, 30), base + Vector2(0, -26), INK, 3.0, true)
			_paths.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -26), base + Vector2(26, -16), base + Vector2(0, -6)]), ORANGE)


## A dashed segment from `a` to `b`, trimmed off both node bases.
func _dashed(a: Vector2, b: Vector2, color: Color) -> void:
	var dir := (b - a).normalized()
	var start := a + dir * 40.0
	var end := b - dir * 40.0
	var length := start.distance_to(end)
	var t := 0.0
	while t < length:
		var seg_end := minf(t + DASH, length)
		_paths.draw_line(start + dir * t, start + dir * seg_end, color, LINE_WIDTH, true)
		t += DASH + GAP


func _build_legend() -> void:
	var card := PanelContainer.new()
	card.name = "Legend"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.anchor_left = 1.0
	card.anchor_top = 1.0
	card.anchor_right = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -230.0
	card.offset_top = -330.0
	card.offset_right = -24.0
	card.offset_bottom = -24.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e9dcbc")
	style.border_color = Color("#8a7454")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	var card_art := MAP_NODE_BUTTON._load(LEGEND_CARD_PATH)
	if card_art != null:
		var art_style := StyleBoxTexture.new()
		art_style.texture = card_art
		art_style.content_margin_left = 18
		art_style.content_margin_right = 18
		art_style.content_margin_top = 16
		art_style.content_margin_bottom = 16
		card.add_theme_stylebox_override("panel", art_style)
	else:
		card.add_theme_stylebox_override("panel", style)
	add_child(card)
	_legend_entries = VBoxContainer.new()
	_legend_entries.name = "LegendEntries"
	_legend_entries.add_theme_constant_override("separation", 4)
	card.add_child(_legend_entries)
	for t in LEGEND_TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = MAP_NODE_BUTTON._load(ICON_DIR + t + ".png")
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color("#3a2f27")
		row.add_child(icon)
		var label := Label.new()
		label.text = tr("UI_MAP_LEGEND_%s" % t.to_upper())
		label.add_theme_color_override("font_color", Color("#3a2f27"))
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
		_legend_entries.add_child(row)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_scroll(_scroll - 80.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_scroll(_scroll + 80.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_drag_from = event.position.x
			_drag_scroll = _scroll
	elif event is InputEventMouseMotion and _dragging:
		_set_scroll(_drag_scroll - (event.position.x - _drag_from))
