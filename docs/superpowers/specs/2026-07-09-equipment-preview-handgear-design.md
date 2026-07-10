# 装备拖拽预览与通用手套重制设计

## 目标

修复通用装备在拖拽时只显示文字/部位字母的问题，清除手套装备看起来像两张图重叠的源图污染，并将三档通用手部装备改成玩家确认的名称与对应美术层级。

## 已确认命名

| 稀有度 | 中文名 | 英文名 | 视觉定位 |
|---|---|---|---|
| common | 破布手套 | Rag Gloves | 旧布与磨损皮革缝合，最简单的手部防护 |
| uncommon | 加固手套 | Reinforced Gloves | 在皮手套上增加少量废铁护片、扣带和铆钉 |
| rare | 军用战术手套 | Military Tactical Gloves | 废土军用库存改造，结构完整，带一个克制的暖橙科技模块 |

名称只修改展示数据和中英文翻译，不改变 `gear_hands_common`、`gear_hands_uncommon`、`gear_hands_rare` 三个稳定 ID，也不改变它们的稀有度、词条数量或掉落逻辑。

## 根因与修复边界

### 拖拽预览

三档通用手套的 JSON `sprite` 为空。正常装备格由 `EquipmentIcon.set_equipment()` 继续回退到 `battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png`，但 Character、Stash、Forge 的拖拽预览只尝试加载 JSON 的显式 `sprite`。因此同一件装备在格子里有图，拖拽时却退化成文字或部位字母。

把贴图解析统一到 `equipment_icon.gd` 的静态接口：

```gdscript
static func resolve_equipment_texture(
	 sprite_path: String, slot: String, rarity: String
) -> Texture2D
```

解析顺序固定为：

1. JSON 显式 `sprite`；
2. 通用部位×稀有度图 `equipment/{slot}_{rarity}.png`；
3. 返回 `null`，由现有 UI 使用部位字母兜底。

`EquipmentIcon.set_equipment()` 与 Character、Stash、Forge 的 `preview_tex` 全部调用同一接口，避免正常格子和拖拽预览再次分叉。

### 重叠装备图

UI 槽位当前只显示一个 `EquipmentIcon`；视觉上的第二只手来自源 PNG。`hands_common.png` 左边缘烘入了一截额外手套，`hands_rare.png` 左边缘也有残片。三档通用手套统一重制，避免只修一张后风格继续断裂。

## 美术合同

- 输出路径保持不变：
  - `battle_scene/assets/images/ui/equipment/hands_common.png`
  - `battle_scene/assets/images/ui/equipment/hands_uncommon.png`
  - `battle_scene/assets/images/ui/equipment/hands_rare.png`
- 每张 `256×256`、透明背景、只有一只手套，不含第二件物体、文字、稀有度边框或 UI。
- 可见像素不得接触画布边缘，四边至少保留 8px 安全边距。
- 三张保持相同朝向、相近占画比例和清晰手掌轮廓，从布料到加固再到军用结构逐级升级。
- 延续当前项目的极简美漫/废土科幻装备图语言：粗深色轮廓、简化大形、两到三阶赛璐璐明暗、低纹理噪声。
- common 使用尘土棕、旧布和磨损皮革；uncommon 加入灰绿废铁；rare 使用深灰军用材料和少量暖橙发光点，避免写实军事装备或高光硬表面概念图。

## 数据与图鉴同步

修改：

- `run_system/data/equipment/gear_hands_{common,uncommon,rare}.json` 的英文 `name`；
- `assets/translations/content_equipment.csv` 的中英文名称；
- 运行 `python scripts/gen_catalog_html.py`，由生成器同步 `docs/catalog_html/`，不手改 HTML。

## 验证

新增装备视觉合同测试，覆盖：

1. `sprite == ""` 的通用手套仍能解析到对应 `hands_{rarity}.png`，拖拽预览不再退化成文字；
2. Character、Stash、Forge 均使用统一解析接口；
3. 三张最终 PNG 为 `256×256` RGBA，且可见像素包围盒四边至少留 8px，阻止裁切残片再次进入；
4. 角色窗口装备后仅显示填充图层，空槽 ghost 图层隐藏；
5. 图鉴重新生成后显示「破布手套 / 加固手套 / 军用战术手套」；
6. 角色窗口回归测试、STS2 HUD 回归测试与全项目 headless smoke 全部通过，并渲染一次带通用手套的角色窗口截图做人工复核。

## 非目标

- 不改变其他四个装备部位的通用名称或美术；
- 不调整装备数值、词条池、稀有度权重和掉落率；
- 不重构 CharacterWindow、StashWindow 或 ForgeWindow 的拖拽数据模型。
