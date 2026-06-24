# Sound effects — drop-in guide

The game plays SFX **by filename** (`AudioManager.play_sfx("<stem>")` loads `<stem>.wav`).
To change one, drop a `.wav` with the matching stem here — no code change.

## Source: Kenney CC0 audio packs

All shipped SFX are sourced from **Kenney** (<https://kenney.nl>) audio packs and are
**CC0 (Creative Commons Zero / public domain)** — free for personal, educational, and
commercial use. Crediting Kenney is appreciated but **not mandatory**. Packs used:

- **Interface Sounds** — UI + card/turn cues
- **Impact Sounds** — hits / blocks / deaths
- **RPG Audio** — coins, slashes, mechanical (Bill's reload)

Each pack's `License.txt` (CC0) is kept with the originals; the chosen `.ogg`s were
converted to mono 44.1 kHz `.wav` via ffmpeg. To re-pick, swap the `.wav` in place.

## Stem → Kenney source map

| Stem | Kenney source | | Stem | Kenney source |
|---|---|---|---|---|
| `ui_click` | click_001 | | `crit` | impactBell_heavy |
| `ui_back` | back_001 | | `block_gain` | impactPlate_medium |
| `ui_hover` | tick_001 | | `bleed` | impactSoft_medium |
| `error` | error_004 | | `heal` | glass_001 |
| `turn_start` | confirmation_001 | | `gold` | handleCoins |
| `card_draw` | scratch_001 | | `gem` | glass_003 |
| `card_play` | drop_001 | | `reward` | maximize_001 |
| `card_play_attack` | drawKnife1 | | `level_up` | maximize_006 |
| `card_play_skill` | cloth2 | | `reload` | metalClick |
| `card_play_power` | confirmation_004 | | `victory` | maximize_009 |
| `attack_hit` | impactMetal_medium | | `defeat` | minimize_001 |
| `attack_slash` | knifeSlice | | `enemy_attack` | impactPunch_heavy |
| `enemy_death` | impactMetal_heavy | | | |

> `victory` / `defeat` use directional UI sweeps (up / down) — functional but could be
> upgraded to proper win/lose jingles later (owner taste pick).

## Legacy fallback
The old procedural SFX synth lives in `scripts/gen_audio.py`; run `python scripts/gen_audio.py --sfx`
to regenerate them (overwrites these Kenney `.wav`s). Not used by default.
