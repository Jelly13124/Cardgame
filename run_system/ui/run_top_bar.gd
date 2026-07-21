extends Control

## Shared StS-style top bar used by every in-run screen (map, battle, shop,
## events, rest/upgrade pages, and deck views).
## Renders a hero portrait, cartoon-heart HP readout, compact XP tick, caps,
## tools, floor utilities, and a relic shelf below the main strip.
##
## Scene-agnostic: it reads RunManager (autoload) state and emits intent
## signals; the HOST scene wires the buttons to its own handlers. Set the
## config properties BEFORE add_child() so _ready() sees them.

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const RELIC_DATA_DIR := "res://run_system/data/relics/"
const TOPBAR_ICON_DIR := "res://run_system/assets/images/ui/topbar/"
const HERO_IDLE_DIR := "res://battle_scene/assets/images/heroes/"
const TOPBAR_BACKGROUND := "res://run_system/assets/images/ui_kit_lightline/hud_topbar_sts2.png"
const HEART_ICON := "res://run_system/assets/images/ui_kit_lightline/icon_heart.png"
const TIMER_ICON := "res://run_system/assets/images/ui_kit_lightline/iconb_clock.png"
const DECK_ICON := "res://run_system/assets/images/ui_kit_lightline/iconb_deck_stack.png"
const SETTINGS_ICON := "res://run_system/assets/images/ui_kit_lightline/icon_gear.png"
# In-run currency is Caps (owner 2026-07-08): same bottle-cap icon as the base.
const GOLD_ICON := "res://run_system/assets/images/home/currency/caps.png"

# â”€â”€â”€ Layout constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# StS2-style roomy strip: portrait | HP/XP | caps | one tool ... floor | deck/settings/time
const PORTRAIT_SIZE := 64.0
const MAIN_BAR_HEIGHT := 80.0
# Full-page art may continue behind the transparent relic shelf from this Y.
# Interactive page content still begins at BAR_HEIGHT.
const PAGE_ART_TOP := MAIN_BAR_HEIGHT
const RELIC_ROW_TOP := 84.0
const RELIC_ROW_HEIGHT := 46.0
const BAR_HEIGHT := 132.0
# The persistent run HUD owns this layer. Full-screen in-run pages and their
# illustration layers must stay below it; blocking pause/tutorial/transition
# overlays may intentionally use a higher layer.
const CANVAS_LAYER := 150
const HEART_SIZE := 42.0
const XP_TICK_WIDTH := 68.0
const XP_TICK_HEIGHT := 4.0

signal deck_pressed
signal character_pressed
signal settings_pressed
signal tool_used(index: int)

## â”€â”€â”€ Config (set by host before add_child) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
var hp_from_player: bool = false  # battle = true (live player HP)
var player_source: Node = null  # the PlayerEntity when hp_from_player
var show_character_button: bool = true  # map only (equipment locked in combat)
var show_settings_button: bool = false  # battle only
var show_tools: bool = false  # battle = tool slots are clickable/usable

## â”€â”€â”€ Cached nodes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
var _hp_label: Label
var _xp_label: Label
var _xp_tick: ProgressBar
var _gold_label: Label
var _floor_label: Label
var _relic_shelf: HBoxContainer
var _tool_shelf: HBoxContainer
var _portrait_label: Label  # fallback initial letter when no sprite
var _portrait_texture: TextureRect
var _time_label: Label
var _last_time_secs: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_right = 1.0
	offset_bottom = BAR_HEIGHT
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_build()
	_connect_state_sources()
	_refresh_all()


# â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _build() -> void:
	# Full-width matte comic strip. The irregular lower ink edge is baked into
	# the generated PNG; all information remains deterministic Godot UI above it.
	var bg := TextureRect.new()
	bg.name = "BackgroundArt"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_right = 1.0
	bg.offset_bottom = MAIN_BAR_HEIGHT
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	if ResourceLoader.exists(TOPBAR_BACKGROUND):
		bg.texture = load(TOPBAR_BACKGROUND)
	add_child(bg)

	# â”€â”€ Hero portrait badge (far left, flush top) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	# StS2-style "hole": the portrait sits in a dark recessed socket (no ornate
	# frame). Clicking it opens the character page — map only; in battle the
	# portrait is display-only (equipment is locked in combat).
	var portrait_panel := Button.new()
	portrait_panel.name = "PortraitButton"
	portrait_panel.focus_mode = Control.FOCUS_NONE
	portrait_panel.clip_contents = true
	portrait_panel.offset_left = 8.0
	portrait_panel.offset_top = (MAIN_BAR_HEIGHT - PORTRAIT_SIZE) * 0.5
	portrait_panel.offset_right = 8.0 + PORTRAIT_SIZE
	portrait_panel.offset_bottom = (MAIN_BAR_HEIGHT + PORTRAIT_SIZE) * 0.5
	# The "hole" look: near-black inset with a black rim; hover lightens slightly
	# so the map's clickable portrait reads as interactive.
	var hole := T.panel_flat(Color(0.030, 0.026, 0.022, 1.0), Color(0.0, 0.0, 0.0, 0.9), 10, 3)
	var hole_hover := T.panel_flat(Color(0.06, 0.052, 0.044, 1.0), Color(0.0, 0.0, 0.0, 0.9), 10, 3)
	portrait_panel.add_theme_stylebox_override("normal", hole)
	portrait_panel.add_theme_stylebox_override("hover", hole_hover)
	portrait_panel.add_theme_stylebox_override("pressed", hole)
	portrait_panel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if show_character_button:
		portrait_panel.tooltip_text = tr("UI_MAP_CHARACTER_BTN")
		portrait_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		portrait_panel.pressed.connect(func(): character_pressed.emit())
	add_child(portrait_panel)

	# TextureRect for the hero idle frame (fills the panel)
	_portrait_texture = TextureRect.new()
	_portrait_texture.name = "PortraitTexture"
	_portrait_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_panel.add_child(_portrait_texture)

	# Fallback letter label (shown when no texture)
	_portrait_label = Label.new()
	_portrait_label.name = "PortraitLabel"
	_portrait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", 36)
	_portrait_label.add_theme_color_override("font_color", T.TEXT_MAIN)
	_portrait_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_portrait_label.add_theme_constant_override("outline_size", 4)
	_portrait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(_portrait_label)

	_load_hero_portrait()

	# â”€â”€ Main content margin (starts AFTER the portrait badge) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	var margin := MarginContainer.new()
	margin.name = "MainMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.anchor_right = 1.0
	margin.offset_left = 14.0 if PORTRAIT_SIZE <= 0.0 else 6.0 + PORTRAIT_SIZE + 8.0
	margin.offset_bottom = MAIN_BAR_HEIGHT
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var row := HBoxContainer.new()
	row.name = "MainRow"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	# â”€â”€ Vitals: big HP bar + thin XP bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	# Frameless UI03 iconography on the lightweight UI07 strip.
	var vitals := HBoxContainer.new()
	vitals.name = "VitalsGroup"
	vitals.alignment = BoxContainer.ALIGNMENT_CENTER
	vitals.add_theme_constant_override("separation", 7)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vitals)

	var heart := TextureRect.new()
	heart.name = "HeartIcon"
	heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(HEART_ICON):
		heart.texture = load(HEART_ICON)
	vitals.add_child(heart)

	_hp_label = _make_plain_label(vitals, 25, Color(1.0, 0.34, 0.24))
	_hp_label.name = "HpLabel"
	_hp_label.custom_minimum_size.x = 92.0

	var xp_group := VBoxContainer.new()
	xp_group.name = "XpGroup"
	xp_group.add_theme_constant_override("separation", 2)
	xp_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(xp_group)
	_xp_label = _make_plain_label(xp_group, 16, Color(0.92, 0.86, 0.74))
	_xp_label.name = "XpLabel"
	_xp_tick = _make_xp_tick()
	xp_group.add_child(_xp_tick)

	# Gold sits LEFT next to the vitals, StS-style: bare icon + number, no frame.
	_gold_label = _make_icon_value(row, GOLD_ICON, 21, Color(1.0, 0.86, 0.45))

	# Tool slots (StS2-style top-bar consumables), left cluster next to gold.
	_tool_shelf = HBoxContainer.new()
	_tool_shelf.name = "ToolShelf"
	_tool_shelf.add_theme_constant_override("separation", 6)
	_tool_shelf.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_tool_shelf)
	if is_instance_valid(RunManager):
		RunManager.tools_changed.connect(refresh_tools)
	refresh_tools()

	# Spacer pushes the right cluster (floor · deck · settings · time) right.
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Floor only. The Act readout is intentionally removed from this compact HUD.
	_floor_label = _make_plain_label(row, 18, Color(0.90, 0.86, 0.76))
	_floor_label.name = "FloorLabel"

	var deck_btn := _make_icon_button("", tr("UI_BATTLE_VIEW_RUN_DECK"), "deck")
	deck_btn.pressed.connect(func(): deck_pressed.emit())
	row.add_child(deck_btn)

	# (Character entry now lives on the clickable hero portrait, far left.)
	if show_settings_button:
		var set_btn := _make_icon_button("", tr("SETTINGS_BUTTON"), "settings")
		set_btn.pressed.connect(func(): settings_pressed.emit())
		row.add_child(set_btn)

	# Run timer with the previously generated alarm-clock icon.
	var timer_group := HBoxContainer.new()
	timer_group.name = "TimerGroup"
	timer_group.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_group.add_theme_constant_override("separation", 4)
	timer_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(timer_group)
	var timer_icon := TextureRect.new()
	timer_icon.name = "TimerIcon"
	timer_icon.custom_minimum_size = Vector2(32, 32)
	timer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	timer_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	timer_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TIMER_ICON):
		timer_icon.texture = load(TIMER_ICON)
	timer_group.add_child(timer_icon)
	_time_label = _make_plain_label(timer_group, 18, Color(0.92, 0.90, 0.82))
	_time_label.name = "TimeLabel"
	_time_label.text = "0:00:00"

	# â”€â”€ Relic shelf (second row below main bar) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	_relic_shelf = HBoxContainer.new()
	_relic_shelf.name = "RelicShelf"
	_relic_shelf.anchor_right = 1.0
	_relic_shelf.offset_left = 16.0
	_relic_shelf.offset_top = RELIC_ROW_TOP
	_relic_shelf.offset_right = -16.0
	_relic_shelf.offset_bottom = RELIC_ROW_TOP + RELIC_ROW_HEIGHT
	_relic_shelf.mouse_filter = Control.MOUSE_FILTER_PASS
	_relic_shelf.add_theme_constant_override("separation", 8)
	add_child(_relic_shelf)


# â”€â”€â”€ Hero portrait loader â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _load_hero_portrait() -> void:
	# Try to load the hero's idle frame 0 as a portrait placeholder.
	# Hero data: current_hero_data["sprite_id"] â†’ id used for the folder name.
	# Path convention: battle_scene/assets/images/heroes/{sprite_id}/idle/{sprite_id}_idle_0.png
	var hero_data: Dictionary = RunManager.current_hero_data
	var sprite_id: String = str(hero_data.get("sprite_id", RunManager.current_hero_id))
	var hero_name: String = str(hero_data.get("name", sprite_id))

	var fallback_letter: String = "?"
	if not hero_name.is_empty():
		fallback_letter = hero_name.substr(0, 1).to_upper()

	# Prefer a dedicated headshot. Fall back to idle frames for older heroes.
	var tex: Texture2D = null
	if not sprite_id.is_empty():
		var headshot_path := "%s%s/%s_headshot.png" % [HERO_IDLE_DIR, sprite_id, sprite_id]
		if ResourceLoader.exists(headshot_path):
			var loaded = load(headshot_path)
			if loaded is Texture2D:
				tex = loaded
		var idle_path := "%s%s/idle/%s_idle_0.png" % [HERO_IDLE_DIR, sprite_id, sprite_id]
		if not tex and ResourceLoader.exists(idle_path):
			var loaded = load(idle_path)
			if loaded is Texture2D:
				tex = loaded
		# Fallback: try _idle_1.png (some heroes start at 1)
		if not tex:
			var alt_path := "%s%s/idle/%s_idle_1.png" % [HERO_IDLE_DIR, sprite_id, sprite_id]
			if ResourceLoader.exists(alt_path):
				var loaded = load(alt_path)
				if loaded is Texture2D:
					tex = loaded

	if tex:
		_portrait_texture.texture = tex
		_portrait_texture.visible = true
		_portrait_label.visible = false
	else:
		_portrait_texture.visible = false
		_portrait_label.text = fallback_letter


# â”€â”€â”€ Stat bar builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _make_xp_tick() -> ProgressBar:
	var tick := ProgressBar.new()
	tick.name = "XpTick"
	tick.custom_minimum_size = Vector2(XP_TICK_WIDTH, XP_TICK_HEIGHT)
	tick.show_percentage = false
	tick.min_value = 0.0
	tick.max_value = 1.0
	tick.value = 0.0
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.add_theme_stylebox_override(
		"background", T.panel_flat(Color(0.02, 0.035, 0.04, 0.82), Color(0, 0, 0, 0), 2, 0)
	)
	tick.add_theme_stylebox_override(
		"fill", T.panel_flat(Color(0.28, 0.82, 0.90), Color(0, 0, 0, 0), 2, 0)
	)
	return tick


# â”€â”€â”€ Framed chip builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


## Frameless "icon + value" readout (StS-style gold counter). Returns the value Label.
func _make_icon_value(parent: Control, icon_path: String, font_size: int, color: Color) -> Label:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)

	return _make_plain_label(box, font_size, color)


## Frameless text readout (act/floor, run timer). Returns the Label.
func _make_plain_label(parent: Control, font_size: int, color: Color = T.TEXT_MAIN) -> Label:
	var label := Label.new()
	label.text = "-"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.display_font(600))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label


# â”€â”€â”€ Run timer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _process(_delta: float) -> void:
	if not _time_label:
		return
	var secs := _run_elapsed_secs()
	if secs == _last_time_secs:
		return
	_last_time_secs = secs
	_time_label.text = "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]


## Seconds since the run started (RunManager.run_started_msec; 0 when no run).
func _run_elapsed_secs() -> int:
	var raw = RunManager.get("run_started_msec")
	var start: int = int(raw) if raw != null else 0
	if start <= 0:
		return 0
	return maxi(0, int((Time.get_ticks_msec() - start) / 1000))


# â”€â”€â”€ Icon button builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _make_icon_button(text: String, tooltip: String, icon_id: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", T.TEXT_MAIN)
	# Frameless — owner wants no frame behind the deck / character / settings buttons.
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not icon_id.is_empty():
		var tex := _load_topbar_icon(icon_id)
		if tex is Texture2D:
			button.icon = tex
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif button.text.is_empty():
			# No icon art yet → readable letter fallback so the button isn't invisible.
			button.text = icon_id.substr(0, 1).to_upper()
	return button


func _load_topbar_icon(icon_id: String) -> Texture2D:
	var path := "%s%s.png" % [TOPBAR_ICON_DIR, icon_id]
	if icon_id == "deck":
		path = DECK_ICON
	elif icon_id == "settings":
		path = SETTINGS_ICON
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


# â”€â”€â”€ State refresh â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _connect_state_sources() -> void:
	_connect_once(RunManager, "health_changed", "_on_rm_health")
	_connect_once(RunManager, "resources_changed", "_on_rm_resources")
	_connect_once(RunManager, "backpack_changed", "_on_rm_backpack")
	_connect_once(RunManager, "relics_updated", "_on_rm_relics")
	if hp_from_player and is_instance_valid(player_source):
		_connect_once(player_source, "health_changed", "_on_player_health")


func _connect_once(source: Object, signal_name: String, method_name: String) -> void:
	if not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	var cb := Callable(self, method_name)
	if not source.is_connected(signal_name, cb):
		source.connect(signal_name, cb)


func _refresh_all() -> void:
	_refresh_vitals()
	_refresh_caps_floor()
	_refresh_relics()


func _hp_values() -> Vector2:
	if hp_from_player and is_instance_valid(player_source):
		return Vector2(player_source.health, player_source.max_health)
	return Vector2(RunManager.current_health, RunManager.max_health)


func _refresh_vitals() -> void:
	if not _hp_label or not _xp_label or not _xp_tick:
		return
	var hp := _hp_values()
	_hp_label.text = "%d/%d" % [int(hp.x), int(hp.y)]

	var lvl: int = RunManager.level
	var need: int = RunManager.xp_to_next(lvl)
	var have: int = RunManager.xp
	_xp_tick.max_value = maxf(1.0, float(need))
	_xp_tick.value = clampf(float(have), 0.0, float(need))
	_xp_label.text = tr("UI_TOPBAR_LEVEL_FMT").format({"lvl": lvl, "xp": have, "next": need})


func _refresh_caps_floor() -> void:
	if not _gold_label:
		return
	_gold_label.text = str(RunManager.gold)
	if _floor_label:
		_floor_label.text = "%s %d" % [tr("UI_TOPBAR_FLOOR_SHORT"), RunManager.current_floor]


## Rebuild the top-bar tool slots from RunManager.tool_inventory (StS2-style).
func refresh_tools() -> void:
	if not is_instance_valid(_tool_shelf):
		return
	for c in _tool_shelf.get_children():
		c.queue_free()
	var inv: Array = RunManager.tool_inventory
	# The compact shared HUD exposes exactly one active tool at a time. If the
	# run owns more, consuming index 0 naturally advances the next one into view.
	if not inv.is_empty():
		_tool_shelf.add_child(_make_tool_slot(0, str(inv[0])))
	else:
		_tool_shelf.add_child(_make_empty_tool_slot())


func _make_empty_tool_slot() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(40, 40)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.5, 0.45, 0.35, 0.45)
	p.add_theme_stylebox_override("panel", sb)
	return p


## A filled tool slot: icon (or first-letter fallback) + tooltip; in battle a press
## emits tool_used(index) so the host resolves + consumes it.
func _make_tool_slot(index: int, tool_id: String) -> Button:
	var data := RunManager.get_tool_data(tool_id)
	var title := Settings.t(
		"TOOL_%s_TITLE" % tool_id, str(data.get("title", _humanize_id(tool_id)))
	)
	var desc := Settings.t("TOOL_%s_DESC" % tool_id, "")
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tip_text := (
		("[b]%s[/b]\n%s" % [title, desc]) if not desc.is_empty() else "[b]%s[/b]" % title
	)
	Tooltip.bind_hover(b, tip_text)
	var icon_path := str(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
	else:
		b.text = _short_label(title)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", T.TEXT_MAIN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.85)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.75, 0.95, 0.9)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.border_color = Color(0.78, 0.92, 1.0, 1.0)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sb)
	if show_tools:
		b.pressed.connect(func() -> void: tool_used.emit(index))
	return b


func _refresh_relics() -> void:
	if not _relic_shelf:
		return
	for child in _relic_shelf.get_children():
		child.queue_free()
	var ids: Array = RunManager.relics if typeof(RunManager.relics) == TYPE_ARRAY else []
	if ids.is_empty():
		return
	for relic_id in ids:
		_relic_shelf.add_child(_make_relic_medallion(str(relic_id)))


func _make_relic_medallion(relic_id: String) -> Button:
	var data := _load_relic_data(relic_id)
	var title := Settings.t(
		"RELIC_%s_TITLE" % relic_id, str(data.get("title", _humanize_id(relic_id)))
	)
	var desc := Settings.t("RELIC_%s_DESC" % relic_id, str(data.get("description", "")))

	var chip := Button.new()
	chip.text = _short_label(title)
	chip.custom_minimum_size = Vector2(48, 48)
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# StS-style: bare relic art, no frame / background box. The tooltip + the
	# pointing-hand cursor are the affordance; every state stays frameless.
	chip.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	chip.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	chip.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.add_theme_color_override("font_color", T.TEXT_MAIN)
	chip.add_theme_font_size_override("font_size", 20)  # old 18

	var icon_path := str(data.get("icon", ""))
	if not icon_path.is_empty():
		var tex := _load_icon_texture(_resolve_relic_icon_path(icon_path))
		if tex is Texture2D:
			chip.icon = tex
			chip.expand_icon = true
			chip.text = ""

	# Lambda safety (project bug class): guard the captured chip with
	# is_instance_valid; hide-on-tree_exited with an owner token so a stale
	# callback can't leak a tooltip past a relic-shelf rebuild.
	var tip_text := (
		("[b]%s[/b]\n%s" % [title, desc]) if not desc.is_empty() else "[b]%s[/b]" % title
	)
	var chip_ref: Button = chip
	var chip_id: int = chip.get_instance_id()
	chip.mouse_entered.connect(
		func():
			if not is_instance_valid(chip_ref):
				return
			Tooltip.show(
				tip_text, chip_ref.global_position + Vector2(chip_ref.size.x * 0.5, 0), chip_id
			)
	)
	chip.mouse_exited.connect(Tooltip.hide_if_owner.bind(chip_id))
	chip.tree_exited.connect(Tooltip.hide_if_owner.bind(chip_id))
	return chip


# â”€â”€â”€ Signal handlers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _on_rm_health(_c: int, _m: int) -> void:
	_refresh_vitals()


func _on_rm_resources(_g: int, _scrap: int) -> void:
	_refresh_caps_floor()


func _on_rm_backpack() -> void:
	_refresh_caps_floor()


func _on_rm_relics() -> void:
	_refresh_relics()


func _on_player_health(_current: int) -> void:
	_refresh_vitals()


# â”€â”€â”€ Relic data helpers (defensive, mirror battle_top_bar) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


func _load_relic_data(relic_id: String) -> Dictionary:
	var data := {"id": relic_id, "title": _humanize_id(relic_id), "description": "", "icon": ""}
	var file := FileAccess.open(RELIC_DATA_DIR + relic_id + ".json", FileAccess.READ)
	if not file:
		return data
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in parsed.keys():
			data[key] = parsed[key]
	return data


func _resolve_relic_icon_path(icon_path: String) -> String:
	if icon_path.begins_with("res://"):
		return icon_path
	return RELIC_DATA_DIR + icon_path


func _load_icon_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null


func _humanize_id(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _short_label(value: String) -> String:
	if value.is_empty():
		return "?"
	return value.substr(0, 1).to_upper()
