extends ColorRect

## Playable-card outline (STS2 NCardHighlight): a shader traces the card's
## silhouette, so the glow hugs the card shape. Shown on every hand card that
## can be played right now; the width eases in/out instead of popping.

const SHADER = preload("res://battle_scene/ui/card_highlight.gdshader")
const COLOR := Color(0.2, 0.92, 1.0, 0.98)
## Outline width in pixels when fully shown.
const WIDTH := 9.0
## The rect extends this far beyond the card on every side.
const MARGIN := 12.0

var _target := 0.0
var _tween: Tween


func _init() -> void:
	name = "CardHighlight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("glow_color", COLOR)
	shader_material.set_shader_parameter("margin", MARGIN)
	shader_material.set_shader_parameter("width_px", 0.0)
	material = shader_material


## Outline the silhouette of `texture` drawn at `card_size`.
func set_source(texture: Texture2D, card_size: Vector2) -> void:
	material.set_shader_parameter("source", texture)
	material.set_shader_parameter("card_size", card_size)
	position = -Vector2(MARGIN, MARGIN)
	size = card_size + Vector2(MARGIN, MARGIN) * 2.0


func is_shown() -> bool:
	return _target > 0.0


func anim_show() -> void:
	if _target == WIDTH:
		return
	_target = WIDTH
	_tween_width(WIDTH, 0.5)


func anim_hide() -> void:
	if _target == 0.0:
		return
	_target = 0.0
	_tween_width(0.0, 0.5)


func anim_hide_instantly() -> void:
	_target = 0.0
	if _tween:
		_tween.kill()
	_set_width(0.0)


## Brief widening when a playable card is picked up.
func anim_flash() -> void:
	if _target <= 0.0 or not is_inside_tree():
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_width, _width(), WIDTH * 2.0, 0.1)
	_tween.tween_method(_set_width, WIDTH * 2.0, WIDTH, 0.35).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)


func _tween_width(to: float, seconds: float) -> void:
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		_set_width(to)
		return
	_tween = create_tween()
	_tween.tween_method(_set_width, _width(), to, seconds).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)


func _width() -> float:
	return float(material.get_shader_parameter("width_px"))


func _set_width(value: float) -> void:
	material.set_shader_parameter("width_px", value)
