class_name Models
## Optional real art. Everything in the game is built in code, but any "slot" can be replaced by
## dropping a model file into res://models/ (see models/README.md for the list of slots):
##
##   models/people/mina.glb             a file named after the slot, or
##   models/people/mina/<anything>.glb  a folder named after the slot (keeps a pack's textures together)
##
## Supported: .glb .gltf .fbx .obj .tscn .scn. Models are scaled to the right size automatically and
## stood on the ground, so nothing has to be prepared in Blender. Optional per-slot tweaks
## (turn, height, offset, animation names, texture tiling) go in models/models.json.
## No file = the built-in procedural version, exactly as before.
##
## Nature kits (trees, bushes, rocks, flowers, grass) can be dropped anywhere under models/nature/
## as a whole folder: files are sorted into kinds by name. Zones place them with Zone.nature().

const ROOT := "res://models/"
const EXTENSIONS := ["glb", "gltf", "fbx", "obj", "tscn", "scn"]

static var _settings = null       # parsed models.json (Dictionary) once loaded
static var _paths := {}            # slot -> resolved path ("" = none)


## Path of the model file for a slot ("people/mina"), or "" if there is none.
static func find(slot: String) -> String:
	if _paths.has(slot):
		return _paths[slot]
	var found := ""
	for ext in EXTENSIONS:
		var p: String = ROOT + slot + "." + ext
		if ResourceLoader.exists(p):
			found = p
			break
	if found == "" and DirAccess.dir_exists_absolute(ROOT + slot):
		var files := Array(ResourceLoader.list_directory(ROOT + slot + "/"))
		files.sort()
		for f in files:
			if (f as String).get_extension().to_lower() in EXTENSIONS:
				found = ROOT + slot + "/" + f
				break
	_paths[slot] = found
	return found


static func has(slot: String) -> bool:
	return find(slot) != ""


## A fresh instance of the slot's model, or null. Tries each slot in order ("people/mina", "people/default").
static func instance(slots: Array) -> Node3D:
	for slot in slots:
		var path := find(slot)
		if path == "":
			continue
		var res := load(path)
		var node: Node3D = null
		if res is PackedScene:
			node = (res as PackedScene).instantiate() as Node3D
		elif res is Mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = res
			node = mi
		if node == null:
			push_warning("Models: %s is not a 3D model" % path)
			continue
		node.set_meta("slot", slot)
		return node
	return null


## Per-slot options from models/models.json ({} if none).
static func options(slot: String) -> Dictionary:
	if _settings == null:
		_settings = {}
		var text := FileAccess.get_file_as_string(ROOT + "models.json")
		if not text.is_empty():
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				_settings = parsed
			else:
				push_error("Models: models/models.json is not valid JSON")
	return _settings.get(slot, {})


## Wraps `model` so its bounding box is `size` tall (or, with fit_largest, `size` along its largest
## side), centred on X/Z, standing on y = 0 (or centred on the origin when `centre_y`). Applies the
## slot's turn / height / size / offset options. Returns the wrapper.
static func fit(model: Node3D, size: float, fit_largest := false, centre_y := false) -> Node3D:
	var opt := options(model.get_meta("slot", ""))
	size = float(opt.get("height", opt.get("size", size)))
	var holder := Node3D.new()
	holder.name = "Model"
	var turn := Node3D.new()
	turn.rotation_degrees.y = float(opt.get("turn", 0.0))
	holder.add_child(turn)
	turn.add_child(model)
	var box := bounds(model)
	if box.size.length() < 0.0001:
		return holder
	# measure after the turn, so the footprint is centred whichever way it faces
	box = Transform3D(Basis(Vector3.UP, turn.rotation.y), Vector3.ZERO) * box
	var extent := maxf(box.size.x, maxf(box.size.y, box.size.z)) if fit_largest else box.size.y
	var s := size / maxf(extent, 0.0001)
	turn.scale = Vector3.ONE * s
	var c := box.get_center() * s
	var o: Vector3 = Data.vec(opt.get("offset"), Vector3.ZERO) if opt.has("offset") else Vector3.ZERO
	turn.position = Vector3(-c.x, -c.y if centre_y else -box.position.y * s, -c.z) + o
	return holder


## Bounding box of every mesh under `root`, in root's own space (works before it is in the tree).
static func bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for gi in all_of(root, "GeometryInstance3D"):
		var aabb: AABB = (gi as GeometryInstance3D).get_aabb()
		var xf := Transform3D.IDENTITY
		var n: Node = gi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * aabb
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


static func all_of(root: Node, cls: String) -> Array:
	var out := []
	if root.is_class(cls):
		out.append(root)
	for c in root.get_children():
		out.append_array(all_of(c, cls))
	return out


## Replace every material of the model (the Observer's glitch, for example).
static func override_material(root: Node, mat: Material) -> void:
	for gi in all_of(root, "GeometryInstance3D"):
		(gi as GeometryInstance3D).material_override = mat


# ---- animation

const ANIM_WORDS := {
	"idle": ["idle", "stand", "breath", "wait"],
	"walk": ["walk"],
	"run": ["run", "jog", "sprint"],
	"sit": ["sit"],
	"talk": ["talk", "speak", "convers", "chat"],
}


static func animation_player(root: Node) -> AnimationPlayer:
	var all := all_of(root, "AnimationPlayer")
	return all[0] if not all.is_empty() else null


## Name of the animation for a role ("idle", "walk", ...), or "". models.json "anim" can name it exactly.
static func pick_animation(ap: AnimationPlayer, role: String, slot := "") -> String:
	if ap == null:
		return ""
	var named: Dictionary = options(slot).get("anim", {})
	if named.has(role):
		return named[role] if ap.has_animation(named[role]) else ""
	var best := ""
	for a in ap.get_animation_list():
		var low := (a as String).to_lower()
		for w in ANIM_WORDS.get(role, [role]):
			if low.contains(w) and (best == "" or a.length() < best.length()):
				best = a
	return best


# ---- textures (Poly Haven / ambientCG style folders: models/textures/<surface>/)

const TEX_WORDS := {
	"normal": ["nor_gl", "normal_gl", "normalgl", "normal", "nrm", "_nor"],
	"rough": ["rough"],
	"albedo": ["diff", "albedo", "basecolor", "base_color", "color", "col"],
}
## Surfaces whose code colour should still tint the texture by default (clothes come in every colour).
const TINT_BY_DEFAULT := ["fabric"]


## A textured material for a named surface ("wood", "carpet", ...), or null if there are no textures.
static func surface_material(surface: String, tint := Color.WHITE) -> Material:
	var dir := ROOT + "textures/" + surface + "/"
	if not DirAccess.dir_exists_absolute(dir):
		return null
	var maps := {}
	var files := Array(ResourceLoader.list_directory(dir))
	files.sort()
	for f in files:
		var low := (f as String).to_lower()
		if not low.get_extension() in ["png", "jpg", "jpeg", "webp", "tga", "exr", "bmp"]:
			continue
		for role in ["normal", "rough", "albedo"]:   # normal first: "nor_gl" files may contain "col"
			if maps.has(role):
				continue
			if TEX_WORDS[role].any(func(w): return low.contains(w)):
				maps[role] = dir + f
				break
	if not maps.has("albedo"):
		return null
	var opt := options("textures/" + surface)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(maps["albedo"])
	if bool(opt.get("tint", surface in TINT_BY_DEFAULT)):
		m.vertex_color_use_as_albedo = true   # MultiMesh instance colours
		m.albedo_color = tint
	m.roughness = 1.0
	if maps.has("rough"):
		m.roughness_texture = load(maps["rough"])
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	if maps.has("normal"):
		m.normal_enabled = true
		m.normal_texture = load(maps["normal"])
	# the game's geometry is scaled primitives, so project the texture in world space
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / maxf(float(opt.get("tile", 2.0)), 0.01)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


# ---- nature kits (models/nature/): many variants per kind, sorted by file name

## kind -> [words in the file name, words that rule it out]. A subfolder models/nature/<kind>/
## takes precedence: then every model in it counts, whatever its name.
const NATURE_KINDS := {
	"trees": [["tree", "pine", "birch", "willow", "oak", "maple", "palm", "cypress"],
		["dead", "stump", "log", "branch", "twisted", "trunk_only"]],
	"bushes": [["bush", "shrub", "hedge"], ["dead"]],
	"rocks": [["rock", "boulder", "stone", "cliff"], ["path", "pebble", "small", "tile"]],
	"flowers": [["flower", "tulip", "daisy", "rose", "lily"], ["petal", "pad"]],
	"grass": [["grass", "fern", "clover"], []],
}

static var _nature := {}   # kind -> Array of {"path", "meshes": [[Mesh, Transform3D]], "aabb"}


## The variants of a nature kind ("trees", "rocks"...) found in models/nature, or [] if none.
static func nature(kind: String) -> Array:
	if _nature.has(kind):
		return _nature[kind]
	var paths: Array = []
	var own := ROOT + "nature/" + kind + "/"
	if DirAccess.dir_exists_absolute(own):
		paths = _model_files(own)
	else:
		var words: Array = NATURE_KINDS.get(kind, [[kind], []])[0]
		var nots: Array = NATURE_KINDS.get(kind, [[kind], []])[1]
		for p in _model_files(ROOT + "nature/"):
			var low := (p as String).get_file().to_lower()
			if words.any(func(w): return low.contains(w)) and not nots.any(func(w): return low.contains(w)):
				paths.append(p)
	var out := []
	for p in paths:
		var v := _flatten(p)
		if not v.is_empty():
			out.append(v)
	if not out.is_empty():
		print("Models: %d %s from models/nature" % [out.size(), kind])
	_nature[kind] = out
	return out


## Every model file under `dir` (recursive), one per name: the same model as .glb and .fbx counts once.
static func _model_files(dir: String) -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var seen := {}
	var files := Array(ResourceLoader.list_directory(dir))
	files.sort()
	for f in files:
		var name := f as String
		if name.ends_with("/"):
			for sub in _model_files(dir + name):
				var key := (sub as String).get_file().get_basename().to_lower()
				if not seen.has(key):
					seen[key] = true
					out.append(sub)
		elif name.get_extension().to_lower() in EXTENSIONS:
			var key := name.get_basename().to_lower()
			if not seen.has(key):
				seen[key] = true
				out.append(dir + name)
	return out


## A model as plain meshes with their transforms (for MultiMesh), plus its bounding box.
static func _flatten(path: String) -> Dictionary:
	var res := load(path)
	var root: Node3D = null
	if res is PackedScene:
		root = (res as PackedScene).instantiate() as Node3D
	elif res is Mesh:
		root = MeshInstance3D.new()
		(root as MeshInstance3D).mesh = res
	if root == null:
		return {}
	var meshes := []
	for mi in all_of(root, "MeshInstance3D"):
		if (mi as MeshInstance3D).mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		xf = root.transform * xf
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		# per-instance material overrides from the import become the mesh's own materials
		var mi3 := mi as MeshInstance3D
		if mi3.material_override or range(mi3.get_surface_override_material_count()).any(func(i): return mi3.get_surface_override_material(i) != null):
			mesh = mesh.duplicate()
			for s in mesh.get_surface_count():
				var m: Material = mi3.material_override if mi3.material_override else mi3.get_surface_override_material(s)
				if m:
					mesh.surface_set_material(s, m)
		meshes.append([mesh, xf])
	var box := bounds(root)
	root.free()
	if meshes.is_empty() or box.size.length() < 0.0001:
		return {}
	return {"path": path, "meshes": meshes, "aabb": box}
