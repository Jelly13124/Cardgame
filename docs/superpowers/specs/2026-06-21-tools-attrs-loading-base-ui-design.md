# Spec — Tool system + attribute rework + drop restructure + loading + base UI

**Date:** 2026-06-21. **Branch:** `overnight-0615`. **Mode:** autonomous overnight
(`/goal`). Smoke-gate (`bash scripts/smoke_test.sh`) + MCP-verify the risky bits +
commit (and push) **per phase**. Owner verifies the complete system + UI tomorrow.

> **Art note (ADR-0005):** any NEW PNG (tool icons) is Codex's. Where a tool icon
> is missing, fall back to a glyph/letter (like gems did before their art landed),
> and write/append an `asset-spec-*.md` contract for the icons. Do NOT hand-draw art.

## Locked design summary

A StS2-flavoured pass: add **one-time tools** (top-bar consumables), make the
**backpack** the scarce shared inventory (gold + equipment + **gems**), restructure
**drops** so tools are the common reward and equipment is a rare boss-only reward,
**re-theme three attributes** around tools/leveling (and delete the Charm flee
mechanic), speed up **map→battle loading**, and redesign the **building detail
pages**. Card upgrades are NOT coming back — gems remain the sole card-growth axis.

---

## Phase 1 — Attribute rework + delete flee

**Charm (魅力):**
- **Delete the low-HP flee mechanic entirely.** Remove `enemy_entity._flee()`,
  `_should_flee()` and the call to them in `take_damage`; remove
  `RunManager.flee_threshold()` and any callers; drop `UI_COMBAT_FLEE` usage. (The
  `enemy_death` SFX stays on the real death path.)
- **New role:** Charm lowers the XP needed to level up. In `RunManager.xp_to_next`
  (or wherever the per-level requirement is computed) multiply the requirement by
  `clampf(1.0 - 0.04 * charm, 0.60, 1.0)` (−4%/point, floor −40%). **[tunable]**
- Charm's existing **shop discount** (`charm_shop_mult`) stays.

**Intelligence (智力):**
- **Remove the +XP bonus** (`xp_int_mult` → no longer applied in `gain_xp`; delete
  or neutralize `xp_int_mult`).
- **Keep** the Bleed-scaling (whatever INT→Bleed does today stays).
- Tool-effect scaling is added in Phase 2 (INT boosts tool numbers).

**Luck (幸运):** unchanged this phase (tool drop chance added in Phase 4).

**Tooltips / attribute view:** update the INT / Luck / Charm descriptions
(`attribute_view.gd` + translation CSVs) to match. INT = "+Bleed, +tool power";
Luck = "+crit, +loot rarity, +gem/tool drop"; Charm = "shop discount, faster
leveling".

Smoke + MCP-verify: kill an enemy (no flee error), level-up math reflects Charm,
INT no longer changes XP.

---

## Phase 2 — Tool system core

**Data:** `run_system/data/tools/<id>.json`, one file per tool:
`{ id, title, target ("enemy"|"self"|"none"), rarity, effects:[{type, amount, …}] }`.
Validate in `data_validator.gd` (a new `tools/` schema + `ALLOWED_TOOL_*`). Effects
reuse the existing `combat_engine._apply_effect` handlers (deal_damage, gain_block,
heal, gain_energy, draw, gain_strength, apply_bleed, apply_weak/vulnerable…).

**Starter set (8, all reusing existing effects) [tunable]:**
med_kit (heal), energy_cell (+energy this turn), adrenaline (draw 2),
frag_grenade (damage 1 enemy), smoke_bomb (gain block), stim (+Strength this turn),
toxin_vial (Bleed 1 enemy), shock_charge (Weak or Vulnerable 1 enemy).

**Inventory:** `RunManager.tool_inventory: Array[String]` (run-scoped, saved/loaded;
NOT in the backpack). **Slots = 2 base**, Outpost base-upgrade grants +1 (cap 3) —
add a `tool_slots` base-upgrade entry (UPGRADE_ORDER + effect consumer +
`ALLOWED_BASE_UPGRADE_EFFECT_KEYS`). Adding a tool past the slot cap is blocked
(or prompts discard) — block for now.

**Top-bar UI (StS2-style):** add a tool-slot row to the shared top bar
(`run_top_bar.gd`, shown in battle via `battle_top_bar`). Each filled slot shows the
tool icon (Codex art at `assets/images/ui/tools/<id>.png`, glyph/letter fallback) +
tooltip; empty slots show a faint outline. In battle, clicking a tool **uses** it:
free + instant (no energy, doesn't end turn); `target=="enemy"` tools enter the same
targeting flow as a single-target attack; then the tool is consumed (removed from
inventory) and its effects resolve via `_apply_effect`. Out of battle the slots are
display-only (no use).

**INT scaling:** when a tool resolves, scale its numeric `amount`s by
`(1.0 + 0.08 * INT)` (rounded). **[tunable]** Centralize so all tool effects scale.

Smoke + MCP-verify: grant tools, enter battle, use a self tool + an enemy-targeted
tool, confirm effects + consumption + INT scaling, no errors.

---

## Phase 3 — Gems occupy the backpack

- Change gem storage from the unlimited `gem_inventory` to the **backpack** (each
  gem = 1 cell, like equipment). Gold keeps stacking; equipment + gems are 1/cell.
- Every gem grant (rest-stop mining, draft pick, shop, relic) routes through a
  backpack add that can **fail when full** → show the existing backpack-full toast
  (mirror the gold path in `loot_reward`), and don't lose the source silently.
- **Socketing a gem frees its backpack cell** (gem moves from backpack onto the
  card). Surface this in the gem/deck UI.
- Backpack capacity: keep current size; if it feels cramped in playtest, bump cells
  or add a backpack-size base-upgrade. **[tunable]**

Smoke + MCP-verify: mine/draft a gem → it occupies a cell; fill the backpack → grant
blocked with toast; socket a gem → cell freed.

---

## Phase 4 — Drops / equipment / shop restructure

- **Shop (`shop_scene`):** replace the **equipment** stall section with a **tools**
  section (sells 2–3 tools, rarity-priced). Cards + relics + remove-service stay.
- **Elite battles:** drop a **tool** (was equipment) into the reward.
- **Normal battles / events:** Luck-scaled chance to also drop a tool —
  `0.25 + 0.03 * luck`, capped `0.60`. **[tunable]** Wire in `loot_reward` reward
  generation + the event reward path.
- **Boss battles:** drop **equipment** (now the only equipment source).
- Tool rewards go to `tool_inventory` (respect slot cap → if full, offer skip).

Smoke + MCP-verify: elite reward = tool; boss reward = equipment; shop shows tools;
a high-Luck normal battle rolls a tool.

---

## Phase 5 — Loading optimization (cache; near-seamless)

- **Card-data global cache (primary, low-risk):** the per-battle
  `json_card_factory.preload_card_data()` re-parses ~50 card JSONs each battle.
  Without editing `addons/` (vendored), pre-warm so the second+ battle is a cache
  hit: e.g. a small autoload / `MetaProgress`-level cache that loads all card JSON
  data once at game start, and the battle reads from it (or relies on Godot's
  resource cache by loading them once up front). Verify the per-battle
  "Preloaded card:" cost drops on the 2nd battle.
- **Scene pre-warm (stretch, only if clean):** while idle on the map, pre-instantiate
  the battle shell so a node click reveals it fast. If the click-time
  `current_encounter` dependency makes this messy, skip it — the cache + a quick
  fade is the realistic "near-seamless" target. Honest expectation: not true
  zero-load (main-thread instantiation), but noticeably faster.

Smoke + MCP-verify (timing/log): 2nd battle entry skips the full card re-preload; no
regressions.

---

## Phase 6 — Building detail pages redesign

- The locked-building detail page (e.g. Outpost "未解锁") is currently one
  "解锁 — X 核心" row + empty space. Redesign `building_screen_base` (+ subclass
  hooks) into a fuller, layered page:
  - Large building art / icon header + a flavour line.
  - The **unlock/upgrade** action as a prominent styled card (cost + effect), not a
    bare row.
  - A **preview of what the building does** when unlocked (its function blurb /
    tier benefits), so a locked page still communicates value.
  - Consistent panels / spacing / fonts (reuse `wasteland_theme`); fill the space.
- Apply to all five (forge / clinic / market / outpost / warehouse), locked +
  unlocked states. Keep each subclass's actual function working.

Smoke + MCP-verify (screenshots): locked + unlocked building pages read full and
themed, not sparse.

---

## Cross-cutting / done criteria
- Keep the HTML catalogs in sync if tool content counts as catalog content
  (`python scripts/gen_catalog_html.py` — add a tools page if the generator covers it).
- Each phase: smoke-gate, MCP-verify the risky bits, commit (+ push), one-line note.
- Tool icons: glyph fallback now; append a `docs/asset-spec-tool-icons.md` Codex
  contract listing the 8 ids so the owner can have Codex deliver art.
- Tomorrow's acceptance: tools usable from the top bar, gems in backpack with the
  socket-frees-cell loop, elite→tool / boss→equipment / shop-sells-tools, the three
  re-themed attributes (no flee), faster 2nd-battle load, and redesigned building
  pages.
