## CurrencyBar — the global currency HUD as its own CanvasLayer: the three
## permanent-currency chips (Core / Caps / Scrap) in a slim strip anchored to
## the BOTTOM-LEFT edge of the screen. (Filename keeps the historical
## "top_bar" name to avoid preload churn — the bar moved to the bottom per
## owner request; the Character entry moved to the home base's right-edge
## image buttons.) Sits on layer 70 — above the WindowLayer (60) — so balances
## stay readable while floating windows are open (still below fullscreen
## popups: RulesLayer 140 / DifficultyPopup 150 / TierConfirm 155).
##
## Labels track MetaProgress.core/caps/scrap_changed; the bar is freed with its
## host scene, which drops the connections.
##
## NO class_name (ADR-0006). Usage:
##   var bar = preload("res://run_system/ui/window/currency_top_bar.gd").new()
##   host_scene.add_child(bar)
extends CanvasLayer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Above WindowLayer's 60 so the balances stay readable over floating windows.
const BAR_LAYER := 70

var _core_label: Label
var _caps_label: Label
var _scrap_label: Label


func _ready() -> void:
	layer = BAR_LAYER

	# Slim chips row along the bottom-left edge (~18px in from bottom/left).
	var row := HBoxContainer.new()
	row.name = "CurrencyHud"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.anchor_left = 0.0
	row.anchor_top = 1.0
	row.anchor_right = 0.0
	row.anchor_bottom = 1.0
	row.offset_left = 18
	row.offset_top = -82
	row.offset_right = 520
	row.offset_bottom = -18
	add_child(row)

	_core_label = _make_currency_chip(row, "core")
	_caps_label = _make_currency_chip(row, "caps")
	_scrap_label = _make_currency_chip(row, "scrap")

	MetaProgress.core_changed.connect(func(_v): _refresh_core())
	MetaProgress.caps_changed.connect(func(_v): _refresh_caps())
	MetaProgress.scrap_changed.connect(func(_v): _refresh_scrap())
	_refresh_core()
	_refresh_caps()
	_refresh_scrap()


## Currency chip: a big number + the Codex currency icon (T.currency_row), sat
## bare on the scene (no background frame — owner request). If the icon PNG is
## missing, currency_row falls back to a small currency-word label so the
## counter stays readable even if the art regresses. Ported verbatim from
## home_base_scene._make_currency_chip.
func _make_currency_chip(parent: Control, icon_id: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(134, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := T.currency_row(0, icon_id, 31, 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# Style the row's amount Label to match the prior big/bright HUD look and hand
	# it back so _refresh_* can update it.
	var label := row.get_meta("amount_label") as Label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _refresh_core() -> void:
	if is_instance_valid(_core_label):
		_core_label.text = str(MetaProgress.core)


func _refresh_caps() -> void:
	if is_instance_valid(_caps_label):
		_caps_label.text = str(MetaProgress.caps)


func _refresh_scrap() -> void:
	if is_instance_valid(_scrap_label):
		_scrap_label.text = str(MetaProgress.scrap)
