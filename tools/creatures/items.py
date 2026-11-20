"""Things you hold, use or open (models/objects/*.glb and models/props/*.glb).

objects/ (what you can picture into your hand; the game fits them to their size):
  flashlight     a ribbed aluminium torch, rubber grip, glass lens (points along Godot -Z = Blender +Y)
  ice_cream      a waffle cone, two scoops and a drip  (meshes "Scoop*" are the bites)
  balloon        a latex balloon, its knot and a ribbon
  beach_ball     six coloured panels and a white cap
props/:
  door_panel     a door frame ("Frame") and a panelled leaf ("Leaf", hinged at x = 0, 0.92 x 2.05 m, faces +Z):
                 recessed panels, lever handles both sides, a kick plate. "*paint*" materials take the door's colour.
  key            an old brass key on a ring with a paper tag
  fuse           a glass cartridge fuse with brass caps
  valve_wheel    a cast handwheel, 0.6 m, spokes and a hub (faces Godot +Z)
  breaker        a breaker box with a big lever
  notebook       a cloth-bound notebook with an elastic band
  pc_set         a monitor, keyboard and mouse
  payphone       a payphone on its post: the box, the handset on its hook, the cord, a hood
  pigeon         a pigeon
"""
import math

import numpy as np
from mathutils import Vector

from dp import scene, tex
from dp.geo import MeshBuilder
from kit import box
from home import lathe, rounded_box


def _out(path, objs):
    print(f"  {path.split('/')[-1]}: {sum(mb.tri_count() for mb, _ in objs)} triangles")
    scene.export_glb(path, [o for _, o in objs])


def _one(path, name, M, fn, recalc=True):
    scene.reset()
    M = M()
    mb = MeshBuilder()
    fn(mb)
    _out(path, [(mb, mb.to_object(name, M, recalc_normals=recalc))])


# ------------------------------------------------------------------ in your hand

def _objects(d):
    def torch(mb):
        # along +Y: tail cap, grip, body, head, lens
        prof = [(0.0, -0.1), (0.016, -0.1), (0.018, -0.095), (0.018, 0.02), (0.02, 0.03), (0.03, 0.06), (0.032, 0.09), (0.0, 0.09)]
        rings = []
        for r, y in prof:
            rings.append([Vector((math.cos(a) * r, y, math.sin(a) * r)) for a in (2 * math.pi * k / 20 for k in range(20))])
        mb.loft(rings, "alu", lambda ri, p: [], cap_start=True, cap_end=False)
        for k in range(10):            # rubber grip rings
            y = -0.08 + k * 0.009
            rings = [[Vector((math.cos(a) * r, y + dy, math.sin(a) * r)) for a in (2 * math.pi * j / 20 for j in range(20))] for r, dy in ((0.0185, 0), (0.0195, 0.003), (0.0185, 0.006))]
            mb.loft(rings, "rubber", lambda ri, p: [], cap_start=False, cap_end=False)
        rings = [[Vector((math.cos(a) * r, 0.0905, math.sin(a) * r)) for a in (2 * math.pi * j / 20 for j in range(20))] for r in (0.03, 0.0)]
        mb.loft(rings, "lens", lambda ri, p: [], cap_start=False, cap_end=False)
        box(mb, (-0.004, -0.0, 0.017), (0.004, 0.012, 0.022), "rubber", 0.05)     # the switch
    _one(d + "/flashlight.glb", "Flashlight", lambda: {
        "alu": scene.material("torch_alu", base_color=(0.16, 0.17, 0.19), roughness=0.35, metallic=0.9),
        "rubber": scene.material("torch_rubber", base_color=(0.03, 0.03, 0.03), roughness=0.9),
        "lens": scene.material("torch_lens", base_color=(1.0, 0.97, 0.85), emission_color=(1.0, 0.95, 0.8), emission_strength=4.0, roughness=0.1)}, torch)

    scene.reset()
    wa = tex.fbm(128, 128, 16, 16, 71, 2)
    yy, xx = np.mgrid[0:128, 0:128] / 128.0
    grid = ((np.abs(((xx + yy) * 8) % 1.0 - 0.5) < 0.08) | (np.abs(((xx - yy) * 8) % 1.0 - 0.5) < 0.08)) * 1.0
    cone_a = np.stack([0.78, 0.55, 0.28])[None, None, :] * (0.85 + 0.15 * wa - 0.25 * grid)[..., None]
    M = {"cone": scene.material("ic_cone", tex.to_image("ic_cone_albedo", np.clip(cone_a, 0, 1)),
                                normal_tex=tex.to_image("ic_cone_normal", tex.normal_from_height(1 - grid, 1.5), non_color=True), roughness=0.8),
         "pink": scene.material("ic_strawberry", base_color=(0.95, 0.6, 0.66), roughness=0.55),
         "cream": scene.material("ic_vanilla", base_color=(0.97, 0.93, 0.8), roughness=0.55)}
    cone = MeshBuilder()
    lathe(cone, [(0.0, 0.0), (0.004, 0.003), (0.032, 0.11), (0.034, 0.118), (0.0, 0.118)], 24, "cone")
    objs = [(cone, cone.to_object("Cone", M))]
    for k, (z, mat, r) in enumerate(((0.135, "cream", 0.038), (0.185, "pink", 0.034))):
        s = MeshBuilder()
        prof = [(0.0, z - r * 0.9)]
        for a in range(-80, 91, 15):
            t = math.radians(a)
            wob = 1.0 + 0.06 * math.sin(a * 0.3) * (a < 0)
            prof.append((math.cos(t) * r * wob, z + math.sin(t) * r * 0.9))
        prof.append((0.0, z + r * 0.9))
        lathe(s, prof, 20, mat, cap_start=False, cap_end=False)
        objs.append((s, s.to_object("Scoop%d" % k, M)))
    _out(d + "/ice_cream.glb", objs)

    def balloon(mb):
        prof = [(0.0, 0.0), (0.012, 0.004), (0.02, 0.012)] + [(0.12 * math.sin(math.pi * t) ** 0.8 * (1 - 0.15 * t), 0.012 + 0.3 * t) for t in [i / 16 for i in range(1, 16)]] + [(0.0, 0.31)]
        lathe(mb, prof, 24, "latex")
        mb.tube([Vector((0, 0, 0.0)), Vector((0.01, 0.0, -0.15)), Vector((-0.01, 0.0, -0.3))], [0.0015] * 3, 4, "ribbon", [])
    _one(d + "/balloon.glb", "Balloon", lambda: {"latex": scene.material("balloon_latex", base_color=(0.85, 0.05, 0.06), roughness=0.15),
                                                  "ribbon": scene.material("balloon_ribbon", base_color=(0.95, 0.95, 0.95), roughness=0.5)}, balloon)

    def ball(mb):
        cols = ["red", "yellow", "blue", "white", "green", "orange"]
        n_lat, n_lon = 12, 36
        for i in range(n_lat):
            for j in range(n_lon):
                t0, t1 = math.pi * i / n_lat, math.pi * (i + 1) / n_lat
                p0, p1 = 2 * math.pi * j / n_lon, 2 * math.pi * (j + 1) / n_lon
                def P(t, p):
                    return Vector((math.sin(t) * math.cos(p), math.sin(t) * math.sin(p), math.cos(t))) * 0.15
                mat = "white" if i < 2 or i >= n_lat - 2 else cols[(j * 6) // n_lon]
                ids = [mb.add_vert(P(t0, p0), []), mb.add_vert(P(t1, p0), []), mb.add_vert(P(t1, p1), []), mb.add_vert(P(t0, p1), [])]
                mb.add_face(ids, [(0, 0), (0, 1), (1, 1), (1, 0)], mat, True)
    _one(d + "/beach_ball.glb", "BeachBall", lambda: {
        "red": scene.material("bb_red", base_color=(0.85, 0.1, 0.1), roughness=0.3), "yellow": scene.material("bb_yellow", base_color=(0.95, 0.8, 0.1), roughness=0.3),
        "blue": scene.material("bb_blue", base_color=(0.1, 0.3, 0.85), roughness=0.3), "white": scene.material("bb_white", base_color=(0.95, 0.95, 0.95), roughness=0.3),
        "green": scene.material("bb_green", base_color=(0.15, 0.65, 0.25), roughness=0.3), "orange": scene.material("bb_orange", base_color=(0.95, 0.5, 0.1), roughness=0.3)}, ball)


# ------------------------------------------------------------------ doors, keys, switches

def _door(d):
    scene.reset()
    g = tex.fbm(128, 256, 3, 40, 81, 3)
    paint = scene.material("door_paint", tex.to_image("door_paint_albedo", np.clip(np.ones((256, 128, 3)) * (0.9 + 0.1 * g)[..., None], 0, 1)),
                           normal_tex=tex.to_image("door_paint_normal", tex.normal_from_height(g, 0.6), non_color=True), roughness=0.45)
    M = {"paint": paint,
         "frame": scene.material("door_frame_paint", base_color=(0.75, 0.75, 0.75), roughness=0.5),
         "brass": scene.material("door_brass", base_color=(0.78, 0.62, 0.32), roughness=0.25, metallic=1.0)}
    W, H, T = 0.92, 2.05, 0.045
    fr = MeshBuilder()      # the frame, centred on the opening (Blender: x across, z up, y = thickness)
    for x0, x1 in ((-W / 2 - 0.09, -W / 2), (W / 2, W / 2 + 0.09)):
        box(fr, (x0, -0.08, 0.0), (x1, 0.08, H + 0.09), "frame", 0.5)
        box(fr, (x0 - 0.01, -0.1, 0.0), (x1 + 0.01, -0.08, H + 0.11), "frame", 0.5)      # architrave
        box(fr, (x0 - 0.01, 0.08, 0.0), (x1 + 0.01, 0.1, H + 0.11), "frame", 0.5)
    box(fr, (-W / 2 - 0.09, -0.08, H), (W / 2 + 0.09, 0.08, H + 0.09), "frame", 0.5)
    box(fr, (-W / 2 - 0.1, -0.1, H + 0.09), (W / 2 + 0.1, 0.1, H + 0.13), "frame", 0.5)
    lf = MeshBuilder()      # the leaf: hinge at x = 0, running to x = W
    box(lf, (0.0, -T / 2, 0.0), (W, T / 2, H), "paint", 0.6)
    for row in range(2):
        ph = H * (0.38 if row == 1 else 0.3)
        pz = H * (0.7 if row == 1 else 0.27)
        for col in range(2):
            px = W / 2 + (col - 0.5) * W * 0.44
            for side in (-1, 1):
                y0 = side * T / 2
                # a raised field inside a sunk moulding
                box(lf, (px - W * 0.17, y0 if side > 0 else y0 - 0.006, pz - ph / 2), (px + W * 0.17, y0 + 0.006 if side > 0 else y0, pz + ph / 2), "paint", 0.3)
                box(lf, (px - W * 0.13, y0 if side > 0 else y0 - 0.012, pz - ph / 2 + 0.05), (px + W * 0.13, y0 + 0.012 if side > 0 else y0, pz + ph / 2 - 0.05), "paint", 0.3)
    for side in (-1, 1):
        y = side * (T / 2 + 0.01)
        lf.tube([Vector((W - 0.08, side * T / 2, 1.0)), Vector((W - 0.08, y + side * 0.04, 1.0))], [0.018, 0.012], 10, "brass", [], cap_start=True)
        lf.tube([Vector((W - 0.08, y + side * 0.04, 1.0)), Vector((W - 0.2, y + side * 0.045, 1.0))], [0.01, 0.009], 8, "brass", [])
        box(lf, (W - 0.12, side * T / 2, 0.88), (W - 0.04, side * T / 2 + side * 0.004, 1.12), "brass", 0.05)      # back plate
        box(lf, (0.04, side * T / 2, 0.04), (W - 0.04, side * T / 2 + side * 0.003, 0.24), "brass", 0.3)          # kick plate
    for z in (0.25, H - 0.25):
        lf.tube([Vector((0.0, 0.0, z - 0.05)), Vector((0.0, 0.0, z + 0.05))], [0.012, 0.012], 8, "brass", [], cap_start=True)
    _out(d + "/door_panel.glb", [(fr, fr.to_object("Frame", M, recalc_normals=True)), (lf, lf.to_object("Leaf", M, recalc_normals=True))])


def _small(d):
    brass = lambda: scene.material("brass", base_color=(0.8, 0.64, 0.3), roughness=0.3, metallic=1.0)

    def key(mb):
        lathe(mb, [(0.0, -0.006), (0.024, -0.006), (0.024, 0.006), (0.0, 0.006)], 20, "brass", center=Vector((0, 0, 0)))    # bow (a disc...)
        mb.tube([Vector((0.0, 0.0, 0.0)), Vector((0.0, -0.09, 0.0))], [0.005, 0.005], 8, "brass", [], cap_start=True)
        box(mb, (-0.002, -0.088, -0.018), (0.002, -0.07, 0.0), "brass", 0.02)       # bit
        box(mb, (-0.002, -0.072, -0.012), (0.002, -0.066, 0.0), "brass", 0.02)
        mb.tube([Vector((0.0, 0.03, 0.0)), Vector((0.012, 0.04, 0.0)), Vector((0.0, 0.05, 0.0)), Vector((-0.012, 0.04, 0.0)), Vector((0.0, 0.03, 0.0))], [0.0015] * 5, 6, "steel", [])
        box(mb, (-0.015, 0.05, -0.001), (0.015, 0.09, 0.001), "tag", 0.05)
    _one(d + "/key.glb", "Key", lambda: {"brass": brass(), "steel": scene.material("key_ring", base_color=(0.7, 0.7, 0.72), roughness=0.2, metallic=1.0),
                                          "tag": scene.material("key_tag", base_color=(0.85, 0.2, 0.15), roughness=0.8)}, key)

    def fuse(mb):
        lathe(mb, [(0.0, -0.07), (0.022, -0.07), (0.022, -0.04), (0.0, -0.04)], 16, "brass")
        lathe(mb, [(0.0, 0.04), (0.022, 0.04), (0.022, 0.07), (0.0, 0.07)], 16, "brass")
        lathe(mb, [(0.019, -0.04), (0.019, 0.04)], 16, "glass", cap_start=False, cap_end=False)
        mb.tube([Vector((0, 0, -0.04)), Vector((0.004, 0, 0.0)), Vector((0, 0, 0.04))], [0.0012] * 3, 4, "wire", [])
        for z in (-0.075, 0.075):
            box(mb, (-0.004, -0.012, z - 0.008 if z < 0 else z), (0.004, 0.012, z if z < 0 else z + 0.008), "brass", 0.02)
    _one(d + "/fuse.glb", "Fuse", lambda: {"brass": brass(), "glass": scene.material("fuse_glass", base_color=(0.8, 0.85, 0.9), roughness=0.05, alpha=0.4),
                                            "wire": scene.material("fuse_wire", base_color=(0.6, 0.6, 0.6), roughness=0.3, metallic=1.0)}, fuse)

    def wheel(mb):
        # in the X-Z plane (facing Blender -Y = Godot +Z), 0.6 across
        R = 0.28
        pts = [Vector((math.cos(a) * R, 0.0, math.sin(a) * R)) for a in (2 * math.pi * k / 32 for k in range(33))]
        mb.tube(pts, [0.022] * len(pts), 10, "red", [])
        for k in range(5):
            a = 2 * math.pi * k / 5
            mb.tube([Vector((0, 0, 0)), Vector((math.cos(a) * R, 0, math.sin(a) * R))], [0.016, 0.013], 8, "red", [])
            for j in range(6):    # knurls on the rim
                b = a + j * 0.2
                c = Vector((math.cos(b) * R, -0.02, math.sin(b) * R))
                box(mb, c - Vector((0.006, 0.006, 0.006)), c + Vector((0.006, 0.006, 0.006)), "red", 0.02)
        mb.tube([Vector((0, 0.04, 0)), Vector((0, -0.05, 0))], [0.05, 0.045], 14, "iron", [], cap_start=True)
        mb.tube([Vector((0, -0.05, 0)), Vector((0, -0.07, 0))], [0.025, 0.025], 6, "iron", [], cap_start=True)
    _one(d + "/valve_wheel.glb", "ValveWheel", lambda: {"red": scene.material("valve_red", base_color=(0.55, 0.08, 0.05), roughness=0.5, metallic=0.4),
                                                         "iron": scene.material("valve_iron", base_color=(0.15, 0.15, 0.15), roughness=0.6, metallic=0.7)}, wheel)

    # the box and its lever are separate meshes ("Box", "Lever"): the game flips only the lever. The lever is built
    # around the origin; it hinges at PIVOT (Blender x 0.115, y -0.02, z 0 = Godot (0.115, 0, 0.02)).
    def breaker_box(mb):
        box(mb, (-0.15, 0.0, -0.22), (0.15, 0.12, 0.22), "grey", 0.3)
        box(mb, (-0.13, -0.005, -0.2), (0.13, 0.0, 0.2), "grey", 0.3)
        box(mb, (0.1, -0.03, -0.05), (0.13, 0.0, 0.05), "black", 0.1)         # pivot block
        box(mb, (-0.1, -0.006, 0.08), (0.02, -0.004, 0.16), "label", 0.1)

    def breaker_lever(mb):
        mb.tube([Vector((0.0, 0.0, 0.0)), Vector((0.0, -0.08, 0.12))], [0.012, 0.012], 8, "black", [])
        mb.tube([Vector((0.0, -0.08, 0.12)), Vector((0.0, -0.11, 0.16))], [0.022, 0.022], 10, "red", [], cap_start=True)
    scene.reset()
    M = {"grey": scene.material("breaker_grey", base_color=(0.45, 0.47, 0.46), roughness=0.5, metallic=0.5),
         "black": scene.material("breaker_black", base_color=(0.05, 0.05, 0.05), roughness=0.6),
         "red": scene.material("breaker_red", base_color=(0.7, 0.08, 0.05), roughness=0.4),
         "label": scene.material("breaker_label", base_color=(0.9, 0.75, 0.1), roughness=0.6)}
    bx, lv = MeshBuilder(), MeshBuilder()
    breaker_box(bx)
    breaker_lever(lv)
    _out(d + "/breaker.glb", [(bx, bx.to_object("Box", M, recalc_normals=True)), (lv, lv.to_object("Lever", M, recalc_normals=True))])

    # a changing-room locker, 0.57 wide x 0.55 deep x 2.0 high, front facing Godot +Z: the body ("Body", open at
    # the front: back, sides, top, floor, a shelf, a coat hook) and the door ("Door", built around its hinge, which
    # sits on the body's +X front edge: Blender (0.285, -0.275, 0) = Godot (0.285, 0, 0.275); it opens with +yaw)
    W, D, H, T = 0.57, 0.55, 2.0, 0.015
    def locker_body(mb):
        box(mb, (-W / 2, D / 2 - T, 0.0), (W / 2, D / 2, H), "paint", 0.5)                  # back
        for sx in (-1, 1):
            box(mb, (sx * W / 2 - T if sx > 0 else -W / 2, -D / 2, 0.0), (W / 2 if sx > 0 else -W / 2 + T, D / 2, H), "paint", 0.5)
        box(mb, (-W / 2, -D / 2, H - T), (W / 2, D / 2, H), "paint", 0.5)                    # top
        box(mb, (-W / 2, -D / 2, 0.0), (W / 2, D / 2, 0.08), "dark", 0.5)                    # plinth / floor
        box(mb, (-W / 2 + T, -D / 2 + 0.02, 1.62), (W / 2 - T, D / 2 - T, 1.635), "paint", 0.5)   # hat shelf
        mb.tube([Vector((0, D / 2 - T, 1.5)), Vector((0, D / 2 - 0.08, 1.5)), Vector((0, D / 2 - 0.1, 1.54))], [0.008] * 3, 6, "steel", [])
        for z in (0.02, H - 0.02):                                                            # the frame lip round the door
            box(mb, (-W / 2, -D / 2 - 0.004, z - 0.02), (W / 2, -D / 2, z + 0.02), "dark", 0.3)
        box(mb, (-W / 2, -D / 2 - 0.004, 0.0), (-W / 2 + 0.02, -D / 2, H), "dark", 0.3)
        box(mb, (W / 2 - 0.02, -D / 2 - 0.004, 0.0), (W / 2, -D / 2, H), "dark", 0.3)

    def locker_door(mb):   # around the hinge: x from -0.55 to 0, y (thickness) -0.02 .. 0, z 0.09 .. 1.97
        x0, x1 = -W + 0.02, -0.005
        box(mb, (x0, -0.02, 0.09), (x1, 0.0, H - 0.03), "paint", 0.5)
        for k in range(5):                                                                   # vent louvres
            z = 1.62 + k * 0.05
            box(mb, (x0 + 0.12, -0.026, z), (x1 - 0.12, -0.02, z + 0.018), "dark", 0.1)
            box(mb, (x0 + 0.12, -0.026, z - 1.4), (x1 - 0.12, -0.02, z - 1.4 + 0.018), "dark", 0.1)
        box(mb, (x0 + 0.03, -0.045, 1.0), (x0 + 0.06, -0.02, 1.18), "steel", 0.1)            # handle (free edge)
        box(mb, (x0 + 0.03, -0.03, 0.9), (x0 + 0.07, -0.02, 0.97), "steel", 0.1)             # latch plate
        cyl_ = mb.tube
        cyl_([Vector((x0 + 0.05, -0.031, 0.935)), Vector((x0 + 0.05, -0.038, 0.935))], [0.012, 0.012], 10, "dark", [])
        box(mb, ((x0 + x1) / 2 - 0.07, -0.024, 1.4), ((x0 + x1) / 2 + 0.07, -0.02, 1.5), "plate", 0.1)   # number plate
        for z in (0.25, 1.75):                                                               # hinge knuckles
            mb.tube([Vector((0.0, -0.01, z)), Vector((0.0, -0.01, z + 0.08))], [0.008, 0.008], 6, "steel", [])
    scene.reset()
    LM = {"paint": scene.material("locker_paint", base_color=(0.3, 0.45, 0.55), roughness=0.45, metallic=0.5),
          "dark": scene.material("locker_dark", base_color=(0.12, 0.16, 0.19), roughness=0.5, metallic=0.4),
          "steel": scene.material("locker_steel", base_color=(0.75, 0.76, 0.78), roughness=0.25, metallic=0.9),
          "plate": scene.material("locker_plate", base_color=(0.85, 0.85, 0.8), roughness=0.5)}
    lb, ld = MeshBuilder(), MeshBuilder()
    locker_body(lb)
    locker_door(ld)
    _out(d + "/locker.glb", [(lb, lb.to_object("Body", LM, recalc_normals=True)), (ld, ld.to_object("Door", LM, recalc_normals=True))])

    def notebook(mb):
        rounded_box(mb, Vector((0, 0, 0.008)), (0.17, 0.23, 0.016), 0.004, "cover", 2)
        box(mb, (-0.081, -0.11, 0.002), (0.083, 0.11, 0.014), "pages", 0.1)
        box(mb, (0.06, -0.117, 0.0), (0.068, 0.117, 0.0165), "band", 0.05)
    _one(d + "/notebook.glb", "Notebook", lambda: {"cover": scene.material("nb_cover", base_color=(0.4, 0.05, 0.05), roughness=0.75),
                                                    "pages": scene.material("nb_pages", base_color=(0.92, 0.9, 0.82), roughness=0.9),
                                                    "band": scene.material("nb_band", base_color=(0.05, 0.05, 0.05), roughness=0.6)}, notebook)

    def pc(mb):
        # monitor (facing Blender -Y = Godot +Z), on a stand; keyboard and mouse in front
        rounded_box(mb, Vector((0, 0, 0.36)), (0.6, 0.04, 0.36), 0.012, "plastic", 2)
        box(mb, (-0.28, -0.022, 0.2), (0.28, -0.019, 0.52), "screen", 0.2)
        lathe(mb, [(0.0, 0.0), (0.11, 0.0), (0.1, 0.012), (0.0, 0.012)], 20, "plastic", center=Vector((0, 0.05, 0)))
        box(mb, (-0.025, 0.02, 0.01), (0.025, 0.06, 0.25), "plastic", 0.1)
        rounded_box(mb, Vector((0, -0.28, 0.012)), (0.44, 0.14, 0.022), 0.006, "plastic", 2)
        for r in range(5):
            for c in range(14):
                x = -0.2 + c * 0.03
                y = -0.33 + r * 0.025
                box(mb, (x, y, 0.022), (x + 0.024, y + 0.02, 0.03), "keys", 0.05)
        rounded_box(mb, Vector((0.3, -0.28, 0.015)), (0.06, 0.1, 0.03), 0.012, "plastic", 3)
    _one(d + "/pc_set.glb", "PCSet", lambda: {"plastic": scene.material("pc_plastic", base_color=(0.08, 0.08, 0.09), roughness=0.5),
                                               "screen": scene.material("pc_screen", base_color=(0.02, 0.03, 0.05), roughness=0.08, metallic=0.4),
                                               "keys": scene.material("pc_keys", base_color=(0.15, 0.15, 0.16), roughness=0.6)}, pc)

    def payphone(mb):
        box(mb, (-0.05, 0.08, 0.0), (0.05, 0.18, 1.2), "steel", 0.3)                      # post
        rounded_box(mb, Vector((0, 0.06, 1.4)), (0.36, 0.16, 0.62), 0.03, "steel", 2)     # the box
        box(mb, (-0.15, -0.025, 1.52), (0.04, -0.02, 1.65), "screen", 0.1)
        for r in range(4):
            for c in range(3):
                box(mb, (-0.12 + c * 0.05, -0.03, 1.3 + r * 0.045), (-0.085 + c * 0.05, -0.02, 1.33 + r * 0.045), "chrome", 0.05)
        rounded_box(mb, Vector((0.12, -0.03, 1.42)), (0.07, 0.07, 0.24), 0.03, "black", 2)    # the handset, on its hook
        mb.tube([Vector((0.12, -0.03, 1.3)), Vector((0.1, -0.08, 1.15)), Vector((0.02, -0.05, 1.1)), Vector((0.0, -0.02, 1.15))], [0.006] * 4, 6, "black", [])
        rounded_box(mb, Vector((0, -0.05, 1.85)), (0.6, 0.45, 0.04), 0.015, "hood", 2)   # a hood
        for x in (-0.3, 0.3):
            box(mb, (x - 0.01, -0.27, 1.35), (x + 0.01, 0.15, 1.85), "hood", 0.3)
    _one(d + "/payphone.glb", "Payphone", lambda: {"steel": scene.material("pp_steel", base_color=(0.55, 0.57, 0.6), roughness=0.35, metallic=0.8),
                                                    "chrome": scene.material("pp_chrome", base_color=(0.8, 0.8, 0.82), roughness=0.15, metallic=1.0),
                                                    "black": scene.material("pp_black", base_color=(0.03, 0.03, 0.03), roughness=0.5),
                                                    "screen": scene.material("pp_screen", base_color=(0.3, 0.45, 0.35), emission_color=(0.3, 0.5, 0.4), emission_strength=0.6, roughness=0.2),
                                                    "hood": scene.material("pp_hood", base_color=(0.1, 0.25, 0.55), roughness=0.4, metallic=0.3)}, payphone)

    def pigeon(mb):
        # a body lofted along the bird's length (Blender -Y = forward = Godot +Z)
        prof = [(-0.13, 0.012, 0.11), (-0.1, 0.03, 0.12), (-0.05, 0.055, 0.13), (0.0, 0.06, 0.13), (0.05, 0.05, 0.14), (0.08, 0.03, 0.17), (0.1, 0.028, 0.2), (0.12, 0.02, 0.2)]
        rings = []
        for y, r, z in prof:
            rings.append([Vector((math.cos(a) * r, -y, z + math.sin(a) * r * 0.9)) for a in (2 * math.pi * k / 12 for k in range(12))])
        mb.loft(rings, "grey", lambda ri, p: [], cap_start=True, cap_end=True)
        mb.tube([Vector((0, -0.12, 0.2)), Vector((0, -0.145, 0.195))], [0.008, 0.002], 6, "beak", [], cap_start=True)
        for sx in (-1, 1):
            box(mb, (sx * 0.02, -0.11, 0.205), (sx * 0.025, -0.105, 0.21), "eye", 0.01)
            mb.tube([Vector((sx * 0.02, -0.0, 0.1)), Vector((sx * 0.02, -0.01, 0.0))], [0.005, 0.004], 5, "beak", [])
            box(mb, (sx * 0.05 - 0.01, -0.05, 0.11), (sx * 0.06 + 0.01, 0.1, 0.16), "wing", 0.05)
        box(mb, (-0.03, 0.12, 0.1), (0.03, 0.19, 0.115), "wing", 0.05)       # tail
        box(mb, (-0.035, -0.09, 0.15), (0.035, -0.06, 0.2), "neck", 0.05)    # the green-purple neck
    _one(d + "/pigeon.glb", "Pigeon", lambda: {"grey": scene.material("pg_grey", base_color=(0.5, 0.52, 0.56), roughness=0.8),
                                                "wing": scene.material("pg_wing", base_color=(0.35, 0.37, 0.42), roughness=0.8),
                                                "neck": scene.material("pg_neck", base_color=(0.25, 0.4, 0.35), roughness=0.4, metallic=0.4),
                                                "beak": scene.material("pg_beak", base_color=(0.75, 0.45, 0.4), roughness=0.6),
                                                "eye": scene.material("pg_eye", base_color=(0.9, 0.4, 0.1), roughness=0.2)}, pigeon)


def build(out_dir):
    import os
    root = os.path.dirname(out_dir)
    objects = os.path.join(root, "objects")
    os.makedirs(objects, exist_ok=True)
    _objects(objects)
    _door(out_dir)
    _small(out_dir)
