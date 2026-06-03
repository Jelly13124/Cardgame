# Cards Catalog

**Last updated:** 2026-06-03
**Total cards:** 24 (excludes `_plus` upgrade variants)

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
| Common | 9 | brace, corrode, defend, hot_swap, patch_kit, reinforce, siphon, strike, weak_strike |
| Uncommon | 8 | acid_splash, cascade, chain_link, charged_shot, deflector, focus, last_stand, spiked_guard |
| Rare | 7 | adrenaline, bone_breaker, bulwark, double_tap, last_breath, preemptive_strike, stun_baton |

| Type | Count |
|---|---|
| Ability | 1 |
| Attack | 10 |
| Skill | 13 |

| Keyword | Cards |
|---|---|
| Retain | brace, cascade |
| Exhaust | adrenaline, charged_shot, focus, last_breath |

## Summary table

| ID | Title | Type | Cost | Rarity | Effects | Keywords | Art |
|---|---|---|---|---|---|---|---|
| `acid_splash` | Acid Splash | attack | 1 | uncommon | deal_damage_all 4; apply_status_all poison 2 | — | ✅ |
| `adrenaline` | Adrenaline | skill | 0 | rare | gain_energy 2; draw_cards 1 | Exhaust | ✅ |
| `bone_breaker` | Bone Breaker | attack | 2 | rare | deal_damage 14; apply_status vulnerable 2 | — | ✅ |
| `brace` | Brace | skill | 0 | common | gain_block 4 | Retain | ✅ |
| `bulwark` | Bulwark | skill | 2 | rare | gain_block 12; gain_energy 1 | — | ✅ |
| `cascade` | Cascade | attack | 1 | uncommon | scale_damage_by_attacks (base=2, per=2) | Retain | ✅ |
| `chain_link` | Chain Link | attack | 1 | uncommon | deal_damage 6; draw_cards 1 | — | ✅ |
| `charged_shot` | Charged Shot | attack | 1 | uncommon | deal_damage_str_mult {'mult': 2} | Exhaust | ✅ |
| `corrode` | Corrode | skill | 1 | common | apply_status frail 2 | — | ✅ |
| `defend` | Defend | skill | 1 | common | gain_block 3 | — | ✅ |
| `deflector` | Deflector | skill | 1 | uncommon | gain_block 5; apply_status weak 1 | — | ✅ |
| `double_tap` | Double Tap | attack | 2 | rare | deal_damage 1; deal_damage 1 | — | ✅ |
| `focus` | Focus | ability | 1 | uncommon | gain_intelligence 1; draw_cards 1 | Exhaust | ✅ |
| `hot_swap` | Hot Swap | skill | 1 | common | draw_cards 2 | — | ✅ |
| `last_breath` | Last Breath | skill | 0 | rare | gain_block 10; draw_cards 2 | Exhaust | ✅ |
| `last_stand` | Last Stand | skill | 2 | uncommon | gain_block 12; draw_cards 1 | — | ✅ |
| `patch_kit` | Patch Kit | skill | 1 | common | apply_status_self regen 3 | — | ✅ |
| `preemptive_strike` | Preemptive Strike | skill | 1 | rare | apply_status_self double_damage 1 | — | ✅ |
| `reinforce` | Reinforce | skill | 1 | common | gain_block 7 | — | ✅ |
| `siphon` | Siphon | attack | 1 | common | deal_damage 4; gain_block 4 | — | ✅ |
| `spiked_guard` | Spiked Guard | skill | 1 | uncommon | gain_block 5; apply_status_self thorns 2 | — | ✅ |
| `strike` | Strike | attack | 1 | common | deal_damage 3 | — | ✅ |
| `stun_baton` | Stun Baton | attack | 1 | rare | deal_damage 1; apply_stun {'stacks': 1} | — | ✅ |
| `weak_strike` | Weak Strike | attack | 1 | common | deal_damage 3; apply_status weak 1 | — | ✅ |

## Per-card details

> STR is auto-added to all attack damage and CON to all block **globally** (default +3 each) — the per-card `scaling` field is deprecated/removed. The "Effects" lines below list the card-face BASE numbers; STR/CON are added at resolve time, not shown on the face.

### `strike`
**Starter deck (×4).** Vanilla attack. Strength is added globally at resolve.
- Effects: `deal_damage 3`
- JSON: `battle_scene/card_info/player/strike.json`
- Art: `battle_scene/assets/images/cards/player/strike.png`

### `weak_strike`
**Starter deck (×1).** "Dead weight" card the player wants to remove. Slightly cheaper utility for inflicting Weak.
- Effects: `deal_damage 3`, `apply_status weak 1`
- JSON: `battle_scene/card_info/player/weak_strike.json`
- Art: `battle_scene/assets/images/cards/player/weak_strike.png`

### `defend`
**Starter deck (×4).** Vanilla block. Constitution is added globally at resolve.
- Effects: `gain_block 3`
- JSON: `battle_scene/card_info/player/defend.json`
- Art: `battle_scene/assets/images/cards/player/defend.png`

### `reinforce`
**NEW (Phase E) — Common.** Solid single-card block; CON is added globally on top.
- Effects: `gain_block 7`
- JSON: `battle_scene/card_info/player/reinforce.json`
- Art: `battle_scene/assets/images/cards/player/reinforce.png`

### `deflector`
**NEW (Phase E) — Uncommon.** Block plus a Weak debuff on the target — defensive tempo card.
- Effects: `gain_block 5`, `apply_status weak 1`
- JSON: `battle_scene/card_info/player/deflector.json`
- Art: `battle_scene/assets/images/cards/player/deflector.png`

### `bulwark`
**NEW (Phase E) — Rare.** Big defensive turn that refunds energy: 12 block + 1 energy back.
- Effects: `gain_block 12`, `gain_energy 1`
- JSON: `battle_scene/card_info/player/bulwark.json`
- Art: `battle_scene/assets/images/cards/player/bulwark.png`

### `preemptive_strike`
**Loot draft (rare).** Doubles damage on the next attack played.
- Effects: `apply_status_self double_damage 1`
- JSON: `battle_scene/card_info/player/preemptive_strike.json`
- Art: `battle_scene/assets/images/cards/player/preemptive_strike.png`

### `stun_baton`
**Control (rare).** Anti-mortar / anti-boss tool: chip damage + 1 Stun to skip an enemy turn.
- Effects: `deal_damage 1`, `apply_stun 1`
- JSON: `battle_scene/card_info/player/stun_baton.json`
- Art: `battle_scene/assets/images/cards/player/stun_baton.png`

### `cascade`
**Combo.** Retains in hand. Damage = `2 + 2 × (attacks played this turn)`. Snowballs in attack-heavy hands.
- Effects: `scale_damage_by_attacks` (base 2, per 2)
- Keywords: **Retain**
- JSON: `battle_scene/card_info/player/cascade.json`
- Art: `battle_scene/assets/images/cards/player/cascade.png`

### `hot_swap`
**Combo.** Pure card draw, cheap.
- Effects: `draw_cards 2`
- JSON: `battle_scene/card_info/player/hot_swap.json`
- Art: `battle_scene/assets/images/cards/player/hot_swap.png`

### `charged_shot`
**Burst (uncommon).** Damage scales purely off Strength (2× STR), independent of the global +STR. Exhausts.
- Effects: `deal_damage_str_mult` (mult 2)
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/charged_shot.json`
- Art: `battle_scene/assets/images/cards/player/charged_shot.png`

### `corrode`
**Common control skill.** Applies Frail so the enemy's future block/defense is weaker.
- Effects: `apply_status frail 2`
- JSON: `battle_scene/card_info/player/corrode.json`
- Art: `battle_scene/assets/images/cards/player/corrode.png`

### `adrenaline`
**Burst (rare).** Free-cost energy + draw. Exhausts. Enables combo turns.
- Effects: `gain_energy 2`, `draw_cards 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/adrenaline.json`
- Art: `battle_scene/assets/images/cards/player/adrenaline.png`

### `siphon`
**Common.** Cheap hybrid: chip damage plus a little block on one card.
- Effects: `deal_damage 4`, `gain_block 4`
- JSON: `battle_scene/card_info/player/siphon.json`
- Art: `battle_scene/assets/images/cards/player/siphon.png`

### `brace`
**Common.** Free-cost block that Retains — bank defense for the turn you need it.
- Effects: `gain_block 4`
- Keywords: **Retain**
- JSON: `battle_scene/card_info/player/brace.json`
- Art: `battle_scene/assets/images/cards/player/brace.png`

### `double_tap`
**Rare.** Two separate hits; Strength applies to each, and both count for attack-scaling combos.
- Effects: `deal_damage 1` × 2
- JSON: `battle_scene/card_info/player/double_tap.json`
- Art: `battle_scene/assets/images/cards/player/double_tap.png`

### `last_breath`
**Rare.** Free-cost panic button: heavy block + 2 draw, then Exhausts.
- Effects: `gain_block 10`, `draw_cards 2`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/last_breath.json`
- Art: `battle_scene/assets/images/cards/player/last_breath.png`

### `last_stand`
**Uncommon.** Big single-card defensive turn: 12 block + a draw to keep going.
- Effects: `gain_block 12`, `draw_cards 1`
- JSON: `battle_scene/card_info/player/last_stand.json`
- Art: `battle_scene/assets/images/cards/player/last_stand.png`

### `patch_kit`
**Common sustain skill.** Applies Regen to the player for delayed recovery.
- Effects: `apply_status_self regen 3`
- JSON: `battle_scene/card_info/player/patch_kit.json`
- Art: `battle_scene/assets/images/cards/player/patch_kit.png`

### `acid_splash`
**Uncommon.** AoE: hits every enemy for 4 and stacks 2 Poison on all of them.
- Effects: `deal_damage_all 4`, `apply_status_all poison 2`
- JSON: `battle_scene/card_info/player/acid_splash.json`
- Art: `battle_scene/assets/images/cards/player/acid_splash.png`

### `focus`
**Uncommon (ability).** Permanent +1 Intelligence + a draw, then Exhausts. Long-game scaling.
- Effects: `gain_intelligence 1`, `draw_cards 1`
- Keywords: **Exhaust**
- JSON: `battle_scene/card_info/player/focus.json`
- Art: `battle_scene/assets/images/cards/player/focus.png`

### `chain_link`
**Uncommon.** Mid attack that cantrips: 6 damage + a draw.
- Effects: `deal_damage 6`, `draw_cards 1`
- JSON: `battle_scene/card_info/player/chain_link.json`
- Art: `battle_scene/assets/images/cards/player/chain_link.png`

### `spiked_guard`
**Uncommon defense skill.** Blocks immediately and adds Thorns for retaliation.
- Effects: `gain_block 5`, `apply_status_self thorns 2`
- JSON: `battle_scene/card_info/player/spiked_guard.json`
- Art: `battle_scene/assets/images/cards/player/spiked_guard.png`

### `bone_breaker`
**Rare.** Heavy 14 damage + 2 Vulnerable to set up the follow-up. Boss-killer opener.
- Effects: `deal_damage 14`, `apply_status vulnerable 2`
- JSON: `battle_scene/card_info/player/bone_breaker.json`
- Art: `battle_scene/assets/images/cards/player/bone_breaker.png`

## Supported effect types (current as of this slice)

See `combat_engine.gd` `_apply_effect()` for the full match. Allowed types tracked in `data_validator.gd` `ALLOWED_EFFECT_TYPES`.

> **STR is auto-added to all attack damage and CON to all block, globally** (default +3 each). The per-card `scaling` field is deprecated/removed — combat_engine no longer reads it. Card JSON carries the BASE number only.

| Effect type | Behavior | Required fields |
|---|---|---|
| `deal_damage` | Target enemy takes amount (+STR globally). | `amount` |
| `deal_damage_all` | All enemies take amount (+STR globally). | `amount` |
| `deal_damage_str_mult` | Damage = `mult` × Strength (does NOT receive the global +STR — already STR-based). | `mult` |
| `scale_damage_by_attacks` | Damage = base + per × attacks_played_this_turn. | `base`, `per` |
| `gain_block` | Player gains block (+CON globally). | `amount` |
| `gain_energy` | Player gains energy this turn. | `amount` |
| `draw_cards` | Draw N cards. | `amount` |
| `gain_strength` / `_constitution` / `_intelligence` / `_luck` / `_charm` | Permanent stat buff. | `amount` |
| `apply_status` | Apply status to targeted enemy. | `status`, `stacks` |
| `apply_status_self` | Apply status to player. | `status`, `stacks` |
| `apply_status_all` | Apply status to all enemies. | `status`, `stacks` |
| `apply_stun` | Stack Stun on targeted enemy (skips its next turn per stack). | `stacks` (or `amount`) |
| `apply_stun_all` | Stack Stun on all enemies. | `stacks` (or `amount`) |
| `exhaust_self` | Marker — card is queue_free'd after resolve instead of going to discard. | — |

## Adding a new card — checklist

1. Create `battle_scene/card_info/player/{id}.json` matching the schema.
2. Add `{id}` to `run_system/ui/loot_reward.gd` `draft_pool` so it can be drafted.
3. If introducing a new effect type, add a handler in `combat_engine.gd` `_apply_effect()` AND add the type to `data_validator.gd` `ALLOWED_EFFECT_TYPES`.
4. Generate a `512x320` landscape PNG illustration using the active art contract in `docs/art-style-reference.md` and ADR-0018 → `battle_scene/assets/images/cards/player/{id}.png`. Do not bake in card UI, labels, cost, title, rarity, type, or description text.
5. Restart the editor — DataValidator scans on `RunManager._ready()` and will fail loud if the JSON has a typo.
