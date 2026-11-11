extends Node

## BattleUIManager handles notifications, inspection, and pile viewing.

const CHARACTER_WINDOW = preload("uid://ba0f3y5ua1p6o")  # res://ui/windows/character_window.gd
const RUN_DECK_VIEWER_MODAL = preload("uid://jvxfh15gtinx")  # res://ui/common/run_deck_viewer_modal.gd
const ENERGY_ORB = preload("uid://bw7ft80f37jg5")  # res://ui/battle/energy_orb.gd

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
var _energy_value := -1
var _energy_maximum := 0
var _hud_exiting := false
var _end_turn_home := Vector2.ZERO
var _end_turn_size := Vector2.ZERO
var _end_turn_home_set := false
var _end_turn_motion: Tween
var _end_turn_transition := false
var _pile_viewer: Control
## Tracks which pile the viewer is currently showing ("draw"/"discard"/"deck"/"")
## so the Q/E toggle logic doesn't compare against the (now localized) title text.
var _current_pile_kind: String = ""


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
	anim_in.call_deferred()

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
	if _energy_display:
		_energy_display.anim_in()
	for hud in _pile_huds():
		hud.anim_in()
	_animate_end_turn(true)


func anim_out() -> void:
	_hud_exiting = true
	if _energy_display:
		_energy_display.anim_out()
	for hud in _pile_huds():
		hud.anim_out()
	_animate_end_turn(false)


func _pile_huds() -> Array:
	var result: Array = []
	for path in ["CardManager/Deck/PileInput/PileHUD", "CardManager/DiscardPile/PileInput/PileHUD", "ExhaustIndicator/PileHUD"]:
		var hud := main.get_node_or_null(path)
		if hud:
			result.append(hud)
	return result


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
	_sync_end_turn_state()
	_energy_value = energy
	_energy_maximum = max_energy
	if _energy_display:
		_energy_display.set_energy(energy, max_energy)
	elif energy_label:
		energy_label.text = "%d/%d" % [energy, max_energy]


func _build_energy_display() -> void:
	if not energy_label or _energy_display:
		return
	_energy_display = ENERGY_ORB.new()
	_energy_display.name = "EnergyDisplay"
	_energy_display.anchor_top = 1.0
	_energy_display.anchor_bottom = 1.0
	# The reference uses a zero-size bottom anchor with a 128 px child below it.
	_energy_display.offset_left = 100.0
	_energy_display.offset_top = -252.0
	_energy_display.offset_right = 228.0
	_energy_display.offset_bottom = -124.0
	_energy_display.z_index = 20
	main.add_child(_energy_display)
	_energy_display.configure(energy_label)
	if _energy_value >= 0:
		_energy_display.set_energy(_energy_value, _energy_maximum)


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


## Mouse pile hotspots use the same viewer and snapshot path as keyboard shortcuts.
func open_pile(kind: String) -> void:
	if main.is_game_over:
		return
	if pile_viewer_layer.visible and _current_pile_kind == kind:
		hide_pile_viewer()
		return
	_current_pile_kind = kind
	if kind == "draw":
		show_pile_viewer(tr("UI_BATTLE_DRAW_PILE"), main.deck)
	elif kind == "discard":
		show_pile_viewer(tr("UI_BATTLE_DISCARD_PILE"), main.discard_pile)


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
