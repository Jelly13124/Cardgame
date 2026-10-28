# Phase 6: Acts and Run Structure as Data

Roadmap: `docs/reviews/sts2-architecture-review/10-roadmap.md` §阶段 6. Findings: S5-01, S4-03,
S5-03, S5-04, S5-05, S1-07, S5-07, S6-04 (S4-04 deferred, see below). Decisions delegated by the
user ("follow the STS2 code structure"); mod loading is out of scope.

## Goal

An act, its encounters, its map rules, its rewards and the run's act list are data. A battle
returns only a result; the run layer decides rewards and routing. Demo and full game differ by one
run configuration. Gameplay, numbers and RNG stream usage stay as they are.

## STS2 mapping

| STS2 | Here |
|---|---|
| `Models.Acts.ActModel` | `content/acts/<id>.json` (ModelDb category `act`), read by `core/run/acts.gd` |
| `Models.Encounters.EncounterModel` | `content/encounters/<id>.json` (category `encounter`), `core/run/encounters.gd` |
| `Map.StandardActMap` | `core/run/map_generator.gd` (from `RunManager.generate_map`) |
| `Rooms.*Room` / `RoomType` | `core/run/rooms.gd` (room types, "?" outcome table) |
| reward/merchant flows | `core/run/rewards.gd`, `core/run/shop_stock.gd` |
| `Models.CardPools` | `core/run/card_pools.gd` (from `run_system/core/discover_pool.gd`) |
| run options (GameMode) | `content/runs/<id>.json` (category `run_config`): act list, heroes, demo flags |
| `Core.Debug` / DevConsole | `autoload/debug.gd` (F9–F12 debug keys) |
| merchant/meta economy | `core/meta/market.gd` (base market rules and prices) |
| `Nodes.Screens.Map`, `Nodes.Rooms` | `ui/map/`, `ui/shop/`, `ui/rewards/`, `ui/events/`, `ui/rest/`, `ui/base/` |

## Data

- **Act** (`content/acts/act1.json` … `act3.json`): `floors`, `boss` (encounter id),
  `hp_mult`, `dmg_mult`, `encounters` (normal pools by floor band: list of
  `{max_floor, pool: [encounter ids]}`), `elites` (encounter ids), `map` (single-node floors,
  `first_merchant_floor`, `guaranteed_treasure_floor`, `early_floor_last`,
  `max_extra_treasures`, `max_children_per_node`, node-type roll tables for early and mid/late
  floors), `extract_rewards` `{continue, extract}`.
  The current shared pools with `ACT_POOL_OFFSET` become per-act band tables with the same
  floors (act N's bands are today's bands shifted by `(N-1)*4`), so every act draws exactly what
  it draws today.
- **Encounter** (`content/encounters/<id>.json`): `room` (`monster`/`elite`/`boss`), `monsters`.
  Elite/boss identity comes from the encounter, so `ELITE_ROSTER`/`ACT_BOSSES` constants go.
- **Run config** (`content/runs/demo.json`, `full.json`): `acts`, `heroes`, `demo` flags; the
  active one is a single project-level choice (`demo` today).
- **Economy** (`content/economy/*.json`): shop prices and stock rules, loot weights, base market
  prices. Values copied verbatim from the scripts.

## Run layer (`core/run/`)

- `acts.gd`: current act definition, `acts_total()`, boss, multipliers, extract rewards.
- `map_generator.gd`: today's algorithm and stream (`derived("map_act_N")`), parameters from the
  act. Same seed → same map as before (tested against a golden map from the base commit).
- `encounters.gd`: `select(node_type, floor)` with the same streams (`encounters`, `elites`).
- `combat_rewards.gd`: from a battle result `{outcome, room, hp, act}` → caps, XP, bounty event,
  boss equipment, elite scrap, and the route (`extract_choice` / `demo_complete` / `loot` /
  `defeat`). The battle screen only shows the route's UI (S1-07).
- `rewards.gd` / `shop_stock.gd`: card reward rarity, tool/equipment drop rolls, shop prices and
  stock as pure functions over the named streams; UI renders and calls back.
- `rooms.gd`: room type list and the "?" fallback outcome table (data) used by the map.

## Meta and debug

- `core/meta/market.gd`: base market prices, stock rolls, exchange rates (from
  `market_screen.gd`); clinic HP-per-level read from one place.
- `autoload/debug.gd`: debug keys move out of `RunManager._input`.

## Deferred

- S4-04 (richer enemy AI formats: weighted/conditional moves): no current monster needs it and
  gameplay must not change; deferred with the format sketched in the ledger.

## Testing

- Golden map: seed `WASTELA1D7`, acts 1–3, equals the map the base commit generates.
- Encounter distribution per floor band, same seed same sequence.
- A fixture act 4 (test-only content dir) becomes playable by data alone: run config lists it,
  acts_total() is 4, its boss and pools resolve.
- Combat result → route table test (boss non-final → extract choice, final → demo complete,
  elite → scrap, normal → loot).
- Reward/shop stock per seed reproducible.
- Existing tests green; playtest with screenshots (map, battle, loot, shop, event, rest).
