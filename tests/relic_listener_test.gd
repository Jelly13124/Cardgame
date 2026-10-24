extends Node

## Relics are per-battle listener instances: a new trigger needs only data + a
## small script (fixture "every third attack grants 3 Block"), instances are
## built once per battle, and once-per-combat effects are spent by real hits
## only.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const HOOK_VALUE = preload("uid://npewr2krgrm6")  # res://core/combat/hook_value.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _battle() -> Node:
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(4):
		await get_tree().process_frame
	for enemy in battle.enemy_container.get_children():
		enemy.health = 999
		enemy.max_health = 999
	return battle


func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _run() -> void:
	MODEL_DB.inject_dir("res://tests/fixtures/relic_mod/", "testmod")
	RunManager.start_new_run("base:cowboy_bill", [], 0, "RELICTEST1")
	RunManager.is_run_active = true
	RunManager.relics = ["testmod:third_attack_block"]

	var battle = await _battle()
	var relic_listeners: Array = battle.relic_effect_system.current_listeners(battle.combat_hooks)
	_expect(relic_listeners.size() == 1, "one listener per held relic")
	var first = relic_listeners[0] if not relic_listeners.is_empty() else null
	battle.combat_hooks.compute("modify_hand_draw", HOOK_VALUE.make(3))
	_expect(battle.relic_effect_system.current_listeners(battle.combat_hooks)[0] == first,
		"relic listeners are not rebuilt per query")

	var enemy: Node = battle.enemy_container.get_child(0)
	var blocks: Array = []
	for i in 6:
		battle.player.energy = 10
		battle.player.block = 0
		var card = battle.deck_manager.add_card_to_hand("base:strike")
		await get_tree().process_frame
		battle.play_spell(card, enemy)
		await _wait_until(func() -> bool: return battle.discard_pile.get_card_count() >= i + 1, 10.0)
		await get_tree().create_timer(0.2).timeout
		blocks.append(int(battle.player.block))
	_expect(blocks == [0, 0, 3, 0, 0, 3], "every third attack grants 3 Block: %s" % [blocks])

	# Player-only power reactions ignore an enemy bearer.
	var foe: Node = battle.enemy_container.get_child(0)
	foe.block = 0
	foe.add_status("feel_no_pain", 3)
	foe.add_status("covering_reload", 1)
	await battle.combat_hooks.react("after_card_exhausted", null)
	await battle.combat_hooks.react("after_reload", null)
	_expect(int(foe.block) == 0, "enemy Feel No Pain / Covering Reload ignore the player's Exhaust and Reload (block %d)" % foe.block)

	RunManager.relics = ["base:" + _once_relic()]
	var once = battle.relic_effect_system.current_listeners(battle.combat_hooks)[0]
	var pair: Array = []
	var effects: Array = once.data.get("effects", [])
	for i in effects.size():
		if bool(effects[i].get("once_per_combat", false)):
			pair = [i, effects[i]]
	_expect(not pair.is_empty(), "found a once-per-combat relic effect")
	if not pair.is_empty():
		_expect(once.can_use(pair), "unspent at battle start")
		once.mark_used(pair)
		_expect(not once.can_use(pair), "spent after use")
		RunManager.relics = []
		battle.relic_effect_system.current_listeners(battle.combat_hooks)
		RunManager.relics = ["base:" + _once_relic()]
		battle.relic_effect_system.setup(battle)
		var fresh = battle.relic_effect_system.current_listeners(battle.combat_hooks)[0]
		_expect(fresh.can_use(pair), "a new battle resets once-per-combat")

	get_tree().current_scene = null
	battle.queue_free()
	await get_tree().process_frame
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	MODEL_DB.reset()
	if failures.is_empty():
		print("[OK] relic listener passed")
		get_tree().quit(0)
		return
	push_error("relic listener failed: %s" % "; ".join(failures))
	get_tree().quit(1)


## Entry of a shipped relic with a once_per_combat effect.
func _once_relic() -> String:
	for id in MODEL_DB.ids("relic"):
		for effect in MODEL_DB.data("relic", id).get("effects", []):
			if bool(effect.get("once_per_combat", false)):
				return str(id).trim_prefix("base:")
	return ""
