extends Node

const HUD = preload("uid://dqn0nfitycf2d")  # res://ui/battle/character_hud.gd
const ENEMY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_health_and_block()
	_test_live_attack_severity()
	if failures.is_empty():
		print("[OK] combat HUD readability")
		get_tree().quit(0)
		return
	push_error("combat HUD readability failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_health_and_block() -> void:
	var hud := HUD.new()
	add_child(hud)
	var frame := hud.get_node("HpFrame") as NinePatchRect
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	var hp_label := hud.get_node("HpFrame/HpLabel")
	var shield := hud.get_node("BlockBadge") as TextureRect
	var shield_label := shield.get_node("BlockLabel") as Label
	_expect(
		frame != null and frame.texture != null
		and frame.texture.resource_path.ends_with("/hp_bar_frame.png")
		and frame.size == Vector2(200, 18)
		and frame.patch_margin_left > 0 and frame.patch_margin_right > 0,
		"health uses the original frame at its native height with preserved caps"
	)
	_expect(
		fill != null and fill.texture_progress != null
		and fill.texture_progress.resource_path.ends_with("/hp_bar_fill.png")
		and fill.nine_patch_stretch,
		"health uses the original separately clipped fill"
	)
	hud.update_stats(31, 50, 8)
	_expect(fill != null and is_equal_approx(fill.ratio, 0.62), "Block preserves partial HP")
	_expect(hp_label.get("text") == "31/50", "HP text shows current and max")
	_expect(shield.visible and shield_label.text == "8", "Block stays in its separate shield")
	hud.update_stats(0, 50, 8)
	_expect(fill != null and is_zero_approx(fill.ratio), "Block does not fill an empty HP bar")
	_expect(hp_label.get("text") == "0/50" and shield.visible, "zero HP and Block remain distinct")
	hud.update_stats(0, 50, 0)
	_expect(not shield.visible, "zero Block hides the shield")
	hud.free()


func _test_live_attack_severity() -> void:
	var battle = FAKE_BATTLE.new()
	add_child(battle)
	battle.setup()
	var enemy := ENEMY.create("base:trash_robot")
	enemy.combat = battle.combat
	battle.combat.add_enemy(enemy.creature)
	enemy.action_pattern = [{"type": "attack", "amount": 12}]
	add_child(enemy)

	var high := _attack_icon(enemy).custom_minimum_size.x
	_expect(_attack_value(enemy) == "12", "attack shows the shared preview amount")
	enemy.creature.add_status("weak", 2)
	var medium := _attack_icon(enemy).custom_minimum_size.x
	_expect(_attack_value(enemy) == "6", "Weak refreshes the visible amount immediately")

	enemy.action_pattern = [{"type": "attack_status", "amount": 4, "status": "burn"}]
	enemy.update_intent_display()
	var low := _attack_icon(enemy).custom_minimum_size.x
	_expect(_attack_value(enemy) == "2", "attack with a status uses the same preview")
	_expect(enemy.find_child("IntentDebuff", true, false) != null, "status rider stays visible")
	_expect(low < medium and medium < high, "three live-damage tiers differ in sword size")
	_expect(high <= 32.0, "highest tier keeps the original glyph within its native size")
	_expect(
		_attack_icon(enemy).texture.resource_path.ends_with("/intent_attack.png"),
		"every tier uses the original sword glyph"
	)
	enemy.free()
	battle.free()


func _attack_icon(enemy: Node) -> TextureRect:
	return enemy.find_child("IntentAttack", true, false).get_node("Icon")


func _attack_value(enemy: Node) -> String:
	var value := enemy.find_child("IntentAttack", true, false).get_node("IntentValue") as Label
	return value.text


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("[FAIL] ", message)
