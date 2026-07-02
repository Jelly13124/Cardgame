# 装备系统重构 — 通用壳 + 保证属性词条

**Date:** 2026-07-01
**Status:** Design (awaiting user review)
**Topic:** equipment-affix-shell-redesign

---

## 目标

把装备从"每件独立设计"改成**通用壳 + 随机词条**模式:同部位同稀有度共用一个外观(asset),
装备的价值几乎全部来自随机词条;每件保证至少 1 个属性词条。只有绿色套装保留独立身份与美术。

## 背景 / 现状(重要)

装备**已经是** affix(词条)驱动的:

- `run_system/core/affix_pool.gd` 在掉落时按稀有度 roll 词条:`AFFIX_COUNT = common 1 / uncommon 2 / rare 3 / set 3 / cursed 3(+1 curse)` —— **数量与本设计一致**。
- 词条池 `POSITIVE`:5 个属性词条(`attr_strength/constitution/intelligence/luck/charm` 各 +1)+ `crit_pct +5` + `max_hp +10`;`CURSE` 为负向诅咒词条。
- `make_equip_instance(base_id, rarity, cursed)` 读 base 的 `slot/set_id`,用 `AFFIX_POOL.roll(rarity, cursed)` 生成实例;稀有度在**掉落时**作为参数传入。
- 铁匠铺 `MetaProgress.curse_stash_item(index)`(100 Scrap)把一件装备重 roll 成诅咒档。

现状 23 件装备 = **8 件杂项独立装备** + **15 件套装**(tank_engineer / warden / weak_hunter,各 5 件)。
现状**诅咒装有系统但无掉落入口**(`make_equip_instance` 的 `cursed` 参数没人传 `true`)。

**因此本次真正的增量只有:** (1) 保证 1 个属性词条;(2) 通用壳 + 按 slot×rarity 共用 asset;
(3) 诅咒装掉落入口(A3+);(4) 删掉 8 件杂项、塌缩为通用壳;(5) 套装保留。

---

## 设计

### 1. 稀有度 × 词条规则

每件装备**保证第 1 个词条是随机属性词条**(`attr_*`),其余随机补齐。

| 档 | 正词条 | 构成 | 备注 |
|---|---|---|---|
| 普通 common | 1 | 1 属性 | |
| 罕见 uncommon | 2 | 1 属性 + 1 任意 | |
| 稀有 rare | 3 | 1 属性 + 2 任意 | |
| 诅咒 cursed | 3 正 + 1 诅咒 | 3 正含 1 属性 | 见 §5 |
| 套装 set(绿) | 3 | 1 属性 + 2 任意 | 额外 set bonus,见 §3 |

- **属性词条** = `attr_strength / attr_constitution / attr_intelligence / attr_luck / attr_charm`(+1)。
- **任意词条** = 上述属性 + `crit_pct(+5%)` + `max_hp(+10)`。
- 词条类型不重复(沿用现有 `_pick_distinct_positives`)。

### 2. 装备数据模型 — 通用壳

- **base 壳 JSON:15 个** = 5 部位(head/chest/weapon/hands/accessory)× 3 档(common/uncommon/rare)。
  - 通用命名,例:`gear_head_rare`,显示名"稀有·头部装备"。
  - 诅咒**不做独立 base 壳**:它是 instance 层的状态(`rarity=cursed` + cursed 词条),
    与铁匠铺 curse 的工作方式一致(curse 不更换装备本体,只重 roll 词条)。掉落 A3+ 时把
    掉落的壳实例 `cursed=true`;渲染时按 `slot×cursed` 取图。
  - *(备选:也可显式做 20 个 base 壳含 cursed 档——更贴"每部位每档一个"的直觉,但多 5 个近乎
    冗余的 JSON,且与铁匠铺 curse 的 instance 语义重复。推荐 15 壳方案;user review 可改。)*
- **稀有度在掉落时决定**(现有 `make_equip_instance(base, rarity, cursed)` 已支持)。

### 3. 套装(保留)

- 保留现有 **3 套 × 5 件 = 15 件**(tank_engineer / warden / weak_hunter),各自独立 `id/name/美术`。
- 掉落/获得时同样 roll 随机词条(3 个,含 1 属性),额外带 `set_id` → 集齐 3 件 / 5 件触发 set bonus
  (`equipment_sets/*.json` 的 tiers)。
- **掉落途径**:普通掉落中以 `SET_PIECE_DROP_CHANCE`(~15%)替代通用壳出现一件对应档位的套装件(壳为主、套装靠运气凑);其余出通用壳。套装件不诅咒。
- 美术每件单独制作(Codex)。

### 4. 删除 8 件杂项 + 迁移

- 删除:`old_hat / rusted_dagger / scrap_breastplate / reinforced_plating / combat_harness /
  lucky_charm / old_world_relic / wasteland_revolver` 的 JSON + 翻译 + 掉落引用。
- **迁移**:掉落表改为指向 15 通用壳;玩家 stash 里**已存的**旧实例继续可用
  (`as_equip_instance` 已按 base `bonuses` 兜底显示),不强制转换,避免破坏存档。

### 5. 诅咒装来源(两条)

1. **掉落(A3+)**:Ascension ≥ 3 时,装备掉落有概率(Luck/Ascension 加权)把该件置 `cursed=true`。
   A0–A2 不出现诅咒装。
2. **铁匠铺**:`curse_stash_item`(100 Scrap)保留不变——把一件非诅咒装重 roll 成诅咒档。

诅咒档词条 = `AFFIX_POOL.roll(rarity, cursed=true)`:3 正(含 1 属性)+ 1 诅咒。

### 6. 美术(选项一:20 张)

- **20 张通用壳图** = 5 部位 × 4 档(common/uncommon/rare/cursed),放
  `battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png`。普通/罕见/稀有/诅咒外观不同。
- 套装 15 件单独出图(Codex),另行 asset-spec。
- 需 Codex 交付;走 ADR-0005 asset-spec 契约 + 先出样审核。

### 7. 图标渲染

- `equipment_icon.gd`:按 `slot + rarity` 解析 `ui/equipment/{slot}_{rarity}.png`,
  取代读取每件 JSON 的 `sprite` 字段;缺图时 fallback 现有 slot 图 / 字母。
- 套装实例仍用各自 JSON 的 `sprite`。

---

## 受影响文件 + wiring

| 文件 | 改动 |
|---|---|
| `run_system/core/affix_pool.gd` | `roll()` 先保证 1 个 `attr_*`,再补其余;加 `_pick_attribute()` helper |
| `run_system/core/run_manager.gd` | 掉落表指向 15 壳;A3+ 诅咒入口(`make_equip_instance(..., cursed)`) |
| `run_system/data/equipment/*.json` | 新增 15 壳;删除 8 杂项 |
| `run_system/ui/equipment_icon.gd` | 按 `slot×rarity` 选图 |
| `assets/translations/content_equipment.csv` | 15 壳的名字/描述;删 8 杂项条目 |
| `battle_scene/data_validator.gd` | 壳需满足 equipment schema(slot/rarity/bonuses 占位) |
| `scripts/gen_catalog_html.py` | equipment 页反映壳(标注"roll N 词条,保证 1 属性") |
| `docs/asset-spec-*.md` | 新增 20 壳图 + 套装图的 Codex 契约 |

## 验证

- `bash scripts/smoke_test.sh` → `DataValidator: all schemas passed` + 干净启动。
- `python scripts/gen_catalog_html.py` 重新生成,`equipment.html` / `index.html` 反映壳。
- 只读抽样校验:`AFFIX_POOL.roll("common")` 必含 1 属性词条;`roll("rare")` 3 个含 ≥1 属性;
  `roll("cursed")` = 3 正(含 1 属性)+ 1 诅咒。

## 未决 / 风险

- **数据模型 15 壳 vs 20 壳**(§2):推荐 15 + 诅咒为 instance 变体;user review 可改 20。
- **诅咒掉落概率**具体数值(A3+ 的百分比)留待实现时给一个可调常量 + `[tunable]` 标注。
- 美术为 Codex 交付项,代码侧先用 fallback,不阻塞 smoke。
