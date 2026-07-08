# Asset Spec — 建筑 UI(lightline)缺口素材

**Date:** 2026-07-08 **Owner:** Codex(透明件)/ Gemini 管线(不透明背景,Claude 自产)
**Status:** OPEN — 全部走占位,到货即插即用(命名节点/固定路径,零代码改动)。

## 风格锚点(必读)

- `docs/project-rules.md` §1 — Rick and Morty 风格 Sci-Fi Cartoon Wasteland:
  粗黑描边、大色块、平涂 cel、废土工业。
- **UI 风格参考 = 概念图**:`docs/art/previews/base_building_*_20260707.png`
  (forge×4 / clinic / market / outpost)。新素材必须和这批概念图 + 已切好的
  `run_system/assets/images/ui_kit_lightline/` 组件(橄榄绿金属框 + 橙色主按钮)
  同一世界、同一描边语言。
- 文字区留白,**不要把中文烘进图里**(文案由代码 tr() 渲染)。

## 一、Codex 交付(透明 PNG)

### 1. poster_frame_blank —— 干净的通缉令空框(最高优先)

- **路径**:`run_system/assets/images/ui_kit_lightline/poster_frame_blank.png`
- **尺寸**:约 240×400,透明背景。
- **要求**:羊皮纸通缉令**空框**,可 9-slice(四边角饰只在边缘 ~30px 内,中心为
  可拉伸的平色纸面)。**不要**内嵌相框、**不要**底部按钮板、不要任何烘焙文字——
  现有 `card_poster` 是一张成品海报,被当 stylebox 拉伸后烘焙元素与真实控件重影
  (2026-07-08 已弃用),这张就是它的替代品。
- **接线**(Claude):`outpost_screen.gd` 海报卡 stylebox + manifest margins。

### 2. 悬赏海报插画 ×10(可选,分批可)

- **路径**:`run_system/assets/images/ui/bounty_posters/poster_art_<id>.png`
- **ids**:open_fire, sustained_assault, scavenger_haul, war_profiteer,
  cull_elites, come_back_alive, field_smith, pest_control, elite_purge, head_hunter
- **尺寸**:约 360×280(展示 180×140),透明背景;每张按契约目标出一幅
  通缉令风格小插画(题材见 `run_system/data/bounties/<id>.json` 的 objective)。
- **接线**:前哨站海报卡 `PosterArt_<id>` 命名节点,到货即插。

### 3. 铁匠 NPC 半身像

- **路径**:`run_system/assets/images/ui/forge/npc_blacksmith.png`
- **尺寸**:约 300×392(展示 150×196),透明背景;废土兽人铁匠半身像
  (概念图 forge 左列)。
- **接线**:`forge_window.gd` 的 `ForgeNpcPortrait` 命名节点(现为熔炉占位)。

### 4. 铁砧插画

- **路径**:`run_system/assets/images/ui/forge/anvil_art.png`
- **尺寸**:竖幅 banner 约 300×500,透明背景;锤击铁砧火花主题
  (概念图 forge 左列下半)。
- **接线**:`forge_window.gd` 的 `ForgeAnvilArt` 命名节点。

## 二、Gemini 管线(不透明背景,不归 Codex)

4 张建筑室内背景 —— `run_system/assets/images/buildings/<id>_bg.png`
(forge / clinic / market / outpost),1920×1080 不透明。
`building_screen_base._add_scene_background()` 已按该路径自动加载(缺图时用
accent 暗色兜底)。走 `scripts/gen_art_gemini.py`(见 memory:gemini-art-pipeline)。

## 验收

- 透明通道干净(无白边/杂色 halo);无烘焙中文;与 lightline 组件同源的描边和配色。
- 落盘后跑 `bash scripts/smoke_test.sh`(素材缺失本来就 warn-free,不会崩)。
