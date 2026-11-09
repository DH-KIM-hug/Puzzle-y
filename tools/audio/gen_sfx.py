#!/usr/bin/env python3
"""Render the Mallang Crew SFX set (design/gdd/audio.md, Visual/Audio table).

Standard library only (math, random, struct, wave). Every sound is synthesized
from sine / triangle / square / noise sources with envelopes, pitch sweeps and
simple chords -- no external or copyrighted material. Output: 22,050 Hz mono
16-bit PCM WAV, peak-normalised to -1 dBFS, short fade-out (no clicks).

Deterministic: a fixed seed per sound, so re-running produces identical files.

Usage:
    python3 tools/audio/gen_sfx.py [out_dir]     # default assets/audio/sfx
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
PEAK_DBFS = -1.0
TAU = 2.0 * math.pi


# --- primitives ---------------------------------------------------------------

def n_samples(dur):
    return max(1, int(round(dur * SR)))


def silence(dur):
    return [0.0] * n_samples(dur)


def osc(freq_fn, dur, shape="sine", phase=0.0):
    """Oscillator with a time-varying frequency (freq_fn(t) -> Hz)."""
    out = []
    ph = phase
    for i in range(n_samples(dur)):
        t = i / SR
        f = freq_fn(t)
        ph += f / SR
        x = ph % 1.0
        if shape == "sine":
            v = math.sin(TAU * x)
        elif shape == "tri":
            v = 4.0 * abs(x - 0.5) - 1.0
        elif shape == "square":
            # soft square: sum of 3 odd harmonics (rounder than a hard square)
            v = (math.sin(TAU * x) + math.sin(3 * TAU * x) / 3 + math.sin(5 * TAU * x) / 5) * 0.8
        elif shape == "saw":
            v = 2.0 * x - 1.0
        else:
            raise ValueError(shape)
        out.append(v)
    return out


def sweep(f0, f1, dur, curve=1.0):
    """Frequency function: exponential-ish glide f0 -> f1."""
    def f(t):
        q = min(1.0, t / dur) ** curve
        return f0 * (f1 / f0) ** q
    return f


def const(f0):
    return lambda t: f0


def vibrato(base_fn, rate, depth):
    return lambda t: base_fn(t) * (1.0 + depth * math.sin(TAU * rate * t))


def noise(dur, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples(dur))]


def lowpass(sig, cutoff_fn):
    """One-pole low-pass with a time-varying cutoff (Hz)."""
    out = []
    y = 0.0
    for i, x in enumerate(sig):
        fc = cutoff_fn(i / SR)
        a = 1.0 - math.exp(-TAU * fc / SR)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, const(cutoff))
    return [x - y for x, y in zip(sig, lp)]


def env(sig, attack=0.005, decay=None, hold=0.0, curve=2.0):
    """Attack-hold-decay envelope; decay defaults to the remaining length."""
    n = len(sig)
    a = n_samples(attack) if attack > 0 else 0
    h = n_samples(hold) if hold > 0 else 0
    d = n - a - h if decay is None else n_samples(decay)
    out = []
    for i, x in enumerate(sig):
        if i < a:
            g = i / max(a, 1)
        elif i < a + h:
            g = 1.0
        else:
            q = (i - a - h) / max(d, 1)
            g = max(0.0, 1.0 - q) ** curve
        out.append(x * g)
    return out


def gain(sig, g):
    return [x * g for x in sig]


def mix(*parts):
    """Mix (signal, offset_seconds) pairs or plain signals."""
    norm = [(p, 0.0) if isinstance(p, list) else p for p in parts]
    n = max(n_samples(off) + len(s) for s, off in norm)
    out = [0.0] * n
    for s, off in norm:
        o = n_samples(off) if off > 0 else 0
        for i, x in enumerate(s):
            out[o + i] += x
    return out


def fade_out(sig, dur=0.012):
    k = min(len(sig), n_samples(dur))
    for i in range(k):
        sig[len(sig) - k + i] *= 1.0 - (i + 1) / k
    return sig


def fade_in(sig, dur=0.002):
    k = min(len(sig), n_samples(dur))
    for i in range(k):
        sig[i] *= i / k
    return sig


def note(semis_from_a4):
    return 440.0 * 2.0 ** (semis_from_a4 / 12.0)


# Notes (A4 = 0).
C5, D5, E5, F5, G5, A5, B5 = 3, 5, 7, 8, 10, 12, 14
C6, E6, G6 = 15, 19, 22
C4, E4, G4 = -9, -5, -2


def tone(semis, dur, shape="tri", attack=0.004, curve=2.0, partials=None):
    f = note(semis)
    if partials:
        s = mix(*[gain(osc(const(f * m), dur, "sine"), a) for m, a in partials])
    else:
        s = osc(const(f), dur, shape)
    return env(s, attack=attack, curve=curve)


def crackle(dur, seed, density=180.0, length=0.004):
    """Sparse tiny clicks = paper rustle."""
    rng = random.Random(seed)
    out = [0.0] * n_samples(dur)
    t = 0.0
    while t < dur:
        t += rng.expovariate(density)
        start = n_samples(t)
        click = env(noise(length, rng.randint(0, 1 << 30)), attack=0.0005, curve=1.5)
        amp = rng.uniform(0.3, 1.0) * (1.0 - t / dur)
        for i, x in enumerate(click):
            if start + i < len(out):
                out[start + i] += x * amp
    return out


# --- the 21 sounds (design/gdd/audio.md Visual/Audio table) -----------------------

def ui_tap():
    body = env(osc(sweep(1300, 900, 0.05), 0.06), attack=0.001, curve=3)
    click = gain(env(highpass(noise(0.006, 1), 2000), attack=0.0, curve=2), 0.4)
    return mix(body, click)


def pick_up():
    return env(osc(sweep(330, 760, 0.08, 0.7), 0.10), attack=0.004, curve=1.6)


def place_thud():
    low = env(osc(sweep(150, 60, 0.12), 0.18), attack=0.002, curve=2.2)
    wob = env(osc(vibrato(const(120), 28, 0.12), 0.16, "sine"), attack=0.01, curve=2.5)
    thump = env(lowpass(noise(0.05, 2), const(500)), attack=0.001, curve=2)
    return mix(low, gain(wob, 0.4), gain(thump, 1.6))


def invalid_return():
    a = env(osc(vibrato(const(620), 9, 0.015), 0.10, "tri"), attack=0.004, curve=1.2)
    b = env(osc(vibrato(sweep(470, 430, 0.14), 9, 0.02), 0.14, "tri"), attack=0.004, curve=1.8)
    return mix((a, 0.0), (b, 0.10))


def line_sweep():
    n = noise(0.26, 3)
    swept = lowpass(n, lambda t: 600 + 5200 * min(1.0, t / 0.2))
    body = env(swept, attack=0.03, curve=1.6)
    return mix(gain(body, 1.4), gain(crackle(0.24, 4, 120), 0.35))


def cell_pop():
    return env(osc(sweep(950, 480, 0.05), 0.07), attack=0.001, curve=2.4)


def sticker_peel():
    n = highpass(noise(0.18, 5), 900)
    body = env(lowpass(n, lambda t: 1500 + 6000 * min(1.0, t / 0.15)), attack=0.06, curve=1.4)
    return mix(body, gain(crackle(0.16, 6, 220), 0.4))


def ab_cat_claw():
    def slash(seed):
        n = highpass(noise(0.09, seed), 1800)
        return env(lowpass(n, lambda t: 9000 - 5000 * min(1.0, t / 0.09)), attack=0.008, curve=2.0)
    return mix((slash(7), 0.0), (gain(slash(8), 0.85), 0.07), (gain(env(osc(sweep(1800, 1200, 0.05), 0.05), attack=0.001), 0.15), 0.0))


def ab_bear_thump():
    boom = env(osc(sweep(95, 42, 0.3), 0.5), attack=0.003, curve=2.0)
    hit = env(lowpass(noise(0.08, 9), const(700)), attack=0.001, curve=2)
    hum = env(osc(vibrato(const(70), 5, 0.04), 0.45, "tri"), attack=0.06, curve=1.6)
    ring = env(lowpass(noise(0.4, 10), lambda t: 1600 - 1200 * min(1.0, t / 0.4)), attack=0.02, curve=2.5)
    return mix(boom, gain(hit, 1.4), (gain(hum, 0.35), 0.03), (gain(ring, 0.4), 0.02))


def ab_chick_pop():
    chirp = env(osc(sweep(1500, 2300, 0.08), 0.09), attack=0.004, curve=1.4)
    pop = env(osc(sweep(900, 520, 0.06), 0.08), attack=0.001, curve=2.4)
    return mix((gain(chirp, 0.7), 0.0), (pop, 0.10))


def ab_sheep_pop():
    puff = env(osc(vibrato(sweep(420, 640, 0.18), 6, 0.03), 0.22), attack=0.05, curve=1.5)
    air = env(lowpass(noise(0.15, 11), const(1200)), attack=0.04, curve=2)
    pop = env(osc(sweep(800, 450, 0.06), 0.08), attack=0.001, curve=2.4)
    return mix(puff, gain(air, 0.25), (gain(pop, 0.8), 0.20))


def ab_frog_splash():
    splash = env(lowpass(noise(0.3, 12), lambda t: 6000 - 4800 * min(1.0, t / 0.3)), attack=0.002, curve=2.6)
    parts = [gain(splash, 1.3)]
    for k, (f, off) in enumerate([(520, 0.12), (700, 0.2), (880, 0.27)]):
        parts.append((gain(env(osc(sweep(f, f * 1.6, 0.04), 0.05), attack=0.002, curve=1.8), 0.45), off))
    return mix(*parts)


def ab_rabbit_hop():
    hop = lambda f: env(osc(sweep(f, f * 1.9, 0.07, 0.6), 0.09), attack=0.003, curve=1.8)
    return mix((hop(500), 0.0), (hop(650), 0.12))


def chain_hit():
    f = note(C5)
    body = env(osc(const(f), 0.24, "tri"), attack=0.002, curve=2.2)
    fifth = env(osc(const(f * 1.5), 0.2, "sine"), attack=0.002, curve=2.6)
    octave = env(osc(const(f * 2.0), 0.12, "sine"), attack=0.001, curve=3)
    trans = env(highpass(noise(0.03, 13), 1500), attack=0.0, curve=2)
    knock = env(osc(sweep(220, 90, 0.06), 0.08), attack=0.001, curve=2)
    return mix(body, gain(fifth, 0.45), gain(octave, 0.3), gain(trans, 0.5), gain(knock, 0.7))


def banner_slam():
    thud = env(osc(sweep(180, 70, 0.1), 0.16), attack=0.001, curve=2.2)
    slap = env(lowpass(highpass(noise(0.12, 14), 400), lambda t: 7000 - 5000 * min(1.0, t / 0.12)), attack=0.001, curve=2.4)
    return mix(thud, gain(slap, 0.9), gain(crackle(0.18, 15, 90), 0.2))


def fizzle():
    return env(osc(vibrato(sweep(320, 170, 0.36), 7, 0.05), 0.38, "tri"), attack=0.02, curve=1.3)


def cap_fanfare():
    parts = []
    for k, s in enumerate([C5, E5, G5, C6]):
        last = k == 3
        d = 0.42 if last else 0.16
        sq = gain(tone(s, d, "square", curve=1.4 if last else 2.0), 0.55)
        tr_ = gain(tone(s + 12, d, "tri", curve=2.2), 0.25)
        parts.append((mix(sq, tr_), 0.11 * k))
    return mix(*parts)


def finisher_fanfare():
    chords = [([G4, B5 - 12, D5], 0.0, 0.14), ([G4, B5 - 12, D5], 0.17, 0.14), ([C5, E5, G5], 0.34, 0.16),
              ([C5, E5, G5, C6], 0.52, 0.95)]
    parts = []
    for notes, off, d in chords:
        last = d > 0.5
        for s in notes:
            f = note(s)
            v = osc(vibrato(const(f), 5.5, 0.006 if last else 0.0), d, "square")
            parts.append((gain(env(v, attack=0.008, hold=0.25 if last else 0.0, curve=1.6), 0.28), off))
            parts.append((gain(env(osc(const(f * 2), d, "tri"), attack=0.006, curve=2.0), 0.08), off))
    parts.append((gain(env(lowpass(noise(0.12, 16), const(900)), attack=0.001, curve=2), 0.8), 0.52))
    return mix(*parts)


def confetti_burst():
    pop = env(lowpass(noise(0.06, 17), const(3000)), attack=0.001, curve=2)
    boom = env(osc(sweep(260, 90, 0.05), 0.07), attack=0.001, curve=2)
    rustle = env(crackle(0.58, 18, 260), attack=0.02, curve=1.2)
    return mix(gain(pop, 1.2), gain(boom, 0.6), (gain(rustle, 0.6), 0.02))


def score_tick():
    return env(osc(const(2000), 0.03), attack=0.0008, curve=2.5)


def result_chime():
    bell = [(1.0, 1.0), (2.76, 0.35), (5.4, 0.12)]
    parts = []
    for k, s in enumerate([C6, E6, G6]):
        d = 1.2 - 0.25 * k
        f = note(s)
        b = mix(*[gain(osc(const(f * m), d), a) for m, a in bell])
        parts.append((env(b, attack=0.003, curve=3.0), 0.25 * k))
    return mix(*parts)


SOUNDS = {
    "ui_tap": ui_tap,
    "pick_up": pick_up,
    "place_thud": place_thud,
    "invalid_return": invalid_return,
    "line_sweep": line_sweep,
    "cell_pop": cell_pop,
    "sticker_peel": sticker_peel,
    "ab_cat_claw": ab_cat_claw,
    "ab_bear_thump": ab_bear_thump,
    "ab_chick_pop": ab_chick_pop,
    "ab_sheep_pop": ab_sheep_pop,
    "ab_frog_splash": ab_frog_splash,
    "ab_rabbit_hop": ab_rabbit_hop,
    "chain_hit": chain_hit,
    "banner_slam": banner_slam,
    "fizzle": fizzle,
    "cap_fanfare": cap_fanfare,
    "finisher_fanfare": finisher_fanfare,
    "confetti_burst": confetti_burst,
    "score_tick": score_tick,
    "result_chime": result_chime,
}


def finalize(sig):
    peak = max((abs(x) for x in sig), default=0.0)
    if peak > 0:
        target = 10.0 ** (PEAK_DBFS / 20.0)
        sig = [x * target / peak for x in sig]
    return fade_out(fade_in(sig))


def write_wav(path, sig):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in sig))


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "assets", "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for name, fn in SOUNDS.items():
        sig = finalize(fn())
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, sig)
        size = os.path.getsize(path)
        total += size
        print("%-18s %5.2f s %7d B" % (name, len(sig) / SR, size))
    print("total %d files, %d B (%.1f KB)" % (len(SOUNDS), total, total / 1024))


if __name__ == "__main__":
    main()
