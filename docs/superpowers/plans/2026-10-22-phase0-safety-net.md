# 阶段 0：安全网 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一键测试入口、测试隔离、存档原子写入、两条一致性测试（预期失败）、`uid://` 引用约定与转换、分层规则与检查、工具与 autoload 目录整理——全程不改变游戏行为。

**Architecture:** 新增 `core/save/save_io.gd`（新 `core/` 层的第一个文件）承接全部存档读写；测试入口脚本负责隔离用户目录、导入、冒烟、运行场景测试、分层检查并汇总；引用转换由 Godot 脚本（生成场景 UID）+ Python 脚本（改写引用）完成。

**Tech Stack:** Godot 4.6.3（GDScript 2.0，无头运行）、Python 3.13（仅标准库）、PowerShell 5.1 / bash。

**Spec:** `docs/superpowers/specs/2026-10-22-phase0-safety-net-design.md`

## Global Constraints

- 不改变任何游戏行为；S1-01、S4-01 只写测试不修复。
- 现有 17 个 `tests/*_test.tscn` 在每个任务结束时全部通过。
- 不修改 `addons/`；不触碰主目录 `Desktop/Cardgame`（只在 worktree `Desktop/Cardgame-phase0` 工作）。
- Godot 可执行文件来自环境变量 `GODOT_BIN`；本计划中写作 `$GODOT_BIN`。
- 手动运行任何 Godot 命令时都设置隔离的用户目录（Windows：`APPDATA=<临时目录>`），直到 Task 1 的入口脚本可用后改用入口脚本。
- 存档文件布局保持：`user://slot_<n>/meta.json`、`user://slot_<n>/run_save.json`、`user://settings.json`。
- Python 工具只用标准库；可重复运行且幂等。
- 每个任务一个提交，Conventional Commits 格式；不 push，不合并。

## Review Focus

1. **安装路径含空格或中文**（`GODOT_BIN`、worktree 路径）：入口脚本必须正确加引号 → Task 1 Step 4 用含空格的临时副本路径验证。
2. **残留 `.tmp`（上次写入中途崩溃）**：下次写入应覆盖 `.tmp` 而不是失败，读取不应把 `.tmp` 当作存档 → Task 2 测试 `test_stale_tmp_is_ignored_and_replaced`。
3. **旧存档没有任何备份文件**：照常读取、状态为 `OK`，首次保存后才产生 `.bak1` → Task 2 `test_legacy_file_without_backups`、Task 3 `test_legacy_profile_loads_unchanged`。
4. **引用改写误伤**：注释、文档字符串、拼接路径（`"res://…/%s.json"`、`CARD_DIR + id`）不能被改写；找不到 `.uid` 的脚本必须报错而不是猜测 → Task 5 `godot_refs.py` 自测。
5. **槽位目录不存在时写存档**（新档、槽 2/3 首次使用）：`write_json` 自动创建目录 → Task 2 `test_write_creates_missing_directories`。
6. **首次全量导入偶发崩溃**（无 `.godot/` 的新检出）：入口脚本自动重试而不是把缺失素材导致的失败报告成测试失败 → Task 1 Step 2 先删除 `.godot/` 再运行入口验证。

---

### Task 1: 测试入口与预期失败清单

**Files:**
- Create: `tools/run_tests.ps1`, `tools/run_tests.sh`, `tests/expected_failures.txt`
- Create（临时，Step 5 删除）: `tests/zz_runner_selfcheck_test.gd`, `tests/zz_runner_selfcheck_test.tscn`

**Interfaces:**
- Produces: 命令 `pwsh tools/run_tests.ps1 [-Only <通配>]` / `bash tools/run_tests.sh [pattern]`；退出码 0/1/2（见 spec §1）；`tests/expected_failures.txt` 每行 `<测试名> <finding ID> <说明>`，`#` 开头为注释。
- 入口在 `tools/check_layers.py` 存在时调用它（Task 7 创建），不存在时跳过并打印 `layers: skipped`。

- [ ] **Step 1：写入口脚本**
  - 解析 `GODOT_BIN`（否则 `godot`），不可用时打印“请设置 GODOT_BIN”并退出 2。
  - 创建临时用户目录，Windows 设置 `APPDATA`、Linux 设置 `XDG_DATA_HOME`；`finally` 中删除。
  - 无 `.godot/` 时运行 `--headless --import`；导入退出码非 0 或日志含 `FATAL` 时重试，最多 2 次，并打印 `import: retried <n>`（已观察到 Godot 4.6.3 首次全量导入在翻译 CSV 阶段偶发崩溃 `Index p_index = -1 is out of bounds`，重试即成功）；3 次都失败则退出码 2。
  - 冒烟：`--headless --quit-after 5`，失败模式与现 `scripts/smoke_test.ps1` 相同（`SCRIPT ERROR`、`Failed to load script`、`Compile Error`、`Parse Error`、`DataValidator: \d+ JSON schema failure`）。
  - 测试：`tests/*_test.tscn`（排除 `*_visual_capture*`），每个超时 300 秒；退出码非 0 或日志含上述错误模式记为失败；日志写到临时目录，失败时打印末尾 30 行。
  - 结果分类：`PASS`、`FAIL`、`XFAIL`（在清单中且失败）、`XPASS`（在清单中却通过，计为失败）。
  - 打印表格（名称、结果、秒数）与汇总行 `passed=<n> failed=<n> xfail=<n> xpass=<n>`。

- [ ] **Step 2：基线运行**
  Run: 删除 `.godot/` 后 `pwsh tools/run_tests.ps1`
  Expected: 导入完成（可能出现 `import: retried 1`）；冒烟 OK；17 个 `PASS`；`layers: skipped`；退出码 0。

- [ ] **Step 3：自检 FAIL / XFAIL / XPASS 三种路径**
  创建 `tests/zz_runner_selfcheck_test.tscn`（根节点脚本在 `_ready` 中 `get_tree().quit(1)`）。
  Run: `pwsh tools/run_tests.ps1 -Only zz_*` → Expected: `FAIL`，退出码 1。
  在清单加入 `zz_runner_selfcheck_test SELF 自检` → Expected: `XFAIL`，退出码 0。
  把脚本改为 `quit(0)` → Expected: `XPASS`，退出码 1。

- [ ] **Step 4：含空格路径**
  把 `$GODOT_BIN` 复制到名为 `Godot Test 副本` 的临时目录，设置 `GODOT_BIN` 指向它运行 `-Only short_circuit*` → Expected: `PASS`。

- [ ] **Step 5：清理并提交**
  删除自检测试与清单中的自检行；`bash tools/run_tests.sh short_circuit` 也通过（若本机有 bash）。
  ```bash
  git add tools/run_tests.ps1 tools/run_tests.sh tests/expected_failures.txt
  git commit -m "test: add one-command test runner with expected-failure list"
  ```

### Task 2: `SaveIO` 原子写入与备份回退

**Files:**
- Create: `core/save/save_io.gd`
- Test: `tests/save_io_contract_test.gd`, `tests/save_io_contract_test.tscn`

**Interfaces:**
- Produces（`const SAVE_IO = preload("uid://<save_io 的 uid>")  # res://core/save/save_io.gd`）：
  - `static var root: String = "user://"`
  - `static func path(relative: String) -> String`
  - `static func write_json(relative: String, data: Variant) -> Error`
  - `static func read_json(relative: String) -> Dictionary` → `{"status": int, "data": Variant, "source": String}`
  - 状态常量：`const OK_STATUS := 0`, `const MISSING := 1`, `const RECOVERED := 2`, `const CORRUPT := 3`
  - `static func exists(relative: String) -> bool`（主文件或任一备份存在）
  - `static func delete(relative: String) -> void`（删除主文件、`.tmp`、`.bak1`、`.bak2`；保留 `.corrupt-*`）

- [ ] **Step 1：写失败的测试**（测试开始时设置 `SAVE_IO.root = "user://__test__/save_io/"` 并清空该目录，结束时删除）

  | 测试函数 | 断言 |
  |---|---|
  | `test_roundtrip` | 写 `{"a": 1}` 到 `x.json` 后读取：`status == OK_STATUS`、`data.a == 1`、`source == "x.json"` |
  | `test_write_creates_missing_directories` | 写 `slot_3/meta.json` 成功且文件存在 |
  | `test_backups_rotate` | 依次写 v1、v2、v3：主文件为 v3，`.bak1` 为 v2，`.bak2` 为 v1 |
  | `test_corrupt_main_recovers_from_bak1` | 写 v1、v2 后把主文件改为 `"{broken"`：读取 `status == RECOVERED`、`data` 为 v1；目录中出现一个 `x.json.corrupt-*` |
  | `test_all_corrupt_keeps_copy` | 主文件与两个备份都写坏：`status == CORRUPT`、`data == {}`；`.corrupt-*` 存在且内容为原主文件 |
  | `test_stale_tmp_is_ignored_and_replaced` | 预先放一个内容为 `"garbage"` 的 `x.json.tmp`：读取仍返回主文件；再次写入成功、`.tmp` 不存在 |
  | `test_legacy_file_without_backups` | 直接用 `FileAccess` 写主文件（无备份）：读取 `status == OK_STATUS`；写入后出现 `.bak1` 且内容为旧主文件 |
  | `test_missing` | 读取不存在文件：`status == MISSING`、`data == {}` |
  | `test_delete_keeps_corrupt_copies` | 制造 `.corrupt-*` 后 `delete`：主文件与备份消失、`.corrupt-*` 仍在 |
  | `test_unserializable_write_keeps_original` | 原文件为 v1；写入无法 JSON 化的值（含 `Callable`）返回非 `OK` 错误，主文件仍为 v1 |

- [ ] **Step 2：运行确认失败**
  Run: `pwsh tools/run_tests.ps1 -Only save_io*` → Expected: `FAIL`（脚本加载失败：`core/save/save_io.gd` 不存在）。

- [ ] **Step 3：实现 `core/save/save_io.gd`**（`extends RefCounted`，无 `class_name`，不引用任何 autoload）。写入顺序按 spec §2；`.corrupt-<Time.get_unix_time_from_system() 取整>`，同秒冲突时追加 `-2`、`-3`。用 `DirAccess.make_dir_recursive_absolute`、`DirAccess.rename_absolute`、`DirAccess.remove_absolute`。

- [ ] **Step 4：运行确认通过**
  Run: `pwsh tools/run_tests.ps1` → Expected: `save_io_contract_test PASS`，其余 17 个 `PASS`，退出码 0。

- [ ] **Step 5：提交**
  ```bash
  git add core/save/save_io.gd core/save/save_io.gd.uid tests/save_io_contract_test.*
  git commit -m "feat(save): add atomic JSON save IO with rotating backups"
  ```

### Task 3: 接入存档读写并隔离现有测试

**Files:**
- Modify: `run_system/core/meta_progress.gd`（`_meta_path`、`_ensure_slot_dir`、`delete_slot`、`peek_slot`、`save_progress`、`load_progress`、`_migrate_legacy_save`）
- Modify: `run_system/core/run_manager.gd`（`_run_save_path`、`has_run_save`、`save_run`、`load_run`、`clear_run_save`）
- Modify: `run_system/core/settings.gd`（`SAVE_PATH`、`load_settings`、`save_settings`）
- Modify: `tests/base_inventory_ownership_contract_test.gd`, `tests/building_upgrade_runtime_test.gd`, `tests/forge_backpack_contract_test.gd`, `tests/demo_content_contract_test.gd`
- Test: `tests/save_integration_contract_test.gd`, `.tscn`

**Interfaces:**
- Consumes: Task 2 的 `SaveIO`。
- 相对路径约定：`"slot_%d/meta.json"`、`"slot_%d/run_save.json"`、`"settings.json"`。
- 行为约定：`load_progress` 遇到 `CORRUPT` 时以默认值继续（与现状一致）并 `push_warning`；遇到 `RECOVERED` 时 `push_warning` 并立即 `save_progress()` 把恢复的数据写回。

- [ ] **Step 1：写失败的集成测试** `save_integration_contract_test`（开头设置 `SaveIO.root = "user://__test__/integration/"`）

  | 测试函数 | 断言 |
  |---|---|
  | `test_legacy_profile_loads_unchanged` | 用 `FileAccess` 在 `slot_1/meta.json` 写入一份旧格式档案（caps 120、scrap 30、buildings `{"forge": 2}`）；`MetaProgress.set_active_slot(1)` 后 `caps == 120`、`scrap == 30`、`get_building_tier("forge") == 2` |
  | `test_profile_survives_corrupt_main` | 保存两次后把主档写坏；重新加载后 caps 等于第一次保存的值；存在 `meta.json.corrupt-*` |
  | `test_run_save_roundtrip` | 开一局后 `save_run()`，修改 `current_floor` 再 `load_run()`：`current_floor` 恢复为保存时的值 |
  | `test_delete_slot_removes_backups` | `delete_slot(1)` 后 `meta.json`、`.bak1`、`run_save.json` 都不存在 |
  | `test_settings_roundtrip` | 修改 `Settings.music_volume = 0.2` 后 `save_settings()`、再 `load_settings()`：值为 0.2 |

- [ ] **Step 2：运行确认失败**（`-Only save_integration*`）→ Expected: `FAIL`（`root` 覆盖未生效，测试写入了不同路径或读不到 `.bak1`）。

- [ ] **Step 3：改为通过 `SaveIO` 读写**；去掉 `meta_progress.gd` 中“损坏改名 `.bak`”的分支；`delete_slot` 改为对 `meta.json` 与 `run_save.json` 调用 `SaveIO.delete`；`_migrate_legacy_save` 读取 `user://meta.json` 的逻辑保留，写入改用 `SaveIO.write_json`。

- [ ] **Step 4：隔离 4 个现有测试**：在各自开始处设置 `SaveIO.root = "user://__test__/<测试名>/"`，结束时删除该目录。

- [ ] **Step 5：运行全部测试**
  Run: `pwsh tools/run_tests.ps1` → Expected: 全部 `PASS`（17 + 2），退出码 0。

- [ ] **Step 6：提交**
  ```bash
  git add run_system/core/meta_progress.gd run_system/core/run_manager.gd run_system/core/settings.gd tests/
  git commit -m "fix(save): route profile, run and settings saves through SaveIO"
  ```

### Task 4: 一致性测试（预期失败）

**Files:**
- Test: `tests/combat_preview_parity_test.gd/.tscn`, `tests/enemy_intent_parity_test.gd/.tscn`
- Modify: `tests/expected_failures.txt`

**Interfaces:**
- 测试根节点充当战斗场景替身（沿用 `tests/short_circuit_contract_test.gd` 的模式）：提供 `player`、`enemy_container`、`combat_engine`、`turn_manager`、`relic_effect_system`、`equipment_set_system`、`is_game_over`、`show_notification()`、`modify_player_attack_damage()`、`modify_enemy_attack_damage()`。
- 输出格式：每个不一致一行 `MISMATCH <卡牌或敌人:行动> <状态组合> preview=<n> actual=<n>`，最后 `[FAIL] <n> mismatches` 或 `[OK]`。

- [ ] **Step 1：`combat_preview_parity_test`**
  - 卡牌集合：`res://battle_scene/card_info/player/` 中 `play_card.gd` 的 `data_requires_enemy_target(data)` 为真、且含伤害类效果（`deal_damage`、`deal_damage_str_mult`、`scale_damage_by_attacks`、`deal_damage_block_mult`）的卡。
  - 状态组合：`STR ∈ {0, 3}` × `玩家虚弱 ∈ {否, 是}` × `目标易伤 ∈ {否, 是}` × `装填 ∈ {0, 2}`（共 16 种）；玩家格挡固定 5；无遗物、无装备套装。
  - 预览：`battle_scene.gd` 脚本实例（不入树）设置 `player`、`combat_engine`、`turn_manager` 后调用 `_card_preview_damage(card, target)`。
  - 实际：对新的伪目标（HP 999、格挡 0）依次 `await combat_engine._apply_effect(effect, target, player, 1.0, card)` 执行该卡所有伤害类效果，记录目标损失的生命值总和；为避免暴击随机，测试期间把运气相关的暴击概率固定为 0（若 `RunManager.crit_chance()` 读取属性，则令 `luck` 与暴击加成为 0 并断言 `crit_chance() == 0`）。
  - 断言：每个组合 `preview == actual`。
- [ ] **Step 2：运行** `-Only combat_preview_parity*` → Expected: `FAIL`，输出至少包含 `MISMATCH piston_jab STR=3`（S1-01）。
- [ ] **Step 3：`enemy_intent_parity_test`**
  - 行动集合：`res://battle_scene/card_info/enemy/` 中每个敌人（含 `phases` 内）`type ∈ {attack, attack_status, attack_all}` 的行动。
  - 状态组合：`玩家易伤 ∈ {否, 是}` × `敌人虚弱 ∈ {否, 是}` × `减伤遗物 ∈ {无, bulwark_plating}` × `current_act ∈ {1, 2}`（共 16 种）。
  - 意图：`enemy_entity._compute_display_attack(amount)`。
  - 实际：伪玩家（HP 999、格挡 0、记录 `take_damage` 收到的值）上执行 `await enemy_ai._execute_action(enemy, action)`。
  - 断言：每个组合 `intent == actual`。
- [ ] **Step 4：运行** `-Only enemy_intent_parity*` → Expected: `FAIL`，输出至少包含一个奇数伤害 + 易伤的 `MISMATCH`（S4-01）。
- [ ] **Step 5：加入预期失败清单**
  ```
  combat_preview_parity_test  S1-01  瞄准预览与实际结算不一致，阶段 1 修复
  enemy_intent_parity_test    S4-01  敌人意图与实际伤害不一致，阶段 1 修复
  ```
  Run: `pwsh tools/run_tests.ps1` → Expected: 两个 `XFAIL`，其余 `PASS`，退出码 0。
- [ ] **Step 6：提交**
  ```bash
  git add tests/combat_preview_parity_test.* tests/enemy_intent_parity_test.* tests/expected_failures.txt
  git commit -m "test: pin preview/intent damage parity bugs as expected failures"
  ```

### Task 5: 场景 UID 与引用转换为 `uid://`

**Files:**
- Create: `tools/assign_scene_uids.gd`, `tools/godot_refs.py`, `tools/tests/test_godot_refs.py`
- Modify: 缺少 UID 的 31 个 `.tscn`（仅第一行）；`battle_scene/`、`run_system/`、`tests/` 下含脚本/场景路径引用的 `.gd`

**Interfaces:**
- `godot --headless --path . --script res://tools/assign_scene_uids.gd`：为缺少 UID 的场景写入 `uid="uid://…"`（`ResourceUID.create_id()` + `ResourceUID.id_to_text()`，与已有 UID 去重），打印 `assigned <n>`。
- `python tools/godot_refs.py convert [--dry-run]`：打印 `rewritten <n> references in <m> files`；遇到无 `.uid` 的脚本或无 UID 的场景时以退出码 1 列出并不写入。
- `python tools/godot_refs.py check`：列出 `battle_scene/`、`run_system/`、`tests/`、`core/` 中残留的 `"res://….gd"`/`"res://….tscn"` 字面量；有残留退出码 1。

- [ ] **Step 1：写 `godot_refs.py` 的单元测试**（`python -m unittest tools/tests/test_godot_refs.py`，用临时目录构造小项目）

  | 测试 | 断言 |
  |---|---|
  | `test_preload_rewritten_with_comment` | `const A = preload("res://a/x.gd")` → `const A = preload("uid://abc")  # res://a/x.gd` |
  | `test_scene_const_and_change_to_rewritten` | `const P := "res://ui/m.tscn"` 与 `change_to("res://ui/m.tscn")` 都改为 UID |
  | `test_comments_untouched` | `# see res://a/x.gd` 不变 |
  | `test_concatenated_paths_untouched` | `"res://data/%s.json" % id`、`DIR + "x.gd"` 不变 |
  | `test_missing_uid_reports_and_writes_nothing` | 引用一个无 `.uid` 的脚本：退出码 1，文件内容不变 |
  | `test_idempotent` | 连续运行两次，第二次 `rewritten 0` |
  | `test_check_lists_leftovers` | 残留一处时 `check` 退出码 1 且输出文件与行号 |

- [ ] **Step 2：运行确认失败** → Expected: `ModuleNotFoundError` / 测试失败。
- [ ] **Step 3：实现 `godot_refs.py`**（正则只匹配完整字符串字面量 `"res://[^"%+]+\.(gd|tscn)"`，并排除 `#` 之后的内容；UID 来源：`<脚本>.uid` 文件内容、场景首行 `uid="…"`）。
- [ ] **Step 4：单元测试通过** → Expected: 7 passed。
- [ ] **Step 5：生成场景 UID**
  Run: `$GODOT_BIN --headless --path . --script res://tools/assign_scene_uids.gd` → Expected: `assigned 31`；`git diff --stat` 只显示 `.tscn` 各 1 行改动。随后 `$GODOT_BIN --headless --path . --import`。
- [ ] **Step 6：转换并验证**
  Run: `python tools/godot_refs.py convert` → Expected: `rewritten <n> references …`，退出码 0。
  Run: `python tools/godot_refs.py check` → Expected: 退出码 0。
  Run: `pwsh tools/run_tests.ps1` → Expected: 全部 `PASS` + 2 个 `XFAIL`，退出码 0。
- [ ] **Step 7：分两个提交**
  ```bash
  git add tools/assign_scene_uids.gd tools/godot_refs.py tools/tests/ $(git diff --name-only -- '*.tscn')
  git commit -m "chore: assign uids to scenes and add reference conversion tool"
  git add -u battle_scene run_system tests
  git commit -m "refactor: reference scripts and scenes by uid"
  ```

### Task 6: 工具脚本与 autoload 目录整理

**Files:**
- Move: `scripts/*` → `tools/`；`battle_scene/scripts/*.py` → `tools/`
- Move: `run_system/core/{settings,audio_manager,tooltip,scene_transition}.gd` 及 `.uid` → `autoload/`
- Modify: `project.godot`（4 个 autoload 路径）、`tools/gen_card_ui_assets.py`、`tools/gen_hud_assets.py`、`tools/gen_ui_polish_assets.py`（项目根层级）、`docs/PROJECT_STRUCTURE.md`、`docs/README.md`、`docs/project-rules.md`、`docs/steam-demo-build.md`、`tools/smoke_test.ps1`/`.sh`（注释中的用法路径）

**Interfaces:**
- Consumes: Task 5 后所有脚本引用均为 `uid://`，移动不需要改代码。

- [ ] **Step 1：`git mv` 移动工具脚本**；把原 `battle_scene/scripts/` 中脚本的 `ROOT` 改为与 `tools/` 下其它脚本相同的层级；`python tools/i18n_audit.py` 与 `python tools/check_missing_art.py` 正常运行（退出码与移动前相同）。
- [ ] **Step 2：`git mv` 移动 4 个 autoload 及其 `.uid`**；更新 `project.godot` 中对应 4 行；更新 `tests/scene_transition_sts2_contract_test.gd` 中残留的路径（若 Task 5 已转为 UID 则无需改）。
- [ ] **Step 3：更新文档路径**：`scripts/` → `tools/`；导出排除规则 `scripts/*` → `tools/*`；`PROJECT_STRUCTURE.md` 增加 `autoload/`、`core/save/` 条目。
- [ ] **Step 4：验证**
  Run: `$GODOT_BIN --headless --path . --import` 后 `pwsh tools/run_tests.ps1` → Expected: 全部 `PASS` + 2 个 `XFAIL`，退出码 0。
  Run: `python tools/godot_refs.py check` → Expected: 退出码 0。
- [ ] **Step 5：提交**
  ```bash
  git add -A tools scripts battle_scene/scripts autoload run_system/core project.godot tests
  git add docs/PROJECT_STRUCTURE.md docs/README.md docs/project-rules.md docs/steam-demo-build.md
  git status --short   # 确认未加入导入生成的 docs/art/previews/*.import
  git commit -m "refactor: move tool scripts to tools/ and UI-independent autoloads to autoload/"
  ```

### Task 7: 分层规则与自动检查

**Files:**
- Create: `docs/conventions/architecture-layers.md`, `tools/check_layers.py`, `tools/tests/test_check_layers.py`
- Modify: `AGENTS.md`（新增“代码结构”小节，约 10 行，链接规则文档）、`docs/PROJECT_STRUCTURE.md`

**Interfaces:**
- `python tools/check_layers.py`：输出 `layers: ok` 或逐条 `layers: <文件>:<行> <规则>`；有违规退出码 1。Task 1 的入口脚本据此判定。
- 规则 ID：`L1` `core/` 不得引用 `ui`/`run_system/ui`/`battle_scene/ui` 路径；`L2` `core/` 不得使用 `get_tree()`、`current_scene`、`get_node(`；`L3` `content/` 下不得有 `.gd`；`L4` 调用 `godot_refs.py check` 的结果。

- [ ] **Step 1：写单元测试**（临时目录构造违规文件）：`test_core_ui_reference_flagged`（L1）、`test_core_scene_tree_flagged`（L2）、`test_content_script_flagged`（L3）、`test_clean_tree_ok`（退出码 0）。
- [ ] **Step 2：运行确认失败**；**Step 3：实现**；**Step 4：单元测试通过**（4 passed）。
- [ ] **Step 5：写规则文档**：目标结构（spec §6 与审查报告 11 第 3 节一致）、依赖规则表、引用约定（`uid://` + 行尾路径注释；新文件用编辑器或 `git mv` 连同 `.uid` 移动；`class_name` 只用于需要类型标注的核心类型）、“禁止 class_name”旧注释在修改相关文件时更新。
- [ ] **Step 6：整体验证**
  Run: `pwsh tools/run_tests.ps1` → Expected: `layers: ok`、全部 `PASS` + 2 个 `XFAIL`，退出码 0。
- [ ] **Step 7：提交**
  ```bash
  git add docs/conventions/architecture-layers.md tools/check_layers.py tools/tests/test_check_layers.py AGENTS.md docs/PROJECT_STRUCTURE.md
  git commit -m "docs: add architecture layering rules with automated check"
  ```

### Task 8: 收尾验证

- [ ] **Step 1**：`pwsh tools/run_tests.ps1` 完整运行，记录输出（期望：冒烟 OK、19 个 `PASS`、2 个 `XFAIL`、`layers: ok`、退出码 0）。
- [ ] **Step 2**：对比运行前后真实用户目录 `%APPDATA%/Godot/app_userdata/CardFramework` 的文件清单与修改时间，确认无变化。
- [ ] **Step 3**：`git log --oneline main..HEAD` 列出本阶段提交（应为 Task 1–7 的 8 个提交 + spec/plan 提交）；`git diff --stat main..HEAD` 中没有 `addons/`、素材或内容 JSON 的改动（除 31 个场景首行）。
- [ ] **Step 4**：写 `docs/superpowers/plans/2026-10-22-phase0-safety-net.md` 末尾的“执行记录”：每个任务的结果、做出的裁定、未完成项与手动试玩清单（spec 成功标准 5）。

---

## 执行记录（2026-10-22，Native 执行）

环境：Godot 4.6.3-stable 官方 win64（`C:\Users\Jerry\Tools\Godot_v4.6.3\`，SHA512 已校验）；Windows PowerShell 5.1（无 pwsh）；Python 3.13。

| 任务 | 结果 | 提交 |
|---|---|---|
| 1 测试入口 | 完成；自检 FAIL/XFAIL/XPASS、含空格与中文路径均通过；执行中发现并修复超时只杀外壳进程的问题 | `50c1398`、`31ac148` |
| 2 SaveIO | 完成；10 项契约测试 | `a2aa86a` |
| 3 接入存档 | 完成；5 项集成测试；4 个写存档的测试改用独立存档根目录 | `769acd4` |
| 4 一致性测试 | 完成；预期失败：瞄准预览 8 处不一致（均为 `piston_jab` STR=3，如 预览 7 / 实际 4）；敌人意图 605 处不一致（取整、减伤遗物、幕倍率） | `9dca783` |
| 5 uid 转换 | 完成；36 个场景补 uid（仅首行）；209 处引用转为 `uid://`；`extends`、读取源码与 `resource_path` 比较保留路径并标注 `# path-ok` | `3d34e38`、`430f4fb` |
| 6 目录整理 | 完成；`scripts/`、`battle_scene/scripts/` → `tools/`（生成脚本输出目录前后一致）；4 个 autoload → `autoload/`；新增 `godot_refs.py sync-comments` | `5f5964a` |
| 7 分层规则 | 完成；`docs/conventions/architecture-layers.md`、`tools/check_layers.py`（L1–L4）；完整运行同时跑工具单元测试 | `f6eb87c` |
| 8 收尾 | 完整运行：冒烟 ok、19 PASS、2 XFAIL、工具单元测试 ok、`layers: ok`、退出码 0；真实用户目录 73 个文件修改时间与大小全部不变；分支未改动 `addons/`、素材、内容 JSON；32 个现有场景仅首行变化 | 本提交 |

与计划的偏差（均有裁定，详见各提交说明）：
- 计划中的 `pwsh` 改为 `powershell -NoProfile -ExecutionPolicy Bypass -File`（本机无 pwsh，脚本兼容 PS 5.1）。
- Godot 4.6.3 不支持 `extends "uid://…"`，成功标准 4 解释为“除 `extends`、注释与 `# path-ok` 标注外 0 处路径引用”。
- 测试入口默认超时由 300 秒改为 120 秒；新增 `tests/support/test_save_root.gd`、`godot_refs.py --dirs` 与 `sync-comments`。
- 工具 `i18n_audit.py` 在 Windows 重定向输出时因 cp1252 编码失败（主目录原脚本同样失败，非本分支引入）；设置 `PYTHONIOENCODING=utf-8` 后输出与主目录一致。未修复。

未完成 / 需要人工完成：
- **手动试玩**（spec 成功标准 5）：主菜单 → 选槽 → 开局 → 一场战斗 → 地图 → 退出并“继续” → 修改设置后重启仍保留。自动化无法覆盖界面交互。
- 本机导出预设（`export_presets.cfg` 不在仓库）中的排除规则需手动把 `scripts/*` 改为 `tools/*`。
- 全量导入偶发崩溃（Godot 内部 `Index p_index = -1`）未定位根因，入口脚本以重试兜底。
