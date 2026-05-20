# ADR-0009: Remove Separate Idle Animation Assets

**Status:** Accepted  
**Date:** 2026-05-19  
**Supersedes:** ADR-0003 for idle-animation requirements only

## Context

The project previously required every combat unit to ship `idle/` and `attack/` frame sets. This doubled character/enemy frame output, created more generated intermediates, and made art direction harder to keep consistent. The current combat read is better served by a strong static rest pose plus one attack animation.

## Decision

Combat heroes and enemies no longer have separate `idle/` animation assets. Runtime loaders use `attack/{sprite_id}_attack_0.png` as the static rest pose, and play the remaining `attack/` frames for attacks. Bosses may still define optional `charge/` frames for telegraphed actions.

## Consequences

- Asset folders are smaller and easier to audit.
- New unit generation asks for 4 attack frames, not 4 idle plus 4 attack frames.
- `idle/` directories and idle-containing hero/enemy generation intermediates should not be committed.
- Existing code may keep compatibility function names such as `play_idle()`, but those functions must show the static rest pose instead of loading idle frames.
