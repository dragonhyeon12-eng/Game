class_name AbyssZone
extends Zone
## THE DEEP, part three: beyond the glowing doorway in the sea cave. Still under the sea; still
## breathable; still walking. The leviathan only circles far below - until the station.
##
##  4 The Smaller Maze   narrow flooded service corridors; two valve wheels open the bulkhead
##  5 The Rooms          three doors (two lead back into the same room); a room with no doors (bubbles
##                       leak through the one wall you can walk through); a door that is only there
##                       while you aren't looking at it (back through it)
##  6 The Abyssal Cross  four trenches in a cross around a central rock; a beacon across each one,
##                       over a narrow arch. All four lit raise a bridge of light toward the station.
##  7 The Leviathan      the station's lights are visible from the start of the cross. Inside, the
##                       lights die. Out the far side, it comes for you across open sand.
##  8 The Exit           the glowing doorway in the cliff.

const CROSS := Vector3(0, 0, -100)
const STATION_Z := -150.0
const EXIT_Z := -205.0

var leviathan: Leviathan
var observer: Observer
var _beacon_posts := {}
var _valves := {}
var _bulkhead: StaticBody3D
var _room3_block: StaticBody3D
var _room3_door: Node3D
var _beacons := {}
var _beacon_lights := {}
var _bridge_parts: Array[Node3D] = []
var _bridge_body: StaticBody3D
var _station_lights: Array[OmniLight3D] = []
var _mast: MeshInstance3D
var _mast_light: OmniLight3D
var _chase := false
var _chase_t := 0.0
var _t := 0.0
var _hint := 0
var _snow: CPUParticles3D
var _lamps: Array[OmniLight3D] = []
var _noise_t := 8.0


func zone_id() -> String: return "abyss"
func is_nightmare() -> bool: return true
func allows_manifestation() -> bool: return true
func manifest_allowlist() -> Array: return ["flashlight"]
func fear_floor() -> float: return 25.0
func fear_decay() -> float: return 1.0
func floor_surface() -> String: return "wet"
func walk_speed() -> float: return 1.6
func sprint_speed() -> float: return 2.8
func water_level_at(_p: Vector3) -> float: return 1000.0
func breathable_at(_p: Vector3) -> bool: return true
func swim_drift_at(_p: Vector3) -> float: return -3.0
func gravity_scale_at(_p: Vector3) -> float: return 0.45
func walk_underwater() -> bool: return true
func max_fall_at(_p: Vector3) -> float: return 1000.0


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, -2.0))


# ------------------------------------------------------------------ build

func build() -> void:
	var rock := Color(0.12, 0.14, 0.15)
	var tile := Color(0.55, 0.7, 0.72)
	# arrival: a small concrete lock chamber
	box(Vector3(0, -0.1, -3), Vector3(4, 0.2, 6), rock, true, 0.0, "concrete")
	box(Vector3(0, 2.6, -3), Vector3(4, 0.2, 6), rock, true, 0.0, "concrete")
	for x in [-2.1, 2.1]:
		box(Vector3(x, 1.25, -3), Vector3(0.2, 2.7, 6), rock, true, 0.0, "concrete")
	box(Vector3(0, 1.25, 0.1), Vector3(4.4, 2.7, 0.2), rock, true, 0.0, "concrete")
	_doorway(Vector3(0, 0, 0.0), false)
	part("box", Vector3(0, 2.48, -3), Vector3(0.3, 0.06, 1.2), Color(0.8, 0.95, 1.0), null, Vector3.ZERO, 3.0)
	omni(Vector3(0, 2.2, -3), Color(0.6, 0.85, 0.95), 0.8, 7.0, false)
	_maze(rock)
	_rooms(tile)
	_cross(rock)
	_station()
	_exit()
	# murky, cold, with something huge circling far below the cross
	var env := make_env(Color(0.05, 0.12, 0.15), 0.12)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.015, 0.025)
	env.fog_enabled = true
	env.fog_light_color = Color(0.012, 0.05, 0.07)
	env.fog_density = 0.022
	env.glow_intensity = 1.2
	env.glow_bloom = 0.1
	environment(env)
	leviathan = Leviathan.new()
	leviathan.thickness = 1.5
	leviathan.orbit_center = CROSS + Vector3(0, -48, 0)
	leviathan.orbit_radius = 34.0
	leviathan.orbit_height = 0.0
	leviathan.orbit_bob = 6.0
	leviathan.speed = 7.0
	add_child(leviathan)
	_snow = marine_snow()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.position = Vector3(0, -100, 0)
	observer.seen_max_distance = 60.0
	observer.seen.connect(func():
		Game.set_flag("observer_deep")
		Sfx.stinger("braam", -4.0)
		Game.player.dread.add_fear(10.0, "observer")
		Game.hud.show_thought("Someone's standing by the last light. Down here. Standing.", 3.5))
	# a street lamp from the summer city, standing on the sea floor, still lit
	var lamp_p := Vector3(2.3, 0, -72.0)
	if prop("lamp_post", lamp_p, 200.0, 1.1) == null:
		shape_at("cylinder", lamp_p + Vector3(0, 2.0, 0), Vector3(0.12, 4.0, 0.12), Color(0.15, 0.17, 0.16), true, Vector3.ZERO, "metal")
	omni(lamp_p + Vector3(0, 4.2, 0), Color(1.0, 0.8, 0.5), 1.2, 9.0, false)
	trigger(lamp_p + Vector3(0, 1, 0), Vector3(4, 2.4, 4), func():
		Game.hud.show_thought("A street lamp. From the park. On the bottom of the sea, still on.", 3.5))
	ambient("underwater", Vector3.ZERO, false, -8.0)
	ambient("drone", Vector3.ZERO, false, -18.0)


func _doorway(pos: Vector3, lit: bool) -> void:
	for x in [-0.65, 0.65]:
		part("box", pos + Vector3(x, 1.15, 0), Vector3(0.14, 2.3, 0.2), Color(0.8, 0.95, 1.0), null, Vector3.ZERO, 6.0 if lit else 1.5)
	part("box", pos + Vector3(0, 2.33, 0), Vector3(1.44, 0.14, 0.2), Color(0.8, 0.95, 1.0), null, Vector3.ZERO, 6.0 if lit else 1.5)


# ---- 4: the smaller maze ------------------------------------------------------------

const MAZE := [
	"#####..#####",
	"#....#.....#",
	"#.##.#.###.#",
	"#.#v.....#.#",
	"#.####.#.#.#",
	"#......#...#",
	"###.####.###",
	"#...#....v.#",
	"#.#.#.####.#",
	"#.#...#....#",
	"#.#####.##.#",
	"#......#...#",
	"#####..#####",
]


func _maze(rock: Color) -> void:
	var origin := Vector3(-12, 0, -32)
	build_grid(MAZE, origin, 2.0, {".": 2.4, "v": 2.4}, 2.6, rock, rock.darkened(0.2), rock.darkened(0.3), "concrete", "concrete")
	# a few caged work lamps, most of them dying
	for cell in [Vector2i(5, 11), Vector2i(3, 6), Vector2i(10, 4), Vector2i(6, 1), Vector2i(1, 9)]:
		var lp := origin + Vector3((cell.x + 0.5) * 2.0, 2.3, (cell.y + 0.5) * 2.0)
		part("sphere", lp, Vector3(0.12, 0.16, 0.12), Color(0.95, 0.9, 0.7), null, Vector3.ZERO, 4.0)
		part("cylinder", lp + Vector3(0, 0.08, 0), Vector3(0.2, 0.06, 0.2), Color(0.2, 0.2, 0.18), null, Vector3.ZERO, 0.0, "metal")
		_lamps.append(omni(lp, Color(0.9, 0.85, 0.65), 0.7, 6.0, false))
	# two valve wheels: rows 3 and 7 ("v")
	var spots := [Vector2i(3, 3), Vector2i(9, 7)]
	for k in 2:
		var cell: Vector2i = spots[k]
		var c := origin + Vector3((cell.x + 0.5) * 2.0, 0, (cell.y + 0.5) * 2.0)
		var wheel := group(c + Vector3(0, 1.2, -0.9))
		for a in 4:
			part("box", Vector3.ZERO, Vector3(0.6, 0.04, 0.04), Color(0.55, 0.12, 0.08), wheel, Vector3(0, 0, a * 45.0), 0.0, "metal")
		part("cylinder", Vector3.ZERO, Vector3(0.62, 0.04, 0.62), Color(0.5, 0.1, 0.07), wheel, Vector3(90, 0, 0), 0.0, "metal")
		omni(c + Vector3(0, 2.0, 0), Color(1.0, 0.45, 0.2), 0.6, 4.0, false)
		var id := "v%d" % k
		interactable(c + Vector3(0, 1.2, -0.7), Vector3(0.9, 0.9, 0.5), func(): return "Turn the valve" if not _valves.has(id) else "",
			func():
				_valves[id] = true
				Game.counters["valves"] = _valves.size()
				create_tween().tween_property(wheel, "rotation:z", wheel.rotation.z + TAU * 1.5, 2.2).set_trans(Tween.TRANS_SINE)
				Sfx.play("metal_screech", -6.0, 0.8)
				Sfx.play("bubbles", -2.0)
				if _valves.size() >= 2:
					Game.set_flag("abyss_valves")
					_open_bulkhead()
				else:
					Game.hud.show_thought("Something gave, far off. One more.", 3.0),
			func(): return not _valves.has(id))
	_bulkhead = solid_box(Vector3(0, 1.2, -31), Vector3(4.0, 2.4, 0.3), Color(0.35, 0.38, 0.36), null, "metal")
	label(Vector3(0, 1.8, -30.83), 0, "BULKHEAD 4", 0.12, Color(0.85, 0.75, 0.2), false)
	trigger(Vector3(0, 1.2, -9), Vector3(4, 2.4, 2), func():
		Game.hud.show_thought("Service tunnels. Flooded. Somebody built all this down here.", 3.5))


func _open_bulkhead() -> void:
	Sfx.stinger("braam", -4.0)
	Game.hud.show_thought("The bulkhead. It's opening.", 2.5)
	create_tween().tween_property(_bulkhead, "position:y", 3.8, 3.0).set_trans(Tween.TRANS_SINE)


# ---- 5: the rooms ---------------------------------------------------------------

func _room_box(z0: float, z1: float, col: Color, doors_far: Array, door_near := true) -> void:
	var w := 8.0
	box(Vector3(0, -0.1, (z0 + z1) * 0.5), Vector3(w, 0.2, z0 - z1), col.darkened(0.2), true, 0.0, "tiles_floor")
	box(Vector3(0, 3.1, (z0 + z1) * 0.5), Vector3(w, 0.2, z0 - z1), col.darkened(0.4), true, 0.0, "tiles_ceiling")
	for x in [-w * 0.5 - 0.1, w * 0.5 + 0.1]:
		box(Vector3(x, 1.5, (z0 + z1) * 0.5), Vector3(0.2, 3.2, z0 - z1), col, true, 0.0, "tiles_pool")
	for z_wall in [z0, z1]:
		var gaps: Array = (doors_far if z_wall == z1 else ([0.0] if door_near else []))
		var xs: Array = [-w * 0.5]
		for g in gaps:
			xs.append(g - 0.6)
			xs.append(g + 0.6)
		xs.append(w * 0.5)
		for i in range(0, xs.size(), 2):
			if xs[i + 1] > xs[i]:
				box(Vector3((xs[i] + xs[i + 1]) * 0.5, 1.5, z_wall), Vector3(xs[i + 1] - xs[i], 3.2, 0.2), col, true, 0.0, "tiles_pool")
		for g in gaps:
			box(Vector3(g, 2.65, z_wall), Vector3(1.2, 0.9, 0.2), col, true, 0.0, "tiles_pool")


func _rooms(tile: Color) -> void:
	# corridor from the bulkhead
	box(Vector3(0, -0.1, -34), Vector3(4, 0.2, 4), tile.darkened(0.3), true, 0.0, "tiles_floor")
	box(Vector3(0, 2.7, -34), Vector3(4, 0.2, 4), tile.darkened(0.5), true, 0.0, "tiles_ceiling")
	for x in [-2.1, 2.1]:
		box(Vector3(x, 1.3, -34), Vector3(0.2, 2.8, 4), tile, true, 0.0, "tiles_pool")
	# room 1: three doors. only one goes anywhere.
	_room_box(-36.0, -44.0, tile, [-2.5, 0.0, 2.5])
	for k in 3:
		var x: float = [-2.5, 0.0, 2.5][k]
		var dg := door(Vector3(x, 0, -44.0), 0, Color(0.6, 0.62, 0.6), 1.0, 2.1, "wood")
		var real := k == 2
		var blk := solid_box(Vector3(x, 1.05, -44.0), Vector3(1.1, 2.1, 0.15), Color(0, 0, 0, 0))
		blk.get_child(1).visible = false
		interactable(Vector3(x, 1.0, -43.8), Vector3(1.1, 2.0, 0.4), func(): return "Open the door",
			func():
				if real:
					open_door(dg, 100.0, 1.2)
					blk.queue_free()
					Sfx.play("door_creak", -4.0)
					Game.set_flag("abyss_room1")
				else:
					Sfx.play("door_creak", -4.0, 1.2)
					Game.hud.fade_to(1.0, 0.25)
					await get_tree().create_timer(0.3, false).timeout
					Game.player.teleport(Transform3D(Basis(), Vector3(x * 0.4, 0.05, -37.0)))
					Sfx.play("glitch", -10.0)
					Game.hud.fade_to(0.0, 0.4)
					Game.player.dread.add_fear(4.0, "same room")
					Game.hud.show_thought("...It's the same room. The door opened into the same room.", 3.0))
	part("box", Vector3(-2.0, 0.45, -40), Vector3(1.8, 0.9, 0.8), Color(0.35, 0.25, 0.22), null, Vector3(0, 12, 0), 0.0, "fabric")  # a drowned sofa
	omni(Vector3(0, 2.7, -40), Color(0.6, 0.85, 0.9), 0.6, 8.0, false)
	# room 2: no doors at all. bubbles leak through one stretch of wall - and you can walk through it.
	box(Vector3(0, -0.1, -45), Vector3(2, 0.2, 2), tile.darkened(0.3), true, 0.0, "tiles_floor")
	box(Vector3(0, 2.7, -45), Vector3(2, 0.2, 2), tile.darkened(0.5), true, 0.0, "tiles_ceiling")
	for x in [-1.1, 1.1]:
		box(Vector3(x, 1.3, -45), Vector3(0.2, 2.8, 2), tile, true, 0.0, "tiles_pool")
	_room_box(-46.0, -54.0, tile.darkened(0.15), [])
	box(Vector3(0, 1.5, -54.0), Vector3(1.6, 3.2, 0.2), tile.darkened(0.15), false, 0.0, "tiles_pool")   # looks solid. isn't.
	var bub := marine_snow(80, Color(0.85, 0.95, 1.0, 0.7))
	bub.emission_box_extents = Vector3(0.6, 1.2, 0.1)
	bub.direction = Vector3(0, 1, 0)
	bub.initial_velocity_min = 0.4
	bub.initial_velocity_max = 0.8
	bub.gravity = Vector3(0, 0.3, 0)
	bub.local_coords = true
	bub.position = Vector3(0, 1.0, -53.9)
	omni(Vector3(0, 2.7, -50), Color(0.55, 0.8, 0.9), 0.5, 8.0, false)
	trigger(Vector3(0, 1.2, -47.5), Vector3(4, 2.4, 2), func():
		Game.hud.show_thought("No doors. ...But something's bubbling through that wall.", 3.5))
	trigger(Vector3(0, 1.2, -55.0), Vector3(2, 2.4, 1), func():
		Game.set_flag("abyss_room2")
		Sfx.play("bubbles", 0.0)
		Game.hud.show_thought("Through the wall. I walked through the wall.", 3.0))
	# room 3: a door that's only there while you aren't looking at it
	box(Vector3(0, -0.1, -55), Vector3(2, 0.2, 2), tile.darkened(0.3), true, 0.0, "tiles_floor")
	_room_box(-56.0, -64.0, tile.darkened(0.3), [0.0])
	_room3_door = door(Vector3(0, 0, -64.0), 0, Color(0.6, 0.62, 0.6), 1.0, 2.1, "wood")
	_room3_block = solid_box(Vector3(0, 1.05, -64.0), Vector3(1.2, 2.1, 0.3), Color(0.4, 0.5, 0.52), null, "tiles_pool")
	omni(Vector3(0, 2.7, -60), Color(0.6, 0.85, 0.9), 0.5, 8.0, false)
	trigger(Vector3(0, 1.2, -58), Vector3(6, 2.4, 2), func():
		Game.hud.show_thought("There was a door on that wall. I saw it. Out of the corner of my eye.", 4.0))
	# corridor out onto the open seabed
	box(Vector3(0, -0.1, -67), Vector3(3, 0.2, 6), tile.darkened(0.4), true, 0.0, "tiles_floor")
	box(Vector3(0, 2.7, -67), Vector3(3, 0.2, 6), tile.darkened(0.5), true)
	for x in [-1.6, 1.6]:
		box(Vector3(x, 1.3, -67), Vector3(0.2, 2.8, 6), tile.darkened(0.3), true, 0.0, "tiles_pool")


# ---- 6: the abyssal cross --------------------------------------------------------

func _cross(rock: Color) -> void:
	# a ledge from the rooms out to the south beacon
	box(Vector3(0, -0.6, -73), Vector3(6, 1.2, 6), rock, true, 0.0, "concrete")
	var arms := {"S": Vector3(0, 0, 1), "N": Vector3(0, 0, -1), "E": Vector3(1, 0, 0), "W": Vector3(-1, 0, 0)}
	# the central rock
	shape_at("cylinder", CROSS + Vector3(0, -3, 0), Vector3(18, 6, 18), rock, true, Vector3.ZERO, "concrete")
	for id in arms:
		var d: Vector3 = arms[id]
		var plat := CROSS + d * 21.0
		box(plat + Vector3(0, -3, 0), Vector3(8, 6, 8), rock.lightened(0.03), true, 0.0, "concrete")
		# a narrow natural arch over the trench
		for k in 9:
			var f := float(k) / 8.0
			var p := CROSS + d * (8.5 + f * 9.0) + Vector3(0, -0.35 - 0.25 * sin(PI * f), 0)
			box(p, (Vector3(1.4, 0.7, 1.4) if d.x == 0 else Vector3(1.4, 0.7, 1.4)), rock.darkened(0.1), true, rad_to_deg(atan2(d.x, d.z)), "concrete")
		# the beacon
		var post := plat + Vector3(0, 0, 0) - d * -2.0
		shape_at("cylinder", post + Vector3(0, 1.2, 0), Vector3(0.25, 2.4, 0.25), Color(0.3, 0.32, 0.33), true, Vector3.ZERO, "metal")
		var lamp := part("sphere", post + Vector3(0, 2.6, 0), Vector3.ONE * 0.5, Color(0.1, 0.18, 0.22), null, Vector3.ZERO, 0.2)
		var l := omni(post + Vector3(0, 2.6, 0), Color(0.3, 0.8, 1.0), 0.0, 22.0, false)
		_beacon_lights[id] = [l, lamp]
		_beacon_posts[id] = post
		interactable(post + Vector3(0, 1.2, 0), Vector3(0.9, 2.4, 0.9), func(): return "Light the beacon" if not _beacons.has(id) else "",
			func(): _light_beacon(id), func(): return not _beacons.has(id))
	# the trenches: dark, bottomless, with faint lights a long way down
	for i in 30:
		var a := randf() * TAU
		var r := randf_range(10.0, 30.0)
		part("sphere", CROSS + Vector3(cos(a) * r, randf_range(-60, -25), sin(a) * r), Vector3.ONE * randf_range(0.2, 0.5),
			Color(0.2, 0.6, 1.0), null, Vector3.ZERO, randf_range(1.0, 3.0))
	trigger(Vector3(0, 1.0, -74), Vector3(6, 2.4, 3), func():
		Game.set_flag("abyss_cross")
		Sfx.stinger("sub_drop", -2.0)
		Game.hud.show_thought("Trenches. Four of them, in a cross. And lights. Over there - a station. With its lights on.", 5.0))


func _light_beacon(id: String) -> void:
	_beacons[id] = true
	Game.counters["beacons"] = _beacons.size()
	var bl: Array = _beacon_lights[id]
	create_tween().tween_property(bl[0], "light_energy", 3.0, 1.5)
	(bl[1] as MeshInstance3D).material_override = Shapes.material(Color(0.4, 0.85, 1.0), 0.3, 6.0)
	Sfx.play("chime", -2.0, 0.5)
	Sfx.play("sub_drop", -6.0)
	Game.player.dread.add_fear(4.0, "beacon")
	if _beacons.size() >= 4:
		Game.set_flag("abyss_beacons")
		_raise_bridge()
	else:
		Game.hud.show_thought("%d. Far below, something turned toward the light." % _beacons.size(), 3.0)
		if _beacons.size() == 2:
			for other in _beacon_posts:
				if not _beacons.has(other):
					var d: Vector3 = (_beacon_posts[other] - CROSS).normalized()
					observer.try_appear_at(_beacon_posts[other] + d.cross(Vector3.UP) * 1.4)
					break


func _raise_bridge() -> void:
	Game.hud.show_thought("All four. ...A bridge. Made of light. Toward the station.", 4.0)
	Sfx.stinger("riser", -2.0)
	var start := CROSS + Vector3(0, 0, -25)
	var end_z := STATION_Z + 1.0
	var n := int((start.z - end_z) / 2.0)
	_bridge_body = StaticBody3D.new()
	add_child(_bridge_body)
	for k in n:
		var p := Vector3(0, -0.1, start.z - k * 2.0 - 1.0)
		var seg := part("box", p, Vector3(2.0, 0.12, 1.9), Color(0.35, 0.8, 1.0), null, Vector3.ZERO, 2.5)
		seg.visible = false
		_bridge_parts.append(seg)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(2.0, 0.2, 2.0)
		cs.shape = b
		cs.position = p
		_bridge_body.add_child(cs)
	for k in _bridge_parts.size():
		await get_tree().create_timer(0.08, false).timeout
		if not is_inside_tree():
			return
		_bridge_parts[k].visible = true


# ---- 7: the station, 8: the exit ----------------------------------------------

func _station() -> void:
	var metal := Color(0.32, 0.35, 0.36)
	var c := Vector3(0, 0, STATION_Z - 8)
	box(c + Vector3(0, -0.2, 0), Vector3(14, 0.4, 16), metal, true, 0.0, "metal")
	box(c + Vector3(0, 3.4, 0), Vector3(14, 0.4, 16), metal, true, 0.0, "metal")
	for x in [-7.0, 7.0]:
		box(c + Vector3(x, 1.6, 0), Vector3(0.4, 3.6, 16), metal, true, 0.0, "metal")
	for z in [8.0, -8.0]:
		box(c + Vector3(-4.5, 1.6, z), Vector3(5, 3.6, 0.4), metal, true, 0.0, "metal")
		box(c + Vector3(4.5, 1.6, z), Vector3(5, 3.6, 0.4), metal, true, 0.0, "metal")
		box(c + Vector3(0, 2.9, z), Vector3(4, 1.0, 0.4), metal, true, 0.0, "metal")
	# portholes glowing into the dark: the station is visible from the cross
	for x in [-7.25, 7.25]:
		for z in [-5.0, 0.0, 5.0]:
			part("cylinder", c + Vector3(x, 2.0, z), Vector3(0.7, 0.05, 0.7), Color(1.0, 0.85, 0.55), null, Vector3(0, 0, 90), 8.0)
	for k in 3:
		var l := omni(c + Vector3(0, 3.0, -5 + k * 5), Color(1.0, 0.85, 0.6), 1.4, 9.0, false)
		_station_lights.append(l)
	omni(c + Vector3(0, 6.0, 10), Color(1.0, 0.85, 0.6), 2.5, 30.0, false)
	# floodlights on the roof and a red mast light: the way out, visible from the edge of the cross
	shape_at("cylinder", c + Vector3(0, 7.6, 0), Vector3(0.3, 8.0, 0.3), metal, true, Vector3.ZERO, "metal")
	_mast = part("sphere", c + Vector3(0, 11.8, 0), Vector3.ONE * 0.6, Color(1.0, 0.15, 0.1), null, Vector3.ZERO, 10.0)
	_mast_light = omni(c + Vector3(0, 11.8, 0), Color(1.0, 0.2, 0.1), 2.0, 25.0, false)
	for x in [-6.0, 6.0]:
		part("box", c + Vector3(x, 3.8, 8.0), Vector3(0.8, 0.4, 0.3), Color(1.0, 0.95, 0.8), null, Vector3(-20, 0, 0), 12.0)
		spot(c + Vector3(x, 3.8, 8.3), c + Vector3(x * 0.3, -2, 30), Color(1.0, 0.93, 0.8), 6.0, 40.0, 40.0, false)
	label(c + Vector3(0, 2.8, 8.25), 0, "STATION DEEP-4", 0.2, Color(0.9, 0.9, 0.85), false)
	box(c + Vector3(3.5, 0.5, -3), Vector3(2, 1.0, 1), Color(0.25, 0.3, 0.28), true, 0.0, "metal")
	trigger(c + Vector3(0, 1.2, 4), Vector3(8, 2.4, 2), func():
		Game.set_flag("abyss_station")
		for l in _station_lights:
			create_tween().tween_property(l, "light_energy", 0.05, 0.8)
		Sfx.play("metal_screech", 2.0, 0.5)
		Sfx.stinger("braam", 2.0)
		Game.player.jolt(Vector3(-4, 3, 2))
		Game.player.dread.add_fear(12.0, "station")
		Game.hud.show_thought("The lights. Something hit the station. Something BIG. The other door - GO.", 4.0))
	# the stretch of open sand to the exit, and the cliff it's in
	box(Vector3(0, -0.5, (STATION_Z - 16 + EXIT_Z) * 0.5), Vector3(30, 1.0, STATION_Z - 16 - EXIT_Z + 4), Color(0.12, 0.13, 0.12), true, 0.0, "concrete")
	trigger(c + Vector3(0, 1.2, -9.5), Vector3(6, 2.4, 1.5), func(): _begin_chase())


func _exit() -> void:
	var rock := Color(0.08, 0.09, 0.1)
	box(Vector3(-16, 20, EXIT_Z - 2), Vector3(30, 44, 4), rock, true, 0.0, "concrete")
	box(Vector3(16, 20, EXIT_Z - 2), Vector3(30, 44, 4), rock, true, 0.0, "concrete")
	box(Vector3(0, 23.2, EXIT_Z - 2), Vector3(2.4, 42, 4), rock, true, 0.0, "concrete")
	var door_p := Vector3(0, 0, EXIT_Z - 0.2)
	_doorway(door_p, true)
	part("box", door_p + Vector3(0, 1.15, -0.3), Vector3(1.16, 2.3, 0.04), Color(0.9, 0.97, 1.0), null, Vector3.ZERO, 3.0)
	box(door_p + Vector3(0, 1.15, -1.2), Vector3(2.0, 2.4, 1.8), Color(0.08, 0.09, 0.1), true, 0.0, "concrete")   # rock behind the light
	omni(door_p + Vector3(0, 1.3, 2.0), Color(0.75, 0.9, 1.0), 3.0, 30.0, false)
	interactable(door_p + Vector3(0, 1.15, 0.2), Vector3(1.4, 2.3, 0.4), func(): return "Step through", func(): _escape())


func _begin_chase() -> void:
	if _chase:
		return
	_chase = true
	_chase_t = 0.0
	var p: Vector3 = Game.player.global_position
	leviathan.place_head(p + Vector3(48, 10, -8), Vector3(-1, -0.15, 0))
	leviathan.rush(p, 3.6)
	Sfx.stinger("screech", 2.0)
	Sfx.play("whoosh", 2.0, 0.4)
	Game.hud.show_thought("IT'S HERE. THE DOOR. RUN.", 3.0)


func _escape() -> void:
	_chase = false
	leviathan.block_at(Vector3(0, 3.0, EXIT_Z + 8.0))
	Sfx.play("thud", 6.0, 0.35)
	Game.on_deep_exit()


# ------------------------------------------------------------------ runtime

func on_player_entered(_from_save: bool) -> void:
	_t = 0.0
	_hint = 0
	_chase = false


func _process(delta: float) -> void:
	_t += delta
	var pl: Player = Game.player
	if pl == null:
		return
	# room 3's door: there only while unobserved
	var door_pos := Vector3(0, 1.0, -64.0)
	var seen := Observation.is_observed(door_pos, 0.6, [_room3_block])
	_room3_block.visible = seen
	# a wall while you look at it (never closing on you while you stand in the doorway); a door while you don't
	var in_doorway: bool = absf(pl.global_position.z + 64.0) < 0.4 and absf(pl.global_position.x) < 0.75   # inside the wall itself
	_room3_block.get_child(0).disabled = not seen or in_doorway
	_room3_door.visible = not seen
	if pl.global_position.z < -64.5 and not Game.has_flag("abyss_room3"):
		Game.set_flag("abyss_room3")
		Game.hud.show_thought("...Backwards. Through a door I couldn't look at.", 3.0)
	_snow.global_position = pl.global_position
	var blink := 1.0 if fmod(_t, 2.0) < 0.25 else 0.0
	_mast.visible = blink > 0.5
	_mast_light.light_energy = 2.0 * blink
	for i in _lamps.size():
		_lamps[i].light_energy = 0.7 * (0.15 if sin(_t * (7.0 + i * 3.1)) * sin(_t * 1.3 + i) > 0.85 else 1.0)
	if Game.in_sequence:
		return
	# the deep is never quiet: metal groaning somewhere, something vast moving, a voice that isn't one
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = randf_range(10.0, 24.0)
		var n: String = ["metal_screech", "sub_drop", "scream_far", "creak", "bubbles"][randi() % 5]
		Sfx.play(n, randf_range(-24.0, -16.0), randf_range(0.4, 0.7))
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("Another door. Another place under the sea. It doesn't end.", 4.0)
	# fell into a trench
	if pl.global_position.y < -8.0:
		Game.ankle_grab(true)
		return
	if _chase:
		_chase_t += delta
		leviathan.rush_target = pl.camera.global_position
		leviathan.speed = 3.6 + _chase_t * 0.08
		if leviathan.head_position().distance_to(pl.camera.global_position) < 3.2:
			_chase = false
			Game.entity_death("leviathan", leviathan)
