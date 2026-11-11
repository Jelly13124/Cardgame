extends Node

const CARD_UPGRADE_MODAL = preload("uid://gq5b8t1mbeti")  # res://ui/rest/card_upgrade_modal.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_ROOM = preload("uid://cyvheo458ghoj")  # res://ui/events/event_room.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const RUN_DECK_VIEWER_MODAL = preload("uid://jvxfh15gtinx")  # res://ui/common/run_deck_viewer_modal.gd
const CARD_FACTORY_SCENE = preload("uid://diap3gdfbqvjv")  # res://ui/battle/card_framework_adapters/my_card_factory.tscn
const MERCHANT_CARD_REMOVAL = preload("uid://cb444odpyv0bh")  # res://ui/shop/merchant_card_removal.gd

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
	var view_upgrades := upgrade.find_child("ViewUpgrades", true, false) as CheckBox
	_expect(
		view_upgrades != null
		and view_upgrades.get_theme_icon("checked").resource_path.ends_with("/kit/checkbox_checked.png")
		and view_upgrades.get_theme_icon("unchecked").resource_path.ends_with("/kit/checkbox_unchecked.png"),
		"the upgrade toggle displays the shared checkbox artwork"
	)
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
	await _test_removal_preview_state()

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
	var deck_title := deck_viewer.find_child("RunDeckTitle", true, false) as Label
	var deck_close := deck_viewer.find_child("RunDeckClose", true, false) as Button
	_expect(deck_title != null and deck_title.global_position.y >= RUN_TOP_BAR.BAR_HEIGHT,
		"deck title is visible below the persistent bar")
	_expect(deck_close != null and deck_close.global_position.y >= RUN_TOP_BAR.BAR_HEIGHT,
		"deck close button is clickable below the persistent bar")
	var grid := deck_viewer.find_child("CardGrid", true, false) as GridContainer
	_expect(grid != null and grid.get_child_count() == 1, "the shared grid shows the run card")
	if grid != null:
		_expect(grid.find_children("*", "Panel", true, false).is_empty(),
			"deck card slots do not draw permanent preview frames")
	deck_viewer.queue_free()
	RunManager.player_deck = original_deck
	await _frames(3)

	if failures.is_empty():
		print("[OK] Card-upgrade and event UI contracts passed")
		get_tree().quit(0)
		return
	push_error("Card/event UI contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_removal_preview_state() -> void:
	var factory := CARD_FACTORY_SCENE.instantiate()
	add_child(factory)
	factory.card_size = Vector2(208, 286)
	var removal := MERCHANT_CARD_REMOVAL.new()
	removal.set("_card_factory", factory)
	add_child(removal)
	var wrapper := removal.call("_card_choice", "base:strike", "preview-only") as Control
	add_child(wrapper)
	await _frames(3)
	_expect(wrapper.custom_minimum_size == Vector2(180, 260), "removal keeps its existing input slot geometry")
	_expect(
		not wrapper.has_theme_stylebox_override("panel")
		and not wrapper.get_children().any(func(child): return child is Panel),
		"the normal removal preview has a transparent wrapper without a decorative panel"
	)
	var card: Control = null
	var pick: Button = null
	for child in wrapper.get_children():
		if child.has_method("update_playable"):
			card = child
		elif child is Button:
			pick = child
	_expect(card != null and pick != null, "removal exposes the original card and its input button")
	if card != null and pick != null:
		_expect(
			card.position == Vector2(10, 20)
			and card.scale.is_equal_approx(Vector2.ONE * (160.0 / 208.0))
			and card.get("suppress_playable_glow") == true,
			"removal preserves the card geometry and suppresses the hand playability cue"
		)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:  # bare-ok: Godot button theme state
			_expect(pick.get_theme_stylebox(state) is StyleBoxEmpty, "removal input adds no %s frame" % state)
		var highlight := card.get("highlight") as Control
		_expect(highlight != null, "removal reuses the card's shape-hugging highlight")
		if highlight != null:
			var material := highlight.material as ShaderMaterial
			_expect(
				highlight.get_parent() == card.get_node("FrontFace")
				and material != null and material.shader.resource_path.ends_with("/card_highlight.gdshader")
				and not bool(highlight.call("is_shown")),
				"the existing card silhouette highlight starts hidden"
			)
			pick.mouse_entered.emit()
			_expect(bool(highlight.call("is_shown")), "removal hover requests the close card outline")
			await get_tree().create_timer(0.55).timeout
			_expect(
				material != null and float(material.get_shader_parameter("width_px")) > 0.0,
				"the hover outline becomes visible through the existing card shader"
			)
			pick.mouse_exited.emit()
			_expect(
				not bool(highlight.call("is_shown"))
				and material != null and is_zero_approx(float(material.get_shader_parameter("width_px"))),
				"removal clears its close outline immediately when hover ends"
			)
	wrapper.queue_free()
	removal.queue_free()
	factory.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
