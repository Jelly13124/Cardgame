extends Node

## CombatEngine handles the core rules of battle: attacks, unit deaths, and spell resolution.

signal victory_declared()

@onready var main = get_parent()

func _has_keyword(unit: Control, kw_name: String) -> bool:
	if not is_instance_valid(unit) or not "keyword_instances" in unit: return false
	for kw in unit.keyword_instances:
		if kw.name.to_lower() == kw_name.to_lower():
			return true
	return false

func perform_attack(attacker: Control, defender: Control):
	if not is_instance_valid(attacker) or not is_instance_valid(defender): return

	var a_pos = attacker.global_position
	var d_pos = defender.global_position
	
	# Pre-calculate combat math
	var a_atk = int(attacker.card_info.get("attack", 0))
	var d_atk = int(defender.card_info.get("attack", 0))
	
	# Temporarily render above everything
	var old_z = attacker.z_index
	attacker.z_index = 100
	
	if attacker.has_method("change_state"):
		attacker.change_state(DraggableObject.DraggableState.MOVING)
	
	# Execute lunge animation
	var tween = create_tween()
	var strike_pos = d_pos - (d_pos - a_pos).normalized() * 20
	tween.tween_property(attacker, "global_position", strike_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Begin returning
	if is_instance_valid(attacker):
		var back_tween = create_tween()
		back_tween.tween_property(attacker, "global_position", a_pos, 0.15)
		
		# Trigger damage resolution
		if is_instance_valid(defender) and defender.has_method("take_damage"):
			defender.take_damage(a_atk)
			
		if d_atk > 0 and is_instance_valid(attacker) and attacker.has_method("take_damage"):
			attacker.take_damage(d_atk)
			
		await back_tween.finished
		
		# Restore state
		if is_instance_valid(attacker):
			attacker.z_index = old_z
			if attacker.has_method("change_state"):
				attacker.change_state(DraggableObject.DraggableState.IDLE)
				
			var original_parent = attacker.card_container
			if original_parent and original_parent.has_method("_update_target_positions"):
				original_parent._update_target_positions()
	else:
		if is_instance_valid(defender) and defender.has_method("take_damage"):
			defender.take_damage(a_atk)
		await main._wait(0.3) # Helper in main

func kill_unit(card: Control):
	if main.is_game_over: return

	if card.card_container:
		card.card_container.remove_card(card)
	
	if card.card_info.get("side", "player") == "player":
		if card.has_method("reset_to_base_state"):
			card.reset_to_base_state()
		
		if _has_keyword(card, "one-time"):
			main.black_hole_pile.add_card(card)
		else:
			main.discard_pile.add_card(card)
	else:
		# Check if the killed enemy was a boss
		if card.card_info.get("is_boss", false):
			emit_signal("victory_declared")
		card.queue_free()
		
	main._update_ui_labels()
	main.show_notification("UNIT DESTROYED", Color(1, 0.2, 0.2))

func check_victory_condition():
	pass # Victory is now handled directly in kill_unit when a boss dies

func resolve_spell_effect(card: Control, target: Control = null):
	var spell_name = card.card_info.get("name", "")
	var script_path = "res://battle_scene/spells/logic/%s.gd" % spell_name
	
	if FileAccess.file_exists(script_path):
		var spell_script = load(script_path)
		if spell_script:
			var logic_instance = spell_script.new()
			if logic_instance and logic_instance.has_method("execute"):
				var context = {
					"main": main,
					"card": card,
					"target": target
				}
				await logic_instance.execute(context)
			else:
				push_error("Spell logic script '%s' does not have execute method!" % script_path)
		else:
			push_error("Failed to load spell script: %s" % script_path)
	else:
		push_warning("No logic script found for spell: %s at %s" % [spell_name, script_path])
