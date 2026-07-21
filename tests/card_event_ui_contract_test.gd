extends Node

const CARD_UPGRADE_MODAL = preload("res://run_system/ui/card_upgrade_modal.gd")
const EVENT_MODAL = preload("res://run_system/ui/event_modal.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")
const RUN_DECK_VIEWER_MODAL = preload("res://run_system/ui/run_deck_viewer_modal.gd")

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var map_source := FileAccess.get_file_as_string("res://run_system/ui/map_scene.gd")
	_expect(
		not map_source.contains("_hide_top_bar_for_page"),
		"in-run pages never hide the shared top bar",
	)
	_expect(
		map_source.contains("layer.layer = RUN_TOP_BAR.CANVAS_LAYER"),
		"map mounts the shared top bar on the persistent HUD layer",
	)
	var shop_source := FileAccess.get_file_as_string("res://run_system/ui/shop_scene.gd")
	_expect(
		shop_source.contains("topbar_layer.layer = RUN_TOP_BAR.CANVAS_LAYER"),
		"shop mounts the same shared top bar on the persistent HUD layer",
	)

	var battle_scene: Node = load("res://battle_scene/battle_scene.tscn").instantiate()
	var battle_top_layer := battle_scene.get_node_or_null("TopBarLayer") as CanvasLayer
	_expect(battle_top_layer != null, "battle exposes the persistent top-bar layer")
	if battle_top_layer != null:
		_expect(
			battle_top_layer.layer == RUN_TOP_BAR.CANVAS_LAYER,
			"battle uses the same persistent HUD layer as every other in-run screen",
		)
	battle_scene.free()

	var original_deck := RunManager.player_deck.duplicate(true)
	RunManager.player_deck = [{"card_id": "strike", "upgraded": false}]

	var upgrade := CARD_UPGRADE_MODAL.new()
	add_child(upgrade)
	await _frames(5)
	var upgrade_bg := upgrade.find_child("UpgradeBackdrop", true, false) as Control
	_expect(upgrade_bg != null, "upgrade page exposes its content backdrop")
	if upgrade_bg != null:
		_expect(
			is_equal_approx(upgrade_bg.offset_top, RUN_TOP_BAR.PAGE_ART_TOP),
			"upgrade art continues behind the transparent relic shelf",
		)
	var upgrade_scroll := upgrade.find_child("DeckScroll", true, false) as Control
	_expect(upgrade_scroll != null, "upgrade page exposes its interactive content")
	if upgrade_scroll != null:
		_expect(
			upgrade_scroll.offset_top >= RUN_TOP_BAR.BAR_HEIGHT,
			"upgrade cards stay below the complete persistent top bar",
		)
	for frame_name in ["UpgradePreviewFrameBase", "UpgradePreviewFrameUpgraded"]:
		var frame := upgrade.find_child(frame_name, true, false) as Control
		_expect(frame != null, "%s exists" % frame_name)
		if frame != null:
			_expect(frame.custom_minimum_size.x <= 276.0, "%s stays close to card width" % frame_name)
			_expect(frame.custom_minimum_size.y <= 380.0, "%s stays close to card height" % frame_name)
			_expect(
				bool(frame.size_flags_vertical & Control.SIZE_SHRINK_CENTER),
				"%s cannot stretch into a tall empty holder" % frame_name,
			)
			var outline := frame.get_node_or_null("UpgradePreviewHoverOutline") as Control
			_expect(outline != null, "%s exposes a hover-only highlight" % frame_name)
			if outline != null:
				_expect(not outline.visible, "%s has no permanent decorative frame" % frame_name)
				frame.mouse_entered.emit()
				_expect(outline.visible, "%s highlights only on mouse hover" % frame_name)
				frame.mouse_exited.emit()
				_expect(not outline.visible, "%s clears highlight after hover" % frame_name)
	upgrade.queue_free()
	await _frames(3)

	var event := EVENT_MODAL.new()
	event.event_data = {
		"id": "contract_event",
		"title": "Contract Event",
		"description": "Event copy floats directly over the scene.",
		"options": [{"text": "Continue", "effects": [], "result": "Done"}],
	}
	add_child(event)
	await _frames(5)
	var vignette := event.find_child("EventTextVignette", true, false) as TextureRect
	var event_bg := event.find_child("EventBackground", true, false) as Control
	_expect(event_bg != null, "event exposes its page background")
	if event_bg != null:
		_expect(
			is_equal_approx(event_bg.offset_top, RUN_TOP_BAR.PAGE_ART_TOP),
			"event art continues behind the transparent relic shelf",
		)
	var event_content := event.find_child("EventContent", true, false) as Control
	_expect(event_content != null, "event exposes its interactive content")
	if event_content != null:
		_expect(
			event_content.offset_top >= RUN_TOP_BAR.BAR_HEIGHT,
			"event copy and choices stay below the complete persistent top bar",
		)
	_expect(vignette != null, "event uses a named unboxed text vignette")
	if vignette != null:
		_expect(
			vignette.texture is GradientTexture2D,
			"event text support is a soft gradient, not a rectangular backing panel",
		)
	event.queue_free()
	await _frames(3)

	var deck_viewer := RUN_DECK_VIEWER_MODAL.new()
	add_child(deck_viewer)
	await _frames(5)
	var deck_background := deck_viewer.find_child("RunDeckBackground", true, false) as Control
	_expect(deck_background != null, "run deck exposes its content background")
	if deck_background != null:
		_expect(
			is_equal_approx(deck_background.offset_top, RUN_TOP_BAR.PAGE_ART_TOP),
			"run-deck art continues behind the transparent relic shelf",
		)
	var deck_content := deck_viewer.find_child("RunDeckContent", true, false) as Control
	_expect(deck_content != null, "run deck exposes its interactive content")
	if deck_content != null:
		_expect(
			deck_content.offset_top >= RUN_TOP_BAR.BAR_HEIGHT,
			"run-deck cards stay below the complete persistent top bar",
		)
	deck_viewer.queue_free()
	RunManager.player_deck = original_deck
	await _frames(3)

	if failures.is_empty():
		print("[OK] Card-upgrade and event UI contracts passed")
		get_tree().quit(0)
		return
	push_error("Card/event UI contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
