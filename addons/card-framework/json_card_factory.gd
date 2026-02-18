@tool
## JSON-based card factory implementation with asset management and caching.
##
## JsonCardFactory extends CardFactory to provide JSON-based card creation with
## sophisticated asset loading, data caching, and error handling. It manages
## card definitions stored as JSON files and automatically loads corresponding
## image assets from specified directories.
##
## Key Features:
## - JSON-based card data definition with flexible schema
## - Automatic asset loading and texture management  
## - Performance-optimized data caching for rapid card creation
## - Comprehensive error handling with detailed logging
## - Directory scanning for bulk card data preloading
## - Configurable asset and data directory paths
##
## File Structure Requirements:
## [codeblock]
## project/
## ├── card_assets/          # card_asset_dir
## │   ├── ace_spades.png
## │   └── king_hearts.png
## ├── card_data/            # card_info_dir  
## │   ├── ace_spades.json   # Matches asset filename
## │   └── king_hearts.json
## [/codeblock]
##
## JSON Schema Example:
## [codeblock]
## {
##   "name": "ace_spades",
##   "front_image": "ace_spades.png", 
##   "suit": "spades",
##   "value": "ace"
## }
## [/codeblock]
class_name JsonCardFactory
extends CardFactory

@export_group("card_scenes")
## Base card scene to instantiate for each card (must inherit from Card class)
@export var default_card_scene: PackedScene

@export_group("asset_paths")
## Directory path containing card image assets (PNG, JPG, etc.)
@export var card_asset_dir: String
## Directory path containing card information JSON files
@export var card_info_dir: String

@export_group("default_textures")
## Common back face texture used for all cards when face-down
@export var back_image: Texture2D


## Validates configuration and default card scene on initialization.
## Ensures default_card_scene references a valid Card-inherited node.
func _ready() -> void:
	if default_card_scene == null:
		push_error("default_card_scene is not assigned!")
		return
		
	# Validate that default_card_scene produces Card instances
	var temp_instance = default_card_scene.instantiate()
	if not (temp_instance is Card):
		push_error("Invalid node type! default_card_scene must reference a Card.")
		default_card_scene = null
	temp_instance.queue_free()


## Creates a new card instance with JSON data and adds it to the target container.
## Uses cached data if available, otherwise loads from JSON and asset files.
## @param card_name: Identifier matching JSON filename (without .json extension)
## @param target: CardContainer to receive the new card
## @returns: Created Card instance or null if creation failed
func create_card(card_name: String, target: CardContainer) -> Card:
	# Use cached data for optimal performance
	if preloaded_cards.has(card_name):
		var card_info = preloaded_cards[card_name]["info"]
		var front_image = preloaded_cards[card_name]["texture"]
		return _create_card_node(card_info.name, front_image, target, card_info)
	else:
		# Load card data on-demand (slower but supports dynamic loading)
		var card_info = _load_card_info(card_name)
		if card_info == null or card_info == {}:
			push_error("Card info not found for card: %s" % card_name)
			return null

		# Validate required JSON fields
		if not card_info.has("front_image"):
			push_error("Card info does not contain 'front_image' key for card: %s" % card_name)
			return null
			
		# Load corresponding image asset
		var front_image_path = card_asset_dir + "/" + card_info["front_image"]
		var front_image = _load_image(front_image_path)
		if front_image == null:
			push_error("Card image not found: %s" % front_image_path)
			return null

		return _create_card_node(card_info.name, front_image, target, card_info)


func preload_card_data() -> void:
	_scan_dir_recursive(card_info_dir)

func _scan_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Failed to open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_scan_dir_recursive(path + "/" + file_name)
		else:
			if file_name.ends_with(".json"):
				var card_name = file_name.get_basename()
				var full_path = path + "/" + file_name
				_preload_single_card(card_name, full_path)
		file_name = dir.get_next()

func _preload_single_card(card_name: String, full_path: String) -> void:
	var card_info = _parse_json_file(full_path)
	if card_info.is_empty():
		return

	var front_image_path = card_asset_dir + "/" + card_info.get("front_image", "")
	var front_image_texture = _load_image(front_image_path)
	if front_image_texture == null:
		return

	preloaded_cards[card_name] = {
		"info": card_info,
		"texture": front_image_texture
	}
	print("Preloaded card: %s from %s" % [card_name, full_path])

func _parse_json_file(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse JSON: %s" % path)
		return {}
	return json.data


func _load_card_info(card_name: String) -> Dictionary:
	# Check root first
	var root_path = card_info_dir + "/" + card_name + ".json"
	if FileAccess.file_exists(root_path):
		return _parse_json_file(root_path)
	
	# Search subdirectories recursively
	return _search_subdirs_for_card(card_info_dir, card_name)

func _search_subdirs_for_card(path: String, card_name: String) -> Dictionary:
	var dir = DirAccess.open(path)
	if dir == null: return {}
	
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if dir.current_is_dir():
			if item != "." and item != "..":
				var res = _search_subdirs_for_card(path + "/" + item, card_name)
				if not res.is_empty():
					return res
		else:
			if item == card_name + ".json":
				return _parse_json_file(path + "/" + item)
		item = dir.get_next()
	return {}


## Loads image texture from file path with error handling.
## @param image_path: Full path to image file
## @returns: Loaded Texture2D or null if loading failed
func _load_image(image_path: String) -> Texture2D:
	var texture = load(image_path) as Texture2D
	if texture == null:
		push_error("Failed to load image resource: %s" % image_path)
		return null
	return texture


## Creates and configures a card node with textures and adds it to target container.
## @param card_name: Card identifier for naming and reference
## @param front_image: Texture for card front face
## @param target: CardContainer to receive the card
## @param card_info: Dictionary of card data from JSON
## @returns: Configured Card instance or null if addition failed
func _create_card_node(card_name: String, front_image: Texture2D, target: CardContainer, card_info: Dictionary) -> Card:
	var card = _generate_card(card_info)
	
	# Duplicate the dictionary to prevent shared-reference bugs
	# (e.g. changing faction or buffs on one card affecting all future cards)
	card.card_info = card_info.duplicate()
	card.card_size = card_size
	
	# Validate container can accept this card if target exists
	if target:
		if !target._card_can_be_added([card]):
			print("Card cannot be added: %s" % card_name)
			card.queue_free()
			return null
		
		# Add to scene tree and container
		var cards_node = target.get_node("Cards")
		cards_node.add_child(card)
		
		# If enemy, start from the far right for a "marching in" effect
		if card.card_info.get("side", "") == "enemy":
			# Offset Y slightly to match the row's center_y if target is a BattleRow
			var row_center_y = target.get("center_y") if target.has_method("get") else 0.0
			card.global_position = Vector2(2500, target.global_position.y + row_center_y)
		
		target.add_card(card)
	else:
		# If no target, add to the root of the current scene so it's in the tree
		var main = get_tree().current_scene
		if main:
			main.add_child(card)
	
	# Set card identity and textures
	card.card_name = card_name
	card.set_faces(front_image, back_image)

	return card


## Instantiates a new card from the default card scene.
## @param _card_info: Card data dictionary (reserved for future customization)
## @returns: New Card instance or null if scene is invalid
func _generate_card(_card_info: Dictionary) -> Card:
	if default_card_scene == null:
		push_error("default_card_scene is not assigned!")
		return null
	return default_card_scene.instantiate()
