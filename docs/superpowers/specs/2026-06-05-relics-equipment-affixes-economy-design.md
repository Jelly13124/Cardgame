# Relics Rebalance + Equipment Affix System + Scrap Economy — Design

> Large overnight batch, executed in PRIORITY ORDER (relics → affixes/weaken →
> scrap+blacksmith → caps shop → cursed → deck editor). Later phases may not all
> land in one night — each phase is independently shippable, smoke-gated, and
> committed. Equipment art / icons are Codex's. HIGH RISK: the affix system
> changes the equipment SAVE format — all save changes must be backward-compatible
> (old `meta.json` / run state must still load).

**Implementer note:** before each phase READ the files it touches (listed
per-phase) to match existing patterns. The two-place rule applies (new
effect/affix/relic-effect types register in handler + validator).

---

## PHASE 1 — Relics: reconcile to the target roster (docs/… relics.html)

Target = 17 relics. Most already exist in `run_system/data/relics/`. Bring the
roster to exactly match the target table below (rarity + effect + i18n). READ each
existing relic JSON + `relic_effect_system.gd` + `data_validator.gd` first.

**Target roster:**
- **Common (8):** `barbed_plating` (turn start: gain 1 Thorns), `cracked_battery`
  (turn start: deal 1 to ALL enemies — CHANGE from its old effect), `lucky_cog`
  (victory: +5 gold), `repair_kit` (victory: heal 3), `sharpened_scrap` (attack
  damage +1), `signal_jammer` (enemy's FIRST attack each combat −2), `steel_plating`
  (first turn: +6 block), `yin_yang_compass` (polarity — keep).
- **Uncommon (7):** `adrenaline_pump` (first turn +1 energy), `bounty_tags`
  (victory: +12 gold AND heal 3), `bulk_actuator` (set Strength=4, max 4),
  `inertial_dampener` (every enemy attack −1), `medkit_drone` (victory heal 4),
  `scavenger_lens` (on gain block: deal 3 to a random enemy), `war_horn` (+1 Strength).
- **Rare (1):** `crit_plating` (NEW: your Block can crit — luck-scaled chance for
  1.5× block).
- **Unique (1):** `crit_clip` (Bill's attack crit; rarity → `unique`).

**Work:**
1. Add `"unique"` to `data_validator.ALLOWED_RARITIES` (and anywhere rarity is
   enumerated). Unique relics never roll as loot (they're hero-starting; already
   excluded by ownership — verify `crit_clip` rarity=unique doesn't break the
   drop/shop rarity buckets, which only key common/uncommon/rare — unique must be
   filtered OUT of those buckets so it never drops).
2. New relic effect hooks if missing (check first; some may already exist):
   - `scavenger_lens` + `crit_plating` need an **on-gain-block relic trigger**.
     Add a `RelicEffectSystem.on_player_gain_block(player, amount) -> int` called
     from `combat_engine` gain_block (returns possibly-modified block for the crit
     case; and applies scavenger's random-enemy damage). Register effect types
     `gain_block_crit` (crit_plating) + `block_gain_damage` (scavenger_lens) or
     reuse existing ones if present.
   - `war_horn` needs a passive **+strength at battle start**. If a passive-stat
     relic mechanism exists reuse it; else add `on_battle_start` stat grant.
3. Reconcile every relic JSON's `rarity` + `effects` + description to the table;
   add `crit_plating.json`. Update i18n (`content_relics.csv` en/zh) for any
   changed/new relics.
4. Remove relics NOT in the target list (e.g. `rabbits_foot` if present) — `git rm`
   + scrub references.
5. content-balance + gdscript-reviewer on new handlers. Smoke. Commit.

---

## PHASE 2 — Equipment Affix System + weakening (the foundation)

Replace static `{bonuses}` equipment with **per-instance rolled affixes**.

### Affix model
An affix = `{ "type": String, "value": int }`. Central pool in a new
`run_system/core/affix_pool.gd` (no class_name; preload) defining roll-able
positive affixes and curse affixes:
- Positive: `attr_strength|attr_constitution|attr_intelligence|attr_luck|attr_charm`
  (value 1), `crit_pct` (5), `max_hp` (10). (Conservative = "weaker".)
- Curse (Phase 5): `curse_attr_*` (−1), `curse_max_hp` (−8), `curse_crit` (−5).
- `AffixPool.roll(rarity, cursed) -> Array` returns the affix list for a freshly
  generated item: common→1 positive, uncommon→2, rare→2 (+ the item keeps its
  `set_id` for the set bonus), cursed→1 curse + up to 3 positive.
- `AffixPool.reroll_one(affixes) -> Array` returns a copy with one random non-curse
  affix replaced by a fresh roll (for blacksmith reforge).
- `AffixPool.describe(affix) -> String` for tooltips/UI (localized).

### Equipment instance (the save-format change)
An equipped/owned item becomes a Dictionary instance:
`{ "base": item_id, "rarity": r, "affixes": [..], "cursed": bool, "set_id": s }`.
- `base` = one of the existing 21 item ids (slot + art shell; its old `bonuses`
  are IGNORED — affixes replace them). `set_id` carried for rare set membership.
- `RunManager.equipped_items[slot]` = instance dict or `{}`/"" when empty.
- Backpack equip cells: `{ "kind":"equip", "item": <instance> }`.
- `MetaProgress.stash` entries become instance dicts.
- **Back-compat migration:** wherever an item is read, accept BOTH the old string
  form (`item_id`) and the new instance dict. A central helper
  `RunManager.as_equip_instance(x) -> Dictionary` converts a legacy string to an
  instance by deriving affixes from that item's JSON `bonuses` (so existing saves
  keep their gear's power). Persist instances on next save. Never wipe saves.

### Consumers to update
- `recompute_attributes()`: sum affix attribute values (+ apply `max_hp` to
  `max_health`, `crit_pct` into the luck/crit pipeline) across equipped instances,
  instead of reading `bonuses`.
- Equipment generation on DROP (`loot_reward` + `_roll_drop_for_node_type`): pick a
  base item for the slot + roll affixes by the drop's rarity → an instance.
- `equipment_panel.gd`: display affix list per item (slot icon + affix lines);
  tooltips show affixes. Equip/unequip/move/drag operate on instances.
- Set bonuses: detect by instance `set_id` (rare items only carry set_id).
- The 21 equipment JSONs: keep as base shells (slot, art, set_id, a `base_rarity`
  hint). Their `bonuses` may stay in JSON but are unused at runtime.
- Validator: allow the instance shape; register affix types in an ALLOWED list.

**Weaker:** affix values are small and common = a single affix. Net power is below
the old multi-bonus items. content-balance pass to confirm.

gdscript-reviewer on the save migration + recompute. Smoke. Commit in sub-steps
(2a affix pool + model + validator; 2b instance storage + migration + recompute;
2c drops + panel display).

---

## PHASE 3 — Scrap currency + Blacksmith dismantle/reforge

- **New permanent currency `scrap`** in MetaProgress (mirror `caps`: field,
  add/spend, `scrap_changed`, back-compat save default 0). Earned ONLY by
  dismantling equipment at the blacksmith.
- **Blacksmith facility** (home base): a panel/section listing owned equipment
  (stash + currently-unequipped). Two actions per item:
  - **Dismantle** → remove the item, gain scrap by rarity (common 5 / uncommon 12 /
    rare 25; cursed +5).
  - **Reforge** → spend scrap (cost by rarity, e.g. 15/30/50) → `AffixPool.reroll_one`
    on that item's affixes (one random non-curse affix replaced).
- Wire into the existing base UI (the blacksmith is currently a safe-cell upgrade;
  add the dismantle/reforge station as a new home-base panel/section). UI —
  owner-verified.
- Smoke. Commit.

---

## PHASE 4 — Caps equipment shop (home base)

- A new home-base shop section selling EQUIPMENT for **Caps**. Generates N items
  (instances with rolled affixes) at varied rarities; prices in caps by rarity
  (e.g. common 60 / uncommon 140 / rare 280). Buying adds the instance to the
  stash (or backpack on next run). Re-roll/refresh optional. UI — owner-verified.
- Smoke. Commit.

---

## PHASE 5 — Cursed equipment

- At high ascension (≥3), equipment drops have a chance to be **cursed**: 1 curse
  affix + up to 3 positive affixes (`AffixPool.roll(rarity, cursed=true)` with an
  extra positive slot). Mark `cursed:true`; display with a distinct (red) treatment.
- Drop logic gated by `RunManager.ascension >= 3`. Smoke. Commit.

---

## PHASE 6 — Starter deck editor + card unlock (Core)

- **Card unlock with Core:** unlockable cards = those NOT in the base starter pool
  / hero starter deck. Unlocking costs Core (e.g. 40 each), stored in
  MetaProgress (reuse/extend `unlocked_cards`). 
- **Starter deck editor** (home base, pre-run): adjust the active hero's starting
  deck by swapping at most **2** cards, choosing replacements from UNLOCKED cards.
  Store the per-hero starter override in MetaProgress; `RunManager.start_new_run`
  applies it (≤2 swaps from the hero's default `starter_deck`). UI — owner-verified.
- Smoke. Commit.

---

## Gates
`bash scripts/smoke_test.sh` after each phase/sub-step. content-balance on new
content; gdscript-reviewer on save-format / currency / recompute changes. Commit
per step. **No push.** Morning report: phases done / deferred / owner-verify list /
Codex art TODOs.

## Out of scope
Art; pushing; reworking the extraction backpack; multiplayer of affixes onto
relics (relics stay fixed-effect).
