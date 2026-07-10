extends Node

const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")
const SHOP_SCENE = preload("res://run_system/ui/shop_scene.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

const EXPECTED_EQUIPMENT_NAMES := {
	"gear_head_common": "Scavenger Cowboy Hat",
	"gear_chest_common": "Scavenger Leather Vest",
	"gear_weapon_common": "Scavenger Revolver",
	"gear_hands_common": "Scavenger Gauntlet",
	"gear_accessory_common": "Scavenger Fang Necklace",
	"gear_head_uncommon": "Ranger Scout Hat",
	"gear_chest_uncommon": "Ranger Tactical Vest",
	"gear_weapon_uncommon": "Ranger Revolver",
	"gear_hands_uncommon": "Ranger Gauntlet",
	"gear_accessory_uncommon": "Ranger Dog Tags",
	"gear_head_rare": "Officer's Battle Cap",
	"gear_chest_rare": "Officer's Heavy Armor",
	"gear_weapon_rare": "Officer's Charged Revolver",
	"gear_hands_rare": "Officer's Power Gauntlet",
	"gear_accessory_rare": "Officer's Core Medal",
}

var failures: PackedStringArray = []
var _original_backpack: Array = []
var _original_tools: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_original_backpack = RunManager.backpack.duplicate(true)
	_original_tools = RunManager.tool_inventory.duplicate()
	await _test_equipment_resolution_and_names()
	await _test_tool_destination_and_slot_dragging()
	await _test_shop_tool_stall()
	await _test_deck_icon()
	_restore_run_state()
	if failures.is_empty():
		print("[OK] Equipment, tool, shop, and deck contracts passed")
		get_tree().quit(0)
		return
	push_error("Equipment/tool/shop contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_equipment_resolution_and_names() -> void:
	var method_exists := _script_has_method(EQUIPMENT_ICON, "resolve_equipment_texture")
	_expect(method_exists, "EquipmentIcon exposes resolve_equipment_texture")

	for path in [
		"res://run_system/ui/window/character_window.gd",
		"res://run_system/ui/window/stash_window.gd",
		"res://run_system/ui/window/forge_window.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(
			source.contains("EQUIPMENT_ICON.resolve_equipment_texture"),
			"%s uses the shared equipment texture resolver" % path.get_file()
		)

	for item_id in EXPECTED_EQUIPMENT_NAMES:
		var path := "res://run_system/data/equipment/%s.json" % item_id
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		_expect(typeof(parsed) == TYPE_DICTIONARY, "%s parses as equipment JSON" % item_id)
		if typeof(parsed) == TYPE_DICTIONARY:
			_expect(
				str(parsed.get("name", "")) == EXPECTED_EQUIPMENT_NAMES[item_id],
				"%s uses the approved series name" % item_id
			)

	_reset_run_inventory()
	RunManager.backpack[0] = {"kind": "equip", "id": "gear_hands_common"}
	var window := CHARACTER_WINDOW.new()
	window.mode = "map"
	add_child(window)
	await _frames(3)
	var grid := window.find_child("BackpackGrid", true, false) as GridContainer
	_expect(grid != null and grid.get_child_count() > 0, "character backpack builds the generic equipment cell")
	if grid != null and grid.get_child_count() > 0:
		var tex = grid.get_child(0).get("preview_tex")
		_expect(tex is Texture2D, "empty equipment sprite still provides a real drag preview")
		if tex is Texture2D:
			_expect(tex.resource_path.ends_with("/hands_common.png"), "drag preview resolves hands_common.png")
	window.queue_free()
	await get_tree().process_frame


func _test_tool_destination_and_slot_dragging() -> void:
	_reset_run_inventory()
	RunManager.tool_inventory.assign(["med_kit"])
	var exact_method := RunManager.has_method("unequip_tool_to_backpack")
	_expect(exact_method, "RunManager exposes unequip_tool_to_backpack")
	if exact_method:
		var moved := bool(RunManager.call("unequip_tool_to_backpack", 0, 3))
		_expect(moved, "equipped tool can move to an exact empty backpack cell")
		_expect(
			RunManager.backpack[3] == {"kind": "tool", "id": "med_kit"},
			"exact backpack target receives the equipped tool"
		)
		RunManager.tool_inventory.assign(["smoke_bomb"])
		RunManager.backpack[4] = {"kind": "gold", "amount": 1}
		var rejected := not bool(RunManager.call("unequip_tool_to_backpack", 0, 4))
		_expect(rejected, "occupied exact target rejects equipped tool")
		_expect(
			RunManager.tool_inventory == ["smoke_bomb"],
			"rejected exact drop keeps the tool equipped"
		)

	_reset_run_inventory()
	RunManager.backpack[0] = {"kind": "tool", "id": "med_kit"}
	var empty_window := CHARACTER_WINDOW.new()
	empty_window.mode = "map"
	add_child(empty_window)
	await _frames(3)
	var empty_slot := empty_window.find_child("ToolSlot0", true, false)
	_expect(empty_slot != null, "empty tool slot is exposed as ToolSlot0")
	if empty_slot != null:
		_expect(
			bool(empty_slot.call("_can_drop_data", Vector2.ZERO, {"src": "backpack", "kind": "tool", "index": 0})),
			"empty tool slot accepts a backpack tool"
		)
		_expect(
			not bool(empty_slot.call("_can_drop_data", Vector2.ZERO, {"src": "backpack", "kind": "equip", "index": 0})),
			"empty tool slot rejects equipment"
		)
	empty_window.queue_free()
	await get_tree().process_frame

	_reset_run_inventory()
	RunManager.tool_inventory.assign(["med_kit"])
	var filled_window := CHARACTER_WINDOW.new()
	filled_window.mode = "map"
	add_child(filled_window)
	await _frames(3)
	var filled_slot := filled_window.find_child("ToolSlot0", true, false)
	_expect(filled_slot != null, "filled tool slot remains ToolSlot0")
	if filled_slot != null:
		var payload: Dictionary = filled_slot.get("drag_payload")
		_expect(payload.get("src") == "tool_slot", "filled tool slot produces tool_slot drag data")
		_expect(payload.get("index") == 0, "filled tool slot drag data preserves slot index")
	filled_window.queue_free()
	await get_tree().process_frame


func _test_shop_tool_stall() -> void:
	var shop := SHOP_SCENE.new()
	var stall = shop.call("_build_tool_stall", {"tool_id": "med_kit", "price": 40})
	_expect(stall is Control, "tool shop stall builds without a rarity field")
	if stall is Control:
		stall.queue_free()
	shop.queue_free()


func _test_deck_icon() -> void:
	var host := Control.new()
	add_child(host)
	var bar := RUN_TOP_BAR.new()
	host.add_child(bar)
	await _frames(2)
	var deck_button: Button = null
	for candidate in bar.find_children("*", "Button", true, false):
		if (candidate as Button).tooltip_text == tr("UI_BATTLE_VIEW_RUN_DECK"):
			deck_button = candidate as Button
			break
	_expect(deck_button != null, "top bar exposes the run-deck button")
	if deck_button != null:
		var path := deck_button.icon.resource_path if deck_button.icon else ""
		_expect(
			path.ends_with("/iconb_deck_stack.png"),
			"run-deck button uses iconb_deck_stack.png (got %s)" % path
		)
	host.queue_free()
	await get_tree().process_frame


func _script_has_method(script: Script, method_name: String) -> bool:
	for method in script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _reset_run_inventory() -> void:
	RunManager.backpack.clear()
	RunManager.backpack.resize(RunManager.MAX_INVENTORY)
	RunManager.tool_inventory.clear()


func _restore_run_state() -> void:
	RunManager.backpack.assign(_original_backpack)
	RunManager.tool_inventory.assign(_original_tools)
