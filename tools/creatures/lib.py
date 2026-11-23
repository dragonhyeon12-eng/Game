"""Shorthand for the bulk prop modules: plain PBR materials by spec, a one-call export, and primitives.

    M(rgb, r=0.5, m=0.0, e=0.0, a=1.0, ds=False)   a material spec (made fresh per export)
    out(d, name, mats, fn)                          build fn(mb) with mats {key: spec}, export d/name.glb
    cyl / ring / sphere / cone / slab / rod / frame_rect   geometry helpers (Blender Z up, -Y = Godot +Z front)
"""
import math

from mathutils import Vector

from dp import scene
from dp.geo import MeshBuilder
from kit import box as _plain_box
from home import lathe, rounded_box

V = Vector


class M:
    """k: what it's made of ("wood", "marble", "stone", "metal", "fabric", "leather", "ceramic"): the game swaps
    tagged materials (name ends "__<k>") for real textured ones in the model's colour."""
    def __init__(self, rgb, r=0.5, m=0.0, e=0.0, a=1.0, ds=False, k=None):
        self.rgb, self.r, self.m, self.e, self.a, self.ds, self.k = rgb, r, m, e, a, ds, k

    def make(self, name, k=None):
        k = self.k or k
        if k:
            name += "__" + k
        return scene.material(name, base_color=self.rgb, roughness=self.r, metallic=self.m,
                              emission_color=self.rgb if self.e else None, emission_strength=self.e,
                              alpha=self.a, double_sided=self.ds)


# a shared palette
CHROME = M((0.8, 0.8, 0.82), 0.15, 0.9, k="metal")
STEEL = M((0.55, 0.56, 0.58), 0.4, 0.85, k="metal")
RUST = M((0.42, 0.25, 0.15), 0.85, 0.3)
BLACK = M((0.04, 0.04, 0.045), 0.55)
RUBBER = M((0.03, 0.03, 0.03), 0.8)
WHITE = M((0.9, 0.9, 0.88), 0.45)
GLASS = M((0.7, 0.8, 0.85), 0.05, 0.0, 0.0, 0.35, True)
WOOD = M((0.32, 0.17, 0.07), 0.4, k="wood")       # oak
DARKWOOD = M((0.11, 0.05, 0.025), 0.35, k="wood")   # walnut
CONCRETE = M((0.55, 0.55, 0.53), 0.9, k="stone")
BRASS = M((0.75, 0.6, 0.3), 0.3, 0.9, k="metal")
MARBLE = M((0.9, 0.89, 0.86), 0.12, k="marble")
DARKMARBLE = M((0.2, 0.21, 0.22), 0.1, k="marble")
GRANITE = M((0.45, 0.43, 0.42), 0.15, k="stone")
CERAMIC = M((0.93, 0.93, 0.91), 0.1, k="ceramic")


def _kind_of(key):
    """Guess what a material is made of from its key in a model's material list."""
    key = key.lower()
    if "wood" in key or key in ("oak", "walnut", "pine", "lid", "board"):
        return "wood"
    if "marble" in key or key in ("top", "worktop", "counter"):
        return "marble"
    if "stone" in key:
        return "stone"
    if key in ("steel", "chrome", "metal", "iron", "brass", "rail", "rim", "screw"):
        return "metal"
    if key in ("fab", "fabric", "cloth", "cloth2", "towel", "duvet", "sheet", "fur", "coat", "rug", "border", "pad", "cushion", "curtain"):
        return "fabric"
    if key in ("cer", "ceramic", "enamel", "porcelain", "white2"):
        return "ceramic"
    return None
PAPER = M((0.92, 0.9, 0.84), 0.85)
LIGHT = M((1.0, 0.95, 0.85), 0.3, 0.0, 4.0)


def box(mb, lo, hi, mat, uv=1.0, faces="all", bevel=None):
    """A box with its edges chamfered (flat-shaded, like planed wood or cut stone): light catches every edge.
    Thin boards (under 1.5 cm) stay sharp."""
    sx, sy, sz = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    r = min(0.012, 0.18 * min(sx, sy, sz)) if bevel is None else bevel
    if faces != "all" or r < 0.0025:
        _plain_box(mb, lo, hi, mat, uv, faces)
        return
    x0, y0, x1, y1 = lo[0], lo[1], hi[0], hi[1]
    def ring(inset, z):
        a, b, c, d = x0 + inset, y0 + inset, x1 - inset, y1 - inset
        q = r - inset          # chamfer length on this ring
        return [V(p) for p in ((a + q, b, z), (c - q, b, z), (c, b + q, z), (c, d - q, z), (c - q, d, z), (a + q, d, z), (a, d - q, z), (a, b + q, z))]
    rings = [ring(r, lo[2]), ring(0.0, lo[2] + r), ring(0.0, hi[2] - r), ring(r, hi[2])]
    mb.loft(rings, mat, lambda ri, p: [], cap_start=True, cap_end=True, smooth=False)


def turned_leg(mb, c, h, r, mat, sides=10):
    """A lathe-turned leg: a foot, a taper, a bead, a block at the top."""
    c = V(c)
    prof = [(r * 0.75, 0.0), (r * 0.9, 0.02), (r * 0.7, 0.05), (r * 0.62, h * 0.35), (r * 0.95, h * 0.62), (r * 0.62, h * 0.66),
            (r * 0.8, h * 0.8), (r * 1.15, h * 0.84), (r * 1.15, h)]
    lathe(mb, prof, sides, mat, center=c)


def out(d, name, mats, fn):
    scene.reset()
    built = {k: (v.make(f"{name}_{k}", _kind_of(k)) if isinstance(v, M) else v) for k, v in mats.items()}
    mb = MeshBuilder()
    fn(mb)
    o = mb.to_object(name, built, recalc_normals=True)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{d}/{name}.glb", [o])


def cyl(mb, c, r, h, mat, sides=12, axis="z", caps=True):
    """A cylinder of radius r, length h, from c along +axis."""
    c = V(c)
    if axis == "z":
        lathe(mb, [(r, 0.0), (r, h)], sides, mat, center=c, cap_start=caps, cap_end=caps)
    else:
        d = {"x": V((1, 0, 0)), "y": V((0, 1, 0))}[axis]
        mb.tube([c, c + d * h], [r, r], sides, mat, [], cap_end=caps)


def rod(mb, a, b, r, mat, sides=6):
    mb.tube([V(a), V(b)], [r, r], sides, mat, [])


def sphere(mb, c, r, mat, rings=8, sides=12, sz=1.0):
    c = V(c)
    prof = [(r * math.sin(math.pi * k / rings) + 1e-4, -r * sz * math.cos(math.pi * k / rings)) for k in range(rings + 1)]
    lathe(mb, prof, sides, mat, z0=0.0, center=c, cap_start=False, cap_end=False)


def cone(mb, c, r0, r1, h, mat, sides=12):
    lathe(mb, [(r0, 0.0), (r1, h)], sides, mat, center=V(c))


def slab(mb, cx, cy, cz, sx, sy, sz, mat, uv=1.0):
    """A box from its centre and size."""
    box(mb, (cx - sx / 2, cy - sy / 2, cz - sz / 2), (cx + sx / 2, cy + sy / 2, cz + sz / 2), mat, uv)


def frame_rect(mb, cx, cz, w, h, t, y0, y1, mat):
    """A rectangular frame in the X-Z plane (a picture or window frame), bar thickness t, depth y0..y1."""
    box(mb, (cx - w / 2, y0, cz - h / 2), (cx + w / 2, y1, cz - h / 2 + t), mat, 0.3)
    box(mb, (cx - w / 2, y0, cz + h / 2 - t), (cx + w / 2, y1, cz + h / 2), mat, 0.3)
    box(mb, (cx - w / 2, y0, cz - h / 2 + t), (cx - w / 2 + t, y1, cz + h / 2 - t), mat, 0.3)
    box(mb, (cx + w / 2 - t, y0, cz - h / 2 + t), (cx + w / 2, y1, cz + h / 2 - t), mat, 0.3)


def legs(mb, w, d, h, r, mat, inset=0.04, z0=0.0, turned=True):
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = (sx * (w / 2 - inset), sy * (d / 2 - inset), z0)
            if turned and h > 0.15:
                turned_leg(mb, c, h, r * 1.3, mat)
            else:
                cyl(mb, c, r, h, mat, 8)


def torus(mb, c, R, r, mat, seg=20, sides=8, axis="z"):
    """A ring of tube radius r around c (in the XY plane for axis z, the XZ plane for axis y)."""
    c = V(c)
    pts = []
    for k in range(seg + 1):
        a = 2 * math.pi * k / seg
        p = V((math.cos(a) * R, math.sin(a) * R, 0)) if axis == "z" else V((math.cos(a) * R, 0, math.sin(a) * R))
        pts.append(c + p)
    mb.tube(pts, [r] * len(pts), sides, mat, [], cap_end=False)


__all__ = ["M", "V", "out", "cyl", "rod", "sphere", "cone", "slab", "frame_rect", "legs", "turned_leg", "torus", "box", "lathe", "rounded_box",
           "MARBLE", "DARKMARBLE", "GRANITE", "CERAMIC",
           "CHROME", "STEEL", "RUST", "BLACK", "RUBBER", "WHITE", "GLASS", "WOOD", "DARKWOOD", "CONCRETE", "BRASS", "PAPER", "LIGHT"]
