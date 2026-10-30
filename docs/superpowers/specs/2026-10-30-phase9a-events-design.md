# Phase 9a: Events as Models

Follow-up to the STS2 comparison of the out-of-combat screens (2026-10-29). The user chose to
follow the STS2 structure for the shop and the events, split into two sub-projects; this is
the first (events). Phase 9b (merchant) gets its own spec. Content stays ours: names, copy and
numbers are not taken from STS2.

## Goal

Every event is a model with pages. An option runs code that changes run state and then either
moves the event to another page with new options or finishes it. Each act deals events from
its own shuffled deck, and an event can refuse to appear when the run does not fit it. Effects
still run through the one run effect registry. A run reloaded inside an event returns to that
same event and cannot claim its rewards twice.

## STS2 mapping

| STS2 | Here |
|---|---|
| `Models.EventModel` | `core/run/events/event_model.gd` (base class) |
| `Models.Events.<Name>` | `content/events/<id>.gd` (one script per event) |
| `Events.EventOption` | `core/run/events/event_option.gd` |
| `ActModel.GenerateRooms` (event part) + `EventModel.IsAllowed` | `core/run/events/event_pool.gd` |
| `Rooms.EventRoom` / `Nodes.Rooms.NEventRoom` | `ui/events/event_room.gd` |
| `Nodes.Events.NEventLayout` | `ui/events/event_layout.gd` |
| `Nodes.Events.NEventOptionButton` | `ui/events/event_option_button.gd` |
| `DynamicVarSet` | `dynamic_vars` dictionary on the model |
| `isPreFinished` | `current_event.finished` in the run save |

`ui/events/event_modal.gd` is removed once `event_room.gd` replaces it.

## Content registration

`content/events/<id>.json` stays the ModelDb entry, so namespaces and `inject_dir` keep working.
It no longer holds options:

```json
{ "id": "rad_storm", "script": "rad_storm.gd", "acts": [2, 3], "art": "rad_storm" }
```

- `script` is resolved relative to the JSON file's directory; ModelDb reports a missing or
  non-`EventModel` script as a content error.
- `acts` is the list of act numbers that may deal the event. An absent `acts` key means the
  event is shared by every act.
- `art` names `run_system/assets/images/events/<art>.png`; it defaults to the id.
- The `"event"` branch of `ModelDb._normalize_refs` no longer walks `options`. Event scripts
  name content by full id (`base:lucky_cog`).

## EventModel

`extends RefCounted`. The registered script is the canonical instance; `EventPool` hands out
`to_mutable()` copies, so state never leaks between visits.

State:

- `id: String`: full id from the registry.
- `owner`: the run facade (`RunManager`). Scripts read run state through it.
- `rng`: the run's `events` stream.
- `dynamic_vars: Dictionary`: the numbers the copy shows and the effects use (`{"damage": 3}`).
  Text substitutes them as `{damage}`, so copy and effect cannot drift apart.
- `page: String`: starts at `"INITIAL"`.
- `current_options: Array` of `EventOption`.
- `is_finished: bool`.
- `signal state_changed`.

Overridden by each event:

- `generate_initial_options() -> Array`: required.
- `is_allowed(run_state) -> bool`: defaults to `true`.
- `calculate_vars() -> void`: fills `dynamic_vars` before the first page. Defaults to doing
  nothing.
- `page_art(page) -> String`: the art name for a page. Defaults to the event's art. rad_storm
  uses `rad_storm_bunker` from BUNKER on, and cursed_safe uses `cursed_safe_open` on OPEN.
  Missing page art falls back to the event's art.

Provided to events:

- `option(key: String, on_chosen: Callable) -> EventOption`
- `set_event_state(page: String, options: Array) -> void`: changes the page and emits
  `state_changed`.
- `set_event_finished(page: String) -> void`: shows that page's text with one proceed option,
  sets `is_finished` and emits `state_changed`.
- `apply(effects: Array) -> void`: runs run-context effects through the shared registry
  (`core/effects/run_effects.gd`). Today this is `RunManager.apply_event_effects`, which moves
  here and is removed from RunManager.
- `luck_option(key, on_success: Callable, on_fail: Callable) -> EventOption`: rolls
  `owner.luck_check_chance()` on `rng`. The button shows the chance as a percentage.
- `will_kill(damage: int) -> bool`.

Text keys (`assets/translations/ui_events.csv`, en and zh):

- `EVENT_<ID>_TITLE`
- `EVENT_<ID>_PAGE_<PAGE>`
- `EVENT_<ID>_OPT_<KEY>`

`<ID>` is the id without its namespace, uppercased; `<KEY>` is the option key. The existing
keys are renamed to this scheme, and both languages keep their current text.

## EventOption

`extends RefCounted`. Built by the model; read by the UI. Fields:

- `key: String` and `text_key: String`.
- `on_chosen: Callable`. An option without one is locked.
- `lock_reason: String`: shown on a locked option.
- `requires(attrs: Dictionary) -> EventOption`: locks the option when an attribute is below its
  threshold (Charm, Luck) and sets `lock_reason` (`"Charm 5"`). It replaces the JSON `requires`
  field and `RunManager.option_unlocked`.
- `chance: float`: `-1` unless the option is a luck option.
- `relic_id` and `card_id`: hover tips that reuse the existing relic and card tooltips.
- `will_kill_player: bool`: marks the button with a warning.
- `is_proceed: bool`: the proceed option that `set_event_finished` makes.

Choosing an option disables every button until the model emits `state_changed`, so a double
click cannot run an option twice.

## EventPool

Static functions over ModelDb.

- `build_deck(act_number: int, exclude: Array, rng) -> Array[String]`: the act's events plus
  the shared events, minus `exclude` (events already seen this run), shuffled with `rng`. Runs
  at run start and at every act start, on the `up_front` stream. The result is stored in
  `RunState.event_deck`.
- `next(run_state) -> EventModel` (or null): walks the deck in order and takes the first event
  whose `is_allowed` holds. That event leaves the deck and joins `seen_event_ids`; events it
  skipped stay in the deck. Returns null when no event fits, and the map then uses the
  `unknown_room.json` fallback as it does now.
- An event never repeats within a run. The current "start a fresh deck once every event was
  seen" fallback is dropped, because the `?` fallback table already covers an empty deck.

This replaces `RunManager.load_random_events`, `pick_random_event`, `_random_events` and
`_seen_random_event_ids`.

Act assignment for the existing events:

| Acts | Events |
|---|---|
| shared (all acts) | hooded_stranger, deserter_charm, fortune_shrine, torn_coin_pouch, buried_cache, cursed_safe |
| 1, 2 | adrenaline_shot, stranded_trader, caravan_checkpoint |
| 2, 3 | collapsed_overpass, mutant_bazaar, rad_storm |

`is_allowed` conditions:

- `rad_storm`: current HP is above the first-page damage, so its opening cannot be lethal.
- `cursed_safe`: the player holds fewer than two curses.
- Every other event keeps the default `true`.

## Run state and save (run save v5)

`RunState` gains two fields:

- `event_deck: Array[String]`
- `current_event: Dictionary`: `{node_id, event_id, finished}`, or empty.

Lifecycle:

- When the map enters a `?` node and `EventPool.next` returns an event, `current_event` is set
  with `finished: false` and the run is saved before the room opens. A reload therefore reopens
  the same event at its first page instead of dealing a new one.
- After the first option of the visit resolves, `current_event.finished` becomes `true` and the
  run is saved. A run reloaded from then on, including in the middle of a multi-page event,
  reopens the room finished: the page text says the event is over and only the proceed option
  is shown. Effects that already applied cannot apply again.
- Proceeding clears `current_event`, emits the run hook `after_event_finished(event_id)`
  through `_emit_run_event`, and saves.
- The map's `_ready` reopens the event room when `current_event.node_id` is the current node.
- `start_new_run` and `advance_act` rebuild `event_deck` and clear `current_event`.

Migration v4 → v5 (`run_save.gd`, through `migration_chain`):

- `seen_random_event_ids` is renamed to `seen_event_ids`.
- `event_deck` is built with `EventPool.build_deck(act, seen, rng)`. The rng is the
  run-seeded `up_front` stream at its saved counter, and the advanced counter is written back,
  so the step is deterministic.
- `current_event` is set to `{}`.
- The per-version backup (`.v4.bak`) works as it did in phase 7.

## Content migration

All 12 events become scripts with the same effects and numbers. Single-page events keep their
shape: each option either applies its effects and calls `set_event_finished`, or runs
`luck_option` with a success branch and a fail branch.

Two events become multi-page events and exercise the state machine. The copy is ours and will
be shown to the user before merge.

**rad_storm**

- INITIAL
  - "Hunker down": lose 4 HP, then finish.
  - [Charm 5] "Wave down a convoy": heal 6 and gain 15 gold, then finish.
  - [Luck] "Sprint for a bunker": on failure, lose 10 HP and finish. On success, gain 20
    scrap and go to BUNKER.
- BUNKER
  - "Dig deeper": gain 10 scrap and take `{rad}` damage. The damage starts at 3 and rises by
    2 on each dig. When the next dig would kill, the page switches to DEATH_WARNING, which
    offers the same options, and the button shows a lethal warning.
  - "Leave": finish.

**cursed_safe**

- INITIAL
  - "Crack it open": go to OPEN.
  - "Leave it": finish.
- OPEN
  - "Pocket the coins": gain 40 gold and the rust curse, then finish.
  - [Luck] "Pry out the humming core": on success, gain 40 gold, 20 scrap and the rust curse.
    On failure, gain 40 gold, the rust curse and the panic curse. Either way, finish.

## UI

- `event_room.gd` is opened by the map in place of the modal. It owns the music swap and the
  `resolved` signal that the map waits for.
- Layout follows STS2's default event layout (decided 2026-10-30): a framed illustration on
  the left and the text column on the right, instead of the illustration stretched over the
  whole screen. Everything sits below the top bar (`RUN_TOP_BAR.BAR_HEIGHT`, 132 px) in the
  1920×1080 viewport:
  - `EventPortrait`: a 1024×768 frame at x 80, centred vertically in the area below the bar.
    The illustration is drawn at 1:1, never scaled up. Existing 1408×768 art fills the frame
    at its own height and is centre-cropped to 1024 wide, so it works before the redraws
    arrive.
  - `EventContent`: the text column from x 1144 to x 1840.
  - `EventBackground`: a full-screen backdrop behind both, `events/backdrops/act_<n>.png`
    for the current act (1920×1080), with a dark scrim so the text stays readable. A missing
    backdrop falls back to a flat dark fill.
  - The full-screen text vignette (`EventTextVignette`) is removed; the scrim replaces it.
- `event_layout.gd` renders the title, page text (with `dynamic_vars` substituted) and the
  option list. It rebuilds on `state_changed`.
- `event_option_button.gd` renders one option:
  - its text;
  - the lock reason, when locked;
  - the luck chance, for a luck option;
  - the lethal warning, when `will_kill_player` is set;
  - the relic or card hover tip.
  - Lock, luck and lethal icons from `ui/events/icons/`. Until Codex delivers them, a text
    suffix stands in.
- New art (page illustrations and option icons) is listed in `docs/art/codex-art-requests.md`
  for Codex.
- The existing UI contract test moves to the new nodes. It asserts the node names
  `EventBackground`, `EventPortrait` and `EventContent`, that the portrait and the content
  start below the bar, that they do not overlap, and that the portrait texture is not scaled
  up.
- Art for the new layout, and redraws of the event illustrations and the shop background in
  the one house style, are listed in `docs/art/codex-art-requests.md`.

## Out of scope

- Combat inside an event (STS2 `NCombatEventLayout`).
- The Ancient layout.
- Event history entries.
- Shared multiplayer events.
- Phase 9b (merchant).

## Testing

All runs go through `tools/run_tests.ps1` (isolated APPDATA).

**EventModel**

- A page change replaces the options and emits `state_changed`.
- `set_event_finished` leaves only the proceed option.
- An option without a callable is locked.
- `requires` locks below the threshold and unlocks at it.
- `luck_option` follows the `events` stream deterministically.
- `will_kill` holds at exactly the current HP.

**EventPool**

- Act 1 never deals an act-2/3-only event.
- Shared events appear in every act.
- An event whose `is_allowed` fails is skipped and stays in the deck.
- The same seed gives the same deck.
- No event repeats across acts.
- An empty deck returns null.

**Save**

- v5 round trip, including `current_event` both unfinished and finished.
- v4 → v5 migration produces the deck deterministically and drops seen events.
- Reload behavior:
  - an unfinished event reloads at INITIAL;
  - a finished event reloads with only the proceed option;
  - effects are not applied twice.

**Content smoke**

- Every event, every first-page option and both luck branches, run headless to the end.
- Every run ends with no errors, every text key resolves in en and zh, and the event is
  either finished or showing options.
- rad_storm: dig until DEATH_WARNING appears before HP reaches 0.

**Other**

- The UI contract test is updated.
- The ModelDb content check reports a missing script.
- A windowed playtest for the user, at the end.
