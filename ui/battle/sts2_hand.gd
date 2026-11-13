extends "res://ui/battle/card_framework_adapters/no_reorder_hand.gd"

## The battle hand laid out like STS2 (HandPosHelper, NPlayerHand.RefreshLayout).
## The anchor is the hand's bottom centre, at the screen's bottom edge. Each
## card's centre sits at STS2's per-hand-size offset from the anchor in STS2's
## pixels, turned by STS2's angle, at STS2's rest scale of its 300 px card,
## so most of each card hides below the screen. The hovered card snaps to full
## size, upright, with its whole face showing; its neighbours make way. Held
## (dragged) cards are left where the mouse has them.

## Our 208 px card face is drawn at STS2's 300 px card width, so cards take the
## same room on screen as STS2's.
const FACE_SCALE := 300.0 / 208.0
const BASE_SCALE := 0.8
## STS2 HandPosHelper._cardPositionData: card centres from the anchor, by hand size.
const POSITIONS := [
	[Vector2(0, -50)],
	[Vector2(-100, -50), Vector2(100, -50)],
	[Vector2(-180, -50), Vector2(0, -59), Vector2(180, -50)],
	[Vector2(-240, -25), Vector2(-80, -50), Vector2(80, -50), Vector2(240, -25)],
	[Vector2(-340, 10), Vector2(-170, -30), Vector2(0, -50), Vector2(170, -30), Vector2(340, 10)],
	[Vector2(-460, 13), Vector2(-273, -25), Vector2(-90, -50), Vector2(90, -50), Vector2(273, -25), Vector2(460, 13)],
	[Vector2(-534, 18), Vector2(-365, -14), Vector2(-189, -39), Vector2(0, -50), Vector2(189, -39), Vector2(365, -14), Vector2(534, 18)],
	[Vector2(-565, 28), Vector2(-400, -14), Vector2(-231, -39), Vector2(-80, -50), Vector2(80, -50), Vector2(231, -39), Vector2(400, -14), Vector2(565, 28)],
	[Vector2(-600, 37), Vector2(-445, -2), Vector2(-300, -29), Vector2(-150, -45), Vector2(0, -50), Vector2(150, -45), Vector2(300, -29), Vector2(445, -2), Vector2(600, 37)],
	[Vector2(-610, 38), Vector2(-472, 5), Vector2(-340, -21), Vector2(-200, -41), Vector2(-64, -50), Vector2(64, -50), Vector2(200, -41), Vector2(340, -21), Vector2(472, 5), Vector2(610, 38)],
]
## STS2 HandPosHelper._cardAngleData, in degrees.
const ANGLES := [
	[0.0],
	[-2.0, 2.0],
	[-3.0, 0.0, 3.0],
	[-8.0, -4.0, 4.0, 8.0],
	[-8.0, -4.0, 0.0, 4.0, 8.0],
	[-9.0, -6.0, -3.0, 3.0, 6.0, 9.0],
	[-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0],
	[-12.0, -9.0, -6.0, -3.0, 3.0, 6.0, 9.0, 12.0],
	[-12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0],
	[-15.0, -12.0, -9.0, -6.0, -3.0, 3.0, 6.0, 9.0, 12.0, 15.0],
]
## NPlayerHand: a hovered card pushes neighbours up to 100 px,
## falling off over 4 cards.
const HOVER_PUSH := 100.0
const HOVER_PUSH_FALLOFF := 4.0

var _hovered: Card = null
var _targets: Dictionary = {}


## STS2's slot for card `index` of a `hand_size` hand: {position (centre offset
## from the anchor), angle_deg, scale (of our card face)}.
static func slot(hand_size: int, index: int) -> Dictionary:
	var n := clampi(hand_size, 1, POSITIONS.size())
	var i := clampi(index, 0, n - 1)
	var factor := 1.0
	match hand_size:
		8:
			factor = 0.95
		9:
			factor = 0.9
		10:
			factor = 0.85
	return {
		"position": POSITIONS[n - 1][i],
		"angle_deg": float(ANGLES[n - 1][i]),
		"scale": BASE_SCALE * factor * FACE_SCALE,
	}


## The hand's bottom centre in global coordinates.
func anchor_point() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y)


## The last layout target of `card`: {center, angle_deg, scale}, or {}.
func target_of(card: Node) -> Dictionary:
	return _targets.get(card, {})


func set_hovered(card: Node) -> void:
	_hovered = card
	_update_target_positions()


func clear_hovered(card: Node) -> void:
	if _hovered == card:
		_hovered = null
		_update_target_positions()


## A card leaving the hand stops its pending move back to its slot (so the play
## or discard animation that takes over is not overwritten) and drops the hand's
## rest scale and angle.
func remove_card(card: Card) -> bool:
	var removed := super.remove_card(card)
	if removed and is_instance_valid(card):
		if card.move_tween and card.move_tween.is_valid():
			card.move_tween.kill()
		card.move_tween = null
		card.is_moving_to_destination = false
		if card.current_state == card.DraggableState.MOVING:
			card.change_state(card.DraggableState.IDLE)
		card.original_scale = Vector2.ONE
		card.original_hover_rotation = 0.0
		if _hovered == card:
			_hovered = null
	return removed


func _update_target_positions() -> void:
	if _hovered != null and not _held_cards.has(_hovered):
		_hovered = null
	_targets.clear()
	var count := _held_cards.size()
	var anchor := anchor_point()
	var focus := _held_cards.find(_hovered) if _hovered != null else -1
	var partitions: Array = []
	var rect := Rect2()
	for i in count:
		var card: Card = _held_cards[i]
		var s := slot(count, i)
		var rest_center: Vector2 = anchor + s.position
		var center := rest_center
		var angle: float = s.angle_deg
		var card_scale: float = s.scale
		if focus > -1:
			center.x -= signf(float(focus - i)) * lerpf(HOVER_PUSH, 0.0, minf(1.0, absf(focus - i) / HOVER_PUSH_FALLOFF))
		if i == focus:
			angle = 0.0
			card_scale = FACE_SCALE
			center.y = anchor.y - card.size.y * FACE_SCALE * 0.5 + 2.0
		_targets[card] = {"center": center, "angle_deg": angle, "scale": card_scale}
		partitions.append(center.x)
		var half: Vector2 = card.size * card_scale * 0.5
		var card_rect := Rect2(center - half, half * 2.0)
		rect = card_rect if i == 0 else rect.merge(card_rect)
		card.visible = true
		card.show_front = card_face_up
		card.can_be_interacted_with = true
		if card.current_state == card.DraggableState.HOLDING:
			continue
		var top_left: Vector2 = center - card.size * 0.5
		if i == focus:
			# STS2 snaps the hovered card's scale, angle and height at once.
			card.scale = Vector2.ONE * card_scale
			card.rotation = 0.0
			card.global_position = top_left
			card.current_hover_position = card.position
			# Dropped on nothing, the card goes back to its rest slot.
			card.original_destination = rest_center - card.size * 0.5
			card.original_rotation = deg_to_rad(s.angle_deg)
			continue
		card.original_scale = Vector2.ONE * card_scale
		card.original_hover_rotation = deg_to_rad(angle)
		card.move(top_left, deg_to_rad(angle))
	vertical_partitions_from_outside = partitions
	vertical_partitions_from_inside.clear()
	for j in range(partitions.size() - 1):
		vertical_partitions_from_inside.append((partitions[j] + partitions[j + 1]) / 2.0)
	if align_drop_zone_size_with_current_hand_size:
		if count == 0:
			drop_zone.return_sensor_size()
		else:
			drop_zone.set_sensor_size_flexibly(rect.size, rect.position - global_position)
		drop_zone.set_vertical_partitions(vertical_partitions_from_outside)
