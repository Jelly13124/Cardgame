extends Control

## The route map: a floor track and one card per choice on the current floor
## (ui/map/route_choice_card.gd), drawn over the wasteland map background. The
## route itself is run data (core/run/map_generator.gd, grown by
## RunManager.enter_map_node); this screen shows it and opens the chosen room.

const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const ROUTE_CHOICE_CARD = preload("uid://e44exoef6xwg")  # res://ui/map/route_choice_card.tscn
const CHARACTER_WINDOW = preload("uid://ba0f3y5ua1p6o")  # res://ui/windows/character_window.gd
const RUN_DECK_VIEWER_MODAL = preload("uid://jvxfh15gtinx")  # res://ui/common/run_deck_viewer_modal.gd
const CARD_UPGRADE_MODAL = preload("uid://gq5b8t1mbeti")  # res://ui/rest/card_upgrade_modal.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const SETTINGS_PANEL_SCRIPT = preload("uid://ledls51ku43w")  # res://ui/menus/settings_panel.gd
const PAUSE_PANEL = preload("uid://dggg8eoy0notq")  # res://ui/menus/pause_panel.gd
const EVENT_ROOM_SCRIPT = preload("res://ui/events/event_room.gd")
const T_THEME = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const BATTLE_PACKED = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const SHOP_PACKED = preload("uid://dr8unxxfi0w51")  # res://ui/shop/merchant_room.tscn
const ROOMS = preload("uid://cxmgdj3654rrj")  # res://core/run/rooms.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const MAP_BACKGROUND_PATH = "res://run_system/assets/images/map/wasteland_route_map_sts2_bg.png"
const REST_SITE_BACKGROUND_PATH = "res://run_system/assets/images/rest/rest_site_bg.png"

const CARD_GAP := 48
const CARD_SLIDE_PX := 40.0
const CARD_STAGGER := 0.06
const CHOOSE_SECONDS := 0.25

var rm: Node
var map_background_tex: Texture2D
var _relic_choice_layer: CanvasLayer
var _relic_choice_box: VBoxContainer
var _is_relic_choice_open: bool = false
## When the active relic-choice modal is a clip-upgrade pick (the Act 2+ opener),
## maps each offered relic id → the clip it REPLACES ("" = pure add / second clip).
var _upgrade_replaces: Dictionary = {}
## Re-entrancy guard for _choose: set before the choose motion, released by the
## room once it resolves (or torn down by the scene change). A second choice
## while it is set is ignored, so one floor never opens two rooms.
var _node_click_pending: bool = false
## When true, this map is a read-only PEEK overlay shown over an active battle:
## no node travel, no checkpoint save, no music swap — plus a "back to battle" button.
var peek_mode: bool = false
var _floor_track: HBoxContainer
var _choice_row: HBoxContainer


func _ready() -> void:
	if not peek_mode:
		AudioManager.play_music("map")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map_background_tex = _load_texture(MAP_BACKGROUND_PATH)

	# RunManager is a registered autoload (project.godot) — always available.
	rm = RunManager

	if rm.map_data.is_empty():
		rm.generate_map()

	_build_route_layout()
	_build_route()
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
	if rm.is_run_active and not peek_mode:
		rm.save_run()
		# A run saved inside an event reopens it (finished events show only
		# the proceed option, so nothing pays out twice).
		if str(rm.state.current_event.get("node_id", "")) == rm.current_node_id and rm.current_node_id != "":
			var resumed = rm.resume_event()
			if resumed != null:
				_node_click_pending = true
				_open_event_room(resumed)

	if peek_mode:
		_build_peek_close_button()


## "Back to battle" button shown only in peek mode — frees this map overlay (its
## parent CanvasLayer), returning to the untouched BattleScene underneath.
func _build_peek_close_button() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PeekClose"
	layer.layer = 100
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var btn := Button.new()
	btn.text = tr("UI_MAP_BACK_TO_BATTLE")
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(240, 50)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	btn.position = Vector2(-120, 14)
	btn.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_click")
			get_parent().queue_free()
	)
	holder.add_child(btn)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	push_warning("MapScene: missing texture '%s'" % path)
	return null


func _draw() -> void:
	if map_background_tex:
		draw_texture_rect(map_background_tex, Rect2(Vector2.ZERO, size), false)


## The floor track under the top bar and the centred row of choice cards.
func _build_route_layout() -> void:
	var column := VBoxContainer.new()
	column.name = "RouteColumn"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = RUN_TOP_BAR.BAR_HEIGHT + 24.0
	column.offset_bottom = -40.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_floor_track = HBoxContainer.new()
	_floor_track.name = "FloorTrack"
	_floor_track.alignment = BoxContainer.ALIGNMENT_CENTER
	_floor_track.add_theme_constant_override("separation", 8)
	_floor_track.custom_minimum_size = Vector2(0, 12)
	_floor_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_floor_track)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	_choice_row = HBoxContainer.new()
	_choice_row.name = "ChoiceRow"
	_choice_row.add_theme_constant_override("separation", CARD_GAP)
	_choice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_choice_row)


## The nodes the player can choose now: the start node on a fresh act, else
## the current node's children.
func _choices() -> Array:
	if rm.current_node_id == "":
		return rm.map_data.filter(func(n): return int(n.floor) == 0)
	var out: Array = []
	for child_id in rm.get_node_by_id(rm.current_node_id).get("children", []):
		var node: Dictionary = rm.get_node_by_id(str(child_id))
		if not node.is_empty():
			out.append(node)
	return out


## Rebuilds the floor track and the cards from the run's route.
func _build_route() -> void:
	var choices := _choices()
	var floors: int = rm.floors_per_act()
	var offered_floor := int(choices[0].floor) if not choices.is_empty() else floors
	for c in _floor_track.get_children():
		_floor_track.remove_child(c)
		c.queue_free()
	for f in range(floors):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(44, 10) if f == offered_floor else Vector2(28, 8)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if f < offered_floor:
			pip.color = T.GLASS_GOLD
		elif f == offered_floor:
			pip.color = T.ACCENT_NEON_BLUE
		elif f == floors - 1:
			pip.color = T.ACCENT_DANGER
		else:
			pip.color = T.GLASS_HAIRLINE_DIM
		_floor_track.add_child(pip)
	for c in _choice_row.get_children():
		_choice_row.remove_child(c)
		c.queue_free()
	var heal: int = ROOMS.rest_heal_amount(rm.max_health)
	for i in range(choices.size()):
		var node: Dictionary = choices[i]
		var next_types: Array = []
		for child_id in node.get("children", []):
			next_types.append(str(rm.get_node_by_id(str(child_id)).get("type", "")))
		var card = ROUTE_CHOICE_CARD.instantiate()
		var slot := Control.new()
		slot.custom_minimum_size = card.custom_minimum_size
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_choice_row.add_child(slot)
		slot.add_child(card)
		card.setup(node, next_types, heal, not peek_mode)
		card.chosen.connect(_choose)
		card.position = Vector2(0, CARD_SLIDE_PX)
		card.modulate.a = 0.0
		var tween: Tween = card.create_tween().set_parallel(true)
		tween.tween_property(card, "position:y", 0.0, 0.2).set_delay(i * CARD_STAGGER).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * CARD_STAGGER)


func _cards() -> Array:
	var out: Array = []
	for slot in _choice_row.get_children():
		for c in slot.get_children():
			if c.has_signal("chosen"):
				out.append(c)
	return out


func _input(event: InputEvent) -> void:
	# `i` toggles the character window (full editable version on the map).
	# Handled before the modal guard so it can also close itself; won't stack on
	# top of another full-screen page.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if _is_character_window_open() or not _is_page_open():
			_open_character_window()
		return

	# ESC → unified pause panel (settings / how-to / abandon / quit), unless a full
	# page (equipment, a modal, etc.) is already open and owns the ESC.
	if (
		event.is_action_pressed("ui_cancel")
		and not _is_page_open()
		and not get_node_or_null("PauseLayer")
	):
		_open_pause()
		get_viewport().set_input_as_handled()
		return

	# 1 / 2 / 3 choose the card at that position (_choose refuses while a
	# modal, a page or another choice is open).
	if event is InputEventKey and event.pressed and not event.echo:
		var index := [KEY_1, KEY_2, KEY_3].find(event.keycode)
		var cards := _cards()
		if index >= 0 and index < cards.size():
			_choose(cards[index].node_id)
			get_viewport().set_input_as_handled()


## True while a page sits over the map: a floating window (character window on
## WindowLayer) or the full-screen run-deck viewer. Choices are refused while
## one is open, so nothing behind it is chosen by mistake (the 误触 bug).
func _is_page_open() -> bool:
	var wl = get_node_or_null("WindowLayer")
	return (wl != null and wl.has_windows()) or get_node_or_null("RunDeckViewerModal") != null


func _is_character_window_open() -> bool:
	var wl = get_node_or_null("WindowLayer")
	return wl != null and wl.get_node_or_null("CharacterWindow") != null


## Choose the route node `node_id`: travel there, play the choose motion, show
## the next floor's cards and open the room. Ignored in a peek, while another
## choice resolves, or under an open page or modal.
func _choose(node_id: String) -> void:
	if peek_mode or _node_click_pending or _is_relic_choice_open or _is_page_open():
		return
	var node: Dictionary = rm.get_node_by_id(node_id)
	if node.is_empty():
		return
	_node_click_pending = true
	if not rm.enter_map_node(node_id)["ok"]:
		_node_click_pending = false
		return
	AudioManager.play_sfx("ui_click")
	var tween := create_tween().set_parallel(true)
	for card in _cards():
		card.interactive = false
		if card.node_id == node_id:
			tween.tween_property(card, "scale", Vector2.ONE * 1.1, CHOOSE_SECONDS)
		else:
			tween.tween_property(card, "modulate:a", 0.0, CHOOSE_SECONDS)
	await tween.finished
	_build_route()
	_enter_room(node)


## Opens the room of the node just entered.
func _enter_room(node: Dictionary) -> void:
	# Each branch is responsible for releasing _node_click_pending when its
	# work is done:
	#   - scene-change branches don't need to release (scene tears down)
	#   - modal-opening branches release in their CLOSE callbacks
	#   - popup-only branches release synchronously below
	match node.type:
		"relic":
			# The hero's start-relic node (core/run/rooms.gd): a fixed starting pair,
			# an upgrade of the held one in later acts, or a random pick.
			var offer: Dictionary = ROOMS.start_relic_offer(str(rm.current_hero_id), int(rm.current_act))
			match str(offer["kind"]):
				"choice":
					var pair: Array[String] = []
					pair.assign(offer["relics"])
					_open_relic_choice(tr("UI_MAP_CHOOSE_STARTING_RELIC"), "starting", pair)
				"upgrade":
					_open_clip_upgrade_choice(offer["relics"], offer["replaces"])
				_:
					var title := "UI_MAP_CHOOSE_STARTING_RELIC" if offer["source"] == "starting" else "UI_MAP_CHOOSE_A_RELIC"
					_open_relic_choice(tr(title), str(offer["source"]))
		"enemy", "elite", "boss":
			rm.current_encounter = rm.encounter_for(node)
			rm.last_battle_node_type = node.type
			SceneTransition.change_to_packed(BATTLE_PACKED)
		"rest":
			_open_rest_choice()
		"merchant":
			SceneTransition.change_to_packed(SHOP_PACKED)
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


## "?" map node — deal the act's next event (saved before the room opens, so a
## reload reopens it). With no event left, roll the `?` table instead; that
## fallback releases the click guard on its own paths.
func _open_event_node(floor_idx: int) -> void:
	var model = rm.enter_event(rm.current_node_id)
	if model == null:
		_resolve_unknown_node(floor_idx)
		return
	_open_event_room(model)


## Show `model` in the event room above the map. The click guard is released
## by the room's `resolved` callback.
func _open_event_room(model) -> void:
	var layer := CanvasLayer.new()
	layer.name = "EventRoomLayer"
	layer.layer = 120
	add_child(layer)

	var room = EVENT_ROOM_SCRIPT.new()
	room.model = model
	room.resolved.connect(
		func():
			_node_click_pending = false  # release click guard so next node is clickable
			layer.queue_free()
			queue_redraw()
	)
	layer.add_child(room)


## "?" map node with no event left: the run layer rolls the outcome
## (core/run/rooms.gd) and applies it; this shows it.
func _resolve_unknown_node(floor_idx: int) -> void:
	var outcome: Dictionary = ROOMS.resolve_unknown()
	var amount := int(outcome["amount"])
	match str(outcome["kind"]):
		"fight":
			rm.current_encounter = rm.select_encounter("enemy", floor_idx)
			rm.last_battle_node_type = "enemy"
			SceneTransition.change_to_packed(BATTLE_PACKED)
			return  # scene change tears down — no click guard to release
		"gold":
			_show_popup(tr("UI_MAP_SCAVENGED_GOLD").format({"n": amount}))
		"scrap":
			_show_popup(tr("UI_MAP_SCRAP_DROP").format({"n": amount}))
		"heal":
			_show_popup(tr("UI_MAP_SCRAP_MEDKIT_HEAL").format({"n": amount}))
		"equipment":
			_grant_treasure_equipment()  # releases the click guard itself
			return
		"cache_empty":
			_show_popup(tr("UI_MAP_CACHE_EMPTY_GOLD").format({"n": amount}))
		"cache":
			# The relic pick releases the click guard when the player chooses.
			_open_relic_choice(tr("UI_MAP_CACHE_PRIED_OPEN").format({"n": amount}), "treasure")
			return
	_node_click_pending = false


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


func _open_relic_choice(
	title: String, source_type: String, forced_choices: Array[String] = []
) -> void:
	if not rm:
		_node_click_pending = false
		return

	# Forced choices (e.g. Bill's fixed clip pair) bypass the random roll.
	var choices: Array[String] = (
		forced_choices if not forced_choices.is_empty() else rm.roll_relic_choices(3)
	)
	if choices.is_empty():
		if source_type == "treasure":
			var gold := ROOMS.treasure_empty_gold()
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

	# Lay the choices out side-by-side (left-right), not stacked.
	var choices_row := HBoxContainer.new()
	choices_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_row.add_theme_constant_override("separation", 28)
	_relic_choice_box.add_child(choices_row)
	for relic_id in choices:
		choices_row.add_child(_make_relic_choice_button(relic_id, source_type))

	_is_relic_choice_open = true
	_relic_choice_layer.visible = true


## Later-act start node: upgrade the held start relic (an upgrade REPLACES the
## relic named in `replaces`) or take another start relic (pure add).
func _open_clip_upgrade_choice(choices: Array, replaces: Dictionary) -> void:
	if not rm:
		_node_click_pending = false
		return
	_upgrade_replaces = replaces.duplicate()

	for child in _relic_choice_box.get_children():
		child.queue_free()

	var title_label = Label.new()
	title_label.text = tr("UI_MAP_CHOOSE_CLIP_UPGRADE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_relic_choice_box.add_child(title_label)

	var hint = Label.new()
	hint.text = tr("UI_MAP_CLIP_UPGRADE_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	_relic_choice_box.add_child(hint)

	var choices_row := HBoxContainer.new()
	choices_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_row.add_theme_constant_override("separation", 28)
	_relic_choice_box.add_child(choices_row)
	for relic_id in choices:
		choices_row.add_child(_make_relic_choice_button(relic_id, "upgrade"))

	_is_relic_choice_open = true
	_relic_choice_layer.visible = true


func _make_relic_choice_button(relic_id: String, source_type: String) -> Button:
	var data = rm.get_relic_data(relic_id)
	var title = Settings.t(
		"RELIC_%s_TITLE" % MODEL_ID.key_entry(relic_id), str(data.get("title", _humanize_id(relic_id)))
	)
	var description = Settings.t("RELIC_%s_DESC" % MODEL_ID.key_entry(relic_id), str(data.get("description", "")))

	var button = Button.new()
	button.custom_minimum_size = Vector2(300, 200)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", T.button_textured("normal"))
	button.add_theme_stylebox_override("hover", T.button_textured("hover"))
	button.add_theme_stylebox_override("pressed", T.button_textured("pressed"))
	# Description shows on hover only — the card itself shows just the name.
	button.tooltip_text = description
	button.pressed.connect(_on_relic_choice_selected.bind(relic_id, source_type))

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	button.add_child(margin)

	# Vertical card: icon on top, name below.
	var col = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var icon_path = str(data.get("icon", ""))
	var icon_texture = _load_texture(icon_path) if not icon_path.is_empty() else null
	var icon_slot := CenterContainer.new()
	icon_slot.custom_minimum_size = Vector2(0, 96)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon_slot)
	if icon_texture:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(88, 88)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon_slot.add_child(icon)
	else:
		var icon = Label.new()
		icon.custom_minimum_size = Vector2(88, 88)
		icon.text = title.substr(0, 1).to_upper()
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 44)
		icon.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		icon_slot.add_child(icon)

	var title_text = Label.new()
	title_text.text = title
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_text.add_theme_font_size_override("font_size", 22)
	title_text.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	col.add_child(title_text)

	return button


func _on_relic_choice_selected(relic_id: String, source_type: String) -> void:
	_is_relic_choice_open = false
	_node_click_pending = false  # release click guard so the next map node is clickable
	_relic_choice_layer.visible = false

	# Clip-upgrade picks may REPLACE the held base clip (swap to an upgraded variant),
	# or be a pure add (grab the other clip as a second exclusive relic).
	if source_type == "upgrade":
		var replaces := str(_upgrade_replaces.get(relic_id, ""))
		_upgrade_replaces = {}
		if replaces != "":
			rm.remove_relic(replaces)

	if rm.add_relic(relic_id):
		var data = rm.get_relic_data(relic_id)
		var relic_title = Settings.t(
			"RELIC_%s_TITLE" % MODEL_ID.key_entry(relic_id), str(data.get("title", _humanize_id(relic_id)))
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
	layer.layer = RUN_TOP_BAR.CANVAS_LAYER
	add_child(layer)

	var bar := RUN_TOP_BAR.new()
	bar.hp_from_player = false
	bar.show_character_button = true
	bar.show_settings_button = true
	bar.deck_pressed.connect(_open_run_deck_viewer)
	bar.character_pressed.connect(_open_character_window)
	bar.settings_pressed.connect(_open_pause)
	layer.add_child(bar)


## Settings overlay (language / fullscreen / volume) — same pattern as the home
## base's _open_settings. Language change reloads the map scene (state lives in
## RunManager, so a reload is lossless).
## Open the unified pause panel (ESC + the top-bar gear). Settings / How-to / Abandon
## (mid-run) / Quit all live inside it.
func _open_pause() -> void:
	PAUSE_PANEL.open(self, RunManager.is_run_active)


func _on_save_and_quit() -> void:
	AudioManager.play_sfx("ui_back")
	if rm and rm.is_run_active:
		rm.save_run()
	SceneTransition.change_to("uid://dnjlmt1repvjw")  # res://ui/menus/main_menu.tscn


## Open the How-to-Play rules panel (loaded at runtime; no-op until it exists).
func _open_rules_panel() -> void:
	var path := "uid://35njcmwpab3t"  # res://ui/menus/rules_panel.gd
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


## Toggle the floating character window (replaces the old fullscreen
## EquipmentPanel). It lives on WindowLayer (CanvasLayer 60) ABOVE the top bar
## (layer 50), so unlike the full-screen pages it needs no top-bar hiding.
func _open_character_window() -> void:
	CHARACTER_WINDOW.open_window(self, "map")


func _open_run_deck_viewer() -> void:
	var existing = get_node_or_null("RunDeckViewerModal")
	if existing:
		existing.queue_free()
		return
	var modal = RUN_DECK_VIEWER_MODAL.new()
	modal.name = "RunDeckViewerModal"
	add_child(modal)


## Treasure equipment drop: 70% uncommon / 30% rare. Drops straight into the
## backpack; if every cell is taken the item is left behind with a notice.
func _grant_treasure_equipment() -> void:
	var einst: Dictionary = ROOMS.treasure_equipment()
	var item_id = str(einst.get("base", ""))
	if item_id == "":
		_show_popup(tr("UI_MAP_CRATE_EMPTY"))
		_node_click_pending = false
		return
	var data = RunManager.get_equipment_data(item_id)
	var item_name = Settings.t("EQUIP_%s_NAME" % MODEL_ID.key_entry(item_id), str(data.get("name", item_id)))
	if RunManager.add_equip_to_backpack(einst):
		_show_popup(tr("UI_MAP_FOUND_EQUIPMENT").format({"n": item_name}))
	else:
		# Backpack full — gold/scrap/equipment all share the 20 cells now, so
		# there is no dedicated equip overflow. Leave the item behind.
		_show_popup(tr("UI_MAP_BACKPACK_FULL").format({"n": item_name}))
	_node_click_pending = false


func _open_rest_choice() -> void:
	var existing = get_node_or_null("RestChoiceModal")
	if existing:
		return

	var modal := Control.new()
	modal.name = "RestChoiceModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)

	var bg := TextureRect.new()
	bg.name = "RestSiteArt"
	if ResourceLoader.exists(REST_SITE_BACKGROUND_PATH):
		bg.texture = load(REST_SITE_BACKGROUND_PATH)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(bg)

	var title := Label.new()
	title.text = tr("UI_MAP_REST_STOP")
	title.offset_left = 48.0
	title.offset_top = RUN_TOP_BAR.BAR_HEIGHT + 24.0
	title.offset_right = 320.0
	title.offset_bottom = RUN_TOP_BAR.BAR_HEIGHT + 74.0
	title.add_theme_font_override("font", T_THEME.display_font(700))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.77, 0.48))
	modal.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(0.92, 0.54, 0.15, 0.95)
	rule.offset_left = 48.0
	rule.offset_top = RUN_TOP_BAR.BAR_HEIGHT + 80.0
	rule.offset_right = 300.0
	rule.offset_bottom = RUN_TOP_BAR.BAR_HEIGHT + 82.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(rule)

	var heal_amount := mini(
		ROOMS.rest_heal_amount(rm.max_health), rm.max_health - rm.current_health
	)
	var heal_btn := _rest_option(
		Vector2(0.20, 0.70),
		"icon_heart",
		tr("UI_MAP_LEGEND_REST"),
		tr("UI_ROUTE_HEAL").format({"n": heal_amount})
	)
	heal_btn.name = "HealChoice"
	heal_btn.pressed.connect(
		func():
			rm.modify_health(heal_amount)
			_show_popup(tr("UI_MAP_RESTED_HEAL").format({"n": heal_amount}))
			modal.queue_free()
			_node_click_pending = false
	)
	modal.add_child(heal_btn)

	var upgrade_btn := _rest_option(
		Vector2(0.66, 0.73),
		"icon_hammer",
		tr("UI_MAP_REST_UPGRADE_BTN"),
		tr("UI_UPGRADE_MODAL_HINT")
	)
	upgrade_btn.name = "UpgradeChoice"
	upgrade_btn.pressed.connect(
		func():
			modal.queue_free()
			var picker := CARD_UPGRADE_MODAL.new()
			add_child(picker)
			picker.upgraded.connect(
				func():
					_show_popup(tr("UI_MAP_CARD_UPGRADED"))
					_node_click_pending = false,
				CONNECT_ONE_SHOT
			)
			picker.cancelled.connect(_open_rest_choice, CONNECT_ONE_SHOT)
	)
	modal.add_child(upgrade_btn)

	var leave_btn := Button.new()
	leave_btn.text = tr("UI_SHOP_LEAVE")
	leave_btn.anchor_left = 1.0
	leave_btn.anchor_right = 1.0
	leave_btn.anchor_top = 1.0
	leave_btn.anchor_bottom = 1.0
	leave_btn.offset_left = -286.0
	leave_btn.offset_top = -108.0
	leave_btn.offset_right = -48.0
	leave_btn.offset_bottom = -42.0
	leave_btn.focus_mode = Control.FOCUS_NONE
	leave_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	leave_btn.add_theme_font_override("font", T_THEME.display_font(700))
	leave_btn.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed"]:
		leave_btn.add_theme_stylebox_override(
			state, T_THEME.ll_button("hover" if state == "hover" else "normal")
		)
	leave_btn.pressed.connect(
		func():
			modal.queue_free()
			_node_click_pending = false
	)
	modal.add_child(leave_btn)


func _rest_option(
	anchor: Vector2, icon_name: String, title_text: String, detail_text: String
) -> Button:
	var button := Button.new()
	button.anchor_left = anchor.x
	button.anchor_top = anchor.y
	button.anchor_right = anchor.x
	button.anchor_bottom = anchor.y
	button.offset_left = -176.0
	button.offset_right = 176.0
	button.offset_top = -58.0
	button.offset_bottom = 58.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	T_THEME.apply_choice_button(button)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16.0
	row.offset_right = -16.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon := TextureRect.new()
	icon.name = "ChoiceIcon"
	icon.texture = T_THEME.lightline_tex(icon_name)
	icon.custom_minimum_size = Vector2(66, 66)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var title := Label.new()
	title.text = title_text
	T_THEME.style_display(title, 28, 700)
	title.add_theme_color_override("font_color", T_THEME.TEXT_MAIN)
	copy.add_child(title)

	var detail := Label.new()
	detail.name = "ChoiceDetail"
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	T_THEME.style_display(detail, 20)
	detail.add_theme_color_override("font_color", T_THEME.UI_BRASS_LIGHT)
	copy.add_child(detail)
	return button
