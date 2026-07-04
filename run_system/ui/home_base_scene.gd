## Home base scene — the boot scene + post-run return point.
## Layout: the 4 building tiles centered in a row, and ONE full-width bottom
## HUD bar (the CURRENCY_TOP_BAR component) holding everything else — currency
## chips on the left, the giant START NEW RUN button with the compact
## difficulty button (→ picker popup) stacked above it in the centre
## (protruding above the bar top per the approved mockup), and the Stash /
## Character image buttons on the right; `i` also toggles the character
## window. The base's actual functions live in the per-building screens
## (run_system/ui/buildings/).
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")
const SETTINGS_PANEL = preload("res://run_system/ui/settings_panel.gd")
const PAUSE_PANEL = preload("res://run_system/ui/pause_panel.gd")
## Fallback hero when no character-window selection has been made — the base hero,
## always available. Keeps START NEW RUN robust (a run never begins with an empty hero).
const DEFAULT_HERO_ID := "cowboy_bill"
const CHARACTER_WINDOW = preload("res://run_system/ui/window/character_window.gd")
const CURRENCY_TOP_BAR = preload("res://run_system/ui/window/currency_top_bar.gd")
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

## The A0..A5 buttons inside the difficulty picker popup (rebuilt every open).
var _difficulty_buttons: Array[Button] = []
## Compact button above START — label shows the current pick ("难度 A{n}").
var _difficulty_button: Button
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("home")
	_build()
	# Currency labels live in the global bottom bar now (it tracks the currency
	# signals itself).
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
	)


func _build() -> void:
	_add_background()
	_add_building_sprites()
	_add_bottom_bar()


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
	if ResourceLoader.exists(HOME_BACKGROUND_PATH):
		var bg := TextureRect.new()
		bg.texture = load(HOME_BACKGROUND_PATH)
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


## ONE full-width bottom HUD bar (approved mockup): the CURRENCY_TOP_BAR
## component owns the chrome + the Core/Caps/Scrap chips (left) and exposes
## center_box / right_box containers; this scene fills them with its own
## controls — the START + difficulty stack in the centre and the Stash /
## Character image buttons on the right — so all scene logic stays here.
## The bar is a CanvasLayer (70), so the difficulty picker popup (150) and
## the other fullscreen popups still open above it.
func _add_bottom_bar() -> void:
	var bar = CURRENCY_TOP_BAR.new()
	bar.name = "CurrencyBar"
	add_child(bar)
	_add_depart_controls(bar.center_box)
	_add_side_buttons(bar.right_box)


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


## Brass bar-button restyle over apply_button_theme (keeps its hover juice /
## font colors, swaps the Kenney texture for the ui_kit brass set or its flat
## fallback).
func _style_brass_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", T.ui_button_brass("normal"))
	btn.add_theme_stylebox_override("hover", T.ui_button_brass("hover"))
	btn.add_theme_stylebox_override("pressed", T.ui_button_brass("pressed"))


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
		_difficulty_button.text = (tr("UI_HOME_DIFFICULTY_BTN").format(
			{"a": _current_difficulty()}
		))


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
		var lock_tex := T.ui_kit_tex("icon_lock")
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


## Floating building label: "Lv<tier>  <name>", centered, no box, gentle up-down bob.
func _add_building_plaque(building_id: String, rect: Rect2, title: String) -> void:
	var label := Label.new()
	label.name = "Plaque_%s" % building_id
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if building_id == "depart_gate":
		label.text = title
	elif MetaProgress.get_building_tier(building_id) <= 0:
		label.text = title  # locked: name only (the 🔒 sits on the sprite)
	else:
		label.text = "Lv%d  %s" % [MetaProgress.get_building_tier(building_id), title]
	label.add_theme_font_size_override("font_size", 33)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.68))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 9)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 5)
	_set_map_rect(label, rect)
	_buildings_root.add_child(label)
	# Gentle bob; duration varies a touch per building so they drift out of lockstep.
	var base_y := label.position.y
	var dur := 1.7 + fmod(rect.position.x * 0.0017, 1.0) * 0.6
	var tw := label.create_tween().set_loops()
	tw.tween_property(label, "position:y", base_y - 7.0, dur).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	tw.tween_property(label, "position:y", base_y, dur).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	# Unlock / upgrade action lives here on the overview now (moved off the detail page).
	if building_id != "depart_gate":
		_add_tier_button(building_id, rect)
	return


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
	if cost < 0 or MetaProgress.core < cost:
		return
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var yes := Button.new()
	yes.text = "确认" if zh else "Confirm"
	yes.custom_minimum_size = Vector2(150, 46)
	yes.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(yes)
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
func _open_character_window() -> void:
	CHARACTER_WINDOW.open_window(self, "base")


## The two 56×56 image buttons INSIDE the bottom bar's right box (vertically
## centered): Stash then Character. Same callbacks as the right-edge buttons
## they replace.
func _add_side_buttons(parent: Control) -> void:
	parent.add_child(_make_stash_button())
	parent.add_child(_make_character_button())


## Stash image button — reuses the removed warehouse building's art; the
## _hover/_pressed texture swap IS the highlight. Opens the stash + character
## window pair (_open_stash_windows).
func _make_stash_button() -> Control:
	var normal_tex := _load_home_texture(BUILDING_IMAGE_DIR + "warehouse.png")
	var hover_tex := _load_home_texture(BUILDING_IMAGE_DIR + "warehouse_hover.png")
	var pressed_tex := _load_home_texture(BUILDING_IMAGE_DIR + "warehouse_pressed.png")
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
	button.pressed.connect(_open_stash_windows)
	return button


## Character image button — the square hero headshot (no hover PNG exists, so
## the highlight is a modulate brighten) inside a subtle border frame. Toggles
## the base-mode character window, same as KEY_I.
func _make_character_button() -> Control:
	var tex := _load_home_texture(HERO_HEADSHOT_PATH)
	if tex == null:
		tex = _load_home_texture(HERO_PORTRAIT_PATH)
	var button := TextureButton.new()
	button.name = "CharacterSideButton"
	button.custom_minimum_size = Vector2(56, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.tooltip_text = tr("UI_EQUIP_TITLE_CHARACTER")
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(
		func() -> void:
			AudioManager.play_sfx("ui_hover")
			button.modulate = Color(1.18, 1.18, 1.18)
	)
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	button.pressed.connect(_open_character_window)
	# Border-only frame overlay so the square portrait reads as a button.
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := T.rounded_button(Color(0, 0, 0, 0), Color(0.62, 0.48, 0.28, 0.9), 6, 2)
	sb.draw_center = false
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(frame)
	return button


## Stash side button — ENSURE both halves of the storage flow are open side by
## side: StashWindow on the LEFT, base-mode CharacterWindow on the RIGHT (drag
## gear between them). Unlike StashWindow.open_window (a toggle), pressing the
## button never closes anything — windows already open are brought to front,
## mirroring _open_forge_windows.
func _open_stash_windows() -> void:
	var wl = load("res://run_system/ui/window/window_layer.gd").ensure(self)
	var sw = wl.get_node_or_null("StashWindow")
	if sw == null or sw.is_queued_for_deletion():
		sw = load("res://run_system/ui/window/stash_window.gd").new()
		sw.name = "StashWindow"
		wl.open(sw)
		sw.position = Vector2(160, 160)  # stash on the LEFT
	else:
		wl.bring_to_front(sw)
	var cw = wl.get_node_or_null("CharacterWindow")
	if cw == null or cw.is_queued_for_deletion():
		cw = CHARACTER_WINDOW.new()
		cw.name = "CharacterWindow"
		cw.mode = "base"
		wl.open(cw)
		cw.position = Vector2(760, 120)  # character window on the RIGHT
	else:
		wl.bring_to_front(cw)


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
