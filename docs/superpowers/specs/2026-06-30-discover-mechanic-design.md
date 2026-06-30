# 发现机制(Discover)设计 — 2026-06-30

炉石式「发现」:打出/触发一张发现牌 → 弹出三选一 → 选中的牌**凭空生成进当前手牌**,
只在本场战斗有效(不进永久牌库)。首版聚焦**战斗内 · 加手牌**,候选**按类型/主题筛选**,
可附带**本场 0 费**修饰。

## 范围(首版)

- 通用 `discover` effect + 全新的战斗内三选一弹窗 `DiscoverModal`。
- 3 张示范发现卡。
- **不做**:永久发现(加牌库)、事件源、遗物源 —— 留作后续(同一 effect 可复用)。

## ① 数据:新 `discover` effect

卡牌 `effects[]` 里的一项:

```json
{ "type": "discover", "pool": "skill", "count": 3, "free": false }
```

| 字段 | 含义 |
|---|---|
| `pool` | 候选筛选:卡**类型**(`attack` / `skill` / `ability`)**或主题标签**(`bleed` 等) |
| `count` | 候选数,默认 3,缺省即 3 |
| `free` | `true` → 选中的牌**本场 0 费**;缺省 `false` |

**`pool` 匹配规则**:先按卡 `type` 字段匹配(`attack`/`skill`/`ability`);若 `pool` 不是这三个类型,
则按卡的 **`tags` 数组**匹配(卡 JSON 新增可选 `tags: ["bleed", …]`)。首版给流血主题的牌加
`tags: ["bleed"]`。

## ② 候选生成

- 池来源:`MetaProgress.get_unlocked_card_pool()`(玩家已解锁的卡 id),**排除基础起手牌**
  (`strike` / `defend` / `weak_strike` 这类,避免发现到无聊的基础牌)。
- 按 `pool` 筛选 → 打乱 → 取前 `count` 张(不足则取全部)。
- 边缘:筛完 **0 张候选** → 不弹窗,飘字提示「无可发现的牌」,effect 直接结束(不暂停战斗)。
- 新增一个无状态 helper(放 `RunManager` 或新 `discover_pool.gd`):
  `roll_discover(pool: String, count: int) -> Array[String]`。

## ③ UI:全新的 `DiscoverModal`(炉石式聚焦,**不套任何奖励界面骨架**)

新文件 `battle_scene/discover_modal.gd`(+ 轻量 `.tscn` 或纯代码构建),`extends Control`:

- **暗化遮罩**:半透明黑(~0.72)盖住战斗场景,隐约透出后面的战斗(**不是** loot_reward 那种实底木框)。
- **三张候选卡居中、放大**水平排列:复用 `PlayCard`(`play_card.tscn`)把"一张卡长什么样"画出来
  (候选本来就是卡),`scale ≈ 1.25`,水平间距足够;**容器 / 布局 / 标题全是新的**,不碰 loot_reward。
- **标题**:顶部一行金色描边文字直接浮在遮罩上(如「发现 · 技能」),**无框、无 banner、无 claim 牌**。
- **交互**:hover 卡上浮 + 金边高亮;点选 → 卡飞入手牌的小动画 → `discovered(card_id)` 信号 → 关闭。
- **modal**:`mouse_filter = STOP` 吃掉所有输入,战斗在它关闭前不可操作(等效暂停)。
- 坚决不出现:木框 / 横条按钮 / 奖励 banner / claim plate。

## ④ 流程

1. 玩家打出发现牌 → `combat_engine._apply_effect` 命中 `discover` case。
2. `roll_discover(pool, count)` 取候选;0 张则提示并结束。
3. `battle_scene` 实例化 `DiscoverModal`、传候选 + 标题 + `free`,`add_child`。
4. `await modal.discovered` —— effect 处理在此挂起,直到玩家选牌(combat_engine 已有 `await` 先例)。
5. 选中 → `deck_manager.add_card_to_hand(card_id)`;`free` → 给该卡实例打 `cost_override = 0`。
6. **手牌满**:加入前查手牌是否达上限,满则飘字「手牌已满,无法加入」、该发现作废(不强行超限)。
7. modal 关闭,战斗继续。

## ⑤ 0 费实现(`cost_override`)

- 选中卡 `add_card_to_hand` 后,拿到该卡实例,`set_meta("cost_override", 0)`(本场临时,**不写存档、不改卡定义**)。
- `PlayCard` 显示费用:`set_card_data` 读 `has_meta("cost_override")` 优先,否则用 `card_info.cost`。
- 出牌扣能量:`battle_scene` 的 `spend_energy` / 费用检查同样优先读 `cost_override`。
- 卡被打出/弃掉后实例销毁,meta 随之消失 —— 天然"本场有效"。

## ⑥ 首版 3 张示范发现卡(1 费技能)

| id | 名称 | 效果 |
|---|---|---|
| `scrap_scavenge` | 废料翻找 | `discover` pool=`skill` count=3 |
| `blood_recipe` | 血色配方 | `discover` pool=`bleed` count=3 `free=true` |
| `armory_requisition` | 军火调拨 | `discover` pool=`attack` count=3 |

- 都是 `type: "skill"`、`cost: 1`、`exhaust_self`(发现是强力即时价值,打完消耗,防刷)。
- 加入 draft 池(`MetaProgress` 解锁/初始池)让它们能进卡组。
- 给现有流血牌(如 `acid_splash` / `hemorrhage` / `corrode` 等带 bleed 的)补 `tags: ["bleed"]`。

## ⑦ 注册(两处)+ 验证

- **handler**:`combat_engine._apply_effect` 加 `discover` case(可能要把该 effect 处理设为
  `await` 弹窗)。
- **schema**:`data_validator.gd` —— `ALLOWED_EFFECT_TYPES += "discover"`;
  `KNOWN_OPTIONAL_CARD_KEYS += "tags"`;校验 discover 的 `pool` 为非空字符串、`count` 为正整数。
- **翻译**:`UI_DISCOVER_TITLE`(「发现」)+ 每个 pool 的副标题(技能/攻击/流血)、3 张卡的
  `CARD_*_TITLE/DESC`、「手牌已满」「无可发现的牌」提示。
- **验证**:smoke + MCP —— 打出 `scrap_scavenge` 看三选一弹窗(暗化背景 + 三张大卡 + 简洁标题)、
  选中进手牌;打出 `blood_recipe` 验证候选都是流血牌 + 选中显示 0 费。
- **catalog**:`gen_catalog_html.py` 重新生成(新卡 + discover 关键词)。

## 文件清单

- 新:`battle_scene/discover_modal.gd`(+ 可选 `.tscn`)、`run_system/core/discover_pool.gd`(或并入 RunManager)、
  3 张 `battle_scene/card_info/player/{scrap_scavenge,blood_recipe,armory_requisition}.json`。
- 改:`combat_engine.gd`(discover handler)、`battle_scene.gd`(弹窗 + cost_override 扣费)、
  `play_card.gd`(cost_override 显示)、`data_validator.gd`(注册)、相关流血卡加 `tags`、
  `MetaProgress` draft 池、翻译 CSV。

## 已知后续(不在首版)

- 永久发现(加牌库)、事件源、遗物源 —— 复用同一 `discover` effect + modal,换"加哪里"。
- 更多主题 pool(burn / block / 等),靠给卡补 `tags`。
- 发现卡美术(Codex,按 asset-spec)。
