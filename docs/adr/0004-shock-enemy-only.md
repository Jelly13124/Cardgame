# ADR-0004: Shock status only applies to enemies

## Status
Accepted

## Date
2026-05-18

## Context
`shock` is a new status introduced with the Tactical Toolkit content slice. Mechanically: 1 stack of shock causes the affected entity to skip 1 action. It's the player's primary tool for interrupting telegraphed big attacks (mortar_cart's `attack_all 12`, Junkyard Tyrant's `Crushing Blow 22`).

The system already supports status effects on either side (poison, burn, weak, vulnerable, strength_up all work on both player and enemies). Shock could symmetrically work both ways.

## Decision
**`shock` only applies to enemies.** If applied to the player by any mechanism, it's silently ignored.

Other statuses (weak, vulnerable, poison, burn) continue to work on both sides.

## Alternatives Considered

### Alternative 1: Shock works on both sides symmetrically
- **Pros:** Consistent with other statuses; less mental model overhead. Opens design space (enemy that shocks the player, "skip your next card play").
- **Cons:** Player's turn is fundamentally different from enemy turn — the player has agency. "Skipping a player action" doesn't have a clean semantic. Skip the whole turn? Lose energy? Discard a card? Each choice is jarring and removes player control.
- **Why rejected:** The "skip an action" mechanic is only intuitive when the actor is automated (the enemy AI executes a queued action). The player doesn't have queued actions in the same sense.

### Alternative 2: Shock works on both sides with custom player semantics ← REJECTED
- E.g. player-shock = lose 1 energy that turn, or skip card draw next turn.
- **Cons:** Adds a hidden second meaning ("shock means action-skip on enemies, energy-loss on player"). Splits the player's mental model of what shock does. Forces a second balance pass.
- **Why rejected:** Complexity > benefit. Forfeits the clean cognitive frame "shock = control tool".

### Alternative 3: Shock only on enemies ← CHOSEN
- **Pros:** Clean mental model: "shock is the player's interrupt button". Aligns with the design intent (counter big telegraphed attacks). No special player semantics needed.
- **Cons:** Slight asymmetry with other statuses; needs to be documented so future content authors don't try `apply_status_self shock`.
- **Why chosen:** Clearer for the player; simpler to balance; design space we lose (enemies shock the player) is not interesting anyway.

## Consequences

**Positive:**
- Shock is a single-purpose mechanic the player understands in one sentence: "skip an enemy action".
- The interrupt mechanic for big telegraphed attacks (`interruptible: true` flag) reads naturally.
- No need for "shock the player" UI / animation.

**Negative / Trade-offs:**
- Documentation overhead: the asymmetry with other statuses must be called out (currently in `docs/catalog-enemies.md` "Status effects" table).
- Future authors writing `apply_status_self shock` will get silent no-op, not an error.

**Risks (and mitigations):**
- *Risk:* a card author writes `apply_status_self shock` thinking it does something. *Mitigation:* extend `DataValidator` to reject `shock` in `apply_status_self` (cheap one-line check).
- *Risk:* design later wants "enemy shocks the player". *Mitigation:* would need a NEW ADR superseding this one + a redesign of what player-shock means.

## Revisit Triggers
- A second player-side debuff with similar "skip-an-action" semantics is needed
- We add a "stun" or "freeze" status for the player and the gap becomes inconsistent
- A boss design needs the player to lose a turn entirely

## Related
- Most affected files: `battle_scene/status_effect_system.gd:consume_shock`, `battle_scene/enemy_ai.gd` (consumes shock at top of enemy turn)
- Used by cards: `stun_baton`, `static_coil`, `emp_burst`, `overload`
- Used to interrupt: `mortar_cart` attack_all, `junkyard_tyrant` Crushing Blows
