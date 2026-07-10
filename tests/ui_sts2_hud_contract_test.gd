extends Node

const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _texture_path(node: Node) -> String:
	if node is TextureRect and node.texture:
		return node.texture.resource_path
	return ""


func _run() -> void:
	await _test_shared_top_bar()
	await _test_map_background()
	await _test_battle_energy_and_end_turn()
	if failures.is_empty():
		print("[OK] STS2 HUD contract passed")
		get_tree().quit(0)
		return
	push_error("STS2 HUD contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_shared_top_bar() -> void:
	var rm := get_tree().root.get_node("RunManager")
	var original_tools: Array[String] = rm.tool_inventory.duplicate()
	var original_relics: Array[String] = rm.relics.duplicate()
	rm.tool_inventory.clear()
	rm.tool_inventory.append("med_kit")
	rm.tool_inventory.append("smoke_bomb")
	rm.relics.clear()
	rm.relics.append("tool_belt")

	var host := Control.new()
	add_child(host)
	var bar := RUN_TOP_BAR.new()
	bar.show_settings_button = true
	host.add_child(bar)
	await get_tree().process_frame
	await get_tree().process_frame

	var background := bar.find_child("BackgroundArt", true, false)
	_expect(background != null, "shared top bar uses a named BackgroundArt texture")
	var background_path := _texture_path(background)
	_expect(
		background_path.ends_with("/hud_topbar_sts2.png"),
		"shared top bar uses hud_topbar_sts2.png (got %s)" % background_path
	)

	var tool_shelf := bar.find_child("ToolShelf", true, false)
	_expect(tool_shelf != null, "shared top bar exposes ToolShelf")
	if tool_shelf:
		_expect(tool_shelf.get_child_count() == 1, "top bar renders exactly one tool slot")
		if tool_shelf.get_child_count() == 1:
			_expect(tool_shelf.get_child(0).size.y <= 44.0, "the single tool slot stays square")

	var floor_label := bar.find_child("FloorLabel", true, false)
	_expect(floor_label != null, "top bar keeps a floor-only readout")
	_expect(bar.find_child("ActLabel", true, false) == null, "top bar removes the Act readout")
	var deck_button: Button = null
	for candidate in bar.find_children("*", "Button", true, false):
		if (candidate as Button).tooltip_text == tr("UI_BATTLE_VIEW_RUN_DECK"):
			deck_button = candidate as Button
			break
	_expect(deck_button != null, "top bar keeps the run-deck interaction")
	if deck_button:
		var deck_path := deck_button.icon.resource_path if deck_button.icon else ""
		_expect(
			deck_path.ends_with("/iconb_deck_stack.png"),
			"run-deck button uses iconb_deck_stack.png (got %s)" % deck_path
		)

	var timer_icon := bar.find_child("TimerIcon", true, false)
	_expect(timer_icon != null, "timer has the alarm-clock icon")
	_expect(
		_texture_path(timer_icon).ends_with("/iconb_clock.png"),
		"timer uses the existing iconb_clock.png asset"
	)

	host.queue_free()
	await get_tree().process_frame
	rm.tool_inventory.assign(original_tools)
	rm.relics.assign(original_relics)


func _test_map_background() -> void:
	var packed := load("res://run_system/ui/map_scene.tscn") as PackedScene
	var map := packed.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var background_path := ""
	if map.map_background_tex:
		background_path = map.map_background_tex.resource_path
	_expect(
		background_path.ends_with("/wasteland_route_map_sts2_bg.png"),
		"map uses the approved STS2-minimal background (got %s)" % background_path
	)
	map.queue_free()
	await get_tree().process_frame


func _test_battle_energy_and_end_turn() -> void:
	var packed := load("res://battle_scene/battle_scene.tscn") as PackedScene
	var battle := packed.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var background := battle.get_node_or_null("BattleBackground")
	var background_path := _texture_path(background)
	_expect(
		background_path.ends_with("/wasteland_battlefield_sts2.png"),
		"battle uses the approved STS2-minimal background (got %s)" % background_path
	)

	var energy := battle.get_node_or_null("EnergyDisplay")
	_expect(energy != null, "battle builds EnergyDisplay")
	if energy:
		var frame := energy.get_node_or_null("Frame")
		var energy_path := _texture_path(frame)
		_expect(
			energy_path.ends_with("/hud_energy_badge_sts2.png"),
			"battle energy uses hud_energy_badge_sts2.png (got %s)" % energy_path
		)
		_expect(energy.get_node_or_null("EnergyCore") == null, "battle removes the old loose core orb")

	var end_turn := battle.get_node_or_null("EndRoundButton") as Button
	_expect(end_turn != null, "battle keeps the EndRoundButton interaction")
	if end_turn:
		_expect(end_turn.size.x <= 240.0, "EndRoundButton stays compact at 240 px or less")
		var style := end_turn.get_theme_stylebox("normal")
		var style_path := ""
		if style is StyleBoxTexture and style.texture:
			style_path = style.texture.resource_path
		_expect(
			style_path.ends_with("/hud_end_turn_sts2.png"),
			"EndRoundButton uses hud_end_turn_sts2.png (got %s)" % style_path
		)

	battle.queue_free()
	await get_tree().process_frame
