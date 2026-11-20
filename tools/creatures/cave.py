"""THE DEEP's sea cave (models/props/cave.glb): a natural tunnel into the cliff and the chamber at its end.

Built in the game's own coordinates (the glb sits at the zone origin): the mouth at (2, 0, -140) in Godot
terms, winding back to a domed chamber round (2, 0, -179) with room at its back for the glowing doorway
at z -183.4. The floor is flattened so it can be walked; walls, roof and floor are lumpy rock (fBm noise),
seen from inside. Plus "CaveMouth": a ragged ring of rock on the cliff face that hides the opening's edges.
"""
import math

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder, fbm


def G(x, y, z):
    """Godot (x, y up, z) -> Blender (x, -z, y)."""
    return Vector((x, -z, y))


def _rock_material():
    h = tex.fbm(256, 256, 6, 6, 31, 5)
    f1, f2 = tex.cellular(256, 256, 10, 10, 32)
    c = np.clip(f2 - f1, 0.0, 1.0)
    hh = h * 0.7 + c * 0.3
    a = np.stack([0.12, 0.13, 0.13])[None, None, :] * (0.6 + 0.8 * hh)[..., None]
    a[..., 1] += 0.025 * (hh > 0.6)          # a little green growth on the high bits
    return scene.material("cave_rock", tex.to_image("cave_rock_albedo", np.clip(a, 0, 1)),
                          normal_tex=tex.to_image("cave_rock_normal", tex.normal_from_height(hh, 3.0), non_color=True),
                          roughness=0.85, double_sided=True)


def _path():
    """(Godot centre point on the floor, half-width, height) along the cave."""
    pts = []
    n = 60
    for i in range(n + 1):
        t = i / n
        z = -139.3 - t * 45.5                               # mouth (in front of the cliff face) .. the back
        x = 2.0 + math.sin(t * 5.0) * 1.3 * (1.0 - t) + math.sin(t * 11.0) * 0.3
        if t < 0.7:
            w, h = 1.9 + 0.5 * math.sin(t * 9.0) ** 2, 3.0 + 0.4 * math.sin(t * 7.0)
        else:                                               # the chamber: opens up, then closes at the back
            u = (t - 0.7) / 0.3
            w = 1.9 + 4.3 * math.sin(min(u * 1.25, 1.0) * math.pi * 0.5) * (1.0 - max(0.0, u - 0.85) * 4.0)
            h = 3.0 + 3.0 * math.sin(min(u * 1.25, 1.0) * math.pi * 0.5) * (1.0 - max(0.0, u - 0.85) * 3.0)
            x = 2.0 + (x - 2.0) * (1.0 - u)
        pts.append((Vector((x, 0.0, z)), max(w, 1.2), max(h, 2.6)))
    return pts


def build(out_dir):
    scene.reset()
    M = {"rock": _rock_material()}
    mb = MeshBuilder()
    path = _path()
    sides = 26
    rings = []
    for i, (c, w, h) in enumerate(path):
        nxt = path[min(i + 1, len(path) - 1)][0]
        prv = path[max(i - 1, 0)][0]
        fwd = (nxt - prv).normalized()
        right = Vector((-fwd.z, 0.0, fwd.x)).normalized()
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides - math.pi * 0.5      # start at the floor
            ox = math.cos(a) * w
            oy = (math.sin(a) + 1.0) * 0.5 * h               # 0 at the floor, h at the roof
            p = c + right * ox + Vector((0, oy, 0))
            n = fbm(Vector((p.x * 0.45, p.y * 0.45, p.z * 0.45)), 4)
            bump = n * 0.75
            if oy < 0.25:                                     # the floor: nearly flat, a little uneven
                p.y = 0.02 + n * 0.06
                p += right * (bump * 0.3 * math.copysign(1.0, ox))
            else:
                d = (right * ox + Vector((0, oy - h * 0.5, 0))).normalized()
                p += d * bump
            ring.append(G(p.x, p.y, p.z))
        rings.append(ring)
    mb.loft(rings, "rock", lambda ri, p: [], cap_start=False, cap_end=True, u_scale=4.0)
    cave = mb.to_object("Cave", M, recalc_normals=False)

    # the ragged ring of rock round the mouth, on the cliff face (z = -137)
    rm = MeshBuilder()
    inner, outer = [], []
    for k in range(40):
        a = 2 * math.pi * k / 40
        n1 = fbm(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, 1.3)), 3)
        n2 = fbm(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, 7.7)), 3)
        ix, iy = math.cos(a) * 1.55, 1.55 + math.sin(a) * 1.85
        iy = max(iy, -0.05)
        ox, oy = math.cos(a) * (6.0 + n2 * 3.0), 1.55 + math.sin(a) * (5.0 + n2 * 3.0)
        oy = max(oy, -0.4)
        inner.append(G(2.0 + ix * (0.95 + n1 * 0.25), iy, -139.6 - n1 * 0.3))
        outer.append(G(2.0 + ox, oy, -140.05))
    mid = []
    for a, b in zip(inner, outer):
        m = (a + b) * 0.5
        m.y -= 0.9 + fbm(m * 0.7, 3) * 0.5          # bulging out from the cliff (Blender -Y = Godot +Z, toward you)
        mid.append(m)
    rm.loft([inner, mid, outer], "rock", lambda ri, p: [], cap_start=False, cap_end=False, u_scale=4.0)
    mouth = rm.to_object("CaveMouth", M, recalc_normals=False)
    print(f"  cave: {mb.tri_count() + rm.tri_count()} triangles")
    scene.export_glb(f"{out_dir}/cave.glb", [cave, mouth])
