#!/usr/bin/env python3
"""Renders the Coil app icon: a glowing, brush-painted spiral on textured paper.

Usage:
    python3 scripts/make_icon.py Coil/Resources/Assets.xcassets/AppIcon.appiconset

Writes AppIcon.png (light), AppIcon-Dark.png and AppIcon-Tinted.png (1024×1024).
Everything is seeded, so the icon is the same on every run.
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 3  # supersampling for smooth brush strokes
S = SIZE * SCALE


def paper(base_center, base_edge, grain, seed):
    """Off-white (or off-black) paper: a soft radial glow plus fine grain and faint fibers."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    d = np.sqrt((x - SIZE * 0.5) ** 2 + (y - SIZE * 0.46) ** 2) / (SIZE * 0.72)
    d = np.clip(d, 0, 1) ** 1.6
    center = np.array(base_center, np.float32)
    edge = np.array(base_edge, np.float32)
    img = center[None, None, :] * (1 - d[..., None]) + edge[None, None, :] * d[..., None]

    # Fine grain plus a slightly blurred, larger-scale mottling like handmade paper.
    fine = rng.normal(0, grain, (SIZE, SIZE)).astype(np.float32)
    coarse = Image.fromarray(((rng.normal(0, 1, (SIZE // 8, SIZE // 8)) * 40 + 128).clip(0, 255)).astype(np.uint8))
    coarse = np.asarray(coarse.resize((SIZE, SIZE), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6)), np.float32)
    texture = fine + (coarse - 128) / 40 * grain * 0.8
    img += texture[..., None]

    out = Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")

    # Faint paper fibers.
    fibers = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(fibers)
    for _ in range(260):
        x0, y0 = rng.uniform(0, SIZE, 2)
        angle = rng.uniform(0, math.pi)
        length = rng.uniform(10, 45)
        draw.line(
            [(x0, y0), (x0 + math.cos(angle) * length, y0 + math.sin(angle) * length)],
            fill=int(rng.uniform(10, 26)), width=1,
        )
    fibers = fibers.filter(ImageFilter.GaussianBlur(0.6))
    sign = -1 if sum(base_center) > 380 else 1
    arr = np.asarray(out, np.float32) + sign * np.asarray(fibers, np.float32)[..., None] * 0.55
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")


def spiral_points():
    """An Archimedean spiral from the outer tail inwards, in supersampled coordinates."""
    cx, cy = S * 0.5, S * 0.5
    turns = 2.15
    r_outer, r_inner = S * 0.34, S * 0.035
    start = math.radians(-35)
    pts = []
    n = 900
    for i in range(n):
        t = i / (n - 1)
        angle = start + t * turns * 2 * math.pi
        r = r_outer + (r_inner - r_outer) * (t ** 0.92)
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle), t))
    return pts


def brush_layer(color_range, seed):
    """Many thin bristles following the spiral, so the stroke has texture and dry, broken edges."""
    rng = np.random.default_rng(seed)
    pts = spiral_points()
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Normals along the path.
    normals = []
    for i in range(len(pts)):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1
        normals.append((-dy / length, dx / length))

    def width(t):
        # Pressure: a firm start that swells, then tapers off towards the centre.
        swell = math.sin(min(1, t * 1.15) * math.pi) ** 0.5
        return S * (0.012 + 0.052 * swell * (1 - 0.55 * t))

    bristles = 110
    lo, hi = color_range
    for b in range(bristles):
        offset = rng.uniform(-1, 1)
        wobble_phase = rng.uniform(0, 2 * math.pi)
        wobble_freq = rng.uniform(3, 9)
        # Dry brush: some bristles run out of paint early or skip near the edges.
        end_t = 1 - abs(offset) ** 2 * rng.uniform(0.05, 0.45)
        start_t = abs(offset) ** 3 * rng.uniform(0, 0.12)
        shade = rng.uniform(lo, hi)
        alpha = int(rng.uniform(70, 150) * (1 - 0.35 * abs(offset)))
        line_w = max(2, int(rng.uniform(0.5, 1.4) * SCALE * 2.2))
        # Paint load varies along the stroke: dense where the brush is pressed, patchy where it dries.
        load_phase = rng.uniform(0, 2 * math.pi)
        load_freq = rng.uniform(1.5, 4)

        def flush(segment, t):
            if len(segment) < 2:
                return
            load = 0.55 + 0.45 * math.sin(load_phase + t * load_freq * 2 * math.pi)
            dry = 1 - 0.6 * max(0, t - 0.6) / 0.4  # the tail runs out of paint
            a = int(alpha * max(0.15, load) * max(0.25, dry))
            draw.line(segment, fill=(int(shade), int(shade), int(shade + 5), a), width=line_w, joint="curve")

        segment = []
        for i, ((x, y, t), (nx, ny)) in enumerate(zip(pts, normals)):
            gap = rng.random() < 0.006 * (1 + 6 * abs(offset)) * (1 + 3 * t)
            if t < start_t or t > end_t or gap:
                flush(segment, t)
                segment = []
                continue
            w = width(t) * (1 + 0.07 * math.sin(wobble_phase + t * wobble_freq * 2 * math.pi))
            segment.append((x + nx * offset * w, y + ny * offset * w))
            if len(segment) >= 14:
                flush(segment, t)
                segment = segment[-1:]
        flush(segment, 1)

    # A softer body under the bristles so the stroke reads as paint, not hair.
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    mid = (lo + hi) / 2
    for (x, y, t), _ in zip(pts, normals):
        if t > 0.97:
            continue
        r = width(t) * 0.82
        bd.ellipse([x - r, y - r, x + r, y + r], fill=(int(mid), int(mid), int(mid + 4), 34))
    body = body.filter(ImageFilter.GaussianBlur(SCALE * 2))

    return Image.alpha_composite(body, layer)


def compose(background, color_range, glow_color, glow_alpha, seed=7):
    stroke = brush_layer(color_range, seed).resize((SIZE, SIZE), Image.LANCZOS)
    # Center the painted shape (including its soft edges) in the icon.
    box = stroke.split()[3].point(lambda v: 255 if v > 12 else 0).getbbox()
    if box:
        dx = int(SIZE / 2 - (box[0] + box[2]) / 2)
        dy = int(SIZE / 2 - (box[1] + box[3]) / 2)
        stroke = stroke.transform(stroke.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy))

    # Glow: a wide, soft halo built from the stroke's own shape.
    mask = stroke.split()[3]
    halo_mask = mask.filter(ImageFilter.GaussianBlur(46)).point(lambda v: min(255, int(v * glow_alpha)))
    halo = Image.new("RGBA", (SIZE, SIZE), glow_color + (0,))
    halo.putalpha(halo_mask)
    inner_mask = mask.filter(ImageFilter.GaussianBlur(12)).point(lambda v: min(255, int(v * glow_alpha * 0.8)))
    inner = Image.new("RGBA", (SIZE, SIZE), glow_color + (0,))
    inner.putalpha(inner_mask)

    out = background.convert("RGBA")
    out = Image.alpha_composite(out, halo)
    out = Image.alpha_composite(out, inner)
    out = Image.alpha_composite(out, stroke)
    return out.convert("RGB")


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "."

    light_bg = paper((255, 254, 252), (233, 231, 226), grain=3.4, seed=1)
    light = compose(light_bg, (124, 176), glow_color=(204, 202, 214), glow_alpha=1.7)
    light.save(f"{folder}/AppIcon.png")

    dark_bg = paper((40, 40, 44), (18, 18, 20), grain=3.0, seed=2)
    dark = compose(dark_bg, (188, 228), glow_color=(232, 232, 242), glow_alpha=1.2)
    dark.save(f"{folder}/AppIcon-Dark.png")

    tinted_bg = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    tinted = compose(tinted_bg, (200, 245), glow_color=(255, 255, 255), glow_alpha=1.0)
    tinted.convert("L").convert("RGB").save(f"{folder}/AppIcon-Tinted.png")
    print("Wrote icons to", folder)


if __name__ == "__main__":
    main()
