# Conventions — Architecture Layers

How the code is organised, which layer may depend on which, and how files
reference each other. `python tools/check_layers.py` enforces the checkable
rules and runs as part of `tools/run_tests.ps1` / `tools/run_tests.sh`.

Background: `docs/reviews/sts2-architecture-review/` (report 11 and the
roadmap) explains why the project moves toward this structure and in which
phase each directory is filled.

## Target structure

```
res://
├── core/        rules only — no nodes, no scene tree, no UI
│   ├── content/     content registry, ids, loaders, validator
│   ├── combat/      combat state, damage/effect pipeline, action queue, turn phases
│   ├── effects/     one script per effect type
│   ├── listeners/   status / relic / equipment-set / ascension behaviour
│   ├── run/         run state, map, encounters, rooms, rewards, shop stock, events
│   ├── meta/        profile state, buildings, economy, bounties, codex
│   ├── save/        save files (SaveIO), migrations
│   └── rng/         named random streams
├── content/     data only (JSON): cards, enemies, relics, statuses, acts, …
├── ui/          everything that is drawn: battle, map, shop, rewards, base, windows, menus, theme
├── autoload/    thin global entry points (Settings, AudioManager, Tooltip, SceneTransition, …)
├── assets/      art, audio, fonts, translations
├── addons/      third-party plugins (untouched)
├── tests/       scene tests (+ tests/support/ helpers)
└── tools/       Python / PowerShell / shell / editor tools
```

Today only `core/save/` and `autoload/` exist; `battle_scene/` and
`run_system/` are migrated phase by phase (see the roadmap). New code goes into
the target directories whenever its layer is clear.

## Dependency rules

| Layer | May depend on | Must not depend on |
|---|---|---|
| `content/` | nothing (data only) | any code — no `.gd` files (**L3**) |
| `core/*` | other `core/` modules; `content/` through the registry; non-UI autoloads | UI scripts or scenes, by path or uid (**L1**); the scene tree: `get_tree()`, `current_scene`, `get_node(`, `get_node_or_null(`, `$Node` (**L2**) |
| `ui/*` | public `core/` services and signals; `assets/` | writing fields of `core` state objects directly |
| `autoload/` | `core/` (to wire services) | concrete UI screens |

## Referencing scripts and scenes

- Reference scripts and scenes by **uid**, with the path as a trailing comment
  (**L4**):

  ```gdscript
  const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd
  SceneTransition.change_to(MAP_SCENE_PATH)       # const MAP_SCENE_PATH := "uid://…"  # res://…
  ```

  A uid reference survives moving the file as long as its `.uid` sidecar (or
  the scene header) moves with it — move files in the Godot editor or with
  `git mv` on both `x.gd` and `x.gd.uid`.
- After moving files run `python tools/godot_refs.py sync-comments` to refresh
  the path comments, and `python tools/godot_refs.py convert` for any new
  `res://` references.
- Keep a `res://` path (and mark the line `# path-ok: <why>`) only where a uid
  cannot work:
  - `extends "res://…"` — Godot 4.6 does not accept uid there (exempt
    automatically);
  - reading a script's source text with `FileAccess` (contract tests);
  - comparing against `Script.resource_path`.
- Content JSON is never read by path outside `core/content/`: consumers ask
  ModelDb (`core/content/model_db.gd`) by category and full ID. Art paths
  (`.png`) stay path-based and derive their file token from
  `MODEL_ID.key_entry(id)`.

## `class_name`

Keep following gameplay-code rule 3: reference custom classes through a
(uid) `preload`, not the global `class_name` registry. Existing `class_name`
declarations stay where they serve type annotations; do not add new ones
unless a type annotation needs it. Older comments saying "no class_name
(project convention)" are updated when their files are next edited.

## Saves

All persistent files go through `core/save/save_io.gd` (atomic write, two
rotating backups, corrupt files preserved as `.corrupt-<time>`). Tests that
save call `tests/support/test_save_root.gd` (`use()` / `release()`) so they
never touch a real profile.
