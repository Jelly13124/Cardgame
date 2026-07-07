## Clinic (义体诊所) building screen. Spends Caps on cybernetic attribute perks
## (the ported Cyber Doctor model), and — at higher tiers — a Max-HP perk (T2)
## and a raised attribute level cap (T3).
##
## Tier-gated functions (MetaProgress.BUILDING_DEFS["clinic"].functions):
##   attr_perks (T1) · max_hp_perk (T2) · high_cap (T3).
##
## NO class_name (ADR-0006): subclasses the base screen via its resource path.
## Reads ONLY the shared MetaProgress building/caps-perk API; edits no shared file.
extends "res://run_system/ui/buildings/building_screen_base.gd"

## Max-HP perk (cyber_hp): +5 max HP per level. Cost/level is sourced from
## MetaProgress.caps_perk_cost(CYBER_HP_PERK); the +HP value is display-only here.
const MAX_HP_PER_LEVEL := 5
## Effective attribute level cap with clinic at T3 (spec: 3 → 5). Display-only here.
const HIGH_CAP_LEVEL := 5
## Legacy base-upgrade tracks (now Caps, like every base upgrade): the directory
## the JSON defs live in, plus the two upgrade ids. These are the classic stat
## upgrades — med_bay (+max HP at run start) and starter_boost (+starting
## attribute points) — driven exactly like the outpost's permanent upgrade rows.
const UPGRADE_DIR := "res://run_system/data/base_upgrades/"
const MED_BAY_UPGRADE_ID := "med_bay"
const STARTER_BOOST_UPGRADE_ID := "starter_boost"


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

	# Live Caps balance banner (services in the clinic spend Caps) — matches the
	# banner treatment on the other 4 screens (forge Scrap / outpost Caps).
	var banner := _styled_panel(true)
	var bm := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		bm.add_theme_constant_override(side, TOK_MARGIN_INNER)
	banner.add_child(bm)
	bm.add_child(T.currency_row(MetaProgress.caps, "caps", 20, 24))
	container.add_child(banner)

	# --- T1: attribute perks (Caps) ---
	container.add_child(_section_header(tr("UI_CLINIC_ATTR_TITLE")))
	if MetaProgress.building_can("clinic", "attr_perks"):
		var attr_group := VBoxContainer.new()
		attr_group.add_theme_constant_override("separation", TOK_ROW_SEP)
		container.add_child(attr_group)
		# Stable perk order so rows don't reshuffle between rebuilds.
		for perk_id in MetaProgress.CYBER_DOC_PERKS.keys():
			attr_group.add_child(_build_attr_perk_row(str(perk_id)))
	else:
		_add_locked_hint(container, tr("UI_CLINIC_LOCKED_ATTR"))

	# --- T2: Max-HP perk (Caps) ---
	container.add_child(_section_header(tr("UI_CLINIC_HP_TITLE")))
	if MetaProgress.building_can("clinic", "max_hp_perk"):
		container.add_child(_build_max_hp_row())
	else:
		_add_locked_hint(container, tr("UI_CLINIC_LOCKED_HP"))

	# --- T3: raised attribute level cap (display-only here) ---
	container.add_child(_section_header(tr("UI_CLINIC_CAP_TITLE")))
	var effective_cap := MetaProgress.attr_perk_cap()
	var cap_note := Label.new()
	cap_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if MetaProgress.building_can("clinic", "high_cap"):
		cap_note.text = tr("UI_CLINIC_CAP_HIGH").format({"cap": effective_cap})
	else:
		cap_note.text = (tr("UI_CLINIC_CAP_BASE").format(
			{"cap": effective_cap, "high": HIGH_CAP_LEVEL}
		))
	_style_label(cap_note, TOK_FONT_BODY, TOK_TEXT_DIM, 1)
	container.add_child(cap_note)


## Minimal JSON loader (mirrors the outpost screen). Returns {} when the file is
## absent or not a JSON object, so callers can render a missing-def fallback.
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Card-style perk row: [icon]  name + level pips ........... [ BUY  cost ] / MAX.
## Shared by the attribute perks and the Max-HP perk. `on_buy` runs on purchase.
func _perk_card(
	icon_path: String, name_text: String, lvl: int, max_lvl: int, cost: int, on_buy: Callable
) -> Control:
	var maxed := lvl >= max_lvl
	var card := _styled_panel(true)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(46, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = name_text
	_style_label(name_lbl, 21, Color(1, 0.92, 0.62), 2)
	info.add_child(name_lbl)

	var pips := ""
	for i in range(max_lvl):
		pips += "●" if i < lvl else "○"
	var pips_lbl := Label.new()
	pips_lbl.text = "%s   %d/%d" % [pips, lvl, max_lvl]
	_style_label(pips_lbl, 18, Color(0.60, 0.92, 1.0), 1)
	info.add_child(pips_lbl)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(176, 46)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", 19)
	T.apply_button_theme(buy)
	buy.add_theme_color_override("font_disabled_color", Color(0.70, 0.62, 0.50, 0.9))
	if maxed:
		buy.text = tr("UI_CLINIC_PERK_MAX")
		buy.disabled = true
	else:
		buy.text = tr("UI_CLINIC_BUY")
		buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
		buy.disabled = MetaProgress.caps < cost
		if not buy.disabled:
			buy.add_theme_color_override("font_color", Color(0.74, 1.0, 0.64))  # affordable
		buy.pressed.connect(on_buy)
		buy.add_child(T.overlay_cost_badge(cost, "caps", 17, 18, -8, -70))
	row.add_child(buy)

	return card


func _build_attr_perk_row(perk_id: String) -> Control:
	var attr: String = str(MetaProgress.CYBER_DOC_PERKS.get(perk_id, ""))
	return _perk_card(
		"res://battle_scene/assets/images/ui/attributes/%s.png" % attr,
		tr("UI_CLINIC_PERK_%s" % perk_id.to_upper()),
		MetaProgress.get_caps_perk_level(perk_id),
		MetaProgress.attr_perk_cap(),
		MetaProgress.caps_perk_cost(perk_id),
		func() -> void: MetaProgress.buy_caps_perk(perk_id)
	)


## Max-HP perk row (cyber_hp). Buys one level via MetaProgress.buy_caps_perk, which
## gates on the clinic's T2 max_hp_perk function and the shared attr_perk_cap().
func _build_max_hp_row() -> Control:
	var perk_id := MetaProgress.CYBER_HP_PERK
	return _perk_card(
		"res://battle_scene/assets/images/ui/attributes/constitution.png",
		tr("UI_CLINIC_HP_PERK").format({"hp": MAX_HP_PER_LEVEL}),
		MetaProgress.get_caps_perk_level(perk_id),
		MetaProgress.attr_perk_cap(),
		MetaProgress.caps_perk_cost(perk_id),
		func() -> void: MetaProgress.buy_caps_perk(perk_id)
	)


func _add_locked_hint(container: VBoxContainer, text: String) -> void:
	container.add_child(_body_label(text, true))
