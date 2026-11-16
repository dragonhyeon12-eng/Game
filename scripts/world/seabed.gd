class_name SeabedZone
extends Zone
## THE DEEP, part two: the sea floor.
##
## Pitch dark. You walk slowly. A light can be pictured into your hand (hold Q) - only a light.
## There is a path, but you can't see it: only glowing rocks mark it, here and there. Off the path,
## the leviathan that circles overhead comes for you. At the end, a sea cave in a cliff: it charges,
## but it cannot fit through the opening. At the back of the cave is a glowing doorway: the way out.

const PATH := [
	Vector3(0, 0, 0), Vector3(4, 0, -14), Vector3(-3, 0, -28), Vector3(-11, 0, -40), Vector3(-7, 0, -55),
	Vector3(4, 0, -66), Vector3(12, 0, -80), Vector3(8, 0, -96), Vector3(-2, 0, -108), Vector3(-4, 0, -122),
	Vector3(1.5, 0, -134), Vector3(2, 0, -146),
]
const SAFE_DISTANCE := 5.5      # metres from the path before it notices
const KILL_DISTANCE := 11.0
const GRACE := 3.0              # seconds off the path before it comes
const CLIFF_Z := -140.0
const MOUTH := Vector3(2, 0, -140)
const MOUTH_W := 2.4
const MOUTH_H := 3.0
const CHASE_START_Z := -118.0

var leviathan: Leviathan
var _off_path_t := 0.0
var _warned := false
var _chase := false
var _safe := false
var _t := 0.0
var _hint := 0
var _heart := 0.0


func zone_id() -> String: return "seabed"
func is_nightmare() -> bool: return true
func allows_manifestation() -> bool: return true
func manifest_allowlist() -> Array: return ["flashlight"]
func fear_floor() -> float: return 25.0
func fear_decay() -> float: return 1.0
func floor_surface() -> String: return "grass"
func walk_speed() -> float: return 1.3
func sprint_speed() -> float: return 2.4
func water_level_at(_p: Vector3) -> float: return 1000.0   # everything is under the sea
func breathable_at(_p: Vector3) -> bool: return true
func swim_drift_at(_p: Vector3) -> float: return -3.0      # weighted to the floor
func gravity_scale_at(_p: Vector3) -> float: return 0.4
## You walk here (slowly), you don't swim.
func walk_underwater() -> bool: return true


func player_start() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(-15)), Vector3(0, 0.05, 4))


## Distance from a point to the (invisible) path.
static func distance_to_path(p: Vector3) -> float:
	var best := INF
	var q := Vector2(p.x, p.z)
	for i in PATH.size() - 1:
		var a := Vector2(PATH[i].x, PATH[i].z)
		var b := Vector2(PATH[i + 1].x, PATH[i + 1].z)
		var ab := b - a
		var tt := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * tt))
	return best


# ------------------------------------------------------------------ build

func build() -> void:
	var sand := Color(0.11, 0.12, 0.11)
	var rock := Color(0.06, 0.07, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	# the floor, with low mounds and scattered stones
	box(Vector3(0, -0.5, -60), Vector3(400, 1.0, 400), sand, true, 0.0, "concrete")
	for i in 70:
		var p := Vector3(rng.randf_range(-90, 90), 0, rng.randf_range(-150, 40))
		if distance_to_path(p) < 3.0:
			continue
		var s := rng.randf_range(0.4, 3.5)
		var tint := rock.lightened(rng.randf_range(0, 0.06))
		var yaw := rng.randf_range(0, 360)   # (random numbers drawn in the same order either way)
		if nature("rocks", p, s * 1.4, yaw, true):
			if s > 1.5:
				blocker(p + Vector3(0, s * 0.3, 0), Vector3(s * 1.1, s * 0.6, s * 0.9))
			continue
		shape_at("sphere", p + Vector3(0, s * 0.2, 0), Vector3(s * 1.4, s * 0.8, s * 1.1), tint, s > 1.5,
			Vector3(0, yaw, 0), "concrete")
	# pale drifting particles would need a particle system; instead: dead coral and bones on the floor
	for i in 40:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-140, 30))
		shape_at("capsule", p + Vector3(0, 0.15, 0), Vector3(0.12, rng.randf_range(0.4, 1.2), 0.12), Color(0.55, 0.53, 0.48), false,
			Vector3(rng.randf_range(60, 100), rng.randf_range(0, 360), 0))

	# glowing rocks: the only marks of the path
	var marks := 0
	for i in PATH.size() - 1:
		var a: Vector3 = PATH[i]
		var b: Vector3 = PATH[i + 1]
		var steps := int(a.distance_to(b) / 9.0) + 1
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			var side := (b - a).normalized().cross(Vector3.UP) * (1.6 if marks % 2 == 0 else -1.6)
			p += side + Vector3(0, 0.25, 0)
			part("sphere", p, Vector3(0.6, 0.45, 0.55), Color(0.15, 0.85, 0.75), null, Vector3(0, marks * 37.0, 0), 2.5)
			part("sphere", p + Vector3(0.3, -0.05, 0.2), Vector3(0.3, 0.25, 0.3), Color(0.15, 0.7, 0.9), null, Vector3.ZERO, 1.8)
			omni(p + Vector3(0, 0.6, 0), Color(0.2, 0.9, 0.8), 0.7, 5.0, false)
			marks += 1

	# the cliff, with the sea cave in it
	var cz := CLIFF_Z
	box(Vector3(-100 + (MOUTH.x - MOUTH_W * 0.5) * 0.5, 40, cz - 3), Vector3(200 + (MOUTH.x - MOUTH_W * 0.5), 80, 6), rock, true, 0.0, "concrete")
	box(Vector3(100 + (MOUTH.x + MOUTH_W * 0.5) * 0.5, 40, cz - 3), Vector3(200 - (MOUTH.x + MOUTH_W * 0.5), 80, 6), rock, true, 0.0, "concrete")
	box(Vector3(MOUTH.x, 40 + MOUTH_H * 0.5, cz - 3), Vector3(MOUTH_W, 80 - MOUTH_H, 6), rock, true, 0.0, "concrete")
	# rocky overhangs around the mouth
	for k in 6:
		shape_at("sphere", MOUTH + Vector3(rng.randf_range(-7, 7), rng.randf_range(6.0, 11.0), -0.5), Vector3(rng.randf_range(3, 6), rng.randf_range(2, 4), 3),
			rock.lightened(0.04), false, Vector3.ZERO, "concrete")
	# the tunnel and the chamber at its end
	var tlen := 28.0
	var tz := cz - 6.0 - tlen * 0.5
	box(Vector3(MOUTH.x, MOUTH_H + 0.5, tz), Vector3(MOUTH_W + 2.0, 1.0, tlen), rock, true, 0.0, "concrete")
	box(Vector3(MOUTH.x - MOUTH_W * 0.5 - 0.5, MOUTH_H * 0.5, tz), Vector3(1.0, MOUTH_H, tlen), rock, true, 0.0, "concrete")
	box(Vector3(MOUTH.x + MOUTH_W * 0.5 + 0.5, MOUTH_H * 0.5, tz), Vector3(1.0, MOUTH_H, tlen), rock, true, 0.0, "concrete")
	var ch := Vector3(MOUTH.x, 0, cz - 6.0 - tlen - 5.0)
	box(ch + Vector3(0, 5.5, 0), Vector3(12, 1, 10), rock, true, 0.0, "concrete")
	box(ch + Vector3(-6, 2.5, 0), Vector3(1, 6, 10), rock, true, 0.0, "concrete")
	box(ch + Vector3(6, 2.5, 0), Vector3(1, 6, 10), rock, true, 0.0, "concrete")
	box(ch + Vector3(0, 2.5, -5), Vector3(12, 6, 1), rock, true, 0.0, "concrete")
	box(ch + Vector3(-3.6, 2.5, 5), Vector3(4.8, 6, 1), rock, true, 0.0, "concrete")
	box(ch + Vector3(3.6, 2.5, 5), Vector3(4.8, 6, 1), rock, true, 0.0, "concrete")
	box(ch + Vector3(0, 4.25, 5), Vector3(2.4, 2.5, 1), rock, true, 0.0, "concrete")
	# the glowing doorway
	var door := ch + Vector3(0, 0, -4.4)
	part("box", door + Vector3(-0.65, 1.15, 0), Vector3(0.14, 2.3, 0.2), Color(0.8, 0.95, 1.0), null, Vector3.ZERO, 6.0)
	part("box", door + Vector3(0.65, 1.15, 0), Vector3(0.14, 2.3, 0.2), Color(0.8, 0.95, 1.0), null, Vector3.ZERO, 6.0)
	part("box", door + Vector3(0, 2.33, 0), Vector3(1.44, 0.14, 0.2), Color(0.8, 0.95, 1.0), null, Vector3.ZERO, 6.0)
	part("box", door + Vector3(0, 1.15, -0.05), Vector3(1.16, 2.3, 0.04), Color(0.9, 0.97, 1.0), null, Vector3.ZERO, 3.0)
	omni(door + Vector3(0, 1.3, 1.2), Color(0.75, 0.9, 1.0), 3.0, 18.0, true)
	interactable(door + Vector3(0, 1.15, 0.2), Vector3(1.4, 2.3, 0.4), func(): return "Step through", func(): Game.on_deep_exit())

	# light from nowhere, very little of it
	var env := make_env(Color(0.04, 0.09, 0.12), 0.07)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.008, 0.016)
	env.fog_enabled = true
	env.fog_light_color = Color(0.008, 0.04, 0.065)
	env.fog_density = 0.03
	env.glow_intensity = 1.3
	env.glow_bloom = 0.12
	environment(env)

	leviathan = Leviathan.new()
	leviathan.thickness = 1.6
	leviathan.orbit_radius = 42.0
	leviathan.orbit_height = 16.0
	leviathan.orbit_bob = 6.0
	leviathan.speed = 9.0
	add_child(leviathan)

	ambient("drone", Vector3.ZERO, false, -16.0)
	ambient("water_lap", Vector3(0, 10, 0), false, -24.0)


func on_player_entered(_from_save: bool) -> void:
	_t = 0.0
	_hint = 0
	_chase = false
	_safe = false
	_off_path_t = 0.0
	leviathan.return_to_orbit(9.0)


# ------------------------------------------------------------------ runtime

func _process(delta: float) -> void:
	_t += delta
	var pl: Player = Game.player
	if pl == null:
		return
	var p := pl.global_position
	# it circles above you, wherever you are
	leviathan.orbit_center = leviathan.orbit_center.lerp(Vector3(p.x, 0, p.z), clampf(delta * 0.3, 0.0, 1.0))
	if Game.in_sequence:
		return
	_hints()

	# off the path?
	if not _safe:
		var off := distance_to_path(p)
		if off > SAFE_DISTANCE:
			_off_path_t += delta
			pl.dread.add_fear(6.0 * delta, "off the path")
			_heart -= delta
			if _heart <= 0.0:
				_heart = 0.7
				Sfx.play("thud", -12.0, 1.6)   # your heartbeat
			if not _warned:
				_warned = true
				Game.hud.show_thought("Back. Back to the lights.", 3.0)
			if _off_path_t > GRACE or off > KILL_DISTANCE:
				Game.leviathan_kill(leviathan)
				return
		else:
			_off_path_t = maxf(0.0, _off_path_t - delta * 2.0)
			_warned = _off_path_t > 0.0

	# the cave
	if not _chase and p.z < CHASE_START_Z:
		_chase = true
		leviathan.place_head(p + Vector3(0, 6, 70), Vector3(0, 0, -1))
		leviathan.rush(p, 6.5)
		Sfx.play("whoosh", 0.0, 0.4)
		Game.hud.show_thought("Something is coming. GET INSIDE.", 3.5)
	if _chase and not _safe:
		leviathan.rush_target = p + Vector3(0, 1.0, 0)
		if p.z < CLIFF_Z - 4.5:
			# inside. it hits the opening and cannot follow
			_safe = true
			# its snout ends right at the opening: far too big to follow
			leviathan.block_at(MOUTH + Vector3(0, MOUTH_H * 0.6, 3.0 + leviathan.thickness * 4.0))
			Sfx.play("thud", 6.0, 0.35)
			pl.jolt(Vector3(-4, 3, 2))
			Game.hud.show_thought("It doesn't fit. It doesn't fit.", 3.0)
		elif leviathan.head_position().distance_to(pl.camera.global_position) < 4.0:
			Game.leviathan_kill(leviathan)


func _hints() -> void:
	if _hint == 0 and _t > 2.0:
		Game.hud.show_thought("...The bottom of the sea. I'm standing on the bottom of the sea.", 4.0)
		_hint = 1
	elif _hint == 1 and _t > 7.0:
		if Game.player.manifestation.held == null:
			Game.hud.show_hint("It's so dark. Picture a light.\nHold Q", 8.0)
		_hint = 2
	elif _hint == 2 and _t > 16.0:
		Game.hud.show_thought("The glowing stones... they're in a line. Stay close to them.", 4.0)
		_hint = 3
