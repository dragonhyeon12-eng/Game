"""Mesh building for the creature generator.

Everything is built into one MeshBuilder per creature: lofts (rings of points stitched into quads),
tubes along curved paths, fans and strips for fin membranes. Each vertex carries skin weights
(bone name -> weight) and each face a material and UVs. `to_object` turns it into a Blender mesh.

Coordinates are Blender's: X right, Y forward, Z up. (The glTF exporter converts to Godot's Y-up,
so Blender +Y becomes Godot -Z, i.e. "forward" in the game.)
"""
import math

import bmesh
import bpy
from mathutils import Vector, noise


class MeshBuilder:
    def __init__(self):
        self.verts = []          # Vector
        self.weights = []        # list of (bone, w) per vertex
        self.faces = []          # tuple of vertex indices
        self.face_uvs = []       # tuple of (u, v) per face corner
        self.face_mat = []       # material index
        self.face_smooth = []
        self.materials = []      # names, index = material slot

    # ---------------------------------------------------------------- basics

    def mat(self, name):
        if name not in self.materials:
            self.materials.append(name)
        return self.materials.index(name)

    def add_vert(self, p, weights):
        self.verts.append(Vector(p))
        self.weights.append(weights)
        return len(self.verts) - 1

    def add_face(self, idx, uvs, mat, smooth=True):
        self.faces.append(tuple(idx))
        self.face_uvs.append(tuple(uvs))
        self.face_mat.append(self.mat(mat))
        self.face_smooth.append(smooth)

    # ---------------------------------------------------------------- lofts

    def loft(self, rings, mat, weight_fn, uv_v=None, closed=True, cap_start=False, cap_end=False,
             smooth=True, u_scale=1.0):
        """Stitch rings (lists of equal length) into a surface.

        weight_fn(ring_index, point) -> [(bone, w)]. uv_v: per-ring v coordinate (defaults to 0..1).
        """
        n = len(rings[0])
        nr = len(rings)
        if uv_v is None:
            uv_v = [i / max(nr - 1, 1) for i in range(nr)]
        ids = []
        for ri, ring in enumerate(rings):
            row = [self.add_vert(p, weight_fn(ri, p)) for p in ring]
            ids.append(row)
        cols = n if closed else n - 1
        for ri in range(nr - 1):
            for k in range(cols):
                k2 = (k + 1) % n
                u0 = k / n * u_scale if closed else k / (n - 1) * u_scale
                u1 = (k + 1) / n * u_scale if closed else (k + 1) / (n - 1) * u_scale
                self.add_face(
                    (ids[ri][k], ids[ri][k2], ids[ri + 1][k2], ids[ri + 1][k]),
                    ((u0, uv_v[ri]), (u1, uv_v[ri]), (u1, uv_v[ri + 1]), (u0, uv_v[ri + 1])),
                    mat, smooth)
        for cap, ri, flip in ((cap_start, 0, True), (cap_end, nr - 1, False)):
            if not cap:
                continue
            ring = rings[ri]
            c = sum((Vector(p) for p in ring), Vector()) / n
            ci = self.add_vert(c, weight_fn(ri, c))
            for k in range(n):
                k2 = (k + 1) % n
                tri = (ids[ri][k], ids[ri][k2], ci)
                if flip:
                    tri = (tri[1], tri[0], tri[2])
                self.add_face(tri, ((0.5, uv_v[ri]),) * 3, mat, smooth)
        return ids

    # ---------------------------------------------------------------- tubes

    def tube(self, path, radii, sides, mat, weights, ridges=0.0, ridge_freq=0.0, cap_end=True,
             cap_start=False, smooth=True, v_scale=1.0, twist_noise=0.0, seed=0.0):
        """A tube along `path` (points) with per-point `radii`. Constant skin weights."""
        frames = parallel_frames(path)
        rings = []
        length = 0.0
        vs = [0.0]
        for i in range(1, len(path)):
            length += (Vector(path[i]) - Vector(path[i - 1])).length
            vs.append(length)
        for i, (p, (t, nrm, bin_)) in enumerate(zip(path, frames)):
            r = radii[i]
            if ridges:
                r *= 1.0 + ridges * math.sin(vs[i] * ridge_freq)
            ring = []
            for k in range(sides):
                a = k / sides * math.tau
                rr = r
                if twist_noise:
                    rr *= 1.0 + twist_noise * noise.noise(Vector((math.cos(a) * 2 + seed, math.sin(a) * 2, vs[i] * 3)))
                ring.append(Vector(p) + (nrm * math.cos(a) + bin_ * math.sin(a)) * rr)
            rings.append(ring)
        uv_v = [v / max(length, 1e-6) * length * v_scale for v in vs]
        return self.loft(rings, mat, lambda ri, pt: weights, uv_v=uv_v, cap_end=cap_end, cap_start=cap_start,
                         smooth=smooth)

    # ---------------------------------------------------------------- membranes

    def strip(self, rows, mat, weight_fn, smooth=True):
        """A sheet from rows of points (open both ways). rows[i] is a list of points."""
        return self.loft(rows, mat, weight_fn, closed=False, smooth=smooth)

    def fan(self, center, outline, mat, weights, smooth=False):
        """A flat fan from `center` through consecutive outline points (fin shapes)."""
        ci = self.add_vert(center, weights)
        ids = [self.add_vert(p, weights) for p in outline]
        n = len(outline)
        for k in range(n - 1):
            u0 = k / (n - 1)
            u1 = (k + 1) / (n - 1)
            self.add_face((ci, ids[k], ids[k + 1]), ((0.5, 0.0), (u0, 1.0), (u1, 1.0)), mat, smooth)

    # ---------------------------------------------------------------- output

    def to_object(self, name, materials, armature=None, recalc_normals=True):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="UVMap")
        li = 0
        for poly, uvs, mi, sm in zip(mesh.polygons, self.face_uvs, self.face_mat, self.face_smooth):
            poly.material_index = mi
            poly.use_smooth = sm
            for k in range(poly.loop_total):
                uv.data[poly.loop_start + k].uv = uvs[k]
            li += poly.loop_total
        for mname in self.materials:
            mesh.materials.append(materials[mname])
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if armature is not None:
            groups = {}
            for vi, ws in enumerate(self.weights):
                for bone, w in ws:
                    if w <= 0.0:
                        continue
                    if bone not in groups:
                        groups[bone] = obj.vertex_groups.new(name=bone)
                    groups[bone].add([vi], w, 'REPLACE')
            obj.parent = armature
            mod = obj.modifiers.new("Armature", 'ARMATURE')
            mod.object = armature
        # merge coincident vertices of separate pieces is NOT done: pieces stay separate shells
        if recalc_normals:   # only for closed shells: on open sheets it can pick the wrong side
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if not f.calc_area() == 0.0])
            bm.to_mesh(mesh)
            bm.free()
        return obj

    def tri_count(self):
        return sum(len(f) - 2 for f in self.faces)


# -------------------------------------------------------------------- curves and frames

def parallel_frames(path):
    """Rotation-minimising frames (tangent, normal, binormal) along a polyline."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    tangents = []
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        t = (b - a)
        tangents.append(t.normalized() if t.length > 1e-9 else Vector((0, 1, 0)))
    up = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = tangents[0].cross(up).normalized()
    frames = []
    for i in range(n):
        t = tangents[i]
        nrm = (nrm - t * nrm.dot(t))
        if nrm.length < 1e-6:
            nrm = t.orthogonal()
        nrm.normalize()
        frames.append((t, nrm, t.cross(nrm).normalized()))
    return frames


def bezier(p0, p1, p2, p3, steps):
    p0, p1, p2, p3 = (Vector(p) for p in (p0, p1, p2, p3))
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        out.append(p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3)
    return out


def catmull(values, t):
    """Catmull-Rom through a list of scalars or Vectors at parameter t in [0, 1]."""
    n = len(values) - 1
    x = min(max(t, 0.0), 1.0) * n
    i = min(int(x), n - 1)
    f = x - i
    p0 = values[max(i - 1, 0)]
    p1 = values[i]
    p2 = values[i + 1]
    p3 = values[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def gauss(x, w):
    return math.exp(-(x / w) ** 2)


def fbm(p, octaves=4, lac=2.0, gain=0.5):
    total = 0.0
    amp = 1.0
    p = Vector(p)
    for _ in range(octaves):
        total += amp * noise.noise(p)
        p *= lac
        amp *= gain
    return total


def ang_diff(a, b):
    d = (a - b + math.pi) % math.tau - math.pi
    return d
