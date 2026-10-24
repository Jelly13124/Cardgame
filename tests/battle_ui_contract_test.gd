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
