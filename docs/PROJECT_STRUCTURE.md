# Project Structure - Roguelite Card Game (Rick and Morty-style Sci-Fi Cartoon Wasteland)

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
    *   *Approved Rick and Morty-style Sci-Fi Cartoon Wasteland style contract for all future assets.*

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
    *   *Definitions for enemy moves, behavior patterns, and required encounter identity `tier` (`minion|normal|heavy|elite|boss`).*

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
    *   *Loot by node type: normal = gold + 3-choose-1 card draft + Luck-scaled tool + Luck-scaled common equipment; elite = card draft + Luck-scaled uncommon equipment; boss reward handled in `battle_scene._victory` (guaranteed rare equipment). After PROCEED it spends queued level-up attribute picks (`pending_attr_points`, pick 1 of 3 attributes).*
*   **Card Factory**: `addons/card-framework/json_card_factory.gd`
    *   *Loads `card_info/player/{card_id}.json` and returns Card nodes.*

### 🛒 Shop & Rest
*   **Shop Scene**: `run_system/ui/shop_scene.tscn` + `.gd`
    *   *Merchant map node loads this. Rolls 3 cards + 3 tools + 3 relics + remove-card service (equipment is no longer sold here). Prices and pools defined at the top of the script.*
*   **Rest Choice Modal**: built inline in `map_scene.gd` (`_open_rest_choice`)
    *   *HEAL 25% HP or UPGRADE A CARD (opens `card_upgrade_modal.gd`).*

### ⬆️ Card Upgrade System
*   **Upgrade logic**: `run_system/core/card_upgrade.gd` (upgrade resolver) — `resolve(card_info)` returns the upgraded `card_info` (bumped cost/description/effects). **Hybrid**: a bespoke top-level `upgrade` block overrides cost/title/description/effects (effects = full replacement), else `formula()` bumps beneficial numeric fields (damage +2 / block +3 / attr+energy +1 / status stacks +1 / draw +1); `is_upgradeable()` returns false for curses. Removed the gem-socket system; the gems data dir (`run_system/data/gems/`) is gone. In-run card upgrades are the growth axis.
*   **Upgrade picker**: `run_system/ui/card_upgrade_modal.gd` — opened from the rest campfire; the player flips ONE deck entry's `upgraded` flag to true (locked for the run). Already-upgraded / non-upgradeable cards are dimmed.
*   **Mechanic**: `player_deck` entries carry an `upgraded: bool`; `deck_manager.gd` re-applies `CARD_UPGRADE.resolve(card_info)` at battle start when set. `run_deck_viewer_modal.gd` renders the deck (upgraded cards show their upgraded stats).

### 🎒 Equipment System
*   **Data**: `run_system/data/equipment/{item_id}.json` (**15 generic shells** `gear_{slot}_{tier}` sharing art by slot×rarity + **15 set pieces**, 3 sets × 5) + `run_system/data/equipment_sets/{set_id}.json` (3 sets). Rarity is **5-tier** (`run_system/core/affix_pool.gd`): common/uncommon/rare/set/cursed roll 1/2/3/3/3 affixes, **each guaranteeing 1 attribute affix** — `set` = a piece carrying a `set_id` (green, grants set bonuses), `cursed` = 3 positives + 1 curse affix (red). Drops route through `RunManager.roll_shell_drop(tier)` (~15% a set piece, else a shell; cursed at Ascension ≥ 3 or via the forge). Instances roll affixes at drop time (`make_equip_instance`).
*   **Set Effect System**: `battle_scene/equipment_set_system.gd` — snapshots active tier effects at battle start; mirrors `relic_effect_system.gd` shape.
*   **Equipment Icon Component**: `run_system/ui/equipment_icon.gd` — tile colored by **rarity** (common/uncommon/rare/set/cursed → graphite / steel-blue / gold / green / red) with a slot PNG icon (slot-letter fallback when the PNG is missing).
*   **Character Window**: `run_system/ui/window/character_window.gd` — draggable window (press **i** anywhere, or the right-edge Character image button at base), **Diablo-4 layout**: paper-doll center, equip slots flanking (head/chest/hands left; weapon/accessory + tools right), backpack grid below + sets/relics/stats. Modes: `base` (backpack = next-run carry list `pending_loadout`; slots = `pending_equipped`), `map` (editable), `battle` (read-only). **Stash Window**: `run_system/ui/window/stash_window.gd` — separate 40-slot storage window (D4 model): drag stash→backpack to carry, backpack/slot→stash to store; equip slots reject direct stash drags. Window infra: `window/draggable_window.gd` + `window/window_layer.gd` (z-order, ESC closes topmost).
*   **Inventory Full Modal**: `run_system/ui/inventory_full_modal.gd` — discard-or-skip flow when bag overflows.

### ❓ Random Events
*   **Event Modal**: `run_system/ui/event_modal.gd`
    *   *The "?" map-node event scene. Loads an event from `run_system/data/random_events/*.json`, presents the choices, and applies the chosen outcome.*

### 🏃 Run Management
*   **Run Shape**: a run is **3 self-contained acts**, each a ~12-floor map ending in a boss. Loot lives in a **20-cell backpack** where Gold / Scrap / equipment compete for space, with safe-cells preserved on death, a permanent base stash, and a next-run loadout (`RunManager.backpack` / `RunManager.pending_loadout`; `MetaProgress.stash`). (The in-run resource was "Core" before 2026-07-07; it is now Scrap, banking to `MetaProgress.scrap`.)
*   **Global State**: `run_system/core/run_manager.gd` (autoload)
    *   *Gold, deck, equipped items, inventory, base_attributes, player_attributes (computed), relics, tools (**equipped** in `tool_inventory`, **held** in backpack `{"kind":"tool"}` cells), XP/level, map state. Public API: `add_card_to_deck`, `remove_card_from_deck_by_uid`, `gain_xp` / `xp_to_next`, `equip_to_slot`, `unequip_slot`, `add_to_inventory`, `discard_from_inventory`, `add_tool_to_backpack` / `equip_tool_from_backpack` / `unequip_tool` / `unequip_tool_to_backpack` / `tool_slots` (1 base + Outpost + relic), `purchase_*` (shop-gated wrappers), `recompute_attributes`, `get_active_set_tiers`. Normal encounter constants are explicit four-band rosters: `ENCOUNTER_POOLS_OPENING` (combined floor 0–1), EARLY (2–3), MID (4–7), LATE (8+), validated against role and base-HP budgets at startup. `start_new_run` calls `_apply_meta_upgrades` to read MetaProgress and add max HP / starting gold / starter inventory.*

### 🏠 Base Building (Meta-Progression)
*   **Persistent State**: `run_system/core/meta_progress.gd` (autoload, owns `user://slot_<n>/meta.json` — 3 save slots; the legacy global `user://meta.json` is no longer read) — **two currencies** (**Caps / Scrap**; Core removed 2026-07-07, old-save balance discarded) + `buildings{}` (per-building tier) + `BUILDING_DEFS`. API: `add_caps/scrap` + `spend_*`, `get_building_tier`, `is_building_unlocked`, `unlock_building` (spends **Scrap**), `upgrade_building` (spends **Caps**), `building_cost_currency` (→ scrap while locked / caps once unlocked), `building_can`, `get_unlocked_card_pool` (directory-scans all cards; no unlock system), `set_starter_deck_override`, `stash` + `dismantle_stash_item` / `reforge_stash_item_locked` (single-affix lock + escalating cost) / `curse_stash_item`.
*   **Bounty State (in MetaProgress)**: save fields `active_bounties` (held contracts `[{id, progress}]`, max 3) / `bounty_shelf` + `bounty_shelf_date` (today's **outpost** shelf; `bounty_free_claimed` persists only as a legacy save field — no gate) / `cards_seen` (card codex, played ⇒ unlocked). API: `refresh_bounty_shelf_if_stale` (date-seeded daily 3-contract reroll; held ids excluded), `take_bounty` (shelf take — **FREE**, guards shelf membership / not already held / max 3; `claim_free_bounty` is a legacy alias, `buy_bounty` is gone), `is_bounty_active`, `get_bounty_data` (cached JSON), `bounty_progress_add` (progress + **instant settle**: pays Caps/Scrap or rolls an equipment tier into the stash, emits `bounty_completed`), `mark_card_seen` (write-throttled). Signals: `bounties_changed`, `bounty_completed`.
*   **In-run bounty hooks**: `RunManager.bounty_event(kind, amount)` — no-op unless a run is active; 6 emit sites: attack card play + elite/boss kill (`battle_scene.gd`), any kill (`enemy_entity.gd`), gold entering the backpack (`run_manager.add_gold` — starting gold / save-restores don't route through it), extraction (`run_manager.gd`), campfire upgrade (`card_upgrade_modal.gd`). Objective kinds live in `ALLOWED_BOUNTY_OBJECTIVES` (`data_validator.gd`).
*   **Boot Scene**: `run_system/ui/home_base_scene.{gd,tscn}` — 4 building tiles in a centered row (x 195/585/975/1365) + a unified **bottom HUD bar** (`window/currency_top_bar.gd`, anchored full-width bottom, exposes left/center/right boxes): currency chips left, giant START + difficulty button (A0-A5 picker popup) center, Warehouse / Character / Gallery nav buttons bottom-right (Warehouse opens StashWindow + CharacterWindow side by side; Character toggles CharacterWindow; Gallery opens the card codex overlay). Bottom-left hosts the **bounty board** panel (`_add_bounty_board_panel`: held contracts from `MetaProgress.active_bounties` with live progress, rebuilt on `bounties_changed`; completion toast on `bounty_completed`). The **card gallery** (`_open_card_gallery`, CanvasLayer overlay) shows every player card with a collected counter — locked (never-played) cards render the battle card back. Theme hooks in `wasteland_theme.gd` (`ui_bottom_bar` / `ui_button_brass` / `ui_button_accent` + window/slot styles) auto-skin from `run_system/assets/images/ui_kit/` when the Codex kit lands (spec: `docs/asset-spec-ui-kit.md`, rev2 pending). Forge opens draggable windows; Clinic/Market/Outpost open fullscreen screens. Press **i** for the CharacterWindow.
*   **Building Screens**: `run_system/ui/buildings/{clinic,market,outpost}_screen.gd` (subclass `building_screen_base.gd`) — **fullscreen, services-only** pages rebuilt 2026-07-07 to the Codex **lightline** concepts; `home_base_scene` convention-loads `<id>_screen.gd`. **Unlock/upgrade lives on the home-base overview** (button under each building's floating label → confirm popup → `MetaProgress.unlock/upgrade_building`). Per-building: **market** = tool shelf + refresh (T1) / equipment shelf (T2) / **Caps↔Scrap** resource conversion (T3) — the bounty shelf left for the outpost; **outpost** = **daily bounty shelf** (T1, ALL takes free, date-seeded reroll, max 3 held — held progress shows on the home-base bounty board, not here) / safe cells (T2) / Caps permanent-upgrade rows (T3: starting gold / backpack / reroll tokens / tool slots — the **starter-deck editor + shop-discount upgrade were removed**, and difficulty select lives above the home START button). `BUILDING_DEFS[id].functions` is a `{function_name: tier}` dict (e.g. outpost = `{bounties:1, safe_cells:2, permanent_upgrades:3}`), gated via `building_can`. Building **unlock costs Scrap, tier-up costs Caps** (`building_cost_currency`). **Forge is a draggable window** (`window/forge_window.gd`, 4 lightline icon-tabs in concept order: dismantle/craft/reforge/curse; opens beside the CharacterWindow for cross-window gear drags). Its dismantle tab adds **bulk dismantle by rarity** (`MetaProgress.dismantle_stash_by_rarity`, confirm dialog; `BULK_DISMANTLE_RARITIES` = common/uncommon/rare — set + cursed gear is excluded). The former warehouse screen was removed (loadout → CharacterWindow base mode).
*   **Battle hook**: `battle_scene/battle_scene.gd` `_victory()` drops Scrap into the backpack + awards Caps by node type, and routes to home base on boss kill; `_game_over()` routes to home base on death.
*   **Effect consumers**: Outpost Caps permanent upgrades (starting gold / backpack / reroll tokens / tool slots + T2 safe cells); Clinic/Market spend Caps; Forge spends Scrap; building unlocks spend Scrap. (The old `research_lab` rarity-bias upgrade was removed — loot rarity is Luck-driven. The `scrap_workshop` shop-discount upgrade is **no longer purchasable** since 2026-07-07 — old saves keep their levels passively.)

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
*   **Lightline UI Kit (PNG)**: `run_system/assets/images/ui_kit_lightline/` — the base-building UI component library sliced from Codex imagegen sheets: **89 named pieces** (`icon_*` / `panel_*` / `btn_*` / `bar_*` / `card_*` / `slot_*` / `row_*` …) + `manifest.json` (per-piece 9-slice margins). Consumed through `wasteland_theme.gd`'s `ll_*` StyleBox hooks (`ll_panel` / `ll_titlebar` / `ll_section` / `ll_inset` / `ll_button` / `ll_button_olive` / `ll_slot`) — every lookup falls back to a programmatic StyleBox so a missing piece never crashes. Raw uncut sheets: `run_system/assets/images/ui_kit_imagegen_v2_lightline/`.

---

## Data Files
All gameplay content is data-driven. Add GDScript only when introducing a new shared effect, trigger, or UI surface.

*   **Player Cards**: `battle_scene/card_info/player/{card_id}.json` (one JSON per card; in-run upgrades are resolved by `card_upgrade.gd`, not stored as `_plus` variants)
*   **Enemies**: `battle_scene/card_info/enemy/{enemy_id}.json` — every file requires `tier` (`minion|normal|heavy|elite|boss`); the generated enemy catalog groups by this field and `DataValidator` cross-checks every normal/elite/boss roster.
*   **Relics**: `run_system/data/relics/{relic_id}.json`
*   **Equipment**: `run_system/data/equipment/{item_id}.json` — **15 generic shells** (`gear_{slot}_{tier}`, empty `bonuses`/`sprite`; art shared by slot×rarity) + **15 set pieces** (bespoke `set_id`/`sprite`). Real stats are **rolled affixes** at drop time (5-tier = 1/2/3/3/3+curse, **each guaranteeing 1 attribute affix**) via `run_system/core/affix_pool.gd`; `bonuses` is a dead back-compat baseline (ignored on new drops).
*   **Equipment Sets**: `run_system/data/equipment_sets/{set_id}.json` (each set has 2 tiers: 3-piece + 5-piece)
*   **Tools**: `run_system/data/tools/{tool_id}.json` — StS2-style one-time battle consumables; `effects[]` reuse the card effect vocabulary (`validate_tool`).
*   **Base Upgrades**: `run_system/data/base_upgrades/{upgrade_id}.json` (8 definitions: med_bay, command_center, scrap_workshop, blacksmith, backpack, starter_boost, reroll_tokens, tool_slots — tiered; effect_value schema varies per effect_key). These are the data the building screens read; `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` in `data_validator.gd` is the schema. (`scrap_workshop` = shop discount is legacy: still validated + applied for old saves, but no building sells it since 2026-07-07.)
*   **Heroes**: `run_system/data/heroes/{hero_id}.json` (`cowboy_bill.json`) — `player.gd` reads `sprite_id` / `tint` / starting stats dynamically from the selected hero's JSON (`RunManager.current_hero_data`), falling back to `cowboy_bill` when none is loaded.
*   **Random Events**: `run_system/data/random_events/{event_id}.json` (12 events) — content (choices, outcomes) for the "?" map node, surfaced by `run_system/ui/event_modal.gd`. Three are "greed-trap" curse-injection events (`torn_coin_pouch` / `deserter_charm` / `adrenaline_shot`): a boon + an `add_curse` effect. Events are dir-scanned into the pool; localized via `EVENT_<ID>_*` keys in `assets/translations/ui_events.csv`.

All schemas validated at startup by `battle_scene/data_validator.gd`.
