extends Node

## Stand-in for battle_scene in combat contract tests: the services surface the
## combat pipeline reads, wired by the production COMBAT_SERVICES.install(),
## plus a real CombatEngine child. Relics and sets are off unless a test sets
## `relic_effect_system` / `equipment_set_system` before calling setup().

const COMBAT_SERVICES = preload("uid://bcjfi8umolkqg")  # res://battle_scene/combat/combat_services.gd
const COMBAT_ENGINE = preload("uid://c444jgeenijlu")  # res://battle_scene/combat_engine.gd
const FAKE_COMBATANT = preload("uid://cxg4jepx5abxn")  # res://tests/support/fake_combatant.gd


class FakeTurnManager:
	extends RefCounted
	var attacks_played_this_turn := 0
	var attacks_played_this_combat := 0
	var current_round := 1
	var is_player_turn := true


var player: Node2D
var enemy_container := Node2D.new()
var turn_manager := FakeTurnManager.new()
var relic_effect_system = null
var equipment_set_system = null
var combat_hooks = null
var combat_commands = null
var effect_registry = null
var crit_rules = null
var combat_engine: Node
var is_game_over := false
var notifications: PackedStringArray = []


func setup() -> void:
	if not enemy_container.is_inside_tree():
		add_child(enemy_container)
	if player == null:
		player = FAKE_COMBATANT.new()
		add_child(player)
	if combat_engine == null:
		combat_engine = COMBAT_ENGINE.new()
		add_child(combat_engine)
	COMBAT_SERVICES.install(self)
	combat_commands.attach(player)
	for enemy in enemy_container.get_children():
		combat_commands.attach(enemy)


func add_enemy(health := 999) -> Node2D:
	var enemy = FAKE_COMBATANT.new()
	enemy.health = health
	enemy.max_health = health
	enemy_container.add_child(enemy)
	if combat_commands:
		combat_commands.attach(enemy)
	return enemy


func clear_enemies() -> void:
	for enemy in enemy_container.get_children():
		enemy_container.remove_child(enemy)
		enemy.free()


func show_notification(text: String, _color: Color = Color.WHITE) -> void:
	notifications.append(text)
