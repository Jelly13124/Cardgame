extends Control

## Slay-the-Spire style procedural map drawn over a wasteland map background.
## The route remains data-driven; only the presentation is custom-drawn here.

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const MAP_RENDERER_SCRIPT = preload("res://run_system/ui/map_renderer.gd")
const EQUIPMENT_PANEL_SCRIPT = preload("res://run_system/ui/equipment_panel.gd")
const RUN_DECK_VIEWER_MODAL = preload("res://run_system/ui/run_deck_viewer_modal.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")
const SETTINGS_PANEL_SCRIPT = preload("res://run_system/ui/settings_panel.gd")
const EVENT_MODAL_SCRIPT = preload("res://run_system/ui/event_modal.gd")
const T_THEME = preload("res://run_system/ui/theme/wasteland_theme.gd")
const BATTLE_PACKED = preload("res://battle_scene/battle_scene.tscn")
const SHOP_PACKED = preload("res://run_system/ui/shop_scene.tscn")
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
## Re-entrancy guard for _on_node_clicked. The handler awaits a 0.35s
## timer before transitioning; without this, a rapid second click on a
## CHILD of the just-clicked node passes _is_accessible and starts a
## second coroutine that clobbers current_encounter / current_node_id.
var _node_click_pending: bool = false
var _renderer: RefCounted  # MapRenderer; kept untyped to avoid class_name parse ordering


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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

	get_viewport().size_changed.connect(_on_viewport_resized)
	_build_relic_choice_layer()
	_build_top_bar()

	# Act-transition toast: only when the map scene loads on a freshly generated
	# act > 1 (advance_act cleared the walk + node selection). Act 1's first map
	# is excluded by the act>1 guard.
	if rm.current_act > 1 and rm.current_node_id == "" and rm.visited_node_ids.is_empty():
		_show_popup(tr("UI_MAP_ENTER_ACT").format({"n": rm.current_act}))

	# In-run checkpoint: the map is the only non-battle save point. Reached on a
	# fresh run, after every battle, and on resume — so the save always reflects
	# "at the map, about to pick the next node."
	if rm.is_run_active:
		rm.save_run()


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
	# `i` toggles the character / equipment panel (full version on the map).
	# Handled before the modal guard so it can also close itself; won't stack on
	# top of another full-screen page.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if get_node_or_null("EquipmentPanel") or not _is_page_open():
			_open_equipment_panel()
		return

	# Block ALL map input while any modal is open (relic choice, rest choice,
	# treasure equipment grant, inventory-full, extract, etc.) OR a node-click
	# coroutine is still resolving. Without this, a click outside a non-FULL_RECT
	# modal can re-enter _on_node_clicked and clobber rm.current_encounter mid-
	# transition, leaving the modal orphaned in a freed scene.
	if _is_relic_choice_open or _node_click_pending or _is_page_open():
		return

	if event is InputEventMouseMotion:
		var node = _get_node_at(event.position)
		var new_id = node.get("id", "") if not node.is_empty() else ""
		if new_id != _hovered_node_id:
			_hovered_node_id = new_id
			queue_redraw()
		if _is_dragging:
			_scroll_offset = clampf(
				_drag_start_scroll - (event.position.x - _drag_start_x), 0.0, _max_scroll
			)
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


## True while a full-screen page (character / run-deck) is mounted over the map.
## map_scene resolves node clicks in the GLOBAL _input(), which fires regardless
## of the opaque page painted on top — without this gate, clicks pass through to
## map nodes (the 误触 bug).
func _is_page_open() -> bool:
	return (
		get_node_or_null("EquipmentPanel") != null or get_node_or_null("RunDeckViewerModal") != null
	)


func _on_node_clicked(node: Dictionary) -> void:
	if _node_click_pending:
		return
	_node_click_pending = true
	rm.current_node_id = node.id
	rm.current_floor = node.floor
	if not (node.id in rm.visited_node_ids):
		rm.visited_node_ids.append(node.id)
	queue_redraw()

	await get_tree().create_timer(0.35).timeout

	# Each branch is responsible for releasing _node_click_pending when its
	# work is done:
	#   - scene-change branches don't need to release (scene tears down)
	#   - modal-opening branches release in their CLOSE callbacks
	#   - popup-only branches release synchronously below
	match node.type:
		"relic":
			_open_relic_choice(tr("UI_MAP_CHOOSE_STARTING_RELIC"), "starting")
		"enemy", "elite", "boss":
			rm.current_encounter = rm.select_encounter(node.type, int(node.floor))
			rm.last_battle_node_type = node.type
			get_tree().change_scene_to_packed(BATTLE_PACKED)
		"rest":
			_open_rest_choice()
		"merchant":
			get_tree().change_scene_to_packed(SHOP_PACKED)
		"treasure":
			# Treasure is always a 3-choose-1 relic pick. _open_relic_choice handles
			# the empty-pool fallback (gold) and manages the click guard.
			_open_relic_choice(tr("UI_MAP_CHOOSE_A_RELIC"), "treasure")
		"unknown":
			_open_event_node(int(node.floor))
		_:
			# Defense-in-depth: an unrecognized node type must still release the
			# click guard, or the whole map locks up (the stuck-guard class of bug).
			push_warning("map: unhandled node type '%s'" % str(node.type))
			_node_click_pending = false


## "?" map node — try to open a data-driven random event. If no events are
## loaded, fall back to the legacy random-outcome roll (the safety net). The
## click guard is released by the modal's `resolved` callback (mirroring
## _on_relic_choice_selected); the fallback releases it on its own paths.
func _open_event_node(floor_idx: int) -> void:
	var event: Dictionary = rm.pick_random_event()
	if event.is_empty():
		_resolve_unknown_node(floor_idx)
		return

	var layer := CanvasLayer.new()
	layer.name = "EventModalLayer"
	layer.layer = 120
	add_child(layer)

	var modal = EVENT_MODAL_SCRIPT.new()
	modal.event_data = event
	modal.resolved.connect(
		func():
			_node_click_pending = false  # release click guard so next node is clickable
			layer.queue_free()
			queue_redraw()
	)
	layer.add_child(modal)


## "?" map node — rolls one of several outcomes for variety. Probabilities:
##   40% enemy ambush       — same as before, drops into combat
##   18% scavenge gold      — small pile of gold (5-20), into the backpack
##   15% core cache         — 10-30 Core (only banks on extraction)
##   12% scrap stash heal   — heal 6-12 HP (capped at max)
##    7% free equipment     — uses the treasure-style grant path
##    8% suspicious cache    — lose 6 HP, gain a relic (skipped if no relics left)
func _resolve_unknown_node(floor_idx: int) -> void:
	var roll: float = randf()

	if roll < 0.40:
		rm.current_encounter = rm.select_encounter("enemy", floor_idx)
		rm.last_battle_node_type = "enemy"
		get_tree().change_scene_to_packed(BATTLE_PACKED)
		# Scene change tears down — no need to reset click guard.
		return

	if roll < 0.58:
		var gold: int = randi_range(5, 20)
		RunManager.add_gold(gold)
		_show_popup(tr("UI_MAP_SCAVENGED_GOLD").format({"n": gold}))
		_node_click_pending = false
		return

	if roll < 0.73:
		# Core stays in the backpack and only counts on a successful extraction.
		var amt: int = randi_range(10, 30)
		RunManager.add_core_to_backpack(amt)
		_show_popup(tr("UI_MAP_CORE_DROP").format({"n": amt}))
		_node_click_pending = false
		return

	if roll < 0.85:
		var heal_amt: int = randi_range(6, 12)
		var before: int = rm.current_health
		rm.modify_health(heal_amt)
		var actual: int = rm.current_health - before
		_show_popup(tr("UI_MAP_SCRAP_MEDKIT_HEAL").format({"n": actual}))
		_node_click_pending = false
		return

	if roll < 0.92:
		# _grant_treasure_equipment resets the click guard on every path
		# (popup-only paths reset synchronously).
		_grant_treasure_equipment()
		return

	# Tail 8%: suspicious cache. Skip if no relics to grant OR player at
	# 1 HP (no payable cost — would be a free relic + "-0 HP" copy).
	if rm.get_unowned_relic_ids().is_empty() or rm.current_health <= 1:
		RunManager.add_gold(15)
		_show_popup(tr("UI_MAP_CACHE_EMPTY_GOLD").format({"n": 15}))
		_node_click_pending = false
		return
	# Cap loss at 6 and at (current_health - 1) so cache can never solo-
	# kill the player. Routes through modify_health for death-gate safety.
	var hp_loss: int = clampi(rm.current_health - 1, 1, 6)
	rm.modify_health(-hp_loss)
	# Click guard stays latched — _open_relic_choice will reset it via
	# _on_relic_choice_selected when player picks.
	_open_relic_choice(tr("UI_MAP_CACHE_PRIED_OPEN").format({"n": hp_loss}), "treasure")


## Brief on-map toast for node outcomes that have no other obvious result
## (?-room scavenge/heal/cache, treasure equipment grant, "nothing remains").
## The earlier popup-strip turned this into a no-op, which silently dropped the
## ONLY feedback for those outcomes — they read as dead clicks. Restored, but
## restrained: small, top-of-screen, fast auto-fade (not the old center banner).
func _show_popup(text: String) -> void:
	if text.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 96
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)


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
		_node_click_pending = false
		return

	var choices: Array[String] = rm.roll_relic_choices(3)
	if choices.is_empty():
		if source_type == "treasure":
			var gold = randi_range(20, 45)
			RunManager.add_gold(gold)
			_show_popup(tr("UI_MAP_NO_RELICS_FOUND_GOLD").format({"n": gold}))
		else:
			_show_popup(tr("UI_MAP_NO_RELICS_REMAIN"))
		_node_click_pending = false
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
	hint.text = tr("UI_MAP_RELIC_PICK_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	_relic_choice_box.add_child(hint)

	for relic_id in choices:
		_relic_choice_box.add_child(_make_relic_choice_button(relic_id, source_type))

	_is_relic_choice_open = true
	_relic_choice_layer.visible = true


func _make_relic_choice_button(relic_id: String, source_type: String) -> Button:
	var data = rm.get_relic_data(relic_id)
	var title = Settings.t(
		"RELIC_%s_TITLE" % relic_id, str(data.get("title", _humanize_id(relic_id)))
	)
	var description = Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))

	var button = Button.new()
	button.custom_minimum_size = Vector2(620, 82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", T.button_textured("normal"))
	button.add_theme_stylebox_override("hover", T.button_textured("hover"))
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
	var icon_slot := CenterContainer.new()
	icon_slot.custom_minimum_size = Vector2(62, 62)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_slot)
	if icon_texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(50, 50)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon_slot.add_child(icon)
	else:
		var icon = Label.new()
		icon.custom_minimum_size = Vector2(50, 50)
		icon.text = title.substr(0, 1).to_upper()
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 28)
		icon.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		icon_slot.add_child(icon)

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
	desc_text.add_theme_font_size_override("font_size", 20)
	desc_text.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70))
	text_box.add_child(desc_text)

	return button


func _on_relic_choice_selected(relic_id: String, _source_type: String) -> void:
	_is_relic_choice_open = false
	_node_click_pending = false  # release click guard so the next map node is clickable
	_relic_choice_layer.visible = false

	if rm.add_relic(relic_id):
		var data = rm.get_relic_data(relic_id)
		var relic_title = Settings.t(
			"RELIC_%s_TITLE" % relic_id, str(data.get("title", _humanize_id(relic_id)))
		)
		_show_popup(tr("UI_MAP_GAINED_RELIC").format({"n": relic_title}))
	else:
		_show_popup(tr("UI_MAP_ALREADY_HAVE_RELIC"))
	queue_redraw()


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _build_top_bar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TopBarLayer"
	layer.layer = 50
	add_child(layer)

	var bar := RUN_TOP_BAR.new()
	bar.hp_from_player = false
	bar.show_character_button = true
	bar.show_settings_button = true
	bar.deck_pressed.connect(_open_run_deck_viewer)
	bar.character_pressed.connect(_open_equipment_panel)
	bar.settings_pressed.connect(_open_settings)
	layer.add_child(bar)


## Settings overlay (language / fullscreen / volume) — same pattern as the home
## base's _open_settings. Language change reloads the map scene (state lives in
## RunManager, so a reload is lossless).
func _open_settings() -> void:
	if get_node_or_null("SettingsOverlay") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "SettingsOverlay"
	layer.layer = 130
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 380)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	box.add_child(title)

	SETTINGS_PANEL_SCRIPT.add_controls(
		box, func() -> void: get_tree().reload_current_scene(), false
	)

	box.add_child(HSeparator.new())

	var howto_btn := Button.new()
	howto_btn.text = tr("MENU_HOWTO")
	howto_btn.custom_minimum_size = Vector2(300, 44)
	T.apply_button_theme(howto_btn)
	howto_btn.pressed.connect(_open_rules_panel)
	box.add_child(howto_btn)

	var save_quit_btn := Button.new()
	save_quit_btn.text = tr("SETTINGS_SAVE_QUIT")
	save_quit_btn.custom_minimum_size = Vector2(300, 44)
	T.apply_button_theme(save_quit_btn)
	save_quit_btn.pressed.connect(_on_save_and_quit)
	box.add_child(save_quit_btn)

	var close_btn := Button.new()
	close_btn.text = tr("SETTINGS_RESUME")
	close_btn.custom_minimum_size = Vector2(300, 44)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(layer.queue_free)
	box.add_child(close_btn)


## Save the run at this map checkpoint and return to the title screen. Continue
## from the menu resumes here.
func _on_save_and_quit() -> void:
	if rm and rm.is_run_active:
		rm.save_run()
	get_tree().change_scene_to_file("res://run_system/ui/main_menu.tscn")


## Open the How-to-Play rules panel (loaded at runtime; no-op until it exists).
func _open_rules_panel() -> void:
	var path := "res://run_system/ui/rules_panel.gd"
	if not ResourceLoader.exists(path):
		return
	var script = load(path)
	if script == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "RulesLayer"
	layer.layer = 140
	add_child(layer)
	var panel = script.new()
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _open_equipment_panel() -> void:
	var existing = get_node_or_null("EquipmentPanel")
	if existing:
		existing.queue_free()
		return
	var panel = EQUIPMENT_PANEL_SCRIPT.new()
	panel.name = "EquipmentPanel"
	add_child(panel)
	_hide_top_bar_for_page(panel)


func _open_run_deck_viewer() -> void:
	var existing = get_node_or_null("RunDeckViewerModal")
	if existing:
		existing.queue_free()
		return
	var modal = RUN_DECK_VIEWER_MODAL.new()
	modal.name = "RunDeckViewerModal"
	add_child(modal)
	_hide_top_bar_for_page(modal)


## A full-screen page (character / run-deck) sits at map_scene's canvas layer,
## BELOW the TopBarLayer (CanvasLayer, layer 50) — so the top bar (incl. its relic
## shelf) bled over the page and doubled the relics. Hide the bar while a page is
## up; restore it when the page closes (X / ESC / toggle) via tree_exited. Capture
## the layer node directly + guard it, so a scene-change teardown can't deref a
## freed map_scene.
func _hide_top_bar_for_page(page: Node) -> void:
	var bar_layer := get_node_or_null("TopBarLayer")
	if not bar_layer:
		return
	bar_layer.visible = false
	page.tree_exited.connect(
		func():
			if is_instance_valid(bar_layer):
				bar_layer.visible = true
	)


## Treasure equipment drop: 70% uncommon / 30% rare. Drops straight into the
## backpack; if every cell is taken the item is left behind with a notice.
func _grant_treasure_equipment() -> void:
	var rarity := "uncommon" if randf() < 0.7 else "rare"
	var item_id = RunManager.roll_equipment_drop(rarity)
	if item_id == "":
		_show_popup(tr("UI_MAP_CRATE_EMPTY"))
		_node_click_pending = false
		return
	var data = RunManager.get_equipment_data(item_id)
	var item_name = Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
	if RunManager.add_equip_to_backpack(RunManager.make_equip_instance(item_id, rarity)):
		_show_popup(tr("UI_MAP_FOUND_EQUIPMENT").format({"n": item_name}))
	else:
		# Backpack full — gold/core/equipment all share the 20 cells now, so
		# there is no dedicated equip overflow. Leave the item behind.
		_show_popup(tr("UI_MAP_BACKPACK_FULL").format({"n": item_name}))
	_node_click_pending = false


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
	title.text = tr("UI_MAP_REST_STOP")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	vbox.add_child(title)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	vbox.add_child(buttons)

	var heal_btn := Button.new()
	heal_btn.text = tr("UI_MAP_REST_HEAL_BTN")
	heal_btn.custom_minimum_size = Vector2(200, 60)
	heal_btn.pressed.connect(
		func():
			var heal_amount = int(rm.max_health * 0.25)
			rm.modify_health(heal_amount)
			_show_popup(tr("UI_MAP_RESTED_HEAL").format({"n": heal_amount}))
			modal.queue_free()
			_node_click_pending = false  # release click guard
	)
	buttons.add_child(heal_btn)

	# Gem socketing: open the deck/gem screen so the player can slot collected gems
	# into their cards (card upgrades were removed — gems are the growth axis).
	var gems_btn := Button.new()
	gems_btn.text = tr("UI_MAP_REST_GEMS_BTN")
	gems_btn.custom_minimum_size = Vector2(200, 60)
	gems_btn.pressed.connect(
		func():
			modal.queue_free()
			_node_click_pending = false
			_open_run_deck_viewer()
	)
	buttons.add_child(gems_btn)
