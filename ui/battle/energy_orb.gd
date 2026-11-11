## Five original art layers and independent feedback around an unchanged energy count.
extends Control

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const DISPLAY_SIZE := Vector2(128, 128)
const CHARGED_SPEEDS := Vector2(30, 60)
const EMPTY_SPEEDS := Vector2(5, 10)
const IN_SECONDS := 0.6
const OUT_SECONDS := 0.6
const HIDDEN_POSITION := Vector2(-480, 128)

var _visuals: Control
var _transition: Tween
var _layers: Array[TextureRect] = []
var _flash: TextureRect
var _label: Label
var _value := -1
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = DISPLAY_SIZE * 0.5
	_visuals = Control.new()
	_visuals.name = "EnergyVisuals"
	_visuals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visuals.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visuals)
	for i in range(1, 6):
		var layer := _add_layer("EnergyLayer%d" % i, "energy_layer_%d" % i)
		_layers.append(layer)
	_flash = _add_layer("EnergyFlash", "energy_flash")
	_flash.modulate.a = 0.0


func configure(label: Label) -> void:
	_label = label
	label.reparent(_visuals, false)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", T.combat_font(700))
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", T.COMBAT_HP_TEXT)
	label.add_theme_color_override("font_outline_color", T.COMBAT_HP_OUTLINE)
	label.add_theme_constant_override("outline_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _add_layer(layer_name: String, texture_name: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.texture = T.combat_tex(texture_name)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.size = DISPLAY_SIZE
	layer.pivot_offset = DISPLAY_SIZE * 0.5
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visuals.add_child(layer)
	return layer


func set_energy(current: int, maximum: int) -> void:
	var restored := _value >= 0 and current > _value
	_value = current
	if _label:
		_label.text = "%d/%d" % [current, maximum]
	for layer in _layers:
		layer.self_modulate = T.ENERGY_EMPTY_TINT if current == 0 else Color.WHITE
	if current == 0:
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash.modulate.a = 0.0
	elif restored:
		_flash_restored_energy()


func layer_rotation_speeds() -> Vector2:
	return EMPTY_SPEEDS if _value == 0 else CHARGED_SPEEDS


func _process(delta: float) -> void:
	if _layers.size() < 3:
		return
	var speeds := layer_rotation_speeds()
	_layers[1].rotation += deg_to_rad(speeds.x) * delta
	_layers[2].rotation += deg_to_rad(speeds.y) * delta


func _flash_restored_energy() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func anim_in() -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_visuals.position = HIDDEN_POSITION
	_transition = create_tween()
	_transition.tween_property(_visuals, "position", Vector2.ZERO, IN_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func anim_out() -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_transition = create_tween()
	_transition.tween_property(_visuals, "position", HIDDEN_POSITION, OUT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
