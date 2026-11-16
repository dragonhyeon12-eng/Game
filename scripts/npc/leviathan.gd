class_name Leviathan
extends Node3D
## A sea serpent dozens of metres long: black, with blue bioluminescent spots along its flanks and pale
## bones breaking through its back. It is only ever half-seen through the murk - mostly as moving lights.
##
## The body is a chain of segments that follow the head's trail, so it moves like a snake.
## Behaviours: ORBIT (circle at a distance, rising and sinking), RUSH (straight at a target),
## BLOCKED (slammed into something too small: thrashes, then withdraws).

enum Mode { ORBIT, RUSH, BLOCKED }

var mode := Mode.ORBIT
var segments := 30
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
var _segs: Array[Node3D] = []
var _trail: Array[Vector3] = []   # head positions, newest first, every `_step` metres
var _step := 0.6
var _blocked_t := 0.0
var _blocked_at := Vector3.ZERO
var _eye_mat: StandardMaterial3D


func _ready() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.015, 0.018, 0.022)
	skin.roughness = 0.35
	skin.metallic = 0.2
	var glow := Shapes.material(Color(0.2, 0.7, 1.0), 0.5, 9.0)
	var glow_dim := Shapes.material(Color(0.15, 0.45, 0.9), 0.5, 5.0)
	var bone := Shapes.material(Color(0.62, 0.6, 0.55), 0.7)
	_eye_mat = Shapes.material(Color(0.4, 0.9, 1.0), 0.3, 8.0)

	for i in segments:
		var seg := Node3D.new()
		add_child(seg)
		var u := float(i) / (segments - 1)
		# thick behind the head, tapering to a thin tail
		var r := thickness * (2.2 * (1.0 - u) * (0.55 + 1.6 * u * (1.0 - u)) + 0.25)
		var body := _mesh(seg, "sphere", Vector3.ZERO, Vector3(r * 1.0, r * 0.85, spacing * 1.35), skin)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# bioluminescent spots along both flanks
		if i % 2 == 0 and i > 0:
			for side in [-1.0, 1.0]:
				_mesh(seg, "sphere", Vector3(r * 0.5 * side, -r * 0.05, 0), Vector3.ONE * (0.22 + r * 0.1), glow if i % 4 == 0 else glow_dim)
		# a glowing line under the belly
		if i % 3 == 1:
			_mesh(seg, "capsule", Vector3(0, -r * 0.4, 0), Vector3(0.08, spacing * 0.35, 0.08), glow_dim, Vector3(90, 0, 0))
		# bones breaking through the back: a spine ridge and ribs
		if i % 3 == 0 and i > 1 and u < 0.85:
			_mesh(seg, "cone", Vector3(0, r * 0.55, 0), Vector3(0.18, r * 0.9, 0.18) * thickness, bone, Vector3(-25, 0, 0))
			for side in [-1.0, 1.0]:
				_mesh(seg, "capsule", Vector3(r * 0.55 * side, r * 0.2, 0), Vector3(0.08, r * 0.55, 0.08), bone, Vector3(0, 0, -60 * side))
		# its own light falls on its body: you glimpse black hide and bone, never the whole of it
		if i % 7 == 2:
			var l := OmniLight3D.new()
			l.light_color = Color(0.25, 0.65, 1.0)
			l.light_energy = 2.0 * thickness
			l.omni_range = r * 4.0 + 4.0
			l.position = Vector3(0, -r * 0.6, 0)
			seg.add_child(l)
		_segs.append(seg)

	# the head: long, low, a jaw full of pale needles, two cold eyes
	_head = _segs[0]
	var hr := thickness * 2.0
	_mesh(_head, "sphere", Vector3(0, 0, -hr * 1.1), Vector3(hr * 1.1, hr * 0.7, hr * 2.6), skin)
	_mesh(_head, "sphere", Vector3(0, -hr * 0.3, -hr * 1.3), Vector3(hr * 0.9, hr * 0.35, hr * 2.2), skin)
	for side in [-1.0, 1.0]:
		_mesh(_head, "sphere", Vector3(hr * 0.42 * side, hr * 0.18, -hr * 1.6), Vector3.ONE * hr * 0.16, _eye_mat)
		for k in 6:
			_mesh(_head, "cone", Vector3(hr * (0.35 - k * 0.04) * side, -hr * 0.25, -hr * (1.9 - k * 0.35)), Vector3(0.06, hr * 0.28, 0.06) * thickness, bone, Vector3(180, 0, 0))
	for k in 4:
		_mesh(_head, "cone", Vector3(0, hr * 0.45, -hr * (0.3 + k * 0.5)), Vector3(0.14, hr * 0.5, 0.14) * thickness, bone, Vector3(-30, 0, 0))

	var p := _orbit_point()
	global_position = p
	for i in int(segments * spacing / _step) + 2:
		_trail.append(p - Vector3(0, 0, -i * _step).rotated(Vector3.UP, _angle))
	_layout()


func _mesh(parent: Node3D, kind: String, pos: Vector3, scl: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


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
			_eye_mat.emission_energy_multiplier = 8.0 + sin(_t * 30.0) * 4.0
			if _blocked_t > 4.5:
				return_to_orbit()
	var to := target - head
	var step := minf(to.length(), speed * delta * (3.0 if mode == Mode.BLOCKED else 1.0))
	if step > 0.0001:
		head += to.normalized() * step
	# undulate sideways a little
	_advance(head)
	_layout()


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
