# 设计 — 撤离背包经济系统(Extraction Backpack Economy)

**日期:** 2026-05-29
**状态:** 设计中(brainstorming)
**目标:** 把背包变成"塔科夫式"的撤离背包 —— 金币/Core/装备共享 20 格、互相挤占;死亡丢失、撤离/通关带走;基地铁匠把部分格子变成"安全格"(死亡不丢),撤离带回的装备进**永久基地仓库**,可在下一局出征时装配。

> 本文以中文为主(项目主硬性要求);字段名 / 路径 / commit 用英文(代码惯例)。

## 1. 现状(探查结论)

- **金币**:`RunManager.gold`(局内整数),战斗/?房/宝箱给,商店花;开新局清零。**不跨局**。
- **Core**:永久元货币 `MetaProgress.core`,目前在 boss 击杀 / 撤离时**即时**存入(+150 / 撤离 50–90),回基地买升级。
- **撤离**:已存在。第 4/8 层 mid-boss 出 `extract_choice_modal`(EXTRACT / PUSH ON);终 boss(第 11 层)= 通关。`battle_scene.gd` `_extract_rewards_for` 给 Core。
- **死亡**:`modify_health → current_health<=0 → _handle_run_loss → run_ended(false)`,有 `TODO: keep 30% of Core`;目前死亡不额外扣(Core 之前已即时存)。
- **背包**:`RunManager.inventory_items: Array[String]`(只装备),`MAX_INVENTORY=20`,`add_to_inventory`。面板已是暗黑三区 + 20 格网格(stack-ready)。

## 2. 已定决策(brainstorming)

- 金币 → **物理堆叠**,≤100/格;**自动合并**到最少格(`ceil(总额/100)` 格),商店按总额扣、自动找零。
- Core → **局内掉落**进背包(≤30/格),来源:**精英 + mid-boss + 终boss + 宝箱 + ?房**;局内不可花;撤离/通关才存进永久 `MetaProgress.core`。
- 死亡 → 背包 + 身上装备**全丢**,唯一例外是**安全格**内容。
- 安全格 → 基地**铁匠**用永久 Core 升级数量,初始约 2 格。
- 跨局保留 → **方案二**:撤离带回的装备进**永久基地仓库**,下一局可装配出征(安全格装备即使死亡也进仓库)。
- 金币是否跨局:**默认不跨局**(只局内购物用;死亡/撤离都不保留金币)。仅 **Core(货币)+ 装备(仓库)** 跨局。← *待你确认;若要金币也跨局再说。*

## 3. 数据模型

### 3.1 背包(格子数组)
安全格语义要求"物品在哪一格"是明确的,所以背包从"装备列表"升级为**定长格子数组**:

```
RunManager.backpack: Array   # 长度 = MAX_INVENTORY(20),每格为下列之一
  null                                  # 空格
  {"kind":"equip", "id":"warden_axe"}   # 装备
  {"kind":"gold",  "amount":85}         # 金币堆(≤100)
  {"kind":"core",  "amount":22}         # Core 堆(≤30)
```

- 现有 `inventory_items` 迁移为 backpack 里的 `equip` 格;`add_to_inventory / discard_from_inventory / equip_to_slot` 等改为操作格子。
- **安全格 = 背包前 `MetaProgress.safe_cells` 格**(UI 高亮金边)。玩家通过把物品**移动到前几格**来"上保险"。
- 金币:`add_gold(n)` 先填现有 gold 格到 100、再开新格;放不下的部分丢弃(背包满)。`total_gold()` = 所有 gold 格之和。Core 同理(≤30)。
- 商店花费:`spend_gold(cost)` 从 gold 格扣 `cost`、重新合并;够不够用 `total_gold()` 判断。

### 3.2 永久存档(MetaProgress,`user://meta.json`)
```
core: int                 # 已有,永久货币
safe_cells: int = 2       # 安全格数量(铁匠升级)
stash: Array[String] = [] # 永久装备仓库(物品 id 列表),容量上限 STASH_CAP(如 40)
```

## 4. 局内循环

- 战斗胜利 / 宝箱 / ?房 产出 **金币堆 / Core 堆 / 装备**,尝试入背包;**背包满则该掉落丢失**(玩家要权衡带什么)。
- Core 在背包里是"货物",**局内不可花**;金币可在商店花。
- 容量竞争:20 格被金币 + Core + 装备瓜分 —— 带 Core 出场就少带装备,这是核心张力。

## 5. 结算:死亡 / 撤离 / 通关

| 事件 | Core | 金币 | 装备 |
|---|---|---|---|
| **死亡** | 仅安全格内 Core 存入 `MetaProgress.core`;其余丢 | 全丢(本就局内) | 仅安全格内装备进 `stash`;其余 + 身上装备全丢 |
| **撤离(mid-boss)** | 背包内全部 Core 存入 `MetaProgress.core` | 丢(局内) | 背包内全部装备进 `stash` |
| **通关(终boss)** | 同撤离 | 丢 | 同撤离 |

- 现有"boss 即时 +Core"改为:**Core 改成掉落进背包**,只在撤离/通关/(安全格)死亡时结算。`battle_scene._extract_rewards_for` 的数值改为掉落量。
- `_handle_run_loss` 落实那个 `TODO`:按上表结算安全格 → stash / core,再 `run_ended(false)`。

## 6. 安全格 + 铁匠

- **安全格**:背包前 `safe_cells` 格,UI 高亮(金边/锁标)。死亡时只有这些格的内容被保留(Core 入库、装备入 stash)。
- **铁匠**:基地(home base)新增的功能入口/NPC,卖**安全格升级**:新 `base_upgrade` `blacksmith`(`effect_key: safe_cells_bonus`),分级花永久 Core,每级 +1 安全格(如 1/2/3 级)。`MetaProgress.safe_cells` = 基础 2 + 升级值。
  - 需在 `data_validator.gd` `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` 注册 `safe_cells_bonus`,并接消费端(MetaProgress 读取)。

## 7. 基地仓库 + 出征装配(方案二)

- **仓库(stash)**:基地一个界面,展示 `MetaProgress.stash` 里的永久装备(撤离带回 / 安全格保住的)。容量上限 `STASH_CAP`,满了入库时让玩家选弃哪件。
- **出征装配**:开新局前(英雄选择之后、进地图之前)给一个"装配"步骤 —— 从 stash 选装备**装进出征背包 / 装备槽**带入新局。被带走的从 stash 移除(它现在在你身上/包里,会再次面临死亡风险)。
  - 与现有 `Arsenal` base_upgrade(起手送物品)并存:Arsenal 给的是"白送的起手",stash 是"你自己攒的"。

## 8. 受影响的现有系统

- `run_manager.gd`:背包格子模型重构;`gold` 改由 backpack 派生;`add_gold/spend_gold/total_gold`;掉落入包;死亡/撤离结算;`start_new_run` 注入出征装配。
- `meta_progress.gd`:`safe_cells`、`stash`、存读;铁匠升级消费。
- `battle_scene.gd`:victory/extract 流程改为"Core 已在包里",撤离/通关时结算入库。
- `shop_scene.gd`:金币花费改走 `spend_gold`(物理堆叠)。
- `loot_reward.gd` / `map_scene.gd`(?房、宝箱):金币/Core/装备改为"入背包格"(满则丢)。
- `equipment_panel.gd`:背包网格渲染三种格 + 安全格高亮 + 把物品移进/移出安全格(拖拽或"上保险"按钮);金币/Core 格显示数量。
- `home_base_scene.gd`:加铁匠入口 + 仓库界面 + 出征装配入口。
- `extract_choice_modal.gd`:文案改为"带走背包"。
- `data_validator.gd`:注册 `safe_cells_bonus`;若 backpack 写入存档,加 schema 校验。

## 9. 实现分期(增量可玩)

- **Phase 1 — 经济基础**:背包格子模型(空/装备/金币/Core);金币堆叠+自动合并;Core 局内掉落+不可花;商店走 spend_gold;容量竞争(满则丢);死亡全丢、撤离/通关把 Core 存进 MetaProgress。**此期无安全格/仓库** —— 装备和金币本就局内,先验证核心循环。
- **Phase 2 — 安全格 + 铁匠**:前 N 格为安全格;死亡保留安全格的 Core(存入);铁匠 base_upgrade 升级 N。
- **Phase 3 — 基地仓库 + 出征装配(方案二)**:`stash` 持久化;撤离/通关→装备入库,死亡→安全格装备入库;基地仓库界面 + 出征装配。

每期跑 `bash scripts/smoke_test.sh` 通过再进下一期。

## 10. 风险 / 平衡

- **改动面大**:背包从列表变格子数组,牵动 shop/loot/?房/面板/存档。`inventory_items` 迁移要彻底,避免两套并存。
- **平衡**:Core 掉落量 × 安全格数 × 死亡惩罚 决定 meta 进度速度;若死亡全丢太狠,新手挫败 —— 安全格初始 2 格是缓冲。数值上线后需playtest调。
- **Core 不再即时入账**:玩家可能"打了 boss 却死在路上,Core 没了" —— 这正是张力,但要在 UI 上讲清楚(背包里的 Core 标注"撤离才入账")。
- **存档兼容**:`meta.json` 加 `safe_cells/stash` 字段,老存档缺字段时取默认(向后兼容)。

## 11. 验收标准

- 金币/Core/装备在 20 格里混装、互相挤占;背包满时新掉落被丢弃且有提示。
- 商店用物理金币堆扣费、找零正确;`total_gold` 与显示一致。
- 死亡:非安全格全丢(含身上装备);安全格 Core 入永久账、安全格装备进仓库。
- 撤离/通关:背包 Core 全入账、装备全进仓库。
- 铁匠升级后安全格数增加,UI 高亮对应格数。
- 基地仓库可见;开新局能从仓库装配出征;被带走的从仓库移除。
- `bash scripts/smoke_test.sh` 通过(`[OK] DataValidator: all schemas passed.`)。

## 12. 范围外(YAGNI)

- 拖拽排序的完整背包整理(v1 用"上保险/取出"按钮即可,拖拽可后续加)。
- 金币跨局(默认不跨局)。
- 仓库内的装备出售/分解(以后可加,归铁匠)。
