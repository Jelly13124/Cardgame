extends Node

## The intent view must classify projected total damage, retain live cells on
## status refresh, and let its own entry/exit/bob lifecycle finish smoothly.
const ENEMY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd

## Only the entry source is varied: production rendering, layout and lifecycle
## remain real so repeated categories cannot hide behind a kind-keyed map.
class OrderedIntentFixture:
	extends ENEMY

	func _intent_entries(action: Dictionary) -> Array[Dictionary]:
		var entries := super._intent_entries(action)
		if bool(action.get("test_reverse", false)):
			entries.reverse()
		if bool(action.get("test_duplicate", false)):
			entries.append(entries[0].duplicate())
		return entries


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
	await _test_same_kind_action_replacement()
	await _test_multi_intent_slot_changes()
	await _test_reordered_and_repeated_categories()
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
	attack = enemy.find_child("IntentAttack", true, false)
	value = attack.find_child("IntentValue", true, false) as Label
	marker = attack.find_child("MultiMarker", true, false) as TextureRect
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
	enemy.call("_process", 1.0)
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
	_expect(enemy.find_child("IntentAttack", true, false) == attack and attack.modulate.a == 1.0,
		"status-only tier changes retain the visible slot without replaying its reveal")
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


## A different move with the same category must not overwrite its outgoing
## artwork or skip the reveal, while live prediction changes remain in place.
func _test_same_kind_action_replacement() -> void:
	var enemy := _enemy({"type": "attack", "amount": 4})
	await get_tree().process_frame
	enemy.call("_process", 1.0)
	var old := enemy.find_child("IntentAttack", true, false) as Control
	var old_icon := old.get_node("Floating/Icon") as TextureRect
	var old_position := old.global_position
	_set_action(enemy, {"type": "attack", "amount": 20})
	var current := enemy.find_child("IntentAttack", true, false) as Control
	_expect(current != old, "a new same-kind action gets its own reveal cell")
	_expect(current.modulate.a == 0.0, "same-kind action starts its reveal from transparent")
	_expect(_path(_icon(enemy, "Attack")).ends_with("/intents/attack_3.png"),
		"new same-kind action has the correct tier before the next frame")
	_expect((current.get_node("Floating/IntentValue") as Label).text == "20",
		"new same-kind action has the correct number before the next frame")
	_expect(_path(old_icon).ends_with("/intents/attack_1.png")
		and (old.get_node("Floating/IntentValue") as Label).text == "4",
		"outgoing same-kind action keeps its original icon and number")
	_expect(old.get_parent() != enemy.get("_intent_cells")
		and old.global_position.is_equal_approx(old_position),
		"outgoing same-kind action leaves the active layout without moving")
	enemy.call("_process", 0.25)
	_expect(is_equal_approx(old.modulate.a, 0.5) and is_equal_approx(current.modulate.a, 0.25),
		"old and new same-kind actions use separate exit and entry fades")
	enemy.update_intent_display()
	_expect(enemy.find_child("IntentAttack", true, false) == current
		and is_equal_approx(current.modulate.a, 0.25),
		"an unchanged refresh does not restart an unfinished action reveal")
	_set_action(enemy, {"type": "attack", "amount": 9})
	var latest := enemy.find_child("IntentAttack", true, false) as Control
	_expect(latest != current and latest != old
		and _path(_icon(enemy, "Attack")).ends_with("/intents/attack_2.png"),
		"a rapid third action immediately owns the current slot and correct artwork")
	_expect((current.get_node("Floating/IntentValue") as Label).text == "20",
		"rapid replacement does not overwrite the previous outgoing number")
	enemy.call("_process", 0.5)
	await get_tree().process_frame
	_expect(not is_instance_valid(old) and not is_instance_valid(current),
		"rapid replacements release both outgoing cells after their fades")
	_expect(is_instance_valid(latest) and is_equal_approx(latest.modulate.a, 0.5),
		"retiring cells cannot remove or restart the newest action")
	enemy.queue_free()
	await get_tree().process_frame


## Buff moves from the second slot of a compound move to the first slot of
## the next move. The outgoing group must retain its old ordering and phase.
func _test_multi_intent_slot_changes() -> void:
	var enemy := _enemy({"type": "reflective_plating", "amount": 8, "thorns": 3})
	await get_tree().process_frame
	enemy.call("_process", 1.0)
	var cells := enemy.get("_intent_cells") as HBoxContainer
	var old_block := cells.get_child(0) as Control
	var old_buff := cells.get_child(1) as Control
	var old_block_position := old_block.global_position
	var old_buff_position := old_buff.global_position
	_set_action(enemy, {"type": "buff_self", "amount": 7})
	var current_buff := enemy.find_child("IntentBuff", true, false) as Control
	_expect(cells.get_child_count() == 1 and cells.get_child(0) == current_buff,
		"new single intent occupies only its ordered active slot")
	_expect(current_buff != old_buff and current_buff.modulate.a == 0.0,
		"moving a category to another slot reveals a new action rather than reusing its old cell")
	_expect((current_buff.get_node("Floating/IntentValue") as Label).text == "7"
		and (old_buff.get_node("Floating/IntentValue") as Label).text == "3",
		"slot changes preserve outgoing values while installing the next move immediately")
	_expect(old_block.global_position.is_equal_approx(old_block_position)
		and old_buff.global_position.is_equal_approx(old_buff_position),
		"outgoing compound intents keep both original slot positions")
	_expect(is_equal_approx(float(old_buff.get_meta("intent_phase")), 0.3)
		and is_equal_approx(float(current_buff.get_meta("intent_phase")), 0.0),
		"outgoing and incoming phase offsets belong to their own ordered slots")
	await get_tree().process_frame
	_expect(old_block.global_position.is_equal_approx(old_block_position)
		and old_buff.global_position.is_equal_approx(old_buff_position),
		"new layout reflow does not drag the outgoing compound group")
	enemy.call("_process", 0.5)
	await get_tree().process_frame
	_expect(not is_instance_valid(old_block) and not is_instance_valid(old_buff),
		"every outgoing compound slot is released after the exit fade")
	_set_action(enemy, {"type": "attack_status", "amount": 10, "status": "weak"})
	_expect(cells.get_child_count() == 2
		and cells.get_child(0).name == "IntentAttack"
		and cells.get_child(1).name == "IntentDebuff",
		"the next compound action restores its declared order without retired cells")
	_expect(_path(_icon(enemy, "Attack")).ends_with("/intents/attack_2.png")
		and _path(_icon(enemy, "Debuff")).ends_with("/intents/debuff.png"),
		"all compound action icons are installed before their reveal")
	enemy.queue_free()
	await get_tree().process_frame


func _test_reordered_and_repeated_categories() -> void:
	var source := ENEMY.create("base:trash_robot")
	var enemy := OrderedIntentFixture.new()
	enemy.creature = source.creature
	enemy.sprite_id = source.sprite_id
	source.free()
	enemy.action_pattern = [{"type": "reflective_plating", "amount": 8, "thorns": 3}]
	add_child(enemy)
	enemy.set_process(false)
	await get_tree().process_frame
	enemy.call("_process", 1.0)
	var cells := enemy.get("_intent_cells") as HBoxContainer
	var old_first := cells.get_child(0) as Control
	var old_second := cells.get_child(1) as Control
	_set_action(enemy, {"type": "reflective_plating", "amount": 8, "thorns": 3, "test_reverse": true})
	_expect(cells.get_child_count() == 2
		and _path(cells.get_child(0).get_node("Floating/Icon") as TextureRect).ends_with("/intents/buff.png")
		and _path(cells.get_child(1).get_node("Floating/Icon") as TextureRect).ends_with("/intents/block.png"),
		"a reordered compound move follows its declared entry order")
	_expect(cells.get_child(0) != old_second and cells.get_child(1) != old_first
		and is_equal_approx(float(old_first.get_meta("intent_phase")), 0.0)
		and is_equal_approx(float(old_second.get_meta("intent_phase")), 0.3),
		"reordering cannot migrate outgoing identities or phase offsets into the new slots")
	_set_action(enemy, {"type": "attack", "amount": 4, "test_duplicate": true})
	_expect(cells.get_child_count() == 2, "two equal categories retain two independent ordered slots")
	if cells.get_child_count() == 2:
		_expect(cells.get_child(0) != cells.get_child(1)
			and _path(cells.get_child(0).get_node("Floating/Icon") as TextureRect).ends_with("/intents/attack_1.png")
			and _path(cells.get_child(1).get_node("Floating/Icon") as TextureRect).ends_with("/intents/attack_1.png"),
			"repeated categories each receive the correct visual before reveal")
		_expect(is_equal_approx(float(cells.get_child(0).get_meta("intent_phase")), 0.0)
			and is_equal_approx(float(cells.get_child(1).get_meta("intent_phase")), 0.3),
			"repeated categories keep independent slot phases")
	enemy.call("_process", 1.0)
	await get_tree().process_frame
	_expect(cells.get_child_count() == 2, "retired compound cells cannot remove repeated active categories")
	enemy.queue_free()
	await get_tree().process_frame
