## ForgeWindow — the Forge building as a floating DraggableWindow, rebuilt to
## match the 2026-07-07 "lightline" concept art (olive-brass metal frame + orange
## primary buttons; see docs/art/previews/base_building_forge_ui_*_20260707.png).
##
## Four icon tabs (concept left→right order): 铁砧 anvil = 拆解 Dismantle · 盾 shield =
## 打造 Craft · 齿轮 gear = 重铸 Reforge · 袋 bag = 诅咒 Curse — each gated by the forge
## tier via `MetaProgress.building_can("forge", fn)` (locked tabs render dimmed +
## 🔒). The body is two columns: LEFT = blacksmith NPC portrait placeholder
## (ForgeNpcPortrait) + anvil illustration (ForgeAnvilArt) — Codex art drops into
## those named nodes later; RIGHT = per-tab content.
##
## DISMANTLE (the redesigned tab): a drop slot up top (drag a stash item onto it →
## single dismantle via MetaProgress.dismantle_stash_item, accepts THIS window's
## own stash payload AND the base-mode CharacterWindow stash so the Diablo-style
## side-by-side windows drag across) + a "全部分解" section header + four bulk
## buttons 普通/罕见/稀有/所有物品. Each bulk button = dismantle EVERY stash item of
## that rarity via MetaProgress.dismantle_stash_by_rarity (set + cursed gear is
## PROTECTED — never bulk-dismantled) behind a confirm dialog showing count + scrap.
##
## CRAFT / REFORGE / CURSE keep their existing unchanged MetaProgress backends
## (make_equip_instance + add_to_stash / reforge_stash_item_locked /
## curse_stash_item) — only the layout is re-skinned to the concept row vocabulary.
##
## Rebuilds on scrap_changed / buildings_changed; frees on close. NO class_name
## (ADR-0006) — loaded by path. Every lightline PNG lookup falls back to a
## programmatic StyleBox (T.ll_*) so a missing Codex asset never crashes.
extends "res://run_system/ui/window/draggable_window.gd"

const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
const EQUIP_TOOLTIP = preload("res://run_system/ui/equip_tooltip.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")

# 920: the dismantle tab (drop slot + bulk column + stash strip) needs the
# room; the draggable_window viewport cap + content scroll absorb anything
# beyond the screen (2026-07-08 overflow fix).
const WIN_SIZE := Vector2(560, 920)
const GRID_CELL_SIZE := Vector2(56, 56)
const BENCH_CELL_SIZE := Vector2(84, 84)

## Scrap cost to craft a fresh item, by target rarity (spec: 40/80/140).
const CRAFT_COST := {"common": 40, "uncommon": 80, "rare": 140}
## Mirrors MetaProgress.CURSE_SCRAP_COST for the button label + gating (an autoload
## const can't seed a GDScript const, so this stays a literal).
const CURSE_COST := 100
## Slot → a representative base equipment item_id used when crafting that slot.
const CRAFT_BASE_BY_SLOT := {
	"head": "warden_helm",
	"chest": "warden_vest",
	"weapon": "warden_axe",
	"hands": "warden_gloves",
	"accessory": "warden_pendant",
}
const CRAFT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
const CRAFT_RARITIES := ["common", "uncommon", "rare"]

## Tabs in the concept's visual left→right order; each id doubles as its
## `building_can("forge", …)` function name.
const TABS := ["dismantle", "craft", "reforge", "curse"]
const TAB_LABEL_KEYS := {
	"dismantle": "UI_FORGE_TAB_DISMANTLE",
	"craft": "UI_FORGE_TAB_CRAFT",
	"reforge": "UI_FORGE_TAB_REFORGE",
	"curse": "UI_FORGE_TAB_CURSE",
}
## Lightline tab-icon piece per tab (matches the concept tab-strip left→right:
## anvil / shield / GEAR / bag — the concept's 3rd tab glyph is a gear, not a hammer).
const TAB_ICONS := {
	"dismantle": "icon_anvil",
	"craft": "icon_shield",
	"reforge": "icon_gear",
	"curse": "icon_bag",
}
## Lock-hint key per tier-gated tab (dismantle is T1 = always available, no hint).
const TAB_LOCK_KEYS := {
	"craft": "UI_FORGE_CRAFT_LOCKED",
	"reforge": "UI_FORGE_REFORGE_LOCKED",
	"curse": "UI_FORGE_CURSE_LOCKED",
}

## The four bulk-dismantle buttons: rarity filter ("" = all) + label key + row icon.
const BULK_BUTTONS := [
	{"rarity": "common", "key": "UI_FORGE_BULK_COMMON", "icon": "icon_hammer"},
	{"rarity": "uncommon", "key": "UI_FORGE_BULK_UNCOMMON", "icon": "icon_anvil"},
	{"rarity": "rare", "key": "UI_FORGE_BULK_RARE", "icon": "icon_star"},
	{"rarity": "", "key": "UI_FORGE_BULK_ALL", "icon": "icon_shield"},
]

## The selected tab (one of TABS); forced back to the first unlocked tab if the
## current one is tier-locked.
var _tab: String = "dismantle"
## Craft picker state.
var _craft_slot: String = "head"
var _craft_rarity: String = "common"
## Index into MetaProgress.stash of the item on the bench (-1 = none).
var _selected_index: int = -1
## Which affix ROW is picked for reforge (-1 = none). Forced to the locked affix
## index once the item has been reforged at least once.
var _selected_affix_index: int = -1
## Whole window body under the title bar, rebuilt wholesale on every change.
var _root: VBoxContainer
## The per-tab right column (rebuilt each _rebuild); fill functions populate it.
var _content: VBoxContainer
## Cached title-bar label so the title can track the active tab name.
var _title_label: Label


func _ready() -> void:
	_tab = _default_tab()
	init_window(_tab_title(), WIN_SIZE)
	_reskin_chrome()
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	content_root.add_child(margin)
	_root = VBoxContainer.new()
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 8)
	margin.add_child(_root)
	_rebuild()
	# Guarded connects (re-entry safe); queue_free on close drops them automatically.
	if not MetaProgress.scrap_changed.is_connected(_on_scrap_changed):
		MetaProgress.scrap_changed.connect(_on_scrap_changed)
	if not MetaProgress.buildings_changed.is_connected(_rebuild):
		MetaProgress.buildings_changed.connect(_rebuild)


## Re-skin the DraggableWindow chrome (body panel, title bar, ✕) to the lightline
## frame. Every piece falls back silently to the programmatic StyleBox.
func _reskin_chrome() -> void:
	add_theme_stylebox_override("panel", T.ll_panel())
	if is_instance_valid(_title_bar):
		_title_bar.add_theme_stylebox_override("panel", T.ll_titlebar())
		_title_bar.custom_minimum_size = Vector2(0, 46)
	# The base title bar's first child is the title Label; center it + track it.
	if is_instance_valid(_title_bar_box) and _title_bar_box.get_child_count() > 0:
		var lbl := _title_bar_box.get_child(0) as Label
		if lbl != null:
			_title_label = lbl
			_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reskin_close_button()


func _reskin_close_button() -> void:
	if not is_instance_valid(_close_btn):
		return
	var tex := T.lightline_tex("btn_close")
	if tex == null:
		return  # keep the base "✕" glyph button
	_close_btn.text = ""
	_close_btn.flat = false
	_close_btn.custom_minimum_size = Vector2(40, 40)
	_close_btn.add_theme_stylebox_override("normal", _tex_box(tex, 1.0))
	_close_btn.add_theme_stylebox_override("hover", _tex_box(tex, 1.14))
	_close_btn.add_theme_stylebox_override("pressed", _tex_box(tex, 0.86))
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_scrap_changed(_v: int) -> void:
	_rebuild()


func _tab_unlocked(tab_id: String) -> bool:
	return MetaProgress.building_can("forge", tab_id)


func _tab_title() -> String:
	return tr(str(TAB_LABEL_KEYS.get(_tab, "UI_BUILD_FORGE_NAME")))


## First unlocked tab in display order (dismantle is T1, so a fresh forge lands on
## it). Falls back to "dismantle" if somehow everything is gated.
func _default_tab() -> String:
	for tab_id in TABS:
		if _tab_unlocked(str(tab_id)):
			return str(tab_id)
	return "dismantle"


## Rebuild the whole body: tab strip → scrap balance → two-column body (NPC/anvil
## left, per-tab content right). Old children are removed immediately so the
## fixed-size window never doubles a frame.
func _rebuild() -> void:
	if not is_instance_valid(_root):
		return
	if _selected_index >= MetaProgress.stash.size():
		_selected_index = -1
		_selected_affix_index = -1
	if not _tab_unlocked(_tab):
		_tab = _default_tab()
	if is_instance_valid(_title_label):
		_title_label.text = _tab_title()
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()

	# ── Tab strip ──
	_root.add_child(_build_tab_bar())

	# ── Slim scrap balance (concept omits a readout; keep it minimal for UX) ──
	var scrap_strip := HBoxContainer.new()
	scrap_strip.alignment = BoxContainer.ALIGNMENT_END
	scrap_strip.add_child(T.currency_row(int(MetaProgress.scrap), "scrap", 16, 18))
	_root.add_child(scrap_strip)

	# ── Two-column body ──
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.add_child(_build_left_column())
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_root.add_child(body)

	match _tab:
		"dismantle":
			_fill_dismantle()
		"craft":
			_fill_craft()
		"reforge":
			_fill_reforge()
		"curse":
			_fill_curse()


# --- tab strip ----------------------------------------------------------------


func _build_tab_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 56)
	for tab_v in TABS:
		row.add_child(_build_tab_icon(str(tab_v)))
	return row


func _build_tab_icon(tab_id: String) -> Control:
	var unlocked := _tab_unlocked(tab_id)
	var selected := tab_id == _tab
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 54)
	btn.focus_mode = Control.FOCUS_NONE
	if selected:
		btn.add_theme_stylebox_override("normal", T.ll_button("normal"))
		btn.add_theme_stylebox_override("hover", T.ll_button("hover"))
		btn.add_theme_stylebox_override("pressed", T.ll_button("pressed"))
		btn.add_theme_stylebox_override("disabled", T.ll_button("normal"))
	else:
		btn.add_theme_stylebox_override("normal", T.ll_section())
		btn.add_theme_stylebox_override("hover", _warm_hover_style())
		btn.add_theme_stylebox_override("pressed", T.ll_section())
		btn.add_theme_stylebox_override("disabled", T.ll_section())

	var stack := Control.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _ll_icon(str(TAB_ICONS.get(tab_id, "icon_anvil")), 34)
	if not unlocked:
		icon.modulate = Color(1, 1, 1, 0.32)
	center.add_child(icon)
	stack.add_child(center)
	if not unlocked:
		var lock_center := CenterContainer.new()
		lock_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lock := _ll_icon("icon_lock", 22)
		lock.modulate = Color(1, 1, 1, 0.9)
		lock_center.add_child(lock)
		stack.add_child(lock_center)
	btn.add_child(stack)

	if not unlocked:
		btn.disabled = true
		if TAB_LOCK_KEYS.has(tab_id):
			btn.tooltip_text = tr(str(TAB_LOCK_KEYS[tab_id]))
	elif not selected:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tid := tab_id
		btn.pressed.connect(
			func() -> void:
				_tab = tid
				_selected_affix_index = -1
				AudioManager.play_sfx("ui_click")
				_rebuild()
		)
	return btn


# --- left column (NPC portrait + anvil illustration; shared by all tabs) -------


func _build_left_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(150, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)

	# Blacksmith NPC portrait — the Codex orc bust (2026-07-08 delivery); falls
	# back to the lightline furnace, then a bare anvil icon, if regenerating.
	var npc := PanelContainer.new()
	npc.name = "ForgeNpcPortrait"
	npc.custom_minimum_size = Vector2(150, 196)
	npc.add_theme_stylebox_override("panel", T.ll_inset())
	var npc_center := CenterContainer.new()
	npc_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	npc.add_child(npc_center)
	var npc_tex := _load_tex_or_null("res://run_system/assets/images/ui/forge/npc_blacksmith.png")
	if npc_tex == null:
		npc_tex = T.lightline_tex("furnace")
	if npc_tex != null:
		var portrait := TextureRect.new()
		portrait.texture = npc_tex
		portrait.custom_minimum_size = Vector2(138, 180)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		npc_center.add_child(portrait)
	else:
		npc_center.add_child(_ll_icon("icon_anvil", 68))
	col.add_child(npc)

	# Anvil illustration — the Codex hammer-striking-anvil banner (2026-07-08);
	# falls back to a large icon_anvil while regenerating.
	var art := PanelContainer.new()
	art.name = "ForgeAnvilArt"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.add_theme_stylebox_override("panel", T.ll_section())
	var art_center := CenterContainer.new()
	art_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(art_center)
	var anvil_tex := _load_tex_or_null("res://run_system/assets/images/ui/forge/anvil_art.png")
	if anvil_tex != null:
		var banner := TextureRect.new()
		banner.texture = anvil_tex
		banner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		banner.custom_minimum_size = Vector2(138, 220)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_center.add_child(banner)
	else:
		art_center.add_child(_ll_icon("icon_anvil", 104))
	col.add_child(art)
	return col


## A Texture2D from an exact path, or null (warn-free placeholder rule).
func _load_tex_or_null(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


# --- DISMANTLE tab -------------------------------------------------------------


func _fill_dismantle() -> void:
	# Drop slot → single dismantle on drop.
	_content.add_child(_build_drop_slot(true))
	var hint := Label.new()
	hint.text = tr("UI_FORGE_DISMANTLE_DROP_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 12, Color(0.68, 0.62, 0.5))
	_content.add_child(hint)

	# "全部分解" section header row.
	_content.add_child(_bulk_header_row())

	# Four bulk-by-rarity buttons.
	for spec_v in BULK_BUTTONS:
		var spec: Dictionary = spec_v
		_content.add_child(
			_bulk_button_row(str(spec["rarity"]), str(spec["key"]), str(spec["icon"]))
		)


func _bulk_header_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 46)
	row.add_child(_ll_icon("icon_scrap", 36))
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_stylebox_override("panel", T.ll_inset())
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 6)
	strip.add_child(m)
	var lbl := Label.new()
	lbl.text = tr("UI_FORGE_BULK_TITLE")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(lbl, 17, T.UI_HEADER_GOLD, 1)
	m.add_child(lbl)
	row.add_child(strip)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(52, 0)
	row.add_child(spacer)
	return row


func _bulk_button_row(rarity: String, label_key: String, icon_name: String) -> Control:
	var prev: Dictionary = MetaProgress.preview_dismantle_by_rarity(rarity)
	var count := int(prev.get("count", 0))
	var enabled := count > 0
	var rar := rarity
	var cb := func() -> void:
		_show_bulk_confirm(rar)
	var row := _icon_button_row(icon_name, tr(label_key), enabled, cb)
	if not enabled:
		# Grey out + tell the player why nothing happens.
		for c in row.get_children():
			if c is Button:
				(c as Button).tooltip_text = tr("UI_FORGE_BULK_NONE")
	return row


## Bulk-dismantle confirm: a centered glass modal (matches the tier-confirm popup
## style) showing the pre-scanned count + scrap, wired to the real dismantle only
## on 确认.
func _show_bulk_confirm(rarity: String) -> void:
	if get_node_or_null("ForgeBulkConfirm") != null:
		return
	var prev: Dictionary = MetaProgress.preview_dismantle_by_rarity(rarity)
	var count := int(prev.get("count", 0))
	var scrap := int(prev.get("scrap", 0))
	if count <= 0:
		return
	var zh := Settings.language == "zh"

	var layer := CanvasLayer.new()
	layer.name = "ForgeBulkConfirm"
	layer.layer = 160
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", T.ll_panel())
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 28)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	m.add_child(box)

	var title := Label.new()
	title.text = tr("UI_FORGE_BULK_CONFIRM_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 22, T.UI_HEADER_GOLD, 1)
	box.add_child(title)

	var msg := Label.new()
	msg.text = tr("UI_FORGE_BULK_CONFIRM").format({"n": count, "s": scrap})
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(msg, 18, Color(1.0, 0.93, 0.78))
	box.add_child(msg)

	var gain := T.currency_row(scrap, "scrap", 20, 22, "获得:" if zh else "Gain:")
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(gain)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var yes := Button.new()
	yes.text = "确认" if zh else "Confirm"
	yes.custom_minimum_size = Vector2(150, 46)
	yes.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(yes)
	yes.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rar := rarity
	yes.pressed.connect(
		func() -> void:
			var res: Dictionary = MetaProgress.dismantle_stash_by_rarity(rar)
			if int(res.get("count", 0)) > 0:
				AudioManager.play_sfx("forge_dismantle")
			_selected_index = -1
			_selected_affix_index = -1
			if is_instance_valid(layer):
				layer.queue_free()
			_rebuild()
	)
	row.add_child(yes)
	var no := Button.new()
	no.text = "取消" if zh else "Cancel"
	no.custom_minimum_size = Vector2(150, 46)
	no.focus_mode = Control.FOCUS_NONE
	T.apply_button_theme(no)
	no.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	no.pressed.connect(
		func() -> void:
			AudioManager.play_sfx("ui_back")
			if is_instance_valid(layer):
				layer.queue_free()
	)
	row.add_child(no)


# --- CRAFT tab -----------------------------------------------------------------


func _fill_craft() -> void:
	_content.add_child(_preview_panel(_ll_icon("icon_hammer", 60)))

	# Slot picker.
	var slot_opt := OptionButton.new()
	slot_opt.custom_minimum_size = Vector2(0, 40)
	slot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in CRAFT_SLOTS:
		slot_opt.add_item(tr("UI_FORGE_SLOT_%s" % str(s).to_upper()))
	slot_opt.selected = CRAFT_SLOTS.find(_craft_slot)
	slot_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_slot = str(CRAFT_SLOTS[idx])
			_rebuild()
	)
	_content.add_child(_picker_row("icon_bag", tr("UI_FORGE_SLOT"), slot_opt))

	# Rarity picker.
	var rarity_opt := OptionButton.new()
	rarity_opt.custom_minimum_size = Vector2(0, 40)
	rarity_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in CRAFT_RARITIES:
		rarity_opt.add_item(tr("UI_FORGE_RARITY_%s" % str(r).to_upper()))
	rarity_opt.selected = CRAFT_RARITIES.find(_craft_rarity)
	rarity_opt.item_selected.connect(
		func(idx: int) -> void:
			_craft_rarity = str(CRAFT_RARITIES[idx])
			_rebuild()
	)
	_content.add_child(_picker_row("icon_star", tr("UI_FORGE_RARITY"), rarity_opt))

	# Craft action. Disabled when Scrap is short OR the stash has no room for the
	# minted item (the handler still refunds as the trust boundary).
	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var stash_has_room: bool = MetaProgress.stash.size() < MetaProgress.effective_stash_cap()
	var enabled := int(MetaProgress.scrap) >= cost and stash_has_room
	_content.add_child(
		_icon_action_row("icon_hammer", tr("UI_FORGE_CRAFT_VERB"), cost, enabled, _on_craft_pressed)
	)


## Spend Scrap and mint a fresh stash item of the selected slot + rarity.
func _on_craft_pressed() -> void:
	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var base_id := str(CRAFT_BASE_BY_SLOT.get(_craft_slot, ""))
	if base_id == "":
		return
	# Mint BEFORE charging so a bad base id can never eat Scrap (pure roll — no
	# side effects until add_to_stash).
	var inst: Dictionary = RunManager.make_equip_instance(base_id, _craft_rarity)
	if inst.is_empty():
		return
	if not MetaProgress.spend_scrap(cost):
		return
	if not MetaProgress.add_to_stash(inst):
		# Stash full → refund, same contract as the market's stash-full path.
		MetaProgress.add_scrap(cost)
		return
	AudioManager.play_sfx("forge_craft")
	_rebuild()


# --- REFORGE tab ---------------------------------------------------------------


func _fill_reforge() -> void:
	_content.add_child(_build_drop_slot(false))
	var sel := _selected_instance()
	if sel.is_empty():
		_content.add_child(_bench_empty_hint())
		_content.add_child(_compact_stash_grid())
		return
	_content.add_child(_selected_name_label(sel))

	var locked := int(sel.get("reforge_index", -1))
	var rcount := int(sel.get("reforge_count", 0))
	var affixes := RunManager.equip_affixes(sel)
	if locked >= 0:
		_selected_affix_index = locked
	if affixes.is_empty():
		var none := Label.new()
		none.text = "—"
		_style_label(none, 15, Color(0.7, 0.7, 0.68))
		_content.add_child(none)
	else:
		for ai in range(affixes.size()):
			_content.add_child(_build_affix_row(affixes[ai], ai, locked, true))
		var rcost := MetaProgress.reforge_cost_for(sel)
		var pick_ok := (
			_selected_affix_index >= 0
			and _selected_affix_index < affixes.size()
			and not AFFIX_POOL.is_curse(affixes[_selected_affix_index])
		)
		var enabled := int(MetaProgress.scrap) >= rcost and pick_ok
		_content.add_child(
			_icon_action_row("icon_hammer", tr("UI_FORGE_REFORGE_VERB"), rcost, enabled, _reforge_selected)
		)
		var status := Label.new()
		if locked >= 0:
			status.text = tr("UI_FORGE_REFORGE_LOCKED_AT").format({"n": rcount})
		elif not pick_ok:
			status.text = tr("UI_FORGE_REFORGE_PICK")
		else:
			status.text = tr("UI_FORGE_REFORGE_FIRST")
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(status, 12, Color(0.74, 0.70, 0.58))
		_content.add_child(status)
	_content.add_child(_compact_stash_grid())


## Reforge the PICKED affix. Backend locks the item on the first reforge + climbs
## the cost each time.
func _reforge_selected() -> void:
	if _selected_index < 0 or _selected_affix_index < 0:
		return
	if MetaProgress.reforge_stash_item_locked(_selected_index, _selected_affix_index):
		AudioManager.play_sfx("forge_reforge")
	_rebuild()


# --- CURSE tab -----------------------------------------------------------------


func _fill_curse() -> void:
	_content.add_child(_build_drop_slot(false))
	var sel := _selected_instance()
	if sel.is_empty():
		_content.add_child(_bench_empty_hint())
		_content.add_child(_compact_stash_grid())
		return
	_content.add_child(_selected_name_label(sel))

	# Show the item's affixes read-only for context.
	for affix in RunManager.equip_affixes(sel):
		_content.add_child(_build_affix_row(affix, -1, -1, false))

	var cursed := bool(sel.get("cursed", false))
	var enabled := int(MetaProgress.scrap) >= CURSE_COST and not cursed
	var idx := _selected_index
	_content.add_child(
		_icon_action_row(
			"icon_bag",
			tr("UI_FORGE_CURSE_VERB"),
			CURSE_COST,
			enabled,
			func() -> void: _curse_item(idx)
		)
	)
	_content.add_child(_compact_stash_grid())


## Curse the benched stash item in place (T3). MetaProgress owns the spend / re-roll
## / flag / save and emits scrap_changed (→ _rebuild).
func _curse_item(index: int) -> void:
	if not MetaProgress.curse_stash_item(index):
		return
	AudioManager.play_sfx("forge_curse")
	_rebuild()


# --- shared bench pieces -------------------------------------------------------


func _selected_instance() -> Dictionary:
	if _selected_index >= 0 and _selected_index < MetaProgress.stash.size():
		return RunManager.as_equip_instance(MetaProgress.stash[_selected_index])
	return {}


## The top drop slot / preview panel. `dismantle_on_drop` = true → a drop dismantles
## the item immediately (Dismantle tab); false → a drop benches it for selection
## (Reforge / Curse tabs). Accepts THIS window's stash payload (src forge_stash) AND
## the base-mode CharacterWindow stash payload (src stash, carrying the entry).
func _build_drop_slot(dismantle_on_drop: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 132)
	panel.add_theme_stylebox_override("panel", T.ll_inset())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var sel := _selected_instance()
	var slot_cell = BACKPACK_CELL.new()
	slot_cell.custom_minimum_size = BENCH_CELL_SIZE
	var anvil_slot_tex: Texture2D = null
	if dismantle_on_drop:
		anvil_slot_tex = T.lightline_tex("drop_slot_anvil")
	if anvil_slot_tex != null:
		# Dismantle: the concept's dashed anvil drop-target IS the slot visual.
		var slot_rect := TextureRect.new()
		slot_rect.texture = anvil_slot_tex
		slot_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_cell.add_child(slot_rect)
	else:
		var slot_icon = EQUIPMENT_ICON.new()
		slot_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if dismantle_on_drop or sel.is_empty():
			slot_icon.set_empty("weapon")
		else:
			var b := str(sel.get("base", ""))
			var d: Dictionary = RunManager.get_equipment_data(b)
			slot_icon.set_equipment(
				str(d.get("slot", "head")),
				Settings.t("EQUIP_%s_NAME" % b, str(d.get("name", b))),
				str(d.get("sprite", "")),
				str(sel.get("rarity", "common"))
			)
		slot_cell.add_child(slot_icon)
	slot_cell.can_accept = func(d):
		return (
			d.get("src") == "forge_stash"
			or (d.get("src") == "stash" and d.get("entry") != null)
		)
	if dismantle_on_drop:
		slot_cell.perform_drop = func(d): _dismantle_dropped(d)
	else:
		slot_cell.perform_drop = func(d): _select_dropped(d)
	center.add_child(slot_cell)
	return panel


func _dismantle_dropped(d: Dictionary) -> void:
	var idx := -1
	if d.get("src") == "forge_stash":
		idx = int(d.get("index", -1))
	elif d.get("entry") != null:
		idx = MetaProgress.stash.find(d.get("entry"))
	if idx < 0 or idx >= MetaProgress.stash.size():
		return
	if MetaProgress.dismantle_stash_item(idx):
		AudioManager.play_sfx("forge_dismantle")
		_selected_index = -1
	_rebuild()


func _select_dropped(d: Dictionary) -> void:
	if d.get("src") == "forge_stash":
		_select_item(int(d.get("index", -1)))
	elif d.get("entry") != null:
		var idx: int = MetaProgress.stash.find(d.get("entry"))
		if idx >= 0:
			_select_item(idx)


func _select_item(index: int) -> void:
	if index < 0 or index >= MetaProgress.stash.size():
		return
	_selected_index = index
	_selected_affix_index = -1
	AudioManager.play_sfx("ui_click")
	_rebuild()


func _bench_empty_hint() -> Label:
	var l := Label.new()
	l.text = tr("UI_FORGE_BENCH_EMPTY")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l, 14, Color(0.72, 0.66, 0.52))
	return l


func _selected_name_label(sel: Dictionary) -> Label:
	var base_id := str(sel.get("base", ""))
	var rarity := str(sel.get("rarity", "common"))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))
	var l := Label.new()
	l.text = "%s [%s]" % [item_name, tr("UI_FORGE_RARITY_%s" % rarity.to_upper())]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l, 17, Color(1, 0.92, 0.55), 1)
	return l


## One affix line. In the reforge tab clicking PICKS that affix (curses can't be
## picked; once locked only the locked row stays enabled). Elsewhere read-only.
func _build_affix_row(
	affix_v: Variant, affix_index: int, locked_index: int, can_pick: bool
) -> Control:
	var a := affix_v as Dictionary
	var is_curse := AFFIX_POOL.is_curse(a)
	var picked := can_pick and affix_index == _selected_affix_index
	var pickable := (
		can_pick and not is_curse and (locked_index < 0 or locked_index == affix_index)
	)

	var btn := Button.new()
	btn.text = AFFIX_POOL.describe(a)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	var fg := Color(1.0, 0.42, 0.42) if is_curse else Color(0.70, 0.92, 0.70)
	if can_pick and not pickable and not picked:
		fg = fg.darkened(0.4)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_disabled_color", fg)
	btn.add_theme_stylebox_override("normal", _affix_row_style(picked))
	btn.add_theme_stylebox_override("hover", _affix_row_style(picked))
	btn.add_theme_stylebox_override("pressed", _affix_row_style(true))
	btn.add_theme_stylebox_override("disabled", _affix_row_style(picked))
	if pickable:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var ai := affix_index
		btn.pressed.connect(
			func() -> void:
				_selected_affix_index = ai
				AudioManager.play_sfx("ui_click")
				_rebuild()
		)
	else:
		btn.disabled = true
	return btn


func _affix_row_style(picked: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.14, 0.11, 0.9) if picked else Color(0.10, 0.10, 0.12, 0.55)
	st.border_color = Color(1.0, 0.82, 0.35) if picked else Color(0.32, 0.30, 0.26, 0.8)
	st.set_border_width_all(2 if picked else 1)
	st.set_corner_radius_all(5)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	return st


# --- compact stash grid (selection surface for reforge / curse) ----------------


func _compact_stash_grid() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	box.add_child(
		_section_title(tr("UI_FORGE_STASH_TITLE").format({"n": MetaProgress.stash.size()}))
	)
	if MetaProgress.stash.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("UI_FORGE_EMPTY")
		_style_label(empty, 13, Color(0.72, 0.66, 0.52))
		box.add_child(empty)
		return box
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for i in range(MetaProgress.stash.size()):
		grid.add_child(_build_forge_stash_cell(i))
	box.add_child(scroll)
	return box


func _build_forge_stash_cell(index: int) -> Control:
	var inst := RunManager.as_equip_instance(MetaProgress.stash[index])
	var base_id := str(inst.get("base", ""))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	var slot := str(data.get("slot", "head"))
	var rarity := str(inst.get("rarity", "common"))
	var item_name := Settings.t("EQUIP_%s_NAME" % base_id, str(data.get("name", base_id)))

	var cell = BACKPACK_CELL.new()
	cell.custom_minimum_size = GRID_CELL_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon = EQUIPMENT_ICON.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_equipment(slot, item_name, str(data.get("sprite", "")), rarity)
	cell.add_child(icon)

	cell.hover_tip = _forge_item_tooltip(inst)
	cell.drag_payload = {"src": "forge_stash", "index": index}
	cell.preview_text = item_name.substr(0, 1)
	cell.preview_color = Color(1.0, 0.86, 0.4)
	cell.preview_tex = _load_equip_tex(str(data.get("sprite", "")))
	var idx := index
	cell.click_handler = func(btn): if btn == MOUSE_BUTTON_LEFT: _select_item(idx)

	if index == _selected_index:
		var hl := Panel.new()
		hl.set_anchors_preset(Control.PRESET_FULL_RECT)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.border_color = Color(1.0, 0.85, 0.35)
		st.set_border_width_all(3)
		st.set_corner_radius_all(6)
		hl.add_theme_stylebox_override("panel", st)
		cell.add_child(hl)
	return cell


# --- concept row builders (icon + dark middle + orange arrow) ------------------


## A dismantle-style row: left icon + wide dark button + orange arrow, BOTH the
## button and the arrow firing `cb`. Used for the bulk buttons.
func _icon_button_row(icon_name: String, verb: String, enabled: bool, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 56)
	row.add_child(_ll_icon(icon_name, 40))
	var btn := Button.new()
	btn.text = verb
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	_apply_dark_button(btn)
	if enabled:
		btn.pressed.connect(cb)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.5)
	row.add_child(btn)
	row.add_child(_orange_arrow_button(enabled, cb))
	return row


## An action row: left icon + dark button (verb left, scrap-cost badge right) +
## orange arrow. Both button + arrow fire `cb`. Used for craft / reforge / curse.
func _icon_action_row(
	icon_name: String, verb: String, cost: int, enabled: bool, cb: Callable
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 56)
	row.add_child(_ll_icon(icon_name, 40))
	var btn := Button.new()
	btn.text = verb
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	_apply_dark_button(btn)
	if cost > 0:
		btn.add_child(T.overlay_cost_badge(cost, "scrap", 15, 16, -10, -72))
	if enabled:
		btn.pressed.connect(cb)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.5)
	row.add_child(btn)
	row.add_child(_orange_arrow_button(enabled, cb))
	return row


## A picker row: left icon + label + an OptionButton (craft slot / rarity).
func _picker_row(icon_name: String, label_text: String, option: OptionButton) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 52)
	row.add_child(_ll_icon(icon_name, 40))
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(64, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(lbl, 15, Color(0.92, 0.88, 0.76))
	row.add_child(lbl)
	row.add_child(option)
	return row


func _orange_arrow_button(enabled: bool, cb: Callable) -> Button:
	var arrow := Button.new()
	arrow.custom_minimum_size = Vector2(52, 52)
	arrow.focus_mode = Control.FOCUS_NONE
	var tex := T.lightline_tex("btn_arrow_right")
	if tex != null:
		arrow.add_theme_stylebox_override("normal", _tex_box(tex, 1.0))
		arrow.add_theme_stylebox_override("hover", _tex_box(tex, 1.14))
		arrow.add_theme_stylebox_override("pressed", _tex_box(tex, 0.86))
		arrow.add_theme_stylebox_override("disabled", _tex_box(tex, 1.0))
	else:
		arrow.add_theme_stylebox_override("normal", T.ll_button("normal"))
		arrow.add_theme_stylebox_override("hover", T.ll_button("hover"))
		arrow.add_theme_stylebox_override("pressed", T.ll_button("pressed"))
		arrow.add_theme_stylebox_override("disabled", T.ll_button("normal"))
		var c := CenterContainer.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(_ll_icon("icon_arrow_right", 22))
		arrow.add_child(c)
	if enabled and cb.is_valid():
		arrow.pressed.connect(cb)
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		arrow.disabled = true
		arrow.modulate = Color(1, 1, 1, 0.5)
	return arrow


func _preview_panel(child: Control) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)
	panel.add_theme_stylebox_override("panel", T.ll_inset())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	if child != null:
		center.add_child(child)
	return panel


func _apply_dark_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(0.93, 0.87, 0.70))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78))
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.84, 0.66))
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.64, 0.5, 0.9))
	btn.add_theme_stylebox_override("normal", T.ll_section())
	btn.add_theme_stylebox_override("hover", _warm_hover_style())
	btn.add_theme_stylebox_override("pressed", T.ll_section())
	btn.add_theme_stylebox_override("disabled", T.ll_section())


# --- small shared helpers ------------------------------------------------------


## A lightline PNG as a fixed-size TextureRect, or an equal-size empty spacer when
## the art is undelivered (warn-free placeholder).
func _ll_icon(icon_name: String, px: float) -> Control:
	var tex := T.lightline_tex(icon_name)
	if tex == null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(px, px)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return spacer
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A StyleBoxTexture over a raw texture with a modulate tint (for hover/pressed
## states of texture-backed buttons: 1.0 normal / >1 hover / <1 pressed).
func _tex_box(tex: Texture2D, tint: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	if tint != 1.0:
		sb.modulate_color = Color(tint, tint, tint)
	return sb


func _warm_hover_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.22, 0.16, 0.09, 0.55)
	st.border_color = Color(0.62, 0.45, 0.24, 0.8)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	return st


func _load_equip_tex(sprite_path: String) -> Texture2D:
	if sprite_path == "":
		return null
	var full := "res://battle_scene/assets/images/" + sprite_path
	if ResourceLoader.exists(full):
		return load(full) as Texture2D
	if FileAccess.file_exists(full):
		var img := Image.load_from_file(full)
		if img:
			return ImageTexture.create_from_image(img)
	return null


## Delegates to the shared EQUIP_TOOLTIP helper (owner 2026-07-08: rarity·slot
## header, no generated name; set pieces keep theirs).
func _forge_item_tooltip(inst: Dictionary) -> String:
	var base_id := str(inst.get("base", ""))
	var data: Dictionary = RunManager.get_equipment_data(base_id)
	return EQUIP_TOOLTIP.text(data, str(data.get("slot", "")), inst)


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	return l


func _style_label(label: Label, font_size: int, color: Color, outline: int = 0) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		label.add_theme_constant_override("outline_size", outline)
