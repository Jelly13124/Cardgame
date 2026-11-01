extends Node

const CARD_UPGRADE_MODAL = preload("uid://gq5b8t1mbeti")  # res://ui/rest/card_upgrade_modal.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_ROOM = preload("uid://cyvheo458ghoj")  # res://ui/events/event_room.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const RUN_DECK_VIEWER_MODAL = preload("uid://jvxfh15gtinx")  # res://ui/common/run_deck_viewer_modal.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var map_source := FileAccess.get_file_as_string("res://ui/map/map_scene.gd")  # path-ok: reads source text
	_expect(
		not map_source.contains("_hide_top_bar_for_page"),
		"in-run pages never hide the shared top bar",
	)
	_expect(
		map_source.contains("layer.layer = RUN_TOP_BAR.CANVAS_LAYER"),
		"map mounts the shared top bar on the persistent HUD layer",
	)
	var shop_source := FileAccess.get_file_as_string("res://ui/shop/merchant_room.gd")  # path-ok: reads source text
	_expect(
		shop_source.contains("topbar_layer.layer = RUN_TOP_BAR.CANVAS_LAYER"),
		"shop mounts the same shared top bar on the persistent HUD layer",
	)

	var battle_scene: Node = load("uid://dnhj5pp3c1v2l").instantiate()  # res://ui/battle/battle_screen.tscn
	var battle_top_layer := battle_scene.get_node_or_null("TopBarLayer") as CanvasLayer
	_expect(battle_top_layer != null, "battle exposes the persistent top-bar layer")
	if battle_top_layer != null:
		_expect(
			battle_top_layer.layer == RUN_TOP_BAR.CANVAS_LAYER,
			"battle uses the same persistent HUD layer as every other in-run screen",
		)
	battle_scene.free()

	var original_deck := RunManager.player_deck.duplicate(true)
	RunManager.player_deck = [{"card_id": "base:strike", "upgraded": false}]

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

	MODEL_DB.inject_dir("res://tests/fixtures/content_mod/", "mymod")
	var model = EVENT_POOL.instantiate("mymod:probe")
	model.begin()
	var event = EVENT_ROOM.new()
	event.model = model
	add_child(event)
	await _frames(5)
	var event_bg := event.find_child("EventBackground", true, false) as Control
	_expect(event_bg != null, "event exposes its page background")
	if event_bg != null:
		_expect(
			is_equal_approx(event_bg.offset_top, RUN_TOP_BAR.PAGE_ART_TOP),
			"event backdrop continues behind the transparent relic shelf",
		)
	_expect(event.find_child("EventTextVignette", true, false) == null, "the full-screen text vignette is gone")
	var portrait := event.find_child("EventPortrait", true, false) as Control
	var event_content := event.find_child("EventContent", true, false) as Control
	_expect(portrait != null and event_content != null, "event exposes its portrait and its content")
	if portrait != null and event_content != null:
		_expect(portrait.position.y >= RUN_TOP_BAR.BAR_HEIGHT, "the portrait stays below the top bar")
		_expect(event_content.position.y >= RUN_TOP_BAR.BAR_HEIGHT,
			"event copy and choices stay below the complete persistent top bar")
		_expect(portrait.position.x + portrait.size.x <= event_content.position.x,
			"the portrait sits left of the text column")
		var art := portrait.find_child("EventPortraitArt", true, false) as TextureRect
		_expect(art != null, "the portrait has an art rect")
		if art != null:
			art.texture = PlaceholderTexture2D.new()
			(art.texture as PlaceholderTexture2D).size = Vector2(1408, 768)
			_expect(is_equal_approx(portrait.size.y, 768.0) and is_equal_approx(art.size.y, 768.0),
				"1408x768 art is drawn at 1:1 height in the 768 frame")
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
