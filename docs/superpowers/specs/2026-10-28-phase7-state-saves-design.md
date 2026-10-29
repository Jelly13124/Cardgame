# Phase 7: State Ownership and Save Versioning

Roadmap: `docs/reviews/sts2-architecture-review/10-roadmap.md` §阶段 7. Findings: S5-02, S6-01,
S7-02, S8-02, S6-02, S8-04. Decisions delegated by the user ("follow the STS2 code structure").
Mod loading is out of scope.

## Goal

Run and profile state are plain data objects. Saves carry a schema version and migrate once,
on load, through an ordered chain of steps. Runtime code handles only the current shape: no
read-time conversion. UI changes run and profile state through service functions that return
a result. `run_system/` holds no code.

## STS2 mapping

| STS2 | Here |
|---|---|
| `Runs.RunState` | `core/run/run_state.gd` |
| `Saves.ProfileSave` / `ProgressState` | `core/meta/profile_state.gd` |
| `Saves.SerializableRun`, `ISaveSchema` | `core/save/run_save.gd` (to/from dict, `schema_version`) |
| `Saves.ProfileSave` | `core/save/profile_save.gd` |
| `Saves.Migrations` + `MigrationManager` | `core/save/migration_chain.gd` (+ the steps in run_save / profile_save) |
| player inventory commands | `core/run/backpack.gd`, `core/run/equipment.gd` (results, not booleans) |
| `Map.MapTravel` | `core/run/map_travel.gd` |

## Saves

- Every save has `schema_version`. The run save's history: v1 (bare ids), v2 (namespaced ids),
  v3 (seeded RNG), **v4** (this phase). The profile save: v1, v2 (namespaced ids), **v3**.
- `migration_chain.gd` holds the steps of a save kind (`from` → `from + 1`) and refuses a chain
  with a gap or a duplicate step. Loading applies every step from the save's version up to the
  current one, backs the original file up once, writes the result back, and hands the runtime
  only the current shape.
- Run v3 → v4 moves into the migration everything `load_run` does today: card id renames and
  retired cards, the removed gem fields and cells, `demo_set_piece_ids_offered` →
  `..._claimed`, `run_started_msec` dropped in favour of `run_elapsed_msec`,
  `current_hero_data` dropped (hero data is read from ModelDb by id), and equipment strings
  turned into equipment instances.
- Profile v2 → v3: what `load_progress` normalizes today (buildings, removed profile state),
  equipment strings in the stash and the base loadout/equipped slots turned into instances,
  and the retired `facilities` / `bounty_free_claimed` fields dropped.
- Historical samples (`tests/fixtures/saves/`) for every version migrate to the current shape
  and load (test).

## State and services

- `RunState` / `ProfileState` hold the fields that `RunManager` / `MetaProgress` hold today;
  `run_save` / `profile_save` serialize them. The autoloads keep their names and API as
  facades over the state (renaming them would touch hundreds of call sites for no behavior),
  but the data lives in the state objects.
- Equipment is always an instance dictionary in state: `as_equip_instance` goes; content that
  grants equipment by id builds the instance at that point (`make_equip_instance`).
- `backpack.gd` / `equipment.gd`: move, equip, unequip, store, discard return
  `{ok, reason}`; the character, stash and forge windows call them instead of editing arrays.
  `map_travel.gd`: entering a node (current node, floor, visited) for the map screen.
- S8-04: the RNG streams are saved since phase 2b. A merchant's rolled stock is saved in the
  run state under its node id, so reopening that merchant after a reload shows the same
  stock.

## Directories

- `run_system/core/run_manager.gd` → `autoload/run_manager.gd`, `meta_progress.gd` →
  `autoload/meta_progress.gd`, `card_upgrade.gd` → `core/run/card_upgrade.gd`,
  `affix_pool.gd` → `core/meta/affixes.gd`, other run-system core scripts to `core/run` or
  `core/meta` by owner.
- `run_system/ui/window/*` → `ui/windows/`; menus (main menu, pause, settings, rules,
  keybinds) → `ui/menus/`; shared widgets (top bar, equipment icon, backpack cell, tooltips,
  deck viewer, inventory-full modal, theme) → `ui/common/`.
- `run_system/assets/` stays where it is: art paths are referenced across the game and the
  main checkout carries uncommitted art work under them. Only code leaves `run_system/`.

## Testing

- Migration chain: gap/duplicate detection; each historical sample → current version; a
  current save round-trips unchanged; migration writes back once and backs up once.
- No `as_equip_instance` in the code; equipment state contains only instances after loading a
  v1 profile and run.
- Service results: moving into a full backpack, equipping into a wrong slot, storing a cursed
  item, return the reason.
- Merchant stock survives save/load.
- Existing tests green; playtest including Save & Quit → Continue.

## Out of scope

Renaming the autoloads, moving art assets, mod loading.
