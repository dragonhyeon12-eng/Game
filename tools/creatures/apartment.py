"""A flat that is someone's home (models/props/*.glb): living room, kitchen, child's room, bathroom, hall.
All face Godot +Z (Blender -Y), origin on the floor at the footprint centre unless noted ("wall" items
have their back on the origin plane, hung at the height given in the game).
"""
import math
import random

from lib import *  # noqa: F401,F403


def build(d):
    random.seed(7)

    # ---------------------------------------------------------------- living room
    def coffee_table(mb):
        slab(mb, 0, 0, 0.4, 1.0, 0.6, 0.04, "wood")
        slab(mb, 0, 0, 0.12, 0.9, 0.5, 0.02, "wood")
        legs(mb, 0.96, 0.56, 0.38, 0.02, "wood", 0.04)
        slab(mb, 0.2, 0.05, 0.43, 0.24, 0.18, 0.02, "mag")
        slab(mb, 0.24, 0.08, 0.45, 0.22, 0.16, 0.015, "mag2")
    out(d, "coffee_table", {"wood": WOOD, "mag": M((0.75, 0.2, 0.2), 0.6), "mag2": M((0.2, 0.4, 0.7), 0.6)}, coffee_table)

    def tv_stand(mb):
        slab(mb, 0, 0, 0.3, 1.6, 0.5, 0.6, "wood")
        slab(mb, 0, -0.252, 0.3, 1.5, 0.01, 0.5, "dark")
        for x in (-0.4, 0.4):
            slab(mb, x, -0.26, 0.45, 0.12, 0.02, 0.02, "metal")
        slab(mb, 0.0, -0.1, 0.12, 0.4, 0.3, 0.08, "black")        # a VCR on the low shelf
        slab(mb, 0.0, -0.255, 0.12, 0.2, 0.01, 0.015, "green")
    out(d, "tv_stand", {"wood": DARKWOOD, "dark": M((0.12, 0.08, 0.05), 0.5), "metal": BRASS, "black": BLACK,
                        "green": M((0.2, 1.0, 0.4), 0.3, 0, 3.0)}, tv_stand)

    def floor_lamp(mb):
        cyl(mb, (0, 0, 0), 0.16, 0.03, "metal", 16)
        cyl(mb, (0, 0, 0.03), 0.014, 1.42, "metal", 8)
        lathe(mb, [(0.21, 1.3), (0.13, 1.6)], 18, "shade", cap_start=False, cap_end=False)
        sphere(mb, (0, 0, 1.42), 0.05, "bulb")
    out(d, "floor_lamp", {"metal": M((0.18, 0.16, 0.14), 0.4, 0.8), "shade": M((0.92, 0.82, 0.6), 0.8, 0, 0.6, 1.0, True),
                          "bulb": M((1.0, 0.9, 0.7), 0.2, 0, 6.0)}, floor_lamp)

    def armchair_old(mb):
        rounded_box(mb, V((0, 0, 0.22)), (0.85, 0.8, 0.3), 0.06, "fab")
        rounded_box(mb, V((0, -0.04, 0.42)), (0.6, 0.66, 0.14), 0.06, "fab")
        rounded_box(mb, V((0, 0.33, 0.7)), (0.62, 0.16, 0.6), 0.07, "fab")
        for sx in (-1, 1):
            rounded_box(mb, V((sx * 0.38, 0.0, 0.45)), (0.14, 0.8, 0.36), 0.06, "fab")
        legs(mb, 0.78, 0.72, 0.08, 0.02, "wood")
        slab(mb, 0, 0.0, 0.5, 0.4, 0.4, 0.002, "doily")
    out(d, "armchair_old", {"fab": M((0.45, 0.32, 0.22), 0.95), "wood": DARKWOOD, "doily": M((0.95, 0.93, 0.88), 0.9)}, armchair_old)

    def picture_frame(mb):     # wall: back on y=0, centre at z=0
        frame_rect(mb, 0, 0, 0.5, 0.4, 0.04, -0.03, 0.0, "frame")
        slab(mb, 0, -0.01, 0, 0.42, 0.01, 0.32, "pic")
        slab(mb, -0.08, -0.016, -0.05, 0.08, 0.001, 0.16, "fig")
        slab(mb, 0.07, -0.016, -0.06, 0.07, 0.001, 0.13, "fig")
    out(d, "picture_frame", {"frame": M((0.6, 0.48, 0.25), 0.4, 0.5), "pic": M((0.55, 0.65, 0.5), 0.8), "fig": M((0.3, 0.25, 0.2), 0.8)}, picture_frame)

    def wall_clock(mb):        # wall: faces -Y, centre at z=0
        mb.tube([V((0, 0, 0)), V((0, -0.05, 0))], [0.17, 0.17], 24, "rim", [])
        mb.tube([V((0, -0.049, 0)), V((0, -0.051, 0))], [0.15, 0.15], 24, "face", [])
        for k in range(12):
            a = k * math.pi / 6
            slab(mb, math.sin(a) * 0.12, -0.053, math.cos(a) * 0.12, 0.012, 0.004, 0.03 if k % 3 == 0 else 0.015, "hand")
        slab(mb, 0.0, -0.056, 0.04, 0.01, 0.003, 0.09, "hand")
        slab(mb, 0.035, -0.058, 0.0, 0.07, 0.003, 0.008, "hand")
    out(d, "wall_clock", {"rim": M((0.15, 0.15, 0.16), 0.4, 0.6), "face": M((0.95, 0.94, 0.9), 0.6), "hand": BLACK}, wall_clock)

    def ceiling_bulb(mb):      # hangs from z=0 down
        cyl(mb, (0, 0, -0.04), 0.04, 0.04, "black", 10)
        cyl(mb, (0, 0, -0.42), 0.004, 0.38, "black", 4)
        cyl(mb, (0, 0, -0.5), 0.018, 0.08, "metal", 10)
        sphere(mb, (0, 0, -0.56), 0.045, "bulb", 6, 10, 1.3)
    out(d, "ceiling_bulb", {"black": BLACK, "metal": BRASS, "bulb": M((1.0, 0.92, 0.75), 0.2, 0, 8.0)}, ceiling_bulb)

    def pendant_lamp(mb):
        cyl(mb, (0, 0, -0.04), 0.05, 0.04, "metal", 10)
        cyl(mb, (0, 0, -0.7), 0.004, 0.66, "black", 4)
        lathe(mb, [(0.03, -0.7), (0.12, -0.78), (0.26, -0.92)], 20, "shade", cap_start=True, cap_end=False)
        sphere(mb, (0, 0, -0.84), 0.05, "bulb")
    out(d, "pendant_lamp", {"metal": STEEL, "black": BLACK, "shade": M((0.15, 0.3, 0.25), 0.4, 0.3, 0, 1, True),
                            "bulb": M((1.0, 0.92, 0.75), 0.2, 0, 8.0)}, pendant_lamp)

    def curtain_rail(mb):      # 1.2 m along X, at z=0
        cyl(mb, (-0.62, 0, 0), 0.015, 1.24, "wood", 8, "x")
        for x in (-0.64, 0.64):
            sphere(mb, (x, 0, 0), 0.03, "wood")
        for k in range(10):
            torus(mb, (-0.5 + k * 0.11, 0, 0), 0.022, 0.004, "brass", 10, 4, "y")
    out(d, "curtain_rail", {"wood": DARKWOOD, "brass": BRASS}, curtain_rail)

    def bookshelf_low(mb):
        W, D, H = 1.1, 0.32, 0.9
        slab(mb, -W / 2 + 0.01, 0, H / 2, 0.02, D, H, "wood"); slab(mb, W / 2 - 0.01, 0, H / 2, 0.02, D, H, "wood")
        slab(mb, 0, D / 2 - 0.005, H / 2, W, 0.01, H, "wood")
        for z in (0.02, 0.45, 0.88):
            slab(mb, 0, 0, z, W, D, 0.02, "wood")
        cols = ["b1", "b2", "b3", "b4"]
        for z0 in (0.03, 0.46):
            x = -W / 2 + 0.03
            while x < W / 2 - 0.08:
                t = random.uniform(0.025, 0.05); h = random.uniform(0.22, 0.36)
                slab(mb, x + t / 2, 0.0, z0 + h / 2, t, 0.22, h, random.choice(cols))
                x += t + 0.003
        slab(mb, 0.25, -0.02, 0.92, 0.2, 0.15, 0.06, "b2")
    out(d, "bookshelf_low", {"wood": WOOD, "b1": M((0.5, 0.12, 0.1), 0.6), "b2": M((0.15, 0.25, 0.45), 0.6),
                             "b3": M((0.2, 0.35, 0.2), 0.6), "b4": M((0.85, 0.78, 0.6), 0.6)}, bookshelf_low)

    # ---------------------------------------------------------------- kitchen
    def fridge(mb):
        rounded_box(mb, V((0, 0, 0.9)), (0.7, 0.68, 1.8), 0.05, "white")
        slab(mb, 0, -0.345, 1.15, 0.66, 0.01, 0.01, "seam")
        for z in (1.4, 0.8):
            slab(mb, 0.27, -0.37, z, 0.03, 0.04, 0.3, "chrome")
        for (x, z, m) in ((-0.15, 1.4, "mag1"), (0.0, 1.5, "mag2"), (-0.1, 0.9, "pic")):
            slab(mb, x, -0.352, z, 0.08 if m != "pic" else 0.18, 0.006, 0.06 if m != "pic" else 0.22, m)
    out(d, "fridge", {"white": M((0.88, 0.88, 0.84), 0.3), "seam": BLACK, "chrome": CHROME, "mag1": M((0.9, 0.2, 0.2), 0.4),
                      "mag2": M((0.2, 0.6, 0.9), 0.4), "pic": PAPER}, fridge)

    def stove(mb):
        slab(mb, 0, 0, 0.45, 0.6, 0.6, 0.9, "white")
        slab(mb, 0, 0, 0.905, 0.6, 0.6, 0.01, "top")
        for x in (-0.14, 0.14):
            for y in (-0.12, 0.14):
                torus(mb, (x, y, 0.92), 0.08, 0.008, "iron", 16, 5)
        slab(mb, 0, -0.302, 0.45, 0.5, 0.01, 0.35, "glass")
        slab(mb, 0, -0.32, 0.66, 0.44, 0.02, 0.02, "chrome")
        slab(mb, 0, 0.27, 0.98, 0.6, 0.06, 0.14, "white")
        for k in range(4):
            cyl(mb, (-0.2 + k * 0.13, 0.24, 0.98), 0.018, 0.03, "black", 10, "y")
    out(d, "stove", {"white": M((0.85, 0.84, 0.8), 0.35), "top": M((0.1, 0.1, 0.1), 0.3), "iron": M((0.08, 0.08, 0.08), 0.6, 0.6),
                     "glass": M((0.05, 0.05, 0.05), 0.1), "chrome": CHROME, "black": BLACK}, stove)

    def kitchen_cabinet(mb):   # base unit with worktop and sink, 1.2 wide
        slab(mb, 0, 0, 0.44, 1.2, 0.6, 0.88, "body")
        slab(mb, 0, -0.02, 0.9, 1.24, 0.64, 0.04, "top")
        for x in (-0.3, 0.3):
            slab(mb, x, -0.302, 0.44, 0.58, 0.01, 0.8, "door")
            slab(mb, x + (0.22 if x < 0 else -0.22), -0.315, 0.7, 0.02, 0.02, 0.12, "chrome")
        slab(mb, -0.25, -0.02, 0.88, 0.46, 0.38, 0.06, "steel")
        rod(mb, (-0.25, 0.2, 0.92), (-0.25, 0.2, 1.1), 0.012, "chrome")
        rod(mb, (-0.25, 0.2, 1.1), (-0.25, 0.05, 1.12), 0.012, "chrome")
    out(d, "kitchen_cabinet", {"body": M((0.8, 0.78, 0.7), 0.5), "door": M((0.62, 0.7, 0.62), 0.45), "top": M((0.35, 0.3, 0.28), 0.3),
                               "steel": STEEL, "chrome": CHROME}, kitchen_cabinet)

    def wall_cupboard(mb):     # wall: back at y=0, bottom at z=0
        slab(mb, 0, -0.17, 0.35, 1.2, 0.34, 0.7, "body")
        for x in (-0.3, 0.3):
            slab(mb, x, -0.345, 0.35, 0.58, 0.01, 0.66, "door")
            slab(mb, x + (0.22 if x < 0 else -0.22), -0.355, 0.08, 0.02, 0.02, 0.1, "chrome")
    out(d, "wall_cupboard", {"body": M((0.8, 0.78, 0.7), 0.5), "door": M((0.62, 0.7, 0.62), 0.45), "chrome": CHROME}, wall_cupboard)

    def washing_machine(mb):
        rounded_box(mb, V((0, 0, 0.43)), (0.6, 0.6, 0.86), 0.03, "white")
        mb.tube([V((0.0, -0.3, 0.42)), V((0.0, -0.33, 0.42))], [0.2, 0.2], 24, "chrome", [])
        mb.tube([V((0.0, -0.33, 0.42)), V((0.0, -0.335, 0.42))], [0.16, 0.16], 24, "glass", [])
        slab(mb, 0, -0.3, 0.78, 0.56, 0.02, 0.1, "panel")
        cyl(mb, (0.18, -0.31, 0.78), 0.03, 0.03, "chrome", 12, "y")
    out(d, "washing_machine", {"white": M((0.9, 0.9, 0.88), 0.35), "chrome": CHROME, "glass": M((0.15, 0.2, 0.25), 0.05),
                               "panel": M((0.8, 0.8, 0.8), 0.4)}, washing_machine)

    def kettle(mb):
        lathe(mb, [(0.0, 0.0), (0.09, 0.0), (0.1, 0.06), (0.09, 0.18), (0.05, 0.22), (0.0, 0.23)], 16, "steel")
        mb.tube([V((0, 0.08, 0.06)), V((0, 0.13, 0.12)), V((0, 0.08, 0.2))], [0.012] * 3, 6, "black", [])
        mb.tube([V((0, -0.08, 0.08)), V((0, -0.15, 0.17))], [0.02, 0.01], 8, "steel", [])
    out(d, "kettle", {"steel": CHROME, "black": BLACK}, kettle)

    def dish_rack(mb):
        slab(mb, 0, 0, 0.01, 0.45, 0.32, 0.02, "plastic")
        for k in range(6):
            x = -0.18 + k * 0.07
            mb.tube([V((x, 0.0, 0.02)), V((x, 0.0, 0.2))], [0.11, 0.11], 18, "plate", [])
        cyl(mb, (0.15, 0.08, 0.02), 0.04, 0.1, "cup", 12)
    out(d, "dish_rack", {"plastic": M((0.85, 0.85, 0.88), 0.4), "plate": M((0.95, 0.95, 0.93), 0.2), "cup": M((0.3, 0.5, 0.7), 0.3)}, dish_rack)

    # ---------------------------------------------------------------- child's room
    def kids_bed(mb):          # head toward -Z (Blender +Y)
        L, W = 1.6, 0.8
        slab(mb, 0, 0, 0.2, W, L, 0.1, "frame")
        slab(mb, 0, L / 2 - 0.03, 0.45, W, 0.06, 0.9, "frame")
        slab(mb, 0, -L / 2 + 0.03, 0.3, W, 0.06, 0.6, "frame")
        for k in range(3):
            sphere(mb, (-0.25 + k * 0.25, L / 2 - 0.06, 0.7), 0.07, ["star1", "star2", "star1"][k], 6, 8)
        legs(mb, W, L, 0.2, 0.025, "frame", 0.04)
        rounded_box(mb, V((0, 0, 0.32)), (W - 0.06, L - 0.1, 0.14), 0.04, "sheet")
        rounded_box(mb, V((0, -0.1, 0.41)), (W - 0.02, L - 0.4, 0.08), 0.04, "duvet")
        rounded_box(mb, V((0, L / 2 - 0.22, 0.44)), (0.5, 0.26, 0.1), 0.05, "sheet")
    out(d, "kids_bed", {"frame": M((0.85, 0.85, 0.9), 0.5), "sheet": M((0.95, 0.95, 0.98), 0.9), "duvet": M((0.55, 0.7, 0.9), 0.9),
                        "star1": M((1.0, 0.85, 0.3), 0.4), "star2": M((0.95, 0.45, 0.5), 0.4)}, kids_bed)

    def toy_box(mb):
        slab(mb, 0, 0, 0.27, 0.9, 0.5, 0.54, "wood")
        slab(mb, 0, 0.0, 0.56, 0.94, 0.54, 0.04, "lid")
        for x, m in ((-0.3, "a"), (0.0, "b"), (0.3, "c")):
            slab(mb, x, -0.252, 0.3, 0.16, 0.005, 0.16, m)
    out(d, "toy_box", {"wood": M((0.7, 0.35, 0.25), 0.6), "lid": M((0.6, 0.28, 0.2), 0.6), "a": M((0.95, 0.85, 0.3), 0.5),
                       "b": M((0.3, 0.6, 0.9), 0.5), "c": M((0.4, 0.8, 0.4), 0.5)}, toy_box)

    def cassette_player(mb):
        rounded_box(mb, V((0, 0, 0.05)), (0.3, 0.16, 0.1), 0.01, "body")
        slab(mb, -0.05, -0.081, 0.05, 0.12, 0.002, 0.06, "window")
        for k in range(2):
            torus(mb, (-0.08 + k * 0.06, -0.083, 0.05), 0.012, 0.003, "white", 10, 4, "y")
        for k in range(5):
            slab(mb, -0.1 + k * 0.035, 0.0, 0.103, 0.025, 0.04, 0.008, "key")
        for k in range(8):
            cyl(mb, (0.09, -0.081, 0.02 + k * 0.009), 0.003, 0.003, "grille", 4, "y")
        rod(mb, (-0.13, 0.06, 0.1), (-0.13, 0.06, 0.2), 0.004, "chrome")
    out(d, "cassette_player", {"body": M((0.12, 0.12, 0.13), 0.5), "window": M((0.3, 0.25, 0.2), 0.1), "white": WHITE,
                               "key": M((0.6, 0.6, 0.62), 0.3, 0.8), "grille": STEEL, "chrome": CHROME}, cassette_player)

    def nightlight(mb):        # wall plug: back at y=0
        rounded_box(mb, V((0, -0.02, 0)), (0.07, 0.04, 0.09), 0.015, "plastic")
        sphere(mb, (0, -0.045, 0.0), 0.035, "glow", 6, 10, 1.0)
    out(d, "nightlight", {"plastic": WHITE, "glow": M((0.6, 0.65, 1.0), 0.3, 0, 5.0)}, nightlight)

    for i, (bg, shapes) in enumerate([((0.97, 0.96, 0.9), [("sun", 0.12, 0.1), ("house", -0.05, -0.05), ("man", 0.1, -0.08)]),
                                      ((0.97, 0.96, 0.9), [("man", 0.0, 0.0), ("man", -0.1, 0.0), ("tall", 0.12, 0.02)]),
                                      ((0.97, 0.96, 0.9), [("eye", 0.0, 0.03), ("tall", -0.11, -0.05), ("tall", 0.11, -0.05)])]):
        def drawing(mb, shapes=shapes):   # wall: a sheet of paper, back at y=0
            slab(mb, 0, -0.002, 0, 0.42, 0.003, 0.3, "paper")
            for s, x, z in shapes:
                if s == "sun":
                    sphere(mb, (x, -0.004, z), 0.035, "yellow", 4, 8, 0.05)
                elif s == "house":
                    slab(mb, x, -0.004, z, 0.12, 0.002, 0.1, "red")
                    slab(mb, x, -0.005, z + 0.07, 0.14, 0.002, 0.04, "brown")
                elif s == "man":
                    sphere(mb, (x, -0.004, z + 0.06), 0.018, "crayon", 4, 8, 0.05)
                    slab(mb, x, -0.004, z, 0.006, 0.002, 0.09, "crayon")
                elif s == "tall":
                    slab(mb, x, -0.005, z, 0.04, 0.002, 0.22, "black")
                    sphere(mb, (x, -0.006, z + 0.12), 0.022, "black", 4, 8, 0.05)
                elif s == "eye":
                    sphere(mb, (x, -0.004, z), 0.06, "black", 4, 12, 0.05)
                    sphere(mb, (x, -0.006, z), 0.02, "red", 4, 8, 0.05)
        out(d, f"drawing_{i}", {"paper": M(bg, 0.9), "yellow": M((1.0, 0.85, 0.2), 0.8), "red": M((0.85, 0.2, 0.15), 0.8),
                                "brown": M((0.45, 0.3, 0.15), 0.8), "crayon": M((0.2, 0.35, 0.8), 0.8), "black": BLACK}, drawing)

    def teddy_bear(mb):
        sphere(mb, (0, 0, 0.12), 0.11, "fur", 8, 12, 1.0)
        sphere(mb, (0, 0, 0.3), 0.085, "fur", 8, 12, 1.0)
        for sx in (-1, 1):
            sphere(mb, (sx * 0.07, 0, 0.38), 0.03, "fur", 5, 8)
            sphere(mb, (sx * 0.11, -0.03, 0.17), 0.04, "fur", 5, 8, 1.4)
            sphere(mb, (sx * 0.06, -0.08, 0.04), 0.045, "fur", 5, 8)
            sphere(mb, (sx * 0.03, -0.075, 0.32), 0.01, "eye", 4, 6)
        sphere(mb, (0, -0.08, 0.28), 0.035, "muzzle", 5, 8)
        sphere(mb, (0, -0.11, 0.29), 0.012, "eye", 4, 6)
        torus(mb, (0, 0, 0.23), 0.07, 0.012, "bow", 14, 5)
    out(d, "teddy_bear", {"fur": M((0.55, 0.38, 0.22), 1.0), "muzzle": M((0.8, 0.68, 0.5), 1.0), "eye": BLACK, "bow": M((0.8, 0.15, 0.2), 0.6)}, teddy_bear)

    def rocking_horse(mb):
        for sx in (-1, 1):
            pts = [V((sx * 0.17, -0.5 + k * 0.1, 0.04 + 0.12 * ((k - 5) / 5) ** 2)) for k in range(11)]
            mb.tube(pts, [0.025] * 11, 6, "wood", [])
            for y in (-0.25, 0.25):
                rod(mb, (sx * 0.17, y, 0.06), (sx * 0.08, y * 0.8, 0.4), 0.022, "wood")
        rounded_box(mb, V((0, 0, 0.45)), (0.2, 0.62, 0.18), 0.08, "white")
        mb.tube([V((0, -0.28, 0.5)), V((0, -0.36, 0.68)), V((0, -0.46, 0.7))], [0.07, 0.06, 0.05], 10, "white", [])
        slab(mb, 0, -0.3, 0.68, 0.03, 0.12, 0.12, "mane")
        rod(mb, (0, 0.3, 0.5), (0, 0.4, 0.38), 0.03, "mane")
        slab(mb, 0, 0.02, 0.55, 0.22, 0.2, 0.03, "saddle")
    out(d, "rocking_horse", {"wood": M((0.75, 0.25, 0.2), 0.5), "white": M((0.92, 0.9, 0.85), 0.5), "mane": M((0.3, 0.2, 0.12), 0.9),
                             "saddle": M((0.2, 0.35, 0.7), 0.5)}, rocking_horse)

    def toy_blocks(mb):
        cols = ["r", "g", "b", "y"]
        k = 0
        for (x, y, z) in ((0, 0, 0), (0.09, 0.01, 0), (0.04, 0.0, 0.08), (-0.12, 0.06, 0), (0.18, -0.08, 0)):
            slab(mb, x, y, z + 0.04, 0.08, 0.08, 0.08, cols[k % 4]); k += 1
    out(d, "toy_blocks", {"r": M((0.85, 0.2, 0.2), 0.6), "g": M((0.3, 0.7, 0.3), 0.6), "b": M((0.2, 0.4, 0.85), 0.6), "y": M((0.95, 0.8, 0.2), 0.6)}, toy_blocks)

    def rug_rect(mb):
        slab(mb, 0, 0, 0.004, 1.6, 1.0, 0.008, "rug")
        frame_rect(mb, 0, 0, 1.5, 0.9, 0.06, 0, 0, "border")
        slab(mb, 0, 0, 0.009, 1.4, 0.04, 0.002, "border")
    out(d, "rug_rect", {"rug": M((0.55, 0.2, 0.18), 1.0), "border": M((0.85, 0.75, 0.5), 1.0)},
        lambda mb: (slab(mb, 0, 0, 0.004, 1.6, 1.0, 0.008, "rug"), slab(mb, 0, 0, 0.0085, 1.44, 0.84, 0.001, "border"),
                    slab(mb, 0, 0, 0.009, 1.3, 0.7, 0.001, "rug")))

    # ---------------------------------------------------------------- bathroom
    def bath_mirror(mb):       # wall: back at y=0
        rounded_box(mb, V((0, -0.06, 0)), (0.5, 0.12, 0.6), 0.02, "white")
        slab(mb, 0, -0.121, 0, 0.44, 0.002, 0.54, "mirror")
        slab(mb, 0, -0.07, -0.33, 0.5, 0.14, 0.02, "white")
        cyl(mb, (-0.12, -0.09, -0.32), 0.02, 0.1, "cup", 10)
    out(d, "bath_mirror", {"white": WHITE, "mirror": M((0.85, 0.88, 0.9), 0.02, 1.0), "cup": M((0.4, 0.7, 0.8), 0.3)}, bath_mirror)

    def towel_rail(mb):        # wall: back at y=0, bar at z=0
        for x in (-0.3, 0.3):
            rod(mb, (x, 0, 0), (x, -0.08, 0), 0.012, "chrome")
        cyl(mb, (-0.3, -0.08, 0), 0.012, 0.6, "chrome", 8, "x")
        slab(mb, 0.0, -0.08, -0.22, 0.4, 0.03, 0.45, "towel")
    out(d, "towel_rail", {"chrome": CHROME, "towel": M((0.6, 0.75, 0.8), 1.0)}, towel_rail)

    def shower_head(mb):       # wall: back at y=0
        rod(mb, (0, 0, -1.0), (0, 0, 0.1), 0.012, "chrome")
        rod(mb, (0, 0, 0.1), (0, -0.25, 0.15), 0.012, "chrome")
        lathe(mb, [(0.02, 0.0), (0.08, -0.05), (0.08, -0.06)], 16, "chrome", center=V((0, -0.27, 0.15)))
        cyl(mb, (0, 0, -0.8), 0.03, 0.08, "chrome", 10, "y")
    out(d, "shower_head", {"chrome": CHROME}, shower_head)

    def laundry_basket(mb):
        lathe(mb, [(0.18, 0.0), (0.22, 0.5)], 16, "wicker", cap_start=True, cap_end=False)
        sphere(mb, (0.02, 0.0, 0.48), 0.17, "cloth", 6, 10, 0.4)
        slab(mb, 0.12, -0.18, 0.5, 0.12, 0.05, 0.25, "cloth2")
    out(d, "laundry_basket", {"wicker": M((0.7, 0.58, 0.38), 0.9, 0, 0, 1, True), "cloth": M((0.8, 0.8, 0.85), 1.0), "cloth2": M((0.7, 0.3, 0.3), 1.0)}, laundry_basket)

    def vent_grille(mb):       # wall: back at y=0, 0.88 wide x 1.0 tall, centred on z=0
        frame_rect(mb, 0, 0, 0.9, 1.06, 0.04, -0.03, 0.0, "metal")
        for k in range(12):
            z = -0.45 + k * 0.08
            v0 = V((-0.41, -0.005, z - 0.02)); v1 = V((0.41, -0.025, z + 0.02))
            box(mb, (v0.x, -0.025, z - 0.012), (v1.x, -0.005, z + 0.012), "metal", 0.2)
        for x in (-0.38, 0.38):
            for z in (-0.47, 0.47):
                cyl(mb, (x, -0.03, z), 0.008, 0.006, "screw", 6, "y")
    out(d, "vent_grille", {"metal": M((0.6, 0.6, 0.58), 0.5, 0.6), "screw": STEEL}, vent_grille)

    # ---------------------------------------------------------------- hall / building
    def coat_rack(mb):
        cyl(mb, (0, 0, 0), 0.2, 0.03, "wood", 12)
        cyl(mb, (0, 0, 0.03), 0.02, 1.72, "wood", 8)
        for k in range(4):
            a = k * math.pi / 2
            rod(mb, (0, 0, 1.6), (math.cos(a) * 0.14, math.sin(a) * 0.14, 1.7), 0.01, "wood")
        slab(mb, 0.1, -0.05, 1.3, 0.22, 0.15, 0.6, "coat")
        sphere(mb, (-0.1, 0.0, 1.72), 0.1, "hat", 5, 10, 0.6)
    out(d, "coat_rack", {"wood": DARKWOOD, "coat": M((0.3, 0.3, 0.35), 1.0), "hat": M((0.25, 0.2, 0.15), 0.9)}, coat_rack)

    def shoe_rack(mb):
        for z in (0.0, 0.2):
            slab(mb, 0, 0, z + 0.01, 0.7, 0.28, 0.02, "wood")
        for x in (-0.34, 0.34):
            slab(mb, x, 0, 0.15, 0.02, 0.28, 0.3, "wood")
        for k, (x, z) in enumerate(((-0.2, 0.03), (-0.05, 0.03), (0.15, 0.03), (-0.12, 0.23), (0.12, 0.23))):
            rounded_box(mb, V((x, -0.02, z + 0.04)), (0.1, 0.26, 0.08), 0.03, ["s1", "s2", "s3"][k % 3])
    out(d, "shoe_rack", {"wood": WOOD, "s1": M((0.1, 0.1, 0.1), 0.4), "s2": M((0.6, 0.3, 0.2), 0.6), "s3": M((0.85, 0.85, 0.85), 0.6)}, shoe_rack)

    def handrail(mb):          # 1 m along +X from origin, at z=0
        cyl(mb, (0, 0, 0), 0.025, 1.0, "rail", 10, "x")
        for x in (0.05, 0.95):
            rod(mb, (x, 0, 0), (x, 0.07, 0), 0.01, "metal")
            cyl(mb, (x, 0.07, -0.04), 0.03, 0.08, "metal", 10, "y") if False else None
    out(d, "handrail", {"rail": M((0.3, 0.38, 0.3), 0.4, 0.5), "metal": STEEL}, handrail)

    def exit_sign(mb):         # wall: back at y=0
        slab(mb, 0, -0.04, 0, 0.36, 0.08, 0.16, "box")
        slab(mb, 0, -0.081, 0, 0.32, 0.002, 0.12, "glow")
        slab(mb, -0.08, -0.083, 0, 0.04, 0.002, 0.08, "man")
        slab(mb, 0.06, -0.083, 0, 0.12, 0.002, 0.02, "man")
    out(d, "exit_sign", {"box": WHITE, "glow": M((0.2, 1.0, 0.4), 0.3, 0, 5.0), "man": M((0.95, 1.0, 0.95), 0.3, 0, 6.0)}, exit_sign)

    def fluorescent_panel(mb): # ceiling: top at z=0
        slab(mb, 0, 0, -0.02, 1.2, 0.3, 0.04, "frame")
        slab(mb, 0, 0, -0.042, 1.12, 0.24, 0.005, "glow")
        for x in (-0.3, 0.0, 0.3):
            slab(mb, x, 0, -0.045, 0.01, 0.24, 0.004, "frame")
    out(d, "fluorescent_panel", {"frame": M((0.85, 0.85, 0.82), 0.5), "glow": M((1.0, 0.97, 0.85), 0.3, 0, 5.0)}, fluorescent_panel)

    def wall_ladder(mb):       # one 1.2 m section: rails at x=+-0.25, rungs every 0.3, back at y=0
        for x in (-0.25, 0.25):
            slab(mb, x, -0.08, 0.6, 0.05, 0.03, 1.2, "metal")
            for z in (0.1, 1.1):
                slab(mb, x, -0.04, z, 0.04, 0.08, 0.03, "metal")
        for k in range(4):
            cyl(mb, (-0.25, -0.08, 0.15 + k * 0.3), 0.014, 0.5, "metal", 8, "x")
    out(d, "wall_ladder", {"metal": RUST}, wall_ladder)

    def window_frame(mb):      # a bare window, 1.0 x 0.8 in the X-Z plane, back at y=0, centre z=0
        frame_rect(mb, 0, 0, 1.0, 0.8, 0.05, -0.06, 0.0, "frame")
        slab(mb, 0, -0.03, 0, 0.02, 0.04, 0.72, "frame")
        slab(mb, 0, -0.025, 0, 0.92, 0.005, 0.72, "glass")
        slab(mb, 0, -0.09, -0.42, 1.08, 0.14, 0.04, "sill")
    out(d, "window_frame", {"frame": M((0.85, 0.85, 0.8), 0.5), "glass": M((0.08, 0.09, 0.1), 0.05, 0.0, 0, 0.85), "sill": M((0.7, 0.7, 0.68), 0.7)}, window_frame)

    def light_switch(mb):      # wall
        slab(mb, 0, -0.005, 0, 0.08, 0.01, 0.08, "plate")
        slab(mb, 0, -0.012, 0, 0.02, 0.008, 0.035, "plate")
    out(d, "light_switch", {"plate": M((0.92, 0.9, 0.85), 0.4)}, light_switch)

    def smoke_detector(mb):    # ceiling
        lathe(mb, [(0.06, 0.0), (0.06, -0.025), (0.04, -0.035), (0.0, -0.036)], 16, "white")
        sphere(mb, (0.03, 0, -0.036), 0.004, "red", 3, 6)
    out(d, "smoke_detector", {"white": WHITE, "red": M((1.0, 0.1, 0.1), 0.3, 0, 6.0)}, smoke_detector)

    def umbrella_stand(mb):
        lathe(mb, [(0.1, 0.0), (0.11, 0.5)], 14, "metal", cap_start=True, cap_end=False)
        for k, m in enumerate(("u1", "u2")):
            rod(mb, (k * 0.04 - 0.02, 0, 0.05), (k * 0.06 - 0.03, 0.02, 0.85), 0.025 - k * 0.005, m, 8)
            mb.tube([V((k * 0.06 - 0.03, 0.02, 0.85)), V((k * 0.06, 0.02, 0.92)), V((k * 0.06 + 0.04, 0.02, 0.88))], [0.008] * 3, 5, "black", [])
    out(d, "umbrella_stand", {"metal": M((0.3, 0.3, 0.32), 0.4, 0.7), "u1": M((0.15, 0.2, 0.4), 0.7), "u2": M((0.6, 0.15, 0.15), 0.7), "black": BLACK}, umbrella_stand)

    def kitchen_bin(mb):
        lathe(mb, [(0.13, 0.0), (0.14, 0.55), (0.0, 0.56)], 16, "steel")
        rod(mb, (-0.05, -0.14, 0.03), (0.05, -0.14, 0.03), 0.01, "black")
    out(d, "kitchen_bin", {"steel": CHROME, "black": BLACK}, kitchen_bin)

    def step_stool(mb):
        slab(mb, 0, 0, 0.45, 0.35, 0.3, 0.03, "wood")
        slab(mb, 0, -0.1, 0.22, 0.35, 0.18, 0.03, "wood")
        legs(mb, 0.33, 0.28, 0.44, 0.015, "wood", 0.03)
    out(d, "step_stool", {"wood": M((0.75, 0.6, 0.4), 0.6)}, step_stool)

    def ceiling_fan(mb):
        cyl(mb, (0, 0, -0.3), 0.012, 0.3, "metal", 6)
        lathe(mb, [(0.0, -0.3), (0.1, -0.32), (0.1, -0.4), (0.0, -0.42)], 14, "metal")
        for k in range(4):
            a = k * math.pi / 2
            c = V((math.cos(a) * 0.4, math.sin(a) * 0.4, -0.37))
            mb.tube([V((math.cos(a) * 0.1, math.sin(a) * 0.1, -0.37)), c + V((math.cos(a) * 0.25, math.sin(a) * 0.25, 0))],
                    [0.06, 0.07], 4, "wood", [])
    out(d, "ceiling_fan", {"metal": BRASS, "wood": DARKWOOD}, ceiling_fan)

    def phone_wall(mb):        # wall phone, back at y=0
        rounded_box(mb, V((0, -0.03, 0)), (0.1, 0.06, 0.2), 0.015, "body")
        mb.tube([V((-0.06, -0.07, -0.08)), V((-0.07, -0.08, 0.0)), V((-0.06, -0.07, 0.08))], [0.025] * 3, 8, "body", [])
        for k in range(12):
            slab(mb, 0.015 + (k % 3) * 0.018 - 0.018, -0.061, 0.05 - (k // 3) * 0.022, 0.012, 0.004, 0.012, "key")
        mb.tube([V((-0.06, -0.07, -0.1)) + V((0, 0, -0.05 * k)) + V((0.01 * math.sin(k * 2), 0, 0)) for k in range(8)], [0.004] * 8, 4, "cord", [])
    out(d, "phone_wall", {"body": M((0.85, 0.82, 0.72), 0.4), "key": M((0.3, 0.3, 0.3), 0.4), "cord": M((0.8, 0.78, 0.7), 0.6)}, phone_wall)

    def radio_old(mb):
        rounded_box(mb, V((0, 0, 0.13)), (0.4, 0.18, 0.26), 0.04, "wood")
        slab(mb, -0.06, -0.091, 0.13, 0.2, 0.004, 0.16, "cloth")
        for z in (0.17, 0.09):
            cyl(mb, (0.12, -0.09, z), 0.022, 0.02, "knob", 12, "y")
        slab(mb, 0.12, -0.091, 0.21, 0.08, 0.004, 0.02, "dial")
    out(d, "radio_old", {"wood": DARKWOOD, "cloth": M((0.6, 0.5, 0.35), 1.0), "knob": BRASS, "dial": M((0.95, 0.85, 0.5), 0.3, 0, 1.5)}, radio_old)

    def plant_hanging(mb):     # hangs from z=0
        for k in range(3):
            a = k * 2 * math.pi / 3
            rod(mb, (0, 0, 0), (math.cos(a) * 0.12, math.sin(a) * 0.12, -0.5), 0.003, "rope", 4)
        lathe(mb, [(0.0, -0.66), (0.08, -0.65), (0.13, -0.5)], 14, "pot", cap_start=False, cap_end=False)
        for k in range(8):
            a = k * 2 * math.pi / 8
            pts = [V((math.cos(a) * (0.08 + 0.05 * t), math.sin(a) * (0.08 + 0.05 * t), -0.5 + 0.05 - 0.25 * t * t)) for t in (0.0, 0.5, 1.0, 1.5)]
            mb.tube(pts, [0.012, 0.012, 0.01, 0.006], 4, "leaf", [])
    out(d, "plant_hanging", {"rope": M((0.75, 0.65, 0.5), 0.9), "pot": M((0.65, 0.4, 0.3), 0.7), "leaf": M((0.2, 0.5, 0.2), 0.6)}, plant_hanging)
