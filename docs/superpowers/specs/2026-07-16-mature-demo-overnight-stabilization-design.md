# Mature Demo Overnight Stabilization Design

## Context and delegated decision

The owner requested an unattended overnight pass and explicitly delegated local
content/layout decisions. This document records the boundary of that delegation:
Codex may finish and rearrange existing UI surfaces, fix defects, and strengthen
tests, but will not replace the horizontal map, redesign the economy, add a new
chapter, or invent world-building while the owner is away.

## Approaches considered

1. **Add more content.** More enemies/events would increase raw volume, but it risks
   hiding UI and progression defects and requires balance decisions the owner did not
   delegate explicitly.
2. **Rebuild another major surface.** A new map/base layout could create a stronger
   screenshot, but contradicts the owner's repeated preference to preserve current
   layouts and would multiply art work.
3. **Stabilize and unify the existing demo (chosen).** Verify every acquisition path,
   remove visual state inconsistencies, fix reproducible defects, and add evidence-rich
   regression coverage. This has the highest player-visible return with the lowest
   design risk.

## Design

### UI consistency

- Generated UI art remains presentation-only; labels, prices, counts, and state are
  deterministic Godot controls.
- Hover never replaces a compact control with a full brown rectangle. It may brighten
  an existing asset by at most 10%, show an outline, or scale to 1.03–1.05.
- Wide art uses native ratio or NinePatchRect. No `STRETCH_SCALE` distortion for save
  strips, price plaques, bars, or buttons.
- Forge dismantle keeps a clear hierarchy: selected single-item action is orange;
  bulk rows are large dark-olive/rust actions; disabled rows retain shape but lose
  saturation. Empty space belongs to the workbench/NPC composition, not tiny buttons.

### Equipment integrity

- A base item with non-empty `set_id` is always materialized as rarity `set` with three
  positive affixes.
- Ordinary shop and forge pools exclude set bases before choosing rarity. They never
  display set art with an ordinary label and never mint a “common set”.
- Cursed creation remains explicit and cannot enter common/uncommon/rare bulk actions.
- Legacy save strings remain readable; migration compatibility is not removed.

### Runtime staging

- Four home buildings retain their current click rectangles and canvas dimensions.
- Forge, clinic, and outpost use their new 1920×1080 interiors. The market retains its
  already-approved merchant-and-counter background.
- Forge backdrop exists only while ForgeWindow exists; closing ForgeWindow removes the
  backdrop even if CharacterWindow remains.

### Verification

- Every behavior change follows RED → GREEN with an existing or new Godot contract.
- Real Windows/OpenGL captures validate map, battle, home, forge, clinic, market, and
  outpost composition; headless mode is used for logic, not screenshot claims.
- Final gates: import, all relevant contracts, smoke, `git diff --check`, and no user
  save writes.

## Self-review

- No placeholders or unresolved design choices remain.
- Scope is one stabilization project; no independent content-expansion subsystem is
  bundled into it.
- The chosen rules are consistent with ADR-0019 and the current UI07 implementation.
- The owner delegated review/approval for this unattended pass, so implementation may
  proceed without a wake-up question.
