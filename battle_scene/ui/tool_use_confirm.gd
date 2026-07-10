extends Control

signal confirmed(index: int, tool_id: String)
signal cancelled

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

var _index := -1
var _tool_id := ""
var _tool_data: Dictionary = {}
var _settled := false


func setup(index: int, tool_id: String, tool_data: Dictionary) -> void:
	_index = index
	_tool_id = tool_id
	_tool_data = tool_data.duplicate(true)


func _ready() -> void:
	name = "ToolUseConfirm"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.0, 0.0, 0.0, 0.66)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ConfirmPanel"
	panel.custom_minimum_size = Vector2(430, 250)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", T.ll_charcoal_panel())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = tr("UI_BATTLE_TOOL_CONFIRM_TITLE")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", T.display_font(700))
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	column.add_child(heading)

	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 16)
	column.add_child(item_row)

	var icon := TextureRect.new()
	icon.name = "ToolIcon"
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := str(_tool_data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	item_row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.custom_minimum_size = Vector2(270, 0)
	copy.add_theme_constant_override("separation", 6)
	item_row.add_child(copy)

	var title := Label.new()
	title.name = "ToolName"
	title.text = Settings.t(
		"TOOL_%s_TITLE" % _tool_id, str(_tool_data.get("title", _tool_id))
	)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", T.TEXT_MAIN)
	copy.add_child(title)

	var description := Label.new()
	description.name = "ToolDescription"
	description.text = Settings.t("TOOL_%s_DESC" % _tool_id, "")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	copy.add_child(description)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)

	var cancel_button := _make_button("CancelButton", tr("UI_COMMON_CANCEL"), false)
	cancel_button.pressed.connect(cancel)
	actions.add_child(cancel_button)
	var use_button := _make_button("UseButton", tr("UI_BATTLE_TOOL_USE"), true)
	use_button.pressed.connect(confirm)
	actions.add_child(use_button)
	use_button.grab_focus()


func _make_button(node_name: String, label: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_stylebox_override(
		"normal", T.ll_button("normal") if primary else T.ll_button_olive("normal")
	)
	button.add_theme_stylebox_override(
		"hover", T.ll_button("hover") if primary else T.ll_button_olive("hover")
	)
	button.add_theme_stylebox_override(
		"pressed", T.ll_button("pressed") if primary else T.ll_button_olive("pressed")
	)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cancel()


func confirm() -> void:
	if _settled:
		return
	_settled = true
	confirmed.emit(_index, _tool_id)
	queue_free()


func cancel() -> void:
	if _settled:
		return
	_settled = true
	cancelled.emit()
	queue_free()
