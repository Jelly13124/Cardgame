# A0 balance audit — 2026-07-23

## Target

Act 1 A0 is tuned for a player who reaches the boss with:

- five ordinary/common equipment pieces (one guaranteed `+1` attribute affix per slot);
- two or three upgraded cards;
- a coherent, but not necessarily rare-heavy, deck plan;
- either of Cowboy Bill's starting clips.

The target is not a guaranteed win. Correct defense timing, Weak timing, and
archetype sequencing should matter. A starter-strength deck with no equipment is
allowed to lose to elites and the boss.

## Audit method

The audit uses production card and enemy JSON, the production upgrade formula,
three-card draws, three energy, block reset, Weak/Vulnerable/Frail, Burn, Stun,
Thorns, Short Circuit/Overload, Crit Clip, and Double-Fire Clip. Four representative
decks were tested against normal, heavy, elite, and boss enemies:

- upgraded starter;
- Gunslinger;
- Guard;
- Overload.

The common-equipment profiles were:

- average: `+1 STR / +1 CON / +1 INT / +1 Luck` (the fifth common Charm affix has
  no direct combat value in this model);
- focused: `+2 STR / +2 CON / +1 INT`.

The proxy is an audit aid rather than a replacement for Godot runtime tests. Every
data change is also covered by schema and combat contract tests.

## Findings

### Upgrade outliers

- `Hot Swap+` currently resolves to **0 Energy, draw 3** because its cost override
  and the generic draw upgrade stack. Multiple upgraded copies can form an
  unintended zero-cost draw loop.
- `Afterburner+` currently resolves to **gain 3 Energy, draw 2** because the generic
  formula upgrades both effects. That is too much free tempo for one upgrade.

Approved corrections:

- `Hot Swap+`: keep cost 1 and draw 3.
- `Afterburner+`: gain 2 Energy, draw 2, Exhaust.

### Enemy Vulnerable timing

Enemy-applied Vulnerable loses one duration stack at the end of each intervening
player turn. Five patterns used too few stacks even though their payoff attack happened
one or two enemy actions later, so the advertised combo expired before dealing
extra damage.

Approved duration corrections:

| Enemy | Setup | Payoff | Vulnerable duration |
|---|---:|---:|---:|
| Slag Walker | attack 9 | next attack 6 | 2 |
| Siege Mortar | attack 6 | telegraph, then attack 16 | 3 |
| Rust Titan | attack 10 | block, then attack 12 | 3 |
| Ash Warden | attack 8 | telegraph, then attack 18 | 3 |
| Ash Warden phase 2 | attack 9 | block, summon, then attack 10 | 4 |

Vulnerable remains a flat `+50%` damage-taken modifier while active. Extra stacks
extend duration; they do not multiply the penalty.

## Proposed A0 result

With the corrected enemy timing and the two bounded upgrades, 200 deterministic
seeds per build/loadout give the following Rust Titan win rates:

| Starting clip | Build | Common average | Common focused |
|---|---|---:|---:|
| Crit Clip | upgraded starter | 93.0% | 98.0% |
| Crit Clip | Gunslinger | 88.0% | 93.5% |
| Crit Clip | Guard | 96.5% | 99.5% |
| Crit Clip | Overload | 82.5% | 85.5% |
| Double-Fire Clip | upgraded starter | 100% | 100% |
| Double-Fire Clip | Gunslinger | 98.0% | 99.5% |
| Double-Fire Clip | Guard | 100% | 100% |
| Double-Fire Clip | Overload | 91.5% | 93.0% |

The lowest-performing valid line is Crit Clip Overload, which still clears in more
than four out of five modelled runs but finishes at a median 10–14 HP. This is the
desired “winnable with strategy, not free” floor. Normal encounters remain
forgiving once the player owns five common pieces, while Chrome Warden and Rust
Titan remain the meaningful checks.

## Follow-up gate

- Keep the four corrected Vulnerable durations under a data contract so later
  edits cannot silently make the combo inert again.
- Keep the two bespoke upgraded card states under the Cowboy Bill contract.
- Re-run the model and Godot contracts whenever card draw, starting clips, common
  affix counts, or Act 1 boss patterns change.
