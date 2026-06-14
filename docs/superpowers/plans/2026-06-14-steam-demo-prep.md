# Steam Demo Prep Implementation Plan

> **For agentic workers:** Executed autonomously overnight by Claude. Each phase is
> self-contained, passes `scripts/smoke_test.sh`, and is committed to `demo-prep`
> (no push). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the shell + polish layer (menu, demo gating, save/resume, result screens,
lightweight tutorial, Steam export scaffolding) to make a shippable Steam demo — audio excluded.

**Architecture:** New code-built `Control` UI scripts following the existing modal pattern
(`run_system/ui/*_modal.gd` + `wasteland_theme.gd`), a centralized demo toggle in
`RunManager`, and a `user://run_save.json` serializer mirroring `meta_progress.gd`.
A new title scene becomes `main_scene`, routing into the existing `home_base_scene` hub.

**Tech Stack:** Godot 4.6, GDScript (no `class_name`, `preload` only), JSON saves,
CSV i18n (en+zh).

**Verification model:** No unit-test framework exists; the gate is `scripts/smoke_test.sh`
(headless boot + `DataValidator` schema pass) plus headless scene-instantiation checks via
`godot --headless -s` one-off scripts where useful. "Test" steps below mean these gates.

**Smoke command:** `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected tail: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

---

## File structure

**New files**
- `run_system/ui/main_menu.gd` + `main_menu.tscn` — title screen (R2)
- `run_system/ui/rules_panel.gd` — "How to Play" panel (R5)
- `run_system/ui/result_screen.gd` — defeat + demo-complete screen (R4)
- `battle_scene/ui/tutorial_tips.gd` — first-battle tip sequence (R5)
- `assets/translations/ui_menu.csv` — new menu/tutorial/result strings (en+zh)
- `export_presets.cfg`, `steam_appid.txt` (R6)
- `docs/steam-demo-build.md` (R6)
- `docs/superpowers/reports/2026-06-14-demo-prep-report.md` (R7)

**Modified files**
- `run_system/core/run_manager.gd` — demo toggle, `acts_total()`, save/load run (R1, R3)
- `run_system/core/meta_progress.gd` — `tutorial_seen` flag (R5)
- `run_system/ui/buildings/warehouse_screen.gd` — hero filter (R1)
- `run_system/ui/map_scene.gd` — checkpoint save + Save&Quit + rules in pause (R3, R5)
- `battle_scene/battle_scene.gd` — result screens + first-battle tip hook (R4, R5)
- `battle_scene/ui/battle_top_bar.gd` — Save&Quit / rules in pause panel (R3, R5)
- `project.godot` — `main_scene` → main_menu; register `ui_menu.csv` translation
- `assets/translations/` — new CSV registered

---

## Phase 0: Branch + docs (DONE before execution)
- [x] Create `demo-prep` branch
- [x] Write spec → `docs/superpowers/specs/2026-06-14-steam-demo-prep-spec.md`
- [x] Write this plan
- [ ] Commit docs

---

## Phase 1: Demo scope gating (R1) — lowest risk, do first

**Files:** Modify `run_system/core/run_manager.gd`, `run_system/ui/buildings/warehouse_screen.gd`

- [ ] **1.1** Add demo toggle block near the act constants in `run_manager.gd`:
  ```gdscript
  ## ── DEMO BUILD ────────────────────────────────────────────────────────────
  ## Flip DEMO_BUILD to false to restore the full 3-act, all-heroes game.
  const DEMO_BUILD: bool = true
  const DEMO_MAX_ACTS: int = 1
  const DEMO_ALLOWED_HEROES: Array[String] = ["cowboy_bill"]

  func acts_total() -> int:
      return DEMO_MAX_ACTS if DEMO_BUILD else ACTS_TOTAL
  ```
- [ ] **1.2** Route `is_final_act()` and `advance_act()`'s cap through `acts_total()`
  instead of `ACTS_TOTAL` (the only two places that gate "is there a next act").
- [ ] **1.3** In `warehouse_screen.gd` hero picker loop, skip heroes not in
  `RunManager.DEMO_ALLOWED_HEROES` when `RunManager.DEMO_BUILD` is true.
- [ ] **1.4** Smoke gate. Commit: `feat(demo): gate demo to Act 1 + Cowboy Bill behind DEMO_BUILD`

**Acceptance:** Headless boot clean; reading the code, an Act-1 boss win path reaches the
final-act victory branch (no extract modal), and only `cowboy_bill` passes the hero filter.

---

## Phase 2: Main menu / title screen (R2)

**Files:** Create `run_system/ui/main_menu.gd` + `main_menu.tscn`, `assets/translations/ui_menu.csv`;
modify `project.godot`.

- [ ] **2.1** Create `ui_menu.csv` with keys: `MENU_TITLE`, `MENU_PLAY`, `MENU_CONTINUE`,
  `MENU_HOWTO`, `MENU_SETTINGS`, `MENU_QUIT`, `MENU_VERSION` (en + zh). Register it in
  `project.godot` `[internationalization]` translations list.
- [ ] **2.2** Create `main_menu.gd` (`extends Control`, no class_name): code-built UI per the
  modal template — title label, version label, vertical button column. `Play` →
  `change_scene_to_file("res://run_system/ui/home_base_scene.tscn")`. `Continue` →
  disabled unless `RunManager.has_run_save()` (function added Phase 3; until then always
  disabled — defensive `RunManager.has_method("has_run_save") and RunManager.has_run_save()`).
  `How to Play` → instances rules panel (Phase 5; guard with preload-exists check, else hide).
  `Settings` → reuse `settings_panel.gd add_controls`. `Quit` → `get_tree().quit()`.
- [ ] **2.3** Create minimal `main_menu.tscn`: a single `Control` root (full rect) with the
  script attached.
- [ ] **2.4** Point `project.godot` `run/main_scene` to `main_menu.tscn`.
- [ ] **2.5** Smoke gate (boots into main_menu now). Commit:
  `feat(menu): title screen as entry point (Play/Continue/HowTo/Settings/Quit)`

**Acceptance:** Headless boot clean booting main_menu; DataValidator still passes.

---

## Phase 3: In-run save / resume (R3) — highest risk

**Files:** Modify `run_system/core/run_manager.gd`, `run_system/ui/map_scene.gd`,
`run_system/ui/main_menu.gd`, pause panels.

- [ ] **3.1** Add to `run_manager.gd`: `const RUN_SAVE_PATH := "user://run_save.json"`,
  and `save_run()`, `load_run() -> bool`, `has_run_save() -> bool`, `clear_run_save()`.
  Serialize every run var-state field from the spec (hp, deck, attributes incl. base,
  backpack, equipped_items, relics, gem_inventory, xp/level/pending_attr_points,
  current_act/floor/encounter, hero id+data, ascension, map_data, current_node_id,
  visited_node_ids). Mirror `meta_progress.gd` FileAccess + JSON pattern; guard types on load.
- [ ] **3.2** Call `clear_run_save()` at the top of `start_new_run()` and inside
  `_teardown_run()` (covers death/victory/extract).
- [ ] **3.3** Call `save_run()` in `map_scene._ready()` after the map is ready (the
  non-battle checkpoint).
- [ ] **3.4** Enable `Continue` in `main_menu.gd`: on press, `RunManager.load_run()` then
  `change_scene_to_file("res://run_system/ui/map_scene.tscn")`.
- [ ] **3.5** Add "Save & Quit to Menu" button to the pause/settings panel on `map_scene`
  (and battle if low-risk): `save_run()` (map only) → `change_scene_to_file(main_menu)`.
- [ ] **3.6** Headless round-trip check: a one-off `-s` script that calls `start_new_run`,
  `save_run`, mutates state, `load_run`, asserts key fields restored. Then smoke gate.
  Commit: `feat(save): in-run save/resume at map checkpoints + Continue`

**Acceptance:** Round-trip script restores hp/deck/act/floor/map_data/visited; smoke clean.
If round-trip is unreliable → apply the spec's degrade (core fields + regenerate map) and
note it in the report.

---

## Phase 4: Result screens (R4)

**Files:** Create `run_system/ui/result_screen.gd`; modify `battle_scene.gd`, `ui_menu.csv`.

- [ ] **4.1** Add keys to `ui_menu.csv`: `RESULT_DEFEAT_TITLE`, `RESULT_DEFEAT_BODY`,
  `RESULT_DEMO_TITLE`, `RESULT_DEMO_BODY`, `RESULT_WISHLIST`, `RESULT_BACK_TO_MENU` (en+zh).
- [ ] **4.2** Create `result_screen.gd` (`extends Control`, no class_name): full-screen modal,
  `mode` setter (`"defeat"` | `"demo_complete"`), shows title/body + run summary (hero,
  floor, act from RunManager) + a "Back to Menu" button → `change_scene_to_file(main_menu)`.
  Emits nothing; it owns the transition.
- [ ] **4.3** In `battle_scene._game_over()`: instead of the bare 3s wait → home_base, show
  `result_screen` in `"defeat"` mode on a CanvasLayer (layer 130).
- [ ] **4.4** In the boss-victory branch (`_victory()` final-act path) and extract path: show
  `result_screen` in `"demo_complete"` mode instead of routing to home_base.
- [ ] **4.5** Smoke gate. Commit: `feat(ui): defeat + demo-complete result screens`

**Acceptance:** Headless boot clean; code paths for death and Act-1 boss win reach the
result screen and then main_menu.

---

## Phase 5: Lightweight tutorial (R5)

**Files:** Create `run_system/ui/rules_panel.gd`, `battle_scene/ui/tutorial_tips.gd`;
modify `meta_progress.gd`, `main_menu.gd`, pause panels, `battle_scene.gd`, `ui_menu.csv`.

- [ ] **5.1** Add `tutorial_seen: bool` to `meta_progress.gd` (persisted in its JSON payload
  + load + a `mark_tutorial_seen()` setter).
- [ ] **5.2** Add keys to `ui_menu.csv` for rules sections + tip lines (en+zh):
  `RULES_TITLE`, `RULES_ENERGY`, `RULES_CARDS`, `RULES_BLOCK`, `RULES_ATTRS`, `RULES_GEMS`,
  `RULES_BACKPACK`, `RULES_INTENT`, `TIP_1`..`TIP_4`, `TIP_NEXT`, `TIP_DONE`.
- [ ] **5.3** Create `rules_panel.gd` (`extends Control`, no class_name): scrollable full-screen
  panel with the localized sections; ESC / close button → `queue_free()`. Wire it into
  `main_menu` (How to Play) and the map pause panel.
- [ ] **5.4** Create `tutorial_tips.gd` (`extends Control`, no class_name): a sequence of
  center-screen dismissible tip cards (`TIP_1..4`) with Next/Done. Pure center overlay,
  no precise anchoring (degrade-safe).
- [ ] **5.5** In `battle_scene._ready()` (or first-turn start): if
  `not MetaProgress.tutorial_seen`, instance `tutorial_tips` on a CanvasLayer, and call
  `MetaProgress.mark_tutorial_seen()`.
- [ ] **5.6** Smoke gate. Commit: `feat(tutorial): how-to-play panel + first-battle tips`

**Acceptance:** Headless boot clean; rules panel and tips instantiate without error in a
headless `-s` smoke; `tutorial_seen` persists.

---

## Phase 6: Steam export scaffolding (R6)

**Files:** Create `export_presets.cfg`, `steam_appid.txt`, `docs/steam-demo-build.md`.

- [ ] **6.1** Write `steam_appid.txt` containing `480` (Steam test app id placeholder).
- [ ] **6.2** Write a Godot 4.6 Windows Desktop `export_presets.cfg` (x86_64, embedded
  pck, sensible product/file metadata). Note: this file is not read at boot, so it cannot
  affect the smoke gate.
- [ ] **6.3** Write `docs/steam-demo-build.md`: how to install export templates + run the
  export, where `steam_appid.txt` goes in the build folder, and the exact spot to add
  GodotSteam once an App ID exists.
- [ ] **6.4** Smoke gate (unchanged behavior). Commit:
  `chore(build): Windows export preset + steam_appid placeholder + build doc`

**Acceptance:** Smoke clean; files exist and are well-formed.

---

## Phase 7: TODO audit + morning report (R7)

**Files:** Create `docs/superpowers/reports/2026-06-14-demo-prep-report.md`.

- [ ] **7.1** Grep `TODO|FIXME|HACK` across `.gd` (excl. addons); triage demo-blocking vs not.
- [ ] **7.2** Write the report: shipped per phase, deferred + why, per-phase smoke results,
  any degrades applied, remaining road to store submission (audio, art freeze, real
  Steamworks, store page, age rating, QA playthrough).
- [ ] **7.3** Final full smoke gate. If any content JSON changed, regenerate catalog (none
  expected). Commit: `docs: demo-prep morning report + TODO triage`

**Acceptance:** Report exists and is accurate; final smoke clean.

---

## Self-review (planner check)
- **Spec coverage:** R1→P1, R2→P2, R3→P3, R4→P4, R5→P5, R6→P6, R7→P7. All mapped. ✓
- **Dependency order:** Continue button (P2) depends on save (P3) — handled by defensive
  `has_method` guard in P2, enabled in P3.4. Result/tutorial reference main_menu path — exists
  after P2. ✓
- **Rule compliance:** no `class_name` in new scripts; `addons/` untouched; i18n en+zh;
  smoke per phase; no content-JSON schema changes. ✓
- **Naming consistency:** `acts_total()`, `has_run_save()`, `save_run()`, `load_run()`,
  `clear_run_save()`, `mark_tutorial_seen()`, `tutorial_seen` used consistently across phases. ✓
