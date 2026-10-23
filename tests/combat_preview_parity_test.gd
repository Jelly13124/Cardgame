extends Node

## Parity: the targeting damage preview must equal the damage the card actually
## deals. Known to fail today (finding S1-01: the preview re-implements the
## damage formula and ignores `no_str`, card multipliers and more). Listed in
## tests/expected_failures.txt until phase 1 unifies the calculation.
##
## This node stands in for battle_scene: CombatEngine reads `main` (its parent)
## for player / relic systems / turn counters; the damage-modifier hooks are
## delegated to a real battle_scene.gd instance so no production logic is
## copied here.

const BATTLE_SCENE_SCRIPT = preload("uid://cf56ce8uvkmha")  # res://battle_scene/battle_scene.gd
const COMBAT_ENGINE_SCRIPT = preload("uid://c444jgeenijlu")  # res://battle_scene/combat_engine.gd
const PLAY_CARD = preload("uid://d4f71g73780ld")  # res://battle_scene/play_card.gd
const STATUS_SYSTEM = preload("uid://cq4eulp4ci8is")  # res://battle_scene/status_effect_system.gd
const CARD_DIR := "res://battle_scene/card_info/player/"
const DAMAGE_EFFECTS := [
	"deal_damage",
	"deal_damage_str_mult",
	"scale_damage_by_attacks",
	"deal_damage_block_mult",
]


class FakeTurnManager:
	extends RefCounted
	var attacks_played_this_turn := 0
	var attacks_played_this_combat := 0
	var current_round := 1


class FakeCard:
	extends Control
	var card_info: Dictionary = {}


class FakeCombatant:
	extends Node2D
	var status_system = STATUS_SYSTEM.new()
	var health := 999
	var max_health := 999
	var block := 0
	var strength := 0
	var constitution := 0
	var intelligence := 0
	var luck := 0
	var damage_received := 0

	func add_status(status: String, stacks: int) -> void:
		status_system.add_status(status, stacks, self)

	func get_status_stacks(status: String) -> int:
		return status_system.get_stacks(status)

	func get_outgoing_multiplier() -> float:
		return status_system.get_outgoing_multiplier()

	func get_incoming_attack_multiplier() -> float:
		return status_system.get_incoming_attack_multiplier()

	func add_block(amount: int) -> void:
		block += amount

	func take_damage(amount: int, _silent: bool = false, _tags: Dictionary = {}) -> void:
		damage_received += amount


# battle_scene stand-in surface read by CombatEngine.
var player: FakeCombatant
var enemy_container := Node2D.new()
var turn_manager := FakeTurnManager.new()
var relic_effect_system = null
var equipment_set_system = null
var is_game_over := false
var combat_engine: Node
var _battle_logic: Node

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func show_notification(_text: String, _color: Color = Color.WHITE) -> void:
	pass


func modify_player_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	return _battle_logic.modify_player_attack_damage(amount, attacker, defender)


func _run() -> void:
	Engine.time_scale = 20.0
	RunManager.is_run_active = false
	RunManager.relics = []
	add_child(enemy_container)
	combat_engine = COMBAT_ENGINE_SCRIPT.new()
	add_child(combat_engine)
	_battle_logic = BATTLE_SCENE_SCRIPT.new()  # never enters the tree: no _ready
	_battle_logic.combat_engine = combat_engine
	_battle_logic.turn_manager = turn_manager
	_battle_logic.relic_effect_system = null
	if RunManager.crit_chance() != 0.0:
		failures.append("precondition: crit chance must be 0 outside a run")

	var mismatches := 0
	for card_data in _target_damage_cards():
		for strength in [0, 3]:
			for weak in [false, true]:
				for vulnerable in [false, true]:
					for loaded in [0, 2]:
						var preview := _preview(card_data, strength, weak, vulnerable, loaded)
						var actual := await _actual(card_data, strength, weak, vulnerable, loaded)
						if preview != actual:
							mismatches += 1
							print(
								"MISMATCH %s STR=%d weak=%s vulnerable=%s loaded=%d preview=%d actual=%d"
								% [card_data["name"], strength, weak, vulnerable, loaded, preview, actual]
							)
	Engine.time_scale = 1.0
	_battle_logic.free()
	if mismatches > 0:
		failures.append("%d preview/actual mismatches" % mismatches)
	if failures.is_empty():
		print("[OK] combat preview parity")
		get_tree().quit(0)
		return
	print("[FAIL] ", "; ".join(failures))
	get_tree().quit(1)


func _target_damage_cards() -> Array:
	var cards: Array = []
	for file_name in DirAccess.get_files_at(CARD_DIR):
		if not file_name.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_DIR + file_name))
		if typeof(data) != TYPE_DICTIONARY or not PLAY_CARD.data_requires_enemy_target(data):
			continue
		for effect in data.get("effects", []):
			if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) in DAMAGE_EFFECTS:
				cards.append(data)
				break
	cards.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return cards


func _setup(card_data: Dictionary, strength: int, weak: bool, vulnerable: bool, loaded: int) -> Array:
	if player and is_instance_valid(player):
		player.free()
	player = FakeCombatant.new()
	player.strength = strength
	player.block = 5
	add_child(player)
	_battle_logic.player = player
	if weak:
		player.add_status("weak", 1)
	if loaded > 0:
		player.add_status("loaded", loaded)
	var target := FakeCombatant.new()
	enemy_container.add_child(target)
	if vulnerable:
		target.add_status("vulnerable", 1)
	var card := FakeCard.new()
	card.card_info = card_data.duplicate(true)
	add_child(card)
	turn_manager.attacks_played_this_turn = 0
	turn_manager.attacks_played_this_combat = 0
	combat_engine.reset_turn_crit()
	return [card, target]


func _preview(card_data: Dictionary, strength: int, weak: bool, vulnerable: bool, loaded: int) -> int:
	var parts := _setup(card_data, strength, weak, vulnerable, loaded)
	var value: int = _battle_logic._card_preview_damage(parts[0], parts[1])
	parts[0].free()
	parts[1].free()
	return value


func _actual(card_data: Dictionary, strength: int, weak: bool, vulnerable: bool, loaded: int) -> int:
	var parts := _setup(card_data, strength, weak, vulnerable, loaded)
	var card: FakeCard = parts[0]
	var target: FakeCombatant = parts[1]
	for effect in card_data.get("effects", []):
		if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) in DAMAGE_EFFECTS:
			await combat_engine._apply_effect(effect, target, player, 1.0, card)
	var dealt := target.damage_received
	card.free()
	target.free()
	return dealt
