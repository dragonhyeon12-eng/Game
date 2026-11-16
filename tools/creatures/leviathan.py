"""THE DEEP's leviathan: one continuous skinned mesh, built to drive with the game's segment chain.

Rig contract with scripts/npc/leviathan.gd (keep in sync):
  - bones "spine_00" .. "spine_33", unparented, one per body segment; spine_i rests at Godot z = i * 2.4
    (Blender y = -i * 2.4), head segment at the origin, the creature facing Godot -Z (Blender +Y);
  - bone "jaw", child of spine_00, hinge at the back of the mouth; rotating it about its X axis opens it;
  - built at thickness 1.0 (the game scales each bone by its `thickness`).

Anatomy: angular skull (brow shelf, cheek flare, sagittal crest, sunken eye sockets), hinged lower jaw
with dark irregular teeth, two pairs of ridged horns, a narrow neck with gill slits, a deep-keeled front
torso wrapped in ribs with bony pectoral fins and irregular dorsal spines (some broken), a long taper
into a laterally flattened tail with a serrated crest above and below, and a crescent tail fin.
"""
import math
import random

import numpy as np
from mathutils import Vector

from dp import geo, scene, tex
from dp.geo import MeshBuilder, smoothstep, gauss, ang_diff, bezier, catmull

SEGMENTS = 34
SPACING = 2.4
L = (SEGMENTS - 1) * SPACING
BODY_START = -1.0
BODY_END = L + 0.6
PROFILE = [(0.0, 2.2), (0.05, 3.1), (0.14, 5.9), (0.26, 5.5), (0.42, 4.1), (0.6, 2.5), (0.78, 1.25), (1.0, 0.35)]

GLOW = (0.25, 0.78, 1.0)


def diameter(u):
    for (u0, d0), (u1, d1) in zip(PROFILE, PROFILE[1:]):
        if u <= u1:
            return d0 + (d1 - d0) * smoothstep(0.0, 1.0, (u - u0) / (u1 - u0))
    return PROFILE[-1][1]


def body_shape(s):
    u = min(max(s / L, 0.0), 1.0)
    d = diameter(u)
    ys = 1.18 + (0.95 - 1.18) * smoothstep(0.2, 0.7, u)
    xs = 1.0 + (0.62 - 1.0) * smoothstep(0.55, 0.9, u)
    if s > L:                       # close the tail to a point
        d *= max(0.05, 1.0 - (s - L) / (BODY_END - L))
    return u, d, d * xs * 0.5, d * ys * 0.5


def spine_weights(s):
    f = min(max(s / SPACING, 0.0), SEGMENTS - 1.0)
    i0 = min(int(f), SEGMENTS - 2)
    t = smoothstep(0.0, 1.0, f - i0)
    return [(f"spine_{i0:02d}", 1.0 - t), (f"spine_{i0 + 1:02d}", t)]


def bone_of(s):
    return f"spine_{min(max(int(round(s / SPACING)), 0), SEGMENTS - 1):02d}"


def superellipse(theta, a, b, p):
    c, s = math.cos(theta), math.sin(theta)
    return (a * math.copysign(abs(c) ** (2 / p), c), b * math.copysign(abs(s) ** (2 / p), s))


def body_point(s, theta, displaced=True):
    u, d, a, b = body_shape(s)
    x, z = superellipse(theta, a, b, 2.4)
    nrm = Vector((math.cos(theta), 0, math.sin(theta)))
    torso = smoothstep(0.03, 0.08, u) * (1.0 - smoothstep(0.45, 0.6, u))
    off = 0.0
    off += d * (0.085 - 0.04 * u) * gauss(ang_diff(theta, math.pi / 2), 0.16)               # dorsal ridge
    off += d * 0.11 * gauss(ang_diff(theta, -math.pi / 2), 0.45) * (1 - smoothstep(0.3, 0.6, u))   # keel
    if 0.04 < u < 0.92:
        off -= d * 0.025 * (gauss(ang_diff(theta, 0), 0.07) + gauss(ang_diff(theta, math.pi), 0.07))  # lateral groove
    band = 1.0 + 0.035 * torso * math.sin(s / SPACING * math.tau + 0.6)                     # muscle bands
    p = Vector((x * band, -s, z * band))
    if displaced:
        q = Vector((p.x * 0.3, p.y * 0.3, p.z * 0.3))
        off += d * (0.05 * geo.fbm(q, 3) + 0.012 * geo.fbm(q * 5.0, 2))
    return p + nrm * off


# ------------------------------------------------------------------ skull

SKULL = [  # (y, width, height, centre z) - Blender metres, back of skull to snout tip
    (-1.125, 2.5, 2.125, 0.625), (0.0, 3.625, 2.625, 0.75), (1.375, 3.25, 2.25, 0.75),
    (2.875, 2.25, 1.55, 0.375), (4.25, 1.55, 1.1, 0.125), (5.125, 0.85, 0.65, 0.0)]
JAW = [(-0.9, 2.9, 1.35, -0.6), (0.6, 2.7, 1.25, -0.95), (2.2, 2.05, 0.95, -1.0), (3.6, 1.4, 0.8, -0.9),
       (4.8, 0.8, 0.6, -0.65)]
EYES = [Vector((1.25, 2.3, 1.0)), Vector((-1.25, 2.3, 1.0))]


def section(table, t):
    cols = list(zip(*table))
    return [catmull(list(c), t) for c in cols]


def skull_point(t, theta):
    y, w, h, zc = section(SKULL, t)
    a, b = w / 2, h / 2
    x, z = superellipse(theta, a, b, 2.6 + 0.8 * smoothstep(2.0, 4.5, y))   # boxier towards the snout
    nrm = Vector((math.cos(theta), 0, math.sin(theta)))
    off = 0.0
    off += 0.32 * gauss(ang_diff(theta, math.pi / 2), 0.1) * (1 - smoothstep(2.5, 4.5, y))           # sagittal crest
    off += 0.4 * gauss(ang_diff(theta, math.pi / 2), 0.55) * gauss(y + 0.5, 0.7)                    # occipital shelf
    for th in (0.95, math.pi - 0.95):
        off += 0.48 * gauss(ang_diff(theta, th), 0.2) * gauss(y - 2.0, 1.1)                         # brow shelf
    for th in (-0.15, math.pi + 0.15):
        off += 0.55 * gauss(ang_diff(theta, th), 0.28) * gauss(y - 0.5, 1.0)                         # cheek flare
    for th in (0.4, math.pi - 0.4):
        off += 0.12 * gauss(ang_diff(theta, th), 0.08) * smoothstep(2.5, 4.0, y)                      # snout ridges
    p = Vector((x, y, zc + z)) + nrm * off
    floor = zc - b * 0.7                                                                          # flat palate
    if p.z < floor:
        p.z = floor - (floor - p.z) * 0.15
    p += nrm * 0.06 * geo.fbm(p * 0.8, 3)
    for e in EYES:                                                                                # eye sockets
        dist = (p - e).length
        if dist < 1.0:
            p -= (p - Vector((0, p.y, zc))).normalized() * 0.32 * gauss(dist, 0.42)
    return p


def jaw_point(t, theta):
    y, w, h, zc = section(JAW, t)
    x, z = superellipse(theta, w / 2, h / 2, 2.2)
    p = Vector((x, y, zc + z))
    top = zc + h / 2 * 0.3
    if p.z > top:
        p.z = top + (p.z - top) * 0.1
    return p + Vector((math.cos(theta), 0, math.sin(theta))) * 0.04 * geo.fbm(p * 0.9, 2)


def table_at_y(table, y):
    ys = [r[0] for r in table]
    return [float(np.interp(y, ys, [r[i] for r in table])) for i in range(4)]


# ------------------------------------------------------------------ textures

def make_textures(rng_seed=7):
    T = {}
    # ---- hide: U around the body (0 = right flank, .25 top, .5 left, .75 belly), V head -> tail
    W, H = 256, 2048
    u = (np.arange(W) + 0.5) / W
    v = 1.0 - (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(u, v)
    s = BODY_START + V * (BODY_END - BODY_START)
    mott = tex.fbm(W, H, 8, 64, rng_seed)
    f1, f2 = tex.cellular(W, H, 48, 300, rng_seed + 1)
    edge = np.clip((f2 - f1) * 3.0, 0, 1)
    top = np.cos((U - 0.25) * math.tau) * 0.5 + 0.5           # 1 on the back
    belly = np.cos((U - 0.75) * math.tau) * 0.5 + 0.5
    lum = 0.045 + 0.03 * mott - 0.015 * top + 0.012 * belly - 0.02 * (1 - edge)
    alb = np.stack([lum * 0.9, lum * 1.0, lum * 1.12], axis=-1)
    T["hide_albedo"] = tex.to_image("lev_hide_albedo", alb)
    wrinkle = tex.fbm(W, H, 16, 256, rng_seed + 2, octaves=3)
    bands = np.sin(s / SPACING * math.tau + 0.6) * 0.5
    height = edge * 0.6 + wrinkle * 0.5 + bands * 0.3
    T["hide_normal"] = tex.to_image("lev_hide_normal", tex.normal_from_height(height, 2.5), non_color=True)
    em = np.zeros((H, W))
    # lateral lines: a dotted row along both flanks, every 0.8 m, from the neck to the tail
    for uc in (0.0, 0.5):
        du = np.minimum(np.abs(U - uc), 1 - np.abs(U - uc)) * 12.0       # metres around (approx.)
        ds = (s % 0.8) - 0.4
        on = (s > 2.0) & (s < L * 0.92)
        em += on * np.exp(-((du / 0.07) ** 2 + (ds / 0.07) ** 2)) * np.where((s // 0.8) % 3 == 0, 1.0, 0.55)
    # gill slits: three short glowing bars on each side of the neck
    for sg in (0.9, 1.5, 2.1):
        for uc in (0.0, 0.5):
            du = np.minimum(np.abs(U - uc), 1 - np.abs(U - uc))
            em += np.exp(-((s - sg) / 0.06) ** 2) * (du < 0.07) * 0.9
    # a sparse row of photophores under the throat and chest
    du = np.abs(U - 0.75)
    ph = (s > 1.0) & (s < L * 0.35)
    em += ph * np.exp(-((du * 12 / 0.06) ** 2 + (((s % 1.6) - 0.8) / 0.06) ** 2)) * 0.7
    em = np.clip(em, 0, 1)
    T["hide_emission"] = tex.to_image("lev_hide_emission", np.stack([em * GLOW[0], em * GLOW[1], em * GLOW[2]], axis=-1))

    # ---- skull: U around (same convention), V back of skull -> snout tip
    W, H = 512, 256
    u = (np.arange(W) + 0.5) / W
    v = 1.0 - (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(u, v)
    f1, f2 = tex.cellular(W, H, 14, 7, rng_seed + 5)
    plates = np.clip((f2 - f1) * 2.5, 0, 1)
    mott = tex.fbm(W, H, 6, 3, rng_seed + 6)
    lum = 0.05 + 0.025 * mott - 0.02 * (1 - plates)
    T["skull_albedo"] = tex.to_image("lev_skull_albedo", np.stack([lum * 0.95, lum, lum * 1.08], axis=-1))
    height = plates * 0.8 + tex.fbm(W, H, 24, 12, rng_seed + 7, 3) * 0.4
    T["skull_normal"] = tex.to_image("lev_skull_normal", tex.normal_from_height(height, 2.5), non_color=True)
    em = np.zeros((H, W))
    for uc in (0.95 / math.tau, (math.pi - 0.95) / math.tau):           # along each brow
        em += np.exp(-((U - uc) / 0.006) ** 2) * ((V > 0.32) & (V < 0.72))
    for uc in (0.08 / math.tau, (math.pi - 0.08) / math.tau):           # along the snout
        em += 0.6 * np.exp(-((U - uc) / 0.005) ** 2) * ((V > 0.5) & (V < 0.95))
    for vc in (0.18, 0.28, 0.38):                                         # crown
        em += np.exp(-(((U - 0.25) / 0.008) ** 2 + ((V - vc) / 0.02) ** 2)) * 0.8
    em = np.clip(em, 0, 1)
    T["skull_emission"] = tex.to_image("lev_skull_emission", np.stack([em * GLOW[0], em * GLOW[1], em * GLOW[2]], axis=-1))

    # ---- bone (horns, spines, ribs, teeth): tiling, streaked along V
    W = H = 256
    streak = tex.fbm(W, H, 24, 3, rng_seed + 8, 3, tile_x=True)
    grain = tex.fbm(W, H, 32, 32, rng_seed + 9, 2)
    lum = 0.085 + 0.04 * streak + 0.015 * grain
    T["bone_albedo"] = tex.to_image("lev_bone_albedo", np.stack([lum * 1.05, lum * 0.98, lum * 0.88], axis=-1))
    T["bone_normal"] = tex.to_image("lev_bone_normal", tex.normal_from_height(streak * 0.8 + grain * 0.3, 2.0), non_color=True)

    # ---- membrane (fins, crests): dark webbing with faint veins
    veins = np.abs(np.sin(tex.fbm(W, H, 4, 4, rng_seed + 10) * 40.0))
    lum = 0.03 + 0.02 * (1 - np.clip(veins * 3, 0, 1)) + 0.01 * grain
    T["membrane_albedo"] = tex.to_image("lev_membrane_albedo", np.stack([lum * 0.9, lum, lum * 1.15], axis=-1))
    T["membrane_normal"] = tex.to_image("lev_membrane_normal", tex.normal_from_height(1 - np.clip(veins * 3, 0, 1), 2.0), non_color=True)
    return T


def make_materials(T):
    M = {}
    M["hide"] = scene.material("lev_hide", T["hide_albedo"], normal_tex=T["hide_normal"], normal_strength=0.8,
                               emission_tex=T["hide_emission"], emission_strength=2.5, roughness=0.38)
    M["skull"] = scene.material("lev_skull", T["skull_albedo"], normal_tex=T["skull_normal"], normal_strength=1.0,
                                emission_tex=T["skull_emission"], emission_strength=2.5, roughness=0.45)
    M["jaw"] = scene.material("lev_jaw", T["skull_albedo"], normal_tex=T["skull_normal"], roughness=0.45)
    M["bone"] = scene.material("lev_bone", T["bone_albedo"], normal_tex=T["bone_normal"], roughness=0.62)
    M["membrane"] = scene.material("lev_membrane", T["membrane_albedo"], normal_tex=T["membrane_normal"],
                                   roughness=0.55, double_sided=True)
    M["glow"] = scene.material("lev_glow", base_color=(0.0, 0.0, 0.0), emission_color=(0.12, 0.55, 0.85), emission_strength=1.6,
                               roughness=0.4)
    M["eye"] = scene.material("lev_eye", base_color=(0.0, 0.0, 0.0), emission_color=(0.1, 0.55, 0.85),
                              emission_strength=1.4, roughness=0.1)
    return M


# ------------------------------------------------------------------ build

def build(out_path):
    random.seed(11)
    scene.reset()
    mb = MeshBuilder()
    head = [("spine_00", 1.0)]
    jawW = [("jaw", 1.0)]

    # ---- body
    N = 28
    rings = []
    ss = []
    s = BODY_START
    while s <= BODY_END + 1e-6:
        rings.append([body_point(s, k / N * math.tau) for k in range(N)])
        ss.append(s)
        s += 0.4
    vs = [(x - BODY_START) / (BODY_END - BODY_START) for x in ss]
    mb.loft(rings, "hide", lambda ri, p: spine_weights(ss[ri]), uv_v=vs, cap_start=True, cap_end=True)

    # ---- skull and jaw
    NS = 36
    rings = [[skull_point(i / 43, k / NS * math.tau) for k in range(NS)] for i in range(44)]
    mb.loft(rings, "skull", lambda ri, p: head, cap_start=True, cap_end=True)
    rings = [[jaw_point(i / 29, k / 24 * math.tau) for k in range(24)] for i in range(30)]
    mb.loft(rings, "jaw", lambda ri, p: jawW, cap_start=True, cap_end=True)
    # eyes: small spheres deep in the sockets
    for e in EYES:
        sph = []
        for i in range(9):
            phi = i / 8 * math.pi
            sph.append([e + Vector((math.sin(phi) * math.cos(k / 12 * math.tau), math.sin(phi) * math.sin(k / 12 * math.tau),
                                    math.cos(phi))) * 0.13 for k in range(12)])
        mb.loft(sph, "eye", lambda ri, p: head)
    # teeth: dark, irregular, curving back into the mouth
    for side in (1, -1):
        for i in range(10):
            y = 1.0 + i * 0.42 + random.uniform(-0.1, 0.1)
            _, w, h, zc = table_at_y(SKULL, y)
            base = Vector((side * w / 2 * 0.72, y, zc - h / 2 * 0.7 + 0.05))
            ln = random.uniform(0.3, 0.75) * (1.0 - 0.3 * i / 10)
            path = bezier(base, base + Vector((0, 0, -ln * 0.5)), base + Vector((-side * 0.05, -ln * 0.25, -ln * 0.9)),
                          base + Vector((-side * 0.08, -ln * 0.35, -ln)), 5)
            r0 = random.uniform(0.07, 0.12)
            mb.tube(path, [r0 * (1 - j / 5) ** 1.3 + 0.006 for j in range(6)], 6, "bone", head)
        for i in range(8):
            y = 0.9 + i * 0.48 + random.uniform(-0.1, 0.1)
            _, w, h, zc = table_at_y(JAW, y)
            base = Vector((side * w / 2 * 0.7, y, zc + h / 2 * 0.3 - 0.05))
            ln = random.uniform(0.28, 0.6)
            path = bezier(base, base + Vector((0, 0, ln * 0.5)), base + Vector((-side * 0.04, -ln * 0.2, ln * 0.9)),
                          base + Vector((-side * 0.06, -ln * 0.3, ln)), 5)
            r0 = random.uniform(0.06, 0.1)
            mb.tube(path, [r0 * (1 - j / 5) ** 1.3 + 0.006 for j in range(6)], 6, "bone", jawW)
        # glowing seam along the jaw line
        pts = []
        for i in range(12):
            y = -0.4 + i * 0.42
            _, w, h, zc = table_at_y(JAW, y)
            pts.append(Vector((side * w / 2 * 1.0, y, zc - h * 0.12)))
        mb.tube(pts, [0.022] * len(pts), 5, "glow", jawW)

    # ---- horns: two ridged pairs sweeping back, and cheek spurs
    for side in (1, -1):
        for base, c1, c2, tip, r0 in (
                ((1.05, -0.125, 1.5), (0.6, -0.6, 0.9), (0.4, 1.2, 0.3), (2.375, -4.375, 2.625), 0.4),
                ((1.5, -0.375, 0.375), (0.8, -0.3, 0.3), (0.2, 1.0, 0.6), (3.25, -3.375, -0.125), 0.3),
                ((1.45, 1.75, 0.3), (0.3, -0.4, 0.0), (0.0, 0.5, 0.1), (2.05, -0.3, 0.1), 0.24)):
            b = Vector((base[0] * side, base[1], base[2]))
            t = Vector((tip[0] * side, tip[1], tip[2]))
            path = bezier(b, b + Vector((c1[0] * side, c1[1], c1[2])), t + Vector((c2[0] * side, c2[1], c2[2])), t, 22)
            radii = [r0 * (1 - j / 22) ** 1.1 + 0.012 for j in range(23)]
            mb.tube(path, radii, 10, "bone", head, ridges=0.08, ridge_freq=9.0, twist_noise=0.08, seed=side)
        # small spikes along the brow
        for k in range(3):
            b = Vector((side * (1.25 - k * 0.12), 1.3 + k * 0.55, 1.75 - k * 0.12))
            t = b + Vector((side * 0.25, -0.55, 0.35))
            mb.tube(bezier(b, b + Vector((0, 0, 0.2)), t - Vector((0, -0.1, 0.05)), t, 5),
                    [0.09 * (1 - j / 5) + 0.008 for j in range(6)], 6, "bone", head)

    # ---- dorsal spines: tall and irregular over the torso, some broken
    for i in range(1, SEGMENTS):
        sp = i * SPACING + random.uniform(-0.4, 0.4)
        u, d, a, b = body_shape(sp)
        if not (0.04 < u < 0.62):
            continue
        h = d * (0.95 + (0.35 - 0.95) * smoothstep(0.1, 0.62, u)) * random.uniform(0.6, 1.3)
        broken = random.random() < 0.2
        if broken:
            h *= 0.45
        lean = math.radians(random.uniform(28, 48))
        base = body_point(sp, math.pi / 2, False) - Vector((0, 0, 0.15 * d))
        rx = random.uniform(-0.12, 0.12) * h
        tip = base + Vector((rx, -math.sin(lean) * h, math.cos(lean) * h))
        path = bezier(base, base + Vector((0, 0, h * 0.45)), tip + Vector((0, h * 0.15, -h * 0.1)), tip, 10)
        r0 = 0.14 + d * 0.04
        rt = r0 * (0.45 if broken else 0.05)
        radii = [r0 + (rt - r0) * (j / 10) ** 0.8 for j in range(11)]
        mb.tube(path, radii, 8, "bone", [(bone_of(sp), 1.0)], ridges=0.06, ridge_freq=6.0, twist_noise=0.12 if broken else 0.05,
                seed=i)
        # shoulder spurs
        if 0.06 < u < 0.36 and i % 2 == 1:
            for side in (1, -1):
                b0 = body_point(sp, math.pi / 2 - side * 0.75, False)
                t0 = b0 + Vector((0.45 * side, -0.9, 0.55)) * d * random.uniform(0.25, 0.42)
                mb.tube(bezier(b0, b0 + (t0 - b0) * 0.3 + Vector((0, 0, 0.2)), t0 - (t0 - b0) * 0.2, t0, 6),
                        [(0.08 + d * 0.025) * (1 - j / 6) + 0.01 for j in range(7)], 6, "bone", [(bone_of(sp), 1.0)])

    # ---- ribs: arcs around the torso, just proud of the hide; every other one carries a glowing seam
    for i in range(1, SEGMENTS):
        sp = i * SPACING + 0.5
        u, d, a, b = body_shape(sp)
        if not (0.07 < u < 0.44):
            continue
        for side in (1, -1):
            pts = []
            for j in range(15):
                th = 1.2 - j / 14 * 2.15
                th = th if side == 1 else math.pi - th
                p = body_point(sp + j * 0.03, th, False)
                pts.append(p + Vector((math.cos(th), 0, math.sin(th))) * (0.06 + 0.02 * d))
            mb.tube(pts, [0.07 + 0.02 * d] * len(pts), 6, "bone", [(bone_of(sp), 1.0)], cap_start=True)
            if i % 2 == 0:
                glow = [p + Vector((math.cos(th), 0, math.sin(th))) * 0.07 for p, th in
                        zip(pts[3:12], [1.2 - j / 14 * 2.15 if side == 1 else math.pi - (1.2 - j / 14 * 2.15) for j in range(3, 12)])]
                mb.tube(glow, [0.03] * len(glow), 5, "glow", [(bone_of(sp), 1.0)])

    # ---- pectoral fins: bony rays with scalloped webbing between them
    fs = 3 * SPACING
    u, d, a, b = body_shape(fs)
    for side in (1, -1):
        root = Vector((side * a * 0.85, -fs, -d * 0.22))
        dirs = [(0.9, -0.75, -0.35), (1.0, -0.4, -0.62), (0.75, -0.15, -0.85), (0.45, -0.55, -0.95)]
        lens = [1.55, 1.35, 1.1, 0.95]
        rays = []
        for (dx, dy, dz), ln in zip(dirs, lens):
            tip = root + Vector((dx * side, dy, dz)).normalized() * d * ln
            ray = bezier(root, root + (tip - root) * 0.35 + Vector((0, 0, 0.25)), root + (tip - root) * 0.75 + Vector((0, 0.2, 0.1)), tip, 12)
            rays.append(ray)
            mb.tube(ray, [0.16 * (1 - j / 12) ** 0.7 + 0.02 for j in range(13)], 7, "bone", [("spine_03", 1.0)])
        for ra, rb in zip(rays, rays[1:]):
            cols = []
            for f in (0.0, 0.25, 0.5, 0.75, 1.0):
                col = []
                for j in range(13):
                    tj = j / 12 * (1.0 - 0.2 * math.sin(math.pi * f))     # scalloped trailing edge
                    k = tj * 12
                    k0 = min(int(k), 11)
                    fr = k - k0
                    pa = ra[k0].lerp(ra[k0 + 1], fr)
                    pb = rb[k0].lerp(rb[k0 + 1], fr)
                    col.append(pa.lerp(pb, f) + Vector((0, 0, -0.12 * math.sin(math.pi * f) * tj)))
                cols.append(col)
            mb.strip(cols, "membrane", lambda ri, p: [("spine_03", 1.0)])
        mb.tube(rays[0][3:], [0.04] * len(rays[0][3:]), 5, "glow", [("spine_03", 1.0)])

    # ---- tail crests (serrated) and the crescent tail fin
    for sign, start, depth in ((1, 0.58, 1.0), (-1, 0.64, 0.55)):
        cols = []
        csv = []
        sp = start * L
        while sp <= L + 0.2:
            u, d, a, b = body_shape(sp)
            crest = d * (0.6 + 0.5 * smoothstep(0.6, 0.95, u)) * depth
            saw = (sp / SPACING) % 1.0
            hgt = crest * (0.55 + 0.45 * saw)
            base = body_point(sp, sign * math.pi / 2, False) - Vector((0, 0, sign * 0.1 * d))
            tip = base + Vector((0, -0.25 * hgt, sign * hgt))
            cols.append([base, base.lerp(tip, 0.5) + Vector((0.03, 0, 0)), tip])
            csv.append(sp)
            sp += 0.5
        mb.strip(cols, "membrane", lambda ri, p, csv=csv: spine_weights(csv[ri]))
    root = Vector((0, -L - 0.2, 0))
    outline = [(0.2, 0.5), (1.2, 2.2), (2.6, 3.9), (3.7, 4.7), (3.1, 3.4), (2.4, 1.6), (1.9, 0.0), (2.3, -1.2),
               (2.9, -2.4), (3.4, -3.1), (2.5, -2.4), (1.2, -1.4), (0.2, -0.4)]
    pts = [root + Vector((0, -oy, oz)) for oy, oz in outline]
    mb.fan(root + Vector((0, -0.6, 0)), pts, "membrane", [("spine_33", 1.0)])
    for a_, b_ in ((0, 3), (9, 12)):
        lead = pts[a_:b_ + 1]
        mb.tube(lead, [0.09 * (1 - j / len(lead)) + 0.02 for j in range(len(lead))], 6, "bone", [("spine_33", 1.0)])
    trail = pts[3:10]
    mb.tube(trail, [0.035] * len(trail), 5, "glow", [("spine_33", 1.0)])

    # ---- assemble, rig, export
    T = make_textures()
    M = make_materials(T)
    bones = [(f"spine_{i:02d}", (0, -i * SPACING, 0), (0, -i * SPACING - 1.0, 0), None) for i in range(SEGMENTS)]
    bones.append(("jaw", (0, -0.6, -0.3), (0, 1.0, -0.6), "spine_00"))
    arm = scene.armature("LeviathanRig", bones)
    obj = mb.to_object("Leviathan", M, arm)
    print(f"  leviathan: {len(mb.verts)} vertices, {mb.tri_count()} triangles")
    scene.export_glb(out_path, [arm, obj])
