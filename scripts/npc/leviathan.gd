class_name Leviathan
extends Node3D
## An abyssal leviathan, dozens of metres long. Almost entirely black; restrained cyan bioluminescence
## traces its skull, ribs and flanks, so in the dark you read it by its outline and those few lines.
##
## Anatomy (front to back, the head faces -Z of each segment):
##  - a massive angular skull: brow ridges, flared cheekbones, two pairs of swept-back horns, deep-set
##    eyes and a separate hinged lower jaw with dark, irregular teeth;
##  - a narrow neck with glowing gill slits;
##  - a thick, deep-chested front torso wrapped in rib arcs, with bony pectoral fins and tall,
##    irregular dorsal spines (some broken);
##  - a long taper into a laterally flattened tail with a serrated crest and a crescent tail fin.
##
## The body is a chain of segments that follow the head's trail, so it moves like a snake.
## Behaviours: ORBIT (circle at a distance, rising and sinking), RUSH (straight at a target),
## BLOCKED (slammed into something too small: thrashes, then withdraws).
## Each segment's parts are merged into one mesh (a few surfaces) to keep it cheap.

enum Mode { ORBIT, RUSH, BLOCKED }

var mode := Mode.ORBIT
var segments := 34
var spacing := 2.4
var thickness := 1.0           # overall scale of the body radius
var speed := 9.0

# orbit parameters
var orbit_center := Vector3.ZERO
var orbit_radius := 90.0
var orbit_height := 0.0
var orbit_bob := 18.0
var orbit_dir := 1.0

var rush_target := Vector3.ZERO
var arrived := false            # set when a rush reaches its target

var _angle := randf() * TAU
var _t := randf() * 10.0
var _head: Node3D
var _jaw: Node3D
var _jaw_open := 0.1
var _segs: Array[Node3D] = []
var _trail: Array[Vector3] = []   # head positions, newest first, every `_step` metres
var _step := 0.6
var _blocked_t := 0.0
var _blocked_at := Vector3.ZERO
var _eye_mat: StandardMaterial3D

# the custom model (models/creatures/leviathan.glb, made by tools/creatures): when present it replaces the
# built-in geometry below, and its bones simply follow the segments every frame
var _model: Node3D
var _sk: Skeleton3D
var _bone_ids: Array[int] = []
var _bone_rests: Array[Transform3D] = []
var _jaw_bone := -1
var _jaw_rest := Quaternion.IDENTITY

# mesh building
var _mats := {}
var _kit := {}                    # material key -> SurfaceTool
var _rng := RandomNumberGenerator.new()

const SKIN_SHADER := """
shader_type spatial;
render_mode %s;
uniform vec3 albedo : source_color = vec3(0.012, 0.014, 0.018);
uniform vec3 rim_color : source_color = vec3(0.12, 0.42, 0.6);
uniform float rim_power = 3.5;
uniform float rim_strength = 0.35;
uniform float roughness = 0.4;
void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.15;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * rim * rim_strength;
}
"""

## Body diameter (before `thickness`) along the body, u = 0 at the head, 1 at the tail tip.
const PROFILE := [[0.0, 2.0], [0.05, 3.0], [0.14, 5.0], [0.26, 4.8], [0.42, 3.6], [0.6, 2.2], [0.78, 1.15], [1.0, 0.35]]


static func diameter(u: float) -> float:
	for i in PROFILE.size() - 1:
		var a: Array = PROFILE[i]
		var b: Array = PROFILE[i + 1]
		if u <= b[0]:
			return lerpf(a[1], b[1], smoothstep(0.0, 1.0, (u - a[0]) / (b[0] - a[0])))
	return PROFILE[-1][1]


func _make_skin(albedo: Color, rim: float, double_sided := false, rough := 0.4) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SKIN_SHADER % ("cull_disabled" if double_sided else "cull_back")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("roughness", rough)
	return m


func _ready() -> void:
	_model = Models.instance(["creatures/leviathan"])
	_rng.seed = hash(get_instance_id())
	_mats["skin"] = _make_skin(Color(0.01, 0.012, 0.016), 0.2)
	_mats["membrane"] = _make_skin(Color(0.008, 0.01, 0.013), 0.25, true, 0.6)
	_mats["bone"] = _make_skin(Color(0.075, 0.07, 0.065), 0.2, false, 0.7)
	_mats["glow"] = Shapes.material(Color(0.25, 0.78, 1.0), 0.5, 4.0)
	_mats["glow_dim"] = Shapes.material(Color(0.15, 0.55, 0.95), 0.5, 2.0)
	_eye_mat = Shapes.material(Color(0.2, 0.8, 1.0), 0.3, 3.0)
	_mats["eye"] = _eye_mat

	var T := thickness
	for i in segments:
		var seg := Node3D.new()
		add_child(seg)
		_segs.append(seg)
		var u := float(i) / (segments - 1)
		var d := diameter(u) * T
		var ys := lerpf(1.18, 0.95, smoothstep(0.2, 0.7, u))     # deep-chested in front
		var xs := lerpf(1.0, 0.62, smoothstep(0.55, 0.9, u))      # tail flattened side to side
		var top := d * ys * 0.5
		var half_w := d * xs * 0.5
		_add("sphere", Vector3.ZERO, Vector3(d * xs, d * ys, spacing * 2.3 + d * 0.3), "skin")

		# lateral line: a dotted cyan line down both flanks
		if u > 0.04 and u < 0.92:
			for side in [-1.0, 1.0]:
				_add("sphere", Vector3(half_w * 0.97 * side, -d * 0.04, 0), Vector3.ONE * (0.1 + d * 0.04), "glow" if i % 3 == 0 else "glow_dim")

		# dorsal spines: tall and irregular over the torso, shrinking down the back, some broken off
		if u > 0.04 and u < 0.62:
			var h := d * lerpf(0.95, 0.35, smoothstep(0.1, 0.62, u)) * _rng.randf_range(0.6, 1.3)
			var broken := _rng.randf() < 0.2
			if broken:
				h *= 0.4
			var lean := deg_to_rad(_rng.randf_range(28.0, 48.0))
			var base := Vector3(0, top * 0.85, _rng.randf_range(-0.3, 0.3))
			_spike(base, base + Vector3(_rng.randf_range(-0.1, 0.1) * h, cos(lean) * h, sin(lean) * h), (0.22 + d * 0.07) * (1.6 if broken else 1.0), "bone")
		# a few smaller spurs off the shoulders
		if u > 0.06 and u < 0.36 and i % 2 == 1:
			for side in [-1.0, 1.0]:
				var b := Vector3(half_w * 0.6 * side, top * 0.6, 0)
				_spike(b, b + Vector3(0.45 * side, 0.55, 0.9) * d * _rng.randf_range(0.25, 0.45), 0.12 + d * 0.04, "bone")

		# ribs: arcs of bone around the torso, standing just proud of the hide
		if u > 0.07 and u < 0.44:
			var R := d * 0.53
			for side in [-1.0, 1.0]:
				var pts := []
				for k in 5:
					var th := deg_to_rad(lerpf(62.0, -48.0, k / 4.0))
					pts.append(Vector3(cos(th) * R * xs * side, sin(th) * R * ys, 0.15 * k))
				for k in 4:
					_limb(pts[k], pts[k + 1], 0.13 + d * 0.035, "bone")
				# every other rib carries a glowing seam
				if i % 2 == 0:
					_limb(pts[1] * 1.04, pts[3] * 1.04, 0.05 + d * 0.012, "glow_dim")

		# pectoral fins: bony rays with black webbing between them
		if i == int(segments * 0.1):
			for side in [-1.0, 1.0]:
				var root := Vector3(half_w * 0.85 * side, -d * 0.22, -0.4)
				var tips := [Vector3(0.9 * side, -0.35, 0.75), Vector3(1.0 * side, -0.62, 0.35), Vector3(0.7 * side, -0.85, 0.1)]
				var tip_pts := []
				for k in tips.size():
					var tp: Vector3 = root + (tips[k] as Vector3).normalized() * d * (1.5 - k * 0.25)
					tip_pts.append(tp)
					_limb(root, tp, 0.16 * T, "bone")
				for k in tip_pts.size() - 1:
					_tri(root, tip_pts[k], tip_pts[k + 1], "membrane")
				_limb(root.lerp(tip_pts[0], 0.35), tip_pts[0], 0.045 * T, "glow_dim")

		# the tail: a serrated crest above and below, and a crescent fin at the end
		if u >= 0.6 and i < segments - 1:
			var crest := d * lerpf(0.6, 1.1, smoothstep(0.6, 0.95, u))
			_tri(Vector3(0, top * 0.8, -spacing * 0.75), Vector3(0, top * 0.8, spacing * 0.75), Vector3(0, top + crest, spacing * 0.45), "membrane")
			_tri(Vector3(0, -top * 0.8, -spacing * 0.6), Vector3(0, -top * 0.8, spacing * 0.6), Vector3(0, -top - crest * 0.55, spacing * 0.4), "membrane")
			if i % 2 == 0:
				_limb(Vector3(0, top * 0.85, -spacing * 0.5), Vector3(0, top + crest * 0.9, spacing * 0.4), 0.04 * T, "glow_dim")
		if i == segments - 1:
			var upper := Vector3(0, 4.6 * T, 3.6 * T)
			var lower := Vector3(0, -3.0 * T, 3.0 * T)
			var notch := Vector3(0, 0, 1.6 * T)
			_tri(Vector3(0, 0.5 * T, -0.8 * T), upper, notch, "membrane")
			_tri(Vector3(0, -0.4 * T, -0.8 * T), lower, notch, "membrane")
			_limb(Vector3(0, 0.5 * T, -0.8 * T), upper, 0.12 * T, "bone")
			_limb(Vector3(0, -0.4 * T, -0.8 * T), lower, 0.1 * T, "bone")
			_limb(Vector3(0, 1.4 * T, 0.0), upper * 0.97, 0.05 * T, "glow")
			_limb(Vector3(0, -1.0 * T, 0.0), lower * 0.97, 0.045 * T, "glow_dim")

		# gill slits on the neck
		if i == 1:
			for side in [-1.0, 1.0]:
				for k in 3:
					_limb(Vector3(half_w * 0.98 * side, d * 0.22, -0.6 + k * 0.6), Vector3(half_w * 0.98 * side, -d * 0.18, -0.45 + k * 0.6), 0.06 * T, "glow_dim")

		if i == 0:
			if _model == null:
				_build_skull(seg, T)
		_flush(seg)

		# its own light falls on its body: you glimpse black hide and bone, never the whole of it
		if i in [0, int(segments * 0.16), int(segments * 0.4), int(segments * 0.75)]:
			var l := OmniLight3D.new()
			l.light_color = Color(0.2, 0.6, 1.0)
			l.light_energy = (0.7 if i == 0 else 1.5) * T
			l.omni_range = d * 2.5 + 5.0
			l.position = Vector3(0, -d * (1.6 if i == 0 else 0.7), -2.0 * T if i == 0 else 0.0)
			Zone._fade_with_distance(l, l.omni_range)
			seg.add_child(l)

	_head = _segs[0]
	if _model:
		_setup_model()
	var p := _orbit_point()
	global_position = p
	for i in int(segments * spacing / _step) + 2:
		_trail.append(p - Vector3(0, 0, -i * _step).rotated(Vector3.UP, _angle))
	_layout()


## The skull, on the head segment (forward = -Z). Long and angular; the lower jaw is its own node.
func _build_skull(seg: Node3D, T: float) -> void:
	var s := 2.5 * T
	# the cranium and upper jaw: one faceted, tapering form - broad at the cheeks, a long wedge of a snout
	_loft([[0.45, 1.0, 0.85, 0.25], [0.0, 1.45, 1.05, 0.3], [-0.55, 1.3, 0.9, 0.3], [-1.15, 0.9, 0.62, 0.15],
		[-1.7, 0.62, 0.44, 0.05], [-2.05, 0.34, 0.26, 0.0]], s, "skin")
	for side in [-1.0, 1.0]:
		# brow ridges over deep-set eyes
		_add("box", Vector3(0.42 * s * side, 0.63 * s, -0.78 * s), Vector3(0.34 * s, 0.2 * s, 0.95 * s), "bone", Vector3(-8, 12 * side, -12 * side))
		# flared cheekbones
		_spike(Vector3(0.6 * s * side, 0.12 * s, -0.7 * s), Vector3(0.82 * s * side, 0.05 * s, 0.05 * s), 0.28 * s, "bone")
		# two pairs of horns, swept back
		_spike(Vector3(0.42 * s * side, 0.6 * s, 0.05 * s), Vector3(0.95 * s * side, 1.05 * s, 1.75 * s), 0.3 * s, "bone")
		_spike(Vector3(0.6 * s * side, 0.15 * s, 0.15 * s), Vector3(1.3 * s * side, -0.05 * s, 1.35 * s), 0.2 * s, "bone")
		# eyes, and the light along the brow and the snout
		_add("sphere", Vector3(0.5 * s * side, 0.43 * s, -0.98 * s), Vector3.ONE * 0.085 * s, "eye")
		_limb(Vector3(0.36 * s * side, 0.75 * s, -0.3 * s), Vector3(0.5 * s * side, 0.66 * s, -1.22 * s), 0.035 * s, "glow")
		_limb(Vector3(0.46 * s * side, 0.06 * s, -0.75 * s), Vector3(0.28 * s * side, 0.0, -2.1 * s), 0.03 * s, "glow_dim")
		# upper teeth: dark, irregular
		for k in 7:
			var z := lerpf(-0.75, -2.05, k / 6.0) * s
			var x: float = lerpf(0.42, 0.24, k / 6.0) * s * side
			var ln := _rng.randf_range(0.14, 0.34) * s
			_spike(Vector3(x, -0.16 * s, z), Vector3(x * 0.95, -0.16 * s - ln, z - 0.04 * s), 0.07 * s, "bone")
	for k in 3:
		_add("sphere", Vector3(0, 0.69 * s, -0.1 * s - k * 0.32 * s), Vector3.ONE * 0.07 * s, "glow_dim")

	# the lower jaw, hinged at the back of the skull
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.2 * s, -0.05 * s)
	seg.add_child(_jaw)
	var jaw_kit_owner := _kit
	_kit = {}
	_loft([[0.25, 1.15, 0.42, -0.08], [-0.6, 1.0, 0.4, -0.12], [-1.3, 0.7, 0.34, -0.14], [-1.9, 0.38, 0.26, -0.13]], s, "skin")
	for side in [-1.0, 1.0]:
		_limb(Vector3(0.58 * s * side, -0.24 * s, 0.0), Vector3(0.2 * s * side, -0.28 * s, -1.85 * s), 0.03 * s, "glow_dim")
		for k in 6:
			var z := lerpf(-0.55, -1.8, k / 5.0) * s
			var x: float = lerpf(0.5, 0.2, k / 5.0) * s * side
			var ln := _rng.randf_range(0.12, 0.28) * s
			_spike(Vector3(x, 0.08 * s, z), Vector3(x * 0.95, 0.08 * s + ln, z + 0.04 * s), 0.065 * s, "bone")
	_flush(_jaw)
	_kit = jaw_kit_owner


# ------------------------------------------------------------------ mesh building

func _st(key: String) -> SurfaceTool:
	if not _kit.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_kit[key] = st
	return _kit[key]


## A primitive (Shapes.mesh kind) merged into the current segment's mesh.
func _add(kind: String, pos: Vector3, scl: Vector3, key: String, rot := Vector3.ZERO) -> void:
	if _model:
		return   # the custom model is used instead
	var xf := Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(scl), pos)
	_st(key).append_from(Shapes.mesh(kind), 0, xf)


## A basis whose Y axis points along `dir`.
static func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## A capsule from a to b, `w` wide.
func _limb(a: Vector3, b: Vector3, w: float, key: String) -> void:
	if _model:
		return   # the custom model is used instead
	var ln := a.distance_to(b)
	if ln < 0.001:
		return
	var xf := Transform3D(_along(b - a) * Basis.from_scale(Vector3(w, (ln + w) * 0.5, w)), (a + b) * 0.5)
	_st(key).append_from(Shapes.mesh("capsule"), 0, xf)


## A cone from base a to tip b, `w` wide at the base.
func _spike(a: Vector3, b: Vector3, w: float, key: String) -> void:
	if _model:
		return   # the custom model is used instead
	var ln := a.distance_to(b)
	if ln < 0.001:
		return
	var xf := Transform3D(_along(b - a) * Basis.from_scale(Vector3(w, ln, w)), (a + b) * 0.5)
	_st(key).append_from(Shapes.mesh("cone"), 0, xf)


## A box from a to b, w wide and h high (a jawbone).
func _beam(a: Vector3, b: Vector3, w: float, h: float, key: String) -> void:
	if _model:
		return   # the custom model is used instead
	var dir := (b - a).normalized()
	var z := -dir
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	var xf := Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(w, h, a.distance_to(b))), (a + b) * 0.5)
	_st(key).append_from(Shapes.mesh("box"), 0, xf)


## A flat triangle (fin webbing), double sided via its material.
func _tri(a: Vector3, b: Vector3, c: Vector3, key: String) -> void:
	if _model:
		return   # the custom model is used instead
	var st := _st(key)
	var n := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


## A faceted solid through cross-sections [z, width, height, y] (in units of `unit`), capped at both
## ends. Flat shading on purpose: hard planes read as bone and plate, not as a smooth worm.
const _RING := [Vector2(0, 0.5), Vector2(0.3, 0.44), Vector2(0.5, 0.14), Vector2(0.47, -0.22), Vector2(0.3, -0.5),
	Vector2(-0.3, -0.5), Vector2(-0.47, -0.22), Vector2(-0.5, 0.14), Vector2(-0.3, 0.44)]


func _loft(sections: Array, unit: float, key: String) -> void:
	if _model:
		return   # the custom model is used instead
	var rings := []
	for sec in sections:
		var ring := []
		for q in _RING:
			ring.append(Vector3(q.x * sec[1], q.y * sec[2] + sec[3], sec[0]) * unit)
		rings.append(ring)
	var n := _RING.size()
	for r in rings.size() - 1:
		for k in n:
			var a: Vector3 = rings[r][k]
			var b: Vector3 = rings[r][(k + 1) % n]
			var c: Vector3 = rings[r + 1][(k + 1) % n]
			var d: Vector3 = rings[r + 1][k]
			_tri_solid(a, b, c, key)
			_tri_solid(a, c, d, key)
	for end in [0, rings.size() - 1]:
		var ctr := Vector3.ZERO
		for v in rings[end]:
			ctr += v
		ctr /= n
		for k in n:
			if end == 0:
				_tri_solid(ctr, rings[end][(k + 1) % n], rings[end][k], key)
			else:
				_tri_solid(ctr, rings[end][k], rings[end][(k + 1) % n], key)


## One-sided triangle on its own surface ("<key>_flat"), normal facing outward.
func _tri_solid(a: Vector3, b: Vector3, c: Vector3, key: String) -> void:
	var fk := key + "_flat"
	if not _mats.has(fk):
		# flat facets catch the rim light all at once: keep it faint so the skull stays black
		_mats[fk] = _make_skin(Color(0.008, 0.009, 0.012), 0.05, false, 0.5)
	var st := _st(fk)
	var nrm := (c - a).cross(b - a).normalized()
	for v in [a, c, b]:
		st.set_normal(nrm)
		st.add_vertex(v)


## Commit everything gathered so far into one mesh under `parent`.
func _flush(parent: Node3D) -> void:
	if _model:
		return   # the custom model is used instead
	if _kit.is_empty():
		return
	var am := ArrayMesh.new()
	for key in _kit:
		(_kit[key] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, _mats[key])
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_kit = {}


## Hook the custom model's skeleton up to the segments (rig contract: see tools/creatures/leviathan.py).
func _setup_model() -> void:
	add_child(_model)
	var found := _model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("Leviathan: the model has no skeleton; using it as a static mesh")
		return
	_sk = found[0]
	for i in segments:
		var b := _sk.find_bone("spine_%02d" % i)
		_bone_ids.append(b)
		_bone_rests.append(_sk.get_bone_global_rest(b) if b >= 0 else Transform3D.IDENTITY)
	_jaw_bone = _sk.find_bone("jaw")
	if _jaw_bone >= 0:
		_jaw_rest = _sk.get_bone_rest(_jaw_bone).basis.get_rotation_quaternion()
	for gi in _model.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pose_model()


## Each spine bone takes its segment's place: the model was built with segment i at z = i * spacing.
func _pose_model() -> void:
	if _sk == null:
		return
	var inv := _sk.global_transform.affine_inverse()
	for i in _bone_ids.size():
		var b := _bone_ids[i]
		if b < 0:
			continue
		var sc := Vector3(thickness, thickness, thickness if i == 0 else 1.0)
		var xf := inv * _segs[i].global_transform * Transform3D(Basis.from_scale(sc), Vector3(0, 0, -i * spacing * sc.z)) * _bone_rests[i]
		_sk.set_bone_pose_position(b, xf.origin)
		_sk.set_bone_pose_rotation(b, xf.basis.get_rotation_quaternion())
		_sk.set_bone_pose_scale(b, xf.basis.get_scale())
	if _jaw_bone >= 0:
		_sk.set_bone_pose_rotation(_jaw_bone, _jaw_rest * Quaternion(Vector3.RIGHT, _jaw_open))


func _orbit_point() -> Vector3:
	return orbit_center + Vector3(cos(_angle) * orbit_radius, orbit_height + sin(_t * 0.23) * orbit_bob, sin(_angle) * orbit_radius)


func head_position() -> Vector3:
	return _trail[0]


## Put the head at a point, the body trailing out behind it along -dir.
func place_head(pos: Vector3, dir: Vector3) -> void:
	var back := -dir.normalized()
	for i in _trail.size():
		_trail[i] = pos + back * (i * _step)
	_layout()


## Lunge straight at a point (e.g. the player).
func rush(target: Vector3, rush_speed := 18.0) -> void:
	mode = Mode.RUSH
	rush_target = target
	speed = rush_speed
	arrived = false


## The head hits something it cannot pass: thrash there, then go back to circling.
func block_at(point: Vector3) -> void:
	mode = Mode.BLOCKED
	_blocked_at = point
	_blocked_t = 0.0


func return_to_orbit(orbit_speed := 9.0) -> void:
	mode = Mode.ORBIT
	speed = orbit_speed
	# continue the orbit from wherever the head is now
	var d := head_position() - orbit_center
	_angle = atan2(d.z, d.x)


func _process(delta: float) -> void:
	_t += delta
	var head := _trail[0]
	var target := head
	match mode:
		Mode.ORBIT:
			_angle += orbit_dir * speed * delta / maxf(orbit_radius, 1.0)
			target = _orbit_point()
		Mode.RUSH:
			target = rush_target
			if head.distance_to(rush_target) < 1.5:
				arrived = true
		Mode.BLOCKED:
			_blocked_t += delta
			# jaw snapping and thrashing at the opening
			var thrash := Vector3(sin(_t * 9.0) * 1.2, sin(_t * 13.0) * 0.6, -absf(sin(_t * 5.0)) * 1.5)
			target = _blocked_at + thrash
			_eye_mat.emission_energy_multiplier = 3.0 + sin(_t * 30.0) * 1.5
			if _blocked_t > 4.5:
				return_to_orbit()
	var to := target - head
	var step := minf(to.length(), speed * delta * (3.0 if mode == Mode.BLOCKED else 1.0))
	if step > 0.0001:
		head += to.normalized() * step
	# undulate sideways a little
	_advance(head)
	_layout()
	# the jaw: barely parted while it circles, wide when it comes for you, snapping when it's stuck
	var want := 0.12 + sin(_t * 0.7) * 0.05
	if mode == Mode.RUSH:
		want = 0.55
	elif mode == Mode.BLOCKED:
		want = 0.35 + absf(sin(_t * 7.0)) * 0.4
	_jaw_open = lerpf(_jaw_open, want, clampf(delta * 6.0, 0.0, 1.0))
	if _jaw:
		_jaw.rotation.x = -_jaw_open
	_pose_model()


func _advance(new_head: Vector3) -> void:
	if new_head.distance_to(_trail[0]) < 0.0001:
		return
	_trail[0] = new_head
	if _trail.size() > 1 and _trail[0].distance_to(_trail[1]) >= _step:
		_trail.insert(0, new_head)
		var needed := int(segments * spacing / _step) + 3
		while _trail.size() > needed:
			_trail.pop_back()


func _layout() -> void:
	for i in segments:
		var d := i * spacing / _step
		var a := int(d)
		var f := d - a
		var p0: Vector3 = _trail[mini(a, _trail.size() - 1)]
		var p1: Vector3 = _trail[mini(a + 1, _trail.size() - 1)]
		var pos := p0.lerp(p1, f)
		# a slow travelling wave down the body
		var wave := sin(_t * 2.0 - i * 0.45) * 0.6 * (float(i) / segments)
		var ahead: Vector3 = _trail[maxi(a - 1, 0)] if a > 0 else pos + (p0 - p1)
		var fwd := (ahead - pos)
		if fwd.length() < 0.001:
			fwd = Vector3.FORWARD
		var side := fwd.normalized().cross(Vector3.UP)
		_segs[i].global_position = pos + side * wave
		_segs[i].look_at(_segs[i].global_position + fwd.normalized(), Vector3.UP if absf(fwd.normalized().y) < 0.98 else Vector3.RIGHT)
