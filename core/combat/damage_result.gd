extends RefCounted

## Outcome of one resolved damage hit, passed to after_damage_given /
## after_damage_received listeners.

var source = null  # combat_source.gd
var props: int = 0
var dealer: Object = null
var target: Object = null
## Damage after every pipeline stage (Intangible included), before Block.
var amount: int = 0
var blocked: int = 0
var hp_lost: int = 0
var killed: bool = false
var critical: bool = false
var block_broken: bool = false


func has(flag: int) -> bool:
	return (props & flag) != 0
