# Steam Demo Prep — Spec

**Date:** 2026-06-14
**Branch:** `demo-prep`
**Author:** Claude (autonomous overnight run, approved by project owner)

## Goal

Close the gap between the current (mechanically-complete) build and a **shippable Steam
demo**, covering everything from the diagnosis EXCEPT audio (owner will source audio
separately). The game already has 65 cards / 15 enemies / 3 bosses / 23 relics /
24 equipment / 8 gems / 2 heroes / 8 events / zh+en i18n — content is NOT the gap.
The gap is the "shell + polish" layer.

## Owner decisions (locked 2026-06-14)

| Topic | Decision |
|---|---|
| Steam integration | **Export preset + placeholder only.** Windows export preset + `steam_appid.txt` placeholder. NO GodotSteam binary (no App ID yet). |
| Demo scope | **Act 1 + Cowboy Bill only.** |
| Tutorial | **Lightweight:** a "How to Play" rules panel + first-battle tip bubbles. No forced step-locked tutorial. |
| Output | **Commit per phase to `demo-prep`, do NOT push.** Morning report at the end. |
| In-run save | Save & quit → continue, **map / non-battle checkpoints only** (quitting mid-battle loses that battle, resumes at the map). |
| Result screens | Add "You Died" + "Demo Complete / Wishlist" screens, replacing the current silent route-back-to-base. |
| Main menu | Title → New Game / Continue / Settings / Quit + language. Reuses `settings_panel.gd`. |
| Audio | **Out of scope.** |
| Art | **Out of scope** (art freeze is owner/Codex). |

## Non-negotiable project rules honored

- Data-driven where applicable; **`class_name` banned for new scripts — use `preload`** (ADR-0006).
- `addons/` not hand-edited. No new content JSON that bypasses `data_validator.gd`.
- Each phase passes `scripts/smoke_test.sh` (GODOT_BIN=`C:/Program Files/Godot/Godot.exe`).
- New UI text goes into `assets/translations/*.csv` with **both en + zh** columns.
- Reuse `run_system/ui/theme/wasteland_theme.gd` for styling; copy the existing modal pattern.

## Requirements

### R1 — Demo scope gating (Act 1 + Bill)
- A single, clearly-commented **demo toggle** in `RunManager` so the full 3-act game is one flip away.
- Act 1 boss victory = run victory (no extract-vs-push choice, since Act 1 is the final act in demo).
- Hero picker (Warehouse) shows only `cowboy_bill`.

### R2 — Main menu / title screen
- New scene becomes `project.godot` `main_scene`.
- Buttons: **Play** (→ home base hub), **Continue** (resume saved run; disabled if none),
  **How to Play** (rules panel), **Settings** (existing settings panel), **Quit**.
- Title text + version label; styled with wasteland theme.

### R3 — In-run save / resume
- `RunManager.save_run()` / `load_run()` / `has_run_save()` / `clear_run_save()`,
  path `user://run_save.json`, mirroring the `meta_progress.gd` JSON pattern.
- Serializes all run var-state incl. `map_data`, `current_node_id`, `visited_node_ids`,
  deck, attributes, backpack, equipped, relics, gems, xp/level, act/floor, hp.
- **Checkpoint = map_scene load.** Save when the map is shown; clear on run end / new run.
- A "Save & Quit to Menu" action in the pause (settings) panel.
- Title "Continue" loads the save and jumps to `map_scene`.

### R4 — Result screens
- **Defeat screen:** shown on death; run summary (hero, floor reached, act); button → menu.
- **Demo-complete screen:** shown on Act 1 boss victory (or extract); "Thanks for playing
  the demo / Wishlist on Steam" message; button → menu.
- Both clear the in-run save.

### R5 — Lightweight tutorial
- **Rules panel:** reusable `Control` describing energy, card types & how to play them,
  block reset, the five attributes, gems, extraction backpack, enemy intents. Openable
  from the title menu and the pause panel.
- **First-battle tips:** a short sequence of dismissible center-screen tip cards on the
  player's first-ever battle, gated by a `MetaProgress` flag so it shows once.

### R6 — Steam export
- Hand-authored `export_presets.cfg` (Windows Desktop, x86_64).
- `steam_appid.txt` placeholder (`480`) at project root.
- `docs/steam-demo-build.md` documenting how to finish the export + where Steamworks plugs in later.

### R7 — TODO audit + morning report
- Grep the ~27 TODO/FIXME markers; flag any demo-blocking ones.
- `docs/superpowers/reports/2026-06-14-demo-prep-report.md`: what shipped, what was
  deferred (and why), per-phase smoke results, and the remaining road to store submission.

## Out of scope (explicit)
- Audio (music/SFX).
- Art generation / freeze.
- Real Steamworks SDK integration (achievements, overlay, cloud) — preset/placeholder only.
- A forced step-locked tutorial.
- Pushing to remote.

## Risk register & degrade strategy
- **In-run save (R3)** is the most complex. If full map-state round-trip proves unreliable
  under the smoke gate, degrade to: save HP/deck/attributes/act/floor and regenerate a fresh
  map on resume (note it in the report). Never ship a half-working save that corrupts state.
- **First-battle tips (R5)** are fuzziest. If precise anchoring is fiddly, degrade to
  center-screen sequential tips (no arrows). If still flaky, degrade to auto-showing the
  rules panel once on first run.
- **export_presets.cfg (R6)** never loads at boot, so a malformed file can't break the
  smoke gate — but validate the format against Godot 4.6 docs; if uncertain, ship the doc
  + appid and leave preset generation as a documented manual step.
- Any task that can't pass smoke is left as a committed-but-disabled stub + a TODO + a
  report entry — not forced in.
