extends Control

@onready var top_bar_health = $TopBar/HBoxContainer/HealthLabel
@onready var top_bar_gold = $TopBar/HBoxContainer/GoldLabel
@onready var top_bar_core = $TopBar/HBoxContainer/CoreLabel
@onready var floor_label = $CenterContainer/VBoxContainer/FloorLabel
@onready var battle_button = $CenterContainer/VBoxContainer/BattleButton

func _ready() -> void:
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.health_changed.connect(_on_health_changed)
		run_manager.resources_changed.connect(_on_resources_changed)
		
		# Initial UI sync
		_on_health_changed(run_manager.current_health, run_manager.max_health)
		_on_resources_changed(run_manager.gold, run_manager.core)
		floor_label.text = "Floor: %d" % run_manager.current_floor
	
	battle_button.pressed.connect(_on_battle_pressed)

func _on_health_changed(current: int, maximum: int) -> void:
	top_bar_health.text = "HP: %d/%d" % [current, maximum]

func _on_resources_changed(gold: int, core: int) -> void:
	top_bar_gold.text = "Gold: %d" % gold
	top_bar_core.text = "Core: %d" % core

func _on_battle_pressed() -> void:
	var run_manager = get_node_or_null("/root/RunManager")
	if run_manager:
		run_manager.current_floor += 1
	get_tree().change_scene_to_file("res://battle_scene/battle_scene.tscn")
