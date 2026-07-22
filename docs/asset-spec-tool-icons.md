# Asset Spec — Tool Icons

> Runtime contract for the one-use battle tools shown in the backpack, market,
> battle top bar, merchant, and use-confirmation dialog.

**Status:** Rebuilt 2026-07-14. The complete 11-icon set is delivered at
`run_system/assets/images/ui/tools/<id>.png`, and every tool JSON points to a
unique semantic icon.

## Production contract

- Canvas: 256×256 RGBA PNG with transparent corners.
- Composition: one centered physical prop, strong silhouette, even safe margin,
  and no UI frame, caption, floor shadow, or character hand.
- Style: original flat 2D American-comic sci-fi western. Use thick clean
  dark-brown outlines, large shapes, sparse interior lines, and broad 2–3 value
  cel shading. Materials lean dusty tan, warm brown, muted red, and grey-green,
  with at most one cyan/orange/toxic accent.
- Avoid: pixel-art edges, realistic metal rendering, painterly grime, dense
  scratches/rivets, dark-fantasy ornament, and glossy 3D lighting.
- Filtering: tool presentation surfaces use linear filtering. The silhouette
  must remain legible at the 40px top-bar size.
- Rarity: tools do not have a rarity field. Do not bake rarity frames or rarity
  glows into their icons.

## Delivered set

| id | visual identity | runtime effect |
|---|---|---|
| `adrenaline_shot` | chunky brass auto-injector, amber chamber | draw 2 cards |
| `blood_kit` | legacy file id; player-facing Circuit Kit | discover 1 of 3 Short Circuit cards; free |
| `combat_stim` | squat brass stim cylinder, orange up-arrow | gain 2 Strength |
| `energy_cell` | salvaged battery canister, cyan bolt window | gain 2 Energy this turn |
| `field_kit` | sand canvas tool roll, wrench and wire spool | discover 1 of 3 Skill cards; free |
| `frag_grenade` | olive fragmentation grenade, lever and pull ring | deal 10 damage to one enemy |
| `med_kit` | off-white hard medical case, red cross | gain 3 Regeneration |
| `munitions_crate` | dented ammunition box with visible cartridges | discover 1 of 3 Attack cards; free |
| `shock_charge` | flat EMP puck with two cyan electrodes | apply 2 Vulnerable and 1 Weak |
| `smoke_bomb` | crooked vented canister and one simple smoke puff | gain 10 Block |
| `toxin_vial` | legacy file id; player-facing Capacitor Spike | apply 10 Short Circuit to one enemy |

Display names and descriptions live in `assets/translations/content_cards.csv`
under `TOOL_<ID>_TITLE` and `TOOL_<ID>_DESC`. Keep the historical
`blood_kit` and `toxin_vial` ids for save compatibility even though their current
player-facing identities are Circuit Kit and Capacitor Spike. Their existing
icons predate those renames and need a future visual audit before final release.
