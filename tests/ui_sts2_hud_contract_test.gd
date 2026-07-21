extends Node

const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")
const ENEMY_ENTITY = preload("res://battle_scene/enemy_entity.gd")

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
	var settings_button: Button = null
	for candidate in bar.find_children("*", "Button", true, false):
		if (candidate as Button).tooltip_text == tr("SETTINGS_BUTTON"):
			settings_button = candidate as Button
			break
	_expect(settings_button != null, "battle top bar keeps the settings interaction")
	if settings_button:
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
		_expect(player_hud.bar_width == 200, "player uses the compact 200 px smooth bar")
		_expect(player_hud.bar_height == 10, "player uses one frameless 10 px trough around a thin core")
		player_hud.update_stats(63, 100, 6)
		var simple_frame := player_hud.get_node_or_null("HpFrame") as Control
		var simple_bar := player_hud.get_node_or_null("HpFrame/HpBar") as Control
		var simple_label := player_hud.get_node_or_null("HpFrame/HpLabel") as Control
		var block_badge := player_hud.get_node_or_null("BlockBadge") as TextureRect
		var block_label := player_hud.get_node_or_null("BlockBadge/BlockLabel") as Label
		_expect(simple_frame != null, "health exposes one compact frame")
		_expect(simple_bar != null, "health builds the rounded real-HP fill")
		if simple_bar:
			_expect(simple_bar.size == Vector2(200.0, 10.0), "health fill matches the frameless inset trough")
			_expect(is_equal_approx(float(simple_bar.get("ratio")), 1.0), "Block hides the empty HP segment")
			_expect(simple_bar.get("fill_color") == Color("#3f8fb6"), "shielded health uses the inset blue core")
			_expect(simple_bar.get("edge_color") == Color("#91d5ed"), "shielded health uses a blue core highlight")
			_expect(simple_bar.get("track_color") == Color("#131a16"), "health uses one recessed dark-olive trough")
		_expect(
			simple_label != null
			and str(simple_label.get("text")) == "63/100"
			and is_equal_approx(simple_label.size.x, 200.0)
			and simple_label.size.y == 34.0,
			"health text stays centered over the rounded bar"
		)
		_expect(
			simple_label != null
			and int(simple_label.get("font_size")) == 26
			and simple_label.size.y == 34.0,
			"health text scales with the compact bar (actual size %s)"
			% str(simple_label.size if simple_label else Vector2.ZERO)
		)
		_expect(simple_label != null and simple_label.position.y == -12.0, "health number is vertically centered over the thin core")
		_expect(
			simple_label != null
			and simple_label.get("font_color") == Color("#fff8e8")
			and simple_label.get("outline_color") == Color("#071018"),
			"health number uses an STS-like warm white fill with a strong ink outline"
		)
		_expect(block_badge != null and block_badge.visible, "Block restores the original shield icon")
		_expect(
			block_badge != null and block_badge.size == Vector2(42.0, 49.0),
			"Block shield scales down with the compact health HUD (got %s)"
			% str(block_badge.size if block_badge else Vector2.ZERO)
		)
		var badge_atlas := block_badge.texture as AtlasTexture if block_badge else null
		_expect(
			badge_atlas != null
			and badge_atlas.atlas.resource_path.ends_with("/block_badge.png")
			and badge_atlas.region == Rect2(9, 5, 46, 54),
			"Block uses the original block_badge.png resource"
		)
		_expect(block_label != null and block_label.text == "6", "Block value is centered inside the shield")
		_expect(player_hud.get_node_or_null("HpFrame/ShieldBarOverlay") == null, "plain HUD has no shield overlay bar")
		player_hud.update_stats(63, 100, 0)
		_expect(block_badge != null and not block_badge.visible, "Block shield hides at zero")
		_expect(
			simple_bar != null
			and is_equal_approx(float(simple_bar.get("ratio")), 0.63)
			and simple_bar.get("fill_color") == Color("#c73a25")
			and simple_bar.get("edge_color") == Color("#ef7047")
			and simple_bar.get("fill_shadow_color") == Color("#5f100c"),
			"real layered red HP returns with zero Block"
		)
	var normal_enemy := ENEMY_ENTITY.create("trash_robot")
	var elite_enemy := ENEMY_ENTITY.create("armored_patrol")
	var boss_enemy := ENEMY_ENTITY.create("rust_titan")
	_expect(not normal_enemy.is_elite and not normal_enemy.is_boss, "normal factory classification")
	_expect(elite_enemy.is_elite and not elite_enemy.is_boss, "elite factory classification")
	_expect(boss_enemy.is_boss and not boss_enemy.is_elite, "boss factory classification")
	_expect(normal_enemy._health_bar_size() == Vector2i(200, 10), "normal enemies match the player 200x10 bar")
	_expect(elite_enemy._health_bar_size() == Vector2i(200, 10), "elites match the player 200x10 bar")
	_expect(boss_enemy._health_bar_size() == Vector2i(200, 10), "bosses match the player 200x10 bar")
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
			style_path.ends_with("/hud_end_turn_orange.png"),
			"EndRoundButton uses the high-contrast orange plate (got %s)" % style_path
		)

	battle.queue_free()
	await get_tree().process_frame


func _test_category_intents() -> void:
	var enemy := ENEMY_ENTITY.create("acid_spitter")
	add_child(enemy)
	await get_tree().process_frame
	var cells := enemy.find_child("IntentCells", true, false) as HBoxContainer
	_expect(cells != null, "enemy exposes a horizontal IntentCells group")
	for status_id in ["burn", "weak", "frail", "vulnerable"]:
		enemy.action_pattern = [
			{"type": "attack_status", "amount": 4, "status": status_id, "stacks": 2}
		]
		enemy._action_index = 0
		enemy.update_intent_display()
		_expect(
			enemy.find_child("IntentAttack", true, false) != null,
			"attack_status shows attack intent for %s" % status_id
		)
		var debuff := enemy.find_child("IntentDebuff", true, false)
		_expect(debuff != null, "attack_status shows generic debuff intent for %s" % status_id)
		if debuff:
			var icon := debuff.get_node_or_null("Icon") as TextureRect
			_expect(
				_texture_path(icon).ends_with("/intent_debuff.png"),
				"%s uses the shared generic debuff icon" % status_id
			)
		var values := enemy.find_children("IntentValue", "Label", true, false)
		for value in values:
			_expect(str(value.text).is_valid_int(), "always-visible intent labels contain numbers only")
		var visible_text := ""
		for label in enemy.find_children("*", "Label", true, false):
			visible_text += " " + str(label.text)
		var status_name := enemy._localized_status_short(status_id)
		_expect(status_name not in visible_text, "%s name is hover-only" % status_id)
		_expect(
			status_name in str(enemy.get("_intent_tooltip")),
			"tooltip retains concrete %s detail" % status_id
		)
	enemy.queue_free()
	await get_tree().process_frame
