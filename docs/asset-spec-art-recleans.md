# Asset Spec — Art re-cleans (3 PNGs)

**Owner:** Codex (ADR-0005 — Codex generates/cleans all PNGs under
`run_system/assets/images/**`). **Status:** Delivered 2026-06-20. These three shipped art
files have cleanup defects; the code already loads them, so a clean re-export at
the **same path** fixes the in-game look with zero code change.

## 1. `home/currency/caps.png` — drop the baked-in number
The cap icon has a small **"1" baked into the art** (top-right). The HUD draws the
live count next to the icon, so the baked "1" reads as a stray/duplicate number.
Re-export the **same bottle-cap icon with NO number/text** (transparent bg,
square, ~128×128). See `docs/asset-spec-currency-icons.md` for the full currency
context.

## 2. `home/currency/scrap.png` — drop the baked-in number
Same issue, worse: a **"232" is baked across the scrap icon**. Re-export the
scrap/bolt icon with **no number/text**, transparent bg, square.
(`home/currency/core.png` is already clean — leave it.)

## 3. `home/buildings_runtime/clinic.png` — remove the stray block on the right
The clinic building sprite has a **small stray block / leftover chunk on the right
edge** (a background-removal artifact — not part of the building). Re-clean so only
the clinic + its intended awning/pipes remain, everything else fully transparent.
Keep the building art itself unchanged; just remove the floating right-edge
fragment and tidy the alpha edges.

## Wiring after delivery
**None.** All three are drop-in overwrites at the paths above — the currency chips
(`home_base_scene._make_currency_chip`) and building sprites
(`_add_interactive_building`) already load them via `ResourceLoader.exists`.

## Delivery notes
- `home/currency/caps.png`: regenerated as a clean 128x128 transparent icon with no baked number or UI chip background.
- `home/currency/scrap.png`: regenerated as a clean 128x128 transparent icon with no baked number or UI chip background.
- `home/buildings_runtime/clinic.png`: re-cleaned in place at 447x471; detached right-edge alpha fragments were removed while preserving the main clinic sprite.
