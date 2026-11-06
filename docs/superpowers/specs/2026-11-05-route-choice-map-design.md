# Route Choice Map

The node map reads as Slay the Spire 2: a branching graph of normal, elite, rest, shop,
treasure, `?` and boss nodes. This change replaces it with a route of choice cards. Each
floor offers 2–3 cards; each card states its room, its rewards and which rooms the floor
after it holds. The user asked for this on 2026-11-05 to set the game apart from STS2, chose
"see one floor ahead" over a pure two-choice or a whole-route view, chose rewards printed on
the card, and chose to leave extraction out of the map. The 2026-08 concept images in
`docs/art/previews/new_map_two_choice_*` are not a reference for this design.

## Goal

At every floor the player sees 2–3 cards. A card shows its room type, the rewards the room
pays, and the room types of the floor that follows it. Choosing a card enters its room; that
card's previewed floor becomes the next set of cards. What a card prints is what the run
pays, and what a preview shows is what the next floor offers.

## Rules the player sees

Floors are numbered here from 0, as in code (`floor 0` is the first floor the player sees).

| Floor | Cards |
|---|---|
| 0 | one card: the starting relic choice (`relic`) |
| 1–5, 7–9 | 2 or 3 cards, rolled |
| 6 | one card: treasure (`guaranteed_treasure_floor`) |
| 10 | one card: rest (the campfire before the boss) |
| 11 | one card: the boss |

- Room types on rolled floors come from the act's existing tables (`early_rolls` through
  `early_floor_last`, then `rolls`), with the extra-treasure cap and the A5 elite bias as
  today. Merchants keep their current earliest floor, which those tables already encode.
- On one floor, non-combat types do not repeat: at most one `shop`, one `rest`, one
  `unknown`, one `treasure`. `enemy` and `elite` may repeat. A rolled repeat is re-rolled
  from the same stream; after 8 tries the floor keeps fewer cards (at least 2; if only one
  distinct type is possible, it falls back to `enemy` for the second card).
- A preview is binding: the floor reached through a card holds exactly the previewed cards.

### What a card prints

| Type | Rewards on the card |
|---|---|
| `enemy` | Caps amount, card draft |
| `elite` | Caps amount, exact Scrap amount, card draft |
| `treasure` | relic choice (3-of-1, as today) |
| `rest` | heal amount (25% of max HP, as today) |
| `shop` | none |
| `unknown` | none (stays a surprise) |
| `relic`, `boss` | as today, no amounts |

XP is not printed. Level-ups keep granting attribute picks; every normal and elite win keeps
granting one card draft (`ui/rewards/loot_reward.gd`).

## Generation and storage

### The map grows as the player walks

`map_data` keeps today's node shape, `{id, floor, slot, type, children}`, plus a `rewards`
dictionary. It never holds the whole act. It holds the walked path, the current choices and
each choice's preview:

- A new act creates the floor-0 node, its children (floor 1) and each child's children
  (floor 2).
- Entering a node generates, for each of its children, that child's children. Siblings of
  the entered node that were not chosen, and their previews, are removed from `map_data`.

`core/run/map_travel.gd` is unchanged: a node is enterable when it is a child of the current
node. The merchant's per-node stock (`state.shop_stock[node_id]`) is unchanged.

### Determinism

A node's children are rolled from `run_rng.derived("map_act_<act>_<node id>")`. The same
seed and the same route always produce the same cards, independent of load order, and no RNG
position is saved. A child's id is its parent's id plus its index (`f0`, `f0.1`, `f0.1.2`),
so ids never collide. `slot` is the card's index on its floor (0–2) for layout.

### Rewards are rolled with the node

`rewards` is filled when the node is generated:

- `enemy`: `{caps}` from `CAPS_PER_COMBAT`.
- `elite`: `{caps, scrap}`; `caps` from `CAPS_PER_ELITE`, `scrap` rolled in
  `loot_economy.elite_scrap` from the node's stream.
- Other types: `{}`.

`core/run/combat_rewards.gd` pays the entered node's `rewards` instead of rolling: Caps
through `award_run_caps`, Scrap through `add_scrap_to_backpack`. Boss settlement is
unchanged. The stale comment at `combat_rewards.gd` "A card draft per level gained" is
corrected (level-ups grant attribute points). The rest heal amount comes from one helper used
by both the card and the rest room, so the two cannot disagree.

### Saves

The run save version goes up by one. The migration keeps an old full-act `map_data` and
fills `rewards` for every node that lacks it, using the node's derived stream. An old map
then plays under the new screen: its current node's children are the cards, their children
the previews. Old nodes keep their ids; the pruning on the next move trims the rest of the
old graph.

## Screen

`ui/map/map_scene.gd` keeps every room-opening path (relic choice, rest, treasure, events,
`?` resolution, resuming a saved event, pause, character window, deck viewer) and the battle
peek mode. It loses graph drawing, scrolling and edges; `ui/map/map_renderer.gd` is deleted.

- **Top bar:** today's.
- **Floor track:** a row of 12 pips under the top bar: walked, current, boss.
- **Cards:** 2–3 fixed-size cards, centred in a row; single-card floors centre one card.
- **Background:** today's map background.

A new `ui/map/route_choice_card.gd` + `.tscn` draws one card from a node dictionary and emits
`chosen(node_id)`. Top to bottom: the room's icon (the existing map node icons) and name; the
reward rows (icon plus number, or a short line for heal and relic choice); a divider; the
"next floor" row of small room icons. Hover raises and outlines the card; click or the 1/2/3
keys choose it. In peek mode cards render but ignore input, with the existing "back to
battle" button.

Motion is light: cards slide in when a floor appears; the chosen card scales up while the
others fade, then the room opens.

Rest, shop, event and treasure screens do not change.

## Tests

- **Generator:** fixed floors (0 relic, 6 treasure, 10 rest, 11 boss, one card each);
  rolled floors hold 2–3 cards with no repeated non-combat type; merchants never earlier than
  today's tables allow; the same seed and route give identical cards twice; after entering a
  node the next floor's types equal its preview; unchosen siblings are pruned; ids are unique.
- **Rewards:** winning a normal or elite fight pays exactly the node's printed Caps and Scrap.
- **Saves:** save mid-floor and reload: same cards, same previews; an old-version save with a
  full act map loads, gains `rewards`, and can be walked to the boss.
- **Screen:** card count equals the current node's children; choosing a card enters its room;
  peek mode cards ignore clicks.
- Tests written against the old graph (including `tests/run_structure_golden_test.gd`) are
  rewritten. Before an old assertion is removed, the rule it covered (fixed floors, merchant
  floor, elite bias, treasure cap) must be asserted by a new test.
- A windowed playtest by the user closes the work.

## Out of scope

- Extraction from the map (the user chose to leave it out).
- Changes to combat, card drafts, attribute level-ups, or the rest, shop, event and treasure
  rooms.
- New art: the cards use the existing node icons and reward icons.

## Work

Worktree `C:\Users\Jerry\Desktop\Cardgame-map`, branch `feat/route-choice-map`, from main
`c508d9b`. The main checkout's uncommitted files are not touched. Merging and pushing wait for
the user.
