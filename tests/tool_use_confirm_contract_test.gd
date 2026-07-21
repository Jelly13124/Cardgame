extends Node

const TOOL_CONFIRM = preload("res://battle_scene/ui/tool_use_confirm.gd")
const BATTLE_SCENE = preload("res://battle_scene/battle_scene.tscn")

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var data := RunManager.get_tool_data("energy_cell")
	var overlay := TOOL_CONFIRM.new()
	overlay.setup(0, "energy_cell", data)
	add_child(overlay)
	await _frames(2)

	_expect(overlay.name == "ToolUseConfirm", "confirmation root has a stable name")
	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "confirmation blocks battle input")
	_expect(
		overlay.size == get_viewport().get_visible_rect().size,
		"confirmation covers the viewport"
	)
	var scrim := overlay.find_child("Scrim", true, false) as ColorRect
	_expect(
		scrim != null and scrim.color.a < 0.8,
		"translucent scrim leaves the battle recognizable"
	)
	for child_name in ["ToolIcon", "ToolName", "ToolDescription", "UseButton", "CancelButton"]:
		_expect(overlay.find_child(child_name, true, false) != null, "%s exists" % child_name)
	var icon := overlay.find_child("ToolIcon", true, false) as TextureRect
	_expect(icon != null and icon.texture != null, "confirmation renders the tool icon")
	if icon != null and icon.texture != null:
		_expect(
			icon.texture.resource_path.ends_with("/energy_cell.png"),
			"confirmation uses the requested tool art"
		)

	var cancel_events: Array[bool] = []
	overlay.cancelled.connect(func() -> void: cancel_events.append(true))
	overlay.cancel()
	overlay.cancel()
	await get_tree().process_frame
	_expect(cancel_events.size() == 1, "cancel emits once")

	var second := TOOL_CONFIRM.new()
	second.setup(2, "med_kit", RunManager.get_tool_data("med_kit"))
	add_child(second)
	await get_tree().process_frame
	var confirmations: Array = []
	second.confirmed.connect(
		func(index: int, tool_id: String) -> void: confirmations.append([index, tool_id])
	)
	second.confirm()
	second.confirm()
	await get_tree().process_frame
	_expect(confirmations == [[2, "med_kit"]], "confirm emits the captured index and id once")

	var click_overlay := TOOL_CONFIRM.new()
	click_overlay.setup(0, "energy_cell", data)
	add_child(click_overlay)
	await get_tree().process_frame
	var click_events: Array[bool] = []
	click_overlay.cancelled.connect(func() -> void: click_events.append(true))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click_overlay.find_child("Scrim", true, false).emit_signal("gui_input", click)
	await get_tree().process_frame
	_expect(click_events.size() == 1, "clicking the scrim cancels")

	var escape_overlay := TOOL_CONFIRM.new()
	escape_overlay.setup(0, "energy_cell", data)
	add_child(escape_overlay)
	await get_tree().process_frame
	var escape_events: Array[bool] = []
	escape_overlay.cancelled.connect(func() -> void: escape_events.append(true))
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	escape_overlay.call("_unhandled_input", escape)
	await get_tree().process_frame
	_expect(escape_events.size() == 1, "Escape cancels")

	await _test_battle_confirmation_flow()

	if failures.is_empty():
		print("[OK] Tool confirmation component contract passed")
		get_tree().quit(0)
		return
	push_error("Tool confirmation component contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_battle_confirmation_flow() -> void:
	var original_tools: Array[String] = RunManager.tool_inventory.duplicate()
	RunManager.tool_inventory.assign(["energy_cell"])
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await _frames(4)

	battle.use_tool(0)
	await get_tree().process_frame
	_expect(RunManager.tool_inventory == ["energy_cell"], "opening confirmation does not consume")
	var first := battle.find_child("ToolUseConfirm", true, false)
	_expect(first != null, "battle opens the custom tool confirmation")
	if first != null:
		first.cancel()
	await get_tree().process_frame
	_expect(RunManager.tool_inventory == ["energy_cell"], "cancel leaves tool inventory unchanged")

	RunManager.tool_inventory.assign(["energy_cell"])
	battle.use_tool(0)
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(
		battle.find_children("ToolUseConfirm", "Control", true, false).size() == 1,
		"duplicate clicks keep one overlay"
	)
	var confirmation := battle.find_child("ToolUseConfirm", true, false)
	if confirmation != null:
		confirmation.confirm()
	var resolved := await _wait_until(func() -> bool: return RunManager.tool_inventory.is_empty())
	_expect(resolved, "confirm resolves and consumes exactly one tool")

	RunManager.tool_inventory.assign(["med_kit"])
	battle.use_tool(0)
	await get_tree().process_frame
	var stale := battle.find_child("ToolUseConfirm", true, false)
	RunManager.tool_inventory.assign(["smoke_bomb"])
	if stale != null:
		stale.confirm()
	await _frames(2)
	_expect(
		RunManager.tool_inventory == ["smoke_bomb"],
		"stale confirmation cannot consume a replacement tool"
	)

	# Enemy-targeted tools have a two-step contract: confirmation only arms the
	# target arrow; the inventory changes after a valid enemy click. Invalid
	# clicks and explicit cancellation leave the tool untouched.
	RunManager.tool_inventory.assign(["toxin_vial"])
	battle.use_tool(0)
	await get_tree().process_frame
	var enemy_confirmation := battle.find_child("ToolUseConfirm", true, false)
	_expect(enemy_confirmation != null, "enemy tool opens confirmation first")
	if enemy_confirmation != null:
		enemy_confirmation.confirm()
	await _frames(2)
	_expect(battle.is_targeting, "confirming an enemy tool enters target selection")
	_expect(battle.call("_is_tool_targeting"), "target selection tracks a pending tool")
	_expect(
		RunManager.tool_inventory == ["toxin_vial"],
		"confirming an enemy tool does not consume before target selection"
	)
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(
		battle.find_child("ToolUseConfirm", true, false) == null,
		"tool clicks are ignored while target selection is active"
	)
	battle.call("_confirm_tool_targeting", null)
	await get_tree().process_frame
	_expect(battle.is_targeting, "an invalid target keeps selection active")
	_expect(
		RunManager.tool_inventory == ["toxin_vial"],
		"an invalid target does not consume the pending tool"
	)

	var escape_targeting := InputEventAction.new()
	escape_targeting.action = "ui_cancel"
	escape_targeting.pressed = true
	battle.call("_input", escape_targeting)
	await get_tree().process_frame
	_expect(not battle.is_targeting, "Escape cancels enemy tool target selection")
	_expect(
		RunManager.tool_inventory == ["toxin_vial"],
		"cancelling target selection leaves the tool inventory unchanged"
	)

	# Re-arm and choose a concrete living enemy. Consumption is exactly once and
	# targeting state is cleared synchronously before effects begin resolving.
	battle.use_tool(0)
	await get_tree().process_frame
	enemy_confirmation = battle.find_child("ToolUseConfirm", true, false)
	if enemy_confirmation != null:
		enemy_confirmation.confirm()
	await _frames(2)
	var chosen_enemy: Node = battle.call("_find_tool_target", RunManager.get_tool_data("toxin_vial"))
	_expect(chosen_enemy != null, "enemy tool selection has a living candidate")
	if chosen_enemy != null:
		battle.call("_confirm_tool_targeting", chosen_enemy)
	var enemy_tool_resolved := await _wait_until(
		func() -> bool: return RunManager.tool_inventory.is_empty()
	)
	_expect(enemy_tool_resolved, "choosing an enemy resolves and consumes exactly one tool")
	_expect(not battle.is_targeting, "successful enemy tool use clears target selection")
	_expect(not battle.call("_is_tool_targeting"), "successful use clears pending tool state")

	for enemy in battle.enemy_container.get_children():
		enemy.queue_free()
	await get_tree().process_frame
	RunManager.tool_inventory.assign(["frag_grenade"])
	battle.use_tool(0)
	await get_tree().process_frame
	_expect(
		battle.find_child("ToolUseConfirm", true, false) == null,
		"enemy tool with no target opens no confirmation"
	)
	_expect(
		RunManager.tool_inventory == ["frag_grenade"],
		"missing target does not consume the tool"
	)

	battle.queue_free()
	await get_tree().process_frame
	RunManager.tool_inventory.assign(original_tools)


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _wait_until(predicate: Callable, max_frames: int = 120) -> bool:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())
