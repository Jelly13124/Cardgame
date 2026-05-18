# Project Rules

**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Last Updated:** 2026-04-09

---

## 0. Documentation Source of Truth

All first-party project documentation lives in `docs/`.

- `docs/PRD.md` defines product scope, gameplay systems, roadmap, and known tech debt.
- `docs/PROJECT_STRUCTURE.md` maps the codebase, scenes, data files, and assets.
- `docs/project-rules.md` defines non-negotiable art, asset, naming, and architecture rules.

Do not reintroduce root-level local workflow docs such as `skills/`; shared project process belongs in this folder.

---

## 1. Art Style — Wasteland Punk Pixel Art (Non-Negotiable)

All visual assets in this project **must** be pixel art in the **Wasteland Punk** aesthetic.

### What is Wasteland Punk?
A post-apocalyptic scrapyard universe — think Mad Max meets Fallout, rendered in bold pixel art:
- **Silhouettes:** Bold, readable at 64px. One glance = instant recognition.
- **Materials:** Scrap metal, duct tape, rubber, chains, cracked glass, worn leather, exposed wiring — everything is salvaged, dented, and corroded. Nothing is clean or new.
- **Color palette:** Earth tone base (rusted orange, sandy brown, dusty grey, faded olive) + **one neon accent per character** (glowing eyes, reactor core, toxic liquid, electric sparks).
- **Outlines:** Bold single-color black outlines — confident pixel weight.
- **Shading:** Cel-shaded / flat — not photorealistic.
- **Background:** Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI baked in.

### Mandatory Prompt Suffix
**Every asset description MUST end with this exact suffix** to ensure style consistency:
```
wasteland punk style, post-apocalyptic scrap aesthetic, rusted metal and salvaged parts,
single color bold black pixel art outlines, cel-shaded flat colors, earth tone palette
with one neon accent color, transparent background, side view, full body, pixel art
```

### Prohibited
- ❌ No clean, shiny, or futuristic-clean aesthetics
- ❌ No Rick and Morty characters (tone is kept, characters are not)
- ❌ No realistic shading or photorealistic lighting
- ❌ No assets that don't visually fit the same scrapyard world

---

## 2. Asset Generation - Production Pipeline

All final in-project visual assets must be PNG pixel art that follows the Wasteland Punk rules above. Source generation can use the available image-generation pipeline, but generated sheets must be post-processed into transparent or scene-ready PNGs before being referenced by Godot.

### Required Outputs
| Asset Type | Output |
|---|---|
| Character / enemy animation | Transparent PNG frames in the entity subfolder |
| Card illustration | PNG card art referenced by card JSON |
| Battle / map background | PNG background art with no UI or characters baked in |
| UI icon / FX | Transparent PNG icon or sprite frame |

### Prompt Requirements
- Preserve the exact Wasteland Punk style language from section 1.
- Prefer side-view full-body sprites for combat units.
- Keep animation sheets on a solid `#FF00FF` background for chroma-key cleanup.
- Keep card and background art free of text, logos, and UI labels.

---

## 3. Sprite Pipeline

Follow this pipeline for every new character or enemy:

1. Generate a contained sheet - same character, same scale, solid `#FF00FF` background.
2. Post-process frames - chroma-key cleanup, split frames, align to a shared baseline.
3. Verify PNG output - confirm transparent PNG frames and consistent dimensions.
4. Save to project - place in the correct per-entity subfolder (see section 4 below).
5. Isolate intermediates - raw sheets may stay in a `generated_sheet/` folder; gameplay must reference only final PNGs.
6. Wire in Godot - use data-driven IDs where available; character systems load frames at runtime.

---

## 4. Asset Folder Structure (Expandable — Must Follow Exactly)

Every entity type gets its **own named subfolder**. No loose files in parent folders.

```
battle_scene/assets/images/
├── enemies/
│   ├── generate_enemy.ps1        ← shared generation script for ALL enemies
│   ├── trash_robot/              ← one subfolder per enemy sprite_id
│   │   ├── trash_robot_idle_0.png
│   │   ├── trash_robot_idle_1.png
│   │   ├── trash_robot_idle_2.png
│   │   ├── trash_robot_idle_3.png
│   │   ├── trash_robot_attack_0.png
│   │   ├── trash_robot_attack_1.png
│   │   ├── trash_robot_attack_2.png
│   │   └── trash_robot_attack_3.png
│   └── wasteland_robber/         ← future enemy (same pattern)
│       └── ...
├── heroes/
│   └── {hero_id}/                ← one subfolder per hero (when art is ready)
│       └── ...
├── cards/
│   └── player/                   ← card art, referenced by front_image in JSON
└── backgrounds/                  ← battle scene backgrounds
```

### Rules
- **One subfolder per entity** — never put two enemies' frames in the same folder
- **Subfolder name = `sprite_id`** — must match exactly what's in the enemy's JSON
- **No loose PNGs in the parent `/enemies/` folder** — always inside a named subfolder
- **Generation script lives inside the entity subfolder** it generates art for
- **Delete all intermediate pipeline files** before committing:
  - `_ref.png` (96×96 reference)
  - `_ref_64.png` (64×64 resize intermediate)
- **Godot `.import` files stay** — they are auto-generated and must not be manually edited

---

## 5. Naming Conventions

| Asset | Pattern | Location | Example |
|---|---|---|---|
| Animation frame | `{sprite_id}_{anim}_{n}.png` | `enemies/{sprite_id}/` | `trash_robot_idle_0.png` |
| Generation script | `generate_enemy.ps1` | `enemies/` (shared root) | `enemies/generate_enemy.ps1` |
| Enemy JSON | `{enemy_id}.json` | `card_info/enemy/` | `robot_grunt.json` |
| Hero JSON | `{hero_id}.json` | `card_info/hero/` | `warrior.json` |
| Card JSON | `{card_id}.json` | `card_info/player/` | `strike.json` |
| Equipment JSON | `{item_id}.json` | `card_info/equipment/` | `scrap_gauntlet.json` |
| Relic JSON | `{relic_id}.json` | `run_system/data/relics/` | `cracked_battery.json` |

---

## 6. Code Architecture Rules

### General
- **Data-driven everything** — new enemies, cards, equipment, and relics require only JSON; no GDScript changes.
- **No art logic in `.tscn` files** — all sprite loading happens in GDScript at runtime.
- **Factory pattern** — use static `create(id)` functions (e.g. `EnemyEntity.create("robot_grunt")`).
- **Fallback gracefully** — if a texture or JSON is missing, `push_warning()` and continue; never crash.

### Enemy Sprites
- `EnemyEntity.ENEMIES_DIR` = `"res://battle_scene/assets/images/enemies/"`
- Frames resolved as: `{ENEMIES_DIR}{sprite_id}/{sprite_id}_{anim}_{n}.png`
- To add a new enemy: create subfolder + JSON. Zero GDScript changes required.

### Adding New Content — Checklist
| Content | Steps |
|---|---|
| **New enemy** | 1. Create `enemies/{sprite_id}/` with frames 2. Add `card_info/enemy/{id}.json` with `sprite_id` field |
| **New card** | 1. Add `card_info/player/{id}.json` with `effects[]` array |
| **New equipment** | 1. Add `card_info/equipment/{id}.json` with `bonuses` dict |
| **New relic** | 1. Add `run_system/data/relics/{id}.json` 2. Add a shared trigger in `battle_scene/relic_effect_system.gd` only if existing triggers are insufficient |
| **New hero** | 1. Add hero JSON 2. Add hero sprite under `heroes/{hero_id}/` |

---

## 7. Prohibited

- ❌ Do not commit API keys to version control (`mcp_config.json` must be gitignored)
- ❌ Do not use ColorRect or procedural geometry as final art — temporary debug placeholders only
- ❌ Do not use non-PNG formats in Godot (convert WebP/JPEG → PNG before importing)
- ❌ Do not hardcode sprite paths in `.tscn` files — always load programmatically
- ❌ Do not put multiple enemies' assets in the same folder
- ❌ Do not leave unused files in the project (delete `_ref.png`, `_ref_64.png` after generation)
- ❌ Do not add card-specific or enemy-specific logic to shared systems — all variance goes in JSON
- ❌ Do not add root-level local `skills/` workflow docs; keep project documentation centralized in `docs/`
