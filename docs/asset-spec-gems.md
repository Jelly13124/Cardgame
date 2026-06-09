# Asset Spec — Gem Icons (Codex)

> **For Codex (ADR-0005).** 8 run-scoped socketable gems. Each slots into a card
> (≤2 per card) and fires its effect when the card is played. They currently render
> with a 💎 glyph / text only — deliver icon art at the target path.

## Deliverable

One PNG per gem id below.

- **Target path:** `run_system/assets/images/gems/<id>.png`
- **Source size:** 64×64, transparent background (shown small in sockets + larger in
  the draft/inventory — must read at ~30px). Bold faceted-gem silhouette.
- **Palette:** lead with the gem's theme colour; dark outline for legibility on the
  card art and the dark inventory panel.
- Wire-up note (Claude, after art lands): the socket/inventory/draft widgets show a
  💎 glyph + name today; swap to a TextureRect loading `gems/<id>.png` with the glyph
  as fallback. No data change.

## Gems

| id | name (en/zh) | effect on play | theme hex | icon direction |
|----|--------------|----------------|-----------|----------------|
| `wealthy` | Wealthy / 富裕 | +5 gold (max 3/combat) | `#ffd24a` | gold coin facet |
| `keen` | Keen / 锋锐 | +3 damage | `#ff6b5e` | sharp red shard |
| `bulwark` | Bulwark / 壁垒 | +4 Block | `#7fa8d8` | blue shield-cut gem |
| `swift` | Swift / 迅捷 | draw 1 card | `#7be0a0` | green teardrop |
| `venom` | Venom / 毒囊 | apply 2 Bleed | `#c85ad8` | violet drop |
| `brute` | Brute / 蛮力 | +1 Strength | `#ff9e4a` | orange angular gem |
| `spark` | Spark / 电火花 | +1 Energy | `#f2e24d` | yellow lightning-cut |
| `leech` | Leech / 吸血 | heal 2 HP | `#ff4d6e` | deep-red heart-cut |

(Display names live in `assets/translations/content_cards.csv` as
`GEM_<id>_TITLE` / `_DESC`. Catalog page: `docs/catalog_html/gems.html`.)
