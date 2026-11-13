extends Node

## Windowed visual check for the STS2 battle layout and the text title menu
## (not run by the test runner). Saves, for a human to inspect:
##   res://tmp/sts2-menu.png         - the title menu
##   res://tmp/sts2-battle-rest.png  - a 3-enemy battle, 5-card hand at rest
##   res://tmp/sts2-battle-hover.png - the same with the third card hovered
## Run with APPDATA / XDG_DATA_HOME pointed at a temp directory.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const MENU_SCENE = preload("uid://dnjlmt1repvjw")  # res://ui/menus/main_menu.tscn
const MONSTERS = preload("uid://dvu3etytjqum8")  # res://core/combat/monsters.gd


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp"))
	var menu := MENU_SCENE.instantiate()
	get_tree().root.add_child(menu)
	await get_tree().create_timer(1.5).timeout
	if not await _save("res://tmp/sts2-menu.png"):
		return
	menu.queue_free()

	RunManager.start_new_run("base:cowboy_bill", [], 0, "STS2CAPTURE1")
	var battle := BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().create_timer(1.5).timeout
	while battle.enemy_container.get_child_count() < 3:
		battle.combat.add_enemy(MONSTERS.create("base:scrap_rat"))
	await get_tree().create_timer(1.5).timeout
	if not await _save("res://tmp/sts2-battle-rest.png"):
		return
	var hand = battle.find_child("Hand", true, false)
	hand.set_hovered(hand._held_cards[2])
	await get_tree().create_timer(0.6).timeout
	if not await _save("res://tmp/sts2-battle-hover.png"):
		return
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	get_tree().quit(0)


func _save(path: String) -> bool:
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s: %s" % [path, error])
		get_tree().quit(1)
		return false
	return true
