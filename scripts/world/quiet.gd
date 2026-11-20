class_name QuietZone
extends Zone
## THE QUIET - thanatophobia. A hospital at night, one long floor of it, and a garden. Nothing here is loud.
## The clocks disagree. The records are for people who never existed. Someone has been visiting Ward 6 every
## night at 3:12, in your handwriting. The water from THE DEEP has got into the corridor.
##
##  1 Waiting       take a number (13; they're serving 12, and always will be). The visitors' book.
##  2 Records       files for Mina, Mr. Halvorsen, Theo, a man who fell. The file for Ward 6: the key is at the
##                  nurses' station.
##  3 The corridor  flooded, ankle-deep, pool-tiled under the water. Visitors under sheets in the doorways - and
##                  once you have the key, they come closer while you look away.
##  4 Ward 6        your room. Your desk, your computer, the towel over the mirror. A hospital bed, empty, warm.
##                  The chart at its foot.
##  5 The garden    a memorial garden under the stars. Plaques. Theo's kite in the tree. Mr. Halvorsen on a bench,
##                  feeding the pigeons. The gate at the far end goes somewhere none of them have been.

const CORR_X := 1.5
const CORR_Z0 := -12.0
const CORR_Z1 := -50.0
const WARD6 := Vector3(0, 0, -54.0)
const GARDEN := Vector3(18.0, 0, -46.0)
const GATE := Vector3(30.0, 0, -46.0)
const FLOOD := Vector2(-29.0, -43.0)       # z range
const WALL := Color(0.78, 0.82, 0.8)
const FLOOR := Color(0.62, 0.66, 0.64)
const H := 3.0

var observer: Observer
var _clocks: Array = []                  # [hour hand, minute hand]
var _figures: Array[Node3D] = []
var _figures_awake := false
var _ward_door: Node3D
var _ward_block: StaticBody3D
var _garden_door: Node3D
var _garden_block: StaticBody3D
var _gate: Node3D
var _gate_block: StaticBody3D
var _key: Node3D
var _monitor_t := 0.0
var _monitor_flat := false
var _halvorsen: NPC
var _lights: Array = []
var _t := 0.0
var _hint := 0
var _fig_hint := 0
var no_figures := false


func zone_id() -> String: return "quiet"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 8.0
func fear_decay() -> float: return 1.8
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.4
func sprint_speed() -> float: return 4.0


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, -1.5))


# ------------------------------------------------------------------ build

func build() -> void:
	_waiting_room()
	_corridor()
	_records()
	_nurses()
	_ward6()
	_garden()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen.connect(func():
		Game.set_flag("observer_quiet")
		Game.player.dread.add_dread(observer.spot_dread))
	var env := make_env(Color(0.6, 0.68, 0.7), 0.08)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.025)
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.08)
	env.fog_density = 0.02
	environment(env)
	ambient("hum", Vector3(0, 2.5, -8), true, -16.0, 14.0)
	ambient("room_tone", Vector3.ZERO, false, -14.0)
	ambient("water_lap", Vector3(0, 0.3, -36), true, -10.0, 14.0)
	ambient("drip", Vector3(0, 2.5, -36), true, -14.0, 10.0)


func _room(x0: float, x1: float, z0: float, z1: float, col := WALL) -> void:
	box(Vector3((x0 + x1) * 0.5, -0.1, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, z0 - z1), FLOOR, true, 0.0, "tiles_floor")
	box(Vector3((x0 + x1) * 0.5, H + 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, z0 - z1), Color(0.85, 0.86, 0.84), true, 0.0, "tiles_ceiling")


## A wall along z (at x) from za to zb, with doorways [[z, width], ...].
func _wall_x(x: float, za: float, zb: float, gaps: Array, col := WALL) -> void:
	var lo := minf(za, zb)
	var hi := maxf(za, zb)
	var cuts := [lo]
	for g in gaps:
		cuts.append(g[0] - g[1] * 0.5)
		cuts.append(g[0] + g[1] * 0.5)
	cuts.append(hi)
	cuts.sort()
	for i in range(0, cuts.size(), 2):
		if cuts[i + 1] - cuts[i] > 0.02:
			box(Vector3(x, H * 0.5, (cuts[i] + cuts[i + 1]) * 0.5), Vector3(0.2, H, cuts[i + 1] - cuts[i]), col, true, 0.0, "plaster")
	for g in gaps:
		box(Vector3(x, H - 0.4, g[0]), Vector3(0.2, 0.8, g[1]), col, true, 0.0, "plaster")


func _wall_z(z: float, xa: float, xb: float, gaps: Array, col := WALL) -> void:
	var lo := minf(xa, xb)
	var hi := maxf(xa, xb)
	var cuts := [lo]
	for g in gaps:
		cuts.append(g[0] - g[1] * 0.5)
		cuts.append(g[0] + g[1] * 0.5)
	cuts.append(hi)
	cuts.sort()
	for i in range(0, cuts.size(), 2):
		if cuts[i + 1] - cuts[i] > 0.02:
			box(Vector3((cuts[i] + cuts[i + 1]) * 0.5, H * 0.5, z), Vector3(cuts[i + 1] - cuts[i], H, 0.2), col, true, 0.0, "plaster")
	for g in gaps:
		box(Vector3(g[0], H - 0.4, z), Vector3(g[1], 0.8, 0.2), col, true, 0.0, "plaster")


func _panel(pos: Vector3, energy := 0.9, flicker := false) -> void:
	part("box", pos + Vector3(0, H - 0.03, 0), Vector3(1.2, 0.04, 0.5), Color(0.95, 1.0, 0.98), null, Vector3.ZERO, 2.2).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := omni(pos + Vector3(0, H - 0.4, 0), Color(0.88, 0.97, 1.0), energy, 8.0, false)
	_lights.append([l, energy, flicker])


## A wall clock. normal: which way it faces. Shows h:m.
func _clock(pos: Vector3, yaw: float, h: int, m: int) -> void:
	var g := group(pos, yaw)
	part("cylinder", Vector3.ZERO, Vector3(0.42, 0.05, 0.42), Color(0.95, 0.95, 0.92), g, Vector3(90, 0, 0))
	part("cylinder", Vector3(0, 0, -0.01), Vector3(0.46, 0.04, 0.46), Color(0.15, 0.15, 0.15), g, Vector3(90, 0, 0))
	for k in 12:
		var a := deg_to_rad(k * 30.0)
		part("box", Vector3(sin(a) * 0.17, cos(a) * 0.17, 0.03), Vector3(0.012, 0.04, 0.01), Color(0.1, 0.1, 0.1), g, Vector3(0, 0, -k * 30.0))
	var hp := Node3D.new()
	hp.position = Vector3(0, 0, 0.035)
	g.add_child(hp)
	part("box", Vector3(0, 0.06, 0), Vector3(0.02, 0.12, 0.01), Color(0.05, 0.05, 0.05), hp)
	var mp := Node3D.new()
	mp.position = Vector3(0, 0, 0.04)
	g.add_child(mp)
	part("box", Vector3(0, 0.08, 0), Vector3(0.012, 0.17, 0.01), Color(0.05, 0.05, 0.05), mp)
	_clocks.append([hp, mp])
	_set_clock(_clocks.size() - 1, h, m)


func _set_clock(i: int, h: int, m: int) -> void:
	var c: Array = _clocks[i]
	(c[0] as Node3D).rotation_degrees.z = -((h % 12) * 30.0 + m * 0.5)
	(c[1] as Node3D).rotation_degrees.z = -(m * 6.0)


# ------------------------------------------------------------------ the waiting room

func _waiting_room() -> void:
	# x -8..8, z 0..-12; the corridor leaves from the middle of the north wall
	_room(-8, 8, 0.5, CORR_Z0)
	_wall_x(-8, 0.5, CORR_Z0, [])
	_wall_x(8, 0.5, CORR_Z0, [])
	_wall_z(0.5, -8, 8, [])
	_wall_z(CORR_Z0, -8, 8, [[0.0, CORR_X * 2.0]])
	# the porthole door you came through, behind you: a ward door, now. WARD 6 on it.
	part("box", Vector3(0, 1.1, 0.38), Vector3(1.1, 2.2, 0.05), Color(0.85, 0.88, 0.9), null, Vector3.ZERO, 0.0, "metal")
	part("cylinder", Vector3(0, 1.55, 0.34), Vector3(0.4, 0.02, 0.4), Color(0.05, 0.06, 0.08), null, Vector3(90, 0, 0), 0.0, 0.1)
	# rows of chairs, all facing a number display
	for r in 3:
		for c in 6:
			var at := Vector3(-5.0 + c * 1.0 + (0.0 if c < 3 else 1.0), 0, -3.5 - r * 1.6)
			box(at + Vector3(0, 0.42, 0), Vector3(0.5, 0.06, 0.5), Color(0.25, 0.45, 0.55), true, 0.0, "plaster")
			box(at + Vector3(0, 0.7, 0.24), Vector3(0.5, 0.5, 0.05), Color(0.25, 0.45, 0.55), false, 0.0, "plaster")
	var disp := Vector3(5.5, 2.3, CORR_Z0 + 0.12)
	part("box", disp, Vector3(1.4, 0.5, 0.06), Color(0.05, 0.05, 0.05))
	label(disp + Vector3(0, 0.02, 0.04), 0, "NOW SERVING   12", 0.07, Color(1.0, 0.3, 0.2), true)
	# the ticket machine
	var tm := Vector3(-6.5, 0, -1.5)
	box(tm + Vector3(0, 0.6, 0), Vector3(0.45, 1.2, 0.35), Color(0.8, 0.2, 0.18), true, 0.0, "metal")
	label(tm + Vector3(0.0, 1.05, -0.18), 180, "TAKE A\nNUMBER", 0.05, Color(1, 1, 1), false)
	interactable(tm + Vector3(0, 0.9, -0.3), Vector3(0.6, 0.6, 0.6), func(): return "Take a number" if not Game.has_flag("q_number") else "",
		func():
			Game.set_flag("q_number")
			Sfx.play("page", -4.0, 1.5)
			Game.hud.show_thought("Number 13. They're serving 12. ...There's nobody else waiting.", 3.5),
		func(): return not Game.has_flag("q_number"))
	# reception, and the visitors' book
	var rd := Vector3(-4.0, 0, -10.0)
	box(rd + Vector3(0, 0.55, 0), Vector3(3.0, 1.1, 0.7), Color(0.6, 0.62, 0.6), true, 0.0, "plaster")
	label(rd + Vector3(0, 1.45, 0.36), 0, "RECEPTION", 0.08, Color(0.2, 0.25, 0.3), false)
	part("box", rd + Vector3(0.5, 1.13, 0.1), Vector3(0.4, 0.04, 0.3), Color(0.25, 0.2, 0.35))
	interactable(rd + Vector3(0.5, 1.2, 0.4), Vector3(0.6, 0.4, 0.5), func(): return "Read the visitors' book",
		func():
			Game.set_flag("q_book")
			Game.hud.show_thought("Every line's in my handwriting. Every night, 3:12 AM. 'Visiting: WARD 6.' ...Every night.", 4.5),
		func(): return Game.has_flag("q_number"))
	# clocks: every one says something different
	_clock(Vector3(-7.88, 2.2, -5.0), 90, 3, 12)
	_clock(Vector3(7.88, 2.2, -4.0), -90, 9, 40)
	_clock(Vector3(-2.5, 2.4, 0.38), 180, 6, 5)
	_clock(Vector3(2.5, 2.4, CORR_Z0 + 0.12), 0, 11, 55)
	# a pot plant, and in the corner, the ice cream cart, very old
	shape_at("cylinder", Vector3(7.2, 0.3, -11.2), Vector3(0.5, 0.6, 0.5), Color(0.5, 0.3, 0.2), true)
	shape_at("sphere", Vector3(7.2, 0.9, -11.2), Vector3(0.9, 0.9, 0.9), Color(0.2, 0.35, 0.15), false)
	box(Vector3(6.8, 0.6, -0.5), Vector3(1.4, 0.9, 0.7), Color(0.9, 0.88, 0.82), true, 0.0, "plaster")
	box(Vector3(6.8, 1.1, -0.5), Vector3(1.44, 0.1, 0.74), Color(0.9, 0.5, 0.6), false)
	interactable(Vector3(6.8, 1.0, -0.9), Vector3(1.4, 1.0, 0.5), func(): return "Ice cream cart",
		func(): Game.hud.show_thought("Mina's cart. In a hospital. Someone's put a get-well card on it. It isn't signed.", 4.0))
	for x in [-4.0, 4.0]:
		_panel(Vector3(x, 0, -4.0))
		_panel(Vector3(x, 0, -9.0), 0.7, true)


# ------------------------------------------------------------------ the corridor

func _corridor() -> void:
	_room(-CORR_X, CORR_X, CORR_Z0, CORR_Z1)
	# west wall: records at -18, wards 1, 3, 5 ; east wall: nurses at -25, wards 2, 4, garden doors at -46
	_wall_x(-CORR_X, CORR_Z0, CORR_Z1, [[-18.0, 1.2], [-31.0, 1.0], [-37.0, 1.0], [-43.0, 1.0]])
	_wall_x(CORR_X, CORR_Z0, CORR_Z1, [[-25.0, 2.4], [-34.0, 1.0], [-40.0, 1.0], [-46.0, 1.6]])
	_wall_z(CORR_Z1, -CORR_X, CORR_X, [[0.0, 1.2]])
	# ward doors (shut, with a little window each) - wards 1 to 5
	var wards := [[-CORR_X, -31.0, "1"], [CORR_X, -34.0, "2"], [-CORR_X, -37.0, "3"], [CORR_X, -40.0, "4"], [-CORR_X, -43.0, "5"]]
	for w in wards:
		var s := signf(w[0])
		var dpos := Vector3(w[0] + s * 0.02, 0, w[1])
		var d := door(dpos, -90.0 * s, Color(0.75, 0.78, 0.8), 0.95, 2.05, "metal")
		label(Vector3(w[0] - s * 0.12, 2.35, w[1]), -90.0 * s, "WARD " + w[2], 0.07, Color(0.2, 0.3, 0.45), false)
		blocker(dpos + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 1.0))
	for z in [-15.0, -21.0, -27.0, -33.0, -39.0, -45.0]:
		_panel(Vector3(0, 0, z), 0.8, z == -33.0 or z == -45.0)
	_clock(Vector3(-CORR_X + 0.12, 2.3, -24.0), 90, 4, 20)
	_clock(Vector3(CORR_X - 0.12, 2.3, -29.0), -90, 12, 0)
	label(Vector3(0, 2.6, CORR_Z0 - 0.15), 180, "WARDS 1 - 6", 0.08, Color(0.2, 0.3, 0.45), false)
	# the flood: pool water over the floor, the tiles under it the pool's tiles
	var fz := (FLOOD.x + FLOOD.y) * 0.5
	var fl := FLOOD.x - FLOOD.y
	box(Vector3(0, 0.0, fz), Vector3(CORR_X * 2.0, 0.02, fl), Color(0.75, 0.85, 0.9), false, 0.0, "tiles_pool")
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.45, 0.55, 0.55)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.04
	wm.metallic = 0.3
	var water := MeshInstance3D.new()
	water.mesh = Shapes.mesh("box")
	water.scale = Vector3(CORR_X * 2.0, 0.01, fl + 1.0)
	water.position = Vector3(0, 0.14, fz)
	water.material_override = wm
	add_child(water)
	omni(Vector3(0, 0.4, fz), Color(0.35, 0.7, 0.9), 0.6, 6.0, false)
	trigger(Vector3(0, 1.2, FLOOD.x + 1.0), Vector3(3, 2.4, 2), func():
		Sfx.play("splash", -4.0, 1.3)
		Game.hud.show_thought("Water. In a hospital corridor. ...It's warm. It smells like the pool. It smells exactly like the pool.", 4.5))
	# the visitors: under sheets, in the doorways
	for spec in [[Vector3(-0.9, 0, -31.0), 90.0], [Vector3(0.9, 0, -40.0), -90.0], [Vector3(-0.9, 0, -43.0), 90.0]]:
		var f := Node3D.new()
		f.position = spec[0]
		f.rotation_degrees.y = spec[1]
		add_child(f)
		var model := Models.instance(["creatures/draped"])
		if model:
			f.add_child(Models.fit(model, 1.85))
		else:
			part("capsule", Vector3(0, 0.95, 0), Vector3(0.62, 1.0, 0.5), Color(0.92, 0.92, 0.9), f, Vector3.ZERO, 0.0, "fabric")
			part("sphere", Vector3(0, 1.72, 0.02), Vector3(0.3, 0.34, 0.3), Color(0.92, 0.92, 0.9), f, Vector3.ZERO, 0.0, "fabric")
		_figures.append(f)


func _update_figures(delta: float, p: Vector3) -> void:
	if not _figures_awake or no_figures:
		return
	for f in _figures:
		var head: Vector3 = f.global_position + Vector3(0, 1.4, 0)
		var to := p - f.global_position
		to.y = 0.0
		var d := to.length()
		if d > 16.0:
			continue
		f.rotation.y = atan2(to.x, to.z)
		if Observation.is_observed(head, 0.6):
			continue
		f.global_position += to.normalized() * minf(1.3 * delta, maxf(d - 0.2, 0.0))
		if _fig_hint == 0 and d < 7.0:
			_fig_hint = 1
			Game.hud.show_thought("The visitors. They've come out of the doorways. ...They were further away. They were further away.", 4.0)
		if d < 0.75:
			Game.entity_death("sheet", f)
			return


# ------------------------------------------------------------------ records and the nurses' station

func _records() -> void:
	# x -9..-1.5, z -14..-22, door at -18
	_room(-9, -CORR_X, -14, -22)
	_wall_z(-14, -9, -CORR_X, [])
	_wall_z(-22, -9, -CORR_X, [])
	_wall_x(-9, -14, -22, [])
	label(Vector3(-CORR_X - 0.12, 2.35, -18.0), 90, "RECORDS", 0.07, Color(0.2, 0.3, 0.45), false)
	_panel(Vector3(-5.2, 0, -18.0), 0.7, true)
	for k in 5:
		box(Vector3(-8.5, 0.75, -15.0 - k * 1.5), Vector3(0.6, 1.5, 1.2), Color(0.55, 0.57, 0.58), true, 0.0, "metal")
	box(Vector3(-5.0, 0.4, -18.0), Vector3(1.6, 0.8, 0.9), Color(0.5, 0.42, 0.32), true, 0.0, "wood")
	var files := [
		["MINA (no surname)", "MINA - no surname given. Ice cream vendor. Admitted: never. Discharged: never. Notes: 'Keeps asking whether it's still summer.'"],
		["HALVORSEN, ARNE", "HALVORSEN, ARNE. Pigeons. Admitted: never. Next of kin: the bench. Notes: 'Very polite. Asks for nothing.'"],
		["THEO (age unknown)", "THEO - age unknown, it changes. Kite. Admitted: never. Notes: 'Will not let go of the string.'"],
		["UNKNOWN MALE (fell)", "UNKNOWN MALE. Fell from a great height, a long way off. No sound until he'd gone. Admitted: never. Notes: 'Not anyone. Was supposed to be someone else.'"],
	]
	for k in files.size():
		var at := Vector3(-7.9, 1.0, -15.0 - k * 1.5)
		var text: String = files[k][1]
		interactable(at, Vector3(0.6, 0.8, 1.0), func(): return "Read the file: " + files[k][0],
			func():
				Sfx.play("page", -6.0, 1.0)
				Game.hud.show_thought(text, 6.0)
				Game.counters["files"] = int(Game.counters.get("files", 0)) + 1)
	# the one that matters, on the desk
	part("box", Vector3(-5.0, 0.82, -18.0), Vector3(0.35, 0.03, 0.45), Color(0.85, 0.7, 0.4))
	label(Vector3(-5.0, 0.84, -18.0), 0, "WARD 6", 0.05, Color(0.2, 0.15, 0.1), false).rotation_degrees.x = -90
	interactable(Vector3(-5.0, 1.0, -18.0), Vector3(0.6, 0.5, 0.7), func(): return "Read the Ward 6 file",
		func():
			Game.set_flag("q_records")
			Sfx.play("page", -4.0, 0.8)
			Game.hud.show_thought("WARD 6. The name's been scratched out, hard, through the paper. 'Admitted 3:12 AM. One visitor, every night. Key: nurses' station.'", 6.0),
		func(): return Game.has_flag("q_book"))


func _nurses() -> void:
	# an alcove off the east side of the corridor
	_room(CORR_X, 6.5, -22.5, -27.5)
	_wall_z(-22.5, CORR_X, 6.5, [])
	_wall_z(-27.5, CORR_X, 6.5, [])
	_wall_x(6.5, -22.5, -27.5, [])
	box(Vector3(3.2, 0.55, -25.0), Vector3(0.6, 1.1, 3.0), Color(0.6, 0.62, 0.6), true, 0.0, "plaster")
	label(Vector3(2.88, 1.3, -25.0), -90, "NURSES", 0.07, Color(0.2, 0.3, 0.45), false)
	_panel(Vector3(4.5, 0, -25.0), 0.7)
	# a board of hooks; one key left
	part("box", Vector3(6.38, 1.6, -25.0), Vector3(0.04, 0.6, 1.0), Color(0.5, 0.4, 0.3), null, Vector3.ZERO, 0.0, "wood")
	for k in 6:
		part("cylinder", Vector3(6.32, 1.75 - (k / 3) * 0.3, -25.3 + (k % 3) * 0.3), Vector3(0.015, 0.06, 0.015), Color(0.7, 0.7, 0.7), null, Vector3(0, 0, 90), 0.0, "metal")
	_key = group(Vector3(6.3, 1.68, -25.0))
	var hung := prop("key", Vector3.ZERO, 90.0, 1.0, _key)
	if hung:
		hung.rotation_degrees.x = 90.0
	else:
		part("box", Vector3.ZERO, Vector3(0.02, 0.08, 0.03), Color(0.75, 0.68, 0.4), _key, Vector3.ZERO, 0.0, "metal")
		part("box", Vector3(0, -0.07, 0), Vector3(0.02, 0.05, 0.05), Color(0.9, 0.9, 0.85), _key)
	interactable(Vector3(6.1, 1.6, -25.0), Vector3(0.6, 0.6, 1.0), func(): return "Take the key to Ward 6",
		func():
			_key.visible = false
			Game.set_flag("q_key")
			Sfx.play("page", -4.0, 1.4)
			Game.hud.show_thought("WARD 6. ...Behind me, in the water - did something move?", 3.5)
			_figures_awake = true,
		func(): return _key.visible and Game.has_flag("q_records"))


# ------------------------------------------------------------------ Ward 6

func _ward6() -> void:
	# x -5..5, z -50..-58: a hospital room that is also your bedroom
	_room(-5, 5, CORR_Z1, -58)
	_wall_x(-5, CORR_Z1, -58, [])
	_wall_x(5, CORR_Z1, -58, [])
	_wall_z(-58, -5, 5, [])
	_wall_z(CORR_Z1, -5, -CORR_X, [])
	_wall_z(CORR_Z1, CORR_X, 5, [])
	_ward_door = door(Vector3(0, 0, CORR_Z1 + 0.02), 0, Color(0.75, 0.78, 0.8), 1.1, 2.05, "metal")
	label(Vector3(0, 2.35, CORR_Z1 + 0.12), 0, "WARD 6", 0.08, Color(0.2, 0.3, 0.45), false)
	_ward_block = solid_box(Vector3(0, 1.0, CORR_Z1), Vector3(1.2, 2.0, 0.2), Color(0, 0, 0))
	_ward_block.get_child(1).visible = false
	interactable(Vector3(0, 1.2, CORR_Z1 + 0.4), Vector3(1.2, 2.0, 0.5),
		func(): return "Unlock Ward 6" if Game.has_flag("q_key") else "Ward 6",
		func():
			if not Game.has_flag("q_key"):
				Game.hud.show_thought("Locked. 'WARD 6.' There's a light on in there.", 2.5)
				return
			_ward_block.queue_free()
			_ward_block = null
			open_door(_ward_door, 95.0, 1.4)
			Sfx.play("door_creak", -4.0, 0.9)
			Game.set_flag("q_ward6"),
		func(): return _ward_block != null)
	# the bed, the monitor, the chart
	box(Vector3(-2.0, 0.5, -55.5), Vector3(1.0, 0.5, 2.1), Color(0.9, 0.9, 0.92), true, 0.0, "fabric")
	box(Vector3(-2.0, 0.85, -56.4), Vector3(0.8, 0.18, 0.4), Color(0.95, 0.95, 0.95), false, 0.0, "fabric")
	part("box", Vector3(-2.0, 0.78, -55.2), Vector3(0.95, 0.06, 1.2), Color(0.75, 0.82, 0.88), null, Vector3(0, 0, 0), 0.0, "fabric")
	box(Vector3(-3.3, 1.3, -56.5), Vector3(0.5, 0.4, 0.3), Color(0.2, 0.22, 0.25), false, 0.0, "metal")
	label(Vector3(-3.3, 1.3, -56.34), 0, "~^~~^~~", 0.05, Color(0.3, 1.0, 0.4), true)
	part("box", Vector3(-2.0, 0.9, -54.35), Vector3(0.35, 0.45, 0.02), Color(0.9, 0.9, 0.85))
	interactable(Vector3(-2.0, 0.9, -54.1), Vector3(0.6, 0.6, 0.5), func(): return "Read the chart",
		func(): _chart())
	# your desk, your computer, the video paused on its title; the mirror with the towel over it
	box(Vector3(3.2, 0.75, -57.3), Vector3(2.0, 0.05, 0.9), Color(0.4, 0.3, 0.2), true, 0.0, "wood")
	box(Vector3(3.2, 0.37, -57.3), Vector3(1.9, 0.74, 0.8), Color(0.35, 0.26, 0.18), true, 0.0, "wood")
	part("box", Vector3(3.2, 1.15, -57.55), Vector3(0.9, 0.55, 0.05), Color(0.05, 0.05, 0.06))
	label(Vector3(3.2, 1.17, -57.52), 0, "HOW TO LUCID DREAM\nTONIGHT! (100% WORKING)\n|| PAUSED", 0.03, Color(0.9, 0.9, 0.95), true)
	omni(Vector3(3.2, 1.3, -57.0), Color(0.6, 0.7, 1.0), 0.4, 3.0, false)
	part("box", Vector3(4.88, 1.6, -54.0), Vector3(0.03, 1.1, 0.6), Color(0.6, 0.65, 0.7), null, Vector3.ZERO, 0.0, "glass")
	part("box", Vector3(4.84, 1.7, -54.0), Vector3(0.03, 1.0, 0.65), Color(0.85, 0.3, 0.3), null, Vector3.ZERO, 0.0, "fabric")
	interactable(Vector3(4.6, 1.6, -54.0), Vector3(0.4, 1.0, 0.8), func(): return "The towel over the mirror",
		func(): Game.hud.show_thought("The towel's over the mirror. Like at home. ...I'm not lifting it. Rule one.", 3.5))
	part("box", Vector3(-3.6, 0.6, -54.6), Vector3(0.5, 0.6, 0.5), Color(0.6, 0.5, 0.4), null, Vector3.ZERO, 0.0, "wood")
	part("box", Vector3(-3.6, 0.93, -54.6), Vector3(0.18, 0.03, 0.24), Color(0.25, 0.2, 0.35))
	interactable(Vector3(-3.6, 1.0, -54.6), Vector3(0.5, 0.4, 0.5), func(): return "Notebook",
		func(): Game.hud.show_thought("My notebook. ...No. My notebook's in my pocket. It's the same one. Same cover, same coffee ring.", 4.0))
	_panel(Vector3(0, 0, -54.0), 0.6)
	_clock(Vector3(-4.88, 2.3, -53.0), 90, 3, 12)
	trigger(Vector3(0, 1.2, -51.5), Vector3(4, 2.4, 2), func():
		Game.hud.show_thought("This is my room. My desk. My computer. ...In a hospital. With a bed in it.", 4.0))


func _chart() -> void:
	Sfx.play("page", -4.0, 0.9)
	if Game.has_flag("q_chart"):
		Game.hud.show_thought("'not yet.'", 2.0)
		return
	Game.set_flag("q_chart")
	Game.hud.show_thought("PATIENT: (scratched out). TIME OF DEATH: 3:12 AM. ...Crossed out. Underneath, in my handwriting: 'not yet.'", 6.0)
	# the monitor flatlines - then, after a long moment, picks up again. every clock stops at 3:12.
	_monitor_flat = true
	Sfx.play("horror_swell", -2.0)
	Sfx.play("chime", 0.0, 0.5)
	await get_tree().create_timer(3.5, false).timeout
	_monitor_flat = false
	for i in _clocks.size():
		_set_clock(i, 3, 12)
	_figures_awake = false
	for f in _figures:
		f.visible = false
	Sfx.play("thud", -6.0, 1.6)
	_garden_block.queue_free()
	_garden_block = null
	open_door(_garden_door, -100.0, 1.2)
	Game.hud.show_thought("...Every clock in the building just stopped. And somewhere back down the corridor, a door's come open. Into a garden.", 5.0)


# ------------------------------------------------------------------ the garden

func _garden() -> void:
	# the glass door from the corridor (east side, z -46), into a walled garden x 1.5..27, z -38..-58
	_garden_door = door(Vector3(CORR_X + 0.02, 0, -46.0), -90, Color(0.7, 0.8, 0.85), 1.5, 2.05, "glass")
	_garden_block = solid_box(Vector3(CORR_X, 1.0, -46.0), Vector3(0.2, 2.0, 1.6), Color(0, 0, 0))
	_garden_block.get_child(1).visible = false
	label(Vector3(CORR_X - 0.12, 2.35, -46.0), 90, "MEMORIAL GARDEN", 0.06, Color(0.2, 0.3, 0.45), false)
	interactable(Vector3(CORR_X - 0.3, 1.2, -46.0), Vector3(0.5, 2.0, 1.6), func(): return "Garden door",
		func(): Game.hud.show_thought("Locked. Through the glass: grass, a tree, a bench. Someone on the bench.", 3.0),
		func(): return _garden_block != null)
	# a short glass passage, then the garden: x 6..30, z -36..-56
	box(Vector3(3.8, -0.1, -46.0), Vector3(4.6, 0.2, 1.8), FLOOR, true, 0.0, "tiles_floor")
	box(Vector3(3.8, H + 0.1, -46.0), Vector3(4.6, 0.2, 1.8), Color(0.85, 0.86, 0.84), true, 0.0, "tiles_ceiling")
	for z in [-45.0, -47.0]:
		box(Vector3(3.8, H * 0.5, z), Vector3(4.6, H, 0.1), Color(0.6, 0.7, 0.75), true, 0.0, "glass")
	var gx0 := 6.0
	var gx1 := 30.0
	var gz0 := -36.0
	var gz1 := -56.0
	box(Vector3((gx0 + gx1) * 0.5, -0.1, (gz0 + gz1) * 0.5), Vector3(gx1 - gx0, 0.2, gz0 - gz1), Color(0.18, 0.28, 0.14), true, 0.0, "grass")
	var brick := Color(0.45, 0.3, 0.25)
	box(Vector3((gx0 + gx1) * 0.5, 1.5, gz0), Vector3(gx1 - gx0, 3.0, 0.4), brick, true, 0.0, "concrete")
	box(Vector3((gx0 + gx1) * 0.5, 1.5, gz1), Vector3(gx1 - gx0, 3.0, 0.4), brick, true, 0.0, "concrete")
	for side in [[gx0, -45.0, gz0], [gx0, -47.0, gz1], [gx1, -44.8, gz0], [gx1, -47.2, gz1]]:
		var za: float = side[1]
		var zb: float = side[2]
		box(Vector3(side[0], 1.5, (za + zb) * 0.5), Vector3(0.4, 3.0, absf(za - zb)), brick, true, 0.0, "concrete")
	box(Vector3(gx0, 2.6, -46.0), Vector3(0.4, 0.8, 2.0), brick, true, 0.0, "concrete")
	# a path, a tree, the bench, the plaques
	box(Vector3(18.0, 0.01, -46.0), Vector3(24.0, 0.02, 1.4), Color(0.6, 0.58, 0.52), false, 0.0, "pavers")
	prop("tree_oak", Vector3(18.0, 0, -51.5), 30.0, 1.2)
	var kite := group(Vector3(19.0, 6.5, -50.5))
	part("box", Vector3.ZERO, Vector3(0.9, 0.9, 0.03), Color(0.9, 0.2, 0.25), kite, Vector3(0, 0, 45))
	part("cylinder", Vector3(0, -1.2, 0), Vector3(0.01, 2.4, 0.01), Color(0.9, 0.9, 0.9), kite, Vector3(0, 0, 20))
	if prop("bench", Vector3(14.0, 0, -42.5), 180.0) == null:
		box(Vector3(14.0, 0.45, -42.5), Vector3(1.8, 0.08, 0.5), Color(0.5, 0.32, 0.18), true, 0.0, "wood")
	_halvorsen = NPC.new()
	add_child(_halvorsen)
	_halvorsen.position = Vector3(14.0, 0, -42.36)       # on the seat, facing out over the garden (the bench's back is to the north)
	_halvorsen.rotation_degrees.y = 0
	_halvorsen.setup("halvorsen", "Mr. Halvorsen", "the old man", {"skin": Color(0.84, 0.68, 0.58), "hair": Color(0.78, 0.78, 0.76),
		"shirt": Color(0.42, 0.47, 0.34), "pants": Color(0.33, 0.29, 0.24), "seated": true, "cap": true,
		"cap_color": Color(0.28, 0.28, 0.3), "sleeves": "long", "hair_style": "short", "build": 1.05, "shoes": Color(0.25, 0.15, 0.08)})
	_halvorsen.dialogue_id = "halvorsen_quiet"
	for k in 5:
		var pg := group(Vector3(13.0 + k * 0.5, 0, -43.6 - (k % 2) * 0.4), randf() * 360.0)
		if prop("pigeon", Vector3.ZERO, 0.0, 1.0, pg) == null:
			part("sphere", Vector3(0, 0.12, 0), Vector3(0.16, 0.14, 0.24), Color(0.5, 0.52, 0.56), pg)
			part("sphere", Vector3(0, 0.2, 0.1), Vector3.ONE * 0.08, Color(0.4, 0.42, 0.46), pg)
	# plaques on the north wall
	var names := ["MINA", "ARNE HALVORSEN", "THEO", "THE MAN WHO FELL", "THE TALL ONE IN THE YELLOW ROOMS", ""]
	for k in names.size():
		var at := Vector3(9.0 + k * 3.6, 1.4, gz0 - 0.22)
		part("box", at, Vector3(1.4, 0.5, 0.04), Color(0.55, 0.45, 0.25), null, Vector3.ZERO, 0.0, "metal")
		if names[k] != "":
			label(at + Vector3(0, 0, -0.03), 180, "IN MEMORY OF\n" + names[k], 0.045, Color(0.15, 0.12, 0.08), false)
	interactable(Vector3(9.0 + 5 * 3.6, 1.4, gz0 - 0.5), Vector3(1.4, 0.8, 0.5), func(): return "The blank plaque",
		func(): Game.hud.show_thought("Blank. Polished. Waiting. ...Not yet.", 3.0))
	# the gate
	_gate = group(GATE + Vector3(0, 0, -1.2))
	for k in 8:
		part("cylinder", Vector3(0, 1.3, k * 0.3 + 0.15), Vector3(0.05, 2.6, 0.05), Color(0.15, 0.15, 0.15), _gate, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(0, 2.5, 1.2), Vector3(0.06, 0.08, 2.4), Color(0.15, 0.15, 0.15), _gate, Vector3.ZERO, 0.0, "metal")
	_gate_block = solid_box(GATE + Vector3(0, 1.3, 0), Vector3(0.2, 2.6, 2.4), Color(0, 0, 0))
	_gate_block.get_child(1).visible = false
	omni(GATE + Vector3(2.0, 1.5, 0), Color(1.0, 0.95, 0.85), 2.5, 8.0, false)
	interactable(GATE + Vector3(-0.4, 1.2, 0), Vector3(0.5, 2.0, 2.4),
		func(): return "Open the gate" if Game.has_flag("q_gatekey") else "The gate",
		func():
			if not Game.has_flag("q_gatekey"):
				Game.hud.show_thought("Locked. There's light on the other side. White light. ...The man on the bench is watching me.", 3.5)
				return
			_gate_block.queue_free()
			_gate_block = null
			create_tween().tween_property(_gate, "rotation_degrees:y", -100.0, 2.0).set_trans(Tween.TRANS_SINE)
			Sfx.play("creak", -2.0, 0.7)
			Game.hud.show_thought("...", 2.0)
			get_tree().create_timer(2.0, false).timeout.connect(func(): Game.on_quiet_exit()),
		func(): return _gate_block != null)
	# the night: moonlight, a lamp by the bench
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_color = Color(0.6, 0.7, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)
	omni(Vector3(12.5, 2.6, -41.8), Color(1.0, 0.85, 0.6), 1.2, 9.0, false)
	trigger(Vector3(7.5, 1.2, -46.0), Vector3(2.5, 2.4, 3.0), func():
		Game.set_flag("q_garden")
		Sfx.play("wind", -8.0, 1.2)
		Game.hud.show_thought("Air. Stars. A garden. ...That's Mr. Halvorsen. On a bench. With the pigeons.", 4.0))


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	Game.counters["files"] = 0


func _process(delta: float) -> void:
	_t += delta
	for l in _lights:
		if l[2]:
			l[0].light_energy = l[1] * (0.1 if randf() < 0.05 and Settings.flashing_ok() else 1.0)
	# the heart monitor: a beep a second; flat, for a while, after the chart
	_monitor_t -= delta
	if _monitor_t <= 0.0:
		_monitor_t = 1.0
		var pl0: Player = Game.player
		if pl0 and pl0.global_position.distance_to(Vector3(-3.3, 1.3, -56.5)) < 9.0:
			Sfx.play_at("chime", self, Vector3(-3.3, 1.3, -56.5), -10.0 if not _monitor_flat else -4.0, 10.0)
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_update_figures(delta, p)
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("A hospital. A waiting room. ...It's so quiet. The door I came through says WARD 6.", 4.0)
	elif _hint == 1 and _t > 7.0:
		_hint = 2
		Game.hud.show_thought("Nobody at reception. There's a ticket machine.", 3.0)
