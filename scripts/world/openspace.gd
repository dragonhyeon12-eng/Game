class_name OpenSpaceZone
extends Zone
## OPEN SPACE - agoraphobia. The staff exit opens onto Level 4 of a car park that never ends: bays to the
## horizon, sodium lamps, a pale sky with nothing in it. Out in the open the fear builds on its own; under a
## roof it eases.
##
##  1 The car park   your car is out here somewhere - you can hear it chirp. It moves when you can't see it.
##  2 The road       a gas station on the horizon that gets no closer while you look at it. Watch the road.
##                   (The distance markers disagree with each other.)
##  3 The station    a payphone is ringing. It's for you.
##  4 The plaza      out the back of the shop: a square the size of a town, empty, and in it the stairs down to
##                   the subway - which move whenever you take your eyes off them.

const STATION_BASE := Vector3(14.0, 0, -260.0)
const PLAZA := Vector3(1200.0, 0, 0)
const ROAD_X := 0.0

var observer: Observer
var _car: Node3D
var _car_flash: Array[OmniLight3D] = []
var _car_t := 3.0
var _car_moves := 0
var _car_spots: Array[Vector3] = []
var _station: Node3D
var _recede := 0.0
var _last_z := 0.0
var _phone_t := 0.0
var _phone_ringing := false
var _stairs: Node3D
var _stairs_unseen := 0.0
var _stairs_moves := 0
var _back_door_at := Vector3.ZERO
var _t := 0.0
var _hint := 0
var _obs_t := 20.0
var _sheltered := false


func zone_id() -> String: return "openspace"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 10.0
func fear_decay() -> float: return 2.0
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.8
func sprint_speed() -> float: return 4.6
func max_fall_at(_p: Vector3) -> float: return 1000.0


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, 2.0))


# ------------------------------------------------------------------ build

func build() -> void:
	# the ground: the car park's tarmac, then grass hills to the horizon
	box(Vector3(0, -0.1, -20), Vector3(160, 0.2, 200), Color(0.3, 0.3, 0.31), true, 0.0, "asphalt")
	box(Vector3(0, -0.1, -500), Vector3(70, 0.2, 800), Color(0.32, 0.4, 0.22), true, 0.0, "grass")    # (flat either side of the road)
	_hills()
	_car_park()
	_road()
	_station_build()
	_plaza()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen_max_distance = 220.0
	observer.seen.connect(func():
		Game.set_flag("observer_open")
		Game.player.dread.add_dread(observer.spot_dread))
	observer.vanished.connect(func(): _obs_t = randf_range(25.0, 50.0))

	var env := make_env(Color(0.7, 0.72, 0.78), 0.55)
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.55, 0.6, 0.7)
	sm.sky_horizon_color = Color(0.85, 0.82, 0.78)
	sm.ground_horizon_color = Color(0.75, 0.72, 0.68)
	sm.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.78, 0.75)
	env.fog_density = 0.0016
	environment(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, 140, 0)
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	add_child(sun)
	ambient("wind", Vector3.ZERO, false, -12.0)
	ambient("drone", Vector3.ZERO, false, -30.0)

	# behind you: the door you came out of, standing in the open, attached to nothing
	box(Vector3(0, 1.1, 3.4), Vector3(1.3, 2.3, 0.15), Color(0.3, 0.32, 0.3), true, 0.0, "metal")
	label(Vector3(0, 2.45, 3.32), 180, "STAFF EXIT", 0.07, Color(0.2, 0.2, 0.2), false)
	label(Vector3(-3, 3.5, 0), 0, "LEVEL 4", 0.6, Color(0.9, 0.85, 0.2), false)
	part("box", Vector3(-3, 3.5, -0.05), Vector3(3.6, 1.0, 0.08), Color(0.15, 0.15, 0.16))
	part("cylinder", Vector3(-3, 1.5, -0.05), Vector3(0.12, 3.0, 0.12), Color(0.5, 0.5, 0.5))


func _car_park() -> void:
	# bays: painted lines in rows, a long way out
	var white := Color(0.85, 0.85, 0.8)
	for row in range(-6, 7):
		var z := row * 14.0 - 20.0
		for k in range(-24, 25):
			box(Vector3(k * 2.8, 0.005, z), Vector3(0.12, 0.01, 5.0), white, false)
		box(Vector3(0, 0.005, z - 2.5), Vector3(135, 0.01, 0.12), white, false)
		if row % 2 == 0:
			for k in range(-20, 21, 4):
				_car_spots.append(Vector3(k * 2.8 + 1.4, 0, z))
	# lamps on a grid
	for i in range(-3, 4):
		for j in range(-3, 4):
			var at := Vector3(i * 24.0 + 12.0, 0, j * 28.0 - 13.0)
			if prop("lamp_post", at, 0, 1.6) == null:
				shape_at("cylinder", at + Vector3(0, 4.0, 0), Vector3(0.15, 8.0, 0.15), Color(0.5, 0.5, 0.5), true)
	# other people's cars, parked, empty
	for k in 24:
		var at: Vector3 = _car_spots.pick_random()
		if at.distance_to(Vector3.ZERO) > 10.0:
			prop("car_%d" % (k % 5), at, 90.0 if randf() < 0.5 else -90.0)
	# yours
	_car = Node3D.new()
	add_child(_car)
	var model := prop("car_2", Vector3.ZERO, 90.0, 1.0, _car)
	if model == null:
		part("box", Vector3(0, 0.7, 0), Vector3(1.8, 1.2, 4.2), Color(0.5, 0.15, 0.12), _car)
	for s in [-0.7, 0.7]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.3)
		l.omni_range = 8.0
		l.light_energy = 0.0
		l.position = Vector3(2.2, 0.8, s)
		_car.add_child(l)
		_car_flash.append(l)
	_car.position = Vector3(-39.2 + 1.4, 0, -76.0)
	interactable(Vector3.ZERO, Vector3(5.0, 2.0, 2.6), func(): return "Get in" if not Game.has_flag("os_car") else "",
		func(): _get_in(), func(): return not Game.has_flag("os_car")).reparent(_car, false)


func _road() -> void:
	# out of the car park and north, dead straight
	box(Vector3(ROAD_X, 0.0, -300), Vector3(8, 0.04, 480), Color(0.2, 0.2, 0.21), false, 0.0, "asphalt")
	for k in 60:
		box(Vector3(ROAD_X, 0.025, -110 - k * 8.0), Vector3(0.15, 0.01, 3.0), Color(0.9, 0.85, 0.5), false)
	# distance markers, every 50 m: they don't agree
	var says := [250, 250, 300, 150, 250, 400, 250]
	for k in says.size():
		var at := Vector3(ROAD_X - 5.0, 0, -110 - k * 50.0)
		part("cylinder", at + Vector3(0, 0.6, 0), Vector3(0.08, 1.2, 0.08), Color(0.9, 0.9, 0.9))
		part("box", at + Vector3(0, 1.35, 0), Vector3(0.6, 0.35, 0.04), Color(0.1, 0.35, 0.15))
		label(at + Vector3(0, 1.35, 0.03), 0, "GAS  %d m" % says[k], 0.06, Color(1, 1, 1), false)
	# telephone poles down the road: some of them leaning, every one the same distance apart except the ones that aren't
	for k in 30:
		var at := Vector3(ROAD_X + 7.0, 0, -100 - k * (16.0 if k % 7 != 3 else 9.0))
		var pole := prop("utility_pole", at, 0.0)
		if pole == null:
			part("cylinder", at + Vector3(0, 4.0, 0), Vector3(0.2, 8.0, 0.2), Color(0.3, 0.25, 0.2), null, Vector3.ZERO, 0.0, "wood")
			part("box", at + Vector3(0, 7.5, 0), Vector3(1.6, 0.12, 0.12), Color(0.3, 0.25, 0.2), null, Vector3.ZERO, 0.0, "wood")
		elif k % 5 == 2:
			pole.rotation_degrees.z = 7.0 if k % 2 == 0 else -5.0


# ------------------------------------------------------------------ the hills

const HILL_CELL := 10.0
const HILL_N := 160          # cells per side: 1600 m
var _hill_noise: FastNoiseLite
var _houses: Array[Node3D] = []
var _house_t := 0.0


## How high the land is here: flat where the car park, the road and the station are, rolling hills beyond.
func hill_height(x: float, z: float) -> float:
	var flat_d := 0.0
	var in_park: float = maxf(absf(x) - 80.0, maxf(z - 80.0, -110.0 - z))
	var in_road: float = absf(x - ROAD_X) - 35.0 if z < -60.0 and z > -900.0 else 1e9
	flat_d = minf(in_park, in_road)
	if flat_d <= 0.0:
		return -0.05
	var k := smoothstep(0.0, 55.0, flat_d)
	var n := _hill_noise.get_noise_2d(x, z)
	# fields, not hills: a gentle lumpiness, a metre or two at most
	var bumps := _hill_noise.get_noise_2d(x * 4.0, z * 4.0)
	return -0.05 + k * (1.6 * (n * 0.5 + 0.5) + 0.35 * bumps + 0.3 * sin(x * 0.05) * cos(z * 0.04) + 0.15)


func _hills() -> void:
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = 7
	_hill_noise.frequency = 0.0035
	_hill_noise.fractal_octaves = 3
	var c := Vector3(0, 0, -400)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := HILL_N * HILL_CELL * 0.5
	var pts := []
	for j in HILL_N + 1:
		var row := []
		for i in HILL_N + 1:
			var x := c.x - half + i * HILL_CELL
			var z := c.z - half + j * HILL_CELL
			row.append(Vector3(x, hill_height(x, z), z))
		pts.append(row)
	for j in HILL_N:
		for i in HILL_N:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var d: Vector3 = pts[j + 1][i]
			var e: Vector3 = pts[j + 1][i + 1]
			if a.y < 0.0 and b.y < 0.0 and d.y < 0.0 and e.y < 0.0:
				continue          # (flat ground: the boxes under the car park and the road)
			for v in [a, b, e, a, e, d]:
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Shapes.surface("grass", Color(0.62, 0.7, 0.42))
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	# tall grass over the hills near the road; it moves in the wind that isn't blowing
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var count := 9000 if Settings.quality >= 1 else 2500
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 4:
		tries += 1
		var x := rng.randf_range(-180.0, 180.0)
		var z := rng.randf_range(-650.0, 110.0)
		var h := hill_height(x, z)
		if h < 0.0:
			continue       # (not on the car park, the road or the station's apron)
		var s := rng.randf_range(1.1, 2.0)
		scatter("grass_tall", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.4), s)), Vector3(x, h - 0.05, z)), Color.WHITE, "", false, false)
		placed += 1
	# the white houses. All the same house. None of them quite where a house should be.
	for k in 18:
		var side := -1.0 if k % 2 == 0 else 1.0
		var x := side * rng.randf_range(90.0, 380.0)
		var z := rng.randf_range(-650.0, 60.0)
		var h := hill_height(x, z)
		var far := Vector2(x, z + 200.0).length()
		var house := prop("house_white", Vector3(x, h - rng.randf_range(0.0, 1.2), z), 0.0, clampf(far / 220.0, 0.8, 2.6))   # (the far ones are bigger: they look the same size from the road)
		if house == null:
			break
		house.rotation.y = 0.0 if x < ROAD_X else PI         # facing the road (the model's front is its +X)
		house.rotation_degrees.x = rng.randf_range(-4.0, 4.0)
		house.rotation_degrees.z = rng.randf_range(-5.0, 5.0)
		if k == 7:
			house.position.y += 2.5                        # this one isn't touching the ground at all
		_houses.append(house)
	# a few lone trees on the tops
	for k in 10:
		var x := (-1.0 if k % 2 else 1.0) * rng.randf_range(70.0, 300.0)
		var z := rng.randf_range(-600.0, 40.0)
		prop("tree_elm", Vector3(x, hill_height(x, z) - 0.2, z), rng.randf() * 360.0, rng.randf_range(0.8, 1.3))


## When you aren't looking at them, the houses turn to face you.
func _update_houses(delta: float, p: Vector3) -> void:
	_house_t -= delta
	if _house_t > 0.0:
		return
	_house_t = 0.5
	for h in _houses:
		if Observation.in_view(h.global_position + Vector3(0, 4, 0), 8.0 * h.scale.x):
			continue
		var to := p - h.global_position
		h.rotation.y = atan2(-to.z, to.x)                  # (the model's front is its +X)


# ------------------------------------------------------------------ the station

func _station_build() -> void:
	_station = Node3D.new()
	_station.position = STATION_BASE
	add_child(_station)
	var st := _station
	# the canopy over the pumps (a roof: shelter)
	for c in [Vector3(-4, 0, -3), Vector3(4, 0, -3), Vector3(-4, 0, 3), Vector3(4, 0, 3)]:
		solid_box(c + Vector3(0, 2.4, 0), Vector3(0.4, 4.8, 0.4), Color(0.85, 0.85, 0.85), st, "metal")
	solid_box(Vector3(0, 5.0, 0), Vector3(12, 0.5, 10), Color(0.9, 0.9, 0.88), st, "metal")
	part("box", Vector3(0, 5.0, 5.02), Vector3(12, 0.5, 0.05), Color(0.85, 0.15, 0.12), st, Vector3.ZERO, 0.6)
	for x in [-2.0, 2.0]:
		solid_box(Vector3(x, 0.8, 0), Vector3(0.7, 1.6, 0.5), Color(0.85, 0.2, 0.15), st, "metal")
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.95, 0.85)
	cl.light_energy = 1.4
	cl.omni_range = 14.0
	cl.position = Vector3(0, 4.5, 0)
	st.add_child(cl)
	# the tall sign
	solid_box(Vector3(-8, 5.0, 4), Vector3(0.4, 10.0, 0.4), Color(0.6, 0.6, 0.6), st, "metal")
	part("box", Vector3(-8, 10.5, 4), Vector3(3.0, 2.0, 0.3), Color(0.95, 0.9, 0.85), st, Vector3.ZERO, 1.2)
	var sl := Label3D.new()
	sl.text = "GAS"
	sl.font_size = 96
	sl.pixel_size = 0.012
	sl.modulate = Color(0.85, 0.15, 0.12)
	sl.position = Vector3(-8, 10.5, 4.17)
	st.add_child(sl)
	# the shop: a box with a door at the front and one at the back
	var shop := Vector3(0, 0, -10)
	solid_box(shop + Vector3(-4.0, 1.6, 0), Vector3(0.2, 3.2, 6), Color(0.85, 0.83, 0.78), st, "plaster")
	solid_box(shop + Vector3(4.0, 1.6, 0), Vector3(0.2, 3.2, 6), Color(0.85, 0.83, 0.78), st, "plaster")
	solid_box(shop + Vector3(0, 3.3, 0), Vector3(8.2, 0.2, 6.2), Color(0.8, 0.8, 0.78), st, "plaster")
	for zf in [3.0, -3.0]:
		solid_box(shop + Vector3(-2.5, 1.6, zf), Vector3(3.0, 3.2, 0.2), Color(0.85, 0.83, 0.78), st, "plaster")
		solid_box(shop + Vector3(2.5, 1.6, zf), Vector3(3.0, 3.2, 0.2), Color(0.85, 0.83, 0.78), st, "plaster")
		solid_box(shop + Vector3(0, 2.75, zf), Vector3(2.0, 0.9, 0.2), Color(0.85, 0.83, 0.78), st, "plaster")
	var sh := OmniLight3D.new()
	sh.light_color = Color(0.95, 1.0, 0.95)
	sh.light_energy = 1.0
	sh.omni_range = 7.0
	sh.position = shop + Vector3(0, 2.8, 0)
	st.add_child(sh)
	solid_box(shop + Vector3(-2.8, 0.5, -1.0), Vector3(1.2, 1.0, 3.0), Color(0.5, 0.45, 0.4), st, "wood")
	# the payphone, on the wall by the back door
	var phone := shop + Vector3(3.0, 1.4, -2.85)
	if prop("payphone", phone + Vector3(0, -1.4, 0.05), 0.0, 1.0, st) == null:
		part("box", phone, Vector3(0.35, 0.55, 0.15), Color(0.2, 0.2, 0.22), st, Vector3.ZERO, 0.0, "metal")
		part("box", phone + Vector3(-0.08, 0.05, 0.1), Vector3(0.08, 0.3, 0.07), Color(0.05, 0.05, 0.05), st)
	var it := interactable(Vector3.ZERO, Vector3(0.6, 0.8, 0.6), func(): return "Answer the phone" if _phone_ringing else "",
		func(): _answer(), func(): return _phone_ringing)
	it.reparent(st, false)
	it.position = phone + Vector3(0, 0, 0.3)
	# the back door: it doesn't open onto the back of the shop
	_back_door_at = shop + Vector3(0, 0, -3.0)
	var bd := door(Vector3.ZERO, 0, Color(0.3, 0.3, 0.32), 1.0, 2.1, "metal")
	bd.reparent(st, false)
	bd.position = _back_door_at
	bd.set_meta("door", true)
	var bi := interactable(Vector3.ZERO, Vector3(1.2, 2.0, 0.5), func(): return "Out the back" if Game.has_flag("os_call") else "Back door",
		func():
			if not Game.has_flag("os_call"):
				Game.hud.show_thought("Locked. ...The phone. It's still ringing.", 2.5)
				return
			_to_plaza())
	bi.reparent(st, false)
	bi.position = _back_door_at + Vector3(0, 1.0, 0.35)
	var block := solid_box(_back_door_at + Vector3(0, 1.05, 0), Vector3(1.0, 2.1, 0.15), Color(0, 0, 0), st)
	block.get_child(1).visible = false


func _sign_point() -> Vector3:
	return _station.global_position + Vector3(-8, 10.5, 4)


func _update_station(delta: float, p: Vector3) -> void:
	if Game.has_flag("os_station") or not Game.has_flag("os_car"):
		_last_z = p.z
		return
	var moved := _last_z - p.z         # how far north you came this frame
	_last_z = p.z
	var true_d := p.distance_to(_station.global_position)
	if true_d < 22.0:
		Game.set_flag("os_station")
		Game.hud.show_thought("It's real. It's just a gas station. ...There's a phone ringing inside.", 3.5)
		_phone_ringing = true
		return
	# while you watch it, every step toward it, it takes away again
	if moved > 0.0 and moved < 1.0 and Observation.in_view(_sign_point(), 2.0, 4.0):
		_recede += moved
		_station.position.z = STATION_BASE.z - _recede
		if _recede > 30.0 and _hint < 10:
			_hint = 10
			Game.hud.show_thought("It isn't getting any closer. I've been walking for ages and it isn't getting any closer.", 4.0)
		elif _recede > 70.0 and _hint < 11:
			_hint = 11
			Game.hud.show_hint("It doesn't come any closer while you're looking at it.\nWatch the road.", 7.0)


func _answer() -> void:
	_phone_ringing = false
	Sfx.play("switch", -6.0, 1.4)
	Dialogue.start(null, "phone_mina")


# ------------------------------------------------------------------ the car

func _get_in() -> void:
	Game.in_sequence = true
	Game.set_mode("cinematic")
	var t := Game._seq
	Game.hud.fade_to(1.0, 0.5)
	Sfx.play("door_creak", -4.0, 1.2)
	await get_tree().create_timer(0.7, false).timeout
	if t != Game._seq: return
	Sfx.play("thud", -6.0, 1.2)
	Game.player.dread.set_values(maxf(Game.player.dread.fear - 20.0, 10.0), 100.0)
	Game.hud.show_thought("My car. It's my car. The seat's still warm.", 3.0)
	await get_tree().create_timer(3.2, false).timeout
	if t != Game._seq: return
	Game.hud.show_thought("A ticket on the dash: 'LEVEL 4 - BAY 0. VALID UNTIL YOU WAKE UP.'", 4.0)
	await get_tree().create_timer(4.2, false).timeout
	if t != Game._seq: return
	Sfx.play("motor", -4.0, 0.5)
	Game.hud.show_thought("It won't start. The fuel light. ...There's a gas station. Way off, past the end of the car park.", 4.5)
	await get_tree().create_timer(2.0, false).timeout
	if t != Game._seq: return
	Game.set_flag("os_car")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, 0.0), _car.global_position + Vector3(0, 0.05, 2.0)))
	Game.hud.fade_to(0.0, 1.0)
	Game.in_sequence = false
	Game.set_mode("game")


func _update_car(delta: float, p: Vector3) -> void:
	if Game.has_flag("os_car"):
		for l in _car_flash:
			l.light_energy = 0.0
		return
	_car_t -= delta
	for l in _car_flash:
		l.light_energy = maxf(0.0, l.light_energy - delta * 6.0)
	if _car_t <= 0.0:
		_car_t = 5.0
		Sfx.play_at("chime", self, _car.global_position + Vector3(0, 1, 0), 6.0, 160.0)
		get_tree().create_timer(0.25, false).timeout.connect(func(): Sfx.play_at("chime", self, _car.global_position + Vector3(0, 1, 0), 6.0, 160.0))
		for l in _car_flash:
			l.light_energy = 6.0
	# out of sight and far enough away, it isn't where you left it
	var d := p.distance_to(_car.global_position)
	if d > 30.0 and not Observation.in_view(_car.global_position + Vector3(0, 0.8, 0), 2.5) and randf() < delta * 0.12 and _car_moves < 4:
		var spots := _car_spots.filter(func(s): return s.distance_to(p) > 35.0 and s.distance_to(p) < 70.0 and not Observation.in_view(s, 3.0))
		if not spots.is_empty():
			_car_moves += 1
			_car.position = spots.pick_random()
			if _car_moves == 1:
				get_tree().create_timer(2.0, false).timeout.connect(func():
					Game.hud.show_thought("The chirp's coming from somewhere else now. ...Cars don't move on their own.", 3.5))


# ------------------------------------------------------------------ the plaza

func _plaza() -> void:
	var c := PLAZA
	box(c + Vector3(0, -0.1, -150), Vector3(400, 0.2, 400), Color(0.62, 0.6, 0.56), true, 0.0, "pavers")
	# a single bench, a single lamp, a long way apart
	prop("bench", c + Vector3(-30, 0, -80), 30)
	prop("lamp_post", c + Vector3(45, 0, -140), 0, 1.6)
	# the door you'll come out of, standing on its own
	box(c + Vector3(0, 1.1, 1.5), Vector3(1.3, 2.3, 0.15), Color(0.3, 0.3, 0.32), true, 0.0, "metal")
	# the stairs down
	_stairs = Node3D.new()
	add_child(_stairs)
	var g := _stairs
	part("box", Vector3(0, 0.02, 0), Vector3(3.4, 0.05, 5.0), Color(0.12, 0.12, 0.13), g)
	for k in 6:
		part("box", Vector3(0, -0.1 - k * 0.2, -1.5 + k * 0.5), Vector3(3.0, 0.1, 0.5), Color(0.4, 0.4, 0.4), g)
	for s in [-1.7, 1.7]:
		part("box", Vector3(s, 0.5, 0), Vector3(0.08, 1.0, 5.0), Color(0.2, 0.35, 0.25), g, Vector3.ZERO, 0.0, "metal")
	part("cylinder", Vector3(2.4, 3.2, 2.3), Vector3(0.16, 6.4, 0.16), Color(0.2, 0.2, 0.2), g)
	part("box", Vector3(2.4, 6.6, 2.3), Vector3(3.0, 1.1, 0.25), Color(0.15, 0.3, 0.8), g, Vector3.ZERO, 2.5)
	for f in [1.0, -1.0]:
		var lb := Label3D.new()
		lb.text = "SUBWAY"
		lb.font_size = 128
		lb.pixel_size = 0.012
		lb.position = Vector3(2.4, 6.6, 2.3 + f * 0.14)
		lb.rotation_degrees.y = 0.0 if f > 0 else 180.0
		g.add_child(lb)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.7, 0.8, 1.0)
	gl.light_energy = 1.0
	gl.omni_range = 6.0
	gl.position = Vector3(0, 0.5, -1)
	g.add_child(gl)
	_stairs.position = c + Vector3(20, 0, -120)
	var it := interactable(Vector3.ZERO, Vector3(3.4, 1.6, 4.0), func(): return "Go down the stairs",
		func(): Game.on_openspace_exit())
	it.reparent(g, false)
	it.position = Vector3(0, 0.6, 0)


func _to_plaza() -> void:
	Game.in_sequence = true
	Game.set_mode("cinematic")
	var t := Game._seq
	Sfx.play("door_creak", -2.0, 0.9)
	Game.hud.fade_to(1.0, 0.4, Color(1, 1, 1))
	await get_tree().create_timer(0.6, false).timeout
	if t != Game._seq: return
	Game.player.teleport(Transform3D(Basis(Vector3.UP, 0.0), PLAZA + Vector3(0, 0.05, -0.5)))
	Game.set_flag("os_plaza")
	Sfx.play("wind", 0.0, 0.8)
	Sfx.play("dark_soundscape", -3.0)
	Game.hud.fade_to(0.0, 1.5, Color(1, 1, 1))
	Game.in_sequence = false
	Game.set_mode("game")
	await get_tree().create_timer(1.5, false).timeout
	Game.hud.show_thought("That was the back of a shop. This is... a square. It doesn't end. ...There. Stairs. Down.", 4.5)


func _update_stairs(delta: float, p: Vector3) -> void:
	if not Game.has_flag("os_plaza"):
		return
	var at := _stairs.global_position + Vector3(1.2, 3.5, 1.0)
	var d := Vector2(p.x - at.x, p.z - at.z).length()
	if d < 8.0:
		_stairs_unseen = 0.0
		return
	if Observation.in_view(at, 2.0):
		_stairs_unseen = 0.0
		return
	_stairs_unseen += delta
	if _stairs_unseen > 0.9:
		# gone: somewhere else, a long way off, wherever you're not looking
		_stairs_unseen = 0.0
		_stairs_moves += 1
		var fwd := -Game.player.global_transform.basis.z
		fwd.y = 0.0
		for tries in 12:
			var a := randf() * TAU
			var r := randf_range(70.0, 130.0)
			var cand := Vector3(p.x + cos(a) * r, 0, p.z + sin(a) * r)
			if absf(cand.x - PLAZA.x) < 190.0 and cand.z < PLAZA.z - 10.0 and cand.z > PLAZA.z - 340.0 and not Observation.in_view(cand, 3.0):
				_stairs.global_position = cand
				break
		Sfx.play_at("whoosh", self, _stairs.global_position, 6.0, 300.0)
		if _stairs_moves == 1:
			Game.hud.show_thought("Where - they were right there. ...Don't take your eyes off them this time.", 4.0)
		elif _stairs_moves == 3:
			Game.hud.show_hint("The stairs move when you look away.\nKeep them in sight all the way there.", 7.0)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0


func _process(delta: float) -> void:
	if Game.player:
		_update_houses(delta, Game.player.global_position)
	_t += delta
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_update_car(delta, p)
	_update_station(delta, p)
	_update_stairs(delta, p)
	if _phone_ringing:
		_phone_t -= delta
		if _phone_t <= 0.0:
			_phone_t = 2.4
			var ph := _station.global_position + Vector3(3.0, 1.4, -12.85)
			Sfx.play_at("chime", self, ph, 2.0, 60.0)
			get_tree().create_timer(0.35, false).timeout.connect(func(): Sfx.play_at("chime", self, ph, 2.0, 60.0))
	# out in the open, it builds; under a roof (the canopy, the shop) it eases
	var st := _station.global_position
	_sheltered = absf(p.x - st.x) < 6.0 and p.z < st.z + 5.0 and p.z > st.z - 13.0
	if not _sheltered and pl.dread.fear < 65.0:
		pl.dread.add_fear(1.2 * delta, "open")
	if not observer.visible:
		_obs_t -= delta
		if _obs_t <= 0.0:
			_obs_t = 10.0
			var fwd := -pl.global_transform.basis.z
			fwd.y = 0.0
			observer.try_appear_at(p + fwd.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(120.0, 180.0))
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("Outside. ...Level 4? There's no building. There's no edge. It just goes on.", 4.0)
	elif _hint == 1 and _t > 8.0:
		_hint = 2
		Game.hud.show_thought("That chirp - that's my car. My car's out here somewhere.", 3.5)
