class_name Shapes
## Shared 1-metre primitive meshes and cached materials, so every builder uses the same few resources.

static var _meshes := {}
static var _materials := {}


static func mesh(kind: String) -> Mesh:
	kind = kind.to_lower()
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 24
			s.rings = 12
			m = s
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 20
			m = c
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 20
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


## Material whose colour comes from MultiMesh per-instance colours.
static func instanced_material(roughness: float) -> StandardMaterial3D:
	var key := "inst|%.2f" % roughness
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	_materials[key] = m
	return m


## The Observer: absolutely black, unlit, as though lighting failed to render him.
static func void_material() -> StandardMaterial3D:
	if _materials.has("void"):
		return _materials["void"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK
	_materials["void"] = m
	return m
