extends Control

## One node on the act map: an octagon base with the room's icon. States:
## "available" (pulses, hover grows it, a click chooses it), "current" (orange
## ring), "visited" (darker base) and "unreachable" (faded). Draws the octagon
## in code until the map art exists (run_system/assets/images/map/).

signal chosen(node_id: String)

const ICON_DIR := "res://run_system/assets/images/map/nodes/"
const ART_DIR := "res://run_system/assets/images/map/"
const SIZE := 72.0
const BOSS_SIZE := 104.0
const PULSE_PERIOD := 1.2
const PULSE_SCALE := 0.06
const HOVER_SCALE := 1.15
const INK := Color("#3a2f27")
const INK_VISITED := Color("#211a15")
const CREAM := Color("#efe2c4")
const RING := Color("#e8742a")

var node_id := ""
var node_type := ""
var state := "unreachable"
var interactive := false
var _hovered := false
var _time := 0.0
var _base_texture: Texture2D
var _icon: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	mouse_entered.connect(func(): _hovered = true)
	mouse_exited.connect(func(): _hovered = false)


## Shows `node` ({id, type}) in `node_state`; only an interactive "available"
## node can be chosen.
func setup(node: Dictionary, node_state: String, is_interactive: bool) -> void:
	node_id = str(node.get("id", ""))
	node_type = str(node.get("type", "enemy"))
	state = node_state
	interactive = is_interactive and state == "available"
	var side := BOSS_SIZE if node_type == "boss" else SIZE
	custom_minimum_size = Vector2.ONE * side
	size = custom_minimum_size
	pivot_offset = size / 2.0
	var inset := side * 0.2
	_icon.position = Vector2.ONE * inset
	_icon.size = Vector2.ONE * (side - inset * 2.0)
	_icon.texture = _load(ICON_DIR + node_type + ".png")
	var art_state := "visited" if state == "visited" else ("unreachable" if state == "unreachable" else "available")
	_base_texture = _load(ART_DIR + ("node_octagon_boss.png" if node_type == "boss" else "node_octagon_%s.png" % art_state))
	modulate.a = 0.45 if state == "unreachable" else 1.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var target := 1.0
	if interactive:
		target = HOVER_SCALE if _hovered else 1.0 + PULSE_SCALE * (0.5 + 0.5 * sin(_time * TAU / PULSE_PERIOD))
	scale = scale.lerp(Vector2.ONE * target, minf(1.0, delta * 12.0))


func _draw() -> void:
	var c := size / 2.0
	var r := size.x * 0.46
	if _base_texture != null:
		draw_texture_rect(_base_texture, Rect2(Vector2.ZERO, size), false)
	else:
		var points := PackedVector2Array()
		for i in 8:
			var a := TAU * (float(i) + 0.5) / 8.0
			points.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(points, INK_VISITED if state == "visited" else INK)
		points.append(points[0])
		var available := state == "available"
		draw_polyline(points, CREAM if available else CREAM.darkened(0.35), 4.0 if available else 2.0, true)
	if state == "current":
		draw_arc(c, r + 6.0, 0.0, TAU, 40, RING, 5.0, true)


func _gui_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		chosen.emit(node_id)


static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
