# Product Requirements Document
**Project:** Unnamed Sci-Fi Roguelite Card Game  
**Art Style:** Original 2D American-comic sci-fi western
**Engine:** Godot 4.6  
**Last Updated:** 2026-07-13

---

## Overview

A single-player roguelite deckbuilder set in a post-apocalyptic scrapyard wasteland. Players collect cards, relics, and equipment while fighting through escalating routes toward bosses. The visual language is locked to an original flat sci-fi cartoon direction: thick clean dark outlines, large simple shape blocks, weird sci-fi western silhouettes, broad cel shading, sparse texture, and bright toxic accent colors.

Combat is **Slay the Spire style**: the player has a hand of cards, limited energy, and must choose each turn which cards to play to survive enemy attacks while defeating them.

Project documentation is centralized in `docs/`:
- `docs/PRD.md` is the product and systems source of truth.
- `docs/PROJECT_STRUCTURE.md` maps scenes, scripts, data, and assets.
- `docs/project-rules.md` defines art, asset, naming, and architecture rules.
- `docs/art-style-reference.md` defines the approved original 2D American-comic style contract and in-game visual exemplars.

---

## Core Gameplay Loop

**Current public-demo contract:** Cowboy Bill + loadout → one 12-floor Act 1 map
→ fixed `rust_titan` boss → victory/settlement → base. There is no push-on choice
or second act in the demo. The three-act extract-or-push structure remains a
full-game ruleset behind `RunManager.DEMO_BUILD = false`.

1. **Hero Select + Loadout** - The demo uses Cowboy Bill (fixed starter deck + attribute spread); the player explicitly moves stored gear into the owned base backpack, which becomes the next-run carry
2. **Map** - Choose the next encounter node (normal / elite / rest / shop / treasure / ? event / boss) within the act's ~12-floor map
3. **Battle** - STS-style card combat
4. **Loot Reward** - Post-battle: claim gold/Scrap and optionally draft 1 new card
5. **Demo Boss Victory** - Defeat Rust Titan on floor 12; bank carried currencies while gear returns to the owned base backpack/equipment slots, show the result, and return to base
6. **Base Building** - Between runs, spend Scrap to unlock and tier-up buildings; Caps remain an inside-building service/permanent-upgrade currency

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
- `apply_short_circuit_scaled` — Apply Intelligence-scaled Short Circuit stacks to one enemy
- `overload` — Consume all Short Circuit on all enemies and deal the stored delayed damage
- `discover` — 3-choose-1 popup filtered by `pool` (a card type or theme tag such as `short_circuit`); the picked card enters the **current hand for this combat only**. Optional `free` makes it cost 0 this combat.
- Economy / curse: `gain_gold`, `lose_gold`, `heal`, `lose_hp`, `add_card_to_hand`, `add_curse_to_deck` — gold / HP swings and shuffling a card (or a permanent curse) into the deck.

> The list above is a selection. The **authoritative** set is `DataValidator.ALLOWED_EFFECT_TYPES` (33 types) — see `docs/conventions/data-files.md` for the full categorized list.

Cards built from existing effects require only JSON. A genuinely new shared effect must add a handler to `combat_engine.gd` and be registered in `DataValidator.ALLOWED_EFFECT_TYPES`.

### Player Attributes (五维属性)

| Attribute | 属性 | Effect |
|---|---|---|
| **Strength** | 力量 | Added GLOBALLY to ALL attack damage (`combat_engine._apply_effect()`, default +3); per-card `scaling` is deprecated |
| **Constitution** | 体质 | Added GLOBALLY to ALL block (default +3); replaces old "Defense" |
| **Intelligence** | 智力 | Adds +1 stack to every target status the player applies (`apply_status` / `apply_status_all`) + powers `apply_short_circuit_scaled` + boosts tool effects (+8%/pt); no longer affects XP |
| **Luck** | 幸运 | Crit chance (+2%/pt, +4% with Crit Clip, uncapped; 1.5× crit) + 1.5%/pt loot rarity + tool/equipment find chance |
| **Charm** | 魅力 | Lowers shop prices (−2%/pt, floor 0.6×) + lowers per-level XP wall (−4%/pt, floor 0.6×) + gates high-Charm event options (the old enemy-flee mechanic was deleted) |

> Equipment boosts these five stats. Attributes persist within a run via `RunManager.player_attributes`.

### Status Effects

| Status | Effect |
|---|---|
| **Short Circuit** | Stored delayed damage on an enemy; it neither ticks nor decays until an `overload` effect consumes all enemies' stacks |
| **Burn** | Deals damage when it ticks, then halves its stacks |
| **Weak** | Direct attack damage dealt is reduced by 50%; stacks decrement at end of affected character turn |
| **Vulnerable** | Direct attack damage taken is increased by 50%; stacks decrement at end of affected character turn |
| **Stun** ⚡ | Enemy skips its next turn per stack; manual-consume, no decay; enemy-only; can interrupt a telegraphed attack |
| **Regen / Thorns / Frail / Dodge** | heal-over-time / reflect-on-hit (loses 1 stack each time it triggers) / −25% block / negate one attack |
| **Metallicize / Feel No Pain** | persistent powers (StS2 port): +Block per turn / +Block on Exhaust |

### Enemy System
- Each enemy loads from `card_info/enemy/{id}.json` — includes a `sprite_id` for the art and a required encounter identity `tier` (`minion | normal | heavy | elite | boss`)
- Action types include `attack`, `attack_ramp`, `attack_status`, `attack_all`, `block`, `breakable_block`, `reflective_plating`, `heal`, `telegraph`, `summon`, `buff_self`, and `add_curse`; `DataValidator.ALLOWED_ENEMY_ACTION_TYPES` is authoritative.
- **Bosses have bespoke mechanics** via an optional `phases` field: at an HP threshold the boss runs one-time `on_enter` actions and swaps to a tougher `action_pattern`. The three act bosses: **rust_titan** (tougher phase-2 loop at 50%), **ash_warden** (debuff + summons `ember_wisp`), **junkyard_tyrant** (summons `scrap_shard` + AoE + self-heal). Killing the boss ends the fight even if summoned adds are still alive.
- **Per-act difficulty scaling**: non-boss enemy HP ×[1.0, 1.25, 1.5] and damage ×[1.0, 1.15, 1.3] by act; the enemy pool also shifts tougher each act. Bosses are exempt (tuned per-boss).
- **Intent badge** displayed above enemy HUD with emoji; multiple enemies per encounter supported

Normal nodes use four explicit base-HP bands keyed by `floor_idx + (current_act - 1) * 4`: opening 0–1 (12–18 HP), early 2–3 (20–30), mid 4–7 (25–34), and late 8+ (34–50). `heavy` enemies must be solo, post-opening `minion` enemies must be a two-minion encounter or support one `normal`, and `elite` / `boss` identities are restricted to their dedicated rosters. These budgets are checked by `DataValidator` before play.

---

## Equipment System (装备)

Equipment is gear the player equips to **boost their five attributes** via rolled **affixes**. It is NOT a passive relic — it carries direct numeric stat bonuses.

### Rules
- Player has **5 equipment slots**: head / chest / weapon / hands / accessory
- Equipment is held in the backpack and **equipped from the character panel**; it cannot be swapped during combat
- Equipment is looted from encounters (Luck-scaled), forged / reforged at the base, and sold by the Market's T2 equipment shelf
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

**Generic-shell model (2026-07-02 refactor).** Equipment is no longer bespoke per item. The pool is **15 generic shells** (`gear_{slot}_{tier}`, 5 slots × common/uncommon/rare) that share art by `slot × rarity`, plus **15 set pieces** (3 sets × 5) that keep bespoke identity/art. **Every rolled item guarantees its first affix is a random attribute (`attr_*`)**; the rest are random. All random drops route through `RunManager.roll_shell_drop(tier)` — ~15% (`SET_PIECE_DROP_CHANCE`) a set piece, else a generic shell. **Cursed has two sources:** Ascension ≥ 3 drops (`CURSE_DROP_CHANCE` on generic shells) and the Forge's base-backpack curse action. The 8 old bespoke misc items were removed.

**Demo exposure rule.** One set is featured per run. Combat rewards at the
floor-3, floor-6, and floor-9 milestones offer three distinct pieces from that
set; the milestone advances only when the player claims the item. Set activations
surface a small local combat callout, so equipment is a playable differentiator
rather than a codex-only feature.

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
At the base, the Forge acts only on gear dragged from the owned base backpack: **dismantle** into Scrap, or **reforge** a single affix. The first reforge locks the item to that affix and each later reforge costs more (rarity-base × (count + 1)); curse affixes cannot be reforged.

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

The planned full game is **3 self-contained acts**, each its own ~12-floor map ending in a single boss (`ACT_BOSSES = [rust_titan, ash_warden, junkyard_tyrant]`; tracked by `RunManager.current_act` / `advance_act()`). The current public demo deliberately caps this architecture to **Act 1 only** (`DEMO_MAX_ACTS = 1`) and fixes its boss to `rust_titan`; defeating that boss is a final victory, so the extract-vs-push flow is not shown in the demo.

### The backpack (20 cells)
All loot lives in a single **20-cell backpack** where **Gold, Scrap, and equipment compete for space**:
- **Gold** — physical stacks (≤100/cell, auto-merge, used for shop change-making). Gold does **NOT** carry across runs.
- **Scrap** — in-run salvage dropped by elites / bosses / treasure / events (≤30/cell). Not spendable in-run; banks to permanent `MetaProgress.scrap` **only on extract or final victory**. (Was "Core" before the 2026-07-07 Core-currency removal; the risk/reward is identical, only the currency name changed.)
- **Equipment** — one item per cell.

### Death, safe cells, the base backpack, and permanent storage
- **Death forfeits the entire run backpack AND equipped gear — EXCEPT "safe cells."** The first N cells are safe (base 2, +1 per Outpost safe-cells upgrade level); safe-cell equipment returns to the owned base backpack and safe-cell Scrap banks automatically.
- **Extract / final victory** banks currencies only. Carried equipment returns to the owned base backpack (`RunManager.pending_loadout`) and worn equipment returns to the owned base slots (`pending_equipped`).
- The permanent stash (`MetaProgress.stash`) is storage only. It changes only through an explicit player drag between StashWindow and the base backpack/slots; settlement, Market purchases, Forge crafting, and bounty equipment do not auto-store gear.

### Full-game extraction choice (not active in the one-act demo)
> **🚪 EXTRACT** — bank the Scrap in your backpack now and return to base (lower, but guaranteed).
>
> **⬆ PUSH ON** — take more Scrap (into the backpack, still at death risk) and continue to the next act (regenerates a fresh act map).

### End States

| Outcome | Result |
|---|---|
| Extract after an act boss | Carried Scrap/Caps bank; gear returns to the owned base backpack/slots; stash is unchanged; run ends |
| Push on | More Scrap into the backpack (still at death risk); next act map generated |
| Clear the final-act boss | Full victory — currencies bank; gear returns to the owned base backpack/slots |
| Die on any floor | Lose the backpack + equipped gear, EXCEPT safe-cell contents; stash is unchanged |

---

## Base Building System (基地建造)

Between runs, players return to their **home base**: 4 illustrated buildings with
**icon-only circular entry markers** floating above them (no name/level plaques),
a **giant START button** bottom-centre with a **difficulty button** above it (opens an
A0-A5 picker popup), a **top-left currency HUD** (Caps + Scrap chips in
`home_base_scene.gd`), a compact **bounty board** panel bottom-left (held contracts + live
progress only — no reward seals or refresh countdown; see "Bounty System" below), and three
**nav image buttons bottom-right** — Warehouse
(stash), Character (hero headshot) and Gallery (card codex — see "Card Gallery" below).
**Two** meta-currencies fund the base (the third, **Core**, was removed 2026-07-07):
**Scrap** (Forge services + **building unlocks/tier-ups**) and **Caps** (Clinic / Market services +
Outpost permanent upgrades). See `meta_progress.gd` `BUILDING_DEFS`
+ `building_cost_currency()`.

**Windowed UI (2026-07-02/03 refactor).** The base uses Diablo-style **draggable,
coexisting windows** (`run_system/ui/window/`). Pressing **i** (home base / map / battle)
toggles the **CharacterWindow** — Diablo-4 layout: paper-doll CENTER, equip slots flanking
it (head/chest/hands left; weapon/accessory + tools right), **backpack grid BELOW**; modes:
`base` / `map` (editable) / `battle` (read-only). **Backpack ≠ stash (D4 model):** the
**StashWindow** (25-slot storage, own window via the right-edge Stash button) is pure
storage — gear must be dragged stash→backpack to be carried/equipped (equip slots reject
stash payloads), backpack→stash to store; at base the backpack grid IS the next-run carry
list (`pending_loadout`). Clicking the **Forge** opens the **ForgeWindow** (craft /
dismantle / reforge / curse as 4 tabs) beside the character window — cross-window drag.
ESC closes the topmost window. Clinic / Market / Outpost still open fullscreen pages. The
former Warehouse building was **removed** (loadout → CharacterWindow+StashWindow; resource
conversion → Market T3; stash cap flat 25).

Every building opens even at tier 0. Its integrated top bar owns the upgrade icon,
Caps balance, centered building identity, and close control. Clicking the upgrade icon
opens the shared `building_upgrade_popover.gd`, which shows the current/next tier and
Scrap cost. Locked facilities keep their service content hidden until unlocked. The
Forge uses the same popover but keeps its distinct workbench header composition.

### The 4 buildings
| Building | Role |
|---|---|
| **Forge (锻造)** | Draggable 4-tab window (lightline icon-tabs): dismantle → Scrap incl. **bulk dismantle by rarity** (confirm dialog; set/cursed gear excluded); craft / reforge / curse (tier-gated, Scrap) |
| **Clinic (诊所)** | Caps-bought permanent attribute perks + a Max-HP perk (tier raises the cap) |
| **Market (黑市)** | Caps tool shop + stock refresh (T1); Caps equipment shop (T2); resource conversion **Caps↔Scrap** bidirectional (T3). All non-curse, non-basic cards are draftable by default — no card-unlock system. _(The daily bounty shelf moved to the Outpost 2026-07-07.)_ |
| **Outpost (前哨站)** | **Bounty center** (T1, see "Bounty System"): daily shelf, taking is **FREE**, max 3 held; **safe cells** (T2); Caps **permanent upgrades** (T3): starting gold / backpack size / reward-reroll tokens / tool slots. _(The starter-deck editor and in-run shop-discount upgrade were **removed** 2026-07-07; the difficulty selector lives above the home-screen START button, not in any building.)_ |

### Rules
- **Building unlocks and tier-ups both cost Scrap** (`building_cost_currency()`).
- Caps/Scrap are earned by extracting or completing runs — NOT from dying.
- Building unlocks + tiers persist permanently across runs (true meta-progression).
- Hero selection + next-run loadout live in the CharacterWindow's base mode (press **i**).
- Retired hidden tracks (`med_bay`, `starter_boost`, `scrap_workshop`) are removed; old save levels are refunded once and erased.

---

## Bounty System (悬赏契约)

Contracts taken at the **Outpost** (they replaced the old mock daily-tasks panel; moved
from the Market 2026-07-07 and taking became **free**). Held contracts show on the
home-base **bounty board** (bottom-left) with live progress. Specs:
`docs/superpowers/specs/2026-07-05-bounty-system-card-codex-design.md` +
`…/2026-07-07-concept-parity-building-ui-design.md`. Contract data:
`run_system/data/bounties/{bounty_id}.json` (validated by `validate_bounty` in
`data_validator.gd` — the schema is `id / title / objective{type,count} / reward /
tier [, price]`; `price` is a legacy optional field, **ignored at runtime**). Catalog
page: `docs/catalog_html/bounties.html`.

### Daily outpost shelf (T1 `bounties`)
- Every local-date change rerolls a **3-contract shelf** at the Outpost — **all free to
  take** (no Caps price, no once-per-day free-claim cap). The roll is seeded with the
  date, so re-entering on the same day keeps the same shelf; already-held ids are excluded.
- The shelf refresh runs on base entry AND outpost entry (`refresh_bounty_shelf_if_stale`).

### Holding & settling
- **Max 3 held** contracts (board full ⇒ the outpost's take buttons grey out). Held contracts **never
  expire** — they stay on the board until completed (the daily reroll never touches them).
- Progress ticks **only while a run is active** (`RunManager.bounty_event` gates on
  `is_run_active`); base/menu activity never counts.
- **Instant settle**: the moment a contract's count is reached mid-run, the reward pays out
  immediately (a toast announces it at base) — no manual turn-in step.
- Rewards: any of **Caps / Scrap** (ints) and/or an **equipment drop tier**
  (common/uncommon/rare — rolled via `roll_shell_drop` into the active run backpack,
  with the owned base backpack as the defensive out-of-run fallback).

### Objective types (7)
`play_attack_cards` · `earn_gold` · `kill_enemies` · `kill_elites` · `kill_boss` ·
`extract_alive` · `upgrade_cards` (campfire upgrades). Two-place rule: each type is
emitted somewhere via `RunManager.bounty_event` AND listed in
`ALLOWED_BOUNTY_OBJECTIVES` (`data_validator.gd`).

> **`earn_gold` 口径**: counts all gold **entering the backpack** during an active run
> (kill drops, reward payouts, extraction bonus). Starting gold and save-resume restores
> do NOT count; spending gold never subtracts.

Launch set: **10 contracts** (7 standard, 3 hard) — see the bounties catalog page for the
objective/reward table.

### Card Gallery (卡牌图鉴)
The **Gallery** nav button (home base, bottom-right) opens the card codex: every player
card in the game, with a **collected counter**. Demo rule: **used = unlocked** — a card
unlocks the first time it is *played* in battle (`MetaProgress.mark_card_seen`, persisted
in `cards_seen`, write-throttled to new ids). Locked entries render as the battle
card-back. There is no other unlock path (drafting alone doesn't count).

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
| `gold` | In-run currency for shops (not banked across runs) |
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
- **Normal**: Gold + a 3-choose-1 **Card Draft** + a Luck-scaled **Tool** + a Luck-scaled **common Equipment** (independent rolls).
- **Elite**: Card Draft + a Luck-scaled **uncommon Equipment** (no tool).
- **Boss**: a guaranteed **rare Equipment**.
- Gold is a flat per-fight amount (Luck no longer scales gold). Tools and equipment claim into the **backpack**; tools are then equipped into a tool slot from the character panel.

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
	"tier": "minion | normal | heavy | elite | boss",
    "max_health": 30,
    "action_pattern": [
        { "type": "attack", "amount": 6, "label": "⚔ 6" },
        { "type": "block",  "amount": 8, "label": "🛡 8" }
    ]
}
```

---

## Art Style - Original 2D American-Comic Sci-Fi Western

The definitive direction is an **original flat 2D American-comic sci-fi western**:
clean dark outlines, large readable shape blocks, sparse interior linework, broad
two-to-three-value cel shading, unusual desert forms, salvage-tech silhouettes,
dusty leather and brass, dented grey-green robot metal, patched red cloth, hoses,
antennas, odd gadgets, and restrained cyan/orange/toxic accents. UI follows the
lightweight UI07 language: thin ink-and-brass borders, charcoal fills, simple
silhouettes, and minimal material noise.

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
| **Style target** | Original flat 2D American-comic sci-fi western matching the approved in-game exemplars: clean outlines, broad shapes, sparse texture, lightweight UI07 panels, and original designs only; no copied characters, logos, scene layouts, or franchise-specific props. |
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
original flat 2D American-comic sci-fi western game art, matching the approved in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png, battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and run_system/assets/images/map/wasteland_route_map_pixel_bg.png, clean dark cartoon outlines, large simple shape blocks, sparse interior lines, broad two-to-three-value cel shading, unusual western wasteland silhouettes, salvage-built machinery, dusty leather, brass, dented grey-green robot metal, patched red cloth, hoses, antennas, odd gadgets, cyan and warm orange accents used sparingly, clean game-ready edges, readable silhouettes, low texture noise, no text, no labels, no UI frame, no logo, no copied franchise characters or props, no exact scene copies
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

> The numbered phases below are a historical delivery log, not a second source of
> current gameplay truth. When a historical bullet conflicts with the demo contract
> above, the current contract and the latest superseding phase win.

### ✅ Phase 15 — Concept-parity building UI rebuild (shipped 2026-07-07)
Spec: `docs/superpowers/specs/2026-07-07-concept-parity-building-ui-design.md`.
Function reference: `docs/building-screens-functions.md`.
- ✅ **Lightline component library**: Codex imagegen sheets sliced into a named PNG kit —
  `run_system/assets/images/ui_kit_lightline/` (89 pieces + `manifest.json` with 9-slice
  margins) — consumed via `wasteland_theme.gd` `ll_*` StyleBox hooks (`ll_panel` /
  `ll_titlebar` / `ll_section` / `ll_inset` / `ll_button(_olive)` / `ll_slot`).
- ✅ **Forge window rebuilt to concept**: 4 icon-tabs + vertical **bulk dismantle by rarity**
  (all/common/uncommon/rare with confirm dialog; **set + cursed gear excluded**).
  Every Forge action consumes or mutates the owned base backpack; the Forge never reads the stash.
- ✅ **Outpost rebuilt to concept**: **bounties moved here from the Market** — daily shelf,
  taking is **FREE** (`price` now optional/ignored in `validate_bounty`); safe cells (T2);
  Caps permanent upgrades (T3): starting gold / backpack / reward-reroll tokens / tool
  slots. **Removed**: starter-deck editor + in-run shop-discount upgrade + the in-building
  difficulty selector (difficulty stays above the home START button).
- ✅ **Market**: bounty shelf dropped; reskinned to concept (tools T1 / equip T2 / convert T3).
- ✅ **Clinic**: reskinned to concept (lightline cards/rows; logic unchanged).

### ✅ Phase 14 — Core currency removed → two-currency economy (shipped 2026-07-07)
Spec: `docs/superpowers/specs/2026-07-07-remove-core-currency-design.md`.
- ✅ **Meta Core deleted** from `MetaProgress` (var / `core_changed` signal / `add_core` /
  `spend_core` / save field all gone). Old saves' `core` balance is **discarded, not
  migrated** — `load_progress` is fault-tolerant on the stale key.
- ✅ **Two-currency mapping**: building **unlocks and tier-ups cost Scrap**
  (`unlock_building`/`upgrade_building`; `building_cost_currency(id)` always returns
  `"scrap"` for building actions), while Outpost permanent upgrades cost Caps.
- ✅ **In-run Core → Scrap rebrand**: battle drops + `total_run_scrap()` +
  `add_scrap_to_backpack()` bank to `MetaProgress.scrap` on extract/victory (same risk/reward,
  backpack cell kind `"scrap"`).
- ✅ **Market convert** is now **Caps↔Scrap bidirectional** (Core→Caps row dropped).
- ✅ **Contract rewards**: `elite_purge`/`head_hunter` core rewards → Scrap; validator drops
  `core` from allowed bounty currencies; `gain_core` event effect → `gain_scrap` (4 events).
- ✅ **UI**: currency HUD shows only Caps + Scrap; building unlock and upgrade badges both use Scrap.

### ✅ Phase 1 — Core Combat (Complete)
- STS card play loop (draw 3 / play / discard / enemy turn)
- Attack card drag-to-target with arrow
- Skill/ability cards via play zone
- Data-driven effect system (effects[] in JSON)
- Enemy intent system with action patterns
- Player HP / block / energy UI (CharacterHUD)
- Draw pile / discard pile viewer (Q/E shortcuts)
- Status effect system (Short Circuit, Burn, Weak, Vulnerable, Stun, Regen, Thorns, Frail, Dodge, and persistent Bill powers)
- Combat sprites with static rest poses and attack animations

### ✅ Phase 2 — Run System & Content (prototype complete; superseded by current demo contract)
- Selectable encounter map evolved into the current authored 12-floor demo act.
- Public demo ends at the fixed Rust Titan boss; the three-act/extraction architecture is retained
  only for the later full-game build.
- Bill uses a fixed 9-card starter deck (4 Shoot, 1 Weakening Shot, 4 Defend) and a curated 28-card demo reward pool.
- Normal/elite/boss rewards now include the current card, tool, relic and equipment economy;
  three planned set pieces are surfaced before the boss so the equipment differentiator is playable.

### ✅ Phase 3 — Equipment & Relics (Complete)
- ✅ Equipment system: 5 body-part slots, **rolled affixes** (5-tier common/uncommon/rare/set/cursed = 1/2/3/3/3+curse; `affix_pool.gd`; **each item guarantees 1 attribute affix**), 3 sets with tiered bonuses (3-piece / 5-piece). Gear = **15 generic shells** (`gear_{slot}_{tier}`, art shared by slot×rarity) + **15 set pieces**; set/cursed derived at roll time; cursed drops at Ascension ≥ 3 or via the forge. _(2026-07-02: replaced the 8 bespoke misc items.)_
- ✅ Inventory (8-item cap) — later superseded by the 20-cell Extraction Backpack where Gold/Core/equipment share cells (see Extraction Backpack Economy)
- ✅ Equipment drops are Luck-scaled (normal = common, elite = uncommon, boss = guaranteed rare; see 2026-06-22 economy pass); the treasure node is a 3-choose-1 relic pick
- ✅ Relic system: passive run effects, JSON-driven (RelicEffectSystem)
- ✅ Shop scene (merchant node): 6 cards + 3 tools + 3 relics + remove-card service (75g) — equipment is no longer sold
- ✅ Rest site: choice between Heal 25% HP and Upgrade a Card (opens `card_upgrade_modal.gd`)
- ✅ Card upgrade system: in-run per-card upgrades resolved by `card_upgrade.gd` (deck entries carry an `upgraded` flag, applied at battle start). **Hybrid model**: a card either carries a bespoke `upgrade` block (overrides any of cost/title/description/effects; effects = full replacement) or falls back to a generic numeric formula (`deal_damage` +2, `gain_block` +3, attribute/energy gains +1, `apply_status` stacks +1, `draw_cards` +1); **curses are never upgradeable**. Growth axes: rest campfire = heal-or-upgrade-a-card; elites give a card + Luck-scaled equipment (no gem); boss gives a guaranteed rare relic/equipment. The interim gem-socket system that briefly replaced upgrades was removed 2026-07-02. _(Deferred: 力量流档案扩充 — a broader Strength-archetype profile expansion is a future pass, not in this refactor.)_
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
- ⛔ Historical Card Research upgrade removed; all eligible cards are draftable by data/pool rules.

### 🟡 Phase 5 — Content Expansion (in progress)
- ✅ Cowboy Bill kit: Shoot/Defend basics plus Short Circuit, global Overload, Loaded, reload, and critical-hit packages. (A second "Feng Shui Master" yin/yang hero was prototyped then **cut** 2026-06-18 — the demo ships Bill-only. Vestigial polarity plumbing remains inert for save compatibility.)
- ✅ 45 player card JSON files (including 5 curses and 2 starter basics); Bill's demo rewards use the focused 28-card pool in `MetaProgress.DEMO_REWARD_POOLS`.
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
> ⚠️ **Gem system removed 2026-07-02.** In-run card upgrades (`card_upgrade.gd` + rest-campfire modal) were restored as the growth axis and the entire gem system (data / socket UI / rewards / `gem_inventory`) was deleted; old saves migrate by stripping gem data. The gem bullets below are historical.
See `docs/superpowers/specs/2026-06-09-gems-leveling-rewards-design.md` for the full design.
- ⛔ ~~**Gem-socket system** (replaces card upgrades): run-scoped gems (`run_system/data/gems/*.json`, cleared on death), 1 socket/card, inserted out of combat and **locked after**.~~ **REMOVED** 2026-07-02 — card upgrades restored.
- ✅ **In-run XP / level**: kill enemies → XP; each level-up grants a **pick-1-of-3 random attribute (+1)**. (Intelligence no longer scales XP — **Charm** lowers the per-level XP wall instead, −4%/pt.) `RunManager.xp / level / gain_xp / xp_to_next / pending_attr_points`.
- ✅ **Starting attributes = 0** (heroes grow via level-ups / gear).
- ✅ **Rewards by node type** (updated 2026-07-02): normal = gold + 3-choose-1 card draft + Luck-scaled tool + Luck-scaled common equipment; elite = card + Luck-scaled uncommon equipment; boss = guaranteed rare equipment. (Equipment drops from normal/elite too, not boss-only. The interim gem draft slots were removed with the gem system.)
- ⛔ The direct StS2 Ironclad-port model is superseded. Current cards use original Cowboy Bill mechanics and visuals; see the current card redesign spec and generated catalog.

### ✅ Phase 8 — Tools · Equipment Economy · A0 Balance (shipped 2026-06-21..22)
Specs: `docs/superpowers/specs/2026-06-21-tools-attrs-loading-base-ui-design.md`, `…/2026-06-22-balance-equipment-economy-design.md`.
- ✅ **Tool system** (StS2-style one-time consumables): `run_system/data/tools/*.json` (11: 8 original + 3 discover tools added 2026-06-30), a top-bar **tool shelf** (`run_top_bar.gd`), confirmation before use, and explicit arrow/click target selection for enemy tools. Cancellation never consumes the item; effects reuse `combat_engine._apply_effect`, scaled ×(1+0.08·INT). _Tool slots reworked in Phase 9 → **1 base slot**, tools held in the backpack + equipped from the character panel; see below._
- ✅ **Attribute rework**: the Charm enemy-**flee** mechanic was **deleted**; INT off XP → boosts tools and player-applied statuses, especially Short Circuit; Charm lowers the per-level XP wall.
- ⛔ ~~**Gems → backpack** (1 gem = 1 cell; socketing frees the cell), replacing the unlimited `gem_inventory` side-list.~~ Moot — the gem system was removed 2026-07-02.
- ✅ **Drop / shop restructure**: shop sells tools (not equipment); Luck-scaled tool + equipment drops (see Rewards by node type).
- ✅ **Loading**: session card-info cache (`MetaProgress.get_card_info_cache` + `cached_card_factory.gd`) skips the per-battle JSON re-parse.
- ✅ **Building detail pages** redesigned for four buildings. The current UI integrates identity/actions into the top bar and opens a shared compact `building_upgrade_popover.gd`; Forge retains its distinct workbench header.
- ✅ **A0 balance pass**: deflated the over-statted 1-cost cards, raised enemy aggression (block→attack), retuned the Act-1 boss `rust_titan` into a 2-3-try skill gate (geared+leveled clears comfortably).

### ✅ Phase 9 — Base/shop/forge UI + tool-system rework (shipped 2026-06-25)
Spec: `docs/superpowers/specs/2026-06-25-base-shop-forge-tools-overhaul.md`.
- ✅ **Historical — building unlock/upgrade → the overview**: this phase used a button under
  each building's floating "Lv<n> Name" label (or 🔒) and a confirm popup. _Superseded by the
  current icon-only overview: clicking any building opens it, and the top-bar upgrade icon opens
  the shared upgrade popover; locked services remain hidden._
- ✅ **Building detail pages are fullscreen** (the shared shell fills the viewport minus a frame
  margin), so big grids fit. The stash window shows the full **25-slot** storage grid.
- ✅ **Market (黑市)**: equipment sits on a **shelf** (rarity-framed icon tiles + price), and the
  card-unlock / card-shop sections render **real card art** (`my_card_factory`).
- ✅ **Forge (铁匠铺) bench**: originally shipped with an embedded stash grid; superseded by the
  current backpack-only workbench and vertical bulk-dismantle list. Drag gear from CharacterWindow,
  then Dismantle/Reforge/Curse it in place; Craft adds the result to the base backpack.
- ✅ **Tool rework**: `tool_slots()` base 2 → **1** (+ Outpost Tool Rack + relic). Tools are now
  **held in the backpack** (`{"kind":"tool"}` cells) and **equipped** into a slot from the
  character panel (`equipment_panel`: 工具槽 row + click-to-equip). New relic **Tool Belt**
  (`tool_belt`, +1 tool slot — `tool_slots` passive relic effect).

### ✅ Phase 10 — Curse cards (shipped 2026-06-25)
Spec: `docs/superpowers/specs/2026-06-25-curse-cards-design.md`; plan: `…/plans/2026-06-25-curse-cards.md`.
- ✅ New **`curse`** card type (+ rarity): **unplayable** (returns to hand on play) with an
  optional `end_turn_in_hand` penalty. 5 curses: 辐射尘 (pure), 漏财 (−5 gold), 铁锈 (−2 HP),
  怯懦 (Weak), 恐慌 (Frail). They are excluded from every normal card pool and use a dedicated
  no-cost dark-purple shell plus production illustrations.
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
  theme tag like `short_circuit`). The picked card enters the **current hand for this combat only**;
  optional `free` makes it cost 0 this combat (a `cost_override` card meta).
- ✅ **3 discover tools** (`blood_kit`, displayed as Circuit Kit, uses the `short_circuit` pool / `munitions_crate` attack / `field_kit` skill)
  trigger discover; they route through the same `combat_engine._apply_effect` as any card. (Demo
  discover *cards* were prototyped then **removed 2026-07-01** — discover is **tool-only** now, to
  drop the card/tool redundancy and not tax the single tool slot.)

### ✅ Phase 12 — Market retier + all-cards-draftable (shipped 2026-07-02)
- ✅ **Removed the base card-unlock/card-shop system**: deleted `MetaProgress.unlock_card` /
  `buy_card_caps` and the `unlocked_cards` / `purchased_cards` save fields. Every non-curse,
  non-basic (`strike`/`defend`) card is now draftable by default — `get_unlocked_card_pool()`
  directory-scans `battle_scene/card_info/player/*.json` instead of reading an unlock list in
  the full-game path. The public Bill demo uses a curated 28-card reward pool so its combat
  identity is not diluted (hero-exclusive cards still gate through `HERO_EXCLUSIVE_CARDS`).
- ✅ **Market (黑市) retiered**: T1 **tool shop** (3 random tools from the whole pool, flat 40
  Caps each, added straight to the backpack); T2 **equipment shop** (unchanged rarity-priced
  Caps shelf, just moved from T1); T3 **refresh** (re-roll both stocks for Caps, price rises
  +10 each use for the visit). `BUILDING_DEFS["market"].functions` is now
  `{tool_shop:1, equip_shop:2, refresh:3}`.
  _(2026-07-05: the daily **bounty shelf** joined the Market at T1 — see Phase 13. 2026-07-07: it moved on to the Outpost, free to take — see Phase 15; market `functions` back to `{tool_shop:1, equip_shop:2, resource_convert:3}`.)_

### ✅ Phase 13 — Bounty system + card gallery (shipped 2026-07-05)
Spec: `docs/superpowers/specs/2026-07-05-bounty-system-card-codex-design.md`; plan: `…/plans/2026-07-05-bounty-system-card-codex.md`.
- ✅ **Bounty contracts** (see "Bounty System" section): 10 JSON contracts in
  `run_system/data/bounties/` + `validate_bounty` schema; daily date-seeded Market shelf
  (1 free + 2 paid, T1) _(2026-07-07: shelf moved to the Outpost, ALL takes free — see
  Phase 15)_; max-3 bounty board on the home base (replaces the mock
  daily-tasks panel with real data); 6 in-run `bounty_event` hooks (attack plays, gold
  into backpack, kills, elites/boss, extraction, campfire upgrades); instant settle with
  Caps/Core/Scrap/equipment rewards _(Core rewards → Scrap in Phase 14)_.
- ✅ **Card gallery**: Gallery nav button at base opens the codex — all player cards,
  used = unlocked (`MetaProgress.cards_seen`, marked on first play), locked cards show the
  card back, collected counter.

### ✅ Phase 9 — Demo Polish (shipped 2026-06-24)
Spec: `docs/superpowers/specs/2026-06-24-demo-polish-overnight-design.md`. Driven by a 4-dimension demo review.
- ✅ **Audio overhaul**: procedural BGM regenerated ~50–60s with seamless loop points + new `shop`/`event` slots; all SFX replaced with **Kenney CC0** samples. Licensing in `assets/audio/{music,sfx}/README.md`. _(The licensed menu track was later removed — the title screen is now silent; see `main_menu._ready()`.)_
- ✅ **Economy**: 99-gold start + per-kill gold drops (toughness-scaled, elites ×2) + shop price retune — the merchant is usable within the one-act demo.
- ✅ **Wishlist CTA**: result screens expose an `OS.shell_open` button only when `application/config/store_url` is a real Steam `/app/…` URL. Development builds no longer send players to the generic Steam homepage.
- ✅ **Onboarding**: rules teach Tools / Relics / Equipment sets / Crit / Base and fully define Luck & Charm; the first-battle sequence is persisted only after its final page is completed.
- ✅ **Combat juice**: damage-scaled screen shake + per-hit sprite feedback (removed the ≥10 gate) + enemy-death thud + energy-orb pop.
- ✅ **Content**: 3 elites (was 1; now picks one at random per node) — `chrome_warden` + `siege_breaker` reuse existing sprites with distinct movesets; Bill-pool card `lucky_streak` (crit-rate source); event-node frequency bumped. `wildfire` was removed, but Burn remains an enemy/status mechanic.
- ✅ **Settings/QoL**: Battle Speed toggle (1×/1.5×/2×); one-shot legacy-save migration (`user://meta.json` → slot 1).

---

## Known Issues & Tech Debt

| Priority | Issue |
|---|---|
| 🟢 | `Sharpened Scrap` relic's `_mark_used_once()` call is harmless dead code for non-`once_per_combat` relics — minor readability |
| P3 | Historical generated-sheet intermediates remain for traceability but are excluded from Godot import with `.gdignore`; current runtime references only production assets. |
| ⚠️ | **The pre-2026-05-25 PixelLab key in `generate_enemy.ps1`** is in git history and should be rotated on the PixelLab side. The file now reads from `$env:PIXELLAB_API_KEY` but the old key remains exposed in historical commits. |
| P3 | Windowed visual verification is still needed at every supported aspect ratio; enemy idle-breathe/full death-fade and a resolution dropdown remain polish candidates. |
| ⚠️ | `steam_appid.txt` is still the test App ID `480`; set the real App ID and `application/config/store_url` before shipping the demo. |
