extends Control

@onready var bill_btn = $HBoxContainer/BillButton
@onready var jerry_btn = $HBoxContainer/JerryButton

func _ready() -> void:
	bill_btn.pressed.connect(func(): _select_hero("hero_robot_bill"))
	jerry_btn.pressed.connect(func(): _select_hero("hero_jerry_killer"))

func _select_hero(hero_id: String) -> void:
	print("Selected Commander: ", hero_id)
	
	# Pass the selected hero to the Deck Builder scene via a global/autoload, or 
	# load it and set it. Passing via RunManager is easiest.
	
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.current_hero_id = hero_id
		
	get_tree().change_scene_to_file("res://run_system/ui/starter_deck_builder.tscn")
