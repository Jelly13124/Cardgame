extends RefCounted

## The argument of a value hook (modify_hand_draw, modify_turn_energy,
## modify_attack_limit, …): listeners fold over `value`; context lives in
## named fields (e.g. `round`, `dealer`).

var value: Variant
var fields: Dictionary = {}


static func make(p_value: Variant, p_fields: Dictionary = {}):
	var v = load("uid://npewr2krgrm6").new()  # res://core/combat/hook_value.gd
	v.value = p_value
	v.fields = p_fields
	return v


func get_field(key: String, default: Variant = null) -> Variant:
	return fields.get(key, default)
