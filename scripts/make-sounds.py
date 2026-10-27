#!/usr/bin/env python3
"""Synthesises every sound in Apps/iOS/Sounds from code (numpy only).

Nothing here is sampled or downloaded, so the files are our own work.
Run `make sounds` (needs numpy) and commit the results.
Plan and the list of cues: energy-bank/03 Product/音效与家的音乐 v0.md.
"""

import os
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


def write_wav(name, x, rate=RATE):
    path = os.path.join(OUT, name + ".wav")
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
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


# 家 music: a slow, chill jazz loop (Mike 10/27: 「jazz 风格一点，chill 一点」). F major, 64 BPM swing,
# 16 bars of a ii-V-I turn played twice, ends where it starts.

BPM = 64
BEAT = 60 / BPM
BARS = 16


def swung(beat):
    """Moves an off-beat eighth to the last third of its beat."""
    whole = np.floor(beat)
    return whole + 2 / 3 if abs(beat - whole - 0.5) < 1e-6 else beat


def rhodes(freq, seconds):
    t = t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / 0.3)
    tone += 0.06 * np.sin(2 * np.pi * freq * 7.1 * t) * np.exp(-t / 0.02)
    tone *= 1 + 0.1 * np.sin(2 * np.pi * 3.6 * t)
    release = np.clip((seconds - t) / 0.2, 0, 1)
    return tone * env(t, 0.008, 1.4) * release


def upright(freq, seconds):
    """Plucked double bass: a thump into a round, dying note."""
    t = t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / 0.15)
    tone += 0.12 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t / 0.06)
    release = np.clip((seconds - t) / 0.08, 0, 1)
    return tone * env(t, 0.006, 0.7) * release


def vibes(freq, seconds=1.8):
    t = t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.15 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.05)
    tone *= 1 + 0.25 * np.sin(2 * np.pi * 5.0 * t)
    return tone * env(t, 0.004, 0.7)


def brush(seconds=0.32):
    """A brush swept across the snare."""
    t = t_axis(seconds)
    swish = bandpass(rng.standard_normal(len(t)), 900, 5000)
    return swish * np.sin(np.pi * t / seconds) ** 2 * np.exp(-t / 0.25)


def ride(seconds=0.9):
    t = t_axis(seconds)
    ping = np.zeros_like(t)
    for ratio, level in ((1.0, 1.0), (1.48, 0.7), (2.13, 0.5), (2.89, 0.35)):
        ping += level * np.sin(2 * np.pi * 3200 * ratio * t + rng.uniform(0, 6.28))
    wash = bandpass(rng.standard_normal(len(t)), 5000, 11000)
    return (0.4 * ping + wash) * env(t, 0.001, 0.25)


def music():
    # Even, so halving the rate keeps every sample.
    length = int(BARS * 4 * BEAT * RATE) // 2 * 2
    out = np.zeros(length + RATE * 6)

    def add(start_beats, sig, gain):
        i = int(swung(start_beats) * BEAT * RATE)
        out[i:i + len(sig)] += gain * sig

    # (bass line as (beat, note), rootless voicing). Two bars of ii-V, then home, then a turn back.
    bars = [
        ([(0, "G2"), (2, "D2"), (3.5, "Gb2")], ["F3", "Bb3", "D4", "A4"]),  # Gm9
        ([(0, "C2"), (2, "G2"), (3, "E2")], ["E3", "Bb3", "D4", "A4"]),  # C13
        ([(0, "F2"), (2, "C3"), (3.5, "A2")], ["E3", "A3", "C4", "G4"]),  # Fmaj9
        ([(0, "D2"), (2, "A2"), (3.5, "C3")], ["F3", "C4", "E4", "A4"]),  # Dm9
        ([(0, "Bb1"), (2, "F2"), (3, "Bb2")], ["A3", "D4", "F4", "C5"]),  # Bbmaj9
        ([(0, "A1"), (2, "E2"), (3.5, "G2")], ["G3", "C#4", "F4", "Bb4"]),  # A7(b9 b13)
        ([(0, "D2"), (2, "A2"), (3, "F2")], ["F3", "C4", "E4", "A4"]),  # Dm9
        ([(0, "D2"), (2, "F#2"), (3.5, "Ab2")], ["F#3", "C4", "Eb4", "A4"]),  # D7(b9) back to Gm9
    ]
    # Comping hits: (beat, length in beats); a lazy anticipation on the and of 2 every other bar.
    comp = [[(0, 1.6), (2.5, 1.2)], [(0.5, 1.2), (3, 0.9)]]
    for bar in range(BARS):
        line, voicing = bars[bar % 8]
        beat0 = bar * 4
        for beat, n in line:
            add(beat0 + beat, upright(note(n), 1.9 * BEAT), 0.36)
        for beat, hold in comp[bar % 2]:
            for k, n in enumerate(voicing):
                add(beat0 + beat + 0.012 * k, rhodes(note(n), hold * BEAT), 0.085)
        # Ride: ding, ding-a, ding, ding-a. Brushes on 2 and 4.
        for beat, level in ((0, 1.0), (1, 0.8), (1.5, 0.5), (2, 1.0), (3, 0.8), (3.5, 0.5)):
            add(beat0 + beat, ride(), 0.012 * level)
        for beat in (1, 3):
            add(beat0 + beat - 0.1, brush(), 0.05)

    # Vibes: a short, lazy phrase every two bars, answered by silence.
    phrase_a = [(0.5, "A4"), (1, "C5"), (1.5, "D5"), (2, "F5"), (3.5, "E5"), (5, "D5")]
    phrase_b = [(0.5, "G4"), (1, "A4"), (2, "C5"), (2.5, "E5"), (4, "D5"), (5.5, "A4")]
    phrase_c = [(1, "F5"), (1.5, "E5"), (2, "D5"), (2.5, "C5"), (3, "A4"), (4.5, "Bb4"), (5, "A4")]
    for start, phrase in ((0, phrase_a), (8, phrase_b), (16, phrase_a), (24, phrase_c),
                          (32, phrase_b), (40, phrase_a), (48, phrase_c), (56, phrase_b[:4])):
        for beat, n in phrase:
            add(start + beat, vibes(note(n)), 0.16)

    # A little record crackle, very low, for the lo-fi feel.
    for _ in range(int(BARS * 4 * BEAT * 6)):
        i = rng.integers(0, length)
        click = rng.standard_normal(40) * np.hanning(40)
        out[i:i + 40] += 0.04 * rng.uniform(0.2, 1.0) * click

    wet = room(out, seconds=2.0, mix=0.4, brightness=3500)
    # Wrap everything past the loop point back to the start, so the loop has no seam.
    loop = wet[:length].copy()
    tail = wet[length:]
    loop[: len(tail)] += tail[: length]
    # Low-pass at 7 kHz and halve the rate in the frequency domain, which treats the loop as a circle: no seam.
    spectrum = np.fft.rfft(loop)
    freqs = np.fft.rfftfreq(length, 1 / RATE)
    spectrum *= 1 / (1 + (freqs / 7000) ** 4)
    loop = np.fft.irfft(spectrum[: length // 4 + 1], length // 2) / 2
    loop = loop / np.abs(loop).max() * 10 ** (-6 / 20)
    # Plain 16-bit PCM: IMA4 starts its first packet from silence and AAC pads, and both leave a click at the loop point.
    print(write_wav("home-loop", loop, RATE // 2))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["effects", "music"]
    if "effects" in which:
        effects()
    if "music" in which:
        music()
