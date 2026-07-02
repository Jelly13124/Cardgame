# 黑市/卡系统重构 · 建筑 UI 统一 · 货币图标 · ESC 设置

**Date:** 2026-07-02
**Status:** Design approved — proceeding straight to plan + overnight execution.
**Topic:** shop-cards-ui-currency-esc

---

## 目标

一晚无人值守完成四块:(A) 删掉基地黑市的卡系统 + 黑市分级(工具/装备/刷新);(B) 统一 5 个建筑界面的视觉主题;(C) 货币用图标显示 + 基地 ESC 调出设置。每阶段 smoke gate,本地 commit,**不 push**。

---

## A. 商店 + 卡系统重构

### A1. 删卡系统(仅基地黑市 Market)
- `market_screen.gd`:删 **card_unlock**(T1)+ **card_shop**(T3)两段 UI 及其卡工厂渲染。
- `meta_progress.gd`:删 `unlock_card()` / `buy_card_caps()` 及字段 `unlocked_cards` / `purchased_cards`;删 `purchased_cards` 注入下一局 deck 的逻辑;save 迁移读旧存档时忽略这两个键(不报错)。
- `data_validator.gd` / 其它:移除对 `unlocked_cards` 的任何消费。
- **地图商人 `shop_scene` 不动**(照卖 6 卡 + 3 工具 + 3 遗物 + 洗牌 75);它的买卡走 `add_card_to_deck`(临时进当前 run deck),与被删的黑市永久卡系统无关。

### A2. 抽卡池改为"全默认可抽"
- 抽卡池(loot draft / 任何读 `unlocked_cards` 或 `INITIAL_CARD_POOL` 决定可 draft 的地方)改为**目录扫描 `card_info/player/*.json`**,排除:`type == curse`、基础卡 `strike` / `defend`、以及**他英雄专属**(`HERO_EXCLUSIVE_CARDS` 里非当前英雄的)。
- `INITIAL_CARD_POOL` 常量与 `unlocked_cards` 门槛不再用于 draft gating(可删或降级为注释);hero-exclusive gating 保留。

### A3. 黑市 Market 分级(tier-gated)
BUILDING_DEFS `market` 保持 3 级(tier_costs `[140, 240]`)。功能按 tier 累加:
- **T1 — 工具铺**:从全工具池随机上架 `N` 件(默认 3),**Caps** 定价(默认 tunable `MARKET_TOOL_PRICE`,如 40 Caps);点击购买进背包工具槽/背包。
- **T2 — 装备铺**:额外上架装备(**掉落式滚词条的通用壳实例**,默认 3,Caps 按稀有度定价，沿用现状 equip_shop 的 `_roll_equip_stock` + 定价，仅 gate 到 T2)。
- **T3 — 刷新**:额外一个「刷新商店」按钮,花 **Caps**(默认 `MARKET_REFRESH_BASE` 如 20,每次 +递增),重 roll 当前 tier 的工具/装备库存。
- 未达 tier 的分区显示锁定态(沿用现状 locked-preview 风格)。

---

## B. 建筑界面 UI 统一(5 屏)

- **不用 web 前端 skill**(产 HTML/CSS,和 Godot GDScript UI 不通)。借鉴其设计品味,**直接重做 Godot 共享主题**。
- 在 `building_screen_base.gd`(5 屏共享 shell)集中定义一套 **theme tokens**(配色层次:底/面板/面板深/描边/金色强调/暗字;字体级别:标题/小节/正文/次要;圆角、内外边距、按钮三态样式、卡片/行样式的 StyleBox helper)。5 屏统一调用。
- 顺带理顺 `forge_screen` / `outpost_screen` 的堆叠布局(截图里的行距/对齐/分区留白)。
- **风格保持** Offbeat 废土深色(不换风格,只提层次与精致度、留白与对齐)。
- 验证以"启动干净 + 视觉不崩"为准(smoke);像素级对比非必需。

---

## C. 两个小改

### C1. 货币图标显示
- 新增一个共享 helper（如 `wasteland_theme.gd` 或一个小工具函数）：给定 `(amount, currency)` 产出「数字 + 图标」的显示(`HBoxContainer`:Label 数字 + TextureRect 图标),图标取 `run_system/assets/images/home/currency/{core,caps,scrap}.png`。
- 替换所有"数字 + 核心/瓶盖/废料**文字**"的显示:建筑界面的花费/余额、`home_base` 顶栏三货币、outpost 升级行的「花费 N 核心」等。**不再出现"110 核心""瓶盖"字样**,改为 `110 <core图标>`。
- 保留纯文本 fallback(图标缺失时)。

### C2. 基地 ESC 调出设置
- `home_base_scene.gd` + `building_screen_base.gd`:`_unhandled_input` 捕获 `ui_cancel`(ESC)→ 打开现有 `settings_panel`(或 `pause_panel`,取战斗外合适的那个)。
- 建筑界面内按 ESC:优先关当前建筑详情页返回基地总览;在总览按 ESC → 开设置。(即 ESC 逐层退出 + 总览层开设置。)以现有交互为准,不破坏"点 X 关闭"。

---

## 受影响文件(概览)
| 区 | 文件 |
|---|---|
| A | `run_system/ui/buildings/market_screen.gd`(重写)、`run_system/core/meta_progress.gd`(删卡系统 + save 迁移)、`run_system/core/run_manager.gd`(draft pool 扫描 + 删 unlocked/purchased 消费)、翻译 `ui_build_market.csv` |
| B | `run_system/ui/buildings/building_screen_base.gd`(theme tokens)、`forge_screen.gd` / `outpost_screen.gd`(布局)、可能 `run_system/ui/theme/wasteland_theme.gd` |
| C | `wasteland_theme.gd`（货币 helper）、`home_base_scene.gd`、`building_screen_base.gd`（ESC）、各 building screen 的花费/余额显示 |

## 验证(每阶段)
- `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → schemas passed + clean boot(注意:脚本内 baked 的 `_console.exe` 路径本机无效,必须用 `GODOT_BIN=Godot.exe`)。
- 删卡系统后:确认无悬空引用(draft/market/save 不再读 unlocked/purchased)。
- catalog 无需改（卡未增删；工具/装备数据未变）。
- MCP 运行时截图验证 UI 因需弹窗、且过夜用户可能不在，**默认不做**;以 smoke + 代码审查为准。

## 默认(实现时取,用户 review 可改)
- MARKET_TOOL_PRICE ≈ 40 Caps；MARKET_REFRESH_BASE ≈ 20 Caps(+递增)；每 tier 上架 3 件。`[tunable]`
- lv2 装备沿用现状 `_roll_equip_stock` + Caps 稀有度价。
- B 保持废土风,只提层次/精致度;不新增美术(用现有资源 + StyleBox)。
- 货币图标覆盖全部基地界面的货币数字。

## 未覆盖 / 风险
- 删 `unlocked_cards` 牵动 draft pool 构建——需找全所有消费点(loot_reward / run_manager / market),逐一改为扫描池。
- B 的 UI 重做无法在过夜 headless 下做视觉验收（只能 smoke 保证不崩）；早上人工过目。
