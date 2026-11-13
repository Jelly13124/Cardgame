# Combat HUD Implementation Plan

**Goal:** Implement the approved second-stage STS2 structural reference with original combat HUD art.

**Architecture:** Creature views bind existing combat models to independent health/status and intent layers. The outer battle UI owns the energy token, pile controls, end-turn action and tutorial; all shared skin resources resolve through WastelandTheme. No combat rules, card presentation or frozen feedback files change.

**Tech Stack:** Godot 4.6.3, GDScript, original PNG construction atlases.

**Spec:** Owner-approved stage 2 and `docs/reviews/sts2-ui-reference.md`.

## Constraints and review focus

- Keep all card art/layout/hand files and the five named combat feedback files byte-identical to `0cd9c2b`.
- Energy: five256² layers displayed128² at(100,828); layer2/3 rotate30/60° per second, or5/10 at zero; number36/outline16.
- Health: four250×16 layers; loss hold1s then1sExpo-Out, healing1s immediately; text24/16; block60², text24/14; status icons40² and stacks18/10.
- Intent: distinct64² severity images with strict thresholds5/10/20/40; total projected per-hit damage×hits; number22/12; float2s,10px amplitude,-8px baseline,.3rad per icon; show1s/hide.5s.
- Piles80², counters26/26/32 and outline12, hover.05s to1.25; endturn hit(1604,846,220,90), text30/12. Fixed input targets.
- Keep shared top bar/relics exactly once and content below132; tutorials must avoid top bar, energy and hand.
- Review interrupted HP changes, maxHP changes, intent refresh stability, more than one enemy/status, disabled/repeated input, and deletion during animation.

## Tasks

- [x] Inspect current UI, reference code coordinates and approved staged requirements; record red contract checks.
- [x] Generate original construction packs, extract33 PNGs at delivery dimensions and record prompts/provenance in TEMP.
- [ ] Implement health echo, shield and status presentation with timing/lifecycle tests.
- [ ] Implement distinct intent tiers/multiple-hit indication and independent float/fade with prediction tests.
- [ ] Implement outer HUD layers, geometry and interactions while preserving hand/card logic.
- [ ] Run focused checks, assign scene UIDs, full isolated tests, frozen-file checks and actual-game screenshots.
- [ ] Record asset specifications and TEMP review.html, commit on feat/ui-refresh and pause for stage review.
