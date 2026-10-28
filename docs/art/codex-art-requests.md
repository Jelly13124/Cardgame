# Art requests for Codex

Assets the game needs that do not exist yet. Collected during the phase 5–7
refactor (2026-10-28). Each entry names the file to create, the size and the
look to match. The game already falls back gracefully when a file is missing
(text badge, no event picture), so none of these block play.

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

## Event illustrations

Folder: `run_system/assets/images/events/`. Size 1408×768 RGB PNG, the event
modal crops it to cover. Reference: `buried_cache.png`. Without art the event
modal shows no picture.

| File | Event title (`content/events/<id>.json`) |
|---|---|
| `adrenaline_shot.png` | Pre-War Auto-Injector |
| `deserter_charm.png` | The Deserter's Charm |
| `torn_coin_pouch.png` | Torn Coin Pouch |

## Checked and complete

`python tools/check_missing_art.py` reports no missing card, relic,
equipment or enemy art (0 hard-missing, 0 cards on placeholder art).
