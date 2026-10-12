#!/usr/bin/env python3
"""Richer, varied sound effects (CPU synthesis, original, no licences). python3 tools/audio/sfx_pack.py [name...]
Numbered variants (sfx_hit_1.ogg ...) are picked at random by Sound.sfx("hit")."""
import os, subprocess, sys, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "../../assets/audio")
rng = np.random.default_rng(11)
T = lambda d: np.arange(int(d * SR)) / SR


def fit(a, b):  # add two arrays of different length
    n = max(len(a), len(b))
    return np.pad(a, (0, n - len(a))) + np.pad(b, (0, n - len(b)))


def lp(x, hz):  # one-pole low-pass
    a = np.exp(-2 * np.pi * hz / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = a * acc + (1 - a) * v
        y[i] = acc
    return y


def hp(x, hz):
    return x - lp(x, hz)


def env(t, a, d):
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)


def tone(f, d, dec=0.15, harm=(1, 0.4, 0.2)):
    t = T(d)
    return sum(h * np.sin(2 * np.pi * f * (i + 1) * t) for i, h in enumerate(harm)) * env(t, 0.003, dec)


def noise(d):
    return rng.normal(0, 1, int(d * SR))


def thump(f0=120, f1=40, d=0.25):
    t = T(d)
    return np.sin(2 * np.pi * np.cumsum(f0 * (f1 / f0) ** (t / d)) / SR) * env(t, 0.002, d / 3)


def save(name, x):
    x = np.asarray(x, float)
    x = np.nan_to_num(x)
    x = x / max(1e-6, np.abs(x).max()) * 0.8
    tmp = os.path.join(OUT, name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def hit(i):
    f = 150 + i * 25
    n = noise(0.14)
    return fit(thump(f * 1.6, 55, 0.18) * 0.9, lp(n, 3500 - i * 300) * env(T(0.14), 0.001, 0.03) * 0.7)


def hit_heavy():
    return fit(thump(110, 30, 0.45), lp(noise(0.3), 1800) * env(T(0.3), 0.001, 0.09) * 0.8)


def whoosh(d=0.3, up=True):
    n = noise(d)
    t = T(d)
    cut = np.linspace(500, 5000, len(t)) if up else np.linspace(5000, 500, len(t))
    y = np.zeros_like(n)
    acc = 0.0
    for i in range(len(n)):
        a = np.exp(-2 * np.pi * cut[i] / SR)
        acc = a * acc + (1 - a) * n[i]
        y[i] = acc
    return y * np.sin(np.pi * t / d) ** 1.5


def blast():
    t = T(0.6)
    sweep = np.sin(2 * np.pi * np.cumsum(900 * np.exp(-t * 3.5) + 120) / SR) * env(t, 0.005, 0.25)
    return fit(sweep * 0.8, lp(noise(0.6), 2500) * env(t, 0.002, 0.18) * 0.5)


def guard():
    return fit(tone(520, 0.35, 0.12, (1, 0.7, 0.5, 0.3)) * 0.6, thump(200, 90, 0.12) * 0.5)


def step(kind, i):
    d = 0.14
    n = noise(d)
    if kind == "grass":
        return hp(lp(n, 2200 + i * 150), 400) * env(T(d), 0.01, 0.04)
    if kind == "dirt":
        return fit(lp(n, 900 + i * 100) * env(T(d), 0.004, 0.035), thump(90, 50, 0.08) * 0.4)
    return fit(hp(lp(n, 5200), 800) * env(T(d), 0.001, 0.02), tone(1900 + i * 200, 0.05, 0.015, (1,)) * 0.3)   # stone / wood tick


def ui(freqs, d=0.22, gap=0.07):
    out = np.zeros(int((d + gap * len(freqs)) * SR))
    for k, f in enumerate(freqs):
        s = tone(f, d, 0.09, (1, 0.35, 0.12))
        o = int(k * gap * SR)
        out[o:o + len(s)] += s[: len(out) - o]
    return out


def arpeggio(notes, step=0.11, d=0.9):
    out = np.zeros(int((d + step * len(notes)) * SR))
    for k, f in enumerate(notes):
        s = tone(f, d, 0.35, (1, 0.5, 0.25, 0.1))
        o = int(k * step * SR)
        out[o:o + len(s)] += s[: len(out) - o]
    return out


PACK = {}
for i in range(1, 5):
    PACK[f"hit_{i}"] = (lambda i=i: hit(i))
PACK["hit_heavy"] = hit_heavy
PACK["dodge"] = lambda: whoosh(0.28, True)
PACK["swing_1"] = lambda: whoosh(0.22, False)
PACK["swing_2"] = lambda: whoosh(0.25, True) * 0.9
PACK["blast"] = blast
PACK["guard"] = guard
for k in ["grass", "dirt", "stone"]:
    for i in range(1, 5):
        PACK[f"step_{k}_{i}"] = (lambda k=k, i=i: step(k, i))
PACK["hover"] = lambda: ui([1800], 0.05) * 0.5
PACK["menu_open"] = lambda: ui([523, 784], 0.25, 0.06)
PACK["menu_close"] = lambda: ui([784, 523], 0.22, 0.06)
PACK["confirm"] = lambda: ui([659, 880, 1175], 0.3, 0.07)
PACK["back"] = lambda: ui([440, 330], 0.2, 0.06)
PACK["error"] = lambda: ui([220, 196], 0.25, 0.09) * 0.8
PACK["levelup"] = lambda: arpeggio([523, 659, 784, 1047, 1319], 0.1, 1.2)
PACK["victory"] = lambda: arpeggio([392, 523, 659, 784, 1047, 784, 1047, 1319], 0.16, 1.5)
PACK["defeat"] = lambda: arpeggio([392, 349, 311, 262], 0.28, 1.4) * 0.8
PACK["pickup"] = lambda: ui([988, 1319], 0.2, 0.05)
PACK["chest"] = lambda: fit(thump(180, 70, 0.2) * 0.8, arpeggio([784, 988, 1175, 1568], 0.07, 0.8) * 0.6)
def portal():
    t = T(1.4)
    rise = np.sin(2 * np.pi * np.cumsum(180 + 700 * (t / 1.4) ** 1.5) / SR) * np.sin(np.pi * t / 1.4)
    return rise * 0.6 + lp(noise(1.4), 1500) * np.sin(np.pi * t / 1.4) * 0.3


PACK["portal"] = portal
PACK["eat"] = lambda: lp(noise(0.12), 1200) * env(T(0.12), 0.003, 0.03)

def amb_cave(seconds=24):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    bed = lp(noise(seconds), 140) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 9.0) ** 2) * 0.8
    drips = np.zeros(n)
    at = 0.7
    while at < seconds - 1:
        f = rng.uniform(900, 1700)
        d = tone(f, 0.35, 0.07, (1, 0.2))
        o = int(at * SR)
        drips[o:o + len(d)] += d[: n - o] * rng.uniform(0.3, 0.8)
        at += rng.uniform(1.2, 4.5)
    rev = np.zeros(n)   # cheap echo
    for dly, g in [(0.23, 0.45), (0.51, 0.28), (0.83, 0.16)]:
        k = int(dly * SR)
        rev[k:] += drips[:-k] * g
    x = bed + drips + rev
    k = 2 * SR   # seamless: crossfade the tail into the head
    out = x[:-k].copy()
    f = np.linspace(0, 1, k)
    out[:k] = x[:k] * f + x[-k:] * (1 - f)
    return out


def amb_wind(seconds=24):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = lp(noise(seconds), 380) * (0.45 + 0.55 * np.sin(2 * np.pi * t / 13.0) ** 2) + hp(lp(noise(seconds), 2500), 900) * 0.12 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 7.0))
    k = 2 * SR
    out = x[:-k].copy()
    f = np.linspace(0, 1, k)
    out[:k] = x[:k] * f + x[-k:] * (1 - f)
    return out


PACK["_amb_cave"] = amb_cave
PACK["_amb_wind"] = amb_wind

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k in (sys.argv[1:] or PACK):
        save(("amb_" + k[5:]) if k.startswith("_amb_") else "sfx_" + k, PACK[k]())
    print("wrote", len(sys.argv[1:] or PACK), "effects")
