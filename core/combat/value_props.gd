extends RefCounted

## Bit flags carried by every damage / block value (STS2 `ValueProp`).
##
## POWERED is the STS2 "powered attack/move": card damage effects, card block and
## enemy moves. Only powered values take Strength, Constitution, Weak,
## Vulnerable, Frail and crits. Relic, set, tool, Thorns and Burn values are not
## powered and resolve at their printed number (Intangible still caps them).

const POWERED := 1
const UNBLOCKABLE := 2
## Base value already scales with Strength (or must not): skip the global +STR.
const NO_STRENGTH := 4
## Skip the global +CON on block (`no_con` on a card effect).
const NO_CONSTITUTION := 8
