"""A realistic shop mannequin, in jointed parts the game poses (models/creatures/mannequin.glb).

Fibreglass, glossy, with a waist seam and ball joints; a sculpted face (brow, sockets, nose, lips, chin,
ears) on an otherwise blank head. Separate meshes the game shows by "realism": Eyes (painted irises and
lashes), Lips (painted), Hair (a moulded wig).

Each part is built around its own pivot (the joint it hangs from), matching scripts/npc/mannequin.gd:
  Torso      pivot = chest (1.0 m up when standing); reaches down over the pelvis to the hip sockets
  Head       pivot = neck base (0.56 above the chest pivot)
  UpperArm   pivot = shoulder, hangs down 0.3
  Forearm_L / Forearm_R   pivot = elbow, with the hand
  Thigh      pivot = hip, 0.45 down to the knee
  Shin       pivot = knee, with the foot
Blender coords: +Z up, -Y = the mannequin's front (Godot +Z).
"""
import math

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder, gauss


def _ring(z, rx, ry, n=20, front=0.0, back=0.0, cx=0.0, cy=0.0):
    """An elliptical cross-section at height z; `front` / `back` push the front (-Y) / back out."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x = math.cos(a) * rx
        y = math.sin(a) * ry
        if y < 0:
            y -= front * (-math.sin(a)) ** 2
        else:
            y += back * math.sin(a) ** 2
        pts.append(Vector((cx + x, cy + y, z)))
    return pts


def _limb(mb, z0, z1, r0, r1, mat, bulge=0.0, bulge_at=0.5, n=14, segs=10):
    rings = []
    for i in range(segs + 1):
        f = i / segs
        z = z0 + (z1 - z0) * f
        r = r0 + (r1 - r0) * f + bulge * gauss(f - bulge_at, 0.25)
        rings.append(_ring(z, r, r * 0.92, n))
    mb.loft(rings, mat, lambda ri, p: [], cap_start=False, cap_end=False)     # (the joint balls close the ends)


def _ball(mb, c, r, mat, n=12):
    rings = []
    for i in range(1, 12):
        t = math.pi * i / 12
        rings.append(_ring(c.z + math.cos(t) * r, math.sin(t) * r, math.sin(t) * r, n, cx=c.x, cy=c.y))
    mb.loft(rings[::-1], mat, lambda ri, p: [], cap_start=True, cap_end=True)


def _torso(mb):
    # (z, half-width, half-depth, front, back)
    prof = [(-0.24, 0.06, 0.05, 0.0, 0.0), (-0.2, 0.15, 0.1, 0.0, 0.02), (-0.12, 0.175, 0.105, 0.0, 0.035),
            (-0.04, 0.165, 0.1, 0.0, 0.03), (0.04, 0.14, 0.09, 0.005, 0.0), (0.1, 0.132, 0.088, 0.008, 0.0),
            (0.2, 0.15, 0.095, 0.015, 0.0), (0.3, 0.17, 0.1, 0.03, 0.0), (0.38, 0.185, 0.1, 0.02, 0.005),
            (0.45, 0.2, 0.085, 0.0, 0.01), (0.5, 0.17, 0.07, 0.0, 0.0), (0.54, 0.09, 0.055, 0.0, 0.0), (0.565, 0.045, 0.042, 0.0, 0.0)]
    rings = [_ring(z, rx, ry, 24, f, b) for z, rx, ry, f, b in prof]
    mb.loft(rings, "plastic", lambda ri, p: [], cap_start=True, cap_end=True)
    # the waist joint: a thin dark seam
    rings = [_ring(0.065, 0.137, 0.091, 24), _ring(0.075, 0.1375, 0.0915, 24)]
    mb.loft(rings, "seam", lambda ri, p: [], cap_start=False, cap_end=False)
    # shoulder sockets
    for sx in (-1, 1):
        _ball(mb, Vector((sx * 0.19, 0.0, 0.44)), 0.05, "plastic")


def _head(mb, extras):
    """The neck, and a head: a sphere pushed and pulled into a face."""
    _limb(mb, -0.02, 0.1, 0.052, 0.047, "plastic", n=16, segs=3)
    c = Vector((0.0, 0.005, 0.175))
    nlat, nlon = 22, 28
    rings = []
    for i in range(1, nlat):
        th = math.pi * i / nlat                     # 0 = top
        ring = []
        for k in range(nlon):
            ph = 2 * math.pi * k / nlon             # 0 = +X; 3pi/2 = front (-Y)
            d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            r = Vector((0.088, 0.105, 0.125))
            p = Vector((d.x * r.x, d.y * r.y, d.z * r.z))
            # a narrower jaw and chin, a flatter face
            u = p.z / 0.125                         # -1 chin .. 1 crown
            front = max(0.0, -d.y)
            p.x *= 1.0 - 0.18 * max(0.0, -u) ** 1.5
            if d.y < 0:
                p.y *= 0.92
            x, z = p.x, p.z
            def bump(cx, cz, wx, wz, h):
                return h * math.exp(-((x - cx) / wx) ** 2 - ((z - cz) / wz) ** 2) * front ** 2
            push = 0.0
            push += bump(0.0, 0.035, 0.07, 0.016, 0.016)            # the brow
            push -= bump(0.032, 0.012, 0.02, 0.014, 0.016) + bump(-0.032, 0.012, 0.02, 0.014, 0.016)   # sockets
            push += bump(0.0, -0.012, 0.011, 0.03, 0.034)           # the nose
            push += bump(0.0, -0.04, 0.013, 0.008, 0.01)            # the tip
            push += bump(0.0, -0.055, 0.02, 0.006, 0.006)           # upper lip
            push += bump(0.0, -0.068, 0.017, 0.006, 0.005)          # lower lip
            push += bump(0.0, -0.1, 0.024, 0.014, 0.012)            # chin
            push += bump(0.045, -0.025, 0.02, 0.02, 0.006) + bump(-0.045, -0.025, 0.02, 0.02, 0.006)   # cheekbones
            p += d * push
            ring.append(c + p)
        rings.append(ring)
    mb.loft(rings, "plastic", lambda ri, p: [], cap_start=True, cap_end=True)
    # ears
    for sx in (-1, 1):
        e = c + Vector((sx * 0.088, 0.008, 0.0))
        _ball(mb, e, 0.016, "plastic", 8)
    # painted eyes: dark irises with a lash line, set into the sockets
    em = extras["eyes"]
    for sx in (-1, 1):
        e = c + Vector((sx * 0.032, -0.093, 0.012))
        _ball(em, e, 0.009, "iris", 10)
        em.tube([e + Vector((-0.012, -0.004, 0.006)), e + Vector((0.0, -0.007, 0.01)), e + Vector((0.012, -0.004, 0.006))], [0.0012] * 3, 5, "lash", [])
    lm = extras["lips"]
    lm.tube([c + Vector((-0.017, -0.1, -0.056)), c + Vector((0.0, -0.106, -0.054)), c + Vector((0.017, -0.1, -0.056))], [0.0022, 0.003, 0.0022], 8, "lips", [])
    lm.tube([c + Vector((-0.014, -0.1, -0.066)), c + Vector((0.0, -0.104, -0.069)), c + Vector((0.014, -0.1, -0.066))], [0.0022, 0.0034, 0.0022], 8, "lips", [])
    # a moulded bob: a shell over the crown and down the back
    hm = extras["hair"]
    rings = []
    for i in range(0, 13):
        th = math.pi * i / 18
        ring = []
        for k in range(28):
            ph = 2 * math.pi * k / 28
            d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            fringe = 1.0 if d.y > -0.3 else 0.0
            if th > math.pi * 0.42 and fringe == 0.0:
                d = Vector((math.sin(math.pi * 0.42) * math.cos(ph), math.sin(math.pi * 0.42) * math.sin(ph), math.cos(math.pi * 0.42)))
            ring.append(c + Vector((d.x * 0.097, d.y * 0.114, d.z * 0.134 + 0.004)))
        rings.append(ring)
    hm.loft(rings, "hair", lambda ri, p: [], cap_start=True, cap_end=False)


def _hand(mb, side):
    """A relaxed hand hanging from the wrist (z = 0), palm toward the body, fingers slightly curled."""
    s = side
    rings = []
    for z, w, d in ((0.0, 0.026, 0.017), (-0.03, 0.04, 0.016), (-0.07, 0.045, 0.014), (-0.085, 0.043, 0.012)):
        rings.append(_ring(z, d, w, 14))        # (the hand is flat in Y-Z: thin in X)
    mb.loft(rings, "plastic", lambda ri, p: [], cap_start=True, cap_end=True)
    for k, (off, ln) in enumerate(((-0.027, 0.068), (-0.009, 0.078), (0.009, 0.074), (0.026, 0.06))):
        base = Vector((0.0, off, -0.08))
        mid = base + Vector((-s * 0.006, off * 0.05, -ln * 0.55))
        tip = base + Vector((-s * 0.018, off * 0.08, -ln))
        mb.tube([base, mid, tip], [0.0098, 0.009, 0.0075], 8, "plastic", [])
    th0 = Vector((0.0, -0.04, -0.035))
    mb.tube([th0, th0 + Vector((-s * 0.02, -0.015, -0.03)), th0 + Vector((-s * 0.03, -0.01, -0.055))], [0.01, 0.009, 0.0075], 8, "plastic", [])


def build(out_path):
    scene.reset()
    gloss = 0.22
    M = {
        "plastic": scene.material("mannequin_plastic", base_color=(0.86, 0.8, 0.74), roughness=gloss),
        "seam": scene.material("mannequin_seam", base_color=(0.2, 0.17, 0.15), roughness=0.6),
        "iris": scene.material("mannequin_iris", base_color=(0.05, 0.08, 0.1), roughness=0.05),
        "lash": scene.material("mannequin_lash", base_color=(0.02, 0.02, 0.02), roughness=0.6),
        "lips": scene.material("mannequin_lips", base_color=(0.5, 0.26, 0.24), roughness=0.35),
        "hair": scene.material("mannequin_hair", base_color=(0.12, 0.08, 0.05), roughness=0.35),
    }
    objs = []
    parts = {}

    def part(name, fn):
        mb = MeshBuilder()
        fn(mb)
        parts[name] = mb
        return mb

    part("Torso", _torso)
    extras = {"eyes": MeshBuilder(), "lips": MeshBuilder(), "hair": MeshBuilder()}
    part("Head", lambda mb: _head(mb, extras))
    part("UpperArm", lambda mb: (_ball(mb, Vector((0, 0, 0)), 0.048, "plastic"), _limb(mb, -0.02, -0.29, 0.043, 0.035, "plastic", bulge=0.006, bulge_at=0.2)))
    for side, nm in ((1, "Forearm_L"), (-1, "Forearm_R")):
        def fa(mb, side=side):
            _ball(mb, Vector((0, 0, 0)), 0.038, "plastic")
            _limb(mb, 0.0, -0.25, 0.035, 0.025, "plastic", bulge=0.006, bulge_at=0.25)
            h = MeshBuilder()
            _hand(h, side)
            mb.merge(h, Vector((0, 0, -0.25)))
        part(nm, fa)
    part("Thigh", lambda mb: (_ball(mb, Vector((0, 0, 0)), 0.07, "plastic"), _limb(mb, 0.0, -0.44, 0.075, 0.048, "plastic", bulge=0.008, bulge_at=0.25, n=16)))

    def shin(mb):
        _ball(mb, Vector((0, 0, 0)), 0.05, "plastic")
        _limb(mb, 0.0, -0.4, 0.048, 0.03, "plastic", bulge=0.012, bulge_at=0.3, n=16)
        # the foot: a lofted wedge forward (-Y), heel to toe
        rings = []
        for y, w, h, z in ((0.035, 0.03, 0.04, -0.42), (0.0, 0.035, 0.06, -0.43), (-0.06, 0.042, 0.05, -0.45), (-0.13, 0.046, 0.032, -0.465), (-0.18, 0.04, 0.02, -0.47), (-0.2, 0.025, 0.012, -0.472)):
            ring = []
            for k in range(14):
                a = 2 * math.pi * k / 14
                ring.append(Vector((math.cos(a) * w, y, z + max(0.0, math.sin(a)) * h - 0.012 * max(0.0, -math.sin(a)))))
            rings.append(ring)
        mb.loft(rings, "plastic", lambda ri, p: [], cap_start=True, cap_end=True)
    part("Shin", shin)
    for name, mb in parts.items():
        objs.append(mb.to_object(name, M, recalc_normals=True))
    for name, key in (("Eyes", "eyes"), ("Lips", "lips"), ("Hair", "hair")):
        objs.append(extras[key].to_object(name, M, recalc_normals=True))
    tris = sum(mb.tri_count() for mb in list(parts.values()) + list(extras.values()))
    print(f"  mannequin: {tris} triangles in {len(objs)} parts")
    scene.export_glb(out_path, objs)
    return objs
