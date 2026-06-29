# Curse Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an StS2-style unplayable **Curse** card type with 5 curses, applied to the player by enemies (temporary), events (permanent), and cards.

**Architecture:** Data-driven — curses are card JSON with `type:"curse"` + `unplayable` + an optional `end_turn_in_hand` effect block. The combat play-gate blocks unplayable cards; end-of-round scans the hand for curse penalties. New sources reuse existing add-card plumbing where possible; each new type/action/effect is registered in BOTH its handler AND the matching `data_validator.ALLOWED_*` list (the validator IS the schema). Curses are excluded from every normal card pool.

**Tech Stack:** Godot 4.6 / GDScript; JSON content; `data_validator.gd` schema; verification via the headless smoke gate (`scripts/smoke_test.sh`) + godot-mcp-runtime runtime checks (no pytest in this project).

**Verification model (read this):** This repo has no unit tests. Each task's "test" is:
1. **Smoke gate** — `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → expect `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
2. **MCP runtime** — `run_project(background:true)` → `run_script` to set up state → `take_screenshot` / inspect return values. Strip McpBridge at the end.
Commit after each green task.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `battle_scene/card_info/player/{radiation_dust,leaking_wealth,rust,cowardice,panic}.json` | the 5 curse cards | create |
| `battle_scene/data_validator.gd` | schema | add `curse` type, `unplayable`/`end_turn_in_hand` card keys, `lose_gold` + `add_curse_to_deck` effects, `add_curse` enemy action, `add_curse` event effect |
| `battle_scene/battle_scene.gd` | play gate + end-round | unplayable return-to-hand; end-of-round curse scan |
| `battle_scene/combat_engine.gd` | effects | `lose_gold`, `add_curse_to_deck`, apply `end_turn_in_hand` |
| `battle_scene/deck_manager.gd` | piles | `add_card_to_draw` |
| `battle_scene/enemy_ai.gd` | enemy actions | `add_curse` case |
| `run_system/core/run_manager.gd` | event effects | `add_curse` event case |
| `run_system/data/enemies/hex_drone.json` + encounter pool | curse enemy | create + wire |
| `run_system/data/events/<curse_event>.json` + event registry | curse event | create + wire |
| card frame color (play_card / card factory) | curse visual | add curse color |
| market `_list_lockable_cards` + dir-scan pools | exclusion | skip `type=="curse"` |
| `assets/translations/*.csv` | i18n | curse names/desc + toast + enemy/event text |
| `docs/{PRD,PROJECT_STRUCTURE}.md`, catalog | docs | update |

---

## Task 1: Curse card type + the 5 curse JSONs + schema + i18n + frame color

**Files:**
- Create: `battle_scene/card_info/player/{radiation_dust,leaking_wealth,rust,cowardice,panic}.json`
- Modify: `battle_scene/data_validator.gd` (ALLOWED_CARD_TYPES + curse-key validation)
- Modify: the card-type→frame-color map (find in `battle_scene/play_card.gd` or the card factory)
- Modify: `assets/translations/` (a card CSV)

- [ ] **Step 1: Add `curse` to the allowed card types**

In `data_validator.gd`, `const ALLOWED_CARD_TYPES = ["attack", "skill", "ability"]` → add `"curse"`.

- [ ] **Step 2: Validate the new optional curse keys**

In `validate_card` (where `data["type"]` is checked, ~L323), after the type check add: if `type=="curse"`, require `data.get("unplayable", false) == true` (curses must be unplayable); if `data.has("end_turn_in_hand")`, validate each entry is a dict whose `type` is in `ALLOWED_EFFECT_TYPES` (reuse the existing effect-array validator).

- [ ] **Step 3: Author the 5 curse JSONs** (exact content)

`radiation_dust.json`:
```json
{ "name": "radiation_dust", "title": "Radiation Dust", "rarity": "curse", "type": "curse", "cost": 0,
  "description": "Unplayable.", "front_image": "player/curse_placeholder.png", "side": "player",
  "unplayable": true, "effects": [] }
```
`leaking_wealth.json`:
```json
{ "name": "leaking_wealth", "title": "Leaking Wealth", "rarity": "curse", "type": "curse", "cost": 0,
  "description": "Unplayable. At the end of your turn while in hand, lose 5 Gold.",
  "front_image": "player/curse_placeholder.png", "side": "player", "unplayable": true,
  "effects": [], "end_turn_in_hand": [ { "type": "lose_gold", "amount": 5 } ] }
```
`rust.json`:
```json
{ "name": "rust", "title": "Rust", "rarity": "curse", "type": "curse", "cost": 0,
  "description": "Unplayable. At the end of your turn while in hand, lose 2 HP.",
  "front_image": "player/curse_placeholder.png", "side": "player", "unplayable": true,
  "effects": [], "end_turn_in_hand": [ { "type": "lose_hp", "amount": 2 } ] }
```
`cowardice.json`:
```json
{ "name": "cowardice", "title": "Cowardice", "rarity": "curse", "type": "curse", "cost": 0,
  "description": "Unplayable. At the end of your turn while in hand, gain 1 Weak.",
  "front_image": "player/curse_placeholder.png", "side": "player", "unplayable": true,
  "effects": [], "end_turn_in_hand": [ { "type": "apply_status_self", "status": "weak", "amount": 1 } ] }
```
`panic.json`:
```json
{ "name": "panic", "title": "Panic", "rarity": "curse", "type": "curse", "cost": 0,
  "description": "Unplayable. At the end of your turn while in hand, gain 1 Frail.",
  "front_image": "player/curse_placeholder.png", "side": "player", "unplayable": true,
  "effects": [], "end_turn_in_hand": [ { "type": "apply_status_self", "status": "frail", "amount": 1 } ] }
```
> If `rarity` must be in an allowed set, add `"curse"` to the rarity list too (check `data_validator`). If `front_image` existence is asserted (not warn-only), ship a `player/curse_placeholder.png` (a dark square) so the card renders; real art is a Codex deliverable (write `asset-spec-curse-cards.md`).

- [ ] **Step 4: Curse frame color**

Find the card-type→frame color (grep `"ability"` / `"attack"` in `battle_scene/play_card.gd` + the card factory). Add `"curse"` → a dark purple (e.g. `Color(0.36, 0.20, 0.45)`).

- [ ] **Step 5: i18n** — add to a card CSV: `CARD_radiation_dust_TITLE/DESC` … for all 5, and `UI_BATTLE_CURSE_UNPLAYABLE` ("诅咒牌无法打出"). Then `--import` to regenerate `.translation`.

- [ ] **Step 6: Verify (smoke)** — `bash scripts/smoke_test.sh` → `[OK] DataValidator` (the 5 curses validate). Fix any schema error.

- [ ] **Step 7: Commit** — `git add` the 5 JSONs + data_validator + frame color + CSV + .translation; `git commit -m "feat(cards): curse card type + 5 curses (schema, frame, i18n)"`.

---

## Task 2: Unplayable play-gate

**Files:** Modify `battle_scene/battle_scene.gd` (`play_spell`, ~L941 after `var type = ...`)

- [ ] **Step 1: Block unplayable cards** — right after `var type = card.card_info.get("type", "skill").to_lower()` in `play_spell`, add (mirrors the out-of-ammo return-to-hand path):
```gdscript
if type == "curse" or bool(card.card_info.get("unplayable", false)):
	AudioManager.play_sfx("error")
	show_notification(tr("UI_BATTLE_CURSE_UNPLAYABLE"), Color(0.72, 0.5, 0.85))
	hand.add_card(card)
	card.remove_meta("_in_play")
	return
```

- [ ] **Step 2: Verify (MCP)** — `run_project(background:true)`; `run_script`: start a run, enter a battle, `deck_manager.add_card_to_hand("rust")`; then simulate clicking/playing it (or call `play_spell` on it). Confirm it returns to hand + the toast fires (screenshot / `get_debug_output`).

- [ ] **Step 3: Commit** — `git commit -m "feat(combat): curses are unplayable (return to hand + toast)"`.

---

## Task 3: `lose_gold` effect + end-of-turn-in-hand penalties

**Files:** Modify `combat_engine.gd` (`_apply_effect`), `data_validator.gd` (ALLOWED_EFFECT_TYPES), `battle_scene.gd` (`_on_end_round_button_pressed`)

- [ ] **Step 1: `lose_gold` effect** — in `combat_engine._apply_effect`'s `match`, add:
```gdscript
"lose_gold":
	RunManager.spend_gold(amount)
	main.show_notification(tr("UI_COMBAT_LOSE_GOLD").format({"n": amount}), Color(0.85, 0.7, 0.3))
```
Add `"lose_gold"` to `ALLOWED_EFFECT_TYPES` in `data_validator.gd`. Add `UI_COMBAT_LOSE_GOLD` i18n ("失去 {n} 金币").

- [ ] **Step 2: End-of-round curse scan** — in `battle_scene._on_end_round_button_pressed`, BEFORE the hand is discarded, add a scan:
```gdscript
for c in hand.get_cards():
	var et: Array = c.card_info.get("end_turn_in_hand", [])
	for eff in et:
		if typeof(eff) == TYPE_DICTIONARY:
			combat_engine._apply_effect(eff, player, player)
```
(Use the actual hand-cards accessor + the player node refs as they exist in that function; `_apply_effect` already routes self-effects to the player.)

- [ ] **Step 3: Verify (MCP)** — battle; `add_card_to_hand("rust")` + `add_card_to_hand("leaking_wealth")` + `add_card_to_hand("cowardice")`; record HP/gold/statuses; end the turn via the end-round path; assert HP −2, gold −5, Weak +1; the curses then discard. Check via `run_script` return values.

- [ ] **Step 4: Commit** — `git commit -m "feat(combat): lose_gold effect + end-of-turn curse penalties"`.

---

## Task 4: Enemy `add_curse` action (temporary) + `hex_drone` enemy + encounter wiring

**Files:** Modify `deck_manager.gd`, `enemy_ai.gd`, `data_validator.gd`; create `run_system/data/enemies/hex_drone.json` + encounter-pool entry + i18n

- [ ] **Step 1: `add_card_to_draw`** — in `deck_manager.gd`, add a method that creates a card by id into the DRAW pile (not hand) and shuffles it in (mirror `add_card_to_hand` but target the draw pile / `RunManager.deck` per how the draw pile is modeled here).

- [ ] **Step 2: Enemy `add_curse` action** — in `enemy_ai._execute_action`'s `match action_type:`, add:
```gdscript
"add_curse":
	var curse_id: String = str(action.get("curse", "radiation_dust"))
	var n: int = int(action.get("amount", 1))
	for _i in range(n):
		main.deck_manager.add_card_to_draw(curse_id)
	main.show_notification(tr("UI_BATTLE_ENEMY_CURSE"), Color(0.72, 0.5, 0.85))
```
Add `"add_curse"` to `ALLOWED_ENEMY_ACTION_TYPES`. Add `UI_BATTLE_ENEMY_CURSE` i18n.

- [ ] **Step 3: `hex_drone` enemy JSON** — reuse an existing sprite_id (pick a small caster/critter already in `battle_scene/assets/images/enemies/`); an action pattern that telegraphs then `add_curse` (curse "rust" or "radiation_dust") interleaved with a weak attack. Match the enemy schema (`id,name,sprite_id,max_health,action_pattern`). i18n `ENEMY_hex_drone_NAME`.

- [ ] **Step 4: Encounter wiring** — add `hex_drone` to the act-1 normal encounter pool / roster (per CLAUDE.md rule 3 — find the encounter-pool list in `run_manager`/encounter data).

- [ ] **Step 5: content-balance** — run the `content-balance` subagent on `hex_drone` (a curse-spammer must not be oppressive at A0).

- [ ] **Step 6: Verify (smoke + MCP)** — smoke validates the enemy; MCP: force a `hex_drone` fight, let it act, assert a curse appears in the draw pile; end combat, start the next — assert the curse is gone (temporary).

- [ ] **Step 7: Commit** — `git commit -m "feat(enemy): add_curse action + hex_drone curse enemy"`.

---

## Task 5: Event `add_curse` (permanent) + curse event + `add_curse_to_deck` card effect

**Files:** Modify `run_manager.gd` (event effect dispatch ~L1437), `combat_engine.gd`, `data_validator.gd`; create a curse event JSON + i18n

- [ ] **Step 1: Event `add_curse`** — in the event-effect dispatch (`run_manager.gd` ~L1442 `match etype`/if-chain), add a case: `add_curse` → `add_card_to_deck(str(effect.get("curse","radiation_dust")))` (the permanent run-deck add). Add `"add_curse"` to `ALLOWED_EVENT_EFFECT_TYPES`. Confirm `add_card_to_deck` exists (else use the existing deck-append API).

- [ ] **Step 2: Card effect `add_curse_to_deck`** — in `combat_engine._apply_effect`, add `add_curse_to_deck` → `RunManager.add_card_to_deck(str(effect.get("card","radiation_dust")))`. Add to `ALLOWED_EFFECT_TYPES`. (Wired + validated for future cards; no shipped player card uses it in v1.)

- [ ] **Step 3: Curse event JSON** — a `?`-node event that grants a reward + a permanent curse (e.g. gain_gold + add_curse). Match the event schema; i18n the event text.

- [ ] **Step 4: Verify (smoke + MCP)** — smoke validates the event; MCP: fire the event effect, assert the curse is now in `RunManager.player_deck` (permanent), and that the shop card-removal can remove it.

- [ ] **Step 5: Commit** — `git commit -m "feat(events): add_curse event + add_curse_to_deck card effect"`.

---

## Task 6: Pool exclusion + catalog + docs + final verification

**Files:** Modify market `_list_lockable_cards` + any dir-scan card pool; run catalog gen; update docs

- [ ] **Step 1: Exclude curses from pools** — in `market_screen._list_lockable_cards`, skip `data.get("type")=="curse"`. Audit any OTHER place that scans `card_info/player/*.json` into an offerable pool (reward/draft) and skip curses there too. (INITIAL_CARD_POOL/unlocked already exclude them since we never add curses to those.)

- [ ] **Step 2: Verify exclusion (MCP)** — open the market unlock list + a reward/draft; assert no curse appears.

- [ ] **Step 3: Catalog** — `python scripts/gen_catalog_html.py`; confirm the 5 curses appear (a "curse" group in cards.html).

- [ ] **Step 4: Docs** — PRD: a line under the content section (new curse type + sources + hex_drone). PROJECT_STRUCTURE: note `curse` card type + `add_curse` enemy/event + `lose_gold`/`add_curse_to_deck` effects.

- [ ] **Step 5: Final smoke + MCP regression** — full `bash scripts/smoke_test.sh` green; one MCP pass over the whole curse flow (unplayable, end-turn penalties, enemy temp curse, event perm curse, removal, pool exclusion).

- [ ] **Step 6: gdscript-reviewer** — run the `gdscript-reviewer` subagent on all changed `.gd` (lambda capture, falsy-zero, signal shape, validator contract, JSON wiring).

- [ ] **Step 7: Strip McpBridge** + `rm mcp_bridge.gd*`; commit `git commit -m "feat(cards): curse pool exclusion + catalog + docs [curse-cards done]"`.

---

## Self-review (spec coverage)

- Card type + unplayable + end_turn_in_hand → Task 1, 2, 3 ✓
- 5 curses (辐射尘/漏财/铁锈/怯懦/恐慌) → Task 1 ✓
- lose_gold (new) / reuse lose_hp + apply_status_self → Task 3 ✓
- Enemy temporary (draw pile) `add_curse` + hex_drone + encounter → Task 4 ✓
- Event permanent `add_curse` + `add_curse_to_deck` card effect → Task 5 ✓
- Pool exclusion + removal (shop, existing) → Task 6 + §6 ✓
- Two-place registration (handler + ALLOWED_*) → every task pairs them ✓
- Frame color + i18n + placeholder art → Task 1 ✓
- Catalog + docs + reviewer + smoke/MCP → Task 6 ✓
- Out of scope (relic/transform/blue-candle) → not in plan ✓
