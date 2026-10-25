# Conventions — Data Files (JSON)

The game's content lives in JSON: cards, enemies, relics, and encounter pools. These files are the source of truth for balance and content — gameplay code reads them, never the reverse.

---

## Locations

All content JSON lives under `content/<type>/`, one file per entry. ModelDb
(`core/content/model_db.gd`) loads it once; nothing outside `core/content/`
reads these files by path.

| Category | Location | Validator |
|---|---|---|
| card | `content/cards/{id}.json` | `DataValidator.validate_card()` |
| monster (incl. elites + boss) | `content/monsters/{id}.json` | `DataValidator.validate_enemy()` |
| relic | `content/relics/{id}.json` | `DataValidator.validate_relic()` |
| equipment / equipment_set | `content/equipment/`, `content/equipment_sets/` | `validate_equipment()` / `validate_equipment_set()` |
| event | `content/events/{id}.json` | `validate_event()` |
| tool | `content/tools/{id}.json` | `validate_tool()` |
| bounty | `content/bounties/{id}.json` | `validate_bounty()` |
| character | `content/characters/{id}.json` | `validate_hero()` |
| base_upgrade | `content/base_upgrades/{id}.json` | `validate_base_upgrade()` |
| card_pool / relic_pool | `content/card_pools/`, `content/relic_pools/` | ModelDb reference check |
| Encounter pools | constants in `run_system/core/run_manager.gd` | `DataValidator.validate_encounter_pools()` |

Art stays in `battle_scene/assets/` and `run_system/assets/`.

---

## IDs

- A content ID is `"<namespace>:<entry>"`. Shipped content is `base`, so
  `content/cards/strike.json` is `base:strike`. The category is not part of the
  ID: the same entry may exist in two categories (`adrenaline_shot` is both an
  event and a tool).
- Runtime state, saves and code literals hold **full** IDs
  (`relics.has("base:crit_clip")`). A bare literal in code compares unequal to
  run state; `tests/content_integrity_test.gd` fails on one. Mark a genuine
  non-ID string that shares an entry name with `# bare-ok: <reason>`.
- References inside JSON may be bare (`"set_id": "warden"`). The loader
  resolves them in the file's own namespace, then `base`, and stores full IDs,
  so consumers never resolve refs. Unresolved refs are load errors.
- Translation keys, asset file names and node names use
  `MODEL_ID.key_entry(id)`: the bare entry for `base` (keys stay
  `CARD_strike_TITLE`, `RELIC_CRIT_CLIP_NAME`), `<ns>_<entry>` for others.

## Pools

A character names its `card_pool` and `relic_pool`. Run offers (draft,
discover, shop, relic rewards) read `RunManager.current_card_pool()` /
`current_relic_pool()`; every card and relic must belong to some pool.

## Tests and mods

`MODEL_DB.inject_dir(path, ns)` loads a directory laid out like `content/`;
`inject(category, ns, entry, data)` adds one entry; `remove` and `reset`
undo them. Rule tests that need special content inject it instead of relying
on shipped data (see `tests/fixtures/content_mod/`).

---

## Naming

- Filename = the local `id` field inside, no extension. `strike.json` → `id: "strike"`.
- The local `id` is **lower-snake-case**: `stun_baton`, `junkyard_tyrant`. No spaces, no caps, no dots.
- Display title is the human-readable `title` (cards, relics, tools, events) or `name` (monsters, equipment, sets, characters) field — separate from `id`. `Stun Baton` is the title; `stun_baton` is the id.

---

## Required fields

### Cards
```json
{
  "id": "card_id",            // matches filename
  "title": "Display Name",
  "type": "attack|skill|ability|curse",
  "cost": 1,
  "effects": [ ... ]
}
```
Optional: `description`, `front_image`, `side`, `rarity` (`common|uncommon|rare|unique|curse`), `retain` (bool).

**Curse cards** (`type: "curse"`, `rarity: "curse"`) are unplayable penalty cards. They MUST set `"unplayable": true`, and may carry `"end_turn_in_hand": [<effect>, …]` — effects applied **to the player** at the end of every turn the card sits in hand (the penalty; each entry reuses the card effect vocabulary). Excluded from every normal card pool; injected by enemies (temporary — shuffled into the combat draw pile) and by events (permanent — into the run deck, clearable at the shop's card-removal service).

#### Card vars

Write each number once: `"vars": {"damage": 6, "weak": 1}` and refer to it from
any effect field as `"$damage"`. ModelDb fills the numbers in at load (the raw
list stays as `effects_template`); an unknown `$name` is a load error.

#### The optional `upgrade` block (in-run card upgrades)

`"upgrade": {"vars": {"damage": 3}}` adds deltas to the vars (STS2
`UpgradeValueBy`); `cost`, `title` and `description` override; an `effects` list
there is a structural replacement (it may use `$name`, filled with the upgraded
vars). A card with none of these uses each effect type's default deltas (the
`upgrade` key of its definition in `combat_effects.gd`).

Cards grow **in-run** via the rest-campfire upgrade picker. `run_system/core/card_upgrade.gd` (`resolve()`) is the source of truth; `deck_manager.gd` applies it at battle start when a `player_deck` entry's `upgraded` flag is set. There are **no `_plus` variant JSON files** — a card has at most one JSON, plus an optional upgrade rule inside it.

A card may carry an optional top-level `"upgrade"` dict that **overrides** the base card when upgraded:

```json
{
  "id": "charged_shot", "type": "attack", "cost": 1,
  "effects": [ { "type": "deal_damage_str_mult", "mult": 2 }, { "type": "exhaust_self" } ],
  "upgrade": {
    "cost": 0,                                  // optional — overrides cost
    "title": "Charged Shot+",                   // optional — overrides title
    "description": "Deal 3× your Strength. Exhaust.",  // optional — overrides description
    "effects": [                                // optional — FULL replacement of effects[]
      { "type": "deal_damage_str_mult", "mult": 3 }, { "type": "exhaust_self" }
    ]
  }
}
```

- Every `upgrade` field is optional; any subset may be present. `vars` adds deltas to the card's vars (the usual form); `effects`, if present, **replaces** the whole base `effects[]` (a structural change; it may use `$name`).
- **No `upgrade.vars` / `upgrade.effects` → default deltas.** Most cards now declare `upgrade.vars` explicitly; otherwise `resolve()` bumps only the unambiguously-beneficial numeric fields; everything else is left unchanged, which is the signal that a card needs a bespoke block. Field names match the card JSON: damage/block/stat/draw use `amount`; status applies use `stacks`.

  | Effect type | Field bumped | Δ |
  |---|---|---|
  | `deal_damage`, `deal_damage_all` | `amount` | +2 |
  | `gain_block` | `amount` | +3 |
  | `gain_strength` / `gain_luck` / `gain_intelligence` / `gain_energy` | `amount` | +1 |
  | `apply_status`, `apply_status_all` | `stacks` | +1 |
  | `draw_cards` | `amount` | +1 |
  | anything else (`deal_damage_str_mult`, `scale_damage_by_attacks`, `add_card_to_hand`, self-debuff, …) | — | unchanged → route to a bespoke `upgrade` block |

- **Curses are never upgradeable** — cards with `"type": "curse"` are skipped entirely (`is_upgradeable()` returns `false`; the modal dims them and the catalog renders no upgrade line). Do NOT add an `upgrade` block to a curse.
- `cost` is **only ever** changed by a bespoke `upgrade.cost`; the formula never touches cost.
- The browsable catalog (`tools/gen_catalog_html.py`) mirrors this resolver in Python and renders an "Upgraded" panel under each non-curse card — keep the two in sync when the rules change.

### Enemies
```json
{
  "id": "enemy_id",            // matches filename
  "name": "Display Name",
  "sprite_id": "sprite_id",    // folder name under enemies/
  "tier": "normal",            // minion|normal|heavy|elite|boss
  "max_health": 30,
  "action_pattern": [ ... ]
}
```
`tier` is required encounter identity metadata. Heavy enemies may appear on normal nodes but only solo; post-opening minions must be paired; elites and bosses belong only to their dedicated rosters. `validate_encounter_pools()` enforces the explicit four-band HP budgets (12–18 / 20–30 / 25–34 / 34–50).

Each action entry needs `type` (one of `ALLOWED_ENEMY_ACTION_TYPES`). `attack_status` actions also need `status` + `stacks`. Attacks marked `"interruptible": true` can be cancelled by 1 stack of stun.

Optional `phases` (array) — HP-threshold phase transitions. Each phase has `hp_below` (fraction in `(0, 1]`), an `action_pattern` (validated like the top-level one), and an optional `on_enter` array of actions fired once on entering the phase.

### Relics
```json
{
  "id": "relic_id",
  "title": "Display Name",
  "effects": [
    { "trigger": "trigger_name", "type": "effect_type", ... }
  ]
}
```

---

## Effect types (cards)

Authoritative list: the combat effect definitions registered in `battle_scene/combat/combat_effects.gd` (`DataValidator.allowed_card_effect_types()`). As of this writing:

- Damage: `deal_damage`, `deal_damage_all`, `deal_damage_str_mult` (damage = `mult` × Strength; needs `mult`), `scale_damage_by_attacks`, `deal_damage_block_mult`
- Defense: `gain_block`
- Resources: `gain_energy`, `draw_cards`, `gain_gold`, `lose_gold`, `heal`, `lose_hp`
- Attributes: `gain_strength`, `gain_constitution`, `gain_intelligence`, `gain_luck`, `gain_charm`, `double_strength`
- Status: `apply_status`, `apply_status_self`, `apply_status_all`, `apply_short_circuit_scaled`, `apply_stun`, `apply_stun_all`, `overload`
- Cards / curses: `add_card_to_hand`, `add_curse_to_deck`, `discover` (3-choose-1 into the hand; `pool` = a card type or a theme tag such as `short_circuit`, `count`, optional `free` = costs 0 this combat)
- Bill / attack allowance: `gain_attack_allowance`, `restore_attack_allowance`
- Legacy compatibility: `flip_polarity` remains accepted for old data/save compatibility but is inert in the current Bill-only kit.
- Marker: `exhaust_self`

**Global attributes:** STR is auto-added to every powered card damage hit and CON to every card Block gain (`core/combat/rules/attribute_rules.gd`, default +3 each); relic, equipment-set and tool values are fixed. The per-card `scaling` field is **deprecated** — nothing reads it. Card JSON carries the BASE number only. (`deal_damage_str_mult`, `deal_damage_block_mult` and `scale_damage_by_attacks` compute their own base and do NOT receive the global +STR.) See the PRD "Combat Value Pipeline" section for the full order.

**Status scaling (Intelligence):** `apply_status` and `apply_status_all` add the player's Intelligence to the base stacks. `apply_short_circuit_scaled` is the dedicated Short Circuit formula and may additionally use `attr`, `mult`, `flat`, and `double_if_short_circuited`. `overload` consumes every enemy's stored Short Circuit and deals that much delayed damage; it is global and does not target a single enemy.

**Tools:** `content/tools/{tool_id}.json` are one-time battle consumables — shape `{id, title, target ("enemy"|"self"|"none"), rarity, effects[], icon}`. Their `effects[]` reuse this same effect vocabulary (resolved through the shared effect registry as tool sources: fixed values — no STR/CON, Weak/Vulnerable or crits — after their own ×(1+0.08·INT) scaling); validated by `DataValidator.validate_tool` (`REQUIRED_TOOL_KEYS` / `ALLOWED_TOOL_TARGETS`).

When adding a new effect type, register it once in `battle_scene/combat/combat_effects.gd` (`register_into`) with its handler and definition.

---

## Enemy action types

Authoritative list in `DataValidator.ALLOWED_ENEMY_ACTION_TYPES`:

- `attack` — single damage to player
- `attack_status` — damage + apply status to player
- `attack_all` — AoE damage (currently single-player target, with louder messaging)
- `block` — self-block
- `heal` — self-heal
- `telegraph` — no-op + "CHARGING" intent badge, sets up next action as interruptible
- `summon` — spawns add enemies mid-combat. Required: `enemy_ids` (array of enemy ids); optional `count` (default 1). Capped at `MAX_ENEMIES_ON_FIELD` (4) — spawns past the cap are skipped. e.g. `{"type":"summon","enemy_ids":["scrap_shard"],"count":2}`
- `buff_self` — applies a status to the acting enemy itself. Required: `status` (∈ the status definitions (`content/statuses/`), e.g. `thorns`), `stacks`. e.g. `{"type":"buff_self","status":"thorns","stacks":3}`

---

## Status names

Authoritative list in `the status definitions in `content/statuses/` (`DataValidator.allowed_status_names()`)`:

`short_circuit`, `burn`, `weak`, `vulnerable`, `stun`, `regen`, `thorns`, `frail`,
`intangible`, `metallicize`, `feel_no_pain`, `hot_streak`, `all_in`, `deadeye`,
`overload_protocol`, `covering_reload`, `reactive_plating`, `loaded`, `bullet`

`short_circuit` stores delayed damage on enemies and does not tick or decay by
itself; the `overload` effect consumes all stored stacks on all enemies and deals
the corresponding damage. `burn` deals damage and then halves its stacks.
`thorns` reflects damage and loses 1 stack per trigger. `metallicize`,
`feel_no_pain`, and the named Bill powers are persistent combat statuses.
Intelligence is added to player-applied `apply_status` / `apply_status_all`
stacks. The removed Bleed and Heat systems must not be reintroduced by data.

**Stun is enemy-only.** Enemy skips its next turn per stack.

---

## Validation lifecycle

`DataValidator.validate_all_data_at_startup()` runs in `RunManager._ready()`. It scans the registered gameplay data sources and reports failures via `push_error`. In debug builds it `assert(false)` to crash loud; in release builds it logs and continues.

To verify locally:
```bash
godot --headless --path . --quit-after 5
```
Expected output: `DataValidator: all card/enemy/relic JSON files passed schema check.`

If you see `X validation failure(s)`, the error log above explains what's wrong (missing field, unknown effect type, typo in status name, encounter pool references a missing enemy id, etc.).

---

## Conventions, not rules (yet)

- **Cost range:** cards currently use 0, 1, or 2 energy. We haven't formalized a max — but cost 3+ should justify itself.
- **HP / damage scale:** enemy HP ranges from 12 (swarmer) to 110 (boss). Player has 50 max HP. Damage from individual cards: 2-12; from boss: up to 22 per hit. Scaling rules aren't formal yet — adjust by playtest.
- **Rarity weights** (for loot draft): common 70 / uncommon 25 / rare 5. Defined in `loot_reward.gd`.

---

## Common mistakes

- ❌ Typo'd key like `"retian": true` — validator catches as warning ("unknown top-level key 'retian'").
- ❌ Effect type spelled `deal_dmg` instead of `deal_damage` — validator catches as error.
- ❌ Enemy `sprite_id` doesn't match a folder under `enemies/` — game runs with a `ColorRect` placeholder and emits only a warning. If you intended to use an existing sprite, double-check the spelling.
- ❌ Adding a new effect type to JSON without registering it in `combat_effects.gd` — the validator rejects any card type that has no registered definition.
