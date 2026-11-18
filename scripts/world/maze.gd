class_name MazeZone
extends Zone
## The first nightmare: endless yellow office corridors under fluorescent light.
##
## A seeded spanning-tree maze (always solvable) plus extra openings and open-plan rooms. Walls that are
## NOT part of the spanning tree may open or close while unobserved, so the way out always exists but
## the way you came may not. Lights die, a chair keeps turning up, a picture of a summer street appears.
## The exit is wherever the hum is loudest.

enum Edge { WALL, OPEN, EXTRA, DYNAMIC }
const DX := [1, -1, 0, 0]
const DZ := [0, 0, 1, -1]

const W := 12
const H := 12
const CELL := 5.0
const WALL_H := 2.9
const THICK := 0.24
const PILLAR := 0.28   # slightly thicker than walls

const WALL_A := Color(0.84, 0.74, 0.4)
const WALL_B := Color(0.8, 0.7, 0.36)
const BASEBOARD := Color(0.45, 0.38, 0.2)
const CARPET := Color(0.42, 0.36, 0.19)
const CEILING := Color(0.8, 0.77, 0.58)
const PANEL := Color(1.0, 0.97, 0.86)
const LIGHT := Color(1.0, 0.95, 0.78)

var seed_value := 1
var observer: Observer

var _edges_x := PackedInt32Array()  # between (x,z) and (x+1,z): x*H + z
var _edges_z := PackedInt32Array()  # between (x,z) and (x,z+1): x*(H-1) + z
var _dynamic: Array = []            # [{body, center, open}]
var _lights: Array = []             # [{light, panel, base, dip, level, dead}]
var _exit_cell := Vector2i.ZERO
var _exit_dir := 0
var _start_yaw := 0.0
var _chair: Node3D
var _pictures: Array[Node3D] = []
var _picture_shown := false
var _hum: AudioStreamPlayer
var _t := 0.0
var _hint := 0
var _obs_cooldown := 40.0
var _obs_check := 0.0
var _obs_present := 0.0
var _obs_seen_now := false
var _sightings := 0
# the expedition: maintenance wing, breakers, power, the hunt, the elevator
var _maint_door: Node3D
var _maint_block: StaticBody3D
var _breakers: Array = []        # [{group, letter, up}]
var _order: Array = []           # correct breaker order (letters)
var _flipped: Array = []
var _main_switch: Node3D
var _wing_lights: Array = []
var _stalker: Stalker
var _hunting := false
var _side := 1.0                  # which side of the wing the escape passage runs (+1 / -1 along its local Z)
var _side_cell := Vector2i(-1, -1)  # the maze cell the escape passage comes out in
var _shutter: StaticBody3D
var _escape_door: Node3D
var _escape_block: StaticBody3D
var _trail: Array[Vector3] = []   # the player's footsteps since the power came on (the stalker follows them)
# the chase: once you're back in the maze with it behind you, the maze closes down to one route to the lift
var _chase_on := false
var _chase_path: Array[Vector2i] = []
var _chase_idx := 0
var _sealed := {}                 # "x,z|x,z" -> true: openings slammed shut
var _env: Environment
var _prop_cells := {}             # cells with something big in the middle (the cart, the bench): the chase route goes round them
var _seal_queue: Array = []       # [time, path index]
var _chase_lights: Array[OmniLight3D] = []
var _chase_t := 0.0
var _shriek_t := 2.0
var _beat_t := 0.0
var _path: Array = []
var _path_t := 0.0
var _glass: StaticBody3D
var _lift_doors: Array[Node3D] = []
var _lift_light: OmniLight3D
var _lift_sign: MeshInstance3D
var _wing_xf := Transform3D.IDENTITY


func zone_id() -> String: return "maze"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 10.0
func fear_decay() -> float: return 1.2
func floor_surface() -> String: return "carpet"
func walk_speed() -> float: return 2.4
func sprint_speed() -> float: return 4.0
func anomaly_pacing() -> Vector2: return Vector2(35, 5)


func cell_center(x: int, z: int) -> Vector3:
	return Vector3(x * CELL, 0, z * CELL)


func _in(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < W and z < H


## Vector2i(which, index) of the edge from (x,z) in direction d: which 0 = X edges, 1 = Z edges, -1 = boundary.
func _edge(x: int, z: int, d: int) -> Vector2i:
	var nx: int = x + DX[d]
	var nz: int = z + DZ[d]
	if not _in(x, z) or not _in(nx, nz):
		return Vector2i(-1, -1)
	if d <= 1:
		return Vector2i(0, mini(x, nx) * H + z)
	return Vector2i(1, x * (H - 1) + mini(z, nz))


func _get_edge(x: int, z: int, d: int) -> int:
	var e := _edge(x, z, d)
	if e.x < 0:
		return -1
	return _edges_x[e.y] if e.x == 0 else _edges_z[e.y]


func _set_edge(x: int, z: int, d: int, v: int) -> void:
	var e := _edge(x, z, d)
	if e.x == 0:
		_edges_x[e.y] = v
	elif e.x == 1:
		_edges_z[e.y] = v


func passable(x: int, z: int, d: int) -> bool:
	if not _sealed.is_empty() and _sealed.has(_edge_key(Vector2i(x, z), Vector2i(x + DX[d], z + DZ[d]))):
		return false
	var t := _get_edge(x, z, d)
	if t == Edge.OPEN or t == Edge.EXTRA:
		return true
	if t == Edge.DYNAMIC:
		var mid := (cell_center(x, z) + cell_center(x + DX[d], z + DZ[d])) * 0.5
		for w in _dynamic:
			if Vector2(w.center.x - mid.x, w.center.z - mid.z).length() < 0.01:
				return w.open
	return false


func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(p.x / CELL), 0, W - 1), clampi(roundi(p.z / CELL), 0, H - 1))


# ------------------------------------------------------------------ build

func build() -> void:
	_generate()
	_geometry()
	_build_lights()
	_props()
	_exit()
	_expedition()
	_register_anomalies()
	_hum = ambient("hum", Vector3.ZERO, false, -18.0)
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.position = Vector3(0, -100, 0)
	observer.seen_threshold = 0.35
	observer.seen_max_distance = 40.0
	observer.seen.connect(_on_observer_seen)
	observer.vanished.connect(func(): _obs_cooldown = randf_range(30.0, 75.0))


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_edges_x.resize((W - 1) * H)
	_edges_x.fill(Edge.WALL)
	_edges_z.resize(W * (H - 1))
	_edges_z.fill(Edge.WALL)

	# randomised depth-first spanning tree: every cell reachable through OPEN edges, forever
	var visited := {}
	var stack := [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var dirs := []
		for d in 4:
			var n := Vector2i(c.x + DX[d], c.y + DZ[d])
			if _in(n.x, n.y) and not visited.has(n):
				dirs.append(d)
		if dirs.is_empty():
			stack.pop_back()
			continue
		var d: int = dirs[rng.randi() % dirs.size()]
		_set_edge(c.x, c.y, d, Edge.OPEN)
		var n := Vector2i(c.x + DX[d], c.y + DZ[d])
		visited[n] = true
		stack.append(n)

	# non-tree walls: some removed (loops), some dynamic (may change while unobserved)
	for arr_name in ["_edges_x", "_edges_z"]:
		var arr: PackedInt32Array = get(arr_name)
		for i in arr.size():
			if arr[i] != Edge.WALL:
				continue
			var r := rng.randf()
			if r < 0.12:
				arr[i] = Edge.EXTRA
			elif r < 0.27:
				arr[i] = Edge.DYNAMIC
		set(arr_name, arr)

	# a few open-plan "office" rooms (2x2)
	for r in 3:
		var rx := rng.randi_range(1, W - 3)
		var rz := rng.randi_range(1, H - 3)
		for e in [[rx, rz, 0], [rx, rz + 1, 0], [rx, rz, 2], [rx + 1, rz, 2]]:
			if _get_edge(e[0], e[1], e[2]) != Edge.OPEN:
				_set_edge(e[0], e[1], e[2], Edge.EXTRA)

	# exit: the boundary cell farthest from the start (BFS over permanent openings)
	var dist := {Vector2i(0, 0): 0}
	var queue := [Vector2i(0, 0)]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in 4:
			var t := _get_edge(c.x, c.y, d)
			if t != Edge.OPEN and t != Edge.EXTRA:
				continue
			var n := Vector2i(c.x + DX[d], c.y + DZ[d])
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	var best := -1
	for x in W:
		for z in H:
			var c := Vector2i(x, z)
			if (x == W - 1 or z == H - 1) and dist.get(c, -1) > best:
				best = dist[c]
				_exit_cell = c
	_exit_dir = 0 if _exit_cell.x == W - 1 else 2
	# the escape passage comes back into the maze one cell along the edge (the wing's local +Z if there's room)
	if _exit_dir == 0:
		_side = 1.0 if _exit_cell.y + 1 < H else -1.0
		_side_cell = Vector2i(W - 1, _exit_cell.y + int(_side))
	else:
		_side = 1.0 if _exit_cell.x >= 1 else -1.0
		_side_cell = Vector2i(_exit_cell.x - int(_side), H - 1)

	for d in 4:
		if _get_edge(0, 0, d) == Edge.OPEN:
			# yaw so the camera's -Z faces direction d
			var dir := Vector3(DX[d], 0, DZ[d])
			_start_yaw = atan2(-dir.x, -dir.z)
			break


func _wall(center: Vector3, along_z: bool, length: float, color: Color) -> void:
	var size := Vector3(THICK, WALL_H, length) if along_z else Vector3(length, WALL_H, THICK)
	box(center + Vector3(0, WALL_H * 0.5, 0), size, color, true, 0.0, "wallpaper")
	var base := Vector3(THICK + 0.03, 0.12, length) if along_z else Vector3(length, 0.12, THICK + 0.03)
	box(center + Vector3(0, 0.06, 0), base, BASEBOARD, false)


func _geometry() -> void:
	var mid := Vector3((W - 1) * CELL * 0.5, 0, (H - 1) * CELL * 0.5)
	var ext := Vector3(W * CELL + 2, 0.1, H * CELL + 2)
	box(mid + Vector3(0, -0.05, 0), ext, CARPET, true, 0.0, "carpet")
	box(mid + Vector3(0, WALL_H + 0.05, 0), ext, CEILING, true, 0.0, "tiles_ceiling")
	for x in W + 1:
		box(Vector3((x - 0.5) * CELL, WALL_H - 0.012, mid.z), Vector3(0.04, 0.02, H * CELL), CEILING.darkened(0.2), false)
	for z in H + 1:
		box(Vector3(mid.x, WALL_H - 0.02, (z - 0.5) * CELL), Vector3(W * CELL, 0.02, 0.04), CEILING.darkened(0.2), false)
	# A pillar at every wall junction. Walls end *inside* the pillars, so no two faces ever share a plane
	# (coplanar faces flicker - "z-fighting").
	for x in W + 1:
		for z in H + 1:
			box(Vector3((x - 0.5) * CELL, WALL_H * 0.5, (z - 0.5) * CELL), Vector3(PILLAR, WALL_H, PILLAR), WALL_A, true, 0.0, "wallpaper")

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var length := CELL - PILLAR + 0.04
	for x in W:
		for z in H:
			for d in [0, 2]:
				var t := _get_edge(x, z, d)
				if t < 0:
					continue
				var center := (cell_center(x, z) + cell_center(x + DX[d], z + DZ[d])) * 0.5
				var along_z: bool = d == 0
				var col := WALL_B if rng.randf() < 0.3 else WALL_A
				if t == Edge.WALL:
					_wall(center, along_z, length, col)
				elif t == Edge.DYNAMIC:
					var size := Vector3(THICK, WALL_H, length) if along_z else Vector3(length, WALL_H, THICK)
					var body := solid_box(center + Vector3(0, WALL_H * 0.5, 0), size, col, null, "wallpaper")
					var w := {"body": body, "center": center, "open": false}
					_dynamic.append(w)
					_set_dynamic(w, rng.randf() < 0.5)

	for x in W:
		_wall(Vector3(x * CELL, 0, -0.5 * CELL), false, length, WALL_A)
		if not (_exit_dir == 2 and (_exit_cell.x == x or _side_cell.x == x)):
			_wall(Vector3(x * CELL, 0, (H - 0.5) * CELL), false, length, WALL_A)
	for z in H:
		_wall(Vector3(-0.5 * CELL, 0, z * CELL), true, length, WALL_A)
		if not (_exit_dir == 0 and (_exit_cell.y == z or _side_cell.y == z)):
			_wall(Vector3((W - 0.5) * CELL, 0, z * CELL), true, length, WALL_A)

	var env := make_env(Color(0.9, 0.82, 0.55), 0.25)
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.02)
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.5, 0.3)
	env.fog_density = 0.012
	if Settings.quality >= 1:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.01
		env.volumetric_fog_albedo = Color(1.0, 0.95, 0.75)
	environment(env)


func _set_dynamic(w: Dictionary, open: bool) -> void:
	w.open = open
	var body: StaticBody3D = w.body
	body.visible = not open
	body.get_child(0).disabled = open


func _build_lights() -> void:
	for x in range(0, W, 2):
		for z in range(0, H, 2):
			var c := cell_center(x, z)
			var panel := part("box", c + Vector3(0, WALL_H - 0.02, 0), Vector3(1.2, 0.03, 0.6), PANEL, null, Vector3.ZERO, 3.0)
			var l := omni(c + Vector3(0, WALL_H - 0.3, 0), LIGHT, 1.6, 8.0, false)
			_lights.append({"light": l, "panel": panel, "base": 1.6, "dip": 0.0, "level": 1.0, "dead": false})


func _props() -> void:
	# The office chair. You will see it again.
	_chair = group(cell_center(0, 0) + Vector3(1.4, 0, 1.5), 200)
	var dark := Color(0.12, 0.12, 0.14)
	part("box", Vector3(0, 0.48, 0), Vector3(0.48, 0.07, 0.48), dark, _chair)
	part("box", Vector3(0, 0.82, -0.22), Vector3(0.44, 0.55, 0.06), dark, _chair)
	part("cylinder", Vector3(0, 0.25, 0), Vector3(0.05, 0.42, 0.05), dark, _chair)
	part("cylinder", Vector3(0, 0.04, 0), Vector3(0.55, 0.05, 0.55), dark, _chair)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	for i in 6:
		var c := Vector2i(rng.randi_range(1, W - 1), rng.randi_range(1, H - 1))
		if c == _exit_cell:
			continue
		# in a corner of the room, never across the middle where you'd run through it
		var reach := 1.3 if i % 2 == 0 else 1.5
		var p := cell_center(c.x, c.y) + Vector3(reach * (1.0 if rng.randf() < 0.5 else -1.0), 0, (1.4 if i % 2 == 0 else 1.25) * (1.0 if rng.randf() < 0.5 else -1.0))
		if i % 2 == 0:  # water cooler
			box(p + Vector3(0, 0.5, 0), Vector3(0.32, 1.0, 0.32), Color(0.85, 0.85, 0.82))
			shape_at("cylinder", p + Vector3(0, 1.25, 0), Vector3(0.28, 0.48, 0.28), Color(0.5, 0.7, 0.85), false, Vector3.ZERO, 0.15)
		else:           # an abandoned desk
			box(p + Vector3(0, 0.73, 0), Vector3(1.4, 0.04, 0.7), Color(0.55, 0.5, 0.42))
			box(p + Vector3(-0.6, 0.36, 0), Vector3(0.04, 0.72, 0.66), Color(0.4, 0.38, 0.33), false)
			box(p + Vector3(0.6, 0.36, 0), Vector3(0.04, 0.72, 0.66), Color(0.4, 0.38, 0.33), false)

	# Pictures of a summer street that should not be here. Hidden until the dream leaks.
	for i in 3:
		var z := rng.randi_range(2, H - 2)
		var pic := group(Vector3(-0.5 * CELL + THICK * 0.5 + 0.015, 1.5, z * CELL), 90)
		part("box", Vector3.ZERO, Vector3(0.7, 0.52, 0.02), Color(0.2, 0.14, 0.08), pic)
		part("box", Vector3(0, 0.08, 0.015), Vector3(0.62, 0.28, 0.01), Color(0.45, 0.7, 0.95), pic)
		part("box", Vector3(0, -0.12, 0.015), Vector3(0.62, 0.16, 0.01), Color(0.85, 0.62, 0.45), pic)
		part("sphere", Vector3(0.18, 0.15, 0.02), Vector3.ONE * 0.08, Color(1.0, 0.85, 0.3), pic)
		part("box", Vector3(-0.16, -0.08, 0.022), Vector3(0.03, 0.1, 0.01), Color.BLACK, pic)  # a small black figure
		pic.visible = false
		_pictures.append(pic)


func _exit() -> void:
	var along_z := _exit_dir == 0
	var center := Vector3((W - 0.5) * CELL, 0, _exit_cell.y * CELL) if _exit_dir == 0 else Vector3(_exit_cell.x * CELL, 0, (H - 0.5) * CELL)
	var inward := Vector3(-1, 0, 0) if _exit_dir == 0 else Vector3(0, 0, -1)
	var along := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var length := CELL - PILLAR + 0.04
	var door_half := 0.6
	var side_len := length * 0.5 - door_half
	_wall(center + along * (door_half + side_len * 0.5), along_z, side_len, WALL_A)
	_wall(center - along * (door_half + side_len * 0.5), along_z, side_len, WALL_A)
	var lintel_h := WALL_H - 2.2
	box(center + Vector3(0, 2.2 + lintel_h * 0.5, 0), Vector3(THICK, lintel_h, 1.2) if along_z else Vector3(1.2, lintel_h, THICK), WALL_A)
	# not an exit: a grey steel door, MAINTENANCE - STAFF ONLY, into the wing behind the yellow rooms
	_maint_door = door(center - inward * 0.02, rad_to_deg(atan2(inward.x, inward.z)), Color(0.42, 0.44, 0.46), 1.08, 2.14, "metal")
	_maint_block = solid_box(center + Vector3(0, 1.07, 0), Vector3(0.2, 2.14, 1.1) if along_z else Vector3(1.1, 2.14, 0.2), Color(0, 0, 0, 0))
	_maint_block.get_child(1).visible = false
	var sign_pos := center + inward * (THICK * 0.5 + 0.04) + Vector3(0, 2.5, 0)
	part("box", sign_pos, Vector3(0.06, 0.24, 0.84) if along_z else Vector3(0.84, 0.24, 0.06), Color(0.55, 0.06, 0.04), null, Vector3.ZERO, 1.2)
	var yaw := rad_to_deg(atan2(inward.x, inward.z))
	label(sign_pos + inward * 0.035, yaw, "MAINTENANCE\nSTAFF ONLY", 0.1, Color(1.0, 0.92, 0.85))
	omni(sign_pos + inward * 0.3, Color(1.0, 0.3, 0.2), 0.4, 3.0, false)
	ambient("buzz", center + inward * 0.4 + Vector3(0, 2.0, 0), true, -6.0, 18.0)
	interactable(center - inward * 0.02 + Vector3(0, 1.1, 0), Vector3(0.3, 2.1, 1.16) if along_z else Vector3(1.16, 2.1, 0.3),
		func(): return "Maintenance door" if _maint_block.visible else "",
		func(): _open_maint(), func(): return _maint_block.visible)
	_wing(center, -inward, along)


func exit_position() -> Vector3:
	return Vector3((W - 0.5) * CELL, 0, _exit_cell.y * CELL) if _exit_dir == 0 else Vector3(_exit_cell.x * CELL, 0, (H - 0.5) * CELL)


func exit_inward() -> Vector3:
	return Vector3(-1, 0, 0) if _exit_dir == 0 else Vector3(0, 0, -1)


func player_start() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _start_yaw), cell_center(0, 0) + Vector3(0, 0.05, 0))


# ------------------------------------------------------------------ anomalies

func _register_anomalies() -> void:
	# walls that come and go (never part of the spanning tree: the maze stays solvable)
	for w in _dynamic:
		Anomalies.register({"id": "wall", "owner": self, "position": w.center + Vector3(0, WALL_H * 0.5, 0), "radius": 2.6,
			"min_unobserved": 2.5, "discovery_fear": 3.0,
			"can_apply": func(): return not _chase_on,
			"apply": func(): _set_dynamic(w, not w.open)})
	# lights that die (and sometimes come back)
	for i in _lights.size():
		if i % 3 != 1:
			continue
		var l: Dictionary = _lights[i]
		Anomalies.register({"id": "light", "owner": self, "position": l.light.position, "radius": 1.2, "min_stage": 1,
			"weight": 0.6, "discovery_fear": 2.0,
			"apply": func():
				l.dead = not l.dead
				l.panel.material_override = Shapes.material(Color(0.35, 0.34, 0.3)) if l.dead else Shapes.material(PANEL, 0.85, 3.0)})
	# the chair moves to another room
	Anomalies.register({"id": "chair", "owner": self, "radius": 0.9, "weight": 1.2, "discovery_fear": 4.0, "max_distance": 60.0,
		"get_position": func(): return _chair.global_position + Vector3(0, 0.5, 0),
		"apply": func():
			for attempt in 12:
				var c := Vector2i(randi_range(0, W - 1), randi_range(0, H - 1))
				var p := cell_center(c.x, c.y) + Vector3(randf_range(-1.4, 1.4), 0, randf_range(-1.4, 1.4))
				if not Observation.is_observed(p + Vector3(0, 0.5, 0), 0.9):
					_chair.position = p
					_chair.rotation.y = randf() * TAU
					break})
	# something from the summer leaks in (once)
	for pic in _pictures:
		Anomalies.register({"id": "picture", "owner": self, "position": pic.position, "radius": 0.6, "min_stage": 1,
			"max_changes": 1, "weight": 0.8, "discovery_fear": 6.0,
			"can_apply": func(): return not _picture_shown,
			"apply": func():
				_picture_shown = true
				pic.visible = true})


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0


func _process(delta: float) -> void:
	_t += delta
	if _hunting and not _chase_on and Game.player and _in_grid(Game.player.global_position) and not Game.in_sequence:
		_begin_chase()
	if _chase_on:
		_update_chase(delta)
	if Game.has_flag("maze_power") and Game.player:
		var pp: Vector3 = Game.player.global_position
		if _trail.is_empty() or _trail[-1].distance_to(pp) > 0.7:
			_trail.append(Vector3(pp.x, 0.0, pp.z))
	_hunt(delta)
	if Game.in_sequence:
		return
	if _hint == 0 and _t > 2.5:
		Game.hud.show_thought("...This isn't my room.", 4.0)
		_hint = 1
	elif _hint == 1 and _t > 10.0:
		Game.hud.show_hint("Your notebook is still in your pocket.\nN: read", 7.0)
		_hint = 2
	elif _hint == 2 and _t > 150.0 and not Game.has_flag("maze_hint_written"):
		# Somebody writes in your notebook. You only hear the page.
		Game.set_flag("maze_hint_written")
		Notebook.reveal_on_next_open("maze_hint")
		Sfx.play("page", 0.0)
		_hint = 3


func on_dread(dread: float, stage: int, delta: float) -> void:
	var d := dread / 100.0
	var v := clampf(Settings.visual_intensity, 0.0, 1.0)
	var ppos: Vector3 = Game.player.global_position
	# fluorescent flicker, stronger as the dream destabilises (scaled by visual intensity: photosensitivity)
	# Only the lights near the player cast shadows (36 shadowed lights would be far too heavy).
	var shadows := Settings.quality >= 1
	for l in _lights:
		l.light.shadow_enabled = shadows and l.light.global_position.distance_to(ppos) < 11.0
		var target := 0.0
		if not l.dead:
			target = l.base * (1.0 - 0.3 * d * v)
			if l.light.global_position.distance_to(ppos) < 26.0:
				l.dip -= delta
				if l.dip <= 0.0 and randf() < (0.01 + 0.5 * d * d) * v * delta:
					l.dip = randf_range(0.04, 0.25)
					l.level = randf_range(0.05, 0.6)
				if l.dip > 0.0:
					target *= lerpf(1.0, l.level, v)
		l.light.light_energy = target
	if _hum:
		_hum.volume_db = -18.0 + 8.0 * d * Settings.audio_intensity
	_update_observer(delta, stage, d)


func _on_observer_seen() -> void:
	if _obs_seen_now:
		return
	_obs_seen_now = true
	_sightings += 1
	Game.player.dread.add_dread(observer.spot_dread)
	Game.player.dread.notify_suspicious()
	Game.set_flag("observer_seen_maze")


func _summon(min_cells: int) -> bool:
	if observer == null or Game.player == null:
		return false
	var start := cell_at(Game.player.global_position)
	var candidates: Array[Vector2i] = []
	# he stands at the far end of a straight corridor
	for d in 4:
		var c := start
		for step in range(1, 8):
			if not passable(c.x, c.y, d):
				break
			c = Vector2i(c.x + DX[d], c.y + DZ[d])
			if step >= min_cells:
				candidates.append(c)
	candidates.shuffle()
	for c in candidates:
		if observer.try_appear_at(cell_center(c.x, c.y)):
			_obs_seen_now = false
			_obs_present = 0.0
			return true
	return false


func _update_observer(delta: float, stage: int, d: float) -> void:
	if observer == null:
		return
	if observer.is_present():
		_obs_present += delta
		# once spotted he glitches away by himself; if never spotted, he leaves eventually
		if _obs_present > 18.0 and not observer.observed and not observer.spotted:
			observer.hide_now()
			_obs_cooldown = lerpf(90.0, 30.0, d) * randf_range(0.8, 1.2)
		return
	_obs_cooldown -= delta
	_obs_check += delta
	if _obs_cooldown > 0.0 or _obs_check < 1.0 or stage == Dread.Stage.CALM:
		return
	_obs_check = 0.0
	var chance := 0.04 if stage == Dread.Stage.UNEASY else (0.1 if stage == Dread.Stage.AFRAID else 0.2)
	if randf() < chance:
		_summon(3)


func observer_event(event: String) -> void:
	if event == "closer":
		# breaking the rules brings him sooner, and nearer
		_obs_cooldown = minf(_obs_cooldown, 4.0)
		if observer and not observer.is_present():
			_summon(2)


# ------------------------------------------------------------------ THE BACKROOMS' expedition
# 1 Arrival  2 The yellow maze: landmarks (a park bench, a street sign, the ice cream cart) and three notes
# 3 The maintenance wing  4 The power room: breakers in the order the notes give  5 The distortion:
# walls swap, doorways lead elsewhere  6 The pursuit  7 The exit: the elevator where you arrived.

func _wbox(local_c: Vector3, local_size: Vector3, color: Color, collide := true, surface: Variant = "concrete") -> void:
	var sz := local_size if absf(_wing_xf.basis.x.x) > 0.5 else Vector3(local_size.z, local_size.y, local_size.x)
	box(_wing_xf * local_c, sz, color, collide, 0.0, surface)


## The wing: local X runs away from the maze (out through the maintenance door), Z along the wall.
func _wing(door_center: Vector3, out: Vector3, along: Vector3) -> void:
	var z_axis := out.cross(Vector3.UP)
	_wing_xf = Transform3D(Basis(out, Vector3.UP, z_axis), door_center)
	var grey := Color(0.5, 0.5, 0.49)
	var floor_c := Color(0.36, 0.36, 0.35)
	var H2 := 2.8
	# corridor: x 0..16, z -1.5..1.5
	_wbox(Vector3(8, -0.05, 0), Vector3(16, 0.1, 3.2), floor_c, true, "concrete")
	_wbox(Vector3(8, H2 + 0.05, 0), Vector3(16, 0.1, 3.2), grey.darkened(0.2))
	for side in [-1.0, 1.0]:
		# walls with gaps for the side doors (x 4.4..5.6 on +Z, 8.3..10.3 window on -Z, x 11.4..12.6 on +Z)
		var gaps: Array = [[4.4, 5.6], [11.4, 12.6]] if side > 0 else [[8.3, 10.3]]
		var x := 0.0
		for g in gaps + [[16.0, 16.0]]:
			if g[0] > x:
				_wbox(Vector3((x + g[0]) * 0.5, H2 * 0.5, side * 1.6), Vector3(g[0] - x, H2, 0.2), grey, true, "concrete")
			x = g[1]
	# the two locked doors, and what's behind the window
	for spec in [[5.0, "B-12  STORAGE"], [12.0, "ELECTRICAL"]]:
		var dpos: Vector3 = _wing_xf * Vector3(spec[0], 0, 1.55)
		door(dpos, rad_to_deg(atan2(-z_axis.x, -z_axis.z)), Color(0.4, 0.42, 0.44), 1.0, 2.1, "metal")
		blocker(dpos + Vector3(0, 1.05, 0), Vector3(1.2, 2.1, 1.2))
		label(_wing_xf * Vector3(spec[0], 2.35, 1.48), rad_to_deg(atan2(-z_axis.x, -z_axis.z)), spec[1], 0.07, Color(0.1, 0.1, 0.1), false)
		interactable(_wing_xf * Vector3(spec[0], 1.0, 1.4), Vector3(1.2, 2.0, 1.2), func(): return "Locked door",
			func():
				Sfx.play_at("knock", self, dpos + Vector3(0, 1.2, 0), 2.0, 12.0)
				Game.hud.show_thought("Locked. ...Something on the other side knocked back.", 3.0)
				Game.player.dread.add_fear(5.0, "knock back"))
	# the dark room behind glass (x 8.3..10.3 window; room x 7.5..11, z -1.6..-5)
	_wbox(Vector3(9.25, -0.05, -3.3), Vector3(3.6, 0.1, 3.4), floor_c)
	_wbox(Vector3(9.25, H2 + 0.05, -3.3), Vector3(3.6, 0.1, 3.4), grey.darkened(0.3))
	_wbox(Vector3(7.4, H2 * 0.5, -3.3), Vector3(0.2, H2, 3.4), grey)
	_wbox(Vector3(11.1, H2 * 0.5, -3.3), Vector3(0.2, H2, 3.4), grey)
	_wbox(Vector3(9.25, H2 * 0.5, -5.05), Vector3(3.6, H2, 0.2), grey)
	_wbox(Vector3(9.3, 0.5, -1.6), Vector3(2.0, 1.0, 0.2), grey)
	_wbox(Vector3(9.3, 2.4, -1.6), Vector3(2.0, 0.8, 0.2), grey)
	_glass = solid_box(_wing_xf * Vector3(9.3, 1.5, -1.6), Vector3(0.04, 1.0, 2.0) if absf(z_axis.x) > 0.5 else Vector3(2.0, 1.0, 0.04), Color(0.4, 0.5, 0.5), null, "glass")
	_glass.collision_layer = 1 | 4
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.65, 0.65, 0.18)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05
	gm.metallic = 0.2
	(_glass.get_child(1) as MeshInstance3D).material_override = gm
	omni(_wing_xf * Vector3(9.25, 2.4, -4.0), Color(0.8, 0.12, 0.08), 0.35, 4.0, false)
	_stalker = Stalker.new()
	add_child(_stalker)
	_stalker.global_position = _wing_xf * Vector3(9.25, 0, -4.2)
	_stalker.rotation.y = atan2(z_axis.x, z_axis.z) + PI
	trigger(_wing_xf * Vector3(8.6, 1.2, 0), Vector3(1.4, 2.4, 3.0), func():
		Game.set_flag("maze_saw_it")
		scare("braam", 8.0, -2.0)
		Game.hud.show_thought("There's someone in there. Standing. Not moving. Don't look at it. Keep going.", 4.0))
	trigger(_wing_xf * Vector3(1.5, 1.2, 0), Vector3(2.0, 2.4, 3.0), func():
		Game.set_flag("maze_found_wing")
		Game.hud.show_thought("Concrete. Pipes. A real building, behind the yellow. Somebody maintains this place.", 4.0))
	# pipes along the ceiling, buzzing tubes
	for k in 2:
		_wbox(Vector3(8, 2.55 - k * 0.18, -1.2 + k * 0.25), Vector3(16, 0.12, 0.12), Color(0.3, 0.32, 0.3), false, "metal")
	for x in [3.0, 8.0, 13.0]:
		var tube := part("box", _wing_xf * Vector3(x, H2 - 0.04, 0.5), Vector3(0.12, 0.04, 1.2) if absf(z_axis.x) > 0.5 else Vector3(1.2, 0.04, 0.12), Color(0.9, 0.95, 1.0), null, Vector3.ZERO, 2.0)
		var l := omni(_wing_xf * Vector3(x, H2 - 0.3, 0.5), Color(0.85, 0.92, 1.0), 0.9, 6.0, false)
		_wing_lights.append([l, tube])
	ambient("buzz", _wing_xf * Vector3(8, 2.4, 0), true, -8.0, 14.0)
	# the power room: x 16..22, z -3..3
	_wbox(Vector3(19, -0.05, 0), Vector3(6, 0.1, 6.2), floor_c)
	_wbox(Vector3(19, 3.05, 0), Vector3(6, 0.1, 6.2), grey.darkened(0.25))
	_wbox(Vector3(19, 1.5, -3.1 * _side), Vector3(6, 3, 0.2), grey)
	_wbox(Vector3(17.8, 1.5, 3.1 * _side), Vector3(3.6, 3, 0.2), grey)
	_wbox(Vector3(21.4, 1.5, 3.1 * _side), Vector3(1.2, 3, 0.2), grey)
	_wbox(Vector3(20.2, 2.75, 3.1 * _side), Vector3(1.2, 0.5, 0.2), grey)
	_escape_passage(grey, floor_c, z_axis)
	_wbox(Vector3(22.1, 1.5, 0), Vector3(0.2, 3, 6.2), grey)
	_wbox(Vector3(16, 1.5, 2.3), Vector3(0.2, 3, 1.4), grey)
	_wbox(Vector3(16, 1.5, -2.3), Vector3(0.2, 3, 1.4), grey)
	_wbox(Vector3(16, 2.9, 0), Vector3(0.2, 0.2, 3.2), grey)
	var pl := omni(_wing_xf * Vector3(19, 2.6, 0), Color(1.0, 0.9, 0.7), 0.9, 7.0, true)
	_wing_lights.append([pl, null])
	# breaker panel on the far wall
	_wbox(Vector3(21.9, 1.5, 0), Vector3(0.16, 1.4, 2.4), Color(0.25, 0.28, 0.26), true, "metal")
	label(_wing_xf * Vector3(21.8, 2.35, 0), rad_to_deg(atan2(-out.x, -out.z)), "EXIT SYSTEM  -  MAIN SUPPLY", 0.06, Color(0.9, 0.85, 0.3), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 404
	_order = ["A", "B", "C", "D"]
	for i in range(3, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = _order[i]
		_order[i] = _order[j]
		_order[j] = tmp
	for k in 4:
		var letter: String = ["A", "B", "C", "D"][k]
		var zc := -0.75 + k * 0.5
		var g := group(_wing_xf * Vector3(21.78, 1.5, zc))
		part("box", Vector3(0, 0.12, 0), Vector3(0.05, 0.25, 0.05), Color(0.1, 0.1, 0.1), g)
		g.rotation_degrees.z = 0.0
		label(_wing_xf * Vector3(21.78, 1.15, zc), rad_to_deg(atan2(-out.x, -out.z)), letter, 0.08, Color(0.95, 0.95, 0.9), false)
		var b := {"group": g, "letter": letter, "up": false}
		_breakers.append(b)
		interactable(_wing_xf * Vector3(21.7, 1.5, zc), Vector3(0.3, 0.5, 0.4), func(): return "Breaker " + letter + (" (up)" if b.up else ""),
			func(): _flip(b), func(): return not Game.has_flag("maze_power"))
	_main_switch = group(_wing_xf * Vector3(21.78, 1.1, 0.95))
	part("box", Vector3(0, 0.15, 0), Vector3(0.07, 0.3, 0.07), Color(0.6, 0.08, 0.05), _main_switch)
	interactable(_wing_xf * Vector3(21.7, 1.2, 0.95), Vector3(0.3, 0.5, 0.4),
		func(): return "MAIN SUPPLY" if _flipped.size() == 4 else "Main supply (breakers off)",
		func():
			if _flipped.size() < 4:
				Game.hud.show_thought("Nothing. The breakers have to be up first.", 2.5)
			else:
				_power_on(),
		func(): return not Game.has_flag("maze_power"))
	# a tape recorder (optional)
	_wbox(Vector3(17.2, 0.45, -2.5), Vector3(0.6, 0.9, 0.8), Color(0.35, 0.3, 0.25), true, "wood")
	box(_wing_xf * Vector3(17.2, 0.95, -2.5), Vector3(0.3, 0.1, 0.2), Color(0.1, 0.1, 0.1), false, 0.0, "metal")
	interactable(_wing_xf * Vector3(17.2, 1.0, -2.5), Vector3(0.6, 0.4, 0.6), func(): return "Play the tape", func(): _tape())
	trigger(_wing_xf * Vector3(17.0, 1.2, 0), Vector3(2.0, 2.4, 4.0), func():
		Game.set_flag("maze_power_room")
		Game.hud.show_thought("Four breakers. A main switch. EXIT SYSTEM. There's an exit system.", 4.0))

	# the elevator where you arrived: dead until the power is back
	var lift := cell_center(0, 0) + Vector3(-0.5 * CELL + THICK * 0.5 + 0.03, 0, 0.0)
	var face_yaw := 90.0
	for k in 2:
		var dg := group(lift + Vector3(0, 0, -0.42 + k * 0.84), face_yaw)
		part("box", Vector3(0, 1.1, 0), Vector3(0.84, 2.2, 0.05), Color(0.6, 0.6, 0.62), dg, Vector3.ZERO, 0.0, "metal")
		_lift_doors.append(dg)
	box(lift + Vector3(-0.05, 1.15, 0), Vector3(0.08, 2.4, 1.9), Color(0.35, 0.36, 0.38), false, 0.0, "metal")
	_lift_sign = part("box", lift + Vector3(0.05, 2.55, 0), Vector3(0.04, 0.16, 0.5), Color(0.15, 0.04, 0.03), null, Vector3.ZERO, 0.4)
	label(lift + Vector3(0.08, 2.55, 0), 90, "LIFT", 0.08, Color(1.0, 0.6, 0.5))
	_lift_light = omni(lift + Vector3(0.4, 2.3, 0), Color(1.0, 0.3, 0.2), 0.0, 4.0, false)
	interactable(lift + Vector3(0.3, 1.2, 0.9), Vector3(0.4, 0.5, 0.3), func(): return "Call the lift",
		func():
			if not Game.has_flag("maze_power"):
				Sfx.play("switch", -10.0)
				Game.hud.show_thought("Dead. No power. ...It's been here the whole time.", 3.0)
			else:
				_lift_arrives())
	box(lift + Vector3(0.05, 1.2, 0.9), Vector3(0.04, 0.25, 0.14), Color(0.2, 0.2, 0.2), false, 0.0, "metal")


## Local size -> world size of an axis-aligned box in the wing's frame.
func _wsize(local: Vector3) -> Vector3:
	var a := (_wing_xf.basis * Vector3(local.x, 0, 0)).abs() + (_wing_xf.basis * Vector3(0, 0, local.z)).abs()
	return Vector3(a.x, local.y, a.z)


## Behind a shutter in the power room's side wall: a narrow service passage back alongside the corridor, into
## the maze one cell along. It opens when the power comes on - so when the glass breaks there is somewhere to run.
func _escape_passage(grey: Color, floor_c: Color, z_axis: Vector3) -> void:
	var sd := _side
	var H2 := 2.8
	_shutter = solid_box(_wing_xf * Vector3(20.2, 1.25, 3.1 * sd), _wsize(Vector3(1.2, 2.5, 0.14)), Color(0.32, 0.34, 0.33), null, "metal")
	var face := _wing_xf.basis * Vector3(0, 0, -0.08 * sd)      # the power-room side of the shutter
	for k in 6:   # slats, riding up with it
		part("box", Vector3(0, 0.3 + k * 0.4 - 1.25, 0) + face, _wsize(Vector3(1.16, 0.03, 0.02)), Color(0.22, 0.23, 0.22), _shutter, Vector3.ZERO, 0.0, "metal")
	label(_wing_xf * Vector3(20.2, 2.7, 3.1 * sd - 0.12 * sd), rad_to_deg(atan2(-z_axis.x * sd, -z_axis.z * sd)), "SERVICE", 0.06, Color(0.9, 0.85, 0.3), false)
	# the stub out of the power room, and the passage back
	_wbox(Vector3(20.2, -0.05, 4.35 * sd), Vector3(1.4, 0.1, 2.5), floor_c, true, "concrete")
	_wbox(Vector3(20.2, H2 + 0.05, 4.35 * sd), Vector3(1.4, 0.1, 2.5), grey.darkened(0.3))
	for x in [19.4, 21.0]:
		_wbox(Vector3(x, H2 * 0.5, 4.3 * sd), Vector3(0.2, H2, 2.4), grey)
	_wbox(Vector3(10.45, -0.05, 6.5 * sd), Vector3(21.1, 0.1, 2.2), floor_c, true, "concrete")
	_wbox(Vector3(10.45, H2 + 0.05, 6.5 * sd), Vector3(21.1, 0.1, 2.2), grey.darkened(0.3))
	_wbox(Vector3(9.75, H2 * 0.5, 5.5 * sd), Vector3(19.3, H2, 0.2), grey)
	_wbox(Vector3(10.5, H2 * 0.5, 7.5 * sd), Vector3(21.0, H2, 0.2), grey)
	_wbox(Vector3(21.05, H2 * 0.5, 6.5 * sd), Vector3(0.2, H2, 2.2), grey)
	for x in [4.0, 12.0, 19.0]:
		part("box", _wing_xf * Vector3(x, H2 - 0.05, 6.5 * sd), Vector3(0.2, 0.08, 0.2), Color(1.0, 0.2, 0.15), null, Vector3.ZERO, 3.0)
		omni(_wing_xf * Vector3(x, H2 - 0.3, 6.5 * sd), Color(1.0, 0.18, 0.12), 0.0, 6.0, false).name = "EscapeLight"
	# where it meets the maze: the boundary wall of the next cell, with a steel door in it
	var along_z := _exit_dir == 0
	var edge := _wing_xf * Vector3(0, 0, 5.0 * sd)
	var o := 1.5 * sd
	var L := CELL - PILLAR + 0.04
	var gap0 := minf(o - 0.65, o + 0.65)
	var gap1 := maxf(o - 0.65, o + 0.65)
	for seg in [[-L * 0.5, gap0], [gap1, L * 0.5]]:
		if seg[1] - seg[0] > 0.05:
			_wall(edge + z_axis * ((seg[0] + seg[1]) * 0.5), along_z, seg[1] - seg[0], WALL_A)
	var lintel_h := WALL_H - 2.2
	box(edge + z_axis * o + Vector3(0, 2.2 + lintel_h * 0.5, 0), _wsize(Vector3(THICK, lintel_h, 1.3)), WALL_A)
	var inward := -_wing_xf.basis.x
	var dpos := edge + z_axis * o - inward * 0.02
	_escape_door = door(dpos, rad_to_deg(atan2(inward.x, inward.z)), Color(0.42, 0.44, 0.46), 1.08, 2.14, "metal")
	_escape_block = solid_box(dpos + Vector3(0, 1.07, 0), _wsize(Vector3(0.2, 2.14, 1.1)), Color(0, 0, 0, 0))
	_escape_block.get_child(1).visible = false
	interactable(dpos + Vector3(0, 1.1, 0) + inward * 0.2, _wsize(Vector3(0.3, 2.1, 1.16)), func(): return "Locked door",
		func(): Game.hud.show_thought("Locked. It doesn't even have a handle on this side.", 2.5), func(): return _escape_block != null and is_instance_valid(_escape_block))


func _open_escape() -> void:
	Sfx.play_at("grind", self, _shutter.global_position, 4.0, 30.0)
	create_tween().tween_property(_shutter, "position:y", _shutter.position.y + 2.45, 1.6).set_trans(Tween.TRANS_SINE)
	open_door(_escape_door, 100.0, 1.0)
	_escape_block.queue_free()
	for n in find_children("EscapeLight", "OmniLight3D", true, false):
		(n as OmniLight3D).light_energy = 1.1


func _open_maint() -> void:
	_maint_block.visible = false
	_maint_block.get_child(0).disabled = true
	Sfx.play("door_creak", -2.0, 0.9)
	open_door(_maint_door, 100.0, 1.4)     # into the wing, on its hinge


func _flip(b: Dictionary) -> void:
	if b.up:
		return
	b.up = true
	(b.group as Node3D).rotation_degrees.z = 160.0
	Sfx.play("switch", -4.0)
	_flipped.append(b.letter)
	var i := _flipped.size() - 1
	if _flipped[i] != _order[i]:
		# wrong: everything trips. bang. the lights die for a moment.
		await get_tree().create_timer(0.35, false).timeout
		Sfx.play("hit", -6.0, 1.3)
		Sfx.play("glitch", -6.0)
		for x in _breakers:
			x.up = false
			(x.group as Node3D).rotation_degrees.z = 0.0
		_flipped.clear()
		for wl in _wing_lights:
			wl[0].visible = false
		Game.player.dread.add_fear(6.0, "breakers tripped")
		Game.hud.show_thought("They all tripped. Wrong order. ...The notes. The notes had an order.", 3.5)
		await get_tree().create_timer(1.6, false).timeout
		for wl in _wing_lights:
			wl[0].visible = true
	elif _flipped.size() == 4:
		Game.hud.show_thought("All four. Now the main supply.", 2.5)


func _power_on() -> void:
	Game.set_flag("maze_power")
	_main_switch.rotation_degrees.z = 160.0
	Sfx.play("switch", 0.0, 0.7)
	Sfx.stinger("braam", 0.0)
	Game.player.jolt(Vector3(-4, 2, 0))
	# the lights go red. the walls shift. the lift lights up. and the glass breaks.
	for l in _lights:
		l.light.light_color = Color(1.0, 0.35, 0.25)
		l.base = 1.2
	for wl in _wing_lights:
		wl[0].light_color = Color(1.0, 0.3, 0.2)
	for w in _dynamic:
		_set_dynamic(w, not w.open)
	_lift_light.light_energy = 1.5
	_lift_sign.material_override = Shapes.material(Color(1.0, 0.25, 0.15), 0.4, 3.0)
	Game.hud.show_thought("Power. ...The lift. Back where I started. And the shutter - it's opening.", 4.0)
	_open_escape()
	_trail.clear()
	_portals()
	await get_tree().create_timer(3.0, false).timeout
	if not is_inside_tree():
		return
	_glass.queue_free()
	Sfx.play_at("hit", self, _stalker.global_position + Vector3(0, 1.5, 0), 6.0, 40.0)
	Sfx.stinger("screech", -2.0)
	Game.player.dread.add_fear(15.0, "it's out")
	Game.hud.show_thought("RUN.", 2.0)
	_hunting = true
	Game.set_flag("maze_hunted")


## After the power comes on, two doorways no longer lead where they did.
func _portals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 808
	for k in 2:
		var a := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		var b := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		var from := cell_center(a.x, a.y)
		var to := cell_center(b.x, b.y)
		trigger(from + Vector3(0, 1.2, 0), Vector3(1.5, 2.4, 1.5), func():
			var off: Vector3 = Game.player.global_position - from
			Game.player.global_position = to + off
			Sfx.play("glitch", -14.0)
			Game.player.dread.add_fear(3.0, "the corridor moved"), false)


func _tape() -> void:
	Sfx.play("static", -10.0)
	var lines := ["\"...day nine. The walls moved again while I was asleep.\"",
		"\"I found the breakers. It only lets the lift run when it's awake.\"",
		"\"When the lights go red, don't look behind you. Just walk. Then run.\""]
	for i in lines.size():
		Game.hud.show_thought(lines[i], 3.8)
		await get_tree().create_timer(4.0, false).timeout
		if not is_inside_tree():
			return
	Game.set_flag("maze_tape")


func _lift_arrives() -> void:
	if Game.in_sequence:
		return
	Sfx.play("ding", 0.0)
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		create_tween().tween_property(_lift_doors[k], "position:z", _lift_doors[k].position.z + side * 0.8, 1.6).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.2, false).timeout
	Sfx.play("splash_big", 0.0, 0.8)
	Game.hud.show_thought("That's not a lift. That's... water. Where the lift should be.", 3.0)
	await get_tree().create_timer(1.5, false).timeout
	Game.on_maze_exit()


func _hunt(delta: float) -> void:
	if not _hunting or _stalker == null or Game.in_sequence:
		return
	var p: Vector3 = Game.player.global_position
	var me := _stalker.global_position
	# both in the yellow rooms: the maze's own passages. Otherwise (the wing, the service passage): your footsteps.
	var in_wing := (_wing_xf.affine_inverse() * me).x > 0.3
	var both_in := _in_grid(p) and _in_grid(me)
	var target := p
	if both_in:
		_trail.clear()
		_path_t -= delta
		if _path_t <= 0.0:
			_path_t = 0.4
			_path = _route(cell_at(me), cell_at(p))
		if not _path.is_empty():
			target = _path[0]
			if Vector2(me.x - target.x, me.z - target.z).length() < 0.4:
				_path.pop_front()
	elif not _trail.is_empty():
		target = _trail[0]
		if Vector2(me.x - target.x, me.z - target.z).length() < 0.5:
			_trail.pop_front()
	var dist := me.distance_to(p)
	var spd := 3.35 if dist > 4.0 else 3.7
	if _chase_on:
		# it never falls far behind, and right behind you it's just short of your sprint: any hesitation and it has you
		spd = 5.0 if dist > 12.0 else (4.0 if dist > 5.0 else 3.3)
	if in_wing and (_wing_xf.affine_inverse() * me).z < -1.2:
		target = _wing_xf * Vector3(9.25, 0, 0)
	_stalker.move_to(target if dist > 1.6 else p, spd, delta)
	if _trail.size() > 400:
		_trail = _trail.slice(-400)
	if dist < 1.1:
		_hunting = false
		Game.entity_death("stalker", _stalker)


# ------------------------------------------------------------------ the chase

static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	return "%d,%d|%d,%d" % [lo.x, lo.y, hi.x, hi.y]


## The cells of the shortest walk from one cell to another (both included); dynamic walls count as open.
## Cells in `avoid` are only walked through if there's no other way.
func _route_cells(from: Vector2i, to: Vector2i, avoid := {}) -> Array[Vector2i]:
	var cost := {from: 0}
	var prev := {from: from}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if cost[open[k]] < cost[open[bi]]:
				bi = k
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		if c == to:
			break
		for d in 4:
			var t := _get_edge(c.x, c.y, d)
			if not (t == Edge.OPEN or t == Edge.EXTRA or t == Edge.DYNAMIC):
				continue
			var n := Vector2i(c.x + DX[d], c.y + DZ[d])
			if not _in(n.x, n.y):
				continue
			var nc: int = cost[c] + (1000 if avoid.has(n) and n != to else 1)
			if not cost.has(n) or nc < cost[n]:
				if not cost.has(n):
					open.append(n)
				cost[n] = nc
				prev[n] = c
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var c: Vector2i = to
	while c != from:
		out.push_front(c)
		c = prev[c]
	out.push_front(from)
	return out


func _begin_chase() -> void:
	_chase_on = true
	_chase_t = 0.0
	_chase_path = _route_cells(cell_at(Game.player.global_position), Vector2i(0, 0), _prop_cells)
	if _chase_path.is_empty():
		_chase_path = _route_cells(cell_at(Game.player.global_position), Vector2i(0, 0))
	if _chase_path.is_empty():
		_chase_on = false
		return
	# the route is open: any shifting wall on it stays open
	for i in _chase_path.size() - 1:
		var mid := (cell_center(_chase_path[i].x, _chase_path[i].y) + cell_center(_chase_path[i + 1].x, _chase_path[i + 1].y)) * 0.5
		for w in _dynamic:
			if Vector2(w.center.x - mid.x, w.center.z - mid.z).length() < 0.01 and not w.open:
				_set_dynamic(w, true)
	# every other light dies - the panels go dark - and red strobes mark the way
	for l in _lights:
		l.dead = true
		l.panel.material_override = Shapes.material(Color(0.2, 0.19, 0.17))
	for i in _chase_path.size():
		var c := _chase_path[i]
		var l := omni(cell_center(c.x, c.y) + Vector3(0, WALL_H - 0.25, 0), Color(1.0, 0.1, 0.06), 0.0, 4.6, false)
		_chase_lights.append(l)
		part("box", cell_center(c.x, c.y) + Vector3(0, WALL_H - 0.03, 0), Vector3(0.5, 0.05, 0.5), Color(1.0, 0.15, 0.1), null, Vector3.ZERO, 6.0)
	if _env:
		var tw := create_tween().set_parallel()
		tw.tween_property(_env, "ambient_light_color", Color(0.5, 0.06, 0.04), 0.6)
		tw.tween_property(_env, "ambient_light_energy", 0.025, 0.6)
		tw.tween_property(_env, "fog_light_color", Color(0.3, 0.02, 0.01), 0.6)
		tw.tween_property(_env, "fog_density", 0.022, 0.6)
		if _env.volumetric_fog_enabled:
			tw.tween_property(_env, "volumetric_fog_albedo", Color(1.0, 0.3, 0.25), 0.6)
	Sfx.stinger("braam", 2.0)
	Sfx.play("metal_screech", -2.0, 0.6)
	Game.player.jolt(Vector3(-3, 2, 0))
	Game.hud.show_thought("The walls - they're closing! Follow the red. RUN!", 3.0)
	for i in mini(3, _chase_path.size()):
		_seal_queue.append([0.15 + i * 0.18, i])


## Slam shut every opening off the route around path cell i.
func _seal_around(i: int) -> void:
	var c := _chase_path[i]
	var prev: Vector2i = _chase_path[i - 1] if i > 0 else Vector2i(-99, -99)
	var nxt: Vector2i = _chase_path[i + 1] if i + 1 < _chase_path.size() else Vector2i(-99, -99)
	var k := 0
	for d in 4:
		var n := Vector2i(c.x + DX[d], c.y + DZ[d])
		if n == prev or n == nxt or not _in(n.x, n.y) or not passable(c.x, c.y, d):
			continue
		_slam(c, n, d, k * 0.07)
		k += 1


func _slam(a: Vector2i, b: Vector2i, d: int, delay: float) -> void:
	_sealed[_edge_key(a, b)] = true
	var center := (cell_center(a.x, a.y) + cell_center(b.x, b.y)) * 0.5
	var length := CELL - PILLAR + 0.04
	var size := Vector3(THICK, WALL_H, length) if d <= 1 else Vector3(length, WALL_H, THICK)
	var body := solid_box(center + Vector3(0, WALL_H * 1.5 + 0.1, 0), size, WALL_B, null, "wallpaper")
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(body, "position:y", WALL_H * 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Sfx.play_at("thud", self, center + Vector3(0, 1.0, 0), 3.0, 26.0)
		var pl: Player = Game.player
		if pl and pl.global_position.distance_to(center) < 7.0:
			pl.jolt(Vector3(randf_range(-2.5, -1.0), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))))


func _update_chase(delta: float) -> void:
	_chase_t += delta
	var pl: Player = Game.player
	var pc := cell_at(pl.global_position)
	# how far along the route you are (the nearest route cell a little ahead of where you were)
	for j in range(_chase_idx, mini(_chase_idx + 4, _chase_path.size())):
		if _chase_path[j] == pc:
			if j > _chase_idx:
				for k in range(_chase_idx + 3, mini(j + 3, _chase_path.size())):
					_seal_queue.append([_chase_t + 0.05 + (k - _chase_idx - 3) * 0.2, k])
			_chase_idx = maxi(_chase_idx, j)
			break
	for q in _seal_queue.duplicate():
		if _chase_t >= q[0]:
			_seal_queue.erase(q)
			_seal_around(q[1])
	# red strobes along the way (gentler with lower visual intensity)
	var v := clampf(Settings.visual_intensity, 0.0, 1.0)
	for i in _chase_lights.size():
		var on := 1.0 if sin(_chase_t * 11.0 - i * 0.9) > -0.2 else 1.0 - 0.85 * v
		_chase_lights[i].light_energy = (2.4 if i >= _chase_idx else 0.35) * on
	for l in _lights:
		l.light.light_energy = 0.0
	# it, behind you
	var dist := _stalker.global_position.distance_to(pl.global_position)
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = clampf(dist / 14.0, 0.28, 0.8)
		Sfx.play("heartbeat", clampf(4.0 - dist * 0.5, -14.0, 2.0), 1.15)
	_shriek_t -= delta
	if dist < 6.0 and _shriek_t <= 0.0:
		_shriek_t = randf_range(1.8, 3.5)
		Sfx.play_at("screech", self, _stalker.global_position + Vector3(0, 2, 0), -2.0, 30.0)
		Game.hud.set_post(0.8, 0.5, 1.0, 1.4)
	# terror, but never the kind that ends it for you: the chase is what decides
	if pl.dread.fear < 88.0:
		pl.dread.add_fear(2.5 * delta, "chased")
	# the lift: a wall slams down behind you, between you and it
	if pc == Vector2i(0, 0) and _chase_path.size() > 1:
		_chase_on = false
		_hunting = false
		var before := _chase_path[_chase_path.size() - 2]
		for d in 4:
			if Vector2i(DX[d], DZ[d]) == before:
				_slam(Vector2i(0, 0), before, d, 0.0)
		Sfx.stinger("hit", 2.0)
		_stalker.speed = 0.0
		_lift_arrives()


## Inside the maze proper (not the wing or the service passage)?
func _in_grid(p: Vector3) -> bool:
	return p.x > -0.5 * CELL and p.z > -0.5 * CELL and p.x < (W - 0.5) * CELL - THICK * 0.5 and p.z < (H - 0.5) * CELL - THICK * 0.5


## Shortest walk through the maze's current openings (BFS over cells), as world points.
func _route(from: Vector2i, to: Vector2i) -> Array:
	if not _in(from.x, from.y) or not _in(to.x, to.y):
		return []
	var prev := {from: from}
	var queue := [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == to:
			break
		for d in 4:
			if not passable(c.x, c.y, d):
				continue
			var n := Vector2i(c.x + DX[d], c.y + DZ[d])
			if _in(n.x, n.y) and not prev.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return []
	var out := []
	var c: Vector2i = to
	while c != from:
		out.push_front(cell_center(c.x, c.y))
		c = prev[c]
	return out


func _expedition() -> void:
	# the summer leaks in: things from the city, where they don't belong
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 313
	var used := {Vector2i(0, 0): true, _exit_cell: true}
	var spots := []
	while spots.size() < 6:
		var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		if not used.has(c):
			used[c] = true
			spots.append(c)
	_prop_cells[spots[0]] = true    # the bench and the cart stand in the middle of their rooms
	_prop_cells[spots[2]] = true
	var bench_c: Vector3 = cell_center(spots[0].x, spots[0].y)
	if not prop("bench", bench_c, 30.0):
		box(bench_c + Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.5), Color(0.5, 0.32, 0.18))
	interactable(bench_c + Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 1.0), func(): return "Park bench",
		func(): Game.hud.show_thought("Mr. Halvorsen's bench. From the park. There are still breadcrumbs on it.", 4.0))
	var sign_c: Vector3 = cell_center(spots[1].x, spots[1].y) + Vector3(1.2, 0, 1.2)
	shape_at("cylinder", sign_c + Vector3(0, 1.4, 0), Vector3(0.06, 2.8, 0.06), Color(0.3, 0.32, 0.3), true, Vector3.ZERO, "metal")
	box(sign_c + Vector3(0.45, 2.6, 0), Vector3(0.9, 0.22, 0.03), Color(0.1, 0.35, 0.18), false, 0.0, "metal")
	label(sign_c + Vector3(0.45, 2.6, 0.02), 0, "PARK AVE", 0.09, Color(0.95, 0.95, 0.9), false)
	var cart: Vector3 = cell_center(spots[2].x, spots[2].y)
	box(cart + Vector3(0, 0.7, 0), Vector3(2.4, 0.9, 1.1), Color(0.95, 0.92, 0.85), true, 20.0)
	box(cart + Vector3(0, 1.08, 0), Vector3(2.44, 0.12, 1.14), Color(0.95, 0.5, 0.6), false, 20.0)
	interactable(cart + Vector3(0, 1.0, 0), Vector3(2.6, 1.2, 1.4), func(): return "Ice cream cart",
		func():
			Game.hud.show_thought("Mina's cart. Every tub is melted. Long ago. It smells like the summer, gone off.", 4.0)
			Game.player.dread.add_fear(3.0, "melted"))
	# three notes, each with a piece of the breaker order
	var texts := ["\"%s goes first. ALWAYS first.\"" % _order[0],
		"\"%s then %s. Never the other way round.\"" % [_order[1], _order[2]],
		"\"%s last. Or it hears you.\"" % _order[3]]
	for k in 3:
		var nc: Vector3 = cell_center(spots[3 + k].x, spots[3 + k].y) + Vector3(1.0, 0, -1.2)
		box(nc + Vector3(0, 0.73, 0), Vector3(1.2, 0.04, 0.6), Color(0.55, 0.5, 0.42), true, 0.0, "wood")
		box(nc + Vector3(0, 0.36, 0), Vector3(1.1, 0.72, 0.5), Color(0.45, 0.4, 0.33), false, 0.0, "wood")
		var paper := part("box", nc + Vector3(0.1, 0.755, 0.05), Vector3(0.21, 0.004, 0.29), Color(0.92, 0.9, 0.82), null, Vector3(0, 15, 0))
		var t: String = texts[k]
		interactable(nc + Vector3(0, 0.85, 0), Vector3(1.0, 0.5, 0.6), func(): return "Read the note",
			func():
				Game.hud.show_thought("Scrawled in pencil, pressed hard: " + t, 5.0)
				if not paper.has_meta("read"):
					paper.set_meta("read", true)
					Game.counters["notes"] = int(Game.counters.get("notes", 0)) + 1
					if Game.counters["notes"] >= 3:
						Game.set_flag("maze_notes"))
