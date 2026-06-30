# 发现机制(Discover)实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加入炉石式「发现」—— 打出发现牌弹三选一,选中的牌凭空进当前手牌(本场战斗),候选按类型/tag 筛,可选本场 0 费。

**Architecture:** 新 `discover` effect 由 `combat_engine` 处理,`await` 一个全新的 `DiscoverModal`(暗化遮罩 + 三张放大的 `PlayCard` 候选,不套奖励界面骨架);选中 → `deck_manager.add_card_to_hand` + 可选 `cost_override=0` meta。候选由无状态 `discover_pool.gd` 从解锁卡池筛出。

**Tech Stack:** Godot 4.6 / GDScript;数据驱动 JSON 卡牌;`class_name` 禁用(ADR-0006)用 `preload`;验证 = `bash scripts/smoke_test.sh`(传 `GODOT_BIN="C:/Program Files/Godot/Godot.exe"`)+ godot MCP。

**验证约定(本项目没有 pytest):** 每个任务末尾跑 smoke gate;含 UI/行为的任务用 godot MCP 截图/`run_script` 验证。**MCP 验证铁律(见记忆 mcp-verify-no-save-pollution):** 绝不在 run_script 里改 `MetaProgress`/触发 `save_progress()`,只读验证。

---

### Task 1: 注册 `discover` effect + 候选生成 helper

**Files:**
- Create: `run_system/core/discover_pool.gd`
- Modify: `battle_scene/data_validator.gd`(ALLOWED_EFFECT_TYPES / KNOWN_OPTIONAL_CARD_KEYS + discover 校验)

- [ ] **Step 1: 新建 `discover_pool.gd`**

```gdscript
## Stateless helper that rolls Discover candidates. No class_name (ADR-0006) — preload.
## A candidate pool is a list of unlocked card ids filtered by `pool` (a card TYPE like
## "attack"/"skill"/"ability", OR a theme tag found in the card's `tags` array).
extends RefCounted

const CARD_DIR := "res://battle_scene/card_info/player/"
## Basic starter cards are excluded — discovering Strike/Defend is boring.
const EXCLUDE := ["strike", "defend", "weak_strike"]
const CARD_TYPES := ["attack", "skill", "ability"]


## Roll up to `count` distinct card ids matching `pool` from the unlocked pool.
## Returns [] when nothing matches (caller shows a "nothing to discover" toast).
static func roll(pool: String, count: int, unlocked: Array) -> Array:
	var matches: Array = []
	for cid in unlocked:
		var id := str(cid)
		if id in EXCLUDE:
			continue
		var data := _load_card(id)
		if data.is_empty():
			continue
		if _matches(data, pool):
			matches.append(id)
	matches.shuffle()
	return matches.slice(0, min(count, matches.size()))


static func _matches(data: Dictionary, pool: String) -> bool:
	if pool in CARD_TYPES:
		return str(data.get("type", "")).to_lower() == pool
	# Otherwise treat `pool` as a theme tag.
	var tags: Variant = data.get("tags", [])
	return typeof(tags) == TYPE_ARRAY and pool in tags


static func _load_card(id: String) -> Dictionary:
	var path := CARD_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
```

- [ ] **Step 2: 在 `data_validator.gd` 注册 discover + tags**

找到 `ALLOWED_EFFECT_TYPES` 常量,加 `"discover"`。找到 `KNOWN_OPTIONAL_CARD_KEYS`,加 `"tags"`。
在卡牌 effect 校验循环里(其它 effect 校验旁)加 discover 分支:

```gdscript
		elif etype == "discover":
			if not effect.has("pool") or str(effect.get("pool", "")).strip_edges() == "":
				push_error("%s: discover effect missing non-empty 'pool'" % prefix)
			if effect.has("count") and int(effect.get("count", 0)) <= 0:
				push_error("%s: discover effect 'count' must be a positive int" % prefix)
```

- [ ] **Step 3: smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected tail: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 4: Commit**

```bash
git add run_system/core/discover_pool.gd battle_scene/data_validator.gd
git commit -m "feat(discover): register discover effect + candidate-roll helper"
```

---

### Task 2: 全新 `DiscoverModal` 弹窗(暗化遮罩 + 三张大卡)

**Files:**
- Create: `battle_scene/discover_modal.gd`

- [ ] **Step 1: 写 `discover_modal.gd`**

```gdscript
## In-combat Discover popup — frosted scrim over the battle + N enlarged PlayCard
## candidates centered, a bare gold title, pick one. NOT the loot/reward frame skin.
## No class_name (ADR-0006) — owner reaches it via preload.
extends Control

const PLAY_CARD := preload("res://battle_scene/play_card.tscn")

signal discovered(card_id: String)

var _card_ids: Array = []
var _title_text: String = ""
var _card_factory = null  # set by caller: a CardFactory-like node that builds card_info


func setup(card_ids: Array, title: String) -> void:
	_card_ids = card_ids
	_title_text = title


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # eat all input → battle is paused
	# Frosted scrim: dim the battle but let it show through (NOT an opaque reward frame).
	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	add_child(vbox)

	var title := Label.new()
	title.text = _title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	vbox.add_child(row)

	for cid in _card_ids:
		row.add_child(_build_candidate(str(cid)))


func _build_candidate(card_id: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(208, 286) * 1.25
	var card = PLAY_CARD.instantiate()
	card.scale = Vector2(1.25, 1.25)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	# Fill the card_info from the factory if provided, else load JSON directly.
	var info := _card_info(card_id)
	card.card_info = info
	if card.is_node_ready() and card.has_method("set_card_data"):
		card.set_card_data(info)
	# A transparent button over the card captures the click + hover.
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = holder.custom_minimum_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_entered.connect(func(): card.scale = Vector2(1.38, 1.38))
	btn.mouse_exited.connect(func(): card.scale = Vector2(1.25, 1.25))
	btn.pressed.connect(func(): _pick(card_id))
	holder.add_child(btn)
	return holder


func _card_info(card_id: String) -> Dictionary:
	var path := "res://battle_scene/card_info/player/%s.json" % card_id
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"name": card_id, "cost": 0, "type": "skill"}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {"name": card_id}


func _pick(card_id: String) -> void:
	discovered.emit(card_id)
	queue_free()
```

- [ ] **Step 2: smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: both `[OK]` lines (the new script compiles even though nothing instantiates it yet).

- [ ] **Step 3: Commit**

```bash
git add battle_scene/discover_modal.gd
git commit -m "feat(discover): DiscoverModal — frosted in-combat 3-choose-1 popup"
```

---

### Task 3: combat_engine handler + battle 接入(弹窗 → 进手牌)

**Files:**
- Modify: `battle_scene/combat_engine.gd`(在 `_apply_effect` 的 match 里加 `discover` case)
- Modify: `battle_scene/battle_scene.gd`(加 `open_discover(...)` 协程)

- [ ] **Step 1: battle_scene 加弹窗协程**

在 `battle_scene.gd` 顶部 const 区加 `const DISCOVER_MODAL := preload("res://battle_scene/discover_modal.gd")`。
加方法(用 `deck_manager` / `show_notification` —— 两者本文件已在用):

```gdscript
## Open the Discover popup for `pool`; await the pick; add the chosen card to hand.
## `free` makes the picked card cost 0 this combat (cost_override meta). Returns the
## chosen card id, or "" if nothing could be discovered / hand was full.
func open_discover(pool: String, count: int, free: bool) -> String:
	var unlocked: Array = MetaProgress.get_unlocked_card_pool()
	var ids: Array = DISCOVER_POOL.roll(pool, count, unlocked)
	if ids.is_empty():
		show_notification(tr("UI_DISCOVER_EMPTY"), Color(0.85, 0.6, 0.4))
		return ""
	var modal = DISCOVER_MODAL.instantiate()
	modal.setup(ids, tr("UI_DISCOVER_TITLE_%s" % pool.to_upper()) if tr("UI_DISCOVER_TITLE_%s" % pool.to_upper()) != "UI_DISCOVER_TITLE_%s" % pool.to_upper() else tr("UI_DISCOVER_TITLE"))
	add_child(modal)
	var picked: String = await modal.discovered
	# Hand-full guard: deck_manager.hand is the live hand array.
	if deck_manager.hand.size() >= MAX_HAND_SIZE:
		show_notification(tr("UI_DISCOVER_HAND_FULL"), Color(0.85, 0.5, 0.4))
		return ""
	var card = deck_manager.add_card_to_hand(picked)
	if free and card and is_instance_valid(card):
		card.set_meta("cost_override", 0)
		if card.has_method("update_display"):
			card.update_display()
	AudioManager.play_sfx("card_draw")
	return picked
```

加 `const DISCOVER_POOL := preload("res://run_system/core/discover_pool.gd")` 到 const 区。
确认 `MAX_HAND_SIZE` 存在;若无,加 `const MAX_HAND_SIZE := 10`(放 const 区)。
确认 `deck_manager.add_card_to_hand` 返回卡实例;若返回 void,见 Task 3 Step 1b。

- [ ] **Step 1b: 确保 `add_card_to_hand` 返回卡实例**

打开 `battle_scene/deck_manager.gd` 的 `add_card_to_hand`。若它没 `return` 新建的卡,改成返回它:
末尾 `return card`(card = 它 create 出来加进 hand 的那张)。若签名/变量名不同,按实际改;目标是
`open_discover` 能拿到刚加入手牌的 `PlayCard` 实例来打 `cost_override`。

- [ ] **Step 2: combat_engine 加 discover case**

在 `combat_engine.gd` 的 `_apply_effect` match 里(其它 effect case 旁)加:

```gdscript
			"discover":
				var d_pool := str(effect.get("pool", "skill"))
				var d_count := int(effect.get("count", 3))
				var d_free := bool(effect.get("free", false))
				if main and main.has_method("open_discover"):
					await main.open_discover(d_pool, d_count, d_free)
```

(`main` 是 combat_engine 已持有的 battle_scene 引用 —— 同文件其它 case 已用 `main.show_notification` 等。)

- [ ] **Step 3: smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: both `[OK]` lines.

- [ ] **Step 4: Commit**

```bash
git add battle_scene/combat_engine.gd battle_scene/battle_scene.gd battle_scene/deck_manager.gd
git commit -m "feat(discover): combat_engine handler + battle open_discover coroutine"
```

---

### Task 4: 本场 0 费(`cost_override`)显示 + 扣费

**Files:**
- Modify: `battle_scene/play_card.gd`(`set_card_data` 显示 cost_override)
- Modify: `battle_scene/battle_scene.gd`(打牌的费用检查 / 扣能量读 cost_override)

- [ ] **Step 1: PlayCard 显示 cost_override**

在 `play_card.gd` `set_card_data` 里,把费用那行改成优先读 meta:

```gdscript
	# ── Cost: cost_override (this-combat discover) wins over the card's base cost ──
	var shown_cost: int = int(data.get("cost", 0))
	if has_meta("cost_override"):
		shown_cost = int(get_meta("cost_override"))
	cost_label.text = str(shown_cost)
```

(替换原来的 `cost_label.text = str(int(data.get("cost", 0)))`。)

- [ ] **Step 2: 出牌扣费读 cost_override**

在 `battle_scene.gd` 找 `spend_energy` 以及"能量够不够"的检查(grep `cost` / `energy`)。把取卡费用的地方
统一成一个 helper,放本文件:

```gdscript
## The effective energy cost of a card right now — cost_override (discover, this combat)
## takes priority over the card's base cost.
func card_cost(card) -> int:
	if card and is_instance_valid(card) and card.has_meta("cost_override"):
		return int(card.get_meta("cost_override"))
	return int(card.card_info.get("cost", 0)) if card else 0
```

把 `spend_energy` 内、以及 `play_spell` 里判断"能量是否足够"的 `card_info.cost` 读取,都替换成
`card_cost(card)`。(grep `card_info.get("cost"` / `\.cost` 在 battle_scene.gd 逐个换成 `card_cost(...)`。)

- [ ] **Step 3: smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: both `[OK]` lines.

- [ ] **Step 4: Commit**

```bash
git add battle_scene/play_card.gd battle_scene/battle_scene.gd
git commit -m "feat(discover): cost_override — discovered cards can cost 0 this combat"
```

---

### Task 5: 3 张示范发现卡 + 流血 tags + draft 池 + 翻译

**Files:**
- Create: `battle_scene/card_info/player/scrap_scavenge.json`
- Create: `battle_scene/card_info/player/blood_recipe.json`
- Create: `battle_scene/card_info/player/armory_requisition.json`
- Modify: 几张流血卡加 `tags: ["bleed"]`
- Modify: `run_system/core/meta_progress.gd`(draft/解锁池含新卡) 或 `data_validator` 的初始池
- Modify: `assets/translations/content_cards.csv` + `assets/translations/ui_battle.csv`

- [ ] **Step 1: 3 张发现卡 JSON**

`scrap_scavenge.json`:
```json
{
  "name": "scrap_scavenge",
  "title": "Scrap Scavenge",
  "rarity": "uncommon",
  "type": "skill",
  "cost": 1,
  "description": "Discover a skill.",
  "front_image": "player/curse_placeholder.png",
  "side": "player",
  "effects": [
    { "type": "discover", "pool": "skill", "count": 3 },
    { "type": "exhaust_self" }
  ]
}
```

`blood_recipe.json`:
```json
{
  "name": "blood_recipe",
  "title": "Blood Recipe",
  "rarity": "uncommon",
  "type": "skill",
  "cost": 1,
  "description": "Discover a Bleed card. It costs 0 this combat.",
  "front_image": "player/curse_placeholder.png",
  "side": "player",
  "tags": ["bleed"],
  "effects": [
    { "type": "discover", "pool": "bleed", "count": 3, "free": true },
    { "type": "exhaust_self" }
  ]
}
```

`armory_requisition.json`:
```json
{
  "name": "armory_requisition",
  "title": "Armory Requisition",
  "rarity": "uncommon",
  "type": "skill",
  "cost": 1,
  "description": "Discover an attack.",
  "front_image": "player/curse_placeholder.png",
  "side": "player",
  "effects": [
    { "type": "discover", "pool": "attack", "count": 3 },
    { "type": "exhaust_self" }
  ]
}
```

(美术用占位 `curse_placeholder.png`;真图后续走 asset-spec / Codex。)

- [ ] **Step 2: 给流血牌加 `tags: ["bleed"]`**

对带流血的牌补 tag,让 `pool:"bleed"` 能选到它们。逐张在 JSON 顶层加 `"tags": ["bleed"],`:
`acid_splash.json`、`hemorrhage.json`、`corrode.json`、`bulkhead_bleed.json`、`siphon_valve.json`
(grep `"bleed"` 或 `apply_bleed_scaled` 在 `battle_scene/card_info/player/*.json` 确认全部带流血的牌,逐张加。)

- [ ] **Step 3: 把 3 张发现卡放进 draft / 解锁池**

打开 `run_system/core/meta_progress.gd`,找 `INITIAL_CARD_POOL`(Task 上下文里它在 ~271 行)。把
`"scrap_scavenge"`、`"blood_recipe"`、`"armory_requisition"` 加进去,让它们能在 draft 出现 + 被
`get_unlocked_card_pool()` 当作发现候选(注意:发现卡自身会进候选池,但 `pool:"skill"` 会包含它们——
可接受,发现到另一张发现卡是有趣的连锁;若不想,在 `discover_pool.EXCLUDE` 里加这三个 id)。

- [ ] **Step 4: 翻译**

`content_cards.csv` 加(KEY,en,zh):
```
CARD_scrap_scavenge_TITLE,Scrap Scavenge,废料翻找
CARD_scrap_scavenge_DESC,Discover a skill.,发现一张技能牌。
CARD_blood_recipe_TITLE,Blood Recipe,血色配方
CARD_blood_recipe_DESC,"Discover a Bleed card. It costs 0 this combat.",发现一张流血牌，本场战斗中它的费用为 0。
CARD_armory_requisition_TITLE,Armory Requisition,军火调拨
CARD_armory_requisition_DESC,Discover an attack.,发现一张攻击牌。
```
`ui_battle.csv` 加:
```
UI_DISCOVER_TITLE,Discover,发现
UI_DISCOVER_TITLE_SKILL,Discover · Skill,发现 · 技能
UI_DISCOVER_TITLE_ATTACK,Discover · Attack,发现 · 攻击
UI_DISCOVER_TITLE_BLEED,Discover · Bleed,发现 · 流血
UI_DISCOVER_EMPTY,Nothing to discover.,没有可发现的牌。
UI_DISCOVER_HAND_FULL,Hand is full — discard discarded.,手牌已满，发现作废。
```

- [ ] **Step 5: import + smoke**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . --import` 然后
`GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: both `[OK]` lines(新卡 JSON 通过 schema,翻译重新生成)。

- [ ] **Step 6: Commit**

```bash
git add battle_scene/card_info/player/ assets/translations/ run_system/core/meta_progress.gd
git commit -m "feat(discover): 3 sample discover cards + bleed tags + pool + localization"
```

---

### Task 6: MCP 验证 + catalog + 文档

**Files:**
- Modify: `docs/catalog_html/*`(重新生成)、`docs/PRD.md`(发现机制一段)

- [ ] **Step 1: MCP 起游戏 + 进战斗 + 加发现卡到手牌**

`mcp__godot__run_project(background:true)`(失败重试一次)。
`run_script` 起一场战斗(参考既往:`RunManager.start_new_run("cowboy_bill", typed_empty, 0)` →
`current_encounter = select_encounter("enemy", 1)` → `change_scene_to_file(battle)`)。
**只读铁律**:不要在 run_script 里 `save_progress`;起战斗只动内存,不调存档写入函数(start_new_run
会 clear run save —— 先 `cp` 备份 `slot_1/run_save.json`、`meta.json`,验证完恢复;或在一个空 slot 上验证)。

- [ ] **Step 2: 加 `scrap_scavenge` 到手牌并打出 → 验证弹窗**

`run_script`:`scene.deck_manager.add_card_to_hand("scrap_scavenge")` →
找到该卡 → `scene.play_spell(card, null)`(或直接 `await scene.open_discover("skill", 3, false)`)。
`take_screenshot`。
Expected: 暗化遮罩 + 三张放大的技能候选卡居中 + 顶部「发现 · 技能」,无木框/横条。

- [ ] **Step 3: 选一张 → 验证进手牌**

`run_script` 触发 modal 的 `_pick(<id>)` 或 `simulate_input` 点中间那张 → `take_screenshot`。
Expected: 弹窗关闭,选中的牌出现在手牌。

- [ ] **Step 4: 验证 blood_recipe 的流血筛选 + 0 费**

`run_script`:`await scene.open_discover("bleed", 3, true)` → screenshot 看候选**全是流血牌** →
选一张 → screenshot 看它在手牌**费用显示 0**。

- [ ] **Step 5: 停游戏 + 清理**

`mcp__godot__stop_project`;`rm -f mcp_bridge.gd mcp_bridge.gd.uid`;确认 `project.godot` 无 `McpBridge`;
若 Step 1 备份了存档,`cp` 恢复。

- [ ] **Step 6: catalog + 文档 + 提交**

```bash
PYTHONIOENCODING=utf-8 python scripts/gen_catalog_html.py
```
在 `docs/PRD.md` 的卡牌/系统章节加一段"发现机制"。

```bash
git add docs/catalog_html/ docs/PRD.md
git commit -m "docs(discover): catalog + PRD; in-engine verified"
```

---

## 自审(plan vs spec)

- **Spec 覆盖**:① discover effect → Task 1;② 候选生成(筛+排除基础) → Task 1;③ DiscoverModal UI → Task 2;
  ④ 流程(暂停/await/进手牌/手牌满) → Task 3;⑤ cost_override 0费 → Task 4;⑥ 3 张示范卡 + tags → Task 5;
  ⑦ 两处注册 + 验证 + catalog → Task 1(validator)+ Task 6。全部有对应任务。
- **类型一致**:`open_discover(pool,count,free)`、`DiscoverModal.setup(card_ids,title)`/`discovered(card_id)`、
  `discover_pool.roll(pool,count,unlocked)`、`card_cost(card)`/`cost_override` meta —— 各任务签名一致。
- **占位扫描**:无 TBD;每个代码步给了实际代码。唯一"按实际改"处(`add_card_to_hand` 返回值、battle 里
  `card_cost` 的逐处替换)是因这些点依赖现有文件细节,已明确指出 grep 目标 + 目标行为。

## 风险 / 注意

- `add_card_to_hand` 当前可能不返回卡实例(Task 3 Step 1b 处理)。0 费依赖能拿到该实例。
- `combat_engine._apply_effect` 改成含 `await`(discover case)—— 确认它的调用链允许协程挂起(出牌流程已有
  `await`,见现有 gain_block 的 `await create_timer`)。
- 发现卡进 `pool:"skill"` 候选会自我递归(发现到发现卡)——设计上接受;不想要就加进 `EXCLUDE`。
