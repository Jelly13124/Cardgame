# Asset Spec — Home-base background touch-up (1 PNG, 4 building pads + bar strip)

**Owner:** Codex (ADR-0005). **Status:** REQUESTED 2026-07-04. **Priority:** LOW —
do AFTER the ui-kit rev2 polish settles; the current bg ships fine meanwhile.

## What & why

`run_system/assets/images/home/home_base_empty_bg.png` (1920×1080, the empty
desert used behind the home base) was painted for the old 5-building layout:
its dirt paths/ground wear don't converge where buildings actually stand now,
and the bottom edge has mid-value clutter that fights the new bottom HUD bar.

Re-export the SAME scene (same sky, mesas, cacti, palette, art language —
this is a touch-up, not a repaint) with two changes:

1. **Four ground pads**: subtle packed-dirt pads / wear patches centred at
   x ≈ 375, 765, 1155, 1545 (y ground zone ≈ 300-660 is where the 360×360
   building sprites sit; pads read as "something heavy stands here"), with the
   existing path network redrawn to converge naturally onto these four spots
   (and a wider path leading to bottom-centre, where the START button sits).
2. **Quiet bottom strip**: the bottom ~110px darkens/simplifies (ground
   shadow / darker dirt, no props, no bright highlights) so the near-black
   HUD bar sits on it without visual noise poking out around it.

## Constraints

- Same file path + dimensions (drop-in overwrite; zero code change).
- project-rules §1 language: flat adult sci-fi cartoon wasteland, thick clean
  dark outlines on foreground props, broad cel shading, no painterly noise.
- Keep the centre of the frame relatively calm (buildings + windows overlay it).
- No text, no watermark, no baked UI.

## Verification checklist

- [ ] Paths converge at the four pad positions above (±40px is fine).
- [ ] Bottom 110px reads as one quiet dark band edge-to-edge.
- [ ] Side-by-side with the current file: same scene identity (sky/mesas/cacti).
