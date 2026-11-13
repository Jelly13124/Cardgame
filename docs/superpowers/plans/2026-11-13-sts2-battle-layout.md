# STS2 Battle Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge the five-card draw, make the title menu text-only, and lay out the hand and the creatures with STS2's numbers.

**Architecture:** `ui/battle/sts2_hand.gd` subclasses card-framework `Hand` and owns hand targets, including hover. `battle_screen.gd` owns creature placement through one function, `layout_creatures()`. `main_menu.gd` gets one shared text-button style.

**Tech Stack:** Godot 4.6.3, GDScript, `tools/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-13-sts2-battle-layout-design.md`

## Global Constraints

- Worktree `C:\Users\Jerry\Desktop\Cardgame-nodemap`, branch `feat/node-map`. Never touch the main checkout or Codex's worktrees. No merge to main, no push.
- Tests run through `tools/run_tests.ps1` with `GODOT_BIN` set and `-TimeoutSeconds 120`. Edit `.gd` files with Python or the Edit tool. Commit as `Jelly13124 <ruizheyuan3487@gmail.com>` with a Conventional subject; the body ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- STS2 values (copied verbatim):
  - the hand table and angles from `HandPosHelper.cs`;
  - base scale 0.8, and ×0.95/0.9/0.85 at 8/9/10 cards;
  - hover: scale 1, angle 0, centre y `-h/2+2`, neighbour push `lerp(100, 0, min(1, |d|/4))`;
  - easing rates: move 7, rotate 10, scale 8;
  - creatures: half-width 960, minimum 150 px from centre, enemy gap 70, feet at centre +200.
- Card width ratio: `208/300`.

## Review Focus

1. Dragging or targeting a hovered card must not snap it back mid-drag. Task 3 test `held card keeps its drag position`.
2. Cards added or removed while one is hovered must relayout without a stale hover offset. Task 3 test `hover clears when the card leaves`.
3. A spawned or killed enemy re-lays out the field and keeps intents above heads. Task 4 test `spawn relays out`.
4. A 4-enemy boss fight stays on screen. Task 4 test `four enemies fit`.

---

### Task 1: Merge the five-card draw
- [ ] Run `git merge --no-ff feat/draw-five`, then run `-Only "combat_simulation*"`. Expected: `[OK]`.

### Task 2: Text-only title menu
**Files:** `ui/menus/main_menu.gd` (`_start_menu_button`), `tests/main_menu_text_buttons_test.gd` (new).
- [ ] Write a failing test: instantiate the menu and find the four start buttons. Each has an empty `normal` stylebox (`StyleBoxEmpty`) and a font colour override, and the order is New Game, Continue, Settings, Quit.
- [ ] Run it. Expected: FAIL.
- [ ] Implement it in `_start_menu_button`: empty styleboxes for normal, hover, pressed, focus and disabled; label 30 px in cream `#efe2c4` with a dark outline of size 8; hover and focus turn the label gold `#f2c56a`; hovering scales the label to 1.08 over 0.05 s.
- [ ] Run it. Expected: `[OK]`. Commit `feat(menu): text-only title menu like STS2`.

### Task 3: STS2 hand
**Files:** `ui/battle/sts2_hand.gd` (new, `extends Hand`); `ui/battle/battle_screen.tscn` (Hand node uses the new script, anchored at the bottom centre with zero size); `ui/battle/play_card.gd` (hand cards skip the framework hover lift and scale and notify the hand); `tests/sts2_hand_layout_test.gd` (new).
**Interfaces:**
- `static func slot(hand_size: int, index: int) -> Dictionary` returns `{position: Vector2, angle_deg: float, scale: float}` from STS2's tables, with positions multiplied by `208/300` and scale = 0.8 × factor.
- `func set_hovered(card: Node) -> void` and `func clear_hovered(card: Node) -> void` recompute the targets.
- [ ] Write a failing test:
  - `slot(5, 0)` = position (−340, 10)×208/300, angle −8, scale 0.8; `slot(3, 1)` = (0, −59)×208/300, angle 0; `slot(10, 9)` scale 0.68.
  - With a battle at 5 cards, hovering card 2 gives it target scale 1, rotation 0 and centre y −286/2+2 relative to the anchor, and card 1's x shift equals `lerp(100, 0, 1/4)`×208/300.
  - `held card keeps its drag position`: a card in the HOLDING state is not given a target by relayout.
  - `hover clears when the card leaves`: removing the hovered card restores table targets for the rest.
- [ ] Run it. Expected: FAIL.
- [ ] Implement it. Override `_update_target_positions` to set each card's target from `slot()`, plus the hover override. Ease toward the targets with STS2's rates in `_process`, skipping held and moving cards. Keep the drop-zone partitions computed from the new rects.
- [ ] Run it, then `-Only "battle*"`, `-Only "card*"` and `-Only "combat*"`. Expected: `[OK]`. Commit `feat(battle): STS2 hand layout and hover`.

### Task 4: STS2 creature placement
**Files:** `ui/battle/battle_screen.gd` (new `layout_creatures()`, called after setup, after `spawn_enemy_view`, and after an enemy view leaves); `ui/battle/battle_screen.tscn` (the Player and EnemyContainer positions come from code); `tests/sts2_creature_layout_test.gd` (new).
**Interfaces:** `func layout_creatures() -> void`. Bounds come from each view's display width: `enemy_view._display_size.x`, and the player's `TARGET_DISPLAY_HEIGHT` square.
- [ ] Write a failing test with encounters of 1, 2 and 3 enemies:
  - the player's global feet are at y 740 and x = 960 − max((960 − w)/2, 150) − w/2;
  - each enemy's feet are at y 740;
  - the enemies' centres follow STS2's `PositionEnemies` with gap 70 from x 960 + max((960 − total)/2, 150);
  - `four enemies fit`: with 4 enemies, every right edge is ≤ 1920;
  - `spawn relays out`: `spawn_enemy_view` triggers the layout.
- [ ] Run it. Expected: FAIL.
- [ ] Implement it, porting `PositionEnemies` (including the crowded gap and the alternating raise) and the single-player branch of `PositionPlayersAndPets`. Then apply `AdjustCreatureScaleForAspectRatio` (scale both sides by `1920/(maxRight+15)` when needed).
- [ ] Run it, then the battle tests. Expected: `[OK]`. Commit `feat(battle): STS2 creature placement`.

### Task 5: Verify
- [ ] Run the full suite. Expected: exit 0.
- [ ] Take windowed screenshots: the menu, and a 3-enemy battle with a 5-card hand (rest, and with card 3 hovered via `set_hovered`). Compare them with the spec.
- [ ] Run a sonnet whole-branch review, apply its fixes test-first, then open a playtest.
