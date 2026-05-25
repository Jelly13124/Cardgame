extends Control

const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")

@onready var bill_btn = $HBoxContainer/BillButton
@onready var jerry_btn = $HBoxContainer/JerryButton

func _ready() -> void:
	var bill_portrait = "res://battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png"
	if ResourceLoader.exists(bill_portrait):
		var bill_tex = load(bill_portrait)
		var tex_rect = TextureRect.new()
		tex_rect.texture = bill_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(250, 250)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var vbox = bill_btn.get_node_or_null("VBoxContainer")
		if vbox:
			vbox.add_child(tex_rect)
			vbox.move_child(tex_rect, 0)

	bill_btn.pressed.connect(func(): _select_hero("hero_robot_bill"))
	jerry_btn.pressed.connect(func(): _select_hero("hero_jerry_killer"))

func _select_hero(hero_id: String) -> void:
	print("Selected Commander: ", hero_id)
	RunManager.start_new_run(hero_id, RunManager.get_default_starter_deck())
	get_tree().change_scene_to_packed(MAP_PACKED)
		
