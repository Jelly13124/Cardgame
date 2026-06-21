# Asset Spec — Loading-screen background

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `run_system/assets/images/**`).
**Status:** Requested. Scene transitions currently show the rotating spinner on a
**plain black** screen; this adds a themed loading-screen illustration behind it.

## Problem

`SceneTransition` (`run_system/core/scene_transition.gd`) fades to black, loads the
next scene, and fades back. During the black hold it shows a centered spinner +
"加载中…" / "Loading…". The backdrop is currently pure black. We want a wasteland
loading-screen illustration behind the spinner.

The code renders it **dimmed to ~62%** (`modulate 0.62`) and **cover-fit** to the
screen, with the spinner + loading text centered on top.

## Deliverable (1 PNG)

| File | Subject |
|---|---|
| `run_system/assets/images/ui/loading_bg.png` | A full-screen wasteland loading-screen illustration (backdrop for the spinner) |

### Hard requirements
- **16:9, delivered at 1920×1080.** It's `STRETCH_KEEP_ASPECT_COVERED` in-game
  (fills the screen, may crop slightly at other aspect ratios), so keep important
  content away from the extreme edges.
- **Calm, uncluttered CENTER.** The spinner + a line of loading text sit dead
  centre, overlaid on top. Put the focal subject off-centre (rule-of-thirds) or
  keep the centre atmospheric/low-detail so the spinner reads cleanly.
- **Dark / atmospheric overall.** It's dimmed to ~62% and the spinner/text are warm
  amber (`#ffd673`) — so a moody, darker scene (dusk, dust haze, interior gloom)
  makes them pop. Avoid bright/busy centres.
- **Opaque, full-bleed** (no transparency needed — it's a backdrop). PNG.
- Subject = on-world wasteland flavour: e.g. Cowboy Bill silhouetted against a
  dusty horizon, a salvage yard at dusk, a lone road through the wastes, a derelict
  outpost. Match the locked **Offbeat Adult Sci-Fi Cartoon Wasteland** style
  (thick outline, cel shading) and the existing building / hero art.

Use the mandatory prompt anchor from `docs/PRD.md` (Art Style section), plus:
**"full-scene 16:9 illustration, moody/dim, calm uncluttered centre, no text, no UI."**

## Wiring after delivery
**None.** `scene_transition.gd` already loads `LOADING_BG_PATH`
(`res://run_system/assets/images/ui/loading_bg.png`) via `ResourceLoader.exists`
and falls back to plain black when it's absent. Drop the PNG in and it appears
behind the spinner automatically — zero code change. (Pairs with the spinner art
in `docs/asset-spec-loading-spinner.md`.)
