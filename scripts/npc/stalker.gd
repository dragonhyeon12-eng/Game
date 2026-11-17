class_name Stalker
extends Node3D
## THE BACKROOMS' entity (models/creatures/stalker.glb, tools/creatures/player.py build_stalker):
## too tall, too thin, arms past its knees. It stands perfectly still until the power comes back on.
## Then it walks - a long lurching stride, arms swinging loose and late, head twitching - and runs.
##
## It has no pathfinding of its own: its zone gives it points to walk to (see MazeZone).
## Same rig as the player's body, posed the same way (skeleton-space rotations, see PlayerBody).

const ARM_REST_DEG := 50.0

var speed := 0.0               # current ground speed (set by move_to)
var _model: Node3D
var _sk: Skeleton3D
var _ids := {}
var _B := {}
var _L := {}
var _R := {}
var _hip_rest := Vector3.ZERO
var _phase := 0.0
var _t := 0.0
var _twitch := 0.0
var _twitch_t := 0.0
var _fallback: MeshInstance3D


func _ready() -> void:
	_model = Models.instance(["creatures/stalker"])
	if _model == null:
		# no model: a tall black shape will do
		_fallback = MeshInstance3D.new()
		_fallback.mesh = Shapes.mesh("capsule")
		_fallback.scale = Vector3(0.4, 1.2, 0.3)
		_fallback.position.y = 1.2
		_fallback.material_override = Shapes.material(Color(0.6, 0.6, 0.58), 0.8)
		add_child(_fallback)
		return
	add_child(_model)
	var found := _model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_sk = found[0]
	for i in _sk.get_bone_count():
		var n := _sk.get_bone_name(i)
		_ids[n] = i
		_B[n] = _sk.get_bone_global_rest(i).basis.get_rotation_quaternion()
		_L[n] = _sk.get_bone_rest(i).basis.get_rotation_quaternion()
	_hip_rest = _sk.get_bone_rest(_ids["hips"]).origin


## Walk toward a point at a speed; returns true when there.
func move_to(target: Vector3, spd: float, delta: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.05:
		speed = 0.0
		return true
	var step := minf(spd * delta, d)
	global_position += to / d * step
	speed = spd
	var want := atan2(to.x, to.z) + PI     # the model faces -Z
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 8.0, 0.0, 1.0))
	return d <= step


func face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z) + PI, clampf(delta * 6.0, 0.0, 1.0))


func _rot(bone: String, axis: Vector3, deg: float) -> void:
	if _ids.has(bone):
		_R[bone] = Quaternion(axis, deg_to_rad(deg)) * _R.get(bone, Quaternion.IDENTITY)


func _process(delta: float) -> void:
	_t += delta
	if _sk == null:
		return
	_R.clear()
	var run := clampf((speed - 2.0) / 2.0, 0.0, 1.0)
	var amp := clampf(speed / 2.0, 0.0, 1.3)
	_phase += delta * speed / 1.9 * TAU
	var s := sin(_phase)
	var X := Vector3.RIGHT
	var Z := Vector3.BACK
	# hunched, head forward and tilted; it leans into a run
	_rot("spine", X, -14.0 - 16.0 * run)
	_rot("chest", X, -10.0 - 8.0 * run)
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.4, 2.2)
		_twitch = randf_range(-35.0, 35.0)
	_rot("neck", X, 18.0)
	_rot("head", Z, 12.0 + _twitch * (0.3 if speed > 0.1 else 1.0))
	_rot("head", Vector3.UP, _twitch * 0.4)
	# arms hang (and swing late, loose, too far)
	_rot("upperarm.L", Z, ARM_REST_DEG - 4.0)
	_rot("upperarm.R", Z, -(ARM_REST_DEG - 4.0))
	var lag := sin(_phase - 0.9)
	_rot("upperarm.L", X, -30.0 * amp * lag - 10.0 * run)
	_rot("upperarm.R", X, 30.0 * amp * lag - 10.0 * run)
	_rot("forearm.L", X, 6.0 + 20.0 * amp * maxf(0.0, -lag))
	_rot("forearm.R", X, 6.0 + 20.0 * amp * maxf(0.0, lag))
	# legs: a long stride with a stiff knee
	for side in ["L", "R"]:
		var sw := s if side == "L" else -s
		_rot("thigh." + side, X, sw * (24.0 + 14.0 * run) * amp + 6.0 * run)
		var knee := (8.0 + 46.0 * maxf(0.0, sin(_phase + 1.2 + (0.0 if side == "L" else PI)))) * amp
		_rot("shin." + side, X, -knee)
		_rot("foot." + side, X, knee * 0.4 - sw * 6.0 * amp)
	for bone in _ids:
		var q: Quaternion = _R.get(bone, Quaternion.IDENTITY)
		var b: Quaternion = _B[bone]
		_sk.set_bone_pose_rotation(_ids[bone], _L[bone] * (b.inverse() * q * b))
	_sk.set_bone_pose_position(_ids["hips"], _hip_rest + Vector3(0, 0.05 * amp * absf(cos(_phase)) - 0.08 * run, 0))
