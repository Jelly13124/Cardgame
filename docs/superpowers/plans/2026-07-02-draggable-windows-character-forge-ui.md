# 可拖动窗口 UI(角色窗 + 铁匠铺窗 + top bar + 删仓库)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use `- [ ]`. Smoke-gate each task, commit locally, DO NOT push.

**Goal:** 暗黑4 式可拖动并存窗口:按 i 开角色界面(基地/地图/战斗三模式),点铁匠铺弹 4-tab 工艺窗并与角色窗跨窗拖装备;货币全局 top bar;删仓库 building(loadout→角色窗、资源交易→黑市 lv3);黑市刷新默认解锁。

**Architecture:** 新建 `run_system/ui/window/` 目录:`draggable_window.gd`(基类)+ `window_layer.gd`(z-order/ESC)是唯一从零件;`character_window.gd` 合并 `equipment_panel`(map/battle)+ `warehouse loadout`(base)+ `home_base StashOverlay`(carry 标记);`forge_window.gd` 移植 forge_screen 四功能成 4-tab。拖拽沿用 `backpack_cell.gd` 原生 drag-drop(跨窗口天然可用)。

**Tech Stack:** Godot 4.6 GDScript。验证 = `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`(脚本内 baked 的 `_console.exe` 路径无效,必须传 GODOT_BIN)。无 pytest;交互(拖拽/i键/tab)最终需人工窗口验收,任务内以 clean boot + 代码审查为 gate。项目规则:**新类禁 class_name,用 `extends "res://…/file.gd"` 路径继承 + preload**(ADR-0006)。

**关键现状坐标(执行者先读这些)**
- `run_system/ui/equipment_panel.gd` — 局内角色面板(角色列/5槽/背包网格/工具槽/拖拽),map_scene KEY_I(236-238)与 `bar.character_pressed`(729)打开,节点名 "EquipmentPanel"。
- `run_system/ui/buildings/warehouse_screen.gd` — base loadout(hero picker 125+、slots drop 目标 137+、stash 网格、`RunManager.pending_equipped/pending_hero_id`)+ T3 conversion(38-44 常量、483-600 UI+handler,后端即 `MetaProgress.spend_core/add_caps/spend_caps/add_scrap`)。
- `run_system/ui/home_base_scene.gd` — `BUILDING_ORDER`(18)/`LEFT_BUILDINGS`(23)/`RIGHT_BUILDINGS`(24)/`BUILDING_ACCENTS`(26+);warehouse tile 打开处 198-201、plaque 208;货币 HUD `_add_currency_hud`(136+);StashOverlay(793+,pending_loadout 标记);ESC guard(72-80)。
- `run_system/ui/buildings/forge_screen.gd` — dismantle/reforge/craft/curse 全在 + 工作台(`_bench_index`、affix 行、craft slot/rarity 选择)。
- `battle_scene/battle_ui_manager.gd:322` — 战斗 `view_attributes`(KEY_I,可重绑)处理器。
- `run_system/ui/backpack_cell.gd` — drag/drop wrapper(`_get_drag_data/_can_drop_data/_drop_data`)。
- `meta_progress.gd` `BUILDING_DEFS`:market `functions={tool_shop:1, equip_shop:2, refresh:3}`;warehouse def 待删。

---

## Task W1: DraggableWindow 基类 + WindowLayer

**Files:**
- Create: `run_system/ui/window/draggable_window.gd`
- Create: `run_system/ui/window/window_layer.gd`

- [ ] **Step 1: window_layer.gd**(挂在场景根上的窗口容器;z-order + ESC)

```gdscript
## WindowLayer — hosts all DraggableWindows for a scene. Adds itself above the
## scene UI, brings a clicked window to front, and closes the TOPMOST window on
## ui_cancel (consuming it so the scene's own ESC handler doesn't also fire).
## Usage: WindowLayer.ensure(host_scene).open(window_instance)
extends CanvasLayer

const LAYER_NAME := "WindowLayer"


static func ensure(host: Node) -> CanvasLayer:
	var existing = host.get_node_or_null(LAYER_NAME)
	if existing:
		return existing
	var wl = load("res://run_system/ui/window/window_layer.gd").new()
	wl.name = LAYER_NAME
	wl.layer = 60  # above scene UI, below Tooltip (if any) — adjust if occluded
	host.add_child(wl)
	return wl


## Add a window and center it (cascade-offset if others are open).
func open(win: Control) -> void:
	add_child(win)
	var vp := get_viewport().get_visible_rect().size
	var offset := 30.0 * float(maxi(get_child_count() - 1, 0))
	win.position = (vp - win.size) * 0.5 + Vector2(offset, offset)
	bring_to_front(win)


func bring_to_front(win: Control) -> void:
	move_child(win, get_child_count() - 1)


func has_windows() -> bool:
	return get_child_count() > 0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if get_child_count() == 0:
		return
	var top := get_child(get_child_count() - 1)
	if top is Control and top.has_method("close"):
		top.close()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 2: draggable_window.gd**

```gdscript
## DraggableWindow — base for the floating base-UI windows (character / forge).
## Title-bar drag (clamped to viewport), ✕ close, click-to-front. Subclass via
## `extends "res://run_system/ui/window/draggable_window.gd"` (no class_name,
## ADR-0006) and call `init_window(title, size)` in _init or _ready, then add
## content into `content_root`.
extends PanelContainer

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")

signal closed

var content_root: VBoxContainer
var _drag_active := false
var _drag_offset := Vector2.ZERO
var _title_bar: PanelContainer


func init_window(title: String, win_size: Vector2) -> void:
	custom_minimum_size = win_size
	size = win_size
	add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.09, 0.07, 0.05, 0.98), Color(0.55, 0.38, 0.18), 2, 4))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	_title_bar = PanelContainer.new()
	_title_bar.custom_minimum_size = Vector2(0, 42)
	_title_bar.add_theme_stylebox_override("panel", T.panel_with_shadow(Color(0.14, 0.10, 0.06, 1.0), Color(0.45, 0.30, 0.14), 1, 0))
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_title_input)
	vbox.add_child(_title_bar)

	var bar := HBoxContainer.new()
	_title_bar.add_child(bar)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(lbl)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(close)
	bar.add_child(x)

	content_root = VBoxContainer.new()
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_root)

	# Click anywhere on the window → bring to front.
	gui_input.connect(_on_window_input)


func close() -> void:
	closed.emit()
	queue_free()


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var wl := get_parent()
		if wl and wl.has_method("bring_to_front"):
			wl.bring_to_front(self)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
		_drag_offset = get_global_mouse_position() - global_position
		if event.pressed:
			var wl := get_parent()
			if wl and wl.has_method("bring_to_front"):
				wl.bring_to_front(self)
	elif event is InputEventMouseMotion and _drag_active:
		var vp := get_viewport_rect().size
		global_position = (get_global_mouse_position() - _drag_offset).clamp(Vector2.ZERO, vp - size)
```

- [ ] **Step 3: smoke**(新文件无人引用也必须 parse 干净)
Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → `all schemas passed` + clean boot。
- [ ] **Step 4: commit** `git add run_system/ui/window/ && git commit -m "feat(ui): DraggableWindow base + WindowLayer (z-order, ESC-closes-topmost)"`

---

## Task CH1: CharacterWindow — map/battle 模式(移植 equipment_panel)

**Files:**
- Create: `run_system/ui/window/character_window.gd`(`extends "res://run_system/ui/window/draggable_window.gd"`)
- Reference: `run_system/ui/equipment_panel.gd`(移植源)

- [ ] **Step 1: 骨架 + 模式**

```gdscript
const MODE_BASE := "base"     # home base: hero picker + stash/loadout
const MODE_MAP := "map"       # in-run map: current equipment + backpack (editable)
const MODE_BATTLE := "battle" # in battle: read-only view

var mode: String = MODE_MAP

static func open_window(host: Node, p_mode: String) -> Control:
	var wl = load("res://run_system/ui/window/window_layer.gd").ensure(host)
	# Toggle: if one is already open, close it instead (i is open/close).
	var existing = wl.get_node_or_null("CharacterWindow")
	if existing:
		existing.close()
		return null
	var win = load("res://run_system/ui/window/character_window.gd").new()
	win.name = "CharacterWindow"
	win.mode = p_mode
	wl.open(win)
	return win
```
`_ready()`:`init_window(tr("UI_EQUIP_TITLE"), Vector2(880, 640))` 后按 mode 分发 `_build_map_battle()` / `_build_base()`(CH2)。

- [ ] **Step 2: 移植 map/battle 主体** — 把 `equipment_panel.gd` 的三列布局(角色列 `_build_character_zone`、装备槽列 `_build_equipment_zone`、背包网格 `_build_backpack_zone`)+ 工具槽行 + `_refresh` 信号接线(`RunManager.backpack_changed` 等)移植进 `content_root`。**battle 模式 = 同一布局但只读**:构建 cell 时不给 drag 数据(`backpack_cell` 若无只读开关,给它加 `var locked := false`,在 `_get_drag_data` 开头 `if locked: return null`;槽位 drop 同理 `_can_drop_data` 返回 false)。全屏适配代码(`_fit_to_viewport`)不移植(窗口固定尺寸)。
- [ ] **Step 3: 换入口** — `map_scene.gd`:236-238 的 KEY_I 与 767+ `_open_equipment_panel` 改为 `CharacterWindow.open_window(self, "map")`(保留原先"页面打开时不响应"的 guard,`_is_page_open` 逻辑对窗口同样适用);729 `bar.character_pressed` 同改。`battle_ui_manager.gd:322` `view_attributes` 分支改为 `CharacterWindow.open_window(<battle_scene root>, "battle")`。
- [ ] **Step 4: smoke + 人工点检提示**(headless 只保证不崩;拖拽/只读留给最终人工验收)。
- [ ] **Step 5: commit** `feat(ui): CharacterWindow map/battle modes replace fullscreen equipment panel`

---

## Task CH2: CharacterWindow — base 模式(hero picker + loadout + stash + carry 标记)

**Files:**
- Modify: `run_system/ui/window/character_window.gd`
- Reference: `warehouse_screen.gd`(hero picker 125+、slots/stash 拖拽约定 7-24)、`home_base_scene.gd` StashOverlay(793+)

- [ ] **Step 1: `_build_base()`** — 顶部 hero picker(移植 warehouse `_build_character_column` 的英雄头像选择,写 `RunManager.pending_hero_id`);下面 5 装备槽 = drop 目标(拖 stash 项→槽 = `RunManager.pending_equipped[slot]`,拖回 = 取消;沿用 warehouse 的 hide-while-assigned 语义);stash 网格(`MetaProgress.stash`,8 列,`backpack_cell` 包装可拖)。
- [ ] **Step 2: carry 标记(替代 StashOverlay)** — base 模式 stash cell **左键点击**(非拖动)切换"带入下局"标记(高亮边框),重建 `RunManager.pending_loadout`(语义照抄 home_base `_stash_selected`/`_stash_rebuild` 793+ 的实现)。
- [ ] **Step 3: 换入口 + 删旧** — home_base 的 stash/loadout 按钮与 KEY_I 都改开 `CharacterWindow.open_window(self, "base")`;删 home_base 的 StashOverlay 构建代码及其 ESC guard 引用(72-80 里的 `StashOverlay`)。**equipment_panel.gd 此时已无调用者 → 删除文件**(先 `grep -rn "equipment_panel" run_system battle_scene --include=*.gd` 确认零引用)。
- [ ] **Step 4: smoke。commit** `feat(ui): CharacterWindow base mode (hero+loadout+stash+carry); retire equipment_panel & StashOverlay`

---

## Task F1: ForgeWindow(4-tab)+ 点铁匠铺开双窗

**Files:**
- Create: `run_system/ui/window/forge_window.gd`(`extends draggable_window.gd`)
- Modify: `run_system/ui/home_base_scene.gd`(forge tile 入口)
- Reference: `forge_screen.gd`(四功能移植源)
- Translations: `assets/translations/ui_build_forge.csv`(tab 键名)

- [ ] **Step 1: 窗体 + tab bar** — `init_window(tr("UI_BUILD_FORGE_NAME"), Vector2(560, 700))`;顶部 4 个 toggle 按钮 **打造/拆解/重铸/诅咒**(`UI_FORGE_TAB_CRAFT/DISMANTLE/REFORGE/CURSE`,新增翻译键 en+zh),按 `MetaProgress.building_can("forge", …)` 灰掉未解锁 tab;下方内容区按选中 tab 重建。
- [ ] **Step 2: 移植四功能** — 从 forge_screen 移植:工作台 drop-slot(接受 `backpack_cell` 拖来的 stash 项;`_can_drop_data` 校验数据形状同 warehouse 约定)、affix 行选择 + 重铸(锁定词条/递增费)、拆解、打造(slot+品质选择)、诅咒。数据后端全部沿用 `MetaProgress.dismantle_stash_item / reforge_stash_item_affix / curse_stash_item` 等,不改逻辑。
- [ ] **Step 3: 双窗入口** — home_base forge tile(177-179)改为:`ForgeWindow` + `CharacterWindow(base)` **并排打开**(forge 居左、角色窗居右,各偏移定位——草图的"右边装备拖到左边");不再走 `_open_building_screen("forge")` 全屏。**forge_screen.gd 删除**(先 grep 零引用;`building_screen_base` 的 convention-load 对不存在的 screen 要么不再被调用要么安全跳过)。
- [ ] **Step 4: smoke。commit** `feat(ui): ForgeWindow with craft/dismantle/reforge/curse tabs; forge opens beside character window`

---

## Task M1: 黑市 lv3 资源交易 + 刷新默认解锁

**Files:**
- Modify: `run_system/ui/buildings/market_screen.gd`、`run_system/core/meta_progress.gd`(BUILDING_DEFS)、`assets/translations/ui_build_market.csv`

- [ ] **Step 1** — `BUILDING_DEFS["market"].functions` → `{tool_shop:1, equip_shop:2, resource_convert:3}`;market_screen 的刷新按钮不再 `building_can` gate(T1 起可用)。
- [ ] **Step 2** — 把 warehouse 的 conversion(常量 CONV_*、`_conversion_row`、两个 handler)搬进 market_screen,gate `building_can("market", "resource_convert")`;翻译键 `UI_WAREHOUSE_CONVERT_*` 若仅此用 → 改名 `UI_MARKET_CONVERT_*` 搬到 ui_build_market.csv(旧键删)。
- [ ] **Step 3** — smoke。commit `feat(shop): market T3 resource conversion (from warehouse); refresh unlocked by default`

---

## Task M2: 删除仓库 building + top bar

**Files:**
- Modify: `run_system/ui/home_base_scene.gd`、`meta_progress.gd`
- Create: `run_system/ui/window/currency_top_bar.gd`
- Delete: `run_system/ui/buildings/warehouse_screen.gd`
- Translations: `assets/translations/ui_build_warehouse.csv`(清死键)、`ui_home.csv`

- [ ] **Step 1: 删 warehouse building** — `BUILDING_DEFS` 删 warehouse 条目(`get_building_tier` 对残留存档键只是读 dict,天然兼容;确认无 `building_can("warehouse", …)` 残留——conversion 已迁);home_base:`BUILDING_ORDER`/`BUILDING_ACCENTS` 去 warehouse、删 tile(198-201)/plaque(208)/tier 按钮;布局保持 2左+门+2右(门上方空出)。`warehouse_screen.gd` 删除(先 grep 零引用)。翻译:`ui_build_warehouse.csv` 中已无引用的键删除(被 CharacterWindow 复用的键先迁到 `ui_equipment.csv` 再删源)。
- [ ] **Step 2: currency_top_bar.gd** — 把 home_base `_add_currency_hud`(136+)提取成 `currency_top_bar.gd`(CanvasLayer,layer=70 高于 WindowLayer):三货币 `T.currency_row` + **角色/背包按钮**(开 `CharacterWindow(base)`)。home_base 改用它;出发门 + 难度 bar 不动。
- [ ] **Step 3** — smoke + `grep -rn "warehouse" run_system battle_scene --include=*.gd`(仅允许注释/历史文档提及,代码零引用)。commit `feat(ui): global currency top bar with character button; remove warehouse building`

---

## Task V: 最终验证 + 文档

- [ ] 全量 smoke;greps:`equipment_panel|warehouse_screen|StashOverlay` 代码零引用。
- [ ] PRD(基地 5→4 building、warehouse 行删除/迁移说明、i 键角色窗)+ PROJECT_STRUCTURE(新 window/ 目录、market lv3、删 warehouse)同步;`ui_home.csv` 里 warehouse flavour 文案清理。
- [ ] commit `docs: sync PRD/PROJECT_STRUCTURE for window UI + warehouse removal`。
- [ ] 报告人工验收清单:i 键三场景、拖拽跨窗、4-tab、top bar 常驻、ESC 关窗层级、删仓库后旧存档载入。

## 风险与守则
- **每任务先 grep 后删**;`class_name` 禁新增;不 push;translations 改后如需立即生效跑一次 `godot --headless --import`。
- 战斗只读窗不得吃战斗输入(WindowLayer 只消费 ui_cancel;backpack_cell.locked 挡拖拽)。
- 跨窗拖拽若 Godot drag 在两 CanvasLayer 间不路由(实测才知),回退方案:forge 窗内嵌一个"从仓库选择"网格(点选替代拖拽)——报告 DONE_WITH_CONCERNS 并说明。
