# Project Structure - Roguelite Card Game (Hardcore 128 Pixel Wasteland Art)

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
    *   *Approved Hardcore 128 Pixel Wasteland Art reference direction for all future assets.*

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
    *   *Where the **Gold Reward (10 Gold)** is set and the **Card Rarity Rolls (70/25/5)** are calculated.*
*   **Card Factory**: `addons/card-framework/json_card_factory.gd`
    *   *The technical backend that loads JSON files and converts them into Card nodes.*

### 🏃 Run Management
*   **Global State**: `run_system/core/run_manager.gd`
    *   *Persistent data like current Gold, Deck list, and Map progress.*

---

## 🖼️ Asset Locations

*   **Card Illustrations (PNG)**: `battle_scene/assets/images/cards/player/`
*   **Hero Sprites (PNG/Animated)**: `battle_scene/assets/images/heroes/cowboy_bill/`
*   **Enemy Sprites (PNG/Animated)**: `battle_scene/assets/images/enemies/`
*   **Battle Backgrounds**: `battle_scene/assets/images/backgrounds/`
*   **Map Art and Node Icons**: `run_system/assets/images/map/`
*   **Relic Icons**: `run_system/assets/images/relics/`

---

## Data Files
This project no longer keeps local workflow skills in the repository. Use the canonical docs in `docs/` instead:

*   **Player Cards**: `battle_scene/card_info/player/{card_id}.json`
*   **Enemies**: `battle_scene/card_info/enemy/{enemy_id}.json`
*   **Relics**: `run_system/data/relics/{relic_id}.json`

New gameplay content should be data-driven first. Add GDScript only when introducing a new shared effect, trigger, or UI surface.
