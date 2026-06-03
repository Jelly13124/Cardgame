# Project Rules

**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Last Updated:** 2026-06-03

---

## 0. Documentation Source of Truth

All first-party project documentation lives in `docs/`.

- `docs/PRD.md` defines product scope, gameplay systems, roadmap, and known tech debt.
- `docs/PROJECT_STRUCTURE.md` maps the codebase, scenes, data files, and assets.
- `docs/project-rules.md` defines non-negotiable art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved style contract, in-game visual exemplars, and prompt anchor.

Do not reintroduce root-level local workflow docs such as `skills/`; shared project process belongs in this folder.

---

## 1. Art Style - Offbeat Adult Sci-Fi Cartoon Wasteland (Non-Negotiable)

All visual assets in this project **must** follow the approved **Offbeat Adult Sci-Fi Cartoon Wasteland** direction in `docs/art-style-reference.md`. The target is original flat adult sci-fi western cartoon game art: clean black outlines, large simple shapes, sparse interior linework, absurd salvage-tech silhouettes, bright toxic accents, and broad cel shading.

Do not use old project reference images as global style references. `docs/art/cowboy-bill-character-sheet-reference.png` may be used only to preserve Cowboy Bill's identity markers. Designs must stay original and must not copy named show characters, logos, exact scene layouts, franchise-specific props, embedded text, labels, speech bubbles, or UI framing.

The approved production exemplars are:

- `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`
- `battle_scene/assets/images/heroes/cowboy_bill/idle/`
- `battle_scene/assets/images/heroes/cowboy_bill/attack/`
- `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`
- `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`
- `battle_scene/assets/images/cards/player/*.png`

### Visual Rules

- **Resolution policy:** Frame sizes are technical output requirements only. A 128x128, 192x192, 256x256, 512x320, or 1920x1080 target is a file-size contract, not a style constraint.
- **Silhouettes:** Exaggerated and immediately readable. Oversized hats, cylindrical robot heads, chunky boots, lanky mechanical limbs, patched capes, bulbous lenses, crooked antennas, rubbery alien shapes, bulky salvaged weapons, hoses, and improvised gadgets are encouraged.
- **Materials:** Simplified dusty leather, red cloth scarf, brass cuffs, dented grey-green metal, patched fabric, rubber hoses, glass lenses, exposed springs, toxic sludge, glowing canisters, and flat alien terrain.
- **Color palette:** Dusty tan and warm brown base colors, muted red cloth, grey-green metal, pale desert sand, sickly toxic green, cyan plasma, and warm orange glows.
- **Accent color:** Use one or two small high-contrast glowing accents per character, item, or UI icon. Toxic green, cyan, and warm orange are the main glow colors.
- **Outlines:** Thick black or very dark hand-drawn cartoon outlines. Do not use thin realistic hairlines, sketchy concept-art hatching, or dense interior scratches.
- **Shading:** Simple two-to-three value cel shading with broad shadow shapes. Avoid painterly rendering, photorealism, gritty texture, noisy grunge, dithering, and dense material detail.
- **Background:** Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI, text, labels, or characters baked in. Background centers must stay low-detail and readable behind gameplay.
- **Card illustrations:** Player card art must be `512x320` landscape PNGs. They are illustrations only and must not bake in card borders, cost badges, titles, rarity labels, type labels, description boxes, speech bubbles, UI, or text.
- **UI icons:** Small UI components and combat intent icons must prioritize simple readability over themed detail. Attack is a simple red sword, block is a simple blue shield, buff is a simple green arrow/glow, and charge is a simple orange warning mark. Avoid skulls, character faces, clutter, and tiny salvage decoration in these icons.

### Character Anchors

- **Style standard:** `docs/art-style-reference.md` is the active global style contract. The approved in-game exemplars listed above are the practical visual yardstick. Old reference images are not global style anchors.
- **Cowboy Bill:** robot cowboy hero, exactly one large orange camera eye, cylindrical robot head, oversized hat with star badge, red scarf, patched duster/poncho, chunky boots, salvaged revolver, faces right. Preserve identity from the Bill sheet, but render him with the active flatter adult sci-fi cartoon language.
- **Enemies:** original junk-tech western robots, mutants, drones, creatures, or wasteland devices; enemies face left and must share the active flat sci-fi cartoon silhouette language.

### Mandatory Prompt Anchor

Every generated asset prompt must preserve this wording unless the asset type makes a clause impossible:

```text
original Offbeat Adult Sci-Fi Cartoon Wasteland game art,
matching the approved in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png, battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and run_system/assets/images/map/wasteland_route_map_pixel_bg.png,
flat 2D adult sci-fi TV-animation look, thick clean dark cartoon outlines, large simple shape blocks, sparse interior lines, broad two-to-three value cel shading,
weird sci-fi western wasteland, rubbery alien desert shapes, absurd salvage-tech silhouettes, dusty leather, brass, dented grey-green robot metal, patched red cloth, hoses, antennas, odd gadgets,
bright toxic green, cyan, and warm orange glow accents used sparingly,
clean game-ready edges, readable silhouettes, low texture noise,
no text, no labels, no UI frame, no logo, no named show characters, no franchise-specific props, no exact scene copies
```

For combat unit sheets, also include:

```text
side view full body, shared baseline, consistent scale, hero faces right or enemy faces left,
for Cowboy Bill and hero combat sprites use 8 idle frames plus 8 attack frames when generated,
idle is a seamless subtle loop, attack is a one-shot readable wind-up / fire / recoil / recovery sequence,
contained inside each frame with safe margins
```

### Prohibited

- No old visual reference image as a global style source.
- No direct copies of copyrighted characters, named show characters, logos, exact show-specific designs, franchise-specific props, or scene layouts.
- No clean, shiny, futuristic-clean, realistic military, or glossy hard-surface concept-art aesthetics.
- No realistic shading, photorealistic lighting, dense hatching, noisy grunge, or painterly over-rendering.
- No previous art-reference family, pixel-art anchor, painterly rendered anchor, or generic cartoon reference.
- No prompt language that treats file dimensions as the art style. Use the active Offbeat Adult Sci-Fi Cartoon Wasteland anchor instead of earlier anchors unless the owner explicitly asks for a one-off different style.
- No dense noise, tiny repeated debris, cluttered map centers, or over-rendering that hides the cartoon silhouette.
- No assets that do not visually fit the same Offbeat Adult Sci-Fi Cartoon Wasteland world.

---

## 2. Asset Generation - Production Pipeline

All final in-project visual assets must be PNG art that follows the Offbeat Adult Sci-Fi Cartoon Wasteland rules above. Source generation can use the available image-generation pipeline, but generated sheets must be post-processed into transparent or scene-ready PNGs before being referenced by Godot.

### Required Outputs

| Asset Type | Output |
|---|---|
| Character / enemy animation | Transparent PNG frames in the entity subfolder |
| Card illustration | PNG card art referenced by card JSON |
| Battle / map background | PNG background art with no UI or characters baked in |
| UI icon / FX | Transparent PNG icon or sprite frame |

### Prompt Requirements

- Preserve the exact Offbeat Adult Sci-Fi Cartoon Wasteland language from section 1 and `docs/art-style-reference.md`.
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
