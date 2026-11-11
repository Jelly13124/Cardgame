## Shared run-deck and battle pile page.
extends Control

signal closed

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const CARD_FACTORY_SCENE = preload("uid://diap3gdfbqvjv")  # res://ui/battle/card_framework_adapters/my_card_factory.tscn
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://core/run/card_upgrade.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd

const CARD_SIZE := Vector2(208, 286)
const GRID_GAP := 22
const PAGE_MARGIN := 48

var dismiss_on_cancel := true
var _card_factory: Node
var _grid: GridContainer
var _title_text := ""
var _entries_override: Variant = null


func configure(title_text: String, entries: Array) -> void:
	_title_text = title_text
	_entries_override = entries.duplicate(true)


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
	_card_factory.card_size = CARD_SIZE
	_build()
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	set_position(Vector2.ZERO)
	set_size(get_viewport_rect().size)
	if _grid != null:
		var available_width := size.x - 2 * PAGE_MARGIN - 20.0
		_grid.columns = clampi(floori((available_width + GRID_GAP) / (CARD_SIZE.x + GRID_GAP)), 1, 7)


func _build() -> void:
	# Opaque full-screen page (pseudo-scene). Map _input is gated separately so
	# clicks can't fall through; in battle the STOP overlay blocks card input.
	var bg := ColorRect.new()
	bg.name = "RunDeckBackground"
	bg.color = T.UI_WINDOW_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "RunDeckContent"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = RUN_TOP_BAR.BAR_HEIGHT
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, PAGE_MARGIN)
	margin.add_theme_constant_override("margin_top", 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var entries: Array = RunManager.player_deck if _entries_override == null else _entries_override
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.name = "RunDeckTitle"
	title.text = _title_text if _title_text != "" else tr("UI_COMMON_RUN_DECK_TITLE").format({"n": entries.size()})
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.style_display(title, 30, 700)
	title.add_theme_color_override("font_color", T.TEXT_MAIN)
	header.add_child(title)
	var close := T.ll_close_button()
	close.name = "RunDeckClose"
	close.tooltip_text = tr("PAUSE_BACK")
	close.pressed.connect(_close)
	header.add_child(close)
	vbox.add_child(T.ui_divider())

	# Card grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	center.add_child(_grid)
	for entry in entries:
		var data: Dictionary
		if entry is Control and "card_info" in entry:
			data = {"card_id": str(entry.card_info.get("id", "")), "card_info": entry.card_info.duplicate(true)}
		else:
			data = entry if entry is Dictionary else {"card_id": str(entry)}
		if str(data.get("card_id", data.get("name", ""))) != "":
			var slot := _make_card_slot(data)
			if slot != null:
				_grid.add_child(slot)


func _close() -> void:
	hide()
	queue_free()
	closed.emit()


## ESC closes the page. Battle's top-bar only consumes ESC when its settings menu
## is already visible, so this never conflicts; the map has no ESC handler.
func _input(event: InputEvent) -> void:
	if dismiss_on_cancel and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## One deck card: its art (upgraded entries render their upgraded stats).
func _make_card_slot(entry: Dictionary) -> Control:
	var card_id: String = str(entry.get("card_id", entry.get("name", "")))
	var card = _card_factory.create_card(card_id, null)
	if card == null:
		return null
	if card.get_parent():
		card.get_parent().remove_child(card)
	var info: Dictionary = entry.get("card_info", card.card_info).duplicate(true)
	if not entry.has("card_info") and bool(entry.get("upgraded", false)):
		info = CARD_UPGRADE.resolve(info)
	card.show_front = true
	card.can_be_interacted_with = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2.ZERO
	card.pivot_offset = Vector2.ZERO
	var slot := Control.new()
	slot.custom_minimum_size = CARD_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(card)
	# Live stat and pipeline text needs the preview back in its scene context.
	slot.ready.connect(func(): card.set_card_data(info), CONNECT_ONE_SHOT)
	return slot
