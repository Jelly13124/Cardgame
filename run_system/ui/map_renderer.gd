## Renders the wasteland map (background, paths, nodes, legend, top bar).
## Owned by MapScene; called from MapScene._draw(). All drawing happens on the
## owning MapScene CanvasItem — this class does not own a CanvasItem of its own.
##
## Reads scene state through `_scene.X` (rm, _node_icon_textures, _node_positions,
## _scroll_offset, _hovered_node_id, _get_screen_pos, _is_accessible).
extends RefCounted
class_name MapRenderer

const NODE_RADIUS: float = 40.0
const NODE_ICON_SIZE: float = 78.0
const LEGEND_NODE_ICON_SIZE: float = 24.0

# Legend labels are localized at draw time via tr() (see _draw_legend); the
# second column is the translation key, not the display string.
const LEGEND_ENTRIES = [
	["relic", "UI_MAP_LEGEND_RELIC"],
	["unknown", "UI_MAP_LEGEND_UNKNOWN"],
	["merchant", "UI_MAP_LEGEND_MERCHANT"],
	["treasure", "UI_MAP_LEGEND_TREASURE"],
	["rest", "UI_MAP_LEGEND_REST"],
	["enemy", "UI_MAP_LEGEND_ENEMY"],
	["elite", "UI_MAP_LEGEND_ELITE"],
	["boss", "UI_MAP_LEGEND_BOSS"],
]

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

var _scene: Control
var _font: Font


func _init(scene: Control) -> void:
	_scene = scene
	_font = ThemeDB.fallback_font


## Main entry point — called from MapScene._draw().
func draw(vp: Vector2) -> void:
	_draw_map_background(vp)
	if _scene.rm.map_data.is_empty():
		return
	_draw_all_paths(vp)
	_draw_all_nodes(vp)
	_draw_legend(vp)


func _draw_map_background(vp: Vector2) -> void:
	if _scene.map_background_tex:
		_scene.draw_texture_rect(_scene.map_background_tex, Rect2(Vector2.ZERO, vp), false)
	else:
		_scene.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.08, 0.08, 0.1, 1.0))
	_scene.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.018, 0.01, 0.12))


func _draw_all_paths(vp: Vector2) -> void:
	var visited: Array = _scene.rm.visited_node_ids
	var current_id: String = _scene.rm.current_node_id

	for node in _scene.rm.map_data:
		if node.children.is_empty():
			continue

		var from = _scene._get_screen_pos(node.id)
		for child_id in node.children:
			var to = _scene._get_screen_pos(child_id)
			if from.x < -70 and to.x < -70:
				continue
			if from.x > vp.x + 70 and to.x > vp.x + 70:
				continue

			# Edge is "walked" only if BOTH endpoints have been visited
			# in walk order — i.e. parent visited AND child visited.
			var walked: bool = (node.id in visited) and (child_id in visited)
			# Edge is "available" (next possible step) if parent is the
			# current node and the child hasn't been entered yet.
			var available: bool = (node.id == current_id) and not (child_id in visited)

			if walked:
				# Walked route: solid glowing cyan (slightly warm tint to read as "past")
				var core = Color(0.55, 1.0, 0.98, 0.92)
				_draw_solid_glow_line(from, to, core, 2.5, 9.0)
			elif available:
				# Available (next step): solid glowing bright cyan — most prominent
				var core = Color(0.40, 0.96, 1.0, 1.0)
				_draw_solid_glow_line(from, to, core, 2.8, 12.0)
			else:
				# Unreachable / future: grey dashed — dark enough to read on the
				# bright sand (alpha 0.22 was invisible), still clearly secondary.
				_draw_pixel_dashed_line(
					from, to, Color(0.24, 0.22, 0.20, 0.55), 2.2, 12.0, 8.0, Vector2.ZERO
				)


func _draw_all_nodes(vp: Vector2) -> void:
	var visited_list: Array = _scene.rm.visited_node_ids

	for node in _scene.rm.map_data:
		var pos = _scene._get_screen_pos(node.id)
		if pos.x < -60 or pos.x > vp.x + 60:
			continue

		var accessible = _scene._is_accessible(node)
		var is_current = node.id == _scene.rm.current_node_id
		var visited = node.id in visited_list  # true ID-based history, not floor heuristic
		var hovered = node.id == _scene._hovered_node_id and accessible

		# Alpha tiers:
		#   current        : 1.0  (full bright + bracket)
		#   walked (visited): 0.75 (clearly drawn but dimmed vs current)
		#   accessible      : 1.0  (next step — full bright so it pops)
		#   unreachable     : 0.30 (very dim so it visually fades into background)
		var alpha = 1.0
		if is_current:
			alpha = 1.0
		elif visited:
			alpha = 0.75
		elif accessible:
			alpha = 1.0
		else:
			alpha = 0.30

		var radius = NODE_RADIUS + (4.0 if hovered else 0.0)
		_draw_map_node(pos, node.type, radius, alpha, accessible, visited, is_current, hovered)


func _draw_map_node(
	pos: Vector2,
	node_type: String,
	radius: float,
	alpha: float,
	accessible: bool,
	visited: bool,
	is_current: bool,
	hovered: bool
) -> void:
	# Hover affordance is pure passive — bigger icon + slightly brighter tint.
	# No overlay rectangle / brackets / accessibility dot. The current node
	# still gets a yellow bracket so "you are here" reads at a glance.
	var icon_size = NODE_ICON_SIZE + (8.0 if hovered else 0.0) + (4.0 if is_current else 0.0)
	var tint = Color(1.0, 1.0, 1.0, alpha)
	if not accessible and not visited:
		tint = Color(0.88, 0.84, 0.76, alpha)
	elif visited and not is_current:
		tint = Color(0.80, 0.76, 0.66, maxf(alpha, 0.62))
	if hovered:
		# Subtle warm brightness boost — combined with the +8px icon growth
		# this reads as "this node is highlighted" without any overlay.
		tint = Color(
			minf(1.0, tint.r * 1.18), minf(1.0, tint.g * 1.12), minf(1.0, tint.b * 1.04), tint.a
		)

	if is_current:
		_draw_pixel_selection(pos, radius + 10.0, Color(1.0, 0.92, 0.25, 1.0))

	_draw_node_texture(pos, node_type, icon_size, tint)


func _draw_node_texture(pos: Vector2, node_type: String, icon_size: float, tint: Color) -> void:
	var texture: Texture2D = _scene._node_icon_textures.get(node_type, null)
	if texture:
		var rect = Rect2(
			pos - Vector2(icon_size * 0.5, icon_size * 0.5), Vector2(icon_size, icon_size)
		)
		var outline = Color(0.04, 0.025, 0.012, tint.a * 0.58)
		_draw_node_texture_rect(texture, rect, Vector2(2, 2), outline)
		_draw_node_texture_rect(texture, rect, Vector2(-1, 0), outline)
		_draw_node_texture_rect(texture, rect, Vector2(1, 0), outline)
		_draw_node_texture_rect(texture, rect, Vector2(0, -1), outline)
		_draw_node_texture_rect(texture, rect, Vector2(0, 1), outline)
		_scene.draw_texture_rect(texture, rect, false, tint)
		return

	var type_color: Color = TYPE_COLORS.get(node_type, Color.GRAY)
	_scene.draw_string(
		_font,
		pos + Vector2(-5, 7),
		"?",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		int(icon_size),
		Color(type_color.r, type_color.g, type_color.b, tint.a)
	)


func _draw_node_texture_rect(texture: Texture2D, rect: Rect2, offset: Vector2, tint: Color) -> void:
	_scene.draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, tint)


func _draw_pixel_selection(center: Vector2, radius: float, color: Color) -> void:
	var left = center.x - radius
	var right = center.x + radius
	var top = center.y - radius
	var bottom = center.y + radius
	var corner = minf(8.0, radius * 0.38)
	var width = 2.0

	_scene.draw_line(Vector2(left, top), Vector2(left + corner, top), color, width)
	_scene.draw_line(Vector2(left, top), Vector2(left, top + corner), color, width)
	_scene.draw_line(Vector2(right, top), Vector2(right - corner, top), color, width)
	_scene.draw_line(Vector2(right, top), Vector2(right, top + corner), color, width)
	_scene.draw_line(Vector2(left, bottom), Vector2(left + corner, bottom), color, width)
	_scene.draw_line(Vector2(left, bottom), Vector2(left, bottom - corner), color, width)
	_scene.draw_line(Vector2(right, bottom), Vector2(right - corner, bottom), color, width)
	_scene.draw_line(Vector2(right, bottom), Vector2(right, bottom - corner), color, width)


func _draw_legend(vp: Vector2) -> void:
	var pw = 156.0
	var ph = 248.0
	var px = vp.x - pw - 18.0
	# Start below the taller framed top bar (main bar ≈ 86px) so it isn't occluded.
	var py = 96.0
	var rect = Rect2(px, py, pw, ph)

	# Drop shadow
	_scene.draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color(0.0, 0.0, 0.0, 0.55))
	# Dark background panel
	_scene.draw_rect(rect, Color(0.06, 0.07, 0.09, 0.94))
	# Subtle inner highlight at top (gives depth)
	_scene.draw_rect(Rect2(px, py, pw, 2.0), Color(0.35, 0.80, 0.95, 0.22))
	# Cyan-tinted border to match the glowing path theme
	_scene.draw_rect(rect, Color(0.28, 0.72, 0.85, 0.75), false, 1.5)

	# Title
	var y = py + 24.0
	var title_text = tr("UI_MAP_LEGEND_TITLE")
	var title_w = _font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_scene.draw_string(
		_font,
		Vector2(px + (pw - title_w) * 0.5, y),
		title_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		Color(0.70, 0.92, 0.98, 1.0)
	)
	y += 7.0
	# Separator line in dim cyan
	_scene.draw_line(
		Vector2(px + 8, y), Vector2(px + pw - 8, y), Color(0.30, 0.72, 0.88, 0.45), 1.0
	)
	y += 16.0

	for entry in LEGEND_ENTRIES:
		_draw_node_texture(
			Vector2(px + 20, y - 6), str(entry[0]), LEGEND_NODE_ICON_SIZE, Color(1.0, 1.0, 1.0, 1.0)
		)
		_scene.draw_string(
			_font,
			Vector2(px + 36, y),
			tr(str(entry[1])),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.82, 0.88, 0.92, 0.95)
		)
		y += 26.0


## Draws a solid glowing line: a wide translucent glow underlay + a bright thin core on top.
## Used for walked and available edges so the active route reads as a lit, solid path.
func _draw_solid_glow_line(
	from: Vector2, to: Vector2, core_color: Color, core_width: float, glow_width: float
) -> void:
	var glow_color = Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.22)
	_scene.draw_line(from, to, glow_color, glow_width)
	var mid_color = Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.50)
	_scene.draw_line(from, to, mid_color, glow_width * 0.50)
	_scene.draw_line(from, to, core_color, core_width)


func _draw_pixel_dashed_line(
	from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float, offset: Vector2
) -> void:
	var length = from.distance_to(to)
	if length < 1.0:
		return
	var dir = (to - from).normalized()
	var distance = 0.0
	while distance < length:
		var start = from + dir * distance + offset
		var end = from + dir * minf(distance + dash, length) + offset
		_scene.draw_line(start, end, color, width)
		distance += dash + gap
