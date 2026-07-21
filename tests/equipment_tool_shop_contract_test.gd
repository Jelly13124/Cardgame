extends Node

const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")
const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")
const MARKET_SCREEN = preload("res://run_system/ui/buildings/market_screen.gd")
const SHOP_SCENE = preload("res://run_system/ui/shop_scene.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

const GENERIC_EQUIPMENT_DIR := "res://battle_scene/assets/images/ui/equipment/"
const GENERIC_EQUIPMENT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
const GENERIC_EQUIPMENT_RARITIES := ["common", "uncommon", "rare"]

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

const EXPECTED_TOOL_IDS := [
	"adrenaline_shot",
	"blood_kit",
	"combat_stim",
	"energy_cell",
	"field_kit",
	"frag_grenade",
	"med_kit",
	"munitions_crate",
	"shock_charge",
	"smoke_bomb",
	"toxin_vial",
]

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
	_test_generic_equipment_asset_contract()
	_test_tool_icon_assets()
	await _test_equipment_cell_sizing()
	await _test_tool_destination_and_slot_dragging()
	await _test_default_unequip_refreshes_immediately()
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


func _test_generic_equipment_asset_contract() -> void:
	var seen_paths := {}
	var resolved_count := 0
	for slot in GENERIC_EQUIPMENT_SLOTS:
		for rarity in GENERIC_EQUIPMENT_RARITIES:
			var basename := "%s_%s.png" % [slot, rarity]
			var expected_path := GENERIC_EQUIPMENT_DIR + basename
			_expect(
				not seen_paths.has(expected_path),
				"%s generic equipment path is unique" % basename
			)
			seen_paths[expected_path] = true
			_expect(
				ResourceLoader.exists(expected_path),
				"%s generic equipment asset exists" % basename
			)

			var texture := EQUIPMENT_ICON.resolve_equipment_texture("", slot, rarity)
			_expect(texture != null, "%s resolves through EquipmentIcon" % basename)
			if texture == null:
				continue
			resolved_count += 1
			_expect(
				texture.resource_path == expected_path,
				"%s resolves its same-named generic texture (got %s)"
				% [basename, texture.resource_path]
			)

			var image := texture.get_image()
			_expect(image != null and not image.is_empty(), "%s yields readable image data" % basename)
			if image == null or image.is_empty():
				continue
			_expect(
				image.get_width() == 256 and image.get_height() == 256,
				"%s uses the 256x256 production canvas" % basename
			)
			_expect(
				image.get_format() == Image.FORMAT_RGBA8,
				"%s imports as RGBA8 rather than opaque RGB" % basename
			)
			_expect(
				image.detect_alpha() != Image.ALPHA_NONE,
				"%s preserves a real alpha channel" % basename
			)
			_expect(
				_image_edges_are_transparent(image),
				"%s keeps every pixel on all four canvas edges transparent" % basename
			)

	_expect(seen_paths.size() == 15, "equipment contract covers 5 slots x 3 rarities")
	_expect(resolved_count == 15, "all 15 generic equipment textures resolve")

	# The reusable inventory icon owns the normal equipment presentation.
	var icon := EQUIPMENT_ICON.new()
	icon.set_equipment("head", "Contract Hat", "", "common")
	var icon_rect := icon.get("_texture_rect") as TextureRect
	_expect(
		icon_rect != null
		and icon_rect.texture != null
		and icon_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"EquipmentIcon renders smooth 256px comic art with LINEAR filtering"
	)
	icon.free()

	# BackpackCell owns the drag preview used by character/stash/forge inventory.
	var cell := BACKPACK_CELL.new()
	cell.preview_tex = EQUIPMENT_ICON.resolve_equipment_texture("", "hands", "uncommon")
	var preview := cell.call("_make_preview") as Control
	var preview_rect := _find_texture_rect(preview, GENERIC_EQUIPMENT_DIR + "hands_uncommon.png")
	_expect(
		preview_rect != null
		and preview_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"BackpackCell equipment drag preview uses LINEAR filtering"
	)
	preview.free()
	cell.free()

	# Market cards bypass EquipmentIcon's slot frame, so verify their direct art
	# presentation uses the same smooth filter too.
	var market := MARKET_SCREEN.new()
	var market_card := market.call(
		"_build_equip_tile",
		{"base": "gear_weapon_rare", "rarity": "rare", "price": 280}
	) as Control
	var market_rect := _find_texture_rect(
		market_card, GENERIC_EQUIPMENT_DIR + "weapon_rare.png"
	)
	_expect(
		market_rect != null
		and market_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"market equipment art uses LINEAR filtering"
	)
	market_card.free()
	market.free()


func _test_tool_icon_assets() -> void:
	var seen_paths := {}
	for tool_id in EXPECTED_TOOL_IDS:
		var data: Dictionary = RunManager.get_tool_data(tool_id)
		var icon_path := str(data.get("icon", ""))
		_expect(icon_path != "", "%s declares an icon path" % tool_id)
		_expect(not seen_paths.has(icon_path), "%s has a unique semantic icon" % tool_id)
		seen_paths[icon_path] = true
		_expect(ResourceLoader.exists(icon_path), "%s icon exists" % tool_id)
		if not ResourceLoader.exists(icon_path):
			continue
		var texture := load(icon_path) as Texture2D
		_expect(texture != null, "%s icon imports as a texture" % tool_id)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(
			image.get_width() == 256 and image.get_height() == 256,
			"%s icon uses the 256x256 production canvas" % tool_id
		)
		for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			_expect(
				image.get_pixelv(corner).a <= 0.05,
				"%s keeps transparent canvas corners" % tool_id
			)


func _test_equipment_cell_sizing() -> void:
	_reset_run_inventory()
	RunManager.backpack[0] = {"kind": "equip", "id": "gear_hands_common"}
	var window := CHARACTER_WINDOW.new()
	window.mode = "map"
	add_child(window)
	await _frames(3)

	var grid := window.find_child("BackpackGrid", true, false) as GridContainer
	_expect(grid != null, "character backpack exposes its sizing grid")
	if grid != null:
		var min_width := INF
		var max_width := 0.0
		var all_minimums_fit := true
		for child in grid.get_children():
			var control := child as Control
			min_width = minf(min_width, control.size.x)
			max_width = maxf(max_width, control.size.x)
			all_minimums_fit = all_minimums_fit and control.custom_minimum_size.x >= 64.0
		_expect(
			all_minimums_fit,
			"every backpack cell is at least as wide as its 64 px equipment icon"
		)
		_expect(
			is_equal_approx(min_width, max_width),
			"equipment content cannot widen only selected backpack columns"
		)

	var slot_cells: Dictionary = window.get("_slot_cells")
	_expect(slot_cells.size() == RunManager.EQUIPMENT_SLOTS.size(), "all equipment slots are registered")
	for slot in slot_cells:
		var slot_cell := slot_cells[slot] as Control
		_expect(
			slot_cell.custom_minimum_size.x >= 84.0,
			"%s equipment slot scales up with the backpack grid" % slot
		)

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
		_expect(
			not _texture_paths(empty_slot).any(func(path): return str(path).ends_with("/med_kit.png")),
			"empty tool slot shows only the ghost tool art"
		)
	empty_window.queue_free()
	await get_tree().process_frame

	_reset_run_inventory()
	var full_tools: Array[String] = []
	for _i in range(RunManager.tool_slots()):
		full_tools.append("med_kit")
	RunManager.tool_inventory.assign(full_tools)
	RunManager.backpack[0] = {"kind": "tool", "id": "smoke_bomb"}
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
		var texture_paths := _texture_paths(filled_slot)
		_expect(
			texture_paths.has(str(RunManager.get_tool_data("med_kit").get("icon", ""))),
			"filled tool slot shows the real med-kit icon"
		)
		_expect(
			not texture_paths.any(func(path): return str(path).ends_with("/ghost_tool.png")),
			"filled tool slot hides the ghost wrench"
		)
		var incoming := {"src": "backpack", "kind": "tool", "index": 0, "tool_id": "smoke_bomb"}
		var accepts_replacement := bool(filled_slot.call("_can_drop_data", Vector2.ZERO, incoming))
		_expect(accepts_replacement, "filled tool slot accepts a backpack tool for replacement")
		if accepts_replacement:
			filled_slot.call("_drop_data", Vector2.ZERO, incoming)
			await _frames(2)
			_expect(RunManager.tool_inventory[0] == "smoke_bomb", "dropped tool replaces the target slot")
			_expect(
				RunManager.backpack[0] == {"kind": "tool", "id": "med_kit"},
				"replaced tool returns to the incoming tool's backpack cell"
			)
	filled_window.queue_free()
	await get_tree().process_frame

	_reset_run_inventory()
	full_tools.clear()
	for _i in range(RunManager.tool_slots()):
		full_tools.append("med_kit")
	RunManager.tool_inventory.assign(full_tools)
	RunManager.backpack[0] = {"kind": "tool", "id": "smoke_bomb"}
	var click_window := CHARACTER_WINDOW.new()
	click_window.mode = "map"
	add_child(click_window)
	await _frames(3)
	click_window.call("_equip_tool", 0)
	_expect(RunManager.tool_inventory[0] == "smoke_bomb", "clicking a tool replaces slot zero when full")
	_expect(
		RunManager.backpack[0] == {"kind": "tool", "id": "med_kit"},
		"click replacement swaps the old tool back into the backpack"
	)
	click_window.queue_free()
	await get_tree().process_frame


func _test_default_unequip_refreshes_immediately() -> void:
	_reset_run_inventory()
	RunManager.tool_inventory.assign(["energy_cell"])
	var observed_states: Array[Dictionary] = []
	var observe := func(source: String) -> void:
		observed_states.append(
			{
				"source": source,
				"tools": RunManager.tool_inventory.duplicate(),
				"backpack_tools": RunManager.backpack_tool_ids(),
			}
		)
	var on_backpack := func() -> void: observe.call("backpack")
	var on_tools := func() -> void: observe.call("tools")
	RunManager.backpack_changed.connect(on_backpack, CONNECT_ONE_SHOT)
	RunManager.tools_changed.connect(on_tools, CONNECT_ONE_SHOT)

	var window := CHARACTER_WINDOW.new()
	window.mode = "map"
	add_child(window)
	await _frames(3)
	_expect(RunManager.unequip_tool(0), "default unequip succeeds with backpack space")
	await _frames(2)

	_expect(observed_states.size() == 2, "unequip emits both inventory signals once")
	for state in observed_states:
		_expect(state.tools.is_empty(), "%s observer sees no equipped tool" % state.source)
		_expect(
			state.backpack_tools == ["energy_cell"],
			"%s observer sees the backpacked tool" % state.source
		)
	var tool_row := window.get("_tool_row") as HBoxContainer
	var slot: Control = null
	if tool_row != null and tool_row.get_child_count() > 0:
		slot = tool_row.get_child(tool_row.get_child_count() - 1) as Control
	_expect(slot != null, "character window keeps a visible tool slot")
	if slot != null:
		_expect(
			not _texture_paths(slot).has(
				str(RunManager.get_tool_data("energy_cell").get("icon", ""))
			),
			"tool slot clears immediately after unequip"
		)

	window.queue_free()
	await get_tree().process_frame

	_reset_run_inventory()
	for i in range(RunManager.effective_backpack_size()):
		RunManager.backpack[i] = {"kind": "gold", "amount": 1}
	RunManager.tool_inventory.assign(["energy_cell"])
	var full_snapshot := RunManager.backpack.duplicate(true)
	_expect(not RunManager.unequip_tool(0), "full backpack rejects default unequip")
	_expect(
		RunManager.tool_inventory == ["energy_cell"],
		"failed unequip keeps the tool equipped"
	)
	_expect(RunManager.backpack == full_snapshot, "failed unequip leaves the backpack unchanged")


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


func _texture_paths(root: Node) -> Array[String]:
	var paths: Array[String] = []
	for node in root.find_children("*", "TextureRect", true, false):
		var rect := node as TextureRect
		if rect.texture:
			paths.append(rect.texture.resource_path)
	return paths


func _find_texture_rect(root: Node, texture_path: String) -> TextureRect:
	if root == null:
		return null
	for node in root.find_children("*", "TextureRect", true, false):
		var rect := node as TextureRect
		if rect.texture != null and rect.texture.resource_path == texture_path:
			return rect
	return null


func _image_edges_are_transparent(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	for x in range(image.get_width()):
		if image.get_pixel(x, 0).a > 0.05 or image.get_pixel(x, last_y).a > 0.05:
			return false
	for y in range(image.get_height()):
		if image.get_pixel(0, y).a > 0.05 or image.get_pixel(last_x, y).a > 0.05:
			return false
	return true


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
