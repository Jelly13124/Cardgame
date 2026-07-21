## End-of-run result screen — defeat or demo-complete.
##
## Owner sets `mode` ("defeat" | "demo_complete") BEFORE add_child, then adds it
## on a CanvasLayer. Reads the (already torn-down) run summary off RunManager,
## shows it, and routes the player back to the home base. No class_name per ADR-0006.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAIN_MENU_PATH := "res://run_system/ui/main_menu.tscn"
## Set this project setting to the real app page before shipping. An empty or
## generic URL deliberately hides the CTA instead of sending players to Steam's
## home page and pretending the store integration is finished.
const STORE_URL_SETTING := "application/config/store_url"

## "defeat" or "demo_complete". Set by the owner before add_child.
var mode: String = "defeat"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var is_win := mode == "demo_complete"

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 420)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var title := Label.new()
	title.text = tr("RESULT_DEMO_TITLE") if is_win else tr("RESULT_DEFEAT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", T.ACCENT_NEON_GREEN if is_win else T.ACCENT_DANGER)
	box.add_child(title)

	var body := Label.new()
	body.text = tr("RESULT_DEMO_BODY") if is_win else tr("RESULT_DEFEAT_BODY")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", T.TEXT_MAIN)
	box.add_child(body)

	var summary := Label.new()
	summary.text = _summary_text()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 18)
	summary.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	box.add_child(summary)

	var details := Label.new()
	details.text = _detail_text()
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_theme_font_size_override("font_size", 17)
	details.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	box.add_child(details)

	if _store_url() != "":
		# The conversion ask belongs on both paths once a real page is configured.
		var teaser := Label.new()
		teaser.text = tr("RESULT_TEASER")
		teaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		teaser.custom_minimum_size = Vector2(560, 0)
		teaser.add_theme_font_size_override("font_size", 18)
		teaser.add_theme_color_override("font_color", T.ACCENT_NEON_BLUE)
		box.add_child(teaser)

		var wishlist_btn := Button.new()
		wishlist_btn.text = tr("RESULT_WISHLIST")
		wishlist_btn.custom_minimum_size = Vector2(360, 52)
		wishlist_btn.focus_mode = Control.FOCUS_NONE
		wishlist_btn.add_theme_font_size_override("font_size", 20)
		T.apply_button_theme(wishlist_btn)
		wishlist_btn.pressed.connect(_on_wishlist)
		box.add_child(wishlist_btn)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	box.add_child(gap)

	var back := Button.new()
	back.text = tr("RESULT_BACK_TO_MENU") if is_win else tr("RESULT_BACK_TO_BASE")
	back.custom_minimum_size = Vector2(320, 56)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(back)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _summary_text() -> String:
	var hero_id: String = str(RunManager.current_hero_id)
	var hero_name: String = hero_id
	if typeof(RunManager.current_hero_data) == TYPE_DICTIONARY:
		hero_name = str(RunManager.current_hero_data.get("name", hero_id))
	hero_name = Settings.t("HERO_%s_NAME" % hero_id, hero_name)
	return (
		tr("RESULT_SUMMARY")
		. format(
			{
				"hero": hero_name,
				"act": RunManager.current_act,
				"floor": int(RunManager.current_floor) + 1,
			}
		)
	)


func _detail_text() -> String:
	var gear_count := 0
	for slot in RunManager.EQUIPMENT_SLOTS:
		if not RunManager.as_equip_instance(RunManager.equipped_items.get(slot, {})).is_empty():
			gear_count += 1
	return (
		tr("RESULT_SUMMARY_DETAILS")
		. format(
			{
				"cards": RunManager.player_deck.size(),
				"relics": RunManager.relics.size(),
				"gear": gear_count,
			}
		)
	)


func _store_url() -> String:
	var url := str(ProjectSettings.get_setting(STORE_URL_SETTING, "")).strip_edges()
	if not url.begins_with("https://store.steampowered.com/app/"):
		return ""
	return url


func _on_back() -> void:
	AudioManager.play_sfx("ui_back")
	var destination := MAIN_MENU_PATH if mode == "demo_complete" else HOME_BASE_PATH
	SceneTransition.change_to(destination)


func _on_wishlist() -> void:
	AudioManager.play_sfx("ui_click")
	var url := _store_url()
	if url != "":
		OS.shell_open(url)
