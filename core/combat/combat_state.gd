extends RefCounted

## Everything one combat is (STS2 CombatState): the creatures, the player's
## piles, the round and whose turn it is, the per-turn counters, and how it
## ended. Victory and defeat are read from here, never from scene nodes.

const PILES = preload("uid://cei2a7t4pll5c")  # res://core/combat/piles.gd

## At most this many enemies stand on the field (summons stop there).
const MAX_ENEMIES_ON_FIELD := 4

var player = null  # creature.gd
## Every enemy that joined the fight, in field order (dead ones stay listed).
var enemies: Array = []
var piles = PILES.new()

var current_round: int = 0
var is_player_turn: bool = true
## Attack cards played this turn / this combat (scale_damage_by_attacks).
var attacks_played_this_turn: int = 0
var attacks_played_this_combat: int = 0
## Double-fire clip: attacks allowed per turn (0 = unlimited) and left now.
var attack_limit_per_turn: int = 0
var attacks_left_this_turn: int = 0
## Capped card `gain_gold` triggers used this combat.
var gold_effect_triggers: int = 0
## The encounter started with a boss: its death ends the fight.
var encounter_has_boss: bool = false
## Ids of cards exhausted this combat, in order (the exhaust pile viewer).
var exhausted_ids: PackedStringArray = []
## "" while the fight goes on, then "victory" or "defeat".
var outcome: String = ""


func is_over() -> bool:
	return outcome != ""


## Enemies still fighting, in field order.
func living_enemies() -> Array:
	return enemies.filter(func(e): return e.is_alive())


## Enemies that still occupy a place on the field (summon cap).
func field_count() -> int:
	return living_enemies().size()


func living_boss_present() -> bool:
	for e in living_enemies():
		if e.is_boss:
			return true
	return false


## The fight is won: every enemy is dead, or the boss died (its adds leave).
func enemies_defeated() -> bool:
	if encounter_has_boss and not living_boss_present():
		return true
	return living_enemies().is_empty()
