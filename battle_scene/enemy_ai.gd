extends Node
## EnemyAI — spawns enemies from JSON data and executes their turn actions.
## To add a new enemy encounter, change `_enemy_roster` or load from RunManager.

# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const ENEMY_ENTITY_SCRIPT = preload("res://battle_scene/enemy_entity.gd")
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

@onready var main = get_parent()

var _enemy_spawned := false

## List of enemy IDs to spawn for this encounter.
## In the future this will be set by RunManager/MapScene before the battle starts.
var enemy_roster: Array[String] = ["trash_robot"]

# ─── Spawning ─────────────────────────────────────────────────────────────────


func spawn_enemy_units() -> void:
	if _enemy_spawned:
		return
	if main.enemy_container.get_child_count() > 0:
		_enemy_spawned = true
		return
	_enemy_spawned = true

	for enemy_id in enemy_roster:
		var enemy = ENEMY_ENTITY_SCRIPT.create(enemy_id)
		# Offset enemies horizontally if there are multiple
		var idx = main.enemy_container.get_child_count()
		enemy.position = Vector2(idx * 260, 0)
		main.enemy_container.add_child(enemy)

		# Wire death → victory check
		enemy.died.connect(_on_enemy_died)
		main.show_notification(enemy.enemy_name + " APPEARED!", Color(1, 0.3, 0.3))


# ─── Enemy Turn ───────────────────────────────────────────────────────────────


func execute_enemy_turn() -> void:
	if main.is_game_over:
		return

	main.show_notification("ENEMY TURN", Color(1, 0.4, 0.4))
	await get_tree().create_timer(0.8).timeout

	for enemy in main.enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		if main.is_game_over:
			return

		enemy.start_turn()
		if main.is_game_over:
			return
		if not is_instance_valid(enemy) or enemy.health <= 0:
			await get_tree().process_frame
			if main.is_game_over:
				return
			continue

		# Shock check: if the enemy is shocked, consume one stack and skip
		# its action. The action pointer still advances so the enemy doesn't
		# build up a backlog of skipped moves.
		if enemy.has_method("consume_shock_if_present") and enemy.consume_shock_if_present():
			main.show_notification("%s SHOCKED!" % enemy.enemy_name, Color(0.95, 0.95, 0.3))
			enemy.consume_next_action()
			if is_instance_valid(enemy):
				enemy.end_turn()
			await get_tree().create_timer(0.4).timeout
			continue

		var action: Dictionary = enemy.consume_next_action()
		await _execute_action(enemy, action)
		if is_instance_valid(enemy):
			enemy.end_turn()
		await get_tree().create_timer(0.25).timeout

	if main.is_game_over:
		return

	main.show_notification("YOUR TURN", Color(0.4, 0.8, 1.0))
	await get_tree().create_timer(0.4).timeout
	main.turn_manager.end_turn()


# ─── Action Execution ──────────────────────────────────────────────────────────


## `enemy` is typed as Node2D (its parent class) instead of EnemyEntity to
## avoid class_name parse-ordering issues.
func _execute_action(enemy: Node2D, action: Dictionary) -> void:
	var action_type: String = action.get("type", "attack")
	var amount: int = int(action.get("amount", 6))

	# Interruptible attacks (e.g. boss Crushing Blow after a telegraph) can be
	# cancelled by spending 1 shock stack on the enemy. This is the shared
	# cancel logic for mortar_cart and the Junkyard Tyrant Boss.
	var is_attack_like = action_type in ["attack", "attack_status", "attack_all"]
	if is_attack_like and bool(action.get("interruptible", false)):
		if enemy.has_method("consume_shock_if_present") and enemy.consume_shock_if_present():
			main.show_notification(
				"%s — INTERRUPTED!" % str(action.get("label", "ATTACK")), Color(0.95, 0.95, 0.3)
			)
			# Visual pulse so the player sees something happened
			var pulse = create_tween()
			pulse.tween_property(enemy, "scale", Vector2(0.9, 1.1), 0.1)
			pulse.tween_property(enemy, "scale", Vector2(1.0, 1.0), 0.1)
			await pulse.finished
			return

	match action_type:
		"attack":
			# Play sprite attack anim at the same time as the lunge tween
			if enemy.has_method("play_attack"):
				enemy.play_attack()
			await _animate_lunge(enemy)
			if main.player and is_instance_valid(main.player):
				var outgoing = main.combat_engine.calculate_attack_damage(
					amount, enemy, main.player
				)
				if main.has_method("modify_enemy_attack_damage"):
					outgoing = main.modify_enemy_attack_damage(outgoing, enemy, main.player)
				main.player.take_damage(outgoing)
				main.show_notification("ENEMY ATTACKS %d!" % outgoing, Color(1, 0.3, 0.3))
			await _animate_return(enemy)

		"attack_status":
			# Damage + apply a status to the player.
			# JSON: {"type":"attack_status", "amount":5, "status":"weak", "stacks":1, "label":"⚔ 5 +Weak"}
			if enemy.has_method("play_attack"):
				enemy.play_attack()
			await _animate_lunge(enemy)
			if main.player and is_instance_valid(main.player):
				var outgoing = main.combat_engine.calculate_attack_damage(
					amount, enemy, main.player
				)
				if main.has_method("modify_enemy_attack_damage"):
					outgoing = main.modify_enemy_attack_damage(outgoing, enemy, main.player)
				main.player.take_damage(outgoing)
				var status: String = str(action.get("status", ""))
				var stacks: int = int(action.get("stacks", 1))
				if status != "" and main.player.has_method("add_status"):
					main.player.add_status(status, stacks)
				main.show_notification(
					"ENEMY HITS %d + %s" % [outgoing, STATUS_SYS.format_name(status).to_upper()],
					Color(1, 0.3, 0.3)
				)
			await _animate_return(enemy)

		"attack_all":
			# AoE attack hitting only the player (we have a single player).
			# Same flow as attack but with louder messaging and a bigger lunge.
			if enemy.has_method("play_attack"):
				enemy.play_attack()
			await _animate_lunge(enemy)
			if main.player and is_instance_valid(main.player):
				var outgoing = main.combat_engine.calculate_attack_damage(
					amount, enemy, main.player
				)
				if main.has_method("modify_enemy_attack_damage"):
					outgoing = main.modify_enemy_attack_damage(outgoing, enemy, main.player)
				main.player.take_damage(outgoing)
				main.show_notification("BIG HIT: %d!" % outgoing, Color(1.0, 0.2, 0.2))
			await _animate_return(enemy)

		"block":
			enemy.add_block(amount)
			main.show_notification("ENEMY DEFENDS +%d" % amount, Color(0.4, 0.6, 1.0))
			# Small visual pulse
			var t = create_tween()
			t.tween_property(enemy, "scale", Vector2(1.2, 1.2), 0.1)
			t.tween_property(enemy, "scale", Vector2(1.0, 1.0), 0.1)
			await t.finished

		"heal":
			if enemy.has_method("heal"):
				enemy.heal(amount)
			main.show_notification("ENEMY HEALS %d" % amount, Color(0.2, 1.0, 0.4))

		"telegraph":
			# Flavor-only action: enemy charges up for a follow-up attack.
			# No damage, no block. The intent badge already shows "CHARGING".
			# The next action (typically marked interruptible:true) is the payoff.
			main.show_notification("%s CHARGING..." % enemy.enemy_name, Color(1.0, 0.7, 0.2))
			var charge_tween = create_tween()
			charge_tween.tween_property(enemy, "modulate", Color(1.4, 1.1, 0.4), 0.25)
			charge_tween.tween_property(enemy, "modulate", Color.WHITE, 0.25)
			await charge_tween.finished

		_:
			push_error(
				(
					"EnemyAI: unknown action type '%s' (enemy '%s'). Check enemy JSON or add the action to enemy_ai._execute_action()."
					% [action_type, enemy.enemy_name]
				)
			)
			assert(false, "EnemyAI: unknown action type '%s'" % action_type)


# ─── Animations ───────────────────────────────────────────────────────────────

var _enemy_start_positions: Dictionary = {}


func _animate_lunge(enemy: Node) -> void:
	_enemy_start_positions[enemy] = enemy.global_position
	var t = create_tween()
	(
		t
		. tween_property(enemy, "global_position", enemy.global_position + Vector2(-100, 0), 0.15)
		. set_trans(Tween.TRANS_QUAD)
	)
	await t.finished


func _animate_return(enemy: Node) -> void:
	if not _enemy_start_positions.has(enemy):
		return
	var t = create_tween()
	t.tween_property(enemy, "global_position", _enemy_start_positions[enemy], 0.15)
	await t.finished


# ─── Victory Check ────────────────────────────────────────────────────────────


func _on_enemy_died() -> void:
	await get_tree().process_frame
	if main.enemy_container.get_child_count() == 0:
		main.combat_engine.declare_victory()
