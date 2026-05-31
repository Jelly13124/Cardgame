# Attributes-Matter Implementation Plan (luck/charm · crit · events)

> **Autonomous overnight build.** Exact code lives in the spec
> `docs/superpowers/specs/2026-05-31-attributes-crit-events-design.md` — each
> phase below references its spec section. Every phase: write a temp headless
> boot-test (where logic exists) → see it fail → implement per spec → see it pass
> → smoke gate green → delete temp test → commit. NEVER commit if smoke is red
> (keep the branch bootable). Bosses/other systems untouched.

**Goal:** Make luck & charm affect gameplay (crit, loot rarity, gold, shop price),
give Cowboy Bill the Crit Clip relic, and upgrade the "?" node into a real
random-event scene with attribute-gated options.

**Tech:** Godot 4.6 / GDScript. No unit framework — temp `_test_*.tscn`+`.gd`
booted headless. Godot: `"C:/Program Files/Godot/Godot.exe"`. Smoke:
`GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`.

**Rules:** `class_name` banned (use preload, except autoloads); never touch
`addons/`/`*.import`/`*.uid`; translation CSV edits need `--headless --import`
before testing. Mixed commits with Codex WIP in shared files are pre-approved.

**Priority:** Phases 1-4 (owner's named asks) first and self-contained; 5-7
(events) layer on top; 8 review.

---

## Phase 1 — Attribute helper foundation  (spec §A)
- **File:** `run_system/core/run_manager.gd` (add consts + `_attr`, `crit_chance`,
  `luck_gold_mult`, `luck_rarity_bonus`, `charm_shop_mult` near `recompute_attributes`).
- **Test:** temp scene asserts `crit_chance()` = clamp(luck×0.03,0,0.40),
  `luck_gold_mult()`=1+luck×0.03, `luck_rarity_bonus()`=luck×0.015,
  `charm_shop_mult()`=max(0.6,1−charm×0.02) at luck/charm ∈ {0,3,10,20}.
- **Commit:** `feat(attr): luck/charm gameplay helper functions on RunManager`

## Phase 2 — Crit Clip relic + crit hook + starting relic  (spec §B)
- **Files:** create `run_system/data/relics/crit_clip.json`; edit
  `battle_scene/relic_effect_system.gd` (add `crit_chance` arm to
  `modify_player_attack_damage`); edit `run_system/core/run_manager.gd`
  (`start_new_run` grants `current_hero_data.starting_relic`); edit
  `run_system/data/heroes/cowboy_bill.json` (`"starting_relic":"crit_clip"`);
  verify `data_validator.gd validate_hero` accepts the new optional key
  (add it to the hero known-optional set if heroes have an unknown-key check).
- **Test:** after `start_new_run("cowboy_bill")`, `RunManager.relics` contains
  `crit_clip`; with luck forced high, the relic hook multiplies a sample damage
  by 1.5 when the roll hits (test the deterministic path: force `crit_chance`≈1
  via high luck and assert the multiplied value; or assert the relic JSON loads
  and the hook arm exists by exercising relic_effect_system with a stub `main`).
  Smoke green.
- **Commit:** `feat(relic): Crit Clip — luck-scaled 1.5x crit on player attacks + hero starting-relic`

## Phase 3 — Luck → loot rarity + post-battle gold  (spec §C)
- **File:** `run_system/ui/loot_reward.gd` (`_generate_draft_options` luck promote;
  `_generate_loot` gold ×`luck_gold_mult`).
- **Test:** helper math already covered in Phase 1; this phase verifies wiring +
  smoke (a temp test can assert `int(round(10*RunManager.luck_gold_mult()))`
  matches expectation at a set luck). Smoke green.
- **Commit:** `feat(loot): luck boosts post-battle gold and loot rarity`

## Phase 4 — Charm → shop pricing  (spec §D)
- **File:** `run_system/ui/shop_scene.gd` (`_discounted_price` ×`charm_shop_mult`).
- **Test:** temp test asserts a sample base price × workshop × `charm_shop_mult()`
  drops at high charm and respects the 0.6 floor. Smoke green.
- **Commit:** `feat(shop): charm lowers merchant prices`

## Phase 5 — Random-event data schema + validator + RunManager API  (spec §E)
- **Files:** create `run_system/data/random_events/` (dir); edit
  `battle_scene/data_validator.gd` (`RANDOM_EVENT_DIR`,
  `ALLOWED_EVENT_EFFECT_TYPES`, `validate_event`, wire into
  `validate_all_data_at_startup`); edit `run_system/core/run_manager.gd`
  (`load_random_events`, `pick_random_event`, `option_unlocked`,
  `apply_event_effects`, `luck_check_chance`).
- **Test:** temp test: write a tiny valid event dict, assert `option_unlocked`
  honors `requires.charm/luck`, `apply_event_effects` dispatches each allowed
  effect to the right RunManager mutation (gold/core/hp/relic/attr), and
  `luck_check_chance()` is in range. `pick_random_event()` returns {} when the
  dir is empty (no events authored yet in this phase). Smoke green.
- **Commit:** `feat(events): random-event schema, validator, and RunManager API`

## Phase 6 — Event modal UI + "?" node wiring  (spec §E)
- **Files:** create `run_system/ui/event_modal.gd` (ExtractChoiceModal-style
  Control + `resolved` signal, renders options, locked options disabled with
  `[Charm N]` hint); edit `run_system/ui/map_scene.gd` (`_on_node_clicked`
  "unknown" arm → open event modal in a `CanvasLayer`; fall back to
  `_resolve_unknown_node` if `pick_random_event()` is empty; release
  `_node_click_pending` in the resolve callback).
- **Test:** smoke gate (UI on a live scene). Verify `event_modal.gd` parses and
  `map_scene.gd` boots clean.
- **Commit:** `feat(events): event modal UI + route the "?" node through it`

## Phase 7 — 4 random events (content)  (spec §E)
- **Files:** create 4 JSONs in `run_system/data/random_events/` — each 2-3
  options, including ≥1 plain-effect, ≥1 `requires.charm`-gated, ≥1
  `luck_check`/`requires.luck` option. Wasteland flavor. Text in JSON.
- **Test:** reimport not needed (text in JSON); boot smoke must show
  `[OK] DataValidator: all schemas passed.` (the new validator must accept all 4).
  Temp test: `RunManager.pick_random_event()` now returns a non-empty event and
  every authored event passes `validate_event`.
- **Commit:** `content(events): 4 wasteland random events with luck/charm options`

## Phase 8 — Integration review (no code)
- Re-read spec; confirm: helpers single-sourced & consumed once each; crit gated
  by relic ownership; starting-relic grant fires only for heroes that declare it;
  event effects all map to real RunManager methods; validator accepts events and
  boot is clean; no leftover refs; YAGNI. Produce a findings list; fix any
  Critical/Important inline (re-running smoke) and commit fixes.

---

## Morning manual playtest checklist (owner runs)
- Start as Bill → has Crit Clip relic; attacks occasionally show "CRIT!" and hit
  ~1.5×; crit feels more frequent with higher luck.
- Post-battle gold and rare-draft frequency feel higher at high luck.
- Shop prices lower at high charm.
- Click a "?" node → an event scene with 2-3 options appears; a charm/luck-gated
  option is locked (greyed with hint) at low attributes and unlocks when high;
  luck_check options resolve success/fail; effects apply.
