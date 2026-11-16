"""Scene setup, materials (glTF-compatible Principled BSDF), armatures and GLB export."""
import os

import bpy


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, base_tex=None, base_color=(0.02, 0.02, 0.02), normal_tex=None, normal_strength=1.0,
             emission_tex=None, emission_color=None, emission_strength=0.0, roughness=0.5, metallic=0.0,
             double_sided=False):
    """A Principled BSDF the glTF exporter maps 1:1 to glTF PBR (+ emissive strength extension)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not double_sided
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    out = nt.nodes.get("Material Output")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if base_tex is not None:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = base_tex
        nt.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
    if normal_tex is not None:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = normal_tex
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if emission_tex is not None:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = emission_tex
        nt.links.new(n.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    elif emission_color is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission_color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    _ = out
    return m


def armature(name, bones):
    """bones: list of (name, head, tail, parent_name or None). Returns the armature object."""
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    made = {}
    for bname, head, tail, parent in bones:
        eb = data.edit_bones.new(bname)
        eb.head = head
        eb.tail = tail
        eb.use_deform = True
        if parent:
            eb.parent = made[parent]
            eb.use_connect = False
        made[bname] = eb
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o == obj)
    for m in list(obj.modifiers):
        if m.type == 'ARMATURE':
            continue
        bpy.ops.object.modifier_apply(modifier=m.name)


def export_glb(path, objects):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    names = {o.name for o in objects}
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
    for o in bpy.context.view_layer.objects:
        o.select_set(o.name in names)
    bpy.context.view_layer.objects.active = bpy.data.objects[objects[0].name]
    print("  exporting", [o.name for o in bpy.context.view_layer.objects if o.select_get()])
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_skins=True,
        export_animations=False,
        export_materials='EXPORT',
        export_image_format='AUTO',
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
    )
    size = os.path.getsize(path) / 1024 / 1024
    print(f"  wrote {path} ({size:.1f} MB)")
