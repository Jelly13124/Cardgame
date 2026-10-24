extends Node
## EnemyAI — spawns enemies from JSON data and executes their turn actions.
## To add a new enemy encounter, change `_enemy_roster` or load from RunManager.

# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const ENEMY_ENTITY_SCRIPT = preload("uid://qtp7jvjqfbou")  # res://battle_scene/enemy_entity.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd

@onready var main = get_parent()

## Hard cap on simultaneous enemies. `summon` actions skip any spawn that would
## exceed this so a boss can't flood the field (and the turn loop) indefinitely.
const MAX_ENEMIES_ON_FIELD := 4

var _enemy_spawned := false

## True once the initial encounter has spawned at least one boss entity (spec A3).
## A boss's death ends the fight even with summoned adds alive, so once we've seen
## a boss we watch for "no living boss remains" in _on_enemy_died.
var _encounter_has_boss := false

## Guards against declaring victory twice (a boss death frees adds whose own
## died signals would otherwise re-enter the victory path).
var _victory_declared := false

## Round-robin cursor into a summon action's `enemy_ids` so repeated summons of
## the same action cycle through the list rather than always spawning the first.
var _summon_cursor: int = 0

## List of enemy IDs to spawn for this encounter.
## In the future this will be set by RunManager/MapScene before the battle starts.
var enemy_roster: Array[String] = ["base:trash_robot"]

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
		main.combat_commands.attach(enemy)

		if enemy.is_boss:
			_encounter_has_boss = true

		# Wire death → victory check
		enemy.died.connect(_on_enemy_died)


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
	main.combat_commands.attach(enemy)
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

		# Phase-transition on_enter (spec A2): if this enemy crossed an HP
		# threshold on the player's turn, the entity queued the phase's on_enter
		# actions. Run them here (start of its turn) through execute_action so
		# summon/buff_self reuse the existing visuals + notifications.
		if enemy.has_method("consume_pending_on_enter"):
			for on_enter_action in enemy.consume_pending_on_enter():
				if main.is_game_over or not is_instance_valid(enemy) or enemy.health <= 0:
					break
				await execute_action(enemy, on_enter_action)
			if main.is_game_over:
				return
			if not is_instance_valid(enemy) or enemy.health <= 0:
				continue

		# Stun check: if the enemy is stunned, consume one stack and skip
		# its action. The action pointer still advances so the enemy doesn't
		# build up a backlog of skipped moves.
		if enemy.has_method("consume_stun_if_present") and enemy.consume_stun_if_present():
			main.show_notification(
				tr("UI_COMBAT_ENEMY_STUNNED").format({"name": enemy.enemy_name}),
				Color(0.95, 0.95, 0.3)
			)
			enemy.consume_next_action()
			if is_instance_valid(enemy):
				enemy.end_turn()
			await get_tree().create_timer(0.4).timeout
			continue

		var action: Dictionary = enemy.consume_next_action()
		await execute_action(enemy, action)
		if is_instance_valid(enemy):
			enemy.end_turn()
		await get_tree().create_timer(0.25).timeout

	if main.is_game_over:
		return

	main.show_notification(tr("UI_COMBAT_YOUR_TURN"), Color(0.4, 0.8, 1.0))
	await get_tree().create_timer(0.4).timeout
	main.turn_manager.end_turn()


# ─── Action Execution ──────────────────────────────────────────────────────────


## Run one enemy move. Interruptible attacks (e.g. boss Crushing Blow after a
## telegraph) are cancelled by spending 1 stun stack on the enemy; every other
## move runs through the shared effect registry ("enemy" context), so attacks
## use the same damage pipeline as the intent badge.
func execute_action(enemy: Node2D, action: Dictionary) -> void:
	var action_type: String = action.get("type", "attack")
	var is_attack_like = action_type in ["attack", "attack_ramp", "attack_status", "attack_all"]
	if is_attack_like and bool(action.get("interruptible", false)):
		if enemy.has_method("consume_stun_if_present") and enemy.consume_stun_if_present():
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
	var source = COMBAT_SOURCE.make("enemy", "enemy", enemy)
	var ctx = EFFECT_CONTEXT.make("enemy", source, enemy, main.player, main)
	await main.effect_registry.execute(ctx, action)


## `summon` move: spawn `count` adds cycling through `enemy_ids`, skipping any
## that would exceed MAX_ENEMIES_ON_FIELD. Returns how many spawned.
## JSON: {"type":"summon","enemy_ids":["scrap_shard"],"count":2,"label":"☠ SUMMON"}
func summon_adds(enemy: Node, action: Dictionary) -> int:
	var enemy_ids: Array = action.get("enemy_ids", [])
	if enemy_ids.is_empty():
		return 0
	var summoned := 0
	for _n in range(int(action.get("count", 1))):
		if main.enemy_container.get_child_count() >= MAX_ENEMIES_ON_FIELD:
			break
		var add_id := str(enemy_ids[_summon_cursor % enemy_ids.size()])
		_summon_cursor += 1
		spawn_summon(add_id)
		summoned += 1
	if summoned > 0:
		main.show_notification(
			tr("UI_COMBAT_ENEMY_SUMMONS").format({"name": enemy.enemy_name}), Color(0.8, 0.4, 1.0)
		)
	return summoned


# ─── Victory Check ────────────────────────────────────────────────────────────


func _on_enemy_died() -> void:
	await get_tree().process_frame
	if _victory_declared:
		return

	# Boss-death rule (spec A3): a boss dying ends the fight even with summoned
	# adds still on the field. The dying boss queue_free()s itself before this
	# runs, so after the awaited frame we detect "the boss is gone" as: the
	# encounter had a boss AND no living boss entity remains in the container.
	# When that's true, free every remaining add FIRST (so the count check below
	# and the adds' own died signals can't race a second victory) then declare
	# victory exactly once.
	if _encounter_has_boss and not _living_boss_present():
		for child in main.enemy_container.get_children():
			if is_instance_valid(child):
				child.queue_free()
		_victory_declared = true
		main.combat_engine.declare_victory()
		return

	if main.enemy_container.get_child_count() == 0:
		_victory_declared = true
		main.combat_engine.declare_victory()


## True if a living boss EnemyEntity is still in the enemy container. A boss that
## just died has already queue_free()d itself, so it won't be counted here.
func _living_boss_present() -> bool:
	for child in main.enemy_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.get("is_boss") == true and child.get("health") > 0:
			return true
	return false
