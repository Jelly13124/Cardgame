# Demo Polish Overnight — Design + Execution Plan

**Date:** 2026-06-24
**Branch:** overnight-0615 (== main as of 806e6a1)
**Mode:** `/goal` autonomous overnight run. Smoke-gate every phase. **Do NOT push.**
**Constraint:** No windowed game launch tonight (owner may be at office + godot MCP is
gopeak/disconnected) → headless smoke + code verification only; visual eyeball deferred to owner.

## Context

A 4-dimension static review of the 2-act Steam demo (DEMO_BUILD, DEMO_MAX_ACTS=2, Cowboy Bill
only) surfaced a prioritized shortcomings list. The owner approved fixing **all** of it, plus an
audio overhaul. This doc is the source of truth + ordered execution plan for the overnight run.

## Decisions (forks resolved with owner)

1. **Economy** — full fix: **99 gold start + per-kill gold drops + shop price retune** (not just 99-start).
2. **Demo length** — **keep 2 acts** → therefore Act 2 must feel *different*, not Act-1 reskins.
3. **New enemies** — **reuse existing sprites + new action patterns** (no new art dependency overnight).
4. **Wishlist CTA** — wire the button to a **placeholder store URL + TODO** (real App ID later; `steam_appid.txt` is 480).
5. **Audio** —
   - **Menu BGM** = real track *Wild West - Desert Wind* (owner-supplied; already converted to `assets/audio/music/menu.ogg`).
   - **Battle / boss / map / home / shop / event BGM** = keep the procedural "code-music" style but **regenerate longer (~60–120s) with seamless loop points** (fixes "too short + obvious loop").
   - **SFX** = replace procedural with **Kenney CC0** samples (consistent with the shipped Kenney UI; kenney.nl reachable).

## Out of scope / blocked

- New enemy/hero **animation frames** (need Codex transparent art) — only reuse existing sprites.
- Real **Steam App ID** + **PixelLab key rotation** — owner actions.
- Cutting to 1 act — owner chose to keep 2.

## Guardrails (every phase)

- After `.gd/.json/.tscn` or asset changes: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` must end `[OK] DataValidator … / [OK] Headless boot clean`.
- After adding/changing binary assets (audio): run `godot --headless --import` so `.import` sidecars generate before smoke.
- New effect/action/status types → register in BOTH the handler AND the `ALLOWED_*` list in `data_validator.gd`.
- New content → wire the pool/roster entry (cards→draft pool, enemies→ELITE_ROSTER/encounter pool, etc.).
- Keep catalogs + PRD/PROJECT_STRUCTURE current (P7).
- Commit per phase (clear messages). **Never push.**

---

## Phases

### P0 — Audio overhaul
**Menu:** `menu.ogg` already = real track (done in setup). Make `gen_audio.py` **stop regenerating menu** (don't clobber the real track).
**Procedural BGM rework (`scripts/gen_audio.py`):** regenerate `battle/boss/map/home` and ADD `shop/event` as **~60–120s** loops with a **seamless loop point** (compose an integer number of bars; match the tail to the head / equal-power crossfade the wrap; keep the existing wasteland-western synth palette). Re-export `.ogg`.
**Wire new BGM slots:** `shop_scene.gd` → `AudioManager.play_music("shop")`; `event_modal.gd` → `play_music("event")` (restore prior on close if needed).
**SFX → Kenney CC0:** download the relevant Kenney audio packs (Interface/UI, Impact, RPG) from kenney.nl; map to the existing ~25 SFX stems in `assets/audio/sfx/*.wav` (keep the exact filenames — `play_sfx` loads `<stem>.wav`); convert to `.wav` as needed (ffmpeg available). Record source + CC0 license in `assets/audio/music/README.md` and a new `assets/audio/sfx/README.md`.
**Verify:** `--headless --import` then smoke; confirm no missing-SFX warnings against the call list.

### P1 — Economy full fix
- **99 gold start:** set the base starting-gold (RunManager run init / Outpost "starting gold" upgrade baseline) so a fresh run begins at 99.
- **Per-kill gold drops:** award gold on enemy death (enemy_ai/enemy_entity death hook → backpack gold), small per-kill amount (elites/boss more), respecting `Junk Magnet` relic.
- **Shop price retune:** rebalance `shop_scene.gd` card/tool/relic prices against the new income so a player can afford ~1–2 shop items per act.
- **Verify:** `content-balance` subagent on the new numbers; smoke. Model a sample act's gold income vs prices in the phase note.

### P2 — Wishlist CTA + demo-end teaser
- `result_screen.gd`: convert the wishlist `Label` → `Button` calling `OS.shell_open(STORE_URL)`; show on **both win and defeat** paths. Add a central `STORE_URL` const with a `# TODO real App ID` placeholder.
- `demo_complete` screen (battle_scene): add a "full game = 3 acts + more heroes" teaser line.
- New/updated strings in `ui_common.csv` (zh + en).
- **Verify:** smoke; grep that `OS.shell_open` now exists and both paths render the CTA.

### P3 — Onboarding / teaching
- `rules_panel.gd` `SECTIONS`: add **Tools, Relics, Equipment, Crit, Base-building**; fill **Luck & Charm** effect text in the attributes section.
- Make the panel reachable beyond title/map: add a "?" button on base / shop / loot screens.
- Strings → `ui_common.csv` (zh + en).
- **Verify:** smoke; confirm new sections render + reachable entry points wired.

### P4 — Combat juice
- **Screen shake:** add a camera/canvas shake scaled by damage (trauma model) in `battle_scene` / `combat_fx.gd`.
- **Small-hit feedback:** remove the `>= 10` gate (`enemy_entity.gd`, `player.gd`) so all HP-damage hits nudge.
- **Number pops:** tween block / status / energy readouts on change (`battle_ui_manager.gd`, `combat_engine.gd`).
- **Enemy death:** fade/scale-poof before `queue_free` (`enemy_entity.gd`).
- **Idle breathe:** subtle scale loop on the static rest sprite (enemy + hero).
- **Verify:** smoke (visual eyeball deferred to owner — no window tonight).

### P5 — Content differentiation (keep 2 acts non-reskin)
- **Elites:** add 2–3 new elite enemies **reusing existing `sprite_id`s** with distinct action patterns; expand `ELITE_ROSTER` (`run_manager.gd`).
- **Act-2 identity:** give Act 2 at least a few exclusive movesets/encounters (reuse sprites) so it isn't Act-1 + ×1.25 HP.
- **Event rate:** raise the "?" event-branch probability (`map_scene.gd`, currently ~8%).
- **Bill builds:** add a **burn payoff** card + an in-pool **crit-rate source** card; wire into Bill's draft pool.
- **Verify:** `data_validator` (new enemies/cards), `content-balance`, catalog regen, smoke.

### P6 — Settings + QoL + hygiene
- **Run-speed toggle:** `Engine.time_scale` setting + UI (`settings.gd`, `settings_panel.gd`, `battle_scene.gd`).
- **Resolution / window-size** option in settings.
- **Legacy save migration:** one-shot `user://meta.json` → `user://slot_1/meta.json` in `MetaProgress`.
- **Doc fix:** `docs/steam-demo-build.md` `DEMO_MAX_ACTS` 1→2.
- **`card_animator.gd`** tween-lifecycle hardening pass (the one hot file unscanned in review).
- **Verify:** smoke.

### P7 — Final verify + catalog + docs + report
- Full smoke + `--headless --import`.
- `python scripts/gen_catalog_html.py` (cards/relics/equipment/enemies/affixes).
- Update PRD + PROJECT_STRUCTURE for new content/systems (audio slots, new enemies/cards, settings, wishlist).
- Write `docs/superpowers/reports/2026-06-24-overnight-report.md` (what shipped, what's deferred, owner follow-ups: real App ID, PixelLab key, visual eyeball of P4, BGM taste check).
- **Optional if time:** Gemini opaque bg for 1 new event + `fortune_shrine` regen.

## Owner follow-ups (left for owner)
- Drop real Steam App ID → swap `STORE_URL` + `steam_appid.txt`.
- Rotate the leaked PixelLab key (PixelLab side).
- Eyeball P4 juice + the reworked BGM taste tomorrow.
