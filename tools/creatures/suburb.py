"""BLACKOUT's street (models/props/*.glb): suburban houses, garden fences, an arched picket gate, utility poles,
mailboxes, manhole covers.

  house_a, house_b   12 x 10 m footprint, 5.2 m to the eaves, a gabled shingle roof; clapboard siding (the
                     material is "*_wall*", so the game tints it per house), framed windows with sills and
                     shutters (the glass is its own mesh, "Windows", so the game can light it), a panelled front
                     door, a porch (a) or a bay and a chimney (b). Front faces +X (Godot): the game turns it.
  fence_panel        2.4 m of slatted garden fence between two posts, 1.6 m tall (scattered along fence lines)
  gate_arch          a 2.8 m picket gate with an arched top, hung from its left edge (origin = hinge)
  utility_pole       a creosoted pole, crossarm, insulators, a transformer; wires go from "attach" heights
  mailbox, manhole
Blender: +Z up, +Y = Godot -Z; Godot +X = Blender +X.
"""
import math

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder
from kit import box
from home import lathe


def _export(name, out_dir, objs):
    print(f"  {name}: {sum(mb.tri_count() for mb, _ in objs)} triangles")
    scene.export_glb(f"{out_dir}/{name}.glb", [o for _, o in objs])


def _siding_tex():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    boards = (yy * 12.0) % 1.0
    shade = 0.82 + 0.18 * boards - 0.25 * (boards < 0.06)
    grain = tex.fbm(n, n, 4, 30, 51, 3)
    a = np.ones((n, n, 3)) * (shade * (0.92 + 0.08 * grain))[..., None]
    h = boards * 0.8 + 0.2 * grain
    return (tex.to_image("siding_albedo", np.clip(a, 0, 1)), tex.to_image("siding_normal", tex.normal_from_height(h, 2.5), non_color=True))


def _shingle_tex():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    row = np.floor(yy * 10.0)
    off = (row % 2) * 0.5
    tab = ((xx * 6.0 + off) % 1.0)
    edge = ((yy * 10.0) % 1.0)
    noise = tex.fbm(n, n, 20, 20, 52, 3)
    v = 0.55 + 0.25 * noise - 0.3 * (edge < 0.08) - 0.15 * (tab < 0.04)
    a = np.ones((n, n, 3)) * np.array([0.22, 0.2, 0.2]) * v[..., None] * 1.4
    return (tex.to_image("shingle_albedo", np.clip(a, 0, 1)), tex.to_image("shingle_normal", tex.normal_from_height(edge + 0.3 * noise, 3.0), non_color=True))


def _mats(prefix=""):
    sa, sn = _siding_tex()
    ra, rn = _shingle_tex()
    return {
        "wall": scene.material(prefix + "house_wall", sa, normal_tex=sn, roughness=0.75),
        "roof": scene.material(prefix + "house_roof", ra, normal_tex=rn, roughness=0.9),
        "trim": scene.material(prefix + "house_trim", base_color=(0.92, 0.91, 0.88), roughness=0.5),
        "door": scene.material(prefix + "house_door", base_color=(0.28, 0.12, 0.08), roughness=0.4),
        "shutter": scene.material(prefix + "house_shutter", base_color=(0.12, 0.17, 0.15), roughness=0.5),
        "glass": scene.material(prefix + "house_glass", base_color=(0.02, 0.025, 0.03), roughness=0.05, metallic=0.6),
        "brick": scene.material(prefix + "house_brick", base_color=(0.42, 0.18, 0.13), roughness=0.9),
        "stone": scene.material(prefix + "house_stone", base_color=(0.5, 0.49, 0.46), roughness=0.9),
        "metal": scene.material(prefix + "house_metal", base_color=(0.5, 0.5, 0.52), roughness=0.4, metallic=0.8),
    }


def _gable_roof(mb, w, d, eave_z, pitch, over=0.45):
    """A roof ridged along Blender Y (the house's depth), sloping down to the left and right (Godot +-X)...
    no: ridge along X (the width), slopes front/back would put the gable at the sides. Ridge along Y here."""
    rise = (w * 0.5 + over) * math.tan(math.radians(pitch))
    x0, x1 = -w * 0.5 - over, w * 0.5 + over
    y0, y1 = -d * 0.5 - over, d * 0.5 + over
    zr = eave_z + rise
    t = 0.12
    for side in (-1, 1):
        xe = x0 if side < 0 else x1
        pts = [Vector((xe, y0, eave_z)), Vector((xe, y1, eave_z)), Vector((0, y1, zr)), Vector((0, y0, zr))]
        if side > 0:
            pts = pts[::-1]
        ids = [mb.add_vert(p, []) for p in pts]
        mb.add_face(ids, [(0, 0), (d / 2.0, 0), (d / 2.0, (w * 0.5 + over) / 2.0), (0, (w * 0.5 + over) / 2.0)], "roof", False)
        # fascia boards along the eave
        box(mb, (xe - (t if side < 0 else 0), y0, eave_z - 0.25), (xe + (t if side > 0 else 0), y1, eave_z), "trim", 0.5)
    # the gable ends: triangles of siding
    for y in (-d * 0.5, d * 0.5):
        pts = [Vector((-w * 0.5, y, eave_z)), Vector((w * 0.5, y, eave_z)), Vector((0, y, zr - 0.1))]
        if y > 0:
            pts = pts[::-1]
        ids = [mb.add_vert(p, []) for p in pts]
        mb.add_face(ids, [(0, 0), (w / 3.0, 0), (w / 6.0, rise / 3.0)], "wall", False)
    return zr


def _window(mb, gm, face_x, y, z, w=1.2, h=1.4, shutters=True):
    """A window on the wall plane x = face_x (facing +X): frame, a cross of glazing bars, sill, shutters."""
    fx = face_x
    box(mb, (fx, y - w / 2 - 0.08, z - h / 2 - 0.08), (fx + 0.06, y + w / 2 + 0.08, z + h / 2 + 0.08), "trim", 0.5)   # frame
    box(mb, (fx, y - w / 2 - 0.12, z - h / 2 - 0.14), (fx + 0.14, y + w / 2 + 0.12, z - h / 2 - 0.06), "trim", 0.5)  # sill
    box(mb, (fx + 0.04, y - 0.025, z - h / 2), (fx + 0.07, y + 0.025, z + h / 2), "trim", 0.5)                        # bars
    box(mb, (fx + 0.04, y - w / 2, z - 0.025), (fx + 0.07, y + w / 2, z + 0.025), "trim", 0.5)
    box(gm, (fx + 0.02, y - w / 2, z - h / 2), (fx + 0.03, y + w / 2, z + h / 2), "glass", 0.5)
    if shutters:
        for s in (-1, 1):
            y0 = y + s * (w / 2 + 0.12)
            box(mb, (fx, min(y0, y0 + s * 0.45), z - h / 2 - 0.05), (fx + 0.04, max(y0, y0 + s * 0.45), z + h / 2 + 0.05), "shutter", 0.5)
            for k in range(8):
                zz = z - h / 2 + 0.05 + k * (h / 8)
                box(mb, (fx + 0.04, min(y0, y0 + s * 0.45) + 0.04, zz), (fx + 0.055, max(y0, y0 + s * 0.45) - 0.04, zz + 0.04), "shutter", 0.2)


def _house(out_dir, name, kind):
    scene.reset()
    M = _mats(name + "_")
    mb = MeshBuilder()
    gm = MeshBuilder()
    W, D, E = 10.0, 12.0, 5.2       # Blender X = Godot X (the front faces +X); Blender Y = depth along the street
    box(mb, (-W / 2, -D / 2, 0), (W / 2, D / 2, E), "wall", 2.0)
    box(mb, (-W / 2 - 0.05, -D / 2 - 0.05, 0), (W / 2 + 0.05, D / 2 + 0.05, 0.45), "stone", 1.0)   # foundation
    for z in (2.6,):   # a band between the floors
        box(mb, (W / 2, -D / 2, z - 0.05), (W / 2 + 0.05, D / 2, z + 0.05), "trim", 0.5)
    for y in (-D / 2, D / 2):    # corner boards
        for x in (-W / 2, W / 2):
            box(mb, (x - 0.08, y - 0.08, 0.45), (x + 0.08, y + 0.08, E), "trim", 0.5)
    zr = _gable_roof(mb, W, D, E, 32 if kind == "a" else 38)
    # gutters and a downpipe
    for xs in (-1, 1):
        mb.tube([Vector((xs * (W / 2 + 0.5), -D / 2 - 0.45, E - 0.15)), Vector((xs * (W / 2 + 0.5), D / 2 + 0.45, E - 0.15))], [0.07, 0.07], 8, "metal", [])
    mb.tube([Vector((W / 2 + 0.5, D / 2 + 0.3, E - 0.15)), Vector((W / 2 + 0.1, D / 2 + 0.1, E - 0.5)), Vector((W / 2 + 0.1, D / 2 + 0.1, 0.1))], [0.05, 0.05, 0.05], 8, "metal", [])
    # the front (x = +W/2): door in the middle, windows either side, up and down
    fx = W / 2
    box(mb, (fx, -0.62, 0.45), (fx + 0.08, 0.62, 2.75), "trim", 0.5)            # door surround
    box(mb, (fx + 0.04, -0.48, 0.45), (fx + 0.09, 0.48, 2.6), "door", 0.5)      # the door
    for zz in (0.75, 1.75):
        for yy in (-0.22, 0.22):
            box(mb, (fx + 0.09, yy - 0.16, zz), (fx + 0.11, yy + 0.16, zz + 0.65), "door", 0.3)   # raised panels
    mb.tube([Vector((fx + 0.12, 0.34, 1.5)), Vector((fx + 0.18, 0.34, 1.5))], [0.025, 0.025], 6, "metal", [], cap_start=True)
    box(mb, (fx + 0.04, -0.4, 2.3), (fx + 0.1, 0.4, 2.55), "glass", 0.3)        # transom
    for y in (-3.4, 3.4):
        _window(mb, gm, fx, y, 1.7)
        _window(mb, gm, fx, y, 4.0)
    _window(mb, gm, fx, 0.0, 4.0, 0.9, 1.1, shutters=False)
    # the sides and back: windows too (the street sees the sides)
    for y in (-D / 2, D / 2):
        side = 1 if y > 0 else -1
        for x in (-2.5, 2.5):
            for z in (1.7, 4.0):
                # (a window on a side wall: built facing +X, then rotated - simpler to build in place)
                w, h = 1.0, 1.3
                box(mb, (x - w / 2 - 0.08, y - 0.06 * (1 - side) * 0.5 - 0.0, z - h / 2 - 0.08), (x + w / 2 + 0.08, y + 0.06 * (1 + side) * 0.5, z + h / 2 + 0.08), "trim", 0.5)
                box(gm, (x - w / 2, y + side * 0.02 - 0.005, z - h / 2), (x + w / 2, y + side * 0.02 + 0.005, z + h / 2), "glass", 0.5)
    if kind == "a":
        # a porch: a deck, two steps, four columns, a little hipped roof
        box(mb, (fx, -2.2, 0.0), (fx + 2.2, 2.2, 0.5), "trim", 1.0)
        for k in range(2):
            box(mb, (fx + 2.2 + k * 0.3, -1.0, 0.0), (fx + 2.5 + k * 0.3, 1.0, 0.33 - k * 0.16), "stone", 1.0)
        for y in (-2.0, -0.8, 0.8, 2.0):
            lathe(mb, [(0.11, 0.5), (0.09, 0.6), (0.085, 2.75), (0.11, 2.85)], 12, "trim", center=Vector((fx + 2.0, y, 0)))
        box(mb, (fx, -2.4, 2.85), (fx + 2.4, 2.4, 3.0), "trim", 0.5)
        pts = [Vector((fx + 2.5, -2.5, 3.0)), Vector((fx + 2.5, 2.5, 3.0)), Vector((fx, 2.5, 3.6)), Vector((fx, -2.5, 3.6))]
        mb.add_face([mb.add_vert(p, []) for p in pts], [(0, 0), (2.5, 0), (2.5, 1), (0, 1)], "roof", False)
        for y in (-2.0, 2.0):     # a rail between the outer columns
            box(mb, (fx + 1.95, min(y, y * 0.4), 1.15), (fx + 2.05, max(y, y * 0.4), 1.22), "trim", 0.5)
    else:
        # a bay window on the front, and a brick chimney on the side
        box(mb, (fx, 2.2, 0.45), (fx + 0.8, 4.6, 2.6), "wall", 2.0)
        _window(mb, gm, fx + 0.8, 3.4, 1.6, 1.8, 1.3, shutters=False)
        box(mb, (fx - 0.1, 2.1, 2.6), (fx + 0.95, 4.7, 2.75), "roof", 0.5)
        box(mb, (-1.4, D / 2 - 0.2, 0.0), (0.2, D / 2 + 0.6, zr + 1.2), "brick", 0.6)
        box(mb, (-1.5, D / 2 - 0.3, zr + 1.2), (0.3, D / 2 + 0.7, zr + 1.35), "brick", 0.6)
    body = mb.to_object("House", M, recalc_normals=True)
    glass = gm.to_object("Windows", M, recalc_normals=True)
    _export(name, out_dir, [(mb, body), (gm, glass)])


def _fence(out_dir):
    scene.reset()
    wa = tex.fbm(128, 128, 2, 30, 61, 3)
    wood = scene.material("fence_wood", tex.to_image("fence_albedo", np.clip(np.stack([0.36, 0.28, 0.2])[None, None, :] * (0.7 + 0.5 * wa)[..., None], 0, 1)),
                          normal_tex=tex.to_image("fence_normal", tex.normal_from_height(wa, 1.5), non_color=True), roughness=0.85)
    M = {"wood": wood}
    mb = MeshBuilder()
    L, H = 2.4, 1.6
    for x in (-L / 2, L / 2):
        box(mb, (x - 0.05, -0.05, 0.0), (x + 0.05, 0.05, H + 0.1), "wood", 0.5)
        lathe(mb, [(0.06, H + 0.1), (0.0, H + 0.2)], 4, "wood", center=Vector((x, 0, 0)), cap_start=False)
    for z in (0.3, 1.3):
        box(mb, (-L / 2, 0.05, z), (L / 2, 0.11, z + 0.09), "wood", 0.5)
    n = 16
    for k in range(n):
        x = -L / 2 + (k + 0.5) * L / n
        box(mb, (x - 0.06, 0.11, 0.05), (x + 0.06, 0.13, H - 0.02 - (k % 2) * 0.03), "wood", 0.5)
    _export("fence_panel", out_dir, [(mb, mb.to_object("FencePanel", M, recalc_normals=True))])

    # the gate: arched picket, white, hung at its left edge
    scene.reset()
    M = {"paint": scene.material("gate_paint", base_color=(0.9, 0.9, 0.86), roughness=0.55),
         "iron": scene.material("gate_iron", base_color=(0.08, 0.08, 0.08), roughness=0.5, metallic=0.7)}
    gm = MeshBuilder()
    W = 2.8
    for x in (0.04, W - 0.04):
        box(gm, (x - 0.04, -0.03, 0.05), (x + 0.04, 0.03, 1.55), "paint", 0.3)
    for z in (0.25, 1.05):
        box(gm, (0.0, -0.035, z), (W, 0.035, z + 0.08), "paint", 0.3)
    gm.tube([Vector((0.05, 0.0, 0.3)), Vector((W - 0.05, 0.0, 1.08))], [0.025, 0.025], 6, "paint", [])   # the brace
    n = 15
    for k in range(n):
        x = 0.12 + k * (W - 0.24) / (n - 1)
        top = 1.35 + 0.45 * math.sin(math.pi * (x / W))           # the arch
        box(gm, (x - 0.04, 0.035, 0.08), (x + 0.04, 0.06, top), "paint", 0.3)
        pts = [Vector((x - 0.04, 0.06, top)), Vector((x + 0.04, 0.06, top)), Vector((x, 0.06, top + 0.09))]
        gm.add_face([gm.add_vert(p, []) for p in pts[::-1]], [(0, 0), (1, 0), (0.5, 1)], "paint", False)
    for z in (0.4, 1.2):    # hinges, and the latch
        box(gm, (-0.02, -0.04, z), (0.25, 0.04, z + 0.05), "iron", 0.2)
    box(gm, (W - 0.2, -0.05, 0.95), (W - 0.02, 0.05, 1.0), "iron", 0.2)
    _export("gate_arch", out_dir, [(gm, gm.to_object("Gate", M, recalc_normals=True))])


def _street(out_dir):
    scene.reset()
    M = {"pole": scene.material("pole_wood", base_color=(0.2, 0.15, 0.1), roughness=0.85),
         "porcelain": scene.material("pole_insulator", base_color=(0.45, 0.55, 0.55), roughness=0.2),
         "can": scene.material("pole_can", base_color=(0.42, 0.44, 0.45), roughness=0.5, metallic=0.6),
         "steel": scene.material("pole_steel", base_color=(0.3, 0.3, 0.32), roughness=0.5, metallic=0.7)}
    mb = MeshBuilder()
    lathe(mb, [(0.15, 0.0), (0.13, 4.0), (0.11, 8.2), (0.0, 8.3)], 10, "pole")
    box(mb, (-0.06, -1.1, 7.6), (0.06, 1.1, 7.75), "pole", 0.3)        # crossarm (along Blender Y = the street)
    for y in (-1.0, -0.35, 0.35, 1.0):
        lathe(mb, [(0.02, 7.75), (0.05, 7.8), (0.035, 7.86), (0.05, 7.9), (0.03, 7.98), (0.0, 7.99)], 8, "porcelain", center=Vector((0, y, 0)))
    lathe(mb, [(0.0, 6.0), (0.28, 6.0), (0.3, 6.1), (0.3, 6.9), (0.26, 7.0), (0.0, 7.0)], 14, "can", center=Vector((0.4, 0, 0)))   # transformer
    box(mb, (0.1, -0.08, 6.4), (0.14, 0.08, 6.6), "steel", 0.2)
    for k in range(10):                                                  # climbing steps
        z = 2.2 + k * 0.45
        s = 1 if k % 2 else -1
        mb.tube([Vector((0, 0, z)), Vector((0.25 * s, 0, z))], [0.012, 0.012], 5, "steel", [])
    _export("utility_pole", out_dir, [(mb, mb.to_object("UtilityPole", M, recalc_normals=True))])

    scene.reset()
    M = {"box": scene.material("mailbox_paint", base_color=(0.1, 0.2, 0.35), roughness=0.4, metallic=0.4),
         "post": scene.material("mailbox_post", base_color=(0.25, 0.2, 0.15), roughness=0.8),
         "flag": scene.material("mailbox_flag", base_color=(0.7, 0.08, 0.05), roughness=0.4)}
    mb = MeshBuilder()
    box(mb, (-0.05, -0.05, 0.0), (0.05, 0.05, 1.0), "post", 0.3)
    rings = []
    for y in (-0.25, 0.25):
        ring = []
        for k in range(12):
            a = math.pi * k / 11
            ring.append(Vector((math.cos(a) * 0.12, y, 1.0 + math.sin(a) * 0.12 + 0.05)))
        ring.append(Vector((-0.12, y, 1.0)))
        ring.append(Vector((0.12, y, 1.0)))
        rings.append(ring)
    mb.loft(rings, "box", lambda ri, p: [], cap_start=True, cap_end=True)
    box(mb, (0.12, 0.0, 1.05), (0.14, 0.03, 1.3), "flag", 0.2)
    _export("mailbox", out_dir, [(mb, mb.to_object("Mailbox", M, recalc_normals=True))])

    scene.reset()
    M = {"iron": scene.material("manhole_iron", base_color=(0.12, 0.12, 0.12), roughness=0.6, metallic=0.7)}
    mb = MeshBuilder()
    lathe(mb, [(0.0, 0.0), (0.38, 0.0), (0.4, 0.015), (0.0, 0.015)], 24, "iron")
    for k in range(6):
        y = -0.3 + k * 0.12
        box(mb, (-0.3, y - 0.015, 0.015), (0.3, y + 0.015, 0.025), "iron", 0.2)
    _export("manhole", out_dir, [(mb, mb.to_object("Manhole", M, recalc_normals=True))])


def build(out_dir):
    _house(out_dir, "house_a", "a")
    _house(out_dir, "house_b", "b")
    _fence(out_dir)
    _street(out_dir)
