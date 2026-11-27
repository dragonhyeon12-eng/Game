"""Park vegetation, built the way real-time foliage is built (models/props/*.glb):

Trees: a flared trunk and three orders of curved branches; at every twig tip a spray of "twig cards" -
an alpha texture of a real twig with a dozen leaves of the species' shape (lobed oak, heart-shaped linden,
small birch, maple-lobed plane, a red maple) - fanned out along the branch, drooping, with normals pointed
away from the crown so the light wraps round it. The game moves them in the wind (materials named *_leaf /
*_bark: scripts/world/foliage.gdshader).
Hedges: a dark core wrapped in hundreds of small-leaved sprays. Lawn grass, wildflowers, fallen leaves.
"""
import math
import random

import numpy as np
from mathutils import Quaternion, Vector

from dp import scene, tex
from dp.geo import MeshBuilder, bezier
from foliage import _alpha_material, _spherical_normals, _bark_textures

SPECIES = {
    #             leaf aspect, lobes, lobe depth, colours (rgb) ...
    "oak":    dict(aspect=0.55, lobes=7, lobe=0.22, cols=[(0.16, 0.3, 0.07), (0.2, 0.36, 0.08), (0.12, 0.25, 0.06)]),
    "linden": dict(aspect=0.85, lobes=0, lobe=0.0, cols=[(0.24, 0.42, 0.1), (0.3, 0.48, 0.12), (0.2, 0.38, 0.09)]),
    "birch":  dict(aspect=0.7, lobes=0, lobe=0.0, cols=[(0.3, 0.46, 0.12), (0.36, 0.52, 0.14), (0.26, 0.42, 0.1)]),
    "plane":  dict(aspect=0.95, lobes=5, lobe=0.3, cols=[(0.18, 0.34, 0.08), (0.22, 0.4, 0.1), (0.15, 0.3, 0.07)]),
    "maple":  dict(aspect=0.95, lobes=5, lobe=0.34, cols=[(0.42, 0.07, 0.04), (0.5, 0.12, 0.05), (0.36, 0.05, 0.04), (0.55, 0.2, 0.06)]),
    "privet": dict(aspect=0.5, lobes=0, lobe=0.0, cols=[(0.1, 0.24, 0.05), (0.13, 0.3, 0.06), (0.08, 0.2, 0.04)]),
}


def _twig_texture(name, species, seed, n=512, leaves=24, twigs=4):
    """A twig, or a few: a stem from the bottom of the card, leaves alternating up it on short stalks."""
    sp = SPECIES[species]
    rng = np.random.default_rng(seed)
    rgb = np.zeros((n, n, 3))
    a = np.zeros((n, n))
    Y, X = np.mgrid[0:n, 0:n] / n
    Yb = 1.0 - Y                                     # 0 at the card's bottom
    for t in range(twigs):
        # the stem: a gentle curve from near the bottom centre up and out
        x0 = 0.5 + rng.uniform(-0.08, 0.08)
        lean = rng.uniform(-0.25, 0.25) if t else rng.uniform(-0.08, 0.08)
        top = rng.uniform(0.75, 0.95) if t == 0 else rng.uniform(0.5, 0.8)
        y0 = 0.02 if t == 0 else rng.uniform(0.15, 0.4)
        def stem_x(y):
            return x0 + lean * ((y - y0) / max(top - y0, 0.01)) ** 1.5
        sx = stem_x(Yb)
        on = (np.abs(X - sx) < 0.004 + 0.004 * (1 - Yb)) & (Yb > y0) & (Yb < top)
        rgb = np.where(on[..., None], np.array([0.22, 0.15, 0.08])[None, None, :], rgb)
        a = np.where(on, 1.0, a)
        k = leaves if t == 0 else leaves // 2
        for i in range(k):
            f = (i + 0.5) / k
            ly = y0 + (top - y0) * (0.15 + 0.85 * f)
            lx = stem_x(ly)
            side = 1 if i % 2 else -1
            size = (0.05 + 0.03 * (1 - f)) * (1.2 if species in ("plane", "maple", "linden") else 1.0) * (0.6 if species == "privet" else 1.0)
            ang = math.radians(rng.uniform(30, 65)) * side + lean * 0.8
            dx, dy = math.sin(ang), math.cos(ang)
            cx, cy = lx + dx * size * 1.1, ly + dy * size * 1.1           # stalk to the leaf's centre
            u = (X - cx) * dx + (Yb - cy) * dy
            v = -(X - cx) * dy + (Yb - cy) * dx
            L, W = size, size * sp["aspect"]
            th = np.arctan2(v, u)
            edge = 1.0 + sp["lobe"] * np.cos(sp["lobes"] * th) if sp["lobes"] else 1.0
            heart = 1.0 - 0.12 * np.clip(-u / L, 0, 1) if species == "linden" else 1.0
            rr = (u / L) ** 2 + (v / W) ** 2
            inside = rr < (np.asarray(edge) * heart) ** 2
            if not inside.any():
                continue
            g = np.array(sp["cols"][rng.integers(len(sp["cols"]))]) * rng.uniform(0.85, 1.25)
            shade = 0.72 + 0.4 * (u / L * 0.5 + 0.5)                     # lighter toward the tip
            vein = 1.0 + 0.18 * (np.abs(v) < W * 0.05) + 0.06 * (np.abs(np.sin((u / L) * 9.0 + np.abs(v / W) * 6.0)) < 0.12)
            rim = 1.0 - 0.25 * np.clip(rr - 0.75, 0, 1)
            col = g[None, None, :] * (shade * vein * rim)[..., None]
            rgb = np.where(inside[..., None], col, rgb)
            a = np.where(inside, 1.0, a)
            st = (np.abs((X - lx) * dy - (Yb - ly) * dx) < 0.0025) & (((X - lx) * dx + (Yb - ly) * dy) > 0) & (((X - lx) * dx + (Yb - ly) * dy) < size * 0.3)
            rgb = np.where(st[..., None], np.array([0.25, 0.2, 0.08])[None, None, :], rgb)
            a = np.where(st, 1.0, a)
    return tex.to_image(name, np.clip(rgb, 0, 1), alpha=a)


def _bark(name, kind):
    if kind != "birch":
        return _bark_textures()
    W = H = 256
    f = tex.fbm(W, H, 8, 4, 5, 4)
    marks = (tex.fbm(W, H, 3, 22, 7, 3) > 0.62).astype(float)
    lum = 0.86 - 0.08 * f
    alb = np.stack([lum, lum * 0.98, lum * 0.94], -1) * (1 - marks[..., None] * 0.8)
    return tex.to_image(name + "_albedo", np.clip(alb, 0, 1)), tex.to_image(name + "_normal", tex.normal_from_height(f * 0.4 + marks * 0.3, 2.0), non_color=True)


def _branch(mb, base, direction, length, radius, depth, max_depth, rng, tips):
    d = direction.normalized()
    side = d.orthogonal().normalized()
    bend = Vector((0, 0, 1)) * rng.uniform(0.05, 0.3) + side * rng.uniform(-0.35, 0.35)
    end = base + (d + bend * 0.4).normalized() * length
    path = bezier(base, base + d * length * 0.35, end - (d * 0.25 - bend * 0.3) * length * 0.3, end, 6)
    radii = [radius * (1.0 - 0.7 * i / 6) for i in range(7)]
    mb.tube(path, radii, 7 if depth == 0 else (5 if depth == 1 else 4), "bark", [], v_scale=0.5)
    if depth >= max_depth:
        tips.append((end, (end - path[4]).normalized()))
        return
    n = 3 if depth == 0 else 2 + (rng.random() < 0.5)
    for k in range(n):
        f = rng.uniform(0.45, 0.95)
        i = min(int(f * 6), 6)
        p = path[i]
        rot = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.5))).normalized()
        nd = (d + rot * rng.uniform(0.6, 1.1)).normalized()
        nd.z = abs(nd.z) * 0.75 + 0.1
        _branch(mb, p, nd, length * rng.uniform(0.5, 0.68), radii[i] * 0.72, depth + 1, max_depth, rng, tips)
    tips.append((end, (end - path[4]).normalized()))


def _card(mb, p, along, up_hint, w, h, mat):
    """A twig card: its bottom edge at p, running `along` (the twig's direction), facing roughly `up_hint`."""
    along = along.normalized()
    side = along.cross(up_hint).normalized()
    if side.length < 0.1:
        side = along.orthogonal().normalized()
    q = [p - side * w * 0.5, p + side * w * 0.5, p + side * w * 0.5 + along * h, p - side * w * 0.5 + along * h]
    ids = [mb.add_vert(v, []) for v in q]
    mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], mat, True)


def _tree(d, name, species, seed, height, spread, card, crown_fill=200, trunk_kind="oak", lean=0.0):
    scene.reset()
    rng = random.Random(seed)
    mb = MeshBuilder()
    trunk_h = height * (0.38 if species != "birch" else 0.55)
    path = [Vector((math.sin(i * 0.7 + seed) * 0.07 * i / 8 + lean * (i / 8) ** 2, 0, trunk_h * i / 8)) for i in range(9)]
    r0 = 0.2 if species != "birch" else 0.13
    radii = [r0 + 0.3 * r0 / 0.2 * (1 - i / 8) ** 6 + 0.05 * (1 - i / 8) for i in range(9)]
    mb.tube(path, radii, 10, "bark", [], v_scale=0.5, twist_noise=0.08, seed=seed)
    tips = []
    nb = rng.randint(5, 7)
    for k in range(nb):
        a = k / nb * math.tau + rng.uniform(-0.35, 0.35)
        dd = Vector((math.cos(a) * spread, math.sin(a) * spread, 1.0))
        base = path[rng.randint(5, 8)]
        _branch(mb, base, dd, height * rng.uniform(0.24, 0.34), radii[7] * 0.8, 0, 2, rng, tips)
    top = path[8]
    _branch(mb, top, Vector((0, 0, 1)), height * 0.32, radii[8] * 0.8, 0, 2, rng, tips)   # the leader
    zs = [t[0].z for t in tips]
    center = Vector((0, 0, (min(zs) + max(zs)) * 0.5 + 0.3))
    # sprays of twig cards at the tips, drooping a little, fanned round the twig
    for tip, dirn in tips:
        out = (tip - center)
        out.z *= 0.6
        out = out.normalized()
        for j in range(4):
            along = (dirn * 0.5 + out * 0.8 + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.55, 0.15)))).normalized()
            up = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 1.0))
            s = card * rng.uniform(0.8, 1.2)
            _card(mb, tip - along * s * 0.15, along, up, s, s, "leaves")
    # fill the crown's volume, so it isn't hollow from below
    crown_r = max((Vector((t[0].x, t[0].y, 0)).length for t in tips), default=2.0)
    crown_h = (max(zs) - min(zs)) * 0.5 + 0.6
    for _ in range(crown_fill):
        u = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        p = center + Vector((u.x * crown_r, u.y * crown_r, u.z * crown_h)) * rng.uniform(0.45, 0.95)
        out = (p - center).normalized()
        along = (out + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.2)))).normalized()
        s = card * rng.uniform(0.8, 1.15)
        _card(mb, p, along, Vector((0, 0, 1)), s, s, "leaves")
    bark_a, bark_n = _bark(name + "_bark", species)
    leaf = _twig_texture(name + "_leaves", species, seed + 100)
    M = {"bark": scene.material(name + "_bark", bark_a, normal_tex=bark_n, roughness=0.9),
         "leaves": _alpha_material(name + "_leaf", leaf, 0.7)}
    obj = mb.to_object(name, M, recalc_normals=False)
    _spherical_normals(obj, center, "leaves", M)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{d}/{name}.glb", [obj])


def _hedge(d, name, L, W, H, step):
    """A clipped hedge: a dark core, wrapped in small-leaved sprays standing out of every face."""
    scene.reset()
    rng = random.Random(hash(name) & 0xffff)
    mb = MeshBuilder()
    from kit import box
    box(mb, (-L / 2 + 0.08, -W / 2 + 0.08, 0.0), (L / 2 - 0.08, W / 2 - 0.08, H - 0.08), "core", 1.0)
    faces = [(Vector((0, -1, 0)), L, H), (Vector((0, 1, 0)), L, H), (Vector((-1, 0, 0)), W, H), (Vector((1, 0, 0)), W, H), (Vector((0, 0, 1)), L, W)]
    for n, a_len, b_len in faces:
        na = int(a_len / step) + 1
        nb = int(b_len / step) + 1
        for i in range(na):
            for j in range(nb):
                fa = (i + rng.uniform(0.1, 0.9)) / na
                fb = (j + rng.uniform(0.1, 0.9)) / nb
                if n.z > 0.5:
                    p = Vector((-L / 2 + fa * L, -W / 2 + fb * W, H - 0.1))
                elif abs(n.y) > 0.5:
                    p = Vector((-L / 2 + fa * L, n.y * (W / 2 - 0.12), fb * (H - 0.1)))
                else:
                    p = Vector((n.x * (L / 2 - 0.12), -W / 2 + fa * W, fb * (H - 0.1)))
                for k in range(2):
                    along = (n + Vector((rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), rng.uniform(-0.5, 0.7)))).normalized()
                    s = step * rng.uniform(1.3, 1.8)
                    _card(mb, p - along * s * 0.25, along, n, s, s, "leaves")
    leaf = _twig_texture(name + "_leaves", "privet", 55, leaves=34, twigs=6)
    M = {"core": scene.material(name + "_hedge_core", base_color=(0.03, 0.07, 0.02), roughness=1.0),
         "leaves": _alpha_material(name + "_hedge_leaf", leaf, 0.8)}
    obj = mb.to_object(name, M, recalc_normals=False)
    _spherical_normals(obj, Vector((0, 0, H * 0.5)), "leaves", M)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{d}/{name}.glb", [obj])


def _blades_texture(name, seed, n=256, blades=170, cols=((0.2, 0.42, 0.08),), dry=0.0, flowers=0):
    rng = np.random.default_rng(seed)
    rgb = np.zeros((n, n, 3))
    a = np.zeros((n, n))
    Y, X = np.mgrid[0:n, 0:n] / n
    yb = 1.0 - Y
    for _ in range(blades):
        x0 = rng.uniform(0.04, 0.96)
        h = rng.uniform(0.35, 1.0)
        lean = rng.uniform(-0.3, 0.3)
        w0 = rng.uniform(0.004, 0.009)
        xc = x0 + lean * yb ** 2
        width = w0 * np.clip(1 - yb / h, 0, 1) ** 0.7
        inside = (np.abs(X - xc) < width) & (yb < h)
        g = np.array(cols[rng.integers(len(cols))]) * rng.uniform(0.75, 1.3)
        g = g * (1 - dry) + np.array([0.55, 0.5, 0.28]) * dry * rng.uniform(0.6, 1.0)
        col = g[None, None, :] * (0.45 + 0.7 * yb)[..., None]
        rgb = np.where(inside[..., None], col, rgb)
        a = np.where(inside, 1.0, a)
    for _ in range(flowers):
        cx, cy = rng.uniform(0.1, 0.9), rng.uniform(0.45, 0.9)
        st = (np.abs(X - cx) < 0.004) & (yb < cy)
        rgb = np.where(st[..., None], np.array([0.22, 0.38, 0.1])[None, None, :], rgb)
        a = np.where(st, 1.0, a)
        kind = rng.integers(3)
        r = rng.uniform(0.018, 0.03)
        dd = np.hypot(X - cx, yb - cy)
        th = np.arctan2(yb - cy, X - cx)
        petals = dd < r * (0.75 + 0.35 * np.abs(np.cos(th * (4 if kind else 6))))
        col = [np.array([0.96, 0.96, 0.92]), np.array([0.95, 0.8, 0.15]), np.array([0.6, 0.45, 0.85])][kind]
        rgb = np.where(petals[..., None], col[None, None, :], rgb)
        a = np.where(petals, 1.0, a)
        eye = dd < r * 0.3
        rgb = np.where(eye[..., None], np.array([0.95, 0.75, 0.1])[None, None, :], rgb)
    return tex.to_image(name, np.clip(rgb, 0, 1), alpha=a)


def _tufts(d, name, size, height, cards, tex_fn, rough=0.9):
    """A square metre (or so) of lawn: thin crossed blade cards scattered over it."""
    scene.reset()
    tex_img = tex_fn()
    rng = random.Random(hash(name) & 0xffff)
    mb = MeshBuilder()
    for _ in range(cards):
        c = Vector((rng.uniform(-size / 2, size / 2), rng.uniform(-size / 2, size / 2), 0))
        a = rng.uniform(0, math.pi)
        w = rng.uniform(0.25, 0.4)
        h = height * rng.uniform(0.7, 1.2)
        dd = Vector((math.cos(a), math.sin(a), 0)) * w * 0.5
        lean = Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0))
        q = [c - dd, c + dd, c + dd + lean + Vector((0, 0, h)), c - dd + lean + Vector((0, 0, h))]
        ids = [mb.add_vert(v, []) for v in q]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "grass", True)
    M = {"grass": _alpha_material(name + "_blade", tex_img, rough)}
    obj = mb.to_object(name, M, recalc_normals=False)
    obj.data.normals_split_custom_set([(0.0, 0.0, 1.0)] * len(obj.data.loops))      # lit like the ground under it
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{d}/{name}.glb", [obj])


def _fallen(d):
    """A scatter of fallen leaves lying flat (a few curled), for paths and under trees."""
    scene.reset()
    rng = random.Random(4)
    mb = MeshBuilder()
    for _ in range(40):
        c = Vector((rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2), 0.005 + rng.uniform(0, 0.01)))
        a = rng.uniform(0, math.tau)
        s = rng.uniform(0.05, 0.09)
        t1 = Vector((math.cos(a), math.sin(a), 0)) * s
        t2 = Vector((-math.sin(a), math.cos(a), 0)) * s
        curl = Vector((0, 0, rng.uniform(0, 0.03)))
        q = [c - t1 - t2, c + t1 - t2 + curl, c + t1 + t2 + curl, c - t1 + t2]
        ids = [mb.add_vert(v, []) for v in q]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "leaves", True)
    img = _twig_texture("fallen_leaves_tex", "plane", 9, leaves=1, twigs=1)
    px = np.array(img.pixels[:]).reshape(-1, 4)
    px[:, 0] = np.clip(px[:, 0] * 2.6 + 0.15, 0, 1)           # autumn: browns and ochres
    px[:, 1] = np.clip(px[:, 1] * 1.2 + 0.05, 0, 1)
    img.pixels[:] = px.ravel()
    M = {"leaves": _alpha_material("fallen_leaves_mat", img, 0.85)}
    obj = mb.to_object("fallen_leaves", M, recalc_normals=False)
    obj.data.normals_split_custom_set([(0.0, 0.0, 1.0)] * len(obj.data.loops))
    scene.export_glb(f"{d}/fallen_leaves.glb", [obj])


def build(d):
    _tree(d, "park_oak", "oak", 11, 11.0, 1.0, 1.0, trunk_kind="oak")
    _tree(d, "park_linden", "linden", 12, 13.0, 0.6, 0.95)
    _tree(d, "park_plane", "plane", 13, 14.0, 0.8, 1.1)
    _tree(d, "park_birch", "birch", 14, 10.0, 0.45, 0.7, crown_fill=140, lean=0.25)
    _tree(d, "park_maple_red", "maple", 15, 9.0, 0.9, 0.95)
    _hedge(d, "hedge_block", 3.0, 1.0, 2.4, 0.32)
    _hedge(d, "hedge_tall", 3.0, 1.2, 7.5, 0.42)
    _tufts(d, "grass_lawn", 1.2, 0.16, 26, lambda: _blades_texture("lawn_blades", 21, blades=200, cols=((0.18, 0.4, 0.07), (0.22, 0.45, 0.09), (0.15, 0.34, 0.06))))
    _tufts(d, "wildflowers", 1.0, 0.42, 14, lambda: _blades_texture("wild_blades", 22, blades=150, cols=((0.22, 0.42, 0.09), (0.3, 0.45, 0.12)), dry=0.15, flowers=7), 0.95)
    _fallen(d)
