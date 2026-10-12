#!/usr/bin/env python3
"""Offline terrain bake (numpy + PIL; all CPU cores via multiprocessing for the AO directions).
Reads ~/.cache/ranch3d_tmp/world_height.bin (tools/bake/export_heights.gd) and writes into assets/terrain/:
  world_height.bin       float32 heights (256 x 384, 1 m)         -> loaded instead of sampling Overworld.height() at runtime
  world_color.png        RGBA8 Terrain3D colour map: baked ambient occlusion x macro tint (alpha = roughness)
  tex/<name>_alb.png     albedo (tinted) + height in alpha, 1024 px   |  tex/<name>_nrm.png  normal + roughness alpha
Runs in ~10 s. Re-run after changing height() or the terrain tints."""
import os, sys
import numpy as np
from multiprocessing import Pool
from PIL import Image

HOME = os.path.expanduser("~")
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "terrain")
W, H = 256, 384
TEX = {"grass004": (0.62, 0.82, 0.42), "ground037": (0.8, 0.68, 0.52), "rock030": (0.74, 0.72, 0.7), "grass001": (0.66, 0.84, 0.46)}
N_DIR, STEPS, RADIUS = 32, 14, 16.0


def horizon_dir(args):
    h, ang = args
    # for each pixel, the max elevation angle of the terrain along direction `ang` within RADIUS
    best = np.zeros_like(h)
    dx, dy = np.cos(ang), np.sin(ang)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    for s in range(1, STEPS + 1):
        d = RADIUS * (s / STEPS) ** 1.5
        sx = np.clip(xs + dx * d, 0, W - 1).astype(np.int32)
        sy = np.clip(ys + dy * d, 0, H - 1).astype(np.int32)
        rise = h[sy, sx] - h
        best = np.maximum(best, np.arctan2(rise, d))
    return best


def blur(a, r):
    k = np.ones(2 * r + 1, np.float32) / (2 * r + 1)
    a = np.apply_along_axis(lambda m: np.convolve(np.pad(m, r, mode="edge"), k, mode="valid"), 0, a)
    return np.apply_along_axis(lambda m: np.convolve(np.pad(m, r, mode="edge"), k, mode="valid"), 1, a)


def fbm(seed, scale):
    rng = np.random.default_rng(seed)
    out = np.zeros((H, W), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(4):
        n = rng.random((H // scale + 3, W // scale + 3)).astype(np.float32)
        im = Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        out += amp * np.asarray(im, np.float32) / 255.0
        tot += amp
        amp *= 0.5
        scale = max(2, scale // 2)
    return out / tot


def main():
    os.makedirs(os.path.join(OUT, "tex"), exist_ok=True)
    raw = np.fromfile(os.path.join(HOME, ".cache/ranch3d_tmp/world_height.bin"), dtype=np.float32).reshape(H, W)
    raw.tofile(os.path.join(OUT, "world_height.bin"))
    with Pool(min(32, os.cpu_count() or 4)) as p:
        hor = p.map(horizon_dir, [(raw, i / N_DIR * 2 * np.pi) for i in range(N_DIR)])
    # ambient occlusion: how much of the sky is hidden by terrain (0 = open, 1 = fully enclosed)
    occ = np.mean([np.sin(np.clip(h, 0, np.pi / 2)) for h in hor], axis=0)
    ao = np.clip(1.0 - occ * 1.35, 0.35, 1.0)
    ao = blur(ao, 1)
    # slope darkening + cavities (curvature) for readable form
    gy, gx = np.gradient(blur(raw, 1))
    slope = np.clip(np.hypot(gx, gy), 0, 2)
    curv = blur(raw, 3) - blur(raw, 9)                      # + on ridges, - in hollows
    tone = 1.0 + np.clip(curv, -1.5, 1.5) * 0.045
    # macro tint: slow noise that varies the meadow between fresh green and dry yellow-brown
    n1, n2 = fbm(5, 48), fbm(9, 12)
    dry = np.clip((n1 - 0.45) * 2.2, 0, 1)
    col = np.stack([1.0 - 0.08 * dry, 1.0 - 0.02 * dry, 1.0 - 0.20 * dry], -1)
    col *= (0.9 + 0.1 * n2)[..., None]
    col *= (ao * np.clip(tone, 0.85, 1.05))[..., None]
    col *= (1.0 - 0.1 * np.clip(slope - 0.5, 0, 1))[..., None]
    col = np.clip(col, 0, 1)
    rough = np.full((H, W, 1), 0.9, np.float32)
    rgba = np.concatenate([col, rough], -1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "world_color.png"))
    print("baked color map  AO range", float(ao.min()), float(ao.max()))
    # texture assets (what terrain_ground.gd used to build per zone with GDScript pixel loops)
    for name, tint in TEX.items():
        alb = Image.open(os.path.join(ROOT, "assets/tex/%s_color.jpg" % name)).convert("RGB").resize((1024, 1024), Image.LANCZOS)
        a = np.asarray(alb, np.float32) / 255.0 * np.array(tint, np.float32)
        lum = (a * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(-1, keepdims=True)
        Image.fromarray((np.concatenate([np.clip(a, 0, 1), lum], -1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "tex", name + "_alb.png"))
        nrm = Image.open(os.path.join(ROOT, "assets/tex/%s_normal.jpg" % name)).convert("RGB").resize((1024, 1024), Image.LANCZOS)
        n = np.asarray(nrm, np.uint8)
        Image.fromarray(np.concatenate([n, np.full((1024, 1024, 1), 230, np.uint8)], -1), "RGBA").save(os.path.join(OUT, "tex", name + "_nrm.png"))
    print("baked", len(TEX) * 2, "terrain textures")


if __name__ == "__main__":
    main()
