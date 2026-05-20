# ADR-0010: Third art-palette recalibration + theme naming generalized

## Status
Accepted

## Date
2026-05-19

## Context
The project's art direction has now pivoted three times in a single day:
1. "Wasteland Punk Pixel Art" (initial)
2. "Cute Wasteland Cartoon" (ADR-0007)
3. **"Hardcore 128 Pixel Wasteland Art"** (ADR-0008, current)

After each pivot, the shared theme file (`run_system/ui/theme/wasteland_*_theme.gd`) was renamed and recolored to match. The rename cost is non-trivial — at minimum the file path, `class_name`, and 3 consumer preload statements + documentation references must all be updated atomically.

We are starting **Slice 1A** of the UI overhaul. The goal is to give Codex a canonical color palette to anchor every new UI component against, so that the next batch of generated art doesn't drift visually from existing sprites.

Two decisions need to be made jointly:
- **What palette?** — the actual hex codes
- **What does the theme file get called?** — given the high pivot rate

## Decision

### Palette: script-sampled from actual sprite art (not designer-chosen)

Use a one-shot Python script (`tools/extract_palette.py`) to scan every game-art PNG and report color frequencies. Pick 8-12 base / accent / chrome colors from the top frequency buckets, plus 3 prescribed neon accents from `docs/project-rules.md` §1 that don't naturally surface in pixel counts (because per-character accents are small details).

Final palette in `wasteland_theme.gd`:
- **5 sampled earth tones:** `RUST_PRIMARY (#a05020)`, `LEATHER_DARK (#302010)`, `SAND_LIGHT (#e0d0a0)`, `WARM_TAN (#b08050)`, `DUSTY_TAUPE (#605040)`
- **3 prescribed accents:** `ACCENT_NEON_BLUE (#3bc7eb)`, `ACCENT_NEON_GREEN (#8ce04a)`, `ACCENT_DANGER (#e07020)`
- **6 UI chrome:** `PANEL_BG_DARK / PANEL_BG / PANEL_BORDER / TEXT_MAIN / TEXT_SECONDARY / SHADOW_COLOR`

Full breakdown + sample-frequency rationale: `tools/palette_report.md`.

### Theme file naming: drop the style suffix

Theme file renamed from `wasteland_cartoon_theme.gd` to **`wasteland_theme.gd`** (no style descriptor). Class is **`WastelandTheme`**.

Rationale: after three pivots in one day, the probability of another pivot is non-trivial. The theme file is colors + StyleBox builders — "wasteland" is the consistent core; "punk / cartoon / pixel" is the lipstick. Naming the file by lipstick guarantees renaming on every pivot.

## Alternatives Considered

### Alternative 1: Designer (or Codex) picks the palette by eye
- **Pros:** Can choose colors that aesthetically "should" work, not just what's there.
- **Cons:** Subjective; risks "theme says #c8a040 but the sprites are actually #b08050" drift. Hard to verify alignment.
- **Why rejected:** Sampling guarantees the theme IS what the art is. Drift becomes impossible by construction.

### Alternative 2: Keep palette dictated by Codex prompts (no theme palette)
- **Pros:** Zero file changes per pivot. Codex handles consistency in prose.
- **Cons:** UI code needs concrete RGB values to build StyleBoxFlat. Prose alone can't replace `Color("#a05020")` literals.
- **Why rejected:** UI code needs constants; theme file is non-optional.

### Alternative 3: Theme file keeps style-suffix name, accept rename cost
- **Pros:** File name is self-documenting — `wasteland_pixel_theme.gd` tells reader "this is for pixel-era art".
- **Cons:** Already paid rename cost twice today. Pattern is unsustainable.
- **Why rejected:** Renames are mechanical work with no design value. Future-proof name beats the documentation hint.

### Alternative 4: Generalize even further — `ui_theme.gd`
- **Pros:** Maximum future-proofing — even if the entire "wasteland" theme is dropped, the file stays.
- **Cons:** "Wasteland" IS the project identity (in PRD, in conversation, in the codex prompt). Generalizing away from it loses too much context.
- **Why rejected:** Goes too far. "wasteland" is stable.

## Consequences

**Positive:**
- Palette is grounded in reality; Codex generates new UI components knowing exactly which hex to anchor on.
- One-shot script can be re-run anytime new art lands (no manual eyedropper work).
- Theme file name won't need renaming on the next style pivot — just update palette constants.
- Existing consumer files (`battle_top_bar`, `loot_reward`, `map_scene`) update their preload path once and are done.

**Negative / Trade-offs:**
- The theme file's docstring + class_name are decoupled from the visual era. Future readers won't know from the filename whether colors are "punk", "cartoon", or "pixel" — they need to read the file or check the active ADR.
- Mitigation: keep ADRs as the history of record. Latest active art-direction ADR explains current palette.
- The legacy aliases at the bottom of `wasteland_theme.gd` (`PANEL_BG_BANNER = PANEL_BG` etc.) are short-term tech debt — they keep existing consumers compiling but mean the same UI looks duplicated under two names. Slice 1B+ should migrate consumers onto the new names and delete the aliases.

**Risks (and mitigations):**
- *Risk:* sampled colors are biased toward whichever sprite has the most pixels (e.g. the wasteland_battlefield.png background dominates many top ranks). *Mitigation:* picks were filtered to include underrepresented but project-essential accent colors per project-rules.md prescription.
- *Risk:* yet another pivot in week 2 forces another palette regeneration. *Mitigation:* the script makes this cheap; rerun, repick top buckets, swap constants. File name doesn't change.

## Revisit Triggers
- The script's sampling methodology produces a clearly wrong palette (e.g. all 14 colors are within 5% of each other)
- The legacy aliases become a maintenance burden rather than a migration aid
- A new asset category outside `battle_scene/assets/images/` and `run_system/assets/images/` needs sampling
- We add a non-Wasteland-themed game mode (mini-game?) that needs its own theme

## Related
- `tools/extract_palette.py` — the sampling script
- `tools/palette_report.md` — the sampling output + final picks
- `run_system/ui/theme/wasteland_theme.gd` — the renamed + recolored theme
- ADR-0007 (Cute Wasteland Cartoon pivot — now Superseded by 0008)
- ADR-0008 (Hardcore 128 Pixel Wasteland pivot — current)
- `docs/asset-spec-ui-overhaul.md` — Slice 1A's asset contract for Codex
