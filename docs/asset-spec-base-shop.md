# Asset Spec — Base & Shop Scenes

**Audience:** Codex (asset generation)
**Owner of code/JSON:** Claude
**Project:** Cardgame (Godot 4.6, Hardcore Wasteland Sprite Art)
**Created:** 2026-05-29

This is the contract for the home-base and shop scene art. Both scenes currently
render a plain dark background; this delivers real scene art + a shopkeeper.

## 0. Style Preamble (Non-Negotiable)

Match the project's **Hardcore Wasteland Sprite Art** direction (see `docs/art-style-reference.md`, ADR-0011).

**Style ground truth — study before generating:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png`. New art must sit in the same world: detailed, fully-rendered illustration; bold dark outlines; warm rust / leather / brass / dusty-tan wasteland palette; rich highlight-mid-shadow shading; one small glowing neon accent. **NOT lo-fi pixel art, not flat.** If wording conflicts with how Bill looks, Bill wins.

Prompt anchor (preserve in every prompt):
```
hardcore wasteland sprite art, detailed fully-rendered illustration, bold dark outlines,
rich controlled shading with clear highlight-mid-shadow, warm rust / leather / brass / dark-steel / dusty-tan palette,
salvaged scrap metal with bolts dents tubes and cracked glass, worn leather and patched cloth,
one small glowing neon accent, match the Cowboy Bill reference fidelity, not lo-fi pixel art, not flat
```

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

- **Theme:** a wasteland trader to stand in the shop — e.g. a scrap-built merchant robot or a goggled human trader in a patched coat, with a money pouch / scale / ware satchel, salvaged jewelry or trinkets. Should read as a friendly-but-shrewd merchant, same world as Cowboy Bill. One large camera-eye is on-theme if a robot (matches the Bill/Trash-Bot robot motif), but a human trader is also fine.
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
- One neon accent per asset; matches the Cowboy Bill fidelity (rendered, not lo-fi).
- Claude wires `home_base_scene.gd` / `shop_scene.gd` to display them (graceful fallback if missing).
