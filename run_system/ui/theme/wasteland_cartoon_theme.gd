## Shared theming primitives for the Cute Wasteland Cartoon UI.
## Used by loot_reward, map_scene, battle_top_bar, and any future UI scene.
##
## Provides:
##   1. Shared color palette constants
##   2. StyleBoxFlat builders for the three common shapes used across the project:
##      - panel_with_shadow(): drop-shadowed panel (loot_reward backgrounds)
##      - panel_flat():        flat panel, no shadow (relic modal, battle top bar)
##      - rounded_button():    button-style box with optional shadow
##
## Per-scene compositions (e.g. wrapping panel_flat + extra margins for a relic
## panel) stay in the consuming scene — only the base shape lives here.
extends RefCounted
class_name WastelandCartoonTheme

# ─── Shared palette ───────────────────────────────────────────────────────────
const PANEL_BG          = Color(0.075, 0.055, 0.045, 0.96)
const PANEL_BG_DARK     = Color(0.045, 0.040, 0.035, 1.00)
const PANEL_BG_BANNER   = Color(0.105, 0.075, 0.055, 0.98)
const PANEL_BORDER      = Color(0.45,  0.32,  0.18,  1.00)
const PANEL_BORDER_WARM = Color(0.74,  0.52,  0.24,  0.92)
const PANEL_HIGHLIGHT   = Color(0.92,  0.66,  0.28,  1.00)
const ROW_BG            = Color(0.12,  0.09,  0.065, 0.98)
const ROW_HOVER_BG      = Color(0.18,  0.125, 0.075, 1.00)
const ROW_PRESSED_BG    = Color(0.23,  0.16,  0.08,  1.00)
const TEXT_MAIN         = Color(1.00,  0.86,  0.55,  1.00)
const TEXT_SECONDARY    = Color(0.72,  0.82,  0.82,  1.00)
const CYAN_EDGE         = Color(0.23,  0.78,  0.92,  1.00)
const SHADOW_COLOR      = Color(0.00,  0.00,  0.00,  0.42)

# ─── Builders ─────────────────────────────────────────────────────────────────

## Generic panel with drop shadow. Used by loot_reward backgrounds.
static func panel_with_shadow(bg: Color, border: Color, radius: int = 4, border_width: int = 3) -> StyleBoxFlat:
	var style = _base(bg, border, radius, border_width)
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = 8
	style.shadow_offset = Vector2(4, 4)
	return style

## Flat panel without shadow. Used by the relic modal and battle top bar.
static func panel_flat(bg: Color, border: Color, radius: int = 8, border_width: int = 3) -> StyleBoxFlat:
	return _base(bg, border, radius, border_width)

## Rounded button-shaped style. Optionally adds content margins for use as a panel.
static func rounded_button(bg: Color, border: Color, radius: int = 6, border_width: int = 1) -> StyleBoxFlat:
	return _base(bg, border, radius, border_width)

## Apply panel + hover + pressed stylebox triplet to a Button. Use for any
## button that wants the consistent Wasteland highlight on hover/press.
static func apply_button_theme(button: Button, bg: Color, border: Color, radius: int = 4) -> void:
	button.add_theme_stylebox_override("normal",  panel_with_shadow(bg, border, radius))
	button.add_theme_stylebox_override("hover",   panel_with_shadow(bg.lightened(0.12), CYAN_EDGE, radius))
	button.add_theme_stylebox_override("pressed", panel_with_shadow(bg.darkened(0.08),  PANEL_HIGHLIGHT, radius))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color(0.78, 0.96, 1.0, 1.0))

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
