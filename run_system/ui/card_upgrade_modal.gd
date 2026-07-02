## Card-upgrade picker (in-run). Full-screen modal listing every card in
## RunManager.player_deck; the player clicks ONE un-upgraded, upgradeable card to
## flip its deck entry's `upgraded` flag to true (deck-build applies the upgrade
## at battle start via card_upgrade.gd). Opened from the rest campfire.
## Non-selectable cards (already upgraded, or not meaningfully upgradeable) are
## dimmed. Emits `upgraded` on a pick, `cancelled` on close/ESC so the caller can
## release its click guard on either outcome. No `class_name` (ADR-0006).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")
const CARD_UPGRADE = preload("res://run_system/core/card_upgrade.gd")

## Emitted after the player picks a card (its entry `upgraded` is now true).
signal upgraded
## Emitted when the player closes without picking (close-X / ESC).
signal cancelled

var _card_factory: Node


func _ready() -> void:
	# MapScene's Control rect is NOT viewport-sized, so PRESET_FULL_RECT would
	# collapse to (0,0). Size ourselves to the viewport and stay updated on resize
	# (mirrors run_deck_viewer_modal).
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
	# Opaque full-screen page. Map _input is gated separately so clicks can't fall
	# through.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.035, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 48)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("UI_UPGRADE_MODAL_TITLE")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = tr("UI_UPGRADE_MODAL_HINT")
	hint.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


## Top-right ✕ — cancel path (no `upgraded`, emits `cancelled`).
func _add_close_x() -> void:
	var x := T.close_x_button()
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -64.0
	x.offset_right = -16.0
	x.offset_top = 16.0
	x.offset_bottom = 64.0
	x.pressed.connect(_cancel)
	add_child(x)


func _cancel() -> void:
	emit_signal("cancelled")
	queue_free()


## ESC closes the page (cancel path). Mirrors run_deck_viewer_modal.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


## One deck card rendered from its base card info. Selectable only when the entry
## is un-upgraded AND the base card is meaningfully upgradeable; otherwise dimmed.
func _make_card_slot(entry: Dictionary) -> Control:
	var card_id: String = str(entry.get("card_id", ""))
	var already_upgraded: bool = bool(entry.get("upgraded", false))

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(190, 300)
	wrapper.add_theme_constant_override("separation", 4)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(180, 250)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
	)
	art_holder.add_child(frame)

	# The factory-created card exposes `card_info` — the BASE card JSON dict, which
	# is exactly what is_upgradeable() expects.
	var base_info: Dictionary = {}
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		if "card_info" in card:
			base_info = card.card_info
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 18)
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2(160.0 / 208.0, 160.0 / 208.0)
		art_holder.add_child(card)
	wrapper.add_child(art_holder)

	var selectable: bool = (not already_upgraded) and CARD_UPGRADE.is_upgradeable(base_info)

	if selectable:
		# A transparent button over the card art turns the whole slot into a click
		# target without reparenting the (input-ignoring) card node.
		var pick := Button.new()
		pick.flat = true
		pick.focus_mode = Control.FOCUS_NONE
		pick.set_anchors_preset(Control.PRESET_FULL_RECT)
		pick.pressed.connect(_on_pick.bind(entry))
		art_holder.add_child(pick)
	else:
		wrapper.modulate = Color(0.4, 0.4, 0.4, 1.0)
		if already_upgraded:
			var lbl := Label.new()
			lbl.text = tr("UI_UPGRADE_ALREADY")
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
			wrapper.add_child(lbl)

	return wrapper


## Flip the REAL deck entry's `upgraded` flag. `entry` is the dictionary passed by
## reference from RunManager.player_deck (Godot Dictionaries are reference types),
## so mutating it here edits the live array element — no copy is involved.
func _on_pick(entry: Dictionary) -> void:
	entry["upgraded"] = true
	AudioManager.play_sfx("ui_click")
	emit_signal("upgraded")
	queue_free()
