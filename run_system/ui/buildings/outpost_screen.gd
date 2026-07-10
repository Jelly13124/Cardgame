## Outpost (前哨站) building screen, rebuilt to the 2026-07-07 "lightline"
## concept (docs/art/previews/base_building_outpost_ui_simple_comic_no_held_
## large_upgrades_20260707.png). The Outpost is the bounty centre + permanent-
## upgrade hub now:
##   LEFT (wide)   T1 bounties            — 可接悬赏: today's shelf as parchment
##                 wanted-poster cards (poster art placeholder + title +
##                 objective + REAL reward icons + orange 免费承接 button).
##                 Taking is FREE (MetaProgress.take_bounty — no Caps price, no
##                 daily-one-free limit). Held contracts show on the HOME
##                 bounty board, not here (no_held concept variant).
##   RIGHT top     T2 safe_cells          — 安全格: safe-crate illustration +
##                 cyan progress dots + orange Caps buy (the existing
##                 `blacksmith` base-upgrade backend).
##   RIGHT bottom  T3 permanent_upgrades  — 永久升级: 4 rows (起始金币 / 背包格数 /
##                 刷新代币 / 工具槽), each icon + name + dots + orange Caps buy
##                 via the existing MetaProgress.purchase_upgrade backend.
##
## REMOVED in this redesign: the starter-deck editor (deck_editor), the merchant
## discount row (scrap_workshop — old saves keep their levels passively), and
## the difficulty selector (difficulty lives on the home START cluster now).
##
## Every lightline PNG lookup falls back to a programmatic StyleBox / spacer so
## a missing Codex asset never crashes (warn-free placeholder rule). Reads ONLY
## the shared MetaProgress upgrade/bounty API; edits no shared file.
## NO class_name (ADR-0006) — instantiate via the base preload below.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const UPGRADE_DIR := "res://run_system/data/base_upgrades/"
## Outpost permanent-upgrade ids → the base-upgrade JSON that drives each row (Caps).
const GOLD_UPGRADE_ID := "command_center"
const BACKPACK_UPGRADE_ID := "backpack"
const SAFE_CELLS_UPGRADE_ID := "blacksmith"
const REROLL_UPGRADE_ID := "reroll_tokens"
const TOOL_SLOTS_UPGRADE_ID := "tool_slots"

## The T3 permanent-upgrade rows in concept order: upgrade id → lightline icon.
const PERMANENT_UPGRADE_ROWS := [
	{"id": GOLD_UPGRADE_ID, "icon": "icon_coin_gold"},
	{"id": BACKPACK_UPGRADE_ID, "icon": "icon_backpack"},
	{"id": REROLL_UPGRADE_ID, "icon": "icon_refresh"},
	{"id": TOOL_SLOTS_UPGRADE_ID, "icon": "icon_wrench"},
]

## Poster-card fixed width (concept: 4 upright parchment cards in a row).
const POSTER_CARD_WIDTH := 190.0
## Poster art placeholder height inside the card.
const POSTER_ART_HEIGHT := 150.0
## Progress-dot size (cyan filled / grey empty).
const DOT_SIZE := 18.0


## Fill the content area. Called once by the base `_build()`; rebuilt wholesale
## by `_rebuild_content()` on building/currency/bounty change so tier gating,
## affordability, and taken-states stay live.
func _build_content(container: VBoxContainer) -> void:
	# Roll today's shelf BEFORE connecting bounties_changed so a stale-date
	# reroll can't re-enter the rebuild mid-populate (same guard as the old
	# market screen; home base also refreshes on entry — this covers booting
	# straight into the outpost after midnight).
	MetaProgress.refresh_bounty_shelf_if_stale()

	MetaProgress.buildings_changed.connect(_rebuild_content)
	MetaProgress.upgrades_changed.connect(_rebuild_content)
	MetaProgress.caps_changed.connect(func(_v): _rebuild_content())
	# Taking a contract flips its poster button to 已承接 (and may grey the rest
	# at 3/3 held); settling one frees a board slot — both arrive here.
	MetaProgress.bounties_changed.connect(_rebuild_content)
	_populate(container)


## Tear down and repaint the content VBox from scratch.
func _rebuild_content() -> void:
	if not is_instance_valid(_content_box):
		return
	for child in _content_box.get_children():
		child.queue_free()
	_populate(_content_box)


func _populate(container: VBoxContainer) -> void:
	var tier := MetaProgress.get_building_tier(building_id)

	if tier <= 0:
		var locked := Label.new()
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(locked, 20, Color(0.86, 0.62, 0.5), 1)
		locked.text = tr("UI_OUTPOST_LOCKED_BUILDING")
		container.add_child(locked)
		return

	# Concept layout: LEFT wide bounty column + RIGHT column (safe cells over
	# permanent upgrades).
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(columns)

	# --- LEFT: 可接悬赏 (T1). ---
	var left := _lightline_section(tr("UI_OUTPOST_SECT_BOUNTIES"), "icon_poster")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.55
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	_fill_bounty_section(left.get_meta("body") as VBoxContainer)

	# --- RIGHT: 安全格 (T2) + 永久升级 (T3). ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns.add_child(right)

	var safe := _lightline_section(tr("UI_OUTPOST_SECT_SAFE_CELLS"), "icon_lock")
	right.add_child(safe)
	if MetaProgress.building_can(building_id, "safe_cells"):
		_fill_safe_cells(safe.get_meta("body") as VBoxContainer)
	else:
		_add_lock_note(safe.get_meta("body") as VBoxContainer, tr("UI_OUTPOST_LOCK_SAFE_CELLS"))

	var perm := _lightline_section(tr("UI_OUTPOST_SECT_UPGRADES"), "icon_uparrow")
	right.add_child(perm)
	if MetaProgress.building_can(building_id, "permanent_upgrades"):
		var body := perm.get_meta("body") as VBoxContainer
		for row_def in PERMANENT_UPGRADE_ROWS:
			_add_upgrade_row(body, str(row_def["id"]), str(row_def["icon"]))
	else:
		_add_lock_note(perm.get_meta("body") as VBoxContainer, tr("UI_OUTPOST_LOCK_UPGRADES"))


# --- 可接悬赏 (T1, free take) -------------------------------------------------


## The poster shelf: one parchment wanted-poster card per shelf contract.
## Taken contracts stay on the shelf greyed (已承接); at 3/3 held every open
## button disables with the 悬赏已满 tooltip. Held contracts + progress live on
## the HOME bounty board, not here.
func _fill_bounty_section(body: VBoxContainer) -> void:
	if MetaProgress.bounty_shelf.is_empty():
		body.add_child(_body_label(tr("UI_OUTPOST_BOUNTY_EMPTY"), true))
		return

	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", 12)
	shelf.add_theme_constant_override("v_separation", 12)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)
	for id in MetaProgress.bounty_shelf:
		shelf.add_child(_build_poster_card(str(id)))


## One wanted-poster card: card_poster frame, poster-art placeholder (named node
## per contract so Codex per-bounty art drops in later), translated title,
## objective line, REAL reward icon row, and the orange 免费承接 button.
func _build_poster_card(bounty_id: String) -> Control:
	var data: Dictionary = MetaProgress.get_bounty_data(bounty_id)
	var title := Settings.t("BOUNTY_%s_TITLE" % bounty_id, str(data.get("title", bounty_id)))
	var objective_v = data.get("objective", {})
	var objective: Dictionary = objective_v if typeof(objective_v) == TYPE_DICTIONARY else {}
	var reward_v = data.get("reward", {})
	var reward: Dictionary = reward_v if typeof(reward_v) == TYPE_DICTIONARY else {}

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(POSTER_CARD_WIDTH, 0)
	# poster_frame_blank = the CLEAN 9-slice parchment frame (2026-07-08 Codex
	# delivery). Its predecessor card_poster was a pre-composed poster whose
	# baked art frame + button plate ghosted behind the real children — never
	# use that one as a stylebox.
	card.add_theme_stylebox_override(
		"panel", T.lightline_box("poster_frame_blank", _poster_fallback_style(), 30)
	)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 12)
	card.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	m.add_child(col)

	# Poster art — the per-contract Codex illustration (2026-07-08 delivery);
	# a named node with the inset+icon placeholder while an id's art is absent.
	var art := PanelContainer.new()
	art.name = "PosterArt_%s" % bounty_id
	art.custom_minimum_size = Vector2(0, POSTER_ART_HEIGHT)
	var art_path := "res://run_system/assets/images/ui/bounty_posters/poster_art_%s.png" % bounty_id
	var art_tex: Texture2D = null
	if ResourceLoader.exists(art_path):
		art_tex = load(art_path) as Texture2D
	if art_tex != null:
		var pic := TextureRect.new()
		pic.texture = art_tex
		pic.custom_minimum_size = Vector2(0, POSTER_ART_HEIGHT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(pic)
	else:
		art.add_theme_stylebox_override("panel", T.ll_inset())
		var art_center := CenterContainer.new()
		art_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.add_child(art_center)
		art_center.add_child(_ll_icon("icon_poster", 84))
	col.add_child(art)

	# INK text — the card background is opaque parchment now, so poster copy
	# reads dark-on-light (the old light-on-dark colors washed out).
	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(0.18, 0.12, 0.07))
	col.add_child(name_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = _bounty_objective_text(objective)
	obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_lbl.add_theme_font_size_override("font_size", 14)
	obj_lbl.add_theme_color_override("font_color", Color(0.38, 0.29, 0.19))
	col.add_child(obj_lbl)

	col.add_child(_build_reward_row(reward))
	col.add_child(_build_take_button(bounty_id))
	return card


## The concept's reward strip: real currency icons (icon_caps / icon_scrap) with
## amounts, plus icon_armor + tier letter for an equipment reward.
func _build_reward_row(reward: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for cur in ["caps", "scrap"]:
		var amt := int(reward.get(cur, 0))
		if amt <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		chip.add_child(_ll_icon("icon_%s" % cur, 26))
		var amt_lbl := Label.new()
		amt_lbl.text = str(amt)
		# Ink on parchment (the poster card is opaque parchment now).
		amt_lbl.add_theme_font_size_override("font_size", 16)
		amt_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09))
		chip.add_child(amt_lbl)
		row.add_child(chip)
	var equip_tier := str(reward.get("equipment", ""))
	if equip_tier != "":
		var echip := HBoxContainer.new()
		echip.add_theme_constant_override("separation", 3)
		echip.add_child(_ll_icon("icon_armor", 26))
		var tier_lbl := Label.new()
		tier_lbl.text = equip_tier.substr(0, 1).to_upper()
		tier_lbl.tooltip_text = Settings.t("UI_BOUNTY_REWARD_EQUIP", "Equipment ({t})").format(
			{"t": equip_tier}
		)
		# Ink on parchment (the poster card is opaque parchment now).
		tier_lbl.add_theme_font_size_override("font_size", 16)
		tier_lbl.add_theme_color_override("font_color", Color(0.18, 0.26, 0.38))
		echip.add_child(tier_lbl)
		row.add_child(echip)
	return row


## The poster's action button. State matrix (in order):
##   held already          → disabled 已承接
##   board full (3/3 held) → disabled + 悬赏已满 tooltip
##   otherwise             → live orange 免费承接 → MetaProgress.take_bounty.
func _build_take_button(bounty_id: String) -> Button:
	var btn := _orange_button(tr("UI_OUTPOST_BOUNTY_TAKE"))
	if MetaProgress.is_bounty_active(bounty_id):
		btn.text = tr("UI_OUTPOST_BOUNTY_TAKEN")
		btn.disabled = true
	elif MetaProgress.active_bounties.size() >= MetaProgress.MAX_ACTIVE_BOUNTIES:
		btn.disabled = true
		btn.tooltip_text = tr("UI_OUTPOST_BOUNTY_FULL")
	else:
		btn.pressed.connect(_on_take_bounty.bind(bounty_id))
	return btn


func _on_take_bounty(bounty_id: String) -> void:
	if not MetaProgress.take_bounty(bounty_id):
		# Guards raced (e.g. board filled from another path) — no state change
		# means no rebuild fires, so just signal the miss.
		AudioManager.play_sfx("error")
		return
	AudioManager.play_sfx("purchase")
	# bounties_changed → _rebuild_content flips this poster to 已承接; the home
	# bounty board gains its progress row through the same signal.


## Human-readable objective line ("Play {n} attack cards"). Keys are the shared
## UI_BOUNTY_OBJ_* set (they live in ui_build_market.csv; tr()/Settings.t works
## globally), with a raw "type × n" fallback for an unmapped future type.
func _bounty_objective_text(objective: Dictionary) -> String:
	var type := str(objective.get("type", ""))
	var count := int(objective.get("count", 1))
	var text := Settings.t("UI_BOUNTY_OBJ_%s" % type.to_upper(), "%s × %d" % [type, count])
	return text.format({"n": count})


# --- 安全格 (T2, Caps — the `blacksmith` base-upgrade backend) ----------------


## The concept's safe-crate panel: crate illustration (card_device), the current
## effective cell count, cyan level dots, next-tier effect, and the orange Caps
## buy button. Backend unchanged: MetaProgress.purchase_upgrade("blacksmith").
func _fill_safe_cells(body: VBoxContainer) -> void:
	var def := _load_upgrade_def(SAFE_CELLS_UPGRADE_ID)
	if def.is_empty():
		body.add_child(
			_body_label(tr("UI_OUTPOST_UPGRADE_MISSING").format({"id": SAFE_CELLS_UPGRADE_ID}))
		)
		return
	var tiers: Array = def.get("tiers", [])
	var lvl := MetaProgress.get_upgrade_level(SAFE_CELLS_UPGRADE_ID)

	# Crate illustration (concept: armored safe crate, cyan-lit).
	var art_row := CenterContainer.new()
	var crate := T.lightline_tex("card_device")
	if crate != null:
		var rect := TextureRect.new()
		rect.texture = crate
		rect.custom_minimum_size = Vector2(150, 164)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_row.add_child(rect)
	else:
		art_row.add_child(_ll_icon("icon_device", 96))
	body.add_child(art_row)

	# Current effective safe cells (base + upgrade level).
	var now_lbl := Label.new()
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_lbl.text = tr("UI_OUTPOST_SAFE_CELLS_NOW").format({"n": MetaProgress.SAFE_CELLS_BASE + lvl})
	_style_label(now_lbl, 16, Color(0.62, 0.90, 0.94), 1)
	body.add_child(now_lbl)

	# Cyan progress dots.
	var dots_row := _dots_row(lvl, tiers.size())
	var dots_center := CenterContainer.new()
	dots_center.add_child(dots_row)
	body.add_child(dots_center)

	# Next effect + buy (or maxed).
	var effect_lbl := Label.new()
	effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(effect_lbl, 15, Color(0.94, 0.90, 0.78), 1)
	body.add_child(effect_lbl)

	if lvl >= tiers.size():
		# Maxed: the effect line already says it — a dead disabled button on top
		# of "已强化至满级" + full dots was three ways of saying the same thing.
		effect_lbl.text = tr("UI_HOME_UPGRADE_FULLY_UPGRADED")
		return

	var buy := _orange_button("")
	var next_tier: Dictionary = tiers[lvl]
	effect_lbl.text = tr("UI_HOME_UPGRADE_NEXT").format(
		{
			"text":
			Settings.t(
				"UPGRADE_%s_TIER%d" % [SAFE_CELLS_UPGRADE_ID, int(next_tier.get("level", lvl + 1))],
				str(next_tier.get("effect_text", ""))
			)
		}
	)
	buy.text = tr("UI_HOME_UPGRADE_BUY")
	buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	buy.add_child(T.overlay_cost_badge(int(next_tier.get("cost", 0)), "caps", 15, 16, -10, -70))
	buy.disabled = not MetaProgress.can_purchase(SAFE_CELLS_UPGRADE_ID, def)
	# purchase_upgrade emits caps_changed + upgrades_changed → _rebuild_content.
	buy.pressed.connect(func(): MetaProgress.purchase_upgrade(SAFE_CELLS_UPGRADE_ID, def))
	body.add_child(buy)


# --- 永久升级 (T3, Caps rows) --------------------------------------------------


## One concept upgrade row: lightline icon + name + cyan/grey level dots + the
## orange buy button with a Caps cost badge. Backend: MetaProgress.purchase_upgrade.
func _add_upgrade_row(container: VBoxContainer, upgrade_id: String, icon_name: String) -> void:
	var def := _load_upgrade_def(upgrade_id)
	if def.is_empty():
		container.add_child(
			_body_label(tr("UI_OUTPOST_UPGRADE_MISSING").format({"id": upgrade_id}))
		)
		return
	var tiers: Array = def.get("tiers", [])
	var lvl := MetaProgress.get_upgrade_level(upgrade_id)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.ll_inset())
	container.add_child(panel)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 10)
	for side in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(row)

	row.add_child(_ll_icon(icon_name, 34))

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	var name_lbl := Label.new()
	name_lbl.text = Settings.t("UPGRADE_%s_NAME" % upgrade_id, str(def.get("name", upgrade_id)))
	_style_label(name_lbl, 16, TOK_TEXT, 1)
	mid.add_child(name_lbl)
	mid.add_child(_dots_row(lvl, tiers.size()))

	if lvl >= tiers.size():
		var chip := _maxed_chip()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		return
	var buy := _orange_button("")
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)
	var next_tier: Dictionary = tiers[lvl]
	# Surface the next tier's effect as the row tooltip (the concept row has no
	# room for an effect line; hover reveals it).
	var effect_text := Settings.t(
		"UPGRADE_%s_TIER%d" % [upgrade_id, int(next_tier.get("level", lvl + 1))],
		str(next_tier.get("effect_text", ""))
	)
	panel.tooltip_text = tr("UI_HOME_UPGRADE_NEXT").format({"text": effect_text})
	buy.text = tr("UI_HOME_UPGRADE_BUY")
	buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	buy.add_child(T.overlay_cost_badge(int(next_tier.get("cost", 0)), "caps", 14, 15, -8, -62))
	buy.disabled = not MetaProgress.can_purchase(upgrade_id, def)
	# purchase_upgrade emits caps_changed + upgrades_changed → _rebuild_content.
	buy.pressed.connect(func(): MetaProgress.purchase_upgrade(upgrade_id, def))


# --- Small UI + data helpers ------------------------------------------------


## A lightline-framed titled section: ll_section panel + a header row (small
## lightline icon + gold title) over a content VBox stored on the "body" meta.
func _lightline_section(title: String, icon_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", T.ll_section())

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, TOK_MARGIN_OUTER)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", TOK_ROW_SEP)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	header.add_child(_ll_icon(icon_name, 28))
	var lbl := Label.new()
	lbl.text = title
	_style_label(lbl, TOK_FONT_SECTION, TOK_GOLD, 2)
	header.add_child(lbl)

	panel.set_meta("body", body)
	return panel


## The concept's cyan/grey progress dots: `cur` filled (icon_dot_cyan) out of
## `total`. Empty dots reuse the cyan PNG desaturated dark; a missing PNG falls
## back to text dots so the row never renders blank.
func _dots_row(cur: int, total: int) -> Control:
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


## Quiet non-interactive MAX chip — replaces the disabled buy button at cap
## (a dead orange button reads as broken; this stays calm and readable).
func _maxed_chip() -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", T.ll_slot("locked"))
	chip.custom_minimum_size = Vector2(92, 40)
	var center := CenterContainer.new()
	chip.add_child(center)
	var lbl := Label.new()
	lbl.text = tr("UI_HOME_UPGRADE_MAXED")
	_style_label(lbl, 15, Color(0.72, 0.62, 0.42), 1)
	center.add_child(lbl)
	return chip


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


## Parchment-toned fallback for the poster card while card_poster.png is absent.
func _poster_fallback_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.62, 0.44, 0.16)
	style.border_color = Color(0.62, 0.52, 0.34, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(TOK_RADIUS)
	return style


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


func _load_upgrade_def(id: String) -> Dictionary:
	return _load_json(UPGRADE_DIR + id + ".json")


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
