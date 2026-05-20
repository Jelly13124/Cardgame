# Cards Catalog

**Last updated:** 2026-05-18
**Total cards:** 17 (5 original + 12 Tactical Toolkit)

## Paths

| Resource | Path |
|---|---|
| Card JSON definitions | `battle_scene/card_info/player/{id}.json` |
| Card art (PNG) | `battle_scene/assets/images/cards/player/{id}.png` |
| Generated art pipeline (intermediates) | `battle_scene/assets/images/cards/player/generated_sheet/` |
| Effect resolver code | `battle_scene/combat_engine.gd` `_apply_effect()` |
| Schema validator | `battle_scene/data_validator.gd` `validate_card()` |
| Loot draft pool | `run_system/ui/loot_reward.gd` `draft_pool` |
| Starter deck | `run_system/core/run_manager.gd` `DEFAULT_STARTER_DECK` |

## Quick stats

| Rarity | Count | IDs |
|---|---|---|
| Common | 8 | strike, weak_strike, defend, stun_baton, static_coil, tinker, hot_swap, adrenaline |
| Uncommon | 6 | override, emp_burst, cascade, salvo, overdrive, charged_shot |
| Rare | 3 | preemptive_strike, overload, junk_bomb |

| Type | Count |
|---|---|
| Attack | 9 |
| Skill | 7 |
| Ability | 1 |

| Keyword | Cards |
|---|---|
| Retain | cascade |
| Exhaust | overdrive, charged_shot, junk_bomb, adrenaline |

## Summary table

| ID | Title | Type | Cost | Rarity | Effects | Keywords | Art |
|---|---|---|---|---|---|---|---|
| `strike` | Strike | attack | 1 | common | deal_damage 3 (+STR) | — | ✅ |
| `weak_strike` | Weak Strike | attack | 1 | common | deal_damage 3 (+STR); apply Weak 1 | — | ✅ |
| `defend` | Defend | skill | 1 | common | gain_block 3 (+CON) | — | ✅ |
| `override` | Override | ability | 2 | uncommon | gain_strength 2 | — | ✅ |
| `preemptive_strike` | Preemptive Strike | skill | 1 | rare | apply_status_self double_damage 1 | — | ✅ |
| `stun_baton` | Stun Baton | attack | 1 | common | deal_damage 4 (+STR); apply Shock 1 | — | ✅ |
| `static_coil` | Static Coil | attack | 1 | common | deal_damage 2 (+STR); gain_block 4 (+CON); apply Shock 1 | — | ✅ |
| `emp_burst` | EMP Burst | skill | 2 | uncommon | apply_shock_all 2 | — | ✅ |
| `overload` | Overload | attack | 2 | rare | deal_damage 8 (+STR); apply Shock 2 | — | ✅ |
| `cascade` | Cascade | attack | 1 | uncommon | scale_damage_by_attacks (base=2, per=2) | Retain | ✅ |
| `salvo` | Salvo | attack | 2 | uncommon | deal_damage 4 (+STR) × 3 | — | ✅ |
| `tinker` | Tinker | skill | 1 | common | gain_strength 1; gain_block 3 (+CON) | — | ✅ |
| `hot_swap` | Hot Swap | skill | 1 | common | draw_cards 2 | — | ✅ |
| `overdrive` | Overdrive | attack | 2 | uncommon | deal_damage 10 (+STR); apply_status_self vulnerable 1 | Exhaust | ✅ |
| `charged_shot` | Charged Shot | attack | 2 | uncommon | deal_damage 12 (+STR) | Exhaust | ✅ |
| `junk_bomb` | Junk Bomb | skill | 2 | rare | deal_damage_all 6 (+STR); draw_cards 2 | Exhaust | ✅ |
| `adrenaline` | Adrenaline | skill | 0 | common | gain_energy 2; draw_cards 1 | Exhaust | ✅ |

## Per-card details

### `strike`
**Starter deck (×4).** Vanilla attack. Scales with Strength.
- Effects: `deal_damage 3` scaling `strength`
- JSON: `battle_scene/card_info/player/strike.json`
- Art: `battle_scene/assets/images/cards/player/strike.png`

### `weak_strike`
**Starter deck (×1).** "Dead weight" card the player wants to remove. Slightly cheaper utility for inflicting Weak.
- Effects: `deal_damage 3` (+STR), `apply_status weak 1`
- JSON: `battle_scene/card_info/player/weak_strike.json`
- Art: `battle_scene/assets/images/cards/player/weak_strike.png`

### `defend`
**Starter deck (×4).** Vanilla block. Scales with Constitution.
- Effects: `gain_block 3` scaling `constitution`
- JSON: `battle_scene/card_info/player/defend.json`
- Art: `battle_scene/assets/images/cards/player/defend.png`

### `override`
**Loot draft.** Permanent strength buff (ability type).
- Effects: `gain_strength 2`
- JSON: `battle_scene/card_info/player/override.json`
- Art: `battle_scene/assets/images/cards/player/override.png`

### `preemptive_strike`
**Loot draft (rare).** Doubles damage on the next attack played.
- Effects: `apply_status_self double_damage 1`
- JSON: `battle_scene/card_info/player/preemptive_strike.json`
- Art: `battle_scene/assets/images/cards/player/preemptive_strike.png`

### `stun_baton`
**Tactical Toolkit — Control.** Anti-mortar / anti-boss tool: 4 damage + 1 Shock on a single enemy.
- Effects: `deal_damage 4` (+STR), `apply_shock 1`
- JSON: `battle_scene/card_info/player/stun_baton.json`
- Art: `battle_scene/assets/images/cards/player/stun_baton.png`

### `static_coil`
**Tactical Toolkit — Control.** Hybrid: small damage + block + Shock. Good budget defensive Shock source.
- Effects: `deal_damage 2` (+STR), `gain_block 4` (+CON), `apply_shock 1`
- JSON: `battle_scene/card_info/player/static_coil.json`
- Art: `battle_scene/assets/images/cards/player/static_coil.png`

### `emp_burst`
**Tactical Toolkit — Control.** AoE Shock — every alive enemy gets 2 stacks. Crippling against multi-attack pattern enemies.
- Effects: `apply_shock_all 2`
- JSON: `battle_scene/card_info/player/emp_burst.json`
- Art: `battle_scene/assets/images/cards/player/emp_burst.png`

### `overload`
**Tactical Toolkit — Control (rare).** Heavy single-target with strong Shock stacks. Boss-killer.
- Effects: `deal_damage 8` (+STR), `apply_shock 2`
- JSON: `battle_scene/card_info/player/overload.json`
- Art: `battle_scene/assets/images/cards/player/overload.png`

### `cascade`
**Tactical Toolkit — Combo.** Retains in hand. Damage = `2 + 2 × (attacks played this turn)`. Snowballs in attack-heavy hands.
- Effects: `scale_damage_by_attacks` (base 2, per 2)
- Keywords: **Retain**
- JSON: `battle_scene/card_info/player/cascade.json`
- Art: `battle_scene/assets/images/cards/player/cascade.png`

### `salvo`
**Tactical Toolkit — Combo.** Three independent 4-damage hits. Combos with Cascade (3 attacks = +6 base), strength stacks 3 times.
- Effects: `deal_damage 4` (+STR) repeated 3 times
- JSON: `battle_scene/card_info/player/salvo.json`
- Art: `battle_scene/assets/images/cards/player/salvo.png`

### `tinker`
**Tactical Toolkit — Combo.** Permanent +1 Strength + 3 Block. Early-game scaling enabler.
- Effects: `gain_strength 1`, `gain_block 3` (+CON)
- JSON: `battle_scene/card_info/player/tinker.json`
- Art: `battle_scene/assets/images/cards/player/tinker.png`

### `hot_swap`
**Tactical Toolkit — Combo.** Pure card draw, cheap.
- Effects: `draw_cards 2`
- JSON: `battle_scene/card_info/player/hot_swap.json`
- Art: `battle_scene/assets/images/cards/player/hot_swap.png`

### `overdrive`
**Tactical Toolkit — Burst.** High damage at the cost of self-Vulnerable next turn. Exhausts.
- Effects: `deal_damage 10` (+STR), `apply_status_self vulnerable 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/overdrive.json`
- Art: `battle_scene/assets/images/cards/player/overdrive.png`

### `charged_shot`
**Tactical Toolkit — Burst.** Pure 12 damage burst. Exhausts.
- Effects: `deal_damage 12` (+STR)
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/charged_shot.json`
- Art: `battle_scene/assets/images/cards/player/charged_shot.png`

### `junk_bomb`
**Tactical Toolkit — Burst (rare).** AoE 6 damage + 2 card draw. Exhausts. Trash-mob clearer + tempo.
- Effects: `deal_damage_all 6` (+STR), `draw_cards 2`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/junk_bomb.json`
- Art: `battle_scene/assets/images/cards/player/junk_bomb.png`

### `adrenaline`
**Tactical Toolkit — Burst.** Free-cost energy + draw. Exhausts. Enables combo turns.
- Effects: `gain_energy 2`, `draw_cards 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/adrenaline.json`
- Art: `battle_scene/assets/images/cards/player/adrenaline.png`

## Supported effect types (current as of this slice)

See `combat_engine.gd` `_apply_effect()` for the full match. Allowed types tracked in `data_validator.gd` `ALLOWED_EFFECT_TYPES`.

| Effect type | Behavior | Required fields |
|---|---|---|
| `deal_damage` | Target enemy takes amount (+STR if scaling). | `amount`, optional `scaling` |
| `deal_damage_all` | All enemies take amount. | `amount`, optional `scaling` |
| `scale_damage_by_attacks` | Damage = base + per × attacks_played_this_turn. | `base`, `per` |
| `gain_block` | Player gains block (+CON if scaling). | `amount`, optional `scaling` |
| `gain_energy` | Player gains energy this turn. | `amount` |
| `draw_cards` | Draw N cards. | `amount` |
| `gain_strength` / `_constitution` / `_intelligence` / `_luck` / `_charm` | Permanent stat buff. | `amount` |
| `apply_status` | Apply status to targeted enemy. | `status`, `stacks` |
| `apply_status_self` | Apply status to player. | `status`, `stacks` |
| `apply_status_all` | Apply status to all enemies. | `status`, `stacks` |
| `apply_shock` | Stack Shock on targeted enemy. | `stacks` (or `amount`) |
| `apply_shock_all` | Stack Shock on all enemies. | `stacks` (or `amount`) |
| `exhaust_self` | Marker — card is queue_free'd after resolve instead of going to discard. | — |

## Adding a new card — checklist

1. Create `battle_scene/card_info/player/{id}.json` matching the schema.
2. Add `{id}` to `run_system/ui/loot_reward.gd` `draft_pool` so it can be drafted.
3. If introducing a new effect type, add a handler in `combat_engine.gd` `_apply_effect()` AND add the type to `data_validator.gd` `ALLOWED_EFFECT_TYPES`.
4. Generate art (see `docs/asset-spec-tactical-toolkit.md` for the codex prompt format) → `battle_scene/assets/images/cards/player/{id}.png`.
5. Restart the editor — DataValidator scans on `RunManager._ready()` and will fail loud if the JSON has a typo.
