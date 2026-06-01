# Codex Prompt — Base & Shop Scene Art

Copy everything below the `---` line into your Codex session.

---

You are working in the Godot 4.6 project at `C:\Users\Jerry\Desktop\Cardgame` — a roguelite deckbuilder in the **Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland** style. The home-base and shop scenes currently render a plain dark background. Generate three assets: a home-base background, a shop background, and a shopkeeper character.

**Generation method:** This briefing fixes *what* to produce (paths, sizes, style) — not *how*. There is no external image service configured; use whatever image capability your session has. Overwrite the exact paths below; do not introduce a tool dependency or commit secrets.

## Step 1 — Read first (style ground truth)
- `docs/asset-spec-base-shop.md` — the authoritative work order (themes, paths, sizes, acceptance). Read it fully.
- `docs/art-style-reference.md` — the Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland rules.
- **`docs/art/rick-morty-radiation-rat-style-reference.png`** — the visual ground truth for the new style. Your art must look like it belongs in the same world: thick rubbery dark outlines, flat bright color blocks, simple cel shading, exaggerated odd proportions, bulging expressive eyes, toxic-green radiation accents, dusty western junk-tech materials, and one or two small neon accents. If older wording conflicts with this reference, the reference wins.

## Step 2 — Deliverables (exact paths + sizes)
1. **Home-base background** → `run_system/assets/images/home/home_base_bg.png` — 1920×1080, opaque. Fortified wasteland scrapyard workshop hub (workbenches, welding rigs, salvaged crates, cables, warm forge glow). Calmer/darker central band (a UI panel overlays the center); detail toward the edges. One amber accent.
2. **Shop background** → `run_system/assets/images/shop/shop_interior_bg.png` — 1920×1080, opaque. Dim wasteland merchant stall (shelves of scavenged gear, hanging tools/weapons, ammo crates, a counter, a hanging lamp). Calmer center (the shop board overlays it); wares frame the sides. One warm-amber/cyan accent.
3. **Shopkeeper character** → `run_system/assets/images/shop/shopkeeper.png` — ~768×1024, **transparent**. A wasteland trader (scrap-built merchant robot or goggled human in a patched coat) with money pouch / scale / ware satchel; standing, facing the player. One small glow accent (cyan lens or amber lantern).

## Step 3 — Rules (non-negotiable)
1. Preserve the current prompt anchor from the matching asset spec section 0 in every prompt.
2. **Backgrounds:** scene-ready — NO UI, text, frames, borders, or characters baked in.
3. **Shopkeeper:** transparent background, single static full-body pose, no UI/price-tags/speech-bubble.
4. One small neon accent per asset — not a flood color.
5. Exact output paths/sizes from §2; a wrong path means the scene keeps its plain dark fallback.

## Step 4 — Per asset
Compose the prompt = theme (from asset-spec §2–4) + the radiation-rat style reference + the style anchor. Generate, then check it reads at 1920×1080 with a UI panel over the center (backgrounds) / at in-shop scale (shopkeeper). Save to the exact path.

## Step 5 — Don't touch (ADR-0005)
- Do not edit any `.gd`, `.tscn`, or `.json` — code/data are Claude's domain. Claude wires the scenes to display these assets.
- Do not bake UI into the art. Do not change paths/sizes. Do not commit API keys.

## Step 6 — Commit
One commit: `Codex: base+shop scene art (3 assets)`. Push when done.
