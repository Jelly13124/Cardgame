# ADR-0019: Original American-comic art and lightweight UI07

**Status:** Accepted
**Date:** 2026-07-13
**Supersedes:** ADR-0017's style name and prompt language

## Context

The runtime art had converged on clear flat 2D shapes and the UI07 lightline kit,
but forward-facing documentation still named a copyrighted animated series as the
canonical style. That wording also pulled later UI concepts toward the wrong kinds
of ornament: heavy frames, rendered metal, or imitation of a specific franchise.

The owner clarified the intended direction as original 2D American-comic art and
approved the existing lightweight top bars, character window, and UI07 component
language. The project still needs western sci-fi silhouettes and restrained comic
exaggeration, but it does not need a named-show imitation target.

## Decision

Lock **Original 2D American-Comic Sci-Fi Western** as the production style name.

- World art uses clean dark ink, broad readable silhouettes, sparse interior
  linework, two-to-three-value cel shading, and restrained cyan/orange/toxic accents.
- Persistent UI uses UI07: thin ink-and-brass borders, charcoal fills, simple
  icon silhouettes, clear hierarchy, and minimal material noise.
- Existing approved runtime exemplars remain valid visual references.
- Cowboy Bill's character sheet remains identity-only reference material.
- Generated prompts describe transferable visual traits and never request imitation
  of a named franchise.

ADR-0018's `512x320` art-only player-card contract remains in force.

## Consequences

- `docs/art-style-reference.md` and `docs/project-rules.md` are the current prompt
  sources; historical ADR bodies remain unchanged.
- Heavy rendered metal, dark-fantasy ornament, dense rivets/scratches, painterly
  wasteland rendering, and franchise-specific designs remain out of scope.
- Active asset specs use the original American-comic/UI07 wording so new generations
  do not regress to an obsolete style target.
