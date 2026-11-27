"""The park plaza at the heart of the summer city (models/props/*.glb): a grand fountain, a rotunda, lantern
lamps, cast-iron benches, hydrangea planters, and a segment of the elevated ring road that circles the city.
Face Godot +Z (Blender -Y), origin on the ground at the footprint centre unless noted. Stone is "__marble"
(polished), wood "__wood", iron "__metal": the game gives them real surfaces.

fountain_grand water levels (Godot y, for the game's water): basin 0.62 (r 5.15), tier 1 1.98 (r 2.95),
tier 2 3.12 (r 1.6), tier 3 4.02 (r 0.75); the nozzle at 4.45.
"""
import math
import random

from lib import *  # noqa: F401,F403

STONE = M((0.78, 0.77, 0.74), 0.18, k="marble")
STONE_D = M((0.6, 0.59, 0.56), 0.3, k="marble")
IRON = M((0.05, 0.05, 0.055), 0.4, 0.6, k="metal")
GLOW = M((1.0, 0.86, 0.6), 0.2, 0.0, 3.5)


def build(d):
    random.seed(33)

    # ---------------------------------------------------------------- the fountain
    def fountain(mb):
        # two broad steps, the basin wall with a rounded coping, the basin floor
        lathe(mb, [(6.6, 0.0), (6.6, 0.16), (6.05, 0.16), (6.05, 0.32)], 48, "stone_d", cap_end=False)
        lathe(mb, [(6.05, 0.32), (5.75, 0.32), (5.72, 0.75), (5.85, 0.8), (5.85, 0.9), (5.6, 0.95), (5.25, 0.92), (5.2, 0.8), (5.2, 0.3)], 64, "stone", cap_start=False, cap_end=False)
        lathe(mb, [(5.2, 0.3), (0.0, 0.3)], 48, "floor", cap_start=False, cap_end=False)
        # the central pedestal, carved: a plinth, a fluted shaft, a collar
        lathe(mb, [(1.3, 0.3), (1.3, 0.55), (1.05, 0.62), (0.75, 0.7), (0.55, 0.9), (0.5, 1.3), (0.62, 1.42), (0.62, 1.5)], 24, "stone", cap_start=False, cap_end=False)
        # tier 1: a wide bowl with a moulded lip
        lathe(mb, [(0.62, 1.5), (1.4, 1.55), (2.4, 1.7), (3.05, 1.88), (3.15, 2.0), (3.12, 2.06), (2.95, 2.04), (2.9, 1.95), (0.0, 1.95)], 48, "stone", cap_start=False, cap_end=False)
        # the stem between the tiers, with a bulb
        lathe(mb, [(0.4, 1.95), (0.42, 2.2), (0.6, 2.4), (0.42, 2.6), (0.32, 2.75), (0.4, 2.85)], 20, "stone", cap_start=False, cap_end=False)
        # tier 2
        lathe(mb, [(0.4, 2.85), (1.0, 2.9), (1.6, 3.02), (1.72, 3.12), (1.7, 3.17), (1.6, 3.15), (1.56, 3.08), (0.0, 3.08)], 40, "stone", cap_start=False, cap_end=False)
        lathe(mb, [(0.25, 3.08), (0.27, 3.3), (0.4, 3.45), (0.25, 3.6), (0.22, 3.78)], 16, "stone", cap_start=False, cap_end=False)
        # tier 3, and the finial the water comes out of
        lathe(mb, [(0.22, 3.78), (0.55, 3.84), (0.82, 3.96), (0.86, 4.04), (0.78, 4.06), (0.74, 4.0), (0.0, 4.0)], 32, "stone", cap_start=False, cap_end=False)
        lathe(mb, [(0.18, 4.0), (0.2, 4.15), (0.12, 4.3), (0.07, 4.42), (0.04, 4.45), (0.0, 4.46)], 16, "brass", cap_start=False)
        # carved lion-head spouts round the first tier's rim, facing out
        for k in range(8):
            a = k * math.pi / 4
            c = V((math.cos(a) * 3.12, math.sin(a) * 3.12, 1.9))
            sphere(mb, c, 0.11, "stone_d", 5, 8)
            mb.tube([c, c + V((math.cos(a) * 0.12, math.sin(a) * 0.12, -0.03))], [0.05, 0.035], 8, "brass", [])
    out(d, "fountain_grand", {"stone": STONE, "stone_d": STONE_D, "floor": M((0.35, 0.55, 0.6), 0.3, k="stone"), "brass": BRASS}, fountain)

    # ---------------------------------------------------------------- the rotunda
    def rotunda(mb):
        R = 3.0
        # three steps
        for k, (r, z) in enumerate(((R + 0.9, 0.0), (R + 0.6, 0.18), (R + 0.3, 0.36))):
            lathe(mb, [(r, z), (r, z + 0.18), (0.0, z + 0.18)], 40, "stone", cap_end=False)
        floor_z = 0.54
        n = 8
        for k in range(n):
            a = 2 * math.pi * k / n + math.pi / n
            c = V((math.cos(a) * R, math.sin(a) * R, 0))
            # base, a fluted shaft (a 16-sided lathe with entasis), an Ionic-ish capital
            lathe(mb, [(0.3, floor_z), (0.3, floor_z + 0.12), (0.24, floor_z + 0.18), (0.22, floor_z + 0.3)], 16, "stone", center=c, cap_start=False, cap_end=False)
            shaft = [(0.22, floor_z + 0.3), (0.215, floor_z + 1.6), (0.19, floor_z + 3.2)]
            lathe(mb, shaft, 16, "stone", center=c, cap_start=False, cap_end=False)
            lathe(mb, [(0.19, floor_z + 3.2), (0.24, floor_z + 3.28), (0.3, floor_z + 3.38), (0.3, floor_z + 3.48)], 16, "stone", center=c, cap_start=False, cap_end=False)
        top = floor_z + 3.48
        # the entablature ring, a cornice, the drum
        lathe(mb, [(R + 0.4, top), (R + 0.4, top + 0.45), (R + 0.55, top + 0.55), (R + 0.55, top + 0.65), (R + 0.3, top + 0.7),
                   (R - 0.3, top + 0.7), (R - 0.35, top), (R - 0.4, top)], 40, "stone", cap_start=False, cap_end=False)
        # the dome, patinated metal, ribbed; a lantern and a finial
        prof = [(R + 0.25 - 0.0, top + 0.7)]
        for k in range(1, 11):
            t = k / 10 * math.pi / 2
            prof.append(((R + 0.25) * math.cos(t) + 0.0001, top + 0.7 + 1.9 * math.sin(t)))
        lathe(mb, prof, 40, "dome", cap_start=False)
        for k in range(16):
            a = 2 * math.pi * k / 16
            pts = [V((math.cos(a) * p[0] * 1.01, math.sin(a) * p[0] * 1.01, p[1] + 0.01)) for p in prof[:-1]]
            mb.tube(pts, [0.035] * len(pts), 4, "dome_rib", [])
        lathe(mb, [(0.35, top + 2.55), (0.35, top + 2.9), (0.42, top + 2.95), (0.0, top + 3.1)], 12, "dome")
        lathe(mb, [(0.05, top + 3.1), (0.04, top + 3.5), (0.0, top + 3.55)], 8, "brass")
        sphere(mb, (0, 0, top + 3.3), 0.08, "brass", 5, 8)
        # the ceiling under the dome
        lathe(mb, [(R - 0.35, top), (0.0, top + 0.05)], 40, "ceiling", cap_start=False, cap_end=False)
    out(d, "rotunda", {"stone": STONE, "dome": M((0.22, 0.27, 0.3), 0.45, 0.6, k="metal"), "dome_rib": M((0.3, 0.35, 0.36), 0.4, 0.7),
                       "brass": BRASS, "ceiling": M((0.9, 0.88, 0.84), 0.6)}, rotunda)

    # ---------------------------------------------------------------- the lantern lamp
    def lamp_lantern(mb):
        # a fluted cast-iron base, a tapering post, a collar; the lantern: four glowing panes under a pointed roof
        lathe(mb, [(0.22, 0.0), (0.22, 0.08), (0.17, 0.12), (0.15, 0.5), (0.11, 0.62), (0.08, 0.7)], 8, "iron")
        lathe(mb, [(0.07, 0.7), (0.055, 3.4), (0.08, 3.45), (0.1, 3.55), (0.06, 3.62)], 8, "iron", cap_start=False)
        for k in range(4):           # little scroll brackets under the lantern
            a = k * math.pi / 2 + math.pi / 4
            pts = [V((math.cos(a) * r, math.sin(a) * r, z)) for r, z in ((0.06, 3.3), (0.16, 3.42), (0.2, 3.55), (0.16, 3.6))]
            mb.tube(pts, [0.012] * 4, 4, "iron", [])
        z0, z1 = 3.62, 4.12
        box(mb, (-0.17, -0.17, z0 - 0.04), (0.17, 0.17, z0), "iron", 0.1)
        for sx in (-1, 1):
            for sy in (-1, 1):
                box(mb, (sx * 0.17 - 0.02, sy * 0.17 - 0.02, z0), (sx * 0.17 + 0.02, sy * 0.17 + 0.02, z1), "iron", 0.05)
        box(mb, (-0.15, -0.15, z0), (0.15, 0.15, z1), "glow", 0.2, bevel=0.0)
        pts = [V((-0.22, -0.22, z1)), V((0.22, -0.22, z1)), V((0.22, 0.22, z1)), V((-0.22, 0.22, z1))]
        apex = V((0, 0, z1 + 0.3))
        for i in range(4):
            a, b = pts[i], pts[(i + 1) % 4]
            mb.add_face([mb.add_vert(a, []), mb.add_vert(b, []), mb.add_vert(apex, [])], [(0, 0), (1, 0), (0.5, 1)], "iron", smooth=False)
        sphere(mb, (0, 0, z1 + 0.34), 0.04, "iron", 4, 6)
    out(d, "lamp_lantern", {"iron": IRON, "glow": GLOW}, lamp_lantern)

    # ---------------------------------------------------------------- the bench
    def bench_classic(mb):       # 1.9 m along X; cast-iron scroll ends, oak slats; seat faces Godot +Z
        for sx in (-0.85, 0.85):
            # the end frame: a front leg curling up into the armrest, a back leg sweeping up into the backrest
            front = [V((sx, -0.28, 0.0)), V((sx, -0.26, 0.2)), V((sx, -0.24, 0.42)), V((sx, -0.27, 0.6)), V((sx, -0.22, 0.66)), V((sx, -0.12, 0.64)), V((sx, 0.1, 0.62))]
            back = [V((sx, 0.3, 0.0)), V((sx, 0.24, 0.25)), V((sx, 0.18, 0.42)), V((sx, 0.24, 0.6)), V((sx, 0.32, 0.85)), V((sx, 0.34, 0.92))]
            mb.tube(front, [0.03] * len(front), 6, "iron", [])
            mb.tube(back, [0.03] * len(back), 6, "iron", [])
            mb.tube([V((sx, -0.25, 0.4)), V((sx, 0.2, 0.4))], [0.022, 0.022], 6, "iron", [])
            sx2 = sx
            curl = [V((sx2, -0.27 + 0.06 * math.cos(t), 0.6 + 0.06 * math.sin(t))) for t in [i * 0.6 for i in range(9)]]
            mb.tube(curl, [0.015] * len(curl), 4, "iron", [])
        for k in range(5):                     # seat slats
            y = -0.24 + k * 0.105
            box(mb, (-0.98, y, 0.42), (0.98, y + 0.085, 0.46), "wood", 0.5)
        for k in range(3):                     # back slats, leaning back
            z = 0.55 + k * 0.12
            y = 0.2 + (z - 0.55) * 0.35
            box(mb, (-0.98, y, z), (0.98, y + 0.03, z + 0.09), "wood", 0.5)
    out(d, "bench_classic", {"iron": IRON, "wood": M((0.32, 0.18, 0.08), 0.45, k="wood")}, bench_classic)

    # ---------------------------------------------------------------- hydrangeas
    def hydrangea(mb, c, s, mats):
        """One shrub: a mound of leaves, and big round flower heads made of little four-petal florets."""
        c = V(c)
        for k in range(14):        # leaves: pointed ovals at angles
            a = random.uniform(0, 2 * math.pi)
            r = random.uniform(0.1, 0.42) * s
            base = c + V((math.cos(a) * r, math.sin(a) * r, random.uniform(0.1, 0.45) * s))
            out_ = V((math.cos(a), math.sin(a), random.uniform(0.1, 0.6))).normalized()
            side = out_.cross(V((0, 0, 1))).normalized() * 0.09 * s
            tip = base + out_ * 0.22 * s
            ids = [mb.add_vert(p, []) for p in (base, base + out_ * 0.1 * s + side, tip, base + out_ * 0.1 * s - side)]
            mb.add_face(ids, [(0, 0), (1, 0.5), (0, 1), (-1, 0.5)], "leaf", smooth=False)
        for k in range(random.randint(4, 6)):   # flower heads
            a = random.uniform(0, 2 * math.pi)
            r = random.uniform(0.0, 0.3) * s
            hc = c + V((math.cos(a) * r, math.sin(a) * r, random.uniform(0.45, 0.62) * s))
            hr = random.uniform(0.11, 0.15) * s
            m = random.choice(mats)
            for f in range(18):
                # florets on a dome: each a small flat cross of petals facing out
                u = random.uniform(0, 2 * math.pi)
                v = random.uniform(-0.2, 1.0)
                n = V((math.cos(u) * math.sqrt(1 - v * v), math.sin(u) * math.sqrt(1 - v * v), v))
                p = hc + n * hr
                t1 = n.cross(V((0, 0, 1)) if abs(n.z) < 0.9 else V((1, 0, 0))).normalized() * hr * 0.32
                t2 = n.cross(t1).normalized() * hr * 0.32
                ids = [mb.add_vert(q, []) for q in (p + t1, p + t2, p - t1, p - t2)]
                mb.add_face(ids, [(1, 0.5), (0.5, 1), (0, 0.5), (0.5, 0)], m, smooth=False)

    flower_mats = {"leaf": M((0.12, 0.3, 0.1), 0.6, ds=True), "w1": M((0.95, 0.96, 0.95), 0.6, ds=True),
                   "w2": M((0.85, 0.9, 0.98), 0.6, ds=True), "b1": M((0.62, 0.72, 0.95), 0.6, ds=True)}

    def planter_hydrangea(mb):   # a raised stone planter, 3.6 x 1.1 x 0.55, full of white hydrangeas
        box(mb, (-1.8, -0.55, 0.0), (1.8, 0.55, 0.5), "stone", 0.5)
        box(mb, (-1.86, -0.61, 0.5), (1.86, 0.61, 0.58), "stone", 0.5)
        box(mb, (-1.7, -0.45, 0.5), (1.7, 0.45, 0.56), "soil", 0.5, bevel=0.0)
        for k in range(6):
            hydrangea(mb, (-1.45 + k * 0.58 + random.uniform(-0.08, 0.08), random.uniform(-0.12, 0.12), 0.5), random.uniform(1.0, 1.25), ["w1", "w1", "w2", "b1"])
    out(d, "planter_hydrangea", dict(flower_mats, stone=STONE, soil=M((0.18, 0.12, 0.07), 1.0)), planter_hydrangea)

    def hydrangea_bush(mb):      # a loose shrub for the flower beds, about 1.2 m across
        for k in range(3):
            a = k * 2.1
            hydrangea(mb, (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0), random.uniform(1.0, 1.3), ["w1", "w2", "b1", "w1"])
    out(d, "hydrangea_bush", flower_mats, hydrangea_bush)

    # ---------------------------------------------------------------- the ring road in the sky
    def viaduct_segment(mb):     # 22 m of elevated road along X, deck at z=0 (the game sets the height), one pier
        L, W = 22.0, 11.0
        box(mb, (-L / 2, -W / 2, -0.9), (L / 2, W / 2, 0.0), "concrete", 1.0)
        for sy in (-1, 1):
            box(mb, (-L / 2, sy * W / 2 - (0.35 if sy > 0 else 0.0), 0.0), (L / 2, sy * W / 2 + (0.0 if sy > 0 else 0.35), 1.05), "concrete", 1.0)
            box(mb, (-L / 2, sy * (W / 2 + 0.05) - 0.05, -0.95), (L / 2, sy * (W / 2 + 0.05) + 0.05, 1.1), "trim", 1.0, bevel=0.0)
        box(mb, (-L / 2, -W / 2 + 0.4, 0.0), (L / 2, W / 2 - 0.4, 0.02), "road", 1.0, bevel=0.0)
        for k in range(4):
            x = -L / 2 + 1.0 + k * 6.0
            box(mb, (x, -0.08, 0.02), (x + 3.0, 0.08, 0.03), "line", 0.1, bevel=0.0)
    VM = {"concrete": M((0.82, 0.83, 0.84), 0.55, k="stone"), "trim": M((0.92, 0.93, 0.94), 0.3),
          "road": M((0.12, 0.12, 0.13), 0.8), "line": M((0.95, 0.95, 0.9), 0.5)}
    out(d, "viaduct_segment", VM, viaduct_segment)

    def viaduct_pier(mb):        # the pier under a segment: a tapering column, its top at z=0 (under the deck), 60 m down
        lathe(mb, [(1.6, -60.0), (1.25, -6.0), (1.6, -1.6), (2.4, -0.9)], 16, "concrete", cap_start=False, cap_end=False)
    out(d, "viaduct_pier", VM, viaduct_pier)
