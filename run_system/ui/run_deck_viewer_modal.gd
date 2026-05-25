## Read-only run-deck viewer. Renders every card in RunManager.player_deck
## via JsonCardFactory so upgraded cards show their `+` title naturally
## (card_id swap to "_plus" makes the factory load the _plus.json variant).
## Opened from the map screen via the [📚 DECK] button.
extends Control
class_name RunDeckViewerModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")

var _card_factory: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(160, 220)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(1100, 720)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header with close X
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "RUN DECK (%d cards)" % RunManager.player_deck.size()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)

	# Subtitle hint about upgrades
	var subtitle := Label.new()
	subtitle.text = "Upgraded cards show a [+] suffix on their name."
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vbox.add_child(subtitle)

	# Scrollable grid of cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1040, 580)
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	if RunManager.player_deck.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "(Deck is empty.)"
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(none_lbl)
		return

	for entry in RunManager.player_deck:
		var card_id: String = str(entry.get("card_id", ""))
		if card_id == "":
			continue
		grid.add_child(_make_card_slot(card_id))


func _make_card_slot(card_id: String) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(180, 260)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Upgraded cards get a subtle gold tint to stand out
	var is_upgraded := card_id.ends_with("_plus")
	var border := Color(1.0, 0.85, 0.35) if is_upgraded else T.PANEL_BORDER
	frame.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), border, 3))
	wrapper.add_child(frame)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 20)
		wrapper.add_child(card)

	return wrapper
