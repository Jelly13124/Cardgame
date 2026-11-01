extends Node2D

## The one floating damage number (STS2 NDamageNumVfx): it pops in large,
## launches up with a little sideways drift, falls under gravity, tints toward
## cream and fades. Every hit and direct HP loss spawns it through `spawn()`.

const GRAVITY := Vector2(0.0, 2000.0)
const SPAWN_OFFSET := Vector2(0.0, -100.0)
const CREAM := Color(1.0, 0.95, 0.82, 1.0)
const BASE_FONT_SIZE := 44
const POP_SCALE := 2.5
const SETTLE_SECONDS := 1.2
const TINT_SECONDS := 0.5
const FADE_SECONDS := 2.0
## Direct HP loss (no hit): curses, events, self-damage.
const HP_LOSS_COLOR := Color(1.0, 0.55, 0.45, 1.0)
const OUTLINE := Color(0.055, 0.045, 0.035, 0.98)

var velocity := Vector2.ZERO


## Spawns `text` above `world_pos` on its own top layer. `emphasis` scales the
## font (heavy and lethal hits read larger); `color` is the colour it starts at.
static func spawn(
	scene_root: Node, world_pos: Vector2, text: String, color: Color, emphasis := 1.0
) -> Node2D:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return null
	var layer := CanvasLayer.new()
	layer.name = "CombatDamageNumber"
	layer.layer = 51
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer)

	var number = load("uid://clps6my10jkri").new()  # res://ui/battle/damage_number_vfx.gd
	number.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(number)

	var label := Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(BASE_FONT_SIZE * emphasis))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	number.add_child(label)
	label.size = label.get_minimum_size()
	label.position = -label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * randf_range(1.2, 1.3)
	label.modulate = color

	number.position = world_pos + SPAWN_OFFSET + Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 5.0))
	number.rotation_degrees = randf_range(-5.0, 5.0)
	number.velocity = Vector2(randf_range(-100.0, 100.0), randf_range(-800.0, -700.0))
	number.scale = Vector2.ONE * POP_SCALE

	var tween: Tween = number.create_tween().set_parallel(true)
	tween.tween_property(label, "modulate", CREAM, TINT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(number, "scale", Vector2.ONE, SETTLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(layer.queue_free)
	return number


func _process(delta: float) -> void:
	position += velocity * delta
	velocity += GRAVITY * delta
