# Overnight Run — Combat Depth & Content (2026-06-18)

**Mode:** unattended overnight. Commit each phase (smoke-gated). **Do NOT push.**
Morning report at the end. Owner-locked forks below.

## Locked decisions (from owner)
- **Commit-only, no push.**
- **Enemy difficulty: noticeably harder** (StS-style real pressure; debuffs + self-buff
  + charge/telegraph; not unfair).
- **New content: modest** (a few cards + relics + equipment + 1-2 enemy variants;
  data-only, reuse/borrow art with audit flags — NO art-gated brand-new enemies).
- **Luck → gold removed** (owner-confirmed).
- **Frail flipped to enemy→player** (gives Frail teeth; repurpose player Frail cards).

## EXCLUDED (do NOT touch this run)
- **Charm.** Owner wants to discuss the new "execute/intimidate threshold" idea
  (low-HP enemies flee = win, scaling with Charm). Leave Charm entirely as-is.

## Phases (priority order — bank settled high-value work first)
1. **Luck → gold removal** (tiny): drop `luck_gold_mult` from post-battle gold.
2. **Demo bug fixes**: top bar `幕 1/3` → `acts_total()` (shows `/2` in demo);
   New-Game on an in-progress slot warns before overwrite.
3. **Enemy threat overhaul** (CORE, data-only): rework all 15 enemies' action
   patterns — more apply Weak/Vulnerable/Frail, add self-buff/charge/telegraph,
   per-act scaling. Make Act 1 teach, Act 2 pressure.
4. **Frail flip + status cleanup**: Frail becomes an enemy→player debuff (−block
   gained, real pressure); repurpose player Frail cards (corrode/purge) to
   Vulnerable/Weak. Audit every status for "is it actually used + useful."
5. **New content (modest)**: a few cards + relics + equipment + 1-2 enemy variants.
6. **Reward-screen reroll**: a spendable `rerolls` resource (default 0); reroll
   button on the reward screen; sources = a base upgrade + an equipment affix.
7. **Map/Battle toggle + return-to-battle bug** (most uncertain — do LAST, after
   the codebase is mapped): currently leaving a battle to the map auto-wins / can't
   return. Make the switch non-destructive: peek the map and return to the ongoing
   battle. If the safe fix is unclear, at minimum stop the auto-win and flag it.
8. **Balance pass + finish**: content-balance subagent over all changes; MCP 2-act
   difficulty sanity; regen catalogs + docs; full QA smoke; write morning report.
9. **Tail (if time):** more enemy variety / cards / balance tuning until dry.

## Guardrails
- Smoke-gate (`GODOT_BIN=C:/Program Files/Godot/Godot.exe bash scripts/smoke_test.sh`)
  + `--headless --import` parse check after every phase. Never commit a red gate.
- Reuse existing statuses/effects; register any new effect/status in BOTH the handler
  AND `data_validator.gd` (the two-place rule).
- Verify behavior live via Godot MCP where it matters (enemy patterns, reroll, toggle).
- Anything that needs new art → flag in `docs/art/needed-assets.md`, don't block on it.
- Log any cap/skip rather than silently truncating.
