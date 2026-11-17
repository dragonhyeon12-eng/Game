"""The dreamer: the player's own body. Rigged, for first-person legs and shadow now and mirrors later.

A realistically proportioned adult, 1.74 m, dressed for 3 AM: a charcoal T-shirt, navy plaid pyjama
trousers, bare feet. Built from a stick skeleton through the Skin modifier, subdivided, given cloth
creases and decimated; skinned to a simple armature with weights computed from bone distance (only
between a bone and its parent or child, so nothing leaks between limbs). Rest pose: A-pose (arms 50
degrees from vertical) so the hands are well clear of the hips.

Rig contract with scripts/player/body.gd (keep in sync):
  bones hips, spine, chest, neck, head, upperarm.L/R, forearm.L/R, hand.L/R, thigh.L/R, shin.L/R, foot.L/R
  (.L = the character's left = Godot -X); feet on y = 0; facing Godot -Z (Blender +Y).
Three meshes so the game can hide some parts from its own first-person camera:
  PlayerBody (torso, legs, feet), PlayerArms (arms, hands), PlayerHead (neck, head, hair).
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

from dp import geo, scene, tex

ARM_DEG = 50.0


STALKER = False   # set by build_stalker(): the Backrooms entity shares this rig with a different body


def _skeleton():
    pts = {}
    edges = []
    zs = 1.33 if STALKER else 1.0
    rs = 0.7 if STALKER else 1.0

    def p(n, xyz, r):
        x, y, z = xyz
        pts[n] = (Vector((x, y, z * zs)), r * rs)

    def _un(v):
        return Vector((v.x, v.y, v.z / zs))

    p("pelvis", (0, 0.0, 0.97), 0.135)
    p("waist", (0, 0.005, 1.12), 0.12)
    p("chest", (0, 0.015, 1.31), 0.15)
    p("upper", (0, 0.0, 1.45), 0.13)
    p("neck", (0, 0.01, 1.54), 0.052)
    p("head", (0, 0.02, 1.63), 0.105)
    p("crown", (0, -0.005, 1.715), 0.092)
    p("chin", (0, 0.07, 1.575), 0.05)
    for a, b in (("pelvis", "waist"), ("waist", "chest"), ("chest", "upper"), ("upper", "neck"), ("neck", "head"),
                 ("head", "crown"), ("head", "chin")):
        edges.append((a, b))
    a = math.radians(ARM_DEG)
    for side, s in ((-1, "L"), (1, "R")):
        sh = Vector((side * 0.195, 0.0, 1.455))
        d = Vector((math.sin(a) * side, 0.0, -math.cos(a)))
        arm = 1.55 if STALKER else 1.0
        sh = Vector((sh.x, sh.y, sh.z * (1.33 if STALKER else 1.0))) / (1.33 if STALKER else 1.0)
        p("sh" + s, sh, 0.064)
        p("elb" + s, sh + d * 0.29 * arm, 0.046)
        p("wri" + s, sh + d * 0.55 * arm, 0.032)
        p("pal" + s, sh + d * 0.62 * arm, 0.036)
        for a2, b2 in (("upper", "sh" + s), ("sh" + s, "elb" + s), ("elb" + s, "wri" + s), ("wri" + s, "pal" + s)):
            edges.append((a2, b2))
        fwd = Vector((0, 1, 0))
        for f in range(4):
            spread = (f - 1.5) * 0.019
            ln = (0.075, 0.085, 0.08, 0.065)[f] * (2.3 if STALKER else 1.0)
            base = _un(pts["pal" + s][0]) + fwd * spread
            k1, k2 = f"k{f}{s}", f"t{f}{s}"
            p(k1, base + d * 0.03, 0.0115)
            p(k2, base + d * (0.03 + ln), 0.009)
            edges.append(("pal" + s, k1))
            edges.append((k1, k2))
        base = _un(pts["pal" + s][0])
        p("th1" + s, base + fwd * 0.035 + d * -0.01, 0.012)
        p("th2" + s, base + fwd * 0.07 + d * 0.03, 0.009)
        edges.append(("pal" + s, "th1" + s))
        edges.append(("th1" + s, "th2" + s))
        p("hip" + s, (side * 0.1, 0.0, 0.91), 0.085)
        p("knee" + s, (side * 0.1, 0.012, 0.5), 0.056)
        p("ank" + s, (side * 0.1, -0.01, 0.085), 0.04)
        p("heel" + s, (side * 0.1, -0.045, 0.035), 0.035)
        p("ball" + s, (side * 0.105, 0.13, 0.025), 0.038)
        p("toe" + s, (side * 0.108, 0.19, 0.022), 0.03)
        for a2, b2 in (("pelvis", "hip" + s), ("hip" + s, "knee" + s), ("knee" + s, "ank" + s), ("ank" + s, "heel" + s),
                       ("ank" + s, "ball" + s), ("ball" + s, "toe" + s)):
            edges.append((a2, b2))
    return pts, edges


def _bones(pts):
    P = lambda n: tuple(pts[n][0])  # noqa: E731
    b = [
        ("hips", P("pelvis"), P("waist"), None),
        ("spine", P("waist"), P("chest"), "hips"),
        ("chest", P("chest"), P("upper"), "spine"),
        ("neck", P("upper"), P("neck"), "chest"),
        ("head", P("neck"), P("crown"), "neck"),
    ]
    for s in ("L", "R"):
        b += [
            ("upperarm." + s, P("sh" + s), P("elb" + s), "chest"),
            ("forearm." + s, P("elb" + s), P("wri" + s), "upperarm." + s),
            ("hand." + s, P("wri" + s), tuple(pts["pal" + s][0] + (pts["pal" + s][0] - pts["wri" + s][0]) * 2.0), "forearm." + s),
            ("thigh." + s, P("hip" + s), P("knee" + s), "hips"),
            ("shin." + s, P("knee" + s), P("ank" + s), "thigh." + s),
            ("foot." + s, P("ank" + s), P("toe" + s), "shin." + s),
        ]
    return b


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length, t


def _textures():
    W = H = 256
    T = {}
    n1 = tex.fbm(W, H, 8, 8, 21)
    n2 = tex.fbm(W, H, 32, 32, 22, 2)
    # skin: warm, slightly uneven
    skin = np.stack([0.80 + 0.04 * n1, 0.62 + 0.04 * n1, 0.52 + 0.04 * n1], axis=-1) * (0.96 + 0.06 * n2[..., None])
    T["skin"] = tex.to_image("player_skin", skin)
    T["skin_n"] = tex.to_image("player_skin_n", tex.normal_from_height(n2 * 0.3, 1.0), non_color=True)
    # shirt: charcoal jersey knit
    knit = (np.sin(np.arange(W) * math.tau / 4)[None, :] * 0.5 + 0.5) * (np.sin(np.arange(H) * math.tau / 6)[:, None] * 0.25 + 0.75)
    shirt = np.stack([0.17, 0.18, 0.19], axis=0)[None, None, :] * (0.9 + 0.12 * knit[..., None]) * (0.92 + 0.12 * n1[..., None])
    T["shirt"] = tex.to_image("player_shirt", shirt)
    T["shirt_n"] = tex.to_image("player_shirt_n", tex.normal_from_height(knit * 0.15 + n1 * 0.4, 1.2), non_color=True)
    # pyjama trousers: navy plaid
    x = np.arange(W)[None, :] / W
    y = np.arange(H)[:, None] / H
    stripe = lambda c, w: (np.abs(((c * 4) % 1.0) - 0.5) < w).astype(float)  # noqa: E731
    plaid = 0.55 * stripe(x, 0.08) + 0.55 * stripe(y, 0.08) + 0.25 * stripe(x * 2 + 0.25, 0.03) + 0.25 * stripe(y * 2 + 0.25, 0.03)
    base = np.array([0.11, 0.14, 0.27])
    pants = base[None, None, :] * (1.0 + 0.45 * np.clip(plaid, 0, 1.2)[..., None]) * (0.92 + 0.12 * n1[..., None])
    pants[..., 0] += 0.06 * stripe(x * 2 + 0.25, 0.015)   # a thin red line
    T["pants"] = tex.to_image("player_pants", pants)
    T["pants_n"] = tex.to_image("player_pants_n", tex.normal_from_height(n1 * 0.5 + plaid * 0.05, 1.2), non_color=True)
    # hair: dark brown strands
    strands = tex.fbm(W, H, 64, 4, 23, 3)
    hair = np.stack([0.09, 0.06, 0.045], axis=0)[None, None, :] * (0.7 + 0.6 * strands[..., None])
    T["hair"] = tex.to_image("player_hair", hair)
    T["hair_n"] = tex.to_image("player_hair_n", tex.normal_from_height(strands, 2.0), non_color=True)
    return T


def build_stalker(out_path):
    """THE BACKROOMS' entity: the same rig, a body that is wrong - too tall, too thin, arms past the
    knees, fingers twice as long, a small head. Grey-white skin with dark veins. No clothes, no face."""
    global STALKER
    STALKER = True
    try:
        build(out_path, stalker=True)
    finally:
        STALKER = False


def build(out_path, stalker=False):
    scene.reset()
    pts, edges = _skeleton()
    body = scene.skin_body("PlayerSkin", pts, edges, "pelvis", flat=("chest", "upper", "pelvis", "waist"))
    # cloth creases and a little irregularity, then lighter
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.normal_update()
    for v in bm.verts:
        co = v.co
        d = 0.002 * geo.fbm(co * 18.0, 2)
        if not STALKER and co.z < 0.95 and co.z > 0.1:   # trouser folds, mostly around the knees and ankles
            d += 0.004 * math.sin(co.z * 70.0 + geo.fbm(co * 4.0, 2) * 3.0) * (0.5 + 0.5 * math.cos((co.z - 0.5) * 6))
        v.co = co + v.normal * d
    bm.to_mesh(body.data)
    bm.free()
    dec = body.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = 0.55
    scene.apply_modifiers(body)

    bones = _bones(pts)
    seg = {name: (Vector(h), Vector(t), parent) for name, h, t, parent in bones}
    adjacent = {name: {name} for name in seg}
    for name, (_, _, parent) in seg.items():
        if parent:
            adjacent[name].add(parent)
            adjacent[parent].add(name)

    # split into three meshes by region, weights from bone distance, materials by region
    T = _textures()
    if stalker:
        n = 256
        veins = np.clip(1 - np.abs(np.sin(tex.fbm(n, n, 6, 6, 41) * 30.0)) * 4, 0, 1)
        mott = tex.fbm(n, n, 8, 8, 42)
        lum = 0.62 + 0.12 * mott
        alb = np.stack([lum * 0.95, lum * 0.95, lum * 0.92], -1) * (1 - 0.35 * veins[..., None]) + np.array([0.05, 0.03, 0.06]) * veins[..., None]
        T["skin"] = tex.to_image("stalker_skin", alb)
        T["skin_n"] = tex.to_image("stalker_skin_n", tex.normal_from_height(mott * 0.5 - veins * 0.6, 2.0), non_color=True)
        T["shirt"], T["pants"], T["hair"] = T["skin"], T["skin"], T["skin"]
        T["shirt_n"], T["pants_n"], T["hair_n"] = T["skin_n"], T["skin_n"], T["skin_n"]
    M = {
        "skin": scene.material("player_skin", T["skin"], normal_tex=T["skin_n"], normal_strength=0.4, roughness=0.6),
        "shirt": scene.material("player_shirt", T["shirt"], normal_tex=T["shirt_n"], normal_strength=0.8, roughness=0.92),
        "pants": scene.material("player_pants", T["pants"], normal_tex=T["pants_n"], normal_strength=0.8, roughness=0.88),
        "hair": scene.material("player_hair", T["hair"], normal_tex=T["hair_n"], normal_strength=1.0, roughness=0.7),
    }
    me = body.data
    verts = [v.co.copy() for v in me.vertices]
    vbone = []
    vweights = []
    for co in verts:
        ds = sorted((_seg_dist(co, h, t)[0], name) for name, (h, t, _) in seg.items())
        d1, b1 = ds[0]
        out = [(b1, 1.0 / (d1 ** 4 + 1e-7))]
        for d2, b2 in ds[1:4]:
            if b2 in adjacent[b1] and d2 < d1 * 1.8:
                out.append((b2, 1.0 / (d2 ** 4 + 1e-7)))
                break
        tot = sum(w for _, w in out)
        vweights.append([(b, w / tot) for b, w in out])
        vbone.append(b1)

    def region(bone):
        if bone in ("head", "neck"):
            return "PlayerHead"
        if bone.startswith(("upperarm", "forearm", "hand")):
            return "PlayerArms"
        return "PlayerBody"

    def mat_for(face_center, bone):
        z = face_center.z
        if bone == "head":
            if z > 1.66 or (z > 1.6 and face_center.y < -0.01):
                return "hair"
            return "skin"
        if bone in ("neck", "forearm.L", "forearm.R", "hand.L", "hand.R", "foot.L", "foot.R"):
            return "skin"
        if bone.startswith("upperarm"):
            h, t, _ = seg[bone]
            return "shirt" if _seg_dist(face_center, h, t)[1] < 0.55 else "skin"
        if bone.startswith(("thigh", "shin")):
            return "skin" if z < 0.1 else "pants"
        return "shirt" if z > 0.93 else "pants"     # torso: a level hem at the waistband

    builders = {"PlayerBody": geo.MeshBuilder(), "PlayerArms": geo.MeshBuilder(), "PlayerHead": geo.MeshBuilder()}
    remap = {k: {} for k in builders}
    for poly in me.polygons:
        c = poly.center
        counts = {}
        for vi in poly.vertices:
            counts[vbone[vi]] = counts.get(vbone[vi], 0) + 1
        fb = max(counts, key=counts.get)
        reg = region(fb)
        mb = builders[reg]
        ids = []
        uvs = []
        h, t, _ = seg[fb]
        axis = (t - h).normalized()
        ref = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))
        e1 = axis.cross(ref).normalized()
        e2 = axis.cross(e1)
        for vi in poly.vertices:
            if vi not in remap[reg]:
                remap[reg][vi] = mb.add_vert(verts[vi], vweights[vi])
            ids.append(remap[reg][vi])
            rel = verts[vi] - h
            ang = math.atan2(rel.dot(e2), rel.dot(e1))
            uvs.append((ang / math.tau * 2.0, rel.dot(axis) * 3.0))
        mb.add_face(ids, uvs, mat_for(c, fb), True)
    bpy.data.objects.remove(body)

    arm = scene.armature("PlayerRig", bones)
    objs = [arm]
    tris = 0
    for name, mb in builders.items():
        o = mb.to_object(name, M, arm, recalc_normals=False)
        objs.append(o)
        tris += mb.tri_count()
    print(f"  player: {tris} triangles in {len(builders)} meshes, {len(bones)} bones")
    scene.export_glb(out_path, objs)
