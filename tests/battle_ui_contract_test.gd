extends Node

## Contract for the STS2-style battle presentation on the real battle scene:
## playable outline, targeting arrow, target reticle, play-queue zone and the
## ways a played card leaves. Presentation only — rules are covered elsewhere.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const CARD_ANIMATOR = preload("uid://co0n3ou8saknv")  # res://ui/battle/card_animator.gd

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
	test_waiting_layout_formula()
	await test_three_quick_plays_line_up()
	await test_discard_flight_lands_in_the_pile()
	await test_exhaust_burns_in_place()
	await test_combat_end_drops_waiting_cards()
	await test_played_card_loses_its_outline()
	await test_end_turn_discard_lands_whole()
	await test_combat_end_hides_outlines()
	await test_flying_card_stays_readable()
	await test_exhaust_embers_are_visible()
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
		cards.append(battle.hand_view.node_of(battle.combat.add_card_to_hand("base:strike")))
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
	battle.combat._end_combat("victory")
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


func test_waiting_layout_formula() -> void:
	_expect(is_equal_approx(CARD_ANIMATOR.waiting_offset(1), 100.0), "first waiting card sits 100 px left")
	_expect(is_equal_approx(CARD_ANIMATOR.waiting_offset(2), 150.0), "second waiting card sits 150 px left")
	_expect(is_equal_approx(CARD_ANIMATOR.waiting_scale(1), 0.4), "first waiting card is at 0.4 scale")
	_expect(absf(CARD_ANIMATOR.waiting_scale(2) - 0.2667) < 0.001, "second waiting card is at about 0.267 scale")


func test_three_quick_plays_line_up() -> void:
	var battle = await _battle()
	battle.player.energy = 10
	var cards: Array = await _add_strikes(battle, 3)
	var enemy: Node = battle.enemy_container.get_child(0)
	for card in cards:
		battle.play_spell(card, enemy)
	await get_tree().create_timer(0.4).timeout
	var animator = battle.card_animator
	var first: Control = cards[0]
	_expect(first.global_position.distance_to(animator.play_position(first)) <= 2.0, "the resolving card sits at the play position (off by %.1f)" % first.global_position.distance_to(animator.play_position(first)))
	_expect(absf(first.scale.x - 0.8) <= 0.02, "the resolving card is at 0.8 scale (got %.2f)" % first.scale.x)
	for i in [1, 2]:
		var waiting: Control = cards[i]
		var expected: Vector2 = animator.play_position(waiting) - Vector2(CARD_ANIMATOR.waiting_offset(i), 0)
		_expect(waiting.global_position.distance_to(expected) <= 2.0, "waiting card %d lines up left of the play position (off by %.1f)" % [i, waiting.global_position.distance_to(expected)])
		_expect(absf(waiting.scale.x - CARD_ANIMATOR.waiting_scale(i)) <= 0.02, "waiting card %d is scaled down (got %.2f)" % [i, waiting.scale.x])
	var drained := await _wait_until(func() -> bool: return battle.discard_pile.get_card_count() >= 3, 10.0)
	_expect(drained, "all three cards end in the discard pile")
	await _free(battle)


func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func test_discard_flight_lands_in_the_pile() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	var card: Control = cards[0]
	battle.play_spell(card, battle.enemy_container.get_child(0))
	var saw_trail := await _wait_until(func() -> bool: return not battle.find_children("*", "Line2D", true, false).is_empty(), 3.0)
	_expect(saw_trail, "the discard flight draws a trail")
	var landed := await _wait_until(func() -> bool: return battle.discard_pile.has_card(card), 6.0)
	_expect(landed, "the played card lands in the discard pile")
	_expect(card.scale == Vector2.ONE and is_equal_approx(card.modulate.a, 1.0), "a landed card is reset for reuse")
	await get_tree().process_frame
	_expect(battle.find_children("*", "Line2D", true, false).is_empty(), "the trail is gone after the flight")
	await _free(battle)


func test_exhaust_burns_in_place() -> void:
	var battle = await _battle()
	var card = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:reload"))
	await get_tree().process_frame
	battle.play_spell(card, null)
	var burned := await _wait_until(func() -> bool: return not battle.find_children("*", "CPUParticles2D", true, false).is_empty(), 3.0)
	_expect(burned, "an exhausted card burns in a particle burst")
	var freed := await _wait_until(func() -> bool: return not is_instance_valid(card), 3.0)
	_expect(freed, "the exhausted card is freed")
	await get_tree().create_timer(2.2).timeout
	_expect(battle.find_children("*", "CPUParticles2D", true, false).is_empty(), "burn particles clean themselves up")
	await _free(battle)


func test_combat_end_drops_waiting_cards() -> void:
	var battle = await _battle()
	battle.player.energy = 10
	var cards: Array = await _add_strikes(battle, 3)
	for card in cards:
		battle.play_spell(card, battle.enemy_container.get_child(0))
	await get_tree().create_timer(0.1).timeout
	battle.combat._end_combat("victory")
	await get_tree().create_timer(0.8).timeout
	_expect(battle.card_animator.waiting_cards().is_empty(), "no card is left waiting after combat ends")
	_expect(battle.discard_pile.has_card(cards[1]) and battle.discard_pile.has_card(cards[2]), "dropped cards are parked in the discard pile")
	_expect(battle.discard_pile.has_card(cards[0]), "the card sliding into the play position is parked too")
	await _free(battle)


func test_played_card_loses_its_outline() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	var card: Control = cards[0]
	battle.player.energy = 3
	battle.refresh_hand_ui()
	_expect(card.highlight.is_shown(), "precondition: the card is lit in hand")
	battle.play_spell(card, battle.enemy_container.get_child(0))
	await get_tree().process_frame
	_expect(not card.highlight.is_shown(), "a played card is no longer outlined")
	await _free(battle)


func test_end_turn_discard_lands_whole() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 3)
	await battle.hand_view.animate_discard(cards.map(func(c): return c.instance))
	_expect(cards.all(func(c) -> bool: return battle.discard_pile.has_card(c)), "every discarded hand card is in the pile")
	_expect(cards.all(func(c) -> bool: return c.scale == Vector2.ONE), "hand cards join the pile only after their flight ends")
	await get_tree().process_frame  # finished trails are freed at the end of the frame
	_expect(battle.find_children("*", "Line2D", true, false).is_empty(), "no trail is left flying without its card")
	await _free(battle)


func test_combat_end_hides_outlines() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 2)
	battle.player.energy = 3
	battle.refresh_hand_ui()
	battle.combat._end_combat("victory")
	_expect(not cards.any(func(c) -> bool: return c.highlight.is_shown()), "outlines go out when combat ends")
	await _free(battle)


func test_flying_card_stays_readable() -> void:
	var battle = await _battle()
	var cards: Array = await _add_strikes(battle, 1)
	var card: Control = cards[0]
	var darkest := [1.0]
	var smallest := [1.0]
	var sampling := [true]
	var sample := func() -> void:
		while sampling[0] and is_instance_valid(card):
			if not battle.discard_pile.has_card(card):
				darkest[0] = minf(darkest[0], card.modulate.r)
				smallest[0] = minf(smallest[0], card.scale.x)
			await get_tree().process_frame
	sample.call()
	await battle.card_animator.fly_to_discard(card)
	sampling[0] = false
	_expect(darkest[0] >= 0.6, "a flying card darkens only slightly (darkest %.2f)" % darkest[0])
	_expect(smallest[0] >= 0.2, "a flying card stays big enough to read (smallest %.2f)" % smallest[0])
	await _free(battle)


func test_exhaust_embers_are_visible() -> void:
	var battle = await _battle()
	var card = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:reload"))
	await get_tree().process_frame
	battle.card_animator.burn_exhaust(card)
	var bursts: Array = battle.find_children("*", "CPUParticles2D", true, false)
	_expect(bursts.size() == 1, "one ember burst per exhausted card")
	if bursts.size() == 1:
		var burst: CPUParticles2D = bursts[0]
		_expect(burst.amount >= 60, "the burst has at least 60 embers (got %d)" % burst.amount)
		_expect(burst.scale_amount_min >= 8.0, "embers are at least 8 px (got %.1f)" % burst.scale_amount_min)
	await _free(battle)
