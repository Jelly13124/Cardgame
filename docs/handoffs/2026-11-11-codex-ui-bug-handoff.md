# 瓶盖猎人 UI 交接：战斗反馈与能量环（2026-11-11）

这份文档给下一轮对话使用。当前工作区是独立 worktree：

- 路径：`C:\Users\Jerry\.codex\worktrees\bottlecap-ui-refresh\Cardgame`
- 分支：`feat/ui-refresh`
- 最近提交：`a33d381 fix(ui): strengthen playable pulse and route choice layout`
- 当前状态：文档创建前应先运行 `git status --short` 确认工作区；不要触碰主目录 `C:\Users\Jerry\Desktop\Cardgame` 的未提交文件。

## 已完成并保持稳定的内容

- 可出牌卡牌的形状贴合高亮已增强：亮度和轮廓宽度同时呼吸，周期 1 秒。实现位于 `ui/battle/card_highlight.gd`，合约在 `tests/battle_ui_contract_test.gd`。
- 多选一地图已加标题、提示和统一软面板，路线卡从 300×420 调整为 320×368，奖励区不再纵向撑出大块空洞。实现位于 `ui/map/map_scene.gd`、`ui/map/route_choice_card.gd`，翻译在 `assets/translations/ui_map.csv`。
- Cowboy Bill 攻击帧已经做过一轮去白边，枪口锚点当前为 `ui/battle/player_view.gd` 的 `MUZZLE_NATIVE_POSITION = Vector2(214, 140)`。
- 最近一次全量验证为 74/74 通过，包含架构层检查和工具单测。

## 用户明确要求继续处理的四个问题

### 1. 枪口闪光太快

当前代码在 `ui/battle/gunshot_fx.gd`：

- `PLAYER_GUNSHOT_WINDUP_SECONDS = 0.22`
- 枪口闪光创建后仅等待 `0.05` 秒就释放
- 子弹飞行使用 `0.16` 秒 Quad 缓动

用户反馈枪口闪光一闪而过，试玩时几乎看不清。下一轮要先查桌面逆向证据目录中的 STS2 攻击/枪口表现代码和着色器，确认闪光的可见窗口、淡入淡出和攻击帧的相位，再调整 `gunshot_fx.gd`。不要只凭感觉把持续时间拉长。枪口闪光属于现有战斗反馈链，改动要保持子弹、命中火花和打击停顿的先后关系。

### 2. 主角攻击动画从白影变成黑影

用户最新反馈是：之前的白色抠图残留变成了黑色边缘/黑影，攻击动作仍然不对。相关代码和素材：

- `ui/battle/player_view.gd`
- `battle_scene/assets/images/heroes/cowboy_bill/attack/cowboy_bill_attack_0.png` 到 `_7.png`
- `tests/hero_attack_art_contract_test.gd`

当前测试只检查半透明亮色边缘，不会抓黑色半透明边缘或黑色背景残片，因此需要补充真正能抓住这次问题的像素检查。逐帧检查：

1. alpha 边缘是否夹带黑色或近黑色像素；
2. 帧之间画布尺寸、脚底基线、枪口位置是否一致；
3. 攻击帧是否只保留一个主角和一把左轮，没有黑色旧背景、重影或重复肢体；
4. 在 Act 1 背景上实际运行截图，确认边缘不会随背景变黑。

修素材时不要修改卡牌插画，也不要改 `ui/battle/combat_feedback_controller.gd`、`damage_number_vfx.gd`、`hit_spark_vfx.gd`、`enemy_death_vfx.gd`。本次枪口闪光问题已由用户明确提出，因此只有 `ui/battle/gunshot_fx.gd` 可以按逆向证据调整时序，其他战斗反馈逻辑继续冻结。

### 3. 意图变化不对

当前意图实现集中在 `ui/battle/enemy_view.gd`：

- 意图节点为 `IntentDisplay` / `IntentCells`；
- `_active_intents` 是按 `kind` 建立的字典；
- `_update_intent_display()` 根据 `kind` 复用或转入 `_retiring_intents`；
- `INTENT_BOB_PERIOD = 2.0`、`INTENT_BOB_AMPLITUDE = 5.0`、`INTENT_BOB_BASE = -4.0`、`INTENT_PHASE_STEP = 0.3`；
- 出现 1 秒，消失 0.5 秒；图标显示 52×52，数字 22 号、描边 12；
- 攻击分档当前为 `<5`、`5–19`、`20+` 三种剑形；多段攻击按每段伤害×次数决定档位。

用户说意图在行动变化时的表现和更新不对。下一轮必须先读：

- 项目逆向文档：`docs/reviews/sts2-ui-reference.md` 的「战斗 HUD 与场景」和「第二阶段战斗 HUD 对照实现」；
- 桌面复用证据：`C:\Users\Jerry\Desktop\STS2-UI-Reference\`；
- 代码证据中的 `NIntent`、`NCreature.RefreshIntents`、`AttackIntent` 以及对应场景/着色器。

重点核对：

1. 行动类型改变但类型相同（例如攻击 4 变攻击 20）时，图标是否应该重播出现动画、只更新数字，还是整体替换；
2. 同一行动包含攻击+减益、格挡+增益时，是否应该按槽位身份更新，而不是简单按 `kind` 去重；
3. 旧图标退出、新图标进入时的占位和相位是否会叠加错位；
4. 新行动出现时是否先显示正确图标再淡入，避免上一行动图标残留一帧；
5. 上下浮动仍保持 STS2 的约 10 像素峰值包络和 0.3 弧度错相，不要重新放大浮动距离。

需要先写一个能复现“行动变化”的测试，再改实现。现有 `tests/enemy_intent_display_test.gd` 已覆盖档位、状态预测、淡入淡出和浮动，但还没有完整覆盖“同 kind 换档”和“多意图顺序变化”这两种情况。

### 4. 删除能量界面外圈

用户想删掉能量徽章外面那一圈，只保留已经认可的能量徽章、数字和暗态切换。相关实现位于 `ui/battle/battle_ui_manager.gd`：

- `_energy_ring` 成员；
- `_build_energy_display()` 创建名为 `EnergyChargeRing` 的 `Control`；
- `_draw_energy_ring()` 用 `draw_arc()` 画空槽和当前能量弧段；
- `_refresh_energy_layers()` 会调用 `_energy_ring.queue_redraw()`。

下一轮只移除 `EnergyChargeRing` 这层和对应绘制/刷新调用，保留 `EnergyDisplay`、`Frame`、`hud_energy_badge_sts2.png`、数字、零能量暗态和能量变化的缩放反馈。不要删除能量徽章本身，也不要碰抽牌堆、弃牌堆、消耗堆。同步更新 `tests/ui_sts2_hud_contract_test.gd`：把“必须有 charge ring”改成“没有 charge ring，但徽章和数字仍存在”。

## 冻结范围

本轮后续修复不得改：

- 卡牌卡框、卡面排版、卡图、手牌布局和卡牌出场动画；
- 能量徽章本体、抽牌堆、弃牌堆、消耗堆的已验收布局（仅按上面要求删除能量外圈）；
- `ui/battle/damage_number_vfx.gd`；
- `ui/battle/hit_spark_vfx.gd`；
- `ui/battle/enemy_death_vfx.gd`；
- `ui/battle/combat_feedback_controller.gd`；
- 伤害数字、命中火花、打击停顿、死亡溶解的现有节奏。

## 继续工作的顺序

1. 只读查看 `Desktop\\STS2-UI-Reference` 与 `docs/reviews/sts2-ui-reference.md`，把枪口闪光、攻击帧切换、意图更新的证据补进工作笔记；
2. 先补三个回归测试：枪口可见窗口、攻击帧黑边、意图同 kind 换档/多意图顺序；
3. 修改意图更新逻辑并验证全部意图测试；
4. 清理主角攻击帧黑影并验证 `hero_attack_art_contract_test`；
5. 调整枪口闪光时序，运行战斗 UI 截图复查；
6. 移除能量外圈并更新 `ui_sts2_hud_contract_test`；
7. 设置 `GODOT_BIN=C:\Users\Jerry\Tools\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe`，运行 `tools/run_tests.ps1`，确认 0 失败；
8. 截图放系统临时目录，不把 STS2 文件或逆向解包内容放入仓库。完成后用 Conventional Commit 提交，提交身份为 `Jelly13124 <ruizheyuan3487@gmail.com>`，不要合并或推送。

## 当前截图与试玩

最近的多选一概念图由图像生成工具生成，仅用于讨论布局，尚未接入游戏。运行试玩应从当前 worktree 启动 Godot 4.6.3；试玩时重点观察：枪口闪光是否看得清、Bill 攻击帧边缘是否出现黑影、敌人行动切换时意图是否短暂残留、能量徽章外圈是否已移除。
