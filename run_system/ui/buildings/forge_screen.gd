## Forge building screen 铁匠铺. Subclasses the shared building screen shell and
## overrides `_build_content()` to render Scrap-spending services over the
## permanent stash, gated by the Forge building tier via
## `MetaProgress.building_can("forge", fn)`:
##   - T1 dismantle — list each stash item with a Dismantle button.
##   - T2 reforge   — per-item Reforge (N Scrap) button (reroll one affix).
##   - T2 craft     — pick slot + rarity, spend Scrap, mint a new stash item.
##   - T3 curse     — per-item Curse (100 Scrap) button (reroll to cursed).
##
## NO class_name (ADR-0006). Loaded by path. Content is rebuilt on
## `scrap_changed` + `buildings_changed` (the base already wires those signals to
## its own `_refresh`, but `_refresh` only repaints the tier badge / action
## button — it does NOT re-run `_build_content`, so we rebuild the body here).
extends "res://run_system/ui/buildings/building_screen_base.gd"

## Affix roller for describe()/is_curse()/roll() (no class_name — preload per ADR-0006).
const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")

## Scrap cost to craft a fresh item, by target rarity (spec: 40/80/140).
const CRAFT_COST := {"common": 40, "uncommon": 80, "rare": 140}
## Scrap cost to curse an item. The actual spend is owned by the backend
## (MetaProgress.curse_stash_item / MetaProgress.CURSE_SCRAP_COST); this mirrors it
## for the button label + gating. (Autoload consts can't seed a GDScript const, so
## this is kept as a literal and must match MetaProgress.CURSE_SCRAP_COST.)
const CURSE_COST := 100
## Slot → a representative base equipment item_id used when crafting that slot.
## (Scanned from run_system/data/equipment/*.json; one base per slot.)
const CRAFT_BASE_BY_SLOT := {
	"head": "warden_helm",
	"chest": "warden_vest",
	"weapon": "warden_axe",
	"hands": "warden_gloves",
	"accessory": "warden_pendant",
}
const CRAFT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
const CRAFT_RARITIES := ["common", "uncommon", "rare"]

## The container the base hands us in `_build_content`; cached so we can rebuild
## the body on currency / building changes without re-running `_build`.
var _body: VBoxContainer
## Craft picker state (which slot / rarity the player has selected).
var _craft_slot: String = "head"
var _craft_rarity: String = "common"


func _build_content(container: VBoxContainer) -> void:
	_body = container
	# The base connects scrap_changed / buildings_changed to its `_refresh`
	# (badge + action button only). We add our own listeners to rebuild the body.
	MetaProgress.scrap_changed.connect(func(_v): _rebuild_body())
	MetaProgress.buildings_changed.connect(_rebuild_body)
	_rebuild_body()


## Rebuild the whole content body from the current building tier + stash state.
func _rebuild_body() -> void:
	if not is_instance_valid(_body):
		return
	for child in _body.get_children():
		child.queue_free()

	# Current Scrap balance.
	var scrap_lbl := Label.new()
	scrap_lbl.text = tr("UI_FORGE_SCRAP").format({"n": int(MetaProgress.scrap)})
	_style_label(scrap_lbl, 22, Color(0.78, 0.86, 0.62), 2)
	_body.add_child(scrap_lbl)

	var can_dismantle := MetaProgress.building_can("forge", "dismantle")
	var can_reforge := MetaProgress.building_can("forge", "reforge")
	var can_craft := MetaProgress.building_can("forge", "craft")
	var can_curse := MetaProgress.building_can("forge", "curse")

	# --- Craft control (T2) ---
	if can_craft:
		_body.add_child(_build_craft_control())
	else:
		_body.add_child(_locked_hint(tr("UI_FORGE_CRAFT_LOCKED")))

	_body.add_child(HSeparator.new())

	# --- Stash list (dismantle / reforge / curse per item) ---
	if MetaProgress.stash.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("UI_FORGE_EMPTY")
		_style_label(empty, 18, Color(0.8, 0.74, 0.6), 1)
		_body.add_child(empty)
	else:
		for i in range(MetaProgress.stash.size()):
			_body.add_child(_build_item_row(int(i), can_dismantle, can_reforge, can_curse))

	# Lock hints for functions above the current tier (only when not already shown).
	if not can_reforge:
		_body.add_child(_locked_hint(tr("UI_FORGE_REFORGE_LOCKED")))
	if not can_curse:
		_body.add_child(_locked_hint(tr("UI_FORGE_CURSE_LOCKED")))


## One stash row: name + rarity, affix lines (curses red), then the per-item
## action buttons that the current tier unlocks.
func _build_item_row(
	index: int, can_dismantle: bool, can_reforge: bool, can_curse: bool
) -> Control:
	var inst := RunManager.as_equip_instance(MetaProgress.stash[index])
	var base_id := str(inst.get("base", ""))
	var rarity := str(inst.get("rarity", "common"))
	var cursed := bool(inst.get("cursed", false))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = "%s [%s]" % [item_name, rarity.capitalize()]
	_style_label(name_lbl, 18, Color(1, 0.92, 0.55), 1)
	name_lbl.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_lbl)

	# Affixes; each as its own label so curses can be tinted red individually.
	var affix_box := HBoxContainer.new()
	affix_box.add_theme_constant_override("separation", 8)
	affix_box.custom_minimum_size = Vector2(280, 0)
	var affixes := RunManager.equip_affixes(inst)
	if affixes.is_empty():
		var none := Label.new()
		none.text = "—"
		_style_label(none, 16, Color(0.7, 0.7, 0.68), 1)
		affix_box.add_child(none)
	else:
		for affix in affixes:
			var a := affix as Dictionary
			var lbl := Label.new()
			lbl.text = AFFIX_POOL.describe(a)
			var is_curse := AFFIX_POOL.is_curse(a)
			_style_label(lbl, 16, Color(1.0, 0.42, 0.42) if is_curse else Color(0.7, 0.92, 0.7), 1)
			affix_box.add_child(lbl)
	row.add_child(affix_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Dismantle (T1).
	if can_dismantle:
		var dismantle_scrap := int(
			MetaProgress.DISMANTLE_SCRAP.get(rarity, MetaProgress.DISMANTLE_SCRAP["common"])
		)
		if cursed:
			dismantle_scrap += 5
		var dismantle_btn := Button.new()
		dismantle_btn.text = tr("UI_FORGE_DISMANTLE").format({"n": dismantle_scrap})
		dismantle_btn.custom_minimum_size = Vector2(150, 36)
		T.apply_button_theme(dismantle_btn)
		dismantle_btn.pressed.connect(func() -> void: MetaProgress.dismantle_stash_item(index))
		row.add_child(dismantle_btn)

	# Reforge (T2).
	if can_reforge:
		var reforge_cost := int(
			MetaProgress.REFORGE_COST.get(rarity, MetaProgress.REFORGE_COST["common"])
		)
		var reforge_btn := Button.new()
		reforge_btn.text = tr("UI_FORGE_REFORGE").format({"n": reforge_cost})
		reforge_btn.custom_minimum_size = Vector2(160, 36)
		T.apply_button_theme(reforge_btn)
		reforge_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
		reforge_btn.disabled = int(MetaProgress.scrap) < reforge_cost
		reforge_btn.pressed.connect(func() -> void: MetaProgress.reforge_stash_item(index))
		row.add_child(reforge_btn)

	# Curse (T3).
	if can_curse:
		var curse_btn := Button.new()
		curse_btn.text = tr("UI_FORGE_CURSE").format({"n": CURSE_COST})
		curse_btn.custom_minimum_size = Vector2(160, 36)
		T.apply_button_theme(curse_btn)
		curse_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
		# Disabled if too poor or the item is already cursed.
		curse_btn.disabled = int(MetaProgress.scrap) < CURSE_COST or cursed
		curse_btn.pressed.connect(func() -> void: _curse_item(index))
		row.add_child(curse_btn)

	return row


## Craft picker (T2): two option buttons (slot + rarity) and a Craft button whose
## label shows the current target's Scrap cost.
func _build_craft_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = tr("UI_FORGE_CRAFT_TITLE")
	_style_label(title, 20, Color(1, 0.92, 0.55), 2)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var slot_lbl := Label.new()
	slot_lbl.text = tr("UI_FORGE_SLOT")
	_style_label(slot_lbl, 16, Color(0.86, 0.86, 0.8), 1)
	row.add_child(slot_lbl)

	var slot_opt := OptionButton.new()
	slot_opt.custom_minimum_size = Vector2(160, 36)
	for s in CRAFT_SLOTS:
		slot_opt.add_item(tr("UI_FORGE_SLOT_%s" % s.to_upper()))
	slot_opt.selected = CRAFT_SLOTS.find(_craft_slot)
	slot_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_slot = str(CRAFT_SLOTS[idx])
			_rebuild_body()
	)
	row.add_child(slot_opt)

	var rarity_lbl := Label.new()
	rarity_lbl.text = tr("UI_FORGE_RARITY")
	_style_label(rarity_lbl, 16, Color(0.86, 0.86, 0.8), 1)
	row.add_child(rarity_lbl)

	var rarity_opt := OptionButton.new()
	rarity_opt.custom_minimum_size = Vector2(160, 36)
	for r in CRAFT_RARITIES:
		rarity_opt.add_item(tr("UI_FORGE_RARITY_%s" % r.to_upper()))
	rarity_opt.selected = CRAFT_RARITIES.find(_craft_rarity)
	rarity_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_rarity = str(CRAFT_RARITIES[idx])
			_rebuild_body()
	)
	row.add_child(rarity_opt)

	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var craft_btn := Button.new()
	craft_btn.text = tr("UI_FORGE_CRAFT").format({"n": cost})
	craft_btn.custom_minimum_size = Vector2(170, 36)
	T.apply_button_theme(craft_btn)
	craft_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.64, 0.50, 0.92))
	craft_btn.disabled = int(MetaProgress.scrap) < cost
	craft_btn.pressed.connect(_on_craft_pressed)
	row.add_child(craft_btn)

	return box


## Spend Scrap and mint a fresh stash item of the selected slot + rarity.
func _on_craft_pressed() -> void:
	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var base_id := str(CRAFT_BASE_BY_SLOT.get(_craft_slot, ""))
	if base_id == "":
		return
	if not MetaProgress.spend_scrap(cost):
		return
	var inst: Dictionary = RunManager.make_equip_instance(base_id, _craft_rarity)
	if inst.is_empty():
		return
	MetaProgress.add_to_stash(inst)
	# add_to_stash saves but emits no signal; spend_scrap already emitted
	# scrap_changed → _rebuild_body picks the new item up. Rebuild explicitly too
	# in case scrap was unchanged for any reason.
	_rebuild_body()


## Curse a stash item in place (T3) via the backend. MetaProgress.curse_stash_item
## handles the CURSE_SCRAP_COST spend, the cursed re-roll, the cursed flag, the save,
## and emits scrap_changed (→ _rebuild_body). Rebuild explicitly too in case the
## scrap math no-ops, so the new cursed affixes show immediately.
func _curse_item(index: int) -> void:
	if not MetaProgress.curse_stash_item(index):
		return
	_rebuild_body()


## A dim italic-ish lock hint line for a function above the current tier.
func _locked_hint(text: String) -> Control:
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = text
	_style_label(lbl, 16, Color(0.66, 0.62, 0.54), 1)
	return lbl
