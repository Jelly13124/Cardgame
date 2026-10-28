extends Node

## Stand-in battle for combat contract tests: a real combat
## (core/combat/combat_manager.gd) with the null presenter, fake combatants
## (tests/support/fake_combatant.gd) and no encounter. Relics and sets are off
## unless a test sets `relic_effect_system` / `equipment_set_system` before
## calling setup().

const COMBAT_MANAGER = preload("uid://dumevejih8ygv")  # res://core/combat/combat_manager.gd
const COMBAT_PRESENTER = preload("uid://d2bnp6o5g3mb6")  # res://core/combat/combat_presenter.gd
const FAKE_COMBATANT = preload("uid://cxg4jepx5abxn")  # res://tests/support/fake_combatant.gd


## Records notifications; everything else is the null presenter.
class RecordingPresenter:
	extends COMBAT_PRESENTER
	var notifications: PackedStringArray = []

	func notify(text: String, _color: Color = Color.WHITE) -> void:
		notifications.append(text)


var combat = COMBAT_MANAGER.new()
var player = FAKE_COMBATANT.new()
var relic_effect_system = null
var equipment_set_system = null
var _presenter = RecordingPresenter.new()

var notifications: PackedStringArray:
	get:
		return _presenter.notifications
var combat_hooks:
	get:
		return combat.combat_hooks
var combat_commands:
	get:
		return combat.combat_commands
var effect_registry:
	get:
		return combat.effect_registry
var crit_rules:
	get:
		return combat.crit_rules
var state:
	get:
		return combat.state
## The per-turn counters (attacks played) live on the combat state.
var turn_manager:
	get:
		return combat.state
## Card resolution and effects are the combat's.
var combat_engine:
	get:
		return self
var is_game_over: bool:
	get:
		return combat.is_game_over


func setup() -> void:
	combat.presenter = _presenter
	# Systems the test built against this stand-in now serve the combat.
	if relic_effect_system != null:
		relic_effect_system._battle_scene = combat
		combat.relic_effect_system = relic_effect_system
	if equipment_set_system != null:
		equipment_set_system._battle_scene = combat
		combat.equipment_set_system = equipment_set_system
	combat.setup({"player": player, "encounter": [], "relics": false})
	combat._enemy_spawned = true


func add_enemy(health := 999) -> RefCounted:
	var enemy = FAKE_COMBATANT.new()
	enemy.side = "enemy"
	enemy.enemy_id = "test:fake_enemy"
	enemy.health = health
	enemy.max_health = health
	return combat.add_enemy(enemy)


func clear_enemies() -> void:
	combat.state.enemies.clear()


func execute_effect(effect: Dictionary, target, source, play = null) -> void:
	await combat.execute_effect(effect, target, source, play)


func resolve_card_effect(card, target, _player = null) -> void:
	await combat.resolve_card_effect(card, target)


func reset_turn_crit() -> void:
	combat.combat_hooks.notify("reset_turn_state", null)
