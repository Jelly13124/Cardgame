# Product Requirements Document
**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Art Style:** Offbeat Adult Sci-Fi Cartoon Wasteland
**Engine:** Godot 4.6  
**Last Updated:** 2026-06-03

---

## Overview

A single-player roguelite deckbuilder set in a post-apocalyptic scrapyard wasteland. Players collect cards, relics, and equipment while fighting through escalating routes toward bosses. The visual language is locked to an original flat adult sci-fi cartoon direction: thick clean dark outlines, large simple shape blocks, weird sci-fi western silhouettes, broad cel shading, sparse texture, and bright toxic accent colors.

Combat is **Slay the Spire style**: the player has a hand of cards, limited energy, and must choose each turn which cards to play to survive enemy attacks while defeating them.

Project documentation is centralized in `docs/`:
- `docs/PRD.md` is the product and systems source of truth.
- `docs/PROJECT_STRUCTURE.md` maps scenes, scripts, data, and assets.
- `docs/project-rules.md` defines art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved Offbeat Adult Sci-Fi Cartoon Wasteland style contract and in-game visual exemplars.

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
| **Curse** | **Unplayable** — returns to hand if played; punishes you each turn it sits in hand (`end_turn_in_hand`) | — |

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
- `discover` — Hearthstone-style 3-choose-1: pops a candidate popup (filtered by `pool` — a card type, or a theme tag like `bleed`); the picked card is created into the **current hand for this combat only** (never the permanent deck). Optional `free` makes it cost 0 this combat (a `cost_override` meta on the card).
- Economy / curse: `gain_gold`, `lose_gold`, `heal`, `lose_hp`, `add_card_to_hand`, `add_curse_to_deck` — gold / HP swings and shuffling a card (or a permanent curse) into the deck.

> The list above is a selection. The **authoritative** set is `DataValidator.ALLOWED_EFFECT_TYPES` (33 types) — see `docs/conventions/data-files.md` for the full categorized list.

**New cards never require GDScript changes** — only a JSON file.

### Player Attributes (五维属性)

| Attribute | 属性 | Effect |
|---|---|---|
| **Strength** | 力量 | Added GLOBALLY to ALL attack damage (`combat_engine._apply_effect()`, default +3); per-card `scaling` is deprecated |
| **Constitution** | 体质 | Added GLOBALLY to ALL block (default +3); replaces old "Defense" |
| **Intelligence** | 智力 | Boosts tool effects (+8%/pt) and card Bleed scaling (default scaling attr); no longer affects XP |
| **Luck** | 幸运 | Crit chance (+2%/pt, +4% with Crit Clip, uncapped; 1.5× crit) + 1.5%/pt loot rarity + gem/tool/equipment find chance |
| **Charm** | 魅力 | Lowers shop prices (−2%/pt, floor 0.6×) + lowers per-level XP wall (−4%/pt, floor 0.6×) + gates high-Charm event options (the old enemy-flee mechanic was deleted) |

> Equipment boosts these five stats. Attributes persist within a run via `RunManager.player_attributes`.

### Status Effects

| Status | Effect |
|---|---|
| **Bleed** | Start of turn: take damage = stacks, then stacks halve (round down) |
| **Burn** 🔥 | Takes damage = stacks at END of turn; loses 1 stack at start of turn |
| **Weak** | Direct attack damage dealt is reduced by 50%; stacks decrement at end of affected character turn |
| **Vulnerable** | Direct attack damage taken is increased by 50%; stacks decrement at end of affected character turn |
| **Stun** ⚡ | Enemy skips its next turn per stack; manual-consume, no decay; enemy-only; can interrupt a telegraphed attack |
| **Regen / Thorns / Frail / Dodge / Double Damage** | heal-over-time / reflect-on-hit / −25% block / negate one attack / next N attacks doubled |
| **Metallicize / Feel No Pain / Dark Embrace** | persistent powers (StS2 port): +Block per turn / +Block on Exhaust / draw on Exhaust |

### Enemy System
- Each enemy loads from `card_info/enemy/{id}.json` — includes a `sprite_id` for the art
- Action types: `attack`, `attack_status`, `attack_all`, `block`, `heal`, `telegraph`, plus `summon` (spawn add enemies, capped at 4 on the field) and `buff_self` (apply a status to itself, e.g. `thorns`)
- **Bosses have bespoke mechanics** via an optional `phases` field: at an HP threshold the boss runs one-time `on_enter` actions and swaps to a tougher `action_pattern`. The three act bosses: **rust_titan** (tougher phase-2 loop at 50%), **ash_warden** (debuff + summons `ember_wisp`), **junkyard_tyrant** (summons `scrap_shard` + AoE + self-heal). Killing the boss ends the fight even if summoned adds are still alive.
- **Per-act difficulty scaling**: non-boss enemy HP ×[1.0, 1.25, 1.5] and damage ×[1.0, 1.15, 1.3] by act; the enemy pool also shifts tougher each act. Bosses are exempt (tuned per-boss).
- **Intent badge** displayed above enemy HUD with emoji; multiple enemies per encounter supported

---

## Equipment System (装备)

Equipment is gear the player equips to **boost their five attributes** via rolled **affixes**. It is NOT a passive relic — it carries direct numeric stat bonuses.

### Rules
- Player has **5 equipment slots**: head / chest / weapon / hands / accessory
- Equipment is held in the backpack and **equipped from the character panel**; it cannot be swapped during combat
- Equipment is looted from encounters (Luck-scaled) and forged / reforged at the base — it is **no longer sold in the shop** (the shop sells tools)
- Each piece shows its rolled affixes, a rarity color, and flavor text

### Rarity & Affixes (5-tier)
A dropped piece becomes an **instance** that rolls its affixes at grant time (`RunManager.make_equip_instance` → `run_system/core/affix_pool.gd`). Rarity drives both the affix count and the tile color:

| Rarity | 中文 | Affixes | Color | Notes |
|---|---|---|---|---|
| `common` | 普通 | 1 | graphite | — |
| `uncommon` | 稀有 | 2 | steel-blue | — |
| `rare` | 罕见 | 3 | gold | — |
| `set` | 套装 | 3 | green | a piece carrying a `set_id` → grants tiered **set bonuses** (3-piece / 5-piece) |
| `cursed` | 诅咒 | 3 **+ 1 curse** | red | 3 positive affixes + 1 negative curse affix (the trade-off) |

`set` / `cursed` are **derived** at roll time (a piece with a `set_id` reads as `set`; a cursed roll as `cursed`). Affixes come from a fixed pool — positives (`attr_*` +1 to a stat, `crit_pct` +5%, `max_hp` +10) and curses (`curse_*`); `affix_pool.attribute_totals()` sums them and `recompute_attributes()` applies the totals on top of `base_attributes` for every equipped piece.

### Equipment JSON Schema (base item)
```json
{
    "id": "tank_engineer_helm",
    "name": "Reinforced Hardhat",
    "slot": "head",
    "rarity": "common",
    "set_id": "tank_engineer",
    "bonuses": { "constitution": 1 },
    "description": "Steel-banded. Heavy. Reliable.",
    "sprite": "equipment/tank_engineer_helm.png"
}
```
- `set_id` — optional; present only on set pieces (one of the 3 sets).
- `bonuses` — a **back-compat baseline only**: freshly-dropped pieces roll affixes anew and ignore it; a legacy stash entry stored as a bare item-id string derives its affixes from `bonuses` (`as_equip_instance`). New stat design lives in the rolled affixes, not here.

### Forge (铁匠铺)
At the base: **dismantle** gear into Scrap, or **reforge** a single affix — the first reforge locks the item to that affix and each later reforge of it costs more (`reforge_stash_item_locked`, cost = rarity-base × (count + 1)). Curse affixes can't be reforged.

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
- **Death forfeits the entire backpack AND equipped gear — EXCEPT "safe cells."** The first N cells are safe (base 2, +1 per Outpost safe-cells upgrade level); their contents survive death.
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

Between runs, players return to their **home base** — a 2-left / 2-right building
layout with a centre "depart door" (Warehouse tile above it). Each building opens a
full-screen, merchant-style screen. Three meta-currencies fund it:
**Core** (unlock + tier-up buildings), **Caps** (Clinic / Market services), **Scrap**
(Forge services). See `meta_progress.gd` `BUILDING_DEFS`.

### The 5 buildings
| Building | Role |
|---|---|
| **Forge (锻造)** | Dismantle gear → Scrap; craft / reforge / curse equipment (tier-gated, Scrap) |
| **Clinic (诊所)** | Caps-bought permanent attribute perks + a Max-HP perk (tier raises the cap) |
| **Market (黑市)** | Caps equipment shop + Core card-unlock; tier 3 opens a card shop |
| **Outpost (前哨站)** | Core upgrades: starting gold / in-run shop discount / safe cells / backpack size; difficulty (ascension) selector; starter-deck editor |
| **Warehouse (仓库)** | Pick the hero + the starting equipment loadout (drag-to-equip); default-unlocked; tier-ups add stash slots + (T3) resource conversion |

### Rules
- Core/Caps/Scrap are earned by extracting or completing runs — NOT from dying.
- Building unlocks + tiers persist permanently across runs (true meta-progression).
- Hero selection lives in the Warehouse (the standalone hero-select screen was removed).
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
Rewards are node-typed (see "Rewards by node type" in Phase 7):
- **Normal**: Gold + a 3-choose-1 **Card Draft** (Luck may turn a slot into a gem) + a Luck-scaled **Tool** + a Luck-scaled **common Equipment** (independent rolls).
- **Elite**: Card Draft + a 3-choose-1 **Gem** + a Luck-scaled **uncommon Equipment** (no tool).
- **Boss**: a guaranteed **rare Equipment** + a Gem.
- Gold is a flat per-fight amount (Luck no longer scales gold). Tools, equipment, and gems all claim into the **backpack**; tools are then equipped into a tool slot from the character panel.

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

## Art Style - Offbeat Adult Sci-Fi Cartoon Wasteland

The game's definitive art direction is **Offbeat Adult Sci-Fi Cartoon Wasteland**. The style target is original flat adult sci-fi western cartoon game art: thick clean dark outlines, large simple shape blocks, sparse interior linework, broad two-to-three value cel shading, weird alien desert forms, absurd salvage-tech silhouettes, dusty leather and brass, dented grey-green robot metal, patched red cloth, hoses, antennas, odd gadgets, and one or two bright toxic/cyan/orange glow accents.

Do not use old project reference images as global style anchors. `docs/art/cowboy-bill-character-sheet-reference.png` may be used only to preserve Cowboy Bill's identity markers. Do not copy named show characters, logos, exact show-specific designs, franchise-specific props, or exact scene layouts.

The approved production exemplars are Cowboy Bill's current runtime art and the new non-pixel backgrounds:

- `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`
- `battle_scene/assets/images/heroes/cowboy_bill/idle/`
- `battle_scene/assets/images/heroes/cowboy_bill/attack/`
- `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`
- `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`
- `battle_scene/assets/images/cards/player/*.png`

The project is no longer a 128-pixel or pixel-art style. Any frame sizes in asset specs are engine output contracts only.

All current playable player cards use `512x320` landscape PNG illustrations under `battle_scene/assets/images/cards/player/`. These are pure illustrations for the card art slot; UI framing, cost, title, rarity, type, and description are rendered by the card scene, never baked into the illustration.

### Visual Rules
| Element | Rule |
|---|---|
| **Style target** | Original Offbeat Adult Sci-Fi Cartoon Wasteland game art matching the approved in-game exemplars; flat 2D adult sci-fi TV-animation-like look, clean outlines, broad simple shapes, sparse texture, original designs only, no copying named show characters, logos, exact scene layouts, or franchise-specific props. |
| **Output sizes** | Use the dimensions required by each asset spec; size does not define the art style. |
| **Silhouette** | Exaggerated and immediately readable: oversized hats, cylindrical robot heads, chunky boots, lanky limbs, patched capes, bulbous lenses, crooked antennas, rubbery alien shapes, bulky salvaged weapons, hoses, and improvised gadgets. |
| **Materials** | Simplified dusty leather, red cloth scarf, brass cuffs, dented grey-green metal, patched fabric, rubber hoses, glass lenses, exposed springs, toxic sludge, glowing canisters, and flat alien terrain. |
| **Color palette** | Dusty tan and warm brown base colors, muted red cloth, grey-green metal, pale desert sand, sickly toxic green, cyan plasma, and warm orange glows. |
| **Outlines** | Thick black or very dark cartoon outlines with sparse interior contour lines. |
| **Shading** | Simple two-to-three value cel shading; use broad shadow shapes instead of detailed painterly texture, hatching, dithering, or noisy grunge. |
| **Background** | Character, card, UI, and FX sprites use transparent backgrounds; full-scene map and battle backgrounds are scene-ready PNGs with no UI, text, labels, or characters baked in. |
| **Card illustration** | `512x320` landscape PNG, no UI frame, no title, no cost, no rarity/type text, no description box, no speech bubble, no baked labels. |

### Character Anchors
- Cowboy Bill: robot cowboy hero with exactly one large orange camera eye, oversized battered hat with star badge, red scarf, patched duster or poncho, chunky boots, salvaged revolver, facing right. Preserve identity from the Bill sheet but render him in the active flatter cartoon style.
- Enemies: original junk-tech western robots, mutants, drones, creatures, or wasteland devices, facing left, with funny-gross silhouettes and one or two small glowing accents.

### Mandatory Prompt Anchor
Every generated asset prompt should preserve this wording:
```text
original Offbeat Adult Sci-Fi Cartoon Wasteland game art, matching the approved in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png, battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and run_system/assets/images/map/wasteland_route_map_pixel_bg.png, flat 2D adult sci-fi TV-animation look, thick clean dark cartoon outlines, large simple shape blocks, sparse interior lines, broad two-to-three value cel shading, weird sci-fi western wasteland, rubbery alien desert shapes, absurd salvage-tech silhouettes, dusty leather, brass, dented grey-green robot metal, patched red cloth, hoses, antennas, odd gadgets, bright toxic green, cyan, and warm orange glow accents used sparingly, clean game-ready edges, readable silhouettes, low texture noise, no text, no labels, no UI frame, no logo, no named show characters, no franchise-specific props, no exact scene copies
```

### Generation Pipeline
Final Godot assets are PNG files. Character and FX sheets can use a solid `#FF00FF` background for cleanup, then be split into transparent frames. Card illustrations and battle backgrounds are scene-ready PNGs with no text, logos, or UI baked in.

### Sprite Pipeline
1. Generate a contained sheet with consistent character scale and a shared baseline.
2. Post-process into transparent PNG frames and verify frame dimensions.
3. Save to `heroes/{hero_id}/`, `enemies/{sprite_id}/`, or `fx/{effect_id}/` as appropriate.
4. Reference final PNGs from JSON or runtime loaders; gameplay must not reference raw sheets.

- **Folder:** `enemies/{sprite_id}/{anim}/{sprite_id}_{anim}_{n}.png` or `heroes/{hero_id}/{anim}/{hero_id}_{anim}_{n}.png`.
- **Frame counts:** Cowboy Bill uses 8 idle frames plus 8 attack frames. Standard enemy attacks use 4 frames by default with `attack_0` as the static rest/wind-up pose. Enemy attacks must hit exactly once; repeated hit poses or multi-swing loops are rejected.
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
- Status effect system (bleed, burn, weak, vulnerable, double_damage, stun, regen, thorns, frail, dodge, + StS2 powers)
- Combat sprites with static rest poses and attack animations

### 🔄 Phase 2 — Run System & Content (Active)
- Map scene with selectable encounter nodes per floor
- 3-floor structure with boss extraction choice screen
- 3–5 enemy types with distinct action patterns + final sprite art
- 10–15 player cards covering all three types
- Fixed starter decks with map/reward progression
- Loot reward with equipment drops

### ✅ Phase 3 — Equipment & Relics (Complete)
- ✅ Equipment system: 5 body-part slots, **rolled affixes** (5-tier rarity common/uncommon/rare/set/cursed = 1/2/3/3/3+curse affixes; `affix_pool.gd`), 3 sets with tiered bonuses (3-piece / 5-piece), 23 base items (14 common / 6 uncommon / 3 rare on disk; set/cursed are derived at roll time)
- ✅ Inventory (8-item cap) — later superseded by the 20-cell Extraction Backpack where Gold/Core/equipment share cells (see Extraction Backpack Economy)
- ✅ Equipment drops are Luck-scaled (normal = common, elite = uncommon, boss = guaranteed rare; see 2026-06-22 economy pass); the treasure node is a 3-choose-1 relic pick
- ✅ Relic system: passive run effects, JSON-driven (RelicEffectSystem)
- ✅ Shop scene (merchant node): 3 cards + 3 tools + 3 relics + remove-card service (75g) — equipment is no longer sold
- ✅ Rest site: choice between Heal 25% HP and Socket Gems (opens the deck/gem screen)
- ⛔ ~~Card upgrade system (`_plus` variants + `upgrade_card_by_uid` + CardUpgradeModal)~~ — **REMOVED**; replaced by the gem-socket system (see Phase 6). All `_plus` cards + the upgrade UI were deleted.
- ✅ Character info panel (map screen): HP / Gold / Floor + equipment slots + inventory + active sets + relics + stats — one consolidated view

### 🟡 Phase 4 — Base Building & Meta-Progression (MVP shipped 2026-05-25)
> ⚠️ **Superseded** by the 5-building refactor + Caps/Scrap economy (see "Base Building System" above). The original flat "5 upgrade panels" model below is historical; Med Bay→Clinic, Arsenal/Research Lab were removed, Scrap Workshop/Command Center→Outpost upgrades.
- ✅ Core currency persistence across runs via `MetaProgress` autoload (`user://meta.json`)
- ✅ (original) Base upgrades (5 × 3 tiers, cost 30/60/100 Core): Med Bay (+max HP), Arsenal (starter gear), Research Lab (loot rarity), Scrap Workshop (shop discount), Command Center (starting gold)
- ✅ Boss victory grants Core and returns to home base. (Superseded by the 3-act map: each act ends in a boss, and the extract-vs-push-on choice now ships after each non-final act boss — see Extraction Backpack Economy.)
- ✅ Player death routes to home base (no Core gained)
- ✅ Hero JSON schema + dynamic loader: heroes/*.json (cowboy_bill); player.gd reads sprite/tint/stats from RunManager.current_hero_data
- ✅ Hero selection now lives in the Warehouse building (the standalone hero-select screen was removed)
- ✅ Run history panel: home base shows last 5 runs (outcome icon + hero + floor + core)
- ✅ Ascension difficulty: 5 levels, each adds a negative modifier (enemy HP+10%, player -5 max HP, -1 first-turn energy, +10% shop prices, elite-heavy maps)
- ✅ Starter Boost upgrade: 3 tiers, +N random attribute points at run start
- ✅ Card Research upgrade: 3 tiers unlocking 5 cards (flash_bang, bone_breaker, last_breath, preemptive_strike, junk_bomb)

### 🟡 Phase 5 — Content Expansion (in progress)
- ✅ Cowboy Bill kit: luck/crit (`crit_clip`) + the StS2 Ironclad bruiser pool. (A second "Feng Shui Master" yin/yang hero was prototyped then **cut** 2026-06-18 — the demo ships Bill-only. Vestigial polarity plumbing remains inert.)
- ✅ ~65 player cards (no upgrade variants — gems replace upgrades), incl. a re-skinned StS2 Ironclad port; per-hero pools + colourless pool
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

### ✅ Phase 7 — Gems · In-Run Leveling · Reward Restructure (shipped 2026-06-09)
See `docs/superpowers/specs/2026-06-09-gems-leveling-rewards-design.md` for the full design.
- ✅ **Gem-socket system** (replaces card upgrades): run-scoped gems (`run_system/data/gems/*.json`, cleared on death), 1 socket/card, inserted out of combat and **locked after**. Gem effects fire after the card's own effects on play. Gems occupy **backpack cells** (1 gem = 1 cell; socketing frees the cell) — `add_gem_to_backpack / backpack_gem_ids / socket_gem / gem_pool`; socket UI reads `backpack_gem_ids()` in `run_deck_viewer_modal.gd`. (`gem_inventory` is now a vestigial migration-only field.) The old `wealthy` keyword is now a gem.
- ✅ **In-run XP / level**: kill enemies → XP; each level-up grants a **pick-1-of-3 random attribute (+1)**. (Intelligence no longer scales XP — **Charm** lowers the per-level XP wall instead, −4%/pt.) `RunManager.xp / level / gain_xp / xp_to_next / pending_attr_points`.
- ✅ **Starting attributes = 0** (heroes grow via level-ups / gear / gems).
- ✅ **Rewards by node type** (updated 2026-06-22): normal = gold + 3-choose-1 card draft (Luck may swap a slot to a gem) + Luck-scaled tool + Luck-scaled common equipment; elite = card + 3-choose-1 gem + Luck-scaled uncommon equipment; boss = guaranteed rare equipment + gem. (Equipment now drops from normal/elite too, not boss-only.)
- ✅ **StS2 Ironclad port** (`docs/sts2-port-audit.md`): re-skinned cards + 7 relics + 6 new combat mechanics; `bleed` replaced `poison`; `burn` retimed; `strength_up` removed.

### ✅ Phase 8 — Tools · Equipment Economy · A0 Balance (shipped 2026-06-21..22)
Specs: `docs/superpowers/specs/2026-06-21-tools-attrs-loading-base-ui-design.md`, `…/2026-06-22-balance-equipment-economy-design.md`.
- ✅ **Tool system** (StS2-style one-time consumables): `run_system/data/tools/*.json` (11: 8 original + 3 discover tools added 2026-06-30), a top-bar **tool shelf** (`run_top_bar.gd`), free instant use in battle (`battle_scene.use_tool`; enemy-target tools auto-target; effects reuse `combat_engine._apply_effect`, scaled ×(1+0.08·INT)). _Tool slots reworked in Phase 9 → **1 base slot**, tools held in the backpack + equipped from the character panel; see below._
- ✅ **Attribute rework**: the Charm enemy-**flee** mechanic was **deleted**; INT off XP → boosts tools + Bleed; Charm lowers the per-level XP wall.
- ✅ **Gems → backpack** (1 gem = 1 cell; socketing frees the cell), replacing the unlimited `gem_inventory` side-list.
- ✅ **Drop / shop restructure**: shop sells tools (not equipment); Luck-scaled tool + equipment drops (see Rewards by node type).
- ✅ **Loading**: session card-info cache (`MetaProgress.get_card_info_cache` + `cached_card_factory.gd`) skips the per-battle JSON re-parse.
- ✅ **Building detail pages** redesigned (icon + flavour + action card + locked-state preview, all 5 buildings). _Phase 9 moved the unlock/upgrade to the overview, dropped the action card, and made the pages fullscreen._
- ✅ **A0 balance pass**: deflated the over-statted 1-cost cards, raised enemy aggression (block→attack), retuned the Act-1 boss `rust_titan` into a 2-3-try skill gate (geared+leveled clears comfortably).

### ✅ Phase 9 — Base/shop/forge UI + tool-system rework (shipped 2026-06-25)
Spec: `docs/superpowers/specs/2026-06-25-base-shop-forge-tools-overhaul.md`.
- ✅ **Building unlock/upgrade → the overview**: a button under each building's floating
  "Lv<n> Name" label (or 🔒) → a confirm popup → spend Core. The detail-page action card is
  gone; clicking a locked building opens the same unlock confirm. Detail pages are services-only.
- ✅ **Building detail pages are fullscreen** (the shared shell fills the viewport minus a frame
  margin), so big grids fit. Warehouse shows the full **40-slot** stash (8-col grid of filled
  items + empty frames) + a **hero portrait** picker.
- ✅ **Market (黑市)**: equipment sits on a **shelf** (rarity-framed icon tiles + price), and the
  card-unlock / card-shop sections render **real card art** (`my_card_factory`).
- ✅ **Forge (铁匠铺) bench**: LEFT stash grid + RIGHT drop slot; drag/click an item onto the bench
  to see its affixes, then **Dismantle** or **Reforge a specific affix** (`affix_pool.reroll_at` +
  `MetaProgress.reforge_stash_item_affix`). Curse/Craft retained.
- ✅ **Tool rework**: `tool_slots()` base 2 → **1** (+ Outpost Tool Rack + relic). Tools are now
  **held in the backpack** (`{"kind":"tool"}` cells) and **equipped** into a slot from the
  character panel (`equipment_panel`: 工具槽 row + click-to-equip). New relic **Tool Belt**
  (`tool_belt`, +1 tool slot — `tool_slots` passive relic effect).

### ✅ Phase 10 — Curse cards (shipped 2026-06-25)
Spec: `docs/superpowers/specs/2026-06-25-curse-cards-design.md`; plan: `…/plans/2026-06-25-curse-cards.md`.
- ✅ New **`curse`** card type (+ rarity): **unplayable** (returns to hand on play) with an
  optional `end_turn_in_hand` penalty. 5 curses: 辐射尘 (pure), 漏财 (−5 gold), 铁锈 (−2 HP),
  怯懦 (Weak), 恐慌 (Frail). Purple frame + 诅咒 label; placeholder art (Codex TODO). Excluded
  from every normal card pool.
- ✅ **3 sources** (source = permanence): **enemy** `add_curse` action → shuffles a curse into
  the combat **draw pile** (temporary); **event** `add_curse` → permanent run-deck curse
  (clearable at the shop's 75g removal); **card** `add_card_to_hand` (temp) / `add_curse_to_deck`
  (perm). New effects `lose_gold` + `add_curse_to_deck`. New enemy **`hex_drone` 咒术机蛭** +
  the **`cursed_safe` 嗡鸣保险箱** event. All MCP-verified.
- ✅ **(2026-06-30) Curse-injection events**: the previously-unreachable 怯懦/恐慌/漏财 curses now
  each have a themed "greed-trap" event — `torn_coin_pouch` (+100 gold + 漏财), `deserter_charm`
  (heal to full + 怯懦), `adrenaline_shot` (+1 Strength permanent + 恐慌). All three curse cards
  are now obtainable in a run; curses are clearable at the shop's card-removal service.

### ✅ Phase 11 — Discover mechanic (shipped 2026-06-30)
Spec: `docs/superpowers/specs/2026-06-30-discover-mechanic-design.md`; plan: `…/plans/2026-06-30-discover-mechanic.md`.
- ✅ New **`discover` effect** + `DiscoverModal` (`battle_scene/discover_modal.gd`, a brand-new
  full-screen 3-choose-1 popup) + `discover_pool.gd` (filters candidates by card type or by a
  theme tag like `bleed`). The picked card enters the **current hand for this combat only**;
  optional `free` makes it cost 0 this combat (a `cost_override` card meta).
- ✅ **3 discover tools** (`blood_kit` bleed-free / `munitions_crate` attack / `field_kit` skill)
  trigger discover; they route through the same `combat_engine._apply_effect` as any card. (Demo
  discover *cards* were prototyped then **removed 2026-07-01** — discover is **tool-only** now, to
  drop the card/tool redundancy and not tax the single tool slot.)

### ✅ Phase 9 — Demo Polish (shipped 2026-06-24)
Spec: `docs/superpowers/specs/2026-06-24-demo-polish-overnight-design.md`. Driven by a 4-dimension demo review.
- ✅ **Audio overhaul**: procedural BGM regenerated ~50–60s with seamless loop points + new `shop`/`event` slots; all SFX replaced with **Kenney CC0** samples. Licensing in `assets/audio/{music,sfx}/README.md`. _(The licensed menu track was later removed — the title screen is now silent; see `main_menu._ready()`.)_
- ✅ **Economy**: 99-gold start + per-kill gold drops (toughness-scaled, elites ×2) + shop price retune — the merchant is usable across a 2-act run.
- ✅ **Wishlist CTA**: real `OS.shell_open` button on BOTH win and defeat result screens + a "full game has more" teaser (`STORE_URL` is a TODO placeholder pending the real App ID).
- ✅ **Onboarding**: rules panel now teaches Tools / Relics / Equipment / Crit / Base and fully defines Luck & Charm; also reachable from the home base.
- ✅ **Combat juice**: damage-scaled screen shake + per-hit sprite feedback (removed the ≥10 gate) + enemy-death thud + energy-orb pop.
- ✅ **Content**: 3 elites (was 1; now picks one at random per node) — `chrome_warden` + `siege_breaker` reuse existing sprites with distinct movesets; 2 Bill-pool cards (`wildfire` AoE-Burn, `lucky_streak` crit-rate source); event-node frequency bumped.
- ✅ **Settings/QoL**: Battle Speed toggle (1×/1.5×/2×); one-shot legacy-save migration (`user://meta.json` → slot 1).

---

## Known Issues & Tech Debt

| Priority | Issue |
|---|---|
| 🟢 | `Sharpened Scrap` relic's `_mark_used_once()` call is harmless dead code for non-`once_per_combat` relics — minor readability |
| P3 | Some historical generated-sheet intermediates remain for traceability; current playable cards reference PNG art only |
| ⚠️ | **The pre-2026-05-25 PixelLab key in `generate_enemy.ps1`** is in git history and should be rotated on the PixelLab side. The file now reads from `$env:PIXELLAB_API_KEY` but the old key remains exposed in historical commits. |
| P3 | Demo-polish deferred (need windowed visual verification): enemy idle-breathe + full death-fade + block/status number pops; a resolution dropdown; act-2-exclusive enemies (the 3-elite variety + per-act scaling partly cover this). |
| ⚠️ | Wishlist `STORE_URL` (`result_screen.gd`) + `steam_appid.txt` are placeholders — set the real Steam App ID before shipping the demo. |
