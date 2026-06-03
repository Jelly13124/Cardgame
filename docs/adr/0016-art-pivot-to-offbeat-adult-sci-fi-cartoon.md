# ADR-0016: Art pivot to Offbeat Adult Sci-Fi Cartoon Wasteland

**Status:** Accepted  
**Date:** 2026-06-02  
**Supersedes:** ADR-0015

## Context

The project previously used the Cowboy Bill character sheet as the single global art reference. That helped preserve Bill's identity, but it also pushed generated backgrounds back toward rendered concept-sheet detail and muddy western texture. The owner rejected the latest map and battle background because they still read as pixel-adjacent and too cluttered.

The current target is a flatter adult sci-fi cartoon direction: clean black outlines, large simple shapes, broad cel shading, weird alien desert props, sparse texture, and bright toxic/cyan/orange accents. The project should feel like original offbeat sci-fi TV-animation game art, not pixel art, not painterly concept art, and not a direct copy of any named show.

## Decision

Use **Offbeat Adult Sci-Fi Cartoon Wasteland** as the global art direction.

- `docs/art-style-reference.md` is the active style contract.
- Old project reference images are no longer global style references.
- `docs/art/cowboy-bill-character-sheet-reference.png` may be used only to preserve Cowboy Bill's identity markers.
- Map and battle backgrounds must be flat, clean, sparse, and readable, with low-detail center areas.
- Generated prompts must explicitly forbid pixel art, retro tiles, dithering, gritty texture, painterly rendering, dense tiny debris, and clutter.
- Do not copy named show characters, logos, exact scene layouts, franchise-specific props, or exact designs.

## Consequences

- Existing assets that look pixelated, painterly, or concept-sheet-rendered are off-style and should be regenerated when touched.
- Future background generations should prioritize broad shape composition over detail.
- Cowboy Bill's identity remains stable, but future Bill art should be flatter and cleaner than the previous concept-sheet render.
- Current UI theme naming remains `wasteland_theme.gd`; it is a legacy filename, not a style name.
