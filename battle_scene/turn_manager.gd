extends Node

## TurnManager handles round progression and phase switching.

signal round_changed(new_round: int)
signal turn_started(side: String)
signal turn_ended(side: String)

var current_round: int = 0
var is_player_turn: bool = true


func _ready() -> void:
	pass


func start_new_game() -> void:
	current_round = 0
	start_next_round()


func start_next_round() -> void:
	current_round += 1
	emit_signal("round_changed", current_round)
	emit_signal("turn_started", "player" if is_player_turn else "enemy")


func end_turn() -> void:
	emit_signal("turn_ended", "player" if is_player_turn else "enemy")
	is_player_turn = !is_player_turn
	
	if is_player_turn:
		start_next_round()
	else:
		emit_signal("turn_started", "enemy")
