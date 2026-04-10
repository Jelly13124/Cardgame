extends Control

# Card IDs available for drafting — must match filenames in card_info/player/
var draft_pool = [
	"strike", "defend", "override", "preemptive_strike"
]

@onready var loot_list_container = $VBoxContainer/LootPanel/MarginContainer/LootList
@onready var proceed_button = $VBoxContainer/BottomRow/MarginContainer/ProceedButton
@onready var draft_overlay = $DraftOverlay
@onready var draft_card_container = $DraftOverlay/VBoxContainer/DraftPanel/MarginContainer/CardsContainer
@onready var draft_skip_button = $DraftOverlay/VBoxContainer/BottomRow/MarginContainer/SkipDraftButton

var _card_factory: Node = null

# State tracking
var available_loot = []
var _rarity_pools = {
	"common": [],
	"uncommon": [],
	"rare": []
}

func _ready() -> void:
	proceed_button.pressed.connect(_on_proceed_pressed)
	draft_skip_button.pressed.connect(_on_skip_draft_pressed)
	
	draft_overlay.visible = false
	
	_card_factory = preload("res://battle_scene/my_card_factory.tscn").instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(160, 220)  # Needed: no CardManager to set this
	
	_categorize_cards()
	_generate_loot()
	_populate_loot_ui()
	
func _generate_loot() -> void:
	available_loot.clear()
	
	# Randomize Gold
	var gold_amount = 10
	
	available_loot.append({
		"id": "gold",
		"type": "gold",
		"amount": gold_amount,
		"title": "%d Gold" % gold_amount
	})
	
	available_loot.append({
		"id": "cards",
		"type": "cards",
		"title": "Card Reward"
	})

func _populate_loot_ui() -> void:
	for child in loot_list_container.get_children():
		child.queue_free()
		
	for loot in available_loot:
		var btn = Button.new()
		# Styling the button to match reference (dark teal background, large)
		btn.custom_minimum_size = Vector2(500, 80)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.4, 0.45) # Teal
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.5, 0.55)
		
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.3, 0.5, 0.55)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		
		var hbox = HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 20)
		
		# Margin for inner spacing
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon = Panel.new()
		var icon_style = StyleBoxFlat.new()
		if loot["type"] == "gold":
			icon.custom_minimum_size = Vector2(46, 46)
			icon_style.bg_color = Color(1.0, 0.84, 0.0) # Gold coin color
			icon_style.corner_radius_top_left = 23
			icon_style.corner_radius_top_right = 23
			icon_style.corner_radius_bottom_left = 23
			icon_style.corner_radius_bottom_right = 23
			icon_style.border_width_left = 2
			icon_style.border_width_right = 2
			icon_style.border_width_top = 2
			icon_style.border_width_bottom = 2
			icon_style.border_color = Color(0.8, 0.6, 0.0)
		elif loot["type"] == "cards":
			icon.custom_minimum_size = Vector2(36, 50)
			icon_style.bg_color = Color(0.9, 0.9, 0.9) # Card color
			icon_style.border_width_left = 2
			icon_style.border_width_right = 2
			icon_style.border_width_top = 2
			icon_style.border_width_bottom = 2
			icon_style.border_color = Color(0.2, 0.4, 0.8)
			icon_style.corner_radius_top_left = 4
			icon_style.corner_radius_top_right = 4
			icon_style.corner_radius_bottom_left = 4
			icon_style.corner_radius_bottom_right = 4
			
		icon.add_theme_stylebox_override("panel", icon_style)
		
		var icon_container = CenterContainer.new()
		icon_container.custom_minimum_size = Vector2(60, 60)
		icon_container.add_child(icon)
		
		var label = Label.new()
		label.text = loot["title"]
		label.add_theme_font_size_override("font_size", 28)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		hbox.add_child(icon_container)
		hbox.add_child(label)
		margin.add_child(hbox)
		btn.add_child(margin)
		
		btn.pressed.connect(func(): _on_loot_selected(loot["id"], btn))
		loot_list_container.add_child(btn)

func _on_loot_selected(loot_id: String, btn: Button) -> void:
	var loot = null
	for l in available_loot:
		if l["id"] == loot_id:
			loot = l
			break
			
	if not loot: return
	
	if loot["type"] == "gold":
		var run_manager = get_node_or_null("/root/RunManager")
		if run_manager:
			run_manager.add_resources(loot["amount"], 0)
			print("Claimed %d Gold" % loot["amount"])
		btn.queue_free()
		
	elif loot["type"] == "cards":
		_open_card_draft()
		btn.queue_free() # We consume the chance.

func _on_proceed_pressed() -> void:
	get_tree().change_scene_to_file("res://run_system/ui/map_scene.tscn")

# --- Card Draft Overlay ---
func _open_card_draft() -> void:
	$VBoxContainer.visible = false
	draft_overlay.visible = true
	_generate_draft_options()

func _categorize_cards() -> void:
	for pool in _rarity_pools.values():
		pool.clear()
		
	for card_id in draft_pool:
		var info = _card_factory._load_card_info(card_id)
		if info:
			var rarity = info.get("rarity", "common").to_lower()
			if rarity in _rarity_pools:
				_rarity_pools[rarity].append(card_id)
			else:
				_rarity_pools["common"].append(card_id)

func _generate_draft_options() -> void:
	for child in draft_card_container.get_children():
		child.queue_free()
		
	var draft_options = []
	
	# Roll for each of the 3 slots
	for i in range(3):
		var roll = randf()
		var picked_rarity = "common"
		
		if roll < 0.05: # 5% Rare
			picked_rarity = "rare"
		elif roll < 0.30: # 25% Uncommon
			picked_rarity = "uncommon"
		else:
			picked_rarity = "common"
			
		# Fallback logic if a pool is empty
		if _rarity_pools[picked_rarity].is_empty():
			if picked_rarity == "rare": picked_rarity = "uncommon"
			if _rarity_pools[picked_rarity].is_empty(): picked_rarity = "common"
		
		var pool = _rarity_pools[picked_rarity]
		if not pool.is_empty():
			# Pick a random card from the target rarity
			var picked_id = pool[randi() % pool.size()]
			# Ideally we avoid duplicates in the same screen
			if not picked_id in draft_options:
				draft_options.append(picked_id)
			else:
				# Simple retry once if duplicate
				picked_id = pool[randi() % pool.size()]
				draft_options.append(picked_id)

	for card_id in draft_options:
		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(240, 330)
		
		var card = _card_factory.create_card(card_id, null)
		if card:
			if card.get_parent():
				card.get_parent().remove_child(card)
			card.can_be_interacted_with = false
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.position = Vector2(40, 55)
			card.scale = Vector2(1.5, 1.5)
			card.pivot_offset = Vector2(80, 110)
			wrapper.add_child(card)
			
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(240, 330)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): _on_draft_card_selected(card_id))
		
		if card:
			btn.mouse_entered.connect(func():
				var t = create_tween()
				t.tween_property(card, "scale", Vector2(1.65, 1.65), 0.1)
			)
			btn.mouse_exited.connect(func():
				var t = create_tween()
				t.tween_property(card, "scale", Vector2(1.5, 1.5), 0.1)
			)
			
		wrapper.add_child(btn)
		draft_card_container.add_child(wrapper)

func _on_draft_card_selected(card_id: String) -> void:
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.add_card_to_deck(card_id)
		print("Drafted card: ", card_id)
	
	_close_card_draft()

func _on_skip_draft_pressed() -> void:
	_close_card_draft()

func _close_card_draft() -> void:
	$VBoxContainer.visible = true
	draft_overlay.visible = false
