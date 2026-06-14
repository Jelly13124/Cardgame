# Steam Demo Prep — Morning Report

**Date:** 2026-06-14 (overnight autonomous run)
**Branch:** `demo-prep` (off `hero-refinement-v2`) — **not pushed**, per owner.
**Spec:** `docs/superpowers/specs/2026-06-14-steam-demo-prep-spec.md`
**Plan:** `docs/superpowers/plans/2026-06-14-steam-demo-prep.md`

## TL;DR

All 7 planned phases shipped and committed. Every phase passed the headless smoke
gate; the two riskiest systems (in-run save/resume, result/tutorial UI) were
additionally verified live via the Godot MCP (real boot + scripted round-trips).
**No degrades were needed** — the full scope landed. Audio and final art remain
out of scope (owner-owned). Nothing was pushed.

## What shipped, per phase

| Phase | Commit | Result |
|---|---|---|
| 0 — Spec + plan | `395d537` | Spec + plan docs |
| 1 — Demo gating (Act 1 + Bill) | `5b06576` | `DEMO_BUILD` toggle in RunManager; `acts_total()` caps the run; Warehouse hero filter |
| 2 — Title screen | `5097f90` | `main_menu` is now `main_scene`; Play / Continue / How-to / Settings / Quit; en+zh strings |
| 3 — In-run save/resume | `2b5ee8d` | `save_run`/`load_run`/`has_run_save`/`clear_run_save`; map-checkpoint saves; Continue + Save&Quit |
| 4 — Result screens | `d4090d8` | Defeat + demo-complete/wishlist screens; demo-aware extract gating |
| 5 — Lightweight tutorial | `abd76a3` | How-to-Play rules panel + first-battle tips; persisted `tutorial_seen` |
| 6 — Steam export scaffolding | `d99d47d` | `steam_appid.txt` (480) + build doc; export preset on disk (gitignored) |
| 7 — TODO audit + report | (this) | Triage below; final smoke clean |

## Verification

- **Smoke gate** (`scripts/smoke_test.sh`, `GODOT_BIN=C:/Program Files/Godot/Godot.exe`)
  passed after **every** phase: `all schemas passed` + clean headless boot.
- **In-run save round-trip** (live, MCP): started a run, mutated hp/floor/xp/level/
  gems/map/node, saved, clobbered state, loaded — all fields restored, the map
  `_node_index` rebuilt, and `clear_run_save` removed the file. ✅
- **Result screens** (live, MCP): both `defeat` and `demo_complete` instantiated
  with no runtime error. ✅
- **Tutorial** (live, MCP): rules panel + tip sequence built and advanced cleanly;
  `mark_tutorial_seen()` flips and persists the flag. ✅

## Deviations from the plan (all minor, all intentional)

1. **i18n keys live in `ui_common.csv`, not a new `ui_menu.csv`.** Reusing the
   already-registered, already-imported CSV avoided bootstrapping a new `.import`
   file + UID at 3am unattended. All `MENU_*/RESULT_*/RULES_*/TIP_*/SETTINGS_SAVE_QUIT`
   keys (en+zh) are there. Compiled `.translation` files are gitignored (project
   convention) and regenerate on `--import`.
2. **`export_presets.cfg` is gitignored** (`.gitignore` line 8 — standard Godot
   practice). The working file sits on disk (usable now); its canonical content is
   embedded in `docs/steam-demo-build.md` so any clone can recreate it.
3. **A working title — "Wasteland Salvage" — was used as a placeholder.** The game
   has no finalized name (`config/name="CardFramework"`, PRD says "Unnamed"). The
   title + version strings are in `ui_common.csv` (`MENU_TITLE`/`MENU_VERSION`) and
   trivial to change. **Owner decision needed: final game name.**

## TODO / placeholder triage (Phase 7)

- Real code TODOs (excl. vendored `addons/`): **1** — `run_manager.gd:1750`
  ("base-building Core retention"), a future-feature note, **not demo-blocking**.
- The ~25 "placeholder" hits are all benign: Codex **art** placeholders (icons,
  building backgrounds, frames) and **intentionally-gated** UI buttons
  (`disabled = true` on locked shop/clinic/market slots, tier-gated buildings).
  None are bugs.
- **No demo-blocking TODOs found.**

## Remaining road to a shippable Steam demo (owner / external)

These are the gaps this run could **not** close (by scope or because they need
external resources / decisions):

1. **Audio (out of scope).** Still 0 audio files. BGM (battle/map/base) + core SFX
   (card play, hit, crit, UI, win/lose). `Settings.master_volume` already exists and
   will drive the Master bus once buses/streams are added.
2. **Final art freeze.** A pile of `generated_sheet/` intermediates + enemy-attack
   redos are still in flight (uncommitted on `hero-refinement-v2`). Pick and lock a
   demo art set; the title screen also wants a proper key-art backdrop (currently
   reuses `wasteland_battlefield.png`).
3. **Real Steamworks integration.** Needs a Steam **App ID**, then GodotSteam +
   `steam_appid.txt` swap (steps in `docs/steam-demo-build.md`). Not required for a
   runnable build, but required for the actual Steam "Demo" app + achievements.
4. **Final game name** (see deviation #3).
5. **Store page + submission.** Capsule art, screenshots, trailer, age-rating
   questionnaire, privacy policy — all Steamworks-side, not code.
6. **Full QA playthrough.** Smoke verifies boot + the new systems in isolation; it
   does **not** verify a complete Act-1 run end-to-end. Recommend a manual play
   session (and a save→quit→continue mid-run) before building the demo.

## How to flip back to the full game

Set `RunManager.DEMO_BUILD = false` (`run_system/core/run_manager.gd`). That
restores all 3 acts (extract-vs-push choice returns) and all heroes in the
Warehouse. Everything else (menu, save, result screens, tutorial) is demo-agnostic
and stays.

## Notes for the owner

- The branch is `demo-prep`; review `git log hero-refinement-v2..demo-prep` for the
  7 commits. Nothing was pushed.
- The pre-existing Codex WIP + art on `hero-refinement-v2` was left untouched and
  uncommitted, as before.
