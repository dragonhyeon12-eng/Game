class_name StillLifeZone
extends Zone
## STILL LIFE - automatonophobia. The Emporium, a department store after closing: three floors under
## flickering panels, and the music still playing for nobody. The mannequins never move while you can see them.
##
##  1 Level 1        the doors lock behind you. The directory says the staff exit is on Level 3; the escalators
##                   are shut behind grilles. The keys are on the security guard - who is a mannequin, at a desk.
##                   Take them, and the display mannequins step down off their stands.
##  2 Level 2        homeware. THE PERFECT FAMILY at dinner: three of them at the table, and an empty chair
##                   with a place card. The way up is shut until you sit with them.
##  3 Level 3        LIFELIKE: figures, each more real than the last - then people you know - then an empty
##                   plinth with your card on it. The lights fail behind you, a section at a time, and in the
##                   dark they don't have to wait for you to look away. The staff exit.

const W := 20.0           # half-width (x)
const D := -40.0          # back wall (z)
const STOREY := 5.0
const CEIL := 4.4
const ESC_A := Vector3(0, 0, -14.0)         # Level 1 -> 2 (bottom), climbing toward -z
const ESC_B := Vector3(6.0, STOREY, -26.0)  # Level 2 -> 3 (bottom), climbing toward +z
const ESC_RUN := 8.66                       # 30 degrees, 5 m up
const EXIT := Vector3(0, 2.0 * STOREY, D + 0.3)      # (at floor level)
const SEAT := Vector3(-8.6, STOREY, -29.4)

const WALL := Color(0.86, 0.84, 0.8)
const FLOOR := Color(0.78, 0.77, 0.74)
const TRIM := Color(0.3, 0.28, 0.26)

var observer: Observer
var _figures: Array[Mannequin] = []      # all of them
var _grille_a: StaticBody3D
var _grille_b: StaticBody3D
var _office_door: Node3D
var _office_block: StaticBody3D
var _keys: Node3D
var _family: Array[Mannequin] = []
var _sections: Array = []                # Level 3 light sections: {z, lights: [...], panels: [...], on}
var _panel_lights: Array = []            # [OmniLight3D, base]
var _climax_t := -1.0
var _t := 0.0
var _hint := 0
var _creak_t := 0.0
var _obs_t := 30.0
var _seated := false


func zone_id() -> String: return "stilllife"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 10.0
func fear_decay() -> float: return 1.5
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.6
func sprint_speed() -> float: return 4.2


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, -2.2))


# ------------------------------------------------------------------ build

func build() -> void:
	_shell()
	for lv in 3:
		_ceiling_lights(lv)
	_escalator(ESC_A, -1.0, "a")
	_escalator(ESC_B, 1.0, "b")
	_level1()
	_level2()
	_level3()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen_max_distance = 50.0
	observer.seen.connect(func():
		Game.set_flag("observer_store")
		Game.player.dread.add_dread(observer.spot_dread))
	observer.vanished.connect(func(): _obs_t = randf_range(30.0, 60.0))
	var env := make_env(Color(0.75, 0.75, 0.8), 0.12)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.1, 0.11)
	env.fog_density = 0.012
	environment(env)
	ambient("hum", Vector3(0, 3.5, -20), true, -12.0, 30.0)
	ambient("hum", Vector3(0, 8.5, -20), true, -12.0, 30.0)
	ambient("room_tone", Vector3.ZERO, false, -12.0)


func _shell() -> void:
	var tall := STOREY * 3.0
	box(Vector3(0, -0.1, D * 0.5), Vector3(W * 2 + 1, 0.2, -D + 1), FLOOR, true, 0.0, "tiles_floor")
	box(Vector3(0, tall + 0.1, D * 0.5), Vector3(W * 2 + 1, 0.2, -D + 1), TRIM, true, 0.0, "concrete")
	for s in [-1.0, 1.0]:
		box(Vector3(s * (W + 0.2), tall * 0.5, D * 0.5), Vector3(0.4, tall, -D + 1), WALL, true, 0.0, "plaster")
	box(Vector3(0, tall * 0.5, D - 0.2), Vector3(W * 2 + 1, tall, 0.4), WALL, true, 0.0, "plaster")
	# the front: glass doors (locked), a glass wall onto the dark street
	for s in [-1.0, 1.0]:
		box(Vector3(s * (W + 2.5) * 0.5, STOREY * 0.5, 0.2), Vector3(W - 2.5, STOREY, 0.2), Color(0.3, 0.35, 0.38), true, 0.0, "glass")
	box(Vector3(0, STOREY * 0.5 + 1.2, 0.2), Vector3(5, STOREY - 2.4, 0.2), Color(0.3, 0.35, 0.38), true, 0.0, "glass")
	box(Vector3(0, 1.2, 0.25), Vector3(5, 2.4, 0.12), Color(0.25, 0.3, 0.32), true, 0.0, "glass")
	box(Vector3(0, tall * 0.5 + STOREY * 0.5, 0.2), Vector3(W * 2 + 1, tall - STOREY, 0.4), WALL, true, 0.0, "plaster")
	label(Vector3(0, 2.6, 0.05), 180, "PUSH", 0.08, Color(0.8, 0.8, 0.8), false)
	label(Vector3(0, 4.3, -0.05), 0, "THE EMPORIUM", 0.3, Color(0.85, 0.7, 0.4), true)
	# Level 2 and 3 floors, with the escalator wells cut out
	_slab(STOREY, [[-1.8, 1.8, ESC_A.z - ESC_RUN - 0.05, ESC_A.z + 0.5]])
	_slab(STOREY * 2.0, [[ESC_B.x - 1.8, ESC_B.x + 1.8, ESC_B.z - 0.5, ESC_B.z + ESC_RUN + 0.05]])
	# railings round the wells
	_rail(Vector3(-1.85, STOREY, ESC_A.z + 0.5), Vector3(-1.85, STOREY, ESC_A.z - ESC_RUN))
	_rail(Vector3(1.85, STOREY, ESC_A.z + 0.5), Vector3(1.85, STOREY, ESC_A.z - ESC_RUN))
	_rail(Vector3(-1.85, STOREY, ESC_A.z + 0.5), Vector3(1.85, STOREY, ESC_A.z + 0.5))
	_rail(Vector3(ESC_B.x - 1.85, STOREY * 2, ESC_B.z - 0.5), Vector3(ESC_B.x - 1.85, STOREY * 2, ESC_B.z + ESC_RUN))
	_rail(Vector3(ESC_B.x + 1.85, STOREY * 2, ESC_B.z - 0.5), Vector3(ESC_B.x + 1.85, STOREY * 2, ESC_B.z + ESC_RUN))
	_rail(Vector3(ESC_B.x - 1.85, STOREY * 2, ESC_B.z - 0.5), Vector3(ESC_B.x + 1.85, STOREY * 2, ESC_B.z - 0.5))
	for lv in 3:
		label(Vector3(-W + 0.05, 3.6 + lv * STOREY, -6), 90, "LEVEL %d" % (lv + 1), 0.25, Color(0.3, 0.28, 0.25), false)


## A floor at height y, the whole store, minus holes [[x0, x1, z0, z1], ...] (one hole: split into four slabs).
func _slab(y: float, holes: Array) -> void:
	var h: Array = holes[0]
	var x0: float = h[0]
	var x1: float = h[1]
	var z0: float = h[2]
	var z1: float = h[3]
	var t := 0.3
	var mk := func(xa: float, xb: float, za: float, zb: float):
		if xb - xa > 0.01 and zb - za > 0.01:
			box(Vector3((xa + xb) * 0.5, y - t * 0.5, (za + zb) * 0.5), Vector3(xb - xa, t, zb - za), FLOOR, true, 0.0, "tiles_floor")
	mk.call(-W, x0, D, 0.0)
	mk.call(x1, W, D, 0.0)
	mk.call(x0, x1, D, z0)
	mk.call(x0, x1, z1, 0.0)


func _rail(a: Vector3, b: Vector3) -> void:
	var c := (a + b) * 0.5
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var ln := (b - a).length()
	box(c + Vector3(0, 0.5, 0), Vector3(ln, 1.0, 0.06) if along_x else Vector3(0.06, 1.0, ln), Color(0.6, 0.7, 0.72), true, 0.0, "glass")
	box(c + Vector3(0, 1.02, 0), Vector3(ln, 0.06, 0.08) if along_x else Vector3(0.08, 0.06, ln), TRIM, false, 0.0, "metal")


## A stopped escalator from `bottom`, climbing 5 m along z (dir -1 or +1). An invisible ramp under the steps.
func _escalator(bottom: Vector3, dir: float, id: String) -> void:
	var top := bottom + Vector3(0, STOREY, dir * ESC_RUN)
	var mid := (bottom + top) * 0.5
	var length := Vector3(0, STOREY, ESC_RUN).length()
	var ramp := StaticBody3D.new()
	ramp.position = mid
	ramp.rotation_degrees.x = 30.0 * -dir
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 0.1, length + 0.4)
	cs.shape = bs
	cs.position.y = -0.05
	ramp.add_child(cs)
	add_child(ramp)
	# the steps (just to look at), the sides, the handrails
	var steps := 24
	for k in steps:
		var f := (k + 0.5) / steps
		var p := bottom.lerp(top, f)
		part("box", p + Vector3(0, -0.1, 0), Vector3(1.3, 0.2, ESC_RUN / steps + 0.02), Color(0.3, 0.3, 0.32), null, Vector3.ZERO, 0.0, "metal")
	for s in [-1.0, 1.0]:
		var side := solid_box(mid + Vector3(s * 0.8, 0.5, 0), Vector3(0.12, 1.0, length + 0.4), Color(0.65, 0.68, 0.7), null, "metal")
		side.rotation_degrees.x = 30.0 * -dir
		part("box", mid + Vector3(s * 0.8, 1.05, 0), Vector3(0.1, 0.08, length), Color(0.08, 0.08, 0.08), null, Vector3(30.0 * -dir, 0, 0))
	# the grille across the bottom
	var g := solid_box(bottom + Vector3(0, 1.3, -dir * 0.6), Vector3(1.9, 2.6, 0.06), Color(0.4, 0.42, 0.44), null, "metal")
	(g.get_child(1) as MeshInstance3D).transparency = 0.35
	for k in 9:
		part("box", Vector3(-0.8 + k * 0.2, 0, 0), Vector3(0.03, 2.6, 0.04), Color(0.25, 0.25, 0.27), g, Vector3.ZERO, 0.0, "metal").position = Vector3(-0.8 + k * 0.2, 0, 0.04)
	label(bottom + Vector3(0, 2.0, -dir * 0.55), 0.0 if dir > 0 else 180.0, "ESCALATOR CLOSED\nPLEASE SEE A MEMBER OF STAFF", 0.06, Color(0.9, 0.2, 0.15), false)
	if id == "a":
		_grille_a = g
		interactable(bottom + Vector3(0, 1.2, -dir * 0.9), Vector3(2.0, 2.0, 0.6),
			func(): return "Unlock the grille" if Game.has_flag("sl_key") else "Escalator grille",
			func(): _open_grille_a(), func(): return _grille_a != null)
	else:
		_grille_b = g
		interactable(bottom + Vector3(0, 1.2, -dir * 0.9), Vector3(2.0, 2.0, 0.6), func(): return "Escalator grille",
			func(): Game.hud.show_thought("Locked. No keyhole on this one. ...It opens from somewhere else.", 3.0),
			func(): return _grille_b != null)


func _lift_grille(g: StaticBody3D) -> void:
	Sfx.play_at("grind", self, g.global_position, -4.0, 20.0)
	var tw := create_tween()
	tw.tween_property(g, "position:y", g.position.y + 2.6, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(g.queue_free)


func _open_grille_a() -> void:
	if not Game.has_flag("sl_key"):
		Game.hud.show_thought("Locked. 'Please see a member of staff.' ...Security might have a key.", 3.0)
		return
	_lift_grille(_grille_a)
	_grille_a = null
	Game.set_flag("sl_escalator")


func _ceiling_lights(lv: int) -> void:
	var y := lv * STOREY + CEIL
	if lv == 2:
		box(Vector3(0, y + 0.06, D * 0.5), Vector3(W * 2, 0.02, -D), Color(0.8, 0.8, 0.78), false, 0.0, "tiles_ceiling")
	for z in [-6.0, -18.0, -30.0]:
		for x in [-12.0, 0.0, 12.0]:
			if lv < 2 and x == 0.0 and z == -18.0:
				continue
			var panel := part("box", Vector3(x, y, z), Vector3(3.0, 0.05, 0.6), Color(0.95, 0.97, 1.0), null, Vector3.ZERO, 2.5)
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if x == 0.0 or lv == 2:
				var l := omni(Vector3(x, y - 0.4, z), Color(0.95, 0.97, 1.0), 1.1, 13.0, false)
				_panel_lights.append([l, 1.1])
				if lv == 2:
					_section_add(z, l, panel)
			elif lv == 2:
				_section_add(z, null, panel)


func _section_add(z: float, l: OmniLight3D, panel: MeshInstance3D) -> void:
	for s in _sections:
		if s.z == z:
			if l: s.lights.append(l)
			s.panels.append(panel)
			return
	_sections.append({"z": z, "lights": [l] if l else [], "panels": [panel], "on": true})


# ------------------------------------------------------------------ mannequins

func _mannequin(pos: Vector3, yaw: float, pose: String, stand := true, realism := 0, col := Color(0.9, 0.86, 0.8)) -> Mannequin:
	var m := Mannequin.new()
	add_child(m)
	m.pose = pose
	m.build(col, realism)
	m.position = pos
	m.rotation_degrees.y = yaw
	m.home = pos
	m.level_y = floorf((pos.y + 0.5) / STOREY) * STOREY
	if stand:
		# a round plinth and a pole up into its back; when it walks off, the plinth stays
		shape_at("cylinder", Vector3(pos.x, m.level_y + 0.06, pos.z), Vector3(0.7, 0.12, 0.7), TRIM, true, Vector3.ZERO, "metal")
		m.position.y = m.level_y + 0.12
	_figures.append(m)
	return m


## Every one you can't see, steps. Hunting ones step toward you; the rest only change.
func _update_figures(delta: float, p: Vector3) -> void:
	var pl: Player = Game.player
	var on_level := floorf((p.y + 0.5) / STOREY) * STOREY
	_creak_t -= delta
	for m in _figures:
		if not m.visible:
			continue
		var head := m.head_position()
		var seen := Observation.is_observed(head + Vector3(0, -0.5, 0), 0.6) and _lit_at(m.global_position)
		if seen:
			m.unseen_t = 0.0
			continue
		m.unseen_t += delta
		if not m.hunting:
			# the idle ones: a new pose, a turn of the head, when you've looked away a while
			if m.unseen_t > 3.0 and randf() < delta * 0.25 and m.global_position.distance_to(p) < 18.0:
				m.unseen_t = 0.0
				m.set_pose(["stand", "hip", "wave", "point"].pick_random())
				m.face_toward(p)
			continue
		if absf(m.level_y - on_level) > 0.5:
			continue
		m.step_t -= delta
		if m.step_t > 0.0:
			continue
		if m.unseen_t < 0.3:
			continue        # (a glance away isn't enough)
		m.step_t = 0.3
		var to := p - m.global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.95:
			Game.entity_death("mannequin", m)
			return
		var dir := to / d
		var step := minf(0.38, d - 0.7)
		var target := m.global_position + _clear_step(m.global_position, dir, step)
		target.y = m.level_y
		m.global_position = target
		m.face_toward(p)
		m.set_pose("reach" if d > 3.0 else "lunge")
		if _creak_t <= 0.0 and d < 12.0:
			_creak_t = randf_range(0.6, 1.4)
			Sfx.play_at("creak", self, m.global_position + Vector3(0, 1.0, 0), -8.0, 14.0)


## A step from `from` along `dir`, turning aside if something's in the way.
func _clear_step(from: Vector3, dir: Vector3, step: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	for a in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var d := dir.rotated(Vector3.UP, a)
		var o := from + Vector3(0, 0.9, 0)
		var q := PhysicsRayQueryParameters3D.create(o, o + d * (step + 0.3), 1)
		q.exclude = [Game.player.get_rid()]
		if space.intersect_ray(q).is_empty():
			return d * step
	return Vector3.ZERO


func _lit_at(pos: Vector3) -> bool:
	if pos.y < STOREY * 2.0 - 0.5:
		return true
	for s in _sections:
		if absf(pos.z - s.z) < 6.0:
			return s.on
	return true


# ------------------------------------------------------------------ Level 1

func _level1() -> void:
	# the directory by the doors
	var dir_at := Vector3(-3.5, 0, -2.0)
	box(dir_at + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.1), Color(0.15, 0.15, 0.17), true, 0.0, "metal")
	label(dir_at + Vector3(0, 1.4, 0.06), 0, "STORE DIRECTORY\n\nLEVEL 1  BEAUTY . SECURITY\nLEVEL 2  HOME\nLEVEL 3  LIFELIKE\n           STAFF EXIT", 0.045, Color(0.9, 0.85, 0.7), true)
	interactable(dir_at + Vector3(0, 1.2, 0.3), Vector3(1.0, 1.4, 0.5), func(): return "Read the directory",
		func():
			Game.set_flag("sl_directory")
			Game.hud.show_thought("Staff exit: Level 3. The doors I came in by won't open. ...Three floors, then.", 4.0))
	# beauty counters: glass and light, rows of little bottles
	for k in 4:
		var cx := -12.0 + (k % 2) * 6.0
		var cz := -8.0 - floorf(k / 2.0) * 9.0
		box(Vector3(cx, 0.5, cz), Vector3(3.6, 1.0, 1.0), Color(0.95, 0.94, 0.92), true, 0.0, "plaster")
		box(Vector3(cx, 1.05, cz), Vector3(3.6, 0.1, 1.0), Color(0.6, 0.7, 0.75), false, 0.0, "glass")
		for b in 6:
			part("cylinder", Vector3(cx - 1.4 + b * 0.55, 1.18, cz), Vector3(0.12, 0.2, 0.12), Color.from_hsv(randf(), 0.4, 0.9), null, Vector3.ZERO, 0.3, 0.1)
	# clothing rails
	for spec in [[Vector3(-14, 0, -30), 0.0], [Vector3(-8, 0, -36), 90.0], [Vector3(6, 0, -9), 0.0], [Vector3(6, 0, -30), 90.0], [Vector3(-14, 0, -14), 90.0]]:
		_rack(spec[0], spec[1])
	# the display mannequins (they hunt, once you've taken the keys)
	var l1 := [[Vector3(-7.0, 0, -4.5), 160.0, "hip"], [Vector3(9.0, 0, -6.0), 200.0, "wave"], [Vector3(-15.0, 0, -22.0), 90.0, "point"],
		[Vector3(10.0, 0, -20.0), -60.0, "stand"], [Vector3(-5.0, 0, -30.0), 30.0, "hip"]]
	for k in l1.size():
		var m := _mannequin(l1[k][0], l1[k][1], l1[k][2])
		if k != 2 and k != 4:
			m.set_meta("wakes", "sl_key")
	# the security office: east, behind a door marked STAFF ONLY
	var ox := 14.0
	_wall_x(ox, -28.0, -38.0, [[-33.0, 1.0]], 3.0, WALL)
	box(Vector3(17, 1.5, -28.0), Vector3(6, 3.0, 0.2), WALL, true, 0.0, "plaster")
	box(Vector3(17, 1.5, -38.0), Vector3(6, 3.0, 0.2), WALL, true, 0.0, "plaster")
	box(Vector3(17, 3.05, -33), Vector3(6, 0.1, 10), WALL, true, 0.0, "plaster")
	label(Vector3(13.88, 2.3, -33.0), -90, "SECURITY\nSTAFF ONLY", 0.06, Color(0.2, 0.2, 0.2), false)
	_office_door = door(Vector3(ox, 0, -33.0), -90, Color(0.4, 0.42, 0.45), 0.95, 2.05, "metal")
	open_door(_office_door, -70.0, 0.01)
	# the guard: behind the desk, facing the door, in a cap, the keys on the desk by its hand
	box(Vector3(16.4, 0.4, -33.0), Vector3(0.9, 0.8, 2.2), Color(0.35, 0.3, 0.25), true, 0.0, "wood")
	for k in 3:
		part("box", Vector3(19.6, 1.3, -31.6 - k * 1.2), Vector3(0.4, 0.45, 0.6), Color(0.08, 0.1, 0.1), null, Vector3.ZERO, 0.5, 0.1)
	box(Vector3(19.6, 0.5, -32.8), Vector3(0.7, 1.0, 3.8), Color(0.3, 0.3, 0.32), true, 0.0, "metal")
	var guard := _mannequin(Vector3(17.5, 0, -33.0), -90.0, "sit", false)
	part("cylinder", Vector3(0, 0.47, 0.0), Vector3(0.24, 0.06, 0.24), Color(0.12, 0.13, 0.2), guard._neck)
	part("box", Vector3(0, 0.45, 0.12), Vector3(0.2, 0.02, 0.12), Color(0.08, 0.08, 0.1), guard._neck)
	guard.set_meta("wakes", "sl_lights3")     # it stays at its desk until the very end
	_keys = group(Vector3(16.3, 0.83, -32.5))
	part("sphere", Vector3.ZERO, Vector3(0.08, 0.02, 0.08), Color(0.7, 0.68, 0.6), _keys, Vector3.ZERO, 0.0, "metal")
	for k in 3:
		part("box", Vector3(0.03 * k - 0.03, 0.0, 0.07), Vector3(0.015, 0.005, 0.08), Color(0.75, 0.7, 0.45), _keys, Vector3(0, -20 + k * 20, 0), 0.0, "metal")
	interactable(Vector3(16.3, 0.9, -32.5), Vector3(0.6, 0.5, 0.6), func(): return "Take the keys",
		func():
			_keys.visible = false
			Game.set_flag("sl_key")
			Sfx.play("page", -4.0, 1.4)
			Game.player.dread.add_fear(6.0, "keys")
			Game.hud.show_thought("Sorry. Sorry. I'll bring them back. ...Behind me - did something just step down?", 4.0)
			_wake("sl_key"),
		func(): return _keys.visible)
	trigger(Vector3(16, 1.2, -33), Vector3(3, 2.4, 4), func():
		Game.set_flag("sl_office")
		Game.hud.show_thought("A guard. ...No. It's one of them. Somebody sat it at the desk and put a cap on it.", 4.0))
	trigger(Vector3(0, 1.2, -10.5), Vector3(4, 2.4, 2), func():
		if not Game.has_flag("sl_key"):
			Game.hud.show_thought("The escalators are behind grilles. 'Please see a member of staff.'", 3.5))


func _rack(at: Vector3, yaw: float) -> void:
	var g := group(at, yaw)
	for sx in [-1.2, 1.2]:
		part("cylinder", Vector3(sx, 0.75, 0), Vector3(0.04, 1.5, 0.04), Color(0.7, 0.7, 0.72), g, Vector3.ZERO, 0.0, "metal")
	part("cylinder", Vector3(0, 1.5, 0), Vector3(0.03, 2.4, 0.03), Color(0.7, 0.7, 0.72), g, Vector3(0, 0, 90), 0.0, "metal")
	var hue := randf()
	for k in 11:
		part("box", Vector3(-1.0 + k * 0.2, 1.05, 0), Vector3(0.04, 0.85, 0.5), Color.from_hsv(fmod(hue + k * 0.03, 1.0), 0.45, 0.6), g, Vector3(0, randf_range(-8, 8), 0), 0.0, "fabric")
	blocker(at + Vector3(0, 0.75, 0), Vector3(2.6, 1.5, 0.6) if absf(yaw) < 1.0 else Vector3(0.6, 1.5, 2.6))


func _wall_x(x: float, z0: float, z1: float, gaps: Array, h: float, col: Color) -> void:
	var lo := minf(z0, z1)
	var hi := maxf(z0, z1)
	var cuts := [lo]
	for g in gaps:
		cuts.append(g[0] - g[1] * 0.5 - 0.05)
		cuts.append(g[0] + g[1] * 0.5 + 0.05)
	cuts.append(hi)
	cuts.sort()
	for i in range(0, cuts.size(), 2):
		box(Vector3(x, h * 0.5, (cuts[i] + cuts[i + 1]) * 0.5), Vector3(0.2, h, cuts[i + 1] - cuts[i]), col, true, 0.0, "plaster")
	for g in gaps:
		box(Vector3(x, h - 0.4, g[0]), Vector3(0.2, 0.8, g[1] + 0.1), col, true, 0.0, "plaster")


func _wake(flag: String) -> void:
	for m in _figures:
		if m.get_meta("wakes", "") == flag:
			m.hunting = true


# ------------------------------------------------------------------ Level 2

func _level2() -> void:
	var y := STOREY
	# showroom: sofas, armchairs, rugs, lamps
	for spec in [[Vector3(-13, y, -8), 0.0], [Vector3(12, y, -10), 90.0], [Vector3(13, y, -33), 180.0]]:
		var c: Vector3 = spec[0]
		box(c + Vector3(0, 0.25, 0), Vector3(4.0, 0.3, 4.0), Color(0.5, 0.35, 0.3), false, spec[1], "fabric")
		box(c + Vector3(0, 0.45, -0.8), Vector3(2.4, 0.5, 0.9), Color(0.55, 0.5, 0.45), true, spec[1], "fabric")
		box(c + Vector3(0, 0.85, -1.2), Vector3(2.4, 0.5, 0.2), Color(0.5, 0.45, 0.4), true, spec[1], "fabric")
		box(c + Vector3(0, 0.25, 0.6), Vector3(1.2, 0.5, 0.6), Color(0.4, 0.3, 0.2), true, spec[1], "wood")
	label(Vector3(0, y + 3.4, -1.0), 180, "HOME", 0.3, Color(0.3, 0.28, 0.25), false)
	# one of the "armchairs" is a mannequin, folded up
	_mannequin(Vector3(-15.5, y, -9.5), 40.0, "crouch", false).set_meta("wakes", "sl_family")
	# THE PERFECT FAMILY
	var t := Vector3(-10.0, y, -30.0)
	box(t + Vector3(0, 0.75, 0), Vector3(1.2, 0.06, 2.4), Color(0.45, 0.3, 0.2), true, 0.0, "wood")
	box(t + Vector3(0, 0.37, 0), Vector3(0.2, 0.74, 0.2), Color(0.35, 0.25, 0.15), false, 0.0, "wood")
	for k in 4:
		var plate := t + Vector3(0, 0.79, -0.9 + k * 0.6)
		shape_at("cylinder", plate, Vector3(0.28, 0.02, 0.28), Color(0.95, 0.95, 0.92))
	for k in 3:
		part("sphere", t + Vector3(0.0, 0.85, -0.9 + k * 0.6), Vector3(0.12, 0.08, 0.12), Color(0.45, 0.3, 0.15))   # plastic food
	label(t + Vector3(0, 2.4, -1.5), 90, "THE PERFECT FAMILY", 0.14, Color(0.6, 0.15, 0.12), false)
	# chairs: three taken, the fourth (nearest the aisle) empty
	var seats := [[t + Vector3(-1.4, 0, -0.6), 90.0, 1.0], [t + Vector3(-1.4, 0, 0.6), 90.0, 0.65], [t + Vector3(1.4, 0, -0.6), -90.0, 0.95]]
	for s in seats:
		_chair(s[0], s[1])
		var m := _mannequin(s[0] + Vector3(0, 0, 0), s[1], "sit", false, 1)
		m.scale = Vector3.ONE * s[2]
		m.set_meta("wakes", "sl_family")
		_family.append(m)
	_chair(SEAT, -90.0)
	label(SEAT + Vector3(-0.55, 0.82, 0), -90, "~ YOU ~", 0.06, Color(0.2, 0.15, 0.1), false)
	interactable(SEAT + Vector3(0, 0.7, 0), Vector3(0.9, 1.0, 0.9), func(): return "Sit down" if not Game.has_flag("sl_family") else "",
		func(): _sit(), func(): return not Game.has_flag("sl_family"))
	trigger(Vector3(-8, y + 1.2, -25), Vector3(8, 2.4, 3), func():
		Game.hud.show_thought("A family at dinner. They've laid a place for one more. ...There's a card on the empty chair.", 4.0))
	trigger(Vector3(0, y + 1.2, -23.4), Vector3(4, 2.4, 2.4), func():
		Game.set_flag("sl_level2")
		Game.hud.show_thought("Level 2. The next escalator's shut as well. Of course it is.", 3.0))


func _chair(at: Vector3, yaw: float) -> void:
	box(at + Vector3(0, 0.45, 0), Vector3(0.5, 0.06, 0.5), Color(0.5, 0.35, 0.22), true, yaw, "wood")
	var back := at + Vector3(0, 0.75, 0) + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -0.24)
	box(back, Vector3(0.5, 0.6, 0.05), Color(0.5, 0.35, 0.22), false, yaw, "wood")


func _sit() -> void:
	if _seated:
		return
	_seated = true
	Game.in_sequence = true
	Game.set_mode("cinematic")
	var pl: Player = Game.player
	var t := Game._seq
	pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), SEAT + Vector3(0.05, -0.35, 0)))
	pl._set_crouch(true)
	Game.look_toward(SEAT + Vector3(-1.6, 0.9, -0.3), 0.6)
	Sfx.play("creak", -4.0, 0.9)
	await get_tree().create_timer(1.5, false).timeout
	if t != Game._seq: return
	# the lights go, for a moment
	for l in _panel_lights:
		l[0].visible = false
	Sfx.play("switch", 0.0, 0.7)
	Sfx.play("horror_swell", -2.0)
	Sfx.stop_music(0.05)
	await get_tree().create_timer(1.6, false).timeout
	if t != Game._seq: return
	for m in _family:
		m.face_toward(SEAT)
		m.set_pose("sit")
		m._neck.rotation_degrees = Vector3(10, 0, 0)
	for l in _panel_lights:
		l[0].visible = true
	Sfx.play("switch", -2.0, 0.9)
	Sfx.stinger("hit", -2.0)
	Game.player.dread.add_fear(12.0, "family")
	Game.hud.show_thought("They're all looking at me. They weren't looking at me.", 3.0)
	await get_tree().create_timer(2.0, false).timeout
	if t != Game._seq: return
	Sfx.play("chime", -4.0, 0.6)
	Game.set_flag("sl_family")
	_lift_grille(_grille_b)
	_grille_b = null
	Game.hud.show_thought("...Somewhere behind me, a grille going up. Thank you for having me. I have to go.", 4.0)
	Sfx.play_music("muzak", 1.0)
	pl._set_crouch(false)
	Game.in_sequence = false
	Game.set_mode("game")
	# they'll be up from the table the moment you stop looking
	_wake("sl_family")


# ------------------------------------------------------------------ Level 3

func _level3() -> void:
	var y := STOREY * 2.0
	label(Vector3(0, y + 3.4, -1.0), 180, "LIFELIKE", 0.3, Color(0.5, 0.12, 0.1), false)
	# the studies: plinths in two rows down to the exit, each figure more real than the last
	var rows := [-9.0, 9.0]
	var placards := ["STUDY No. 1", "STUDY No. 2", "STUDY No. 3", "STUDY No. 4"]
	for k in 4:
		var at := Vector3(rows[k % 2] * 0.5, y, -6.0 - k * 3.0)
		var m := _mannequin(at, 180.0 if k % 2 == 0 else 160.0, ["stand", "hip", "point", "stand"][k], true, mini(k, 2))
		m.set_meta("wakes", "sl_lights3")
		label(at + Vector3(0, 0.3, 0.75), 0, placards[k], 0.05, Color(0.2, 0.2, 0.2), false)
	# then people. people you've met. frozen on plinths under spotlights.
	var people := [
		["mina", "MINA  (ice cream)", {"skin": Color(0.86, 0.64, 0.5), "hair": Color(0.32, 0.16, 0.07), "shirt": Color(0.95, 0.55, 0.62),
			"pants": Color(0.2, 0.25, 0.42), "apron": true, "cap": true, "cap_color": Color(0.98, 0.98, 0.95), "height": 0.95, "hair_style": "bun", "build": 0.92}],
		["halvorsen", "MR. HALVORSEN  (pigeons)", {"skin": Color(0.84, 0.68, 0.58), "hair": Color(0.78, 0.78, 0.76), "shirt": Color(0.42, 0.47, 0.34),
			"pants": Color(0.33, 0.29, 0.24), "cap": true, "cap_color": Color(0.28, 0.28, 0.3), "sleeves": "long", "hair_style": "short", "build": 1.05}],
		["theo", "THEO  (kite)", {"skin": Color(0.58, 0.4, 0.28), "hair": Color(0.05, 0.04, 0.04), "shirt": Color(0.96, 0.8, 0.2), "pants": Color(0.25, 0.4, 0.62),
			"height": 0.68, "cap": true, "cap_color": Color(0.85, 0.15, 0.12), "hair_style": "curly", "build": 0.9}],
	]
	for k in people.size():
		var at := Vector3(rows[k % 2] * 0.55, y, -20.0 - k * 4.0)
		shape_at("cylinder", at + Vector3(0, 0.06, 0), Vector3(0.9, 0.12, 0.9), TRIM, true, Vector3.ZERO, "metal")
		var hmn := Human.new()
		add_child(hmn)
		hmn.build(people[k][2])
		hmn.position = at + Vector3(0, 0.12, 0)
		hmn.rotation_degrees.y = 180.0
		hmn.set_frozen(true)
		label(at + Vector3(0, 0.3, 0.75), 0, people[k][1], 0.05, Color(0.2, 0.2, 0.2), false)
		spot(at + Vector3(0, 4.2, 1.2), at + Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.8), 3.0, 7.0, 25.0, false)
	# the last plinth: empty. your card on it.
	var last := Vector3(0, y, -34.0)
	shape_at("cylinder", last + Vector3(0, 0.06, 0), Vector3(0.9, 0.12, 0.9), TRIM, true, Vector3.ZERO, "metal")
	label(last + Vector3(0, 0.3, 0.75), 0, "YOU  (coming soon)", 0.06, Color(0.5, 0.1, 0.08), false)
	spot(last + Vector3(0, 4.2, 1.2), last + Vector3(0, 1.0, 0), Color(1.0, 0.92, 0.8), 3.0, 7.0, 25.0, false)
	# along the walls, the rest of the collection - every one of them waiting
	for k in 6:
		var s := -1.0 if k % 2 == 0 else 1.0
		var at := Vector3(s * 16.0, y, -10.0 - k * 4.5)
		var m := _mannequin(at, -90.0 * s, ["stand", "wave", "hip"][k % 3], true, 1)
		m.set_meta("wakes", "sl_lights3")
	# the staff exit
	box(EXIT + Vector3(0, 1.15, 0.1), Vector3(1.4, 2.3, 0.1), Color(0.3, 0.32, 0.3), false, 0.0, "metal")
	part("box", EXIT + Vector3(0, 2.6, 0.2), Vector3(1.0, 0.25, 0.04), Color(0.1, 0.8, 0.3), null, Vector3.ZERO, 2.5)
	label(EXIT + Vector3(0, 2.6, 0.23), 0, "STAFF EXIT", 0.07, Color(1, 1, 1), true)
	interactable(EXIT + Vector3(0, 1.1, 0.5), Vector3(1.4, 2.0, 0.6), func(): return "Staff exit",
		func():
			Sfx.play("door_creak", -2.0, 0.8)
			Game.on_stilllife_exit())
	trigger(Vector3(ESC_B.x, y + 1.2, ESC_B.z + ESC_RUN + 1.5), Vector3(4, 2.4, 2), func():
		Game.set_flag("sl_level3")
		Game.hud.show_thought("'LIFELIKE.' ...The exit's at the far end. Past all of them.", 3.5))
	trigger(Vector3(0, y + 1.2, -22.0), Vector3(W * 2, 2.4, 2), func(): _begin_climax())


func _begin_climax() -> void:
	if _climax_t >= 0.0:
		return
	_climax_t = 0.0
	Sfx.play_music("suspense", 0.4)
	Game.set_flag("sl_lights3")
	Sfx.stinger("braam", -2.0)
	Sfx.play("switch", 2.0, 0.5)
	Game.hud.show_thought("The lights - behind me - they're going out. In the dark they don't have to wait for me to look away.", 4.5)
	_wake("sl_lights3")


func _update_climax(delta: float) -> void:
	if _climax_t < 0.0:
		return
	_climax_t += delta
	# a section every 2.5 s, from the front of the floor toward the exit
	for s in _sections:
		var due: float = (absf(s.z) - 6.0) / 12.0 * 2.5 + 0.5
		if s.on and _climax_t > due and s.z > -31.0:
			s.on = false
			for l in s.lights:
				l.visible = false
			for p in s.panels:
				p.material_override = Shapes.material(Color(0.2, 0.2, 0.2))
			Sfx.play("switch", -2.0, 0.6)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0


func _process(delta: float) -> void:
	_t += delta
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_update_figures(delta, p)
	_update_climax(delta)
	for l in _panel_lights:
		if l[0].visible and randf() < 0.004 and Settings.flashing_ok():
			l[0].light_energy = l[1] * 0.2
		else:
			l[0].light_energy = move_toward(l[0].light_energy, l[1], delta * 4.0)
	if _hint == 0 and _t > 1.5:
		_hint = 1
		Sfx.play("thud", -2.0, 0.7)
		Game.hud.show_thought("The doors - they've locked. Behind me. ...A shop? At this time of night?", 4.0)
	elif _hint == 1 and _t > 7.0:
		_hint = 2
		Game.hud.show_hint("They only move when you aren't looking.", 6.0)
	if not observer.visible and p.y > STOREY - 0.5:
		_obs_t -= delta
		if _obs_t <= 0.0:
			_obs_t = 12.0
			observer.try_appear_at(Vector3(randf_range(-15, 15), floorf((p.y + 0.5) / STOREY) * STOREY, randf_range(-35, -5)))
