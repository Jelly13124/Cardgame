# 悬赏系统(取代每日任务)+ 卡牌图鉴 Design Spec

**Date:** 2026-07-05
**Status:** Approved (brainstorming) — 实施暂缓,等 Codex 当前工作区的 UI 批次落定后再出 plan。
**Scope:** 两个内聚子系统,一个 spec:①悬赏系统(离线单机化的"每日任务"替代品,黑市售卖契约);②卡牌图鉴(demo:用过即解锁)。

---

## 1. Motivation / 背景

Codex 在基地 UI 里加了一块**每日任务面板**(`home_base_scene._add_daily_tasks_panel`,
三条硬编码演示行 + 刷新倒计时)——目前是**纯展示 mock,无追踪后端**。讨论结论:

- 每日任务是网游留存机制,对买断制单机玩家体验弱(爆发式游玩 → 无感或负反馈)。
- 改造成**悬赏系统**:黑市卖悬赏契约,Caps 获得稳定去处(投资-回收循环),
  局内多出支线目标(影响路线决策)。**取代**每日任务,不并存(单一系统原则,
  参照删宝石的教训)。
- 用户拍板保留**真实时间每日刷新**(货架每日换新——保留"每天来看看"的节奏感,
  但已持有的契约不受日历影响)。
- 图鉴:demo 只做卡牌,入口用 Codex 已画好的基地图鉴按钮(角色/仓库按钮旁)。

**非目标(本轮不做):**
- 遗物/装备/敌人图鉴页(正式版再加)。
- 悬赏的赛季/周常/成就化;联网校时(本地时钟即可,单机不防改时间)。
- 不动 Codex 正在改的 UI 文件的现有结构——实施时在它落定的版本上接线。

---

## 2. 悬赏系统

### 2.1 概念模型

- **契约(bounty)**:一张可购买/领取的目标卡:「完成 X → 得 Y」。
- **悬赏板(bounty board)**:基地面板(改造 Codex 的每日任务面板),显示
  **当前持有的契约**(上限 **3** 张)+ 各自实时进度条。不显示商店内容。
- **悬赏货架(bounty shelf)**:黑市新增货架:每天刷 **3 张**契约 =
  **1 张免费领取 + 2 张 Caps 购买**。买/领即进悬赏板。
  货架刷新不影响已持有契约。

### 2.2 刷新与持久

- 货架按**本地日期**刷新:meta 存 `bounty_shelf_date: "YYYY-MM-DD"` +
  `bounty_shelf: [bounty_id, ...]`;读档/进基地时日期不同则重掷(免费位重置)。
- 掷取用日期做种子的确定性随机(同一天重进不换货)。
- **持有契约跨局、跨天、跨存档会话持久**:meta 存
  `active_bounties: [{id, progress}]`,完成即结算移除。上限 3,满了货架只能看不能买。

### 2.3 契约数据(数据驱动,validator 做 schema)

`run_system/data/bounties/*.json`,demo 首发 ~10 张:

```json
{
  "id": "cull_elites",
  "title": "清除精英",
  "objective": { "type": "kill_elites", "count": 2 },
  "reward": { "caps": 120 },
  "price": 50,
  "tier": "standard"
}
```

- `objective.type` ∈ ALLOWED_BOUNTY_OBJECTIVES(validator 双注册):
  demo 池用现有钩子可追踪的类型 —
  `play_attack_cards` / `earn_gold`(局内累计)/ `kill_elites` / `kill_boss` /
  `extract_alive` / `upgrade_cards` / `kill_enemies`(总击杀)。
- `reward`:`caps` / `core` / `scrap` / `equipment`(指定 tier,走
  `roll_shell_drop`)任意子集。
- `price`:货架购买价(Caps);免费位忽略 price。`tier` 影响掷取权重与定价带
  (standard 30-50 / hard 60-80,数值 [tunable],上 catalog 后按曲线调)。

### 2.4 追踪与结算

- `RunManager` 增加 `bounty_progress: {bounty_id: int}`(内存)+ 打点入口
  `bounty_event(kind, amount)`;战斗/奖励路径在**既有钩子处**调用:
  出牌(攻击牌)、金币入账、精英/Boss 击杀(`last_battle_node_type` 判定)、
  撤离结算、篝火升级。
- 进度**实时入 meta**(`active_bounties[].progress`,死亡不清零——契约是
  跨局的);达成即**立即结算**:发奖 + toast(复用现有 toast/popup),
  从 active 移除。
- 悬赏板行 UI 复用 Codex 面板的行构造(标题/进度条/奖励额)。

### 2.5 黑市接线

- `BUILDING_DEFS["market"].functions` 增加 `bounty_shelf: 1`(T1 即有,
  与工具货架同级;不新建 building)。
- market_screen 加「悬赏」区:3 张契约卡(免费位标"免费"),买/领按钮,
  持有满 3 置灰;文案走翻译 CSV。

---

## 3. 卡牌图鉴(demo:卡牌 only)

### 3.1 解锁追踪

- meta 存 `cards_seen: {card_id: true}`;打点位置:**战斗中出牌成功时**
  (combat_engine 出牌路径,含 0 费/工具发现打出的牌;弃牌/抽牌不算)。
- demo 规则:**用过 = 解锁**。starter 牌开局即多半很快点亮,符合预期。

### 3.2 图鉴窗

- 入口:Codex 基地 UI 已画的**图鉴按钮**(角色/仓库按钮旁)。
- `DraggableWindow` 子类图鉴窗:卡面网格(复用 card factory 渲染,
  同 deck viewer 缩放),按**类型分组**(攻击/技能/能力/诅咒),组内按稀有度排;
  未解锁 = **卡背 + "???"**;顶部计数「已收录 n / 总数」(总数 = 目录扫描,
  与 `get_unlocked_card_pool` 同源但含basics/诅咒)。
- 只读窗,无交互决策;悬停显示已解锁卡的 tooltip。

---

## 4. 组件边界

| Unit | 职责 |
|---|---|
| `run_system/data/bounties/*.json`(新) | 契约内容 |
| `data_validator.gd`(改) | bounty schema + ALLOWED_BOUNTY_OBJECTIVES |
| `meta_progress.gd`(改) | `active_bounties` / `bounty_shelf(+date)` / `cards_seen` 持久化 + 结算发奖 |
| `run_manager.gd`(改) | `bounty_event` 打点入口 + 转发进度 |
| 战斗/奖励钩子(改) | 出牌/金币/击杀/撤离/升级处各一行打点 |
| 悬赏板(改造 Codex 面板) | 持有契约 + 进度展示 |
| market_screen(改) | 悬赏货架(3 张/日,免费+付费) |
| 图鉴窗(新) | 卡面网格 + 解锁态 |
| catalog(改) | bounties 页(HTML 设计先行规则适用:实施前先在 catalog 排目标/数值) |

## 5. 验证

- smoke gate(validator 校 bounty JSON);headless:货架日期重掷确定性、
  打点→进度→结算链路、`cards_seen` 打点、图鉴窗构建;
  content-balance 过一遍契约定价/奖励曲线。
- 存档兼容:旧档缺 `active_bounties`/`cards_seen` 键 → 默认空,不崩。

## 6. 风险 / 未决

- **实施时序**:Codex 工作区有大批未提交 UI 改动(含每日任务面板本体)——
  **等它落定再实施**,悬赏板改造要基于它的最终版本;实施前先 `git status` 确认。
- 改本地时钟可刷货架——单机不设防,明确接受。
- `earn_gold` 与撤离结算的计量口径(局内累计 vs 带出)实施时定一个写进 catalog。
- Codex 图鉴按钮的点击回调是否已预留——实施时接线,没有就补一个按钮信号。
