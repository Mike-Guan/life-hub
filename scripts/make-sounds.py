#!/usr/bin/env python3
"""Synthesises every sound in Apps/iOS/Sounds from code (numpy only).

Nothing here is sampled or downloaded, so the files are our own work.
Run `make sounds` (needs numpy and ffmpeg) and commit the results.
Plan and the list of cues: energy-bank/03 Product/音效与家的音乐 v0.md.
"""

import os
import subprocess
import sys
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Apps", "iOS", "Sounds")
rng = np.random.default_rng(7)


def note(name):
    """Frequency of a note name such as 'A4' or 'F#3'."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = steps[name[0]] + name.count("#") - name.count("b")
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(t, attack, decay):
    """A short linear attack, then an exponential decay with time constant `decay`."""
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def fftconvolve(x, ir):
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def lowpass(x, cutoff):
    """Two one-pole low-passes in a row, as one FFT convolution."""
    k = np.exp(-2 * np.pi * cutoff / RATE)
    taps = (1 - k) * k ** np.arange(int(8 / (1 - k)) + 1)
    return fftconvolve(x, np.convolve(taps, taps))[: len(x)]


def bandpass(x, low, high):
    return lowpass(x, high) - lowpass(x, low)


def marimba(freq, seconds=0.9, bright=1.0):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t) * env(t, 0.002, 0.28)
    body += 0.22 * bright * np.sin(2 * np.pi * freq * 3.93 * t) * env(t, 0.001, 0.05)
    body += 0.06 * bright * np.sin(2 * np.pi * freq * 9.2 * t) * env(t, 0.001, 0.015)
    click = bandpass(rng.standard_normal(len(t)), 900, 4000) * env(t, 0.0005, 0.004) * 0.25
    return body + click


def kalimba(freq, seconds=1.2):
    t = t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) * env(t, 0.002, 0.45)
    tone += 0.18 * np.sin(2 * np.pi * freq * 5.95 * t) * env(t, 0.001, 0.03)
    tone += 0.08 * np.sin(2 * np.pi * freq * 2.0 * t) * env(t, 0.002, 0.2)
    return tone


def woodblock(freq, seconds=0.18):
    t = t_axis(seconds)
    sweep = freq * (1 + 0.15 * np.exp(-t / 0.01))
    phase = 2 * np.pi * np.cumsum(sweep) / RATE
    tone = np.sin(phase) * env(t, 0.0005, 0.03)
    tone += 0.5 * bandpass(rng.standard_normal(len(t)), freq * 0.8, freq * 2.5) * env(t, 0.0005, 0.008)
    return tone


def thump(seconds=0.35):
    t = t_axis(seconds)
    sweep = 55 + 70 * np.exp(-t / 0.03)
    phase = 2 * np.pi * np.cumsum(sweep) / RATE
    tone = np.sin(phase) * env(t, 0.002, 0.09)
    tone += 0.35 * lowpass(rng.standard_normal(len(t)), 2500) * env(t, 0.0005, 0.012)
    return tone


def clink(freq, seconds=0.5):
    """A light metal tap, like two cans touching."""
    t = t_axis(seconds)
    tone = np.zeros_like(t)
    for ratio, level, decay in ((1.0, 1.0, 0.09), (2.76, 0.5, 0.05), (5.40, 0.3, 0.03), (8.93, 0.15, 0.02)):
        tone += level * np.sin(2 * np.pi * freq * ratio * t) * env(t, 0.0005, decay)
    return tone


def rustle(seconds, density=60):
    """Paper or cardboard: short filtered noise grains."""
    n = int(seconds * RATE)
    out = np.zeros(n)
    for _ in range(int(seconds * density)):
        start = rng.integers(0, n - 2000)
        length = rng.integers(300, 2000)
        grain = rng.standard_normal(length) * np.hanning(length) * rng.uniform(0.2, 1.0)
        out[start:start + length] += grain
    out = bandpass(out, 1200, 6000)
    shape = np.sin(np.pi * np.linspace(0, 1, n)) ** 0.7
    return out * shape


def room(x, seconds=0.6, mix=0.18, brightness=4000):
    """Small soft room: convolution with decaying filtered noise."""
    t = t_axis(seconds)
    ir = lowpass(rng.standard_normal(len(t)), brightness) * np.exp(-t / (seconds / 5))
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(ir) - 1)])
    return dry + mix * wet


def place(parts, seconds):
    """Mixes (start_seconds, signal, gain) parts into one buffer."""
    out = np.zeros(int(seconds * RATE))
    for start, sig, gain in parts:
        i = int(start * RATE)
        end = min(len(out), i + len(sig))
        out[i:end] += gain * sig[: end - i]
    return out


def finish(x, peak_db):
    """Trims trailing silence, fades the tail, normalises to `peak_db` dBFS."""
    level = np.abs(x)
    last = np.nonzero(level > 1e-3 * level.max())[0][-1]
    x = x[: last + 1]
    fade = min(len(x), int(0.02 * RATE))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / np.abs(x).max() * 10 ** (peak_db / 20)


def write_wav(name, x):
    path = os.path.join(OUT, name + ".wav")
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    return path


# Effects. HAKU is a deadpan roommate: wood and soft tines, short, quiet, never a fanfare.

def effects():
    fx = {}
    # 上班: two dry wood knocks, the second higher. "OK, on it."
    fx["mode-work"] = finish(room(place([(0, woodblock(880), 1), (0.09, woodblock(1175), 0.9)], 0.4)), -4)
    # 下班: two soft marimba notes falling a fourth. Shoulders down.
    fx["mode-chill"] = finish(room(place([(0, marimba(note("C5")), 0.9), (0.11, marimba(note("G4")), 1)], 1.2), mix=0.25), -5)
    # 副业: three quick kalimba notes rising. Something of your own.
    fx["mode-money"] = finish(room(place(
        [(0, kalimba(note("D5")), 0.8), (0.07, kalimba(note("F5")), 0.8), (0.14, kalimba(note("A5")), 0.9)], 1.4)), -5)
    # Identity card (boxing, tennis, gym…): a padded thump and one knock.
    fx["mode-card"] = finish(room(place([(0, thump(), 1), (0.06, woodblock(660), 0.35)], 0.5), mix=0.12), -3)
    # A tap that changes nothing (the card already on, a tab, a close button).
    fx["tap"] = finish(woodblock(1400, 0.08), -10)
    # Spending cans in the shop: two cans touch.
    fx["buy"] = finish(room(place([(0, clink(1480), 1), (0.075, clink(1975), 0.7)], 0.7), mix=0.2), -6)
    # Unboxing: a cardboard rustle, then three low notes. Pleased, not thrilled.
    box = rustle(0.45)
    tune = place([(0, marimba(note("F4")), 0.8), (0.12, marimba(note("A4")), 0.8), (0.24, marimba(note("C5")), 1)], 1.3)
    fx["unbox"] = finish(room(place([(0, box, 0.35), (0.35, tune, 1)], 1.8), mix=0.22), -5)
    # Entering 家: a door latch and one tine.
    latch = place([(0, woodblock(520, 0.12), 1), (0.05, woodblock(760, 0.1), 0.6)], 0.2)
    fx["home-open"] = finish(room(place([(0, latch, 1), (0.16, kalimba(note("F5")), 0.55)], 1.3), mix=0.3), -7)
    # Placing a room item in 家.
    fx["place"] = finish(room(place([(0, woodblock(330, 0.15), 1), (0.02, thump(0.2), 0.3)], 0.3)), -7)
    for name, x in fx.items():
        print(write_wav(name, x))


# 家 music: a slow, warm loop. F major, 70 BPM, 16 bars, ends where it starts.

BPM = 70
BEAT = 60 / BPM
BARS = 16


def rhodes(freq, seconds):
    t = t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / 0.4)
    tone *= 1 + 0.12 * np.sin(2 * np.pi * 4.2 * t)
    shape = env(t, 0.012, 1.6)
    release = np.clip((seconds - t) / 0.25, 0, 1)
    return tone * shape * release


def bass(freq, seconds):
    t = t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.1 * np.sin(2 * np.pi * freq * 2 * t)
    release = np.clip((seconds - t) / 0.15, 0, 1)
    return tone * env(t, 0.02, 1.2) * release


def music():
    length = int(BARS * 4 * BEAT * RATE)
    out = np.zeros(length + RATE * 6)

    def add(start_beats, sig, gain):
        i = int(start_beats * BEAT * RATE)
        out[i:i + len(sig)] += gain * sig

    chords = [
        ("F2", ["A3", "C4", "E4"]),  # Fmaj7
        ("A2", ["G3", "C4", "E4"]),  # Am7
        ("D2", ["F3", "A3", "C4"]),  # Dm7
        ("Bb1", ["F3", "A3", "D4"]),  # Bbmaj7
    ]
    for bar in range(BARS):
        root, voicing = chords[bar % 4]
        beat0 = bar * 4
        add(beat0, bass(note(root), 3.6 * BEAT), 0.32)
        add(beat0 + 2.5, bass(note(root) * 1.5, 1.2 * BEAT), 0.12)
        for k, n in enumerate(voicing):
            add(beat0 + 0.03 * k, rhodes(note(n), 3.8 * BEAT), 0.13)
        # Off-beat soft shaker, the room ticking along.
        for b in range(4):
            shake = lowpass(rng.standard_normal(int(0.07 * RATE)), 7000) - lowpass(rng.standard_normal(int(0.07 * RATE)), 3000)
            shake *= np.hanning(len(shake))
            add(beat0 + b + 0.5, shake, 0.025)

    # Kalimba line: sparse, with rests. Two phrases, each played twice with a change.
    phrase_a = [(0, "C5"), (1.5, "A4"), (2, "G4"), (4, "E5"), (5, "C5"), (8, "D5"), (9.5, "C5"), (10, "A4"),
                (12, "F4"), (13.5, "G4")]
    phrase_b = [(0, "A4"), (1, "C5"), (2, "F5"), (4.5, "E5"), (5, "C5"), (8, "D5"), (9, "F5"), (10, "A4"),
                (12, "C5"), (14, "A4")]
    for start, phrase in ((0, phrase_a), (16, phrase_b), (32, phrase_a[:-1] + [(13.5, "E4")]), (48, phrase_b[:8])):
        for beat, n in phrase:
            add(start + beat, kalimba(note(n), 1.6), 0.22)

    wet = room(out, seconds=2.4, mix=0.5, brightness=3000)
    # Wrap everything past the loop point back to the start, so the loop has no seam.
    loop = wet[:length].copy()
    tail = wet[length:]
    loop[: len(tail)] += tail[: length]
    loop = lowpass(loop, 6000)
    loop = loop / np.abs(loop).max() * 10 ** (-6 / 20)
    wav = write_wav("home-loop", loop)
    # IMA4 in CAF has no encoder padding (AAC does), so the loop stays seamless. 22 kHz is enough after the 6 kHz low-pass.
    caf = os.path.join(OUT, "home-loop.caf")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ar", "22050", "-c:a", "adpcm_ima_qt", caf], check=True
    )
    os.remove(wav)
    print(caf)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["effects", "music"]
    if "effects" in which:
        effects()
    if "music" in which:
        music()
