# 可拖动窗口 UI 重构 — 角色界面 + 铁匠铺(暗黑4 风)

**Date:** 2026-07-02
**Status:** Design approved (brainstorm).
**Topic:** draggable-windows-character-forge-ui

---

## 目标

把基地从"点建筑→全屏 overlay"改成暗黑4 式的**可拖动并存窗口**:按 **i** 开**角色界面**(装备/背包/loadout),点**铁匠铺**弹出**工艺窗口**(4-tab),两窗口并排、可拖动、跨窗口拖装备。货币做成**全局常驻 top bar**。删掉**仓库 building**(功能拆分),黑市加**资源交易**。本轮**只做角色界面 + 铁匠铺**两个窗口;诊所/前哨站保持全屏。

## 复用现状(重要 — 内容基本都在,这次主要换外壳)

- `run_system/ui/equipment_panel.gd`:局内角色面板 = LEFT 角色 / MIDDLE 5 装备槽 / RIGHT 背包网格 + 拖拽(`backpack_cell.gd` 的 `_get_drag_data/_can_drop_data/_drop_data`)。
- `run_system/ui/buildings/warehouse_screen.gd`:基地 loadout = 英雄选择 + 5 装备槽(drop 目标)+ stash 网格(可拖);拖拽 mirror equipment_panel。含 T3 **资源交易**。
- `run_system/ui/buildings/forge_screen.gd`:四功能全在(dismantle/reforge/craft/curse)+ 工作台 drop-slot。
- `run_system/ui/backpack_cell.gd`:Godot 原生拖拽 wrapper（跨窗口拖拽天然可用）。
- `run_system/ui/home_base_scene.gd`:货币 HUD、出发门(`UI_HOME_START_RUN`「开始新征程」)、难度 bar、building tiles、`BuildingOverlay`(全屏)。

## 设计

### 1. `DraggableWindow` 基类(唯一"从零"的件)
`run_system/ui/window/draggable_window.gd`(+ 一个轻量 `WindowLayer` 管理 z-order)。
- 标题栏拖动(gui_input → 跟随鼠标,夹在视口内);右上 ✕ 关闭;点击窗口→置顶(`move_to_front`);初始居中(可后续记忆位置);ESC 关**最上层**窗口。
- 角色窗、forge 窗都继承它。多窗口可同时存在。

### 2. `CharacterWindow`(按 **i** 或 top bar 按钮开/关)
`run_system/ui/window/character_window.gd`，继承 `DraggableWindow`。
- **顶部**:hero picker(**仅基地模式**显示)。
- **主体**:5 装备槽 + 工具槽 + paper-doll + 背包/stash 网格 + 拖拽。
- **三模式(`mode`)**:
  - `base`:英雄选择 + stash 网格 + loadout(拖 stash→槽,写 `RunManager.pending_equipped` / `pending_hero_id`)。**可开 forge 并存拖拽**。
  - `map`:当前 `RunManager` 装备 + 背包(可拖换/整理)。
  - `battle`:只读(看当前装备/背包,不能换 — 符合"战斗不可换装备")。
- 把 `equipment_panel` + `warehouse` 的槽位/网格/拖拽逻辑**合并**进这一个组件（按 mode 选数据源）。
- **入口**:`i` 键在基地 / 地图 / 战斗都能开(战斗=只读)。基地 top bar 上也有一个"角色/背包"按钮。

### 3. `ForgeWindow`(点铁匠铺 building tile 弹出)
`run_system/ui/window/forge_window.gd`，继承 `DraggableWindow`。
- **顶部 4-tab 小 bar:打造 / 拆解 / 重铸 / 诅咒**（复用 forge_screen 的四功能，tier-gate 沿用 `building_can("forge", ...)`）。
- 工作台 drop-slot:接受从 `CharacterWindow` 的 stash/背包**跨窗口拖来的**装备（`_can_drop_data/_drop_data`）。
- 基地里点铁匠铺 → 开 forge 窗（**不再全屏**）；与角色窗并存。

### 4. 黑市 Market 调整
`run_system/ui/buildings/market_screen.gd` + `meta_progress.gd` `BUILDING_DEFS["market"]`。
- **lv1 工具(+ 刷新默认解锁，不再 gate) / lv2 加装备 / lv3 加资源交易**。
- 把 warehouse 的**资源交易**(core/caps/scrap 互换)UI + 逻辑搬到 market lv3。
- `functions` 由 `{tool_shop:1, equip_shop:2, refresh:3}` 改为 `{tool_shop:1, equip_shop:2, resource_convert:3}`；refresh 不再走 `building_can` gate（默认可用）。

### 5. 全局货币 top bar
`run_system/ui/window/currency_top_bar.gd`（从 home_base 的 `_add_currency_hud` 提取）。
- core/caps/scrap 数字+图标，**常驻在窗口上层**（拖动窗口不会盖住余额）。
- 加一个**角色/背包入口按钮**（替代被删的仓库 tile）。
- 出发"开始新征程" + 难度 bar 保持（视觉可贴 top bar 风）。

### 6. 删除仓库 building
- `BUILDING_DEFS` 去掉 `warehouse`；`home_base_scene` 布局从 5 building → **4**（诊所/黑市/前哨站/铁匠铺）；去掉仓库 tile。
- `warehouse_screen.gd`:loadout/stash/hero 逻辑迁入 `CharacterWindow(base)`；资源交易迁入 market；迁移完删除该 screen。
- 存档兼容:旧存档的 `warehouse` building tier 键读时忽略（不报错）；stash/pending_equipped 数据不变。

### 7. 不变
- 诊所 / 前哨站:仍全屏 overlay。铁匠铺改窗口（见 §3）。

## 受影响文件
| 区 | 文件 |
|---|---|
| 窗口基类 | 新 `window/draggable_window.gd`, `window/window_layer.gd`(z-order) |
| 角色窗 | 新 `window/character_window.gd`（合并 equipment_panel + warehouse loadout）; `equipment_panel.gd`/`warehouse_screen.gd` 逻辑迁移后清理 |
| forge 窗 | 新 `window/forge_window.gd`（复用 forge_screen 四功能 + 4-tab）; forge 全屏入口改为开窗 |
| 黑市 | `market_screen.gd`（+资源交易 lv3, 刷新默认）; `meta_progress.gd`（BUILDING_DEFS market functions, 删 warehouse def） |
| top bar | 新 `window/currency_top_bar.gd`（提取自 home_base）; `home_base_scene.gd`（4 building 布局, 角色入口, i 键） |
| 入口 | `home_base_scene` / `map_scene` / `battle_scene` 加 `i` 键开 CharacterWindow（对应 mode） |

## 验证
- `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → schemas passed + clean boot。
- 拖拽 / 窗口拖动 / 4-tab / i 键 / 跨窗口拖装备 / top bar 常驻 → **人工窗口内验收**（headless 只保证不崩）。
- 存档兼容:删 warehouse building 后旧存档能读（tier 键忽略）。

## 未决 / 风险
- 合并 equipment_panel + warehouse 成一个组件是本设计最大的一块 — 三模式数据源要清晰隔离。
- 跨窗口拖拽依赖 Godot 原生 drag-drop 在两个 `DraggableWindow` 间正常路由（源在角色窗、目标在 forge 窗）— 需实测。
- 战斗中开只读角色窗不能干扰战斗输入（窗口层吃 ESC/i，但不吃战斗操作）。
- `i` 与现有键位（如背包/角色快捷键）冲突需排查。
