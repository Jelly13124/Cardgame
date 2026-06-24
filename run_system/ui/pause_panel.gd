## Unified pause / settings overlay. ESC and the ⚙ gear both open it. Top level:
## Resume · Settings · (Abandon) · Quit. "Settings" swaps to the detailed audio /
## key-binding / display controls; Abandon (red, only while a run is active) and Quit
## (red) each ask for confirmation first. Abandon discards the run and returns to the
## home base; Quit exits the application.
##
## No class_name (ADR-0006): owner instances with `.new()`, optionally sets `on_resume`
## and `show_abandon`, then add_childs it (ideally on a high CanvasLayer).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const RULES_PANEL = preload("res://run_system/ui/rules_panel.gd")
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"

## Called when the player resumes (lets the opener unpause / clear its guard). Optional.
var on_resume: Callable = Callable()
## Show the Abandon → base option (true mid-run; false at the home base where it's moot).
var show_abandon: bool = true

var _body: VBoxContainer  # swapped between the menu, settings, and confirm views


## Convenience opener: drop the panel on a fresh high CanvasLayer under `host`. No-op if
## one is already open. `abandon` shows the Abandon option (pass RunManager.is_run_active).
static func open(host: Node, abandon: bool, on_resume: Callable = Callable()) -> void:
	if host.get_node_or_null("PauseLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "PauseLayer"
	layer.layer = 160
	host.add_child(layer)
	var panel = load("res://run_system/ui/pause_panel.gd").new()
	panel.show_abandon = abandon
	panel.on_resume = on_resume
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()
	_show_menu()
	T.fade_in(self)


func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 540)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 30)
	panel.add_child(margin)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_body)


func _clear_body() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


# --- Top-level menu ---------------------------------------------------------
func _show_menu() -> void:
	_clear_body()
	_body.add_child(_title(tr("PAUSE_TITLE")))
	_body.add_child(_gap(8))
	_body.add_child(_menu_button(tr("PAUSE_RESUME"), _resume))
	_body.add_child(_menu_button(tr("PAUSE_SETTINGS"), _show_settings))
	_body.add_child(_menu_button(tr("MENU_HOWTO"), _open_howto))
	if show_abandon:
		_body.add_child(_menu_button(tr("PAUSE_ABANDON"), _confirm_abandon, true))
	_body.add_child(_menu_button(tr("PAUSE_QUIT"), _confirm_quit, true))


# --- Settings sub-view (the detailed controls) ------------------------------
func _show_settings() -> void:
	_clear_body()
	_body.add_child(_title(tr("SETTINGS_TITLE")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 392)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	# in_battle=true shows the "restart to apply language" note; the no-op language
	# callback avoids reloading the scene under the pause (which would drop the run).
	SETTINGS_PANEL.add_controls(inner, func() -> void: pass, true)
	SETTINGS_PANEL.add_key_controls(inner)
	_body.add_child(_menu_button(tr("PAUSE_BACK"), _show_menu))


# --- Confirmations ----------------------------------------------------------
func _confirm_abandon() -> void:
	_show_confirm(tr("PAUSE_ABANDON_CONFIRM"), _do_abandon)


func _confirm_quit() -> void:
	_show_confirm(tr("PAUSE_QUIT_CONFIRM"), _do_quit)


func _show_confirm(text: String, on_yes: Callable) -> void:
	_clear_body()
	_body.add_child(_title(tr("PAUSE_CONFIRM_TITLE")))
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(440, 0)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", T.TEXT_MAIN)
	_body.add_child(lbl)
	_body.add_child(_gap(8))
	_body.add_child(_menu_button(tr("PAUSE_CONFIRM_YES"), on_yes, true))
	_body.add_child(_menu_button(tr("PAUSE_CONFIRM_NO"), _show_menu))


func _do_abandon() -> void:
	AudioManager.play_sfx("ui_back")
	Engine.time_scale = 1.0  # in case a battle set a fast-forward
	RunManager.abandon_run()
	SceneTransition.change_to(HOME_BASE_PATH)


func _do_quit() -> void:
	# Save an active run first so "Quit" never destroys progress — the title screen's
	# Continue can resume it next launch. (The player still perceives a direct exit.)
	if RunManager.is_run_active:
		RunManager.save_run()
	get_tree().quit()


func _open_howto() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RulesLayer"
	layer.layer = 170
	add_child(layer)
	var panel = RULES_PANEL.new()
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _resume() -> void:
	AudioManager.play_sfx("ui_back")
	if on_resume.is_valid():
		on_resume.call()
	queue_free()


# ESC backs out one level (settings/confirm → menu, menu → resume).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()


# --- Small widget helpers ---------------------------------------------------
func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	return l


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _menu_button(text: String, cb: Callable, danger: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	T.apply_button_theme(b)
	if danger:
		# Whole button red (not just the label) for the destructive Abandon / Quit actions.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.52, 0.13, 0.11)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.86, 0.32, 0.26)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		var sb_hover: StyleBoxFlat = sb.duplicate()
		sb_hover.bg_color = Color(0.68, 0.17, 0.14)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb_hover)
		b.add_theme_stylebox_override("pressed", sb_hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.90))
		b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	b.pressed.connect(cb)
	return b
