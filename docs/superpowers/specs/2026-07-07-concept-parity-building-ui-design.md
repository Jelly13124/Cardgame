# 概念图对齐:基地四栋楼 UI 重构 + 组件库 Design Spec

**Date:** 2026-07-07  **Status:** Approved (owner) → implement.
**Scope:** 用 Codex 的 lightline 组件 sheet + 四栋楼概念图,把基地建筑 UI 重构成**和概念图 1:1**,
并装上真实逻辑(含批量拆解新功能 + 悬赏迁到前哨站)。

## 素材

- **组件 sheet**(4 张,`run_system/assets/images/ui_kit_imagegen_v2_lightline/transparent_sheets/`):
  01 basic_controls(窗框/标题牌/红✕/按钮四态/tab/toggle/进度点)、02 cards_widgets(建筑升级卡/
  槽位四态/进度条/物品箱)、03 icons(货币+五维+功能全套小图标)、04 building_widgets(虚线投放槽/
  tab 条/熔炉/罐/兑换行/升级行/羊皮纸卡/血条框)。橄榄绿金属框 + 橙色主按钮,和概念图同源。
- **概念图**(`docs/art/previews/base_building_*_20260707.png`):forge 四 tab(dismantle/craft/
  reforge/curse)+ clinic + market(+6tools 变体)+ outpost(+no_held 变体)。**实装以概念图为准。**
- **缺的美术(Codex 待补,不阻塞)**:4 张室内背景、铁匠兽人肖像、铁砧插画、悬赏海报插画。
  实装先用占位(当前暗化基地背景 / 通用框 / 目标图标),到货即插即用。

## 确认的逻辑(owner 拍板)

### 铁匠铺 拆解 tab — 新增"按稀有度批量拆解"
- 布局(概念图):左列 NPC 肖像 + 铁砧插画;右列 投放槽 + 按钮竖排 [全部分解(标题)] 普通/罕见/稀有/所有物品。
- **投放槽保留**:拖单件进槽 = 精确拆一件(现有 `dismantle_stash_item`)。
- **稀有度按钮 = 一键批量**:`普通/罕见/稀有` 各拆掉仓库里该稀有度全部;`所有物品` = 全拆。
- **安全**:批量**只拆 common/uncommon/rare**,**排除 set/cursed**(套装/诅咒只能投放槽单拆);
  点批量 → **二次确认弹窗**(显示"将拆解 N 件,得 M 废料")。
- 新后端:`MetaProgress.dismantle_stash_by_rarity(rarity: String) -> {count,scrap}`(rarity=""=全拆非套装/诅咒),
  内部循环 `dismantle_stash_item`,跳过 set/cursed。
- 按钮标签用**规范稀有度名**(普通/罕见/稀有),不用概念图的"魔法"。

### 其它三 tab(打造/重铸/诅咒)
- 逻辑不变(现有 forge_window),视觉重排成各自概念图的布局。

### 前哨站 — 悬赏迁入 + 免费承接(实现之前的改版 doc)
- 左panel **可接悬赏**:每日刷新一批契约海报卡(海报插画 + 真实奖励图标 瓶盖/废料/装备 + 「免费承接」按钮;
  持有满 3 置灰)。**承接免费**(去掉 market 的 1免2购 + Caps 价)。
- 右上 **安全格**(T2 gated,锁图标)+ 右下 **永久升级**(起始金币/背包格/刷新代币/工具槽,进度点+Caps齿轮按钮)。
- **持有中+进度仍在主界面左下悬赏板**(前哨站不显示持有区,用 no_held 概念图版)。
- 后端迁移:`refresh_bounty_shelf_if_stale`/`claim_free_bounty` 保留;**去掉 `buy_bounty` 的 Caps 价**
  (全部走 claim_free,或把 price 视为 0)。`BUILDING_DEFS`:market 去 `bounty_shelf`,outpost 加 `bounties: 1`。
  market_screen 去悬赏 section。

### 诊所 / 黑市
- 诊所:视觉重排成概念图(属性强化卡片 + 生命上限 + 等级上限),逻辑不变(Caps)。
- 黑市:重排成概念图(工具货架/装备货架/兑换台),逻辑不变(去悬赏后:tool_shop+refresh T1 / equip T2 / convert T3)。
  工具数保持 3(6tools 变体待定,不在本轮)。

## 组件库(地基,先做)

- **切 sheet**:把 4 张合集切成单件透明 PNG，落 `run_system/assets/images/ui_kit_lightline/`,
  按角色命名(如 `panel_window`/`titlebar`/`tab_active`/`tab_idle`/`btn_orange_{normal,hover,pressed}`/
  `btn_olive_*`/`slot_{normal,selected,locked,empty}`/`drop_slot`/`progress_row`/`convert_row`/
  `card_building`/`poster_blank`/`icon_{caps,scrap,anvil,shield,hammer,bag,...}`)。
- 每个 9-slice 面板记 margins(角饰只在角区);产出 `manifest.json`(name→源sheet+角色+margins)。
- `wasteland_theme.gd` 加 lightline 主题钩子(`T.lightline_panel()`/`lightline_button(state)`/…),
  优先加载新组件,程序化 fallback 保底(和现有 ui_kit 钩子同模式)。切换到 lightline 皮肤。

## 实施顺序(phased)

1. **组件切分 + 主题钩子**(地基)。
2. **铁匠铺窗**重构(4-tab 概念图布局 + 批量拆解逻辑 + 确认弹窗)。
3. **前哨站**重构(悬赏迁入 + 免费承接 + 安全格/永久升级布局;market 去悬赏)。
4. **诊所 + 黑市**重排。
5. 文档 + catalog(bounty price 去除)+ 终验 + 截图对照。

## 验证
- 每阶段 smoke gate;实机截图与概念图并排比对(布局/配色/间距)。
- 批量拆解 headless 测:common/uncommon/rare 各拆全部、set/cursed 不被拆、确认弹窗、废料结算。
- 悬赏迁移:前哨站免费承接进 active、板子显进度、market 无悬赏、旧存档兼容。
- gdscript-reviewer 全批;缺的美术走占位不崩(warn-only)。

## 风险
- 缺 4 张室内背景 + NPC + 海报插画 → 占位顶着,视觉差一档,Codex 到货补。
- 批量拆解误删:set/cursed 排除 + 二次确认双保险。
- 悬赏免费化后 Caps 少一个去处 —— 可接受(owner 要免费);数值观察 [tunable]。
