# Project Rules

**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Last Updated:** 2026-05-19

---

## 0. Documentation Source of Truth

All first-party project documentation lives in `docs/`.

- `docs/PRD.md` defines product scope, gameplay systems, roadmap, and known tech debt.
- `docs/PROJECT_STRUCTURE.md` maps the codebase, scenes, data files, and assets.
- `docs/project-rules.md` defines non-negotiable art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved visual reference and prompt anchor.

Do not reintroduce root-level local workflow docs such as `skills/`; shared project process belongs in this folder.

---

## 1. Art Style - Hardcore Wasteland Sprite Art (Non-Negotiable)

All visual assets in this project **must** follow the approved **Hardcore Wasteland Sprite Art** direction in `docs/art-style-reference.md`. (Renamed from "Hardcore 128 Pixel Wasteland Art" — see ADR-0011.)

The ground-truth reference is Cowboy Bill (`battle_scene/assets/images/heroes/cowboy_bill/`): a one-eyed robot cowboy as a **detailed, fully-rendered sprite** — bold dark outlines, rusted scrap materials, warm leather/brass colors, rich highlight-mid-shadow shading, and one small glowing neon accent. The look is rendered sprite art, NOT lo-fi pixel art. When wording conflicts with how Bill looks, Bill wins.

### Visual Rules

- **Native resolution:** Combat heroes and standard enemies are authored at 128×128 (192×192 bosses) unless a spec marks a larger scale. This is the in-game display/detail budget — NOT a lo-fi pixel-art aesthetic; the look is a detailed fully-rendered sprite.
- **Silhouettes:** Compact, tough, battle-ready, and readable at gameplay size. One glance should identify the unit or item.
- **Materials:** Scrap metal, duct tape, bolts, dents, rubber, cracked glass, worn leather, patched cloth, and exposed wiring. Everything is salvaged and used.
- **Color palette:** Warm earth-tone base: leather brown, rust orange, dusty tan, muted olive, dark steel, faded brass, and desaturated charcoal.
- **Accent color:** One small high-contrast accent per character, item, or UI icon.
- **Outlines:** Bold dark outlines that read at gameplay size. Do not use thin realistic hairlines or pure minimalist line art.
- **Shading:** Rich, controlled shading with a clear highlight/mid/shadow read (a fully-rendered sprite). Avoid flat fills, photorealism, and noisy dithering.
- **Background:** Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI baked in.

### Character Anchors

- **Cowboy Bill:** robot cowboy hero, exactly one large central camera eye, oversized battered hat, red bandana, patched duster/poncho, chunky boots, salvaged hand cannon, faces right.
- **Trash Bot:** compact trash-collecting robot enemy, trash-bin or compactor body, camera-eye face, tiny tank treads or scrap wheels, stubby grabber arms, dents/tape/bolts, small neon light, faces left.

### Mandatory Prompt Anchor

Every generated asset prompt must preserve this wording unless the asset type makes a clause impossible:

```text
hardcore wasteland sprite art, detailed fully-rendered game sprite, bold dark outlines,
rich controlled shading with clear highlight-mid-shadow, warm rust / leather / brass / dark-steel / dusty-tan palette,
salvaged scrap metal with bolts dents tubes and cracked glass, worn leather and patched cloth,
one small glowing neon accent, authored at 128px native (192px bosses) for in-game readability,
transparent background, match the Cowboy Bill reference fidelity, not lo-fi pixel art, not flat
```

For combat unit sheets, also include:

```text
side view, full body, shared baseline, consistent scale, hero faces right or enemy faces left,
4 attack frames, attack frame 0 doubles as the static rest pose, no separate idle animation
```

### Prohibited

- No clean, shiny, or futuristic-clean aesthetics.
- No direct copies of copyrighted characters or named IP styles.
- No realistic shading, photorealistic lighting, vector art, or hard-surface concept art.
- No flat, vector, or cel-shaded output with no material texture.
- No tiny 16x16 or 32x32 lo-fi sprites for combat units.
- No dense noise or over-rendering that makes the sprite unreadable at gameplay size.
- No assets that do not visually fit the same Hardcore Wasteland Sprite Art world (match Cowboy Bill).

---

## 2. Asset Generation - Production Pipeline

All final in-project visual assets must be PNG art that follows the Hardcore Wasteland Sprite Art rules above. Source generation can use the available image-generation pipeline, but generated sheets must be post-processed into transparent or scene-ready PNGs before being referenced by Godot.

### Required Outputs

| Asset Type | Output |
|---|---|
| Character / enemy animation | Transparent PNG frames in the entity subfolder |
| Card illustration | PNG card art referenced by card JSON |
| Battle / map background | PNG background art with no UI or characters baked in |
| UI icon / FX | Transparent PNG icon or sprite frame |

### Prompt Requirements

- Preserve the exact Hardcore Wasteland Sprite Art language from section 1 and `docs/art-style-reference.md`.
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
