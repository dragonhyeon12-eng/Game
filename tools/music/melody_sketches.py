"""Ten original candidate melodies for the DREAM PROTOCOL title theme, each on the (softened) music box over
a soft pad, played twice (plain, then with a quiet octave echo). One file each, and a reel of all ten.

    python3 tools/music/melody_sketches.py <outdir>            (numpy + scipy)
"""
import math
import os
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8,
         "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(n):
    """'A5' -> 81."""
    name, octave = n[:-1], int(n[-1])
    return 12 * (octave + 1) + NAMES[name]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


CHORDS = {   # pad voicings (root, third, fifth, around the octave below middle C .. middle C)
    "Am": ["A3", "C4", "E4"], "C": ["C4", "E4", "G4"], "Dm": ["D4", "F4", "A4"], "Em": ["E3", "G3", "B3"],
    "E": ["E3", "G#3", "B3"], "F": ["F3", "A3", "C4"], "G": ["G3", "B3", "D4"], "Bb": ["Bb3", "D4", "F4"],
    "D": ["D4", "F#4", "A4"], "A": ["A3", "C#4", "E4"], "Gm": ["G3", "Bb3", "D4"], "Cm": ["C4", "Eb4", "G4"],
    "Fm": ["F3", "Ab3", "C4"], "Ab": ["Ab3", "C4", "Eb4"], "Eb": ["Eb4", "G4", "Bb4"], "Bm": ["B3", "D4", "F#4"],
    "C/E": ["E3", "G3", "C4"], "Fmaj7": ["F3", "A3", "C4", "E4"], "Esus": ["E3", "A3", "B3"], "G7": ["G3", "B3", "F4"],
    "Gsus": ["G3", "C4", "D4"], "A7": ["A3", "C#4", "G4"], "D/F#": ["F#3", "A3", "D4"],
}

# name, bpm, beats per bar, melody [(note or None, beats)], one chord per bar
MELODIES = [
    ("01 Lullaby for Nowhere", 66, 3,
     [("E5", 1), ("A5", 2), ("G5", 1), ("E5", 2), ("D5", 1), ("E5", 1), ("C5", 1), ("B4", 3),
      ("E5", 1), ("A5", 2), ("B5", 1), ("C6", 2), ("B5", 1), ("G5", 1), ("E5", 1), ("A5", 3)],
     ["Am", "C", "F", "E", "Am", "C", "Em", "Am"]),
    ("02 Seven Steps Home", 72, 4,
     [("C5", .5), ("G5", .5), ("F#5", .5), ("G5", 1.5), ("E5", 1), ("D5", .5), ("E5", .5), ("C5", 3),
      ("C5", .5), ("G5", .5), ("F#5", .5), ("G5", 1.5), ("A5", 1), ("B5", .5), ("A5", .5), ("G5", 3),
      ("A5", 1), ("G5", .5), ("E5", .5), ("G5", 2), ("F#5", 1), ("E5", .5), ("D5", .5), ("E5", 2),
      ("C5", .5), ("G5", .5), ("F#5", .5), ("G5", 1.5), ("E5", 1), ("D5", 1), ("C5", 3)],
     ["C", "C", "C", "G", "F", "D/F#", "C", "C"]),
    ("03 Window Light", 60, 3,
     [("A5", 1.5), ("F5", .5), ("D5", 1), ("Bb5", 2), ("A5", 1), ("G5", 1.5), ("E5", .5), ("C#5", 1), ("D5", 3),
      ("A5", 1.5), ("F5", .5), ("D5", 1), ("D6", 2), ("C6", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("A5", 3)],
     ["Dm", "Bb", "A", "Dm", "Dm", "Bb", "Gm", "A"]),
    ("04 The Swing", 76, 3,
     [("B5", 1), ("E5", 1), ("B5", 1), ("A5", 1), ("E5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("F#5", 1), ("G5", 2), ("B4", 1),
      ("B5", 1), ("E5", 1), ("B5", 1), ("C6", 1), ("E5", 1), ("C6", 1), ("B5", 1), ("A5", 1), ("F#5", 1), ("E5", 3)],
     ["Em", "Am", "C", "G", "Em", "C", "Bm", "Em"]),
    ("05 Postcard", 70, 4,
     [("C5", 1.5), ("F5", .5), ("A5", 1), ("G5", 1), ("F5", 1.5), ("D5", .5), ("C5", 2),
      ("C5", 1.5), ("F5", .5), ("A5", 1), ("C6", 1), ("Bb5", 1.5), ("A5", .5), ("G5", 2),
      ("A5", 1.5), ("Bb5", .5), ("C6", 1), ("A5", 1), ("G5", 1.5), ("F5", .5), ("D5", 2),
      ("C5", 1), ("F5", 1), ("G5", 1), ("E5", 1), ("F5", 4)],
     ["F", "Bb", "F", "C", "F", "Gm", "C", "F"]),
    ("06 Echo Corridor", 72, 4,
     [("A5", .5), ("C6", .5), ("B5", .5), ("E5", 2.5), ("A4", .5), ("C5", .5), ("B4", .5), ("E4", 2.5),
      ("A5", .5), ("C6", .5), ("D6", .5), ("E6", 1.5), ("D6", 1), ("C6", 1), ("B5", 1), ("A5", 2),
      ("F5", .5), ("A5", .5), ("G5", .5), ("C5", 2.5), ("F4", .5), ("A4", .5), ("G4", .5), ("C4", 2.5),
      ("D5", .5), ("E5", .5), ("F5", .5), ("E5", 1.5), ("D5", 1), ("E5", 4)],
     ["Am", "Am", "Am", "F", "F", "C", "Dm", "E"]),
    ("07 Three Notes", 68, 4,
     [("E5", 1), ("D5", 1), ("A4", 2), ("E5", 1), ("D5", 1), ("B4", 2), ("E5", 1), ("D5", 1), ("C5", 1), ("D5", 1), ("E5", 4),
      ("E5", 1), ("D5", 1), ("A4", 2), ("G5", 1), ("E5", 1), ("D5", 2), ("C5", 1), ("B4", 1), ("G4", 1), ("B4", 1), ("A4", 4)],
     ["Am", "G", "F", "Am", "Am", "C", "G", "Am"]),
    ("08 Paper Boat", 80, 3,
     [("D5", .5), ("G5", .5), ("B5", 1), ("A5", 1), ("G5", 1), ("D5", 2), ("E5", .5), ("G5", .5), ("C6", 1), ("B5", 1), ("A5", 3),
      ("D5", .5), ("G5", .5), ("B5", 1), ("D6", 1), ("C6", 1), ("B5", .5), ("A5", .5), ("G5", 1), ("E5", 1), ("F#5", 1), ("A5", 1), ("G5", 3)],
     ["G", "G", "C", "D", "G", "C", "A7", "G"]),
    ("09 Before the Bell", 64, 4,
     [("G4", 1), ("C5", 1), ("Eb5", 1), ("D5", 1), ("C5", 1), ("G5", 3), ("Ab5", 1), ("G5", 1), ("F5", 1), ("Eb5", 1), ("D5", 4),
      ("G4", 1), ("C5", 1), ("Eb5", 1), ("G5", 1), ("C6", 2), ("B5", 2), ("Ab5", 1), ("F5", 1), ("D5", 1), ("B4", 1), ("C5", 4)],
     ["Cm", "Cm", "Fm", "G", "Cm", "Ab", "Fm", "Cm"]),
    ("10 Somewhere Warm", 62, 4,
     [("F#5", 2), ("A5", 1), ("D6", 1), ("C#6", 2), ("A5", 2), ("B5", 1.5), ("A5", .5), ("G5", 1), ("F#5", 1), ("E5", 4),
      ("F#5", 2), ("A5", 1), ("D6", 1), ("E6", 2), ("D6", 1), ("Bb5", 1), ("A5", 1.5), ("G5", .5), ("F#5", 1), ("E5", 1), ("D5", 4)],
     ["D", "A", "G", "A", "D", "Gm", "D", "D"]),
]


def tt(sec):
    return np.arange(int(sec * SR)) / SR


def music_box(m, length=3.2, vel=1.0):
    f = hz(m)
    t = tt(length)
    env = np.minimum(1.0, t * 70.0) ** 2 * np.exp(-t * 1.3)
    s = np.sin(2 * np.pi * f * t) + 0.12 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3.5) + 0.04 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 7.0)
    return s * env * vel


def pad(notes, length):
    t = tt(length)
    s = np.zeros_like(t)
    for n in notes:
        f = hz(midi(n))
        s += np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.004 * t) + 0.15 * np.sin(2 * np.pi * f * 2 * t)
    env = np.clip(t / 1.2, 0, 1) * np.clip((length - t) / 1.2, 0, 1)
    return s * env


def impulse(seconds, seed):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = r.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
    ir = sosfilt(butter(1, 5000, btype="low", fs=SR, output="sos"), ir)
    return ir / np.sqrt(np.sum(ir ** 2))


def render(spec):
    name, bpm, per_bar, notes, chords = spec
    beat = 60.0 / bpm
    bar = beat * per_bar
    phrase = bar * len(chords)
    total = phrase * 2 + 4.0
    n = int(total * SR)
    L, R, dry = np.zeros(n), np.zeros(n), np.zeros((2, n))
    rng = np.random.default_rng(hash(name) & 0xffff)

    def add(sig, at, pan, gain, verb=0.45):
        i0 = max(0, int(at * SR))
        sig = sig[: n - i0] * gain
        lg, rg = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
        L[i0:i0 + len(sig)] += sig * lg
        R[i0:i0 + len(sig)] += sig * rg
        dry[0, i0:i0 + len(sig)] += sig * lg * verb
        dry[1, i0:i0 + len(sig)] += sig * rg * verb

    for rep in range(2):
        t0 = rep * phrase
        for b, ch in enumerate(chords):
            add(pad(CHORDS[ch], bar + 1.2), t0 + b * bar - 0.6 if b or rep else 0.0, 0.0, 0.012, 0.5)
        at = t0
        beat_pos = 0.0
        for note, beats in notes:
            if note is not None:
                strong = abs(beat_pos % per_bar) < 1e-6
                vel = 0.85 + 0.15 * strong + rng.uniform(-0.04, 0.04)
                add(music_box(midi(note), 3.2, vel), at + rng.uniform(-0.008, 0.008), 0.1, 0.09)
                if rep == 1 and strong:
                    add(music_box(midi(note) + 12, 2.5), at + beat * 0.5, -0.3, 0.018, 0.6)
            at += beats * beat
            beat_pos += beats
    wet = np.stack([fftconvolve(dry[c], impulse(3.2, c + 1))[:n] for c in range(2)])
    mix = np.stack([L + wet[0] * 0.8, R + wet[1] * 0.8], 1)
    lp = butter(2, 5500, btype="low", fs=SR, output="sos")
    hp = butter(1, 45, btype="high", fs=SR, output="sos")
    mix = np.stack([sosfilt(lp, sosfilt(hp, mix[:, c])) for c in range(2)], 1)
    fade = np.clip((total - np.arange(n) / SR) / 3.0, 0, 1)[:, None]
    mix = mix * fade
    mix *= 10 ** (-3 / 20) / np.max(np.abs(mix))
    return mix


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "melodies"
    os.makedirs(out, exist_ok=True)
    reel = []
    for spec in MELODIES:
        mix = render(spec)
        fn = os.path.join(out, spec[0].replace(" ", "_").lower() + ".wav")
        wavfile.write(fn, SR, (mix * 32767).astype(np.int16))
        print(f"wrote {fn} ({len(mix) / SR:.0f} s)")
        reel.append(mix)
        reel.append(np.zeros((int(2.0 * SR), 2)))
    wavfile.write(os.path.join(out, "all_ten.wav"), SR, (np.concatenate(reel) * 32767).astype(np.int16))


if __name__ == "__main__":
    main()
