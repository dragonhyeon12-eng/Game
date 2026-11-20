class_name Props
## Models made by tools/creatures (trees, grass, the facade kit, street furniture, cars): models/props/*.glb.
## Like every model, optional: with the file missing, callers fall back to their built-in geometry.

static var _scenes := {}     # slot -> PackedScene (or null)
static var _meshes := {}     # "slot|mesh|tint" -> Mesh
static var _parts := {}      # slot -> [[Mesh, Transform3D relative to the root], ...]


static func scene(slot: String) -> PackedScene:
	if not _scenes.has(slot):
		var path := Models.find("props/" + slot)
		_scenes[slot] = load(path) as PackedScene if path != "" else null
	return _scenes[slot]


static func has(slot: String) -> bool:
	return scene(slot) != null


static func instance(slot: String) -> Node3D:
	var s := scene(slot)
	return s.instantiate() as Node3D if s else null


## One mesh out of a prop file (the first, or the one named `mesh_name`), for MultiMesh use.
## With tint_walls, materials whose name contains "wall" take each instance's colour.
static func mesh(slot: String, mesh_name := "", tint_walls := false) -> Mesh:
	var key := "%s|%s|%s" % [slot, mesh_name, tint_walls]
	if _meshes.has(key):
		return _meshes[key]
	var root := instance(slot)
	var found: Mesh = null
	if root:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			if mesh_name == "" or mi.name == mesh_name or String(mi.name).begins_with(mesh_name + "_") or mi.mesh.resource_name == mesh_name:
				found = mi.mesh
				break
		root.free()
	if found and tint_walls:
		found = found.duplicate()
		for i in found.get_surface_count():
			var m := found.surface_get_material(i)
			if m is BaseMaterial3D and String(m.resource_name).contains("wall"):
				var t := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				t.vertex_color_use_as_albedo = true
				found.surface_set_material(i, t)
	_meshes[key] = found
	return found


## Every mesh in a prop file, with where it sits in the model: [[Mesh, Transform3D], ...] (empty if missing).
## For batching whole models (trees) into MultiMeshes, one per mesh.
static func parts(slot: String) -> Array:
	if _parts.has(slot):
		return _parts[slot]
	var out := []
	var root := instance(slot)
	if root:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != root:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			if (mi as MeshInstance3D).mesh:
				out.append([(mi as MeshInstance3D).mesh, xf])
		root.free()
	_parts[slot] = out
	return out
