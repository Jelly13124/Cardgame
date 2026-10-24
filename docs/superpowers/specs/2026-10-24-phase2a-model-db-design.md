# Phase 2a — ModelDb content registry and namespaced IDs

Status: decided by the agent under the owner's delegation ("decide it yourself,
follow the STS2 architecture as much as possible"). Owner choices already made:
move only data JSON to `content/<type>/` (art stays), namespace every content ID
including base content (`base:`), follow the STS2 implementation.

Roadmap items: S2-01 (one content registry), S2-05/S2-06 (unified IDs and
references), S2-07 (content directory layout), S3-05 (pool ownership), S9-03
(rule tests use synthetic content). Seeded RNG is phase 2b, not here.

## Problem

Content is read from ten directories by about twenty files, each with its own
`DirAccess` loop, cache and path constant. IDs are bare strings (`reload`), so
an event and a tool can share `adrenaline_shot`, and mod or test content cannot
be added without editing those loops. Cross-references inside JSON (`set_id`,
`starter_deck`, `enemy_ids`, effect `card`/`curse`/`id`) are interpreted by each
consumer. Rule tests can only use the shipped content.

## STS2 reference

STS2 has a static `ModelDb` (`Dictionary<ModelId, AbstractModel>`) filled once by
`Init()`, with `Inject`/`Remove` for tests, and queries such as `AllCards`.
`AllCards` is derived from card pools; a `CharacterModel` owns its `CardPool`,
`RelicPool` and `StartingDeck`. Canonical models are immutable; runtime code
works on `ToMutable()` clones. `ModelId` is category + entry and serializes to a
string.

## Design

### IDs

- A content ID is the string `"<namespace>:<entry>"`, e.g. `base:reload`.
  The category is not encoded: every field that holds an ID has one category
  (STS2 encodes it because it has one global dictionary; ours is keyed by
  category, which also resolves the `adrenaline_shot` event/tool collision).
- `core/content/model_id.gd` (static, no `class_name`):
  - `make(ns, entry) -> String`, `namespace_of(id)`, `entry_of(id)`,
    `is_full(id) -> bool`.
  - `key_entry(id) -> String`: the token used for translation keys and asset
    file names. For `base` it is the bare entry (so every existing
    `CARD_<entry>_TITLE` key and `player/<entry>.png` path is unchanged); for
    other namespaces it is `<ns>_<entry>`.
- Runtime state (deck, relics, equipment instances, tools, encounters, unlocks,
  bounties, upgrades, history) stores full IDs only. Code literals that name
  content are written as full IDs (`"base:lucky_coin"`), so comparisons such as
  `relics.has(...)` compare like with like and stay greppable.

### Models

- `core/content/content_model.gd`: `id` (full), `category`, `namespace`,
  `entry`, and `data` — the parsed JSON, deep read-only
  (`Dictionary.make_read_only()` applied recursively). `data.id` is the full ID.
  `to_mutable() -> Dictionary` returns a deep, writable copy (STS2 `ToMutable`).
- One model class for all categories. Typed subclasses per category were
  considered and dropped: every consumer reads dictionaries today, so typed
  wrappers would add a layer without removing any interpretation.

### ModelDb

`core/content/model_db.gd` (static state, no `class_name`, no scene tree, no
autoload). Categories:
`card, monster, relic, equipment, equipment_set, event, tool, bounty,
character, base_upgrade, card_pool, relic_pool`.

- `ensure_loaded()` loads base content from `res://content/<dir>/` once
  (namespace `base`). Every query calls it.
- Queries: `get_model(category, id)` (null when absent), `data(category, id)`
  (read-only dict, `{}` when absent), `mutable(category, id)`,
  `ids(category) -> Array[String]` (sorted), `models(category)`,
  `has(category, id)`.
- `resolve(category, ref, context_ns := "base") -> String`: a full ref is
  returned if registered; a bare ref resolves in `context_ns` first, then
  `base`; unknown returns `""`. This is the only place bare refs are parsed.
- Test and mod hooks: `inject_dir(path, ns)` (same layout as `content/`),
  `inject(category, ns, entry, data)`, `remove(category, id)`, `reset()`
  (drops everything and reloads base on next query).
- `load_errors() -> Array[String]`: problems found while loading (bad JSON,
  local `id` not equal to the file name, unresolved reference). Loading never
  aborts; the validator fails on a non-empty list.

### Directory layout

| Category | New dir | From |
|---|---|---|
| card | `content/cards/` | `battle_scene/card_info/player/` |
| monster | `content/monsters/` | `battle_scene/card_info/enemy/` |
| relic | `content/relics/` | `run_system/data/relics/` |
| equipment | `content/equipment/` | `run_system/data/equipment/` |
| equipment_set | `content/equipment_sets/` | `run_system/data/equipment_sets/` |
| event | `content/events/` | `run_system/data/random_events/` |
| tool | `content/tools/` | `run_system/data/tools/` |
| bounty | `content/bounties/` | `run_system/data/bounties/` |
| character | `content/characters/` | `run_system/data/heroes/` |
| base_upgrade | `content/base_upgrades/` | `run_system/data/base_upgrades/` |
| card_pool | `content/card_pools/` | new |
| relic_pool | `content/relic_pools/` | new |

Files keep their names; the file name is the local entry. Art stays where it
is. Card JSON renames `name` (the ID) to `id`; `title` stays the display name.
Other categories already use `id` for the ID and `name` for display.
`battle_scene/card_info/generate_cards.sh` moves its output path; old dirs are
deleted.

### References inside JSON

The loader (the owner) rewrites these to full IDs, so consumers never
re-interpret them:

| Where | Field | Target |
|---|---|---|
| card, relic effects (+ `upgrade.effects`) | `card`, `curse` | card |
| monster `action_pattern`, `phases[].action_pattern`, `phases[].on_enter` | `curse` → card, `enemy_ids[]` → monster |
| event option `effects*` | `curse` → card; `id` when `type == gain_relic` → relic |
| equipment | `set_id` | equipment_set |
| character | `starter_deck[]` → card, `card_pool` → card_pool, `relic_pool` → relic_pool |
| card_pool | `cards[]` | card |
| relic_pool | `relics[]` | relic |

`sprite_id`, `card_ui_skin`, `front_image` and status names are asset or rule
keys, not content references, and are left alone.

### Pools

- `content/card_pools/cowboy.json` lists every current player card;
  `content/relic_pools/cowboy.json` lists every current relic.
  `content/characters/cowboy_bill.json` gains `card_pool` and `relic_pool`.
- Run-time offers (loot draft, discover, shop, market, relic rewards) read the
  current character's pool. Collection, catalog and validation read
  `ids(category)`. With one character both sets are equal, so offers are
  unchanged. Existing filters (unlock, rarity, starter exclusions) still apply
  after the pool.
- Validator: every card and relic belongs to at least one pool.

### Consumers

All content reads go through ModelDb; the per-file caches and dir constants are
deleted (`MetaProgress._card_info_cache`, `RunManager` relic/tool/equipment
caches and `*_DATA_DIR`, `EnemyEntity.ENEMY_DATA_DIR`, `DiscoverPool.CARD_DIR`,
and the screen-local loops). The card factory (`cached_card_factory.gd`) fills
`preloaded_cards[full_id]` from `ModelDb.mutable("card", id)`; the addon stays
untouched. A card node's `card_name` and `card_info.id` are the full ID.
Translation keys and asset paths built from an ID use `key_entry(id)`.
`battle_scene/data_validator.gd` stays where it is and reads through ModelDb.

### Saves

- Run save `"v"` goes from 1 to 2; meta save gains `"content_v": 2`.
- On load of an older save the file is first copied to `<name>.v1.bak` (once;
  an existing backup is not overwritten), then migrated by
  `core/content/save_migration.gd` (pure functions on dictionaries): each known
  ID field is passed through `resolve` with its category. A ref that does not
  resolve is kept verbatim, so nothing the player owned is dropped; the
  existing "unknown id is skipped" behaviour of each consumer handles it.
- Run fields: `current_hero_id`, `current_hero_data.id`, `player_deck[].card_id`,
  `equipped_items`, `backpack` instances (`base`, `set_id`), `relics`,
  `tool_inventory`, `current_encounter`, `seen_random_event_ids`,
  `demo_featured_set_id`, `demo_set_piece_ids_claimed`.
  `current_hero_data` is re-read from ModelDb rather than migrated field by field.
- Meta fields: `upgrades` keys, `stash`, `base_loadout`, `base_equipped`,
  `active_bounties`, `bounty_shelf`, `cards_seen` keys, `run_history` hero and
  card/relic lists.

### Validation and tooling

- `tests/model_db_test.gd`: load, resolve rules, inject/remove/reset,
  read-only data, `to_mutable` independence, collision of the same entry in two
  categories.
- `tests/content_integrity_test.gd`: `load_errors()` empty, every card/relic in
  a pool, every `"base:..."` literal in `.gd` sources resolves in some
  category, no `.gd` file outside `core/content/` reads `res://content/`.
- `tests/save_migration_test.gd`: v1 run and meta fixtures migrate to full IDs;
  unknown refs are kept; backup written once.
- Existing tests that read content dirs switch to ModelDb. Rule tests that
  need special content use `inject`.
- `tools/gen_catalog_html.py`, `tools/check_missing_art.py`,
  `tools/i18n_audit.py` and `generate_cards.sh` point at `content/`.
  Docs that name the old dirs are updated.

## Out of scope

- Affixes stay code constants in `affix_pool.gd` (they are stat modifiers
  stored by stat key, not content stored by ID). Revisit with phase 4.
- Encounter tables and act structure stay in `RunManager` constants (phase 6);
  their literals become full IDs.
- Seeded RNG streams (phase 2b). Typed model subclasses. Mod loading UI.

## Risks

- About 210 code literals and 130 key/path format sites change. Mitigation: the
  literal-scan test, the full existing suite, and one real battle + run save /
  load cycle.
- A missed bare literal compares unequal and silently disables a rule. The scan
  test catches literals that look like IDs of registered content in comparison
  calls (`has`, `==`, `in`, `get`) as a second net.
