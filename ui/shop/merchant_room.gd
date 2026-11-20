## The merchant room (STS2 NMerchantRoom), loaded for a `merchant` map node. It
## builds this node's MerchantInventory once (core/run/merchant) and restores it
## after a reload, lays out the relic shelf, tool shelf, card row and card
## removal, and keeps the saved stock current after every sale.
extends Control

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const CARD_FACTORY_SCENE = preload("uid://diap3gdfbqvjv")  # res://ui/battle/card_framework_adapters/my_card_factory.tscn
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const CHARACTER_WINDOW = preload("uid://ba0f3y5ua1p6o")  # res://ui/windows/character_window.gd
const RUN_DECK_VIEWER_MODAL = preload("uid://jvxfh15gtinx")  # res://ui/common/run_deck_viewer_modal.gd
const PAUSE_PANEL = preload("uid://dggg8eoy0notq")  # res://ui/menus/pause_panel.gd
const INVENTORY = preload("uid://dgj1md8jt0tg7")  # res://core/run/merchant/merchant_inventory.gd
const MERCHANT_SLOT = preload("uid://b8xlpnq6b5osf")  # res://ui/shop/merchant_slot.gd
const MERCHANT_CARD_REMOVAL = preload("uid://cb444odpyv0bh")  # res://ui/shop/merchant_card_removal.gd
# Lazy-loaded at call site to avoid map→shop→map cyclic preload.
const MAP_SCENE_PATH := "uid://d3x5b8wvg2q"  # res://ui/map/map_scene.tscn
const SHOP_BACKGROUND_PATH := "res://run_system/assets/images/ui_v2/shop/shop_background.png"
## STS2 merchant_inventory: the goods lie straight on one big rug, cards in
## the top row and relics, tools and card removal in the row below.
const SHOP_RUG = preload("uid://c7vwm1yr54e3u")  # res://ui/shop/shop_rug.gd
const RUG_ANCHORS := Rect2(0.022, 0.2, 0.735, 0.775)
const SHOPKEEPER_PATH := "res://run_system/assets/images/shop/shopkeeper.png"

var inventory
var removal_service: Button
var _card_factory: Node


func _ready() -> void:
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	# play_card.tscn is intrinsically 208x286; slots scale the card down.
	_card_factory.card_size = Vector2(208, 286)

	inventory = _load_inventory()
	for entry in inventory.all_entries():
		entry.purchase_completed.connect(_on_purchase_completed)
		entry.purchase_failed.connect(_on_purchase_failed)
	_build_ui()
	AudioManager.play_music("shop")


## This node's inventory: restored from the run state, or rolled and saved.
func _load_inventory() -> RefCounted:
	var node_id := str(RunManager.current_node_id)
	var saved: Variant = RunManager.state.shop_stock.get(node_id, {})
	if typeof(saved) == TYPE_DICTIONARY and not saved.is_empty():
		return INVENTORY.from_dict(RunManager, saved)
	var fresh = INVENTORY.create(RunManager)
	RunManager.state.shop_stock[node_id] = fresh.to_dict()
	return fresh


func _on_purchase_completed(_entry) -> void:
	AudioManager.play_sfx("purchase")
	RunManager.state.shop_stock[str(RunManager.current_node_id)] = inventory.to_dict()


func _on_purchase_failed(_status: int) -> void:
	AudioManager.play_sfx("error")


func _build_ui() -> void:
	_add_scene_art()

	var topbar_layer := CanvasLayer.new()
	topbar_layer.name = "TopBarLayer"
	topbar_layer.layer = RUN_TOP_BAR.CANVAS_LAYER
	add_child(topbar_layer)

	var topbar := RUN_TOP_BAR.new()
	topbar.name = "RunTopBar"
	topbar.show_character_button = true
	topbar.show_settings_button = true
	topbar.show_tools = false
	topbar.deck_pressed.connect(_open_run_deck_viewer)
	topbar.character_pressed.connect(
		func(): CHARACTER_WINDOW.open_window(self, CHARACTER_WINDOW.MODE_MAP)
	)
	topbar.settings_pressed.connect(func(): PAUSE_PANEL.open(self, RunManager.is_run_active))
	topbar_layer.add_child(topbar)

	var title := Label.new()
	title.text = tr("UI_SHOP_TITLE")
	title.offset_left = 52.0
	title.offset_top = RUN_TOP_BAR.BAR_HEIGHT + 20.0
	title.offset_right = 340.0
	title.offset_bottom = RUN_TOP_BAR.BAR_HEIGHT + 68.0
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", T.UI_V2_INK)
	add_child(title)

	_add_rug()

	# Top row: the six cards, as large as the rug allows.
	var card_row := HBoxContainer.new()
	card_row.name = "CardShelf"
	card_row.anchor_left = 0.035
	card_row.anchor_top = 0.225
	card_row.anchor_right = 0.745
	card_row.anchor_bottom = 0.57
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 18)
	add_child(card_row)
	for entry in inventory.card_entries:
		card_row.add_child(MERCHANT_SLOT.create(entry, _card_factory))

	# Bottom row: the three relics, then the tools, then card removal.
	var relic_shelf := HBoxContainer.new()
	relic_shelf.name = "RelicShelf"
	relic_shelf.anchor_left = 0.05
	relic_shelf.anchor_top = 0.6
	relic_shelf.anchor_right = 0.31
	relic_shelf.anchor_bottom = 0.88
	relic_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	relic_shelf.add_theme_constant_override("separation", 22)
	add_child(relic_shelf)
	for entry in inventory.relic_entries:
		relic_shelf.add_child(MERCHANT_SLOT.create(entry))

	var tool_shelf := HBoxContainer.new()
	tool_shelf.name = "ToolShelf"
	tool_shelf.anchor_left = 0.33
	tool_shelf.anchor_top = 0.61
	tool_shelf.anchor_right = 0.56
	tool_shelf.anchor_bottom = 0.87
	tool_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_shelf.add_theme_constant_override("separation", 18)
	add_child(tool_shelf)
	for entry in inventory.tool_entries:
		tool_shelf.add_child(MERCHANT_SLOT.create(entry))

	removal_service = MERCHANT_CARD_REMOVAL.create(inventory.card_removal_entry, _card_factory)
	removal_service.anchor_left = 0.59
	removal_service.anchor_top = 0.57
	removal_service.anchor_right = 0.725
	removal_service.anchor_bottom = 0.92
	add_child(removal_service)

	var leave_btn := Button.new()
	leave_btn.name = "LeaveButton"
	leave_btn.text = tr("UI_SHOP_LEAVE")
	leave_btn.anchor_left = 1.0
	leave_btn.anchor_top = 1.0
	leave_btn.anchor_right = 1.0
	leave_btn.anchor_bottom = 1.0
	leave_btn.offset_left = -268.0
	leave_btn.offset_top = -102.0
	leave_btn.offset_right = -46.0
	leave_btn.offset_bottom = -40.0
	leave_btn.focus_mode = Control.FOCUS_NONE
	leave_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	leave_btn.add_theme_font_override("font", T.display_font(700))
	leave_btn.add_theme_font_size_override("font_size", 22)
	T.apply_action_button(leave_btn, "primary")
	leave_btn.pressed.connect(_on_leave_pressed)
	add_child(leave_btn)



func _add_rug() -> void:
	var rug: Control = SHOP_RUG.new()
	rug.anchor_left = RUG_ANCHORS.position.x
	rug.anchor_top = RUG_ANCHORS.position.y
	rug.anchor_right = RUG_ANCHORS.end.x
	rug.anchor_bottom = RUG_ANCHORS.end.y
	add_child(rug)


func _add_scene_art() -> void:
	if ResourceLoader.exists(SHOP_BACKGROUND_PATH):
		var bg := TextureRect.new()
		bg.texture = load(SHOP_BACKGROUND_PATH)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.025, 0.020, 0.016, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.010, 0.006, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	if ResourceLoader.exists(SHOPKEEPER_PATH):
		var keeper := TextureRect.new()
		keeper.texture = load(SHOPKEEPER_PATH)
		keeper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		keeper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		keeper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keeper.anchor_left = 1.0
		keeper.anchor_top = 1.0
		keeper.anchor_right = 1.0
		keeper.anchor_bottom = 1.0
		keeper.offset_left = -430
		keeper.offset_top = -650
		keeper.offset_right = -38
		keeper.offset_bottom = -34
		add_child(keeper)


# --- Leave -----------------------------------------------------------------


func _open_run_deck_viewer() -> void:
	var existing := get_node_or_null("RunDeckViewerModal")
	if existing:
		existing.queue_free()
		return
	var modal := RUN_DECK_VIEWER_MODAL.new()
	modal.name = "RunDeckViewerModal"
	add_child(modal)


func _on_leave_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	SceneTransition.change_to(MAP_SCENE_PATH)
