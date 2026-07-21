extends Node

const HOME_BASE = preload("res://run_system/ui/home_base_scene.tscn")

var _capture_failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[capture] setup")
	var original_language: String = Settings.language
	var original_buildings: Dictionary = MetaProgress.buildings.duplicate(true)
	var original_caps: int = MetaProgress.caps
	var original_scrap: int = MetaProgress.scrap
	var original_upgrades: Dictionary = MetaProgress.upgrades.duplicate(true)
	var original_caps_perks: Dictionary = MetaProgress.caps_perk_levels.duplicate(true)
	var original_bounties: Array = MetaProgress.active_bounties.duplicate(true)
	var original_bounty_shelf: Array = MetaProgress.bounty_shelf.duplicate(true)
	var original_bounty_shelf_date: String = MetaProgress.bounty_shelf_date
	Settings.language = "zh"
	seed(20260714)
	for building_id in ["forge", "clinic", "market", "outpost"]:
		# Main-page captures validate the complete accepted concepts, not a wall of
		# tier locks. Upgrade-popover placement gets its own T1 capture below.
		MetaProgress.buildings[building_id] = 3
	MetaProgress.caps = 4440
	MetaProgress.scrap = 620
	MetaProgress.upgrades = {
		"command_center": 3,
		"backpack": 2,
		"reroll_tokens": 2,
		"tool_slots": 1,
		"blacksmith": 2,
	}
	MetaProgress.caps_perk_levels = {
		"cyber_str": 3,
		"cyber_con": 2,
		"cyber_int": 1,
		"cyber_luck": 2,
		"cyber_charm": 0,
		"cyber_hp": 3,
	}
	MetaProgress.active_bounties = []
	MetaProgress.bounty_shelf = [
		"war_profiteer",
		"elite_purge",
		"scavenger_haul",
	]
	# Prevent HomeBase's stale-daily refresh from writing capture fixtures into
	# the user's active save slot.
	MetaProgress.bounty_shelf_date = Time.get_date_string_from_system()
	var home := HOME_BASE.instantiate()
	add_child(home)
	Input.warp_mouse(Vector2(2, 2))
	print("[capture] home added")
	await _wait_frames(12)
	print("[capture] overview ready")
	await _capture_viewport("res://tmp/home-base-icon-only-bounty.png")
	print("[capture] overview saved")

	for building_id in ["outpost", "clinic", "market"]:
		home.call("_open_building_screen", building_id)
		await _wait_frames(8)
		var building_overlay := home.get_node_or_null("BuildingOverlay")
		await _capture_viewport("res://tmp/base-building-%s-runtime.png" % building_id)
		print("[capture] %s building saved" % building_id)
		if building_overlay != null:
			building_overlay.queue_free()
		await _wait_frames(3)

	home.call("_open_forge_windows")
	await _wait_frames(8)
	await _capture_viewport("res://tmp/base-building-forge-runtime.png")
	print("[capture] forge building saved")
	var forge_window := home.find_child("ForgeWindow", true, false)
	if forge_window != null:
		forge_window.queue_free()
	var character_window := home.find_child("CharacterWindow", true, false)
	if character_window != null:
		character_window.queue_free()
	await _wait_frames(3)

	# Separate captures prove every shared popup remains an overlay and never
	# becomes a replacement page or changes the service-column layout.
	for building_id in ["outpost", "clinic", "market"]:
		MetaProgress.buildings[building_id] = 1
		home.call("_open_building_screen", building_id)
		await _wait_frames(6)
		var upgrade_overlay := home.get_node_or_null("BuildingOverlay")
		if upgrade_overlay != null:
			var upgrade := upgrade_overlay.find_child("BuildingUpgradeButton", true, false) as Button
			if upgrade != null:
				upgrade.pressed.emit()
				await _wait_frames(3)
		await _capture_viewport("res://tmp/base-upgrade-%s-runtime.png" % building_id)
		print("[capture] %s upgrade popover saved" % building_id)
		if upgrade_overlay != null:
			upgrade_overlay.queue_free()
		await _wait_frames(3)
		MetaProgress.buildings[building_id] = 3

	MetaProgress.buildings["forge"] = 1
	home.call("_open_forge_windows")
	await _wait_frames(6)
	forge_window = home.find_child("ForgeWindow", true, false)
	if forge_window != null:
		var forge_upgrade := forge_window.find_child("ForgeUpgradeButton", true, false) as Button
		if forge_upgrade != null:
			forge_upgrade.pressed.emit()
			await _wait_frames(3)
	await _capture_viewport("res://tmp/base-upgrade-forge-runtime.png")
	print("[capture] forge upgrade popover saved")

	home.queue_free()
	Settings.language = original_language
	MetaProgress.buildings = original_buildings
	MetaProgress.caps = original_caps
	MetaProgress.scrap = original_scrap
	MetaProgress.upgrades = original_upgrades
	MetaProgress.caps_perk_levels = original_caps_perks
	MetaProgress.active_bounties = original_bounties
	MetaProgress.bounty_shelf = original_bounty_shelf
	MetaProgress.bounty_shelf_date = original_bounty_shelf_date
	await _wait_frames(3)
	get_tree().quit(1 if _capture_failed else 0)


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _capture_viewport(path: String) -> void:
	# Headless GL does not emit frame_post_draw reliably on Windows. The caller
	# already waits multiple process frames, so the viewport texture is ready here.
	var viewport_texture := get_viewport().get_texture()
	var image := viewport_texture.get_image() if viewport_texture != null else null
	if image == null:
		_capture_failed = true
		push_error("Could not read the viewport for visual capture %s" % path)
		return
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_capture_failed = true
		push_error("Could not save visual capture %s: %s" % [path, error])
