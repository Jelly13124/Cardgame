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
## Legacy Core base-upgrade tracks surfaced in the clinic (Core, not Caps): the
## directory the JSON defs live in, plus the two upgrade ids to render. These are
## the classic stat upgrades — med_bay (+max HP at run start) and starter_boost
## (+starting attribute points) — driven exactly like the outpost's Core rows.
const UPGRADE_DIR := "res://run_system/data/base_upgrades/"
const MED_BAY_UPGRADE_ID := "med_bay"
const STARTER_BOOST_UPGRADE_ID := "starter_boost"


func _build_content(container: VBoxContainer) -> void:
	# Rebuild on the currency/building/perk signals so rows stay live.
	MetaProgress.caps_changed.connect(func(_v: int) -> void: _rebuild(container))
	MetaProgress.buildings_changed.connect(func() -> void: _rebuild(container))
	MetaProgress.upgrades_changed.connect(func() -> void: _rebuild(container))
	# Core upgrades (med_bay / starter_boost) spend Core; rebuild on core_changed too
	# so the Core balance label and Buy gating stay live after a purchase.
	MetaProgress.core_changed.connect(func(_v: int) -> void: _rebuild(container))
	_rebuild(container)


func _rebuild(container: VBoxContainer) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		child.queue_free()

	# Live Caps balance (services in the clinic spend Caps).
	var caps_lbl := Label.new()
	caps_lbl.text = tr("UI_CLINIC_CAPS").format({"n": MetaProgress.caps})
	_style_label(caps_lbl, 18, Color(1.0, 0.82, 0.45), 1)
	container.add_child(caps_lbl)

	container.add_child(HSeparator.new())

	# --- T1: attribute perks (Caps) ---
	_add_section_title(container, tr("UI_CLINIC_ATTR_TITLE"))
	if MetaProgress.building_can("clinic", "attr_perks"):
		# Stable perk order so rows don't reshuffle between rebuilds.
		for perk_id in MetaProgress.CYBER_DOC_PERKS.keys():
			container.add_child(_build_attr_perk_row(str(perk_id)))
	else:
		_add_locked_hint(container, tr("UI_CLINIC_LOCKED_ATTR"))

	container.add_child(HSeparator.new())

	# --- T2: Max-HP perk (Caps) ---
	_add_section_title(container, tr("UI_CLINIC_HP_TITLE"))
	if MetaProgress.building_can("clinic", "max_hp_perk"):
		container.add_child(_build_max_hp_row())
	else:
		_add_locked_hint(container, tr("UI_CLINIC_LOCKED_HP"))

	container.add_child(HSeparator.new())

	# --- T3: raised attribute level cap (display-only here) ---
	_add_section_title(container, tr("UI_CLINIC_CAP_TITLE"))
	var effective_cap := MetaProgress.attr_perk_cap()
	var cap_note := Label.new()
	cap_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if MetaProgress.building_can("clinic", "high_cap"):
		cap_note.text = tr("UI_CLINIC_CAP_HIGH").format({"cap": effective_cap})
	else:
		cap_note.text = (tr("UI_CLINIC_CAP_BASE").format(
			{"cap": effective_cap, "high": HIGH_CAP_LEVEL}
		))
	_style_label(cap_note, 16, Color(0.8, 0.74, 0.6), 1)
	container.add_child(cap_note)

	# --- Core Upgrades (legacy Core stat tracks) ---
	# Visible whenever the clinic is unlocked (tier >= 1). These spend Core (not
	# Caps) and are driven like the outpost's Core rows: load the base-upgrade JSON
	# def, show name / level / next-tier effect+cost, BUY → MetaProgress.purchase_upgrade.
	if MetaProgress.get_building_tier("clinic") >= 1:
		container.add_child(HSeparator.new())
		_add_section_title(container, tr("UI_CLINIC_CORE_TITLE"))

		# Core balance for this section (Core is a separate currency from Caps).
		var core_lbl := Label.new()
		core_lbl.text = tr("UI_CLINIC_CORE_BALANCE").format({"n": MetaProgress.core})
		_style_label(core_lbl, 18, Color(0.64, 0.90, 1.0), 1)
		container.add_child(core_lbl)

		_add_core_upgrade_row(container, MED_BAY_UPGRADE_ID)
		_add_core_upgrade_row(container, STARTER_BOOST_UPGRADE_ID)


## A single legacy Core upgrade row (med_bay / starter_boost). Ported from the
## outpost screen: loads the base-upgrade JSON by id and shows title, level dots,
## next-tier effect, cost, and a BUY button gated by MetaProgress.can_purchase and
## driven by MetaProgress.purchase_upgrade (which emits core_changed + upgrades_changed
## → _rebuild). Spends Core, not Caps.
func _add_core_upgrade_row(container: VBoxContainer, upgrade_id: String) -> void:
	var def: Dictionary = _load_json(UPGRADE_DIR + upgrade_id + ".json")
	if def.is_empty():
		var err := Label.new()
		_style_label(err, 18, Color(0.86, 0.5, 0.5), 1)
		err.text = tr("UI_CLINIC_CORE_MISSING").format({"id": upgrade_id})
		container.add_child(err)
		return

	var tiers: Array = def.get("tiers", [])
	var lvl: int = MetaProgress.get_upgrade_level(upgrade_id)

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	container.add_child(row)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	row.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	_style_label(title, 21, Color(1, 0.92, 0.55), 2)
	title.text = (
		Settings.t("UPGRADE_%s_NAME" % upgrade_id, str(def.get("name", upgrade_id))).to_upper()
	)
	vbox.add_child(title)

	var dots := ""
	for i in range(tiers.size()):
		dots += "●" if i < lvl else "○"
	var level_lbl := Label.new()
	_style_label(level_lbl, 18, Color(0.90, 0.90, 0.86), 1)
	level_lbl.text = tr("UI_HOME_UPGRADE_LEVEL").format(
		{"dots": dots, "cur": lvl, "max": tiers.size()}
	)
	vbox.add_child(level_lbl)

	var effect_lbl := Label.new()
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(effect_lbl, 17, Color(0.94, 0.90, 0.78), 1)
	vbox.add_child(effect_lbl)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom)

	var cost_lbl := Label.new()
	_style_label(cost_lbl, 18, Color(0.64, 0.90, 1.0), 1)
	bottom.add_child(cost_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(120, 36)
	T.apply_button_theme(buy)
	buy.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	bottom.add_child(buy)

	if lvl >= tiers.size():
		effect_lbl.text = tr("UI_HOME_UPGRADE_FULLY_UPGRADED")
		cost_lbl.text = ""
		buy.text = tr("UI_HOME_UPGRADE_MAXED")
		buy.disabled = true
	else:
		var next_tier: Dictionary = tiers[lvl]
		var effect_text := Settings.t(
			"UPGRADE_%s_TIER%d" % [upgrade_id, int(next_tier.get("level", lvl + 1))],
			str(next_tier.get("effect_text", ""))
		)
		effect_lbl.text = tr("UI_HOME_UPGRADE_NEXT").format({"text": effect_text})
		cost_lbl.text = tr("UI_HOME_UPGRADE_COST").format({"n": int(next_tier.get("cost", 0))})
		buy.text = tr("UI_HOME_UPGRADE_BUY")
		buy.disabled = not MetaProgress.can_purchase(upgrade_id, def)
		# purchase_upgrade emits core_changed + upgrades_changed → _rebuild.
		buy.pressed.connect(func() -> void: MetaProgress.purchase_upgrade(upgrade_id, def))


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


func _build_attr_perk_row(perk_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lvl := MetaProgress.get_caps_perk_level(perk_id)
	var max_lvl := MetaProgress.attr_perk_cap()
	var maxed := lvl >= max_lvl

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_CLINIC_PERK_%s" % perk_id.to_upper())
	_style_label(name_lbl, 18, Color(1, 0.92, 0.55), 1)
	name_lbl.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = tr("UI_CLINIC_PERK_LEVEL").format({"cur": lvl, "max": max_lvl})
	_style_label(lvl_lbl, 18, Color(0.90, 0.90, 0.86), 1)
	lvl_lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lvl_lbl)

	var cost := MetaProgress.caps_perk_cost(perk_id)
	var cost_lbl := Label.new()
	cost_lbl.text = "" if maxed else tr("UI_CLINIC_PERK_COST").format({"n": cost})
	_style_label(cost_lbl, 18, Color(1.0, 0.82, 0.45), 1)
	cost_lbl.custom_minimum_size = Vector2(150, 0)
	row.add_child(cost_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 36)
	T.apply_button_theme(buy_btn)
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	if maxed:
		buy_btn.text = tr("UI_CLINIC_PERK_MAX")
		buy_btn.disabled = true
	else:
		buy_btn.text = tr("UI_CLINIC_BUY")
		buy_btn.disabled = MetaProgress.caps < cost
		buy_btn.pressed.connect(func() -> void: MetaProgress.buy_caps_perk(perk_id))
	row.add_child(buy_btn)

	return row


## Max-HP perk row (cyber_hp). Buys one level via MetaProgress.buy_caps_perk, which
## gates on the clinic's T2 max_hp_perk function and the shared attr_perk_cap().
func _build_max_hp_row() -> Control:
	var perk_id := MetaProgress.CYBER_HP_PERK
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lvl := MetaProgress.get_caps_perk_level(perk_id)
	var max_lvl := MetaProgress.attr_perk_cap()
	var maxed := lvl >= max_lvl

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_CLINIC_HP_PERK").format({"hp": MAX_HP_PER_LEVEL})
	_style_label(name_lbl, 18, Color(1, 0.92, 0.55), 1)
	name_lbl.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = tr("UI_CLINIC_PERK_LEVEL").format({"cur": lvl, "max": max_lvl})
	_style_label(lvl_lbl, 18, Color(0.90, 0.90, 0.86), 1)
	lvl_lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lvl_lbl)

	var cost := MetaProgress.caps_perk_cost(perk_id)
	var cost_lbl := Label.new()
	cost_lbl.text = "" if maxed else tr("UI_CLINIC_PERK_COST").format({"n": cost})
	_style_label(cost_lbl, 18, Color(1.0, 0.82, 0.45), 1)
	cost_lbl.custom_minimum_size = Vector2(150, 0)
	row.add_child(cost_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 36)
	T.apply_button_theme(buy_btn)
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	if maxed:
		buy_btn.text = tr("UI_CLINIC_PERK_MAX")
		buy_btn.disabled = true
	else:
		buy_btn.text = tr("UI_CLINIC_BUY")
		buy_btn.disabled = MetaProgress.caps < cost
		buy_btn.pressed.connect(func() -> void: MetaProgress.buy_caps_perk(perk_id))
	row.add_child(buy_btn)

	return row


func _add_section_title(container: VBoxContainer, text: String) -> void:
	var title := Label.new()
	title.text = text.to_upper()
	_style_label(title, 20, Color(1, 0.92, 0.55), 2)
	container.add_child(title)


func _add_locked_hint(container: VBoxContainer, text: String) -> void:
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = text
	_style_label(hint, 16, Color(0.78, 0.66, 0.52), 1)
	container.add_child(hint)
