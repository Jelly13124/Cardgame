# 敌人层级与普通遭遇平衡设计

## 目标

解决普通战斗在同一类别内从 12 血单鼠跳到 40+25 血双怪的问题，使敌人身份、图鉴分组与遭遇强度一致，并用自动验证阻止超预算普通遭遇回归。

## 审计结论

当前普通遭遇总基础生命范围：

| 阶段 | 当前范围 | 当前平均 |
|---|---:|---:|
| 前期 | 12–30 | 20.4 |
| 中期 | 25–42 | 32.1 |
| 后期 | 32–65 | 45.2 |

后期池包含 `rust_brute + riot_hound`（40+25）与 `rust_brute + scrap_rat`（40+12）。非首领敌人随后再乘每幕 HP 系数 `[1.0, 1.25, 1.5]`，进阶 1–5 还会额外乘 `[1.1, 1.2, 1.3, 1.4, 1.5]`。问题来自遭遇组合跨度和缺少敌人层级元数据，而不是废料鼠或锈蚀蛮兵单独的基础生命值。

## 敌人层级

所有敌人 JSON 新增必填 `tier`，允许值固定为：

```text
minion | normal | heavy | elite | boss
```

分配如下：

- `minion`：`ember_wisp`、`scrap_shard`、`scrap_rat`
- `normal`：`acid_spitter`、`chrome_hound`、`hex_drone`、`mortar_cart`、`mortar_cart_siege`、`riot_hound`、`riot_hound_alpha`、`slag_walker`、`trash_robot`、`wasteland_killer`
- `heavy`：`rust_brute`
- `elite`：`armored_patrol`、`chrome_warden`、`siege_breaker`
- `boss`：`ash_warden`、`junkyard_tyrant`、`rust_titan`

`tier` 是遭遇身份，不改变奖励、节点类型或战斗数值。重型普通怪仍来自普通节点，但只能单独出现。

## 普通遭遇池

新增开场池，并将普通遭遇重排为四段。括号为总基础生命：

### 开场层：综合层级 0–1，预算 12–18

- `scrap_rat`（12）
- `hex_drone`（16）
- `acid_spitter`（18）

### 前期：综合层级 2–3，预算 20–30

- `wasteland_killer`（20）
- `scrap_rat + scrap_rat`（24）
- `riot_hound`（25）
- `mortar_cart`（28）
- `trash_robot`（30）

### 中期：综合层级 4–7，预算 25–34

- `riot_hound`（25）
- `mortar_cart`（28）
- `slag_walker`（28）
- `acid_spitter + scrap_rat`（30）
- `wasteland_killer + scrap_rat`（32）
- `chrome_hound`（32）
- `riot_hound_alpha`（34）

### 后期：综合层级 8+，预算 34–50

- `riot_hound_alpha`（34）
- `rust_brute`（40）
- `mortar_cart + scrap_rat`（40）
- `chrome_hound + scrap_rat`（44）
- `mortar_cart_siege + scrap_rat`（44）
- `slag_walker + acid_spitter`（46）
- `riot_hound + riot_hound`（50）

第二幕因 `ACT_POOL_OFFSET == 4` 从中期池开始，第三幕从后期池开始；现有跨幕 HP/伤害系数保持不变。

## 遭遇约束

- `boss` 只能出现在 `ACT_BOSSES`；
- `elite` 只能出现在 `ELITE_ROSTER`；
- `heavy` 在普通遭遇中必须单独出现；
- `minion` 可在开场单独出现，开场之后只能双杂兵或作为普通敌人的支援；
- 普通遭遇总基础生命必须落在其阶段预算内；
- 本轮不修改任何敌人的 `max_health`、动作数值或跨幕/进阶乘区。

## 选择逻辑

`RunManager.select_encounter()` 使用综合层级：

```gdscript
var tier_floor := floor_idx + (current_act - 1) * ACT_POOL_OFFSET
```

分段改为：

```text
0–1 opening
2–3 early
4–7 mid
8+  late
```

仍从显式 roster 中等概率选择，不引入动态预算生成器，保证遭遇可读、可测试且不会产生未审过的组合。

## 验证器与图鉴

- `DataValidator.REQUIRED_ENEMY_KEYS` 加入 `tier`；
- 校验 tier 值属于允许列表；
- `validate_encounter_pools()` 加入开场池，并检查身份、组合规则和生命预算；
- `scripts/gen_catalog_html.py` 按 `minion / normal / heavy / elite / boss` 五组生成敌人图鉴，不再使用“Boss 与其他全部混合”的启发式分类；
- `docs/PRD.md` 与 `docs/PROJECT_STRUCTURE.md` 同步四段普通遭遇与 tier 规则。

## 验证

1. 20 个敌人 JSON 都有合法 tier；
2. 普通池中不存在 elite/boss；
3. `rust_brute` 只单独出现；
4. 单只 `scrap_rat` 只存在于 opening；
5. 四段所有 roster 均满足生命预算；
6. Act 1 各层、Act 2 开场与 Act 3 开场采样只返回对应池中的组合；
7. 精英与首领选择仍只返回各自 roster；
8. 生成图鉴按五层级分组且总数仍为 20；
9. DataValidator 与全项目 smoke 通过。

## 非目标

- 不修改敌人基础生命、攻击、格挡或状态数值；
- 不调整首领阶段；
- 不调整精英/普通地图节点出现概率；
- 不修改跨幕和进阶倍率。
