## CardAnimator owns the play-queue zone and the discard / exhaust tweens for
## played cards.
## Lives as a child Node of BattleScene; constructed in BattleScene._ready().
## All tweens are created on this Node so they live with the battle scene
## lifecycle.
##
## Reads scene state (player, discard_pile) through `_scene.X`.
extends Node
class_name CardAnimator

## Scale of the card at the play position.
const PLAY_SCALE := 0.8

var _scene: Node
## Played cards waiting for their turn in the action queue, oldest first.
var _waiting: Array = []
var _tweens: Dictionary = {}


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


# ─── Play-queue zone (STS2 NCardPlayQueue) ────────────────────────────────────


## The card resolving now sits at the play position; cards waiting behind it
## line up to its left, smaller the further back they are.
func play_position(card: Control) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.40) - card.size * 0.5


## Leftward offset of the i-th waiting card (i from 1).
static func waiting_offset(i: int) -> float:
	return 300.0 * float(i) / float(i + 2)


## Scale of the i-th waiting card (i from 1).
static func waiting_scale(i: int) -> float:
	return 0.8 * (1.0 - float(i) / float(i + 1))


## A played card joins the waiting line (it resolves when the action queue
## reaches it).
func enqueue_card(card: Control) -> void:
	if is_instance_valid(card):
		_waiting.append(card)
	_layout_waiting()


## The queue reached `card`: it moves to the play position and the line closes up.
func begin_resolving(card: Control) -> void:
	_waiting.erase(card)
	_layout_waiting()
	if not is_instance_valid(card):
		return
	await _tween_card(card, play_position(card), PLAY_SCALE, 0.2).finished


func waiting_cards() -> Array:
	return _waiting.duplicate()


## Remove every waiting card from the line (combat ended) and return them.
func drop_waiting() -> Array:
	var dropped := _waiting.duplicate()
	_waiting.clear()
	return dropped


func _layout_waiting() -> void:
	_waiting = _waiting.filter(func(c) -> bool: return is_instance_valid(c))
	for index in range(_waiting.size()):
		var i := index + 1
		var card: Control = _waiting[index]
		_tween_card(card, play_position(card) - Vector2(waiting_offset(i), 0.0), waiting_scale(i), 0.35)


func _tween_card(card: Control, at: Vector2, card_scale: float, seconds: float) -> Tween:
	var previous: Tween = _tweens.get(card)
	if previous and previous.is_valid():
		previous.kill()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "global_position", at, seconds).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	tween.tween_property(card, "scale", Vector2.ONE * card_scale, seconds).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "rotation", 0.0, seconds).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	tween.tween_property(card, "modulate:a", 1.0, seconds)
	_tweens[card] = tween
	tween.finished.connect(func() -> void: _tweens.erase(card))
	return tween


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
