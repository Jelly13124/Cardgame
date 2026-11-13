extends Button

## The card-removal service (STS2 NMerchantCardRemoval): a button with the
## current price that opens a deck picker; picking a card asks the removal
## entry to remove it.

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const MERCHANT_SLOT = preload("uid://b8xlpnq6b5osf")  # res://ui/shop/merchant_slot.gd

const CARD_SCALE := 160.0 / 208.0
const CARD_SERVICE_ICON_PATH := "res://run_system/assets/images/ui_kit_lightline/iconb_cards_fan.png"

var entry
var picker: Control = null
var _card_factory: Node
var _price_content: Control
var _price_label: Label


static func create(p_entry, card_factory: Node) -> Button:
	var button = load("uid://cb444odpyv0bh").new()  # res://ui/shop/merchant_card_removal.gd
	button.entry = p_entry
	button._card_factory = card_factory
	button._build()
	return button


func _build() -> void:
	name = "RemoveCardService"
	custom_minimum_size = Vector2(180, 236)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	MERCHANT_SLOT.style_button(self, Color(0.67, 0.54, 0.34))
	text = ""
	var content := VBoxContainer.new()
	content.name = "RemoveCardProduct"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 4)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var icon := TextureRect.new()
	icon.name = "RemoveCardIcon"
	icon.custom_minimum_size = Vector2(72, 72)
	icon.texture = load(CARD_SERVICE_ICON_PATH) if ResourceLoader.exists(CARD_SERVICE_ICON_PATH) else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var title := Label.new()
	title.name = "RemoveCardTitle"
	title.text = tr("UI_SHOP_REMOVE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	T.style_display(title, 20, 700)
	title.add_theme_color_override("font_color", T.TEXT_MAIN)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var price_button := Button.new()
	price_button.name = "RemoveCardPrice"
	price_button.custom_minimum_size = Vector2(164, 70)
	price_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_button.focus_mode = Control.FOCUS_NONE
	_price_content = T.centered_currency_button_content(price_button, 0, "caps", 39, 54, true, 4)
	if _price_content.get_child_count() > 0:
		var price_row := _price_content.get_child(0)
		if price_row is HBoxContainer:
			_price_label = price_row.get_meta("amount_label", null) as Label
	if _price_label != null:
		_price_label.add_theme_font_override("font", T.display_font(700))
		_price_label.add_theme_font_size_override("font_size", 39)
		_price_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.96))
		_price_label.add_theme_constant_override("outline_size", 15)
	content.add_child(price_button)
	pressed.connect(open_picker)
	entry.entry_updated.connect(refresh)
	entry.purchase_completed.connect(_on_purchase_completed)
	RunManager.resources_changed.connect(_on_resources_changed)
	RunManager.backpack_changed.connect(refresh)
	refresh()


func _on_purchase_completed(_entry) -> void:
	refresh()


func _on_resources_changed(_gold: int, _scrap: int) -> void:
	refresh()


func refresh() -> void:
	disabled = not entry.is_stocked()
	text = tr("UI_SHOP_SOLD") if disabled else ""
	if _price_content != null:
		_price_content.visible = not disabled
	if _price_label != null and not disabled:
		_price_label.text = str(entry.cost())
	var color := Color(0.97, 0.85, 0.58) if entry.enough_gold() else MERCHANT_SLOT.PRICE_SHORT
	if _price_label != null:
		_price_label.add_theme_color_override("font_color", color)


func open_picker() -> void:
	if picker != null or not entry.is_stocked():
		return
	if not entry.enough_gold():
		AudioManager.play_sfx("error")
		return
	picker = _build_picker()
	get_parent().add_child(picker)


func _build_picker() -> Control:
	var modal := Control.new()
	modal.name = "RemoveCardPicker"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(1100, 720)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("UI_SHOP_REMOVE_MODAL_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.55, 0.55))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("UI_SHOP_REMOVE_MODAL_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1040, 560)
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for deck_entry in RunManager.player_deck:
		var uid := str(deck_entry.get("uid", ""))
		var card_id := str(deck_entry.get("card_id", ""))
		if uid != "" and card_id != "":
			grid.add_child(_card_choice(card_id, uid))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)
	var cancel := Button.new()
	cancel.text = tr("UI_SHOP_CANCEL")
	cancel.custom_minimum_size = Vector2(140, 42)
	cancel.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(cancel)
	cancel.pressed.connect(close_picker)
	actions.add_child(cancel)
	return modal


func _card_choice(card_id: String, uid: String) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(180, 260)
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.suppress_playable_glow = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 20)
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2.ONE * CARD_SCALE
		wrapper.add_child(card)
		if card.highlight:
			card.highlight.anim_hide_instantly()

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:  # bare-ok: Godot button theme state
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_pick.bind(uid))
	wrapper.add_child(button)
	if card:
		button.mouse_entered.connect(func():
			card.highlight.anim_show()
			card.create_tween().tween_property(card, "scale", Vector2.ONE * CARD_SCALE * 1.06, 0.10))
		button.mouse_exited.connect(func():
			card.highlight.anim_hide_instantly()
			card.create_tween().tween_property(card, "scale", Vector2.ONE * CARD_SCALE, 0.10))
	return wrapper


func _on_pick(uid: String) -> void:
	entry.try_remove(uid)
	close_picker()


func close_picker() -> void:
	if picker != null:
		picker.queue_free()
		picker = null
