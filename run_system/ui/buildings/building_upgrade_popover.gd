## Shared anchored upgrade confirmation for every base facility.
##
## The host owns positioning and lifetime: call setup() before add_child(), then
## remove the popover when `dismissed` is emitted. Successful actions also emit
## `state_changed`, even though MetaProgress already broadcasts buildings_changed;
## the explicit signal lets window hosts refresh immediately without depending on
## the global signal order.
extends Control

signal state_changed(building_id: String, tier: int)
signal dismissed

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const FRAME = preload(
	"res://run_system/assets/images/ui/buildings/building_upgrade_popover_frame.png"
)

const POPUP_SIZE := Vector2(384, 288)

const _TIER_UNLOCKS_ZH := {
	"forge": {1: "拆解装备", 2: "打造与重铸", 3: "追咒"},
	"clinic": {1: "永久属性强化", 2: "生命上限", 3: "强化上限提升至 5"},
	"market": {1: "工具货架", 2: "装备货架", 3: "资源兑换"},
	"outpost": {1: "悬赏", 2: "安全格", 3: "永久升级"},
}
const _TIER_UNLOCKS_EN := {
	"forge": {1: "Dismantling", 2: "Crafting and reforging", 3: "Curse work"},
	"clinic": {1: "Permanent attributes", 2: "Maximum health", 3: "Enhancement cap: 5"},
	"market": {1: "Tool shelf", 2: "Equipment shelf", 3: "Resource exchange"},
	"outpost": {1: "Bounties", 2: "Safe cells", 3: "Permanent upgrades"},
}

var building_id := ""

var _title_label: Label
var _tier_label: Label
var _unlock_label: Label
var _cost_host: HBoxContainer
var _held_host: HBoxContainer
var _confirm_button: Button


func setup(id: String) -> void:
	building_id = id


func _ready() -> void:
	name = "BuildingUpgradePopover"
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	_build()
	MetaProgress.scrap_changed.connect(_on_scrap_changed)
	MetaProgress.buildings_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var frame := TextureRect.new()
	frame.name = "UpgradePopoverFrame"
	frame.texture = FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 43)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	_title_label = Label.new()
	_title_label.name = "UpgradePopoverTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", T.display_font(700))
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	box.add_child(_title_label)

	_tier_label = Label.new()
	_tier_label.name = "UpgradePopoverTier"
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_override("font", T.display_font(700))
	_tier_label.add_theme_font_size_override("font_size", 21)
	_tier_label.add_theme_color_override("font_color", T.TEXT_MAIN)
	box.add_child(_tier_label)

	_unlock_label = Label.new()
	_unlock_label.name = "UpgradePopoverUnlock"
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unlock_label.add_theme_font_size_override("font_size", 16)
	_unlock_label.add_theme_color_override("font_color", T.TEXT_MAIN)
	box.add_child(_unlock_label)

	var divider := HSeparator.new()
	divider.modulate = Color(0.72, 0.58, 0.35, 0.55)
	box.add_child(divider)

	var currency_row := HBoxContainer.new()
	currency_row.add_theme_constant_override("separation", 20)
	currency_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(currency_row)

	_cost_host = HBoxContainer.new()
	_cost_host.name = "UpgradePopoverCost"
	_cost_host.alignment = BoxContainer.ALIGNMENT_CENTER
	currency_row.add_child(_cost_host)

	_held_host = HBoxContainer.new()
	_held_host.name = "UpgradePopoverHeld"
	_held_host.alignment = BoxContainer.ALIGNMENT_CENTER
	currency_row.add_child(_held_host)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)

	var cancel := Button.new()
	cancel.name = "UpgradePopoverCancel"
	cancel.text = _local_text("取消", "CANCEL")
	cancel.custom_minimum_size = Vector2(0, 50)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_action_button(cancel, false)
	cancel.pressed.connect(_on_cancel_pressed)
	actions.add_child(cancel)

	_confirm_button = Button.new()
	_confirm_button.name = "UpgradePopoverConfirm"
	_confirm_button.text = _local_text("确认升级", "CONFIRM")
	_confirm_button.custom_minimum_size = Vector2(0, 50)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_action_button(_confirm_button, true)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(_confirm_button)


func _refresh() -> void:
	if building_id.is_empty() or not is_instance_valid(_confirm_button):
		return
	var tier := MetaProgress.get_building_tier(building_id)
	var next_tier := tier + 1
	var cost := MetaProgress.next_building_cost(building_id)
	var building_name := tr("UI_BUILD_%s_NAME" % building_id.to_upper())

	_title_label.text = _local_text("升级%s", "UPGRADE %s") % building_name
	_tier_label.text = (
		_local_text("未解锁  →  T1", "LOCKED  →  T1")
		if tier <= 0
		else "T%d  →  T%d" % [tier, next_tier]
	)
	_unlock_label.text = _local_text("解锁：%s", "UNLOCK: %s") % _next_unlock_name(next_tier)

	_rebuild_currency_host(_cost_host, _local_text("升级费用", "COST"), maxi(cost, 0))
	_rebuild_currency_host(_held_host, _local_text("持有", "HELD"), MetaProgress.scrap)

	var maxed := cost < 0 or tier >= MetaProgress.MAX_BUILDING_TIER
	var affordable := not maxed and MetaProgress.scrap >= cost
	_confirm_button.disabled = not affordable
	_confirm_button.modulate = Color.WHITE if affordable else Color(0.58, 0.58, 0.58, 0.9)
	if maxed:
		_confirm_button.text = tr("UI_BUILD_MAX")
		_confirm_button.tooltip_text = ""
	else:
		_confirm_button.text = _local_text("确认升级", "CONFIRM")
		_confirm_button.tooltip_text = (
			""
			if affordable
			else _local_text("废料不足，还差 %d", "Not enough Scrap — need %d more")
			% (cost - MetaProgress.scrap)
		)


func _rebuild_currency_host(host: HBoxContainer, prefix: String, amount: int) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	var prefix_label := Label.new()
	prefix_label.text = prefix
	prefix_label.add_theme_font_size_override("font_size", 15)
	prefix_label.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	host.add_child(prefix_label)
	var row := T.currency_row(amount, "scrap", 17, 19)
	_move_icon_first(row)
	host.add_child(row)


func _move_icon_first(row: HBoxContainer) -> void:
	for child in row.get_children():
		if child is TextureRect:
			row.move_child(child, 0)
			return


func _next_unlock_name(next_tier: int) -> String:
	var table: Dictionary = _TIER_UNLOCKS_ZH if Settings.language == "zh" else _TIER_UNLOCKS_EN
	var building_table: Dictionary = table.get(building_id, {})
	return str(
		building_table.get(
			next_tier,
			_local_text("更多建筑功能", "More facility functions"),
		)
	)


func _style_action_button(button: Button, primary: bool) -> void:
	button.add_theme_font_override("font", T.display_font(700))
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", T.TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	if primary:
		T.apply_concept_price_button(button, "orange")
	else:
		button.add_theme_stylebox_override("normal", T.ll_button_dark("normal"))
		button.add_theme_stylebox_override("hover", T.ll_button_dark("hover"))
		button.add_theme_stylebox_override("pressed", T.ll_button_dark("pressed"))
		button.add_theme_stylebox_override("disabled", T.ll_button_dark("disabled"))


func _on_scrap_changed(_value: int) -> void:
	_refresh()


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("ui_back")
	dismissed.emit()


func _on_confirm_pressed() -> void:
	var tier := MetaProgress.get_building_tier(building_id)
	var changed := false
	if tier <= 0:
		changed = MetaProgress.unlock_building(building_id)
	elif tier < MetaProgress.MAX_BUILDING_TIER:
		changed = MetaProgress.upgrade_building(building_id)
	AudioManager.play_sfx("upgrade" if changed else "error")
	if not changed:
		_refresh()
		return
	state_changed.emit(building_id, MetaProgress.get_building_tier(building_id))
	dismissed.emit()


func _local_text(zh: String, en: String) -> String:
	return zh if Settings.language == "zh" else en
