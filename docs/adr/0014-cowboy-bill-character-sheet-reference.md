# ADR-0014: Cowboy Bill character sheet is the primary Bill reference

## Status
Accepted

## Date
2026-06-01

## Context

The project owner provided a full Cowboy Bill / Robo-Cowboy character sheet with turnaround poses, eye states, hand and arm parts, hat and cape variants, weapons, gadgets, and VFX. Earlier docs used a single action scene (`current-cowboy-bill-style-reference.png`) as the Bill reference, which was useful for card staging but too limited for consistent future hero, card, and UI generation.

The owner also clarified that the desired visual direction should stay in the Rick-and-Morty-style flat adult sci-fi animation family, not drift into gritty hard-surface wasteland concept art.

## Decision

Use `docs/art/cowboy-bill-character-sheet-reference.png` as Cowboy Bill's primary identity reference.

Use `docs/art/current-cowboy-bill-style-reference.png` only as an action/card-scene staging reference.

The sheet includes external style-label text. That text, logo treatment, named characters, and proprietary story elements must not be copied into project assets or prompts. The usable reference is Bill's original design language: single orange camera eye, cylindrical robot head, cowboy hat with star badge, red scarf, patched duster, chunky boots, salvaged weapons, shield bubble, acid splash, and related gadget/VFX shapes.

## Consequences

- Future Cowboy Bill art should be more consistent across combat frames, cards, icons, and UI.
- Card art can use Bill's weapons/VFX without always showing his full body.
- Old standalone Bill renders are no longer identity references.
- Existing runtime sprites can be replaced incrementally; this ADR only changes the art contract.

## Related

- `docs/art-style-reference.md`
- `docs/project-rules.md`
- `docs/art/cowboy-bill-character-sheet-reference.png`
- `docs/art/current-cowboy-bill-style-reference.png`
- ADR-0013
