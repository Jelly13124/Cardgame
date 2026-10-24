extends Node

## Contract for the STS2-style battle presentation on the real battle scene:
## playable outline, targeting arrow, target reticle, play-queue zone and the
## ways a played card leaves. Presentation only — rules are covered elsewhere.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	await test_outline_follows_playability()
	await test_outline_is_not_a_hover_toggle()
	await test_arrow_is_segmented_and_hides_the_cursor()
	await test_cursor_returns_when_combat_ends_mid_aim()
	await test_hover_shows_reticle_without_changing_the_enemy()
	await test_freed_hover_target_resets_arrow()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if failures.is_empty():
		print("[OK] battle UI contract passed")
		get_tree().quit(0)
		return
	push_error("battle UI contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _battle() -> Node:
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)  # cards read get_tree().current_scene
	get_tree().current_scene = battle
	for _i in range(4):
		await get_tree().process_frame
	for enemy in battle.enemy_container.get_children():
		enemy.health = 999
		enemy.max_health = 999
	return battle


func _free(battle: Node) -> void:
	get_tree().current_scene = self if self.get_parent() == get_tree().root else null
	battle.queue_free()
	await get_tree().process_frame


func _add_strikes(battle: Node, count: int) -> Array:
	var cards: Array = []
	for _i in range(count):
		cards.append(battle.deck_manager.add_card_to_hand("strike"))
	await get_tree().process_frame
	return cards


func test_outline_follows_playability() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 2)
	battle.player.energy = 3
	battle.refresh_hand_ui()
	_expect(cards.all(func(c) -> bool: return c.highlight.is_shown()), "affordable hand cards show the outline")
	battle.player.energy = 0
	battle.refresh_hand_ui()
	_expect(not cards.any(func(c) -> bool: return c.highlight.is_shown()), "unaffordable hand cards hide the outline")
	battle.player.energy = 3
	battle.refresh_hand_ui()
	_expect(cards.all(func(c) -> bool: return c.highlight.is_shown()), "the outline returns when energy does")
	battle._on_end_round_button_pressed()
	await get_tree().process_frame
	_expect(not cards.any(func(c) -> bool: return is_instance_valid(c) and c.highlight.is_shown()), "End Turn hides every outline")
	await _free(battle)


func test_outline_is_not_a_hover_toggle() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	battle.player.energy = 0
	battle.refresh_hand_ui()
	cards[0]._on_mouse_entered()
	_expect(not cards[0].highlight.is_shown(), "hovering an unplayable card does not light the outline")
	_expect(battle.find_child("PlayableGlow", true, false) == null, "the old rectangular PlayableGlow is gone")
	cards[0]._on_mouse_exited()
	await _free(battle)


func test_arrow_is_segmented_and_hides_the_cursor() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	battle.start_spell_targeting(cards[0])
	await get_tree().process_frame
	var arrow = battle.targeting_arrow
	_expect(arrow != null, "targeting creates the arrow")
	if arrow:
		_expect(arrow.segment_positions().size() == 19, "arrow has 19 segments (got %d)" % arrow.segment_positions().size())
		_expect(arrow.current_color() == Color.WHITE, "idle arrow is white")
		# Headless Godot ignores mouse_mode, so check the arrow's own claim on it.
		_expect(arrow.cursor_hidden, "the cursor hides while aiming")
		arrow.set_target_valid(true)
		_expect(arrow.current_color() == arrow.ENEMY_COLOR, "arrow turns enemy red over a target")
	battle._cancel_spell_targeting()
	_expect(arrow == null or not arrow.cursor_hidden, "the arrow releases the cursor on cancel")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the cursor returns when aiming is cancelled")
	_expect(battle.targeting_arrow == null, "cancel removes the arrow")
	await _free(battle)


func test_cursor_returns_when_combat_ends_mid_aim() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	battle.start_spell_targeting(cards[0])
	await get_tree().process_frame
	var arrow = battle.targeting_arrow
	battle._victory()
	_expect(arrow == null or not is_instance_valid(arrow) or not arrow.cursor_hidden, "the arrow releases the cursor when combat ends")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the cursor returns when combat ends mid-aim")
	await _free(battle)


func test_hover_shows_reticle_without_changing_the_enemy() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	var enemy: Node = battle.enemy_container.get_child(0)
	battle.start_spell_targeting(cards[0])
	await get_tree().process_frame
	battle._set_hover_effect(enemy, true)
	await get_tree().create_timer(0.3).timeout
	_expect(enemy.reticle_shown(), "hovering a target shows its reticle")
	_expect(enemy.scale == Vector2.ONE, "the enemy is not scaled on hover (got %s)" % enemy.scale)
	_expect(enemy.modulate == Color.WHITE, "the enemy is not tinted on hover (got %s)" % enemy.modulate)
	battle._set_hover_effect(enemy, false)
	_expect(not enemy.reticle_shown(), "leaving the target hides its reticle")
	battle._cancel_spell_targeting()
	await _free(battle)


func test_freed_hover_target_resets_arrow() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	var enemy: Node = battle.enemy_container.get_child(0)
	battle.start_spell_targeting(cards[0])
	await get_tree().process_frame
	battle.hovered_unit = enemy
	battle._set_hover_effect(enemy, true)
	battle.targeting_arrow.set_target_valid(true)
	enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(battle.hovered_unit == null, "a freed hover target is dropped")
	_expect(battle.targeting_arrow.current_color() == Color.WHITE, "the arrow returns to white when its target is gone")
	battle._cancel_spell_targeting()
	await _free(battle)
