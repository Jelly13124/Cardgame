# Product Requirements Document
**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Art Style:** Wasteland Punk Pixel Art  
**Engine:** Godot 4.6  
**Last Updated:** 2026-04-09

---

## Overview

A single-player roguelite deckbuilder set in a post-apocalyptic scrapyard wasteland. Players collect cards, relics, and equipment while fighting through escalating routes toward bosses. The visual language is locked to Wasteland Punk Pixel Art: rusted scrap metal, dusty earth tones, bold black pixel outlines, and sparse neon accents.

Combat is **Slay the Spire style**: the player has a hand of cards, limited energy, and must choose each turn which cards to play to survive enemy attacks while defeating them.

Project documentation is centralized in `docs/`:
- `docs/PRD.md` is the product and systems source of truth.
- `docs/PROJECT_STRUCTURE.md` maps scenes, scripts, data, and assets.
- `docs/project-rules.md` defines art, asset, naming, and architecture rules.

---

## Core Gameplay Loop

```
Hero Select -> Floor 1 Map -> Battle -> Loot -> Map -> ... -> Boss
                                                                              ↓
                                                              Extract OR Push to Floor 2
                                                                              ↓
                                                              Floor 2 → ... → Boss
                                                                              ↓
                                                              Extract OR Push to Floor 3
                                                                              ↓
                                                              Floor 3 → Final Boss → Victory
```

1. **Hero Select** - Choose a hero archetype with a fixed starter deck and attribute spread
2. **Map** - Choose the next encounter node (normal / elite / rest site / shop / boss)
3. **Battle** - STS-style card combat
4. **Loot Reward** - Post-battle: claim gold and optionally draft 1 new card
5. **Boss Extraction Choice** _(after each boss)_ - Continue to the next floor OR extract with current loot
6. **Base Building** - Between runs, spend Core to permanently upgrade the home base

---

## Battle System

### Turn Structure
1. Player draws **3 cards** from the draw pile
2. Player plays cards spending **energy** (resets to 3 each round)
3. Player clicks **END ROUND**
4. Enemy executes its **next action** from its action pattern
5. All remaining hand cards go to the **discard pile**
6. Player's **block resets to 0**; draw pile reshuffles from discard if empty
7. Loop back to step 1

### Card Types

| Type | Play Method | Requires Target |
|---|---|---|
| **Attack** | Click card → drag targeting arrow → release on enemy | Yes (enemy) |
| **Skill** | Drag card upward into the invisible play zone | No |
| **Ability** | Drag card upward into the invisible play zone | No |

### Card Effects System (Data-Driven)
All effects are defined in card JSON via the `effects[]` array. The `CombatEngine` resolves them generically. Supported effect types:

- `deal_damage` — Single-target damage (scales with `strength`)
- `deal_damage_all` — All-enemy damage
- `gain_block` — Player block this turn (scales with `constitution`)
- `gain_strength` / `gain_constitution` / `gain_intelligence` / `gain_luck` / `gain_charm` — Permanent stat buffs
- `gain_energy` — Extra energy this turn
- `draw_cards` — Additional card draw
- `apply_status` — Apply a status effect to a target enemy
- `apply_status_self` — Apply a status effect to the player
- `apply_status_all` — Apply a status effect to all enemies

**New cards never require GDScript changes** — only a JSON file.

### Player Attributes (五维属性)

| Attribute | 属性 | Effect |
|---|---|---|
| **Strength** | 力量 | Added to attack card damage |
| **Constitution** | 体质 | Added to skill card block; replaces old "Defense" |
| **Intelligence** | 智力 | Used by Ability cards and special scaling (e.g. Overdrive) |
| **Luck** | 幸运 | Affects reward quality, crit chance (future) |
| **Charm** | 魅力 | Affects shop prices, NPC interactions (future) |

> Equipment boosts these five stats. Attributes persist within a run via `RunManager.player_attributes`.

### Status Effects

| Status | Effect |
|---|---|
| **Poison** ☠ | Deals stacks damage at start of turn, stacks decrease by 1 per turn |
| **Burn** 🔥 | Deals stacks damage at start of turn, does NOT decrease |
| **Weak** | Direct attack damage dealt is reduced by 50%; stacks decrement at end of affected character turn |
| **Vulnerable** | Direct attack damage taken is increased by 50%; stacks decrement at end of affected character turn |
| **Strength Up** | Bonus strength for stacks turns then expires |

### Enemy System
- Each enemy loads from `card_info/enemy/{id}.json` — includes a `sprite_id` for pixel art
- Enemies have an `action_pattern` array that cycles: `attack`, `block`, `heal`
- **Intent badge** displayed above enemy HUD with emoji (⚔/🛡/♥)
- Multiple enemies per encounter are supported

---

## Equipment System (装备)

Equipment is gear the player equips to **boost their five attributes**. It is NOT a passive relic — it has direct numeric stat bonuses.

### Rules
- Player has **5 equipment slots** (one per attribute, or general-purpose)
- Equipment can only be changed on the **Map screen** (between battles)
- Equipment **cannot** be swapped during combat
- Equipment is looted from encounters, purchased in shops, or found in the base
- Each piece of equipment shows: stat bonuses, rarity, and flavor text

### Equipment JSON Schema
```json
{
    "id": "scrap_gauntlet",
    "name": "Scrap Gauntlet",
    "rarity": "common",
    "slot": 1,
    "bonuses": {
        "strength": 2,
        "constitution": 1
    },
    "description": "Welded from junk. Still hits hard.",
    "sprite": "equipment/scrap_gauntlet.png"
}
```

### RunManager Fields
- `equipped_items: Array[String]` — up to 5 equipment IDs (already exists, to be repurposed)
- Equipment stat totals are computed and applied to `player_attributes` at map screen load

---

## Relic System (遗物)

Relics are **passive effects that persist for the entire run**. Unlike equipment, they don't boost stats directly — they change rules, trigger on events, or provide recurring advantages.

### Examples
| Relic | Effect |
|---|---|
| **Cracked Reactor** | Start each battle with 1 extra energy |
| **Stolen Badge** | Reduce shop prices by 20% |
| **Junk Magnet** | Enemies drop 1 extra gold on death |
| **Failsafe Module** | Once per run, survive a killing blow with 1 HP |

### Rules
- Relics are collected from elite encounters, shops, and boss rewards
- Relics are **not** equippable in slots — they auto-activate
- Stored in `RunManager.relics: Array[String]`
- Each relic is defined in a JSON file in `run_system/data/relics/{id}.json`

---

## Tarkov Extraction System (撤离机制)

The run is divided into **3 floors**. After each boss, the player faces an extraction choice.

### Floor Structure
```
Floor 1: Normal encounters → Elite → Boss
Floor 2: Harder encounters → Elite → Boss  
Floor 3: Hardest encounters → Elite → Final Boss → Victory
```

### Extraction Choice (after each Floor 1 and Floor 2 boss)
When a boss is defeated, the player sees a choice screen:

> **🚪 EXTRACT** — Leave now. Keep all gold, equipment, relics, and cards collected so far. Return to base.
>
> **⬆ PUSH DEEPER** — Continue to the next floor. Higher risk, higher reward. If you die, you lose everything.

- Extracting triggers **base-building reward** (carry-in loot saved)
- Dying on a deeper floor means losing everything above the floor you extracted at
- Players who push all 3 floors and win get the **full victory bonus**

### End States

| Outcome | Result |
|---|---|
| Extract after Floor 1 boss | Save Floor 1 loot → base building |
| Extract after Floor 2 boss | Save Floor 1+2 loot → base building |
| Complete Floor 3 boss | Full victory, maximum reward |
| Die on any floor | Lose all loot from that floor onward |

---

## Base Building System (基地建造)

Between runs, players return to their **home base** and spend **Core** (meta-currency) to permanently improve it.

### Base Upgrades (examples)
| Upgrade | Effect |
|---|---|
| **Med Bay** | Start runs with more max HP |
| **Arsenal** | Unlock more starter equipment options |
| **Research Lab** | Add cards to the general draft pool |
| **Scrap Workshop** | Reduce equipment upgrade costs in shops |
| **Command Center** | Reveal map nodes before choosing |

### Rules
- Core is earned by extracting or completing runs — NOT from dying
- Base upgrades persist permanently across all runs (true meta-progression)
- Some upgrades unlock new heroes or starting decks

---

## Run System

### RunManager (Autoload Singleton)
Central source of truth for a run. Persists across scene changes.

| Data | Description |
|---|---|
| `current_health / max_health` | Player HP (carries over battle to battle) |
| `player_deck` | Array of card dictionaries (uid + card_id) |
| `player_attributes` | Five-dimension RPG stat dictionary (str/con/int/lck/chr) |
| `current_encounter` | Enemy IDs for the next battle |
| `gold` | Currency for shops |
| `core` | Meta-progression resource (spent in base building) |
| `current_floor` | Which floor of the run (1–3) |
| `equipped_items` | Up to 5 equipped item IDs (stat-boosting equipment) |
| `relics` | Array of relic IDs (passive run effects) |
| `highest_extract_floor` | Highest floor the player safely extracted from this run |

### Deck Persistence
- `RunManager.player_deck` is read by `deck_manager.reset_deck()` at battle start
- Cards drafted from loot rewards are added via `RunManager.add_card_to_deck()`
- Starter decks are fixed per hero/run setup; players do not build starter decks manually

### Map System
- `map_scene.gd` shows available encounter nodes for the current floor
- Player can manage equipment on this screen (swap items freely)
- Before loading `battle_scene.tscn`, the map sets `RunManager.current_encounter`
- Enemy encounters escalate in difficulty by floor

### Loot Reward
- Post-battle screen shows: **Gold**, **Card Draft**, and occasionally **Equipment Drop**
- Gold: random 30–75 gold, added to RunManager
- Card Draft: choose 1 of 3 random cards from the `draft_pool`
- Equipment Drop: rare chance to find a new equipment piece to equip on the map screen

---

## Technical Architecture

### Scene Structure

```
BattleScene (Node)
├── CardManager (Control) — Card framework, manages drag/drop
│   ├── CardPlayZone      — Invisible drop target for skill/ability cards
│   ├── Hand              — Player's current hand (fan layout)
│   ├── Deck              — Draw pile
│   ├── DiscardPile       — Discard pile
│   └── BlackHolePile     — Permanent removal pile (for one-time cards, future)
├── Player (Node2D)        — PlayerEntity: HP, attributes, AnimatedSprite2D
├── EnemyContainer (Node2D) — Holds all EnemyEntity nodes for current encounter
├── TurnManager            — Round counter, energy, turn signals
├── CombatEngine           — Generic effect resolver
├── EnemyAI                — Spawns enemies, executes enemy turns
└── BattleUIManager        — Pile viewer, card inspect, notifications
```

### Key Scripts

| Script | Responsibility |
|---|---|
| `battle_scene.gd` | Central orchestrator: wires all subsystems, targeting state |
| `combat_engine.gd` | Data-driven effect resolver; reads `effects[]` from card JSON; applies weak/vulnerable attack multipliers |
| `enemy_entity.gd` | Loads from JSON; manages sprite via `sprite_id`; action pattern cycling |
| `enemy_ai.gd` | Spawns enemies; executes turn; applies enemy attack multipliers and relic modifiers |
| `deck_manager.gd` | Draw/discard/reshuffle logic |
| `play_card.gd` | Routes attack vs skill via mouse events |
| `run_manager.gd` | Autoload: all persistent run state including equipment and relics |

### Card JSON Schema

**Player card (`card_info/player/{name}.json`):**
```json
{
    "name": "card_id",
    "title": "Display Title",
    "type": "attack | skill | ability",
    "cost": 1,
    "description": "BBCode description text.",
    "front_image": "player/filename.png",
    "side": "player",
    "effects": [
        { "type": "deal_damage", "amount": 6, "scaling": "strength" }
    ]
}
```

**Enemy JSON (`card_info/enemy/{id}.json`):**
```json
{
    "id": "enemy_id",
    "name": "Display Name",
    "sprite_id": "sprite_prefix",
    "max_health": 30,
    "action_pattern": [
        { "type": "attack", "amount": 6, "label": "⚔ 6" },
        { "type": "block",  "amount": 8, "label": "🛡 8" }
    ]
}
```

---

## Art Style — Wasteland Punk Pixel Art

The game's definitive art direction is **Wasteland Punk Pixel Art**: a post-apocalyptic scrapyard aesthetic (think Mad Max meets Fallout) rendered in bold, cel-shaded pixel art.

### Visual Rules
| Element | Rule |
|---|---|
| **Silhouette** | Bold, instantly readable at 64×64. Simple shape, exaggerated proportions. |
| **Materials** | Scrap metal, duct tape, rubber, chains, cracked glass, worn leather, exposed wiring — salvaged and corroded. Nothing clean or new. |
| **Color palette** | Earth tone base (rusted orange, sandy brown, dusty grey, faded olive) + **one neon accent per character** |
| **Outlines** | Bold single-color black outlines — pixel-weight, confident |
| **Shading** | Cel-shaded / flat — NOT photorealistic |
| **Background** | Sprites and FX are transparent; full-scene map and battle backgrounds are scene-ready PNGs with no UI baked in |

### Mandatory Prompt Suffix
Every generated character or combat sprite prompt should preserve this wording:
```
wasteland punk style, post-apocalyptic scrap aesthetic, rusted metal and salvaged parts,
single color bold black pixel art outlines, cel-shaded flat colors, earth tone palette
with one neon accent color, transparent background, side view, full body, pixel art
```

### Generation Pipeline
Final Godot assets are PNG files. Character and FX sheets use a solid `#FF00FF` background for cleanup, then are split into transparent frames. Card illustrations and battle backgrounds are scene-ready PNGs with no text, logos, or UI baked in.

### Sprite Pipeline
1. Generate a contained sheet with consistent character scale and a shared baseline.
2. Post-process into transparent PNG frames and verify frame dimensions.
3. Save to `heroes/{hero_id}/`, `enemies/{sprite_id}/`, or `fx/{effect_id}/` as appropriate.
4. Reference final PNGs from JSON or runtime loaders; gameplay must not reference raw sheets.

- **Folder:** `enemies/{sprite_id}/{sprite_id}_{anim}_{n}.png` or `heroes/{hero_id}/{hero_id}_{anim}_{n}.png`.
- **Frame counts:** 4 frames idle (looping) + 4 frames attack (one-shot, returns to idle).
- **Scale:** frames render with nearest filtering in Godot and are sized per entity.
- **Source sheets:** keep raw/generated sheets in `generated_sheet/` folders only.

---

## Development Roadmap

### ✅ Phase 1 — Core Combat (Complete)
- STS card play loop (draw 3 / play / discard / enemy turn)
- Attack card drag-to-target with arrow
- Skill/ability cards via play zone
- Data-driven effect system (effects[] in JSON)
- Enemy intent system with action patterns
- Player HP / block / energy UI (CharacterHUD)
- Draw pile / discard pile viewer (Q/E shortcuts)
- Status effect system (poison, burn, weak, vulnerable, strength_up)
- Pixel art combat sprites with idle + attack animations

### 🔄 Phase 2 — Run System & Content (Active)
- Map scene with selectable encounter nodes per floor
- 3-floor structure with boss extraction choice screen
- 3–5 enemy types with distinct action patterns + pixel art
- 10–15 player cards covering all three types
- Fixed starter decks with map/reward progression
- Loot reward with equipment drops

### ⬜ Phase 3 — Equipment & Relics
- Equipment system: 5 slots, stat bonuses, swap on map screen
- Relic system: passive run effects, JSON-driven
- Shop scene: buy cards, equipment, relics; remove cards
- Rest site scene: heal or upgrade a card
- Card upgrade system

### ⬜ Phase 4 — Base Building & Meta-Progression
- Home base scene with upgrade nodes
- Core currency persistence across runs
- Base upgrades: Med Bay, Arsenal, Research Lab, etc.
- Extraction flow: post-boss choice screen → base reward
- Hero unlock system via base upgrades

### ⬜ Phase 5 — Content Expansion
- Multiple hero archetypes with unique starting decks
- 30+ unique cards
- 10+ enemy types with pixel art
- 3 boss encounters (one per floor) with multi-phase patterns
- Final boss with unique mechanics

---

## Known Issues & Tech Debt

| Priority | Issue |
|---|---|
| 🟡 | `_write_hp_to_run_manager()` writes HP directly, bypassing `health_changed` signal |
| 🟢 | API key exposed in `generate_enemy.ps1` — should use env variable |
| 🟢 | Black Hole Pile exists in scene but has no gameplay purpose yet |
| P3 | Some legacy generated card art may remain unused; current playable cards should reference PNG art |
