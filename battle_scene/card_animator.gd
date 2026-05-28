## CardAnimator owns the play-area / discard / exhaust tweens for played cards.
## Lives as a child Node of BattleScene; constructed in BattleScene._ready().
## All tweens are created on this Node so they live with the battle scene
## lifecycle.
##
## Reads scene state (player, discard_pile) through `_scene.X`.
extends Node
class_name CardAnimator

var _scene: Node


func setup(scene: Node) -> void:
	_scene = scene


## Lock down a card so it stops accepting input while the play animation runs.
func prepare_for_play(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.z_index = 90
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = card.size / 2.0
	if "can_be_interacted_with" in card:
		card.can_be_interacted_with = false


## Fly a card to the centre of the play area between player and target.
func fly_to_play_area(card: Control, target_node: Node) -> void:
	if not is_instance_valid(card):
		return

	var target_pos = _get_play_area_card_position(card, target_node)
	var tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(card, "global_position", target_pos, 0.20)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(card, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	(
		tween
		. tween_property(card, "scale", Vector2(0.92, 0.92), 0.20)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(card, "modulate:a", 1.0, 0.12)
	await tween.finished

	if not is_instance_valid(card):
		return
	var settle = create_tween()
	(
		settle
		. tween_property(card, "scale", Vector2(1.0, 1.0), 0.06)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		settle
		. tween_property(card, "scale", Vector2(0.92, 0.92), 0.08)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	await settle.finished


## Fly the card to the discard pile with a short spin and shrink.
func fly_to_discard(card: Control) -> void:
	if not is_instance_valid(card):
		return

	var discard_pile = _scene.discard_pile
	if not is_instance_valid(discard_pile):
		return
	var target_pos: Vector2 = discard_pile.global_position + Vector2(80, 110)
	card.z_index = 90

	var tween = create_tween().set_parallel(true)
	var spin_dir = 1.0 if target_pos.x >= card.global_position.x else -1.0
	(
		tween
		. tween_property(card, "global_position", target_pos, 0.34)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. tween_property(card, "rotation", card.rotation + spin_dir * TAU * 0.72, 0.34)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. tween_property(card, "scale", Vector2(0.32, 0.32), 0.34)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(card, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await tween.finished

	# Reset state so the card is reusable inside the discard pile container.
	card.scale = Vector2.ONE
	card.rotation = 0.0
	card.z_index = 0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if "can_be_interacted_with" in card:
		card.can_be_interacted_with = true


## Reshuffle visual: fly a card from its current (discard pile) position to
## the deck. Caller is expected to add the card to the deck container after
## this returns. The card is shown face-down with a half spin to read as a
## "shuffled back in" motion.
func fly_to_deck(card: Control, start_pos: Vector2) -> void:
	if not is_instance_valid(card):
		return
	var deck = _scene.deck
	if not is_instance_valid(deck):
		return

	var target_pos: Vector2 = deck.global_position + Vector2(80, 110)
	card.global_position = start_pos
	card.visible = true
	card.modulate.a = 1.0
	card.scale = Vector2(0.5, 0.5)
	card.rotation = 0.0
	card.z_index = 80
	if "show_front" in card:
		card.show_front = false

	var tween = create_tween().set_parallel(true)
	var spin_dir = 1.0 if target_pos.x <= card.global_position.x else -1.0
	(
		tween
		. tween_property(card, "global_position", target_pos, 0.32)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(card, "rotation", spin_dir * TAU * 0.5, 0.32)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(card, "scale", Vector2(0.32, 0.32), 0.32)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	await tween.finished

	# Reset state so the card is reusable inside the deck container.
	card.scale = Vector2.ONE
	card.rotation = 0.0
	card.z_index = 0


## Fly an exhausted card upward and fade it out. Caller is expected to
## queue_free() the card after this returns.
func fly_to_exhaust(card: Control) -> void:
	if not is_instance_valid(card):
		return

	card.z_index = 90
	var rise_target = card.global_position + Vector2(0, -160)
	var tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(card, "global_position", rise_target, 0.45)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(card, "rotation", card.rotation + TAU * 0.5, 0.45)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(card, "scale", Vector2(0.5, 0.5), 0.45)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. tween_property(card, "modulate", Color(1.4, 1.4, 1.7, 0.0), 0.45)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	if _scene.has_method("show_notification"):
		_scene.show_notification("EXHAUSTED", Color(0.7, 0.7, 1.0))
	await tween.finished


# ─── Internal ─────────────────────────────────────────────────────────────────


func _get_play_area_card_position(card: Control, target_node: Node) -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var card_half = card.size * 0.5
	var play_center = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.48)

	var player_node = _scene.player
	if (
		target_node
		and is_instance_valid(target_node)
		and player_node
		and is_instance_valid(player_node)
	):
		play_center = player_node.global_position.lerp(target_node.global_position, 0.48)
		play_center.y -= card.size.y * 0.12

	var pos = play_center - card_half
	var max_x = maxf(24.0, viewport_size.x - card.size.x - 24.0)
	var max_y = maxf(80.0, viewport_size.y - card.size.y - 150.0)
	pos.x = clampf(pos.x, 24.0, max_x)
	pos.y = clampf(pos.y, 80.0, max_y)
	return pos
