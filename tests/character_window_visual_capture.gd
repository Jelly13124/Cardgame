extends Node

const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")
const GENERIC_EQUIPMENT := [
	["gear_head_common", "common"],
	["gear_chest_common", "common"],
	["gear_weapon_common", "common"],
	["gear_hands_common", "common"],
	["gear_accessory_common", "common"],
	["gear_head_uncommon", "uncommon"],
	["gear_chest_uncommon", "uncommon"],
	["gear_weapon_uncommon", "uncommon"],
	["gear_hands_uncommon", "uncommon"],
	["gear_accessory_uncommon", "uncommon"],
	["gear_head_rare", "rare"],
	["gear_chest_rare", "rare"],
	["gear_weapon_rare", "rare"],
	["gear_hands_rare", "rare"],
	["gear_accessory_rare", "rare"],
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_tools: Array[String] = RunManager.tool_inventory.duplicate()
	var original_loadout: Array = RunManager.pending_loadout.duplicate(true)
	var original_equipped: Dictionary = RunManager.pending_equipped.duplicate(true)
	var original_upgrades: Dictionary = MetaProgress.upgrades.duplicate(true)
	RunManager.tool_inventory.clear()
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#171a19")
	add_child(backdrop)

	var window := CHARACTER_WINDOW.new()
	window.mode = "map"
	add_child(window)
	for _i in range(8):
		await get_tree().process_frame
	window.position = (get_viewport().get_visible_rect().size - window.size) * 0.5
	for _i in range(3):
		await get_tree().process_frame

	if not _save_capture("res://tmp/character-window-runtime-empty-tool.png"):
		get_tree().quit(1)
		return

	window.queue_free()
	for _i in range(3):
		await get_tree().process_frame
	RunManager.tool_inventory.assign(["med_kit"])
	var filled_window := CHARACTER_WINDOW.new()
	filled_window.mode = "map"
	add_child(filled_window)
	for _i in range(8):
		await get_tree().process_frame
	filled_window.position = (get_viewport().get_visible_rect().size - filled_window.size) * 0.5
	for _i in range(3):
		await get_tree().process_frame
	if not _save_capture("res://tmp/character-window-runtime-filled-tool.png"):
		get_tree().quit(1)
		return

	filled_window.queue_free()
	for _i in range(3):
		await get_tree().process_frame
	RunManager.pending_loadout.clear()
	RunManager.pending_equipped.clear()
	MetaProgress.upgrades["backpack"] = 3
	for spec in GENERIC_EQUIPMENT:
		RunManager.pending_loadout.append(
			RunManager.make_equip_instance(str(spec[0]), str(spec[1]))
		)
	var equipment_window := CHARACTER_WINDOW.new()
	equipment_window.mode = "base"
	add_child(equipment_window)
	for _i in range(8):
		await get_tree().process_frame
	equipment_window.position = (get_viewport().get_visible_rect().size - equipment_window.size) * 0.5
	for _i in range(3):
		await get_tree().process_frame
	if not _save_capture("res://tmp/character-window-runtime-equipment-15.png"):
		get_tree().quit(1)
		return

	RunManager.tool_inventory.assign(original_tools)
	RunManager.pending_loadout.assign(original_loadout)
	RunManager.pending_equipped.clear()
	RunManager.pending_equipped.merge(original_equipped, true)
	MetaProgress.upgrades = original_upgrades
	get_tree().quit(0)


func _save_capture(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Could not save character window capture %s: %s" % [path, error])
		return false
	print("[OK] Character window capture saved: ", absolute_path)
	return true
