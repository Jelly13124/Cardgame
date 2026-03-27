extends Node

## TurnManager handles round progression, energy resets, and phase switching.
## It emits signals when rounds or energy change.

signal round_changed(new_round: int)
signal energy_changed(current: int, max_val: int)
signal turn_started(side: String)
signal turn_ended(side: String)

@export var max_energy: int = 3
@export var energy_per_round: int = 2

var current_round: int = 0
var current_energy: int = 0
var is_player_turn: bool = true


func _ready() -> void:
	pass


func start_new_game() -> void:
	current_round = 0
	start_next_round()


func start_next_round() -> void:
	current_round += 1
	current_energy = max_energy
	emit_signal("round_changed", current_round)
	emit_signal("energy_changed", current_energy, max_energy)
	emit_signal("turn_started", "player" if is_player_turn else "enemy")


func gain_energy(amount: int) -> void:
	current_energy = clampi(current_energy + amount, 0, max_energy)
	emit_signal("energy_changed", current_energy, max_energy)


func spend_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		emit_signal("energy_changed", current_energy, max_energy)
		return true
	return false


func can_afford(amount: int) -> bool:
	return current_energy >= amount


func end_turn() -> void:
	emit_signal("turn_ended", "player" if is_player_turn else "enemy")
	is_player_turn = !is_player_turn
	
	if is_player_turn:
		start_next_round()
	else:
		emit_signal("turn_started", "enemy")
