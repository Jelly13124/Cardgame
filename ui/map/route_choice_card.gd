extends Control

## One choice card on the route map: the room's icon and name, the rewards its
## node prints (core/run/map_generator.gd), and the room icons of the floor it
## leads to. Emits `chosen` on a left click when interactive; the map screen
## decides what choosing does.

signal chosen(node_id: String)

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const NODE_ICON_DIR := "res://run_system/assets/images/map/nodes/"
const CAPS_ICON := "res://run_system/assets/images/home/currency/caps.png"
const SCRAP_ICON := "res://run_system/assets/images/home/currency/scrap.png"
## The route screen keeps three equally weighted choices visible at once. The
## slightly wider card leaves enough room for a readable encounter preview and
## reward rows without turning the card into a dense panel.
const CARD_SIZE := Vector2(320, 460)
const ENCOUNTERS = preload("uid://mlx3xqfjwlpq")  # res://core/run/encounters.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const ENEMY_ART_DIR := "res://battle_scene/assets/images/enemies/"
const MAX_PORTRAITS := 3
const PORTRAIT_PX := 48
const STRENGTH_COLORS := {"weak": T.ACCENT_NEON_GREEN, "normal": T.UI_HEADER_GOLD, "strong": T.ACCENT_DANGER}

var node_id := ""
var interactive := false
var _style: StyleBox
var _hover_style: StyleBox
var _panel: PanelContainer
var _hover_tween: Tween


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = panel
	# The route card itself is the content target. Keep its normal state open so
	# the shared beige panel skin cannot read as a second, empty card frame.
	_style = StyleBoxEmpty.new()
	_hover_style = T.semantic_outline(T.ACCENT_NEON_BLUE, 2, 8)
	_hover_style.content_margin_left = 18
	_hover_style.content_margin_right = 18
	_hover_style.content_margin_top = 16
	_hover_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", _style)
	add_child(panel)

	# A compact index makes the three-choice structure scannable and mirrors the
	# number-key shortcuts shown by the map screen. It is deliberately a small
	# flat badge instead of a second decorative frame around the card.
	var choice_number := PanelContainer.new()
	choice_number.name = "ChoiceNumber"
	choice_number.anchor_left = 0.0
	choice_number.anchor_top = 0.0
	choice_number.anchor_right = 0.0
	choice_number.anchor_bottom = 0.0
	choice_number.offset_left = 14.0
	choice_number.offset_top = 12.0
	choice_number.offset_right = 48.0
	choice_number.offset_bottom = 46.0
	choice_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number_style := StyleBoxFlat.new()
	number_style.bg_color = Color(0.08, 0.055, 0.025, 0.94)
	number_style.border_color = T.GLASS_GOLD
	number_style.set_border_width_all(1)
	number_style.set_corner_radius_all(17)
	number_style.content_margin_left = 2.0
	number_style.content_margin_right = 2.0
	choice_number.add_theme_stylebox_override("panel", number_style)
	var number_label := Label.new()
	number_label.name = "Label"
	number_label.text = "•"
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.add_theme_color_override("font_color", T.TEXT_MAIN)
	number_label.add_theme_font_size_override("font_size", 20)
	choice_number.add_child(number_label)
	add_child(choice_number)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_unique(box, icon, "TypeIcon")

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	T.style_display(title, 24)
	_add_unique(box, title, "TypeName")

	var foes := HBoxContainer.new()
	foes.alignment = BoxContainer.ALIGNMENT_CENTER
	foes.add_theme_constant_override("separation", 6)
	foes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foes)
	var portraits := HBoxContainer.new()
	portraits.add_theme_constant_override("separation", 4)
	portraits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_unique(foes, portraits, "Portraits")
	var tag := Label.new()
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	T.style_display(tag, 18)
	tag.visible = false
	_add_unique(foes, tag, "StrengthTag")

	var rewards := VBoxContainer.new()
	rewards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 5)
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_unique(box, rewards, "Rewards")

	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var next_label := Label.new()
	next_label.text = tr("UI_ROUTE_NEXT")
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_color_override("font_color", T.UI_LABEL_DIM)
	next_label.add_theme_font_size_override("font_size", 15)
	box.add_child(next_label)

	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_CENTER
	next_row.add_theme_constant_override("separation", 8)
	next_row.custom_minimum_size = Vector2(0, 24)
	next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_unique(box, next_row, "NextRow")

	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


## Shows `node` ({id, type, rewards}); `next_types` are the room types of the
## floor it leads to; `heal_amount` is what a campfire would heal now.
func setup(
	node: Dictionary,
	next_types: Array,
	heal_amount: int,
	is_interactive: bool,
	choice_index: int = 0
) -> void:
	node_id = str(node.get("id", ""))
	interactive = is_interactive
	get_node("ChoiceNumber/Label").text = str(choice_index) if choice_index > 0 else "•"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	var type := str(node.get("type", "enemy"))
	%TypeIcon.texture = _icon(NODE_ICON_DIR + type + ".png")
	%TypeName.text = tr("UI_MAP_LEGEND_%s" % type.to_upper())
	for c in %Rewards.get_children():
		c.queue_free()
		%Rewards.remove_child(c)
	_show_foes(str(node.get("encounter", "")), str(node.get("strength", "")))
	var rewards: Dictionary = node.get("rewards", {})
	match type:
		"enemy", "elite":
			_add_row(CAPS_ICON, "+%d" % int(rewards.get("gold", 0)), T.TEXT_MAIN)
			if type == "elite":
				_add_row(SCRAP_ICON, "+%d" % int(rewards.get("scrap", 0)), T.TEXT_MAIN)
			_add_row("", tr("UI_ROUTE_CARD_DRAFT"), T.ACCENT_NEON_BLUE)
		"rest":
			_add_row("", tr("UI_ROUTE_HEAL").format({"n": heal_amount}), T.ACCENT_NEON_GREEN)
		"treasure":
			_add_row("", tr("UI_ROUTE_RELIC_CHOICE"), T.UI_HEADER_GOLD)
	for c in %NextRow.get_children():
		c.queue_free()
		%NextRow.remove_child(c)
	for t in next_types:
		var small := TextureRect.new()
		small.texture = _icon(NODE_ICON_DIR + str(t) + ".png")
		small.custom_minimum_size = Vector2(24, 24)
		small.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		small.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Tooltip.bind_hover(small, tr("UI_MAP_LEGEND_%s" % str(t).to_upper()))
		%NextRow.add_child(small)


## Up to three monster portraits of `encounter` and its strength tag
## (hidden when `strength` is "": elites and non-fights).
func _show_foes(encounter: String, strength: String) -> void:
	for c in %Portraits.get_children():
		%Portraits.remove_child(c)
		c.queue_free()
	var shown := 0
	for monster_id in ENCOUNTERS.monsters_of(encounter):
		if shown >= MAX_PORTRAITS:
			break
		var sprite := str(MODEL_DB.data("monster", monster_id).get("sprite_id", monster_id.get_slice(":", monster_id.get_slice_count(":") - 1)))
		var tex := _icon("%s%s/attack/%s_attack_0.png" % [ENEMY_ART_DIR, sprite, sprite])
		if tex == null:
			continue
		var face := TextureRect.new()
		face.texture = tex
		face.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%Portraits.add_child(face)
		shown += 1
	%StrengthTag.visible = strength != ""
	if strength != "":
		%StrengthTag.text = tr("UI_ROUTE_STRENGTH_%s" % strength.to_upper())
		%StrengthTag.add_theme_color_override("font_color", STRENGTH_COLORS.get(strength, T.UI_HEADER_GOLD))


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		chosen.emit(node_id)


func _set_hover(on: bool) -> void:
	if not interactive:
		return
	_panel.add_theme_stylebox_override("panel", _hover_style if on else _style)
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * (1.035 if on else 1.0),
		0.05 if on else 0.5
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _add_row(icon_path: String, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_path != "":
		var icon := TextureRect.new()
		icon.texture = _icon(icon_path)
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	T.style_display(label, 20)
	row.add_child(label)
	%Rewards.add_child(row)


func _add_unique(parent: Node, child: Node, child_name: String) -> void:
	child.name = child_name
	parent.add_child(child)
	child.owner = self
	child.unique_name_in_owner = true


static func _icon(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
