## Shared original PNG skin, palette and presentation helpers.
## All panel and button chrome resolves here so screens share fixed patch margins.
## Card fonts and illustrations have their own approved presentation contract.
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

# ─── Retained semantic palette used by existing information readouts ──────────
const GLASS_BG = Color(0.10, 0.075, 0.04, 0.96)  # panel / button surface
const GLASS_BG_TITLE = Color(0.13, 0.10, 0.055, 0.96)  # titlebar (a touch lighter)
const GLASS_BG_HOVER = Color(0.13, 0.098, 0.052, 0.96)  # ≈ surface ×1.3
const GLASS_BG_PRESSED = Color(0.07, 0.052, 0.028, 0.96)  # ≈ surface ×0.7
const GLASS_BG_DEEP = Color(0.06, 0.045, 0.025, 0.9)  # inset wells / empty equip slots
const GLASS_BG_CELL = Color(0.05, 0.038, 0.02, 0.9)  # empty backpack cells
const GLASS_BG_LOCKED = Color(0.035, 0.028, 0.016, 0.92)  # locked cells (near-black)
const GLASS_HAIRLINE = Color(0.34, 0.26, 0.15)  # the 1px border everywhere
const GLASS_HAIRLINE_DIM = Color(0.24, 0.18, 0.10)  # backpack cells / quiet edges
const GLASS_HAIRLINE_FAINT = Color(0.16, 0.12, 0.07)  # locked-cell border
const GLASS_GOLD = Color(0.78, 0.56, 0.22)  # accent stripe / hover border
const GLASS_GOLD_BRIGHT = Color(1.0, 0.81, 0.27)  # headline gold / hot hover

# ─── Text and information accents ───────────────────────────────────────────
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
const UI_ACCENT_BG = Color(0.42, 0.13, 0.08, 0.96)  # accent (START) warm dark-red glass
const UI_ACCENT_BG_HOVER = Color(0.52, 0.17, 0.10, 0.96)
const UI_ACCENT_BG_PRESSED = Color(0.30, 0.09, 0.055, 0.96)
const UI_ACCENT_RIM = GLASS_GOLD  # accent gold rim (1px hairline)
const UI_ACCENT_TEXT = Color("#ffe8c0")  # accent button label

# ─── Combat readouts and page scrims ──────────────────────────────────────────
const COMBAT_TRACK_BG = Color("#211611")
const INTENT_ATTACK_LOW = Color("#ffe5d4")
const INTENT_ATTACK_MEDIUM = Color("#ffc69e")
const INTENT_ATTACK_HIGH = Color("#ff9d83")
const ENERGY_EMPTY_TINT = Color(0.57, 0.63, 0.62)
const REWARD_SCRIM = Color(0.035, 0.037, 0.043, 0.92)
const RESULT_SCRIM = Color(0.024, 0.027, 0.032, 0.94)

# ─── Shared original UI kit ────────────────────────────────────────────────────
const KIT_DIR := "res://run_system/assets/images/ui/kit/"
const KIT_PATCH_MARGINS := {
	"panel_hard_9slice": Vector4(24, 24, 24, 24),
	"panel_soft_9slice": Vector4(24, 24, 24, 24),
	"button_primary_normal": Vector4(20, 16, 20, 16),
	"button_primary_hover": Vector4(20, 16, 20, 16),
	"button_primary_pressed": Vector4(20, 16, 20, 16),
	"button_primary_disabled": Vector4(20, 16, 20, 16),
	"button_secondary_normal": Vector4(20, 16, 20, 16),
	"button_secondary_hover": Vector4(20, 16, 20, 16),
	"button_secondary_pressed": Vector4(20, 16, 20, 16),
	"button_secondary_disabled": Vector4(20, 16, 20, 16),
	"tooltip_panel_9slice": Vector4(55, 43, 91, 32),
	"tooltip_shadow_9slice": Vector4(55, 43, 91, 32),
	"dropdown_9slice": Vector4(20, 16, 20, 16),
	"input_9slice": Vector4(20, 16, 20, 16),
	"divider": Vector4(8, 0, 8, 0),
}
const TOOLTIP_CONTENT_MARGINS := Vector4(22, 16, 45, 28)
const TOOLTIP_BASE_SIZE := Vector2(400, 118)
const TOOLTIP_FONT_SIZE := 22
const INPUT_INVALID_TINT := Color(1.0, 0.48, 0.40)
const SKIN_HOVER_TINT := Color(1.10, 1.10, 1.06)
const SKIN_SELECTED_TINT := Color(1.15, 1.08, 0.83)
const SKIN_PRESSED_TINT := Color(0.82, 0.84, 0.80)
const SKIN_LOCKED_TINT := Color(0.54, 0.58, 0.55, 0.92)
const SKIN_DISABLED_TINT := Color(0.58, 0.58, 0.58, 0.92)

static var _kit_textures: Dictionary = {}


## Mandatory original kit textures report a missing asset at the lookup boundary.
static func kit_tex(asset_name: String) -> Texture2D:
	if _kit_textures.has(asset_name):
		return _kit_textures[asset_name]
	var path := KIT_DIR + asset_name + ".png"
	if not ResourceLoader.exists(path):
		push_error("Missing shared UI skin: %s" % path)
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Invalid shared UI skin: %s" % path)
		return null
	_kit_textures[asset_name] = texture
	return texture


## Vector4 values are left, top, right, bottom. Texture patches stay centralized.
static func kit_box(
	asset_name: String, content_margins: Vector4 = Vector4.ZERO
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = kit_tex(asset_name)
	var patches: Vector4 = KIT_PATCH_MARGINS.get(asset_name, Vector4.ZERO)
	style.texture_margin_left = patches.x
	style.texture_margin_top = patches.y
	style.texture_margin_right = patches.z
	style.texture_margin_bottom = patches.w
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	return style


## Quiet panels carry selection/rarity state through a tint on the shared artwork.
static func state_box(
	state: String = "normal", content_margin: float = 6.0, tint: Color = Color.WHITE
) -> StyleBoxTexture:
	var style := kit_box("panel_hard_9slice", Vector4.ONE * content_margin)
	var state_tint := Color.WHITE
	match state:
		"hover":
			state_tint = SKIN_HOVER_TINT
		"selected", "filled":
			state_tint = SKIN_SELECTED_TINT
		"pressed":
			state_tint = SKIN_PRESSED_TINT
		"locked":
			state_tint = SKIN_LOCKED_TINT
		"disabled":
			state_tint = SKIN_DISABLED_TINT
	style.modulate_color = state_tint * tint
	return style


## Solid-color data marks and progress fills remain semantic shapes in one place.
static func semantic_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style


## Thin state borders leave the content beneath them unobscured.
static func semantic_outline(color: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := semantic_fill(Color.TRANSPARENT)
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


static func input_box(invalid: bool = false) -> StyleBoxTexture:
	var style := kit_box("input_9slice", Vector4(14, 8, 14, 8))
	if invalid:
		style.modulate_color = INPUT_INVALID_TINT
	return style


static func dropdown_box(state: String = "normal") -> StyleBoxTexture:
	var style := kit_box("dropdown_9slice", Vector4(14, 8, 34, 8))
	if state == "hover":
		style.modulate_color = SKIN_HOVER_TINT
	elif state == "pressed":
		style.modulate_color = SKIN_PRESSED_TINT
	elif state == "disabled":
		style.modulate_color = SKIN_DISABLED_TINT
	return style


static func apply_dropdown_theme(option: OptionButton) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		option.add_theme_stylebox_override(state, dropdown_box(state))
	option.add_theme_icon_override("arrow", kit_tex("dropdown_arrow"))
	option.add_theme_color_override("font_color", TEXT_MAIN)
	option.add_theme_color_override("font_hover_color", SAND_LIGHT)
	option.add_theme_color_override("font_pressed_color", SAND_LIGHT)
	var popup := option.get_popup()
	popup.add_theme_color_override("font_hover_color", LEATHER_DARK)
	var popup_styles := {
		"panel": kit_box("panel_hard_9slice"),
		"hover": kit_box("button_secondary_hover"),
	}
	for style_name in popup_styles:
		var previous := popup.get_theme_stylebox(style_name)
		var style: StyleBoxTexture = popup_styles[style_name]
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, previous.get_margin(side))
		popup.add_theme_stylebox_override(style_name, style)


static func checkbox_tex(checked: bool, disabled: bool = false) -> Texture2D:
	var asset_name := "checkbox_checked" if checked else "checkbox_unchecked"
	if disabled:
		asset_name += "_disabled"
	return kit_tex(asset_name)


static func apply_checkbox_theme(button: CheckBox) -> void:
	button.add_theme_icon_override("checked", checkbox_tex(true))
	button.add_theme_icon_override("unchecked", checkbox_tex(false))
	button.add_theme_icon_override("checked_disabled", checkbox_tex(true, true))
	button.add_theme_icon_override("unchecked_disabled", checkbox_tex(false, true))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var focus := semantic_outline(UI_HEADER_GOLD, 2, 4)
	button.add_theme_stylebox_override("focus", focus)


# ─── Compatible panel and button entry points ──────────────────────────────────
## Legacy color/radius arguments remain accepted while the artwork owns the skin.
static func panel_with_shadow(
	_bg: Color, _border: Color, _radius: int = 4, _border_width: int = 3
) -> StyleBoxTexture:
	return kit_box("panel_hard_9slice")


static func panel_flat(
	_bg: Color, _border: Color, _radius: int = 8, _border_width: int = 3
) -> StyleBoxTexture:
	return kit_box("panel_hard_9slice")


static func rounded_button(
	_bg: Color, _border: Color, _radius: int = 6, _border_width: int = 1
) -> StyleBoxTexture:
	return button_textured()


static func reward_row_style(_bg: Color, _border: Color) -> StyleBoxTexture:
	return kit_box("button_secondary_normal", Vector4(12, 8, 12, 8))


static func icon_frame_style() -> StyleBoxTexture:
	return state_box("normal", 3)


static func panel_textured(variant: String = "default") -> StyleBoxTexture:
	var asset_name := "panel_soft_9slice" if variant == "soft" else "panel_hard_9slice"
	return kit_box(asset_name, Vector4.ONE * 16)


static func button_textured(state: String = "normal") -> StyleBoxTexture:
	return ll_button_olive(state)


static func apply_button_theme(
	button: Button, _bg: Color = Color.WHITE, _border: Color = Color.WHITE, _radius: int = 4
) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, button_textured(state))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", SAND_LIGHT)
	button.add_theme_color_override("font_pressed_color", SAND_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
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


static func fade_in(control: Control, dur: float = 0.16) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, dur)


static func style_slider(slider: HSlider, accent: Color = Color(0.82, 0.58, 0.25)) -> void:
	slider.focus_mode = Control.FOCUS_NONE
	var track := semantic_fill(GLASS_BG_DEEP)
	track.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("slider", track)
	var fill := semantic_fill(accent)
	fill.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


# ─── Existing fonts and currency content ────────────────────────────────────────
const DISPLAY_FONT_SRC = preload("res://assets/fonts/Oswald.ttf")
const CJK_FALLBACK = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const COMBAT_FONT_SRC = preload("res://assets/fonts/Kreon-VariableFont_wght.ttf")


## A condensed Oswald FontVariation at the given weight (100–700). Apply with
## label.add_theme_font_override("font", T.display_font(600)). The wasteland HUD
## look comes from this + tight letter-spacing.
static func display_font(weight: int = 600) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = DISPLAY_FONT_SRC
	fv.variation_opentype = {"wght": weight}
	fv.fallbacks = [CJK_FALLBACK]
	return fv


## Serif combat readout inspired by Slay the Spire 2's compact numeric HUD.
## Kreon is bundled under the SIL Open Font License; Chinese still falls back
## to Noto so this can be safely used by mixed-language combat labels.
static func combat_font(weight: int = 700) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = COMBAT_FONT_SRC
	fv.variation_opentype = {"wght": weight}
	fv.fallbacks = [CJK_FALLBACK]
	return fv


## Apply the display font + size (+ optional letter spacing) to a Label in one call.
static func style_display(label: Label, size: int, weight: int = 600, spacing: int = 0) -> void:
	label.add_theme_font_override("font", display_font(weight))
	label.add_theme_font_size_override("font_size", size)
	if spacing != 0:
		label.add_theme_constant_override("font_spacing_glyph", spacing)


const _CURRENCY_ICON_DIR := "res://run_system/assets/images/home/currency/"

## Currency display fallback names (used only if the icon PNG is missing, so
## a regressed art pipeline never leaves the number without a unit).
const _CURRENCY_FALLBACK_NAME := {
	"caps": {"zh": "瓶盖", "en": "Caps"},
	"scrap": {"zh": "废料", "en": "Scrap"},
}


## Amount + currency ICON row: an HBoxContainer with a number Label followed by a
## small TextureRect icon (`home/currency/{currency}.png`; currency ∈ caps/scrap).
## Falls back to "<amount> <currency-word>" text if the icon PNG is
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


## Put a currency row in the visual centre of a Button.  This is the shared
## implementation for the compact price plaques in the accepted building
## concepts: no redundant "Buy" verb and no absolute right-edge badge.  Some
## concepts use icon -> amount (Clinic / Outpost), while the Market keeps the
## amount -> icon ordering shown on its merchandise cards.
static func centered_currency_button_content(
	button: Button,
	amount: int,
	currency: String,
	font_size: int = 18,
	icon_size: int = 20,
	icon_first: bool = true,
	separation: int = 4
) -> Control:
	var holder := CenterContainer.new()
	holder.name = "CenteredCurrencyContent"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := currency_row(amount, currency, font_size, icon_size)
	row.add_theme_constant_override("separation", separation)
	if icon_first:
		for child in row.get_children():
			if child is TextureRect:
				row.move_child(child, 0)
				break
	holder.add_child(row)
	button.add_child(holder)
	button.set_meta("concept_price_button", true)
	button.set_meta("currency_order", "icon_first" if icon_first else "amount_first")
	return holder


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


# ─── Shared window, selection and action hooks ─────────────────────────────────
static func close_x_button() -> Button:
	return ll_close_button(48.0)


static func ui_panel() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice")


static func ui_titlebar() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice", Vector4(12, 0, 8, 0))


static func ui_inset_panel() -> StyleBoxTexture:
	return state_box()


static func ui_slot_box(
	state: String = "empty", border_override: Color = Color(0, 0, 0, 0)
) -> StyleBoxTexture:
	var tint := border_override if border_override.a > 0.0 else Color.WHITE
	return state_box(state, 3, tint)


static func ui_nameplate_box() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice", Vector4(10, 3, 10, 3))


static func ui_header_label(text: String, size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	var fv := display_font(700)
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UI_HEADER_GOLD)
	return l


static func ui_bottom_bar() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice")


static func ui_button_brass(state: String = "normal") -> StyleBoxTexture:
	return kit_box("button_secondary_" + state, Vector4(16, 10, 16, 10))


static func ui_button_accent(state: String = "normal") -> StyleBoxTexture:
	return kit_box("button_primary_" + state)


static func ui_divider() -> Control:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_stylebox_override("panel", kit_box("divider"))
	return line


static func ll_panel() -> StyleBoxTexture:
	return ui_panel()


static func ll_titlebar() -> StyleBoxTexture:
	return ui_titlebar()


static func ll_section() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice")


static func ll_inset() -> StyleBoxTexture:
	return state_box()


static func ll_button(state: String = "normal") -> StyleBoxTexture:
	return kit_box("button_primary_" + state, Vector4(18, 10, 18, 12))


static func ll_button_olive(state: String = "normal") -> StyleBoxTexture:
	return kit_box("button_secondary_" + state, Vector4(18, 10, 18, 12))


static func ll_button_dark(state: String = "normal") -> StyleBoxTexture:
	return ll_button_olive(state)


static func concept_price_button(variant: String, state: String = "normal") -> StyleBoxTexture:
	var kind := "secondary" if variant == "olive" else "primary"
	return kit_box("button_%s_%s" % [kind, state], Vector4(14, 8, 14, 9))


static func apply_concept_price_button(button: Button, variant: String) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, concept_price_button(variant, state))


static func ll_charcoal_panel() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice", Vector4(16, 12, 16, 12))


static func ll_titleplate() -> StyleBoxTexture:
	return kit_box("panel_hard_9slice", Vector4(20, 6, 20, 6))


static func ll_close_button(px: float = 48.0) -> Button:
	var button := Button.new()
	button.text = "×"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(px, px)
	button.add_theme_font_override("font", display_font(600))
	button.add_theme_font_size_override("font_size", int(px * 0.45))
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, kit_box("button_secondary_" + state))
	return button


static func ll_slot(state: String = "normal") -> StyleBoxTexture:
	return state_box(state, 3)


static func ll_inset_thin() -> StyleBoxTexture:
	return state_box()


static func apply_choice_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, ll_button_olive(state))
	var focus := semantic_outline(UI_HEADER_GOLD, 2, 4)
	button.add_theme_stylebox_override("focus", focus)


# ─── Retained original icon sources ────────────────────────────────────────────
const UI_KIT_DIR := "res://run_system/assets/images/ui_kit/"
const LIGHTLINE_DIR := "res://run_system/assets/images/ui_kit_lightline/"
const INK_SET := "lw"
const CONCEPT_UI_DIR := "res://run_system/assets/images/ui/concept_dark_panel/"
static var _concept_tex_cache: Dictionary = {}


static func ui_kit_tex(kit_name: String) -> Texture2D:
	var path := UI_KIT_DIR + kit_name + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


static func lightline_tex(tex_name: String) -> Texture2D:
	var path := LIGHTLINE_DIR + tex_name + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


static func concept_tex(asset_name: String) -> Texture2D:
	if _concept_tex_cache.has(asset_name):
		return _concept_tex_cache[asset_name]
	var path := CONCEPT_UI_DIR + asset_name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res
	if tex == null:
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) == OK:
			tex = ImageTexture.create_from_image(image)
	if tex != null:
		_concept_tex_cache[asset_name] = tex
	return tex


## Existing chrome callers pass a shared textured fallback during migration.
static func lightline_box(
	_box_name: String, fallback: StyleBox, _mh: int = 24, _mv: int = -1
) -> StyleBoxTexture:
	if fallback is StyleBoxTexture:
		return fallback
	return kit_box("panel_hard_9slice")


static func concept_box(
	_asset_name: String,
	fallback: StyleBox,
	_margin_h: int = 0,
	_margin_v: int = -1,
	_content_margin: int = 0
) -> StyleBoxTexture:
	if fallback is StyleBoxTexture:
		return fallback
	return kit_box("panel_hard_9slice")
