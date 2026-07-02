## CurrencyTopBar — the global currency HUD as its own CanvasLayer: the three
## permanent-currency chips (Core / Caps / Scrap, ported from home_base_scene's
## old _add_currency_hud) plus a Character button that toggles the floating
## character window on the host scene. Sits on layer 70 — above the WindowLayer
## (60) — so balances stay readable while floating windows are open (still below
## fullscreen popups: RulesLayer 140 / TierConfirm 155).
##
## Labels track MetaProgress.core/caps/scrap_changed; the bar is freed with its
## host scene, which drops the connections.
##
## NO class_name (ADR-0006). Usage:
##   var bar = preload("res://run_system/ui/window/currency_top_bar.gd").new()
##   bar.setup(host_scene)  # the node whose WindowLayer hosts the window
##   host_scene.add_child(bar)
extends CanvasLayer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Above WindowLayer's 60 so the balances + Character button stay usable over
## floating windows.
const BAR_LAYER := 70

## The node the Character button opens the character window on. Set via setup().
var _host: Node = null

var _core_label: Label
var _caps_label: Label
var _scrap_label: Label


## Store the scene the Character button targets (its WindowLayer hosts the window).
func setup(host: Node) -> void:
	_host = host


func _ready() -> void:
	layer = BAR_LAYER

	# Same top-left strip the old home-base HUD occupied, widened for the button.
	var row := HBoxContainer.new()
	row.name = "CurrencyHud"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.anchor_right = 0.0
	row.anchor_bottom = 0.0
	row.offset_left = 22
	row.offset_top = 28
	row.offset_right = 700
	row.offset_bottom = 92
	add_child(row)

	_core_label = _make_currency_chip(row, "core")
	_caps_label = _make_currency_chip(row, "caps")
	_scrap_label = _make_currency_chip(row, "scrap")

	var btn := Button.new()
	btn.name = "CharacterButton"
	btn.text = tr("UI_HOME_CHARACTER_BTN")
	btn.custom_minimum_size = Vector2(150, 48)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.apply_button_theme(btn)
	btn.pressed.connect(_on_character_pressed)
	row.add_child(btn)

	MetaProgress.core_changed.connect(func(_v): _refresh_core())
	MetaProgress.caps_changed.connect(func(_v): _refresh_caps())
	MetaProgress.scrap_changed.connect(func(_v): _refresh_scrap())
	_refresh_core()
	_refresh_caps()
	_refresh_scrap()


## Toggle the floating character window (base mode) on the host scene.
func _on_character_pressed() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	AudioManager.play_sfx("ui_click")
	load("res://run_system/ui/window/character_window.gd").open_window(_host, "base")


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
