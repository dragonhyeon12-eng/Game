class_name AboveZone
extends Zone
## ABOVE - fear of heights. The freight elevator opens onto a rooftop above the clouds, at night.
## Towers go down into the fog further than towers should.
##
## Goal: the red light at the top of the radio mast - on the last tower, far off, visible from the start.
##  1 Rooftop        the bridge controls on the second roof need a key, at the far end of a plank over the drop.
##  2 Bridges        a bare steel beam (wind gusts - crouch); once across, it's gone. The key runs out a bridge.
##  3 Elevators      a sky lift that runs sideways, through floors that don't exist.
##  4 Floating stairs steps in the open air that are only there when you're close to them.
##  5 Construction   scaffolding up an unfinished tower; a crane swings a girder across the gap.
##  6 Skyway         a glass corridor between towers. Glass floor. The lights go out behind you.
##  7 Final ascent   the mast. At the top, the platform takes itself apart and builds a path into the sky.
## Looking down fills DREAD. Falling is a long way. Sometimes, far off, someone else falls.

const TOWER_A := Rect2(-7, -7, 14, 14)
const TOWER_B := Rect2(19, -5, 10, 10)
const TOWER_C := Rect2(20, -26, 8, 8)
const MAST := Vector3(19, 20, -157)
const TOWER_D := Rect2(19, -72, 10, 10)
const TOWER_E := Rect2(18, -115, 18, 17.5)
const TOWER_F := Rect2(12, -164, 14, 14)
const LIFT_Z0 := -26.0                 # the sky lift: C's north edge ...
const LIFT_Z1 := -62.0                 # ... to D's south edge
const CRANE := Vector3(26, 27, -110)   # the jib's pivot
const GAP := Vector3(19, 20, -116.5)   # where the girder has to go
const MAST_H := 18.0
const PLANK_END := -13.1
const FALL_Y := -14.0
## Checkpoints (see Zone.checkpoint_at): across the beam, off the sky lift, the construction site, the mast.
const CHECKPOINTS := {
	"roof_b": [Vector3(24, 0.05, 0), 0.0, ["above_cross"]],
	"lift": [Vector3(24, 0.05, -66.5), 0.0, ["above_cross", "above_key", "above_bridge", "above_lift"]],
	"site": [Vector3(24, 12.05, -100.5), 0.0, ["above_cross", "above_key", "above_bridge", "above_lift", "above_stairs"]],
	"mast": [Vector3(19, 20.05, -154.0), 0.0, ["above_cross", "above_key", "above_bridge", "above_lift", "above_stairs", "above_crane", "above_skyway"]],
}

var _beam: StaticBody3D
var _beam_gone := false
var _on_b_t := 0.0
var _beam_noticed := false
var _plank: Node3D
var _key: Node3D
var _bridge: Node3D
var _bridge_body: StaticBody3D
var _bridge_out := false
var _beacon: OmniLight3D
var _beacon_mesh: MeshInstance3D
var _climbing := false
var _wind: AudioStreamPlayer
var _gust_t := 6.0
var _gust_phase := 0       # 0 calm, 1 rising, 2 pushing
var _gust_dir := Vector3.ZERO
var _gust_strength := 0.0
var _gusts := 0
var _fallers: Array = []   # [node, velocity, spin]
var _faller_t := 25.0
var observer: Observer
var _obs_seen_at := -100.0
var _obs_t := 20.0
var _roofs: Array = []     # distant rooftop spots for the Observer
var _creak_t := 0.0
var _t := 0.0
var _hint := 0
var _ground_y := 0.0
var _cage: Array[StaticBody3D] = []
var _lift: Node3D
var _lift_doors: Array[Node3D] = []
var _lift_label: Label3D
var _lift_riding := false
var _lift_at_d := false
var _steps: Array = []            # [mesh, body, shown]
var _jib: Node3D
var _girder: Node3D
var _girder_body: StaticBody3D
var _crane_done := false
var _sky_lights: Array = []       # [z, light, mesh]
var _sky_dark := false
var _glass_cracked := false
var _path_started := false
var _path_tiles: Array = []


func zone_id() -> String: return "above"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 15.0
func fear_decay() -> float: return 3.0     # (heights frighten in bursts: it should ease off when you step back)
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.3
func sprint_speed() -> float: return 3.8
func max_fall_at(_p: Vector3) -> float: return 40.0


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, 5.4))


## Wind pushes you (Player adds it to its movement unless crouched).
func wind_at(p: Vector3) -> Vector3:
	# gusts belong to the first rooftops and the beam; past roof C the paths are too narrow to be fair
	if _gust_phase != 2 or _in_hut(p) or p.y < -6.0 or _in_skyway(p) or p.z < -30.0:
		return Vector3.ZERO
	return _gust_dir * _gust_strength


func _in_hut(p: Vector3) -> bool:
	return p.x > -2.5 and p.x < 2.5 and p.z > 3.0 and p.z < 7.0


# ------------------------------------------------------------------ build

func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	_tower(TOWER_A, 0.0, Color(0.36, 0.36, 0.38))
	_tower(TOWER_B, 0.0, Color(0.33, 0.33, 0.36))
	_tower(TOWER_C, 0.0, Color(0.3, 0.3, 0.33))
	_tower(TOWER_D, 0.0, Color(0.32, 0.31, 0.33))
	_tower(TOWER_E, 12.0, Color(0.35, 0.34, 0.33))
	_tower(TOWER_F, 20.0, Color(0.28, 0.29, 0.32))
	_sky_lift()
	_floating_stairs()
	_construction()
	_skyway()
	_rims()
	_hut()
	_plank_and_key()
	_beam_build()
	_bridge_build()
	_mast()
	_props()
	_skyline(rng)
	_clouds(rng)
	_sky()
	_wind = ambient("wind", Vector3.ZERO, false, -10.0) as AudioStreamPlayer
	ambient("drone", Vector3.ZERO, false, -24.0)
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen_max_distance = 120.0
	# seen across the rooftops from far off, and often: a jolt, not a wall of dread each time
	observer.seen.connect(func():
		Game.player.dread.add_dread(10.0 if _t - _obs_seen_at > 40.0 else 5.0)
		_obs_seen_at = _t)
	observer.vanished.connect(func(): _obs_t = randf_range(35.0, 70.0))


func _tower(r: Rect2, top: float, col: Color) -> void:
	var c := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	box(c + Vector3(0, top - 0.15, 0), Vector3(r.size.x, 0.3, r.size.y), col.lightened(0.05), true, 0.0, "concrete")
	box(c + Vector3(0, top - 150.3, 0), Vector3(r.size.x, 300.0, r.size.y), col, true, 0.0, "concrete")
	# a band of dark windows just under the roof, to show how high this is
	for k in 6:
		var y := top - 3.0 - k * 3.5
		for side in [-1.0, 1.0]:
			box(c + Vector3(0, y, side * (r.size.y * 0.5 + 0.01)), Vector3(r.size.x - 1.0, 1.4, 0.02), Color(0.04, 0.05, 0.07), false, 0.0, 0.1)
			box(c + Vector3(side * (r.size.x * 0.5 + 0.01), y, 0), Vector3(0.02, 1.4, r.size.y - 1.0), Color(0.04, 0.05, 0.07), false, 0.0, 0.1)


## Low parapets, with gaps where the plank, the beam and the bridge leave the roof.
func _rims() -> void:
	var col := Color(0.42, 0.42, 0.44)
	# tower A: gaps west (plank, z -3) and east (beam, z 0)
	box(Vector3(0, 0.15, -6.9), Vector3(14, 0.3, 0.2), col, true, 0.0, "concrete")
	box(Vector3(0, 0.15, 6.9), Vector3(14, 0.3, 0.2), col, true, 0.0, "concrete")
	box(Vector3(-6.9, 0.15, -5.3), Vector3(0.2, 0.3, 3.4), col, true, 0.0, "concrete")
	box(Vector3(-6.9, 0.15, 2.6), Vector3(0.2, 0.3, 8.8), col, true, 0.0, "concrete")
	box(Vector3(6.9, 0.15, -3.75), Vector3(0.2, 0.3, 6.5), col, true, 0.0, "concrete")
	box(Vector3(6.9, 0.15, 3.75), Vector3(0.2, 0.3, 6.5), col, true, 0.0, "concrete")
	# tower B: gaps west (beam, z 0) and north (bridge, x 24)
	box(Vector3(19.1, 0.15, -2.9), Vector3(0.2, 0.3, 4.2), col, true, 0.0, "concrete")
	box(Vector3(19.1, 0.15, 2.9), Vector3(0.2, 0.3, 4.2), col, true, 0.0, "concrete")
	box(Vector3(28.9, 0.15, 0), Vector3(0.2, 0.3, 10), col, true, 0.0, "concrete")
	box(Vector3(24, 0.15, 4.9), Vector3(10, 0.3, 0.2), col, true, 0.0, "concrete")
	box(Vector3(21.2, 0.15, -4.9), Vector3(4.4, 0.3, 0.2), col, true, 0.0, "concrete")
	box(Vector3(26.8, 0.15, -4.9), Vector3(4.4, 0.3, 0.2), col, true, 0.0, "concrete")


func _hut() -> void:
	# the elevator machine room on roof A: x -2.5..2.5, z 3..7, door gap facing north
	var col := Color(0.5, 0.48, 0.44)
	box(Vector3(0, 1.5, 6.95), Vector3(5, 3, 0.1), col, true, 0.0, "plaster")
	box(Vector3(-2.45, 1.5, 5), Vector3(0.1, 3, 4), col, true, 0.0, "plaster")
	box(Vector3(2.45, 1.5, 5), Vector3(0.1, 3, 4), col, true, 0.0, "plaster")
	box(Vector3(-1.5, 1.5, 3.05), Vector3(2.0, 3, 0.1), col, true, 0.0, "plaster")
	box(Vector3(1.5, 1.5, 3.05), Vector3(2.0, 3, 0.1), col, true, 0.0, "plaster")
	box(Vector3(0, 2.6, 3.05), Vector3(1.0, 0.8, 0.1), col, true, 0.0, "plaster")
	box(Vector3(0, 3.05, 5), Vector3(5.2, 0.1, 4.2), col.darkened(0.2), true, 0.0, "concrete")
	# the elevator you came up in, behind you
	for side in [-1.0, 1.0]:
		part("box", Vector3(side * 0.5, 1.2, 6.88), Vector3(0.98, 2.4, 0.04), Color(0.38, 0.4, 0.42), null, Vector3.ZERO, 0.0, "metal")
	box(Vector3(1.6, 1.0, 6.3), Vector3(1.2, 2.0, 1.0), Color(0.3, 0.38, 0.32), true, 0.0, "metal")   # winding machine
	var l := omni(Vector3(0, 2.7, 5), Color(1.0, 0.8, 0.55), 0.7, 6.0, false)
	l.name = "HutLight"
	# a lamp over the door, outside
	part("box", Vector3(0, 2.9, 2.9), Vector3(0.3, 0.12, 0.2), Color(1.0, 0.85, 0.6), null, Vector3.ZERO, 2.0)
	omni(Vector3(0, 2.7, 2.4), Color(1.0, 0.82, 0.55), 1.4, 12.0, true)
	label(Vector3(0, 2.4, 2.99), 180, "ROOF  -  NO ACCESS", 0.08, Color(0.85, 0.2, 0.15), false)


func _plank_and_key() -> void:
	# a scaffold board laid out over the edge, west of roof A
	_plank = group(Vector3(-6.0, 0.0, -3.0))
	part("box", Vector3(-3.7, -0.03, 0), Vector3(7.4, 0.06, 0.34), Color(0.55, 0.42, 0.25), _plank, Vector3.ZERO, 0.0, "wood")
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(7.4, 0.06, 0.34)
	cs.shape = b
	cs.position = Vector3(-3.7, -0.03, 0)
	body.add_child(cs)
	_plank.add_child(body)
	# bricks weighing down the near end
	box(Vector3(-6.3, 0.12, -3.0), Vector3(0.4, 0.2, 0.3), Color(0.5, 0.25, 0.2), false, 8.0, "concrete")
	_key = group(Vector3(PLANK_END, 0.04, -3.0))
	if prop("key", Vector3(0, 0.006, 0), 90.0, 1.2, _key) == null:
		part("box", Vector3(0, 0.01, 0), Vector3(0.12, 0.012, 0.04), Color(0.85, 0.7, 0.3), _key, Vector3.ZERO, 0.6, "metal")
		part("cylinder", Vector3(-0.07, 0.01, 0), Vector3(0.06, 0.012, 0.06), Color(0.85, 0.7, 0.3), _key, Vector3.ZERO, 0.6, "metal")
		var tag := part("box", Vector3(0.02, 0.01, 0.06), Vector3(0.08, 0.01, 0.06), Color(0.9, 0.2, 0.15), _key, Vector3(0, 20, 0), 0.5)
		tag.name = "Tag"
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.4)
	glow.light_energy = 0.5
	glow.omni_range = 1.5
	glow.position = Vector3(0, 0.3, 0)
	_key.add_child(glow)
	interactable(Vector3(PLANK_END, 0.25, -3.0), Vector3(0.7, 0.6, 0.7), func(): return "Take the key",
		func():
			_key.visible = false
			Game.set_flag("above_key")
			Sfx.play("creak", 2.0, 0.8)
			Game.player.jolt(Vector3(-4, 0, 3))
			_plank.rotation_degrees.z = 3.0
			Game.player.dread.add_fear(10.0, "plank")
			Game.hud.show_thought("Got it. Got it. Now back. Slowly. Don't look down.", 4.0),
		func(): return _key.visible)


func _beam_build() -> void:
	# a bare I-beam from roof A (x 7) to roof B (x 19), along z = 0
	_beam = StaticBody3D.new()
	_beam.collision_layer = 1
	add_child(_beam)
	var steel := Color(0.45, 0.25, 0.18)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(12.4, 0.3, 0.32)
	cs.shape = b
	cs.position = Vector3(13, -0.15, 0)
	_beam.add_child(cs)
	part("box", Vector3(13, -0.02, 0), Vector3(12.4, 0.04, 0.32), steel, _beam, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(13, -0.2, 0), Vector3(12.4, 0.34, 0.04), steel, _beam, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(13, -0.38, 0), Vector3(12.4, 0.04, 0.32), steel, _beam, Vector3.ZERO, 0.0, "metal")
	for k in 7:
		part("cylinder", Vector3(7.5 + k * 1.8, 0.0, 0.1), Vector3(0.04, 0.02, 0.04), steel.darkened(0.3), _beam, Vector3.ZERO, 0.0, "metal")


func _bridge_build() -> void:
	# a maintenance bridge that slides out of roof B's north edge (z -5) to roof C (z -18)
	_bridge = group(Vector3(24, 0, -4.6))
	part("box", Vector3(0, -0.06, -6.7), Vector3(0.9, 0.12, 13.4), Color(0.4, 0.42, 0.44), _bridge, Vector3.ZERO, 0.0, "metal")
	for k in 14:
		part("box", Vector3(0, 0.005, -0.5 - k * 0.95), Vector3(0.88, 0.01, 0.05), Color(0.3, 0.32, 0.34), _bridge, Vector3.ZERO, 0.0, "metal")
	_bridge.scale.z = 0.02
	_bridge_body = StaticBody3D.new()
	_bridge_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.9, 0.12, 13.4)
	cs.shape = b
	cs.position = Vector3(24, -0.06, -11.3)
	cs.disabled = true
	_bridge_body.add_child(cs)
	add_child(_bridge_body)
	# the controls, on roof B
	var ctl := Vector3(25.6, 0, -3.8)
	box(ctl + Vector3(0, 0.6, 0), Vector3(0.6, 1.2, 0.4), Color(0.75, 0.65, 0.2), true, 0.0, "metal")
	label(ctl + Vector3(0, 1.0, 0.21), 0, "BRIDGE", 0.07, Color(0.1, 0.1, 0.1), false)
	part("cylinder", ctl + Vector3(0, 0.8, 0.21), Vector3(0.06, 0.02, 0.06), Color(0.3, 0.3, 0.3), null, Vector3(90, 0, 0), 0.0, "metal")
	interactable(ctl + Vector3(0, 0.8, 0.3), Vector3(0.8, 0.8, 0.5),
		func(): return "Use the key" if Game.has_flag("above_key") else "Bridge controls",
		func():
			if not Game.has_flag("above_key"):
				Game.hud.show_thought("A keyhole. Of course there's a keyhole.", 3.0)
				return
			_extend_bridge(false),
		func(): return not _bridge_out)


func _extend_bridge(instant: bool) -> void:
	_bridge_out = true
	Game.set_flag("above_bridge")
	_bridge_body.get_child(0).disabled = false
	if instant:
		_bridge.scale.z = 1.0
		return
	Sfx.play("creak", 0.0, 0.5)
	create_tween().tween_property(_bridge, "scale:z", 1.0, 4.0).set_trans(Tween.TRANS_SINE)
	Game.hud.show_thought("No railings. Of course there are no railings.", 3.5)


func _mast() -> void:
	var steel := Color(0.7, 0.18, 0.12)
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			shape_at("cylinder", MAST + Vector3(x, MAST_H * 0.5, z), Vector3(0.08, MAST_H, 0.08), steel, true, Vector3.ZERO, "metal")
	for k in 12:
		var y := 0.8 + k * 1.5
		for side in 4:
			var yaw := side * 90.0
			var off := Vector3(0, 0, 0.6).rotated(Vector3.UP, deg_to_rad(yaw))
			shape_at("cylinder", MAST + off + Vector3(0, y, 0), Vector3(0.035, 1.7, 0.035), steel.lightened(0.15), false, Vector3(0, yaw, 50 if k % 2 == 0 else -50), "metal")
	# ladder on the south face
	for x in [-0.22, 0.22]:
		shape_at("cylinder", MAST + Vector3(x, MAST_H * 0.5, 0.75), Vector3(0.04, MAST_H, 0.04), Color(0.75, 0.75, 0.75), false, Vector3.ZERO, "metal")
	for k in int(MAST_H / 0.35):
		shape_at("cylinder", MAST + Vector3(0, 0.3 + k * 0.35, 0.75), Vector3(0.03, 0.44, 0.03), Color(0.75, 0.75, 0.75), false, Vector3(0, 0, 90), "metal")
	# the platform at the top
	box(MAST + Vector3(0, MAST_H - 0.05, 0), Vector3(2.2, 0.1, 2.2), Color(0.35, 0.35, 0.37), true, 0.0, "metal")
	for side in 4:
		var off := Vector3(0, 0, 1.08).rotated(Vector3.UP, side * PI * 0.5)
		var sz := Vector3(2.2, 0.05, 0.05) if side % 2 == 0 else Vector3(0.05, 0.05, 2.2)
		box(MAST + off + Vector3(0, MAST_H + 1.0, 0), sz, Color(0.75, 0.75, 0.75), false, 0.0, "metal")
		var csz := Vector3(2.2, 1.2, 0.1) if side % 2 == 0 else Vector3(0.1, 1.2, 2.2)
		var cage := solid_box(MAST + off + Vector3(0, MAST_H + 0.6, 0), csz, Color(0, 0, 0))
		cage.get_child(1).visible = false
		_cage.append(cage)
	_beacon_mesh = part("sphere", MAST + Vector3(0, MAST_H + 1.1, 0), Vector3.ONE * 0.35, Color(1.0, 0.1, 0.05), null, Vector3.ZERO, 6.0)
	_beacon = omni(MAST + Vector3(0, MAST_H + 1.3, 0), Color(1.0, 0.12, 0.06), 4.0, 30.0, false)
	interactable(MAST + Vector3(0, 1.0, 1.0), Vector3(0.9, 2.0, 0.6), func(): return "Climb the ladder",
		func(): _climb(), func(): return not _climbing and Game.player.global_position.y < MAST.y + 2.0)
	interactable(MAST + Vector3(0, MAST_H + 1.1, 0), Vector3(0.9, 0.9, 0.9), func(): return "Touch the light" if not _path_started else "",
		func(): _rearrange(), func(): return not _path_started)


func _props() -> void:
	# roof A: water tank, vents, a satellite dish
	var tank := Vector3(-3.5, 0, -4)
	for x in [-0.8, 0.8]:
		for z in [-0.8, 0.8]:
			shape_at("cylinder", tank + Vector3(x, 0.7, z), Vector3(0.12, 1.4, 0.12), Color(0.3, 0.3, 0.3), true, Vector3.ZERO, "metal")
	shape_at("cylinder", tank + Vector3(0, 2.5, 0), Vector3(2.2, 2.2, 2.2), Color(0.42, 0.33, 0.26), true, Vector3.ZERO, "wood")
	shape_at("cone", tank + Vector3(0, 3.9, 0), Vector3(2.4, 0.6, 2.4), Color(0.3, 0.25, 0.2), false, Vector3.ZERO, "wood")
	for p in [Vector3(4, 0.5, -4), Vector3(4.5, 0.5, 1.5)]:
		box(p, Vector3(1.4, 1.0, 1.0), Color(0.55, 0.56, 0.58), true, 0.0, "metal")
	shape_at("sphere", Vector3(-4.8, 1.2, 4.5), Vector3(1.2, 1.2, 0.3), Color(0.8, 0.8, 0.78), false, Vector3(20, 30, 0))
	# roof B: pipes and an old antenna
	for i in 3:
		shape_at("cylinder", Vector3(27.5, 0.3 + i * 0.25, 2.0), Vector3(0.18, 5.0, 0.18), Color(0.3, 0.35, 0.33), true, Vector3(90, 0, 0), "metal")
	shape_at("cylinder", Vector3(21, 3.0, 3.5), Vector3(0.08, 6.0, 0.08), Color(0.5, 0.5, 0.5), false, Vector3.ZERO, "metal")
	omni(Vector3(24, 2.5, 0), Color(0.6, 0.7, 1.0), 0.6, 10.0, false)
	omni(Vector3(24, 2.5, -22), Color(0.6, 0.7, 1.0), 0.5, 10.0, false)


func _skyline(rng: RandomNumberGenerator) -> void:
	# other towers, all the way around, all the way down; a few lit windows
	var win := MultiMesh.new()
	win.transform_format = MultiMesh.TRANSFORM_3D
	win.use_colors = true
	win.mesh = Shapes.mesh("box")
	var xforms := []
	var cols := []
	var placed := 0
	while placed < 34:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(45.0, 190.0)
		var c := Vector3(cos(ang) * dist + 12, 0, sin(ang) * dist - 8)
		var w := rng.randf_range(8.0, 20.0)
		var top := rng.randf_range(-70.0, 25.0)
		if c.x > -5.0 and c.x < 50.0 and c.z < -30.0 and c.z > -200.0:
			continue
		box(c + Vector3(0, top - 150, 0), Vector3(w, 300, w), Color(0.2, 0.21, 0.24).lightened(rng.randf_range(0, 0.08)), false, rng.randf_range(0, 90), "concrete")
		if dist < 110.0 and top > -30.0:
			_roofs.append(c + Vector3(rng.randf_range(-w * 0.3, w * 0.3), top, rng.randf_range(-w * 0.3, w * 0.3)))
		for k in 22:
			var face := rng.randi_range(0, 3)
			var n := Vector3(0, 0, 1).rotated(Vector3.UP, face * PI * 0.5)
			var along := n.cross(Vector3.UP)
			var pos := c + n * (w * 0.5 + 0.05) + along * rng.randf_range(-w * 0.4, w * 0.4) + Vector3(0, top - rng.randf_range(2.0, 50.0), 0)
			var basis := Basis(Vector3.UP, face * PI * 0.5) * Basis.from_scale(Vector3(0.9, 1.2, 0.05))
			xforms.append(Transform3D(basis, pos))
			cols.append(Color(1.0, 0.8, 0.45) * rng.randf_range(0.4, 1.0) if rng.randf() < 0.85 else Color(0.6, 0.75, 1.0) * 0.7)
		placed += 1
	win.instance_count = xforms.size()
	for i in xforms.size():
		win.set_instance_transform(i, xforms[i])
		win.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = win
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _clouds(rng: RandomNumberGenerator) -> void:
	# a sea of cloud far below, lit by the moon: a pale floor, and soft billows heaped on it at every depth -
	# camera-facing puffs with soft edges, drifting. The height fog (see _sky) swallows everything under them.
	box(Vector3(12, -46, -8), Vector3(900, 0.5, 900), Color(0.2, 0.22, 0.3), false, 0.0, 1.0)
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.55, Color(1, 1, 1, 0.45))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var lo := Settings.quality < 1       # LOW graphics: fewer, bigger billows (overlapping see-through sprites are slow on phones)
	mm.instance_count = 150 if lo else 420
	for i in mm.instance_count:
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * 320.0
		var y := rng.randf_range(-44.0, -14.0)
		var s := rng.randf_range(22.0, 70.0) * (1.0 + (y + 44.0) / 60.0) * (1.4 if lo else 1.0)
		var p := Vector3(cos(ang) * dist + 12, y, sin(ang) * dist - 8)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s * 0.6, 1.0)), p))
		var lit := rng.randf_range(0.0, 1.0)
		mm.set_instance_color(i, Color(0.42, 0.46, 0.6, 0.55).lerp(Color(0.62, 0.66, 0.8, 0.7), lit * lit))
	_cloud_sea = MultiMeshInstance3D.new()
	_cloud_sea.multimesh = mm
	_cloud_sea.material_override = mat
	_cloud_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cloud_sea)


var _cloud_sea: MultiMeshInstance3D


func _sky() -> void:
	part("sphere", Vector3(-180, 120, -260), Vector3.ONE * 24.0, Color(0.85, 0.88, 1.0), null, Vector3.ZERO, 2.5)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.65, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	moon.look_at_from_position(Vector3(-180, 120, -260).normalized() * 10.0, Vector3.ZERO, Vector3.UP)
	var env := make_env(Color(0.35, 0.4, 0.55), 0.22)
	# night: stars, the moon, thin cloud catching its light
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/world/sky.gdshader")
	for kv in [["zenith", Color(0.008, 0.012, 0.035)], ["horizon", Color(0.05, 0.065, 0.11)], ["ground", Color(0.03, 0.035, 0.05)],
			["sun_color", Color(0.75, 0.82, 1.0)], ["cloud_light", Color(0.32, 0.36, 0.48)], ["cloud_shadow", Color(0.04, 0.05, 0.08)]]:
		sky_mat.set_shader_parameter(kv[0], kv[1])
	sky_mat.set_shader_parameter("cloud_cover", 0.3)
	sky_mat.set_shader_parameter("stars", 1.0)
	sky_mat.set_shader_parameter("sun_size", 0.9997)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.16, 0.24)
	env.fog_density = 0.006
	env.fog_height = -8.0              # under the rooftops it thickens fast: the towers go down into cloud
	env.fog_height_density = 0.12
	env.glow_intensity = 1.0
	environment(env)


# ------------------------------------------------------------------ the climb

func _climb() -> void:
	_climbing = true
	var t := Game._seq
	Game.in_sequence = true
	Game.set_mode("cinematic")
	var pl: Player = Game.player
	pl.teleport(Transform3D(Basis(), MAST + Vector3(0, 0.05, 1.25)))
	pl.set_physics_process(false)
	var steps := 36
	for k in steps:
		var f := float(k + 1) / steps
		var tw := create_tween()
		tw.tween_property(pl, "global_position:y", MAST.y + MAST_H * f + 0.05, 0.22)
		pl._pitch = deg_to_rad(45.0) if k < 20 or k > 26 else deg_to_rad(-70.0)
		pl.head.rotation.x = pl._pitch
		if k % 4 == 0:
			Sfx.play("step_concrete_%d" % (k % 4), -8.0, 1.5)
		if k == 20:
			Game.hud.show_thought("Don't look down. Don't look down. Don't--", 2.5)
			pl.dread.add_fear(15.0, "looked down")
			Sfx.play("whoosh", -2.0, 0.5)
		if k == 27:
			pl.jolt(Vector3(-3, 2, 3))
		await get_tree().create_timer(0.22, false).timeout
		if t != Game._seq: return
	pl.set_physics_process(true)
	pl.teleport(Transform3D(Basis(), MAST + Vector3(0, MAST_H + 0.05, 0.5)))
	pl._pitch = deg_to_rad(10)
	pl.head.rotation.x = pl._pitch
	Game.set_flag("above_mast")
	Game.in_sequence = false
	Game.set_mode("game")
	_climbing = false
	Game.hud.show_thought("The top. The light. It's warm. It's so warm.", 3.5)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	give(["above_key"])
	_t = 0.0
	_hint = 2 if from_save else 0
	if Game.has_flag("above_key"):
		_key.visible = false
	if Game.has_flag("above_bridge"):
		_extend_bridge(true)
	if Game.has_flag("above_crane"):
		_swing_jib(true)
	if Game.has_flag("above_cross"):     # (no way back across: the beam went)
		_beam_gone = true
		_beam_noticed = true
		_beam.visible = false
		_beam.get_child(0).disabled = true
	_ground_y = Game.player.global_position.y if Game.player else 0.0


func _process(delta: float) -> void:
	_t += delta
	_beacon.light_energy = (4.0 if fmod(_t, 1.6) < 0.8 else 0.4) if Settings.flashing_ok() else 2.5
	if _cloud_sea:
		_cloud_sea.position = Vector3(sin(_t * 0.013) * 9.0, 0, _t * 0.25 - floorf(_t * 0.25 / 40.0) * 40.0)   # drifting
	_update_fallers(delta)
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	if pl.is_on_floor():
		_ground_y = p.y
	if p.y < _ground_y + FALL_Y:
		Game.fall_death()
		return
	_hints(p)
	_update_wind(delta, p)
	_update_height_fear(delta, pl)
	_update_beam(delta, p)
	_update_plank(delta, p)
	_update_observer(delta)
	_update_stairs(p)
	_update_skyway(p)
	_faller_t -= delta
	if _faller_t <= 0.0:
		_faller_t = randf_range(30.0, 55.0)
		_spawn_faller(pl)


func _update_wind(delta: float, p: Vector3) -> void:
	_gust_t -= delta
	match _gust_phase:
		0:
			_wind.volume_db = lerpf(_wind.volume_db, -12.0, clampf(delta, 0.0, 1.0))
			if _gust_t <= 0.0:
				_gust_phase = 1
				_gust_t = 1.6
				var on_beam := p.x > 7.0 and p.x < 19.0
				_gust_dir = Vector3(0, 0, 1 if randf() < 0.5 else -1) if on_beam else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				_gust_strength = 1.8 if on_beam or p.x < -7.0 else 1.2
		1:
			_wind.volume_db = lerpf(_wind.volume_db, 2.0, clampf(delta * 2.0, 0.0, 1.0))
			if _gust_t <= 0.0:
				_gust_phase = 2
				_gust_t = 1.8
				_gusts += 1
				if _gusts == 1:
					Game.hud.show_hint("WIND!  Crouch (C / Ctrl) to hold on.", 5.0)
		2:
			if Game.player.dread.fear < 65.0:
				Game.player.dread.add_fear(3.0 * delta, "wind")
			if _gust_t <= 0.0:
				_gust_phase = 0
				_gust_t = randf_range(6.0, 11.0)


func _update_height_fear(delta: float, pl: Player) -> void:
	var cam := pl.camera.global_position
	var down := clampf((-pl._pitch - 0.35) / 0.9, 0.0, 1.0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pl.global_position + Vector3.UP * 0.2, pl.global_position + Vector3.DOWN * 6.0, 1)
	q.exclude = [pl.get_rid()]
	var over_void := space.intersect_ray(q).is_empty()
	# heights alone frighten you, but never all the way (the scripted scares do the rest)
	var cap := pl.dread.fear < 65.0
	if over_void and cap:
		pl.dread.add_fear(5.0 * delta, "over the drop")
	if down > 0.0:
		var look := PhysicsRayQueryParameters3D.create(cam, cam - pl.camera.global_transform.basis.z * 40.0, 1)
		look.exclude = [pl.get_rid()]
		var hit := space.intersect_ray(look)
		if hit.is_empty() or hit.position.y < pl.global_position.y - 8.0:
			if cap:
				pl.dread.add_fear(14.0 * down * delta, "looking down")
				pl.dread.add_stability(-4.0 * down * delta)


func _update_beam(delta: float, p: Vector3) -> void:
	if p.x > 19.5 and absf(p.z) < 5.0 and p.y > -1.0:
		if not Game.has_flag("above_cross"):
			Game.set_flag("above_cross")
			Game.hud.show_thought("Across. I'm across.", 2.5)
			checkpoint_at("roof_b")
		_on_b_t += delta
		if not _beam_gone and _on_b_t > 3.0 and not Observation.is_observed(Vector3(13, 0, 0), 3.0, [_beam]):
			_beam_gone = true
			_beam.visible = false
			_beam.get_child(0).disabled = true
	if _beam_gone and not _beam_noticed and Observation.in_view(Vector3(13, 0, 0), 1.0) and p.x > 18.0:
		_beam_noticed = true
		Sfx.play("thud", -10.0, 0.5)
		Game.player.dread.add_fear(8.0, "beam gone")
		Game.hud.show_thought("The beam. Where's the beam? There's no way back.", 3.5)


func _update_plank(delta: float, p: Vector3) -> void:
	var on := p.x < -7.0 and absf(p.z + 3.0) < 0.5 and p.y > -0.5
	var bend := clampf((-7.0 - p.x) / 6.0, 0.0, 1.0) if on else 0.0
	_plank.rotation_degrees.z = lerpf(_plank.rotation_degrees.z, bend * 3.5, clampf(delta * 4.0, 0.0, 1.0))
	if on:
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = randf_range(1.2, 2.5)
			Sfx.play_at("creak", self, Vector3(p.x, 0, -3), -4.0 + bend * 6.0, 20.0)


func _update_observer(delta: float) -> void:
	if observer.visible or _roofs.is_empty():
		return
	_obs_t -= delta
	if _obs_t <= 0.0:
		_obs_t = 8.0
		observer.try_appear_at(_roofs.pick_random())


## Somebody falls, far away, without a sound until they pass.
func _spawn_faller(pl: Player) -> void:
	var fwd := -pl.camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5))
	var pos := pl.global_position + fwd * randf_range(28.0, 45.0) + Vector3(0, 30, 0)
	var f := Node3D.new()
	f.position = pos
	add_child(f)
	var dark := Color(0.03, 0.03, 0.035)
	part("capsule", Vector3(0, 0, 0), Vector3(0.38, 0.75, 0.25), dark, f)
	part("sphere", Vector3(0, 0.55, 0), Vector3.ONE * 0.24, dark, f)
	for s in [-1.0, 1.0]:
		part("capsule", Vector3(0.3 * s, 0.25, 0), Vector3(0.1, 0.6, 0.1), dark, f, Vector3(0, 0, 140 * s))
		part("capsule", Vector3(0.12 * s, -0.65, 0), Vector3(0.12, 0.7, 0.12), dark, f, Vector3(0, 0, 15 * s))
	_fallers.append([f, Vector3(0, -6.0, 0), Vector3(randf_range(-2, 2), randf_range(-1, 1), randf_range(-2, 2)), false])


func _update_fallers(delta: float) -> void:
	for i in range(_fallers.size() - 1, -1, -1):
		var e: Array = _fallers[i]
		var f: Node3D = e[0]
		e[1].y = maxf(e[1].y - 14.0 * delta, -45.0)
		f.position += e[1] * delta
		f.rotation += e[2] * delta
		if not e[3] and Game.player and f.position.y < Game.player.global_position.y + 2.0:
			e[3] = true
			Sfx.play_at("whoosh", self, f.position, 0.0, 70.0)
			if Observation.in_view(f.position, 1.0):
				Game.player.dread.add_fear(10.0, "someone fell")
		if f.position.y < -120.0:
			f.queue_free()
			_fallers.remove_at(i)


func _hints(p: Vector3) -> void:
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("...Up. It went up. How far up did it go?", 4.0)
	elif _hint == 1 and _t > 7.0 and not _in_hut(p):
		_hint = 2
		Game.hud.show_thought("There's a light. On the mast, over there. I need to get to that light.", 4.5)


# ------------------------------------------------------------------ 3: the sky lift

func _in_skyway(p: Vector3) -> bool:
	return p.x > 17.4 and p.x < 20.6 and p.z < -118.4 and p.z > -150.0 and p.y > 19.0


func _sky_lift() -> void:
	var steel := Color(0.4, 0.42, 0.45)
	# the rail it hangs from, C to D, over nothing
	box(Vector3(24, 3.0, (LIFT_Z0 + LIFT_Z1) * 0.5), Vector3(0.3, 0.4, LIFT_Z0 - LIFT_Z1 + 2.0), Color(0.3, 0.3, 0.32), false, 0.0, "metal")
	for z in [LIFT_Z0 + 0.5, LIFT_Z1 - 0.5]:
		for x in [-1.4, 1.4]:
			shape_at("cylinder", Vector3(24 + x, 1.6, z), Vector3(0.15, 3.2, 0.15), steel, true, Vector3.ZERO, "metal")
		box(Vector3(24, 3.25, z), Vector3(3.0, 0.2, 0.3), steel, false, 0.0, "metal")
	label(Vector3(24, 2.6, LIFT_Z0 + 0.65), 0, "SKY LIFT", 0.12, Color(0.9, 0.85, 0.6), true)
	omni(Vector3(24, 2.6, LIFT_Z0 + 1.2), Color(1.0, 0.85, 0.6), 1.2, 8.0, false)
	# the cab: x 23..25, z -28.4..-26 at the start
	_lift = group(Vector3(24, 0, LIFT_Z0 - 1.2))
	var col := Color(0.55, 0.5, 0.42)
	for side in [-1.0, 1.0]:
		var wb := solid_box(Vector3(side * 1.0, 1.2, 0), Vector3(0.08, 2.4, 2.4), col, _lift, "metal")
		wb.get_child(1).visible = true
		part("box", Vector3(side * 1.04, 1.5, 0), Vector3(0.01, 0.9, 1.8), Color(0.1, 0.12, 0.16), _lift, Vector3.ZERO, 0.0, "glass")
	solid_box(Vector3(0, -0.05, 0), Vector3(2.0, 0.1, 2.4), Color(0.3, 0.3, 0.3), _lift, "metal")
	solid_box(Vector3(0, 2.45, 0), Vector3(2.0, 0.1, 2.4), col.darkened(0.3), _lift, "metal")
	part("cylinder", Vector3(0, 2.75, 0), Vector3(0.1, 0.6, 0.1), steel, _lift, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(0, 2.38, 0), Vector3(0.6, 0.03, 0.2), Color(1.0, 0.9, 0.7), _lift, Vector3.ZERO, 3.0)
	var inner := OmniLight3D.new()
	inner.light_color = Color(1.0, 0.85, 0.6)
	inner.light_energy = 0.8
	inner.omni_range = 4.0
	inner.position = Vector3(0, 2.2, 0)
	_lift.add_child(inner)
	# doors at both ends; the far ones stay shut until it arrives
	for end in [1.0, -1.0]:
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			var dn := solid_box(Vector3(side * 0.5, 1.2, end * 1.18), Vector3(1.0, 2.4, 0.05), Color(0.6, 0.55, 0.45), _lift, "metal")
			_lift_doors.append(dn)
	_lift_label = Label3D.new()
	_lift_label.text = "R"
	_lift_label.font_size = 64
	_lift_label.pixel_size = 0.004
	_lift_label.modulate = Color(1.0, 0.35, 0.2)
	_lift_label.position = Vector3(0, 2.15, -1.13)
	_lift.add_child(_lift_label)
	# open the near doors
	for k in 2:
		_set_door(k, true)
	interactable(Vector3(24.8, 1.2, LIFT_Z0 - 1.6), Vector3(0.3, 0.4, 0.4), func(): return "Press the button" if not _lift_riding and not _lift_at_d else "",
		func(): _ride_lift(), func(): return not _lift_riding and not _lift_at_d and Game.player.global_position.z < LIFT_Z0 - 0.3)
	part("box", Vector3(24.94, 1.2, LIFT_Z0 - 1.6), Vector3(0.04, 0.3, 0.2), Color(0.2, 0.2, 0.2), _lift, Vector3.ZERO, 0.0, "metal")
	_lift.get_child(_lift.get_child_count() - 1).position = Vector3(0.94, 1.2, -0.4)
	# D: the far roof, a lamp and a melted ice-cream cart from somebody else's dream
	for x in [21.3, 26.7]:   # a parapet, with a gap where the stairs start
		box(Vector3(x, 0.15, -72.0 + 0.1), Vector3(4.6, 0.3, 0.2), Color(0.42, 0.42, 0.44), true, 0.0, "concrete")
	omni(Vector3(24, 2.5, -66), Color(0.6, 0.7, 1.0), 0.5, 10.0, false)
	var cart := Vector3(27, 0, -69)
	part("box", cart + Vector3(0, 0.6, 0), Vector3(1.2, 0.7, 0.7), Color(0.85, 0.82, 0.78), null, Vector3(0, 0, -6), 0.0, "metal")
	part("sphere", cart + Vector3(0.2, 1.0, 0), Vector3(0.9, 0.35, 0.6), Color(0.95, 0.75, 0.8), null, Vector3.ZERO, 0.0)
	part("cylinder", cart + Vector3(-0.5, 0.25, 0.35), Vector3(0.5, 0.06, 0.5), Color(0.2, 0.2, 0.2), null, Vector3(90, 0, 0), 0.0, "metal")
	blocker(cart + Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 0.8))
	trigger(cart, Vector3(4, 3, 4), func():
		Game.hud.show_thought("The ice-cream cart. From the park. ...It's melting. Up here.", 3.5))


func _set_door(k: int, open: bool) -> void:
	var d: StaticBody3D = _lift_doors[k]
	var side := -1.0 if k % 2 == 0 else 1.0
	create_tween().tween_property(d, "position:x", side * (1.45 if open else 0.5), 1.2).set_trans(Tween.TRANS_SINE)
	d.get_child(0).set_deferred("disabled", open)


func _ride_lift() -> void:
	_lift_riding = true
	Game.set_flag("above_lift")
	var t := Game._seq
	Game.in_sequence = true
	Game.set_mode("cinematic")
	var pl: Player = Game.player
	for k in 2:
		_set_door(k, false)
	Sfx.play("ding", -4.0, 0.9)
	await get_tree().create_timer(1.4, false).timeout
	if t != Game._seq: return
	pl.set_physics_process(false)
	var offset := pl.global_position - _lift.global_position
	var floors := ["R", "41", "88", "112", "-3", "7", "∞", "41", "R"]
	var dur := 14.0
	var t0 := 0.0
	var start_z := _lift.position.z
	var end_z := LIFT_Z1 + 1.2
	var fi := -1
	Sfx.play("motor", -6.0, 0.7)
	while t0 < dur:
		var dt := get_process_delta_time()
		t0 += dt
		var f := clampf(t0 / dur, 0.0, 1.0)
		var e := f * f * (3.0 - 2.0 * f)
		_lift.position.z = lerpf(start_z, end_z, e)
		_lift.position.y = sin(t0 * 2.3) * 0.015
		pl.global_position = _lift.global_position + offset
		var nfi := int(f * (floors.size() - 1))
		if nfi != fi:
			fi = nfi
			_lift_label.text = floors[fi]
			Sfx.play("ding", -16.0, 1.2)
			if floors[fi] == "∞":
				Sfx.stinger("whisper", -8.0)
				Game.hud.show_thought("That's not a floor. That's not a floor.", 2.5)
			elif floors[fi] == "-3":
				Game.hud.show_thought("Minus three? We're going sideways.", 2.5)
		if fi == 4 and randf() < dt * 3.0:
			pl.jolt(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
		await get_tree().process_frame
		if t != Game._seq: return
	_lift_at_d = true
	pl.global_position = _lift.global_position + offset
	pl.set_physics_process(true)
	Sfx.play("ding", -2.0, 0.8)
	for k in [2, 3]:
		_set_door(k, true)
	Game.in_sequence = false
	Game.set_mode("game")
	Game.hud.show_thought("It stopped. The doors at the other end are open.", 3.0)
	checkpoint_at("lift")


# ------------------------------------------------------------------ 4: floating stairs

func _floating_stairs() -> void:
	# three flights in the open air, D's north edge (z -72, y 0) to E's south edge (z -97.5, y 12)
	var z := -72.0
	var y := 0.0
	var mat := Shapes.surface("concrete", Color(0.55, 0.55, 0.57))
	for flight in 3:
		for i in 16:
			y += 0.25
			z -= 0.45
			_step(Vector3(24, y - 0.1, z + 0.225), Vector3(1.3, 0.2, 0.47), mat, true)
		if flight < 2:
			_step(Vector3(24, y - 0.1, z - 1.0), Vector3(1.6, 0.2, 2.0), mat)
			z -= 2.0
	trigger(Vector3(24, 1.0, -71.0), Vector3(3, 2, 1.5), func():
		Game.hud.show_thought("Stairs. Going up into nothing. ...There's nothing holding them up.", 3.5))
	trigger(Vector3(24, 13.0, -99.5), Vector3(6, 2.4, 2), func():
		if Game.has_flag("above_stairs"):
			return
		Game.set_flag("above_stairs")
		checkpoint_at("site")
		Game.hud.show_thought("Solid. Solid ground. ...An unfinished building, up here.", 3.0))


## One step (or landing). Steps are walked as a ramp - you can't climb a 25 cm riser without one.
func _step(pos: Vector3, size: Vector3, mat: Material, ramp := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh("box")
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(size.x, 0.001, size.z)
	mi.visible = false
	add_child(mi)
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	if ramp:
		# from this step's front-bottom edge to its back-top edge, one riser's worth of slope
		var slope := atan2(0.25, 0.45)
		b.size = Vector3(size.x, 0.06, Vector2(0.45, 0.25).length() + 0.02)
		body.position = pos + Vector3(0, 0.1 - 0.125 - 0.03, 0)
		body.rotation.x = slope
	cs.disabled = true
	body.add_child(cs)
	add_child(body)
	_steps.append([mi, cs, false, size])


func _update_stairs(p: Vector3) -> void:
	if p.z > -70.0 or p.z < -100.0:
		return
	for s in _steps:
		var mi: MeshInstance3D = s[0]
		var near := mi.position.distance_to(p + Vector3(0, 0.5, 0)) < 4.2
		if near != s[2]:
			s[2] = near
			var size: Vector3 = s[3]
			(s[1] as CollisionShape3D).disabled = not near
			if near:
				mi.visible = true
				create_tween().tween_property(mi, "scale", size, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				Sfx.play("chime", -26.0, randf_range(1.6, 2.2))
			else:
				var tw := create_tween()
				tw.tween_property(mi, "scale", Vector3(size.x, 0.001, size.z), 0.4)
				tw.tween_callback(func(): mi.visible = s[2])


# ------------------------------------------------------------------ 5: the construction site

func _construction() -> void:
	var steel := Color(0.62, 0.3, 0.12)
	var wood := Color(0.55, 0.42, 0.26)
	var top := 12.0
	# a steel skeleton: columns and two levels of beams over E's slab
	for x in [28.0, 31.75, 35.5]:
		for z in [-99.0, -104.0, -108.5, -114.5]:
			box(Vector3(x, top + 4.5, z), Vector3(0.3, 9.0, 0.3), steel, true, 0.0, "metal")
	for y in [top + 4.0, top + 8.6]:
		for z in [-99.0, -104.0, -108.5, -114.5]:
			box(Vector3(31.75, y, z), Vector3(7.8, 0.35, 0.2), steel, false, 0.0, "metal")
		for x in [28.0, 31.75, 35.5]:
			box(Vector3(x, y, -106.75), Vector3(0.2, 0.35, 15.7), steel, false, 0.0, "metal")
	# stacks of materials, a mixer, a work lamp
	box(Vector3(32, top + 0.4, -100.5), Vector3(3.0, 0.8, 1.2), wood, true, 8.0, "wood")
	box(Vector3(33, top + 0.3, -112.0), Vector3(2.4, 0.6, 1.4), Color(0.6, 0.6, 0.58), true, -5.0, "concrete")
	shape_at("cylinder", Vector3(28.5, top + 0.8, -112.5), Vector3(1.2, 1.4, 1.2), Color(0.85, 0.55, 0.15), true, Vector3(0, 0, 70), "metal")
	part("box", Vector3(27.5, top + 2.0, -99.0), Vector3(0.4, 0.3, 0.2), Color(1.0, 0.95, 0.8), null, Vector3(-30, 0, 0), 6.0)
	spot(Vector3(27.5, top + 2.0, -99.2), Vector3(22, top, -110), Color(1.0, 0.93, 0.8), 3.0, 30.0, 45.0, true)
	label(Vector3(24.0, top + 1.6, -98.32), 0, "DANGER - CONSTRUCTION SITE\nNO UNAUTHORISED PERSONS", 0.05, Color(0.9, 0.75, 0.1), false)
	# scaffolding up the west side: ramp to 16, ramp back to 20, a deck north to the gap
	var deck := wood.darkened(0.1)
	_plankway(Vector3(19, top, -100), Vector3(19, top + 4, -108), 1.2, deck)
	box(Vector3(19.8, top + 4 - 0.05, -109.0), Vector3(2.8, 0.1, 2.0), deck, true, 0.0, "wood")
	_plankway(Vector3(20.6, top + 4, -108), Vector3(20.6, top + 8, -100), 1.2, deck)
	box(Vector3(19.8, top + 8 - 0.05, -99.0), Vector3(2.8, 0.1, 2.0), deck, true, 0.0, "wood")
	box(Vector3(19, top + 8 - 0.05, -107.0), Vector3(1.2, 0.1, 16.0), deck, true, 0.0, "wood")
	for z in range(-98, -116, -3):
		for x in [18.35, 21.25]:
			shape_at("cylinder", Vector3(x, top + 4.5, z), Vector3(0.05, 9.0, 0.05), Color(0.6, 0.62, 0.64), false, Vector3.ZERO, "metal")
		box(Vector3(18.35, top + 9.0, z - 1.5), Vector3(0.05, 0.05, 3.0), Color(0.6, 0.62, 0.64), false, 0.0, "metal")
	# the tower crane
	var mast_base := Vector3(CRANE.x, top, CRANE.z)
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			box(mast_base + Vector3(x, (CRANE.y - top) * 0.5, z), Vector3(0.12, CRANE.y - top, 0.12), Color(0.85, 0.7, 0.1), true, 0.0, "metal")
	for k in int((CRANE.y - top) / 1.5):
		for side in 4:
			var off := Vector3(0, 0, 0.6).rotated(Vector3.UP, side * PI * 0.5)
			shape_at("cylinder", mast_base + off + Vector3(0, 0.75 + k * 1.5, 0), Vector3(0.04, 1.7, 0.04), Color(0.85, 0.7, 0.1), false,
				Vector3(0, side * 90.0, 50 if k % 2 == 0 else -50), "metal")
	_jib = group(CRANE)
	part("box", Vector3(7.0, 0.3, 0), Vector3(16.0, 0.6, 0.8), Color(0.88, 0.72, 0.12), _jib, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(-3.0, 0.2, 0), Vector3(5.0, 0.8, 1.2), Color(0.88, 0.72, 0.12), _jib, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(-4.8, -0.5, 0), Vector3(1.4, 1.2, 1.4), Color(0.5, 0.5, 0.5), _jib, Vector3.ZERO, 0.0, "concrete")
	part("box", Vector3(0.9, -1.0, 0.8), Vector3(1.4, 1.6, 1.2), Color(0.85, 0.85, 0.82), _jib, Vector3.ZERO, 0.0, "metal")
	part("sphere", Vector3(15.0, 0.7, 0), Vector3.ONE * 0.25, Color(1.0, 0.1, 0.05), _jib, Vector3.ZERO, 6.0)
	var d := GAP - CRANE
	var hook_r := Vector2(d.x, d.z).length()
	var rope := part("cylinder", Vector3(hook_r, -1.9, 0), Vector3(0.03, 3.8, 0.03), Color(0.15, 0.15, 0.15), _jib, Vector3.ZERO, 0.0, "metal")
	rope.name = "Rope"
	_girder = Node3D.new()
	_girder.position = Vector3(hook_r, -3.8, 0)
	_jib.add_child(_girder)
	var final_yaw := atan2(-d.z, d.x)
	_girder.rotation.y = -final_yaw
	for y in [0.13, -0.13]:
		part("box", Vector3(0, y, 0), Vector3(0.9, 0.04, 5.0), Color(0.62, 0.3, 0.12), _girder, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(0, 0, 0), Vector3(0.04, 0.26, 5.0), Color(0.62, 0.3, 0.12), _girder, Vector3.ZERO, 0.0, "metal")
	_girder_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.0, 0.3, 5.0)
	cs.shape = b
	cs.disabled = true
	_girder_body.add_child(cs)
	_girder_body.position = GAP + Vector3(0, -0.15, 0)
	add_child(_girder_body)
	# the controls: a pendant hanging on the top deck
	var ctl := Vector3(19.6, top + 8, -113.5)
	box(ctl + Vector3(0, 0.55, 0), Vector3(0.4, 1.1, 0.3), Color(0.9, 0.75, 0.1), true, 0.0, "metal")
	label(ctl + Vector3(0, 0.85, 0.16), 0, "SLEW", 0.05, Color(0.1, 0.1, 0.1), false)
	interactable(ctl + Vector3(0, 0.8, 0.25), Vector3(0.6, 0.6, 0.4), func(): return "Swing the crane" if not _crane_done else "",
		func(): _swing_jib(false), func(): return not _crane_done)
	trigger(Vector3(19, top + 9, -112), Vector3(1.2, 2.4, 2), func():
		Game.hud.show_thought("A gap. And on the other side - a glass walkway. The crane... the girder on the crane.", 4.0))


func _set_rope(girder_y: float) -> void:
	var r := _jib.get_node("Rope") as Node3D
	r.position.y = girder_y * 0.5
	r.scale.y = -girder_y


## A sloped walkway of boards between two points (collision: a ramp).
func _plankway(a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var d := b - a
	var L := d.length()
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var yaw := atan2(-d.x, -d.z)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	add_shape("box", Transform3D(basis * Basis.from_scale(Vector3(w, 0.08, L)), (a + b) * 0.5 + Vector3(0, -0.04, 0)), col, true, "wood")
	var n := int(L / 0.4)
	for i in n:
		var p := a + d * ((i + 0.5) / n)
		add_shape("box", Transform3D(basis * Basis.from_scale(Vector3(w, 0.03, 0.05)), p + Vector3(0, 0.01, 0)), col.darkened(0.3), false, "wood")


func _swing_jib(instant: bool) -> void:
	_crane_done = true
	Game.set_flag("above_crane")
	var d := GAP - CRANE
	var final_yaw := atan2(-d.z, d.x)
	if instant:
		_jib.rotation.y = final_yaw
		_girder.position.y = -7.15
		_set_rope(-7.15)
		_girder_body.get_child(0).disabled = false
		return
	Sfx.play("motor", -2.0, 0.6)
	Sfx.play("metal_screech", -6.0, 0.5)
	Game.hud.show_thought("It's moving. Come on. Come on.", 3.0)
	var tw := create_tween()
	tw.tween_property(_jib, "rotation:y", final_yaw, 9.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		Sfx.play("creak", 0.0, 0.5)
		Game.hud.show_thought("...It's swinging. Wait for it to stop.", 2.0))
	tw.tween_method(func(v: float): _girder.position.y = v; _set_rope(v), -3.8, -7.15, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		Sfx.play("thud", 2.0, 0.6)
		Sfx.play("hit", -6.0, 0.7)
		Game.player.jolt(Vector3(-2, 1, 0))
		_girder_body.get_child(0).disabled = false)


# ------------------------------------------------------------------ 6: the skyway

func _skyway() -> void:
	var z0 := -118.5
	var z1 := -150.0
	var frame := Color(0.25, 0.27, 0.3)
	var cz := (z0 + z1) * 0.5
	var L := z0 - z1
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.7, 0.8, 0.12)
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	# floor: concrete, except a run of glass in the middle
	box(Vector3(19, 19.9, (z0 + -128.0) * 0.5), Vector3(3.0, 0.2, z0 + 128.0), Color(0.4, 0.4, 0.42), true, 0.0, "concrete")
	box(Vector3(19, 19.9, (-134.0 + z1) * 0.5), Vector3(3.0, 0.2, -134.0 - z1), Color(0.4, 0.4, 0.42), true, 0.0, "concrete")
	var gf := solid_box(Vector3(19, 19.95, -131.0), Vector3(3.0, 0.1, 6.0), Color.WHITE)
	(gf.get_child(1) as MeshInstance3D).material_override = glass
	box(Vector3(19, 23.0, cz), Vector3(3.2, 0.2, L), frame, true, 0.0, "metal")
	for x in [17.5, 20.5]:
		var w := solid_box(Vector3(x, 21.4, cz), Vector3(0.05, 2.8, L), Color.WHITE)
		(w.get_child(1) as MeshInstance3D).material_override = glass
		box(Vector3(x, 20.05, cz), Vector3(0.12, 0.1, L), frame, false, 0.0, "metal")
	for k in int(L / 3.0) + 1:
		var z := z0 - k * 3.0
		for x in [17.5, 20.5]:
			box(Vector3(x, 21.4, z), Vector3(0.12, 2.8, 0.12), frame, false, 0.0, "metal")
		box(Vector3(19, 22.85, z), Vector3(3.0, 0.12, 0.12), frame, false, 0.0, "metal")
		if k % 2 == 0 and z > z1 + 1.0:
			var m := part("box", Vector3(19, 22.86, z - 1.5), Vector3(1.0, 0.03, 0.15), Color(0.85, 0.95, 1.0), null, Vector3.ZERO, 3.0)
			var l := omni(Vector3(19, 22.6, z - 1.5), Color(0.8, 0.9, 1.0), 0.7, 6.0, false)
			_sky_lights.append([z - 1.5, l, m])
	# the glass crack lines (shown once it cracks)
	var cracks := group(Vector3(19, 20.01, -130.5))
	cracks.name = "Cracks"
	for i in 9:
		part("box", Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), Vector3(randf_range(0.4, 1.2), 0.004, 0.012),
			Color(0.9, 0.95, 1.0), cracks, Vector3(0, randf_range(0, 180), 0), 1.5)
	cracks.visible = false
	# F's roof at the far end: the mast, a bench facing the drop
	box(Vector3(19, 20.15, -163.9), Vector3(14, 0.3, 0.2), Color(0.42, 0.42, 0.44), true, 0.0, "concrete")
	for x in [12.1, 25.9]:
		box(Vector3(x, 20.15, -157), Vector3(0.2, 0.3, 14), Color(0.42, 0.42, 0.44), true, 0.0, "concrete")
	if prop("bench", Vector3(23.5, 20, -161.5), 0.0) == null:
		box(Vector3(23.5, 20.45, -161.5), Vector3(1.6, 0.06, 0.5), Color(0.45, 0.32, 0.2), false, 0.0, "wood")
	blocker(Vector3(23.5, 20.5, -161.5), Vector3(1.7, 1.0, 0.6))
	omni(Vector3(19, 22.5, -152), Color(0.6, 0.7, 1.0), 0.6, 10.0, false)
	trigger(Vector3(19, 21, -120), Vector3(3, 2.4, 1.5), func():
		Game.hud.show_thought("Glass. All of it glass.", 2.0)
		observer.try_appear_at(Vector3(19, 20, -142)))
	trigger(Vector3(19, 21, -153), Vector3(6, 2.4, 2), func():
		if Game.has_flag("above_skyway"):
			return
		Game.set_flag("above_skyway")
		checkpoint_at("mast")
		Game.hud.show_thought("The mast. The light's at the top. A bench, up here, facing nothing.", 3.5))


func _update_skyway(p: Vector3) -> void:
	if not _in_skyway(p):
		return
	# stepping onto the glass
	if not _glass_cracked and p.z < -129.0 and p.z > -133.0:
		_glass_cracked = true
		var cr := get_node_or_null("Cracks")
		if cr:
			cr.visible = true
		Sfx.play("hit", -4.0, 1.8)
		Sfx.play("creak", -2.0, 1.4)
		Sfx.stinger("braam", -8.0)
		Game.player.jolt(Vector3(-3, 0, 1))
		Game.player.dread.add_fear(14.0, "glass")
		Game.hud.show_thought("It cracked. It CRACKED. Don't stop, don't--", 3.0)
	# the lights die behind you, one by one, close on your heels
	if p.z < -124.0:
		for e in _sky_lights:
			var l: OmniLight3D = e[1]
			if l.light_energy > 0.0 and float(e[0]) > p.z + 4.0:
				l.light_energy = 0.0
				(e[2] as MeshInstance3D).visible = false
				Sfx.play("glitch", -18.0, 2.0)


# ------------------------------------------------------------------ 7: the climax

## The platform at the top of the mast comes apart and builds a path into the sky.
func _rearrange() -> void:
	_path_started = true
	Game.set_flag("above_mast")
	Sfx.stinger("riser", 0.0)
	Sfx.play("grind", -4.0, 1.3)
	Game.player.jolt(Vector3(-3, 2, 2))
	Game.hud.show_thought("It's-- the platform's moving--", 2.5)
	var top := MAST + Vector3(0, MAST_H, 0)
	_cage[2].queue_free()     # the north rail goes first
	var n := 14
	var rise := 0.4
	var run := 1.7
	var slope := atan2(rise, run)
	var t := Game._seq
	var target := top
	for i in n:
		var f := float(i) / (n - 1)
		target = top + Vector3(sin(f * 2.4) * 2.0, i * rise - 0.09, -1.0 - i * run)
		var tile := Node3D.new()
		tile.position = top + Vector3(randf_range(-6, 6), randf_range(-12, -4), randf_range(-6, 6))
		tile.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(tile)
		var mi := MeshInstance3D.new()
		mi.mesh = Shapes.mesh("box")
		mi.scale = Vector3(1.6, 0.18, 1.6)
		mi.material_override = Shapes.surface("metal", Color(0.36, 0.36, 0.38))
		tile.add_child(mi)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.6, 0.18, 1.6)
		cs.shape = b
		body.add_child(cs)
		tile.add_child(body)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(tile, "position", target, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "rotation", Vector3(slope, 0, 0), 1.2)
		_path_tiles.append(tile)
		Sfx.play_at("thud", self, target, -6.0, 30.0)
		await get_tree().create_timer(0.35, false).timeout
		if t != Game._seq or not is_inside_tree(): return
	# a door, standing in the sky at the end of it
	var door_p := target + Vector3(0, 0.29, -1.9)
	for e in [[0, 2.15, 1.2, 0.1], [-0.6, 1.07, 0.1, 2.15], [0.6, 1.07, 0.1, 2.15]]:
		part("box", door_p + Vector3(e[0], e[1], 0), Vector3(e[2], e[3], 0.12), Color(0.95, 0.97, 1.0), null, Vector3.ZERO, 8.0)
	part("box", door_p + Vector3(0, 1.05, -0.02), Vector3(1.1, 2.1, 0.02), Color(1.0, 1.0, 1.0), null, Vector3.ZERO, 4.0)
	box(door_p + Vector3(0, -0.1, 0.4), Vector3(2.0, 0.2, 1.6), Color(0.36, 0.36, 0.38), true, 0.0, "metal")
	omni(door_p + Vector3(0, 1.4, 1.0), Color(0.9, 0.95, 1.0), 3.0, 20.0, false)
	interactable(door_p + Vector3(0, 1.05, 0.3), Vector3(1.2, 2.1, 0.4), func(): return "Step through", func(): Game.on_above_exit())
	Sfx.play("chime", -2.0, 0.6)
	Game.hud.show_thought("A path. And a door. In the sky.", 3.0)
