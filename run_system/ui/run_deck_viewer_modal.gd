## Run-deck screen. Renders every card in RunManager.player_deck.
## Opened from the map [📚 DECK] button.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")
const CARD_UPGRADE = preload("res://run_system/core/card_upgrade.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

const TOP_BAR_CLEARANCE := RUN_TOP_BAR.BAR_HEIGHT

var _card_factory: Node


func _ready() -> void:
	# MapScene's Control rect is NOT viewport-sized (it draws via get_viewport_rect()
	# but never sets its own size), so PRESET_FULL_RECT would collapse to (0,0).
	# Size ourselves to the viewport explicitly and stay updated on resize.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(208, 286)
	_build()


func _fit_to_viewport() -> void:
	set_position(Vector2.ZERO)
	set_size(get_viewport_rect().size)


func _build() -> void:
	# Opaque full-screen page (pseudo-scene). Map _input is gated separately so
	# clicks can't fall through; in battle the STOP overlay blocks card input.
	var bg := ColorRect.new()
	bg.name = "RunDeckBackground"
	bg.color = Color(0.07, 0.05, 0.035, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "RunDeckContent"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = TOP_BAR_CLEARANCE
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 48)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header with close X
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = tr("UI_COMMON_RUN_DECK_TITLE").format({"n": RunManager.player_deck.size()})
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)

	# Card grid
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 600)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for entry in RunManager.player_deck:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("card_id", "")) != "":
			grid.add_child(_make_card_slot(entry))

	_add_close_x()


## Top-right ✕ — same effect as the second-press toggle (queue_free).
func _add_close_x() -> void:
	var x := T.close_x_button()
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -64.0
	x.offset_right = -16.0
	x.offset_top = TOP_BAR_CLEARANCE + 16.0
	x.offset_bottom = TOP_BAR_CLEARANCE + 64.0
	x.pressed.connect(queue_free)
	add_child(x)


## ESC closes the page. Battle's top-bar only consumes ESC when its settings menu
## is already visible, so this never conflicts; the map has no ESC handler.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


## One deck card: its art (upgraded entries render their upgraded stats).
func _make_card_slot(entry: Dictionary) -> Control:
	var card_id: String = str(entry.get("card_id", ""))
	var upgraded: bool = bool(entry.get("upgraded", false))

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(190, 270)
	wrapper.add_theme_constant_override("separation", 4)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(180, 250)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
	)
	art_holder.add_child(frame)
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		if upgraded and card.has_method("set_card_data"):
			# Re-apply upgraded card_info so cost/desc/effects all refresh.
			card.set_card_data(CARD_UPGRADE.resolve(card.card_info))
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 18)
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2(160.0 / 208.0, 160.0 / 208.0)
		art_holder.add_child(card)
	wrapper.add_child(art_holder)

	return wrapper
