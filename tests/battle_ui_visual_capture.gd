extends Node

## Windowed visual check for the STS2-style battle presentation (not run by the
## test runner). Saves two screenshots for a human to inspect:
##   res://tmp/battle-ui-aim.png    — arrow over an enemy (red), reticle, outlines
##   res://tmp/battle-ui-leave.png  — a card arcing to discard with its trail
##   res://tmp/battle-ui-burn.png   — an exhausted card burning
## Run with APPDATA / XDG_DATA_HOME pointed at a temp directory.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn
const AIM_PATH = "res://tmp/battle-ui-aim.png"
const LEAVE_PATH = "res://tmp/battle-ui-leave.png"
const BURN_PATH = "res://tmp/battle-ui-burn.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	RunManager.is_run_active = false
	RunManager.current_hero_id = "base:cowboy_bill"
	RunManager.current_hero_data = {"card_ui_skin": "base:cowboy_bill"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp"))
	var battle := BATTLE_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(battle)
	await get_tree().process_frame
	get_tree().current_scene = battle
	for _i in range(45):
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	battle.player.energy = 10
	var strike = battle.deck_manager.add_card_to_hand("base:strike")
	var reload = battle.deck_manager.add_card_to_hand("base:reload")
	await get_tree().create_timer(0.5).timeout

	var enemy: Node2D = battle.enemy_container.get_child(0)
	battle.start_spell_targeting(strike)
	# A windowed run cannot rely on warp_mouse, so pin the arrow on the enemy.
	battle.set_process(false)
	var arrow = battle.targeting_arrow
	arrow.set_process(false)
	arrow._update_curve(enemy.get_targeting_rect().get_center())
	arrow.set_target_valid(true)
	enemy.show_reticle()
	await get_tree().create_timer(1.0).timeout
	if not await _save(AIM_PATH):
		return
	battle.set_process(true)
	enemy.hide_reticle()
	battle._cancel_spell_targeting()

	battle.play_spell(reload, null)
	await _wait_for_burst(battle, 4.0)
	await get_tree().create_timer(0.15).timeout
	if not await _save(BURN_PATH):
		return
	await get_tree().create_timer(1.0).timeout
	battle.play_spell(strike, enemy)
	await get_tree().create_timer(1.15).timeout
	if not await _save(LEAVE_PATH):
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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


func _wait_for_burst(battle: Node, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while battle.find_children("*", "CPUParticles2D", true, false).is_empty():
		if Time.get_ticks_msec() > deadline:
			return
		await get_tree().process_frame
