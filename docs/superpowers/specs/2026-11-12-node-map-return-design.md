# Node Map Return

On 2026-11-12 the user asked to replace the route of choice cards with a branching node
map again, styled after a reference they supplied: a hand-drawn watercolour parchment map,
dark octagonal nodes with cream icons, dashed paths, and the walked path in orange. They
want to plan a route several floors ahead, as on a Slay the Spire map, and they want the
map to look like that reference rather than like a menu.

From the same day Claude owns code, design and UI direction. GPT/Codex only draws art
from Claude's briefs. Codex's `feat/ui-refresh` branch is not merged; this work starts
from `main` (`c644bee`).

## Goal

A run walks a full act map of branching nodes again. The player sees every floor of the
act, can scroll it, and picks the next node among the current node's children. Nodes show
only their room type. The map reads as a hand-drawn parchment chart, not as UI panels.

## Non-goals and anti-goals

- No information beyond room type on a node: no enemy preview, no strength tag, no reward
  amounts, no hover cards with numbers. (The user dropped these on 2026-11-12.)
- No player token on the map. The current node is marked on the node itself. (The user
  dropped the hero figurine as not worth the effort.)
- No new map rules. The old generation rules come back unchanged.
- Anti-goal: a map that looks like the route cards (dark panels in a row). If the screen
  reads as buttons on a background, it has failed even when it works.

## Approaches

| | Approach | Trade-off |
|---|---|---|
| **A (chosen)** | Restore the map data layer (generator, travel, save shape) from `c508d9b`; write a new presentation | Keeps tested rules and the save shape; the screen is built for the reference look (hover, states, scrolling) |
| B | Restore the old map wholesale and reskin it | Fastest, but the old renderer draws everything in one `_draw`, so node states, hover and animation are awkward; code we would rewrite at once |
| C | Rewrite the map from scratch | Cleanest, but re-derives and re-tests rules and saves that already worked |

The user picked A on 2026-11-12.

## 1. Data layer: back to the act map

- `core/run/map_generator.gd` returns to the `c508d9b` version: `generate(act, rng,
  elite_bias_floor) -> Array` builds a whole act. Rules: 12 floors; floor 0 a single
  `relic` node; 2–4 nodes on middle floors (width 4), as the old code rolls them; floor 6
  all `treasure`; floor 10 all `rest`; floor 11 a single `boss`; each node links to at most
  `max_children_per_node` (3) nodes of the next floor, and floor 1 is capped at that many
  nodes; floors through `early_floor_last` (4) use `early_rolls`, which hold no merchant, so
  merchants first appear on floor 5. (The old `generate_map` comment says "3-5 nodes" and
  "merchants from floor 4"; it is wrong and is corrected when restored.)
- `RunManager.rng_for_act_map(act)` is restored as it was at `c508d9b` (a derived
  `map_act_<act>` stream, falling back to `rng("niche")` outside a run) and replaces
  `_route_rng()`. `RunManager.generate_map()` builds the act map from it and indexes the
  nodes with `_reindex_map()`; `load_run()` keeps calling `_reindex_map()`. A move does not
  change the map, so it needs no reindex. `MAP_TRAVEL.enter` moves the player, as before the
  route cards; `RunManager.enter_map_node` goes away.
- The act tables (`content/acts/act1..3.json`) restore their `c508d9b` `early_rolls`, so
  floor 1 is no longer fights only.
- Removed with the route cards: `MapGenerator.start/grow/roll_children/fill_fight/node_rewards`, node
  fields `rewards`, `encounter` and `strength`, `Encounters.strength`,
  `RunManager.encounter_for`, `ui/map/route_choice_card.{gd,tscn}`, the route translation
  keys (`UI_ROUTE_*`), and the route tests.
- Encounters are chosen on entering a fight node with `select_encounter(type, floor)`, as
  before. `Encounters.monsters_of` may stay if `select` still uses it.

## 2. Economy: one currency stays

- Kept from `a69aad9`: backpack gold is the only run currency (shown as Caps) and banks 1:1;
  `legacy_caps` carries Caps that did not fit; the boss adds `boss_gold` (45) to the backpack.
- A won fight's loot gold is fixed by room type from `content/economy/loot_economy.json`:
  `enemy` 8, `elite` 18. A `?` fight pays as `enemy`. `combat_gold_by_strength` is replaced by
  `combat_gold` (8). `RunManager.battle_rewards()` becomes a lookup by
  `last_battle_node_type`, with no node data. `Rewards.combat_loot(node_type, gold)` keeps its
  current signature; the loot screen passes `battle_rewards().gold`.
- Elite Scrap is rolled at settlement again (`loot_economy.elite_scrap`, from the `rewards`
  stream), as before the route cards.

## 3. Saves

Run save v9 (`_v8_to_v9`):

- A save is an act graph when every node id matches `f<floor>_s<slot>`; anything else is a
  route and gets a fresh act map from `rng_for_act_map` for its act.
  - If `current_node_id` is `""`, the player stays at the act start.
  - Otherwise the player stands on the node of their current floor with the lowest `slot`;
    `visited_node_ids` keeps only that node.
  - An event in progress (`current_event`, which the event room saves while open) is kept and
    re-keyed to that node, so a rolled or finished event resumes and pays out once.
  - A merchant's `shop_stock` keyed by an old route id is dropped (saves are taken on the
    map, never inside the shop).
- A save whose `map_data` is already an act graph (v6 and older shapes, carried through) keeps
  it. Node fields `rewards`, `encounter` and `strength` are erased wherever present.
- `legacy_caps` and the backpack are untouched.
- The v6→v7 and v7→v8 steps called `node_rewards` and `fill_fight`, which go away. Their
  map work becomes a no-op (v7→v8 still moves `run_caps` into `legacy_caps`); v9 erases the
  fields they used to fill.

## 4. The map screen

`ui/map/map_scene.gd` keeps its room-opening logic (relic choice, rest, treasure, events,
`?`, event resume, pause, `I` window, deck viewer, battle peek). Its map presentation is new:

- **Canvas.** A horizontally scrollable map: floor 0 at the left, the boss at the right.
  Scroll with the wheel and by dragging the empty map; on open it scrolls so the current
  node sits about a third from the left. Floors are spaced evenly; a floor's nodes spread
  over the vertical band between the top bar and the bottom margin, with a small seeded
  jitter so the graph looks hand-placed (the same seed gives the same layout).
- **Background.** One long parchment image behind the whole act, scrolled with it.
- **Nodes.** Each node is an octagon base plus a room icon. States:
  - *available* (a child of the current node, or floor 0 at the start): full colour, a slow
    pulse (scale 1.0–1.06, 1.2 s), hover scales to 1.15 with a cursor change;
  - *current*: an orange ring around the octagon;
  - *visited*: darker base, icon kept;
  - *unreachable*: 45% opacity.
  Bosses use a larger octagon.
- **Paths.** Every edge is a dashed line (dash about 14 px, gap 10 px, width 4 px, ink
  colour). Edges on the walked path are solid orange; edges from the current node to its
  children are orange dashes. The start is marked with an orange flag at floor 0's node.
- **Legend.** A small parchment card at the bottom right listing the eight room types.
- **Choosing.** Click an available node: the node pops (scale 1.25 then back, 0.2 s), the
  map records the move, then the room opens after 0.3 s as today. Choosing is refused in
  peek mode, under an open page, or while another choice resolves.

Until GPT's art arrives, the screen draws the octagons in code and uses the existing node
icons (`run_system/assets/images/map/nodes/*.png`), so the screen works and tests run without
new art.

## 5. Art for GPT (brief written by Claude after approval)

Style anchor: the user's reference (hand-drawn watercolour parchment, soft green trees and
hills at the edges, ink linework) translated to our wasteland: dry scrub, rock buttes,
broken poles and pipes at the edges, a calm centre band where nodes sit. Files:

- `run_system/assets/images/map/route_parchment.png`: 4200×1080 RGB, the whole act's
  background, edges decorated, centre band (y 160–940) calm.
- `run_system/assets/images/map/node_octagon_{available,visited,unreachable,current_ring}.png`:
  96×96 RGBA; `node_octagon_boss.png` 144×144.
- `run_system/assets/images/map/nodes/{relic,enemy,elite,rest,merchant,treasure,unknown,boss}.png`:
  redraw as cream single-silhouette icons, 64×64 RGBA, matching the octagons.
- `run_system/assets/images/map/start_flag.png`: 64×64 RGBA.
- `run_system/assets/images/map/legend_card.png`: 360×420 RGBA parchment card.

## Tests

- Generator: new rule tests over many seeds (floor 0 one `relic`, floor 6 all `treasure`,
  floor 10 all `rest`, floor 11 one `boss`, 2–4 nodes on middle floors and at most 3 on floor 1,
  every node except the boss has 1–3 children, every node after floor 0 has a parent, no
  merchant before floor 5, the A5 bias raises elites), adapted from
  `route_map_generator_test.gd` before it is deleted. Restore the run-structure golden map
  checks: the `map` keys of `tests/fixtures/run_structure_golden.json` and `a5_map` of
  `run_structure_golden2.json`, both from `c508d9b`.
- Travel and economy: a won `enemy` pays 8, `elite` 18 and rolls 8–16 Scrap, `?` pays 8;
  settlement banks backpack gold plus `legacy_caps`.
- Saves: a v8 route save loads as a full act map with the player on its current floor; one
  saved inside an event resumes that event on the new node; one at the act start stays at the
  start; a v6 graph save keeps its graph; node `rewards`/`encounter`/`strength` are gone after
  migration.
- Screen: the map shows one node control per node; available nodes are exactly the current
  node's children; choosing one moves the player once even if clicked twice; peek mode never
  travels; the screen scrolls to keep the current node in view.
- Full suite green.

## Left to the builder

Exact floor spacing, jitter range, pulse and colour values, legend layout, and how scrolling
clamps at the ends.
