# BGM Candidates — pick tomorrow 🎵

The current tracks in `assets/audio/music/*.ogg` are **procedural-synth placeholders**
(`scripts/gen_audio.py`) — that's why they sound rough. Below is a curated shortlist
of **real royalty-free music** to replace them. The game's vibe is **wasteland +
spaghetti-western** (hero = Cowboy Bill, SteamWorld-style salvage world), so each slot
blends those.

## How to use what you pick
1. Audition the links, pick one per slot.
2. Download the file (prefer **.ogg**; if only **.mp3/.wav**, that's fine — or I can
   convert).
3. Drop it in `assets/audio/music/` with the **exact slot filename** below (e.g.
   `battle.ogg`). The `AudioManager` loads by filename — no code change needed.
4. **`shop` and `event` are NEW slots** (no track today). If you pick those, tell me
   and I'll add the small `AudioManager` wiring (play `shop.ogg` in the shop, `event.ogg`
   in the event scene).

## Licensing (all safe for a commercial Steam demo)
- **Pixabay** — free, **no attribution required**, commercial OK. Easiest to audition +
  download. (Primary source below.)
- **OpenGameArt CC0** — public domain, no attribution.
- **Uppbeat / Silverman Sound** — free with their license (some need a credit line — check
  the track page).

---

## Per-slot picks

### `menu.ogg` — Title screen (atmospheric, evocative wasteland intro)
- 🔎 Pixabay: [post-apocalyptic](https://pixabay.com/music/search/post%20apocalyptic/) ·
  [desert](https://pixabay.com/music/search/desert/)
- Ross Bugden — **"The Wasteland"** (dramatic, free): [YouTube](https://www.youtube.com/watch?v=5eAalHA1bAc) ·
  [SoundCloud](https://soundcloud.com/rossbugden/dramatic-apocalyptic-music-the-wasteland-copyright-and-royalty-free)

### `home.ogg` — Home base (calmer, gritty-but-hopeful settlement)
- 🔎 Pixabay: [western desert](https://pixabay.com/music/search/western%20desert/) (pick a
  mellow acoustic one) · [OpenGameArt CC0 music](https://opengameart.org/content/cc0-music-0)

### `map.ogg` — Overworld map (traveling, spaghetti-western journey)
- 🔎 Pixabay: [spaghetti western](https://pixabay.com/music/search/spaghetti-western/) ·
  [wild west](https://pixabay.com/music/search/wild%20west/)
- Specific: **"Western Adventure — Cinematic Spaghetti Loop"** by *Sonican* (loops cleanly,
  on the spaghetti-western page above).

### `battle.ogg` — Normal combat (driving, western + industrial energy)
- 🔎 Pixabay: [game western](https://pixabay.com/music/search/game%20western/)
- Specific: **"Western Duel"** by *Music_For_Videos* (tense standoff energy) ·
  **"Tex Mex — electronic cowboy"** by *melodyayresgriffiths*.

### `boss.ogg` — Boss combat (intense, dramatic, high stakes)
- 🔎 Pixabay: [post-apocalyptic](https://pixabay.com/music/search/post%20apocalyptic/) (the
  bigger, drum-heavy ones)
- Silverman Sound — **"Against Time"** (industrial drums + driving piano, very boss-fight):
  [link](https://www.silvermansound.com/free-music/against-time)
- Uppbeat — [post-apocalyptic category](https://uppbeat.io/music/category/dark/post-apocalyptic)

### `shop.ogg` — Merchant (NEW; relaxed, cozy western saloon)
- 🔎 Pixabay: [western](https://pixabay.com/music/search/western/) (pick a slow, warm,
  acoustic/whistle one — think saloon between gunfights)

### `event.ogg` — Random event (NEW; short, tense/mysterious bed)
- 🔎 Pixabay: [desert](https://pixabay.com/music/search/desert/) +
  [post-apocalyptic](https://pixabay.com/music/search/post%20apocalyptic/) (pick an ambient,
  low-key, loopable one — it plays under a decision)

---

## My quick recommendation (if you just want one fast set)
Pixabay is the fastest: open the **spaghetti-western** and **post-apocalyptic** pages,
grab one warm/traveling track (→ `map`/`home`/`shop`), one tense one (→ `battle`), one
big dramatic one (→ `boss`/`menu`), one ambient one (→ `event`). All download as MP3 you
can drop straight in. Tell me which you picked and I'll convert/loop + wire the two new
slots.

Sources: [Pixabay Music](https://pixabay.com/music/), [OpenGameArt CC0](https://opengameart.org/content/cc0-music-0),
[Silverman Sound](https://www.silvermansound.com/free-music/against-time),
[Uppbeat](https://uppbeat.io/music/category/dark/post-apocalyptic),
[Ross Bugden](https://www.youtube.com/watch?v=5eAalHA1bAc).
