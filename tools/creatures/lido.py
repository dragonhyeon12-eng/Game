"""The open-air pool sunk into the summer city, and the playground above it (models/props/*.glb).
Face Godot +Z (Blender -Y), origin on the ground at the footprint centre unless noted.
"""
import math
import random

from lib import *  # noqa: F401,F403

WHITE_PAINT = M((0.86, 0.86, 0.84), 0.35)
RED = M((0.75, 0.08, 0.06), 0.35)
BLUE = M((0.06, 0.2, 0.6), 0.35)
YELLOW = M((0.9, 0.65, 0.05), 0.35)
GREEN = M((0.1, 0.4, 0.15), 0.4)
PLASTIC_W = M((0.85, 0.86, 0.85), 0.3)


def build(d):
    random.seed(23)

    # ---------------------------------------------------------------- the pool
    def pool_ladder(mb):       # the deck edge on y=0 (Godot z=0); it hangs down into the pool on Godot +Z
        for x in (-0.25, 0.25):
            pts = [V((x, 0.35, 0.0)), V((x, 0.35, 0.75)), V((x, 0.25, 0.95)), V((x, 0.05, 0.95)), V((x, -0.12, 0.8)), V((x, -0.15, 0.3)), V((x, -0.15, -1.45))]
            mb.tube(pts, [0.022] * len(pts), 10, "chrome", [])
            cyl(mb, (x, 0.35, -0.005), 0.05, 0.01, "chrome", 12)       # the flange on the deck
        for k in range(4):
            z = -0.25 - k * 0.32
            box(mb, (-0.24, -0.22, z - 0.015), (0.24, -0.08, z + 0.015), "step", 0.2)
    out(d, "pool_ladder", {"chrome": CHROME, "step": M((0.75, 0.75, 0.73), 0.4, 0.7, k="metal")}, pool_ladder)

    def lane_rope(mb):         # 10 m along X: a rope threaded through floats, alternating colours (floats at the waterline, z = 0)
        cyl(mb, (-5.0, 0, 0), 0.006, 10.0, "rope", 4, "x")
        n = 70
        for k in range(n):
            x = -4.95 + k * (9.9 / (n - 1))
            band = (k // 4) % 3
            m = ["red", "white", "blue"][band] if abs(x) < 4.2 else "red"
            prof = [(0.0, -0.06), (0.04, -0.058), (0.055, -0.03), (0.055, 0.03), (0.04, 0.058), (0.0, 0.06)]
            rings = []
            for px, pz in prof:
                rings.append([V((x + pz, math.cos(a) * px, math.sin(a) * px)) for a in (2 * math.pi * i / 8 for i in range(8))])
            mb.loft(rings, m, lambda ri, p: [], cap_start=False, cap_end=False)
    out(d, "lane_rope", {"rope": M((0.9, 0.9, 0.85), 0.8), "red": RED, "white": WHITE_PAINT, "blue": BLUE}, lane_rope)

    def starting_block(mb):
        box(mb, (-0.3, -0.25, 0.0), (0.3, 0.35, 0.45), "base", 0.3)
        pts = [V((-0.3, -0.35, 0.72)), V((0.3, -0.35, 0.72)), V((0.3, 0.3, 0.62)), V((-0.3, 0.3, 0.62))]
        top = [mb.add_vert(p, []) for p in pts]
        mb.add_face(top, [(0, 0), (1, 0), (1, 1), (0, 1)], "top", smooth=False)
        box(mb, (-0.25, -0.1, 0.44), (0.25, 0.25, 0.62), "base", 0.3)
        mb.tube([V((-0.22, -0.35, 0.6)), V((-0.22, -0.4, 0.5))], [0.012] * 2, 6, "chrome", [])
        mb.tube([V((0.22, -0.35, 0.6)), V((0.22, -0.4, 0.5))], [0.012] * 2, 6, "chrome", [])
        box(mb, (-0.12, -0.255, 0.2), (0.12, -0.25, 0.4), "plate", 0.1)
    out(d, "starting_block", {"base": WHITE_PAINT, "top": M((0.15, 0.35, 0.65), 0.6), "chrome": CHROME, "plate": M((0.05, 0.05, 0.05), 0.4)}, starting_block)

    def lifeguard_chair(mb):   # a tall white chair with a ladder at the back and a sunshade
        H = 1.9
        for sx in (-1, 1):
            for sy in (-1, 1):
                rod(mb, (sx * 0.42, sy * 0.45, 0.0), (sx * 0.3, sy * 0.25, H), 0.035, "frame", 8)
        for z in (0.5, 1.0, 1.45):
            for sy in (-1, 1):
                t = z / H
                hw = 0.42 - 0.12 * t
                hy = 0.45 - 0.2 * t
                rod(mb, (-hw, sy * hy, z), (hw, sy * hy, z), 0.025, "frame", 6)
        box(mb, (-0.34, -0.3, H), (0.34, 0.3, H + 0.06), "seat", 0.3)
        box(mb, (-0.34, 0.26, H + 0.06), (0.34, 0.32, H + 0.65), "seat", 0.3)
        for sx in (-1, 1):
            rod(mb, (sx * 0.34, -0.25, H + 0.06), (sx * 0.34, -0.25, H + 0.35), 0.02, "frame", 6)
            rod(mb, (sx * 0.34, -0.25, H + 0.35), (sx * 0.34, 0.26, H + 0.35), 0.02, "frame", 6)
        cyl(mb, (0.25, 0.25, H + 0.06), 0.02, 1.4, "frame", 6)
        cone(mb, (0.25, 0.25, H + 1.25), 0.9, 0.02, 0.35, "shade", 12)
        box(mb, (-0.3, -0.32, H - 0.45), (0.3, -0.3, H - 0.1), "sign", 0.1)
    out(d, "lifeguard_chair", {"frame": WHITE_PAINT, "seat": M((0.55, 0.38, 0.22), 0.4, k="wood"), "shade": M((0.85, 0.15, 0.1), 0.6, ds=True),
                               "sign": RED}, lifeguard_chair)

    def deckchair(mb):         # a sun lounger, 1.9 long along Godot Z, the back raised at -Z
        for sx in (-1, 1):
            rod(mb, (sx * 0.3, -0.9, 0.05), (sx * 0.3, 0.55, 0.32), 0.015, "frame", 6)
            rod(mb, (sx * 0.3, -0.9, 0.0), (sx * 0.3, -0.9, 0.32), 0.015, "frame", 6)
            rod(mb, (sx * 0.3, 0.75, 0.0), (sx * 0.3, 0.55, 0.32), 0.015, "frame", 6)
        for k in range(12):
            y = -0.85 + k * 0.105
            box(mb, (-0.3, y, 0.31), (0.3, y + 0.08, 0.34), "slat", 0.2)
        for k in range(6):       # the backrest, tilted up
            t = k / 5
            y = 0.62 + t * 0.35
            z = 0.36 + t * 0.55
            box(mb, (-0.3, y, z), (0.3, y + 0.05, z + 0.09), "slat", 0.2)
        rounded_box(mb, V((0, 0.0, 0.37)), (0.55, 1.2, 0.04), 0.015, "towel", 2)
    out(d, "deckchair", {"frame": CHROME, "slat": PLASTIC_W, "towel": M((0.1, 0.5, 0.7), 0.95, k="fabric")}, deckchair)

    def diving_board(mb):      # a springboard: a pedestal and a 3.5 m board reaching out over Godot +Z
        box(mb, (-0.35, 0.3, 0.0), (0.35, 1.1, 0.8), "base", 0.4)
        box(mb, (-0.25, -0.2, 0.7), (0.25, 0.3, 0.8), "base", 0.4)
        box(mb, (-0.25, -3.5, 0.8), (0.25, 1.0, 0.86), "board", 0.3)
        for sx in (-1, 1):
            rod(mb, (sx * 0.3, 1.1, 0.0), (sx * 0.3, 1.1, 1.6), 0.02, "chrome", 8)
            rod(mb, (sx * 0.3, 1.1, 1.6), (sx * 0.3, 0.2, 1.3), 0.02, "chrome", 8)
    out(d, "diving_board", {"base": M((0.75, 0.74, 0.7), 0.85, k="stone"), "board": M((0.1, 0.35, 0.6), 0.5), "chrome": CHROME}, diving_board)

    def diving_tower(mb):      # a 5 m concrete platform tower: legs, a deck reaching out over Godot +Z, a ladder at the back
        for sx in (-1, 1):
            box(mb, (sx * 0.9 - 0.15, 0.6, 0.0), (sx * 0.9 + 0.15, 0.9, 5.0), "concrete", 0.5)
        box(mb, (-1.05, -2.4, 4.85), (1.05, 1.0, 5.1), "concrete", 0.5)
        box(mb, (-1.05, -2.42, 5.1), (1.05, -2.35, 5.12), "edge", 0.2)
        for sx in (-1, 1):
            rod(mb, (sx * 1.0, 1.0, 5.1), (sx * 1.0, -2.2, 5.1), 0.02, "chrome", 6)
            for k in range(4):
                y = 0.9 - k * 1.0
                rod(mb, (sx * 1.0, y, 5.1), (sx * 1.0, y, 6.0), 0.02, "chrome", 6)
            rod(mb, (sx * 1.0, 1.0, 6.0), (sx * 1.0, -2.2, 6.0), 0.025, "chrome", 6)
        for sx in (-0.25, 0.25):                                    # the ladder up the back
            rod(mb, (sx, 1.05, 0.0), (sx, 1.05, 6.0), 0.02, "chrome", 6)
        for k in range(17):
            z = 0.3 + k * 0.3
            rod(mb, (-0.25, 1.05, z), (0.25, 1.05, z), 0.015, "chrome", 6)
    out(d, "diving_tower", {"concrete": CONCRETE, "edge": YELLOW, "chrome": CHROME}, diving_tower)

    def changing_cabin(mb):    # a painted wooden beach cabin, 1.2 x 1.2 x 2.3, door on Godot +Z
        W = 1.2
        for k in range(12):
            x = -W / 2 + k * 0.1
            m = "stripe" if k % 2 else "paint"
            box(mb, (x, -W / 2, 0.08), (x + 0.1, W / 2, 2.1), m, 0.3)
        box(mb, (-W / 2 - 0.05, -W / 2 - 0.05, 0.0), (W / 2 + 0.05, W / 2 + 0.05, 0.08), "wood", 0.4)
        pts = [V((-W / 2 - 0.1, -W / 2 - 0.15, 2.1)), V((W / 2 + 0.1, -W / 2 - 0.15, 2.1)), V((W / 2 + 0.1, 0, 2.45)), V((-W / 2 - 0.1, 0, 2.45))]
        mb.add_face([mb.add_vert(p, []) for p in pts], [(0, 0), (1, 0), (1, 1), (0, 1)], "roof", smooth=False)
        pts = [V((-W / 2 - 0.1, 0, 2.45)), V((W / 2 + 0.1, 0, 2.45)), V((W / 2 + 0.1, W / 2 + 0.15, 2.1)), V((-W / 2 - 0.1, W / 2 + 0.15, 2.1))]
        mb.add_face([mb.add_vert(p, []) for p in pts], [(0, 0), (1, 0), (1, 1), (0, 1)], "roof", smooth=False)
        box(mb, (-0.4, -W / 2 - 0.02, 0.1), (0.4, -W / 2, 1.95), "door", 0.3)
        cyl(mb, (0.3, -W / 2 - 0.02, 1.0), 0.025, 0.04, "brass", 10, "y")
        box(mb, (-0.15, -W / 2 - 0.025, 1.6), (0.15, -W / 2 - 0.02, 1.75), "number", 0.1)
    out(d, "changing_cabin", {"paint": WHITE_PAINT, "stripe": M((0.2, 0.45, 0.7), 0.5, k="wood"), "wood": WOOD, "roof": M((0.55, 0.1, 0.08), 0.6, ds=True),
                              "door": M((0.85, 0.85, 0.8), 0.45, k="wood"), "brass": BRASS, "number": M((0.1, 0.1, 0.1), 0.4)}, changing_cabin)

    def lifebuoy_post(mb):
        cyl(mb, (0, 0, 0), 0.04, 1.6, "post", 8)
        box(mb, (-0.3, -0.06, 1.0), (0.3, 0.0, 1.6), "board", 0.3)
        for k in range(8):
            a0 = k * math.pi / 4
            seg = [V((math.cos(a0 + t * math.pi / 4 / 4) * 0.25, -0.12, 1.3 + math.sin(a0 + t * math.pi / 4 / 4) * 0.25)) for t in range(5)]
            mb.tube(seg, [0.06] * 5, 10, "red" if k % 2 == 0 else "white", [], cap_end=False)
    out(d, "lifebuoy_post", {"post": WHITE_PAINT, "board": M((0.1, 0.3, 0.6), 0.5, k="wood"), "red": RED, "white": WHITE_PAINT}, lifebuoy_post)

    def parasol(mb):
        cyl(mb, (0, 0, 0), 0.22, 0.06, "base", 16)
        cyl(mb, (0, 0, 0.06), 0.02, 2.2, "pole", 8)
        n = 16
        for k in range(n):
            a0 = 2 * math.pi * k / n
            a1 = 2 * math.pi * (k + 1) / n
            p0 = V((0, 0, 2.35))
            p1 = V((math.cos(a0) * 1.4, math.sin(a0) * 1.4, 1.95))
            p2 = V((math.cos(a1) * 1.4, math.sin(a1) * 1.4, 1.95))
            mb.add_face([mb.add_vert(p, []) for p in (p0, p1, p2)], [(0.5, 1), (0, 0), (1, 0)], "s1" if (k // 2) % 2 else "s2", smooth=False)
    out(d, "parasol", {"base": CONCRETE, "pole": CHROME, "s1": M((0.95, 0.95, 0.9), 0.7, ds=True), "s2": M((0.1, 0.5, 0.75), 0.7, ds=True)}, parasol)

    def pool_sign(mb):         # a sign on a post (the game writes on it), the board facing Godot +Z, 0.9 x 0.5 at 1.6
        cyl(mb, (0, 0.05, 0), 0.035, 1.9, "post", 8)
        box(mb, (-0.45, -0.02, 1.35), (0.45, 0.03, 1.85), "board", 0.2)
        frame_rect(mb, 0, 1.6, 0.9, 0.5, 0.025, -0.03, -0.02, "red")
    out(d, "pool_sign", {"post": STEEL, "board": WHITE_PAINT, "red": RED}, pool_sign)

    # ---------------------------------------------------------------- the playground
    def swing_set(mb):         # an A-frame, 3 m wide along X; the two seats are separate meshes? no: one piece, the game sways it
        for sx in (-1.5, 1.5):
            for sy in (-1, 1):
                rod(mb, (sx, sy * 0.9, 0.0), (sx, 0.0, 2.4), 0.045, "frame", 10)
            cyl(mb, (sx, -0.95, -0.4), 0.06, 0.4, "concrete", 8) if False else None
        cyl(mb, (-1.6, 0, 2.4), 0.05, 3.2, "frame", 10, "x")
        for x in (-0.75, 0.75):
            for dx in (-0.22, 0.22):
                for k in range(16):
                    z = 2.38 - k * 0.1
                    torus(mb, (x + dx, 0, z), 0.018, 0.004, "chain", 6, 3, "y" if k % 2 else "z")
            box(mb, (x - 0.25, -0.1, 0.72), (x + 0.25, 0.1, 0.76), "seat", 0.2)
    out(d, "swing_set", {"frame": M((0.15, 0.45, 0.2), 0.4, 0.3), "chain": CHROME, "seat": M((0.08, 0.08, 0.08), 0.7), "concrete": CONCRETE}, swing_set)

    def slide(mb):             # a ladder up the back (Godot -Z), the chute down the front (Godot +Z)
        H = 1.8
        for sx in (-0.3, 0.3):
            rod(mb, (sx, 1.2, 0.0), (sx, 0.9, H + 0.6), 0.03, "frame", 8)
            rod(mb, (sx, 0.5, 0.0), (sx, 0.5, H), 0.04, "frame", 8)
            rod(mb, (sx, 0.9, H + 0.6), (sx, 0.5, H + 0.6), 0.03, "frame", 8)
        for k in range(6):
            t = (k + 1) / 7
            rod(mb, (-0.3, 1.2 - 0.3 * t, H * t), (0.3, 1.2 - 0.3 * t, H * t), 0.02, "frame", 6)
        box(mb, (-0.35, 0.45, H), (0.35, 0.95, H + 0.05), "deck", 0.3)
        rows = []
        for k in range(13):
            t = k / 12
            y = 0.45 - t * 2.6
            z = H * (1 - t) ** 1.4 + 0.25 * t
            row = [V((x, y, z + (0.12 * (abs(x) / 0.3) ** 4))) for x in (-0.32, -0.28, -0.15, 0.0, 0.15, 0.28, 0.32)]
            rows.append(row)
        mb.strip(rows, "chute", lambda ri, p: [])
        rows2 = [[V((p.x, p.y, p.z - 0.03)) for p in reversed(r)] for r in rows]
        mb.strip(rows2, "chute", lambda ri, p: [])
    out(d, "slide", {"frame": M((0.1, 0.25, 0.6), 0.4, 0.3), "deck": WOOD, "chute": M((0.92, 0.75, 0.1), 0.15, 0.6)}, slide)

    def climbing_dome(mb):     # a geodesic-ish climbing dome of bars, 3 m across
        R = 1.5
        lat = [k * math.pi / 2 / 4 for k in range(5)]
        n = 12
        for i, la in enumerate(lat):
            z = math.sin(la) * R
            r = math.cos(la) * R
            if i < 4:
                pts = [V((math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r, z)) for k in range(n + 1)]
                mb.tube(pts, [0.025] * len(pts), 6, "bar" if i % 2 else "bar2", [], cap_end=False)
        for k in range(n):
            a = 2 * math.pi * k / n
            pts = [V((math.cos(a) * math.cos(la) * R, math.sin(a) * math.cos(la) * R, math.sin(la) * R)) for la in lat]
            mb.tube(pts, [0.025] * len(pts), 6, "bar", [])
    out(d, "climbing_dome", {"bar": M((0.8, 0.15, 0.1), 0.35, 0.5), "bar2": M((0.95, 0.7, 0.1), 0.35, 0.5)}, climbing_dome)

    def sandbox(mb):           # 2.4 square timber frame, sand, a bucket and spade left behind
        for k in range(4):
            a = k * math.pi / 2
            c = V((math.cos(a) * 1.15, math.sin(a) * 1.15, 0.15))
            if k % 2 == 0:
                box(mb, (c.x - 0.08, -1.25, 0.0), (c.x + 0.08, 1.25, 0.3), "wood", 0.4)
            else:
                box(mb, (-1.25, c.y - 0.08, 0.0), (1.25, c.y + 0.08, 0.3), "wood", 0.4)
        rows = [[V((x, y, 0.18 + 0.04 * math.sin(x * 3 + y * 2) + 0.03 * math.cos(x * 5 - y * 4))) for x in [-1.07 + i * 0.214 for i in range(11)]] for y in [-1.07 + j * 0.214 for j in range(11)]]
        mb.strip(rows, "sand", lambda ri, p: [])
        lathe(mb, [(0.0, 0.2), (0.07, 0.2), (0.09, 0.38)], 12, "bucket", center=V((0.5, -0.4, 0)), cap_end=False)
        box(mb, (-0.45, 0.3, 0.22), (-0.42, 0.65, 0.24), "bucket", 0.1)
    out(d, "sandbox", {"wood": WOOD, "sand": M((0.85, 0.75, 0.52), 1.0), "bucket": M((0.1, 0.55, 0.85), 0.3)}, sandbox)

    def roundabout(mb):        # a merry-go-round: a disc and hand rails (the game can spin it)
        lathe(mb, [(0.0, 0.2), (1.2, 0.2), (1.25, 0.25), (1.2, 0.3), (0.0, 0.3)], 32, "deck")
        cyl(mb, (0, 0, 0.0), 0.12, 0.2, "steel", 12)
        for k in range(4):
            a = k * math.pi / 2
            pts = [V((math.cos(a) * 1.1, math.sin(a) * 1.1, 0.3)), V((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.9)), V((0, 0, 1.0))]
            mb.tube(pts, [0.025] * 3, 8, "rail", [])
            sector = [V((0, 0, 0.301))] + [V((math.cos(a + t * math.pi / 2 / 6) * 1.2, math.sin(a + t * math.pi / 2 / 6) * 1.2, 0.301)) for t in range(7)]
            mb.fan(sector[0], sector[1:], "s%d" % (k % 2), [])
    out(d, "roundabout", {"deck": M((0.3, 0.3, 0.32), 0.5, 0.6), "steel": STEEL, "rail": M((0.9, 0.75, 0.1), 0.35, 0.5),
                          "s0": M((0.85, 0.15, 0.1), 0.4), "s1": M((0.1, 0.4, 0.8), 0.4)}, roundabout)

    def seesaw(mb):            # 3.6 m along X
        box(mb, (-0.15, -0.2, 0.0), (0.15, 0.2, 0.5), "base", 0.3)
        box(mb, (-1.8, -0.12, 0.5), (1.8, 0.12, 0.56), "plank", 0.3)
        for sx in (-1, 1):
            box(mb, (sx * 1.55 - 0.15, -0.14, 0.56), (sx * 1.55 + 0.15, 0.14, 0.62), "seat", 0.3)
            mb.tube([V((sx * 1.35, -0.14, 0.56)), V((sx * 1.35, -0.14, 0.8)), V((sx * 1.35, 0.14, 0.8)), V((sx * 1.35, 0.14, 0.56))], [0.015] * 4, 6, "steel", [])
    out(d, "seesaw", {"base": M((0.85, 0.15, 0.1), 0.4, 0.4), "plank": WOOD, "seat": M((0.1, 0.1, 0.1), 0.7), "steel": STEEL}, seesaw)

    def spring_rider(mb):      # a little horse on a spring
        mb.tube([V((0, 0, 0.0)) + V((0.08 * math.cos(t), 0.08 * math.sin(t), t * 0.012)) for t in [i * 0.6 for i in range(30)]], [0.012] * 30, 6, "steel", [])
        rounded_box(mb, V((0, 0.0, 0.55)), (0.22, 0.6, 0.25), 0.08, "body", 3)
        mb.tube([V((0, -0.25, 0.6)), V((0, -0.35, 0.8)), V((0, -0.42, 0.85))], [0.08, 0.07, 0.06], 10, "body", [])
        for sx in (-1, 1):
            sphere(mb, (sx * 0.05, -0.47, 0.88), 0.015, "eye", 4, 6)
            rod(mb, (sx * 0.15, -0.3, 0.75), (sx * 0.05, -0.3, 0.75), 0.015, "handle", 6)
        box(mb, (-0.03, -0.3, 0.88), (0.03, 0.1, 0.95), "mane", 0.1)
    out(d, "spring_rider", {"steel": CHROME, "body": M((0.95, 0.75, 0.1), 0.3), "eye": BLACK, "handle": RED, "mane": M((0.85, 0.2, 0.1), 0.5)}, spring_rider)

    def play_fence(mb):        # a 2 m panel of a low playground fence along X
        for x in (-1.0, 1.0):
            cyl(mb, (x, 0, 0), 0.035, 1.0, "post", 8)
            sphere(mb, (x, 0, 1.02), 0.045, "post", 5, 8)
        for z in (0.2, 0.85):
            cyl(mb, (-1.0, 0, z), 0.018, 2.0, "rail", 6, "x")
        for k in range(15):
            x = -0.9 + k * (1.8 / 14)
            box(mb, (x - 0.035, -0.012, 0.12), (x + 0.035, 0.012, 0.92), "picket%d" % (k % 3), 0.2)
    out(d, "play_fence", {"post": M((0.1, 0.35, 0.2), 0.4, 0.3), "rail": M((0.1, 0.35, 0.2), 0.4, 0.3),
                          "picket0": M((0.85, 0.2, 0.15), 0.4), "picket1": M((0.95, 0.75, 0.1), 0.4), "picket2": M((0.15, 0.45, 0.8), 0.4)}, play_fence)

    def park_gate(mb):         # a wrought-iron gateway arch, 3 m opening along X
        for sx in (-1, 1):
            box(mb, (sx * 1.7 - 0.25, -0.25, 0.0), (sx * 1.7 + 0.25, 0.25, 2.6), "stone", 0.4)
            box(mb, (sx * 1.7 - 0.3, -0.3, 2.6), (sx * 1.7 + 0.3, 0.3, 2.75), "stone", 0.4)
            sphere(mb, (sx * 1.7, 0, 2.95), 0.18, "stone", 6, 12)
        pts = [V((-1.45, 0, 2.5)) + V((0, 0, 0))]
        arch = [V((math.cos(t) * -1.45, 0, 2.5 + math.sin(t) * 0.7)) for t in [i * math.pi / 16 for i in range(17)]]
        mb.tube(arch, [0.03] * len(arch), 6, "iron", [])
        mb.tube([V((-1.45, 0, 2.45)), V((1.45, 0, 2.45))], [0.03, 0.03], 6, "iron", [])
        for k in range(9):
            x = -1.2 + k * 0.3
            top = 2.5 + math.sqrt(max(0.0, 1 - (x / 1.45) ** 2)) * 0.7
            rod(mb, (x, 0, 2.45), (x, 0, top), 0.012, "iron", 4)
    out(d, "park_gate", {"stone": M((0.62, 0.6, 0.56), 0.6, k="stone"), "iron": M((0.08, 0.08, 0.09), 0.5, 0.6)}, park_gate)
