extends CardContainer
class_name CardPlayZone

const HAND_RESERVED_HEIGHT: float = 240.0
const HORIZONTAL_OVERFLOW: float = 80.0


func _ready():
	_sync_play_zone_bounds()
	super._ready()
	if get_viewport():
		get_viewport().size_changed.connect(_sync_play_zone_bounds)
	_sync_play_zone_bounds()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_play_zone_bounds()


func _sync_play_zone_bounds() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO and get_viewport():
		viewport_size = get_viewport().get_visible_rect().size

	var play_height = maxf(180.0, viewport_size.y - HAND_RESERVED_HEIGHT)
	sensor_position = Vector2(-HORIZONTAL_OVERFLOW, 0.0)
	sensor_size = Vector2(viewport_size.x + HORIZONTAL_OVERFLOW * 2.0, play_height)

	if drop_zone:
		drop_zone.set_sensor(sensor_size, sensor_position, sensor_texture, sensor_visibility)


func _card_can_be_added(cards: Array) -> bool:
	var main = get_tree().current_scene
	if main and main.has_method("can_afford"):
		return main.can_afford(cards)
	return true


# Override move_cards — this fires the moment the framework accepts the drop.
# We intercept here instead of on_card_move_done, because CardContainer
# (unlike Pile) never calls card.move() so _on_move_done never fires.
func move_cards(cards: Array, _index: int = -1, _with_history: bool = true) -> bool:
	var main = get_tree().current_scene
	for card in cards:
		if main and main.has_method("play_spell"):
			# Skill/ability → null target. Attack-with-sole-enemy → that enemy.
			# Attack-with-multiple-enemies shouldn't reach the play zone (it
			# uses the arrow flow), but if it somehow does, fall back to null
			# which play_spell handles gracefully for AoE-style effects.
			var target: Node = null
			var c_type := str(card.card_info.get("type", "skill")).to_lower()
			if c_type == "attack" and main.has_method("sole_alive_enemy"):
				target = main.sole_alive_enemy()
			main.play_spell(card, target)
	# Return true so the framework removes the card from the hand
	return true
