# Sound effects — drop-in guide

The game plays SFX **by filename** (`AudioManager.play_sfx("<stem>")` loads `<stem>.wav`).
To change one, drop a `.wav` with the matching stem here — no code change.

## Source: procedural (`gen_audio.py`)

The shipped SFX are synthesized by `scripts/gen_audio.py` (numpy, wasteland-retro palette)
and written at **reduced gain** (0.5). The Kenney CC0 set trialled on 2026-06-24 was
**reverted** — the owner preferred the procedural style and the Kenney picks were too
loud / harsh. Regenerate with:

```bash
python scripts/gen_audio.py --sfx
```

To swap in real samples later, drop `.wav`s with the stems below (they override the
procedural ones — no code change).

## Stems
`ui_click` · `ui_back` · `ui_hover` · `error` · `turn_start` · `card_draw` · `card_play` ·
`card_play_attack` · `card_play_skill` · `card_play_power` · `attack_hit` · `attack_slash` ·
`enemy_attack` · `enemy_death` · `crit` · `block_gain` · `bleed` · `heal` · `gold` · `gem` ·
`reward` · `level_up` · `reload` · `victory` · `defeat`
