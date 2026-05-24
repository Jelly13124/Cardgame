## Card-upgrade picker modal. Lists every NON-upgraded card in the run deck;
## clicking one upgrades it via RunManager.upgrade_card_by_uid and emits
## `picked(uid)`. Cancel button emits `picked("")`. Caller is responsible for
## freeing this node after handling the signal (the modal auto-queue_frees
## on either branch).
extends Control
class_name CardUpgradeModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal picked(uid: String)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	# Dim background — clicks blocked
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(760, 540)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "UPGRADE A CARD"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a card to permanently upgrade for the rest of the run."
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(subtitle)

	# Scrollable list of upgrade candidates
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(720, 380)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var candidates_added := 0
	for entry in RunManager.player_deck:
		var card_id: String = str(entry.get("card_id", ""))
		var uid: String = str(entry.get("uid", ""))
		if card_id == "" or uid == "":
			continue
		if card_id.ends_with("_plus"):
			continue
		# Confirm a _plus variant exists (defensive — same check as RunManager)
		var path := "res://battle_scene/card_info/player/" + card_id + "_plus.json"
		if not FileAccess.file_exists(path):
			continue
		list.add_child(_build_row(card_id, uid))
		candidates_added += 1

	if candidates_added == 0:
		var none_lbl := Label.new()
		none_lbl.text = "(All cards in your deck are already upgraded.)"
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		list.add_child(none_lbl)

	# Cancel button
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(120, 36)
	cancel.pressed.connect(_on_cancel)
	actions.add_child(cancel)


func _build_row(card_id: String, uid: String) -> Button:
	var base_data = _load_card_json(card_id)
	var plus_data = _load_card_json(card_id + "_plus")
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.text = "%s   →   %s\n  %s" % [
		str(base_data.get("title", card_id)),
		str(plus_data.get("title", card_id + "+")),
		str(plus_data.get("description", "(no preview)")),
	]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_card_pressed.bind(uid))
	return btn


func _load_card_json(card_id: String) -> Dictionary:
	var path := "res://battle_scene/card_info/player/" + card_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _on_card_pressed(uid: String) -> void:
	RunManager.upgrade_card_by_uid(uid)
	emit_signal("picked", uid)
	queue_free()


func _on_cancel() -> void:
	emit_signal("picked", "")
	queue_free()
