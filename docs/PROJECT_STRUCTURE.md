# Project Structure - Roguelite Card Game (Original 2D American-Comic Sci-Fi Western)

This guide provides a precise map of the codebase for adjusting the UI, logic, and assets.

**Last audited:** 2026-07-24. Runtime code and JSON remain authoritative when
this map falls behind implementation.

## Documentation

All first-party project documentation lives in `docs/`.

*   **Product Requirements**: `docs/PRD.md`
    *   *Product scope, gameplay systems, roadmap, and known tech debt.*
*   **Project Structure**: `docs/PROJECT_STRUCTURE.md`
    *   *This file. Use it as the quick map for code, scenes, data, and assets.*
*   **Project Rules**: `docs/project-rules.md`
    *   *Non-negotiable art direction, asset pipeline, naming, and architecture rules.*
*   **Art Style Reference**: `docs/art-style-reference.md`
    *   *Approved original 2D American-comic / lightweight UI07 style contract for all future assets.*
*   **Enemy Art Direction**: `docs/enemy-art-direction.md`
    *   *Current non-boss enemy silhouettes, palette separation, and restrained attack-motion rules.*
*   **External Wasteland Study Board**: `docs/art/external-references/rick-morty-s3e2-wasteland/`
    *   *Documentation-only visual study material and its non-copying usage rules.*

Project conventions belong here, in `docs/project-rules.md`, or under
`docs/conventions/`.

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
    *   *System for managing Short Circuit, Burn, Weak, Vulnerable, Stun, and persistent player powers.*
*   **Discover**: `battle_scene/discover_modal.gd` (full-screen 3-choose-1 popup) + `run_system/core/discover_pool.gd` (rolls candidates by card type / theme tag). Driven by the `discover` effect in `combat_engine._apply_effect`; the picked card enters the hand for this combat only (optional `free` = 0-cost via a `cost_override` meta). Triggered by the 3 discover **tools** (`blood_kit`, displayed as Circuit Kit; `munitions_crate`; `field_kit`) — the demo discover *cards* were removed 2026-07-01, so discover is tool-only. Candidates suppress the "playable" glow and drive their keyword tooltip from the overlay button.

---

## 🗺️ Progression & Meta-Progression

### 💰 Loot & Rewards
*   **Reward Screen**: `run_system/ui/loot_reward.gd`
    *   *Loot by node type: normal = gold + 3-choose-1 card draft + Luck-scaled tool + Luck-scaled common equipment; elite = card draft + Luck-scaled uncommon equipment; boss reward handled in `battle_scene._victory` (guaranteed rare equipment). After PROCEED it spends queued level-up attribute picks (`pending_attr_points`, pick 1 of 3 attributes).*
*   **Card Factory**: `addons/card-framework/json_card_factory.gd`
    *   *Loads `card_info/player/{card_id}.json` and returns Card nodes.*

### 🛒 Shop & Rest
*   **Shop Scene**: `run_system/ui/shop_scene.tscn` + `.gd`
    *   *Merchant map node loads this. Rolls 6 cards + 3 tools + 3 relics + remove-card service (equipment is no longer sold here). Prices and pools defined at the top of the script.*
*   **Rest Choice Modal**: built inline in `map_scene.gd` (`_open_rest_choice`)
    *   *HEAL 25% HP or UPGRADE A CARD (opens `card_upgrade_modal.gd`).*

### ⬆️ Card Upgrade System
*   **Upgrade logic**: `run_system/core/card_upgrade.gd` (upgrade resolver) — `resolve(card_info)` returns the upgraded `card_info` (bumped cost/description/effects). **Hybrid**: a bespoke top-level `upgrade` block overrides cost/title/description/effects (effects = full replacement), else `formula()` bumps beneficial numeric fields (damage +2 / block +3 / attr+energy +1 / status stacks +1 / draw +1); `is_upgradeable()` returns false for curses. In-run card upgrades are the growth axis.
*   **Upgrade picker**: `run_system/ui/card_upgrade_modal.gd` — opened from the rest campfire; the player flips ONE deck entry's `upgraded` flag to true (locked for the run). Already-upgraded / non-upgradeable cards are dimmed.
*   **Mechanic**: `player_deck` entries carry an `upgraded: bool`; `deck_manager.gd` re-applies `CARD_UPGRADE.resolve(card_info)` at battle start when set. `run_deck_viewer_modal.gd` renders the deck (upgraded cards show their upgraded stats).

### 🎒 Equipment System
*   **Data**: `run_system/data/equipment/{item_id}.json` (**15 generic shells** `gear_{slot}_{tier}` sharing art by slot×rarity + **15 set pieces**, 3 sets × 5) + `run_system/data/equipment_sets/{set_id}.json` (3 sets). Rarity is **5-tier** (`run_system/core/affix_pool.gd`): common/uncommon/rare/set/cursed roll 1/2/3/3/3 affixes, **each guaranteeing 1 attribute affix** — `set` = a piece carrying a `set_id` (green, grants set bonuses), `cursed` = 3 positives + 1 curse affix (red). Drops route through `RunManager.roll_shell_drop(tier)` (~15% a set piece, else a shell; cursed at Ascension ≥ 3 or via the forge). Instances roll affixes at drop time (`make_equip_instance`).
*   **Set Effect System**: `battle_scene/equipment_set_system.gd` — snapshots active tier effects at battle start and emits compact local trigger callouts. The demo reward track in `RunManager` offers three claim-gated pieces from one featured set at floors 3/6/9.
*   **Equipment Icon Component**: `run_system/ui/equipment_icon.gd` — tile colored by **rarity** (common/uncommon/rare/set/cursed → graphite / steel-blue / gold / green / red) with a slot PNG icon (slot-letter fallback when the PNG is missing).
*   **Character Window**: `run_system/ui/window/character_window.gd` — draggable window (press **i** anywhere, or the right-edge Character image button at base), **Diablo-4 layout**: paper-doll center, equip slots flanking (head/chest/hands left; weapon/accessory + tools right), backpack grid below + sets/relics/stats. Modes: `base` (backpack = next-run carry list `pending_loadout`; slots = `pending_equipped`), `map` (editable), `battle` (read-only). **Stash Window**: `run_system/ui/window/stash_window.gd` — separate 25-slot storage window (D4 model): drag stash→backpack to carry, backpack/slot→stash to store; equip slots reject direct stash drags. Window infra: `window/draggable_window.gd` + `window/window_layer.gd` (z-order, ESC closes topmost).
*   **Inventory Full Modal**: `run_system/ui/inventory_full_modal.gd` — discard-or-skip flow when bag overflows.

### ❓ Random Events
*   **Event Modal**: `run_system/ui/event_modal.gd`
    *   *The "?" map-node event scene. Loads an event from `run_system/data/random_events/*.json`, presents the choices, and applies the chosen outcome.*

### 🏃 Run Management
*   **Run Shape**: the current public demo is **one 12-floor act** with a fixed `rust_titan` boss (`DEMO_BUILD = true`, `DEMO_MAX_ACTS = 1`); defeating it is a final victory with no extract-vs-push screen. The same manager retains the planned 3-act architecture behind `DEMO_BUILD = false`. Loot lives in a **20-cell backpack** where Gold / Scrap / equipment compete for space. On success only currencies bank automatically; gear returns to the independently persisted base backpack/slots (`pending_loadout` / `pending_equipped`). On death only safe-cell gear survives. `MetaProgress.stash` is permanent storage changed only by explicit player transfers.
*   **Global State**: `run_system/core/run_manager.gd` (autoload)
    *   *Gold, deck, equipped items, inventory, base_attributes, player_attributes (computed), relics, tools (**equipped** in `tool_inventory`, **held** in backpack `{"kind":"tool"}` cells), XP/level, map state. Public API: `add_card_to_deck`, `remove_card_from_deck_by_uid`, `gain_xp` / `xp_to_next`, `equip_to_slot`, `unequip_slot`, `add_to_inventory`, `discard_from_inventory`, `add_tool_to_backpack` / `equip_tool_from_backpack` / `unequip_tool` / `unequip_tool_to_backpack` / `tool_slots` (1 base + Outpost + relic), `purchase_*` (shop-gated wrappers), `recompute_attributes`, `get_active_set_tiers`. Normal encounter constants are explicit four-band rosters: `ENCOUNTER_POOLS_OPENING` (combined floor 0–1), EARLY (2–3), MID (4–7), LATE (8+), validated against role and base-HP budgets at startup. `start_new_run` applies Ascension, Clinic HP perks, Command Center Caps, reroll tokens, and backpack capacity from MetaProgress.*

### 🏠 Base Building (Meta-Progression)
*   **Persistent State**: `run_system/core/meta_progress.gd` (autoload, owns `user://slot_<n>/meta.json` — 3 save slots; imports the pre-slot global `user://meta.json` into slot 1 once) — **two currencies** (**Caps / Scrap**) + `buildings{}` + `BUILDING_DEFS` + pure-storage `stash` + the owned base backpack/slots serialized as `base_loadout` / `base_equipped`. Storage transfers use `move_stash_to_base_backpack`, `move_base_backpack_to_stash`, and `move_base_slot_to_stash` atomically. Building unlocks/tier-ups spend Scrap.
*   **Bounty State (in MetaProgress)**: save fields `active_bounties` (held contracts `[{id, progress}]`, max 3) / `bounty_shelf` + `bounty_shelf_date` (today's **outpost** shelf) / `cards_seen`. `bounty_progress_add` settles instantly: Caps/Scrap pay directly, while equipment rolls into the active run backpack (owned base backpack fallback when out of run), never the stash. Signals: `bounties_changed`, `bounty_completed`.
*   **In-run bounty hooks**: `RunManager.bounty_event(kind, amount)` — no-op unless a run is active; 6 emit sites: attack card play + elite/boss kill (`battle_scene.gd`), any kill (`enemy_entity.gd`), gold entering the backpack (`run_manager.add_gold` — starting gold / save-restores don't route through it), extraction (`run_manager.gd`), campfire upgrade (`card_upgrade_modal.gd`). Objective kinds live in `ALLOWED_BOUNTY_OBJECTIVES` (`data_validator.gd`).
*   **Boot Scene**: `run_system/ui/home_base_scene.{gd,tscn}` — 4 buildings use **icon-only circular entry markers** floating over the scene (no name/level plaques) + a unified **bottom HUD bar** (`window/currency_top_bar.gd`, anchored full-width bottom, exposes left/center/right boxes): currency chips left, giant START + difficulty button (A0-A5 picker popup) center, Warehouse / Character / Gallery nav buttons bottom-right (Warehouse opens StashWindow + CharacterWindow side by side; Character toggles CharacterWindow; Gallery opens the card codex overlay). Bottom-left hosts the compact **bounty board** (`_add_bounty_board_panel`): held contracts from `MetaProgress.active_bounties`, full-width progress rails, and the Outpost pickup hint; reward seals and the visible refresh countdown are intentionally omitted. Rows rebuild on `bounties_changed`, and completion toasts listen to `bounty_completed`. The **card gallery** (`_open_card_gallery`, CanvasLayer overlay) shows every player card with a collected counter — locked (never-played) cards render the battle card back. Theme hooks in `wasteland_theme.gd` (`ui_bottom_bar` / `ui_button_brass` / `ui_button_accent` + window/slot styles) use the checked-in `ui_kit/` and `ui_kit_lightline/` assets with programmatic fallbacks. Forge opens draggable windows; Clinic/Market/Outpost open fullscreen screens. Press **i** for the CharacterWindow.
*   **Building Screens**: `run_system/ui/buildings/{clinic,market,outpost}_screen.gd` are fullscreen **lightline** service pages. Per-building: **market** = tool shelf + refresh (T1) / equipment shelf into the owned base backpack (T2) / **Caps↔Scrap** conversion (T3); **outpost** = free daily bounty shelf (T1) / safe cells (T2) / Caps permanent-upgrade rows (T3). **Forge is a draggable window** (`window/forge_window.gd`) opened beside CharacterWindow: its workbench accepts only `src=carry` base-backpack drags, bulk dismantle is a vertical all/common/uncommon/rare list, and craft/dismantle/reforge/curse never read or mutate the stash.
*   **Battle hook**: `battle_scene/battle_scene.gd` `_victory()` drops Scrap into the backpack + awards Caps by node type and opens the demo result; `_game_over()` opens defeat settlement, whose action returns to base.
*   **Effect consumers**: Outpost Caps permanent upgrades (starting gold / backpack / rerolls / tool slots + T2 safe cells); Clinic/Market spend Caps; Forge spends Scrap; building unlocks/tiers spend Scrap. Retired hidden effects are migrated out rather than remaining passive.

---

## 🖼️ Asset Locations

*   **Card Illustrations (PNG)**: `battle_scene/assets/images/cards/player/` (`512x320` landscape art-only PNGs)
*   **Equipment Icons (PNG)**: `battle_scene/assets/images/equipment/` (falls back to placeholder if missing)
*   **Shop Scene Art (PNG, optional)**: `run_system/assets/images/shop/` (background + shopkeeper)
*   **Hero Sprites (PNG/Animated)**: `battle_scene/assets/images/heroes/{sprite_id}/` (e.g. `cowboy_bill/`; the active hero's `sprite_id` comes from its `run_system/data/heroes/` JSON)
*   **Enemy Sprites (PNG/Animated)**: `battle_scene/assets/images/enemies/`
*   **Battle Backgrounds**: `battle_scene/assets/images/backgrounds/` (active: `wasteland_battlefield_quiet_v6.png`)
*   **Map Art and Node Icons**: `run_system/assets/images/map/` (active background: `wasteland_route_map_sts2_bg.png`)
*   **Relic Icons**: `run_system/assets/images/relics/`
*   **Lightline UI Kit (PNG)**: `run_system/assets/images/ui_kit_lightline/` — the base-building UI component library sliced from source sheets: **89 named pieces** (`icon_*` / `panel_*` / `btn_*` / `bar_*` / `card_*` / `slot_*` / `row_*` …) + `manifest.json` (per-piece 9-slice margins). Consumed through `wasteland_theme.gd`'s `ll_*` StyleBox hooks (`ll_panel` / `ll_titlebar` / `ll_section` / `ll_inset` / `ll_button` / `ll_button_olive` / `ll_slot`) — every lookup falls back to a programmatic StyleBox so a missing piece never crashes. Raw uncut sheets: `run_system/assets/images/ui_kit_imagegen_v2_lightline/`.

---

## Data Files
All gameplay content is data-driven. Add GDScript only when introducing a new shared effect, trigger, or UI surface.

*   **Player Cards**: `battle_scene/card_info/player/{card_id}.json` (one JSON per card; in-run upgrades are resolved by `card_upgrade.gd`, not stored as `_plus` variants)
*   **Enemies**: `battle_scene/card_info/enemy/{enemy_id}.json` — every file requires `tier` (`minion|normal|heavy|elite|boss`); the generated enemy catalog groups by this field and `DataValidator` cross-checks every normal/elite/boss roster.
*   **Relics**: `run_system/data/relics/{relic_id}.json`
*   **Equipment**: `run_system/data/equipment/{item_id}.json` — **15 generic shells** (`gear_{slot}_{tier}`, empty `bonuses`/`sprite`; art shared by slot×rarity) + **15 set pieces** (bespoke `set_id`/`sprite`). Real stats are **rolled affixes** at drop time (5-tier = 1/2/3/3/3+curse, **each guaranteeing 1 attribute affix**) via `run_system/core/affix_pool.gd`; `bonuses` is a dead back-compat baseline (ignored on new drops).
*   **Equipment Sets**: `run_system/data/equipment_sets/{set_id}.json` (each set has 2 tiers: 3-piece + 5-piece)
*   **Tools**: `run_system/data/tools/{tool_id}.json` — StS2-style one-time battle consumables; `effects[]` reuse the card effect vocabulary (`validate_tool`).
*   **Base Upgrades**: `run_system/data/base_upgrades/{upgrade_id}.json` (5 active definitions: command_center, blacksmith, backpack, reroll_tokens, tool_slots). `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` in `data_validator.gd` is the authoritative schema.
*   **Heroes**: `run_system/data/heroes/{hero_id}.json` (`cowboy_bill.json`) — `player.gd` reads `sprite_id` / `tint` / starting stats dynamically from the selected hero's JSON (`RunManager.current_hero_data`), falling back to `cowboy_bill` when none is loaded.
*   **Random Events**: `run_system/data/random_events/{event_id}.json` (12 events) — content (choices, outcomes) for the "?" map node, surfaced by `run_system/ui/event_modal.gd`. Three are "greed-trap" curse-injection events (`torn_coin_pouch` / `deserter_charm` / `adrenaline_shot`): a boon + an `add_curse` effect. Events are dir-scanned into the pool; localized via `EVENT_<ID>_*` keys in `assets/translations/ui_events.csv`.

All schemas validated at startup by `battle_scene/data_validator.gd`.

---

## Agent and Repository Surfaces

*   **Agent entry point**: `AGENTS.md`
*   **Project-local agent skills**: `.agents/skills/` (reserved; currently empty)
*   **Project-local Codex configuration**: `.codex/` (reserved; currently empty)
*   **Documentation**: `docs/`
*   **Maintenance and generation scripts**: `scripts/`
*   **Automated checks**: `tests/`

Ignored `.godot/`, `tmp/`, `.planning/`, `.mcp/`, and `.superpowers/` content is
local cache or intermediate workflow state, not a source of truth.
