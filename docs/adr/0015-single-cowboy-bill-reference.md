# ADR-0015: Single art reference - Cowboy Bill character sheet

## Status
Accepted

## Date
2026-06-02

## Context

The project previously carried multiple active or semi-active art references: the radiation-rat style sheet, a Cowboy Bill action/card-scene image, and the newer Cowboy Bill / Robo-Cowboy character sheet. This created conflicting prompt anchors and inconsistent asset direction.

The owner clarified that the project should use only the Cowboy Bill / Robo-Cowboy character sheet as the art reference, and that all other active references should be removed.

## Decision

Use `docs/art/cowboy-bill-character-sheet-reference.png` as the only approved visual reference for all future art generation.

Remove the old active reference images and their import sidecars from `docs/art/`.

Update forward-facing hard-rule docs to the **Robo-Cowboy Sheet Style** direction. Older ADR bodies remain historical records, but ADR-0015 supersedes their active art-reference decisions.

## Consequences

- All future prompts must reference the Cowboy Bill character sheet only.
- Generated enemies, cards, UI icons, equipment, relics, VFX, and hero assets should share the sheet's thick ink, warm leather/brass, dented robot metal, red cloth, patched duster, and salvage-tech visual grammar.
- The reference sheet's embedded text, labels, speech bubble, logo-like signature, and sheet layout are not game-asset content and must not be copied.
- Existing off-style assets can be replaced incrementally; this ADR changes the art contract, not gameplay wiring.

## Related

- `docs/art-style-reference.md`
- `docs/project-rules.md`
- `docs/art/cowboy-bill-character-sheet-reference.png`
- Supersedes ADR-0013 and ADR-0014 for active art-reference selection.
