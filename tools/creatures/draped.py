"""COMPRESSION's sheeted figure: a person-shaped thing standing under a bedsheet. Static.

The sheet is a loft of horizontal rings from the crown to the floor. Each ring follows the body
underneath (head, shoulders, chest, then the cloth falling free), plus hanging folds that grow toward
the hem, a ragged hem, and two dents where eyes press against the cloth. Woven, stained fabric texture.

Faces Blender -Y (Godot +Z), stands on z = 0, 1.85 m tall. (Not wired into the game yet: the drying
room's figures are built in its level script.)
"""
import math

import numpy as np
from mathutils import Vector

from dp import geo, scene, tex
from dp.geo import MeshBuilder, smoothstep, gauss, ang_diff

HEIGHT = 1.85


# (height, half-width, half-depth) of the sheet where it rests on the body; below the shoulders it falls
W_TABLE = [(1.85, 0.0, 0.0), (1.83, 0.055, 0.055), (1.77, 0.105, 0.11), (1.66, 0.118, 0.12), (1.57, 0.1, 0.1),
           (1.5, 0.14, 0.11), (1.45, 0.215, 0.135), (1.4, 0.255, 0.15), (1.3, 0.265, 0.16), (1.0, 0.27, 0.18),
           (0.6, 0.31, 0.23), (0.25, 0.36, 0.28), (0.0, 0.4, 0.32)]


def body_radius(z, theta):
    zs = [r[0] for r in reversed(W_TABLE)]
    w = float(np.interp(z, zs, [r[1] for r in reversed(W_TABLE)]))
    d = float(np.interp(z, zs, [r[2] for r in reversed(W_TABLE)]))
    return w, d


def build(out_path):
    scene.reset()
    mb = MeshBuilder()
    N = 64
    rings = []
    zs = []
    z = HEIGHT
    nz = 70
    for i in range(nz + 1):
        t = i / nz
        z = HEIGHT * (1 - t) ** 1.0
        zs.append(z)
        ring = []
        for k in range(N):
            th = k / N * math.tau
            w, d = body_radius(z, th)
            if i == 0:
                w, d = 0.0, 0.0
            x = math.cos(th) * w
            y = math.sin(th) * d
            hang = smoothstep(1.5, 0.2, z)
            # folds: a few long hanging ones, wandering slightly, deeper toward the hem
            fold = (math.sin(th * 7 + 0.6 * math.sin(z * 2.0)) * 0.6 + math.sin(th * 13 + 1.7 + z) * 0.25 +
                    geo.fbm(Vector((math.cos(th) * 2, math.sin(th) * 2, z * 1.5)), 3) * 0.6)
            r = 1.0 + fold * 0.07 * hang
            p = Vector((x * r, y * r, z))
            # the cloth drapes over the shoulders and slumps a little at the front of the head
            if z > 1.5:
                p.z -= 0.01 * (1 - math.sin(th) ** 2)
            ring.append(p)
        rings.append(ring)
    # ragged hem: lift the last ring unevenly
    for k in range(N):
        th = k / N * math.tau
        rings[-1][k].z = max(0.0, 0.02 + 0.05 * (0.5 + 0.5 * math.sin(th * 5 + 1.0)) + 0.03 * geo.fbm(Vector((th, 0, 0)), 2))
    # eyes pressing against the cloth (front = -Y)
    for ring in rings:
        for p in ring:
            for ex in (-0.045, 0.045):
                e = Vector((ex, -0.105, 1.7))
                dist = (p - e).length
                if dist < 0.06 and p.y < 0:
                    p.y += 0.02 * gauss(dist, 0.025)
    rings = [list(reversed(r)) for r in rings]      # outward-facing winding
    mb.loft(rings, "sheet", lambda ri, p: [], uv_v=[1 - z / HEIGHT for z in zs], u_scale=3.0)

    # fabric: weave, folds of grime, old stains, a darker hem
    W = H = 512
    weave = (np.sin(np.arange(W) * math.tau / 8)[None, :] * np.sin(np.arange(H) * math.tau / 8)[:, None]) * 0.5 + 0.5
    grime = tex.fbm(W, H, 6, 6, 3)
    stain_n = tex.fbm(W, H, 4, 4, 9)
    stains = np.clip((stain_n - 0.62) * 6, 0, 1)
    v = 1 - (np.arange(H) + 0.5) / H
    hem = np.clip((v[:, None] - 0.8) * 5, 0, 1)
    base = np.array([0.83, 0.81, 0.75])
    col = base[None, None, :] * (0.92 + 0.06 * weave[..., None]) * (0.85 + 0.15 * grime[..., None])
    col = col * (1 - 0.35 * stains[..., None]) + np.array([0.42, 0.33, 0.22])[None, None, :] * 0.35 * stains[..., None]
    col = col * (1 - 0.3 * hem[..., None])
    alb = tex.to_image("draped_albedo", col)
    nrm = tex.to_image("draped_normal", tex.normal_from_height(weave * 0.05 + grime * 0.6, 1.5), non_color=True)
    mat = scene.material("draped_sheet", alb, normal_tex=nrm, normal_strength=0.6, roughness=0.9, double_sided=True)
    obj = mb.to_object("Draped", {"sheet": mat}, recalc_normals=False)
    print(f"  draped: {len(mb.verts)} vertices, {mb.tri_count()} triangles")
    scene.export_glb(out_path, [obj])
