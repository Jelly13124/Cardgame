# Codex handoff: hit-effect textures and flipbooks (2026-11-14)

Hits now burst into layered, additive sparks (`ui/battle/hit_spark_vfx.gd`). The
glow, streak and speck shapes are drawn in code. Some shapes cannot be drawn in
code: a starburst flare, smoke, a shockwave ring and one flipbook per hit kind.
This brief asks for those textures. Claude wires them in after review.

The layering follows a study of how Slay the Spire 2 builds its hit effects: a
centre glow, fast streak sparks, specks, outward streaks, plus one short
flipbook per attack type, all blended additively. That study is for structure
only. **Every texture must be original.** Do not trace, copy or recolour any
STS2 asset.

## Rules for this work

- **Art only.** Create the PNG files listed here. Do not edit `.gd`, `.tscn`,
  `.json` or translations.
- **Additive textures.** The game draws these files with additive blending, so
  black adds nothing and brighter pixels glow more. Deliver **RGBA PNGs with a
  transparent background**:
  - keep the hottest core near white;
  - put the colour in the falloff;
  - fade every edge to fully transparent;
  - leave no hard cut-off at the frame border.
- **Greyscale-friendly.** Items marked *tinted* are recoloured per hit kind in
  code. Draw those in white to warm-white, not in a final colour.
- **Style.** Use the wasteland comic house style (inked, chunky, flat-lit), as in
  `battle_scene/assets/images/fx/combat_feedback/` and
  `battle_scene/assets/images/fx/gunshot/`. These are bold comic shapes, not soft
  photographic smoke.
- **Frames.** Each flipbook is a set of separate files named `<name>-1.png` …
  `<name>-N.png`, the same as the existing `impact_normal-1.png`. Every frame
  shares one canvas size, and the burst is centred on the canvas centre.
- **Folder.** Use `battle_scene/assets/images/fx/hit/` (create it).

## Files

| File(s) | Canvas | Frames | What it is |
|---|---|---|---|
| `flare-1..4.png` | 256×256 | 4 | *Tinted.* A 6–8-point starburst flare. Frame 1 is a tight hot star, frames 2–3 open up, and frame 4 is thin fading rays. It plays on every hit. |
| `ring.png` | 256×256 | 1 | *Tinted.* A thin soft shockwave ring: transparent centre, a bright 6–10 px band at about 80% of the radius, transparent outside. Code scales it up and fades it. |
| `smoke_puff-1..6.png` | 256×256 | 6 | Dusty grey-brown comic smoke puff (not tinted). Frame 1 is a small dense ball; it billows out and breaks into 3–4 chunky lobes; frame 6 is thin wisps. It plays on blunt and blast hits. |
| `shot_impact-1..4.png` | 192×192 | 4 | Bullet hit: a small bright puncture flash with 3–5 metal shards flicking out in one direction (pointing right; code rotates it to match the shot). |
| `blast_burst-1..6.png` | 320×320 | 6 | Explosion: a hot orange-yellow fireball core, ragged flame tongues, then dark smoke edges eating in. Frame 6 is mostly smoke. |
| `shock_arc-1..4.png` | 256×256 | 4 | Electric hit: 3–4 jagged cyan-white arcs out from the centre. Change the arcs every frame (do not just scale them), so it flickers. |
| `blunt_crack-1..4.png` | 256×256 | 4 | Heavy blow: a flat comic "crack" star with a dust ring under it. It squashes wide on frame 1, then rebounds. |

That is 32 PNGs. Give each folder an `animation.gif` preview, as the other FX
folders have.

## Check before handing back

- Every file exists at the exact canvas size above, in RGBA with a transparent
  background.
- No frame has a visible rectangular edge when laid over a dark background.
- `python tools/check_missing_art.py` still reports 0 missing.
