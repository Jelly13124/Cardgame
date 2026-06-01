# ADR-0013: Art reference standard - radiation rat

## Status
Accepted

## Date
2026-05-31

## Context

ADR-0012 moved the project to a Rick-and-Morty-like adult sci-fi cartoon wasteland direction. The first approved reference in that ADR was a Cowboy Bill exploration, but the owner later selected a mutated radiation rat preview as the better style standard.

The new reference better captures the desired production look: rubbery outlines, flat color blocks, simple cel shading, bulging expressive eyes, toxic-green radiation accents, gross-comic proportions, and a less rendered animation-screenshot feel.

## Decision

Use `docs/art/rick-morty-radiation-rat-style-reference.png` as the project-wide art style reference.

Cowboy Bill's current identity/card-scene reference is `docs/art/current-cowboy-bill-style-reference.png`. Older standalone Cowboy Bill renders are no longer reference material. When Cowboy Bill is regenerated, he should preserve his identity markers while matching the radiation-rat style standard.

## Consequences

- Future prompts should reference the radiation rat image for line weight, flatness, palette, eye treatment, and mutant-comedy silhouette language.
- Existing art may remain temporarily, but any new or regenerated art should match this standard.
- Asset dimensions remain technical output contracts only; they do not define the art style.

## Related

- `docs/art-style-reference.md`
- `docs/project-rules.md`
- `docs/art/rick-morty-radiation-rat-style-reference.png`
- `docs/art/current-cowboy-bill-style-reference.png`
- Supersedes the reference-image choice in ADR-0012.
