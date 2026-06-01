## Reusable upgrade-card widget used inside home_base_scene.
## Renders: title, level dots (●●○), next-tier preview text, cost,
## BUY button. Listens to MetaProgress.core_changed + upgrades_changed
## to refresh state. When BUY is pressed, calls MetaProgress.purchase_upgrade.
extends PanelContainer
class_name UpgradePanel

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

var _definition: Dictionary = {}

var _title_label: Label
var _level_label: Label
var _effect_label: Label
var _cost_label: Label
var _buy_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(320, 204)
	add_theme_stylebox_override("panel", T.panel_textured("dark"))
	if not _title_label:
		_build()


func _build() -> void:
	if _title_label:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	_title_label = Label.new()
	_style_label(_title_label, 22, Color(1, 0.92, 0.55), 2)
	vbox.add_child(_title_label)

	_level_label = Label.new()
	_style_label(_level_label, 20, Color(0.90, 0.90, 0.86), 1)
	vbox.add_child(_level_label)

	_effect_label = Label.new()
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_effect_label, 18, Color(0.94, 0.90, 0.78), 1)
	_effect_label.custom_minimum_size = Vector2(250, 44)
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_effect_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom)

	_cost_label = Label.new()
	_style_label(_cost_label, 20, Color(0.64, 0.90, 1.0), 1)
	bottom.add_child(_cost_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(96, 36)
	T.apply_button_theme(_buy_button)
	_buy_button.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	_buy_button.pressed.connect(_on_buy_pressed)
	bottom.add_child(_buy_button)

	MetaProgress.core_changed.connect(func(_v): _refresh())
	MetaProgress.upgrades_changed.connect(_refresh)


func set_definition(definition: Dictionary) -> void:
	_definition = definition
	if not _title_label:
		_build()
	_refresh()


func _style_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", outline_size)


func _refresh() -> void:
	if not _title_label or _definition.is_empty():
		return
	var id := str(_definition.get("id", ""))
	var tiers: Array = _definition.get("tiers", [])
	var lvl := MetaProgress.get_upgrade_level(id)

	var upgrade_name := Settings.t("UPGRADE_%s_NAME" % id, str(_definition.get("name", id)))
	_title_label.text = upgrade_name.to_upper()

	# Level dots: ●●○ for 2/3, etc.
	var dots := ""
	for i in range(tiers.size()):
		dots += "●" if i < lvl else "○"
	_level_label.text = tr("UI_HOME_UPGRADE_LEVEL").format(
		{"dots": dots, "cur": lvl, "max": tiers.size()}
	)

	if lvl >= tiers.size():
		_effect_label.text = tr("UI_HOME_UPGRADE_FULLY_UPGRADED")
		_cost_label.text = ""
		_buy_button.text = tr("UI_HOME_UPGRADE_MAXED")
		_buy_button.disabled = true
		return

	var next_tier: Dictionary = tiers[lvl]
	var effect_text := Settings.t(
		"UPGRADE_%s_TIER%d" % [id, int(next_tier.get("level", lvl + 1))],
		str(next_tier.get("effect_text", ""))
	)
	_effect_label.text = tr("UI_HOME_UPGRADE_NEXT").format({"text": effect_text})
	_cost_label.text = tr("UI_HOME_UPGRADE_COST").format({"n": int(next_tier.get("cost", 0))})
	_buy_button.text = tr("UI_HOME_UPGRADE_BUY")
	_buy_button.disabled = not MetaProgress.can_purchase(id, _definition)


func _on_buy_pressed() -> void:
	if _definition.is_empty():
		return
	MetaProgress.purchase_upgrade(str(_definition.get("id", "")), _definition)
