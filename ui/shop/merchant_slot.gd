extends VBoxContainer

## One merchant slot (STS2 NMerchantSlot / NMerchantCard / NMerchantRelic /
## NMerchantPotion) for a card, relic or tool entry: the goods, a SALE tag and
## the price button. The price turns red when the player cannot afford it; a
## sold slot shows SOLD. It follows its entry's signals and gold changes.

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const CARD_ENTRY = preload("uid://c4olkv36j1puq")  # res://core/run/merchant/merchant_card_entry.gd
const RELIC_ENTRY = preload("uid://w22svgh4s36c")  # res://core/run/merchant/merchant_relic_entry.gd

const PRICE := Color(1.0, 0.84, 0.18)
const PRICE_SHORT := Color(1.0, 0.36, 0.30)
const SALE := Color(0.42, 0.92, 0.48)
const TOOL_ACCENT := Color(0.38, 0.80, 0.93)
const RELIC_ACCENT := Color(0.84, 0.68, 0.33)
const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.45, 0.8, 1.0),
	"rare": Color(1.0, 0.85, 0.35),
}

var entry
var buy_button: Button
var sale_tag: Label
## The card view, relic or tool icon; hidden once sold.
var goods: Control
var _card_factory: Node
var _accent := PRICE
var _shown_card_id := ""


## A slot for `p_entry`; `card_factory` renders card entries.
static func create(p_entry, card_factory: Node = null) -> VBoxContainer:
	var slot = load("uid://b8xlpnq6b5osf").new()  # res://ui/shop/merchant_slot.gd
	slot.entry = p_entry
	slot._card_factory = card_factory
	slot._build()
	return slot


func _build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 5)
	sale_tag = Label.new()
	sale_tag.name = "SaleTag"
	sale_tag.text = tr("UI_SHOP_SALE")
	sale_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sale_tag.add_theme_font_override("font", T.display_font(700))
	sale_tag.add_theme_font_size_override("font_size", 18)
	sale_tag.add_theme_color_override("font_color", SALE)
	add_child(sale_tag)

	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_button.add_theme_font_override("font", T.display_font(650))
	buy_button.add_theme_font_size_override("font_size", 18)
	if entry is CARD_ENTRY:
		_build_card()
	elif entry is RELIC_ENTRY:
		_build_relic()
	else:
		_build_tool()
	style_button(buy_button, _accent)
	buy_button.pressed.connect(func(): entry.try_purchase())
	add_child(buy_button)

	entry.entry_updated.connect(refresh)
	entry.purchase_completed.connect(_on_purchase_completed)
	RunManager.backpack_changed.connect(refresh)
	RunManager.resources_changed.connect(_on_resources_changed)
	refresh()


func _on_purchase_completed(_entry) -> void:
	refresh()


func _on_resources_changed(_gold: int, _scrap: int) -> void:
	refresh()


func _build_card() -> void:
	custom_minimum_size = Vector2(148, 270)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(146, 202)
	add_child(holder)
	goods = holder
	_accent = RARITY_COLORS.get(entry.rarity, PRICE)
	buy_button.custom_minimum_size = Vector2(118, 38)
	holder.mouse_entered.connect(func(): _hover(holder, Vector2(1.04, 1.04)))
	holder.mouse_exited.connect(func(): _hover(holder, Vector2.ONE))
	_show_card()


## Renders the entry's card (again after a refill restocks the slot).
func _show_card() -> void:
	for child in goods.get_children():
		child.queue_free()
	_shown_card_id = entry.card_id
	if _card_factory == null or not entry.is_stocked():
		return
	var card = _card_factory.create_card(entry.card_id, null)
	if card == null:
		return
	if card.get_parent():
		card.get_parent().remove_child(card)
	card.can_be_interacted_with = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(2, 2)
	card.pivot_offset = Vector2.ZERO
	card.scale = Vector2.ONE * 0.69
	goods.add_child(card)


func _build_relic() -> void:
	custom_minimum_size = Vector2(132, 200)
	var data: Dictionary = RunManager.get_relic_data(entry.relic_id)
	var icon := _icon_button(str(data.get("icon", "")), Vector2(104, 104))
	icon.tooltip_text = Settings.t("RELIC_%s_TITLE" % MODEL_ID.key_entry(entry.relic_id), str(data.get("title", entry.relic_id)))
	for state in ["normal", "hover", "pressed", "focus"]:  # bare-ok: theme state
		icon.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	icon.pressed.connect(func(): entry.try_purchase())
	add_child(icon)
	goods = icon
	_accent = RELIC_ACCENT
	buy_button.custom_minimum_size = Vector2(96, 34)


func _build_tool() -> void:
	custom_minimum_size = Vector2(92, 150)
	var data: Dictionary = RunManager.get_tool_data(entry.tool_id)
	var icon := _icon_button(str(data.get("icon", "")), Vector2(82, 90))
	icon.tooltip_text = Settings.t("TOOL_%s_TITLE" % MODEL_ID.key_entry(entry.tool_id), str(data.get("title", entry.tool_id)))
	style_button(icon, TOOL_ACCENT)
	icon.pressed.connect(func(): entry.try_purchase())
	add_child(icon)
	goods = icon
	_accent = TOOL_ACCENT
	buy_button.custom_minimum_size = Vector2(82, 32)


func _icon_button(icon_path: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if icon_path != "" and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
	return button


## Price, affordability, sale and sold state from the entry as it is now.
func refresh() -> void:
	if not is_instance_valid(buy_button):
		return
	var stocked: bool = entry.is_stocked()
	if entry is CARD_ENTRY and stocked and entry.card_id != _shown_card_id:
		_show_card()
	# Faded, not hidden: the tag keeps its line so every slot stays aligned.
	sale_tag.modulate.a = 1.0 if is_on_sale() else 0.0
	if goods:
		goods.modulate.a = 1.0 if stocked else 0.0
	buy_button.disabled = not stocked
	if not stocked:
		buy_button.text = tr("UI_SHOP_SOLD")
		return
	buy_button.text = str(entry.cost())
	var color := PRICE if entry.enough_gold() else PRICE_SHORT
	buy_button.add_theme_color_override("font_color", color)
	buy_button.add_theme_color_override("font_hover_color", color.lightened(0.3))


func is_on_sale() -> bool:
	return entry is CARD_ENTRY and entry.is_stocked() and entry.on_sale


func _hover(node: Control, to: Vector2) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "scale", to, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func style_button(button: Button, accent: Color) -> void:
	for state in ["normal", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.045, 0.055, 0.055, 0.94)
		style.border_color = accent if state != "disabled" else Color(0.28, 0.28, 0.27, 0.75)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.08, 0.09, 0.085, 0.98)
	hover.border_color = accent.lightened(0.18)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(5)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.97, 0.85, 0.58))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
