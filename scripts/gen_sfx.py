#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Procedural chiptune SFX generator.

Synthesizes ORIGINAL 8-bit-style sound effects (no samples, no external audio
assets) straight to assets/audio/sfx/<name>.wav. Each cue is a hand-tuned
waveform + envelope — unique per action, matching the game's pixel/cartoon feel.

Run:  python scripts/gen_sfx.py [name ...]
      (no args = generate all cues)

After running, re-import in Godot so the new .wav files are picked up:
      "<godot>" --headless --path . --import
"""
import os
import sys
import numpy as np
from scipy.io import wavfile

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx"))


# ── primitives ────────────────────────────────────────────────────────────────
def _t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def square(freq, dur, duty=0.5):
    ph = (freq * _t(dur)) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def sine(freq, dur):
    return np.sin(2 * np.pi * freq * _t(dur))


def triangle(freq, dur):
    ph = (freq * _t(dur)) % 1.0
    return 2 * np.abs(2 * ph - 1) - 1


def noise(dur):
    return np.random.uniform(-1, 1, int(SR * dur))


def sweep_square(f0, f1, dur, duty=0.5):
    t = _t(dur)
    freq = np.linspace(f0, f1, len(t))
    ph = np.cumsum(freq) / SR % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def env(sig, a=0.005, d=0.04, s=0.5, r=0.08):
    """ADSR envelope (seconds for a/d/r; s is sustain level 0..1)."""
    n = len(sig)
    e = np.zeros(n)
    ai, di, ri = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    ae = min(ai, n)
    e[:ae] = np.linspace(0, 1, ae)
    de = min(ae + di, n)
    if de > ae:
        e[ae:de] = np.linspace(1, s, de - ae)
    rs = max(de, n - ri)
    if rs > de:
        e[de:rs] = s
    if n > rs:
        e[rs:] = np.linspace(s, 0, n - rs)
    return sig * e


def expdecay(sig, tau=0.1):
    return sig * np.exp(-_t(len(sig) / SR) / tau)


def norm(sig, peak=0.85):
    m = np.max(np.abs(sig))
    return sig if m < 1e-9 else sig / m * peak


def cat(*parts):
    return np.concatenate(parts)


def mix(*sigs):
    n = max(len(s) for s in sigs)
    out = np.zeros(n)
    for s in sigs:
        out[: len(s)] += s
    return out


def gap(dur):
    return np.zeros(int(SR * dur))


# ── cues ──────────────────────────────────────────────────────────────────────
def purchase():
    """Bright two-note coin 'cha-ching' (square)."""
    a = env(square(midi(84), 0.06), a=0.002, d=0.02, s=0.7, r=0.03)  # C6
    b = env(square(midi(91), 0.20), a=0.002, d=0.05, s=0.6, r=0.12)  # G6
    return cat(a, b)


def upgrade():
    """Triumphant rising arpeggio C5-E5-G5-C6 (square)."""
    notes, parts = [72, 76, 79, 84], []
    for i, nn in enumerate(notes):
        last = i == len(notes) - 1
        parts.append(
            env(square(midi(nn), 0.24 if last else 0.075), a=0.003, d=0.03,
                s=0.7, r=0.16 if last else 0.05)
        )
    return cat(*parts)


def forge_craft():
    """Two metallic hammer strikes — low punch + transient + ring."""
    def strike():
        body = expdecay(sine(155, 0.13), 0.05) + 0.6 * expdecay(square(155, 0.13), 0.04)
        tick = expdecay(noise(0.13), 0.010) * 0.5
        ring = expdecay(sine(2400, 0.13), 0.03) * 0.22 + expdecay(sine(3170, 0.13), 0.03) * 0.12
        return body + tick + ring
    return cat(strike(), gap(0.05), strike() * 0.82)


def forge_dismantle():
    """Take-apart: a clank then crumbling debris (descending filtered noise)."""
    clank = expdecay(square(520, 0.1), 0.025) * 0.5 + expdecay(sine(880, 0.1), 0.02) * 0.32
    t = _t(0.30)
    desc = np.sin(2 * np.pi * np.linspace(820, 130, len(t)) * t)
    crumble = expdecay(noise(0.30), 0.10) * (0.35 + 0.65 * np.abs(desc)) * 0.7
    return cat(clank, crumble)


def forge_reforge():
    """Rising magical shimmer — sweep + vibrato sparkle."""
    base = env(sweep_square(300, 1150, 0.30), a=0.01, d=0.05, s=0.7, r=0.1) * 0.55
    t = _t(0.30)
    vib = np.sin(2 * np.pi * np.linspace(820, 1640, len(t)) * t + 6 * np.sin(2 * np.pi * 18 * t))
    sparkle = env((vib > 0).astype(float) * 2 - 1, a=0.01, d=0.1, s=0.4, r=0.12) * 0.38
    return mix(base, sparkle)


def forge_curse():
    """Ominous descending detuned dyad (tritone) + low rumble + slow vibrato."""
    t = _t(0.5)
    f = np.linspace(330, 158, len(t))
    a = (np.sin(2 * np.pi * f * t) > 0).astype(float) * 2 - 1
    b = (np.sin(2 * np.pi * f * 1.414 * t) > 0).astype(float) * 2 - 1  # tritone = dissonant
    dyad = env(a * 0.5 + b * 0.4, a=0.02, d=0.1, s=0.6, r=0.2)
    dyad *= 0.85 + 0.15 * np.sin(2 * np.pi * 5 * t)  # unease vibrato
    rumble = expdecay(sine(70, 0.5), 0.3) * 0.4
    return mix(dyad, rumble)


CUES = {
    "purchase": purchase,
    "upgrade": upgrade,
    "forge_craft": forge_craft,
    "forge_dismantle": forge_dismantle,
    "forge_reforge": forge_reforge,
    "forge_curse": forge_curse,
}


def main(argv):
    names = argv or list(CUES)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        if name not in CUES:
            print("unknown cue:", name)
            continue
        sig = norm(CUES[name]())
        wavfile.write(os.path.join(OUT, name + ".wav"), SR, (sig * 32767).astype(np.int16))
        print("wrote %-18s %.2fs" % (name + ".wav", len(sig) / SR))


if __name__ == "__main__":
    main(sys.argv[1:])
