#!/usr/bin/env python3
"""Procedural BGM generator for the demo (numpy synth, wasteland-western palette).

Music -> assets/audio/music/*.ogg (this script ffmpeg-converts WAV->OGG itself).
Tracks are ~50-60s with a seamless crossfade loop point so the loop is not obvious.

  python scripts/gen_audio.py          # (re)generate BGM oggs (battle/boss/map/home/shop/event)
  python scripts/gen_audio.py --sfx    # ALSO write the legacy procedural SFX (fallback only)

SFX now ship from the Kenney CC0 audio packs (see assets/audio/sfx/README.md); the
procedural SFX synth below is kept as an opt-in fallback. `menu.ogg` is the real
licensed track (Wild West - Desert Wind) and is NEVER regenerated here.
"""
import os, wave, struct
import numpy as np

SR = 44100
SFX_DIR = "assets/audio/sfx"
MUS_DIR = "assets/audio/music"
os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUS_DIR, exist_ok=True)
rng = np.random.default_rng(7)

# ---------- core synth helpers ----------
def tarr(d): return np.linspace(0, d, int(SR * d), endpoint=False)
def sine(f, d, ph=0.0): return np.sin(2 * np.pi * f * tarr(d) + ph)
def saw(f, d):
    x = tarr(d) * f; return 2.0 * (x - np.floor(0.5 + x))
def square(f, d, duty=0.5):
    x = (tarr(d) * f) % 1.0; return np.where(x < duty, 1.0, -1.0)
def tri(f, d): return 2.0 * np.abs(saw(f, d)) - 1.0
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def silence(d): return np.zeros(int(SR * d))

def env_perc(sig, decay=20.0):
    n = len(sig); return sig * np.exp(-decay * np.linspace(0, 1, n) * (n / SR))

def adsr(n, a, d, s, r):
    a = max(1, int(a * SR)); d = max(1, int(d * SR)); r = max(1, int(r * SR))
    sus = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a), np.linspace(1, s, d),
        np.full(sus, s), np.linspace(s, 0, r)])
    if len(env) < n: env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]

def lowpass(sig, cutoff):
    rc = 1.0 / (2 * np.pi * cutoff); alpha = (1.0 / SR) / (rc + 1.0 / SR)
    out = np.zeros_like(sig); acc = 0.0
    for i in range(len(sig)):
        acc += alpha * (sig[i] - acc); out[i] = acc
    return out

def delay(sig, time=0.18, fb=0.35, mix=0.3, taps=4):
    out = sig.copy(); d = int(time * SR)
    for k in range(1, taps + 1):
        if d * k >= len(sig): break
        echo = np.zeros_like(sig); echo[d * k:] = sig[:len(sig) - d * k]
        out += echo * (fb ** k) * mix
    return out

def norm(sig, peak=0.85):
    m = np.max(np.abs(sig)) or 1.0; return sig / m * peak

def softclip(sig): return np.tanh(sig)

def padd(*sigs):
    n = max(len(s) for s in sigs); out = np.zeros(n)
    for s in sigs: out[:len(s)] += s
    return out

def seamless(track, xfade=0.6):
    """Fold the track's tail into its head so end->start loops without a click/gap.
    Returns the trimmed track whose first `xfade`s already contain the old tail, so
    playing it on loop is seamless. No-op for very short tracks."""
    n = int(xfade * SR)
    if 2 * n >= len(track):
        return track
    head = track[:n].copy()
    tail = track[-n:].copy()
    fin = np.linspace(0.0, 1.0, n)
    track[:n] = head * fin + tail * (1.0 - fin)
    return track[:-n]

def write_wav(path, sig, sr=SR):
    sig = np.clip(sig, -1, 1); data = (sig * 32767).astype("<i2").tobytes()
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(data)
    return path

def midi(n): return 440.0 * 2 ** ((n - 69) / 12.0)

# ---------- SFX (legacy procedural fallback — opt-in via --sfx; Kenney CC0 is the default) ----------
def sfx_ui_click():
    s = padd(env_perc(square(880, 0.05, 0.5), 60) * 0.5, env_perc(sine(1600, 0.04), 80) * 0.3)
    return norm(s, 0.6)

def sfx_ui_back():
    s = padd(env_perc(square(440, 0.07), 40) * 0.5, env_perc(sine(660, 0.05), 60) * 0.25)
    return norm(s, 0.55)

def sfx_card_play():
    w = env_perc(noise(0.12), 18) * lowpass_sweep(0.12, 4000, 600)
    thn = env_perc(sine(180, 0.12), 22) * 0.8
    return norm(w * 0.5 + thn)

def lowpass_sweep(d, f0, f1):
    n = int(SR * d); return np.interp(np.arange(n), [0, n - 1], [1, 0])  # amp-only fallback

def sfx_card_draw():
    s = padd(env_perc(noise(0.08), 35) * 0.4, env_perc(sine(1200, 0.06), 50) * 0.2)
    return norm(s, 0.5)

def sfx_attack_hit():
    thump = env_perc(sine(90, 0.18), 16)
    crack = env_perc(noise(0.10), 30)
    body = env_perc(square(140, 0.12, 0.3), 22) * 0.4
    return norm(softclip(padd(thump * 1.2, crack * 0.7, body)))

def sfx_attack_slash():
    s = env_perc(noise(0.16), 14) * np.interp(np.arange(int(SR*0.16)), [0, int(SR*0.16)], [1, 0.2])
    s = padd(s, env_perc(sine(300, 0.12), 20) * 0.3)
    return norm(s, 0.8)

def sfx_crit():
    s = padd(env_perc(sine(1320, 0.25), 9), env_perc(sine(1980, 0.25), 11) * 0.6, env_perc(sine(2640, 0.2), 14) * 0.35)
    s = delay(s, 0.06, 0.4, 0.4, 3)
    return norm(s, 0.85)

def sfx_block_gain():
    s = padd(env_perc(tri(523, 0.12), 18) * 0.6, env_perc(sine(784, 0.1), 22) * 0.4, env_perc(noise(0.05), 50) * 0.15)
    return norm(s, 0.7)

def sfx_heal():
    n = int(SR * 0.4); f = np.interp(np.arange(n), [0, n], [440, 880])
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * adsr(n, 0.05, 0.1, 0.6, 0.2)
    return norm(s, 0.55)

def sfx_bleed():
    s = padd(env_perc(lowpass(noise(0.14), 900), 16) * 0.7, env_perc(sine(120, 0.12), 24) * 0.3)
    return norm(s, 0.55)

def sfx_gold():
    s = silence(0)
    for i, f in enumerate([1568, 2093, 2637]):
        seg = env_perc(sine(f, 0.12), 16) * 0.5
        pad = silence(0.03 * i); s = mix2(s, np.concatenate([pad, seg]))
    return norm(s, 0.6)

def mix2(a, b):
    n = max(len(a), len(b)); out = np.zeros(n)
    out[:len(a)] += a; out[:len(b)] += b; return out

def sfx_reward_chime():
    notes = [midi(72), midi(76), midi(79), midi(84)]; s = silence(0)
    for i, f in enumerate(notes):
        seg = env_perc(sine(f, 0.3), 8) * 0.5 + env_perc(tri(f, 0.3), 8) * 0.2
        s = mix2(s, np.concatenate([silence(0.08 * i), seg]))
    return norm(delay(s, 0.12, 0.3, 0.25), 0.7)

def sfx_level_up():
    notes = [midi(60), midi(64), midi(67), midi(72), midi(76)]; s = silence(0)
    for i, f in enumerate(notes):
        seg = env_perc(square(f, 0.18, 0.4), 14) * 0.4
        s = mix2(s, np.concatenate([silence(0.06 * i), seg]))
    return norm(s, 0.7)

def sfx_turn_start():
    s = padd(env_perc(sine(523, 0.12), 16) * 0.5, env_perc(sine(784, 0.1), 20) * 0.3)
    return norm(s, 0.5)

def sfx_enemy_attack():
    s = padd(env_perc(saw(70, 0.22), 12) * 0.6, env_perc(noise(0.12), 24) * 0.5, env_perc(sine(55, 0.2), 14) * 0.5)
    return norm(softclip(s), 0.85)

def sfx_defeat():
    notes = [midi(60), midi(58), midi(55), midi(51)]; s = silence(0)
    for i, f in enumerate(notes):
        seg = env_perc(tri(f, 0.5), 5) * 0.5
        s = mix2(s, np.concatenate([silence(0.18 * i), seg]))
    return norm(s, 0.7)

def sfx_victory():
    notes = [midi(60), midi(64), midi(67), midi(72)]; s = silence(0)
    for i, f in enumerate(notes):
        seg = env_perc(sine(f, 0.6), 4) * 0.4 + env_perc(saw(f, 0.6), 4) * 0.2
        s = mix2(s, np.concatenate([silence(0.12 * i), seg]))
    chord = sum(env_perc(sine(midi(m), 0.7), 3) for m in [72, 76, 79]) * 0.2
    s = mix2(s, np.concatenate([silence(0.48), chord]))
    return norm(delay(s, 0.16, 0.3, 0.25), 0.8)

def sfx_reload():
    a = padd(env_perc(noise(0.05), 60) * 0.6, env_perc(square(220, 0.04), 50) * 0.4)
    b = padd(env_perc(noise(0.05), 60) * 0.6, env_perc(square(180, 0.05), 45) * 0.4)
    return norm(np.concatenate([a, silence(0.06), b]), 0.7)

def sfx_error():
    s = env_perc(square(160, 0.18, 0.5), 12) * 0.5
    return norm(s, 0.55)

def sfx_gem():
    s = padd(env_perc(sine(2100, 0.25), 10), env_perc(sine(3150, 0.22), 13) * 0.5)
    return norm(delay(s, 0.05, 0.4, 0.4, 4), 0.6)

SFX = {
    "ui_click": sfx_ui_click, "ui_back": sfx_ui_back, "card_play": sfx_card_play,
    "card_draw": sfx_card_draw, "attack_hit": sfx_attack_hit, "attack_slash": sfx_attack_slash,
    "crit": sfx_crit, "block_gain": sfx_block_gain, "heal": sfx_heal, "bleed": sfx_bleed,
    "gold": sfx_gold, "reward": sfx_reward_chime, "level_up": sfx_level_up,
    "turn_start": sfx_turn_start, "enemy_attack": sfx_enemy_attack, "defeat": sfx_defeat,
    "victory": sfx_victory, "reload": sfx_reload, "error": sfx_error, "gem": sfx_gem,
}

# ---------- music ----------
def instr_pluck(f, d, vol=0.5):
    s = (saw(f, d) * 0.6 + square(f, d, 0.45) * 0.4) * adsr(int(SR * d), 0.005, 0.08, 0.4, 0.15)
    return lowpass(s, 2200) * vol

def instr_bass(f, d, vol=0.6):
    s = (square(f, d, 0.5) * 0.7 + sine(f, d) * 0.5) * adsr(int(SR * d), 0.01, 0.05, 0.7, 0.1)
    return lowpass(s, 700) * vol

def instr_pad(f, d, vol=0.3):
    s = sum(saw(f * r, d) for r in [1.0, 1.004, 0.996]) / 3.0
    return lowpass(s, 1500) * adsr(int(SR * d), 0.3, 0.2, 0.7, 0.4) * vol

def instr_lead(f, d, vol=0.4):
    s = tri(f, d) * adsr(int(SR * d), 0.01, 0.1, 0.5, 0.2)
    return s * vol

def drum_kick(d=0.18):
    n = int(SR * d); f = np.interp(np.arange(n), [0, n], [120, 40])
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-18 * np.linspace(0, 1, n) * (n / SR))

def drum_snare(d=0.12):
    return (env_perc(noise(d), 30) * 0.6 + env_perc(tri(180, d), 22) * 0.3)

def drum_hat(d=0.05):
    return env_perc(lowpass(noise(d), 9000) - lowpass(noise(d), 6000), 60) * 0.5

def place(track, sig, at_sec):
    i = int(at_sec * SR); end = i + len(sig)
    if end > len(track): sig = sig[:len(track) - i]
    track[i:i + len(sig)] += sig

def build_music(bpm, bars, chords, lead_notes=None, drums=False, kick_only=False,
                pad=True, lead_vol=0.4, loop_xfade=0.6):
    """Render `bars` bars at `bpm`, then fold a seamless loop point. The lead motif
    repeats (2 slots/bar) instead of stretching, so long tracks keep their shape."""
    beat = 60.0 / bpm; bar = beat * 4; total = bar * bars
    track = np.zeros(int(SR * total))
    for b in range(bars):
        root = chords[b % len(chords)]
        # bass on beats
        for k in range(4):
            place(track, instr_bass(midi(root - 12), beat * 0.9), b * bar + k * beat)
        # pad chord (root, +3, +7)
        if pad:
            for off in [0, 3, 7]:
                place(track, instr_pad(midi(root + off), bar * 0.98, 0.22), b * bar)
        # arp pluck
        arp = [root, root + 7, root + 12, root + 7]
        for k in range(4):
            place(track, instr_pluck(midi(arp[k % 4]), beat * 0.5, 0.32), b * bar + k * beat)
        # drums
        if drums:
            for k in range(4):
                place(track, drum_kick(), b * bar + k * beat)
                place(track, drum_hat(), b * bar + k * beat + beat * 0.5)
            place(track, drum_snare(), b * bar + beat)
            place(track, drum_snare(), b * bar + 3 * beat)
        elif kick_only:
            place(track, drum_kick(), b * bar)
            place(track, drum_kick(), b * bar + 2 * beat)
    # lead melody — repeat the motif (2 slots/bar) across all bars rather than
    # stretching a few notes over the whole (now much longer) track.
    if lead_notes:
        seg = bar / 2.0
        for i in range(bars * 2):
            nn = lead_notes[i % len(lead_notes)]
            if nn is None:
                continue
            place(track, instr_lead(midi(nn), seg * 0.9, lead_vol), i * seg)
    track = norm(softclip(track * 1.1), 0.7)
    if loop_xfade > 0.0:
        track = seamless(track, loop_xfade)
    return track

# minor-key wasteland progressions (MIDI root notes). bars tuned for ~50-60s loops.
A = 57  # A3
def music_battle():
    # driving Am - G - F - E
    ch = [A, A - 2, A - 4, A - 5]
    lead = [69, 72, 71, 69, 67, 69, 64, 67]
    return build_music(124, 28, ch, lead_notes=lead, drums=True, lead_vol=0.34)
def music_map():
    ch = [A, A + 3, A - 4, A - 2]
    lead = [76, None, 72, None, 69, None, 71, None]
    return build_music(96, 22, ch, lead_notes=lead, kick_only=True, lead_vol=0.3)
def music_home():
    ch = [A + 3, A, A - 2, A - 4]
    lead = [72, None, 76, None, 74, None, 71, None]
    return build_music(84, 20, ch, lead_notes=lead, pad=True, lead_vol=0.28)
def music_boss():
    ch = [A - 5, A - 5, A - 4, A - 2]
    lead = [64, 65, 67, 64, 60, 62, 64, 62]
    return build_music(132, 30, ch, lead_notes=lead, drums=True, lead_vol=0.38)
def music_shop():
    # warm, relaxed saloon — gentle, no drums
    ch = [A + 3, A + 5, A, A + 2]
    lead = [76, None, 79, None, 77, None, 72, None]
    return build_music(92, 20, ch, lead_notes=lead, pad=True, lead_vol=0.26)
def music_event():
    # sparse, tense, ambient bed under a decision
    ch = [A - 5, A - 7, A - 4, A - 5]
    lead = [60, None, None, 62, None, None, 59, None]
    return build_music(70, 16, ch, lead_notes=lead, kick_only=True, pad=True, lead_vol=0.22)

# NOTE: "menu" is intentionally absent — menu.ogg is the real licensed track.
MUSIC = {"battle": music_battle, "map": music_map, "home": music_home,
         "boss": music_boss, "shop": music_shop, "event": music_event}

if __name__ == "__main__":
    import subprocess, sys
    if "--sfx" in sys.argv:  # legacy procedural SFX — Kenney CC0 is the default set
        for name, fn in SFX.items():
            write_wav(f"{SFX_DIR}/{name}.wav", fn())
        print(f"wrote {len(SFX)} legacy SFX -> {SFX_DIR}")
    for name, fn in MUSIC.items():
        wav = f"{MUS_DIR}/{name}.wav"; ogg = f"{MUS_DIR}/{name}.ogg"
        sig = fn(); write_wav(wav, sig)
        subprocess.run(["ffmpeg", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg],
                       check=True, capture_output=True)
        os.remove(wav)
        print(f"wrote {name}.ogg ({len(sig) / SR:.0f}s)")
    print(f"wrote {len(MUSIC)} music loops (.ogg) -> {MUS_DIR}  (menu.ogg = real track, untouched)")
