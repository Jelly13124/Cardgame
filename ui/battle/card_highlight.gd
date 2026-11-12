extends ColorRect

## Playable-card outline (STS2 NCardHighlight): a shader traces the card's
## silhouette, so the glow hugs the card shape. Shown on every hand card that
## can be played right now; the width eases in/out instead of popping.

const SHADER = preload("res://ui/battle/card_highlight.gdshader")
const COLOR := Color(0.2, 0.92, 1.0, 0.98)
## Resting outline width in pixels. The pulse breathes around this value while
## staying close to the card edge, rather than becoming a decorative frame.
const WIDTH := 9.0
## STS2-style playable feedback breathes visibly after the 0.5 s reveal. Both
## opacity and thickness move together so the cue reads at a glance over bright
## or dark card art.
const PULSE_PERIOD := 1.0
const PULSE_MIN_ALPHA := 0.25
const PULSE_MAX_ALPHA := 1.0
const PULSE_MIN_WIDTH := 7.0
const PULSE_MAX_WIDTH := 13.0
## The rect extends this far beyond the card on every side.
const MARGIN := 12.0

var _target := 0.0
var _tween: Tween
var _pulse_enabled := false
var _pulse_time := 0.0


func _init() -> void:
	name = "CardHighlight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("glow_color", COLOR)
	shader_material.set_shader_parameter("margin", MARGIN)
	shader_material.set_shader_parameter("width_px", 0.0)
	material = shader_material
	set_process(true)


## Outline the silhouette of `texture` drawn at `card_size`.
func set_source(texture: Texture2D, card_size: Vector2) -> void:
	material.set_shader_parameter("source", texture)
	material.set_shader_parameter("card_size", card_size)
	position = -Vector2(MARGIN, MARGIN)
	size = card_size + Vector2(MARGIN, MARGIN) * 2.0


func is_shown() -> bool:
	return _target > 0.0


func anim_show() -> void:
	if _target > 0.0:
		return
	_target = WIDTH
	_pulse_enabled = false
	_pulse_time = 0.0
	_tween_width(WIDTH, 0.5)


func anim_hide() -> void:
	if _target == 0.0:
		return
	_target = 0.0
	_stop_pulse()
	_tween_width(0.0, 0.5)


func anim_hide_instantly() -> void:
	_target = 0.0
	_stop_pulse()
	if _tween:
		_tween.kill()
	_set_width(0.0)


## Brief widening when a playable card is picked up.
func anim_flash() -> void:
	if _target <= 0.0 or not is_inside_tree():
		return
	var resume_pulse := _pulse_enabled
	_pulse_enabled = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_width, _width(), WIDTH * 2.0, 0.1)
	_tween.tween_method(_set_width, WIDTH * 2.0, WIDTH, 0.35).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	if resume_pulse:
		_tween.tween_callback(_begin_pulse)


func _tween_width(to: float, seconds: float) -> void:
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		_set_width(to)
		if to > 0.0:
			_begin_pulse()
		return
	_tween = create_tween()
	_tween.tween_method(_set_width, _width(), to, seconds).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	if to > 0.0:
		_tween.tween_callback(_begin_pulse)
	else:
		_tween.tween_callback(_stop_pulse)


func _width() -> float:
	return float(material.get_shader_parameter("width_px"))


func _set_width(value: float) -> void:
	material.set_shader_parameter("width_px", value)


func _begin_pulse() -> void:
	if _target <= 0.0:
		return
	_pulse_enabled = true
	_pulse_time = 0.0


func _stop_pulse() -> void:
	_pulse_enabled = false
	_pulse_time = 0.0
	_set_glow_alpha(COLOR.a)


func _set_glow_alpha(value: float) -> void:
	material.set_shader_parameter(
		"glow_color", Color(COLOR.r, COLOR.g, COLOR.b, clampf(value, 0.0, 1.0))
	)


func _process(delta: float) -> void:
	if not _pulse_enabled or _target <= 0.0:
		return
	_pulse_time = fmod(_pulse_time + delta, PULSE_PERIOD)
	var wave := 0.5 + 0.5 * sin(_pulse_time * TAU / PULSE_PERIOD)
	# Smooth the endpoints so the highlight eases into and out of its flash,
	# while the wider width makes the change readable without a hard pop.
	wave = wave * wave * (3.0 - 2.0 * wave)
	_set_glow_alpha(lerpf(PULSE_MIN_ALPHA, PULSE_MAX_ALPHA, wave))
	_set_width(lerpf(PULSE_MIN_WIDTH, PULSE_MAX_WIDTH, wave))
