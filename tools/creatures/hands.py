"""The dreamer's first-person hand and forearm (models/fp_hand.glb): a right hand, mirrored in-game for the left.

Sculpted the way you would by hand, but in code:
  1. a high-resolution form from metaballs (palm with thenar/hypothenar pads, metacarpal ridges, knuckle
     heads, the web of the thumb, finger pads, a tapering forearm), each finger its own metaball family so
     the fingers don't melt together, fused with a voxel remesh and smoothed;
  2. skin detail displaced into it: flexion creases at every finger joint, the palm's three main lines and
     the wrist creases, wrinkles over the knuckles, raised veins on the back of the hand and the forearm;
  3. colour painted per vertex: warmer knuckles and fingertips, a paler palm and inner forearm, darker
     creases, blue-grey veins, mottling and a few freckles;
  4. a game mesh (~9k triangles) decimated from it, unwrapped, with colour and normal maps baked from the
     high-resolution version (plus pores);
  5. nails as their own little curved plates, fitted to the fingertips;
  6. a rig: forearm, hand, three bones per finger and thumb, weighted automatically.

Rig contract with scripts/player/fp_hands.gd: bones forearm, hand, {index,middle,ring,pinky,thumb}_{1,2,3};
each finger bone bends (curls toward the palm) about its local -X; Blender +Y (fingers) = Godot -Z, the back of
the hand faces Godot +Y, the thumb is on Godot -X (a right hand). Origin = the middle of the wrist.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

from dp import geo, scene, tex

HI_VOXEL = 0.00055
LO_TRIS = 9000
TEX = 1024

# name, MCP joint, splay (deg, + toward the pinky), phalanx lengths, radii at base / PIP / DIP / tip
FINGERS = [
    ("index", (-0.0285, 0.090, 0.0), -4.0, (0.041, 0.024, 0.020), (0.0098, 0.0089, 0.0079, 0.0069)),
    ("middle", (-0.0092, 0.094, 0.0), -0.5, (0.046, 0.028, 0.021), (0.0100, 0.0091, 0.0081, 0.0071)),
    ("ring", (0.0102, 0.0915, -0.001), 3.5, (0.043, 0.026, 0.020), (0.0094, 0.0086, 0.0077, 0.0067)),
    ("pinky", (0.0278, 0.0835, -0.003), 9.0, (0.033, 0.020, 0.018), (0.0081, 0.0075, 0.0067, 0.0059)),
]
THUMB_CMC = Vector((-0.019, 0.014, -0.011))
THUMB_MCP = Vector((-0.043, 0.050, -0.019))
THUMB_DIR = Vector((-0.36, 0.90, -0.17)).normalized()
THUMB_LEN = (0.032, 0.027)
THUMB_UP = Vector((-0.72, 0.05, 0.69))   # the way the thumbnail faces


def _lin(c):
    return np.array([tex.linear(v) for v in c])


def chains():
    """[(name, [joint positions], dorsal vector, [radii])] for the four fingers and the thumb."""
    out = []
    for name, mcp, splay, lens, radii in FINGERS:
        a = math.radians(splay)
        d = Vector((math.sin(a), math.cos(a), -0.02)).normalized()
        pts = [Vector(mcp)]
        for ln in lens:
            pts.append(pts[-1] + d * ln)
        out.append((name, pts, Vector((0, 0, 1)), list(radii)))
    up = (THUMB_UP - THUMB_DIR * THUMB_UP.dot(THUMB_DIR)).normalized()
    pts = [THUMB_CMC, THUMB_MCP, THUMB_MCP + THUMB_DIR * THUMB_LEN[0], THUMB_MCP + THUMB_DIR * (THUMB_LEN[0] + THUMB_LEN[1])]
    out.append(("thumb", pts, up, [0.0135, 0.0112, 0.0101, 0.0087]))
    return out


# ------------------------------------------------------------------ the form (metaballs)

_K = 1.0   # metaball radius -> surface radius, measured once


def _calibrate():
    global _K
    mb = bpy.data.metaballs.new("Cal")
    mb.resolution = 0.0004
    el = mb.elements.new(type='BALL')
    el.co = (0, 0, 0)
    el.radius = 0.01
    ob = bpy.data.objects.new("Cal", mb)
    bpy.context.scene.collection.objects.link(ob)
    me = _convert([ob])
    xs = [v.co.x for v in me.data.vertices]
    _K = (max(xs) - min(xs)) * 0.5 / 0.01
    bpy.data.objects.remove(me)
    print(f"  metaball radius factor {_K:.3f}")


def _family(name):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = 0.0009
    mb.render_resolution = 0.0009
    mb.threshold = 0.6
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _quat_x_to(d):
    return Vector((1, 0, 0)).rotation_difference(d.normalized())


def _capsule(ob, a, b, r, stiff=2.0):
    el = ob.data.elements.new(type='CAPSULE')
    el.co = (a + b) * 0.5
    el.radius = r / _K
    el.size_x = (b - a).length * 0.5
    el.rotation = _quat_x_to(b - a)
    el.stiffness = stiff


def _ellipsoid(ob, c, half, rot=Quaternion(), stiff=2.0):
    m = max(half)
    el = ob.data.elements.new(type='ELLIPSOID')
    el.co = c
    el.radius = m / _K
    el.size_x, el.size_y, el.size_z = half[0] / m, half[1] / m, half[2] / m
    el.rotation = rot
    el.stiffness = stiff


def _ball(ob, c, r, stiff=2.0):
    el = ob.data.elements.new(type='BALL')
    el.co = c
    el.radius = r / _K
    el.stiffness = stiff


def _convert(objs):
    """A metaball family -> a mesh object (the evaluated surface); the metaball object goes."""
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    src = objs[0]
    me = bpy.data.meshes.new_from_object(src.evaluated_get(dg))
    ob = bpy.data.objects.new(src.name + "_mesh", me)
    ob.matrix_world = src.matrix_world
    bpy.context.scene.collection.objects.link(ob)
    for o in objs:
        bpy.data.objects.remove(o)
    return ob


def _form():
    palm = _family("Palm")
    # the palm block, the pads, the dorsal ridges of the metacarpals and the knuckle heads
    _ellipsoid(palm, Vector((0.0, 0.050, -0.002)), (0.034, 0.036, 0.0095))
    _ellipsoid(palm, Vector((-0.024, 0.031, -0.010)), (0.0135, 0.024, 0.0115), Quaternion((0, 0, 1), math.radians(-28)))
    _ellipsoid(palm, Vector((0.027, 0.040, -0.006)), (0.0095, 0.030, 0.0092), Quaternion((0, 0, 1), math.radians(6)))
    _ellipsoid(palm, Vector((0.0, 0.081, -0.0065)), (0.036, 0.0095, 0.0075))
    for name, mcp, splay, lens, radii in FINGERS:
        m = Vector(mcp)
        _capsule(palm, Vector((m.x * 0.55, 0.012, 0.004)), m + Vector((0, -0.006, 0.0015)), 0.0068)
        _ball(palm, m + Vector((0, 0, 0.0015)), radii[0] * 1.02)
        a = math.radians(splay)
        _capsule(palm, m, m + Vector((math.sin(a), math.cos(a), 0)) * 0.010, radii[0] * 0.98)
    # the web between thumb and index, and the base of the thumb
    _capsule(palm, THUMB_MCP + Vector((0.004, 0.002, 0.002)), Vector(FINGERS[0][1]) + Vector((-0.002, -0.012, -0.004)), 0.0046)
    _capsule(palm, THUMB_CMC, THUMB_MCP, 0.0128)
    # wrist and forearm: wider and flatter toward the elbow
    _ellipsoid(palm, Vector((0, 0.004, -0.0005)), (0.0275, 0.016, 0.0165))
    _capsule(palm, Vector((0, 0.0, 0)), Vector((0, -0.27, 0.004)), 0.0185)
    for y, hx, hz in ((-0.035, 0.0265, 0.018), (-0.09, 0.0285, 0.0205), (-0.15, 0.0315, 0.0245), (-0.21, 0.034, 0.0275), (-0.255, 0.0345, 0.0285)):
        _ellipsoid(palm, Vector((0, y, 0.001 + (0.004 if y < -0.1 else 0.0))), (hx, 0.034, hz))
    parts = [_convert([palm])]
    # fingers and the thumb: their own families
    for name, pts, up, radii in chains():
        ob = _family("F_" + name)
        start = 1 if name == "thumb" else 0
        for i in range(start, 3):
            a, b = pts[i], pts[i + 1]
            ra, rb = radii[i], radii[i + 1]
            mid = a.lerp(b, 0.5)
            _capsule(ob, a, mid, (ra + (ra + rb) * 0.5) * 0.5)
            _capsule(ob, mid, b, ((ra + rb) * 0.5 + rb) * 0.5)
            _ball(ob, b, rb * 0.97)
            # the pad on the palm side of each segment
            d = (b - a).normalized()
            q = Vector((0, 1, 0)).rotation_difference(d)
            _ellipsoid(ob, mid - up * rb * 0.35, (rb * 0.8, (b - a).length * 0.32, rb * 0.62), q)
        # the fingertip: a rounded pad, slightly flattened
        tip, d = pts[3], (pts[3] - pts[2]).normalized()
        q = Vector((0, 1, 0)).rotation_difference(d)
        _ellipsoid(ob, tip - d * 0.004 - up * radii[3] * 0.2, (radii[3] * 0.95, radii[3] * 1.15, radii[3] * 0.8), q)
        parts.append(_convert([ob]))
    for o in bpy.context.view_layer.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    hand = bpy.context.view_layer.objects.active
    hand.name = "HandHigh"
    rm = hand.modifiers.new("Remesh", 'REMESH')
    rm.mode = 'VOXEL'
    rm.voxel_size = HI_VOXEL
    sm = hand.modifiers.new("Smooth", 'SMOOTH')
    sm.factor = 0.6
    sm.iterations = 6
    scene.apply_modifiers(hand)
    return hand


# ------------------------------------------------------------------ skin detail

def _noise3(P, freq, seed=0, octaves=3):
    """Smooth 3D value noise (fbm) at many points at once, in [-1, 1]."""
    out = np.zeros(len(P))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        X = P * freq * (2 ** o) + seed * 17.13 + o * 3.7
        i0 = np.floor(X).astype(np.int64)
        f = X - i0
        f = f * f * (3 - 2 * f)
        acc = np.zeros(len(P))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    h = (i0[:, 0] + dx) * 73856093 ^ (i0[:, 1] + dy) * 19349663 ^ (i0[:, 2] + dz) * 83492791
                    h = (h * 2654435761) & 0xFFFFFFFF
                    r = (h % 10007) / 10007.0 * 2 - 1
                    wx = f[:, 0] if dx else 1 - f[:, 0]
                    wy = f[:, 1] if dy else 1 - f[:, 1]
                    wz = f[:, 2] if dz else 1 - f[:, 2]
                    acc += r * wx * wy * wz
        out += amp * acc
        total += amp
        amp *= 0.5
    return out / total


def _seg_param(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0.0, 1.0)
    q = a + t[:, None] * ab
    return np.linalg.norm(P - q, axis=1), t


def _polyline_dist(P2, pts):
    d = np.full(len(P2), 1e9)
    for i in range(len(pts) - 1):
        a, b = np.array(pts[i]), np.array(pts[i + 1])
        ab = b - a
        t = np.clip(((P2 - a) @ ab) / (ab @ ab), 0, 1)
        d = np.minimum(d, np.linalg.norm(P2 - (a + t[:, None] * ab), axis=1))
    return d


def _smooth_path(pts, n=40):
    out = []
    for i in range(n + 1):
        out.append(tuple(geo.catmull([Vector(p) for p in pts], i / n)))
    return out


def _detail(hand):
    me = hand.data
    nv = len(me.vertices)
    P = np.zeros(nv * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    me.calc_normals() if hasattr(me, "calc_normals") else None
    N = np.zeros(nv * 3)
    me.vertices.foreach_get("normal", N)
    N = N.reshape(-1, 3)
    rng = np.random.default_rng(5)

    # which part of the hand each vertex belongs to: nearest bone segment
    segs = [("forearm", np.array([0, -0.28, 0.003]), np.array([0, -0.01, 0.0]), np.array([0, 0, 1.0]))]
    segs.append(("hand", np.array([0, -0.01, 0.0]), np.array([0, 0.085, 0.0]), np.array([0, 0, 1.0])))
    for name, pts, up, radii in chains():
        for i in range(3):
            segs.append((f"{name}_{i + 1}", np.array(pts[i]), np.array(pts[i + 1]), np.array(up)))
    dists = np.stack([_seg_param(P, a, b)[0] - (0.02 if n in ("hand", "forearm") else 0.0) for n, a, b, u in segs], 1)
    owner = np.argmin(dists, 1)
    names = [s[0] for s in segs]

    disp = np.zeros(nv)
    crease = np.zeros(nv)     # 0..1, for colour
    vein = np.zeros(nv)
    knuck = np.zeros(nv)
    up_all = np.stack([segs[o][3] for o in range(len(segs))])[owner]
    dorsal = np.einsum("ij,ij->i", N, up_all)          # +1 back of the hand, -1 palm side
    dmask = np.clip((dorsal - 0.2) / 0.5, 0, 1)
    pmask = np.clip((-dorsal - 0.2) / 0.5, 0, 1)

    noise = _noise3(P, 900.0, 1, 2)

    # finger joints: palm-side flexion creases, knuckle bumps and wrinkles on the back
    for name, pts, up, radii in chains():
        for j in (1, 2):           # PIP and DIP (for the thumb: MCP and IP)
            a, jp, b = np.array(pts[j - 1]), np.array(pts[j]), np.array(pts[j + 1])
            ax = b - a
            ax /= np.linalg.norm(ax)
            sel = np.isin(owner, [names.index(f"{name}_{j}"), names.index(f"{name}_{j + 1}")])
            s = (P - jp) @ ax
            w = 1.0 if j == 1 else 0.7
            lines = (-0.0011, 0.0011) if (j == 1 and name != "thumb") else (0.0,)
            for c in lines:
                g = np.exp(-((s - c) / 0.00055) ** 2)
                disp -= sel * pmask * g * 0.00042 * w
                crease += sel * pmask * g * w
            bump = np.exp(-(s / 0.0042) ** 2)
            ridges = np.sin(s * math.tau / 0.00105 + noise * 4.0) * np.exp(-(s / 0.0045) ** 2)
            disp += sel * dmask * (bump * 0.00055 * w + ridges * 0.00011 * w)
            crease += sel * dmask * np.clip(-ridges, 0, 1) * 0.5 * w
            knuck += sel * dmask * bump * w
        # crease at the base of each finger, palm side
        jp = np.array(pts[0 if name == "thumb" else 0]) + (np.array(pts[1]) - np.array(pts[0])) * (0.0 if name == "thumb" else 0.14)
        if name != "thumb":
            ax = np.array(pts[1]) - np.array(pts[0])
            ax /= np.linalg.norm(ax)
            s = (P - jp) @ ax
            sel = owner == names.index(f"{name}_1")
            g = np.exp(-(s / 0.0007) ** 2)
            disp -= sel * pmask * g * 0.0004
            crease += sel * pmask * g
        # knuckle heads (MCP) on the back of the hand
        mc = np.array(pts[1] if name == "thumb" else pts[0]) + np.array([0, 0, 0.004])
        g = np.exp(-(np.linalg.norm(P - mc, axis=1) / 0.007) ** 2)
        knuck += g * dmask

    # the palm's lines and the wrist creases (palm side of the hand/wrist)
    hsel = np.isin(owner, [names.index("hand"), names.index("forearm")]) * pmask
    P2 = P[:, :2]
    for path, depth in (
        (_smooth_path([(0.036, 0.071), (0.015, 0.075), (-0.008, 0.081), (-0.022, 0.075)]), 0.00055),   # heart line
        (_smooth_path([(-0.034, 0.053), (-0.012, 0.056), (0.012, 0.060), (0.027, 0.063)]), 0.0005),     # head line
        (_smooth_path([(-0.032, 0.054), (-0.018, 0.040), (-0.011, 0.024), (-0.008, 0.007)]), 0.0006),    # life line
        (_smooth_path([(-0.004, 0.012), (0.004, 0.040), (0.006, 0.066)]), 0.00025),                        # fate line, faint
        ([(-0.026, 0.004), (0.026, 0.006)], 0.0004), ([(-0.025, -0.006), (0.025, -0.005)], 0.00028),     # wrist
    ):
        dd = _polyline_dist(P2, path)
        g = np.exp(-(dd / 0.0008) ** 2)
        disp -= hsel * g * depth * 0.75
        crease += hsel * g * (depth / 0.0005) * 0.7
    # many fine palm creases
    fine = np.sin((P2[:, 0] * 0.7 + P2[:, 1]) * 1400.0 + noise * 6.0)
    disp -= hsel * np.clip(fine - 0.9, 0, 1) * 0.0004

    # veins on the back of the hand and up the forearm
    vsel = np.isin(owner, [names.index("hand"), names.index("forearm")]) * dmask
    for path in (
        [(-0.019, 0.074), (-0.012, 0.050), (-0.004, 0.028), (0.002, 0.0), (0.006, -0.06), (0.010, -0.15), (0.013, -0.26)],
        [(0.0, 0.078), (0.004, 0.052), (0.004, 0.030)],
        [(0.019, 0.072), (0.016, 0.048), (0.008, 0.028), (0.004, 0.012)],
        [(-0.028, 0.050), (-0.024, 0.020), (-0.021, -0.03), (-0.017, -0.12), (-0.012, -0.24)],
        [(0.006, -0.06), (-0.004, -0.11), (-0.014, -0.15)],
    ):
        sp = _smooth_path(path, 60)
        sp = [(x + 0.0012 * math.sin(y * 140.0), y) for x, y in sp]
        dd = _polyline_dist(P2, sp)
        g = np.exp(-(dd / 0.0017) ** 2)
        disp += vsel * g * 0.0004
        vein += vsel * g
    # fine irregularity everywhere
    disp += noise * 0.00005
    P2n = P + N * disp[:, None]
    me.vertices.foreach_set("co", P2n.ravel())
    me.update()

    # colour (linear)
    base = _lin((0.84, 0.64, 0.53))
    palm_c = _lin((0.88, 0.67, 0.59))
    red = _lin((0.80, 0.50, 0.45))
    dark = _lin((0.58, 0.39, 0.34))
    vein_c = _lin((0.62, 0.55, 0.60))
    frk = _lin((0.66, 0.46, 0.35))
    inner_arm = _lin((0.89, 0.71, 0.61))
    col = np.tile(base, (nv, 1))
    col = col * (1 - pmask[:, None] * 0.6) + palm_c * pmask[:, None] * 0.6
    fa = owner == names.index("forearm")
    col[fa] = col[fa] * (1 - pmask[fa, None] * 0.5) + inner_arm * pmask[fa, None] * 0.5
    tips = np.zeros(nv)
    for name, pts, up, radii in chains():
        tips += np.exp(-(np.linalg.norm(P - np.array(pts[3]), axis=1) / 0.009) ** 2)
    redness = np.clip(knuck * 0.45 + tips * 0.5 + pmask * 0.12, 0, 0.8)
    col = col * (1 - redness[:, None]) + red * redness[:, None]
    cr = np.clip(crease, 0, 1) * 0.4
    col = col * (1 - cr[:, None]) + dark * cr[:, None]
    vv = np.clip(vein, 0, 1) * 0.22
    col = col * (1 - vv[:, None]) + vein_c * vv[:, None]
    mott = _noise3(P, 120.0, 2, 3)
    col *= (0.96 + 0.08 * mott)[:, None]
    fr = (rng.random(nv) < 0.0009) & (dmask > 0.5)
    spots = np.zeros(nv)
    for i in np.nonzero(fr)[0]:
        spots += np.exp(-(np.linalg.norm(P - P[i], axis=1) / 0.0011) ** 2)
    sp = np.clip(spots, 0, 1) * 0.4
    col = col * (1 - sp[:, None]) + frk * sp[:, None]
    attr = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    attr.data.foreach_set("color", np.hstack([col, np.ones((nv, 1))]).ravel())
    return segs


# ------------------------------------------------------------------ nails

def _nails(hand):
    bvh = BVHTree.FromObject(hand, bpy.context.evaluated_depsgraph_get())
    nails = []
    for name, pts, up, radii in chains():
        a, b = pts[2], pts[3]
        d = (b - a).normalized()
        side = d.cross(up).normalized()
        r = radii[3]
        L = (b - a).length * (0.62 if name != "thumb" else 0.66)
        w = r * 1.55
        rows, cols = 9, 7
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        grid = []
        for i in range(rows):
            v = i / (rows - 1)
            row = []
            for j in range(cols):
                u = j / (cols - 1) - 0.5
                # rounded at the base, straight-ish at the free edge, slightly past the fingertip
                width = w * (0.86 + 0.14 * math.sin(min(1.0, v * 2.0) * math.pi * 0.5))
                along = b - d * (L - v * (L + 0.0018))
                if v < 0.32:
                    width *= math.sqrt(max(0.08, 1 - ((0.32 - v) / 0.32) ** 2))   # the rounded cuticle end
                p0 = along + side * (u * width) + up * 0.02
                hit = bvh.ray_cast(p0, -up, 0.05)
                if hit[0] is not None and v < 0.93:
                    p = hit[0] + hit[1] * 0.00022
                else:
                    # the free edge: carries on the curve of the last row, out in the air
                    p = (grid[-1][j] if grid else p0) + d * (0.0018 / max(1, rows - 1) * 2.0) - up * 0.0001
                row.append(p)
            grid.append(row)
        verts = [[bm.verts.new(p) for p in row] for row in grid]
        for i in range(rows - 1):
            for j in range(cols - 1):
                f = bm.faces.new((verts[i][j], verts[i][j + 1], verts[i + 1][j + 1], verts[i + 1][j]))
                for loop, (ii, jj) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                    loop[uvl].uv = (jj / (cols - 1), ii / (rows - 1))
        me = bpy.data.meshes.new("Nail_" + name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("Nail_" + name, me)
        bpy.context.scene.collection.objects.link(ob)
        so = ob.modifiers.new("Solid", 'SOLIDIFY')
        so.thickness = 0.0005
        so.offset = -1.0
        sub = ob.modifiers.new("Sub", 'SUBSURF')
        sub.levels = 1
        scene.apply_modifiers(ob)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob["bone"] = f"{name}_3"
        nails.append(ob)
    # join into one object; remember which vertices belong to which bone
    for o in bpy.context.view_layer.objects:
        o.select_set(o in nails)
    bpy.context.view_layer.objects.active = nails[0]
    groups = {}
    for o in nails:
        vg = o.vertex_groups.new(name=o["bone"])
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = "Nails"
    _ = groups
    return ob


def _nail_texture():
    W, H = 64, 128
    v = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
    u = np.linspace(-1, 1, W)[None, :] * np.ones((H, 1))
    pink = np.array([0.84, 0.60, 0.57])
    white = np.array([0.93, 0.89, 0.84])
    lunula = np.clip(1 - (((v - 0.02) / 0.12) ** 2 + (u / 0.45) ** 2), 0, 1)[..., None] * 0.5
    free = np.clip((v - 0.9) / 0.03, 0, 1)[..., None]
    streaks = 0.97 + 0.03 * np.sin(u * 40.0 + np.sin(v * 7.0))[..., None]
    c = pink[None, None, :] * (1 - free) + white[None, None, :] * free
    c = c * (1 - lunula * 0.6) + white[None, None, :] * lunula * 0.6
    c = c * streaks
    edge = np.clip(np.abs(u) - 0.85, 0, 1)[..., None] * 3.0
    c = c * (1 - edge * 0.3)
    return tex.to_image("nail_col", c)


# ------------------------------------------------------------------ rig

def _rig():
    bones = [("forearm", Vector((0, -0.27, 0.004)), Vector((0, -0.002, 0)), None),
             ("hand", Vector((0, -0.002, 0)), Vector((0, 0.07, 0)), "forearm")]
    for name, pts, up, radii in chains():
        parent = "hand"
        for i in range(3):
            tail = pts[i + 1] if i < 2 else pts[3] + (pts[3] - pts[2]).normalized() * radii[3] * 0.9
            bones.append((f"{name}_{i + 1}", pts[i], tail, parent))
            parent = f"{name}_{i + 1}"
    arm = scene.armature("HandRig", bones)
    # roll each bone so its local Z is the back of that finger (curl = rotate about local X)
    ups = {name: up for name, pts, up, radii in chains()}
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for eb in arm.data.edit_bones:
        key = eb.name.split("_")[0]
        eb.align_roll(ups.get(key, Vector((0, 0, 1))))
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


# ------------------------------------------------------------------ bake

def _bake(high, low, img, kind):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 4
    mat = low.data.materials[0]
    nodes = mat.node_tree.nodes
    node = nodes.new("ShaderNodeTexImage")
    node.image = img
    nodes.active = node
    for o in bpy.context.view_layer.objects:
        o.select_set(o in (high, low))
    bpy.context.view_layer.objects.active = low
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = 0.0018
    sc.render.bake.max_ray_distance = 0.004
    sc.render.bake.margin = 6
    if kind == "NORMAL":
        sc.render.bake.normal_space = 'TANGENT'
    bpy.ops.object.bake(type=kind)
    nodes.remove(node)


def build(out_path):
    scene.reset()
    _calibrate()
    high = _form()
    print(f"  high-res hand: {len(high.data.vertices)} verts")
    _detail(high)
    # emission material on the high mesh shows its vertex colours to the baker
    hm = bpy.data.materials.new("HighCol")
    hm.use_nodes = True
    nt = hm.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Col"
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(at.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    high.data.materials.append(hm)

    # the game mesh
    low = high.copy()
    low.data = high.data.copy()
    low.name = "Hand"
    bpy.context.scene.collection.objects.link(low)
    low.data.color_attributes.remove(low.data.color_attributes["Col"])
    low.data.materials.clear()
    dec = low.modifiers.new("Dec", 'DECIMATE')
    dec.ratio = LO_TRIS / (len(high.data.polygons) * (1 if len(high.data.polygons[0].vertices) == 3 else 2))
    scene.apply_modifiers(low)
    for p in low.data.polygons:
        p.use_smooth = True
    print(f"  game mesh: {len(low.data.polygons)} faces")
    for o in bpy.context.view_layer.objects:
        o.select_set(o == low)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(70), island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')

    col_img = bpy.data.images.new("hand_col", TEX, TEX)
    nor_img = bpy.data.images.new("hand_nor", TEX, TEX)
    nor_img.colorspace_settings.name = 'Non-Color'
    tmp = bpy.data.materials.new("Bake")
    tmp.use_nodes = True
    low.data.materials.append(tmp)
    _bake(high, low, col_img, "EMIT")
    _bake(high, low, nor_img, "NORMAL")
    # pores: fine height noise folded into the baked normals
    n = np.array(nor_img.pixels[:]).reshape(TEX, TEX, 4)
    pores = tex.fbm(TEX, TEX, 420, 420, 77, 1)
    f1, _f2 = tex.cellular(TEX, TEX, 260, 260, 78)
    h = pores * 0.5 - np.exp(-(f1 / 0.22) ** 2) * 0.6     # tiny pits
    gy, gx = np.gradient(h)
    k = 0.16
    n[..., 0] = np.clip(n[..., 0] - gx * k, 0, 1)
    n[..., 1] = np.clip(n[..., 1] + gy * k, 0, 1)
    nor_img.pixels[:] = n.ravel()
    low.data.materials.clear()
    skin = scene.material("Skin", base_tex=col_img, normal_tex=nor_img, normal_strength=1.0, roughness=0.55)
    low.data.materials.append(skin)
    for img, fname in ((col_img, "fp_hand_col.png"), (nor_img, "fp_hand_nor.png")):
        img.filepath_raw = os.path.join(os.path.dirname(out_path), fname)
        img.file_format = 'PNG'

    nails = _nails(high)
    nails.data.materials.append(scene.material("Nail", base_tex=_nail_texture(), roughness=0.28))
    bpy.data.objects.remove(high)

    arm = _rig()
    # weights: automatic (bone heat); the nails ride their fingertip bone
    for o in bpy.context.view_layer.objects:
        o.select_set(o in (low, arm))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    nails.parent = arm
    mod = nails.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    scene.export_glb(out_path, [arm, low, nails])
    return arm, low, nails


def preview(out_dir, arm):
    """Rest pose and a loose fist, from where the player sees it and from the side."""
    from dp import preview as pv
    views = [("top", (0.05, -0.1, 0.22), (0, 0.06, 0), 50), ("palm", (0.02, 0.05, -0.25), (0, 0.06, 0), 50),
             ("side", (-0.25, 0.06, 0.05), (0, 0.06, 0), 50)]
    pv.render_views(out_dir, "hand_rest", views, res=(800, 600), samples=32)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        if "_" in pb.name:
            j = int(pb.name[-1])
            amt = {1: 55, 2: 70, 3: 45}[j] if not pb.name.startswith("thumb") else {1: 10, 2: 30, 3: 40}[j]
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = (math.radians(-amt), 0, 0)
    bpy.ops.object.mode_set(mode='OBJECT')
    pv.render_views(out_dir, "hand_fist", views[:1] + views[2:], res=(800, 600), samples=32)
