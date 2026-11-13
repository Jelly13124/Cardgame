extends Node

## Creatures are placed with STS2's algorithm (NCombatRoom.PositionEnemies and
## the single-player branch of PositionPlayersAndPets): each side centred in its
## half of the 1920x1080 scene, at least 150 px from the centre, 70 px between
## enemies, feet at y 740; both sides shrink when the rightmost enemy would
## leave the screen. A spawned enemy re-lays out the field.

const MONSTERS = preload("uid://dvu3etytjqum8")  # res://core/combat/monsters.gd
const LAYOUT = preload("uid://bnx6w7s37vqt7")  # res://ui/battle/sts2_creature_layout.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _living_views(battle) -> Array:
	var out: Array = []
	for v in battle.enemy_container.get_children():
		if not v.is_queued_for_deletion():
			out.append(v)
	return out


func _check_field(battle, label: String) -> void:
	var views := _living_views(battle)
	var widths: Array = []
	for v in views:
		widths.append(v._display_size.x)
	var want: Dictionary = LAYOUT.arrange(battle.player.TARGET_DISPLAY_HEIGHT, widths)
	_expect(battle.player.global_position.is_equal_approx(want.player), "%s: the hero at STS2's spot (%s vs %s)" % [label, battle.player.global_position, want.player])
	for i in views.size():
		var g: Vector2 = views[i].global_position
		_expect(g.is_equal_approx(want.enemies[i]), "%s: enemy %d at STS2's spot (%s vs %s)" % [label, i, g, want.enemies[i]])


func _run() -> void:
	# STS2's numbers, worked by hand.
	_expect(LAYOUT.player_position(256.0).is_equal_approx(Vector2(-480, 200)), "one hero: centred in the left half (%s)" % LAYOUT.player_position(256.0))
	var one: Array = LAYOUT.enemy_positions([256.0])
	_expect(one[0].is_equal_approx(Vector2(480, 200)), "one enemy: centred in the right half (%s)" % [one])
	var two: Array = LAYOUT.enemy_positions([256.0, 256.0])
	_expect(two[0].is_equal_approx(Vector2(317, 200)) and two[1].is_equal_approx(Vector2(643, 200)), "two enemies: 70 px apart, centred (%s)" % [two])
	var three: Array = LAYOUT.enemy_positions([256.0, 256.0, 256.0])
	_expect(three[0].is_equal_approx(Vector2(203, 200)) and three[1].is_equal_approx(Vector2(480, 152.8)) and three[2].is_equal_approx(Vector2(757, 200)), "three enemies: crowded gap 21, the middle one raised 47.2 (%s)" % [three])
	var calm: Dictionary = LAYOUT.arrange(256.0, [256.0])
	_expect(is_equal_approx(calm.scale, 1.0) and calm.player.is_equal_approx(Vector2(480, 740)) and calm.enemies[0].is_equal_approx(Vector2(1440, 740)), "one on one: feet at y 740, no shrink (%s)" % [calm])
	# Four 384 px bosses: the rightmost edge (960+ ~1110) passes 1920, so both sides shrink.
	var crowd: Dictionary = LAYOUT.arrange(256.0, [384.0, 384.0, 384.0, 384.0])
	_expect(crowd.scale < 1.0, "a crowded field shrinks (%.3f)" % crowd.scale)
	var last: Vector2 = crowd.enemies[3]
	_expect(last.x + 192.0 * crowd.scale <= 1920.0, "the shrunken field stays on screen (%.1f)" % (last.x + 192.0 * crowd.scale))

	RunManager.start_new_run("base:cowboy_bill", [], 0, "CREATURELAYOUT1")
	var battle = load("uid://dnhj5pp3c1v2l").instantiate()  # res://ui/battle/battle_screen.tscn
	add_child(battle)
	for i in 60:
		await get_tree().process_frame
	_expect(battle.has_method("layout_creatures"), "the battle screen lays out creatures")
	_check_field(battle, "opening")

	# spawn relays out: each added enemy re-centres the whole field
	battle.combat.add_enemy(MONSTERS.create("base:scrap_rat"))
	await get_tree().process_frame
	_check_field(battle, "after one spawn")
	battle.combat.add_enemy(MONSTERS.create("base:trash_robot"))
	await get_tree().process_frame
	_check_field(battle, "after two spawns")

	# four enemies fit: a crowded field never crosses the right edge
	battle.combat.add_enemy(MONSTERS.create("base:junkyard_tyrant"))
	await get_tree().process_frame
	for v in _living_views(battle):
		var right: float = v.global_position.x + v._display_size.x * 0.5 * v.global_scale.x
		_expect(right <= 1920.0, "a crowded field stays on screen (right edge %.1f)" % right)

	battle.queue_free()
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] sts2 creature layout passed")
		get_tree().quit(0)
		return
	push_error("sts2 creature layout failed: %s" % "; ".join(failures))
	get_tree().quit(1)
