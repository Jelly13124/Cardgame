# Codex 生成提示词 — UI 二期(地图 / 基地 / 战斗)

契约:`docs/asset-spec-ui-phase2-map-base-battle.md`。
**每次生成都要附参考图**:
- `deprecated_heavy_20260708/core_gold_rim_attempt/ui_components_07_core_lightweight_transparent.png`(**现役 UI 语言,最高优先参考**)
- `docs/art/previews/home_base_ui_simple_comic_concept_20260708.png`(基地概念,已过审)
- `run_system/assets/images/ui_kit_imagegen_v2_lightline/transparent_sheets/ui_components_03_icons_transparent.png`(图标同族)

## 全局风格前缀(每条开头带上)

> Rick and Morty-style sci-fi cartoon wasteland game UI art. Flat dark charcoal
> fills with ONE thin warm-brass hairline outline per shape (the sheet-07
> language) — lightweight, clean, no rivets, no corner plates, no heavy bevels,
> no rendered metal. Thick black outlines only on illustrations/icons, flat cel
> shading. Fully transparent background, clean alpha. NO text, NO letters, NO
> numbers, NO watermark.

---

**注(owner 2026-07-08):不出概念图 — 下面的组件 sheet 直接生成,风格锚死参考图;
观感在实装截图上迭代。**

## 批次 1 — Sheet 09:战斗 HUD 组件

**输出**:`ui_components_09_battle_hud_transparent.png`,~1254×1254,透明,网格摆放不重叠。

```
[全局风格前缀]

A component sheet of separate battle-HUD pieces on a grid, generous
transparent spacing:

1. ENERGY CORE medallion (about 220x220): round charcoal plate, thin brass
   ring, a subtle inner glow ring of warm orange, big EMPTY center zone.
2. END TURN button (about 300x110): large orange rounded-rect with thin brass
   outline, EMPTY label zone.
3. HP BAR FRAME (about 420x64): slim capsule frame, charcoal with thin brass
   outline, hollow interior for a code-drawn fill.
4. BLOCK BADGE (about 120x120): small blue shield chip, thin outline, empty
   number zone.
5. FIVE INTENT ICONS (about 110x110 each): red sword (attack), blue shield
   (block), green up-arrow (buff), orange spark/warning (charge), purple
   down-arrow (debuff) — extremely simple, readable at 32px, flat fills +
   black outline.
6. TARGET ARROW HEAD (about 140x140): chunky comic arrowhead, warm orange
   with black outline, pointing up-right.
7. TURN BANNER strip (about 520x90): slim dark strip with thin brass edge,
   empty center.
```

## 批次 2 — Sheet 10:地图组件

**输出**:`ui_components_10_map_kit_transparent.png`,~1254×1254。

```
[全局风格前缀]

A component sheet of MAP pieces on a grid, generous transparent spacing:

1. EIGHT round MAP NODE BADGES (about 150x150 each), all sharing one badge
   base: charcoal disc + thin brass ring + flat icon with black outline:
   - bandit skull (enemy fight)
   - horned skull with crossed blades (elite)
   - large crowned skull (boss)
   - goblin merchant tent front
   - campfire with flame
   - banded treasure crate
   - glowing relic star
   - bold question mark (unknown)
2. CURRENT-POSITION MARKER (about 130x150): small cowboy hat pin with a
   ground shadow tick.
3. CLEARED STAMP (about 110x110): hand-stamped check mark, warm green ink.
4. BLOCKED STAMP (about 110x110): faint grey X stamp.
5. PATH DOT (about 44x44): single round trail dot, warm tan, black outline.
```

## 批次 3 — Sheet 11:基地组件

**输出**:`ui_components_11_base_kit_transparent.png`,~1254×900。

```
[全局风格前缀]

A component sheet of HOME-BASE pieces on a grid, matching the home-base
concept reference:

1. GIANT DEPART BUTTON (about 760x150): extra-large warm-orange plate with
   thin dark outline and slightly angled corner cuts (like the concept's 出发
   button), EMPTY label zone.
2. NAMEPLATE MEDALLION (about 150x150): round charcoal disc with thin brass
   ring, EMPTY center (building icons overlay in code).
3. TIER PIP (about 60x60): a small faceted diamond/gem shape in plain light
   grey (the game tints it), thin black outline.
4. DROPDOWN FIELD (about 300x84): slim charcoal recessed field with thin
   brass outline and a small down-chevron zone at the right end.
```

## 批次 4 — Sheet 12:图标补充(与 sheet 03 同族)

**输出**:`ui_components_12_icons_b_transparent.png`,~1254×700。

```
[全局风格前缀]

A sheet of SIX small game icons on a grid (about 130x130 each), flat fills +
thick black outlines, same family as the reference icon sheet:

1. SKULL — simple cartoon skull, front view (difficulty marker).
2. CARDS — three fanned playing cards with a star on the front card
   (collection / codex).
3. HERO — cowboy hat over a simple robot head silhouette (character nav).
4. DECK — a tidy stack of cards, top card showing a back pattern.
5. CLOCK — round alarm clock, simple hands (daily refresh countdown).
6. FLAG — small tattered banner on a pole (floor progress).
```

## 批次 5 — 篝火插画

**输出**:`campfire_scene.png`,约 600×400,透明 →
`run_system/assets/images/ui/rest/campfire_scene.png`。

```
[全局风格前缀]

ONE illustration, about 600x400: a cozy wasteland CAMPFIRE at night — ring of
scrap-metal stones, warm orange flames with simple comic flame shapes, a
bedroll and a battered kettle beside it, sparks drifting up. Flat cel shading,
thick black outlines, transparent background. No characters, no text.
```

## 验收(每批)
- 概念图:布局/组件形状与 07 语言一致即可过审,文字区留白;
- sheet:件间不接触不重叠;透明通道干净;无任何文字数字;
- 落盘后 Claude 切片(`hud_*`/`map_*`/`base_*`/`icon_*` 命名)+ manifest + 接线 + smoke。
