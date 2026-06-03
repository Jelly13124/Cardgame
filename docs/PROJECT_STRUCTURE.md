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
    *   *System for managing poison, burn, weak, vulnerable, double damage, and other buffs/debuffs.*

---

## 🗺️ Progression & Meta-Progression

### 💰 Loot & Rewards
*   **Reward Screen**: `run_system/ui/loot_reward.gd`
    *   *Gold reward (10g) + card rarity rolls (70/25/5) + elite/boss equipment drop row + draft overlay.*
*   **Card Factory**: `addons/card-framework/json_card_factory.gd`
    *   *Loads `card_info/player/{card_id}.json` and returns Card nodes. Handles `_plus` variants transparently — no factory changes needed for upgrades.*

### 🛒 Shop & Rest
*   **Shop Scene**: `run_system/ui/shop_scene.tscn` + `.gd`
    *   *Merchant map node loads this. Rolls 3 cards + 2 equipment + 1 relic + remove-card service. Prices and pools defined at the top of the script.*
*   **Rest Choice Modal**: built inline in `map_scene.gd` (`_open_rest_choice`)
    *   *HEAL 25% HP or UPGRADE A CARD; upgrade reuses `card_upgrade_modal.gd`.*

### 🃏 Card Upgrade System
*   **Upgrade Picker**: `run_system/ui/card_upgrade_modal.gd`
    *   *Modal listing every non-upgraded deck card. Click → calls `RunManager.upgrade_card_by_uid(uid)`.*
*   **Upgrade variants**: `battle_scene/card_info/player/{card_id}_plus.json`
    *   *17 files mirror base cards with stronger numbers. Reuse base card art (`front_image` field points to the same PNG).*
*   **Mechanic**: Upgrading swaps the deck entry's `card_id` from `"X"` to `"X_plus"`. Loader is unchanged.

### 🎒 Equipment System
*   **Data**: `run_system/data/equipment/{item_id}.json` (21 items) + `run_system/data/equipment_sets/{set_id}.json` (3 sets)
*   **Set Effect System**: `battle_scene/equipment_set_system.gd` — snapshots active tier effects at battle start; mirrors `relic_effect_system.gd` shape.
*   **Equipment Icon Component**: `run_system/ui/equipment_icon.gd` — reusable placeholder (colored panel + slot letter) with PNG fallback.
*   **Character Panel**: `run_system/ui/equipment_panel.gd` — map-screen modal showing HP/Gold/Floor + slots + inventory + active sets + relics + stats. Open via `⚔ CHARACTER` button.
*   **Inventory Full Modal**: `run_system/ui/inventory_full_modal.gd` — discard-or-skip flow when bag overflows.

### ❓ Random Events
*   **Event Modal**: `run_system/ui/event_modal.gd`
    *   *The "?" map-node event scene. Loads an event from `run_system/data/random_events/*.json`, presents the choices, and applies the chosen outcome.*

### 🏃 Run Management
*   **Run Shape**: a run is **3 self-contained acts**, each a ~12-floor map ending in a boss. Loot lives in a **20-cell backpack** where Gold / Core / equipment compete for space, with safe-cells preserved on death, a permanent base stash, and a next-run loadout (`RunManager.backpack` / `RunManager.pending_loadout`; `MetaProgress.stash`).
*   **Global State**: `run_system/core/run_manager.gd` (autoload)
    *   *Gold, deck, equipped items, inventory, base_attributes, player_attributes (computed), relics, map state. Public API: `add_card_to_deck`, `remove_card_from_deck_by_uid`, `upgrade_card_by_uid`, `equip_to_slot`, `unequip_slot`, `add_to_inventory`, `discard_from_inventory`, `purchase_*` (shop-gated wrappers), `recompute_attributes`, `get_active_set_tiers`. `start_new_run` calls `_apply_meta_upgrades` to read MetaProgress and add max HP / starting gold / starter inventory.*

### 🏠 Base Building (Meta-Progression)
*   **Persistent State**: `run_system/core/meta_progress.gd` (autoload, owns `user://meta.json`) — Core currency + per-upgrade level (0-3). API: `add_core`, `get_upgrade_level`, `can_purchase`, `purchase_upgrade`, `reset_all` (debug).
*   **Boot Scene**: `run_system/ui/home_base_scene.{gd,tscn}` — Core counter + 5 upgrade panels + START NEW RUN
*   **Upgrade Widget**: `run_system/ui/upgrade_panel.gd` — reusable panel (title / level dots / next-tier preview / BUY)
*   **Battle hook**: `battle_scene/battle_scene.gd` `_victory()` grants +150 Core and routes to home base on boss kill; `_game_over()` routes to home base on death
*   **Effect consumers**: `loot_reward.gd` reads `research_lab` for rarity bias; `shop_scene.gd` reads `scrap_workshop` for discount

---

## 🖼️ Asset Locations

*   **Card Illustrations (PNG)**: `battle_scene/assets/images/cards/player/` (base + `_plus` reuses base art)
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

*   **Player Cards**: `battle_scene/card_info/player/{card_id}.json` (base + `{card_id}_plus.json` for upgrades)
*   **Enemies**: `battle_scene/card_info/enemy/{enemy_id}.json`
*   **Relics**: `run_system/data/relics/{relic_id}.json`
*   **Equipment**: `run_system/data/equipment/{item_id}.json` (rarity budget: common=+1, uncommon=+2 total, rare=+3 total)
*   **Equipment Sets**: `run_system/data/equipment_sets/{set_id}.json` (each set has 2 tiers: 3-piece + 5-piece)
*   **Base Upgrades**: `run_system/data/base_upgrades/{upgrade_id}.json` (5 upgrades × 3 tiers each; effect_value schema varies per effect_key)
*   **Heroes**: `run_system/data/heroes/{hero_id}.json` (`cowboy_bill.json`, `hero_jerry_killer.json`) — `player.gd` reads `sprite_id` / `tint` / starting stats dynamically from the selected hero's JSON (`RunManager.current_hero_data`), falling back to `cowboy_bill` when none is loaded.
*   **Random Events**: `run_system/data/random_events/{event_id}.json` — content (choices, outcomes) for the "?" map node, surfaced by `run_system/ui/event_modal.gd`.

All schemas validated at startup by `battle_scene/data_validator.gd`.
