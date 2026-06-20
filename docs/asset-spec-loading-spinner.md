# Asset Spec — Loading spinner

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `run_system/assets/images/**`).
**Status:** Requested. Scene transitions currently show a rotating **gear glyph (⚙)**
placeholder during the black load hold; this replaces it with bespoke art.

## Problem

`SceneTransition` (`run_system/core/scene_transition.gd`) fades to black, loads the
next scene, and fades back. During the black hold (noticeable when the battle scene
preloads its card pool) it now shows a centered loading indicator: a spinner above a
"加载中…" / "Loading…" label. The spinner is **rotated continuously by code**
(0→360° over 0.9s, looping), so the art must be a single still image designed to spin.

Right now the spinner is a placeholder **⚙ gear glyph**. We want a proper themed icon.

## Deliverable (1 PNG)

| File | Subject |
|---|---|
| `run_system/assets/images/ui/loading_spinner.png` | A single wasteland loading spinner icon, designed to be rotated continuously by the engine |

### Hard requirements
- **Designed to ROTATE about its center.** The engine spins this image around its
  centre point (pivot = image centre), so the subject must read well while turning —
  e.g. a cog/gear, a salvage saw-blade, a radial gauge/compass, or a segmented ring
  with a brighter "head" segment. NOT something with a fixed up/down (no text, no
  upright figure).
- **Centered + balanced.** The visual centre of mass must sit at the image centre, or
  it will appear to wobble while spinning. Even padding all around.
- **Transparent background** (PNG with alpha). Only the spinner subject is opaque.
- **Square**, delivered at **192×192** (rendered ~96px in-game; size is an output
  contract only, per project rules).
- Style = the locked **Offbeat Adult Sci-Fi Cartoon Wasteland**: thick dark cartoon
  outline, 2–3 value cel shading, low texture noise. Warm brass/amber tones so it
  reads on a pure-black screen (the placeholder uses amber `#ffd673`); one bright
  accent highlight is welcome.
- Optional: a subtle brighter "leading" segment / glint so the rotation direction is
  legible (makes the spin feel intentional rather than a static wheel).

Use the mandatory prompt anchor from `docs/PRD.md` (Art Style section), plus:
**"single centered icon, radially symmetric, no text, no number, transparent background."**

## Wiring after delivery
**None.** `scene_transition.gd` already loads `SPINNER_TEX_PATH`
(`res://run_system/assets/images/ui/loading_spinner.png`) via `ResourceLoader.exists`
and falls back to the ⚙ glyph when it's missing. Drop the PNG in and the real spinner
appears automatically — zero code change.
