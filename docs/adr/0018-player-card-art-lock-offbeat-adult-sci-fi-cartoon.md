# ADR-0018: Player card art lock - Offbeat Adult Sci-Fi Cartoon Wasteland

**Status:** Accepted  
**Date:** 2026-06-03  
**Supersedes:** none

## Context

ADR-0017 locked the overall production art style, but several player card illustrations still came from older experiments or placeholder-like UI concepts. That made the playable deck visually inconsistent with Cowboy Bill, the battle background, and the updated map/node direction.

The current card scene expects art-only `512x320` landscape PNGs. Card frame, cost, title, rarity, type, and description are separate UI layers.

## Decision

Regenerate and install all unique playable player card illustrations in the Offbeat Adult Sci-Fi Cartoon Wasteland style.

The official card illustration contract is:

- `512x320` landscape PNG.
- Art only; no card frame, cost badge, title, rarity text, type label, description box, speech bubble, logo, or UI.
- Match Cowboy Bill and the approved scene exemplars: flat adult sci-fi western cartoon, thick clean dark outlines, broad cel shading, sparse texture, dusty tan/brown base palette, and small toxic green/cyan/orange accents.
- `_plus` card variants reuse the base card illustration unless their gameplay identity changes enough to require distinct art.

## Consequences

- All current player card JSON `front_image` entries continue to point at PNGs under `battle_scene/assets/images/cards/player/`.
- Legacy JPEG card art is off-style and should not remain in the playable asset folder.
- Future cards must ship with a matching PNG illustration before being considered visually complete.
- Historical generated sheets can remain in `generated_sheet/` for traceability, but gameplay must reference only final PNGs.
