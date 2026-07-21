extends Node

const FORGE_WINDOW = preload("res://run_system/ui/window/forge_window.gd")
const FORGE_SOURCE := "res://run_system/ui/window/forge_window.gd"

var failures: PackedStringArray = []
var _original_pending: Array = []
var _original_stash: Array = []
var _original_scrap := 0
var _original_buildings: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_snapshot_state()
	MetaProgress.buildings["forge"] = 3
	await _test_vertical_layout_and_backpack_only_drop()
	await _test_pending_backpack_mutations()
	_restore_state()
	_stop_test_audio()
	if failures.is_empty():
		print("[OK] Forge backpack-only contracts passed")
		get_tree().quit(0)
		return
	push_error("Forge backpack contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_vertical_layout_and_backpack_only_drop() -> void:
	var carried := _equip("gear_head_common", "common")
	_set_pending([carried])
	var forge := FORGE_WINDOW.new()
	add_child(forge)
	await _frames(4)

	var list := forge.find_child("ForgeBulkList", true, false)
	_expect(list is VBoxContainer, "bulk dismantle actions use a vertical VBox list")
	var craft_tab := forge.find_child("ForgeTab_craft", true, false) as Button
	_expect(craft_tab != null, "forge tabs expose stable named buttons")
	if craft_tab:
		var normal_style := craft_tab.get_theme_stylebox("normal") as StyleBoxFlat
		var hover_style := craft_tab.get_theme_stylebox("hover") as StyleBoxFlat
		_expect(
			normal_style != null and hover_style != null,
			"forge tabs use one shared flat-frame component"
		)
		_expect(
			normal_style != null
			and hover_style != null
			and normal_style.bg_color != hover_style.bg_color
			and normal_style.get_border_width(SIDE_LEFT)
			== hover_style.get_border_width(SIDE_LEFT)
			and normal_style.corner_radius_top_left == hover_style.corner_radius_top_left,
			"forge tab hover changes color without changing geometry"
		)
	var expected_rows := ["all", "common", "uncommon", "rare"]
	var expected_zh := ["全部", "普通", "精良", "军官"]
	for i in range(expected_rows.size()):
		var row := forge.find_child("ForgeBulkAction_%s" % expected_rows[i], true, false)
		_expect(row is HBoxContainer, "%s dismantle action is one horizontal row" % expected_rows[i])
		if list != null and list.get_child_count() > i + 1:
			_expect(
				list.get_child(i + 1).name == "ForgeBulkAction_%s" % expected_rows[i],
				"bulk actions preserve all/common/uncommon/rare vertical order"
			)
		if row != null and Settings.language == "zh":
			_expect(row.custom_minimum_size.y >= 56.0, "%s bulk row is visually substantial" % expected_rows[i])
			var action := forge.find_child("ForgeBulkButton_%s" % expected_rows[i], true, false) as Button
			_expect(
				action != null and action.custom_minimum_size.y >= 54.0,
				"%s bulk button fills its row" % expected_rows[i]
			)
			var has_quality_name := false
			for text_value in _control_texts(row):
				if text_value.contains(expected_zh[i]):
					has_quality_name = true
					break
			_expect(
				has_quality_name,
				"%s row uses the approved quality name %s" % [expected_rows[i], expected_zh[i]]
			)

	forge.set("_selected_index", 0)
	forge.call("_rebuild")
	await _frames(2)
	var single_action := forge.find_child("ForgeSingleDismantleButton", true, false) as Button
	_expect(single_action != null, "single dismantle uses a dedicated named action button")
	if single_action:
		_expect(
			_style_texture_path(single_action.get_theme_stylebox("normal")).ends_with(
				"/forge_dismantle_action.png"
			),
			"single dismantle uses its dedicated UI component"
		)

	var workbench = forge.find_child("ForgeWorkbenchCell", true, false)
	_expect(workbench != null, "forge exposes a named backpack workbench drop cell")
	if workbench != null:
		var carry_payload := {"src": "carry", "entry": carried, "slot": "head"}
		_expect(
			bool(workbench.call("_can_drop_data", Vector2.ZERO, carry_payload)),
			"workbench accepts a base-backpack carry payload"
		)
		_expect(
			not bool(
				workbench.call(
					"_can_drop_data", Vector2.ZERO, {"src": "stash", "entry": carried}
				)
			),
			"workbench rejects a permanent-stash payload"
		)
		_expect(
			not bool(
				workbench.call(
					"_can_drop_data", Vector2.ZERO, {"src": "forge_stash", "index": 0}
				)
			),
			"workbench rejects the removed embedded-forge-stash payload"
		)

	var source := FileAccess.get_file_as_string(FORGE_SOURCE)
	_expect(not source.contains("_compact_stash_grid"), "forge source has no embedded stash grid")
	_expect(not source.contains("UI_FORGE_STASH_TITLE"), "forge source has no warehouse title")
	_expect(not source.contains("MetaProgress.stash"), "forge does not read permanent stash data")
	_expect(
		forge.find_child("ForgeTab_curse", true, false) == null,
		"curse is merged into reforge instead of occupying a fourth tab"
	)
	for tab_id in ["reforge"]:
		forge.set("_tab", tab_id)
		forge.call("_rebuild")
		await _frames(2)
		var rendered_text := " ".join(_control_texts(forge))
		_expect(
			not rendered_text.contains("仓库") and not rendered_text.to_lower().contains("stash"),
			"%s tab renders no warehouse inventory" % tab_id
		)
	_expect(
		forge.find_child("ForgeReforgeCurseAction", true, false) != null,
		"reforge page contains the tier-gated curse action"
	)

	forge.queue_free()
	await get_tree().process_frame


func _test_pending_backpack_mutations() -> void:
	var forge := FORGE_WINDOW.new()
	# Backend helpers are intentionally callable without mounting the visual tree.
	var stash_sentinel := [_equip("gear_weapon_rare", "rare")]
	MetaProgress.stash = stash_sentinel.duplicate(true)
	MetaProgress.scrap = 1000

	var common := _equip("gear_head_common", "common")
	var uncommon := _equip("gear_chest_uncommon", "uncommon")
	var rare := _equip("gear_weapon_rare", "rare")
	var cursed := _equip("gear_hands_common", "cursed")
	cursed["cursed"] = true
	var set_piece := _equip("gear_accessory_rare", "rare")
	set_piece["set_id"] = "demo_set"
	_set_pending([common, uncommon, rare, cursed, set_piece])

	var preview: Dictionary = forge.call("_preview_pending_dismantle", "")
	_expect(int(preview.get("count", -1)) == 3, "bulk preview protects cursed and set gear")
	_expect(int(preview.get("scrap", -1)) == 42, "bulk preview totals 5+12+25 Scrap")
	var scrap_before := MetaProgress.scrap
	var result: Dictionary = forge.call("_dismantle_pending_by_rarity", "uncommon")
	_expect(result == {"count": 1, "scrap": 12}, "uncommon bulk dismantle reports exact result")
	_expect(RunManager.pending_loadout.size() == 4, "bulk dismantle removes only the matching backpack entry")
	_expect(MetaProgress.scrap == scrap_before + 12, "bulk dismantle grants Scrap")
	_expect(MetaProgress.stash == stash_sentinel, "bulk dismantle never mutates warehouse storage")

	_set_pending([common])
	scrap_before = MetaProgress.scrap
	_expect(bool(forge.call("_dismantle_pending_item", 0)), "single backpack dismantle succeeds")
	_expect(RunManager.pending_loadout.is_empty(), "single dismantle removes the backpack item")
	_expect(MetaProgress.scrap == scrap_before + 5, "single common dismantle grants 5 Scrap")
	_expect(MetaProgress.stash == stash_sentinel, "single dismantle leaves warehouse storage untouched")

	var reforge_item := RunManager.make_equip_instance("gear_head_common", "common")
	_set_pending([reforge_item])
	scrap_before = MetaProgress.scrap
	var reforge_cost := MetaProgress.reforge_cost_for(reforge_item)
	_expect(bool(forge.call("_reforge_pending_item", 0, 0)), "reforge mutates a backpack entry")
	var reforged := RunManager.as_equip_instance(RunManager.pending_loadout[0])
	_expect(int(reforged.get("reforge_count", 0)) == 1, "reforge count persists on backpack entry")
	_expect(int(reforged.get("reforge_index", -1)) == 0, "first reforge locks the selected affix")
	_expect(MetaProgress.scrap == scrap_before - reforge_cost, "reforge spends its escalating Scrap cost")
	_expect(MetaProgress.stash == stash_sentinel, "reforge leaves warehouse storage untouched")

	var curse_item := RunManager.make_equip_instance("gear_chest_common", "common")
	_set_pending([curse_item])
	scrap_before = MetaProgress.scrap
	_expect(bool(forge.call("_curse_pending_item", 0)), "curse mutates a backpack entry")
	var cursed_result := RunManager.as_equip_instance(RunManager.pending_loadout[0])
	_expect(bool(cursed_result.get("cursed", false)), "curse flag persists on backpack entry")
	_expect(str(cursed_result.get("rarity", "")) == "cursed", "curse promotes entry to cursed tier")
	_expect(MetaProgress.scrap == scrap_before - 100, "curse spends 100 Scrap")
	_expect(MetaProgress.stash == stash_sentinel, "curse leaves warehouse storage untouched")

	_set_pending([])
	forge.set("_craft_slot", "head")
	forge.set("_craft_rarity", "common")
	scrap_before = MetaProgress.scrap
	forge.call("_on_craft_pressed")
	_expect(RunManager.pending_loadout.size() == 1, "crafted equipment enters the base backpack")
	var crafted := RunManager.as_equip_instance(RunManager.pending_loadout[0])
	_expect(str(crafted.get("rarity", "")) == "common", "common craft stays common rarity")
	_expect(str(crafted.get("set_id", "")) == "", "craft never mints a normal set item")
	_expect(str(crafted.get("base", "")) == "gear_head_common", "craft uses the non-set shell base")
	_expect(MetaProgress.scrap == scrap_before - 40, "common craft spends 40 Scrap")
	_expect(MetaProgress.stash == stash_sentinel, "craft does not auto-store equipment")

	forge.free()


func _equip(base_id: String, rarity: String) -> Dictionary:
	return {"base": base_id, "rarity": rarity, "affixes": []}


func _set_pending(items: Array) -> void:
	RunManager.pending_loadout.clear()
	RunManager.pending_loadout.append_array(items)


func _control_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for node in root.find_children("*", "Control", true, false):
		if node is Button or node is Label:
			var text_value := str(node.get("text"))
			if text_value != "":
				texts.append(text_value)
	return texts


func _style_texture_path(style: StyleBox) -> String:
	if style is StyleBoxTexture and (style as StyleBoxTexture).texture:
		return (style as StyleBoxTexture).texture.resource_path
	return ""


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _snapshot_state() -> void:
	_original_pending = RunManager.pending_loadout.duplicate(true)
	_original_stash = MetaProgress.stash.duplicate(true)
	_original_scrap = MetaProgress.scrap
	_original_buildings = MetaProgress.buildings.duplicate(true)


func _restore_state() -> void:
	_set_pending(_original_pending)
	MetaProgress.stash = _original_stash.duplicate(true)
	MetaProgress.scrap = _original_scrap
	MetaProgress.buildings = _original_buildings.duplicate(true)
	MetaProgress.save_progress()
	MetaProgress.scrap_changed.emit(MetaProgress.scrap)
	MetaProgress.buildings_changed.emit()


func _stop_test_audio() -> void:
	# Crafting intentionally exercises the real handler, including its one-shot SFX.
	# Release that stream before the headless test exits so Godot's leak check stays clean.
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	AudioManager.get("_sfx_cache").clear()
