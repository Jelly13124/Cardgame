# Asset Spec — UI 二期:地图 / 主基地 / 局内战斗 全量重做(lw 墨线金边语言)

**Date:** 2026-07-08 **Owner:** Codex **Status:** OPEN
**语言锚点:** sheet 07(`deprecated_heavy_20260708/core_gold_rim_attempt/ui_components_07_core_lightweight_transparent.png`,
owner 定案的现役 UI 语言:炭黑平色 + 细金边墨线,轻量、无铆钉无厚框)+
`docs/art/previews/home_base_ui_simple_comic_concept_20260708.png`(基地概念,已过审)。
配套提示词:`docs/codex-prompt-ui-phase2-20260708.md`。

## 流程(owner 2026-07-08:**不出概念图**,组件 sheet 直出)

1. Codex 按下方清单直接出**组件 sheet**(透明、不重叠、可切片),风格锚死
   sheet 07 + 已有的基地概念图;
2. Claude 切片(`hud_*`/`map_*`/`base_*`/`icon_*`)→ manifest → 场景接线 → smoke;
3. 观感问题在实装截图上迭代,不走概念图轮。

## 现有可复用(不用重新生成)

- lw 12 件核心(panel/bar/panel_sm/panel_wide/pill/btn_orange/btn_olive/btn_close/
  slot_brackets/bubble/divider/panel_tall)——所有面板、按钮、✕、tooltip 气泡直接用;
- icons sheet 03 全套(caps/scrap/五维/refresh/swap/lock/backpack/crate/poster/anvil/...);
- 装备壳 ×15、状态图标全套、事件立绘 ×9、悬赏海报 ×10、铁匠/铁砧插画;
- 细线槽位/井(程序化)。

## 缺口清单(= Codex 生成任务)

### 批次 1 — Sheet 09 战斗 HUD 件
| 件 | 用途 / 落点 |
|---|---|

> **2026-07-08 逐件目检后大幅缩减(owner 纠正:先看图再判,不按批次年龄推定)。**
> 战斗组逐件裁决:
> - `intent_attack/block/buff/charge` ✅ **保留**——平涂+描边,正是 rule §1 要的极简意图;
> - `energy_core` ✅ 保留(圆章平涂,契合);`hp_bar_frame/fill` ✅ 保留;`block_badge` ✅ 保留;
> - `energy_panel_frame`、`button_normal/hover/pressed`(旧棕底角钉钮)❌ 风格不符,
>   但**不需要新美术**——战斗重做时直接换现有 lw 件,PNG 届时退役;
> - 回合结束钮/回合横幅/瞄准箭头:lw_btn_orange / lw_bar / 程序化即可,**无 Codex 需求**;
> - `topbar/{character,deck}.png`、`loot_ui/*`(卡背扇/金币堆)✅ 保留——物件插画,风格合格。
>
> **→ Sheet 09 取消。** 战斗界面重做 = 纯接线(chrome 换 lw 件),零新美术。

### ~~批次 2 — 地图件~~(**取消**,owner 2026-07-08)
现有 `map/nodes/*.png` 8 个节点章**质量合格、风格契合,保留不重绘**;
当前位置/已清/不可达/路径均为程序化表现,不需要新美术。地图界面重做只动
chrome(顶栏/面板走现有 lw 件)。

### 批次 3 — 基地小件 ×2(对齐已过审基地概念;唯一真缺的组件)
| 件 | 用途 |
|---|---|
| `base_medallion_blank` | 楼名牌左侧圆形图标章(空底,楼图标代码叠) |
| `base_tier_pip` | tier 菱形 pip,白模板(代码按 tier 染橙/青/紫/绿) |

(出发钮:现役 depart_plaque 为 Codex 近期成品,保留;难度下拉:sheet 05 的
`field_dropdown` 同为炭黑+细金边,可复用——均不重出。)

### ~~批次 4 — 图标补充~~(**取消**)
逐项复核:图鉴/角色导航已有图标;难度骷髅可复用 `map/nodes/enemy.png`;
牌堆用现有 `topbar/deck.png`;倒计时/楼层为文字显示,无图标必要。

### 批次 5 — 插画 ×1
`campfire_scene`:篝火休息节点插画(约 600×400 透明),奖励/篝火页主视觉。

## 退役预告(接线完成后清理,已缩小)
仅 `battle_scene/ui/{energy_panel_frame,button_normal,button_hover,button_pressed}.png`
(旧棕底 chrome,被 lw 件替代后删)。其余原列项目**全部保留**(owner 目检定案)。

## 验收
透明通道干净;无烘焙文字;sheet 件间不接触;与 07 sheet 同一支笔(细金边+墨线,
无铆钉/厚框/重倒角);落盘后 Claude 切片接线 + smoke。
