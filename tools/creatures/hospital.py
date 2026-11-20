"""The hospital in THE QUIET (models/props/*.glb): waiting room, corridor, records, nurses' station, ward 6,
the memorial garden. Face Godot +Z (Blender -Y), origin on the floor at the footprint centre unless noted;
"wall" items have their back on y=0.
"""
import math
import random

from lib import *  # noqa: F401,F403

PAINT = M((0.86, 0.88, 0.87), 0.5)
BLUE = M((0.2, 0.4, 0.55), 0.45)
MINT = M((0.75, 0.85, 0.8), 0.5)


def build(d):
    random.seed(11)

    def ceiling_troffer(mb):   # ceiling: top at z=0, 1.2 x 0.5
        slab(mb, 0, 0, -0.03, 1.24, 0.54, 0.06, "frame")
        slab(mb, 0, 0, -0.061, 1.16, 0.46, 0.004, "diff")
        for x in (-0.39, 0.0, 0.39):
            slab(mb, x, 0, -0.064, 0.012, 0.46, 0.006, "frame")
        slab(mb, 0, 0, -0.064, 1.16, 0.012, 0.006, "frame")
    out(d, "ceiling_troffer", {"frame": M((0.88, 0.9, 0.9), 0.4, 0.3), "diff": M((0.95, 1.0, 0.98), 0.3, 0, 3.0)}, ceiling_troffer)

    def clock_face(mb):        # wall: back at y=0, 0.46 across (hands are the game's)
        mb.tube([V((0, 0, 0)), V((0, -0.05, 0))], [0.23, 0.23], 28, "rim", [])
        mb.tube([V((0, -0.049, 0)), V((0, -0.052, 0))], [0.21, 0.21], 28, "face", [])
        for k in range(60):
            a = k * math.pi / 30
            big = k % 5 == 0
            slab(mb, math.sin(a) * 0.185, -0.054, math.cos(a) * 0.185, 0.01 if big else 0.004, 0.003, 0.035 if big else 0.012, "tick")
        cyl(mb, (0, -0.06, 0), 0.012, 0.01, "tick", 10, "y")
    out(d, "clock_face", {"rim": M((0.12, 0.12, 0.13), 0.35, 0.6), "face": M((0.96, 0.96, 0.93), 0.5), "tick": BLACK}, clock_face)

    def ward_door(mb):         # a door slab with a porthole, 1.1 x 2.2, centred on y=0
        slab(mb, 0, 0, 1.1, 1.1, 0.05, 2.2, "paint")
        torus(mb, (0, 0, 1.55), 0.2, 0.02, "steel", 24, 6, "y")
        slab(mb, 0, 0, 1.55, 0.36, 0.01, 0.36, "glass")
        for y in (-0.03, 0.03):
            slab(mb, 0, y, 0.15, 1.0, 0.004, 0.3, "kick")
            slab(mb, 0.0, y, 1.05, 0.25, 0.004, 0.3, "push")
        rod(mb, (-0.45, -0.05, 0.95), (-0.45, -0.05, 1.25), 0.015, "steel")
    out(d, "ward_door", {"paint": M((0.82, 0.86, 0.88), 0.4, 0.2), "steel": CHROME, "glass": M((0.05, 0.06, 0.08), 0.05),
                         "kick": STEEL, "push": STEEL}, ward_door)

    def number_display(mb):    # centred on its origin, faces +Z
        slab(mb, 0, 0, 0, 1.4, 0.06, 0.5, "case")
        slab(mb, 0, -0.031, 0, 1.3, 0.002, 0.4, "led")
        for x in (-0.5, 0.5):
            rod(mb, (x, 0, 0.25), (x, 0.0, 0.6), 0.012, "steel")
    out(d, "number_display", {"case": BLACK, "led": M((0.08, 0.02, 0.02), 0.2), "steel": STEEL}, number_display)

    def ticket_machine(mb):
        rounded_box(mb, V((0, 0, 0.6)), (0.45, 0.35, 1.2), 0.04, "red")
        slab(mb, 0, -0.176, 0.85, 0.3, 0.004, 0.22, "panel")
        slab(mb, 0, -0.178, 0.72, 0.12, 0.004, 0.012, "black")
        slab(mb, 0, -0.19, 0.69, 0.06, 0.04, 0.05, "ticket")
        cyl(mb, (0.1, -0.18, 0.95), 0.03, 0.01, "button", 12, "y")
        cyl(mb, (0, 0, 0), 0.25, 0.03, "black", 16)
    out(d, "ticket_machine", {"red": M((0.8, 0.18, 0.15), 0.35, 0.3), "panel": WHITE, "black": BLACK, "ticket": PAPER,
                              "button": M((0.2, 0.9, 0.3), 0.3, 0, 2.0)}, ticket_machine)

    def reception_desk(mb):    # 3.0 x 0.7, 1.1 high, the public side faces +Z
        slab(mb, 0, 0.05, 0.38, 2.9, 0.6, 0.76, "body")
        slab(mb, 0, -0.27, 0.55, 3.0, 0.08, 1.1, "front")
        slab(mb, 0, -0.27, 1.12, 3.06, 0.3, 0.04, "top")
        slab(mb, 0, 0.05, 0.77, 2.95, 0.66, 0.03, "top")
        for x in (-1.0, 0.0, 1.0):
            slab(mb, x, -0.312, 0.55, 0.9, 0.004, 0.8, "panel")
        slab(mb, 0.8, 0.1, 0.95, 0.5, 0.05, 0.35, "black")
        slab(mb, 0.8, 0.12, 0.8, 0.2, 0.15, 0.03, "black")
    out(d, "reception_desk", {"body": M((0.6, 0.62, 0.6), 0.6), "front": MINT, "panel": M((0.68, 0.78, 0.74), 0.5),
                              "top": M((0.85, 0.82, 0.75), 0.3), "black": BLACK}, reception_desk)

    def book_open(mb):
        for s in (-1, 1):
            pts = [[V((s * x, y, 0.02 + 0.03 * math.sin(math.pi * x / 0.2) * 0.4)) for x in (0.0, 0.05, 0.1, 0.15, 0.2)] for y in (-0.15, 0.15)]
            mb.loft([pts[0], pts[1]], "page", lambda ri, p: [], closed=False)
            slab(mb, s * 0.1, 0, 0.008, 0.21, 0.31, 0.016, "cover")
        for k in range(6):
            slab(mb, -0.1, -0.1 + k * 0.035, 0.035, 0.14, 0.004, 0.001, "ink")
    out(d, "book_open", {"page": M((0.93, 0.9, 0.82), 0.85, 0, 0, 1, True), "cover": M((0.25, 0.2, 0.35), 0.6), "ink": M((0.15, 0.15, 0.3), 0.8)}, book_open)

    def records_shelf(mb):     # 1.2 wide, 0.6 deep, 1.5 high, open front faces +Z
        W, D, H = 1.2, 0.6, 1.5
        for x in (-W / 2 + 0.015, W / 2 - 0.015):
            slab(mb, x, 0, H / 2, 0.03, D, H, "steel")
        slab(mb, 0, D / 2 - 0.01, H / 2, W, 0.02, H, "steel")
        for z in (0.03, 0.5, 1.0, 1.48):
            slab(mb, 0, 0, z, W, D, 0.025, "steel")
        for z0 in (0.045, 0.515, 1.015):
            x = -W / 2 + 0.05
            while x < W / 2 - 0.1:
                w = random.choice((0.08, 0.08, 0.1))
                slab(mb, x + w / 2, -0.02, z0 + 0.16, w - 0.006, 0.36, 0.32, random.choice(("bx1", "bx2", "bx3")))
                slab(mb, x + w / 2, -0.201, z0 + 0.2, w * 0.5, 0.002, 0.06, "label")
                x += w
    out(d, "records_shelf", {"steel": M((0.55, 0.57, 0.58), 0.45, 0.6), "bx1": M((0.2, 0.3, 0.5), 0.6), "bx2": M((0.55, 0.2, 0.18), 0.6),
                             "bx3": M((0.75, 0.68, 0.45), 0.6), "label": PAPER}, records_shelf)

    def file_folder(mb):
        slab(mb, 0, 0, 0.004, 0.35, 0.45, 0.008, "manila")
        slab(mb, 0.0, 0.0, 0.009, 0.3, 0.4, 0.004, "paper")
        slab(mb, 0.1, -0.235, 0.004, 0.1, 0.03, 0.008, "manila")
        rod(mb, (-0.12, 0.15, 0.012), (0.08, 0.15, 0.012), 0.002, "ink")
    out(d, "file_folder", {"manila": M((0.85, 0.7, 0.4), 0.8), "paper": PAPER, "ink": M((0.6, 0.1, 0.1), 0.6)}, file_folder)

    def metal_desk(mb):        # 1.6 x 0.9, top at 0.8
        slab(mb, 0, 0, 0.785, 1.6, 0.9, 0.03, "top")
        slab(mb, 0.55, 0.0, 0.39, 0.45, 0.85, 0.77, "body")
        for k in range(3):
            slab(mb, 0.55, -0.427, 0.15 + k * 0.25, 0.4, 0.004, 0.22, "drawer")
            slab(mb, 0.55, -0.435, 0.22 + k * 0.25, 0.12, 0.012, 0.015, "steel")
        slab(mb, -0.78, 0, 0.39, 0.03, 0.85, 0.77, "body")
        slab(mb, -0.1, 0.42, 0.45, 1.3, 0.02, 0.5, "body")
    out(d, "metal_desk", {"top": M((0.45, 0.42, 0.35), 0.5), "body": M((0.5, 0.55, 0.52), 0.45, 0.4), "drawer": M((0.55, 0.6, 0.57), 0.45, 0.4), "steel": CHROME}, metal_desk)

    def hook_board(mb):        # wall: back at y=0, 1.0 wide x 0.6
        slab(mb, 0, -0.02, 0, 1.0, 0.04, 0.6, "wood")
        frame_rect(mb, 0, 0, 1.0, 0.6, 0.03, -0.045, -0.035, "dark")
        for k in range(6):
            x = -0.3 + (k % 3) * 0.3; z = 0.15 - (k // 3) * 0.3
            mb.tube([V((x, -0.04, z)), V((x, -0.08, z)), V((x, -0.09, z + 0.02))], [0.006] * 3, 5, "brass", [])
            slab(mb, x, -0.041, z - 0.06, 0.06, 0.002, 0.025, "label")
    out(d, "hook_board", {"wood": M((0.55, 0.42, 0.3), 0.7), "dark": DARKWOOD, "brass": BRASS, "label": PAPER}, hook_board)

    def heart_monitor(mb):     # on a wheeled pole; the screen centre at 1.3, faces +Z
        for k in range(5):
            a = k * 2 * math.pi / 5
            rod(mb, (0, 0, 0.08), (math.cos(a) * 0.28, math.sin(a) * 0.28, 0.05), 0.012, "steel")
            sphere(mb, (math.cos(a) * 0.28, math.sin(a) * 0.28, 0.03), 0.03, "black", 5, 8)
        cyl(mb, (0, 0, 0.05), 0.016, 1.05, "steel", 8)
        rounded_box(mb, V((0, 0.0, 1.3)), (0.5, 0.3, 0.4), 0.03, "case")
        slab(mb, -0.05, -0.151, 1.3, 0.34, 0.002, 0.28, "screen")
        for k in range(4):
            cyl(mb, (0.19, -0.15, 1.2 + k * 0.06), 0.015, 0.01, ["b1", "b2", "b1", "b2"][k], 8, "y")
        mb.tube([V((0.2, 0.1, 1.15)), V((0.4, 0.2, 1.0)), V((0.6, 0.2, 0.9))], [0.005] * 3, 4, "black", [])
    out(d, "heart_monitor", {"steel": CHROME, "black": BLACK, "case": M((0.85, 0.86, 0.84), 0.4), "screen": M((0.02, 0.05, 0.03), 0.1),
                             "b1": M((0.9, 0.85, 0.2), 0.4), "b2": M((0.3, 0.3, 0.32), 0.4)}, heart_monitor)

    def clipboard_chart(mb):   # 0.25 x 0.35, centred, faces +Z (hangs on the bed's foot)
        slab(mb, 0, 0, 0, 0.25, 0.008, 0.35, "board")
        slab(mb, 0, -0.006, -0.01, 0.22, 0.003, 0.3, "paper")
        slab(mb, 0, -0.012, 0.16, 0.1, 0.02, 0.04, "clip")
        for k in range(7):
            slab(mb, -0.02, -0.0081, 0.09 - k * 0.03, 0.15, 0.001, 0.004, "ink")
    out(d, "clipboard_chart", {"board": M((0.55, 0.4, 0.25), 0.6), "paper": PAPER, "clip": CHROME, "ink": M((0.15, 0.2, 0.4), 0.8)}, clipboard_chart)

    def bedside_locker(mb):
        rounded_box(mb, V((0, 0, 0.4)), (0.5, 0.48, 0.74), 0.02, "body")
        slab(mb, 0, -0.245, 0.62, 0.44, 0.006, 0.16, "drawer")
        slab(mb, 0, -0.245, 0.3, 0.44, 0.006, 0.4, "drawer")
        for z in (0.62, 0.45):
            slab(mb, 0, -0.255, z, 0.14, 0.012, 0.015, "steel")
        slab(mb, 0, 0, 0.78, 0.52, 0.5, 0.025, "top")
        for x in (-0.2, 0.2):
            for y in (-0.2, 0.2):
                sphere(mb, (x, y, 0.025), 0.025, "black", 4, 8)
        cyl(mb, (0.12, 0.08, 0.79), 0.035, 0.1, "glass", 12)
    out(d, "bedside_locker", {"body": M((0.82, 0.8, 0.72), 0.5), "drawer": M((0.72, 0.7, 0.6), 0.5), "steel": CHROME, "top": M((0.6, 0.48, 0.32), 0.5),
                              "black": BLACK, "glass": GLASS}, bedside_locker)

    def monitor_wide(mb):      # a big flat monitor on its stand, origin under the stand, screen 0.9 x 0.55 centred 0.37 up
        slab(mb, 0, 0, 0.01, 0.3, 0.2, 0.02, "case")
        slab(mb, 0, 0.03, 0.15, 0.06, 0.03, 0.28, "case")
        slab(mb, 0, 0.0, 0.37, 0.94, 0.04, 0.59, "case")
        slab(mb, 0, -0.021, 0.37, 0.9, 0.002, 0.55, "screen")
    out(d, "monitor_wide", {"case": M((0.08, 0.08, 0.09), 0.4), "screen": M((0.02, 0.02, 0.03), 0.1)}, monitor_wide)

    def desk_long(mb):         # 2.0 x 0.9, top at 0.775
        slab(mb, 0, 0, 0.75, 2.0, 0.9, 0.05, "wood")
        for x in (-0.75, 0.75):
            slab(mb, x, 0, 0.36, 0.4, 0.8, 0.72, "dark")
            for k in range(3):
                slab(mb, x, -0.402, 0.13 + k * 0.23, 0.36, 0.004, 0.2, "wood")
                slab(mb, x, -0.41, 0.2 + k * 0.23, 0.1, 0.012, 0.012, "brass")
        slab(mb, 0, 0.4, 0.45, 1.1, 0.02, 0.5, "dark")
    out(d, "desk_long", {"wood": M((0.42, 0.31, 0.21), 0.5), "dark": M((0.33, 0.24, 0.16), 0.55), "brass": BRASS}, desk_long)

    def mirror_towel(mb):      # wall: a mirror with a towel thrown over it, back at y=0, centre z=0
        frame_rect(mb, 0, 0, 0.62, 1.12, 0.04, -0.03, 0.0, "frame")
        slab(mb, 0, -0.01, 0, 0.56, 0.006, 1.06, "mirror")
        rows = []
        for i in range(9):
            z = 0.6 - i * 0.12
            rows.append([V((x, -0.04 - 0.02 * math.sin(x * 9 + i) - (0.03 if i == 0 else 0.0), z - 0.02 * math.cos(x * 7 + i))) for x in
                         [-0.34 + k * 0.085 for k in range(9)]])
        mb.strip(rows, "towel", lambda ri, p: [])
    out(d, "mirror_towel", {"frame": M((0.7, 0.7, 0.72), 0.3, 0.8), "mirror": M((0.8, 0.85, 0.88), 0.02, 1.0),
                            "towel": M((0.85, 0.3, 0.3), 1.0, 0, 0, 1, True)}, mirror_towel)

    def memorial_plaque(mb):   # wall: back at y=0, 1.4 x 0.5
        slab(mb, 0, -0.01, 0, 1.46, 0.02, 0.56, "stone")
        slab(mb, 0, -0.03, 0, 1.4, 0.02, 0.5, "brass")
        frame_rect(mb, 0, 0, 1.36, 0.46, 0.02, -0.045, -0.04, "brass")
        for x in (-0.64, 0.64):
            for z in (-0.2, 0.2):
                sphere(mb, (x, -0.045, z), 0.012, "dark", 4, 6)
    out(d, "memorial_plaque", {"stone": M((0.55, 0.55, 0.52), 0.9), "brass": M((0.6, 0.48, 0.25), 0.35, 0.85), "dark": M((0.3, 0.25, 0.15), 0.4, 0.8)}, memorial_plaque)

    def iron_gate(mb):         # bars along Godot +Z from 0 to 2.4 (Blender y 0 .. -2.4), 2.6 high
        for k in range(8):
            y = -(k * 0.3 + 0.15)
            cyl(mb, (0, y, 0.0), 0.022, 2.45, "iron", 8)
            cone(mb, (0, y, 2.45), 0.04, 0.0, 0.14, "iron", 6)
        for z in (0.15, 2.3):
            slab(mb, 0, -1.2, z, 0.05, 2.4, 0.06, "iron")
        for k in range(4):
            y = -(0.3 + k * 0.6)
            torus(mb, (0, y, 2.0), 0.13, 0.012, "iron", 16, 4, "y") if False else None
            pts = [V((0, y + 0.12 * math.cos(t), 2.05 + 0.12 * math.sin(t))) for t in [i * math.pi / 8 for i in range(17)]]
            mb.tube(pts, [0.012] * len(pts), 4, "iron", [])
        cyl(mb, (0, -2.4, 0), 0.06, 2.7, "iron", 10)
        sphere(mb, (0, -2.4, 2.75), 0.08, "iron", 6, 10)
    out(d, "iron_gate", {"iron": M((0.12, 0.12, 0.13), 0.55, 0.6)}, iron_gate)

    # ---------------------------------------------------------------- dressing
    def hand_rail_hosp(mb):    # wall: 2 m bumper rail along X, back at y=0, at z=0
        slab(mb, 0, -0.06, 0, 2.0, 0.04, 0.14, "rail")
        for x in (-0.9, 0.0, 0.9):
            slab(mb, x, -0.03, 0, 0.06, 0.04, 0.08, "steel")
    out(d, "hand_rail_hosp", {"rail": M((0.45, 0.6, 0.62), 0.4), "steel": STEEL}, hand_rail_hosp)

    def sanitizer(mb):         # wall
        rounded_box(mb, V((0, -0.05, 0)), (0.12, 0.1, 0.24), 0.02, "white")
        slab(mb, 0, -0.1, -0.06, 0.08, 0.02, 0.05, "grey")
        slab(mb, 0, -0.101, 0.03, 0.06, 0.002, 0.08, "window")
    out(d, "sanitizer", {"white": WHITE, "grey": M((0.4, 0.42, 0.45), 0.4), "window": M((0.6, 0.85, 0.95), 0.1)}, sanitizer)

    def fire_extinguisher(mb):
        lathe(mb, [(0.0, 0.0), (0.08, 0.0), (0.08, 0.5), (0.05, 0.56), (0.02, 0.58)], 16, "red")
        cyl(mb, (0, 0, 0.58), 0.015, 0.06, "black", 8)
        slab(mb, 0.03, 0, 0.64, 0.12, 0.02, 0.02, "black")
        mb.tube([V((-0.02, 0, 0.62)), V((-0.08, -0.04, 0.5)), V((-0.09, -0.06, 0.3))], [0.012] * 3, 6, "black", [])
        slab(mb, 0, -0.08, 0.3, 0.08, 0.002, 0.12, "label")
    out(d, "fire_extinguisher", {"red": M((0.8, 0.08, 0.06), 0.3, 0.2), "black": BLACK, "label": PAPER}, fire_extinguisher)

    def wet_floor_sign(mb):
        for s in (-1, 1):
            p0 = V((-0.15, s * 0.0, 0.62));
            pts = [V((-0.15, 0, 0.62)), V((0.15, 0, 0.62)), V((0.15, s * 0.2, 0.0)), V((-0.15, s * 0.2, 0.0))]
            a = mb.add_vert(pts[0], []); b = mb.add_vert(pts[1], []); c = mb.add_vert(pts[2], []); dd = mb.add_vert(pts[3], [])
            mb.add_face([a, b, c, dd], [(0, 1), (1, 1), (1, 0), (0, 0)], "yellow", smooth=False)
            mb.add_face([dd, c, b, a], [(0, 0), (1, 0), (1, 1), (0, 1)], "yellow", smooth=False)
            slab(mb, 0, s * 0.11, 0.3, 0.12, 0.002, 0.1, "black")
        slab(mb, 0, 0, 0.66, 0.1, 0.04, 0.06, "yellow")
    out(d, "wet_floor_sign", {"yellow": M((1.0, 0.82, 0.1), 0.4), "black": BLACK}, wet_floor_sign)

    def notice_board(mb):      # wall: 1.2 x 0.9 cork
        slab(mb, 0, -0.015, 0, 1.2, 0.03, 0.9, "cork")
        frame_rect(mb, 0, 0, 1.24, 0.94, 0.04, -0.04, 0.0, "frame")
        for k in range(7):
            x = random.uniform(-0.45, 0.45); z = random.uniform(-0.3, 0.3)
            w, h = random.choice(((0.21, 0.3), (0.15, 0.1), (0.3, 0.21)))
            slab(mb, x, -0.032 - k * 0.0005, z, w, 0.001, h, random.choice(("p1", "p2", "p3")))
            sphere(mb, (x, -0.036, z + h / 2 - 0.02), 0.008, "pin", 3, 6)
    out(d, "notice_board", {"cork": M((0.65, 0.48, 0.3), 0.95), "frame": M((0.6, 0.6, 0.62), 0.4, 0.6), "p1": PAPER, "p2": M((1.0, 0.95, 0.6), 0.9),
                            "p3": M((0.75, 0.85, 1.0), 0.9), "pin": M((0.9, 0.15, 0.15), 0.4)}, notice_board)

    def water_cooler(mb):
        slab(mb, 0, 0, 0.5, 0.32, 0.32, 1.0, "white")
        lathe(mb, [(0.05, 1.0), (0.14, 1.06), (0.15, 1.35), (0.12, 1.42), (0.03, 1.45), (0.0, 1.45)], 16, "water")
        slab(mb, 0, -0.165, 0.8, 0.2, 0.02, 0.12, "grey")
        for x, m in ((-0.05, "blue"), (0.05, "red")):
            slab(mb, x, -0.18, 0.84, 0.03, 0.03, 0.04, m)
        slab(mb, 0, -0.17, 0.62, 0.18, 0.05, 0.02, "grey")
    out(d, "water_cooler", {"white": WHITE, "water": M((0.55, 0.75, 0.95), 0.05, 0, 0, 0.55), "grey": M((0.4, 0.42, 0.45), 0.5),
                            "blue": M((0.2, 0.4, 0.9), 0.4), "red": M((0.9, 0.2, 0.2), 0.4)}, water_cooler)

    def vending_machine(mb):
        rounded_box(mb, V((0, 0, 0.92)), (0.9, 0.8, 1.84), 0.03, "body")
        slab(mb, -0.12, -0.401, 1.05, 0.56, 0.004, 1.3, "glass")
        for r in range(5):
            for c in range(5):
                slab(mb, -0.34 + c * 0.11, -0.3, 0.55 + r * 0.25, 0.07, 0.12, 0.14, random.choice(("s1", "s2", "s3", "s4")))
        slab(mb, 0.3, -0.402, 1.2, 0.18, 0.004, 0.4, "panel")
        for k in range(9):
            slab(mb, 0.26 + (k % 3) * 0.04, -0.405, 1.3 - (k // 3) * 0.05, 0.03, 0.004, 0.03, "key")
        slab(mb, -0.12, -0.402, 0.22, 0.5, 0.01, 0.16, "black")
    out(d, "vending_machine", {"body": M((0.15, 0.3, 0.55), 0.4, 0.3), "glass": M((0.6, 0.7, 0.75), 0.05, 0, 0.4, 0.3, True),
                               "s1": M((0.9, 0.2, 0.2), 0.4), "s2": M((0.95, 0.75, 0.2), 0.4), "s3": M((0.3, 0.7, 0.3), 0.4), "s4": M((0.6, 0.3, 0.7), 0.4),
                               "panel": BLACK, "key": STEEL, "black": BLACK}, vending_machine)

    def privacy_screen(mb):    # three folding panels, 1.8 wide
        for k in range(3):
            x = -0.6 + k * 0.6
            y = 0.08 if k == 1 else 0.0
            for s in (-0.28, 0.28):
                cyl(mb, (x + s, y, 0.05), 0.012, 1.65, "steel", 6)
                sphere(mb, (x + s, y, 0.04), 0.03, "black", 4, 6)
            slab(mb, x, y, 1.0, 0.54, 0.01, 1.2, "cloth")
            slab(mb, x, y, 1.68, 0.58, 0.02, 0.02, "steel")
    out(d, "privacy_screen", {"steel": CHROME, "black": BLACK, "cloth": M((0.6, 0.78, 0.75), 0.95, 0, 0, 1, True)}, privacy_screen)

    def stretcher(mb):         # 2.0 long along Godot Z
        slab(mb, 0, 0, 0.75, 0.6, 2.0, 0.06, "pad")
        for y in (-0.9, 0.9):
            for x in (-0.28, 0.28):
                rod(mb, (x, y * 0.85, 0.72), (x * 0.9, y * 0.9, 0.08), 0.015, "steel")
                sphere(mb, (x * 0.9, y * 0.9, 0.06), 0.06, "black", 5, 8)
        slab(mb, 0, 0, 0.35, 0.5, 1.6, 0.02, "steel")
        for x in (-0.31, 0.31):
            cyl(mb, (x, -0.95, 0.85), 0.012, 1.9, "steel", 6, "y")
        rounded_box(mb, V((0, 0.82, 0.82)), (0.45, 0.28, 0.1), 0.04, "sheet")
        slab(mb, 0, -0.15, 0.79, 0.62, 1.3, 0.02, "sheet")
    out(d, "stretcher", {"pad": M((0.25, 0.3, 0.35), 0.6), "steel": CHROME, "black": BLACK, "sheet": M((0.94, 0.95, 0.96), 0.9)}, stretcher)

    def oxygen_tank(mb):
        lathe(mb, [(0.0, 0.0), (0.09, 0.0), (0.09, 0.95), (0.05, 1.05), (0.02, 1.08)], 16, "green")
        cyl(mb, (0, 0, 1.08), 0.025, 0.08, "brass", 8)
        cyl(mb, (-0.05, 0, 1.13), 0.03, 0.03, "steel", 10, "x")
        lathe(mb, [(0.12, 0.0), (0.12, 0.05)], 16, "black")
    out(d, "oxygen_tank", {"green": M((0.15, 0.45, 0.25), 0.35, 0.4), "brass": BRASS, "steel": CHROME, "black": BLACK}, oxygen_tank)

    def xray_lightbox(mb):     # wall: 0.9 x 0.6
        slab(mb, 0, -0.04, 0, 0.9, 0.08, 0.6, "case")
        slab(mb, 0, -0.081, 0, 0.84, 0.002, 0.54, "glow")
        slab(mb, -0.2, -0.083, 0, 0.36, 0.002, 0.46, "film")
        slab(mb, 0.2, -0.083, 0, 0.36, 0.002, 0.46, "film")
        for k in range(6):
            slab(mb, -0.2, -0.085, -0.15 + k * 0.06, 0.2 - abs(k - 2.5) * 0.02, 0.001, 0.015, "bone")
    out(d, "xray_lightbox", {"case": WHITE, "glow": M((0.85, 0.92, 1.0), 0.3, 0, 2.0), "film": M((0.05, 0.07, 0.1), 0.2, 0, 0, 0.85),
                             "bone": M((0.7, 0.75, 0.8), 0.4, 0, 0.8)}, xray_lightbox)

    def sharps_bin(mb):        # wall
        slab(mb, 0, -0.08, 0, 0.22, 0.16, 0.3, "yellow")
        slab(mb, 0, -0.08, 0.16, 0.24, 0.18, 0.03, "lid")
        slab(mb, 0, -0.161, 0.0, 0.16, 0.002, 0.08, "label")
    out(d, "sharps_bin", {"yellow": M((1.0, 0.8, 0.1), 0.4), "lid": M((0.85, 0.1, 0.1), 0.4), "label": PAPER}, sharps_bin)

    def get_well_card(mb):     # a standing folded card
        for s in (-1, 1):
            a = mb.add_vert(V((-0.08, 0, 0.2)), []); b = mb.add_vert(V((0.08, 0, 0.2)), [])
            c = mb.add_vert(V((0.08, s * 0.06, 0.0)), []); dd = mb.add_vert(V((-0.08, s * 0.06, 0.0)), [])
            mb.add_face([a, b, c, dd], [(0, 1), (1, 1), (1, 0), (0, 0)], "card" if s < 0 else "inside", smooth=False)
            mb.add_face([dd, c, b, a], [(0, 0), (1, 0), (1, 1), (0, 1)], "card" if s < 0 else "inside", smooth=False)
        sphere(mb, (0, -0.035, 0.1), 0.03, "flower", 4, 8, 0.2)
    out(d, "get_well_card", {"card": M((0.95, 0.85, 0.4), 0.8), "inside": PAPER, "flower": M((0.9, 0.3, 0.45), 0.6)}, get_well_card)

    def med_cabinet(mb):       # wall: a glass-fronted cabinet, 0.8 x 1.0, bottom at z=0
        slab(mb, 0, -0.15, 0.5, 0.8, 0.3, 1.0, "white")
        slab(mb, 0, -0.302, 0.5, 0.74, 0.004, 0.94, "glass")
        for z in (0.33, 0.66):
            slab(mb, 0, -0.15, z, 0.74, 0.26, 0.015, "white")
        for z0 in (0.02, 0.35, 0.68):
            for k in range(6):
                x = -0.3 + k * 0.12
                cyl(mb, (x, -0.15, z0), 0.03, random.uniform(0.08, 0.2), random.choice(("amber", "white2", "blue")), 10)
        slab(mb, 0.3, -0.31, 0.5, 0.02, 0.02, 0.15, "steel")
        slab(mb, 0, -0.01, 0.92, 0.12, 0.004, 0.12, "cross")
    out(d, "med_cabinet", {"white": WHITE, "glass": M((0.7, 0.8, 0.85), 0.05, 0, 0, 0.3, True), "amber": M((0.6, 0.3, 0.05), 0.2, 0, 0, 0.8),
                           "white2": M((0.95, 0.95, 0.95), 0.4), "blue": M((0.3, 0.45, 0.8), 0.3), "steel": CHROME, "cross": M((0.2, 0.7, 0.3), 0.4)}, med_cabinet)

    def bird_bath(mb):
        lathe(mb, [(0.18, 0.0), (0.18, 0.06), (0.08, 0.1), (0.07, 0.7), (0.1, 0.75), (0.38, 0.85), (0.4, 0.9), (0.34, 0.9), (0.08, 0.82)], 20, "stone")
        lathe(mb, [(0.33, 0.86), (0.0, 0.86)], 20, "water", cap_start=False, cap_end=False)
    out(d, "bird_bath", {"stone": M((0.6, 0.6, 0.57), 0.9), "water": M((0.3, 0.45, 0.5), 0.05)}, bird_bath)

    def planter_box(mb):       # 1.6 x 0.6 wooden planter with flowers
        slab(mb, 0, 0, 0.25, 1.6, 0.6, 0.5, "wood")
        slab(mb, 0, 0, 0.48, 1.5, 0.5, 0.02, "soil")
        for k in range(14):
            x = -0.68 + k * 0.105; y = random.uniform(-0.18, 0.18)
            h = random.uniform(0.18, 0.35)
            rod(mb, (x, y, 0.48), (x, y, 0.48 + h), 0.006, "stem", 4)
            sphere(mb, (x, y, 0.5 + h), 0.035, random.choice(("f1", "f2", "f3")), 4, 6)
    out(d, "planter_box", {"wood": M((0.45, 0.32, 0.2), 0.8), "soil": M((0.2, 0.14, 0.08), 1.0), "stem": M((0.2, 0.45, 0.15), 0.7),
                           "f1": M((0.95, 0.95, 0.9), 0.6), "f2": M((0.95, 0.75, 0.3), 0.6), "f3": M((0.7, 0.45, 0.85), 0.6)}, planter_box)

    def lantern_post(mb):      # a garden lamp
        cyl(mb, (0, 0, 0), 0.08, 0.1, "iron", 10)
        cyl(mb, (0, 0, 0.1), 0.03, 1.4, "iron", 8)
        lathe(mb, [(0.0, 1.5), (0.1, 1.52), (0.12, 1.75), (0.0, 1.85)], 6, "glass")
        cone(mb, (0, 0, 1.78), 0.16, 0.0, 0.14, "iron", 6)
    out(d, "lantern_post", {"iron": M((0.12, 0.12, 0.13), 0.5, 0.6), "glass": M((1.0, 0.92, 0.7), 0.2, 0, 3.0)}, lantern_post)
