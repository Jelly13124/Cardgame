## Outpost (前哨站) building screen. Subclasses the shared building-screen shell
## and fills the content VBox with the Outpost's tier-gated functions:
##   T1  gold        — starting-gold Core upgrade (absorbs the old Command Center).
##   T1  discount    — in-run merchant-discount Core upgrade (absorbs Scrap Workshop).
##   T1  difficulty  — ascension selector (0..MetaProgress.max_ascension) for next run.
##   T2  safe_cells  — safe-cell Core upgrade (absorbs the old Blacksmith upgrade).
##   T3  deck_editor  — starter-deck editor (swap <=2 default cards for unlocked ones).
##
## Reads ONLY the shared MetaProgress building/upgrade API + RunManager; edits no
## shared file. NO class_name (ADR-0006) — instantiate via the base preload and
## subclass through the path string below.
##
## Wiring (F0d backends):
##   * difficulty: writes RunManager.pending_ascension; start_new_run reads it as the
##     next run's ascension when no explicit `asc` is passed.
##   * deck_editor: SAVE persists the edited deck (≤2 swaps) via
##     MetaProgress.set_starter_deck_override(hero_id, deck); start_new_run applies it.
extends "res://run_system/ui/buildings/building_screen_base.gd"

const CARD_DIR := "res://battle_scene/card_info/player/"
const UPGRADE_DIR := "res://run_system/data/base_upgrades/"
## Outpost Core-upgrade ids → the base-upgrade JSON that drives each row.
const GOLD_UPGRADE_ID := "command_center"
const DISCOUNT_UPGRADE_ID := "scrap_workshop"
const BACKPACK_UPGRADE_ID := "backpack"
const SAFE_CELLS_UPGRADE_ID := "blacksmith"
const REROLL_UPGRADE_ID := "reroll_tokens"
## Max cards swappable in the starter-deck editor (spec: <=2).
const MAX_DECK_SWAPS := 2

## Re-entrancy guard: the difficulty selector writes RunManager.ascension, which
## does not emit a signal, so we hold the chosen value here for the active session.
var _chosen_ascension: int = -1

## Starter-deck editor working state (in-memory only — see header note).
## `_deck_working` is the current edited deck (Array[String], default-length);
## `_deck_default` is the hero's untouched default for swap-count accounting.
var _deck_default: Array = []
var _deck_working: Array = []
## Index in `_deck_working` the player has selected to replace (-1 = none).
var _deck_selected_slot: int = -1
## True once the current working deck has been saved (clears on any further edit).
var _deck_saved: bool = false


## Fill the content area. Called once by the base `_build()`; rebuilt wholesale by
## `_refresh_content()` on building/currency change so tier gating stays live.
func _build_content(container: VBoxContainer) -> void:
	# Rebuild content whenever the building tier or any currency changes so newly
	# unlocked functions appear and lock messaging clears. The base already wires
	# these signals to its own `_refresh`; we add our own content rebuild.
	MetaProgress.buildings_changed.connect(_rebuild_content)
	MetaProgress.upgrades_changed.connect(_rebuild_content)
	MetaProgress.core_changed.connect(func(_v): _rebuild_content())
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

	# --- Core balance banner (shared currency context for every action). ---
	var bal := Label.new()
	_style_label(bal, 20, Color(0.64, 0.90, 1.0), 1)
	bal.text = tr("UI_OUTPOST_CORE_BALANCE").format({"n": MetaProgress.core})
	container.add_child(bal)
	container.add_child(HSeparator.new())

	if tier <= 0:
		var locked := Label.new()
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(locked, 20, Color(0.86, 0.62, 0.5), 1)
		locked.text = tr("UI_OUTPOST_LOCKED_BUILDING")
		container.add_child(locked)
		return

	# --- T1: starting gold (Core upgrade row). ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_GOLD"))
	_add_upgrade_row(container, GOLD_UPGRADE_ID)

	# --- T1: merchant discount (Core upgrade row). ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_DISCOUNT"))
	_add_upgrade_row(container, DISCOUNT_UPGRADE_ID)

	# --- T1: backpack capacity (Core upgrade row). Available at T1 alongside the
	# other basic Core upgrades; raises RunManager.effective_backpack_size() from
	# the base 10 toward the 20-cell ceiling. ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_BACKPACK"))
	_add_upgrade_row(container, BACKPACK_UPGRADE_ID)

	# --- T1: reward-screen card rerolls (Core upgrade row). ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_REROLL"))
	_add_upgrade_row(container, REROLL_UPGRADE_ID)

	# --- T1: difficulty selector. ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_DIFFICULTY"))
	_add_difficulty_selector(container)

	# --- T2: safe cells (Core upgrade row, gated). ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_SAFE_CELLS"))
	if MetaProgress.building_can(building_id, "safe_cells"):
		_add_upgrade_row(container, SAFE_CELLS_UPGRADE_ID)
	else:
		_add_lock_note(container, tr("UI_OUTPOST_LOCK_SAFE_CELLS"))

	# --- T3: starter-deck editor (gated). ---
	_add_section_header(container, tr("UI_OUTPOST_SECT_DECK"))
	if MetaProgress.building_can(building_id, "deck_editor"):
		_add_deck_editor(container)
	else:
		_add_lock_note(container, tr("UI_OUTPOST_LOCK_DECK"))


# --- Core upgrade rows (ported from upgrade_panel.gd) -----------------------


## A single Core upgrade row: title, level dots, next-tier effect, cost, BUY.
## Loads the base-upgrade JSON by id and drives BUY via MetaProgress.purchase_upgrade.
func _add_upgrade_row(container: VBoxContainer, upgrade_id: String) -> void:
	var def := _load_upgrade_def(upgrade_id)
	if def.is_empty():
		var err := Label.new()
		_style_label(err, 18, Color(0.86, 0.5, 0.5), 1)
		err.text = tr("UI_OUTPOST_UPGRADE_MISSING").format({"id": upgrade_id})
		container.add_child(err)
		return

	var tiers: Array = def.get("tiers", [])
	var lvl := MetaProgress.get_upgrade_level(upgrade_id)

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
		# purchase_upgrade emits core_changed + upgrades_changed → _rebuild_content.
		buy.pressed.connect(func(): MetaProgress.purchase_upgrade(upgrade_id, def))


# --- T1 difficulty selector -------------------------------------------------


## Ascension selector: a row of 0..MetaProgress.max_ascension buttons. Selecting a
## value sets RunManager.pending_ascension, which start_new_run reads as the next
## run's difficulty (it falls back to this when no explicit `asc` is passed).
func _add_difficulty_selector(container: VBoxContainer) -> void:
	var max_asc: int = int(MetaProgress.max_ascension)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(note, 16, Color(0.86, 0.78, 0.6), 1)
	note.text = tr("UI_OUTPOST_DIFFICULTY_NOTE")
	container.add_child(note)

	# Current effective selection: the session choice if made, else the pending
	# ascension (clamped to the unlocked range; -1 pending → default 0).
	var pending: int = int(RunManager.pending_ascension)
	var current: int = _chosen_ascension if _chosen_ascension >= 0 else maxi(pending, 0)
	current = clampi(current, 0, max_asc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	container.add_child(row)

	for a in range(max_asc + 1):
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(56, 40)
		btn.add_theme_font_size_override("font_size", 18)
		T.apply_button_theme(btn)
		btn.text = "A%d" % a
		btn.button_pressed = (a == current)
		var value := a
		btn.pressed.connect(func(): _on_difficulty_chosen(value))
		row.add_child(btn)

	var chosen_lbl := Label.new()
	_style_label(chosen_lbl, 17, Color(0.7, 0.92, 0.7), 1)
	chosen_lbl.text = tr("UI_OUTPOST_DIFFICULTY_CHOSEN").format({"n": current})
	container.add_child(chosen_lbl)


func _on_difficulty_chosen(value: int) -> void:
	_chosen_ascension = value
	# Persist the choice into RunManager.pending_ascension; start_new_run reads it
	# as the next run's difficulty. Clamp to the engine's accepted 0..5 range.
	RunManager.pending_ascension = clampi(value, 0, 5)
	_rebuild_content()


# --- T3 starter-deck editor (in-memory only) --------------------------------


## Starter-deck editor. Shows the active hero's default starter_deck as a list of
## slots; selecting a slot then an unlocked replacement performs an in-memory swap
## (capped at MAX_DECK_SWAPS). SAVE is disabled — persistence needs a new
## MetaProgress field (see header note). RESET reverts the working copy.
func _add_deck_editor(container: VBoxContainer) -> void:
	_ensure_deck_state()

	var hero_id: String = str(RunManager.current_hero_id)
	var hero_lbl := Label.new()
	_style_label(hero_lbl, 17, Color(0.86, 0.78, 0.6), 1)
	if hero_id == "":
		hero_lbl.text = tr("UI_OUTPOST_DECK_NO_HERO")
		container.add_child(hero_lbl)
		return
	hero_lbl.text = tr("UI_OUTPOST_DECK_HERO").format({"hero": _hero_display_name(hero_id)})
	container.add_child(hero_lbl)

	var swaps := _swap_count()
	var swaps_lbl := Label.new()
	_style_label(swaps_lbl, 16, Color(0.7, 0.9, 1.0), 1)
	swaps_lbl.text = tr("UI_OUTPOST_DECK_SWAPS").format({"cur": swaps, "max": MAX_DECK_SWAPS})
	container.add_child(swaps_lbl)

	# Current deck (selectable slots).
	var deck_lbl := Label.new()
	_style_label(deck_lbl, 17, Color(1, 0.92, 0.55), 1)
	deck_lbl.text = tr("UI_OUTPOST_DECK_CURRENT")
	container.add_child(deck_lbl)

	var deck_grid := GridContainer.new()
	deck_grid.columns = 3
	deck_grid.add_theme_constant_override("h_separation", 8)
	deck_grid.add_theme_constant_override("v_separation", 6)
	container.add_child(deck_grid)

	for i in range(_deck_working.size()):
		var card_id := str(_deck_working[i])
		var slot_btn := Button.new()
		slot_btn.toggle_mode = true
		slot_btn.custom_minimum_size = Vector2(180, 36)
		slot_btn.add_theme_font_size_override("font_size", 16)
		T.apply_button_theme(slot_btn)
		slot_btn.text = _card_display_name(card_id)
		slot_btn.button_pressed = (i == _deck_selected_slot)
		var idx := i
		slot_btn.pressed.connect(func(): _on_deck_slot_selected(idx))
		deck_grid.add_child(slot_btn)

	# Replacement pool (unlocked cards), shown only when a slot is selected.
	if _deck_selected_slot >= 0:
		var pool_lbl := Label.new()
		_style_label(pool_lbl, 17, Color(1, 0.92, 0.55), 1)
		pool_lbl.text = tr("UI_OUTPOST_DECK_REPLACE")
		container.add_child(pool_lbl)

		var pool_grid := GridContainer.new()
		pool_grid.columns = 3
		pool_grid.add_theme_constant_override("h_separation", 8)
		pool_grid.add_theme_constant_override("v_separation", 6)
		container.add_child(pool_grid)

		for card_id in MetaProgress.get_unlocked_card_pool():
			var cid := str(card_id)
			var pick := Button.new()
			pick.custom_minimum_size = Vector2(180, 34)
			pick.add_theme_font_size_override("font_size", 15)
			T.apply_button_theme(pick)
			pick.text = _card_display_name(cid)
			# Disallow a swap that would exceed the cap (unless this slot is already
			# a swapped slot being changed, which doesn't raise the count).
			pick.disabled = not _can_swap_slot_to(_deck_selected_slot, cid)
			pick.pressed.connect(func(): _on_replacement_chosen(cid))
			pool_grid.add_child(pick)

	# Controls: RESET (in-memory) + disabled SAVE with explanatory note.
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	container.add_child(controls)

	var reset_btn := Button.new()
	reset_btn.custom_minimum_size = Vector2(120, 38)
	reset_btn.add_theme_font_size_override("font_size", 17)
	T.apply_button_theme(reset_btn)
	reset_btn.text = tr("UI_OUTPOST_DECK_RESET")
	reset_btn.pressed.connect(_on_deck_reset)
	controls.add_child(reset_btn)

	var save_btn := Button.new()
	save_btn.custom_minimum_size = Vector2(120, 38)
	save_btn.add_theme_font_size_override("font_size", 17)
	T.apply_button_theme(save_btn)
	save_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	save_btn.text = tr("UI_OUTPOST_DECK_SAVE")
	# Persist the edited deck (≤2 swaps already enforced) onto this hero via
	# MetaProgress.set_starter_deck_override; start_new_run applies it.
	save_btn.pressed.connect(_on_deck_save.bind(hero_id))
	controls.add_child(save_btn)

	var save_note := Label.new()
	save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(save_note, 15, Color(0.7, 0.92, 0.7) if _deck_saved else Color(0.86, 0.78, 0.6), 1)
	save_note.text = tr("UI_OUTPOST_DECK_SAVED") if _deck_saved else tr("UI_OUTPOST_DECK_SAVE_HINT")
	container.add_child(save_note)


## Seed the working deck from the active hero's default the first time (or if the
## hero changed / state is empty). Idempotent for repeated rebuilds.
func _ensure_deck_state() -> void:
	var default_deck := _hero_default_deck()
	if _deck_default != default_deck:
		_deck_default = default_deck.duplicate()
		_deck_working = default_deck.duplicate()
		_deck_selected_slot = -1


## The active hero's default starter deck (Array[String]). Falls back to
## RunManager.DEFAULT_STARTER_DECK when no hero is loaded / the hero JSON omits it.
func _hero_default_deck() -> Array:
	var hero_id: String = str(RunManager.current_hero_id)
	if hero_id != "":
		var hero := _load_hero_def(hero_id)
		var sd: Variant = hero.get("starter_deck", [])
		if typeof(sd) == TYPE_ARRAY and not (sd as Array).is_empty():
			var out: Array = []
			for c in sd:
				out.append(str(c))
			return out
	var fallback: Array = []
	for c in RunManager.DEFAULT_STARTER_DECK:
		fallback.append(str(c))
	return fallback


## Number of slots whose card differs from the hero default (the swap count).
func _swap_count() -> int:
	var n := 0
	for i in range(_deck_working.size()):
		if i < _deck_default.size() and str(_deck_working[i]) != str(_deck_default[i]):
			n += 1
	return n


## True if setting slot `idx` to `card_id` is allowed under the swap cap. Changing
## a slot that is ALREADY swapped (back toward or to another non-default card) does
## not raise the count; changing a still-default slot must keep the count <= cap.
func _can_swap_slot_to(idx: int, card_id: String) -> bool:
	if idx < 0 or idx >= _deck_working.size():
		return false
	var slot_is_default := (
		idx < _deck_default.size() and str(_deck_working[idx]) == str(_deck_default[idx])
	)
	if not slot_is_default:
		return true  # already counts as a swap; replacing it doesn't add another
	return _swap_count() < MAX_DECK_SWAPS


func _on_deck_slot_selected(idx: int) -> void:
	_deck_selected_slot = -1 if idx == _deck_selected_slot else idx
	_rebuild_content()


func _on_replacement_chosen(card_id: String) -> void:
	if _deck_selected_slot < 0 or _deck_selected_slot >= _deck_working.size():
		return
	if not _can_swap_slot_to(_deck_selected_slot, card_id):
		return
	_deck_working[_deck_selected_slot] = card_id
	_deck_selected_slot = -1
	_deck_saved = false
	_rebuild_content()


func _on_deck_reset() -> void:
	_deck_working = _deck_default.duplicate()
	_deck_selected_slot = -1
	_deck_saved = false
	_rebuild_content()


## Persist the edited deck for `hero_id`. The editor already caps swaps at ≤2, so
## the working array is safe to hand straight to MetaProgress.set_starter_deck_override.
func _on_deck_save(hero_id: String) -> void:
	if hero_id == "":
		return
	MetaProgress.set_starter_deck_override(hero_id, _deck_working)
	_deck_saved = true
	_rebuild_content()


# --- Small UI + data helpers ------------------------------------------------


func _add_section_header(container: VBoxContainer, text: String) -> void:
	container.add_child(HSeparator.new())
	var lbl := Label.new()
	_style_label(lbl, 24, accent, 2)
	lbl.text = text
	container.add_child(lbl)


func _add_lock_note(container: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(lbl, 18, Color(0.78, 0.6, 0.5), 1)
	lbl.text = text
	container.add_child(lbl)


func _load_upgrade_def(id: String) -> Dictionary:
	return _load_json(UPGRADE_DIR + id + ".json")


func _load_hero_def(id: String) -> Dictionary:
	return _load_json("res://run_system/data/heroes/" + id + ".json")


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


func _card_display_name(card_id: String) -> String:
	var data := _load_json(CARD_DIR + card_id + ".json")
	return Settings.t("CARD_%s_NAME" % card_id, str(data.get("name", card_id)))


func _hero_display_name(hero_id: String) -> String:
	var data := _load_hero_def(hero_id)
	return Settings.t("HERO_%s_NAME" % hero_id, str(data.get("name", hero_id)))
