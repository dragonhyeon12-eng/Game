"""The city park and street (models/props/*.glb).

  fountain        a two-tier stone fountain sized to the park's water (basin r 2.6, rim at 0.5; upper bowl r 1.0
                  with its water at 1.855; a finial at 2.15) - the game draws the water itself
  ice_cream_cart  a pushcart: freezer body with lids, a pink trim, wheels, handle, a striped umbrella
                  (2.8 x 1.2 footprint, long axis along Godot X)
  bus_shelter     a glass shelter (open toward Godot -X), roof, bench, a timetable panel (1.8 x 4.2)
  hammock         a woven sling between two rings, 2.8 m end to end along Godot X, sagging 0.55 m
  wood_post       a weathered post with an iron ring at the top
  kite            a diamond kite (spars, sail, a bow-tie tail), in Godot's X-Y plane facing +Z
"""
import math
import random

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder
from kit import box
from home import lathe, rounded_box, _fabric


def _export(path, name, M, fn):
    scene.reset()
    M = M()
    mb = MeshBuilder()
    fn(mb)
    o = mb.to_object(name, M, recalc_normals=True)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(path, [o])


def _stone():
    h = tex.fbm(256, 256, 8, 8, 91, 4)
    a = np.stack([0.66, 0.64, 0.6])[None, None, :] * (0.8 + 0.3 * h)[..., None]
    return scene.material("park_stone", tex.to_image("park_stone_albedo", np.clip(a, 0, 1)),
                          normal_tex=tex.to_image("park_stone_normal", tex.normal_from_height(h, 2.0), non_color=True), roughness=0.85)


def build(d):
    random.seed(77)

    def fountain(mb):
        # the basin: an outer wall with a moulded rim, an inner wall, the floor of the pool
        lathe(mb, [(2.45, 0.0), (2.62, 0.0), (2.62, 0.38), (2.68, 0.42), (2.68, 0.5), (2.35, 0.5), (2.35, 0.15), (0.0, 0.15)], 48, "stone", cap_start=False)
        # the pedestal: a stepped foot, a fluted column, a collar
        lathe(mb, [(0.0, 0.15), (0.45, 0.15), (0.45, 0.28), (0.36, 0.34), (0.3, 0.4)], 24, "stone", cap_start=False, cap_end=False)
        rings = []
        for z in (0.4, 1.0, 1.5):
            rings.append([Vector((math.cos(a) * (0.27 + 0.02 * math.cos(a * 12)), math.sin(a) * (0.27 + 0.02 * math.cos(a * 12)), z)) for a in (2 * math.pi * k / 48 for k in range(48))])
        mb.loft(rings, "stone", lambda ri, p: [], cap_start=False, cap_end=False)
        lathe(mb, [(0.27, 1.5), (0.34, 1.56), (0.28, 1.62), (0.4, 1.66)], 24, "stone", cap_start=False, cap_end=False)
        # the upper bowl: curving out to the rim, its water at 1.855
        lathe(mb, [(0.4, 1.66), (0.7, 1.7), (0.95, 1.78), (1.02, 1.87), (0.98, 1.88), (0.93, 1.83), (0.0, 1.83)], 32, "stone", cap_start=False)
        # the finial in the middle: a pine cone on a stem
        lathe(mb, [(0.0, 1.83), (0.08, 1.83), (0.06, 1.95), (0.1, 2.02), (0.12, 2.12), (0.09, 2.22), (0.04, 2.3), (0.0, 2.32)], 16, "stone")
        # four little lion masks... four spouts on the column
        for k in range(4):
            a = math.pi / 2 * k
            p = Vector((math.cos(a) * 0.29, math.sin(a) * 0.29, 0.95))
            mb.tube([p, p + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, -0.03))], [0.04, 0.02], 8, "bronze", [])
    _export(d + "/fountain.glb", "Fountain", lambda: {"stone": _stone(), "bronze": scene.material("ft_bronze", base_color=(0.35, 0.3, 0.18), roughness=0.4, metallic=0.9)}, fountain)

    def cart(mb):
        rounded_box(mb, Vector((0, 0, 0.7)), (2.8, 1.2, 0.9), 0.08, "white")
        box(mb, (-1.42, -0.62, 1.01), (1.42, 0.62, 1.15), "pink", 0.5)
        for k in range(3):     # freezer lids, stainless
            x = -0.85 + k * 0.6
            box(mb, (x - 0.27, -0.42, 1.15), (x + 0.27, 0.42, 1.19), "steel", 0.3)
            box(mb, (x - 0.06, -0.44, 1.19), (x + 0.06, -0.36, 1.21), "steel", 0.05)
        box(mb, (-1.4, -0.61, 0.32), (1.4, -0.6, 0.38), "pink", 0.3)       # a stripe
        for sy in (-1, 1):     # wheels: spoked, at one end
            c = Vector((-1.0, sy * 0.64, 0.22))
            pts = [c + Vector((math.cos(a) * 0.22, 0, math.sin(a) * 0.22)) for a in (2 * math.pi * k / 24 for k in range(25))]
            mb.tube(pts, [0.03] * 25, 6, "black", [])
            for k in range(8):
                a = 2 * math.pi * k / 8
                mb.tube([c, c + Vector((math.cos(a) * 0.2, 0, math.sin(a) * 0.2))], [0.008] * 2, 4, "steel", [])
        lathe(mb, [(0.06, 0.0), (0.04, 0.25)], 8, "black", center=Vector((1.2, -0.4, 0)))     # a stand at the other end
        lathe(mb, [(0.06, 0.0), (0.04, 0.25)], 8, "black", center=Vector((1.2, 0.4, 0)))
        mb.tube([Vector((1.4, -0.45, 0.95)), Vector((1.75, -0.45, 1.05)), Vector((1.75, 0.45, 1.05)), Vector((1.4, 0.45, 0.95))], [0.02] * 4, 8, "steel", [])  # handle
        # the umbrella: a pole and a striped canopy (alternating gores)
        mb.tube([Vector((1.1, 0.3, 1.15)), Vector((1.1, 0.3, 3.4))], [0.025] * 2, 8, "white", [])
        top = Vector((1.1, 0.3, 3.45))
        n = 12
        for k in range(n):
            a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
            p0 = top + Vector((math.cos(a0) * 1.4, math.sin(a0) * 1.4, -0.5))
            p1 = top + Vector((math.cos(a1) * 1.4, math.sin(a1) * 1.4, -0.5))
            ids = [mb.add_vert(top, []), mb.add_vert(p1, []), mb.add_vert(p0, [])]
            mat = "pink" if k % 2 == 0 else "white"
            mb.add_face(ids, [(0.5, 1), (1, 0), (0, 0)], mat, False)
            mb.add_face(ids[::-1], [(0, 0), (1, 0), (0.5, 1)], mat, False)
            # a scalloped valance
            v = [mb.add_vert(p0, []), mb.add_vert(p1, []), mb.add_vert((p0 + p1) * 0.5 + Vector((0, 0, -0.18)), [])]
            mb.add_face(v, [(0, 1), (1, 1), (0.5, 0)], mat, False)
            mb.add_face(v[::-1], [(0.5, 0), (1, 1), (0, 1)], mat, False)
    _export(d + "/ice_cream_cart.glb", "IceCreamCart", lambda: {
        "white": scene.material("cart_white", base_color=(0.97, 0.95, 0.9), roughness=0.4),
        "pink": scene.material("cart_pink", base_color=(0.95, 0.5, 0.6), roughness=0.5),
        "steel": scene.material("cart_steel", base_color=(0.75, 0.77, 0.8), roughness=0.25, metallic=0.9),
        "black": scene.material("cart_black", base_color=(0.05, 0.05, 0.05), roughness=0.6)}, cart)

    def shelter(mb):
        # posts at the back corners and the front; glass back (toward Godot +X) and sides; a curved roof
        for x in (-0.2, 1.4):
            for y in (-2.05, 2.05):
                box(mb, (x - 0.04, y - 0.04, 0.0), (x + 0.04, y + 0.04, 2.45), "frame", 0.3)
        box(mb, (1.37, -2.0, 0.15), (1.41, 2.0, 2.35), "glass", 0.5)
        for y in (-2.05, 2.05):
            box(mb, (-0.15, y - 0.02, 0.15), (1.35, y + 0.02, 2.35), "glass", 0.5)
        rings = []
        for k in range(9):
            t = k / 8
            x = -0.4 + t * 2.0
            z = 2.45 + 0.18 * math.sin(math.pi * t)
            rings.append([Vector((x, -2.15, z)), Vector((x, 2.15, z))])
        mb.loft(rings, "frame", lambda ri, p: [], closed=False)
        mb.loft([[Vector((p.x, p.y, p.z + 0.04)) for p in r] for r in rings][::-1], "frame", lambda ri, p: [], closed=False)
        box(mb, (0.8, -1.5, 0.43), (1.25, 1.5, 0.48), "bench", 0.4)        # bench
        for y in (-1.3, 1.3):
            box(mb, (1.0, y - 0.03, 0.0), (1.06, y + 0.03, 0.45), "frame", 0.1)
        box(mb, (1.3, -1.9, 0.9), (1.36, -1.2, 1.9), "panel", 0.3)         # the timetable, lit
        box(mb, (0.5, 1.95, 2.2), (1.2, 2.0, 2.45), "sign", 0.2)          # the stop's sign
    _export(d + "/bus_shelter.glb", "BusShelter", lambda: {
        "frame": scene.material("bs_frame", base_color=(0.2, 0.22, 0.25), roughness=0.35, metallic=0.8),
        "glass": scene.material("bs_glass", base_color=(0.6, 0.7, 0.75), roughness=0.05, alpha=0.3, double_sided=True),
        "bench": scene.material("bs_bench", base_color=(0.45, 0.47, 0.5), roughness=0.4, metallic=0.6),
        "panel": scene.material("bs_panel", base_color=(0.95, 0.95, 0.9), emission_color=(1.0, 0.98, 0.9), emission_strength=1.0, roughness=0.5),
        "sign": scene.material("bs_sign", base_color=(0.1, 0.35, 0.7), roughness=0.4)}, shelter)

    def hammock(mb):
        L, sag, W = 2.8, 0.55, 0.95
        rings = []
        for k in range(17):
            t = k / 16
            x = -L / 2 + t * L
            z = -sag * math.sin(math.pi * t)
            w = W * (0.15 + 0.85 * math.sin(math.pi * t) ** 0.5) * 0.5
            rings.append([Vector((x, -w, z + 0.12 * (1 - math.sin(math.pi * t)))), Vector((x, 0.0, z - 0.04 * math.sin(math.pi * t))), Vector((x, w, z + 0.12 * (1 - math.sin(math.pi * t))))])
        mb.loft(rings, "cloth", lambda ri, p: [], closed=False)
        for sx in (-1, 1):
            pts = [Vector((sx * (L / 2 + 0.25), 0, 0.15)) + Vector((0, math.cos(a) * 0.05, math.sin(a) * 0.05)) for a in (2 * math.pi * k / 12 for k in range(13))]
            mb.tube(pts, [0.008] * 13, 4, "rope", [])
            for k in range(5):
                mb.tube([Vector((sx * (L / 2 + 0.25), 0, 0.12)), Vector((sx * L / 2, -W * 0.08 + k * W * 0.04, 0.1))], [0.005] * 2, 4, "rope", [])
    _export(d + "/hammock.glb", "Hammock", lambda: {"cloth": scene.material("hm_cloth", base_color=(0.85, 0.45, 0.35), roughness=0.95, double_sided=True),
                                                   "rope": scene.material("hm_rope", base_color=(0.8, 0.75, 0.6), roughness=0.9)}, hammock)

    def post(mb):
        lathe(mb, [(0.07, 0.0), (0.065, 1.7), (0.05, 1.78), (0.0, 1.8)], 10, "wood")
        pts = [Vector((0.07 + 0.05 + math.cos(a) * 0.05, 0, 1.5 + math.sin(a) * 0.05)) for a in (2 * math.pi * k / 12 for k in range(13))]
        mb.tube(pts, [0.008] * 13, 5, "iron", [])
    _export(d + "/wood_post.glb", "WoodPost", lambda: {"wood": scene.material("post_wood", base_color=(0.35, 0.27, 0.18), roughness=0.9),
                                                      "iron": scene.material("post_iron", base_color=(0.15, 0.13, 0.12), roughness=0.6, metallic=0.7)}, post)

    def kite(mb):
        # in Blender's X-Z plane (Godot X-Y), facing -Y (Godot +Z)
        top, bot, l, r = Vector((0, 0, 0.55)), Vector((0, 0, -0.8)), Vector((-0.45, 0, 0.1)), Vector((0.45, 0, 0.1))
        for tri, mat in (((top, l, Vector((0, 0, 0.1))), "red"), ((top, Vector((0, 0, 0.1)), r), "yellow"), ((Vector((0, 0, 0.1)), l, bot), "yellow"), ((Vector((0, 0, 0.1)), bot, r), "red")):
            ids = [mb.add_vert(p, []) for p in tri]
            mb.add_face(ids, [(0, 0), (1, 0), (0.5, 1)], mat, False)
            mb.add_face(ids[::-1], [(0.5, 1), (1, 0), (0, 0)], mat, False)
        mb.tube([top, bot], [0.006] * 2, 4, "spar", [])
        mb.tube([l, r], [0.006] * 2, 4, "spar", [])
        for k in range(5):     # bows on the tail
            c = bot + Vector((0.05 * math.sin(k), 0, -0.25 - k * 0.22))
            for s in (-1, 1):
                ids = [mb.add_vert(c, []), mb.add_vert(c + Vector((s * 0.08, 0, 0.04)), []), mb.add_vert(c + Vector((s * 0.08, 0, -0.04)), [])]
                mb.add_face(ids, [(0, 0.5), (1, 1), (1, 0)], "red" if k % 2 else "yellow", False)
                mb.add_face(ids[::-1], [(1, 0), (1, 1), (0, 0.5)], "red" if k % 2 else "yellow", False)
        mb.tube([bot] + [bot + Vector((0.05 * math.sin(k), 0, -0.25 - k * 0.22)) for k in range(5)], [0.003] * 6, 4, "spar", [])
    _export(d + "/kite.glb", "Kite", lambda: {"red": scene.material("kite_red", base_color=(0.9, 0.2, 0.25), roughness=0.6, double_sided=True),
                                             "yellow": scene.material("kite_yellow", base_color=(0.98, 0.85, 0.3), roughness=0.6, double_sided=True),
                                             "spar": scene.material("kite_spar", base_color=(0.4, 0.3, 0.2), roughness=0.7)}, kite)
