# Wave-3 Art Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the wave-3 art contract tool-agnostic (drop the dropped-PixelLab references) so it's a paste-ready Codex briefing, and document the Claude-side completion runbook for when Codex delivers art.

**Architecture:** Two phases. **Phase A (now):** edit two Markdown contract docs to remove PixelLab/`$env:PIXELLAB_API_KEY` and reframe generation as method-neutral. **Phase B (per Codex delivery, later):** a runbook — visually verify each delivered batch, flip the 5 enemy `sprite_id`s, smoke-test, refresh catalogs, commit. There is no application code to change in Phase A; verification is grep + headless smoke, not unit tests (this is a docs/data task).

**Tech Stack:** Markdown docs, Godot 4.6 JSON content, `scripts/smoke_test.sh` (headless DataValidator), `scripts/gen_catalogs.py` (catalog art-presence check). Spec: `docs/superpowers/specs/2026-05-28-wave3-art-handoff-design.md`.

---

## File Structure

- **Modify (Phase A):** `docs/asset-spec-content-expansion.md` — the work order; strip PixelLab, add a tool-agnostic generation note.
- **Modify (Phase A):** `docs/codex-prompt-content-expansion.md` — the paste-in briefing; strip PixelLab, add a generation-method note.
- **Modify (Phase B, enemy batch only):** `battle_scene/card_info/enemy/{rust_titan,ash_warden,slag_walker,acid_spitter,chrome_hound}.json` — flip `sprite_id` to each enemy's own folder.
- **Use (not edit):** `scripts/smoke_test.sh`, `scripts/gen_catalogs.py`, the `/regen-catalogs` skill.
- **External (Codex, not this plan):** PNGs under `battle_scene/assets/images/**` and `run_system/assets/images/relics/**`.

Smoke binary on this machine: `GODOT_BIN="C:/Program Files/Godot/Godot.exe"`.

---

# Phase A — Contract refresh (do now)

### Task 1: Make `asset-spec-content-expansion.md` tool-agnostic

**Files:**
- Modify: `docs/asset-spec-content-expansion.md`

- [ ] **Step 1: Add the tool-agnostic generation note** near the top.

Replace this exact paragraph:

```markdown
**Every asset in this spec currently uses a placeholder** — gameplay works but the visuals borrow other items' art. When you replace a placeholder, the game picks up the real art automatically (paths are fixed in the JSON).
```

with:

```markdown
**Every asset in this spec currently uses a placeholder** — gameplay works but the visuals borrow other items' art. When you replace a placeholder, the game picks up the real art automatically (paths are fixed in the JSON).

> **Generation is tool-agnostic.** This doc fixes only *what* to produce (paths, sizes, style, one neon accent per item) — not *how*. There is currently NO external image service wired in (the previous PixelLab pipeline was dropped). Use whatever image generation your session supports. If you have no image model, the documented fallback is improving the procedural generator `scripts/gen_wave3_content_assets.py`, which already drew crude geometric placeholders at every target path; you **overwrite** those finals in place. Enemy art will not render until Claude flips the 5 new enemies' `sprite_id` to their own folders post-delivery — that is Claude's follow-up, not Codex's.
```

- [ ] **Step 2: Replace the PixelLab key bullet** in section 7 ("What NOT to do").

Replace this exact line:

```markdown
- Do not commit a leaked PixelLab API key. The generator scripts read `$env:PIXELLAB_API_KEY` now (see `battle_scene/assets/images/enemies/generate_enemy.ps1`).
```

with:

```markdown
- Do not commit API keys or secrets. If your generation method calls an external service, read its credentials from an environment variable in your shell session — never bake them into a committed file.
```

- [ ] **Step 3: Verify no PixelLab references remain and the item tables are intact.**

Run:
```bash
grep -ci pixellab docs/asset-spec-content-expansion.md
grep -c '`cards/player/' docs/asset-spec-content-expansion.md
```
Expected: first command prints `0` (no PixelLab). Second prints a non-zero count (the card output-path rows are untouched). Eyeball that sections 2–5 (Cards/Enemies/Equipment/Relics tables) are unchanged.

- [ ] **Step 4: Commit.**

```bash
git add docs/asset-spec-content-expansion.md
git commit -m "docs(asset-spec): drop PixelLab, make wave-3 generation tool-agnostic"
```

---

### Task 2: Make `codex-prompt-content-expansion.md` tool-agnostic

**Files:**
- Modify: `docs/codex-prompt-content-expansion.md`

- [ ] **Step 1: Add the generation-method note** after the intro paragraph.

Replace this exact sentence (end of the intro paragraph):

```markdown
You are responsible for replacing the placeholders with real assets that match the project's art rules.
```

with:

```markdown
You are responsible for replacing the placeholders with real assets that match the project's art rules.

**Generation method (read first):** This briefing fixes *what* to produce — paths, sizes, style, one neon accent per item — not *how*. There is currently NO external image service configured (the old PixelLab pipeline was dropped). Generate using whatever image capability your session has; if you have none, the fallback is to improve the procedural generator `scripts/gen_wave3_content_assets.py` (it already drew crude geometric placeholders at every target path). Either way, **overwrite the existing placeholder PNGs in place**, and do not re-introduce PixelLab or any specific tool dependency.
```

- [ ] **Step 2: Replace the PixelLab key bullet** in Step 7 ("Don't touch").

Replace this exact line:

```markdown
- Do not commit any literal API keys. The `generate_enemy.ps1` and `gen_*` scripts read from `$env:PIXELLAB_API_KEY`. If your generator needs the key, set it in your shell session, do not bake it into the script.
```

with:

```markdown
- Do not commit any literal API keys or secrets. If your generation method calls an external service, read its credentials from an environment variable in your shell session — never bake them into a committed file.
```

- [ ] **Step 3: Verify no PixelLab references remain.**

Run:
```bash
grep -ci pixellab docs/codex-prompt-content-expansion.md
```
Expected: `0`.

- [ ] **Step 4: Commit.**

```bash
git add docs/codex-prompt-content-expansion.md
git commit -m "docs(codex-prompt): drop PixelLab, add tool-agnostic generation note"
```

---

### Task 3: Confirm the handoff package is coherent (read-through, no edit)

**Files:** none modified.

- [ ] **Step 1: Read both refreshed docs end-to-end** and confirm: the 27-item tables (13 cards / 5 enemies / 5 Warden equipment / 4 relics) are present with exact paths + frame sizes + neon accents; the magenta-chroma / transparent-final / enemy-faces-left / frame-size rules are intact; nothing instructs Codex to edit `.gd`/`.json`/`.tscn`.

- [ ] **Step 2: Verify the briefing is paste-ready.**

Run:
```bash
grep -n "Copy everything below" docs/codex-prompt-content-expansion.md
```
Expected: matches the "Copy everything below the `---`" line — the content under it is what the user pastes into their Codex session.

No commit (no changes).

---

**Phase A is the complete now-work.** Hand `docs/codex-prompt-content-expansion.md` to the user — they paste it into their Codex session. Whether Codex image-generates or falls back to procedural code becomes visible immediately. Phase B runs later, once Codex pushes art.

---

# Phase B — Completion runbook (run per Codex delivery batch, later)

> Gated on Codex delivering art. Delivery order: cards → enemies → equipment → relics. Run Task 4 for **every** batch; additionally run Task 5 for the **enemy** batch.

### Task 4: Per-batch acceptance (cards / equipment / relics batches)

**Files:** none edited by Claude (Codex committed the PNGs); catalogs updated via skill.

- [ ] **Step 1: Pull the batch.**

```bash
git pull --ff-only
```

- [ ] **Step 2: Visually verify each delivered PNG.** For every file in the batch, open it and confirm: correct path + dimensions (cards 512×320; equipment/relic icons 128×128), transparent background (no `#FF00FF` leftover), exactly one neon accent, silhouette readable at in-game scale. Use the Read tool to view each PNG. If any fails, note it and ask the user to have Codex redo that item (do NOT edit the art — ADR-0005).

- [ ] **Step 3: Run the headless smoke test.**

```bash
GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh
```
Expected tail: `[OK] DataValidator: all schemas passed.`

- [ ] **Step 4: Refresh the catalogs' art-presence status.** Run the generator and reconcile the Art/Icon column in the relevant `docs/catalog-*.md` (cards or relics) per the `/regen-catalogs` skill:

```bash
PYTHONIOENCODING=utf-8 python scripts/gen_catalogs.py cards
```
(Use `relics` for the relic batch. Equipment has no catalog file — skip.)

- [ ] **Step 5: Commit any catalog refresh.** Stage the catalog file that matches this batch (`docs/catalog-cards.md` for the cards batch, `docs/catalog-relics.md` for the relics batch):

```bash
git add docs/catalog-cards.md   # or docs/catalog-relics.md for the relics batch
git commit -m "docs(catalog): wave-3 <category> art delivered, refresh art status"
```
(Skip entirely for the equipment batch — no catalog file exists, and Codex's PNGs auto-upgrade with no Claude-side change.)

---

### Task 5: Enemy `sprite_id` flip (run only for the enemy batch, after Task 4 visual-verify passes)

**Files:**
- Modify: `battle_scene/card_info/enemy/rust_titan.json`
- Modify: `battle_scene/card_info/enemy/ash_warden.json`
- Modify: `battle_scene/card_info/enemy/slag_walker.json`
- Modify: `battle_scene/card_info/enemy/acid_spitter.json`
- Modify: `battle_scene/card_info/enemy/chrome_hound.json`

- [ ] **Step 1: Flip each `sprite_id` to the enemy's own folder.** Apply these exact edits:

| File | Change |
|---|---|
| `rust_titan.json` | `"sprite_id": "rust_brute"` → `"sprite_id": "rust_titan"` |
| `ash_warden.json` | `"sprite_id": "armored_patrol"` → `"sprite_id": "ash_warden"` |
| `slag_walker.json` | `"sprite_id": "rust_brute"` → `"sprite_id": "slag_walker"` |
| `acid_spitter.json` | `"sprite_id": "mortar_cart"` → `"sprite_id": "acid_spitter"` |
| `chrome_hound.json` | `"sprite_id": "riot_hound"` → `"sprite_id": "chrome_hound"` |

- [ ] **Step 2: Verify each enemy now points at its own (Codex-delivered) folder and none are unlisted.**

```bash
PYTHONIOENCODING=utf-8 python scripts/gen_catalogs.py enemies
```
Expected: the Sprite ID column for the 5 enemies now shows their own id (e.g. `rust_titan`), Frames `✅`, and there is no `UNLISTED` warning.

- [ ] **Step 3: Run the headless smoke test** (DataValidator cross-checks every enemy + encounter pool at boot).

```bash
GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh
```
Expected tail: `[OK] DataValidator: all schemas passed.`

- [ ] **Step 4: Update the enemies catalog** — remove the `†` placeholder-sprite footnote and the `†` marks in the summary table (sprites are now dedicated), per `/regen-catalogs`.

- [ ] **Step 5: Commit.**

```bash
git add battle_scene/card_info/enemy/rust_titan.json battle_scene/card_info/enemy/ash_warden.json battle_scene/card_info/enemy/slag_walker.json battle_scene/card_info/enemy/acid_spitter.json battle_scene/card_info/enemy/chrome_hound.json docs/catalog-enemies.md
git commit -m "feat(enemies): point 5 wave-3 enemies at their delivered dedicated sprites"
```

---

## Final state (after all Phase-B batches)

Every wave-3 item shows dedicated hardcore-128 art at its real path; the 5 enemy `sprite_id`s point at their own folders; `scripts/smoke_test.sh` is green; `docs/catalog-*.md` show art `✅` with no placeholder footnotes. Phase 5's "enemy types with final sprite art" item is closed.
