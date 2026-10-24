extends Node

## Contract for the shared value pipeline (core/combat): damage, block and
## status stacks go through additive → multiplicative → floor → reduction → cap,
## with a preview mode that never changes state.

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const VALUE_CALC = preload("uid://tynklfj3vjf5")  # res://core/combat/value_calc.gd
const CARD_PLAY = preload("uid://bxaw24a7fumhm")  # res://core/combat/card_play.gd
const COMBAT_HOOKS = preload("uid://cjb2wdqhw4j2x")  # res://core/combat/combat_hooks.gd
const ATTRIBUTE_RULES = preload("uid://ctdg0fm8xx4bv")  # res://core/combat/rules/attribute_rules.gd
const CRIT_RULES = preload("uid://bjfqp2irnmi37")  # res://core/combat/rules/crit_rules.gd
const STATUS_SYSTEM = preload("uid://cq4eulp4ci8is")  # res://battle_scene/status_effect_system.gd

const POWERED: int = VALUE_PROPS.POWERED


class FakeCreature:
	extends Node2D
	var status_system = STATUS_SYSTEM.new()
	var strength := 0
	var constitution := 0
	var intelligence := 0
	var block := 0
	var health := 50

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)


class RecursiveListener:
	extends RefCounted
	var hooks
	var count := 0

	func after_damage_given(result) -> void:
		count += 1
		await hooks.after_damage_given(result)


var failures: PackedStringArray = []
var hooks
var player: FakeCreature
var enemy: FakeCreature


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	for test in [
		"test_strength_and_props",
		"test_multipliers_floor_once",
		"test_intangible_caps_every_damage",
		"test_block_pipeline",
		"test_status_stacks",
		"test_deadeye_preview_is_pure",
		"test_loaded_taken_once_per_play",
	]:
		_fresh()
		call(test)
	await test_hook_depth_limit()
	if failures.is_empty():
		print("[OK] combat pipeline contract passed")
		get_tree().quit(0)
		return
	push_error("combat pipeline contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _fresh() -> void:
	for node in [player, enemy]:
		if node and is_instance_valid(node):
			node.free()
	player = FakeCreature.new()
	enemy = FakeCreature.new()
	add_child(player)
	add_child(enemy)
	hooks = COMBAT_HOOKS.new()
	var attributes = ATTRIBUTE_RULES.new()
	var crit = CRIT_RULES.new()
	crit.hooks = hooks
	var h = hooks
	var creatures := [player, enemy]
	# Same order as combat_services: attributes, statuses, crits, extras.
	hooks.provider = func() -> Array:
		var out: Array = [attributes]
		for c in creatures:
			for l in c.status_system.listeners():
				l.hooks = h
				out.append(l)
		out.append(crit)
		out.append_array(h.listeners)
		return out


func _card(dealer: Node) -> Object:
	return COMBAT_SOURCE.make("card", "player", dealer)


func _damage(source, target, base: int, props: int, preview := false, play = null) -> int:
	var calc = VALUE_CALC.for_damage(source, target, base, props, preview, play)
	var value: int = hooks.compute_damage(calc)
	if not preview:
		calc.commit()
	return value


func test_strength_and_props() -> void:
	player.strength = 3
	_expect(_damage(_card(player), enemy, 4, POWERED) == 7, "STR adds to powered card damage")
	_expect(
		_damage(_card(player), enemy, 4, POWERED | VALUE_PROPS.NO_STRENGTH) == 4,
		"NO_STRENGTH skips STR"
	)
	enemy.add_status("vulnerable", 1)
	var tool_source = COMBAT_SOURCE.make("tool", "player", player)
	_expect(_damage(tool_source, enemy, 4, 0) == 4, "tool damage ignores STR and Vulnerable")


func test_multipliers_floor_once() -> void:
	enemy.add_status("vulnerable", 1)
	_expect(_damage(_card(player), enemy, 7, POWERED) == 10, "7 x1.5 floors to 10")
	player.add_status("weak", 1)
	_expect(_damage(_card(player), enemy, 7, POWERED) == 5, "7 x0.5 x1.5 floors once to 5")


func test_intangible_caps_every_damage() -> void:
	enemy.add_status("intangible", 1)
	enemy.add_status("vulnerable", 1)
	_expect(_damage(_card(player), enemy, 30, POWERED) == 1, "Intangible caps powered damage")
	var relic = COMBAT_SOURCE.make("relic", "player")
	_expect(_damage(relic, enemy, 6, 0) == 1, "Intangible caps unpowered damage")


func test_block_pipeline() -> void:
	player.constitution = 3
	player.add_status("frail", 1)
	var calc = VALUE_CALC.for_block(_card(player), player, 5, POWERED, false)
	_expect(hooks.compute_block(calc) == 6, "card block: floor((5+3) x0.75) = 6")
	var relic_calc = VALUE_CALC.for_block(COMBAT_SOURCE.make("relic", "player"), player, 5, 0, false)
	_expect(hooks.compute_block(relic_calc) == 5, "relic block ignores CON and Frail")


func _stacks(source, target, status: String, stacks: int, effect_type: String) -> int:
	return hooks.compute_status_stacks(
		VALUE_CALC.for_status(source, target, status, stacks, effect_type, false)
	)


func test_status_stacks() -> void:
	player.intelligence = 2
	_expect(_stacks(_card(player), enemy, "weak", 1, "apply_status") == 3, "INT boosts card statuses on enemies")
	_expect(_stacks(_card(player), player, "regen", 1, "apply_status_self") == 1, "INT skips self statuses")
	_expect(_stacks(_card(player), enemy, "stun", 1, "apply_status") == 1, "INT skips Stun")
	var tool_source = COMBAT_SOURCE.make("tool", "player", player)
	_expect(_stacks(tool_source, enemy, "weak", 1, "apply_status") == 3, "INT boosts tool statuses on enemies")
	var relic = COMBAT_SOURCE.make("relic", "player", player)
	_expect(_stacks(relic, enemy, "weak", 1, "apply_status") == 1, "INT skips relic statuses")


func test_deadeye_preview_is_pure() -> void:
	player.add_status("deadeye", 1)
	_expect(_damage(_card(player), enemy, 4, POWERED, true) == 6, "preview shows forced crit")
	_expect(_damage(_card(player), enemy, 4, POWERED, true) == 6, "second preview still shows it")
	_expect(player.get_status_stacks("deadeye") == 1, "preview keeps Deadeye")
	_expect(_damage(_card(player), enemy, 4, POWERED) == 6, "real hit crits")
	_expect(player.get_status_stacks("deadeye") == 0, "real hit spends Deadeye")


func test_loaded_taken_once_per_play() -> void:
	player.add_status("loaded", 2)
	var preview = CARD_PLAY.new()
	preview.preview = true
	_expect(preview.take_loaded(player) == 2, "preview play reads Loaded")
	_expect(preview.take_loaded(player) == 0, "second damage effect gets none")
	_expect(player.get_status_stacks("loaded") == 2, "preview keeps Loaded")
	var real = CARD_PLAY.new()
	_expect(real.take_loaded(player) == 2, "real play takes Loaded")
	_expect(player.get_status_stacks("loaded") == 0, "real play spends Loaded")


func test_hook_depth_limit() -> void:
	_fresh()
	var listener := RecursiveListener.new()
	listener.hooks = hooks
	hooks.add_listener(listener)
	await hooks.after_damage_given(null)
	_expect(listener.count == COMBAT_HOOKS.MAX_DEPTH, "re-entrant hooks stop at depth %d (got %d)" % [COMBAT_HOOKS.MAX_DEPTH, listener.count])
