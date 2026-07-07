## Home base scene — the boot scene + post-run return point.
## Layout: the 4 interactive building sprites on the desert scene, plus a
## base-only HUD: top resource chips, top-right difficulty/settings, bottom-left
## bounty board (held contracts + live progress), bottom-center START, and
## bottom-right Warehouse / Character / Gallery buttons. The base's actual
## functions live in the per-building screens (run_system/ui/buildings/).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const PAUSE_PANEL = preload("res://run_system/ui/pause_panel.gd")
## Fallback hero when no character-window selection has been made — the base hero,
## always available. Keeps START NEW RUN robust (a run never begins with an empty hero).
const DEFAULT_HERO_ID := "cowboy_bill"
const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")
const STASH_WINDOW = preload("res://run_system/ui/window/stash_window.gd")
const BUILDING_SCREEN_BASE = preload("res://run_system/ui/buildings/building_screen_base.gd")
## Building selector order + per-building accent color. The tile art lives under
## run_system/assets/images/home/buildings/.
const BUILDING_ORDER := ["forge", "clinic", "market", "outpost"]
## Entry-screen arrangement: two flank columns + a centre column holding the
## START "door", so the layout reads as "2 buildings left / 2 right /
## depart-door centre".
const LEFT_BUILDINGS := ["forge", "clinic"]
const RIGHT_BUILDINGS := ["market", "outpost"]
const BUILDING_IMAGE_DIR := "res://run_system/assets/images/home/buildings_runtime/"
const BUILDING_ACCENTS := {
	"forge": Color(0.92, 0.55, 0.32),
	"clinic": Color(0.46, 0.86, 0.78),
	"market": Color(0.95, 0.82, 0.40),
	"outpost": Color(0.62, 0.78, 0.96),
}
const HOME_BACKGROUND_PATH := "res://run_system/assets/images/home/home_base_empty_bg.png"
const MAP_CANVAS_SIZE := Vector2(1920, 1080)
## Grayscale-darken shader for LOCKED building buttons (replaces the old
## too-subtle modulate 0.75 dim). Applied as the button's material only — the
## brass lock overlay is a SIBLING TextureRect, so it stays full-color.
const LOCKED_DESAT_SHADER = preload("res://run_system/ui/theme/locked_desat.gdshader")
## Common visual ground line: every building's opaque art bottom sits this many
## px above its tile's bottom edge (the PNGs carry uneven transparent padding,
## so identical tile rects would otherwise render art at uneven baselines).
const GROUND_INSET := 12.0
## Bottom-bar Character image button art: the square hero headshot (the same
## avatar run_top_bar uses), with the character window's portrait as fallback.
const HERO_HEADSHOT_PATH := "res://battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_headshot.png"
const HERO_PORTRAIT_PATH := "res://battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png"
const BASE_HUD_ICON_DIR := "res://run_system/assets/images/home/base_hud/"
const CURRENCY_ICON_DIR := "res://run_system/assets/images/home/currency/"
const CARD_DATA_DIR := "res://battle_scene/card_info/player/"
## Locked-gallery slot art: the same card back battle uses (play_card.gd).
const GALLERY_CARD_BACK := "res://battle_scene/assets/images/cards/ui/card_back.png"
const TOP_HUD_LAYER := 70

const BUILDING_BADGE_ICONS := {
	"forge": "badge_forge",
	"clinic": "badge_clinic",
	"market": "badge_market",
	"outpost": "badge_outpost",
}

## The A0..A5 buttons inside the difficulty picker popup (rebuilt every open).
var _difficulty_buttons: Array[Button] = []
## Top-right difficulty button — label shows the current pick ("难度 A{n}").
var _difficulty_button: Button
var _top_currency_labels: Dictionary = {}
## Three-column building area (left flank / centre door / right flank), rebuilt
## on buildings_changed.
var _building_area: HBoxContainer
## Container holding the interactive building sprites + plaques (lock / tier badges).
## Freed + rebuilt on buildings_changed so unlock / tier-up repaints live.
var _buildings_root: Control
## Per-building art-alignment offset (asset_id → Vector2), computed once from
## the normal texture's opaque bbox so buildings_changed rebuilds don't
## re-decode the PNGs every time.
var _art_offset_cache: Dictionary = {}
## Shared ShaderMaterial for locked building buttons (lazy; see LOCKED_DESAT_SHADER).
var _locked_material: ShaderMaterial = null
## The bounty board's rows container (inside the bottom-left panel) — cleared +
## refilled on bounties_changed instead of rebuilding the whole panel chrome.
var _bounty_rows_box: VBoxContainer = null
## The HUD root Control the completion toast overlays onto.
var _base_hud_root: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("home")
	# Roll today's bounty shelf on base entry (not just when the market opens) so
	# the daily date rolls even if the player never visits the Black Market.
	MetaProgress.refresh_bounty_shelf_if_stale()
	_build()
	_connect_home_hud_signals()
	# Repaint the building sprites (lock → unlocked, tier badges) the moment a building
	# changes — previously wired to the inert _rebuild_building_tiles, so the lock only
	# cleared on a scene reload (the "must restart to see it unlocked" bug).
	MetaProgress.buildings_changed.connect(_add_building_sprites)


## `i` toggles the floating character window (hero / loadout / stash); ESC opens
## the unified pause/settings panel (mirrors map_scene's ui_cancel → pause
## wiring). Both are guarded against the full-page overlays / popups: ESC doesn't
## double-open if a panel is already up and defers to any overlay currently open
## (BuildingOverlay owns its own ESC — it backs out to this overview first;
## TierConfirm/RulesLayer are simple popups without their own ESC handler, so ESC
## here would otherwise fall through to Settings while one is open — skip in that
## case too so a stray ESC doesn't stack panels). The character window shouldn't
## open under those overlays either, so KEY_I shares the same guard set.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if _overlay_blocking():
			return
		get_viewport().set_input_as_handled()
		_open_character_window()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if get_node_or_null("PauseLayer") != null:
		return  # already open
	if get_node_or_null("BuildingOverlay") != null:
		return  # the building screen's own _unhandled_input handles ESC first
	var gallery_layer := get_node_or_null("CardGalleryLayer")
	if gallery_layer != null:
		get_viewport().set_input_as_handled()
		gallery_layer.queue_free()
		return
	if (
		get_node_or_null("TierConfirm") != null
		or get_node_or_null("RulesLayer") != null
		or get_node_or_null("DifficultyPopup") != null
	):
		return  # let the open popup own ESC (none currently bind it; avoid stacking)
	get_viewport().set_input_as_handled()
	_open_pause()


## True while a full-page overlay / popup is up (the same set the ESC guards
## check one by one above).
func _overlay_blocking() -> bool:
	return (
		get_node_or_null("PauseLayer") != null
		or get_node_or_null("BuildingOverlay") != null
		or get_node_or_null("TierConfirm") != null
		or get_node_or_null("RulesLayer") != null
		or get_node_or_null("DifficultyPopup") != null
		or get_node_or_null("CardGalleryLayer") != null
	)


func _build() -> void:
	_add_background()
	_add_building_sprites()
	_add_base_hud()


## Open the How-to-Play panel (loaded at runtime; same pattern as map_scene._open_rules_panel).
func _open_rules_panel() -> void:
	var path := "res://run_system/ui/rules_panel.gd"
	if not ResourceLoader.exists(path):
		return
	var script = load(path)
	if script == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "RulesLayer"
	layer.layer = 140
	add_child(layer)
	var panel = script.new()
	panel.tree_exited.connect(layer.queue_free)
	layer.add_child(panel)


func _add_background() -> void:
	var bg_tex := _load_raw_png_texture(HOME_BACKGROUND_PATH)
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.08, 0.07, 0.05, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _load_raw_png_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		var image := Image.new()
		var err := image.load(ProjectSettings.globalize_path(path))
		if err == OK:
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


func _connect_home_hud_signals() -> void:
	MetaProgress.caps_changed.connect(func(_v): _refresh_top_currency("caps"))
	MetaProgress.core_changed.connect(func(_v): _refresh_top_currency("core"))
	MetaProgress.scrap_changed.connect(func(_v): _refresh_top_currency("scrap"))
	# Bound methods (not lambdas) so the autoload connections auto-clean when this
	# scene is freed. bounties_changed repaints the board (market claims/buys,
	# progress); bounty_completed additionally shows the completion toast.
	MetaProgress.bounties_changed.connect(_rebuild_bounty_rows)
	MetaProgress.bounty_completed.connect(_on_bounty_completed)
	_refresh_top_currencies()


func _add_base_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BaseHudLayer"
	layer.layer = TOP_HUD_LAYER
	add_child(layer)

	var root := Control.new()
	root.name = "BaseHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_base_hud_root = root

	_add_top_hud(root)
	_add_bounty_board_panel(root)
	_add_start_run_button(root)
	_add_bottom_nav(root)


func _add_top_hud(root: Control) -> void:
	var top_body := Panel.new()
	top_body.name = "TopHudBar"
	top_body.anchor_left = 0.0
	top_body.anchor_top = 0.0
	top_body.anchor_right = 1.0
	top_body.anchor_bottom = 0.0
	top_body.offset_left = 0.0
	top_body.offset_top = 0.0
	top_body.offset_right = 0.0
	top_body.offset_bottom = 88.0
	top_body.mouse_filter = Control.MOUSE_FILTER_STOP
	top_body.add_theme_stylebox_override("panel", _home_top_bar_style())
	root.add_child(top_body)

	var resources := HBoxContainer.new()
	resources.name = "ResourceChips"
	resources.alignment = BoxContainer.ALIGNMENT_CENTER
	resources.add_theme_constant_override("separation", 24)
	resources.anchor_left = 0.5
	resources.anchor_top = 0.0
	resources.anchor_right = 0.5
	resources.anchor_bottom = 0.0
	resources.offset_left = -410.0
	resources.offset_top = 20.0
	resources.offset_right = 410.0
	resources.offset_bottom = 70.0
	top_body.add_child(resources)

	_top_currency_labels["caps"] = _make_top_currency_chip(resources, "caps")
	_top_currency_labels["core"] = _make_top_currency_chip(resources, "core")
	_top_currency_labels["scrap"] = _make_top_currency_chip(resources, "scrap")
	_refresh_top_currencies()

	var right_controls := HBoxContainer.new()
	right_controls.name = "TopRightControls"
	right_controls.alignment = BoxContainer.ALIGNMENT_END
	right_controls.add_theme_constant_override("separation", 14)
	right_controls.anchor_left = 1.0
	right_controls.anchor_top = 0.0
	right_controls.anchor_right = 1.0
	right_controls.anchor_bottom = 0.0
	right_controls.offset_left = -410.0
	right_controls.offset_top = 16.0
	right_controls.offset_right = -42.0
	right_controls.offset_bottom = 72.0
	top_body.add_child(right_controls)

	right_controls.add_child(_make_top_difficulty_button())
	right_controls.add_child(
		_make_square_icon_button("icon_settings", tr("PAUSE_SETTINGS"), _open_pause)
	)


func _make_top_currency_chip(parent: Control, currency: String) -> Label:
	var panel := PanelContainer.new()
	panel.name = currency.capitalize() + "TopChip"
	panel.custom_minimum_size = Vector2(180, 46)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _home_chip_style())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := _make_icon_rect(CURRENCY_ICON_DIR + currency + ".png", Vector2(34, 34))
	row.add_child(icon)

	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", T.display_font(600))
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.62, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


func _refresh_top_currencies() -> void:
	_refresh_top_currency("caps")
	_refresh_top_currency("core")
	_refresh_top_currency("scrap")


func _refresh_top_currency(currency: String) -> void:
	var label = _top_currency_labels.get(currency, null)
	if not (label is Label) or not is_instance_valid(label):
		return
	match currency:
		"caps":
			label.text = str(MetaProgress.caps)
		"core":
			label.text = str(MetaProgress.core)
		"scrap":
			label.text = str(MetaProgress.scrap)


func _make_top_difficulty_button() -> Button:
	var btn := Button.new()
	btn.name = "DifficultyButton"
	btn.custom_minimum_size = Vector2(278, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _home_button_style("normal"))
	btn.add_theme_stylebox_override("hover", _home_button_style("hover"))
	btn.add_theme_stylebox_override("pressed", _home_button_style("pressed"))
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.pressed.connect(_show_difficulty_popup)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	row.add_child(_make_icon_rect(BASE_HUD_ICON_DIR + "icon_difficulty.png", Vector2(38, 38)))

	var label := Label.new()
	label.name = "DifficultyLabel"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", T.display_font(600))
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.60, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var arrow := Label.new()
	arrow.text = "v"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_override("font", T.display_font(700))
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", Color(0.78, 0.58, 0.32, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	btn.set_meta("label", label)
	_difficulty_button = btn
	_refresh_difficulty_button()
	return btn


func _make_square_icon_button(icon_id: String, tooltip: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.name = icon_id.capitalize() + "Button"
	btn.custom_minimum_size = Vector2(58, 56)
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _home_button_style("normal"))
	btn.add_theme_stylebox_override("hover", _home_button_style("hover"))
	btn.add_theme_stylebox_override("pressed", _home_button_style("pressed"))
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.pressed.connect(callback)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center)
	center.add_child(_make_icon_rect(BASE_HUD_ICON_DIR + icon_id + ".png", Vector2(38, 38)))
	return btn


## Bounty board (bottom-left): the held contracts (MetaProgress.active_bounties,
## max 3) with live progress. Replaces Codex's mock daily-tasks panel — the
## visual shell (panel/header/row language) is Codex's, only the data is real.
## Contracts are taken at the Black Market's bounty shelf; the refresh label
## shows the time until the shelf's next daily reroll (local midnight).
func _add_bounty_board_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "BountyBoardPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 48.0
	panel.offset_top = -282.0
	panel.offset_right = 466.0
	panel.offset_bottom = -68.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _home_panel_style())
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	box.add_child(header)
	header.add_child(_make_icon_rect(BASE_HUD_ICON_DIR + "icon_daily_tasks.png", Vector2(28, 28)))

	var title := Label.new()
	title.text = _home_text("悬赏", "BOUNTIES")
	title.add_theme_font_override("font", T.display_font(600))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("outline_size", 2)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var refresh := Label.new()
	refresh.text = _home_text("刷新: %s", "Refresh: %s") % _daily_refresh_time()
	refresh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	refresh.add_theme_font_override("font", T.display_font(500))
	refresh.add_theme_font_size_override("font_size", 16)
	refresh.add_theme_color_override("font_color", Color(0.72, 0.62, 0.48, 1.0))
	header.add_child(refresh)

	box.add_child(_daily_divider())

	var rows := VBoxContainer.new()
	rows.name = "BountyRows"
	rows.add_theme_constant_override("separation", 8)
	box.add_child(rows)
	_bounty_rows_box = rows
	_fill_bounty_rows()


## Repaint just the board's data rows (the panel chrome survives). Connected to
## MetaProgress.bounties_changed / bounty_completed.
func _rebuild_bounty_rows() -> void:
	if not is_instance_valid(_bounty_rows_box):
		return
	for child in _bounty_rows_box.get_children():
		child.queue_free()
	_fill_bounty_rows()


## One progress row per held contract, or a single empty-state hint pointing at
## the Black Market shelf. Reward chip shows the PRIMARY currency (caps first,
## then core/scrap) with a trailing "+" when the contract pays out more kinds.
func _fill_bounty_rows() -> void:
	var added := 0
	for entry in MetaProgress.active_bounties:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("id", ""))
		var data: Dictionary = MetaProgress.get_bounty_data(id)
		if data.is_empty():
			continue
		var objective_v = data.get("objective", {})
		var objective: Dictionary = objective_v if typeof(objective_v) == TYPE_DICTIONARY else {}
		var reward_v = data.get("reward", {})
		var reward: Dictionary = reward_v if typeof(reward_v) == TYPE_DICTIONARY else {}

		var title := Settings.t("BOUNTY_%s_TITLE" % id, str(data.get("title", id)))
		var current := int(entry.get("progress", 0))
		var target := int(objective.get("count", 1))

		var reward_amount := 0
		var reward_currency := "caps"
		var reward_parts := 0
		for cur in ["caps", "core", "scrap"]:
			var amt := int(reward.get(cur, 0))
			if amt <= 0:
				continue
			reward_parts += 1
			if reward_amount == 0:
				reward_amount = amt
				reward_currency = cur
		if str(reward.get("equipment", "")) != "":
			reward_parts += 1
		_bounty_rows_box.add_child(
			_make_daily_task_row(
				title, current, target, reward_amount, reward_currency, reward_parts > 1
			)
		)
		added += 1

	if added == 0:
		var empty := Label.new()
		empty.text = _home_text("暂无悬赏——到黑市承接", "No bounties — visit the Black Market")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_override("font", T.display_font(500))
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.72, 0.62, 0.48, 1.0))
		_bounty_rows_box.add_child(empty)


## Completion handler: repaint (the settled contract leaves the board — also
## covered by bounties_changed, but a manual emit must repaint too) + toast.
func _on_bounty_completed(bounty_id: String) -> void:
	_rebuild_bounty_rows()
	var data: Dictionary = MetaProgress.get_bounty_data(bounty_id)
	var title := Settings.t("BOUNTY_%s_TITLE" % bounty_id, str(data.get("title", bounty_id)))
	_show_home_toast(_home_text("悬赏完成:%s", "Bounty complete: %s") % title)


## Lightweight self-freeing toast over the base HUD (home base has no shared
## popup helper — mirrors loot_reward's toast pattern, restyled to the home
## glass look). Replaces any toast already showing.
func _show_home_toast(text: String) -> void:
	var host: Control = _base_hud_root if is_instance_valid(_base_hud_root) else self
	var existing := host.get_node_or_null("HomeToast")
	if existing != null:
		existing.queue_free()

	# Full-width holder band above the DEPART button; centers the label reliably.
	var holder := CenterContainer.new()
	holder.name = "HomeToast"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 0.0
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_top = -252.0
	holder.offset_bottom = -196.0
	host.add_child(holder)

	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font", T.display_font(600))
	toast.add_theme_font_size_override("font_size", 26)
	toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60, 1.0))
	toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	toast.add_theme_constant_override("outline_size", 5)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(toast)

	AudioManager.play_sfx("reward")
	# Bound to the holder (not self) so a replacement toast auto-kills the tween.
	var tween := holder.create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(holder, "modulate:a", 0.0, 0.5)
	tween.tween_callback(holder.queue_free)


## One board row: title + progress bar + reward chip. Codex's daily-task row
## visuals, extended with a reward currency icon choice + optional "+" suffix
## (multi-currency contracts show their primary reward plus a "+").
func _make_daily_task_row(
	title: String,
	current: int,
	target: int,
	reward: int,
	reward_currency: String = "core",
	reward_plus: bool = false
) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 43)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 3)
	row.add_child(text_box)

	var top := HBoxContainer.new()
	text_box.add_child(top)

	var name := Label.new()
	name.text = title
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_override("font", T.display_font(500))
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", Color(0.90, 0.82, 0.66, 1.0))
	top.add_child(name)

	var progress_text := Label.new()
	progress_text.text = "%d/%d" % [current, target]
	progress_text.add_theme_font_override("font", T.display_font(500))
	progress_text.add_theme_font_size_override("font_size", 16)
	progress_text.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52, 1.0))
	top.add_child(progress_text)

	var progress := ProgressBar.new()
	progress.max_value = float(maxi(target, 1))
	progress.value = float(current)
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 6)
	progress.add_theme_stylebox_override(
		"background",
		_home_flat_style(Color(0.08, 0.065, 0.045, 0.96), Color(0.12, 0.10, 0.075, 1.0), 2, 1)
	)
	progress.add_theme_stylebox_override(
		"fill", _home_flat_style(Color(0.54, 0.42, 0.25, 1.0), Color(0.54, 0.42, 0.25, 1.0), 2, 0)
	)
	text_box.add_child(progress)

	var reward_box := PanelContainer.new()
	reward_box.custom_minimum_size = Vector2(82, 34)
	reward_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_box.add_theme_stylebox_override(
		"panel",
		_home_flat_style(Color(0.10, 0.075, 0.045, 0.96), Color(0.36, 0.27, 0.16, 1.0), 5, 1)
	)
	row.add_child(reward_box)

	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 8)
	reward_margin.add_theme_constant_override("margin_right", 8)
	reward_margin.add_theme_constant_override("margin_top", 4)
	reward_margin.add_theme_constant_override("margin_bottom", 4)
	reward_box.add_child(reward_margin)

	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 4)
	reward_margin.add_child(reward_row)

	var reward_label := Label.new()
	reward_label.text = str(reward)
	reward_label.add_theme_font_override("font", T.display_font(600))
	reward_label.add_theme_font_size_override("font_size", 17)
	reward_label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.60, 1.0))
	reward_row.add_child(reward_label)
	reward_row.add_child(
		_make_icon_rect(CURRENCY_ICON_DIR + reward_currency + ".png", Vector2(22, 22))
	)
	if reward_plus:
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_override("font", T.display_font(600))
		plus.add_theme_font_size_override("font_size", 15)
		plus.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52, 1.0))
		reward_row.add_child(plus)
	return row


func _add_start_run_button(root: Control) -> void:
	var button := Button.new()
	button.name = "StartRunButton"
	button.text = _home_text("出发", "DEPART")
	button.anchor_left = 0.5
	button.anchor_top = 1.0
	button.anchor_right = 0.5
	button.anchor_bottom = 1.0
	button.offset_left = -335.0
	button.offset_top = -172.0
	button.offset_right = 335.0
	button.offset_bottom = -65.0
	button.add_theme_font_override("font", T.display_font(700))
	button.add_theme_font_size_override("font_size", 46)
	button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.64, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.74, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.95, 0.78, 0.56, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.10, 0.035, 0.02, 1.0))
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_stylebox_override("normal", _home_start_button_style("normal"))
	button.add_theme_stylebox_override("hover", _home_start_button_style("hover"))
	button.add_theme_stylebox_override("pressed", _home_start_button_style("pressed"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_on_start_pressed)
	root.add_child(button)


func _add_bottom_nav(root: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "BottomRightNav"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	row.anchor_left = 1.0
	row.anchor_top = 1.0
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -480.0
	row.offset_top = -206.0
	row.offset_right = -70.0
	row.offset_bottom = -52.0
	root.add_child(row)

	row.add_child(
		_make_home_nav_button(
			"icon_warehouse",
			_home_text("仓库", "WAREHOUSE"),
			tr("UI_STASH_WINDOW_TITLE"),
			_open_stash_window
		)
	)
	row.add_child(
		_make_home_nav_button(
			"icon_character",
			_home_text("角色", "CHARACTER"),
			tr("UI_EQUIP_TITLE_CHARACTER"),
			_open_character_window
		)
	)
	row.add_child(
		_make_home_nav_button(
			"icon_gallery",
			_home_text("图鉴", "GALLERY"),
			_home_text("卡牌图鉴", "CARD GALLERY"),
			_open_card_gallery
		)
	)


func _make_home_nav_button(
	icon_id: String, label_text: String, tooltip: String, callback: Callable
) -> Button:
	var btn := Button.new()
	btn.name = icon_id.capitalize() + "NavButton"
	btn.custom_minimum_size = Vector2(126, 148)
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _home_button_style("normal"))
	btn.add_theme_stylebox_override("hover", _home_button_style("hover"))
	btn.add_theme_stylebox_override("pressed", _home_button_style("pressed"))
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.pressed.connect(callback)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	box.add_child(_make_icon_rect(BASE_HUD_ICON_DIR + icon_id + ".png", Vector2(76, 76)))

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", T.display_font(600))
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.60, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return btn


func _make_icon_rect(path: String, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_home_texture(path)
	return icon


func _home_text(zh: String, en: String) -> String:
	return zh if Settings.language == "zh" else en


func _daily_refresh_time() -> String:
	var now := Time.get_datetime_dict_from_system()
	var seconds: int = (
		int(now.get("hour", 0)) * 3600 + int(now.get("minute", 0)) * 60 + int(now.get("second", 0))
	)
	var left: int = maxi(0, 86400 - seconds)
	var h := left / 3600
	var m := (left % 3600) / 60
	var s := left % 60
	return "%02d:%02d:%02d" % [h, m, s]


func _daily_divider() -> Control:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.add_theme_stylebox_override(
		"panel", _home_flat_style(Color(0.24, 0.18, 0.10, 0.75), Color(0, 0, 0, 0), 0, 0)
	)
	return line


func _home_top_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.052, 0.04, 0.94)
	style.border_color = Color(0.36, 0.27, 0.15, 1.0)
	style.border_width_bottom = 2
	return style


func _home_panel_style() -> StyleBoxFlat:
	var style := _home_flat_style(
		Color(0.075, 0.060, 0.042, 0.94), Color(0.38, 0.29, 0.16, 1.0), 7, 2
	)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _home_chip_style() -> StyleBoxFlat:
	return _home_flat_style(Color(0.055, 0.045, 0.032, 0.96), Color(0.39, 0.30, 0.18, 1.0), 7, 2)


func _home_button_style(state: String) -> StyleBoxFlat:
	match state:
		"hover":
			return _home_flat_style(
				Color(0.12, 0.090, 0.052, 0.98), Color(0.76, 0.56, 0.24, 1.0), 7, 2
			)
		"pressed":
			return _home_flat_style(
				Color(0.045, 0.036, 0.024, 0.98), Color(0.25, 0.19, 0.11, 1.0), 7, 2
			)
		_:
			return _home_flat_style(
				Color(0.075, 0.060, 0.038, 0.98), Color(0.36, 0.28, 0.16, 1.0), 7, 2
			)


func _home_start_button_style(state: String) -> StyleBox:
	var bg := Color(0.44, 0.12, 0.075, 0.98)
	var border := Color(0.72, 0.45, 0.23, 1.0)
	if state == "hover":
		bg = Color(0.55, 0.16, 0.095, 0.99)
		border = Color(0.96, 0.64, 0.28, 1.0)
	elif state == "pressed":
		bg = Color(0.31, 0.075, 0.050, 0.99)
		border = Color(0.46, 0.27, 0.15, 1.0)
	var style := _home_flat_style(bg, border, 8, 3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 18.0
	return T.concept_box("depart_plaque_%s" % state, style, 58, 36, 28)


func _home_flat_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _add_building_sprites() -> void:
	# Re-entrant: also fires on buildings_changed. Free the prior visuals (immediately,
	# so there's no one-frame double-draw) and rebuild under a single root container.
	if is_instance_valid(_buildings_root):
		remove_child(_buildings_root)
		_buildings_root.queue_free()
	_buildings_root = Control.new()
	_buildings_root.name = "BuildingsRoot"
	_buildings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buildings_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buildings_root)
	# Keep the buildings just above the background (below the HUD / depart / help button)
	# even when re-added last on a rebuild.
	move_child(_buildings_root, 1)
	# Organic placement matching the four packed-dirt pads baked into the
	# Codex home_base_empty_bg (2026-07-04): two FAR pads up top (smaller
	# tiles, added first so the near row draws over them if they ever touch)
	# and two NEAR pads below (bigger tiles). Tile bottoms sit on their pad;
	# per-art baseline alignment inside the tile is _building_art_offset()'s
	# job. Tune HERE if the bg pads move.
	_add_interactive_building(
		"clinic",
		Rect2(485, 290, 310, 310),
		tr("UI_BUILD_CLINIC_NAME"),
		func() -> void: _open_building_screen("clinic")
	)
	_add_interactive_building(
		"market",
		Rect2(1100, 300, 310, 310),
		tr("UI_BUILD_MARKET_NAME"),
		func() -> void: _open_building_screen("market")
	)
	_add_interactive_building(
		"forge",
		Rect2(210, 430, 370, 370),
		tr("UI_BUILD_FORGE_NAME"),
		func() -> void: _open_forge_windows()
	)
	_add_interactive_building(
		"outpost",
		Rect2(1260, 440, 370, 370),
		tr("UI_BUILD_OUTPOST_NAME"),
		func() -> void: _open_building_screen("outpost")
	)

	# Plaques stay centered above their tile: plaque_x = tile_x + (tile_w-215)/2,
	# plaque_y = tile_y - 82 (far pads sit higher, near pads lower).
	_add_building_plaque("clinic", Rect2(532, 208, 215, 78), tr("UI_BUILD_CLINIC_NAME"))
	_add_building_plaque("market", Rect2(1147, 218, 215, 78), tr("UI_BUILD_MARKET_NAME"))
	_add_building_plaque("forge", Rect2(287, 348, 215, 78), tr("UI_BUILD_FORGE_NAME"))
	_add_building_plaque("outpost", Rect2(1337, 358, 215, 78), tr("UI_BUILD_OUTPOST_NAME"))


## Giant START button + the compact difficulty button directly above it,
## stacked into the bottom bar's centre box (difficulty first = on top). The
## old always-visible difficulty bar row is gone — difficulty now lives in a
## modal picker popup (_show_difficulty_popup).
func _add_depart_controls(parent: Control) -> void:
	_add_difficulty_button(parent)

	var button := Button.new()
	button.name = "StartRunButton"
	button.text = TranslationServer.translate("UI_HOME_START_RUN")
	# 500×96 (was ×88): the accent plate art is 128px tall, and together with the
	# shallower 20px vertical 9-slice margins the taller button keeps the baked
	# plate from reading vertically squashed. Composition is unchanged — bottom
	# stays 10px above the screen edge, difficulty pill 6px above the button.
	button.custom_minimum_size = Vector2(500, 96)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 38)
	T.apply_button_theme(button)  # hover tick + scale-pop juice
	# Accent restyle over the generic theme: red-clay plate + gold rim (kit
	# btn_accent_* when delivered), warm cream label in every state.
	button.add_theme_stylebox_override("normal", T.ui_button_accent("normal"))
	button.add_theme_stylebox_override("hover", T.ui_button_accent("hover"))
	button.add_theme_stylebox_override("pressed", T.ui_button_accent("pressed"))
	button.add_theme_color_override("font_color", T.UI_ACCENT_TEXT)
	button.add_theme_color_override("font_hover_color", T.UI_ACCENT_TEXT)
	button.add_theme_color_override("font_pressed_color", T.UI_ACCENT_TEXT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_on_start_pressed)
	parent.add_child(button)


## Compact difficulty button above START — its label shows the current pick
## ("Difficulty A{n}"); clicking opens the modal A0..A5 picker popup.
func _add_difficulty_button(parent: Control) -> void:
	var btn := Button.new()
	btn.name = "DifficultyButton"
	btn.custom_minimum_size = Vector2(200, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.apply_button_theme(btn)
	_style_brass_button(btn)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.pressed.connect(_show_difficulty_popup)
	parent.add_child(btn)
	_difficulty_button = btn
	_refresh_difficulty_button()


## Glass bar-button restyle over apply_button_theme (keeps its hover juice /
## font colors, swaps the Kenney texture for the theme's menu-glass styles —
## incl. the disabled state, which otherwise falls back to the engine grey).
func _style_brass_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", T.ui_button_brass("normal"))
	btn.add_theme_stylebox_override("hover", T.ui_button_brass("hover"))
	btn.add_theme_stylebox_override("pressed", T.ui_button_brass("pressed"))
	btn.add_theme_stylebox_override("disabled", T.ui_button_brass("disabled"))


## The same clamp the old difficulty bar applied on build: pending ascension
## (or 0 when unset) clamped to the highest unlocked level, written back so
## START uses exactly what the button displays.
func _current_difficulty() -> int:
	var max_unlocked: int = clampi(int(MetaProgress.max_ascension), 0, 5)
	var pending: int = RunManager.pending_ascension if RunManager.pending_ascension >= 0 else 0
	var current: int = clampi(pending, 0, max_unlocked)
	RunManager.pending_ascension = current
	return current


func _refresh_difficulty_button() -> void:
	if is_instance_valid(_difficulty_button):
		var label_text := tr("UI_HOME_DIFFICULTY_BTN").format({"a": _current_difficulty()})
		_difficulty_button.tooltip_text = label_text
		if _difficulty_button.has_meta("label"):
			var lbl = _difficulty_button.get_meta("label")
			if lbl is Label and is_instance_valid(lbl):
				lbl.text = label_text
				return
		_difficulty_button.text = label_text


## Modal difficulty picker — same overlay structure as the TierConfirm popup
## (dim + centered panel on its own CanvasLayer). Unlock gating ported verbatim
## from the removed difficulty bar: entries above MetaProgress.max_ascension
## (clamped to 5) are disabled; the current pick renders selected. Picking one
## sets RunManager.pending_ascension, closes the popup and refreshes the
## button label; clicking the dim backs out without changing anything.
func _show_difficulty_popup() -> void:
	if get_node_or_null("DifficultyPopup") != null:
		return  # already open
	var layer := CanvasLayer.new()
	layer.name = "DifficultyPopup"
	layer.layer = 150
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				AudioManager.play_sfx("ui_back")
				layer.queue_free()
	)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE so clicks beside the panel reach the dim (close); the panel and its
	# buttons still receive input themselves.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 28)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	m.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = tr("UI_HOME_DIFFICULTY_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	_difficulty_buttons.clear()
	var max_unlocked: int = clampi(int(MetaProgress.max_ascension), 0, 5)
	var current: int = _current_difficulty()
	for value in range(6):
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = "A%d" % value
		btn.custom_minimum_size = Vector2(58, 42)
		btn.add_theme_font_size_override("font_size", 17)
		btn.focus_mode = Control.FOCUS_NONE
		btn.disabled = value > max_unlocked
		btn.button_pressed = value == current
		_style_difficulty_button(btn, btn.button_pressed, btn.disabled)
		var asc := value
		btn.pressed.connect(
			func() -> void:
				AudioManager.play_sfx("ui_click")
				_on_home_difficulty_chosen(asc)
				_refresh_difficulty_button()
				layer.queue_free()
		)
		row.add_child(btn)
		_difficulty_buttons.append(btn)


func _on_home_difficulty_chosen(value: int) -> void:
	var max_unlocked: int = clampi(int(MetaProgress.max_ascension), 0, 5)
	RunManager.pending_ascension = clampi(value, 0, max_unlocked)
	for i in range(_difficulty_buttons.size()):
		var btn := _difficulty_buttons[i]
		if is_instance_valid(btn):
			btn.button_pressed = i == RunManager.pending_ascension
			_style_difficulty_button(btn, btn.button_pressed, btn.disabled)


func _style_difficulty_button(button: Button, selected: bool, disabled: bool) -> void:
	var bg := Color(0.13, 0.10, 0.075, 0.96)
	var border := Color(0.55, 0.36, 0.18, 1.0)
	var text := Color(0.86, 0.76, 0.58, 1.0)
	if selected:
		bg = Color(0.30, 0.17, 0.065, 0.98)
		border = Color(1.0, 0.72, 0.28, 1.0)
		text = Color(1.0, 0.90, 0.55, 1.0)
	elif disabled:
		bg = Color(0.07, 0.06, 0.052, 0.78)
		border = Color(0.25, 0.20, 0.16, 0.75)
		text = Color(0.42, 0.36, 0.28, 0.85)
	button.add_theme_stylebox_override("normal", T.rounded_button(bg, border, 5, 2))
	button.add_theme_stylebox_override(
		"hover", T.rounded_button(bg.lightened(0.10), Color(0.35, 0.88, 1.0, 1.0), 5, 2)
	)
	button.add_theme_stylebox_override("pressed", T.rounded_button(bg.darkened(0.10), border, 5, 2))
	button.add_theme_stylebox_override("disabled", T.rounded_button(bg, border, 5, 2))
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_disabled_color", text)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	button.add_theme_constant_override("outline_size", 1)


func _add_interactive_building(
	asset_id: String, rect: Rect2, tooltip: String, callback: Callable
) -> void:
	var normal_tex := _load_home_texture("%s%s.png" % [BUILDING_IMAGE_DIR, asset_id])
	var hover_tex := _load_home_texture("%s%s_hover.png" % [BUILDING_IMAGE_DIR, asset_id])
	var pressed_tex := _load_home_texture("%s%s_pressed.png" % [BUILDING_IMAGE_DIR, asset_id])
	var button := TextureButton.new()
	button.name = "Building_%s" % asset_id
	button.texture_normal = normal_tex
	button.texture_hover = hover_tex if hover_tex is Texture2D else normal_tex
	button.texture_pressed = pressed_tex if pressed_tex is Texture2D else button.texture_hover
	button.texture_click_mask = _make_click_mask(normal_tex)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Each building PNG carries different transparent padding, so identical tile
	# rects would render the art at uneven baselines / off-centre. Shift the whole
	# button (art + click mask move together) so the opaque art's horizontal
	# centre sits on the tile centre and its bottom sits on the shared ground
	# line (tile bottom − GROUND_INSET). Hover/pressed variants share the normal
	# texture's canvas dimensions, so one offset aligns all three states.
	var art_offset := _building_art_offset(asset_id, normal_tex, rect.size)
	_set_map_rect(button, Rect2(rect.position + art_offset, rect.size))
	# The building sprites already swap to a hover texture, but were silent — add the
	# hover tick + click so the boot screen feels responsive (sound connected before
	# the callback so it still fires when the callback opens a building overlay).
	button.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover"))
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(callback)
	_buildings_root.add_child(button)
	# Locked buildings (not yet unlocked with Core) render grey-dark via the
	# desaturation shader (material on the button node only — the lock overlay
	# below is a sibling, so it keeps its brass color) with a lock badge so it
	# reads at a glance which ones aren't available. Still clickable — clicking
	# routes to the unlock confirm. Unlocked buttons keep material = null (every
	# rebuild creates fresh buttons, so no stale material survives an unlock).
	if MetaProgress.get_building_tier(asset_id) <= 0:
		button.material = _get_locked_material()
		# Lock glyph resolve chain: active skin dir → the V3 glyph dir (Codex,
		# pending) → the rev2 brass padlock kept on disk (ui_kit/). Pinned
		# explicitly so switching UI_KIT_DIR to the glass/none skin can never
		# regress to the emoji fallback below.
		var lock_tex := T.ui_kit_tex("icon_lock")
		if (
			lock_tex == null
			and ResourceLoader.exists("res://run_system/assets/images/ui_glyphs/glyph_lock.png")
		):
			lock_tex = load("res://run_system/assets/images/ui_glyphs/glyph_lock.png")
		if (
			lock_tex == null
			and ResourceLoader.exists("res://run_system/assets/images/ui_kit/icon_lock.png")
		):
			lock_tex = load("res://run_system/assets/images/ui_kit/icon_lock.png")
		if lock_tex != null:
			# Kit brass padlock (156×208 source — not square, so IGNORE_SIZE +
			# KEEP_ASPECT_CENTERED inside a ~64×84 rect centered on the tile).
			var lock := TextureRect.new()
			lock.name = "Lock_%s" % asset_id
			lock.texture = lock_tex
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_size := Vector2(64, 84)
			_set_map_rect(lock, Rect2(rect.position + (rect.size - lock_size) * 0.5, lock_size))
			_buildings_root.add_child(lock)
		else:
			# Fallback while the kit PNG is regenerating: the old glyph label.
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒"
			lock_lbl.add_theme_font_size_override("font_size", 76)
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_map_rect(lock_lbl, rect)
			_buildings_root.add_child(lock_lbl)


## Alignment offset for a building's art inside its tile (cached per building —
## see _add_interactive_building). STRETCH_KEEP_ASPECT_CENTERED math: the full
## texture fits the tile at a uniform scale, centered; the opaque used-rect is
## then located inside that drawn frame and the delta to "used-rect centre-x on
## tile centre-x, used-rect bottom on tile bottom − GROUND_INSET" is returned.
func _building_art_offset(asset_id: String, tex: Texture2D, tile_size: Vector2) -> Vector2:
	if _art_offset_cache.has(asset_id):
		return _art_offset_cache[asset_id]
	var offset := Vector2.ZERO
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var tex_size := Vector2(img.get_width(), img.get_height())
				var s: float = minf(tile_size.x / tex_size.x, tile_size.y / tex_size.y)
				var drawn_origin := (tile_size - tex_size * s) * 0.5
				var art_center_x := (
					drawn_origin.x + (float(used.position.x) + used.size.x * 0.5) * s
				)
				var art_bottom_y := drawn_origin.y + float(used.position.y + used.size.y) * s
				offset = Vector2(
					tile_size.x * 0.5 - art_center_x, (tile_size.y - GROUND_INSET) - art_bottom_y
				)
	_art_offset_cache[asset_id] = offset
	return offset


## Shared grayscale-darken material for locked building buttons (lazy — built
## once, reused across rebuilds; the shader's uniform defaults are the tuning).
func _get_locked_material() -> ShaderMaterial:
	if _locked_material == null:
		_locked_material = ShaderMaterial.new()
		_locked_material.shader = LOCKED_DESAT_SHADER
	return _locked_material


func _make_click_mask(texture: Texture2D) -> BitMap:
	if not texture:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, 0.1)
	return mask


## Floating building plaque: circular icon badge + compact name/level plate.
func _add_building_plaque(building_id: String, rect: Rect2, title: String) -> void:
	var holder := Control.new()
	holder.name = "Plaque_%s" % building_id
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_map_rect(holder, Rect2(rect.position + Vector2(0, -54), rect.size + Vector2(0, 54)))
	_buildings_root.add_child(holder)

	var icon_id: String = str(BUILDING_BADGE_ICONS.get(building_id, ""))
	if icon_id != "":
		var icon := _make_icon_rect(BASE_HUD_ICON_DIR + icon_id + ".png", Vector2(78, 78))
		icon.anchor_left = 0.5
		icon.anchor_top = 0.0
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.0
		icon.offset_left = -39.0
		icon.offset_top = 0.0
		icon.offset_right = 39.0
		icon.offset_bottom = 78.0
		holder.add_child(icon)

	var plaque := PanelContainer.new()
	plaque.anchor_left = 0.5
	plaque.anchor_top = 0.0
	plaque.anchor_right = 0.5
	plaque.anchor_bottom = 0.0
	plaque.offset_left = -84.0
	plaque.offset_top = 62.0
	plaque.offset_right = 84.0
	plaque.offset_bottom = 122.0
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_stylebox_override(
		"panel",
		_home_flat_style(Color(0.065, 0.052, 0.035, 0.98), Color(0.56, 0.42, 0.22, 1.0), 5, 2)
	)
	holder.add_child(plaque)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", T.display_font(600))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.58, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tier := MetaProgress.get_building_tier(building_id)
	if tier <= 0:
		label.text = "%s\n%s" % [title, tr("UI_BUILD_LOCKED")]
	else:
		label.text = "%s\nLv.%d" % [title, tier]
	plaque.add_child(label)


## Unlock / upgrade button under a building's floating label — confirms before spending Core.
## Hidden at max tier. Rebuilt with the plaques on buildings_changed so it stays live.
func _add_tier_button(building_id: String, plaque_rect: Rect2) -> void:
	var tier := MetaProgress.get_building_tier(building_id)
	var cost := MetaProgress.next_building_cost(building_id)
	if cost < 0:
		return  # maxed (or no unlock cost) → no button
	var zh := Settings.language == "zh"
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 17)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.apply_button_theme(btn)
	_style_brass_button(btn)  # glass chip (the Kenney texture read muddy over the sky)
	btn.text = ("解锁" if zh else "Unlock") if tier <= 0 else ("升级" if zh else "Upgrade")
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = cost < 0 or MetaProgress.core < cost
	# Contrast pass: the theme's default grey-brown label was near-invisible on
	# the plaque — warm gold (UI_HEADER_GOLD #f2c56a) in every state, incl. the
	# disabled (can't-afford) one, with a dark outline so it reads on desert.
	btn.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	btn.add_theme_color_override("font_hover_color", T.UI_HEADER_GOLD.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", T.UI_HEADER_GOLD)
	btn.add_theme_color_override("font_disabled_color", Color(T.UI_HEADER_GOLD, 0.85))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	btn.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_click")
			_show_tier_confirm(building_id)
	)
	# Cost shown as amount+icon, overlaid on the button's right side (verb text
	# stays as btn.text on the left) instead of the old "N 核心" word suffix.
	var badge := T.overlay_cost_badge(cost, "core", 15, 18, -10, -110)
	# Match the verb's gold on the cost number (the badge keeps its core icon).
	if badge.get_child_count() > 0 and badge.get_child(0).has_meta("amount_label"):
		var amount_lbl := badge.get_child(0).get_meta("amount_label") as Label
		if amount_lbl != null:
			amount_lbl.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	btn.add_child(badge)
	var bw := 196.0
	var br := Rect2(
		plaque_rect.position.x + plaque_rect.size.x * 0.5 - bw * 0.5,
		plaque_rect.position.y + plaque_rect.size.y - 4,
		bw,
		40
	)
	_set_map_rect(btn, br)
	_buildings_root.add_child(btn)


## Confirmation popup for an unlock/upgrade. Confirm spends Core via MetaProgress
## (→ buildings_changed → the overview rebuilds with the new tier).
func _show_tier_confirm(building_id: String) -> void:
	if get_node_or_null("TierConfirm") != null:
		return  # a confirm popup is already open
	var tier := MetaProgress.get_building_tier(building_id)
	var cost := MetaProgress.next_building_cost(building_id)
	if cost < 0:
		return  # already at max tier — nothing to offer
	# NOTE: do NOT early-return when Core < cost — that silently ate the click
	# (fresh saves have 0 Core, so locked buildings felt dead). Show the popup
	# with a disabled Confirm + an "not enough Core" hint instead.
	var affordable := MetaProgress.core >= cost
	var zh := Settings.language == "zh"
	var is_unlock := tier <= 0
	var bname := tr("UI_BUILD_%s_NAME" % building_id.to_upper())

	var layer := CanvasLayer.new()
	layer.name = "TierConfirm"
	layer.layer = 155
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 28)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	m.add_child(box)

	var msg := Label.new()
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlock:
		msg.text = ("解锁「%s」?" if zh else 'Unlock "%s"?') % bname
	else:
		var t2 := tier + 1
		msg.text = ("把「%s」升级到 T%d?" if zh else 'Upgrade "%s" to T%d?') % [bname, t2]
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	box.add_child(msg)

	# Cost as amount+icon (no "N 核心" word), centered under the question.
	var cost_row := T.currency_row(cost, "core", 20, 22, "花费:" if zh else "Cost:")
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cost_row)

	if not affordable:
		var short := Label.new()
		short.text = (
			("核心不足(还差 %d)" if zh else "Not enough Core (%d more needed)")
			% (cost - MetaProgress.core)
		)
		short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		short.add_theme_font_size_override("font_size", 15)
		short.add_theme_color_override("font_color", Color(0.9, 0.45, 0.35))
		box.add_child(short)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var yes := Button.new()
	yes.text = "确认" if zh else "Confirm"
	yes.custom_minimum_size = Vector2(150, 46)
	yes.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(yes)
	if not affordable:
		yes.disabled = true
		yes.tooltip_text = "核心不足" if zh else "Not enough Core"
	yes.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("upgrade")
			if is_unlock:
				MetaProgress.unlock_building(building_id)
			else:
				MetaProgress.upgrade_building(building_id)
			layer.queue_free()
	)
	row.add_child(yes)
	var no := Button.new()
	no.text = "取消" if zh else "Cancel"
	no.custom_minimum_size = Vector2(150, 46)
	no.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(no)
	no.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_back")
			layer.queue_free()
	)
	row.add_child(no)


func _set_map_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x / MAP_CANVAS_SIZE.x
	control.anchor_top = rect.position.y / MAP_CANVAS_SIZE.y
	control.anchor_right = (rect.position.x + rect.size.x) / MAP_CANVAS_SIZE.x
	control.anchor_bottom = (rect.position.y + rect.size.y) / MAP_CANVAS_SIZE.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _load_home_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	if path.begins_with("res://"):
		var image := Image.new()
		var err := image.load(ProjectSettings.globalize_path(path))
		if err == OK:
			return ImageTexture.create_from_image(image)
	return null


func _style_readable_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	label.add_theme_constant_override("outline_size", outline_size)


## Settings overlay (Language / Fullscreen / Volume). Language change reloads
## the home base so all labels pick up the new locale.
## Open the unified pause panel (the ⚙ gear). No run is active at the base, so the
## Abandon option auto-hides (PAUSE_PANEL.open is passed is_run_active = false here).
func _open_pause() -> void:
	PAUSE_PANEL.open(self, RunManager.is_run_active)


## Rebuild the three-column building area: left flank (Forge/Clinic), centre
## column (the START door), right flank (Market/Outpost). Called on
## build and on every buildings_changed so lock→unlock / tier-up repaint live.
func _rebuild_building_tiles() -> void:
	if not is_instance_valid(_building_area):
		return
	for c in _building_area.get_children():
		c.queue_free()
	_building_area.add_child(_make_building_column(LEFT_BUILDINGS))
	_building_area.add_child(_make_center_column())
	_building_area.add_child(_make_building_column(RIGHT_BUILDINGS))


## A flank column: stacked building tiles.
func _make_building_column(building_ids: Array) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for building_id in building_ids:
		col.add_child(_make_building_tile(str(building_id)))
	return col


## The centre column: just the START "door".
func _make_center_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_make_start_door())
	return col


## The START "door": a tall, golden, clickable tile that launches the run. Visually
## distinct from the building tiles (warm gradient + DEPART label) so it reads as
## the way out, not another building.
func _make_start_door() -> Control:
	var accent := Color(1.0, 0.82, 0.36)
	var door := PanelContainer.new()
	door.custom_minimum_size = Vector2(300, 196)
	door.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.16, 0.12, 0.05, 0.97), accent, 6, 4)
	)
	door.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	door.add_child(box)

	var glyph := Label.new()
	glyph.text = "🚪"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 64)
	box.add_child(glyph)

	var label := Label.new()
	label.text = TranslationServer.translate("UI_HOME_START_RUN")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_readable_label(label, 28, Color(1.0, 0.92, 0.55), 3)
	box.add_child(label)

	door.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_start_pressed()
	)
	return door


func _make_building_tile(building_id: String) -> Control:
	var accent: Color = BUILDING_ACCENTS.get(building_id, Color(0.86, 0.78, 0.52))
	var tier := MetaProgress.get_building_tier(building_id)

	# Big, intentional tile: accent border, generated building art, and lock/tier badge.
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(300, 220)
	var border := accent
	border.a = 1.0
	tile.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.075, 0.060, 0.048, 0.96), border, 6, 3)
	)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)

	# Accent header strip across the top with the building name (prominent, distinct).
	var header_strip := PanelContainer.new()
	header_strip.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(accent.r, accent.g, accent.b, 0.92), border, 4, 0)
	)
	box.add_child(header_strip)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_right", 12)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header_strip.add_child(header_margin)
	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Dark text on the bright accent strip reads cleanly.
	_style_readable_label(name_lbl, 24, Color(0.10, 0.08, 0.06), 0)
	header_margin.add_child(name_lbl)

	var body_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body_margin.add_theme_constant_override(side, 14)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body_margin.add_child(body)

	var art := TextureRect.new()
	art.texture = _load_building_texture(building_id)
	art.custom_minimum_size = Vector2(0, 112)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if tier <= 0:
		badge.text = "🔒 " + tr("UI_BUILD_LOCKED")
		_style_readable_label(badge, 20, Color(0.86, 0.62, 0.56), 1)
	else:
		badge.text = "T%d" % tier
		_style_readable_label(badge, 20, Color(0.7, 0.92, 0.7), 1)
	body.add_child(badge)

	tile.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_building_screen(building_id)
	)
	return tile


func _load_building_texture(building_id: String) -> Texture2D:
	var path := "%s%s.png" % [BUILDING_IMAGE_DIR, building_id]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


## Open a building's screen as a full-rect overlay child. Phase 1 swaps in
## per-building subclasses of BUILDING_SCREEN_BASE; for now every tile opens the
## shared base screen (real unlock/upgrade buttons, placeholder content).
func _open_building_screen(building_id: String) -> void:
	if get_node_or_null("BuildingOverlay") != null:
		return
	if MetaProgress.get_building_tier(building_id) <= 0:
		# Locked: the unlock action moved to the overview — show its confirm popup
		# instead of opening an empty services page.
		_show_tier_confirm(building_id)
		return
	# Convention: load run_system/ui/buildings/<id>_screen.gd (a BUILDING_SCREEN_BASE
	# subclass) if it exists, else fall back to the shared base (placeholder content).
	# This lets each building screen be added as its own isolated file.
	var script_path := "res://run_system/ui/buildings/%s_screen.gd" % building_id
	var screen = (
		load(script_path).new()
		if ResourceLoader.exists(script_path)
		else BUILDING_SCREEN_BASE.new()
	)
	screen.name = "BuildingOverlay"
	screen.building_id = building_id
	screen.accent = BUILDING_ACCENTS.get(building_id, Color(0.86, 0.78, 0.52))
	screen.on_close = func() -> void:
		if is_instance_valid(screen):
			screen.queue_free()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)


## Toggle the floating character window in base mode — hero picker, next-run
## equipment loadout (→ RunManager.pending_equipped) and stash carry-marks
## (→ RunManager.pending_loadout). Replaces the old StashOverlay popup, whose
## select-to-carry logic now lives inside the window.
func _open_card_gallery() -> void:
	if get_node_or_null("CardGalleryLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "CardGalleryLayer"
	layer.layer = 145
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				AudioManager.play_sfx("ui_back")
				layer.queue_free()
	)
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1210, 820)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _home_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var card_ids := _gallery_card_ids()
	var seen_count := 0
	for cid in card_ids:
		if MetaProgress.cards_seen.has(str(cid)):
			seen_count += 1

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	header.add_child(_make_icon_rect(BASE_HUD_ICON_DIR + "icon_gallery.png", Vector2(42, 42)))

	var title := Label.new()
	title.text = _home_text("卡牌图鉴", "CARD GALLERY")
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	title.add_theme_constant_override("outline_size", 3)
	header.add_child(title)

	var counter := Label.new()
	counter.text = (_home_text("已收录 %d / %d", "Collected %d / %d") % [seen_count, card_ids.size()])
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter.add_theme_font_override("font", T.display_font(600))
	counter.add_theme_font_size_override("font_size", 21)
	counter.add_theme_color_override("font_color", Color(0.80, 0.70, 0.52, 1.0))
	counter.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	counter.add_theme_constant_override("outline_size", 2)
	header.add_child(counter)

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(54, 48)
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_override("font", T.display_font(700))
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_stylebox_override("normal", _home_button_style("normal"))
	close.add_theme_stylebox_override("hover", _home_button_style("hover"))
	close.add_theme_stylebox_override("pressed", _home_button_style("pressed"))
	close.add_theme_color_override("font_color", Color(0.94, 0.82, 0.60, 1.0))
	close.pressed.connect(func() -> void: AudioManager.play_sfx("ui_back"))
	close.pressed.connect(layer.queue_free)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 700)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

	if card_ids.is_empty():
		var empty := Label.new()
		empty.text = _home_text("暂无卡牌数据", "No card data found.")
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52, 1.0))
		grid.add_child(empty)
		return
	for card_id in card_ids:
		grid.add_child(_make_gallery_card_slot(str(card_id)))


## Every player card on disk — basics (strike/defend), curses, and ALL heroes'
## exclusives included; the codex shows the full set whether seen or not.
## Sort: type attack → skill → ability → curse, then rarity common → uncommon
## → rare → curse/special, then alphabetical by id.
func _gallery_card_ids() -> Array:
	var type_order := {"attack": 0, "skill": 1, "ability": 2, "curse": 3}
	var rarity_order := {"common": 0, "uncommon": 1, "rare": 2, "curse": 3, "special": 4}
	var cache: Dictionary = MetaProgress.get_card_info_cache()
	var entries: Array = []
	var dir := DirAccess.open(CARD_DATA_DIR)
	if dir == null:
		push_warning("CardGallery: cannot open card dir %s" % CARD_DATA_DIR)
		return []
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var card_id := file_name.get_basename()
		var data: Dictionary = cache.get(card_id, {})
		(
			entries
			. append(
				{
					"id": card_id,
					"type_rank": int(type_order.get(str(data.get("type", "")), 99)),
					"rarity_rank": int(rarity_order.get(str(data.get("rarity", "")), 99)),
				}
			)
		)
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["type_rank"] != b["type_rank"]:
				return a["type_rank"] < b["type_rank"]
			if a["rarity_rank"] != b["rarity_rank"]:
				return a["rarity_rank"] < b["rarity_rank"]
			return str(a["id"]) < str(b["id"])
	)
	var ids: Array = []
	for entry in entries:
		ids.append(str(entry["id"]))
	return ids


func _make_gallery_card_slot(card_id: String) -> Control:
	if not MetaProgress.cards_seen.has(card_id):
		return _make_gallery_locked_slot()
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(214, 300)
	slot.add_theme_stylebox_override(
		"panel",
		_home_flat_style(Color(0.045, 0.036, 0.026, 0.88), Color(0.26, 0.20, 0.12, 1.0), 6, 1)
	)

	var data: Dictionary = MetaProgress.get_card_info_cache().get(card_id, {})
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	slot.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var title := Label.new()
	title.text = Settings.t("CARD_%s_TITLE" % card_id, str(data.get("title", card_id))).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	box.add_child(title)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	box.add_child(meta)

	var cost := Label.new()
	cost.text = str(data.get("cost", "-"))
	cost.custom_minimum_size = Vector2(34, 30)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_override("font", T.display_font(700))
	cost.add_theme_font_size_override("font_size", 20)
	cost.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	cost.add_theme_stylebox_override(
		"normal",
		_home_flat_style(Color(0.06, 0.09, 0.10, 0.96), Color(0.18, 0.62, 0.72, 1.0), 5, 1)
	)
	meta.add_child(cost)

	var type_id := str(data.get("type", "card")).to_upper()
	var type_label := Label.new()
	type_label.text = Settings.t("UI_BATTLE_CARD_TYPE_%s" % type_id, type_id)
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.add_theme_font_override("font", T.display_font(600))
	type_label.add_theme_font_size_override("font_size", 17)
	type_label.add_theme_color_override("font_color", Color(0.76, 0.66, 0.48, 1.0))
	meta.add_child(type_label)

	box.add_child(_daily_divider())

	var desc := Label.new()
	desc.text = _strip_bbcode(
		Settings.t("CARD_%s_DESC" % card_id, str(data.get("description", "")))
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.88, 0.80, 0.66, 1.0))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	return slot


## Locked codex slot: the battle card back (dark glass fallback while the
## Codex asset regenerates) + a centered "???". Deliberately NO card name and
## NO tooltip — unseen cards stay unspoiled.
func _make_gallery_locked_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(214, 300)
	slot.add_theme_stylebox_override(
		"panel",
		_home_flat_style(Color(0.030, 0.026, 0.020, 0.88), Color(0.17, 0.14, 0.10, 1.0), 6, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	slot.add_child(margin)

	if ResourceLoader.exists(GALLERY_CARD_BACK):
		var back := TextureRect.new()
		back.texture = load(GALLERY_CARD_BACK)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back.modulate = Color(0.58, 0.58, 0.58, 0.80)
		margin.add_child(back)
	else:
		# Codex asset may still be regenerating — warn only, keep the dark glass.
		push_warning("CardGallery: missing card back texture %s" % GALLERY_CARD_BACK)
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.055, 0.048, 0.038, 0.75)
		margin.add_child(placeholder)

	var center := CenterContainer.new()
	margin.add_child(center)
	var mark := Label.new()
	mark.text = "???"
	mark.add_theme_font_override("font", T.display_font(700))
	mark.add_theme_font_size_override("font_size", 32)
	mark.add_theme_color_override("font_color", Color(0.74, 0.66, 0.52, 0.92))
	mark.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	mark.add_theme_constant_override("outline_size", 3)
	center.add_child(mark)
	return slot


func _strip_bbcode(text: String) -> String:
	return text.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")


func _open_character_window() -> void:
	CHARACTER_WINDOW.open_window(self, "base")


## The two 56×56 image buttons INSIDE the bottom bar's right box (vertically
## centered): Stash then Character. Same callbacks as the right-edge buttons
## they replace.
func _add_side_buttons(parent: Control) -> void:
	parent.add_child(_make_stash_button())
	parent.add_child(_make_character_button())


## Stash image button — dedicated kit art (btn_stash_*, ui-kit V4/v7); falls
## back to the removed warehouse building's sprite if the kit files are absent.
## The _hover/_pressed texture swap IS the highlight. Opens the stash window.
func _make_stash_button() -> Control:
	var normal_tex := T.ui_kit_tex("btn_stash_normal")
	var hover_tex := T.ui_kit_tex("btn_stash_hover")
	var pressed_tex := T.ui_kit_tex("btn_stash_pressed")
	if normal_tex == null:
		normal_tex = _load_home_texture(BUILDING_IMAGE_DIR + "warehouse.png")
		hover_tex = _load_home_texture(BUILDING_IMAGE_DIR + "warehouse_hover.png")
		pressed_tex = _load_home_texture(BUILDING_IMAGE_DIR + "warehouse_pressed.png")
	var button := TextureButton.new()
	button.name = "StashSideButton"
	button.custom_minimum_size = Vector2(56, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.texture_normal = normal_tex
	button.texture_hover = hover_tex if hover_tex is Texture2D else normal_tex
	button.texture_pressed = pressed_tex if pressed_tex is Texture2D else button.texture_hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.tooltip_text = tr("UI_STASH_WINDOW_TITLE")
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover"))
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_open_stash_window)
	return button


## Character image button — dedicated kit art (btn_char_*, ui-kit V4/v7) with
## real hover/pressed states; falls back to the hero headshot + modulate
## brighten + border frame when the kit files are absent. Toggles the
## base-mode character window, same as KEY_I.
func _make_character_button() -> Control:
	var normal_tex := T.ui_kit_tex("btn_char_normal")
	var hover_tex := T.ui_kit_tex("btn_char_hover")
	var pressed_tex := T.ui_kit_tex("btn_char_pressed")
	var kit_mode := normal_tex != null
	if not kit_mode:
		normal_tex = _load_home_texture(HERO_HEADSHOT_PATH)
		if normal_tex == null:
			normal_tex = _load_home_texture(HERO_PORTRAIT_PATH)
	var button := TextureButton.new()
	button.name = "CharacterSideButton"
	button.custom_minimum_size = Vector2(56, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.texture_normal = normal_tex
	if kit_mode:
		button.texture_hover = hover_tex if hover_tex is Texture2D else normal_tex
		button.texture_pressed = pressed_tex if pressed_tex is Texture2D else button.texture_hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.tooltip_text = tr("UI_EQUIP_TITLE_CHARACTER")
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(
		func() -> void:
			AudioManager.play_sfx("ui_hover")
			if not kit_mode:
				button.modulate = Color(1.18, 1.18, 1.18)
	)
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_open_character_window)
	if not kit_mode:
		# Border-only frame overlay so the square portrait reads as a button.
		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := T.rounded_button(Color(0, 0, 0, 0), Color(0.62, 0.48, 0.28, 0.9), 6, 2)
		sb.draw_center = false
		frame.add_theme_stylebox_override("panel", sb)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(frame)
	return button


## Stash side button: open the pure storage page. The character button opens the
## separate character/backpack page; players can keep both open for drag flow.
func _open_stash_window() -> void:
	STASH_WINDOW.open_window(self)


## Forge entrance — dual floating windows instead of the old fullscreen
## BuildingOverlay: the ForgeWindow (560 wide) opens on the LEFT beside the
## base-mode CharacterWindow (700 wide) on the RIGHT, so stash gear drags from
## the character window straight onto the forge bench (Diablo-style). A locked
## forge still routes to the unlock confirm like every other building. Windows
## already open are brought to front, never duplicated (positions are set AFTER
## WindowLayer.open(), which centers by default).
func _open_forge_windows() -> void:
	if MetaProgress.get_building_tier("forge") <= 0:
		_show_tier_confirm("forge")
		return
	var wl = load("res://run_system/ui/window/window_layer.gd").ensure(self)
	var fw = wl.get_node_or_null("ForgeWindow")
	if fw == null or fw.is_queued_for_deletion():
		fw = load("res://run_system/ui/window/forge_window.gd").new()
		fw.name = "ForgeWindow"
		wl.open(fw)
		fw.position = Vector2(120, 140)  # forge on the LEFT
	else:
		wl.bring_to_front(fw)
	var cw = wl.get_node_or_null("CharacterWindow")
	if cw == null or cw.is_queued_for_deletion():
		cw = CHARACTER_WINDOW.new()
		cw.name = "CharacterWindow"
		cw.mode = "base"
		wl.open(cw)
		cw.position = Vector2(800, 120)  # character window on the RIGHT
	else:
		wl.bring_to_front(cw)


## START NEW RUN launches the run directly (the hero-select screen was removed).
## Hero + ascension come from the pending intent set by the character window
## (hero) and the Outpost (difficulty) building screen; both fall back to safe
## defaults so a run never starts with an empty hero. start_new_run also resolves
## these pending values internally — passing them explicitly keeps the behavior obvious.
func _on_start_pressed() -> void:
	var hero: String = (
		RunManager.pending_hero_id if RunManager.pending_hero_id != "" else DEFAULT_HERO_ID
	)
	var asc: int = RunManager.pending_ascension if RunManager.pending_ascension >= 0 else 0
	RunManager.start_new_run(hero, [], asc)
	SceneTransition.change_to_packed(MAP_PACKED)


func _build_recent_runs_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var history: Array = MetaProgress.run_history
	if history.is_empty():
		var none := Label.new()
		none.text = tr("UI_HOME_NO_RUNS")
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(none)
		return panel

	# Show newest first, max 5 entries.
	var slice_start: int = max(0, history.size() - 5)
	var to_show: Array = history.slice(slice_start)
	to_show.reverse()
	for entry in to_show:
		vbox.add_child(_build_history_row(entry))
	return panel


func _build_history_row(entry: Dictionary) -> Label:
	var outcome: String = str(entry.get("outcome", "?"))
	var icon: String = "✓" if outcome == "victory" else ("⤴" if outcome == "extracted" else "✗")
	var color: Color = (
		{
			"victory": Color(0.4, 1.0, 0.5),
			"extracted": Color(1.0, 0.9, 0.4),
		}
		. get(outcome, Color(1.0, 0.4, 0.4))
	)

	var hero: String = _humanize_hero_id(str(entry.get("hero_id", "?")))
	var floor_index: int = int(entry.get("floor", 0))
	var act: int = int(entry.get("act", 1))  # legacy summaries predate `act`
	var core_earned: int = int(entry.get("core_earned", 0))

	var row := Label.new()
	row.text = (tr("UI_HOME_RUN_ROW").format(
		{"icon": icon, "hero": hero, "act": act, "floor": floor_index + 1, "core": core_earned}
	))
	row.add_theme_color_override("font_color", color)
	return row


func _humanize_hero_id(hero_id: String) -> String:
	# Quick lookup table — covers the two heroes we ship. These are compact
	# run-history nicknames (not the canonical hero name), so they are local UI
	# labels owned by ui_home, not the HERO_<id>_NAME content key.
	var names := {
		"cowboy_bill": tr("UI_HOME_HERO_BILL"),
	}
	if names.has(hero_id):
		return names[hero_id]
	return hero_id.replace("_", " ").capitalize()
