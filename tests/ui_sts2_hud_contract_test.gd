extends Node

const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const ENEMY_ENTITY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd

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
		if node.texture is AtlasTexture and node.texture.atlas:
			return node.texture.atlas.resource_path
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
		background_path.ends_with("/wasteland_route_map_pixel_bg.png"),
		"map uses the approved quiet 1920x1080 background (got %s)" % background_path
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
	var background := battle.get_node_or_null("BattleBackground")
	var background_path := _texture_path(background)
	_expect(
		background_path.ends_with("/wasteland_battlefield_act1_v1.png"),
		"Act 1 battle uses the refreshed comic combat-stage background (got %s)" % background_path
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
		_expect(block != null and block.visible and block.size == Vector2(42, 49), "Block has an independent compact shield")
		_expect(_texture_path(block).ends_with("/block_badge.png"), "Block uses the original combat shield art")
		_expect(block_number != null and block_number.text == "6" and block_number.get_theme_font_size("font_size") == 25 and block_number.get_theme_constant("outline_size") == 2, "Block count uses the compact shield typography")
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
		var draw_icon := draw_pile.get_node_or_null("PileIcon") as TextureRect
		var discard_icon := discard_pile.get_node_or_null("PileIcon") as TextureRect
		_expect(draw_icon != null, "draw pile builds its book icon")
		_expect(discard_icon != null, "discard pile builds its book icon")
		if draw_icon and discard_icon:
			var draw_icon_path := _texture_path(draw_icon)
			var discard_icon_path := _texture_path(discard_icon)
			_expect(
				draw_icon_path.ends_with("/iconb_deck_stack.png"),
				"draw pile uses iconb_deck_stack.png (got %s)" % draw_icon_path
			)
			_expect(
				discard_icon_path.ends_with("/iconb_deck_stack.png"),
				"discard pile uses iconb_deck_stack.png (got %s)" % discard_icon_path
			)
			_expect(draw_icon.flip_h != discard_icon.flip_h, "draw/discard book icons face opposite directions")
			_expect(draw_icon.size.x <= 96.0, "draw-pile book stays a compact icon")
			_expect(discard_icon.size.x <= 96.0, "discard-pile book stays a compact icon")

	var energy := battle.get_node_or_null("EnergyDisplay")
	_expect(energy != null, "battle builds EnergyDisplay")
	if energy:
		var frame := energy.get_node_or_null("Frame")
		var energy_path := _texture_path(frame)
		_expect(
			energy_path.ends_with("/hud_energy_badge_sts2.png"),
			"battle energy uses hud_energy_badge_sts2.png (got %s)" % energy_path
		)
		var dial := energy.get_node_or_null("EnergyChargeRing") as Control
		_expect(dial == null, "energy badge has no decorative charge ring")
		var count := energy.get_node_or_null("EnergyLabel") as Label
		_expect(count != null, "energy badge keeps its independent count")
		if frame is TextureRect:
			battle.ui_manager.update_labels(0, 3)
			_expect(frame.self_modulate != Color.WHITE, "zero energy dims the badge")
			_expect(count != null and count.text == "0/3", "zero energy keeps the correct readable count")
			battle.ui_manager.update_labels(2, 3)
			_expect(frame.self_modulate == Color.WHITE, "gaining energy restores the badge")
			_expect(count != null and count.text == "2/3", "gaining energy updates the count")
			_expect(energy.scale.x > 1.0, "energy changes retain the existing scale feedback")
		battle.ui_manager.show_pile_viewer_from_names(tr("UI_BATTLE_EXHAUST_PILE"), [], "exhaust")
		var pile_title := battle.find_child("RunDeckTitle", true, false) as Label
		var pile_grid := battle.find_child("CardGrid", true, false) as GridContainer
		await get_tree().process_frame
		_expect(pile_title != null and pile_title.global_position.y >= RUN_TOP_BAR.BAR_HEIGHT,
			"battle pile uses the shared page below the top bar")
		_expect(pile_grid != null and pile_grid.get_child_count() == 0,
			"an empty exhaust pile does not show the run deck")
		battle.ui_manager.hide_pile_viewer()

	var end_turn := battle.get_node_or_null("EndRoundButton") as Button
	_expect(end_turn != null, "battle keeps the EndRoundButton interaction")
	if end_turn:
		_expect(end_turn.size == Vector2(220, 90), "EndRoundButton keeps the approved 220x90 input rectangle")
		var visuals := end_turn.get_node_or_null("ActionVisuals") as Control
		var face := end_turn.get_node_or_null("ActionVisuals/Face") as NinePatchRect
		var style_path := face.texture.resource_path if face != null and face.texture != null else ""
		_expect(visuals != null and visuals.get("role") == "end_turn"
			and style_path.ends_with("/combat/end_turn_normal.png"),
			"EndRoundButton keeps the original end-turn art state")

	battle.queue_free()
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
