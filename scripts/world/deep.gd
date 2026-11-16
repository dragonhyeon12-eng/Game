class_name DeepZone
extends Zone
## THE DEEP - aquaphobia. A night-time indoor swimming complex.
##
## Goal: the way out is a door at the bottom of the diving well - which goes down much further than
## it should. To reach it the well must be drained from the pump room. The pump room's door is jammed;
## the only way in is an underwater tunnel in the main pool, which surfaces somewhere it shouldn't.
## And the water only goes down while somebody is watching it. Look away and the dream fills it again.
##
## Also: the main pool's water level changes when unobserved, and the water sometimes shows a figure
## standing where nobody stands.
##
## The well has no bottom. Below it is an impossibly vast ocean - a trench walled by cliffs, where
## leviathans circle. Once drained, you sink into it. Looking down fills DREAD fast. Near the sea floor
## two black hands come up out of it and pull you down: into the second part (SeabedZone).

const HALL_X := 32.0
const HALL_Z := 18.0
const CEIL := 10.0
const MAIN := Rect2(-22, -8, 28, 16)     # x, z, width, depth (x: -22..6, z: -8..8)
const MAIN_DEPTH := 2.2
const WELL := Rect2(12, -7, 12, 14)      # x: 12..24, z: -7..7
const WELL_DEPTH := 30.0
const OCEAN_TOP := -30.0     # the sea's surface, where the well's floor should have been
const SEABED := -175.0
const OCEAN_CENTER := Vector3(18, 0, 0)
const REST := -0.15                      # normal water level
const DRAIN_RATE := 1.6                  # m/s while watched
const REFILL_RATE := 0.7                 # m/s while unobserved

const DECK := Color(0.72, 0.76, 0.78)
const TILE := Color(0.55, 0.78, 0.86)
const WALL := Color(0.78, 0.8, 0.8)
const CONCRETE := Color(0.5, 0.52, 0.52)

var main_level := REST
var well_level := REST
var drained := false
var drain_rate_override := -1.0   # tests
var lever_pulled := false

var _main_water: Node3D
var _well_water: Node3D
var _pump_door: StaticBody3D
var _lever_arm: Node3D
var _gurgle: AudioStreamPlayer3D
var observer: Observer
var reflection: Observer
var _obs_cooldown := 45.0
var _refl_cooldown := 70.0
var _obs_check := 0.0
var _t := 0.0
var _hint := 0
var _drip := 2.0
var _in_tunnel := false
var _saw_well := false
var _env_hall: Environment
var _env_ocean: Environment
var _world_env: WorldEnvironment
var _in_ocean := false
var _grabbed := false
var leviathans: Array[Leviathan] = []
var _handle_pickup: Node3D
var _locker_door: Node3D
var _gate: StaticBody3D
var _gate_hint := false
const GATE_POS := Vector3(11.5, 0, 0)


func zone_id() -> String: return "deep"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 15.0
func fear_decay() -> float: return 1.0
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.4
func sprint_speed() -> float: return 4.0
func anomaly_pacing() -> Vector2: return Vector2(30, 6)


func player_start() -> Transform3D:
	# by the entrance doors, south side, looking out over the main pool
	return Transform3D(Basis(Vector3.UP, deg_to_rad(15)), Vector3(-6, 0.05, 15))


# ------------------------------------------------------------------ water queries (used by the player)

func water_level_at(p: Vector3) -> float:
	if p.y < OCEAN_TOP and Vector2(p.x - OCEAN_CENTER.x, p.z - OCEAN_CENTER.z).length() < 400.0:
		return OCEAN_TOP + 0.1  # the sea
	if _in_rect(MAIN, p) and p.y > -MAIN_DEPTH - 1.0:
		return main_level
	if _in_rect(WELL, p) and not drained:
		return well_level
	if p.x < MAIN.position.x and p.x > -26.5 and absf(p.z) < 0.7 and p.y < -0.6:
		return 0.0  # the flooded tunnel
	return -INF


## In the sea you can breathe. You shouldn't be able to.
func breathable_at(p: Vector3) -> bool:
	return p.y < OCEAN_TOP


## In water you normally float up; in the sea you sink, and cannot swim against it.
func swim_drift_at(p: Vector3) -> float:
	return -8.0 if p.y < OCEAN_TOP else 0.8


func gravity_scale_at(p: Vector3) -> float:
	# dream gravity inside the drained well: you sink slowly down into it
	return 0.5 if drained and _in_rect(WELL, p) and p.y < -0.5 else 1.0


func max_fall_at(p: Vector3) -> float:
	return 9.0 if drained and _in_rect(WELL, p) and p.y < -0.5 else 60.0


static func _in_rect(r: Rect2, p: Vector3) -> bool:
	return p.x > r.position.x and p.x < r.end.x and p.z > r.position.y and p.z < r.end.y


# ------------------------------------------------------------------ build

func build() -> void:
	_hall()
	_main_pool()
	_tunnel()
	_well()
	_pump_room()
	_props()
	_objectives()
	_sea_life()
	_lighting()
	_register_anomalies()
	_characters()
	ambient("water_lap", Vector3(-8, 0.2, 0), true, -2.0, 30.0)
	ambient("water_lap", Vector3(18, 0.2, 0), true, -6.0, 24.0)
	ambient("hum", Vector3(0, 9, 0), false, -24.0)
	_gurgle = ambient("gurgle", Vector3(18, -1, 0), true, -80.0, 40.0) as AudioStreamPlayer3D


func _hall() -> void:
	# deck (floor around the pools)
	box(Vector3(0, -0.15, -13), Vector3(64, 0.3, 10), DECK, true, 0.0, "tiles_floor")
	box(Vector3(0, -0.15, 13), Vector3(64, 0.3, 10), DECK, true, 0.0, "tiles_floor")
	box(Vector3(-27, -0.15, 0), Vector3(10, 0.3, 16), DECK, true, 0.0, "tiles_floor")
	box(Vector3(9, -0.15, 0), Vector3(6, 0.3, 16), DECK, true, 0.0, "tiles_floor")
	box(Vector3(28, -0.15, 0), Vector3(8, 0.3, 16), DECK, true, 0.0, "tiles_floor")
	box(Vector3(18, -0.15, -7.5), Vector3(12, 0.3, 1), DECK, true, 0.0, "tiles_floor")
	box(Vector3(18, -0.15, 7.5), Vector3(12, 0.3, 1), DECK, true, 0.0, "tiles_floor")
	# coping around the pool edges
	for r in [MAIN, WELL]:
		var c := Vector3(r.position.x + r.size.x * 0.5, 0.02, r.position.y + r.size.y * 0.5)
		box(c + Vector3(0, 0, -r.size.y * 0.5 - 0.15), Vector3(r.size.x + 0.6, 0.06, 0.3), Color(0.92, 0.92, 0.9), false)
		box(c + Vector3(0, 0, r.size.y * 0.5 + 0.15), Vector3(r.size.x + 0.6, 0.06, 0.3), Color(0.92, 0.92, 0.9), false)
		box(c + Vector3(-r.size.x * 0.5 - 0.15, 0, 0), Vector3(0.3, 0.06, r.size.y), Color(0.92, 0.92, 0.9), false)
		box(c + Vector3(r.size.x * 0.5 + 0.15, 0, 0), Vector3(0.3, 0.06, r.size.y), Color(0.92, 0.92, 0.9), false)
	# walls: tiled to 2.4 m, painted above
	for side in [-1.0, 1.0]:
		box(Vector3(0, 1.2, HALL_Z * side), Vector3(HALL_X * 2, 2.4, 0.3), TILE.lightened(0.3), true, 0.0, "tiles_pool")
		box(Vector3(0, 6.2, HALL_Z * side), Vector3(HALL_X * 2, 7.6, 0.3), WALL, true, 0.0, "plaster")
	box(Vector3(-HALL_X, 1.2, 0), Vector3(0.3, 2.4, HALL_Z * 2), TILE.lightened(0.3), true, 0.0, "tiles_pool")
	box(Vector3(-HALL_X, 6.2, 0), Vector3(0.3, 7.6, HALL_Z * 2), WALL, true, 0.0, "plaster")
	# east wall, with a window (z -4..0, y 1..2.4) and a door (z 2.5..3.5) into the pump room
	var ex := HALL_X
	box(Vector3(ex, 5.0, 0), Vector3(0.3, 10, 0.01), WALL, false)  # (keeps the batch non-empty)
	box(Vector3(ex, 5.0, -11), Vector3(0.3, 10, 14), WALL, true, 0.0, "plaster")        # z -18..-4
	box(Vector3(ex, 5.0, 10.75), Vector3(0.3, 10, 14.5), WALL, true, 0.0, "plaster")    # z 3.5..18
	box(Vector3(ex, 5.0, 1.25), Vector3(0.3, 10, 2.5), WALL, true, 0.0, "plaster")      # z 0..2.5
	box(Vector3(ex, 0.5, -2), Vector3(0.3, 1.0, 4), WALL, true, 0.0, "plaster")         # under window
	box(Vector3(ex, 6.2, -2), Vector3(0.3, 7.6, 4), WALL, true, 0.0, "plaster")         # over window
	box(Vector3(ex, 6.05, 3), Vector3(0.3, 7.9, 1.0), WALL, true, 0.0, "plaster")       # over door
	# the window: solid to your body, but you can see (and watch) through it
	var glass := solid_box(Vector3(ex, 1.7, -2), Vector3(0.06, 1.4, 4), Color(0.6, 0.75, 0.8), null, "glass")
	glass.collision_layer = 4
	label(Vector3(ex - 0.17, 2.7, -2), -90, "PUMP ROOM", 0.25, Color(0.2, 0.22, 0.25), false)
	# ceiling + light strips (some dead)
	box(Vector3(0, CEIL + 0.15, 0), Vector3(HALL_X * 2, 0.3, HALL_Z * 2), Color(0.6, 0.62, 0.62), true, 0.0, "tiles_ceiling")
	for i in 6:
		var z := -15.0 + i * 6.0
		var alive := i != 2 and i != 5
		part("box", Vector3(0, CEIL - 0.05, z), Vector3(50, 0.08, 0.35), Color(0.9, 0.95, 1.0) if alive else Color(0.3, 0.32, 0.33),
			null, Vector3.ZERO, 2.5 if alive else 0.0)
	# entrance doors behind the start (locked: the dream has no way back)
	door(Vector3(-6, 0, HALL_Z - 0.17), 180, Color(0.35, 0.45, 0.5), 1.6, 2.3, "metal")
	interactable(Vector3(-6, 1.1, HALL_Z - 0.3), Vector3(1.8, 2.2, 0.3), func(): return "Entrance doors",
		func(): Game.hud.show_thought("They don't open. There's only water on the other side of the glass anyway.", 3.5))


func _basin(r: Rect2, depth: float, hole := false, has_floor := true) -> void:
	var c := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	if has_floor:
		box(Vector3(c.x, -depth - 0.15, c.z), Vector3(r.size.x, 0.3, r.size.y), TILE, true, 0.0, "tiles_pool")
	var y := -depth * 0.5 - 0.15
	var hgt := depth + 0.0
	box(Vector3(c.x, y, r.position.y - 0.15), Vector3(r.size.x + 0.6, hgt, 0.3), TILE, true, 0.0, "tiles_pool")
	box(Vector3(c.x, y, r.end.y + 0.15), Vector3(r.size.x + 0.6, hgt, 0.3), TILE, true, 0.0, "tiles_pool")
	box(Vector3(r.end.x + 0.15, y, c.z), Vector3(0.3, hgt, r.size.y), TILE, true, 0.0, "tiles_pool")
	var wx := r.position.x - 0.15
	if not hole:
		box(Vector3(wx, y, c.z), Vector3(0.3, hgt, r.size.y), TILE, true, 0.0, "tiles_pool")
	else:
		# west wall with a dark square opening (z -0.6..0.6, y -2.0..-0.8)
		box(Vector3(wx, y, (r.position.y - 0.6) * 0.5), Vector3(0.3, hgt, r.position.y * -1.0 - 0.6), TILE, true, 0.0, "tiles_pool")
		box(Vector3(wx, y, (r.end.y + 0.6) * 0.5), Vector3(0.3, hgt, r.end.y - 0.6), TILE, true, 0.0, "tiles_pool")
		box(Vector3(wx, -0.55, 0), Vector3(0.3, 0.5, 1.2), TILE, true, 0.0, "tiles_pool")
		box(Vector3(wx, -2.15, 0), Vector3(0.3, 0.3, 1.2), TILE, true, 0.0, "tiles_pool")


func _water(r: Rect2, level: float) -> Node3D:
	var root := group(Vector3(r.position.x + r.size.x * 0.5, level, r.position.y + r.size.y * 0.5))
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(r.size.x, r.size.y)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/water.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


func _main_pool() -> void:
	_basin(MAIN, MAIN_DEPTH, true)
	# lane lines on the bottom
	for i in range(1, 8):
		var z := MAIN.position.y + i * 2.0
		box(Vector3(MAIN.position.x + MAIN.size.x * 0.5, -MAIN_DEPTH + 0.005, z), Vector3(MAIN.size.x - 3.0, 0.02, 0.25), Color(0.08, 0.15, 0.4), false)
	_main_water = _water(MAIN, main_level)
	# lane ropes float on the water (one batched mesh, moving with the water)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Shapes.mesh("sphere")
	mm.instance_count = 7 * 46
	var idx := 0
	for i in range(1, 8):
		var z := -MAIN.size.y * 0.5 + i * 2.0
		for k in 46:
			var x := -MAIN.size.x * 0.5 + 0.3 + k * 0.6
			mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3.ONE * 0.11), Vector3(x, 0.02, z)))
			mm.set_instance_color(idx, Color(0.85, 0.15, 0.12) if (k / 4) % 2 == 0 else Color(0.95, 0.95, 0.95))
			idx += 1
	var ropes := MultiMeshInstance3D.new()
	ropes.multimesh = mm
	ropes.material_override = Shapes.surface("plain@0.4")
	ropes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_main_water.add_child(ropes)
	# pool ladders
	for p in [Vector3(5.6, 0, -6), Vector3(-21.6, 0, 6)]:
		var dir := -1.0 if p.x > 0 else 1.0
		for side in [-0.25, 0.25]:
			shape_at("cylinder", p + Vector3(0, -0.3, side), Vector3(0.05, 1.6, 0.05), Color(0.8, 0.82, 0.85), false, Vector3.ZERO, "metal")
			shape_at("cylinder", p + Vector3(0.2 * -dir, 0.55, side), Vector3(0.05, 0.5, 0.05), Color(0.8, 0.82, 0.85), false, Vector3(0, 0, 45 * dir), "metal")
		for step in 3:
			box(p + Vector3(0, -0.4 - step * 0.4, 0), Vector3(0.12, 0.04, 0.5), Color(0.8, 0.82, 0.85), false, 0.0, "metal")


func _tunnel() -> void:
	# a square duct under the deck, heading west, flooded and dark
	var x0 := MAIN.position.x - 0.3
	box(Vector3(x0 - 2.0, -2.05, 0), Vector3(4.0, 0.1, 1.4), TILE.darkened(0.4), true, 0.0, "tiles_pool")
	box(Vector3(x0 - 2.0, -0.55, 0), Vector3(4.0, 0.5, 1.4), TILE.darkened(0.4), true, 0.0, "tiles_pool")
	box(Vector3(x0 - 2.0, -1.4, -0.7), Vector3(4.0, 1.6, 0.1), TILE.darkened(0.4), true, 0.0, "tiles_pool")
	box(Vector3(x0 - 2.0, -1.4, 0.7), Vector3(4.0, 1.6, 0.1), TILE.darkened(0.4), true, 0.0, "tiles_pool")
	box(Vector3(x0 - 4.1, -1.4, 0), Vector3(0.2, 1.6, 1.4), Color(0.02, 0.03, 0.04), true)   # the end: just dark
	# the inside of the duct is water too
	var w := _water(Rect2(x0 - 4.0, -0.6, 4.0, 1.2), -0.82)
	w.get_child(0).material_override.set_shader_parameter("clarity", 0.8)


func _well() -> void:
	_basin(WELL, WELL_DEPTH, false, false)   # no floor: the tiles just... end
	_well_water = _water(WELL, well_level)
	# a few lights down the walls, then nothing
	omni(Vector3(18, -2.0, -6.6), Color(0.3, 0.85, 1.0), 1.4, 8.0, false)
	omni(Vector3(18, -2.0, 6.6), Color(0.3, 0.85, 1.0), 1.4, 8.0, false)
	omni(Vector3(18, -9.0, 0), Color(0.2, 0.6, 0.8), 0.6, 8.0, false)
	_ocean()


func _ocean() -> void:
	var c := OCEAN_CENTER
	var rock := Color(0.05, 0.06, 0.075)
	# the rock ceiling over the sea, with the well opening through it
	var top := OCEAN_TOP + 1.0
	var span := 900.0
	box(Vector3(c.x, top, WELL.position.y - span * 0.5), Vector3(span, 2.0, span), rock, false, 0.0, "concrete")
	box(Vector3(c.x, top, WELL.end.y + span * 0.5), Vector3(span, 2.0, span), rock, false, 0.0, "concrete")
	box(Vector3(WELL.position.x - span * 0.5, top, 0), Vector3(span, 2.0, WELL.size.y), rock, false, 0.0, "concrete")
	box(Vector3(WELL.end.x + span * 0.5, top, 0), Vector3(span, 2.0, WELL.size.y), rock, false, 0.0, "concrete")
	# the surface of the sea, seen from above through the well
	var surface := _water(Rect2(c.x - 450, -450, 900, 900), OCEAN_TOP)
	var sm: ShaderMaterial = surface.get_child(0).material_override
	sm.set_shader_parameter("shallow", Color(0.02, 0.12, 0.18))
	sm.set_shader_parameter("deep", Color(0.0, 0.02, 0.05))
	sm.set_shader_parameter("clarity", 0.35)
	# the trench: cliffs all around, falling away into the dark
	var rng := RandomNumberGenerator.new()
	rng.seed = 1312
	for i in 30:
		var a := i * TAU / 30.0 + rng.randf_range(-0.05, 0.05)
		var radius := rng.randf_range(115.0, 150.0)
		var h := rng.randf_range(140.0, 230.0)
		var w := rng.randf_range(28.0, 45.0)
		var pos := c + Vector3(cos(a) * radius, SEABED + h * 0.5 - 20.0, sin(a) * radius)
		box(pos, Vector3(w, h, rng.randf_range(20.0, 40.0)), rock.lightened(rng.randf_range(0.0, 0.08)), false, rad_to_deg(-a) + 90.0, "concrete")
		# ledges and overhangs
		for k in 2:
			var ly := SEABED + rng.randf_range(20.0, h - 30.0)
			box(c + Vector3(cos(a) * (radius - 14.0), ly, sin(a) * (radius - 14.0)), Vector3(w * 0.7, rng.randf_range(4.0, 9.0), 14.0),
				rock.lightened(0.05), false, rad_to_deg(-a) + 90.0, "concrete")
	# the sea floor, far below, with faint living lights on it
	box(Vector3(c.x, SEABED - 1.0, c.z), Vector3(320, 2.0, 320), Color(0.06, 0.07, 0.07), true, 0.0, "concrete")
	for i in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 110.0)
		part("sphere", c + Vector3(cos(a) * r, SEABED + 0.2, sin(a) * r), Vector3.ONE * rng.randf_range(0.3, 1.2),
			Color(0.1, 0.5, 0.9), null, Vector3.ZERO, rng.randf_range(1.0, 3.0))
	# a cold shaft of light from the well, falling into the sea
	spot(Vector3(18, OCEAN_TOP - 1.0, 0), Vector3(18, SEABED, 0), Color(0.4, 0.75, 0.9), 3.0, 120.0, 14.0, false)
	# leviathans, circling in the murk
	for spec in [[48.0, -80.0, 1.0, 1.2, 8.0], [80.0, -115.0, -1.0, 1.7, 7.0], [40.0, -145.0, 1.0, 1.3, 6.0]]:
		var lev := Leviathan.new()
		lev.orbit_center = c
		lev.orbit_radius = spec[0]
		lev.orbit_height = spec[1]
		lev.orbit_dir = spec[2]
		lev.thickness = spec[3]
		lev.speed = spec[4]
		add_child(lev)
		leviathans.append(lev)


	# diving boards and a platform tower on the south side
	box(Vector3(16, 0.6, 7.6), Vector3(0.6, 0.12, 3.0), Color(0.85, 0.85, 0.82), true)
	box(Vector3(16, 0.3, 8.8), Vector3(0.4, 0.6, 0.4), CONCRETE, true, 0.0, "concrete")
	box(Vector3(21, 2.5, 9.0), Vector3(2.0, 5.0, 2.0), CONCRETE, true, 0.0, "concrete")
	box(Vector3(21, 5.05, 7.8), Vector3(2.0, 0.1, 3.2), CONCRETE, true, 0.0, "concrete")


func _pump_room() -> void:
	# room outside the east wall: x 32..40, z -5..5, height 3.2
	var c := Vector3(36, 0, 0)
	box(c + Vector3(0, -0.15, 0), Vector3(8.3, 0.3, 10.3), CONCRETE, true, 0.0, "concrete")
	box(c + Vector3(0, 3.35, 0), Vector3(8.3, 0.3, 10.3), CONCRETE, true, 0.0, "concrete")
	box(c + Vector3(4.15, 1.6, 0), Vector3(0.3, 3.2, 10.3), CONCRETE.lightened(0.1), true, 0.0, "concrete")
	box(c + Vector3(0, 1.6, -5.15), Vector3(8.3, 3.2, 0.3), CONCRETE.lightened(0.1), true, 0.0, "concrete")
	box(c + Vector3(0, 1.6, 5.15), Vector3(8.3, 3.2, 0.3), CONCRETE.lightened(0.1), true, 0.0, "concrete")
	# pipes
	for i in 3:
		shape_at("cylinder", Vector3(39.4 - i * 0.4, 1.6, 0), Vector3(0.22, 3.2, 0.22), Color(0.3, 0.42, 0.38).darkened(i * 0.1), true, Vector3.ZERO, "metal")
	shape_at("cylinder", Vector3(36, 2.7, -4.6), Vector3(0.25, 8.0, 0.25), Color(0.35, 0.36, 0.38), false, Vector3(0, 0, 90), "metal")
	box(Vector3(38.5, 0.7, 3.5), Vector3(2.0, 1.4, 1.6), Color(0.25, 0.4, 0.35), true, 0.0, "metal")     # pump
	shape_at("cylinder", Vector3(38.5, 1.5, 3.5), Vector3(0.8, 0.3, 0.8), Color(0.25, 0.4, 0.35), false, Vector3(90, 0, 0), "metal")
	# the sump you climb out of
	box(Vector3(38, -0.02, -3), Vector3(1.6, 0.04, 1.6), Color(0.05, 0.1, 0.12), false)
	_water(Rect2(37.3, -3.7, 1.4, 1.4), -0.05)
	# the DRAIN lever, under the window
	box(Vector3(33.0, 0.5, -2), Vector3(0.5, 1.0, 0.8), Color(0.3, 0.32, 0.34), true, 0.0, "metal")
	label(Vector3(33.27, 1.15, -2), 90, "DRAIN", 0.12, Color(0.9, 0.85, 0.2), false)
	_lever_arm = group(Vector3(33.0, 1.0, -2))
	part("cylinder", Vector3(0, 0.22, 0), Vector3(0.04, 0.45, 0.04), Color(0.7, 0.1, 0.08), _lever_arm, Vector3.ZERO, 0.0, "metal")
	part("sphere", Vector3(0, 0.46, 0), Vector3.ONE * 0.09, Color(0.1, 0.1, 0.1), _lever_arm)
	_lever_arm.rotation_degrees.z = 35
	_lever_arm.visible = false
	part("cylinder", Vector3(33.0, 1.02, -2), Vector3(0.07, 0.05, 0.07), Color(0.15, 0.15, 0.16), null, Vector3.ZERO, 0.0, "metal")  # empty socket
	interactable(Vector3(33.0, 1.3, -2), Vector3(0.5, 0.8, 0.8),
		func():
			if not _lever_arm.visible:
				return "Fit the handle" if Game.has_flag("deep_handle") else "DRAIN lever (no handle)"
			return "Pull the DRAIN lever" if not lever_pulled else "The lever",
		func(): _pull_lever())
	omni(Vector3(36, 3.0, 0), Color(1.0, 0.9, 0.7), 0.8, 9.0, true)
	# the door back to the hall (x = 32, z 2.5..3.5): jammed from the hall side
	_pump_door = solid_box(Vector3(32, 1.05, 3), Vector3(0.12, 2.1, 0.98), Color(0.4, 0.42, 0.45), null, "metal")
	interactable(Vector3(32, 1.05, 3), Vector3(0.6, 2.1, 1.0),
		func(): return "Pump room door",
		func():
			if Game.player.global_position.x > 32.0:
				_open_pump_door()
			else:
				Game.hud.show_thought("Jammed. Something is wedged against it from the other side.", 3.5),
		func(): return _pump_door.visible)


func _open_pump_door() -> void:
	_pump_door.visible = false
	_pump_door.get_child(0).disabled = true
	Sfx.play("thud", -10.0, 1.4)
	Game.hud.show_thought("It just... opens, from this side.", 3.0)


func _props() -> void:
	# bleachers along the north wall
	for i in 4:
		box(Vector3(-4, 0.25 + i * 0.5, -12.5 - i * 0.9), Vector3(30, 0.5 + i * 1.0, 0.9), CONCRETE.lightened(0.15), true, 0.0, "concrete")
	# lifeguard chair
	var lg := Vector3(-10, 0, 9.4)
	for x in [-0.4, 0.4]:
		for z in [-0.3, 0.3]:
			shape_at("cylinder", lg + Vector3(x, 0.9, z), Vector3(0.06, 1.8, 0.06), Color(0.92, 0.92, 0.9), true)
	box(lg + Vector3(0, 1.8, 0), Vector3(0.9, 0.08, 0.7), Color(0.92, 0.92, 0.9), true)
	box(lg + Vector3(0, 2.2, 0.32), Vector3(0.9, 0.8, 0.06), Color(0.92, 0.92, 0.9), false)
	box(lg + Vector3(0, 3.0, 0), Vector3(1.2, 0.05, 1.0), Color(0.85, 0.2, 0.15), false)
	# lockers by the west wall
	for i in 12:
		box(Vector3(-31.55, 1.0, -9 + i * 0.6), Vector3(0.55, 2.0, 0.57), Color(0.3, 0.45, 0.55), true, 0.0, "metal")
	# a forgotten towel, a pair of flip-flops
	box(Vector3(-4, 0.02, 10.5), Vector3(1.2, 0.03, 0.6), Color(0.9, 0.85, 0.3), false, 15.0, "fabric")
	box(Vector3(-3.0, 0.02, 10.6), Vector3(0.12, 0.03, 0.28), Color(0.2, 0.5, 0.9), false, 5.0)
	box(Vector3(-2.82, 0.02, 10.55), Vector3(0.12, 0.03, 0.28), Color(0.2, 0.5, 0.9), false, -8.0)


func _lighting() -> void:
	var env := make_env(Color(0.45, 0.6, 0.65), 0.18)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.01, 0.015)
	env.glow_intensity = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.35, 0.4)
	env.fog_density = 0.01
	if Settings.quality >= 1:
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color(0.7, 0.9, 1.0)
	_env_hall = env
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)
	# under the sea: black-blue murk that swallows everything past a few dozen metres
	var sea := make_env(Color(0.05, 0.12, 0.18), 0.12)
	sea.background_mode = Environment.BG_COLOR
	sea.background_color = Color(0.0, 0.015, 0.03)
	sea.fog_enabled = true
	sea.fog_light_color = Color(0.02, 0.085, 0.13)
	sea.fog_density = 0.009
	sea.glow_enabled = true
	sea.glow_intensity = 1.4
	sea.glow_bloom = 0.15
	_env_ocean = sea
	# underwater lights make the pool the brightest thing in the room
	for i in 6:
		var x := MAIN.position.x + 2.0 + i * 4.8
		omni(Vector3(x, -1.2, MAIN.position.y + 0.4), Color(0.3, 0.85, 1.0), 1.2, 7.0, false)
		omni(Vector3(x, -1.2, MAIN.end.y - 0.4), Color(0.3, 0.85, 1.0), 1.2, 7.0, false)
	# a few weak lights high up
	for p in [Vector3(-20, 9, 12), Vector3(0, 9, -12), Vector3(20, 9, 12), Vector3(-20, 9, -12)]:
		omni(p, Color(0.85, 0.95, 1.0), 2.0, 16.0, Settings.quality >= 1)


func _register_anomalies() -> void:
	# the main pool is never quite at the level you left it
	Anomalies.register({"id": "pool_level", "owner": self, "position": Vector3(-8, 0, 0), "radius": 9.0,
		"min_unobserved": 3.0, "discovery_fear": 5.0, "max_distance": 60.0,
		"can_apply": func(): return not _player_in_main(),
		"apply": func(): main_level = [REST, -0.9, -1.4, 0.0].filter(func(l): return absf(l - main_level) > 0.1).pick_random()})
	# a puddle walks across the deck
	var puddle := part("box", Vector3(-24, 0.003, 10), Vector3(1.8, 0.005, 1.2), Color(0.25, 0.4, 0.45), null, Vector3.ZERO, 0.0, 0.05)
	Anomalies.register({"id": "puddle", "owner": self, "radius": 1.5, "discovery_fear": 2.0, "weight": 0.7,
		"get_position": func(): return puddle.global_position,
		"apply": func(): puddle.position = Vector3(randf_range(-28, 28), 0.003, [randf_range(-17, -9), randf_range(9, 17)].pick_random())})


func _player_in_main() -> bool:
	return Game.player != null and _in_rect(MAIN, Game.player.global_position) and Game.player.global_position.y < 0.0


func _characters() -> void:
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen_max_distance = 60.0
	observer.seen.connect(func(): Game.player.dread.add_dread(observer.spot_dread))
	observer.vanished.connect(func(): _obs_cooldown = randf_range(40.0, 80.0))
	# the figure in the water: standing where nobody stands, seen only as a reflection
	reflection = Observer.new()
	reflection.reflected = true
	add_child(reflection)
	reflection.hide_now()
	reflection.seen_threshold = 0.5
	reflection.seen.connect(func(): Game.player.dread.add_dread(reflection.spot_dread))
	reflection.vanished.connect(func(): _refl_cooldown = randf_range(50.0, 100.0))


# ------------------------------------------------------------------ the drain

func _pull_lever() -> void:
	Game.set_flag("deep_saw_lever")
	if not Game.has_flag("deep_handle"):
		Game.hud.show_thought("The handle's been snapped off. There's just a socket. Where would it be...", 4.0)
		return
	if not _lever_arm.visible:
		_lever_arm.visible = true
		Sfx.play("thud", -12.0, 1.6)
		Game.hud.show_thought("It fits.", 2.0)
		return
	if lever_pulled:
		Game.hud.show_thought("It won't move any further.", 2.0)
		return
	lever_pulled = true
	Game.set_flag("deep_lever")
	_lever_arm.rotation_degrees.z = -35
	Sfx.play("thud", -6.0, 0.7)
	Game.hud.show_thought("Somewhere far below, something starts to gurgle.", 3.5)
	Game.hud.show_hint("Watch the deep pool.", 6.0)


func _update_drain(delta: float) -> void:
	if not lever_pulled or drained:
		_gurgle.volume_db = -80.0
		return
	# watching the well's opening (or the water itself, from the edge) counts as watching the water
	var watched := Observation.is_observed(Vector3(18, -0.5, 0), 5.5) or Observation.is_observed(Vector3(18, well_level, 0), 5.0)
	var rate := drain_rate_override if drain_rate_override > 0.0 else DRAIN_RATE
	if watched:
		well_level -= rate * delta
		_gurgle.volume_db = -2.0
	else:
		well_level = minf(REST, well_level + REFILL_RATE * delta)
		_gurgle.volume_db = -14.0
	if well_level <= OCEAN_TOP + 0.6:
		drained = true
		Game.set_flag("deep_drained")
		_well_water.visible = false
		_gurgle.volume_db = -80.0
		Sfx.play("whoosh", -6.0, 0.6)
		Game.hud.show_thought("It's empty. There is no bottom. There's... the sea.", 4.5)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	if not from_save:
		Notebook.reveal_on_next_open("deep_watch")
	lever_pulled = Game.has_flag("deep_lever")
	_lever_arm.visible = lever_pulled
	if Game.has_flag("deep_handle"):
		_handle_pickup.visible = false
	if Game.has_flag("deep_key"):
		_open_locker(true)
	if Game.has_flag("deep_gate"):
		_open_gate(true)
	if Game.has_flag("deep_in_pump"):
		_open_pump_door()
	if lever_pulled:
		_lever_arm.rotation_degrees.z = -35
		_open_pump_door()
	if Game.has_flag("deep_drained"):
		drained = true
		well_level = OCEAN_TOP
		_well_water.visible = false


func _process(delta: float) -> void:
	_t += delta
	_main_water.position.y = lerpf(_main_water.position.y, main_level, clampf(delta * 0.8, 0.0, 1.0))
	_well_water.position.y = well_level
	_update_drain(delta)
	if Game.player == null:
		return
	_update_sea(delta)
	if Game.in_sequence:
		return
	var p: Vector3 = Game.player.global_position

	# the tunnel goes somewhere it shouldn't
	if p.x < MAIN.position.x - 2.8 and p.y < -0.6 and absf(p.z) < 0.7 and not _in_tunnel:
		_in_tunnel = true
		_through_tunnel()

	# drips in the dark
	_drip -= delta
	if _drip <= 0.0:
		_drip = randf_range(1.5, 5.0)
		Sfx.play_at("drip", self, p + Vector3(randf_range(-12, 12), randf_range(3, 8), randf_range(-12, 12)), -8.0, 25.0)

	_hints()
	_update_observers(delta)


func _update_sea(delta: float) -> void:
	var pl: Player = Game.player
	var cam_y := pl.camera.global_position.y
	var in_sea := cam_y < OCEAN_TOP
	if in_sea != _in_ocean:
		_in_ocean = in_sea
		_world_env.environment = _env_ocean if in_sea else _env_hall
		if in_sea:
			Game.hud.show_thought("I can breathe. I shouldn't be able to breathe.", 4.0)
	if not in_sea or Game.in_sequence:
		return
	# looking down into the abyss: DREAD climbs fast
	var down := clampf((-pl._pitch - 0.35) / 0.9, 0.0, 1.0)
	if down > 0.0:
		pl.dread.add_fear(16.0 * down * delta, "looking down")
		pl.dread.add_stability(-5.0 * down * delta)
	# near the sea floor, something takes hold
	if not _grabbed and pl.global_position.y < SEABED + 22.0:
		_grabbed = true
		Game.ankle_grab(false)


func _through_tunnel() -> void:
	var t := Game._seq
	Game.hud.fade_to(1.0, 0.6)
	await get_tree().create_timer(0.7, false).timeout
	if t != Game._seq:
		return
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(36.5, 0.05, -3.0)))
	Sfx.play("whoosh", -8.0, 1.6)
	Game.hud.fade_to(0.0, 1.2)
	Game.hud.show_thought("...I came up somewhere else. This is the other end of the building.", 4.0)
	Game.set_flag("deep_in_pump")
	_in_tunnel = false


func _hints() -> void:
	if not _gate_hint and Game.has_flag("deep_saw_lever") and not Game.has_flag("deep_handle") and _t > 30.0 \
			and Game.player.global_position.distance_to(Vector3(-4, 0, -5)) < 12.0:
		_gate_hint = true
		Game.hud.show_thought("Something red is lying at the bottom of the pool.", 3.5)
	if _hint == 0 and _t > 2.0:
		Game.hud.show_thought("A swimming pool. At night. Who leaves the lights on in the water?", 4.5)
		_hint = 1
	elif _hint == 1 and _t > 9.0:
		Game.hud.show_hint("Find a way out.\nIn water: Space swim up   C dive   (watch your breath)", 9.0)
		_hint = 2
	elif _hint == 2 and not _saw_well and Game.player.global_position.distance_to(Vector3(18, 0, 0)) < 10.0:
		_saw_well = true
		Game.set_flag("deep_saw_gate")
		Game.hud.show_thought("There's no bottom. There has to be a bottom.", 3.5)
	elif _hint == 2 and _t > 120.0 and not lever_pulled:
		Game.hud.show_thought("The pump room door is jammed... there has to be another way in.", 4.0)
		_hint = 3
	elif _hint == 3 and _t > 220.0 and not lever_pulled:
		Game.hud.show_thought("There's a dark square in the wall of the shallow end. Under the water.", 4.0)
		_hint = 4


func _update_observers(delta: float) -> void:
	var d: Dread = Game.player.dread
	_obs_cooldown -= delta
	_refl_cooldown -= delta
	_obs_check += delta
	if _obs_check < 1.0:
		return
	_obs_check = 0.0
	if d.stage == Dread.Stage.CALM:
		return
	# on the deck, the bleachers, the top of the diving tower
	if _obs_cooldown <= 0.0 and not observer.is_present() and randf() < 0.15:
		var spots := [Vector3(-26, 0, -15), Vector3(26, 0, 15), Vector3(21, 5.1, 7.6), Vector3(-4, 2.0, -15.2), Vector3(-28, 0, 12)]
		spots.shuffle()
		for s in spots:
			if s.distance_to(Game.player.global_position) > 12.0 and observer.try_appear_at(s):
				break
	# in the water, upside down, where the reflection of someone standing on the deck would be
	if _refl_cooldown <= 0.0 and not reflection.is_present() and not _player_in_main() and randf() < 0.2:
		var spot := Vector3(randf_range(-18, 2), main_level, randf_range(-5, 5))
		reflection.try_appear_at(spot)
	if reflection.is_present():
		reflection.global_position.y = _main_water.position.y


# ------------------------------------------------------------------ objectives: handle, locker 13, gate

func _objectives() -> void:
	# the DRAIN lever's handle, lying on the bottom of the main pool
	_handle_pickup = group(Vector3(-4, -MAIN_DEPTH + 0.06, -5), 30)
	part("cylinder", Vector3(0, 0, 0), Vector3(0.05, 0.5, 0.05), Color(0.75, 0.1, 0.08), _handle_pickup, Vector3(0, 0, 90), 0.4, "metal")
	part("sphere", Vector3(0.26, 0, 0), Vector3.ONE * 0.1, Color(0.1, 0.1, 0.1), _handle_pickup)
	var glint := OmniLight3D.new()
	glint.light_color = Color(1.0, 0.4, 0.3)
	glint.light_energy = 0.6
	glint.omni_range = 1.6
	glint.position = Vector3(0, 0.3, 0)
	_handle_pickup.add_child(glint)
	var take := interactable(Vector3(-4, -MAIN_DEPTH + 0.3, -5), Vector3(1.0, 0.8, 1.0),
		func(): return "Take the lever handle",
		func():
			_handle_pickup.visible = false
			Game.set_flag("deep_handle")
			Sfx.play("thud", -14.0, 1.8)
			Game.hud.show_thought("A lever handle. Snapped clean off. Like someone wanted it down here.", 4.0),
		func(): return _handle_pickup.visible)
	take.name = "HandlePickup"

	# locker 13 (there were twelve)
	var lz := -9.0 + 12 * 0.6
	box(Vector3(-31.7, 1.0, lz), Vector3(0.25, 2.0, 0.57), Color(0.22, 0.32, 0.38), true, 0.0, "metal")
	_locker_door = group(Vector3(-31.42, 0.02, lz + 0.28))
	part("box", Vector3(0, 0.98, -0.28), Vector3(0.03, 1.96, 0.55), Color(0.25, 0.37, 0.45), _locker_door, Vector3.ZERO, 0.0, "metal")
	for k in 4:
		part("box", Vector3(0.02, 1.6 + k * 0.05, -0.28), Vector3(0.01, 0.015, 0.35), Color(0.1, 0.12, 0.13), _locker_door)
	label(Vector3(-31.39, 1.45, lz), 90, "13", 0.12, Color(0.85, 0.85, 0.8), false)
	# what's inside: wet black hair hanging from the hook, and the key
	for k in 9:
		part("box", Vector3(-31.65 + randf_range(-0.06, 0.06), 1.35, lz + randf_range(-0.18, 0.18)), Vector3(0.012, randf_range(0.6, 1.1), 0.012),
			Color(0.02, 0.02, 0.02), null, Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 0.0, 0.2)
	var key := part("box", Vector3(-31.6, 1.05, lz), Vector3(0.02, 0.09, 0.03), Color(0.85, 0.7, 0.3), null, Vector3.ZERO, 0.3, "metal")
	key.name = "GateKey"
	interactable(Vector3(-31.3, 1.0, -5.7), Vector3(0.4, 2.0, 6.6), func(): return "Lockers",
		func(): Game.hud.show_thought("Locked. All of them. I counted twelve.", 3.0))
	interactable(Vector3(-31.3, 1.0, lz), Vector3(0.4, 2.0, 0.55),
		func(): return "Locker 13" if not Game.has_flag("deep_key") else "",
		func():
			_open_locker(false)
			Game.set_flag("deep_key")
			Sfx.play("thud", -2.0, 0.9)
			Game.player.dread.add_fear(10.0, "locker 13")
			Game.player.jolt(Vector3(-3, 2, 0))
			Game.hud.show_thought("Hair. Wet hair. ...And a key. Don't touch the hair. Just take the key.", 4.5),
		func(): return not Game.has_flag("deep_key"))
	# note in the pump room
	label(Vector3(39.83, 1.9, -1.0), -90, "WELL GATE KEY\nmoved to locker 13", 0.09, Color(0.15, 0.15, 0.17), false)

	# the fence around the diving well, padlocked
	var fence := StaticBody3D.new()
	fence.collision_layer = 4   # solid to you, transparent to watching
	add_child(fence)
	var steel := Color(0.62, 0.64, 0.66)
	var sides := [
		[Vector3(18, 0, -7.6), Vector3(13.4, 0, 0)], [Vector3(18, 0, 7.6), Vector3(13.4, 0, 0)],
		[Vector3(24.6, 0, 0), Vector3(0, 0, 15.2)],
		[Vector3(11.5, 0, -4.15), Vector3(0, 0, 6.9)], [Vector3(11.5, 0, 4.15), Vector3(0, 0, 6.9)],
	]
	for sd in sides:
		var c: Vector3 = sd[0]
		var ext: Vector3 = sd[1]
		var length := ext.length()
		var along := ext.normalized()
		var sz := Vector3(maxf(absf(ext.x), 0.05), 1.3, maxf(absf(ext.z), 0.05))
		box(c + Vector3(0, 1.3, 0), sz + Vector3(0, -1.26, 0), steel, false, 0.0, "metal")
		box(c + Vector3(0, 0.65, 0), sz + Vector3(0, -1.27, 0), steel, false, 0.0, "metal")
		var n := int(length / 0.18)
		for k in n + 1:
			box(c + along * (-length * 0.5 + k * length / n) + Vector3(0, 0.65, 0), Vector3(0.025, 1.3, 0.025), steel, false, 0.0, "metal")
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(maxf(absf(ext.x), 0.1), 2.4, maxf(absf(ext.z), 0.1))
		cs.shape = b
		cs.position = c + Vector3(0, 1.2, 0)
		fence.add_child(cs)
	# the gate
	_gate = StaticBody3D.new()
	_gate.collision_layer = 4
	_gate.position = GATE_POS + Vector3(0, 0, -0.7)   # hinge
	add_child(_gate)
	var gcs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(0.1, 2.4, 1.4)
	gcs.shape = gb
	gcs.position = Vector3(0, 1.2, 0.7)
	_gate.add_child(gcs)
	part("box", Vector3(0, 1.3, 0.7), Vector3(0.04, 0.04, 1.4), steel, _gate, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(0, 0.1, 0.7), Vector3(0.04, 0.04, 1.4), steel, _gate, Vector3.ZERO, 0.0, "metal")
	for k in 8:
		part("box", Vector3(0, 0.7, 0.05 + k * 0.185), Vector3(0.025, 1.25, 0.025), steel, _gate, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(-0.06, 0.9, 1.3), Vector3(0.05, 0.08, 0.06), Color(0.75, 0.6, 0.25), _gate, Vector3.ZERO, 0.0, "metal")   # padlock
	part("box", Vector3(-0.08, 0.95, 1.2), Vector3(0.02, 0.2, 0.12), Color(0.85, 0.82, 0.7), _gate, Vector3(0, 0, 10), 0.0, 0.8)   # tag
	interactable(GATE_POS + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 1.4),
		func(): return "Unlock the gate" if Game.has_flag("deep_key") else "Gate",
		func():
			Game.set_flag("deep_saw_gate")
			if Game.has_flag("deep_key"):
				_open_gate(false)
				Game.set_flag("deep_gate")
			else:
				Game.hud.show_thought("Padlocked. There's a tag on the chain: \"SPARE KEY - LOCKER 13\".", 4.0),
		func(): return not Game.has_flag("deep_gate"))


func _open_locker(instant: bool) -> void:
	var key := get_node_or_null("GateKey")
	if key:
		key.visible = false
	if instant:
		_locker_door.rotation_degrees.y = -100
	else:
		create_tween().tween_property(_locker_door, "rotation_degrees:y", -100.0, 0.25).set_trans(Tween.TRANS_BACK)


func _open_gate(instant: bool) -> void:
	_gate.get_child(0).disabled = true
	if instant:
		_gate.rotation_degrees.y = 100
	else:
		Sfx.play("thud", -8.0, 1.5)
		create_tween().tween_property(_gate, "rotation_degrees:y", 100.0, 1.2).set_trans(Tween.TRANS_SINE)
		Game.hud.show_thought("Open. Now there's nothing between me and it.", 3.0)


## Optional creatures (only if their model files are in models/sea/). A fish in a swimming pool, and
## far below, in the sea, shapes too big to be fish: dark, slow, never close.
func _sea_life() -> void:
	var fish := Critter.create(["sea/fish1"], 0.35)
	if fish:
		add_child(fish)
		fish.orbit(Vector3(-9, -1.5, 1), 3.5, 0.7, 0.25)
	for i in 2:
		var whale := Critter.create(["sea/whale"], 28.0, true)
		if whale:
			add_child(whale)
			whale.orbit(OCEAN_CENTER + Vector3(0, -95.0 - i * 30.0, 0), 75.0 + i * 25.0, 4.5 * (1 if i == 0 else -1), 4.0)
	for i in 3:
		var shark := Critter.create(["sea/shark"], 4.0, true)
		if shark:
			add_child(shark)
			shark.orbit(OCEAN_CENTER + Vector3(0, -50.0 - i * 14.0, 0), 22.0 + i * 9.0, 4.0 + i, 2.0)
	var manta := Critter.create(["sea/manta"], 6.0, true)
	if manta:
		add_child(manta)
		manta.orbit(OCEAN_CENTER + Vector3(0, -75, 0), 38.0, -3.0, 5.0)
