# Phase 2b — Seeded run RNG streams

Status: decided by the agent under the owner's delegation ("follow the STS2
architecture as much as possible"). Owner choice already made: show the run
seed on the result screen and allow entering a seed when starting a run.

Roadmap item: S1-09 (reproducible runs). Builds on phase 2a (ModelDb).

## Problem

About 70 gameplay rolls call the global `randi()` / `randf()` / `shuffle()`.
A run cannot be reproduced, a bug report cannot carry a seed, and one system's
extra roll changes every later roll in unrelated systems (an extra crit roll
changes the next card reward).

## STS2 reference

`RunRngSet(string seed)` hashes the seed string to a `uint` and creates one
`Rng` per `RunRngType` (UpFront, Shuffle, UnknownMapPoint,
CombatCardGeneration, CombatCardSelection, CombatTargets, MonsterAi, Niche, …),
each seeded with `seed + hash(snake_case(name))`. `PlayerRngSet` adds Rewards,
Shops and Transformations. An `Rng` is `{Seed, Counter}`; every draw increments
`Counter`; a save stores the seed and each stream's counter, and loading
fast-forwards a fresh `Rng` to the counter. `SeedHelper` generates 10-character
seeds from `0-9A-Z` without `I`/`O`, and canonicalizes typed seeds (upper case,
`O`→`0`, `I`→`1`, trimmed). `Rng.Chaotic` is the unseeded generator for
cosmetic randomness.

## Design

### Rng — `core/rng/rng.gd`

- `_init(seed: int, counter := 0)`; fields `seed`, `counter`.
- Backed by one `RandomNumberGenerator` seeded with `seed`. Every public draw
  makes exactly one `randi()` call and increments `counter`, so
  `fast_forward(n)` replays `n` calls exactly.
- `next_int(max_exclusive)`, `next_range(min, max_inclusive)` (replaces
  `randi_range`), `next_float()` in `[0,1)`, `next_bool()`, `pick(array)`,
  `shuffle(array)` (Fisher–Yates, in place), `chance(p) -> bool`.
- `to_dict() -> {seed, counter}`; `static from_dict(d)`.

### RunRngSet — `core/rng/run_rng_set.gd`

- `_init(seed_string: String)`: canonicalizes, keeps `seed_string` for display,
  `seed = fnv1a32(seed_string)`.
- Streams, each `Rng(seed + fnv1a32(name))`:

| Stream | Uses |
|---|---|
| `up_front` | event deal order, demo featured set |
| `encounters` | normal fights, in visit order |
| `elites` | elite fights, in visit order |
| `shuffle` | draw-pile shuffles (combat start, reshuffle) |
| `unknown_map_point` | "?" node outcome rolls and their amounts |
| `combat_card_generation` | discover candidates, added curses picked at random |
| `combat_targets` | random-target effects (relic random enemy) |
| `combat_crits` | crit rolls (cards and relics) |
| `monster_ai` | reserved for random enemy intents |
| `rewards` | loot rows, card draft rarity/picks, equipment drops, affix rolls, elite scrap |
| `shops` | shop and market stock |
| `events` | event luck checks |
| `niche` | anything else gameplay-relevant |

  Act maps use `derived("map_act_<n>")`: a fresh, unsaved stream per act, so an
  act's map depends only on the seed (STS2 generates act maps up front). With
  separate `encounters` / `elites` streams, the k-th fight of each kind is fixed
  by the seed whatever path the player takes.
  `combat_crits` has no STS2 counterpart (STS2 has no crit); it is separate so
  previews and crit-dependent cards never shift reward rolls.
- `stream(name) -> Rng`; unknown names are an error.
- `to_dict() -> {seed_string, counters: {name: int}}`, `static from_dict(d)`.
- `static random_seed_string() -> String` (10 chars, alphabet
  `0123456789ABCDEFGHJKLMNPQRSTUVWXYZ`, from an unseeded RNG) and
  `static canonicalize(s) -> String`.

### Ownership

- `RunManager.run_rng` (a `RunRngSet`) is created by `start_new_run(hero,
  starter_deck, asc, seed_string := "")`; empty → random seed.
- Consumers call `RunManager.rng("rewards").next_int(n)` etc. No gameplay code
  calls the global `randi`/`randf`/`shuffle` any more; a contract test scans for
  them, with an allow-list for cosmetic files (`card_animator.gd`,
  `audio_manager.gd`) and non-gameplay uniqueness (deck entry uid).
- MetaProgress's date-seeded bounty shelf keeps its own local RNG (meta, not run).
- Outside an active run (home-base market stock, forge reforge/curse rolls,
  tests, menus) `RunManager.rng(name)` returns the stream of a session-local
  random set that is never saved, so callers never null-check and meta
  randomness stays unseeded.
- Draw-pile shuffles: the card-framework addon's `CardContainer.shuffle()` uses
  the global `randi()` and the addon stays untouched, so `deck_manager.gd` owns
  a `_shuffle_pile(pile)` that shuffles the pile's held-card array with the
  `shuffle` stream and reapplies child order and card UI exactly like the addon
  does.
- `loot_reward.gd` drops its `randomize()` call (it reseeded the global RNG).

### Saves

- Run save `v` 3 adds `"rng": run_rng.to_dict()`; loading rebuilds the set and
  fast-forwards each stream. A v2 save (no `rng`) gets a fresh random seed —
  the run continues; reproducibility starts from that point.
- `core/content/save_migration.gd` gains the 2→3 step (adds nothing but the
  version; the loader handles the missing key).

### UI

- Result screen shows `Seed: <seed_string>` under the summary.
- Starting a run: the home base Depart flow gets a small optional seed field
  (empty = random). Typed seeds are canonicalized; invalid characters are
  rejected with the field outline turning red.
- Translation keys `UI_RESULT_SEED`, `UI_HOME_SEED_PLACEHOLDER`,
  `UI_HOME_SEED_INVALID` (en + zh).

### Tests

- `tests/rng_contract_test.gd`: same seed → same sequence; counter round-trip
  through `to_dict`/`from_dict` + fast-forward; streams independent (drawing
  from `combat_crits` does not change the next `rewards` draw); canonicalize
  rules; random seed alphabet/length.
- Reproducibility: two `start_new_run` with the same seed produce the same map,
  encounters, first card draft and first shop stock.
- Save round-trip: draw from several streams, save, load, next draws match an
  uninterrupted copy.
- Source scan: no global RNG calls outside the allow-list.

## Out of scope

Daily runs, seed sharing UI beyond display/input, multiplayer player sets.
