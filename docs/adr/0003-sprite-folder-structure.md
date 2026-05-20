# ADR-0003: Sprite frames split into per-animation subfolders

## Status
Accepted

## Date
2026-05-19

## Context
Each combat unit (enemy, hero, boss) has multiple animations: `idle` (looping) and `attack` (one-shot), plus optional `charge` (boss telegraph). Each animation is currently 4 PNG frames + their `.import` sidecars.

Original layout: all frames sat loose at the entity root:
```
enemies/scrap_rat/
  scrap_rat_idle_0.png
  scrap_rat_idle_1.png  ...
  scrap_rat_attack_0.png  ...
```

With 8 enemies × 8+ frames + sidecars, each folder ballooned to 16-24 files and was visually unscannable.

## Decision
Each animation gets its **own subfolder** inside the entity folder. Filenames retain the full `{sprite_id}_{anim}_{N}.png` prefix:

```
enemies/{sprite_id}/
├── idle/         {sprite_id}_idle_0..3.png
├── attack/       {sprite_id}_attack_0..3.png
├── charge/       {sprite_id}_charge_0..3.png   (optional)
└── generated_sheet/   (pipeline intermediates, unchanged)
```

One-off images (portraits, single static fallback frames) stay at the entity root — only multi-frame **animations** get subfolders.

The path-construction in `enemy_entity._build_sprite_visual()` and `player._add_animation_frames()` was updated to insert the `{anim}/` segment.

## Alternatives Considered

### Alternative 1: Flat folder (status quo)
- **Pros:** Zero refactor cost. Path construction is the simplest possible.
- **Cons:** 16-24 files per entity = unscannable. Adding new animations (death, hurt, cast) makes it worse linearly.
- **Why rejected:** User explicitly flagged the visual mess.

### Alternative 2: Subfolder per animation, full filename (`idle/scrap_rat_idle_0.png`) ← CHOSEN
- **Pros:** Visually grouped. Filename alone identifies the sprite even when copied out of context. Aligns with how Godot's editor displays asset trees.
- **Cons:** Slight name redundancy (`scrap_rat/idle/scrap_rat_idle_0.png` repeats `scrap_rat` twice).
- **Why chosen:** Redundancy is cheap; ambiguity is expensive. Searching for `scrap_rat_idle_2.png` across the project still works.

### Alternative 3: Subfolder per animation, short filename (`idle/0.png`)
- **Pros:** No redundancy. Shorter paths.
- **Cons:** A loose `0.png` opened from outside the folder hierarchy is meaningless. File comparison tools, diff viewers, error messages all lose context.
- **Why rejected:** The "free naming context" of the full filename is worth more than the path length.

## Consequences

**Positive:**
- Entity folders now show 3-4 items (subfolders + portrait) instead of 16-24 loose files.
- Adding new animations (death, hurt, etc.) doesn't pollute the root — just add a new subfolder.
- Boss's `charge/` is now its own first-class animation registered in `SpriteFrames`, ready to be played during the telegraph action.

**Negative / Trade-offs:**
- Path-construction code is one segment longer.
- Catalog docs, asset spec, codex prompt all needed to be updated (one-time cost).
- Existing `.import` files had to be moved with the PNGs to avoid orphaned import metadata.

**Risks (and mitigations):**
- *Risk:* Codex generates assets in the old flat layout out of habit. *Mitigation:* asset spec doc + codex prompt explicitly call out the subfolder requirement.
- *Risk:* Future animations (e.g. `hurt`) ship loose at root by accident. *Mitigation:* a future `asset-audit` hook can enforce "no loose PNGs at entity root except portrait".

## Revisit Triggers
- We adopt an asset packing tool (SpriteFrames `.tres` or texture atlas) that prefers a flat input
- A single animation grows past 20+ frames and the subfolder itself becomes hard to scan

## Related
- Most affected files: `battle_scene/enemy_entity.gd:_build_sprite_visual`, `battle_scene/player.gd:_add_animation_frames`, `docs/project-rules.md` §4
- ~76 PNG + .import sidecars were physically relocated in the refactor commit
