class_name CityZone
extends Zone
## The first dream: a warm, bright summer city that feels like the perfect lucid dream.
## Deliberately comforting - fear gains are heavily damped and nothing changes behind your back.
## The only thing out of place is a black figure at the far end of the avenue, easy to overlook.
##
## Grid: 5x5 blocks, pitch 42m (32m block incl. 3.5m sidewalk + 10m street). Block (0,0) is the park.

const PITCH := 42.0
const BLOCK := 32.0
const SIDEWALK := 3.5
const CURB := 0.15
const HALF := 2
const GRASS_Y := 0.17
const BOUNDS := 109.0

const ASPHALT := Color(0.09, 0.095, 0.105)
const PAVEMENT := Color(0.62, 0.6, 0.56)
const GRASS := Color(0.22, 0.45, 0.12)
const PATH := Color(0.72, 0.66, 0.55)
const GLASS := Color(0.22, 0.34, 0.45)
const TRIM := Color(0.9, 0.88, 0.84)
const BARK := Color(0.28, 0.18, 0.11)
const STONE := Color(0.7, 0.68, 0.64)
const WATER := Color(0.12, 0.38, 0.55)
const METAL := Color(0.18, 0.2, 0.22)
const FACADES := [Color(0.85, 0.6, 0.45), Color(0.92, 0.85, 0.68), Color(0.55, 0.7, 0.78), Color(0.85, 0.56, 0.55),
	Color(0.64, 0.78, 0.6), Color(0.95, 0.76, 0.5), Color(0.74, 0.7, 0.86), Color(0.9, 0.9, 0.87)]
const LEAVES := [Color(0.2, 0.45, 0.12), Color(0.28, 0.52, 0.14), Color(0.16, 0.38, 0.1)]

var observer: Observer
var _theo: NPC
var _kite: Node3D
var _kite_line: MeshInstance3D
var _pigeons: Array[Node3D] = []
var _pigeon_home: Array[Vector3] = []
var _observer_spots: Array[Vector3] = []
var _t := 0.0
var _hint_stage := 0
var _hint_t := 0.0
var _pigeon_freeze := 0.0
var _saw_lottery := false
var _next_chirp := 2.0
var _water: Node3D
var _observer_return := -1.0   # seconds until he reappears somewhere far away


func zone_id() -> String: return "city"
func allows_manifestation() -> bool: return true
func fear_gain() -> float: return 0.35


## Grass inside the park (away from the paths), concrete everywhere else.
func surface_at(p: Vector3) -> String:
	var inner := (BLOCK - 2.0 * SIDEWALK) * 0.5
	if absf(p.x) < inner and absf(p.z) < inner and absf(p.x) > 1.3 and absf(p.z) > 1.3 and Vector2(p.x, p.z).length() > 2.7:
		return "grass"
	return "concrete"
func fear_decay() -> float: return 5.0
func walk_speed() -> float: return 3.0
func sprint_speed() -> float: return 5.4


func player_start() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(-13.5, GRASS_Y + 0.05, 0))


func build() -> void:
	_ground()
	_buildings()
	_streets()
	_park()
	_skyline()
	_lighting()
	_characters()
	_quest()
	ambient("city", Vector3.ZERO, false, -14.0)
	_water = ambient("water", Vector3(0, 0.8, 0), true, -2.0, 22.0)
	for s in [Vector3(BOUNDS, 10, 0), Vector3(-BOUNDS, 10, 0)]:
		blocker(s, Vector3(1, 40, BOUNDS * 2))
	for s in [Vector3(0, 10, BOUNDS), Vector3(0, 10, -BOUNDS)]:
		blocker(s, Vector3(BOUNDS * 2, 40, 1))


# ------------------------------------------------------------------ geometry

func _ground() -> void:
	box(Vector3(0, -0.25, 0), Vector3(800, 0.5, 800), ASPHALT, true, 0.0, "asphalt")
	for i in range(-HALF, HALF + 1):
		for j in range(-HALF, HALF + 1):
			box(Vector3(i * PITCH, CURB * 0.5, j * PITCH), Vector3(BLOCK, CURB, BLOCK), PAVEMENT, true, 0.0, "pavers")
	for k in range(-HALF, HALF):
		var mid := (k + 0.5) * PITCH
		var t := -90.0
		while t <= 90.0:
			box(Vector3(t, 0.015, mid), Vector3(3, 0.02, 0.14), Color(0.85, 0.75, 0.3), false)
			box(Vector3(mid, 0.015, t), Vector3(0.14, 0.02, 3), Color(0.85, 0.75, 0.3), false)
			t += 6.0


func _buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	var lot := BLOCK - 2.0 * SIDEWALK
	for i in range(-HALF, HALF + 1):
		for j in range(-HALF, HALF + 1):
			if i == 0 and j == 0:
				continue
			if i == 0 and j == -2:
				continue     # the hill with the big tree: the quiet place at the end of the city
			var c := Vector3(i * PITCH, CURB, j * PITCH)
			var near_park := absi(i) <= 1 and absi(j) <= 1
			var layout := rng.randi_range(0, 2)
			var sx := 1 if layout == 0 else 2
			var sz := 2 if layout == 2 else 1
			var gap := 0.6
			var w := (lot - gap * (sx - 1)) / sx
			var d := (lot - gap * (sz - 1)) / sz
			for a in sx:
				for b in sz:
					var x := c.x - lot * 0.5 + w * 0.5 + a * (w + gap)
					var z := c.z - lot * 0.5 + d * 0.5 + b * (d + gap)
					var h := rng.randf_range(9.0, 23.0) if near_park else rng.randf_range(16.0, 48.0)
					var facade: Color = FACADES[rng.randi() % FACADES.size()]
					# a real building from the facade kit, when there is one
					var style: String = ["brick", "plaster", "plaster", "modern"][rng.randi() % 4] if near_park else ["brick", "modern", "plaster"][rng.randi() % 3]
					var tint := facade.lightened(0.15) if style == "plaster" else (Color(0.78, 0.5, 0.4) if style == "brick" else Color(0.82, 0.82, 0.8))
					if facade_building(Vector3(x, c.y, z), w, d, maxi(1, int((h - 4.2) / 3.6)), style, tint, near_park or rng.randf() < 0.4):
						if rng.randf() < 0.6:
							box(Vector3(x + rng.randf_range(-w, w) * 0.25, c.y + 4.2 + int((h - 4.2) / 3.6) * 3.6 + 1.15, z + rng.randf_range(-d, d) * 0.25),
								Vector3(2.2, 1.1, 1.6), Color(0.6, 0.6, 0.6), false, 0.0, "metal")
						continue
					box(Vector3(x, c.y + h * 0.5, z), Vector3(w, h, d), facade, true, 0.0, "plaster")
					box(Vector3(x, c.y + 1.25, z), Vector3(w + 0.1, 2.5, d + 0.1), facade.darkened(0.45), false)
					box(Vector3(x, c.y + 2.68, z), Vector3(w + 0.7, 0.1, d + 0.7), FACADES[rng.randi() % FACADES.size()], false)
					var y := 3.8
					while y < h - 2.0:
						box(Vector3(x, c.y + y, z), Vector3(w + 0.08, 1.5, d + 0.08), GLASS, false, 0.0, "glass")
						y += 3.6
					box(Vector3(x, c.y + h + 0.12, z), Vector3(w + 0.16, 0.24, d + 0.16), TRIM, false)
					if rng.randf() < 0.6:
						box(Vector3(x + rng.randf_range(-w, w) * 0.25, c.y + h + 0.7, z + rng.randf_range(-d, d) * 0.25),
							Vector3(2.2, 1.1, 1.6), Color(0.6, 0.6, 0.6), false)
			# street trees
			var edge := BLOCK * 0.5 - 1.75
			for side in 4:
				for t in [-1, 0, 1]:
					var along: float = t * 10.5 + rng.randf_range(-0.8, 0.8)
					var p := c
					match side:
						0: p += Vector3(along, 0, edge)
						1: p += Vector3(along, 0, -edge)
						2: p += Vector3(edge, 0, along)
						_: p += Vector3(-edge, 0, along)
					_tree(p, rng.randf_range(0.8, 1.1), rng.randi() % 3)


func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for side in 4:
		var t := -170.0
		while t <= 170.0:
			var depth := 126.0 + rng.randf_range(0.0, 25.0)
			var h := rng.randf_range(25.0, 95.0)
			var col: Color = FACADES[rng.randi() % FACADES.size()].darkened(0.1)
			var p: Vector3
			match side:
				0: p = Vector3(t, h * 0.5, depth)
				1: p = Vector3(t, h * 0.5, -depth)
				2: p = Vector3(depth, h * 0.5, t)
				_: p = Vector3(-depth, h * 0.5, t)
			if not _far_building(p - Vector3(0, h * 0.5, 0), h, col, rng):
				box(p, Vector3(14, h, 14), col, false)
			t += 17.0


## Distant skyline: large modern facades, two bays a side, double-height floors (they are far away).
func _far_building(base: Vector3, h: float, col: Color, _rng: RandomNumberGenerator) -> bool:
	if not Props.has("facade_kit"):
		return false
	var floors := int(h / 7.2)
	for face in 4:
		var n := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][face] as Vector3
		var b := Basis(Vector3.UP, atan2(n.x, n.z)) * Basis.from_scale(Vector3(7.0 / 3.0, 2.0, 2.0))
		var along := n.cross(Vector3.UP) * -1.0
		for i in 2:
			for f in floors:
				scatter("facade_kit", Transform3D(b, base + n * 7.0 + along * (-3.5 + i * 7.0) + Vector3(0, f * 7.2, 0)),
					col.lightened(0.25), "bay_modern", true, false)
	box(base + Vector3(0, floors * 3.6, 0), Vector3(13.2, floors * 7.2, 13.2), col.darkened(0.3), false)
	return true


func _tree(base: Vector3, s: float, variant: int) -> void:
	if prop(["tree_oak", "tree_lime", "tree_young"][variant], base, randf() * 360.0, s * 0.9):
		blocker(base + Vector3(0, 1.5, 0), Vector3(0.45, 3.0, 0.45))
		return
	var leaf: Color = LEAVES[variant]
	shape_at("cylinder", base + Vector3(0, 1.6 * s, 0), Vector3(0.22, 3.2, 0.22) * s, BARK, true)
	shape_at("sphere", base + Vector3(0, 4.0 * s, 0), Vector3(3.2, 2.6, 3.2) * s, leaf)
	shape_at("sphere", base + Vector3(0.7, 5.0 * s, -0.4), Vector3(2.2, 2.0, 2.2) * s, leaf.lightened(0.1))
	shape_at("sphere", base + Vector3(-0.6, 3.3 * s, 0.6), Vector3(2.0, 2.0, 2.0) * s, leaf.darkened(0.1))


func _bench(center: Vector3, yaw: float) -> void:
	var r := Basis(Vector3.UP, deg_to_rad(yaw))
	if prop("bench", center, yaw + 180.0):
		box(center + r * Vector3(0, 0.45, 0), Vector3(1.9, 0.08, 0.5), Color(0, 0, 0, 0), true, yaw)
		return
	var slat := Color(0.5, 0.32, 0.18)
	box(center + r * Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.5), slat, true, yaw, "wood")
	box(center + r * Vector3(0, 0.75, -0.24), Vector3(1.8, 0.45, 0.06), slat, false, yaw, "wood")
	box(center + r * Vector3(-0.8, 0.22, 0), Vector3(0.06, 0.44, 0.46), METAL, false, yaw)
	box(center + r * Vector3(0.8, 0.22, 0), Vector3(0.06, 0.44, 0.46), METAL, false, yaw)


func _car(center: Vector3, yaw: float, color: Color) -> void:
	var r := Basis(Vector3.UP, deg_to_rad(yaw))
	if prop("car_%d" % (absi(hash(center)) % 5), center, yaw):
		blocker(center + Vector3(0, 0.75, 0), Vector3(4.4, 1.5, 1.8).rotated(Vector3.UP, deg_to_rad(yaw)).abs())
		return
	box(center + r * Vector3(0, 0.55, 0), Vector3(4.2, 0.7, 1.8), color, true, yaw, 0.35)
	box(center + r * Vector3(-0.2, 1.15, 0), Vector3(2.3, 0.55, 1.65), color, true, yaw, 0.35)
	box(center + r * Vector3(-0.2, 1.16, 0), Vector3(2.36, 0.38, 1.71), GLASS, false, yaw, 0.1)
	for w in [Vector3(1.3, 0.32, 0.9), Vector3(1.3, 0.32, -0.9), Vector3(-1.3, 0.32, 0.9), Vector3(-1.3, 0.32, -0.9)]:
		shape_at("cylinder", center + r * w, Vector3(0.64, 0.24, 0.64), Color(0.03, 0.03, 0.03), false, Vector3(90, yaw, 0))


func _lamp(base: Vector3) -> void:
	if prop("lamp_post", base, 0.0, 1.1):
		blocker(base + Vector3(0, 2.5, 0), Vector3(0.25, 5.0, 0.25))
		return
	shape_at("cylinder", base + Vector3(0, 2.5, 0), Vector3(0.12, 5.0, 0.12), METAL, true)
	box(base + Vector3(0, 5.05, 0), Vector3(0.4, 0.3, 0.4), METAL, false)
	box(base + Vector3(0, 4.86, 0), Vector3(0.32, 0.08, 0.32), Color(0.95, 0.92, 0.8), false)


func _crosswalk(center: Vector3, along_x: bool) -> void:
	for k in range(-4, 5):
		var off := Vector3(0, 0, k * 1.05) if along_x else Vector3(k * 1.05, 0, 0)
		var sz := Vector3(3, 0.02, 0.55) if along_x else Vector3(0.55, 0.02, 3)
		box(center + off + Vector3(0, 0.035, 0), sz, Color(0.85, 0.85, 0.82), false)


func _streets() -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var i := Vector3(sx * PITCH * 0.5, 0, sz * PITCH * 0.5)
			_crosswalk(i + Vector3(0, 0, 6.7), false)
			_crosswalk(i + Vector3(0, 0, -6.7), false)
			_crosswalk(i + Vector3(6.7, 0, 0), true)
			_crosswalk(i + Vector3(-6.7, 0, 0), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots := [[Vector3(-30, 0, -17.4), 0], [Vector3(-44, 0, 17.4), 0], [Vector3(9, 0, 17.4), 0],
		[Vector3(-17.4, 0, 33), 90], [Vector3(17.4, 0, -32), 90], [Vector3(17.4, 0, 42), 90],
		[Vector3(56, 0, 17.4), 0], [Vector3(-60, 0, -17.4), 0], [Vector3(-17.4, 0, -52), 90]]
	for s in spots:
		_car(s[0], s[1], (FACADES[rng.randi() % FACADES.size()] as Color).darkened(rng.randf_range(0.0, 0.4)))
	# the bus stop at the far end of the avenue
	var stop := Vector3(69.75, CURB, -31.5)
	box(stop + Vector3(0.6, 2.5, 0), Vector3(1.8, 0.1, 4.2), METAL)
	box(stop + Vector3(1.4, 1.25, 0), Vector3(0.06, 2.4, 4.0), Color(0.5, 0.62, 0.7), false, 0.0, 0.2)
	box(stop + Vector3(-0.2, 1.25, -2.05), Vector3(0.08, 2.5, 0.08), METAL)
	box(stop + Vector3(-0.2, 1.25, 2.05), Vector3(0.08, 2.5, 0.08), METAL)
	box(stop + Vector3(1.0, 0.45, 0), Vector3(0.45, 0.08, 3.0), METAL)


func _park() -> void:
	var inner := BLOCK - 2.0 * SIDEWALK
	box(Vector3(0, GRASS_Y - 0.01, 0), Vector3(inner, 0.02, inner), GRASS, false, 0.0, "grass")
	box(Vector3(0, GRASS_Y + 0.005, 0), Vector3(inner, 0.02, 2.6), PATH, false, 0.0, "concrete")
	box(Vector3(0, GRASS_Y + 0.02, 0), Vector3(2.6, 0.02, inner), PATH, false, 0.0, "concrete")
	# low hedges with gaps for the paths: real bushes when there are models, boxes otherwise
	var e := inner * 0.5
	var length := e - 2.2
	var grng := RandomNumberGenerator.new()
	grng.seed = 515
	var bushes := Props.has("bush")
	for s in [-1, 1]:
		var mid: float = s * (2.2 + length * 0.5)
		for seg in [[Vector3(mid, 0.5, e), Vector3(length, 0.8, 0.7)], [Vector3(mid, 0.5, -e), Vector3(length, 0.8, 0.7)],
				[Vector3(e, 0.53, mid), Vector3(0.68, 0.86, length - 0.02)], [Vector3(-e, 0.53, mid), Vector3(0.68, 0.86, length - 0.02)]]:
			var c: Vector3 = seg[0]
			var sz: Vector3 = seg[1]
			if not bushes:
				box(c, sz, LEAVES[2])
				continue
			blocker(c, sz)
			var along := Vector3(1, 0, 0) if sz.x > sz.z else Vector3(0, 0, 1)
			var len := maxf(sz.x, sz.z)
			var k := -len * 0.5 + 0.4
			while k < len * 0.5:
				var b := Basis(Vector3.UP, grng.randf() * TAU) * Basis.from_scale(Vector3.ONE * grng.randf_range(0.75, 1.0))
				scatter("bush", Transform3D(b, Vector3(c.x, GRASS_Y - 0.05, c.z) + along * k), Color.WHITE)
				k += 0.75
	# grass: thousands of clumps over the lawns
	for i in 3200:
		var gp := Vector3(grng.randf_range(-e, e), GRASS_Y - 0.02, grng.randf_range(-e, e))
		if surface_at(gp) == "grass" and Vector2(gp.x, gp.z).length() > 3.1:
			var gb := Basis(Vector3.UP, grng.randf() * TAU) * Basis.from_scale(Vector3(1.1, grng.randf_range(0.32, 0.55), 1.1) * grng.randf_range(0.8, 1.2))
			if not scatter("grass_clump", Transform3D(gb, gp), Color.WHITE, "", false, false):
				break
	# fountain
	shape_at("cylinder", Vector3(0, GRASS_Y + 0.25, 0), Vector3(5.2, 0.5, 5.2), STONE, true, Vector3.ZERO, "concrete")
	_fountain_water(Vector3(0, GRASS_Y + 0.47, 0), 2.4)
	shape_at("cylinder", Vector3(0, GRASS_Y + 1.0, 0), Vector3(0.6, 1.6, 0.6), STONE, true)
	shape_at("cylinder", Vector3(0, GRASS_Y + 1.75, 0), Vector3(2.0, 0.2, 2.0), STONE)
	_fountain_water(Vector3(0, GRASS_Y + 1.855, 0), 0.9)
	shape_at("sphere", Vector3(0, GRASS_Y + 2.15, 0), Vector3(0.35, 0.5, 0.35), WATER.lightened(0.3), false, Vector3.ZERO, 0.05)
	# trees
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for i in 26:
		var p := Vector3(rng.randf_range(-13, 13), GRASS_Y, rng.randf_range(-13, 13))
		if absf(p.x) < 3.2 or absf(p.z) < 3.2 or Vector2(p.x, p.z).length() < 7.0:
			continue
		if Vector2(p.x - 9.5, p.z - 9.5).length() < 5.0 or Vector2(p.x - 2.4, p.z + 9.0).length() < 4.0:
			continue
		_tree(p, rng.randf_range(0.9, 1.35), rng.randi() % 3)
	# benches
	_bench(Vector3(-9, GRASS_Y, 2.0), 180)
	_bench(Vector3(-5, GRASS_Y, -2.0), 0)
	_bench(Vector3(7, GRASS_Y, -2.0), 0)
	_bench(Vector3(2.0, GRASS_Y, 8), -90)
	_bench(Vector3(-2.0, GRASS_Y, -9), 90)
	for l in [Vector3(-10, GRASS_Y, -1.7), Vector3(10, GRASS_Y, 1.7), Vector3(1.7, GRASS_Y, -10), Vector3(-1.7, GRASS_Y, 10)]:
		_lamp(l)
	# the ice cream cart (out of ice cream)
	var cart := Vector3(2.4, GRASS_Y, -9.0)
	box(cart + Vector3(0, 0.7, 0), Vector3(2.8, 0.9, 1.2), Color(0.98, 0.95, 0.88))
	box(cart + Vector3(0, 1.08, 0), Vector3(2.84, 0.14, 1.24), Color(0.95, 0.5, 0.6), false)
	box(cart + Vector3(0, 1.19, 0), Vector3(2.0, 0.06, 1.0), Color(0.75, 0.85, 0.9), false, 0.0, 0.3)
	shape_at("cylinder", cart + Vector3(-1.0, 0.22, 0), Vector3(0.44, 1.3, 0.44), Color(0.1, 0.1, 0.1), false, Vector3(90, 0, 0))
	shape_at("cylinder", cart + Vector3(1.1, 2.0, -0.3), Vector3(0.05, 2.2, 0.05), TRIM)
	shape_at("cone", cart + Vector3(1.1, 3.3, -0.3), Vector3(2.8, 0.55, 2.8), Color(0.98, 0.62, 0.7))
	label(cart + Vector3(0, 0.75, 0.62), 0, "ICE CREAM", 0.22, Color(0.86, 0.35, 0.47), false)


## A disc of real water (the same shader as the pools), shallow and clear.
func _fountain_water(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 48
	disc.rings = 8
	mi.mesh = disc
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/water.gdshader")
	mat.set_shader_parameter("absorb", 0.6)
	mat.set_shader_parameter("wave_height", 0.004)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)


# ------------------------------------------------------------------ light

func _lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -130, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	# a perfect summer afternoon: deep blue overhead, hazy at the horizon, fair-weather clouds drifting
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/world/sky.gdshader")
	sky_mat.set_shader_parameter("zenith", Color(0.18, 0.4, 0.82))
	sky_mat.set_shader_parameter("horizon", Color(0.74, 0.84, 0.94))
	sky_mat.set_shader_parameter("cloud_cover", 0.42)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := make_env(Color(0.6, 0.7, 0.85), 0.6)
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# neutral ambient: sky-only ambient turned every shadow deep blue
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.86)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.92)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	if Settings.quality >= 1:
		env.ssil_enabled = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.004
		env.volumetric_fog_albedo = Color(1.0, 0.95, 0.88)
	environment(env)


# ------------------------------------------------------------------ characters

func _characters() -> void:
	# Mina, the ice cream vendor without ice cream.
	var mina := NPC.new()
	add_child(mina)
	mina.position = Vector3(2.4, GRASS_Y, -10.4)
	mina.rotation_degrees.y = 0
	mina.setup("mina", "Mina", "the ice cream vendor", {"skin": Color(0.86, 0.64, 0.5), "hair": Color(0.32, 0.16, 0.07),
		"shirt": Color(0.95, 0.55, 0.62), "pants": Color(0.2, 0.25, 0.42), "apron": true, "cap": true,
		"cap_color": Color(0.98, 0.98, 0.95), "height": 0.95, "hair_style": "bun", "build": 0.92})

	# Mr. Halvorsen, on the bench, with the pigeons.
	var arne := NPC.new()
	add_child(arne)
	arne.position = Vector3(-9, GRASS_Y, 2.05)
	arne.rotation_degrees.y = 180
	arne.setup("halvorsen", "Mr. Halvorsen", "the old man", {"skin": Color(0.84, 0.68, 0.58), "hair": Color(0.78, 0.78, 0.76),
		"shirt": Color(0.42, 0.47, 0.34), "pants": Color(0.33, 0.29, 0.24), "seated": true, "cap": true,
		"cap_color": Color(0.28, 0.28, 0.3), "sleeves": "long", "hair_style": "short", "build": 1.05,
		"shoes": Color(0.25, 0.15, 0.08)})
	for i in 7:
		var p := Vector3(-9 + randf_range(-1.7, 1.7), GRASS_Y + 0.06, randf_range(-0.9, 0.6))
		var bird := group(p, randf_range(0, 360))
		part("sphere", Vector3(0, 0.06, 0), Vector3(0.09, 0.09, 0.14), Color(0.42, 0.43, 0.47), bird)
		part("sphere", Vector3(0, 0.12, 0.07), Vector3.ONE * 0.055, Color(0.25, 0.3, 0.32), bird)
		_pigeons.append(bird)
		_pigeon_home.append(p)

	# Theo and his kite.
	_theo = NPC.new()
	add_child(_theo)
	_theo.position = Vector3(9.5, GRASS_Y, 9.5)
	_theo.rotation_degrees.y = 150
	_theo.setup("theo", "Theo", "the kid with the kite", {"skin": Color(0.58, 0.4, 0.28), "hair": Color(0.05, 0.04, 0.04),
		"shirt": Color(0.96, 0.8, 0.2), "pants": Color(0.25, 0.4, 0.62), "height": 0.68, "cap": true,
		"cap_color": Color(0.85, 0.15, 0.12), "hair_style": "curly", "build": 0.9, "shoes": Color(0.9, 0.9, 0.92)})
	_kite = group(Vector3(14, 15, 17))
	part("box", Vector3.ZERO, Vector3(0.9, 0.9, 0.03), Color(0.9, 0.2, 0.25), _kite, Vector3(0, 0, 45))
	part("box", Vector3(0, 0, 0.01), Vector3(0.5, 0.5, 0.02), Color(0.98, 0.85, 0.3), _kite, Vector3(0, 0, 45))
	for t in range(1, 6):
		part("box", Vector3(0, -0.6 - t * 0.3, 0), Vector3(0.12, 0.12, 0.02),
			Color(0.2, 0.5, 0.9) if t % 2 else Color(0.98, 0.98, 0.95), _kite, Vector3(0, 0, 45))
	_kite_line = part("cylinder", Vector3.ZERO, Vector3.ONE, Color(0.95, 0.95, 0.95))

	# The jogger, looping the park.
	var jog := NPC.new()
	add_child(jog)
	var e := BLOCK * 0.5 - 1.75
	jog.position = Vector3(-e, CURB, -e)
	jog.setup("jogger", "the jogger", "the jogger", {"skin": Color(0.74, 0.52, 0.38), "hair": Color(0.6, 0.42, 0.2),
		"shirt": Color(0.25, 0.72, 0.72), "pants": Color(0.08, 0.08, 0.1), "hair_style": "long",
		"shoes": Color(0.95, 0.4, 0.3)})
	jog.patrol = [Vector3(-e, CURB, -e), Vector3(e, CURB, -e), Vector3(e, CURB, e), Vector3(-e, CURB, e)]
	jog.patrol_speed = 3.3

	# The Observer: far end of the avenue, by the bus stop. Easy to overlook.
	_observer_spots = [Vector3(69.75, CURB, -27.8), Vector3(-69.75, CURB, 9.0), Vector3(-9.0, CURB, 69.75), Vector3(9.0, CURB, -69.75)]
	observer = Observer.new()
	add_child(observer)
	observer.global_position = _observer_spots[0]
	observer.seen_threshold = 0.6
	observer.seen_max_distance = 120.0
	observer.seen.connect(func():
		Game.set_flag("observer_noticed")
		Game.player.dread.add_dread(observer.spot_dread))
	observer.vanished.connect(func(): _observer_return = randf_range(35.0, 70.0))


# ------------------------------------------------------------------ runtime

func on_player_entered(_from_save: bool) -> void:
	_t = 0.0
	_hint_stage = 0
	_hint_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	_quest_update(delta)
	_hints(delta)
	_life(delta)
	# After vanishing, he comes back later - far away, somewhere you are not looking.
	if _observer_return > 0.0 and observer and not observer.is_present():
		_observer_return -= delta
		if _observer_return <= 0.0:
			var spots := _observer_spots.duplicate()
			spots.shuffle()
			_observer_return = 3.0   # retry soon if every spot is in view
			for spot in spots:
				if spot.distance_to(Game.player.global_position) > 40.0 and observer.try_appear_at(spot):
					_observer_return = -1.0
					break
	# You can never quite reach him.
	var p = Game.player
	if observer and p and not observer.has_pending() and observer.is_present():
		var dist := Vector2(p.global_position.x - observer.global_position.x, p.global_position.z - observer.global_position.z).length()
		if dist < 26.0:
			var best := _observer_spots[0]
			var best_d := -1.0
			for s in _observer_spots:
				var d := s.distance_to(p.global_position)
				if d > best_d:
					best_d = d
					best = s
			observer.request_relocation(best)


func _hints(delta: float) -> void:
	if Game.in_sequence:
		return
	_hint_t += delta
	match _hint_stage:
		0:
			if _t > 3.0:
				Game.hud.show_thought("...Okay. Okay. This is-- I'm dreaming. I'm actually dreaming.", 5.0)
				_hint_stage = 1
				_hint_t = 0.0
		1:
			if _hint_t > 6.0:
				if not Game.has_flag("manifest_first"):
					Game.hud.show_hint("You're lucid. Picture something. Something sweet.\nHold Q", 10.0)
				_hint_stage = 2
				_hint_t = 0.0
		2:
			if Game.has_flag("manifest_first") and _hint_t > 25.0:
				if not Game.has_flag("talked_any"):
					Game.hud.show_hint("The people here seem... real.\nE: talk", 8.0)
				_hint_stage = 3
				_hint_t = 0.0
			elif _hint_t > 60.0 and not Game.has_flag("manifest_first"):
				Game.hud.show_hint("Hold Q to picture something.", 6.0)
				_hint_t = 0.0
		3:
			if (Game.has_flag("talked_any") and _hint_t > 40.0) or _t > 300.0:
				Game.hud.show_hint("You can wake up whenever you like.\nHold T", 10.0)
				Game.set_flag("wake_hint")
				_hint_stage = 4


func _life(delta: float) -> void:
	# The pigeons stop when you ask the wrong question.
	if Game.has_flag("asked_lottery") and not _saw_lottery:
		_saw_lottery = true
		_pigeon_freeze = 30.0
	_pigeon_freeze = maxf(0.0, _pigeon_freeze - delta)
	if _pigeon_freeze <= 0.0:
		for i in _pigeons.size():
			var t := _t * 2.3 + i * 1.7
			var hop := maxf(0.0, sin(t * 2.0)) * 0.04
			_pigeons[i].position = _pigeon_home[i] + Vector3(sin(t * 0.21 + i) * 0.25, hop, cos(t * 0.17 + i * 2.0) * 0.25)
			_pigeons[i].rotation.y = i * 0.9 + sin(t * 0.4) * 1.2
	# birdsong, now and then
	if _t > _next_chirp:
		_next_chirp = _t + randf_range(1.5, 6.0)
		var p = Game.player
		if p:
			var where: Vector3 = p.global_position + Vector3(randf_range(-15, 15), randf_range(5, 10), randf_range(-15, 15))
			Sfx.play_at("chirp", self, where, -6.0, 40.0)
	# the kite sways; its string runs to Theo's hand
	if _kite:
		var kp := Vector3(14 + sin(_t * 0.4) * 1.6, 15 + sin(_t * 0.7) * 0.7, 17 + cos(_t * 0.33) * 1.2)
		_kite.position = kp
		_kite.rotation_degrees = Vector3(sin(_t * 1.1) * 10, 40, sin(_t * 0.9) * 15)
		if _theo and _theo.get_hand():
			var hand: Vector3 = _theo.get_hand().global_position
			var delta_v := kp - hand
			var length := delta_v.length()
			var up := delta_v / length
			var side := up.cross(Vector3.FORWARD).normalized()
			if side.length() < 0.1:
				side = Vector3.RIGHT
			var fwd := side.cross(up)
			_kite_line.global_transform = Transform3D(Basis(side, up, fwd).scaled(Vector3(0.006, length, 0.006)), hand + delta_v * 0.5)


func _find_spot_near(ppos: Vector3, min_d: float, max_d: float) -> Vector3:
	for attempt in 24:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		var p := ppos + dir * randf_range(min_d, max_d)
		if absf(p.x) > BOUNDS - 3 or absf(p.z) > BOUNDS - 3:
			continue
		p.y = ground_y(p, CURB)
		if p.y > CURB + 0.3:
			continue   # landed on a roof, a car or a bench: he stands on the ground
		var body := p + Vector3.UP * 0.95
		# unobserved now, but in plain sight the moment you turn around
		if not Observation.is_observed(body, 0.6) and Observation.has_line_of_sight(body):
			return p
	return Vector3.INF


func observer_event(event: String) -> void:
	if event != "closer" or observer == null or Game.player == null:
		return
	var p: Vector3 = Game.player.global_position
	var target := clampf(observer.global_position.distance_to(p) * 0.6, 27.0, 50.0)
	var spot := _find_spot_near(p, target * 0.85, target)
	if spot != Vector3.INF:
		_observer_spots.insert(0, spot)
		observer.request_relocation(spot)


# ------------------------------------------------------------------ the city's stages
# 1 Awakening (the dream bedroom)  2 The Neighbourhood: three landmarks  3 The Experiment: picture
# something, change two things  4 The Residents: talk, tell one of them  5 The Observer  6 The Exit:
# the hammock under the giant tree on the hill, visible over the rooftops from the park.

const HILL := Vector3(0, CURB, -84)
var _landmarks := {}
var _changes := {}
var _fountain_jets: Array[Node3D] = []
var _told_t := -1.0


func _quest() -> void:
	# landmarks: the fountain, the ice cream cart, the bus stop at the far end of the avenue
	for lm in [["fountain", Vector3(0, 1, 0), Vector3(9, 3, 9), "The fountain's dry. In a dream? I could fix that."],
			["cart", Vector3(2.4, 1, -9), Vector3(5, 3, 5), "An ice cream cart. Nobody's queuing."],
			["busstop", Vector3(69, 1, -31.5), Vector3(8, 3, 9), "The 3:12 bus. Every stop on the timetable says 3:12."]]:
		var id: String = lm[0]
		var line: String = lm[3]
		trigger(lm[1], lm[2], func():
			_landmarks[id] = true
			Game.counters["landmarks"] = _landmarks.size()
			Game.hud.show_thought(line, 4.0)
			if _landmarks.size() >= 3:
				Game.set_flag("city_landmarks"))
	label(Vector3(69.0, 2.2, -29.4), 180, "3:12  3:12  3:12  3:12", 0.08, Color(0.1, 0.1, 0.12), false)

	# things that can be changed by wanting them changed
	interactable(Vector3(0, GRASS_Y + 0.9, 2.7), Vector3(5.4, 1.4, 0.6), func(): return "" if _changes.has("fountain") else "Picture the fountain flowing",
		func(): _change("fountain"), func(): return not _changes.has("fountain"))
	interactable(Vector3(9, 0.9, 17.4), Vector3(4.4, 1.6, 2.2), func(): return "" if _changes.has("car") else "Picture it another colour",
		func(): _change("car"), func(): return not _changes.has("car"))
	interactable(Vector3(-10, GRASS_Y + 1.5, -1.7), Vector3(0.8, 3.0, 0.8), func(): return "" if _changes.has("lamps") else "Picture the lamps lit",
		func(): _change("lamps"), func(): return not _changes.has("lamps"))

	# the hill: a long grassy mound, the biggest tree in the city, a hammock in its shade
	var cone := CylinderMesh.new()
	cone.top_radius = 2.5
	cone.bottom_radius = 15.0
	cone.height = 3.6
	cone.radial_segments = 40
	var hill := MeshInstance3D.new()
	hill.mesh = cone
	hill.material_override = Shapes.surface("grass", GRASS)
	hill.position = HILL + Vector3(0, 1.8, 0)
	add_child(hill)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = cone.create_convex_shape()
	cs.position = hill.position
	body.add_child(cs)
	add_child(body)
	var top := HILL + Vector3(0, 3.6, 0)
	if not prop("tree_oak", top, 30.0, 4.6):
		_tree(top, 4.6, 0)
	blocker(top + Vector3(0, 3, 0), Vector3(1.4, 6, 1.4))
	var hrng := RandomNumberGenerator.new()
	hrng.seed = 9
	for i in 600:
		var a := hrng.randf() * TAU
		var r := sqrt(hrng.randf()) * 14.5
		var y := 3.6 * clampf((15.0 - r) / 12.5, 0.0, 1.0)
		var gb := Basis(Vector3.UP, hrng.randf() * TAU) * Basis.from_scale(Vector3(1.1, hrng.randf_range(0.35, 0.6), 1.1))
		if not scatter("grass_clump", Transform3D(gb, HILL + Vector3(cos(a) * r, y - 0.05, sin(a) * r)), Color.WHITE, "", false, false):
			break
	# hammock between the trunk and a post
	var post := top + Vector3(3.2, 0, 1.0)
	shape_at("cylinder", post + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), BARK, true, Vector3.ZERO, "wood")
	var a0 := top + Vector3(0.6, 1.35, 0.2)
	var a1 := post + Vector3(0, 1.5, 0)
	for k in 9:
		var f := float(k) / 8.0
		var p := a0.lerp(a1, f) + Vector3(0, -0.55 * sin(PI * f), 0)
		box(p, Vector3(0.42, 0.04, 0.95), Color(0.85, 0.45, 0.35), false, rad_to_deg(atan2(a1.x - a0.x, a1.z - a0.z)) + 90.0, "fabric")
	interactable(a0.lerp(a1, 0.5) + Vector3(0, -0.4, 0), Vector3(2.0, 1.0, 1.4), func(): return "Lie down in the hammock",
		func():
			if not Game.has_flag("observer_noticed"):
				Game.hud.show_thought("Not yet. There's more of the dream to see.", 3.0)
				return
			Game.hud.show_thought("Quiet. Just the leaves. ...Time to wake up.", 3.0)
			Game.request_wake())
	label(HILL + Vector3(0, 0.8, 14.0), 0, "THE HILL", 0.3, Color(0.2, 0.18, 0.14), false)
	Notebook.rule_broken.connect(_on_rule_broken)


func _change(what: String) -> void:
	if _changes.has(what) or not Game.player:
		return
	_changes[what] = true
	Game.counters["changes"] = _changes.size()
	Sfx.play("chime", -2.0, 0.7)
	Sfx.play("whoosh", -8.0, 1.8)
	Game.player.jolt(Vector3(-1, 0, 0))
	match what:
		"fountain":
			for k in 6:
				var a := k / 6.0 * TAU
				var jet := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.02
				c.bottom_radius = 0.05
				c.height = 1.3
				jet.mesh = c
				jet.material_override = Shapes.material(Color(0.75, 0.9, 1.0), 0.05, 0.6)
				jet.position = Vector3(cos(a) * 1.6, GRASS_Y + 1.1, sin(a) * 1.6)
				jet.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
				add_child(jet)
				_fountain_jets.append(jet)
			Game.hud.show_thought("It just... does what I want. I want it, and it is.", 4.0)
		"car":
			var tint := Color.from_hsv(randf(), 0.55, 0.8)
			for c in get_children():
				if c is Node3D and String(c.name).begins_with("car_") and (c as Node3D).global_position.distance_to(Vector3(9, 0, 17.4)) < 1.0:
					for mi in c.find_children("*", "MeshInstance3D", true, false):
						for si in mi.mesh.get_surface_count():
							var m: Material = mi.mesh.surface_get_material(si)
							if m and String(m.resource_name).ends_with("paint"):
								var nm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
								nm.albedo_color = tint
								mi.set_surface_override_material(si, nm)
			Game.hud.show_thought("Blue. No - that colour. Exactly that colour.", 3.5)
		"lamps":
			for l in [Vector3(-10, GRASS_Y, -1.7), Vector3(10, GRASS_Y, 1.7), Vector3(1.7, GRASS_Y, -10), Vector3(-1.7, GRASS_Y, 10)]:
				omni(l + Vector3(0, 4.7, 0), Color(1.0, 0.85, 0.6), 2.0, 9.0, false)
			Game.hud.show_thought("Lamps in broad daylight. Because I can.", 3.0)
	if _changes.size() >= 2:
		Game.set_flag("city_changed")


func _on_rule_broken(id: String) -> void:
	if id != "rule_tell" or Game.zone_type != "city":
		return
	# they all stop. they all look at you. then everything carries on as if nothing happened.
	_told_t = 4.0
	for c in get_children():
		if c is NPC:
			c.set_frozen(true)
	Sfx.stinger("whisper", -4.0)


func _quest_update(delta: float) -> void:
	var talked := 0
	for id in ["mina", "halvorsen", "theo", "jogger"]:
		if Game.has_flag("talked_" + id):
			talked += 1
	Game.counters["talked"] = talked
	if talked >= 3 and not Game.has_flag("city_talked"):
		Game.set_flag("city_talked")
	if _told_t > 0.0:
		_told_t -= delta
		if _told_t <= 0.0:
			for c in get_children():
				if c is NPC:
					c.set_frozen(false)
	for i in _fountain_jets.size():
		_fountain_jets[i].scale.y = 1.0 + 0.08 * sin(_t * 9.0 + i)
