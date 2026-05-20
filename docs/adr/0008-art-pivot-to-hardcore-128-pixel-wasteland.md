# ADR-0008: Art direction pivot - Cute Wasteland Cartoon -> Hardcore 128 Pixel Wasteland Art

## Status
Accepted - Supersedes ADR-0007

## Date
2026-05-19

## Context

ADR-0007 moved the project from the original pixel direction to a cute cartoon direction after the owner rejected the first generated pixel pass. That experiment clarified a production problem: the high-resolution cartoon direction did not actually fit the current game. The battle background, map art, and Godot rendering setup already lean pixel-art, and the generated "cartoon" assets became visually inconsistent or looked pixelated after import and scaling.

The owner then selected a new one-eyed Cowboy Bill concept as the visual reference and explicitly chose **Hardcore 128 Pixel Wasteland Art** as the new target. The key constraint is production discipline: the owner has no dedicated art pipeline, so assets need a constrained native resolution, predictable facing direction, strong pixel silhouettes, and repeatable prompt language.

## Decision

Pivot the entire art direction to **Hardcore 128 Pixel Wasteland Art**.

Concrete rules:

- **Reference image:** `docs/art/hardcore-128-pixel-wasteland-reference.png`
- **Native unit scale:** standard combat heroes and enemies use 128x128 pixel frames.
- **Boss scale:** bosses may use 192x192 frames when the spec calls for larger presence.
- **Rendering:** final Godot assets should read as pixel art; avoid high-resolution cartoon brushwork.
- **Outlines:** bold black pixel outlines, not thin realistic line art.
- **Shading:** controlled pixel clusters, not noisy dithering or painterly rendering.
- **Palette:** dusty wasteland earth tones with one small neon accent.
- **Facing:** Cowboy Bill and other heroes face right; enemies face left in source PNGs.

## Alternatives Considered

### Keep Cute Wasteland Cartoon
- **Pros:** The owner liked the broad silhouette idea in the first reference image.
- **Cons:** It requires stronger art direction and cleanup than this project currently has. Small generated frames still looked pixelated in game, while true high-resolution cartoon assets would clash with the existing pixel backgrounds.
- **Why rejected:** It increases art-production risk for a solo developer.

### Return to the original loose Wasteland Punk Pixel Art
- **Pros:** Matches existing background direction better than cartoon.
- **Cons:** The old rule was too broad, which caused inconsistent enemy/card output and muddy palette choices.
- **Why rejected:** It does not give enough concrete control to future asset generation.

### Hardcore 128 Pixel Wasteland Art - Chosen
- **Pros:** Keeps the wasteland tone, matches the current game presentation, gives Codex a strict native-resolution target, and is easier to batch-regenerate consistently.
- **Cons:** Existing cute-cartoon assets and old 64x64/96x96 sprite specs are now off-style and need regeneration.
- **Why chosen:** It is the best fit for a solo-dev asset pipeline and the current Godot project.

## Consequences

**Positive:**
- Art generation now has a concrete local reference image and a strict prompt anchor.
- 128-native units should reduce inconsistent scale and avoid tiny unreadable sprites.
- Pixel output better matches the map/battle backgrounds already in the project.

**Negative / Trade-offs:**
- Existing cute-cartoon Cowboy Bill, Trash Bot, cards, and tactical enemies are off-style.
- Runtime sprite sizing may need a pass so 128x128 units display consistently.
- Tactical Toolkit docs and future Codex prompts must stop referencing Cute Wasteland Cartoon.

## Revisit Triggers

- The owner approves a different concrete reference image.
- 128x128 proves too small for animation readability.
- Bosses need a separate art scale rule beyond 192x192.
- Steam capsule / store feedback indicates the style undercommunicates the game's tone.

## Related

- ADR-0007 (superseded)
- `docs/art-style-reference.md`
- `docs/project-rules.md`
- `docs/asset-spec-tactical-toolkit.md`
- `docs/codex-prompt-tactical-toolkit.md`
