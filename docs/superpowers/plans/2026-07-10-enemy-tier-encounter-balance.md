# Enemy Tier and Encounter Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为全部敌人建立可验证的五级身份，并把普通遭遇重排为开场/前期/中期/后期四段预算。

**Architecture:** 敌人 JSON 的 `tier` 是身份真源；`RunManager` 只维护显式、可审计的 roster；`DataValidator` 同时验证 JSON tier、角色约束和基础生命预算；图鉴直接按 tier 分组。

**Tech Stack:** Godot 4.6、GDScript、JSON、Python catalog generator、Markdown documentation。

## Global Constraints

- tier 允许值仅为 `minion | normal | heavy | elite | boss`。
- 不修改任何敌人的 `max_health`、动作数值、跨幕倍率或进阶倍率。
- heavy 普通遭遇必须单独出现；elite/boss 不得进入普通池。
- 开场后 minion 只能双杂兵或作为 normal 支援。
- 四段基础 HP 预算固定为 opening 12–18、early 20–30、mid 25–34、late 34–50。
- 图鉴必须由 `scripts/gen_catalog_html.py` 生成，禁止手改 HTML。

---

### Task 1: Add the failing enemy balance contract

**Files:**
- Create: `tests/enemy_encounter_balance_contract_test.gd`
- Create: `tests/enemy_encounter_balance_contract_test.tscn`

**Interfaces:**
- Consumes: enemy JSON, RunManager encounter constants, DataValidator.
- Produces: exact tier assignment and roster-budget regression coverage.

- [ ] **Step 1: Write the failing test**

The test loads all enemy JSON and checks the exact mapping from the approved spec. It then checks exact pools:

```gdscript
const EXPECTED_POOLS := {
    "opening": [["scrap_rat"], ["hex_drone"], ["acid_spitter"]],
    "early": [["wasteland_killer"], ["scrap_rat", "scrap_rat"], ["riot_hound"], ["mortar_cart"], ["trash_robot"]],
    "mid": [["riot_hound"], ["mortar_cart"], ["slag_walker"], ["acid_spitter", "scrap_rat"], ["wasteland_killer", "scrap_rat"], ["chrome_hound"], ["riot_hound_alpha"]],
    "late": [["riot_hound_alpha"], ["rust_brute"], ["mortar_cart", "scrap_rat"], ["chrome_hound", "scrap_rat"], ["mortar_cart_siege", "scrap_rat"], ["slag_walker", "acid_spitter"], ["riot_hound", "riot_hound"]],
}
```

It must assert 20 legal tiers, exact role assignments, each pool's HP budget, solo-heavy, no ordinary elite/boss, solo-minion only in opening, and `DataValidator.validate_encounter_pools() == 0` after implementation.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/enemy_encounter_balance_contract_test.tscn
```

Expected: non-zero exit because `tier` and `ENCOUNTER_POOLS_OPENING` are absent and old late pools exceed budget.

- [ ] **Step 3: Commit the red balance test**

```powershell
git add tests/enemy_encounter_balance_contract_test.gd tests/enemy_encounter_balance_contract_test.tscn
git commit --only -m "test: lock enemy tiers and encounter budgets" -- tests/enemy_encounter_balance_contract_test.gd tests/enemy_encounter_balance_contract_test.tscn
```

### Task 2: Add tier metadata and explicit four-band rosters

**Files:**
- Modify: `battle_scene/card_info/enemy/*.json`
- Modify: `run_system/core/run_manager.gd`

**Interfaces:**
- Produces: required enemy `tier` field.
- Produces: `ENCOUNTER_POOLS_OPENING`, revised EARLY/MID/LATE constants.

- [ ] **Step 1: Add exact tier values to all 20 JSON files**

Use the exact assignment in `docs/superpowers/specs/2026-07-10-enemy-tier-encounter-balance-design.md`; place `tier` beside `sprite_id` without changing any other gameplay values.

- [ ] **Step 2: Replace encounter constants and selection bands**

```gdscript
if tier_floor <= 1:
    pool = ENCOUNTER_POOLS_OPENING
elif tier_floor <= 3:
    pool = ENCOUNTER_POOLS_EARLY
elif tier_floor <= 7:
    pool = ENCOUNTER_POOLS_MID
else:
    pool = ENCOUNTER_POOLS_LATE
```

The four constants must match `EXPECTED_POOLS` exactly and preserve equal random choice within each explicit roster.

- [ ] **Step 3: Run the balance contract**

Expected: metadata and exact roster assertions pass; validator-specific assertions may still fail until Task 3.

- [ ] **Step 4: Commit tier data and roster selection**

```powershell
git add battle_scene/card_info/enemy run_system/core/run_manager.gd
git commit --only -m "balance: classify enemies and smooth encounter pools" -- battle_scene/card_info/enemy run_system/core/run_manager.gd
```

### Task 3: Enforce tier roles and HP budgets at startup

**Files:**
- Modify: `battle_scene/data_validator.gd`

**Interfaces:**
- Consumes: every enemy JSON's `tier` and `max_health`.
- Produces: `ALLOWED_ENEMY_TIERS`; complete `validate_encounter_pools()` enforcement.

- [ ] **Step 1: Require legal tier metadata**

Add `tier` to `REQUIRED_ENEMY_KEYS` and reject values outside:

```gdscript
const ALLOWED_ENEMY_TIERS := ["minion", "normal", "heavy", "elite", "boss"]
```

- [ ] **Step 2: Validate every explicit roster**

Load an `enemy_id -> {tier,max_health}` dictionary and check:

```gdscript
const ENCOUNTER_BUDGETS := {
    "ENCOUNTER_POOLS_OPENING": Vector2i(12, 18),
    "ENCOUNTER_POOLS_EARLY": Vector2i(20, 30),
    "ENCOUNTER_POOLS_MID": Vector2i(25, 34),
    "ENCOUNTER_POOLS_LATE": Vector2i(34, 50),
}
```

For normal pools: reject elite/boss; reject mixed or multi-enemy heavy; after opening reject solo minion and minion+minion only when not exactly two; require every non-minion companion to be normal. Require every `ELITE_ROSTER` id to be elite and every `ACT_BOSSES` id to be boss.

- [ ] **Step 3: Run the contract and direct headless validation**

Expected: contract passes and boot prints `[OK] DataValidator` without failures.

- [ ] **Step 4: Commit validator enforcement**

```powershell
git add battle_scene/data_validator.gd
git commit --only -m "feat: validate enemy tiers and encounter budgets" -- battle_scene/data_validator.gd
```

### Task 4: Group the catalog by tier and synchronize documentation

**Files:**
- Modify: `scripts/gen_catalog_html.py`
- Modify: `docs/PRD.md`
- Modify: `docs/PROJECT_STRUCTURE.md`
- Modify/Generated: `docs/catalog_html/enemies.html`
- Modify/Generated: `docs/catalog_html/index.html`

**Interfaces:**
- Consumes: JSON `tier`.
- Produces: five sections ordered minion, normal, heavy, elite, boss.

- [ ] **Step 1: Replace boss heuristics with tier grouping**

```python
ENEMY_TIERS = [
    ("minion", "Minions 杂兵"),
    ("normal", "Normal 普通"),
    ("heavy", "Heavy 重型"),
    ("elite", "Elites 精英"),
    ("boss", "Bosses 首领"),
]
```

`enemy_block()` must render a tier pill and use the boss color only for boss; each section sorts by `max_health` and total count remains 20.

- [ ] **Step 2: Update PRD and project structure**

Document the required tier field, exact role rules, four floor bands, budgets, and `ENCOUNTER_POOLS_OPENING` wiring. Remove stale claims that enemy schema lacks tier or that catalog uses boss/rest heuristics.

- [ ] **Step 3: Regenerate and verify catalog output**

```powershell
python scripts/gen_catalog_html.py
rg -n "Minions 杂兵|Normal 普通|Heavy 重型|Elites 精英|Bosses 首领|20 entries" docs/catalog_html/enemies.html docs/catalog_html/index.html
```

- [ ] **Step 4: Run the full balance and startup verification**

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/enemy_encounter_balance_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 5
```

Expected: zero exits; all schemas and encounter constraints pass.

- [ ] **Step 5: Commit docs, generator, and generator-owned output**

```powershell
git add scripts/gen_catalog_html.py docs/PRD.md docs/PROJECT_STRUCTURE.md docs/catalog_html/enemies.html docs/catalog_html/index.html
git commit --only -m "docs: expose enemy tiers in catalog and architecture" -- scripts/gen_catalog_html.py docs/PRD.md docs/PROJECT_STRUCTURE.md docs/catalog_html/enemies.html docs/catalog_html/index.html
```
