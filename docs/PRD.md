# Product Requirements Document
**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Art Style:** Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland
**Engine:** Godot 4.6  
**Last Updated:** 2026-06-01

---

## Overview

A single-player roguelite deckbuilder set in a post-apocalyptic scrapyard wasteland. Players collect cards, relics, and equipment while fighting through escalating routes toward bosses. The visual language is locked to a Rick-and-Morty-like adult sci-fi cartoon wasteland style: thick rubbery dark outlines, flat bright color blocks, simple cel shading, exaggerated odd proportions, dusty western junk-tech materials, and weird comic sci-fi energy.

Combat is **Slay the Spire style**: the player has a hand of cards, limited energy, and must choose each turn which cards to play to survive enemy attacks while defeating them.

Project documentation is centralized in `docs/`:
- `docs/PRD.md` is the product and systems source of truth.
- `docs/PROJECT_STRUCTURE.md` maps scenes, scripts, data, and assets.
- `docs/project-rules.md` defines art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland reference.

---

## Core Gameplay Loop

```
Hero Select + Loadout -> Act 1 Map -> Battle -> Loot -> Map -> ... -> Act Boss
                                                                              ↓
                                                              Extract OR Push on to Act 2
                                                                              ↓
                                                              Act 2 → ... → Boss
                                                                              ↓
                                                              Extract OR Push on to Act 3
                                                                              ↓
                                                              Act 3 → Final Boss → Victory
```

1. **Hero Select + Loadout** - Pick a hero (fixed starter deck + attribute spread) and inject stashed gear into the backpack
2. **Map** - Choose the next encounter node (normal / elite / rest / shop / treasure / ? event / boss) within the act's ~12-floor map
3. **Battle** - STS-style card combat
4. **Loot Reward** - Post-battle: claim gold/Core and optionally draft 1 new card
5. **Boss Extraction Choice** _(after each non-final act boss)_ - Push on to the next act OR extract (bank carried Core, gear → permanent stash)
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
| **Luck** | 幸运 | Crit chance (1.5× hits via Cowboy Bill's Crit Clip relic, ≈luck×3% capped 40%) + post-battle gold + loot rarity |
| **Charm** | 魅力 | Lowers shop prices (≈2%/point, floored at 0.6×) + unlocks high-Charm options in random events |

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
- Each enemy loads from `card_info/enemy/{id}.json` — includes a `sprite_id` for the art
- Action types: `attack`, `attack_status`, `attack_all`, `block`, `heal`, `telegraph`, plus `summon` (spawn add enemies, capped at 4 on the field) and `buff_self` (apply a status to itself, e.g. `strength_up`)
- **Bosses have bespoke mechanics** via an optional `phases` field: at an HP threshold the boss runs one-time `on_enter` actions and swaps to a tougher `action_pattern`. The three act bosses: **rust_titan** (enrage at 50% — stacks Strength), **ash_warden** (debuff + summons `ember_wisp`), **junkyard_tyrant** (summons `scrap_shard` + AoE + self-heal). Killing the boss ends the fight even if summoned adds are still alive.
- **Per-act difficulty scaling**: non-boss enemy HP ×[1.0, 1.25, 1.5] and damage ×[1.0, 1.15, 1.3] by act; the enemy pool also shifts tougher each act. Bosses are exempt (tuned per-boss).
- **Intent badge** displayed above enemy HUD with emoji; multiple enemies per encounter supported

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

## Extraction Backpack Economy (撤离背包经济)

The run is **3 self-contained acts**, each its own ~12-floor map ending in a single boss (`ACT_BOSSES = [rust_titan, ash_warden, junkyard_tyrant]`; tracked by `RunManager.current_act` / `advance_act()`). Clearing a non-final act's boss opens an extract-vs-push choice; clearing the final act's boss wins the run.

### The backpack (20 cells)
All loot lives in a single **20-cell backpack** where **Gold, Core, and equipment compete for space**:
- **Gold** — physical stacks (≤100/cell, auto-merge, used for shop change-making). Gold does **NOT** carry across runs.
- **Core** — in-run meta-currency dropped by elites / bosses / treasure / events (≤30/cell). Not spendable in-run; banks to permanent `MetaProgress.core` **only on extract or final victory**.
- **Equipment** — one item per cell.

### Death, safe cells, and the permanent stash
- **Death forfeits the entire backpack AND equipped gear — EXCEPT "safe cells."** The first N cells are safe (base 2, +1 per Blacksmith base-upgrade level); their contents survive death.
- **Extract / final victory** banks all carried Core and sends all carried + equipped gear to a **permanent base stash** (`MetaProgress.stash`).
- A **loadout step** at the base injects chosen stashed gear into the next run's backpack (`RunManager.pending_loadout`).

### Extraction choice (after each non-final act boss)
> **🚪 EXTRACT** — bank the Core in your backpack now and return to base (lower, but guaranteed).
>
> **⬆ PUSH ON** — take more Core (into the backpack, still at death risk) and continue to the next act (regenerates a fresh act map).

### End States

| Outcome | Result |
|---|---|
| Extract after an act boss | Carried Core banks to `MetaProgress.core`; all gear → stash; run ends |
| Push on | More Core into the backpack (still at death risk); next act map generated |
| Clear the final-act boss | Full victory — everything banks |
| Die on any floor | Lose the backpack + equipped gear, EXCEPT safe-cell contents |

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
│   └── (exhaust uses queue_free directly — no dedicated removal pile)
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

## Art Style - Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland

The game's definitive art direction is **Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland**, with `docs/art/rick-morty-radiation-rat-style-reference.png` as the ground-truth reference. The style target is original adult sci-fi animation adapted into game assets: thick rubbery dark outlines, flat bright color blocks, simple cel shading, exaggerated awkward proportions, toxic-green radiation accents, dusty western junk-tech materials, and weird comic tone.

The project is no longer a 128-pixel or pixel-art style. Any frame sizes in asset specs are engine output contracts only.

### Visual Rules
| Element | Rule |
|---|---|
| **Style target** | Rick-and-Morty-like adult sci-fi cartoon wasteland game art; original designs only, no copying named characters or exact show designs. |
| **Output sizes** | Use the dimensions required by each asset spec; size does not define the art style. |
| **Silhouette** | Exaggerated, asymmetrical, and immediately readable: bulging eyes, huge teeth, warped bodies, lanky limbs, crooked antennas, glowing pustules, and awkward junk-tech proportions. |
| **Materials** | Mutant skin, patchy fur, dusty leather, brass cuffs, dented steel, exposed springs, patched cloth, rubber hoses, cracked glass, radioactive slime, and cheap improvised sci-fi parts. |
| **Color palette** | Sickly radioactive green and yellow-green accents over dusty tan, dirty pink skin, leather brown, rust, brass, dark steel, and occasional cyan or magenta. |
| **Outlines** | Thick black or very dark brown rubbery outlines with confident interior contour lines. |
| **Shading** | Simple two-to-three value cel shading; use shadow shapes to clarify volume instead of detailed painterly texture. |
| **Background** | Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI baked in. |

### Character Anchors
- Cowboy Bill: robot cowboy hero with exactly one large orange camera eye, oversized battered hat with star badge, red scarf, patched duster or poncho, chunky boots, salvaged revolver, facing right.
- Enemies: original junk-tech cartoon creatures, drones, mutants, or robots, facing left, with strong comic silhouettes and one or two small neon accents.

### Mandatory Prompt Anchor
Every generated asset prompt should preserve this wording:
```text
original offbeat adult sci-fi cartoon wasteland game art, Rick-and-Morty-like broad adult sci-fi animation energy without copying named characters or exact show designs, thick dark rubbery outlines, flat bright color blocks, simple cel shading, exaggerated asymmetrical proportions, bulging expressive eyes, weird mutant or junk-tech silhouette, dusty western leather and brass, dented steel, exposed springs, patched cloth, radioactive slime, one or two small toxic-green glowing accents, crisp sprite-ready edges, solid #FF00FF magenta background for cleanup or transparent final PNG, no text, no UI frame, no logo
```

### Generation Pipeline
Final Godot assets are PNG files. Character and FX sheets can use a solid `#FF00FF` background for cleanup, then be split into transparent frames. Card illustrations and battle backgrounds are scene-ready PNGs with no text, logos, or UI baked in.

### Sprite Pipeline
1. Generate a contained sheet with consistent character scale and a shared baseline.
2. Post-process into transparent PNG frames and verify frame dimensions.
3. Save to `heroes/{hero_id}/`, `enemies/{sprite_id}/`, or `fx/{effect_id}/` as appropriate.
4. Reference final PNGs from JSON or runtime loaders; gameplay must not reference raw sheets.

- **Folder:** `enemies/{sprite_id}/{anim}/{sprite_id}_{anim}_{n}.png` or `heroes/{hero_id}/{anim}/{hero_id}_{anim}_{n}.png`.
- **Frame counts:** 4 attack frames; `attack_0` is also the static rest pose. There are no separate idle animation assets.
- **Scale:** frames render at the size set by gameplay/UI code; scale does not change the art direction.
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
- Combat sprites with static rest poses and attack animations

### 🔄 Phase 2 — Run System & Content (Active)
- Map scene with selectable encounter nodes per floor
- 3-floor structure with boss extraction choice screen
- 3–5 enemy types with distinct action patterns + final sprite art
- 10–15 player cards covering all three types
- Fixed starter decks with map/reward progression
- Loot reward with equipment drops

### ✅ Phase 3 — Equipment & Relics (Complete)
- ✅ Equipment system: 5 body-part slots, stat bonuses, swap on map screen, 2 sets with tiered bonuses (3-piece / 5-piece), 18 items (10 common / 4 uncommon / 4 rare)
- ✅ Inventory (8-item cap) — later superseded by the 20-cell Extraction Backpack where Gold/Core/equipment share cells (see Extraction Backpack Economy)
- ✅ Elite/Boss loot equipment drops; treasure node 50/50 relic or equipment (70/30 uncommon/rare)
- ✅ Relic system: passive run effects, JSON-driven (RelicEffectSystem)
- ✅ Shop scene (merchant node): 3 cards + 2 equipment + 1 relic + remove-card service (75g)
- ✅ Rest site: choice between Heal 25% HP and Upgrade a Card
- ✅ Card upgrade system: 17 `_plus` variants, `RunManager.upgrade_card_by_uid` + CardUpgradeModal; upgrade = card_id swap (e.g., `strike` → `strike_plus`)
- ✅ Character info panel (map screen): HP / Gold / Floor + equipment slots + inventory + active sets + relics + stats — one consolidated view

### 🟡 Phase 4 — Base Building & Meta-Progression (MVP shipped 2026-05-25)
- ✅ Home base scene with 5 upgrade panels + START NEW RUN button (boot scene)
- ✅ Core currency persistence across runs via `MetaProgress` autoload (`user://meta.json`)
- ✅ Base upgrades (5 × 3 tiers, cost 30/60/100 Core):
  - **Med Bay**: +10/20/30 max HP at run start
  - **Arsenal**: 1 common / 2 commons / 2 commons + 1 uncommon in starter inventory
  - **Research Lab**: 5% / 10% / 15% chance to promote loot draft cards' rarity (Lv3 also adds +5% rare)
  - **Scrap Workshop**: 10% / 20% / 30% off all shop prices
  - **Command Center**: +50 / +120 / +200 starting gold
- ✅ Boss victory grants Core and returns to home base. (Superseded by the 3-act map: each act ends in a boss, and the extract-vs-push-on choice now ships after each non-final act boss — see Extraction Backpack Economy.)
- ✅ Player death routes to home base (no Core gained)
- ✅ Hero JSON schema + dynamic loader: heroes/*.json (cowboy_bill + hero_jerry_killer); player.gd reads sprite/tint/stats from RunManager.current_hero_data
- ✅ Hero unlock: jerry_unlock base upgrade (100 Core, single tier)
- ✅ Run history panel: home base shows last 5 runs (outcome icon + hero + floor + core)
- ✅ Ascension difficulty: 5 levels, each adds a negative modifier (enemy HP+10%, player -5 max HP, -1 first-turn energy, +10% shop prices, elite-heavy maps)
- ✅ Starter Boost upgrade: 3 tiers, +N random attribute points at run start
- ✅ Card Research upgrade: 3 tiers unlocking 5 cards (flash_bang, bone_breaker, last_breath, preemptive_strike, junk_bomb)

### 🟡 Phase 5 — Content Expansion (in progress)
- ✅ Second hero with a distinct kit: **Jerry the Killer** (aggressive high-STR, `bounty_tags` starting relic); Cowboy Bill = luck/crit (`crit_clip`)
- ✅ 35 cards (excl. `_plus`), including luck/charm/strength-scaling cards
- ✅ 13 enemy types (+2 summon-only adds); art migrating to the new style (ADR-0012)
- ✅ 3 boss encounters (one per act) with multi-phase patterns + bespoke mechanics (enrage / summon / AoE)
- ⬜ More heroes, more enemies, deeper boss gimmicks

### ✅ Phase 6 — Three-Act Maps · Extraction Economy · Active Attributes (shipped 2026-05–06)
- ✅ **3-act map**: each act is its own ~12-floor map ending in a boss (`current_act` / `advance_act()`), with per-act enemy stat + pool scaling
- ✅ **Extraction Backpack Economy**: 20-cell backpack (Gold/Core/equipment share cells), safe cells survive death, permanent base stash + next-run loadout, extract-vs-push choice after each non-final act boss
- ✅ **Active attributes**: Luck → crit (`crit_clip`) + post-battle gold + loot rarity; Charm → shop discount + event gating
- ✅ **Boss bespoke mechanics**: HP-threshold `phases` + `summon` / `buff_self` enemy actions
- ✅ **Random events**: the "?" map node opens a full event scene (2–3 attribute-gated options); 6 events
- ✅ Act-aware UI (map top bar / vitals / run history show the act) + i18n (zh) for events

---

## Known Issues & Tech Debt

| Priority | Issue |
|---|---|
| 🟢 | `Sharpened Scrap` relic's `_mark_used_once()` call is harmless dead code for non-`once_per_combat` relics — minor readability |
| P3 | Some legacy generated card art may remain unused; current playable cards should reference PNG art |
| ⚠️ | **The pre-2026-05-25 PixelLab key in `generate_enemy.ps1`** is in git history and should be rotated on the PixelLab side. The file now reads from `$env:PIXELLAB_API_KEY` but the old key remains exposed in historical commits. |
