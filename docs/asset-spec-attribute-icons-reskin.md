# Asset Spec — Attribute icon re-skin (Luck / Intelligence / Constitution)

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `**/assets/images/**`).
**Status:** Requested 2026-07-01.
**Companion:** `docs/asset-spec-ui-icons.md` (equipment-slot icons, same size/treatment).

## Context

The 5 five-attribute icons live at `battle_scene/assets/images/ui/attributes/*.png`
(**64×64**, flat cartoon, one clear shape + one main color + thick dark outline,
transparent background). Three are being re-skinned to new subjects/colors so all five
read as a distinct-color set:

| Attribute | Current icon | New icon | Main color |
|---|---|---|---|
| Strength (力量) | orange muscle arm | *unchanged* | orange |
| Charm (魅力) | pink star face | *unchanged* | pink |
| **Luck (幸运)** | gold horseshoe + star | **four-leaf clover** | **green** |
| **Intelligence (智力)** | purple gear-brain | **brain** (drop the gear) | **blue** |
| **Constitution (体质)** | blue chest plate | **shield** | **gold / brass** |

Colors are chosen so the five stay mutually distinct: orange / pink / green / blue / gold.

## Deliverables — 3 PNGs, **64×64**, transparent, overwrite in place

| File (overwrite) | Subject | Main color |
|---|---|---|
| `battle_scene/assets/images/ui/attributes/luck.png` | a single bright four-leaf clover | grass green |
| `battle_scene/assets/images/ui/attributes/intelligence.png` | a single stylized brain | electric blue |
| `battle_scene/assets/images/ui/attributes/constitution.png` | a single sturdy shield | brass gold |

## Hard requirements

- **PNG with alpha, transparent background**, subject centered, even padding, reads at ~30–44px.
- **ONE clear silhouette, ONE main color** + the thick dark cartoon outline; 2–3 value cel
  shading; low texture noise; at most one small bright accent glow.
- **NO text / number / letter / UI frame / background** baked in.
- Style = the locked **Offbeat Adult Sci-Fi Cartoon Wasteland** (match Cowboy Bill + the
  existing `ui/attributes/strength.png` & `charm.png` treatment). 64×64 is an output
  contract only — never pixel art.

## Codex prompts (one per icon)

Each prepends the mandatory anchor from `docs/art-style-reference.md` (§Prompt Anchor) +
`single game UI icon, one clear silhouette, no text, no number, no label, no UI frame,
transparent background, centered, 64x64`. Subject lines:

- **luck.png** — `a single bright grass-green four-leaf clover, four rounded heart-shaped
  leaves, thick clean dark cartoon outline, broad flat cel shading, one small warm
  highlight glint, cheerful lucky charm, readable at small size`
- **intelligence.png** — `a single stylized cartoon brain, electric blue, simple readable
  gyrus curves, no gear, thick clean dark cartoon outline, broad flat cel shading, one
  soft cyan glow accent, readable at small size`
- **constitution.png** — `a single sturdy heraldic shield, brass-gold metal, simple bold
  shape with one central rivet or bolt, thick clean dark cartoon outline, broad flat cel
  shading, one warm highlight, tough and reliable, readable at small size`

## Wiring after delivery

**No code change** — the icons load by attribute name from
`ui/attributes/<attr>.png`, so overwriting the three files is enough.

## Review gate

Drop the 3 samples to `docs/art/previews/attr_icons_<date>/` for approval before
overwriting the live `ui/attributes/` files — same discipline as the other art.
