## Shared theming primitives for the Hardcore 128 Pixel Wasteland UI.
## Used by loot_reward, map_scene, battle_top_bar, and any future UI scene.
##
## The palette is sampled directly from the project's actual sprite art via
## `tools/extract_palette.py` — see `tools/palette_report.md` for the source
## frequency breakdown and the picked canonical 14 colors. Updating colors
## here only is fine; do NOT inline hex codes in consumer scripts.
##
## Provides:
##   1. Shared color palette constants (sampled + accent neons)
##   2. StyleBoxFlat builders for the three common shapes used across the project:
##      - panel_with_shadow(): drop-shadowed panel (loot_reward backgrounds)
##      - panel_flat():        flat panel, no shadow (relic modal, battle top bar)
##      - rounded_button():    button-style box with optional shadow
##
## Per-scene compositions (e.g. wrapping panel_flat + extra margins for a relic
## panel) stay in the consuming scene — only the base shape lives here.
##
## Naming note: this file is intentionally `wasteland_theme.gd` (no style-era
## suffix) because the project's art direction has pivoted multiple times.
## See ADR-0010 for the naming + palette decision history.
extends RefCounted
class_name WastelandTheme

# ─── Base earth tones (sampled from actual sprites — see palette_report.md) ──
const RUST_PRIMARY = Color("#a05020")  # rank 1, 5.49% — dominant warm
const LEATHER_DARK = Color("#302010")  # rank 5, dark structural / outline
const SAND_LIGHT = Color("#e0d0a0")  # rank 30, light highlight / icon shine
const WARM_TAN = Color("#b08050")  # rank 17, mid warm
const DUSTY_TAUPE = Color("#605040")  # rank 40, neutral mid

# ─── Accent neons (from project-rules.md §1 prescription) ───────────────────
const ACCENT_NEON_BLUE = Color("#3bc7eb")  # primary highlight, hover edge
const ACCENT_NEON_GREEN = Color("#8ce04a")  # secondary, heal / positive
const ACCENT_DANGER = Color("#e07020")  # hits, warnings, attack intent

# ─── UI chrome (panel / border / text) ──────────────────────────────────────
const PANEL_BG_DARK = Color("#1a0e08")  # modal backdrop, inspect overlay
const PANEL_BG = Color("#2a1a10")  # standard panel bg
const PANEL_BORDER = Color("#6b3a1f")  # warm border
const TEXT_MAIN = Color("#f0d8a8")  # high-contrast text on dark
const TEXT_SECONDARY = Color("#b08060")  # dimmer text / subtitle
const SHADOW_COLOR = Color(0.00, 0.00, 0.00, 0.42)

# ─── Windowed-UI v2 chrome (approved character-window mockup palette) ────────
const UI_WINDOW_BG = Color("#14100a")  # floating-window body
const UI_TITLEBAR_BG = Color("#221610")  # title-bar strip
const UI_BORDER_BRASS = Color("#6b5228")  # window / plate border
const UI_HEADER_GOLD = Color("#f2c56a")  # section headers, window title
const UI_LABEL_BROWN = Color("#9a7c4e")  # slot labels
const UI_LABEL_DIM = Color("#8a7050")  # dim labels (stat line, counts)
const UI_INSET_BG = Color("#0e0b07")  # recessed wells (paper-doll zone)
const UI_INSET_BORDER = Color("#3a2c18")  # inset border + thin dividers
const UI_SLOT_BORDER = Color("#55401f")  # empty equip-slot border
const UI_SLOT_ICON_TINT = Color("#6e5834")  # empty-slot glyph + header hints
const UI_BRASS_LIGHT = Color("#d9b06a")  # filled / hover brass
const UI_LOCKED_BG = Color("#0a0805")  # locked backpack cell
const UI_LOCKED_BORDER = Color("#241b10")
const UI_LOCKED_GLYPH = Color("#3d2f1b")  # flat padlock color
const UI_EMPTY_BG = Color("#0c0906")  # empty backpack cell
const UI_EMPTY_BORDER = Color("#2e2318")
const UI_NAMEPLATE_BG = Color("#1b1209")  # hero name plate
const UI_TOOL_BORDER = Color("#4a3820")  # tool slot ("optional") border
const UI_BAR_BG = Color("#1a1209")  # bottom HUD bar body
const UI_ACCENT_BG = Color("#c4462e")  # accent (START) red-clay plate
const UI_ACCENT_BG_HOVER = Color("#d8543a")
const UI_ACCENT_BG_PRESSED = Color("#a83a26")
const UI_ACCENT_RIM = Color("#f0c060")  # accent gold rim
const UI_ACCENT_TEXT = Color("#ffe8c0")  # accent button label

# ─── Builders ─────────────────────────────────────────────────────────────────


## Generic panel with drop shadow. Used by loot_reward backgrounds.
static func panel_with_shadow(
	bg: Color, border: Color, radius: int = 4, border_width: int = 3
) -> StyleBoxFlat:
	var style = _base(bg, border, radius, border_width)
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = 8
	style.shadow_offset = Vector2(4, 4)
	return style


## Flat panel without shadow. Used by the relic modal and battle top bar.
static func panel_flat(
	bg: Color, border: Color, radius: int = 8, border_width: int = 3
) -> StyleBoxFlat:
	return _base(bg, border, radius, border_width)


## Rounded button-shaped style. Optionally adds content margins for use as a panel.
static func rounded_button(
	bg: Color, border: Color, radius: int = 6, border_width: int = 1
) -> StyleBoxFlat:
	return _base(bg, border, radius, border_width)


## Reward row style: panel_with_shadow wrapped with row-content padding.
## Used by loot_reward to render the list of loot rows.
static func reward_row_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = panel_with_shadow(bg, border, 3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## Square icon well frame with a slightly thicker border than a normal panel.
## Used by loot_reward's icon thumbnails.
static func icon_frame_style() -> StyleBoxFlat:
	return panel_with_shadow(Color(0.045, 0.04, 0.035, 1.0), Color(0.62, 0.44, 0.22, 1.0), 2, 3)


## Apply panel + hover + pressed stylebox triplet to a Button.
## Updated to use codex's textured button_normal/hover/pressed PNGs (9-slice).
## The `bg`/`border`/`radius` params are now ignored — kept for caller signature
## compatibility. Callers that need pure programmatic style can use rounded_button().
static func apply_button_theme(
	button: Button, _bg: Color = Color.WHITE, _border: Color = Color.WHITE, _radius: int = 4
) -> void:
	button.add_theme_stylebox_override("normal", button_textured("normal"))
	button.add_theme_stylebox_override("hover", button_textured("hover"))
	button.add_theme_stylebox_override("pressed", button_textured("pressed"))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", SAND_LIGHT)
	button.add_theme_color_override("font_pressed_color", SAND_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
	# Hover "juice": a soft tick + a subtle scale pop. Attached here so every themed
	# button across the game gets the same alive feedback for free.
	button.mouse_entered.connect(
		func() -> void:
			if not is_instance_valid(button) or button.disabled:
				return
			AudioManager.play_sfx("ui_hover")
			_button_pop(button, Vector2(1.04, 1.04), 0.08)
	)
	button.mouse_exited.connect(
		func() -> void:
			if is_instance_valid(button):
				_button_pop(button, Vector2.ONE, 0.10)
	)


## Tween a button's scale (centered) with the prior pop killed first, so rapid
## hover in/out doesn't stack fighting tweens. Used by apply_button_theme's juice.
static func _button_pop(button: Button, to: Vector2, dur: float) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return  # create_tween() outside the tree warns; skip if mid-removal
	var prev = button.get_meta("_juice_tw") if button.has_meta("_juice_tw") else null
	if prev != null and (prev is Tween) and prev.is_valid():
		prev.kill()
	button.pivot_offset = button.size / 2.0
	var tw := button.create_tween()
	button.set_meta("_juice_tw", tw)
	tw.tween_property(button, "scale", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fade a freshly-shown modal/overlay in (modulate only — safe under any container,
## unlike scale/position which fight layout). Call once the control is in the tree.
static func fade_in(control: Control, dur: float = 0.16) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, dur)


## Theme an HSlider's track + filled area to wasteland tones (kills the default
## grey/blue slider). The grabber stays the engine default — small + unobtrusive.
static func style_slider(slider: HSlider, accent: Color = Color(0.82, 0.58, 0.25)) -> void:
	slider.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.06, 0.05, 0.04, 0.95)
	track.border_color = Color(0.0, 0.0, 0.0, 0.5)
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


# ─── Display font (Oswald — condensed, for titles/labels/numbers) ─────────────
## Oswald is Latin-only, so it falls back to the project CJK font for Chinese —
## English/numbers get the condensed HUD look, 中文 still renders via Noto.
const DISPLAY_FONT_SRC = preload("res://assets/fonts/Oswald.ttf")
const CJK_FALLBACK = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")


## A condensed Oswald FontVariation at the given weight (100–700). Apply with
## label.add_theme_font_override("font", T.display_font(600)). The wasteland HUD
## look comes from this + tight letter-spacing.
static func display_font(weight: int = 600) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = DISPLAY_FONT_SRC
	fv.variation_opentype = {"wght": weight}
	fv.fallbacks = [CJK_FALLBACK]
	return fv


## Apply the display font + size (+ optional letter spacing) to a Label in one call.
static func style_display(label: Label, size: int, weight: int = 600, spacing: int = 0) -> void:
	label.add_theme_font_override("font", display_font(weight))
	label.add_theme_font_size_override("font_size", size)
	if spacing != 0:
		label.add_theme_constant_override("font_spacing_glyph", spacing)


# ─── Textured (PNG-based) builders ────────────────────────────────────────────
# Codex delivers 9-slice PNG components — these helpers wrap them in
# StyleBoxTexture so .add_theme_stylebox_override("panel", ...) Just Works.

# Kenney UI Pack (CC0) 9-slice art, tinted to wasteland tones via modulate_color.
const _K_PANEL = preload("res://run_system/assets/images/ui/kenney/panel.png")
const _K_PANEL_RECESSED = preload("res://run_system/assets/images/ui/kenney/panel_recessed.png")
const _K_BTN_NORMAL = preload("res://run_system/assets/images/ui/kenney/button_normal.png")
const _K_BTN_HOVER = preload("res://run_system/assets/images/ui/kenney/button_hover.png")
const _K_BTN_PRESSED = preload("res://run_system/assets/images/ui/kenney/button_pressed.png")

# Wasteland tints applied over the grey Kenney art.
const _TINT_PANEL = Color(0.40, 0.29, 0.17)
const _TINT_PANEL_DARK = Color(0.26, 0.18, 0.10)
const _TINT_BTN = Color(0.60, 0.45, 0.26)
const _TINT_BTN_HOVER = Color(0.82, 0.64, 0.36)
const _TINT_BTN_PRESSED = Color(0.46, 0.33, 0.19)


## 9-slice panel (Kenney art, wasteland-tinted). variant: "default" / "dark".
static func panel_textured(variant: String = "default") -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = _K_PANEL_RECESSED if variant == "dark" else _K_PANEL
	style.modulate_color = _TINT_PANEL_DARK if variant == "dark" else _TINT_PANEL
	for s in [
		&"texture_margin_left",
		&"texture_margin_right",
		&"texture_margin_top",
		&"texture_margin_bottom"
	]:
		style.set(s, 34)
	for s in [
		&"content_margin_left",
		&"content_margin_right",
		&"content_margin_top",
		&"content_margin_bottom"
	]:
		style.set(s, 16)
	return style


## 9-slice button stylebox (Kenney art, brass-tinted). state: normal/hover/pressed.
static func button_textured(state: String = "normal") -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	match state:
		"hover":
			style.texture = _K_BTN_HOVER
			style.modulate_color = _TINT_BTN_HOVER
		"pressed":
			style.texture = _K_BTN_PRESSED
			style.modulate_color = _TINT_BTN_PRESSED
		_:
			style.texture = _K_BTN_NORMAL
			style.modulate_color = _TINT_BTN
	style.texture_margin_left = 18
	style.texture_margin_right = 18
	style.texture_margin_top = 14
	style.texture_margin_bottom = 20
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 10
	return style


## Currency icon PNGs (Codex art). Keyed by currency id: core / caps / scrap.
const _CURRENCY_ICON_DIR := "res://run_system/assets/images/home/currency/"

## Currency display fallback names (used only if the icon PNG is missing, so
## a regressed art pipeline never leaves the number without a unit).
const _CURRENCY_FALLBACK_NAME := {
	"core": {"zh": "核心", "en": "Core"},
	"caps": {"zh": "瓶盖", "en": "Caps"},
	"scrap": {"zh": "废料", "en": "Scrap"},
}


## Amount + currency ICON row: an HBoxContainer with a number Label followed by a
## small TextureRect icon (`home/currency/{currency}.png`; currency ∈ core/caps/
## scrap). Falls back to "<amount> <currency-word>" text if the icon PNG is
## missing so a regressed art pipeline never leaves a bare, unlabeled number.
## `icon_size` controls the icon's square size (20–24px fits inline with body text).
## `prefix` optionally prepends a label before the row (e.g. "花费: <row>") — pass
## the already-translated prefix text; empty string omits it.
static func currency_row(
	amount: int, currency: String, font_size: int = 20, icon_size: int = 22, prefix: String = ""
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if prefix != "":
		var prefix_lbl := Label.new()
		prefix_lbl.text = prefix
		prefix_lbl.add_theme_font_size_override("font_size", font_size)
		prefix_lbl.add_theme_color_override("font_color", TEXT_MAIN)
		prefix_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(prefix_lbl)

	var icon_path := "%s%s.png" % [_CURRENCY_ICON_DIR, currency]
	var icon_tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		var loaded = load(icon_path)
		if loaded is Texture2D:
			icon_tex = loaded

	var amount_lbl := Label.new()
	amount_lbl.text = str(amount)
	amount_lbl.add_theme_font_size_override("font_size", font_size)
	amount_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	amount_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount_lbl)
	# Stable handle regardless of child order (the optional prefix Label, when
	# present, sits BEFORE this one) — callers that need to live-update the
	# number should fetch `row.get_meta("amount_label")` rather than assuming
	# a child index.
	row.set_meta("amount_label", amount_lbl)

	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		# Missing-art fallback: show the currency word so the number still reads.
		var zh := Settings.language == "zh"
		var names: Dictionary = _CURRENCY_FALLBACK_NAME.get(
			currency, {"zh": currency, "en": currency}
		)
		var word_lbl := Label.new()
		word_lbl.text = str(names.get("zh" if zh else "en", currency))
		word_lbl.add_theme_font_size_override("font_size", font_size)
		word_lbl.add_theme_color_override("font_color", TEXT_SECONDARY)
		word_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(word_lbl)

	return row


## A currency_row anchored as a right-edge overlay badge on a parent Control (a
## Button that already has left-aligned verb text, typically) — e.g. "Reforge"
## text on the left, a Scrap amount+icon badge overlaid on the right. Anchors to
## the FULL right column (top=0, bottom=1) and wraps the row in a CenterContainer
## so it is reliably vertically centered regardless of the parent's height —
## anchoring the row itself to a zero-height center-right point would collapse
## its rect and rely on min-size clamping, which is fragile. `right_inset` /
## `left_inset` are negative pixel offsets from the parent's right edge (e.g.
## -8 / -66 reserves a ~58px-wide badge column, 8px from the edge).
static func overlay_cost_badge(
	amount: int, currency: String, font_size: int, icon_size: int, right_inset: int, left_inset: int
) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.anchor_top = 0.0
	holder.anchor_bottom = 1.0
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.offset_right = right_inset
	holder.offset_left = left_inset
	holder.offset_top = 0
	holder.offset_bottom = 0
	holder.add_child(currency_row(amount, currency, font_size, icon_size))
	return holder


## A square ✕ close button for the full-screen pages (character / run-deck).
## The caller anchors it to the page's top-right corner and connects `pressed`.
static func close_x_button() -> Button:
	var b := Button.new()
	b.text = "✕"
	b.custom_minimum_size = Vector2(48, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_stylebox_override("normal", button_textured("normal"))
	b.add_theme_stylebox_override("hover", button_textured("hover"))
	b.add_theme_stylebox_override("pressed", button_textured("pressed"))
	return b


# ─── Windowed-UI v2 builders (character / stash / forge window chrome) ───────
# Every shape routes through the Codex ui_kit texture hooks below
# (docs/asset-spec-ui-kit.md). The kit is CONTRACTED but not delivered — a
# missing PNG is NORMAL today and falls back to the programmatic StyleBoxFlat
# silently (no warning); delivery is drop-in with zero code change.

const _UI_KIT_DIR := "res://run_system/assets/images/ui_kit/"


## A ui_kit texture by basename ("icon_lock" → ui_kit/icon_lock.png), or null
## while the kit is undelivered. Callers must handle null with a flat fallback.
static func ui_kit_tex(kit_name: String) -> Texture2D:
	var path := _UI_KIT_DIR + kit_name + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


## StyleBoxTexture over a ui_kit 9-slice PNG, or `fallback` while the kit is
## undelivered. margin_h / margin_v are the 9-slice texture margins from the
## asset spec (margin_v = -1 mirrors margin_h). `tile_h` switches the middle
## column from STRETCH to TILE — for targets much wider than the source art
## (the full-width bottom bar), where stretching smears the baked detail.
## Only pass tile_h for art whose middle strip actually wraps cleanly.
static func _ui_kit_box(
	kit_name: String,
	fallback: StyleBoxFlat,
	margin_h: int = 0,
	margin_v: int = -1,
	tile_h: bool = false
) -> StyleBox:
	var tex := ui_kit_tex(kit_name)
	if tex == null:
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = tex
	if margin_v < 0:
		margin_v = margin_h
	style.texture_margin_left = margin_h
	style.texture_margin_right = margin_h
	style.texture_margin_top = margin_v
	style.texture_margin_bottom = margin_v
	if tile_h:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


## Floating-window body chrome (character / stash / forge windows).
static func ui_panel() -> StyleBox:
	return _ui_kit_box("panel_window", panel_with_shadow(UI_WINDOW_BG, UI_BORDER_BRASS, 6, 2), 48)


## Floating-window title-bar strip. Deliberately NOT tile_h: the titlebar
## art's middle strip has a hard left↔right wrap discontinuity (measured seam
## Δ≈12 mean / 104 peak vs ≈3 adjacent baseline), so tiling would draw visible
## seam lines; windows top out at ~700px wide, so the stretch stays mild.
static func ui_titlebar() -> StyleBox:
	return _ui_kit_box(
		"panel_window_titlebar", panel_flat(UI_TITLEBAR_BG, UI_BORDER_BRASS, 4, 1), 48, 16
	)


## Recessed inner well (paper-doll spotlight / inset sections).
static func ui_inset_panel() -> StyleBox:
	return _ui_kit_box("panel_inset", panel_flat(UI_INSET_BG, UI_INSET_BORDER, 6, 1), 48)


## Slot / backpack-cell box for the v2 window chrome. States:
##   "empty"      — equip slot awaiting gear (slot glyph on inset bg)
##   "cell_empty" — unlocked empty backpack grid cell
##   "locked"     — backpack cell beyond the unlocked capacity
##   "hover"      — brass hover/selected ring
##   "filled"     — carries gear; pass the rarity color as border_override
##   "tool"       — the optional tool slot (lighter border reads as "dashed")
## Kit hooks slot_normal / slot_hover / slot_locked skin the non-informational
## states; "filled" and "tool" stay flat so the rarity border is never lost.
static func ui_slot_box(
	state: String = "empty", border_override: Color = Color(0, 0, 0, 0)
) -> StyleBox:
	var kit_name := ""
	match state:
		"locked":
			kit_name = "slot_locked"
		"hover":
			kit_name = "slot_hover"
		"empty", "cell_empty":
			kit_name = "slot_normal"
	if kit_name != "":
		var tex := ui_kit_tex(kit_name)
		if tex:
			var style := StyleBoxTexture.new()
			style.texture = tex
			return style
	var fb: StyleBoxFlat
	match state:
		"locked":
			fb = _base(UI_LOCKED_BG, UI_LOCKED_BORDER, 6, 2)
		"cell_empty":
			fb = _base(UI_EMPTY_BG, UI_EMPTY_BORDER, 6, 2)
		"hover":
			fb = _base(UI_INSET_BG, UI_BRASS_LIGHT, 6, 2)
		"filled":
			fb = _base(UI_NAMEPLATE_BG, UI_BRASS_LIGHT, 6, 2)
		"tool":
			fb = _base(UI_EMPTY_BG, UI_TOOL_BORDER, 6, 2)
		_:
			fb = _base(UI_INSET_BG, UI_SLOT_BORDER, 6, 2)
	if border_override.a > 0.0:
		fb.border_color = border_override
	return fb


## The hero-switcher name plate (and other small brass-rimmed plates).
static func ui_nameplate_box() -> StyleBoxFlat:
	var style := _base(UI_NAMEPLATE_BG, UI_BORDER_BRASS, 4, 1)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


## Gold section-header Label (display font, wide glyph spacing) — the v2 window
## chrome's section titles.
static func ui_header_label(text: String, size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	var fv := display_font(700)
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UI_HEADER_GOLD)
	return l


## The home-base bottom HUD bar body — kit `panel_bottom_bar.png` (delivered
## at 345×142, 9-slice margins 64/24), else a flat dark strip whose only drawn
## border is a 2px brass TOP edge (the other three sides sit on the screen
## edge, so they stay width 0). The middle column TILES horizontally instead
## of stretching — 345→1920 smeared the baked rivets/seams; the strip's wrap
## edges match (measured seam Δ≈4 vs ≈3 adjacent-column baseline), so tiling
## repeats the pattern cleanly. Vertical stays a plain stretch.
static func ui_bottom_bar() -> StyleBox:
	var fb := StyleBoxFlat.new()
	fb.bg_color = UI_BAR_BG
	fb.border_color = UI_BORDER_BRASS
	fb.border_width_top = 2
	return _ui_kit_box("panel_bottom_bar", fb, 64, 24, true)


## Brass default bar-button — kit `btn_brass_<state>.png` (144×56 9-slice,
## margins 24), else flat: dark plate + 1px brass border; hover brightens the
## border, pressed darkens the plate. state: "normal" / "hover" / "pressed".
static func ui_button_brass(state: String = "normal") -> StyleBox:
	var fb: StyleBoxFlat
	match state:
		"hover":
			fb = _base(UI_NAMEPLATE_BG, UI_BRASS_LIGHT, 6, 1)
		"pressed":
			fb = _base(UI_INSET_BG, UI_BORDER_BRASS, 6, 1)
		_:
			fb = _base(UI_NAMEPLATE_BG, UI_BORDER_BRASS, 6, 1)
	return _ui_kit_box("btn_brass_" + state, fb, 24)


## Accent (giant START) button — kit `btn_accent_<state>.png` (delivered at
## 273×128, 9-slice margins 24 h / 20 v — the shallower vertical margins leave
## more of the plate in the scalable middle row, so drawing the 128px-tall art
## at the ~96px button height compresses it less), else flat: red-clay plate +
## 2px gold rim; hover brighter plate, pressed darker. Label text pairs with
## UI_ACCENT_TEXT.
static func ui_button_accent(state: String = "normal") -> StyleBox:
	var bg := UI_ACCENT_BG
	match state:
		"hover":
			bg = UI_ACCENT_BG_HOVER
		"pressed":
			bg = UI_ACCENT_BG_PRESSED
	return _ui_kit_box("btn_accent_" + state, _base(bg, UI_ACCENT_RIM, 6, 2), 24, 20)


## A 1px-thin horizontal divider line (the v2 chrome's only separator shape).
static func ui_divider() -> Control:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(0, 1)
	var style := StyleBoxFlat.new()
	style.bg_color = UI_INSET_BORDER
	line.add_theme_stylebox_override("panel", style)
	return line


# ─── Internal ─────────────────────────────────────────────────────────────────


static func _base(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
