class_name KeywordBase
extends RefCounted

## Base class for Unit Keywords (Shield, Wipe, etc.)
## Allows adding modular unit behaviors as standalone scripts.

var unit: UnitCard
var name: String = "keyword_base"

func setup(p_unit: UnitCard) -> void:
	unit = p_unit
	
	# Try to infer name from script location if not overridden
	var script = get_script()
	if script and script.resource_path:
		var fn = script.resource_path.get_file().get_basename()
		if fn != "keyword_base":
			name = fn

## Called when damage is about to be taken. 
## Should return the modified damage amount.
func on_damage_taken(amount: int) -> int:
	return amount

## Called when the unit is first played/deployed to the battlefield from the hand.
func on_deploy(_row: Node, _slot_index: int) -> void:
	pass

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
