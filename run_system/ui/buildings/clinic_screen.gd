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

## Proposed Max-HP perk numbers (spec): +5 max HP per level, cost 200 + 150/level.
## NOTE: not yet wired into MetaProgress (see REPORT) — shown disabled for now.
const MAX_HP_PER_LEVEL := 5
const MAX_HP_BASE_COST := 200
const MAX_HP_COST_STEP := 150
## Effective attribute level cap with clinic at T3 (spec: 3 → 5). Display-only here.
const HIGH_CAP_LEVEL := 5


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
	var effective_cap := _effective_attr_cap()
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


## The currently effective attribute perk level cap. buy_caps_perk uses the const
## CAPS_PERK_MAX_LEVEL (3); the T3 high_cap raise is not yet enforced in
## MetaProgress (see REPORT), so this reports the const today.
func _effective_attr_cap() -> int:
	return MetaProgress.CAPS_PERK_MAX_LEVEL


func _build_attr_perk_row(perk_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lvl := MetaProgress.get_caps_perk_level(perk_id)
	var max_lvl := _effective_attr_cap()
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


## Max-HP perk row. NOTE: MetaProgress.buy_caps_perk only resolves CYBER_DOC_PERKS,
## so a "cyber_hp" perk currently can't be bought (no facility mapping, no run-start
## consumer). Until that's wired (see REPORT), this row is informational + disabled.
func _build_max_hp_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_CLINIC_HP_PERK").format({"hp": MAX_HP_PER_LEVEL})
	_style_label(name_lbl, 18, Color(1, 0.92, 0.55), 1)
	name_lbl.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_lbl)

	var cost := MAX_HP_BASE_COST
	var cost_lbl := Label.new()
	cost_lbl.text = tr("UI_CLINIC_PERK_COST").format({"n": cost})
	_style_label(cost_lbl, 18, Color(1.0, 0.82, 0.45), 1)
	cost_lbl.custom_minimum_size = Vector2(150, 0)
	row.add_child(cost_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Disabled "coming" — the perk needs a MetaProgress id + run-start consumer.
	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 36)
	T.apply_button_theme(buy_btn)
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	buy_btn.text = tr("UI_CLINIC_COMING")
	buy_btn.disabled = true
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
