extends Control

## Slay-the-Spire style procedural map drawn over a wasteland map background.
## The route remains data-driven; only the presentation is custom-drawn here.

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const MAP_RENDERER_SCRIPT = preload("res://run_system/ui/map_renderer.gd")
const EQUIPMENT_PANEL_SCRIPT = preload("res://run_system/ui/equipment_panel.gd")
const INVENTORY_FULL_MODAL_FOR_TREASURE = preload("res://run_system/ui/inventory_full_modal.gd")
const CARD_UPGRADE_MODAL = preload("res://run_system/ui/card_upgrade_modal.gd")
const T_THEME = preload("res://run_system/ui/theme/wasteland_theme.gd")
const MAP_BACKGROUND_PATH = "res://run_system/assets/images/map/wasteland_route_map_pixel_bg.png"
const NODE_ICON_DIR = "res://run_system/assets/images/map/nodes/"

const MAP_LEFT: float = 180.0
const MAP_TOP: float = 155.0
const MAP_BOTTOM_PADDING: float = 210.0
const FLOOR_SPACING: float = 310.0

# Rendering is delegated to MapRenderer; node-icon sizing constants live there too.
# Legend / TYPE_COLORS also moved into MapRenderer.

var rm: Node
var map_background_tex: Texture2D
var _node_icon_textures: Dictionary = {}
var _node_positions: Dictionary = {}
var _hovered_node_id: String = ""
var _scroll_offset: float = 0.0
var _max_scroll: float = 0.0
var _is_dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_scroll: float = 0.0
var _relic_choice_layer: CanvasLayer
var _relic_choice_box: VBoxContainer
var _is_relic_choice_open: bool = false
var _renderer: RefCounted  # MapRenderer; kept untyped to avoid class_name parse ordering


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_background_tex = _load_texture(MAP_BACKGROUND_PATH)
	_load_node_icons()
	_renderer = MAP_RENDERER_SCRIPT.new(self)

	# RunManager is a registered autoload (project.godot) — always available.
	rm = RunManager

	if rm.map_data.is_empty():
		rm.generate_map(12, 4)

	_compute_positions()
	_max_scroll = max(0.0, _get_total_width() - get_viewport_rect().size.x)
	_scroll_to_current()

	rm.health_changed.connect(func(_c, _m): queue_redraw())
	rm.resources_changed.connect(func(_g, _co): queue_redraw())
	rm.relics_updated.connect(func(): queue_redraw())
	get_viewport().size_changed.connect(_on_viewport_resized)
	_build_relic_choice_layer()
	_build_equipment_button()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	push_warning("MapScene: missing texture '%s'" % path)
	return null


func _load_node_icons() -> void:
	_node_icon_textures.clear()
	for entry in MAP_RENDERER_SCRIPT.LEGEND_ENTRIES:
		var node_type = str(entry[0])
		_node_icon_textures[node_type] = _load_texture(NODE_ICON_DIR + node_type + ".png")


func _on_viewport_resized() -> void:
	_compute_positions()
	_max_scroll = max(0.0, _get_total_width() - get_viewport_rect().size.x)
	_scroll_offset = clampf(_scroll_offset, 0.0, _max_scroll)
	queue_redraw()


func _compute_positions() -> void:
	_node_positions.clear()
	if not rm:
		return

	var vp = get_viewport_rect().size
	var max_slot = max(1, _get_max_slot())
	var map_height = maxf(260.0, vp.y - MAP_TOP - MAP_BOTTOM_PADDING)
	var slot_spacing = map_height / float(max_slot)
	var center_y = MAP_TOP + map_height * 0.5

	# Pre-count nodes per floor so we can Y-center single-node floors
	# (start relic, boss) without depending on which slot they happen to be in.
	var nodes_per_floor: Dictionary = {}
	for node in rm.map_data:
		nodes_per_floor[node.floor] = nodes_per_floor.get(node.floor, 0) + 1

	for node in rm.map_data:
		var x = MAP_LEFT + node.floor * FLOOR_SPACING
		var y: float
		if nodes_per_floor.get(node.floor, 0) == 1:
			y = center_y
		else:
			y = MAP_TOP + node.slot * slot_spacing
		_node_positions[node.id] = Vector2(x, y)


func _get_max_floor() -> int:
	var result = 0
	for node in rm.map_data:
		if node.floor > result:
			result = node.floor
	return result


func _get_max_slot() -> int:
	var result = 0
	for node in rm.map_data:
		if node.slot > result:
			result = node.slot
	return result


func _get_total_width() -> float:
	return MAP_LEFT + (_get_max_floor() + 2) * FLOOR_SPACING + 200.0


func _scroll_to_current() -> void:
	if rm.current_node_id == "":
		_scroll_offset = 0.0
		return

	var node = rm.get_node_by_id(rm.current_node_id)
	if not node.is_empty():
		var target = MAP_LEFT + node.floor * FLOOR_SPACING - get_viewport_rect().size.x * 0.35
		_scroll_offset = clampf(target, 0.0, _max_scroll)


func _get_screen_pos(node_id: String) -> Vector2:
	if node_id in _node_positions:
		return _node_positions[node_id] - Vector2(_scroll_offset, 0)
	return Vector2.ZERO


func _draw() -> void:
	if _renderer:
		_renderer.draw(get_viewport_rect().size)


func _is_accessible(node_data: Dictionary) -> bool:
	if node_data.floor == 0 and rm.current_node_id == "":
		return true
	if rm.current_node_id != "":
		var current = rm.get_node_by_id(rm.current_node_id)
		if not current.is_empty() and node_data.id in current.children:
			return true
	return false


func _get_node_at(pos: Vector2) -> Dictionary:
	for node in rm.map_data:
		var sp = _get_screen_pos(node.id)
		if pos.distance_to(sp) <= MAP_RENDERER_SCRIPT.NODE_RADIUS + 8:
			return node
	return {}


func _input(event: InputEvent) -> void:
	if _is_relic_choice_open:
		return

	if event is InputEventMouseMotion:
		var node = _get_node_at(event.position)
		var new_id = node.get("id", "") if not node.is_empty() else ""
		if new_id != _hovered_node_id:
			_hovered_node_id = new_id
			queue_redraw()
		if _is_dragging:
			_scroll_offset = clampf(_drag_start_scroll - (event.position.x - _drag_start_x), 0.0, _max_scroll)
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var node = _get_node_at(event.position)
				if not node.is_empty() and _is_accessible(node):
					_on_node_clicked(node)
				else:
					_is_dragging = true
					_drag_start_x = event.position.x
					_drag_start_scroll = _scroll_offset
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = clampf(_scroll_offset + 50.0, 0.0, _max_scroll)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset = clampf(_scroll_offset - 50.0, 0.0, _max_scroll)
			queue_redraw()


func _on_node_clicked(node: Dictionary) -> void:
	rm.current_node_id = node.id
	rm.current_floor = node.floor
	queue_redraw()

	await get_tree().create_timer(0.35).timeout

	match node.type:
		"relic":
			_open_relic_choice("Choose Your Starting Relic", "starting")
		"enemy", "elite", "boss":
			rm.current_encounter = rm.select_encounter(node.type, int(node.floor))
			rm.last_battle_node_type = node.type
			get_tree().change_scene_to_file(rm.BATTLE_SCENE)
		"rest":
			_open_rest_choice()
		"merchant":
			_show_popup("The merchant waves... nothing to sell yet.")
		"treasure":
			if randf() < 0.5:
				_open_relic_choice("Choose a Relic", "treasure")
			else:
				_grant_treasure_equipment()
		"unknown":
			if randf() < 0.5:
				rm.current_encounter = rm.select_encounter("enemy", int(node.floor))
				rm.last_battle_node_type = "enemy"
				get_tree().change_scene_to_file(rm.BATTLE_SCENE)
			else:
				var gold = randi_range(5, 20)
				rm.add_resources(gold, 0)
				_show_popup("Scavenged %d gold." % gold)


func _show_popup(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.y += 80
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(1.5)
	tween.tween_callback(label.queue_free)
	queue_redraw()


func _build_relic_choice_layer() -> void:
	_relic_choice_layer = CanvasLayer.new()
	_relic_choice_layer.name = "RelicChoiceLayer"
	_relic_choice_layer.layer = 80
	_relic_choice_layer.visible = false
	add_child(_relic_choice_layer)

	var root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_relic_choice_layer.add_child(root)

	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.56)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	var center = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(720, 410)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	_relic_choice_box = VBoxContainer.new()
	_relic_choice_box.name = "Choices"
	_relic_choice_box.add_theme_constant_override("separation", 14)
	panel.add_child(_relic_choice_box)


func _open_relic_choice(title: String, source_type: String) -> void:
	if not rm:
		return

	var choices: Array[String] = rm.roll_relic_choices(3)
	if choices.is_empty():
		if source_type == "treasure":
			var gold = randi_range(20, 45)
			rm.add_resources(gold, 0)
			_show_popup("No relics remain. Found %d gold!" % gold)
		else:
			_show_popup("No relics remain.")
		return

	for child in _relic_choice_box.get_children():
		child.queue_free()

	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_relic_choice_box.add_child(title_label)

	var hint = Label.new()
	hint.text = "Pick one. Relics are unique for this run."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	_relic_choice_box.add_child(hint)

	for relic_id in choices:
		_relic_choice_box.add_child(_make_relic_choice_button(relic_id, source_type))

	_is_relic_choice_open = true
	_relic_choice_layer.visible = true


func _make_relic_choice_button(relic_id: String, source_type: String) -> Button:
	var data = rm.get_relic_data(relic_id)
	var title = str(data.get("title", _humanize_id(relic_id)))
	var description = str(data.get("description", ""))

	var button = Button.new()
	button.custom_minimum_size = Vector2(620, 82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal",  T.button_textured("normal"))
	button.add_theme_stylebox_override("hover",   T.button_textured("hover"))
	button.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	button.pressed.connect(_on_relic_choice_selected.bind(relic_id, source_type))

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)

	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon_path = str(data.get("icon", ""))
	var icon_texture = _load_texture(icon_path) if not icon_path.is_empty() else null
	if icon_texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(58, 58)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	else:
		var icon = Label.new()
		icon.custom_minimum_size = Vector2(54, 54)
		icon.text = title.substr(0, 1).to_upper()
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 28)
		icon.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		row.add_child(icon)

	var text_box = VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title_text = Label.new()
	title_text.text = title
	title_text.add_theme_font_size_override("font_size", 22)
	title_text.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	text_box.add_child(title_text)

	var desc_text = Label.new()
	desc_text.text = description
	desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_text.add_theme_font_size_override("font_size", 15)
	desc_text.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70))
	text_box.add_child(desc_text)

	return button


func _on_relic_choice_selected(relic_id: String, _source_type: String) -> void:
	_is_relic_choice_open = false
	_relic_choice_layer.visible = false

	if rm.add_relic(relic_id):
		var data = rm.get_relic_data(relic_id)
		_show_popup("Gained relic: %s" % str(data.get("title", _humanize_id(relic_id))))
	else:
		_show_popup("Already have that relic.")
	queue_redraw()


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _build_equipment_button() -> void:
	var equip_btn := Button.new()
	equip_btn.text = "⚔ CHARACTER"
	equip_btn.add_theme_font_size_override("font_size", 16)
	T.apply_button_theme(equip_btn)
	# Anchor to top-right corner with a small margin
	equip_btn.anchor_left = 1.0
	equip_btn.anchor_right = 1.0
	equip_btn.anchor_top = 0.0
	equip_btn.anchor_bottom = 0.0
	equip_btn.offset_left = -200.0
	equip_btn.offset_right = -12.0
	equip_btn.offset_top = 12.0
	equip_btn.offset_bottom = 52.0
	equip_btn.pressed.connect(_open_equipment_panel)
	add_child(equip_btn)


func _open_equipment_panel() -> void:
	var existing = get_node_or_null("EquipmentPanel")
	if existing:
		existing.queue_free()
		return
	var panel = EQUIPMENT_PANEL_SCRIPT.new()
	panel.name = "EquipmentPanel"
	add_child(panel)


## Treasure equipment drop: 70% uncommon / 30% rare. Either adds directly to
## inventory or opens the inventory-full modal.
func _grant_treasure_equipment() -> void:
	var rarity := "uncommon" if randf() < 0.7 else "rare"
	var item_id = RunManager.roll_equipment_drop(rarity)
	if item_id == "":
		_show_popup("The crate was empty.")
		return
	var data = RunManager.get_equipment_data(item_id)
	var item_name = str(data.get("name", item_id))
	if RunManager.add_to_inventory(item_id):
		_show_popup("Found %s!" % item_name)
		return
	# Inventory full → modal
	var modal = INVENTORY_FULL_MODAL_FOR_TREASURE.new()
	modal.setup(item_id)
	modal.resolved.connect(func(took: bool):
		if took:
			_show_popup("Took %s." % item_name)
		else:
			_show_popup("Left %s behind." % item_name)
	)
	add_child(modal)


## Rest-stop choice modal. Player picks HEAL (25% HP) or UPGRADE (open card
## picker). Cancelling the picker returns to this choice; once a path
## resolves, the modal closes and the rest is consumed.
func _open_rest_choice() -> void:
	var existing = get_node_or_null("RestChoiceModal")
	if existing:
		return  # already open

	var modal := Control.new()
	modal.name = "RestChoiceModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T_THEME.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(520, 220)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "REST STOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	vbox.add_child(title)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	vbox.add_child(buttons)

	var heal_btn := Button.new()
	heal_btn.text = "HEAL 25%% HP"  # %% escapes the % for any future format use
	heal_btn.custom_minimum_size = Vector2(200, 60)
	heal_btn.pressed.connect(func():
		var heal_amount = int(rm.max_health * 0.25)
		rm.modify_health(heal_amount)
		_show_popup("Rested. Healed %d HP." % heal_amount)
		modal.queue_free()
	)
	buttons.add_child(heal_btn)

	var upgrade_btn := Button.new()
	upgrade_btn.text = "UPGRADE A CARD"
	upgrade_btn.custom_minimum_size = Vector2(200, 60)
	upgrade_btn.pressed.connect(func():
		var picker = CARD_UPGRADE_MODAL.new()
		picker.picked.connect(func(uid: String):
			if uid == "":
				# Cancelled — leave rest choice open so player can pick HEAL
				return
			_show_popup("Card upgraded.")
			modal.queue_free()
		)
		modal.add_child(picker)
	)
	buttons.add_child(upgrade_btn)
