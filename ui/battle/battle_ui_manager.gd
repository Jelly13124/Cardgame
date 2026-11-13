extends Node

## BattleUIManager handles notifications, inspection, and pile viewing.

const CHARACTER_WINDOW = preload("uid://ba0f3y5ua1p6o")  # res://ui/windows/character_window.gd
const RUN_DECK_VIEWER_MODAL = preload("uid://jvxfh15gtinx")  # res://ui/common/run_deck_viewer_modal.gd
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd

@export_group("UI Nodes")
@export var energy_label: Label
@export var notify_label: Label
@export var pile_viewer_layer: CanvasLayer
@export var inspect_layer: CanvasLayer
@export var inspect_pivot: Control

@onready var main = get_parent()

var notify_tween: Tween
var inspected_card: Control = null
var _energy_display: Control
var _energy_frame: TextureRect
var _energy_tween: Tween
var _energy_value := -1
var _energy_fraction := 0.0
var _pile_viewer: Control
## Tracks which pile the viewer is currently showing ("draw"/"discard"/"deck"/"")
## so the Q/E toggle logic doesn't compare against the (now localized) title text.
var _current_pile_kind: String = ""
var _hud_exiting := false
var _end_turn_home := Vector2.ZERO
var _end_turn_size := Vector2.ZERO
var _end_turn_home_set := false
var _end_turn_motion: Tween
var _end_turn_transition := false


func _ready() -> void:
	if not pile_viewer_layer:
		pile_viewer_layer = main.get_node("PileViewerLayer")
	if not inspect_layer:
		inspect_layer = main.get_node("InspectLayer")
	if not inspect_pivot:
		inspect_pivot = main.get_node("InspectLayer/InspectOverlay/InspectPivot")
	if not notify_label:
		notify_label = main.get_node("NotificationLabel")
	if not energy_label:
		energy_label = main.get_node("EnergyLabel")
	_build_energy_display.call_deferred()

	if notify_label:
		notify_label.modulate.a = 0


func _process(_delta: float) -> void:
	_sync_end_turn_state()


func _sync_end_turn_state() -> void:
	if main.end_round_button:
		var disabled: bool = (
			_hud_exiting or _end_turn_transition or main.is_targeting
			or not main._accepts_player_input()
		)
		if main.end_round_button.disabled != disabled:
			main.end_round_button.disabled = disabled
			var visuals: Node = main.end_round_button.get_node_or_null("ActionVisuals")
			if visuals:
				visuals.sync_state()


func anim_in() -> void:
	if main.is_game_over:
		anim_out()
		return
	_hud_exiting = false
	_animate_end_turn(true)


func anim_out() -> void:
	_hud_exiting = true
	_animate_end_turn(false)


func _animate_end_turn(entering: bool) -> void:
	var button: Button = main.end_round_button
	if button == null:
		return
	if not _end_turn_home_set:
		_end_turn_home = button.position
		_end_turn_size = button.size
		_end_turn_home_set = true
	if _end_turn_motion and _end_turn_motion.is_valid():
		_end_turn_motion.kill()
	_end_turn_transition = true
	if entering:
		button.position = _end_turn_home + Vector2(0, 250)
	_sync_end_turn_state()
	var destination := _end_turn_home if entering else _end_turn_home + Vector2(0, 250)
	var transition := Tween.TRANS_BACK if entering else Tween.TRANS_EXPO
	_end_turn_motion = create_tween()
	_end_turn_motion.tween_property(button, "position", destination, 0.5).set_trans(transition).set_ease(Tween.EASE_OUT)
	_end_turn_motion.finished.connect(
		func() -> void:
			# Control position tweens can accumulate subpixel size drift at anchors.
			button.position = destination
			button.size = _end_turn_size
			_end_turn_transition = false
			_sync_end_turn_state()
	)




func update_labels(energy: int, max_energy: int) -> void:
	if energy_label == null:
		return
	var count := "%d/%d" % [energy, max_energy]
	if count == energy_label.text and _energy_value >= 0:
		return
	var energy_changed := _energy_value >= 0 and energy != _energy_value
	_energy_value = energy
	_energy_fraction = clampf(float(energy) / maxi(1, max_energy), 0.0, 1.0)
	energy_label.text = count
	_refresh_energy_layers()
	if energy_changed:
		_pop_energy()


## Quick scale-pop on the energy orb whenever energy changes — spend/gain now reads
## kinetically instead of a silent text swap.
func _pop_energy() -> void:
	if _energy_display == null or not is_instance_valid(_energy_display):
		return
	_energy_display.pivot_offset = Vector2(52, 52)
	_energy_display.scale = Vector2(1.16, 1.16)
	if _energy_tween and _energy_tween.is_valid():
		_energy_tween.kill()
	_energy_tween = create_tween()
	(
		_energy_tween
		. tween_property(_energy_display, "scale", Vector2.ONE, 0.18)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _build_energy_display() -> void:
	if not energy_label or _energy_display:
		return

	_energy_display = Control.new()
	_energy_display.name = "EnergyDisplay"
	_energy_display.anchor_left = 0.0
	_energy_display.anchor_top = 1.0
	_energy_display.anchor_right = 0.0
	_energy_display.anchor_bottom = 1.0
	# One compact hand-inked token where STS2 centres its energy counter
	# (combat_ui.tscn: 100 px from the left, 252 px above the bottom).
	_energy_display.offset_left = 48.0
	_energy_display.offset_top = -304.0
	_energy_display.offset_right = 152.0
	_energy_display.offset_bottom = -200.0
	_energy_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_display.z_index = 20
	main.add_child(_energy_display)

	# The faceted medallion is stationary. The count remains an independent text layer.
	var medal_rect := Rect2(0.0, 0.0, 104.0, 104.0)
	var medal_tex := T.lightline_tex("hud_energy_badge_sts2")
	if medal_tex != null:
		var medal := TextureRect.new()
		medal.name = "Frame"
		medal.texture = medal_tex
		medal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.position = medal_rect.position
		medal.size = medal_rect.size
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_energy_display.add_child(medal)
		_energy_frame = medal
	var old_parent = energy_label.get_parent()
	if old_parent:
		old_parent.remove_child(energy_label)
	_energy_display.add_child(energy_label)
	energy_label.anchor_left = 0.0
	energy_label.anchor_top = 0.0
	energy_label.anchor_right = 0.0
	energy_label.anchor_bottom = 0.0
	energy_label.offset_left = medal_rect.position.x
	energy_label.offset_top = medal_rect.position.y
	energy_label.offset_right = medal_rect.end.x
	energy_label.offset_bottom = medal_rect.end.y
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_override("font", T.display_font(700))
	energy_label.add_theme_font_size_override("font_size", 32)
	energy_label.add_theme_color_override("font_color", Color(0.035, 0.07, 0.08, 1.0))
	energy_label.add_theme_color_override("font_outline_color", Color(0.80, 0.92, 0.94, 0.30))
	energy_label.add_theme_constant_override("outline_size", 1)
	energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_energy_layers()


func _refresh_energy_layers() -> void:
	if _energy_frame != null:
		_energy_frame.self_modulate = T.ENERGY_EMPTY_TINT if _energy_value == 0 else Color.WHITE


func show_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notify_label:
		return

	notify_label.text = text
	notify_label.add_theme_color_override("font_color", color)
	notify_label.modulate.a = 1.0

	if notify_tween and notify_tween.is_valid():
		notify_tween.kill()

	notify_tween = create_tween()
	notify_tween.tween_interval(1.5)
	notify_tween.tween_property(notify_label, "modulate:a", 0.0, 0.5)


# --- Inspection UI ---


func _on_inspect_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_inspection()


func close_inspection() -> void:
	if inspected_card:
		inspected_card.queue_free()
		inspected_card = null
	if inspect_layer:
		inspect_layer.visible = false


# --- Pile Viewer UI ---


func show_pile_viewer(title: String, pile_container: CardContainer) -> void:
	var entries: Array = []
	for card in pile_container.get_cards():
		var card_id := str(card.card_info.get("id", ""))
		if card_id != "":
			entries.append({"card_id": card_id, "card_info": card.card_info.duplicate(true)})
	_show_deck_page(title, entries, _current_pile_kind)


func show_pile_viewer_from_names(title: String, names, kind: String) -> void:
	_show_deck_page(title, Array(names), kind)


func show_run_deck_viewer(title: String = "", deck_entries: Array = []) -> void:
	if pile_viewer_layer.visible and _current_pile_kind == "deck":
		hide_pile_viewer()
		return
	if deck_entries.is_empty():
		if RunManager.is_run_active:
			deck_entries = RunManager.player_deck.duplicate()
		else:
			for pile in [main.hand, main.deck, main.discard_pile]:
				for card in pile.get_cards():
					if is_instance_valid(card):
						deck_entries.append(str(card.card_info.get("id", "")))
	_show_deck_page(title, deck_entries, "deck")


func _show_deck_page(title: String, entries: Array, kind: String) -> void:
	hide_pile_viewer()
	var page := RUN_DECK_VIEWER_MODAL.new()
	page.configure(title, entries)
	page.dismiss_on_cancel = false
	page.closed.connect(hide_pile_viewer)
	_pile_viewer = page
	_current_pile_kind = kind
	pile_viewer_layer.add_child(page)
	pile_viewer_layer.show()


func hide_pile_viewer() -> void:
	if is_instance_valid(_pile_viewer):
		_pile_viewer.hide()
		_pile_viewer.queue_free()
	_pile_viewer = null
	_current_pile_kind = ""
	pile_viewer_layer.hide()


func _input(event: InputEvent) -> void:
	if main.is_game_over:
		return

	if event.is_action_pressed("ui_cancel"):
		# Floating windows (read-only character window) close FIRST. This must
		# happen here — battle_scene's root _input opens the pause panel and
		# consumes ESC before WindowLayer's _unhandled_input would ever run, and
		# this child _input runs before the parent's (reverse tree order).
		var wl = main.get_node_or_null("WindowLayer")
		if wl != null and wl.has_windows():
			var top = wl.get_child(wl.get_child_count() - 1)
			if top is Control and top.has_method("close"):
				top.close()
			get_viewport().set_input_as_handled()
		elif inspect_layer and inspect_layer.visible:
			close_inspection()
		elif pile_viewer_layer and pile_viewer_layer.visible:
			hide_pile_viewer()
			get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == Settings.get_key("view_draw"):
			if pile_viewer_layer and pile_viewer_layer.visible and _current_pile_kind == "draw":
				hide_pile_viewer()
			else:
				_current_pile_kind = "draw"
				show_pile_viewer(tr("UI_BATTLE_DRAW_PILE"), main.deck)

		elif event.keycode == Settings.get_key("view_discard"):
			if pile_viewer_layer and pile_viewer_layer.visible and _current_pile_kind == "discard":
				hide_pile_viewer()
			else:
				_current_pile_kind = "discard"
				show_pile_viewer(tr("UI_BATTLE_DISCARD_PILE"), main.discard_pile)

		elif event.keycode == Settings.get_key("view_exhaust"):
			if pile_viewer_layer and pile_viewer_layer.visible and _current_pile_kind == "exhaust":
				hide_pile_viewer()
			else:
				main.view_exhaust_pile()

		elif event.keycode == Settings.get_key("end_turn"):
			# Spacebar ends the turn — same guarded path as the End Round button.
			# Suppressed while a pile/inspect overlay is open or an attack is being
			# targeted, so it never fires mid-interaction.
			var overlay_open := (
				(pile_viewer_layer and pile_viewer_layer.visible)
				or (inspect_layer and inspect_layer.visible)
			)
			if not overlay_open and not main.is_targeting:
				main._on_end_round_button_pressed()

		elif event.keycode == Settings.get_key("view_attributes"):
			# `i` toggles the read-only character window (no backpack ops in battle).
			CHARACTER_WINDOW.open_window(main, "battle")
