extends "res://core/combat/creature.gd"

## Creature for combat contract tests (core/combat/creature.gd) with 999 HP and
## counters: `damage_received` sums what reached it (before Block), `hp_lost`
## what reached HP, `hits` each hit's amount.

var damage_received := 0
var hp_lost := 0
var hits: Array[int] = []


func _init() -> void:
	max_health = 999
	health = 999


func apply_damage(amount: int, from_player := false) -> Dictionary:
	if amount > 0 and not dead:
		damage_received += amount
		hits.append(amount)
	var r: Dictionary = super.apply_damage(amount, from_player)
	hp_lost += int(r["hp_lost"])
	return r


func lose_hp(amount: int) -> int:
	var lost := super.lose_hp(amount)
	hp_lost += lost
	return lost
