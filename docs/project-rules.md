# Project Rules

**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Last Updated:** 2026-05-31

---

## 0. Documentation Source of Truth

All first-party project documentation lives in `docs/`.

- `docs/PRD.md` defines product scope, gameplay systems, roadmap, and known tech debt.
- `docs/PROJECT_STRUCTURE.md` maps the codebase, scenes, data files, and assets.
- `docs/project-rules.md` defines non-negotiable art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved visual reference and prompt anchor.

Do not reintroduce root-level local workflow docs such as `skills/`; shared project process belongs in this folder.

---

## 1. Art Style - Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland (Non-Negotiable)

All visual assets in this project **must** follow the approved **Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland** direction in `docs/art-style-reference.md`. The owner's shorthand is "Rick and Morty style": broad adult sci-fi cartoon energy, rubbery outlines, flat colors, absurd proportions, and weird sci-fi comedy. Designs must stay original and must not copy named characters, exact show designs, logos, or proprietary story elements. This supersedes the old sprite-art direction; see ADR-0012.

The ground-truth reference is `docs/art/rick-morty-radiation-rat-style-reference.png`: a mutated radiation rat sheet with thick rubbery cartoon outlines, flat bright color blocks, simple cel shading, bulging expressive eyes, gross-comic proportions, dusty wasteland junk straps, and toxic-green radioactive accents. The current Cowboy Bill identity/card-scene reference is `docs/art/current-cowboy-bill-style-reference.png`. When older docs, previous sprites, or old Cowboy Bill references conflict with these references, these references win.

### Visual Rules

- **Resolution policy:** Frame sizes are technical output requirements only. A 128x128, 192x192, 256x256, or 512x320 target is a file-size contract, not a style constraint.
- **Silhouettes:** Exaggerated, asymmetrical, and immediately readable. Bulging eyes, huge teeth, warped bodies, lanky limbs, crooked antennas, glowing pustules, and awkward junk-tech proportions are encouraged.
- **Materials:** Mutant skin, patchy fur, dusty western leather, brass cuffs, dented steel, exposed springs, patched cloth, rubber hoses, cracked glass, radioactive slime, and cheap improvised sci-fi parts.
- **Color palette:** Sickly radioactive green and yellow-green accents over dusty tan, dirty pink skin, leather brown, rust, brass, dark steel, and occasional cyan or magenta.
- **Accent color:** Toxic green is the primary world accent. Use one or two small high-contrast glowing accents per character, item, or UI icon.
- **Outlines:** Thick black or very dark brown rubbery outlines. Do not use thin realistic hairlines or pure minimalist line art.
- **Shading:** Simple two-to-three value cel shading. Avoid high-detail painterly rendering, photorealism, and noisy dithering.
- **Background:** Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI baked in.

### Character Anchors

- **Style standard:** the radiation rat reference defines the current line weight, flatness, eye treatment, radioactive palette, and gross-comic silhouette language.
- **Cowboy Bill:** robot cowboy hero, exactly one large orange camera eye, oversized hat with star badge, red scarf, patched duster/poncho, chunky boots, salvaged revolver, faces right. Use `docs/art/current-cowboy-bill-style-reference.png` for his current look. Do not use older standalone Bill renders.
- **Enemies:** original junk-tech cartoon creatures, radiation mutants, drones, or robots; enemies face left and should share the new cartoon silhouette language.

### Mandatory Prompt Anchor

Every generated asset prompt must preserve this wording unless the asset type makes a clause impossible:

```text
original offbeat adult sci-fi cartoon wasteland game art, Rick-and-Morty-like broad adult sci-fi animation energy without copying named characters or exact show designs,
thick dark rubbery outlines, flat bright color blocks, simple cel shading, exaggerated asymmetrical proportions,
bulging expressive eyes, weird mutant or junk-tech silhouette, dusty western leather and brass, dented steel, exposed springs, patched cloth, radioactive slime,
one or two small toxic-green glowing accents, crisp sprite-ready edges,
solid #FF00FF magenta background for cleanup or transparent final PNG, no text, no UI frame, no logo
```

For combat unit sheets, also include:

```text
side view full body, shared baseline, consistent scale, hero faces right or enemy faces left,
4 attack frames, attack frame 0 doubles as the static rest pose, no separate idle animation,
contained inside each frame with safe margins
```

### Prohibited

- No direct copies of copyrighted characters, named show characters, logos, or exact show-specific designs.
- No clean, shiny, or futuristic-clean aesthetics.
- No realistic shading, photorealistic lighting, vector art, or hard-surface concept art.
- No high-detail painterly rendered sprites as the new target.
- No prompt language that treats file dimensions as the art style. Use the current cartoon anchor instead of earlier sprite-art anchors unless the owner explicitly asks for a one-off different style.
- No dense noise or over-rendering that hides the cartoon silhouette.
- No assets that do not visually fit the same Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland world.

---

## 2. Asset Generation - Production Pipeline

All final in-project visual assets must be PNG art that follows the Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland rules above. Source generation can use the available image-generation pipeline, but generated sheets must be post-processed into transparent or scene-ready PNGs before being referenced by Godot.

### Required Outputs

| Asset Type | Output |
|---|---|
| Character / enemy animation | Transparent PNG frames in the entity subfolder |
| Card illustration | PNG card art referenced by card JSON |
| Battle / map background | PNG background art with no UI or characters baked in |
| UI icon / FX | Transparent PNG icon or sprite frame |

### Prompt Requirements

- Preserve the exact Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland language from section 1 and `docs/art-style-reference.md`.
- Prefer side-view full-body sprites for combat units.
- Final enemy frames must face left toward the player. Do not rely on a global runtime flip to correct mixed source orientations.
- Hero frames must face right toward enemies.
- Keep animation sheets on a solid `#FF00FF` background for chroma-key cleanup.
- Keep card and background art free of text, logos, and UI labels.

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

Every entity type gets its **own named subfolder**, and within that, each animation lives in its own per-animation subfolder (`attack/`, optional `charge/`). No loose animation PNGs at the entity root. The project no longer keeps separate `idle/` animation assets; `attack_0` is the static rest pose.

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
|   |-- junkyard_tyrant/          <- boss may also have a charge/ subfolder
|   |   |-- attack/               (4 frames)
|   |   `-- charge/               (4 frames - telegraph wind-up)
|   `-- wasteland_robber/         <- future enemy, same pattern
|       `-- ...
|-- heroes/
|   `-- {hero_id}/                <- one subfolder per hero
|       |-- attack/               (4 frames)
|       `-- {hero_id}_portrait.png
|-- cards/
|   `-- player/                   <- card art, referenced by front_image in JSON
`-- backgrounds/                  <- battle scene backgrounds
```

### Rules

- **One subfolder per entity** - never put two enemies' frames in the same folder.
- **Subfolder name = `sprite_id`** - must match exactly what is in the enemy JSON.
- **Animation frames go in per-animation subfolders** - `attack/` and optional `charge/`.
- **No separate idle assets** - `attack_0` is the static rest pose for heroes and enemies.
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
