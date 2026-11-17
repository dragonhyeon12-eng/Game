"""Trees, bushes and grass for the city (models/props/*.glb).

Trees: a tapering trunk with root flare and recursive curved branches (bark texture), and a canopy of
leaf-cluster cards (an alpha-masked leaf texture painted with numpy) whose normals point away from the
canopy's centre, so light wraps around it like a real crown instead of lighting each card flat.
Grass: a clump of crossed cards with a blade texture, meant to be scattered by the thousand.
"""
import math
import random

import numpy as np
from mathutils import Quaternion, Vector

from dp import scene, tex
from dp.geo import MeshBuilder, bezier

LEAF_GREENS = [(0.16, 0.32, 0.07), (0.22, 0.4, 0.09), (0.3, 0.45, 0.12), (0.13, 0.27, 0.06)]


def _leaf_texture(name, seed, n=512, leaves=420, size=(0.035, 0.07)):
    """RGBA leaf cluster: many overlapping ellipse leaves with a midrib, varied greens."""
    rng = np.random.default_rng(seed)
    rgb = np.zeros((n, n, 3))
    a = np.zeros((n, n))
    Y, X = np.mgrid[0:n, 0:n] / n
    for _ in range(leaves):
        cx, cy = rng.random(2) * 0.84 + 0.08
        r = np.hypot(cx - 0.5, cy - 0.5)
        if r > 0.47 and rng.random() < 0.8:
            continue
        ang = rng.random() * math.pi
        L = rng.uniform(*size) * 1.6
        W = L * rng.uniform(0.35, 0.5)
        dx, dy = X - cx, Y - cy
        u = dx * math.cos(ang) + dy * math.sin(ang)
        v = -dx * math.sin(ang) + dy * math.cos(ang)
        inside = (u / L) ** 2 + (v / W) ** 2 < 1.0
        if not inside.any():
            continue
        g = np.array(LEAF_GREENS[rng.integers(len(LEAF_GREENS))]) * rng.uniform(0.8, 1.35)
        shade = 0.75 + 0.35 * (u / L * 0.5 + 0.5)                     # lighter toward the tip
        rib = 1.0 - 0.25 * (np.abs(v) < W * 0.08)
        col = g[None, None, :] * (shade * rib)[..., None]
        rgb = np.where(inside[..., None], col, rgb)
        a = np.where(inside, 1.0, a)
    return tex.to_image(name, rgb, alpha=a)


def _bark_textures():
    W = H = 256
    fib = tex.fbm(W, H, 40, 4, 31, 4)
    cracks = np.clip(1 - np.abs(np.sin(tex.fbm(W, H, 14, 3, 32) * 28.0)) * 3, 0, 1)
    lum = 0.22 + 0.14 * fib - 0.12 * cracks
    alb = np.stack([lum * 1.1, lum * 0.92, lum * 0.75], -1)
    nrm = tex.normal_from_height(fib * 0.6 - cracks, 4.0)
    return tex.to_image("bark_albedo", alb), tex.to_image("bark_normal", nrm, non_color=True)


def _grass_texture(seed=40, n=256):
    rng = np.random.default_rng(seed)
    rgb = np.zeros((n, n, 3))
    a = np.zeros((n, n))
    Y, X = np.mgrid[0:n, 0:n] / n
    yb = 1.0 - Y                                  # 0 at the bottom of the card
    for _ in range(90):
        x0 = rng.uniform(0.05, 0.95)
        h = rng.uniform(0.45, 1.0)
        lean = rng.uniform(-0.25, 0.25)
        w0 = rng.uniform(0.006, 0.014)
        xc = x0 + lean * yb ** 2
        width = w0 * np.clip(1 - yb / h, 0, 1)
        inside = (np.abs(X - xc) < width) & (yb < h)
        g = np.array([0.2, 0.42, 0.08]) * rng.uniform(0.75, 1.3) + np.array([0.08, 0.05, 0.0]) * rng.random()
        col = g[None, None, :] * (0.55 + 0.6 * yb)[..., None]
        rgb = np.where(inside[..., None], col, rgb)
        a = np.where(inside, 1.0, a)
    return tex.to_image("grass_blades", rgb, alpha=a)


def _branch(mb, base, direction, length, radius, depth, rng, tips, bone=None):
    d = direction.normalized()
    side = d.orthogonal().normalized()
    bend = Vector((0, 0, 1)) * 0.25 + side * rng.uniform(-0.3, 0.3)
    end = base + (d + bend * 0.35).normalized() * length
    path = bezier(base, base + d * length * 0.35, end - (d * 0.2 - bend * 0.3) * length * 0.3, end, 6)
    radii = [radius * (1.0 - 0.65 * i / 6) for i in range(7)]
    mb.tube(path, radii, 7 if depth == 0 else 5, "bark", [], v_scale=0.5)
    if depth >= 2:
        tips.append(end)
        return
    n = 3 if depth == 0 else 2
    for k in range(n):
        f = rng.uniform(0.55, 0.95)
        i = int(f * 6)
        p = path[i]
        rot_axis = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.4))).normalized()
        nd = (d + rot_axis * rng.uniform(0.6, 1.1)).normalized()
        nd.z = abs(nd.z) * 0.8 + 0.2
        _branch(mb, p, nd, length * rng.uniform(0.5, 0.7), radii[i] * 0.7, depth + 1, rng, tips)
    tips.append(end)


def _tree(name, out_dir, seed, height, crown, spread, leaf_size, leaf_tex_seed):
    scene.reset()
    rng = random.Random(seed)
    mb = MeshBuilder()
    # trunk with root flare
    trunk_h = height * 0.42
    path = [Vector((math.sin(i * 0.7 + seed) * 0.06 * i / 8, 0, trunk_h * i / 8)) for i in range(9)]
    radii = [0.18 + 0.32 * (1 - i / 8) ** 6 + 0.06 * (1 - i / 8) for i in range(9)]
    mb.tube(path, radii, 9, "bark", [], v_scale=0.5, twist_noise=0.08, seed=seed)
    tips = []
    for k in range(rng.randint(4, 6)):
        a = k / 5 * math.tau + rng.uniform(-0.4, 0.4)
        d = Vector((math.cos(a) * spread, math.sin(a) * spread, 1.0))
        base = path[rng.randint(6, 8)]
        _branch(mb, base, d, height * rng.uniform(0.26, 0.36), radii[7] * 0.85, 0, rng, tips)
    # canopy: leaf cards around the branch tips, filling an ellipsoid crown
    center = Vector((0, 0, trunk_h + crown * 0.55))
    cards = []
    for tip in tips:
        for _ in range(7):
            p = tip + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 0.8))) * crown * 0.25
            cards.append(p)
    for _ in range(110):
        u = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 0.8))).normalized()
        cards.append(center + Vector((u.x * crown * 0.55, u.y * crown * 0.55, u.z * crown * 0.42)) * rng.uniform(0.5, 1.0))
    leaf_ids = []
    for p in cards:
        s = leaf_size * 0.62 * rng.uniform(0.75, 1.25)
        nrm = (p - center).normalized()
        t1 = nrm.orthogonal().normalized()
        t1.rotate(Quaternion(nrm, rng.uniform(0, math.tau)))
        t2 = nrm.cross(t1)
        tilt = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5)))
        t1 = (t1 + tilt).normalized()
        t2 = (t2 - tilt * 0.5).normalized()
        quad = [p - t1 * s - t2 * s, p + t1 * s - t2 * s, p + t1 * s + t2 * s, p - t1 * s + t2 * s]
        ids = [mb.add_vert(q, []) for q in quad]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "leaves", True)
        leaf_ids.append((ids, center))
    bark_a, bark_n = _bark_textures()
    leaf = _leaf_texture(name + "_leaves", leaf_tex_seed)
    M = {
        "bark": scene.material(name + "_bark", bark_a, normal_tex=bark_n, roughness=0.9),
        "leaves": _alpha_material(name + "_leaf", leaf, 0.75),
    }
    obj = mb.to_object(name, M, recalc_normals=False)
    _spherical_normals(obj, center, "leaves", M)
    print(f"  {name}: {mb.tri_count()} triangles")
    scene.export_glb(f"{out_dir}/{name}.glb", [obj])


def _alpha_material(name, image, roughness):
    import bpy
    m = scene.material(name, image, roughness=roughness, double_sided=True)
    nt = m.node_tree
    img = [n for n in nt.nodes if n.type == 'TEX_IMAGE'][0]
    bsdf = nt.nodes.get("Principled BSDF")
    gt = nt.nodes.new("ShaderNodeMath")
    gt.operation = 'GREATER_THAN'           # exported as glTF alphaMode MASK
    gt.inputs[1].default_value = 0.5
    nt.links.new(img.outputs["Alpha"], gt.inputs[0])
    nt.links.new(gt.outputs[0], bsdf.inputs["Alpha"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = 'DITHERED'
    _ = bpy
    return m


def _spherical_normals(obj, center, mat_name, M):
    """Leaf cards get normals pointing away from the crown centre (soft, volumetric shading)."""
    me = obj.data
    mats = [m.name for m in me.materials]
    li = mats.index(M[mat_name].name)
    normals = []
    for poly in me.polygons:
        for k in range(poly.loop_total):
            vi = me.loops[poly.loop_start + k].vertex_index
            if poly.material_index == li:
                normals.append(tuple((me.vertices[vi].co - center).normalized()))
            else:
                normals.append(tuple(poly.normal) if not poly.use_smooth else tuple(me.vertices[vi].normal))
    me.normals_split_custom_set(normals)


def _bush(out_dir):
    scene.reset()
    rng = random.Random(9)
    mb = MeshBuilder()
    center = Vector((0, 0, 0.55))
    for _ in range(60):
        u = Vector((rng.gauss(0, 1), rng.gauss(0, 1), abs(rng.gauss(0, 0.7)))).normalized()
        p = center + Vector((u.x * 0.85, u.y * 0.85, u.z * 0.55 - 0.1)) * rng.uniform(0.4, 1.0)
        s = rng.uniform(0.32, 0.45)
        nrm = (p - center).normalized()
        t1 = nrm.orthogonal().normalized()
        t2 = nrm.cross(t1)
        quad = [p - t1 * s - t2 * s, p + t1 * s - t2 * s, p + t1 * s + t2 * s, p - t1 * s + t2 * s]
        ids = [mb.add_vert(q, []) for q in quad]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "leaves", True)
    leaf = _leaf_texture("bush_leaves", 77, leaves=520, size=(0.03, 0.05))
    M = {"leaves": _alpha_material("bush_leaf", leaf, 0.8)}
    obj = mb.to_object("bush", M, recalc_normals=False)
    _spherical_normals(obj, center, "leaves", M)
    scene.export_glb(f"{out_dir}/bush.glb", [obj])


def _grass(out_dir):
    scene.reset()
    mb = MeshBuilder()
    for k in range(3):
        a = k / 3 * math.pi
        d = Vector((math.cos(a), math.sin(a), 0)) * 0.32
        quad = [Vector((0, 0, 0)) - d, Vector((0, 0, 0)) + d, d + Vector((0, 0, 0.38)), -d + Vector((0, 0, 0.38))]
        ids = [mb.add_vert(q, []) for q in quad]
        mb.add_face(ids, [(0, 0), (1, 0), (1, 1), (0, 1)], "grass", True)
    M = {"grass": _alpha_material("grass_card", _grass_texture(), 0.9)}
    obj = mb.to_object("grass_clump", M, recalc_normals=False)
    me = obj.data
    me.normals_split_custom_set([(0.0, 0.0, 1.0)] * len(me.loops))     # lit like the ground under it
    scene.export_glb(f"{out_dir}/grass_clump.glb", [obj])


def build(out_dir):
    _tree("tree_oak", out_dir, 3, 8.5, 5.2, 0.9, 0.85, 11)
    _tree("tree_lime", out_dir, 7, 10.5, 4.6, 0.55, 0.8, 12)
    _tree("tree_young", out_dir, 13, 6.0, 3.4, 0.7, 0.65, 13)
    _bush(out_dir)
    _grass(out_dir)
