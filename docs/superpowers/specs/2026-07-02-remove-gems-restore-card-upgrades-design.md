# 删宝石 + 卡牌升级回归 Design Spec

**Date:** 2026-07-02
**Status:** Approved (brainstorming) → ready for writing-plans
**Scope:** 一个内聚子系统 —— 卡牌成长轴重做。删除宝石系统,让局内卡牌升级回归作为**唯一**的卡成长机制。

---

## 1. Motivation / 目标

当前卡牌成长的唯一轴是**宝石**:8 颗宝石当作可嵌卡的关键词载体,占背包格、手动 socket、嵌入锁死、局内清空。用户判定:**宝石"投入的心智/管理成本 > 回报"**——玩家要管背包、决定嵌哪张、还拔不出来,只换来「出牌 +1 力量」的边际效果;同时缺少"把一张卡养成核心"的成长感。

**决策(brainstorming 方案 A)**:删除宝石,让**局内卡牌升级**回归承担卡牌成长。升级用**混合模型**(公式兵底 + 关键卡手写)。**本轮不新增力量流档案内容**(留作将来单独一轮);指数滚雪球暂由现有缩放卡(`charged_shot` 2×力量、`combat_stim` +力量、`瞄准伤口`)提供,较温和。

**非目标(本轮明确不做)**:
- 不新增任何缩放/累积器卡牌,不做"力量流档案扩充"。
- 升级**不做永久化**(不进 meta、不进前哨站编辑器);每局重置。
- 不改动战斗引擎已有的缩放效果类型(`gain_strength` / `deal_damage_str_mult` / `apply_bleed_scaled` / `double_target_bleed` 等保持原样)。

---

## 2. 现状事实(执行者先读)

**宝石散落 3 处 + 存储:**
- 数据:`run_system/data/gems/*.json`(8 颗:brute, bulwark, keen, leech, spark, swift, venom, wealthy)。结构 `{id, title, trigger, effects[], icon}`。
- `run_system/core/run_manager.gd`:`gem_inventory`(var ~117)、`_gem_cache`(~121)、`add_gem_to_backpack`(~1102)、`backpack_gem_ids`(~1116)、`_find_gem_cell`、`socket_gem`(~1859,注意现在**每卡只 1 槽**:`if gems.size() >= 1: return false`)、`gem_inventory.clear()`(~689)、legacy 迁移 `add_gem_to_backpack`(~2157)。`add_card` 给每条 deck 条目写 `"gems": []`(~807)。
- Rest 篝火:`run_system/ui/map_scene.gd` `_open_rest_choice()`(~831):回血按钮(25% maxHP)+ 「挖矿得宝石」按钮(~898)。
- Loot:`run_system/ui/loot_reward.gd` 精英战 append `gem_draft`(~129);普通战给卡+Luck 工具;Boss loot 在 `battle_scene/battle_scene.gd` `_victory` 处理(宝石 + 遗物)。
- Deck viewer / 顶栏:socketing "any time from the top-bar deck button" —— 存在宝石嵌入 UI(`run_deck_viewer_modal.gd` 或相关),需清理。
- Validator:`battle_scene/data_validator.gd` 有 gem schema + gem 相关 ALLOWED 触发/效果校验。
- Catalog:`scripts/gen_catalog_html.py` + `docs/catalog_html/gems.html`。

**卡牌结构**:`battle_scene/card_info/player/*.json`(54 张),字段 `name/title/rarity/type/cost/description/front_image/side/effects[]`。**无 upgrade 字段**(旧 `_plus.json` + `card_upgrade_modal` 已删净)。

**已存在、本轮复用不动的缩放引擎**:`gain_strength`、`deal_damage_str_mult`(charged_shot)、`apply_bleed_scaled`(dissect/bone_breaker)、`double_target_bleed`(limit_break)。

---

## 3. 设计

### 3.1 删除宝石(数据 + 逻辑 + 迁移 + 扫雷)

- **删数据**:`run_system/data/gems/`(整目录)、宝石图标引用、`docs/catalog_html/gems.html`(由 catalog 重生成时消失)。
- **删逻辑(run_manager)**:`gem_inventory`、`_gem_cache`、`add_gem_to_backpack`、`backpack_gem_ids`、`_find_gem_cell`、`socket_gem`、`get_gem_data`/gem 缓存加载(若有)。`add_card` 不再写 `"gems"` 字段。
- **删 UI**:map_scene rest 的「挖矿得宝石」按钮;loot_reward 精英 `gem_draft` append(**精英位不替换**,回到卡+装备几率);deck viewer / 顶栏的宝石嵌入 UI;equipment_panel/character_window 若渲染 gem 背包格的分支。
- **删 Boss 宝石**:`battle_scene._victory` 去掉宝石授予,**保留遗物**(装备继续走 Luck 掉落那套)。
- **存档迁移**(load 时,一次性、不崩):
  - 剥掉每条 `player_deck[].gems`(直接丢弃已嵌宝石)。
  - 清空背包里的宝石格 → 变空格(归还给装备/工具)。
  - `gem_inventory` 读入后忽略/清空。
  - 迁移是**容错读**(旧 key 存在就跳过,不 push_error)。
- **扫雷 grep**:遗物 / 事件 / 工具 JSON + `.gd` 里所有 `gem`/`socket` 引用,逐一中和(例如任何"给宝石/宝石增强"的遗物或事件效果,改成等价的其它奖励或删除)。
- **validator**:移除 gem schema、gem 相关 ALLOWED 列表、gem 触发校验。

### 3.2 卡牌升级模型(混合,局内)

**状态**:`player_deck` 条目新增 `upgraded: bool`(默认 false)。**每张卡最多升一次;局内有效、每局重置**(`start_new_run` / 迁移不保留)。不进 meta。

**升级态解析**(新建 helper `run_system/core/card_upgrade.gd`,`preload`,无 class_name):
```
resolve(base: Dictionary) -> Dictionary   # 返回"升级后"的有效卡数据
    up = base.get("upgrade", {})           # 可选手写块
    result = deep copy of base
    if up.has("cost"):        result.cost = up.cost
    if up.has("title"):       result.title = up.title
    if up.has("description"): result.description = up.description
    if up.has("effects"):     result.effects = up.effects        # 手写:整段覆盖
    else:                     result.effects = formula(base.effects)  # 公式兵底
    return result
```

**公式兵底 `formula(effects)`**(只 bump **明确正向**的真实类型;费用不碰;字段名对齐真实 JSON——伤害/格挡/属性用 `amount`,状态用 `stacks`):
| effect type | bump |
|---|---|
| `deal_damage` / `deal_damage_all` | `amount += 2` |
| `gain_block` | `amount += 3` |
| `gain_strength` / `gain_dexterity` / `gain_luck` / `gain_intelligence` / `gain_energy` | `amount += 1` |
| `apply_status` / `apply_status_all`(**敌方**) | `stacks += 1` |
| `draw_cards` | `amount += 1` |
| **排除**:`apply_status_self`(可能自我减益)、`apply_bleed_scaled`/`deal_damage_str_mult`/`scale_damage_by_attacks`/`double_target_bleed`(缩放)、`lose_hp`/`lose_gold`(代价)、其它无数值 | 不 bump → 走 bespoke |

> 排除项若是某卡唯一效果 → 该卡公式升不动 → validator warn → Phase 5 必补手写 `upgrade` 块。

**手写层 `upgrade` 块**(卡 JSON 内联,给公式覆盖不了或想要个性的卡):可含 `cost` / `title` / `description` / `effects`(整段)任意子集。**降费只走手写**。示例:
```json
"upgrade": { "cost": 0, "description": "Deal damage equal to 2× your Strength.", "effects": [ ... ] }
```

**升级覆盖率保证**:writing-plans 阶段审计 54 张卡——公式 bump 不到任何数值、且无手写块的卡,**必须补一个手写 `upgrade` 块**(否则升级是空操作)。validator 对"既无手写块又无可 bump 数值"的卡 **warn**(shipped 数据应做到人人可升)。

**应用点**:卡面构建时(`my_card_factory` / `cached_card_factory` 读 card_info 产出实例)——若该 deck 实例 `upgraded=true`,用 `card_upgrade.resolve()` 的结果替换有效 `cost/title/description/effects`。战斗引擎读到的即升级后效果。升级后卡面显示升级标记(名字加 "+" 或角标)。

### 3.3 在哪升级(填坑后只剩两处)

- **Rest 篝火**(`_open_rest_choice`):回血 **或 升级一张卡**,二选一(经典 StS smith)。「升级」按钮 → 打开**升级选卡 modal**(新建精简 `run_system/ui/card_upgrade_modal.gd`:列出当前牌组、置灰已升级的、选一张 → 设 `upgraded=true` → 关闭 + 释放 rest 点击 guard)。
- **精英 loot**:宝石位**删除**,不替换(卡 + 装备几率照旧)。
- **Boss loot**:宝石 → **遗物**(§3.1 已述)。

### 3.4 收尾

- **validator**:去 gem 校验;加 `upgrade` 块 schema(cost int / title,description string / effects 走与主 effects 相同的 ALLOWED_* 校验);升级覆盖率 warn。
- **catalog**:`gen_catalog_html.py` 卡片渲染升级态(基础 vs 升级后:cost/desc/effects 差异)。删 gems 页(生成器不再扫 gems 目录)。**改完 JSON+CSV 后重生成 `docs/catalog_html/`,HTML 必须与游戏数据一致**(项目硬规则)。
- **翻译**:删宝石相关键(`ui_*` 里 gem 键、rest 挖矿键、loot gem 键);加升级 UI 键(rest 升级按钮、升级 modal 文案、升级卡角标)。
- **文档同步**:`docs/PRD.md`(宝石删除、升级回归、成长轴说明)、`docs/PROJECT_STRUCTURE.md`(gems 目录删除、card_upgrade.gd/modal 新增)、`docs/conventions/*`(卡数据 `upgrade` 块约定)。

---

## 4. 组件边界(units)

| Unit | 职责 | 依赖 |
|---|---|---|
| `run_manager.gd`(改) | 删所有 gem 状态/函数;`add_card` 去 `gems` 字段;deck 条目 `upgraded`;load 迁移剥宝石 | — |
| `card_upgrade.gd`(新) | `resolve(base)` + `formula(effects)`;纯函数、无副作用、可单测 | 卡 JSON 结构 |
| `my_card_factory` / `cached_card_factory`(改) | 构建实例时按 `upgraded` 套 `card_upgrade.resolve()` | `card_upgrade.gd` |
| `card_upgrade_modal.gd`(新) | 选一张未升级卡 → 置 `upgraded=true` | run_manager |
| `map_scene._open_rest_choice`(改) | 挖矿按钮 → 升级按钮 → 开 modal | modal |
| `loot_reward.gd`(改) | 删精英 gem_draft | — |
| `battle_scene._victory`(改) | 删 Boss 宝石,留遗物 | — |
| `data_validator.gd`(改) | 去 gem 校验;加 `upgrade` 校验 + 覆盖率 warn | — |
| `gen_catalog_html.py`(改) | 渲染升级态;不再扫 gems | — |

---

## 5. 数据流

1. **获得升级**:rest 篝火选"升级" / (无其它来源)→ modal 选卡 → `player_deck[i].upgraded = true`。
2. **进战斗**:factory 遍历 deck,`upgraded` 的实例经 `card_upgrade.resolve()` → 有效 cost/desc/effects 变升级态 → combat_engine 照常执行。
3. **每局重置**:`start_new_run` 重建牌组时 `upgraded` 归 false(局内成长,不跨局)。
4. **旧存档载入**:迁移剥掉 `gems`、清宝石背包格;`upgraded` 缺省 false。

---

## 6. 验证

- 每阶段 `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` 门禁(尾部 `all schemas passed` + `boot clean`)。
- `gdscript-reviewer` subagent 过一遍改动(freed-node / Variant / falsy-zero / 迁移健壮性)。
- **旧存档迁移单测**(headless 脚本):构造带 `gems`/宝石背包/`gem_inventory` 的假存档 → load → 断言无宝石残留、不崩、`upgraded` 缺省 false。read-only,不污染真实 slot(见 [[mcp-verify-no-save-pollution]])。
- 升级路径 headless 校验:置一张卡 `upgraded=true` → factory 产出 → 断言 effects/cost 为升级态;公式卡 + 手写卡各一。
- catalog 重生成后人工/脚本比对 HTML 与 JSON 一致。
- 分阶段**本地 commit,不 push**(用户晨间验收;见 [[git-codex-mixed-commits]] [[autonomous-run-workflow]])。

---

## 7. 风险 / 未决

- **升级覆盖率**:少数卡(纯触发/无数值)公式升不动 → 必须手写,plan 阶段逐张审计(§3.2)。
- **socket UI 藏得深**:宝石嵌入入口可能散在 deck viewer + 顶栏 + 角色窗,grep 要彻底,别留死按钮。
- **遗物/事件引用宝石**:若有"给宝石"的遗物/事件,删宝石后需改成等价奖励(§3.1 扫雷),否则空引用。
- **指数爽感温和**:本轮不补力量流内容,滚雪球较弱——已与用户确认,留作将来单独一轮。
- **cached_card_factory 缓存**:卡信息缓存(P5 的 `get_card_info_cache`)缓存的是**基础**卡数据;升级态在实例构建时叠加,别把升级结果写回缓存。
