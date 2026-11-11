extends Node

const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const ENEMY_ENTITY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const TEST_SAVE_ROOT = preload("uid://c5pfll7nw68un")  # res://tests/support/test_save_root.gd

var failures: PackedStringArray = []


func _ready() -> void:
	TEST_SAVE_ROOT.use("ui_sts2_hud_contract")
	call_deferred("_run")


func _exit_tree() -> void:
	TEST_SAVE_ROOT.release()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _texture_path(node: Node) -> String:
	if node is TextureRect and node.texture:
		return node.texture.resource_path
	if node is NinePatchRect and node.texture:
		return node.texture.resource_path
	return ""


func _run() -> void:
	await _test_shared_top_bar()
	await _test_map_background()
	await _test_battle_energy_and_end_turn()
	await _test_category_intents()
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
	rm.tool_inventory.append("base:med_kit")
	rm.tool_inventory.append("base:smoke_bomb")
	rm.relics.clear()
	rm.relics.append("base:tool_belt")

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

	var heart_icon := bar.find_child("HeartIcon", true, false)
	_expect(heart_icon != null, "shared top bar exposes the cartoon HeartIcon")
	_expect(
		_texture_path(heart_icon).ends_with("/icon_heart.png"),
		"HP uses the approved UI03 cartoon heart (got %s)" % _texture_path(heart_icon)
	)
	_expect(bar.find_child("HpLabel", true, false) != null, "shared top bar exposes HpLabel")
	_expect(bar.find_child("XpLabel", true, false) != null, "shared top bar exposes XpLabel")
	var xp_tick := bar.find_child("XpTick", true, false) as ProgressBar
	_expect(xp_tick != null, "shared top bar exposes the short XpTick")
	if xp_tick:
		_expect(xp_tick.custom_minimum_size.x <= 72.0, "XpTick stays short at 72 px or less")
	var progress_bars := bar.find_children("*", "ProgressBar", true, false)
	_expect(progress_bars.size() == 1, "top bar keeps only the short XP tick, not HP/XP bars")

	var tool_shelf := bar.find_child("ToolShelf", true, false)
	_expect(tool_shelf != null, "shared top bar exposes ToolShelf")
	if tool_shelf:
		_expect(tool_shelf.get_child_count() == 1, "top bar renders exactly one tool slot")
		if tool_shelf.get_child_count() == 1:
			var tool_button := tool_shelf.get_child(0) as Button
			_expect(tool_button != null and tool_button.size.y <= 44.0, "the single tool slot stays square")
			if tool_button != null:
				_expect(
					tool_button.tooltip_text.is_empty(),
					"tool slot disables Godot's native black tooltip"
				)
				Tooltip.hide()
				tool_button.mouse_entered.emit()
				await get_tree().process_frame
				var tooltip_label := Tooltip.get("_label") as RichTextLabel
				_expect(
					bool(Tooltip.get("_visible"))
					and int(Tooltip.get("_owner_id")) == tool_button.get_instance_id(),
					"tool slot opens the owner-safe global tooltip"
				)
				_expect(
					tooltip_label != null
					and tooltip_label.text.contains("[b]")
					and tooltip_label.text.contains(tr("TOOL_med_kit_DESC")),
					"tool slot global tooltip contains the rich title and description"
				)
				tool_button.mouse_exited.emit()
				await get_tree().process_frame
				_expect(not bool(Tooltip.get("_visible")), "tool slot exit hides its own tooltip")

	var plain_width := float(Tooltip.call("_measure_text_width", "Short hint"))
	var colored_width := float(
		Tooltip.call("_measure_text_width", "[color=#9fd0ff]Short hint[/color]")
	)
	_expect(
		is_equal_approx(plain_width, colored_width),
		"global tooltip width ignores parameterized BBCode color tags"
	)

	var floor_label := bar.find_child("FloorLabel", true, false)
	_expect(floor_label != null, "top bar keeps a floor-only readout")
	_expect(bar.find_child("ActLabel", true, false) == null, "top bar removes the Act readout")
	var deck_button: Button = null
	for candidate in bar.find_children("*", "Button", true, false):
		if str(candidate.get_meta(Tooltip.TOOLTIP_TEXT_META, "")) == tr("UI_BATTLE_VIEW_RUN_DECK"):
			deck_button = candidate as Button
			break
	_expect(deck_button != null, "top bar keeps the run-deck interaction")
	if deck_button:
		_expect(deck_button.tooltip_text.is_empty(), "run-deck hints use the shared tooltip overlay")
		var deck_path := deck_button.icon.resource_path if deck_button.icon else ""
		_expect(
			deck_path.ends_with("/iconb_deck_stack.png"),
			"run-deck button uses iconb_deck_stack.png (got %s)" % deck_path
		)
	var settings_button: Button = null
	for candidate in bar.find_children("*", "Button", true, false):
		if str(candidate.get_meta(Tooltip.TOOLTIP_TEXT_META, "")) == tr("SETTINGS_BUTTON"):
			settings_button = candidate as Button
			break
	_expect(settings_button != null, "battle top bar keeps the settings interaction")
	if settings_button:
		_expect(settings_button.tooltip_text.is_empty(), "settings hints use the shared tooltip overlay")
		var settings_path := settings_button.icon.resource_path if settings_button.icon else ""
		_expect(
			settings_path.ends_with("/icon_gear.png"),
			"settings uses the matching comic gear icon (got %s)" % settings_path
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
	var packed := load("uid://d3x5b8wvg2q") as PackedScene  # res://ui/map/map_scene.tscn
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
	var packed := load("uid://dnhj5pp3c1v2l") as PackedScene  # res://ui/battle/battle_screen.tscn
	var battle := packed.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.65).timeout
	var background := battle.get_node_or_null("BattleBackground")
	var background_path := _texture_path(background)
	_expect(
		background_path.ends_with("/wasteland_battlefield_quiet_v6.png"),
		"battle uses the cool layered comic combat-stage background (got %s)" % background_path
	)
	_expect(
		background.self_modulate.r > 1.35
		and background.self_modulate.g > 1.35
		and background.self_modulate.b > 1.25,
		"battle lifts the cool background midtones instead of crushing the scene"
	)

	var player := battle.get_node_or_null("Player")
	var player_sprite := player.get("_sprite") as AnimatedSprite2D if player else null
	_expect(
		player_sprite != null
		and String(player_sprite.animation) == "idle"
		and player_sprite.frame == 0
		and not player_sprite.is_playing(),
		"Cowboy Bill holds a quiet static rest pose instead of looping an idle animation"
	)
	if player_sprite:
		_expect(
			not player_sprite.sprite_frames.get_animation_loop("idle"),
			"Cowboy Bill's idle track is non-looping"
		)
	var player_hud: Node = player.get("_hud") if player else null
	_expect(player_hud != null, "player builds its CharacterHUD")
	if player_hud:
		_expect(player_hud.bar_width == 250 and player_hud.bar_height == 16, "creature health uses the reference 250x16 geometry")
		var initial_loss := player_hud.get_node("HpFrame/HpLoss") as TextureProgressBar
		_expect(is_equal_approx(initial_loss.ratio, float(player.health) / player.max_health)
			and player_hud.get("_hp_echo_tween") == null and player_hud.get("_hp_fill_tween") == null,
			"restoring run HP at battle startup does not fake a damage or healing animation")
		player_hud.update_stats(63, 100, 6)
		var frame := player_hud.get_node_or_null("HpFrame") as TextureRect
		var bar := player_hud.get_node_or_null("HpFrame/HpBar") as TextureProgressBar
		var loss := player_hud.get_node_or_null("HpFrame/HpLoss") as TextureProgressBar
		var number := player_hud.get_node_or_null("HpFrame/HpLabel") as Control
		var block := player_hud.get_node_or_null("BlockBadge") as TextureRect
		var block_number := player_hud.get_node_or_null("BlockBadge/BlockLabel") as Label
		_expect(frame != null and frame.size == Vector2(250, 16) and _texture_path(frame).ends_with("/combat/hp_frame.png"), "health uses the original 250x16 frame layer")
		_expect(bar != null and bar.size == Vector2(250, 16) and is_equal_approx(bar.ratio, 0.63), "health foreground immediately matches the creature")
		_expect(loss != null and loss.size == Vector2(250, 16), "health loss has its own independent layer")
		_expect(number != null and str(number.get("text")) == "63/100" and number.size == Vector2(250, 40) and number.position == Vector2(0, -12), "health text stays centered over the thin bar")
		_expect(number != null and int(number.get("font_size")) == 24 and int(number.get("outline_size")) == 16, "health text uses 24/16 typography")
		_expect(number != null and number.get("font_color") == Color("#fff8e8") and number.get("outline_color") == Color("#071018"), "health number keeps warm white fill and strong ink outline")
		_expect(block != null and block.visible and block.size == Vector2(60, 60), "Block has an independent 60 px shield")
		_expect(_texture_path(block).ends_with("/combat/block.png"), "Block uses the original combat shield art")
		_expect(block_number != null and block_number.text == "6" and block_number.get_theme_font_size("font_size") == 24 and block_number.get_theme_constant("outline_size") == 14, "Block count uses 24/14 typography")
		player_hud.update_stats(63, 100, 0)
		_expect(block != null and not block.visible, "Block shield hides at zero")
		_expect(bar != null and is_equal_approx(bar.ratio, 0.63), "HP remains proportional when Block is removed")
	var normal_enemy := ENEMY_ENTITY.create("base:trash_robot")
	var elite_enemy := ENEMY_ENTITY.create("base:armored_patrol")
	var boss_enemy := ENEMY_ENTITY.create("base:rust_titan")
	_expect(not normal_enemy.is_elite and not normal_enemy.is_boss, "normal factory classification")
	_expect(elite_enemy.is_elite and not elite_enemy.is_boss, "elite factory classification")
	_expect(boss_enemy.is_boss and not boss_enemy.is_elite, "boss factory classification")
	_expect(normal_enemy._health_bar_size() == Vector2i(250, 16), "normal enemies match the player 250x16 bar")
	_expect(elite_enemy._health_bar_size() == Vector2i(250, 16), "elites match the player 250x16 bar")
	_expect(boss_enemy._health_bar_size() == Vector2i(250, 16), "bosses match the player 250x16 bar")
	normal_enemy.free()
	elite_enemy.free()
	boss_enemy.free()

	var draw_pile := battle.get_node_or_null("CardManager/Deck")
	var discard_pile := battle.get_node_or_null("CardManager/DiscardPile")
	_expect(draw_pile != null, "battle keeps the draw-pile interaction node")
	_expect(discard_pile != null, "battle keeps the discard-pile interaction node")
	if draw_pile and discard_pile:
		_expect(draw_pile.hide_cards, "draw pile keeps framework card surfaces hidden")
		_expect(discard_pile.hide_cards, "discard pile keeps framework card surfaces hidden")
		_expect(draw_pile.get_node_or_null("CardBackVisual") == null, "draw pile removes legacy card-back art")
		_expect(
			discard_pile.get_node_or_null("CardBackVisual") == null,
			"discard pile removes legacy card-back art"
		)
		for pair in [[draw_pile, "draw"], [discard_pile, "discard"]]:
			var pile: Control = pair[0]
			var input := pile.get_node_or_null("PileInput") as Control
			var hud := pile.get_node_or_null("PileInput/PileHUD") as Control
			_expect(pile.size == Vector2(160, 220) and pile.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s keeps the passive card-container geometry used by frozen animations" % pair[1])
			_expect(input != null and input.size == Vector2(80, 80), "%s has an independent 80 px input rectangle" % pair[1])
			_expect(hud != null, "%s pile has independent visual layers" % pair[1])
			if hud and input:
				var icon := hud.get_node_or_null("Visuals/PileIcon") as TextureRect
				var count := pile.get_node_or_null("CountLabel") as Label
				_expect(_texture_path(icon).ends_with("/combat/%s.png" % pair[1]), "%s uses original pile art" % pair[1])
				_expect(count != null and count.get_theme_font_size("font_size") == 26 and count.get_theme_constant("outline_size") == 12, "%s direct framework count is 26/12" % pair[1])
				_expect(count != null and count.text == str(pile.get_cards().size()), "%s count matches its unchanged card container" % pair[1])
				var frozen_flight_target := pile.global_position + Vector2(80, 110)
				_expect(icon != null and icon.get_global_rect().get_center().is_equal_approx(frozen_flight_target), "%s frozen animation target lands at the original art center" % pair[1])
				_expect(get_viewport().get_visible_rect().has_point(frozen_flight_target), "%s animation target remains inside the viewport" % pair[1])
				var fixed_rect := input.get_global_rect()
				input.mouse_entered.emit()
				await get_tree().create_timer(0.07).timeout
				_expect(hud.scale.is_equal_approx(Vector2.ONE * 1.25), "%s hover scales visuals to 1.25" % pair[1])
				_expect(count != null and count.scale.is_equal_approx(hud.scale), "%s direct count follows the visual hover scale" % pair[1])
				_expect(input.get_global_rect() == fixed_rect, "%s hover keeps its input rectangle fixed" % pair[1])
				input.mouse_exited.emit()
		var draw_input := draw_pile.get_node_or_null("PileInput") as Control
		var discard_input := discard_pile.get_node_or_null("PileInput") as Control
		_expect(draw_input != null and draw_input.global_position == Vector2(15, 985), "draw input stays inset 15 from the lower-left corner")
		_expect(discard_input != null and discard_input.global_position == Vector2(1825, 985), "discard input stays inset 15 from the lower-right corner")
		await _test_pile_count_container_updates(battle, draw_pile, discard_pile)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		if draw_input:
			draw_input.gui_input.emit(click)
		_expect(battle.ui_manager._current_pile_kind == "draw" and battle.ui_manager.pile_viewer_layer.visible, "draw click opens the existing draw viewer")
		battle.ui_manager.hide_pile_viewer()
		var key := InputEventKey.new()
		key.keycode = Settings.get_key("view_discard")
		key.pressed = true
		battle.ui_manager._input(key)
		_expect(battle.ui_manager._current_pile_kind == "discard" and battle.ui_manager.pile_viewer_layer.visible, "discard keyboard input keeps the existing viewer behavior")
		battle.ui_manager.hide_pile_viewer()

	var energy := battle.get_node_or_null("EnergyDisplay") as Control
	_expect(energy != null, "battle builds EnergyDisplay")
	if energy:
		_expect(energy.position == Vector2(100, 828) and energy.size == Vector2(128, 128), "energy keeps the reference 128 px bottom-left anchor")
		for i in range(1, 6):
			var layer := energy.get_node_or_null("EnergyVisuals/EnergyLayer%d" % i) as TextureRect
			_expect(layer != null and layer.size == Vector2(128, 128), "energy layer %d renders at 128 px" % i)
			_expect(_texture_path(layer).ends_with("/combat/energy_layer_%d.png" % i), "energy layer %d uses original 256 px art" % i)
			if layer:
				_expect(layer.pivot_offset == Vector2(64, 64), "energy layer %d rotates about the shared center" % i)
		var label := battle.ui_manager.energy_label as Label
		_expect(label.get_theme_font_size("font_size") == 36 and label.get_theme_constant("outline_size") == 16, "energy number is 36/16 above the art")
		_expect(energy.has_method("layer_rotation_speeds"), "energy exposes its current rotation rates")
		if energy.has_method("layer_rotation_speeds"):
			battle.ui_manager.update_labels(3, 3)
			_expect(energy.layer_rotation_speeds() == Vector2(30, 60), "charged energy rotates at +30/+60 degrees per second")
			energy.set_process(false)
			var layer2 := energy.get_node("EnergyVisuals/EnergyLayer2") as TextureRect
			var angle := layer2.rotation
			energy._process(0.5)
			_expect(is_equal_approx(layer2.rotation - angle, deg_to_rad(15)), "energy advances the middle layer at the specified rate")
			battle.ui_manager.update_labels(0, 3)
			_expect(energy.layer_rotation_speeds() == Vector2(5, 10), "zero energy immediately slows to +5/+10")
			_expect(energy.get_node("EnergyVisuals/EnergyLayer1").self_modulate != Color.WHITE, "zero energy immediately darkens every art layer")
			battle.ui_manager.update_labels(2, 3)
			_expect(energy.get_node("EnergyVisuals/EnergyLayer1").self_modulate == Color.WHITE, "restored energy returns the art to its full color")
			_expect(energy.get_node("EnergyVisuals/EnergyFlash").modulate.a > 0.0, "restored energy flashes independently of the count")
			battle.ui_manager.update_labels(0, 3)
			_expect(is_zero_approx(energy.get_node("EnergyVisuals/EnergyFlash").modulate.a), "zero energy immediately clears an in-flight restored flash")
		battle.ui_manager.show_pile_viewer_from_names(tr("UI_BATTLE_EXHAUST_PILE"), [], "exhaust")
		await get_tree().process_frame
		var pile_title := battle.find_child("RunDeckTitle", true, false) as Label
		var pile_grid := battle.find_child("CardGrid", true, false) as GridContainer
		_expect(pile_title != null and pile_title.global_position.y >= RUN_TOP_BAR.BAR_HEIGHT, "battle pile uses the shared page below the top bar")
		_expect(pile_grid != null and pile_grid.get_child_count() == 0, "an empty exhaust pile does not show the run deck")
		battle.ui_manager.hide_pile_viewer()

	var end_turn := battle.get_node_or_null("EndRoundButton") as Button
	_expect(end_turn != null, "battle keeps the EndRoundButton interaction")
	if end_turn:
		_expect(end_turn.position == Vector2(1604, 846) and end_turn.size == Vector2(220, 90), "end turn keeps the independent reference input rectangle")
		_expect(end_turn.get_theme_font_size("font_size") == 30 and end_turn.get_theme_constant("outline_size") == 12, "end turn native text is 30/12")
		var visuals := end_turn.get_node_or_null("ActionVisuals") as Control
		var face := end_turn.get_node_or_null("ActionVisuals/Face")
		_expect(visuals != null and _texture_path(face).ends_with("/combat/end_turn_normal.png"), "end turn uses the original normal texture through shared feedback")
		if visuals:
			var input_rect := end_turn.get_global_rect()
			end_turn.mouse_entered.emit()
			_expect(_texture_path(face).ends_with("/combat/end_turn_hover.png"), "end turn hover chooses its original state art")
			end_turn.button_down.emit()
			_expect(_texture_path(face).ends_with("/combat/end_turn_pressed.png"), "end turn press chooses its original state art")
			end_turn.button_up.emit()
			end_turn.mouse_exited.emit()
			end_turn.disabled = true
			visuals.sync_state(true)
			_expect(_texture_path(face).ends_with("/combat/end_turn_disabled.png"), "end turn disabled state chooses its original state art")
			_expect(end_turn.get_global_rect() == input_rect, "end turn feedback keeps its input rectangle fixed")
			end_turn.disabled = false
			visuals.sync_state(true)

	var exhaust := battle.get_node_or_null("ExhaustIndicator") as Button
	_expect(exhaust != null and exhaust.size == Vector2(80, 80), "exhaust has a separate 80 px input rectangle")
	if exhaust:
		var count := exhaust.get_node_or_null("PileHUD/Visuals/CountLabel") as Label
		_expect(count != null and count.get_theme_font_size("font_size") == 32 and count.get_theme_constant("outline_size") == 12, "exhaust count is 32/12")
		_expect(exhaust.position == Vector2(1725, 985), "exhaust stays beside the discard pile with its own input target")

	var host := battle.get_node("TopBarLayer/TopBar")
	host._setup()
	_expect(host.get_child_count() == 1, "battle mounts exactly one persistent shared top bar even after repeated setup")
	_expect(host.find_child("RelicShelf", true, false) != null, "battle keeps the shared relic shelf visible")
	var tutorial_canvas := CanvasLayer.new()
	tutorial_canvas.layer = 140
	battle.add_child(tutorial_canvas)
	var tips := load("uid://cc37k40gsd5x").new() as Control  # res://ui/battle/tutorial_tips.gd
	tutorial_canvas.add_child(tips)
	await get_tree().process_frame
	await get_tree().process_frame
	var tip_panel := tips.find_child("TutorialPanel", true, false) as Control
	var dim := tips.find_child("TutorialDim", true, false) as Control
	_expect(tips.get_global_rect() == Rect2(0, 132, 1920, 948), "tutorial CanvasLayer root fills the entire content area below the top bar (got %s)" % tips.get_global_rect())
	_expect(dim != null and dim.get_global_rect() == tips.get_global_rect(), "tutorial dim fills the entire content area")
	_expect(tip_panel != null and is_equal_approx(tip_panel.global_position.x, 680.0), "tutorial panel is horizontally centered at x680 (got %s)" % str(tip_panel.global_position if tip_panel else Vector2.ZERO))
	_expect(tip_panel != null and is_equal_approx(tip_panel.size.x, 560.0)
		and tip_panel.size.y >= 260.0 and tip_panel.size.y <= 300.0
		and is_equal_approx(tip_panel.get_global_rect().get_center().x, 960.0),
		"tutorial stays 560px wide and centered while its height accommodates font metrics")
	_expect(tip_panel != null and get_viewport().get_visible_rect().encloses(tip_panel.get_global_rect()), "tutorial panel is fully contained in the viewport")
	_expect(tip_panel != null and tip_panel.get_global_rect().position.y >= RUN_TOP_BAR.BAR_HEIGHT, "tutorial panel starts below the persistent top bar")
	_expect(tip_panel != null and tip_panel.get_global_rect().end.y <= 650.0, "tutorial stays in the empty upper lane above energy and hand")
	_expect(dim != null and dim.get_global_rect().position.y >= RUN_TOP_BAR.BAR_HEIGHT, "tutorial dim never paints over the top bar")
	tutorial_canvas.queue_free()
	await _test_hud_transitions_and_turn_state(battle)

	battle.queue_free()
	await get_tree().process_frame


func _test_hud_transitions_and_turn_state(battle: Node) -> void:
	var manager: Node = battle.ui_manager
	_expect(manager.has_method("anim_in") and manager.has_method("anim_out"), "outer HUD exposes bounded entrance and exit choreography")
	if not manager.has_method("anim_in") or not manager.has_method("anim_out"):
		return
	var orb := battle.get_node("EnergyDisplay") as Control
	var orb_visuals := orb.get_node_or_null("EnergyVisuals") as Control
	var pile_input := battle.deck.get_node("PileInput") as Control
	var pile_hud := pile_input.get_node("PileHUD") as Control
	var pile_visuals := pile_hud.get_node_or_null("Visuals") as Control
	var end_turn: Button = battle.end_round_button
	var fixed_orb := orb.get_global_rect()
	var fixed_pile_input := pile_input.get_global_rect()
	_expect(is_equal_approx(orb.IN_SECONDS, 0.6) and is_equal_approx(orb.OUT_SECONDS, 0.6), "energy preserves 0.6 second entry/exit timing")
	_expect(is_equal_approx(pile_hud.IN_SECONDS, 0.5) and is_equal_approx(pile_hud.OUT_SECONDS, 0.5), "piles preserve 0.5 second entry/exit timing")
	manager.anim_out()
	_expect(end_turn.disabled, "HUD exit immediately disables end turn")
	await get_tree().create_timer(0.65).timeout
	_expect(orb_visuals != null and orb_visuals.position.is_equal_approx(Vector2(-480, 128)), "energy exits to the reference local hidden position")
	_expect(pile_visuals != null and pile_visuals.position.is_equal_approx(Vector2(0, 180)), "pile art exits below its stable input rectangle")
	_expect(orb.get_global_rect() == fixed_orb and pile_input.get_global_rect() == fixed_pile_input, "HUD art transitions leave energy and pile input anchors fixed")
	_expect(end_turn.position.is_equal_approx(Vector2(1604, 1096)), "end turn exits 250 px below its normal anchor")
	_expect(battle.get_node("TopBarLayer").visible, "HUD exit preserves the persistent top bar")
	manager.anim_in()
	_expect(end_turn.disabled, "end turn stays disabled during entrance")
	await get_tree().create_timer(0.65).timeout
	_expect(orb_visuals != null and orb_visuals.position.is_equal_approx(Vector2.ZERO), "energy entrance finishes at its normal local position")
	_expect(pile_visuals != null and pile_visuals.position.is_equal_approx(Vector2.ZERO), "pile entrance finishes at its normal local position")
	_expect(end_turn.get_global_rect() == Rect2(1604, 846, 220, 90), "end turn entrance restores the reference input rectangle (got %s)" % end_turn.get_global_rect())
	_expect(end_turn.disabled == not battle._accepts_player_input(), "end turn native disabled state follows the existing combat guard")
	battle._on_end_round_button_pressed()
	await get_tree().process_frame
	_expect(not battle._accepts_player_input() and end_turn.disabled, "a real end-turn request immediately uses the disabled art state (accepts=%s disabled=%s targeting=%s ending=%s)" % [battle._accepts_player_input(), end_turn.disabled, battle.is_targeting, battle.combat._ending_turn])
	_expect(_texture_path(end_turn.get_node("ActionVisuals/Face")).ends_with("/combat/end_turn_disabled.png"), "a real turn transition selects the original disabled texture")
	battle.combat._end_combat("victory")
	manager.anim_in()
	await get_tree().create_timer(0.65).timeout
	_expect(battle.is_game_over and manager._hud_exiting and end_turn.disabled, "a late entrance cannot reopen the HUD after combat finishes")
	_expect(orb_visuals.position.is_equal_approx(Vector2(-480, 128)), "late deferred entrance preserves the completed-combat exit position")


## Completion-time add/remove/clear must update counters without a hand refresh.
func _test_pile_count_container_updates(battle: Node, draw_pile: Node, discard_pile: Node) -> void:
	var draw_count := draw_pile.get_node_or_null("CountLabel") as Label
	var discard_count := discard_pile.get_node_or_null("CountLabel") as Label
	if draw_count == null:
		draw_count = draw_pile.get_node_or_null("PileHUD/CountLabel") as Label
	if discard_count == null:
		discard_count = discard_pile.get_node_or_null("PileHUD/CountLabel") as Label
	if draw_count == null or discard_count == null or draw_pile.get_cards().is_empty():
		_expect(false, "both pile counters exist for container update checks")
		return
	var before: int = draw_pile.get_cards().size()
	var card = draw_pile.get_cards()[0]
	draw_pile.remove_card(card)
	_expect(draw_count.text == str(before - 1), "removing a draw node immediately updates its counter without a hand refresh")
	discard_pile.add_card(card)
	_expect(discard_count.text == str(discard_pile.get_cards().size()), "completion-time discard arrival immediately updates its counter")
	discard_pile.remove_card(card)
	_expect(discard_count.text == str(discard_pile.get_cards().size()), "removing a discard node immediately updates its counter")
	draw_pile.add_card(card)
	_expect(draw_count.text == str(before), "reshuffle arrival immediately restores the draw counter")
	if discard_pile.get_cards().is_empty():
		var temporary = battle.card_factory.create_card("base:strike", discard_pile)
		_expect(temporary != null and discard_count.text == "1", "newly created pile node immediately updates its counter")
		discard_pile.clear_cards()
		_expect(discard_count.text == "0", "clearing a pile immediately resets its counter")
	await get_tree().process_frame


func _test_category_intents() -> void:
	var enemy := ENEMY_ENTITY.create("base:acid_spitter")
	add_child(enemy)
	await get_tree().process_frame
	var cells := enemy.find_child("IntentCells", true, false) as HBoxContainer
	_expect(cells != null, "enemy exposes a horizontal IntentCells group")
	for status_id in ["burn", "weak", "frail", "vulnerable"]:
		enemy.action_pattern = [
			{"type": "attack_status", "amount": 4, "status": status_id, "stacks": 2}
		]
		enemy.creature.moves._action_index = 0
		enemy.update_intent_display()
		_expect(
			enemy.find_child("IntentAttack", true, false) != null,
			"attack_status shows attack intent for %s" % status_id
		)
		var debuff := enemy.find_child("IntentDebuff", true, false)
		_expect(debuff != null, "attack_status shows generic debuff intent for %s" % status_id)
		if debuff:
			var icon := debuff.find_child("Icon", true, false) as TextureRect
			_expect(
				_texture_path(icon).ends_with("/combat/intents/debuff.png"),
				"%s uses the shared generic debuff icon" % status_id
			)
		var values := enemy.find_children("IntentValue", "Label", true, false)
		for value in values:
			if value.visible:
				_expect(str(value.text).is_valid_int(), "always-visible single-hit intent labels contain numbers only")
		var visible_text := ""
		for label in enemy.find_children("*", "Label", true, false):
			visible_text += " " + str(label.text)
		var status_name := enemy.INTENTS.short_status(status_id)
		_expect(status_name not in visible_text, "%s name is hover-only" % status_id)
		_expect(
			status_name in str(enemy.get("_intent_tooltip")),
			"tooltip retains concrete %s detail" % status_id
		)
	enemy.queue_free()
	await get_tree().process_frame
