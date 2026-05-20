# Theme Finalization Slice

**Date:** 2026-05-20
**Branch target:** `hero-refinement-v2`
**Estimated effort:** 2–3 hours
**Risk:** Low (mechanical replacements, single owner per change)

## Why

`WastelandTheme` (`run_system/ui/theme/wasteland_theme.gd`) was introduced as the single source of truth for UI styling, but the migration off the previous per-file `_make_*_style()` helpers and palette aliases stopped short. The result is mixed-state code:

- Three UI scripts still expose local `_make_*_style()` wrappers, even though those wrappers now contain only a one-line forward to `WastelandTheme`.
- `WastelandTheme` keeps seven legacy palette aliases (`PANEL_BG_BANNER`, `PANEL_BORDER_WARM`, `PANEL_HIGHLIGHT`, `ROW_BG`, `ROW_HOVER_BG`, `ROW_PRESSED_BG`, `CYAN_EDGE`) for backward compatibility. Two of them have zero callers; the remaining five all live in `loot_reward.gd`.
- ADR-0010 explicitly flagged the aliases as short-term tech debt to be removed in a "Slice 1B+" follow-up. That follow-up is this slice.

Closing this gap means future palette / theme changes touch exactly one file (`wasteland_theme.gd`), instead of grepping a half-dozen consumer files.

## Scope

In scope:

1. Delete three thin-wrapper functions on consumer files and inline their callers.
2. Promote `loot_reward.gd`'s two non-trivial wrappers (`_make_reward_row_style`, `_make_icon_frame_style`) into `WastelandTheme` as new builders, then delete the consumer-side copies.
3. Migrate `loot_reward.gd`'s five remaining alias references to the canonical palette names.
4. Delete all seven legacy aliases from `WastelandTheme`.
5. Mark the legacy-alias note in ADR-0010 as resolved.

Out of scope:

- Any palette color value change (this slice only renames; ADR-0010 governs colors).
- The `apply_button_theme()` signature cleanup (legacy `_bg`, `_border`, `_radius` placeholders) — separate slice if/when we touch it.
- Splitting `loot_reward.gd` / `map_scene.gd` for size — both files are now small enough that ADR-driven splits aren't justified.

## File-by-file changes

### `battle_scene/ui/battle_top_bar.gd`

- Delete `_make_panel_style()` (lines 304–305).
- Rewrite caller at line 128:
  ```gdscript
  panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
  ```
  (`const T = preload("res://run_system/ui/theme/wasteland_theme.gd")` already exists on line 3 of this file — use it.)

### `run_system/ui/map_scene.gd`

- Delete `_make_relic_panel_style()` (lines 410–411).
- Delete `_make_relic_button_style(state, _bg)` (lines 416–417).
- Rewrite callers at lines 281, 337–339 to inline `T.panel_textured("dark")` and `T.button_textured(state)` directly.

### `run_system/ui/theme/wasteland_theme.gd`

Add two new builders alongside the existing `panel_with_shadow` / `panel_flat`:

```gdscript
## Reward row style: panel_with_shadow wrapped with row-content padding.
## Used by loot_reward to render the list of loot rows.
static func reward_row_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style = panel_with_shadow(bg, border, 3)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style

## Square icon well frame with a slightly thicker border than a normal panel.
## Used by loot_reward's icon thumbnails.
static func icon_frame_style() -> StyleBoxFlat:
    return panel_with_shadow(Color(0.045, 0.04, 0.035, 1.0), Color(0.62, 0.44, 0.22, 1.0), 2, 3)
```

Then delete all seven legacy aliases (lines 45–54), including the surrounding header comment block, since the migration is complete.

### `run_system/ui/loot_reward.gd`

- Delete `_make_reward_row_style()` (lines 354–360).
- Delete `_make_icon_frame_style()` (lines 364–365).
- Update callers to use the new `WastelandTheme` builders:
  - Line 101: `_make_reward_row_style(T.ROW_BG, T.PANEL_BORDER)` → `T.reward_row_style(T.PANEL_BG, T.PANEL_BORDER)`
  - Line 102: `_make_reward_row_style(T.ROW_HOVER_BG, T.CYAN_EDGE)` → `T.reward_row_style(T.WARM_TAN, T.ACCENT_NEON_BLUE)`
  - Line 103: `_make_reward_row_style(T.ROW_PRESSED_BG, T.PANEL_HIGHLIGHT)` → `T.reward_row_style(T.RUST_PRIMARY, T.ACCENT_DANGER)`
  - Line 152: `_make_icon_frame_style()` → `T.icon_frame_style()`
  - Lines 183, 304: `T.CYAN_EDGE` → `T.ACCENT_NEON_BLUE`

### `docs/adr/0010-third-palette-recalibration.md`

Update the "legacy aliases" note (around line 75) to record that the aliases were removed in the 2026-05-20 Theme Finalization slice and reference this spec.

## Verification

1. **Static check.** `godot --headless --path . --quit-after 5` — must report zero parse errors.
2. **Grep guard.** Each of the seven removed alias names must have zero matches across the repo after the slice lands (excluding the ADR note).
3. **Manual visual check.** Open these screens in the editor; each must look pixel-identical to pre-slice:
   - Loot reward (after winning a battle): loot row normal / hover / pressed states; icon well; reward plate with cyan edge.
   - Map relic-choice modal (floor 0 boot, or any relic node): modal panel + three relic choice buttons in normal / hover / pressed.
   - Battle top bar settings overlay: dark panel background.

## Rollback

Each of the five changed files is independently revertable. If verification fails after landing, `git revert` the slice commit — none of the changes touch persisted state or asset files, so revert is safe.

## Open questions

None. All three affected files already use `const T = preload("res://run_system/ui/theme/wasteland_theme.gd")` as a top-of-file alias, so the rewritten call sites can use `T.<builder>` directly.
