class_name AboveZone
extends Zone
## ABOVE - fear of heights. The freight elevator opens onto a rooftop above the clouds, at night.
## Towers go down into the fog further than towers should.
##
## Goal: reach the light at the top of the radio mast on the third roof.
##  - The bridge controls on the second roof need a key. The key is at the far end of a plank that
##    sticks out over the drop from the first roof.
##  - The second roof is reached along a bare steel beam. Wind gusts push you off unless you crouch.
##    Once you're across, the beam is gone.
##  - The key extends a bridge to the third roof. Climb the mast. Touch the light.
## Looking down fills DREAD. Falling is a long way. Sometimes, far off, someone else falls.

const TOWER_A := Rect2(-7, -7, 14, 14)
const TOWER_B := Rect2(19, -5, 10, 10)
const TOWER_C := Rect2(20, -26, 8, 8)
const MAST := Vector3(24, 0, -22)
const MAST_H := 18.0
const PLANK_END := -13.1
const FALL_Y := -14.0

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
var _obs_t := 20.0
var _roofs: Array = []     # distant rooftop spots for the Observer
var _creak_t := 0.0
var _t := 0.0
var _hint := 0


func zone_id() -> String: return "above"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 15.0
func fear_decay() -> float: return 1.2
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.3
func sprint_speed() -> float: return 3.8
func max_fall_at(_p: Vector3) -> float: return 40.0


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, 5.4))


## Wind pushes you (Player adds it to its movement unless crouched).
func wind_at(p: Vector3) -> Vector3:
	if _gust_phase != 2 or _in_hut(p) or p.y < -6.0:
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
	observer.seen.connect(func(): Game.player.dread.add_dread(observer.spot_dread))
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
		blocker(MAST + off + Vector3(0, MAST_H + 0.6, 0), csz)
	_beacon_mesh = part("sphere", MAST + Vector3(0, MAST_H + 1.1, 0), Vector3.ONE * 0.35, Color(1.0, 0.1, 0.05), null, Vector3.ZERO, 6.0)
	_beacon = omni(MAST + Vector3(0, MAST_H + 1.3, 0), Color(1.0, 0.12, 0.06), 4.0, 30.0, false)
	interactable(MAST + Vector3(0, 1.0, 1.0), Vector3(0.9, 2.0, 0.6), func(): return "Climb the ladder",
		func(): _climb(), func(): return not _climbing and Game.player.global_position.y < 2.0)
	interactable(MAST + Vector3(0, MAST_H + 1.1, 0), Vector3(0.9, 0.9, 0.9), func(): return "Touch the light",
		func(): Game.on_above_exit())


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
	# a floor of cloud far below: one sheet, and heaped billows on it
	box(Vector3(12, -46, -8), Vector3(600, 0.5, 600), Color(0.17, 0.18, 0.24), false, 0.0, 1.0)
	for i in 160:
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * 260.0
		var s := rng.randf_range(18.0, 55.0)
		var p := Vector3(cos(ang) * dist + 12, rng.randf_range(-47.0, -42.0), sin(ang) * dist - 8)
		shape_at("sphere", p, Vector3(s, s * 0.16, s * 0.9), Color(0.19, 0.2, 0.27).lightened(rng.randf_range(0.0, 0.06)), false, Vector3(0, rng.randf_range(0, 360), 0), 1.0)


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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.045)
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.11)
	env.fog_density = 0.006
	env.fog_height = -30.0
	env.fog_height_density = 0.08
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
		tw.tween_property(pl, "global_position:y", MAST_H * f + 0.05, 0.22)
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
	Game.hud.show_thought("The light. It's warm. It's so warm.", 3.5)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	if Game.has_flag("above_key"):
		_key.visible = false
	if Game.has_flag("above_bridge"):
		_extend_bridge(true)


func _process(delta: float) -> void:
	_t += delta
	_beacon.light_energy = 4.0 if fmod(_t, 1.6) < 0.8 else 0.4
	_update_fallers(delta)
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	if p.y < FALL_Y:
		Game.fall_death()
		return
	_hints(p)
	_update_wind(delta, p)
	_update_height_fear(delta, pl)
	_update_beam(delta, p)
	_update_plank(delta, p)
	_update_observer(delta)
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
	if over_void:
		pl.dread.add_fear(5.0 * delta, "over the drop")
	if down > 0.0:
		var look := PhysicsRayQueryParameters3D.create(cam, cam - pl.camera.global_transform.basis.z * 40.0, 1)
		look.exclude = [pl.get_rid()]
		var hit := space.intersect_ray(look)
		if hit.is_empty() or hit.position.y < -8.0:
			pl.dread.add_fear(14.0 * down * delta, "looking down")
			pl.dread.add_stability(-4.0 * down * delta)


func _update_beam(delta: float, p: Vector3) -> void:
	if p.x > 19.5 and absf(p.z) < 5.0 and p.y > -1.0:
		if not Game.has_flag("above_cross"):
			Game.set_flag("above_cross")
			Game.hud.show_thought("Across. I'm across.", 2.5)
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
