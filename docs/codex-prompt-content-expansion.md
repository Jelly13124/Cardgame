# Codex Prompt — Content Expansion (Wave 3) Asset Generation

Copy everything below the `---` line into your codex session.

---

You are working in the Godot 4.6 project at `C:\Users\Jerry\Desktop\Cardgame` — a roguelite deckbuilder with a strict **Hardcore Wasteland Sprite Art** style. Between 2026-05-25 and 2026-05-26, Phase 5 wave 1 + wave 2 shipped a batch of new cards, a multi-act boss redesign, the Warden equipment set, and 4 new uncommon/rare relics. All gameplay, JSON, and UI work is done. **Every one of those new items currently uses a placeholder PNG** (reused art from a similar existing item). You are responsible for replacing the placeholders with real assets that match the project's art rules.

**Generation method (read first):** This briefing fixes *what* to produce — paths, sizes, style, one neon accent per item — not *how*. There is currently NO external image service configured (the previous one was dropped). Generate using whatever image capability your session has; if you have none, the fallback is to improve the procedural generator `scripts/gen_wave3_content_assets.py` (it already drew crude geometric placeholders at every target path). Either way, **overwrite the existing placeholder PNGs in place**, and do not re-introduce any specific external tool dependency.

**Style ground truth — study these BEFORE generating anything, and match them.** Cowboy Bill is the canonical character and the single source of truth for the look:
- `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png`
- `battle_scene/assets/images/heroes/cowboy_bill/attack/cowboy_bill_attack_0.png`

Match his exact treatment: warm rust / leather / brass / dusty-tan palette; bold dark outlines; rich controlled shading with a clear highlight-mid-shadow read (a polished, fully-rendered sprite — NOT flat, lo-fi, or crude geometric shapes); riveted salvaged-metal and patched-cloth materials; and exactly one small glowing neon accent (like Bill's amber eye and cyan chest light). Every new card, enemy, equipment, and relic must look like it belongs in the same set as Bill — same line weight, same rendering fidelity, same palette family. **If the "hardcore 128 pixel wasteland" wording in these docs ever seems to conflict with how Bill actually looks, Bill's sprite wins** — it is the real target; the text is only shorthand.

## Step 1 — Read these files before doing anything else

1. **`docs/asset-spec-content-expansion.md`** — your authoritative work order. Lists every PNG you need to deliver, the exact file path, the frame size, the theme description, and the neon accent color per item. Read sections 0–8 in order.
2. **`docs/art-style-reference.md`** — the approved Hardcore Wasteland Sprite Art visual reference translated into concrete art rules.
3. **`docs/project-rules.md`** §1–§5 — the non-negotiable style anchor, sprite pipeline (`#FF00FF` chroma key → transparent PNG), and folder/naming conventions.
4. **`docs/adr/0008-art-pivot-to-hardcore-128-pixel-wasteland.md`** — the ADR locking in the current art direction. Confirms native sizes (128 for regular, 192 for bosses), reference image path, palette and outline rules.
5. **`docs/catalog-all.md`** — the bilingual content catalog, for cross-referencing what each card / enemy / item actually does in-game (helps the art match the mechanic).

Also look at one reference of each existing asset type so your output matches the project's visual weight:

| Reference for | File |
|---|---|
| **Overall style anchor (study FIRST)** | `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png` + `heroes/cowboy_bill/attack/cowboy_bill_attack_0.png` |
| Card front art      | `battle_scene/assets/images/cards/player/strike.png` (512×320) |
| Regular enemy frame | `battle_scene/assets/images/enemies/trash_robot/attack/trash_robot_attack_0.png` (128×128) |
| Boss enemy frame    | `battle_scene/assets/images/enemies/junkyard_tyrant/attack/junkyard_tyrant_attack_0.png` (192×192) |
| Equipment icon      | `battle_scene/assets/images/equipment/lucky_charm.png` (128×128) |
| Relic icon          | `run_system/assets/images/relics/cracked_battery.png` (128×128) |

## Step 2 — Deliverables (all itemized in the asset spec)

- **13 card front-image PNGs** → `battle_scene/assets/images/cards/player/{card_id}.png` (512×320 each)
- **5 enemy sprite sets** → `battle_scene/assets/images/enemies/{sprite_id}/attack/{sprite_id}_attack_{0..3}.png`
  - `rust_titan` and `ash_warden` are bosses → 192×192
  - `slag_walker`, `acid_spitter`, `chrome_hound` are regular enemies → 128×128
- **5 equipment icons** → `battle_scene/assets/images/equipment/warden_*.png` (128×128 each)
- **4 relic icons** → `run_system/assets/images/relics/{relic_id}.png` (128×128 each)

All single-frame (except enemy attack sequences, which are 4 frames each), transparent background.

## Step 3 — Pipeline rules (non-negotiable)

These come from `docs/project-rules.md` §2–§5 and the asset spec section 1. Follow exactly:

1. **Every prompt** must preserve the Hardcore Wasteland Sprite Art prompt anchor (verbatim from asset spec §0).
2. **Item / icon assets are item-only** — no character holding the item, no UI frame, no background scene, no rarity badges, no text. Just the item, centered, on transparent background.
3. **Card art is composition-only** — no UI frame, no cost circle, no title text. The card-framework script overlays those.
4. **Enemy / boss sprites face LEFT** in source PNGs. (Heroes face right; enemies face left.)
5. **Sheet generation uses `#FF00FF` (magenta) background** for chroma-key cleanup. Final per-item output must be transparent PNG.
6. **Output paths are exact** — see the table in asset spec section 1. Wrong filename = placeholder fallback never gets replaced.
7. **One neon accent color per item** — small detail, not flood-color the whole item. Color is specified per-item in the spec tables.
8. **`.import` files** are generated by Godot on first import. Do not write them manually.
9. **Intermediate sheets** may stay in `<output_dir>/generated_sheet/` if they match the current delivery — drop a `pipeline-meta.json` and `prompt-used.txt` there for traceability.

## Step 4 — One item at a time

For each item in the asset spec:
1. Compose the prompt: theme description from the asset spec entry + neon accent color + the mandatory style anchor suffix.
2. Generate the icon (with `#FF00FF` background) — for enemy attack sequences, generate the 4 frames as a coherent animation (wind-up → strike → impact → settle).
3. Chroma-key cleanup → single transparent PNG (or 4 PNGs for enemy frames).
4. Verify the silhouette reads at in-game scale:
   - Cards: render at 160×220 hand size — squint at that scale and confirm the subject reads
   - Enemy/boss: render at native size (battle scene uses 192 height for regular, 288 for bosses) — confirm pose & facing
   - Equipment/relic: render at 48×48 (panel slot size) — confirm legibility
5. Save to the exact output path from the spec.

## Step 5 — Set / batch coherence

Cross-check each batch before considering it done:

- **Warden equipment set (5 pieces)** — same soot-black plate base, same ember-orange accent, same outline weight. If two pieces look like different sets, redo the offending one.
- **Ash Warden boss + Warden equipment set** — visually related (the gear was "stripped from a fallen Warden"). Boss has louder ember glow; equipment is the cooled-down version.
- **Mid/late enemies** (`slag_walker`, `acid_spitter`, `chrome_hound`) — should share the existing enemy roster's visual weight; lay them next to `rust_brute.png`, `mortar_cart.png`, `riot_hound.png` and confirm they fit.
- **Card art** — should match the existing 17 cards' visual density; lay next to `strike.png`, `junk_bomb.png`, `cascade.png` and confirm consistent line work + palette.

## Step 6 — Delivery order

Asset spec section 6 recommends shipping in this order so each batch has independent value:
1. Cards (13) — highest visibility, simplest pipeline
2. Enemies (5) — fixes "old enemy with new HP" feel from the multi-boss redesign
3. Warden equipment set (5) — boss-themed reward kit
4. Relics (4) — small visual footprint, last

Within each batch, ship in JSON-id alphabetical order so it's easy to track what's done.

## Step 7 — Don't touch

Per ADR-0005 (Claude/Codex ownership split):

- Do not edit any `.gd`, `.tscn`, or JSON files. Code/data are Claude's domain.
- Do not invent new effects, rename items, or change IDs.
- Do not bake UI frames, rarity badges, cost circles, or stat numbers into the art.
- Do not change frame sizes from the table in spec section 1.
- Do not regenerate already-shipped art unless the spec explicitly asks for it.
- Do not commit `.import` files (Godot writes them on import).
- Do not commit any literal API keys or secrets. If your generation method calls an external service, read its credentials from an environment variable in your shell session — never bake them into a committed file.

## Step 8 — Commits

One commit per asset category is fine (one for all 13 cards, one for all 5 enemies, etc.). Commit message format:

```
Codex: Wave-3 art — <category> (<N> items)

Generated per docs/asset-spec-content-expansion.md §<section>.
Each item: <neon-accent>, <frame-size>, hardcore-128-pixel-wasteland anchor.

<bulleted per-item list with id + one-line theme>
```

Push the branch when each category is done (do NOT batch all 4 categories into a single push — small batches are easier for Claude to review).
