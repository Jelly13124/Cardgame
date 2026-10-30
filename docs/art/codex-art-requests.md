# Art requests for Codex

Assets the game needs that do not exist yet. Collected during the phase 5–7
refactor (2026-10-28). Each entry names the file to create, the size and the
look to match. The game already falls back gracefully when a file is missing
(text badge, old or no picture), so none of these block play.

Match the existing wasteland comic style: inked outlines, warm rust and teal
palette, flat cel shading. Use an existing file in the same folder as the
reference for line weight and palette.

## Status icons

Folder: `battle_scene/assets/images/ui/status/`. Size 64×64 RGBA PNG,
transparent background, readable at 30×30 (the battle badge size). Reference:
`burn.png`, `bullet.png`. Without an icon the badge shows the status label
as coloured text.

| File | Status | Meaning (from `content/statuses/`) |
|---|---|---|
| `deadeye.png` | Deadeye | The next Attack is guaranteed to crit |
| `loaded.png` | Loaded | The next damaging Attack gains the stacks as extra damage |
| `overload_protocol.png` | Overload Protocol | Overloads can crit |
| `reactive_plating.png` | Reactive Plating | When a card grants Block, gain that many Thorns |

## House style (applies to everything below)

One style for the whole game: the wasteland comic look of the cards, enemies and
`shop/shop_interior_bg.png` — inked outlines, warm rust and teal palette, flat cel
shading, a single warm light source. The current event illustrations are soft painted
images with no outlines; they do not match and are all redrawn below.

Deliver every image at the size it is shown. The game never scales art up; art drawn
smaller than its slot looks blurry (this is why the current 1408×768 event art looked
soft when it was stretched over 1920×1080).

## Event illustrations (new layout, redraw all)

Phase 9a moves events to a left-picture, right-text layout like STS2: the illustration
sits in a 1024×768 frame on the left; the text and options are on the right.

Folder: `run_system/assets/images/events/`. Size **1024×768** RGB PNG, shown at 1:1.
Keep the subject in the middle 900×700; the frame border covers the edges. One clear
focal subject, readable at a glance, no text in the image. Until a redraw lands, the old
1408×768 file is shown centre-cropped.

| File | Event | Status |
|---|---|---|
| `adrenaline_shot.png` | Pre-War Auto-Injector | missing |
| `deserter_charm.png` | The Deserter's Charm | missing |
| `torn_coin_pouch.png` | Torn Coin Pouch | missing |
| `buried_cache.png` | Buried Cache | redraw (off-style, wrong size) |
| `caravan_checkpoint.png` | The Caravan Checkpoint | redraw |
| `collapsed_overpass.png` | The Collapsed Overpass | redraw |
| `cursed_safe.png` | Humming Strongbox (closed) | redraw |
| `fortune_shrine.png` | The Fortune Shrine | redraw |
| `hooded_stranger.png` | The Hooded Stranger | redraw |
| `mutant_bazaar.png` | The Mutant Bazaar | redraw |
| `rad_storm.png` | Rad Storm (green sky, glowing dust wall) | redraw |
| `stranded_trader.png` | Stranded Trader | redraw |
| `rad_storm_bunker.png` | Rad Storm, second page: inside a bunker, a glowing core in a dark concrete room, dust in the hatch light | new |
| `cursed_safe_open.png` | Humming Strongbox, second page: the box open, coins and a pulsing green core inside | new |

The event's story text is in `assets/translations/ui_events.csv`
(`EVENT_<ID>_DESC` / `_PAGE_INITIAL`); read it for the scene.

## Event backdrops (new)

Folder: `run_system/assets/images/events/backdrops/`. Size **1920×1080** RGB PNG. Full
screen behind the frame and the text, under a 55% black scrim, so keep it low in
contrast and detail — a mood, not a scene; nothing important in x 1144–1840 (text
column). Without it the room uses a flat dark fill.

| File | Act |
|---|---|
| `act_1.png` | Act 1 — outer wastes, dusty orange dusk |
| `act_2.png` | Act 2 — ruined city, rust and grey |
| `act_3.png` | Act 3 — irradiated zone, sickly green glow |

## Event option icons (new)

Folder: `ui/events/icons/`. Size **32×32** RGBA PNG, transparent background, light
strokes readable on a dark button. The button falls back to a text suffix when an icon
is missing.

| File | Meaning |
|---|---|
| `lock.png` | Option locked by an attribute (padlock) |
| `luck.png` | Luck check (die) |
| `lethal.png` | This option can kill you (skull) |

## Shop (redo, used by phase 9b)

The user finds the shop background ugly. Diagnosis: one flat picture with a large
empty floor in the middle, nothing layered, the keeper pasted on as a separate card.
STS2 builds its merchant room from layers with the merchant as its own character. Split
it the same way; all three are shown at 1:1 in 1920×1080.

Folder: `run_system/assets/images/shop/`.

| File | Size | Content |
|---|---|---|
| `shop_interior_bg.png` | 1920×1080 RGB | Back wall and room only, no counter: shelves of junk, a doorway to the wastes on the left, warm hanging lamp. Redraw. |
| `shop_counter_fg.png` | 1920×1080 RGBA, transparent above the counter | The counter across the lower third and foreground clutter at the edges; it overlaps the keeper's waist. New. |
| `shopkeeper.png` | 768×1024 RGBA, transparent | The keeper from the waist up, standing behind the counter line, same light as the room. Redraw. |

Item cards and prices are drawn by the game on top; leave the middle 1100×500 above
the counter calm.

## Checked and complete

`python tools/check_missing_art.py` reports no missing card, relic,
equipment or enemy art (0 hard-missing, 0 cards on placeholder art).
