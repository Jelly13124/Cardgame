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
