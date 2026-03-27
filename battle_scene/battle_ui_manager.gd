extends Node

## BattleUIManager handles notifications, inspection, and pile viewing.

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
		
	var close_btn = main.get_node_or_null("PileViewerLayer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(hide_pile_viewer)
		
	if notify_label:
		notify_label.modulate.a = 0

func update_labels(energy: int, max_energy: int) -> void:
	if energy_label:
		energy_label.text = "Energy: %d / %d" % [energy, max_energy]

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notify_label: return
	
	notify_label.text = text
	notify_label.add_theme_color_override("font_color", color)
	notify_label.modulate.a = 1.0
	
	if notify_tween and notify_tween.is_valid():
		notify_tween.kill()
	
	notify_tween = create_tween()
	notify_tween.tween_interval(1.5)
	notify_tween.tween_property(notify_label, "modulate:a", 0.0, 0.5)

# --- Inspection UI ---

func inspect_card(card: Control) -> void:
	if main.is_game_over: return
	if inspect_layer and inspect_pivot:
		inspect_layer.visible = true
		
		# Clear existing if any
		if inspected_card:
			inspected_card.queue_free()
		
		inspected_card = main.card_factory.create_card(card.card_info.get("name", "error"), null)
		if inspected_card:
			inspected_card.reparent(inspect_pivot)
			
			if "attack" in inspected_card and "health" in inspected_card:
				var base_buffed_atk = card.get("base_attack") if "base_attack" in card else 0
				var base_buffed_hp = card.get("base_health") if "base_health" in card else 0
				
				if base_buffed_atk == null: base_buffed_atk = 0
				if base_buffed_hp == null: base_buffed_hp = 0
				
				inspected_card.base_attack = base_buffed_atk
				inspected_card.base_health = base_buffed_hp
				inspected_card.attack = base_buffed_atk
				inspected_card.health = base_buffed_hp
				if inspected_card.has_method("_update_card_ui"):
					inspected_card._update_card_ui()
			
			inspected_card.set_view_mode("card")
			if inspected_card.has_method("set_inspect_scale"):
				inspected_card.set_inspect_scale(2.5)
			else:
				inspected_card.scale = Vector2(2.5, 2.5)
				
			inspected_card.global_position = Vector2(760, 265)
			inspected_card.can_be_interacted_with = false
			inspected_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inspected_card.refresh_ui()

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
	if not pile_viewer_layer: return
	
	pile_viewer_title.text = title
	
	# Clear existing cards
	for child in pile_viewer_grid.get_children():
		child.queue_free()
		
	# Populate with cards from the pile
	for card_data in pile_container.get_cards():
		var card_instance = main.card_factory.create_card(card_data.card_info.get("name", "error"), null)
		if card_instance:
			if card_instance.get_parent():
				card_instance.get_parent().remove_child(card_instance)
				
			card_instance.card_info = card_data.card_info.duplicate()
			card_instance.set_view_mode("card")
			card_instance.scale = Vector2(0.8, 0.8)
			card_instance.can_be_interacted_with = false
			card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_instance.refresh_ui()
			pile_viewer_grid.add_child(card_instance)
			
	pile_viewer_layer.visible = true

func hide_pile_viewer() -> void:
	if not pile_viewer_layer: return
	pile_viewer_layer.visible = false
	for child in pile_viewer_grid.get_children():
		child.queue_free()

func _input(event: InputEvent) -> void:
	if main.is_game_over: return
	
	if event.is_action_pressed("ui_cancel"):
		if inspect_layer and inspect_layer.visible:
			close_inspection()
		elif pile_viewer_layer and pile_viewer_layer.visible:
			hide_pile_viewer()
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			if pile_viewer_layer and pile_viewer_layer.visible and pile_viewer_title.text == "Draw Pile":
				hide_pile_viewer()
			else:
				show_pile_viewer("Draw Pile", main.deck)
				
		elif event.keycode == KEY_E:
			if pile_viewer_layer and pile_viewer_layer.visible and pile_viewer_title.text == "Discard Pile":
				hide_pile_viewer()
			else:
				show_pile_viewer("Discard Pile", main.discard_pile)
