"""THE PLACE WE REMEMBER: the park's own furniture and landmarks (models/props/*.glb).
Face Godot +Z (Blender -Y), origin on the ground at the footprint centre unless noted. Stone "__marble"/"__stone",
wood "__wood", metal "__metal" (the game gives them real surfaces).
"""
import math
import random

from lib import *  # noqa: F401,F403

WSTONE = M((0.86, 0.85, 0.82), 0.3, k="marble")        # the white stone of the arch and the plinths
GREY = M((0.62, 0.6, 0.56), 0.6, k="stone")
IRON = M((0.06, 0.06, 0.065), 0.45, 0.6, k="metal")
GREEN_PAINT = M((0.1, 0.24, 0.16), 0.45, 0.2, k="metal")
BRONZE = M((0.42, 0.3, 0.14), 0.35, 0.9, k="metal")
SIGN = M((0.92, 0.9, 0.84), 0.6)


def build(d):
    random.seed(5)

    def coffee_cup(mb):        # a takeaway cup: paper, a cardboard sleeve, a white lid with a sip hole (14 cm)
        lathe(mb, [(0.0, 0.0), (0.03, 0.0), (0.042, 0.13)], 20, "paper", cap_end=False)
        lathe(mb, [(0.034, 0.035), (0.04, 0.095)], 20, "sleeve", cap_start=False, cap_end=False)
        lathe(mb, [(0.044, 0.128), (0.045, 0.14), (0.038, 0.148), (0.0, 0.15)], 20, "lid", cap_start=False)
        box(mb, (0.012, -0.004, 0.148), (0.026, 0.004, 0.152), "dark", 0.05, bevel=0.0)
    out(d, "coffee_cup", {"paper": M((0.96, 0.95, 0.92), 0.6), "sleeve": M((0.55, 0.38, 0.22), 0.8), "lid": M((0.97, 0.97, 0.96), 0.35),
                          "dark": M((0.08, 0.06, 0.05), 0.5)}, coffee_cup)

    def signpost(mb):          # a green post with four finger boards at angles (the game writes on them)
        lathe(mb, [(0.09, 0.0), (0.09, 0.1), (0.06, 0.16), (0.055, 2.6), (0.07, 2.65), (0.0, 2.75)], 12, "post")
        sphere(mb, (0, 0, 2.78), 0.06, "post", 5, 8)
        for k, a in enumerate((20.0, 110.0, 200.0, 290.0)):
            r = math.radians(a)
            z = 2.35 - k * 0.24
            dx, dy = math.cos(r), math.sin(r)
            c = V((dx * 0.42, dy * 0.42, z))
            # a board pointing along (dx, dy), with an arrow tip
            w = 0.7
            p = [c - V((dx, dy, 0)) * w / 2 + V((0, 0, -0.09)), c + V((dx, dy, 0)) * w / 2 + V((0, 0, -0.09)),
                 c + V((dx, dy, 0)) * (w / 2 + 0.1), c + V((dx, dy, 0)) * w / 2 + V((0, 0, 0.09)), c - V((dx, dy, 0)) * w / 2 + V((0, 0, 0.09))]
            n = V((-dy, dx, 0)) * 0.015
            front = [mb.add_vert(q + n, []) for q in p]
            back = [mb.add_vert(q - n, []) for q in p]
            mb.add_face(front, [(0, 0), (1, 0), (1, 0.5), (1, 1), (0, 1)], "board", smooth=False)
            mb.add_face(list(reversed(back)), [(0, 1), (1, 1), (1, 0.5), (1, 0), (0, 0)], "board", smooth=False)
            for i in range(5):
                a0, a1, b0, b1 = front[i], front[(i + 1) % 5], back[i], back[(i + 1) % 5]
                mb.add_face([a0, b0, b1, a1], [(0, 0), (0, 1), (1, 1), (1, 0)], "rim", smooth=False)
    out(d, "signpost", {"post": GREEN_PAINT, "board": SIGN, "rim": GREEN_PAINT}, signpost)

    def map_board(mb):         # a park map on two posts under a little roof; the map face is 1.6 x 1.1, centre 1.45 up, facing +Z
        for x in (-0.95, 0.95):
            box(mb, (x - 0.05, -0.05, 0.0), (x + 0.05, 0.05, 2.25), "wood", 0.5)
        box(mb, (-0.88, -0.03, 0.85), (0.88, 0.04, 2.05), "wood", 0.5)
        frame_rect(mb, 0, 1.45, 1.72, 1.22, 0.06, -0.06, -0.03, "trim")
        pts = [V((-1.15, -0.3, 2.2)), V((1.15, -0.3, 2.2)), V((1.15, 0.0, 2.38)), V((-1.15, 0.0, 2.38))]
        mb.add_face([mb.add_vert(p, []) for p in pts], [(0, 0), (1, 0), (1, 1), (0, 1)], "roof", smooth=False)
        pts = [V((-1.15, 0.0, 2.38)), V((1.15, 0.0, 2.38)), V((1.15, 0.3, 2.2)), V((-1.15, 0.3, 2.2))]
        mb.add_face([mb.add_vert(p, []) for p in pts], [(0, 0), (1, 0), (1, 1), (0, 1)], "roof", smooth=False)
    out(d, "map_board", {"wood": M((0.3, 0.18, 0.09), 0.5, k="wood"), "trim": GREEN_PAINT, "roof": M((0.18, 0.2, 0.18), 0.6, 0.3, ds=True)}, map_board)

    def marker(mb):            # a park marker: a squat stone post with a bronze dial on top (the game makes it glow)
        lathe(mb, [(0.26, 0.0), (0.26, 0.08), (0.2, 0.14), (0.17, 0.85), (0.22, 0.9), (0.22, 0.98)], 16, "stone")
        lathe(mb, [(0.2, 0.98), (0.2, 1.01), (0.0, 1.02)], 24, "bronze")
        for k in range(12):
            a = k * math.pi / 6
            box(mb, (math.cos(a) * 0.15 - 0.008, math.sin(a) * 0.15 - 0.008, 1.015), (math.cos(a) * 0.15 + 0.008, math.sin(a) * 0.15 + 0.008, 1.03), "dark", 0.05, bevel=0.0)
        mb.tube([V((0, 0, 1.02)), V((0, 0.12, 1.05))], [0.012, 0.004], 6, "dark", [])
        box(mb, (-0.1, -0.185, 0.5), (0.1, -0.165, 0.68), "bronze", 0.1)
    out(d, "marker", {"stone": WSTONE, "bronze": BRONZE, "dark": M((0.1, 0.08, 0.05), 0.4, 0.8)}, marker)

    def bench_blue(mb):        # THE bench: slatted, painted a faded blue, with a little brass plaque on its back
        for sx in (-0.88, 0.88):
            box(mb, (sx - 0.04, -0.28, 0.0), (sx + 0.04, 0.22, 0.42), "frame", 0.3)
            box(mb, (sx - 0.04, 0.16, 0.42), (sx + 0.04, 0.26, 0.9), "frame", 0.3)
            box(mb, (sx - 0.04, -0.3, 0.6), (sx + 0.04, 0.2, 0.65), "frame", 0.3)
        for k in range(5):
            y = -0.26 + k * 0.1
            box(mb, (-0.98, y, 0.42), (0.98, y + 0.08, 0.46), "slat", 0.5)
        for k in range(4):
            z = 0.52 + k * 0.1
            box(mb, (-0.98, 0.18, z), (0.98, 0.22, z + 0.075), "slat", 0.5)
        box(mb, (-0.1, 0.175, 0.72), (0.1, 0.18, 0.77), "brass", 0.05, bevel=0.0)
    out(d, "bench_blue", {"frame": M((0.1, 0.1, 0.1), 0.5, 0.5, k="metal"), "slat": M((0.42, 0.55, 0.65), 0.55, k="wood"), "brass": BRASS}, bench_blue)

    def flower_round(mb):      # a round raised bed, 3.2 m across: a stone kerb, soil, rings of tulips and a standard rose in the middle
        lathe(mb, [(1.6, 0.0), (1.6, 0.3), (1.45, 0.32), (1.45, 0.22), (0.0, 0.22)], 40, "kerb", cap_end=False)
        for ring, (r, n, col) in enumerate(((1.25, 26, "t1"), (0.9, 18, "t2"), (0.55, 12, "t1"))):
            for k in range(n):
                a = 2 * math.pi * k / n + ring * 0.2
                c = V((math.cos(a) * r, math.sin(a) * r, 0.22))
                h = 0.32 + random.uniform(-0.05, 0.05)
                rod(mb, c, c + V((0, 0, h)), 0.006, "stem", 4)
                lathe(mb, [(0.0, h - 0.06), (0.03, h - 0.04), (0.032, h), (0.022, h + 0.03)], 6, col, center=c, cap_end=False)
                for s in (-1, 1):
                    leaf = [c + V((0, 0, 0.05)), c + V((s * 0.04, 0.01, 0.16)), c + V((s * 0.01, 0, 0.24))]
                    mb.add_face([mb.add_vert(p, []) for p in leaf], [(0, 0), (1, 0.5), (0, 1)], "leaf", smooth=False)
        rod(mb, (0, 0, 0.22), (0, 0, 1.1), 0.02, "stem", 6)
        for k in range(14):
            u = V((random.gauss(0, 1), random.gauss(0, 1), random.gauss(0, 0.7))).normalized()
            sphere(mb, V((0, 0, 1.25)) + u * 0.22, 0.05, random.choice(("rose", "rose", "leafb")), 4, 6)
    out(d, "flower_round", {"kerb": WSTONE, "soil": M((0.15, 0.1, 0.06), 1.0), "t1": M((0.85, 0.15, 0.2), 0.5, ds=True), "t2": M((0.98, 0.85, 0.3), 0.5, ds=True),
                            "stem": M((0.2, 0.38, 0.12), 0.6), "leaf": M((0.18, 0.36, 0.1), 0.6, ds=True), "rose": M((0.95, 0.75, 0.78), 0.5),
                            "leafb": M((0.15, 0.32, 0.09), 0.6)}, flower_round)

    def rose_arch(mb):         # a painted iron arch over a path (2.4 wide, 2.7 high), climbing roses up both sides
        for sx in (-1.2, 1.2):
            for sy in (-0.25, 0.25):
                cyl(mb, (sx, sy, 0.0), 0.02, 2.1, "iron", 6)
        for sy in (-0.25, 0.25):
            pts = [V((math.cos(t) * 1.2, sy, 2.1 + math.sin(t) * 0.6)) for t in [i * math.pi / 14 for i in range(15)]]
            mb.tube(pts, [0.02] * len(pts), 6, "iron", [])
        for k in range(9):
            t = k * math.pi / 8
            rod(mb, (math.cos(t) * 1.2, -0.25, 2.1 + math.sin(t) * 0.6), (math.cos(t) * 1.2, 0.25, 2.1 + math.sin(t) * 0.6), 0.012, "iron", 4)
        for _ in range(140):     # rose foliage and blooms climbing the arch
            t = random.uniform(0, 1)
            if t < 0.38:
                p = V((random.choice((-1.2, 1.2)), random.uniform(-0.3, 0.3), t / 0.38 * 2.1))
            else:
                a = (t - 0.38) / 0.62 * math.pi
                p = V((math.cos(a) * 1.2, random.uniform(-0.3, 0.3), 2.1 + math.sin(a) * 0.6))
            p += V((random.uniform(-0.12, 0.12), 0, random.uniform(-0.08, 0.08)))
            if random.random() < 0.25:
                sphere(mb, p, random.uniform(0.04, 0.06), random.choice(("rose", "rose2")), 4, 6)
            else:
                n = V((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))).normalized()
                t1 = n.orthogonal().normalized() * 0.07
                t2 = n.cross(t1).normalized() * 0.05
                mb.add_face([mb.add_vert(q, []) for q in (p - t1, p + t2, p + t1, p - t2)], [(0, 0.5), (0.5, 1), (1, 0.5), (0.5, 0)], "leaf", smooth=False)
    out(d, "rose_arch", {"iron": M((0.92, 0.92, 0.9), 0.45, 0.3), "leaf": M((0.13, 0.3, 0.08), 0.6, ds=True), "rose": M((0.92, 0.35, 0.45), 0.5),
                         "rose2": M((0.98, 0.9, 0.88), 0.5)}, rose_arch)

    def pond(mb):              # a small round pond's stone rim (4 m across), its bed; the game adds water and lilies
        lathe(mb, [(2.2, 0.0), (2.2, 0.18), (2.05, 0.24), (1.85, 0.2), (1.82, -0.1), (1.6, -0.5), (0.0, -0.55)], 40, "stone", cap_end=False)
        for k in range(18):
            a = 2 * math.pi * k / 18 + random.uniform(-0.05, 0.05)
            c = V((math.cos(a) * 2.05, math.sin(a) * 2.05, 0.2))
            sphere(mb, c, random.uniform(0.18, 0.26), "stone2", 4, 6, 0.55)
    out(d, "pond", {"stone": GREY, "stone2": M((0.55, 0.53, 0.5), 0.7, k="stone")}, pond)

    def lily_pads(mb):         # a cluster of lily pads and two flowers, floating (origin at the water line)
        for k in range(9):
            c = V((random.uniform(-0.9, 0.9), random.uniform(-0.9, 0.9), 0.005))
            r = random.uniform(0.12, 0.2)
            gap = random.uniform(0, 2 * math.pi)
            pts = [c + V((math.cos(gap + 0.35 + t * (2 * math.pi - 0.7) / 12) * r, math.sin(gap + 0.35 + t * (2 * math.pi - 0.7) / 12) * r, 0)) for t in range(13)]
            mb.fan(c, pts, "pad", [])
        for c in (V((0.3, -0.2, 0.02)), V((-0.4, 0.35, 0.02))):
            for k in range(8):
                a = k * math.pi / 4
                tip = c + V((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.05))
                s = V((-math.sin(a), math.cos(a), 0)) * 0.025
                mb.add_face([mb.add_vert(q, []) for q in (c, c + (tip - c) * 0.5 + s, tip, c + (tip - c) * 0.5 - s)], [(0, 0), (1, 0), (1, 1), (0, 1)], "petal", smooth=False)
            sphere(mb, c + V((0, 0, 0.03)), 0.015, "eye", 3, 6)
    out(d, "lily_pads", {"pad": M((0.14, 0.32, 0.1), 0.4, ds=True), "petal": M((0.98, 0.9, 0.92), 0.5, ds=True), "eye": M((0.95, 0.8, 0.2), 0.5)}, lily_pads)

    def urn_plinth(mb):        # a stone urn on a square plinth (sculpture), 2.2 m
        box(mb, (-0.4, -0.4, 0.0), (0.4, 0.4, 0.15), "stone", 0.4)
        box(mb, (-0.32, -0.32, 0.15), (0.32, 0.32, 1.05), "stone", 0.4)
        box(mb, (-0.38, -0.38, 1.05), (0.38, 0.38, 1.15), "stone", 0.4)
        lathe(mb, [(0.12, 1.15), (0.2, 1.2), (0.12, 1.3), (0.14, 1.4), (0.3, 1.6), (0.36, 1.8), (0.32, 1.95), (0.38, 2.0), (0.36, 2.05), (0.0, 2.04)], 24, "stone")
        for sx in (-1, 1):
            pts = [V((sx * 0.3, 0, 1.92)), V((sx * 0.44, 0, 1.88)), V((sx * 0.44, 0, 1.7)), V((sx * 0.32, 0, 1.62))]
            mb.tube(pts, [0.025] * 4, 6, "stone", [])
    out(d, "urn_plinth", {"stone": WSTONE}, urn_plinth)

    def obelisk(mb):           # a slim stone obelisk on a stepped base, 4.5 m
        box(mb, (-0.7, -0.7, 0.0), (0.7, 0.7, 0.25), "stone", 0.4)
        box(mb, (-0.5, -0.5, 0.25), (0.5, 0.5, 0.5), "stone", 0.4)
        lathe(mb, [(0.32, 0.5), (0.22, 4.1), (0.0, 4.5)], 4, "stone", center=V((0, 0, 0)))
    out(d, "obelisk", {"stone": WSTONE}, obelisk)

    def stone_archway(mb):     # the exit: a great white stone arch (6 m opening, 9.5 m high), pilasters, a keystone, a cornice
        W, Hs = 3.0, 6.0         # half-opening, springing height
        for sx in (-1, 1):
            box(mb, (sx * W, -0.8, 0.0) if sx > 0 else (-W - 1.6, -0.8, 0.0), (W + 1.6, 0.8, Hs) if sx > 0 else (-W, 0.8, Hs), "stone", 0.6)
            box(mb, (sx * (W + 0.8) - 0.9, -0.95, 0.0), (sx * (W + 0.8) + 0.9, 0.95, 0.5), "stone", 0.6)          # plinth
            box(mb, (sx * (W + 0.8) - 0.95, -0.95, Hs - 0.3), (sx * (W + 0.8) + 0.95, 0.95, Hs), "stone", 0.6)     # impost
        # the arch: voussoirs from springing to keystone, and the spandrel walls above
        n = 15
        for k in range(n):
            a0 = math.pi * k / n
            a1 = math.pi * (k + 1) / n
            for side in (-0.8, 0.8):
                pass
            ri, ro = W, W + 1.1
            p = [V((math.cos(a0) * ri, -0.8, Hs + math.sin(a0) * ri)), V((math.cos(a1) * ri, -0.8, Hs + math.sin(a1) * ri)),
                 V((math.cos(a1) * ro, -0.8, Hs + math.sin(a1) * ro)), V((math.cos(a0) * ro, -0.8, Hs + math.sin(a0) * ro))]
            q = [v + V((0, 1.6, 0)) for v in p]
            ids_f = [mb.add_vert(v, []) for v in p]
            ids_b = [mb.add_vert(v, []) for v in q]
            mb.add_face(ids_f, [(0, 0), (1, 0), (1, 1), (0, 1)], "stone", smooth=False)
            mb.add_face(list(reversed(ids_b)), [(0, 0), (1, 0), (1, 1), (0, 1)], "stone", smooth=False)
            mb.add_face([ids_f[0], ids_f[1], ids_b[1], ids_b[0]], [(0, 0), (1, 0), (1, 1), (0, 1)], "soffit", smooth=False)
            mb.add_face([ids_f[3], ids_b[3], ids_b[2], ids_f[2]], [(0, 0), (1, 0), (1, 1), (0, 1)], "stone", smooth=False)
        box(mb, (-0.45, -0.9, Hs + W - 0.2), (0.45, 0.9, Hs + W + 1.35), "stone", 0.5)                                  # keystone
        for sx in (-1, 1):                                                                                                # spandrels
            box(mb, (sx * 2.2 - 1.0 if sx > 0 else -W - 1.6, -0.8, Hs + 1.9), (W + 1.6 if sx > 0 else -2.2 + 1.0, 0.8, Hs + W + 1.1), "stone", 0.6)
        box(mb, (-W - 1.9, -1.0, Hs + W + 1.1), (W + 1.9, 1.0, Hs + W + 1.6), "stone", 0.6)                             # cornice
        box(mb, (-W - 1.6, -0.85, Hs + W + 1.6), (W + 1.6, 0.85, Hs + W + 2.3), "stone", 0.6)                           # attic
    out(d, "stone_archway", {"stone": M((0.92, 0.91, 0.88), 0.35, k="marble"), "soffit": M((0.85, 0.84, 0.8), 0.5, k="marble")}, stone_archway)

    def garden_gate(mb):       # a double iron gate (4 m opening, 3 m high); its leaves are separate meshes ("LeafL", "LeafR")
        pass
    # the gate is built as three objects
    from dp import scene as _sc
    from dp.geo import MeshBuilder as _MB
    _sc.reset()
    GM = {"iron": IRON.make("garden_gate_iron"), "stone": WSTONE.make("garden_gate_stone"), "gold": BRASS.make("garden_gate_gold")}
    posts = _MB()
    for sx in (-1, 1):
        box(posts, (sx * 2.45 - 0.35, -0.35, 0.0), (sx * 2.45 + 0.35, 0.35, 3.4), "stone", 0.4)
        box(posts, (sx * 2.45 - 0.42, -0.42, 3.4), (sx * 2.45 + 0.42, 0.42, 3.55), "stone", 0.4)
        sphere(posts, (sx * 2.45, 0, 3.8), 0.22, "stone", 6, 10)
    leaves = []
    for name, sx in (("LeafL", -1), ("LeafR", 1)):
        mb = _MB()
        # built hanging from its hinge at x=0 and reaching toward the middle (x = -sx * 2.1)
        w = 2.1
        for k in range(11):
            x = -sx * (0.08 + k * (w - 0.16) / 10)
            top = 2.75 + 0.25 * math.sin(math.pi * (k / 10)) if sx < 0 else 2.75 + 0.25 * math.sin(math.pi * (k / 10))
            cyl(mb, (x, 0, 0.05), 0.016, top - 0.05, "iron", 6)
            cone(mb, (x, 0, top), 0.03, 0.0, 0.12, "gold", 6)
        for z in (0.15, 1.1, 2.4):
            cyl(mb, (min(0, -sx * w), 0, z), 0.025, w, "iron", 6, "x")
        for k in range(4):            # scrolls in the middle band
            x = -sx * (0.3 + k * 0.5)
            pts = [V((x + 0.18 * math.cos(t), 0, 1.75 + 0.18 * math.sin(t))) for t in [i * 0.6 for i in range(11)]]
            mb.tube(pts, [0.01] * len(pts), 4, "iron", [])
        leaves.append((mb, name))
    objs = [(posts, posts.to_object("Posts", GM, recalc_normals=True))]
    for mb, name in leaves:
        objs.append((mb, mb.to_object(name, GM, recalc_normals=True)))
    _sc.export_glb(f"{d}/garden_gate.glb", [o for _, o in objs])
    print("  garden_gate")

    def clock_tower(mb):       # a tall pale clock tower with a green copper spire (seen only from far away: 48 m)
        box(mb, (-4.0, -4.0, 0.0), (4.0, 4.0, 30.0), "stone", 2.0)
        box(mb, (-4.4, -4.4, 30.0), (4.4, 4.4, 31.0), "stone", 2.0)
        box(mb, (-3.6, -3.6, 31.0), (3.6, 3.6, 38.0), "stone", 2.0)
        for k in range(4):
            a = k * math.pi / 2
            n = V((math.cos(a), math.sin(a), 0))
            c = n * 3.62 + V((0, 0, 34.5))
            mb.tube([c, c + n * 0.05], [2.2, 2.2], 28, "face", [])
            for h in range(12):
                t = h * math.pi / 6
                side = n.cross(V((0, 0, 1)))
                p = c + n * 0.06 + side * math.cos(t) * 1.9 + V((0, 0, math.sin(t) * 1.9))
                sphere(mb, p, 0.12, "dark", 3, 6)
        for z in range(4, 28, 4):
            for k in range(4):
                a = k * math.pi / 2
                n = V((math.cos(a), math.sin(a), 0))
                side = n.cross(V((0, 0, 1)))
                c = n * 4.01 + V((0, 0, z))
                p = [c - side * 0.7, c + side * 0.7, c + side * 0.7 + V((0, 0, 2.0)), c - side * 0.7 + V((0, 0, 2.0))]
                mb.add_face([mb.add_vert(q, []) for q in p], [(0, 0), (1, 0), (1, 1), (0, 1)], "window", smooth=False)
        lathe(mb, [(3.8, 38.0), (3.0, 41.0), (0.4, 47.5), (0.0, 48.0)], 8, "copper")
    out(d, "clock_tower", {"stone": M((0.82, 0.8, 0.74), 0.7, k="stone"), "face": M((0.95, 0.94, 0.9), 0.5), "dark": BLACK,
                           "window": M((0.15, 0.18, 0.22), 0.2), "copper": M((0.3, 0.55, 0.48), 0.5, 0.4)}, clock_tower)

    # a single swing: the frame ("Frame"), and the seat on its chains ("Seat", pivoting at its top, z = 2.4)
    _sc.reset()
    SM = {"frame": M((0.85, 0.35, 0.25), 0.55, 0.3).make("swing_frame"), "chain": CHROME.make("swing_chain"), "seat": M((0.12, 0.12, 0.12), 0.7).make("swing_seat")}
    fr = _MB()
    for sx in (-1.1, 1.1):
        for sy in (-1, 1):
            rod(fr, (sx, sy * 0.85, 0.0), (sx, 0.0, 2.45), 0.05, "frame", 10)
    cyl(fr, (-1.2, 0, 2.45), 0.055, 2.4, "frame", 10, "x")
    st = _MB()
    for dx in (-0.22, 0.22):
        for k in range(17):
            z = -0.02 - k * 0.1
            torus(st, (dx, 0, z), 0.018, 0.004, "chain", 6, 3, "y" if k % 2 else "z")
    box(st, (-0.26, -0.11, -1.72), (0.26, 0.11, -1.67), "seat", 0.2)
    o1 = fr.to_object("Frame", SM, recalc_normals=True)
    o2 = st.to_object("Seat", SM, recalc_normals=True)
    o2.location = (0, 0, 2.45)
    _sc.export_glb(f"{d}/swing_single.glb", [o1, o2])
    print("  swing_single")

    def entrance_gates(mb):    # the park's way in: two tall stone piers with lanterns, open iron gates folded back, a nameplate
        for sx in (-1, 1):
            x = sx * 4.2
            box(mb, (x - 0.55, -0.55, 0.0), (x + 0.55, 0.55, 3.6), "stone", 0.4)
            box(mb, (x - 0.65, -0.65, 3.6), (x + 0.65, 0.65, 3.8), "stone", 0.4)
            lathe(mb, [(0.15, 3.8), (0.2, 3.9), (0.12, 4.0), (0.12, 4.35), (0.2, 4.45), (0.0, 4.6)], 8, "iron", center=V((x, 0, 0)))
            box(mb, (x - 0.12, -0.12, 4.0), (x + 0.12, 0.12, 4.32), "glow", 0.1, bevel=0.0)
            for k in range(9):        # the gate leaf, folded open against the railings
                y = 0.65 + k * 0.22
                cyl(mb, (x - sx * 0.1, y, 0.0), 0.016, 2.6, "iron", 6)
                cone(mb, (x - sx * 0.1, y, 2.6), 0.03, 0.0, 0.1, "iron", 6)
            for z in (0.2, 2.3):
                cyl(mb, (x - sx * 0.1, 0.6, z), 0.022, 1.9, "iron", 6, "y")
        box(mb, (-1.6, -0.62, 3.05), (1.6, -0.58, 3.45), "plate", 0.2)
    out(d, "entrance_gates", {"stone": M((0.7, 0.62, 0.52), 0.55, k="stone"), "iron": IRON, "glow": M((1.0, 0.85, 0.6), 0.3, 0.0, 2.5),
                              "plate": BRONZE}, entrance_gates)

    def park_bin(mb):          # a green slatted litter bin
        lathe(mb, [(0.0, 0.0), (0.22, 0.0), (0.22, 0.85), (0.24, 0.88), (0.0, 0.9)], 16, "green")
        for k in range(16):
            a = k * math.pi / 8
            box(mb, (math.cos(a) * 0.225 - 0.015, math.sin(a) * 0.225 - 0.015, 0.05), (math.cos(a) * 0.225 + 0.015, math.sin(a) * 0.225 + 0.015, 0.8), "dark", 0.1, bevel=0.0)
    out(d, "park_bin", {"green": GREEN_PAINT, "dark": M((0.06, 0.15, 0.1), 0.5, 0.3)}, park_bin)


    def iron_railing(mb):      # 2 m of park railing: black iron bars with spear tops between two rails, 1.3 m
        for k in range(13):
            x = -0.96 + k * 0.16
            cyl(mb, (x, 0, 0.0), 0.011, 1.22, "iron", 6)
            cone(mb, (x, 0, 1.22), 0.025, 0.0, 0.09, "iron", 4)
        for z in (0.12, 1.05):
            box(mb, (-1.0, -0.018, z - 0.02), (1.0, 0.018, z + 0.02), "iron", 0.1, bevel=0.0)
        cyl(mb, (-1.0, 0, 0.0), 0.035, 1.35, "iron", 8)
        sphere(mb, (-1.0, 0, 1.38), 0.05, "iron", 4, 8)
    out(d, "iron_railing", {"iron": IRON}, iron_railing)
