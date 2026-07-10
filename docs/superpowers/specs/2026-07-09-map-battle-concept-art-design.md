# Map and Battle Concept Art Design

**Date:** 2026-07-09  
**Status:** Approved direction; awaiting written-spec review  
**Deliverables:** Two 16:9 full-screen concept mockups: one map, one battle

## Goal

Produce implementation-faithful concept images that improve the map and battle presentation without changing their current gameplay geometry. The concepts must look like the same game as the approved UI07/lightline kit, Cowboy Bill, the current wasteland backgrounds, and the approved simple-comic base UI.

These images communicate layout and art direction. Godot remains responsible for final text, exact sizing, interaction states, and runtime data.

## Shared Visual Language

- Original offbeat sci-fi cartoon wasteland with clean dark outlines, large readable shapes, sparse interior lines, and broad two-to-three-value cel shading.
- Warm desert tan and dusty orange environment; charcoal UI; restrained warm-brass hairlines; small cyan, orange, and toxic-green accents.
- One slim continuous charcoal top strip shared by both screens, approximately 64 px high on a 1920×1080 canvas.
- Integrated 56 px hero portrait at far left; HP and XP immediately beside it; frameless caps and tool readouts; quiet act/floor, deck, settings, and timer group at the right.
- No rivets, screw heads, bolts, thick metal framing, heavy bevels, oversized chrome, separate square plates around every readout, or stretched artwork.
- No franchise characters, logos, watermarks, speech bubbles, or decorative text.

## Map Concept

Preserve the current horizontal route-map logic and its broad three-band composition.

- Keep the existing wasteland route-map environment and its quiet pale center band; environmental detail stays away from route nodes.
- Show a horizontally progressing branching graph with straight dotted links only. Do not use curved paths, pipes, glow tubes, or multi-layer neon trails.
- Keep node badges compact and consistent with the existing 64 px runtime nodes.
- Distinguish route states through restrained value and color: current node at full strength with a small selection bracket, visited route warm gold, available route cyan, unreachable route dim brown/charcoal.
- Keep the current-position cyan marker at the left side of the route.
- Retain the narrow right-side legend beneath the top bar; use one light charcoal panel with a fine brass edge rather than a heavy framed cabinet.
- Preserve open negative space so the graph remains the dominant information layer.

## Battle Concept

Preserve the current battle coordinate logic and bottom-HUD interaction zones.

- Cowboy Bill stands on the left at roughly the current player position and faces right; one enemy stands on the right at roughly the current enemy position and faces left.
- Keep the center battlefield open for targeting, effects, and intent readability.
- Keep compact HP bars directly beneath combatants and a small intent icon/number above the enemy.
- Show a three-card hand centered at the bottom without changing the existing fan/spread logic.
- Draw and discard piles remain at the bottom-left and bottom-right edges. Each uses the approved cream `iconb_cards_fan` silhouette; its count is a small anchored badge attached to the icon, never a large floating numeral.
- Energy sits quietly above the draw pile as three small cyan energy dots/capsules plus a compact `3/3` label. Do not use the current large ornate energy ring.
- End Turn stays at the lower-right in a slim charcoal button with a warm-orange/brass accent, clear of the discard pile.
- The shared top bar is visually identical to the map top bar, apart from battle-specific settings/tools state.

## Reference Priority

1. Actual current map and battle runtime screenshots for geometry and interaction zones.
2. UI07/lightline component sheet and approved base-screen concept for UI language.
3. Current Cowboy Bill identity artwork and current map/battle backgrounds for world style.
4. The previous revised concepts only as evidence of rejected or unresolved presentation; they are not style authorities.

## Acceptance Criteria

- Exactly two landscape concept images are delivered and saved under `docs/art/previews/`.
- Both read as the same game and use the same shared top bar.
- Map paths are straight and dotted; map progression remains horizontal.
- Battle retains the player/enemy/hand/pile/end-turn spatial logic.
- Energy is compact; pile counts are attached badges.
- UI remains lightweight and avoids all prohibited heavy mechanical chrome.
- The images contain no watermark and no accidental franchise-specific content.

