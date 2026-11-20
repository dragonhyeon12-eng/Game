"""The resting places (models/props/*.glb): a white room that feels like home, and the two items you can
carry - a music box and pills.

  music_box     walnut box, brass corners and crank, velvet inside, a comb and pinned cylinder;
                the lid is its own mesh ("Lid", hinged along its back edge) so the game can open it
  pill_bottle   amber bottle, white child-proof cap, a paper label
  pill          one two-tone capsule
  shelf_white   a painted wooden shelf unit (three shelves)
  armchair      an upholstered armchair, plump cushions, a throw over one arm
  bed_white     bed frame, mattress, duvet with a turned-down fold, two pillows
  table_lamp    a ceramic lamp with a fabric shade (glowing)
  side_table    a little round table on three legs
  flower_vase   a glass vase with stems and soft white flowers
  rug_round     a round wool rug
Blender: +Z up, +Y = Godot -Z. Sizes in metres.
"""
import math
import random

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder
from kit import box


def _export(name, out_dir, objects_fn):
    scene.reset()
    objs = objects_fn()
    tris = sum(mb.tri_count() for mb, _ in objs)
    print(f"  {name}: {tris} triangles")
    scene.export_glb(f"{out_dir}/{name}.glb", [o for _, o in objs])


def _wood(name, rgb, seed, grain=40):
    g = tex.fbm(256, 256, 2, grain, seed, 4)
    a = np.stack(rgb)[None, None, :] * (0.72 + 0.4 * g)[..., None]
    h = g
    return (tex.to_image(name + "_albedo", np.clip(a, 0, 1)),
            tex.to_image(name + "_normal", tex.normal_from_height(h, 1.2), non_color=True))


def _fabric(name, rgb, seed, weave=64):
    n = tex.fbm(128, 128, 8, 8, seed, 3)
    yy, xx = np.mgrid[0:128, 0:128] / 128.0
    w = 0.5 + 0.5 * np.sin(xx * weave * math.pi) * np.sin(yy * weave * math.pi)
    a = np.stack(rgb)[None, None, :] * (0.86 + 0.1 * n + 0.06 * w)[..., None]
    return (tex.to_image(name + "_albedo", np.clip(a, 0, 1)),
            tex.to_image(name + "_normal", tex.normal_from_height(w * 0.6 + n * 0.4, 0.8), non_color=True))


def lathe(mb, profile, sides, mat, z0=0.0, cap_start=True, cap_end=True, smooth=True, center=Vector((0, 0, 0))):
    """A surface of revolution: profile [(radius, z)], around +Z."""
    rings = []
    for r, z in profile:
        rings.append([center + Vector((math.cos(a) * r, math.sin(a) * r, z0 + z)) for a in
                      (2 * math.pi * k / sides for k in range(sides))])
    mb.loft(rings, mat, lambda ri, p: [], cap_start=cap_start, cap_end=cap_end, smooth=smooth)


def rounded_box(mb, c, size, r, mat, segs=3):
    """A box with rounded vertical edges (cushions, mattress): a lofted rounded-rectangle extrusion,
    with the top and bottom edges bevelled by `r`."""
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    def outline(inset):
        pts = []
        for qx, qy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
            cx, cy = qx * (sx - r), qy * (sy - r)
            for k in range(segs + 1):
                a = math.radians(a0 + 90 * k / segs)
                rr = max(r - inset, 0.001)
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        return pts
    rings = []
    for z, inset in ((-sz, r * 0.6), (-sz + r * 0.35, r * 0.1), (-sz + r, 0.0), (sz - r, 0.0), (sz - r * 0.35, r * 0.1), (sz, r * 0.6)):
        rings.append([c + Vector((x, y, z)) for x, y in outline(inset)])
    mb.loft(rings, mat, lambda ri, p: [], cap_start=True, cap_end=True, smooth=True)


# ------------------------------------------------------------------ the music box

def _music_box(out_dir):
    def make():
        walnut_a, walnut_n = _wood("walnut", (0.32, 0.17, 0.09), 11, 60)
        M = {
            "walnut": scene.material("mb_walnut", walnut_a, normal_tex=walnut_n, roughness=0.32),
            "brass": scene.material("mb_brass", base_color=(0.85, 0.62, 0.28), roughness=0.25, metallic=1.0),
            "velvet": scene.material("mb_velvet", base_color=(0.42, 0.04, 0.08), roughness=0.95),
            "steel": scene.material("mb_steel", base_color=(0.75, 0.75, 0.78), roughness=0.2, metallic=1.0),
            "inlay": scene.material("mb_inlay", base_color=(0.85, 0.75, 0.55), roughness=0.4),
        }
        W, D, H = 0.16, 0.11, 0.065       # the box
        mb = MeshBuilder()
        t = 0.008
        box(mb, (-W / 2, -D / 2, 0), (W / 2, D / 2, t), "walnut", 0.2)                         # floor
        for lo, hi in (((-W / 2, -D / 2, 0), (W / 2, -D / 2 + t, H)), ((-W / 2, D / 2 - t, 0), (W / 2, D / 2, H)),
                       ((-W / 2, -D / 2, 0), (-W / 2 + t, D / 2, H)), ((W / 2 - t, -D / 2, 0), (W / 2, D / 2, H))):
            box(mb, lo, hi, "walnut", 0.2)
        box(mb, (-W / 2 + t, -D / 2 + t, t), (W / 2 - t, D / 2 - t, t + 0.004), "velvet", 0.1)   # velvet floor
        # the movement: a pinned cylinder and a steel comb, in a little well on the left
        mb.tube([Vector((-0.05, -0.02, 0.03)), Vector((0.0, -0.02, 0.03))], [0.011, 0.011], 16, "brass", [], cap_start=True)
        for k in range(18):
            x = -0.048 + k * 0.0026
            box(mb, (x, -0.006, 0.026), (x + 0.0016, 0.02, 0.029), "steel", 0.05)
        box(mb, (-0.052, 0.018, 0.02), (0.002, 0.026, 0.034), "steel", 0.05)
        for k in range(26):
            a = random.random() * 2 * math.pi
            x = -0.048 + random.random() * 0.046
            p = Vector((x, -0.02 + math.cos(a) * 0.0115, 0.03 + math.sin(a) * 0.0115))
            box(mb, p - Vector((0.0006, 0.0006, 0.0006)), p + Vector((0.0006, 0.0006, 0.0006)), "steel", 0.05)
        # brass corner caps and little feet
        for sx in (-1, 1):
            for sy in (-1, 1):
                c = Vector((sx * (W / 2 - 0.004), sy * (D / 2 - 0.004), 0))
                box(mb, c - Vector((0.006, 0.006, 0.0)), c + Vector((0.006, 0.006, 0.012)), "brass", 0.05)
                lathe(mb, [(0.0, -0.006), (0.006, -0.006), (0.007, -0.002), (0.005, 0.0)], 10, "brass", center=Vector((sx * (W / 2 - 0.012), sy * (D / 2 - 0.012), 0)))
        # the crank, out of the right side
        mb.tube([Vector((W / 2, 0, 0.032)), Vector((W / 2 + 0.012, 0, 0.032))], [0.003, 0.003], 8, "brass", [], cap_start=True)
        mb.tube([Vector((W / 2 + 0.012, 0, 0.032)), Vector((W / 2 + 0.012, 0, 0.056))], [0.0025, 0.0025], 8, "brass", [])
        mb.tube([Vector((W / 2 + 0.012, 0, 0.056)), Vector((W / 2 + 0.026, 0, 0.056))], [0.0045, 0.0045], 10, "walnut", [], cap_start=True)
        body = mb.to_object("MusicBox", M, recalc_normals=False)
        # the lid: hinged along the back edge (y = +D/2, z = H): its origin is the hinge
        lm = MeshBuilder()
        lt = 0.012
        box(lm, (-W / 2, -D, 0), (W / 2, 0, lt), "walnut", 0.2)
        box(lm, (-W / 2 + 0.008, -D + 0.008, -0.002), (W / 2 - 0.008, -0.008, 0.0), "velvet", 0.1)      # velvet lining
        box(lm, (-0.03, -D / 2 - 0.02, lt), (0.03, -D / 2 + 0.02, lt + 0.0015), "inlay", 0.05)          # an inlaid star... a lozenge
        box(lm, (-0.008, -D - 0.004, 0.002), (0.008, -D, 0.01), "brass", 0.05)                          # the clasp
        lid = lm.to_object("Lid", M, recalc_normals=False)
        lid.location = (0, D / 2, H)
        return [(mb, body), (lm, lid)]
    _export("music_box", out_dir, make)


# ------------------------------------------------------------------ pills

def _pills(out_dir):
    def bottle():
        label = np.ones((64, 128, 3)) * np.array([0.95, 0.94, 0.9])
        label[18:24, 10:118] = (0.15, 0.25, 0.55)
        label[30:33, 10:90] = (0.3, 0.3, 0.3)
        label[38:41, 10:70] = (0.3, 0.3, 0.3)
        label[46:49, 10:100] = (0.3, 0.3, 0.3)
        M = {
            "amber": scene.material("pb_amber", base_color=(0.55, 0.25, 0.05), roughness=0.08, metallic=0.0, alpha=0.75),
            "cap": scene.material("pb_cap", base_color=(0.95, 0.95, 0.93), roughness=0.45),
            "label": scene.material("pb_label", tex.to_image("pb_label", label), roughness=0.8),
        }
        mb = MeshBuilder()
        lathe(mb, [(0.0, 0.0), (0.019, 0.0), (0.021, 0.004), (0.021, 0.058), (0.017, 0.064), (0.012, 0.068), (0.012, 0.072)], 24, "amber", cap_end=False)
        lathe(mb, [(0.0215, 0.016), (0.0215, 0.052)], 24, "label", cap_start=False, cap_end=False)
        lathe(mb, [(0.0, 0.07), (0.0145, 0.07), (0.0155, 0.072), (0.0155, 0.088), (0.014, 0.09), (0.0, 0.09)], 24, "cap")
        for k in range(24):     # ridges on the cap
            a = 2 * math.pi * k / 24
            p = Vector((math.cos(a) * 0.0157, math.sin(a) * 0.0157, 0.08))
            box(mb, p - Vector((0.0008, 0.0008, 0.007)), p + Vector((0.0008, 0.0008, 0.007)), "cap", 0.05)
        return [(mb, mb.to_object("PillBottle", M, recalc_normals=False))]
    _export("pill_bottle", out_dir, bottle)

    def pill():
        M = {"a": scene.material("pill_a", base_color=(0.95, 0.95, 0.97), roughness=0.3),
             "b": scene.material("pill_b", base_color=(0.35, 0.6, 0.85), roughness=0.3)}
        mb = MeshBuilder()
        r, L = 0.0042, 0.0095
        for half, mat in ((-1, "a"), (1, "b")):
            prof = [(0.0, half * (L + r))] + [(r * math.sin(math.radians(a)), half * (L + r * math.cos(math.radians(a)))) for a in range(15, 91, 15)] + [(r, 0.0)]
            if half < 0:
                prof = prof
            rings = []
            for rr, z in prof:
                rings.append([Vector((z, math.cos(t) * max(rr, 0.0001), math.sin(t) * max(rr, 0.0001))) for t in (2 * math.pi * k / 14 for k in range(14))])
            mb.loft(rings if half > 0 else rings[::-1], mat, lambda ri, p: [], cap_start=False, cap_end=False)
        return [(mb, mb.to_object("Pill", M, recalc_normals=True))]
    _export("pill", out_dir, pill)


# ------------------------------------------------------------------ furniture

def _furniture(out_dir):
    def white_wood():
        a, n = _wood("whitewood", (0.93, 0.92, 0.88), 5, 30)
        return scene.material("whitewood", a, normal_tex=n, roughness=0.55)

    def shelf():
        M = {"wood": white_wood()}
        mb = MeshBuilder()
        W, D, H = 1.2, 0.32, 1.6
        for x in (-W / 2, W / 2 - 0.025):
            box(mb, (x, -D / 2, 0), (x + 0.025, D / 2, H), "wood", 0.5)
        for z in (0.06, 0.55, 1.05, H - 0.025):
            box(mb, (-W / 2, -D / 2, z), (W / 2, D / 2, z + 0.025), "wood", 0.5)
        box(mb, (-W / 2, D / 2 - 0.01, 0), (W / 2, D / 2, H), "wood", 0.5)                # the back
        box(mb, (-W / 2, -D / 2, 0), (W / 2, -D / 2 + 0.02, 0.06), "wood", 0.5)           # the plinth
        return [(mb, mb.to_object("Shelf", M, recalc_normals=False))]
    _export("shelf_white", out_dir, shelf)

    def armchair():
        fa, fn = _fabric("chair_linen", (0.86, 0.82, 0.74), 3)
        ta, tn = _fabric("chair_throw", (0.62, 0.72, 0.8), 9, 120)
        M = {"linen": scene.material("chair_linen", fa, normal_tex=fn, roughness=0.95),
             "throw": scene.material("chair_throw", ta, normal_tex=tn, roughness=0.95),
             "leg": scene.material("chair_leg", base_color=(0.35, 0.22, 0.12), roughness=0.4)}
        mb = MeshBuilder()
        rounded_box(mb, Vector((0, 0, 0.3)), (0.82, 0.78, 0.22), 0.06, "linen")             # base
        rounded_box(mb, Vector((0, 0.04, 0.46)), (0.62, 0.66, 0.14), 0.06, "linen")         # seat cushion
        rounded_box(mb, Vector((0, 0.34, 0.66)), (0.66, 0.16, 0.62), 0.07, "linen")         # back
        for sx in (-1, 1):
            rounded_box(mb, Vector((sx * 0.36, 0.0, 0.52)), (0.14, 0.76, 0.26), 0.06, "linen")   # arms
        rounded_box(mb, Vector((-0.36, -0.05, 0.66)), (0.17, 0.5, 0.04), 0.015, "throw")    # a throw over one arm
        rounded_box(mb, Vector((-0.44, -0.05, 0.5)), (0.03, 0.5, 0.3), 0.012, "throw")
        for sx in (-1, 1):
            for sy in (-1, 1):
                lathe(mb, [(0.022, 0.0), (0.028, 0.18)], 10, "leg", center=Vector((sx * 0.34, sy * 0.32, 0.0)))
        return [(mb, mb.to_object("Armchair", M, recalc_normals=False))]
    _export("armchair", out_dir, armchair)

    def bed():
        da, dn = _fabric("duvet", (0.95, 0.95, 0.94), 21, 40)
        M = {"frame": white_wood(),
             "sheet": scene.material("sheet", da, normal_tex=dn, roughness=0.92),
             "duvet": scene.material("duvet", da, normal_tex=dn, roughness=0.95),
             "blanket": scene.material("blanket", base_color=(0.72, 0.8, 0.86), roughness=0.95)}
        mb = MeshBuilder()
        W, L = 1.5, 2.05
        box(mb, (-W / 2 - 0.04, -L / 2, 0.18), (W / 2 + 0.04, L / 2, 0.3), "frame", 0.5)          # frame
        for sx in (-1, 1):
            for sy in (-1, 1):
                box(mb, (sx * (W / 2) - 0.04, sy * (L / 2) - 0.04, 0), (sx * (W / 2) + 0.04, sy * (L / 2) + 0.04, 0.2), "frame", 0.3)
        box(mb, (-W / 2 - 0.04, L / 2, 0), (W / 2 + 0.04, L / 2 + 0.06, 1.05), "frame", 0.5)      # headboard
        rounded_box(mb, Vector((0, 0, 0.42)), (W, L - 0.04, 0.24), 0.06, "sheet")                 # mattress
        rounded_box(mb, Vector((0, -0.18, 0.565)), (W + 0.04, L - 0.46, 0.07), 0.035, "duvet")    # duvet
        rounded_box(mb, Vector((0, 0.48, 0.585)), (W + 0.04, 0.28, 0.035), 0.017, "duvet")        # turned down
        rounded_box(mb, Vector((0, -0.62, 0.61)), (W + 0.06, 0.55, 0.04), 0.02, "blanket")        # a blanket at the foot
        for sx in (-1, 1):
            rounded_box(mb, Vector((sx * 0.36, L / 2 - 0.28, 0.6)), (0.62, 0.38, 0.13), 0.06, "sheet")   # pillows
        return [(mb, mb.to_object("Bed", M, recalc_normals=False))]
    _export("bed_white", out_dir, bed)

    def lamp():
        sa, sn = _fabric("shade", (0.98, 0.94, 0.85), 4, 90)
        M = {"ceramic": scene.material("lamp_ceramic", base_color=(0.78, 0.86, 0.9), roughness=0.15),
             "shade": scene.material("lamp_shade", sa, normal_tex=sn, roughness=0.9, emission_color=(1.0, 0.85, 0.6), emission_strength=1.5, double_sided=True),
             "brass": scene.material("lamp_brass", base_color=(0.85, 0.65, 0.3), roughness=0.3, metallic=1.0)}
        mb = MeshBuilder()
        lathe(mb, [(0.0, 0.0), (0.07, 0.0), (0.09, 0.03), (0.1, 0.12), (0.085, 0.22), (0.035, 0.27), (0.02, 0.3), (0.0, 0.3)], 24, "ceramic")
        mb.tube([Vector((0, 0, 0.3)), Vector((0, 0, 0.42))], [0.008, 0.008], 8, "brass", [])
        lathe(mb, [(0.17, 0.36), (0.11, 0.52)], 28, "shade", cap_start=False, cap_end=False)
        return [(mb, mb.to_object("TableLamp", M, recalc_normals=False))]
    _export("table_lamp", out_dir, lamp)

    def side_table():
        M = {"wood": white_wood()}
        mb = MeshBuilder()
        lathe(mb, [(0.0, 0.58), (0.27, 0.58), (0.28, 0.6), (0.27, 0.62), (0.0, 0.62)], 32, "wood")
        for k in range(3):
            a = 2 * math.pi * k / 3
            top = Vector((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.58))
            foot = Vector((math.cos(a) * 0.24, math.sin(a) * 0.24, 0.0))
            mb.tube([foot, top], [0.016, 0.02], 8, "wood", [], cap_start=True)
        return [(mb, mb.to_object("SideTable", M, recalc_normals=False))]
    _export("side_table", out_dir, side_table)

    def vase():
        M = {"glass": scene.material("vase_glass", base_color=(0.85, 0.93, 0.95), roughness=0.05, alpha=0.4),
             "stem": scene.material("vase_stem", base_color=(0.25, 0.42, 0.2), roughness=0.6),
             "petal": scene.material("vase_petal", base_color=(0.98, 0.97, 0.95), roughness=0.7, double_sided=True),
             "heart": scene.material("vase_heart", base_color=(0.95, 0.8, 0.3), roughness=0.6)}
        mb = MeshBuilder()
        lathe(mb, [(0.0, 0.0), (0.05, 0.0), (0.06, 0.05), (0.045, 0.16), (0.03, 0.2), (0.04, 0.22)], 20, "glass", cap_end=False)
        rnd = random.Random(7)
        for k in range(5):
            a = 2 * math.pi * k / 5 + rnd.random() * 0.4
            tip = Vector((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.42 + rnd.random() * 0.08))
            mid = Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.25))
            mb.tube([Vector((0, 0, 0.04)), mid, tip], [0.003, 0.003, 0.003], 5, "stem", [])
            for p in range(6):
                pa = 2 * math.pi * p / 6
                d = Vector((math.cos(pa), math.sin(pa), 0.25))
                ids = [mb.add_vert(tip, []), mb.add_vert(tip + d * 0.03 + Vector((-d.y, d.x, 0)) * 0.012, []),
                       mb.add_vert(tip + d * 0.042, []), mb.add_vert(tip + d * 0.03 - Vector((-d.y, d.x, 0)) * 0.012, [])]
                mb.add_face(ids, [(0.5, 0), (0, 0.6), (0.5, 1), (1, 0.6)], "petal", True)
            box(mb, tip - Vector((0.006, 0.006, 0.004)), tip + Vector((0.006, 0.006, 0.006)), "heart", 0.05)
        return [(mb, mb.to_object("FlowerVase", M, recalc_normals=False))]
    _export("flower_vase", out_dir, vase)

    def rug():
        h = tex.fbm(256, 256, 30, 30, 8, 3)
        yy, xx = np.mgrid[0:256, 0:256] / 256.0
        rr = np.hypot(xx - 0.5, yy - 0.5)
        band = (np.sin(rr * 60.0) > 0.7) * 0.12
        a = np.stack([0.85, 0.8, 0.72])[None, None, :] * (0.88 + 0.12 * h - band)[..., None]
        M = {"wool": scene.material("rug_wool", tex.to_image("rug_albedo", np.clip(a, 0, 1)),
                                    normal_tex=tex.to_image("rug_normal", tex.normal_from_height(h, 1.5), non_color=True), roughness=1.0)}
        mb = MeshBuilder()
        lathe(mb, [(0.0, 0.0), (1.1, 0.0), (1.12, 0.012), (0.0, 0.012)], 48, "wool")
        return [(mb, mb.to_object("Rug", M, recalc_normals=False))]
    _export("rug_round", out_dir, rug)


def build(out_dir):
    random.seed(17)
    _music_box(out_dir)
    _pills(out_dir)
    _furniture(out_dir)
