# Design — Character / Deck pages as full-screen pseudo-scenes (+ fix map click pass-through)

**Date:** 2026-06-11
**Status:** Approved (pending spec review)
**Scope:** UI/UX only — no gameplay/data changes, no new art. Separate from the
battle-load performance task (tracked independently).

---

## Problem

Opening the Character page over the map lets clicks **pass through to the map
nodes underneath**, causing accidental node selection (误触). The Deck page also
reads as a **popup** (dim backdrop + centred panel) rather than its own screen.

### Root cause of the pass-through (the real bug)

`map_scene.gd` resolves node clicks / drag / scroll in a global **`_input(event)`**
handler. Godot's `_input` fires for the whole viewport **regardless of what
Control is painted on top** — `mouse_filter = STOP` and an opaque background do
NOT stop it. The handler's only guard is:

```gdscript
if _is_relic_choice_open or _node_click_pending:
    return
```

It does **not** check whether the Character page (`EquipmentPanel`) or the Deck
page (`RunDeckViewerModal`) is open, so map node-clicks fire underneath them.

## Goal

1. **Fix the pass-through misclick** — the map must ignore its `_input` while a
   full-screen page is open.
2. **Make both pages feel like separate screens** (full-screen, opaque) with a
   consistent **top-right X** to exit, not a popup.

---

## Current state (verified)

| Page | File | Today |
|---|---|---|
| Character | `run_system/ui/equipment_panel.gd` (`class_name EquipmentPanel`) | Already full-screen opaque (bg α=1.0), Diablo 3-zone. Exit = a **"返回地图" text button** (`UI_EQUIP_BACK_TO_MAP`) → `queue_free`. Added as child `"EquipmentPanel"` of `map_scene`. Map-only. |
| Deck / gems | `run_system/ui/run_deck_viewer_modal.gd` (`class_name RunDeckViewerModal`) | **Popup look**: dim overlay `Color(0,0,0,0.78)` + centred `1180×740` panel; inline header **"X"** → `queue_free`. Added as child `"RunDeckViewerModal"` of `map_scene`; ALSO opened in battle via `battle_ui_manager.show_run_deck_viewer()` (own CanvasLayer) and from the rest stop. |

The battle-opened Deck page is why we keep these as **pseudo-scenes** (full-screen
Control overlays), NOT real `.tscn` scene changes — a real scene change mid-battle
would tear the battle down. The map-opened pages could be real scenes, but one
overlay component that works in both contexts is simpler and loses no state.

---

## Design

### ① Block map input while a page is open (the core fix)

In `map_scene.gd`, extend the `_input` early-return guard:

```gdscript
if _is_relic_choice_open or _node_click_pending or _is_page_open():
    return
```

Add the helper:

```gdscript
## True while a full-screen page (character / deck-gem) is mounted over the map.
## map_scene resolves node clicks in the global _input(), which fires regardless
## of the opaque page painted on top — without this, clicks pass through to map
## nodes (the 误触 bug).
func _is_page_open() -> bool:
    return get_node_or_null("EquipmentPanel") != null \
        or get_node_or_null("RunDeckViewerModal") != null
```

Both pages are already added as those exact named children, and both already set
`mouse_filter = STOP` (which handles gui-based clicks — buttons inside the page).
This guard closes the `_input` gap specifically. No change needed in battle (card
input there is gui-based and the full-rect STOP overlay already blocks it).

### ② Deck page: popup → full-screen opaque + top-right X

In `run_deck_viewer_modal.gd` `_build()`:
- Change the backdrop `ColorRect` from `Color(0,0,0,0.78)` to an **opaque**
  wasteland-toned fill (e.g. `Color(0.07, 0.05, 0.035, 1.0)`) so nothing shows
  through — it reads as a screen, not a dimmed overlay.
- Drop the `CenterContainer` + fixed `1180×740` `PanelContainer` framing; let the
  content fill the screen with a comfortable `MarginContainer` (e.g. 48px) so the
  card grid + gem panel use the full width.
- Replace the inline header "X" with the **shared top-right X** (see ④),
  anchored to the page's top-right corner.

### ③ Character page: text button → top-right X

In `equipment_panel.gd` `_build()`:
- Replace the `"返回地图"` text button with the **shared top-right X** anchored
  top-right (same control, same behavior → `queue_free`). Keeps the existing
  full-screen opaque background and 3-zone layout otherwise unchanged.
- `UI_EQUIP_BACK_TO_MAP` becomes orphaned → remove it from its translation CSV.

### ④ Shared top-right X close button

Add one small static helper to `wasteland_theme.gd` so both pages get an
identical close control (convention §1: shared styling lives in the theme):

```gdscript
## A square close (✕) button styled for the full-screen pages. Caller anchors it
## top-right and connects `pressed`.
static func close_x_button() -> Button:
    var b := Button.new()
    b.text = "✕"
    b.custom_minimum_size = Vector2(48, 48)
    b.focus_mode = Control.FOCUS_NONE
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    b.add_theme_font_size_override("font_size", 24)
    b.add_theme_color_override("font_color", TEXT_MAIN)
    b.add_theme_stylebox_override("normal", button_textured("normal"))
    b.add_theme_stylebox_override("hover", button_textured("hover"))
    b.add_theme_stylebox_override("pressed", button_textured("pressed"))
    return b
```

Each page anchors the returned button to its top-right corner
(`anchor_left = anchor_right = 1.0`, small offsets) and connects
`pressed → queue_free`.

### ⑤ ESC also closes

Each page adds a minimal `_input` (or `_unhandled_input`) that closes on
`ui_cancel` and marks the event handled, so ESC works as a second exit. (The page
is `MOUSE_FILTER_STOP` and on top, so this won't leak to the map.)

---

## Out of scope (YAGNI)

- Battle-load stutter / scene-load perf — separate task (systematic-debugging).
- No conversion to real `.tscn` scenes (pseudo-scene by design — see above).
- No relayout of the Character 3-zone or Deck grid beyond removing the popup
  framing; content stays as-is.
- The pre-existing `class_name` on these two files (ADR-0006 nit) is NOT touched.

## Risks / watch-items

- **Toggle behavior:** `map_scene` opens each page by toggling on the named child
  (`_open_*` checks `get_node_or_null` and frees if present). Keep that — the X /
  ESC just calls `queue_free`, same as the second-press toggle. The top-bar
  Character/Deck buttons still toggle correctly.
- **Battle deck page:** the opaque full-screen change must still look right on the
  battle CanvasLayer (it covers the battle — intended). Verify the battle's own
  end-turn / card input is blocked while open (expected: gui-based, blocked by the
  STOP overlay).
- **ESC double-binding:** battle already has an ESC settings menu; the deck page's
  ESC handler must `set_input_as_handled()` so a single ESC closes the page
  without also toggling settings.

## Verification

- `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
  → `[OK] DataValidator…` + `[OK] Headless boot clean.`
- Runtime (godot MCP): open the Character page over the map, click where a map
  node sits → node must NOT activate (no scene change / no encounter set).
  Confirm X and ESC close both pages; confirm the Deck page is full-screen opaque
  with a top-right X, from both map and battle.
