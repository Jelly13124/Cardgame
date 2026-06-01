extends Node
## EnemyAI — spawns enemies from JSON data and executes their turn actions.
## To add a new enemy encounter, change `_enemy_roster` or load from RunManager.

# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const ENEMY_ENTITY_SCRIPT = preload("res://battle_scene/enemy_entity.gd")
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

@onready var main = get_parent()

## Hard cap on simultaneous enemies. `summon` actions skip any spawn that would
## exceed this so a boss can't flood the field (and the turn loop) indefinitely.
const MAX_ENEMIES_ON_FIELD := 4

var _enemy_spawned := false

## Round-robin cursor into a summon action's `enemy_ids` so repeated summons of
## the same action cycle through the list rather than always spawning the first.
var _summon_cursor: int = 0

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
		main.show_notification(
			tr("UI_COMBAT_ENEMY_APPEARED").format({"name": enemy.enemy_name}), Color(1, 0.3, 0.3)
		)


## Instantiate a single add mid-combat, position it after the existing enemies,
## add it to the enemy container, and wire its death → victory check. Honors the
## MAX_ENEMIES_ON_FIELD cap (caller should already check, but we guard here too).
## Returns the spawned EnemyEntity, or null if the field is full.
func spawn_summon(enemy_id: String) -> Node2D:
	if main.enemy_container.get_child_count() >= MAX_ENEMIES_ON_FIELD:
		return null
	var enemy = ENEMY_ENTITY_SCRIPT.create(enemy_id)
	var idx = main.enemy_container.get_child_count()
	enemy.position = Vector2(idx * 260, 0)
	main.enemy_container.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	main.show_notification(
		tr("UI_COMBAT_ENEMY_APPEARED").format({"name": enemy.enemy_name}), Color(1, 0.3, 0.3)
	)
	return enemy


# ─── Enemy Turn ───────────────────────────────────────────────────────────────


func execute_enemy_turn() -> void:
	if main.is_game_over:
		return

	main.show_notification(tr("UI_COMBAT_ENEMY_TURN"), Color(1, 0.4, 0.4))
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
			main.show_notification(
				tr("UI_COMBAT_ENEMY_SHOCKED").format({"name": enemy.enemy_name}),
				Color(0.95, 0.95, 0.3)
			)
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

	main.show_notification(tr("UI_COMBAT_YOUR_TURN"), Color(0.4, 0.8, 1.0))
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
			var interrupt_label := str(action.get("label", tr("UI_COMBAT_INTERRUPT_DEFAULT_LABEL")))
			main.show_notification(
				tr("UI_COMBAT_INTERRUPTED").format({"label": interrupt_label}),
				Color(0.95, 0.95, 0.3)
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
				main.show_notification(
					tr("UI_COMBAT_ENEMY_ATTACKS").format({"n": outgoing}), Color(1, 0.3, 0.3)
				)
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
					tr("UI_COMBAT_ENEMY_HITS_STATUS").format(
						{"n": outgoing, "status": STATUS_SYS.format_name_localized(status)}
					),
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
				main.show_notification(
					tr("UI_COMBAT_BIG_HIT").format({"n": outgoing}), Color(1.0, 0.2, 0.2)
				)
			await _animate_return(enemy)

		"block":
			enemy.add_block(amount)
			main.show_notification(
				tr("UI_COMBAT_ENEMY_DEFENDS").format({"n": amount}), Color(0.4, 0.6, 1.0)
			)
			# Small visual pulse
			var t = create_tween()
			t.tween_property(enemy, "scale", Vector2(1.2, 1.2), 0.1)
			t.tween_property(enemy, "scale", Vector2(1.0, 1.0), 0.1)
			await t.finished

		"heal":
			if enemy.has_method("heal"):
				enemy.heal(amount)
			main.show_notification(
				tr("UI_COMBAT_ENEMY_HEALS").format({"n": amount}), Color(0.2, 1.0, 0.4)
			)

		"telegraph":
			# Flavor-only action: enemy charges up for a follow-up attack.
			# No damage, no block. The intent badge already shows "CHARGING".
			# The next action (typically marked interruptible:true) is the payoff.
			main.show_notification(
				tr("UI_COMBAT_ENEMY_CHARGING").format({"name": enemy.enemy_name}),
				Color(1.0, 0.7, 0.2)
			)
			var charge_tween = create_tween()
			charge_tween.tween_property(enemy, "modulate", Color(1.4, 1.1, 0.4), 0.25)
			charge_tween.tween_property(enemy, "modulate", Color.WHITE, 0.25)
			await charge_tween.finished

		"summon":
			# Spawn `count` adds, cycling through `enemy_ids`. Skips spawns that
			# would push the field past MAX_ENEMIES_ON_FIELD.
			# JSON: {"type":"summon","enemy_ids":["scrap_shard"],"count":2,"label":"☠ SUMMON"}
			var enemy_ids: Array = action.get("enemy_ids", [])
			var count: int = int(action.get("count", 1))
			if enemy_ids.is_empty():
				return
			var summoned := 0
			for n in range(count):
				if main.enemy_container.get_child_count() >= MAX_ENEMIES_ON_FIELD:
					break
				var add_id := str(enemy_ids[_summon_cursor % enemy_ids.size()])
				_summon_cursor += 1
				spawn_summon(add_id)
				summoned += 1
			if summoned > 0:
				main.show_notification(
					tr("UI_COMBAT_ENEMY_SUMMONS").format({"name": enemy.enemy_name}),
					Color(0.8, 0.4, 1.0)
				)
				var pulse = create_tween()
				pulse.tween_property(enemy, "scale", Vector2(1.15, 1.15), 0.12)
				pulse.tween_property(enemy, "scale", Vector2(1.0, 1.0), 0.12)
				await pulse.finished

		"buff_self":
			# Apply a status to the acting enemy itself (e.g. strength_up to ramp).
			# JSON: {"type":"buff_self","status":"strength_up","stacks":3,"label":"💪 ENRAGE"}
			var status: String = str(action.get("status", ""))
			var stacks: int = int(action.get("stacks", 1))
			if status != "" and enemy.has_method("add_status"):
				enemy.add_status(status, stacks)
			main.show_notification(
				tr("UI_COMBAT_ENEMY_BUFFS_SELF").format(
					{"name": enemy.enemy_name, "status": STATUS_SYS.format_name_localized(status)}
				),
				Color(1.0, 0.6, 0.2)
			)
			var buff_tween = create_tween()
			buff_tween.tween_property(enemy, "modulate", Color(1.5, 0.7, 0.7), 0.2)
			buff_tween.tween_property(enemy, "modulate", Color.WHITE, 0.2)
			await buff_tween.finished

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
