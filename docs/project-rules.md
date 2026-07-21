# Project Rules

**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Last Updated:** 2026-07-19

---

## 0. Documentation Source of Truth

All first-party project documentation lives in `docs/`. The root `AGENTS.md` is
the concise agent entry point requested by the project owner; it must point back
to these canonical documents rather than inventing a separate style contract.

- `docs/PRD.md` defines product scope, gameplay systems, roadmap, and known tech debt.
- `docs/PROJECT_STRUCTURE.md` maps the codebase, scenes, data files, and assets.
- `docs/project-rules.md` defines non-negotiable art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved style contract, in-game visual exemplars, and prompt anchor.

Do not reintroduce root-level local workflow docs such as `skills/`; shared project process belongs in this folder. `AGENTS.md` is the only root-level instruction exception.

---

## 1. Art Style - Original 2D American-Comic Sci-Fi Western (Non-Negotiable)

All visual assets in this project **must** follow the approved **original 2D American-comic sci-fi western** direction in `docs/art-style-reference.md`: clean dark outlines, large readable shapes, sparse interior linework, offbeat salvage-tech silhouettes, restrained bright accents, and broad cel shading. Persistent UI follows the lightweight UI07 language rather than rendered-metal or dark-fantasy chrome.

Do not use old project reference images as global style references. `docs/art/cowboy-bill-character-sheet-reference.png` may be used only to preserve Cowboy Bill's identity markers. Designs must stay original and must not copy named show characters, logos, exact scene layouts, franchise-specific props, embedded text, labels, speech bubbles, or UI framing.

The approved production exemplars are:

- `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`
- `battle_scene/assets/images/heroes/cowboy_bill/idle/`
- `battle_scene/assets/images/heroes/cowboy_bill/attack/`
- `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`
- `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`
- `battle_scene/assets/images/cards/player/strike.png` as the first approved controlled-detail card-art sample. Other existing player card illustrations are legacy production assets pending the same style pass and must not be used as style references.
- `docs/art/previews/base_building_forge_ui_dismantle_simple_comic_20260707.png` for persistent UI screen style

### Visual Rules

- **Resolution policy:** Frame sizes are technical output requirements only. A 128x128, 192x192, 256x256, 512x320, or 1920x1080 target is a file-size contract, not a style constraint.
- **Silhouettes:** Exaggerated and immediately readable. Oversized hats, cylindrical robot heads, chunky boots, lanky mechanical limbs, patched capes, bulbous lenses, crooked antennas, rubbery alien shapes, bulky salvaged weapons, hoses, and improvised gadgets are encouraged.
- **Materials:** Simplified dusty leather, red cloth scarf, brass cuffs, dented grey-green metal, patched fabric, rubber hoses, glass lenses, exposed springs, toxic sludge, glowing canisters, and flat alien terrain.
- **Color palette:** Dusty tan and warm brown base colors, muted red cloth, grey-green metal, pale desert sand, sickly toxic green, cyan plasma, and warm orange glows.
- **Accent color:** Use one or two small high-contrast glowing accents per character, item, or UI icon. Toxic green, cyan, and warm orange are the main glow colors.
- **Detail target:** Use the visual language of a Rick-and-Morty-style adult sci-fi TV cartoon: confident wobbly 2D linework, rubbery anatomy, off-kilter proportions, strange comedy silhouettes, flat cel colors, and controlled medium-low detail. Include a few purposeful dents, seams, patches, crooked joints, cables, or alien background marks so the world feels weird and lived-in. Do not flatten the work into clean corporate vector art, preschool illustration, or generic children's-book minimalism. Never copy franchise characters, props, locations, or exact designs.
- **Outlines:** Thick black or very dark hand-drawn cartoon outlines. Keep interior contour lines to the minimum required to explain the form. Do not use thin realistic hairlines, sketchy concept-art hatching, dense panel seams, or interior scratches.
- **Shading:** Simple two-to-three value cel shading with broad shadow shapes. Flat fill plus one broad shadow is preferred. Avoid painterly rendering, photorealism, gritty texture, noisy grunge, gradients as material rendering, dithering, and dense material detail.
- **Background:** Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI, text, labels, or characters baked in. Background centers must stay low-detail and readable behind gameplay.
- **Card illustrations:** Player card art must be `512x320` landscape PNGs. Use one primary action, one clear subject and at most one target; build the scene from three-to-seven large flat background shapes plus sparse ground/alien marks. Small paired action accents such as one muzzle flash and one impact star are allowed. Add only purposeful character detail—several dents, seams, patches, crooked joints, cables, or odd facial/eye marks—not texture noise. No dense rocks, debris clouds, scratch fields, rivet fields, material texture, hatching, cinematic concept-art lighting, or realistic mechanical panel detail. They are illustrations only and must not bake in card borders, cost badges, titles, rarity labels, type labels, description boxes, speech bubbles, UI, or text.
- **UI icons:** Small UI components and combat intent icons must prioritize simple readability over themed detail. Attack is a simple red sword, block is a simple blue shield, buff is a simple green arrow/glow, and charge is a simple orange warning mark. Avoid skulls, character faces, clutter, and tiny salvage decoration in these icons.
- **UI screens:** Base, shop, forge, clinic, market, outpost, inventory, and modal screens use the simple line-art 2D American comic / TV-animation UI direction anchored by `docs/art/previews/base_building_forge_ui_dismantle_simple_comic_20260707.png`: lightweight borders, flat color blocks, sparse panel lines, clear button hierarchy, and minimal material rendering. The shared `run_system/ui/run_top_bar.gd` remains visible and unchanged on every in-run screen (map, battle, event, rest, card upgrade, deck, reward, and shop). Interactive page content starts below the component's full `BAR_HEIGHT`; scene art may continue behind the transparent relic shelf from `PAGE_ART_TOP`. Pages must never hide, duplicate, or paint over the run top bar. Card previews show only the card in their normal state. Their surrounding outline is an interaction highlight that appears on hover/focus and disappears immediately afterward; it must never be a permanent decorative frame or large empty container. Avoid thick metal frames, bulky corner plates, rivet fields, dense scratches, heavy bevels, dark fantasy ornament, and Diablo-like rendered-metal UI.

### Character Anchors

- **Style standard:** `docs/art-style-reference.md` is the active global style contract. The approved in-game exemplars listed above are the practical visual yardstick. Old reference images are not global style anchors.
- **Cowboy Bill:** robot cowboy hero, exactly one large orange camera eye, cylindrical robot head, oversized hat with star badge, red scarf, patched duster/poncho, chunky boots, salvaged revolver, faces right. Preserve identity from the Bill sheet, but render him with the active flatter sci-fi cartoon language.
- **Enemies:** original junk-tech western robots, mutants, drones, creatures, or wasteland devices; enemies face left and must share the active flat sci-fi cartoon silhouette language.

### Mandatory Prompt Anchor

Every generated asset prompt must preserve this wording unless the asset type makes a clause impossible:

```text
original simple flat 2D American-comic sci-fi western TV-cartoon game art,
matching the approved in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png, battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and run_system/assets/images/map/wasteland_route_map_pixel_bg.png,
Rick-and-Morty-style adult sci-fi TV-animation visual language without copied designs, confident wobbly dark cartoon outlines, rubbery anatomy, off-kilter proportions, large flat shape blocks, controlled purposeful interior lines, broad two-to-three-value cel shading,
weird sci-fi western wasteland, rubbery alien desert shapes, absurd salvage-tech silhouettes, dusty leather, brass, dented grey-green robot metal, patched red cloth, hoses, antennas, odd gadgets,
bright toxic green, cyan, and warm orange glow accents used sparingly,
clean game-ready edges, immediately readable silhouettes, controlled medium-low detail with a few purposeful dents, seams, patches, crooked joints or cables, no corporate vector smoothness, no preschool minimalism, no texture noise, no hatching, no scratch fields, no dense mechanical panel lines,
no text, no labels, no UI frame, no logo, no copied franchise characters or props, no exact scene copies
```

For combat unit sheets, also include:

```text
side view full body, shared baseline, consistent scale, hero faces right or enemy faces left,
for Cowboy Bill and hero combat sprites use 8 idle frames plus 8 attack frames when generated,
for standard enemies use 4 attack frames by default,
enemy 4-frame attack structure: rest or wind-up -> one hit -> recoil -> return/rest,
the attack must hit exactly once; no repeated strikes, no repeated hit poses, no multi-swing loops,
idle is a seamless subtle loop, attack is a one-shot readable wind-up / fire / recoil / recovery sequence,
contained inside each frame with safe margins
```

### Prohibited

- No old visual reference image as a global style source.
- No direct copies of copyrighted characters, named show characters, logos, exact show-specific designs, franchise-specific props, or scene layouts.
- No clean, shiny, futuristic-clean, realistic military, or glossy hard-surface concept-art aesthetics.
- No realistic shading, photorealistic lighting, dense hatching, noisy grunge, or painterly over-rendering.
- No previous art-reference family, pixel-art anchor, painterly rendered anchor, or generic cartoon reference.
- No prompt language that treats file dimensions as the art style. Use the active original 2D American-comic anchor instead of earlier anchors unless the owner explicitly asks for a one-off different style.
- No dense noise, tiny repeated debris, cluttered map centers, or over-rendering that hides the cartoon silhouette.
- No assets that do not visually fit the same original 2D American-comic sci-fi western world.

---

## 2. Asset Generation - Production Pipeline

All final in-project visual assets must be PNG art that follows the original 2D American-comic rules above. Source generation can use the available image-generation pipeline, but generated sheets must be post-processed into transparent or scene-ready PNGs before being referenced by Godot.

### Required Outputs

| Asset Type | Output |
|---|---|
| Character / enemy animation | Transparent PNG frames in the entity subfolder |
| Card illustration | PNG card art referenced by card JSON |
| Battle / map background | PNG background art with no UI or characters baked in |
| UI icon / FX | Transparent PNG icon or sprite frame |

### Prompt Requirements

- Preserve the exact original 2D American-comic language from section 1 and `docs/art-style-reference.md`.
- Match the approved in-game exemplars before matching any written description.
- Prefer side-view full-body sprites for combat units.
- Final enemy frames must face left toward the player. Do not rely on a global runtime flip to correct mixed source orientations.
- Hero frames must face right toward enemies.
- Keep animation sheets on a solid `#FF00FF` background for chroma-key cleanup.
- Keep card and background art free of text, logos, UI labels, and baked-in characters unless the asset is specifically a character illustration.
- Keep player card illustrations at `512x320` unless the card scene layout is intentionally changed at the same time.

---

## 3. Sprite Pipeline

Follow this pipeline for every new character or enemy:

1. Generate a contained sheet - same character, same scale, solid `#FF00FF` background.
2. Post-process frames - chroma-key cleanup, split frames, align to a shared baseline.
3. Verify PNG output - confirm transparent PNG frames, consistent dimensions, and correct facing direction.
4. Save to project - place in the correct per-entity subfolder (see section 4 below).
5. Isolate intermediates - raw sheets may stay in a `generated_sheet/` folder only if they match the current animation contract; gameplay must reference only final PNGs.
6. Wire in Godot - use data-driven IDs where available; character systems load frames at runtime.

---

## 4. Asset Folder Structure (Expandable - Must Follow Exactly)

Every entity type gets its **own named subfolder**, and within that, each animation lives in its own per-animation subfolder (`idle/`, `attack/`, optional `charge/`). No loose animation PNGs at the entity root. Heroes may define looping `idle/` animation assets; enemies may still use `attack_0` as their static rest pose when no separate idle exists.

```text
battle_scene/assets/images/
|-- enemies/
|   |-- generate_enemy.ps1        <- shared generation script for ALL enemies
|   |-- trash_robot/              <- one subfolder per enemy sprite_id
|   |   |-- attack/
|   |   |   |-- trash_robot_attack_0.png
|   |   |   |-- trash_robot_attack_1.png
|   |   |   |-- trash_robot_attack_2.png
|   |   |   `-- trash_robot_attack_3.png
|   |-- junkyard_tyrant/
|   |   `-- attack/               (4 frames)
|   `-- wasteland_robber/         <- future enemy, same pattern
|       `-- ...
|-- heroes/
|   `-- {hero_id}/                <- one subfolder per hero
|       |-- idle/                 (8 frames for Cowboy Bill)
|       |-- attack/               (8 frames for Cowboy Bill)
|       `-- {hero_id}_portrait.png
|-- cards/
|   `-- player/                   <- card art, referenced by front_image in JSON
`-- backgrounds/                  <- battle scene backgrounds
```

### Rules

- **One subfolder per entity** - never put two enemies' frames in the same folder.
- **Subfolder name = `sprite_id`** - must match exactly what is in the enemy JSON.
- **Animation frames go in per-animation subfolders** - `idle/` and `attack/`; add optional future animation folders only when runtime actually plays them.
- **Hero idle assets are allowed** - Cowboy Bill uses `idle/` as the static and looping rest animation. Enemies may still use `attack_0` as the static rest pose unless they are explicitly regenerated with idle frames.
- **One-off images stay at the entity root** - portraits and single static images do not need animation subfolders.
- **No loose animation PNGs at the parent `/enemies/` folder or entity root** - always use a named animation subfolder.
- **Generation script lives inside the entity subfolder** it generates art for when the script is entity-specific; shared scripts may live at the asset category root.
- **Delete disposable resize intermediates** before committing, such as `_ref.png` and `_ref_64.png`.
- **Godot `.import` files stay** - they are auto-generated and must not be manually edited.

---

## 5. Naming Conventions

| Asset | Pattern | Location | Example |
|---|---|---|---|
| Animation frame | `{sprite_id}_{anim}_{n}.png` | `enemies/{sprite_id}/{anim}/` | `enemies/trash_robot/attack/trash_robot_attack_0.png` |
| Generation script | `generate_enemy.ps1` | `enemies/` or entity folder | `enemies/generate_enemy.ps1` |
| Enemy JSON | `{enemy_id}.json` | `card_info/enemy/` | `robot_grunt.json` |
| Hero JSON | `{hero_id}.json` | `card_info/hero/` | `warrior.json` |
| Card JSON | `{card_id}.json` | `card_info/player/` | `strike.json` |
| Equipment JSON | `{item_id}.json` | `card_info/equipment/` | `scrap_gauntlet.json` |
| Relic JSON | `{relic_id}.json` | `run_system/data/relics/` | `cracked_battery.json` |

---

## 6. Code Architecture Rules

### General

- **Data-driven everything** - new enemies, cards, equipment, and relics require only JSON unless a new shared behavior is needed.
- **No art logic in `.tscn` files** - all sprite loading happens in GDScript at runtime.
- **Factory pattern** - use static `create(id)` functions where the codebase already exposes them.
- **Fallback gracefully** - if a texture or JSON is missing, `push_warning()` and continue; never crash.

### Enemy Sprites

- `EnemyEntity.ENEMIES_DIR` = `"res://battle_scene/assets/images/enemies/"`
- Frames resolve as: `{ENEMIES_DIR}{sprite_id}/{anim}/{sprite_id}_{anim}_{n}.png`
- Enemy PNGs are stored already facing left toward the player; `EnemyEntity` must not apply a blanket horizontal flip.
- To add a new enemy: create subfolder + JSON. Zero GDScript changes should be required unless introducing new shared behavior.

### Adding New Content - Checklist

| Content | Steps |
|---|---|
| **New enemy** | 1. Create `enemies/{sprite_id}/` with frames. 2. Add `card_info/enemy/{id}.json` with `sprite_id`. |
| **New card** | 1. Add `card_info/player/{id}.json` with `effects[]`. 2. Add card art under `assets/images/cards/player/`. |
| **New equipment** | 1. Add `card_info/equipment/{id}.json` with `bonuses`. |
| **New relic** | 1. Add `run_system/data/relics/{id}.json`. 2. Add a shared trigger in `battle_scene/relic_effect_system.gd` only if existing triggers are insufficient. |
| **New hero** | 1. Add hero JSON. 2. Add hero sprite under `heroes/{hero_id}/`. |

### Content Catalog — Design-First Workflow (Non-Negotiable)

The browsable tables under `docs/catalog_html/` (cards / relics / equipment / enemies /
gems / tools / events / affixes / keywords) are the reference for *what content exists*.
They are **generated** from the JSON data + translation CSVs + `affix_pool.gd` by
`scripts/gen_catalog_html.py`. Treat the catalog as the design surface, and work in this
order for ANY content add / remove / retune:

1. **Design in the catalog first.** Before writing data, open the relevant catalog page
   and plan the change against the full existing set — naming, cost/rarity/tier numbers,
   power curve, and consistency with sibling content.
2. **Then implement in the game data** — the JSON (+ translation CSVs + any wiring per the
   checklist above).
3. **Regenerate and verify.** Run `python scripts/gen_catalog_html.py` and confirm the new
   content appears as intended. **A content change is not "done" until the catalog matches
   the game data** and the smoke gate passes.

**Never hand-edit the HTML** — a regen overwrites it. If a content type has no catalog page
yet, add a `build_*()` for it in `gen_catalog_html.py` (plus a `nav()` link) rather than
leaving it untracked. `docs/catalog_html/index.html` is the **combined single-page view**
(left-side tabs over every category) — the handiest surface for balance/number passes; the
per-category pages are kept too.

---

## 7. Prohibited

- Do not commit API keys to version control (`mcp_config.json` must be gitignored).
- Do not use ColorRect or procedural geometry as final art; temporary debug placeholders only.
- Do not use non-PNG formats in Godot (convert WebP/JPEG to PNG before importing).
- Do not hardcode sprite paths in `.tscn` files; always load programmatically.
- Do not put multiple enemies' assets in the same folder.
- Do not leave unused files in the project; delete disposable generation intermediates before committing.
- Do not add card-specific or enemy-specific logic to shared systems; all variance goes in JSON where possible.
- Do not add root-level local `skills/` workflow docs; keep project documentation centralized in `docs/`.
