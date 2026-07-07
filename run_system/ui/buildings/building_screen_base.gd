## Reusable full-rect overlay screen for ONE base building. Configured with a
## `building_id` (one of MetaProgress.BUILDING_DEFS). Renders a layered detail page:
## an icon + name + flavour header, a prominent ACTION CARD (unlock/upgrade with its
## effect, cost, and — when locked — a preview of what the building does so a locked
## page still sells its value), and a scrollable `content` VBox that subclasses fill
## via `_build_content()`.
##
## NO class_name (ADR-0006: preload these instead). Instantiate with `.new()`,
## set `building_id`, then add as a child — `_ready()` builds the UI.
extends Control

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

## Which building this screen represents. Set before adding the node to the tree.
var building_id: String = ""

## Callback the host (home base) sets so the back button can close the overlay.
## When unset, the screen frees itself.
var on_close: Callable = Callable()

## Per-building accent color (header tint), mirrors the selector tile accent.
var accent: Color = Color(0.86, 0.78, 0.52)

var _tier_badge: Label
var _content_box: VBoxContainer
## Amount+icon currency chip (T.currency_row) in the header's right column. Shows
## the currency the building's NEXT action spends (Scrap while locked → unlock,
## Caps once unlocked → tier-up), via MetaProgress.building_cost_currency.
var _cost_row: HBoxContainer
## The row's amount Label — cached for cheap live updates.
var _cost_amount_lbl: Label
## The header's right VBox — kept so the cost chip can be rebuilt when the cost
## CURRENCY flips (locked→unlocked changes scrap→caps, so the icon must change).
var _header_right_box: VBoxContainer

## Per-building header art (the same home-base runtime sprites).
const _ICON_DIR := "res://run_system/assets/images/home/buildings_runtime/"
## Placeholder per-building background path (Codex art swaps these in later).
const _BG_DIR := "res://run_system/assets/images/buildings/"

# ─── Phase B: shared visual tokens ──────────────────────────────────────────
# One set of colors/sizes so all 5 building screens (forge/outpost/clinic/
# market/warehouse) read as ONE UI instead of five hand-tuned ones. Screens
# should pull from these + the `_section_header` / `_styled_panel` / `_row_panel`
# helpers below rather than inventing their own Color(...)/font-size literals.
# Reuses `wasteland_theme` colors where they already exist (T.TEXT_MAIN etc.);
# these tokens are the subset that shows up over and over in building content.

## Panel fills (dark → panel, matches T.PANEL_BG_DARK / T.PANEL_BG).
const TOK_PANEL_BG := Color(0.11, 0.08, 0.06, 0.92)
const TOK_PANEL_BG_DARK := Color(0.075, 0.055, 0.040, 0.94)
## Hairline separators / faint dividers between rows.
const TOK_LINE := Color(0.34, 0.28, 0.20, 0.85)
## The warm gold accent used for section headers + emphasis (matches the header
## title's default `accent`-adjacent look across screens).
const TOK_GOLD := Color(1.0, 0.86, 0.40)
## Body / dim text.
const TOK_TEXT := Color(0.92, 0.88, 0.76)
const TOK_TEXT_DIM := Color(0.74, 0.68, 0.56)

## Font sizes: title (building name, handled by header) / section / body / dim.
const TOK_FONT_SECTION := 21
const TOK_FONT_BODY := 17
const TOK_FONT_DIM := 14

## Shared corner radius + margins so every panel/row matches.
const TOK_RADIUS := 6
const TOK_MARGIN_OUTER := 14
const TOK_MARGIN_INNER := 10
## Standard vertical gap between rows inside a section list.
const TOK_ROW_SEP := 10


func _ready() -> void:
	# STOP so this full-rect overlay blocks the home base behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	T.fade_in(self)  # soft entrance instead of a hard pop-in
	MetaProgress.buildings_changed.connect(_refresh)
	MetaProgress.caps_changed.connect(func(_v): _refresh())
	MetaProgress.scrap_changed.connect(func(_v): _refresh())


## ESC backs out of this building detail page first (same effect as the ✕ close
## button — reuses `_close()`, so the existing X-button behavior is untouched).
## Consumes the event so the base overview's own ESC→Settings handler doesn't
## also fire this same frame.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("ui_back")
		_close()


func _build() -> void:
	# Full-screen, merchant-style framing: a per-building (or fallback) background,
	# a dark readability shade, then a large centered framed panel.
	_add_scene_background()

	# Near-fullscreen framed board: fill the viewport (minus a small frame margin) so
	# big grids — a 40-slot stash, the market shelf — have real room instead of being
	# crammed into a small centered card.
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(side, 40)
	add_child(outer)

	# The big framed board. Accent tints the border so each building reads distinct.
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var border := accent
	border.a = 1.0
	board.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.055, 0.045, 0.038, 0.96), border, 6, 3)
	)
	outer.add_child(board)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 34)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	board.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# --- Header band: building icon + name/flavour, then tier + cost chip + close ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	vbox.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := "%s%s.png" % [_ICON_DIR, building_id]
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon_frame.add_child(icon)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 3)
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_box)
	var name_lbl := Label.new()
	name_lbl.text = tr("UI_BUILD_%s_NAME" % building_id.to_upper())
	_style_label(name_lbl, 40, accent, 3)
	title_box.add_child(name_lbl)
	var flavour_lbl := Label.new()
	flavour_lbl.text = _flavour_text()
	flavour_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavour_lbl.custom_minimum_size = Vector2(560, 0)
	_style_label(flavour_lbl, 17, Color(0.82, 0.76, 0.62), 1)
	title_box.add_child(flavour_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var right_box := VBoxContainer.new()
	right_box.alignment = BoxContainer.ALIGNMENT_CENTER
	right_box.add_theme_constant_override("separation", 6)
	header.add_child(right_box)
	_header_right_box = right_box
	_tier_badge = Label.new()
	_tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_tier_badge, 24, Color(0.90, 0.90, 0.86), 2)
	right_box.add_child(_tier_badge)
	_rebuild_cost_row()

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(56, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Note: the unlock/upgrade action card moved to the base overview (a button under
	# each building's floating label). The detail page is services-only now.

	# --- Scrollable content area: subclasses populate this; base shows placeholder.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 384)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Inner margin so content doesn't crowd the frame edge / scrollbar.
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 6)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_margin)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_content_box)

	# --- Bottom bar: prominent LEAVE / back button (bottom-right).
	vbox.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	var foot_spacer := Control.new()
	foot_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(foot_spacer)
	var leave_btn := Button.new()
	leave_btn.text = tr("UI_BUILD_LEAVE")
	leave_btn.custom_minimum_size = Vector2(200, 48)
	leave_btn.add_theme_font_size_override("font_size", 20)
	T.apply_button_theme(leave_btn)
	leave_btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_back"))
	leave_btn.pressed.connect(_close)
	footer.add_child(leave_btn)

	_build_content(_content_box)
	_refresh()


## Full-rect background: a per-building placeholder image if Codex has delivered
## one, else a dark ColorRect tinted toward `accent`. Always topped with a dark
## shade for label readability (mirrors home_base / shop framing).
func _add_scene_background() -> void:
	var bg_path := "%s%s_bg.png" % [_BG_DIR, building_id]
	if ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.texture = load(bg_path)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		# Dark base tinted a touch toward the building accent so the 5 screens
		# feel distinct even without final art.
		var tint := accent
		var bg := ColorRect.new()
		bg.color = Color(tint.r * 0.10 + 0.02, tint.g * 0.10 + 0.02, tint.b * 0.10 + 0.02, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


## Extension point. Subclasses override to fill the content VBox with their
## tier-gated functions. The base implementation shows a placeholder label.
func _build_content(container: VBoxContainer) -> void:
	var placeholder := Label.new()
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.text = tr("UI_BUILD_COMING")
	_style_label(placeholder, 20, Color(0.8, 0.74, 0.6), 1)
	container.add_child(placeholder)


# --- Per-building copy (translation-driven; subclasses may override) ---------


## One-line tagline shown under the building name. CSV: UI_BUILD_<ID>_FLAVOUR.
func _flavour_text() -> String:
	return tr("UI_BUILD_%s_FLAVOUR" % building_id.to_upper())


# --- State refresh ----------------------------------------------------------


## (Re)build the header cost chip: the currency the building's next action spends
## (Scrap while locked, Caps once unlocked) with the matching live balance. Called
## on build + whenever a currency/building signal fires (the currency can flip when
## the building unlocks, so the whole row — icon included — is rebuilt).
func _rebuild_cost_row() -> void:
	if not is_instance_valid(_header_right_box):
		return
	if is_instance_valid(_cost_row):
		_cost_row.queue_free()
	var currency := MetaProgress.building_cost_currency(building_id)
	var balance: int = MetaProgress.scrap if currency == "scrap" else MetaProgress.caps
	_cost_row = T.currency_row(balance, currency, 22, 24)
	_cost_row.alignment = BoxContainer.ALIGNMENT_END
	_header_right_box.add_child(_cost_row)
	_cost_amount_lbl = _cost_row.get_meta("amount_label") as Label
	if is_instance_valid(_cost_amount_lbl):
		_cost_amount_lbl.add_theme_color_override("font_color", Color(0.90, 0.86, 0.64))


## Update the tier badge, cost chip, and action card to the current building state.
## Safe to call repeatedly (wired to buildings/currency change signals).
func _refresh() -> void:
	_rebuild_cost_row()
	var tier := MetaProgress.get_building_tier(building_id)
	if is_instance_valid(_tier_badge):
		_tier_badge.text = tr("UI_BUILD_LOCKED") if tier <= 0 else "T%d" % tier


func _close() -> void:
	if on_close.is_valid():
		on_close.call()
	else:
		queue_free()


func _style_label(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	label.add_theme_constant_override("outline_size", outline_size)


# ─── Phase B: shared building-content helpers ───────────────────────────────
# Subclasses call these instead of hand-rolling PanelContainer/Label boilerplate
# so the 5 screens share one visual language. Keep DRY: if a screen needs a
# variant, extend the helper rather than forking a parallel styling path.


## A section header for a block of content: a hairline rule, then a gold,
## uppercased title. Use to open every logical group (a workbench, a shop
## shelf, an upgrade category) so the 5 screens share one section rhythm.
func _section_header(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = text.to_upper()
	_style_label(lbl, TOK_FONT_SECTION, TOK_GOLD, 2)
	box.add_child(lbl)
	return box


## A consistent StyleBox'd panel for a content block (a card, a shop shelf, a
## workbench column). `dark` picks the darker recessed fill (nested panels /
## drop targets); otherwise the standard panel fill. Wrap the returned
## PanelContainer's single child in a MarginContainer for inner padding, or use
## `_row_panel()` below when the content is a simple list row.
func _styled_panel(dark: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = TOK_PANEL_BG_DARK if dark else TOK_PANEL_BG
	style.border_color = TOK_LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOK_RADIUS)
	style.content_margin_left = TOK_MARGIN_INNER
	style.content_margin_right = TOK_MARGIN_INNER
	style.content_margin_top = TOK_MARGIN_INNER
	style.content_margin_bottom = TOK_MARGIN_INNER
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A single list row (an upgrade row, a stash line, a shop entry): a styled
## panel pre-wired with an inner MarginContainer + HBoxContainer so callers
## just `row.add_child(...)` their label/price/button in a horizontal line.
## Returns the HBoxContainer — the caller adds THAT row's content, then adds
## the owning panel (`row.get_meta("_panel")`) to its own parent container.
func _row_panel() -> HBoxContainer:
	var panel := _styled_panel(false)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TOK_MARGIN_INNER)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Stash the owning panel so a caller that needs the panel itself (e.g. to set
	# custom_minimum_size or swap the stylebox) can fetch it back.
	row.set_meta("_panel", panel)
	margin.add_child(row)
	return row


## Apply the shared body/dim text styling in one call — thin wrapper over
## `_style_label` with the Phase-B body-text token, so callers don't need to
## remember the exact color/size for "ordinary paragraph text".
func _body_label(text: String, dim: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(lbl, TOK_FONT_DIM if dim else TOK_FONT_BODY, TOK_TEXT_DIM if dim else TOK_TEXT, 1)
	return lbl
