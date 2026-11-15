# Conventions — UI Code

Light conventions for UI scripts. UI is currently the messiest part of the codebase; this doc documents both intent and known violations.

---

## Locations

| Concern | Files |
|---|---|
| Battle HUD (HP bar, block badge, status badges) | `ui/battle/character_hud.gd` |
| Shared top bar (HP/XP bars, gold/act chips, relic shelf) | `ui/common/run_top_bar.gd` |
| Battle top-bar host (settings/pause menu only) | `ui/battle/battle_top_bar.gd` |
| Battle notifications + pile viewer + inspect overlay | `ui/battle/battle_ui_manager.gd` |
| Act map view (scroll, layout, dashed paths, legend) | `ui/map/node_map_view.gd` |
| One map node (octagon, icon, state, pulse) | `ui/map/map_node_button.gd` |
| Map screen (room opening, relic modal, peek) | `ui/map/map_scene.gd` |
| Loot reward screen + card draft | `ui/rewards/loot_reward.gd` |
| Hero selection (demo: Cowboy Bill only) | `ui/windows/character_window.gd` |
| Shared theme | `ui/common/theme/wasteland_theme.gd` (legacy filename; palette follows the original 2D American-comic/UI07 contract) |

---

## ✅ Active rules

### 1. All shared visual styling goes through the shared theme script
```gdscript
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd

# Use builders, don't reinvent StyleBoxFlat.new()
panel.add_theme_stylebox_override("panel", T.panel_with_shadow(T.PANEL_BG, T.PANEL_BORDER, 5))
```

- **Why:** consolidates the 3-way StyleBoxFlat duplication we used to have. Centralizes palette tweaks.
- **What goes in T:** shared colors, common panel/button builders, anything used in 2+ UI files.
- **What stays in the UI file:** one-off inline compositions used by a single caller. If two scenes need the same composition, promote it to a `WastelandTheme` static method instead of duplicating the wrapper.

### 2. Texture loading goes through a defensive `_load_texture(path)` helper
Pattern used in `map_scene.gd`, `loot_reward.gd`, and others:
```gdscript
func _load_texture(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path)
    if FileAccess.file_exists(path):
        var image = Image.new()
        if image.load(...) == OK:
            return ImageTexture.create_from_image(image)
    push_warning("MissingTexture: %s" % path)
    return null
```

- **Why:** assets may be regenerated independently from code; UI should not crash. Fall back to `null` and let the UI handle missing visuals gracefully.

### 3. `@onready` for nodes that exist in `.tscn`
Don't `get_node()` at use time. Cache via `@onready var foo = $Path`.

### 4. New UI scenes use the shared `theme.tres` (if/when we make it a `.tres`)
Currently `WastelandTheme` is a legacy-named script class with builder methods (programmatic theming). A migration to `.tres` Theme resource would let `.tscn` files inherit theme automatically. Not done yet.

---

## ⚠️ Known violations (deliberate or backlog)

### A. Battle UI refresh is partly pull-based
Combat rules no longer touch the UI (`core/combat/` runs headless since the phase 5 split), but on the UI side `ui/battle/battle_presenter.gd` and `ui/battle/hand_view.gd` still call `screen._update_ui_labels()` directly after changes. The player's `stats_changed` / `status_changed` signals also trigger it. Forgetting a call leaves stale labels.

**Why we ignore the rule:** the refresh is cheap and the remaining call sites are few; replacing them with per-label signals is deferred.

**Reconsider:** when adding a non-UI consumer of these events (replay, analytics) or when a stale label bug appears.

---

## File-size discipline

Individual UI files have a soft cap of ~400 lines. Currently:

| File | Lines | Status |
|---|---|---|
| `battle_screen.gd` | ~1160 | ⚠️ Over cap — views, input, targeting, HUD and post-combat routing in one room script |
| `map_scene.gd` | ~840 | ⚠️ Over cap — the node map view draws the map; room opening and the rest choice still live here |
| `run_top_bar.gd` | ~670 | ⚠️ Over cap — vitals, chips, buttons and relic shelf |
| `loot_reward.gd` | ~620 | ⚠️ Over cap |
| `play_card.gd` | ~590 | ⚠️ Over cap — card face, skins, text fitting and hover |
| `battle_ui_manager.gd` | ~350 | ✅ OK |
| `character_hud.gd` | ~310 | ✅ OK |
| `battle_top_bar.gd` | ~50 | ✅ Hosts run_top_bar |

Line counts as of 2026-11-13.

When a file approaches 400 lines, the responsibilities are usually entangled. Consider splitting by concern (e.g. settings panel vs status display vs relic chips).

---

## Common mistakes

- ❌ Reinventing `StyleBoxFlat.new()` in a new UI file. → Use `T.panel_with_shadow(...)` or `T.panel_flat(...)`.
- ❌ Hardcoding a color like `Color(0.45, 0.32, 0.18, 1.0)`. → Reference `T.PANEL_BORDER` etc.
- ❌ Forgetting to call `_update_ui_labels()` after a state change. → Add the call, or (better) emit a signal the UI subscribes to.
- ❌ Reaching into another node's UI tree via `find_child("X", true, false)`. → Wire a signal from the data layer.

---

## When in doubt

- Read `docs/project-rules.md`, `docs/art-style-reference.md`, and
  `docs/PROJECT_STRUCTURE.md` for current style and structure rules.
- The shared theme palette lives in `ui/common/theme/wasteland_theme.gd` - read its constants before defining new colors locally, and keep new colors aligned with the original 2D American-comic/UI07 direction.
