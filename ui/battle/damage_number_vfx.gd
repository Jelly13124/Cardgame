extends Node2D

## The one floating combat number (STS2 NDamageNumVfx / NHealNumVfx /
## NDamageBlockedVfx; colours and font read from STS2's vfx scenes).
## Damage pops in large and red, launches up, falls under gravity, turns
## cream and fades. Healing pops in green and fades. A fully blocked hit
## shows BLOCKED, blue turning white, drifting up as it shrinks.

const KIND_DAMAGE := "damage"
const KIND_HEAL := "heal"
const KIND_BLOCKED := "blocked"

const GRAVITY := Vector2(0.0, 2000.0)
const SPAWN_OFFSET := Vector2(0.0, -100.0)
const DAMAGE_RED := Color(0.97, 0.16684, 0.0776, 1.0)
const HEAL_GREEN := Color(0.137093, 0.97, 0.0776, 1.0)
const BLOCKED_BLUE := Color("21C0FF")
## STS2 StsColors.cream.
const CREAM := Color("FFF6E2")
const FONT_SIZE := 64
const OUTLINE := Color(0.21, 0.202685, 0.1869, 1.0)
const OUTLINE_SIZE := 20
const SHADOW := Color(0.0, 0.0, 0.0, 0.12549)
const SHADOW_OFFSET := Vector2i(5, 4)
const POP_SCALE := 2.5
const SETTLE_SECONDS := 1.2
const TINT_SECONDS := 0.5
const FADE_SECONDS := 2.0

## Pixels per second; only damage numbers fly.
var velocity := Vector2.ZERO


## A damage number: red, then cream. `emphasis` scales the font (heavy and
## lethal hits read larger).
static func spawn(scene_root: Node, world_pos: Vector2, amount: int, emphasis := 1.0) -> Node2D:
	var number := _make(scene_root, world_pos + SPAWN_OFFSET, str(amount), DAMAGE_RED, emphasis)
	if number == null:
		return null
	number.position += Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 5.0))
	number.rotation_degrees = randf_range(-5.0, 5.0)
	number.velocity = Vector2(randf_range(-100.0, 100.0), randf_range(-800.0, -700.0))
	number.get_node("Label").scale = Vector2.ONE * randf_range(1.2, 1.3)
	number.scale = Vector2.ONE * POP_SCALE
	var label: Label = number.get_node("Label")
	var tween: Tween = number.create_tween().set_parallel(true)
	tween.tween_property(label, "modulate", CREAM, TINT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(number, "scale", Vector2.ONE, SETTLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(number.get_parent().queue_free)
	return number


## A heal number: green, settles from its pop and fades after a second.
static func spawn_heal(scene_root: Node, world_pos: Vector2, amount: int) -> Node2D:
	var number := _make(scene_root, world_pos + SPAWN_OFFSET, str(amount), HEAL_GREEN, 1.0)
	if number == null:
		return null
	number.scale = Vector2.ONE * 1.5
	var tween: Tween = number.create_tween().set_parallel(true)
	tween.tween_property(number, "modulate:a", 0.0, 0.3).set_delay(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(number, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(number.get_parent().queue_free)
	return number


## BLOCKED: blue turning white, rising 250 px while shrinking to 0.6.
static func spawn_blocked(scene_root: Node, world_pos: Vector2) -> Node2D:
	var number := _make(scene_root, world_pos + SPAWN_OFFSET, TranslationServer.translate("UI_COMBAT_BLOCKED"), BLOCKED_BLUE, 0.75)
	if number == null:
		return null
	var label: Label = number.get_node("Label")
	var tween: Tween = number.create_tween().set_parallel(true)
	tween.tween_property(number, "scale", Vector2.ONE * 0.6, 2.0).from(Vector2.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "position:y", number.position.y - 250.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(number.get_parent().queue_free)
	return number


## The number node on its own top layer: a cream label with STS2's outline and
## shadow, tinted `color`.
static func _make(scene_root: Node, pos: Vector2, text: String, color: Color, emphasis: float) -> Node2D:
	if not is_instance_valid(scene_root) or scene_root.get_tree() == null:
		return null
	var layer := CanvasLayer.new()
	layer.name = "CombatDamageNumber"
	layer.layer = 51
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(layer, true)  # readable names stay countable when numbers overlap

	var number = load("uid://clps6my10jkri").new()  # res://ui/battle/damage_number_vfx.gd
	number.process_mode = Node.PROCESS_MODE_ALWAYS
	number.position = pos
	layer.add_child(number)

	var label := Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * emphasis))
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", SHADOW_OFFSET.x)
	label.add_theme_constant_override("shadow_offset_y", SHADOW_OFFSET.y)
	label.add_theme_constant_override("shadow_outline_size", OUTLINE_SIZE)
	number.add_child(label)
	label.size = label.get_minimum_size()
	label.position = -label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.modulate = color
	return number


func _process(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	position += velocity * delta
	velocity += GRAVITY * delta
