# Asset Spec — Ornate framed-metal UI kit (map HUD)

**Owner:** Codex (ADR-0005). **Status:** Requested — the code already lays out the
new bigger framed HUD + map using the EXISTING generic 9-slice panels/buttons as
placeholders. These deliverables replace the placeholders with the heavier
"ornate riveted metal" look from the owner's concept.

## Context

The map top HUD (`run_system/ui/run_top_bar.gd`) was enlarged and restructured to
a framed layout: hero-portrait badge (far left) → big HP bar + thin XP bar →
gold chip → act/floor chip → Deck / Character / Settings buttons → relic shelf.
It currently frames everything with `wasteland_theme.panel_textured()` /
`button_textured()` (generic rusty 9-slice). The map paths/legend
(`map_renderer.gd`) were restyled to glowing cyan solid lines + a dark
cyan-bordered legend. The concept calls for richer, ornate metal frames.

All assets: **locked Offbeat Adult Sci-Fi Cartoon Wasteland style** — thick dark
cartoon outline, 2–3 value cel shading, dented grey-green/brass metal with
rivets and bevels, warm dusty palette, one or two cyan/orange accent glows, low
texture noise, **transparent background**, **no text/numbers/labels baked in**.
Use the mandatory prompt anchor in `docs/PRD.md`.

## Deliverables

### 1. HUD panel 9-slice — `battle_scene/assets/images/ui/panel_hud.png`
A wide ornate metal plaque for the top-bar background and the framed chips:
riveted corners, beveled edge, dark interior. 9-slice safe corners (~20px).
Wire: a new `wasteland_theme.panel_textured("hud")` variant, used by
`run_top_bar` for the main bar bg + `_make_framed_chip` styleboxes.

### 2. Hero-portrait frame — `battle_scene/assets/images/ui/portrait_frame.png`
A **square** (deliver 128×128, rendered ~84px) ornate metal badge frame with a
transparent center window (the hero sprite shows through behind it). Riveted,
beveled, slight cyan accent. Wire: overlay it on top of the `_portrait_texture`
in `run_top_bar._build()`.

### 3. Button 9-slice (ornate) — `battle_scene/assets/images/ui/button_hud_{normal,hover,pressed}.png`
Heavier framed metal buttons for the Deck / Character / Settings icon buttons
(and optionally the START / "查看卡组" buttons). Square-ish, ~52px. Wire:
optional `button_textured("hud_*")` variants.

### 4. Legend panel frame — `run_system/assets/images/map/legend_frame.png` (optional)
A dark riveted-metal 9-slice for the map legend panel (currently a drawn dark
rect with a cyan border). If delivered, `map_renderer._draw_legend` can blit it
instead of `draw_rect`. Lower priority — the drawn version is acceptable.

### 5. Map node medallions (optional, future) — `run_system/assets/images/map/nodes/base_ring.png`
A stone/metal base ring the node icons sit on (the concept shows each icon on a
raised disc). Lower priority; current node icons render fine without it.

## Notes
- Sizes are output contracts only; the art direction does not depend on them.
- After delivery, the wiring is small (add a theme variant + point the texture at
  the new path). Ping the code side or follow the "Wire" note per item.
- Do NOT bake any numbers/labels into these frames (same mistake as the currency
  icons — see `docs/asset-spec-currency-icons.md`).
