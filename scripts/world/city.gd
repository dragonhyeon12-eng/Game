class_name CityZone
extends Zone
## The first dream: a warm, bright summer city that feels like the perfect lucid dream.
## Deliberately comforting - fear gains are heavily damped and nothing changes behind your back.
## The only thing out of place is a black figure at the far end of the avenue, easy to overlook.
##
## One long walk north that never looks like a line: the PARK (you wake here) -> the AVENUE, longer than it
## should be, ending at a wall painted with sky -> a jog east along a cross street -> the ARCADE, a glass-roofed
## passage that starts to smell of chlorine -> the LIDO, an open-air pool sunk in the middle of the city, the
## road running straight into it -> the STEPS, too many of them -> the PLAYGROUND on a terrace above the
## rooftops -> the gate -> the MEADOW, where the city simply stops, and the hill with the big tree.

const PITCH := 42.0
const BLOCK := 32.0
const SIDEWALK := 3.5
const CURB := 0.15
const HALF := 2
const GRASS_Y := 0.17
const BOUNDS := 109.0
const PARK := 28.0                        # the park block: x, z -28..28 (lawns to 26, the plaza in the middle)
const PLAZA_R := 15.0
const RING_OUT := 38.5                    # the ring road round the park, and its far pavement, end here
const VIADUCT_R := 100.0                  # the ring road in the sky, round the whole city
const VIADUCT_Y := 34.0
const LAMPS := [Vector3(2.9, CURB, -14.4), Vector3(-2.9, CURB, 14.4), Vector3(14.4, CURB, 2.9), Vector3(-14.4, CURB, -2.9),
	Vector3(-2.9, CURB, -14.4), Vector3(2.9, CURB, 14.4), Vector3(14.4, CURB, -2.9), Vector3(-14.4, CURB, 2.9)]
const CART := Vector3(6.5, CURB, 20.0)
const ARNE_BENCH := Vector3(-8.0, CURB, 8.6)
# the walk, south to north (y = ground height)
const AVE_X := 8.5                       # the avenue: x -8.5..8.5 (road -5..5), z -26..-110
const AVE_END := -110.0
const CROSS := Rect2(-8.5, -127.0, 70.5, 17.0)     # the cross street, running east (x, z, w, d)
const ARCADE := Rect2(39.0, -177.0, 10.0, 50.0)    # x 39..49, z -177..-127
const LIDO := Rect2(14.0, -252.0, 78.0, 75.0)      # the courtyard: x 14..92, z -252..-177
const POOL := Rect2(28.0, -216.0, 50.0, 21.0)      # x 28..78, z -216..-195
const POOL_FLOOR := -2.1
const LAWN := Rect2(14.0, -244.0, 78.0, 22.0)      # the lido lawn, north of the pool: z -244..-222
const STEPS := Rect2(44.0, -282.0, 20.0, 30.0)     # x 44..64, z -282..-252, rising to TOP_Y
const TOP_Y := 9.15
const TERRACE := Rect2(20.0, -318.0, 70.0, 36.0)   # the playground: x 20..90, z -318..-282, at TOP_Y
const MEADOW := Rect2(-40.0, -470.0, 190.0, 152.0) # x -40..150, z -470..-318, at TOP_Y
const CAR_SPOT := Vector3(3.0, 0, -70.0)
const BUS_STOP := Vector3(6.6, CURB, -104.0)
const KITE_BASE := Vector3(44, 21, -300)

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
	if absf(p.x) < PARK - 2.0 and absf(p.z) < PARK - 2.0 and absf(p.x) > 2.6 and absf(p.z) > 2.6 and Vector2(p.x, p.z).length() > PLAZA_R + 0.3:
		return "grass"
	var q := Vector2(p.x, p.z)
	if LAWN.has_point(q) or (MEADOW.has_point(q) and p.y > TOP_Y - 1.0):
		return "grass"
	return "concrete"


## The lido pool: you can swim in it.
func water_level_at(p: Vector3) -> float:
	if POOL.has_point(Vector2(p.x, p.z)) and p.y > POOL_FLOOR - 1.0 and p.y < 1.0:
		return 0.0
	return -INF
func fear_decay() -> float: return 5.0
func walk_speed() -> float: return 3.0
func sprint_speed() -> float: return 5.4


func player_start() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, 0.0), Vector3(0.0, CURB + 0.05, 24.0))     # on the south path, the fountain ahead


func build() -> void:
	_ground()
	_district()
	_avenue()
	_arcade()
	_lido()
	_steps()
	_playground()
	_meadow()
	_park()
	_viaduct()
	_skyline()
	_lighting()
	_characters()
	_quest()
	ambient("city", Vector3.ZERO, false, -14.0)
	_water = ambient("water", Vector3(0, 0.8, 0), true, -2.0, 22.0)
	ambient("water", Vector3(53, 0.5, -205), true, -6.0, 40.0)


# ------------------------------------------------------------------ geometry

func _ground() -> void:
	box(Vector3(0, -0.25, -200), Vector3(900, 0.5, 900), ASPHALT, true, 0.0, "asphalt")
	# the park block and the ring road round it
	box(Vector3(0, CURB * 0.5, 0), Vector3(PARK * 2.0, CURB, PARK * 2.0), PAVEMENT, true, 0.0, "pavers")
	for sgn in [-1.0, 1.0]:
		box(Vector3(0, CURB * 0.5, sgn * (RING_OUT - 1.75)), Vector3(RING_OUT * 2.0, CURB, 3.5), PAVEMENT, true, 0.0, "pavers")
		box(Vector3(sgn * (RING_OUT - 1.75), CURB * 0.5, 0), Vector3(3.5, CURB, RING_OUT * 2.0), PAVEMENT, true, 0.0, "pavers")
		_dashes(Vector3(0, 0, sgn * 31.5), Vector3(1, 0, 0), 66.0)
		_dashes(Vector3(sgn * 31.5, 0, 0), Vector3(0, 0, 1), 66.0)


## A dashed yellow centre line, `length` long, centred on `c`, along `dir`.
func _dashes(c: Vector3, dir: Vector3, length: float, y := 0.015) -> void:
	var t := -length * 0.5
	while t <= length * 0.5:
		var sz := Vector3(3, 0.02, 0.14) if absf(dir.x) > 0.5 else Vector3(0.14, 0.02, 3)
		box(c + dir * t + Vector3(0, y, 0), sz, Color(0.85, 0.75, 0.3), false)
		t += 6.0


## Pavement strip (a sidewalk) as a box, x0..x1, z0..z1, at height y.
func _walk(x0: float, x1: float, z0: float, z1: float, y := CURB, surf := "pavers", col := PAVEMENT) -> void:
	box(Vector3((x0 + x1) * 0.5, y - 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.3, z1 - z0), col, true, 0.0, surf)


# ------------------------------------------------------------------ the buildings that make the walls of the walk

## Every block of the city: [x0, x1, z0, z1, the sides that face the walk ("n" = -z ...), min height, max height]
const BLOCKS := [
	# round the park
	[-80.0, -RING_OUT, -RING_OUT, RING_OUT, "e", 50.0, 120.0, "glass"], [RING_OUT, 80.0, -RING_OUT, RING_OUT, "w", 50.0, 120.0, "glass"],
	[-80.0, 80.0, RING_OUT, 80.0, "n", 50.0, 120.0, "glass"],
	[-80.0, -8.5, -110.0, -RING_OUT, "es", 12.0, 30.0], [8.5, 80.0, -110.0, -RING_OUT, "wsn", 12.0, 30.0],
	# the cross street
	[-40.0, -8.5, -127.0, -110.0, "e", 14.0, 30.0], [62.0, 96.0, -127.0, -110.0, "w", 14.0, 30.0],
	[-40.0, 39.0, -177.0, -127.0, "sen", 16.0, 34.0], [49.0, 96.0, -177.0, -127.0, "swn", 16.0, 34.0],
	# round the lido
	[-20.0, 14.0, -252.0, -177.0, "e", 18.0, 32.0], [92.0, 126.0, -252.0, -177.0, "w", 18.0, 32.0],
	# the steps, between two tall blocks; then the terrace's flanks
	[14.0, 44.0, -282.0, -252.0, "sen", 20.0, 30.0], [64.0, 92.0, -282.0, -252.0, "swn", 20.0, 30.0],
	[-10.0, 20.0, -318.0, -282.0, "en", 18.0, 26.0], [90.0, 120.0, -318.0, -282.0, "wn", 18.0, 26.0],
]


func _district() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	for b in BLOCKS:
		_block(b[0], b[1], b[2], b[3], b[4], b[5], b[6], rng, b.size() > 7 and b[7] == "glass")


## A city block: buildings along the sides that face the walk (a strip ~16 m deep), plain roofs behind them.
func _block(x0: float, x1: float, z0: float, z1: float, sides: String, hmin: float, hmax: float, rng: RandomNumberGenerator, glass := false) -> void:
	var DEPTH := 22.0 if glass else 15.0
	var done := []    # rects already built (corners are shared by two sides)
	for side in sides:
		var along_x: bool = side == "n" or side == "s"
		var a0: float = x0 if along_x else z0
		var a1: float = x1 if along_x else z1
		var t := a0
		while t < a1 - 4.0:
			var w := minf(rng.randf_range(11.0, 17.0), a1 - t)
			if a1 - (t + w) < 6.0:
				w = a1 - t
			var c: Vector3
			var size: Vector2   # x, z
			match side:
				"s": c = Vector3(t + w * 0.5, CURB, z1 - DEPTH * 0.5); size = Vector2(w, DEPTH)
				"n": c = Vector3(t + w * 0.5, CURB, z0 + DEPTH * 0.5); size = Vector2(w, DEPTH)
				"e": c = Vector3(x1 - DEPTH * 0.5, CURB, t + w * 0.5); size = Vector2(DEPTH, w)
				_: c = Vector3(x0 + DEPTH * 0.5, CURB, t + w * 0.5); size = Vector2(DEPTH, w)
			t += w
			var r := Rect2(c.x - size.x * 0.5 + 0.5, c.z - size.y * 0.5 + 0.5, size.x - 1.0, size.y - 1.0)
			if done.any(func(o: Rect2): return o.intersects(r)):
				continue
			done.append(r)
			if glass:
				_glass_tower(c, size.x - 3.0, size.y - 3.0, rng.randf_range(hmin, hmax), rng)
			else:
				_building(c, size.x - 0.6, size.y - 0.6, rng.randf_range(hmin, hmax), rng)
	# behind the strip: roofs seen from the terrace, nothing more
	var inner := Rect2(x0 + DEPTH, z0 + DEPTH, (x1 - x0) - DEPTH * 2.0, (z1 - z0) - DEPTH * 2.0)
	if inner.size.x > 2.0 and inner.size.y > 2.0 and not glass:
		var h := rng.randf_range(hmin, hmax) * 0.8
		box(Vector3(inner.get_center().x, CURB + h * 0.5, inner.get_center().y), Vector3(inner.size.x, h, inner.size.y),
			(FACADES[rng.randi() % FACADES.size()] as Color).darkened(0.35), true, 0.0, "concrete")


static var _glass_mat: ShaderMaterial


## A glass skyscraper: a slab with a setback crown, mirror glass on a world-space curtain wall.
func _glass_tower(c: Vector3, w: float, d: float, h: float, rng: RandomNumberGenerator) -> void:
	if _glass_mat == null:
		_glass_mat = ShaderMaterial.new()
		_glass_mat.shader = load("res://scripts/world/glass_tower.gdshader")
	var tint := [Color(0.28, 0.42, 0.55), Color(0.3, 0.48, 0.55), Color(0.35, 0.42, 0.5), Color(0.25, 0.38, 0.52)][rng.randi() % 4] as Color
	var m := _glass_mat
	if rng.randf() < 0.5:
		m = _glass_mat.duplicate()
		m.set_shader_parameter("glass", tint)
	var crown := h * rng.randf_range(0.72, 0.85)
	for part_spec in [[Vector3(w, crown, d), crown * 0.5], [Vector3(w * 0.72, h - crown, d * 0.72), crown + (h - crown) * 0.5]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part_spec[0]
		mi.mesh = bm
		mi.material_override = m
		mi.position = c + Vector3(0, part_spec[1], 0)
		add_child(mi)
	blocker(c + Vector3(0, crown * 0.5, 0), Vector3(w, crown, d))
	# a podium at street level: stone, a canopy over the doors
	box(c + Vector3(0, 0.5, 0), Vector3(w + 0.4, 1.0, d + 0.4), Color(0.45, 0.46, 0.47), false, 0.0, "concrete")


func _building(c: Vector3, w: float, d: float, h: float, rng: RandomNumberGenerator) -> void:
	var facade: Color = FACADES[rng.randi() % FACADES.size()]
	var style: String = ["brick", "plaster", "plaster", "modern"][rng.randi() % 4]
	var tint := facade.lightened(0.15) if style == "plaster" else (Color(0.78, 0.5, 0.4) if style == "brick" else Color(0.82, 0.82, 0.8))
	if facade_building(c, w, d, maxi(1, int((h - 4.2) / 3.6)), style, tint, rng.randf() < 0.5):
		return
	box(Vector3(c.x, c.y + h * 0.5, c.z), Vector3(w, h, d), facade, true, 0.0, "plaster")
	var y := 3.8
	while y < h - 2.0:
		box(Vector3(c.x, c.y + y, c.z), Vector3(w + 0.08, 1.5, d + 0.08), GLASS, false, 0.0, "glass")
		y += 3.6


# ------------------------------------------------------------------ 2 the avenue

func _avenue() -> void:
	# road and sidewalks, from the park's ring road to the cross street
	_walk(-AVE_X, -5.0, AVE_END, -RING_OUT)
	_walk(5.0, AVE_X, AVE_END - 3.5, -RING_OUT)
	_dashes(Vector3(0, 0, (AVE_END - RING_OUT) * 0.5 - 4.0), Vector3(0, 0, 1), -AVE_END - RING_OUT + 4.0)
	_crosswalk(Vector3(0, 0, -RING_OUT - 3.0), false)
	_crosswalk(Vector3(0, 0, AVE_END - 2.0), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var z := -RING_OUT - 8.0
	while z > AVE_END + 4.0:
		_tree(Vector3(-AVE_X + 1.6, CURB, z), rng.randf_range(0.8, 1.05), rng.randi() % 3)
		_tree(Vector3(AVE_X - 1.6, CURB, z - 6.0), rng.randf_range(0.8, 1.05), rng.randi() % 3)
		if int(-z) % 24 < 12:
			_lamp(Vector3(-AVE_X + 0.8, CURB, z - 3.0))
		z -= 12.0
	for c in [[Vector3(-3.0, 0, -50.0), 90], [CAR_SPOT, 90], [Vector3(-3.0, 0, -88.0), 90], [Vector3(3.0, 0, -96.0), 90]]:
		_car(c[0], c[1], (FACADES[rng.randi() % FACADES.size()] as Color).darkened(rng.randf_range(0.0, 0.4)))
	# the cross street, running east; the avenue itself runs straight into a wall painted with sky
	_walk(CROSS.position.x, CROSS.end.x, CROSS.position.y, CROSS.position.y + 3.5)
	_walk(AVE_X, CROSS.end.x, CROSS.end.y - 3.5, CROSS.end.y)
	_dashes(Vector3(CROSS.get_center().x + 4.0, 0, CROSS.get_center().y), Vector3(1, 0, 0), CROSS.size.x - 8.0)
	_crosswalk(Vector3(44.0, 0, CROSS.get_center().y), true)
	for x in [20.0, 32.0, 56.0]:
		_lamp(Vector3(x, CURB, CROSS.position.y + 1.0))
	_sky_mural(Vector3(0, CURB, CROSS.position.y + 0.7))      # (in front of the facade bays)
	trigger(Vector3(0, 1.5, -64.0), Vector3(17, 3, 2), func():
		Game.hud.show_thought("Was the avenue always this long? ...It doesn't matter. It's lovely.", 4.0))
	trigger(Vector3(0, 1.5, AVE_END - 5.0), Vector3(17, 3, 4), func():
		Game.hud.show_thought("The street runs into the sky. ...No. That's a wall. Someone's painted sky on a wall.", 4.5))
	# the bus stop, at the end of the avenue
	if furnish("bus_shelter", BUS_STOP, 0.0):
		blocker(BUS_STOP + Vector3(1.39, 1.25, 0), Vector3(0.06, 2.4, 4.0))
		blocker(BUS_STOP + Vector3(1.0, 0.24, 0), Vector3(0.45, 0.48, 3.0))
	label(BUS_STOP + Vector3(1.35, 2.0, 0), -90, "3:12  3:12  3:12  3:12", 0.08, Color(0.1, 0.1, 0.12), false)


## A wall at the end of the avenue painted as the sky the street would run into: a gradient, clouds, the
## road's own lines continuing up it. From far off, the avenue just goes on into the blue.
func _sky_mural(base: Vector3) -> void:
	var w := 17.0
	var h := 16.0
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 zenith = vec3(0.18, 0.4, 0.82);
uniform vec3 horizon = vec3(0.74, 0.84, 0.94);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float y = 1.0 - UV.y;
	vec3 c = mix(horizon, zenith, smoothstep(0.0, 0.9, y));
	float cl = n(UV * vec2(6.0, 9.0)) * 0.6 + n(UV * vec2(13.0, 21.0)) * 0.4;
	c = mix(c, vec3(1.0), smoothstep(0.62, 0.8, cl) * smoothstep(0.15, 0.5, y) * 0.85);
	// the road, painted on: it narrows to the horizon line and stops
	float road = step(abs(UV.x - 0.5), 0.3 * (1.0 - y / 0.12)) * step(y, 0.12);
	c = mix(c, vec3(0.09, 0.095, 0.105), road);
	c = mix(c, vec3(0.85, 0.75, 0.3), road * step(abs(UV.x - 0.5), 0.006) * step(0.5, fract(y * 40.0)));
	ALBEDO = c;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.position = base + Vector3(0, h * 0.5 - 0.15, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ 3 the arcade

func _arcade() -> void:
	var r := ARCADE
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var mid := r.get_center().x
	# the floor: pavers, giving way to pool tiles for the last stretch
	var tiles_from := z0 + 14.0
	_walk(x0, x1, tiles_from, z1, CURB, "pavers")
	_walk(x0, x1, z0, tiles_from, CURB, "tiles_pool", Color(0.82, 0.88, 0.9))
	var h := 7.0
	# shopfronts down both sides, shuttered; the walls go pool-tiled at the far end too
	for side in [-1.0, 1.0]:
		var wx = mid + side * (r.size.x * 0.5 + 0.1)
		var k := z1 - 3.0
		var i := 0
		while k > z0 + 2.0:
			var tiled := k < tiles_from + 2.0
			var col := Color(0.82, 0.88, 0.9) if tiled else Color(0.62, 0.6, 0.56)
			box(Vector3(wx, h * 0.5 + CURB, k), Vector3(0.2, h, 0.6), col, true, 0.0, "tiles_pool" if tiled else "concrete")   # pilaster
			if not tiled:
				# a shutter, down; one in five lit and open, nothing on its shelves
				var open := i % 5 == 2
				box(Vector3(wx + side * 0.05, CURB + 1.6, k - 2.5), Vector3(0.08, 3.2, 4.2), Color(0.55, 0.57, 0.58) if not open else Color(0.95, 0.93, 0.85), true, 0.0, "metal" if not open else "plaster")
				box(Vector3(wx, CURB + 4.6, k - 2.5), Vector3(0.24, 2.6, 4.4), Color(0.85, 0.8, 0.72), true, 0.0, "plaster")
				if open:
					omni(Vector3(wx - side * 0.8, CURB + 2.6, k - 2.5), Color(1.0, 0.95, 0.85), 0.6, 5.0, false)
			else:
				box(Vector3(wx, CURB + h * 0.5, k - 2.5), Vector3(0.2, h, 4.4), col, true, 0.0, "tiles_pool")
			k -= 5.0
			i += 1
	# the glass roof on its frames
	for zz in range(int(z1) - 2, int(z0), -5):
		box(Vector3(mid, CURB + h, zz), Vector3(r.size.x + 0.6, 0.25, 0.18), Color(0.2, 0.22, 0.2), false, 0.0, "metal")
	box(Vector3(mid, CURB + h + 0.15, (z0 + z1) * 0.5), Vector3(r.size.x + 0.6, 0.04, r.size.y), Color(0.75, 0.85, 0.85), false, 0.0, "glass")
	box(Vector3(mid, CURB + h + 0.05, (z0 + z1) * 0.5), Vector3(0.2, 0.2, r.size.y), Color(0.2, 0.22, 0.2), false, 0.0, "metal")
	# hanging lights, on in the middle of the day
	var k2 := z1 - 6.0
	while k2 > z0:
		prop("pendant_lamp", Vector3(mid, CURB + h, k2), 0.0)
		k2 -= 10.0
	# benches down the middle, a bin, and a pool's depth sign where a shop sign should be
	_bench(Vector3(x0 + 1.4, CURB, z1 - 14.0), -90)
	_bench(Vector3(x1 - 1.4, CURB, z1 - 28.0), 90)
	label(Vector3(x0 + 0.25, CURB + 4.8, tiles_from - 6.0), 90, "DEPTH 1.2 m", 0.25, Color(0.1, 0.3, 0.6), false)
	label(Vector3(x1 - 0.25, CURB + 4.8, tiles_from + 8.0), -90, "NO RUNNING", 0.25, Color(0.75, 0.1, 0.08), false)
	trigger(Vector3(mid, 1.5, z1 - 4.0), Vector3(r.size.x, 3, 2), func():
		Game.hud.show_thought("An arcade. Every shop's shut. ...On a summer afternoon?", 3.5))
	trigger(Vector3(mid, 1.5, tiles_from + 4.0), Vector3(r.size.x, 3, 2), func():
		Game.hud.show_thought("Chlorine. It smells like the swimming baths in here.", 3.5))


# ------------------------------------------------------------------ 4 the lido

func _lido() -> void:
	var c := LIDO
	# the deck, all pool tiles, the whole courtyard: and the lawn beyond the water
	var deck := Color(0.62, 0.66, 0.67)     # (white tiles in full sun: kept a touch grey, or they glare)
	_walk(c.position.x, c.end.x, POOL.end.y, c.end.y, CURB, "tiles_floor", deck)                      # south deck
	_walk(c.position.x, c.end.x, LAWN.end.y, POOL.position.y, CURB, "tiles_pool", deck)                # north deck
	_walk(c.position.x, POOL.position.x, POOL.position.y, POOL.end.y, CURB, "tiles_pool", deck)
	_walk(POOL.end.x, c.end.x, POOL.position.y, POOL.end.y, CURB, "tiles_pool", deck)
	_walk(LAWN.position.x, LAWN.end.x, LAWN.position.y, LAWN.end.y, CURB, "grass", GRASS)
	_walk(c.position.x, c.end.x, c.position.y, LAWN.position.y, CURB, "tiles_floor", deck)             # the strip to the steps
	# the pool: a tiled basin, still water
	var pc := POOL.get_center()
	box(Vector3(pc.x, POOL_FLOOR - 0.2, pc.y), Vector3(POOL.size.x, 0.4, POOL.size.y), Color(0.75, 0.86, 0.9), true, 0.0, "tiles_pool")
	var wall_h := CURB - POOL_FLOOR
	for e in [[Vector3(pc.x, 0, POOL.position.y - 0.15), Vector3(POOL.size.x + 0.6, 0, 0.3)], [Vector3(pc.x, 0, POOL.end.y + 0.15), Vector3(POOL.size.x + 0.6, 0, 0.3)],
			[Vector3(POOL.position.x - 0.15, 0, pc.y), Vector3(0.3, 0, POOL.size.y)], [Vector3(POOL.end.x + 0.15, 0, pc.y), Vector3(0.3, 0, POOL.size.y)]]:
		var at: Vector3 = e[0]
		var sz: Vector3 = e[1]
		box(Vector3(at.x, POOL_FLOOR + wall_h * 0.5, at.z), Vector3(sz.x, wall_h, sz.z), Color(0.75, 0.86, 0.9), true, 0.0, "tiles_pool")
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = POOL.size
	plane.subdivide_width = 60
	plane.subdivide_depth = 24
	water.mesh = plane
	var wm := ShaderMaterial.new()
	wm.shader = load("res://scripts/world/water.gdshader" if Settings.quality >= 1 else "res://scripts/world/water_lite.gdshader")
	wm.set_shader_parameter("wave_height", 0.002)      # (dead still: no foam, no chop, a clean blue)
	wm.set_shader_parameter("foam_amount", 0.0)
	wm.set_shader_parameter("wave_speed", 0.08)
	wm.set_shader_parameter("refraction", 0.012)
	wm.set_shader_parameter("absorb", 0.32)
	wm.set_shader_parameter("deep", Color(0.05, 0.45, 0.62))
	wm.set_shader_parameter("shallow", Color(0.55, 0.9, 0.95))
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(pc.x, 0.0, pc.y)
	add_child(water)
	# lanes on the bottom, ropes on top
	for k in 5:
		var lz := POOL.position.y + 3.5 * (k + 1)
		box(Vector3(pc.x, POOL_FLOOR + 0.01, lz + 1.75 - 3.5), Vector3(POOL.size.x - 4.0, 0.02, 0.3), Color(0.08, 0.12, 0.3), false)
		for seg in 5:
			scatter_prop("lane_rope", Vector3(POOL.position.x + 5.0 + seg * 10.0, 0.0, lz), 0.0)
	# the road from the arcade runs straight across the deck and on into the water, along the bottom
	var road_x := ARCADE.get_center().x
	for k in range(int(LIDO.end.y) - 1, int(POOL.position.y) - 30, -6):
		var y := CURB + 0.01 if k > POOL.end.y else POOL_FLOOR + 0.015
		if k < POOL.position.y and k > POOL.position.y - 1.0:
			continue
		if k < POOL.position.y:
			y = CURB + 0.01
		box(Vector3(road_x, y, k), Vector3(0.14, 0.02, 3.0), Color(0.85, 0.75, 0.3), false)
	_crosswalk(Vector3(road_x, CURB - 0.02, POOL.end.y + 4.0), false)
	_crosswalk(Vector3(road_x, POOL_FLOOR, pc.y + 2.0), false)
	# a street lamp standing in the deep end, lit; a car parked on the bottom
	_lamp(Vector3(66.0, POOL_FLOOR, -204.0))
	omni(Vector3(66.0, 5.0, -204.0), Color(1.0, 0.85, 0.6), 1.2, 9.0, false)
	prop("car_3", Vector3(57.0, POOL_FLOOR, -210.5), 80.0)
	# poolside: starting blocks at the shallow end, the diving tower at the deep end, a lifeguard's chair
	for k in 6:
		scatter_prop("starting_block", Vector3(POOL.position.x - 0.45, CURB, POOL.position.y + 1.75 + k * 3.5), 90.0)
	furnish("diving_tower", Vector3(POOL.end.x - 3.5, CURB, POOL.position.y - 0.9), 0.0, Vector3(2.4, 5.0, 0.6), Vector3(0, 2.5, -0.75))
	furnish("lifeguard_chair", Vector3(pc.x, CURB, POOL.end.y + 1.6), 180.0, Vector3(1.0, 2.0, 1.0), Vector3(0, 1.0, 0))
	for x in [POOL.position.x + 2.0, POOL.end.x - 2.0]:
		prop("pool_ladder", Vector3(x, CURB, POOL.end.y), 180.0)
		prop("pool_ladder", Vector3(x, CURB, POOL.position.y), 0.0)
	# ...and pool ladders going down into the lawn
	for x in [30.0, 52.0, 76.0]:
		prop("pool_ladder", Vector3(x, CURB, LAWN.end.y - 0.2), 180.0)
	var sign := prop("pool_sign", Vector3(POOL.position.x + 6.0, CURB, POOL.end.y + 1.2), 180.0)
	if sign:
		label(sign.position + Vector3(0, 1.6, -0.04), 180, "NO DIVING\nDEPTH 1.2 m", 0.09, Color(0.1, 0.1, 0.12), false)
	prop("lifebuoy_post", Vector3(POOL.end.x + 2.5, CURB, POOL.end.y + 1.5), 200.0)
	# changing cabins in a row along the south side
	var x := c.position.x + 3.0
	while x < c.end.x - 2.0:
		if absf(x - road_x) > 4.0:
			if scatter_prop("changing_cabin", Vector3(x, CURB, c.end.y - 1.2), 180.0):
				blocker(Vector3(x, CURB + 1.2, c.end.y - 1.2), Vector3(1.3, 2.4, 1.3))
		x += 1.5
	# loungers and parasols on the lawn, set out for people who aren't coming
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	for k in 9:
		var lx := LAWN.position.x + 6.0 + k * 8.0
		var lz := LAWN.get_center().y + rng.randf_range(-3.0, 3.0)
		scatter_prop("deckchair", Vector3(lx, CURB, lz), 180.0 + rng.randf_range(-10, 10))
		scatter_prop("deckchair", Vector3(lx + 1.0, CURB, lz), 180.0 + rng.randf_range(-10, 10))
		if k % 2 == 0:
			prop("parasol", Vector3(lx + 0.5, CURB, lz - 1.4), 0.0)
	for i in 1400:
		var gp := Vector3(rng.randf_range(LAWN.position.x, LAWN.end.x), CURB - 0.02, rng.randf_range(LAWN.position.y, LAWN.end.y))
		var gb := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.1, rng.randf_range(0.3, 0.5), 1.1))
		if not scatter("grass_clump", Transform3D(gb, gp), Color.WHITE, "", false, false):
			break
	trigger(Vector3(road_x, 1.5, LIDO.end.y - 3.0), Vector3(10, 3, 2), func():
		Game.hud.show_thought("A swimming pool. In the middle of the city. Under the sky. ...Of course there is.", 4.5))
	trigger(Vector3(road_x, 1.5, POOL.end.y + 3.0), Vector3(8, 3, 2), func():
		Game.hud.show_thought("The road goes straight into the water. Lines and all.", 3.5))


# ------------------------------------------------------------------ 5 the steps

func _steps() -> void:
	var r := STEPS
	var n := 31
	var run := r.size.y / n
	var rise := (TOP_Y - CURB) / n
	for k in n:
		var y := CURB + rise * (k + 1)
		var z := r.end.y - run * (k + 0.5)
		box(Vector3(r.get_center().x, y * 0.5, z), Vector3(r.size.x, y, run), Color(0.78, 0.76, 0.72), false, 0.0, "concrete")
	# you walk up a ramp (the steps are for looking at)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var length := Vector2(r.size.y, TOP_Y - CURB).length()
	bs.size = Vector3(r.size.x, 0.2, length)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(r.get_center().x, (CURB + TOP_Y) * 0.5 - 0.1, r.get_center().y)
	body.rotation.x = atan2(TOP_Y - CURB, r.size.y)     # (rising to the north, -z)
	add_child(body)
	# handrails up the middle
	for k in 6:
		var z := r.end.y - k * 5.0 - 2.5
		var y := CURB + (r.end.y - z) / r.size.y * (TOP_Y - CURB)
		prop("wood_post", Vector3(r.get_center().x, y - 0.1, z), 0.0, 0.6)
	trigger(Vector3(r.get_center().x, 3.0, r.get_center().y), Vector3(r.size.x, 8, 2), func():
		Game.hud.show_thought("Ninety-eight. Ninety-nine. ...I didn't think there'd be this many.", 4.0))


# ------------------------------------------------------------------ 6 the playground, on a terrace above the roofs

func _playground() -> void:
	var r := TERRACE
	box(Vector3(r.get_center().x, TOP_Y * 0.5, r.get_center().y), Vector3(r.size.x, TOP_Y, r.size.y), Color(0.62, 0.6, 0.56), true, 0.0, "pavers")
	# the play area: soft red ground, a low fence of coloured pickets
	var pa := Rect2(28.0, -314.0, 52.0, 26.0)
	box(Vector3(pa.get_center().x, TOP_Y + 0.01, pa.get_center().y), Vector3(pa.size.x, 0.02, pa.size.y), Color(0.34, 0.17, 0.15), false, 0.0, "concrete")
	var fx := pa.position.x + 1.0
	while fx < pa.end.x:
		if absf(fx - 55.0) > 2.0:
			scatter_prop("play_fence", Vector3(fx, TOP_Y, pa.end.y), 0.0)
		scatter_prop("play_fence", Vector3(fx, TOP_Y, pa.position.y), 0.0)
		fx += 2.0
	var fz := pa.position.y + 1.0
	while fz < pa.end.y:
		scatter_prop("play_fence", Vector3(pa.position.x, TOP_Y, fz), 90.0)
		scatter_prop("play_fence", Vector3(pa.end.x, TOP_Y, fz), 90.0)
		fz += 2.0
	for s in [[Vector2(pa.get_center().x, pa.end.y), Vector3(pa.size.x, 1.2, 0.2), false], [Vector2(pa.get_center().x, pa.position.y), Vector3(pa.size.x, 1.2, 0.2), true],
			[Vector2(pa.position.x, pa.get_center().y), Vector3(0.2, 1.2, pa.size.y), false], [Vector2(pa.end.x, pa.get_center().y), Vector3(0.2, 1.2, pa.size.y), false]]:
		if s[2]:
			continue      # (the north side is open: the gate to the meadow is there)
		var at: Vector2 = s[0]
		var size: Vector3 = s[1]
		if size.x > 1.0:    # the south fence has a gap where you come in
			var gap := 55.0
			blocker(Vector3((pa.position.x + gap - 1.8) * 0.5, TOP_Y + 0.6, at.y), Vector3(gap - 1.8 - pa.position.x, 1.2, 0.2))
			blocker(Vector3((pa.end.x + gap + 1.8) * 0.5, TOP_Y + 0.6, at.y), Vector3(pa.end.x - gap - 1.8, 1.2, 0.2))
		else:
			blocker(Vector3(at.x, TOP_Y + 0.6, at.y), size)
	furnish("swing_set", Vector3(36.0, TOP_Y, -300.0), 0.0, Vector3(3.2, 2.4, 0.2), Vector3(0, 1.2, 0))
	furnish("slide", Vector3(48.0, TOP_Y, -306.0), 30.0, Vector3(0.8, 2.4, 0.8), Vector3(0, 1.2, -0.7))
	furnish("climbing_dome", Vector3(64.0, TOP_Y, -296.0), 0.0, Vector3(3.0, 1.5, 3.0), Vector3(0, 0.75, 0))
	prop("sandbox", Vector3(72.0, TOP_Y, -306.0), 15.0)
	_roundabout = prop("roundabout", Vector3(40.0, TOP_Y, -294.0), 0.0)
	prop("seesaw", Vector3(58.0, TOP_Y, -310.0), 10.0)
	prop("spring_rider", Vector3(70.0, TOP_Y, -294.0), 200.0)
	prop("spring_rider", Vector3(72.5, TOP_Y, -295.5), 160.0)
	for b in [[Vector3(30.0, TOP_Y, -286.5), 0], [Vector3(76.0, TOP_Y, -286.5), 0]]:
		_bench(b[0], b[1])
	trigger(Vector3(55.0, TOP_Y + 1.5, -284.5), Vector3(20, 3, 2), func():
		Game.hud.show_thought("A playground. Up here, above the roofs. ...Nobody on the swings. The roundabout's still turning.", 4.5))
	# the gate out, on the north side
	prop("park_gate", Vector3(55.0, TOP_Y, r.position.y), 0.0)
	for side in [-1.0, 1.0]:
		blocker(Vector3(55.0 + side * 1.7, TOP_Y + 1.4, r.position.y), Vector3(0.6, 2.8, 0.6))
	# the terrace's north edge: railings, and the gate the only way through
	blocker(Vector3((r.position.x + 53.3) * 0.5, TOP_Y + 0.6, r.position.y), Vector3(53.3 - r.position.x, 1.2, 0.2))
	blocker(Vector3((r.end.x + 56.7) * 0.5, TOP_Y + 0.6, r.position.y), Vector3(r.end.x - 56.7, 1.2, 0.2))
	var rx := r.position.x + 1.0
	while rx < r.end.x:
		if absf(rx - 55.0) > 2.5:
			scatter_prop("play_fence", Vector3(rx, TOP_Y, r.position.y), 0.0)
		rx += 2.0


var _roundabout: Node3D


# ------------------------------------------------------------------ 7 the meadow, where the city stops

const HILL := Vector3(55, TOP_Y, -400)


func _meadow() -> void:
	var r := MEADOW
	box(Vector3(r.get_center().x, TOP_Y * 0.5, r.get_center().y), Vector3(r.size.x, TOP_Y, r.size.y), GRASS, true, 0.0, "grass")
	# the edges: you can't walk off the world (and nobody would want to)
	for e in [[Vector3(r.get_center().x, TOP_Y + 5, r.position.y), Vector3(r.size.x, 10, 1)],
			[Vector3(r.position.x, TOP_Y + 5, r.get_center().y), Vector3(1, 10, r.size.y)], [Vector3(r.end.x, TOP_Y + 5, r.get_center().y), Vector3(1, 10, r.size.y)],
			[Vector3((r.position.x + TERRACE.position.x) * 0.5, TOP_Y + 5, r.end.y), Vector3(TERRACE.position.x - r.position.x, 10, 1)],
			[Vector3((TERRACE.end.x + r.end.x) * 0.5, TOP_Y + 5, r.end.y), Vector3(r.end.x - TERRACE.end.x, 10, 1)]]:
		blocker(e[0], e[1])
	# a path through the grass from the gate to the hill
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var a := Vector3(55.0, TOP_Y, r.end.y)
	var b := HILL + Vector3(0, 0, 15.0)
	var n := 48
	for k in n:
		var t := k / float(n - 1)
		var p := a.lerp(b, t) + Vector3(sin(t * PI * 1.5) * 9.0, 0, 0)
		var dx := cos(t * PI * 1.5) * PI * 1.5 * 9.0      # d/dt of the sideways swing
		var dz := b.z - a.z
		box(Vector3(p.x, TOP_Y + 0.005, p.z), Vector3(2.2, 0.02, 2.4), PATH, false, rad_to_deg(atan2(dx, dz)), "concrete")
	# grass, a few trees, wildflowers
	for i in 5000:
		var gp := Vector3(rng.randf_range(r.position.x + 20.0, r.end.x - 20.0), TOP_Y - 0.02, rng.randf_range(r.position.y + 15.0, r.end.y))
		var gb := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.1, rng.randf_range(0.4, 0.7), 1.1))
		if not scatter("grass_clump", Transform3D(gb, gp), Color.WHITE, "", false, false):
			break
	for i in 700:
		var gp := Vector3(rng.randf_range(r.position.x + 20.0, r.end.x - 20.0), TOP_Y - 0.05, rng.randf_range(r.position.y + 15.0, r.end.y))
		if not scatter("grass_tall", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.0)), gp), Color.WHITE, "", false, false):
			break
	for i in 14:
		var tp := Vector3(rng.randf_range(r.position.x + 15.0, r.end.x - 15.0), TOP_Y, rng.randf_range(r.position.y + 15.0, r.end.y - 25.0))
		if tp.distance_to(HILL) < 22.0 or absf(tp.x - 55.0) < 14.0:
			continue
		_tree(tp, rng.randf_range(1.0, 1.5), rng.randi() % 3)
	# things that don't belong in a field: a street lamp, lit; a swing hanging from nothing, high as the clouds
	_lamp(Vector3(26.0, TOP_Y, -372.0))
	omni(Vector3(26.0, TOP_Y + 5.0, -372.0), Color(1.0, 0.85, 0.6), 1.0, 8.0, false)
	prop("pool_ladder", Vector3(92.0, TOP_Y, -352.0), 140.0)
	_sky_swing = group(Vector3(80.0, TOP_Y + 40.0, -385.0))
	var chain := CylinderMesh.new()
	chain.top_radius = 0.012
	chain.bottom_radius = 0.012
	chain.height = 39.3
	chain.radial_segments = 4
	for dx in [-0.22, 0.22]:
		var mi := MeshInstance3D.new()
		mi.mesh = chain
		mi.material_override = Shapes.material(Color(0.7, 0.7, 0.72), 0.3, 0.0, 0.9)
		mi.position = Vector3(dx, -19.65, 0)
		_sky_swing.add_child(mi)
	part("box", Vector3(0, -39.3, 0), Vector3(0.55, 0.04, 0.2), Color(0.3, 0.2, 0.12), _sky_swing, Vector3.ZERO, 0.0, "wood")
	trigger(Vector3(55.0, TOP_Y + 1.5, r.end.y - 4.0), Vector3(8, 3, 2), func():
		Game.hud.show_thought("The city just... stops. Grass, all the way to the sky.", 4.0))
	trigger(Vector3(80.0, TOP_Y + 1.5, -385.0), Vector3(10, 3, 10), func():
		Game.hud.show_thought("A swing. The chains go up... and up. ...What's it hanging from?", 4.0))


var _sky_swing: Node3D


func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# towers all round the walk's south half (the meadow, to the north, has only sky)
	for side in 3:
		var t := -260.0 if side >= 1 else -110.0
		var t_end := 60.0 if side >= 1 else 170.0
		while t <= t_end:
			var h := rng.randf_range(25.0, 95.0)
			var col: Color = FACADES[rng.randi() % FACADES.size()].darkened(0.1)
			var p: Vector3
			match side:
				0: p = Vector3(t, h * 0.5, 90.0 + rng.randf_range(0.0, 25.0))
				1: p = Vector3(-90.0 - rng.randf_range(0.0, 25.0), h * 0.5, t)
				_: p = Vector3(150.0 + rng.randf_range(0.0, 25.0), h * 0.5, t)
			var rr := Vector2(p.x, p.z).length()
			if rr > VIADUCT_R - 14.0 and rr < VIADUCT_R + 14.0:
				t += 19.0
				continue      # (the ring road in the sky passes here)
			if not _far_building(p - Vector3(0, h * 0.5, 0), h, col, rng):
				box(p, Vector3(14, h, 14), col, false)
			t += 19.0


## Distant skyline: large modern facades, two bays a side, double-height floors (they are far away).
func _far_building(base: Vector3, h: float, col: Color, _rng: RandomNumberGenerator) -> bool:
	if not Props.has("facade_kit") or Settings.quality < 1:     # (LOW graphics: plain blocks, far away)
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
	if scatter_prop(["tree_oak", "tree_lime", "tree_young"][variant], base, randf() * 360.0, s * 0.9):
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


func _park() -> void:
	var lawn := PARK - 2.0
	# four lawns, a cross of paths, and in the middle a round plaza of polished stone
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(Vector3(sx * (lawn + 2.6) * 0.5, GRASS_Y - 0.01, sz * (lawn + 2.6) * 0.5), Vector3(lawn - 2.6, 0.02, lawn - 2.6), GRASS, false, 0.0, "grass")
	var stone := ShaderMaterial.new()
	stone.shader = load("res://scripts/world/plaza_stone.gdshader")
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_R
	disc.bottom_radius = PLAZA_R
	disc.height = 0.06
	disc.radial_segments = 72
	var plaza := MeshInstance3D.new()
	plaza.mesh = disc
	plaza.material_override = stone
	plaza.position = Vector3(0, CURB + 0.0, 0)
	add_child(plaza)
	for path in [[Vector3(0, CURB, (PLAZA_R + PARK) * 0.5), Vector3(5.2, 0.06, PARK - PLAZA_R + 0.5)], [Vector3(0, CURB, -(PLAZA_R + PARK) * 0.5), Vector3(5.2, 0.06, PARK - PLAZA_R + 0.5)],
			[Vector3((PLAZA_R + PARK) * 0.5, CURB, 0), Vector3(PARK - PLAZA_R + 0.5, 0.06, 5.2)], [Vector3(-(PLAZA_R + PARK) * 0.5, CURB, 0), Vector3(PARK - PLAZA_R + 0.5, 0.06, 5.2)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = path[1]
		mi.mesh = bm
		mi.material_override = stone
		mi.position = path[0]
		add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	# the fountain, and its water
	_fountain_build()
	# round the plaza: planters of white hydrangeas, benches in front of them facing the fountain, lantern lamps
	for k in 4:
		for side in [-1.0, 1.0]:
			var a := deg_to_rad(k * 90.0 + side * 27.0)
			var dir := Vector3(sin(a), 0, cos(a))
			var yaw := rad_to_deg(a) + 90.0
			var pc := dir * (PLAZA_R - 1.6)
			if furnish("planter_hydrangea", Vector3(pc.x, CURB, pc.z), yaw, Vector3(3.6, 0.6, 1.1).rotated(Vector3.UP, deg_to_rad(yaw)).abs(), Vector3(0, 0.3, 0)):
				pass
			var bp := dir * (PLAZA_R - 3.1)
			var bench_yaw := rad_to_deg(atan2(-dir.x, -dir.z))
			if Vector3(bp.x, CURB, bp.z).distance_to(ARNE_BENCH) > 1.0:
				_bench_classic(Vector3(bp.x, CURB, bp.z), bench_yaw)
	_bench_classic(ARNE_BENCH, rad_to_deg(atan2(-ARNE_BENCH.x, -ARNE_BENCH.z)))
	for l in LAMPS:
		_lantern(l)
	# the rotunda, on the north-west lawn (on the left of the fountain as you come in), with a path to it
	var rot := Vector3(-16.0, CURB, -15.0)
	if furnish("rotunda", rot, 20.0, Vector3.ZERO):
		var body := StaticBody3D.new()
		add_child(body)
		body.position = rot
		var steps := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 3.9
		cy.height = 0.54
		steps.shape = cy
		steps.position = Vector3(0, 0.27 - 0.27, 0)
		body.add_child(steps)
		for k in 8:
			var a := 2.0 * PI * k / 8.0 + PI / 8.0 + deg_to_rad(20.0)
			blocker(rot + Vector3(cos(a) * 3.0, 2.3, -sin(a) * 3.0), Vector3(0.45, 3.5, 0.45))
	var to_rot := rot.normalized()
	for k in 7:
		var p := to_rot * (PLAZA_R - 0.5 + k * 1.5)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.4, 0.05, 1.6)
		mi.mesh = bm
		mi.material_override = stone
		mi.position = Vector3(p.x, CURB, p.z)
		mi.rotation.y = atan2(to_rot.x, to_rot.z)
		add_child(mi)
	# trees all round the lawns, thick at the edges; hydrangeas along the paths; grass
	for i in 70:
		var p := Vector3(rng.randf_range(-lawn, lawn), GRASS_Y, rng.randf_range(-lawn, lawn))
		var r := Vector2(p.x, p.z).length()
		if r < PLAZA_R + 3.0 or absf(p.x) < 4.5 or absf(p.z) < 4.5 or p.distance_to(rot) < 7.0:
			continue
		if Vector2(p.x, p.z).distance_to(Vector2(CART.x, CART.z)) < 5.0:
			continue
		_tree(p, rng.randf_range(1.0, 1.5), rng.randi() % 3)
	for k in 4:
		for side in [-1.0, 1.0]:
			for j in 4:
				var a := deg_to_rad(k * 90.0)
				var along := Vector3(sin(a), 0, cos(a))
				var across = Vector3(cos(a), 0, -sin(a)) * side * 3.3
				var bp = along * (PLAZA_R + 2.0 + j * 2.8) + across
				scatter_prop("hydrangea_bush", Vector3(bp.x, GRASS_Y, bp.z), rng.randf() * 360.0, rng.randf_range(0.8, 1.1))
	for i in 3600:
		var gp := Vector3(rng.randf_range(-lawn, lawn), GRASS_Y - 0.02, rng.randf_range(-lawn, lawn))
		if surface_at(gp) == "grass":
			var gb := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.1, rng.randf_range(0.32, 0.55), 1.1) * rng.randf_range(0.8, 1.2))
			if not scatter("grass_clump", Transform3D(gb, gp), Color.WHITE, "", false, false):
				break
	# the ice cream cart (out of ice cream), at the edge of the south lawn
	if not furnish("ice_cream_cart", CART, 0.0, Vector3(2.8, 1.2, 1.2), Vector3(0, 0.6, 0)):
		box(CART + Vector3(0, 0.7, 0), Vector3(2.8, 0.9, 1.2), Color(0.98, 0.95, 0.88))
	label(CART + Vector3(0, 0.75, 0.62), 0, "ICE CREAM", 0.22, Color(0.86, 0.35, 0.47), false)


func _bench_classic(at: Vector3, yaw: float) -> void:
	if prop("bench_classic", at, yaw) != null:
		box(at + Vector3(0, 0.44, 0), Vector3(1.9, 0.08, 0.55).rotated(Vector3.UP, deg_to_rad(yaw)).abs(), Color(0, 0, 0, 0), true)
	else:
		_bench(at, yaw + 180.0)


var _lantern_glow: Array = []      # [MeshInstance3D, surface] of each lamp's glass: dark until you picture them lit
static var _unlit: StandardMaterial3D


func _lantern(at: Vector3) -> void:
	var l := prop("lamp_lantern", at, 0.0, 1.05)
	if l == null:
		_lamp(at)
		return
	blocker(at + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3))
	if _unlit == null:
		_unlit = StandardMaterial3D.new()
		_unlit.albedo_color = Color(0.85, 0.82, 0.75)
		_unlit.roughness = 0.1
		_unlit.metallic_specular = 0.9
	for mi in l.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := (mi as MeshInstance3D).mesh.surface_get_material(i)
			if m and String(m.resource_name).contains("glow"):
				(mi as MeshInstance3D).set_surface_override_material(i, _unlit)
				_lantern_glow.append([mi, i])


# ------------------------------------------------------------------ the fountain

const FOUNTAIN_LEVELS := [[0.62, 5.15], [1.98, 2.95], [3.12, 1.6], [4.02, 0.75]]   # water height, radius (from the model)
var _fountain_flow: Array[Node3D] = []


func _fountain_build() -> void:
	if prop("fountain_grand", Vector3(0, CURB, 0), 0.0) != null:
		var fb := StaticBody3D.new()
		fb.collision_layer = 1
		add_child(fb)
		for spec in [[Vector3(0, CURB + 0.08, 0), 6.6, 0.16], [Vector3(0, CURB + 0.48, 0), 5.85, 0.95], [Vector3(0, CURB + 2.0, 0), 1.3, 4.0]]:
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = spec[1]
			cy.height = spec[2]
			cs.shape = cy
			cs.position = spec[0]
			fb.add_child(cs)
		for lv in FOUNTAIN_LEVELS:
			_fountain_water(Vector3(0, CURB + lv[0], 0), lv[1])
	else:
		shape_at("cylinder", Vector3(0, CURB + 0.25, 0), Vector3(11.0, 0.5, 11.0), STONE, true, Vector3.ZERO, "concrete")
		_fountain_water(Vector3(0, CURB + 0.47, 0), 5.2)


## The fountain running: a plume from the top, water sheeting off every tier's lip, spray. Off until you picture it.
func _fountain_on() -> void:
	var sheet_mat := ShaderMaterial.new()
	sheet_mat.shader = load("res://scripts/world/falling_water.gdshader")
	# sheets falling off the three tiers, each into the one below (the last into the basin)
	for i in range(1, 4):
		var top: float = CURB + FOUNTAIN_LEVELS[i][0] + 0.03
		var r: float = FOUNTAIN_LEVELS[i][1] + 0.12
		var below: float = CURB + FOUNTAIN_LEVELS[i - 1][0]
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r * 1.12
		cm.height = top - below
		cm.radial_segments = 40
		cm.cap_top = false
		cm.cap_bottom = false
		var sheet := MeshInstance3D.new()
		sheet.mesh = cm
		sheet.material_override = sheet_mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.position = Vector3(0, (top + below) * 0.5, 0)
		sheet.rotation.x = PI       # (V runs top to bottom: the streaks fall)
		add_child(sheet)
		_fountain_flow.append(sheet)
	# the plume: two nested columns of rising water, the outer one wider and fainter
	var plume_mat := sheet_mat.duplicate() as ShaderMaterial
	plume_mat.set_shader_parameter("speed", -2.6)
	plume_mat.set_shader_parameter("opacity", 0.85)
	for spec in [[0.12, 0.32, 5.5], [0.3, 0.7, 4.2]]:
		var cm := CylinderMesh.new()
		cm.bottom_radius = spec[0]
		cm.top_radius = spec[1]
		cm.height = spec[2]
		cm.radial_segments = 16
		cm.cap_top = false
		cm.cap_bottom = false
		var jet := MeshInstance3D.new()
		jet.mesh = cm
		jet.material_override = plume_mat
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jet.position = Vector3(0, CURB + 4.45 + spec[2] * 0.5, 0)
		add_child(jet)
		_fountain_flow.append(jet)
	# spray: droplets thrown up and falling back
	var parts := GPUParticles3D.new() if Settings.quality >= 1 else null
	if parts:
		parts.amount = 600
		parts.lifetime = 2.2
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 14.0
		pm.initial_velocity_min = 8.0
		pm.initial_velocity_max = 10.5
		pm.gravity = Vector3(0, -9.8, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		parts.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.06, 0.12)
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.9, 0.97, 1.0, 0.7)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.material = dm
		parts.draw_pass_1 = qm
		parts.position = Vector3(0, CURB + 4.5, 0)
		parts.visibility_aabb = AABB(Vector3(-8, -6, -8), Vector3(16, 14, 16))
		add_child(parts)
		_fountain_flow.append(parts)


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
	mat.shader = load("res://scripts/world/water.gdshader" if Settings.quality >= 1 else "res://scripts/world/water_lite.gdshader")
	mat.set_shader_parameter("absorb", 0.6)
	mat.set_shader_parameter("wave_height", 0.004)
	mat.set_shader_parameter("foam_amount", 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)


# ------------------------------------------------------------------ the ring road in the sky

## A ring of elevated road round the whole city, high over the roofs, on tall piers. Nothing ever drives on it.
func _viaduct() -> void:
	var n := int(ceil(TAU * VIADUCT_R / 22.0))
	var stretch := (TAU * VIADUCT_R / n) / 22.0 + 0.01
	for k in n:
		var a := TAU * k / n
		var p := Vector3(cos(a) * VIADUCT_R, VIADUCT_Y, sin(a) * VIADUCT_R)
		var yaw := rad_to_deg(-a) - 90.0
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.from_scale(Vector3(stretch, 1, 1)), p)
		var ps := Props.parts("viaduct_segment")
		if ps.is_empty():
			return
		for i in ps.size():
			var key := "viaduct_segment|#%d|false|true" % i
			if not _scatter.has(key):
				_scatter[key] = [ps[i][0], [], true]
			_scatter[key][1].append([xf * (ps[i][1] as Transform3D), Color.WHITE])
		# a pier where it stands on open ground (not through a roof)
		var on_roof := false
		for b in BLOCKS:
			if p.x > b[0] - 3.0 and p.x < b[1] + 3.0 and p.z > b[2] - 3.0 and p.z < b[3] + 3.0:
				on_roof = true
		if not on_roof and k % 2 == 0:
			scatter_prop("viaduct_pier", p + Vector3(0, -0.9, 0), yaw)


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
	sky_mat.set_shader_parameter("cloud_cover", 0.4)
	sky_mat.set_shader_parameter("rings", 1.0)               # the dream's sky: vast pale rings, partly there
	sky_mat.set_shader_parameter("sun_size", 0.9986)
	sky_mat.set_shader_parameter("zenith", Color(0.16, 0.42, 0.88))
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
	# a blazing summer light: the sun blooms, and the plaza's polished stone gives the sky back
	env.glow_enabled = true
	env.glow_intensity = 0.7 if Settings.quality >= 1 else 0.45
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.1
	if Settings.quality >= 1:
		env.ssr_enabled = true
		env.ssr_max_steps = 48
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
	mina.position = CART + Vector3(0, 0, -1.4)
	mina.rotation_degrees.y = 0
	mina.setup("mina", "Mina", "the ice cream vendor", {"skin": Color(0.86, 0.64, 0.5), "hair": Color(0.32, 0.16, 0.07),
		"shirt": Color(0.95, 0.55, 0.62), "pants": Color(0.2, 0.25, 0.42), "apron": true, "cap": true,
		"cap_color": Color(0.98, 0.98, 0.95), "height": 0.95, "hair_style": "bun", "build": 0.92})

	# Mr. Halvorsen, on the bench, with the pigeons.
	var arne := NPC.new()
	add_child(arne)
	var arne_dir := -ARNE_BENCH.normalized()
	arne.position = ARNE_BENCH + arne_dir * 0.08      # (on the seat, facing the fountain)
	arne.rotation_degrees.y = rad_to_deg(atan2(arne_dir.x, arne_dir.z))
	arne.setup("halvorsen", "Mr. Halvorsen", "the old man", {"skin": Color(0.84, 0.68, 0.58), "hair": Color(0.78, 0.78, 0.76),
		"shirt": Color(0.42, 0.47, 0.34), "pants": Color(0.33, 0.29, 0.24), "seated": true, "cap": true,
		"cap_color": Color(0.28, 0.28, 0.3), "sleeves": "long", "hair_style": "short", "build": 1.05,
		"shoes": Color(0.25, 0.15, 0.08)})
	for i in 7:
		var p := ARNE_BENCH - ARNE_BENCH.normalized() * randf_range(0.9, 2.2) + Vector3(randf_range(-1.6, 1.6), 0.06, randf_range(-1.0, 1.0))
		var bird := group(p, randf_range(0, 360))
		if prop("pigeon", Vector3(0, -0.06, 0), 0.0, 0.8, bird) == null:
			part("sphere", Vector3(0, 0.06, 0), Vector3(0.09, 0.09, 0.14), Color(0.42, 0.43, 0.47), bird)
			part("sphere", Vector3(0, 0.12, 0.07), Vector3.ONE * 0.055, Color(0.25, 0.3, 0.32), bird)
		_pigeons.append(bird)
		_pigeon_home.append(p)

	# Theo and his kite.
	_theo = NPC.new()
	add_child(_theo)
	_theo.position = Vector3(44.0, TOP_Y, -306.0)
	_theo.rotation_degrees.y = 10
	_theo.setup("theo", "Theo", "the kid with the kite", {"skin": Color(0.58, 0.4, 0.28), "hair": Color(0.05, 0.04, 0.04),
		"shirt": Color(0.96, 0.8, 0.2), "pants": Color(0.25, 0.4, 0.62), "height": 0.68, "cap": true,
		"cap_color": Color(0.85, 0.15, 0.12), "hair_style": "curly", "build": 0.9, "shoes": Color(0.9, 0.9, 0.92)})
	_kite = group(KITE_BASE)
	if prop("kite", Vector3.ZERO, 0.0, 1.0, _kite) == null:
		part("box", Vector3.ZERO, Vector3(0.9, 0.9, 0.03), Color(0.9, 0.2, 0.25), _kite, Vector3(0, 0, 45))
		part("box", Vector3(0, 0, 0.01), Vector3(0.5, 0.5, 0.02), Color(0.98, 0.85, 0.3), _kite, Vector3(0, 0, 45))
		for t in range(1, 6):
			part("box", Vector3(0, -0.6 - t * 0.3, 0), Vector3(0.12, 0.12, 0.02),
				Color(0.2, 0.5, 0.9) if t % 2 else Color(0.98, 0.98, 0.95), _kite, Vector3(0, 0, 45))
	_kite_line = part("cylinder", Vector3.ZERO, Vector3.ONE, Color(0.95, 0.95, 0.95))

	# The jogger, looping the park.
	var jog := NPC.new()
	add_child(jog)
	var jy := CURB
	jog.position = Vector3(24.0, jy, -190.0)
	jog.setup("jogger", "the jogger", "the jogger", {"skin": Color(0.74, 0.52, 0.38), "hair": Color(0.6, 0.42, 0.2),
		"shirt": Color(0.25, 0.72, 0.72), "pants": Color(0.08, 0.08, 0.1), "hair_style": "long",
		"shoes": Color(0.95, 0.4, 0.3)})
	jog.patrol = [Vector3(24.0, jy, -191.0), Vector3(86.0, jy, -191.0), Vector3(86.0, jy, -219.5), Vector3(22.0, jy, -219.5)]
	jog.patrol_speed = 3.3

	# The Observer: far end of the avenue, by the bus stop. Easy to overlook.
	# (the far end of the avenue, across the pool, the terrace's far corner, the far edge of the meadow)
	_observer_spots = [BUS_STOP + Vector3(-0.5, 0, 4.0), Vector3(88.0, CURB, -248.0), Vector3(86.0, TOP_Y, -316.0), Vector3(120.0, TOP_Y, -450.0)]
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
	# the roundabout turns on its own; the swing in the meadow sways, very slowly, very far
	if _roundabout:
		_roundabout.rotation.y += delta * 0.35
	if _sky_swing:
		_sky_swing.rotation.x = sin(_t * 0.25) * 0.03
	# birdsong, now and then
	if _t > _next_chirp:
		_next_chirp = _t + randf_range(1.5, 6.0)
		var p = Game.player
		if p:
			var where: Vector3 = p.global_position + Vector3(randf_range(-15, 15), randf_range(5, 10), randf_range(-15, 15))
			Sfx.play_at("chirp", self, where, -6.0, 40.0)
	# the kite sways; its string runs to Theo's hand
	if _kite:
		var kp := KITE_BASE + Vector3(sin(_t * 0.4) * 1.6, sin(_t * 0.7) * 0.7, cos(_t * 0.33) * 1.2)
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
		p.y = ground_y(p + Vector3(0, ppos.y - p.y + 1.0, 0), ppos.y)
		if absf(p.y - ppos.y) > 0.4:
			continue   # landed on a roof, a car or a bench (or in the pool): he stands where you stand
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

var _landmarks := {}
var _changes := {}
var _told_t := -1.0


func _quest() -> void:
	# landmarks: the fountain, the ice cream cart, the bus stop at the far end of the avenue
	for lm in [["fountain", Vector3(0, 1, 0), Vector3(18, 3, 18), "The fountain's not running. In a dream? I could fix that."],
			["cart", CART + Vector3(0, 1, 0), Vector3(6, 3, 6), "An ice cream cart. Nobody's queuing."],
			["busstop", BUS_STOP + Vector3(0, 1, 0), Vector3(8, 3, 9), "The 3:12 bus. Every stop on the timetable says 3:12."]]:
		var id: String = lm[0]
		var line: String = lm[3]
		trigger(lm[1], lm[2], func():
			_landmarks[id] = true
			Game.counters["landmarks"] = _landmarks.size()
			Game.hud.show_thought(line, 4.0)
			if _landmarks.size() >= 3:
				Game.set_flag("city_landmarks"))

	# things that can be changed by wanting them changed
	interactable(Vector3(0, CURB + 1.1, 6.3), Vector3(6.0, 1.6, 1.0), func(): return "" if _changes.has("fountain") else "Picture the fountain flowing",
		func(): _change("fountain"), func(): return not _changes.has("fountain"))
	interactable(CAR_SPOT + Vector3(0, 0.9, 0), Vector3(2.2, 1.6, 4.4), func(): return "" if _changes.has("car") else "Picture it another colour",
		func(): _change("car"), func(): return not _changes.has("car"))
	interactable((LAMPS[1] as Vector3) + Vector3(0, 1.6, 0), Vector3(0.9, 3.2, 0.9), func(): return "" if _changes.has("lamps") else "Picture the lamps lit",
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
	hill.position = HILL + Vector3(0, 1.8 - 0.05, 0)
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
	if not furnish("wood_post", post, 0.0, Vector3(0.14, 1.8, 0.14), Vector3(0, 0.9, 0)):
		shape_at("cylinder", post + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), BARK, true, Vector3.ZERO, "wood")
	var a0 := top + Vector3(0.6, 1.35, 0.2)
	var a1 := post + Vector3(0, 1.5, 0)
	var sling := prop("hammock", (a0 + a1) * 0.5, 0.0)
	if sling:
		# stretched to the gap and turned along it (the model runs 2.8 m along its X)
		var span := a1 - a0
		sling.scale = Vector3(span.length() / 3.3, 1.0, 1.0)
		sling.rotation.y = atan2(-span.z, span.x)
		sling.rotation.z = atan2(span.y, Vector2(span.x, span.z).length())
	else:
		for k in 9:
			var f := float(k) / 8.0
			var p := a0.lerp(a1, f) + Vector3(0, -0.55 * sin(PI * f), 0)
			box(p, Vector3(0.42, 0.04, 0.95), Color(0.85, 0.45, 0.35), false, rad_to_deg(atan2(a1.x - a0.x, a1.z - a0.z)) + 90.0, "fabric")
	interactable(a0.lerp(a1, 0.5) + Vector3(0, -0.4, 0), Vector3(2.0, 1.0, 1.4), func(): return "Lie down in the hammock",
		func():
			Game.hud.show_thought("Quiet. Just the leaves. ...So sleepy. Just for a minute.", 3.0)
			Game.enter_remember())
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
			_fountain_on()
			Game.hud.show_thought("It just... does what I want. I want it, and it is.", 4.0)
		"car":
			var tint := Color.from_hsv(randf(), 0.55, 0.8)
			for c in get_children():
				if c is Node3D and String(c.name).begins_with("car_") and (c as Node3D).global_position.distance_to(CAR_SPOT) < 1.0:
					for mi in c.find_children("*", "MeshInstance3D", true, false):
						for si in mi.mesh.get_surface_count():
							var m: Material = mi.mesh.surface_get_material(si)
							if m and String(m.resource_name).ends_with("paint"):
								var nm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
								nm.albedo_color = tint
								mi.set_surface_override_material(si, nm)
			Game.hud.show_thought("Blue. No - that colour. Exactly that colour.", 3.5)
		"lamps":
			for g in _lantern_glow:
				(g[0] as MeshInstance3D).set_surface_override_material(g[1], null)
			for l in LAMPS:
				omni(l + Vector3(0, 4.1, 0), Color(1.0, 0.85, 0.6), 1.6, 8.0, false)
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
	for i in _fountain_flow.size():
		if _fountain_flow[i] is MeshInstance3D and i >= 3:
			_fountain_flow[i].scale.y = 1.0 + 0.05 * sin(_t * 7.0 + i)
