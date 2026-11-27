"""DREAM PROTOCOL - title theme, full version: "The Place We Remember".

A layered piece built on the game's music-box lullaby (scripts/autoload/sfx.gd, _track_title): the same
melody on the same instrument, with a marimba, glass bells, an electric piano, a choir of soft humming
voices, and wind in the leaves under everything. A feeling of wanting to go back somewhere, without
knowing quite where: it never fully resolves.

    python3 tools/music/compose_longing.py <out.wav>          (needs numpy + scipy)

Structure (each phrase = 4 bars x 6 s = 24 s, 40 bpm, a note every 1.5 s):
    0:00 intro     wind, humming, a few far bells
    0:24 A1        the music box alone, the old theme
    0:48 A2        marimba joins, rippling under it
    1:12 B1        lifts: a new, rising melody; the electric piano comes in
    1:36 B2        bells answer the melody
    2:00 A3        everything: the theme again, full
    2:24 bridge    thins out; the melody keeps starting and not finishing
    2:48 A4        the music box alone again; it ends on the wrong chord, and stops
    3:12 outro     wind, one bell, the humming fading
"""
import math
import sys

import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
rng = np.random.default_rng(312)


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


TOTAL = 214.0
N = int(TOTAL * SR)
L = np.zeros(N)
R = np.zeros(N)
dry_l, dry_r = np.zeros(N), np.zeros(N)       # what goes to the reverb


def place(sig, start, pan=0.0, gain=1.0, verb=0.35):
    """Add a mono signal at `start` seconds, panned (-1 left .. 1 right)."""
    i0 = int(start * SR)
    if i0 >= N:
        return
    sig = sig[: N - i0] * gain
    lg = math.cos((pan + 1) * math.pi / 4)
    rg = math.sin((pan + 1) * math.pi / 4)
    L[i0:i0 + len(sig)] += sig * lg
    R[i0:i0 + len(sig)] += sig * rg
    dry_l[i0:i0 + len(sig)] += sig * lg * verb
    dry_r[i0:i0 + len(sig)] += sig * rg * verb


def tt(sec):
    return np.arange(int(sec * SR)) / SR


# ------------------------------------------------------------------ instruments

def music_box(m, length=3.5):
    """The game's own music box (sfx.gd _bell): a sine with fading 2nd and 3rd partials."""
    f = hz(m)
    t = tt(length)
    env = np.minimum(1.0, t * 300.0) * np.exp(-t * 1.6)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3.0) + 0.12 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 6.0)
    # a tiny mechanical tick at the pluck
    s[:200] += rng.normal(0, 0.15, 200) * np.exp(-np.arange(200) / 40.0)
    return s * env


def marimba(m, length=2.2):
    """A rosewood bar: the fundamental, the bar's tuned 4th partial, a soft mallet thump."""
    f = hz(m)
    t = tt(length)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2)
    s += 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 14.0)
    s += 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 40.0)
    s += 0.3 * np.sin(2 * np.pi * f * 0.5 * t) * np.exp(-t * 30.0) * 0.4      # the resonator's body
    att = np.minimum(1.0, t * 900.0)
    return s * att


def glass_bell(m, length=7.0):
    """A small glass/tubular bell: inharmonic partials ringing at different rates, a slow shimmer."""
    f = hz(m)
    t = tt(length)
    parts = [(1.0, 1.0, 0.7), (2.76, 0.45, 1.4), (5.4, 0.22, 2.6), (8.93, 0.12, 4.5), (0.5, 0.18, 0.9)]
    s = np.zeros_like(t)
    for ratio, amp, dec in parts:
        s += amp * np.sin(2 * np.pi * f * ratio * t + ratio) * np.exp(-t * dec)
    s *= 1.0 + 0.08 * np.sin(2 * np.pi * 5.3 * t)       # the beating of a real bell
    return s * np.minimum(1.0, t * 600.0)


def epiano(m, length=5.0, vel=1.0):
    """A Rhodes-like electric piano: FM tine with a bell-ish attack fading to a warm sine, slow tremolo."""
    f = hz(m)
    t = tt(length)
    idx = 1.4 * vel * np.exp(-t * 2.5) + 0.25
    mod = np.sin(2 * np.pi * f * t) * idx
    s = np.sin(2 * np.pi * f * t + mod)
    s += 0.18 * vel * np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t * 18.0)       # the tine's ping
    env = np.minimum(1.0, t * 250.0) * np.exp(-t * 0.55)
    return s * env


def hum_voice(m, length, seed, vowel="mm"):
    """One humming voice: a breathy, nasal 'mmm' with delayed vibrato, swelling in and out.
    Built from harmonics weighted by a formant envelope (low nasal formant for 'mm', 'oo' a little brighter)."""
    r = np.random.default_rng(seed)
    f0 = hz(m)
    t = tt(length)
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * (4.8 + r.uniform(-0.3, 0.3)) * t + r.uniform(0, 6)) * np.clip(t / 2.5, 0, 1)
    drift = 1.0 + 0.0015 * np.sin(2 * np.pi * 0.13 * t + r.uniform(0, 6))
    phase = 2 * np.pi * np.cumsum(f0 * vib * drift) / SR
    formants = [(260, 90, 1.0), (1000, 300, 0.12), (2400, 400, 0.03)] if vowel == "mm" else [(330, 110, 1.0), (850, 200, 0.35), (2300, 400, 0.06)]
    s = np.zeros_like(t)
    for k in range(1, 16):
        fk = f0 * k
        if fk > 6000:
            break
        w = sum(a * math.exp(-((fk - fc) / bw) ** 2) for fc, bw, a in formants) + 0.02 / k
        s += w * np.sin(k * phase + r.uniform(0, 6))
    breath = sosfilt(butter(2, [300, 2400], btype="band", fs=SR, output="sos"), r.normal(0, 1, len(t))) * 0.05
    env = np.clip(t / 2.5, 0, 1) * np.clip((length - t) / 2.5, 0, 1)
    env *= 0.85 + 0.15 * np.sin(2 * np.pi * t / 9.0 + r.uniform(0, 6))
    return (s + breath) * env


def pad(chord, length):
    """The game's warm pad (sfx.gd _pad): detuned sines, a touch of octave, slow breathing."""
    t = tt(length)
    s = np.zeros_like(t)
    for m in chord:
        f = hz(m)
        s += np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.004 * t) + 0.18 * np.sin(2 * np.pi * f * 2 * t)
    env = np.clip(t / 1.6, 0, 1) * np.clip((length - t) / 1.6, 0, 1)
    return s * env * (0.85 + 0.15 * np.sin(2 * np.pi * t / 7.0))


# ------------------------------------------------------------------ the music

BAR = 6.0
NOTE = 1.5
# the old theme's chords (A minor - F - G - C/E) and its melody
A_CH = [[57, 64, 72], [53, 60, 69], [55, 62, 71], [52, 60, 67]]
A_MEL = [76, 74, 72, 74, 76, 79, 76, 74, 72, 69, 72, 74, 76, 74, 72, 67]
# B: the lift (F - C - G - A minor), and its new melody, reaching up and falling back
B_CH = [[53, 57, 60, 65], [48, 55, 60, 64], [55, 59, 62, 67], [57, 60, 64, 69]]
B_MEL = [72, 74, 76, 77, 79, 77, 76, 74, 76, 74, 72, 71, 72, 74, 76, 72]
# the bridge: D minor - A minor - F major 7 - E (the chord that wants to go home)
BR_CH = [[50, 57, 62, 65], [45, 57, 60, 64], [53, 57, 60, 64], [52, 56, 59, 64]]
# the end: the theme, its last note left hanging over F major 7
END_MEL = A_MEL[:15] + [71]
END_CH = A_CH[:3] + [[53, 57, 60, 64]]


def phrase_pad(start, chords, gain):
    for b, ch in enumerate(chords):
        place(pad(ch, BAR + 1.6), start + b * BAR - 0.8, 0.0, gain, 0.5)


def melody(start, notes, gain, echo=True, inst=music_box, pan=0.1, octave=0):
    for i, m in enumerate(notes):
        if m is None:
            continue
        place(inst(m + octave), start + i * NOTE + rng.uniform(-0.008, 0.008), pan, gain, 0.4)
        if echo and i % 4 == 0:
            place(music_box(m + 12), start + i * NOTE + 0.75, -pan, gain * 0.36, 0.5)


def marimba_part(start, chords, gain, density=1.0):
    """Rolling arpeggios, an octave below the melody: up through the chord and back, four to a beat-and-a-half."""
    for b, ch in enumerate(chords):
        tones = sorted(set([c - 12 for c in ch] + [ch[0], ch[1]]))
        pattern = [0, 1, 2, 3, 2, 1, 0, 2] if len(tones) >= 4 else [0, 1, 2, 1, 0, 2, 1, 2]
        for k in range(16):
            if density < 1.0 and rng.random() > density:
                continue
            m = tones[pattern[k % len(pattern)] % len(tones)]
            when = start + b * BAR + k * 0.375 + rng.uniform(-0.006, 0.006)
            vel = 0.75 + 0.25 * (k % 4 == 0)
            place(marimba(m), when, -0.35 + 0.15 * math.sin(k), gain * vel, 0.3)


def epiano_part(start, chords, gain):
    """Chords on the electric piano: on the bar, and again softly off the beat, a little behind."""
    for b, ch in enumerate(chords):
        voicing = [ch[0] - 12] + list(ch[1:]) + ([ch[1] + 12] if len(ch) < 4 else [])
        for j, m in enumerate(voicing):
            place(epiano(m, 5.5, 0.9), start + b * BAR + j * 0.025, 0.25 - 0.15 * j, gain, 0.45)
        for j, m in enumerate(voicing[1:]):
            place(epiano(m, 3.0, 0.5), start + b * BAR + 3.75 + j * 0.02, -0.2 + 0.1 * j, gain * 0.45, 0.5)


def bells(start, notes, gain, step=3.0, octave=12):
    for i, m in enumerate(notes):
        if m is not None:
            place(glass_bell(m + octave), start + i * step, rng.uniform(-0.7, 0.7), gain, 0.7)


def humming(start, chords, gain, vowel="mm"):
    """Three voices humming the chord tones, each its own slow breath."""
    for b, ch in enumerate(chords):
        for v, m in enumerate(ch[:3]):
            place(hum_voice(m, BAR + 3.0, int(start * 10) + b * 7 + v, vowel), start + b * BAR - 1.0 + v * 0.3, [-0.55, 0.0, 0.55][v], gain, 0.6)


# 0:00 intro
humming(6.0, A_CH[1:], 0.018)
bells(3.0, [76, None, None, 72, None, 74, None, None], 0.05, 3.0, 12)
# 0:24 A1: the music box alone
t0 = 24.0
phrase_pad(t0, A_CH, 0.010)
melody(t0, A_MEL, 0.11)
humming(t0, A_CH, 0.012)
# 0:48 A2: marimba
t0 = 48.0
phrase_pad(t0, A_CH, 0.010)
melody(t0, A_MEL, 0.11)
marimba_part(t0, A_CH, 0.07, 0.8)
humming(t0, A_CH, 0.013)
# 1:12 B1: the lift; electric piano
t0 = 72.0
phrase_pad(t0, B_CH, 0.010)
melody(t0, B_MEL, 0.11)
epiano_part(t0, B_CH, 0.045)
marimba_part(t0, B_CH, 0.06, 0.6)
humming(t0, B_CH, 0.016, "oo")
# 1:36 B2: bells answer
t0 = 96.0
phrase_pad(t0, B_CH, 0.011)
melody(t0, B_MEL, 0.11)
epiano_part(t0, B_CH, 0.05)
marimba_part(t0, B_CH, 0.07)
bells(t0 + 0.75, [B_MEL[i] for i in range(0, 16, 2)], 0.045, 3.0, 12)
humming(t0, B_CH, 0.018, "oo")
# 2:00 A3: everything
t0 = 120.0
phrase_pad(t0, A_CH, 0.012)
melody(t0, A_MEL, 0.12)
melody(t0, A_MEL, 0.035, False, glass_bell, -0.4, 12)
marimba_part(t0, A_CH, 0.075)
epiano_part(t0, A_CH, 0.045)
humming(t0, A_CH, 0.02, "oo")
# 2:24 bridge: thin; the melody keeps starting and not finishing
t0 = 144.0
phrase_pad(t0, BR_CH, 0.012)
epiano_part(t0, BR_CH, 0.05)
humming(t0, BR_CH, 0.022, "oo")
frag = A_MEL[:4] + [None] * 4 + A_MEL[:5] + [None] * 3
melody(t0, frag, 0.09, False)
bells(t0 + 1.5, [None, 81, None, None, 79, None, None, 76], 0.035, 3.0, 0)
# 2:48 A4: the music box alone again; the wrong last chord
t0 = 168.0
phrase_pad(t0, END_CH, 0.010)
melody(t0, END_MEL, 0.11)
humming(t0, END_CH, 0.014)
marimba_part(t0, END_CH[:2], 0.035, 0.5)
# 3:12 outro: wind, one bell, the humming fading
bells(194.0, [76], 0.05, 3.0, 12)
humming(192.0, [[53, 57, 64]], 0.012)

# ------------------------------------------------------------------ wind and leaves

def wind_and_leaves():
    n = N
    t = np.arange(n) / SR
    # gusts: slow, irregular swells
    g = np.zeros(n)
    for f, a, ph in [(0.031, 0.5, 0.0), (0.073, 0.3, 1.3), (0.17, 0.15, 2.1), (0.011, 0.6, 0.4)]:
        g += a * np.sin(2 * np.pi * f * t + ph)
    gust = np.clip(0.5 + 0.5 * g / 1.55, 0.05, 1.0)
    white = rng.normal(0, 1, (2, n))
    # the body of the wind: low and soft, its pitch rising a little with each gust
    lo = np.stack([sosfilt(butter(2, [90, 520], btype="band", fs=SR, output="sos"), white[c]) for c in range(2)])
    hi = np.stack([sosfilt(butter(2, [1200, 5200], btype="band", fs=SR, output="sos"), white[c]) for c in range(2)])
    w = lo * (0.6 * gust) + hi * (0.12 * gust ** 2)
    # leaves: little dry crackles, thicker when the wind gusts
    leaves = np.zeros((2, n))
    count = int(TOTAL * 18)
    times = np.sort(rng.uniform(0, TOTAL, count))
    grain = int(0.03 * SR)
    shape = np.exp(-np.arange(grain) / (0.004 * SR))
    hp = butter(2, 2500, btype="high", fs=SR, output="sos")
    burst = sosfilt(hp, rng.normal(0, 1, grain * 64))
    for k, tm in enumerate(times):
        i0 = int(tm * SR)
        if i0 + grain >= n or rng.random() > gust[i0] ** 1.5:
            continue
        c = k % 2
        off = rng.integers(0, len(burst) - grain)
        leaves[c, i0:i0 + grain] += burst[off:off + grain] * shape * rng.uniform(0.2, 1.0)
    env = np.clip(t / 6.0, 0, 1) * np.clip((TOTAL - t) / 5.0, 0, 1)
    return (w * 0.05 + leaves * 0.03) * env


wind = wind_and_leaves()

# ------------------------------------------------------------------ the room: a soft, long hall

def impulse(seconds, seed):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = r.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
    ir = sosfilt(butter(1, 5200, btype="low", fs=SR, output="sos"), ir)
    ir[:int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
    return ir / np.sqrt(np.sum(ir ** 2))


wet_l = fftconvolve(dry_l, impulse(4.2, 1))[:N]
wet_r = fftconvolve(dry_r, impulse(4.2, 2))[:N]
mix_l = L + wet_l * 0.9 + wind[0]
mix_r = R + wet_r * 0.9 + wind[1]
# warm it a touch, take the mud out of the low end
hp = butter(1, 45, btype="high", fs=SR, output="sos")
mix_l, mix_r = sosfilt(hp, mix_l), sosfilt(hp, mix_r)
# fade the very end, gently
fade = np.clip((TOTAL - np.arange(N) / SR) / 6.0, 0, 1)
mix_l *= fade
mix_r *= fade
# soft limit and normalise to -1 dBFS
mix = np.stack([mix_l, mix_r], 1)
mix = np.tanh(mix / (np.max(np.abs(mix)) * 0.9) * 1.2) / np.tanh(1.2)
mix *= 10 ** (-1 / 20) / np.max(np.abs(mix))

out = sys.argv[1] if len(sys.argv) > 1 else "the_place_we_remember.wav"
from scipy.io import wavfile
wavfile.write(out, SR, (mix * 32767).astype(np.int16))
print(f"wrote {out}: {TOTAL:.0f} s, {SR} Hz stereo")
