class_name TenementZone
extends Zone
## COMPRESSION, part two: the freight elevator goes up into an apartment building that doesn't fit
## inside itself.
##
##  3 The Apartments       a narrow third-floor hallway. 3B stands open. Inside, the flat goes on far
##                         longer than the building is wide: a living room (with a park bench in it),
##                         a yellow corridor that hums like the Backrooms, a child's room, a bathroom.
##  4 The Squeeze          the bathroom vent: a duct that gets narrower the further you crawl.
##  5 Impossible Building  a stairwell. ROOF ACCESS is from floor 7. Going up brings you back to the
##                         same landing; going DOWN raises the floor number.
##  6 The Collapse         floor 7's corridor. The building comes down behind you: ceiling, walls -
##                         the corridor shrinks to nothing a few steps behind you.
##  7 The Escape Shaft     a narrow vertical climb, and a door at the very top. (-> ABOVE)

const O := Vector3(-52, 0, -24)        # stairwell origin: north-wall centre of the main landing
const STOREY := 3.2
const CORR_X0 := -49.9                 # collapse corridor
const CORR_X1 := -10.0
const CORR_Z := -24.8
const SHAFT := Vector3(-8.8, 0, -24.8)
const SHAFT_H := 14.0
const EXIT_FLOOR := 7

## Checkpoints (see Zone.checkpoint_at): out of the duct, floor 7, the shaft.
const CHECKPOINTS := {
	"stairs": [Vector3(-51.0, 0.05, -24.9), 180.0, ["ten_apartment", "ten_vent", "ten_stairs"]],
	"floor7": [Vector3(-48.9, 0.05, -24.8), -90.0, ["ten_apartment", "ten_vent", "ten_stairs", "ten_floor7"]],
	"shaft": [Vector3(-8.8, 0.05, -24.8), -90.0, ["ten_apartment", "ten_vent", "ten_stairs", "ten_floor7", "ten_collapse", "ten_shaft"]],
}

const PAPER := Color(0.52, 0.55, 0.46)
const PLASTER := Color(0.78, 0.76, 0.7)
const CONCRETE := Color(0.45, 0.44, 0.41)

var observer: Observer
var _obs_stage := 0
var _floor_num := 4
var _labels := {}                 # storey -> Label3D
var _ups := 0
var _downs := 0
var _exit_door: Node3D
var _exit_block: StaticBody3D
var _grille: Node3D
var _grille_block: StaticBody3D
var _collapse := false
var _front := CORR_X0
var _front_speed := 2.8
var _segs: Array = []             # [x, ceiling body, wall L, wall R, light, done]
var _dust: CPUParticles3D
var _climbing := false
var _t := 0.0
var _hint := 0
var _creak_t := 6.0
var _tv: MeshInstance3D
var _duct_pops := 0
var _leaving := false


func zone_id() -> String: return "tenement"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 15.0
func fear_decay() -> float: return 1.2
func floor_surface() -> String: return "wood"
func walk_speed() -> float: return 2.3
func sprint_speed() -> float: return 3.7
## A light can be pictured here (hold Q) - a weak one: the dark still counts.
func allows_manifestation() -> bool: return true
func manifest_allowlist() -> Array: return ["flashlight"]
func flashlight_scale() -> float: return 0.45


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, 1.0))


# ------------------------------------------------------------------ helpers

## An axis-aligned wall from a to b (x,z), with openings: [offset along, width, top, bottom := 0].
func _wall(a: Vector2, b: Vector2, h: float, col: Color, surf: String, gaps := [], y0 := 0.0, t := 0.12) -> void:
	var along := b - a
	var L := along.length()
	var dir := along / L
	var xz := absf(dir.x) > 0.5
	var spans := []
	var cur := 0.0
	var gs := gaps.duplicate()
	gs.sort_custom(func(p, q): return p[0] < q[0])
	for g in gs:
		var g0: float = g[0] - g[1] * 0.5
		var g1: float = g[0] + g[1] * 0.5
		var top: float = g[2]
		var bottom: float = g[3] if g.size() > 3 else 0.0
		if g0 > cur:
			spans.append([cur, g0, 0.0, h])
		if top < h:
			spans.append([g0, g1, top, h])
		if bottom > 0.0:
			spans.append([g0, g1, 0.0, bottom])
		cur = g1
	if cur < L:
		spans.append([cur, L, 0.0, h])
	for s in spans:
		var s0: float = s[0]
		var s1: float = s[1]
		var y_lo: float = s[2]
		var y_hi: float = s[3]
		var p := a + dir * ((s0 + s1) * 0.5)
		var size := Vector3(s1 - s0, y_hi - y_lo, t) if xz else Vector3(t, y_hi - y_lo, s1 - s0)
		box(Vector3(p.x, y0 + (y_lo + y_hi) * 0.5, p.y), size, col, true, 0.0, surf)


## A room: floor, ceiling and four walls. gaps: {"n"|"s"|"w"|"e": [[offset, width, top, bottom?], ...]}
## (n = the -Z wall, offsets run +X; w = the -X wall, offsets run +Z.)
func _room(x0: float, x1: float, z0: float, z1: float, h: float, wall: Color, wall_s: String,
		floor_c: Color, floor_s: String, ceil_c: Color, gaps := {}, y0 := 0.0, ceiling := true) -> void:
	box(Vector3((x0 + x1) * 0.5, y0 - 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.15, 0.2, z1 - z0 + 0.15), floor_c, true, 0.0, floor_s)
	if ceiling:
		box(Vector3((x0 + x1) * 0.5, y0 + h + 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.15, 0.2, z1 - z0 + 0.15), ceil_c, true, 0.0, "plaster")
	_wall(Vector2(x0, z0), Vector2(x1, z0), h, wall, wall_s, gaps.get("n", []), y0)
	_wall(Vector2(x0, z1), Vector2(x1, z1), h, wall, wall_s, gaps.get("s", []), y0)
	_wall(Vector2(x0, z0), Vector2(x0, z1), h, wall, wall_s, gaps.get("w", []), y0)
	_wall(Vector2(x1, z0), Vector2(x1, z1), h, wall, wall_s, gaps.get("e", []), y0)
	# skirting
	for z in [z0 + 0.07, z1 - 0.07]:
		box(Vector3((x0 + x1) * 0.5, y0 + 0.06, z), Vector3(x1 - x0, 0.12, 0.02), wall.darkened(0.5), false, 0.0, "wood")


## Collision only (stairs are drawn as steps, walked as ramps).
func _ramp(center: Vector3, size: Vector3, rot_x_deg: float) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation_degrees.x = rot_x_deg
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	add_child(body)


func _bulb(pos: Vector3, energy: float, rng: float, col := Color(1.0, 0.8, 0.55)) -> OmniLight3D:
	if prop("ceiling_bulb", pos + Vector3(0, 0.56, 0), 0.0) == null:
		part("sphere", pos, Vector3(0.09, 0.12, 0.09), col, null, Vector3.ZERO, 5.0)
		part("cylinder", pos + Vector3(0, 0.12, 0), Vector3(0.03, 0.18, 0.03), Color(0.1, 0.1, 0.1), null, Vector3.ZERO, 0.0, "plain")
	return omni(pos + Vector3(0, -0.05, 0), col, energy, rng, false)


# ------------------------------------------------------------------ build

func build() -> void:
	_hallway()
	_apartment()
	_duct()
	_stairwell()
	_corridor()
	_shaft()
	var env := make_env(Color(0.3, 0.27, 0.22), 0.12)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.05, 0.04)
	env.fog_density = 0.035
	environment(env)
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.position = Vector3(0, -100, 0)
	observer.seen_max_distance = 25.0
	observer.seen.connect(_on_observer_seen)
	ambient("room_tone", Vector3.ZERO, false, -14.0)
	ambient("hum", Vector3.ZERO, false, -26.0)


# ---- 3: the hallway and apartment 3B ---------------------------------------------

func _hallway() -> void:
	var carpet := Color(0.35, 0.12, 0.1)
	_room(-1.1, 1.1, -20.0, 0.0, 2.6, PAPER, "wallpaper", carpet, "carpet", PLASTER, {
		"s": [[1.1, 1.5, 2.3]],
		"w": [[11.0, 1.0, 2.1]],
	})
	# the freight elevator you came up in
	_room(-0.8, 0.8, 0.0, 2.2, 2.4, Color(0.4, 0.42, 0.44), "metal", Color(0.3, 0.3, 0.3), "metal", Color(0.3, 0.3, 0.3), {"n": [[0.8, 1.6, 2.4]]})
	_bulb(Vector3(0, 2.2, 1.1), 0.6, 4.0)
	# doors that don't open. 3B is standing open.
	for d in [[-1.06, -4.0, 90.0, "3A"], [-1.06, -14.0, 90.0, "3C"], [1.06, -6.0, -90.0, "3D"], [1.06, -12.0, -90.0, "3E"]]:
		var x: float = d[0]
		var z: float = d[1]
		var yaw: float = d[2]
		door(Vector3(x, 0, z), yaw, Color(0.42, 0.3, 0.22), 0.92, 2.05, "wood")
		label(Vector3(x + signf(-x) * 0.04, 1.75, z), yaw, d[3], 0.07, Color(0.75, 0.62, 0.35), false)
		var nm: String = d[3]
		interactable(Vector3(x + signf(-x) * 0.25, 1.0, z), Vector3(0.5, 2.0, 1.0), func(): return "Try the door",
			func():
				Sfx.play("knock", -6.0, 0.8)
				if nm == "3C":
					await get_tree().create_timer(0.8, false).timeout
					Sfx.play("knock", -2.0, 0.6)
					Game.player.dread.add_fear(6.0, "knock back")
					Game.hud.show_thought("Locked. ...And something knocked back.", 3.0)
				else:
					Game.hud.show_thought("Locked.", 1.5))
	label(Vector3(-1.04, 1.75, -9.0 - 0.75), 90, "3B", 0.07, Color(0.75, 0.62, 0.35), false)
	if prop("curtain_rail", Vector3(-1.1, 2.15, -9.0), 90.0, 0.9) == null:
		part("box", Vector3(-1.1, 2.15, -9.0), Vector3(0.14, 0.06, 1.1), Color(0.3, 0.22, 0.16), null, Vector3.ZERO, 0.0, "wood")
	# the stairwell door at the end: bricked up behind its wired glass
	door(Vector3(0, 0, -19.94), 0, Color(0.35, 0.36, 0.33), 1.0, 2.1, "metal")
	label(Vector3(0, 2.3, -19.92), 0, "STAIRS", 0.09, Color(0.85, 0.85, 0.8), false)
	interactable(Vector3(0, 1.0, -19.7), Vector3(1.0, 2.0, 0.4), func(): return "Open the stairwell door",
		func(): Game.hud.show_thought("It opens onto bricks. Someone bricked up the stairs.", 3.0))
	for z in [-3.0, -9.5, -16.0]:
		_bulb(Vector3(0, 2.4, z), 0.55, 6.0)
	trigger(Vector3(0, 1.2, -1.5), Vector3(2, 2.4, 1), func():
		Game.hud.show_thought("Up. It went up. ...This isn't the building I was in.", 3.5))
	trigger(Vector3(0, 1.2, -9.0), Vector3(2, 2.4, 1.2), func():
		Sfx.stinger("door_creak", -10.0)
		Game.hud.show_thought("3B is open. There's a light on in there.", 3.0))


func _apartment() -> void:
	var wood := Color(0.42, 0.3, 0.2)
	# living room: x -9..-1.25
	_room(-9.0, -1.25, -13.0, -5.0, 2.7, Color(0.62, 0.52, 0.4), "wallpaper", wood, "wood", PLASTER, {
		"e": [[4.0, 1.0, 2.1]],
		"w": [[4.0, 1.4, 2.3]],
		"n": [[3.9, 1.2, 2.0, 0.9]],
	})
	box(Vector3(-5.1, 1.4, -13.55), Vector3(1.6, 1.4, 0.1), Color(0.45, 0.22, 0.17), true, 0.0, "plaster")  # bricks, right outside the window
	part("box", Vector3(-5.1, 1.45, -13.0), Vector3(1.2, 0.03, 0.03), wood, null, Vector3.ZERO, 0.0, "wood")
	trigger(Vector3(-2.5, 1.2, -9.0), Vector3(2, 2.4, 3), func():
		Game.set_flag("ten_apartment")
		Game.hud.show_thought("Hello? ...The TV's on.", 2.5))
	# sofa facing a television full of static
	if prop("sofa", Vector3(-4.6, 0, -7.2), 180.0, 1.1) == null:
		part("box", Vector3(-4.6, 0.25, -7.2), Vector3(2.2, 0.5, 0.9), Color(0.32, 0.36, 0.3), null, Vector3.ZERO, 0.0, "fabric")
		part("box", Vector3(-4.6, 0.65, -6.8), Vector3(2.2, 0.8, 0.2), Color(0.3, 0.34, 0.28), null, Vector3.ZERO, 0.0, "fabric")
	blocker(Vector3(-4.6, 0.5, -7.1), Vector3(2.2, 1.0, 1.0))
	if not furnish("tv_stand", Vector3(-4.6, 0, -11.9), 0.0, Vector3(1.6, 0.6, 0.5), Vector3(0, 0.3, 0)):
		box(Vector3(-4.6, 0.3, -11.9), Vector3(1.6, 0.6, 0.5), wood.darkened(0.2), true, 0.0, "wood")
	if prop("tv_crt", Vector3(-4.6, 0.6, -11.85), 0.0) != null:
		_tv = part("box", Vector3(-4.6, 0.9, -11.64), Vector3(0.5, 0.36, 0.01), Color(0.7, 0.75, 0.8), null, Vector3.ZERO, 2.0)
	else:
		part("box", Vector3(-4.6, 0.85, -11.9), Vector3(0.8, 0.55, 0.5), Color(0.08, 0.08, 0.08), null, Vector3.ZERO, 0.0, "plain")
		_tv = part("box", Vector3(-4.6, 0.86, -11.64), Vector3(0.62, 0.42, 0.01), Color(0.7, 0.75, 0.8), null, Vector3.ZERO, 2.0)
	_tv.material_override = _tv.material_override.duplicate()
	omni(Vector3(-4.6, 0.9, -11.2), Color(0.6, 0.7, 0.85), 0.5, 4.0, false)
	ambient("static", Vector3(-4.6, 0.9, -11.6), true, -14.0, 8.0)
	if prop("coffee_table", Vector3(-4.6, 0, -9.4), 0.0) == null:
		part("box", Vector3(-4.6, 0.22, -9.4), Vector3(1.0, 0.04, 0.6), wood, null, Vector3.ZERO, 0.0, "wood")
	blocker(Vector3(-4.6, 0.2, -9.4), Vector3(1.0, 0.4, 0.6))
	prop("rug_rect", Vector3(-4.6, 0.0, -9.3), 0.0, 1.2)
	# a standing lamp
	if prop("floor_lamp", Vector3(-8.3, 0, -6.0), 0.0) == null:
		part("cylinder", Vector3(-8.3, 0.75, -6.0), Vector3(0.03, 1.5, 0.03), Color(0.2, 0.18, 0.15), null, Vector3.ZERO, 0.0, "metal")
		part("cone", Vector3(-8.3, 1.55, -6.0), Vector3(0.4, 0.3, 0.4), Color(0.9, 0.8, 0.6), null, Vector3.ZERO, 0.6)
	# someone lives here: an armchair, a shelf of books, pictures, a clock that has stopped
	furnish("armchair_old", Vector3(-2.3, 0, -7.4), 200.0, Vector3(0.85, 0.9, 0.8), Vector3(0, 0.45, 0))
	furnish("bookshelf_low", Vector3(-6.9, 0, -5.2), 180.0, Vector3(1.1, 0.9, 0.32), Vector3(0, 0.45, 0))
	prop("radio_old", Vector3(-6.7, 0.9, -5.22), 170.0)
	prop("picture_frame", Vector3(-3.0, 1.6, -5.0), 180.0)
	prop("picture_frame", Vector3(-1.3, 1.55, -11.8), -90.0, 0.8)
	prop("wall_clock", Vector3(-8.98, 1.95, -7.4), 90.0)
	prop("pendant_lamp", Vector3(-4.6, 2.7, -9.2), 0.0)
	prop("plant_hanging", Vector3(-1.8, 2.7, -12.4), 0.0)
	prop("light_switch", Vector3(-1.27, 1.2, -10.0), -90.0)
	omni(Vector3(-8.3, 1.4, -6.0), Color(1.0, 0.8, 0.55), 0.9, 7.0, true)
	# the park bench. here.
	if prop("bench", Vector3(-7.6, 0, -10.6), 90.0 + 180.0) == null:
		part("box", Vector3(-7.6, 0.45, -10.6), Vector3(0.5, 0.06, 1.6), wood, null, Vector3.ZERO, 0.0, "wood")
	blocker(Vector3(-7.6, 0.5, -10.6), Vector3(0.6, 1.0, 1.7))
	trigger(Vector3(-6.5, 1.2, -9.5), Vector3(1.5, 2.4, 3), func():
		Sfx.stinger("whisper", -8.0)
		Game.hud.show_thought("That's... the bench from the park. The one by the fountain.", 3.5))
	# the yellow corridor: the Backrooms, in someone's flat
	var yellow := Color(0.62, 0.52, 0.28)
	_room(-31.0, -9.15, -10.0, -8.0, 2.5, yellow, "wallpaper", Color(0.5, 0.42, 0.22), "carpet", Color(0.6, 0.57, 0.45), {
		"e": [[1.0, 1.4, 2.3]],
		"w": [[1.0, 1.4, 2.3]],
	})
	for x in range(-12, -30, -4):
		if prop("fluorescent_panel", Vector3(x, 2.5, -9.0), 0.0) == null:
			part("box", Vector3(x, 2.47, -9.0), Vector3(1.2, 0.04, 0.25), Color(1.0, 0.98, 0.85), null, Vector3.ZERO, 3.0)
		omni(Vector3(x, 2.3, -9.0), Color(1.0, 0.96, 0.8), 0.45, 5.0, false)
	ambient("buzz", Vector3(-20, 2.3, -9.0), true, -12.0, 14.0)
	trigger(Vector3(-11.0, 1.2, -9.0), Vector3(1.0, 2.4, 2), func():
		Sfx.stinger("riser", -10.0)
		Game.hud.show_thought("Yellow. Humming. ...That's the yellow rooms. In someone's flat.", 3.5))
	trigger(Vector3(-26.0, 1.2, -9.0), Vector3(1.0, 2.4, 2), func():
		Game.hud.show_thought("This hallway is longer than the whole building.", 3.0))
	# the child's room
	_room(-37.0, -31.15, -13.0, -5.0, 2.6, Color(0.6, 0.66, 0.72), "wallpaper", wood, "wood", PLASTER, {
		"e": [[4.0, 1.0, 2.1]],
		"w": [[4.0, 0.9, 2.1]],
	})
	if prop("kids_bed", Vector3(-35.8, 0, -6.0), 90.0) == null:
		part("box", Vector3(-35.8, 0.25, -6.0), Vector3(1.6, 0.5, 0.8), Color(0.75, 0.75, 0.82), null, Vector3.ZERO, 0.0, "fabric")
	blocker(Vector3(-35.8, 0.3, -6.0), Vector3(1.6, 0.6, 0.8))
	prop("teddy_bear", Vector3(-36.3, 0.42, -5.95), 90.0)
	if prop("toy_box", Vector3(-32.0, 0, -12.4), 0.0) == null:
		part("box", Vector3(-32.0, 0.3, -12.4), Vector3(0.9, 0.6, 0.5), Color(0.7, 0.35, 0.25), null, Vector3.ZERO, 0.0, "wood")
	blocker(Vector3(-32.0, 0.3, -12.4), Vector3(0.9, 0.6, 0.5))
	for i in 6:
		var dp := Vector3(-31.24, 1.2 + (i % 2) * 0.45, -6.5 - i * 0.9)
		if prop("drawing_%d" % (i % 3), dp, -90.0) == null:
			part("box", dp + Vector3(-0.08, 0, 0), Vector3(0.01, 0.35, 0.45), Color(0.95, 0.93, 0.85), null, Vector3.ZERO, 0.0, "plain")
	omni(Vector3(-34.0, 0.4, -12.6), Color(0.6, 0.65, 1.0), 0.35, 5.0, false)   # nightlight
	if prop("nightlight", Vector3(-34.0, 0.35, -13.0), 0.0) == null:
		part("sphere", Vector3(-34.0, 0.35, -12.95), Vector3.ONE * 0.08, Color(0.6, 0.65, 1.0), null, Vector3.ZERO, 3.0)
	furnish("rocking_horse", Vector3(-33.6, 0, -6.6), 35.0, Vector3(0.4, 0.8, 1.0), Vector3(0, 0.4, 0))
	prop("toy_blocks", Vector3(-33.2, 0, -10.2), 20.0)
	prop("rug_round", Vector3(-34.0, 0, -9.0), 0.0, 0.8)
	prop("ceiling_bulb", Vector3(-34.0, 2.6, -9.0), 0.0)
	# a cassette player on the toy box (optional)
	if prop("cassette_player", Vector3(-32.0, 0.58, -12.4), 0.0) == null:
		part("box", Vector3(-32.0, 0.66, -12.4), Vector3(0.28, 0.1, 0.16), Color(0.15, 0.15, 0.15), null, Vector3.ZERO, 0.0, "metal")
	interactable(Vector3(-32.0, 0.7, -12.3), Vector3(0.5, 0.4, 0.4), func(): return "Press play" if not Game.has_flag("ten_tape") else "",
		func(): _tape(), func(): return not Game.has_flag("ten_tape"))
	trigger(Vector3(-32.0, 1.2, -9.0), Vector3(1.0, 2.4, 2), func(): _obs_stage = 1)
	# the bathroom, and the vent
	_room(-40.0, -37.15, -10.5, -7.5, 2.4, Color(0.85, 0.87, 0.86), "tiles_pool", Color(0.6, 0.62, 0.6), "tiles_floor", PLASTER, {
		"e": [[1.5, 0.9, 2.1]],
		"w": [[1.5, 0.9, 1.25]],
	})
	if prop("bathtub", Vector3(-38.6, 0, -10.05), 90.0, 1.12) != null:
		part("box", Vector3(-38.6, 0.46, -10.05), Vector3(1.3, 0.02, 0.42), Color(0.25, 0.3, 0.28), null, Vector3.ZERO, 0.0, "water")
		prop("shower_head", Vector3(-39.98, 1.9, -10.1), 90.0)
	else:
		part("box", Vector3(-38.6, 0.3, -10.05), Vector3(2.0, 0.6, 0.7), Color(0.9, 0.9, 0.88), null, Vector3.ZERO, 0.0, "tiles_pool")
		part("box", Vector3(-38.6, 0.5, -10.05), Vector3(1.8, 0.02, 0.5), Color(0.25, 0.3, 0.28), null, Vector3.ZERO, 0.0, "water")
	blocker(Vector3(-38.6, 0.3, -10.05), Vector3(2.0, 0.6, 0.7))
	furnish("toilet", Vector3(-38.0, 0, -7.78), 180.0, Vector3(0.45, 0.8, 0.6), Vector3(0, 0.4, 0))
	furnish("sink_basin", Vector3(-39.2, 0, -7.75), 180.0, Vector3(0.55, 0.9, 0.45), Vector3(0, 0.45, 0))
	prop("bath_mirror", Vector3(-39.2, 1.55, -7.5), 180.0)
	prop("towel_rail", Vector3(-37.17, 1.1, -8.0), -90.0)
	prop("laundry_basket", Vector3(-37.5, 0, -10.1), 0.0)
	_bulb(Vector3(-38.6, 2.25, -9.0), 0.5, 4.0, Color(0.9, 0.95, 1.0))
	ambient("drip", Vector3(-38.6, 0.5, -10.0), true, -10.0, 6.0)
	_grille = group(Vector3(-39.96, 0.65, -9.0))
	if prop("vent_grille", Vector3.ZERO, 90.0, 1.0, _grille) == null:
		for i in 7:
			part("box", Vector3(0, -0.5 + i * 0.16, 0), Vector3(0.03, 0.04, 0.88), Color(0.6, 0.6, 0.58), _grille, Vector3.ZERO, 0.0, "metal")
	_grille_block = solid_box(Vector3(-40.0, 0.65, -9.0), Vector3(0.1, 1.2, 0.9), Color(0, 0, 0))
	_grille_block.get_child(1).visible = false
	interactable(Vector3(-39.8, 0.65, -9.0), Vector3(0.4, 1.2, 0.9), func(): return "Pull the vent cover off",
		func():
			_grille_block.queue_free()
			Sfx.play("metal_screech", -4.0, 1.3)
			var tw := create_tween()
			tw.tween_property(_grille, "position", Vector3(-39.4, 0.05, -8.3), 0.4)
			tw.parallel().tween_property(_grille, "rotation_degrees", Vector3(80, 30, 0), 0.4)
			Game.set_flag("ten_vent")
			Game.hud.show_thought("It's the only way on. ...Crouch. (C)", 3.0),
		func(): return not Game.has_flag("ten_vent"))
	trigger(Vector3(-38.0, 1.2, -9.0), Vector3(1.0, 2.4, 2), func():
		Game.hud.show_thought("No other door. Just the vent.", 2.5))


func _tape() -> void:
	Sfx.play("static", -10.0)
	var lines := ["\"Mum says the flat is the same size it always was.\"",
		"\"But my room keeps getting further away from the kitchen.\"",
		"\"The man in the corner doesn't talk. He just faces the wall when you look.\""]
	for i in lines.size():
		Game.hud.show_thought(lines[i], 3.8)
		await get_tree().create_timer(4.0, false).timeout
		if not is_inside_tree():
			return
	Game.set_flag("ten_tape")


# ---- 4: the squeeze ---------------------------------------------------------------

func _duct() -> void:
	var m := Color(0.45, 0.46, 0.46)
	var h := 1.25
	# leg one: west from the bathroom, x -40 .. -53.45, narrowing. It turns south at the end.
	for sg in [[-40.0, -44.0, 0.9], [-44.0, -48.0, 0.86], [-48.0, -53.45, 0.82]]:   # (the player is 0.68 across)
		var xa: float = sg[0]
		var xb: float = sg[1]
		var w: float = sg[2]
		box(Vector3((xa + xb) * 0.5, -0.05, -9.0), Vector3(xa - xb, 0.1, 1.2), m, true, 0.0, "metal")
		box(Vector3((xa + xb) * 0.5, h + 0.05, -9.0), Vector3(xa - xb, 0.1, 1.2), m, true, 0.0, "metal")
		box(Vector3((xa + xb) * 0.5, h * 0.5, -9.0 + w * 0.5 + 0.05), Vector3(xa - xb, h, 0.1), m, true, 0.0, "metal")
		var xs := maxf(xb, -52.48)
		box(Vector3((xa + xs) * 0.5, h * 0.5, -9.0 - w * 0.5 - 0.05), Vector3(xa - xs, h, 0.1), m, true, 0.0, "metal")
	box(Vector3(-53.5, h * 0.5, -9.0), Vector3(0.1, h, 1.0), m, true, 0.0, "metal")
	# leg two: south, z -9 .. -24, narrower still
	for sg in [[-9.0, -15.0, 0.8], [-15.0, -24.0, 0.78]]:
		var za: float = sg[0]
		var zb: float = sg[1]
		var w: float = sg[2]
		box(Vector3(-53.0, -0.05, (za + zb) * 0.5), Vector3(1.2, 0.1, za - zb), m, true, 0.0, "metal")
		box(Vector3(-53.0, h + 0.05, (za + zb) * 0.5), Vector3(1.2, 0.1, za - zb), m, true, 0.0, "metal")
		var za2 := za - 0.53 if za > -9.5 else za
		box(Vector3(-53.0 - w * 0.5 - 0.05, h * 0.5, (za + zb) * 0.5), Vector3(0.1, h, za - zb), m, true, 0.0, "metal")
		box(Vector3(-53.0 + w * 0.5 + 0.05, h * 0.5, (za2 + zb) * 0.5), Vector3(0.1, h, za2 - zb), m, true, 0.0, "metal")
	# thin light through the slats, here and there
	for p in [Vector3(-43, h, -9), Vector3(-49, h, -9), Vector3(-53, h, -13), Vector3(-53, h, -19.5)]:
		part("box", p + Vector3(0, -0.01, 0), Vector3(0.5, 0.01, 0.06), Color(1.0, 0.85, 0.6), null, Vector3.ZERO, 3.0)
		omni(p + Vector3(0, -0.2, 0), Color(1.0, 0.8, 0.55), 0.25, 3.0, false)
	trigger(Vector3(-46.0, 0.6, -9.0), Vector3(1.0, 1.2, 1.0), func():
		Sfx.play("metal_screech", -10.0, 0.6)
		Game.player.dread.add_fear(5.0, "duct")
		Game.hud.show_thought("It's narrower. It's getting narrower.", 2.5))
	trigger(Vector3(-53.0, 0.6, -14.0), Vector3(1.0, 1.2, 1.0), func():
		Sfx.play("thud", -6.0, 0.5)
		Sfx.play("creak", -4.0, 0.7)
		Game.player.jolt(Vector3(-1, 0, 2))
		Game.hud.show_thought("Don't stop. Don't stop. If I stop I'll never--", 2.5))
	trigger(Vector3(-53.0, 0.6, -21.0), Vector3(1.0, 1.2, 1.0), func():
		Game.hud.show_thought("Light. Light ahead.", 2.0))


# ---- 5: the impossible stairwell -------------------------------------------------------

func _stairwell() -> void:
	var ang := rad_to_deg(atan2(1.6, 3.0))
	for k in range(-2, 3):
		var y := k * STOREY
		var col := CONCRETE.darkened(0.04 * absf(k))
		# landings
		box(Vector3(O.x, y - 0.1, O.z - 0.8), Vector3(4.2, 0.2, 1.6), col, true, 0.0, "concrete")
		box(Vector3(O.x, y + 1.5, O.z - 5.4), Vector3(4.2, 0.2, 1.6), col, true, 0.0, "concrete")
		# flights: A (west) up toward -Z, B (east) up toward +Z
		for i in 10:
			box(Vector3(O.x - 1.0, y + 0.08 + i * 0.16, O.z - 1.6 - 0.15 - i * 0.3), Vector3(2.0, 0.16, 0.3), col.lightened(0.04), false, 0.0, "concrete")
			box(Vector3(O.x + 1.0, y + 1.6 + 0.08 + i * 0.16, O.z - 4.6 + 0.15 + i * 0.3), Vector3(2.0, 0.16, 0.3), col.lightened(0.04), false, 0.0, "concrete")
		for f in [[-1.0, ang, 0.8], [1.0, -ang, 2.4]]:   # the sloped slab under each flight
			var sx: float = f[0]
			var sa: float = f[1]
			var sy: float = f[2]
			add_shape("box", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(sa)) * Basis.from_scale(Vector3(2.0, 0.14, 3.42)),
				Vector3(O.x + sx, y + sy - 0.2, O.z - 3.1)), col.darkened(0.2), false, "concrete")
		_ramp(Vector3(O.x - 1.0, y + 0.8 - 0.05, O.z - 3.1), Vector3(2.0, 0.1, 3.42), ang)
		_ramp(Vector3(O.x + 1.0, y + 2.4 - 0.05, O.z - 3.1), Vector3(2.0, 0.1, 3.42), -ang)
		# the divider, a handrail on it
		box(Vector3(O.x, y + 1.6, O.z - 3.1), Vector3(0.12, 3.2, 3.0), col.darkened(0.1), true, 0.0, "concrete")
		part("box", Vector3(O.x - 0.08, y + 1.75, O.z - 3.1), Vector3(0.04, 0.05, 3.4), Color(0.25, 0.3, 0.25), null, Vector3(-ang, 0, 0), 0.0, "metal")
		# walls
		var north_gaps := []
		var east_gaps := []
		if k == 0:
			north_gaps = [[1.1, 0.84, 1.25]]
			east_gaps = [[0.8, 1.0, 2.1]]
		_wall(Vector2(O.x - 2.1, O.z), Vector2(O.x + 2.1, O.z), STOREY, col, "concrete", north_gaps, y)
		_wall(Vector2(O.x + 2.1, O.z), Vector2(O.x + 2.1, O.z - 6.3), STOREY, col, "concrete", east_gaps, y)
		_wall(Vector2(O.x - 2.1, O.z), Vector2(O.x - 2.1, O.z - 6.3), STOREY, col, "concrete", [], y)
		_wall(Vector2(O.x - 2.1, O.z - 6.3), Vector2(O.x + 2.1, O.z - 6.3), STOREY, col, "concrete", [], y)
		if k != 0:
			for i in 6:
				part("box", Vector3(O.x - 1.0, y + 0.25 + i * 0.16, O.z - 0.07), Vector3(0.7, 0.04, 0.02), Color(0.5, 0.5, 0.48), null, Vector3.ZERO, 0.0, "metal")
		# floor number, painted on the wall
		var lb := label(Vector3(O.x + 0.9, y + 1.9, O.z - 0.08), 180, "", 0.45, Color(0.85, 0.82, 0.7), false)
		_labels[k] = lb
		label(Vector3(O.x + 2.03, y + 2.45, O.z - 0.8), -90, "ROOF ACCESS - FLOOR 7", 0.06, Color(0.85, 0.2, 0.15), false)
		# the door on this landing (only floor 7's opens)
		var d := door(Vector3(O.x + 2.04, y, O.z - 0.8), -90, Color(0.3, 0.33, 0.3), 0.95, 2.05, "metal")
		if k == 0:
			_exit_door = d
		var bl := _bulb(Vector3(O.x - 1.4, y + 3.0, O.z - 0.6), 0.6 if k != 1 else 0.25, 6.0)
		bl.shadow_enabled = k == 0
		if prop("window_frame", Vector3(O.x - 1.0, y + 1.5, O.z - 6.24), 0.0) == null:
			box(Vector3(O.x - 1.0, y + 1.5, O.z - 6.25), Vector3(1.0, 0.8, 0.02), Color(0.15, 0.15, 0.15), false)   # a dead window
	# capping slab and pit
	box(Vector3(O.x, 3 * STOREY + 0.1, O.z - 3.15), Vector3(4.4, 0.2, 6.5), CONCRETE, true, 0.0, "concrete")
	box(Vector3(O.x, -2 * STOREY - 0.3, O.z - 3.15), Vector3(4.4, 0.2, 6.5), CONCRETE, true, 0.0, "concrete")
	_exit_block = solid_box(Vector3(O.x + 2.1, 1.05, O.z - 0.8), Vector3(0.14, 2.1, 1.0), Color(0, 0, 0))
	_exit_block.get_child(1).visible = false
	interactable(Vector3(O.x + 1.85, 1.0, O.z - 0.8), Vector3(0.4, 2.0, 1.0), func(): return "Try the door" if _floor_num != EXIT_FLOOR else "",
		func():
			Sfx.play("knock", -6.0, 0.7)
			Game.hud.show_thought("Locked. \"ROOF ACCESS - FLOOR 7\". This is floor %d." % _floor_num, 3.0),
		func(): return _floor_num != EXIT_FLOOR)
	if Game.counters.has("floor"):
		_floor_num = int(Game.counters["floor"])     # (back from a checkpoint: the floor you'd got to)
	_update_labels()
	trigger(Vector3(O.x - 1.0, 0.8, O.z - 0.6), Vector3(1.0, 1.6, 1.0), func():
		Game.set_flag("ten_stairs")
		Game.counters["floor"] = _floor_num
		checkpoint_at("stairs")
		Sfx.stinger("braam", -8.0)
		Game.hud.show_thought("Stairs. Floor 4. The roof's from 7. ...Up, then.", 3.5))


func _update_labels() -> void:
	for k in _labels:
		var n: int = _floor_num if k >= 0 else _floor_num - k
		(_labels[k] as Label3D).text = str(n)
	Game.counters["floor"] = _floor_num


func _stair_loop() -> void:
	var pl: Player = Game.player
	var p := pl.global_position
	if absf(p.x - O.x) > 2.1 or p.z > O.z or p.z < O.z - 6.3:
		return
	var on_landing := p.z > O.z - 1.5
	if not on_landing:
		return
	if p.y > STOREY - 0.4:
		pl.global_position.y -= STOREY
		_ups += 1
		match _ups:
			1: Game.hud.show_thought("%d. ...I went up a whole flight. It still says %d." % [_floor_num, _floor_num], 3.5)
			2:
				Sfx.stinger("whisper", -8.0)
				Game.hud.show_thought("Same landing. Same crack in the wall. Up doesn't go up.", 3.5)
			4: Game.hud.show_hint("The stairs don't go where they go.\nTry the other way.", 6.0)
	elif p.y < -STOREY + 0.4:
		pl.global_position.y += STOREY
		_floor_num += 1
		_downs += 1
		_update_labels()
		Sfx.play("creak", -8.0, 0.6)
		match _floor_num:
			5: Game.hud.show_thought("5. I went DOWN. And it says 5.", 3.0)
			6:
				_obs_stage = 3
				Game.hud.show_thought("6. Down is up. Down is up.", 2.5)
			EXIT_FLOOR: _open_exit()
		if _floor_num > EXIT_FLOOR:
			# overshot: the building lets you back
			_floor_num = EXIT_FLOOR
			_update_labels()


func _open_exit() -> void:
	Game.set_flag("ten_floor7")
	checkpoint_at("floor7")
	Sfx.play("door_creak", -2.0, 0.8)
	Sfx.stinger("braam", -6.0)
	_exit_block.queue_free()
	open_door(_exit_door, 100.0, 2.0)     # swinging out into the corridor
	Game.hud.show_thought("7. ...The door's open.", 3.0)


# ---- 6: the collapse ----------------------------------------------------------------

func _corridor() -> void:
	var wall := Color(0.5, 0.48, 0.42)
	var n := ceili((CORR_X1 - CORR_X0) / 2.0)    # (rounding down left a hole in the floor at the end)
	for i in n:
		var x := CORR_X0 + 1.0 + i * 2.0
		box(Vector3(x, -0.1, CORR_Z), Vector3(2.0, 0.2, 2.4), Color(0.4, 0.3, 0.22), true, 0.0, "wood")
		var ceil := solid_box(Vector3(x, 2.6, CORR_Z), Vector3(2.02, 0.2, 2.4), PLASTER, null, "plaster")
		var wl := solid_box(Vector3(x, 1.3, CORR_Z - 1.1), Vector3(2.02, 2.6, 0.14), wall, null, "wallpaper")
		var wr := solid_box(Vector3(x, 1.3, CORR_Z + 1.1), Vector3(2.02, 2.6, 0.14), wall, null, "wallpaper")
		var light: OmniLight3D = null
		if i % 3 == 1:
			light = _bulb(Vector3(x, 2.35, CORR_Z), 0.5, 6.0)
		if i % 4 == 2:
			door(Vector3(x, 0, CORR_Z - 1.02), 0, Color(0.42, 0.3, 0.22), 0.92, 2.05, "wood")
		_segs.append([x, ceil, wl, wr, light, false])
	# at the far end, the way out: an exit sign that you can see from the door
	if prop("exit_sign", Vector3(CORR_X1 - 0.27, 2.45, CORR_Z), -90.0, 1.6) == null:
		part("box", Vector3(CORR_X1 - 0.3, 2.2, CORR_Z), Vector3(0.05, 0.22, 0.6), Color(0.2, 1.0, 0.4), null, Vector3.ZERO, 6.0)
	label(Vector3(CORR_X1 - 0.33, 2.2, CORR_Z), -90, "EXIT ↑", 0.12, Color(0.85, 1.0, 0.9), true)
	omni(Vector3(CORR_X1 - 0.6, 2.0, CORR_Z), Color(0.3, 1.0, 0.5), 0.8, 8.0, false)
	_dust = CPUParticles3D.new()
	_dust.amount = 160
	_dust.lifetime = 2.0
	_dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(1.0, 1.2, 1.0)
	_dust.direction = Vector3(1, 0.3, 0)
	_dust.spread = 50.0
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 2.5
	_dust.gravity = Vector3(0, -0.6, 0)
	_dust.scale_amount_min = 0.1
	_dust.scale_amount_max = 0.35
	var q := QuadMesh.new()
	var mm := StandardMaterial3D.new()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.billboard_keep_scale = true
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.3, 0.27, 0.22, 0.22)
	mm.albedo_texture = _soft_dot()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = mm
	_dust.mesh = q
	add_child(_dust)
	trigger(Vector3(CORR_X0 + 2.5, 1.2, CORR_Z), Vector3(1.0, 2.4, 2.2), func(): _begin_collapse())


func _begin_collapse() -> void:
	if Game.has_flag("ten_shaft"):
		return        # (it already came down, and you made it)
	_collapse = true
	_front = CORR_X0 - 1.0
	_front_speed = 2.7
	Game.set_flag("ten_collapse")
	Sfx.stinger("sub_drop", 2.0)
	Sfx.play("grind", 0.0, 0.5)
	Sfx.play("metal_screech", -2.0, 0.4)
	Game.player.jolt(Vector3(-5, 4, 3))
	Game.player.dread.add_fear(15.0, "collapse")
	Game.hud.show_thought("The whole building-- RUN. RUN!", 3.0)


func _update_collapse(delta: float) -> void:
	var pl: Player = Game.player
	_front_speed = minf(_front_speed + delta * 0.05, 3.3)
	_front += _front_speed * delta
	_dust.global_position = Vector3(_front, 1.2, CORR_Z)
	_dust.emitting = true
	for s in _segs:
		if s[5] or float(s[0]) > _front:
			continue
		s[5] = true
		var x: float = s[0]
		# the corridor folds up behind you: the ceiling drops, the walls come together
		var tw := create_tween().set_parallel(true)
		tw.tween_property(s[1], "position:y", 0.7 + randf() * 0.3, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s[1], "rotation_degrees:x", randf_range(-12, 12), 0.45)
		tw.tween_property(s[2], "position:z", CORR_Z - 0.35, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s[3], "position:z", CORR_Z + 0.35, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if s[4] != null:
			(s[4] as OmniLight3D).light_energy = 0.0
			Sfx.play("glitch", -14.0, 2.0)
		if randf() < 0.5:
			Sfx.play(["thud", "creak", "grind", "scrape"][randi() % 4], -4.0, randf_range(0.4, 0.8))
		if x + 4.0 > pl.global_position.x:
			pl.jolt(Vector3(randf_range(-2, 0), randf_range(-1, 1), randf_range(-1, 1)))
	if _front > pl.global_position.x - 0.3 and pl.global_position.x < CORR_X1:
		_collapse = false
		Game.entity_death("crush", null)
		return
	if pl.global_position.x > CORR_X1 - 0.5:
		_collapse = false
		_dust.emitting = false
		Game.set_flag("ten_shaft")
		checkpoint_at("shaft")
		Sfx.play("thud", 4.0, 0.4)
		Game.hud.show_thought("It stopped. ...It stopped at the door. Up. Go UP.", 3.0)


# ---- 7: the escape shaft -----------------------------------------------------------

func _shaft() -> void:
	var c := Vector3(CORR_X1 + 1.2, 0, CORR_Z)
	_room(CORR_X1, CORR_X1 + 2.4, CORR_Z - 1.2, CORR_Z + 1.2, 2.6, CONCRETE, "concrete", CONCRETE.darkened(0.2), "concrete", CONCRETE, {
		"w": [[1.2, 1.4, 2.4]],
	}, 0.0, false)
	for e in [[-0.95, 0.5, 2.4], [0.95, 0.5, 2.4]]:   # a ceiling with a hole in it
		box(c + Vector3(e[0], 2.7, 0), Vector3(e[1], 0.2, e[2]), CONCRETE, true, 0.0, "plaster")
	for e in [-0.95, 0.95]:
		box(c + Vector3(0, 2.7, e), Vector3(1.4, 0.2, 0.5), CONCRETE, true, 0.0, "plaster")
	# (the room's ceiling has a hole in it: the shaft. its walls go up and up and get closer.)
	for k in 7:
		var y := 2.6 + k * 2.0
		var w := 1.5 - k * 0.04
		for side in [-1.0, 1.0]:
			box(c + Vector3(side * (w * 0.5 + 0.06), y + 1.0, 0), Vector3(0.12, 2.0, w + 0.24), CONCRETE.darkened(0.1 + k * 0.03), true, 0.0, "concrete")
			box(c + Vector3(0, y + 1.0, side * (w * 0.5 + 0.06)), Vector3(w, 2.0, 0.12), CONCRETE.darkened(0.1 + k * 0.03), true, 0.0, "concrete")
	# the ladder
	if Models.find("props/wall_ladder") != "":
		for i in int(ceil(SHAFT_H / 1.2)):
			prop("wall_ladder", c + Vector3(0, i * 1.2, -0.68), 0.0, 0.9)
	else:
		for side in [-0.22, 0.22]:
			part("box", c + Vector3(side, SHAFT_H * 0.5, -0.6), Vector3(0.04, SHAFT_H + 0.4, 0.05), Color(0.35, 0.3, 0.25), null, Vector3.ZERO, 0.0, "metal")
		for i in int(SHAFT_H / 0.3):
			part("cylinder", c + Vector3(0, 0.3 + i * 0.3, -0.6), Vector3(0.025, 0.44, 0.025), Color(0.4, 0.33, 0.25), null, Vector3(0, 0, 90), 0.0, "metal")
	# the top: a little landing, a door, light all round its edges
	box(c + Vector3(0, SHAFT_H - 0.1, 0.15), Vector3(1.3, 0.2, 1.0), CONCRETE, true, 0.0, "concrete")
	box(c + Vector3(0, SHAFT_H + 2.6, 0), Vector3(1.6, 0.2, 1.6), CONCRETE, true, 0.0, "concrete")
	door(Vector3(c.x, SHAFT_H, c.z + 0.58), 180, Color(0.35, 0.36, 0.35), 0.9, 2.05, "metal")
	for e in [[0, 2.08, 1.0, 0.03], [-0.47, 1.02, 0.03, 2.05], [0.47, 1.02, 0.03, 2.05]]:
		part("box", Vector3(c.x + e[0], SHAFT_H + e[1], c.z + 0.62), Vector3(e[2], e[3], 0.01), Color(0.9, 0.95, 1.0), null, Vector3.ZERO, 8.0)
	omni(c + Vector3(0, SHAFT_H + 1.2, 0.3), Color(0.8, 0.9, 1.0), 0.8, 5.0, false)
	ambient("wind", c + Vector3(0, SHAFT_H + 1.0, 0.8), true, -10.0, 16.0)
	interactable(c + Vector3(0, 1.0, -0.45), Vector3(0.7, 2.0, 0.3), func(): return "Climb",
		func(): _climb(), func(): return not _climbing and Game.player.global_position.y < 2.0)
	interactable(Vector3(c.x, SHAFT_H + 1.0, c.z + 0.55), Vector3(0.9, 2.0, 0.3), func(): return "Open the door",
		func():
			_leaving = true
			Sfx.play("door_creak", -2.0, 0.9)
			Sfx.play("wind", 0.0)
			Game.hud.fade_to(1.0, 1.2, Color(0.85, 0.9, 1.0))
			await get_tree().create_timer(1.0, false).timeout
			Game.on_compression_exit(),
		func(): return not _leaving and Game.player.global_position.y > SHAFT_H - 1.0)
	trigger(Vector3(CORR_X1 + 1.2, 1.2, CORR_Z), Vector3(1.2, 2.4, 1.2), func():
		Game.hud.show_thought("A ladder. Up. A long way up.", 2.5))


func _climb() -> void:
	_climbing = true
	var t := Game._seq
	Game.in_sequence = true
	Game.set_mode("cinematic")
	var pl: Player = Game.player
	var c := Vector3(CORR_X1 + 1.2, 0, CORR_Z)
	pl.teleport(Transform3D(Basis(), c + Vector3(0, 0.05, -0.15)))
	pl.set_physics_process(false)
	var steps := 40
	for k in steps:
		var f := float(k + 1) / steps
		create_tween().tween_property(pl, "global_position:y", (SHAFT_H - 0.05) * f + 0.05, 0.2)
		pl._pitch = deg_to_rad(55.0) if k < 24 or k > 30 else deg_to_rad(-75.0)
		pl.head.rotation.x = pl._pitch
		if k % 3 == 0:
			Sfx.play("step_metal_%d" % (k % 4), -8.0, 1.4)
		if k == 12:
			Game.hud.show_thought("It's narrower up here. My shoulders are touching.", 2.5)
			Sfx.play("scrape", -6.0, 0.7)
		if k == 24:
			Sfx.play("grind", 0.0, 0.4)
			Sfx.stinger("sub_drop", -2.0)
			pl.jolt(Vector3(-3, 2, 2))
			Game.hud.show_thought("Don't look down--", 2.0)
		await get_tree().create_timer(0.2, false).timeout
		if t != Game._seq: return
	pl.set_physics_process(true)
	pl.teleport(Transform3D(Basis(), c + Vector3(0, SHAFT_H + 0.05, -0.1)))
	pl.rotation.y = PI
	Game.in_sequence = false
	Game.set_mode("game")
	_climbing = false
	Game.hud.show_thought("A door. Light, all round the edges. ...Wind?", 3.0)


# ------------------------------------------------------------------ the Observer

func _on_observer_seen() -> void:
	Game.player.dread.add_fear(10.0, "observer")
	Sfx.stinger("braam", -6.0)
	if _obs_stage == 2:
		Game.set_flag("observer_comp")
		Game.hud.show_thought("Him. The man from the park. In a child's bedroom.", 3.0)
	elif _obs_stage == 4:
		Game.hud.show_thought("He's on the stairs above me. Watching where I go.", 3.0)


func _update_observer() -> void:
	match _obs_stage:
		1:
			if observer.try_appear_at(Vector3(-36.4, 0, -12.4)):
				_obs_stage = 2
		3:
			if observer.try_appear_at(Vector3(O.x + 1.0, 1.6, O.z - 5.4)):
				_obs_stage = 4


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 1 if from_save else 0
	_collapse = false
	# back from a checkpoint: the vent cover's off, the floor count, floor 7's door
	if from_save:
		_floor_num = int(Game.counters.get("floor", _floor_num))
		_update_labels()
	if Game.has_flag("ten_vent") and is_instance_valid(_grille_block):
		_grille_block.queue_free()
		_grille.position = Vector3(-39.4, 0.05, -8.3)
		_grille.rotation_degrees = Vector3(80, 30, 0)
	if Game.has_flag("ten_floor7") and is_instance_valid(_exit_block):
		_exit_block.queue_free()
		open_door(_exit_door, 100.0, 0.01)
	Game.counters["floor"] = _floor_num


func _process(delta: float) -> void:
	_t += delta
	var pl: Player = Game.player
	if pl == null:
		return
	if _tv:
		var v := randf_range(0.5, 1.0)
		(_tv.material_override as StandardMaterial3D).emission_energy_multiplier = 1.0 + v * 2.0
	if Game.in_sequence:
		return
	_update_observer()
	_stair_loop()
	if _collapse:
		_update_collapse(delta)
	# the building settles around you
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(9.0, 22.0)
		Sfx.play(["creak", "door_creak", "knock", "scrape"][randi() % 4], randf_range(-22.0, -14.0), randf_range(0.5, 0.9))
	# you are in the squeeze
	if pl.global_position.x < -40.2 and pl.global_position.z > -24.0 and pl.global_position.y < 1.4:
		pl.dread.add_fear(2.0 * delta, "squeeze")
		if _duct_pops < 3 and randf() < delta * 0.15:
			_duct_pops += 1
			Sfx.play("metal_screech", -14.0, randf_range(1.3, 1.8))
	if _hint == 0 and _t > 4.0:
		_hint = 1
		Game.hud.show_thought("Third floor. Apartments. Nobody's home. Somebody's always home.", 3.5)
