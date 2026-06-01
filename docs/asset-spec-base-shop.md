# Asset Spec — Base & Shop Scenes

**Audience:** Codex (asset generation)
**Owner of code/JSON:** Claude
**Project:** Cardgame (Godot 4.6, Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland)
**Created:** 2026-05-29

This is the contract for the home-base and shop scene art. Both scenes currently
render a plain dark background; this delivers real scene art + a shopkeeper.

## 0. Style Preamble (Non-Negotiable)

Every prompt for every asset in this doc must preserve the current art direction from `docs/art-style-reference.md` and `docs/project-rules.md` section 1:

```text
original offbeat adult sci-fi cartoon wasteland game art, Rick-and-Morty-like broad adult sci-fi animation energy without copying named characters or exact show designs, thick dark rubbery outlines, flat bright color blocks, simple cel shading, exaggerated asymmetrical proportions, weird junk-tech silhouette, dusty western leather and brass, dented steel, exposed springs, patched cloth, one or two small glowing neon accents, crisp sprite-ready edges, solid #FF00FF magenta background for cleanup or transparent final PNG, no text, no UI frame, no logo
```

Style notes:
- File dimensions in the tables below are output-size requirements only; they do not imply pixel art.
- Use clean cartoon silhouettes, thick dark outlines, flat bright color blocks, and simple cel shading.
- Keep the wasteland-western junk-tech materials: dusty leather, brass, dented steel, exposed springs, patched cloth, rubber hoses, cracked glass.
- Use one or two small neon accents per item or character; do not flood the asset with glow.
- Keep designs original and do not copy named characters or exact show-specific designs.
## 1. Pipeline

| Asset | Size | Transparent? | Output path |
|---|---|---|---|
| Home-base background | 1920×1080 | No (full scene) | `run_system/assets/images/home/home_base_bg.png` |
| Shop background      | 1920×1080 | No (full scene) | `run_system/assets/images/shop/shop_interior_bg.png` |
| Shopkeeper character | ~768×1024 | **Yes** (transparent) | `run_system/assets/images/shop/shopkeeper.png` |

Rules:
- **Backgrounds are scene-ready** — no UI, no text, no characters baked in, no frame/border. They sit behind UI panels, so keep the composition readable with a darker/calmer center where panels overlay; visual interest toward the edges.
- **Shopkeeper is a character sprite** — transparent background, single static pose, full body, facing the player (slight 3/4 is fine). No UI, no price tags, no speech bubble.
- Exact output paths; wrong path = the scene keeps its plain dark fallback.

## 2. Home-base background

- **Theme:** the player's fortified wasteland home base / scrapyard workshop hub — the safe camp you return to between runs to spend Core on upgrades. Scrap-metal structures, workbenches and welding rigs, salvaged crates, cables, a warm forge/campfire glow. Lived-in, hopeful-but-gritty. Wide establishing shot.
- **Composition:** calmer, slightly darker central band (a big upgrade panel + START button overlay it); more detail/structures toward the left and right edges.
- **Neon accent:** warm amber forge glow (one accent).

## 3. Shop background

- **Theme:** a wasteland merchant's stall / dim salvage shop interior — shelves of scavenged gear, hanging tools and weapons, ammo crates, a counter, a hanging lamp. Warmer and more cramped/cozy than the base.
- **Composition:** the shop board panel overlays the center, so keep center calmer; shelves and wares frame the sides.
- **Neon accent:** warm lamp-glow amber or a small cyan price-display glow (one accent).

## 4. Shopkeeper character

- **Theme:** a wasteland trader to stand in the shop — e.g. a scrap-built merchant robot, mutant scavenger, or goggled human trader in a patched coat, with a money pouch / scale / ware satchel, salvaged jewelry or trinkets. Should read as a friendly-but-shrewd merchant in the same radiation-rat style world. A large expressive lens/eye is on-theme if a robot, but a human or mutant trader is also fine.
- **Pose:** standing, facing the player, welcoming gesture or arms-crossed; single static sprite.
- **Neon accent:** one small glow (e.g. cyan eye/lens or amber lantern).

## 5. What NOT to do
- No UI, text, price tags, frames, or borders baked into any asset.
- No characters baked into the backgrounds (the shopkeeper is a separate transparent sprite).
- Don't change the output paths or sizes.
- Don't edit any `.gd` / `.tscn` / `.json` (Claude wires the display; ADR-0005).
- Don't commit API keys; read any service credentials from an env var.

## 6. Acceptance
- Each path exists at the listed size; backgrounds opaque, shopkeeper transparent (no leftover matte).
- Reads at 1920×1080 with a UI panel overlaying the center.
- One neon accent per asset; matches the approved cartoon wasteland reference.
- Claude wires `home_base_scene.gd` / `shop_scene.gd` to display them (graceful fallback if missing).
