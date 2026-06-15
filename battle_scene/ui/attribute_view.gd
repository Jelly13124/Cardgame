## In-battle character glance — READ-ONLY view of the five attributes (+ HP /
## Level). Opened with the `i` key during combat. Deliberately has no backpack /
## equipment interaction (per design: battle shows stats only). No class_name
## per ADR-0006; owner toggles it on a CanvasLayer.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

const ATTRS := ["strength", "constitution", "intelligence", "luck", "charm"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = tr("CHAR_VIEW_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	# HP + Level context line (read-only).
	box.add_child(
		_stat_row(
			tr("CHAR_VIEW_HP"),
			"%d / %d" % [int(RunManager.current_health), int(RunManager.max_health)]
		)
	)
	box.add_child(_stat_row(tr("CHAR_VIEW_LEVEL"), str(int(RunManager.level))))

	box.add_child(HSeparator.new())

	for attr in ATTRS:
		var name_text: String = tr("UI_COMBAT_ATTR_%s" % attr.to_upper())
		var val: int = int(RunManager.player_attributes.get(attr, 0))
		box.add_child(_stat_row(name_text, str(val)))

	box.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = tr("CHAR_VIEW_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	box.add_child(hint)


## One "label .... value" row.
func _stat_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", T.TEXT_MAIN)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	v.text = value_text
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 20)
	v.add_theme_color_override("font_color", T.SAND_LIGHT)
	row.add_child(v)
	return row
