"""Studio preview renders (Cycles, CPU) for checking silhouettes and proportions while iterating."""
import math
import os

import bpy
from mathutils import Vector


def render_views(out_dir, name, views, res=(960, 540), samples=24, background=(0.18, 0.19, 0.21)):
    """views: list of (label, camera_location, look_at, lens_mm)."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.image_settings.file_format = 'PNG'
    world = bpy.data.worlds.new("preview") if sc.world is None else sc.world
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*background, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    # key, rim and fill lights
    for lname, loc, energy in (("key", (30, 40, 50), 4.0), ("rim", (-40, -30, 25), 3.0), ("fill", (10, -50, -20), 1.2)):
        ld = bpy.data.lights.new(lname, 'SUN')
        ld.energy = energy
        lo = bpy.data.objects.new(lname, ld)
        sc.collection.objects.link(lo)
        lo.rotation_euler = (-Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    paths = []
    for label, loc, target, lens in views:
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cam_data.lens = lens
        cam_data.clip_end = 1000
        path = os.path.join(out_dir, f"{name}_{label}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths
