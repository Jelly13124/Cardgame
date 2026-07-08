# Codex 美术生成提示词 — UI 缺口批次(2026-07-08)

配套契约:`docs/asset-spec-building-ui-lightline-gaps.md`(交付路径/接线以契约为准)。
**参考图必须一起喂给 Codex**:
- `docs/art/previews/character_page_ui_simple_comic_concept_20260708.png`(角色窗概念,炭黑框)
- `docs/art/previews/stash_page_ui_simple_comic_concept_20260708.png`(仓库窗概念,炭黑框)
- `docs/art/previews/base_building_forge_ui_dismantle_simple_comic_20260707.png`(lightline 楼页概念)
- `run_system/assets/images/ui_kit_imagegen_v2_lightline/transparent_sheets/`(已有 4 张组件 sheet,配色/描边同源)

## 全局风格前缀(每条提示词开头都带上)

> Rick and Morty-style sci-fi cartoon wasteland game UI art. Thick black outlines,
> big flat color blocks, flat cel shading, post-apocalyptic industrial hardware.
> Same visual language as the reference images: dark charcoal gunmetal panels with
> riveted corner screws, olive-green metal accents, warm orange primary highlights.
> Fully transparent background (clean alpha, no halo, no drop shadow onto empty
> space). NO text, NO letters, NO numbers, NO watermark anywhere in the image.

---

## 批次 1 — Sheet 05:炭黑窗框组件 sheet

**输出**:`ui_components_05_charcoal_window_transparent.png`,约 1280×1280,透明背景。
**用途**:角色窗/仓库窗(可拖窗家族)按新概念图换装;切片后落
`run_system/assets/images/ui_kit_lightline/`。

```
[全局风格前缀]

A component sheet of separate game-UI pieces laid out on a grid with generous
transparent spacing between pieces — pieces must NOT touch or overlap.

Include exactly these components:

1. One large rectangular WINDOW FRAME (about 700x520): dark charcoal gunmetal
   metal frame with a beveled outer edge, one round rivet screw in each corner,
   and a thin warm-grey hairline inset just inside the frame. The center is a
   flat very-dark charcoal fill. All corner decoration stays within the outer
   48 pixels of the frame so it can be nine-sliced.

2. One wide recessed TITLE PLATE (about 560x96): a dark inset slot with
   chamfered corners and small angular side notches, subtle inner top shadow,
   completely empty center.

3. One SORT DROPDOWN FIELD (about 260x76): a dark recessed rectangular field
   with a thin border and a small downward chevron arrow at the right end.

4. One CORNER RARITY RIBBON template (about 72x72): a small folded triangular
   ribbon that hugs the top-left corner of a square slot, drawn in plain
   light grey / white so the game can tint it any color.

5. One PENCIL edit icon (about 96x96): stubby cartoon pencil, side view.

6. One SUPPLY CRATE icon (about 128x128): battered metal-banded wooden crate,
   front three-quarter view.

7. One small CHEVRON-DOWN arrow icon (about 80x80), matching the existing
   chevron style.

8. One round CORNER MEDALLION ornament (about 120x120): a riveted gear /
   compass rose medallion, dark metal with olive accent.

9. Six EMPTY-SLOT GHOST ICONS (about 110x110 each), drawn as dim desaturated
   grey line-art silhouettes for empty equipment slots: a cowboy hat, an
   armored chest plate, a mechanical glove, a revolver, an amulet on a chain,
   a wrench.
```

**切片命名(Claude 接线用)**:`panel_window_charcoal` / `panel_titleplate` /
`field_dropdown` / `ribbon_rarity_corner` / `icon_pencil` / `icon_crate` /
`icon_arrow_down` / `ornament_medallion` / `ghost_{head,chest,hands,weapon,accessory,tool}`。

---

## 批次 2 — Sheet 06:装备壳图标 15 张(slot × rarity)

**输出**:`ui_components_06_equipment_shells_transparent.png`,约 1280×900,透明背景。
**用途**:替换 `battle_scene/assets/images/ui/equipment/<slot>_<rarity>.png` 的
15 张通用壳图标(概念图里的物品观感主要靠这批)。

```
[全局风格前缀]

A sheet of 15 game item icons arranged in a STRICT 5-column x 3-row grid with
generous transparent spacing. Each icon about 150x150, chunky readable
silhouettes, centered in its cell.

Columns left to right (item family): 1 WEAPON, 2 HEAD, 3 CHEST, 4 HANDS,
5 ACCESSORY.
Rows top to bottom (quality tier): row 1 CRUDE, row 2 MILITARY, row 3 ORNATE.

- Row 1 CRUDE: rusty, taped-together scrap versions — a rusty snub revolver, a
  battered leather cowboy hat, a scrap-metal chest vest, a worn work glove, a
  simple cord necklace with a bottle-cap pendant.
- Row 2 MILITARY: solid olive-drab military-grade versions — a serviced
  revolver with drum, a reinforced combat helmet with goggles, an armored
  plate carrier, an articulated tactical gauntlet, a brass compass amulet.
- Row 3 ORNATE: gilded high-tech versions with a faint warm glow — an ornate
  long-barrel plasma revolver with gold inlay, a crested commander helmet, a
  gilded power-armor chest piece, a glowing servo power-fist, a jeweled amulet
  with a glowing core.

Same thick-outline flat cel style for all 15; consistent light from top-left.
```

**落盘映射**:第 1 行→`*_common`,第 2 行→`*_uncommon`,第 3 行→`*_rare`;
列→`weapon/head/chest/hands/accessory`。

---

## 批次 3 — 通缉令空框(最高优先,修 bug 用)

**输出**:`poster_frame_blank.png`,约 480×800,透明背景。
**用途**:前哨站悬赏海报卡底框(现 card_poster 是成品海报不能 9-slice,已弃用)。

```
[全局风格前缀]

ONE blank wanted-poster frame, portrait orientation, about 480x800.
Weathered parchment sheet pinned to a dark metal backing board: slightly torn
parchment edges, one rivet or nail in each corner, a thin dark border line
following the edge. The ENTIRE center is flat empty parchment — NO inner
picture frame, NO button plate, NO artwork, NO text. All decoration stays
within the outer 60 pixels so the frame can be nine-sliced.
```

---

## 批次 4 — 悬赏海报插画 ×10(sheet)

**输出**:`bounty_poster_art_sheet.png`,5×2 网格,单幅约 360×280,透明背景;
切片后落 `run_system/assets/images/ui/bounty_posters/poster_art_<id>.png`。

```
[全局风格前缀]

A sheet of 10 small wanted-poster illustrations in a STRICT 5-column x 2-row
grid, each about 360x280, generous transparent spacing, sepia-and-ink look
(parchment-friendly muted palette with one warm accent), thick outlines.

Row 1, left to right:
1. OPEN FIRE — a fanned revolver blazing with muzzle flashes.
2. SUSTAINED ASSAULT — twin gatling barrels spun up, shell casings flying.
3. SCAVENGER HAUL — a burlap sack overflowing with bottle caps.
4. WAR PROFITEER — an opened briefcase stacked with bottle caps and gold.
5. CULL ELITES — one big horned mutant skull in a crosshair.

Row 2, left to right:
6. ELITE PURGE — three mutant skulls in a row, each struck through.
7. COME BACK ALIVE — a lone silhouette walking out of a bunker hatch into
   light.
8. FIELD SMITH — a hammer striking a playing card on an anvil, sparks.
9. PEST CONTROL — a swarm of small scrap-critters under a big X.
10. HEAD HUNTER — a crowned boss skull on a target board with a knife stuck
    in it.
```

**id 顺序**:open_fire, sustained_assault, scavenger_haul, war_profiteer,
cull_elites / elite_purge, come_back_alive, field_smith, pest_control, head_hunter。

---

## 批次 5 — 铁匠 NPC 半身像

**输出**:`npc_blacksmith.png`,约 600×784,透明背景 →
`run_system/assets/images/ui/forge/npc_blacksmith.png`。

```
[全局风格前缀]

ONE bust portrait of a wasteland ORC BLACKSMITH, waist-up, about 600x784.
Green-skinned, heavy build, leather apron over a scarred chest, welding
goggles pushed up on the forehead, one mechanical prosthetic arm holding a
smith hammer over the shoulder, warm forge glow rim light from below-left.
Friendly-gruff expression. Character fills the frame, feet not visible.
```

---

## 批次 6 — 铁砧插画(竖幅 banner)

**输出**:`anvil_art.png`,约 600×1000,透明背景 →
`run_system/assets/images/ui/forge/anvil_art.png`。

```
[全局风格前缀]

ONE tall banner illustration, about 600x1000: a heavy blacksmith ANVIL on a
scrap-metal base, a smith hammer frozen mid-strike above it, a burst of warm
orange sparks at the impact point, faint heat glow. Composition reads
bottom-heavy (anvil) with the spark burst in the upper third. No character.
```

---

## 不在本批(走 Gemini 管线,Claude 自产)

4 张建筑室内背景 `run_system/assets/images/buildings/<id>_bg.png`(1920×1080 不透明)。

## 验收(每批)

- 透明通道干净、无白边 halo;无任何烘焙文字/数字/水印。
- sheet 类:件与件不接触不重叠(切片器按连通域切)。
- 9-slice 件(窗框/标题板/海报框):角饰只在边缘区,中心平色。
- 落盘后 Claude 切片/接线并跑 `bash scripts/smoke_test.sh`。
