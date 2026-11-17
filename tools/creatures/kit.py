"""Architecture kit and street props (models/props/*.glb).

facade_kit.glb holds named modules the game assembles into buildings of any size (one MultiMesh per
module type, so a whole city is a handful of draw calls):
  bay_brick, bay_plaster, bay_modern   one floor x one window bay, 3 m wide x 3.6 m tall, facing +Z
                                       (recessed glass, frame, sill, lintel)
  shop                                 ground-floor shopfront, 3 m x 4.2 m, with an awning
  cornice                              3 m crowning moulding
  bay_tower, bay_tower_lit             curtain-wall bay for skyscrapers (glass, mullions, spandrel);
                                       the lit version has warm office light behind the glass
Every module's wall surface uses a material named "*_wall*" so the game can tint it per building.

Props: bench, lamp_post, bin, hydrant, car (lofted body, glass, wheels).
"""
import math
import random

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder


# ------------------------------------------------------------------ textures

def _brick_tex():
    n = 512
    rows = 16
    y = np.arange(n) / n * rows
    row = np.floor(y).astype(int)
    x = (np.arange(n)[None, :] / n * 8 + (row[:, None] % 2) * 0.5) % 1.0 * 8
    bx = np.floor((np.arange(n)[None, :] / n * 8 + (row[:, None] % 2) * 0.5)).astype(int) % 8
    fx = (np.arange(n)[None, :] / n * 8 + (row[:, None] % 2) * 0.5) % 1.0
    fy = (y % 1.0)[:, None] * np.ones((1, n))
    mortar = ((fx < 0.04) | (fx > 0.96) | (fy < 0.07) | (fy > 0.93)).astype(float)
    rng = np.random.default_rng(5)
    tone = rng.random((rows, 8))[row[:, None] % rows, bx]
    grain = tex.fbm(n, n, 64, 64, 6, 2)
    big = tex.fbm(n, n, 4, 4, 7, 3)
    brick = np.stack([0.95, 0.9, 0.85])[None, None, :] * (0.82 + 0.25 * tone + 0.12 * grain - 0.1 * big)[..., None]
    mort = np.ones((n, n, 3)) * np.array([1.0, 0.98, 0.95]) * (1.1 + 0.1 * grain[..., None])
    alb = np.where(mortar[..., None] > 0.5, mort, brick)
    height = (1 - mortar) * 0.7 + 0.25 * grain
    _ = x
    return tex.to_image("brick_albedo", np.clip(alb, 0, 1)), tex.to_image("brick_normal", tex.normal_from_height(height, 4.0), non_color=True)


def _plaster_tex():
    n = 256
    g = tex.fbm(n, n, 16, 16, 8, 4)
    alb = np.ones((n, n, 3)) * (0.9 + 0.12 * g)[..., None]
    return tex.to_image("plaster_albedo", alb), tex.to_image("plaster_normal", tex.normal_from_height(g, 2.0), non_color=True)


# ------------------------------------------------------------------ geometry helpers

def box(mb, lo, hi, mat, uv_scale=1.0, faces="all"):
    """Axis-aligned box with world-scaled UVs (metres / uv_scale) on every face."""
    lo, hi = Vector(lo), Vector(hi)
    c = [Vector((x, y, z)) for z in (lo.z, hi.z) for y in (lo.y, hi.y) for x in (lo.x, hi.x)]
    quads = {
        "-z": (0, 2, 3, 1), "+z": (4, 5, 7, 6), "-y": (0, 1, 5, 4),
        "+y": (2, 6, 7, 3), "-x": (0, 4, 6, 2), "+x": (1, 3, 7, 5),
    }
    for name, q in quads.items():
        if faces != "all" and name not in faces:
            continue
        pts = [c[i] for i in q]
        nrm = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        ax = max(range(3), key=lambda i: abs(nrm[i]))
        uv_axes = [i for i in range(3) if i != ax]
        ids = [mb.add_vert(p, []) for p in pts]
        uvs = [(p[uv_axes[0]] / uv_scale, p[uv_axes[1]] / uv_scale) for p in pts]
        mb.add_face(ids, uvs, mat, False)


def window_bay(mb, wall, w=3.0, h=3.6, win_w=1.35, win_h=1.9, sill_z=0.95, depth=0.3, glass="glass", frame="frame"):
    """A wall panel (front face at y=0, facing -Y in Blender = +Z in Godot after export? see note)
    with a recessed window. Built facing Blender -Y; exported, that is Godot +Z."""
    x0, x1 = -w / 2, w / 2
    wx0, wx1 = -win_w / 2, win_w / 2
    z0, z1 = sill_z, sill_z + win_h
    # wall pieces around the opening (front face at y = 0, wall goes back to y = depth)
    box(mb, (x0, 0, 0), (wx0, depth, h), wall, 1.0, "-y")
    box(mb, (wx1, 0, 0), (x1, depth, h), wall, 1.0, "-y")
    box(mb, (wx0, 0, 0), (wx1, depth, z0), wall, 1.0, "-y")
    box(mb, (wx0, 0, z1), (wx1, depth, h), wall, 1.0, "-y")
    # reveal (the opening's inner faces)
    r = 0.16
    box(mb, (wx0, 0, z0), (wx1, r, z0 + 0.001), wall, 1.0, "+z")
    box(mb, (wx0, 0, z1 - 0.001), (wx1, r, z1), wall, 1.0, "-z")
    box(mb, (wx0, 0, z0), (wx0 + 0.001, r, z1), wall, 1.0, "+x")
    box(mb, (wx1 - 0.001, 0, z0), (wx1, r, z1), wall, 1.0, "-x")
    # glass and frame, set back in the reveal
    box(mb, (wx0, r, z0), (wx1, r + 0.02, z1), glass, 1.0, "-y")
    f = 0.06
    for lo, hi in (((wx0, r - 0.04, z0), (wx1, r, z0 + f)), ((wx0, r - 0.04, z1 - f), (wx1, r, z1)),
                   ((wx0, r - 0.04, z0), (wx0 + f, r, z1)), ((wx1 - f, r - 0.04, z0), (wx1, r, z1)),
                   ((-f / 2, r - 0.04, z0), (f / 2, r, z1)), ((wx0, r - 0.04, z0 + win_h * 0.62), (wx1, r, z0 + win_h * 0.62 + f))):
        box(mb, lo, hi, frame, 1.0)
    # stone sill and lintel
    box(mb, (wx0 - 0.08, -0.06, z0 - 0.07), (wx1 + 0.08, 0.05, z0), "stone", 1.0)
    box(mb, (wx0 - 0.05, -0.02, z1), (wx1 + 0.05, 0.02, z1 + 0.16), "stone", 1.0)
    # a little ledge at each floor line
    box(mb, (x0, -0.03, 0), (x1, 0.0, 0.12), "stone", 1.0)


def _facade_kit(out_dir):
    scene.reset()
    brick_a, brick_n = _brick_tex()
    plast_a, plast_n = _plaster_tex()
    M = {
        "brick_wall": scene.material("brick_wall", brick_a, normal_tex=brick_n, normal_strength=1.0, roughness=0.85),
        "plaster_wall": scene.material("plaster_wall", plast_a, normal_tex=plast_n, normal_strength=0.6, roughness=0.8),
        "modern_wall": scene.material("modern_wall", base_color=(0.75, 0.75, 0.74), roughness=0.6),
        "glass": scene.material("glass", base_color=(0.05, 0.07, 0.09), roughness=0.05, metallic=0.6),
        "glass_lit": scene.material("glass_lit", base_color=(0.1, 0.08, 0.05), emission_color=(1.0, 0.78, 0.45), emission_strength=1.6, roughness=0.1),
        "frame": scene.material("frame", base_color=(0.92, 0.92, 0.9), roughness=0.5),
        "frame_dark": scene.material("frame_dark", base_color=(0.12, 0.13, 0.14), roughness=0.4, metallic=0.6),
        "stone": scene.material("stone", plast_a, normal_tex=plast_n, roughness=0.75, base_color=(0.8, 0.78, 0.74)),
        "awning": scene.material("awning", base_color=(0.55, 0.12, 0.1), roughness=0.9),
        "spandrel": scene.material("spandrel_wall", base_color=(0.3, 0.32, 0.35), roughness=0.5, metallic=0.4),
    }
    objs = []

    def module(name, fn):
        mb = MeshBuilder()
        fn(mb)
        o = mb.to_object(name, M, recalc_normals=False)
        objs.append(o)

    module("bay_brick", lambda mb: window_bay(mb, "brick_wall"))
    module("bay_plaster", lambda mb: window_bay(mb, "plaster_wall", win_w=1.2, win_h=1.75))
    module("bay_modern", lambda mb: window_bay(mb, "modern_wall", win_w=2.4, win_h=2.1, sill_z=0.75, frame="frame_dark"))

    def shop(mb):
        w, h = 3.0, 4.2
        box(mb, (-w / 2, 0, 0), (-1.25, 0.3, h), "brick_wall", 1.0, "-y")
        box(mb, (1.25, 0, 0), (w / 2, 0.3, h), "brick_wall", 1.0, "-y")
        box(mb, (-1.25, 0, 3.2), (1.25, 0.3, h), "brick_wall", 1.0, "-y")
        box(mb, (-1.25, 0, 0), (1.25, 0.3, 0.45), "frame_dark", 1.0)
        box(mb, (-1.25, 0.08, 0.45), (1.25, 0.1, 3.2), "glass", 1.0, "-y")
        for x in (-1.25, 0.0, 1.21):
            box(mb, (x, 0.0, 0.45), (x + 0.05, 0.1, 3.2), "frame_dark", 1.0)
        # awning: sloped canvas
        a0 = Vector((-1.4, 0.0, 3.35))
        ids = [mb.add_vert(p, []) for p in (Vector((-1.4, 0.0, 3.35)), Vector((1.4, 0.0, 3.35)), Vector((1.4, -1.1, 2.85)), Vector((-1.4, -1.1, 2.85)))]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "awning", False)
        ids = [mb.add_vert(p, []) for p in (Vector((-1.4, -1.1, 2.85)), Vector((1.4, -1.1, 2.85)), Vector((1.4, -1.1, 2.6)), Vector((-1.4, -1.1, 2.6)))]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "awning", False)
        _ = a0
    module("shop", shop)

    def cornice(mb):
        box(mb, (-1.5, -0.1, 0), (1.5, 0.3, 0.25), "stone", 1.0)
        box(mb, (-1.5, -0.25, 0.25), (1.5, 0.3, 0.45), "stone", 1.0)
        box(mb, (-1.5, -0.12, 0.45), (1.5, 0.3, 0.95), "stone", 1.0)
        box(mb, (-1.5, -0.18, 0.95), (1.5, 0.3, 1.05), "stone", 1.0)
    module("cornice", cornice)

    def tower(mb, lit):
        w, h = 3.0, 3.6
        box(mb, (-w / 2, 0, 0), (w / 2, 0.3, 0.9), "spandrel", 1.0, "-y")
        box(mb, (-w / 2, 0, 3.3), (w / 2, 0.3, h), "spandrel", 1.0, "-y")
        box(mb, (-w / 2, 0.06, 0.9), (w / 2, 0.08, 3.3), "glass_lit" if lit else "glass", 1.0, "-y")
        for x in (-w / 2, 0.0):
            box(mb, (x, -0.05, 0), (x + 0.08, 0.06, h), "frame_dark", 1.0)
    module("bay_tower", lambda mb: tower(mb, False))
    module("bay_tower_lit", lambda mb: tower(mb, True))

    for i, o in enumerate(objs):
        o.location.x = i * 4.0   # side by side in the file; the game reads each mesh's own geometry
    print(f"  facade kit: {len(objs)} modules")
    scene.export_glb(f"{out_dir}/facade_kit.glb", objs)


# ------------------------------------------------------------------ props

def _prop(name, out_dir, fn, materials):
    scene.reset()
    materials = materials()
    mb = MeshBuilder()
    fn(mb)
    o = mb.to_object(name, materials, recalc_normals=False)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{out_dir}/{name}.glb", [o])


def _props(out_dir):
    def mats():
        wood_a = tex.to_image("slat_albedo", np.stack([0.55, 0.36, 0.2])[None, None, :] * (0.8 + 0.3 * tex.fbm(128, 128, 2, 24, 3, 3))[..., None])
        return {
            "iron": scene.material("cast_iron", base_color=(0.05, 0.055, 0.06), roughness=0.45, metallic=0.8),
            "slats": scene.material("slats", wood_a, roughness=0.7),
            "green": scene.material("paint_green", base_color=(0.08, 0.2, 0.13), roughness=0.4, metallic=0.5),
            "red": scene.material("paint_red", base_color=(0.6, 0.06, 0.04), roughness=0.35, metallic=0.3),
            "glass": scene.material("lamp_glass", base_color=(0.9, 0.85, 0.7), emission_color=(1.0, 0.85, 0.6), emission_strength=0.3, roughness=0.2),
        }

    def bench(mb):
        for x in (-0.8, 0.8):
            pts = [Vector((x, 0.22, 0)), Vector((x, 0.2, 0.45)), Vector((x, -0.2, 0.45)), Vector((x, -0.25, 0)), Vector((x, -0.22, 0.9))]
            mb.tube(pts[:4], [0.025] * 4, 5, "iron", [])
            mb.tube([Vector((x, -0.2, 0.45)), Vector((x, -0.25, 0.92))], [0.022] * 2, 5, "iron", [])
        for k in range(4):
            y = 0.17 - k * 0.11
            box(mb, (-0.95, y - 0.045, 0.43), (0.95, y + 0.045, 0.47), "slats", 0.5)
        for k in range(3):
            z = 0.58 + k * 0.12
            box(mb, (-0.95, -0.27, z), (0.95, -0.23, z + 0.08), "slats", 0.5)
    _prop("bench", out_dir, bench, mats)

    def lamp(mb):
        mb.tube([Vector((0, 0, 0)), Vector((0, 0, 0.5))], [0.13, 0.1], 10, "iron", [], cap_start=True)
        mb.tube([Vector((0, 0, 0.5)), Vector((0, 0, 3.6))], [0.075, 0.055], 10, "iron", [], ridges=0.08, ridge_freq=25.0)
        mb.tube([Vector((0, 0, 3.6)), Vector((0, 0, 3.75)), Vector((0, 0.02, 3.8))], [0.07, 0.09, 0.06], 10, "iron", [])
        # lantern: tapered glass with a cap
        mb.tube([Vector((0, 0, 3.8)), Vector((0, 0, 4.25))], [0.12, 0.2], 6, "glass", [], cap_start=True)
        mb.tube([Vector((0, 0, 4.25)), Vector((0, 0, 4.42)), Vector((0, 0, 4.52))], [0.24, 0.12, 0.02], 6, "iron", [])
    _prop("lamp_post", out_dir, lamp, mats)

    def bin_(mb):
        mb.tube([Vector((0, 0, 0)), Vector((0, 0, 0.9))], [0.25, 0.27], 16, "green", [], cap_start=True, cap_end=False)
        mb.tube([Vector((0, 0, 0.9)), Vector((0, 0, 0.98))], [0.29, 0.29], 16, "iron", [])
        mb.tube([Vector((0, 0, 0.98)), Vector((0, 0, 1.06))], [0.27, 0.05], 16, "green", [])
    _prop("bin", out_dir, bin_, mats)

    def hydrant(mb):
        mb.tube([Vector((0, 0, 0)), Vector((0, 0, 0.08))], [0.16, 0.14], 12, "red", [], cap_start=True)
        mb.tube([Vector((0, 0, 0.08)), Vector((0, 0, 0.6))], [0.11, 0.1], 12, "red", [])
        mb.tube([Vector((0, 0, 0.6)), Vector((0, 0, 0.72)), Vector((0, 0, 0.8))], [0.12, 0.1, 0.03], 12, "red", [])
        for d in (Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, -1, 0))):
            mb.tube([Vector((0, 0, 0.45)), Vector((0, 0, 0.45)) + d * 0.17], [0.045, 0.05], 8, "red", [])
    _prop("hydrant", out_dir, hydrant, mats)


def _car(out_dir, name, color):
    scene.reset()
    mb = MeshBuilder()
    # body: lofted cross-sections along the length (X), lower body + cabin
    sections = []   # (x, half_width, z_bottom, z_shoulder, z_top, top_half_width)
    for x, hw, zb, zs, zt, thw in ((-2.15, 0.8, 0.32, 0.72, 0.8, 0.7), (-1.9, 0.88, 0.25, 0.85, 0.92, 0.8),
                                    (-1.0, 0.9, 0.24, 0.9, 1.0, 0.8), (-0.6, 0.9, 0.24, 0.9, 1.42, 0.72),
                                    (0.6, 0.9, 0.24, 0.9, 1.44, 0.72), (1.0, 0.9, 0.24, 0.9, 1.0, 0.8),
                                    (1.95, 0.88, 0.26, 0.8, 0.86, 0.8), (2.2, 0.8, 0.34, 0.66, 0.72, 0.7)):
        ring = [Vector((x, -hw, zb)), Vector((x, hw, zb)), Vector((x, hw, zs)), Vector((x, thw, zt)),
                Vector((x, -thw, zt)), Vector((x, -hw, zs))]
        sections.append(ring)
    mb.loft([[p for p in r] for r in sections], "paint", lambda ri, p: [], cap_start=True, cap_end=True, smooth=False)
    # glass band on the cabin
    for side in (-1, 1):
        pts = [Vector((-0.55, 0.81 * side, 0.95)), Vector((0.55, 0.81 * side, 0.95)), Vector((0.5, 0.73 * side, 1.38)), Vector((-0.5, 0.73 * side, 1.36))]
        if side < 0:
            pts = pts[::-1]
        ids = [mb.add_vert(p, []) for p in pts]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "glass", False)
    for x0, x1 in ((0.62, 0.98), (-0.98, -0.62)):
        zt = 1.4
        pts = [Vector((x1, -0.78, 0.98)), Vector((x1, 0.78, 0.98)), Vector((x0, 0.7, zt)), Vector((x0, -0.7, zt))]
        if x0 < 0:
            pts = [Vector((x0, -0.78, 0.98)), Vector((x1, -0.7, zt)), Vector((x1, 0.7, zt)), Vector((x0, 0.78, 0.98))]
        ids = [mb.add_vert(p, []) for p in pts]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "glass", False)
    # wheels
    for x in (-1.35, 1.35):
        for side in (-1, 1):
            c = Vector((x, 0.82 * side, 0.32))
            mb.tube([c - Vector((0, 0.11, 0)), c + Vector((0, 0.11, 0))], [0.32, 0.32], 16, "tyre", [], cap_start=True)
            mb.tube([c + Vector((0, 0.112 * side, 0)), c + Vector((0, 0.115 * side, 0))], [0.2, 0.2], 10, "rim", [], cap_start=True)
    # lights
    for side in (-1, 1):
        box(mb, (2.16, 0.55 * side - 0.15, 0.6), (2.22, 0.55 * side + 0.15, 0.7), "light")
        box(mb, (-2.2, 0.6 * side - 0.12, 0.6), (-2.14, 0.6 * side + 0.12, 0.7), "rear")
    M = {
        "paint": scene.material(name + "_paint", base_color=color, roughness=0.25, metallic=0.5),
        "glass": scene.material(name + "_glass", base_color=(0.03, 0.04, 0.05), roughness=0.05, metallic=0.7),
        "tyre": scene.material(name + "_tyre", base_color=(0.02, 0.02, 0.02), roughness=0.9),
        "rim": scene.material(name + "_rim", base_color=(0.6, 0.6, 0.62), roughness=0.3, metallic=0.9),
        "light": scene.material(name + "_light", base_color=(0.9, 0.9, 0.85), roughness=0.1),
        "rear": scene.material(name + "_rear", base_color=(0.5, 0.02, 0.02), roughness=0.2),
    }
    o = mb.to_object(name, M, recalc_normals=False)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{out_dir}/{name}.glb", [o])


def build(out_dir):
    random.seed(3)
    _facade_kit(out_dir)
    _props(out_dir)
    for i, c in enumerate([(0.55, 0.06, 0.05), (0.12, 0.2, 0.38), (0.75, 0.74, 0.7), (0.08, 0.08, 0.09), (0.35, 0.38, 0.3)]):
        _car(out_dir, f"car_{i}", c)
