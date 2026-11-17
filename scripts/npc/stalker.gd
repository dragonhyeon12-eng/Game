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


## Smooth periodic curve through keyframes [[phase 0..1, value], ...] (wraps around).
static func _curve(keys: Array, p: float) -> float:
	p = fposmod(p, 1.0)
	for k in keys.size():
		var a: Array = keys[k]
		var b: Array = keys[(k + 1) % keys.size()]
		var pb: float = b[0] if k + 1 < keys.size() else b[0] + 1.0
		if p >= a[0] and p <= pb:
			var pa: float = a[0]
			var f: float = (p - pa) / maxf(pb - pa, 0.0001)
			f = f * f * (3.0 - 2.0 * f)
			return lerpf(float(a[1]), float(b[1]), f)
	return float(keys[0][1])


# One stride = two steps. Left leg at phase p, right at p + 0.5. Positive thigh = forward, knee = bend.
const THIGH_WALK := [[0.0, 26.0], [0.5, -22.0], [0.72, -6.0], [0.88, 34.0]]
const KNEE_WALK := [[0.0, 6.0], [0.12, 22.0], [0.45, 8.0], [0.68, 64.0], [0.85, 30.0]]
const THIGH_RUN := [[0.0, 38.0], [0.42, -34.0], [0.6, -10.0], [0.8, 62.0]]
const KNEE_RUN := [[0.0, 18.0], [0.15, 40.0], [0.4, 22.0], [0.62, 118.0], [0.82, 70.0]]

var _held := 0.0          # a stutter: the pose freezes for a moment while it keeps moving
var _hold_t := 3.0
var _look_target := Vector3.ZERO
var _look_w := 0.0


## Where its head turns to (the player, usually). Its body doesn't have to agree.
func watch(point: Vector3) -> void:
	_look_target = point
	_look_w = 1.0


func _process(delta: float) -> void:
	_t += delta
	if _sk == null:
		return
	# the stutter: every few seconds the animation hangs for a split second, then jerks on
	_hold_t -= delta
	if _held > 0.0:
		_held -= delta
		return
	if _hold_t <= 0.0:
		_hold_t = randf_range(1.8, 4.5)
		_held = randf_range(0.08, 0.22)
	_R.clear()
	var moving := speed > 0.1
	var run := clampf((speed - 2.0) / 1.7, 0.0, 1.0)
	var walk := clampf(speed / 1.2, 0.0, 1.0)
	# stride length grows with speed; the cadence is slow and heavy when walking, frantic when running
	_phase += delta * speed / lerpf(2.1, 3.4, run)
	var X := Vector3.RIGHT
	var Z := Vector3.BACK
	var Y := Vector3.UP

	# --- legs, with a limp: the right leg drags (shorter forward swing, stiffer knee) while walking
	var hip_drop := 0.0
	for side in ["L", "R"]:
		var p := _phase + (0.0 if side == "L" else 0.5)
		var limp := 0.55 if side == "R" else 1.0
		limp = lerpf(1.0, limp, 1.0 - run)
		var th := lerpf(_curve(THIGH_WALK, p), _curve(THIGH_RUN, p), run) * walk
		var kn := lerpf(_curve(KNEE_WALK, p), _curve(KNEE_RUN, p), run) * walk
		if th > 0.0:
			th *= limp
		kn *= lerpf(limp, 1.0, 0.4)
		_rot("thigh." + side, X, th + 8.0 * run)
		_rot("shin." + side, X, -kn - 4.0)
		# the foot: toes up as the heel strikes, pointed as it leaves the ground
		_rot("foot." + side, X, kn * 0.35 - th * 0.25)
		# a slight outward splay: it walks wide
		_rot("thigh." + side, Z, (4.0 if side == "L" else -4.0) * walk)
		if side == "R" and fposmod(p, 1.0) < 0.5:
			hip_drop = sin(fposmod(p, 1.0) * TAU) * 0.06 * (1.0 - run) * walk   # dropping onto the bad leg

	# --- body: pitched forward, rolling with each step, twisting against the legs
	var s := sin(_phase * TAU)
	var lean := 10.0 + 30.0 * run
	_rot("hips", X, -lean * 0.4)
	_rot("spine", X, -lean * 0.6 - 6.0)
	_rot("chest", X, -lean * 0.5 - 8.0)
	_rot("spine", Y, s * 9.0 * walk)
	_rot("chest", Y, -s * 14.0 * walk)
	_rot("hips", Z, s * 5.0 * walk + hip_drop * 60.0)
	_rot("chest", Z, -s * 6.0 * walk)

	# --- arms: too long, hanging, swinging late and loose; flailing behind it when it runs
	for side in ["L", "R"]:
		var sg := 1.0 if side == "L" else -1.0
		var p := _phase + (0.5 if side == "L" else 0.0) - 0.12      # opposite the leg, and late
		var swing := sin(p * TAU)
		# (positive X = forward for a hanging arm)
		_rot("upperarm." + side, Z, sg * (ARM_REST_DEG - 1.0))
		# the torso leans forward; the arms still hang down (gravity), then swing
		var torso_pitch := lean * 1.5 + 14.0
		_rot("upperarm." + side, X, torso_pitch * 0.92 + (swing * (22.0 + 14.0 * run) + 6.0 * run) * walk)
		var elbow := 10.0 + 14.0 * walk + 38.0 * run * (0.4 + 0.6 * maxf(swing, 0.0))
		_rot("forearm." + side, X, elbow)
		_rot("forearm." + side, Y, sg * 10.0 * run)
		# hands flop at the wrist
		_rot("hand." + side, X, 18.0 * sin(p * TAU - 1.2) * walk + 10.0)

	# --- head: twitching; while running it stays locked level (the body heaves under it)
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.3, 2.0) if moving else randf_range(0.8, 3.5)
		_twitch = randf_range(-40.0, 40.0) if randf() < 0.6 else randf_range(-85.0, 85.0)
	_rot("neck", X, 10.0 + lean * 0.7)          # counter the lean: the face stays on you
	_rot("head", X, lean * 0.3)
	_rot("head", Z, _twitch * (0.25 if moving else 0.8))
	_rot("head", Y, _twitch * 0.3)
	if not moving:
		# standing: barely swaying, breathing, the head creeping round
		var br := sin(_t * 1.1)
		_rot("chest", X, br * 2.5)
		_rot("spine", Z, sin(_t * 0.37) * 3.0)
		_rot("upperarm.L", X, br * 3.0)
		_rot("upperarm.R", X, -br * 3.0)

	for bone in _ids:
		var q: Quaternion = _R.get(bone, Quaternion.IDENTITY)
		var b: Quaternion = _B[bone]
		_sk.set_bone_pose_rotation(_ids[bone], _L[bone] * (b.inverse() * q * b))
	# the hips bob: lowest as each foot lands; lower overall when running
	var bob := (0.07 * absf(cos(_phase * TAU)) - 0.035) * walk - 0.12 * run - hip_drop
	_sk.set_bone_pose_position(_ids["hips"], _hip_rest + Vector3(0, bob, 0.05 * run))
