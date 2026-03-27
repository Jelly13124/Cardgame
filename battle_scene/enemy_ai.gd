extends Node

## EnemyAI handles enemy turn decision-making and unit spawning.

@onready var main = get_parent()
@onready var combat_engine = main.get_node("CombatEngine")

func spawn_enemy_units():
	var rows_list = main._get_battle_rows()
	if rows_list.size() < 2: return
	
	var current_round = main.turn_manager.current_round
	var spawn_count = 1
	if current_round > 2: spawn_count = 2
	if current_round > 5: spawn_count = 3
	
	var enemy_types = ["alien_soldier", "alien_sniper", "alien_killer"]
	
	for i in range(spawn_count):
		var spawn_row = rows_list[0]
		if spawn_row.get_card_count() < 7:
			var random_type = enemy_types[randi() % enemy_types.size()]
			var card = main.card_factory.create_card(random_type, spawn_row)
			if card:
				card.card_info["side"] = "enemy"
				card.refresh_ui()
	
	# Boss Round
	if current_round % 10 == 0 or current_round == 5:
		main.show_notification("BOSS WARNING: OMEGA BOT DETECTED!", Color(1, 0, 0))
		var spawn_row = rows_list[0]
		var boss = main.card_factory.create_card("unit_boss_mk1", spawn_row)
		if boss:
			boss.card_info["side"] = "enemy"
			boss.card_info["is_boss"] = true
			boss.refresh_ui()

func execute_enemy_turn():
	if main.is_in_combat_phase or main.is_game_over: return
	main.is_in_combat_phase = true
	Engine.time_scale = 1.0
	
	# Trigger End Turn abilities
	for row in main._get_battle_rows():
		for card in row.get_cards():
			card.can_be_interacted_with = false
			if is_instance_valid(card) and "keyword_instances" in card:
				for kw in card.keyword_instances:
					if kw.has_method("on_turn_end"):
						kw.on_turn_end(row)
	
	main.show_notification("ENEMY TURN", Color(1, 0.4, 0.4))
	await main._wait(1.0)
	
	var rows_list = main._get_battle_rows()
	if rows_list.size() >= 2:
		var enemy_rows = [rows_list[0]]
		var player_rows = [rows_list[1]]
		
		for e_row in enemy_rows:
			var e_cards = e_row.get_cards()
			for e_unit in e_cards:
				if not is_instance_valid(e_unit) or e_unit.get_parent() == null: continue
				if e_unit.card_info.get("side", "player") == "enemy":
					var valid_targets = []
					for p_row in player_rows:
						for card in p_row.get_cards():
							if is_instance_valid(card) and card.card_info.get("side", "player") == "player":
								valid_targets.append(card)
							
					# Taunt Filter
					var taunt_targets = []
					for t in valid_targets:
						if combat_engine._has_keyword(t, "taunt"):
							taunt_targets.append(t)
					if taunt_targets.size() > 0:
						valid_targets = taunt_targets
							
					if valid_targets.size() > 0:
						var target = valid_targets[randi() % valid_targets.size()]
						await combat_engine.perform_attack(e_unit, target)
						await main._wait(0.2)
					else:
						# Direct Hero Attack
						var a_atk = int(e_unit.card_info.get("attack", 0))
						if main.player_hero:
							main.player_hero.take_damage(a_atk)
							main.show_notification("HERO HIT! -" + str(a_atk), Color(1, 0.2, 0.2))
						
						# Animation
						var a_pos = e_unit.global_position
						var tween = create_tween()
						var strike_pos = a_pos + Vector2(0, 100)
						tween.tween_property(e_unit, "global_position", strike_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						await tween.finished
						var back_tween = create_tween()
						back_tween.tween_property(e_unit, "global_position", a_pos, 0.15)
						await back_tween.finished
						await main._wait(0.2)
	
	if main.is_game_over: return
	
	main.show_notification("YOUR TURN", Color(0.4, 0.8, 1.0))
	await main._wait(0.5)
	
	main.is_in_combat_phase = false
	Engine.time_scale = 1.0
	
	# Reset player attacks
	if rows_list.size() >= 2:
		var p_rows = [rows_list[1]]
		for p_row in p_rows:
			for card in p_row.get_cards():
				if is_instance_valid(card) and card.card_info.get("side", "player") == "player":
					card.can_attack = true
					card.modulate = Color(1.0, 1.0, 1.0)
					card.can_be_interacted_with = true
	
	main.turn_manager.end_turn()
