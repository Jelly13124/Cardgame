extends Control

# Temporary master pool for drafting
var draft_pool = [
	"unit_robot_leader", "unit_battle_enforce_drone", "unit_defend_drone", "unit_attack_drone", "spell_air_raid", "spell_draft", "spell_zap"
]

@onready var card_container = $VBoxContainer/CardsContainer
@onready var skip_button = $VBoxContainer/MarginContainer/SkipButton
@onready var title_label = $VBoxContainer/TitleLabel

func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)
	_generate_draft_options()

func _generate_draft_options() -> void:
	# Clear existing
	for child in card_container.get_children():
		child.queue_free()
		
	# Pick 3 random cards
	var draft_options = []
	var pool_copy = draft_pool.duplicate()
	pool_copy.shuffle()
	
	for i in range(min(3, pool_copy.size())):
		draft_options.append(pool_copy[i])
		
	# Instantiate buttons for the cards
	for card_id in draft_options:
		var btn = Button.new()
		btn.text = card_id.replace("unit_", "").replace("spell_", "").capitalize()
		btn.custom_minimum_size = Vector2(250, 400) # Big like a card
		btn.theme_override_font_sizes.font_size = 24
		
		btn.pressed.connect(func(): _on_card_selected(card_id))
		card_container.add_child(btn)

func _on_card_selected(card_id: String) -> void:
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.add_card_to_deck(card_id)
		print("Drafted card: ", card_id)
	
	# Return to map
	get_tree().change_scene_to_file("res://run_system/ui/map_scene.tscn")

func _on_skip_pressed() -> void:
	print("Skipped draft reward.")
	get_tree().change_scene_to_file("res://run_system/ui/map_scene.tscn")
