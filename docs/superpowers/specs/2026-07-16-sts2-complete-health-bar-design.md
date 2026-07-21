# STS2-Inspired Complete Health Bar Redesign

Date: 2026-07-16

## Goal

Replace the battle health bar as a complete visual system rather than replacing only its outer frame. Preserve combat values, health animation timing, HUD placement, the approved cyan block shield, and Kreon combat numerals.

## Approved approach

Use two independently generated raster components:

1. `battle_hp_track_sts2_ui07.png`: a nearly black blue-teal empty trough with one restrained pale steel edge and pointed ends.
2. `battle_hp_fill_sts2_ui07.png`: a saturated but slightly dusty red inner fill with a narrow warm-red top highlight, dark lower edge, and clean end cap.

Both assets use transparent backgrounds after chroma-key postprocessing. They contain no text, symbols, brass, rivets, ornament, glow, or drop shadow.

## Runtime composition

- The generated track is the bottom layer and remains fully visible.
- The generated fill is used by `TextureProgressBar`, so current HP continues to control its width.
- The delayed damage layer uses the same generated fill texture with a lighter warm tint rather than a separately drawn procedural gradient.
- HP text stays centered above the layers and continues using Kreon Bold.
- The cyan block shield continues to overlap the left edge and is not regenerated in this pass.
- Existing player, normal-enemy, elite, and boss width tiers remain unchanged.

## Visual target

- Very thin horizontal silhouette comparable to the official STS2 battle HUD.
- Dark empty HP is readable against both light and dark battlefield regions.
- Red fill looks illustrated and tactile at 16–24 px runtime heights without becoming a heavy metal plaque.
- At partial HP, the fill terminates cleanly and does not expose a stretched decorative point inside the bar.

## Implementation boundaries

- Remove the code-generated live-HP and loss gradients from `character_hud.gd`.
- Keep health arithmetic, delayed-loss timing, healing behavior, status layout, and block visibility unchanged.
- Do not change the top bar, battle background, energy, end-turn button, character positions, or encounter balance.

## Verification

- Contract test must fail while the HUD still lacks the generated track/fill texture pair.
- Contract test must verify both texture resource paths and confirm live/loss layers share the generated fill source.
- Run the full non-visual Godot test suite.
- Capture a real 1920x1080 Windows/OpenGL battle with nonzero block and visually inspect full and partial HP presentation.
- Run `git diff --check`.
