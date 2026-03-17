extends "res://battle_scene/spells/logic/spell_logic_base.gd"

func execute(context: Dictionary) -> void:
	var main = context.get("main")
	var target = context.get("target")
	
	if target:
		# Enforce Robot target validation
		var is_robot = false
		if "card_info" in target and target.card_info is Dictionary:
			if target.card_info.get("race", "").to_lower() == "robot":
				is_robot = true
				
		if is_robot:
			main.show_notification("MODIFIED: +2/+2", Color(0.2, 0.8, 0.2))
			if target.has_method("add_temporary_stats"):
				target.add_temporary_stats(2, 2)
		else:
			main.show_notification("MUST TARGET ROBOT", Color(1, 0.3, 0.3))
			# Refund energy natively handled by the caller since execution fails gracefully
			# But wait, spell cost was already subtracted prior to execution. We should refund it.
			if main.has_method("gain_energy") and target.card_info.has("cost"):
				main.gain_energy(int(target.card_info.get("cost", 0)))
				
			# On second thought, simply refund the 1 energy cost of this spell directly.
			# But wait, the standard approach in this engine is you spend energy before casting.
			# If the spell fizzles, let's refund the spell's cost.
			if main.has_method("gain_energy") \
			   and "card" in context \
			   and "card_info" in context.card \
			   and context.card.card_info.has("cost"):
				var cost = int(context.card.card_info.get("cost", 0))
				main.gain_energy(cost)
