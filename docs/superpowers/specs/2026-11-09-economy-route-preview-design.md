# One Run Currency and Route Encounter Preview

The 2026-11-09 review found two problems with the route map. First, the run has two
currencies called Caps. The top bar and the shop use backpack gold, labelled Caps. A
fight also adds hidden run caps, and the route card prints those, not what the loot
screen pays. Second, floors 1–4 roll only `enemy` and `unknown` with fixed rewards, so
a floor often shows three identical cards. On 2026-11-09 the user chose: one in-run
currency named Caps, banked 1:1; encounters pre-rolled and shown on the card with a
strength tag; and more room types on early floors.

## Goal

Every Caps number the player sees is the same currency: the top bar, route cards, the
loot screen, the shop, and what extraction banks. A fight card shows which monsters it
holds, how strong they are, and what they pay. Early floors offer more than fights and
`?`.

## 1. One currency

- The hidden run caps are removed: `RunState.run_caps`, `RunManager._run_caps`,
  `award_run_caps`, `CAPS_PER_COMBAT`, `CAPS_PER_ELITE`, `CAPS_PER_BOSS` and
  `GOLD_PER_CAP`.
- Extraction or final victory banks `total_gold()` into `MetaProgress` caps 1:1. Death
  banks none, as now.
- Fight payouts are printed on the route node as `rewards.gold`. The loot screen's gold
  row pays exactly that number (it no longer reads `combat_gold`). New economy keys in
  `content/economy/loot_economy.json`:
  - `combat_gold_by_strength`: `{"weak": 6, "normal": 8, "strong": 11}`
  - `elite_gold`: `18`
  - `boss_gold`: `45`, added to the backpack when the boss falls (before the run settles).
- An elite still prints and pays its rolled Scrap, as now.
- A fight rolled from a `?` room pays `combat_gold_by_strength.normal`.
- Base prices are unchanged. The old per-run bank was about 145 caps (about 130 hidden
  plus gold/10); a run now banks its leftover gold, usually 150–300. Spending in the
  shop now lowers what a run brings home.

## 2. Encounters on the card

- When an `enemy` or `elite` node is generated, it rolls its encounter id from its
  rewards stream (`map_act_<act>_<id>_rewards`) and stores it as `node.encounter`.
  `enemy` nodes pick from `Encounters.band_pool(act, floor)`, `elite` nodes from
  `act.elites`. Entering the node fights that encounter. `?` fights and the boss keep
  today's selection.
- Strength of an `enemy` encounter: the summed `max_health` of its monsters, compared
  with the mean over its band pool. Below 85% of the mean is `weak`, above 115% is
  `strong`, otherwise `normal`. The value is stored as `node.strength`. Elites have no
  strength tag.
- `rewards.gold` follows strength: weak 6, normal 8, strong 11; elite 18.
- The card shows up to three monster portraits below the room name. A portrait is the
  monster's first attack frame,
  `battle_scene/assets/images/enemies/<sprite_id>/attack/<sprite_id>_attack_0.png`. A
  strength tag sits beside the portraits (弱 / 中 / 强, Weak / Normal / Strong), and the
  Caps row shows `rewards.gold`. Elite cards show the elite's portrait and no tag.

## 3. Early floors

- Floor 1 (after the relic) offers only `enemy` cards, told apart by encounter and
  strength.
- Floors 2–4 use new `early_rolls` in acts 1–3: enemy 55%, unknown 25%, merchant 8%,
  rest 7%, treasure 5%. Treasure still counts toward `max_extra_treasures` and stays
  unique per floor.
- Floor 5 onward is unchanged.

## Saves

Run save v8. The migration:

- moves old `run_caps` into a one-time `legacy_caps` value; on load it is added to the
  backpack as gold, and any part that does not fit is banked at settlement;
- gives every `enemy`/`elite` node without `encounter` one (and `strength` for enemies),
  rolled by the same rule;
- rewrites `rewards.caps` to `rewards.gold` using the strength table.

## Tests

- Settlement banks exactly `total_gold()` as caps, and nothing else.
- A won fight's loot gold equals its node's printed `rewards.gold`; a `?` fight pays 8;
  the boss adds 45 gold.
- Entering an `enemy`/`elite` node fights its stored encounter.
- Strength tags: an encounter below, inside and above the 85–115% band gets weak,
  normal and strong.
- Over 200 routes, floor 1 is all `enemy`, and floors 2–4 sometimes show merchant, rest
  and treasure.
- A v7 save with `run_caps` and old nodes loads with that value as backpack gold, nodes
  with encounters, and `rewards.gold`.
- The card shows portraits, a tag and the gold.

## Out of scope

Base building prices, the shop's prices and card/relic text that already says Caps
(it already means backpack gold).

## Work

Worktree `C:\Users\Jerry\Desktop\Cardgame-econ`, branch `feat/economy-route-preview`,
from main `7ad21fc`. Merging and pushing wait for the user.
