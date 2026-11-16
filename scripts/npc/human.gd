class_name Human
extends Node3D
## A procedurally built, articulated person (no model files): rounded limbs with knees and elbows,
## hands with fingers, a face (eyes with lids, brows, nose, ears, mouth with a moving jaw), hair and
## clothes. Animates breathing, blinking, head turning, talking, walking and sitting.
## Origin at the feet, facing +Z. Height 1.0 = ~1.75 m.

var height := 1.0
var seated := false
var walk_speed := 0.0          # set > 0 while walking (m/s)
var look_target := Vector3.INF # world point to look at, INF = idle glances

var _hips: Node3D
var _spine: Node3D
var _chest: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _lids: Array[Node3D] = []
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _hands: Array[Node3D] = []
var _t := randf() * 10.0
var _next_blink := randf_range(1.0, 4.0)
var _blink := 0.0
var _talk := 0.0
var _phase := 0.0


## look keys: skin, hair, hair_style (short|long|bun|bald|curly), shirt, pants, shoes, height,
##            seated, sleeves (short|long), apron, cap, cap_color, build (0.85 slim .. 1.15 broad)
func build(l: Dictionary) -> void:
	height = l.get("height", 1.0)
	seated = l.get("seated", false)
	var h := height
	var b: float = l.get("build", 1.0)
	var skin := Shapes.skin(l.get("skin", Color(0.82, 0.62, 0.5)))
	var shirt := Shapes.surface("fabric", l.get("shirt", Color(0.3, 0.5, 0.8)))
	var pants := Shapes.surface("fabric", l.get("pants", Color(0.2, 0.22, 0.28)))
	var shoes := Shapes.material(l.get("shoes", Color(0.07, 0.06, 0.06)), 0.45)
	var hair_col: Color = l.get("hair", Color(0.15, 0.1, 0.07))
	var hair := Shapes.material(hair_col, 0.75)
	var long_sleeves: bool = l.get("sleeves", "short") == "long"

	# ---- hips & legs
	_hips = _pivot(self, Vector3(0, 0.92 * h, 0))
	_mesh(_hips, "sphere", Vector3(0, 0.0, 0), Vector3(0.34 * b, 0.22, 0.22 * b), pants)
	for side in [-1.0, 1.0]:
		var thigh := _pivot(_hips, Vector3(0.095 * side * b, -0.04, 0))
		_mesh(thigh, "capsule", Vector3(0, -0.22 * h, 0), Vector3(0.155 * b, 0.25 * h, 0.16 * b), pants)
		var knee := _pivot(thigh, Vector3(0, -0.44 * h, 0))
		_mesh(knee, "capsule", Vector3(0, -0.21 * h, 0), Vector3(0.12, 0.23 * h, 0.125), pants)
		var foot := _pivot(knee, Vector3(0, -0.43 * h, 0))
		_mesh(foot, "capsule", Vector3(0, -0.02, 0.05), Vector3(0.1, 0.07, 0.26), shoes, Vector3(90, 0, 0))
		_mesh(foot, "box", Vector3(0, -0.045, 0.05), Vector3(0.1, 0.02, 0.27), shoes)
		_thighs.append(thigh)
		_knees.append(knee)

	# ---- torso
	_spine = _pivot(_hips, Vector3(0, 0.06, 0))
	_mesh(_spine, "capsule", Vector3(0, 0.14 * h, 0), Vector3(0.3 * b, 0.16 * h, 0.2 * b), shirt)
	_chest = _pivot(_spine, Vector3(0, 0.28 * h, 0))
	_mesh(_chest, "sphere", Vector3(0, 0.06 * h, 0), Vector3(0.38 * b, 0.34 * h, 0.24 * b), shirt)
	if l.get("apron", false):
		var apron := Shapes.surface("fabric", Color(0.85, 0.85, 0.82))
		_mesh(_spine, "capsule", Vector3(0, 0.1 * h, 0.075 * b), Vector3(0.3 * b, 0.21 * h, 0.06), apron)
		_mesh(_chest, "box", Vector3(0, 0.02 * h, 0.115 * b), Vector3(0.2 * b, 0.16 * h, 0.012), apron)
	# collar
	_mesh(_chest, "cylinder", Vector3(0, 0.22 * h, 0), Vector3(0.14, 0.03, 0.12), shirt)

	# ---- arms
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(_chest, Vector3(0.2 * side * b, 0.17 * h, 0))
		_mesh(shoulder, "sphere", Vector3(-0.015 * side, -0.02, 0), Vector3(0.105, 0.1, 0.11) * b, shirt)
		_mesh(shoulder, "capsule", Vector3(0, -0.14 * h, 0), Vector3(0.1 * b, 0.155 * h, 0.1 * b), shirt)
		var elbow := _pivot(shoulder, Vector3(0, -0.29 * h, 0))
		_mesh(elbow, "capsule", Vector3(0, -0.13 * h, 0), Vector3(0.085, 0.145 * h, 0.085), shirt if long_sleeves else skin)
		var hand := _pivot(elbow, Vector3(0, -0.27 * h, 0))
		_build_hand(hand, skin, side)
		shoulder.rotation_degrees.z = 4.0 * side
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		_hands.append(hand)

	# ---- neck & head
	_neck = _pivot(_chest, Vector3(0, 0.19 * h, 0))
	_mesh(_neck, "cylinder", Vector3(0, 0.035, -0.005), Vector3(0.11, 0.1, 0.11), skin)
	_head = _pivot(_neck, Vector3(0, 0.06, 0))
	_mesh(_head, "sphere", Vector3(0, 0.11, 0), Vector3(0.19, 0.23, 0.21), skin)              # cranium
	_jaw = _pivot(_head, Vector3(0, 0.06, 0.0))
	_mesh(_jaw, "sphere", Vector3(0, -0.005, 0.02), Vector3(0.165, 0.13, 0.17), skin)        # jaw / chin
	_mesh(_head, "capsule", Vector3(0, 0.09, 0.105), Vector3(0.03, 0.025, 0.035), skin, Vector3(-15, 0, 0))  # nose
	for side in [-1.0, 1.0]:
		_mesh(_head, "sphere", Vector3(0.097 * side, 0.1, 0.0), Vector3(0.03, 0.055, 0.04), skin)          # ear
		_mesh(_head, "sphere", Vector3(0.04 * side, 0.125, 0.088), Vector3(0.034, 0.024, 0.02), Shapes.material(Color(0.93, 0.92, 0.9), 0.2))  # eye white
		_mesh(_head, "sphere", Vector3(0.04 * side, 0.125, 0.097), Vector3.ONE * 0.014, Shapes.material(Color(0.12, 0.08, 0.05), 0.1))      # iris
		var lid := _pivot(_head, Vector3(0.04 * side, 0.137, 0.095))
		_mesh(lid, "box", Vector3(0, -0.006, 0), Vector3(0.038, 0.026, 0.012), skin)
		lid.scale.y = 0.05
		_lids.append(lid)
		_mesh(_head, "box", Vector3(0.042 * side, 0.152, 0.094), Vector3(0.042, 0.008, 0.012), hair, Vector3(0, 0, -8 * side))  # brow
	_mesh(_jaw, "box", Vector3(0, 0.0, 0.1), Vector3(0.042, 0.006, 0.01), Shapes.material(Color(0.5, 0.25, 0.23), 0.5))  # mouth

	# ---- hair
	match l.get("hair_style", "short"):
		"short":
			_mesh(_head, "sphere", Vector3(0, 0.15, -0.012), Vector3(0.205, 0.17, 0.225), hair)
		"long":
			_mesh(_head, "sphere", Vector3(0, 0.14, -0.015), Vector3(0.21, 0.19, 0.23), hair)
			_mesh(_head, "capsule", Vector3(0, 0.0, -0.07), Vector3(0.2, 0.14, 0.09), hair)
		"bun":
			_mesh(_head, "sphere", Vector3(0, 0.15, -0.012), Vector3(0.205, 0.17, 0.225), hair)
			_mesh(_head, "sphere", Vector3(0, 0.2, -0.11), Vector3.ONE * 0.09, hair)
		"curly":
			for i in 9:
				var a := i * TAU / 9.0
				_mesh(_head, "sphere", Vector3(sin(a) * 0.07, 0.19 + 0.02 * sin(a * 3.0), cos(a) * 0.07 - 0.02), Vector3.ONE * 0.1, hair)
		_:
			pass
	if l.get("cap", false):
		var cap := Shapes.surface("fabric", l.get("cap_color", Color.RED))
		_mesh(_head, "sphere", Vector3(0, 0.2, -0.005), Vector3(0.215, 0.12, 0.23), cap)
		_mesh(_head, "box", Vector3(0, 0.185, 0.12), Vector3(0.18, 0.012, 0.11), cap, Vector3(-8, 0, 0))

	if seated:
		for i in 2:
			_thighs[i].rotation_degrees.x = -90
			_knees[i].rotation_degrees.x = 90
			_elbows[i].rotation_degrees.x = -55
		_hips.position.y = 0.48


func _build_hand(hand: Node3D, skin: Material, side: float) -> void:
	_mesh(hand, "sphere", Vector3(0, -0.045, 0), Vector3(0.075, 0.1, 0.035), skin)        # palm
	for f in 4:
		var x := (-0.027 + f * 0.018) * side
		var length: float = [0.06, 0.07, 0.066, 0.052][f]
		_mesh(hand, "capsule", Vector3(x, -0.095 - length * 0.5, 0.004), Vector3(0.016, length * 0.5, 0.018), skin, Vector3(10, 0, 0))
	_mesh(hand, "capsule", Vector3(0.04 * side, -0.06, 0.018), Vector3(0.018, 0.03, 0.02), skin, Vector3(25, 0, -35 * side))


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, kind: String, pos: Vector3, scale_v: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func hand(i := 1) -> Node3D:
	return _hands[i]


## Mouth moves for a little while (called when a line of dialogue is shown).
func speak(seconds := 1.6) -> void:
	_talk = seconds


func freeze_pose() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	# nobody can see the details of a person 35 m away: don't animate them
	var cam := get_viewport().get_camera_3d()
	if cam and walk_speed <= 0.05 and cam.global_position.distance_squared_to(global_position) > 1225.0:
		return
	var h := height

	# breathing
	_chest.scale = Vector3(1.0, 1.0 + 0.012 * sin(_t * 1.7), 1.0 + 0.02 * sin(_t * 1.7))

	# blinking
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 5.5)
	_blink = maxf(0.0, _blink - delta)
	var lid := 1.0 if _blink > 0.0 else 0.05
	for l in _lids:
		l.scale.y = lid

	# talking
	_talk = maxf(0.0, _talk - delta)
	_jaw.rotation_degrees.x = (absf(sin(_t * 14.0)) * 9.0 + sin(_t * 23.0) * 2.0) if _talk > 0.0 else 0.0

	# head look
	var target := Vector3.ZERO
	if look_target != Vector3.INF:
		var local := _neck.global_transform.affine_inverse() * look_target
		target = Vector3(clampf(-rad_to_deg(atan2(local.y, Vector2(local.x, local.z).length())), -25, 20),
			clampf(rad_to_deg(atan2(local.x, local.z)), -70, 70), 0)
	else:
		target = Vector3(0, sin(_t * 0.3) * 25.0, 0)
	_head.rotation_degrees = _head.rotation_degrees.lerp(target, clampf(delta * 4.0, 0.0, 1.0))

	if seated:
		return

	if walk_speed > 0.05:
		_phase += delta * walk_speed * 2.6
		var swing := sin(_phase)
		for i in 2:
			var s := swing if i == 0 else -swing
			_thighs[i].rotation_degrees.x = s * 28.0
			_knees[i].rotation_degrees.x = maxf(0.0, -cos(_phase + (0.0 if i == 0 else PI))) * 45.0
			_shoulders[i].rotation_degrees.x = -s * 22.0
			_elbows[i].rotation_degrees.x = -18.0 - maxf(0.0, s) * 15.0
		_hips.position.y = 0.92 * h + absf(cos(_phase)) * 0.035
		_spine.rotation_degrees.y = swing * 5.0
	else:
		# relaxed standing, a slow weight shift
		var sway := sin(_t * 0.6)
		_hips.position = Vector3(sway * 0.012, 0.92 * h, 0)
		for i in 2:
			_thighs[i].rotation_degrees.x = lerpf(_thighs[i].rotation_degrees.x, 0.0, delta * 5.0)
			_knees[i].rotation_degrees.x = lerpf(_knees[i].rotation_degrees.x, 2.0, delta * 5.0)
			_shoulders[i].rotation_degrees.x = lerpf(_shoulders[i].rotation_degrees.x, 2.0 * sin(_t * 0.8 + i), delta * 3.0)
			_elbows[i].rotation_degrees.x = lerpf(_elbows[i].rotation_degrees.x, -10.0, delta * 3.0)
		_spine.rotation_degrees.y = 0.0
