extends Control

## Hero selection — portrait-based, data-driven. Builds one clickable portrait
## card per hero discovered in run_system/data/heroes/. No hardcoded scene
## button slots (a new hero JSON appears automatically). Portrait is the hero's
## sprite portrait, tinted by the hero's `tint`; locked heroes are dimmed.

const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")
const HERO_DIR := "res://run_system/data/heroes/"
const HERO_SPRITE_DIR := "res://battle_scene/assets/images/heroes/"

@onready var hero_row: HBoxContainer = $HeroRow

var _ascension_slider: HSlider = null
var _ascension_value_label: Label = null


func _ready() -> void:
	_build_hero_cards()
	_build_ascension_slider()


func _build_hero_cards() -> void:
	for child in hero_row.get_children():
		child.queue_free()

	var hero_ids := _list_hero_ids()
	hero_ids.sort()
	for hero_id in hero_ids:
		hero_row.add_child(_make_hero_card(hero_id, _load_hero(hero_id)))


func _make_hero_card(hero_id: String, hero_data: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	card.alignment = BoxContainer.ALIGNMENT_CENTER

	var english_name := str(hero_data.get("name", hero_id))
	var hero_name := Settings.t("HERO_%s_NAME" % hero_id, english_name).to_upper()
	var tint := _parse_tint(str(hero_data.get("tint", "#ffffff")))
	var locked: bool = (
		hero_id == "hero_jerry_killer" and MetaProgress.get_upgrade_level("jerry_unlock") <= 0
	)

	var portrait := TextureButton.new()
	portrait.custom_minimum_size = Vector2(280, 380)
	portrait.ignore_texture_size = true
	portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var tex := _load_portrait(str(hero_data.get("sprite_id", hero_id)))
	if tex:
		portrait.texture_normal = tex
	if locked:
		portrait.modulate = Color(0.28, 0.28, 0.30)
		portrait.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		portrait.modulate = tint
		portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		portrait.pressed.connect(func() -> void: _select_hero(hero_id))
		portrait.mouse_entered.connect(func() -> void: portrait.modulate = tint.lightened(0.15))
		portrait.mouse_exited.connect(func() -> void: portrait.modulate = tint)
	card.add_child(portrait)

	var name_label := Label.new()
	name_label.text = hero_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.62) if locked else tint)
	card.add_child(name_label)

	if locked:
		var lock := Label.new()
		lock.text = tr("UI_HERO_LOCKED_SHORT")
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 20)
		lock.add_theme_color_override("font_color", Color(0.85, 0.62, 0.32))
		card.add_child(lock)

	return card


func _parse_tint(hex: String) -> Color:
	if hex.is_valid_html_color():
		return Color(hex)
	return Color.WHITE


func _load_portrait(sprite_id: String) -> Texture2D:
	var path := "%s%s/%s_portrait.png" % [HERO_SPRITE_DIR, sprite_id, sprite_id]
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	push_warning("hero_select: missing portrait '%s'" % path)
	return null


func _build_ascension_slider() -> void:
	if MetaProgress.max_ascension <= 0:
		return  # nothing to choose

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vbox.position.y = -110
	add_child(vbox)

	var label := Label.new()
	label.text = tr("UI_HERO_ASCENSION")
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	_ascension_slider = HSlider.new()
	_ascension_slider.min_value = 0
	_ascension_slider.max_value = MetaProgress.max_ascension
	_ascension_slider.step = 1
	_ascension_slider.value = MetaProgress.max_ascension  # default to highest
	_ascension_slider.custom_minimum_size = Vector2(240, 24)
	_ascension_slider.value_changed.connect(_on_ascension_changed)
	row.add_child(_ascension_slider)

	_ascension_value_label = Label.new()
	_ascension_value_label.text = tr("UI_HERO_ASCENSION_VALUE").format(
		{"n": int(_ascension_slider.value)}
	)
	_ascension_value_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(_ascension_value_label)


func _on_ascension_changed(value: float) -> void:
	if _ascension_value_label:
		_ascension_value_label.text = tr("UI_HERO_ASCENSION_VALUE").format({"n": int(value)})


func _list_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(HERO_DIR)
	if dir == null:
		return ids
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			ids.append(file_name.get_basename())
	return ids


func _load_hero(hero_id: String) -> Dictionary:
	var path := HERO_DIR + hero_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _select_hero(hero_id: String) -> void:
	var asc: int = MetaProgress.max_ascension
	if _ascension_slider:
		asc = int(_ascension_slider.value)
	RunManager.start_new_run(hero_id, [], asc)
	get_tree().change_scene_to_packed(MAP_PACKED)
