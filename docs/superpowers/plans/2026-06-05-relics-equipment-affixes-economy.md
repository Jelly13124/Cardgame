# Relics + Equipment Affixes + Scrap Economy — Plan

> Executes spec 2026-06-05-relics-equipment-affixes-economy-design.md. Controller
> dispatches one implementer subagent per task, SEQUENTIAL (shared files),
> smoke-gate + commit each. Priority order = build order; earlier tasks must be
> green+committed first. No push. Gate: `GODOT_BIN="C:/Program Files/Godot/Godot.exe"
> bash scripts/smoke_test.sh`. CSV edits → reimport before smoke.

## P1 — Relics reconcile
- [ ] R1 — Add `"unique"` rarity to validator + ensure unique/“none” never enters
  common/uncommon/rare drop & shop buckets. Reconcile every relic JSON's
  rarity/effects to the target table; add `crit_plating.json`; remove `rabbits_foot`
  (+scrub refs). Add the on-gain-block relic trigger (combat_engine gain_block →
  RelicEffectSystem) for scavenger_lens (deal 3 random) + crit_plating (block crit);
  war_horn passive +1 STR at battle start (reuse if present). i18n. gdscript-reviewer
  + content-balance + smoke + commit.

## P2 — Equipment affix system
- [ ] E_A — affix_pool.gd (positive + curse affixes, roll/reroll_one/describe) +
  validator ALLOWED affix types + instance shape. smoke + commit.
- [ ] E_B — instance storage + back-compat: RunManager.as_equip_instance(); convert
  equipped_items/backpack/stash read+write to accept string OR instance; migration on
  load; recompute_attributes reads affixes (attrs + max_hp + crit_pct). gdscript-reviewer
  (save migration) + smoke + commit.
- [ ] E_C — drops roll instances (loot_reward + _roll_drop_for_node_type); equipment
  shells keep set_id; equipment_panel displays affix lines + tooltips; set detection by
  instance set_id. content-balance + smoke + commit.

## P3 — Scrap + Blacksmith
- [ ] S1 — MetaProgress.scrap (mirror caps, back-compat) + scrap_changed. smoke + commit.
- [ ] S2 — Home-base Blacksmith station: list owned equip, Dismantle (→scrap by rarity)
  + Reforge (spend scrap → AffixPool.reroll_one). UI. smoke + commit.

## P4 — Caps equipment shop
- [ ] Q1 — Home-base equipment shop: generate instances, price in caps by rarity, buy →
  stash. UI. smoke + commit.

## P5 — Cursed equipment
- [ ] C1 — ascension≥3 drop chance for cursed instances (1 curse + up to 3 positive);
  red treatment in panel. smoke + commit.

## P6 — Starter deck editor + card unlock
- [ ] D1 — Card unlock with Core (extend unlocked_cards + cost). smoke + commit.
- [ ] D2 — Home-base starter-deck editor: ≤2 swaps from unlocked cards, per-hero
  override in MetaProgress, applied in start_new_run. UI. smoke + commit.

## Final
- [ ] Full smoke green. Regen HTML catalogs (relics/equipment/keywords) so they reflect
  the new roster/affixes. Morning summary: done/deferred, owner-verify (all base UI),
  Codex art TODOs (caps/scrap icons, new relic/equip art).
