## Card-upgrade picker modal. Renders every NON-upgraded card in the run deck
## as actual card visuals (via JsonCardFactory). Click a card → upgrades it
## via RunManager.upgrade_card_by_uid and emits `picked(uid)`. Cancel emits
## `picked("")`. Modal queue_frees on either branch.
extends Control
class_name CardUpgradeModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")

signal picked(uid: String)

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

	var title := Label.new()
	title.text = "UPGRADE A CARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a card to permanently upgrade for the rest of the run."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	# Scrollable grid of upgrade candidates
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1040, 560)
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	var candidates_added := 0
	for entry in RunManager.player_deck:
		var card_id: String = str(entry.get("card_id", ""))
		var uid: String = str(entry.get("uid", ""))
		if card_id == "" or uid == "":
			continue
		if card_id.ends_with("_plus"):
			continue
		var path := "res://battle_scene/card_info/player/" + card_id + "_plus.json"
		if not FileAccess.file_exists(path):
			continue
		grid.add_child(_make_card_slot(card_id, uid))
		candidates_added += 1

	if candidates_added == 0:
		var none_lbl := Label.new()
		none_lbl.text = "(All cards in your deck are already upgraded.)"
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(none_lbl)

	# Cancel button
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(140, 42)
	cancel.pressed.connect(_on_cancel)
	actions.add_child(cancel)


func _make_card_slot(card_id: String, uid: String) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(180, 260)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
	)
	wrapper.add_child(frame)

	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 20)
		card.pivot_offset = Vector2(80, 110)
		wrapper.add_child(card)

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_card_pressed.bind(uid))
	wrapper.add_child(button)

	if card:
		button.mouse_entered.connect(
			func():
				frame.add_theme_stylebox_override(
					"panel",
					T.panel_with_shadow(Color(0.13, 0.095, 0.062, 0.96), T.ACCENT_NEON_BLUE, 3)
				)
				var tween = create_tween()
				tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.10)
		)
		button.mouse_exited.connect(
			func():
				frame.add_theme_stylebox_override(
					"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
				)
				var tween = create_tween()
				tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.10)
		)

	return wrapper


func _on_card_pressed(uid: String) -> void:
	RunManager.upgrade_card_by_uid(uid)
	emit_signal("picked", uid)
	queue_free()


func _on_cancel() -> void:
	emit_signal("picked", "")
	queue_free()
