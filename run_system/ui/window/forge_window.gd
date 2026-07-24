## ForgeWindow — the Forge building as a floating DraggableWindow, rebuilt to
## match the 2026-07-07 "lightline" concept art (olive-brass metal frame + orange
## primary buttons; see docs/art/previews/base_building_forge_ui_*_20260707.png).
##
## Three consistent tabs: Dismantle, Craft, and Reforge. Curse is the tier-3
## secondary action inside Reforge instead of occupying a fourth tab. Tabs share
## identical geometry and differ only through normal/hover/selected color.
## The body is two columns: LEFT = blacksmith NPC portrait placeholder
## (ForgeNpcPortrait) + anvil illustration (ForgeAnvilArt) — Codex art drops into
## those named nodes later; RIGHT = per-tab content.
##
## DISMANTLE: the workbench accepts only a base CharacterWindow backpack payload
## (`src == "carry"`). Single and bulk actions operate on RunManager.pending_loadout;
## the permanent stash never appears in this window. Bulk actions are presented as
## a Diablo-style vertical list: all / common / uncommon / rare. Set + cursed gear
## remain protected from bulk dismantle and every bulk action keeps its confirmation.
##
## CRAFT / REFORGE use the same pending-loadout ownership: crafted gear is
## placed in the base backpack, while reforge/curse mutate the selected backpack
## entry in place. The separate StashWindow remains pure storage.
##
## Rebuilds on scrap_changed / buildings_changed; frees on close. NO class_name
## (project convention) — loaded by path. Every lightline PNG lookup falls back to a
## programmatic StyleBox (T.ll_*) so a missing Codex asset never crashes.
extends "res://run_system/ui/window/draggable_window.gd"

const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")
const EQUIPMENT_ICON = preload("res://run_system/ui/equipment_icon.gd")
const BACKPACK_CELL = preload("res://run_system/ui/backpack_cell.gd")
const BUILDING_UPGRADE_POPOVER = preload(
	"res://run_system/ui/buildings/building_upgrade_popover.gd"
)

const FORGE_BADGE_PATH := "res://run_system/assets/images/home/base_hud/badge_forge.png"
const FORGE_WORKBENCH_PATH := (
	"res://run_system/assets/images/ui/forge/forge_blacksmith_workbench.png"
)
const CAPS_ICON_PATH := "res://run_system/assets/images/home/currency/caps.png"
const UPGRADE_ICON_PATH := "res://run_system/assets/images/ui_kit_lightline/icon_uparrow.png"

# The vertical dismantle list fits inside this compact floating window; the
# draggable_window viewport cap + content scroll absorb smaller viewports.
const WIN_SIZE := Vector2(640, 760)
const BENCH_CELL_SIZE := Vector2(84, 84)

## Scrap cost to craft a fresh item, by target rarity (spec: 40/80/140).
const CRAFT_COST := {"common": 40, "uncommon": 80, "rare": 140}
## Mirrors MetaProgress.CURSE_SCRAP_COST for the button label + gating (an autoload
## const can't seed a GDScript const, so this stays a literal).
const CURSE_COST := 100
## Slot → a representative base equipment item_id used when crafting that slot.
const CRAFT_BASE_BY_SLOT := {
	"head": "gear_head_common",
	"chest": "gear_chest_common",
	"weapon": "gear_weapon_common",
	"hands": "gear_hands_common",
	"accessory": "gear_accessory_common",
}
const CRAFT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
const CRAFT_RARITIES := ["common", "uncommon", "rare"]

## Tabs in the concept's visual left→right order; each id doubles as its
## `building_can("forge", …)` function name.
const TABS := ["dismantle", "craft", "reforge"]
const TAB_LABEL_KEYS := {
	"dismantle": "UI_FORGE_TAB_DISMANTLE",
	"craft": "UI_FORGE_TAB_CRAFT",
	"reforge": "UI_FORGE_TAB_REFORGE",
}
## Lightline tab-icon piece per tab (matches the concept tab-strip left→right:
## anvil / shield / GEAR — the concept's 3rd tab glyph is a gear, not a hammer).
const TAB_ICONS := {
	"dismantle": "icon_anvil",
	"craft": "icon_shield",
	"reforge": "icon_gear",
}
## Lock-hint key per tier-gated tab (dismantle is T1 = always available, no hint).
const TAB_LOCK_KEYS := {
	"craft": "UI_FORGE_CRAFT_LOCKED",
	"reforge": "UI_FORGE_REFORGE_LOCKED",
}

## Diablo-style vertical order. Chinese names deliberately use the project's
## approved quality vocabulary: 全部 / 普通 / 精良 / 军官.
const BULK_BUTTONS := [
	{"rarity": "", "zh": "全部", "en": "ALL", "icon": "icon_swap"},
	{"rarity": "common", "zh": "普通", "en": "COMMON", "icon": ""},
	{"rarity": "uncommon", "zh": "精良", "en": "UNCOMMON", "icon": ""},
	{"rarity": "rare", "zh": "军官", "en": "RARE", "icon": ""},
]

## The selected tab (one of TABS); forced back to the first unlocked tab if the
## current one is tier-locked.
var _tab: String = "dismantle"
## Craft picker state.
var _craft_slot: String = "head"
var _craft_rarity: String = "common"
## Index into RunManager.pending_loadout of the item on the bench (-1 = none).
var _selected_index: int = -1
## Which affix ROW is picked for reforge (-1 = none). Forced to the locked affix
## index once the item has been reforged at least once.
var _selected_affix_index: int = -1
## Whole window body under the title bar, rebuilt wholesale on every change.
var _root: VBoxContainer
## The per-tab right column (rebuilt each _rebuild); fill functions populate it.
var _content: VBoxContainer
## Concept-v2 custom top bar state.
var _upgrade_button: Button
var _caps_label: Label
var _upgrade_popover: Control
var _popover_host: Control


func _ready() -> void:
	_tab = _default_tab()
	# Forge owns a deliberately different header: Upgrade + Caps | badge/name | X.
	# The stock DraggableWindow title bar cannot express that hierarchy.
	init_window(tr("UI_BUILD_FORGE_NAME"), WIN_SIZE, false)
	_reskin_chrome()
	_mount_forge_header()
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
	if not MetaProgress.caps_changed.is_connected(_on_caps_changed):
		MetaProgress.caps_changed.connect(_on_caps_changed)
	if not MetaProgress.buildings_changed.is_connected(_rebuild):
		MetaProgress.buildings_changed.connect(_rebuild)


## Re-skin the DraggableWindow body. The Forge owns its fixed custom header.
func _reskin_chrome() -> void:
	add_theme_stylebox_override("panel", T.ll_charcoal_panel())


## Fixed, draggable concept-v2 top bar. Manual anchors keep the badge/name
## geometrically centered even though the left group is wider than the close X.
func _mount_forge_header() -> void:
	for child in header_root.get_children():
		header_root.remove_child(child)
		child.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	header_root.add_child(margin)

	var bar := PanelContainer.new()
	bar.name = "ForgeHeader"
	bar.custom_minimum_size = Vector2(0, 62)
	bar.add_theme_stylebox_override("panel", T.ll_titlebar())
	bind_drag_area(bar)
	margin.add_child(bar)

	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(stage)

	var left := HBoxContainer.new()
	left.name = "ForgeHeaderLeft"
	left.anchor_top = 0.5
	left.anchor_bottom = 0.5
	left.offset_left = 12
	left.offset_top = -22
	left.offset_right = 245
	left.offset_bottom = 22
	left.add_theme_constant_override("separation", 10)
	stage.add_child(left)

	_upgrade_button = Button.new()
	_upgrade_button.name = "ForgeUpgradeButton"
	_upgrade_button.text = _local_text("升级", "UPGRADE")
	_upgrade_button.custom_minimum_size = Vector2(108, 42)
	_upgrade_button.focus_mode = Control.FOCUS_NONE
	_upgrade_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_upgrade_button.add_theme_font_override("font", T.display_font(700))
	_upgrade_button.add_theme_font_size_override("font_size", 16)
	_upgrade_button.add_theme_color_override("font_color", T.TEXT_MAIN)
	_upgrade_button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82))
	for state in ["normal", "hover", "pressed", "disabled"]:
		_upgrade_button.add_theme_stylebox_override(state, T.ll_button(state))
	var upgrade_tex := _load_tex_or_null(UPGRADE_ICON_PATH)
	if upgrade_tex != null:
		_upgrade_button.icon = upgrade_tex
		_upgrade_button.expand_icon = true
		_upgrade_button.add_theme_constant_override("icon_max_width", 20)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	left.add_child(_upgrade_button)

	var caps_chip := HBoxContainer.new()
	caps_chip.name = "ForgeCapsChip"
	caps_chip.add_theme_constant_override("separation", 5)
	caps_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(caps_chip)
	var caps_tex := _load_tex_or_null(CAPS_ICON_PATH)
	if caps_tex != null:
		var caps_icon := TextureRect.new()
		caps_icon.texture = caps_tex
		caps_icon.custom_minimum_size = Vector2(25, 25)
		caps_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		caps_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		caps_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caps_chip.add_child(caps_icon)
	_caps_label = Label.new()
	_caps_label.name = "ForgeCapsAmount"
	_caps_label.text = str(MetaProgress.caps)
	_caps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caps_label.add_theme_font_override("font", T.display_font(700))
	_caps_label.add_theme_font_size_override("font_size", 19)
	_caps_label.add_theme_color_override("font_color", T.TEXT_MAIN)
	_caps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caps_chip.add_child(_caps_label)

	var center := HBoxContainer.new()
	center.name = "ForgeHeaderTitle"
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -105
	center.offset_top = -24
	center.offset_right = 105
	center.offset_bottom = 24
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 7)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(center)
	var badge_tex := _load_tex_or_null(FORGE_BADGE_PATH)
	if badge_tex != null:
		var badge := TextureRect.new()
		badge.name = "ForgeHeaderBadge"
		badge.texture = badge_tex
		badge.custom_minimum_size = Vector2(40, 40)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(badge)
	var title := Label.new()
	title.text = tr("UI_BUILD_FORGE_NAME")
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", T.display_font(700))
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", T.UI_HEADER_GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(title)

	var close_btn := T.ll_close_button(40.0)
	close_btn.name = "ForgeCloseButton"
	close_btn.anchor_left = 1.0
	close_btn.anchor_top = 0.5
	close_btn.anchor_right = 1.0
	close_btn.anchor_bottom = 0.5
	close_btn.offset_left = -52
	close_btn.offset_top = -21
	close_btn.offset_right = -12
	close_btn.offset_bottom = 21
	close_btn.pressed.connect(close)
	stage.add_child(close_btn)
	_refresh_header_state()


func _refresh_header_state() -> void:
	if is_instance_valid(_caps_label):
		_caps_label.text = str(MetaProgress.caps)
	if is_instance_valid(_upgrade_button):
		var tier := MetaProgress.get_building_tier("forge")
		_upgrade_button.tooltip_text = (
			tr("UI_BUILD_MAX")
			if tier >= MetaProgress.MAX_BUILDING_TIER
			else tr("UI_BUILD_ACTION_UPGRADE_HEAD").format({"n": tier + 1})
		)


func _on_caps_changed(_value: int) -> void:
	_refresh_header_state()


func _on_upgrade_pressed() -> void:
	if is_instance_valid(_upgrade_popover):
		_close_upgrade_popover()
		return
	_ensure_popover_host()
	_upgrade_popover = BUILDING_UPGRADE_POPOVER.new()
	_upgrade_popover.setup("forge")
	_upgrade_popover.state_changed.connect(_on_upgrade_state_changed)
	_upgrade_popover.dismissed.connect(_close_upgrade_popover)
	_popover_host.add_child(_upgrade_popover)
	_upgrade_popover.position = Vector2(14, 66)
	AudioManager.play_sfx("ui_click")


func _ensure_popover_host() -> void:
	if is_instance_valid(_popover_host):
		return
	_popover_host = Control.new()
	_popover_host.name = "ForgePopoverHost"
	_popover_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popover_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popover_host)
	move_child(_popover_host, get_child_count() - 1)


func _close_upgrade_popover() -> void:
	if is_instance_valid(_upgrade_popover):
		_upgrade_popover.queue_free()
	_upgrade_popover = null


func _on_upgrade_state_changed(_building_id: String, _tier: int) -> void:
	_refresh_header_state()
	_rebuild()


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
	var forge_tier := MetaProgress.get_building_tier("forge")
	if _selected_index >= RunManager.pending_loadout.size():
		_selected_index = -1
		_selected_affix_index = -1
	if not _tab_unlocked(_tab):
		_tab = _default_tab()
	_refresh_header_state()
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()

	# A locked forge exposes only its in-context unlock control. Services (and in
	# particular dismantle) must not become usable until the header upgrade flow
	# unlocks T1.
	if forge_tier <= 0:
		var locked_hint := Label.new()
		locked_hint.name = "ForgeLockedHint"
		locked_hint.text = tr("UI_BUILD_FORGE_UNLOCK_DESC")
		locked_hint.custom_minimum_size = Vector2(0, 84)
		locked_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(locked_hint, 15, Color(0.72, 0.66, 0.52))
		_root.add_child(locked_hint)
		return

	# ── Tab strip ──
	_root.add_child(_build_tab_bar())

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
	btn.name = "ForgeTab_%s" % tab_id
	btn.text = tr(str(TAB_LABEL_KEYS.get(tab_id, tab_id)))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 54)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", T.display_font(700))
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_constant_override("icon_max_width", 26)
	btn.add_theme_constant_override("h_separation", 10)
	btn.icon = T.lightline_tex(str(TAB_ICONS.get(tab_id, "icon_anvil")))
	btn.expand_icon = true
	btn.add_theme_color_override(
		"font_color", Color(1.0, 0.70, 0.30) if selected else Color(0.82, 0.77, 0.66)
	)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.48))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.30))
	btn.add_theme_color_override("font_disabled_color", Color(0.44, 0.42, 0.38, 0.72))
	for state in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, _forge_tab_style(state, selected, unlocked))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

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


## Diablo-style tab rhythm without Diablo-style rendered chrome: every state
## keeps the same frame, border width, corner radius and padding. Only color
## changes between idle, hover, selected, pressed and locked states.
func _forge_tab_style(state: String, selected: bool, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.070, 0.072, 0.96)
	style.border_color = Color(0.31, 0.30, 0.27, 0.95)
	if not unlocked:
		style.bg_color = Color(0.045, 0.047, 0.048, 0.82)
		style.border_color = Color(0.22, 0.22, 0.21, 0.72)
	elif selected:
		style.bg_color = Color(0.22, 0.105, 0.035, 0.98)
		style.border_color = Color(0.96, 0.51, 0.16, 1.0)
		if state == "hover":
			style.bg_color = Color(0.27, 0.135, 0.045, 0.99)
			style.border_color = Color(1.0, 0.69, 0.25, 1.0)
	elif state == "hover":
		style.bg_color = Color(0.145, 0.105, 0.060, 0.98)
		style.border_color = Color(0.88, 0.62, 0.26, 1.0)
	elif state == "pressed":
		style.bg_color = Color(0.19, 0.095, 0.035, 0.99)
		style.border_color = Color(0.94, 0.49, 0.15, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


# --- left column (NPC portrait + anvil illustration; shared by all tabs) -------


func _build_left_column() -> Control:
	var stage := CenterContainer.new()
	stage.name = "ForgeNpcStage"
	stage.custom_minimum_size = Vector2(220, 390)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The accepted concept uses one coherent blacksmith-at-anvil silhouette, not
	# the former portrait card stacked above a second anvil card. Keep the legacy
	# ForgeNpcPortrait node name so visual/runtime probes retain a stable hook.
	var workbench_tex := _load_tex_or_null(FORGE_WORKBENCH_PATH)
	if workbench_tex != null:
		var workbench := TextureRect.new()
		workbench.name = "ForgeNpcPortrait"
		workbench.texture = workbench_tex
		workbench.custom_minimum_size = Vector2(210, 390)
		workbench.size_flags_vertical = Control.SIZE_EXPAND_FILL
		workbench.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		workbench.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		workbench.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		workbench.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(workbench)
	else:
		var fallback := CenterContainer.new()
		fallback.name = "ForgeNpcPortrait"
		fallback.custom_minimum_size = Vector2(210, 390)
		fallback.add_child(_ll_icon("icon_anvil", 104))
		stage.add_child(fallback)
	return stage


## A Texture2D from an exact path, or null (warn-free placeholder rule).
func _load_tex_or_null(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


# --- DISMANTLE tab -------------------------------------------------------------


func _fill_dismantle() -> void:
	# Drop slot → single dismantle from the base backpack.
	_content.add_child(_build_drop_slot(true))
	var sel := _selected_instance()
	if not sel.is_empty():
		_content.add_child(_selected_name_label(sel))
		for affix in RunManager.equip_affixes(sel):
			_content.add_child(_build_affix_row(affix, -1, -1, false))
		var idx := _selected_index
		var amount := _dismantle_value(sel)
		_content.add_child(
			_icon_action_row(
				"icon_scrap",
				tr("UI_FORGE_DISMANTLE_VERB"),
				-amount,
				true,
				func() -> void: _dismantle_selected(idx)
			)
		)
	var hint := Label.new()
	hint.text = _local_text("把背包装备拖到这里拆解。", "Drag backpack equipment here to dismantle it.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 12, Color(0.68, 0.62, 0.5))
	_content.add_child(hint)

	_content.add_child(_build_bulk_list())


## Diablo-style one-action-per-line list. It is intentionally a VBox, not the
## former four-button horizontal strip, so labels and disabled states remain
## readable at the forge window's compact width.
func _build_bulk_list() -> Control:
	var list := VBoxContainer.new()
	list.name = "ForgeBulkList"
	list.add_theme_constant_override("separation", 5)
	list.add_child(_bulk_header_row())
	for spec_v in BULK_BUTTONS:
		var spec: Dictionary = spec_v
		list.add_child(
			_bulk_button_row(
				str(spec["rarity"]),
				_local_text(str(spec["zh"]), str(spec["en"])),
				str(spec["icon"])
			)
		)
	return list


func _bulk_header_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.custom_minimum_size = Vector2(0, 30)
	row.add_child(_ll_icon("icon_scrap", 27))
	var lbl := Label.new()
	lbl.text = tr("UI_FORGE_BULK_TITLE")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(lbl, 15, T.UI_HEADER_GOLD, 1)
	row.add_child(lbl)
	return row


func _bulk_button_row(rarity: String, label_text: String, icon_name: String) -> Control:
	var prev: Dictionary = _preview_pending_dismantle(rarity)
	var count := int(prev.get("count", 0))
	var scrap := int(prev.get("scrap", 0))
	var enabled := count > 0
	var rar := rarity
	var row := HBoxContainer.new()
	row.name = "ForgeBulkAction_%s" % ("all" if rarity == "" else rarity)
	row.custom_minimum_size = Vector2(0, 58)
	row.add_theme_constant_override("separation", 7)
	row.add_child(_rarity_dot(rarity) if rarity != "" else _ll_icon(icon_name, 30))
	var button := Button.new()
	button.name = "ForgeBulkButton_%s" % ("all" if rarity == "" else rarity)
	button.text = (
		"%s    %s"
		% [
			label_text,
			_local_text("%d 件  ·  +%d 废料" % [count, scrap], "%d ITEMS  ·  +%d SCRAP" % [count, scrap]),
		]
	)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", T.display_font(700))
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _dismantle_action_style(state, false))
	if enabled:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: _show_bulk_confirm(rar))
	else:
		button.disabled = true
		button.modulate = Color(1, 1, 1, 0.5)
		button.tooltip_text = tr("UI_FORGE_BULK_NONE")
	row.add_child(button)
	if not enabled:
		row.modulate = Color(1, 1, 1, 0.72)
	return row


## A filled dot in the rarity's frame color (equipment_icon.gd RARITY_COLORS) —
## the bulk rows key by rarity, so the leading glyph IS the rarity color.
func _rarity_dot(rarity: String) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(30, 30)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(7)
	sb.bg_color = EQUIPMENT_ICON.RARITY_COLORS.get(rarity, Color(0.95, 0.96, 0.98))
	sb.border_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", sb)
	holder.add_child(dot)
	return holder


## Pure preview over the BASE BACKPACK ownership list. Bulk dismantle protects
## set and cursed equipment just like the former stash backend.
func _preview_pending_dismantle(rarity: String) -> Dictionary:
	var count := 0
	var scrap_total := 0
	for entry in RunManager.pending_loadout:
		var inst := RunManager.as_equip_instance(entry)
		if not _bulk_pending_match(inst, rarity):
			continue
		count += 1
		scrap_total += _dismantle_value(inst)
	return {"count": count, "scrap": scrap_total}


func _bulk_pending_match(inst: Dictionary, rarity: String) -> bool:
	if inst.is_empty() or bool(inst.get("cursed", false)):
		return false
	if str(inst.get("set_id", "")) != "":
		return false
	var item_rarity := str(inst.get("rarity", "common"))
	if not item_rarity in MetaProgress.BULK_DISMANTLE_RARITIES:
		return false
	return rarity == "" or item_rarity == rarity


func _dismantle_value(inst: Dictionary) -> int:
	var rarity := str(inst.get("rarity", "common"))
	var amount := int(
		MetaProgress.DISMANTLE_SCRAP.get(
			rarity, MetaProgress.DISMANTLE_SCRAP["common"]
		)
	)
	if bool(inst.get("cursed", false)):
		amount += 5
	return amount


## Remove every matching BASE BACKPACK entry, then grant the summed Scrap once.
## Returns the same {count, scrap} shape as the legacy stash API for testability.
func _dismantle_pending_by_rarity(rarity: String) -> Dictionary:
	var kept: Array = []
	var count := 0
	var scrap_total := 0
	for entry in RunManager.pending_loadout:
		var inst := RunManager.as_equip_instance(entry)
		if _bulk_pending_match(inst, rarity):
			count += 1
			scrap_total += _dismantle_value(inst)
		else:
			kept.append(entry)
	if count <= 0:
		return {"count": 0, "scrap": 0}
	RunManager.pending_loadout.clear()
	RunManager.pending_loadout.append_array(kept)
	_selected_index = -1
	_selected_affix_index = -1
	MetaProgress.add_scrap(scrap_total)
	_refresh_character_backpack()
	return {"count": count, "scrap": scrap_total}


## Bulk-dismantle confirm: a centered glass modal (matches the tier-confirm popup
## style) showing the pre-scanned count + scrap, wired to the real dismantle only
## on 确认.
func _show_bulk_confirm(rarity: String) -> void:
	if get_node_or_null("ForgeBulkConfirm") != null:
		return
	var prev: Dictionary = _preview_pending_dismantle(rarity)
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
			var res: Dictionary = _dismantle_pending_by_rarity(rar)
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
	# ribbon_rarity_corner, not icon_star: the star is the charm attribute's icon.
	_content.add_child(_picker_row("ribbon_rarity_corner", tr("UI_FORGE_RARITY"), rarity_opt))

	# Craft action. The result enters the base backpack, never the permanent stash.
	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var backpack_has_room := (
		RunManager.pending_loadout.size() < RunManager.effective_backpack_size()
	)
	var enabled := int(MetaProgress.scrap) >= cost and backpack_has_room
	_content.add_child(
		_icon_action_row("icon_hammer", tr("UI_FORGE_CRAFT_VERB"), cost, enabled, _on_craft_pressed)
	)


## Spend Scrap and mint a fresh BASE BACKPACK item of the selected slot + rarity.
func _on_craft_pressed() -> void:
	var cost := int(CRAFT_COST.get(_craft_rarity, CRAFT_COST["common"]))
	var base_id := str(CRAFT_BASE_BY_SLOT.get(_craft_slot, ""))
	if base_id == "":
		return
	# Mint BEFORE charging so a bad base id can never eat Scrap.
	var inst: Dictionary = RunManager.make_equip_instance(base_id, _craft_rarity)
	if inst.is_empty():
		return
	if RunManager.pending_loadout.size() >= RunManager.effective_backpack_size():
		return
	if not MetaProgress.spend_scrap(cost):
		return
	RunManager.pending_loadout.append(inst)
	AudioManager.play_sfx("forge_craft")
	_refresh_character_backpack()
	_rebuild()


# --- REFORGE tab ---------------------------------------------------------------


func _fill_reforge() -> void:
	_content.add_child(_build_drop_slot(false))
	var sel := _selected_instance()
	if sel.is_empty():
		_content.add_child(_bench_empty_hint())
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

	_append_curse_action(sel)


## Reforge the PICKED affix. Backend locks the item on the first reforge + climbs
## the cost each time.
func _reforge_selected() -> void:
	if _selected_index < 0 or _selected_affix_index < 0:
		return
	if _reforge_pending_item(_selected_index, _selected_affix_index):
		AudioManager.play_sfx("forge_reforge")
	_rebuild()


## Curse is the tier-3 secondary operation in the Reforge page. Keeping it in
## the same equipment bench avoids a fourth navigation mode while preserving the
## existing backend, cost, audio, and backpack-only ownership rules.
func _append_curse_action(sel: Dictionary) -> void:
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 8)
	_content.add_child(divider)

	var title := Label.new()
	title.text = tr("UI_FORGE_CURSE_VERB")
	_style_label(title, 15, Color(0.94, 0.68, 0.36), 1)
	_content.add_child(title)

	var unlocked := MetaProgress.building_can("forge", "curse")
	var cursed := bool(sel.get("cursed", false))
	var enabled := unlocked and int(MetaProgress.scrap) >= CURSE_COST and not cursed
	var idx := _selected_index
	var action := _icon_action_row(
			"icon_bag",
			tr("UI_FORGE_CURSE_VERB"),
			CURSE_COST,
			enabled,
			func() -> void: _curse_item(idx)
	)
	action.name = "ForgeReforgeCurseAction"
	_content.add_child(action)
	if not unlocked or cursed:
		var status := Label.new()
		status.text = (
			tr("UI_FORGE_CURSE_LOCKED")
			if not unlocked
			else _local_text("该装备已经被诅咒。", "This item is already cursed.")
		)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(status, 12, Color(0.72, 0.66, 0.56))
		_content.add_child(status)


## Curse the benched BASE BACKPACK item in place (T3).
func _curse_item(index: int) -> void:
	if not _curse_pending_item(index):
		return
	AudioManager.play_sfx("forge_curse")
	_rebuild()


# --- shared bench pieces -------------------------------------------------------


func _selected_instance() -> Dictionary:
	if _selected_index >= 0 and _selected_index < RunManager.pending_loadout.size():
		return RunManager.as_equip_instance(RunManager.pending_loadout[_selected_index])
	return {}


## The top drop slot / preview panel. `dismantle_on_drop` = true → a drop dismantles
## the item immediately (Dismantle tab); false → a drop benches it for selection
## (Reforge / Curse tabs). The only accepted source is the BASE BACKPACK payload
## emitted by CharacterWindow (`src == "carry"`, carrying the owned entry).
func _build_drop_slot(dismantle_on_drop: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ForgeWorkbenchDropSlot"
	panel.custom_minimum_size = Vector2(0, 132)
	panel.add_theme_stylebox_override("panel", T.ll_inset())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var sel := _selected_instance()
	var slot_cell = BACKPACK_CELL.new()
	slot_cell.name = "ForgeWorkbenchCell"
	slot_cell.custom_minimum_size = BENCH_CELL_SIZE
	var anvil_slot_tex: Texture2D = null
	if dismantle_on_drop and sel.is_empty():
		# Ink language (sheet 08): corner-bracket drop target + a dim anvil ghost
		# (the old drop_slot_anvil baked both in the heavier dashed style).
		anvil_slot_tex = T.lightline_tex(T.INK_SET + "_slot_brackets")
	if anvil_slot_tex != null:
		var slot_rect := TextureRect.new()
		slot_rect.texture = anvil_slot_tex
		slot_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_cell.add_child(slot_rect)
		var ghost := T.lightline_tex("icon_anvil")
		if ghost != null:
			var ghost_rect := TextureRect.new()
			ghost_rect.texture = ghost
			ghost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			ghost_rect.offset_left = 26
			ghost_rect.offset_top = 26
			ghost_rect.offset_right = -26
			ghost_rect.offset_bottom = -26
			ghost_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ghost_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ghost_rect.modulate = Color(1, 1, 1, 0.28)
			ghost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_cell.add_child(ghost_rect)
	else:
		var slot_icon = EQUIPMENT_ICON.new()
		slot_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sel.is_empty():
			slot_icon.set_empty("weapon")
		else:
			var b := str(sel.get("base", ""))
			var d: Dictionary = RunManager.get_equipment_data(b)
			# Keep the same central resolver used by inventory drag previews. This
			# also ensures legacy sprite ids resolve to the approved shell art.
			slot_cell.preview_tex = EQUIPMENT_ICON.resolve_equipment_texture(
				str(d.get("sprite", "")),
				str(d.get("slot", "head")),
				str(sel.get("rarity", "common"))
			)
			slot_icon.set_equipment(
				str(d.get("slot", "head")),
				Settings.t("EQUIP_%s_NAME" % b, str(d.get("name", b))),
				str(d.get("sprite", "")),
				str(sel.get("rarity", "common"))
			)
		slot_cell.add_child(slot_icon)
	slot_cell.can_accept = func(d):
		if d.get("src") != "carry" or d.get("entry") == null:
			return false
		return RunManager.pending_loadout.find(d.get("entry")) >= 0
	slot_cell.perform_drop = func(d): _select_dropped(d)
	center.add_child(slot_cell)
	return panel


func _select_dropped(d: Dictionary) -> void:
	if d.get("src") != "carry" or d.get("entry") == null:
		return
	var idx := RunManager.pending_loadout.find(d.get("entry"))
	if idx >= 0:
		_select_item(idx)


func _select_item(index: int) -> void:
	if index < 0 or index >= RunManager.pending_loadout.size():
		return
	_selected_index = index
	_selected_affix_index = -1
	AudioManager.play_sfx("ui_click")
	_rebuild()


func _dismantle_selected(index: int) -> void:
	if _dismantle_pending_item(index):
		AudioManager.play_sfx("forge_dismantle")
	_rebuild()


func _dismantle_pending_item(index: int) -> bool:
	if index < 0 or index >= RunManager.pending_loadout.size():
		return false
	var inst := RunManager.as_equip_instance(RunManager.pending_loadout[index])
	if inst.is_empty():
		return false
	var amount := _dismantle_value(inst)
	RunManager.pending_loadout.remove_at(index)
	_selected_index = -1
	_selected_affix_index = -1
	MetaProgress.add_scrap(amount)
	_refresh_character_backpack()
	return true


## Reforge one affix on a base-backpack entry, preserving the existing first-pick
## lock and escalating-cost semantics from the former stash backend.
func _reforge_pending_item(index: int, affix_index: int) -> bool:
	if index < 0 or index >= RunManager.pending_loadout.size():
		return false
	var inst := RunManager.as_equip_instance(RunManager.pending_loadout[index])
	if inst.is_empty():
		return false
	var affixes := RunManager.equip_affixes(inst)
	if affix_index < 0 or affix_index >= affixes.size():
		return false
	if AFFIX_POOL.is_curse(affixes[affix_index]):
		return false
	var locked := int(inst.get("reforge_index", -1))
	if locked >= 0 and locked != affix_index:
		return false
	var cost := MetaProgress.reforge_cost_for(inst)
	if not MetaProgress.spend_scrap(cost):
		return false
	inst["affixes"] = AFFIX_POOL.reroll_at(affixes, affix_index)
	inst["reforge_index"] = affix_index
	inst["reforge_count"] = int(inst.get("reforge_count", 0)) + 1
	RunManager.pending_loadout[index] = inst
	_refresh_character_backpack()
	return true


func _curse_pending_item(index: int) -> bool:
	if index < 0 or index >= RunManager.pending_loadout.size():
		return false
	var inst := RunManager.as_equip_instance(RunManager.pending_loadout[index])
	if inst.is_empty() or bool(inst.get("cursed", false)):
		return false
	if not MetaProgress.spend_scrap(CURSE_COST):
		return false
	inst["affixes"] = AFFIX_POOL.roll("cursed")
	inst["cursed"] = true
	inst["rarity"] = "cursed"
	RunManager.pending_loadout[index] = inst
	_refresh_character_backpack()
	return true


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


# --- concept action-row builders ----------------------------------------------


## An action row: left icon + one full-width verb button. The former separate
## right-arrow CTA was visually noisy and easy to read as a second action.
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
	if cost < 0:
		btn.name = "ForgeSingleDismantleButton"
		for state in ["normal", "hover", "pressed", "disabled"]:
			btn.add_theme_stylebox_override(state, _dismantle_action_style(state, true))
		btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		_apply_dark_button(btn)
	if cost > 0:
		btn.add_child(T.overlay_cost_badge(cost, "scrap", 15, 16, -10, -72))
	elif cost < 0:
		btn.add_child(T.overlay_cost_badge(abs(cost), "scrap", 15, 16, -10, -72))
	if enabled:
		btn.pressed.connect(cb)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.5)
	row.add_child(btn)
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
	btn.add_theme_stylebox_override("hover", _button_hover_style())
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


func _button_hover_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.12, 0.10, 0.92)
	st.border_color = Color(0.76, 0.58, 0.28, 0.75)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	return st


func _dismantle_action_style(state: String, primary: bool) -> StyleBox:
	var fallback := T.ll_button(state) if primary else T.ll_button_olive(state)
	var style := T.lightline_box("forge_dismantle_action", fallback, 24, 20)
	var textured := style as StyleBoxTexture
	if textured == null:
		return style
	var tint := Color.WHITE if primary else Color(0.62, 0.67, 0.50, 1.0)
	match state:
		"hover":
			tint = tint.lightened(0.10)
		"pressed":
			tint = tint.darkened(0.16)
		"disabled":
			tint = Color(tint.r, tint.g, tint.b, 0.42)
	textured.modulate_color = tint
	textured.content_margin_left = 18
	textured.content_margin_right = 18
	textured.content_margin_top = 9
	textured.content_margin_bottom = 10
	return textured


## Forge and CharacterWindow are siblings under WindowLayer. Repaint the visible
## backpack immediately after a craft/dismantle/reforge/curse mutation.
func _refresh_character_backpack() -> void:
	var layer := get_parent()
	if layer == null:
		return
	var character := layer.get_node_or_null("CharacterWindow")
	if character != null and character.has_method("refresh"):
		character.call("refresh")


func _style_label(label: Label, font_size: int, color: Color, outline: int = 0) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		label.add_theme_constant_override("outline_size", outline)


func _local_text(zh: String, en: String) -> String:
	return zh if Settings.language == "zh" else en
