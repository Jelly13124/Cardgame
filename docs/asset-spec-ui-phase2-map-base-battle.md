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
| `hud_energy_core` | 圆形能量核底章(中心留数字区)替 `battle_scene/ui/energy_core.png` |
| `hud_end_turn` | 回合结束大按钮(橙,墨线,四态靠 modulate) |
| `hud_hp_frame` | 细长胶囊血条框(填充程序化) |
| `hud_block_badge` | 蓝盾格挡小章(数字区留白)替 block_badge.png |
| `hud_intent_{attack,block,buff,charge,debuff}` | 5 个意图小图标:红剑/蓝盾/绿箭/橙警/紫降,极简(rule §1) |
| `hud_target_arrow` | 拖拽指向箭头头部 |
| `hud_turn_banner` | 回合横幅条(可选,lw_bar 可代) |

### 批次 2 — Sheet 10 地图件
| 件 | 用途 |
|---|---|
| `map_node_{enemy,elite,boss,merchant,rest,treasure,relic,unknown}` | 8 个节点圆章,墨线重绘(现 map/nodes/*.png 为旧风格) |
| `map_marker_here` | 当前位置钉(牛仔帽/靴印) |
| `map_stamp_cleared` | 已清勾章 |
| `map_stamp_blocked` | 不可达淡叉 |
| `map_path_dot` | 路径圆点(虚线程序化排布) |

### 批次 3 — Sheet 11 基地件(对齐已过审基地概念)
| 件 | 用途 |
|---|---|
| `base_btn_depart` | 特大出发钮(概念中带角撑的橙色大板;lw_btn_orange 拉到 500×96 会太素) |
| `base_medallion_blank` | 楼名牌左侧圆形图标章(空底,楼图标代码叠) |
| `base_tier_pip` | tier 菱形 pip,白模板(代码按 tier 染橙/青/紫/绿) |
| `field_dropdown_ink` | 墨线下拉框(难度选择;现 charcoal 版风格不符) |

### 批次 4 — Sheet 12 图标补充(墨线,与 sheet 03 同族)
`icon_skull`(难度)/ `icon_cards`(图鉴导航)/ `icon_hero`(角色导航,牛仔帽头形)/
`icon_deck`(局内牌堆)/ `icon_clock`(悬赏倒计时)/ `icon_flag`(楼层进度)。

### 批次 5 — 插画 ×1
`campfire_scene`:篝火休息节点插画(约 600×400 透明),奖励/篝火页主视觉。

## 退役预告(接线完成后清理)
`battle_scene/ui/{energy_core,energy_panel_frame,hp_bar_*,intent_*,block_badge,button_*}.png`、
`run_system/map/nodes/*.png`(旧章)、`ui/topbar/{character,deck}.png`、`loot_ui/*.png`。

## 验收
透明通道干净;无烘焙文字;sheet 件间不接触;与 07 sheet 同一支笔(细金边+墨线,
无铆钉/厚框/重倒角);落盘后 Claude 切片接线 + smoke。
