# Music tracks — drop-in guide

The game plays BGM **by filename** (no registry). To replace a track, just drop an
`.ogg` with the matching name here — it's picked up automatically, no code change.
Looping is forced in code, so the file does **not** need baked loop points.

| File | Plays during | Set by |
|---|---|---|
| `menu.ogg` | Title / main menu | `main_menu.gd` |
| `home.ogg` | Home base (between runs) | `home_base_scene.gd` |
| `map.ogg` | The run map | `map_scene.gd` |
| `battle.ogg` | Normal + elite fights | `battle_scene.gd` |
| `boss.ogg` | Boss fights | `battle_scene.gd` (when the node is a boss) |

## Format
- **OGG Vorbis**, stereo, 44.1 kHz. Any reasonable length — it loops seamlessly in
  code, so a 1–3 min loop is plenty.
- Aim for consistent loudness across the 5 tracks (roughly -16 LUFS / peaks below
  -1 dBFS) so one isn't jarringly louder than another. Player volume is separate
  (Settings → Music slider) and is applied on top.
- Tracks **fade in** when they start (~1s, `AudioManager.play_music`), and a track
  change always happens behind the scene's fade-to-black, so no hard cut is audible
  — you don't need fade-in/out baked into the file.

## Licensing
Only drop in music you have the right to ship: **CC0 / public domain**, a license
that permits commercial game use (credit as required), or your own. Note the source
+ license here when you add a track.

| Track | Source | License |
|---|---|---|
| (fill in when you replace a track) | | |
