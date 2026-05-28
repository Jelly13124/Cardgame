# Design — Wave-3 Art Handoff to Codex

**Date:** 2026-05-28
**Status:** Approved (brainstorming)
**Goal:** Close the one remaining Phase-5 item — "10+ enemy types with **final sprite art**" — by handing wave-3 art generation to Codex, tool-agnostically, and planning the Claude-side completion.

## Context

Wave-3 gameplay content is shipped and committed: 30 cards, 13 enemies (incl. 3 bosses), 21 equipment, 10 relics. The PRD lists Phase-5 content as essentially done **except final sprite art**.

The art contract already exists: `docs/asset-spec-content-expansion.md` + `docs/codex-prompt-content-expansion.md` (2026-05-26) itemize all 27 wave-3 assets needing art — 13 cards, 5 enemies, 5 Warden equipment, 4 relics — with exact paths, frame sizes, themes, and neon accents. Those tables are still accurate against current JSON.

Two facts reshape the handoff:
1. **PixelLab is no longer used.** The asset-spec / codex-prompt still reference PixelLab, `$env:PIXELLAB_API_KEY`, and an "image-generation pipeline" — now stale.
2. **Procedural placeholder art already exists on disk** (untracked), produced by `scripts/gen_wave3_content_assets.py` — a pure-Python (PIL) generator that hand-draws every wave-3 asset with geometric primitives at the exact target paths (+ magenta `-raw.png` intermediates and `pipeline-meta.json` in `generated_sheet/`). It is crude (e.g. a brown-hexagon Rust Titan), not hardcore-128 pixel art, and is NOT wired in for enemies (see wiring gap below).

**Codex's image mechanism is unconfirmed.** Codex is a code agent; it produces images either by (a) writing/running procedural draw code (the PIL route, quality-capped) or (b) calling an image-generation API/model (PixelLab was that route, now dropped). Whether "Codex generates the art itself" holds depends on whether the user's Codex session has an image-generation capability wired in. The design is therefore **tool-agnostic**: the contract fixes paths/sizes/style; the generation method is Codex's to satisfy, and which route is in play becomes visible the moment the prompt is pasted into Codex.

## Wiring gap (the only code-side blocker)

- **Cards / equipment / relics:** `front_image` / `sprite` / `icon` already point at the final paths, and placeholder PNGs exist there. When Codex writes real art to the same path, it auto-upgrades. **No wiring change needed.**
- **Enemies:** the 5 new enemy JSONs set `sprite_id` to a *reuse* placeholder (`rust_titan`→`rust_brute`, `ash_warden`→`armored_patrol`, `slag_walker`→`rust_brute`, `acid_spitter`→`mortar_cart`, `chrome_hound`→`riot_hound`). So neither the procedural art nor future Codex art at `enemies/<id>/attack/` renders until `sprite_id` is flipped to each enemy's own folder. **This flip is the Claude-side completion step.**

## Design

### 1. Contract refresh (Claude, now)
Make the existing contract tool-agnostic:
- Remove PixelLab / `$env:PIXELLAB_API_KEY` / "image-generation pipeline" references from `asset-spec-content-expansion.md` and `codex-prompt-content-expansion.md`.
- Reframe generation as method-neutral: "produce these PNGs at these paths/sizes in the hardcore-128 style using whatever generation your session supports; if no image model is available, the fallback is improving the procedural generator." Keep the magenta-chroma / transparent-final and facing/frame rules (still valid regardless of tool).
- Keep the 27-item tables (id / path / frame size / theme / neon accent) — the real, still-accurate contract.
- Add notes: (a) procedural placeholders already exist at the target paths, so Codex **overwrites** rather than creates; (b) Claude will flip the 5 enemy `sprite_id`s post-delivery.

### 2. Handoff package (Claude → user)
The refreshed `codex-prompt-content-expansion.md` is the paste-in briefing. The user runs it in their Codex session. Delivery order stays cards → enemies → equipment → relics, small batches, one commit/push per category for batch review. Pasting it also immediately reveals whether Codex image-generates (real raster art) or falls back to procedural code.

### 3. Completion / acceptance (Claude, per delivered batch)
For each batch Codex pushes:
1. Visually verify each PNG — correct path, dimensions, transparent background (no magenta leftover), single neon accent, silhouette reads at in-game scale.
2. **Enemy batch only:** flip the 5 enemy `sprite_id`s to their own folders so the delivered art renders. (Codex overwrites the procedural final PNGs in place; the `generated_sheet/` intermediates may stay as pipeline traceability.)
3. Run `bash scripts/smoke_test.sh` (must end `[OK] DataValidator: all schemas passed.`).
4. Run `/regen-catalogs` to refresh the catalogs' art-presence status; commit.

### 4. Interim behavior
Do **not** flip enemy `sprite_id`s before Codex delivers — keep the polished reuse placeholders so players never see the crude procedural shapes. The flip + verification is one clean post-delivery step.

## Decisions

- **`gen_wave3_content_assets.py` + its procedural output:** keep, untracked, as the documented procedural **fallback** (Plan B if Codex has no image generation). Do not delete; do not commit it as part of this work.
- **ADR-0005 boundary wrinkle:** if the realized art route is "write better procedural draw code," then art generation is *code*, which blurs the "Codex owns art / Claude owns code" split. If that route is chosen, write a short follow-up ADR clarifying ownership of procedural art-gen code. (Not needed if Codex uses an image model.)

## Out of scope (YAGNI)

Other Phase-5 gameplay — multiple hero archetypes with unique decks, multi-phase boss patterns, final-boss unique mechanics. Each is separate future work.

## Acceptance criteria

- `asset-spec-content-expansion.md` / `codex-prompt-content-expansion.md` carry no PixelLab references and read tool-agnostically, with the 27-item tables intact.
- A paste-ready Codex briefing exists.
- A written Claude-side completion checklist exists: per-batch visual verify → enemy `sprite_id` flip → smoke → catalog refresh → commit.
- Final state target (post-Codex): every wave-3 item shows dedicated hardcore-128 art at its real path; the 5 enemy `sprite_id`s point at their own folders; smoke green; catalogs show art ✅.

## Open item resolved at run time

Whether Codex image-generates or falls back to procedural is confirmed the moment the briefing is pasted into the Codex session. The design holds either way; only the achievable art *quality* differs.
