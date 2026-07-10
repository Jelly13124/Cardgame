# Tool Confirmation and Inventory Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tool unequip/replacement update the character window immediately, require an StS2-style confirmation before combat tool use, and set save slot 1 to 5,000 Caps and 5,000 Scrap.

**Architecture:** `RunManager` remains the only inventory authority and completes both collection mutations before emitting either signal. A focused `ToolUseConfirm` control owns only modal presentation and confirm/cancel input; `battle_scene.gd` owns pending-request validation, target resolution, effects, and consumption. Headless contract scenes exercise the real character window and battle scene before the save file is backed up and edited.

**Tech Stack:** Godot 4.6, GDScript, CSV localization, PowerShell JSON tooling.

## Global Constraints

- Preserve direct backpack-to-tool-slot replacement and return the displaced tool to the incoming tool's backpack cell.
- Enemy-targeted tools continue to select the first valid enemy; enemy targeting redesign is out of scope.
- Cancellation, stale requests, duplicate clicks, and missing targets must not consume a tool.
- Use the existing lightline/charcoal visual language; do not use the native `ConfirmationDialog`.
- Change only `caps` and `scrap` in save slot 1, and create a timestamped sibling backup first.
- Preserve unrelated dirty-worktree changes. The tracked implementation targets are already modified before this plan begins, so do not stage or commit those overlapping files; never include `.import`, `.uid`, or user-data files.

---

### Task 1: Make tool unequip atomic and refresh the live character window

**Files:**
- Modify: `tests/equipment_tool_shop_contract_test.gd`
- Modify: `run_system/core/run_manager.gd:1785-1794`
- Modify: `run_system/ui/window/character_window.gd:138-152`

**Interfaces:**
- Consumes: `RunManager.backpack`, `RunManager.tool_inventory`, `_ensure_backpack()`, `_first_null_cell()`.
- Produces: `func unequip_tool(index: int) -> bool` whose `backpack_changed` and `tools_changed` observers always see the final consistent state.
- Produces: map/battle `CharacterWindow` instances subscribed to `RunManager.tools_changed`.

- [ ] **Step 1: Add the failing atomic-unequip regression**

Add the call to `_run()` immediately after `_test_tool_destination_and_slot_dragging()`:

```gdscript
	await _test_default_unequip_refreshes_immediately()
```

Add this function before `_test_shop_tool_stall()`:

```gdscript
func _test_default_unequip_refreshes_immediately() -> void:
	_reset_run_inventory()
	RunManager.tool_inventory.assign(["energy_cell"])
	var observed_states: Array[Dictionary] = []
	var observe := func(source: String) -> void:
		observed_states.append({
			"source": source,
			"tools": RunManager.tool_inventory.duplicate(),
			"backpack_tools": RunManager.backpack_tool_ids(),
		})
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
		_expect(state.backpack_tools == ["energy_cell"], "%s observer sees the backpacked tool" % state.source)
	var slot := window.find_child("ToolSlot0", true, false)
	_expect(slot != null, "character window keeps the named empty tool slot")
	if slot != null:
		_expect(
			not _texture_paths(slot).has(str(RunManager.get_tool_data("energy_cell").get("icon", ""))),
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
	_expect(RunManager.tool_inventory == ["energy_cell"], "failed unequip keeps the tool equipped")
	_expect(RunManager.backpack == full_snapshot, "failed unequip leaves the backpack unchanged")
```

- [ ] **Step 2: Run the contract and prove the signal-order regression fails**

Run:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/equipment_tool_shop_contract_test.tscn
```

Expected: non-zero exit; the `backpack` observation still contains `energy_cell` in `tool_inventory`, and the mounted tool slot remains populated.

- [ ] **Step 3: Replace the two-phase unequip with one atomic mutation**

Replace `RunManager.unequip_tool()` with:

```gdscript
func unequip_tool(index: int) -> bool:
	_ensure_backpack()
	if index < 0 or index >= tool_inventory.size():
		return false
	var backpack_index := _first_null_cell()
	if backpack_index == -1:
		return false
	backpack[backpack_index] = {"kind": "tool", "id": tool_inventory[index]}
	tool_inventory.remove_at(index)
	backpack_changed.emit()
	tools_changed.emit()
	return true
```

Do not call `add_tool_to_backpack()` here because it emits `backpack_changed` before `tool_inventory` is updated.

- [ ] **Step 4: Subscribe the character window to tool-only changes**

Add beside the guarded `backpack_changed` connection in `CharacterWindow._ready()`:

```gdscript
			if not RunManager.tools_changed.is_connected(_refresh):
				RunManager.tools_changed.connect(_refresh)
```

- [ ] **Step 5: Run the inventory/UI contracts**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/equipment_tool_shop_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/character_window_layout_contract_test.tscn
```

Expected: both exit 0; the new test observes two consistent final states, and replacement/exact-destination assertions remain green.

- [ ] **Step 6: Verify the scoped diff without staging overlapping files**

```powershell
git diff --check -- tests/equipment_tool_shop_contract_test.gd run_system/core/run_manager.gd run_system/ui/window/character_window.gd
git status --short -- tests/equipment_tool_shop_contract_test.gd run_system/core/run_manager.gd run_system/ui/window/character_window.gd
```

Expected: diff check is empty and all three paths remain modified but unstaged. Do not commit them because each contains pre-existing work from before this plan.

---

### Task 2: Build the compact lightline tool confirmation component

**Files:**
- Create: `battle_scene/ui/tool_use_confirm.gd`
- Create: `tests/tool_use_confirm_contract_test.gd`
- Create: `tests/tool_use_confirm_contract_test.tscn`
- Modify: `assets/translations/ui_battle.csv:2`

**Interfaces:**
- Produces: `ToolUseConfirm.setup(index: int, tool_id: String, tool_data: Dictionary) -> void`.
- Produces: signals `confirmed(index: int, tool_id: String)` and `cancelled`.
- Produces: public `confirm() -> void` and `cancel() -> void`, both idempotent.
- Produces named children `ToolIcon`, `ToolName`, `ToolDescription`, `UseButton`, and `CancelButton` under root `ToolUseConfirm`.

- [ ] **Step 1: Add the red component contract scene**

Create `tests/tool_use_confirm_contract_test.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/tool_use_confirm_contract_test.gd" id="1_test"]

[node name="ToolUseConfirmContractTest" type="Node"]
script = ExtResource("1_test")
```

Create `tests/tool_use_confirm_contract_test.gd`:

```gdscript
extends Node

const TOOL_CONFIRM = preload("res://battle_scene/ui/tool_use_confirm.gd")

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("[FAIL] ", message)


func _run() -> void:
	var data := RunManager.get_tool_data("energy_cell")
	var overlay := TOOL_CONFIRM.new()
	overlay.setup(0, "energy_cell", data)
	add_child(overlay)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(overlay.name == "ToolUseConfirm", "confirmation root has a stable name")
	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "confirmation blocks battle input")
	_expect(overlay.size == get_viewport().get_visible_rect().size, "confirmation covers the viewport")
	var scrim := overlay.find_child("Scrim", true, false) as ColorRect
	_expect(scrim != null and scrim.color.a < 0.8, "translucent scrim leaves the battle recognizable")
	for child_name in ["ToolIcon", "ToolName", "ToolDescription", "UseButton", "CancelButton"]:
		_expect(overlay.find_child(child_name, true, false) != null, "%s exists" % child_name)
	var icon := overlay.find_child("ToolIcon", true, false) as TextureRect
	_expect(icon != null and icon.texture != null, "confirmation renders the tool icon")
	if icon != null and icon.texture != null:
		_expect(icon.texture.resource_path.ends_with("/energy_cell.png"), "confirmation uses the requested tool art")

	var cancelled_count := 0
	overlay.cancelled.connect(func() -> void: cancelled_count += 1)
	overlay.cancel()
	overlay.cancel()
	await get_tree().process_frame
	_expect(cancelled_count == 1, "cancel emits once")

	var second := TOOL_CONFIRM.new()
	second.setup(2, "med_kit", RunManager.get_tool_data("med_kit"))
	add_child(second)
	await get_tree().process_frame
	var confirmations: Array = []
	second.confirmed.connect(func(index: int, tool_id: String) -> void: confirmations.append([index, tool_id]))
	second.confirm()
	second.confirm()
	await get_tree().process_frame
	_expect(confirmations == [[2, "med_kit"]], "confirm emits the captured index and id once")

	var click_overlay := TOOL_CONFIRM.new()
	click_overlay.setup(0, "energy_cell", data)
	add_child(click_overlay)
	await get_tree().process_frame
	var click_cancelled := 0
	click_overlay.cancelled.connect(func() -> void: click_cancelled += 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click_overlay.find_child("Scrim", true, false).emit_signal("gui_input", click)
	await get_tree().process_frame
	_expect(click_cancelled == 1, "clicking the scrim cancels")

	var escape_overlay := TOOL_CONFIRM.new()
	escape_overlay.setup(0, "energy_cell", data)
	add_child(escape_overlay)
	await get_tree().process_frame
	var escape_cancelled := 0
	escape_overlay.cancelled.connect(func() -> void: escape_cancelled += 1)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	escape_overlay.call("_unhandled_input", escape)
	await get_tree().process_frame
	_expect(escape_cancelled == 1, "Escape cancels")

	if failures.is_empty():
		print("[OK] Tool confirmation component contract passed")
		get_tree().quit(0)
		return
	push_error("Tool confirmation component contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
```

- [ ] **Step 2: Run the component contract and verify it fails on the missing script**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/tool_use_confirm_contract_test.tscn
```

Expected: non-zero exit because `res://battle_scene/ui/tool_use_confirm.gd` does not exist.

- [ ] **Step 3: Add localized confirmation copy**

Append these exact rows to `assets/translations/ui_battle.csv`:

```csv
UI_BATTLE_TOOL_CONFIRM_TITLE,USE TOOL?,确认使用工具？
UI_BATTLE_TOOL_USE,USE,使用
```

The component reuses `UI_COMMON_CANCEL` for the secondary action and existing `TOOL_<id>_TITLE` / `TOOL_<id>_DESC` strings for content.

- [ ] **Step 4: Implement the focused confirmation control**

Create `battle_scene/ui/tool_use_confirm.gd`:

```gdscript
extends Control

signal confirmed(index: int, tool_id: String)
signal cancelled

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

var _index := -1
var _tool_id := ""
var _tool_data: Dictionary = {}
var _settled := false


func setup(index: int, tool_id: String, tool_data: Dictionary) -> void:
	_index = index
	_tool_id = tool_id
	_tool_data = tool_data.duplicate(true)


func _ready() -> void:
	name = "ToolUseConfirm"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.0, 0.0, 0.0, 0.66)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 250)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", T.ll_charcoal_panel())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = tr("UI_BATTLE_TOOL_CONFIRM_TITLE")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", T.display_font(700))
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", T.UI_BRASS_LIGHT)
	column.add_child(heading)

	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 16)
	column.add_child(item_row)

	var icon := TextureRect.new()
	icon.name = "ToolIcon"
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := str(_tool_data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	item_row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.custom_minimum_size = Vector2(270, 0)
	copy.add_theme_constant_override("separation", 6)
	item_row.add_child(copy)
	var title := Label.new()
	title.name = "ToolName"
	title.text = Settings.t("TOOL_%s_TITLE" % _tool_id, str(_tool_data.get("title", _tool_id)))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", T.TEXT_MAIN)
	copy.add_child(title)
	var description := Label.new()
	description.name = "ToolDescription"
	description.text = Settings.t("TOOL_%s_DESC" % _tool_id, "")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	copy.add_child(description)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var cancel_button := _make_button("CancelButton", tr("UI_COMMON_CANCEL"), false)
	cancel_button.pressed.connect(cancel)
	actions.add_child(cancel_button)
	var use_button := _make_button("UseButton", tr("UI_BATTLE_TOOL_USE"), true)
	use_button.pressed.connect(confirm)
	actions.add_child(use_button)
	use_button.grab_focus()


func _make_button(node_name: String, label: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_stylebox_override("normal", T.ll_button("normal") if primary else T.ll_button_olive("normal"))
	button.add_theme_stylebox_override("hover", T.ll_button("hover") if primary else T.ll_button_olive("hover"))
	button.add_theme_stylebox_override("pressed", T.ll_button("pressed") if primary else T.ll_button_olive("pressed"))
	return button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cancel()


func confirm() -> void:
	if _settled:
		return
	_settled = true
	confirmed.emit(_index, _tool_id)
	queue_free()


func cancel() -> void:
	if _settled:
		return
	_settled = true
	cancelled.emit()
	queue_free()
```

- [ ] **Step 5: Import translations and run the component contract**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --import
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/tool_use_confirm_contract_test.tscn
```

Expected: import exits 0; contract exits 0 with exactly one cancel emission and one `[2, "med_kit"]` confirmation.

- [ ] **Step 6: Verify the component diff without staging the dirty translation file**

```powershell
git diff --check -- battle_scene/ui/tool_use_confirm.gd tests/tool_use_confirm_contract_test.gd tests/tool_use_confirm_contract_test.tscn assets/translations/ui_battle.csv
git status --short -- battle_scene/ui/tool_use_confirm.gd tests/tool_use_confirm_contract_test.gd tests/tool_use_confirm_contract_test.tscn assets/translations/ui_battle.csv
```

Expected: diff check is empty; the three new files are untracked and `ui_battle.csv` remains modified but unstaged. Keep the batch uncommitted because the translation file contains pre-existing edits.

---

### Task 3: Gate battle tool resolution behind confirmation

**Files:**
- Modify: `tests/tool_use_confirm_contract_test.gd`
- Modify: `battle_scene/battle_scene.gd:1-40,425-462`

**Interfaces:**
- Consumes: `ToolUseConfirm.confirmed(index, tool_id)` and `ToolUseConfirm.cancelled`.
- Produces: `use_tool(index: int) -> void` that opens at most one confirmation and performs no immediate mutation.
- Produces: `_on_tool_use_confirmed(index: int, expected_tool_id: String) -> void` that revalidates index and id before calling `_resolve_tool()`.
- Produces: `_find_tool_target(tdata: Dictionary) -> Node`, preserving first-valid-enemy selection.

- [ ] **Step 1: Extend the contract with real battle integration assertions**

Add this preload:

```gdscript
const BATTLE_SCENE = preload("res://battle_scene/battle_scene.tscn")
```

Call `await _test_battle_confirmation_flow()` after the component assertions, before reporting the final result. Add:

```gdscript
func _test_battle_confirmation_flow() -> void:
	var original_tools: Array[String] = RunManager.tool_inventory.duplicate()
	RunManager.tool_inventory.assign(["energy_cell"])
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	for _i in range(4):
		await get_tree().process_frame

	battle.use_tool(0)
	await get_tree().process_frame
	_expect(RunManager.tool_inventory == ["energy_cell"], "opening confirmation does not consume")
	var first := battle.find_child("ToolUseConfirm", true, false)
	_expect(first != null, "battle opens the custom tool confirmation")
	if first != null:
		first.cancel()
	await get_tree().process_frame
	_expect(RunManager.tool_inventory == ["energy_cell"], "cancel leaves tool inventory unchanged")

	battle.use_tool(0)
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(battle.find_children("ToolUseConfirm", "Control", true, false).size() == 1, "duplicate clicks keep one overlay")
	var confirm := battle.find_child("ToolUseConfirm", true, false)
	if confirm != null:
		confirm.confirm()
	for _i in range(4):
		await get_tree().process_frame
	_expect(RunManager.tool_inventory.is_empty(), "confirm resolves and consumes exactly one tool")

	RunManager.tool_inventory.assign(["med_kit"])
	battle.use_tool(0)
	await get_tree().process_frame
	var stale := battle.find_child("ToolUseConfirm", true, false)
	RunManager.tool_inventory[0] = "smoke_bomb"
	if stale != null:
		stale.confirm()
	for _i in range(2):
		await get_tree().process_frame
	_expect(RunManager.tool_inventory == ["smoke_bomb"], "stale confirmation cannot consume a replacement tool")

	for enemy in battle.enemy_container.get_children():
		enemy.queue_free()
	await get_tree().process_frame
	RunManager.tool_inventory.assign(["frag_grenade"])
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(battle.find_child("ToolUseConfirm", true, false) == null, "enemy tool with no target opens no confirmation")
	_expect(RunManager.tool_inventory == ["frag_grenade"], "missing target does not consume the tool")

	battle.queue_free()
	await get_tree().process_frame
	RunManager.tool_inventory.assign(original_tools)
```

- [ ] **Step 2: Run the integration contract and prove immediate consumption/duplicate behavior fails**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/tool_use_confirm_contract_test.tscn
```

Expected: non-zero exit because `battle.use_tool(0)` still resolves immediately and no `ToolUseConfirm` appears.

- [ ] **Step 3: Add pending-confirmation state to the battle scene**

Add near the other preloads and member variables:

```gdscript
const TOOL_USE_CONFIRM = preload("res://battle_scene/ui/tool_use_confirm.gd")

var _tool_confirm: Control = null
var _tool_resolving := false
```

- [ ] **Step 4: Replace direct use with open/revalidate/resolve flow**

Replace `use_tool()` and insert the helpers before `_resolve_tool()`:

```gdscript
func use_tool(index: int) -> void:
	if is_instance_valid(_tool_confirm) or _tool_resolving:
		return
	if index < 0 or index >= RunManager.tool_inventory.size():
		return
	var tool_id := str(RunManager.tool_inventory[index])
	var tdata: Dictionary = RunManager.get_tool_data(tool_id)
	if tdata.is_empty():
		return
	if str(tdata.get("target", "none")) == "enemy" and _find_tool_target(tdata) == null:
		AudioManager.play_sfx("error")
		return
	var overlay := TOOL_USE_CONFIRM.new()
	overlay.setup(index, tool_id, tdata)
	overlay.confirmed.connect(_on_tool_use_confirmed)
	overlay.cancelled.connect(_on_tool_use_cancelled)
	overlay.tree_exited.connect(_on_tool_confirm_exited.bind(overlay))
	_tool_confirm = overlay
	add_child(overlay)


func _on_tool_use_confirmed(index: int, expected_tool_id: String) -> void:
	_tool_confirm = null
	if index < 0 or index >= RunManager.tool_inventory.size():
		return
	if str(RunManager.tool_inventory[index]) != expected_tool_id:
		return
	var tdata: Dictionary = RunManager.get_tool_data(expected_tool_id)
	if tdata.is_empty():
		return
	var target := _find_tool_target(tdata)
	if str(tdata.get("target", "none")) == "enemy" and target == null:
		AudioManager.play_sfx("error")
		return
	_tool_resolving = true
	await _resolve_tool(index, tdata, target)
	_tool_resolving = false


func _on_tool_use_cancelled() -> void:
	_tool_confirm = null


func _on_tool_confirm_exited(overlay: Control) -> void:
	if _tool_confirm == overlay:
		_tool_confirm = null


func _find_tool_target(tdata: Dictionary) -> Node:
	if str(tdata.get("target", "none")) != "enemy":
		return null
	for candidate in enemy_container.get_children():
		if (
			is_instance_valid(candidate)
			and not candidate.is_queued_for_deletion()
			and candidate.has_method("take_damage")
		):
			return candidate
	return null
```

Keep `_resolve_tool()` as the only effect-and-consume pipeline. The stale-id check must occur before target resolution and before any effect call.

- [ ] **Step 5: Run focused and neighboring battle/UI contracts**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/tool_use_confirm_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/ui_sts2_hud_contract_test.tscn
```

Expected: both exit 0; open/cancel/duplicate/confirm/stale assertions pass, and the top-bar/energy/end-turn contract remains unchanged.

- [ ] **Step 6: Verify the battle integration diff without staging**

```powershell
git diff --check -- battle_scene/battle_scene.gd tests/tool_use_confirm_contract_test.gd
git status --short -- battle_scene/battle_scene.gd tests/tool_use_confirm_contract_test.gd
```

Expected: diff check is empty. Leave both paths unstaged because `battle_scene.gd` contains pre-existing work.

---

### Task 4: Verify the complete change and update save slot 1 test funds

**Files:**
- Verify only: all production/test files from Tasks 1-3.
- External backup: `%APPDATA%\Godot\app_userdata\CardFramework\slot_1\meta.json.bak-<timestamp>`.
- Modify external user data: `%APPDATA%\Godot\app_userdata\CardFramework\slot_1\meta.json`.

**Interfaces:**
- Consumes: a valid save-slot JSON object containing `caps` and `scrap`.
- Produces: the same object with only `caps = 5000` and `scrap = 5000`, plus a byte-for-byte backup of the prior file.

- [ ] **Step 1: Run every relevant contract and the headless smoke gate**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/equipment_tool_shop_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/character_window_layout_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/tool_use_confirm_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/ui_sts2_hud_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 5
```

Expected: all five commands exit 0; smoke output contains no script parse errors, invalid calls, or schema errors.

- [ ] **Step 2: Check source diffs for whitespace/errors and verify commit scope**

```powershell
git diff --check
git status --short
```

Expected: `git diff --check` is empty; all implementation changes remain unstaged; unrelated pre-existing changes remain untouched.

- [ ] **Step 3: Back up and modify the save atomically**

Run this exact PowerShell block after tests pass:

```powershell
$save = Join-Path $env:APPDATA 'Godot\app_userdata\CardFramework\slot_1\meta.json'
if (-not (Test-Path -LiteralPath $save -PathType Leaf)) { throw "Save slot 1 not found: $save" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "$save.bak-$stamp"
Copy-Item -LiteralPath $save -Destination $backup

$profile = Get-Content -Raw -LiteralPath $save | ConvertFrom-Json
$profile.caps = 5000
$profile.scrap = 5000
$json = $profile | ConvertTo-Json -Depth 100
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($save, $json + [Environment]::NewLine, $utf8)

$before = Get-Content -Raw -LiteralPath $backup | ConvertFrom-Json
$after = Get-Content -Raw -LiteralPath $save | ConvertFrom-Json
if ($after.caps -ne 5000 -or $after.scrap -ne 5000) { throw 'Test funds were not written' }
$before.caps = $after.caps
$before.scrap = $after.scrap
$beforeComparable = $before | ConvertTo-Json -Depth 100 -Compress
$afterComparable = $after | ConvertTo-Json -Depth 100 -Compress
if ($beforeComparable -ne $afterComparable) { throw 'A save field other than caps/scrap changed' }
[pscustomobject]@{ Save = $save; Backup = $backup; Caps = $after.caps; Scrap = $after.scrap }
```

Expected: output reports the save and backup paths with `Caps = 5000` and `Scrap = 5000`; comparison throws no exception.

- [ ] **Step 4: Re-read the save and report the verified result**

```powershell
$save = Join-Path $env:APPDATA 'Godot\app_userdata\CardFramework\slot_1\meta.json'
$profile = Get-Content -Raw -LiteralPath $save | ConvertFrom-Json
[pscustomobject]@{ Caps = $profile.caps; Scrap = $profile.scrap; TutorialSeen = $profile.tutorial_seen }
Get-ChildItem -LiteralPath (Split-Path -Parent $save) -Filter 'meta.json.bak-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 FullName,Length,LastWriteTime
```

Expected: Caps and Scrap are both 5000, the unrelated `TutorialSeen` value is preserved, and the newest backup exists with non-zero length.
