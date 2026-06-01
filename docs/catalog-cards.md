# Cards Catalog

**Last updated:** 2026-06-01
**Total cards:** 35 (excludes `_plus` upgrade variants)

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
| Common | 14 | adrenaline, brace, defend, double_tap, hot_swap, lucky_shot, scrap_strike, silver_tongue, siphon, static_coil, strike, stun_baton, tinker, weak_strike |
| Uncommon | 13 | acid_splash, cascade, chain_link, charged_shot, emp_burst, focus, gunslinger, iron_will, last_stand, overdrive, override, salvo, windfall |
| Rare | 8 | bone_breaker, carapace, executioner, flash_bang, junk_bomb, last_breath, overload, preemptive_strike |

| Type | Count |
|---|---|
| Ability | 3 |
| Attack | 18 |
| Skill | 14 |

| Keyword | Cards |
|---|---|
| Retain | brace, cascade |
| Exhaust | adrenaline, charged_shot, flash_bang, focus, iron_will, junk_bomb, last_breath, overdrive |

## Summary table

| ID | Title | Type | Cost | Rarity | Effects | Keywords | Art |
|---|---|---|---|---|---|---|---|
| `acid_splash` | Acid Splash | attack | 1 | uncommon | deal_damage_all 4; apply_status_all poison 2 | — | ✅ |
| `adrenaline` | Adrenaline | skill | 0 | common | gain_energy 2; draw_cards 1 | Exhaust | ✅ |
| `bone_breaker` | Bone Breaker | attack | 2 | rare | deal_damage 14 (+STR); apply_status vulnerable 2 | — | ✅ |
| `brace` | Brace | skill | 0 | common | gain_block 4 (+CON) | Retain | ✅ |
| `carapace` | Carapace | skill | 2 | rare | gain_block 15 (+CON); gain_constitution 1 | — | ✅ |
| `cascade` | Cascade | attack | 1 | uncommon | scale_damage_by_attacks (base=2, per=2) | Retain | ✅ |
| `chain_link` | Chain Link | attack | 1 | uncommon | deal_damage 6 (+STR); draw_cards 1 | — | ✅ |
| `charged_shot` | Charged Shot | attack | 2 | uncommon | deal_damage 12 (+STR) | Exhaust | ✅ |
| `defend` | Defend | skill | 1 | common | gain_block 3 (+CON) | — | ✅ |
| `double_tap` | Double Tap | attack | 1 | common | deal_damage 3 (+STR); deal_damage 3 (+STR) | — | ✅ |
| `emp_burst` | EMP Burst | skill | 2 | uncommon | apply_shock_all 2 | — | ✅ |
| `executioner` | Executioner | attack | 2 | rare | deal_damage 9 (+STR) | — | ✅ |
| `flash_bang` | Flash Bang | skill | 1 | rare | apply_shock_all 1 | Exhaust | ✅ |
| `focus` | Focus | ability | 1 | uncommon | gain_intelligence 1; draw_cards 1 | Exhaust | ✅ |
| `gunslinger` | Gunslinger | attack | 1 | uncommon | deal_damage 6; draw_cards 1 | — | ✅ |
| `hot_swap` | Hot Swap | skill | 1 | common | draw_cards 2 | — | ✅ |
| `iron_will` | Iron Will | ability | 1 | uncommon | gain_strength 1; gain_constitution 1 | Exhaust | ✅ |
| `junk_bomb` | Junk Bomb | skill | 2 | rare | deal_damage_all 6 (+STR); draw_cards 2 | Exhaust | ✅ |
| `last_breath` | Last Breath | skill | 0 | rare | gain_block 10 (+CON); draw_cards 2 | Exhaust | ✅ |
| `last_stand` | Last Stand | skill | 2 | uncommon | gain_block 12 (+CON); draw_cards 1 | — | ✅ |
| `lucky_shot` | Lucky Shot | attack | 1 | common | deal_damage 4 (+LUCK) | — | ✅ |
| `overdrive` | Overdrive | attack | 2 | uncommon | deal_damage 10 (+STR); apply_status_self vulnerable 1 | Exhaust | ✅ |
| `overload` | Overload | attack | 2 | rare | deal_damage 8 (+STR); apply_shock 2 | — | ✅ |
| `override` | Override | ability | 2 | uncommon | gain_strength 2 | — | ✅ |
| `preemptive_strike` | Preemptive Strike | skill | 1 | rare | apply_status_self double_damage 1 | — | ✅ |
| `salvo` | Salvo | attack | 2 | uncommon | deal_damage 4 (+STR); deal_damage 4 (+STR); deal_damage 4 (+STR) | — | ✅ |
| `scrap_strike` | Scrap Strike | attack | 1 | common | deal_damage 4 (+STR); draw_cards 1 | — | ✅ |
| `silver_tongue` | Silver Tongue | skill | 1 | common | apply_status weak 2; gain_block 3 | — | ✅ |
| `siphon` | Siphon | attack | 1 | common | deal_damage 4 (+STR); gain_block 4 (+CON) | — | ✅ |
| `static_coil` | Static Coil | attack | 1 | common | deal_damage 2 (+STR); gain_block 4 (+CON); apply_shock 1 | — | ✅ |
| `strike` | Strike | attack | 1 | common | deal_damage 3 (+STR) | — | ✅ |
| `stun_baton` | Stun Baton | attack | 1 | common | deal_damage 4 (+STR); apply_shock 1 | — | ✅ |
| `tinker` | Tinker | skill | 1 | common | gain_strength 1; gain_block 3 (+CON) | — | ✅ |
| `weak_strike` | Weak Strike | attack | 1 | common | deal_damage 3 (+STR); apply_status weak 1 | — | ✅ |
| `windfall` | Windfall | skill | 1 | uncommon | gain_block 4 (+LUCK); draw_cards 1 | — | ✅ |

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

### `siphon`
**Phase 5 — Common.** Cheap hybrid: chip damage plus a little block on one card.
- Effects: `deal_damage 4` (+STR), `gain_block 4` (+CON)
- JSON: `battle_scene/card_info/player/siphon.json`
- Art: `battle_scene/assets/images/cards/player/siphon.png`

### `brace`
**Phase 5 — Common.** Free-cost block that Retains — bank defense for the turn you need it.
- Effects: `gain_block 4` (+CON)
- Keywords: **Retain**
- JSON: `battle_scene/card_info/player/brace.json`
- Art: `battle_scene/assets/images/cards/player/brace.png`

### `double_tap`
**Phase 5 — Common.** Two separate 3-damage hits; Strength applies to each, and both count for attack-scaling combos.
- Effects: `deal_damage 3` (+STR) × 2
- JSON: `battle_scene/card_info/player/double_tap.json`
- Art: `battle_scene/assets/images/cards/player/double_tap.png`

### `scrap_strike`
**Phase 5 — Common.** Cantrip attack: small hit that replaces itself with a draw.
- Effects: `deal_damage 4` (+STR), `draw_cards 1`
- JSON: `battle_scene/card_info/player/scrap_strike.json`
- Art: `battle_scene/assets/images/cards/player/scrap_strike.png`

### `last_breath`
**Phase 5 — Rare.** Free-cost panic button: heavy block + 2 draw, then Exhausts.
- Effects: `gain_block 10` (+CON), `draw_cards 2`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/last_breath.json`
- Art: `battle_scene/assets/images/cards/player/last_breath.png`

### `last_stand`
**Phase 5 — Uncommon.** Big single-card defensive turn: 12 block + a draw to keep going.
- Effects: `gain_block 12` (+CON), `draw_cards 1`
- JSON: `battle_scene/card_info/player/last_stand.json`
- Art: `battle_scene/assets/images/cards/player/last_stand.png`

### `acid_splash`
**Phase 5 — Uncommon.** AoE: hits every enemy for 4 and stacks 2 Poison on all of them.
- Effects: `deal_damage_all 4`, `apply_status_all poison 2`
- JSON: `battle_scene/card_info/player/acid_splash.json`
- Art: `battle_scene/assets/images/cards/player/acid_splash.png`

### `focus`
**Phase 5 — Uncommon (ability).** Permanent +1 Intelligence + a draw, then Exhausts. Long-game scaling.
- Effects: `gain_intelligence 1`, `draw_cards 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/focus.json`
- Art: `battle_scene/assets/images/cards/player/focus.png`

### `chain_link`
**Phase 5 — Uncommon.** Mid attack that cantrips: 6 damage + a draw.
- Effects: `deal_damage 6` (+STR), `draw_cards 1`
- JSON: `battle_scene/card_info/player/chain_link.json`
- Art: `battle_scene/assets/images/cards/player/chain_link.png`

### `iron_will`
**Phase 5 — Uncommon (ability).** Permanent +1 Strength AND +1 Constitution, then Exhausts. Dual-stat enabler.
- Effects: `gain_strength 1`, `gain_constitution 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/iron_will.json`
- Art: `battle_scene/assets/images/cards/player/iron_will.png`

### `carapace`
**Phase 5 — Rare.** Huge 15 block + permanent +1 Constitution — defensive scaling payoff.
- Effects: `gain_block 15` (+CON), `gain_constitution 1`
- JSON: `battle_scene/card_info/player/carapace.json`
- Art: `battle_scene/assets/images/cards/player/carapace.png`

### `flash_bang`
**Phase 5 — Rare.** Cheap AoE Shock — 1 stack on every enemy, then Exhausts. Crowd interrupt tool.
- Effects: `apply_shock_all 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/flash_bang.json`
- Art: `battle_scene/assets/images/cards/player/flash_bang.png`

### `bone_breaker`
**Phase 5 — Rare.** Heavy 14 damage + 2 Vulnerable to set up the follow-up. Boss-killer opener.
- Effects: `deal_damage 14` (+STR), `apply_status vulnerable 2`
- JSON: `battle_scene/card_info/player/bone_breaker.json`
- Art: `battle_scene/assets/images/cards/player/bone_breaker.png`

### `lucky_shot`
**Attributes wave — Common.** Luck-scaling attack: rewards a high-Luck (crit) build with bigger hits.
- Effects: `deal_damage 4` scaling `luck`
- JSON: `battle_scene/card_info/player/lucky_shot.json`
- Art: `battle_scene/assets/images/cards/player/lucky_shot.png`

### `silver_tongue`
**Attributes wave — Common.** Charm-flavored control: applies Weak and a little block.
- Effects: `apply_status weak 2`, `gain_block 3`
- JSON: `battle_scene/card_info/player/silver_tongue.json`
- Art: `battle_scene/assets/images/cards/player/silver_tongue.png`

### `gunslinger`
**Attributes wave — Uncommon.** Cantrip attack: solid 6 damage that replaces itself with a draw.
- Effects: `deal_damage 6`, `draw_cards 1`
- JSON: `battle_scene/card_info/player/gunslinger.json`
- Art: `battle_scene/assets/images/cards/player/gunslinger.png`

### `windfall`
**Attributes wave — Uncommon.** Luck-scaling block + a draw; defensive payoff for a Luck build.
- Effects: `gain_block 4` scaling `luck`, `draw_cards 1`
- JSON: `battle_scene/card_info/player/windfall.json`
- Art: `battle_scene/assets/images/cards/player/windfall.png`

### `executioner`
**Attributes wave — Rare.** Strength-scaling finisher: heavy single hit for Jerry / high-STR builds.
- Effects: `deal_damage 9` (+STR)
- JSON: `battle_scene/card_info/player/executioner.json`
- Art: `battle_scene/assets/images/cards/player/executioner.png`

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
