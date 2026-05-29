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
	custom_minimum_size = Vector2(320, 200)
	add_theme_stylebox_override("panel", T.panel_textured("dark"))
	if not _title_label:
		_build()


func _build() -> void:
	if _title_label:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	vbox.add_child(_title_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 20)
	_level_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_level_label)

	_effect_label = Label.new()
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
	_effect_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(_effect_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 20)
	_cost_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	bottom.add_child(_cost_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(96, 36)
	_buy_button.pressed.connect(_on_buy_pressed)
	bottom.add_child(_buy_button)

	MetaProgress.core_changed.connect(func(_v): _refresh())
	MetaProgress.upgrades_changed.connect(_refresh)


func set_definition(definition: Dictionary) -> void:
	_definition = definition
	if not _title_label:
		_build()
	_refresh()


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
