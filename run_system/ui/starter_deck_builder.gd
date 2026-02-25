extends Control

const MIN_CARDS = 5
const MAX_CARDS = 10

# These will be loaded dynamically in _ready based on RunManager's hero selection
var available_pool: Array[String] = []
var constructed_deck: Array[String] = [
	"unit_defend_drone", "unit_defend_drone",
	"unit_attack_drone", "unit_attack_drone"
]
var current_hero = "hero_robot_bill"

@onready var pool_container = $VBoxContainer/HBoxContainer/PanelPool/VBoxContainer/ScrollContainer/PoolGrid
@onready var deck_container = $VBoxContainer/HBoxContainer/PanelDeck/VBoxContainer/ScrollContainer/DeckGrid
@onready var count_label = $VBoxContainer/HBoxContainer/PanelDeck/VBoxContainer/CountLabel
@onready var start_button = $VBoxContainer/MarginContainer/StartButton

var card_factory = null

func _ready() -> void:
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager and run_manager.current_hero_id != "":
		current_hero = run_manager.current_hero_id
		
	# Setup Card Factory
	var factory_script = load("res://addons/card-framework/json_card_factory.gd")
	if factory_script:
		card_factory = factory_script.new()
		card_factory.default_card_scene = load("res://battle_scene/unit_card.tscn")
		card_factory.card_asset_dir = "res://battle_scene/assets/images/cards"
		card_factory.card_info_dir = "res://battle_scene/card_info"
		card_factory.back_image = load("res://battle_scene/assets/images/cards/cardBack_blue4.png")
		card_factory.card_size = Vector2(200, 280)
		add_child(card_factory)
		card_factory.preload_card_data()
		
	_load_hero_pool()
	_refresh_ui()
	start_button.pressed.connect(_on_start_pressed)

func _load_hero_pool() -> void:
	var path = "res://battle_scene/card_info/player/units/%s.json" % current_hero
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data.has("starting_pool"):
				# Populate using the JSON array
				available_pool.clear()
				for c in data["starting_pool"]:
					available_pool.append(str(c))
			else:
				print("Hero JSON missing 'starting_pool' array.")
	else:
		print("Could not find hero JSON at: ", path)

func _refresh_ui() -> void:
	# Clear both grids
	for child in pool_container.get_children(): child.queue_free()
	for child in deck_container.get_children(): child.queue_free()
	
	if not card_factory: return
	
	# Determine unique cards and their counts in the deck
	var deck_counts = {}
	for card_id in constructed_deck:
		deck_counts[card_id] = deck_counts.get(card_id, 0) + 1
		
	# Populate Pool (Unique cards only)
	var unique_pool = []
	for card_id in available_pool:
		if not unique_pool.has(card_id):
			unique_pool.append(card_id)
			
	for card_id in unique_pool:
		var current_copies = deck_counts.get(card_id, 0)
		# Only show in pool if we haven't drafted 2 copies yet
		if current_copies < 2:
			var card_node = card_factory.create_card(card_id, null)
			if card_node:
				if card_node.get_parent():
					card_node.get_parent().remove_child(card_node)
				pool_container.add_child(card_node)
				card_node.custom_minimum_size = card_factory.card_size
				
				# Prevent the card from thinking it's in a real container to stop dragging
				card_node.card_container = null
				# Listen for clicks on the card itself
				if not card_node.gui_input.is_connected(_on_pool_card_click.bind(card_id)):
					card_node.gui_input.connect(_on_pool_card_click.bind(card_id))
		
	# Populate Deck (Show unique drafted copies with multiplier badges)
	var unique_deck = []
	for card_id in constructed_deck:
		if not unique_deck.has(card_id):
			unique_deck.append(card_id)
			
	for card_id in unique_deck:
		var current_copies = deck_counts.get(card_id, 0)
		var card_node = card_factory.create_card(card_id, null)
		if card_node:
			if card_node.get_parent():
				card_node.get_parent().remove_child(card_node)
			deck_container.add_child(card_node)
			card_node.custom_minimum_size = card_factory.card_size
			card_node.card_container = null
			
			if card_node.has_method("set_duplicate_count"):
				card_node.set_duplicate_count(current_copies)
				
			# Listen for clicks on the card itself
			if not card_node.gui_input.is_connected(_on_deck_card_click.bind(card_id)):
				card_node.gui_input.connect(_on_deck_card_click.bind(card_id))
		
	count_label.text = "Selected: %d / %d (Min: %d)" % [constructed_deck.size(), MAX_CARDS, MIN_CARDS]
	
	# Update Button State
	if constructed_deck.size() >= MIN_CARDS and constructed_deck.size() <= MAX_CARDS:
		start_button.disabled = false
		start_button.modulate = Color(0, 1, 0, 1) # Green
	else:
		start_button.disabled = true
		start_button.modulate = Color(1, 1, 1, 0.5)

func _on_pool_card_click(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_move_to_deck(card_id)
		get_viewport().set_input_as_handled()

func _on_deck_card_click(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_move_to_pool(card_id)
		get_viewport().set_input_as_handled()

func _move_to_deck(card_id: String) -> void:
	if constructed_deck.size() >= MAX_CARDS: return
	
	# Enforce max 2 copies rule
	var count = 0
	for id in constructed_deck:
		if id == card_id:
			count += 1
			
	if count >= 2:
		var main = get_tree().current_scene
		if main and main.has_method("show_notification"):
			main.show_notification("Max 2 copies!", Color.RED)
		return
	
	# We don't remove from pool anymore because pool just shows unique available cards
	constructed_deck.append(card_id)
	_refresh_ui()

func _move_to_pool(card_id: String) -> void:
	# Enforce mandatory starter cards
	if card_id == "unit_defend_drone" and constructed_deck.count(card_id) <= 2:
		var main = get_tree().current_scene
		if main and main.has_method("show_notification"):
			main.show_notification("Can't remove mandatory starter!", Color.RED)
		return
	if card_id == "unit_attack_drone" and constructed_deck.count(card_id) <= 2:
		var main = get_tree().current_scene
		if main and main.has_method("show_notification"):
			main.show_notification("Can't remove mandatory starter!", Color.RED)
		return
		
	constructed_deck.erase(card_id)
	_refresh_ui()

func _on_start_pressed() -> void:
	if constructed_deck.size() < MIN_CARDS: return
	
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.start_new_run(current_hero, constructed_deck)
		print("Starting new run with %d cards!" % constructed_deck.size())
		get_tree().change_scene_to_file("res://run_system/ui/map_scene.tscn")
	else:
		print("ERROR: RunManager autoload not found!")
