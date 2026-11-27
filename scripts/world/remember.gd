class_name RememberZone
extends Zone
## THE PLACE WE REMEMBER. An ordinary, beautiful city park on a summer afternoon - that slowly stops behaving
## like one. Nothing chases you. Nothing jumps out. The place itself is what's wrong.
##
## Six sections, one walk north (z falls as you go), no loading:
##   01 THE ENTRANCE    z 8 .. -105     gates off a city street, a wide curving path, lawns, trees, the fountain ahead
##   02 THE FOUNTAIN    z -105 .. -165  a plaza and parterres; two coffees on a bench; the water reflects another sky;
##                                      signs on three paths, every one of them to THE GARDENS
##   03 THE GARDENS     z -170 .. -322  hedged garden rooms; the same blue bench, the same flower bed, the same red
##                                      maple, again; a clock tower on the horizon that never gets any closer
##   04 THE PLAYGROUND  z -322 .. -420  huge, faded, empty; a swing moving without wind; footsteps that aren't yours
##   05 THE IMPOSSIBLE GARDEN  z -420 .. -545  the hedges grow out of reach; the sky stops; three markers to find;
##                                      a path to the east that never ends
##   06 THE EXIT        z -545 .. -660  a white stone arch, and through it an ordinary street. The park is gone.

const GRASS := Color(0.3, 0.46, 0.16)
const PATHC := Color(0.78, 0.74, 0.66)
const GRAVEL := Color(0.72, 0.68, 0.6)

const FOUNTAIN := Vector3(0, 0, -128)
const PLAZA_R := 15.0
const GARDEN_GATE := Vector3(0, 0, -178)
const HUB := Vector3(0, 0, -500)          # the impossible garden's centre; the locked gate on its north side
const GATE := Vector3(0, 0, -513)
const ARCH := Vector3(0, 0, -600)
const STREET_Z := -616.0
const LOOP_FROM := 45.0                   # the east corridor repeats from here ...
const LOOP_LEN := 45.0                    # ... every 45 m (step past LOOP_FROM + 2 * LOOP_LEN and you're back one period)

const CHECKPOINTS := {
	"fountain": [Vector3(0, 0.05, -100.0), 0.0, ["rm_fountain"]],
	"gardens": [Vector3(0, 0.05, -182.0), 0.0, ["rm_fountain", "rm_gardens"]],
	"playground": [Vector3(0, 0.05, -326.0), 0.0, ["rm_fountain", "rm_gardens", "rm_playground"]],
	"hub": [Vector3(0, 0.05, -488.0), 0.0, ["rm_fountain", "rm_gardens", "rm_playground", "rm_impossible"]],
}

var _paths: Array[Rect2] = []            # stone paths, for footsteps
var _gravel: Array[Rect2] = []           # gravel paths
var _t := 0.0
var _sky: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _amb := {}                           # name -> audio player
var _clock: Node3D
var _skyline: Array[Node3D] = []
var _swing_seat: Node3D
var _swing_on := false
var _swing_t := 0.0
var _swing_creak := 0.0
var _markers: Array = []                 # [node, glow mesh, done]
var _marker_ping := 0.0
var _gate_l: Node3D
var _gate_r: Node3D
var _gate_block: StaticBody3D
var _musicbox: Node
var _echo_left := 6                      # footsteps that aren't yours (how many)
var _echo_dist := 0.0
var _last_pos := Vector3.ZERO
var _loops := 0
var _on_street := false
var _street_t := 0.0
var _bell_done := false
var _hedges_shown := 0


func zone_id() -> String: return "remember"
func allows_manifestation() -> bool: return false
func fear_gain() -> float: return 0.15
func fear_decay() -> float: return 4.0
func walk_speed() -> float: return 2.9
func sprint_speed() -> float: return 5.0


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, 6.0))


func surface_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	if p.z < STREET_Z + 8.0:
		return "concrete"
	for r in _paths:
		if r.has_point(q):
			return "concrete"
	for r in _gravel:
		if r.has_point(q):
			return "gravel"
	if Vector2(p.x - FOUNTAIN.x, p.z - FOUNTAIN.z).length() < PLAZA_R:
		return "concrete"
	return "grass"


func water_level_at(_p: Vector3) -> float:
	return -INF


# ------------------------------------------------------------------ build

func build() -> void:
	_ground()
	_entrance()
	_fountain_plaza()
	_gardens()
	_playground()
	_impossible()
	_exit()
	_city_around()
	_lighting()
	_audio()
	Props.set_wind(1.0)


func _ground() -> void:
	# the whole park is lawn; the street beyond the arch is its own
	box(Vector3(0, -0.5, -301.5), Vector3(420, 1.0, 603), GRASS, true, 0.0, "grass")
	box(Vector3(0, -0.5, 40), Vector3(420, 1.0, 80), Color(0.09, 0.095, 0.105), true, 0.0, "asphalt")
	# the park's boundary: hedges (taller round the impossible garden), the railings at the front
	_hedge(Vector3(-76, 0, -1.0), Vector3(-76, 0, -426), 2.4)
	_hedge(Vector3(76, 0, -1.0), Vector3(76, 0, -426), 2.4)
	_hedge(Vector3(-76, 0, -426), Vector3(-76, 0, -545), 7.5)
	_hedge(Vector3(76, 0, -426), Vector3(76, 0, -498), 7.5)
	_hedge(Vector3(76, 0, -502), Vector3(76, 0, -545), 7.5)
	_hedge(Vector3(-76, 0, -545), Vector3(-3.5, 0, -545), 7.5)
	_hedge(Vector3(3.5, 0, -545), Vector3(76, 0, -545), 7.5)


## A paved path from a to b (straight), `w` wide, as a thin slab (you walk on the lawn under it).
func _path(a: Vector3, b: Vector3, w: float, gravel := false) -> void:
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var yaw := rad_to_deg(atan2(d.x, d.z))
	box((a + b) * 0.5 + Vector3(0, 0.012, 0), Vector3(w, 0.024, len + w * 0.3), GRAVEL if gravel else PATHC, false, yaw, "concrete" if gravel else "pavers")
	# footsteps: an axis-aligned box round it is close enough
	var lo := Vector2(minf(a.x, b.x) - w * 0.5, minf(a.z, b.z) - w * 0.5)
	var hi := Vector2(maxf(a.x, b.x) + w * 0.5, maxf(a.z, b.z) + w * 0.5)
	(_gravel if gravel else _paths).append(Rect2(lo, hi - lo))


## A curving path through points.
func _path_curve(pts: Array, w: float, gravel := false) -> void:
	for i in pts.size() - 1:
		_path(pts[i], pts[i + 1], w, gravel)


## A clipped hedge along a line, in 3 m sections; `h` = height (2.4 normal; the impossible garden's grow).
func _hedge(a: Vector3, b: Vector3, h := 2.4) -> void:
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	if len < 0.5:
		return
	var dir := Vector3(d.x, 0, d.z) / len
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))      # (the model runs along its own X)
	var n := maxi(1, int(round(len / 3.0)))
	var step := len / n
	var tall := h > 4.0
	var slot := "hedge_tall" if tall else "hedge_block"
	var base_h := 7.5 if tall else 2.4
	for i in n:
		var c := a + dir * (step * (i + 0.5))
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.from_scale(Vector3(step / 3.0 + 0.04, h / base_h, 1.0)), Vector3(c.x, 0.0, c.z))
		var ps := Props.parts(slot)
		if ps.is_empty():
			box(Vector3(c.x, h * 0.5, c.z), Vector3(step, h, 1.0), Color(0.12, 0.26, 0.08), false, yaw)
		for k in ps.size():
			var key := "%s|#%d|false|true" % [slot, k]
			if not _scatter.has(key):
				_scatter[key] = [ps[k][0], [], true]
			_scatter[key][1].append([xf * (ps[k][1] as Transform3D), Color.WHITE])
	var mid := (a + b) * 0.5
	var bsz := Vector3(len, h, 1.1).rotated(Vector3.UP, deg_to_rad(yaw)).abs() if absf(dir.x) > 0.01 and absf(dir.z) > 0.01 else (Vector3(len, h, 1.1) if absf(dir.x) > 0.5 else Vector3(1.1, h, len))
	blocker(Vector3(mid.x, h * 0.5, mid.z), bsz)


func _tree(p: Vector3, slot: String, s: float, yaw := -1.0) -> void:
	if scatter_prop(slot, p, randf() * 360.0 if yaw < 0.0 else yaw, s):
		blocker(p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5))


func _lawn(rect: Rect2, n: int, rng: RandomNumberGenerator, flowers := 0.0) -> void:
	for i in n:
		var gp := Vector3(rng.randf_range(rect.position.x, rect.end.x), 0.0, rng.randf_range(rect.position.y, rect.end.y))
		if surface_at(gp) != "grass":
			continue
		var gb := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.0, rng.randf_range(0.8, 1.3), 1.0) * rng.randf_range(0.85, 1.15))
		var slot := "wildflowers" if rng.randf() < flowers else "grass_lawn"
		scatter(slot, Transform3D(gb, gp), Color.WHITE, "", false, false)


func _bench(p: Vector3, yaw: float, slot := "bench_classic") -> Node3D:
	var b := prop(slot, p, yaw)
	if b:
		box(p + Vector3(0, 0.44, 0), Vector3(1.95, 0.08, 0.55).rotated(Vector3.UP, deg_to_rad(yaw)).abs(), Color(0, 0, 0, 0), true)
	return b


func _lamp(p: Vector3) -> void:
	if prop("lamp_lantern", p, 0.0, 1.05):
		blocker(p + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3))


# ------------------------------------------------------------------ 01 the entrance

func _entrance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	# the street you come in from, and the gates
	box(Vector3(0, 0.08, 4.0), Vector3(60, 0.16, 6.0), Color(0.62, 0.6, 0.56), true, 0.0, "pavers")
	_paths.append(Rect2(-30, 1, 60, 6))
	furnish("entrance_gates", Vector3(0, 0, 0.0), 0.0, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		blocker(Vector3(sx * 4.2, 1.8, 0), Vector3(1.2, 3.6, 1.2))
	label(Vector3(0, 3.25, -0.65), 180, "MEMORIAL PARK", 0.16, Color(0.95, 0.85, 0.6), false)
	label(Vector3(0, 3.25, 0.65), 0, "MEMORIAL PARK", 0.16, Color(0.95, 0.85, 0.6), false)
	# the park's railings, east and west of the gates
	for sx in [-1.0, 1.0]:
		var x := 4.8
		while x < 76.0:
			if not scatter_prop("iron_railing", Vector3(sx * (x + 1.0), 0, 0.3), 0.0, 1.0):
				scatter_prop("play_fence", Vector3(sx * (x + 1.0), 0, 0.3), 0.0, 1.0)
			x += 2.0
		blocker(Vector3(sx * 40.4, 1.0, 0.3), Vector3(71.2, 2.0, 0.3))
	# behind you: the street you came from, a row of shops across it (you can't go back that way)
	for x in [-48.0, -24.0, 0.0, 24.0, 48.0]:
		facade_building(Vector3(x, 0.15, 30.0), 22.0, 12.0, 3 + int(absf(x)) % 3, ["brick", "plaster", "modern"][int(absf(x) / 24.0) % 3], Color(0.85, 0.72, 0.58), true)
	box(Vector3(0, 0.075, 21.5), Vector3(130, 0.15, 5.0), Color(0.62, 0.6, 0.56), true, 0.0, "pavers")
	blocker(Vector3(0, 3, 19.5), Vector3(160, 6, 1))
	for sx in [-1.0, 1.0]:
		blocker(Vector3(sx * 78.0, 3, 10), Vector3(1, 6, 20))
	var tz := -60.0
	while tz < 60.0:
		box(Vector3(tz, 0.015, 12.0), Vector3(3, 0.02, 0.14), Color(0.85, 0.75, 0.3), false)
		tz += 6.0
	for c in [[Vector3(-20, 0, 9.0), 0.0], [Vector3(26, 0, 15.0), 180.0]]:
		if prop("car_%d" % (absi(int(c[0].x)) % 5), c[0], c[1]):
			blocker((c[0] as Vector3) + Vector3(0, 0.75, 0), Vector3(4.4, 1.5, 1.8))
	# the path: wide, gently curving, toward the fountain
	var pts := []
	for k in 12:
		var z := -float(k) * 9.0
		pts.append(Vector3(sin(z / 28.0) * 5.0, 0, z))
	pts.append(Vector3(0, 0, FOUNTAIN.z + PLAZA_R - 0.5))
	_path_curve(pts, 6.0)
	# lawns either side: big trees, beds of flowers, benches and lamps along the path
	_lawn(Rect2(-70, -108, 140, 106), 2600, rng, 0.05)
	var slots := ["park_oak", "park_linden", "park_plane"]
	for i in 46:
		var p := Vector3(rng.randf_range(-68, 68), 0, rng.randf_range(-100, -6))
		var cx := sin(p.z / 28.0) * 5.0
		if absf(p.x - cx) < 10.0 or Vector2(p.x - FOUNTAIN.x, p.z - FOUNTAIN.z).length() < PLAZA_R + 8.0:
			continue
		_tree(p, slots[rng.randi() % 3], rng.randf_range(0.85, 1.2))
	for k in 6:
		var z := -14.0 - k * 15.0
		var cx := sin(z / 28.0) * 5.0
		var side := 1.0 if k % 2 == 0 else -1.0
		_bench(Vector3(cx + side * 4.4, 0, z), -90.0 * side)
		_lamp(Vector3(cx - side * 4.0, 0, z - 6.0))
		if k % 2 == 1:
			prop("park_bin", Vector3(cx + side * 4.3, 0, z + 1.6), 0.0)
	for f in [Vector3(-16, 0, -30), Vector3(17, 0, -55), Vector3(-15, 0, -78)]:
		furnish("flower_round", f, rng.randf() * 360.0, Vector3(3.2, 0.4, 3.2), Vector3(0, 0.2, 0))
	for i in 40:
		var z := rng.randf_range(-100, -8)
		var cx := sin(z / 28.0) * 5.0
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		scatter_prop("hydrangea_bush", Vector3(cx + side * rng.randf_range(4.8, 6.0), 0, z), rng.randf() * 360.0, rng.randf_range(0.8, 1.15))
	for i in 14:
		scatter_prop("fallen_leaves", Vector3(rng.randf_range(-40, 40), 0.0, rng.randf_range(-100, -10)), rng.randf() * 360.0, rng.randf_range(0.8, 1.4))
	trigger(Vector3(0, 1.5, -6.0), Vector3(14, 3, 2), func():
		Game.hud.show_thought("A park. Sunday afternoon, it feels like. ...I think I've been here before.", 4.5))
	checkpoint_zone("fountain", Vector3(0, 1.5, -100), Vector3(14, 3, 2), Vector3(0, 0.05, -100), 0.0)


# ------------------------------------------------------------------ 02 the fountain

var _fountain_water: Array[MeshInstance3D] = []


func _fountain_plaza() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var stone := ShaderMaterial.new()
	stone.shader = load("res://scripts/world/plaza_stone.gdshader")
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_R
	disc.bottom_radius = PLAZA_R
	disc.height = 0.05
	disc.radial_segments = 72
	var plaza := MeshInstance3D.new()
	plaza.mesh = disc
	plaza.material_override = stone
	plaza.position = FOUNTAIN + Vector3(0, 0.01, 0)
	add_child(plaza)
	# the fountain, running; its water reflects a sky that isn't quite this one
	if prop("fountain_grand", FOUNTAIN, 0.0):
		var fb := StaticBody3D.new()
		add_child(fb)
		for spec in [[Vector3(0, 0.08, 0), 6.6, 0.16], [Vector3(0, 0.48, 0), 5.85, 0.95], [Vector3(0, 2.0, 0), 1.3, 4.0]]:
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = spec[1]
			cy.height = spec[2]
			cs.shape = cy
			cs.position = FOUNTAIN + (spec[0] as Vector3)
			fb.add_child(cs)
		for lv in [[0.62, 5.15, 4.2], [1.98, 2.95, 1.5], [3.12, 1.6, 0.6], [4.02, 0.75, 0.0]]:
			_still_water(FOUNTAIN + Vector3(0, lv[0], 0), lv[1], lv[2])
		_fountain_running(FOUNTAIN)
	ambient("water", FOUNTAIN + Vector3(0, 1.0, 0), true, 2.0, 40.0)
	# symmetrical gardens: four parterres round the plaza, each a flower bed in a low clipped hedge
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var c := FOUNTAIN + Vector3(qx * 24.0, 0, qz * 22.0)
			furnish("flower_round", c, 0.0, Vector3(3.2, 0.4, 3.2), Vector3(0, 0.2, 0))
			for e in [[Vector3(-6, 0, -5), Vector3(6, 0, -5)], [Vector3(-6, 0, 5), Vector3(6, 0, 5)], [Vector3(-6, 0, -5), Vector3(-6, 0, 5)], [Vector3(6, 0, -5), Vector3(6, 0, 5)]]:
				_hedge(c + (e[0] as Vector3), c + (e[1] as Vector3), 0.8)
			for k in 6:
				scatter_prop("hydrangea_bush", c + Vector3(rng.randf_range(-4.5, 4.5), 0, rng.randf_range(-3.6, 3.6)), rng.randf() * 360.0, 0.8)
	# round the plaza: planters, benches, lamps
	for k in 8:
		var a := deg_to_rad(k * 45.0 + 22.5)
		var dir := Vector3(sin(a), 0, cos(a))
		var yaw := rad_to_deg(a) + 90.0
		if k != 0 and k != 7:     # (the south-east and south-west gaps: the way in)
			furnish("planter_hydrangea", FOUNTAIN + dir * (PLAZA_R - 1.5), yaw, Vector3(3.6, 0.6, 1.1).rotated(Vector3.UP, deg_to_rad(yaw)).abs(), Vector3(0, 0.3, 0))
		_lamp(FOUNTAIN + Vector3(sin(a + 0.4), 0, cos(a + 0.4)) * (PLAZA_R - 0.6))
	var cups_bench := FOUNTAIN + Vector3(-10.5, 0, 6.0)
	var by := rad_to_deg(atan2(-(-10.5), -6.0))
	_bench(cups_bench, by)
	_bench(FOUNTAIN + Vector3(10.5, 0, 6.0), rad_to_deg(atan2(-10.5, -6.0)))
	_bench(FOUNTAIN + Vector3(0, 0, -11.8), 0.0)
	# two coffees on the bench, still steaming. Nobody.
	var right := Vector3(cos(deg_to_rad(by)), 0, -sin(deg_to_rad(by)))
	for k in 2:
		prop("coffee_cup", cups_bench + Vector3(0, 0.46, 0) + right * (-0.45 + k * 0.32), rng.randf() * 360.0)
	_steam(cups_bench + Vector3(0, 0.62, 0) + right * -0.45)
	interactable(cups_bench + Vector3(0, 0.6, 0), Vector3(1.2, 0.5, 0.7), func(): return "Two coffees",
		func():
			Game.set_flag("rm_cups")
			Game.hud.show_thought("Still warm. Two of them, side by side. ...Whoever was here, they've only just gone.", 4.5))
	# the paths off the plaza: west, north and east. Signs on all three; every sign says THE GARDENS
	_path(FOUNTAIN + Vector3(-PLAZA_R + 0.5, 0, 0), FOUNTAIN + Vector3(-34, 0, 0), 4.0, true)
	_path(FOUNTAIN + Vector3(-34, 0, 0), Vector3(-34, 0, GARDEN_GATE.z + 4.0), 4.0, true)
	_path(Vector3(-34, 0, GARDEN_GATE.z + 4.0), GARDEN_GATE + Vector3(-2, 0, 4.0), 4.0, true)
	_path(FOUNTAIN + Vector3(PLAZA_R - 0.5, 0, 0), FOUNTAIN + Vector3(34, 0, 0), 4.0, true)
	_path(FOUNTAIN + Vector3(34, 0, 0), Vector3(34, 0, GARDEN_GATE.z + 4.0), 4.0, true)
	_path(Vector3(34, 0, GARDEN_GATE.z + 4.0), GARDEN_GATE + Vector3(2, 0, 4.0), 4.0, true)
	_path(FOUNTAIN + Vector3(0, 0, -PLAZA_R + 0.5), GARDEN_GATE + Vector3(0, 0, 3.0), 4.0, true)
	for sp in [[FOUNTAIN + Vector3(-PLAZA_R - 2.5, 0, 2.6), -90.0], [FOUNTAIN + Vector3(2.6, 0, -PLAZA_R - 2.5), 180.0], [FOUNTAIN + Vector3(PLAZA_R + 2.5, 0, -2.6), 90.0]]:
		_signpost(sp[0], sp[1])
	# park information: the map (wrong), and the rules
	_map_board(FOUNTAIN + Vector3(-5.5, 0, PLAZA_R + 3.0), 0.0)
	var rules := prop("pool_sign", FOUNTAIN + Vector3(5.5, 0, PLAZA_R + 2.6), 0.0)
	if rules:
		label(rules.position + Vector3(0, 1.6, 0.05), 0, "MEMORIAL PARK\nPlease keep to the paths.\nPlease do not feed the birds.\nPlease remember to leave.", 0.045, Color(0.12, 0.12, 0.14), false)
	interactable(FOUNTAIN + Vector3(5.5, 1.6, PLAZA_R + 2.9), Vector3(1.0, 0.7, 0.4), func(): return "Read the park rules",
		func(): Game.hud.show_thought("'Please remember to leave.' ...Remember to. Not 'please leave'.", 4.0))
	# trees round the parterres
	_lawn(Rect2(-70, -170, 140, 64), 1600, rng, 0.08)
	for i in 30:
		var p := Vector3(rng.randf_range(-68, 68), 0, rng.randf_range(-168, -108))
		if absf(p.x) < 44.0 and absf(p.z - FOUNTAIN.z) < 32.0:
			continue
		if absf(absf(p.x) - 34.0) < 4.0:
			continue
		_tree(p, ["park_linden", "park_oak", "park_plane"][rng.randi() % 3], rng.randf_range(0.85, 1.2))
	trigger(FOUNTAIN + Vector3(0, 1.5, PLAZA_R + 1.0), Vector3(12, 3, 2), func():
		Game.set_flag("rm_fountain")
		Game.hud.show_thought("Listen to it. ...I used to sit by a fountain like this. I think I did.", 4.0))
	trigger(FOUNTAIN + Vector3(0, 1.5, 7.5), Vector3(7, 3, 2.5), func():
		Game.hud.show_thought("The sky in the water's a different colour. ...It's just the light.", 3.5))


## A disc of still water with a different sky in it.
func _still_water(pos: Vector3, radius: float, ripple: float) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 56
	disc.rings = 2
	mi.mesh = disc
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/dream_water.gdshader")
	mat.set_shader_parameter("ripple_r", ripple)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	_fountain_water.append(mi)


func _fountain_running(at: Vector3) -> void:
	var sheet_mat := ShaderMaterial.new()
	sheet_mat.shader = load("res://scripts/world/falling_water.gdshader")
	var levels := [[0.62, 5.15], [1.98, 2.95], [3.12, 1.6], [4.02, 0.75]]
	for i in range(1, 4):
		var top: float = levels[i][0] + 0.03
		var r: float = levels[i][1] + 0.12
		var below: float = levels[i - 1][0]
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
		sheet.position = at + Vector3(0, (top + below) * 0.5, 0)
		sheet.rotation.x = PI
		add_child(sheet)
	var plume_mat := sheet_mat.duplicate() as ShaderMaterial
	plume_mat.set_shader_parameter("speed", -2.6)
	plume_mat.set_shader_parameter("opacity", 0.85)
	for spec in [[0.12, 0.3, 4.6], [0.28, 0.62, 3.6]]:
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
		jet.position = at + Vector3(0, 4.45 + spec[2] * 0.5, 0)
		add_child(jet)
	if Settings.quality >= 1:
		var parts := GPUParticles3D.new()
		parts.amount = 500
		parts.lifetime = 2.0
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 13.0
		pm.initial_velocity_min = 7.5
		pm.initial_velocity_max = 9.5
		pm.gravity = Vector3(0, -9.8, 0)
		parts.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.1)
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.9, 0.97, 1.0, 0.65)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.material = dm
		parts.draw_pass_1 = qm
		parts.position = at + Vector3(0, 4.5, 0)
		parts.visibility_aabb = AABB(Vector3(-8, -6, -8), Vector3(16, 14, 16))
		add_child(parts)


func _steam(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 2.6
	p.direction = Vector3(0, 1, 0)
	p.spread = 8.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0, 0.03, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	p.mesh = qm
	p.position = at
	add_child(p)


func _signpost(at: Vector3, yaw: float) -> void:
	var s := prop("signpost", at, yaw)
	if s == null:
		return
	blocker(at + Vector3(0, 1.4, 0), Vector3(0.2, 2.8, 0.2))
	# four boards; three say THE GARDENS, whichever way they point. One says HOME.
	var texts := ["THE GARDENS", "THE GARDENS", "HOME", "THE GARDENS"]
	for k in 4:
		var a := deg_to_rad([20.0, 110.0, 200.0, 290.0][k])
		var z := 2.35 - k * 0.24
		var local := Vector3(cos(a) * 0.42, z, -sin(a) * 0.42)
		var l := label(Vector3.ZERO, 0, texts[k], 0.05, Color(0.1, 0.2, 0.13), false)
		remove_child(l)
		s.add_child(l)
		l.position = local
		l.rotation.y = a
	interactable(at + Vector3(0, 2.0, 0), Vector3(1.6, 1.4, 1.6), func(): return "Read the signs",
		func():
			Game.hud.show_thought("Every way says THE GARDENS. ...And one says HOME. It points back the way I came.", 4.0))


## The park map: the layout on it is not the park you're standing in. "YOU ARE HERE", twice.
func _map_board(at: Vector3, yaw: float) -> void:
	if prop("map_board", at, yaw) == null:
		return
	blocker(at + Vector3(0, 1.2, 0), Vector3(2.0, 2.4, 0.3))
	var img := Image.create(320, 220, false, Image.FORMAT_RGB8)
	img.fill(Color(0.88, 0.86, 0.78))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	img.fill_rect(Rect2i(14, 14, 292, 192), Color(0.62, 0.74, 0.5))           # lawns
	img.fill_rect(Rect2i(150, 14, 20, 192), Color(0.9, 0.86, 0.74))           # a straight path (there isn't one)
	img.fill_rect(Rect2i(14, 100, 292, 14), Color(0.9, 0.86, 0.74))
	for y in 220:                                                              # a lake where the fountain is
		for x in 320:
			if Vector2(x - 220, y - 60).length() < 34.0:
				img.set_pixel(x, y, Color(0.45, 0.65, 0.82))
	for i in 18:                                                               # trees
		var c := Vector2i(rng.randi_range(24, 296), rng.randi_range(24, 196))
		img.fill_rect(Rect2i(c.x - 4, c.y - 4, 8, 8), Color(0.35, 0.52, 0.28))
	for c in [Vector2i(60, 170), Vector2i(250, 150)]:                         # YOU ARE HERE, twice
		img.fill_rect(Rect2i(c.x - 5, c.y - 5, 10, 10), Color(0.85, 0.1, 0.1))
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.1)
	face.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.6
	face.material_override = m
	face.position = at + Vector3(0, 1.45, 0.045).rotated(Vector3.UP, deg_to_rad(yaw))
	face.rotation.y = deg_to_rad(yaw)
	add_child(face)
	label(at + Vector3(0, 2.12, 0.06).rotated(Vector3.UP, deg_to_rad(yaw)), yaw, "MEMORIAL PARK", 0.06, Color(0.95, 0.92, 0.85), false)
	interactable(at + Vector3(0, 1.45, 0.3), Vector3(1.8, 1.2, 0.5), func(): return "Look at the map",
		func():
			Game.set_flag("rm_map")
			Game.hud.show_thought("A lake. Straight paths. 'YOU ARE HERE'... twice. None of this is the park I'm standing in.", 4.5))


# ------------------------------------------------------------------ 03 the gardens

func _gardens() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var x0 := -58.0
	var x1 := 58.0
	var z0 := -176.0       # south (the entrance)
	var z1 := -322.0       # north (on to the playground)
	# the outer hedge, with gaps at the entrance (south) and the way on (north)
	_hedge(Vector3(x0, 0, z0), Vector3(-3.0, 0, z0))
	_hedge(Vector3(3.0, 0, z0), Vector3(x1, 0, z0))
	_hedge(Vector3(x0, 0, z1), Vector3(-3.0, 0, z1))
	_hedge(Vector3(3.0, 0, z1), Vector3(x1, 0, z1))
	_hedge(Vector3(x0, 0, z0), Vector3(x0, 0, z1))
	_hedge(Vector3(x1, 0, z0), Vector3(x1, 0, z1))
	prop("rose_arch", GARDEN_GATE, 0.0)
	# paths: the main allee up the middle; a cross allee at -228; the east path round by the rooms
	_path(GARDEN_GATE, Vector3(0, 0, z1), 3.2, true)
	_path(Vector3(-40, 0, -228), Vector3(40, 0, -228), 3.0, true)
	_path(Vector3(40, 0, -228), Vector3(40, 0, -300), 3.0, true)
	_path(Vector3(-40, 0, -228), Vector3(-40, 0, -300), 3.0, true)
	_path(Vector3(-40, 0, -300), Vector3(40, 0, -300), 3.0, true)
	# hedges lining the allees (with openings into the rooms)
	for side in [-1.0, 1.0]:
		_hedge(Vector3(side * 3.0, 0, z0 - 6.0), Vector3(side * 3.0, 0, -224.0))
		_hedge(Vector3(side * 3.0, 0, -232.0), Vector3(side * 3.0, 0, -261.0))
		_hedge(Vector3(side * 3.0, 0, -271.0), Vector3(side * 3.0, 0, -296.0))
		_hedge(Vector3(side * 3.0, 0, -304.0), Vector3(side * 3.0, 0, z1 + 2.0))
		_hedge(Vector3(side * 8.0, 0, -224.0), Vector3(side * 36.0, 0, -224.0))
		_hedge(Vector3(side * 8.0, 0, -232.0), Vector3(side * 36.0, 0, -232.0))
	# rose arches along the main allee
	for z in [-196.0, -212.0, -270.0, -286.0]:
		prop("rose_arch", Vector3(0, 0, z), 0.0)
	# the two garden rooms either side, the same arrangement in both: a pond, the blue bench, the round bed, an urn
	for side in [-1.0, 1.0]:
		var c := Vector3(side * 24.0, 0, -266.0)
		_hedge(c + Vector3(-14, 0, -18), c + Vector3(14, 0, -18))
		_hedge(c + Vector3(-14, 0, 18), c + Vector3(-3, 0, 18))
		_hedge(c + Vector3(3, 0, 18), c + Vector3(14, 0, 18))
		var inner = c.x - side * 14.0
		var outer = c.x + side * 14.0
		_hedge(Vector3(inner, 0, c.z - 18.0), Vector3(inner, 0, c.z - 4.0))
		_hedge(Vector3(inner, 0, c.z + 4.0), Vector3(inner, 0, c.z + 18.0))
		_hedge(Vector3(outer, 0, c.z - 18.0), Vector3(outer, 0, c.z + 18.0))
		_path(Vector3(side * 3.0, 0, c.z), Vector3(inner, 0, c.z), 2.4, true)
		_garden_room(c)
	# THE BLUE BENCH: the same bench, in three places (the two rooms have their own; here's the third)
	_blue_bench(Vector3(14.0, 0, -304.0), 0.0)
	# THE RED MAPLE: one distinctive tree, on two different paths, exactly the same
	for p in [Vector3(0, 0, -240.0), Vector3(40, 0, -290.0)]:
		if scatter_prop("park_maple_red", p + Vector3(1.6, 0, 0), 127.0, 1.0):
			blocker(p + Vector3(1.6, 1.5, 0), Vector3(0.5, 3.0, 0.5))
	trigger(Vector3(40, 1.5, -286.0), Vector3(4, 3, 3), func():
		Game.set_flag("rm_maple")
		Game.hud.show_thought("That tree. The red one. ...It was by the middle path. This is the east path.", 4.0))
	# sculptures
	prop("obelisk", Vector3(-40, 0, -228), 0.0)
	blocker(Vector3(-40, 1.0, -228), Vector3(1.4, 2.0, 1.4))
	prop("urn_plinth", Vector3(40, 0, -228), 0.0)
	blocker(Vector3(40, 1.0, -228), Vector3(0.8, 2.0, 0.8))
	# lawns and flowers inside the gardens
	_lawn(Rect2(x0, z1, x1 - x0, z0 - z1), 2200, rng, 0.12)
	for i in 18:
		scatter_prop("fallen_leaves", Vector3(rng.randf_range(x0, x1), 0.0, rng.randf_range(z1, z0)), rng.randf() * 360.0, 1.0)
	# the clock tower on the horizon: it keeps its distance (see _process)
	_clock = prop("clock_tower", Vector3(-60, 0, -560), 20.0)
	trigger(GARDEN_GATE + Vector3(0, 1.5, -2.0), Vector3(6, 3, 2), func():
		Game.set_flag("rm_gardens")
		Game.hud.show_thought("The gardens. Every sign was right. ...Every sign.", 3.5))
	trigger(Vector3(0, 1.5, -262.0), Vector3(5, 3, 2), func():
		Game.hud.show_thought("That clock tower. I've been walking toward it for ages. ...It's no nearer.", 4.0))
	checkpoint_zone("gardens", GARDEN_GATE + Vector3(0, 1.5, -4.0), Vector3(6, 3, 2), GARDEN_GATE + Vector3(0, 0.05, -4.0), 0.0)


func _garden_room(c: Vector3) -> void:
	_pond(c + Vector3(0, 0, -6.0))
	_blue_bench(c + Vector3(-7.0, 0, 7.0), 135.0)
	furnish("flower_round", c + Vector3(7.0, 0, 6.0), 40.0, Vector3(3.2, 0.4, 3.2), Vector3(0, 0.2, 0))
	prop("urn_plinth", c + Vector3(9.0, 0, -12.0), 0.0)
	blocker(c + Vector3(9.0, 1.0, -12.0), Vector3(0.8, 2.0, 0.8))
	for k in 6:
		scatter_prop("hydrangea_bush", c + Vector3(-12.0 + k * 1.6, 0, -15.5), k * 47.0, 0.9)
	_path(c + Vector3(0, 0, 18.0), c + Vector3(0, 0, 2.0), 2.4, true)


func _blue_bench(at: Vector3, yaw: float) -> void:
	_bench(at, yaw, "bench_blue")
	label(at + Vector3(0, 0.745, -0.185).rotated(Vector3.UP, deg_to_rad(yaw)), yaw + 180.0, "FOR E., WHO LOVED THIS PLACE", 0.018, Color(0.2, 0.15, 0.05), false)
	interactable(at + Vector3(0, 0.6, 0), Vector3(2.0, 0.8, 0.8), func(): return "The blue bench",
		func():
			var n := int(Game.counters.get("rm_bench", 0)) + 1
			Game.counters["rm_bench"] = n
			Game.hud.show_thought(["'For E., who loved this place.' A nice bench.",
				"'For E., who loved this place.' ...The same bench. The same plaque.",
				"The same bench. Again. Same chip in the paint, same plaque. It's the same one."][mini(n - 1, 2)], 4.0))


func _pond(c: Vector3) -> void:
	if prop("pond", c, 0.0) == null:
		return
	var cs := StaticBody3D.new()
	var sh := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 2.2
	cy.height = 0.6
	sh.shape = cy
	sh.position = c + Vector3(0, 0.3, 0)
	cs.add_child(sh)
	add_child(cs)
	_still_water(c + Vector3(0, 0.08, 0), 1.85, 0.0)
	prop("lily_pads", c + Vector3(0.3, 0.09, -0.2), 30.0)


# ------------------------------------------------------------------ 04 the playground

func _playground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var z0 := -326.0
	var z1 := -416.0
	# the path in from the gardens, and on north to the impossible garden
	_path(Vector3(0, 0, -322.0), Vector3(0, 0, z0 - 4.0), 3.0, true)
	_path(Vector3(0, 0, z1 + 4.0), Vector3(0, 0, -426.0), 3.0, true)
	# the play area: soft, faded rubber, enormous, ringed with a coloured fence
	var pa := Rect2(-44, z1 + 4.0, 88, z0 - z1 - 12.0)
	box(Vector3(pa.get_center().x, 0.02, pa.get_center().y), Vector3(pa.size.x, 0.04, pa.size.y), Color(0.52, 0.36, 0.32), false, 0.0, "concrete")
	_paths.append(pa)
	var fx := pa.position.x + 1.0
	while fx < pa.end.x:
		if absf(fx) > 2.5:
			scatter_prop("play_fence", Vector3(fx, 0, pa.end.y), 0.0)
			scatter_prop("play_fence", Vector3(fx, 0, pa.position.y), 0.0)
		fx += 2.0
	var fz := pa.position.y + 1.0
	while fz < pa.end.y:
		scatter_prop("play_fence", Vector3(pa.position.x, 0, fz), 90.0)
		scatter_prop("play_fence", Vector3(pa.end.x, 0, fz), 90.0)
		fz += 2.0
	# (the fence keeps you to its two gates, north and south)
	for zz in [pa.position.y, pa.end.y]:
		blocker(Vector3((pa.position.x - 2.5) * 0.5, 0.55, zz), Vector3(-2.5 - pa.position.x, 1.1, 0.2))
		blocker(Vector3((pa.end.x + 2.5) * 0.5, 0.55, zz), Vector3(pa.end.x - 2.5, 1.1, 0.2))
	for xx in [pa.position.x, pa.end.x]:
		blocker(Vector3(xx, 0.55, pa.get_center().y), Vector3(0.2, 1.1, pa.size.y))
	# the swings: a row of four; the third one is moving
	for k in 4:
		var sp := Vector3(-30.0 + k * 3.0, 0, -348.0)
		var sw := prop("swing_single", sp, 0.0)
		blocker(sp + Vector3(-1.1, 1.2, 0), Vector3(0.2, 2.4, 1.8))
		blocker(sp + Vector3(1.1, 1.2, 0), Vector3(0.2, 2.4, 1.8))
		if sw and k == 2:
			for c in sw.find_children("Seat*", "Node3D", true, false):
				_swing_seat = c
				break
	furnish("slide", Vector3(-6.0, 0, -360.0), 25.0, Vector3(0.8, 2.4, 0.8), Vector3(0, 1.2, -0.7))
	furnish("climbing_dome", Vector3(12.0, 0, -350.0), 0.0, Vector3(3.0, 1.5, 3.0), Vector3(0, 0.75, 0))
	prop("roundabout", Vector3(26.0, 0, -362.0), 30.0)
	prop("seesaw", Vector3(-18.0, 0, -384.0), 70.0)
	prop("sandbox", Vector3(16.0, 0, -392.0), 10.0)
	for p in [Vector3(30, 0, -384), Vector3(32.5, 0, -386)]:
		prop("spring_rider", p, rng.randf() * 360.0)
	furnish("slide", Vector3(34.0, 0, -400.0), -60.0, Vector3(0.8, 2.4, 0.8), Vector3(0, 1.2, -0.7))
	for b in [[Vector3(-40.0, 0, -360.0), 90.0], [Vector3(-40.0, 0, -392.0), 90.0], [Vector3(40.0, 0, -372.0), -90.0]]:
		_bench(b[0], b[1])
	for i in 26:
		var p := Vector3(rng.randf_range(-58, 58), 0, rng.randf_range(z1, z0))
		if pa.grow(4.0).has_point(Vector2(p.x, p.z)):
			continue
		_tree(p, ["park_linden", "park_plane", "park_birch"][rng.randi() % 3], rng.randf_range(0.9, 1.25))
	_lawn(Rect2(-60, z1 - 6, 120, z0 - z1 + 6), 1200, rng, 0.05)
	trigger(Vector3(0, 1.5, z0 - 2.0), Vector3(6, 3, 2), func():
		Game.set_flag("rm_playground")
		_swing_on = true
		Game.hud.show_thought("A playground. A huge one. ...Not a single child.", 3.5))
	trigger(Vector3(-24.0, 1.5, -352.0), Vector3(14, 3, 10), func():
		Game.hud.show_thought("There's no wind. ...It's still swinging.", 3.0))
	checkpoint_zone("playground", Vector3(0, 1.5, z0 - 2.0), Vector3(6, 3, 2), Vector3(0, 0.05, z0 - 2.0), 0.0)


# ------------------------------------------------------------------ 05 the impossible garden

func _impossible() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	# the approach: hedges that grow as you walk, from waist height to far over your head
	for k in 11:
		var za := -426.0 - k * 6.0
		var h := lerpf(2.4, 7.5, clampf(float(k) / 7.0, 0.0, 1.0))
		for side in [-1.0, 1.0]:
			if side > 0.0 and k == 5:
				continue      # (a gap: the path to a garden you've seen before)
			_hedge(Vector3(side * 3.5, 0, za), Vector3(side * 3.5, 0, minf(za - 6.0, HUB.z + 12.0) if k == 10 else za - 6.0), h)
	_path(Vector3(0, 0, -426.0), HUB + Vector3(0, 0, 12.0), 3.0, true)
	# the hub: a square room of tall hedge, a way in (south), the east and west corridors, the locked gate (north)
	var H := 7.5
	var e := 12.0
	_hedge(HUB + Vector3(-e, 0, e), HUB + Vector3(-2.0, 0, e), H)
	_hedge(HUB + Vector3(2.0, 0, e), HUB + Vector3(e, 0, e), H)
	_hedge(HUB + Vector3(-e, 0, -e), HUB + Vector3(-2.5, 0, -e), H)
	_hedge(HUB + Vector3(2.5, 0, -e), HUB + Vector3(e, 0, -e), H)
	_hedge(HUB + Vector3(-e, 0, e), HUB + Vector3(-e, 0, 2.0), H)
	_hedge(HUB + Vector3(-e, 0, -2.0), HUB + Vector3(-e, 0, -e), H)
	_hedge(HUB + Vector3(e, 0, e), HUB + Vector3(e, 0, 2.0), H)
	_hedge(HUB + Vector3(e, 0, -2.0), HUB + Vector3(e, 0, -e), H)
	box(HUB + Vector3(0, 0.012, 0), Vector3(2 * e, 0.024, 2 * e), GRAVEL, false, 0.0, "concrete")
	_paths.append(Rect2(HUB.x - e, HUB.z - e, 2 * e, 2 * e))
	_blue_bench(HUB + Vector3(-7.0, 0, 6.0), 90.0)
	prop("urn_plinth", HUB + Vector3(7.0, 0, 7.0), 0.0)
	blocker(HUB + Vector3(7.0, 1.0, 7.0), Vector3(0.8, 2.0, 0.8))
	# the gate: locked, iron; a music box playing somewhere beyond it
	var g := prop("garden_gate", GATE, 0.0)
	if g:
		for c in g.find_children("Leaf*", "MeshInstance3D", true, false):
			var pivot := Node3D.new()
			var left := String(c.name).begins_with("LeafL")
			pivot.position = Vector3(-2.1 if left else 2.1, 0, 0)
			g.add_child(pivot)
			c.get_parent().remove_child(c)
			pivot.add_child(c)
			c.position = Vector3.ZERO
			if left:
				_gate_l = pivot
			else:
				_gate_r = pivot
	blocker(GATE + Vector3(-2.45, 1.9, 0), Vector3(0.8, 3.8, 0.8))
	blocker(GATE + Vector3(2.45, 1.9, 0), Vector3(0.8, 3.8, 0.8))
	_gate_block = solid_box(GATE + Vector3(0, 1.5, 0), Vector3(4.2, 3.0, 0.3), Color(0, 0, 0))
	_gate_block.get_child(1).visible = false
	_musicbox = ambient("musicbox", GATE + Vector3(0, 1.5, -30.0), true, -6.0, 90.0)
	interactable(GATE + Vector3(0, 1.4, 0.5), Vector3(4.0, 2.8, 0.6), func(): return "The gate" if _gate_block else "",
		func():
			var n := _markers_done()
			Game.hud.show_thought(["Locked. ...Three empty sockets on the lock. Three of something.",
				"Locked. One socket filled. Two to go.", "Locked. Two filled. One more."][mini(n, 2)], 3.5),
		func(): return _gate_block != null)
	# WEST: a corridor of tall hedge and repeated arches, round a corner to a little garden room: marker one
	_hedge(HUB + Vector3(-e, 0, -2.0), HUB + Vector3(-70, 0, -2.0), H)
	_hedge(HUB + Vector3(-e, 0, 2.0), HUB + Vector3(-66, 0, 2.0), H)
	_hedge(HUB + Vector3(-70, 0, -2.0), HUB + Vector3(-70, 0, 40.0), H)
	_hedge(HUB + Vector3(-66, 0, 2.0), HUB + Vector3(-66, 0, 24.0), H)
	_path(HUB + Vector3(-e, 0, 0), HUB + Vector3(-68, 0, 0), 3.0, true)
	_path(HUB + Vector3(-68, 0, 0), HUB + Vector3(-68, 0, 30.0), 3.0, true)
	for x in [-24.0, -36.0, -48.0, -60.0]:
		prop("rose_arch", HUB + Vector3(x, 0, 0), 90.0)
	var room_w := HUB + Vector3(-58.0, 0, 32.0)
	_hedge(room_w + Vector3(-12, 0, -8), room_w + Vector3(-12, 0, 8), H)
	_hedge(room_w + Vector3(-12, 0, 8), room_w + Vector3(8, 0, 8), H)
	_hedge(room_w + Vector3(8, 0, 8), room_w + Vector3(8, 0, -8), H)
	_hedge(room_w + Vector3(-8, 0, -8), room_w + Vector3(8, 0, -8), H)
	furnish("flower_round", room_w + Vector3(2.0, 0, 2.0), 40.0, Vector3(3.2, 0.4, 3.2), Vector3(0, 0.2, 0))
	_marker(room_w + Vector3(-4.0, 0, -2.0))
	# EAST: a corridor that does not end (it repeats; turn round and it lets you go). Marker two in a niche, early on
	_hedge(HUB + Vector3(e, 0, 2.0), HUB + Vector3(200, 0, 2.0), H)
	_hedge(HUB + Vector3(e, 0, -2.0), HUB + Vector3(28, 0, -2.0), H)
	_hedge(HUB + Vector3(34, 0, -2.0), HUB + Vector3(200, 0, -2.0), H)
	_hedge(HUB + Vector3(28, 0, -2.0), HUB + Vector3(28, 0, -8.0), H)
	_hedge(HUB + Vector3(34, 0, -2.0), HUB + Vector3(34, 0, -8.0), H)
	_hedge(HUB + Vector3(28, 0, -8.0), HUB + Vector3(34, 0, -8.0), H)
	_marker(HUB + Vector3(31.0, 0, -5.5))
	_hedge(HUB + Vector3(200, 0, 2.0), HUB + Vector3(200, 0, -2.0), H)
	_path(HUB + Vector3(e, 0, 0), HUB + Vector3(200, 0, 0), 3.0, true)
	var ax := LOOP_FROM
	while ax < 200.0:
		prop("rose_arch", HUB + Vector3(ax, 0, 0), 90.0)
		ax += 15.0
	# SOUTH-EAST, off the approach: a garden you have already seen. The fountain, small. The blue bench. The coffees.
	var room_e := Vector3(30.0, 0, -459.0)
	for s in [[room_e + Vector3(-16, 0, -12), room_e + Vector3(16, 0, -12)], [room_e + Vector3(-16, 0, 12), room_e + Vector3(16, 0, 12)],
			[room_e + Vector3(16, 0, -12), room_e + Vector3(16, 0, 12)], [room_e + Vector3(-16, 0, -12), room_e + Vector3(-16, 0, -2)],
			[room_e + Vector3(-16, 0, 2), room_e + Vector3(-16, 0, 12)]]:
		_hedge(s[0], s[1], H)
	_path(Vector3(1.5, 0, -459.0), room_e + Vector3(-16, 0, -1.0), 3.0, true)
	if prop("fountain_grand", room_e, 0.0, 0.55):
		var fb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 3.4
		cy.height = 1.0
		cs.shape = cy
		cs.position = room_e + Vector3(0, 0.5, 0)
		fb.add_child(cs)
		add_child(fb)
		_still_water(room_e + Vector3(0, 0.34, 0), 2.8, 0.0)
	var cups := room_e + Vector3(-8.0, 0, 6.0)
	_blue_bench(cups, 135.0)
	for k in 2:
		prop("coffee_cup", cups + Vector3(-0.35 + k * 0.32, 0.46, 0.0), k * 80.0)
	_marker(room_e + Vector3(9.0, 0, -6.0))
	trigger(room_e + Vector3(-12, 1.5, 0), Vector3(2, 3, 4), func():
		Game.hud.show_thought("The fountain. The bench. The two coffees. ...Smaller. Like I'm remembering it wrong.", 4.5))
	# tall obelisks near each marker, white over the hedge tops: something to steer by
	for m in _markers:
		var at: Vector3 = (m[0] as Node3D).position
		prop("obelisk", at + Vector3(2.0, 0, 2.0), 0.0, 2.3)
		blocker(at + Vector3(2.0, 1.0, 2.0), Vector3(2.4, 2.0, 2.4))
	# lawn underfoot, between the hedges
	_lawn(Rect2(-80, -540, 150, 120), 900, rng, 0.0)
	trigger(Vector3(0, 1.5, -440.0), Vector3(7, 3, 2), func():
		Game.hud.show_thought("The hedges are taller here. ...They're growing. Aren't they?", 3.5))
	trigger(HUB + Vector3(0, 1.5, 8.0), Vector3(10, 3, 2), func():
		Game.set_flag("rm_impossible")
		Game.hud.show_thought("No sky line. No sound but that music box. ...And a gate.", 4.0))
	checkpoint_zone("hub", HUB + Vector3(0, 1.5, 11.0), Vector3(4, 3, 2), HUB + Vector3(0, 0.05, 11.0), 0.0)


func _marker(at: Vector3) -> void:
	var m := prop("marker", at, 0.0)
	if m == null:
		return
	blocker(at + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5))
	var glow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.19
	cm.bottom_radius = 0.19
	cm.height = 0.01
	glow.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.85, 0.5)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.8, 0.45)
	gm.emission_energy_multiplier = 0.0
	glow.material_override = gm
	glow.position = at + Vector3(0, 1.035, 0)
	add_child(glow)
	var rec := [m, glow, false]
	_markers.append(rec)
	interactable(at + Vector3(0, 1.0, 0), Vector3(0.7, 0.6, 0.7), func(): return "Touch the marker" if not rec[2] else "",
		func(): _activate(rec), func(): return not rec[2])


func _markers_done() -> int:
	return _markers.filter(func(r): return r[2]).size()


func _activate(rec: Array) -> void:
	rec[2] = true
	var gm := (rec[1] as MeshInstance3D).material_override as StandardMaterial3D
	create_tween().tween_property(gm, "emission_energy_multiplier", 3.0, 1.2)
	var n := _markers_done()
	Game.counters["markers"] = n
	Sfx.play_at("chime", self, (rec[1] as Node3D).global_position, -4.0, 30.0, [1.0, 1.26, 1.5][clampi(n - 1, 0, 2)])
	Game.hud.show_thought(["It's warm. It hummed. ...One.", "Another. Somewhere a lock turned a little. Two.", "Three. ...The music's stopped."][clampi(n - 1, 0, 2)], 3.5)
	if n >= 3:
		_open_gate()


func _open_gate() -> void:
	Game.set_flag("rm_gate")
	if _musicbox:
		var mb := _musicbox
		create_tween().tween_property(mb, "volume_db", -80.0, 2.0)
	if _gate_block:
		_gate_block.queue_free()
		_gate_block = null
	Sfx.play_at("creak", self, GATE + Vector3(0, 1.5, 0), -2.0, 40.0, 0.7)
	if _gate_l:
		create_tween().tween_property(_gate_l, "rotation_degrees:y", -100.0, 3.0).set_trans(Tween.TRANS_SINE)
	if _gate_r:
		create_tween().tween_property(_gate_r, "rotation_degrees:y", 100.0, 3.0).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ 06 the exit

func _exit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	_path(GATE, ARCH + Vector3(0, 0, 2.0), 3.6, true)
	# the hedges fall away as you go: tall by the gate, waist-high, then nothing but lawn
	for k in 10:
		var za := GATE.z - k * 4.0
		var h := lerpf(7.5, 0.0, float(k) / 9.0)
		if h > 0.6:
			for side in [-1.0, 1.0]:
				_hedge(Vector3(side * 3.5, 0, za), Vector3(side * 3.5, 0, za - 4.0), h)
	# the lawn either side, a few still trees; the park's end is a stone wall, with the arch in it
	_lawn(Rect2(-40, ARCH.z, 80, GATE.z - ARCH.z - 2.0), 600, rng, 0.06)
	for p in [Vector3(-16, 0, -575), Vector3(18, 0, -580), Vector3(-24, 0, -560), Vector3(26, 0, -556)]:
		_tree(p, "park_linden", 1.1, 40.0)
	for side in [-1.0, 1.0]:
		_hedge(Vector3(side * 40.0, 0, -545.0), Vector3(side * 40.0, 0, ARCH.z), 2.4)
		box(Vector3(side * 22.0, 1.6, ARCH.z), Vector3(36.0, 3.2, 1.2), Color(0.9, 0.89, 0.86), true, 0.0, "concrete")
	if prop("stone_archway", ARCH, 0.0):
		for sx in [-1.0, 1.0]:
			blocker(ARCH + Vector3(sx * 3.8, 5.0, 0), Vector3(1.6, 10.0, 1.6))
	trigger(ARCH + Vector3(0, 1.5, 14.0), Vector3(8, 3, 2), func():
		Game.set_flag("rm_arch")
		Game.hud.show_thought("A street. A real one. Cars, kerbs, a bus stop. ...Through there.", 4.0))
	_street()


## An ordinary street, beyond the arch. It exists twice: here, seen through the arch, with the park's wall on its
## near side; and far away (STREET_FAR), the same street with ordinary shops where the park should be. Step
## through the arch and you're on the far one. Turn round: no arch, no park. Just a street.
const STREET_FAR := Vector3(3000, 0, 0)


func _street() -> void:
	_street_copy(Vector3.ZERO, false)
	_street_copy(STREET_FAR, true)


func _street_copy(o: Vector3, far: bool) -> void:
	var z := STREET_Z
	box(o + Vector3(0, -0.25, z - 20.0), Vector3(200, 0.5, 64), Color(0.09, 0.095, 0.105), true, 0.0, "asphalt")
	box(o + Vector3(0, 0.075, z + 11.5), Vector3(120, 0.15, 7.0 if not far else 7.0), Color(0.62, 0.6, 0.56), true, 0.0, "pavers")
	box(o + Vector3(0, 0.075, z - 9.5), Vector3(120, 0.15, 5.0), Color(0.62, 0.6, 0.56), true, 0.0, "pavers")
	var t := -60.0
	while t < 60.0:
		box(o + Vector3(t, 0.015, z), Vector3(3, 0.02, 0.14), Color(0.85, 0.75, 0.3), false)
		t += 6.0
	for x in [-36.0, -12.0, 14.0, 38.0]:
		facade_building(o + Vector3(x, 0.15, z - 22.0), 22.0, 14.0, 4, ["brick", "plaster", "modern", "plaster"][int(x + 36.0) % 4], Color(0.85, 0.7, 0.55), true)
	if far:
		# where the park was: a row of shops, a pavement, nothing else
		box(o + Vector3(0, -0.25, z + 30.0), Vector3(200, 0.5, 30), Color(0.09, 0.095, 0.105), true, 0.0, "asphalt")
		for x in [-48.0, -24.0, 0.0, 24.0, 48.0]:
			facade_building(o + Vector3(x, 0.15, z + 23.0), 22.0, 10.0, 3 + int(absf(x)) % 3, ["plaster", "brick", "modern"][int(absf(x) / 24.0) % 3], Color(0.82, 0.74, 0.62), true)
		blocker(o + Vector3(0, 5, z + 16.0), Vector3(120, 10, 1))
	for c in [[Vector3(-20, 0, z + 5.0), 0.0], [Vector3(9, 0, z - 4.5), 0.0], [Vector3(30, 0, z + 5.0), 180.0]]:
		if prop("car_%d" % (absi(int(c[0].x)) % 5), o + (c[0] as Vector3), c[1]):
			blocker(o + (c[0] as Vector3) + Vector3(0, 0.75, 0), Vector3(4.4, 1.5, 1.8))
	for x in [-28.0, 0.0, 28.0]:
		if prop("lamp_post", o + Vector3(x, 0.15, z - 8.0), 0.0, 1.1):
			blocker(o + Vector3(x, 2.5, z - 8.0), Vector3(0.25, 5.0, 0.25))
	furnish("bus_shelter", o + Vector3(18.0, 0.15, z - 9.0), 90.0)
	for e in [[Vector3(0, 5, z - 13.0), Vector3(120, 10, 1)], [Vector3(-60, 5, z), Vector3(1, 10, 40)], [Vector3(60, 5, z), Vector3(1, 10, 40)]]:
		blocker(o + (e[0] as Vector3), e[1])


func _cross_threshold() -> void:
	_on_street = true
	Game.set_flag("rm_exit")
	var pl = Game.player
	pl.global_position += STREET_FAR
	_last_pos = pl.global_position
	# ordinary afternoon again: plain light, a breeze, traffic
	_sun.light_energy = 1.35
	_sun.shadow_blur = 1.0
	_env.ambient_light_energy = 0.55
	_env.ambient_light_color = Color(0.78, 0.8, 0.86)
	_env.fog_density = 0.003
	_sky.set_shader_parameter("cloud_speed", 0.004)
	Props.set_wind(1.0)
	(_amb["traffic"] as AudioStreamPlayer).volume_db = -7.0
	(_amb["wind"] as AudioStreamPlayer).volume_db = -22.0
	(_amb["hum"] as AudioStreamPlayer).volume_db = -80.0
	Sfx.music_gain = 0.0


# ------------------------------------------------------------------ the city round the park (and how it goes)

func _city_around() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/glass_tower.gdshader")
	for spec in [[Vector3(-100, 0, 30), 70.0], [Vector3(-130, 0, -20), 110.0], [Vector3(-115, 0, -80), 90.0], [Vector3(-125, 0, -150), 120.0],
			[Vector3(105, 0, 25), 85.0], [Vector3(125, 0, -40), 100.0], [Vector3(110, 0, -110), 130.0], [Vector3(140, 0, -180), 95.0],
			[Vector3(-30, 0, 70), 60.0], [Vector3(30, 0, 80), 75.0], [Vector3(-90, 0, -240), 80.0], [Vector3(100, 0, -260), 90.0]]:
		var at: Vector3 = spec[0]
		var h: float = spec[1]
		var w := rng.randf_range(16, 26)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, w * rng.randf_range(0.8, 1.2))
		mi.mesh = bm
		mi.material_override = mat
		mi.position = at + Vector3(0, h * 0.5, 0)
		add_child(mi)
		_skyline.append(mi)


func _lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42, -150, 0)
	_sun.light_color = Color(1.0, 0.94, 0.84)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 110.0
	add_child(_sun)
	_sky = ShaderMaterial.new()
	_sky.shader = load("res://scripts/world/sky.gdshader")
	_sky.set_shader_parameter("zenith", Color(0.14, 0.4, 0.86))
	_sky.set_shader_parameter("horizon", Color(0.72, 0.83, 0.95))
	_sky.set_shader_parameter("cloud_cover", 0.38)
	_sky.set_shader_parameter("sun_size", 0.9988)
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = make_env(Color(0.78, 0.8, 0.86), 0.55)
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_exposure = 1.05
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.08
	_env.adjustment_contrast = 1.04
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.78, 0.84, 0.93)
	_env.fog_density = 0.003
	_env.fog_sky_affect = 0.12
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_bloom = 0.1
	_env.glow_hdr_threshold = 1.1
	if Settings.quality >= 1:
		_env.ssao_enabled = true
		_env.ssil_enabled = true
		_env.ssr_enabled = true
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = 0.003
		_env.volumetric_fog_albedo = Color(1.0, 0.96, 0.9)
	environment(_env)


func _audio() -> void:
	_amb["traffic"] = ambient("city", Vector3.ZERO, false, -16.0)
	_amb["wind"] = ambient("wind", Vector3.ZERO, false, -20.0)
	_amb["hum"] = ambient("hum", Vector3.ZERO, false, -80.0)
	Sfx.music_gain = 0.35


# ------------------------------------------------------------------ the walk changes as you go

## 0 at the gates .. 1 in the impossible garden (and the exit path); used for everything that changes.
func _depth(z: float) -> float:
	return clampf(remap(z, -150.0, -470.0, 0.0, 1.0), 0.0, 1.0)


var _next_chirp := 1.0


func on_player_entered(_from_save: bool) -> void:
	_t = 0.0
	_last_pos = Game.player.global_position if Game.player else Vector3.ZERO


func _process(delta: float) -> void:
	_t += delta
	var pl = Game.player
	if pl == null:
		return
	var p: Vector3 = pl.global_position
	var d := _depth(p.z)
	var exit_k := clampf(remap(p.z, -545.0, -598.0, 0.0, 1.0), 0.0, 1.0)     # stillness before the arch
	# --- light: afternoon -> warm at the fountain -> flat in the playground -> static, artificial in the garden
	if _sun and not _on_street:
		var warm := clampf(1.0 - absf(p.z - FOUNTAIN.z) / 40.0, 0.0, 1.0)
		_sun.light_color = Color(1.0, 0.94, 0.84).lerp(Color(1.0, 0.86, 0.68), warm * 0.6)
		var flat := clampf(remap(p.z, -330.0, -430.0, 0.0, 1.0), 0.0, 1.0)
		_sun.light_energy = lerpf(1.35, 0.75, flat) * (1.0 - exit_k * 0.0)
		_env.ambient_light_energy = lerpf(0.55, 0.85, flat)
		_env.ambient_light_color = Color(0.78, 0.8, 0.86).lerp(Color(0.95, 0.95, 0.97), flat)
		_sun.shadow_blur = lerpf(1.0, 4.0, flat)
		_sky.set_shader_parameter("cloud_speed", lerpf(0.004, 0.0, clampf(remap(p.z, -400.0, -460.0, 0.0, 1.0), 0.0, 1.0)))
		_env.fog_density = lerpf(0.003, 0.0055, clampf(remap(p.z, -430.0, -480.0, 0.0, 1.0), 0.0, 1.0)) * (1.0 - exit_k * 0.4)
	# --- wind: alive at the gates; gone in the impossible garden; barely there by the arch
	if not _on_street:
		Props.set_wind(lerpf(1.0, 0.0, clampf(remap(p.z, -330.0, -440.0, 0.0, 1.0), 0.0, 1.0)) + 0.08 * exit_k * 0.0)
	# --- sound: traffic, wind and birds fade away; a hum in the impossible garden; music to nothing before the arch
	if not _on_street:
		(_amb["traffic"] as AudioStreamPlayer).volume_db = lerpf(-16.0, -46.0, clampf(d * 1.4, 0.0, 1.0))
		(_amb["wind"] as AudioStreamPlayer).volume_db = lerpf(-20.0, -42.0, d) - exit_k * 8.0
		var hum_k := clampf(remap(p.z, -430.0, -480.0, 0.0, 1.0), 0.0, 1.0) * (1.0 - exit_k)
		(_amb["hum"] as AudioStreamPlayer).volume_db = lerpf(-80.0, -26.0, sqrt(hum_k))
		Sfx.music_gain = 0.35 * clampf(1.0 - d * 1.6, 0.0, 1.0) * (1.0 - exit_k)
		if _t > _next_chirp:
			_next_chirp = _t + randf_range(1.5, 5.0) + d * 25.0
			if d < 0.6:
				Sfx.play_at("chirp", self, p + Vector3(randf_range(-15, 15), randf_range(5, 10), randf_range(-15, 15)), -6.0 - d * 14.0, 40.0)
	# --- the clock tower keeps its distance; the skyline goes, a tower at a time, when you aren't looking
	if _clock and not _on_street:
		_clock.global_position = Vector3(p.x - 70.0, 0.0, p.z - 230.0)
		_clock.visible = d < 0.75
	for b in _skyline:
		if b.visible and d > 0.15 + (_skyline.find(b) % 6) * 0.1 and not Observation.is_observed(b.global_position + Vector3(0, 20, 0), 0.3):
			b.visible = false
	# --- the swing, moving on its own; a bicycle bell, once, far away
	if _swing_seat and _swing_on:
		_swing_t += delta
		var amp := 0.42 * clampf(_swing_t / 4.0, 0.0, 1.0)
		var ang := sin(_swing_t * 2.05) * amp
		_swing_seat.rotation.x = ang
		_swing_creak -= delta
		if absf(cos(_swing_t * 2.05)) < 0.05 and _swing_creak <= 0.0 and p.distance_to(_swing_seat.global_position) < 30.0:
			_swing_creak = 0.8
			Sfx.play_at("creak", self, _swing_seat.global_position, -14.0, 25.0, randf_range(1.3, 1.5))
	if not _bell_done and p.z < -360.0 and p.z > -420.0:
		_bell_done = true
		Sfx.play_at("ding", self, Vector3(55.0, 2.0, -400.0), -10.0, 120.0, 1.6)
	# --- footsteps that aren't yours: in the playground, a few times, a step behind you just after your own
	var moved := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	if _echo_left > 0 and p.z < -340.0 and p.z > -425.0 and moved > 0.0:
		_echo_dist += moved
		if _echo_dist > 9.0:
			_echo_dist = randf_range(-6.0, 0.0)
			_echo_left -= 1
			var back: Vector3 = pl.global_transform.basis.z       # (the way you're not looking)
			var behind := p + Vector3(back.x, 0, back.z).normalized() * 5.5
			get_tree().create_timer(0.28).timeout.connect(func():
				if is_inside_tree():
					Sfx.play_at("step_concrete_%d" % (randi() % 4), self, behind, -9.0, 20.0, 0.92))
	# --- markers you haven't found call quietly
	_marker_ping -= delta
	if _marker_ping <= 0.0 and p.z < -440.0 and not _on_street:
		_marker_ping = 5.5
		for m in _markers:
			if not m[2]:
				Sfx.play_at("chime", self, (m[1] as Node3D).global_position, -22.0, 45.0, 2.0)
	# --- the corridor that doesn't end: walk far enough east and you're further back along it, none the wiser
	if p.z < HUB.z + 2.0 and p.z > HUB.z - 2.0 and p.x > HUB.x + LOOP_FROM + 2.0 * LOOP_LEN:
		pl.global_position = p - Vector3(LOOP_LEN, 0, 0)
		_last_pos = pl.global_position
		_loops += 1
		if _loops == 2:
			Game.hud.show_thought("This path doesn't end. ...I should go back the way I came.", 4.0)
	# --- the street
	if not _on_street and p.z < ARCH.z - 1.0 and absf(p.x) < 4.0:
		_cross_threshold()
	if _on_street:
		_street_t += delta
		if _street_t > 4.0 and _street_t - delta <= 4.0:
			Game.on_remember_exit()
