extends Node

const MAP_SCENE = preload("uid://d3x5b8wvg2q")  # res://ui/map/map_scene.tscn
const LOOT_REWARD = preload("uid://csl8exl41do23")  # res://ui/rewards/loot_reward.tscn
const RESULT_SCREEN = preload("uid://bxh1x1hy6fylv")  # res://ui/rewards/result_screen.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const TEST_SAVE_ROOT = preload("uid://c5pfll7nw68un")  # res://tests/support/test_save_root.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	TEST_SAVE_ROOT.use("rest_reward_ui")
	RunManager.start_new_run("base:cowboy_bill", [], 0, "RESTREWARD1")
	await _test_rest_choices()
	await _test_reward_pages()
	await _test_result_backing()
	TEST_SAVE_ROOT.release()
	if failures.is_empty():
		print("[OK] Rest and reward UI contract passed")
		get_tree().quit(0)
	else:
		push_error("Rest and reward UI contract failed: %s" % ", ".join(failures))
		get_tree().quit(1)


func _test_rest_choices() -> void:
	RunManager.set_max_health(80, true)
	RunManager.modify_health(-13)
	var map = MAP_SCENE.instantiate()
	add_child(map)
	map._open_rest_choice()
	await get_tree().process_frame
	var rest: Control = map.get_node("RestChoiceModal")
	var heal := rest.find_child("HealChoice", true, false) as Button
	var upgrade := rest.find_child("UpgradeChoice", true, false) as Button
	_expect(heal != null and upgrade != null, "rest offers visible heal and upgrade buttons")
	if heal != null and upgrade != null:
		var amount := heal.find_child("ChoiceDetail", true, false) as Label
		_expect(
			amount != null and amount.text == tr("UI_ROUTE_HEAL").format({"n": 13}),
			"the heal choice shows the 13 HP actually recoverable"
		)
		for button in [heal, upgrade]:
			var icon := button.find_child("ChoiceIcon", true, false) as TextureRect
			_expect(icon != null and icon.texture != null, "each rest action has a visible icon")
			_expect(
				button.get_global_rect().position.y >= RUN_TOP_BAR.BAR_HEIGHT,
				"rest controls stay below the complete run top bar"
			)
		heal.pressed.emit()
		_expect(RunManager.current_health == 80, "the heal choice restores the displayed HP")
		await get_tree().process_frame
		_expect(map.get_node_or_null("RestChoiceModal") == null, "choosing heal closes the rest site")
		await _test_rest_upgrade_and_leave(map)
	map.queue_free()
	await get_tree().process_frame


func _test_rest_upgrade_and_leave(map: Control) -> void:
	map._open_rest_choice()
	var rest := map.get_node("RestChoiceModal")
	var upgrade := rest.find_child("UpgradeChoice", true, false) as Button
	upgrade.pressed.emit()
	await get_tree().process_frame
	_expect(map.get_node_or_null("RestChoiceModal") == null, "upgrade opens the picker in place of rest")
	var back := map.find_child("BackButton", true, false) as Button
	_expect(back != null, "upgrade opens the card picker with a back button")
	if back == null:
		return
	back.pressed.emit()
	await get_tree().process_frame
	rest = map.get_node_or_null("RestChoiceModal")
	_expect(rest != null, "back from the upgrade picker returns to the rest choices")
	if rest == null:
		return
	for button: Button in rest.find_children("*", "Button", true, false):
		if button.text == tr("UI_SHOP_LEAVE"):
			button.pressed.emit()
			await get_tree().process_frame
			_expect(map.get_node_or_null("RestChoiceModal") == null, "leave returns to the route")
			return
	_expect(false, "the rest site keeps a leave button")


func _test_reward_pages() -> void:
	var loot = LOOT_REWARD.instantiate()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(loot)
	await get_tree().process_frame
	var backing := loot.get_node_or_null("RewardBackdrop") as ColorRect
	_expect(
		backing != null and backing.offset_top == RUN_TOP_BAR.PAGE_ART_TOP,
		"reward backing begins behind the relic shelf and leaves the main bar clear"
	)
	_expect(
		loot.loot_root.get_global_rect().position.y >= RUN_TOP_BAR.BAR_HEIGHT,
		"loot content starts below the complete run top bar"
	)

	loot._open_card_draft()
	await get_tree().process_frame
	_expect(
		loot.draft_overlay.get_global_rect().position.y >= RUN_TOP_BAR.BAR_HEIGHT,
		"draft content starts below the complete run top bar"
	)
	_expect(loot.draft_card_container.get_child_count() == 3, "draft still offers three cards")
	var ancestor: Node = loot.draft_card_container.get_parent()
	while ancestor != null and ancestor != loot.draft_overlay:
		_expect(
			not (ancestor is Panel or ancestor is PanelContainer),
			"draft cards have no decorative tray"
		)
		ancestor = ancestor.get_parent()
	loot.draft_skip_button.pressed.emit()
	_expect(loot.loot_root.visible, "skipping the draft returns to the available loot")
	layer.queue_free()


func _test_result_backing() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var result := RESULT_SCREEN.new()
	layer.add_child(result)
	await get_tree().process_frame
	_expect(
		result.get_global_rect() == Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size),
		"settlement fills the viewport when mounted on a CanvasLayer"
	)
	var backing := result.get_node_or_null("ResultBackdrop") as ColorRect
	_expect(
		backing != null and backing.color.a >= 0.9,
		"settlement copy has a dark backing even over a bright battle or event"
	)
	layer.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("[FAIL] ", message)
