# 阶段 0：安全网 — 设计（spec）

日期：2026-10-22
分支：`refactor/phase0-safety-net`（worktree：`Desktop/Cardgame-phase0`，基于 `176d866`）
来源：架构审查路线图 `docs/reviews/sts2-architecture-review/10-roadmap.md` 阶段 0（审查文档目前在主目录 `Desktop/Cardgame/docs/reviews/`，尚未提交）

## 目标

在修改任何游戏规则之前，建立“一键确认没有破坏既有行为”的能力，消除存档丢失风险，并确定之后所有目录迁移都依赖的路径约定与分层规则。

**本阶段不改变任何游戏行为。** 两个已知显示 bug（S1-01 瞄准预览、S4-01 敌人意图）只写测试把它们固定下来，修复留给阶段 1。

## 已确认的决定

| 决定 | 内容 | 来源 |
|---|---|---|
| 工作位置 | 新分支 + 独立 worktree；主目录未提交的美术改动不受影响；每个任务一个提交 | 用户选择 |
| 引用约定 | 脚本与场景之间一律用 `preload("uid://…")`/`load("uid://…")` 引用，并在同行注释原路径 | 用户选择 |
| 转换范围 | 本阶段把全部 `.gd`/`.tscn` 引用转换为 `uid://`；数据目录与素材路径留给阶段 2 | 推荐方案 A（用户未另选） |

已验证（Godot 4.6.3 实测）：`preload/load("uid://…")` 可用；`.uid` 文件随脚本移动（`git mv`）后引用不断；场景头带 `uid` 时 `change_scene_to_file("uid://…")`、`ResourceLoader.exists` 可用。项目 35 个场景中仅 4 个场景头带 `uid`，需要先补齐。

## 范围（对应审查 finding）

1. **一键测试入口**（S9-01）
2. **测试隔离用户数据**（S9-04）
3. **存档原子写入与备份回退**（S8-03）
4. **预览/意图一致性测试**（S9-02，预期失败）
5. **引用转换为 `uid://`**（S11-04）
6. **分层与依赖规则成文 + 自动检查**（S11-06）
7. **低风险目录整理**：工具脚本 → `tools/`；4 个界面无关的 autoload → `autoload/`（S11-05）

不在范围：`RunManager`/`MetaProgress` 拆分（阶段 7）、内容数据迁移（阶段 2）、任何规则修复（阶段 1）。

## 设计

### 1. 测试入口 `tools/run_tests.ps1` 与 `tools/run_tests.sh`

- Godot 可执行文件：环境变量 `GODOT_BIN`，否则 PATH 上的 `godot`；找不到时给出明确提示后退出码 2。
- 步骤：
  1. 为本次运行创建独立用户数据目录（Windows 设置 `APPDATA`，Linux 设置 `XDG_DATA_HOME`），运行结束后删除；
  2. 若无 `.godot/` 导入缓存，先 `--headless --import`；
  3. 冒烟启动：`--headless --quit-after 5`，匹配原 `smoke_test.ps1` 的错误模式；
  4. 依次运行 `tests/*_test.tscn`（不含 `*_visual_capture`），每个超时 300 秒；
  5. 运行分层检查 `tools/check_layers.py`；
  6. 输出表格（名称、结果、耗时）与汇总。
- **预期失败清单** `tests/expected_failures.txt`：每行 `<测试名>  <finding ID>  <说明>`。清单内的测试失败记为 `XFAIL`（不影响退出码）；清单内的测试**通过**记为 `XPASS`，并使退出码为 1，提醒删除该行。
- 退出码：0 = 全部通过（含 XFAIL）；1 = 有失败或 XPASS；2 = 环境问题。
- 原 `scripts/smoke_test.ps1`/`.sh` 移到 `tools/` 并保留（只做冒烟），文档改为推荐 `run_tests`。

### 2. 存档读写 `core/save/save_io.gd`（新 `core/` 层的第一个文件）

纯静态工具（`extends RefCounted`），不依赖任何 autoload 或节点：

- `static var root: String = "user://"`：测试可改为 `"user://__test__/"`；所有存档路径由 `SaveIO.path(relative)` 拼出。
- `write_json(relative, data) -> Error`：
  1. 序列化后写入 `<file>.tmp`；
  2. 重新读取 `.tmp` 并解析，失败则删除 `.tmp` 返回错误、原文件不动；
  3. 轮换备份：`<file>.bak2` ← `<file>.bak1` ← 当前 `<file>`；
  4. `.tmp` 改名为 `<file>`。
- `read_json(relative) -> Dictionary`：返回 `{ "status": OK|MISSING|RECOVERED|CORRUPT, "data": Dictionary, "source": String }`。依次尝试 `<file>`、`.bak1`、`.bak2`；主文件损坏但备份可用时返回 `RECOVERED`，并把损坏文件另存为 `<file>.corrupt-<unix时间>`（**永不覆盖**）；全部失败返回 `CORRUPT`，同样保留损坏副本。
- `delete(relative)`：删除文件及其 `.tmp/.bak1/.bak2`（`.corrupt-*` 保留）。
- 接入点（行为保持不变，只换底层读写）：`MetaProgress.save_progress/load_progress/peek_slot/delete_slot`、`RunManager.save_run/load_run/has_run_save/clear_run_save`、`Settings.save_settings/load_settings`。原“损坏改名 `.bak` 后以默认值继续”改为：有备份则恢复；全部损坏时保留损坏副本并以默认值继续（与现状一致的可玩性，但不再丢失原文件）。
- 文件布局保持 `user://slot_<n>/meta.json`、`user://slot_<n>/run_save.json`、`user://settings.json` 不变，旧存档无需迁移。

### 3. 测试隔离

- 双重保护：运行器层面重定向用户数据目录（第 1 节）；代码层面需要写存档的测试在开头设置 `SaveIO.root = "user://__test__/"` 并在结束时清理该目录。
- 现有写存档的测试（`base_inventory_ownership`、`building_upgrade_runtime`、`forge_backpack`、`demo_content`）全部加上第二层保护。

### 4. 一致性测试（预期失败）

- `tests/combat_preview_parity_test.tscn`：对 `battle_scene/card_info/player/` 中每张需要选择敌方目标、且含伤害效果的卡牌，在若干状态组合（STR 0/3、玩家虚弱、目标易伤、装填 2 层）下，比较 `battle_scene._card_preview_damage(card, target)` 与经 `combat_engine._apply_effect` 实际结算对伪目标造成的伤害。已知 `piston_jab` 等 `no_str` 卡会失败（S1-01）。
- `tests/enemy_intent_parity_test.tscn`：对每个敌人 JSON 中的攻击类行动，在玩家易伤/敌人虚弱/持有减伤遗物/第 2 幕倍率下，比较 `enemy_entity._compute_display_attack` 与经 `enemy_ai._execute_action` 实际对伪玩家造成的伤害。已知奇数伤害+易伤会失败（S4-01）。
- 两个测试列入 `tests/expected_failures.txt`；测试输出列出每个不一致的具体组合，作为阶段 1 的验收清单。
- 测试只读取正式内容、不修改规则代码。

### 5. 引用转换

- 场景 UID：`tools/assign_scene_uids.gd`（用 `godot --headless --script` 运行）为场景头缺少 `uid` 的 `.tscn` 生成 UID。UID 由 Godot 自身的 `ResourceUID.create_id()` / `id_to_text()` 生成，只修改文件第一行，生成前收集已有 UID 去重。
- 引用改写：`tools/godot_refs.py`（Python 3，可重复运行、幂等）：
  1. `convert`：把 `.gd` 中 `preload("res://….gd|.tscn")`、`load("res://….gd|.tscn")`、以及值为 `"res://….tscn"` 的常量与 `change_to(...)` 实参改写为对应 `uid://`，并在行尾追加 `# res://原路径`；读取 `.gd.uid` 与场景头获取 UID；
  2. `check`：列出仍残留的 `res://….gd|.tscn` 字符串引用（供运行器与人工复核）。
- 范围：`battle_scene/`、`run_system/`、`tests/`；不改 `addons/`（第三方）、`.tscn` 内部的 `ext_resource`（编辑器维护）、`project.godot`（autoload 与主场景继续用路径，迁移时同步修改）。
- 数据目录常量（如 `card_info/player/`）与素材路径不转换（阶段 2 处理）。

### 6. 分层规则

- 新文档 `docs/conventions/architecture-layers.md`：目标结构（`core/`、`content/`、`ui/`、`autoload/`、`assets/`、`tools/`）、依赖规则表、引用约定（`uid://` + 路径注释；`class_name` 只用于需要做类型标注的核心类型，不再新增“禁止 class_name”的注释，旧注释在被修改时更新）。
- `AGENTS.md` 增加一段简短的“代码结构”规则并链接该文档；`docs/PROJECT_STRUCTURE.md` 更新工具与 autoload 的新位置。
- `tools/check_layers.py`：当前可执行的检查——`core/` 下的脚本不得包含 `res://run_system/ui`、`res://battle_scene/ui`、`get_tree()`、`current_scene`；`content/`（尚不存在时跳过）中不得有 `.gd`；新增的 `.gd`/`.tscn` 引用不得使用 `res://` 路径（复用 `godot_refs.py check`）。

### 7. 目录整理

- `scripts/*` 与 `battle_scene/scripts/*` → `tools/`（`git mv`）；修正 `battle_scene/scripts` 中脚本的项目根目录层级；更新 `docs/PROJECT_STRUCTURE.md`、`docs/README.md`、`docs/project-rules.md`、`docs/steam-demo-build.md` 中的路径（含导出排除规则 `scripts/*` → `tools/*`）。
- `run_system/core/{settings,audio_manager,tooltip,scene_transition}.gd`（连同 `.uid`）→ `autoload/`；更新 `project.godot` 与 `tests/scene_transition_sts2_contract_test.gd`。`RunManager`、`MetaProgress` 不动（阶段 7）。

## 成功标准

1. `tools/run_tests.ps1` 一条命令完成：冒烟启动无错误；原 17 个测试全部通过；新增存档测试通过；两个一致性测试为 `XFAIL` 且输出具体不一致组合；分层检查通过；退出码 0。
2. 运行测试前后，开发者真实的 `app_userdata/CardFramework` 不新增、不修改文件。
3. 存档测试覆盖：正常写读、写入中断（残留 `.tmp`）、主文件损坏从 `.bak1` 恢复、全部损坏保留 `.corrupt-*`、`delete` 不删除 `.corrupt-*`、旧格式存档（无备份）照常读取。
4. `godot_refs.py check` 在 `battle_scene/`、`run_system/`、`tests/` 中报告 0 处 `.gd`/`.tscn` 路径引用。
5. 手动试玩：主菜单 → 选槽 → 开局 → 一场战斗 → 地图 → 退出并“继续” → 设置修改后重启仍保留；与 `main` 行为一致。

## 风险与应对

| 风险 | 应对 |
|---|---|
| 批量改写引用造成运行时断链 | 工具幂等且只改可识别模式；每个子步骤后跑完整测试与冒烟；改动单独提交便于回滚 |
| 自动生成的场景 UID 与已有 UID 冲突 | 生成前收集全部现有 UID（`.uid` 文件、场景头、`.import`）并去重 |
| 存档改造影响旧存档 | 文件布局不变；增加“旧格式无备份存档”测试；读取逻辑对缺失备份容错 |
| 新 worktree 无导入缓存 | 运行器检测并先导入 |
| 导出配置在仓库外（`export_presets.cfg` 未提交） | 文档更新排除规则，并在完成说明中提醒手动修改本机导出预设 |
