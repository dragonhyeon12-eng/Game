class_name PatternZone
extends Zone
## PATTERN - trypophobia. Down the subway stairs at night, and the stairs are gone behind you. A walk, not a
## puzzle: the platform (a train standing with its doors shut), a long tiled passage to the WAY OUT, the
## ticket hall, and a round chamber beyond it with a hospital door: WARD 6.
##
## What it does to you is the holes. Not dots: little cups, a dark throat and a raised wet rim, packed
## together in every size on swellings that grow out of the tiles - in the grout at first, then behind the
## posters, then over everything. They breathe. They spread while you aren't looking (turn round: there are
## more). And staring at them makes your skin crawl: the screen grains and shivers, something ticks in your
## ears, and the fear climbs. Eyes on the signs. Eyes on the WAY OUT.

const C := Vector3(0, 0, -77)          # the ticket hall's centre
const HALL_X := 14.0                   # the hall: x -14..14, z -62..-92, 5 m high
const HALL_Z0 := -62.0
const HALL_Z1 := -92.0
const HALL_H := 5.0
const PASS_X := 2.0                    # the passage: x -2..2, z -19.5..-62
const PASS_Z0 := -19.7
const PASS_H := 2.8
const HEX_H := 3.2                     # (the platform's ceiling height, and the core corridor's)
const DOOR_W := 1.5
const CORE := Vector3(0, 0, -112)
const WAY_IN := 3                      # the chamber's doorway (south)
const TILE_C := Color(0.88, 0.85, 0.76)        # cream station tiles
const BAND := Color(0.12, 0.32, 0.28)          # the line's colour, a band along every wall
const FLOOR_C := Color(0.5, 0.48, 0.44)
const POD := Color(0.8, 0.69, 0.6)             # the swellings: pale, a little fleshy, wet

var observer: Observer
var _crust: Node3D                     # every patch that's there from the start
var _spread: Array = []                # [{node, at, shown}] patches that come while you aren't looking
var _all_patches: Array = []           # [centre, radius, node] - for the staring
var _batch := {}                       # node -> {"pods": [[xf, col]], "pits": [[xf, col]]}
var _rings: Array[Node3D] = []
var _ring_pos := [2, 4, 1]
var _vault: Node3D
var _open := false
var _t := 0.0
var _hint := 0
var _section := "platform"
var _grow_t := 4.0
var _grown := 0
var _fresh: Array = []                 # patches grown behind you, not yet seen
var _stare := 0.0                      # how much of them you're looking at, smoothed
var _stare_t := 0.0
var _stare_said := false
var _itch: AudioStreamPlayer
var _flicker: Array = []               # [light, base]
var _flick_t := 0.0
static var _pit_mesh: ArrayMesh
static var _pod_mesh: Mesh
static var _pit_mat: ShaderMaterial
static var _pod_mat: StandardMaterial3D


func zone_id() -> String: return "pattern"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 12.0
func fear_decay() -> float: return 1.4
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.6
func sprint_speed() -> float: return 4.2


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, -1.0))


static func door_dir(i: int) -> Vector3:
	var a := deg_to_rad(i * 60.0)
	return Vector3(sin(a), 0, -cos(a))


static func door_point(i: int) -> Vector3:
	return CORE + door_dir(i) * 8.0


# ------------------------------------------------------------------ build

func build() -> void:
	_crust = Node3D.new()
	_crust.name = "Crust"
	add_child(_crust)
	_platform()
	_passage()
	_hall()
	_core()
	_flush()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen.connect(func():
		Game.set_flag("observer_pattern")
		Game.player.dread.add_dread(observer.spot_dread))
	var env := make_env(Color(0.85, 0.82, 0.72), 0.12)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.11, 0.09)
	env.fog_density = 0.025
	environment(env)
	ambient("hum", Vector3(0, 2.5, -40.0), true, -14.0, 40.0)
	ambient("drone", Vector3.ZERO, false, -26.0)
	_itch = Sfx.make_loop("itch", false, -60.0) as AudioStreamPlayer
	add_child(_itch)


# ---- the holes

static func _meshes() -> void:
	if _pit_mesh != null:
		return
	# a pit: a dark throat sunk below the surface, rising to a lip, and back down to the surface round it
	# (all of it sits on the surface: the throat is a dark well inside a raised, glistening rim - anything sunk
	# below the surface would be hidden by the swelling it grows on)
	var rings := [[0.0, 0.006, Color(0.015, 0.008, 0.008)], [0.22, 0.01, Color(0.025, 0.012, 0.01)], [0.34, 0.06, Color(0.1, 0.05, 0.04)],
		[0.43, 0.15, Color(0.5, 0.36, 0.3)], [0.5, 0.17, Color(0.88, 0.76, 0.67)], [0.62, 0.005, Color(0.8, 0.69, 0.6)]]
	var seg := 10 if Settings.quality >= 1 else 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in seg:
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var p00 := Vector3(cos(t0) * a[0], a[1], sin(t0) * a[0])
			var p01 := Vector3(cos(t1) * a[0], a[1], sin(t1) * a[0])
			var p10 := Vector3(cos(t0) * b[0], b[1], sin(t0) * b[0])
			var p11 := Vector3(cos(t1) * b[0], b[1], sin(t1) * b[0])
			for v in [[p00, a[2]], [p10, b[2]], [p11, b[2]], [p00, a[2]], [p11, b[2]], [p01, a[2]]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	_pit_mesh = st.commit()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	_pod_mesh = sm
	_pit_mat = ShaderMaterial.new()
	_pit_mat.shader = load("res://scripts/world/pores.gdshader")
	_pod_mat = StandardMaterial3D.new()
	_pod_mat.vertex_color_use_as_albedo = true
	_pod_mat.roughness = 0.3
	_pod_mat.metallic_specular = 0.65


## A patch of holes: a swelling (a dome `dome` x its radius high; flat crust if pod is false) on the surface at
## `center` facing `normal`, packed with pits of every size from `hole` (radius range), rims nearly touching.
## Positions are in `parent`'s space.
func _patch(parent: Node3D, center: Vector3, normal: Vector3, radius: float, dome := 0.3, hole := Vector2(0.025, 0.075), pod := true) -> void:
	_meshes()
	if parent == _crust:
		parent = _chunk(center)          # (in 10 m pieces, so what's behind you or round the corner isn't drawn)
	if Settings.quality < 1:
		hole *= 1.3                      # (LOW: fewer, bigger)
	if not _batch.has(parent):
		_batch[parent] = {"pods": [], "pits": []}
	var up := normal.normalized()
	var t1 := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := up.cross(t1)
	var H := radius * dome
	var tint := POD.lerp(POD.darkened(0.25), randf() * 0.5)
	if pod and dome > 0.01:
		_batch[parent].pods.append([Transform3D(Basis(t1, up, t1.cross(up)) * Basis.from_scale(Vector3(radius * 2.0, H * 2.0, radius * 2.0)), center), tint])   # (right-handed, or it's inside out)
	# packed: sizes picked from big to small so the little ones fill the gaps between the big
	var placed: Array = []
	var tries := int(radius * radius / (hole.x * hole.y) * 3.0) + 20
	for k in tries:
		var f := float(k) / tries
		var r := lerpf(hole.y, hole.x, sqrt(f)) * randf_range(0.85, 1.15)
		var a := randf() * TAU
		var d := sqrt(randf()) * (radius - r)
		var u := cos(a) * d
		var v := sin(a) * d
		var ok := true
		for q in placed:
			if Vector2(u - q[0], v - q[1]).length() < (r + q[2]) * 0.92:
				ok = false
				break
		if ok:
			placed.append([u, v, r])
	for q in placed:
		var u: float = q[0]
		var v: float = q[1]
		var rr: float = q[2]
		var h := 0.0
		var n := up
		if H > 0.001:
			var k2 := clampf(1.0 - (u * u + v * v) / (radius * radius), 0.0, 1.0)
			h = H * sqrt(k2)
			n = (t1 * (u / (radius * radius)) + t2 * (v / (radius * radius)) + up * (h / (H * H) if h > 0.001 else 1.0 / H)).normalized()
		var at := center + t1 * u + t2 * v + up * h + n * 0.002
		var x := n.cross(t2).normalized()
		if x.length() < 0.1:
			x = t1
		var z := x.cross(n)
		var s := rr * 2.0
		_batch[parent].pits.append([Transform3D(Basis(x, n, z) * Basis.from_scale(Vector3(s, s * 0.7, s)), at), Color.WHITE])
	if parent.get_parent() == _crust or parent.get_parent() == self:
		_all_patches.append([parent.global_transform * center if parent.is_inside_tree() else center, radius, parent])


var _chunks := {}


func _chunk(at: Vector3) -> Node3D:
	var k := Vector2i(floori(at.x / 10.0), floori(at.z / 10.0))
	if not _chunks.has(k):
		var n := Node3D.new()
		_crust.add_child(n)
		_chunks[k] = n
	return _chunks[k]


## A patch that isn't there yet: it comes while you aren't looking.
func _later(center: Vector3, normal: Vector3, radius: float, dome := 0.3, hole := Vector2(0.025, 0.075)) -> void:
	var g := Node3D.new()
	g.visible = false
	add_child(g)
	_patch(g, center, normal, radius, dome, hole)
	_spread.append({"node": g, "at": center, "shown": false})


## Build the MultiMeshes: one for the swellings, one for the pits, per group.
func _flush() -> void:
	_pit_mat.set_shader_parameter("pulse", 0.14 * clampf(Settings.visual(), 0.15, 1.0))
	for node in _batch:
		for kind in ["pods", "pits"]:
			var list: Array = _batch[node][kind]
			if list.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = kind == "pods"
			mm.mesh = _pod_mesh if kind == "pods" else _pit_mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i][0])
				if kind == "pods":
					mm.set_instance_color(i, list[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _pod_mat if kind == "pods" else _pit_mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# the pits are only pits up close; far off, a swelling is enough (it's grey, and dotted, in the fog)
			mmi.visibility_range_end = (28.0 if Settings.quality >= 1 else 18.0) if kind == "pits" else 70.0
			mmi.visibility_range_end_margin = 4.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			(node as Node3D).add_child(mmi)
	_batch.clear()


# ---- the station

## Tiled walls with the line's band along them.
func _tiled(c: Vector3, size: Vector3) -> void:
	box(c, size, TILE_C, true, 0.0, "tiles_pool")
	var along_x := size.x > size.z
	box(Vector3(c.x, 1.65, c.z), Vector3(size.x + (0.0 if along_x else 0.02), 0.3, size.z + (0.02 if along_x else 0.0)), BAND, false, 0.0, "tiles_pool")


func _platform() -> void:
	# x -4..4, z 0..-19.5; the tracks to the east behind a barrier, a train standing there with its doors shut
	box(Vector3(0, -0.1, -9.2), Vector3(18.4, 0.2, 20.4), FLOOR_C, true, 0.0, "tiles_floor")
	box(Vector3(0, HEX_H + 0.6, -9.2), Vector3(18.4, 0.2, 20.4), TILE_C.darkened(0.15), true, 0.0, "tiles_ceiling")
	_tiled(Vector3(-4.1, 1.9, -10), Vector3(0.2, 3.8, 21))
	_tiled(Vector3(0, 1.9, 0.6), Vector3(14, 3.8, 0.2))
	box(Vector3(3.6, 0.005, -10), Vector3(0.5, 0.01, 19.0), Color(0.85, 0.75, 0.15), false)       # the yellow line
	box(Vector3(4.2, 0.55, -10), Vector3(0.1, 1.1, 20), Color(0.6, 0.7, 0.72), true, 0.0, "glass")
	box(Vector3(6.5, -0.6, -10), Vector3(4.4, 0.2, 22), Color(0.12, 0.1, 0.09), false)
	box(Vector3(7.2, 1.5, -10), Vector3(2.8, 3.0, 20), Color(0.75, 0.75, 0.72), true, 0.0, "plain@0.4")
	box(Vector3(5.82, 2.2, -10), Vector3(0.02, 0.25, 20), BAND, false)
	for k in 6:
		part("box", Vector3(5.79, 1.5, -1.5 - k * 3.3), Vector3(0.02, 0.8, 1.4), Color(0.05, 0.05, 0.06), null, Vector3.ZERO, 0.0, 0.1)
	box(Vector3(9.0, 1.9, -10), Vector3(0.2, 3.8, 22), TILE_C.darkened(0.2), true, 0.0, "tiles_pool")
	# where the stairs were: more wall
	part("box", Vector3(0, 1.6, 0.48), Vector3(3.2, 3.2, 0.04), TILE_C.darkened(0.05), null, Vector3.ZERO, 0.0, "tiles_pool")
	# a station: name boards, benches, the timetable, a vending machine humming
	for z in [-5.0, -14.0]:
		part("box", Vector3(-3.97, 2.3, z), Vector3(0.04, 0.6, 2.4), BAND, null, Vector3.ZERO, 0.0, "plain@0.4")
		label(Vector3(-3.94, 2.3, z), 90, "HALCYON  ROAD", 0.14, Color(0.96, 0.96, 0.92), false)
		box(Vector3(-3.6, 0.42, z + 2.5), Vector3(0.5, 0.06, 1.8), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	if not furnish("vending_machine", Vector3(-3.5, 0, -9.5), 90.0, Vector3(0.9, 1.84, 0.8), Vector3(0, 0.92, 0)):
		box(Vector3(-3.5, 0.92, -9.5), Vector3(0.8, 1.84, 0.9), Color(0.7, 0.15, 0.12), true)
	ambient("buzz", Vector3(-3.4, 1.0, -9.5), true, -18.0, 8.0)
	var tt := Vector3(-3.95, 1.5, -2.0)
	box(tt, Vector3(0.05, 0.9, 0.7), Color(0.95, 0.95, 0.92), false)
	label(tt + Vector3(0.04, 0.25, 0), 90, "LAST TRAIN\n00:47", 0.05, Color(0.15, 0.15, 0.15), false)
	interactable(tt + Vector3(0.3, 0, 0), Vector3(0.4, 0.9, 0.8), func(): return "The timetable",
		func(): Game.hud.show_thought("Last train, 00:47. The one standing there has its doors shut and nobody in it.", 3.5))
	for z in [-3.0, -9.0, -15.0]:
		part("box", Vector3(0, HEX_H + 0.45, z), Vector3(2.5, 0.05, 0.4), Color(0.95, 1.0, 0.95), null, Vector3.ZERO, 2.5)
		omni(Vector3(0, HEX_H, z), Color(0.95, 1.0, 0.92), 0.9, 9.0, false)
	label(Vector3(0, 2.9, -19.45), 0, "WAY OUT  ->", 0.12, Color(0.95, 0.85, 0.3), true)
	# the end wall, with the way through to the passage
	box(Vector3(-3.0, HEX_H * 0.5 + 0.3, -19.7), Vector3(2.0, HEX_H + 0.6, 0.4), TILE_C, true, 0.0, "tiles_pool")
	box(Vector3(3.0, HEX_H * 0.5 + 0.3, -19.7), Vector3(2.0, HEX_H + 0.6, 0.4), TILE_C, true, 0.0, "tiles_pool")
	box(Vector3(0, PASS_H + (HEX_H + 0.6 - PASS_H) * 0.5, -19.7), Vector3(4.0, HEX_H + 0.6 - PASS_H, 0.4), TILE_C, true, 0.0, "tiles_pool")
	box(Vector3(6.5, HEX_H * 0.5 + 0.3, -19.9), Vector3(5.0, HEX_H + 0.6, 0.2), TILE_C, true, 0.0, "tiles_pool")
	# only a little, so far: in the grout, in a corner, where you might not notice
	_patch(_crust, Vector3(-3.99, 0.25, -12.6), Vector3(1, 0, 0), 0.18, 0.12, Vector2(0.012, 0.03))
	_patch(_crust, Vector3(-3.99, 3.1, -6.8), Vector3(1, 0, 0), 0.22, 0.15, Vector2(0.012, 0.035))
	_patch(_crust, Vector3(1.8, 0.002, -18.6), Vector3.UP, 0.2, 0.08, Vector2(0.012, 0.03))
	for k in 4:
		_later(Vector3(-3.99, randf_range(0.3, 2.8), -4.0 - k * 4.0), Vector3(1, 0, 0), randf_range(0.15, 0.3), 0.2, Vector2(0.012, 0.04))
	trigger(Vector3(0, 1.2, -4), Vector3(8, 2.4, 2), func():
		Game.hud.show_thought("Halcyon Road. ...The last train's gone. The stairs too - just tiles where they were.", 4.0))


func _passage() -> void:
	# 42 m of tiled tunnel to the WAY OUT: tubes, adverts, and the holes coming on as you go
	var z0 := PASS_Z0
	var z1 := HALL_Z0
	var mid := (z0 + z1) * 0.5
	var ln := z0 - z1
	box(Vector3(0, -0.1, (-19.4 + z1) * 0.5), Vector3(PASS_X * 2.0, 0.2, -19.4 - z1), FLOOR_C, true, 0.0, "tiles_floor")
	box(Vector3(0, PASS_H + 0.1, mid), Vector3(PASS_X * 2.0, 0.2, ln), TILE_C.darkened(0.1), true, 0.0, "tiles_pool")
	for s in [-1.0, 1.0]:
		_tiled(Vector3(s * (PASS_X + 0.15), PASS_H * 0.5, mid), Vector3(0.3, PASS_H, ln))
	for k in 8:
		var z := z0 - 3.0 - k * 5.2
		part("box", Vector3(0, PASS_H - 0.02, z), Vector3(0.25, 0.04, 1.4), Color(0.95, 1.0, 0.92), null, Vector3.ZERO, 2.2)
		var l := omni(Vector3(0, PASS_H - 0.4, z), Color(0.95, 1.0, 0.92), 0.8, 7.0, false)
		if k == 5:
			_flicker.append([l, 0.8])
	# adverts: summer things. Further in, the holes are behind them; one's bulging off the wall
	var ads := [["SUNSHINE COAST - THIS SUMMER", Color(0.95, 0.6, 0.2)], ["THE EMPORIUM - OPEN LATE", Color(0.85, 0.3, 0.4)],
		["GET AWAY FROM IT ALL", Color(0.3, 0.6, 0.9)], ["MIND THE GAP", Color(0.15, 0.3, 0.6)], ["HAVE YOU SEEN THIS CAT?", Color(0.9, 0.9, 0.85)],
		["SWIM SAFE", Color(0.3, 0.75, 0.85)]]
	for k in ads.size():
		var s := -1.0 if k % 2 == 0 else 1.0
		var z := z0 - 6.0 - k * 6.4
		var ax := s * (PASS_X - 0.01)
		part("box", Vector3(ax, 1.45, z), Vector3(0.02, 1.4, 2.0), ads[k][1], null, Vector3.ZERO, 0.0, "plain@0.5")
		label(Vector3(ax - s * 0.015, 1.9, z), -90.0 * s, ads[k][0], 0.06, Color(1, 1, 1), false)
		if k >= 3:
			# the poster's coming away at the corner, and behind it -
			part("box", Vector3(ax - s * 0.12, 0.95, z - 0.75), Vector3(0.02, 0.5, 0.5), ads[k][1].darkened(0.2), null, Vector3(0, 0, s * 25.0), 0.0, "plain@0.5")
			_patch(_crust, Vector3(ax - s * 0.02, 0.9, z - 0.7), Vector3(-s, 0, 0), 0.3 + (k - 3) * 0.1, 0.35)
		if k == 5:
			# this one's bulging right off the wall
			_patch(_crust, Vector3(ax - s * 0.05, 1.45, z), Vector3(-s, 0, 0), 0.75, 0.45, Vector2(0.03, 0.085))
	# in the grout, along the skirting, thicker the further you go
	for k in 26:
		var f := float(k) / 25.0
		var s := -1.0 if k % 2 == 0 else 1.0
		var z := z0 - 1.5 - f * (ln - 3.0)
		var r := lerpf(0.12, 0.42, f) * randf_range(0.8, 1.2)
		_patch(_crust, Vector3(s * (PASS_X - 0.01), randf_range(0.15, 2.5), z), Vector3(-s, 0, 0), r, lerpf(0.1, 0.4, f), Vector2(lerpf(0.012, 0.025, f), lerpf(0.035, 0.075, f)))
	for k in 10:
		var z := z0 - 22.0 - k * 2.0
		_patch(_crust, Vector3(randf_range(-1.2, 1.2), PASS_H - 0.005, z), Vector3.DOWN, randf_range(0.2, 0.45), 0.3)
	for k in 14:
		var s := -1.0 if randf() < 0.5 else 1.0
		_later(Vector3(s * (PASS_X - 0.01), randf_range(0.3, 2.4), z0 - 4.0 - k * 2.7), Vector3(-s, 0, 0), randf_range(0.2, 0.5), 0.35)
	label(Vector3(0, PASS_H - 0.3, HALL_Z0 + 4.0), 0, "WAY OUT  ->", 0.1, Color(0.95, 0.85, 0.3), true)
	ambient("buzz", Vector3(0, PASS_H - 0.3, z0 - 29.0), true, -14.0, 10.0)
	trigger(Vector3(0, 1.2, z0 - 16.0), Vector3(4, 2.4, 1), func():
		Game.hud.show_thought("Something in the grout. Little holes. ...Lots of little holes.", 3.5))
	trigger(Vector3(0, 1.2, z0 - 34.0), Vector3(4, 2.4, 1), func():
		Game.hud.show_thought("Don't look at them. Eyes on the signs. Just walk.", 3.5))


func _hall() -> void:
	# the ticket hall: barriers left open, a dead board, a kiosk, benches - and it's all over everything
	var x0 := -HALL_X
	var x1 := HALL_X
	room_shell(x0, x1, HALL_Z1, HALL_Z0, HALL_H, "nswe", {"n": [[-PASS_X - 0.0, PASS_X + 0.0, PASS_H]], "s": [[-DOOR_W * 0.5, DOOR_W * 0.5, HEX_H]]},
		TILE_C, FLOOR_C, {"wall_s": "tiles_pool", "floor_s": "tiles_floor", "ceil_s": "tiles_ceiling", "ceil_c": TILE_C.darkened(0.2)})
	for zw in [HALL_Z0, HALL_Z1]:
		box(Vector3(0, 1.65, zw + (-0.16 if zw == HALL_Z0 else 0.16)), Vector3(HALL_X * 2.0, 0.3, 0.02), BAND, false, 0.0, "tiles_pool")
	for xw in [x0, x1]:
		box(Vector3(xw + (0.16 if xw < 0 else -0.16), 1.65, C.z), Vector3(0.02, 0.3, HALL_Z0 - HALL_Z1), BAND, false, 0.0, "tiles_pool")
	# the barriers, open
	for k in 8:
		var bx := -7.0 + k * 2.0
		box(Vector3(bx, 0.5, HALL_Z0 - 4.0), Vector3(0.3, 1.0, 1.2), Color(0.55, 0.57, 0.6), true, 0.0, "metal")
		part("box", Vector3(bx + 0.4, 0.75, HALL_Z0 - 4.0), Vector3(0.5, 0.35, 0.04), Color(0.3, 0.3, 0.32), null, Vector3(0, 70, 0), 0.0, "glass")
	for s in [-1.0, 1.0]:
		box(Vector3(s * 10.5, 0.5, HALL_Z0 - 4.0), Vector3(7.0, 1.0, 0.3), Color(0.55, 0.57, 0.6), true, 0.0, "metal")
	# ticket machines on the west wall, the kiosk in the east corner, benches
	for k in 3:
		box(Vector3(x0 + 0.5, 0.85, HALL_Z0 - 9.0 - k * 1.4), Vector3(0.7, 1.7, 1.0), Color(0.2, 0.35, 0.55), true, 0.0, "metal")
		part("box", Vector3(x0 + 0.86, 1.25, HALL_Z0 - 9.0 - k * 1.4), Vector3(0.01, 0.4, 0.5), Color(0.2, 0.25, 0.3), null, Vector3.ZERO, 0.0, 0.1)
	box(Vector3(x1 - 2.0, 1.2, HALL_Z0 - 10.0), Vector3(3.5, 2.4, 3.0), Color(0.45, 0.32, 0.22), true, 0.0, "wood")
	part("box", Vector3(x1 - 3.76, 1.6, HALL_Z0 - 10.0), Vector3(0.02, 0.9, 2.4), Color(0.08, 0.08, 0.1), null, Vector3.ZERO, 0.0, 0.1)
	label(Vector3(x1 - 3.8, 2.6, HALL_Z0 - 10.0), -90.0, "PAPERS  -  SWEETS  -  TICKETS", 0.08, Color(0.95, 0.85, 0.3), false)
	for k in 2:
		box(Vector3(-7.0 + k * 14.0, 0.42, C.z + 2.0), Vector3(2.4, 0.06, 0.5), Color(0.45, 0.32, 0.2), true, 0.0, "wood")
	# the board over the way on: dead, but one line
	var bd := Vector3(0, 3.7, HALL_Z1 + 0.2)
	box(bd, Vector3(4.6, 1.0, 0.15), Color(0.05, 0.05, 0.06), false, 0.0, "metal")
	label(bd + Vector3(0, 0.2, 0.09), 0, "- - - - - - - - - - - -", 0.1, Color(0.4, 0.3, 0.05), true)
	label(bd + Vector3(0, -0.15, 0.09), 0, "WARD 6  ..........  DUE", 0.11, Color(1.0, 0.7, 0.15), true)
	label(Vector3(0, HEX_H + 0.3, HALL_Z1 + 0.2), 0, "WAY OUT", 0.1, Color(0.95, 0.85, 0.3), true)
	# pillars, and columns grown up out of the floor: porous, all the way up
	for p in [Vector3(-6, 0, -71), Vector3(6, 0, -71), Vector3(-6, 0, -84), Vector3(6, 0, -84)]:
		box(p + Vector3(0, HALL_H * 0.5, 0), Vector3(0.9, HALL_H, 0.9), TILE_C, true, 0.0, "tiles_pool")
		for k in 5:
			var face: Vector3 = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][k % 4]
			_patch(_crust, p + face * 0.46 + Vector3(0, 0.6 + k * 0.85, 0), face, randf_range(0.28, 0.45), 0.4)
	for c in [Vector3(-10, 0, -76), Vector3(9.5, 0, -79), Vector3(-3.5, 0, -88), Vector3(4.0, 0, -70.5), Vector3(-10.5, 0, -88.5), Vector3(10.5, 0, -89)]:
		var cr := randf_range(0.45, 0.7)
		shape_at("cylinder", c + Vector3(0, HALL_H * 0.5, 0), Vector3(cr * 2.0, HALL_H, cr * 2.0), POD.darkened(0.1), true, Vector3.ZERO, 0.35)
		for k in 9:
			var a := k * 2.4
			var n := Vector3(cos(a), 0, sin(a))
			_patch(_crust, c + n * (cr - 0.02) + Vector3(0, 0.4 + k * 0.5, 0), n, randf_range(0.2, 0.34), 0.25)
	# over the walls, the floor, the ceiling
	for k in 40:
		var side := k % 4
		var at: Vector3
		var n: Vector3
		match side:
			0:
				at = Vector3(x0 + 0.16, randf_range(0.3, 4.6), randf_range(HALL_Z1 + 1, HALL_Z0 - 1)); n = Vector3(1, 0, 0)
			1:
				at = Vector3(x1 - 0.16, randf_range(0.3, 4.6), randf_range(HALL_Z1 + 1, HALL_Z0 - 1)); n = Vector3(-1, 0, 0)
			2:
				at = Vector3(randf_range(x0 + 1, x1 - 1), randf_range(0.3, 4.6), HALL_Z1 + 0.16); n = Vector3(0, 0, 1)
			_:
				at = Vector3(randf_range(x0 + 1, x1 - 1), randf_range(0.3, 4.6), HALL_Z0 - 0.16); n = Vector3(0, 0, -1)
		if absf(at.x) < 2.5 and (side == 2 or side == 3):
			at.x += 4.0 * signf(at.x + 0.01)
		_patch(_crust, at, n, randf_range(0.3, 0.8), randf_range(0.2, 0.5))
	for k in 18:
		_patch(_crust, Vector3(randf_range(x0 + 1, x1 - 1), HALL_H - 0.01, randf_range(HALL_Z1 + 1, HALL_Z0 - 1)), Vector3.DOWN, randf_range(0.4, 0.9), 0.3)
	for k in 14:
		var at := Vector3(randf_range(x0 + 1, x1 - 1), 0.0, randf_range(HALL_Z1 + 1, HALL_Z0 - 6))
		if absf(at.x) < 2.0:
			at.x += 3.0 * signf(at.x + 0.01)      # (not on the way across)
		_patch(_crust, at, Vector3.UP, randf_range(0.3, 0.7), 0.18)
	for k in 26:
		var a := randf() * TAU
		var at := C + Vector3(cos(a) * randf_range(8.0, 12.5), randf_range(0.4, 4.5), sin(a) * randf_range(8.0, 13.0))
		at.x = clampf(at.x, x0 + 0.17, x1 - 0.17)
		var n := Vector3(-signf(at.x), 0, 0) if absf(at.x) > HALL_X - 0.5 else Vector3.UP
		if n == Vector3.UP:
			at.y = 0.0
		_later(at, n, randf_range(0.3, 0.7), 0.35)
	# light: dim, a couple that won't settle
	for p in [Vector3(-7, 0, -68), Vector3(7, 0, -68), Vector3(-7, 0, -86), Vector3(7, 0, -86), Vector3(0, 0, -77)]:
		part("box", Vector3(p.x, HALL_H - 0.03, p.z), Vector3(1.4, 0.04, 0.4), Color(0.95, 0.92, 0.8), null, Vector3.ZERO, 1.8)
		var l := omni(Vector3(p.x, HALL_H - 0.6, p.z), Color(0.95, 0.9, 0.78), 0.9, 11.0, false)
		if p.z < -80.0:
			_flicker.append([l, 0.9])
	ambient("hum", C + Vector3(0, 3.0, 0), true, -16.0, 24.0)
	trigger(Vector3(0, 1.2, HALL_Z0 - 1.5), Vector3(4, 2.4, 1), func():
		_section = "hall"
		Game.set_flag("pt_hive")
		Game.hud.show_thought("Oh. Oh no. ...It's all over everything. Don't look. Just walk.", 4.0))
	interactable(bd + Vector3(0, -2.4, 1.5), Vector3(4.0, 0.6, 0.6), func(): return "The departures board",
		func(): Game.hud.show_thought("Every line's dead but one. WARD 6. Due.", 3.0))


func _core() -> void:
	# a short corridor north from the ticket hall to a round chamber, every surface crusted
	var d0z := HALL_Z1
	var end_z := CORE.z + 8.0
	var mid_z := (d0z + end_z) * 0.5
	var ln := d0z - end_z
	for s in [-1.0, 1.0]:
		box(Vector3(s * (DOOR_W * 0.5 + 0.15), HEX_H * 0.5, mid_z), Vector3(0.3, HEX_H, ln), TILE_C.darkened(0.1), true, 0.0, "tiles_pool")
	box(Vector3(0, -0.1, mid_z), Vector3(DOOR_W + 0.6, 0.2, ln), FLOOR_C.darkened(0.1), true, 0.0, "tiles_floor")
	box(Vector3(0, HEX_H + 0.1, mid_z), Vector3(DOOR_W + 0.6, 0.2, ln), TILE_C.darkened(0.15), true, 0.0, "tiles_pool")
	part("box", Vector3(0, HEX_H - 0.02, mid_z), Vector3(0.5, 0.04, 0.3), Color(0.95, 0.9, 0.75), null, Vector3.ZERO, 1.6)
	for k in 6:
		var z := d0z - 1.0 - k * (ln - 2.0) / 5.0
		_patch(_crust, Vector3((-1.0 if k % 2 == 0 else 1.0) * (DOOR_W * 0.5), randf_range(0.4, 2.4), z), Vector3(1.0 if k % 2 == 0 else -1.0, 0, 0), randf_range(0.25, 0.45), 0.3)
	# the chamber: 8 m across, 6 high
	var R := 8.0
	box(CORE + Vector3(0, -0.1, 0), Vector3(2 * R + 2, 0.2, 2 * R + 2), TILE_C.darkened(0.35), true, 0.0, "tiles_floor")
	box(CORE + Vector3(0, 6.1, 0), Vector3(2 * R + 2, 0.2, 2 * R + 2), TILE_C.darkened(0.3), true, 0.0, "tiles_pool")
	for i in 6:
		var dir := door_dir(i)
		var yaw := rad_to_deg(atan2(dir.x, dir.z))
		var wc := CORE + dir * R
		if i == WAY_IN:
			var side := 2.0 * R * tan(deg_to_rad(30.0))
			var seg := (side - DOOR_W) * 0.5
			var tang := dir.cross(Vector3.UP)
			for s in [-1.0, 1.0]:
				box(wc + tang * s * (DOOR_W * 0.5 + seg * 0.5) + Vector3(0, 3.0, 0), Vector3(seg, 6.0, 0.3), TILE_C, true, yaw, "tiles_pool")
			box(wc + Vector3(0, 4.6, 0), Vector3(DOOR_W, 2.8, 0.3), TILE_C, true, yaw, "tiles_pool")
		else:
			box(wc + Vector3(0, 3.0, 0), Vector3(2.0 * R * tan(deg_to_rad(30.0)) + 0.3, 6.0, 0.3), TILE_C, true, yaw, "tiles_pool")
	var crust := _crust
	for k in 46:
		var i := randi() % 6
		if i == 0 and k % 3 != 0:
			continue
		var dir := door_dir(i)
		var tang := dir.cross(Vector3.UP)
		_patch(crust, CORE + dir * (R - 0.16) + tang * randf_range(-4, 4) + Vector3(0, randf_range(0.3, 5.6), 0), -dir, randf_range(0.35, 0.8), randf_range(0.15, 0.45))
	for k in 10:
		_patch(crust, CORE + Vector3(randf_range(-6, 6), 5.99, randf_range(-6, 6)), Vector3.DOWN, randf_range(0.5, 1.0), 0.3)
	omni(CORE + Vector3(0, 5.0, 0), Color(0.95, 0.9, 0.75), 1.5, 16.0, true)
	# the vault on the north wall: three rings, each with one clean notch. Turn them to the top.
	_vault = group(CORE + door_dir(0) * (R - 0.3) + Vector3(0, 2.8, 0), 0)
	var radii := [2.4, 1.7, 1.0]
	for k in 3:
		var ring := Node3D.new()
		_vault.add_child(ring)
		var disc := MeshInstance3D.new()
		disc.mesh = Shapes.mesh("cylinder")
		disc.scale = Vector3(radii[k] * 2.0, 0.12 + k * 0.06, radii[k] * 2.0)
		disc.rotation_degrees.x = 90
		disc.material_override = Shapes.material(TILE_C.darkened(0.1 + k * 0.1), 0.5)
		ring.add_child(disc)
		var notch := MeshInstance3D.new()
		notch.mesh = Shapes.mesh("box")
		notch.scale = Vector3(0.22, 0.22, 0.05)
		notch.position = Vector3(0, radii[k] - 0.25, 0.1 + k * 0.03)
		notch.material_override = Shapes.material(Color(0.95, 0.8, 0.3), 0.4, 1.5)
		ring.add_child(notch)
		_patch(ring, Vector3(0, 0, 0.07 + k * 0.03), Vector3(0, 0, 1), radii[k] - 0.15, 0.05, Vector2(0.035, 0.09), false)
		ring.rotation_degrees.z = _ring_pos[k] * 60.0
		_rings.append(ring)
	# behind it, a porthole door
	var ph := CORE + door_dir(0) * (R - 0.12) + Vector3(0, 1.1, 0)
	part("box", ph, Vector3(1.1, 2.2, 0.05), Color(0.85, 0.88, 0.9), null, Vector3.ZERO, 0.0, "metal")
	part("cylinder", ph + Vector3(0, 0.45, 0.04), Vector3(0.4, 0.02, 0.4), Color(0.9, 0.95, 1.0), null, Vector3(90, 0, 0), 1.8)
	label(ph + Vector3(0, 1.25, 0.04), 0, "WARD 6", 0.1, Color(0.2, 0.3, 0.5), false)
	# the levers on a pedestal in the middle of the room
	var ped := CORE + Vector3(0, 0, -2.5)
	box(ped + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.6), TILE_C.darkened(0.2), true, 0.0, "tiles_pool")
	var names := ["outer", "middle", "inner"]
	for k in 3:
		var lv := ped + Vector3(-0.5 + k * 0.5, 1.1, 0)
		part("cylinder", lv, Vector3(0.05, 0.3, 0.05), Color(0.3, 0.3, 0.3), null, Vector3.ZERO, 0.0, "metal")
		part("sphere", lv + Vector3(0, 0.17, 0), Vector3.ONE * 0.1, Color(0.95, 0.8, 0.3), null, Vector3.ZERO, 0.5)
		var kk := k
		interactable(lv, Vector3(0.35, 0.5, 0.5), func(): return "Turn the %s ring" % names[kk] if not _open else "",
			func(): _turn(kk), func(): return not _open)
	interactable(ph + Vector3(0, 0, 0.5), Vector3(1.2, 2.2, 0.6), func(): return "Through the porthole door" if _open else "",
		func(): Game.on_pattern_exit(), func(): return _open)
	trigger(CORE + Vector3(0, 1.2, 6.0), Vector3(4, 2.4, 2), func():
		Game.set_flag("pt_core")
		Game.hud.show_thought("The middle. It's all holes in here. ...The rings on the far wall are turning.", 4.0)
		# the rings turn to their notches by themselves, and the vault rolls aside
		for k in 3:
			get_tree().create_timer(1.0 + k * 0.9, false).timeout.connect(func():
				if is_inside_tree() and not _open:
					while _ring_pos[k] != 0:
						_turn(k)))


func _turn(k: int) -> void:
	_ring_pos[k] = (_ring_pos[k] + 1) % 6
	Sfx.play("grind", -6.0, 1.4)
	Sfx.play("thud", -10.0, 1.6)
	create_tween().tween_property(_rings[k], "rotation_degrees:z", _ring_pos[k] * 60.0 if _ring_pos[k] != 0 else 360.0, 0.4).set_trans(Tween.TRANS_BACK)
	if _ring_pos[k] == 0:
		get_tree().create_timer(0.45, false).timeout.connect(func(): _rings[k].rotation_degrees.z = 0.0)
	if _ring_pos == [0, 0, 0]:
		_open = true
		Game.set_flag("pt_rings")
		Sfx.stinger("hit", -2.0)
		Sfx.play("whoosh", -2.0, 0.6)
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_property(_vault, "position:x", _vault.position.x + 3.2, 2.5).set_trans(Tween.TRANS_SINE)
		Game.hud.show_thought("It's rolling aside. ...A door. A hospital door. WARD 6.", 4.0)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	Game.counters["hive"] = 0


func _exit_tree() -> void:
	super()
	if Game.hud:
		Game.hud.post_extra = Vector4.ZERO


func _process(delta: float) -> void:
	_t += delta
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		if Game.hud:
			Game.hud.post_extra = Vector4.ZERO
		return
	var p := pl.global_position
	if p.z < PASS_Z0 and _section == "platform":
		_section = "passage"
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("The stairs - they're gone. Just tiles where they were. ...WAY OUT, the signs say.", 4.5)
	_update_growth(delta, p)
	_update_stare(delta, pl)
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = randf_range(0.05, 0.5)
		for f in _flicker:
			var on := 1.0 if randf() < 0.65 else randf_range(0.0, 0.4)
			(f[0] as OmniLight3D).light_energy = float(f[1]) * lerpf(1.0, on, clampf(Settings.visual(), 0.0, 1.0))


## While you aren't looking, it spreads: a patch near you that isn't in view is suddenly there.
func _update_growth(delta: float, p: Vector3) -> void:
	_grow_t -= delta
	if _grow_t <= 0.0:
		_grow_t = randf_range(2.5, 5.0) if _section != "platform" else randf_range(8.0, 14.0)
		var cands := _spread.filter(func(sp): return not sp.shown and sp.at.distance_to(p) < 16.0 and not Observation.in_view(sp.at, 0.8))
		if not cands.is_empty():
			var sp: Dictionary = cands.pick_random()
			sp.shown = true
			(sp.node as Node3D).visible = true
			_fresh.append(sp)
			_grown += 1
			Sfx.play_at("drip", self, sp.at, -22.0, 10.0, 2.2)
	# ...and when you turn round and see one that wasn't there
	for sp in _fresh:
		if sp.at.distance_to(p) < 9.0 and Observation.in_view(sp.at, 0.5):
			_fresh.erase(sp)
			if _grown >= 2 and randf() < 0.5:
				Game.hud.show_thought(["That wasn't there before.", "...That was clean. A second ago, that was clean.", "It's spreading. Behind me. Every time I look away."].pick_random(), 3.0)
			Game.player.dread.add_fear(4.0, "it spread")
			break


## Staring at them: the screen crawls, something ticks in your ears, the fear climbs. Look away and it eases.
func _update_stare(delta: float, pl: Player) -> void:
	var cam := pl.camera
	var fwd := -cam.global_transform.basis.z
	var eye := cam.global_position
	var e := 0.0
	for pt in _all_patches:
		var node: Node3D = pt[2]
		if not node.visible:
			continue
		var at: Vector3 = pt[0]
		var to := at - eye
		var d := to.length()
		if d > 5.0 or d < 0.01:
			continue
		var facing := fwd.dot(to / d)
		if facing < 0.75:
			continue
		e += (1.0 - d / 5.0) * smoothstep(0.75, 0.97, facing) * clampf(float(pt[1]) * 2.0, 0.3, 1.5)
	e = clampf(e, 0.0, 1.0)
	_stare = lerpf(_stare, e, clampf(delta * (2.5 if e > _stare else 1.2), 0.0, 1.0))
	var v := clampf(Settings.visual(), 0.0, 1.0)
	Game.hud.post_extra = Vector4(0.35 * _stare, 0.9 * _stare * v, 0.15 * _stare, 2.2 * _stare * v)
	if _itch:
		_itch.volume_db = linear_to_db(maxf(_stare * Settings.audio_intensity, 0.0001)) - 4.0
	if _stare > 0.2:
		pl.dread.add_fear(7.0 * _stare * delta, "the holes")
		if _stare > 0.6 and v > 0.3 and randf() < delta * 3.0:
			pl.jolt(Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), 0) * _stare)      # a shudder
	if _stare > 0.6:
		_stare_t += delta
		if _stare_t > 1.5 and not _stare_said:
			_stare_said = true
			Game.hud.show_thought("Stop looking at them. Stop LOOKING at them.", 3.0)
	else:
		_stare_t = 0.0
