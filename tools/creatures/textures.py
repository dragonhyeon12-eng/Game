"""Tileable PBR surface textures for every surface type in the game (albedo, OpenGL normal, roughness).

Written to models/textures/<surface>/ where the game's optional-texture slots pick them up and apply
them everywhere that surface is used (world-space triplanar, so no UVs are needed). Most are made
near-neutral in colour and tinted by each object's own colour in game ("tint": true in models.json),
so a yellow Backrooms wall and a white bedroom wall share one wallpaper texture.

All noise is generated in the frequency domain or with wrapped cells, so every map tiles seamlessly.
Only numpy is needed (no Blender); run with any Python that has numpy:
    python tools/creatures/textures.py
"""
import json
import os
import struct
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "models", "textures")
RNG = np.random.default_rng(1987)


# ------------------------------------------------------------------ tileable noise

def spectral(n, beta=2.0, lo=1.0, hi=None, seed=None):
    """Periodic fractal noise (n x n) with a 1/f^beta spectrum between frequencies lo and hi. 0..1."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    fx = np.fft.fftfreq(n)[None, :] * n
    fy = np.fft.fftfreq(n)[:, None] * n
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.where(f > 0, 1.0 / np.maximum(f, 1e-9) ** (beta / 2.0), 0.0)
    amp *= (f >= lo)
    if hi:
        amp *= np.exp(-(f / hi) ** 4)
    phase = np.exp(2j * np.pi * rng.random((n, n)))
    img = np.real(np.fft.ifft2(amp * phase))
    img -= img.min()
    return img / max(img.max(), 1e-9)


def worley(n, cells, seed=None):
    """Wrapped Worley noise: F1, F2 (in cell units) and the id of the nearest cell."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    pts = rng.random((cells, cells, 2))
    ids = rng.random((cells, cells))
    xs = (np.arange(n) + 0.5) / n * cells
    X, Y = np.meshgrid(xs, xs)
    cx = np.floor(X).astype(int)
    cy = np.floor(Y).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    nid = np.zeros((n, n))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gx = cx + dx
            gy = cy + dy
            jp = pts[gy % cells, gx % cells]
            d = np.sqrt((X - gx - jp[..., 0]) ** 2 + (Y - gy - jp[..., 1]) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            nid = np.where(closer, ids[gy % cells, gx % cells], nid)
            f1 = np.minimum(f1, d)
    return f1, f2, nid


def grid_cells(n, count, gap):
    """Tile/slab grid: per-pixel cell id (0..1 random), distance to the nearest joint (0..0.5), u, v in cell."""
    t = np.arange(n) / n * count
    u = t % 1.0
    X, Y = np.meshgrid(u, u)
    ix = np.floor(t).astype(int)
    IX, IY = np.meshgrid(ix, ix)
    ids = RNG.random((count, count))[IY % count, IX % count]
    edge = np.minimum(np.minimum(X, 1 - X), np.minimum(Y, 1 - Y))
    joint = np.clip(1.0 - edge / max(gap, 1e-6), 0, 1)
    return ids, edge, joint, X, Y


def normal_map(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * strength
    nz = np.ones_like(height)
    ln = np.sqrt(dx * dx + dy * dy + nz)
    # OpenGL convention (green up); image rows go down
    return np.stack([-dx / ln * 0.5 + 0.5, dy / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], -1)


def blur(img, r):
    """Cheap periodic box blur (r passes of a 3-tap kernel)."""
    for _ in range(r):
        img = (img + np.roll(img, 1, 0) + np.roll(img, -1, 0)) / 3.0
        img = (img + np.roll(img, 1, 1) + np.roll(img, -1, 1)) / 3.0
    return img


def write_png(path, arr):
    arr = np.clip(arr, 0, 1)
    if arr.ndim == 2:
        arr = np.stack([arr] * 3, -1)
    h, w = arr.shape[:2]
    data = (arr * 255 + 0.5).astype(np.uint8)
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        c = struct.pack(">I", len(payload)) + tag + payload
        return c + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def save(name, albedo, height, rough, strength=4.0):
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    write_png(os.path.join(d, f"{name}_diff.png"), albedo)
    write_png(os.path.join(d, f"{name}_nor_gl.png"), normal_map(height, strength))
    write_png(os.path.join(d, f"{name}_rough.png"), rough)
    print("  texture", name, albedo.shape[0])


def neutral(lum, warm=0.0):
    """Near-white albedo from a luminance map (tinted in game by each object's colour)."""
    return np.stack([lum * (1 + warm), lum, lum * (1 - warm)], -1)


# ------------------------------------------------------------------ surfaces

def concrete(n=1024):
    big = spectral(n, 2.2, 1, 12)
    mid = spectral(n, 1.6, 8, 120)
    fine = spectral(n, 1.0, 100)
    pores = (spectral(n, 0.3, 200) > 0.82).astype(float)
    f1, f2, _ = worley(n, 7)
    cracks = np.clip(1 - (f2 - f1) * 70, 0, 1) * (spectral(n, 2.0, 1, 6) > 0.72) * spectral(n, 1.0, 20)
    stains = np.clip((spectral(n, 2.4, 1, 8) - 0.55) * 3, 0, 1)
    lum = 0.9 + 0.12 * (big - 0.5) + 0.08 * (mid - 0.5) + 0.05 * (fine - 0.5) - 0.2 * pores - 0.25 * cracks - 0.12 * stains
    height = 0.6 * mid + 0.3 * fine - 0.8 * pores - 1.2 * cracks
    rough = 0.82 + 0.1 * (fine - 0.5) - 0.12 * stains
    save("concrete", neutral(lum, 0.01), height, rough, 3.0)


def asphalt(n=1024):
    grain = spectral(n, 0.6, 150)
    stones = (spectral(n, 0.5, 90) > 0.75).astype(float)
    big = spectral(n, 2.2, 1, 10)
    patch = (spectral(n, 2.6, 1, 5) > 0.62).astype(float)
    f1, f2, _ = worley(n, 5)
    cracks = np.clip(1 - (f2 - f1) * 80, 0, 1) * (spectral(n, 2.0, 1, 5) > 0.72) * spectral(n, 1.0, 20)
    oil = np.clip((spectral(n, 2.5, 1, 8) - 0.6) * 4, 0, 1)
    lum = 0.95 + 0.25 * (grain - 0.5) + 0.25 * stones - 0.1 * (big - 0.5) - 0.12 * patch - 0.45 * cracks - 0.3 * oil
    height = 0.8 * grain + 0.6 * stones - 1.5 * cracks
    rough = 0.9 - 0.25 * oil + 0.05 * (grain - 0.5)
    save("asphalt", neutral(lum), height, rough, 3.0)


def pavers(n=1024):
    ids, edge, joint, u, v = grid_cells(n, 4, 0.025)
    surf = spectral(n, 1.2, 20)
    big = spectral(n, 2.4, 1, 8)
    moss = np.clip((spectral(n, 2.0, 2, 30) - 0.55) * 4, 0, 1) * joint
    chip = (spectral(n, 0.8, 60) > 0.86).astype(float) * (edge < 0.06)
    lum = (0.92 + 0.08 * (ids - 0.5) + 0.07 * (surf - 0.5) - 0.1 * (big - 0.5)) * (1 - 0.55 * joint) - 0.2 * chip
    alb = neutral(lum)
    alb[..., 1] += 0.04 * moss
    height = (1 - joint) * 0.8 + 0.25 * surf - 0.6 * chip
    rough = 0.8 + 0.12 * joint + 0.05 * (surf - 0.5)
    save("pavers", alb, height, rough, 6.0)


def tiles(name, n, count, gap, gloss, grout_dark):
    ids, edge, joint, u, v = grid_cells(n, count, gap)
    surf = spectral(n, 1.4, 10)
    grime = blur(np.clip((spectral(n, 2.2, 1, 10) - 0.45) * 2, 0, 1), 2)
    bevel = np.clip(edge / (gap * 2.5), 0, 1)
    lum = (0.96 + 0.05 * (ids - 0.5) + 0.03 * (surf - 0.5)) * (1 - grout_dark * joint) * (1 - 0.18 * grime * joint)
    height = bevel * 0.8 + 0.05 * surf
    rough = np.where(joint > 0.5, 0.85, gloss + 0.08 * (surf - 0.5) + 0.15 * grime)
    save(name, neutral(lum), height, rough, 7.0)


def ceiling(n=512):
    ids, edge, joint, u, v = grid_cells(n, 2, 0.02)
    fiss = (spectral(n, 0.4, 60) > 0.7).astype(float)
    worms = np.clip(1 - np.abs(spectral(n, 1.5, 20, 80) - 0.5) * 30, 0, 1)
    stain = np.clip((spectral(n, 2.5, 1, 4) - 0.6) * 3, 0, 1)
    rail = (edge < 0.012).astype(float)
    lum = (0.95 - 0.18 * fiss - 0.1 * worms - 0.25 * stain) * (1 - 0.15 * rail)
    alb = neutral(lum, 0.02)
    alb[..., 2] -= 0.05 * stain
    height = -0.6 * fiss - 0.3 * worms + 0.5 * rail
    rough = 0.92 - 0.3 * rail
    save("tiles_ceiling", alb, height, rough, 4.0)


def wallpaper(n=1024):
    x = np.arange(n) / n
    stripes = (np.sin(x * 2 * np.pi * 12) * 0.5 + 0.5)[None, :] * np.ones((n, 1))
    fine = (np.sin(x * 2 * np.pi * 96) * 0.5 + 0.5)[None, :] * np.ones((n, 1))
    motif = np.clip(np.sin(x[None, :] * 2 * np.pi * 6) * np.sin(x[:, None] * 2 * np.pi * 8), 0, 1) ** 3
    paper = spectral(n, 1.0, 80)
    damp = blur(np.clip((spectral(n, 2.4, 1, 6) - 0.5) * 2.5, 0, 1), 3)
    tide = np.clip(1 - np.abs(damp - 0.35) * 25, 0, 1)
    lum = 0.9 + 0.04 * stripes + 0.03 * fine + 0.03 * motif + 0.04 * (paper - 0.5) - 0.07 * damp - 0.05 * tide
    alb = neutral(lum, 0.03)
    alb[..., 2] -= 0.04 * damp
    height = 0.2 * fine + 0.3 * paper + 0.2 * motif
    rough = 0.88 - 0.05 * damp
    save("wallpaper", alb, height, rough, 2.0)


def carpet(n=1024):
    fibre = spectral(n, 0.2, 200)
    tuft = spectral(n, 0.8, 60)
    wear = spectral(n, 2.4, 1, 6)
    stains = np.clip((spectral(n, 2.6, 1, 10) - 0.6) * 4, 0, 1)
    lum = 0.9 + 0.18 * (fibre - 0.5) + 0.1 * (tuft - 0.5) - 0.08 * (wear - 0.5) - 0.3 * stains
    alb = neutral(lum, 0.02)
    height = 0.7 * fibre + 0.6 * tuft
    rough = np.ones((n, n)) * 0.98
    save("carpet", alb, height, rough, 2.5)


def grass(n=1024):
    blades = spectral(n, 0.15, 180)
    clump = spectral(n, 1.2, 20, 120)
    big = spectral(n, 2.4, 1, 6)
    soil = np.clip((spectral(n, 2.2, 2, 20) - 0.76) * 4, 0, 1) * 0.7
    dry = np.clip((spectral(n, 2.0, 1, 10) - 0.55) * 3, 0, 1)
    g = 0.26 + 0.14 * blades + 0.08 * clump + 0.05 * (big - 0.5)
    alb = np.stack([g * 0.55 + 0.12 * dry, g, g * 0.28 + 0.02 * dry], -1)
    soil_c = np.array([0.24, 0.19, 0.13]) * (0.8 + 0.4 * blades[..., None])
    alb = alb * (1 - soil[..., None]) + soil_c * soil[..., None]
    height = 0.9 * blades + 0.5 * clump - 0.4 * soil
    rough = 0.9 + 0.05 * (blades - 0.5)
    save("grass", alb, height, rough, 2.5)


def streaks(n, seed_scale, passes):
    """Noise smeared along X: long fibres / grain."""
    img = spectral(n, 0.8, seed_scale)
    for _ in range(passes):
        img = (img + np.roll(img, 3, 1) + np.roll(img, -3, 1) + np.roll(img, 7, 1) + np.roll(img, -7, 1)) / 5.0
    img -= img.min()
    return img / max(img.max(), 1e-9)


def wood(n=1024):
    planks = 6
    y = np.arange(n) / n
    pid = np.floor(y * planks).astype(int)
    tone = RNG.random(planks)
    shift = RNG.integers(0, n, planks)
    grain = streaks(n, 40, 25)
    fine = streaks(n, 150, 10)
    knots = (spectral(n, 1.6, 8, 40) > 0.9).astype(float)
    grain = np.stack([np.roll(grain[i], shift[pid[i]]) for i in range(n)])
    vfrac = (y * planks) % 1.0
    gap = (np.minimum(vfrac, 1 - vfrac) < 0.01).astype(float)[:, None] * np.ones((1, n))
    ends = ((np.arange(n)[None, :] + shift[pid][:, None]) % (n // 2) < 3).astype(float)
    lum = 0.82 + 0.1 * (grain - 0.5) + 0.06 * (fine - 0.5) + 0.12 * (tone[pid][:, None] - 0.5) - 0.18 * knots
    lum = lum * (1 - 0.6 * np.maximum(gap, ends))
    alb = np.stack([lum * 1.05, lum * 0.95, lum * 0.82], -1)
    height = 0.3 * grain + 0.3 * fine - 1.0 * np.maximum(gap, ends)
    rough = 0.55 + 0.1 * (fine - 0.5) + 0.25 * np.maximum(gap, ends)
    save("wood", alb, height, rough, 3.0)


def plaster(n=1024):
    trowel = spectral(n, 2.0, 3, 40)
    grain = spectral(n, 0.6, 120)
    damp = blur(np.clip((spectral(n, 2.6, 1, 5) - 0.6) * 3, 0, 1), 2)
    f1, f2, _ = worley(n, 6)
    hair = np.clip(1 - (f2 - f1) * 90, 0, 1) * (spectral(n, 2.0, 1, 5) > 0.75) * spectral(n, 1.0, 20)
    lum = 0.93 + 0.04 * (trowel - 0.5) + 0.03 * (grain - 0.5) - 0.12 * damp - 0.2 * hair
    height = 0.6 * trowel + 0.2 * grain - 0.5 * hair
    rough = 0.86 - 0.04 * damp
    save("plaster", neutral(lum, 0.015), height, rough, 3.0)


def metal(n=512):
    x = np.arange(n) / n
    brushed = spectral(n, 0.6, 40)
    streak = blur(np.repeat(RNG.random((1, n)), n, 0), 1) * 0.5 + 0.5 * spectral(n, 1.0, 30)
    scratches = (spectral(n, 0.2, 150) > 0.93).astype(float)
    rust = np.clip((spectral(n, 2.4, 1, 10) - 0.74) * 3, 0, 1) * 0.6
    lum = 0.88 + 0.06 * (streak - 0.5) + 0.1 * scratches - 0.25 * rust
    alb = neutral(lum)
    alb = alb * (1 - rust[..., None]) + np.array([0.45, 0.25, 0.14]) * rust[..., None]
    height = 0.2 * streak + 0.4 * scratches + 0.6 * rust * spectral(n, 0.6, 80)
    rough = 0.38 + 0.15 * (brushed - 0.5) + 0.45 * rust - 0.1 * scratches
    _ = x
    save("metal", alb, height, rough, 2.0)


def fabric(n=512):
    x = np.arange(n)
    warp = (np.sin(x * 2 * np.pi / 6) * 0.5 + 0.5)[None, :]
    weft = (np.sin(x * 2 * np.pi / 6) * 0.5 + 0.5)[:, None]
    weave = np.where((x[None, :] // 6 + x[:, None] // 6) % 2 == 0, warp, weft)
    fuzz = spectral(n, 0.4, 100)
    lum = 0.9 + 0.06 * weave + 0.05 * (fuzz - 0.5)
    height = 0.5 * weave + 0.3 * fuzz
    rough = np.ones((n, n)) * 0.95
    save("fabric", neutral(lum), height, rough, 2.0)


TILE = {  # metres one copy of the texture covers, and whether the object's own colour tints it
    "concrete": (3.0, True), "asphalt": (4.0, True), "pavers": (2.4, True), "tiles_floor": (1.2, True),
    "tiles_pool": (0.5, True), "tiles_ceiling": (1.2, True), "wallpaper": (1.0, True), "carpet": (2.0, True),
    "grass": (3.0, False), "wood": (1.6, True), "plaster": (2.5, True), "metal": (1.5, True), "fabric": (0.5, True),
}


def main():
    concrete()
    asphalt()
    pavers()
    tiles("tiles_floor", 1024, 4, 0.03, 0.22, 0.45)
    tiles("tiles_pool", 512, 4, 0.05, 0.1, 0.35)
    ceiling()
    wallpaper()
    carpet()
    grass()
    wood()
    plaster()
    metal()
    fabric()
    cfg_path = os.path.join(ROOT, "models", "models.json")
    cfg = {}
    if os.path.exists(cfg_path):
        cfg = json.load(open(cfg_path))
    for k, (tile, tint) in TILE.items():
        cfg["textures/" + k] = {"tile": tile, "tint": tint}
    json.dump(cfg, open(cfg_path, "w"), indent="\t")
    print("  wrote", cfg_path)


if __name__ == "__main__":
    main()
