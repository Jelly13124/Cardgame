# Asset Spec — 缺失美术总清单(给美术的一站式需求)

**用途:** 这是当前游戏里**所有还没有成品 / 还在用占位 / 烤错了内容**的美术的汇总。
拿这一份就能把缺口一次性补齐。已经交付且 OK 的美术(角色、敌人、卡牌插画、遗物、
状态图标、属性图标、工具图标、宝石图标、建筑、背景)**不在此列**。

**Owner:** 按 ADR-0005 本应由 Codex 出图;本清单也可交给外部美术。回来后由 Claude 接线。
**Status:** Requested（2026-06-29）。

> 工程接线细节(代码侧,美术可忽略)集中在最后一节,并指向各自的详细 spec
> (`asset-spec-ui-icons.md` / `asset-spec-currency-icons.md` / `asset-spec-card-back.md`)。

---

## 0. 全局硬性要求(每一张都适用)

- **PNG 带 alpha、透明背景**,主体居中,留白均匀。
- **禁止烤入任何文字 / 数字 / 字母 / UI 框 / logo。**(尤其货币图标——当前 bug 就是烤了数字。)
- 风格 = 锁定的 **Offbeat Adult Sci-Fi Cartoon Wasteland**:厚的深色卡通描边、大色块、
  内部线条稀疏、2–3 阶 cel 上色、低纹理噪点、亮色高光(toxic green / cyan / 暖橙)克制使用。
- 尺寸是**输出契约**,不是像素画——按给定像素尺寸交清晰矢量感卡通图即可。
- 直接对齐游戏内范例:牛仔 Bill
  (`battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`)、
  战斗背景(`battle_scene/assets/images/backgrounds/wasteland_battlefield.png`)、
  现有遗物图(`run_system/assets/images/relics/*.png`)、属性图标(`battle_scene/assets/images/ui/attributes/*.png`)。

### 强制风格锚点(英文 prompt 前缀,每张都用)

```text
original Offbeat Adult Sci-Fi Cartoon Wasteland game art,
flat 2D adult sci-fi TV-animation look, thick clean dark cartoon outlines, large simple shape blocks, sparse interior lines, broad two-to-three value cel shading,
weird sci-fi western wasteland, dusty leather, patched cloth, brass/scrap accents,
bright toxic green, cyan, and warm orange glow accents used sparingly,
clean game-ready edges, readable silhouettes, low texture noise,
no text, no labels, no UI frame, no logo, transparent background
```

> 用法:**最终 prompt = 上面这段锚点 + 下面每一项的 `subject:` 一行。**

---

## 1. 诅咒卡牌插画 ×5 —— **512×320**,放 `battle_scene/assets/images/cards/player/{id}.png`

当前 5 张诅咒卡全部共用 `curse_placeholder.png` 占位,需要换成各自的插画。
和普通卡同一画风、同一尺寸(512×320,中心主体、四周留白给卡框),**但调性更暗、不祥、病态**——
统一压一层**暗紫(curse)氛围**,让它和明亮的普通卡同框时一眼能认出是"坏牌 / 负面牌"。
无文字。

| id | 中文名 | 牌面效果(画面动机) |
|---|---|---|
| `radiation_dust` | 辐射尘 | 无法打出的纯死牌,只占手牌 |
| `leaking_wealth` | 漏财 | 回合结束若在手 → 失去 5 金币 |
| `rust` | 铁锈 | 回合结束若在手 → 失去 2 生命 |
| `cowardice` | 怯懦 | 回合结束若在手 → 获得 1 层虚弱 |
| `panic` | 恐慌 | 回合结束若在手 → 获得 1 层脆弱 |

**画面 + subject 行(接锚点后):**

- **辐射尘 `radiation_dust.png`** — 一团悬浮的放射性绿色尘埃云,中间一个破裂、渗漏的辐射警告罐,
  toxic green 微光,背景压暗紫不祥氛围。
  `subject: a hovering cloud of radioactive green dust around a cracked leaking radiation canister, toxic green glow, ominous dark-violet curse haze`

- **漏财 `leaking_wealth.png`** — 一个破了洞的皮质钱袋,暗淡无光的瓶盖(caps)从破洞漏出、往下掉,
  暗紫调,钱财流失的失落感。
  `subject: a torn leather coin pouch leaking dull lifeless bottle-caps that spill and fall away, dark-violet curse mood, sense of loss`

- **铁锈 `rust.png`** — 一块被红锈啃噬、锈斑蔓延的金属板或齿轮,锈孔往外渗,暗橙锈色 + 暗紫氛围。
  `subject: a corroded metal plate and gear being eaten by spreading red rust, weeping rust holes, dark-orange corrosion under a dark-violet ominous haze`

- **怯懦 `cowardice.png`** — 一个蜷缩发抖、缩在角落抱头的拾荒者剪影,冷色、无力、退缩感,暗紫。
  `subject: a hunched trembling scavenger silhouette curled up clutching its head, cold powerless cowering feeling, dark-violet curse mood`

- **恐慌 `panic.png`** — 一张惊恐扭曲的脸 / 慌乱瞪大的眼睛,周围是绷断的神经线条,暗紫 + 病态绿。
  `subject: a panicked distorted face with wide terrified eyes and frayed snapping nerve lines, dark-violet with sickly green, curse mood`

---

## 2. 装备槽位图标 ×5 —— **64×64**,放 `battle_scene/assets/images/ui/slots/{slot}.png`

(和现有 `ui/attributes/*.png` 属性图标同尺寸、同处理。)当前这 5 个空槽位在角色面板、仓库、
铁匠铺里显示成**彩色字母框**(`H/C/W/Hd/Ac`),像程序占位。
这是**类别标记**——保持最简可读剪影:**一个清晰形状 + 一个主色**(下面的槽位色)+ 厚描边,
小尺寸(约 44–74px)必须看得清。无场景、无多余道具、无文字。

| 文件 | 槽位 | subject(接锚点后) | 主色 |
|---|---|---|---|
| `slots/head.png` | 头部 | `a riveted salvage helmet / visor cap, single clear silhouette` | 锈红 |
| `slots/chest.png` | 胸甲 | `a patched armored plate vest, single clear silhouette` | 钢蓝 |
| `slots/weapon.png` | 武器 | `a salvaged revolver sidearm, single clear silhouette` | 黄铜 |
| `slots/hands.png` | 手部 | `a worn work glove / gauntlet, single clear silhouette` | 橄榄绿 |
| `slots/accessory.png` | 饰品 | `a charm pendant with a small skull-badge motif, single clear silhouette` | 褪色紫 |

---

## 3. Tool Belt 遗物图标 ×1 —— **128×128**,放 `run_system/assets/images/relics/tool_belt.png`

(和其它遗物图标一致,参考 `run_system/assets/images/relics/war_horn.png` 的尺寸/处理。)
新遗物"工具腰带"目前缺图,遗物架退化成文字徽章。

- **画面**:一条磨旧的皮质工具腰带 / 弹药带,插着几样拾荒工具(扳手 + 罐子),黄铜带扣。
  读作"能多带工具"。比槽位图标多一点材质细节(遗物渲染约 48px),仍是扁平卡通、低噪点、一处暖色高光。
- `subject: a worn leather tool belt / bandolier with a wrench and a canister tucked in, brass buckle, one warm accent glow`

---

## 4. 货币图标 ×3 —— **128×128**,**覆盖**重做 `run_system/assets/images/home/currency/{id}.png`

**当前是坏的**:出厂图把占位数字烤进了画里(`caps.png` 右上角一个"1",`scrap.png` 横着一串"232"),
和界面上真实数值叠在一起,看着像数字重复/乱码。基地货币条现在只能显示纯数字、不敢加载这三张图。
**重做要点:绝对不能有任何数字/文字**,纯图标。

| 文件 | 货币 | subject(接锚点后) | 主色 |
|---|---|---|---|
| `currency/core.png` | 核心(meta) | `a glowing cyan power-core energy crystal shard` | cyan 青光 |
| `currency/caps.png` | 瓶盖 | `a single dented bottle-cap, the wasteland money` | 暖红 / 橙 |
| `currency/scrap.png` | 废料 | `a small cluster of bolts, gears and scrap-metal nuggets` | 暖灰绿金属 |

---

## 5. 卡背 ×1 —— **160×220**,**覆盖**重做 `battle_scene/assets/images/cards/ui/card_back.png`

**当前是坏的**:卡背带一块**不透明黑底**,在抽牌堆 / 弃牌堆背后显示成一块丑陋的黑方框。
需要**透明圆角**(四角透明、跟随卡片圆角),中间是废土风的卡背纹样(齿轮 / 拾荒徽记 / Bill 的标志意象),
克制用一两处暖色或 cyan 高光。无文字。

- `subject: a wasteland card-back pattern, gear / scavenger emblem motif centered, rounded corners with fully transparent corners (no opaque background), one restrained warm or cyan accent`

---

## 交付方式(和其它美术同一纪律)

- **每一类先交 1 张样图过审**,放到 `docs/art/previews/missing_art_<date>/`,我看过 OK 再批量,别一口气盲铺整套。
  - 建议首批样图:`cards/player/rust.png`(诅咒卡代表)+ `slots/weapon.png`(槽位代表)。
- 命名 / 路径 / 尺寸严格按上表——文件名就是 `id`,放对目录即可被游戏自动认到。

## 工程接线(代码侧 — Claude / Codex,美术忽略)

- **诅咒卡**:把 5 张诅咒卡 JSON 的 `front_image` 从 `player/curse_placeholder.png` 改成各自的 `player/{id}.png`。
- **槽位图标**:`run_system/ui/equipment_icon.gd` `set_empty()`(及已装备路径)改为加载
  `res://battle_scene/assets/images/ui/slots/<slot>.png`,字母保留作缺图回退。详见 `asset-spec-ui-icons.md`。
- **Tool Belt**:无需改代码,`tool_belt.json` 已指向该路径,落图即生效。
- **货币图标**:在 `home_base_scene.gd` `_make_currency_chip()` 重新挂回 54×54 的 `TextureRect`
  (加载 `home/currency/{id}.png`),数字纯文本回退保留。详见 `asset-spec-currency-icons.md`。
- **卡背**:直接覆盖同名文件即可,场景已引用。详见 `asset-spec-card-back.md`。
