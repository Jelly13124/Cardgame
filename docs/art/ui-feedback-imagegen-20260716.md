# UI feedback art generation — 2026-07-16

All assets in this batch use the project's approved original flat 2D American-comic
sci-fi western direction: controlled black ink, restrained cel shading, readable
silhouettes, weathered metal/leather, and sparse cyan/orange accents. References were
the existing UI07 kit, current approved equipment icons, and the runtime screenshots.

## Production assets

- Battle HUD: dedicated charcoal/brass nine-patch HP frame, compact blue/cyan block
  badge, and no heart/skull decoration.
- Set equipment: three five-item contact sheets (Weak Hunter, Tank Engineer, Warden),
  isolated on chroma backgrounds and split by alpha gaps into 15 transparent 256px
  icons. Each sheet orders head, chest, weapon, hands, trinket.
- Home buildings: forge, clinic, market, and outpost as isolated transparent comic
  sprites. Runtime normal/hover/pressed states share the same art; hover is a 10%
  luminance lift and pressed is a darkened 3px-down state, with no filled hover block.
- Building interiors: forge, clinic, and outpost 16:9 stages with a low-detail open
  centre reserved for UI. Forge is warm iron/orange, clinic is cold cyan, and outpost
  is brown radio-room metal.
- Shell UI: clean save-slot strip with no baked settings gear and a dedicated
  rust-orange forge dismantle action plaque.

## Imagegen/post-processing mode

- Raster generation used opaque chroma-key backgrounds for isolated sprites and UI.
- Chroma removal used the bundled `remove_chroma_key.py` soft matte with sampled
  corners, edge contraction, spill cleanup, and alpha-bounds cropping.
- Final runtime sizes: equipment 256×256; home building canvases preserve their prior
  per-building dimensions; interiors 1920×1080; HP frame 512×80; block badge 128×128;
  dismantle plaque 512×128; save strip 640×145.
