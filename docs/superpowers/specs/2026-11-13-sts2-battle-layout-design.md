# STS2 Battle Layout, Five-Card Draw, Text Title Menu

On 2026-11-13 the user asked for three things on the node map branch: the five-card draw
(built on `feat/draw-five`, not yet merged here); the title menu without button boxes, as
Codex had drawn it; and the battle layout taken straight from STS2's reverse-engineered
code. That means the hand sits partly below the screen and rises on hover, and the hero,
enemies and cards use STS2's positions and sizes. The user approved this design in chat
the same day. Cards themselves (frame, face, art) do not change.

## Sources

STS2 v0.107.1 evidence in `C:\Users\Jerry\Desktop\STS2-UI-Reference\v0.107.1-59260271\`
(decompiled C#, scenes), read only:

- `HandPosHelper.cs`: per hand size (1–10), each card's position relative to the hand
  anchor and its angle; base scale 0.8, further multiplied at 8/9/10 cards (0.95/0.9/0.85).
- `NPlayerHand.RefreshLayout`: the hovered card snaps to angle 0 and scale 1 with its centre
  at `-height/2 + 2`, so the whole card shows; the others move away by
  `lerp(100, 0, min(1, |d|/4))`.
- `NHandCardHolder`: holders ease toward their targets (move 7/s, rotate 10/s, scale 8/s,
  exponential).
- `player_hand.tscn`: the hand anchor is the screen's bottom centre.
- `NCombatRoom.PositionEnemies` / `PositionPlayersAndPets`: each side lays out within its own
  half of the 1920×1080 scene (960 px from the centre). Creatures are centred in that half
  but at least 150 px from the centre, with 70 px between enemies (shrinking when crowded,
  and every other enemy raised 40–60 px when very crowded). Feet sit at the centre + 200
  (y 740). `AdjustCreatureScaleForAspectRatio` scales both sides down when the right edge
  would cross the screen.
- `NMainMenuTextButton`: main menu entries are text buttons with no box.

## Design

1. **Five cards.** Merge `feat/draw-five` (39034a9) into `feat/node-map`.
2. **Title menu.** The four main menu entries (New Game, Continue, Settings, Quit) become
   text-only buttons: no box, a cream label with a dark outline, and a gold, slightly larger
   label on hover or focus. Their order and actions do not change.
3. **Hand.** A `Hand` subclass, `ui/battle/sts2_hand.gd`, replaces the fan curve with
   STS2's table:
   - Positions are scaled by our card width over STS2's (`208 / 300`), so the proportions
     match on our smaller card. The anchor is the screen's bottom centre.
   - Rest scale is 0.8 (with STS2's 8/9/10-card factors); angles come from the table.
   - The hovered card goes to scale 1 and angle 0 and shows fully (its bottom 2 px above the
     screen edge); neighbours make way.
   - Cards ease with STS2's rates.
   - `play_card.gd` stops its own hover lift and scale for hand cards; the hand drives them.
     Targeting, dragging and playing keep their behaviour.
4. **Creatures.** `battle_screen.gd` places the hero and enemies with STS2's algorithm,
   using each view's displayed sprite size as its bounds:
   - the hero is centred in the left half, feet at y 740;
   - enemies are centred in the right half (70 px gaps, at least 150 px from the centre),
     feet at y 740, re-laid out when one spawns or dies;
   - both sides scale down if the rightmost enemy would leave the screen.
   Display sizes stay 256 (hero, normal), 320 (elite) and 384 (boss): these sit inside
   STS2's own creature bounds (about 244–457 wide, 246–527 tall) and match our art's
   resolution. Bigger heroes need bigger art, which goes in a later brief.
5. Health bars, intents and statuses keep following their creature.

## Tests

- **Hand:** for 3, 5 and 10 cards, each card's target position, angle and scale equal
  STS2's table times `208/300` (scale times 0.8). Hovering card 2 of 5 sets it to scale 1,
  angle 0 and centre y `-286/2 + 2`, and shifts its neighbours by STS2's formula.
- **Creatures:** with 1, 2 and 3 enemies, feet are at y 740, the hero is centred in the left
  half, enemies are centred in the right half with 70 px gaps, and no enemy crosses the
  screen edge.
- **Menu:** the main menu buttons draw no box (empty stylebox) and keep their order and
  actions.
- **Five cards:** the merged branch's existing turn-draw test.
- Full suite green; windowed screenshots of the menu and a 3-enemy battle with a five-card
  hand.

## Non-goals

No card face changes, no new art, no change to targeting or play rules.
