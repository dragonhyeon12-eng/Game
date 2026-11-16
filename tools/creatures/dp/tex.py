"""Procedural textures with numpy, saved into Blender images (packed into the GLB on export).

All textures are generated in UV space, so markings line up with the anatomy the mesh code laid
out (e.g. the body's U goes around the body, V runs head to tail).
"""
import numpy as np
import bpy


def value_noise(w, h, cells_x, cells_y, seed, tile_x=True):
    """Smooth value noise, w x h, with cells_x x cells_y lattice cells. Tiles in X if tile_x."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y + 1, cells_x + 1))
    if tile_x:
        grid[:, -1] = grid[:, 0]
    xs = np.linspace(0, cells_x, w, endpoint=False) if tile_x else np.linspace(0, cells_x, w)
    ys = np.linspace(0, cells_y, h)
    xi = np.minimum(xs.astype(int), cells_x - 1)
    yi = np.minimum(ys.astype(int), cells_y - 1)
    xf = xs - xi
    yf = ys - yi
    xf = xf * xf * (3 - 2 * xf)
    yf = yf * yf * (3 - 2 * yf)
    a = grid[yi][:, xi]
    b = grid[yi][:, xi + 1]
    c = grid[yi + 1][:, xi]
    d = grid[yi + 1][:, xi + 1]
    top = a + (b - a) * xf[None, :]
    bot = c + (d - c) * xf[None, :]
    return top + (bot - top) * yf[:, None]


def fbm(w, h, cells_x, cells_y, seed, octaves=4, tile_x=True):
    out = np.zeros((h, w))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        out += amp * value_noise(w, h, cells_x * 2 ** o, cells_y * 2 ** o, seed + o * 17, tile_x)
        total += amp
        amp *= 0.5
    return out / total


def cellular(w, h, cells_x, cells_y, seed, tile_x=True):
    """F1 and F2 distances to jittered points (Worley noise), tiling in X. Values in cell units."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells_y, cells_x, 2))
    xs = (np.arange(w) + 0.5) / w * cells_x
    ys = (np.arange(h) + 0.5) / h * cells_y
    X, Y = np.meshgrid(xs, ys)
    cx = np.floor(X).astype(int)
    cy = np.floor(Y).astype(int)
    f1 = np.full((h, w), 9.0)
    f2 = np.full((h, w), 9.0)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx = cx + dx
            ny = cy + dy
            wrap_x = nx % cells_x if tile_x else np.clip(nx, 0, cells_x - 1)
            cl_y = np.clip(ny, 0, cells_y - 1)
            jp = pts[cl_y, wrap_x]
            px = nx + jp[..., 0]
            py = ny + jp[..., 1]
            d = np.sqrt((X - px) ** 2 + (Y - py) ** 2)
            f2 = np.where(d < f1, f1, np.minimum(f2, d))
            f1 = np.minimum(f1, d)
    return f1, f2


def normal_from_height(height, strength, tile_x=True):
    """Tangent-space normal map (OpenGL / glTF convention) from a height field."""
    if tile_x:
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    else:
        dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    # image rows go down in numpy but UV v goes up: flip so green = +v
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)


def to_image(name, rgb, alpha=None, non_color=False):
    """Store an (h, w, 3) float array in a packed Blender image. Row 0 of the array = top (v = 1)."""
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=alpha is not None)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'   # first: changing it later resets the pixels
    a = np.ones((h, w, 1)) if alpha is None else alpha[..., None]
    px = np.concatenate([np.clip(rgb, 0, 1), a], axis=-1)
    # Blender's pixel rows start at the bottom
    img.pixels.foreach_set(np.flipud(px).astype(np.float32).ravel())
    img.file_format = 'PNG'
    img.pack()
    return img


def linear(c):
    """sRGB -> linear for colour constants written into colour textures (Blender converts back)."""
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
