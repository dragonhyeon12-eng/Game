class_name ShiftZone
extends Zone
## PROTOTYPE (work in progress) - THE SHIFT. A test bed for the randomness mechanic: the dream lets go
## of whatever you aren't looking at, and after a while it makes something new in its place.
##
## The map is a grid of SEGMENTS (rooms, S metres square) with EDGES between them (a wall, a doorway or
## nothing). Each segment remembers when it was last seen. While nobody looks at it, it DISSIPATES in
## stages: the small things go, then the light and the colour, then the furniture, until it is a bare grey
## shell. After long enough ignored, it REBUILDS: a new kind of room, new furniture, a new floor.
## Edges between rooms nobody is looking at open, close and move - but the map always stays connected
## (a door only closes if every room can still be reached). The EXIT moves too, if you leave it alone.
##
## Rules that keep it fair:
##  - nothing changes while it can be seen (re-checked at the moment of the change, not from a cache);
##  - the room you stand in counts as seen; nothing changes within reach of you;
##  - the floor under you is never touched.
##
## Debug: a map in the corner (F3 hides it) - grey = intact, yellow / orange / red = dissipating,
## blue flash = rebuilt, white outline = seen right now. `speed` runs the clocks faster (tests).

const N := 6                 # segments per side
const S := 8.0               # segment size (m)
const H := 3.0               # wall height
const T := 0.2               # wall thickness
const DOOR_W := 1.5
const DOOR_H := 2.25
const POST := 0.3
## Seconds unseen before each dissipation stage, and before a rebuild.
const STAGE_T := [7.0, 14.0, 21.0]
const REBUILD_T := 28.0
const EDGE_UNSEEN_T := 9.0   # both rooms unseen this long before the wall between them may change
const EDGE_EVERY := 1.2      # at most one wall change this often
const EXIT_T := 35.0
const WALL := Color(0.6, 0.58, 0.53)

const WALL_NONE := 2
const WALL_DOOR := 1
const WALL_SOLID := 0

## Kinds of room: floor surface + colour, lamp colour, what's in the corners.
const THEMES := {
	"office":   {"floor": "carpet", "col": Color(0.35, 0.38, 0.42), "lamp": Color(0.85, 0.92, 1.0)},
	"bedroom":  {"floor": "wood", "col": Color(0.5, 0.36, 0.25), "lamp": Color(1.0, 0.8, 0.55)},
	"storage":  {"floor": "concrete", "col": Color(0.45, 0.44, 0.41), "lamp": Color(1.0, 0.95, 0.8)},
	"lounge":   {"floor": "carpet", "col": Color(0.42, 0.22, 0.2), "lamp": Color(1.0, 0.75, 0.5)},
	"kitchen":  {"floor": "tiles_floor", "col": Color(0.7, 0.72, 0.7), "lamp": Color(0.95, 1.0, 0.95)},
	"bare":     {"floor": "concrete", "col": Color(0.38, 0.37, 0.35), "lamp": Color(0.9, 0.9, 1.0)},
}
const NOTICE := ["...Wasn't there something here?", "This room was different. I'm sure it was.",
	"It goes grey when I don't look at it.", "It's rebuilding itself. Behind my back.",
	"I came through a door. Where's the door?"]

var speed := 1.0
var debug_map := true
var stats := {"rebuilds": 0, "stages": 0, "edge_changes": 0, "exit_moves": 0, "violations": 0, "noticed": 0}

var _segs: Array = []         # [r][c] -> Dictionary (see _make_seg)
var _edges := {}              # Vector3i(c, r, d) -> {"state", "node", "changed_at"}  d: 0 = east, 1 = south
var _now := 0.0
var _check := 0
var _edge_t := 0.0
var _exit_seg := Vector2i(-1, -1)
var _exit_node: Node3D
var _leaving := false
var _rng := RandomNumberGenerator.new()
var _map: ShiftMap
var _layer: CanvasLayer


func zone_id() -> String: return "shifting"
func floor_surface() -> String: return "carpet"
func walk_speed() -> float: return 2.8
func sprint_speed() -> float: return 4.6


func player_start() -> Transform3D:
	return Transform3D(Basis(), center(0, 0) + Vector3(0, 0.05, 0))


static func center(c: int, r: int) -> Vector3:
	return Vector3((c - N * 0.5 + 0.5) * S, 0, (r - N * 0.5 + 0.5) * S)


func seg_at(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(p.x / S + N * 0.5), 0, N - 1), clampi(floori(p.z / S + N * 0.5), 0, N - 1))


# ------------------------------------------------------------------ build

func build() -> void:
	_rng.randomize()
	var half := N * S * 0.5
	# the outside: fixed walls round the whole grid, and posts where the walls meet
	for side in 4:
		var horiz := side < 2
		var off := (-half - T * 0.5) if side % 2 == 0 else (half + T * 0.5)
		var pos := Vector3(0, H * 0.5, off) if horiz else Vector3(off, H * 0.5, 0)
		var size := Vector3(N * S + T * 2.0, H, T) if horiz else Vector3(T, H, N * S + T * 2.0)
		box(pos, size, WALL.darkened(0.1), true, 0.0, "plaster")
	for i in N + 1:
		for j in N + 1:
			box(Vector3(-half + i * S, H * 0.5, -half + j * S), Vector3(POST, H, POST), WALL.darkened(0.15), true, 0.0, "plaster")
	box(Vector3(0, H + 0.15, 0), Vector3(N * S + 1.0, 0.1, N * S + 1.0), Color(0.2, 0.2, 0.2), false)   # a roof over it all
	# the rooms
	for r in N:
		var row := []
		for c in N:
			row.append(_make_seg(c, r, THEMES.keys()[_rng.randi() % THEMES.size()]))
		_segs.append(row)
	# the walls between them: a maze (every room reachable), then some extra openings
	for r in N:
		for c in N:
			if c < N - 1:
				_edges[Vector3i(c, r, 0)] = {"state": WALL_SOLID, "node": null, "changed_at": -99.0}
			if r < N - 1:
				_edges[Vector3i(c, r, 1)] = {"state": WALL_SOLID, "node": null, "changed_at": -99.0}
	_carve_maze()
	for k in _edges:
		if _edges[k].state == WALL_SOLID and _rng.randf() < 0.22:
			_edges[k].state = WALL_DOOR if _rng.randf() < 0.7 else WALL_NONE
		_build_edge(k)
	_place_exit(Vector2i(0, 0))

	var env := make_env(Color(0.3, 0.3, 0.32), 0.25)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.08, 0.09)
	env.fog_density = 0.035
	environment(env)
	ambient("room_tone", Vector3.ZERO, false, -12.0)
	ambient("hum", Vector3.ZERO, false, -26.0)

	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_map = ShiftMap.new()
	_map.zone = self
	_layer.add_child(_map)


func _carve_maze() -> void:
	var seen := {Vector2i(0, 0): true}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var opts: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x >= 0 and nb.y >= 0 and nb.x < N and nb.y < N and not seen.has(nb):
				opts.append(nb)
		if opts.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = opts[_rng.randi() % opts.size()]
		_edges[_edge_key(cur, nxt)].state = WALL_DOOR
		seen[nxt] = true
		stack.append(nxt)


static func _edge_key(a: Vector2i, b: Vector2i) -> Vector3i:
	if a.y == b.y:
		return Vector3i(mini(a.x, b.x), a.y, 0)
	return Vector3i(a.x, mini(a.y, b.y), 1)


## The two rooms on either side of an edge.
static func _edge_segs(k: Vector3i) -> Array[Vector2i]:
	return [Vector2i(k.x, k.y), Vector2i(k.x + 1, k.y) if k.z == 0 else Vector2i(k.x, k.y + 1)]


static func edge_mid(k: Vector3i) -> Vector3:
	return center(k.x, k.y) + (Vector3(S * 0.5, 0, 0) if k.z == 0 else Vector3(0, 0, S * 0.5))


func edge_state(k: Vector3i) -> int:
	return _edges[k].state if _edges.has(k) else WALL_SOLID


# ------------------------------------------------------------------ segments

func _make_seg(c: int, r: int, theme: String) -> Dictionary:
	var root := Node3D.new()
	root.position = center(c, r)
	add_child(root)
	var th: Dictionary = THEMES[theme]
	var seg := {"c": c, "r": r, "root": root, "theme": theme, "gen": 0, "stage": 0, "last_seen": _now,
		"seen": false, "changed": false, "loose": [], "furniture": [], "bodies": [], "lamp": null,
		"floor": null, "rebuilt_at": -99.0, "pace": _rng.randf_range(0.7, 1.45)}   # (each room lets go at its own pace)
	var fl := solid_box(Vector3(0, -0.1, 0), Vector3(S, 0.2, S), th.col, root, th.floor)
	seg.floor = fl
	seg.bodies.append(fl)
	part("box", Vector3(0, H + 0.04, 0), Vector3(S, 0.08, S), Color(0.75, 0.74, 0.7), root, Vector3.ZERO, 0.0, "plaster")
	# one lamp: a ceiling fitting and its light
	part("box", Vector3(0, H - 0.02, 0), Vector3(1.2, 0.04, 0.25), Color(1, 1, 1), root, Vector3.ZERO, 1.5)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, H - 0.4, 0)
	lamp.light_color = th.lamp
	lamp.light_energy = 0.9
	lamp.omni_range = S * 0.85
	lamp.omni_attenuation = 1.1
	lamp.shadow_enabled = false
	_fade_with_distance(lamp, lamp.omni_range)
	root.add_child(lamp)
	seg.lamp = lamp
	_furnish(seg)
	return seg


## Furniture in the four corners (the cross through the middle, from doorway to doorway, stays clear).
func _furnish(seg: Dictionary) -> void:
	var root: Node3D = seg.root
	var theme: String = seg.theme
	for q in 4:
		var sx := -1.0 if q % 2 == 0 else 1.0
		var sz := -1.0 if q < 2 else 1.0
		var at := Vector3(sx * 2.6, 0, sz * 2.6)
		if _rng.randf() < 0.2:
			continue
		var yaw := 90.0 * (_rng.randi() % 4)
		match theme:
			"office":
				if _rng.randf() < 0.6:
					_solid(seg, at + Vector3(0, 0.38, 0), Vector3(1.6, 0.76, 0.8), Color(0.45, 0.33, 0.22), yaw, "wood")   # desk
					_loose(seg, "box", at + Vector3(0, 0.95, 0), Vector3(0.5, 0.35, 0.05), Color(0.1, 0.1, 0.12), yaw)   # monitor
					_loose(seg, "box", at + Vector3(0.45, 0.77, 0.1), Vector3(0.3, 0.01, 0.22), Color(0.95, 0.95, 0.9), yaw + 12.0)  # papers
					_loose(seg, "cylinder", at + Vector3(-0.55, 0.82, 0.15), Vector3(0.08, 0.11, 0.08), Color(0.8, 0.2, 0.15), 0.0)  # mug
				else:
					_solid(seg, at + Vector3(0, 0.65, 0), Vector3(0.55, 1.3, 0.65), Color(0.5, 0.52, 0.55), yaw, "metal")   # filing cabinet
					_loose(seg, "box", at + Vector3(0, 1.36, 0), Vector3(0.3, 0.12, 0.25), Color(0.75, 0.7, 0.5), 20.0)   # a box file
			"bedroom":
				if _rng.randf() < 0.5:
					_solid(seg, at + Vector3(0, 0.25, 0), Vector3(1.1, 0.5, 1.95), Color(0.85, 0.85, 0.82), yaw, "fabric")   # bed
					_loose(seg, "box", at + Vector3(0, 0.58, 0), Vector3(0.6, 0.12, 0.35), Color(0.95, 0.95, 0.95), yaw)    # pillow
				else:
					_solid(seg, at + Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.2), yaw, "wood")   # wardrobe
				_loose(seg, "cylinder", at + Vector3(0.9, 0.3, 0.9), Vector3(0.25, 0.6, 0.25), Color(0.7, 0.6, 0.45), 0.0)   # lamp
			"storage":
				_solid(seg, at + Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 0.5), Color(0.4, 0.42, 0.44), yaw, "metal")   # shelving
				for k in _rng.randi_range(2, 4):
					_loose(seg, "box", at + Vector3(_rng.randf_range(-0.7, 0.7), 0.25 + (k % 3) * 0.7, _rng.randf_range(-0.6, 0.6)),
						Vector3.ONE * _rng.randf_range(0.25, 0.45), Color(0.6, 0.48, 0.3), _rng.randf() * 360.0)    # boxes
			"lounge":
				if _rng.randf() < 0.6:
					_solid(seg, at + Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 0.85), Color(0.3, 0.32, 0.4), yaw, "fabric")   # sofa
					_loose(seg, "box", at + Vector3(0.5, 0.86, 0), Vector3(0.4, 0.35, 0.12), Color(0.7, 0.55, 0.3), yaw)  # cushion
				else:
					_loose(seg, "cylinder", at + Vector3(0, 0.25, 0), Vector3(0.35, 0.5, 0.35), Color(0.45, 0.3, 0.2), 0.0)   # plant pot
					_loose(seg, "sphere", at + Vector3(0, 0.85, 0), Vector3(0.7, 0.8, 0.7), Color(0.2, 0.45, 0.2), 0.0)       # plant
			"kitchen":
				_solid(seg, at + Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.6), Color(0.85, 0.85, 0.82), yaw, "plaster")   # counter
				for k in 3:
					_loose(seg, "cylinder", at + Vector3(-0.6 + k * 0.6, 0.92, 0), Vector3(0.24, 0.02, 0.24), Color(0.95, 0.95, 0.95), 0.0)  # plates
			"bare":
				if q == 0:
					_solid(seg, at + Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45), Color(0.35, 0.25, 0.2), _rng.randf() * 360.0, "wood")   # one chair
	if theme != "bare" and _rng.randf() < 0.6:
		_loose(seg, "box", Vector3(0, 0.01, 0), Vector3(2.4, 0.01, 1.6), (THEMES[theme].col as Color).lightened(0.25), 0.0)   # a rug


func _solid(seg: Dictionary, pos: Vector3, size: Vector3, col: Color, yaw: float, surf: String) -> void:
	var b := solid_box(pos, size, col, seg.root, surf)
	b.rotation_degrees.y = yaw
	seg.furniture.append(b)
	seg.bodies.append(b)


func _loose(seg: Dictionary, kind: String, pos: Vector3, size: Vector3, col: Color, yaw: float) -> void:
	var m := part(kind, pos, size, col, seg.root, Vector3(0, yaw, 0))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seg.loose.append(m)


## Is any of the room in view? A 3x3 grid of points through it, each in view and not behind a wall.
func seg_visible(seg: Dictionary) -> bool:
	var pl: Player = Game.player
	if pl == null:
		return true
	var p := pl.global_position
	var c := center(seg.c, seg.r)
	if absf(p.x - c.x) < S * 0.5 + 1.5 and absf(p.z - c.z) < S * 0.5 + 1.5:
		return true      # you're in it (or in its doorway)
	var ex: Array = seg.bodies
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			for y in [0.4, 1.6]:
				if Observation.is_observed(c + Vector3(i * 2.8, y, j * 2.8), 0.9, ex):
					return true
	return false


func _set_stage(seg: Dictionary, stage: int) -> void:
	if seg_visible(seg):
		return
	seg.stage = stage
	seg.changed = true
	stats.stages += 1
	match stage:
		1:   # the small things go first
			var keep := []
			for m in seg.loose:
				if _rng.randf() < 0.5:
					m.queue_free()
				else:
					keep.append(m)
			seg.loose = keep
		2:   # then all of them, and the light, and the colour
			for m in seg.loose:
				m.queue_free()
			seg.loose = []
			(seg.lamp as OmniLight3D).light_energy = 0.35
			(seg.lamp as OmniLight3D).light_color = Color(0.75, 0.75, 0.78)
			var fl: StaticBody3D = seg.floor
			(fl.get_child(1) as MeshInstance3D).material_override = Shapes.surface("concrete", Color(0.32, 0.32, 0.32))
		3:   # then the furniture. a bare grey shell
			for b in seg.furniture:
				seg.bodies.erase(b)
				b.queue_free()
			seg.furniture = []
			(seg.lamp as OmniLight3D).light_energy = 0.12


func _rebuild(seg: Dictionary) -> void:
	if seg_visible(seg):
		return
	var themes: Array = THEMES.keys()
	themes.erase(seg.theme)
	var fresh := _make_seg(seg.c, seg.r, themes[_rng.randi() % themes.size()])
	fresh.gen = seg.gen + 1
	fresh.changed = true
	fresh.rebuilt_at = _now
	(seg.root as Node3D).queue_free()
	_segs[seg.r][seg.c] = fresh
	stats.rebuilds += 1


# ------------------------------------------------------------------ edges

func _build_edge(k: Vector3i) -> void:
	var e: Dictionary = _edges[k]
	if e.node != null:
		(e.node as Node3D).queue_free()
	var g := Node3D.new()
	g.position = edge_mid(k)
	if k.z == 1:
		g.rotation.y = PI * 0.5        # a south edge runs along x
	add_child(g)
	e.node = g
	var L := S - POST
	match int(e.state):
		WALL_SOLID:
			solid_box(Vector3(0, H * 0.5, 0), Vector3(T, H, L), WALL, g, "plaster")
		WALL_DOOR:
			var side := (L - DOOR_W) * 0.5
			for s in [-1.0, 1.0]:
				solid_box(Vector3(0, H * 0.5, s * (DOOR_W * 0.5 + side * 0.5)), Vector3(T, H, side), WALL, g, "plaster")
			solid_box(Vector3(0, (DOOR_H + H) * 0.5, 0), Vector3(T, H - DOOR_H, DOOR_W), WALL, g, "plaster")
			part("box", Vector3(0, 0.005, 0), Vector3(T + 0.02, 0.01, DOOR_W), Color(0.3, 0.27, 0.24), g)   # threshold


func _edge_bodies(k: Vector3i) -> Array:
	var out := []
	var n: Node3D = _edges[k].node
	if n:
		for ch in n.get_children():
			if ch is StaticBody3D:
				out.append(ch)
	return out


## Can every room still be reached if edge k becomes `state`?
func _connected_with(k: Vector3i, state: int) -> bool:
	var old: int = _edges[k].state
	_edges[k].state = state
	var seen := {Vector2i(0, 0): true}
	var q: Array[Vector2i] = [Vector2i(0, 0)]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.y < 0 or nb.x >= N or nb.y >= N or seen.has(nb):
				continue
			if _edges[_edge_key(cur, nb)].state != WALL_SOLID:
				seen[nb] = true
				q.append(nb)
	_edges[k].state = old
	return seen.size() == N * N


func all_connected() -> bool:
	var any: Vector3i = _edges.keys()[0]
	return _connected_with(any, _edges[any].state)


func _try_edge_change() -> void:
	var p := Game.player.global_position
	var here := seg_at(p)
	var keys := _edges.keys()
	keys.shuffle()
	for k in keys.slice(0, 8):
		var e: Dictionary = _edges[k]
		if _now - float(e.changed_at) < 6.0:
			continue
		var ok := true
		for sg in _edge_segs(k):
			var seg: Dictionary = _segs[sg.y][sg.x]
			if sg == here:
				continue         # the room you're in: only the wall itself must be out of sight
			if seg.seen or _now - float(seg.last_seen) < EDGE_UNSEEN_T:
				ok = false
		if not ok:
			continue
		var mid := edge_mid(k)
		if Vector2(p.x - mid.x, p.z - mid.z).length() < 3.0:
			continue
		var ex := _edge_bodies(k)
		if Observation.is_observed(mid + Vector3(0, 1.5, 0), 2.2, ex) or Observation.is_observed(mid + Vector3(0, 0.5, 0), 2.2, ex):
			continue
		var choices := [WALL_SOLID, WALL_DOOR, WALL_NONE]
		choices.erase(int(e.state))
		var st: int = choices[_rng.randi() % 2]
		if st == WALL_SOLID and not _connected_with(k, st):
			continue
		e.state = st
		e.changed_at = _now
		_build_edge(k)
		stats.edge_changes += 1
		for sg in _edge_segs(k):
			_segs[sg.y][sg.x].changed = true
		return


# ------------------------------------------------------------------ the exit

func _place_exit(away_from: Vector2i) -> void:
	# a door in the outside wall of a room on the edge of the grid, as far from `away_from` as possible
	var best := Vector2i(N - 1, N - 1)
	var best_d := -1.0
	for r in N:
		for c in N:
			if c != 0 and r != 0 and c != N - 1 and r != N - 1:
				continue
			var d := Vector2(c - away_from.x, r - away_from.y).length() + _rng.randf() * 1.5
			if d > best_d and Vector2i(c, r) != _exit_seg:
				best_d = d
				best = Vector2i(c, r)
	_exit_seg = best
	if _exit_node:
		_exit_node.queue_free()
	var out := Vector3(1, 0, 0) if best.x == N - 1 else (Vector3(-1, 0, 0) if best.x == 0 else (Vector3(0, 0, 1) if best.y == N - 1 else Vector3(0, 0, -1)))
	var pos := center(best.x, best.y) + out * (S * 0.5 - 0.02)
	_exit_node = door(pos, rad_to_deg(atan2(-out.x, -out.z)), Color(0.3, 0.45, 0.32), 1.0, 2.1, "metal")
	var sign := label(pos - out * 0.05 + Vector3(0, 2.5, 0), rad_to_deg(atan2(-out.x, -out.z)), "EXIT", 0.12, Color(0.3, 1.0, 0.4))
	sign.reparent(_exit_node)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.4)
	glow.light_energy = 0.6
	glow.omni_range = 4.0
	glow.position = pos - out * 0.8 + Vector3(0, 2.4, 0)
	_exit_node.add_child(glow)
	glow.global_position = pos - out * 0.8 + Vector3(0, 2.4, 0)
	var it := interactable(pos - out * 0.3 + Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.6), func(): return "Open the EXIT",
		func(): _leave(), func(): return not _leaving)
	it.reparent(_exit_node)


func exit_segment() -> Vector2i:
	return _exit_seg


func _leave() -> void:
	_leaving = true
	Game.set_flag("shift_exit")
	Sfx.play("door_creak", -2.0)
	Game.hud.show_card("THE SHIFT", "prototype - %d rooms rebuilt, %d walls moved, %d times you noticed" % [stats.rebuilds, stats.edge_changes, stats.noticed], 0.8)
	await get_tree().create_timer(4.0, false).timeout
	Game.hud.hide_card(0.5)
	Game.return_to_title()


# ------------------------------------------------------------------ runtime

func on_player_entered(_from_save: bool) -> void:
	_now = 0.0
	Game.hud.show_hint("PROTOTYPE - THE SHIFT (work in progress)\nWhat you don't look at fades, and then changes. Find the EXIT.\nF3: the debug map", 9.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		debug_map = not debug_map


func _process(delta: float) -> void:
	if _map:
		_map.visible = debug_map and Game.mode == "game"
		_map.queue_redraw()
	var pl: Player = Game.player
	if pl == null or Game.in_sequence or Game.mode != "game":
		return
	_now += delta * speed
	# who can see what: a few rooms a frame (every room within a quarter of a second or so)
	for i in 6:
		_check = (_check + 1) % (N * N)
		var seg: Dictionary = _segs[_check / N][_check % N]
		var vis := seg_visible(seg)
		if vis:
			if not seg.seen and seg.changed:
				_noticed(seg)
			seg.last_seen = _now
			seg.changed = false
		seg.seen = vis
		if vis:
			continue
		var unseen: float = (_now - float(seg.last_seen)) / float(seg.pace)
		if unseen > REBUILD_T:
			_rebuild(seg)
		elif seg.stage < 3 and unseen > STAGE_T[seg.stage]:
			_set_stage(seg, seg.stage + 1)
	_edge_t -= delta * speed
	if _edge_t <= 0.0:
		_edge_t = EDGE_EVERY
		_try_edge_change()
	_update_exit()


func _noticed(seg: Dictionary) -> void:
	stats.noticed += 1
	Sfx.play("creak", -16.0, randf_range(0.5, 0.8))
	if stats.noticed <= NOTICE.size() or randf() < 0.15:
		Game.hud.show_thought(NOTICE[(stats.noticed - 1) % NOTICE.size()], 3.0)


func _update_exit() -> void:
	var seg: Dictionary = _segs[_exit_seg.y][_exit_seg.x]
	if seg.seen or _now - float(seg.last_seen) < EXIT_T:
		return
	var here := seg_at(Game.player.global_position)
	if absi(here.x - _exit_seg.x) + absi(here.y - _exit_seg.y) < 3:
		return
	if Observation.is_observed(_exit_node.get_child(0).global_position + Vector3(0, 1, 0), 1.5):
		return
	_place_exit(here)
	_segs[_exit_seg.y][_exit_seg.x].last_seen = _now
	stats.exit_moves += 1


func segment(c: int, r: int) -> Dictionary:
	return _segs[r][c]


## Debug view: the grid, how far gone each room is, the walls, you and the exit.
class ShiftMap extends Control:
	var zone: ShiftZone
	const CELL := 22.0

	func _ready() -> void:
		position = Vector2(16, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if zone == null:
			return
		var n := ShiftZone.N
		draw_rect(Rect2(-6, -22, n * CELL + 12, n * CELL + 46), Color(0, 0, 0, 0.55))
		draw_string(ThemeDB.fallback_font, Vector2(0, -8), "THE SHIFT - debug (F3)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
		for r in n:
			for c in n:
				var seg: Dictionary = zone.segment(c, r)
				var col: Color = [Color(0.32, 0.32, 0.34), Color(0.75, 0.7, 0.25), Color(0.85, 0.45, 0.15), Color(0.7, 0.12, 0.1)][int(seg.stage)]
				if zone._now - float(seg.rebuilt_at) < 1.5:
					col = Color(0.3, 0.5, 1.0)
				var rect := Rect2(c * CELL + 2, r * CELL + 2, CELL - 4, CELL - 4)
				draw_rect(rect, col)
				if seg.seen:
					draw_rect(rect, Color(1, 1, 1, 0.9), false, 1.5)
		for k in zone._edges:
			var st: int = zone._edges[k].state
			if st == ShiftZone.WALL_NONE:
				continue
			var a: Vector2
			var b: Vector2
			if k.z == 0:
				a = Vector2((k.x + 1) * CELL, k.y * CELL)
				b = a + Vector2(0, CELL)
			else:
				a = Vector2(k.x * CELL, (k.y + 1) * CELL)
				b = a + Vector2(CELL, 0)
			if st == ShiftZone.WALL_SOLID:
				draw_line(a, b, Color(0.9, 0.9, 0.85), 2.0)
			else:
				draw_line(a, a.lerp(b, 0.3), Color(0.9, 0.9, 0.85), 2.0)
				draw_line(a.lerp(b, 0.7), b, Color(0.9, 0.9, 0.85), 2.0)
		draw_rect(Rect2(0, 0, n * CELL, n * CELL), Color(0.9, 0.9, 0.85), false, 2.0)
		var e := zone.exit_segment()
		draw_rect(Rect2(e.x * CELL + 7, e.y * CELL + 7, CELL - 14, CELL - 14), Color(0.3, 1.0, 0.4))
		if Game.player:
			var p := Game.player.global_position
			var m := Vector2(p.x / ShiftZone.S + n * 0.5, p.z / ShiftZone.S + n * 0.5) * CELL
			draw_circle(m, 3.5, Color(1, 0.25, 0.25))
			var f := -Game.player.global_transform.basis.z
			draw_line(m, m + Vector2(f.x, f.z) * 9.0, Color(1, 0.25, 0.25), 1.5)
		var s: Dictionary = zone.stats
		draw_string(ThemeDB.fallback_font, Vector2(0, n * CELL + 16), "rebuilt %d  walls %d  exit moved %d" % [s.rebuilds, s.edge_changes, s.exit_moves],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
