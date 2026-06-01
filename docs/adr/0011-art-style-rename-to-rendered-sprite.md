# ADR-0011: Rename art style to "Hardcore Wasteland Sprite Art" and correct the pixel-art wording

## Status
Accepted (supersedes the style **naming and description** in ADR-0008 and ADR-0010; their decisions otherwise stand)

Historical only for current art generation. ADR-0013 and `docs/art-style-reference.md` now define the active Rick-and-Morty-like wasteland cartoon style, and older Cowboy Bill runtime frames are not reference material.

## Date
2026-05-28

## Context
The canonical style was named **"Hardcore 128 Pixel Wasteland Art"** (ADR-0008), and the written prompt anchor in `project-rules.md` §1 and `art-style-reference.md` demanded *"bold black pixel outlines, controlled pixel shading, no high-resolution cartoon brushwork,"* and listed *"painterly / high-resolution cartoon / anything that does not read as pixel art"* under **Avoid**.

But the actual shipped flagship art contradicts that wording. `heroes/cowboy_bill/` (the canonical character), `enemies/junkyard_tyrant/`, and `cards/player/strike.png` are **detailed, fully-rendered illustrated sprites** — rich highlight/mid/shadow shading, bold dark outlines, warm rust/leather/brass materials, one glowing neon accent. That is essentially the painterly/high-detail look the docs told generators to **avoid**.

The mismatch had a concrete cost: AI art generation (Codex) followed the *words* and produced off-style lo-fi/crude output that didn't match the game. The phrase "128 Pixel" in the name is the root of the confusion — readers take it to mean a lo-fi pixel-art aesthetic, when it only ever meant the native authoring/display resolution.

## Decision
1. **Rename** the canonical style to **"Hardcore Wasteland Sprite Art."** "128" survives only as a *resolution* fact: assets are authored at 128×128 native (192×192 bosses) for in-game readability — it is **not** a pixel-art aesthetic.
2. **Correct the written description** to match reality: detailed, fully-rendered sprites; bold dark outlines; rich controlled shading with a clear highlight/mid/shadow read. Remove the contradicting rules ("controlled pixel shading", "no high-resolution cartoon brushwork", "must read as pixel art").
3. **Cowboy Bill (`battle_scene/assets/images/heroes/cowboy_bill/`) is the ground-truth fidelity reference.** When wording conflicts with how Bill actually looks, Bill's sprite wins.
4. **Scope (the "sane global"):** apply the rename + corrected wording to the forward-facing authoritative, index, and active-contract docs, plus this ADR. Leave frozen `generated_sheet/**` prompt logs, `.import` sidecars, and historical ADR bodies unchanged — they are point-in-time records, are Codex/Godot-owned (ADR-0005, project-rules §4), and several are blocked by the PreToolUse guard. This ADR makes the rename discoverable. The reference image keeps its filename (`docs/art/hardcore-128-pixel-wasteland-reference.png`) to avoid editing its auto-generated `.import`.

## Alternatives Considered

### Alternative 1: Keep the name, only patch each handoff with "Bill wins"
- **Pros:** smallest change; one note per art contract.
- **Cons:** leaves the misleading name and the self-contradicting rules in the canonical docs, so every new content wave hits the same trap.
- **Why rejected:** treats the symptom, not the root cause.

### Alternative 2: Literally rename across all 85 files (incl. frozen records)
- **Pros:** perfectly uniform string.
- **Cons:** rewrites historical `prompt-used.txt` / `pipeline-meta.json` (falsifying what was actually used), edits auto-generated `.import` files, and fights the addons-guard hook.
- **Why rejected:** corrupts historical records for cosmetic uniformity.

### Alternative 3: Do nothing
- **Pros:** zero work.
- **Cons:** AI generations keep drifting off-style; the docs stay wrong.
- **Why rejected:** the contradiction is an active, recurring cost.

## Consequences

**Positive:**
- The canonical docs match the actual art, so prompts/generators get correct guidance.
- "Sprite Art" + the Bill ground-truth rule stop the lo-fi drift.

**Negative / Trade-offs:**
- Temporary name inconsistency: frozen historical records and old handoff docs still say "128 Pixel Wasteland." Mitigated by this ADR + supersede pointers on ADR-0008/0010.

**Risks (and mitigations):**
- *Risk:* someone reads an old handoff doc and uses the stale name/anchor. *Mitigation:* the canonical docs and active contracts are updated; old docs are historical and dated.

## Revisit Triggers
- The art direction genuinely pivots again (write a new ADR, as 0007→0008 did).
- A true lo-fi pixel-art style is ever intentionally adopted.

## Related
- Files most affected: `docs/art-style-reference.md`, `docs/project-rules.md` §1, `docs/asset-spec-content-expansion.md`, `docs/codex-prompt-content-expansion.md`.
- Ground truth: `battle_scene/assets/images/heroes/cowboy_bill/`.
- Related ADRs: ADR-0008 (original pixel-wasteland pivot), ADR-0010 (palette recalibration), ADR-0005 (Claude/Codex ownership split).
