#!/usr/bin/env python3
"""Draws the meadow cover cards (assets/terrain/cover/*.png, 128 px RGBA): daisy, buttercup, violet, clover, tall-grass
seed heads. Each card is a small bunch (several blooms on stems) drawn at 4x and downsampled, so edges stay soft.
python3 tools/assets/make_cover_art.py"""
import math, os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "terrain", "cover")
S = 4
N = 128 * S


def bloom(d, cx, cy, r, petals, col, center, rnd, pr=0.55):
    for i in range(petals):
        a = i / petals * math.tau + rnd.uniform(-0.15, 0.15)
        px, py = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
        w, h = r * pr, r * 0.42
        pts = []
        for k in range(14):
            t = k / 14 * math.tau
            x, y = math.cos(t) * w, math.sin(t) * h
            pts.append((px + x * math.cos(a) - y * math.sin(a), py + x * math.sin(a) + y * math.cos(a)))
        shade = tuple(int(c * (0.88 + 0.12 * rnd.random())) for c in col)
        d.polygon(pts, fill=shade + (255,))
    d.ellipse([cx - r * 0.26, cy - r * 0.26, cx + r * 0.26, cy + r * 0.26], fill=center + (255,))


def stem(d, x0, y0, x1, y1, w=3):
    d.line([(x0, y0), (x1, y1)], fill=(70, 120, 50, 255), width=w * S // 2 + 2)
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    d.polygon([(mx, my), (mx + 14 * S, my - 6 * S), (mx + 3 * S, my + 2 * S)], fill=(78, 134, 56, 255))


def card(name, make):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    make(ImageDraw.Draw(img), random.Random(hash(name) & 0xFFFF))
    img.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def flowers(petals, col, center, size, count, pr=0.55):
    def mk(d, rnd):
        for i in range(count):
            x = N * (0.2 + 0.6 * rnd.random())
            top = N * (0.18 + 0.28 * rnd.random())
            stem(d, N * 0.5 + (x - N * 0.5) * 0.3, N * 0.98, x, top)
            bloom(d, x, top, size * S * (0.8 + 0.4 * rnd.random()), petals, col, center, rnd, pr)
    return mk


def clover(d, rnd):
    for i in range(7):
        x, y = N * (0.15 + 0.7 * rnd.random()), N * (0.55 + 0.4 * rnd.random())
        for k in range(3):
            a = k / 3 * math.tau + rnd.random()
            d.ellipse([x + math.cos(a) * 10 * S - 9 * S, y + math.sin(a) * 10 * S - 7 * S, x + math.cos(a) * 10 * S + 9 * S, y + math.sin(a) * 10 * S + 7 * S], fill=(64, 130, 56, 255))
        stem(d, x, N, x, y - 14 * S, 2)
        d.ellipse([x - 8 * S, y - 28 * S, x + 8 * S, y - 12 * S], fill=(236, 150, 176, 255))


def seedgrass(d, rnd):
    for i in range(14):
        x0 = N * (0.25 + 0.5 * rnd.random())
        x1 = x0 + N * (rnd.random() - 0.5) * 0.35
        top = N * (0.1 + 0.4 * rnd.random())
        d.line([(x0, N), ((x0 + x1) / 2, N * 0.55), (x1, top)], fill=(120, 150, 70, 255), width=3 * S // 2)
        for k in range(7):
            yy = top + k * 6 * S
            d.line([(x1, yy), (x1 + 7 * S, yy - 5 * S)], fill=(176, 160, 96, 255), width=2 * S // 2 + 1)
            d.line([(x1, yy), (x1 - 7 * S, yy - 5 * S)], fill=(176, 160, 96, 255), width=2 * S // 2 + 1)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    card("daisy", flowers(12, (250, 248, 240), (244, 200, 40), 13, 4, 0.5))
    card("buttercup", flowers(5, (252, 214, 40), (210, 150, 20), 11, 5, 0.6))
    card("violet", flowers(5, (150, 110, 214), (250, 220, 90), 11, 4, 0.55))
    card("poppy", flowers(4, (226, 60, 50), (40, 30, 30), 14, 3, 0.7))
    card("clover", clover)
    card("seedgrass", seedgrass)
    print("wrote cover cards")
