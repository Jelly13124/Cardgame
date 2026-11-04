extends Node

## Card-play smoothness: several player changes in one frame refresh the hand
## once, a card whose text did not change is not re-typeset, and profile
## saves wait until the battle is over instead of writing mid-combat.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd

const PROBE_CARD := "test_only:perf_probe_seen_card"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	await test_player_changes_in_one_frame_refresh_the_hand_once()
	await test_unchanged_card_text_is_not_rebuilt()
	await test_profile_saves_wait_for_the_battle_to_end()
	if failures.is_empty():
		print("[OK] battle refresh perf passed")
		get_tree().quit(0)
		return
	push_error("battle refresh perf failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _battle() -> Node:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "PERF0001")
	RunManager.current_encounter = ["base:scrap_rat"]
	RunManager.last_battle_node_type = "enemy"
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(30):
		await get_tree().process_frame
	return battle


func _free(battle: Node) -> void:
	get_tree().current_scene = null
	battle.queue_free()
	await get_tree().process_frame


func test_player_changes_in_one_frame_refresh_the_hand_once() -> void:
	var battle = await _battle()
	await get_tree().process_frame
	var before: int = battle.hand_refresh_count
	battle.player.creature.energy_changed.emit(2)
	battle.player.creature.block_changed.emit(5)
	battle.player.creature.health_changed.emit(40)
	battle.player.creature.stats_changed.emit()
	_expect(battle.hand_refresh_count == before, "player signals do not rebuild the hand synchronously")
	await get_tree().process_frame
	_expect(battle.hand_refresh_count == before + 1, "four player signals in one frame refresh the hand once (got %d)" % (battle.hand_refresh_count - before))
	await _free(battle)


func test_unchanged_card_text_is_not_rebuilt() -> void:
	var battle = await _battle()
	var card = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:strike"))
	await get_tree().process_frame
	battle.refresh_hand_ui()
	var builds: int = card.description_builds
	battle.refresh_hand_ui()
	battle.refresh_hand_ui()
	_expect(card.description_builds == builds, "refreshing an unchanged card does not re-typeset its text")
	var text_before: String = card.desc_label.get_parsed_text()
	battle.player.creature.strength += 4
	battle.refresh_hand_ui()
	_expect(card.description_builds == builds + 1, "a stat change that alters the text re-typesets it once")
	_expect(card.desc_label.get_parsed_text() != text_before, "the new damage number is shown")
	await _free(battle)


func test_profile_saves_wait_for_the_battle_to_end() -> void:
	var battle = await _battle()
	var path: String = SAVE_IO.path(MetaProgress._meta_path())
	MetaProgress.mark_card_seen(PROBE_CARD)
	_expect(not _profile_mentions(path, PROBE_CARD), "a card seen mid-combat is not written to disk yet")
	_expect(MetaProgress.cards_seen.has(PROBE_CARD), "the card is still recorded in memory")
	await _free(battle)
	_expect(_profile_mentions(path, PROBE_CARD), "leaving the battle writes the deferred profile save")
	MetaProgress.mark_card_seen(PROBE_CARD + "_after")
	_expect(_profile_mentions(path, PROBE_CARD + "_after"), "outside combat the profile saves immediately")


func _profile_mentions(path: String, text: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains(text)
