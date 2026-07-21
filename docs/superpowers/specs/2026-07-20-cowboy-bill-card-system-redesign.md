# Cowboy Bill Card-System Redesign

**Status:** implementation in progress
**Design surface reviewed:** `docs/catalog_html/cards.html` (54 cards)

## Catalog diagnosis

The current pool has 20 Attacks, 23 Skills, 6 Abilities, and 5 Curses. Its main
problem is not raw quantity; it is that several effects are duplicated while the
robot-cowboy fantasy is split across unrelated melee, poison, self-harm, reload,
critical-hit, and status packages. Twelve zero-cost cards and thirty-six one-cost
cards also flatten the energy curve.

The redesign keeps stable card IDs for save compatibility, but every playable
card must earn a clear role inside one of four Bill packages.

## Locked vocabulary

- **Short Circuit / 短路:** an enemy status that stores charge. It does not deal
  damage and does not decay on its own.
- **Overload / 过载:** a card action keyword. Remove all Short Circuit from the
  target and deal 1 damage per stack removed.
- Short Circuit is the setup; Overload is the payoff. They are not alternate
  names for the same thing.
- Overload damage ignores Strength and does not trigger attack-only reactions.
  It can Crit only while Critical Discharge is active.
- Enemy-applied damage over time remains **Burn**, never Bleed.

## Four card packages

| Package | Primary stats | Core verbs | Visual language |
|---|---|---|---|
| Gunslinger | Strength + Luck | Shoot, Crit, Replay, Reload | revolver close-ups, ricochets, chambers, brass rounds |
| Circuit Breaker | Intelligence | apply Short Circuit, multiply charge, Overload | exposed cables, cyan arcs, cracked robot cores |
| Scrap Guard | Constitution | Block, Thorns, convert charge to Block | energy shields, cover, patched plating, deflection |
| Redline Reactor | Energy + Exhaust | trade HP, draw, gain Energy, Exhaust | pressure gauges, hot coils, venting orange reactor light |

Neutral starter cards teach only direct damage, Block, and Weak. Reward cards
then introduce one package at a time. A card may bridge two packages, but it
must have one primary job and a short description.

## Circuit Breaker core package

| Stable ID | Card | Rarity / cost | Role |
|---|---|---|---|
| `recoil_shot` | Short-Circuit Round | common / 1 | small immediate hit + reliable single-target charge |
| `arc_flash` | Arc Flash | common / 1 | low AoE hit + Overload all enemies |
| `acid_splash` | Whirling Sawblades | uncommon / 1 | fixed AoE hit + Short Circuit all enemies |
| `dissect` | Circuit Diagnosis | uncommon / 1 | Intelligence-scaling pure charge builder |
| `coagulate` | Charge Sink | uncommon / 1 | alternate payoff: remove all charge for equal Block |
| `bone_breaker` | Voltage Tear | rare / 2 | high charge; doubles application on an already shorted target |
| `hemorrhage` | Critical Discharge | rare / 2 | lets Overload use Bill's Luck-based Crit chance |
| `limit_break` | Overload | rare / 1 | double one target's charge, then Overload; Exhaust |

The normal damage line remains intentionally below same-cost direct attacks:
charge builders defer damage and require an Overload outlet. In exchange, their
combined setup/payoff ceiling is higher and ignores attack-only mitigation.

## Gunslinger core package

**Loaded / 上膛** is Bill's prepared-shot resource. The next Attack that deals
damage gains damage equal to Loaded, then removes all stacks. Loaded persists
between turns, but only the first damage effect spends it, so Replay cannot reuse
the same chambered bonus. Reload still refreshes Double-Fire Clip's attack
allowance, preserving the relic's separate identity.

| Stable ID | Card | Rarity / cost | Role |
|---|---|---|---|
| `strike` | Shoot | common / 1 | readable 5-damage starter shot |
| `weak_strike` | Weakening Shot | common / 1 | 4 damage plus Weak; lower immediate output |
| `reload` | Reload | common / 0 | gain 2 Loaded, cycle a card, refresh clip ammo, Exhaust |
| `chain_link` | Quickdraw | uncommon / 1 | 4 damage plus draw; keeps the firing chain moving |
| `charged_shot` | Charged Shot | uncommon / 1 | 6 + 2× Strength finisher; Exhaust |
| `cascade` | Final Salvo | uncommon / 1 | retained 5-damage finisher that grows with Attacks played |
| `load_up` | Load Up | uncommon / 1 | create two Reloads for a burst turn |
| `lucky_streak` | Deadeye | uncommon / 1 | gain Luck plus one guaranteed next Crit |
| `covering_reload` | Covering Reload | uncommon / 1 | turn every Reload into Block |
| `hot_streak` | Hot Streak | uncommon / 1 | every Crit creates 2 Loaded |
| `all_in` | All In | rare / 1 | Crits deal 2×; non-Crits bank 2 Loaded |

## Scrap Guard core package

Scrap Guard uses Block as both survival and ammunition. **Reactive Plating**
turns every card-granted Block effect into Thorns; **Kinetic Rebound** grants
Block first and then attacks for the resulting total. Charge Sink remains the
bridge from Circuit Breaker into this package.

| Stable ID | Card | Rarity / cost | Role |
|---|---|---|---|
| `defend` | Defend | common / 1 | 5-Block starter energy shield |
| `brace` | Brace | common / 0 | small retained emergency Block |
| `siphon` | Scrap Counter | common / 1 | 3 damage plus 3 Block bridge |
| `tape_patch` | Quick Patch | common / 0 | temporary 4 Block; Exhaust |
| `deflector` | Deflector | uncommon / 1 | Block plus Weak on one target |
| `vent_plating` | Vent Plating | uncommon / 1 | 5 Block plus card flow |
| `spiked_guard` | Spiked Guard | uncommon / 1 | immediate Block plus Thorns |
| `venom_coat` | Reactive Plating | uncommon / 1 | card-granted Block creates Thorns |
| `rebar_wave` | Kinetic Rebound | rare / 2 | gain Block, then deal current Block as damage |
| `coagulate` | Charge Sink | uncommon / 1 | consume Short Circuit for equal Block |

## Redline Reactor core package

**Heat / 热量** is stored reactor pressure on Bill. It persists during combat and
does nothing by itself. Self-damaging reactor cards create more Heat than their HP
cost, while **Vent / 泄压** removes the entire Heat pool to power one payoff.
Redline Protocol also converts every Exhaust into 2 Heat, so exhaust cards remain
useful without forcing every Redline card to lose HP.

| Stable ID | Card | Rarity / cost | Role |
|---|---|---|---|
| `breach_charge` | Reactor Burst | common / 1 | lose 1 HP; build Heat; fixed AoE |
| `hot_swap` | Hot Swap | common / 1 | simple two-card cycle into reactor pieces |
| `hemo_drive` | Redline Drive | uncommon / 1 | efficient hit plus a large Heat deposit |
| `siphon_valve` | Fuel Siphon | uncommon / 0 | trade HP for Heat and Energy; Exhaust |
| `bulkhead_bleed` | Emergency Bulkhead | uncommon / 2 | trade HP for Heat and a large Block packet |
| `combat_stim` | Redline Protocol | uncommon / 1 | every Exhaust creates 2 Heat |
| `data_dump` | Memory Dump | uncommon / 0 | deep draw that Exhausts into the protocol |
| `focusing_blow` | Thermal Release | uncommon / 1 | Vent all Heat for single-target damage |
| `adrenaline` | Afterburner | rare / 0 | Energy plus draw; Exhaust |
| `last_breath` | Emergency Vent | rare / 0 | Vent all Heat for Block; draw; Exhaust |

Heat and Short Circuit deliberately mirror one another without sharing rules:
Heat belongs to Bill and is spent by Vent; Short Circuit belongs to enemies and
is detonated by Overload.

## Implementation order

1. Lock Short Circuit/Overload vocabulary across runtime, translations, tooltips,
   generated catalog, tests, relics, and tools.
2. Finish and verify the eight-card Circuit Breaker package.
3. Redesign Gunslinger around shooting/Crit/Reload without making Reload dead
   outside Double-Fire Clip.
4. Remove duplicate Block/Thorns cards while building Scrap Guard bridges.
5. Reframe self-damage cards as Redline Reactor actions; no blood vocabulary.
6. Generate card art package by package and validate it inside the actual card frame.
