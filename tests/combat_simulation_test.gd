extends Node

## A whole combat runs headless (STS2 TestMode): core/combat/combat_manager.gd
## with the null presenter plays a fight from setup to victory or defeat —
## no battle scene, no nodes — and the same seed replays the same fight.
## Plays made faster than they resolve still resolve in order.

const COMBAT_MANAGER = preload("uid://dumevejih8ygv")  # res://core/combat/combat_manager.gd
const COMBAT_PRESENTER = preload("uid://d2bnp6o5g3mb6")  # res://core/combat/combat_presenter.gd
const CREATURE = preload("uid://kab2636ev63e")  # res://core/combat/creature.gd
const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd

const STARTER := [
	"base:strike", "base:strike", "base:strike", "base:strike", "base:weak_strike",
	"base:defend", "base:defend", "base:defend", "base:defend", "base:siphon",
]


## A presenter whose card resolution takes real time, so plays queue up.
class SlowPresenter:
	extends COMBAT_PRESENTER
	var tree: SceneTree

	func card_resolving(_card: Object) -> void:
		await tree.create_timer(0.05).timeout


var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var saved_rng = RunManager.run_rng
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var first: Array = await _fight("SIM1SEED22", 60)
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_expect(first[0] == "victory", "the starter deck beats a Trash Robot headless (%s)" % first[0])
	_expect(nodes_after == nodes_before, "a headless combat creates no node (%d → %d)" % [nodes_before, nodes_after])
	var second: Array = await _fight("SIM1SEED22", 60)
	_expect(first[1] == second[1], "the same seed replays the same fight:\n%s\n%s" % [first[1], second[1]])
	var other: Array = await _fight("SIM2SEED33", 60)
	_expect(other[1] != first[1], "another seed plays another fight")
	var lost: Array = await _fight("SIM1SEED22", 5, 999)
	_expect(lost[0] == "defeat", "a 5-HP player loses to an enemy it cannot kill (%s)" % lost[0])
	await _test_rapid_plays()
	RunManager.run_rng = saved_rng
	if failures.is_empty():
		print("[OK] combat simulation passed")
		get_tree().quit(0)
		return
	push_error("combat simulation failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _combat(seed_string: String, hp: int, presenter = null) -> RefCounted:
	RunManager.run_rng = RUN_RNG_SET.new(seed_string)
	var player = CREATURE.player(hp, hp)
	for attr in ["strength", "constitution", "intelligence", "luck", "charm"]:
		player.set(attr, 3)
	var combat = COMBAT_MANAGER.new()
	if presenter != null:
		combat.presenter = presenter
	combat.setup({"player": player, "deck": STARTER, "encounter": ["base:trash_robot"], "relics": false})
	return combat


## Plays attacks at the first enemy, then anything else playable, then ends
## the turn — until the fight is over. Returns [outcome, log].
func _fight(seed_string: String, hp: int, enemy_hp := 0) -> Array:
	var combat = _combat(seed_string, hp)
	var log: Array = []
	combat.card_played.connect(func(c): log.append("play %s" % c.model_id))
	combat.round_changed.connect(
		func(r): log.append("round %d hp %d" % [r, combat.player.health])
	)
	await combat.start()
	if enemy_hp > 0:
		for e in combat.state.living_enemies():
			e.max_health = enemy_hp
			e.health = enemy_hp
	var turns := 0
	while not combat.is_game_over and turns < 40:
		turns += 1
		var played := true
		while played and not combat.is_game_over:
			played = false
			for card in combat.state.piles.hand.cards.duplicate():
				if not combat.can_play_card(card):
					continue
				var target = combat.state.living_enemies()[0] if card.requires_enemy_target() else null
				if combat.play_card(card, target):
					await _drain(combat)
					played = true
					break
		if combat.is_game_over:
			break
		combat.request_end_turn()
		await _drain(combat)
	log.append("end %s" % combat.state.outcome)
	return [combat.state.outcome, log]


func _drain(combat) -> void:
	while combat.action_queue.is_busy():
		await combat.action_queue.drained


## Three Strikes played in one frame, while the first still resolves, end the
## same way as three Strikes played one after another.
func _test_rapid_plays() -> void:
	var results: Array = []
	for rapid in [true, false]:
		var slow = SlowPresenter.new()
		slow.tree = get_tree()
		var combat = _combat("SIM3SEED44", 60, slow)
		await combat.start()
		var enemy = combat.state.living_enemies()[0]
		enemy.max_health = 999
		enemy.health = 999
		var log: Array = []
		combat.card_played.connect(func(c): log.append(c.model_id))
		var strikes: Array = []
		for _i in range(3):
			var s = combat.add_card_to_hand("base:strike")
			s.cost_override = 0
			strikes.append(s)
		for s in strikes:
			combat.play_card(s, enemy)
			if not rapid:
				await _drain(combat)
		await _drain(combat)
		results.append([enemy.health, log, combat.state.attacks_played_this_turn])
	_expect(results[0] == results[1], "rapid plays resolve like sequential ones: %s vs %s" % results)
	_expect(results[0][2] == 3, "each queued Strike counted once (%d)" % results[0][2])
