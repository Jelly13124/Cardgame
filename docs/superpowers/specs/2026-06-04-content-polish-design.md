# Content Expansion + Polish — Design

> Overnight build, lowest-risk tier (runs after Hero + Economy). Pure JSON/i18n
> content plus a code-quality sweep. Card/relic art is Codex's; logic functions
> without it.

## Part A — Content expansion (around the new statuses)

Add general-pool content that exercises the statuses shipped earlier
(`regen` / `thorns` / `frail` / `dodge`). NOT polarity cards (those belong to the
hero spec). All new cards/relics added to their pools + i18n (en/zh), then run
`content-balance` and fix outliers before commit.

**New cards** (neutral, general draft pool — `MetaProgress.INITIAL_CARD_POOL`),
cost/numbers are starting points for the balance pass; add `_plus` variants:
- `venom_coat` — skill, common, cost 1: gain_block 4 + apply_status_self thorns 2.
- `purge` — skill, uncommon, cost 1: apply_status frail 2 to target + apply_status weak 1.
- `second_wind` — skill, uncommon, cost 1: gain_block 5 + apply_status_self regen 2.
- `smoke_step` — skill, rare, cost 1: apply_status_self dodge 1 (the rare player
  source of Dodge — keep it rare per the established design that Dodge is scarce
  for the player). Consider `exhaust_self` to keep it from being spammed.

**New relics** (JSON in `run_system/data/relics/`, add to droppable pool, en/zh):
- `barbed_plating` (common): at player_turn_start, gain thorns 1. (Reuses the
  status system; needs a relic effect that applies a self-status at turn start —
  add the handler + validator entry if not present.)
- `medkit_drone` (uncommon): on combat_victory, heal a small flat amount (relic
  `heal` trigger already exists — confirm and reuse).

**New random events** (`run_system/data/random_events/`, +en/zh i18n, follow the
existing 6-event schema + validator): add 2 events with attribute-gated options
(luck/charm), themed to fit the wasteland; reward Caps where it fits the new
economy (small) so events tie into the currency.

## Part B — Polish + tech debt

Run a focused cleanup over THIS session's changes (the `1169c26..HEAD` range plus
the overnight commits), not the whole repo:
- `/simplify`-style pass: dedupe, simplify, remove dead code introduced recently.
  Notably re-evaluate any now-unused helpers from the hurt-frame removal and the
  card-overhaul (`scaling` remnants), and the `MAX_ANIMATION_FRAMES` usage.
- Verify no leftover references to removed systems (hurt frames, Jerry hero).
- Keep behavior identical; this is quality-only. Skip anything that would change
  intended behavior (note skips).

## Smoke / gates
`bash scripts/smoke_test.sh` after each task; `content-balance` on new cards/relics;
`gdscript-reviewer` on any new effect/relic handlers. Commit per task. No push.

## Out of scope
Art; balance of the yin/yang hero (its own spec); pushing.
