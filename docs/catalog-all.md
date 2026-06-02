# Catalog — All Content / 全内容表

**Last updated / 最后更新:** 2026-06-01
**Counts / 数量:** 21 cards (base) · 14 relics · 21 equipment items · 3 equipment sets

> Bilingual reference. The single English column on the right is the in-game string;
> the Chinese is for the design table. Detailed per-domain catalogs still live at
> `catalog-cards.md`, `catalog-relics.md`, `catalog-enemies.md` (may be stale —
> this file is the source of truth as of 2026-06-01).

---

## 🃏 Cards / 卡牌

### Quick stats / 速览

| Rarity 稀有 | Count 数量 |
|---|---|
| Common 普通    | 7 |
| Uncommon 罕见  | 7 |
| Rare 稀有      | 7 |
| **Total 合计** | **21** |

> **STR is auto-added to all attack damage and CON to all block, globally** (default +3 each); card faces show the BASE number only. The per-card `scaling` field is deprecated/removed. Costs are energy ⚡. The `+ / 升级` column lists the `_plus` rest-site upgrade where one exists.

### Common / 普通 (7)

| ID | Name / 名称 | Type / 类型 | Cost / 费 | Effect / 效果 | + / 升级 |
|---|---|---|---|---|---|
| `strike`        | Strike / 打击         | attack / 攻击 | 1 | Deal 3 dmg (+STR) / 造成 3 伤害 (+力量) | 3→5 |
| `weak_strike`   | Weak Strike / 虚弱打击 | attack / 攻击 | 1 | Deal 3 (+STR) + apply 1 Weak / 3 伤害 (+力量)+施加 1 虚弱 | 3→4 dmg, 1→2 weak |
| `defend`        | Defend / 防御         | skill / 技能  | 1 | Gain 3 block (+CON) / 获得 3 格挡 (+体质) | 3→5 |
| `hot_swap`      | Hot Swap / 热交换     | skill / 技能  | 1 | Draw 2 / 抽 2 牌 | 2→3 draw |
| `brace`         | Brace / 撑住          | skill / 技能  | 0 | 4 block (+CON), retain / 4 格挡 (+体质), 保留 | 4→6 |
| `siphon`        | Siphon / 汲取         | attack / 攻击 | 1 | 4 dmg (+STR) + 4 block (+CON) / 4 伤害 (+力量)+4 格挡 (+体质) | 4→6 both |
| `reinforce`     | Reinforce / 加固      | skill / 技能  | 1 | Gain 7 block (+CON) / 获得 7 格挡 (+体质) | — |

### Uncommon / 罕见 (7)

| ID | Name / 名称 | Type / 类型 | Cost / 费 | Effect / 效果 | + / 升级 |
|---|---|---|---|---|---|
| `charged_shot`  | Charged Shot / 蓄能射击| attack / 攻击 | 1 | Deal 2× STR dmg, exhaust / 造成 2 倍力量伤害, 消耗 | — |
| `cascade`       | Cascade / 连击        | attack / 攻击 | 1 | 2 + 2/attack this turn, retain / 2+ 本回合每张攻击 +2, 保留 | base 2→3 |
| `last_stand`    | Last Stand / 最后防线 | skill / 技能  | 2 | 12 block (+CON) + draw 1 / 12 格挡 (+体质)+抽 1 | 12→17 blk, 1→2 draw |
| `acid_splash`   | Acid Splash / 酸液飞溅| attack / 攻击 | 1 | 4 AoE dmg (+STR) + 2 Poison AoE / 全体 4 伤害 (+力量)+2 中毒 | 4→6 dmg, 2→3 poison |
| `focus`         | Focus / 专注          | ability / 能力 | 1 | +1 INT + draw 1, exhaust / +1 智力+抽 1, 消耗 | +1→+2 INT |
| `chain_link`    | Chain Link / 连锁     | attack / 攻击 | 1 | 6 dmg (+STR) + draw 1 / 6 伤害 (+力量)+抽 1 | 6→9 dmg |
| `deflector`     | Deflector / 偏导护盾  | skill / 技能  | 1 | 5 block (+CON) + 1 Weak / 5 格挡 (+体质)+1 虚弱 | — |

### Rare / 稀有 (7)

| ID | Name / 名称 | Type / 类型 | Cost / 费 | Effect / 效果 | + / 升级 |
|---|---|---|---|---|---|
| `preemptive_strike` | Preemptive Strike / 先发制人 | skill / 技能 | 1 | Next attack doubles dmg / 下次攻击翻倍 | 1→2 stacks |
| `adrenaline`    | Adrenaline / 肾上腺素 | skill / 技能  | 0 | +2 energy + draw 1, exhaust / +2 能量+抽 1, 消耗 | 1→2 draw |
| `double_tap`    | Double Tap / 双发     | attack / 攻击 | 2 | 1 dmg (+STR) ×2 / 1 伤害 (+力量) ×2 | — |
| `stun_baton`    | Stun Baton / 电棍     | attack / 攻击 | 1 | Deal 1 (+STR) + apply 1 Stun / 1 伤害 (+力量)+施加 1 眩晕 | — |
| `bone_breaker` | Bone Breaker / 碎骨者  | attack / 攻击 | 2 | 14 dmg (+STR) + 2 Vulnerable / 14 伤害 (+力量)+2 易伤 | 14→19 dmg, 2→3 vuln |
| `last_breath`  | Last Breath / 最后一搏 | skill / 技能  | 0 | 10 block (+CON) + draw 2, exhaust / 10 格挡 (+体质)+抽 2, 消耗 | 10→14 blk, 2→3 draw |
| `bulwark`      | Bulwark / 壁垒        | skill / 技能  | 2 | 12 block (+CON) + 1 energy / 12 格挡 (+体质)+1 能量 | — |

---

## 💎 Relics / 遗物 (14)

| ID | Name / 名称 | Rarity / 稀有 | Trigger / 触发 | Effect / 效果 |
|---|---|---|---|---|
| `cracked_battery`   | Cracked Battery / 破损电池        | common 普通   | turn 1 start / 首回合 | +1 energy / +1 能量 |
| `lucky_cog`         | Lucky Cog / 幸运齿轮              | common 普通   | combat win / 战斗胜利 | +5 gold / +5 金币 |
| `repair_kit`        | Repair Kit / 修理包               | common 普通   | combat win / 战斗胜利 | Heal 3 HP / 回 3 血 |
| `sharpened_scrap`   | Sharpened Scrap / 磨利废刃        | common 普通   | every attack / 每次攻击 | +1 dmg / +1 伤害 |
| `signal_jammer`     | Signal Jammer / 信号干扰器        | common 普通   | first enemy hit / 首次受击 | −2 dmg / −2 伤害 |
| `steel_plating`     | Steel Plating / 钢板装甲          | common 普通   | turn 1 start / 首回合 | +6 block / +6 格挡 |
| `crit_clip`         | Crit Clip / 暴击弹夹              | common 普通   | every attack / 每次攻击 | Luck-scaled 1.5× crit / 幸运缩放 1.5× 暴击 |
| `rabbits_foot`      | Rabbit's Foot / 兔脚              | common 普通   | combat win / 战斗胜利 | +6 gold / +6 金币 |
| `bulk_actuator`     | Bulk Actuator / 重型驱动器        | uncommon 罕见 | turn 1 start / 首回合 | +10 block / +10 格挡 |
| `scavenger_lens`    | Scavenger's Lens / 拾荒者透镜     | uncommon 罕见 | combat win / 战斗胜利 | +12 gold / +12 金币 |
| `inertial_dampener` | Inertial Dampener / 惯性阻尼器    | uncommon 罕见 | every enemy hit / 每次受击 | −1 dmg / −1 伤害 |
| `bounty_tags`       | Bounty Tags / 赏金标签            | uncommon 罕见 | combat win / 战斗胜利 | +12 gold + heal 3 / +12 金币+回 3 血 |
| `adrenaline_pump`   | Adrenaline Pump / 肾上腺泵        | uncommon 罕见 | turn 1 start / 首回合 | +1 energy / +1 能量 |
| `war_horn`          | War Horn / 战号                   | rare 稀有     | every attack / 每次攻击 | +2 dmg / +2 伤害 |

---

## 🛡️ Equipment / 装备 (21)

### Standalone / 独立单品 (6)

| ID | Name / 名称 | Slot / 部位 | Rarity / 稀有 | Bonuses / 加成 |
|---|---|---|---|---|
| `old_hat`             | Old Wasteland Hat / 旧荒野帽      | head 头部     | common 普通   | +1 charm 魅力 |
| `scrap_breastplate`   | Scrap Breastplate / 废料胸甲      | chest 胸部    | common 普通   | +1 constitution 体质 |
| `rusted_dagger`       | Rusted Dagger / 锈匕首            | weapon 武器   | common 普通   | +1 strength 力量 |
| `lucky_charm`         | Lucky Charm / 幸运护符            | accessory 饰品| uncommon 罕见 | +2 luck 幸运 |
| `wasteland_revolver`  | Wasteland Revolver / 荒野左轮     | weapon 武器   | rare 稀有     | +2 strength 力量, +1 luck 幸运 |
| `old_world_relic`     | Old World Relic / 旧世遗物        | accessory 饰品| rare 稀有     | +2 intelligence 智力, +1 charm 魅力 |

### Set: Tank Engineer / 套装：重装工程师 (5)

**Set bonus / 套装加成:**
- 3-piece / 三件: +1 block at start of every turn / 每回合开始 +1 格挡
- 5-piece / 五件: +2 damage on attack cards / 攻击牌 +2 伤害

| ID | Name / 名称 | Slot / 部位 | Rarity / 稀有 | Bonuses / 加成 |
|---|---|---|---|---|
| `tank_engineer_helm`       | Reinforced Hardhat / 加固安全帽  | head 头部     | common 普通   | +1 constitution 体质 |
| `tank_engineer_vest`       | Plated Vest / 镀板背心            | chest 胸部    | uncommon 罕见 | +2 constitution 体质 |
| `tank_engineer_hammer`     | Pipe Hammer / 管钳锤              | weapon 武器   | common 普通   | +1 strength 力量 |
| `tank_engineer_gauntlets`  | Iron Gauntlets / 铁护手           | hands 手部    | common 普通   | +1 constitution 体质 |
| `tank_engineer_coil`       | Power Coil / 动力线圈             | accessory 饰品| uncommon 罕见 | +1 constitution 体质, +1 intelligence 智力 |

### Set: Weak Hunter / 套装：弱化猎手 (5)

**Set bonus / 套装加成:**
- 3-piece / 三件: +1 block on defense cards / 防御牌 +1 格挡
- 5-piece / 五件: attack cards apply 1 Weak / 攻击牌施加 1 虚弱

| ID | Name / 名称 | Slot / 部位 | Rarity / 稀有 | Bonuses / 加成 |
|---|---|---|---|---|
| `weak_hunter_helm`     | Hunter's Visor / 猎人面镜       | head 头部     | common 普通   | +1 luck 幸运 |
| `weak_hunter_vest`     | Stalker's Vest / 潜行者背心     | chest 胸部    | common 普通   | +1 charm 魅力 |
| `weak_hunter_gun`      | Marked Sidearm / 记号手枪       | weapon 武器   | uncommon 罕见 | +2 strength 力量 |
| `weak_hunter_gloves`   | Weak Hunter Gloves / 弱化猎手手套 | hands 手部  | common 普通   | +1 strength 力量 |
| `weak_hunter_trinket`  | Faded Sigil / 褪色印记          | accessory 饰品| common 普通   | +1 intelligence 智力 |

### Set: Warden / 套装：守望者 (5)

**Set bonus / 套装加成:**
- 3-piece / 三件: +2 block at start of every turn / 每回合开始 +2 格挡
- 5-piece / 五件: attack cards apply 1 Burn / 攻击牌施加 1 燃烧

| ID | Name / 名称 | Slot / 部位 | Rarity / 稀有 | Bonuses / 加成 |
|---|---|---|---|---|
| `warden_helm`     | Warden Helm / 守望者头盔   | head 头部     | common 普通   | +1 constitution 体质 |
| `warden_vest`     | Warden Vest / 守望者背心   | chest 胸部    | common 普通   | +1 constitution 体质 |
| `warden_axe`      | Warden Axe / 守望者战斧    | weapon 武器   | uncommon 罕见 | +2 strength 力量 |
| `warden_gloves`   | Warden Gloves / 守望者手套 | hands 手部    | common 普通   | +1 strength 力量 |
| `warden_pendant`  | Warden Pendant / 守望者吊坠 | accessory 饰品| rare 稀有    | +2 strength 力量, +1 constitution 体质 |

---

## Glossary / 术语对照

| EN | 中文 |
|---|---|
| Strength (STR)     | 力量 |
| Constitution (CON) | 体质 |
| Intelligence (INT) | 智力 |
| Luck (LCK)         | 幸运 |
| Charm (CHA)        | 魅力 |
| Block              | 格挡 |
| Energy             | 能量 |
| Draw               | 抽牌 |
| Exhaust            | 消耗 |
| Retain             | 保留 |
| Poison             | 中毒 |
| Burn               | 燃烧 |
| Weak               | 虚弱 |
| Vulnerable         | 易伤 |
| Shock              | 麻痹 / 电击 |
| Double Damage      | 双倍伤害 |
| Strength Up        | 力量上升 |
| common / uncommon / rare | 普通 / 罕见 / 稀有 |
| attack / skill / ability | 攻击 / 技能 / 能力 |
| head / chest / weapon / hands / accessory | 头部 / 胸部 / 武器 / 手部 / 饰品 |
