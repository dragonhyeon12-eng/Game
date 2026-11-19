class_name PatternZone
extends Zone
## PATTERN - trypophobia. Down the subway stairs: a platform tiled in hexagons, and beyond it the hive -
## a six-sided room with six identical doorways, every frame crusted with clusters of small holes.
##
##  1 The platform   a map of hexagons: YOU ARE HERE at the edge, the way out in the middle.
##  2 The hive       one doorway has no holes. That's the way on - and it moves whenever you take your eyes off
##                   it. Every other doorway brings you back into the same room, and the holes spread a little
##                   further: over the walls, the floor, toward you. Four rooms deep is the middle.
##  3 The core       a round door of three rings. Line them up.
##                   Behind it, a porthole door with a hospital sign: WARD 6.

const C := Vector3(0, 0, -30)          # the hive room's centre
const APO := 6.0                       # centre to each wall
const DOOR_W := 1.5
const HEX_H := 3.2
const CORR := 4.6                      # corridor length beyond each doorway
const CORE := Vector3(0, 0, -66)
const BONE := Color(0.86, 0.82, 0.72)
const HOLE := Color(0.06, 0.04, 0.035)
const WAY_IN := 3                      # the doorway from the platform (south)

var observer: Observer
var _frames: Array[Node3D] = []        # the hole clusters round each doorway
var _true_door := 0
var _entry := WAY_IN
var _depth := 0
var _swarm := 0
var _swarm_layers: Array[Node3D] = []
var _depth_layers: Array[Node3D] = []
var _in_hive := false
var _back_plug: StaticBody3D
var _core_plug: StaticBody3D
var _unseen := 0.0
var _moves := 0
var _stall_t := 0.0
var _room_lights: Array[OmniLight3D] = []
var _rings: Array[Node3D] = []
var _ring_pos := [2, 4, 1]
var _vault: Node3D
var _open := false
var _t := 0.0
var _hint := 0
var no_swarm_death := false
static var _hole_mesh: CylinderMesh
var _armed := true            # (after coming back in through a doorway: not until you're in the room again)


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
	return C + door_dir(i) * APO


# ------------------------------------------------------------------ build

func build() -> void:
	_platform()
	_hive()
	_core()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen.connect(func():
		Game.set_flag("observer_pattern")
		Game.player.dread.add_dread(observer.spot_dread))
	var env := make_env(Color(0.85, 0.82, 0.72), 0.1)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.11, 0.09)
	env.fog_density = 0.03
	environment(env)
	ambient("hum", C + Vector3(0, 2.5, 0), true, -12.0, 20.0)
	ambient("drone", Vector3.ZERO, false, -24.0)


## A cluster of holes on a surface: discs scattered round `center` in the plane of `normal`.
func _cluster(parent: Node3D, center: Vector3, normal: Vector3, radius: float, count: int, hole_r := Vector2(0.025, 0.07)) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if _hole_mesh == null:
		_hole_mesh = CylinderMesh.new()       # cheap: 8 sides, no rings (there are thousands of these)
		_hole_mesh.radial_segments = 8
		_hole_mesh.rings = 0
		_hole_mesh.top_radius = 0.5
		_hole_mesh.bottom_radius = 0.5
		_hole_mesh.height = 1.0
	mm.mesh = _hole_mesh
	mm.instance_count = count
	var up := normal.normalized()
	var t1 := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := up.cross(t1)
	var basis_n := Basis(t1, up, t2)
	for k in count:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var hr := randf_range(hole_r.x, hole_r.y)
		var at := center + (t1 * cos(a) + t2 * sin(a)) * r + up * 0.004
		mm.set_instance_transform(k, Transform3D(basis_n.scaled(Vector3(hr * 2.0, 0.01, hr * 2.0)), at))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Shapes.material(HOLE, 0.9)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _hex_tiles(center: Vector3, size: Vector2, normal_up := true) -> void:
	# the floor pattern: small hexagonal tiles (six-sided prisms) - flat, regular, too many of them
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.radial_segments = 6
	cm.rings = 1
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 1.0
	mm.mesh = cm
	var s := 0.36
	var cols := int(size.x / (s * 1.5))
	var rows := int(size.y / (s * 1.732))
	mm.instance_count = cols * rows
	var k := 0
	for i in cols:
		for j in rows:
			var x := center.x - size.x * 0.5 + i * s * 1.5
			var z := center.z - size.y * 0.5 + j * s * 1.732 + (s * 0.866 if i % 2 == 1 else 0.0)
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, deg_to_rad(30.0)).scaled(Vector3(s * 1.84, 0.004, s * 1.84)), Vector3(x, center.y + 0.003, z)))
			k += 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Shapes.material(BONE.darkened(0.08), 0.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _platform() -> void:
	# x -4..4, z 0..-19.5, the tracks on the east behind a barrier
	box(Vector3(0, -0.1, -9.2), Vector3(18.4, 0.2, 20.4), BONE.darkened(0.3), true, 0.0, "tiles_floor")
	box(Vector3(0, HEX_H + 0.6, -9.2), Vector3(18.4, 0.2, 20.4), BONE.darkened(0.2), true, 0.0, "tiles_pool")
	box(Vector3(-4.1, 1.9, -10), Vector3(0.2, 3.8, 21), BONE, true, 0.0, "tiles_pool")
	box(Vector3(0, 1.9, 0.6), Vector3(14, 3.8, 0.2), BONE, true, 0.0, "tiles_pool")
	_hex_tiles(Vector3(0, 0, -10), Vector2(8, 19))
	# the track: a drop behind a glass barrier, and a train standing there with its doors shut
	box(Vector3(4.2, 0.55, -10), Vector3(0.1, 1.1, 20), Color(0.6, 0.7, 0.72), true, 0.0, "glass")
	box(Vector3(6.5, -0.6, -10), Vector3(4.4, 0.2, 22), Color(0.12, 0.1, 0.09), false)
	box(Vector3(7.2, 1.5, -10), Vector3(2.8, 3.0, 20), Color(0.75, 0.75, 0.72), true, 0.0, "metal")
	for k in 6:
		part("box", Vector3(5.79, 1.5, -1.5 - k * 3.3), Vector3(0.02, 0.8, 1.4), Color(0.05, 0.05, 0.06), null, Vector3.ZERO, 0.0, 0.1)
	box(Vector3(9.0, 1.9, -10), Vector3(0.2, 3.8, 22), BONE.darkened(0.2), true, 0.0, "tiles_pool")
	# the stairs you came down: gone (just more wall, where they were)
	part("box", Vector3(0, 1.6, 0.48), Vector3(3.2, 3.2, 0.04), BONE.darkened(0.05), null, Vector3.ZERO, 0.0, "tiles_pool")
	# the map
	var mp := Vector3(-3.95, 1.6, -6.0)
	box(mp, Vector3(0.1, 1.4, 2.0), Color(0.15, 0.15, 0.17), false, 0.0, "metal")
	label(mp + Vector3(0.07, 0.55, 0), 90, "NETWORK MAP", 0.06, Color(0.95, 0.95, 0.9), true)
	for k in 7:
		var off := Vector3.ZERO if k == 0 else Vector3(0, cos(deg_to_rad(k * 60.0)) * 0.36, sin(deg_to_rad(k * 60.0)) * 0.36)
		part("cylinder", mp + Vector3(0.06, -0.05, 0) + off, Vector3(0.3, 0.02, 0.3), Color(0.9, 0.85, 0.3) if k == 0 else Color(0.5, 0.5, 0.55), null, Vector3(0, 0, 90), 1.0)
	label(mp + Vector3(0.08, -0.5, 0.1), 90, "YOU ARE HERE (edge)  .  WAY OUT (middle)", 0.035, Color(0.9, 0.9, 0.85), true)
	interactable(mp + Vector3(0.3, 0, 0), Vector3(0.5, 1.4, 2.0), func(): return "Read the map",
		func():
			Game.set_flag("pt_map")
			Game.hud.show_thought("Hexagons inside hexagons. 'You are here' - the edge. 'Way out' - the middle. ...Every line on it is a hexagon.", 4.5))
	for z in [-3.0, -9.0, -15.0]:
		part("box", Vector3(0, HEX_H + 0.45, z), Vector3(2.5, 0.05, 0.4), Color(0.95, 1.0, 0.95), null, Vector3.ZERO, 2.5)
		omni(Vector3(0, HEX_H, z), Color(0.95, 1.0, 0.92), 0.9, 9.0, false)
	label(Vector3(0, 2.9, -19.0), 0, "WAY OUT  ->", 0.12, Color(0.9, 0.85, 0.3), true)
	# clusters already starting, in the corners
	var g := Node3D.new()
	add_child(g)
	_cluster(g, Vector3(-3.99, 2.6, -2.0), Vector3(1, 0, 0), 0.5, 120)
	_cluster(g, Vector3(-3.99, 0.4, -13.0), Vector3(1, 0, 0), 0.35, 70)
	_cluster(g, Vector3(2.0, HEX_H + 0.49, -11.0), Vector3(0, -1, 0), 0.6, 140)
	box(Vector3(-2.5, HEX_H * 0.5 + 0.3, -19.7), Vector3(3.0, HEX_H + 0.6, 0.4), BONE, true, 0.0, "tiles_pool")
	box(Vector3(2.5, HEX_H * 0.5 + 0.3, -19.7), Vector3(3.0, HEX_H + 0.6, 0.4), BONE, true, 0.0, "tiles_pool")
	box(Vector3(6.5, HEX_H * 0.5 + 0.3, -19.9), Vector3(5.0, HEX_H + 0.6, 0.2), BONE, true, 0.0, "tiles_pool")
	trigger(Vector3(0, 1.2, -4), Vector3(8, 2.4, 2), func():
		Game.hud.show_thought("A station. Tiles, all little hexagons. And in the corners... I don't like the corners.", 4.0))


func _hive() -> void:
	# the room: six walls, a doorway in each, a corridor behind each doorway
	var side := 2.0 * APO * tan(deg_to_rad(30.0))
	var seg := (side - DOOR_W) * 0.5
	box(C + Vector3(0, -0.1, 0), Vector3(21, 0.2, 21), BONE.darkened(0.3), true, 0.0, "tiles_floor")
	box(C + Vector3(0, HEX_H + 0.1, 0), Vector3(21, 0.2, 21), BONE.darkened(0.15), true, 0.0, "tiles_pool")
	_hex_tiles(C, Vector2(13, 13))
	for i in 6:
		var dir := door_dir(i)
		var tang := dir.cross(Vector3.UP)
		var yaw := rad_to_deg(atan2(dir.x, dir.z))
		var wc := C + dir * APO
		for s in [-1.0, 1.0]:
			box(wc + tang * s * (DOOR_W * 0.5 + seg * 0.5) + Vector3(0, HEX_H * 0.5, 0), Vector3(seg + 0.02, HEX_H, 0.3), BONE, true, yaw, "tiles_pool")
		box(wc + Vector3(0, HEX_H - 0.35, 0), Vector3(DOOR_W, 0.7, 0.3), BONE, true, yaw, "tiles_pool")
		# the corridor
		for s in [-1.0, 1.0]:
			box(wc + dir * (CORR * 0.5 + 0.15) + tang * s * (DOOR_W * 0.5 + 0.15) + Vector3(0, HEX_H * 0.5, 0), Vector3(0.3, HEX_H, CORR), BONE.darkened(0.05), true, yaw, "tiles_pool")
		if i != 0 and i != WAY_IN:
			box(wc + dir * (CORR + 0.3) + Vector3(0, HEX_H * 0.5, 0), Vector3(DOOR_W + 0.6, HEX_H, 0.3), BONE.darkened(0.05), true, yaw, "tiles_pool")
		# the frame of holes round the doorway (both faces: the room side, and the corridor side)
		var fr := Node3D.new()
		add_child(fr)
		for s in [-1.0, 1.0]:
			_cluster(fr, wc - dir * 0.16 + tang * s * (DOOR_W * 0.5 + 0.45) + Vector3(0, 1.0, 0), -dir, 0.5, 200, Vector2(0.03, 0.09))
			_cluster(fr, wc - dir * 0.16 + tang * s * (DOOR_W * 0.5 + 0.4) + Vector3(0, 2.1, 0), -dir, 0.45, 160, Vector2(0.03, 0.09))
		_cluster(fr, wc - dir * 0.16 + Vector3(0, HEX_H - 0.35, 0), -dir, 0.55, 200, Vector2(0.03, 0.09))
		_frames.append(fr)
		var lamp := part("box", wc - dir * 1.0 + Vector3(0, HEX_H - 0.02, 0), Vector3(0.8, 0.04, 0.3), Color(0.95, 1.0, 0.9), null, Vector3(0, yaw, 0), 2.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 2:
		var l := omni(C + Vector3(0, HEX_H - 0.4, 0) + Vector3(k * 2.0 - 1.0, 0, 0), Color(0.95, 1.0, 0.9), 1.2, 11.0, false)
		_room_lights.append(l)
	# the way back (closes once you're in) and the way on (opens four rooms deep)
	_back_plug = solid_box(door_point(WAY_IN) + door_dir(WAY_IN) * (CORR + 0.3) + Vector3(0, HEX_H * 0.5, 0), Vector3(DOOR_W + 0.6, HEX_H, 0.3), BONE.darkened(0.05), null, "tiles_pool")
	_set_body(_back_plug, false)
	_core_plug = solid_box(door_point(0) + door_dir(0) * (CORR + 0.3) + Vector3(0, HEX_H * 0.5, 0), Vector3(DOOR_W + 0.6, HEX_H, 0.3), BONE.darkened(0.05), null, "tiles_pool")
	# the holes that come with each wrong turn, and with each room deeper (a layer each)
	for lvl in 4:
		var g := Node3D.new()
		add_child(g)
		g.visible = false
		for k in 10 + lvl * 6:
			var i := randi() % 6
			var dir := door_dir(i)
			var tang := dir.cross(Vector3.UP)
			var along := randf_range(-2.5, 2.5)
			if absf(along) < DOOR_W * 0.6:
				along += signf(along + 0.01) * DOOR_W
			_cluster(g, C + dir * (APO - 0.16) + tang * along + Vector3(0, randf_range(0.3, 2.8), 0), -dir, randf_range(0.25, 0.6), 60 + lvl * 25)
		for k in 3 + lvl * 2:
			_cluster(g, C + Vector3(randf_range(-4, 4), 0.0, randf_range(-4, 4)), Vector3.UP, randf_range(0.3, 0.8), 80 + lvl * 30)
			_cluster(g, C + Vector3(randf_range(-4, 4), HEX_H - 0.01, randf_range(-4, 4)), Vector3.DOWN, randf_range(0.3, 0.8), 80)
		_swarm_layers.append(g)
	for lvl in 4:
		var g := Node3D.new()
		add_child(g)
		g.visible = false
		for k in 8:
			var i := k % 6
			var dir := door_dir(i)
			var tang := dir.cross(Vector3.UP)
			_cluster(g, C + dir * (APO - 0.16) + tang * randf_range(1.6, 2.6) * (1.0 if k % 2 == 0 else -1.0) + Vector3(0, randf_range(0.5, 2.5), 0), -dir, 0.35, 70)
		_depth_layers.append(g)
	_show_true_door()


static func _set_body(b: StaticBody3D, on: bool) -> void:
	b.visible = on
	for ch in b.get_children():
		if ch is CollisionShape3D:
			ch.disabled = not on


func _show_true_door() -> void:
	for i in 6:
		_frames[i].visible = i != _true_door


func _core() -> void:
	# a long corridor north from door 0 to a round chamber, every surface crusted with holes
	var d0 := door_point(0) + door_dir(0) * (CORR + 0.45)
	var end_z := CORE.z + 8.0
	var mid_z := (d0.z + end_z) * 0.5
	var ln := d0.z - end_z
	for s in [-1.0, 1.0]:
		box(Vector3(s * (DOOR_W * 0.5 + 0.15), HEX_H * 0.5, mid_z), Vector3(0.3, HEX_H, ln), BONE.darkened(0.1), true, 0.0, "tiles_pool")
	box(Vector3(0, -0.1, (C.z - 10.5 + end_z - 1.0) * 0.5), Vector3(4, 0.2, (C.z - 10.5) - (end_z - 1.0)), BONE.darkened(0.35), true, 0.0, "tiles_floor")
	box(Vector3(0, HEX_H + 0.1, mid_z), Vector3(4, 0.2, ln), BONE.darkened(0.15), true, 0.0, "tiles_pool")
	# the chamber: 8 m across, 6 high
	var R := 8.0
	box(CORE + Vector3(0, -0.1, 0), Vector3(2 * R + 2, 0.2, 2 * R + 2), BONE.darkened(0.35), true, 0.0, "tiles_floor")
	box(CORE + Vector3(0, 6.1, 0), Vector3(2 * R + 2, 0.2, 2 * R + 2), BONE.darkened(0.3), true, 0.0, "tiles_pool")
	for i in 6:
		var dir := door_dir(i)
		var yaw := rad_to_deg(atan2(dir.x, dir.z))
		var wc := CORE + dir * R
		if i == WAY_IN:
			var side := 2.0 * R * tan(deg_to_rad(30.0))
			var seg := (side - DOOR_W) * 0.5
			var tang := dir.cross(Vector3.UP)
			for s in [-1.0, 1.0]:
				box(wc + tang * s * (DOOR_W * 0.5 + seg * 0.5) + Vector3(0, 3.0, 0), Vector3(seg, 6.0, 0.3), BONE, true, yaw, "tiles_pool")
			box(wc + Vector3(0, 4.6, 0), Vector3(DOOR_W, 2.8, 0.3), BONE, true, yaw, "tiles_pool")
		else:
			box(wc + Vector3(0, 3.0, 0), Vector3(2.0 * R * tan(deg_to_rad(30.0)) + 0.3, 6.0, 0.3), BONE, true, yaw, "tiles_pool")
	var crust := Node3D.new()
	add_child(crust)
	for k in 46:
		var i := randi() % 6
		if i == 0 and k % 3 != 0:
			continue
		var dir := door_dir(i)
		var tang := dir.cross(Vector3.UP)
		_cluster(crust, CORE + dir * (R - 0.16) + tang * randf_range(-4, 4) + Vector3(0, randf_range(0.3, 5.6), 0), -dir, randf_range(0.4, 0.9), 130)
	for k in 10:
		_cluster(crust, CORE + Vector3(randf_range(-6, 6), 5.99, randf_range(-6, 6)), Vector3.DOWN, randf_range(0.6, 1.2), 160)
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
		disc.material_override = Shapes.material(BONE.darkened(0.1 + k * 0.1), 0.5)
		ring.add_child(disc)
		var notch := MeshInstance3D.new()
		notch.mesh = Shapes.mesh("box")
		notch.scale = Vector3(0.22, 0.22, 0.05)
		notch.position = Vector3(0, radii[k] - 0.25, 0.1 + k * 0.03)
		notch.material_override = Shapes.material(Color(0.95, 0.8, 0.3), 0.4, 1.5)
		ring.add_child(notch)
		_cluster(ring, Vector3(0, 0, 0.07 + k * 0.03), Vector3(0, 0, 1), radii[k] - 0.1, 220 - k * 50)
		ring.rotation_degrees.z = _ring_pos[k] * 60.0
		_rings.append(ring)
	# behind it, a porthole door
	var ph := CORE + door_dir(0) * (R - 0.12) + Vector3(0, 1.1, 0)
	part("box", ph, Vector3(1.1, 2.2, 0.05), Color(0.85, 0.88, 0.9), null, Vector3.ZERO, 0.0, "metal")
	part("cylinder", ph + Vector3(0, 0.45, 0.04), Vector3(0.4, 0.02, 0.4), Color(0.9, 0.95, 1.0), null, Vector3(90, 0, 0), 1.8)
	label(ph + Vector3(0, 1.25, 0.04), 0, "WARD 6", 0.1, Color(0.2, 0.3, 0.5), false)
	# the levers on a pedestal in the middle of the room
	var ped := CORE + Vector3(0, 0, -2.5)
	box(ped + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.6), BONE.darkened(0.2), true, 0.0, "tiles_pool")
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
		Game.hud.show_thought("The middle. It's all holes in here. ...Three rings on the far wall, and a notch in each.", 4.0))


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


# ------------------------------------------------------------------ the hive, running

func _corridor_of(p: Vector3) -> int:
	var rel := p - C
	rel.y = 0.0
	for i in 6:
		var dir := door_dir(i)
		var along := rel.dot(dir)
		var lat := absf(rel.dot(dir.cross(Vector3.UP)))
		if along > APO + 0.4 and lat < DOOR_W * 0.5 + 0.2:
			return i
	return -1


func _update_hive(delta: float, p: Vector3) -> void:
	var rel := p - C
	rel.y = 0.0
	if not _in_hive:
		if rel.length() < APO - 1.0:
			_in_hive = true
			Sfx.play("dark_soundscape", -2.0)
			Game.set_flag("pt_hive")
			_set_body(_back_plug, true)
			_entry = WAY_IN
			Game.hud.show_thought("Six doors. Every one the same - crusted round with holes. ...No. One of them's clean.", 4.5)
		return
	if rel.length() < APO - 0.5:
		_armed = true
	var i := _corridor_of(p)
	if _armed and i >= 0 and rel.dot(door_dir(i)) > APO + 2.4 and not (i == 0 and _depth >= 4):
		_pass_through(i)
		return
	if _depth >= 4:
		return
	# the clean doorway: watched, it stays; unwatched, it goes somewhere else
	var dp := door_point(_true_door) + Vector3(0, 1.4, 0)
	if Observation.is_observed(dp, 0.7) or p.distance_to(dp) < 2.0:
		_unseen = 0.0
	else:
		_unseen += delta
		if _unseen > 1.2:
			_unseen = 0.0
			var options := []
			for k in 6:
				if k != _true_door and k != _entry and not Observation.in_view(door_point(k) + Vector3(0, 1.4, 0), 0.7):
					options.append(k)
			if not options.is_empty():
				_true_door = options.pick_random()
				_show_true_door()
				_moves += 1
				if _moves == 1:
					Game.hud.show_thought("It moved. The clean one - it's a different door now.", 3.0)
				elif _moves == 3:
					Game.hud.show_hint("The doorway without holes is the way on.\nIt moves when you look away from it.", 7.0)
	# time in here feeds the holes too
	_stall_t += delta
	if _stall_t > 35.0:
		_stall_t = 0.0
		_grow_swarm()


## Through doorway i: you come back in through the opposite one, into "another" room.
func _pass_through(i: int) -> void:
	var pl: Player = Game.player
	var rel := pl.global_position - C
	pl.global_position = C - Vector3(rel.x, -rel.y, rel.z)
	pl.rotation.y += PI
	pl.velocity = -Vector3(pl.velocity.x, -pl.velocity.y, pl.velocity.z)
	_entry = (i + 3) % 6
	_stall_t = 0.0
	_armed = false
	if i == _true_door:
		_depth += 1
		Game.counters["hive"] = _depth
		_swarm = maxi(0, _swarm - 1)
		_refresh_swarm()
		for k in _depth_layers.size():
			_depth_layers[k].visible = k < _depth
		for l in _room_lights:
			l.light_color = Color(0.95, 1.0, 0.9).lerp(Color(0.95, 0.85, 0.55), _depth / 4.0)
			l.light_energy = 1.2 - _depth * 0.15
		Sfx.play("whoosh", -8.0, 0.7)
		Sfx.play("dark_soundscape", -4.0)
		if _depth >= 4:
			_true_door = 0
			_set_body(_core_plug, false)
			Game.set_flag("pt_deep")
			Game.hud.show_thought("This one's different. The clean door... there's a corridor behind it. A long one.", 4.0)
		else:
			_true_door = _random_door()
			Game.hud.show_thought(["Another room. The same room. ...Deeper, though. I can feel it's deeper.", "Deeper.", "Nearly. Nearly in the middle."][_depth - 1], 3.0)
	else:
		_true_door = _random_door()
		_grow_swarm()
	_show_true_door()


func _random_door() -> int:
	var options := []
	for k in 6:
		if k != _entry and k != (_entry + 3) % 6:
			options.append(k)
	return options.pick_random()


func _grow_swarm() -> void:
	_swarm += 1
	Sfx.play("static_burst", -6.0, 0.5)
	Sfx.play("drip", 0.0, 0.5)
	Game.player.dread.add_fear(10.0, "holes")
	_refresh_swarm()
	match _swarm:
		1: Game.hud.show_thought("The same room - but there are more of them. More holes. Closer.", 3.5)
		2: Game.hud.show_thought("They're spreading. On the floor now. Don't look at them. DON'T LOOK.", 3.5)
		3: Game.hud.show_thought("They're all over it. One more wrong door and - I can't. I can't.", 3.5)
	if _swarm >= 4 and not no_swarm_death:
		Game.entity_death("pattern")


func _refresh_swarm() -> void:
	for k in _swarm_layers.size():
		_swarm_layers[k].visible = k < _swarm


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	Game.counters["hive"] = 0


func _process(delta: float) -> void:
	_t += delta
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_update_hive(delta, p)
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("The stairs - they're gone. Just tiles where they were. ...The way out's in the middle, the signs say.", 4.5)
