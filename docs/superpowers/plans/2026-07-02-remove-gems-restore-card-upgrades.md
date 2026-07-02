# 删宝石 + 卡牌升级回归 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use `- [ ]`. **每阶段 smoke gate + 本地 commit,不 push。** 中文回复用户;代码/标识符/JSON 英文。

**Goal:** 删除宝石系统,让局内卡牌升级回归作为唯一卡成长机制(混合模型:公式兵底 + 关键卡手写)。

**Architecture:** 新增纯函数 helper `card_upgrade.gd`(`resolve` + `formula`);升级是 `player_deck` 条目上的 `upgraded: bool`,建卡时(`deck_manager.reset_deck`)按需用 `play_card.set_card_data()` 套升级态。先让升级机制跑通(Phase 1-3),再删宝石(Phase 4),保证全程有卡成长。

**Tech Stack:** Godot 4.6 GDScript;无 pytest——验证 = `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`(必传 GODOT_BIN,baked `_console.exe` 无效;尾部须 `all schemas passed` + `boot clean`)+ headless `mcp__godot__run_script`/临时 SceneTree 脚本(read-only,不污染真实 slot,见 spec §6)+ `gdscript-reviewer` subagent。`class_name` 禁用,新脚本 `preload`(ADR-0006)。

**关键坐标(执行者先读 spec `docs/superpowers/specs/2026-07-02-remove-gems-restore-card-upgrades-design.md`,再读这些):**
- `battle_scene/deck_manager.gd:134` `reset_deck()` — 从 `RunManager.player_deck` 建卡;当前建卡后 `set_meta("uid")`/`set_meta("gems")`/`_refresh_gem_socket()`。升级注入点。
- `battle_scene/play_card.gd:178` `set_card_data(data)` — 设 `card_info` + 重建 cost/description label + `_refresh_gem_socket()`。升级重刷视觉的唯一方法。`_build_gem_socket`(~99)/`_gem_socket_node`(42)/`_refresh_gem_socket`(217) 是宝石视觉,Phase 4 删。
- `battle_scene/battle_scene.gd:714-716` — Boss loot `RunManager.gem_pool()` 授予宝石。Phase 4 删,留遗物。
- `run_system/core/run_manager.gd` — `player_deck`(56)、`gem_inventory`(117)、`_gem_cache`(121)、`start_new_run`(669)、`add_card_to_deck`(805,写 `"gems":[]`)、`add_gem_to_backpack`(1102)、`backpack_gem_ids`(1116)、`socket_gem`(1859)、`gem_pool`、`_find_gem_cell`、`gem_inventory.clear()`(689)、legacy 迁移(~2157)。
- `run_system/ui/map_scene.gd:831` `_open_rest_choice()` — 回血按钮 + 「挖矿得宝石」按钮(~898)。
- `run_system/ui/loot_reward.gd` — 精英 `gem_draft` append(~129)。
- `battle_scene/data_validator.gd` — gem schema + gem ALLOWED。
- `scripts/gen_catalog_html.py` + `docs/catalog_html/` — catalog 生成器。
- 卡数据:`battle_scene/card_info/player/*.json`(54 张)。

---

## Phase 1 — 升级核心:card_upgrade.gd + validator 支持

### Task 1.1: `card_upgrade.gd`(resolve + formula 纯函数)

**Files:**
- Create: `run_system/core/card_upgrade.gd`

- [ ] **Step 1: 写 helper**

```gdscript
## Card-upgrade resolver (in-run). Pure functions, no side effects — safe to unit
## test headless. `resolve(base)` returns the UPGRADED effective card data for a
## base card-info dict. Bespoke path: a card JSON may carry an optional `upgrade`
## block ({cost?, title?, description?, effects?}) that overrides those fields
## (effects = full replacement). Formula path (no `upgrade` block): bump known
## numeric fields per effect type. Cost is only ever changed by the bespoke block.
## No `class_name` (ADR-0006) — used via preload.
extends RefCounted


## Return a deep-copied, upgraded version of `base`. `base` is un-mutated.
static func resolve(base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	var up: Dictionary = base.get("upgrade", {})
	if typeof(up) != TYPE_DICTIONARY:
		up = {}
	if up.has("cost"):
		result["cost"] = int(up["cost"])
	if up.has("title"):
		result["title"] = str(up["title"])
	if up.has("description"):
		result["description"] = str(up["description"])
	if up.has("effects"):
		result["effects"] = (up["effects"] as Array).duplicate(true)
	else:
		result["effects"] = formula(base.get("effects", []))
	return result


## Generic numeric bump for cards without a bespoke `upgrade.effects`. ONLY the
## unambiguously-beneficial effect types are bumped; scaling / cost / self-debuff
## effects are deliberately excluded so they route to a bespoke `upgrade` block
## (Phase 5 audit). Field names match the real card JSON: damage/block/stat use
## `amount`; status applies use `stacks`.
static func formula(effects: Array) -> Array:
	var out: Array = effects.duplicate(true)
	for eff in out:
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		match str(eff.get("type", "")):
			"deal_damage", "deal_damage_all":
				eff["amount"] = int(eff.get("amount", 0)) + 2
			"gain_block":
				eff["amount"] = int(eff.get("amount", 0)) + 3
			"gain_strength", "gain_dexterity", "gain_luck", \
			"gain_intelligence", "gain_energy":
				eff["amount"] = int(eff.get("amount", 0)) + 1
			# Enemy-facing status only (apply_status / _all). apply_status_SELF is
			# excluded — it may be a drawback (self weak/frail on cost cards) → bespoke.
			"apply_status", "apply_status_all":
				eff["stacks"] = int(eff.get("stacks", 0)) + 1
			"draw_cards":
				eff["amount"] = int(eff.get("amount", 0)) + 1
			_:
				pass
	return out


## True when `resolve()` would change something (card is meaningfully upgradeable).
## Used by the validator coverage warning and the upgrade modal (grey out no-op).
static func is_upgradeable(base: Dictionary) -> bool:
	if base.has("upgrade"):
		return true
	var before: Array = base.get("effects", [])
	return formula(before) != before
```

- [ ] **Step 2: 冒烟(新文件 parse 干净)**
Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 3: headless 单测(临时脚本,验证后删)**
写临时 `scratchpad` 脚本用 `mcp__godot__run_script`(`extends RefCounted` + `func execute(scene_tree)`):
```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
	var CU = load("res://run_system/core/card_upgrade.gd")
	# formula: deal_damage +2
	var strike = {"cost": 1, "effects": [{"type": "deal_damage", "amount": 3}]}
	var up = CU.resolve(strike)
	assert(up["effects"][0]["amount"] == 5, "formula dmg")
	assert(strike["effects"][0]["amount"] == 3, "base un-mutated")
	# bespoke: full override + cost
	var bespoke = {"cost": 1, "upgrade": {"cost": 0, "effects": [{"type": "deal_damage", "amount": 9}]}}
	var bu = CU.resolve(bespoke)
	assert(bu["cost"] == 0 and bu["effects"][0]["amount"] == 9, "bespoke")
	# is_upgradeable
	assert(CU.is_upgradeable(strike) == true, "strike upgradeable")
	assert(CU.is_upgradeable({"effects": [{"type": "exhaust_self"}]}) == false, "no-op not upgradeable")
	return "CARD_UPGRADE_OK"
```
Expected debug output contains `CARD_UPGRADE_OK`, no assert failure.

- [ ] **Step 4: commit**
```bash
git add run_system/core/card_upgrade.gd
git commit -m "feat(cards): card_upgrade.gd resolver (bespoke override + formula fallback)"
```

### Task 1.2: validator 支持 `upgrade` 块

**Files:**
- Modify: `battle_scene/data_validator.gd`(卡校验函数,先 grep `func .*validate.*card` / 卡 effects 校验循环定位)

- [ ] **Step 1: 定位卡校验** — `grep -n 'validate_card\|effects\|ALLOWED_EFFECT' battle_scene/data_validator.gd`,找到逐张卡校验 + effects 循环的函数。

- [ ] **Step 2: 加 upgrade 块校验** — 在单卡校验里,若卡有 `"upgrade"`:校验它是 Dictionary;若含 `cost` 须 int;`title`/`description` 须 String;若含 `effects` 须 Array 且**每个 effect 走与主 effects 相同的 `ALLOWED_*` 校验**(复用现有 effect 校验子函数,别复制逻辑)。非法则 `push_error`(shipped 数据 fail loud)。

- [ ] **Step 3: 加升级覆盖率 warn** — 单卡校验末尾:`if not CardUpgrade.is_upgradeable(card_dict): push_warning("Card '%s' has no bespoke upgrade and no formula-bumpable effect — upgrade is a no-op" % name)`。文件顶部 `const CARD_UPGRADE = preload("res://run_system/core/card_upgrade.gd")`。

- [ ] **Step 4: 冒烟** — 会打印当前所有不可升级卡的 warn(Phase 5 消化)。确认 `all schemas passed` 仍在(warn 不 fail)。

- [ ] **Step 5: commit**
```bash
git add battle_scene/data_validator.gd
git commit -m "feat(validator): validate card upgrade block + warn on un-upgradeable cards"
```

---

## Phase 2 — 战斗中套用升级

### Task 2.1: deck_manager 建卡注入 + play_card 重刷

**Files:**
- Modify: `battle_scene/deck_manager.gd:134-153`(`reset_deck`)
- Reference: `battle_scene/play_card.gd:178`(`set_card_data`)

- [ ] **Step 1: reset_deck 注入升级** — 文件顶部加 `const CARD_UPGRADE = preload("res://run_system/core/card_upgrade.gd")`。把建卡分支改成(保留现有 uid/gems meta 行,Phase 4 再删 gems 行):
```gdscript
		var card = card_factory.create_card(card_name, deck)
		if card and typeof(item) == TYPE_DICTIONARY:
			card.set_meta("uid", item.get("uid", ""))
			card.set_meta("gems", item.get("gems", []))  # Phase 4 removes
			if item.get("upgraded", false) and card.has_method("set_card_data"):
				# Re-apply the upgraded card_info so cost/desc/effects all refresh.
				card.set_card_data(CARD_UPGRADE.resolve(card.card_info))
			if card.has_method("_refresh_gem_socket"):
				card._refresh_gem_socket()
```

- [ ] **Step 2: 冒烟** — `all schemas passed` + `boot clean`。

- [ ] **Step 3: headless 验证升级实卡** — 临时脚本:构造 `RunManager.is_run_active=true` + 一张 `upgraded=true` 的 strike 进 `player_deck` → 触发一次 `reset_deck`(或直接调 `card_factory.create_card("strike", deck)` 后手动 `set_card_data(CARD_UPGRADE.resolve(card.card_info))`)→ 断言 `card.card_info["effects"][0]["amount"] == 5`。read-only(不 save)。Expected `UPGRADE_APPLIED_OK`。

- [ ] **Step 4: commit**
```bash
git add battle_scene/deck_manager.gd
git commit -m "feat(cards): apply per-instance upgrade when building the battle deck"
```

---

## Phase 3 — 获得升级(rest 篝火 + 选卡 modal)

### Task 3.1: `card_upgrade_modal.gd`(选一张未升级卡)

**Files:**
- Create: `run_system/ui/card_upgrade_modal.gd`
- Translations: `assets/translations/ui_run_map.csv`(或现有 rest/loot 所在 CSV,先 grep `UI_MAP_REST` 定位)

- [ ] **Step 1: modal 脚本** — 全屏遮罩 + 牌组网格(读 `RunManager.player_deck`),每张卡渲染;`CARD_UPGRADE.is_upgradeable(base) == false` 或 `entry.get("upgraded", false) == true` 的**置灰不可选**;点可选卡 → `entry["upgraded"] = true` → `emit_signal("upgraded")` → `queue_free()`。顶部 `const CARD_UPGRADE = preload("res://run_system/core/card_upgrade.gd")`。用 `RunManager.get_card_info(card_id)`/card factory 取卡面数据渲染(复用 deck viewer 的渲染法——先读 `run_deck_viewer_modal.gd` 的卡渲染,别重造)。新翻译键:`UI_UPGRADE_MODAL_TITLE`(Upgrade a Card / 升级一张卡)、`UI_UPGRADE_MODAL_HINT`(Pick a card to upgrade / 选一张卡升级)、`UI_UPGRADE_ALREADY`(Upgraded / 已升级)。

- [ ] **Step 2: 冒烟** — parse 干净。

- [ ] **Step 3: commit**
```bash
git add run_system/ui/card_upgrade_modal.gd assets/translations/
git commit -m "feat(ui): card_upgrade_modal — pick an un-upgraded deck card to upgrade"
```

### Task 3.2: rest 篝火加「升级」选项

**Files:**
- Modify: `run_system/ui/map_scene.gd`(`_open_rest_choice` ~831)
- Translations: rest CSV(`UI_MAP_REST_UPGRADE_BTN`)

- [ ] **Step 1: 加升级按钮** — 在 `_open_rest_choice` 的按钮 HBox 里,回血按钮之后加第三个按钮「升级一张卡」(`UI_MAP_REST_UPGRADE_BTN`,en `Upgrade a Card` / zh `升级一张卡`)。pressed → 关 rest modal(**不释放** `_node_click_pending`)→ 打开 `card_upgrade_modal`;modal 的 `upgraded`/关闭信号 → `_show_popup(升级成功)` + `_node_click_pending = false`。若 modal 被取消(未选)→ 也要释放 guard(避免卡死)。preload const:`const CARD_UPGRADE_MODAL = preload("res://run_system/ui/card_upgrade_modal.gd")`。
  - 注意:此刻「挖矿得宝石」按钮**仍在**(Phase 4 才删),rest 暂时三选一(回血/挖矿/升级),可接受。

- [ ] **Step 2: 冒烟 + headless** — parse 干净;临时脚本实例化 `card_upgrade_modal`、断言构建无错。

- [ ] **Step 3: commit**
```bash
git add run_system/ui/map_scene.gd assets/translations/
git commit -m "feat(map): rest campfire can upgrade a card (smith)"
```

---

## Phase 4 — 删除宝石(数据 + 逻辑 + UI + 迁移)

### Task 4.1: 删宝石数据 + run_manager 逻辑 + 迁移

**Files:**
- Delete: `run_system/data/gems/`(整目录 + `.uid`)
- Modify: `run_system/core/run_manager.gd`

- [ ] **Step 1: grep 全量宝石引用**（先摸清爆炸半径）
`grep -rni 'gem' run_system battle_scene --include=*.gd | grep -v '#'` + `grep -rli 'gem' run_system/data battle_scene/card_info`（遗物/事件/工具 JSON 里的宝石引用)。列清单。

- [ ] **Step 2: run_manager 删函数/状态** — 删 `gem_inventory`、`_gem_cache`、`add_gem_to_backpack`、`backpack_gem_ids`、`_find_gem_cell`、`socket_gem`、`gem_pool`、gem 数据加载/缓存 fn;`gem_inventory.clear()`(689)行删;`add_card_to_deck` 的 `card_data` 去掉 `"gems": []`(改 `{"uid": uid, "card_id": card_id}`)。

- [ ] **Step 3: load 迁移(容错、不崩)** — 在存档 load 反序列化 player_deck / backpack 处:读到旧条目有 `gems` key → 丢弃该 key(不建 socket);backpack 里 `{"kind":"gem",...}` 的格 → 置 null(空格);旧 `gem_inventory` 数组 → 忽略。全程**不 push_error**(旧 key 存在是正常迁移)。`upgraded` 缺省 false(deck 条目读不到就 false)。

- [ ] **Step 4: 删数据目录**
```bash
git rm -r run_system/data/gems
```
(若有 `.uid` 一并删。)

- [ ] **Step 5: 冒烟** — `all schemas passed` + `boot clean`(注意:validator 此时可能仍引用 gem schema → 若报错,顺手在本 task 或 4.4 处理;理想是 4.4 先行或本步一起改 validator)。

- [ ] **Step 6: commit**
```bash
git add run_system/core/run_manager.gd
git rm -r run_system/data/gems
git commit -m "refactor(run): remove gem inventory/socket logic + migrate old saves (strip gems)"
```

### Task 4.2: 删宝石 UI(play_card socket / deck_manager meta / deck viewer 入口)

**Files:**
- Modify: `battle_scene/play_card.gd`、`battle_scene/deck_manager.gd`、`run_system/ui/run_deck_viewer_modal.gd`(socket 入口,grep 确认)、`run_system/ui/window/character_window.gd`(若渲染 gem 背包格)

- [ ] **Step 1: play_card 删 socket 视觉** — 删 `_gem_socket_node`(42)、`_build_gem_socket`(~99)及其在 `_ready` 的调用、`_refresh_gem_socket`(217)及 `set_card_data` 里对它的调用。

- [ ] **Step 2: deck_manager 去 gems meta** — `reset_deck` 删 `card.set_meta("gems", ...)` 行 + `_refresh_gem_socket` 调用块(Phase 2 保留的临时行)。

- [ ] **Step 3: deck viewer / 顶栏 socket 入口** — grep `socket_gem\|_socket\|gem` 于 `run_deck_viewer_modal.gd` + 顶栏 + `character_window.gd`;删宝石嵌入按钮/网格/背包 gem 格渲染分支。留意别删到升级或装备逻辑。

- [ ] **Step 4: 冒烟 + headless** — 建卡不再引用 gem;`boot clean`。

- [ ] **Step 5: commit**
```bash
git add battle_scene/play_card.gd battle_scene/deck_manager.gd run_system/ui/run_deck_viewer_modal.gd run_system/ui/window/character_window.gd
git commit -m "refactor(ui): remove gem socket UI from cards, deck viewer, character window"
```

### Task 4.3: 删奖励侧宝石(rest 挖矿 / 精英 gem_draft / Boss 宝石)

**Files:**
- Modify: `run_system/ui/map_scene.gd`(rest 挖矿按钮)、`run_system/ui/loot_reward.gd`(精英 gem_draft + gem_draft 处理分支)、`battle_scene/battle_scene.gd:714-716`(Boss 宝石)

- [ ] **Step 1: rest 删挖矿** — `_open_rest_choice` 删「挖矿得宝石」按钮(`gems_btn` ~898)及其 handler;rest 变回血/升级二选一。

- [ ] **Step 2: loot 删精英 gem_draft** — 删精英 append `gem_draft` 的 block(~129)+ 任何 `gem_draft` 类型的领取处理分支;精英回到卡 + 装备几率。

- [ ] **Step 3: battle 删 Boss 宝石** — `_victory` 里 `RunManager.gem_pool()` 授予块(714-716)删除,**保留遗物授予**。

- [ ] **Step 4: 冒烟 + headless** — loot_reward 实例化构建无错(精英/普通/boss 三种 node_type 各构建一次断言无 gem 分支)。

- [ ] **Step 5: commit**
```bash
git add run_system/ui/map_scene.gd run_system/ui/loot_reward.gd battle_scene/battle_scene.gd
git commit -m "refactor(rewards): drop gem sources (rest mining, elite gem draft, boss gem)"
```

### Task 4.4: validator 去 gem schema

**Files:**
- Modify: `battle_scene/data_validator.gd`

- [ ] **Step 1** — 删 gem schema 校验函数 + gem ALLOWED 触发/效果列表 + boot 校验里对 `data/gems` 的扫描调用。保留 Phase 1.2 的 upgrade 校验。

- [ ] **Step 2: 冒烟** — `all schemas passed`(不再有 gem 引用)。

- [ ] **Step 3: 迁移单测** — 临时脚本:构造带 `gems`/`{"kind":"gem"}` 背包格/`gem_inventory` 的假存档 dict → 走 load 迁移路径 → 断言无宝石残留、`upgraded` 缺省 false、不崩。**read-only,用 spare slot 或纯内存,不写真实 slot**(见 [[mcp-verify-no-save-pollution]])。Expected `GEM_MIGRATION_OK`。

- [ ] **Step 4: commit**
```bash
git add battle_scene/data_validator.gd
git commit -m "refactor(validator): remove gem schema + validation"
```

---

## Phase 5 — 升级覆盖率审计 + 手写 bespoke

### Task 5.1: 审计 54 张卡,补手写 upgrade

**Files:**
- Modify: `battle_scene/card_info/player/*.json`(仅需 bespoke 的卡)
- Translations: 若升级改描述文案,加 `_UPGRADE` 描述键或直接内联 `description`

- [ ] **Step 1: 列不可升级卡** — 跑冒烟看 Phase 1.2 的 warn 输出(或临时脚本遍历 54 卡跑 `CardUpgrade.is_upgradeable`),得出公式覆盖不到的卡清单(纯触发/无数值:如 `exhaust_self`-only、纯 `draw`-无 amount、状态倍率类如 `charged_shot`/`limit_break`/`瞄准伤口`)。

- [ ] **Step 2: 先看 catalog 再改**(项目硬规则)— 打开 `docs/catalog_html/cards.html` 对照现有数值/稀有度/功率曲线,给每张需要 bespoke 的卡设计升级态。**升级方向优先加强缩放/个性**(charged_shot+ 改 3×、combat_stim+ 多 +1 力量、瞄准伤口+ 提高倍率或降费、limit_break+ 降费或不 exhaust)。逐卡加内联 `upgrade` 块(§spec 3.2 形态)。

- [ ] **Step 3: content-balance subagent** — 对新增的 bespoke 升级态跑 `content-balance` 检查功率曲线离群。

- [ ] **Step 4: 冒烟** — warn 归零(所有卡可升级);`all schemas passed`。

- [ ] **Step 5: commit**
```bash
git add battle_scene/card_info/player/ assets/translations/
git commit -m "content(cards): bespoke upgrade blocks for scaling/special cards (full upgrade coverage)"
```

---

## Phase 6 — catalog + 文档 + 最终验证

### Task 6.1: catalog 渲染升级态 + 去 gems 页

**Files:**
- Modify: `scripts/gen_catalog_html.py`

- [ ] **Step 1: 渲染升级态** — 卡片渲染时,用与游戏一致的逻辑(移植 `card_upgrade.formula` + bespoke `upgrade` 覆盖到 python)展示「基础 → 升级后」的 cost/描述/effects 差异(如折叠区或并排)。**去掉 gems 页生成**(不再扫 `run_system/data/gems`)。

- [ ] **Step 2: 重生成 + 一致性**
```bash
python scripts/gen_catalog_html.py
```
人工/脚本比对:升级态与 JSON 一致;`gems.html` 消失;`index.html` 左栏无宝石 tab。

- [ ] **Step 3: commit**
```bash
git add scripts/gen_catalog_html.py docs/catalog_html/
git commit -m "docs(catalog): render card upgrade state; drop gems page"
```

### Task 6.2: 文档同步 + 最终整体验证

**Files:**
- Modify: `docs/PRD.md`、`docs/PROJECT_STRUCTURE.md`、`docs/conventions/data-files.md`(卡 `upgrade` 块约定)

- [ ] **Step 1: PRD** — 删宝石系统段;写卡牌成长 = 局内升级(混合模型、rest 篝火/精英无、Boss 遗物);标注"力量流档案扩充"留待将来。

- [ ] **Step 2: PROJECT_STRUCTURE** — 删 `run_system/data/gems`、宝石 UI 提及;加 `run_system/core/card_upgrade.gd`、`run_system/ui/card_upgrade_modal.gd`;`player_deck` 条目 `upgraded` 字段。

- [ ] **Step 3: conventions/data-files** — 卡 JSON 可选 `upgrade` 块的 schema 约定(bespoke override + 公式兵底规则表)。

- [ ] **Step 4: gdscript-reviewer subagent** — 对全批 `.gd` 改动跑一遍(freed-node / Variant / falsy-zero / 迁移健壮性 / 升级视觉刷新)。

- [ ] **Step 5: 最终 grep + 冒烟**
```bash
grep -rni 'gem' run_system battle_scene --include=*.gd | grep -v '#'   # 期望:仅注释/历史,零活引用
GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh
```
Expected: 零活 gem 引用;`all schemas passed` + `boot clean`。

- [ ] **Step 6: commit**
```bash
git add docs/
git commit -m "docs: sync PRD/PROJECT_STRUCTURE/conventions for gem removal + card upgrades"
```

---

## 自查 / 风险守则
- **先 grep 后删**;`class_name` 禁新增;分阶段本地 commit、**不 push**;translations 改后如需即时生效跑 `godot --headless --import`。
- 顺序保证全程有卡成长(升级 Phase 1-3 先落,宝石 Phase 4 后删)。
- 迁移必须容错读旧 key、不崩、不污染真实 slot。
- 升级是**局内**:`start_new_run` 重建 deck 时 `upgraded` 天然为 false(`add_card_to_deck` 不写该字段);确认无残留跨局。
- cached_card_factory 缓存的是**基础**卡数据;升级只在实例 `set_card_data` 时叠加,**别写回缓存**(deck_manager 用的是 create_card 产出的独立 node,安全)。
