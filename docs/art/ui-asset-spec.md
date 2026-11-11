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

目录为 `run_system/assets/images/ui/kit/`。按钮已按逆向复核改为底图与独立轮廓，普通、悬停、按下和禁用复用底图，通过主题调色与视觉层反馈。旧八张四态底板由四张分层图替换。

| 完成 | 文件路径 | 原图尺寸 | 显示尺寸与用途 | 九宫格边距 |
|---|---|---|---|---|
| [x] | `run_system/assets/images/ui/kit/panel_hard_9slice.png` | 96×96 RGBA | 按面板控件尺寸拉伸；皮肤基准展示为 550×250 | 24/24/24/24 |
| [x] | `run_system/assets/images/ui/kit/panel_soft_9slice.png` | 96×96 RGBA | 按面板控件尺寸拉伸；皮肤基准展示为 550×250 | 24/24/24/24 |
| [x] | `run_system/assets/images/ui/kit/button_primary_base.png` | 320×96 RGBA | 展示 320×80，基地出发 670×107；九宫格，阴影复用此图 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_primary_outline.png` | 320×96 RGBA | 与底图同尺寸对齐，透明中心，独立交互描边 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_secondary_base.png` | 320×96 RGBA | 展示 320×80，基地难度 278×56；九宫格，阴影复用此图 | 20/16/20/16 |
| [x] | `run_system/assets/images/ui/kit/button_secondary_outline.png` | 320×96 RGBA | 与底图同尺寸对齐，透明中心，独立交互描边 | 20/16/20/16 |
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

基地、建筑窗口、主菜单、存档行、角色与锻造窗口、事件、商店、路线卡、奖励、休息选项和通用按钮引用同一套主题构造方法。装饰面板与兼容按钮样式使用 StyleBoxTexture；动态按钮保留原生 Button 输入与文字，独立的 Shadow、Face、Outline 子层由共用控制器管理。

数据进度、稀有度色点与角色地面阴影使用集中定义的语义填充，安全格、图像边缘与焦点状态使用共用的细线语义轮廓。卡牌升级预览的两处既有贴卡交互轮廓保持其专属几何与显隐规则。商店删牌页卡格透明，悬停调用卡牌现有轮廓。

长短横幅与角饰已作为共用贴图交付，可由后续奖励、营火、结算和弹窗阶段按对应位置直接引用。

## 审查材料与核验

原始生成稿、完整提示词、确定性处理脚本、尺寸与哈希清单位于系统临时目录 `bottlecap-ui-stage1-20261110/`。`generation-manifest.json` 保存原始图像与提示词，`asset-manifest.json` 保存交付来源、尺寸、裁切区域与哈希。

素材原生大小预览为 `qc/kit-contact.png`。改后截图、STS2 自述结构示意和并排对比统一由该目录的 `review.html` 浏览。STS2 原图与代码继续由临时分析目录管理。

## 第1阶段验证结果

`tools/run_tests.ps1` 使用指定 Godot4.6.3 与隔离 APPDATA 返回0，71项通过、0项失败。全量日志位于系统临时目录 `cardgame-tests-9566d316a45f4d339145972fdcad1e93/logs/`。下拉悬停文字配色收尾后，`ui_*` 两项界面测试再次通过，日志位于 `cardgame-tests-1fe5af45b48c4094bb3bbe95b9aaf197/logs/`。

新增与更新的检查覆盖23份皮肤尺寸、四态按钮、九宫格边距、下拉展开菜单、种子无效态、复选框、提示所有者和即时更新、卡牌预览轮廓、安全格货币文字遮挡，以及原有基地出发按钮位置。新测试场景已由 `tools/assign_scene_uids.gd` 分配引擎UID。

30张改后原生截图与结构示意保存在 `bottlecap-ui-stage1-20261110/after/`、`reference/`、`comparisons/`。截图启动使用隔离存档与私有桌面，最后一次截图日志无错误。卡牌源文件、卡图、字体资源和已确认的五项战斗反馈文件与阶段起点一致。

## 第1阶段按钮修订验收

本次替换了主、次按钮的厚角片底板，新增4张320×96分层图并移除原8张四态图；共用皮肤交付数为19张。生成使用内置图像工具，原始稿保留于 Codex 默认生成目录，完整提示词、确定性调色与拆层处理、交付哈希记录在系统临时目录 `bottlecap-ui-buttons-20261110/` 的 `generation-prompts.json`、`process_buttons.py` 与 `asset-manifest.json`。

主菜单使用32号实时文字与24×24选择箭头。箭头复用已交付的32×32原创下拉图旋转显示，放在文字左侧12像素。主、次按钮的阴影复用底图，偏移(0,4)，轮廓单独显示。菜单没有整块底板，列表保持位置稳定并用较安静的底色遮住无关的底层画面。

悬停0.05秒，失焦0.5秒Expo-Out；主按钮视觉缩放1.05/0.95，次按钮1.025/0.975。输入命中区、原生文字和图标保持稳定。状态同步覆盖鼠标、键盘、禁用、隐藏恢复、拖出回入、重复应用与退出树。迁移时保留原文字内距，基地出发为28/22/28/18，结束回合为28/8/28/8，建筑升级确认键为14/8/14/9。

指定Godot4.6.3的完整 `tools/run_tests.ps1` 最终返回0：71项通过、0项失败，工具测试与架构检查通过。新增与更新的界面检查分布于5个现有测试，包含真实鼠标和键盘输入。最终控制台证据保存在临时目录 `bottlecap-ui-buttons-20261110/tests/full-final.console.log`，不依赖成功后会自动清理的测试工作目录。

32张改后1920×1080截图、改前对照和自绘STS2结构示意由 `bottlecap-ui-buttons-20261110/review.html` 浏览。改前来自本轮起点 `af106b5` 对应的前轮实际游戏截图；建筑升级弹窗为新增检查项。最终截图日志无ERROR或WARNING，正式中文Cowboy Bill卡壳核验通过。主目录状态与修订前一致，卡牌源文件、卡图、字体和五项冻结战斗特效无改动。本次没有新增场景文件，新增脚本UID由Godot生成。
