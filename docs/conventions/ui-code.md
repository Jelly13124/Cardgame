# Conventions — UI Code

Light conventions for UI scripts. UI is currently the messiest part of the codebase; this doc documents both intent and known violations.

---

## Locations

| Concern | Files |
|---|---|
| Battle HUD (HP bar, block badge, status badges) | `battle_scene/ui/character_hud.gd` |
| Battle top bar (HP / gold / floor / relic chips / settings) | `battle_scene/ui/battle_top_bar.gd` |
| Battle notifications + pile viewer + inspect overlay | `battle_scene/battle_ui_manager.gd` |
| Map rendering (background, paths, nodes, legend) | `run_system/ui/map_renderer.gd` (extracted from map_scene) |
| Map interaction + relic modal | `run_system/ui/map_scene.gd` |
| Loot reward screen + card draft | `run_system/ui/loot_reward.gd` |
| Hero selection | `run_system/ui/hero_select.gd` |
| Shared theme | `run_system/ui/theme/wasteland_cartoon_theme.gd` (legacy filename; palette must follow Hardcore 128 Pixel Wasteland Art) |

---

## ✅ Active rules

### 1. All shared visual styling goes through the shared theme script
```gdscript
const T = preload("res://run_system/ui/theme/wasteland_cartoon_theme.gd")

# Use builders, don't reinvent StyleBoxFlat.new()
panel.add_theme_stylebox_override("panel", T.panel_with_shadow(T.PANEL_BG, T.PANEL_BORDER, 5))
```

- **Why:** consolidates the 3-way StyleBoxFlat duplication we used to have. Centralizes palette tweaks.
- **What goes in T:** shared colors, common panel/button builders, anything used in 2+ UI files.
- **What stays in the UI file:** scene-specific compositions (e.g. `_make_reward_row_style` wraps `T.panel_with_shadow` with content margins specific to loot rows).

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

- **Why:** assets may be regenerating (Codex pipeline); UI shouldn't crash. Fall back to `null` and let the UI handle missing visuals gracefully.

### 3. `@onready` for nodes that exist in `.tscn`
Don't `get_node()` at use time. Cache via `@onready var foo = $Path`.

### 4. New UI scenes use the shared `theme.tres` (if/when we make it a `.tres`)
Currently `WastelandCartoonTheme` is a legacy-named script class with builder methods (programmatic theming). A migration to `.tres` Theme resource would let `.tscn` files inherit theme automatically. Not done yet.

---

## ⚠️ Known violations (deliberate or backlog)

### A. `battle_scene.gd` reaches into `ui_manager` directly
`battle_scene.gd` calls `ui_manager.show_notification(...)`, `ui_manager.update_labels(...)`, `_update_ui_labels()` 10+ times. Tight coupling between gameplay layer and UI.

**Why we ignore the rule:** event bus refactor is deferred maintainability work. Current pain is low; cost is high.

**Reconsider:** when adding analytics, replay system, or non-UI consumers of game events.

### B. UI updates are pull-based (manual `_update_ui_labels()` calls)
Every gameplay state change is followed by a manual UI refresh call. Forgetting one = stale UI.

**Why we ignore the rule:** see A. Same deferred maintainability.

**Mitigation today:** UI refresh is cheap; we call `_update_ui_labels()` liberally rather than selectively. Wastes a few ms per turn, but no visible bug.

### C. `character_hud.gd` data layer is reached from outside via `find_child("StatusBadges", true, false)`
`status_effect_system.gd` reaches into the HUD to refresh status badge container by string-name lookup. Couples the status data layer to the UI tree structure.

**Why we ignore the rule:** quick hack from the early status effect system. Should become a signal (`status_changed`) that the HUD subscribes to.

**Reconsider:** part of the event-bus refactor.

---

## File-size discipline

Individual UI files have a soft cap of ~400 lines. Currently:

| File | Lines | Status |
|---|---|---|
| `map_scene.gd` | ~412 | ✅ Recently split (was 628 — `_draw_*` extracted to `map_renderer.gd`) |
| `loot_reward.gd` | ~362 | ✅ Recently slimmed (theme dedup) |
| `battle_top_bar.gd` | ~385 | ⚠️ Approaching cap |
| `battle_ui_manager.gd` | ~180 | ✅ OK |
| `character_hud.gd` | ~120 | ✅ OK |

When a file approaches 400 lines, the responsibilities are usually entangled. Consider splitting by concern (e.g. settings panel vs status display vs relic chips).

---

## Common mistakes

- ❌ Reinventing `StyleBoxFlat.new()` in a new UI file. → Use `T.panel_with_shadow(...)` or `T.panel_flat(...)`.
- ❌ Hardcoding a color like `Color(0.45, 0.32, 0.18, 1.0)`. → Reference `T.PANEL_BORDER` etc.
- ❌ Forgetting to call `_update_ui_labels()` after a state change. → Add the call, or (better) emit a signal the UI subscribes to.
- ❌ Reaching into another node's UI tree via `find_child("X", true, false)`. → Wire a signal from the data layer.

---

## When in doubt

- The most-recent ADRs in `docs/adr/` cover style / structure decisions.
- The shared theme palette lives in `run_system/ui/theme/wasteland_cartoon_theme.gd` - read its constants before defining new colors locally, but keep new colors aligned with Hardcore 128 Pixel Wasteland Art.
