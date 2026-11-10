# Codex handoff: missing and outdated art (2026-11-10)

Audit of the game at `main` 7ad21fc (route choice map). It supersedes the open items
in `docs/art/codex-art-requests.md` (2026-10-30); the house style section there still
applies. Every item below was checked against the files on disk and the code that
loads them.

## Rules for this work

- **Art only.** Create or replace the image files listed here. Do not edit `.gd`,
  `.tscn`, `.json` or translations. Items marked *needs code* are drawn now and wired
  later by Claude.
- **Style.** Use the wasteland comic house style: inked outlines, flat cel colour, a warm
  rust-and-teal palette and one warm light. References: `battle_scene/assets/images/cards/player/`,
  `run_system/assets/images/shop/shop_interior_bg.png` and the enemies under
  `battle_scene/assets/images/enemies/`. Art must be original; external reference boards
  are for study only (`docs/enemy-art-direction.md`).
- **Size.** Deliver every image at the size it is shown; the game never scales art up.
  Sizes below are exact.
- **Naming and place.** Use exactly the file name and folder given. The game picks a file
  up by name, and a missing file falls back to text or a flat fill, so nothing breaks
  while work is in progress.
- **Leave alone:** the user's uncommitted files in `docs/art/previews/` and
  `docs/superpowers/`, and all enemy sprites. The user kept the old enemy style on
  purpose; only scrap_rat, hex_drone and chrome_hound use the 2026-08 redraw.
- **Check.** `python tools/check_missing_art.py` must still report 0 missing. It does not
  cover events, status icons or backdrops, so also confirm each file below exists at its
  size.

## P0 — missing; the game shows a blank or a fallback

### Event illustrations: 3 missing
Folder `run_system/assets/images/events/`, **1024×768 RGB PNG**. The left frame of the
event room shows the image 1:1. For the scene, read `EVENT_<ID>_DESC` and
`EVENT_<ID>_PAGE_INITIAL` in `assets/translations/ui_events.csv`.

| File | Event | Now |
|---|---|---|
| `adrenaline_shot.png` | Pre-War Auto-Injector: a glowing amber auto-injector | empty black frame |
| `deserter_charm.png` | The Deserter's Charm | empty black frame |
| `torn_coin_pouch.png` | Torn Coin Pouch | empty black frame |

### Event second-page art: 2 missing
Same folder and size.

| File | Shown on |
|---|---|
| `rad_storm_bunker.png` | Rad Storm, BUNKER / DEATH_WARNING pages: inside a bunker, a glowing core in a dark concrete room, dust in the hatch light |
| `cursed_safe_open.png` | Humming Strongbox, OPEN page: the box open, coins and a pulsing green core inside |

### Event backdrops: 3 missing
Folder `run_system/assets/images/events/backdrops/` (create it), **1920×1080 RGB PNG**.
The backdrop sits behind the whole event room under a 55% black scrim. Make it a low-contrast
mood image, not a detailed scene, and keep x 1144–1840 quiet because the text column sits there.

| File | Act |
|---|---|
| `act_1.png` | outer wastes, dusty orange dusk |
| `act_2.png` | ruined city, rust and grey |
| `act_3.png` | irradiated zone, sickly green glow |

### Status icons: 4 missing
Folder `battle_scene/assets/images/ui/status/`, **64×64 RGBA PNG** with a transparent
background. Each must read clearly at 30×30. Match `burn.png` and `bullet.png`. Without
an icon, the battle badge shows coloured text instead.

| File | Status | Meaning |
|---|---|---|
| `deadeye.png` | Deadeye | the next Attack is guaranteed to crit (eye in crosshair) |
| `loaded.png` | Loaded | the next damaging Attack deals the stacks as extra damage (chambered round) |
| `overload_protocol.png` | Overload Protocol | Overloads can crit (cracked battery with a spark) |
| `reactive_plating.png` | Reactive Plating | when a card grants Block, gain that much Thorns (spiked armour plate) |

### Event option icons: 3 missing
Folder `ui/events/icons/` (create it; the code loads from this exact path), **32×32 RGBA
PNG**, transparent. Use light strokes that read on a dark button. Without an icon, the
button shows a text suffix.

| File | Meaning |
|---|---|
| `lock.png` | option locked by an attribute (padlock) |
| `luck.png` | luck check (die) |
| `lethal.png` | this option can kill you (skull) |

## P1 — present but wrong size or off-style (looks soft or out of place)

### Event illustrations: redraw 9 at 1024×768
These exist at 1408×768 in a soft painted style with no outlines. The frame crops and
scales them, so they look blurry and do not match the rest of the game. Redraw each at
**1024×768** in the house style and keep the same file name:
`buried_cache`, `caravan_checkpoint`, `collapsed_overpass`, `cursed_safe`,
`fortune_shrine`, `hooded_stranger`, `mutant_bazaar`, `rad_storm`, `stranded_trader`.

### Battle background: redraw at 1920×1080
`battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v6.png` is
1672×941 and is stretched to 1920×1080. Redraw it under the same name at **1920×1080 RGB**,
keeping the composition and mood but with more presence than the current flat, pale
version. The hero stands on the left third and up to three enemies on the right half,
all on a ground line near y 760. Keep the bottom 300 px calm, because the hand of cards
sits there.

### Route map background: redraw at 1920×1080
`run_system/assets/images/map/wasteland_route_map_sts2_bg.png` is 1672×941 and was drawn
for the old scrolling node map. The map is now one centred row of 2–3 choice cards
(about 1000×420 at the centre) under a thin floor track at y≈150. Redraw it under the
same name at **1920×1080**:

- frame the edges with wasteland detail (ruins, poles, a road vanishing into the middle);
- keep the centre calm and mid-dark so the dark cards read.

At present it is a pale parchment, and the dark cards look pasted on top of it.

## P2 — new art that needs code to use (draw now, Claude wires it)

| File | Size | Purpose |
|---|---|---|
| `run_system/assets/images/rewards/loot_bg.png` | 1920×1080 RGB | Backdrop for the combat reward screen, which is plain black now. A battlefield aftermath (smoke, scattered scrap) kept dark and calm in the centre 900×600. |
| `run_system/assets/images/ui/panels/panel_rust_9slice.png` | 96×96 RGBA, 24 px border | Shared panel skin of rust metal with an inked edge, to replace the generic dark-grey panels (reward rows, event text, route cards, character window). |
| `run_system/assets/images/ui/panels/panel_paper_9slice.png` | 96×96 RGBA, 24 px border | Worn paper or cardboard variant for text-heavy panels. |
| `run_system/assets/images/ui/panels/button_rust_{normal,hover,pressed,disabled}.png` | 192×64 RGBA, 20 px border | Matching button states. |
| `run_system/assets/images/rest/option_rest.png`, `option_upgrade.png` | 256×256 RGBA | Big option plaques for the campfire. The two options are tiny text labels now. |

Hold: `shop_counter_fg.png` from the 2026-10-30 list. The shop code does not layer a
counter yet, so do not draw it until the user asks.

## Not needed

- Cards, relics, equipment, tool icons, bounty posters, map node icons, and enemy attack
  frames are complete: `check_missing_art.py` reports 0 missing and none on placeholders.
- Route cards show enemy portraits cut from the existing `<enemy>/attack/<enemy>_attack_0.png`.
  No new portraits are needed.
- `run_system/assets/images/ui_glyphs/glyph_lock.png` is referenced only as a dead fallback.
  The lightline lock icon is used instead, so do not draw it.
