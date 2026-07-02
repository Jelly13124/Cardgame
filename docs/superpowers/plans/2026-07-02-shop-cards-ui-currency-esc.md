# 黑市/卡系统 · 建筑 UI 统一 · 货币图标 · ESC 设置 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`. **Overnight unattended run:** smoke-gate each phase, commit locally, DO NOT push.

**Goal:** 删基地黑市卡系统 + 黑市分级(工具/装备/刷新);统一 5 建筑界面主题;货币用图标显示;基地 ESC 调设置。

**Architecture:** 复用现有 building/theme/meta 结构。删卡走 meta_progress + run_manager + market_screen;卡池改目录扫描;黑市按 building tier gate 工具/装备/刷新;UI 统一在 `building_screen_base` 的 theme tokens;货币 helper 在 `wasteland_theme.gd`;ESC 复用 `PausePanel.open`。

**Tech Stack:** Godot 4.6 GDScript. 验证 = `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`(schemas passed + clean boot). Commit local only.

---

## Phase A — 商店 + 卡系统重构

### Task A1: 删卡系统 + 卡池改目录扫描
**Files:** `run_system/core/meta_progress.gd`, `run_system/core/run_manager.gd`

- [ ] `meta_progress.available_card_pool()`(~381)改为**目录扫描**:遍历 `res://battle_scene/card_info/player/*.json`,排除 `type=="curse"`、`strike`/`defend`、以及 `HERO_EXCLUSIVE_CARDS` 里非当前英雄的 id;返回该 pool。不再引用 `unlocked_cards`。
- [ ] 删 `unlock_card()`(~399)、`buy_card_caps()`(~415);删字段 `unlocked_cards`/`purchased_cards`(163/167)、reset(128-129)、clear(822)、save 写(856-857)。load(900-911)改为**忽略**旧键(不赋值、不报错)。
- [ ] `run_manager.gd:~712` 删注入 `MetaProgress.purchased_cards` 到 deck 的循环(及 699 附近注释)。
- [ ] `INITIAL_CARD_POOL`(271)：若 `available_card_pool` 不再用它,降级为注释或删(确认无其它引用后)。
- [ ] Smoke。Commit `feat(shop): all cards draftable by default; remove base card-unlock/purchase system`.

### Task A2: 黑市 market_screen 重写(工具/装备/刷新 by tier)
**Files:** `run_system/ui/buildings/market_screen.gd`(重写内容构建), 翻译 `assets/translations/ui_build_market.csv`

- [ ] 删 card_unlock(T1)+ card_shop(T3)两段 + 卡工厂(`_card_factory`/CARD_FACTORY_SCENE/CARD_DIR/卡价常量)。
- [ ] 内容按 tier 累加:**T1** 工具区(全工具池随机 3,Caps 价 `MARKET_TOOL_PRICE=40`,购买→背包);**T2** 装备区(沿用 `_roll_equip_stock` + Caps 稀有度价,gate T2);**T3** 刷新按钮(Caps `MARKET_REFRESH_BASE=20`,每次 +10 递增;重 roll 工具+装备库存)。未达 tier 显示锁定态。
- [ ] 翻译:删 card_unlock/card_shop 文案键;加工具区/刷新键(`UI_BUILD_MARKET_*`)。
- [ ] Smoke + 若可 MCP 只读确认库存(过夜跳过 MCP)。Commit `feat(shop): market tiers — T1 tools / T2 equipment / T3 refresh (Caps)`.

---

## Phase B — 建筑界面 UI 统一(5 屏)

### Task B1: building_screen_base theme tokens
**Files:** `run_system/ui/buildings/building_screen_base.gd`(+ 可能 `run_system/ui/theme/wasteland_theme.gd`)

- [ ] 在 base 集中定义 theme tokens:配色(bg/panel/panel_dark/line/gold/txt/dim + 三货币色)、字体级别(title/section/body/dim px)、圆角/内外边距常量、按钮三态 StyleBox helper、行/卡片 StyleBox helper。保持 Offbeat 废土深色,提层次/留白/对齐。
- [ ] 提供 base 方法供子屏调用(如 `_section_header(text)`, `_styled_button(text)`, `_panel_row()`),减少各屏重复样式代码。
- [ ] Smoke(不崩)。Commit `refactor(ui): shared theme tokens + styled helpers in building_screen_base`.

### Task B2: forge + outpost(+其余屏)套用统一样式 + 布局理顺
**Files:** `run_system/ui/buildings/{forge,outpost,clinic,market,warehouse}_screen.gd`

- [ ] forge/outpost 用 B1 的 helper 重排:分区留白、行对齐、按钮/价签统一;修截图里的堆叠感(工作台词条行、锻造区;outpost 升级行)。
- [ ] clinic/market/warehouse 同套 theme(至少配色/字体/按钮一致);不重排其复杂布局除非明显错位。
- [ ] Smoke。Commit `feat(ui): unify all 5 building screens on the shared theme; tidy forge/outpost layout`.

---

## Phase C — 货币图标 + ESC 设置

### Task C1: 货币图标显示
**Files:** `run_system/ui/theme/wasteland_theme.gd`(helper), 各 building screen + `home_base_scene.gd`

- [ ] 加 helper `currency_row(amount:int, currency:String) -> Control`:HBox = 数字 Label + 图标 TextureRect(`res://run_system/assets/images/home/currency/{core|caps|scrap}.png`),图标缺失时纯文本 fallback。
- [ ] 替换所有"数字+核心/瓶盖/废料**文字**"处:建筑花费/余额、home_base 顶栏三货币、outpost 升级行「花费 N 核心」等。目标:界面不再出现"核心/瓶盖/废料"中文货币名,改数字+图标。
- [ ] Smoke。Commit `feat(ui): show currencies as amount + icon (core/caps/scrap) instead of text`.

### Task C2: 基地 ESC 调设置
**Files:** `run_system/ui/home_base_scene.gd`, `run_system/ui/buildings/building_screen_base.gd`

- [ ] home_base:`_unhandled_input` 捕获 `ui_cancel` → 复用现有打开设置的调用(`PausePanel.open(self, false, ...)` 或 home_base 已有的 settings 入口)。
- [ ] building_screen_base:`_unhandled_input` `ui_cancel` → 先关当前详情页返回总览(若在详情页);总览层由 home_base 处理开设置。不破坏现有「点 X 关闭」。
- [ ] Smoke。Commit `feat(ui): ESC opens settings from home base / backs out of building screens`.

---

## Phase D — 最终验证
- [ ] 全量 smoke:schemas passed + clean boot。
- [ ] grep 确认无悬空:`unlocked_cards`/`purchased_cards`/`unlock_card`/`buy_card_caps` 零剩余引用;"核心/瓶盖/废料"文字货币显示已清。
- [ ] 早上人工过目提醒:B 的 UI 视觉、黑市 tier 行为需窗口内确认(过夜 headless 只保证不崩)。

## 验证约定 / 默认
- 每 Task 末尾 smoke(`GODOT_BIN=Godot.exe`)。Commit 本地,**不 push**。
- `[tunable]`:MARKET_TOOL_PRICE=40 / MARKET_REFRESH_BASE=20(+10 递增) / 每 tier 3 件。
- 无 pytest;UI/掉落逻辑靠 smoke + 代码审查 + 无头脚本(如需)。

## 风险
- 删 `unlocked_cards`/`purchased_cards` 若有遗漏消费点 → smoke 或 grep 抓;A1 先跑 grep 确认全删。
- B UI 无法过夜做视觉验收;只保证 boot clean,早上人工看。
- market_screen 重写较大 → controller 主导(跨 UI + 数据),机械子步可派 subagent。
