extends Control

@onready var bill_btn = $HBoxContainer/BillButton
@onready var jerry_btn = $HBoxContainer/JerryButton

func _ready() -> void:
	# Add Robot Bill's brand new portrait to the UI
	var bill_tex = load("res://battle_scene/assets/images/cards/hero_robot_bill.png")
	if bill_tex:
		var tex_rect = TextureRect.new()
		tex_rect.texture = bill_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(250, 250)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var vbox = bill_btn.get_node_or_null("VBoxContainer")
		if vbox:
			vbox.add_child(tex_rect)
			vbox.move_child(tex_rect, 0)
			
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
