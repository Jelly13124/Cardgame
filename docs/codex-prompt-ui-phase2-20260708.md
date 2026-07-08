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

## ~~批次 1 — 战斗 HUD 组件~~(**取消**,owner 目检定案 2026-07-08)
意图图标/能量核/血条/格挡章**全部保留**(平涂+描边,风格合格);旧棕底
`energy_panel_frame`/`button_*` 由现有 lw 件在接线时替代——战斗重做零新美术。

## ~~批次 2 — 地图组件~~(取消:现有 map/nodes 节点章保留,地图无新美术需求)

## 批次 3 — Sheet 11:基地小件 ×2

**输出**:`ui_components_11_base_kit_transparent.png`,~900×500。

```
[全局风格前缀]

A component sheet of TWO home-base pieces on a grid, matching the home-base
concept reference, generous transparent spacing:

1. NAMEPLATE MEDALLION (about 150x150): round charcoal disc with thin brass
   ring, EMPTY center (building icons overlay in code).
2. TIER PIP (about 60x60): a small faceted diamond/gem shape in plain light
   grey (the game tints it), thin black outline.
```

## ~~批次 4 — 图标补充~~(**取消**,owner 目检定案:现有图标够用)

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
