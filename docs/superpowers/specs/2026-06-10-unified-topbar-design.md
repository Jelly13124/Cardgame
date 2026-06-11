# Design — Unified StS-style Top Bar (map + battle) with relic shelf

**Date:** 2026-06-10
**Status:** Approved (pending spec review)
**Scope:** UI restyle only — no gameplay/data changes, no new art assets.

---

## Problem

The game has **two divergent top bars**:

- **Battle** (`battle_scene/ui/battle_top_bar.gd`, Control node under
  `battle_scene.tscn` → `TopBarLayer/TopBar`, layer 30): chip-based, already
  shows a relic strip. ~385 lines (⚠️ near the ~400-line soft cap).
- **Map** (`run_system/ui/map_renderer.gd` `_draw_top_bar()`): raw `draw_string`
  text (`生命 / 金币 / 层数 / 幕 / 等级`), **no panel framing, no relic display.**

The map bar is the ugly one in the user's screenshot, and the map screen never
shows the player's relics. The two bars look nothing alike.

## Goal

One **shared StS-style top-bar component** used by both map and battle:

- Polished, on-brand (Offbeat Adult Sci-Fi Cartoon Wasteland) framing — no raw text.
- HP and XP rendered as real **progress bars** with overlaid value labels.
- A **relic shelf** row below the main bar, shown on **both** scenes.
- Pure code — reuse `wasteland_theme.gd` primitives + existing relic PNG icons.
  No external assets, no Codex handoff.

## Chosen layout (approved)

Plan A main bar + relics moved to their own row **below** the bar:

```
┌────────────────────────────────────────────────────────────────────┐
│ [HP ▓▓▓▓▓░ 40/50]                          [⛁ 220] [幕1/3·层5] [D][U][⚙]│  ← main bar
│ [XP ▓▓▓░░ Lv3·14/22]                                                 │
├────────────────────────────────────────────────────────────────────┤
│ 遗物  (◉)(◉)(◉)(◉)(◉) …                                              │  ← relic shelf
└────────────────────────────────────────────────────────────────────┘
```

- **Left vitals block:** `HP ProgressBar` stacked over `XP ProgressBar`, each
  with a centered overlay `Label` (`40 / 50`, `Lv 3 · 14/22`).
- **Right cluster:** Gold chip · Act/Floor chip · button group.
- **Relic shelf:** left-aligned `HBoxContainer` of round relic medallions with
  tooltips; a small `遗物` caption leads the row.

---

## Architecture

### New component: `run_system/ui/run_top_bar.gd` (extends `Control`)

Lives in `run_system/ui` because it reads `RunManager` (autoload) and relic data
under `run_system/data` — shared between the run layer (map) and battle.

Internal structure (built programmatically, mirroring the existing
`battle_top_bar` build style):

```
run_top_bar (Control, min height ≈ 108)
├── Background (ColorRect, warm dark, full width, main-bar height)
├── BottomLine (ColorRect accent border under main bar)
├── MainRow (MarginContainer → HBoxContainer)
│   ├── Vitals (VBoxContainer)
│   │   ├── HPBar   (ProgressBar + centered overlay Label)
│   │   └── XPBar   (ProgressBar + centered overlay Label)
│   ├── Spacer (SIZE_EXPAND_FILL)
│   ├── GoldChip   (PanelContainer: coin + value)
│   ├── ActChip    (PanelContainer: 幕 a/N · 层 f)
│   └── Buttons (HBoxContainer: Deck / Character? / Settings?)
└── RelicShelf (HBoxContainer of relic medallions, second row)
```

### Configuration (exported / set by host before `_ready` work runs)

| Property | Type | Map | Battle | Purpose |
|---|---|---|---|---|
| `hp_from_player` | `bool` | `false` | `true` | Battle reads live `main.player.health`; map reads `RunManager.current_health`. |
| `show_character_button` | `bool` | `true` | `false` | Equipment is locked in combat. |
| `show_settings_button` | `bool` | `false` | `true` | Battle keeps the settings/return-to-map menu. |
| `player_source` | `Node` | `null` | `main.player` | Live HP node when `hp_from_player`. |

### Signals (host wires these; component stays scene-agnostic)

- `deck_pressed` — open the run deck / gem viewer.
- `character_pressed` — open the equipment/character panel (map only).
- `settings_pressed` — open the settings menu (battle only).

The component never changes scenes or opens modals itself; it only renders state
and emits intent. This keeps the gameplay/UI coupling at the host boundary.

### Data flow & refresh

- On `_ready`/setup: connect to `RunManager` signals already used today —
  `health_changed`, `resources_changed`, `backpack_changed` (gold lives in the
  backpack), `relics_updated`. When `hp_from_player`, also connect the player's
  `health_changed`.
- Each signal triggers a targeted refresh:
  - `_refresh_vitals()` — HP bar value/label + XP bar value/label.
  - `_refresh_gold_act()` — gold + act/floor chips.
  - `_refresh_relics()` — rebuild the relic shelf.
- HP source resolution: prefer a valid `player_source` when `hp_from_player`,
  else fall back to `RunManager.current_health / max_health`.

### Relic medallion

Port the existing `battle_top_bar._make_relic_chip` logic into the shared
component (or a tiny `_make_relic_medallion` helper):

- Round medallion, relic PNG icon via the defensive `_load_texture` helper,
  letter fallback when no icon.
- Hover highlight + custom `Tooltip` autoload anchored above the chip.
- **Lambda safety (project bug class):** the `mouse_entered` lambda must
  `is_instance_valid(chip_ref)` before touching the captured chip; `mouse_exited`
  and `tree_exited` both call `Tooltip.hide_if_owner(chip_id)` so a stale
  callback can't leak a tooltip past a relic-strip rebuild.

---

## Host integration

### Battle — `battle_scene/ui/battle_top_bar.gd` slims to a host

- Keep: the settings menu (`settings_panel`, resume / return-to-map / exit) and
  its `_input` ESC handling — substantial and battle-specific.
- Replace: the hand-built chip row + relic strip with one `run_top_bar` child
  configured `hp_from_player = true`, `player_source = main.player`,
  `show_settings_button = true`, `show_character_button = false`.
- Wire: `deck_pressed → _on_deck_pressed`, `settings_pressed → _show_settings`.
- Net: both `battle_top_bar.gd` and the new component land **under** the
  ~400-line cap.

### Map — `run_system/ui/map_scene.gd`

- Add a `run_top_bar` child (inside a `CanvasLayer` so it sits above the
  custom-drawn map), configured `hp_from_player = false`,
  `show_character_button = true`, `show_settings_button = false`.
- Wire: `deck_pressed → _open_run_deck_viewer`,
  `character_pressed → _open_equipment_panel`.
- **Remove** `map_renderer.draw()`'s call to `_draw_top_bar()` and delete that
  method (the raw-text bar is fully superseded).
- **Remove** `_build_equipment_button()` and `_build_deck_button()` (their
  buttons now live in the shared bar). Keep their target methods
  (`_open_equipment_panel`, `_open_run_deck_viewer`) — now invoked via signal.
- Map already connects `health_changed / resources_changed / backpack_changed /
  relics_updated` for `queue_redraw`; the component connects its own copies for
  its refresh. No conflict (both are read-only observers).

---

## Visual spec

- Panels/buttons: `wasteland_theme` `panel_textured(...)` / `button_textured(...)`
  9-slice, or `panel_flat` / `rounded_button` for chips. No new `StyleBoxFlat`
  reinvention, no inline hex (convention §1).
- HP fill: warm red (≈ existing `Color(0.82, 0.16, 0.10)`); track dark maroon.
- XP fill: `T.ACCENT_NEON_GREEN`; track dark olive.
- Text: `T.TEXT_MAIN` on dark; chip captions `T.TEXT_SECONDARY`.
- Both scenes show gold + `幕 a/N · 层 f` (battle previously showed only floor —
  unified to match, per approval).

## Out of scope (YAGNI)

- The in-battle `character_hud.gd` (HP/block/status badges over the player
  sprite) is untouched.
- No relic data/behavior changes.
- No new settings menu on the map (buttons relocate only; behavior unchanged).
- No `.tres` theme migration (convention §4 remains deferred).

## Risks / watch-items

- **Layer/scene mismatch:** map is a custom-`_draw()` Control; the bar must be a
  child `CanvasLayer` (or a top-anchored Control above the draw) so it isn't
  overpainted and isn't scrolled with the map.
- **Gold source:** map reads gold from the backpack (`backpack_changed`), not
  `resources_changed` — the component must connect `backpack_changed` or the
  gold readout goes stale after loot drops (same bug the map bar already guards).
- **File-size cap:** verify both touched `.gd` files stay < ~400 lines after the
  refactor.

## Verification

- `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
  → `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
- Manual/MCP check: launch, confirm map bar shows framed HP/XP bars + relics +
  working Deck/Character buttons; confirm battle bar unchanged in function with
  the new look and live HP.
