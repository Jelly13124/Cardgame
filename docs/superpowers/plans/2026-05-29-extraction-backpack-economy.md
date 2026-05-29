# 撤离背包经济系统 实施计划

> **For agentic workers:** 三期**串行**执行(Phase 1 smoke 绿 → Phase 2 → Phase 3)。每期内:**地基任务(改 run_manager/meta_progress)是 barrier,必须先完成**;之后消费端任务按文件归属**并行**(每个 `.gd` 仅一个 agent 改)。本项目无单元测试框架(见 `docs/conventions/gameplay-code.md`),验证 = `bash scripts/smoke_test.sh` + 临时 `.tscn` boot 检查 + 不变量打印。Smoke 二进制:`GODOT_BIN="C:/Program Files/Godot/Godot.exe"`。中文说明 + 英文代码/字段/路径(代码惯例)。

**Goal:** 把背包做成撤离式经济:金币/Core/装备共享 20 格、互相挤占;死亡丢失(安全格除外)、撤离/通关带走;铁匠升级安全格;跨局基地仓库 + 出征装配。

**Architecture:** 核心是把 `RunManager.inventory_items`(装备列表)重构为 `RunManager.backpack`(定长格子数组,每格 空/装备/金币堆/Core堆)。金币由背包派生(不再独立标量)。Core 改为局内掉落进背包,撤离/通关结算入 `MetaProgress.core`。安全格 = 背包前 N 格,死亡保留。`MetaProgress.stash` 永久仓库 + 出征装配实现跨局。

**Tech Stack:** Godot 4.6 / GDScript;`scripts/smoke_test.sh`;存档 `user://meta.json`。**Spec:** `docs/superpowers/specs/2026-05-29-extraction-backpack-economy-design.md`。

---

## 数据模型契约(所有 agent 共享 — 严格按此对齐)

`RunManager` 新增:
```gdscript
# 定长 20。每格为下列之一:
#   null
#   {"kind": "equip", "id": String}
#   {"kind": "gold",  "amount": int}   # 1..100
#   {"kind": "core",  "amount": int}   # 1..30
var backpack: Array = []
const GOLD_PER_CELL := 100
const CORE_PER_CELL := 30

signal backpack_changed   # 任何背包变动后 emit

func total_gold() -> int           # 所有 gold 格之和
func total_run_core() -> int       # 所有 core 格之和(局内携带,未入账)
func free_cells() -> int           # 空格数(不含安全格占用判断)
func add_gold(n: int) -> int       # 入包(自动合并到最少格),返回实际放入量(满则<n)
func spend_gold(cost: int) -> bool # 够则扣 cost 并重新合并,返回成功与否
func add_core_to_backpack(n: int) -> int  # 入包(≤30/格),返回实际放入量
func add_equip_to_backpack(item_id: String) -> bool  # 占一格;满则 false
func backpack_count_used() -> int  # 非空格数
```

`gold` 旧标量**删除**;所有读 `gold` 处改 `total_gold()`,所有 `add_resources(g,0)` 的金币部分改 `add_gold(g)`,`add_resources(-cost,0)` 改 `spend_gold(cost)`。`add_resources` 保留但只处理 core 的旧调用要逐个迁移(见各 Task)。

`MetaProgress` 新增(持久化到 `user://meta.json`):
```gdscript
var safe_cells: int = 2          # 安全格数(基础2 + 铁匠升级)
var stash: Array[String] = []    # 永久装备仓库(item_id)
const STASH_CAP := 40
func add_to_stash(item_id: String) -> bool   # 满返回 false
func remove_from_stash(item_id: String) -> bool
```
安全格约定:**背包索引 `0 .. safe_cells-1` 为安全格**。

## 文件归属(并行安全)
| 文件 | 改动期 | 归属 |
|---|---|---|
| `run_system/core/run_manager.gd` | 1地基,2地基,3地基 | 每期地基 task 独占(串行,不并发) |
| `run_system/core/meta_progress.gd` | 2地基,3地基 | 同上 |
| `run_system/ui/shop_scene.gd` | 1 | shop agent |
| `run_system/ui/loot_reward.gd` | 1 | loot agent |
| `run_system/ui/map_scene.gd` | 1 | map agent(?房/宝箱掉落) |
| `run_system/ui/equipment_panel.gd` | 1,2,3 | 每期 panel agent(串行) |
| `battle_scene/battle_scene.gd` | 1,3 | battle agent |
| `run_system/ui/extract_choice_modal.gd` | 1 | battle agent(同批,文案) |
| `run_system/ui/home_base_scene.gd` | 2,3 | home agent |
| `battle_scene/data_validator.gd` | 2 | meta/upgrade agent |
| `run_system/data/base_upgrades/blacksmith.json` | 2 新建 | meta/upgrade agent |

---

# PHASE 1 — 经济基础

## Task 1.1(地基 / barrier):RunManager 背包格子模型 + 金币/Core API

**Files:** Modify `run_system/core/run_manager.gd`

- [ ] **Step 1:** 删除 `var gold: int = 0`,新增背包字段 + 信号 + 常量(见数据模型契约)。`start_new_run` 里把背包初始化为 `backpack.resize(MAX_INVENTORY); backpack.fill(null)`(替换 `inventory_items.clear()` / `gold` 重置)。
- [ ] **Step 2:** 实现金币/Core/装备 API:
```gdscript
func _first_null_cell() -> int:
	for i in range(MAX_INVENTORY):
		if backpack[i] == null:
			return i
	return -1

func total_gold() -> int:
	var t := 0
	for c in backpack:
		if c != null and c.get("kind") == "gold":
			t += int(c["amount"])
	return t

func total_run_core() -> int:
	var t := 0
	for c in backpack:
		if c != null and c.get("kind") == "core":
			t += int(c["amount"])
	return t

func backpack_count_used() -> int:
	var n := 0
	for c in backpack:
		if c != null:
			n += 1
	return n

func add_gold(n: int) -> int:
	return _add_stacked("gold", n, GOLD_PER_CELL)

func add_core_to_backpack(n: int) -> int:
	return _add_stacked("core", n, CORE_PER_CELL)

# 先填未满的同类格,再开新格;放不下的返回未放入差额。
func _add_stacked(kind: String, n: int, per: int) -> int:
	var remaining := n
	for c in backpack:
		if remaining <= 0:
			break
		if c != null and c.get("kind") == kind and int(c["amount"]) < per:
			var room := per - int(c["amount"])
			var put := mini(room, remaining)
			c["amount"] = int(c["amount"]) + put
			remaining -= put
	while remaining > 0:
		var idx := _first_null_cell()
		if idx == -1:
			break
		var put := mini(per, remaining)
		backpack[idx] = {"kind": kind, "amount": put}
		remaining -= put
	if n != remaining:
		emit_signal("backpack_changed")
	return n - remaining

func spend_gold(cost: int) -> bool:
	if total_gold() < cost:
		return false
	var remaining := cost
	for i in range(MAX_INVENTORY):
		if remaining <= 0:
			break
		var c = backpack[i]
		if c != null and c.get("kind") == "gold":
			var take := mini(int(c["amount"]), remaining)
			c["amount"] = int(c["amount"]) - take
			remaining -= take
			if int(c["amount"]) <= 0:
				backpack[i] = null
	_normalize_gold()
	emit_signal("backpack_changed")
	return true

# 合并金币到最少格(自动找零的结果)
func _normalize_gold() -> void:
	var g := total_gold()
	for i in range(MAX_INVENTORY):
		if backpack[i] != null and backpack[i].get("kind") == "gold":
			backpack[i] = null
	var idx := 0
	while g > 0 and idx < MAX_INVENTORY:
		if backpack[idx] == null:
			var put := mini(GOLD_PER_CELL, g)
			backpack[idx] = {"kind": "gold", "amount": put}
			g -= put
		idx += 1

func add_equip_to_backpack(item_id: String) -> bool:
	var idx := _first_null_cell()
	if idx == -1 or item_id == "":
		return false
	backpack[idx] = {"kind": "equip", "id": item_id}
	emit_signal("backpack_changed")
	return true
```
- [ ] **Step 3:** 迁移装备相关 API 到背包模型:`add_to_inventory(item_id)` → 改为调用 `add_equip_to_backpack`;`discard_from_inventory(index)` → `backpack[index] = null; emit backpack_changed`(仅当该格是 equip);`equip_to_slot` 取消装备进背包用 `add_equip_to_backpack`,从背包取装备时把该格置 null。提供帮助函 `backpack_equip_ids() -> Array[String]`(供面板/兼容旧逻辑)。把 `equipped_items` 取消装备的回包路径接到背包。
- [ ] **Step 4:** 迁移 `purchase_card/equipment/relic/card_removal`:`if gold < cost` → `if not _can_afford(cost)`(`func _can_afford(c): return total_gold() >= c`);`add_resources(-cost, 0)` → `spend_gold(cost)`。`add_resources(g, 0)` 的金币奖励调用点(line ~1013 等)→ `add_gold(g)`。
- [ ] **Step 5:** 死亡/撤离结算骨架(本期:无安全格/仓库 → 死亡丢全部背包,撤离/通关把 `total_run_core()` 存入 `MetaProgress.add_core`):
```gdscript
# 在 _teardown_run 内,run_ended 之前:
func _settle_backpack(victory: bool, outcome: String) -> void:
	if victory or outcome == "extracted":
		MetaProgress.add_core(total_run_core())  # 撤离/通关:携带 core 入账
	# 死亡(victory==false 且非 extracted):core 丢失,不入账
	# Phase 2/3 会在此加入安全格 / stash 结算
```
在 `_teardown_run` 调 `_settle_backpack(victory, outcome)`。**注意**:`battle_scene` 原本 boss 即时 `MetaProgress.add_core` 的调用要删(改由掉落+结算),见 Task 1.5。
- [ ] **Step 6(验证):** `GODOT_BIN=... bash scripts/smoke_test.sh` → `[OK]`。再写临时 `_econtest.tscn`+`.gd`(extends Node,_ready 里:`RunManager.add_gold(250); assert(RunManager.total_gold()==250); RunManager.spend_gold(70); print("gold=",RunManager.total_gold()); RunManager.add_core_to_backpack(50); print("core=",RunManager.total_run_core(),"used=",RunManager.backpack_count_used()); get_tree().quit()`),`godot --headless res://_econtest.tscn --quit-after 3` 验证 gold=180 / core=50 / used 合理,无 SCRIPT ERROR;删除临时文件。
- [ ] **Step 7:** Commit `feat(econ): backpack cell model + gold/core stacks (phase1 base)`。

## Task 1.2(并行):商店金币花费

**Files:** Modify `run_system/ui/shop_scene.gd`
- [ ] 金币显示 `RunManager.gold` → `RunManager.total_gold()`(line ~70 的 `_on_resources_changed` 与所有显示点)。连接 `RunManager.backpack_changed` 一起刷新金币显示。购买调用已走 `purchase_*`(Task 1.1 内部已改),无需改调用点;只改显示与"买得起"判断显示(置灰按钮用 `total_gold()`)。
- [ ] 验证:`bash scripts/smoke_test.sh` → `[OK]`。

## Task 1.3(并行):战斗奖励入背包

**Files:** Modify `run_system/ui/loot_reward.gd`
- [ ] 金币奖励(line ~244 `RunManager.add_resources(loot["amount"],0)`)→ `RunManager.add_gold(loot["amount"])`;若返回值 < amount(背包满),显示 `tr("UI_LOOT_BACKPACK_FULL")`(新 key,加进 `assets/translations/ui_loot.csv`,en+zh)。装备 drop(line ~404 `add_to_inventory`)→ `add_equip_to_backpack`。
- [ ] 验证:smoke `[OK]`。

## Task 1.4(并行):?房/宝箱奖励入背包 + Core 掉落

**Files:** Modify `run_system/ui/map_scene.gd`
- [ ] `_resolve_unknown_node` / `_grant_treasure_equipment` 里给金币的 `add_resources(g,0)` → `add_gold(g)`;给装备 → `add_equip_to_backpack`(满则 `_show_popup` 提示丢弃)。
- [ ] **新增 Core 掉落**:treasure 与 ?房的部分结果掉 Core stack → `RunManager.add_core_to_backpack(randi_range(10,30))`,popup 提示"获得 N Core(撤离才入账)"(新 key `UI_MAP_CORE_DROP`)。
- [ ] 验证:smoke `[OK]`。

## Task 1.5(并行):战斗胜利 Core 掉落 + 撤离结算

**Files:** Modify `battle_scene/battle_scene.gd`, `run_system/ui/extract_choice_modal.gd`
- [ ] boss/精英胜利:把原 `MetaProgress.add_core(BOSS_VICTORY_CORE)` 与 `_on_extract_chosen` 里的 `MetaProgress.add_core(...)` **改为** `RunManager.add_core_to_backpack(...)`(Core 进背包,不即时入账)。精英战胜利也掉少量 core 进背包。
- [ ] 撤离:`_on_extract_chosen` extract 分支 → `RunManager.end_run_victory(0, "extracted")`(core 已在包里,`_settle_backpack` 会结算);push-on 分支同样把奖励 core 进背包再进 loot 流程。终boss → `end_run_victory(0, "victory")`。
- [ ] `extract_choice_modal.gd` 文案改为"带走背包内的 Core / 继续(背包内 Core 仍有风险)"(改 `ui_hero.csv` 的 EXTRACT 文案 en+zh)。
- [ ] 验证:smoke `[OK]`。

## Task 1.6(并行):背包面板渲染三种格

**Files:** Modify `run_system/ui/equipment_panel.gd`
- [ ] `_make_grid_cell(index)` 扩展:读 `RunManager.backpack[index]`,按 `kind` 渲染 —— equip(现有图标+左键装备/右键丢弃)、gold(金币图标+数量,不可点)、core(core 图标+数量,不可点)、null(空格)。监听 `RunManager.backpack_changed` 刷新。背包计数用 `backpack_count_used()`/`MAX_INVENTORY`。
- [ ] 验证:smoke `[OK]` + 临时 boot(同面板 boot 法)无错。

## Task 1.7(验证 / barrier 收尾)
- [ ] `bash scripts/smoke_test.sh` → `[OK]`;临时 boot 跑一遍战斗→loot→shop→撤离的关键路径无 SCRIPT ERROR;Commit `feat(econ): phase1 consumers (shop/loot/map/battle/panel)`。

---

# PHASE 2 — 安全格 + 铁匠

## Task 2.1(地基 / barrier):MetaProgress 安全格 + 死亡结算保安全格

**Files:** Modify `run_system/core/meta_progress.gd`, `run_system/core/run_manager.gd`
- [ ] `meta_progress.gd`:加 `var safe_cells: int = 2`,load/save 读写(缺字段默认2,向后兼容);`safe_cells` 实际值 = `2 + get_upgrade_level("blacksmith")`(用 `_effective_safe_cells()`)。
- [ ] `run_manager.gd` `_settle_backpack`:死亡分支改为 —— 遍历安全格 `0 .. MetaProgress._effective_safe_cells()-1`,其中 core 格 `MetaProgress.add_core(amount)`(安全格 core 即使死亡也入账)。非安全格 core 丢。(装备入库在 Phase 3。)
- [ ] 验证:smoke `[OK]`。Commit `feat(econ): safe cells settlement (phase2 base)`。

## Task 2.2(并行):铁匠 base_upgrade

**Files:** Create `run_system/data/base_upgrades/blacksmith.json`; Modify `battle_scene/data_validator.gd`, `run_system/ui/home_base_scene.gd`
- [ ] 新建 `blacksmith.json`:`effect_key: "safe_cells_bonus"`,3 级(cost 例:40/80/140 Core,每级 +1 安全格,effect_text)。
- [ ] `data_validator.gd` 的 `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` 加 `"safe_cells_bonus"`。
- [ ] `home_base_scene.gd` 的 `UPGRADE_ORDER` 加 `"blacksmith"`(面板自动渲染)。
- [ ] 验证:smoke `[OK]`(DataValidator 校验新 json)。

## Task 2.3(并行):面板安全格高亮 + 移进/移出

**Files:** Modify `run_system/ui/equipment_panel.gd`
- [ ] 前 `MetaProgress._effective_safe_cells()` 格画金边/锁标(安全格);其余普通。
- [ ] 每个非空格加"移入安全格 / 移出"操作(右键菜单或一个小按钮):调用 `RunManager.move_cell(from, to)`(在 run_manager 加一个交换两格内容的辅助,本 task 顺带加到 run_manager —— 注意这会碰 run_manager,需在 2.1 之后串行,由本 agent 串行追加,或并入 2.1)。**为避免并发,`move_cell` 放进 Task 2.1 地基**;本 task 只调用它。
- [ ] 验证:smoke `[OK]` + 临时 boot。Commit `feat(econ): safe cells UI + blacksmith (phase2)`。

---

# PHASE 3 — 基地仓库 + 出征装配

## Task 3.1(地基 / barrier):MetaProgress 仓库 + 装备入库结算

**Files:** Modify `run_system/core/meta_progress.gd`, `run_system/core/run_manager.gd`
- [ ] `meta_progress.gd`:加 `var stash: Array[String] = []` + `STASH_CAP` + `add_to_stash/remove_from_stash` + load/save(缺字段默认 []).
- [ ] `run_manager.gd` `_settle_backpack`:撤离/通关 → 背包内所有 equip 格 `MetaProgress.add_to_stash(id)`(满则丢弃多余,后续可加选择);死亡 → 仅安全格内 equip 格入库。
- [ ] 验证:smoke `[OK]`。Commit `feat(econ): permanent stash settlement (phase3 base)`。

## Task 3.2(并行):基地仓库界面 + 出征装配

**Files:** Modify `run_system/ui/home_base_scene.gd`(+ 可新建 `run_system/ui/stash_panel.gd`)
- [ ] 基地加"仓库"入口:列出 `MetaProgress.stash` 装备(用 `equipment_icon` + tooltip)。
- [ ] 出征装配:开新局流程(`home_base → hero_select → map`)中,在 `hero_select` 选完英雄后、进 map 前,插入"装配"步骤(或基地直接装配):从 stash 选装备 → 记到一个待出征列表 `RunManager.pending_loadout: Array[String]`;`start_new_run` 把 `pending_loadout` 里的装备 `add_equip_to_backpack` 并从 stash `remove_from_stash`。
- [ ] 验证:smoke `[OK]` + 临时 boot。Commit `feat(econ): base stash + loadout (phase3)`。

---

## 自检对照 spec
- §3 数据模型 → Task 1.1 / 2.1 / 3.1 地基。
- §4 局内循环 → 1.3 / 1.4 / 1.5 掉落入包。
- §5 死亡/撤离/通关结算 → 1.1 Step5 + 2.1 + 3.1。
- §6 安全格+铁匠 → 2.1 / 2.2 / 2.3。
- §7 仓库+出征装配 → 3.1 / 3.2。
- §8 受影响系统 → 各 Task 文件归属覆盖。
- §11 验收 → 每期验证步骤 + 末尾临时 boot。

## 验收(全部完成后,你肉眼验)
- 战斗/?房/宝箱掉金币/Core/装备进背包,满了被丢且有提示;商店扣费/找零正确。
- 死亡:非安全格全丢(含身上装备);安全格 Core 入永久账、安全格装备进仓库。
- 撤离/通关:背包 Core 全入账、装备全进仓库。
- 铁匠升级后安全格数增加,面板高亮对应格。
- 基地仓库可见;开新局能从仓库装配出征。
- `bash scripts/smoke_test.sh` → `[OK]`。
