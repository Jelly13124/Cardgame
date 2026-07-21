# Short Circuit Card Package

**Status:** approved direction, implementation in progress
**Catalog reviewed:** `docs/catalog_html/cards.html`, `relics.html`, `tools.html`, and `keywords.html`

## Core rule

- **Short Circuit** is stored charge on an enemy. It deals no automatic damage and does not decay.
- **Overload** removes all Short Circuit from the target and deals damage equal to the removed stacks.
- Overload damage is status damage: it is not increased by Strength and does not trigger Thorns.
- **Critical Discharge** lets player-caused Overloads use Bill's normal Luck-based Crit chance.
- Enemy-applied legacy Bleed becomes **Burn**, so the robot hero is no longer described as bleeding.

Delayed damage is intentionally budgeted above immediate damage. A common one-cost direct attack is worth roughly 5–6 immediate damage; a one-cost Short Circuit builder may carry 8–10 total delayed value because it requires both setup and a payoff card.

## Card migration

| Stable card id | New title | Cost / rarity | New role |
|---|---|---:|---|
| `recoil_shot` | Short-Circuit Round | 1 / common | Deal 2; apply 6 (+INT) Short Circuit. Upgrade: 3 and 8. |
| `arc_flash` | Arc Flash | 1 / common | Deal 2 to all; Overload all enemies. Upgrade damage to 4. |
| `acid_splash` | Whirling Sawblades | 1 / uncommon | Deal 2 fixed to all; apply 5 Short Circuit to all. Upgrade: 3 and 7. |
| `dissect` | Circuit Diagnosis | 1 / uncommon | Apply 8 + 2×INT Short Circuit. Upgrade: 10 + 3×INT. |
| `coagulate` | Charge Sink | 1 / uncommon | Remove all enemy Short Circuit; gain equal total Block. Upgrade cost to 0. |
| `bone_breaker` | Voltage Tear | 2 / rare | Apply 10 (+INT) Short Circuit; double the application if already affected. Upgrade base to 13. |
| `limit_break` | Overload | 1 / rare | Double target Short Circuit, then Overload it. Exhaust. Upgrade cost to 0. |
| `hemorrhage` | Critical Discharge | 2 / rare | This combat, player Overloads can Crit. Upgrade cost to 1. |

## Supporting content migration

- Bleed discovery becomes Short Circuit discovery.
- Bleed relic bonuses become larger Short Circuit bonuses to match the delayed-damage scale.
- The Warden five-piece bonus applies 2 Short Circuit instead of 1 Bleed.
- The old direct Bleed tool becomes a 10-stack Capacitor Spike.
- `Bulkhead Bleed` and `Hemo Drive` keep their stable ids for save compatibility but receive robot-native titles.

## Readability requirements

- Short Circuit uses cyan and a broken-circuit/lightning icon.
- Burn uses warm orange and remains a start-of-turn damage-over-time effect for enemies.
- Card descriptions must explicitly say whether Short Circuit is applied, Overloaded, doubled, or removed for Block.
