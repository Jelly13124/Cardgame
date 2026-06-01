# ADR-0012: Art direction pivot to Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland

## Status
Accepted; reference image superseded by ADR-0013

Historical style pivot record. For current generation, use `docs/art/rick-morty-radiation-rat-style-reference.png` and `docs/art/current-cowboy-bill-style-reference.png`; do not use the older standalone Cowboy Bill reference.

## Date
2026-05-31

## Context

The project owner reviewed multiple Cowboy Bill style explorations and selected the adult sci-fi cartoon version with thick outlines, flat bright colors, exaggerated proportions, and a strange comic wasteland mood. The previous Hardcore Wasteland Sprite Art direction is no longer the desired target for new art.

The owner described the chosen direction as "Rick and Morty" style. For production docs and prompts, the project will not request exact imitation of a named copyrighted show. Instead, the internal style name and prompt anchor describe the transferable visual traits: offbeat adult sci-fi cartoon energy, rubbery dark outlines, flat color blocks, simple cel shading, weird junk-tech silhouettes, and western wasteland details.

## Decision

Adopt **Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland** as the canonical art style for future generated assets.

Concrete changes:

- `docs/art-style-reference.md` is now the authoritative style spec for Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland.
- The first standalone Cowboy Bill reference from this pivot has been replaced by the ADR-0013 radiation-rat style standard plus the current Cowboy Bill card-scene reference.
- `docs/project-rules.md` section 1 now uses the new style name, visual rules, and prompt anchor.
- Future asset prompts must avoid exact named-IP imitation while preserving the selected cartoon traits.
- Existing assets can be replaced incrementally. Gameplay code and JSON should remain unchanged unless an asset path or frame contract changes.

## Consequences

Positive:

- The visual target is much clearer and more distinct.
- Assets should become easier to animate because shapes are simpler and cel shading is lighter.
- Cards, enemies, and UI icons can lean into stronger silhouette comedy and brighter reads.

Trade-offs:

- Existing high-detail rendered sprites, backgrounds, and card art are now off-style.
- A full migration is large, so replacement should happen by playable batches.
- Historical ADRs and generated prompt logs may still mention older style names; they remain historical records.

## Implementation Notes

Recommended migration order:

1. Cowboy Bill hero portrait and combat frames.
2. Starter/deck-visible card art: `strike`, `defend`, `weak_strike`, `junk_bomb`, `salvo`.
3. Early enemies: `trash_robot`, `scrap_rat`, `riot_hound`.
4. UI icons, equipment, relics, and later card/enemy waves.
5. Battle and shop/base backgrounds once character readability is settled.

## Related

- `docs/art-style-reference.md`
- `docs/project-rules.md`
- `docs/art/rick-morty-radiation-rat-style-reference.png`
- `docs/art/current-cowboy-bill-style-reference.png`
- Supersedes the forward-looking style guidance in ADR-0011.
