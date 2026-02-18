class_name KeywordBase
extends RefCounted

## Base class for Unit Keywords (Shield, Wipe, etc.)
## Allows adding modular unit behaviors as standalone scripts.

var unit: UnitCard

func setup(p_unit: UnitCard) -> void:
	unit = p_unit

## Called when damage is about to be taken. 
## Should return the modified damage amount.
func on_damage_taken(amount: int) -> int:
	return amount

## Called before an attack is executed.
## Allows modifying the target list (e.g., for 'Wipe' multi-hitting).
## [param targets]: The current list of target unit(s).
## [param row]: The BattleRow where combat is happening.
## Returns the modified target list.
func on_before_attack(targets: Array, _row: Node) -> Array:
	return targets

## Called after an attack is resolved.
func on_after_attack(_targets: Array, _row: Node) -> void:
	pass

## Called when the unit dies.
func on_death() -> void:
	pass
