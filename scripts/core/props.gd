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
		if _scenes[slot]:
			_dress(_scenes[slot])
	return _scenes[slot]


# ------------------------------------------------------------------ real surfaces
# Models from tools/creatures tag what a material is made of in its name ("desk_top__marble"). Those are
# swapped, once per file (every copy shares the meshes), for the textured surface in models/textures/<kind>/,
# in the model's own colour: grain on wood, veins in marble, flecks in stone, weave in fabric.

const KINDS := {     # kind: [texture folder, metres per tile, use the texture's roughness, clearcoat, use its colour]
	"wood": ["woodgrain", 1.3, false, 0.25],
	"marble": ["marble", 0.9, true, 0.6],
	"stone": ["stone", 0.6, true, 0.3],
	"metal": ["metal", 0.5, false, 0.0, false],
	"fabric": ["fabric", 0.25, false, 0.0],
	"leather": ["fabric", 0.6, false, 0.2],
	"ceramic": ["", 1.0, false, 0.8],
}
static var _kind_mats := {}
static var _avg := {}


static func _dress(ps: PackedScene) -> void:
	var root := ps.instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var wm := _windy(String(m.resource_name).to_lower(), m, mesh)
			if wm:
				mesh.surface_set_material(i, wm)
				continue
			if not String(m.resource_name).contains("__"):
				continue
			var t := _textured(String(m.resource_name).get_slice("__", 1).get_slice(".", 0), m)
			if t:
				mesh.surface_set_material(i, t)
	root.free()


static func _textured(kind: String, orig: BaseMaterial3D) -> Material:
	if not KINDS.has(kind):
		return null
	var key := "%s|%s|%.2f|%.2f" % [kind, orig.albedo_color.to_html(), orig.roughness, orig.metallic]
	if _kind_mats.has(key):
		return _kind_mats[key]
	var spec: Array = KINDS[kind]
	var m := StandardMaterial3D.new()
	m.albedo_color = orig.albedo_color
	m.roughness = orig.roughness
	m.metallic = orig.metallic
	m.cull_mode = orig.cull_mode
	if float(spec[3]) > 0.0 and Settings.quality >= 1:
		m.clearcoat_enabled = true          # a polish: a second, sharp highlight on top
		m.clearcoat = float(spec[3])
		m.clearcoat_roughness = 0.1
	var dir := "res://models/textures/%s/" % spec[0]
	if spec[0] != "" and DirAccess.dir_exists_absolute(dir):
		for f in ResourceLoader.list_directory(dir):
			var low := String(f).to_lower()
			if not low.ends_with(".png") and not low.ends_with(".jpg"):
				continue
			var tex := load(dir + f) as Texture2D
			if low.contains("nor"):
				m.normal_enabled = true
				m.normal_texture = tex
				m.normal_scale = 0.6
			elif low.contains("rough"):
				if spec[2]:
					m.roughness_texture = tex
					m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
					m.roughness = 1.0
			elif (low.contains("diff") or low.contains("albedo") or low.contains("col")) and (spec.size() < 5 or spec[4]):
				m.albedo_texture = tex
				# keep the model's colour: divide out the texture's average colour
				var a := _average(dir + f, tex)
				var c := orig.albedo_color
				m.albedo_color = Color(minf(c.r / maxf(a.r, 0.05), 4.0), minf(c.g / maxf(a.g, 0.05), 4.0), minf(c.b / maxf(a.b, 0.05), 4.0), c.a)
		m.uv1_triplanar = true                  # (props move: project in the model's own space, not the world's)
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3.ONE / float(spec[1])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_kind_mats[key] = m
	return m


static func _average(path: String, tex: Texture2D) -> Color:
	if _avg.has(path):
		return _avg[path]
	var c := Color(0.5, 0.5, 0.5)
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		while img.get_width() > 1 or img.get_height() > 1:      # halve step by step: a true average
			img.resize(maxi(img.get_width() / 2, 1), maxi(img.get_height() / 2, 1), Image.INTERPOLATE_BILINEAR)
		c = img.get_pixel(0, 0)
	_avg[path] = c
	return c


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



# ------------------------------------------------------------------ wind
# Leaves, grass and the bark under them get shaders that move them in the wind (scripts/world/foliage.gdshader,
# bark_wind.gdshader): the whole plant leans with gusts, every leaf shivers. A zone can still the air.

static var _wind_mats: Array[ShaderMaterial] = []
static var _wind := 1.0
static var _white: ImageTexture


static func set_wind(v: float) -> void:
	_wind = v
	for m in _wind_mats:
		m.set_shader_parameter("wind", v)


static func wind() -> float:
	return _wind


static func _windy(name: String, m: BaseMaterial3D, mesh: Mesh) -> Material:
	var leafy := name.contains("leaf") or name.contains("grass") or name.contains("blade") or name.contains("hedge")
	var barky := name.contains("bark")
	if not leafy and not barky:
		return null
	var h := maxf(mesh.get_aabb().end.y, 0.3)
	var sm := ShaderMaterial.new()
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	if leafy:
		sm.shader = preload("res://scripts/world/foliage.gdshader")
		sm.set_shader_parameter("albedo_tex", m.albedo_texture if m.albedo_texture else _white)
		sm.set_shader_parameter("albedo", m.albedo_color)
		sm.set_shader_parameter("alpha_cut", m.alpha_scissor_threshold if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.4)
		sm.set_shader_parameter("roughness", m.roughness)
		sm.set_shader_parameter("flutter", clampf(h * 0.004, 0.006, 0.04))
		if name.contains("hedge"):
			sm.set_shader_parameter("flutter", 0.01)
	else:
		sm.shader = preload("res://scripts/world/bark_wind.gdshader")
		sm.set_shader_parameter("albedo_tex", m.albedo_texture if m.albedo_texture else _white)
		sm.set_shader_parameter("albedo", m.albedo_color)
		sm.set_shader_parameter("roughness", m.roughness)
		sm.set_shader_parameter("normal_tex", m.normal_texture)
		sm.set_shader_parameter("use_normal", 1.0 if m.normal_texture else 0.0)
	sm.set_shader_parameter("sway_height", h)
	sm.set_shader_parameter("sway", clampf(h * 0.022, 0.015, 0.32) if not name.contains("hedge") else 0.02)
	sm.set_shader_parameter("wind", _wind)
	sm.resource_name = m.resource_name
	_wind_mats.append(sm)
	return sm
