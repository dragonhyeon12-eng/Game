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

const WALL_A := Color(0.78, 0.68, 0.33)
const WALL_B := Color(0.74, 0.65, 0.3)
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
	_register_anomalies()
	_hum = ambient("hum", Vector3.ZERO, false, -18.0)
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.position = Vector3(0, -100, 0)
	observer.seen_threshold = 0.35
	observer.seen_max_distance = 40.0
	observer.seen.connect(_on_observer_seen)


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

	for d in 4:
		if _get_edge(0, 0, d) == Edge.OPEN:
			# yaw so the camera's -Z faces direction d
			var dir := Vector3(DX[d], 0, DZ[d])
			_start_yaw = atan2(-dir.x, -dir.z)
			break


func _wall(center: Vector3, along_z: bool, length: float, color: Color) -> void:
	var size := Vector3(THICK, WALL_H, length) if along_z else Vector3(length, WALL_H, THICK)
	box(center + Vector3(0, WALL_H * 0.5, 0), size, color)
	var base := Vector3(THICK + 0.03, 0.12, length) if along_z else Vector3(length, 0.12, THICK + 0.03)
	box(center + Vector3(0, 0.06, 0), base, BASEBOARD, false)


func _geometry() -> void:
	var mid := Vector3((W - 1) * CELL * 0.5, 0, (H - 1) * CELL * 0.5)
	var ext := Vector3(W * CELL + 2, 0.1, H * CELL + 2)
	box(mid + Vector3(0, -0.05, 0), ext, CARPET, true, 0.0, 1.0)
	box(mid + Vector3(0, WALL_H + 0.05, 0), ext, CEILING)
	for x in W + 1:
		box(Vector3((x - 0.5) * CELL, WALL_H - 0.012, mid.z), Vector3(0.04, 0.02, H * CELL), CEILING.darkened(0.2), false)
	for z in H + 1:
		box(Vector3(mid.x, WALL_H - 0.02, (z - 0.5) * CELL), Vector3(W * CELL, 0.02, 0.04), CEILING.darkened(0.2), false)
	# A pillar at every wall junction. Walls end *inside* the pillars, so no two faces ever share a plane
	# (coplanar faces flicker - "z-fighting").
	for x in W + 1:
		for z in H + 1:
			box(Vector3((x - 0.5) * CELL, WALL_H * 0.5, (z - 0.5) * CELL), Vector3(PILLAR, WALL_H, PILLAR), WALL_A)

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
					var body := solid_box(center + Vector3(0, WALL_H * 0.5, 0), size, col)
					var w := {"body": body, "center": center, "open": false}
					_dynamic.append(w)
					_set_dynamic(w, rng.randf() < 0.5)

	for x in W:
		_wall(Vector3(x * CELL, 0, -0.5 * CELL), false, length, WALL_A)
		if not (_exit_dir == 2 and _exit_cell.x == x):
			_wall(Vector3(x * CELL, 0, (H - 0.5) * CELL), false, length, WALL_A)
	for z in H:
		_wall(Vector3(-0.5 * CELL, 0, z * CELL), true, length, WALL_A)
		if not (_exit_dir == 0 and _exit_cell.y == z):
			_wall(Vector3((W - 0.5) * CELL, 0, z * CELL), true, length, WALL_A)

	var env := make_env(Color(0.9, 0.82, 0.55), 0.25)
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
		var p := cell_center(c.x, c.y) + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
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
	box(center - inward * 0.06 + Vector3(0, 1.09, 0), Vector3(0.08, 2.18, 1.16) if along_z else Vector3(1.16, 2.18, 0.08), Color(0.5, 0.38, 0.25))
	shape_at("sphere", center + inward * 0.02 + along * 0.4 + Vector3(0, 1.0, 0), Vector3.ONE * 0.06, Color(0.75, 0.7, 0.5))
	# EXIT sign above it
	var sign_pos := center + inward * (THICK * 0.5 + 0.04) + Vector3(0, 2.5, 0)
	part("box", sign_pos, Vector3(0.06, 0.24, 0.64) if along_z else Vector3(0.64, 0.24, 0.06), Color(0.6, 0.05, 0.04), null, Vector3.ZERO, 1.5)
	var yaw := rad_to_deg(atan2(inward.x, inward.z))
	label(sign_pos + inward * 0.035, yaw, "EXIT", 0.18, Color(1.0, 0.95, 0.9))
	omni(sign_pos + inward * 0.3, Color(1.0, 0.2, 0.15), 0.5, 3.0, false)
	# the loudest hum in the building
	ambient("hum", center + inward * 0.4 + Vector3(0, 2.0, 0), true, 4.0, 38.0)
	interactable(center - inward * 0.02 + Vector3(0, 1.1, 0), Vector3(0.3, 2.1, 1.16) if along_z else Vector3(1.16, 2.1, 0.3),
		func(): return "Open the door", func(): Game.on_maze_exit())


func player_start() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _start_yaw), cell_center(0, 0) + Vector3(0, 0.05, 0))


# ------------------------------------------------------------------ anomalies

func _register_anomalies() -> void:
	# walls that come and go (never part of the spanning tree: the maze stays solvable)
	for w in _dynamic:
		Anomalies.register({"id": "wall", "owner": self, "position": w.center + Vector3(0, WALL_H * 0.5, 0), "radius": 2.6,
			"min_unobserved": 2.5, "discovery_fear": 3.0,
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
	Game.player.dread.add_fear(12.0 if _sightings == 1 else 7.0, "observer seen")
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
		# once seen he is gone the moment you look away; if never seen, he leaves eventually
		if (_obs_seen_now and observer.unobserved_time > 0.4) or (_obs_present > 18.0 and not observer.observed):
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
