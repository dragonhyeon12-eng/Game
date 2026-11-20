"""Furniture and fittings for every interior (models/props/*.glb). All face Godot +Z (Blender -Y) unless noted,
origin on the floor at the footprint's centre.

  desk_wood (1.5 x 0.7, drawers)       office_chair (5-star base)        bed_single (head toward -Z)
  nightstand        alarm_clock (digital)       wardrobe (1.3 x 0.7 x 2.0, two doors)
  desk_lamp (articulated)   mug    curtain (a gathered panel, 0.6 x 1.4)
  sofa   tv_crt   kitchen_table   chair_wood   bathtub   sink_basin (on a pedestal)   toilet
  hospital_bed  iv_stand  waiting_chairs (a row of three)  filing_cabinet  trolley  wheelchair
  potted_plant  crate  bookshelf_books  radiator  counter (1.8 shop counter)  clothes_rack  bunk_bed
"""
import math
import random

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder
from kit import box
from home import lathe, rounded_box, _wood, _fabric


def _export(path, name, M, fn):
    scene.reset()
    M = M()
    mb = MeshBuilder()
    fn(mb)
    o = mb.to_object(name, M, recalc_normals=True)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(path, [o])


def _mats_wood(name, rgb, seed):
    a, n = _wood(name, rgb, seed, 40)
    return scene.material(name, a, normal_tex=n, roughness=0.5)


def _mats_fabric(name, rgb, seed, weave=64):
    a, n = _fabric(name, rgb, seed, weave)
    return scene.material(name, a, normal_tex=n, roughness=0.95)


def M_metal(name="metal", rgb=(0.6, 0.6, 0.62), r=0.35):
    return scene.material(name, base_color=rgb, roughness=r, metallic=0.85)


def M_plain(name, rgb, r=0.5, emit=0.0):
    return scene.material(name, base_color=rgb, roughness=r, emission_color=rgb if emit else None, emission_strength=emit)


def legs4(mb, w, d, h, r, mat, inset=0.04, taper=0.8):
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * (w / 2 - inset), sy * (d / 2 - inset), 0))
            lathe(mb, [(r * taper, 0.0), (r, h)], 8, mat, center=c)


def build(d):
    random.seed(41)

    # ---------------------------------------------------------------- bedroom
    def desk(mb):
        W, D, H = 1.5, 0.7, 0.74
        box(mb, (-W / 2, -D / 2, H - 0.035), (W / 2, D / 2, H), "wood", 0.6)
        legs4(mb, W, D, H - 0.035, 0.022, "dark")
        box(mb, (W / 2 - 0.45, -D / 2 + 0.02, 0.15), (W / 2 - 0.03, D / 2 - 0.02, H - 0.035), "wood", 0.6)     # drawer pedestal
        for k in range(3):
            z = 0.18 + k * 0.18
            box(mb, (W / 2 - 0.44, -D / 2, z), (W / 2 - 0.04, -D / 2 + 0.015, z + 0.16), "wood", 0.3)
            box(mb, (W / 2 - 0.29, -D / 2 - 0.02, z + 0.07), (W / 2 - 0.19, -D / 2, z + 0.09), "metal", 0.05)
        box(mb, (-W / 2 + 0.03, D / 2 - 0.03, 0.3), (W / 2 - 0.46, D / 2 - 0.01, H - 0.04), "dark", 0.5)      # modesty panel
    _export(d + "/desk_wood.glb", "DeskWood", lambda: {"wood": _mats_wood("desk_oak", (0.55, 0.38, 0.22), 1), "dark": _mats_wood("desk_dark", (0.3, 0.2, 0.12), 2), "metal": M_metal()}, desk)

    def office_chair(mb):
        for k in range(5):
            a = 2 * math.pi * k / 5
            tip = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.06))
            mb.tube([Vector((0, 0, 0.1)), tip], [0.022, 0.016], 6, "black", [])
            lathe(mb, [(0.0, 0.0), (0.03, 0.0), (0.03, 0.05), (0.0, 0.05)], 8, "black", center=tip - Vector((0, 0, 0.06)))
        lathe(mb, [(0.03, 0.08), (0.025, 0.38)], 10, "chrome")
        rounded_box(mb, Vector((0, 0, 0.45)), (0.48, 0.46, 0.08), 0.03, "seat")
        mb.tube([Vector((0, 0.2, 0.42)), Vector((0, 0.25, 0.55))], [0.018, 0.018], 6, "black", [])
        rounded_box(mb, Vector((0, 0.24, 0.8)), (0.44, 0.06, 0.52), 0.03, "seat")
        for sx in (-1, 1):
            mb.tube([Vector((sx * 0.24, 0.0, 0.45)), Vector((sx * 0.26, 0.0, 0.62)), Vector((sx * 0.26, -0.15, 0.64))], [0.015] * 3, 6, "black", [])
    _export(d + "/office_chair.glb", "OfficeChair", lambda: {"black": M_plain("chair_black", (0.05, 0.05, 0.05), 0.5), "chrome": M_metal("chair_chrome", (0.75, 0.75, 0.78), 0.15),
                                                            "seat": _mats_fabric("chair_mesh", (0.12, 0.12, 0.14), 6, 120)}, office_chair)

    def bed_single(mb):
        W, L = 1.1, 2.06
        box(mb, (-W / 2, -L / 2, 0.06), (W / 2, L / 2, 0.3), "dark", 0.5)
        for sx in (-1, 1):
            for sy in (-1, 1):
                box(mb, (sx * W / 2 - 0.035, sy * L / 2 - 0.035, 0.0), (sx * W / 2 + 0.035, sy * L / 2 + 0.035, 0.32), "dark", 0.3)
        box(mb, (-W / 2, L / 2 - 0.05, 0.0), (W / 2, L / 2 + 0.03, 1.05), "dark", 0.5)           # headboard
        for k in range(5):
            x = -0.4 + k * 0.2
            box(mb, (x - 0.05, L / 2 - 0.06, 0.4), (x + 0.05, L / 2 - 0.05, 0.95), "wood", 0.2)
        rounded_box(mb, Vector((0, 0, 0.4)), (W - 0.06, L - 0.08, 0.2), 0.05, "sheet")
        rounded_box(mb, Vector((0, L / 2 - 0.3, 0.55)), (0.62, 0.36, 0.11), 0.05, "sheet")
        rounded_box(mb, Vector((0, -0.25, 0.525)), (W + 0.02, L - 0.6, 0.06), 0.03, "duvet")
        rounded_box(mb, Vector((0, 0.42, 0.535)), (W + 0.02, 0.22, 0.04), 0.018, "duvet")
    _export(d + "/bed_single.glb", "BedSingle", lambda: {"dark": _mats_wood("bed_dark", (0.3, 0.2, 0.12), 3), "wood": _mats_wood("bed_wood", (0.5, 0.34, 0.2), 4),
                                                        "sheet": _mats_fabric("bed_sheet", (0.85, 0.85, 0.83), 7), "duvet": _mats_fabric("bed_duvet", (0.16, 0.3, 0.36), 8, 40)}, bed_single)

    def nightstand(mb):
        box(mb, (-0.25, -0.22, 0.04), (0.25, 0.22, 0.56), "wood", 0.5)
        box(mb, (-0.26, -0.23, 0.53), (0.26, 0.23, 0.56), "wood", 0.5)
        for z in (0.1, 0.32):
            box(mb, (-0.22, -0.235, z), (0.22, -0.22, z + 0.18), "wood", 0.3)
            lathe(mb, [(0.012, 0.0), (0.015, 0.02), (0.0, 0.025)], 8, "metal", center=Vector((0, -0.235, z + 0.09)))
        legs4(mb, 0.5, 0.44, 0.04, 0.02, "wood")
    _export(d + "/nightstand.glb", "Nightstand", lambda: {"wood": _mats_wood("ns_wood", (0.55, 0.38, 0.22), 9), "metal": M_metal()}, nightstand)

    def clock(mb):
        rounded_box(mb, Vector((0, 0, 0.05)), (0.2, 0.08, 0.1), 0.02, "plastic")
        box(mb, (-0.08, -0.042, 0.02), (0.08, -0.039, 0.08), "screen", 0.05)
    _export(d + "/alarm_clock.glb", "AlarmClock", lambda: {"plastic": M_plain("clock_plastic", (0.06, 0.06, 0.07), 0.4), "screen": M_plain("clock_screen", (0.05, 0.0, 0.0), 0.1)}, clock)

    def wardrobe(mb):
        W, D, H = 1.3, 0.7, 2.0
        box(mb, (-W / 2, -D / 2, 0.06), (W / 2, D / 2, H), "wood", 0.6)
        box(mb, (-W / 2 - 0.02, -D / 2 - 0.02, H - 0.05), (W / 2 + 0.02, D / 2 + 0.02, H + 0.02), "wood", 0.6)      # cornice
        box(mb, (-W / 2 + 0.02, -D / 2 + 0.02, 0.0), (W / 2 - 0.02, D / 2 - 0.02, 0.06), "dark", 0.3)
        for sx in (-1, 1):
            x0, x1 = (-W / 2 + 0.02, -0.005) if sx < 0 else (0.005, W / 2 - 0.02)
            box(mb, (x0, -D / 2 - 0.02, 0.1), (x1, -D / 2, H - 0.07), "wood", 0.5)
            box(mb, (x0 + 0.06, -D / 2 - 0.03, 0.2), (x1 - 0.06, -D / 2 - 0.02, H - 0.2), "wood", 0.4)
            mb.tube([Vector((sx * 0.05, -D / 2 - 0.05, 0.95)), Vector((sx * 0.05, -D / 2 - 0.05, 1.15))], [0.01, 0.01], 6, "metal", [])
    _export(d + "/wardrobe.glb", "Wardrobe", lambda: {"wood": _mats_wood("wr_wood", (0.55, 0.38, 0.22), 10), "dark": _mats_wood("wr_dark", (0.3, 0.2, 0.12), 11), "metal": M_metal()}, wardrobe)

    def desk_lamp(mb):
        lathe(mb, [(0.0, 0.0), (0.075, 0.0), (0.07, 0.02), (0.02, 0.03), (0.0, 0.03)], 16, "metal")
        mb.tube([Vector((0, 0, 0.03)), Vector((0.03, 0, 0.25))], [0.007] * 2, 6, "metal", [])
        mb.tube([Vector((0.03, 0, 0.25)), Vector((0.12, 0, 0.36))], [0.007] * 2, 6, "metal", [])
        for p in (Vector((0.03, 0, 0.25)),):
            lathe(mb, [(0.0, -0.012), (0.015, -0.012), (0.015, 0.012), (0.0, 0.012)], 8, "metal", center=p)
        lathe(mb, [(0.012, 0.0), (0.03, -0.02), (0.07, -0.09), (0.068, -0.095)], 16, "shade", cap_start=True, cap_end=False, center=Vector((0.12, 0, 0.37)))
        lathe(mb, [(0.0, -0.06), (0.022, -0.05), (0.0, -0.03)], 10, "bulb", center=Vector((0.12, 0, 0.37)))
    _export(d + "/desk_lamp.glb", "DeskLamp", lambda: {"metal": M_metal("lamp_metal", (0.1, 0.1, 0.11), 0.4), "shade": M_plain("lamp_shade_black", (0.05, 0.05, 0.06), 0.4),
                                                      "bulb": M_plain("lamp_bulb", (1.0, 0.9, 0.7), 0.2, 2.0)}, desk_lamp)

    def mug(mb):
        lathe(mb, [(0.0, 0.0), (0.038, 0.0), (0.04, 0.005), (0.04, 0.095), (0.036, 0.095), (0.035, 0.012), (0.0, 0.012)], 18, "cer")
        mb.tube([Vector((0.04, 0, 0.075)), Vector((0.065, 0, 0.07)), Vector((0.065, 0, 0.03)), Vector((0.04, 0, 0.025))], [0.007] * 4, 6, "cer", [])
        lathe(mb, [(0.0, 0.07), (0.035, 0.07)], 18, "coffee", cap_start=False, cap_end=False)
    _export(d + "/mug.glb", "Mug", lambda: {"cer": M_plain("mug_ceramic", (0.7, 0.25, 0.2), 0.25), "coffee": M_plain("mug_coffee", (0.12, 0.06, 0.03), 0.1)}, mug)

    def curtain(mb):
        W, H = 0.6, 1.4
        n = 24
        rings = []
        for k, z in enumerate((0.0, H * 0.5, H)):
            ring = [Vector((-W / 2 + W * i / (n - 1), 0.03 * math.sin(i * 1.2) * (1.0 + 0.3 * (k == 0)), z)) for i in range(n)]
            rings.append(ring)
        mb.loft(rings, "cloth", lambda ri, p: [], closed=False, cap_start=False, cap_end=False)
        mb.tube([Vector((-W / 2 - 0.05, 0, H + 0.03)), Vector((W / 2 + 0.05, 0, H + 0.03))], [0.012, 0.012], 8, "metal", [], cap_start=True)
    _export(d + "/curtain.glb", "Curtain", lambda: {"cloth": scene.material("curtain_cloth", base_color=(0.3, 0.12, 0.15), roughness=0.95, double_sided=True), "metal": M_metal()}, curtain)

    # ---------------------------------------------------------------- living rooms
    def sofa(mb):
        rounded_box(mb, Vector((0, 0, 0.22)), (1.9, 0.85, 0.3), 0.06, "fab")
        for k in range(3):
            rounded_box(mb, Vector((-0.6 + k * 0.6, -0.04, 0.43)), (0.58, 0.7, 0.14), 0.06, "fab")
            rounded_box(mb, Vector((-0.6 + k * 0.6, 0.34, 0.68)), (0.56, 0.18, 0.46), 0.07, "fab")
        for sx in (-1, 1):
            rounded_box(mb, Vector((sx * 0.92, 0.0, 0.42)), (0.18, 0.85, 0.42), 0.07, "fab")
        legs4(mb, 1.8, 0.75, 0.08, 0.025, "wood")
    _export(d + "/sofa.glb", "Sofa", lambda: {"fab": _mats_fabric("sofa_fab", (0.32, 0.34, 0.42), 12), "wood": _mats_wood("sofa_leg", (0.3, 0.2, 0.12), 13)}, sofa)

    def tv(mb):
        rounded_box(mb, Vector((0, 0.05, 0.3)), (0.62, 0.5, 0.5), 0.04, "plastic")
        box(mb, (-0.25, -0.205, 0.12), (0.25, -0.2, 0.48), "screen", 0.1)
        box(mb, (0.2, -0.21, 0.08), (0.28, -0.2, 0.11), "plastic", 0.05)
        mb.tube([Vector((-0.08, 0.1, 0.55)), Vector((-0.2, 0.15, 0.85))], [0.004, 0.003], 4, "metal", [])
        mb.tube([Vector((0.08, 0.1, 0.55)), Vector((0.2, 0.15, 0.85))], [0.004, 0.003], 4, "metal", [])
    _export(d + "/tv_crt.glb", "TV", lambda: {"plastic": M_plain("tv_plastic", (0.1, 0.09, 0.08), 0.5), "screen": M_plain("tv_screen", (0.05, 0.07, 0.07), 0.05), "metal": M_metal()}, tv)

    def kitchen_table(mb):
        box(mb, (-0.6, -0.45, 0.72), (0.6, 0.45, 0.76), "wood", 0.6)
        box(mb, (-0.55, -0.4, 0.64), (0.55, 0.4, 0.72), "wood", 0.6)
        legs4(mb, 1.12, 0.82, 0.72, 0.03, "wood")
    _export(d + "/kitchen_table.glb", "KitchenTable", lambda: {"wood": _mats_wood("kt_wood", (0.6, 0.45, 0.3), 14)}, kitchen_table)

    def chair_wood(mb):
        box(mb, (-0.21, -0.2, 0.43), (0.21, 0.2, 0.47), "wood", 0.4)
        legs4(mb, 0.42, 0.4, 0.43, 0.018, "wood", inset=0.025)
        for sx in (-1, 1):
            box(mb, (sx * 0.19 - 0.02, 0.17, 0.43), (sx * 0.19 + 0.02, 0.2, 0.92), "wood", 0.2)
        for z in (0.62, 0.74, 0.86):
            box(mb, (-0.19, 0.175, z), (0.19, 0.195, z + 0.05), "wood", 0.2)
    _export(d + "/chair_wood.glb", "ChairWood", lambda: {"wood": _mats_wood("cw_wood", (0.5, 0.35, 0.22), 15)}, chair_wood)

    # ---------------------------------------------------------------- bathroom
    def bathtub(mb):
        rings = []
        for z, s in ((0.0, 0.92), (0.15, 0.97), (0.55, 1.0), (0.58, 1.02)):
            rings.append([Vector((math.cos(a) * 0.38 * s * (1 + 0.6 * abs(math.cos(a)) ** 6), math.sin(a) * 0.82 * s, z)) for a in (2 * math.pi * k / 28 for k in range(28))])
        mb.loft(rings, "enamel", lambda ri, p: [], cap_start=True, cap_end=False)
        inner = [[Vector((p.x * 0.88, p.y * 0.93, z)) for p in rings[-1]] for z in (0.58, 0.12)]
        mb.loft(inner, "enamel", lambda ri, p: [], cap_start=False, cap_end=True)
        mb.loft([rings[-1], inner[0]], "enamel", lambda ri, p: [], cap_start=False, cap_end=False)
        mb.tube([Vector((0, 0.82, 0.6)), Vector((0, 0.82, 0.72)), Vector((0, 0.7, 0.75))], [0.015] * 3, 8, "chrome", [])
    _export(d + "/bathtub.glb", "Bathtub", lambda: {"enamel": M_plain("tub_enamel", (0.92, 0.92, 0.9), 0.15), "chrome": M_metal("tub_chrome", (0.8, 0.8, 0.82), 0.1)}, bathtub)

    def sink(mb):
        lathe(mb, [(0.05, 0.0), (0.08, 0.0), (0.06, 0.4), (0.09, 0.75), (0.0, 0.76)], 16, "cer")
        rounded_box(mb, Vector((0, 0, 0.8)), (0.55, 0.42, 0.12), 0.05, "cer")
        lathe(mb, [(0.0, 0.83), (0.18, 0.86)], 20, "basin", cap_start=False, cap_end=False, center=Vector((0, -0.02, 0)))
        mb.tube([Vector((0, 0.15, 0.86)), Vector((0, 0.15, 0.95)), Vector((0, 0.05, 0.96))], [0.012] * 3, 8, "chrome", [])
    _export(d + "/sink_basin.glb", "Sink", lambda: {"cer": M_plain("sink_cer", (0.93, 0.93, 0.92), 0.15), "basin": M_plain("sink_basin", (0.85, 0.86, 0.86), 0.1), "chrome": M_metal("sink_chrome", (0.8, 0.8, 0.82), 0.1)}, sink)

    def toilet(mb):
        lathe(mb, [(0.0, 0.0), (0.13, 0.0), (0.12, 0.2), (0.18, 0.38), (0.0, 0.4)], 20, "cer")
        rounded_box(mb, Vector((0, -0.05, 0.41)), (0.38, 0.46, 0.04), 0.04, "seat")
        rounded_box(mb, Vector((0, 0.24, 0.62)), (0.42, 0.18, 0.4), 0.03, "cer")
        box(mb, (-0.03, 0.2, 0.82), (0.03, 0.26, 0.83), "chrome", 0.02)
    _export(d + "/toilet.glb", "Toilet", lambda: {"cer": M_plain("wc_cer", (0.93, 0.93, 0.92), 0.15), "seat": M_plain("wc_seat", (0.95, 0.95, 0.95), 0.3), "chrome": M_metal()}, toilet)

    # ---------------------------------------------------------------- hospital
    def hospital_bed(mb):
        W, L = 0.95, 2.1
        box(mb, (-W / 2, -L / 2, 0.45), (W / 2, L / 2, 0.52), "frame", 0.5)
        for sx in (-1, 1):
            for sy in (-1, 1):
                c = Vector((sx * (W / 2 - 0.05), sy * (L / 2 - 0.06), 0))
                lathe(mb, [(0.02, 0.1), (0.02, 0.45)], 8, "frame", center=c)
                lathe(mb, [(0.0, 0.0), (0.05, 0.0), (0.05, 0.05), (0.0, 0.05)], 10, "black", center=c)
        for sy in (-1, 1):   # head and foot boards
            box(mb, (-W / 2, sy * L / 2 - 0.02, 0.45), (W / 2, sy * L / 2 + 0.02, 0.95 if sy > 0 else 0.8), "board", 0.5)
        for sx in (-1, 1):   # rails
            for z in (0.7, 0.8):
                mb.tube([Vector((sx * W / 2, -0.4, z)), Vector((sx * W / 2, 0.5, z))], [0.012] * 2, 6, "frame", [])
        rounded_box(mb, Vector((0, 0, 0.6)), (W - 0.06, L - 0.06, 0.16), 0.04, "sheet")
        rounded_box(mb, Vector((0, L / 2 - 0.3, 0.72)), (0.6, 0.35, 0.1), 0.04, "sheet")
        rounded_box(mb, Vector((0, -0.25, 0.7)), (W, L - 0.7, 0.04), 0.02, "blanket")
    _export(d + "/hospital_bed.glb", "HospitalBed", lambda: {"frame": M_metal("hb_frame", (0.8, 0.8, 0.82), 0.3), "black": M_plain("hb_wheel", (0.05, 0.05, 0.05), 0.6),
                                                            "board": M_plain("hb_board", (0.75, 0.8, 0.85), 0.4), "sheet": _mats_fabric("hb_sheet", (0.9, 0.92, 0.94), 16),
                                                            "blanket": _mats_fabric("hb_blanket", (0.55, 0.7, 0.75), 17, 40)}, hospital_bed)

    def iv_stand(mb):
        for k in range(5):
            a = 2 * math.pi * k / 5
            mb.tube([Vector((0, 0, 0.08)), Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, 0.04))], [0.012, 0.01], 6, "metal", [])
        lathe(mb, [(0.012, 0.08), (0.01, 1.9)], 8, "metal")
        for sx in (-1, 1):
            mb.tube([Vector((0, 0, 1.9)), Vector((sx * 0.12, 0, 1.92)), Vector((sx * 0.13, 0, 1.86))], [0.006] * 3, 5, "metal", [])
        rounded_box(mb, Vector((0.12, 0, 1.72)), (0.1, 0.04, 0.18), 0.02, "bag")
        mb.tube([Vector((0.12, 0, 1.62)), Vector((0.1, 0.02, 1.2)), Vector((0.2, 0.1, 0.9))], [0.002] * 3, 4, "bag", [])
    _export(d + "/iv_stand.glb", "IVStand", lambda: {"metal": M_metal("iv_metal", (0.8, 0.8, 0.82), 0.25), "bag": scene.material("iv_bag", base_color=(0.85, 0.9, 0.95), roughness=0.1, alpha=0.6)}, iv_stand)

    def waiting_chairs(mb):
        box(mb, (-0.85, -0.05, 0.35), (0.85, 0.05, 0.4), "metal", 0.3)
        for x in (-0.75, 0.75):
            mb.tube([Vector((x, 0, 0.35)), Vector((x, -0.2, 0.0))], [0.02] * 2, 6, "metal", [])
            mb.tube([Vector((x, 0, 0.35)), Vector((x, 0.2, 0.0))], [0.02] * 2, 6, "metal", [])
        for k in range(3):
            x = -0.55 + k * 0.55
            rounded_box(mb, Vector((x, -0.02, 0.45)), (0.5, 0.46, 0.06), 0.02, "plastic")
            rounded_box(mb, Vector((x, 0.22, 0.75)), (0.5, 0.05, 0.42), 0.02, "plastic")
    _export(d + "/waiting_chairs.glb", "WaitingChairs", lambda: {"metal": M_metal(), "plastic": M_plain("wc_blue", (0.18, 0.35, 0.55), 0.4)}, waiting_chairs)

    def filing_cabinet(mb):
        box(mb, (-0.24, -0.3, 0.0), (0.24, 0.3, 1.32), "grey", 0.4)
        for k in range(4):
            z = 0.04 + k * 0.32
            box(mb, (-0.22, -0.31, z), (0.22, -0.3, z + 0.29), "grey", 0.3)
            box(mb, (-0.06, -0.33, z + 0.2), (0.06, -0.31, z + 0.23), "metal", 0.05)
            box(mb, (-0.04, -0.312, z + 0.1), (0.04, -0.31, z + 0.15), "label", 0.05)
    _export(d + "/filing_cabinet.glb", "FilingCabinet", lambda: {"grey": M_plain("fc_grey", (0.55, 0.57, 0.58), 0.4), "metal": M_metal(), "label": M_plain("fc_label", (0.9, 0.88, 0.8), 0.6)}, filing_cabinet)

    def trolley(mb):
        for z in (0.25, 0.85):
            box(mb, (-0.35, -0.25, z), (0.35, 0.25, z + 0.03), "metal", 0.3)
        for sx in (-1, 1):
            for sy in (-1, 1):
                c = Vector((sx * 0.32, sy * 0.22, 0))
                lathe(mb, [(0.012, 0.07), (0.012, 0.88)], 6, "metal", center=c)
                lathe(mb, [(0.0, 0.0), (0.04, 0.0), (0.04, 0.04), (0.0, 0.04)], 8, "black", center=c)
        mb.tube([Vector((-0.32, 0.25, 0.88)), Vector((-0.32, 0.3, 0.98)), Vector((0.32, 0.3, 0.98)), Vector((0.32, 0.25, 0.88))], [0.012] * 4, 6, "metal", [])
        for k in range(4):
            lathe(mb, [(0.0, 0.0), (0.02, 0.0), (0.02, 0.09), (0.0, 0.1)], 8, "bottle", center=Vector((-0.2 + k * 0.1, 0.0, 0.88)))
        box(mb, (0.05, -0.15, 0.88), (0.3, 0.1, 0.9), "tray", 0.1)
    _export(d + "/trolley.glb", "Trolley", lambda: {"metal": M_metal("tr_metal", (0.78, 0.78, 0.8), 0.25), "black": M_plain("tr_wheel", (0.05, 0.05, 0.05), 0.6),
                                                   "bottle": scene.material("tr_bottle", base_color=(0.6, 0.75, 0.8), roughness=0.1, alpha=0.6), "tray": M_metal("tr_tray", (0.7, 0.7, 0.72), 0.2)}, trolley)

    def wheelchair(mb):
        for sx in (-1, 1):
            c = Vector((sx * 0.3, 0.05, 0.3))
            pts = [c + Vector((0, math.cos(a) * 0.3, math.sin(a) * 0.3)) for a in (2 * math.pi * k / 24 for k in range(25))]
            mb.tube(pts, [0.015] * len(pts), 6, "black", [])
            for k in range(8):
                a = 2 * math.pi * k / 8
                mb.tube([c, c + Vector((0, math.cos(a) * 0.29, math.sin(a) * 0.29))], [0.003] * 2, 4, "metal", [])
            mb.tube([Vector((sx * 0.25, -0.3, 0.05)), Vector((sx * 0.25, -0.3, 0.45))], [0.012] * 2, 6, "metal", [])
            lathe(mb, [(0.0, 0.0), (0.05, 0.0), (0.05, 0.03), (0.0, 0.03)], 8, "black", center=Vector((sx * 0.25, -0.33, 0.0)))
            mb.tube([Vector((sx * 0.24, 0.2, 0.45)), Vector((sx * 0.24, 0.25, 0.95)), Vector((sx * 0.24, 0.35, 0.95))], [0.012] * 3, 6, "metal", [])
        rounded_box(mb, Vector((0, -0.02, 0.48)), (0.46, 0.44, 0.05), 0.02, "seat")
        rounded_box(mb, Vector((0, 0.22, 0.72)), (0.46, 0.04, 0.42), 0.02, "seat")
        box(mb, (-0.2, -0.45, 0.08), (0.2, -0.3, 0.1), "metal", 0.1)
    _export(d + "/wheelchair.glb", "Wheelchair", lambda: {"metal": M_metal("whc_metal", (0.75, 0.75, 0.78), 0.25), "black": M_plain("whc_black", (0.05, 0.05, 0.05), 0.6),
                                                         "seat": M_plain("whc_seat", (0.1, 0.1, 0.12), 0.7)}, wheelchair)

    # ---------------------------------------------------------------- general
    def plant(mb):
        lathe(mb, [(0.0, 0.0), (0.15, 0.0), (0.2, 0.4), (0.21, 0.42), (0.0, 0.42)], 18, "pot")
        rnd = random.Random(5)
        for k in range(14):
            a = 2 * math.pi * k / 14 + rnd.random() * 0.3
            h = rnd.uniform(0.5, 0.9)
            base = Vector((0, 0, 0.4))
            tip = Vector((math.cos(a) * rnd.uniform(0.25, 0.45), math.sin(a) * rnd.uniform(0.25, 0.45), 0.4 + h))
            mid = (base + tip) * 0.5 + Vector((0, 0, 0.15))
            mb.tube([base, mid], [0.008, 0.006], 4, "stem", [])
            side = Vector((-(tip - mid).y, (tip - mid).x, 0)).normalized() * 0.07
            ids = [mb.add_vert(mid, []), mb.add_vert((mid + tip) * 0.5 + side, []), mb.add_vert(tip, []), mb.add_vert((mid + tip) * 0.5 - side, [])]
            mb.add_face(ids, [(0, 0), (1, 0.5), (0, 1), (-1, 0.5)], "leaf", True)
    _export(d + "/potted_plant.glb", "PottedPlant", lambda: {"pot": M_plain("plant_pot", (0.6, 0.35, 0.25), 0.7), "stem": M_plain("plant_stem", (0.25, 0.4, 0.15), 0.6),
                                                            "leaf": scene.material("plant_leaf", base_color=(0.2, 0.45, 0.18), roughness=0.5, double_sided=True)}, plant)

    def crate(mb):
        S = 0.8
        box(mb, (-S / 2, -S / 2, 0.0), (S / 2, S / 2, S), "wood", 0.4)
        for f in range(4):
            a = f * math.pi / 2
            n = Vector((math.cos(a), math.sin(a), 0))
            t = Vector((-n.y, n.x, 0))
            c = n * (S / 2 + 0.01)
            for z in (0.06, S - 0.06):
                p0, p1 = c - t * S / 2 + Vector((0, 0, z - 0.05)), c + t * S / 2 + Vector((0, 0, z + 0.05))
                box(mb, (min(p0.x, p1.x) - 0.01, min(p0.y, p1.y) - 0.01, p0.z), (max(p0.x, p1.x) + 0.01, max(p0.y, p1.y) + 0.01, p1.z), "dark", 0.3)
    _export(d + "/crate.glb", "Crate", lambda: {"wood": _mats_wood("crate_wood", (0.6, 0.48, 0.3), 18), "dark": _mats_wood("crate_dark", (0.4, 0.3, 0.18), 19)}, crate)

    def bookshelf(mb):
        W, D, H = 0.9, 0.3, 1.9
        box(mb, (-W / 2, -D / 2, 0), (-W / 2 + 0.02, D / 2, H), "wood", 0.4)
        box(mb, (W / 2 - 0.02, -D / 2, 0), (W / 2, D / 2, H), "wood", 0.4)
        box(mb, (-W / 2, D / 2 - 0.01, 0), (W / 2, D / 2, H), "wood", 0.4)
        rnd = random.Random(8)
        cols = ["b1", "b2", "b3", "b4"]
        for k in range(5):
            z = 0.04 + k * 0.38
            box(mb, (-W / 2, -D / 2, z - 0.02), (W / 2, D / 2, z), "wood", 0.4)
            x = -W / 2 + 0.03
            while x < W / 2 - 0.08 and k < 5:
                w = rnd.uniform(0.025, 0.05)
                h = rnd.uniform(0.2, 0.32)
                box(mb, (x, -D / 2 + 0.03, z), (x + w, D / 2 - 0.03, z + h), cols[rnd.randrange(4)], 0.1)
                x += w + 0.003
    _export(d + "/bookshelf_books.glb", "Bookshelf", lambda: {"wood": _mats_wood("bs_wood", (0.45, 0.3, 0.18), 20), "b1": M_plain("book_red", (0.5, 0.1, 0.08), 0.6),
                                                             "b2": M_plain("book_blue", (0.12, 0.2, 0.4), 0.6), "b3": M_plain("book_green", (0.15, 0.3, 0.15), 0.6),
                                                             "b4": M_plain("book_cream", (0.85, 0.8, 0.65), 0.6)}, bookshelf)

    def radiator(mb):
        for k in range(12):
            x = -0.45 + k * 0.08
            rounded_box(mb, Vector((x, 0, 0.42)), (0.06, 0.08, 0.6), 0.025, "paint")
        for z in (0.15, 0.68):
            mb.tube([Vector((-0.5, 0, z)), Vector((0.5, 0, z))], [0.02] * 2, 8, "paint", [], cap_start=True)
        lathe(mb, [(0.0, 0.0), (0.025, 0.0), (0.02, 0.06), (0.0, 0.07)], 8, "brass", center=Vector((0.52, 0, 0.12)))
    _export(d + "/radiator.glb", "Radiator", lambda: {"paint": M_plain("rad_paint", (0.9, 0.9, 0.88), 0.4), "brass": M_metal("rad_valve", (0.75, 0.6, 0.3), 0.3)}, radiator)

    def counter(mb):
        box(mb, (-0.9, -0.3, 0.0), (0.9, 0.3, 0.88), "body", 0.5)
        box(mb, (-0.92, -0.32, 0.88), (0.92, 0.32, 0.92), "top", 0.5)
        box(mb, (-0.88, -0.31, 0.08), (0.88, -0.3, 0.8), "panel", 0.5)
        box(mb, (-0.9, -0.28, 0.0), (0.9, 0.28, 0.08), "kick", 0.5)
    _export(d + "/counter.glb", "Counter", lambda: {"body": M_plain("ctr_body", (0.85, 0.85, 0.83), 0.4), "top": M_plain("ctr_top", (0.2, 0.2, 0.22), 0.2),
                                                   "panel": _mats_wood("ctr_panel", (0.6, 0.45, 0.3), 21), "kick": M_plain("ctr_kick", (0.1, 0.1, 0.1), 0.5)}, counter)

    def clothes_rack(mb):
        for sx in (-1, 1):
            mb.tube([Vector((sx * 0.75, 0, 0.0)), Vector((sx * 0.75, 0, 1.45))], [0.015] * 2, 8, "chrome", [])
            mb.tube([Vector((sx * 0.75, -0.25, 0.02)), Vector((sx * 0.75, 0.25, 0.02))], [0.015] * 2, 8, "chrome", [], cap_start=True)
        mb.tube([Vector((-0.78, 0, 1.45)), Vector((0.78, 0, 1.45))], [0.013] * 2, 8, "chrome", [], cap_start=True)
        rnd = random.Random(3)
        cols = ["c1", "c2", "c3", "c4"]
        for k in range(9):
            x = -0.62 + k * 0.155
            mb.tube([Vector((x, 0, 1.45)), Vector((x, 0, 1.38))], [0.003] * 2, 4, "chrome", [])
            c = cols[rnd.randrange(4)]
            rings = []
            for z, w, dd in ((1.38, 0.18, 0.04), (1.3, 0.22, 0.06), (0.95, 0.22, 0.07), (0.8, 0.23, 0.06)):
                rings.append([Vector((x + math.cos(a) * dd, math.sin(a) * w, z)) for a in (2 * math.pi * j / 10 for j in range(10))])
            mb.loft(rings, c, lambda ri, p: [], cap_start=True, cap_end=True)
    _export(d + "/clothes_rack.glb", "ClothesRack", lambda: {"chrome": M_metal("cr_chrome", (0.8, 0.8, 0.82), 0.15), "c1": _mats_fabric("cr_c1", (0.75, 0.2, 0.3), 22),
                                                            "c2": _mats_fabric("cr_c2", (0.15, 0.2, 0.35), 23), "c3": _mats_fabric("cr_c3", (0.85, 0.8, 0.7), 24),
                                                            "c4": _mats_fabric("cr_c4", (0.2, 0.2, 0.2), 25)}, clothes_rack)
