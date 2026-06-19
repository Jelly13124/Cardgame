# Overnight Run — Combat Depth & Content — Morning Report (2026-06-18)

**Branch:** `overnight-0615`. **Commit-only, NOT pushed** (per owner). Plan/contract:
`docs/superpowers/plans/2026-06-18-overnight-combat-depth.md`.

## TL;DR
Shipped **8 commits**, each smoke-gated (`DataValidator` + clean headless boot) and
the risky bits **MCP-verified live**. The demo's combat is now noticeably harder and
the reward screen has a working reroll. Two wishlist items were deliberately
**deferred** (Charm rework, map/battle toggle) — see "Deferred & why".

## What shipped (each smoke-gated)

| Commit | What |
|---|---|
| `6abc879` | **Luck → gold removed.** Post-battle gold is flat 10 (was `10×luck_gold_mult`); removed the dead `luck_gold_mult()`/`GOLD_PER_LUCK` and the "+gold" line from every Luck description. Luck = crit + loot rarity + gems. |
| `200def8` | **Top-bar act count fix.** Was `幕 X/3` (full game's `ACTS_TOTAL`) even in the 2-act demo; now `RunManager.acts_total()` → reads `幕 X/2`. (The new-game overwrite confirm the owner asked about **already existed** via `_confirm_overwrite`/`slot_exists`.) |
| `5f98620` | **Enemy threat pass.** 6 plain enemies + the Act-1 boss now apply real pressure: rust_brute→Frail, slag_walker→Vulnerable, trash_robot→Weak, wasteland_killer→telegraphed 17 SNIPE, armored_patrol (elite)→Frail, rust_titan (boss)→Vulnerable+Frail in P1, Thorns enrage <50% HP. No new action types (reuse attack_status/telegraph/buff_self). |
| `e8666e2` | **Frail flipped to enemy→player.** Frail on enemies did nothing (they don't gain Block); now it's an enemy tool that punishes the player's Block (the player's card Block already respects Frail via `gain_block`). Player Frail cards repurposed: Corrode 2 Frail→2 Vulnerable, Purge 1 Frail→1 Vulnerable. Also fixed the stale "Intelligence: reserved/no effect" tooltip (INT = +5% XP + scales Bleed). |
| `4ed8139` | **2 enemy variants** (reuse sprites): Riot Hound Alpha (Weak + Metallicize plate-up), Siege Mortar (Vulnerable + telegraphed 16 BARRAGE). Added to the LATE pool → appear in Act 2. |
| `0f5a637` | **Intimidator Plate** relic (uncommon: attacks also apply 1 Weak) + **2 equipment** (Reinforced Plating +1 CON, Combat Harness +1 STR/+1 CON). Existing mechanics, reused art. |
| `5205159` | **Reward card-draft reroll.** A `刷新 (N)` button on the card draft re-rolls the 3 cards, spending `RunManager.reward_rerolls` (default 0). Source: new **Reroll Tokens** Outpost upgrade (1/2/3 per tier). Reset each run + saved/loaded. |
| `d01103a` | Catalog regen (50 cards, 29 relics, 17 enemies, 23 equipment). |

## Live verification (Godot MCP)
- **Frail-flip:** in a real fight, enemy applied Frail → player Frail icon shows,
  `get_block_multiplier()` → 0.75 ✓. Corrode confirmed → Vulnerable ✓.
- **Act label:** battle top bar reads `幕 1/2` ✓.
- **Reward reroll:** killed an enemy → reward screen showed flat `10 金币` (Luck-gold
  removal ✓), opened the card draft → `刷新（3）` button rendered; pressing it spent
  to `刷新（2）` and re-rolled the cards; grant from the upgrade (lvl 2 → 2 rerolls)
  and save/load round-trip both verified ✓.

## Deferred & why
1. **Charm.** Owner said "let's discuss Charm again" + floated a NEW idea (Charm raises
   an **execute/intimidate threshold** — low-HP enemies flee = win). That's a genuinely
   good, distinct identity but undecided, so it was kept entirely out of the unattended
   run. Left exactly as-is. Worth a short design chat.
2. **Map/Battle toggle.** Investigated: the battle top-bar's "返回地图" button
   (`battle_scene/ui/battle_top_bar.gd:150` `_on_return_map_pressed`) does
   `change_scene_to_file(map)` — it **tears down the in-progress battle**. Because the
   node was already marked visited on click, you then **skip the fight** ("default win").
   The owner wants this to become a real **toggle** (peek the map, return to the ongoing
   fight). That needs a UX decision + battle-state preservation (a modal map overlay, or
   suspend/restore), so I did **not** build it unattended. Recommendation: a modal
   map-peek overlay that never tears down `BattleScene` (cheapest, no state to save). If
   you'd rather just close the exploit fast, disable/remove the return-map button during
   an active battle (1-line). Your call on the UX.

## Balance check
The `content-balance` subagent reviewed every new/changed item against the existing
curve. **Verdict: all on-curve — zero number/rarity fixes required.** Two judgment
calls (designer's choice; both left as-is, flagged for you):
- **wasteland_killer placement.** Its telegraphed 17 SNIPE is itself on-curve
  (telegraphed + interruptible, like mortar_cart's AoE channel), but it sits **solo in
  `ENCOUNTER_POOLS_EARLY`**, so the burst can land on Act-1 floors 1–3 — the spikiest
  first impression. It's survivable (one Brace Protocol fully eats it, or kill the
  20-HP body during the wind-up) and the telegraph makes it a teaching moment. Left
  as-is (matches "noticeably harder + teaches block/stun"); **move it to the MID pool**
  if early first-fight spikes feel unfair to new players.
- **intimidator_plate rarity.** Uncommon is correct — Weak **decays 1/turn**, so it does
  NOT permanently stack (despite first appearances). Bump to rare only if single-target
  lockdown proves too strong in play.
Corrode/Purge, both equipment, both enemy variants, and the elite/boss reworks all sit
squarely in-band.

## Art still owed (reused placeholders flagged)
Tonight's new content reuses existing art (game-ready, but not bespoke):
- Relic **Intimidator Plate** → reuses `barbed_plating.png` icon.
- Equipment **Reinforced Plating** → `scrap_breastplate.png`; **Combat Harness** → `lucky_charm.png`.
- Enemy variants **Riot Hound Alpha** / **Siege Mortar** → reuse `riot_hound` / `mortar_cart` sprites (intentional same-sprite variants; distinct art optional).

## Recommended next steps
1. Manual play a full 2-act run to feel the new difficulty (the threat pass + variants).
2. Decide the **Map/Battle** UX (peek-toggle vs close-the-exploit) — I can build it fast once you pick.
3. Charm design chat (the execute-threshold idea).
4. Review + `push` when happy (everything is local, unpushed).

## Post-report (same day) — both deferred items BUILT + verified
Owner picked the directions, so both were implemented after the overnight:
- **Charm = low-HP flee** (`261ffe5`). Non-boss/elite enemies flee once HP ≤
  Charm×2% of max (cap 30%, 0 at Charm 0); fleeing counts as a kill (loot/XP/win).
  Charm now has a combat identity. Verified live (flee→win; boss/elite/charm-0 immune).
- **Map peek overlay** (`228308f`). The battle "return to map" button now opens the
  map as a read-only modal overlay (peek_mode: no travel/save/music-swap) with a
  "返回战斗" button — fixes the skip-the-fight exploit. Verified live (battle stays
  alive underneath; back-to-battle returns to the same fight).
