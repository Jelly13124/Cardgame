# Card System Overhaul — Global Attributes · Roster = card_overview.html · Shock→Stun (design)

**Date:** 2026-06-01
**Status:** Locked by owner. Source spec = `C:\Users\Jerry\Downloads\card_overview.html` (the 21-card table). Owner decisions: (1) **the table IS the complete card roster** — delete every card not in it; (2) **attributes become global** — STR auto-adds to all attack damage, CON to all block; strip per-card `scaling`. Plus: rename the **Shock** keyword to **Stun** (fits the skip-turn effect).

## Architecture change: global STR / CON

Today, attack/block scaling is per-card via a `scaling` field read in `combat_engine._apply_effect()`. New model:
- **`deal_damage` and `deal_damage_all`**: combat_engine adds `player.strength` to the amount automatically (every attack). Card JSON carries the BASE number only; the `scaling` field is removed.
- **`gain_block`**: combat_engine adds `player.constitution` automatically.
- **NOT auto-boosted** (special): `scale_damage_by_attacks` (cascade) and the new `deal_damage_str_mult` (charged_shot) — these compute their own damage and must NOT receive the global +STR.
- Base attributes stay 3 each; only equipment/relics raise them. So a "3 damage" card hits 6 at base STR 3 — matches the table's "数值=基础值, 默认各+3".

Implementation: in `_apply_effect`, after computing an effect's base amount, add the global stat for the qualifying effect types; delete the old `scaling` lookup (or make it a no-op). Strip `"scaling"` from all kept card JSONs.

## New effect types (register in combat_engine + data_validator)
- **`deal_damage_str_mult`** — damage = `player.strength * mult` (charged_shot: mult 2). Does NOT add global STR. Required field: `mult`.
- **`apply_stun`** — renamed from `apply_shock` (see Shock→Stun below).

## Shock → Stun rename (keyword fits "skip turn")
Global rename across code + data + i18n:
- Status name `"shock"` → `"stun"` in `ALLOWED_STATUS_NAMES` (data_validator), `status_effect_system.gd` (STATUS_COLORS/ICONS/DESCRIPTIONS keys), `enemy_entity.gd` status-name map.
- Effect `apply_shock` → `apply_stun`, `apply_shock_all` → `apply_stun_all` (no card uses `_all` after this overhaul — keep the handler renamed for parity/enemies, but it's unused).
- `consume_shock` → `consume_stun`, `consume_shock_if_present` → `consume_stun_if_present` (status_effect_system, enemy_ai, enemy_entity).
- i18n: `UI_COMBAT_SHOCK_X` / `UI_COMBAT_ALL_SHOCK_X` / `UI_COMBAT_ENEMY_SHOCKED` → `..._STUN_...`; zh `感电` → `眩晕`. Display label `⚡` Stun / 眩晕.
- Behavior unchanged: each stack makes the enemy skip one action; manual-consume, no natural decay; can interrupt a telegraphed attack. Enemy-only.

## The roster (21 base cards — the table is the target)

Rarity map: 普通=common, 罕见=uncommon, 稀有=rare. All numbers are BASE (global +STR/+CON applied at runtime). `_plus` variants per the table's plus block.

| id | type | cost | rarity | effects (base) | + (upgrade) |
|---|---|---|---|---|---|
| strike | attack | 1 | common | deal_damage 3 | 5 |
| weak_strike | attack | 1 | common | deal_damage 3; apply_status weak 1 | 4 / weak 2 |
| defend | skill | 1 | common | gain_block 3 | 5 |
| preemptive_strike | skill | 1 | rare | apply_status_self double_damage 1 | cost 0; double_damage 2 |
| stun_baton | attack | 1 | rare | deal_damage 1; apply_stun 1 | cost 0; same |
| cascade | attack | 1 | uncommon | scale_damage_by_attacks base 2 per 2 · Retain | base 3 |
| hot_swap | skill | 1 | common | draw_cards 2 | 3 |
| charged_shot | attack | 1 | uncommon | deal_damage_str_mult mult 2 · Exhaust | cost 0 |
| adrenaline | skill | 0 | rare | gain_energy 2; draw_cards 1 · Exhaust | draw 2 |
| acid_splash | attack | 1 | uncommon | deal_damage_all 4; apply_status_all poison 2 · AoE | 6 / poison 3 |
| bone_breaker | attack | 2 | rare | deal_damage 14; apply_status vulnerable 2 | 19 / vuln 3 |
| brace | skill | 0 | common | gain_block 4 · Retain | 6 |
| chain_link | attack | 1 | uncommon | deal_damage 6; draw_cards 1 | 9 |
| double_tap | attack | 2 | rare | deal_damage 1; deal_damage 1 | 2 / 2 |
| focus | ability | 1 | uncommon | gain_intelligence 1; draw_cards 1 · Exhaust | int 2 |
| last_breath | skill | 0 | rare | gain_block 10; draw_cards 2 · Exhaust | 14 / draw 3 |
| last_stand | skill | 2 | uncommon | gain_block 12; draw_cards 1 | 17 / draw 2 |
| siphon | attack | 1 | common | deal_damage 4; gain_block 4 | 6 / 6 |
| **reinforce** (NEW) | skill | 1 | common | gain_block 7 | 10 |
| **deflector** (NEW) | skill | 1 | uncommon | gain_block 5; apply_status weak 1 | weak 2 |
| **bulwark** (NEW) | skill | 2 | rare | gain_block 12; gain_energy 1 | 16 |

Note: `focus` keeps `gain_intelligence` (the table lists it, flagged as a future-cleanup item — out of scope here; no INT consumers exist but that's pre-existing).

## Cards to DELETE (17 base + their `_plus`)
Not in the table → remove JSON (+`_plus`), art PNGs, translations, and all wiring:
`override, iron_will, tinker, carapace` (the 4 attribute-granters), `salvo, overdrive, overload, emp_burst, flash_bang, junk_bomb, scrap_strike, static_coil`, and last night's `lucky_shot, silver_tongue, gunslinger, windfall, executioner`.

## Wiring fixes (must, or boot/validator breaks)
- **`MetaProgress.INITIAL_CARD_POOL`**: remove all deleted ids; add `reinforce, deflector, bulwark`.
- **Starter decks**: `RunManager.DEFAULT_STARTER_DECK` and hero JSON `starter_deck` — `cowboy_bill` and **`hero_jerry_killer`** (Jerry's deck currently uses `scrap_strike` + `double_tap` — `scrap_strike` is deleted → replace, e.g. with `siphon`/`strike`).
- **`base_upgrades/card_research.json`** unlocks reference `flash_bang` + `junk_bomb` (deleted) → replace with surviving cards (e.g. `chain_link`, `deflector`) or trim.
- **Loot draft pool** (`loot_reward.gd` / `MetaProgress.get_unlocked_card_pool`) — dr(derives from INITIAL_CARD_POOL + unlocked_cards; verify deleted ids gone).
- Card art for deleted cards: orphan PNGs — delete them too (runtime-loaded with fallback; safe). New cards' art = Codex follow-up (letter/placeholder fallback meanwhile).

## Testing
Per phase: temp boot-scene logic tests + `scripts/smoke_test.sh` green before commit (DataValidator must pass with the new roster + no dangling card refs in pools/decks/upgrades). Key checks:
- Global STR/CON: `deal_damage 3` resolves to `3 + strength` (6 at base); `gain_block 3` → `3 + constitution`; `deal_damage_str_mult mult 2` → `strength*2` (NOT +global); `scale_damage_by_attacks` unaffected by global STR.
- `apply_stun` applies the `stun` status; enemy skips a turn; no lingering `shock`/`apply_shock` references anywhere (grep clean).
- DataValidator passes; `start_new_run` for both heroes builds a valid deck (no deleted-card refs); card_research unlocks resolve.

## Build phases (priority: foundation first, it gates everything)
1. **Foundation** — combat_engine global STR/CON + `deal_damage_str_mult`; Shock→Stun rename across code + i18n; data_validator (ALLOWED_EFFECT_TYPES +`deal_damage_str_mult`, `apply_shock`→`apply_stun`(+`_all`); ALLOWED_STATUS_NAMES `shock`→`stun`).
2. **Delete roster** — remove 17 base + `_plus` JSON + art + translations; un-wire pools/decks/card_research.
3. **Rebalance kept 18** — apply the table's numbers/costs, strip `scaling`, stun_baton→apply_stun, charged_shot→deal_damage_str_mult, double_tap 1×2 @ cost 2, etc.; update `_plus` + translations.
4. **Add 3 new** — reinforce/deflector/bulwark (+`_plus`) + translations + INITIAL_CARD_POOL.
5. **Catalog regen + full review + battle boot.**

## Risks
- Global STR/CON double-count if any `scaling` left behind → strip ALL `scaling` from kept cards (grep `scaling` in card_info/player after).
- Deleted card still referenced in a deck/pool/upgrade → DataValidator/encounter or `start_new_run` breaks. The wiring-fixes section is mandatory.
- This overhaul removes last night's 5 attribute cards and several others by owner decision — intentional.
