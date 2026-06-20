# Asset Spec — Card back (transparent corners)

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `battle_scene/assets/images/**`).
**Status:** Requested. The current card back ships with an **opaque black
background**, which reads as an ugly black frame behind the draw/discard piles.

## Problem

`battle_scene/assets/images/cards/ui/card_back.png` (160×220) is the universal
card back — shown on the **Deck** and **DiscardPile** piles in battle
(`battle_scene/battle_scene.tscn` → `CardManager/Deck/CardBackVisual` and
`CardManager/DiscardPile/CardBackVisual`) and on any face-down card.

The art is a rounded, ornate card (brown/gold frame + teal diamond emblem), but
its **corners and outer border are baked OPAQUE BLACK** (`rgba(0,0,0,255)` — 100%
of the border ring). On the lighter desert/swamp battle backgrounds the black
rectangle around the rounded card stands out as a hard black frame (the user's
"抽牌堆弃牌堆下面有黑框").

The Control + `TextureRect` that render it draw nothing black themselves — the
black is **inside the PNG**. So this is a pure art fix: same design, transparent
background.

## Deliverable (1 PNG, overwrite in place)

| File | Subject |
|---|---|
| `battle_scene/assets/images/cards/ui/card_back.png` | The existing card-back design (rounded brown/gold frame, teal diamond + Cowboy Bill emblem) on a **transparent** background |

### Hard requirements
- **Keep the existing card-back design.** The artwork itself is fine — do NOT
  redesign it. The ONLY change is the background.
- **Transparent background (PNG with alpha).** Everything outside the rounded
  card silhouette — corners included — must be fully transparent (`alpha = 0`),
  not black. The rounded card sits cleanly on any scene behind it.
- **Preserve the portrait aspect** (160:220). Deliver at **2× = 320×440** for
  crispness (rendered at 160×220 in-game; size is an output contract only, per
  project rules) — or 160×220 if regenerating at native size is cleaner.
- **Soft anti-aliased rounded corners** against the transparent edge (no black
  fringe / matte halo left over from background removal).
- Style = the locked **Offbeat Adult Sci-Fi Cartoon Wasteland** (thick dark
  cartoon outline on the card frame itself is fine and expected — that outline is
  part of the card, NOT a background; only the area *outside* the card outline
  must be transparent).

## Wiring after delivery
**None.** Drop-in overwrite — `card_back.png` is already wired into both piles via
`TextureRect` (`stretch_mode = keep-aspect-centered`). Once the transparent
version lands, the black frame disappears with zero code change. (The
`CardBackVisual` TextureRects keep aspect, so the transparent margins simply show
the scene behind.)
