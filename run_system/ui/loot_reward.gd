extends Control

## Emitted when player presses PROCEED. Owner (battle_scene) handles
## the actual scene transition back to the map. When this scene is run
## standalone (legacy path), the no-op listener falls back to the old
## direct-change behavior in _on_proceed_pressed.
signal closed

const GOLD_ICON_PATH := "res://run_system/assets/images/loot_ui/gold_reward.png"
const CARD_REWARD_ICON_PATH := "res://run_system/assets/images/loot_ui/card_reward.png"

# Shared palette lives in run_system/ui/theme/wasteland_theme.gd as
# `T.PANEL_BG` etc. — see wasteland_theme.gd for all colors / builders.
const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const INVENTORY_FULL_MODAL = preload("res://run_system/ui/inventory_full_modal.gd")
# Lazy-loaded at call site to avoid map→battle→loot cyclic preload.
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"

# Card IDs available for drafting - must match filenames in card_info/player/
## The card pool from which draft choices are rolled. Populated at _ready
## from MetaProgress.get_unlocked_card_pool() — the union of the always-
## available INITIAL_CARD_POOL (25 cards) and any cards unlocked via
## the Market screen's per-card unlock.
var draft_pool: Array = []

@onready var loot_root = $VBoxContainer
@onready var loot_list_container = $VBoxContainer/LootPanel/MarginContainer/LootList
@onready var proceed_button = $VBoxContainer/BottomRow/MarginContainer/ProceedButton
@onready var draft_overlay = $DraftOverlay
@onready
var draft_card_container = $DraftOverlay/VBoxContainer/DraftPanel/MarginContainer/CardsContainer
@onready
var draft_skip_button = $DraftOverlay/VBoxContainer/BottomRow/MarginContainer/SkipDraftButton

var _card_factory: Node = null
var available_loot = []
var _rarity_pools = {"common": [], "uncommon": [], "rare": []}


func _ready() -> void:
	randomize()
	draft_pool = MetaProgress.get_unlocked_card_pool()
	proceed_button.pressed.connect(_on_proceed_pressed)
	draft_skip_button.pressed.connect(_on_skip_draft_pressed)
	draft_overlay.visible = false

	_card_factory = preload("res://battle_scene/my_card_factory.tscn").instantiate()
	add_child(_card_factory)
	# play_card.tscn is intrinsically 208x286; match it so the bg lines up with the
	# (208-laid-out) frame/art/labels. Draft cards are scaled back down below to
	# keep their original on-screen footprint.
	_card_factory.card_size = Vector2(208, 286)

	_apply_static_theme()
	_categorize_cards()
	_generate_loot()
	_populate_loot_ui()


func _apply_static_theme() -> void:
	$BackgroundColor.color = Color(0.035, 0.027, 0.020, 0.72)
	$VBoxContainer.add_theme_constant_override("separation", 14)
	$VBoxContainer/BannerPanel.custom_minimum_size = Vector2(520, 104)
	$VBoxContainer/LootPanel.custom_minimum_size = Vector2(760, 278)
	$VBoxContainer/BannerPanel/MarginContainer.add_theme_constant_override("margin_left", 58)
	$VBoxContainer/BannerPanel/MarginContainer.add_theme_constant_override("margin_right", 58)
	$VBoxContainer/BannerPanel/MarginContainer.add_theme_constant_override("margin_top", 16)
	$VBoxContainer/BannerPanel/MarginContainer.add_theme_constant_override("margin_bottom", 16)
	$VBoxContainer/BannerPanel/MarginContainer/TitleLabel.add_theme_font_size_override(
		"font_size", 44
	)
	$VBoxContainer/BannerPanel/MarginContainer/TitleLabel.add_theme_color_override(
		"font_color", Color(1.0, 0.84, 0.48, 1.0)
	)
	$VBoxContainer/BannerPanel/MarginContainer/TitleLabel.add_theme_color_override(
		"font_outline_color", Color(0.0, 0.0, 0.0, 0.72)
	)
	$VBoxContainer/BannerPanel/MarginContainer/TitleLabel.add_theme_constant_override(
		"outline_size", 3
	)
	$VBoxContainer/LootPanel/MarginContainer.add_theme_constant_override("margin_left", 28)
	$VBoxContainer/LootPanel/MarginContainer.add_theme_constant_override("margin_right", 28)
	$VBoxContainer/LootPanel/MarginContainer.add_theme_constant_override("margin_top", 24)
	$VBoxContainer/LootPanel/MarginContainer.add_theme_constant_override("margin_bottom", 24)
	loot_list_container.add_theme_constant_override("separation", 12)

	$VBoxContainer/BannerPanel.add_theme_stylebox_override("panel", _make_banner_style())
	$VBoxContainer/LootPanel.add_theme_stylebox_override("panel", _make_loot_panel_style())
	$DraftOverlay/VBoxContainer/DraftPanel.add_theme_stylebox_override(
		"panel", T.panel_textured("dark")
	)
	# Buttons auto-pick up textured normal/hover/pressed via apply_button_theme.
	T.apply_button_theme(proceed_button)
	T.apply_button_theme(draft_skip_button)


func _generate_loot() -> void:
	available_loot.clear()
	var gold_amount = 10  # flat; Luck no longer scales gold

	available_loot.append(
		{
			"id": "gold",
			"type": "gold",
			"amount": gold_amount,
			"title": tr("UI_LOOT_GOLD_TITLE").format({"n": gold_amount}),
			"subtitle": tr("UI_LOOT_GOLD_SUBTITLE"),
			"icon": GOLD_ICON_PATH
		}
	)

	# Card acquisition is combat-driven: every non-boss combat offers a 3-choose-1
	# card draft. (Attributes come from LEVEL-UPS, surfaced on PROCEED; gems from
	# elites/bosses.) Boss loot is handled in battle_scene._victory (never here).
	var node_type: String = RunManager.last_battle_node_type
	available_loot.append(
		{
			"id": "cards",
			"type": "cards",
			"title": tr("UI_LOOT_CARD_TITLE"),
			"subtitle": tr("UI_LOOT_CARD_SUBTITLE"),
			"icon": CARD_REWARD_ICON_PATH
		}
	)
	if node_type == "elite":
		available_loot.append(
			{
				"id": "gem_draft",
				"type": "gem_draft",
				"title": tr("UI_LOOT_GEM_TITLE"),
				"subtitle": tr("UI_LOOT_GEM_SUBTITLE"),
				"icon": CARD_REWARD_ICON_PATH
			}
		)

	var equipment_drop_rarity = (
		_drop_rarity_for_node_type(node_type) if node_type == "elite" else ""
	)
	var equipment_drop_id = (
		RunManager.roll_equipment_drop(equipment_drop_rarity) if equipment_drop_rarity != "" else ""
	)
	if equipment_drop_id != "":
		var data = RunManager.get_equipment_data(equipment_drop_id)
		# Roll the affix instance UP FRONT so the claim grants this exact instance.
		# The reward row deliberately shows NO stat/set subtitle (just the item
		# name) — the player inspects the actual rolled affixes on the map screen.
		var instance := RunManager.make_equip_instance(equipment_drop_id, equipment_drop_rarity)
		available_loot.append(
			{
				"id": "equipment",
				"type": "equipment",
				"item_id": equipment_drop_id,
				"rarity": equipment_drop_rarity,
				"instance": instance,
				"title":
				Settings.t(
					"EQUIP_%s_NAME" % equipment_drop_id, str(data.get("name", equipment_drop_id))
				),
				"subtitle": "",
				"icon": "res://battle_scene/assets/images/%s" % str(data.get("sprite", "")),
				"action": tr("UI_LOOT_ACTION_TAKE")
			}
		)


func _populate_loot_ui() -> void:
	for child in loot_list_container.get_children():
		child.queue_free()

	for loot in available_loot:
		loot_list_container.add_child(_make_loot_row(loot))


func _make_loot_row(loot: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(704, 104)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.add_theme_stylebox_override("normal", _make_reward_row_style(false))
	button.add_theme_stylebox_override("hover", _make_reward_row_style(true))
	button.add_theme_stylebox_override("pressed", _make_reward_row_pressed_style())
	button.pressed.connect(_on_loot_selected.bind(str(loot["id"]), button))

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	row.add_child(_make_icon_well(str(loot.get("icon", "")), str(loot.get("type", ""))))

	var copy = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 4)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var title = Label.new()
	title.text = str(loot.get("title", tr("UI_LOOT_DEFAULT_TITLE")))
	title.add_theme_color_override("font_color", T.TEXT_MAIN)
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	title.add_theme_constant_override("outline_size", 2)
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title)

	var subtitle_text := str(loot.get("subtitle", ""))
	if subtitle_text != "":
		var subtitle = Label.new()
		subtitle.text = subtitle_text
		subtitle.add_theme_color_override("font_color", T.TEXT_SECONDARY)
		subtitle.add_theme_font_size_override("font_size", 18)
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(subtitle)

	row.add_child(_make_claim_plate(str(loot.get("action", tr("UI_LOOT_ACTION_CLAIM")))))
	return button


func _make_icon_well(icon_path: String, loot_type: String = "") -> PanelContainer:
	var frame = PanelContainer.new()
	var is_primary_reward := loot_type in ["gold", "cards"]
	frame.custom_minimum_size = Vector2(88, 88) if is_primary_reward else Vector2(76, 76)
	frame.add_theme_stylebox_override("panel", _make_icon_well_style())
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)

	var texture = _load_texture(icon_path)
	if texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(78, 78) if is_primary_reward else Vector2(62, 62)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var fallback = Label.new()
		fallback.text = "?"
		fallback.add_theme_font_size_override("font_size", 34)
		fallback.add_theme_color_override("font_color", T.TEXT_MAIN)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(fallback)

	return frame


func _make_claim_plate(label_text: String = "") -> PanelContainer:
	var plate = PanelContainer.new()
	plate.custom_minimum_size = Vector2(112, 54)
	plate.add_theme_stylebox_override("panel", _make_claim_plate_style())
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label = Label.new()
	label.text = label_text if label_text != "" else tr("UI_LOOT_ACTION_CLAIM")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.80, 0.98, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _make_banner_style() -> StyleBoxFlat:
	var style := T.panel_with_shadow(
		Color(0.13, 0.075, 0.045, 0.98), Color(0.78, 0.38, 0.16, 1.0), 6, 3
	)
	style.shadow_size = 12
	style.shadow_offset = Vector2(3, 5)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_loot_panel_style() -> StyleBoxFlat:
	var style := T.panel_with_shadow(
		Color(0.075, 0.046, 0.030, 0.96), Color(0.60, 0.30, 0.14, 1.0), 6, 3
	)
	style.shadow_size = 14
	style.shadow_offset = Vector2(5, 7)
	return style


func _make_reward_row_style(hovered: bool) -> StyleBoxFlat:
	var bg := Color(0.105, 0.065, 0.042, 0.96) if not hovered else Color(0.145, 0.088, 0.050, 0.98)
	var border := Color(0.55, 0.29, 0.14, 1.0) if not hovered else T.ACCENT_NEON_BLUE
	var style := T.panel_with_shadow(bg, border, 5, 2)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_reward_row_pressed_style() -> StyleBoxFlat:
	var style := _make_reward_row_style(true)
	style.bg_color = Color(0.16, 0.082, 0.044, 1.0)
	style.border_color = T.ACCENT_DANGER
	return style


func _make_icon_well_style() -> StyleBoxFlat:
	var style := T.panel_with_shadow(
		Color(0.035, 0.029, 0.023, 1.0), Color(0.80, 0.50, 0.20, 1.0), 4, 2
	)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	return style


func _make_claim_plate_style() -> StyleBoxFlat:
	var style := T.panel_with_shadow(Color(0.035, 0.145, 0.165, 0.98), T.ACCENT_NEON_BLUE, 5, 3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 3)
	return style


func _on_loot_selected(loot_id: String, button: Button) -> void:
	AudioManager.play_sfx("reward")
	var loot = null
	for entry in available_loot:
		if entry["id"] == loot_id:
			loot = entry
			break

	if not loot:
		return

	if loot["type"] == "gold":
		var amount: int = int(loot["amount"])
		var put: int = RunManager.add_gold(amount)
		print("Claimed %d Gold" % put)
		if put < amount:
			# Backpack couldn't hold the full reward — leave the row so the
			# player can retry after freeing a cell, and warn them.
			_show_backpack_full_toast()
			return
		button.queue_free()
	elif loot["type"] == "cards":
		# Combat card draft (normal + elite). Luck may turn a slot into a gem.
		_draft_gem_only = false
		_open_card_draft()
		button.queue_free()
	elif loot["type"] == "gem_draft":
		# Elite reward: a one-off 3-choose-1 gem draft (all gems).
		_draft_gem_only = true
		_open_card_draft()
		button.queue_free()
	elif loot["type"] == "equipment":
		_claim_equipment_drop(loot.get("instance", {}), button)


## Draft state. `_draft_gem_only` = elite gem draft; `_in_attr` = level-up attribute
## pick (3-of-5, one +1 per level gained).
var _draft_gem_only: bool = false
var _in_attr: bool = false


func _on_proceed_pressed() -> void:
	# Before leaving, spend any queued level-up attribute points (one pick per level).
	if RunManager.pending_attr_points > 0:
		_open_attr_choice()
		return
	_finish_loot()


## --- Level-up attribute choice: pick 1 of 3 random attributes (+1) per level. ---
const _ATTR_KEYS := ["strength", "constitution", "intelligence", "luck", "charm"]


func _open_attr_choice() -> void:
	_in_attr = true
	loot_root.visible = false
	draft_overlay.visible = true
	_generate_attr_options()


func _generate_attr_options() -> void:
	for child in draft_card_container.get_children():
		child.queue_free()
	var keys := _ATTR_KEYS.duplicate()
	keys.shuffle()
	# Luck: a chance that ONE of the three level-up slots is a gem instead of an
	# attribute (scaled by luck_gem_chance). Only when the gem pool is non-empty.
	var gem_slot := -1
	var pool: Array = RunManager.gem_pool()
	if not pool.is_empty() and randf() < RunManager.luck_gem_chance():
		gem_slot = randi() % 3
	for i in range(min(3, keys.size())):
		if i == gem_slot:
			var gem_id := str(pool[randi() % pool.size()])
			draft_card_container.add_child(_make_gem_draft_slot(gem_id, true))
		else:
			draft_card_container.add_child(_make_attr_slot(str(keys[i])))


func _make_attr_slot(attr: String) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(300, 400)
	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.10, 0.085, 0.06, 0.95), Color(1.0, 0.82, 0.4), 4)
	)
	wrapper.add_child(frame)
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(box)
	var name_lbl = Label.new()
	name_lbl.text = tr("UI_COMBAT_ATTR_%s" % attr.to_upper())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	box.add_child(name_lbl)
	var plus = Label.new()
	plus.text = "+1"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 48)
	plus.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	box.add_child(plus)
	var button = Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_attr_picked.bind(attr))
	wrapper.add_child(button)
	return wrapper


func _on_attr_picked(attr: String) -> void:
	RunManager.grant_attribute(attr, 1)
	RunManager.pending_attr_points = maxi(0, RunManager.pending_attr_points - 1)
	if RunManager.pending_attr_points > 0:
		_generate_attr_options()
		return
	_in_attr = false
	draft_overlay.visible = false
	_finish_loot()


## Leave the loot screen (emit closed so battle_scene drives the transition; fall
## back to a direct scene change in standalone use).
func _finish_loot() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file(MAP_SCENE_PATH)
		return
	emit_signal("closed")
	queue_free()


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

	var gem_ids: Array = RunManager.gem_pool()
	for i in range(3):
		# Gem slot when this is an elite gem-draft, or (in a level draft) a Luck roll.
		var as_gem := _draft_gem_only or (randf() < RunManager.luck_gem_chance())
		if as_gem and not gem_ids.is_empty():
			draft_card_container.add_child(
				_make_gem_draft_slot(str(gem_ids[randi() % gem_ids.size()]))
			)
		else:
			draft_card_container.add_child(_make_draft_card_slot(_roll_draft_card_id()))


## Roll a single card id for a draft slot (rarity weighted, Luck-boosted).
func _roll_draft_card_id() -> String:
	var roll = randf()
	var picked_rarity = "common"
	if roll < 0.05:
		picked_rarity = "rare"
	elif roll < 0.30:
		picked_rarity = "uncommon"
	if picked_rarity != "rare" and randf() < RunManager.luck_rarity_bonus():
		picked_rarity = "rare" if picked_rarity == "uncommon" else "uncommon"
	if _rarity_pools[picked_rarity].is_empty():
		if picked_rarity == "rare":
			picked_rarity = "uncommon"
		if _rarity_pools[picked_rarity].is_empty():
			picked_rarity = "common"
	var pool = _rarity_pools[picked_rarity]
	return str(pool[randi() % pool.size()]) if not pool.is_empty() else ""


func _make_draft_card_slot(card_id: String) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(300, 400)

	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.095, 0.072, 0.055, 0.92), T.PANEL_BORDER, 4)
	)
	wrapper.add_child(frame)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Compensate for the 208x286 card so the draft slot renders identically to
		# the old 160x220 @1.5 footprint (160/208 ≈ 0.769), zoomed from the new center.
		card.position = Vector2(46, 55)
		card.scale = Vector2(1.5 * 160.0 / 208.0, 1.5 * 160.0 / 208.0)
		card.pivot_offset = Vector2(104, 143)
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
		button.mouse_entered.connect(
			func():
				frame.add_theme_stylebox_override(
					"panel",
					T.panel_with_shadow(Color(0.13, 0.095, 0.062, 0.96), T.ACCENT_NEON_BLUE, 4)
				)
				var tween = create_tween()
				tween.tween_property(
					card, "scale", Vector2(1.62 * 160.0 / 208.0, 1.62 * 160.0 / 208.0), 0.10
				)
		)
		button.mouse_exited.connect(
			func():
				frame.add_theme_stylebox_override(
					"panel",
					T.panel_with_shadow(Color(0.095, 0.072, 0.055, 0.92), T.PANEL_BORDER, 4)
				)
				var tween = create_tween()
				tween.tween_property(
					card, "scale", Vector2(1.5 * 160.0 / 208.0, 1.5 * 160.0 / 208.0), 0.10
				)
		)

	return wrapper


## A gem option in a draft (elite gem-draft, or a Luck-rolled level-up slot).
## `in_attr` routes the pick through the level-up flow (consume an attr point +
## continue) instead of the card-draft completion.
func _make_gem_draft_slot(gem_id: String, in_attr: bool = false) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(300, 400)

	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.06, 0.10, 0.13, 0.95), Color(0.45, 0.85, 1.0), 4)
	)
	wrapper.add_child(frame)

	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(box)

	var glyph = Label.new()
	glyph.text = "💎"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 80)
	box.add_child(glyph)

	var gdata := RunManager.get_gem_data(gem_id)
	var name_lbl = Label.new()
	name_lbl.text = Settings.t("GEM_%s_TITLE" % gem_id, str(gdata.get("title", gem_id)))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	box.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = Settings.t("GEM_%s_DESC" % gem_id, "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(240, 0)
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.8))
	box.add_child(desc_lbl)

	var button = Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if in_attr:
		button.pressed.connect(_on_attr_gem_picked.bind(gem_id))
	else:
		button.pressed.connect(_on_gem_draft_selected.bind(gem_id))
	wrapper.add_child(button)
	return wrapper


## Level-up slot resolved as a gem (Luck roll): bank the gem, consume one attr
## point, and continue the pick loop (mirrors _on_attr_picked's tail).
func _on_attr_gem_picked(gem_id: String) -> void:
	if gem_id != "":
		RunManager.gem_inventory.append(gem_id)
	RunManager.pending_attr_points = maxi(0, RunManager.pending_attr_points - 1)
	if RunManager.pending_attr_points > 0:
		_generate_attr_options()
		return
	_in_attr = false
	draft_overlay.visible = false
	_finish_loot()


func _on_draft_card_selected(card_id: String) -> void:
	if card_id != "":
		RunManager.add_card_to_deck(card_id)
	_after_draft()


func _on_gem_draft_selected(gem_id: String) -> void:
	if gem_id != "":
		RunManager.gem_inventory.append(gem_id)
	_after_draft()


func _on_skip_draft_pressed() -> void:
	# Skipping an attribute pick forfeits that point (and chains to the next).
	if _in_attr:
		RunManager.pending_attr_points = maxi(0, RunManager.pending_attr_points - 1)
		if RunManager.pending_attr_points > 0:
			_generate_attr_options()
			return
		_in_attr = false
		draft_overlay.visible = false
		_finish_loot()
		return
	_after_draft()


## Card / gem draft is a single pick — return to the loot list so the player can
## claim the remaining rewards, then PROCEED.
func _after_draft() -> void:
	draft_overlay.visible = false
	loot_root.visible = true
	_draft_gem_only = false


## Returns "" if no drop. Otherwise the drop rarity for this node type.
func _drop_rarity_for_node_type(node_type: String) -> String:
	match node_type:
		"elite":
			return "uncommon"
		"boss":
			return "rare"
		_:
			return ""


func _claim_equipment_drop(instance: Dictionary, button: Button) -> void:
	if instance.is_empty():
		return
	# The instance (with its rolled affixes) was already created when the loot was
	# built, so what the player saw is exactly what they get.
	if RunManager.add_to_inventory(instance):
		button.queue_free()
		return
	# Backpack full → warn, then open the discard-one-to-take modal.
	_show_backpack_full_toast()
	button.disabled = true
	var modal = INVENTORY_FULL_MODAL.new()
	modal.setup(instance)
	modal.resolved.connect(func(_took_item: bool): button.queue_free())
	add_child(modal)


## Transient bottom-centered notice used when the backpack can't hold a reward
## (gold overflow or a full equipment bag). Self-frees after a short fade.
func _show_backpack_full_toast() -> void:
	# Avoid stacking duplicates if the player spams a blocked reward.
	var existing = get_node_or_null("BackpackFullToast")
	if existing:
		existing.queue_free()

	var toast = Label.new()
	toast.name = "BackpackFullToast"
	toast.text = tr("UI_LOOT_BACKPACK_FULL")
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", T.ACCENT_DANGER)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast.add_theme_constant_override("outline_size", 6)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.position = Vector2(0, -120)
	add_child(toast)

	# Bind the tween to the toast (not self) so replacing the toast auto-kills
	# its tween — avoids a callback firing on an already-freed label.
	var tween = toast.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)


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
