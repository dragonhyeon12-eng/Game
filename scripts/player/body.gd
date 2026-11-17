class_name PlayerBody
extends Node3D
## The dreamer's own body (models/player.glb, made by tools/creatures/player.py), standing under the
## first-person camera: look down and you see your shirt, legs and bare feet; it casts your shadow.
##
## Its head and arms live on HIDDEN_LAYER, which the first-person camera does not draw (they would block
## the view and double the first-person hands) but which shadows - and later mirrors - still use.
##
## Animation is procedural, driven every frame by what the player is really doing: walking/running in
## step with the ground speed (backwards too), crouching (legs folded by two-bone IK so the feet stay
## planted), airborne, swimming (body tilted forward, flutter kick, breaststroke arms).
## Rotations are written in skeleton space (X right, Y up, -Z forward) and converted to each bone's frame.

const HIDDEN_LAYER := 1 << 19          # render layer 20
const BACK_OFFSET := 0.17              # body sits a little behind the eyes, so you never look into your chest
const ARM_REST_DEG := 50.0             # the model's A-pose (see tools/creatures/player.py)

var player: Player
var _model: Node3D
var _sk: Skeleton3D
var _ids := {}
var _B := {}                           # bone -> global rest rotation
var _L := {}                           # bone -> local rest rotation
var _hip_rest := Vector3.ZERO
var _thigh_len := 0.41
var _shin_len := 0.415
var _ankle_h := 0.09
var _R := {}
var _phase := 0.0
var _t := 0.0
var _crouch := 0.0
var _air := 0.0
var _swim := 0.0
var _amp := 0.0


## The body, or null if there is no model file.
static func create(p: Player) -> PlayerBody:
	var model := Models.instance(["player"])
	if model == null:
		return null
	var b := PlayerBody.new()
	b.player = p
	b._model = model
	return b


func _ready() -> void:
	position = Vector3(0, 0, BACK_OFFSET)
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
	var hip := _sk.get_bone_global_rest(_ids["thigh.L"]).origin
	var knee := _sk.get_bone_global_rest(_ids["shin.L"]).origin
	var ankle := _sk.get_bone_global_rest(_ids["foot.L"]).origin
	_thigh_len = hip.distance_to(knee)
	_shin_len = knee.distance_to(ankle)
	_ankle_h = ankle.y
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var gi := mi as GeometryInstance3D
		if mi.name.begins_with("PlayerHead") or mi.name.begins_with("PlayerArms"):
			gi.layers = HIDDEN_LAYER
	if player and player.camera:
		player.camera.cull_mask &= ~HIDDEN_LAYER


func _rot(bone: String, axis: Vector3, deg: float) -> void:
	_R[bone] = Quaternion(axis, deg_to_rad(deg)) * _R.get(bone, Quaternion.IDENTITY)


## Two-bone leg IK in the sagittal plane: thigh forward / knee bend (degrees) for a hip height.
func _fold(hip_height: float) -> Vector2:
	var d := clampf(hip_height - _ankle_h, 0.12, _thigh_len + _shin_len - 0.001)
	var a := _thigh_len
	var b := _shin_len
	var knee := PI - acos(clampf((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	var thigh := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	return Vector2(rad_to_deg(thigh), rad_to_deg(knee))


func _process(delta: float) -> void:
	if _sk == null or player == null:
		return
	_t += delta
	_R.clear()
	var k := clampf(delta * 8.0, 0.0, 1.0)
	var grounded: bool = player.is_on_floor() or (Game.zone != null and Game.zone.has_method("walk_underwater") and Game.zone.walk_underwater())
	_crouch = lerpf(_crouch, 1.0 if player.is_crouched() else 0.0, k)
	_air = lerpf(_air, 0.0 if grounded or player.swimming else 1.0, clampf(delta * 6.0, 0.0, 1.0))
	_swim = lerpf(_swim, 1.0 if player.swimming else 0.0, clampf(delta * 3.0, 0.0, 1.0))

	# walking: phase advances with distance travelled (negative when walking backwards)
	var local_v: Vector3 = player.global_transform.basis.inverse() * player.velocity
	var ground_speed := Vector2(local_v.x, local_v.z).length()
	var dir := -1.0 if local_v.z > 0.15 else 1.0
	_amp = lerpf(_amp, clampf(ground_speed / 2.6, 0.0, 1.35) if grounded else 0.0, k)
	_phase += delta * ground_speed / 1.35 * TAU * dir
	var s := sin(_phase)
	var X := Vector3.RIGHT
	var Z := Vector3.BACK

	# arms hang down from the A-pose, slightly away from the body, and swing against the legs
	_rot("upperarm.L", Z, ARM_REST_DEG - 6.0)
	_rot("upperarm.R", Z, -(ARM_REST_DEG - 6.0))
	_rot("upperarm.L", X, -22.0 * _amp * s)
	_rot("upperarm.R", X, 22.0 * _amp * s)
	_rot("forearm.L", X, 10.0 + 14.0 * _amp * maxf(0.0, -s))
	_rot("forearm.R", X, 10.0 + 14.0 * _amp * maxf(0.0, s))

	# legs: stride + knee flexion in swing, then crouch folding and the airborne tuck on top
	var fold := _fold(lerpf(_hip_rest.y, 0.42, _crouch))
	var knee_l := 6.0 * _amp + 42.0 * _amp * maxf(0.0, sin(_phase + 1.3))
	var knee_r := 6.0 * _amp + 42.0 * _amp * maxf(0.0, sin(_phase + 1.3 + PI))
	var stride := 26.0 * _amp
	for side in ["L", "R"]:
		var sw := s if side == "L" else -s
		var kn := knee_l if side == "L" else knee_r
		var thigh := sw * stride + fold.x * _crouch + 22.0 * _air
		var shin := -(kn + fold.y * _crouch + 38.0 * _air)
		_rot("thigh." + side, X, thigh)
		_rot("shin." + side, X, shin)
		_rot("foot." + side, X, -(thigh + shin) * 0.8 * (1.0 - _swim))     # keep the sole level

	# torso: leans into a crouch, a small sway while walking, breathing
	_rot("spine", X, -16.0 * _crouch)
	_rot("chest", X, -8.0 * _crouch + sin(_t * 1.6) * 1.2)
	_rot("spine", Vector3.UP, 4.0 * _amp * s)
	var hip_drop := (_hip_rest.y - lerpf(_hip_rest.y, 0.42, _crouch))
	var bob := 0.025 * _amp * absf(cos(_phase))

	# swimming: tip forward, flutter kick, pointed feet, a slow breaststroke
	if _swim > 0.01:
		var kick := sin(_t * 7.0)
		for side in ["L", "R"]:
			var sw := kick if side == "L" else -kick
			_rot("thigh." + side, X, sw * 16.0 * _swim)
			_rot("shin." + side, X, -(12.0 + 10.0 * maxf(0.0, sw)) * _swim)
			_rot("foot." + side, X, -45.0 * _swim)
		var stroke := sin(_t * 2.4)
		_rot("upperarm.L", X, (150.0 + 20.0 * stroke) * _swim)
		_rot("upperarm.R", X, (150.0 + 20.0 * stroke) * _swim)
		_rot("upperarm.L", Z, -35.0 * maxf(0.0, -stroke) * _swim)
		_rot("upperarm.R", Z, 35.0 * maxf(0.0, -stroke) * _swim)

	# write the pose
	for bone in _ids:
		var q: Quaternion = _R.get(bone, Quaternion.IDENTITY)
		var b: Quaternion = _B[bone]
		_sk.set_bone_pose_rotation(_ids[bone], _L[bone] * (b.inverse() * q * b))
	_sk.set_bone_pose_position(_ids["hips"], _hip_rest + Vector3(0, bob - hip_drop, 0.1 * _crouch))
	# the whole body pitches forward around the shoulders when swimming
	var pivot := Vector3(0, 1.45, 0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-78.0 * _swim))
	_model.transform = Transform3D(tilt, pivot - tilt * pivot)
