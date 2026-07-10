# 装备系列、工具拖拽、商店与顶部栏设计

## 目标

把 15 件通用装备改成三个统一系列，修复通用装备拖拽时退化成文字的问题；让角色窗口的扳手工具槽支持双向拖拽并使用正确的填充视觉；修复进入商店时的工具商品异常；将顶部栏旧卡背按钮换成现有的新卡组图标。

## 通用装备系列

稳定 ID、稀有度、词条数量、掉落权重与数值全部不变，只修改英文 JSON 名称和中英文翻译。

| 稀有度 | ID | 中文名 | 英文名 |
|---|---|---|---|
| common | `gear_head_common` | 拾荒者牛仔帽 | Scavenger Cowboy Hat |
| common | `gear_chest_common` | 拾荒者皮背心 | Scavenger Leather Vest |
| common | `gear_weapon_common` | 拾荒者左轮 | Scavenger Revolver |
| common | `gear_hands_common` | 拾荒者护手 | Scavenger Gauntlet |
| common | `gear_accessory_common` | 拾荒者牙链 | Scavenger Fang Necklace |
| uncommon | `gear_head_uncommon` | 游骑兵侦察帽 | Ranger Scout Hat |
| uncommon | `gear_chest_uncommon` | 游骑兵战术背心 | Ranger Tactical Vest |
| uncommon | `gear_weapon_uncommon` | 游骑兵左轮 | Ranger Revolver |
| uncommon | `gear_hands_uncommon` | 游骑兵护手 | Ranger Gauntlet |
| uncommon | `gear_accessory_uncommon` | 游骑兵铭牌 | Ranger Dog Tags |
| rare | `gear_head_rare` | 军官战帽 | Officer's Battle Cap |
| rare | `gear_chest_rare` | 军官重甲 | Officer's Heavy Armor |
| rare | `gear_weapon_rare` | 军官蓄能左轮 | Officer's Charged Revolver |
| rare | `gear_hands_rare` | 军官动力护手 | Officer's Power Gauntlet |
| rare | `gear_accessory_rare` | 军官核心勋章 | Officer's Core Medal |

这些名称表示视觉系列，不增加 `set_id`，也不产生套装效果；真正的套装装备继续使用现有绿色 set 稀有度与套装规则。

## 现有装备图

继续使用 `battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png` 的 15 张现有图片，不重新设计主体。清除图片边缘串入的相邻素材残片；不改变各文件现有画布尺寸、主体方向、颜色或装备造型。最终仍为透明 PNG，孤立残片不得接触画布边缘。

## 装备拖拽预览

通用装备 JSON 的 `sprite` 为空。正常格子已经回退到部位×稀有度通用图，但 Character、Stash、Forge 的拖拽预览只加载显式 `sprite`，因此显示分叉。

在 `equipment_icon.gd` 提供统一静态接口：

```gdscript
static func resolve_equipment_texture(
	sprite_path: String, slot: String, rarity: String
) -> Texture2D
```

解析顺序：

1. JSON 显式 `sprite`；
2. `battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png`；
3. `null`，由现有部位字母兜底。

正常装备图与 Character、Stash、Forge 的 `preview_tex` 全部调用该接口。

## 角色窗口工具槽

当前背包工具拥有拖拽 payload，但空工具槽是普通 `Control`，已装备工具是普通 `Button`，两者均不参与原生拖放。

改为使用与背包/装备槽相同的 `BackpackCell` 交互包装：

- 空槽显示现有 `ghost_tool.png` 的简洁扳手轮廓，不叠加第二层橙色大框；
- 空槽只接收 `kind == "tool"` 的背包拖拽，成功后调用 `equip_tool_from_backpack()`；
- 填充槽隐藏 ghost，只显示真实工具图标和统一的 2px 青蓝强调边；
- 填充槽产生 `src == "tool_slot"` 拖拽数据；
- 拖到指定的已解锁背包格时，工具落入该格；目标格被占用或超出容量时拒绝；
- 点击背包工具装备、点击已装备工具卸下继续作为备用操作；
- battle 只读模式继续禁用拖拽和卸下。

为精确落入目标背包格，`RunManager` 新增：

```gdscript
func unequip_tool_to_backpack(tool_index: int, backpack_index: int) -> bool
```

现有 `unequip_tool()` 保持“放入第一个空格”的点击语义。

顶部栏工具格维持已确认的单格展示，不改变数量逻辑。

## 商店闪退

工具没有稀有度层级；`_make_tool_stock_entry()` 只返回 `tool_id` 与 `price`，但 `_build_tool_stall()` 强制读取 `entry["rarity"]`，导致工具卡片构建中断并向网格加入空节点。

工具商品改用固定的 `TOOL_ACCENT` 青蓝色显示名称/描述/图标兜底，不向工具数据伪造稀有度。商店直接实例化和地图跳转进入必须都能正常构建三个工具商品。

## 顶部栏卡组图标

运行牌组按钮不再加载 `run_system/assets/images/ui/topbar/deck.png`，改用现有 `run_system/assets/images/ui_kit_lightline/iconb_deck_stack.png`。按钮保持 48×48、无背景框、原 tooltip 与点击行为不变。

## 数据与图鉴

- 修改 15 个 `run_system/data/equipment/gear_{slot}_{rarity}.json` 的英文 `name`；
- 修改 `assets/translations/content_equipment.csv` 的对应中英文名称；
- 运行 `python scripts/gen_catalog_html.py`，不手改生成 HTML。

## 验证

1. 15 件通用装备名称与系列表完全一致；
2. `sprite == ""` 的通用装备仍能解析真实拖拽贴图；
3. Character、Stash、Forge 均使用统一贴图解析接口；
4. 背包工具可拖入空工具槽，已装备工具可拖回指定空背包格；
5. 工具槽填充状态只显示真实工具图，不显示 ghost；
6. 商店场景连续实例化多次无脚本错误，稳定生成三个工具商品；
7. 顶部栏牌组按钮使用 `iconb_deck_stack.png`；
8. 装备图鉴、角色窗口回归、HUD 回归与全项目 smoke 通过；
9. 渲染角色窗口和顶部栏截图人工复核。

## 非目标

- 不新增套装效果；
- 不修改装备数值、工具效果与商店价格；
- 不改变顶部栏工具格数量；
- 不重新生成 15 张装备主体美术。
