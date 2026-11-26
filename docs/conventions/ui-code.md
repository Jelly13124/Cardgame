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
| Character window (equipment, backpack, attributes; also holds the hero picker, demo: Cowboy Bill only) | `ui/windows/character_window.gd` |
| Shared theme | `ui/common/theme/wasteland_theme.gd` (legacy filename; palette follows the original 2D American-comic/UI07 contract) |
| UI icon source (SVG) | `tools/svg_icons/gen.py` → `tools/svg_icons/svg/`, rendered by `tools/svg_icons/rasterize.gd` |

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

### 4. Text colour follows the surface under it
Almost every shared kit surface is cream paper (`#e8d6b0`). That includes
`panel_hard_9slice`, the tooltip, dropdown and input plates, the secondary button,
`ll_charcoal_panel()` and `panel_textured("dark")`, despite their names. Only
`panel_soft_9slice`, the run top bar and the battle field are dark.

| Surface | Body | Secondary | Heading |
|---|---|---|---|
| Paper (cream) | `T.PANEL_INK` (13:1) | `T.PANEL_INK_SOFT` (6.2:1) | `T.PANEL_HEADER` rust (5.7:1) |
| Dark | `T.TEXT_MAIN` | `T.TEXT_SECONDARY` | `T.UI_HEADER_GOLD` |

- On paper, ink text has no outline (`outline_size` 0). The gold and cream family is for
  dark surfaces only.
- Rarity names on paper use `EQUIPMENT_ICON.paper_rarity_color(rarity)`. The bright
  rarity colours are for dark tiles.
- Helpers that draw text take the colour as a parameter, for example
  `T.currency_row(..., text_color)` and `T.overlay_cost_badge(..., text_color)`. Pass the
  ink colour when the row sits on paper.
- Aim for at least 4.5:1 contrast for body text.

### 5. Buttons come in two families, set by `T.apply_action_button(button, role)`
- **Primary** (`"primary"`): the rust plate with light text, for the main action on a screen.
- **Secondary** (`"secondary"`) and **list** (`"list"`): the cream plate
  (`run_system/assets/images/ui/kit/button_secondary_base.png`, ink rim) with `PANEL_INK` text, `PANEL_HEADER` on
  hover and `PANEL_INK_SOFT` when disabled. `kit_box("button_secondary_*")`,
  `ll_button_olive()` and the legacy skins all resolve to this plate.
- Do not override a secondary button's font colour with a light colour. Rust or tinted
  primary-style buttons keep light text.
- A close button is always `T.ll_close_button(px)`. It shows the white × glyph
  (`ui_kit_lightline/glyph_close.png`) tinted ink, and rust on hover. It falls back to a
  text × only when the glyph is missing.

### 6. Small UI icons come from SVG source
The icons for the top bar, main menu, enemy intents, currency, card reward, piles, lock
and close are drawn in code in `tools/svg_icons/gen.py`. Map node icons
(`run_system/assets/images/map/nodes/`) are not: the owner kept their hand-drawn art
(2026-11-25), so do not add them to the manifest.

- **What the script does:** `rasterize.gd` renders each SVG with Godot's own SVG renderer
  and overwrites the PNG at the path the game already loads. So no `.gd` or test changes
  when an icon changes.
- **To change an icon:**
  1. Edit `gen.py`.
  2. Run it.
  3. Run the rasteriser.
  4. Run `--import`.

  The exact commands are in the script's docstring.
- **Do not hand-edit those PNGs, and do not ask Codex to redraw them.** The list of
  targets is `MANIFEST` in `gen.py`.
- **Status, attribute, relic, equipment and tool art** stays Codex PNG art.

### 7. New UI scenes use the shared `theme.tres` (if/when we make it a `.tres`)
Currently `WastelandTheme` is a legacy-named script class with builder methods (programmatic theming). A migration to `.tres` Theme resource would let `.tscn` files inherit theme automatically. Not done yet.

---

## ⚠️ Known violations (deliberate or backlog)

### A. Battle UI refresh is partly pull-based
Combat rules no longer touch the UI (`core/combat/` runs headless since the phase 5 split), but on the UI side `ui/battle/battle_presenter.gd` and `ui/battle/hand_view.gd` still call `screen._update_ui_labels()` directly after changes. The player's `stats_changed` / `status_changed` signals also trigger it. Forgetting a call leaves stale labels.

**Why we ignore the rule:** the refresh is cheap and the remaining call sites are few; replacing them with per-label signals is deferred.

**Reconsider:** when adding a non-UI consumer of these events (replay, analytics) or when a stale label bug appears.

### B. No gamepad / keyboard focus yet (TODO, deferred)
Every screen is mouse-first: buttons are built with `focus_mode = FOCUS_NONE`, no screen grabs focus when it opens, and overlays (settings, pause, slot picker, modals) are tracked with per-screen fields instead of one screen stack.

**Why we ignore the rule:** the owner deferred gamepad support on 2026-11-26; it is a TODO for when there is time. The installed skills `godot-ui-control` and `game-ui-ux` describe the target.

**When we pick it up:**
1. Audit every screen first (main menu, settings, pause, map, battle, rewards, shop, rest, event, home base, deck views), then show the owner a staged plan before changing code.
2. Give interactive controls a focus mode other than `FOCUS_NONE`, focus one control when a screen opens, and restore focus when an overlay closes.
3. Set focus neighbours where containers do not give a sensible order (map nodes, hand cards, shop grid).
4. Map `ui_accept` / `ui_cancel` and the battle actions (`end_turn`, pile views) to gamepad buttons in `autoload/settings.gd` key bindings.
5. Add a headless test that every screen has a focused control after opening.
6. Keep the current look: focus feedback reuses the hover/selection outline (see the UI gate in `AGENTS.md`).

---

## File-size discipline

Individual UI files have a soft cap of ~400 lines. Currently:

| File | Lines | Status |
|---|---|---|
| `battle_screen.gd` | ~1165 | ⚠️ Over cap — views, input, targeting, HUD and post-combat routing in one room script |
| `map_scene.gd` | ~840 | ⚠️ Over cap — the node map view draws the map; room opening and the rest choice still live here |
| `run_top_bar.gd` | ~670 | ⚠️ Over cap — vitals, chips, buttons and relic shelf |
| `loot_reward.gd` | ~620 | ⚠️ Over cap |
| `play_card.gd` | ~590 | ⚠️ Over cap — card face, skins, text fitting and hover |
| `battle_ui_manager.gd` | ~350 | ✅ OK |
| `character_hud.gd` | ~310 | ✅ OK |
| `battle_top_bar.gd` | ~50 | ✅ Hosts run_top_bar |

Line counts as of 2026-11-24.

When a file approaches 400 lines, the responsibilities are usually entangled. Consider splitting by concern (e.g. settings panel vs status display vs relic chips).

---

## Common mistakes

- ❌ Reinventing `StyleBoxFlat.new()` in a new UI file. → Use `T.panel_with_shadow(...)` or `T.panel_flat(...)`.
- ❌ Hardcoding a color like `Color(0.45, 0.32, 0.18, 1.0)`. → Reference `T.PANEL_BORDER` etc.
- ❌ Light text (`TEXT_MAIN`, `UI_HEADER_GOLD`, a cream `Color(...)`) on a cream panel or secondary button. → `T.PANEL_INK` / `PANEL_INK_SOFT` / `PANEL_HEADER`.
- ❌ Redrawing a UI icon PNG by hand. → Change `tools/svg_icons/gen.py` and re-render.
- ❌ Forgetting to call `_update_ui_labels()` after a state change. → Add the call, or (better) emit a signal the UI subscribes to.
- ❌ Reaching into another node's UI tree via `find_child("X", true, false)`. → Wire a signal from the data layer.

---

## When in doubt

- Read `docs/project-rules.md`, `docs/art-style-reference.md`, and
  `docs/PROJECT_STRUCTURE.md` for current style and structure rules.
- The shared theme palette lives in `ui/common/theme/wasteland_theme.gd` - read its constants before defining new colors locally, and keep new colors aligned with the original 2D American-comic/UI07 direction.
