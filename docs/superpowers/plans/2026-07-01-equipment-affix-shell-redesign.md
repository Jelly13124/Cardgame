# 装备系统重构(通用壳 + 保证属性词条)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把装备改成"通用壳 + 随机词条"——同部位同稀有度共用一个外观,每件保证 1 个属性词条;套装保留独立身份;诅咒装 A3+ 掉落 + 铁匠铺打造。

**Architecture:** 复用现有 affix 系统(`affix_pool.gd` + `make_equip_instance`)。改 `roll()` 保证属性词条;用 15 个通用壳 base(5 部位 × 3 档)替换 8 件杂项装备,诅咒为 instance 变体;掉落表指向壳 + A3+ 诅咒入口;`equipment_icon` 按 `slot×rarity` 取图。套装 15 件不动。

**Tech Stack:** Godot 4.6 / GDScript;数据 = JSON + 翻译 CSV;验证 = `scripts/smoke_test.sh`(headless DataValidator)+ `scripts/gen_catalog_html.py` + Godot MCP `run_script`(只读抽样)。

**验证约定(全程通用):**
- **Schema/启动**:`GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → 期望 `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
- **Catalog**:`python scripts/gen_catalog_html.py` → 无报错。
- **提交**:每个 Task 末尾 commit（**本地 commit,不 push**——项目习惯,见 memory git-codex-mixed-commits）。
- **不污染存档**:MCP `run_script` 只调纯函数/只读，绝不 `save_progress()`（见 memory mcp-verify-no-save-pollution）。

---

### Task 1: `affix_pool.roll` 保证 1 个属性词条

**Files:**
- Modify: `run_system/core/affix_pool.gd`(`roll()` + 新增 `_pick_attribute()`)

- [ ] **Step 1: 加属性词条辅助 + 改 roll**

在 `affix_pool.gd` 顶部常量后加:

```gdscript
## The attribute affixes (the 5 stats). A subset of POSITIVE — every rolled item
## guarantees one of these first, then fills the rest from the full POSITIVE pool.
const ATTRIBUTE_TYPES := [
	"attr_strength", "attr_constitution", "attr_intelligence", "attr_luck", "attr_charm",
]
```

把 `roll()` 改为(替换整个函数体):

```gdscript
static func roll(rarity: String, cursed: bool = false) -> Array:
	var is_cursed: bool = cursed or rarity == "cursed"
	var positives_wanted: int = int(AFFIX_COUNT.get(rarity, 1))
	var result: Array = []
	var used_types: Array = []
	# Guarantee the FIRST positive is a random attribute affix.
	if positives_wanted > 0:
		var attr := _pick_attribute()
		result.append(attr)
		used_types.append(attr["type"])
	# Fill the rest from the full positive pool (distinct types).
	for picked in _pick_distinct_positives(positives_wanted - 1, used_types):
		result.append(picked)
	if is_cursed:
		var curse: Dictionary = CURSE[randi() % CURSE.size()].duplicate(true)
		result.append(curse)
	return result


## Pick one random attribute affix (deep copy).
static func _pick_attribute() -> Dictionary:
	var attrs: Array = []
	for entry in POSITIVE:
		if ATTRIBUTE_TYPES.has(entry["type"]):
			attrs.append(entry)
	return attrs[randi() % attrs.size()].duplicate(true)
```

- [ ] **Step 2: MCP 只读抽样验证**

用 Godot MCP `run_script`(纯静态函数,无存档写入):

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
	var AP = load("res://run_system/core/affix_pool.gd")
	var out := {}
	for r in ["common", "uncommon", "rare", "cursed"]:
		var counts := {"total": 0, "has_attr": 0, "curse": 0}
		for _i in 200:
			var a = AP.roll(r)
			counts.total += 1
			var attr := false
			for x in a:
				if str(x.type).begins_with("attr_"): attr = true
				if str(x.type).begins_with("curse_"): counts.curse += 1
			if attr: counts.has_attr += 1
		out[r] = counts
	return out
```

Expected: 每档 `has_attr == total`(200/200);`cursed` 档每次含 1 curse(`curse == 200`);词条总数 = common 1 / uncommon 2 / rare 3 / cursed 4。

- [ ] **Step 3: smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 4: commit(本地)**

```bash
git add run_system/core/affix_pool.gd
git commit -m "feat(equip): guarantee one attribute affix per rolled item"
```

---

### Task 2: 15 通用壳 JSON + 翻译 + 删 8 杂项

**Files:**
- Create: `run_system/data/equipment/gear_{slot}_{tier}.json` × 15
- Delete: `run_system/data/equipment/{old_hat,rusted_dagger,scrap_breastplate,reinforced_plating,combat_harness,lucky_charm,old_world_relic,wasteland_revolver}.json`
- Modify: `assets/translations/content_equipment.csv`

- [ ] **Step 1: 生成 15 个壳 JSON**

壳模板(以 `gear_head_rare.json` 为例):

```json
{
    "id": "gear_head_rare",
    "name": "Rare Headgear",
    "slot": "head",
    "rarity": "rare",
    "bonuses": {},
    "description": "Salvaged head protection. Rolls rare affixes.",
    "sprite": ""
}
```

用脚本一次生成全部 15 个(5 部位 × 3 档),`bonuses` 空(真实数值来自掉落 roll 的词条),`sprite` 空(图由 `equipment_icon` 按 slot×rarity 解析,见 Task 4):

```bash
python3 - <<'PY'
import json, os
slots=["head","chest","weapon","hands","accessory"]
tiers=["common","uncommon","rare"]
tname={"common":"Common","uncommon":"Uncommon","rare":"Rare"}
sname={"head":"Headgear","chest":"Chestpiece","weapon":"Weapon","hands":"Handgear","accessory":"Trinket"}
d="run_system/data/equipment"
for s in slots:
    for t in tiers:
        o={"id":f"gear_{s}_{t}","name":f"{tname[t]} {sname[s]}","slot":s,"rarity":t,
           "bonuses":{},"description":"Salvaged gear. Rolls its affixes on drop.","sprite":""}
        open(f"{d}/gear_{s}_{t}.json","w",encoding="utf-8").write(json.dumps(o,ensure_ascii=False,indent=4)+"\n")
        print("wrote",o["id"])
PY
```

- [ ] **Step 2: 删除 8 件杂项**

```bash
cd run_system/data/equipment
rm old_hat.json rusted_dagger.json scrap_breastplate.json reinforced_plating.json \
   combat_harness.json lucky_charm.json old_world_relic.json wasteland_revolver.json
```

- [ ] **Step 3a: 追加 15 壳翻译(生成脚本)**

```bash
python3 - <<'PY'
slots=[("head","头部装备","Headgear"),("chest","胸部装备","Chestpiece"),
       ("weapon","武器","Weapon"),("hands","手部装备","Handgear"),("accessory","饰品","Trinket")]
tiers=[("common","普通","Common","随机 1 条词条(1 属性)。","Rolls 1 affix (an attribute)."),
       ("uncommon","罕见","Uncommon","随机 2 条词条(含 1 属性)。","Rolls 2 affixes, incl. 1 attribute."),
       ("rare","稀有","Rare","随机 3 条词条(含 1 属性)。","Rolls 3 affixes, incl. 1 attribute.")]
lines=[]
for s,szh,sen in slots:
    for t,tzh,ten,dzh,den in tiers:
        i=f"gear_{s}_{t}"
        lines.append(f'EQUIP_{i}_NAME,{ten} {sen},{tzh}·{szh}')
        lines.append(f'EQUIP_{i}_DESC,"{den}",{dzh}')
open("assets/translations/content_equipment.csv","a",encoding="utf-8").write("\n".join(lines)+"\n")
print("appended",len(lines),"rows")
PY
```

- [ ] **Step 3b: 删 8 杂项翻译行**

```bash
grep -nE 'EQUIP_(old_hat|rusted_dagger|scrap_breastplate|reinforced_plating|combat_harness|lucky_charm|old_world_relic|wasteland_revolver)_' assets/translations/content_equipment.csv
```
用 Edit 逐行删除上面列出的行（每个 id 有 `_NAME` + `_DESC` 共 16 行）。

- [ ] **Step 4: smoke(schema 校验壳 + 确认无悬空引用)**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: `all schemas passed`。若报"未知装备 id"(掉落表还引用旧杂项)→ 先做 Task 3 再回跑；本步只要求壳 JSON schema 通过。

- [ ] **Step 5: commit**

```bash
git add run_system/data/equipment/ assets/translations/content_equipment.csv
git commit -m "feat(equip): add 15 generic gear shells, remove 8 bespoke misc items"
```

---

### Task 3: 掉落表指向壳 + A3+ 诅咒入口

**Files:**
- Modify: `run_system/core/run_manager.gd`(装备掉落选择 + 诅咒常量)

- [ ] **Step 1: 定位现有掉落调用**

Run: `grep -n "make_equip_instance(" run_system/core/run_manager.gd`
读出掉落处(约 line 1465 `add_equip_to_backpack(make_equip_instance(item_id, rarity))`)与 `item_id`/`rarity` 的来源函数,确认按 node_type 得到 rarity(normal=common / elite=uncommon / boss=rare)。

- [ ] **Step 2: 加诅咒常量 + 壳选择 helper**

在 run_manager 的常量区加:

```gdscript
## Ascension >= 3: a dropped GENERIC shell has this chance to roll as a cursed
## variant (3 positives incl. 1 attribute + 1 curse). [tunable]
const CURSE_DROP_CHANCE := 0.15
## A drop has this chance to be a SET PIECE of the tier instead of a generic shell
## (keeps sets collectible; shells are the mainline). [tunable]
const SET_PIECE_DROP_CHANCE := 0.15
const EQUIP_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]
```

加壳选择 helper(掉落 = 大多数出通用壳;~15% 出对应档位套装件;A3+ 的通用壳有概率诅咒。套装件不诅咒):

```gdscript
## Roll a drop of the given tier (common/uncommon/rare). ~15% chance it's a set
## piece of that tier (keeps sets collectible); otherwise a generic shell. At
## Ascension >= 3 a generic shell may come out cursed (set pieces never cursed).
func roll_shell_drop(tier: String) -> Dictionary:
	if randf() < SET_PIECE_DROP_CHANCE:
		var piece := _random_set_piece(tier)
		if piece != "":
			return make_equip_instance(piece, tier)
	var slot: String = EQUIP_SLOTS[randi() % EQUIP_SLOTS.size()]
	var base_id: String = "gear_%s_%s" % [slot, tier]
	var cursed: bool = ascension >= 3 and randf() < CURSE_DROP_CHANCE
	return make_equip_instance(base_id, tier, cursed)

## Random set-piece base id whose rarity matches `tier` (set_id != ""). "" if none.
func _random_set_piece(tier: String) -> String:
	var dir := DirAccess.open(EQUIPMENT_DATA_DIR)
	if dir == null:
		return ""
	var cands: Array[String] = []
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		var d := get_equipment_data(id)
		if str(d.get("set_id", "")) != "" and str(d.get("rarity", "")) == tier:
			cands.append(id)
	if cands.is_empty():
		return ""
	return cands[randi() % cands.size()]
```

- [ ] **Step 3: 掉落处改用 helper**

把掉落装备处（Step 1 定位的 `add_equip_to_backpack(make_equip_instance(item_id, rarity))`）改为:

```gdscript
add_equip_to_backpack(roll_shell_drop(rarity))
```
（若该处的 `rarity` 变量名不同，按实际改；确保传入的是 node 决定的 tier。删除不再需要的 `item_id` 选取逻辑。）

- [ ] **Step 4: MCP 只读验证掉落(不写存档)**

MCP `run_script`:

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
	RunManager.ascension = 3
	var sample = RunManager.roll_shell_drop("rare")   # inspect key names here
	var cursed_seen := 0
	for _i in 300:
		if bool(RunManager.roll_shell_drop("rare").get("cursed", false)): cursed_seen += 1
	RunManager.ascension = 0
	return {"sample": sample, "cursed_seen_of_300": cursed_seen}
```

Expected: `sample` 显示实例结构(`affixes` 3 条含 1 属性、`cursed`、其 base-id 字段);`cursed_seen_of_300` ≈ 45(非 0)。（只改内存 `ascension` 并复位，不 `save_progress`。）

- [ ] **Step 5: smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: `all schemas passed` + clean boot（掉落表不再引用已删杂项）。

- [ ] **Step 6: commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "feat(equip): drop generic shells; A3+ cursed drop entry"
```

---

### Task 4: `equipment_icon` 按 slot×rarity 取图

**Files:**
- Modify: `run_system/ui/equipment_icon.gd`(`set_equipment` 图片解析)

- [ ] **Step 1: 加壳图目录常量**

`equipment_icon.gd` 常量区加:

```gdscript
const SHELL_ICON_DIR := "res://battle_scene/assets/images/ui/equipment/"
```

- [ ] **Step 2: 改图片解析优先级**

在 `set_equipment(slot, item_name, sprite_path, rarity)` 里,把"加载真实贴图"段改为:**先用 JSON `sprite`（套装用），否则按 `slot×rarity` 找通用壳图，最后 fallback slot 图/字母**:

```gdscript
	# 1) explicit sprite (set pieces keep their bespoke art)
	if sprite_path != "":
		var full := "res://battle_scene/assets/images/" + sprite_path
		if ResourceLoader.exists(full):
			var tex := load(full) as Texture2D
			if tex:
				_texture_rect.texture = tex
				_texture_rect.modulate = Color.WHITE
				_texture_rect.visible = true
				_label.visible = false
				return
	# 2) generic shell art by slot × rarity
	var shell_path := "%s%s_%s.png" % [SHELL_ICON_DIR, slot, rarity]
	if ResourceLoader.exists(shell_path):
		var stex := load(shell_path) as Texture2D
		if stex:
			_texture_rect.texture = stex
			_texture_rect.modulate = Color.WHITE
			_texture_rect.visible = true
			_label.visible = false
			return
	# 3) fallback: slot icon / letter
	_try_show_slot_icon(slot, Color(1, 1, 1, 0.75))
```

- [ ] **Step 3: smoke（图未交付时走 fallback，不应崩）**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: clean boot（`ui/equipment/*.png` 还没交付 → 走 slot-icon fallback，无报错）。

- [ ] **Step 4: commit**

```bash
git add run_system/ui/equipment_icon.gd
git commit -m "feat(equip): resolve shell icon by slot x rarity, sets keep bespoke art"
```

---

### Task 5: catalog 反映壳 + data_validator + 迁移确认

**Files:**
- Modify: `scripts/gen_catalog_html.py`（`build_equipment`）
- Verify: `battle_scene/data_validator.gd`（壳应已满足 schema — 只确认）
- Verify: 旧存档实例兼容（只读确认）

- [ ] **Step 1: catalog 装备条目显示"roll 词条"提示**

`build_equipment()` 里，装备卡片 `bl`（`bonuses` 列表）现在壳 `bonuses` 为空 → 改为按 rarity 显示 roll 规则。在生成 `bl` 处加:

```python
        roll_txt = {"common":"Rolls 1 affix (1 attribute)",
                    "uncommon":"Rolls 2 affixes (incl. 1 attribute)",
                    "rare":"Rolls 3 affixes (incl. 1 attribute)"}.get(rar, "")
        bl = "".join(f"<li>+{v} {cap(k)}</li>" for k, v in d.get("bonuses", {}).items())
        if not d.get("bonuses") and roll_txt:
            bl = f"<li>{roll_txt}</li>"
```

- [ ] **Step 2: 重新生成 catalog**

Run: `python scripts/gen_catalog_html.py`
Expected: 无报错;`equipment.html` 显示 15 壳(每部位每档) + 15 套装,`index.html` 同步。

- [ ] **Step 3: data_validator 确认(只读)**

Run: `grep -n "REQUIRED_EQUIPMENT_KEYS\|validate_equipment" battle_scene/data_validator.gd`
确认壳的 `id/name/slot/rarity/bonuses` 满足 required（`bonuses={}` 是合法 Dictionary）。若 validator 要求 `bonuses` 非空 → 无此要求（现有 set 件也可空），跳过。

- [ ] **Step 4: 迁移兼容(只读确认)**

Run: `grep -n "func as_equip_instance" run_system/core/run_manager.gd`
确认旧存档里已存的杂项实例走 `as_equip_instance` 的 `bonuses` 兜底仍能显示（不主动转换，避免动存档）。若旧实例按 base id 加载会因 JSON 已删而报 warning-only fallback（可接受，非崩溃）。

- [ ] **Step 5: smoke + commit**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`（`all schemas passed`）
```bash
git add scripts/gen_catalog_html.py docs/catalog_html/
git commit -m "docs(equip): catalog reflects generic shells (roll rules)"
```

---

### Task 6: Codex 美术契约（asset-spec，不由本工作者实装）

**Files:**
- Create: `docs/asset-spec-equipment-shells.md`

- [ ] **Step 1: 写契约**

写一份 asset-spec（参考 `docs/asset-spec-ui-icons.md` 体例），要求 Codex 交付:
- **20 张通用壳图** → `battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png`(5 部位 × common/uncommon/rare/cursed),64×64,透明底,Offbeat 风格,同部位不同档位有可辨识差异(材质/成色 + 档位色),无文字/边框(边框由 UI 画)。
- **套装 15 件图**（3 套 × 5 部位），各自独立造型 + 绿色调,同 asset-spec 分组。
- Review gate: 先出 1 部位全 4 档 + 1 套装样张到 `docs/art/previews/equipment_shells_<date>/` 审核，再批量。

- [ ] **Step 2: commit**

```bash
git add docs/asset-spec-equipment-shells.md
git commit -m "docs(equip): Codex asset contract for shell + set icons"
```

---

### Task 7: 最终整体验证

- [ ] **Step 1: 全量 smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 2: catalog 一致**

Run: `python scripts/gen_catalog_html.py` → 无报错;装备 = 15 壳 + 15 套装 = 30 条。

- [ ] **Step 3: MCP 只读综合抽样**

重跑 Task 1 Step 2 + Task 3 Step 4 的脚本，确认:每档保证属性词条;A3+ 出诅咒;掉落覆盖 5 部位。

- [ ] **Step 4: 收尾说明**

在回复里向用户报告:数据/引擎已完成 + 已验证;20 壳图 + 套装图为 Codex 待交付项（代码侧已走 fallback，不阻塞）。

---

## 未覆盖 / 交接
- **美术**（Task 6 契约）由 Codex 交付；交付后覆盖 `ui/equipment/{slot}_{rarity}.png`，无需再改代码。
- **诅咒掉落概率** `CURSE_DROP_CHANCE=0.15` 为 `[tunable]`，平衡时可调。
