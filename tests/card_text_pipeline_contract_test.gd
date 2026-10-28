extends Node

## Card text numbers come from the shared pipeline: in battle, a Shoot card
## with 3 Strength, 2 Loaded and Weak reads 4 (floor((3 + 3 + 2) × 0.5)) —
## the same number the targeting preview and the hit use.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://battle_scene/battle_scene.tscn
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)  # current_scene must be a child of the root
	var previous_scene := get_tree().current_scene
	get_tree().current_scene = battle
	for _i in range(4):
		await get_tree().process_frame
	battle.player.strength = 3
	battle.player.creature.add_status("weak", 1)
	battle.player.creature.add_status("loaded", 2)
	var card = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:strike"))
	await get_tree().process_frame
	_expect(card != null, "a Shoot card joins the hand")
	if card:
		var values: Dictionary = COMBAT_EFFECTS.preview_effect_values(battle.combat, card.instance)
		_expect(int(values.get(0, -1)) == 4, "pipeline previews Shoot at 4 (got %s)" % [values])
		card.update_display()
		var text: String = card.desc_label.get_parsed_text()
		_expect(text.contains("Deal 4 ("), "card text shows the pipeline number 4 (text: %s)" % text)
	var deal := tr("UI_BATTLE_DESC_DEAL_SCALING")
	var block := tr("UI_BATTLE_DESC_BLOCK_SCALING")
	_expect(deal.contains("#ff7a5c") and not deal.contains("#8b0000"), "Strength part of card numbers is readable red (%s)" % deal)
	_expect(block.contains("#8fb8ff") and not block.contains("#4444ff"), "Constitution part of card numbers is readable blue (%s)" % block)
	get_tree().current_scene = previous_scene
	battle.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("[OK] card text pipeline contract passed")
		get_tree().quit(0)
		return
	push_error("card text pipeline contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
