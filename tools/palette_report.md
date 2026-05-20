# Palette Extraction Report

- Source: 87 game-art PNGs under `battle_scene/assets/images/` + `run_system/assets/images/`
- Bucket size: 16 (each RGB channel rounded to nearest multiple)
- Excluded: transparent pixels (alpha<200), outline ink (max RGB<25), `generated_sheet/` subfolders
- Total opaque pixels analyzed: 8,400,870

## Top color buckets (by frequency)

Pick **8-12** of these as the canonical Wasteland Pixel palette. Aim for: 4-5 earth-tone base colors, 2-3 neon accents, 2-3 UI neutrals (panel bg / borders).

| Rank | Swatch | Hex | Pct | Luminance | Sample assets (≤3) |
|---:|:---:|:---|---:|---:|:---|
| 1 | <span style="background:#a05020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#a05020` |  5.49% |   93.5 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 2 | <span style="background:#b06020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#b06020` |  4.43% |  108.4 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 3 | <span style="background:#804020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#804020` |  4.17% |   75.3 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 4 | <span style="background:#905020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#905020` |  3.87% |   90.1 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 5 | <span style="background:#302010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#302010` |  2.84% |   34.2 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 6 | <span style="background:#403020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#403020` |  2.35% |   50.2 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 7 | <span style="background:#503020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#503020` |  2.26% |   53.6 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 8 | <span style="background:#904020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#904020` |  2.24% |   78.7 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 9 | <span style="background:#201010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#201010` |  1.93% |   19.4 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 10 | <span style="background:#603020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#603020` |  1.90% |   57.0 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 11 | <span style="background:#402010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#402010` |  1.90% |   37.6 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 12 | <span style="background:#704020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#704020` |  1.87% |   71.9 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 13 | <span style="background:#a06020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#a06020` |  1.85% |  105.0 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 14 | <span style="background:#c06020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#c06020` |  1.74% |  111.8 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 15 | <span style="background:#a07040;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#a07040` |  1.62% |  118.7 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 16 | <span style="background:#c09050;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#c09050` |  1.56% |  149.6 | `adrenaline.png`, `cascade.png`, `charged_shot.png` |
| 17 | <span style="background:#b08050;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#b08050` |  1.47% |  134.7 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 18 | <span style="background:#703020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#703020` |  1.45% |   60.5 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 19 | <span style="background:#504030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#504030` |  1.37% |   66.2 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 20 | <span style="background:#b05020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#b05020` |  1.35% |   96.9 | `wasteland_battlefield.png`, `cascade.png`, `charged_shot.png` |
| 21 | <span style="background:#604030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#604030` |  1.26% |   69.6 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 22 | <span style="background:#603010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#603010` |  1.21% |   55.9 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 23 | <span style="background:#805030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#805030` |  1.20% |   87.9 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 24 | <span style="background:#b08040;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#b08040` |  1.18% |  133.6 | `adrenaline.png`, `cascade.png`, `charged_shot.png` |
| 25 | <span style="background:#704030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#704030` |  1.15% |   73.0 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 26 | <span style="background:#804030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#804030` |  1.13% |   76.5 | `wasteland_battlefield.png`, `cascade.png`, `charged_shot.png` |
| 27 | <span style="background:#906030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#906030` |  1.12% |  102.7 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 28 | <span style="background:#705030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#705030` |  1.09% |   84.5 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 29 | <span style="background:#201000;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#201000` |  1.05% |   18.2 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 30 | <span style="background:#e0d0a0;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#e0d0a0` |  0.97% |  207.9 | `adrenaline.png`, `cascade.png`, `charged_shot.png` |
| 31 | <span style="background:#d07020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#d07020` |  0.96% |  126.6 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 32 | <span style="background:#e08020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#e08020` |  0.95% |  141.5 | `wasteland_battlefield.png`, `cascade.png`, `defend.png` |
| 33 | <span style="background:#e07020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#e07020` |  0.90% |  130.0 | `wasteland_battlefield.png`, `cascade.png`, `defend.png` |
| 34 | <span style="background:#604020;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#604020` |  0.87% |   68.5 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 35 | <span style="background:#e0d0b0;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#e0d0b0` |  0.85% |  209.1 | `adrenaline.png`, `cascade.png`, `charged_shot.png` |
| 36 | <span style="background:#502010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#502010` |  0.84% |   41.0 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 37 | <span style="background:#b06030;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#b06030` |  0.82% |  109.5 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 38 | <span style="background:#703010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#703010` |  0.77% |   59.3 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 39 | <span style="background:#503010;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#503010` |  0.72% |   52.5 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |
| 40 | <span style="background:#605040;display:inline-block;width:24px;height:14px;border:1px solid #000"></span> | `#605040` |  0.72% |   82.2 | `wasteland_battlefield.png`, `adrenaline.png`, `cascade.png` |

## Canonical palette (picked 2026-05-19)

Observation: the source art is overwhelmingly warm-brown dominated (top 40 results are nearly all variations of rust/leather). No cool grey or strong accent neons surface in the pixel counts because per-character accents are tiny details. The picked palette **anchors UI in the dominant earth tones** (so panels feel native to the art) **and explicitly adds the project-rules-prescribed neon accents** (since UI buttons / focus states need them).

### Base (5 earth tones, sampled from top ranks)

| Name | Hex | From | Use |
|---|---|---|---|
| `RUST_PRIMARY` | `#a05020` | rank 1 (5.49%) | dominant warm — main hue for borders / highlights |
| `LEATHER_DARK` | `#302010` | rank 5 (2.84%) | dark structural — outlines, deep panel bg |
| `SAND_LIGHT` | `#e0d0a0` | rank 30 (0.97%) | light highlight — text on dark, icon shine |
| `WARM_TAN` | `#b08050` | rank 17 (1.47%) | mid-warm — secondary panel / inactive button |
| `DUSTY_TAUPE` | `#605040` | rank 40 (0.72%) | neutral mid — separator lines / dim chrome |

### Accent (3 neon, from project-rules.md §1 prescription)

| Name | Hex | Use |
|---|---|---|
| `ACCENT_NEON_BLUE` | `#3bc7eb` | primary highlight (hover edge, current-node ring) |
| `ACCENT_NEON_GREEN` | `#8ce04a` | secondary (heal, positive feedback, toxic) |
| `ACCENT_DANGER` | `#e07020` | hits, warnings, attack intent (sampled rank 32) |

### UI neutrals (3 chrome colors)

| Name | Hex | Use |
|---|---|---|
| `PANEL_BG_DARK` | `#1a0e08` | darkest panel bg (modal backdrop, inspect overlay) |
| `PANEL_BG` | `#2a1a10` | standard panel bg |
| `PANEL_BORDER` | `#6b3a1f` | warm border (slightly darker than RUST_PRIMARY) |
| `TEXT_MAIN` | `#f0d8a8` | high-contrast text on dark |
| `TEXT_SECONDARY` | `#b08060` | dimmer text / subtitle |
| `SHADOW_COLOR` | `#00000042` (alpha 0.26) | drop shadows |

**Total: 14 named colors.** Copy these into `run_system/ui/theme/wasteland_theme.gd` (renamed from `wasteland_cartoon_theme.gd`).
