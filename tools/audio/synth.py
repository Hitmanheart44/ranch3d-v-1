"""Original, royalty-free audio for the game, synthesized on the CPU (no samples, no licenses).
python3 tools/audio/synth.py   ->  assets/audio/*.ogg
Music: Japanese pentatonic (in-scale / yo-scale) koto-like plucks (Karplus-Strong), breathy flute pads, soft drums.
Ambience: sea surf, wind, birdsong. SFX: steps, UI clicks and chimes, door, coins, summon shimmer.
"""
import os
import subprocess
import wave

import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "../../assets/audio")
rng = np.random.default_rng(7)


def save(name, x, loop_xfade=0.0):
    x = np.asarray(x, np.float64)
    if loop_xfade > 0:  # seamless loop: crossfade the tail into the head
        n = int(loop_xfade * SR)
        head, tail = x[:n].copy(), x[-n:]
        f = np.linspace(0, 1, n)
        x = x[:-n].copy()
        x[:n] = head * f + tail * (1 - f)
    x = x / max(1e-6, np.max(np.abs(x))) * 0.85
    pcm = (x * 32767).astype(np.int16)
    tmp = os.path.join(OUT, name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)
    print("saved", name, round(len(x) / SR, 1), "s")


def env(n, a=0.005, r=0.3):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t / r)


def pluck(freq, dur, bright=0.6, decay=0.996):
    """Karplus-Strong string: koto / shamisen-like."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p) * bright
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = decay * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out * env(n, 0.002, dur * 0.5)


def flute(freq, dur, vib=5.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.minimum(1, t / 0.4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = np.convolve(rng.normal(0, 1, n), np.ones(30) / 30, "same") * 0.15
    a = np.minimum(1, t / 0.25) * np.minimum(1, (dur - t) / 0.4).clip(0, 1)
    return (tone + breath) * a


def drum(dur=0.5, pitch=90.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = pitch * (1 + 2.5 * np.exp(-t * 30))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    return body + rng.normal(0, 1, n) * np.exp(-t * 60) * 0.3


def bell(freq, dur=3.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, d in [(1, 1, 1.0), (2.76, 0.5, 0.6), (5.4, 0.25, 0.35), (8.9, 0.12, 0.2)]:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (dur * d))
    return out * np.minimum(1, t / 0.003)


def mix_at(track, x, at, gain=1.0):
    i = int(at * SR)
    j = min(len(track), i + len(x))
    track[i:j] += x[: j - i] * gain


def lowpass(x, k=8):
    return np.convolve(x, np.ones(k) / k, "same")


# ---------------------------------------------------------------- music

def scale(root, kind):
    steps = {"yo": [0, 2, 5, 7, 9], "in": [0, 1, 5, 7, 8], "min": [0, 3, 5, 7, 10]}[kind]
    return [root * 2 ** ((s + 12 * o) / 12) for o in range(3) for s in steps]


def song(seconds, bpm, root, kind, seed, drums=False, bells=False, flute_gain=0.35, density=0.7):
    r = np.random.default_rng(seed)
    track = np.zeros(int((seconds + 4) * SR))
    beat = 60.0 / bpm
    notes = scale(root, kind)
    pos = 5
    t = 0.0
    phrase = []
    while t < seconds:  # melody: a stepwise walk over the scale, phrases repeat with variation
        if len(phrase) < 8:
            pos = int(np.clip(pos + r.choice([-2, -1, -1, 0, 1, 1, 2]), 2, len(notes) - 2))
            phrase.append(pos)
        else:
            phrase = phrase[4:] + [int(np.clip(p + r.choice([-1, 0, 1]), 2, len(notes) - 2)) for p in phrase[:4]]
        for p in phrase[-8:]:
            if t >= seconds:
                break
            if r.random() < density:
                mix_at(track, pluck(notes[p], beat * 2.5, bright=0.5), t, 0.55)
                if r.random() < 0.25:  # koto grace note
                    mix_at(track, pluck(notes[p + 1], beat, bright=0.35), t - 0.07, 0.25)
            t += beat * (1 if r.random() < 0.7 else 2)
    for k in range(int(seconds / (beat * 4)) + 1):  # light bass: short low plucks on the root and fifth, no drone
        mix_at(track, pluck(notes[0] / 2, beat * 1.5, bright=0.7, decay=0.99), k * beat * 4, 0.28)
        mix_at(track, pluck(notes[3] / 2, beat * 1.5, bright=0.5, decay=0.99), k * beat * 4 + beat * 2, 0.18)
    for k in range(int(seconds / (beat * 16))):  # now and then a short flute phrase answers the koto (no held tones)
        if r.random() < 0.6:
            start = k * beat * 16 + beat * 8
            p = int(r.integers(5, len(notes) - 4))
            for q in range(4):
                mix_at(track, flute(notes[p + [0, 1, 0, -1][q]], beat * 0.9), start + q * beat, flute_gain * 0.6)
    if drums:
        for k in range(int(seconds / beat)):
            if k % 4 == 0:
                mix_at(track, drum(0.6, 70), k * beat, 0.6)
            elif k % 4 == 2:
                mix_at(track, drum(0.3, 160), k * beat, 0.25)
    if bells:
        for k in range(int(seconds / (beat * 8))):
            mix_at(track, bell(notes[7 + (k % 4)], beat * 2.5), k * beat * 8 + beat * 0.5, 0.1)
    return track[: int(seconds * SR) + int(2 * SR)]


# ---------------------------------------------------------------- ambience & sfx

def surf(seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0, 1, n)
    swell = (0.55 + 0.45 * np.sin(2 * np.pi * t / 7.0) ** 2) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 17.0))
    return lowpass(noise, 40) * swell + lowpass(noise, 6) * swell ** 3 * 0.25


def wind(seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    return lowpass(rng.normal(0, 1, n), 120) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 11.0))


def birds(seconds):
    track = np.zeros(int(seconds * SR))
    t = 0.5
    while t < seconds - 1:
        f0 = rng.uniform(2500, 4200)
        for c in range(rng.integers(2, 5)):  # a little chirp phrase
            n = int(0.09 * SR)
            tt = np.arange(n) / SR
            f = f0 * (1 + 0.25 * np.sin(np.pi * tt / 0.09))
            mix_at(track, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.09), t + c * 0.13, 0.3)
        t += rng.uniform(1.5, 5.0)
    return track + wind(seconds) * 0.05


def sfx_step():
    n = int(0.12 * SR)
    return lowpass(rng.normal(0, 1, n), 25) * env(n, 0.003, 0.03)


def sfx_click():
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 1400 * t) * env(n, 0.001, 0.015)


def sfx_chime():
    b = bell(1320, 0.8)
    return bell(880, 1.0) * 0.6 + np.pad(b, (0, SR - len(b))) * 0.4


def sfx_door():
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    creak = np.sin(2 * np.pi * (180 + 60 * np.sin(2 * np.pi * 7 * t)) * t) * np.exp(-t * 4) * 0.4
    return creak + drum(0.5, 60)[:n] * 0.6


def sfx_coin():
    return bell(1600, 0.5) + np.concatenate([np.zeros(int(0.06 * SR)), bell(2100, 0.44)])[: int(0.5 * SR)]


def sfx_summon():
    n = int(4.0 * SR)
    t = np.arange(n) / SR
    rise = np.sin(2 * np.pi * np.cumsum(200 + 900 * (t / 4.0) ** 2) / SR) * (t / 4.0)
    shimmer = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) for f in [880, 1108, 1320, 1760]) * (t / 4.0) ** 3 * 0.25
    return (rise * 0.5 + shimmer + lowpass(rng.normal(0, 1, n), 4) * (t / 4.0) * 0.15)


os.makedirs(OUT, exist_ok=True)
import sys
if "sfx" in sys.argv:  # just the effects
    for k in ["step", "click", "chime", "door", "coin", "summon"]:
        save("sfx_" + k, globals()["sfx_" + k]())
    sys.exit()
save("music_ranch", song(64, 84, 220.0, "yo", 1, flute_gain=0.3, density=0.6), 2.0)
save("music_town", song(56, 112, 246.94, "yo", 2, drums=True, flute_gain=0.25, density=0.8), 2.0)
save("music_shrine", song(64, 66, 196.0, "in", 3, bells=True, flute_gain=0.4, density=0.45), 2.0)
save("music_battle", song(48, 138, 164.81, "in", 4, drums=True, flute_gain=0.2, density=0.9), 2.0)
save("music_cave", song(64, 60, 146.83, "in", 5, bells=True, flute_gain=0.5, density=0.3), 2.0)
save("amb_sea", surf(30), 2.0)
save("amb_birds", birds(30), 2.0)
save("sfx_step", sfx_step())
save("sfx_click", sfx_click())
save("sfx_chime", sfx_chime())
save("sfx_door", sfx_door())
save("sfx_coin", sfx_coin())
save("sfx_summon", sfx_summon())
