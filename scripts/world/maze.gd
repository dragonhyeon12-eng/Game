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

const W := 16
const H := 16
const CELL := 6.5
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
var _no_hazard := {}              # rooms with something in a corner (the note desks): no debris dropped in them
var _prop_cells := {}             # cells with something big in the middle (the cart, the bench): the chase route goes round them
var _seal_queue: Array = []       # route indices whose rooms close next (one per beat)
var _queued_to := 0
var _last_beat := -1
var _decoys: Array = []           # false trails: {at: route index, cells: [...], warned}
var _decoy_lights: Array = []     # [light, route index of the trail's mouth]
var _hazards: Array = []          # {kind: debris/pit/beam, idx, c, along, across, side, built}
var _hinted := {}
var _sparks: Array = []           # [light, time to next spark] on the dead exit signs
var _rasp: Node
var _gate: Node3D
var _bars_spot := Vector3.ZERO
var _at_bars := false
var _rattle_t := 0.0
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
	_way_in()
	_stains()
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
			if r < 0.3:                      # (open-plan: most of the walls a maze would have aren't there)
				arr[i] = Edge.EXTRA
			elif r < 0.42:
				arr[i] = Edge.DYNAMIC
		set(arr_name, arr)

	# open-plan halls: big empty rooms of carpet and light (3x3 and 2x2)
	for r in 7:
		var size := 3 if r % 2 == 0 else 2
		var rx := rng.randi_range(1, W - size - 1)
		var rz := rng.randi_range(1, H - size - 1)
		for i in size:
			for j in size:
				if i < size - 1:
					if _get_edge(rx + i, rz + j, 0) != Edge.OPEN:
						_set_edge(rx + i, rz + j, 0, Edge.EXTRA)
				if j < size - 1:
					if _get_edge(rx + i, rz + j, 2) != Edge.OPEN:
						_set_edge(rx + i, rz + j, 2, Edge.EXTRA)

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
		if x != ENTRY_CELL.x:      # (the way in: see _entry)
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
		# in a corner of the room, never across the middle where you'd run through it (and no debris dropped in here)
		_no_hazard[c] = true
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
	var cp: Dictionary = Game.counters.get("chase", {})
	if Game.has_flag("maze_chase") and not cp.is_empty():
		return Transform3D(Basis(Vector3.UP, float(cp.yaw)), Vector3(float(cp.x), 0.05, float(cp.z)))
	return Transform3D(Basis(Vector3.UP, PI * 0.5), START)      # on the office carpet, facing the blinds


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
	if from_save and Game.has_flag("maze_chase") and not Game.has_flag("maze_escaped"):
		_restore_chase()


## Back from the chase checkpoint: the maze as it was when the chase began - power on, the wing open,
## the stalker loose and on your trail - and you, where you came back into the yellow rooms.
func _restore_chase() -> void:
	var cp: Dictionary = Game.counters.get("chase", {})
	if cp.is_empty():
		return
	_hint = 3
	_seal_entry()
	_maint_block.visible = false
	_maint_block.get_child(0).disabled = true
	open_door(_maint_door, 100.0, 0.01)
	_main_switch.rotation_degrees.z = 160.0
	for b in _breakers:
		_set_breaker(b, true)
	for l in _lights:
		l.light.light_color = Color(1.0, 0.35, 0.25)
		l.base = 1.2
	for wl in _wing_lights:
		wl[0].light_color = Color(1.0, 0.3, 0.2)
	for w in _dynamic:
		_set_dynamic(w, not w.open)
	_lift_light.light_energy = 1.5
	_lift_sign.material_override = Shapes.material(Color(1.0, 0.25, 0.15), 0.4, 3.0)
	_open_escape()
	_portals()
	if is_instance_valid(_glass):
		_glass.queue_free()
	_stalker.global_position = Vector3(float(cp.sx), 0, float(cp.sz))
	_trail.clear()
	for t in cp.get("trail", []):
		_trail.append(Vector3(float(t[0]), 0.0, float(t[1])))
	_hunting = true
	_stalker.scramble = true
	Game.hud.show_thought("Again. It's right behind me. RUN.", 2.5)


func _process(delta: float) -> void:
	_t += delta
	_update_way_in(delta)
	if Game.has_flag("maze_power") and not _way_on and Game.player and _in_grid(Game.player.global_position) and not Game.in_sequence:
		_way_back()
	if _way_on:
		_update_way_back(delta)
	if _watching and _stalker and Game.player:
		var to: Vector3 = Game.player.global_position - _stalker.global_position
		_stalker.rotation.y = lerp_angle(_stalker.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 2.0))
	if _chase_on:
		_update_chase(delta)
	elif _at_bars:
		_update_bars(delta)
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
	var v := clampf(Settings.visual(), 0.0, 1.0)
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
		_hum.volume_db = _hum_base + 8.0 * d * Settings.audio_intensity
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
	_stalker.planted.connect(_on_stalker_planted)
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
		var lever := prop("breaker", Vector3(0, 0.0, 0), rad_to_deg(atan2(-out.x, -out.z)), 0.8, g)
		if lever == null:
			part("box", Vector3(0, 0.12, 0), Vector3(0.05, 0.25, 0.05), Color(0.1, 0.1, 0.1), g)
		var pivot: Node3D = null
		if lever:
			# only the lever moves: hang it on a hinge at its pivot block (the box stays on the wall)
			for mi in lever.find_children("Lever*", "MeshInstance3D", true, false):
				pivot = Node3D.new()
				pivot.position = Vector3(0.115, 0, 0.02)
				lever.add_child(pivot)
				mi.get_parent().remove_child(mi)
				mi.transform = Transform3D.IDENTITY
				pivot.add_child(mi)
				break
		label(_wing_xf * Vector3(21.78, 1.15, zc), rad_to_deg(atan2(-out.x, -out.z)), letter, 0.08, Color(0.95, 0.95, 0.9), false)
		var b := {"group": g, "lever": pivot, "letter": letter, "up": false}
		_breakers.append(b)
		_set_breaker(b, false)
		interactable(_wing_xf * Vector3(21.7, 1.5, zc), Vector3(0.3, 0.5, 0.4), func(): return "Breaker " + letter + (" (up)" if b.up else ""),
			func(): _flip(b), func(): return not Game.has_flag("maze_power"))
	_main_switch = group(_wing_xf * Vector3(21.78, 1.1, 0.95))
	part("box", Vector3(0, 0.15, 0), Vector3(0.07, 0.3, 0.07), Color(0.6, 0.08, 0.05), _main_switch)
	interactable(_wing_xf * Vector3(21.7, 1.2, 0.95), Vector3(0.3, 0.5, 0.4),
		func(): return "MAIN SUPPLY",
		func():
			for b in _breakers:
				if not b.up:
					b.up = true
					_set_breaker(b, true)
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
	var edge := _wing_xf * Vector3(0, 0, CELL * sd)          # (the next cell's centre, on the boundary)
	var o := (6.5 - CELL) * sd                               # (the door lines up with the passage, at 6.5 along)
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
	_set_breaker(b, true)
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
			_set_breaker(x, false)
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
	_seal_entry()
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
	Game.hud.show_thought("Power. ...The lift. Back the way I came. And the shutter - it's opening.", 4.0)
	_open_escape()
	_trail.clear()
	_portals()
	await get_tree().create_timer(3.0, false).timeout
	if not is_inside_tree():
		return
	# behind the glass, it comes up to the glass. It puts its hand on it. It watches you go. That's all.
	_stalker.global_position = _wing_xf * Vector3(9.3, 0, -2.0)
	Sfx.play_at("thud", self, _stalker.global_position + Vector3(0, 1.5, 0), 0.0, 30.0, 0.7)
	Game.player.dread.add_fear(8.0, "at the glass")
	Game.hud.show_thought("It's at the glass. ...It's just watching me. Go. Just go.", 3.5)
	_watching = true


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
			if _chase_on or _at_bars or _way_on:
				return          # (not on the way back: it would throw you off the trail)
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


func _lift_arrives(chased := false) -> void:
	if Game.in_sequence:
		return
	if chased:
		await get_tree().create_timer(1.6, false).timeout
		Game.hud.show_thought("It can't get through the bars. ...It's watching me.", 3.0)
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
			if _chase_on:
				target += _wall_hug(target, me)
			if Vector2(me.x - target.x, me.z - target.z).length() < 0.45:
				_path.pop_front()
	elif not _trail.is_empty():
		target = _trail[0]
		if Vector2(me.x - target.x, me.z - target.z).length() < 0.5:
			_trail.pop_front()
	var dist := me.distance_to(p)
	var spd := 3.35 if dist > 4.0 else 3.7
	if _chase_on:
		# it never falls far behind, and right behind you it's short of your sprint (about 4):
		# any hesitation - a wrong turn, a crawl, a stumble - and it has you
		spd = 8.0 if dist > 10.0 else (6.1 if dist > 4.5 else 4.9)
	var ml := _wing_xf.affine_inverse() * me
	if in_wing and ml.z < -1.2 and ml.z > -5.4 and ml.x > 7.0 and ml.x < 11.5:
		target = _wing_xf * Vector3(9.25, 0, 0)       # (out of the room behind the glass, into the corridor)
	_stalker.move_to(target if dist > 1.6 else p, spd, delta)
	if _trail.size() > 400:
		_trail = _trail.slice(-400)
	if dist < 1.1:
		_hunting = false
		if _chase_on:
			_chase_on = false
			Sfx.stop_music(0.05)
		_stalker.scramble = false
		Game.entity_death("stalker", _stalker)


## Scrambling along the walls: toward a wall of the room it's heading into, on the side it's already clinging to.
func _wall_hug(target: Vector3, me: Vector3) -> Vector3:
	var h := target - me
	h.y = 0.0
	if h.length() < 0.3:
		return Vector3.ZERO
	var hd := h.normalized()
	var right := hd.cross(Vector3.UP)
	var tc := cell_at(target)
	var best := 0
	var off := Vector3.ZERO
	for d in 4:
		var nrm := Vector3(DX[d], 0, DZ[d])
		if absf(nrm.dot(hd)) > 0.5 or passable(tc.x, tc.y, d):
			continue
		var sd := 1 if nrm.dot(right) > 0.0 else -1
		if best == 0 or sd == _stalker.grip_side:
			best = sd
			off = nrm * 1.25
	_stalker.grip_side = best
	return off


# ------------------------------------------------------------------ the chase

## (tests) Is the doorway between two neighbouring rooms open - not walled, not slammed?
func _passable_route_check(a: Vector2i, b: Vector2i) -> bool:
	for d in 4:
		if Vector2i(a.x + DX[d], a.y + DZ[d]) == b:
			return passable(a.x, a.y, d)
	return false


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
	_save_chase_checkpoint()
	var start := cell_at(Game.player.global_position)
	_chase_path = _long_route(start, Vector2i(0, 0))
	if _chase_path.size() < 2:
		_chase_on = false
		return
	# the route is open: any shifting wall on it stays open
	for i in _chase_path.size() - 1:
		var mid := (cell_center(_chase_path[i].x, _chase_path[i].y) + cell_center(_chase_path[i + 1].x, _chase_path[i + 1].y)) * 0.5
		for w in _dynamic:
			if Vector2(w.center.x - mid.x, w.center.z - mid.z).length() < 0.01 and not w.open:
				_set_dynamic(w, true)
	_plan_decoys()
	_plan_hazards()
	# every other light dies - the panels go dark - and red strobes mark the way (the false trails too)
	for l in _lights:
		l.dead = true
		l.panel.material_override = Shapes.material(Color(0.2, 0.19, 0.17))
	for i in _chase_path.size():
		var c := _chase_path[i]
		_chase_lights.append(_red_light(c))
	for dc in _decoys:
		for c in dc.cells:
			_decoy_lights.append([_red_light(c), dc.at])
	# the EXIT signs: the only honest thing in here
	for i in range(1, _chase_path.size() - 1):
		var din := _chase_path[i] - _chase_path[i - 1]
		var dout := _chase_path[i + 1] - _chase_path[i]
		if din != dout or _decoy_at(i) or i % 4 == 0:
			_exit_sign(_chase_path[i], din, signi(din.x * dout.y - din.y * dout.x))
	# ...and over the mouth of every false trail, an EXIT sign that's dead: grey, cracked, hanging by one chain
	for dc in _decoys:
		var j: Vector2i = _chase_path[dc.at]
		var mouth: Vector2i = dc.cells[0]
		_broken_sign(mouth, mouth - j)
	if _env:
		var tw := create_tween().set_parallel()
		tw.tween_property(_env, "ambient_light_color", Color(0.75, 0.22, 0.16), 0.6)
		tw.tween_property(_env, "ambient_light_energy", 0.16, 0.6)
		tw.tween_property(_env, "fog_light_color", Color(0.3, 0.05, 0.03), 0.6)
		tw.tween_property(_env, "fog_density", 0.01, 0.6)
		if _env.volumetric_fog_enabled:
			tw.tween_property(_env, "volumetric_fog_albedo", Color(1.0, 0.3, 0.25), 0.6)
	Sfx.play_music("chase", 0.15)
	Sfx.stinger("braam", 2.0)
	Sfx.play("siren", -3.0)
	Sfx.play("metal_screech", -2.0, 0.6)
	Game.player.jolt(Vector3(-3, 2, 0))
	Game.hud.show_thought("The walls - they're closing! Follow the EXIT signs. RUN!", 3.0)
	_stalker.scramble = true
	Game.player.crouch_speed = 3.6
	# run for it: faster, and a long, high leap (the stalker's speeds match)
	Game.player.sprint_speed = 5.6
	Game.player.jump_speed = 5.6
	Game.player.jump_boost = 2.5
	var glow := OmniLight3D.new()       # a cold, pale sheen on it: white against all that red, so you see it coming
	glow.light_color = Color(0.8, 0.9, 1.0)
	glow.light_energy = 1.3
	glow.omni_range = 2.6
	glow.position = Vector3(0, 1.3, -0.6)
	_stalker.add_child(glow)
	if _rasp == null:
		_rasp = Sfx.make_loop("stalker_rasp", true, 2.0, 22.0)
		_stalker.add_child(_rasp)
		_rasp.position = Vector3(0, 1.4, 0)
	for i in mini(4, _chase_path.size()):
		_seal_queue.append(i)
	_queued_to = mini(3, _chase_path.size() - 1)


## A checkpoint, the moment the chase begins: die in it, and you're back here, not at the start of the maze.
func _save_chase_checkpoint() -> void:
	var pl: Player = Game.player
	var trail := []
	for t in _trail.slice(-80):
		trail.append([snappedf(t.x, 0.01), snappedf(t.z, 0.01)])
	Game.counters["chase"] = {"x": pl.global_position.x, "z": pl.global_position.z, "yaw": pl.rotation.y,
		"sx": _stalker.global_position.x, "sz": _stalker.global_position.z, "trail": trail}
	Game.set_flag("maze_chase")
	Game.save_checkpoint()
	Game.hud.show_hint("Checkpoint.", 2.0)


## A long way round: out through a far part of the maze and back to the lift, never crossing itself.
## (~45 rooms; the shortest way if there's no such loop.)
func _long_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var block := _prop_cells.duplicate()
	var best: Array[Vector2i] = _route_cells(from, to, block)
	var best_score := absf(best.size() - 46.0) + 30.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 777
	var cand: Array[Vector2i] = []
	for x in W:
		for z in H:
			var m := Vector2i(x, z)
			if m != from and m != to and not block.has(m):
				cand.append(m)
	for k in range(cand.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp := cand[k]
		cand[k] = cand[j]
		cand[j] = tmp
	var t0 := Time.get_ticks_msec()
	for m in cand:
		if Time.get_ticks_msec() - t0 > 250:
			break
		var a := _route_cells(from, m, block)
		if a.is_empty():
			continue
		var avoid := block.duplicate()
		for c in a:
			avoid[c] = true
		avoid.erase(m)
		var b := _route_cells(m, to, avoid)
		if b.is_empty():
			continue
		var ok := true
		for c in b.slice(1):
			if avoid.has(c):
				ok = false
				break
		if not ok:
			continue
		var whole: Array[Vector2i] = a.duplicate()
		whole.append_array(b.slice(1))
		var score := absf(whole.size() - 46.0)
		if score < best_score:
			best_score = score
			best = whole
	return best


func _red_light(c: Vector2i) -> OmniLight3D:
	var l := omni(cell_center(c.x, c.y) + Vector3(0, WALL_H - 0.25, 0), Color(1.0, 0.25, 0.15), 0.0, 6.2, false)
	l.visible = false
	part("box", cell_center(c.x, c.y) + Vector3(0, WALL_H - 0.03, 0), Vector3(0.5, 0.05, 0.5), Color(1.0, 0.15, 0.1), null, Vector3.ZERO, 6.0)
	return l


func _decoy_at(i: int) -> Dictionary:
	for dc in _decoys:
		if dc.at == i:
			return dc
	return {}


## False trails: lit red like the real way, a few rooms long, and every one ends in a wall.
func _plan_decoys() -> void:
	var on_route := {}
	for c in _chase_path:
		on_route[c] = true
	var used := {}
	var i := 4
	while i < _chase_path.size() - 5:
		var c := _chase_path[i]
		var placed := false
		for d in 4:
			var n := Vector2i(c.x + DX[d], c.y + DZ[d])
			if not _in(n.x, n.y) or on_route.has(n) or used.has(n) or _prop_cells.has(n) or not passable(c.x, c.y, d):
				continue
			var cells: Array[Vector2i] = [n]
			var cur := n
			for step in 2:
				var nxt := Vector2i(-99, -99)
				for d2 in 4:
					var m := Vector2i(cur.x + DX[d2], cur.y + DZ[d2])
					if _in(m.x, m.y) and m != c and not on_route.has(m) and not used.has(m) and not cells.has(m) \
							and not _prop_cells.has(m) and passable(cur.x, cur.y, d2):
						nxt = m
						break
				if nxt.x < 0:
					break
				cells.append(nxt)
				cur = nxt
			if cells.size() >= 2:
				for x in cells:
					used[x] = true
				_decoys.append({"at": i, "cells": cells, "warned": false})
				placed = true
				break
		i += 8 if placed else 1


## Things in the way, on the straight stretches: junk to weave round, holes to jump, a fallen wall to crawl under.
func _plan_hazards() -> void:
	var kinds := ["debris", "pit", "beam", "debris", "pit", "debris", "beam", "pit", "debris", "pit"]
	var k := 0
	var last := 1
	for i in range(3, _chase_path.size() - 3):
		if i - last < 3 or not _decoy_at(i).is_empty() or not _decoy_at(i - 1).is_empty() or not _decoy_at(i + 1).is_empty():
			continue
		var din := _chase_path[i] - _chase_path[i - 1]
		var dout := _chase_path[i + 1] - _chase_path[i]
		if din != dout:
			continue
		var c := _chase_path[i]
		if _prop_cells.has(c) or _no_hazard.has(c):
			continue      # (a water cooler or a desk in a corner would block the way round)
		var along := Vector3(din.x, 0, din.y)
		_hazards.append({"kind": kinds[k % kinds.size()], "idx": i, "c": cell_center(c.x, c.y), "along": along,
			"across": Vector3(-along.z, 0, along.x), "side": 1.0 if k % 2 == 0 else -1.0, "built": false})
		k += 1
		last = i


## Route waypoints for walking the chase (the QA test): [point, action] where action is "", "jump", "crouch", "stand".
func chase_waypoints() -> Array:
	var out := []
	for i in _chase_path.size():
		var c := cell_center(_chase_path[i].x, _chase_path[i].y)
		var h := {}
		for hz in _hazards:
			if hz.idx == i:
				h = hz
		if h.is_empty():
			out.append([c, ""])
			continue
		var al: Vector3 = h.along
		var ac: Vector3 = h.across
		var sd: float = h.side
		match String(h.kind):
			"debris":
				out.append([c - al * 2.4, ""])          # (through the doorway first, then sidestep)
				out.append([c - al * 1.3 - ac * sd * 1.25, ""])
				out.append([c, ""])
				out.append([c + al * 1.3 + ac * sd * 1.25, ""])
			"pit":
				out.append([c - al * 1.0, "jump"])
				out.append([c + al * 1.6, ""])
			"beam":
				out.append([c - al * 0.9, "crouch"])
				out.append([c + al * 1.15, "stand"])
	return out


func _exit_sign(c: Vector2i, din: Vector2i, turn: int) -> void:
	var fwd := Vector3(din.x, 0, din.y)
	var pos := cell_center(c.x, c.y) + fwd * 1.7 + Vector3(0, WALL_H - 0.42, 0)
	var g := group(pos, rad_to_deg(atan2(-fwd.x, -fwd.z)))
	var green := Color(0.1, 0.85, 0.3)
	part("box", Vector3(0, 0.28, 0), Vector3(0.02, 0.36, 0.02), Color(0.2, 0.2, 0.2), g)
	part("box", Vector3.ZERO, Vector3(1.05, 0.34, 0.05), green, g, Vector3.ZERO, 2.6)
	var white := Color(1, 1, 1)
	var ax := 0.0 if turn == 0 else (0.34 if turn > 0 else -0.34)
	var tx := 0.0 if turn == 0 else -ax * 0.45
	var lb := label(g.global_transform * Vector3(tx - (0.0 if turn != 0 else 0.15), 0, 0.03), g.rotation_degrees.y, "EXIT", 0.2, white, true)
	lb.no_depth_test = false
	# the arrow
	if turn == 0:
		var ux := 0.33
		part("box", Vector3(ux, -0.02, 0.03), Vector3(0.045, 0.18, 0.01), white, g, Vector3.ZERO, 3.0)
		part("box", Vector3(ux - 0.04, 0.05, 0.03), Vector3(0.045, 0.11, 0.01), white, g, Vector3(0, 0, -45), 3.0)
		part("box", Vector3(ux + 0.04, 0.05, 0.03), Vector3(0.045, 0.11, 0.01), white, g, Vector3(0, 0, 45), 3.0)
	else:
		var s := float(turn)
		part("box", Vector3(ax, 0, 0.03), Vector3(0.2, 0.045, 0.01), white, g, Vector3.ZERO, 3.0)
		part("box", Vector3(ax + s * 0.065, 0.04, 0.03), Vector3(0.11, 0.045, 0.01), white, g, Vector3(0, 0, -45 * s), 3.0)
		part("box", Vector3(ax + s * 0.065, -0.04, 0.03), Vector3(0.11, 0.045, 0.01), white, g, Vector3(0, 0, 45 * s), 3.0)


## A dead EXIT sign just inside the mouth of a false trail, facing back at the junction: grey, cracked, crooked,
## spitting the odd spark. (The way on always has a lit green one.)
func _broken_sign(c: Vector2i, into: Vector2i) -> void:
	var fwd := Vector3(into.x, 0, into.y)
	var pos := cell_center(c.x, c.y) - fwd * 1.6 + Vector3(0, WALL_H - 0.5, 0)
	var g := group(pos, rad_to_deg(atan2(-fwd.x, -fwd.z)))
	g.scale = Vector3.ONE * 1.4
	var tilt := Node3D.new()
	tilt.rotation_degrees.z = 24.0
	tilt.position = Vector3(-0.45, 0.25, 0)
	g.add_child(tilt)
	part("box", Vector3(0.0, 0.0, 0), Vector3(0.02, 0.3, 0.02), Color(0.2, 0.2, 0.2), g).position = Vector3(-0.45, 0.32, 0)
	var panel := part("box", Vector3(0.45, -0.17, 0), Vector3(1.05, 0.34, 0.05), Color(0.32, 0.33, 0.32), tilt, Vector3.ZERO, 0.0, 0.6)
	part("box", Vector3(0.3, -0.12, 0.03), Vector3(0.5, 0.012, 0.005), Color(0.05, 0.05, 0.05), tilt, Vector3(0, 0, 32))    # the crack
	part("box", Vector3(0.55, -0.2, 0.03), Vector3(0.3, 0.012, 0.005), Color(0.05, 0.05, 0.05), tilt, Vector3(0, 0, -20))
	var lb := Label3D.new()
	lb.text = "EXIT"
	lb.font_size = 48
	lb.pixel_size = 0.0045
	lb.modulate = Color(0.45, 0.47, 0.45)
	lb.position = Vector3(0.3, -0.17, 0.03)
	tilt.add_child(lb)
	var spark := OmniLight3D.new()
	spark.light_color = Color(0.7, 0.85, 1.0)
	spark.light_energy = 0.0
	spark.omni_range = 3.0
	spark.position = Vector3(0.9, -0.1, 0.1)
	tilt.add_child(spark)
	_sparks.append([spark, randf_range(0.5, 3.0)])
	panel.set_meta("broken", true)


## Slam shut every opening off the route around path cell i (a false trail's mouth stays open - and its far
## end is walled up), and drop whatever's waiting in that room.
func _seal_around(i: int) -> void:
	var c := _chase_path[i]
	var prev: Vector2i = _chase_path[i - 1] if i > 0 else Vector2i(-99, -99)
	var nxt: Vector2i = _chase_path[i + 1] if i + 1 < _chase_path.size() else Vector2i(-99, -99)
	var dc := _decoy_at(i)
	var mouth: Vector2i = dc.cells[0] if not dc.is_empty() else Vector2i(-99, -99)
	var k := 0
	for d in 4:
		var n := Vector2i(c.x + DX[d], c.y + DZ[d])
		if n == prev or n == nxt or n == mouth or not _in(n.x, n.y) or not passable(c.x, c.y, d):
			continue
		_slam(c, n, d, k * Sfx.CHASE_BEAT * 0.5)
		k += 1
	if not dc.is_empty():
		var cells: Array = dc.cells
		for x in cells:
			for d in 4:
				var m := Vector2i(x.x + DX[d], x.y + DZ[d])
				if cells.has(m) or (m == c and x == cells[0]) or not _in(m.x, m.y) or not passable(x.x, x.y, d):
					continue
				_slam(x, m, d, k * Sfx.CHASE_BEAT * 0.5)
				k += 1
	for h in _hazards:
		if h.idx == i and not h.built:
			_build_hazard(h, k * Sfx.CHASE_BEAT * 0.5)


func _slam(a: Vector2i, b: Vector2i, d: int, delay: float) -> void:
	_sealed[_edge_key(a, b)] = true
	var center := (cell_center(a.x, a.y) + cell_center(b.x, b.y)) * 0.5
	var length := CELL - PILLAR + 0.04
	var size := Vector3(THICK, WALL_H, length) if d <= 1 else Vector3(length, WALL_H, THICK)
	var body := solid_box(center + Vector3(0, WALL_H * 1.5 + 0.1, 0), size, WALL_B, null, "wallpaper")
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): Sfx.play_at("piston_slam", self, center + Vector3(0, 1.4, 0), 4.0, 32.0))
	# the sound's impact is SLAM_IMPACT in: the wall lands exactly on it (and so on the beat)
	tw.tween_property(body, "position:y", WALL_H * 0.5, Sfx.SLAM_IMPACT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var pl: Player = Game.player
		if pl and pl.global_position.distance_to(center) < 8.0:
			pl.jolt(Vector3(randf_range(-2.5, -1.0), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))))


func _build_hazard(h: Dictionary, delay: float) -> void:
	h.built = true
	var c: Vector3 = h.c
	var al: Vector3 = h.along
	var ac: Vector3 = h.across
	var sd: float = h.side
	var x_along := absf(al.x) > 0.5
	var root := Node3D.new()
	add_child(root)
	var drop := 3.4
	match String(h.kind):
		"debris":
			# a toppled filing cabinet and a desk, then another heap on the other side: weave
			for j in 2:
				var sgn := sd if j == 0 else -sd
				var at := c + al * (-1.3 if j == 0 else 1.3) + ac * sgn * 1.15
				var sz := Vector3(0.9, 1.1, 2.5) if x_along else Vector3(2.5, 1.1, 0.9)
				solid_box(at + Vector3(0, 0.55, 0), sz, Color(0.42, 0.43, 0.42), root, "metal")
				var top := part("box", at + Vector3(0, 1.25, 0) + ac * sgn * 0.3, Vector3(1.2, 0.3, 0.7) if x_along else Vector3(0.7, 0.3, 1.2),
					Color(0.5, 0.42, 0.3), root, Vector3(0, 12 * sgn, 8), 0.0, "wood")
				top.visible = true
		"pit":
			# the floor gives way: a hole right across, too deep to see the bottom
			var sz := Vector3(1.6, 0.02, CELL - THICK) if x_along else Vector3(CELL - THICK, 0.02, 1.6)
			var hole := MeshInstance3D.new()
			hole.mesh = Shapes.mesh("box")
			hole.scale = sz
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0, 0, 0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.disable_fog = true
			hole.material_override = m
			hole.position = c + Vector3(0, 0.012, 0)
			root.add_child(hole)
			# broken floor at both lips, tipping down into it
			for e in [-1.0, 1.0]:
				for j in 5:
					var off: float = (j - 2) * 0.95 + randf_range(-0.15, 0.15)
					var tilt: float = randf_range(18.0, 38.0) * e
					var rot := Vector3(0, 0, -tilt) if x_along else Vector3(tilt, 0, 0)
					part("box", c + al * e * (0.78 + randf_range(-0.05, 0.08)) + ac * off + Vector3(0, -0.06, 0),
						(Vector3(0.36, 0.1, randf_range(0.7, 0.95)) if x_along else Vector3(randf_range(0.7, 0.95), 0.1, 0.36)),
						CARPET.darkened(0.25), root, rot, 0.0, "carpet")
			drop = 0.0
			root.scale = Vector3(1, 1, 1) * 0.01
		"beam":
			# a wall section, fallen across the way: under it or nowhere
			var sz := Vector3(0.5, WALL_H - 1.2, CELL - THICK) if x_along else Vector3(CELL - THICK, WALL_H - 1.2, 0.5)
			var blk := solid_box(c + Vector3(0, 1.2 + (WALL_H - 1.2) * 0.5, 0), sz, WALL_B, root, "wallpaper")
			blk.get_child(1).visible = false
			var vis := part("box", c + Vector3(0, 1.75, 0), (Vector3(0.28, 1.15, CELL - THICK) if x_along else Vector3(CELL - THICK, 1.15, 0.28)),
				WALL_B, root, (Vector3(7, 0, 0) if x_along else Vector3(0, 0, 7)), 0.0, "wallpaper")
			vis.visible = true
			# torn plaster along its edges, pale against the dark
			for y in [1.2, 2.3]:
				part("box", c + Vector3(0, y + (0.04 if y < 2.0 else -0.04), 0) - al * 0.15, (Vector3(0.08, 0.1, CELL - THICK - 0.2) if x_along else Vector3(CELL - THICK - 0.2, 0.1, 0.08)),
					Color(0.85, 0.82, 0.74), root, (Vector3(7, 0, 0) if x_along else Vector3(0, 0, 7)), 0.6, "concrete")
			# the back of it: studs and torn plasterboard; cables and ceiling tiles hanging where it came from
			for j in 6:
				var sx := -2.0 + j * 0.8
				part("box", c + ac * sx + al * 0.18 + Vector3(0, 1.75 - sx * 0.06, 0), (Vector3(0.06, 1.1, 0.09) if x_along else Vector3(0.09, 1.1, 0.06)),
					Color(0.62, 0.5, 0.34), root, (Vector3(7, 0, 0) if x_along else Vector3(0, 0, 7)), 0.0, "wood")
			for j in 4:
				var cx := randf_range(-2.0, 2.0)
				var ln := randf_range(0.5, 1.2)
				part("cylinder", c + ac * cx + al * randf_range(-0.6, 0.6) + Vector3(0, WALL_H - ln * 0.5, 0), Vector3(0.02, ln, 0.02),
					Color(0.08, 0.08, 0.08), root, Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)))
			for j in 3:
				part("box", c + ac * (j - 1) * 1.4 + Vector3(0, WALL_H - 0.35, 0) + al * 0.4, Vector3(0.6, 0.02, 0.6), CEILING, root,
					Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), 0.0, "tiles_ceiling")
	h.root = root
	root.position.y = drop
	var tw := create_tween()
	tw.tween_interval(delay)
	if h.kind == "pit":
		tw.tween_callback(func():
			Sfx.play_at("thud", self, c, 6.0, 30.0)
			Sfx.play_at("scrape", self, c, 2.0, 25.0))
		tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_callback(func(): Sfx.play_at("piston_slam", self, c + Vector3(0, 1.4, 0), 4.0, 32.0))
		tw.tween_property(root, "position:y", 0.0, Sfx.SLAM_IMPACT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sfx.play_at("metal_screech" if h.kind == "debris" else "thud", self, c + Vector3(0, 1.0, 0), -2.0, 26.0))


func _music_clock() -> float:
	var p := Sfx.music_pos("chase")
	return p if p >= 0.0 else _chase_t


func _update_chase(delta: float) -> void:
	_chase_t += delta
	var pl: Player = Game.player
	var pc := cell_at(pl.global_position)
	# how far along the route you are (the nearest route cell a little ahead of where you were)
	for j in range(_chase_idx, mini(_chase_idx + 4, _chase_path.size())):
		if _chase_path[j] == pc:
			_chase_idx = maxi(_chase_idx, j)
			break
	while _queued_to < mini(_chase_idx + 4, _chase_path.size() - 1):
		_queued_to += 1
		_seal_queue.append(_queued_to)
	# the walls come down on the beat: one room's worth per beat
	var bt := int(floor((_music_clock() + Sfx.SLAM_IMPACT) / Sfx.CHASE_BEAT))
	if bt != _last_beat:
		_last_beat = bt
		if not _seal_queue.is_empty():
			_seal_around(_seal_queue.pop_front())
	# red strobes running ahead of you toward the way out (gentler with lower visual intensity); only the
	# nearby ones are lit at all
	var v := clampf(Settings.visual(), 0.0, 1.0)
	for i in _chase_lights.size():
		var near := i >= _chase_idx - 2 and i <= _chase_idx + 5
		_chase_lights[i].visible = near
		if near:
			var on := 1.0 if sin(_chase_t * 11.0 - i * 0.9) > -0.2 else 1.0 - 0.45 * v
			_chase_lights[i].light_energy = (3.6 if i >= _chase_idx else 2.0) * on
	for dl in _decoy_lights:
		var near: bool = dl[1] >= _chase_idx - 1 and dl[1] <= _chase_idx + 4
		dl[0].visible = near
		if near:
			dl[0].light_energy = 3.6 if sin(_chase_t * 11.0 - dl[1] * 0.9) > -0.2 else 3.6 * (1.0 - 0.45 * v)
	for l in _lights:
		l.light.light_energy = 0.0
		l.light.visible = false       # (off, not just dark: in the browser each surface only takes a few lights)
	for sp in _sparks:
		var light: OmniLight3D = sp[0]
		light.light_energy = maxf(0.0, light.light_energy - delta * 25.0)
		sp[1] -= delta
		if sp[1] <= 0.0 and Settings.flashing_ok():
			sp[1] = randf_range(0.6, 3.5)
			light.light_energy = randf_range(2.0, 4.0)
			if light.global_position.distance_to(pl.global_position) < 14.0:
				Sfx.play_at("static_burst", self, light.global_position, -14.0, 14.0)
	# the hazards: a word of warning the first time, and the holes swallow you if you don't jump
	var feet := pl.global_position
	for h in _hazards:
		if not h.built:
			continue
		var rel: Vector3 = feet - h.c
		var da: float = rel.dot(h.along)
		var dx: float = rel.dot(h.across)
		if not _hinted.has(h.kind) and da > -9.0 and da < -2.0 and absf(dx) < 2.5:
			_hinted[h.kind] = true
			match String(h.kind):
				"pit": Game.hud.show_thought("The floor's gone - JUMP!", 2.0)
				"beam": Game.hud.show_thought("It's down across the way - get under it! CROUCH!", 2.5)
				"debris": Game.hud.show_thought("Junk in the way - round it, don't stop!", 2.0)
		if h.kind == "pit" and absf(da) < 0.55 and absf(dx) < 2.4 and pl.is_on_floor() and feet.y < 0.15:
			_fall_in_pit()
			return
	for dc in _decoys:
		if not dc.warned and pc == dc.cells[dc.cells.size() - 1]:
			dc.warned = true
			Sfx.stinger("hit", 0.0)
			Game.hud.show_thought("Dead end. DEAD END. Back - BACK!", 2.0)
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
	if pl.dread.fear < 80.0:
		pl.dread.add_fear(2.5 * delta, "chased")
	pl.dread.fear = minf(pl.dread.fear, 80.0)
	pl.dread.stability = maxf(pl.dread.stability, 25.0)
	# the lift: steel bars slam down behind you, between you and it
	if pc == Vector2i(0, 0) and _chase_path.size() > 1:
		_chase_on = false
		_hunting = false
		_bar_gate(_chase_path[_chase_path.size() - 2])
		pl.sprint_speed = sprint_speed()
		pl.jump_speed = Player.JUMP_SPEED
		pl.jump_boost = 0.0
		pl.crouch_speed = 1.8
		Sfx.stop_music(0.1)
		Sfx.stinger("hit", 2.0)
		_lift_arrives(true)


func _on_stalker_planted(kind: String, side: int, where: Vector3) -> void:
	if not _hunting and not _at_bars:
		return
	match kind:
		"foot": Sfx.play_at("stalker_step", self, where, -2.0, 30.0)
		"hand": Sfx.play_at("stalker_step", self, where, 1.0, 30.0)
		"wall": Sfx.play_at("wall_grip", self, where, 4.0, 30.0)
	var pl: Player = Game.player
	if _chase_on and pl and pl.global_position.distance_to(where) < 3.5:
		pl.jolt(Vector3(randf_range(-0.8, -0.3), randf_range(-0.6, 0.6), 0))


## Into a hole in the floor.
func _fall_in_pit() -> void:
	_chase_on = false
	_hunting = false
	Sfx.stop_music(0.05)
	var pl: Player = Game.player
	pl.add_collision_exception_with(_body)
	create_tween().tween_property(pl, "global_position:y", pl.global_position.y - 9.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Game.entity_death("fall")
	get_tree().create_timer(3.0, false).timeout.connect(func():
		if is_instance_valid(pl) and is_instance_valid(_body):
			pl.remove_collision_exception_with(_body))


## Steel bars between you and it. It can't get through. It can still reach.
func _bar_gate(before: Vector2i) -> void:
	var dir := before - Vector2i(0, 0)
	var dv := Vector3(dir.x, 0, dir.y)
	var center := (cell_center(0, 0) + cell_center(before.x, before.y)) * 0.5
	_sealed[_edge_key(Vector2i(0, 0), before)] = true
	var g := group(center + Vector3(0, WALL_H + 0.2, 0), rad_to_deg(atan2(dv.x, dv.z)))
	var steel := Color(0.3, 0.31, 0.32)
	var span := CELL - PILLAR
	var n := 22
	for k in n:
		var x := -span * 0.5 + span * (k + 0.5) / n
		part("cylinder", Vector3(x, -WALL_H * 0.5, 0), Vector3(0.06, WALL_H, 0.06), steel, g, Vector3.ZERO, 0.0, "metal")
	for y in [0.15, 1.1, WALL_H - 0.15]:
		part("box", Vector3(0, y - WALL_H, 0), Vector3(span, 0.08, 0.1), steel.darkened(0.2), g, Vector3.ZERO, 0.0, "metal")
	var blk := solid_box(center + Vector3(0, WALL_H * 0.5, 0), (Vector3(0.14, WALL_H, span) if dir.x != 0 else Vector3(span, WALL_H, 0.14)),
		steel, null, "metal")
	blk.get_child(1).visible = false
	_gate = g
	create_tween().tween_property(g, "position:y", center.y + WALL_H, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sfx.play_at("gate_slam", self, center + Vector3(0, 1.4, 0), 6.0, 34.0)
	_bars_spot = center + dv * 0.62
	_at_bars = true
	_stalker.scramble = true


func _update_bars(delta: float) -> void:
	if Game.in_sequence and not Game.has_flag("maze_escaped") and Game.zone_type != "maze":
		return
	var pl: Player = Game.player
	if not _stalker.grab_bars:
		if _stalker.move_to(_bars_spot, 6.0, delta) or _stalker.global_position.distance_to(_bars_spot) < 0.1:
			_stalker.scramble = false
			_stalker.grab_bars = true
			_stalker.speed = 0.0
			Sfx.play_at("gate_slam", self, _bars_spot + Vector3(0, 1.4, 0), 0.0, 30.0)
	else:
		if pl:
			_stalker.face(pl.global_position, delta)
		_rattle_t -= delta
		if _rattle_t <= 0.0:
			_rattle_t = randf_range(0.5, 1.1)
			Sfx.play_at("bars_rattle", self, _bars_spot + Vector3(0, 1.5, 0), 3.0, 30.0)
			if _gate:
				var gx := _gate.position
				var tw := create_tween()
				for j in 4:
					tw.tween_property(_gate, "position", gx + Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)), 0.04)
				tw.tween_property(_gate, "position", gx, 0.04)


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
	# (the big ones stand in a corner of their room, out of the way of anyone running through)
	var bench_c: Vector3 = cell_center(spots[0].x, spots[0].y) + Vector3(-1.3, 0, -1.5)
	if not prop("bench", bench_c, 30.0):
		box(bench_c + Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.5), Color(0.5, 0.32, 0.18))
	interactable(bench_c + Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 1.0), func(): return "Park bench",
		func(): Game.hud.show_thought("Mr. Halvorsen's bench. From the park. There are still breadcrumbs on it.", 4.0))
	var sign_c: Vector3 = cell_center(spots[1].x, spots[1].y) + Vector3(1.2, 0, 1.2)
	shape_at("cylinder", sign_c + Vector3(0, 1.4, 0), Vector3(0.06, 2.8, 0.06), Color(0.3, 0.32, 0.3), true, Vector3.ZERO, "metal")
	box(sign_c + Vector3(0.45, 2.6, 0), Vector3(0.9, 0.22, 0.03), Color(0.1, 0.35, 0.18), false, 0.0, "metal")
	label(sign_c + Vector3(0.45, 2.6, 0.02), 0, "PARK AVE", 0.09, Color(0.95, 0.95, 0.9), false)
	var cart: Vector3 = cell_center(spots[2].x, spots[2].y) + Vector3(1.45, 0, 1.45)
	box(cart + Vector3(0, 0.7, 0), Vector3(1.7, 0.9, 0.9), Color(0.95, 0.92, 0.85), true, 45.0)
	box(cart + Vector3(0, 1.08, 0), Vector3(1.74, 0.12, 0.94), Color(0.95, 0.5, 0.6), false, 45.0)
	interactable(cart + Vector3(0, 1.0, 0), Vector3(2.6, 1.2, 1.4), func(): return "Ice cream cart",
		func():
			Game.hud.show_thought("Mina's cart. Every tub is melted. Long ago. It smells like the summer, gone off.", 4.0)
			Game.player.dread.add_fear(3.0, "melted"))
	# three notes, each with a piece of the breaker order
	var texts := ["\"%s goes first. ALWAYS first.\"" % _order[0],
		"\"%s then %s. Never the other way round.\"" % [_order[1], _order[2]],
		"\"%s last. Or it hears you.\"" % _order[3]]
	for k in 3:
		_no_hazard[spots[3 + k]] = true
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


## A breaker's lever: up (on) or down. With the model, only the lever swings on its hinge;
## the stand-in box (no model) tips as a whole, as before.
func _set_breaker(b: Dictionary, up: bool) -> void:
	if b.get("lever") != null:
		(b.lever as Node3D).rotation_degrees.x = 0.0 if up else 110.0
	else:
		(b.group as Node3D).rotation_degrees.z = 160.0 if up else 0.0


# ------------------------------------------------------------------ the way in
# Before the yellow rooms, a walk. You wake on the carpet of an office at night, the blinds lit like day;
# out down a corridor of numbered doors (one open: a radio playing a song you know); across a hall too big
# to be inside any building - pillars to the haze, a row of chairs facing the way you came, a door standing
# on its own, a staircase into the ceiling, a window onto a sky in a wall with nothing behind it, a payphone
# ringing; then one last corridor, and the rooms. One way: once you're in, the doorway is wallpaper.

const ENTRY_CELL := Vector2i(3, 0)    # the rooms are entered through this cell's south wall
const ENTRY_HALF := 0.95
const OFF_X0 := -35.0
const OFF_X1 := 5.0
const OFF_Z0 := -182.0
const OFF_Z1 := -150.0
const OFF_H := 2.9
const C1_X := -15.0                    # the corridor of doors: x -16.2..-13.8, z -150..-110
const COR_H := 2.6
const HALL_X0 := -30.0
const HALL_X1 := 70.0
const HALL_Z0 := -110.0
const HALL_Z1 := -40.0
const HALL_H := 3.4
const C2_X := 19.5                     # the last corridor: x 18.4..20.6, z -40..-3.4 (= the entry cell's x)
const START := Vector3(-32.6, 0.05, -170.0)
const PUDDLE := Vector3(10.0, 0.0, -62.0)
const PHONE := Vector3(22.0, 0.0, -58.63)
const SKY_WALL := Vector3(35.0, 0.0, -78.0)
const LONE_DOOR := Vector3(2.0, 0.0, -88.0)

const OFFICE_WALL := Color(0.8, 0.79, 0.75)
const OFFICE_CARPET := Color(0.3, 0.33, 0.37)
const C1_WALL := Color(0.86, 0.8, 0.6)

var _entry_wall: StaticBody3D
var _entry_sealed := false
var _seal_noticed := false
var _section := "office"
var _hum_base := -26.0
var _walk_lights: Array = []          # [light, panel, base energy]
var _chairs_row: Array[Node3D] = []
var _chairs_turned := false
var _lone_door: Node3D
var _lone_open := false
var _lone_through := false
var _clouds: Array[Node3D] = []
var _phone_state := 0                 # 0 quiet, 1 ringing, 2 answered
var _phone_t := 0.0
var _desk_phone := Vector3.ZERO
var _desk_state := 0
var _desk_t := 0.0
var _radio: AudioStreamPlayer3D
var _radio_off_t := -1.0
var _drip_t := 2.0
var _tv_screen: MeshInstance3D
var _flicker: Array = []              # [light, panel, base]
var _flick_t := 0.0
var _door_tries := 0


func _way_in() -> void:
	_office()
	_corridor_of_doors()
	_hall()
	_last_corridor()
	_entry()
	checkpoint_zone("hall", Vector3(C1_X, 1.3, HALL_Z0 + 2.0), Vector3(2.2, 2.6, 1.5), Vector3(C1_X, 0.05, HALL_Z0 + 2.0), 180.0)
	checkpoint_zone("rooms", Vector3(C2_X, 1.3, -8.0), Vector3(2.0, 2.6, 1.5), Vector3(C2_X, 0.05, -8.0), 180.0)
	trigger(Vector3(C1_X, 1.3, HALL_Z0 + 1.0), Vector3(2.2, 2.6, 1.0), func():
		Game.hud.show_thought("...How big IS this place?", 3.0))
	trigger(Vector3(C2_X, 1.3, -30.0), Vector3(2.0, 2.6, 1.0), func():
		Game.hud.show_thought("That smell. Damp carpet. ...I know where this goes.", 3.5))
	for i in _walk_lights.size():
		if i % 3 != 2:
			continue
		var wl: Array = _walk_lights[i]
		Anomalies.register({"id": "light", "owner": self, "position": (wl[0] as Node3D).position, "radius": 1.5, "min_stage": 1,
			"weight": 0.5, "discovery_fear": 2.0,
			"apply": func():
				var off: bool = (wl[0] as OmniLight3D).light_energy > 0.01
				(wl[0] as OmniLight3D).light_energy = 0.0 if off else float(wl[2])
				(wl[1] as MeshInstance3D).material_override = Shapes.material(Color(0.35, 0.34, 0.3)) if off else Shapes.material(PANEL, 0.85, 3.0)})
	# the chairs in the hall turn to face you
	Anomalies.register({"id": "chairs", "owner": self, "position": Vector3(-6.75, 0.6, -104.0), "radius": 6.0, "weight": 2.0,
		"max_changes": 1, "discovery_fear": 6.0, "max_distance": 45.0,
		"can_apply": func(): return Game.player != null and Game.player.global_position.z > -100.0,
		"apply": func():
			_chairs_turned = true
			for ch in _chairs_row:
				var to: Vector3 = Game.player.global_position - ch.global_position
				ch.rotation.y = atan2(to.x, to.z)})


## An axis-aligned wall from a to b (the same z, or the same x), h high, with openings [from, to, top] or
## [from, to, top, sill] along it: a lintel from `top` up to h, and (windows) a wall up to `sill` below.
func _wall_run(a: Vector3, b: Vector3, h: float, openings: Array, col: Color, surface := "wallpaper", t := 0.3) -> void:
	var along_x := absf(b.x - a.x) >= absf(b.z - a.z)
	var lo := minf(a.x, b.x) if along_x else minf(a.z, b.z)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.z, b.z)
	var fixed := a.z if along_x else a.x
	var cuts := openings.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var at := lo
	for o in cuts:
		_wall_piece(at, o[0], 0.0, h, fixed, along_x, col, surface, t, true)
		_wall_piece(o[0], o[1], o[2], h, fixed, along_x, col, surface, t, false)
		if o.size() > 3:
			_wall_piece(o[0], o[1], 0.0, o[3], fixed, along_x, col, surface, t, true)
		at = o[1]
	_wall_piece(at, hi, 0.0, h, fixed, along_x, col, surface, t, true)


func _wall_piece(p0: float, p1: float, y0: float, y1: float, fixed: float, along_x: bool, col: Color, surface: String, t: float, base: bool) -> void:
	if p1 - p0 < 0.01 or y1 - y0 < 0.01:
		return
	var c := (p0 + p1) * 0.5
	var y := (y0 + y1) * 0.5
	box(Vector3(c, y, fixed) if along_x else Vector3(fixed, y, c), Vector3(p1 - p0, y1 - y0, t) if along_x else Vector3(t, y1 - y0, p1 - p0), col, true, 0.0, surface)
	if base:
		box(Vector3(c, 0.06, fixed) if along_x else Vector3(fixed, 0.06, c), Vector3(p1 - p0, 0.12, t + 0.03) if along_x else Vector3(t + 0.03, 0.12, p1 - p0), BASEBOARD, false)


## Floor, ceiling and the walls named in `sides` ("s" z0, "n" z1, "w" x0, "e" x1) of a box room. Walls along x
## run the full width (and past the corners); walls along z fit between them. openings: {side: [...]}.
func _room(x0: float, x1: float, z0: float, z1: float, h: float, sides: String, openings: Dictionary, wall_c: Color,
		floor_c: Color, wall_s := "wallpaper", ceil_c := CEILING) -> void:
	var t := 0.3
	box(Vector3((x0 + x1) * 0.5, -0.05, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), floor_c, true, 0.0, "carpet")
	box(Vector3((x0 + x1) * 0.5, h + 0.05, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), ceil_c, true, 0.0, "tiles_ceiling")
	if sides.contains("s"):
		_wall_run(Vector3(x0 - t * 0.5, 0, z0), Vector3(x1 + t * 0.5, 0, z0), h, openings.get("s", []), wall_c, wall_s)
	if sides.contains("n"):
		_wall_run(Vector3(x0 - t * 0.5, 0, z1), Vector3(x1 + t * 0.5, 0, z1), h, openings.get("n", []), wall_c, wall_s)
	if sides.contains("w"):
		_wall_run(Vector3(x0, 0, z0 + t * 0.5), Vector3(x0, 0, z1 - t * 0.5), h, openings.get("w", []), wall_c, wall_s)
	if sides.contains("e"):
		_wall_run(Vector3(x1, 0, z0 + t * 0.5), Vector3(x1, 0, z1 - t * 0.5), h, openings.get("e", []), wall_c, wall_s)


## A ceiling light that can go out: an emissive panel and a lamp under it.
func _walk_light(pos: Vector3, h: float, energy: float, rng: float, col := LIGHT) -> void:
	var panel := part("box", Vector3(pos.x, h - 0.02, pos.z), Vector3(1.2, 0.03, 0.6), PANEL, null, Vector3.ZERO, 3.0)
	var l := omni(Vector3(pos.x, h - 0.35, pos.z), col, energy, rng, false)
	_walk_lights.append([l, panel, energy])


## Rows of ceiling troffers (models, drawn together), skipping where `skip` says.
func _troffers(x0: float, x1: float, z0: float, z1: float, step: float, h: float, skip := Callable()) -> void:
	var x := x0
	while x <= x1 + 0.01:
		var z := z0
		while z <= z1 + 0.01:
			var p := Vector3(x, h, z)
			if not skip.is_valid() or not skip.call(p):
				if not scatter_prop("ceiling_troffer", p, 0.0, 1.0, false):
					part("box", p - Vector3(0, 0.02, 0), Vector3(1.2, 0.03, 0.5), PANEL, null, Vector3.ZERO, 2.5)
			z += step
		x += step


## A thing that stands on the floor, with something to bump into.
func _thing(slot: String, pos: Vector3, yaw: float, solid: Vector3, fallback_col := Color(0.5, 0.5, 0.5)) -> void:
	if not scatter_prop(slot, pos, yaw, 1.0, true):
		box(pos + Vector3(0, solid.y * 0.5, 0), solid, fallback_col, false, yaw, "wood")
	if solid != Vector3.ZERO:
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = solid
		cs.shape = bs
		cs.transform = Transform3D(b, pos + Vector3(0, solid.y * 0.5, 0))
		_body.add_child(cs)


# ---- the office

func _office() -> void:
	var cx := (OFF_X0 + OFF_X1) * 0.5
	# the west wall: six windows, the blinds down, and light behind them like the middle of the day
	var wins := []
	for k in 6:
		var wz := OFF_Z0 + 4.0 + k * 4.8
		wins.append([wz - 1.2, wz + 1.2, 2.3, 0.9])
	var c1 := [C1_X - 1.05, C1_X + 1.05, COR_H]
	_room(OFF_X0, OFF_X1, OFF_Z0, OFF_Z1, OFF_H, "nswe", {"w": wins, "n": [c1]}, OFFICE_WALL, OFFICE_CARPET, "plaster", Color(0.86, 0.85, 0.8))
	for k in 6:
		var wz := OFF_Z0 + 4.0 + k * 4.8
		part("box", Vector3(OFF_X0 - 0.17, 1.6, wz), Vector3(0.02, 1.4, 2.4), Color(1.0, 0.97, 0.88), null, Vector3.ZERO, 2.2)
		box(Vector3(OFF_X0 + 0.16, 0.92, wz), Vector3(0.08, 0.04, 2.44), Color(0.9, 0.9, 0.88), false)      # the sill
		var up := k == 3      # one has its blinds pulled up: nothing out there but white
		var y := 2.24
		while y > (1.9 if up else 0.95):
			box(Vector3(OFF_X0 + 0.05, y, wz), Vector3(0.05, 0.008, 2.36), Color(0.88, 0.87, 0.82), false, 0.0, "metal")
			y -= 0.085
		omni(Vector3(OFF_X0 + 1.6, 1.6, wz), Color(1.0, 0.95, 0.85), 0.55 if not up else 0.9, 7.0, false)
	trigger(Vector3(OFF_X0 + 2.0, 1.3, OFF_Z0 + 4.0 + 3 * 4.8), Vector3(3.0, 2.6, 3.0), func():
		Game.hud.show_thought("Daylight. ...It's three in the morning. And there's nothing out there. Just white.", 4.5))
	# ceiling
	_troffers(OFF_X0 + 2.5, OFF_X1 - 2.5, OFF_Z0 + 2.0, OFF_Z1 - 2.0, 4.0, OFF_H,
		func(p: Vector3): return absf(p.x - (-25.0)) < 0.6 and absf(p.z - (-174.0)) < 0.6 or absf(p.x - (-5.0)) < 0.6 and absf(p.z - (-174.0)) < 0.6)
	_walk_light(Vector3(-25.0, 0, -174.0), OFF_H, 1.0, 15.0, Color(1.0, 0.98, 0.92))
	_walk_light(Vector3(-5.0, 0, -174.0), OFF_H, 1.0, 15.0, Color(1.0, 0.98, 0.92))
	omni(Vector3(-15.0, OFF_H - 0.4, -158.0), Color(1.0, 0.98, 0.92), 0.9, 14.0, false)
	# the pods: four desks back to back, partitions, monitors, chairs pushed out where people got up
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1201
	var pod_x := [-28.0, -21.0, -14.0, -7.0, 0.0]
	var pod_z := [-177.0, -170.0, -163.0]
	var screen_on := Vector2i(2, 1)
	var phone_at := Vector2i(1, 2)
	var fabric := Color(0.4, 0.43, 0.48)
	for i in pod_x.size():
		for j in pod_z.size():
			var px: float = pod_x[i]
			var pz: float = pod_z[j]
			box(Vector3(px, 0.62, pz), Vector3(4.1, 1.24, 0.05), fabric, true, 0.0, "fabric")
			box(Vector3(px, 1.255, pz), Vector3(4.12, 0.03, 0.07), Color(0.7, 0.7, 0.72), false, 0.0, "metal")
			for sx in [-1.0, 1.0]:
				box(Vector3(px + sx * 2.06, 0.62, pz), Vector3(0.05, 1.24, 1.9), fabric, true, 0.0, "fabric")
				box(Vector3(px + sx * 2.06, 1.255, pz), Vector3(0.07, 0.03, 1.92), Color(0.7, 0.7, 0.72), false, 0.0, "metal")
			for dx in [-1.0, 1.0]:
				for side in [-1.0, 1.0]:
					var yaw := 0.0 if side > 0 else 180.0
					var dp := Vector3(px + dx * 1.0, 0, pz + side * 0.47)
					var b := Basis(Vector3.UP, deg_to_rad(yaw))
					_thing("desk_long", dp, yaw, Vector3(1.96, 0.775, 0.88), Color(0.6, 0.55, 0.47))
					if rng.randf() < 0.85:
						var mp: Vector3 = dp + b * Vector3(0.1, 0.775, -0.25)
						scatter_prop("monitor_wide", mp, yaw, 1.0, false)
						if Vector2i(i, j) == screen_on and dx > 0 and side > 0:
							part("box", mp + b * Vector3(0, 0.37, 0.035), Vector3(0.84, 0.5, 0.004), Color(0.35, 0.5, 0.85), null, Vector3(0, yaw, 0), 1.6)
							var lb := label(mp + b * Vector3(0, 0.4, 0.04), yaw, "SESSION LOCKED\n03:12", 0.045, Color(0.9, 0.95, 1.0))
							lb.pixel_size = 0.045 / 64.0
						box(dp + b * Vector3(0.05, 0.785, 0.12), Vector3(0.46, 0.02, 0.15), Color(0.16, 0.16, 0.17), false, yaw, "metal")   # keyboard
					if rng.randf() < 0.5:
						var cup := "coffee_cup" if rng.randf() < 0.5 else "mug"
						prop(cup, dp + b * Vector3(rng.randf_range(-0.8, -0.4), 0.775, rng.randf_range(-0.1, 0.2)), rng.randf() * 360.0)
					if rng.randf() < 0.6:
						part("box", dp + b * Vector3(rng.randf_range(-0.7, 0.3), 0.779, rng.randf_range(0.0, 0.25)), Vector3(0.21, 0.004, 0.297),
							Color(0.94, 0.93, 0.88), null, Vector3(0, yaw + rng.randf_range(-25, 25), 0))
					if Vector2i(i, j) == phone_at and dx < 0 and side < 0:
						_desk_phone = dp + b * Vector3(-0.6, 0.775, 0.0)
						box(_desk_phone + Vector3(0, 0.04, 0), Vector3(0.22, 0.08, 0.2), Color(0.2, 0.2, 0.21), false, yaw)
						box(_desk_phone + Vector3(0, 0.1, -0.03), Vector3(0.2, 0.05, 0.06), Color(0.15, 0.15, 0.16), false, yaw)
						interactable(_desk_phone + Vector3(0, 0.15, 0), Vector3(0.5, 0.4, 0.5),
							func(): return "Answer the phone" if _desk_state == 1 else "A desk phone",
							func(): _answer_desk_phone())
					# the chair, where somebody pushed it back
					var cp: Vector3 = dp + b * Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(0.75, 1.15))
					var cyaw := yaw + 180.0 + rng.randf_range(-45.0, 45.0)
					_thing("office_chair", cp, cyaw, Vector3(0.55, 0.95, 0.55), Color(0.15, 0.15, 0.17))
	# the north side: reception, a kitchenette, the printer, the notice board
	_thing("reception_desk", Vector3(-3.0, 0, -154.6), 180.0, Vector3(3.0, 1.1, 0.7), Color(0.55, 0.5, 0.42))
	furnish("office_chair", Vector3(-3.0, 0, -153.6), 190.0, Vector3(0.55, 0.95, 0.55), Vector3(0, 0.47, 0))
	label(Vector3(-3.0, 2.15, OFF_Z1 - 0.16), 180.0, "HALCYON  &  PARTNERS", 0.16, Color(0.62, 0.6, 0.55), false)
	_thing("waiting_chairs", Vector3(3.9, 0, -158.0), -90.0, Vector3(1.8, 0.8, 0.6))
	_thing("waiting_chairs", Vector3(3.9, 0, -161.0), -90.0, Vector3(1.8, 0.8, 0.6))
	prop("potted_plant", Vector3(3.9, 0, -155.2), 30.0)
	prop("potted_plant", Vector3(OFF_X1 - 0.6, 0, OFF_Z0 + 0.6), 80.0)
	prop("potted_plant", Vector3(-17.4, 0, OFF_Z1 - 0.6), 10.0)
	prop("coat_rack", Vector3(-12.4, 0, OFF_Z1 - 0.5), 0.0)
	# kitchenette (north-west)
	for k in 3:
		_thing("kitchen_cabinet", Vector3(-33.8 + k * 1.24, 0, OFF_Z1 - 0.47), 180.0, Vector3(1.2, 0.9, 0.6), Color(0.85, 0.85, 0.82))
	_thing("fridge", Vector3(-29.4, 0, OFF_Z1 - 0.5), 180.0, Vector3(0.7, 1.8, 0.68), Color(0.92, 0.92, 0.9))
	ambient("hum", Vector3(-29.4, 1.0, OFF_Z1 - 0.6), true, -14.0, 9.0)
	prop("kettle", Vector3(-32.6, 0.92, OFF_Z1 - 0.5), 200.0)
	for k in 3:
		prop("mug", Vector3(-33.9 + k * 0.16, 0.92, OFF_Z1 - 0.62), k * 50.0)
	_thing("water_cooler", Vector3(OFF_X0 + 0.5, 0, -156.0), 90.0, Vector3(0.4, 1.4, 0.4), Color(0.85, 0.85, 0.82))
	label(Vector3(-31.0, 1.6, OFF_Z1 - 0.16), 180.0, "PLEASE WASH YOUR OWN MUG", 0.05, Color(0.2, 0.2, 0.2), false)
	# the printer, still warm
	box(Vector3(-10.0, 0.4, -156.5), Vector3(0.7, 0.8, 0.6), Color(0.45, 0.45, 0.46), true, 0.0, "metal")
	box(Vector3(-10.0, 0.95, -156.5), Vector3(0.62, 0.3, 0.52), Color(0.86, 0.85, 0.8), true)
	box(Vector3(-10.0, 1.11, -156.3), Vector3(0.5, 0.02, 0.4), Color(0.25, 0.25, 0.26), false)
	var sheet := part("box", Vector3(-10.0, 0.83, -156.15), Vector3(0.21, 0.003, 0.297), Color(0.96, 0.96, 0.93))
	sheet.visible = false
	interactable(Vector3(-10.0, 1.0, -156.5), Vector3(0.9, 0.8, 0.9),
		func(): return "The printer" if not sheet.visible else "Read the page",
		func():
			if not sheet.visible:
				Sfx.play_at("motor", self, Vector3(-10.0, 1.0, -156.5), -8.0, 12.0)
				Sfx.play_at("page", self, Vector3(-10.0, 1.0, -156.5), -2.0, 10.0)
				sheet.visible = true
				Game.hud.show_thought("It's warm. It wakes up, and prints one page.", 3.0)
			else:
				Game.hud.show_thought("Blank, except one line, in the middle: THANK YOU FOR WAITING.", 4.0))
	# the notice board
	if prop("notice_board", Vector3(-22.0, 1.55, OFF_Z1 - 0.15), 180.0) == null:
		box(Vector3(-22.0, 1.55, OFF_Z1 - 0.17), Vector3(1.2, 0.9, 0.03), Color(0.6, 0.45, 0.3), false)
	for k in 5:
		part("box", Vector3(-22.4 + (k % 3) * 0.38, 1.7 - int(k / 3) * 0.36, OFF_Z1 - 0.19), Vector3(0.21, 0.28, 0.004),
			Color(0.96, 0.95, 0.85) if k % 2 == 0 else Color(0.95, 0.9, 0.6), null, Vector3(0, 0, k * 4.0 - 8.0))
	interactable(Vector3(-22.0, 1.55, OFF_Z1 - 0.4), Vector3(1.3, 1.0, 0.4), func(): return "Notice board",
		func(): Game.hud.show_thought("FIRE DRILL THURSDAY.  Has anyone seen my mug (blue, WORLD'S OKAYEST)?  PLEASE DON'T PROP THE DOORS OPEN.  Lift out of order - use the stairs.  The stairs are out of order.", 7.0))
	# the clock over the way out, stopped
	box(Vector3(C1_X, 2.75, OFF_Z1 - 0.17), Vector3(0.5, 0.2, 0.03), Color(0.05, 0.05, 0.05), false)
	label(Vector3(C1_X, 2.75, OFF_Z1 - 0.19), 180.0, "03:12", 0.12, Color(1.0, 0.2, 0.15))
	# the glass doors, propped open (someone didn't read the notice)
	for side in [-1.0, 1.0]:
		var hinge := Vector3(C1_X + side * 1.02, 0, OFF_Z1 - 0.2)
		var g := group(hinge, side * -100.0)
		part("box", Vector3(-side * 0.5, 1.15, 0), Vector3(0.98, 2.28, 0.012), Color(0.75, 0.85, 0.85), g, Vector3.ZERO, 0.0, "glass")
		part("box", Vector3(-side * 0.5, 1.0, 0.03), Vector3(0.4, 0.03, 0.03), Color(0.7, 0.7, 0.72), g, Vector3.ZERO, 0.0, "metal")
	if not prop("exit_sign", Vector3(C1_X + 1.6, 2.45, OFF_Z1 - 0.15), 180.0):
		part("box", Vector3(C1_X + 1.6, 2.45, OFF_Z1 - 0.18), Vector3(0.36, 0.16, 0.04), Color(0.2, 1.0, 0.4), null, Vector3.ZERO, 3.0)


func _answer_desk_phone() -> void:
	if _desk_state != 1:
		Game.hud.show_thought("A desk phone. Line four is blinking.", 2.5)
		return
	_desk_state = 2
	Sfx.play("static_burst", -10.0)
	Game.hud.show_thought("...Nobody. Just the hum - the same hum as in here. Like they're in the next room. Then the line goes.", 5.0)
	Game.player.dread.add_fear(3.0, "the phone")


# ---- the corridor of doors

func _corridor_of_doors() -> void:
	var x0 := C1_X - 1.2
	var x1 := C1_X + 1.2
	var room := [OFF_Z1 + 19.5, OFF_Z1 + 20.5, 2.1]       # room 207 stands open
	_room(x0, x1, OFF_Z1, HALL_Z0, COR_H, "we", {"w": [room]}, C1_WALL, Color(0.38, 0.36, 0.3))
	var n := 0
	for k in 7:
		var z := OFF_Z1 + 5.0 + k * 5.0
		for side in [-1, 1]:
			n += 1
			var num := 200 + (k * 2 + (1 if side < 0 else 2))
			var wx := x0 + 0.17 if side < 0 else x1 - 0.17
			var d := door(Vector3(wx, 0, z), 90.0 if side < 0 else -90.0, Color(0.55, 0.42, 0.3), 0.92, 2.05)
			label(Vector3(wx + (0.02 if side < 0 else -0.02), 2.25, z), 90.0 if side < 0 else -90.0, str(num), 0.08, Color(0.85, 0.72, 0.4), false)
			if num == 207:
				open_door(d, -95.0, 0.01)
				continue
			var spooky := num == 210
			interactable(Vector3(wx + (0.15 if side < 0 else -0.15), 1.05, z), Vector3(0.3, 2.0, 1.0), func(): return "Room %d" % num,
				func():
					Sfx.play_at("knock", self, Vector3(wx, 1.0, z), -14.0, 8.0, 1.6)
					if spooky and _door_tries >= 0:
						_door_tries = -1
						await get_tree().create_timer(0.8, false).timeout
						Sfx.play_at("knock", self, Vector3(wx - side * 0.5, 1.0, z), -6.0, 10.0, 0.9)
						Game.hud.show_thought("Locked. ...Someone on the other side just let go of the handle.", 4.0)
						Game.player.dread.add_fear(5.0, "the handle")
					else:
						Game.hud.show_thought("Locked.", 1.5))
	_troffers(C1_X, C1_X, OFF_Z1 + 2.5, HALL_Z0 - 2.5, 4.0, COR_H,
		func(p: Vector3): return absf(p.z - (OFF_Z1 + 6.5)) < 0.6 or absf(p.z - (OFF_Z1 + 22.5)) < 0.6 or absf(p.z - (OFF_Z1 + 34.5)) < 0.6)
	for z in [OFF_Z1 + 6.5, OFF_Z1 + 22.5, OFF_Z1 + 34.5]:
		_walk_light(Vector3(C1_X, 0, z), COR_H, 0.9, 9.0, Color(1.0, 0.95, 0.82))
	# room 207: a storeroom. A mop, a chair facing the corner, and a radio playing a song you know
	var rx0 := x0 - 4.2
	_room(rx0, x0, OFF_Z1 + 17.8, OFF_Z1 + 22.2, COR_H, "w", {}, C1_WALL.darkened(0.08), Color(0.36, 0.34, 0.29))
	for wz in [OFF_Z1 + 17.8, OFF_Z1 + 22.2]:      # (ending inside the corridor's wall: no faces in the same plane)
		_wall_run(Vector3(rx0 - 0.15, 0, wz), Vector3(x0, 0, wz), COR_H, [], C1_WALL.darkened(0.08))
	var rc := Vector3(rx0 + 2.1, 0, OFF_Z1 + 20.0)
	if not prop("ceiling_bulb", rc + Vector3(0, COR_H, 0), 0.0):
		part("sphere", rc + Vector3(0, COR_H - 0.3, 0), Vector3.ONE * 0.09, Color(1.0, 0.9, 0.7), null, Vector3.ZERO, 3.0)
	omni(rc + Vector3(0, COR_H - 0.5, 0), Color(1.0, 0.85, 0.6), 0.8, 6.0, false)
	furnish("chair_wood", rc + Vector3(-1.5, 0, -1.6), 225.0, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.45, 0))
	_thing("step_stool", rc + Vector3(1.4, 0, 1.6), 20.0, Vector3(0.4, 0.5, 0.4))
	if not prop("radio_old", rc + Vector3(1.4, 0.5, 1.6), 200.0):
		box(rc + Vector3(1.4, 0.63, 1.6), Vector3(0.4, 0.26, 0.18), Color(0.45, 0.3, 0.18), false)
	shape_at("cylinder", rc + Vector3(-1.4, 0.17, 1.5), Vector3(0.36, 0.34, 0.36), Color(0.75, 0.6, 0.15), true)       # mop bucket
	shape_at("cylinder", rc + Vector3(-1.35, 0.8, 1.45), Vector3(0.03, 1.3, 0.03), Color(0.55, 0.42, 0.28), false, Vector3(8, 0, 6), "wood")
	_radio = AudioStreamPlayer3D.new()
	_radio.max_distance = 18.0
	_radio.unit_size = 2.5
	_radio.volume_db = -4.0
	_radio.attenuation_filter_cutoff_hz = 2800.0
	_radio.position = rc + Vector3(1.4, 0.65, 1.6)
	add_child(_radio)
	interactable(rc + Vector3(1.4, 0.7, 1.6), Vector3(0.6, 0.5, 0.5),
		func(): return "Turn the radio off" if _radio.playing else "The radio",
		func():
			if _radio.playing:
				_radio.stop()
				_radio_off_t = 0.0
				Sfx.play("switch", -10.0)
				Game.hud.show_thought("Quiet. ...I know that song. I don't know where from.", 3.5)
			else:
				Game.hud.show_thought("Off. The dial's still warm.", 2.0))


# ---- the hall

func _hall() -> void:
	_room(HALL_X0, HALL_X1, HALL_Z0, HALL_Z1, HALL_H, "nswe",
		{"s": [[C1_X - 1.05, C1_X + 1.05, COR_H]], "n": [[C2_X - ENTRY_HALF, C2_X + ENTRY_HALF, COR_H]]}, WALL_A, CARPET)
	var keep := [Vector3(C1_X, 0, HALL_Z0), Vector3(C2_X, 0, HALL_Z1), PUDDLE, SKY_WALL, LONE_DOOR, Vector3(-20, 0, -76), Vector3(50, 0, -94), Vector3(-6.75, 0, -104)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1301
	var x := HALL_X0 + 4.0
	while x < HALL_X1 - 1.0:
		var z := HALL_Z0 + 4.0
		while z < HALL_Z1 - 1.0:
			var p := Vector3(x, 0, z)
			if not (PHONE.distance_to(p) < 1.0) and keep.any(func(k): return Vector2(k.x - x, k.z - z).length() < 4.2):
				z += 8.0
				continue
			box(p + Vector3(0, HALL_H * 0.5, 0), Vector3(0.9, HALL_H, 0.9), WALL_A if rng.randf() < 0.7 else WALL_B, true, 0.0, "wallpaper")
			box(p + Vector3(0, 0.06, 0), Vector3(0.96, 0.12, 0.96), BASEBOARD, false)
			var r := rng.randf()
			if r < 0.06:
				prop("fire_extinguisher", p + Vector3(0.62, 0, 0), 0.0)
			elif r < 0.1:
				prop("potted_plant", p + Vector3(-0.8, 0, 0.6), rng.randf() * 360.0)
			elif r < 0.16:
				box(p + Vector3(0, 0.35, 0.46), Vector3(0.08, 0.12, 0.012), Color(0.92, 0.9, 0.84), false)      # a socket
			z += 8.0
		x += 8.0
	# light: rows of troffers; lamps every 16 m; far over in the north-east the lights are out
	var dead := func(p: Vector3): return p.x > 41.0 and p.z > -74.0
	var lamp_x := [-20.0, -4.0, 12.0, 28.0, 44.0, 60.0]
	var lamp_z := [-100.0, -84.0, -68.0, -52.0]
	_troffers(HALL_X0 + 2.0, HALL_X1 - 2.0, HALL_Z0 + 2.0, HALL_Z1 - 2.0, 4.0, HALL_H, func(p: Vector3):
		if dead.call(p):
			box(p - Vector3(0, 0.02, 0), Vector3(1.2, 0.03, 0.5), Color(0.42, 0.41, 0.36), false)
			return true
		return lamp_x.any(func(lx): return absf(lx - p.x) < 0.5) and lamp_z.any(func(lz): return absf(lz - p.z) < 0.5))
	for lx in lamp_x:
		for lz in lamp_z:
			var p := Vector3(lx, 0, lz)
			if not dead.call(p):
				_walk_light(p, HALL_H, 1.25, 16.0)
	# a tube that won't settle, over the way on
	var fp := Vector3(C2_X + 4.0, 0, HALL_Z1 + 6.0)
	var fpanel := part("box", Vector3(fp.x, HALL_H - 0.02, fp.z), Vector3(1.2, 0.03, 0.6), PANEL, null, Vector3.ZERO, 3.0)
	var fl := omni(Vector3(fp.x, HALL_H - 0.35, fp.z), LIGHT, 1.0, 10.0, false)
	_flicker.append([fl, fpanel, 1.0])
	ambient("buzz", fp + Vector3(0, HALL_H - 0.3, 0), true, -10.0, 14.0)
	# the way on: an EXIT sign over it (and two more, over nothing at all)
	for sg in [[Vector3(C2_X, 2.95, HALL_Z1 - 0.16), 180.0], [Vector3(HALL_X1 - 0.16, 2.4, -60.0), -90.0], [Vector3(HALL_X0 + 0.16, 2.4, -88.0), 90.0]]:
		if not prop("exit_sign", sg[0], sg[1]):
			part("box", sg[0], Vector3(0.36, 0.16, 0.04), Color(0.2, 1.0, 0.4), null, Vector3(0, sg[1], 0), 3.0)
		omni(sg[0] + Basis(Vector3.UP, deg_to_rad(sg[1])) * Vector3(0, -0.2, 0.4), Color(0.3, 1.0, 0.5), 0.35, 3.5, false)
	_hall_chairs()
	_hall_door()
	_hall_stairs()
	_hall_sky_wall()
	_hall_puddle()
	_hall_vending()
	_hall_phone()
	_hall_tv()


## A row of chairs facing the way you came in, as if for a meeting nobody came to.
func _hall_chairs() -> void:
	for k in 8:
		var p := Vector3(-12.0 + k * 1.5, 0, -104.0)
		var ch := prop("office_chair", p, 180.0)
		if ch == null:
			ch = group(p, 180.0)
			part("box", Vector3(0, 0.48, 0), Vector3(0.48, 0.07, 0.48), Color(0.12, 0.12, 0.14), ch)
			part("box", Vector3(0, 0.82, -0.22), Vector3(0.44, 0.55, 0.06), Color(0.12, 0.12, 0.14), ch)
		_chairs_row.append(ch)
		blocker(p + Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.55))
	interactable(Vector3(-6.75, 0.8, -104.0), Vector3(12.0, 1.2, 1.0),
		func(): return "The chairs",
		func():
			if _chairs_turned:
				Game.hud.show_thought("They were facing the door. ...They were. Now they're facing me.", 4.0)
			else:
				Game.hud.show_thought("Eight chairs in a row, facing the way I came in. Waiting for something.", 3.5))


## A door, in its frame, standing on its own in the middle of the floor.
func _hall_door() -> void:
	var p := LONE_DOOR
	box(p + Vector3(-0.56, 1.06, 0), Vector3(0.12, 2.16, 0.2), Color(0.85, 0.83, 0.76), true, 0.0, "wood")
	box(p + Vector3(0.56, 1.06, 0), Vector3(0.12, 2.16, 0.2), Color(0.85, 0.83, 0.76), true, 0.0, "wood")
	box(p + Vector3(0, 2.18, 0), Vector3(1.24, 0.12, 0.2), Color(0.85, 0.83, 0.76), true, 0.0, "wood")
	_lone_door = door(p, 180.0, Color(0.62, 0.5, 0.36), 0.92, 2.05)
	var shut := solid_box(p + Vector3(0, 1.03, 0), Vector3(0.96, 2.06, 0.08), Color(0, 0, 0, 0))
	shut.get_child(1).visible = false
	interactable(p + Vector3(0, 1.05, 0), Vector3(1.0, 2.0, 0.5),
		func(): return "Open the door" if not _lone_open else "",
		func():
			_lone_open = true
			shut.get_child(0).disabled = true
			Sfx.play_at("door_creak", self, p + Vector3(0, 1, 0), -4.0, 20.0)
			open_door(_lone_door, -95.0, 1.4)
			Game.hud.show_thought("...The hall. The same hall, on the other side. It's just a door.", 3.5),
		func(): return not _lone_open)
	# walk through it, and when you look back it has closed itself (it never makes a sound)
	trigger(p + Vector3(0, 1.0, 1.6), Vector3(3.0, 2.0, 1.0), func(): _lone_through = _lone_open, false)
	trigger(p + Vector3(0, 1.0, -1.6), Vector3(3.0, 2.0, 1.0), func(): _lone_through = _lone_open, false)
	set_meta("lone_shut", shut)


func _hall_stairs() -> void:
	# a staircase going up into the ceiling, and stopping there
	var base := Vector3(-20.0, 0, -79.0)
	var rise := HALL_H / 12.0
	for k in 12:
		var y := rise * (k + 1)
		box(base + Vector3(0, y * 0.5, k * 0.3 + 0.15), Vector3(1.3, y, 0.3), Color(0.55, 0.5, 0.42), true, 0.0, "wood")
		box(base + Vector3(0, y + 0.01, k * 0.3 + 0.02), Vector3(1.32, 0.02, 0.05), Color(0.35, 0.33, 0.3), false, 0.0, "metal")
	for side in [-1.0, 1.0]:
		var a := base + Vector3(side * 0.7, 0.95, 0.0)
		var b := base + Vector3(side * 0.7, HALL_H + 0.9, 3.6)
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var dir := (b - a).normalized()
		var bas := Basis(Vector3.RIGHT, -asin(dir.y)) * Basis.from_scale(Vector3(0.05, 0.05, len))
		add_shape("box", Transform3D(bas, mid), Color(0.3, 0.3, 0.32), false, "metal")
		for k in [0, 4, 8]:
			var q := base + Vector3(side * 0.7, rise * (k + 1), k * 0.3 + 0.15)
			box(q + Vector3(0, 0.47, 0), Vector3(0.04, 0.94, 0.04), Color(0.3, 0.3, 0.32), false, 0.0, "metal")
	trigger(base + Vector3(0, 2.0, 1.9), Vector3(1.3, 1.6, 1.0), func():
		Game.hud.show_thought("It just... stops. Into the ceiling tiles. Somebody built a staircase to nowhere.", 4.0))


func _hall_sky_wall() -> void:
	# a piece of wall, floor to ceiling, with two windows onto a summer sky. Behind it: the hall.
	var p := SKY_WALL
	box(p + Vector3(0, HALL_H * 0.5, 0), Vector3(7.0, HALL_H, 0.3), WALL_A, true, 0.0, "wallpaper")
	box(p + Vector3(0, 0.06, 0), Vector3(7.0, 0.12, 0.33), BASEBOARD, false)
	for wx in [-1.6, 1.6]:
		var c := p + Vector3(wx, 1.65, -0.16)
		part("box", c, Vector3(1.8, 1.4, 0.01), Color(0.5, 0.72, 0.98), null, Vector3.ZERO, 1.3)
		for k in 3:
			var cl := group(c + Vector3(-0.6 + k * 0.55, 0.15 + (k % 2) * 0.28, -0.004))
			part("sphere", Vector3.ZERO, Vector3(0.42, 0.13, 0.01), Color(1, 1, 1), cl, Vector3.ZERO, 1.6)
			part("sphere", Vector3(0.14, 0.04, 0), Vector3(0.26, 0.12, 0.01), Color(1, 1, 1), cl, Vector3.ZERO, 1.6)
			_clouds.append(cl)
		for fr in [[Vector3(0, 0.72, 0), Vector3(1.92, 0.06, 0.06)], [Vector3(0, -0.72, 0), Vector3(1.92, 0.06, 0.06)],
				[Vector3(-0.93, 0, 0), Vector3(0.06, 1.5, 0.06)], [Vector3(0.93, 0, 0), Vector3(0.06, 1.5, 0.06)], [Vector3(0, 0, 0), Vector3(0.04, 1.4, 0.05)]]:
			box(c + fr[0] + Vector3(0, 0, -0.02), fr[1], Color(0.92, 0.92, 0.9), false, 0.0, "wood")
		box(c + Vector3(0, -0.76, -0.08), Vector3(1.96, 0.04, 0.16), Color(0.92, 0.92, 0.9), false, 0.0, "wood")
	omni(p + Vector3(0, 1.6, -1.6), Color(0.75, 0.85, 1.0), 0.7, 7.0, false)
	ambient("wind", p + Vector3(0, 1.6, -0.5), true, -22.0, 9.0)
	interactable(p + Vector3(0, 1.6, -0.4), Vector3(6.0, 1.6, 0.5), func(): return "Look out of the window",
		func(): Game.hud.show_thought("Sky. A summer sky, clouds going over. ...I can hear the wind.", 3.5))
	trigger(p + Vector3(0, 1.2, 1.6), Vector3(7.0, 2.4, 2.0), func():
		Game.hud.show_thought("There's nothing behind it. Just wall. Just the hall. Where's the sky coming from?", 4.5))


func _hall_puddle() -> void:
	var p := PUDDLE
	if not prop("wet_floor_sign", p + Vector3(-2.6, 0, -1.4), 30.0):
		box(p + Vector3(-2.6, 0.3, -1.4), Vector3(0.3, 0.6, 0.3), Color(1.0, 0.85, 0.1), false)


func _hall_vending() -> void:
	var p := Vector3(50.0, 0, -94.0)
	_thing("vending_machine", p, -90.0, Vector3(0.9, 1.84, 0.8), Color(0.7, 0.15, 0.12))
	omni(p + Vector3(-1.0, 1.4, 0), Color(0.9, 0.95, 1.0), 0.6, 5.0, false)
	ambient("buzz", p + Vector3(0, 1.0, 0), true, -16.0, 10.0)
	var cable_a := p + Vector3(0.45, 0.02, 0.2)
	for k in 4:
		var a := cable_a + Vector3(0.6 * k + 0.3, 0, sin(k * 1.3) * 0.25)
		box(a, Vector3(0.62, 0.02, 0.02), Color(0.08, 0.08, 0.08), false, rad_to_deg(cos(k * 1.3) * 0.3))
	box(cable_a + Vector3(2.7, 0.03, 0.1), Vector3(0.08, 0.05, 0.05), Color(0.15, 0.15, 0.15), false)
	interactable(p + Vector3(-0.5, 1.0, 0), Vector3(0.4, 1.8, 1.0), func(): return "Vending machine",
		func(): Game.hud.show_thought("Every row is the same orange drink. ...It isn't plugged in. It's humming anyway.", 4.0))


func _hall_phone() -> void:
	if not prop("payphone", PHONE, 180.0):
		box(PHONE + Vector3(0, 1.4, -0.05), Vector3(0.36, 0.62, 0.16), Color(0.5, 0.5, 0.52), false, 0.0, "metal")
	interactable(PHONE + Vector3(0, 1.4, -0.2), Vector3(0.6, 0.8, 0.5),
		func(): return "Answer the phone" if _phone_state == 1 else "Payphone",
		func():
			if _phone_state == 1:
				_phone_state = 2
				Sfx.play("static_burst", -14.0)
				Game.hud.show_thought("...Children. A playground, far away, and a swing creaking. Somebody laughing. ...Then the dial tone.", 6.0)
			elif _phone_state == 2:
				Game.hud.show_thought("The cord's been cut. ...It was ringing.", 3.0)
			else:
				Game.hud.show_thought("A payphone, bolted to a pillar. No coins in the slot.", 2.5))


func _hall_tv() -> void:
	# a television on a desk, on, showing static
	var p := Vector3(-14.0, 0, -50.0)
	_thing("desk_wood", p, 160.0, Vector3(1.2, 0.76, 0.6), Color(0.5, 0.4, 0.3))
	var b := Basis(Vector3.UP, deg_to_rad(160.0))
	if not prop("tv_crt", p + Vector3(0, 0.76, 0), 160.0):
		box(p + Vector3(0, 1.0, 0), Vector3(0.5, 0.45, 0.45), Color(0.12, 0.11, 0.1), false, 160.0)
	_tv_screen = part("box", p + b * Vector3(0, 1.0, 0.235), Vector3(0.4, 0.3, 0.004), Color(0.6, 0.62, 0.65), null, Vector3(0, 160, 0))
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.6, 0.62, 0.65)
	tm.emission_enabled = true
	tm.emission = Color(0.7, 0.72, 0.76)
	tm.emission_energy_multiplier = 1.4
	_tv_screen.material_override = tm
	ambient("static", p + Vector3(0, 1.0, 0), true, -22.0, 9.0)
	omni(p + b * Vector3(0, 1.0, 0.8), Color(0.7, 0.75, 0.85), 0.4, 4.0, false)
	interactable(p + Vector3(0, 1.0, 0), Vector3(0.8, 0.6, 0.8), func(): return "The television",
		func():
			Game.hud.show_thought("Static. ...For a second - a bedroom. Mine. From up in a corner, like a camera. Someone asleep in my bed.", 5.0)
			Game.player.dread.add_fear(4.0, "the tv"))


# ---- the last corridor, and the way into the rooms

func _last_corridor() -> void:
	var x0 := C2_X - 1.1
	var x1 := C2_X + 1.1
	box(Vector3(C2_X, -0.05, (HALL_Z1 - 0.5 * CELL - 1.0) * 0.5), Vector3(2.2, 0.1, absf(HALL_Z1 - (-0.5 * CELL - 1.0))), CARPET, true, 0.0, "carpet")
	box(Vector3(C2_X, COR_H + 0.05, (HALL_Z1 - 0.5 * CELL - THICK * 0.5) * 0.5), Vector3(2.2, 0.1, absf(HALL_Z1 + 0.5 * CELL + THICK * 0.5)), CEILING, true, 0.0, "tiles_ceiling")
	for wx in [x0, x1]:
		_wall_run(Vector3(wx, 0, HALL_Z1 + 0.15), Vector3(wx, 0, -0.5 * CELL - THICK * 0.5), COR_H, [], WALL_A)
	_troffers(C2_X, C2_X, HALL_Z1 + 2.0, -6.0, 4.0, COR_H, func(p: Vector3): return absf(p.z - (-34.0)) < 0.6 or absf(p.z - (-18.0)) < 0.6)
	_walk_light(Vector3(C2_X, 0, -34.0), COR_H, 0.9, 10.0)
	var fpanel := part("box", Vector3(C2_X, COR_H - 0.02, -18.0), Vector3(1.2, 0.03, 0.6), PANEL, null, Vector3.ZERO, 3.0)
	var fl := omni(Vector3(C2_X, COR_H - 0.35, -18.0), LIGHT, 0.9, 10.0, false)
	_flicker.append([fl, fpanel, 0.9])
	ambient("buzz", Vector3(C2_X, COR_H - 0.3, -18.0), true, -8.0, 12.0)


func _entry() -> void:
	# the entry cell's south wall: a doorway as wide as the corridor
	var center := Vector3(ENTRY_CELL.x * CELL, 0, -0.5 * CELL)
	var length := CELL - PILLAR + 0.04
	var side_len := length * 0.5 - ENTRY_HALF
	for s in [-1.0, 1.0]:
		_wall(center + Vector3(s * (ENTRY_HALF + side_len * 0.5), 0, 0), false, side_len, WALL_A)
	box(center + Vector3(0, COR_H + (WALL_H - COR_H) * 0.5, 0), Vector3(ENTRY_HALF * 2.0, WALL_H - COR_H, THICK), WALL_A, true, 0.0, "wallpaper")
	# and the wall that won't be a doorway any more, once you're through
	_entry_wall = solid_box(center + Vector3(0, COR_H * 0.5, 0), Vector3(ENTRY_HALF * 2.0, COR_H, THICK), WALL_A, null, "wallpaper")
	part("box", Vector3(0, 0.06 - COR_H * 0.5, 0), Vector3(ENTRY_HALF * 2.0, 0.12, THICK + 0.03), BASEBOARD, _entry_wall)
	_entry_wall.visible = false
	_entry_wall.get_child(0).disabled = true


func _seal_entry() -> void:
	if _entry_sealed:
		return
	_entry_sealed = true
	_entry_wall.visible = true
	_entry_wall.get_child(0).disabled = false


func _update_way_in(delta: float) -> void:
	var pl: Player = Game.player
	if pl == null:
		return
	var p := pl.global_position
	# which part of the walk you're in: the hum gets louder the further in you go
	var sec := "rooms"
	if p.z < OFF_Z1:
		sec = "office"
	elif p.z < HALL_Z0:
		sec = "doors"
	elif p.z < HALL_Z1:
		sec = "hall"
	elif p.z < -0.5 * CELL:
		sec = "last"
	_section = sec
	var hum_to: float = {"office": -30.0, "doors": -24.0, "hall": -19.0, "last": -14.0, "rooms": -18.0}[sec]
	_hum_base = move_toward(_hum_base, hum_to, 4.0 * delta)
	# behind you, the doorway into the rooms closes up
	var door_at := Vector3(ENTRY_CELL.x * CELL, 1.3, -0.5 * CELL)
	if not _entry_sealed and _in_grid(p) and p.distance_to(door_at) > 5.0 and not Observation.is_observed(door_at, 1.2):
		_seal_entry()
	if _entry_sealed and not _seal_noticed and p.distance_to(door_at) < 12.0 and Observation.is_observed(door_at, 0.6) and not _chase_on and not _hunting:
		_seal_noticed = true
		Game.hud.show_thought("The doorway. ...It was right there. I came in through there.", 4.0)
		pl.dread.add_fear(5.0, "no way back")
	# the radio: playing whatever Sfx calls muzak, quietly, until you turn it off (and then, later, again)
	if _radio:
		if not _radio.playing and _radio_off_t < 0.0 and Sfx.music.has("muzak"):
			_radio.stream = Sfx.music["muzak"]
			_radio.play()
		if _radio_off_t >= 0.0:
			_radio_off_t += delta
			if _radio_off_t > 20.0 and _radio.global_position.distance_to(p) > 9.0:
				_radio_off_t = -2.0
				_radio.volume_db = -9.0
				_radio.play()
	# the desk phone rings once you've had a moment to look around; the payphone, when you're halfway across
	if _desk_state == 0 and _t > 22.0 and sec == "office":
		_desk_state = 1
		_desk_t = 0.0
	if _desk_state == 1:
		_desk_t -= delta
		if _desk_t <= 0.0:
			_desk_t = 3.2
			Sfx.play_at("ring", self, _desk_phone + Vector3(0, 0.1, 0), -2.0, 30.0)
		if sec != "office":
			_desk_state = 3      # (gone quiet behind you)
	if _phone_state == 0 and sec == "hall" and p.z > -84.0:
		_phone_state = 1
		_phone_t = 0.0
	if _phone_state == 1:
		_phone_t -= delta
		if _phone_t <= 0.0:
			_phone_t = 3.2
			Sfx.play_at("ring", self, PHONE + Vector3(0, 1.4, -0.2), 2.0, 60.0, 0.94)
		if sec == "last" or sec == "rooms":
			_phone_state = 3
	# drips, into the wet patch
	if sec == "hall" and p.distance_to(PUDDLE) < 26.0:
		_drip_t -= delta
		if _drip_t <= 0.0:
			_drip_t = randf_range(1.4, 4.0)
			Sfx.play_at("drip", self, PUDDLE + Vector3(randf_range(-0.6, 0.6), 0.05, randf_range(-0.4, 0.4)), -6.0, 22.0)
	# the clouds in the window go over
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += delta * 0.04
		var home := SKY_WALL.x + (-1.6 if i < 3 else 1.6)
		if c.position.x > home + 0.75:
			c.position.x = home - 0.75
	# the static on the TV
	if _tv_screen and sec == "hall" and Engine.get_frames_drawn() % 3 == 0:
		(_tv_screen.material_override as StandardMaterial3D).emission_energy_multiplier = randf_range(0.7, 1.8)
	# the door that closes itself behind you
	if _lone_through and _lone_open and not Observation.is_observed(LONE_DOOR + Vector3(0, 1.0, 0), 1.0) and p.distance_to(LONE_DOOR) > 3.0:
		_lone_open = false
		_lone_through = false
		open_door(_lone_door, 0.0, 0.01)
		var shut: StaticBody3D = get_meta("lone_shut")
		shut.get_child(0).disabled = false
	# the tubes that won't settle
	_flick_t -= delta
	for f in _flicker:
		if _flick_t <= 0.0:
			var on := 1.0 if randf() < 0.6 else randf_range(0.0, 0.5)
			(f[0] as OmniLight3D).light_energy = float(f[2]) * lerpf(1.0, on, clampf(Settings.visual(), 0.0, 1.0))
	if _flick_t <= 0.0:
		_flick_t = randf_range(0.05, 0.6)


func surface_at(p: Vector3) -> String:
	if Vector2(p.x - PUDDLE.x, p.z - PUDDLE.z).length() < 1.4:
		return "wet"
	return floor_surface()


func saved_checkpoint() -> Variant:
	# the chase keeps its own checkpoint (where it began)
	if Game.has_flag("maze_chase") and not Game.has_flag("maze_escaped") and not (Game.counters.get("chase", {}) as Dictionary).is_empty():
		return null
	return super()


# ------------------------------------------------------------------ stains
# The carpet and the ceiling tiles are clean textures; the damp is laid over them, patch by patch, so it never
# repeats: coffee rings in the office, tide lines on the ceiling of the hall, and the rooms, soaked.

static var _stain_tex: ImageTexture
var _stain_lists := {}      # "floor"/"ceiling"/"wet" -> [[Transform3D, Color], ...]


static func _stain_texture() -> ImageTexture:
	if _stain_tex:
		return _stain_tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	for y in n:
		for x in n:
			var dx := (x - n * 0.5) / (n * 0.5)
			var dy := (y - n * 0.5) / (n * 0.5)
			var r := sqrt(dx * dx + dy * dy)
			var v := 0.85 - r + noise.get_noise_2d(x, y) * 0.6
			var inside := clampf(v / 0.3, 0.0, 1.0)
			var rim := clampf(1.0 - absf(v - 0.03) / 0.045, 0.0, 1.0) * 0.45      # the tide line, where it dried
			var a := clampf(inside * 0.6 + rim, 0.0, 1.0) * clampf((1.0 - r) / 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_stain_tex = ImageTexture.create_from_image(img)
	return _stain_tex


func _stain(kind: String, at: Vector3, size: float, col: Color, rng: RandomNumberGenerator) -> void:
	var sc := Vector3(size * rng.randf_range(0.7, 1.3), 1.0, size * rng.randf_range(0.7, 1.3))
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sc)
	if kind == "ceiling":
		b = Basis(Vector3.RIGHT, PI) * b
	if not _stain_lists.has(kind):
		_stain_lists[kind] = []
	_stain_lists[kind].append([Transform3D(b, at), col])


## A scatter of stains over a rectangle of floor (y = 0) or ceiling (y = h).
func _stains_in(x0: float, x1: float, z0: float, z1: float, h: float, floor_n: int, ceil_n: int, floor_size: Vector2,
		ceil_size: Vector2, rng: RandomNumberGenerator, floor_col := Color(0.2, 0.16, 0.08, 0.5)) -> void:
	for k in floor_n:
		_stain("floor", Vector3(rng.randf_range(x0, x1), 0.004 + k * 0.00002, rng.randf_range(z0, z1)), rng.randf_range(floor_size.x, floor_size.y),
			Color(floor_col, floor_col.a * rng.randf_range(0.5, 1.0)), rng)
	for k in ceil_n:
		_stain("ceiling", Vector3(rng.randf_range(x0, x1), h - 0.004 - k * 0.00002, rng.randf_range(z0, z1)), rng.randf_range(ceil_size.x, ceil_size.y),
			Color(0.42, 0.33, 0.14, rng.randf_range(0.3, 0.6)), rng)


func _stains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1777
	# the office: coffee, here and there, and one or two on the ceiling
	_stains_in(OFF_X0 + 1, OFF_X1 - 1, OFF_Z0 + 1, OFF_Z1 - 1, OFF_H, 10, 3, Vector2(0.15, 0.45), Vector2(0.5, 1.1), rng, Color(0.18, 0.12, 0.06, 0.45))
	_stains_in(C1_X - 1.0, C1_X + 1.0, OFF_Z1 + 1, HALL_Z0 - 1, COR_H, 5, 2, Vector2(0.4, 1.0), Vector2(0.4, 0.9), rng)
	_stains_in(HALL_X0 + 1, HALL_X1 - 1, HALL_Z0 + 1, HALL_Z1 - 1, HALL_H, 55, 34, Vector2(0.8, 3.2), Vector2(0.7, 2.6), rng)
	_stains_in(C2_X - 0.9, C2_X + 0.9, HALL_Z1 + 1, -4.5, COR_H, 7, 5, Vector2(0.6, 1.6), Vector2(0.5, 1.2), rng)
	_stains_in(-0.5 * CELL, (W - 0.5) * CELL, -0.5 * CELL, (H - 0.5) * CELL, WALL_H, 170, 120, Vector2(0.8, 3.4), Vector2(0.6, 2.4), rng, Color(0.22, 0.17, 0.07, 0.55))
	# the wet patch in the hall: soaked through, and shining
	for k in 5:
		_stain("floor", PUDDLE + Vector3(rng.randf_range(-1.2, 1.2), 0.0045 + k * 0.00002, rng.randf_range(-0.8, 0.8)), rng.randf_range(1.6, 2.8), Color(0.12, 0.09, 0.03, 0.75), rng)
	_stain("wet", PUDDLE + Vector3(0.3, 0.006, 0.2), 1.9, Color(0.1, 0.09, 0.06, 0.85), rng)
	_stain("wet", PUDDLE + Vector3(-0.5, 0.0062, -0.3), 1.1, Color(0.1, 0.09, 0.06, 0.8), rng)
	for k in 3:
		_stain("ceiling", PUDDLE + Vector3(rng.randf_range(-0.8, 0.8), HALL_H - 0.005 - k * 0.00002, rng.randf_range(-0.6, 0.6)), rng.randf_range(1.5, 2.8), Color(0.38, 0.28, 0.1, 0.7), rng)
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	for kind in _stain_lists:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _stain_texture()
		m.roughness = 0.08 if kind == "wet" else 0.95
		if kind == "wet":
			m.metallic_specular = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var cells := {}
		for it in _stain_lists[kind]:
			var o: Vector3 = (it[0] as Transform3D).origin
			var key := Vector2i(floori(o.x / 40.0), floori(o.z / 40.0))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(it)
		for key in cells:
			var list: Array = cells[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = quad
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i][0])
				mm.set_instance_color(i, list[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = m
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 70.0
			mmi.visibility_range_end_margin = 10.0
			add_child(mmi)
	_stain_lists.clear()



# ------------------------------------------------------------------ the way back
# No chase. With the power on, the rooms are red and wrong - walls moved, two doorways leading elsewhere - and
# a trail of dim red lamps and EXIT signs leads back to the lift. Whatever was behind the glass stays there.

var _way_on := false
var _watching := false
var _way_path: Array[Vector2i] = []
var _way_lights: Array = []        # [light, phase]
var _lift_called := false


func _way_back() -> void:
	_way_on = true
	_seal_entry()
	var start := cell_at(Game.player.global_position)
	_way_path = _route_cells(start, Vector2i(0, 0))
	# the way stays open: any shifting wall on it is open, and stays so
	for i in _way_path.size() - 1:
		var mid := (cell_center(_way_path[i].x, _way_path[i].y) + cell_center(_way_path[i + 1].x, _way_path[i + 1].y)) * 0.5
		for w in _dynamic:
			if Vector2(w.center.x - mid.x, w.center.z - mid.z).length() < 0.01 and not w.open:
				_set_dynamic(w, true)
	for i in _way_path.size():
		var l := _red_light(_way_path[i])
		l.visible = true
		l.light_energy = 1.6
		_way_lights.append([l, randf() * TAU])
	for i in range(1, _way_path.size() - 1):
		var din := _way_path[i] - _way_path[i - 1]
		var dout := _way_path[i + 1] - _way_path[i]
		if din != dout or i % 4 == 0:
			_exit_sign(_way_path[i], din, signi(din.x * dout.y - din.y * dout.x))
	if _env:
		var tw := create_tween().set_parallel()
		tw.tween_property(_env, "ambient_light_color", Color(0.7, 0.3, 0.22), 2.0)
		tw.tween_property(_env, "fog_light_color", Color(0.35, 0.1, 0.06), 2.0)
	Sfx.play("metal_screech", -10.0, 0.5)
	Game.hud.show_thought("Red. All of it. ...And EXIT signs, leading off. Back to the lift.", 3.5)


func _update_way_back(delta: float) -> void:
	# the red lamps breathe, slowly, out of step with each other
	for wl in _way_lights:
		wl[1] += delta * 1.3
		(wl[0] as OmniLight3D).light_energy = 1.2 + 0.5 * sin(wl[1])
	if not _lift_called and cell_at(Game.player.global_position) == Vector2i(0, 0):
		_lift_called = true
		_lift_arrives()
