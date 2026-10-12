#!/usr/bin/env python3
"""Draws the 9-slice UI art (assets/ui/*.png): parchment panel in a wooden frame, dark glass panel, ribbon, buttons,
tabs, bar trough/fill, divider. Re-run after tweaking:  python3 tools/assets/make_ui_art.py  (+ godot --import)"""
import numpy as np, os
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui")
SS = 4
rng = np.random.default_rng(7)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def vgrad(w, h, top, bot):
    t = np.linspace(0, 1, h)[:, None, None]
    a = np.array(top, float)[None, None, :]; b = np.array(bot, float)[None, None, :]
    return np.repeat(a + (b - a) * t, w, axis=1)

def noise(w, h, scale, amp):
    n = rng.random((h // scale + 2, w // scale + 2))
    img = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return (np.asarray(img, float) / 255.0 - 0.5) * amp

def rr_mask(w, h, r, inset=0):
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([inset * SS, inset * SS, (w - inset) * SS - 1, (h - inset) * SS - 1], r * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)

def paste_layer(base, rgb, mask):
    base.paste(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)), (0, 0), mask)

def panel_paper(w=224, h=224):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # drop-shadow is added by the engine; here: outer dark edge, wood band, gold line, inner shadow, paper
    paste_layer(img, np.full((h, w, 3), (38, 22, 12)), rr_mask(w, h, 18))
    wood = vgrad(w, h, (140, 90, 48), (88, 52, 26)) + noise(w, h, 2, 26)[:, :, None]
    grain = (np.sin(np.arange(w)[None, :] * 0.9 + noise(w, h, 9, 14)) * 6)[:, :, None]
    paste_layer(img, wood + grain, rr_mask(w, h, 17, 2))
    paste_layer(img, np.full((h, w, 3), (205, 160, 80)), rr_mask(w, h, 12, 12))
    paste_layer(img, np.full((h, w, 3), (92, 56, 28)), rr_mask(w, h, 11, 14))
    paper = vgrad(w, h, (240, 228, 196), (222, 205, 165)) + noise(w, h, 3, 10)[:, :, None] + noise(w, h, 24, 14)[:, :, None]
    vig = np.asarray(rr_mask(w, h, 10, 15).filter(ImageFilter.GaussianBlur(9)), float) / 255.0
    paper = paper * (0.80 + 0.20 * vig)[:, :, None]
    paste_layer(img, paper, rr_mask(w, h, 10, 15))
    d = ImageDraw.Draw(img)
    gold, dark = (222, 178, 92, 255), (92, 56, 28, 255)
    for sx, sy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:   # filigree corner brackets: L-shape, scroll curl, diamond inlay
        ox = 20 if sx > 0 else w - 21
        oy = 20 if sy > 0 else h - 21
        for k, col in [(3, dark), (2, gold)]:
            d.line([(ox, oy + sy * 34), (ox, oy), (ox + sx * 34, oy)], fill=col, width=k if k == 3 else 1)
        d.arc([ox + sx * 7 - 7, oy + sy * 7 - 7, ox + sx * 7 + 7, oy + sy * 7 + 7], 0, 360, fill=gold, width=1)
        cx, cy = ox + sx * 14, oy + sy * 14
        d.polygon([(cx, cy - 7), (cx + 7, cy), (cx, cy + 7), (cx - 7, cy)], fill=(176, 44, 30, 255), outline=gold)
        for t in (22, 28):
            d.ellipse([ox + sx * t - 1, oy - 1, ox + sx * t + 1, oy + 1], fill=gold)
            d.ellipse([ox - 1, oy + sy * t - 1, ox + 1, oy + sy * t + 1], fill=gold)
    return img

def panel_dark(w=128, h=128):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paste_layer(img, np.full((h, w, 3), (205, 160, 80)), rr_mask(w, h, 14))
    body = vgrad(w, h, (40, 24, 28), (22, 12, 14)) + noise(w, h, 3, 6)[:, :, None]
    m = np.asarray(rr_mask(w, h, 12, 2), float) * 0.93
    out = np.asarray(img, float)
    out[:, :, :3] = np.where(m[:, :, None] > 0, body, out[:, :, :3])
    out[:, :, 3] = np.maximum(np.asarray(rr_mask(w, h, 14), float) * 0.95, 0)
    inner = np.asarray(rr_mask(w, h, 12, 2), float) / 255.0
    a = out[:, :, 3] / 255.0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

def ribbon(w=320, h=64):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    big = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(big)
    # swallow-tailed banner: body + tail wings
    poly = [(30, 8), (w - 30, 8), (w - 6, 8), (w - 22, h / 2), (w - 6, h - 8), (w - 30, h - 8), (30, h - 8), (6, h - 8), (22, h / 2), (6, 8)]
    bd.polygon([(x * s, y * s) for x, y in poly], fill=(70, 20, 14, 255))
    big = big.resize((w, h), Image.LANCZOS)
    arr = np.asarray(big, float)
    mask = Image.fromarray(arr[:, :, 3].astype(np.uint8))
    inner = Image.new("L", (w * s, h * s), 0)
    ImageDraw.Draw(inner).polygon([(x * s, y * s) for x, y in [(33, 11), (w - 33, 11), (w - 10, 11), (w - 25, h / 2), (w - 10, h - 11), (w - 33, h - 11), (33, h - 11), (10, h - 11), (25, h / 2), (10, 11)]], fill=255)
    inner = inner.resize((w, h), Image.LANCZOS)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paste_layer(img, np.full((h, w, 3), (222, 178, 92)), mask)
    body = vgrad(w, h, (176, 44, 30), (112, 22, 16)) + noise(w, h, 2, 10)[:, :, None]
    gloss = np.zeros((h, w, 1)); gloss[: h // 2 - 2] = 22
    paste_layer(img, body + gloss, inner)
    return img

def button(state, w=160, h=56):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pal = {"normal": ((190, 56, 36), (118, 24, 18), (222, 178, 92)), "hover": ((226, 86, 52), (150, 38, 24), (255, 226, 140)),
           "pressed": ((120, 28, 20), (170, 52, 34), (200, 150, 70)), "disabled": ((92, 70, 64), (66, 50, 46), (120, 104, 90)),
           "focus": ((0, 0, 0), (0, 0, 0), (255, 226, 140))}[state]
    if state == "focus":
        mk = rr_mask(w, h, 16).point(lambda v: v); ring = Image.new("L", (w, h), 0)
        ImageChops_sub = np.asarray(rr_mask(w, h, 16), float) - np.asarray(rr_mask(w, h, 13, 3), float)
        paste_layer(img, np.full((h, w, 3), pal[2]), Image.fromarray(np.clip(ImageChops_sub, 0, 255).astype(np.uint8)))
        return img
    paste_layer(img, np.full((h, w, 3), (50, 18, 12)), rr_mask(w, h, 17))
    paste_layer(img, np.full((h, w, 3), pal[2]), rr_mask(w, h, 16, 1))
    body = vgrad(w, h, pal[0], pal[1])
    paste_layer(img, body, rr_mask(w, h, 14, 3))
    ramp = np.clip(1.0 - np.arange(h) / (h * 0.55), 0, 1) ** 1.6
    gl = (ramp[:, None, None] * (46 if state != "pressed" else 8)) * np.ones((1, w, 1))
    mm = rr_mask(w, h, 12, 4)
    paste_layer(img, body + gl, Image.fromarray((np.asarray(mm, float) * (np.asarray(rr_mask(w, h, 14, 3), float) > 0)).astype(np.uint8)))
    return img

def cham_mask(w, h, c, inset=0):
    m = Image.new("L", (w * SS, h * SS), 0)
    i, c2 = inset * SS, c * SS
    ImageDraw.Draw(m).polygon([(i + c2, i), (w * SS - i - c2, i), (w * SS - i, i + c2), (w * SS - i, h * SS - i - c2), (w * SS - i - c2, h * SS - i),
                               (i + c2, h * SS - i), (i, h * SS - i - c2), (i, i + c2)], fill=255)
    return m.resize((w, h), Image.LANCZOS)

def plate(state, primary=False, w=160, h=52):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if state == "focus":
        ring = np.asarray(cham_mask(w, h, 10), float) - np.asarray(cham_mask(w, h, 8, 3), float)
        paste_layer(img, np.full((h, w, 3), (255, 226, 140)), Image.fromarray(np.clip(ring, 0, 255).astype(np.uint8)))
        return img
    if primary:
        pal = {"normal": ((190, 56, 36), (118, 24, 18)), "hover": ((226, 86, 52), (150, 38, 24)), "pressed": ((120, 28, 20), (170, 52, 34)), "disabled": ((110, 90, 84), (80, 66, 60))}[state]
    else:
        pal = {"normal": ((238, 224, 188), (214, 194, 150)), "hover": ((252, 242, 214), (232, 212, 164)), "pressed": ((196, 174, 132), (222, 202, 160)), "disabled": ((190, 180, 160), (170, 160, 140))}[state]
    paste_layer(img, np.full((h, w, 3), (44, 24, 12)), cham_mask(w, h, 10))
    paste_layer(img, vgrad(w, h, (236, 196, 108), (170, 120, 52)), cham_mask(w, h, 9, 1))
    paste_layer(img, np.full((h, w, 3), (70, 40, 20)), cham_mask(w, h, 8, 3))
    face = vgrad(w, h, pal[0], pal[1]) + noise(w, h, 3, 6)[:, :, None]
    ramp = np.clip(1.0 - np.arange(h) / (h * 0.5), 0, 1) ** 1.8
    face = face + ramp[:, None, None] * (22 if primary else 10)
    paste_layer(img, face, cham_mask(w, h, 7, 4))
    if state == "hover" and not primary:      # red diamond marker in the left margin
        d = ImageDraw.Draw(img); cx, cy = 14, h // 2
        d.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)], fill=(176, 44, 30, 255), outline=(222, 178, 92, 255))
    return img

def tab(active, w=128, h=48):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    col = ((236, 222, 184), (214, 194, 150)) if active else ((150, 104, 62), (112, 74, 40))
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * SS - 1, (h + 18) * SS], 14 * SS, fill=255)
    m = m.resize((w, h), Image.LANCZOS)
    paste_layer(img, np.full((h, w, 3), (50, 28, 14)), m)
    m2 = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m2).rounded_rectangle([2 * SS, 2 * SS, (w - 2) * SS - 1, (h + 18) * SS], 12 * SS, fill=255)
    paste_layer(img, vgrad(w, h, col[0], col[1]) + noise(w, h, 3, 8)[:, :, None], m2.resize((w, h), Image.LANCZOS))
    return img

def trough(w=96, h=24):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paste_layer(img, np.full((h, w, 3), (205, 160, 80)), rr_mask(w, h, 12))
    paste_layer(img, vgrad(w, h, (26, 16, 10), (66, 44, 28)), rr_mask(w, h, 11, 2))
    return img

def fill(w=96, h=24):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    base = vgrad(w, h, (255, 255, 255), (170, 170, 170))
    gl = np.zeros((h, w, 1)); gl[2 : h // 2 - 1] = 40
    paste_layer(img, base + gl, rr_mask(w, h, 9, 3))
    return img

def divider(w=256, h=16):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(w):
        t = 1 - abs(x - w / 2) / (w / 2)
        d.point((x, h // 2), fill=(120, 80, 40, int(255 * min(1, t * 2.2))))
        d.point((x, h // 2 + 1), fill=(222, 178, 92, int(200 * min(1, t * 2.2))))
    d.polygon([(w / 2, 2), (w / 2 + 6, h / 2), (w / 2, h - 2), (w / 2 - 6, h / 2)], fill=(188, 52, 34, 255), outline=(222, 178, 92, 255))
    return img

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    arts = {"panel_paper": panel_paper(), "panel_dark": panel_dark(), "ribbon": ribbon(), "tab_on": tab(True), "tab_off": tab(False),
            "bar_trough": trough(), "bar_fill": fill(), "divider": divider()}
    for s in ["normal", "hover", "pressed", "disabled", "focus"]:
        arts["btn_" + s] = button(s)
        arts["plate_" + s] = plate(s)
        arts["plate_primary_" + s] = plate(s, True)
    sheet = Image.new("RGBA", (900, 560), (70, 90, 80, 255)); x = y = 10
    for n, im in arts.items():
        im.save(os.path.join(OUT, n + ".png"))
        if x + im.width > 890: x = 10; y += 200
        sheet.alpha_composite(im, (x, y)); x += im.width + 14
    sheet.save(os.path.join(OUT, "_preview.png"))
    print("wrote", len(arts))
