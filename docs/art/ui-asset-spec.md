# 界面素材规格与交付状态

日期为 2026-11-10，分支为 `feat/ui-refresh`。本页按验收阶段记录已核验的交付 PNG。当前阶段为第 1 阶段，后续阶段在获得确认后补齐相应条目。

## 共用约定

- 视觉基准为当前 `battle_scene/assets/images/enemies/*/attack/*_attack_0..3.png` 的平涂、深色轮廓和低密度细节。所有本轮新皮肤由内置图像生成制作，技术处理包含去品红、裁切、调色板收敛、缩小与透明边缘核验。
- 原图尺寸指仓库内交付 PNG 的像素尺寸。九宫格的显示尺寸由控件布局决定，四角保持原生像素，中段拉伸。尺寸小于素材的控件缩小显示。
- 九宫格边距按左、上、右、下记录。所有皮肤路径、边距与内容内距由 `ui/common/theme/wasteland_theme.gd` 管理。插画、文字和输入命中区各自独立。
- 本阶段保持现有页面布局。奖励、战斗 HUD、营火等专属结构与动效按后续阶段验收。

## 第 1 阶段收进的既有缺图

主目录指定范围实际为 15 张 PNG 与 15 份配套 `.import`，共 30 个文件。逐项尺寸与格式符合交接清单，复制前后 SHA-256 一致。既有事件图在第4阶段继续按新敌人基准复核画风。

| 完成 | 文件路径 | 原图尺寸 | 显示尺寸 | 九宫格 | 格式 |
|---|---|---|---|---|---|
| [x] | `battle_scene/assets/images/ui/status/deadeye.png` | 64×64 | 30×30 当前；40×40 为第 2 阶段目标 | 无 | RGBA |
| [x] | `battle_scene/assets/images/ui/status/loaded.png` | 64×64 | 30×30 当前；40×40 为第 2 阶段目标 | 无 | RGBA |
| [x] | `battle_scene/assets/images/ui/status/overload_protocol.png` | 64×64 | 30×30 当前；40×40 为第 2 阶段目标 | 无 | RGBA |
| [x] | `battle_scene/assets/images/ui/status/reactive_plating.png` | 64×64 | 30×30 当前；40×40 为第 2 阶段目标 | 无 | RGBA |
| [x] | `run_system/assets/images/events/adrenaline_shot.png` | 1024×768 | 1024×768 | 无 | RGB |
| [x] | `run_system/assets/images/events/backdrops/act_1.png` | 1920×1080 | 1920×1000 可见区，从 y=80 起；1920×1080 原图覆盖裁切 | 无 | RGB |
| [x] | `run_system/assets/images/events/backdrops/act_2.png` | 1920×1080 | 1920×1000 可见区，从 y=80 起；1920×1080 原图覆盖裁切 | 无 | RGB |
| [x] | `run_system/assets/images/events/backdrops/act_3.png` | 1920×1080 | 1920×1000 可见区，从 y=80 起；1920×1080 原图覆盖裁切 | 无 | RGB |
| [x] | `run_system/assets/images/events/cursed_safe_open.png` | 1024×768 | 1024×768 | 无 | RGB |
| [x] | `run_system/assets/images/events/deserter_charm.png` | 1024×768 | 1024×768 | 无 | RGB |
| [x] | `run_system/assets/images/events/rad_storm_bunker.png` | 1024×768 | 1024×768 | 无 | RGB |
| [x] | `run_system/assets/images/events/torn_coin_pouch.png` | 1024×768 | 1024×768 | 无 | RGB |
| [x] | `ui/events/icons/lethal.png` | 32×32 | 32×32 | 无 | RGBA |
| [x] | `ui/events/icons/lock.png` | 32×32 | 32×32 | 无 | RGBA |
| [x] | `ui/events/icons/luck.png` | 32×32 | 32×32 | 无 | RGBA |

## 第 1 阶段原创共用皮肤

目录为 `run_system/assets/images/ui/kit/`。下表逐项列出实际文件。按钮为每种状态独立的贴图。

| 完成 | 文件路径 | 原图尺寸 | 显示尺寸与用途 | 九宫格边距 |
|---|---|---|---|---|
| [x] | `run_system/assets/images/ui/kit/panel_hard_9slice.png` | 96×96 RGBA | 按面板控件尺寸拉伸；皮肤基准展示为 550×250 | 24/24/24/24 |
| [x] | `run_system/assets/images/ui/kit/panel_soft_9slice.png` | 96×96 RGBA | 按面板控件尺寸拉伸；皮肤基准展示为 550×250 | 24/24/24/24 |
| [x] | `run_system/assets/images/ui/kit/button_primary_normal.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_primary_hover.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_primary_pressed.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_primary_disabled.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_secondary_normal.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_secondary_hover.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_secondary_pressed.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_secondary_disabled.png` | 192×64 RGBA | 按按钮控件尺寸拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/tooltip_panel_9slice.png` | 320×96 RGBA | 初始 400×118，随正文向下扩展 | 55/43/91/32 |
| [x] | `run_system/assets/images/ui/kit/tooltip_shadow_9slice.png` | 320×96 RGBA | 初始 400×118，随正文向下扩展 | 55/43/91/32 |
| [x] | `run_system/assets/images/ui/kit/banner_long.png` | 652×162 RGBA | 652×162；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/banner_short.png` | 360×96 RGBA | 360×96；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/dropdown_9slice.png` | 192×64 RGBA | 随下拉框控件拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/input_9slice.png` | 192×64 RGBA | 随输入框控件拉伸；原生基准 192×64 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/divider.png` | 256×8 RGBA | 基准高 8；基地悬赏区高 1，横向按内容区延展 | 8/0/8/0 |
| [x] | `run_system/assets/images/ui/kit/corner.png` | 32×32 RGBA | 32×32；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/checkbox_unchecked.png` | 32×32 RGBA | 32×32；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/checkbox_checked.png` | 32×32 RGBA | 32×32；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/checkbox_unchecked_disabled.png` | 32×32 RGBA | 32×32；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/checkbox_checked_disabled.png` | 32×32 RGBA | 32×32；按使用处等比缩小 | 无 |
| [x] | `run_system/assets/images/ui/kit/dropdown_arrow.png` | 32×32 RGBA | 32×32；按使用处等比缩小 | 无 |

### 提示框图层与文字

主图与投影为两张独立原画轮廓贴图，分别由 PanelContainer 的 StyleBoxTexture 与 NinePatchRect 显示。投影取主图轮廓的 32% 不透明度，偏移 (3,2)。主图保持完整不透明的平涂内面。

初始最小尺寸为 400×118，内容内距为 22/16/45/28，文字可用宽为 333，字号为 22。字体沿用本项目自己的 Oswald 与 Noto CJK。提示沿用所有者检查与过期关闭保护，按视口边界避让。

### 共用皮肤的应用

基地、建筑窗口、主菜单、存档行、角色与锻造窗口、事件、商店、路线卡、奖励、休息选项和通用按钮引用同一套主题构造方法。主题原有入口保持兼容，装饰性面板和按钮均返回 StyleBoxTexture。

数据进度、稀有度色点与角色地面阴影使用集中定义的语义填充，安全格、图像边缘与焦点状态使用共用的细线语义轮廓。卡牌升级预览的两处既有贴卡交互轮廓保持其专属几何与显隐规则。商店删牌页卡格透明，悬停调用卡牌现有轮廓。

长短横幅与角饰已作为共用贴图交付，可由后续奖励、营火、结算和弹窗阶段按对应位置直接引用。

## 审查材料与核验

原始生成稿、完整提示词、确定性处理脚本、尺寸与哈希清单位于系统临时目录 `bottlecap-ui-stage1-20261110/`。`generation-manifest.json` 保存原始图像与提示词，`asset-manifest.json` 保存交付来源、尺寸、裁切区域与哈希。

素材原生大小预览为 `qc/kit-contact.png`。改后截图、STS2 自述结构示意和并排对比统一由该目录的 `review.html` 浏览。STS2 原图与代码继续由临时分析目录管理。

## 第1阶段验证结果

`tools/run_tests.ps1` 使用指定 Godot4.6.3 与隔离 APPDATA 返回0，71项通过、0项失败。全量日志位于系统临时目录 `cardgame-tests-9566d316a45f4d339145972fdcad1e93/logs/`。下拉悬停文字配色收尾后，`ui_*` 两项界面测试再次通过，日志位于 `cardgame-tests-1fe5af45b48c4094bb3bbe95b9aaf197/logs/`。

新增与更新的检查覆盖23份皮肤尺寸、四态按钮、九宫格边距、下拉展开菜单、种子无效态、复选框、提示所有者和即时更新、卡牌预览轮廓、安全格货币文字遮挡，以及原有基地出发按钮位置。新测试场景已由 `tools/assign_scene_uids.gd` 分配引擎UID。

30张改后原生截图与结构示意保存在 `bottlecap-ui-stage1-20261110/after/`、`reference/`、`comparisons/`。截图启动使用隔离存档与私有桌面，最后一次截图日志无错误。卡牌源文件、卡图、字体资源和已确认的五项战斗反馈文件与阶段起点一致。
