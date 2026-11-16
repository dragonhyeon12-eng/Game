"""The Observer: a black, too-tall, too-thin figure. Static: he never moves while watched.

Built from a stick skeleton (vertices + edges with per-vertex radii) through Blender's Skin modifier,
smoothed with Subdivision Surface, then roughened (bony, gaunt) and decimated for real time.
The game turns him pure black and glitchy (models slot "observer"), so the material here is a plain
matte black; the shape is what matters: hunched uneven shoulders, a head slightly too small and pushed
forward, arms hanging to the knees, long fingers, knock knees.

Faces Blender -Y (Godot +Z), feet on z = 0, 2.2 m tall.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector

from dp import geo, scene


def build(out_path):
    random.seed(5)
    scene.reset()
    pts = {}
    edges = []

    def p(name, xyz, r):
        pts[name] = (Vector(xyz), r)

    def e(a, b):
        edges.append((a, b))

    # spine (chest pushed forward: towards -Y), head small and tilted
    p("pelvis", (0, 0.0, 1.02), 0.13)
    p("waist", (0, -0.01, 1.22), 0.085)
    p("chest", (0, -0.08, 1.48), 0.13)
    p("upper", (0, -0.06, 1.66), 0.11)
    p("neck", (0.025, -0.16, 1.84), 0.042)
    p("jaw", (0.055, -0.24, 1.95), 0.07)
    p("head", (0.075, -0.23, 2.05), 0.095)
    p("crown", (0.095, -0.19, 2.14), 0.07)
    for a, b in (("pelvis", "waist"), ("waist", "chest"), ("chest", "upper"), ("upper", "neck"), ("neck", "jaw"),
                 ("jaw", "head"), ("head", "crown")):
        e(a, b)
    # arms: uneven shoulders, hanging to the knees
    for side, sh_h, sh_x in ((-1, 1.69, 0.21), (1, 1.645, 0.23)):
        s = "L" if side < 0 else "R"
        p("sh" + s, (side * sh_x, -0.02, sh_h), 0.06)
        p("elb" + s, (side * (sh_x + 0.05), 0.0, sh_h - 0.45), 0.04)
        p("wri" + s, (side * (sh_x + 0.07), -0.05, sh_h - 1.0), 0.032)
        p("pal" + s, (side * (sh_x + 0.075), -0.06, sh_h - 1.09), 0.036)
        e("upper", "sh" + s)
        e("sh" + s, "elb" + s)
        e("elb" + s, "wri" + s)
        e("wri" + s, "pal" + s)
        for f in range(4):
            spread = (f - 1.5) * 0.022
            k1 = f"k{f}{s}"
            k2 = f"m{f}{s}"
            k3 = f"t{f}{s}"
            base = pts["pal" + s][0]
            ln = (0.11, 0.135, 0.13, 0.1)[f] * 1.25
            p(k1, base + Vector((side * 0.005 + spread * side, -0.02 + spread * 0.5, -0.05)), 0.013)
            p(k2, base + Vector((side * 0.008 + spread * side * 1.3, -0.035 + spread * 0.5, -0.05 - ln)), 0.011)
            p(k3, base + Vector((side * 0.01 + spread * side * 1.5, -0.03 + spread * 0.5, -0.05 - ln * 1.8)), 0.006)
            e("pal" + s, k1)
            e(k1, k2)
            e(k2, k3)
        # thumb
        base = pts["pal" + s][0]
        p("th1" + s, base + Vector((-side * 0.02, -0.04, -0.03)), 0.012)
        p("th2" + s, base + Vector((-side * 0.03, -0.08, -0.11)), 0.008)
        e("pal" + s, "th1" + s)
        e("th1" + s, "th2" + s)
    # legs: long, thin, slightly knock-kneed
    for side in (-1, 1):
        s = "L" if side < 0 else "R"
        p("hip" + s, (side * 0.105, 0.0, 0.97), 0.06)
        p("knee" + s, (side * 0.075, -0.03, 0.53), 0.042)
        p("ank" + s, (side * 0.1, 0.01, 0.07), 0.03)
        p("toe" + s, (side * 0.105, -0.15, 0.025), 0.026)
        e("pelvis", "hip" + s)
        e("hip" + s, "knee" + s)
        e("knee" + s, "ank" + s)
        e("ank" + s, "toe" + s)

    obj = scene.skin_body("Observer", pts, edges, "pelvis", flat=("chest", "upper", "pelvis"))

    # gaunt, bony surface: sunken between ribs, knobbly joints, a little wrong everywhere
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    for v in bm.verts:
        co = v.co
        n = v.normal
        d = 0.006 * geo.fbm(co * 6.0, 3) + 0.003 * geo.fbm(co * 25.0, 2)
        if 1.32 < co.z < 1.64 and abs(co.x) < 0.16 and co.y < 0.02:          # ribs under the skin
            d -= 0.006 * (0.5 + 0.5 * math.cos(co.z * 105.0))
        for jn in ("kneeL", "kneeR", "elbL", "elbR"):
            jc = pts[jn][0]
            d += 0.012 * geo.gauss((co - jc).length, 0.035)
        v.co = co + n * d
    bm.to_mesh(obj.data)
    bm.free()
    dec = obj.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = 0.45
    scene.apply_modifiers(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    mat = scene.material("observer_black", base_color=(0.008, 0.008, 0.009), roughness=0.85)
    obj.data.materials.append(mat)
    print(f"  observer: {len(obj.data.vertices)} vertices, {sum(len(p.vertices) - 2 for p in obj.data.polygons)} triangles")
    scene.export_glb(out_path, [obj])
