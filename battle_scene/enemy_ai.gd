extends Node
## EnemyAI — spawns enemies from JSON data and executes their turn actions.
## To add a new enemy encounter, change `_enemy_roster` or load from RunManager.

@onready var main = get_parent()

var _enemy_spawned := false

## List of enemy IDs to spawn for this encounter. 
## In the future this will be set by RunManager/MapScene before the battle starts.
var enemy_roster: Array[String] = ["trash_robot"]

# ─── Spawning ─────────────────────────────────────────────────────────────────

func spawn_enemy_units() -> void:
	if _enemy_spawned: return
	if main.enemy_container.get_child_count() > 0:
		_enemy_spawned = true
		return
	_enemy_spawned = true

	for enemy_id in enemy_roster:
		var enemy = EnemyEntity.create(enemy_id)
		# Offset enemies horizontally if there are multiple
		var idx = main.enemy_container.get_child_count()
		enemy.position = Vector2(idx * 260, 0)
		main.enemy_container.add_child(enemy)

		# Wire death → victory check
		enemy.died.connect(_on_enemy_died)
		main.show_notification(enemy.enemy_name + " APPEARED!", Color(1, 0.3, 0.3))

# ─── Enemy Turn ───────────────────────────────────────────────────────────────

func execute_enemy_turn() -> void:
	if main.is_game_over: return

	main.show_notification("ENEMY TURN", Color(1, 0.4, 0.4))
	await get_tree().create_timer(0.8).timeout

	for enemy in main.enemy_container.get_children():
		if not is_instance_valid(enemy): continue
		if main.is_game_over: return

		var action: Dictionary = enemy.consume_next_action()
		await _execute_action(enemy, action)
		await get_tree().create_timer(0.25).timeout

	if main.is_game_over: return

	main.show_notification("YOUR TURN", Color(0.4, 0.8, 1.0))
	await get_tree().create_timer(0.4).timeout
	main.turn_manager.end_turn()

# ─── Action Execution ──────────────────────────────────────────────────────────

func _execute_action(enemy: EnemyEntity, action: Dictionary) -> void:
	var action_type: String = action.get("type", "attack")
	var amount: int         = int(action.get("amount", 6))

	match action_type:
		"attack":
			# Play sprite attack anim at the same time as the lunge tween
			if enemy.has_method("play_attack"):
				enemy.play_attack()
			await _animate_lunge(enemy)
			if main.player and is_instance_valid(main.player):
				# Apply weakness debuff: weakened enemy deals 0.75× damage
				var outgoing = amount
				if enemy.has_method("get_status_stacks") and enemy.get_status_stacks("weakness") > 0:
					outgoing = int(outgoing * enemy.status_system.get_outgoing_multiplier())
				main.player.take_damage(outgoing)
				main.show_notification("ENEMY ATTACKS %d!" % outgoing, Color(1, 0.3, 0.3))
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

		_:
			push_warning("EnemyAI: unknown action type '%s'" % action_type)

# ─── Animations ───────────────────────────────────────────────────────────────

var _enemy_start_positions: Dictionary = {}

func _animate_lunge(enemy: Node) -> void:
	_enemy_start_positions[enemy] = enemy.global_position
	var t = create_tween()
	t.tween_property(enemy, "global_position",
		enemy.global_position + Vector2(-100, 0), 0.15).set_trans(Tween.TRANS_QUAD)
	await t.finished

func _animate_return(enemy: Node) -> void:
	if not _enemy_start_positions.has(enemy): return
	var t = create_tween()
	t.tween_property(enemy, "global_position", _enemy_start_positions[enemy], 0.15)
	await t.finished

# ─── Victory Check ────────────────────────────────────────────────────────────

func _on_enemy_died() -> void:
	await get_tree().process_frame
	if main.enemy_container.get_child_count() == 0:
		main.combat_engine.victory_declared.emit()
