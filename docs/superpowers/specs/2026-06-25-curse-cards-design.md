# Curse Cards — Design (2026-06-25)

A new **Curse** card type (StS2-style junk cards): unplayable negative cards added to the
deck/hand by other cards, events, and enemies, plus enemies that inflict them.

**Grounding (StS1/StS2):** Curses are unplayable detrimental cards. *Permanent* curses
(events/cards) stay in the deck until removed; *temporary* junk (enemy-given, StS "Status")
lives only in the current combat. Many curses carry an end-of-turn-in-hand penalty.
Refs: [StS Wiki — Curse](https://slay-the-spire.fandom.com/wiki/Curse),
[StS2 Cards](https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:Cards).

**Owner decisions:** enemy curses = **temporary** (combat-only); curse effects = **mix**
(some pure dead-weight, some end-turn penalty); scope = **standard** (type + 5 curses +
1–2 curse enemies + all 3 sources). No curse relic / Transform / play-curse relic in v1.

## Our card system (grounding)

- Card types today: `attack` / `skill` / `ability` (`ALLOWED_CARD_TYPES`, `data_validator.gd`).
  Card JSON: `name,title,rarity,type,cost,description,front_image,side,effects` (+ `polarity`,
  `retain`). No `unplayable` / `status` / `curse` / end-turn-in-hand concept yet.
- **`add_card_to_hand`** card-effect already exists (`combat_engine._apply_effect` →
  `deck_manager.add_card_to_hand`) — spawns a card straight into hand.
- **Unplayable pattern already exists**: an out-of-ammo attack is returned to hand + a toast
  (`battle_scene.play_spell` ~L961). Curses reuse this path.
- **Card removal exists**: shop `purchase_card_removal(uid, 75g)` — so permanent curses are
  clearable.
- Enemy actions (`ALLOWED_ENEMY_ACTION_TYPES`): attack/attack_status/attack_all/block/heal/
  telegraph/summon/buff_self — **no add-card** → new action needed.
- Event effects (`ALLOWED_EVENT_EFFECT_TYPES`): gain_gold/lose_hp/heal/gain_core/gain_relic/
  gain_equipment/gain_attribute — **no add-curse** → new effect needed.

## 1. Card type `curse` + schema additions

- Add `"curse"` to `ALLOWED_CARD_TYPES`.
- New optional card keys (validated, default off):
  - `"unplayable": true` — the card cannot be played. `play_spell` checks it first: return the
    card to hand + show `UI_BATTLE_CURSE_UNPLAYABLE` ("诅咒牌无法打出"). Reuses the ammo-fail path.
  - `"end_turn_in_hand": [ <effect>, … ]` — effects applied **to the player** at end of turn
    while this card sits in hand (the curse's penalty). Each entry reuses the combat effect
    system (see §3). Optional; pure curses omit it.
- Curse cards live in `battle_scene/card_info/player/` like other cards (so the factory loads
  them by id). `cost` is irrelevant for unplayable curses — set `0`; `side` = `"player"`.
- Curses are **excluded from every normal card pool** — draft/reward/level-up/shop/unlock
  never offer a `type=="curse"` card. They appear ONLY via the three curse sources.

## 2. The curse set (5 — mix)

| id | name (zh) | unplayable | end-of-turn-in-hand penalty |
|---|---|---|---|
| `radiation_dust` | 辐射尘 | ✓ | — (pure dead weight) |
| `leaking_wealth` | 漏财 | ✓ | **lose 5 gold** |
| `rust` | 铁锈 | ✓ | **lose 2 HP** |
| `cowardice` | 怯懦 | ✓ | **gain 1 Weak** |
| `panic` | 恐慌 | ✓ | **gain 1 Frail** |

Penalties reuse existing combat effect machinery where possible (Weak/Frail via
`apply_status_self`; HP via the self-damage path); **`lose_gold` is a new effect type** (§3).
Mix balance: 1 pure (辐射尘) + 4 penalty.

## 3. End-of-turn-in-hand trigger + the `lose_gold` effect

- Hook: in `battle_scene._on_end_round_button_pressed`, **before** the hand is discarded, scan
  the hand for cards whose data has `end_turn_in_hand`; for each, apply each listed effect to
  the player via the existing `combat_engine._apply_effect` (target = player).
- Effect types used (verified against `combat_engine._apply_effect`): **reuse `lose_hp`**
  (`player.lose_hp`, blood-cost path) for HP and **`apply_status_self`** for Weak/Frail — both
  already exist. Gold is **backpack-stacked** (not a plain int) and the existing `gain_gold` is
  gain-only (`try_gain_gold`), so add a **new `lose_gold`** effect → `RunManager.spend_gold(amount)`
  (the clamping removal path; no-op if the player can't afford it) + register in
  `ALLOWED_EFFECT_TYPES`. A short toast names the curse that bit you.
- Curses with `end_turn_in_hand` are discarded with the rest of the hand afterward (so the
  penalty is "per turn you fail to clear it from hand", matching StS).

## 4. Three sources (the source decides permanence)

- **Enemy → temporary.** New enemy action **`add_curse`** (`{type:"add_curse", curse:"<id>",
  amount:1}` or a small random pool). Handler in `enemy_ai`: shuffle `amount` copies of the
  curse into the player's **draw pile** (a `deck_manager.add_card_to_draw` helper; add if
  absent). Combat-scoped: the draw pile is rebuilt from the run deck each fight, so enemy
  curses vanish after combat. Telegraphed like other enemy moves.
- **Event → permanent.** New event effect **`add_curse`** (`{type:"add_curse", curse:"<id>"}`).
  Handler adds the curse to `RunManager.player_deck` (permanent; clearable at the shop). Ship
  one event that grants a curse for a reward (e.g. "撬开发光的保险箱:拿一笔钱,但染上一张诅咒").
- **Card → either.** A card's `effects` can add a curse:
  - temporary: `add_card_to_hand` with a curse id (exists, no new code).
  - permanent: new card effect **`add_curse_to_deck`** (`{type, curse, amount}`) →
    `RunManager.add_card_to_deck(curse_id)`. (Used by rare "double-edged" cards — none shipped
    in v1 unless desired; the effect is wired + validated so future cards can use it.)

## 5. Curse-inflicting enemies (1–2)

- **1 dedicated curse enemy** (new JSON), reusing an existing sprite (ADR-0005 reuse approach —
  pick a caster/critter at implementation, e.g. a small drone/leech), with a telegraphed
  `add_curse` move (shuffles 辐射尘 or 铁锈 into your draw pile) mixed with a weak attack.
  Working name **`hex_drone` 咒术机蛭**.
- Optional 2nd: add an `add_curse` move to one existing elite's pattern (no new sprite).
- **Wiring (CLAUDE.md rule 3):** new enemy needs an encounter-pool / roster entry (act-1 normal
  pool). content-balance pass before shipping (a curse-spammer must not be oppressive at A0).

## 6. Removal / persistence

- **Permanent** curses (event / `add_curse_to_deck`) → in `RunManager.player_deck` → removable
  via the shop's existing card-removal (75 g). No new removal UI.
- **Temporary** curses (enemy) → live only in the combat piles; gone next combat. No cleanup
  code needed (piles rebuild from `player_deck`).

## 7. Two-place registration (the validator IS the schema)

Every new type/action/effect is registered in BOTH its handler AND the matching `ALLOWED_*`:

| New thing | Handler | `ALLOWED_*` list |
|---|---|---|
| card type `curse` | `play_spell` unplayable gate + frame color | `ALLOWED_CARD_TYPES` |
| card key `unplayable` / `end_turn_in_hand` | play gate + end-turn scan | card-schema validation in `validate_card` |
| effect `lose_gold` | `combat_engine._apply_effect` | `ALLOWED_EFFECT_TYPES` |
| effect `add_curse_to_deck` | `combat_engine._apply_effect` → RunManager | `ALLOWED_EFFECT_TYPES` |
| enemy action `add_curse` | `enemy_ai._execute_action` | `ALLOWED_ENEMY_ACTION_TYPES` |
| event effect `add_curse` | event effect handler | `ALLOWED_EVENT_EFFECT_TYPES` |

## 8. Visual / art

- Curse cards get a **distinct dark frame** (StS curses read purple/black). Add a `curse` color
  to the card-frame-by-type logic.
- `front_image`: a Codex deliverable (offbeat-sci-fi-cartoon curse illustrations, 512×320).
  Write an `asset-spec-curse-cards.md` for the 5; ship a **placeholder** (a shared dark curse
  graphic or the type frame with no art) meanwhile — warn-only fallback per project rule 5.

## 9. i18n

New `assets/translations/` rows: each curse `CARD_<id>_TITLE/DESC`, the enemy name, the event
text, and `UI_BATTLE_CURSE_UNPLAYABLE`. Regenerate `.translation` via `--import`.

## 10. Out of scope (v1)

Curse-synergy relic (Du-Vu Doll-style), Transform-into-curse, Blue-Candle "play curses" relic,
curse-specific removal discount. Noted as future follow-ups.

## 11. Files touched (estimate)

- `battle_scene/data_validator.gd` — 4 `ALLOWED_*` additions + curse-card schema checks.
- `battle_scene/card_info/player/{radiation_dust,leaking_wealth,rust,cowardice,panic}.json` — new.
- `battle_scene/combat_engine.gd` — `lose_gold`, `add_curse_to_deck`; end-turn-in-hand apply.
- `battle_scene/battle_scene.gd` — `play_spell` unplayable gate; end-round hand scan.
- `battle_scene/deck_manager.gd` — `add_card_to_draw` (if absent).
- `battle_scene/enemy_ai.gd` — `add_curse` action.
- enemy JSON + encounter-pool wiring; event JSON + `add_curse` event handler.
- pool-exclusion guards (draft/reward/shop/unlock skip `type=="curse"`).
- card-frame-by-type color; translations CSV(s).

## 12. Acceptance / testing

- Smoke gate green (DataValidator validates the 5 curses + the new enemy/event).
- MCP runtime checks: a curse in hand is unplayable (returns + toast); end-turn penalties fire
  (HP −2 / Weak / Frail / gold −5) and the curse then discards; an enemy `add_curse` shuffles a
  curse into the draw pile that's gone next combat; an event `add_curse` persists into the run
  deck and is removable at the shop; curses never appear in a draft/reward/shop offer.
- content-balance pass on the curse enemy.
