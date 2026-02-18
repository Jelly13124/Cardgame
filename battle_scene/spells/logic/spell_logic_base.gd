class_name SpellLogicBase
extends RefCounted

## Base class for all spell logic objects.
## This allows us to decouple individual spell effects from the main game manager.

## Executes the spell effect.
## [param context] A dictionary containing:
## - "main": The game manager (battle_scene.gd)
## - "card": The Card node being played
## - "target": The targeted Card node (if unit-targeted), or null
func execute(_context: Dictionary) -> void:
	pass
