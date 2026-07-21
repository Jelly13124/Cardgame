## Clinic (义体诊所) building content, matched to the accepted 2026-07-13
## top-bar concept. BuildingScreenBase owns the shared top bar; this script only
## builds the service area below it:
##   MAIN (wide)   T1 attr_perks        — five attribute rows, each a lightline
##                 bar: framed attr icon + bare attribute name + level dots
##                 (orange filled / dark empty / faint beyond the current cap)
##                 + the orange Caps buy button.
##   RIGHT top     T2 max_hp_perk       — 生命上限 card: cyan heart icon + cyan
##                 level dots + the orange Caps buy (cyber_hp backend).
##   RIGHT bottom  T3 high_cap          — binary 强化上限 unlock. There is no
##                 progress track: before T3 it reads "T3 解锁"; at T3 it reads
##                 "强化上限 5 / 已解锁". The actual cap remains single-sourced
##                 from MetaProgress.attr_perk_cap().
##
## VISUAL REBUILD ONLY — the backend is untouched: MetaProgress.buy_caps_perk /
## caps_perk_cost / attr_perk_cap / get_caps_perk_level, rebuilt live on the
## caps/buildings/upgrades signals exactly as before.
##
## Every lightline PNG lookup falls back to a programmatic StyleBox / spacer /
## legacy attribute PNG so a missing Codex asset never crashes (warn-free
## placeholder rule).
##
## NO class_name (ADR-0006): subclasses the base screen via its resource path.
## Reads ONLY the shared MetaProgress building/caps-perk API; edits no shared file.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const CLINIC_NPC_PATH := "res://run_system/assets/images/ui/clinic/npc_cyber_doctor.png"

## Max-HP perk (cyber_hp): +5 max HP per level. Cost/level is sourced from
## MetaProgress.caps_perk_cost(CYBER_HP_PERK); the +HP value is display-only here.
const MAX_HP_PER_LEVEL := 5
## Effective attribute level cap with clinic at T3 (spec: 3 → 5). This remains
## the total dot count for purchasable perk rows; the separate cap-unlock card
## deliberately has no dots because the tier unlock is binary.
const HIGH_CAP_LEVEL := 5

## Lightline icon per base attribute (concept row order = CYBER_DOC_PERKS order).
## Missing PNGs fall back to the legacy attribute icons, then to a spacer.
const ATTR_LL_ICONS := {
	"strength": "icon_fist",
	"constitution": "icon_torso",
	"intelligence": "icon_brain",
	"luck": "icon_clover",
	"charm": "icon_star",
}
## Legacy attribute icon dir (pre-lightline art) — fallback for ATTR_LL_ICONS.
const LEGACY_ATTR_ICON_DIR := "res://battle_scene/assets/images/ui/attributes/"

## Level-dot diameter (attr rows + right-column cards).
const DOT_SIZE := 18.0
## Concept dot colors: orange filled (attr rows), cyan handled by icon_dot_cyan.
const DOT_FILL := Color(0.95, 0.62, 0.16)
const DOT_EMPTY_BG := Color(0.13, 0.12, 0.10)
const DOT_RING := Color(0.42, 0.38, 0.28)
## Keeps the two right-hand concept cards close to the bottom edge at 1080p;
## smaller windows remain safe because BuildingScreenBase owns the ScrollContainer.
const CONTENT_MIN_HEIGHT := 710.0
const NPC_STAGE_WIDTH := 440.0


func _build_content(container: VBoxContainer) -> void:
	# Rebuild on the currency/building/perk signals so rows stay live.
	MetaProgress.caps_changed.connect(func(_v: int) -> void: _rebuild(container))
	MetaProgress.buildings_changed.connect(func() -> void: _rebuild(container))
	MetaProgress.upgrades_changed.connect(func() -> void: _rebuild(container))
	_rebuild(container)


func _rebuild(container: VBoxContainer) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		child.queue_free()

	# Accepted concept layout: robot doctor | five attribute rows | two cards.
	# The doctor is frameless scene dressing; every actual purchase remains a
	# normal button in the centre/right service columns.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.custom_minimum_size = Vector2(0, CONTENT_MIN_HEIGHT)
	container.add_child(columns)

	# --- LEFT: approved cyber-doctor character art. ---
	var npc := _build_npc_art_stage(
		CLINIC_NPC_PATH,
		"ClinicCyberDoctor",
		Vector2(NPC_STAGE_WIDTH, CONTENT_MIN_HEIGHT),
		"icon_heart",
	)
	npc.size_flags_horizontal = Control.SIZE_FILL
	columns.add_child(npc)

	# --- CENTRE: T1 attribute perk rows (Caps). ---
	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", TOK_ROW_SEP)
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.size_flags_stretch_ratio = 1.75
	columns.add_child(main_col)
	if MetaProgress.building_can("clinic", "attr_perks"):
		# Stable perk order so rows don't reshuffle between rebuilds.
		for perk_id in MetaProgress.CYBER_DOC_PERKS.keys():
			main_col.add_child(_build_attr_perk_row(str(perk_id)))
	else:
		_add_lock_note(main_col, tr("UI_CLINIC_LOCKED_ATTR"))

	# --- RIGHT: 生命上限 (T2) card over 强化上限 (T3) card. ---
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 16)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0
	columns.add_child(right_col)
	right_col.add_child(_build_vitals_card())
	right_col.add_child(_build_cap_card())


# --- T1: attribute perk rows ---------------------------------------------------


## One concept attribute row: [framed attr icon] [name] .. [dots] .. [orange buy].
## Backend unchanged: get_caps_perk_level / attr_perk_cap / caps_perk_cost /
## buy_caps_perk (caps_changed then triggers the rebuild that repaints levels).
func _build_attr_perk_row(perk_id: String) -> Control:
	var attr: String = str(MetaProgress.CYBER_DOC_PERKS.get(perk_id, ""))
	var lvl := MetaProgress.get_caps_perk_level(perk_id)
	var cap := MetaProgress.attr_perk_cap()
	var cost := MetaProgress.caps_perk_cost(perk_id)

	var panel := PanelContainer.new()
	panel.name = "ClinicAttribute_%s" % attr
	# ll_inset ships a 28px content margin on every side (9-slice default); at
	# five rows that overflows the scroll viewport and clips the 魅力 row. The
	# ink border itself is thin — 10px vertical padding clears it fine.
	var row_box := T.ll_inset()
	row_box.content_margin_top = 10.0
	row_box.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", row_box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	# Full perk name + level on hover (the concept row only shows the bare
	# attribute name, so the descriptive copy moves to the tooltip).
	panel.tooltip_text = (
		"%s — %s"
		% [
			tr("UI_CLINIC_PERK_%s" % perk_id.to_upper()),
			tr("UI_CLINIC_PERK_LEVEL").format({"cur": lvl, "max": cap}),
		]
	)

	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 12)
	for side in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(row)

	# Framed icon plate (concept: the icon sits in its own bordered square).
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", T.ll_slot("normal"))
	plate.custom_minimum_size = Vector2(56, 56)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plate_center := CenterContainer.new()
	plate.add_child(plate_center)
	plate_center.add_child(_attr_icon(attr, 40))
	row.add_child(plate)

	# Bare attribute name (concept) — shared UI_COMBAT_ATTR_* keys (力量/体质/…).
	var name_lbl := Label.new()
	name_lbl.text = tr("UI_COMBAT_ATTR_%s" % attr.to_upper())
	_style_label(name_lbl, 21, Color(0.97, 0.93, 0.84), 1)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_lbl)

	var pre_spacer := Control.new()
	pre_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pre_spacer)

	var dots := _perk_dots(lvl, cap)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dots)

	var post_spacer := Control.new()
	post_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(post_spacer)

	row.add_child(_buy_button(lvl, cap, cost, func() -> void: MetaProgress.buy_caps_perk(perk_id)))
	return panel


# --- T2: 生命上限 (Max-HP perk, cyber_hp) ---------------------------------------


## The concept's right-column vitals card: title, cyan heart, level dots, orange
## Caps buy. Backend unchanged: MetaProgress.buy_caps_perk(CYBER_HP_PERK), gated
## on the clinic's T2 max_hp_perk function inside buy_caps_perk itself.
func _build_vitals_card() -> Control:
	var card := _ll_card(tr("UI_CLINIC_VITALS_TITLE"))
	card.name = "ClinicVitalsCard"
	var body := card.get_meta("body") as VBoxContainer

	var icon_center := CenterContainer.new()
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_center.add_child(_ll_icon("icon_heart", 60))
	body.add_child(icon_center)

	if not MetaProgress.building_can("clinic", "max_hp_perk"):
		_add_lock_note(body, tr("UI_CLINIC_LOCKED_HP"))
		return card

	var perk_id := MetaProgress.CYBER_HP_PERK
	var lvl := MetaProgress.get_caps_perk_level(perk_id)
	var cap := MetaProgress.attr_perk_cap()

	var dots_center := CenterContainer.new()
	dots_center.add_child(_cyan_dots(lvl, HIGH_CAP_LEVEL, cap))
	body.add_child(dots_center)

	var note := Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("UI_CLINIC_HP_PERK").format({"hp": MAX_HP_PER_LEVEL})
	_style_label(note, TOK_FONT_DIM, TOK_TEXT_DIM, 1)
	body.add_child(note)

	body.add_child(
		_buy_button(
			lvl,
			cap,
			MetaProgress.caps_perk_cost(perk_id),
			func() -> void: MetaProgress.buy_caps_perk(perk_id),
			Vector2(184, 65)
		)
	)
	return card


# --- T3: 强化上限 (binary, display-only) -----------------------------------------


## The cap raise IS the clinic's T3 tier, so this card has no buy action and no
## point track. It is intentionally binary: locked below T3, then cap 5 unlocked.
func _build_cap_card() -> Control:
	var card := _ll_card(tr("UI_CLINIC_CAP_TITLE"))
	card.name = "ClinicCapCard"
	var body := card.get_meta("body") as VBoxContainer

	var icon_center := CenterContainer.new()
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_center.add_child(_ll_icon("icon_uparrow", 56))
	body.add_child(icon_center)

	if MetaProgress.building_can("clinic", "high_cap"):
		var value_lbl := Label.new()
		value_lbl.text = "%s %d" % [tr("UI_CLINIC_CAP_TITLE"), HIGH_CAP_LEVEL]
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(value_lbl, 22, Color(0.36, 0.86, 0.91), 2)
		body.add_child(value_lbl)

		var unlocked_lbl := Label.new()
		unlocked_lbl.text = tr("UI_CLINIC_CAP_UNLOCKED")
		unlocked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(unlocked_lbl, TOK_FONT_BODY, TOK_TEXT, 1)
		body.add_child(unlocked_lbl)
	else:
		var lock_row := HBoxContainer.new()
		lock_row.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_row.add_theme_constant_override("separation", 8)
		lock_row.add_child(_ll_icon("icon_lock", 28))
		var locked_lbl := Label.new()
		locked_lbl.text = tr("UI_CLINIC_CAP_T3_UNLOCK")
		_style_label(locked_lbl, TOK_FONT_BODY, TOK_TEXT_DIM, 1)
		lock_row.add_child(locked_lbl)
		body.add_child(lock_row)
	return card


# --- Small UI helpers (lightline, PNG-optional) --------------------------------


## The orange lightline price plaque shared by every purchasable in this screen:
## a quiet MAX chip at the cap, otherwise centered Caps icon -> amount with no
## redundant 购买 verb, disabled while Caps are short. `on_buy` is the backend.
func _buy_button(
	lvl: int,
	max_lvl: int,
	cost: int,
	on_buy: Callable,
	plaque_size: Vector2 = Vector2(146, 60)
) -> Control:
	if lvl >= max_lvl:
		# A dead disabled button at the cap reads as broken; a calm chip doesn't.
		var chip := _maxed_chip(plaque_size)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return chip
	var buy := _orange_button("")
	T.apply_concept_price_button(buy, "orange")
	buy.custom_minimum_size = plaque_size
	buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = MetaProgress.caps < cost
	buy.pressed.connect(on_buy)
	T.centered_currency_button_content(buy, cost, "caps", 23, 29, true, 8)
	return buy


## Quiet non-interactive MAX chip — same width as the buy button so attribute
## rows don't shift when a stat caps out.
func _maxed_chip(plaque_size: Vector2 = Vector2(146, 60)) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", T.ll_slot("locked"))
	chip.custom_minimum_size = plaque_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var center := CenterContainer.new()
	chip.add_child(center)
	var lbl := Label.new()
	lbl.text = tr("UI_CLINIC_PERK_MAX")
	_style_label(lbl, 15, Color(0.72, 0.62, 0.42), 1)
	center.add_child(lbl)
	return chip


## A lightline-framed titled card (right column): ll_section panel + centered
## gold title over a content VBox stored on the "body" meta.
func _ll_card(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", T.ll_section())

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TOK_MARGIN_OUTER)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", TOK_ROW_SEP)
	margin.add_child(body)

	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(lbl, TOK_FONT_SECTION, TOK_GOLD, 2)
	body.add_child(lbl)

	panel.set_meta("body", body)
	return panel


## The concept attr-row dots: HIGH_CAP_LEVEL circles — orange filled up to `lvl`,
## dark ring while within the current cap, extra-faint beyond it (sells the T3
## cap raise). Programmatic circles (StyleBoxFlat), so no PNG dependency.
func _perk_dots(lvl: int, cap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in range(HIGH_CAP_LEVEL):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(DOT_SIZE / 2.0))
		if i < lvl:
			sb.bg_color = DOT_FILL
		else:
			sb.bg_color = DOT_EMPTY_BG
			sb.border_color = DOT_RING
			sb.set_border_width_all(1)
			if i >= cap:
				sb.bg_color = Color(DOT_EMPTY_BG, 0.45)
				sb.border_color = Color(DOT_RING, 0.35)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
	return row


## The concept right-column dots: `total` dots, cyan-filled up to `cur`
## (icon_dot_cyan), grey-dimmed empties, extra-faint beyond `cap`. Falls back to
## text dots when the PNG is absent so the row never renders blank.
func _cyan_dots(cur: int, total: int, cap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var dot_tex := T.lightline_tex("icon_dot_cyan")
	if dot_tex == null:
		var lbl := Label.new()
		var dots := ""
		for i in range(total):
			dots += "●" if i < cur else "○"
		lbl.text = dots
		_style_label(lbl, 16, Color(0.55, 0.88, 0.92), 1)
		row.add_child(lbl)
		return row
	for i in range(total):
		var dot := TextureRect.new()
		dot.texture = dot_tex
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i >= cur:
			dot.modulate = Color(0.42, 0.42, 0.42, 0.85)
		if i >= cap:
			dot.modulate = Color(0.30, 0.30, 0.30, 0.45)
		row.add_child(dot)
	return row


## An orange lightline primary button (concept's main action button).
func _orange_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	btn.add_theme_color_override("font_hover_color", Color(0.20, 0.13, 0.05))
	btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	# Disabled = clearly darker plate + light text (dark-on-dim was unreadable).
	btn.add_theme_color_override("font_disabled_color", Color(0.88, 0.82, 0.68, 0.95))
	btn.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.72, 0.35))
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_stylebox_override("normal", T.ll_button("normal"))
	btn.add_theme_stylebox_override("hover", T.ll_button("hover"))
	btn.add_theme_stylebox_override("pressed", T.ll_button("pressed"))
	var disabled_box := T.ll_button("normal")
	if disabled_box is StyleBoxTexture:
		(disabled_box as StyleBoxTexture).modulate_color = Color(0.42, 0.42, 0.42)
	btn.add_theme_stylebox_override("disabled", disabled_box)
	return btn


## Attribute icon with a lightline → legacy-PNG → spacer fallback chain.
func _attr_icon(attr: String, px: float) -> Control:
	var tex := T.lightline_tex(str(ATTR_LL_ICONS.get(attr, "")))
	if tex == null:
		var legacy_path := "%s%s.png" % [LEGACY_ATTR_ICON_DIR, attr]
		if ResourceLoader.exists(legacy_path):
			tex = load(legacy_path) as Texture2D
	if tex == null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(px, px)
		return spacer
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A lightline PNG as a fixed-size TextureRect, or an equal-size empty spacer
## when the art is undelivered (warn-free placeholder).
func _ll_icon(icon_name: String, px: float) -> Control:
	var tex := T.lightline_tex(icon_name)
	if tex == null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(px, px)
		return spacer
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _add_lock_note(container: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_ll_icon("icon_lock", 26))
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(lbl, 17, Color(0.78, 0.6, 0.5), 1)
	lbl.text = text
	row.add_child(lbl)
	container.add_child(row)
