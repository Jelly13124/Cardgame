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
## Where a flying card lands, relative to the discard pile node.
const DISCARD_GLYPH_OFFSET := Vector2(80, 110)
## Positions kept in a discard flight's trail.
const TRAIL_POINTS := 12
## A flying card dims to this brightness and shrinks to this scale (it stays
## readable rather than turning into a black speck).
const FLIGHT_MIN_SHADE := 0.65
const FLIGHT_END_SCALE := 0.25

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
	# Out of the hand it is no longer "playable": drop the outline at once.
	var highlight = card.get("highlight")
	if highlight:
		highlight.anim_hide_instantly()


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


# ─── Leaving the play zone (STS2 NCardFlyVfx / NExhaustVfx) ───────────────────


## Arc into the discard pile: a randomized quadratic arc that speeds up, the
## card turning along its path, dimming slightly and shrinking over the first
## third, with a fading trail. Resets the card for reuse in the pile on arrival.
func fly_to_discard(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var discard_pile = _scene.discard_pile
	if not is_instance_valid(discard_pile):
		return
	card.z_index = 90
	var start: Vector2 = card.global_position + card.pivot_offset
	var end: Vector2 = discard_pile.global_position + DISCARD_GLYPH_OFFSET
	var control: Vector2 = (start + end) * 0.5
	control.y -= 500.0 + randf_range(100.0, 400.0)
	var duration := randf_range(1.0, 1.75)
	var speed := randf_range(1.1, 1.25)
	var accel := randf_range(2.0, 2.5)
	var start_scale := card.scale.x
	var trail := _make_trail()
	AudioManager.play_sfx("card_draw", -4.0, 1.35)

	var time := 0.0
	while time / duration <= 1.0 and is_inside_tree():
		await get_tree().process_frame
		if not is_instance_valid(card):
			break
		var delta := get_process_delta_time()
		time += speed * delta
		speed += accel * delta
		var at := _quadratic(start, control, end, minf(time / duration, 1.0))
		var ahead := _quadratic(start, control, end, minf((time + 0.05) / duration, 1.0))
		card.global_position = at - card.pivot_offset
		if ahead != at:
			card.rotation = lerp_angle(card.rotation, (ahead - at).angle() + PI * 0.5, delta * 12.0)
		var fade := clampf(time * 3.0 / duration, 0.0, 1.0)
		var shade := lerpf(1.0, FLIGHT_MIN_SHADE, fade)
		card.modulate = Color(shade, shade, shade, 1.0)
		card.scale = Vector2.ONE * lerpf(start_scale, FLIGHT_END_SCALE, fade)
		trail.add_point(at)
		while trail.get_point_count() > TRAIL_POINTS:
			trail.remove_point(0)
		trail.modulate.a = 1.0 - clampf(time / duration, 0.0, 1.0) * 0.6
	trail.queue_free()
	_reset_for_pile(card)


## Exhaust: the card burns where it stands in a one-shot ember burst and fades;
## the burst frees itself after 2 s. Caller frees the card afterwards.
func burn_exhaust(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var burst := _make_burn_burst()
	burst.global_position = card.global_position + card.pivot_offset
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(
		func() -> void:
			if is_instance_valid(burst):
				burst.queue_free()
	)
	AudioManager.play_sfx("card_play_power", -2.0, 0.7)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 0.0, 0.4)
	await tween.finished


## A card dropped from the queue (combat ended): it sinks and fades. The caller
## parks it in the discard pile afterwards.
func drop_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "global_position:y", card.global_position.y + 30.0, 0.5).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	await tween.finished
	_reset_for_pile(card)


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


# ─── Helpers ──────────────────────────────────────────────────────────────────


## Back to a normal, interactive card for the pile it is about to join.
func _reset_for_pile(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.scale = Vector2.ONE
	card.rotation = 0.0
	card.z_index = 0
	card.modulate = Color.WHITE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if "can_be_interacted_with" in card:
		card.can_be_interacted_with = true


func _make_trail() -> Line2D:
	var trail := Line2D.new()
	trail.name = "CardTrail"
	trail.width = 18.0
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(1.0, 1.0))
	trail.width_curve = taper
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.94, 0.8, 0.0))
	fade.set_color(1, Color(1.0, 0.94, 0.8, 0.75))
	trail.gradient = fade
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.z_index = 85
	_scene.add_child(trail)
	return trail


func _make_burn_burst() -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.name = "ExhaustBurst"
	burst.one_shot = true
	burst.amount = 70
	burst.lifetime = 1.0
	burst.explosiveness = 0.85
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = Vector2(70.0, 90.0)
	burst.direction = Vector2.UP
	burst.spread = 80.0
	burst.initial_velocity_min = 160.0
	burst.initial_velocity_max = 340.0
	burst.gravity = Vector2(0.0, -40.0)
	burst.scale_amount_min = 8.0
	burst.scale_amount_max = 14.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.38, 1.0))
	ramp.add_point(0.45, Color(1.0, 0.5, 0.15, 0.95))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.42, 0.4, 0.38, 0.0))
	burst.color_ramp = ramp
	burst.z_index = 95
	_scene.add_child(burst)
	return burst


static func _quadratic(p0: Vector2, control: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * control + t * t * p1
