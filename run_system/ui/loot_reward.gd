extends Control

const GOLD_ICON_PATH := "res://run_system/assets/images/loot_ui/gold_reward.png"
const CARD_REWARD_ICON_PATH := "res://run_system/assets/images/loot_ui/card_reward.png"

const PANEL_BG := Color(0.075, 0.055, 0.045, 0.96)
const PANEL_BORDER := Color(0.45, 0.32, 0.18, 1.0)
const PANEL_HIGHLIGHT := Color(0.92, 0.66, 0.28, 1.0)
const ROW_BG := Color(0.12, 0.09, 0.065, 0.98)
const ROW_HOVER_BG := Color(0.18, 0.125, 0.075, 1.0)
const ROW_PRESSED_BG := Color(0.23, 0.16, 0.08, 1.0)
const TEXT_MAIN := Color(1.0, 0.86, 0.55, 1.0)
const TEXT_SECONDARY := Color(0.72, 0.82, 0.82, 1.0)
const CYAN_EDGE := Color(0.23, 0.78, 0.92, 1.0)

# Card IDs available for drafting - must match filenames in card_info/player/
var draft_pool = [
	"strike", "defend", "override", "preemptive_strike", "weak_strike"
]

@onready var loot_root = $VBoxContainer
@onready var loot_list_container = $VBoxContainer/LootPanel/MarginContainer/LootList
@onready var proceed_button = $VBoxContainer/BottomRow/MarginContainer/ProceedButton
@onready var draft_overlay = $DraftOverlay
@onready var draft_card_container = $DraftOverlay/VBoxContainer/DraftPanel/MarginContainer/CardsContainer
@onready var draft_skip_button = $DraftOverlay/VBoxContainer/BottomRow/MarginContainer/SkipDraftButton

var _card_factory: Node = null
var available_loot = []
var _rarity_pools = {
	"common": [],
	"uncommon": [],
	"rare": []
}


func _ready() -> void:
	randomize()
	proceed_button.pressed.connect(_on_proceed_pressed)
	draft_skip_button.pressed.connect(_on_skip_draft_pressed)
	draft_overlay.visible = false

	_card_factory = preload("res://battle_scene/my_card_factory.tscn").instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(160, 220)

	_apply_static_theme()
	_categorize_cards()
	_generate_loot()
	_populate_loot_ui()


func _apply_static_theme() -> void:
	$VBoxContainer/BannerPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.105, 0.075, 0.055, 0.98), PANEL_HIGHLIGHT, 4))
	$VBoxContainer/LootPanel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, PANEL_BORDER, 5))
	$DraftOverlay/VBoxContainer/DraftPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.05, 0.052, 0.98), PANEL_BORDER, 5))
	_apply_button_theme(proceed_button, Color(0.13, 0.1, 0.075, 1.0), PANEL_HIGHLIGHT)
	_apply_button_theme(draft_skip_button, Color(0.13, 0.1, 0.075, 1.0), PANEL_HIGHLIGHT)


func _generate_loot() -> void:
	available_loot.clear()
	var gold_amount = 10

	available_loot.append({
		"id": "gold",
		"type": "gold",
		"amount": gold_amount,
		"title": "%d Gold" % gold_amount,
		"subtitle": "Recovered from the fight",
		"icon": GOLD_ICON_PATH
	})

	available_loot.append({
		"id": "cards",
		"type": "cards",
		"title": "Card Reward",
		"subtitle": "Choose one card for your deck",
		"icon": CARD_REWARD_ICON_PATH
	})


func _populate_loot_ui() -> void:
	for child in loot_list_container.get_children():
		child.queue_free()

	for loot in available_loot:
		loot_list_container.add_child(_make_loot_row(loot))


func _make_loot_row(loot: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(660, 104)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.add_theme_stylebox_override("normal", _make_reward_row_style(ROW_BG, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", _make_reward_row_style(ROW_HOVER_BG, CYAN_EDGE))
	button.add_theme_stylebox_override("pressed", _make_reward_row_style(ROW_PRESSED_BG, PANEL_HIGHLIGHT))
	button.pressed.connect(_on_loot_selected.bind(str(loot["id"]), button))

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	row.add_child(_make_icon_well(str(loot.get("icon", ""))))

	var copy = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 4)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var title = Label.new()
	title.text = str(loot.get("title", "Reward"))
	title.add_theme_color_override("font_color", TEXT_MAIN)
	title.add_theme_font_size_override("font_size", 31)
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title)

	var subtitle = Label.new()
	subtitle.text = str(loot.get("subtitle", ""))
	subtitle.add_theme_color_override("font_color", TEXT_SECONDARY)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(subtitle)

	row.add_child(_make_claim_plate())
	return button


func _make_icon_well(icon_path: String) -> PanelContainer:
	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(82, 82)
	frame.add_theme_stylebox_override("panel", _make_icon_frame_style())
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)

	var texture = _load_texture(icon_path)
	if texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(68, 68)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var fallback = Label.new()
		fallback.text = "?"
		fallback.add_theme_font_size_override("font_size", 34)
		fallback.add_theme_color_override("font_color", TEXT_MAIN)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(fallback)

	return frame


func _make_claim_plate() -> PanelContainer:
	var plate = PanelContainer.new()
	plate.custom_minimum_size = Vector2(104, 50)
	plate.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.12, 0.13, 1.0), CYAN_EDGE, 3))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label = Label.new()
	label.text = "CLAIM"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.76, 0.96, 1.0, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _on_loot_selected(loot_id: String, button: Button) -> void:
	var loot = null
	for entry in available_loot:
		if entry["id"] == loot_id:
			loot = entry
			break

	if not loot:
		return

	if loot["type"] == "gold":
		var run_manager = get_node_or_null("/root/RunManager")
		if run_manager:
			run_manager.add_resources(loot["amount"], 0)
			print("Claimed %d Gold" % loot["amount"])
		button.queue_free()
	elif loot["type"] == "cards":
		_open_card_draft()
		button.queue_free()


func _on_proceed_pressed() -> void:
	var rm = get_node_or_null("/root/RunManager")
	get_tree().change_scene_to_file(rm.MAP_SCENE if rm else "res://run_system/ui/map_scene.tscn")


func _open_card_draft() -> void:
	loot_root.visible = false
	draft_overlay.visible = true
	_generate_draft_options()


func _categorize_cards() -> void:
	for pool in _rarity_pools.values():
		pool.clear()

	for card_id in draft_pool:
		var info = _card_factory._load_card_info(card_id)
		if info:
			var rarity = info.get("rarity", "common").to_lower()
			if rarity in _rarity_pools:
				_rarity_pools[rarity].append(card_id)
			else:
				_rarity_pools["common"].append(card_id)


func _generate_draft_options() -> void:
	for child in draft_card_container.get_children():
		child.queue_free()

	var draft_options = []
	for i in range(3):
		var roll = randf()
		var picked_rarity = "common"

		if roll < 0.05:
			picked_rarity = "rare"
		elif roll < 0.30:
			picked_rarity = "uncommon"

		if _rarity_pools[picked_rarity].is_empty():
			if picked_rarity == "rare":
				picked_rarity = "uncommon"
			if _rarity_pools[picked_rarity].is_empty():
				picked_rarity = "common"

		var pool = _rarity_pools[picked_rarity]
		if not pool.is_empty():
			var picked_id = pool[randi() % pool.size()]
			if not picked_id in draft_options:
				draft_options.append(picked_id)
			else:
				picked_id = pool[randi() % pool.size()]
				draft_options.append(picked_id)

	for card_id in draft_options:
		draft_card_container.add_child(_make_draft_card_slot(card_id))


func _make_draft_card_slot(card_id: String) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(300, 400)

	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.095, 0.072, 0.055, 0.92), PANEL_BORDER, 4))
	wrapper.add_child(frame)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(70, 88)
		card.scale = Vector2(1.5, 1.5)
		card.pivot_offset = Vector2(80, 110)
		wrapper.add_child(card)

	var button = Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_draft_card_selected.bind(card_id))
	wrapper.add_child(button)

	if card:
		button.mouse_entered.connect(func():
			frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.095, 0.062, 0.96), CYAN_EDGE, 4))
			var tween = create_tween()
			tween.tween_property(card, "scale", Vector2(1.62, 1.62), 0.10)
		)
		button.mouse_exited.connect(func():
			frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.095, 0.072, 0.055, 0.92), PANEL_BORDER, 4))
			var tween = create_tween()
			tween.tween_property(card, "scale", Vector2(1.5, 1.5), 0.10)
		)

	return wrapper


func _on_draft_card_selected(card_id: String) -> void:
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.add_card_to_deck(card_id)
		print("Drafted card: ", card_id)

	_close_card_draft()


func _on_skip_draft_pressed() -> void:
	_close_card_draft()


func _close_card_draft() -> void:
	loot_root.visible = true
	draft_overlay.visible = false


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource

	var file_path = path
	if path.begins_with("res://"):
		file_path = ProjectSettings.globalize_path(path)

	var image = Image.new()
	var err = image.load(file_path)
	if err == OK:
		return ImageTexture.create_from_image(image)

	return null


func _apply_button_theme(button: Button, bg: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(bg, border, 4))
	button.add_theme_stylebox_override("hover", _make_panel_style(bg.lightened(0.12), CYAN_EDGE, 4))
	button.add_theme_stylebox_override("pressed", _make_panel_style(bg.darkened(0.08), PANEL_HIGHLIGHT, 4))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color(0.78, 0.96, 1.0, 1.0))


func _make_reward_row_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = _make_panel_style(bg, border, 3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_icon_frame_style() -> StyleBoxFlat:
	var style = _make_panel_style(Color(0.045, 0.04, 0.035, 1.0), Color(0.62, 0.44, 0.22, 1.0), 2)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	return style


func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(4, 4)
	return style
