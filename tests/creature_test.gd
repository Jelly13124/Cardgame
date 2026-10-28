extends Node

## The creature data object (core/combat/creature.gd) changes HP, Block and
## energy synchronously, announces each change, and dies exactly once.

const CREATURE = preload("uid://kab2636ev63e")  # res://core/combat/creature.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_damage_through_block()
	_test_dies_once()
	_test_lose_hp_and_heal()
	_test_player_turn_reset()
	_test_breakable_armor()
	if failures.is_empty():
		print("[OK] creature passed")
		get_tree().quit(0)
		return
	push_error("creature failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_damage_through_block() -> void:
	var c = CREATURE.player(30, 30)
	c.add_block(4)
	var seen := {"hp": -1, "block": -1}
	c.health_changed.connect(func(v): seen["hp"] = v)
	c.block_changed.connect(func(v): seen["block"] = v)
	var r: Dictionary = c.apply_damage(10)
	_expect(r["blocked"] == 4 and r["hp_lost"] == 6, "10 into 4 Block: 4 blocked, 6 lost (%s)" % r)
	_expect(c.health == 24 and c.block == 0, "HP 24, Block 0 after the hit")
	_expect(seen["hp"] == 24 and seen["block"] == 0, "signals carry the new values (%s)" % seen)
	_expect(r["block_broken"] and not r["killed"], "the hit broke the Block and did not kill")


func _test_dies_once() -> void:
	var c = CREATURE.player(5, 5)
	var deaths := [0]
	c.died.connect(func(): deaths[0] += 1)
	var r: Dictionary = c.apply_damage(9)
	_expect(r["killed"] and r["hp_lost"] == 5, "a lethal hit reports the kill and the HP actually lost")
	c.apply_damage(3)
	c.lose_hp(2)
	_expect(deaths[0] == 1, "died fires once, however often the corpse is hit (%d)" % deaths[0])
	_expect(not c.is_alive() and c.health == 0, "a dead creature stays at 0 HP")


func _test_lose_hp_and_heal() -> void:
	var c = CREATURE.player(20, 20)
	c.add_block(10)
	_expect(c.lose_hp(3) == 3 and c.health == 17 and c.block == 10, "HP loss ignores Block")
	_expect(c.heal(10) == 3 and c.health == 20, "healing stops at max HP")


func _test_player_turn_reset() -> void:
	var c = CREATURE.player(20, 20)
	c.max_energy = 3
	c.energy = 0
	c.add_block(7)
	c.add_status("metallicize", 2)
	c.start_turn()
	_expect(c.energy == 3, "turn start refills energy")
	_expect(c.block == 2, "Metallicize grants Block after the turn-start reset (%d)" % c.block)
	c.gain_temp_strength(2)
	c.end_turn()
	_expect(c.strength == 0, "temporary Strength fades at end of turn")


func _test_breakable_armor() -> void:
	var c = CREATURE.new()
	c.side = "enemy"
	c.max_health = 40
	c.health = 40
	c.add_block(5)
	c.arm_breakable_armor("vulnerable", 2)
	var r: Dictionary = c.apply_damage(5, true)
	_expect(r["armor_broken"] and c.get_status_stacks("vulnerable") == 2, "player damage that removes armed Block exposes the enemy")
	c.add_block(5)
	c.arm_breakable_armor("vulnerable", 2)
	c.apply_damage(5, false)
	_expect(c.get_status_stacks("vulnerable") == 2, "enemy-side damage does not break armor")
