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

const _PANEL_DEFAULT_TEX = preload("res://battle_scene/assets/images/ui/panel_default.png")
const _PANEL_DARK_TEX = preload("res://battle_scene/assets/images/ui/panel_dark.png")
const _BUTTON_NORMAL_TEX = preload("res://battle_scene/assets/images/ui/button_normal.png")
const _BUTTON_HOVER_TEX = preload("res://battle_scene/assets/images/ui/button_hover.png")
const _BUTTON_PRESSED_TEX = preload("res://battle_scene/assets/images/ui/button_pressed.png")


## 9-slice panel from PNG. variant: "default" (rusty rivet panel) or "dark"
## (heavier modal backdrop). Margins match the asset spec's 16px corner safe-zone.
static func panel_textured(variant: String = "default") -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = _PANEL_DARK_TEX if variant == "dark" else _PANEL_DEFAULT_TEX
	style.texture_margin_left = 16
	style.texture_margin_right = 16
	style.texture_margin_top = 16
	style.texture_margin_bottom = 16
	return style


## 9-slice button stylebox. state: "normal" / "hover" / "pressed".
## Margins match the asset spec's 12px horizontal / 8px vertical corner safe-zone.
static func button_textured(state: String = "normal") -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	match state:
		"hover":
			style.texture = _BUTTON_HOVER_TEX
		"pressed":
			style.texture = _BUTTON_PRESSED_TEX
		_:
			style.texture = _BUTTON_NORMAL_TEX
	style.texture_margin_left = 12
	style.texture_margin_right = 12
	style.texture_margin_top = 8
	style.texture_margin_bottom = 8
	return style


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
