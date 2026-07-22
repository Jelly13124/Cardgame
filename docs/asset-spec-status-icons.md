# Status Icon Runtime Contract

**Last audited:** 2026-07-22

The status badge system is already wired. `battle_scene/status_effect_system.gd`
loads `battle_scene/assets/images/ui/status/<status_id>.png` and falls back to a
short glyph when a PNG is absent. Stack counts are rendered by code; never bake
numbers or text into an icon.

## Asset contract

- PNG with transparent background; source may be 64×64 and is displayed at 30×30.
- One bold silhouette, one main color, dark outline, clear lower-right area.
- Follow the UI07 icon rules in `docs/project-rules.md`: flat fill, sparse lines,
  no character faces, texture, rivet fields, or ornamental frames.
- `DataValidator.ALLOWED_STATUS_NAMES` is authoritative for status ids.

## Current coverage

Runtime PNGs exist for:

`short_circuit`, `burn`, `weak`, `vulnerable`, `stun`, `regen`, `thorns`,
`frail`, `dodge`, `metallicize`, `feel_no_pain`, `hot_streak`, `all_in`,
`covering_reload`, and `bullet`.

The following active statuses intentionally use the glyph fallback until new
icons are generated and visually approved:

`deadeye`, `overload_protocol`, `reactive_plating`, and `loaded`.

Removed statuses such as Bleed, Double Damage, Dark Embrace, and the old
Hemorrhage status must not regain runtime icons. The card file id
`hemorrhage.json` is a save-compatible legacy id whose displayed card is
**Critical Discharge**; it is not a status id.
