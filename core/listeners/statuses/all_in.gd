extends "res://core/listeners/status_listener.gd"

## All In: the bearer's Crits deal `vars.crit_mult` (2.0) damage and no other
## multiplier source applies; a powered attack that does not Crit grants
## `vars.loaded` (2) Loaded when it lands.


func modify_crit_multiplier(m) -> void:
	if m.get_field("dealer") == owner and amount() > 0:
		m.value = float(var_value("crit_mult", 2.0))
		m.fields["locked"] = true


func after_non_crit(calc) -> void:
	if calc.dealer != owner or calc.preview or amount() <= 0:
		return
	var bearer: Object = owner
	var loaded := int(var_value("loaded", 2))
	calc.on_commit(func() -> void: bearer.add_status("loaded", loaded))
