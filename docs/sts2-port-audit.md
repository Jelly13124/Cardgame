# StS2 Ironclad → CardFramework Port Audit (2026-06-08)

Source: Slay the Spire 2 EA Ironclad set (untapped.gg / stratgg) + established
Ironclad card knowledge. This is a **reconstruction**, not a copy: numbers are
retuned to our power curve and every survivor is re-skinned to the cyber / scrap /
yin-yang setting. Cards that depend on systems we don't model (potions, card
generation, ethereal, X-cost, intent-reading, name-counting) are SKIPPED.

## Engine vocabulary we map onto

Effects: `deal_damage`, `deal_damage_all`, `deal_damage_str_mult`,
`scale_damage_by_attacks`, `gain_block`, `gain_energy`, `draw_cards`,
`gain_strength/constitution/intelligence/luck/charm`, `apply_status[/_self/_all]`,
`apply_stun[_all]`, `exhaust_self`, `flip_polarity`.
Statuses: poison, burn, weak, vulnerable, strength_up, double_damage, stun, regen,
thorns, frail, dodge.
Auto-scaling: **STR auto-adds to all attack damage; CON auto-adds to all block.**

## New mechanics added this run (budget ≤6)

| # | Type | Kind | What | Unlocks |
|---|------|------|------|---------|
| M1 | `lose_hp` | effect | Player loses N HP (self-cost) | Bloodletting, Blood Wall, Hemokinesis, Breakthrough |
| M2 | `double_strength` | effect | Double current STR (attribute payoff) | Limit Break |
| M3 | `deal_damage_block_mult` | effect | Deal damage = current Block × mult (CON/block payoff) | Body Slam |
| M4 | `strength_per_turn` | status | Start of turn: gain N strength | Demon Form |
| M5 | `metallicize` | status | Start of turn: gain N block | Metallicize |
| M6 | `on_exhaust` trigger → statuses `feel_no_pain` (block on exhaust) + `dark_embrace` (draw on exhaust) | status+trigger | One exhaust-trigger hook, two statuses | Feel No Pain, Dark Embrace |

Each registers in the handler AND `data_validator.gd` ALLOWED_* (two-place rule).

## Attribute / pool legend

- Pool **B** = Cowboy Bill exclusive (strength / blood / exhaust bruiser, cyber-industrial reskin).
- Pool **F** = Feng Shui Master exclusive (given yin/yang polarity + matched_bonus, balance reskin).
- Pool **C** = colourless `INITIAL_CARD_POOL` (no attribute lean, draftable by all).

---

## CARDS — PORT-AS-IS (existing effects only)

| Our id | Reskin title | Orig | Cost | Type | Rarity | Pool | Effects |
|--------|-------------|------|------|------|--------|------|---------|
| `rebar_wave` | Rebar Wave | Iron Wave | 1 | attack | common | C | gain_block 5; deal_damage 5 |
| `piston_jab` | Piston Jab | Twin Strike | 1 | attack | common | B | deal_damage 5 ×2 |
| `recoil_shot` | Recoil Shot | Pommel Strike | 1 | attack | common | C | deal_damage 9; draw_cards 1 |
| `arc_flash` | Arc Flash | Thunderclap | 1 | attack | common | C | deal_damage_all 4; apply_status_all vulnerable 1 |
| `vent_plating` | Vent Plating | Shrug It Off | 1 | skill | common | C | gain_block 8; draw_cards 1 |
| `pipe_swing` | Pipe Swing | Clothesline | 2 | attack | common | B | deal_damage 12; apply_status weak 2 |
| `haymaker` | Haymaker | Uppercut | 2 | attack | uncommon | B | deal_damage 13; apply_status weak 1; apply_status vulnerable 1 |
| `scrap_maul` | Scrap Maul | Bludgeon | 3 | attack | rare | B | deal_damage 32 |
| `overclock_swing` | Overclock Swing | Heavy Blade | 2 | attack | uncommon | B | deal_damage_str_mult mult 3 (pure STR payoff) |
| `combat_stim` | Combat Stim | Inflame | 1 | ability | uncommon | B | gain_strength 2 |
| `kinetic_barrier` | Kinetic Barrier | Flame Barrier | 2 | skill | uncommon | F(yin) | gain_block 12; apply_status_self thorns 3 |
| `phase_plating` | Phase Plating | Ghostly Armor | 1 | skill | common | C | gain_block 10 |
| `brace_protocol` | Brace Protocol | Power Through | 1 | skill | common | C | gain_block 15 |
| `static_shout` | Static Shout | Intimidate | 0 | skill | uncommon | C | apply_status_all weak 1; exhaust_self |
| `power_surge` | Power Surge | Seeing Red | 1 | skill | uncommon | B | gain_energy 2; exhaust_self |
| `mark_target` | Mark Target | Setup Strike | 1 | attack | common | B | deal_damage 7; gain_strength 2 |
| `data_dump` | Data Dump | Battle Trance | 0 | skill | uncommon | C | draw_cards 3 |
| `sweep_arc` | Sweep Arc | Cleave | 1 | attack | common | C | deal_damage_all 8 |
| `incinerate` | Incinerate | Immolate | 2 | attack | rare | B | deal_damage_all 18; apply_status_all burn 2 |
| `tape_patch` | Tape Patch | True Grit | 1 | skill | common | C | gain_block 7; exhaust_self |
| `focusing_blow` | Focusing Blow | Searing Blow | 2 | attack | uncommon | B | deal_damage 16 |
| `crowbar_smash` | Crowbar Smash | Bash | 2 | attack | common | C | deal_damage 8; apply_status vulnerable 2 |

## CARDS — PORT-NEW-MECH

| Our id | Reskin title | Orig | Cost | Type | Rarity | Pool | Effects (mechanic) |
|--------|-------------|------|------|------|--------|------|--------------------|
| `siphon_valve` | Siphon Valve | Bloodletting | 0 | skill | uncommon | B | lose_hp 3 (M1); gain_energy 2 |
| `bulkhead_bleed` | Bulkhead Bleed | Blood Wall | 2 | skill | uncommon | B | lose_hp 2 (M1); gain_block 16 |
| `hemo_drive` | Hemo Drive | Hemokinesis | 1 | attack | uncommon | B | lose_hp 2 (M1); deal_damage 15 |
| `breach_charge` | Breach Charge | Breakthrough | 1 | attack | common | B | lose_hp 1 (M1); deal_damage_all 9 |
| `overdrive_core` | Overdrive Core | Demon Form | 3 | ability | rare | B | apply_status_self strength_per_turn 2 (M4) |
| `limit_break` | Limit Break | Limit Break | 1 | skill | rare | B | double_strength (M2); exhaust_self |
| `plating_loop` | Plating Loop | Metallicize | 1 | ability | uncommon | F(yin) | apply_status_self metallicize 3 (M5) |
| `slam_dunk` | Slam Dunk | Body Slam | 1 | attack | uncommon | F(yin) | deal_damage_block_mult mult 1 (M3) |
| `pain_damper` | Pain Damper | Feel No Pain | 1 | ability | uncommon | B | apply_status_self feel_no_pain 3 (M6) |
| `salvage_loop` | Salvage Loop | Dark Embrace | 2 | ability | rare | B | apply_status_self dark_embrace 1 (M6) |

## CARDS — SKIP (and why)

Anger (card-gen), Perfected Strike / Bully / Molten Fist / Dismantle (count/condition),
Sword Boomerang (random-N), Headbutt / Havoc / Warcry (deck manipulation),
Armaments (upgrade), Corruption / Sentinel / Whirlwind / Carnage (cost/ethereal/X),
Reaper / Feed (lifesteal/exec), Fiend Fire / Sever Soul / Second Wind (hand-exhaust),
Rampage (persistent scaling), Combust / Brutality / Berserk / Rupture / Evolve /
Fire Breathing / Juggernaut (end-turn/trigger over budget), Barricade (block-persist
over budget), Spot Weakness / Disarm (intent/enemy-STR), Clash / Dropkick (hand
condition), Cinder (draw-pile exhaust). Many duplicate cards we already ship.

---

## RELICS — PORT (re-skinned, mapped to ALLOWED_RELIC_EFFECT_TYPES)

Existing relic effect types: `add_damage`, `apply_self_status`, `block_gain_damage`,
`crit_chance`, `deal_damage_all`, `gain_block`, `gain_block_crit`, `gain_energy`,
`gain_gold`, `gain_strength`, `heal`, `reduce_damage`, `set_polarity_alternating`,
`set_strength`. (No new relic mechanics this run — stay in budget.)

| Our id | Reskin name | Orig | Rarity | Effect mapping |
|--------|------------|------|--------|----------------|
| `kinetic_hammer` | Kinetic Hammer | Vajra | common | gain_strength 1 (battle start) |
| `riot_plate` | Riot Plate | Bronze Scales | common | apply_self_status thorns 3 (battle start) |
| `ballast_anchor` | Ballast Anchor | Anchor | common | gain_block 10 (battle start) |
| `tracer_rounds` | Tracer Rounds | Bag of Marbles | common | apply enemy vulnerable at battle start (deal_damage_all 0 + status) → use apply_self? → see note |
| `combat_ration` | Combat Ration | Strawberry/Meal Ticket | common | heal (on pickup / battle start) |
| `whetstone_mod` | Whetstone Mod | Whetstone | common | add_damage 1 |
| `red_visor` | Red Visor | Red Mask / Red Skull | uncommon | gain_strength when low HP → set_strength/gain_strength |
| `kunai_module` | Kunai Module | Kunai | uncommon | gain_strength after 3 attacks/turn → simplify gain_strength 1 battle start |
| `letter_opener` | Servo Blade | Letter Opener | uncommon | deal_damage_all 5 every 3rd skill → deal_damage_all on trigger |
| `nitro_cell` | Nitro Cell | (energy relic) | rare | gain_energy 1 (turn start) |
| `bulwark_core` | Bulwark Core | Tungsten Rod / Self-Forming Clay | rare | reduce_damage 1 |
| `crit_capacitor` | Crit Capacitor | Pen Nib-ish | uncommon | crit_chance + |

Note: relics whose triggers don't exist verbatim are simplified to the nearest
supported trigger (battle-start / turn-start / on-block / on-crit). Anything
requiring a brand-new trigger is dropped to stay within the no-new-relic-mechanic
budget. Final relic set is trimmed to those that map cleanly during implementation.
