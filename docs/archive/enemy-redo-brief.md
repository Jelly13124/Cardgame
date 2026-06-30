# Enemy Art Redo Brief

Status: active redo brief, created 2026-06-04.

## Problem

The current enemy refactor drifted too far into detailed mech / armored robot language. It does not match the approved flat weird sci-fi cartoon wasteland look strongly enough.

## New Direction

- Enemies should read first as funny-gross aliens, mutants, odd creatures, or comedy goons.
- Mechanical elements are allowed only as sparse props: a small antenna, tube, cracked visor, junk shield, canister, or gadget.
- Avoid dense armor plates, rivet fields, chrome surfaces, realistic military shields, panel seams, and hard-surface mech rendering.
- Keep bodies simple and lumpy, with large uneven eyes, awkward mouths, rubbery silhouettes, and readable poses.
- Keep attack animation small: a tiny poke, spit, pulse, spark, bite, or recoil in place.

## Review Gate

Generate one sample first, then stop for review. Do not batch-generate or replace runtime assets until the sample direction is accepted.

## First Sample Target

Redo `armored_patrol` as an alien shield goon:

- Left-facing, full body.
- Lumpy green-tan alien, one large uneven eye, crooked mouth.
- Brown poncho scraps or simple wasteland cloth.
- Flat battered wooden or junk shield as the prop.
- 4-frame 1x4 attack sheet on solid `#FF00FF` for standard enemy attacks.
- Attack structure is strict: rest/wind-up, one hit, recoil, return/rest.
- The attack must hit exactly once; no repeated weapon swings, repeated hit poses, or multi-hit loops.
- Small shield poke only; no leap or big body movement.

## Assets Needing Re-evaluation

These assets may technically have older 8-frame attacks but should be reviewed or regenerated because they lean too mechanical or repeat hit poses:

- `armored_patrol`
- `acid_spitter`
- `chrome_hound`
- `mortar_cart`
- `slag_walker`
- `ash_warden`
- `ember_wisp`
- `scrap_shard`

These are still incomplete under the current enemy-animation goal:

- `rust_titan`
- `junkyard_tyrant`
