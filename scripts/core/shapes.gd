class_name Shapes
## Shared 1-metre primitive meshes and cached materials, so every builder uses the same few resources.

static var _meshes := {}
static var _materials := {}


static func mesh(kind: String) -> Mesh:
	kind = kind.to_lower()
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	var hi := Settings.quality >= 1      # LOW graphics: fewer sides on round things
	match kind:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 24 if hi else 14
			s.rings = 12 if hi else 7
			m = s
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 20 if hi else 12
			c.rings = 0
			m = c
		"pipe":
			# a cylinder with few sides, for things there are hundreds of
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 0
			m = c
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 20 if hi else 12
			c.rings = 0
			m = c
		"capsule":
			# 1 wide, 2 tall: scale by (width, length / 2, depth)
			var c := CapsuleMesh.new()
			c.radius = 0.5
			c.height = 2.0
			c.radial_segments = 16 if hi else 10
			c.rings = 6 if hi else 3
			m = c
		"taper":
			# a cylinder that narrows toward the bottom (forearms, shins, fingers)
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.38
			c.height = 1.0
			c.radial_segments = 14 if hi else 10
			c.rings = 0
			m = c
		"plane":
			var p := PlaneMesh.new()
			p.size = Vector2.ONE
			m = p
		_:
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
	_meshes[kind] = m
	return m


## A plain lit material. Cached by colour/roughness/emission.
static func material(color: Color, roughness := 0.85, emission := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, emission, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


## Named procedural surfaces (see surface.gdshader). "plain@0.3" = plain with roughness 0.3.
## Values: pattern, scale, roughness, metallic, accent colour, bump.
const SURFACES := {
	"plain":         [0, 1.0, 0.85, 0.0, Color(0.5, 0.5, 0.5), 0.0],
	"glass":         [0, 1.0, 0.06, 0.35, Color(0.5, 0.5, 0.5), 0.0],
	"metal":         [0, 2.0, 0.35, 0.8, Color(0.5, 0.5, 0.5), 0.0],
	"water":         [0, 1.0, 0.04, 0.1, Color(0.5, 0.5, 0.5), 0.0],
	"tiles_pool":    [1, 4.0, 0.12, 0.0, Color(0.82, 0.86, 0.88), 0.0],
	"tiles_floor":   [1, 2.0, 0.3, 0.0, Color(0.55, 0.57, 0.58), 0.0],
	"tiles_ceiling": [1, 1.667, 0.9, 0.0, Color(0.55, 0.53, 0.42), 0.0],
	"pavers":        [1, 1.0, 0.85, 0.0, Color(0.42, 0.41, 0.39), 0.0],
	"wallpaper":     [2, 1.0, 0.9, 0.0, Color(0.55, 0.45, 0.25), 0.0],
	"wood":          [3, 1.0, 0.55, 0.0, Color(0.5, 0.5, 0.5), 0.5],
	"carpet":        [4, 1.0, 1.0, 0.0, Color(0.6, 0.52, 0.32), 0.6],
	"concrete":      [5, 1.0, 0.95, 0.0, Color(0.5, 0.5, 0.5), 0.4],
	"asphalt":       [5, 1.0, 0.9, 0.0, Color(0.5, 0.5, 0.5), 0.5],
	"plaster":       [6, 1.0, 0.85, 0.0, Color(0.5, 0.5, 0.5), 0.0],
	"grass":         [7, 1.0, 1.0, 0.0, Color(0.5, 0.5, 0.5), 0.5],
	"fabric":        [8, 1.0, 0.95, 0.0, Color(0.5, 0.5, 0.5), 0.0],
}

static var _surface_shader: Shader


## Material for a named surface. Colour comes from MultiMesh instance colours multiplied by `tint`.
static func surface(name: String, tint := Color.WHITE) -> Material:
	var key := "surf|%s|%s" % [name, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	if _surface_shader == null:
		_surface_shader = load("res://scripts/core/surface.gdshader")
	var base := name
	var rough_override := -1.0
	if name.contains("@"):
		base = name.get_slice("@", 0)
		rough_override = name.get_slice("@", 1).to_float()
	# real textures in models/textures/<surface>/ replace the procedural pattern
	var textured := Models.surface_material(base, tint)
	if textured:
		_materials[key] = textured
		return textured
	var def: Array = SURFACES.get(base, SURFACES["plain"])
	var m := ShaderMaterial.new()
	m.shader = _surface_shader
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("pattern", def[0])
	m.set_shader_parameter("scale", def[1])
	m.set_shader_parameter("roughness_base", rough_override if rough_override >= 0.0 else def[2])
	m.set_shader_parameter("metallic_base", def[3])
	m.set_shader_parameter("accent", def[4])
	m.set_shader_parameter("bump", def[5])
	_materials[key] = m
	return m


## Backwards-compatible: a plain surface with the given roughness.
static func instanced_material(roughness: float) -> Material:
	return surface("plain@%.2f" % roughness)


## Skin with a little subsurface scattering, so it reads as skin rather than plastic.
static func skin(color: Color) -> StandardMaterial3D:
	var key := "skin|" + color.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.35
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.6
	_materials[key] = m
	return m


## The Observer: absolutely black, unlit, as though lighting failed to render him.
static func void_material() -> StandardMaterial3D:
	if _materials.has("void"):
		return _materials["void"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK
	m.disable_fog = true   # stays pure black at any distance: no haze, no atmosphere
	_materials["void"] = m
	return m
