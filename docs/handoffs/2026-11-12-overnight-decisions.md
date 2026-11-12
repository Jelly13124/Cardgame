# 2026-11-12 过夜决定日志

工作区：`C:\Users\Jerry\.codex\worktrees\bottlecap-ui-refresh\Cardgame`；分支 `feat/ui-refresh`；起点 `645d4c5`。开始前 `git status --short` 为空。

每行记录「决定｜理由/证据｜如果判断不合适要改的文件」。阶段完成记录、测试证据和提交见同目录过夜报告。

- 全程按用户给定 A→F 顺序验收、全量测试、逐阶段提交；阶段内独立调查并行｜用户已授权自主决定，优先 STS2 结构、新敌人画风、可读性｜本日志、过夜报告。
- 攻击意图保持项目原有三档（总伤害 `<5`、`5–19`、`20+`）和原有三张 64×64 图；只修复切换时的槽位、旧图退场和新图进入｜用户明确三档是本项目设计，STS2 五档只作结构参考｜`ui/battle/enemy_view.gd`、意图测试；不新增意图图标。
- 能量界面只删除 `EnergyChargeRing` 外圈，保留徽章、数字、零能量暗态和缩放反馈｜用户明确要去掉外圈且保留主体｜`ui/battle/battle_ui_manager.gd`、`tests/ui_sts2_hud_contract_test.gd`。
- 枪口火光独立可见窗口定为 0.16 秒并与现有 0.16 秒子弹飞行并行，火光淡出不延迟子弹或命中顺序｜本地 STS2 证据没有同款枪口时长，只有 0.30–0.35 秒命中特效与 0.268 秒四帧攻击特效，故按可读性和现有接触相位做最小适配｜`ui/battle/gunshot_fx.gd`、`tests/gunshot_fx_contract_test.gd`。
- 共用 `panel_hard_9slice.png` 右上红角是可重复的视觉污染；用左上原生角镜像覆盖右上，保持九宫格外形与平涂，不把角饰复制到小格子/按钮｜图像像素检查确认右上红像素为污染，改后 `ui_skin_contract_test` 通过｜`run_system/assets/images/ui/kit/panel_hard_9slice.png`、`tests/ui_skin_contract_test.gd`。
- 阶段 A 在 `7ba184e` 提交｜全量 `tools/run_tests.ps1` 75/75、工具测试、分层检查通过；改前/改后实际截图与过渡截图在 `C:\Users\Jerry\AppData\Local\Temp\bottlecap-ui-overnight-20261112\review.html`｜如需回退，回到 `645d4c5` 并只撤销阶段 A 文件。
- 测试与截图均使用临时用户目录和测试存档根；截图、原始生成稿、STS2 阅读证据留在仓库外临时目录｜保护真实存档，避免将参考资源交付为原创资源｜截图工具、测试启动命令。
- 先保留全套实际改前截图，再改生产视觉；保留单屏前后和原创坐标线框三列｜用户需要明早逐屏验收｜临时 `review.html` 与捕获脚本。
- 阶段 B 的奖励、选卡、营火、结算与通用弹窗共用压暗遮罩、横幅和材质底板；选卡层自身从 `BAR_HEIGHT` 起算，并把局部坐标折回到全局动作带 `y=884..957`，避免顶栏被覆盖｜既满足 persistent top bar 的层级，也保留用户给定的动作位置；如果视觉不合适改 `ui/rewards/loot_reward.gd`、`ui/rewards/loot_reward.tscn`、`ui/map/map_scene.gd`、`ui/rewards/result_screen.gd`、`ui/rewards/extract_choice_modal.gd`。
- 阶段 C 的路线标题使用 `banner_long.png` 加深色字，路线组框与卡片常态都改为空样式，稀少内容卡的 VBox 在可用高度内居中；商店删卡服务改为与商品同样的图标/标题/价格货位，遗物提示统一走共享 Tooltip 并包含说明，价格统一使用 54×54 Caps、39 号字和 15 px 描边｜保持 UI07 的轻边框与 STS2 的库存信息层级，同时不改变商店库存规则；涉及 `ui/map/map_scene.gd`、`ui/map/route_choice_card.gd`、`ui/shop/merchant_card_removal.gd`、`ui/shop/merchant_slot.gd` 及 Stage C 合约测试。
- 阶段 D 保留现有原创基地背景与四座建筑运行图，只统一基地面板改用 `panel_textured("hard")`，保留 normal/hover/pressed 建筑状态、锁定灰阶、浮动建筑徽章、悬赏/难度/种子/出发/三入口层级｜现有资产已满足 1920×1080 与新敌人画风，重画会扩大风险且不改变信息层级；如果需要调整改 `ui/base/home_base_scene.gd`、基地运行图资源和 Stage D 合约测试。
- 阶段 E 复用现有原创荒地画风，把 Act 2/3 选为城市废墟/冷色辐射变体，补齐 1920×1080 全屏副本和 1024×768 事件插画副本；战斗在 `_ready` 按 `RunManager.current_act` 换背景，事件页优先加载 `_1024x768` 版本｜现有构图已符合新敌人画风，尺寸统一比重新生成一整套更可控；如果需要回退改 `ui/battle/battle_screen.gd`、`ui/map/map_scene.gd`、`ui/menus/main_menu.gd`、`ui/events/event_room.gd` 和 Stage E 资源副本。
- 阶段 F 将新敌人、新主角、三幕背景和 UI07 皮肤写入两份认可样板文档，并把最终截图与 13 张原创结构示意集中到临时 `review.html`｜让明早验收同时有运行画面和可核对的结构尺寸；若需回退改 `docs/art-style-reference.md`、`docs/project-rules.md`、`docs/art/ui-asset-spec.md` 与临时 review 生成脚本。

## 本轮追加决定（2026-11-12）

- 地图概念图和实际地图页保留现有 persistent topbar 原样，三选一内容从 `RUN_TOP_BAR.BAR_HEIGHT` 以下开始｜用户明确概念图不要更改已有 topbar，且 UI07 要保持顶栏稳定｜如果不合适改 `ui/map/map_scene.gd`、`ui/map/route_choice_card.gd`、`ui/map/route_choice_card.tscn`；不要改 `ui/common/run_top_bar.gd`。
- 路线选择改为固定三槽结构，卡片为 320×460、间距 28，并显示 1/2/3 选择编号｜采用 Slay the Spire 式三选一信息节奏，同时保持本项目废土漫画画风和可读性｜如果不合适改 `ui/map/map_scene.gd`、`ui/map/route_choice_card.gd`、`tests/map_route_scene_test.gd`、`tests/route_choice_card_test.gd`。
- 奖励界面回退到过夜改动前的紧凑居中结构，保留遮罩和完整顶栏安全间距｜过夜版本的巨型底板、横幅和绝对定位造成画面变丑，用户要求沿用之前奖励界面｜如果不合适改 `ui/rewards/loot_reward.gd`、`ui/rewards/loot_reward.tscn`、`ui/rewards/result_screen.gd`、`ui/rewards/extract_choice_modal.gd` 及 Stage B 合约测试。
- 路线地图背景替换为 1920×1080 的原创废土漫画场景，中心留出安静区域承载路线卡｜解决旧羊皮纸/杂乱背景与三槽路线层级冲突｜如果不合适改 `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`。
- 主角战斗显示目标高度降到 256，强制 tint alpha 为 1，并用可见像素底线和归一化枪口锚点保持 idle/attack 对齐｜修复待机过透明、主角过大，同时保留 384px 原画源像素和枪口/受击/血条相对位置｜如果不合适改 `ui/battle/player_view.gd`、`tests/hero_presentation_contract_test.gd`、`tests/hero_attack_art_contract_test.gd`。
- 暂停阶段 E 的事件插画重画项，不改事件背景、`ui/events/event_room.gd`，也不把事件尺寸文档从旧规格改成新规格｜用户明确要求先停下该项，后续规格为全屏 1920×1080/2112×1188、右侧自然变暗留文案｜恢复该项时改 `ui/events/event_room.gd`、事件资源、`docs/handoffs/2026-11-10-codex-art-handoff.md`、`docs/art/ui-asset-spec.md`。
