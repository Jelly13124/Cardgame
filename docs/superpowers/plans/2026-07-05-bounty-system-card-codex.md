# 悬赏系统 + 卡牌图鉴 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`. 每阶段 smoke gate + 本地 commit;push 由项目主决定。Spec: `docs/superpowers/specs/2026-07-05-bounty-system-card-codex-design.md`(先读)。

**Goal:** 悬赏系统取代每日任务(黑市每日货架 1 免 2 购、契约持有到完成、局内打点即时结算)+ 卡牌图鉴(用过即解锁,填充 Codex 已建的图鉴窗)。

**Architecture:** 契约 JSON 数据驱动(validator 双注册);持久化全在 `MetaProgress`(`active_bounties`/`bounty_shelf*`/`cards_seen`);打点走 `RunManager.bounty_event(kind, amount)` 单入口,战斗/奖励路径各加一行;UI 三处:悬赏板(改造 Codex 每日面板)、黑市悬赏货架(新 section)、图鉴窗(填 `_gallery_card_ids` + 锁定渲染)。

**Tech Stack:** Godot 4.6 GDScript;验证 `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`(必传;尾部两条 `[OK]`);headless 行为测试 read-only(不碰真实 slot);`class_name` 禁用(ADR-0006);catalog HTML 设计先行(契约数值先排 catalog 再定稿)。

**关键锚点(执行者实读确认,行号近似):**
- `run_system/ui/home_base_scene.gd` — 每日面板 `_add_daily_tasks_panel`(411,三条硬编码行)、`_make_daily_task_row`(471,标题/进度/奖励行构造,复用)、`_daily_refresh_time`(674)、图鉴窗(~1590-1680,完整壳)、`_gallery_card_ids`(~1678,硬编码占位)、`_make_gallery_card_slot`(其后)。
- `run_system/ui/buildings/market_screen.gd` — `_populate`(114)分 section 布局;`_locked_section` 样式;刷新 section(130)。
- `run_system/core/meta_progress.gd` — `save_progress`(791)/`load_progress`(815)字典;`BUILDING_DEFS["market"].functions`。
- `run_system/core/run_manager.gd` — 金币入账、`last_battle_node_type`(战斗类型)、撤离结算、`start_new_run`。
- `battle_scene/combat_engine.gd` — 出牌执行路径(卡类型可判 attack);敌人死亡处理(battle_scene/enemy 死亡钩子,grep `die\|_on_enemy_dead\|killed`)。
- 篝火升级:`run_system/ui/card_upgrade_modal.gd` `_on_pick`(置 `upgraded=true` 处)。
- `battle_scene/data_validator.gd` — `_validate_dir` 注册模式(参照 tools/gems 曾经的接法)。
- `scripts/gen_catalog_html.py` — 加 bounties 页(参照 tools 页的生成方式)。

---

## Phase B1 — 契约数据 + 后端(数据/validator/meta/打点入口)

**Files:** Create `run_system/data/bounties/*.json`(10 张);Modify `data_validator.gd`、`meta_progress.gd`、`run_manager.gd`;Create `assets/translations/content_bounties.csv`。

- [ ] 10 张首发契约(spec §2.3 schema:id/title/objective{type,count}/reward/price/tier)。目标类型恰好覆盖 ALLOWED 池:`play_attack_cards`(10/25)、`earn_gold`(150/400)、`kill_elites`(2/4)、`kill_boss`(1)、`extract_alive`(1)、`upgrade_cards`(2)、`kill_enemies`(15)。standard 价 30-50 / hard 60-80,奖励 caps 80-200、hard 掺 core(10-20)或 equipment tier。标题双语(csv `BOUNTY_<id>_TITLE`)。
- [ ] validator:`validate_bounty`(schema + `ALLOWED_BOUNTY_OBJECTIVES` 常量)+ `_validate_dir(BOUNTY_DATA_DIR, ...)` 注册;fail loud。
- [ ] meta_progress:`active_bounties: Array`(`[{id, progress}]`)、`bounty_shelf: Array[String]`、`bounty_shelf_date: String`、`bounty_free_claimed: bool`;save/load 容错(缺键默认空);API:`refresh_bounty_shelf_if_stale()`(本地日期比对,日期字符串做种子 `seed(hash(date))` 确定性掷 3 张不重复且不与已持有重复)、`claim_free_bounty(id)`/`buy_bounty(id)`(校验:货架在售/持有<3/免费位未领/Caps 够)、`bounty_progress_add(kind, amount)`(遍历 active,objective.type==kind 则 progress+=amount,达标 → `_settle_bounty`:发奖 caps/core/scrap/equipment(`RunManager.roll_shell_drop` 进 stash)+ `bounty_completed` 信号 + 移除)、`get_bounty_data(id)`(带缓存的 JSON 读取)。
- [ ] run_manager:`func bounty_event(kind: String, amount: int = 1) -> void`(仅 `is_run_active` 时转发 `MetaProgress.bounty_progress_add`;`extract_alive`/`kill_boss` 等一次性事件也走它)。
- [ ] headless 单测(read-only):货架同日重进不换货、跨日换货;买/领→active;`bounty_progress_add` 达标结算发奖且移除;满 3 拒买。哨兵 `BOUNTY_CORE_OK`。smoke + commit `feat(bounty): contract data + validator + meta persistence + progress/settle core`。

## Phase B2 — 局内打点钩子

**Files:** Modify `battle_scene/combat_engine.gd`(或出牌路径实际所在)、`battle_scene/battle_scene.gd`、`run_system/core/run_manager.gd`、`run_system/ui/card_upgrade_modal.gd`。

- [ ] 出牌成功且卡 type=="attack" → `RunManager.bounty_event("play_attack_cards")`。
- [ ] 敌人死亡 → `bounty_event("kill_enemies")`;战斗胜利处按 `last_battle_node_type`:elite → `kill_elites`,boss → `kill_boss`。
- [ ] 局内金币入账(找 RunManager 加金币的函数,只算正数增量)→ `bounty_event("earn_gold", amount)`。
- [ ] 撤离成功结算处 → `bounty_event("extract_alive")`。
- [ ] 篝火升级选卡后 → `bounty_event("upgrade_cards")`。
- [ ] 同点顺手打 `cards_seen`:出牌成功 → `MetaProgress.mark_card_seen(card_id)`(B1 里没有就在此加,含 save 节流:已 seen 不重写)。
- [ ] headless:模拟打点链路断言进度/结算;smoke + commit `feat(bounty): in-run event hooks (cards/gold/kills/extract/upgrade) + cards_seen tracking`。

## Phase B3 — UI:悬赏板 + 黑市货架

**Files:** Modify `run_system/ui/home_base_scene.gd`、`run_system/ui/buildings/market_screen.gd`、`run_system/core/meta_progress.gd`(BUILDING_DEFS)、`assets/translations/ui_home.csv`/`ui_build_market.csv`。

- [ ] 悬赏板:`_add_daily_tasks_panel` 改造——标题「悬赏 / BOUNTIES」;行数据源 = `MetaProgress.active_bounties`(标题/进度 current-target/奖励额,复用 `_make_daily_task_row` 的视觉);空态一行提示「到黑市承接悬赏」;`refresh` 标签改显示货架刷新(`_daily_refresh_time` 复用);连 `bounty_completed`/`buildings_changed` 重建;完成 toast(复用现有 popup/toast)。硬编码三行与假倒计时删除。
- [ ] `BUILDING_DEFS["market"].functions` 加 `"bounty_shelf": 1`;market_screen `_populate` 加悬赏 section(T1):`refresh_bounty_shelf_if_stale()` 后展示 3 张契约卡(标题/目标/奖励/价格;免费位标「免费领取」),按钮走 `claim_free_bounty`/`buy_bounty`,持有满 3 或已领/已购置灰;文案入 csv。
- [ ] headless:board 行数=active 数、空态、货架买/领后按钮态;smoke + commit `feat(bounty): board UI (replaces daily panel) + market bounty shelf`。

## Phase C1 — 图鉴填充

**Files:** Modify `run_system/ui/home_base_scene.gd`(`_gallery_card_ids`、`_make_gallery_card_slot`)。

- [ ] `_gallery_card_ids()` → 目录扫描全部玩家卡(含 basics + 诅咒,按 type 分组排序:attack/skill/ability/curse,组内按稀有度);返回全量。
- [ ] `_make_gallery_card_slot`:`MetaProgress.cards_seen.has(id)` → 正常卡面(现有 factory 渲染);未解锁 → 卡背 + 「???」标签(变暗)。
- [ ] 图鉴头部加计数「已收录 n / total」。
- [ ] headless:计数正确、锁定/解锁分支构建无错;smoke + commit `feat(gallery): real card codex — seen-tracking fill, locked card backs, counter`。

## Phase D — catalog + 文档 + 终验

- [ ] `gen_catalog_html.py` 加 bounties 页(id/标题/目标/奖励/价格/tier 表)+ index tab;重生成;**contracts 数值对照 catalog 复核**(content-balance subagent 过一遍定价/奖励曲线,离群修正)。
- [ ] PRD(悬赏系统取代每日任务、图鉴)+ PROJECT_STRUCTURE(bounties 数据目录、meta 新字段、板/货架/图鉴)。
- [ ] gdscript-reviewer 全批;最终 smoke;commit `docs: bounty+gallery sync`。

## 守则
- 存档兼容:旧档缺新键全部默认空/false,不 push_error。
- 打点只在 `is_run_active`;结算发奖走既有 add_caps/add_core/add_scrap/add_to_stash(自带 save)。
- 不动 Codex 图鉴窗/面板的视觉结构,只换数据源与行为。
- 日期种子掷取用 `seed()` 局部 RNG(RandomNumberGenerator 实例),不污染全局随机。
