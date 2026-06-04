# Overnight Build Plan — Hero → Economy → Content → Polish

> Executes the three 2026-06-04 specs (yinyang-hero, economy-caps-base-overhaul,
> content-polish). Run by a controller (subagent-driven-development): one fresh
> implementer subagent per task, SEQUENTIAL (shared files — no parallel edits),
> smoke-gate + commit after each. New content runs content-balance; new handlers
> run gdscript-reviewer. **No push.** Priority order below is the build order; if
> the night runs short, earlier tasks must be green+committed first.

Gate: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
→ tail `[OK] DataValidator: all schemas passed.` CSV edits → reimport
(`Godot --headless --path . --import`) before smoke.

---

## A. YIN/YANG HERO  (spec: yinyang-hero-design.md)

- [ ] **H1 — Polarity state + validator.** player.gd: `current_polarity`,
  `_polarities_seen`, `harmony_active`, `set_polarity`/`flip_polarity`/
  `reset_polarity_turn`/`_check_harmony`/`is_card_matched`. data_validator:
  `polarity` enum field, `matched_bonus` (array of valid effects), `flip_polarity`
  effect type, `set_polarity_alternating` relic effect type. Smoke + commit.
- [ ] **H2 — Combat + relic hooks.** combat_engine: `flip_polarity` handler
  (flip + on new harmony grant +1 energy & draw 1 & notify); after a card's
  `effects`, if `player.is_card_matched(card.polarity)` resolve its
  `matched_bonus` via `_apply_effect`. relic_effect_system: handle
  `set_polarity_alternating` at player_turn_start (round parity → reset_polarity_turn,
  refresh HUD). gdscript-reviewer + smoke + commit.
- [ ] **H3 — Hero + relic + rewire.** Add `hero_fengshui_master.json` +
  `yin_yang_compass.json`; remove `hero_jerry_killer.json`; rewire hero_select,
  the unlock base-upgrade (repoint to fengshui), and ensure compass is NOT in the
  droppable relic pool. i18n hero name/desc + relic. Smoke + commit.
- [ ] **H4 — Hero cards.** 6 cards (yin_crescent_cut, yin_still_water,
  yang_solar_strike, yang_ember_will, taiji_shift, taiji_pivot) + `_plus`; add to
  INITIAL_CARD_POOL; en/zh i18n with polarity-clear descriptions. content-balance
  + smoke + commit.
- [ ] **H5 — Polarity HUD.** battle_scene `update_polarity_hud()` (阴/阳/调和
  badge near player HUD, colored; hidden when polarity==""); call on turn start /
  flip / harmony. i18n. Smoke + commit. (Owner verifies visually.)

## B. ECONOMY / BASE  (spec: economy-caps-base-overhaul-design.md)

- [ ] **E1 — Caps plumbing.** MetaProgress `caps` + back-compat save/load +
  add_caps/spend_caps + caps_changed signal. gdscript-reviewer (save migration) +
  smoke + commit.
- [ ] **E2 — Caps earning.** RunManager: combat/elite/boss awards + extraction
  gold→caps conversion, banked like Core (death banks none). Tunable consts.
  smoke + commit.
- [ ] **E3 — Core harder.** Raise base-upgrade Core costs (~1.6–2×); cut boss Core
  reward ~30–40%. Document old→new. smoke + commit.
- [ ] **E4 — Cyber Doctor + caps perks.** `cyber_doc` facility (300 Core unlock) +
  generic caps-perk model (levels, escalating cost, buy) + 5 attribute perks +
  run-start consumer adding bought levels to base_attributes. gdscript-reviewer +
  smoke + commit.
- [ ] **E5 — Home base UI.** Two-layer home_base_scene: Core+Caps balances,
  facility lock/unlock (Core), Cyber Doctor caps-perk shop, live refresh, higher
  costs reflected. Smoke (boot). commit. (Owner verifies visually.)

## C. CONTENT  (spec: content-polish-design.md, Part A)

- [ ] **C1 — Status cards.** venom_coat, purge, second_wind, smoke_step + `_plus`;
  pool + i18n. content-balance + smoke + commit.
- [ ] **C2 — Status relics.** barbed_plating (turn-start self-thorns; add handler
  + validator if needed), medkit_drone (victory heal, reuse existing). pool + i18n.
  gdscript-reviewer + smoke + commit.
- [ ] **C3 — Events.** 2 new random events (attribute-gated, small Caps reward) +
  en/zh i18n, matching the existing schema/validator. smoke + commit.

## D. POLISH  (spec: content-polish-design.md, Part B)

- [ ] **P1 — Cleanup.** Focused simplify/dead-code pass over this session's
  changes (hurt-frame remnants, `scaling` remnants, unused helpers); verify no
  refs to removed systems (hurt frames, Jerry). Behavior-preserving. smoke + commit.

---

## Final
- [ ] Full smoke green. Leave everything committed locally (NO push).
- [ ] Write a morning summary: tasks done / skipped (+reasons) / what needs owner
  visual verification (hero HUD, base UI) / Codex art TODOs (hero sprite, hero
  card art, caps icon, new card art).
