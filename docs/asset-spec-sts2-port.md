# Asset Spec — StS2 Port (cards + relics)

> **For Codex (ADR-0005).** Claude shipped these as data with **placeholder art**
> (each new card's `front_image` points at an existing PNG; each new relic's `icon`
> reuses an existing relic PNG). Replace with real art at the listed target paths.
> Style: cyber / scrap / wasteland, matching the existing card + relic art.

## Cards — target `battle_scene/assets/images/cards/player/<id>.png`

Currently every new card points `front_image` at a type-placeholder
(`player/strike.png` for attacks, `player/defend.png` for skills,
`player/brace.png` for abilities). Deliver one PNG per id below (and update each
JSON's `front_image` to `player/<id>.png` when art lands). Sizes/format: match the
existing player card PNGs.

Bill (Ironclad bruiser — strength / blood / exhaust, cyber-industrial):
piston_jab, pipe_swing, haymaker, scrap_maul, overclock_swing, combat_stim,
power_surge, mark_target, incinerate, focusing_blow, siphon_valve, bulkhead_bleed,
hemo_drive, breach_charge, overdrive_core, limit_break, pain_damper, salvage_loop

Colourless (neutral utility): rebar_wave, recoil_shot, arc_flash, vent_plating,
phase_plating, brace_protocol, static_shout, data_dump, sweep_arc, tape_patch,
crowbar_smash

Feng Shui Master (yin defensive, jade/dark): kinetic_barrier, plating_loop, slam_dunk

(Each card also has a `_plus` JSON that reuses the base art — no separate `_plus`
PNG needed; the base art covers both.)

## Relics — target `run_system/assets/images/relics/<id>.png`

ballast_anchor (heavy anchor), kinetic_hammer (industrial hammer),
thorn_harness (barbed harness), brutal_servo (servo + blade), bulwark_plating
(riot shield plate), war_drum (war drum), vampiric_coupler (blood-red coupler).

When art lands, update each relic JSON `icon` to
`res://run_system/assets/images/relics/<id>.png`.

## Catalog

After art lands, no data change is required for rendering, but rerun
`python scripts/gen_catalog_html.py` if any numbers were also retuned.
