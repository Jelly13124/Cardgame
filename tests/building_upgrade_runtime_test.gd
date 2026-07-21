extends Node

const HOME_BASE = preload("res://run_system/ui/home_base_scene.tscn")

var failures: PackedStringArray = []
var _original_buildings: Dictionary
var _original_caps: int
var _original_scrap: int
var _original_bounty_shelf: Array
var _original_bounty_shelf_date: String


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_original_buildings = MetaProgress.buildings.duplicate(true)
	_original_caps = MetaProgress.caps
	_original_scrap = MetaProgress.scrap
	_original_bounty_shelf = MetaProgress.bounty_shelf.duplicate(true)
	_original_bounty_shelf_date = MetaProgress.bounty_shelf_date
	seed(20260714)

	# Exercise the real home-base routes without writing a test mutation to the
	# active save slot.  _simulate_unlock() below mirrors the successful backend
	# state transition and emits the same live-refresh signals, but deliberately
	# skips MetaProgress.save_progress().
	MetaProgress.buildings["clinic"] = 0
	MetaProgress.buildings["forge"] = 0
	MetaProgress.scrap = (
		int(MetaProgress.BUILDING_DEFS["clinic"].get("unlock_cost", 0))
		+ int(MetaProgress.BUILDING_DEFS["forge"].get("unlock_cost", 0))
		+ 100
	)
	MetaProgress.caps = 4440
	MetaProgress.bounty_shelf = ["war_profiteer", "elite_purge", "scavenger_haul"]
	# HomeBase refreshes a stale daily shelf and saves it. Pin the in-memory date
	# for this test so instantiation cannot write to the user's active slot.
	MetaProgress.bounty_shelf_date = Time.get_date_string_from_system()
	MetaProgress.emit_signal("scrap_changed", MetaProgress.scrap)
	MetaProgress.emit_signal("buildings_changed")

	var home := HOME_BASE.instantiate()
	add_child(home)
	await _frames(6)

	await _test_locked_clinic_route(home)
	await _test_locked_forge_route(home)
	await _test_forge_backdrop_lifecycle(home)
	await _test_accepted_building_surfaces(home)
	await _test_popover_does_not_reflow_services(home)

	home.queue_free()
	await _frames(2)
	MetaProgress.buildings = _original_buildings
	MetaProgress.caps = _original_caps
	MetaProgress.scrap = _original_scrap
	MetaProgress.bounty_shelf = _original_bounty_shelf
	MetaProgress.bounty_shelf_date = _original_bounty_shelf_date
	MetaProgress.emit_signal("scrap_changed", MetaProgress.scrap)
	MetaProgress.emit_signal("buildings_changed")

	if failures.is_empty():
		print("[OK] Building upgrade runtime flow passed")
		get_tree().quit(0)
		return
	push_error("Building upgrade runtime flow failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_locked_clinic_route(home: Node) -> void:
	home.call("_open_building_screen", "clinic")
	await _frames(4)

	var overlay := home.get_node_or_null("BuildingOverlay")
	_expect(overlay is CanvasLayer, "locked clinic opens the home BuildingOverlay route")
	if overlay == null:
		return

	var top_bar := overlay.find_child("BuildingTopBar", true, false) as Control
	var services := overlay.find_child("BuildingServicesScroll", true, false) as ScrollContainer
	var action := overlay.find_child("BuildingUpgradeButton", true, false) as Button
	_expect(top_bar != null, "locked clinic interior exposes the integrated building top bar")
	_expect(services != null, "clinic interior exposes BuildingServicesScroll")
	if services != null:
		_expect(not services.visible, "locked clinic hides BuildingServicesScroll")
	_expect(action != null, "locked clinic top bar exposes its upgrade action")
	if action != null:
		_expect(not action.disabled, "clinic upgrade action remains available before unlock")
		action.pressed.emit()
		await _frames(2)
		var popover := overlay.find_child("BuildingUpgradePopover", true, false) as Control
		_expect(popover != null, "clinic upgrade action opens the shared confirmation popover")
		if popover != null:
			_expect(
				popover.find_child("UpgradePopoverConfirm", true, false) is Button,
				"clinic upgrade popover exposes a confirmed Scrap action"
			)

	var overlay_before := overlay
	var services_before := services
	_expect(_simulate_unlock("clinic"), "clinic unlock state transition can be simulated")
	await _frames(4)

	_expect(
		home.get_node_or_null("BuildingOverlay") == overlay_before,
		"clinic interior remains open after unlock"
	)
	_expect(
		services_before != null and is_instance_valid(services_before) and services_before.visible,
		"clinic services reveal immediately after unlock"
	)

	if is_instance_valid(overlay_before):
		overlay_before.queue_free()
	await _frames(2)


func _test_locked_forge_route(home: Node) -> void:
	home.call("_open_forge_windows")
	await _frames(5)

	var window_layer := home.get_node_or_null("WindowLayer")
	_expect(window_layer is CanvasLayer, "locked forge opens through WindowLayer")
	if window_layer == null:
		return
	var forge := window_layer.get_node_or_null("ForgeWindow") as Control
	_expect(forge != null, "locked forge route creates ForgeWindow")
	_expect(
		window_layer.get_node_or_null("ForgeBackdrop") is TextureRect,
		"forge route mounts its interior backdrop"
	)
	if forge == null:
		return

	var header := forge.find_child("ForgeHeader", true, false) as Control
	var action := forge.find_child("ForgeUpgradeButton", true, false) as Button
	_expect(header != null, "locked ForgeWindow exposes its distinct integrated header")
	_expect(action != null, "locked ForgeWindow exposes its header upgrade action")
	if action != null:
		_expect(not action.disabled, "forge upgrade action remains available before unlock")
	_expect(
		forge.find_child("ForgeLockedHint", true, false) != null,
		"locked ForgeWindow shows the locked-service hint"
	)
	_expect(
		forge.find_child("ForgeNpcPortrait", true, false) == null,
		"locked ForgeWindow does not build forge service content"
	)
	_expect(
		_service_buttons(forge, action).is_empty(),
		"locked ForgeWindow has no forge service tabs or actions"
	)
	if action != null:
		action.pressed.emit()
		await _frames(2)
		var popover := forge.find_child("BuildingUpgradePopover", true, false) as Control
		_expect(popover != null, "forge upgrade action opens the shared confirmation popover")
		if popover != null:
			var cancel := popover.find_child("UpgradePopoverCancel", true, false) as Button
			if cancel != null:
				cancel.pressed.emit()
				await _frames(2)

	var forge_before := forge
	_expect(_simulate_unlock("forge"), "forge unlock state transition can be simulated")
	await _frames(5)

	_expect(
		window_layer.get_node_or_null("ForgeWindow") == forge_before,
		"ForgeWindow remains open after unlock"
	)
	_expect(
		is_instance_valid(forge_before)
		and forge_before.find_child("ForgeNpcPortrait", true, false) != null,
		"forge services build immediately after unlock"
	)
	_expect(
		is_instance_valid(forge_before)
		and not _service_buttons(forge_before, forge_before.find_child("ForgeUpgradeButton", true, false) as Button).is_empty(),
		"forge service tabs/actions appear after unlock"
	)
	if is_instance_valid(forge_before):
		forge_before.queue_free()
	await _frames(2)
	_expect(
		window_layer.get_node_or_null("ForgeBackdrop") == null,
		"closing ForgeWindow removes its backdrop while CharacterWindow may remain"
	)
	var character_window := window_layer.get_node_or_null("CharacterWindow")
	if character_window != null:
		character_window.queue_free()
	await _frames(2)


func _test_forge_backdrop_lifecycle(home: Node) -> void:
	home.call("_open_forge_windows")
	await _frames(4)
	var window_layer := home.get_node_or_null("WindowLayer")
	_expect(window_layer != null, "forge lifecycle test reuses WindowLayer")
	if window_layer == null:
		return
	var character_window := window_layer.get_node_or_null("CharacterWindow")
	var forge_window := window_layer.get_node_or_null("ForgeWindow")
	_expect(character_window != null and forge_window != null, "forge lifecycle opens both windows")
	_expect(window_layer.get_node_or_null("ForgeBackdrop") != null, "forge lifecycle opens one backdrop")
	if character_window != null:
		character_window.queue_free()
	await _frames(2)
	_expect(
		window_layer.get_node_or_null("ForgeBackdrop") != null,
		"closing CharacterWindow first keeps the active forge backdrop"
	)
	if forge_window != null:
		forge_window.queue_free()
	await _frames(2)
	_expect(
		window_layer.get_node_or_null("ForgeBackdrop") == null,
		"closing ForgeWindow last removes the backdrop without an input blocker"
	)


func _test_accepted_building_surfaces(home: Node) -> void:
	var npc_hooks := {
		"clinic": "ClinicCyberDoctorArt",
	}
	for building_id in ["clinic", "market", "outpost"]:
		MetaProgress.buildings[building_id] = 3
		MetaProgress.emit_signal("buildings_changed")
		home.call("_open_building_screen", building_id)
		await _frames(5)
		var overlay := home.get_node_or_null("BuildingOverlay")
		_expect(overlay != null, "%s T3 opens its real building surface" % building_id)
		if overlay == null:
			continue
		if npc_hooks.has(building_id):
			var npc := overlay.find_child(str(npc_hooks[building_id]), true, false) as TextureRect
			_expect(npc != null and npc.texture != null, "%s uses its delivered NPC texture" % building_id)
		if building_id == "clinic":
			_expect(
				overlay.find_children("ClinicAttribute_*", "PanelContainer", true, false).size() == 5,
				"clinic keeps five interactive permanent-attribute rows"
			)
			_expect(
				overlay.find_child("ClinicVitalsCard", true, false) != null
				and overlay.find_child("ClinicCapCard", true, false) != null,
				"clinic keeps the max-HP and binary-cap cards"
			)
		elif building_id == "market":
			_expect(
				overlay.find_child("MarketMerchantSceneSpacer", true, false) is Control,
				"market reserves the concept's left merchant scene inside the baked background"
			)
			_expect(
				overlay.find_child("MarketMutantVendorArt", true, false) == null,
				"market does not layer a second merchant over the baked merchant-and-counter background"
			)
			for shelf_contract in [
				["MarketToolShelf", 329.0],
				["MarketEquipmentShelf", 367.0],
				["MarketConversionPanel", 169.0],
			]:
				var shelf := overlay.find_child(str(shelf_contract[0]), true, false) as PanelContainer
				_expect(
					shelf != null
					and shelf.get_theme_stylebox("panel") is StyleBoxTexture,
					"market %s uses the generated full shelf-panel texture" % shelf_contract[0]
				)
				if shelf != null:
					_expect(
						is_equal_approx(shelf.custom_minimum_size.y, float(shelf_contract[1])),
						"market %s keeps the measured concept height" % shelf_contract[0]
					)
			var tool_cards := overlay.find_children(
				"MarketToolTile_*", "PanelContainer", true, false
			)
			_expect(
				tool_cards.size() == 5,
				"market renders exactly five full tool product cards"
			)
			for candidate in tool_cards:
				var tool_card := candidate as PanelContainer
				_expect(
					tool_card != null
					and tool_card.get_theme_stylebox("panel") is StyleBoxTexture,
					"every market tool offer uses the generated full-card texture"
				)
				if tool_card != null:
					_expect(
						tool_card.tooltip_text.is_empty(),
						"market tool cards disable Godot's native black tooltip"
					)
			var equipment_cards := overlay.find_children(
				"MarketEquipmentTile_*", "PanelContainer", true, false
			)
			_expect(
				equipment_cards.size() == 5,
				"market renders exactly five slot-specific full equipment product cards"
			)
			for candidate in equipment_cards:
				var equipment_card := candidate as PanelContainer
				_expect(
					equipment_card != null
					and equipment_card.get_theme_stylebox("panel") is StyleBoxTexture,
					"every market equipment offer uses its generated rarity-card texture"
				)
				if equipment_card != null:
					_expect(
						equipment_card.tooltip_text.is_empty(),
						"market equipment cards disable Godot's native black tooltip"
					)
			_expect(
				overlay.find_child("MarketConversionPanel", true, false) != null,
				"market keeps the bidirectional conversion service"
			)
			_expect(
				overlay.find_child("MarketConversionStrip", true, false) is HBoxContainer
				and overlay.find_children("MarketConversion_*_to_*", "PanelContainer", true, false).size() == 2,
				"market keeps both exchange directions in one compact horizontal strip"
			)
			for candidate in overlay.find_children(
				"MarketConversion_*_to_*", "PanelContainer", true, false
			):
				var conversion_row := candidate as PanelContainer
				_expect(
					conversion_row != null
					and conversion_row.get_theme_stylebox("panel") is StyleBoxTexture,
					"each market conversion row uses the generated exchange-row texture"
				)
			var price_buttons := _concept_price_buttons(overlay)
			_expect(
				price_buttons.size() == 10,
				"market renders one compact concept price plaque for every real offer"
			)
			for price_button in price_buttons:
				_expect(
					price_button.text.is_empty()
					and str(price_button.get_meta("currency_order", "")) == "amount_first"
					and price_button.find_child("CenteredCurrencyContent", false, false) != null,
					"market price plaque is amount-first, centered, and has no Buy verb"
				)
			if not tool_cards.is_empty() and not equipment_cards.is_empty():
				var first_tool := tool_cards[0] as PanelContainer
				var first_equipment := equipment_cards[0] as PanelContainer
				Tooltip.hide()
				first_tool.mouse_entered.emit()
				await get_tree().process_frame
				var tooltip_label := Tooltip.get("_label") as RichTextLabel
				_expect(
					bool(Tooltip.get("_visible"))
					and int(Tooltip.get("_owner_id")) == first_tool.get_instance_id(),
					"market tool card opens the owner-safe global tooltip"
				)
				_expect(
					tooltip_label != null and tooltip_label.text.contains("[b]"),
					"market tool tooltip includes a rich title instead of a bare description"
				)
				first_equipment.mouse_entered.emit()
				await get_tree().process_frame
				_expect(
					bool(Tooltip.get("_visible"))
					and int(Tooltip.get("_owner_id")) == first_equipment.get_instance_id(),
					"market equipment hover safely takes tooltip ownership"
				)
				first_tool.mouse_exited.emit()
				await get_tree().process_frame
				_expect(
					bool(Tooltip.get("_visible"))
					and int(Tooltip.get("_owner_id")) == first_equipment.get_instance_id(),
					"stale tool-card exit cannot hide the newer equipment tooltip"
				)
				first_equipment.mouse_exited.emit()
				await get_tree().process_frame
				_expect(
					not bool(Tooltip.get("_visible")),
					"market equipment exit hides only its own tooltip"
				)
		else:
			_expect(
				overlay.find_child("OutpostRobotCommanderArt", true, false) == null,
				"outpost deliberately keeps the service layout NPC-free"
			)
			for hook in ["OutpostPermanentPanel", "OutpostBountyPanel", "OutpostSafePanel"]:
				_expect(overlay.find_child(hook, true, false) != null, "outpost exposes %s" % hook)
			_expect(
				overlay.find_children("OutpostBountyPoster_*", "PanelContainer", true, false).size() == 3,
				"outpost renders the three free bounty posters in one row"
			)
		if is_instance_valid(overlay):
			overlay.queue_free()
		await _frames(2)


func _test_popover_does_not_reflow_services(home: Node) -> void:
	MetaProgress.buildings["market"] = 1
	MetaProgress.emit_signal("buildings_changed")
	home.call("_open_building_screen", "market")
	await _frames(5)
	var overlay := home.get_node_or_null("BuildingOverlay")
	_expect(overlay != null, "market opens for upgrade-popover geometry test")
	if overlay == null:
		return
	var services := overlay.find_child("BuildingServicesContent", true, false) as Control
	var upgrade := overlay.find_child("BuildingUpgradeButton", true, false) as Button
	_expect(services != null and upgrade != null, "market exposes service content and upgrade action")
	if services == null or upgrade == null:
		overlay.queue_free()
		return
	var position_before := services.global_position
	var size_before := services.size
	upgrade.pressed.emit()
	await _frames(3)
	_expect(
		overlay.find_child("BuildingUpgradePopover", true, false) != null,
		"market upgrade opens as an anchored popover"
	)
	_expect(
		services.global_position.is_equal_approx(position_before)
		and services.size.is_equal_approx(size_before),
		"upgrade popover leaves the underlying service layout unchanged"
	)
	overlay.queue_free()
	await _frames(2)


## Save-free equivalent of MetaProgress.unlock_building's successful branch.
## This keeps the runtime contract deterministic without touching a user's slot.
func _simulate_unlock(building_id: String) -> bool:
	var cost := MetaProgress.next_building_cost(building_id)
	if cost < 0 or MetaProgress.scrap < cost:
		return false
	MetaProgress.scrap -= cost
	MetaProgress.buildings[building_id] = 1
	MetaProgress.emit_signal("scrap_changed", MetaProgress.scrap)
	MetaProgress.emit_signal("buildings_changed")
	return true


func _service_buttons(forge: Control, tier_action: Button) -> Array[Button]:
	var buttons: Array[Button] = []
	var close_button = forge.get("_close_btn")
	for candidate in forge.find_children("*", "Button", true, false):
		var button := candidate as Button
		if (
			button == tier_action
			or button == close_button
			or button.name in ["ForgeCloseButton", "UpgradePopoverCancel", "UpgradePopoverConfirm"]
		):
			continue
		buttons.append(button)
	return buttons


func _concept_price_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for candidate in root.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button != null and bool(button.get_meta("concept_price_button", false)):
			buttons.append(button)
	return buttons


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
