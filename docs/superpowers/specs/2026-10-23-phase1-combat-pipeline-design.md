# 阶段 1：统一数值与效果管线 — 设计（spec）

日期：2026-10-23
分支：`refactor/phase1-combat-pipeline`（worktree：`Desktop/Cardgame-phase1`，基于阶段 0 分支 `17d4e6c`）
来源：架构审查路线图 `docs/reviews/sts2-architecture-review/10-roadmap.md` 阶段 1，以及与作者的逐条确认（2026-10-22～23 对话）。
对照：STS2 v0.107.1 反编译代码（`Hook.ModifyDamage`、`ValueProp`、`IntangiblePower`、`AbstractModel.AfterDamageGiven/AfterAttack`、`ActionQueueSet`/`ActionExecutor`），以及 slaythespire.wiki.gg 的 STS2 易伤页面。

## 目标

1. 伤害、格挡、状态层数各只有**一条**计算管线（加法 → 乘法 → 取整 → 减免 → 上限），带预览模式；瞄准预览、敌人意图、卡面数字、实际结算全部调用它。
2. 卡牌、道具、遗物、装备套装、敌人行动、诅咒、事件共用**一个效果执行器**（注册表），伤害与格挡只通过命令执行，命中链不能被绕过。
3. 修正来源（属性、状态、遗物、套装、幕倍率）以**监听者**形式接入管线；命中后/攻击后有统一钩子。
4. 出牌、使用道具、结束回合进入**顶层动作队列**串行执行（STS2 的 `ActionQueueSet` 模型）；动作内部的命令与钩子按 `await` 深度优先执行。
5. 阶段 0 的两个一致性测试转绿；现有契约测试保持通过（随接口迁移改写）。

不在范围：伤口体系与刺客英雄（记入路线图，单独阶段）；内容注册表（阶段 2）；每个能力/遗物一个脚本的完整监听者模型（阶段 3，本阶段只做适配器）；卡面描述模板与 `vars`（阶段 4，本阶段只让数字来自管线）；文件迁入 `ui/`（阶段 5）。放电体系保持现状。

## 已确认的规则决定

| # | 决定 | 来源 |
|---|---|---|
| D1 | Final Salvo（cascade）与 Kinetic Rebound（rebar_wave）没有套装伤害加成与命中效果是 **bug**，修复 | 作者 |
| D2 | “本回合/本场已打出攻击”计数**按打出算**：每打出一张攻击牌计 1 次，与段数、重放次数无关 | 作者 |
| D3 | 智力只加给**施加给敌人**的状态 | 作者 |
| D4 | 命中效果只由**卡牌造成的伤害**触发（含卡牌引发的 Overload 放电）；遗物、荆棘、状态伤害不触发 | 作者 |
| D5 | 采用 STS2 规则：只有卡牌伤害效果与敌人攻击“有加成”（吃力量、虚弱、易伤、暴击）；卡牌与敌人招式的格挡吃体质/脆弱。遗物、套装、道具、荆棘、灼烧的伤害与格挡**按固定数值**结算。道具伤害因此不再吃易伤 | 作者（选项 1），STS2 `ValueProp.Unpowered` 与 wiki 核实 |
| D6 | 闪避改为 **无实体（intangible）**，按回合计：持有期间每段伤害最多 1 点（所有伤害类型，含格挡扣减与预览）；层数在**对手方回合结束时**减 1 | 作者（选项 1） |
| D7 | 暴击只对“有加成的玩家伤害”判定；例外：Overload Protocol 让 Overload 放电可暴击。随机暴击不预览，只有必定暴击（Deadeye 状态、必暴遗物）在预览中显示 | 作者 + 现有规则 |
| D8 | 方案 C：管线 + 命令 + 钩子 + 顶层动作队列，一次完成 | 作者 |
| D9 | 卡牌 JSON 的效果类型名保持不变（`deal_damage`、`scale_damage_by_attacks` 等），它们只定义“基础值从哪里来”，之后统一进入同一命中链 | 实施决定（避免数据与 Mod 兼容性变动） |

## 1. 伤害来源与属性

每次伤害、格挡、状态施加都带一个 **来源**（`source`）与 **属性**（`props`）：

- `source.kind`：`card` | `tool` | `relic` | `set` | `enemy` | `status` | `thorns` | `event` | `debug`；另带 `card`（来源卡节点）、`id`（遗物/套装/状态 id）、`dealer`（施加者生物，可为空）。
- `props` 位标志：`POWERED`（有加成）、`UNBLOCKABLE`（无视格挡）、`NO_STRENGTH`（不加力量，取自效果的 `no_str` 或基础值已含力量的效果类型）、`NO_CONSTITUTION`（`no_con`）。
- “卡牌来源” = `source.kind == card`。

| 来源 | 伤害 props | 格挡 props |
|---|---|---|
| 卡牌伤害效果（5 种伤害类型，任何卡牌类型） | `POWERED` | — |
| 卡牌格挡（`gain_block`、Charge Sink 的 Overload 转格挡） | — | `POWERED` |
| 卡牌引发的 Overload 放电 | 无（卡牌来源） | — |
| 敌人攻击 | `POWERED` | 敌人格挡招式：`POWERED`（吃自身脆弱） |
| 道具、遗物、套装 | 无 | 无 |
| 荆棘反伤、灼烧 | 无 | — |
| 自身失去生命（`lose_hp`） | 不是伤害：不经格挡，只受无实体上限 | — |

## 2. 伤害管线（每一段伤害各算一次）

1. **基础值**（由效果类型决定，见 §5）。敌人攻击：招式数值 × 幕伤害倍率（非 Boss，四舍五入，与生命缩放一致，属于敌人基础强度）。
2. **加法**（仅 `POWERED`）：
   - 力量：攻击方是玩家且无 `NO_STRENGTH`；
   - 装填（Loaded）：来源是攻击牌的卡牌伤害；一次出牌结算中**第一个**伤害效果开始时整体消耗，该效果的所有目标都获得加成；
   - 套装 `attack_damage_bonus`：来源卡牌是攻击牌；
   - 遗物 `player_attack_damage/add_damage`：攻击方是玩家。
3. **乘法**：暴击（§3）、虚弱（攻击方，`POWERED`）、易伤（受击方，`POWERED`）。
4. **取整**：向下取整一次（STS2 与 wiki 规则）。原先暴击用四舍五入、敌人意图用四舍五入，统一改为向下取整。
5. **减免**（仅 `POWERED` 且攻击方是敌人、受击方是玩家）：遗物 `enemy_attack_damage/reduce_damage`（`once_per_combat` 只在实际结算时标记已用），下限 0。
6. **上限**：受击方有无实体 → 最多 1。
7. **格挡与生命**：除非 `UNBLOCKABLE`，先扣格挡再扣生命。

预览模式走完全相同的步骤，但：不消耗装填、必暴、一次性遗物；不掷随机暴击；不产生任何副作用。预览数值 = 第 6 步的结果（进入格挡之前），与实际交给受击方的数值逐一对应。

## 3. 暴击

- 判定对象：攻击方是玩家的 `POWERED` 伤害，每段单独判定；Overload Protocol 生效时 Overload 放电也判定。
- 必定暴击：先看必暴遗物（每回合第一段攻击），再看 Deadeye 状态（消耗 1 层）。预览只读不消耗。
- 倍率：基础 1.5；遗物覆盖取最大值（Volatile 1.75）；All In 为 2.0 且优先。
- 副作用（仅实际结算）：标记暴击反馈；Hot Streak 获得 2 装填；Ricochet Loader 加一张 Reload；All In 的非暴击段获得 2 装填（每段一次，基础伤害 > 0 时）。

## 4. 格挡与状态层数

**格挡**：基础值 → 加法（`POWERED`：体质（无 `NO_CONSTITUTION` 时）、套装 `skill_block_bonus`（技能牌来源）、遗物 `player_gain_block/gain_block`）→ 乘法（`POWERED`：脆弱 0.75、遗物 `gain_block_crit` 随机 1.5，预览不掷）→ 向下取整。获得后钩子：Reactive Plating（卡牌来源 → 获得同量荆棘）、Scavenger Lens（`POWERED` 玩家格挡 → 随机敌人 3 点遗物伤害）。
变化：Inertial Dampener 的 +2 现在在脆弱之前相加（原来在之后）。

**状态层数**：基础层数 → 加法：
- 智力：来源是卡牌或道具、目标是敌人、效果类型是 `apply_status`/`apply_status_all`、状态不是眩晕（`apply_short_circuit_scaled` 自带属性公式，不再加）；
- Brutal Servo：玩家一方施加的**每一次**短路 +N（卡牌、道具、遗物、套装、荆棘转短路）。变化：套装 Warden 与 Serrated Barbs 的短路现在也吃这个加成。

## 5. 效果执行器

`core/effects/effect_registry.gd`：效果类型 → 处理器，处理器声明可用上下文（`combat`、`run`）。执行入口 `execute(ctx, effect)`；未知类型 `push_error` + `assert`（沿用规则 5）。`DataValidator` 的允许列表保留（两处登记规则），新增契约测试检查“允许列表 ⊆ 注册表”。

战斗处理器（`battle_scene/combat/combat_effects.gd`）由战斗场景注册，替代 `combat_engine._apply_effect` 的 27 个分支。5 种伤害类型只计算基础值：

| 类型 | 基础值 | 隐含 props |
|---|---|---|
| `deal_damage` / `deal_damage_all` | `amount` | `POWERED`（`no_str` → `NO_STRENGTH`） |
| `deal_damage_str_mult` | `base + 力量 × mult` | `POWERED` + `NO_STRENGTH` |
| `deal_damage_block_mult` | `当前格挡 × mult` | `POWERED` + `NO_STRENGTH` |
| `scale_damage_by_attacks` | `base + per × 已打出攻击数`（`scope`） | `POWERED` + `NO_STRENGTH` |

来源卡牌、道具、遗物、套装、敌人行动、诅咒的 `end_turn_in_hand`、事件选项都通过同一个执行器，只是 `ctx.source` 不同：
- 遗物动作（回合开始格挡/能量/状态/全体伤害/临时力量、胜利治疗/金币等）→ 对应效果类型，`source.kind = relic`；
- 套装动作（`start_turn_block`、`start_battle_block`、`start_turn_energy`）→ `gain_block` / `gain_energy`，`source.kind = set`；
- 敌人招式：`attack`/`attack_ramp`/`attack_all` → 伤害命令；`attack_status` → 伤害 + 命中时施加状态；`block`/`breakable_block`/`reflective_plating`/`heal`/`buff_self`/`summon`/`telegraph`/`add_curse` 注册为敌方处理器；招式 JSON 不变；
- 事件（`run` 上下文）：`gain_gold`、`lose_hp`、`heal`、`gain_scrap`、`gain_relic`、`gain_equipment`、`gain_attribute`、`add_curse`，从 `RunManager.apply_event_effects` 移入 `core/effects/run_effects.gd`，`apply_event_effects` 改为调用注册表。

## 6. 命令与钩子

**命令**（`battle_scene/combat/combat_commands.gd`，负责表现）：
- `damage(source, targets, base, props)`：对每个目标 → 管线（实际模式）→ 提交副作用 → `take_damage` → 钩子 `after_damage_given` / `after_damage_received`（荆棘反应挂在后者）。
- `after_attack` 由出牌结算在每个结算轮次结束后发出（攻击牌、目标存活），敌人攻击招式结算后也发出。
- `gain_block(ctx, creature, base, props)`、`apply_status(ctx, target, status, stacks)`、`lose_hp(ctx, creature, amount)`。
- 受击方 `take_damage(amount, silent, tags)` 只负责“扣格挡、扣血、表现”，不再计算任何修正。

**钩子**（`core/combat/combat_hooks.gd`，监听者实现其中任意方法即可）：

| 钩子 | 用途 |
|---|---|
| `modify_damage_additive / multiplicative / reduction / cap(calc)` | 伤害各阶段 |
| `modify_block_additive / multiplicative(calc)` | 格挡各阶段 |
| `modify_status_stacks(calc)` | 状态层数 |
| `after_damage_given(result)` | 命中效果：套装 `attack_apply_status`（来源卡是攻击牌、目标存活）、敌人 `attack_status` 的附加状态 |
| `after_damage_received(result)` | 荆棘反伤（`POWERED` 伤害、攻击方存在）、Medkit Drone（玩家被敌人攻击且损失生命） |
| `after_attack(attack)` | 遗物 `player_attack`（每次结算轮次一次，目标存活） |
| `after_block_gained(result)` | Reactive Plating、Scavenger Lens |

监听者（本阶段为适配器，阶段 3 再拆成每个内容一个脚本）：`core/combat/rules/attribute_rules.gd`（力量/体质/智力）、`status_rules.gd`（虚弱/易伤/脆弱/无实体/装填/荆棘）、`crit_rules.gd`、`RelicEffectSystem`、`EquipmentSetSystem`。监听者顺序固定：属性 → 状态 → 暴击 → 遗物 → 套装（遗物内部按持有顺序）。

钩子嵌套执行（深度优先），设**深度上限 16**：超过时 `push_error` 并跳过该层，防止设计错误造成死循环。

## 7. 无实体

- 状态名 `intangible`，替换 `dodge`：Smoke Step 改为获得 1 层无实体；chrome_hound 的 `buff_self` 改为无实体 1 层；`dodge` 从允许列表、状态表、图标、翻译中移除，图标复用原闪避图标并改名。
- 管线第 6 步与 `lose_hp` 都受上限约束。
- 减层：玩家回合结束时，每个敌人的无实体 −1；敌人回合全部结束时，玩家的无实体 −1。

## 8. 顶层动作队列

`core/combat/action_queue.gd`：`enqueue(action)`，动作是带 `execute()` 协程的对象；执行器逐个 `await`。动作类型：`PlayCardAction`、`UseToolAction`、`EndTurnAction`（弃牌、诅咒惩罚、敌人回合、下一回合开始）。

- 出牌：合法性检查与费用（能量、攻击次数）在**入队时**完成，卡牌立即离开手牌并飞向出牌区；效果结算在队列中按顺序执行。原先“不同的牌可以并行结算”取消（S1-06）。
- 结束回合按钮入队，排在已入队的出牌之后；敌人回合期间拒绝玩家输入。
- 战斗结束（胜利/失败）时清空尚未开始的动作，正在执行的动作在下一个检查点退出。
- 攻击计数（D2）在 `PlayCardAction` 完成全部结算（含重放）后 +1。

## 9. 预览、意图、卡面

- 瞄准预览：对卡牌的每个伤害效果分别走预览管线后求和（与实际逐个取整一致）；只计一次结算轮次（重放由卡面关键词显示）。
- 敌人意图：攻击招式的数字 = 预览管线（敌人 → 玩家）。
- 卡面描述：`deal_damage`、`deal_damage_all`、`gain_block` 的数字 = 预览管线（无目标），颜色比较逻辑不变。

## 10. 其他修正

- `combat_engine.gd` 保留为薄层：出牌结算编排（开枪动画、重放、阴阳匹配奖励）与对执行器的公开入口 `execute_effect(effect, target, source)`；外部不再调用私有 `_apply_effect`（S1-11）。
- `pay_energy(-n)` 用于加能量的调用改为 `gain_energy(n)`（S1-11）。

## 测试与验收

- `combat_preview_parity_test`、`enemy_intent_parity_test` 改为通过新的公开接口比较“预览 vs 实际”，并加入无实体、装填、套装、减伤遗物（含一次性）、幕倍率、Deadeye 必暴的组合；从 `expected_failures.txt` 删除两行。
- 新增 `combat_pipeline_contract_test`：阶段顺序与取整、props 表（道具/遗物/荆棘不吃易伤与力量）、无实体（伤害、格挡扣减、lose_hp、减层时机）、暴击规则、格挡与层数管线、Brutal Servo 范围。
- 新增 `combat_hooks_contract_test`：Final Salvo 与 Kinetic Rebound 获得套装加成与命中效果；命中效果只由卡牌来源触发；攻击计数按打出；钩子深度上限。
- 新增 `action_queue_contract_test`：快速连续出两张牌按入队顺序结算；结束回合排在出牌之后；战斗结束清空队列。
- 新增 `effect_registry_contract_test`：允许列表 ⊆ 注册表；事件效果走注册表；未知类型报错。
- 现有测试中直接调用 `_apply_effect`、`_consume_loaded_bonus`、`_short_circuit_overload`、`_consume_short_circuit`、`_compute_display_attack`、`_execute_action` 的地方改为新的公开接口，断言含义不变（数据断言不动）。
- 完整入口 `tools/run_tests.ps1` 退出码 0；分层检查通过（`core/` 不引用场景树与 UI）。

## 已知的数值变化（需要作者试玩确认手感）

1. 道具、遗物、套装的伤害不再吃力量、虚弱、易伤、暴击，也不触发荆棘；道具格挡不吃体质/脆弱。
2. 暴击与幕倍率外的乘法统一向下取整：奇数伤害暴击少 1。
3. 闪避 → 无实体（Smoke Step 明显变强；chrome_hound 让玩家一整回合只能造成 1 点/段）。
4. 重放不再额外计入“已打出攻击数”。
5. Inertial Dampener 在脆弱之前相加；Brutal Servo 覆盖所有玩家施加的短路。
6. 出牌排队结算，快速连点时后一张牌等前一张结算完。

## 后续（记入路线图，不在本阶段实施）

- **职业卡池骨架**：卡牌增加职业 / 无色标记，奖励、商店、发现按职业取池（为第二个英雄做准备）。
- **刺客英雄与伤口体系**（作者 2026-10-23 提出）：伤口层数可叠加；按**每段伤害**推进撕裂计数，满 4 次撕裂，造成等于伤口层数的伤害后清零；撕裂伤害本身不推进计数。待定：撕裂伤害是否无视格挡、遇到无实体时撕裂如何处理、层数上限或倍率、刺客初始卡组（4 攻 4 防 + 1 张上伤口 + 1 张三连击）与初始遗物、双发弹夹的改动。挂在本阶段的 `after_damage_given` 钩子上实现。
- **路线图调整**：原阶段 5 的“出牌串行进入动作队列”（S1-06）已在本阶段完成；阶段 3 把 `RelicEffectSystem` / `EquipmentSetSystem` 适配器与 `status_rules` 拆成每个内容一个监听者脚本。
