# ADR-0017: Formal art style lock - Offbeat Adult Sci-Fi Cartoon Wasteland

**Status:** Accepted  
**Date:** 2026-06-02  
**Supersedes:** ADR-0016

## Context

ADR-0016 moved the project away from the old Cowboy Bill character-sheet reference and toward a flatter adult sci-fi cartoon direction. After that pivot, the project generated and installed a new Cowboy Bill runtime look plus matching non-pixel map and battle backgrounds.

The owner approved the new look explicitly after seeing Cowboy Bill in the updated scene context. That approval turns the experimental pivot into the production art direction.

## Decision

Lock **Offbeat Adult Sci-Fi Cartoon Wasteland** as the official production art style.

The approved in-game exemplars are:

- `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`
- `battle_scene/assets/images/heroes/cowboy_bill/idle/`
- `battle_scene/assets/images/heroes/cowboy_bill/attack/`
- `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`
- `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`

Future generated art should match these exemplars first, then the written rules in `docs/art-style-reference.md`.

Old reference images are no longer global style anchors. `docs/art/cowboy-bill-character-sheet-reference.png` remains identity documentation for Cowboy Bill only.

## Consequences

- Existing art that reads as pixel art, painterly concept art, gritty wasteland rendering, American comic trial art, or old Robo-Cowboy concept-sheet art is off-style.
- New cards, relics, enemies, UI icons, maps, backgrounds, and hero art must match the approved exemplars.
- Future prompts must explicitly forbid pixel art, retro tiles, dithering, painterly rendering, gritty texture, dense scratches, dense debris, and exact copies of named show characters or franchise-specific designs.
- Historical ADR bodies remain historical records; forward-facing docs and generation rules use this ADR and `docs/art-style-reference.md`.
