"""DREAM PROTOCOL - title theme, second version: "Somewhere We Were".

Original music. Written to sit in the same world as warm, muffled dreamcore game soundtracks: a steady gentle
pulse (92 bpm), almost no high end (everything rounded off above ~3 kHz), the weight low and warm (felt piano,
bass, pad), E major with one borrowed C major chord for the pang of something not quite right. The game's
music box carries the melody; marimba, electric piano, a choir of humming voices, glass bells and soft wind
in leaves around it. A faint tape wobble, like a memory replayed too many times. Breaths between phrases.

    python3 tools/music/compose_dream.py <out.wav>          (numpy + scipy)

Form (bar = 2.61 s):  intro 4 | A1 8 | A2 8 | B 8 | A3 8 (full) | B' 8 (thinning) | outro 4  -> ~2:08
"""
import math
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
BPM = 92.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
rng = np.random.default_rng(1992)
NN = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(n):
    return 12 * (int(n[-1]) + 1) + NN[n[:-1]]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def tt(sec):
    return np.arange(int(sec * SR)) / SR


# ------------------------------------------------------------------ the score

# chords (pad/piano voicings, bass note)
CH = {
    "Emaj7": (["E3", "B3", "D#4", "G#4"], "E2"), "G#m7": (["G#3", "B3", "D#4", "F#4"], "G#2"),
    "C#m7": (["C#4", "E4", "G#4", "B4"], "C#2"), "Amaj7": (["A3", "C#4", "E4", "G#4"], "A2"),
    "E": (["E3", "G#3", "B3", "E4"], "E2"), "B/D#": (["D#3", "F#3", "B3", "F#4"], "D#2"),
    "Cmaj7": (["C4", "E4", "G4", "B4"], "C2"), "B": (["B3", "D#4", "F#4"], "B1"),
    "Bsus": (["B3", "E4", "F#4"], "B1"), "F#m7": (["F#3", "A3", "C#4", "E4"], "F#2"),
    "A": (["A3", "C#4", "E4"], "A2"), "C": (["C4", "E4", "G4"], "C2"),
}
A_CH = ["Emaj7", "G#m7", "C#m7", "Amaj7", "E", "B/D#", "Cmaj7", "B"]
A_MEL = [("G#5", 1.5), ("F#5", .5), ("E5", 1), ("B4", 1),
         ("D#5", 1.5), ("E5", .5), ("F#5", 2),
         ("G#5", 1.5), ("F#5", .5), ("E5", 1), ("C#5", 1),
         ("E5", 3), (None, 1),
         ("G#5", 1.5), ("F#5", .5), ("E5", 1), ("B5", 1),
         ("A5", 1.5), ("G#5", .5), ("F#5", 2),
         ("G5", 2), ("E5", 1), ("D5", 1),                 # the borrowed chord: G natural, D natural
         ("D#5", 3), (None, 1)]
B_CH = ["Amaj7", "B", "G#m7", "C#m7", "F#m7", "Bsus", "Cmaj7", "Bsus"]
B_MEL = [("C#6", 1.5), ("B5", .5), ("A5", 1), ("E5", 1),
         ("D#5", 1), ("F#5", 1), ("B5", 2),
         ("B5", 1.5), ("G#5", .5), ("D#5", 1), ("E5", 1),
         ("C#5", 3), (None, 1),
         ("A5", 1.5), ("G#5", .5), ("F#5", 1), ("C#5", 1),
         ("E5", 1), ("F#5", 1), ("B5", 2),
         ("B5", 1.5), ("G5", .5), ("E5", 1), ("G5", 1),
         ("F#5", 3), (None, 1)]
OUT_CH = ["Emaj7", "Amaj7", "Cmaj7", "Cmaj7"]

SECTIONS = [  # (name, chords, melody, layers)
    ("intro", OUT_CH[:2] + ["C#m7", "B"], None, {"piano": .7, "pad": 1, "hum": .7, "bells": 1}),
    ("A1", A_CH, A_MEL, {"piano": 1, "pad": 1, "bass": .8, "box": 1, "hum": .6}),
    ("A2", A_CH, A_MEL, {"piano": 1, "pad": 1, "bass": 1, "box": 1, "marimba": .8, "ep": .5, "hum": .7}),
    ("B", B_CH, B_MEL, {"piano": 1, "pad": 1.1, "bass": 1, "box": 1, "marimba": 1, "ep": 1, "hum": 1, "bells": 1}),
    ("A3", A_CH, A_MEL, {"piano": 1.1, "pad": 1.2, "bass": 1.1, "box": 1.1, "marimba": 1, "ep": 1, "hum": 1.1, "bells": .7, "boxhi": 1}),
    ("B2", B_CH, B_MEL, {"piano": .8, "pad": 1, "bass": .6, "box": .9, "ep": .6, "hum": .9}),
    ("outro", OUT_CH, None, {"piano": .7, "pad": .9, "hum": .6, "bells": .8}),
]
BREATHS = ["A2", "B", "A3", "outro"]     # a half-second breath before these sections
GAP = 0.55

starts = []
t = 0.0
for name, chords, _, _ in SECTIONS:
    if name in BREATHS:
        t += GAP
    starts.append(t)
    t += BAR * len(chords)
TOTAL = t + 7.0
N = int(TOTAL * SR)
L, R = np.zeros(N), np.zeros(N)
dry = np.zeros((2, N))


def place(sig, at, pan=0.0, gain=1.0, verb=0.4):
    i0 = max(0, int(at * SR))
    if i0 >= N:
        return
    sig = sig[: N - i0] * gain
    lg, rg = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
    L[i0:i0 + len(sig)] += sig * lg
    R[i0:i0 + len(sig)] += sig * rg
    dry[0, i0:i0 + len(sig)] += sig * lg * verb
    dry[1, i0:i0 + len(sig)] += sig * rg * verb


# ------------------------------------------------------------------ instruments (all soft-edged)

def felt_piano(m, length=4.0, vel=1.0):
    """A felted upright: slightly stretched partials, highs dying fast, two strings a hair apart, a soft hammer."""
    f = hz(m)
    t = tt(length)
    s = np.zeros_like(t)
    for k in range(1, 7):
        fk = f * k * (1 + 0.0004 * k * k)
        amp = (0.66 ** (k - 1)) * (0.7 + 0.3 * vel)
        dec = 0.8 + 0.45 * k * (f / 300) ** 0.3
        s += amp * (np.sin(2 * np.pi * fk * t) + 0.6 * np.sin(2 * np.pi * fk * 1.0015 * t)) * np.exp(-t * dec)
    env = np.minimum(1.0, t * 90.0) ** 2
    return s * env * vel


def music_box(m, length=3.2, vel=1.0):
    f = hz(m)
    t = tt(length)
    env = np.minimum(1.0, t * 70.0) ** 2 * np.exp(-t * 1.3)
    s = np.sin(2 * np.pi * f * t) + 0.22 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3.0) + 0.08 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 6.0)
    return s * env * vel


def marimba(m, length=2.0):
    f = hz(m)
    t = tt(length)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.6) + 0.1 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 12.0)
    return s * np.minimum(1.0, t * 120.0) ** 2


def epiano(m, length=4.0, vel=1.0):
    f = hz(m)
    t = tt(length)
    idx = 0.5 * vel * np.exp(-t * 2.0) + 0.1
    s = np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * f * t) * idx) * (1.0 + 0.12 * np.sin(2 * np.pi * 3.0 * t))
    return s * np.minimum(1.0, t * 60.0) ** 2 * np.exp(-t * 0.55)


def glass_bell(m, length=6.0):
    f = hz(m)
    t = tt(length)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 0.6) + 0.15 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 1.6) + 0.2 * np.sin(2 * np.pi * f * 0.5 * t) * np.exp(-t * 0.8)
    return s * np.minimum(1.0, t * 40.0) ** 2


def bass(m, length):
    f = hz(m)
    t = tt(length)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 1.5)
    env = np.minimum(1.0, t * 30.0) * np.exp(-t * 0.35) * np.clip((length - t) / 0.3, 0, 1)
    return s * env


def pad(notes, length):
    t = tt(length)
    s = np.zeros_like(t)
    for n in notes:
        f = hz(midi(n))
        s += np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.004 * t) + 0.5 * np.sin(2 * np.pi * f * 0.997 * t + 1.0)
    env = np.clip(t / 1.0, 0, 1) * np.clip((length - t) / 1.0, 0, 1)
    return s * env * (0.85 + 0.15 * np.sin(2 * np.pi * t / 6.0))


def hum_voice(m, length, seed, vowel="mm"):
    r = np.random.default_rng(seed)
    f0 = hz(m)
    t = tt(length)
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * (4.8 + r.uniform(-0.3, 0.3)) * t + r.uniform(0, 6)) * np.clip(t / 2.0, 0, 1)
    phase = 2 * np.pi * np.cumsum(f0 * vib) / SR
    formants = [(260, 90, 1.0), (1000, 300, 0.1)] if vowel == "mm" else [(330, 110, 1.0), (850, 200, 0.3)]
    s = np.zeros_like(t)
    for k in range(1, 14):
        fk = f0 * k
        w = sum(a * math.exp(-((fk - fc) / bw) ** 2) for fc, bw, a in formants) + 0.015 / k
        s += w * np.sin(k * phase + r.uniform(0, 6))
    env = np.clip(t / 2.0, 0, 1) * np.clip((length - t) / 2.0, 0, 1)
    return s * env


# ------------------------------------------------------------------ arranging

for (name, chords, mel, lay), t0 in zip(SECTIONS, starts):
    for b, ch in enumerate(chords):
        notes, bnote = CH[ch]
        at = t0 + b * BAR
        if "pad" in lay:
            place(pad(notes, BAR + 2.0), at - 1.0 if at > 1.0 else at, 0.0, 0.006 * lay["pad"], 0.5)
        if "piano" in lay:
            # the left hand: low root on the bar; the right: the chord, softly broken across the beat, again on beat 3
            g = 0.05 * lay["piano"]
            place(felt_piano(midi(bnote) + 12, 5.0, 0.8), at, -0.15, g, 0.35)
            # the right hand: the chord broken gently on every half-beat, up and back (the pulse under it all)
            tones = [midi(n) for n in notes]
            order = [0, 1, 2, 3, 2, 1, 2, 3] if len(tones) >= 4 else [0, 1, 2, 1, 2, 1, 0, 2]
            for k in range(8):
                m = tones[order[k] % len(tones)]
                v = 0.55 if k % 2 == 0 else 0.4
                place(felt_piano(m, 3.0, v), at + k * BEAT * 0.5 + rng.uniform(-0.008, 0.008), -0.3 + 0.08 * k, g * (0.6 if k == 0 else 0.42), 0.42)
        if "bass" in lay:
            place(bass(midi(bnote), BAR * 0.98), at, 0.0, 0.07 * lay["bass"], 0.1)
            place(bass(midi(bnote), BEAT * 0.9), at + 3.5 * BEAT, 0.0, 0.03 * lay["bass"], 0.1)
        if "marimba" in lay:
            tones = sorted(midi(n) for n in notes)
            pat = [0, 2, 1, 3, 2, 1, 3, 2]
            for k in range(8):
                place(marimba(tones[pat[k] % len(tones)]), at + k * BEAT * 0.5 + rng.uniform(-0.006, 0.006), -0.4, 0.035 * lay["marimba"] * (1.0 if k % 2 == 0 else 0.7), 0.35)
        if "ep" in lay:
            for j, n in enumerate(notes):
                place(epiano(midi(n), 3.5, 0.8), at + 1.5 * BEAT + 0.03 * j, 0.35, 0.018 * lay["ep"], 0.5)
        if "hum" in lay:
            for v, n in enumerate(notes[:3]):
                place(hum_voice(midi(n), BAR + 2.5, int(at * 10) + v, "mm" if name in ("intro", "A1", "outro") else "oo"),
                      at - 0.8 + v * 0.25, [-0.55, 0.0, 0.55][v], 0.008 * lay["hum"], 0.6)
        if "bells" in lay and b % 2 == 0:
            place(glass_bell(midi(notes[-1]) + 12), at + 2.5 * BEAT, rng.uniform(-0.6, 0.6), 0.03 * lay["bells"], 0.7)
    if mel:
        at = t0
        pos = 0.0
        for note, beats in mel:
            if note is not None:
                strong = abs(pos % 4) < 1e-6
                vel = 0.8 + 0.2 * strong + rng.uniform(-0.04, 0.04)
                if "box" in lay:
                    place(music_box(midi(note), 3.2, vel), at + rng.uniform(-0.008, 0.008), 0.12, 0.07 * lay["box"], 0.5)
                if "ep" in lay and lay["ep"] >= 1.0:
                    place(epiano(midi(note) - 12, 2.5, 0.6), at, -0.2, 0.012, 0.5)
                if "boxhi" in lay and strong:
                    place(music_box(midi(note) + 12, 2.4), at + BEAT * 0.5, -0.3, 0.015, 0.6)
            at += beats * BEAT
            pos += beats

# ------------------------------------------------------------------ leaves and wind (soft)

tsec = np.arange(N) / SR
gust = np.zeros(N)
for f, a, ph in [(0.031, 0.5, 0.0), (0.073, 0.3, 1.3), (0.011, 0.6, 0.4)]:
    gust += a * np.sin(2 * np.pi * f * tsec + ph)
gust = np.clip(0.5 + 0.5 * gust / 1.4, 0.05, 1.0)
stir = np.zeros(N)
for f, a, ph in [(0.21, 0.5, 0.3), (0.37, 0.3, 1.7), (0.09, 0.6, 2.9)]:
    stir += a * np.sin(2 * np.pi * f * tsec + ph)
stir = np.clip(0.5 + 0.5 * stir / 1.4, 0, 1) ** 2 * gust
wind = np.stack([sosfilt(butter(2, [90, 450], btype="band", fs=SR, output="sos"), rng.normal(0, 1, N)) * gust * 0.6
                 + sosfilt(butter(2, [700, 2200], btype="band", fs=SR, output="sos"), rng.normal(0, 1, N)) * stir for _ in range(2)])
wind *= 0.03 * np.clip(tsec / 5.0, 0, 1) * np.clip((TOTAL - tsec) / 5.0, 0, 1)

# ------------------------------------------------------------------ room, breaths, tape, master

def impulse(seconds, seed):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    ti = np.arange(n) / SR
    ir = r.normal(0, 1, n) * np.exp(-ti * 6.9 / seconds)
    ir = sosfilt(butter(1, 3500, btype="low", fs=SR, output="sos"), ir)
    return ir / np.sqrt(np.sum(ir ** 2))


wet = np.stack([fftconvolve(dry[c], impulse(3.8, c + 1))[:N] for c in range(2)])
hold, room, air = np.ones(N), np.ones(N), np.ones(N)
for (name, *_), t0 in zip(SECTIONS, starts):
    if name not in BREATHS:
        continue
    a = t0 - GAP
    fo = np.clip((tsec - (a - 0.18)) / 0.18, 0, 1)
    bi = np.clip((tsec - (t0 - 0.02)) / 0.04, 0, 1)
    inside = (tsec > a - 0.18) & (tsec < t0 + 0.02)
    k = (1 - fo[inside]) + bi[inside]
    hold[inside] = np.minimum(hold[inside], k)
    room[inside] = np.minimum(room[inside], 0.15 + 0.85 * k)
    air[inside] = np.minimum(air[inside], 0.55 + 0.45 * k)
mix = np.stack([L * hold + wet[0] * 0.85 * room + wind[0] * air, R * hold + wet[1] * 0.85 * room + wind[1] * air])
# tape: a slow, faint wobble in pitch (read the mix through a gently wandering clock)
wow = 0.0016 * np.sin(2 * np.pi * 0.42 * tsec) + 0.0007 * np.sin(2 * np.pi * 1.3 * tsec + 1.1)
src = np.clip(tsec * SR + np.cumsum(wow) , 0, N - 1)
mix = np.stack([np.interp(src, np.arange(N), mix[c]) for c in range(2)])
# warm and muffled: everything rounded off above ~4.5 kHz, a little low-end weight, no rumble
for c in range(2):
    mix[c] = sosfilt(butter(1, 35, btype="high", fs=SR, output="sos"), mix[c])
    mix[c] = sosfilt(butter(2, 4500, btype="low", fs=SR, output="sos"), mix[c])
fade = np.clip((TOTAL - tsec) / 6.0, 0, 1) * np.clip(tsec / 1.5, 0, 1)
mix *= fade
mix *= 10 ** (-3 / 20) / np.max(np.abs(mix))
out = sys.argv[1] if len(sys.argv) > 1 else "somewhere_we_were.wav"
wavfile.write(out, SR, (mix.T * 32767).astype(np.int16))
print(f"wrote {out}: {TOTAL:.0f} s")
