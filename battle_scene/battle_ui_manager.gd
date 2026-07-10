extends Node

## BattleUIManager handles notifications, inspection, and pile viewing.

const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")
const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

@export_group("UI Nodes")
@export var energy_label: Label
@export var notify_label: Label
@export var pile_viewer_layer: CanvasLayer
@export var pile_viewer_title: Label
@export var pile_viewer_grid: Container
@export var inspect_layer: CanvasLayer
@export var inspect_pivot: Control

@onready var main = get_parent()

var notify_tween: Tween
var inspected_card: Control = null
var _energy_display: Control = null
## Tracks which pile the viewer is currently showing ("draw"/"discard"/"deck"/"")
## so the Q/E toggle logic doesn't compare against the (now localized) title text.
var _current_pile_kind: String = ""


func _ready() -> void:
	if not pile_viewer_layer:
		pile_viewer_layer = main.get_node("PileViewerLayer")
	if not pile_viewer_title:
		pile_viewer_title = main.get_node("PileViewerLayer/TitleLabel")
	if not pile_viewer_grid:
		pile_viewer_grid = main.get_node("PileViewerLayer/ScrollContainer/GridContainer")
	if not inspect_layer:
		inspect_layer = main.get_node("InspectLayer")
	if not inspect_pivot:
		inspect_pivot = main.get_node("InspectLayer/InspectOverlay/InspectPivot")
	if not notify_label:
		notify_label = main.get_node("NotificationLabel")
	if not energy_label:
		energy_label = main.get_node("EnergyLabel")
	_build_energy_display.call_deferred()

	var close_btn = main.get_node_or_null("PileViewerLayer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(hide_pile_viewer)

	if notify_label:
		notify_label.modulate.a = 0


func update_labels(energy: int, max_energy: int) -> void:
	if energy_label:
		# Compact "3/3" (no spaces) so the number sits inside the round medal's
		# inner ring instead of poking past its edges.
		energy_label.text = "%d/%d" % [energy, max_energy]
	_pop_energy()


## Quick scale-pop on the energy orb whenever energy changes — spend/gain now reads
## kinetically instead of a silent text swap.
func _pop_energy() -> void:
	if _energy_display == null or not is_instance_valid(_energy_display):
		return
	_energy_display.pivot_offset = Vector2(52, 52)
	_energy_display.scale = Vector2(1.16, 1.16)
	var tw := create_tween()
	(
		tw
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
	# One compact hand-inked token, bottom-aligned with End Round across the hand.
	_energy_display.offset_left = 32.0
	_energy_display.offset_top = -396.0
	_energy_display.offset_right = 136.0
	_energy_display.offset_bottom = -292.0
	_energy_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_display.z_index = 20
	main.add_child(_energy_display)

	# The single faceted badge is the entire energy visual. The localized numeric
	# value stays deterministic and is reparented over its empty centre.
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
	if not pile_viewer_layer:
		return

	pile_viewer_title.text = title

	# Clear existing cards
	_clear_pile_viewer_grid()

	# Populate with cards from the pile
	for card_data in pile_container.get_cards():
		var card_name = card_data.card_info.get("name", "")
		if card_name.is_empty():
			continue
		_add_card_to_viewer(card_name)

	pile_viewer_layer.visible = true


## Like show_pile_viewer but populated from card-name strings — used by the hidden
## Exhaust pile, whose cards no longer exist as nodes once exhausted.
func show_pile_viewer_from_names(title: String, names, kind: String) -> void:
	if not pile_viewer_layer:
		return
	_current_pile_kind = kind
	pile_viewer_title.text = title
	_clear_pile_viewer_grid()
	for nm in names:
		if str(nm) != "":
			_add_card_to_viewer(str(nm))
	pile_viewer_layer.visible = true


func show_run_deck_viewer(title: String = "", deck_entries: Array = []) -> void:
	if not pile_viewer_layer:
		return
	if title.is_empty():
		title = tr("UI_BATTLE_RUN_DECK")
	_current_pile_kind = "deck"

	# If no entries were passed, build them: prefer RunManager.player_deck if a run
	# is active, otherwise fall back to the live battle's hand+deck+discard.
	if deck_entries.is_empty():
		if RunManager.is_run_active:
			deck_entries = RunManager.player_deck.duplicate()
		else:
			for pile in [main.hand, main.deck, main.discard_pile]:
				if pile and pile.has_method("get_cards"):
					for card in pile.get_cards():
						if is_instance_valid(card):
							deck_entries.append(card.card_info.get("name", ""))

	pile_viewer_title.text = title
	_clear_pile_viewer_grid()

	for entry in deck_entries:
		var card_name = _card_id_from_deck_entry(entry)
		if card_name.is_empty():
			continue
		_add_card_to_viewer(card_name)

	pile_viewer_layer.visible = true


func hide_pile_viewer() -> void:
	if not pile_viewer_layer:
		return
	pile_viewer_layer.visible = false
	_current_pile_kind = ""
	_clear_pile_viewer_grid()


func _clear_pile_viewer_grid() -> void:
	if not pile_viewer_grid:
		return
	for child in pile_viewer_grid.get_children():
		child.queue_free()


func _add_card_to_viewer(card_name: String) -> void:
	if card_name.is_empty():
		return
	var card_instance = main.card_factory.create_card(card_name, null)
	if card_instance:
		if card_instance.get_parent():
			card_instance.get_parent().remove_child(card_instance)
		card_instance.show_front = true
		card_instance.can_be_interacted_with = false
		card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_instance.scale = Vector2(0.7, 0.7)
		pile_viewer_grid.add_child(card_instance)


func _card_id_from_deck_entry(entry) -> String:
	if typeof(entry) == TYPE_STRING:
		return entry
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("card_id", entry.get("name", "")))
	if entry is Control and "card_info" in entry:
		return str(entry.card_info.get("name", ""))
	return ""


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
