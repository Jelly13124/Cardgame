extends Control

## Emitted when player presses PROCEED. Owner (battle_scene) handles
## the actual scene transition back to the map. When this scene is run
## standalone (legacy path), the no-op listener falls back to the old
## direct-change behavior in _on_proceed_pressed.
signal closed

# In-run currency is Caps (owner 2026-07-08): same bottle-cap icon as the base.
const GOLD_ICON_PATH := "res://run_system/assets/images/home/currency/caps.png"
const CARD_REWARD_ICON_PATH := "res://run_system/assets/images/ui_kit_lightline/iconb_cards_fan.png"
const BANNER_LONG_PATH := "res://run_system/assets/images/ui/kit/banner_long.png"
const REWARD_PANEL_SIZE := Vector2(526, 640)
const REWARD_ROW_SIZE := Vector2(402, 86)
const CONTINUE_SIZE := Vector2(269, 108)
const CARD_REWARD_CENTER_Y := 76.0
const CARD_REWARD_PITCH := 350.0
const CARD_REWARD_ACTION_TOP := 884.0
const CARD_REWARD_ACTION_BOTTOM := 957.0

# Shared palette lives in ui/common/theme/wasteland_theme.gd as
# `T.PANEL_BG` etc. — see wasteland_theme.gd for all colors / builders.
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const REWARDS = preload("uid://dao6ryap2ksxs")  # res://core/run/rewards.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const INVENTORY_FULL_MODAL = preload("uid://deiqqoalu4lpl")  # res://ui/common/inventory_full_modal.gd
# Lazy-loaded at call site to avoid map→battle→loot cyclic preload.
const MAP_SCENE_PATH := "uid://d3x5b8wvg2q"  # res://ui/map/map_scene.tscn

## The card pool from which draft choices are rolled. Populated at _ready
## from MetaProgress.get_unlocked_card_pool() — every non-curse, non-basic card
## on disk, minus other heroes' exclusive cards (all cards are draftable by
## default; there is no per-card unlock system).
var draft_pool: Array = []

@onready var loot_root: VBoxContainer = $LootContents
@onready var loot_list_container: VBoxContainer = $LootContents/LootList
@onready var proceed_button: Button = $LootContents/ProceedButton
@onready var draft_overlay: Control = $DraftOverlay
@onready var draft_title: Label = $DraftOverlay/TitleLabel
@onready var draft_card_container: HBoxContainer = $DraftOverlay/CardsContainer
@onready var draft_skip_button: Button = $DraftOverlay/Actions/SkipDraftButton
@onready var reward_panel: Panel = $RewardPanel
@onready var reward_banner: TextureRect = $RewardBanner

var _card_factory: Node = null
var available_loot = []
var _rarity_pools = {"common": [], "uncommon": [], "rare": []}


func _ready() -> void:
	draft_pool = MetaProgress.get_unlocked_card_pool()
	proceed_button.pressed.connect(_on_proceed_pressed)
	draft_skip_button.pressed.connect(_on_skip_draft_pressed)
	draft_overlay.visible = false
	_animate_overlay_in()

	_card_factory = preload("uid://diap3gdfbqvjv").instantiate()  # res://ui/battle/card_framework_adapters/my_card_factory.tscn
	add_child(_card_factory)
	# Match the 208×286 layout of the shared PlayCard scene before scaling its previews.
	_card_factory.card_size = Vector2(208, 286)

	_apply_static_theme()
	_categorize_cards()
	_generate_loot()
	_populate_loot_ui()


func _apply_static_theme() -> void:
	$RewardBackdrop.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	$RewardBackdrop.color = T.REWARD_SCRIM
	loot_root.offset_top = RUN_TOP_BAR.BAR_HEIGHT + 40.0
	# Keep the draft layer itself below the persistent top bar. Its child offsets
	# are authored in the layer's local space so the measured action band still
	# lands at y=884..957 in the viewport.
	draft_overlay.offset_top = RUN_TOP_BAR.BAR_HEIGHT
	reward_panel.custom_minimum_size = REWARD_PANEL_SIZE
	reward_panel.add_theme_stylebox_override("panel", T.panel_textured("hard"))
	reward_banner.texture = _load_texture(BANNER_LONG_PATH)
	reward_banner.custom_minimum_size = Vector2(652, 162)
	for title: Label in [$LootContents/TitleLabel, draft_title]:
		T.style_display(title, 44, 700)
		title.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
		title.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.96))
		title.add_theme_constant_override("outline_size", 16)
	_style_action(proceed_button, true)
	_style_action(draft_skip_button)
	proceed_button.custom_minimum_size = CONTINUE_SIZE
	draft_card_container.add_theme_constant_override("separation", int(CARD_REWARD_PITCH - 312.0))


func _style_action(button: Button, primary: bool = false) -> void:
	T.apply_action_button(button, "primary" if primary else "secondary")
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", T.display_font(700))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.96))
	button.add_theme_constant_override("outline_size", 12)


func _animate_overlay_in() -> void:
	modulate.a = 0.0
	reward_panel.position.y += 24.0
	reward_banner.position.y += 12.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward_panel, "position:y", reward_panel.position.y - 24.0, 0.5)
	tween.tween_property(reward_banner, "position:y", reward_banner.position.y - 12.0, 0.5)
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_LINEAR)


## What this fight offers comes from the run layer (core/run/rewards.gd); this
## screen only names and draws it.
func _generate_loot() -> void:
	available_loot.clear()
	for entry in REWARDS.combat_loot(RunManager.last_battle_node_type, int(RunManager.battle_rewards().get("gold", 0))):
		match str(entry["type"]):
			"gold":
				var gold_amount := int(entry["amount"])
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
			"cards":
				available_loot.append(
					{
						"id": "cards",
						"type": "cards",
						"title": tr("UI_LOOT_CARD_TITLE"),
						"subtitle": tr("UI_LOOT_CARD_SUBTITLE"),
						"icon": CARD_REWARD_ICON_PATH
					}
				)
			"tool":
				var tool_id := str(entry["tool_id"])
				var tdata := RunManager.get_tool_data(tool_id)
				available_loot.append(
					{
						"id": "tool",
						"type": "tool",
						"tool_id": tool_id,
						"rarity": str(tdata.get("rarity", "common")),
						"title":
						Settings.t("TOOL_%s_TITLE" % MODEL_ID.key_entry(tool_id), str(tdata.get("title", tool_id))),
						"subtitle": Settings.t("TOOL_%s_DESC" % MODEL_ID.key_entry(tool_id), ""),
						"icon": str(tdata.get("icon", "")),
						"action": tr("UI_LOOT_ACTION_TAKE")
					}
				)
			"equipment":
				available_loot.append(_equipment_loot(entry))


func _equipment_loot(entry: Dictionary) -> Dictionary:
	var einst: Dictionary = entry["instance"]
	var demo_set_due := bool(entry["demo_set_piece"])
	var equip_id := str(einst.get("base", ""))
	var edata := RunManager.get_equipment_data(equip_id)
	var einst_rarity := str(einst.get("rarity", entry["rarity"]))
	var subtitle := ""
	if demo_set_due:
		var set_id := str(edata.get("set_id", ""))
		var set_name := Settings.t("SET_%s_NAME" % MODEL_ID.key_entry(set_id), set_id.replace("_", " ").capitalize())
		subtitle = tr("UI_LOOT_DEMO_SET_SUBTITLE").format({"set": set_name})
	var spr := str(edata.get("sprite", ""))
	var icon_path := (
		"res://battle_scene/assets/images/%s" % spr
		if spr != ""
		else (
			"res://battle_scene/assets/images/ui/equipment/%s_%s.png"
			% [str(edata.get("slot", "")), einst_rarity]
		)
	)
	return {
		"id": "equipment",
		"type": "equipment",
		"item_id": equip_id,
		"rarity": einst_rarity,
		"instance": einst,
		"demo_set_piece": demo_set_due,
		"title": Settings.t("EQUIP_%s_NAME" % MODEL_ID.key_entry(equip_id), str(edata.get("name", equip_id))),
		"subtitle": subtitle,
		"icon": icon_path,
		"action": tr("UI_LOOT_ACTION_TAKE")
	}


func _populate_loot_ui() -> void:
	for child in loot_list_container.get_children():
		child.queue_free()

	for loot in available_loot:
		loot_list_container.add_child(_make_loot_row(loot))


func _make_loot_row(loot: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = REWARD_ROW_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.apply_choice_button(button)
	button.pressed.connect(_on_loot_selected.bind(str(loot["id"]), button))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.add_child(_make_icon_well(str(loot.get("icon", ""))))

	var title := Label.new()
	title.text = str(loot.get("title", tr("UI_LOOT_DEFAULT_TITLE")))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.style_display(title, 24, 600)
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.02, 0.94))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_color", T.TEXT_MAIN)
	row.add_child(title)

	var action := Label.new()
	action.text = str(loot.get("action", tr("UI_LOOT_ACTION_CLAIM")))
	T.style_display(action, 20, 700)
	action.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	action.add_theme_color_override("font_outline_color", Color(0.06, 0.035, 0.02, 0.94))
	action.add_theme_constant_override("outline_size", 12)
	row.add_child(action)
	return button


func _make_icon_well(icon_path: String) -> Control:
	# Bare art, no framing box (owner 2026-07-08: stop framing every item —
	# the reward icons carry themselves).
	var holder = CenterContainer.new()
	holder.custom_minimum_size = Vector2(56, 56)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture = _load_texture(icon_path)
	if texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon)
	else:
		var fallback = Label.new()
		fallback.text = "?"
		fallback.add_theme_font_size_override("font_size", 34)
		fallback.add_theme_color_override("font_color", T.TEXT_MAIN)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fallback)

	return holder


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
		if put > 0:
			AudioManager.play_sfx("gold")
		print("Claimed %d Gold" % put)
		if put < amount:
			# Backpack couldn't hold the full reward — leave the row so the
			# player can retry after freeing a cell, and warn them.
			_show_backpack_full_toast()
			return
		button.queue_free()
	elif loot["type"] == "cards":
		# Combat card draft (normal + elite).
		_open_card_draft()
		button.queue_free()
	elif loot["type"] == "equipment":
		_claim_equipment_drop(
			loot.get("instance", {}), button, bool(loot.get("demo_set_piece", false))
		)
	elif loot["type"] == "tool":
		_claim_tool_drop(str(loot.get("tool_id", "")), button)


## Draft state. `_in_attr` = level-up attribute pick (3-of-5, one +1 per level gained).
## Lazily-created reward card-draft reroll button (Reroll Tokens upgrade).
var _reroll_btn: Button = null
var _in_attr: bool = false


func _on_proceed_pressed() -> void:
	# Before leaving, spend any queued level-up attribute points (one pick per level).
	if RunManager.pending_attr_points > 0:
		_open_attr_choice()
		return
	_finish_loot()


## --- Level-up attribute choice: pick 1 of 3 random attributes (+1) per level. ---
const _ATTR_KEYS := ["strength", "constitution", "intelligence", "luck", "charm"]
## The canonical lw stat icons (same set as clinic / character window); the
## legacy battle_scene attribute PNGs stay as the per-icon fallback.
const _ATTR_LL_ICONS := {
	"strength": "icon_fist",
	"constitution": "icon_torso",
	"intelligence": "icon_brain",
	"luck": "icon_clover",
	"charm": "icon_star",
}


func _open_attr_choice() -> void:
	_in_attr = true
	loot_root.visible = false
	draft_overlay.visible = true
	# The overlay is shared with the card draft — retitle it for the level-up pick.
	draft_title.text = tr("UI_LOOT_ATTR_TITLE")
	draft_skip_button.text = tr("UI_LOOT_ATTR_SKIP")
	_generate_attr_options()
	# Attribute pick has no reroll — hide the card-draft reroll button if present.
	if _reroll_btn:
		_reroll_btn.visible = false


func _generate_attr_options() -> void:
	for child in draft_card_container.get_children():
		child.queue_free()
	for attr in REWARDS.attribute_choices(_ATTR_KEYS, 3):
		draft_card_container.add_child(_make_attr_slot(str(attr)))


func _make_attr_slot(attr: String) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(248, 306)
	wrapper.pivot_offset = wrapper.custom_minimum_size * 0.5
	var frame = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", T.ll_inset_thin())
	wrapper.add_child(frame)
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(box)
	# Attribute portrait — the canonical lw stat icon, falling back to the legacy
	# battle_scene PNG (then text-only) so a missing asset never crashes the pick.
	var icon_tex := T.lightline_tex(str(_ATTR_LL_ICONS.get(attr, "")))
	if icon_tex == null:
		var legacy_path := "res://battle_scene/assets/images/ui/attributes/%s.png" % attr
		if ResourceLoader.exists(legacy_path):
			icon_tex = load(legacy_path) as Texture2D
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(108, 108)
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
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
	# Hover pop, mirroring the card draft's feel (the old version had no feedback).
	button.mouse_entered.connect(
		func():
			var tween = wrapper.create_tween()
			tween.tween_property(wrapper, "scale", Vector2(1.05, 1.05), 0.10)
	)
	button.mouse_exited.connect(
		func():
			var tween = wrapper.create_tween()
			tween.tween_property(wrapper, "scale", Vector2.ONE, 0.10)
	)
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
		SceneTransition.change_to(MAP_SCENE_PATH)
		return
	emit_signal("closed")
	queue_free()


func _open_card_draft() -> void:
	loot_root.visible = false
	draft_overlay.visible = true
	draft_title.text = tr("UI_LOOT_DRAFT_TITLE")
	draft_skip_button.text = tr("UI_LOOT_SKIP_CARD")
	_generate_draft_options()
	_refresh_reroll_btn()


## Reward card-draft reroll button — re-rolls the 3 offered cards, spending one of
## the run's reward_rerolls (granted by the Reroll Tokens base upgrade).
func _refresh_reroll_btn() -> void:
	if _reroll_btn == null:
		_reroll_btn = Button.new()
		_reroll_btn.custom_minimum_size = Vector2(220, 54)
		_style_action(_reroll_btn)
		_reroll_btn.pressed.connect(_on_reroll_pressed)
		$DraftOverlay/Actions.add_child(_reroll_btn)
	_reroll_btn.visible = true
	var n: int = RunManager.reward_rerolls
	_reroll_btn.text = tr("UI_LOOT_REROLL").format({"n": n})
	_reroll_btn.disabled = n <= 0


func _on_reroll_pressed() -> void:
	if RunManager.reward_rerolls <= 0:
		return
	RunManager.reward_rerolls -= 1
	AudioManager.play_sfx("ui_click")
	_generate_draft_options()
	_refresh_reroll_btn()


func _categorize_cards() -> void:
	_rarity_pools = REWARDS.rarity_pools(draft_pool)


func _generate_draft_options() -> void:
	for child in draft_card_container.get_children():
		child.queue_free()

	var used := {}  # ids shown this draft — the 3 slots never repeat the same card
	for i in range(3):
		var cid := _roll_unique_draft_card_id(used)
		used[cid] = true
		draft_card_container.add_child(_make_draft_card_slot(cid))


func _roll_unique_draft_card_id(used: Dictionary) -> String:
	return REWARDS.roll_unique_draft_card(_rarity_pools, used)


func _make_draft_card_slot(card_id: String) -> Control:
	var card_w := 208.0
	var card_h := 286.0
	var disp_scale := 1.5
	var disp := Vector2(card_w, card_h) * disp_scale
	var wrapper = Control.new()
	# Pad so the hover scale-up doesn't clip against the neighbours.
	wrapper.custom_minimum_size = disp + Vector2(28, 28)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
		card.scale = Vector2(disp_scale, disp_scale)
		# Centre the scaled card in the wrapper (scale pivots around the card centre).
		var tl: Vector2 = (wrapper.custom_minimum_size - disp) * 0.5
		card.position = tl - Vector2(card_w * 0.5, card_h * 0.5) * (1.0 - disp_scale)
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
		# Hover: pop the card up a touch (no frame to recolour any more).
		button.mouse_entered.connect(
			func():
				var tween = create_tween()
				tween.tween_property(
					card, "scale", Vector2(disp_scale * 1.07, disp_scale * 1.07), 0.10
				)
		)
		button.mouse_exited.connect(
			func():
				var tween = create_tween()
				tween.tween_property(card, "scale", Vector2(disp_scale, disp_scale), 0.10)
		)

	return wrapper


func _on_draft_card_selected(card_id: String) -> void:
	if card_id != "":
		RunManager.add_card_to_deck(card_id)
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


## Card draft is a single pick — return to the loot list so the player can
## claim the remaining rewards, then PROCEED.
func _after_draft() -> void:
	draft_overlay.visible = false
	loot_root.visible = true


## Claim a tool reward into the top-bar inventory. Slots full → warn (no silent
## loss); the player can skip by proceeding, or use a tool first and take it next.
func _claim_tool_drop(tool_id: String, button: Button) -> void:
	if tool_id == "":
		return
	if RunManager.add_tool(tool_id):
		AudioManager.play_sfx("reward")
		button.queue_free()
		return
	_show_backpack_full_toast(tr("UI_LOOT_TOOL_SLOTS_FULL"))


func _claim_equipment_drop(
	instance: Dictionary, button: Button, is_demo_set_piece: bool = false
) -> void:
	if instance.is_empty():
		return
	# The instance (with its rolled affixes) was already created when the loot was
	# built, so what the player saw is exactly what they get.
	if RunManager.add_to_inventory(instance):
		if is_demo_set_piece:
			RunManager.mark_demo_set_piece_claimed(instance)
		button.queue_free()
		return
	# Backpack full → warn, then open the discard-one-to-take modal.
	_show_backpack_full_toast()
	button.disabled = true
	var modal = INVENTORY_FULL_MODAL.new()
	modal.setup(instance)
	modal.resolved.connect(
		func(took_item: bool):
			if took_item and is_demo_set_piece:
				RunManager.mark_demo_set_piece_claimed(instance)
			button.queue_free()
	)
	add_child(modal)


## Transient bottom-centered notice used when a reward can't be taken (gold
## overflow, full equipment bag, or full tool slots). Self-frees after a short
## fade. Pass `toast_text` to override the default backpack-full message.
func _show_backpack_full_toast(toast_text: String = "") -> void:
	# Avoid stacking duplicates if the player spams a blocked reward.
	var existing = get_node_or_null("BackpackFullToast")
	if existing:
		existing.queue_free()

	var toast = Label.new()
	toast.name = "BackpackFullToast"
	toast.text = toast_text if toast_text != "" else tr("UI_LOOT_BACKPACK_FULL")
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

	# Guard the raw-file fallback: a missing path (e.g. Codex tool art still
	# pending) would otherwise spam a loud core ERROR. Fall through to the glyph.
	if not FileAccess.file_exists(file_path):
		return null

	var image = Image.new()
	var err = image.load(file_path)
	if err == OK:
		return ImageTexture.create_from_image(image)

	return null
