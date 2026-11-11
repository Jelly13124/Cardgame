extends Node

## The intent view must classify projected total damage, retain live cells on
## status refresh, and let its own entry/exit/bob lifecycle finish smoothly.
const ENEMY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("[FAIL] ", message)


func _run() -> void:
	await _test_damage_tiers_and_categories()
	await _test_status_predictions()
	await _test_animation_lifecycle()
	await _test_scaled_boss_clearance()
	if failures.is_empty():
		print("[OK] enemy intent display")
		get_tree().quit(0)
	else:
		print("[FAIL] ", "; ".join(failures))
		get_tree().quit(1)


func _enemy(action: Dictionary) -> Node2D:
	var enemy := ENEMY.create("base:trash_robot")
	enemy.action_pattern = [action]
	add_child(enemy)
	# Godot enables a script's _process when the node enters the tree.
	enemy.set_process(false)
	return enemy


func _set_action(enemy: Node, action: Dictionary) -> void:
	enemy.action_pattern = [action]
	enemy.creature.moves._action_index = 0
	enemy.update_intent_display()


func _icon(enemy: Node, kind: String) -> TextureRect:
	var cell := enemy.find_child("Intent" + kind, true, false)
	return cell.find_child("Icon", true, false) as TextureRect if cell else null


func _path(icon: TextureRect) -> String:
	return icon.texture.resource_path if icon != null and icon.texture != null else ""


func _test_damage_tiers_and_categories() -> void:
	var enemy := _enemy({"type": "attack", "amount": 4})
	await get_tree().process_frame
	for row in [[0, 1], [4, 1], [5, 2], [19, 2], [20, 3], [80, 3]]:
		_set_action(enemy, {"type": "attack", "amount": row[0]})
		var icon := _icon(enemy, "Attack")
		_expect(_path(icon).ends_with("/combat/intents/attack_%d.png" % row[1]),
			"damage %d selects original attack tier %d" % row)
		_expect(icon != null and icon.size == Vector2(52, 52), "every severity uses the same compact 52px footprint")
		_expect(icon != null and icon.modulate == Color.WHITE, "severity keeps the original PNG colors")
	_set_action(enemy, {"type": "attack", "amount": 7, "hits": 3})
	_expect(_path(_icon(enemy, "Attack")).ends_with("/combat/intents/attack_3.png"), "7x3 chooses tier 3 from total 21")
	var attack := enemy.find_child("IntentAttack", true, false)
	var value := attack.find_child("IntentValue", true, false) as Label
	_expect(value != null and value.text == "7×3", "multi-hit prints projected per-hit damage and count")
	var marker := attack.find_child("MultiMarker", true, false) as TextureRect
	_expect(marker != null and marker.visible and _path(marker).ends_with("/combat/intents/multi.png"),
		"multi-hit has its separate marker")
	_expect(value != null and value.get_theme_font_size("font_size") == 22
		and value.get_theme_constant("outline_size") == 12, "damage text remains readable over the scene")
	_set_action(enemy, {"type": "attack_all", "amount": 8})
	_expect(value != null and value.text == "8" and marker != null and not marker.visible,
		"all-target attack remains one hit without explicit repeat metadata")
	for row in [["unknown", "Unknown", "unknown"], ["future_action", "Unknown", "unknown"],
		["escape", "Escape", "escape"], ["summon", "Summon", "summon"],
		["telegraph", "Charge", "charge"], ["block", "Block", "block"],
		["buff_self", "Buff", "buff"], ["add_curse", "CardDebuff", "card_debuff"],
		["heal", "Heal", "heal"], ["sleep", "Sleep", "sleep"],
		["status", "Status", "status"], ["stun", "Stun", "stun"],
		["death_blow", "DeathBlow", "death_blow"]]:
		_set_action(enemy, {"type": row[0], "amount": 5})
		_expect(_path(_icon(enemy, row[1])).ends_with("/combat/intents/%s.png" % row[2]),
			"%s receives its matching intent category" % row[0])
	enemy.queue_free()
	await get_tree().process_frame


func _test_scaled_boss_clearance() -> void:
	for parent_scale in [Vector2.ONE, Vector2(1.1, 1.25)]:
		var host := Node2D.new()
		host.position = Vector2(20, 10)
		host.scale = parent_scale
		add_child(host)
		var boss := ENEMY.create("base:rust_titan")
		boss.action_pattern = [{"type": "block", "amount": 10}]
		host.add_child(boss)
		boss.set_process(false)
		boss.global_position = Vector2(1440, 610)
		await get_tree().process_frame
		var planted := boss.global_position
		for pulse_scale in [Vector2.ONE, Vector2(1.2, 1.2), Vector2.ONE]:
			boss.scale = pulse_scale
			for _phase in range(8):
				boss.call("_process", 0.25)
				var icon := _icon(boss, "Block")
				var viewport_bounds: Rect2 = icon.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, icon.size)
				_expect(viewport_bounds.position.y >= 132.0,
					"boss intent clears top bar throughout bob: actor scale %s, parent scale %s, top %.3f"
					% [pulse_scale, parent_scale, viewport_bounds.position.y])
				_expect(boss.global_position.is_equal_approx(planted) and boss.scale == pulse_scale,
					"intent correction leaves actor position and block pulse scale unchanged")
		host.queue_free()
		await get_tree().process_frame


func _test_status_predictions() -> void:
	var battle := FAKE_BATTLE.new()
	add_child(battle)
	battle.setup()
	var enemy := _enemy({"type": "attack_status", "amount": 12, "hits": 2, "status": "weak"})
	battle.combat.add_enemy(enemy.creature)
	enemy.combat = battle.combat
	enemy.creature.add_status("weak", 2)
	battle.player.add_status("vulnerable", 2)
	enemy.update_intent_display()
	var attack := enemy.find_child("IntentAttack", true, false)
	var label := attack.find_child("IntentValue", true, false) as Label
	_expect(label != null and label.text == "9×2", "Weak and Vulnerable use the shared projected per-hit result (9)")
	_expect(_path(_icon(enemy, "Attack")).ends_with("/combat/intents/attack_2.png"), "status-adjusted total 18 chooses tier 2")
	_expect(_icon(enemy, "Debuff") != null, "status attack keeps the separate generic debuff icon")
	battle.player.add_status("intangible", 1)
	enemy.update_intent_display()
	_expect(label != null and label.text == "1×2", "status refresh updates the existing per-hit label in place")
	_expect(_path(_icon(enemy, "Attack")).ends_with("/combat/intents/attack_1.png"), "Intangible lowers total 2 to tier 1")
	enemy.queue_free()
	battle.queue_free()
	await get_tree().process_frame


func _test_animation_lifecycle() -> void:
	var enemy := _enemy({"type": "attack_status", "amount": 8, "status": "weak"})
	await get_tree().process_frame
	var attack := enemy.find_child("IntentAttack", true, false) as Control
	var debuff := enemy.find_child("IntentDebuff", true, false) as Control
	_expect(attack.modulate.a == 0.0, "new intent enters from transparent")
	if not enemy.has_method("_process"):
		_expect(false, "intent display advances independent per-icon float and fade lifecycles")
	else:
		enemy.call("_process", 0.5)
		_expect(is_equal_approx(attack.modulate.a, 0.5), "entry fade reaches half opacity after 0.5s")
		var first := attack.find_child("Floating", true, false) as Control
		var second := debuff.find_child("Floating", true, false) as Control
		_expect(first != null and is_equal_approx(first.position.y, -9.0), "bob reaches -9px at quarter period")
		_expect(second != null and absf(second.position.y - (-8.775)) < 0.02, "second icon has 0.3rad phase offset")
		enemy.call("_process", 0.5)
		_expect(is_equal_approx(attack.modulate.a, 1.0), "entry finishes at 1s")
		_expect(first != null and is_equal_approx(first.position.y, -4.0), "bob crosses its -4px base at half period")
		enemy.update_intent_display()
		_expect(enemy.find_child("IntentAttack", true, false) == attack and attack.modulate.a == 1.0,
			"unchanged refresh preserves the live cell without replaying appearance")
		enemy.call("_process", 1.0)
		_expect(first != null and is_equal_approx(first.position.y, -4.0), "bob returns after its full 2s period")
		enemy.global_position = Vector2(500, 400)
		var planted := enemy.global_position
		enemy.call("_process", 0.5)
		_expect(_icon(enemy, "Attack").get_global_rect().position.y >= 132.0,
			"full bob envelope stays below the shared top bar for a high actor")
		_expect(enemy.global_position == planted, "intent safety leaves the actor planted")
		_set_action(enemy, {"type": "block", "amount": 6})
		_expect(is_instance_valid(attack) and attack.get_parent() != enemy.get("_intent_cells"), "old intent remains available for its exit fade")
		enemy.call("_process", 0.25)
		_expect(is_equal_approx(attack.modulate.a, 0.5), "exit reaches half opacity after 0.25s")
		enemy.call("_process", 0.25)
		await get_tree().process_frame
		_expect(not is_instance_valid(attack), "old intent releases after its 0.5s fade")
	enemy.queue_free()
	await get_tree().process_frame
