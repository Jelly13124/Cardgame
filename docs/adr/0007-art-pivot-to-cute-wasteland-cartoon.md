# ADR-0007: Art direction pivot — Wasteland Punk Pixel Art → Cute Wasteland Cartoon

## Status
Accepted

## Date
2026-05-19

## Context
Original art direction (set in PRD and `docs/project-rules.md` §1): **"Wasteland Punk Pixel Art"** — post-apocalyptic scrapyard, rusted-metal palette, bold pixel outlines, side-view full-body pixel sprites.

After implementing the Tactical Toolkit content slice (12 cards + 6 enemies + 1 boss), the human owner reported the executed art looked "ugly". Diagnostic conversation narrowed the complaint to two specific issues:

1. **Inconsistent across sprites** — different sprites looked like they came from different artists (varying line weight, detail level, shading approach).
2. **Palette feels muddy** — heavy reliance on `rust-orange + dusty-grey` earth tones produced a flat, low-contrast visual field with no anchor.

The owner explored these problems further with Codex and arrived at an approved replacement reference: a one-eyed robot cowboy (Cowboy Bill) + cute trash-bin robot (Trash Bot) in a **rounded, hand-drawn cartoon style with warm rust/leather colors and small neon accents** — drawn from an approved reference image (2026-05-19).

## Decision
Pivot the entire art direction to **"Cute Wasteland Cartoon"** with the Cowboy Bill + Trash Bot image as the canonical reference. Replace the pixel-art prompt anchor with the cartoon anchor.

Concrete changes:
- **Style name:** "Wasteland Punk Pixel Art" → "Cute Wasteland Cartoon"
- **Silhouettes:** sharp pixel silhouettes → rounded, toy-like, readable at 64px
- **Outlines:** bold pixel-weight black → clean bold hand-drawn dark outlines
- **Shading:** flat cel-shaded pixel → simple cel shading with light hand-painted wear
- **Palette:** earth tones + one neon accent (unchanged in concept but with a more deliberate "warm rust/leather" interpretation)
- **Character anchors:** Cowboy Bill (hero) and Trash Bot (canonical enemy) become the visual yardstick for all future assets
- **Prompt anchor:** rewritten in `docs/project-rules.md` §1 and `docs/art-style-reference.md`

All existing sprites are now "off-style". They continue to load and function — the change is cosmetic — but they are scheduled for regeneration by Codex under the new prompt anchor.

## Alternatives Considered

### Alternative 1: Keep pixel art, tighten discipline (16-color palette + strict rules)
- **Pros:** Smallest change. Most existing sprites stay valid. Cheap to enforce via stricter Codex prompt.
- **Cons:** Doesn't address the owner's actual complaint that the *style itself* felt off-target. Tightening discipline solves "inconsistent" but not "I don't like this aesthetic".
- **Why rejected:** Owner's feedback was diagnostic ("looks ugly"), not just about execution. Tightening rules would have produced more-consistent ugliness.

### Alternative 2: Switch to a different pixel style (e.g. 32px lo-fi like Loop Hero)
- **Pros:** Still pixel art, smaller production overhead per sprite, very iconic.
- **Cons:** Loses the gritty wasteland flavor the owner wants to keep. Lo-fi pixel art evokes very different genre conventions.
- **Why rejected:** The wasteland theme is core to the game; pivoting style should preserve theme.

### Alternative 3: Cute Wasteland Cartoon ← CHOSEN
- **Pros:** Preserves the wasteland theme. Cute/cartoon style is more forgiving of inconsistency (small variations read as "personality"). The Cowboy Bill + Trash Bot reference establishes a concrete visual target that Codex can match. Steam-friendly (broader appeal than punk-pixel).
- **Cons:** Invalidates 12 existing card arts + 6 existing enemy sheets — all need regeneration. The owner-approved reference image becomes the new yardstick, which means future variation needs to go through Codex+owner alignment.
- **Why chosen:** Owner-approved reference removes ambiguity. The "cute" framing is more commercial-friendly for Steam. The shift is large but happens early, before art volume scales.

## Consequences

**Positive:**
- New unified visual target — Cowboy Bill + Trash Bot pair as concrete anchor.
- Future Codex art generation has a clearer style to match (image reference > prose description).
- Style is more accessible / wider appeal for Steam audience.

**Negative / Trade-offs:**
- All 12 Tactical Toolkit card arts + 6 enemy sprite sheets are now off-style. Regeneration required.
- Catalog docs that referenced "Wasteland Punk Pixel" language need updates.
- `docs/project-rules.md` §1, `docs/asset-spec-tactical-toolkit.md` §0, and `docs/codex-prompt-tactical-toolkit.md` all already updated; future content slices need to use the new anchor.
- The "pixel" word should be removed from project terminology — the game is no longer pixel art.

**Risks (and mitigations):**
- *Risk:* Codex drifts from the Cowboy Bill + Trash Bot reference over many generations. *Mitigation:* `docs/art-style-reference.md` codifies the visual rules; future asset specs reference it; regular cross-checks against the canonical image.
- *Risk:* re-generating existing assets disrupts gameplay (missing sprites mid-fight). *Mitigation:* code already falls back to `ColorRect` placeholder if a sprite is missing; regeneration can happen incrementally without breaking the game.
- *Risk:* style drift between cards and enemies (cards painted differently from sprites). *Mitigation:* both must reference the same `docs/art-style-reference.md` prompt anchor.

## Revisit Triggers
- The Cowboy Bill / Trash Bot reference image is itself revised
- A second hero or boss introduces a visual constraint the cute cartoon style can't accommodate
- Steam page feedback indicates the style undersells the game's depth
- Codex output reliably diverges from the reference despite prompt anchoring

## Related
- Owner-approved reference image: 2026-05-19 Cowboy Bill + Trash Bot composition
- `docs/art-style-reference.md` (new canonical style spec)
- `docs/project-rules.md` §1 (updated 2026-05-19)
- `docs/asset-spec-tactical-toolkit.md` §0 (updated 2026-05-19)
- `docs/codex-prompt-tactical-toolkit.md` (updated 2026-05-19)
- ADR-0005 (Codex owns art generation — this pivot lands in Codex's domain)
