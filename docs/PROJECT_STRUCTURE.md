# Project Structure - Roguelite Card Game (Offbeat Adult Sci-Fi Cartoon Wasteland)

This guide provides a precise map of the codebase for adjusting the UI, logic, and assets.

## Documentation

All first-party project documentation lives in `docs/`.

*   **Product Requirements**: `docs/PRD.md`
    *   *Product scope, gameplay systems, roadmap, and known tech debt.*
*   **Project Structure**: `docs/PROJECT_STRUCTURE.md`
    *   *This file. Use it as the quick map for code, scenes, data, and assets.*
*   **Project Rules**: `docs/project-rules.md`
    *   *Non-negotiable art direction, asset pipeline, naming, and architecture rules.*
*   **Art Style Reference**: `docs/art-style-reference.md`
    *   *Approved Offbeat Adult Sci-Fi Cartoon Wasteland style contract for all future assets.*

The old root-level `skills/` workflow docs have been removed. Project conventions should be documented here or in `docs/project-rules.md`.

---

## 🃏 Card System (UI & Data)

### 🎨 Visuals & UI Adjustment
*   **Main Card Scene**: `battle_scene/play_card.tscn`
    *   *Where to adjust nodes, banners, font sizes, and container positions.*
*   **Card Logic & Colors**: `battle_scene/play_card.gd`
    *   *Where the live math is calculated and Rarity Colors (Silver/Blue/Golds) are defined in `RARITY_COLORS`.*
*   **Shape & Effects**: `battle_scene/card_art_mask.gdshader`
    *   *The shader that handles the "Angled Bottom" shape for Attack cards.*

### 📄 Card Data (JSON)
*   **Player Cards**: `battle_scene/card_info/player/`
    *   *Where individual cards (Strike, Defend, etc.) are defined with their stats, rarity, and effects.*
*   **Enemy Cards**: `battle_scene/card_info/enemy/`
    *   *Definitions for enemy moves and behavior patterns.*

---

## ⚔️ Battle Scene (Combat & Layout)

### 🏗️ Battlefield UI
*   **Main Scene**: `battle_scene/battle_scene.tscn`
    *   *The root scene where nodes for the Player, Enemies, and Deck are positioned.*
*   **Battle Manager**: `battle_scene/battle_scene.gd`
    *   *Handles high-level battle transitions and UI refreshes when stats change.*
*   **Targeting**: `battle_scene/targeting_arrow.gd`
    *   *Logic for the "Zap" arrow when playing Attack cards.*

### ⚙️ Combat Logic
*   **Core Engine**: `battle_scene/combat_engine.gd`
    *   *The brain of the game. It resolves all card effects (damage, block, buffs) triggered by JSON data.*
*   **Status Effects**: `battle_scene/status_effect_system.gd`
    *   *System for managing bleed, burn, weak, vulnerable, double damage, and other buffs/debuffs.*
*   **Discover**: `battle_scene/discover_modal.gd` (full-screen 3-choose-1 popup) + `run_system/core/discover_pool.gd` (rolls candidates by card type / theme tag). Driven by the `discover` effect in `combat_engine._apply_effect`; the picked card enters the hand for this combat only (optional `free` = 0-cost via a `cost_override` meta). Triggered by the 3 discover **tools** (`blood_kit`/`munitions_crate`/`field_kit`) — the demo discover *cards* were removed 2026-07-01, so discover is tool-only. Candidates suppress the "playable" glow and drive their keyword tooltip from the overlay button.

---

## 🗺️ Progression & Meta-Progression

### 💰 Loot & Rewards
*   **Reward Screen**: `run_system/ui/loot_reward.gd`
    *   *Loot by node type: normal = gold + 3-choose-1 card draft (Luck may swap a slot for a gem); elite = card + gem 3-choose-1 + equipment; boss reward handled in `battle_scene._victory`. After PROCEED it spends queued level-up attribute picks (`pending_attr_points`, pick 1 of 3 attributes).*
*   **Card Factory**: `addons/card-framework/json_card_factory.gd`
    *   *Loads `card_info/player/{card_id}.json` and returns Card nodes.*

### 🛒 Shop & Rest
*   **Shop Scene**: `run_system/ui/shop_scene.tscn` + `.gd`
    *   *Merchant map node loads this. Rolls 3 cards + 3 tools + 3 relics + remove-card service (equipment is no longer sold here). Prices and pools defined at the top of the script.*
*   **Rest Choice Modal**: built inline in `map_scene.gd` (`_open_rest_choice`)
    *   *HEAL 25% HP or SOCKET GEMS (opens the deck/gem screen).*

### 💎 Gem / Socket System (replaced card upgrades)
*   **Gem data**: `run_system/data/gems/{gem_id}.json` — run-scoped socketables; `effects[]` reuse the card effect vocabulary and fire when the socketed card is played. Schema in `data_validator.gd` (`validate_gem`).
*   **Socket screen**: `run_system/ui/run_deck_viewer_modal.gd` — each deck card shows its 1 socket; insert a gem from the **backpack** (`backpack_gem_ids()`), **locked after** (no removal this run). Socketing frees the gem's backpack cell.
*   **Mechanic**: `player_deck` entries carry a `gems: []` array; battle cards get a `gems` meta (`deck_manager.gd`); `combat_engine.resolve_card_effect` runs each gem's effects after the card's own. Card upgrades (`_plus`) were fully removed.

### 🎒 Equipment System
*   **Data**: `run_system/data/equipment/{item_id}.json` (**15 generic shells** `gear_{slot}_{tier}` sharing art by slot×rarity + **15 set pieces**, 3 sets × 5) + `run_system/data/equipment_sets/{set_id}.json` (3 sets). Rarity is **5-tier** (`run_system/core/affix_pool.gd`): common/uncommon/rare/set/cursed roll 1/2/3/3/3 affixes, **each guaranteeing 1 attribute affix** — `set` = a piece carrying a `set_id` (green, grants set bonuses), `cursed` = 3 positives + 1 curse affix (red). Drops route through `RunManager.roll_shell_drop(tier)` (~15% a set piece, else a shell; cursed at Ascension ≥ 3 or via the forge). Instances roll affixes at drop time (`make_equip_instance`).
*   **Set Effect System**: `battle_scene/equipment_set_system.gd` — snapshots active tier effects at battle start; mirrors `relic_effect_system.gd` shape.
*   **Equipment Icon Component**: `run_system/ui/equipment_icon.gd` — tile colored by **rarity** (common/uncommon/rare/set/cursed → graphite / steel-blue / gold / green / red) with a slot PNG icon (slot-letter fallback when the PNG is missing).
*   **Character Panel**: `run_system/ui/equipment_panel.gd` — map-screen modal showing HP/Gold/Floor + slots + inventory + active sets + relics + stats. Open via `⚔ CHARACTER` button.
*   **Inventory Full Modal**: `run_system/ui/inventory_full_modal.gd` — discard-or-skip flow when bag overflows.

### ❓ Random Events
*   **Event Modal**: `run_system/ui/event_modal.gd`
    *   *The "?" map-node event scene. Loads an event from `run_system/data/random_events/*.json`, presents the choices, and applies the chosen outcome.*

### 🏃 Run Management
*   **Run Shape**: a run is **3 self-contained acts**, each a ~12-floor map ending in a boss. Loot lives in a **20-cell backpack** where Gold / Core / equipment compete for space, with safe-cells preserved on death, a permanent base stash, and a next-run loadout (`RunManager.backpack` / `RunManager.pending_loadout`; `MetaProgress.stash`).
*   **Global State**: `run_system/core/run_manager.gd` (autoload)
    *   *Gold, deck, equipped items, inventory, base_attributes, player_attributes (computed), relics, gems (in backpack cells), tools (**equipped** in `tool_inventory`, **held** in backpack `{"kind":"tool"}` cells), XP/level, map state. Public API: `add_card_to_deck`, `remove_card_from_deck_by_uid`, `socket_gem` / `gem_pool` / `get_gem_data`, `gain_xp` / `xp_to_next`, `equip_to_slot`, `unequip_slot`, `add_to_inventory`, `discard_from_inventory`, `add_tool_to_backpack` / `equip_tool_from_backpack` / `unequip_tool` / `tool_slots` (1 base + Outpost + relic), `purchase_*` (shop-gated wrappers), `recompute_attributes`, `get_active_set_tiers`. `start_new_run` calls `_apply_meta_upgrades` to read MetaProgress and add max HP / starting gold / starter inventory.*

### 🏠 Base Building (Meta-Progression)
*   **Persistent State**: `run_system/core/meta_progress.gd` (autoload, owns `user://slot_<n>/meta.json` — 3 save slots; the legacy global `user://meta.json` is no longer read) — three currencies (**Core / Caps / Scrap**) + `buildings{}` (per-building tier) + `BUILDING_DEFS`. API: `add_core/caps/scrap` + `spend_*`, `get_building_tier`, `is_building_unlocked`, `unlock_building`, `upgrade_building`, `building_can`, `unlock_card`, `set_starter_deck_override`, `stash` + `dismantle_stash_item` / `reforge_stash_item_locked` (single-affix lock + escalating cost) / `curse_stash_item`.
*   **Boot Scene**: `run_system/ui/home_base_scene.{gd,tscn}` — Core/Caps/Scrap bar + 5 building tiles laid out 2-left / 2-right with a centre START "door" (Warehouse above it). Clicking a tile opens its screen.
*   **Building Screens**: `run_system/ui/buildings/{forge,clinic,market,outpost,warehouse}_screen.gd` (subclass `building_screen_base.gd`) — **fullscreen, services-only** pages (the shared shell fills the viewport); `home_base_scene` convention-loads `<id>_screen.gd`. **Unlock/upgrade moved to the home-base overview** (a button under each building's floating label → confirm popup → `MetaProgress.unlock/upgrade_building`), not in the detail page. Per-building: market = equipment **shelf** + real-card grids (`my_card_factory`); forge = stash + drop-slot **bench** (click an affix to select; one button reforges it with a per-item lock + escalating Scrap cost); warehouse = hero-portrait picker + 40-slot stash grid + loadout board. Outpost builds its Core-upgrade rows inline.
*   **Battle hook**: `battle_scene/battle_scene.gd` `_victory()` awards Core + Caps by node type and routes to home base on boss kill; `_game_over()` routes to home base on death.
*   **Effect consumers**: Outpost Core upgrades (starting gold / shop discount / safe cells / backpack); Clinic/Market spend Caps; Forge spends Scrap. (The old `research_lab` rarity-bias upgrade was removed — loot rarity is Luck-driven.)

---

## 🖼️ Asset Locations

*   **Card Illustrations (PNG)**: `battle_scene/assets/images/cards/player/` (`512x320` landscape art-only PNGs)
*   **Equipment Icons (PNG)**: `battle_scene/assets/images/equipment/` (codex generates; falls back to placeholder if missing)
*   **Shop Scene Art (PNG, optional)**: `run_system/assets/images/shop/` (background + shopkeeper; codex generates)
*   **Hero Sprites (PNG/Animated)**: `battle_scene/assets/images/heroes/{sprite_id}/` (e.g. `cowboy_bill/`; the active hero's `sprite_id` comes from its `run_system/data/heroes/` JSON)
*   **Enemy Sprites (PNG/Animated)**: `battle_scene/assets/images/enemies/`
*   **Battle Backgrounds**: `battle_scene/assets/images/backgrounds/`
*   **Map Art and Node Icons**: `run_system/assets/images/map/`
*   **Relic Icons**: `run_system/assets/images/relics/`

---

## Data Files
All gameplay content is data-driven. Add GDScript only when introducing a new shared effect, trigger, or UI surface.

*   **Player Cards**: `battle_scene/card_info/player/{card_id}.json` (one JSON per card; no `_plus` upgrade variants — gems replace upgrades)
*   **Enemies**: `battle_scene/card_info/enemy/{enemy_id}.json`
*   **Relics**: `run_system/data/relics/{relic_id}.json`
*   **Equipment**: `run_system/data/equipment/{item_id}.json` — **15 generic shells** (`gear_{slot}_{tier}`, empty `bonuses`/`sprite`; art shared by slot×rarity) + **15 set pieces** (bespoke `set_id`/`sprite`). Real stats are **rolled affixes** at drop time (5-tier = 1/2/3/3/3+curse, **each guaranteeing 1 attribute affix**) via `run_system/core/affix_pool.gd`; `bonuses` is a dead back-compat baseline (ignored on new drops).
*   **Equipment Sets**: `run_system/data/equipment_sets/{set_id}.json` (each set has 2 tiers: 3-piece + 5-piece)
*   **Gems**: `run_system/data/gems/{gem_id}.json` — run-scoped socketables that occupy backpack cells (`validate_gem`); see the Gem/Socket section.
*   **Tools**: `run_system/data/tools/{tool_id}.json` — StS2-style one-time battle consumables; `effects[]` reuse the card effect vocabulary (`validate_tool`).
*   **Base Upgrades**: `run_system/data/base_upgrades/{upgrade_id}.json` (8 definitions: med_bay, command_center, scrap_workshop, blacksmith, backpack, starter_boost, reroll_tokens, tool_slots — tiered; effect_value schema varies per effect_key). These are the data the building screens read; `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` in `data_validator.gd` is the schema.
*   **Heroes**: `run_system/data/heroes/{hero_id}.json` (`cowboy_bill.json`) — `player.gd` reads `sprite_id` / `tint` / starting stats dynamically from the selected hero's JSON (`RunManager.current_hero_data`), falling back to `cowboy_bill` when none is loaded.
*   **Random Events**: `run_system/data/random_events/{event_id}.json` (12 events) — content (choices, outcomes) for the "?" map node, surfaced by `run_system/ui/event_modal.gd`. Three are "greed-trap" curse-injection events (`torn_coin_pouch` / `deserter_charm` / `adrenaline_shot`): a boon + an `add_curse` effect. Events are dir-scanned into the pool; localized via `EVENT_<ID>_*` keys in `assets/translations/ui_events.csv`.

All schemas validated at startup by `battle_scene/data_validator.gd`.
