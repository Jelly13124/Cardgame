# 删除核心货币 → 双货币经济(Caps + Scrap) Design Spec

**Date:** 2026-07-07  **Status:** Approved (owner) → implement.
**Scope:** 移除第三货币 **Core(核心)**,只留 **Caps(瓶盖)** + **Scrap(废料)**,让经济更废土。

## 目标 / 决策(owner 拍板)

- **核心彻底删除**:var/signal/add_core/spend_core/存档字段/UI 全去。
- **拆分映射(owner 原话:"装备和建筑解锁用废料,商店诊所升级用瓶盖")**:
  - **Scrap(废料)** = 捡破烂档:铁匠铺打造/拆解(现有)+ **建筑解锁 unlock**(4 栋)+
    **战斗胜利产出**(原发 Core 的那份改发 Scrap,给废料稳定来源)。
  - **Caps(瓶盖)** = 钱:黑市购物 + 诊所强化(现有)+ **建筑升级 tier-up(T2/T3)** +
    **前哨站永久升级** + 撤离结算/战斗奖励(现有)。
- **兑换台**(黑市 T3):去掉 Core→Caps,改 **Caps ↔ Scrap 双向**。
- **契约奖励**:2 张给 Core 的(`elite_purge` 15、`head_hunter` 20)→ 改给 **Scrap**。
- **存档**:core 字段删除、余额**清零不迁移**;旧档缺/多 core 键都容错。
- **UI**:货币显示只剩 **Caps + Scrap** 两枚;所有花费角标显示对的币种图标。
- **数值**:先沿用现值(解锁 60-100、tier 100-240),Scrap/Caps 尺度不同,标记 [待平衡]。

## 关键实现点

**meta_progress.gd**
- 删 `var core` / `signal core_changed` / `add_core` / `spend_core` / 序列化 `"core"` /
  反序列化 core / `_reset_to_defaults` 的 core。
- `unlock_building(id)`:改花 **Scrap**(`spend_scrap(unlock_cost)`);可负担判断改 `scrap >=`.
- `upgrade_building(id)`:改花 **Caps**(`spend_caps(tier_cost)`)。
- `next_building_cost` 返回值不变(数值),但**调用方要知道 unlock 看 Scrap / upgrade 看 Caps**——
  加 `building_cost_currency(id) -> "scrap"|"caps"`(unlock 时 scrap,否则 caps)供 UI 取图标 + 判负担。
- 前哨站 Core 升级(base_upgrades:command_center/backpack/reroll_tokens/tool_slots):
  `can_afford`/`purchase` 从 core 改 **caps**。
- 契约结算 `_settle_bounty`:reward 里 `core` 字段改读 `scrap`(或保留 core 键但按 scrap 发——
  统一:契约 JSON 把 `"core"` 改成 `"scrap"`,validator 去掉 core reward,`_settle` 去 add_core)。
- FACILITY_UNLOCK_COSTS / cyber_doc:已无 UI 且属性强化改走 building_can(2026-07-07 前修),
  这块 Core 设施解锁若还引用 core,一并删。

**data_validator.gd**:bounty reward 允许币种去掉 `core`(留 caps/scrap/equipment)。

**契约 JSON**:`elite_purge.json`(core 15→scrap 30 [待平衡])、`head_hunter.json`(core 20→scrap 40)。

**BUILDING_DEFS**:unlock_cost/tier_costs 数值不动;语义变(unlock=Scrap,tier=Caps)。

**battle_scene `_victory`**:原 `add_core(...)` 的奖励 → `add_scrap(...)`(同量或按 [待平衡])。

**market_screen 兑换台**:`resource_convert` 区块改 Caps→Scrap + Scrap→Caps 两行(去 Core→Caps)。

**UI 币种**:
- 顶栏 `_add_top_hud` 货币芯片:去掉 core 芯片,只建 caps + scrap。
- `_show_tier_confirm`:unlock 显示 Scrap 花费 + 判 `scrap>=`;upgrade 显示 Caps。用
  `building_cost_currency(id)` 取。
- outpost/clinic/market 屏的花费角标 currency 参数对应改。

## 验证

- smoke gate;headless 迁移测试(旧档带 core → load 不崩、core 无残留、balances 清零);
  headless:unlock 扣 scrap、upgrade 扣 caps、契约给 scrap、兑换双向。
- gdscript-reviewer 全批;grep `add_core|spend_core|"core"|core_changed` 零活引用。
- **catalog**:bounties 页 reward 列更新(core→scrap);smoke。
- 文档:PRD(货币三→二、经济表)、PROJECT_STRUCTURE、building-screens-functions(货币栏)、
  conventions 若提及。

## 风险
- Scrap 早期来源:靠拆装备 + 战斗产出;解锁楼要 Scrap,若前期 Scrap 紧,调战斗产出/解锁价 [待平衡]。
- 存档兼容:老档 core 直接丢,不回补(owner 定清零)。
- 数值尺度:Caps(百-千)与 Scrap(十-百)不同,沿用现值后需实测调 [待平衡]。
