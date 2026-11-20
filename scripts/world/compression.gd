class_name CompressionZone
extends Zone
## COMPRESSION - claustrophobia. The service level under an old apartment building: concrete, pipes,
## bare bulbs, and less room everywhere you go.
##
## Goal: the freight elevator is dead. Its fuse box has three empty slots. The three fuses are:
##  - at the end of a crawl-through ventilation duct (crouch), where something breathes behind you
##    and fingers come through the slats;
##  - at the far end of THE PRESS, a room whose walls move in whenever you are not looking at them;
##  - in the drying room, among the sheets, where sheeted figures come closer while you look away.
## The corridor you came in by is gone once you reach the hub. Tight spaces raise DREAD on their own.

const W := 30
const H := 36
const WALL_H := 3.4
const CEILING := {".": 2.6, ",": 2.3, "_": 1.45, "v": 1.4, "w": 1.6, "P": 2.6, "S": 3.2, "E": 2.4}

const PRESS_CENTER_Z := -18.0
const PRESS_X0 := 6.0
const PRESS_X1 := 14.0
const PRESS_OPEN := 1.95         # half-width of the press room
const PRESS_SPEED := 0.38        # m/s per wall while unwatched
const FIGURE_SPEED := 1.4

## Checkpoints (see Zone.checkpoint_at): the hub, each time you come back to it with another fuse, and
## with the power on.
const HUB := Vector3(0.5, 0.05, -17.0)
const CHECKPOINTS := {
	"hub": [HUB, 0.0, ["comp_saw_box"]],
	"hub1": [HUB, 0.0, ["comp_saw_box", "comp_fuse_vent"]],
	"hub2": [HUB, 0.0, ["comp_saw_box", "comp_fuse_vent", "comp_fuse_press"]],
	"hub3": [HUB, 0.0, ["comp_saw_box", "comp_fuse_vent", "comp_fuse_press", "comp_fuse_sheets", "comp_fuses"]],
	"power": [HUB, 0.0, ["comp_saw_box", "comp_fuse_vent", "comp_fuse_press", "comp_fuse_sheets", "comp_fuses", "comp_power"]],
}

const CONCRETE := Color(0.42, 0.41, 0.38)
const DIRTY := Color(0.33, 0.31, 0.27)
const METAL := Color(0.38, 0.4, 0.42)
const SHEET := Color(0.95, 0.94, 0.9)

var grid: Array[PackedByteArray] = []
var _press_walls: Array[StaticBody3D] = []
var _press_h := [PRESS_OPEN, PRESS_OPEN]
var _press_moves := 0
var _grind: AudioStreamPlayer3D
var _figures: Array[Node3D] = []
var _figure_hint := 0
var _room_t := 0.0
var _sheets: Array[Node3D] = []
var _sheet_bulb: Node3D
var _fingers: Array = []          # [group, seen_time]
var _breath: AudioStreamPlayer3D
var _seal: StaticBody3D
var _sealed_t := 0.0
var _seal_noticed := false
var _fuse_slots: Array[Node3D] = []
var _fuse_items := {}             # flag -> node
var _elev_doors: Array[Node3D] = []
var _elev_inner: Array[Node3D] = []
var _elev_open := false
var _elev_riding := false
var _call_light: MeshInstance3D
var _bulbs: Array = []            # [light, base_energy, flicker]
var _t := 0.0
var _hint := 0
var _tight_t := 0.0
var _tight := 0.0
var _knock_t := 6.0


func zone_id() -> String: return "compression"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 15.0
func fear_decay() -> float: return 1.2
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.3
func sprint_speed() -> float: return 3.6
## A light can be pictured here (hold Q) - a weak one: the dark still counts.
func allows_manifestation() -> bool: return true
func manifest_allowlist() -> Array: return ["flashlight"]
func flashlight_scale() -> float: return 0.45


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.5, 0.05, -2.2))


static func cell_center(c: int, r: int) -> Vector3:
	return Vector3(c - 15 + 0.5, 0, r - 36 + 0.5)


func _paint(c0: int, c1: int, r0: int, r1: int, ch: String) -> void:
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			grid[r][c] = ch.unicode_at(0)


func _at(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= W or r >= H:
		return "#"
	return String.chr(grid[r][c])


# ------------------------------------------------------------------ build

func build() -> void:
	for r in H:
		var row := PackedByteArray()
		row.resize(W)
		row.fill("#".unicode_at(0))
		grid.append(row)
	_paint(13, 17, 30, 34, ".")   # boiler room (start)
	_paint(15, 15, 22, 29, ",")   # the corridor
	_paint(15, 15, 24, 25, "_")   # ...where the ceiling comes down
	_paint(11, 19, 14, 21, ".")   # the hub
	_paint(15, 16, 12, 13, "E")   # freight elevator
	_paint(20, 20, 17, 18, ",")   # to the press
	_paint(21, 28, 16, 19, "P")   # the press
	_paint(4, 10, 19, 19, "v")    # the vent: west...
	_paint(4, 4, 9, 19, "v")      # ...north...
	_paint(4, 9, 9, 9, "v")       # ...east
	_paint(7, 10, 6, 9, "w")      # vent junction (fuse)
	_paint(10, 10, 21, 24, ",")   # to the drying room
	_paint(1, 9, 23, 33, "S")     # the drying room

	_geometry()
	_lights()
	_fusebox_and_elevator()
	_press()
	_vent()
	_drying_room()
	_props()
	_wall_detail()
	_vermin()

	var env := make_env(Color(0.35, 0.32, 0.27), 0.05)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.06
	environment(env)

	ambient("room_tone", Vector3.ZERO, false, -10.0)
	ambient("hum", Vector3(0.5, 2.3, -18), true, -14.0, 14.0)
	ambient("drone", Vector3.ZERO, false, -26.0)
	_breath = ambient("breath", Vector3(-10.5, 0.6, -20), true, -80.0, 8.0) as AudioStreamPlayer3D
	_grind = ambient("grind", Vector3(10, 1.2, PRESS_CENTER_Z), true, -80.0, 25.0) as AudioStreamPlayer3D


func _geometry() -> void:
	# floor
	box(Vector3(0, -0.15, -18), Vector3(W + 2, 0.3, H + 2), DIRTY, true, 0.0, "concrete")
	# walls: only wall cells that touch open space, merged into runs
	for r in H:
		var run_start := -1
		for c in W + 1:
			var edge := c < W and _at(c, r) == "#" and _touches_open(c, r)
			if edge and run_start < 0:
				run_start = c
			elif not edge and run_start >= 0:
				var a := cell_center(run_start, r)
				var b := cell_center(c - 1, r)
				box((a + b) * 0.5 + Vector3(0, WALL_H * 0.5, 0), Vector3(c - run_start, WALL_H, 1), CONCRETE, true, 0.0, "concrete")
				run_start = -1
	# ceilings by height, merged into runs
	for r in H:
		var c := 0
		while c < W:
			var ch := _at(c, r)
			if ch == "#":
				c += 1
				continue
			var c1 := c
			while c1 + 1 < W and _at(c1 + 1, r) == ch:
				c1 += 1
			var h: float = CEILING[ch]
			var a := cell_center(c, r)
			var b := cell_center(c1, r)
			var col := METAL if ch == "v" or ch == "w" else CONCRETE.darkened(0.15)
			box((a + b) * 0.5 + Vector3(0, (h + WALL_H) * 0.5, 0), Vector3(c1 - c + 1, WALL_H - h, 1), col, true, 0.0, "metal" if ch == "v" or ch == "w" else "concrete")
			if ch == "v" or ch == "w":
				box((a + b) * 0.5 + Vector3(0, 0.01, 0), Vector3(c1 - c + 1, 0.02, 1), METAL.darkened(0.2), false, 0.0, "metal")
			c = c1 + 1
	# the corridor seals itself behind you (enabled later)
	_seal = solid_box(Vector3(0.5, 1.3, -13.9), Vector3(1.0, 2.6, 0.2), CONCRETE, null, "concrete")
	_set_body(_seal, false)


func _touches_open(c: int, r: int) -> bool:
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if _at(c + dc, r + dr) != "#":
				return true
	return false


static func _set_body(b: StaticBody3D, on: bool) -> void:
	b.visible = on
	for ch in b.get_children():
		if ch is CollisionShape3D:
			ch.disabled = not on


func _bulb(pos: Vector3, energy: float, rng: float, flicker := false, shadows := false, col := Color(1.0, 0.78, 0.5)) -> OmniLight3D:
	part("sphere", pos, Vector3.ONE * 0.09, col, null, Vector3.ZERO, 3.0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part("cylinder", pos + Vector3(0, 0.2, 0), Vector3(0.01, 0.3, 0.01), Color(0.05, 0.05, 0.05)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := omni(pos + Vector3(0, -0.1, 0), col, energy, rng, shadows)
	_bulbs.append([l, energy, flicker])
	return l


func _lights() -> void:
	_bulb(Vector3(0.5, 2.25, -3.5), 1.0, 7.0, false, true)
	_bulb(Vector3(0.5, 1.95, -8.0), 0.5, 5.0, true)
	_bulb(Vector3(0.5, 1.15, -11.0), 0.35, 4.0, false, false, Color(1.0, 0.15, 0.1))   # emergency light in the low part
	_bulb(Vector3(-1.5, 2.25, -18.5), 0.9, 8.0, false, true)
	_bulb(Vector3(3.0, 2.25, -15.5), 0.6, 6.0, true)
	_bulb(Vector3(-4.5, 1.95, -12.5), 0.4, 4.0, true)   # drying-room corridor
	_bulb(Vector3(1.0, 2.1, -23.0), 0.3, 3.0, false, false, Color(0.7, 0.8, 1.0))   # inside the elevator
	# vent: a few slats of light, nearly nothing
	for p in [Vector3(-8, 1.0, -16.5), Vector3(-10.5, 1.0, -22), Vector3(-9.5, 1.0, -26.5)]:
		omni(p, Color(0.8, 0.7, 0.55), 0.45, 4.0, false)
	omni(Vector3(-6, 1.3, -28.5), Color(0.9, 0.8, 0.6), 0.6, 5.0, false)


# ------------------------------------------------------------------ fuse box and freight elevator

func _fusebox_and_elevator() -> void:
	# fuse box on the hub's north wall
	var fb := Vector3(3.5, 1.4, -21.9)
	box(fb, Vector3(0.55, 0.75, 0.16), Color(0.3, 0.35, 0.3), true, 0.0, "metal")
	label(fb + Vector3(0, 0.27, 0.085), 0, "ELEVATOR", 0.06, Color(0.9, 0.85, 0.3), false)
	for i in 3:
		var slot := fb + Vector3(-0.15 + i * 0.15, -0.05, 0.09)
		part("box", slot, Vector3(0.08, 0.25, 0.02), Color(0.05, 0.05, 0.05), null)
		var f := group(slot + Vector3(0, 0, 0.03))
		_fuse_mesh(f)
		f.rotation_degrees.z = 90
		f.visible = false
		_fuse_slots.append(f)
	interactable(fb, Vector3(0.7, 0.9, 0.4),
		func():
			if Game.has_flag("comp_power"):
				return "Fuse box (working)"
			return "Put the fuses in" if _fuses_found() > _fuses_inserted() else "Fuse box",
		func(): _use_fusebox())
	# the elevator: a cage barely big enough for one
	for side in [-1.0, 1.0]:
		var d := group(Vector3(1.0 + side * 0.5, 0, -22.0))
		part("box", Vector3(0, 1.2, 0), Vector3(1.0, 2.4, 0.06), METAL.darkened(0.2), d, Vector3.ZERO, 0.0, "metal")
		for k in 5:
			part("box", Vector3(-0.4 + k * 0.2, 1.2, 0.04), Vector3(0.03, 2.3, 0.02), METAL.lightened(0.1), d, Vector3.ZERO, 0.0, "metal")
		_elev_doors.append(d)
	_elev_block = solid_box(Vector3(1.0, 1.2, -22.0), Vector3(2.0, 2.4, 0.1), Color(0, 0, 0), null)
	_elev_block.get_child(1).visible = false
	# inner walls that close in during the ride (visual)
	for side in [-1.0, 1.0]:
		var w := group(Vector3(1.0 + side * 0.97, 0, -23.0))
		part("box", Vector3(0, 1.2, 0), Vector3(0.04, 2.4, 1.95), METAL.darkened(0.35), w, Vector3.ZERO, 0.0, "metal")
		_elev_inner.append(w)
	label(Vector3(1.0, 2.55, -21.94), 0, "FREIGHT  -  MAX 1 PERSON", 0.07, Color(0.8, 0.8, 0.75), false)
	# call button
	box(Vector3(-0.3, 1.25, -21.95), Vector3(0.14, 0.24, 0.06), METAL, false, 0.0, "metal")
	_call_light = part("sphere", Vector3(-0.3, 1.28, -21.91), Vector3.ONE * 0.06, Color(0.6, 0.05, 0.05), null, Vector3.ZERO, 1.5)
	interactable(Vector3(-0.3, 1.25, -21.8), Vector3(0.4, 0.5, 0.3), func(): return "Call the elevator",
		func(): _call_elevator(), func(): return not _elev_open)


var _elev_block: StaticBody3D


func _fuse_mesh(parent: Node3D) -> void:
	part("cylinder", Vector3.ZERO, Vector3(0.05, 0.14, 0.05), Color(0.9, 0.88, 0.8), parent, Vector3.ZERO, 0.0, 0.3)
	part("cylinder", Vector3(0, 0.08, 0), Vector3(0.055, 0.03, 0.055), Color(0.8, 0.65, 0.3), parent, Vector3.ZERO, 0.0, "metal")
	part("cylinder", Vector3(0, -0.08, 0), Vector3(0.055, 0.03, 0.055), Color(0.8, 0.65, 0.3), parent, Vector3.ZERO, 0.0, "metal")


func _fuse_pickup(flag: String, pos: Vector3, thought: String) -> void:
	var f := group(pos)
	_fuse_mesh(f)
	f.rotation_degrees.z = 90
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.light_energy = 0.35
	glow.omni_range = 1.2
	glow.position = Vector3(0.2, 0, 0)
	f.add_child(glow)
	_fuse_items[flag] = f
	interactable(pos, Vector3(0.6, 0.6, 0.6), func(): return "Take the fuse",
		func():
			f.visible = false
			Game.set_flag(flag)
			Game.counters["fuses"] = _fuses_found()
			if _fuses_found() >= 3:
				Game.set_flag("comp_fuses")
			Sfx.play("page", -6.0, 0.6)
			Game.hud.show_thought(thought, 3.5),
		func(): return f.visible)


func _fuses_found() -> int:
	var n := 0
	for k in ["comp_fuse_vent", "comp_fuse_press", "comp_fuse_sheets"]:
		if Game.has_flag(k):
			n += 1
	return n


func _fuses_inserted() -> int:
	return int(Game.counters.get("fuses_in", 0))


func _use_fusebox() -> void:
	Game.set_flag("comp_saw_box")
	if Game.has_flag("comp_power"):
		Game.hud.show_thought("It hums now.", 2.0)
		return
	var found := _fuses_found()
	if found <= _fuses_inserted():
		Game.hud.show_thought("Three empty slots. The fuses have been taken out." if found == 0 else "Still empty slots.", 3.0)
		return
	Game.counters["fuses_in"] = found
	_show_fuses()
	Sfx.play("thud", -12.0, 1.5)
	if found >= 3:
		_power_on(false)
	else:
		Game.hud.show_thought("%d of 3." % found, 2.0)


func _show_fuses() -> void:
	for i in 3:
		_fuse_slots[i].visible = i < _fuses_inserted()


func _power_on(instant: bool) -> void:
	Game.set_flag("comp_power")
	_call_light.material_override = Shapes.material(Color(0.1, 0.9, 0.2), 0.85, 2.0)
	if not instant:
		Sfx.play("whoosh", -6.0, 0.4)
		Game.hud.show_thought("Something wakes up behind the walls. The elevator.", 3.5)
		for b in _bulbs:
			b[1] *= 1.3


func _call_elevator() -> void:
	Game.set_flag("comp_saw_box")
	if not Game.has_flag("comp_power"):
		Game.hud.show_thought("Nothing. No power.", 2.0)
		return
	_elev_open = true
	Sfx.play("thud", -6.0, 0.6)
	_set_body(_elev_block, false)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		create_tween().tween_property(_elev_doors[i], "position:x", 1.0 + side * 1.45, 1.6).set_trans(Tween.TRANS_SINE)
	Game.hud.show_thought("Get in. It's so small. Get in.", 3.0)


func _ride() -> void:
	_elev_riding = true
	Game.in_sequence = true
	Game.set_flag("comp_elevator")
	Game.set_mode("cinematic")
	var t := Game._seq
	_set_body(_elev_block, true)
	_elev_block.get_child(1).visible = false
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		create_tween().tween_property(_elev_doors[i], "position:x", 1.0 + side * 0.5, 1.2).set_trans(Tween.TRANS_SINE)
	Sfx.play("thud", -2.0, 0.5)
	await get_tree().create_timer(1.5, false).timeout
	if t != Game._seq: return
	# up. and the cage gets smaller.
	_grind.global_position = Vector3(1, 1.2, -23)
	_grind.volume_db = -4.0
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		create_tween().tween_property(_elev_inner[i], "position:x", 1.0 + side * 0.55, 6.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for k in 12:
		Game.player.jolt(Vector3(randf_range(-1.5, 1.5), randf_range(-1, 1), randf_range(-1.5, 1.5)))
		Game.player.dread.add_fear(3.5, "elevator")
		for b in _bulbs:
			b[0].light_energy = b[1] * (0.0 if randf() < 0.4 and Settings.flashing_ok() else 1.0)
		if k == 5:
			Game.hud.show_thought("It's getting smaller. It's getting smaller.", 3.0)
		await get_tree().create_timer(0.5, false).timeout
		if t != Game._seq: return
	_grind.volume_db = -80.0
	Game.enter_tenement()


# ------------------------------------------------------------------ THE PRESS

func _press() -> void:
	var length := PRESS_X1 - PRESS_X0
	for side in [-1.0, 1.0]:
		var w := solid_box(Vector3((PRESS_X0 + PRESS_X1) * 0.5, 1.3, PRESS_CENTER_Z + side * (PRESS_OPEN + 0.15)), Vector3(length, 2.6, 0.3),
			CONCRETE.darkened(0.1), null, "concrete")
		(w.get_child(1) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_press_walls.append(w)
		# rusted rails along the floor, the only sign they can move
		box(Vector3((PRESS_X0 + PRESS_X1) * 0.5, 0.01, PRESS_CENTER_Z + side * 1.0), Vector3(length, 0.02, 0.06), Color(0.35, 0.2, 0.12), false, 0.0, "metal")
	# harsh strip light
	part("box", Vector3(10, 2.55, PRESS_CENTER_Z), Vector3(6.0, 0.05, 0.15), Color(0.9, 0.95, 1.0), null, Vector3.ZERO, 3.0)
	var l := omni(Vector3(10, 2.3, PRESS_CENTER_Z), Color(0.85, 0.92, 1.0), 1.2, 9.0, false)
	_bulbs.append([l, 1.2, true])
	label(Vector3(4.98, 1.9, -16.5), -90, "THE PRESS\nDO NOT ENTER\nWHILE IN OPERATION", 0.05, Color(0.85, 0.2, 0.1), false)
	# the shelf with the fuse, at the far end
	box(Vector3(13.75, 0.8, PRESS_CENTER_Z), Vector3(0.4, 0.05, 0.8), METAL, true, 0.0, "metal")
	_fuse_pickup("comp_fuse_press", Vector3(13.7, 0.9, PRESS_CENTER_Z), "One. Now get out before it closes.")


func _player_in_press(p: Vector3) -> bool:
	return p.x > PRESS_X0 and p.x < PRESS_X1 + 0.5 and absf(p.z - PRESS_CENTER_Z) < PRESS_OPEN + 0.3


func _update_press(delta: float, p: Vector3) -> void:
	var inside := _player_in_press(p)
	var moving := false
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var h: float = _press_h[i]
		if inside:
			var probe := Vector3(clampf(p.x, PRESS_X0 + 0.5, PRESS_X1 - 0.5), 1.3, PRESS_CENTER_Z + side * h)
			if not Observation.is_observed(probe, 0.9, [_press_walls[i]]):
				h -= PRESS_SPEED * delta
				moving = true
		else:
			h = minf(PRESS_OPEN, h + 0.7 * delta)
		_press_h[i] = h
		_press_walls[i].position.z = PRESS_CENTER_Z + side * (h + 0.15)
	_grind.volume_db = lerpf(_grind.volume_db, -2.0 if moving else -60.0, clampf(delta * 6.0, 0.0, 1.0))
	if not inside:
		return
	if moving:
		_press_moves += 1
		Game.player.dread.add_fear(4.0 * delta, "the press")
		if _press_moves == 20:
			Game.hud.show_thought("The walls... the walls are moving.", 3.0)
		elif _press_moves == 160:
			Game.hud.show_hint("They only move while you're not looking at them.", 6.0)
	# keep the player between them, or crush them
	var lo: float = PRESS_CENTER_Z - _press_h[0] + 0.36
	var hi: float = PRESS_CENTER_Z + _press_h[1] - 0.36
	if hi - lo < 0.05:
		Game.entity_death("crush")
		return
	if p.z < lo or p.z > hi:
		Game.player.global_position.z = clampf(p.z, lo, hi)


# ------------------------------------------------------------------ the vent

func _vent() -> void:
	label(Vector3(-3.98, 1.6, -16.5), 90, "VENT", 0.08, Color(0.6, 0.6, 0.55), false)
	# slats with light behind them, and fingers in three of them
	var slats := [Vector3(-7.5, 0.7, -16.04), Vector3(-10.96, 0.7, -20.5), Vector3(-10.96, 0.7, -24.5), Vector3(-9.5, 0.7, -26.96)]
	for i in slats.size():
		var s: Vector3 = slats[i]
		var along_x := absf(s.z - roundf(s.z)) < 0.1
		for k in 4:
			var off := Vector3(0, k * 0.07 - 0.1, 0)
			part("box", s + off, Vector3(0.5, 0.02, 0.02) if along_x else Vector3(0.02, 0.02, 0.5), Color(0.9, 0.8, 0.6), null, Vector3.ZERO, 1.2)
		if i == 0:
			continue
		var g := group(s)
		var inward := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		for k in 4:
			var f := part("capsule", Vector3.ZERO, Vector3(0.022, 0.09, 0.022), Color(0.78, 0.74, 0.7), g, Vector3.ZERO, 0.0, 0.6)
			f.position = (Vector3(k * 0.035 - 0.05, 0.02, 0) if along_x else Vector3(0, 0.02, k * 0.035 - 0.05)) + inward * 0.05
			f.rotation_degrees = Vector3(90, 0, 0) if along_x else Vector3(0, 0, 90)
		_fingers.append([g, 0.0])
	_fuse_pickup("comp_fuse_vent", Vector3(-6.0, 0.12, -29.0), "Two. Don't think about what was breathing.")


func _update_vent(delta: float, p: Vector3) -> void:
	var in_vent := _at(int(floor(p.x + 15)), int(floor(p.z + 36))) in ["v", "w"]
	# something breathing just behind you in the duct
	if in_vent:
		var back := Game.player.global_transform.basis.z
		_breath.global_position = p + back * 2.2 + Vector3(0, 0.6, 0)
		_breath.volume_db = lerpf(_breath.volume_db, -6.0, clampf(delta, 0.0, 1.0))
		_knock_t -= delta
		if _knock_t <= 0.0:
			_knock_t = randf_range(5.0, 9.0)
			Sfx.play_at("knock", self, p + back * randf_range(1.5, 4.0) + Vector3(0, 1.2, 0), 0.0, 12.0)
			if Game.player.dread.fear < 60.0:
				Game.player.dread.add_fear(1.5, "knocking in the duct")
	else:
		_breath.volume_db = lerpf(_breath.volume_db, -80.0, clampf(delta * 2.0, 0.0, 1.0))
	for f in _fingers:
		var g: Node3D = f[0]
		if not g.visible:
			continue
		if g.global_position.distance_to(p) < 6.0 and Observation.is_observed(g.global_position, 0.15):
			f[1] += delta
			if f[1] > 0.5:
				g.visible = false
				Sfx.play_at("knock", self, g.global_position, -2.0, 10.0)
				Game.player.dread.add_fear(4.0, "fingers")
				Game.hud.show_thought("Fingers. There were fingers.", 2.5)


# ------------------------------------------------------------------ the drying room

func _drying_room() -> void:
	# x -14..-5, z -13..-2. Lines of sheets, a bare bulb on a cord.
	var rows := [-11.0, -8.6, -6.2, -3.8]
	# thin, worn cotton: light passes through it, and so do the shapes of whatever stands behind
	var cloth: Array[StandardMaterial3D] = []
	for k in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(SHEET.darkened(k * 0.06), 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.95
		cloth.append(m)
	for ri in rows.size():
		var z: float = rows[ri]
		box(Vector3(-9.5, 2.75, z), Vector3(9, 0.015, 0.015), Color(0.2, 0.2, 0.2), false)
		var x := -13.6 + (0.9 if ri % 2 == 1 else 0.0)
		while x < -5.6:
			var s := group(Vector3(x + 0.75, 2.75, z))
			var sheet := part("box", Vector3(0, -1.15, 0), Vector3(1.45, 2.3, 0.02), SHEET, s, Vector3.ZERO, 0.0, "fabric")
			sheet.material_override = cloth[randi() % cloth.size()]
			sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_sheets.append(s)
			x += 2.3
	_sheet_bulb = group(Vector3(-9.5, 3.2, -7.5))
	part("cylinder", Vector3(0, -0.4, 0), Vector3(0.01, 0.8, 0.01), Color(0.05, 0.05, 0.05), _sheet_bulb)
	part("sphere", Vector3(0, -0.85, 0), Vector3.ONE * 0.1, Color(1.0, 0.85, 0.6), _sheet_bulb, Vector3.ZERO, 3.0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.55)
	l.light_energy = 2.2
	l.omni_range = 12.0
	l.shadow_enabled = true
	l.position = Vector3(0, -1.0, 0)
	_sheet_bulb.add_child(l)
	# laundry baskets and a crate with the fuse
	box(Vector3(-13.2, 0.4, -12.3), Vector3(0.8, 0.8, 0.8), Color(0.35, 0.25, 0.15), true, 10.0, "wood")
	_fuse_pickup("comp_fuse_sheets", Vector3(-13.2, 0.88, -12.3), "Three. Don't turn around slowly. Don't turn around at all.")
	for p in [Vector3(-6, 0.25, -12.4), Vector3(-12.8, 0.25, -2.6)]:
		shape_at("cylinder", p, Vector3(0.6, 0.5, 0.45), Color(0.5, 0.45, 0.35), true, Vector3.ZERO, "fabric")
	# the ones under the sheets
	for p in [Vector3(-12.6, 0, -9.8), Vector3(-9.0, 0, -5.6), Vector3(-11.0, 0, -3.4)]:
		var f := Node3D.new()
		f.position = p
		add_child(f)
		f.set_meta("home", p)
		_figures.append(f)
		# the custom model (models/creatures/draped.glb, made by tools/creatures): a body under a thin sheet
		var model := Models.instance(["creatures/draped"])
		if model:
			f.add_child(Models.fit(model, 1.85))
			continue
		part("capsule", Vector3(0, 0.95, 0), Vector3(0.62, 1.0, 0.5), SHEET.darkened(0.08), f, Vector3.ZERO, 0.0, "fabric")
		part("sphere", Vector3(0, 1.72, 0.02), Vector3(0.3, 0.34, 0.3), SHEET.darkened(0.05), f, Vector3.ZERO, 0.0, "fabric")
		part("cone", Vector3(0, 0.3, 0), Vector3(0.85, 0.6, 0.75), SHEET.darkened(0.12), f, Vector3.ZERO, 0.0, "fabric")
		# where the eyes press against the cloth
		for sx in [-0.07, 0.07]:
			part("sphere", Vector3(sx, 1.76, 0.155), Vector3(0.05, 0.035, 0.02), Color(0.12, 0.1, 0.09), f)
		f.set_meta("home", p)
		_figures.append(f)


func _in_drying_room(p: Vector3) -> bool:
	return p.x > -14.0 and p.x < -5.0 and p.z > -13.0 and p.z < -2.0


func _update_drying(delta: float, p: Vector3) -> void:
	_sheet_bulb.rotation_degrees.x = sin(_t * 0.9) * 9.0
	_sheet_bulb.rotation_degrees.z = sin(_t * 0.7 + 1.0) * 6.0
	for i in _sheets.size():
		_sheets[i].rotation_degrees.x = sin(_t * 1.3 + i * 0.7) * 2.5
	if not _in_drying_room(p):
		_room_t = 0.0
		return
	_room_t += delta
	if _room_t < 2.0:
		return   # a moment to see them before anything moves
	if _figure_hint == 0:
		_figure_hint = 1
		Game.hud.show_thought("Sheets on the lines. And... shapes. Under the sheets. Standing.", 4.0)
	for f in _figures:
		var head: Vector3 = f.global_position + Vector3(0, 1.4, 0)
		var to := p - f.global_position
		to.y = 0.0
		var d := to.length()
		f.rotation.y = atan2(to.x, to.z)
		if Observation.is_observed(head, 0.6):
			continue
		var step := minf(FIGURE_SPEED * delta, maxf(d - 0.2, 0.0))
		f.global_position += to.normalized() * step
		if _figure_hint == 1 and d < 6.0:
			_figure_hint = 2
			Game.hud.show_hint("They only move when you aren't looking.", 6.0)
		if d < 0.75:
			Game.entity_death("sheet", f)
			return


# ------------------------------------------------------------------ props

func _props() -> void:
	# boiler and pipes in the start room
	shape_at("cylinder", Vector3(-1.2, 0.9, -4.8), Vector3(1.1, 1.8, 1.1), Color(0.3, 0.2, 0.15), true, Vector3.ZERO, "metal")
	for i in 3:
		shape_at("cylinder", Vector3(-1.85 + i * 0.12, 1.3, -3.0), Vector3(0.08, 2.6, 0.08), Color(0.35, 0.3, 0.25).darkened(i * 0.1), false, Vector3.ZERO, "metal")
	# pipes along the corridor ceiling, sagging lower than they should
	for i in 2:
		shape_at("cylinder", Vector3(0.15 + i * 0.25, 2.05 - i * 0.12, -10), Vector3(0.12, 8.0, 0.12), Color(0.3, 0.33, 0.3), false, Vector3(90, 0, 0), "metal")
	# hub junk
	box(Vector3(-3.2, 0.5, -21.2), Vector3(1.0, 1.0, 1.0), Color(0.4, 0.3, 0.2), true, 12.0, "wood")
	box(Vector3(-3.0, 1.25, -21.3), Vector3(0.6, 0.5, 0.6), Color(0.45, 0.33, 0.22), true, -20.0, "wood")
	box(Vector3(4.6, 1.0, -15.0), Vector3(0.5, 2.0, 1.2), Color(0.3, 0.35, 0.35), true, 0.0, "metal")
	label(Vector3(0.5, 1.9, -0.98), 180, "B3", 0.4, Color(0.6, 0.58, 0.5), false)
	# over the doorway to the drying room (hub, back-left corner), with a bulb so it can't be missed
	label(Vector3(-3.97, 2.55, -14.5), 90, "DRYING ROOM", 0.09, Color(0.8, 0.76, 0.66), false)
	_bulb(Vector3(-3.4, 2.25, -14.5), 0.6, 4.0)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	for flag in _fuse_items:
		_fuse_items[flag].visible = not Game.has_flag(flag)
	Game.counters["fuses"] = _fuses_found()
	_show_fuses()
	if Game.has_flag("comp_power"):
		_power_on(true)
	if Game.has_flag("comp_sealed"):
		_set_body(_seal, true)
		_seal_noticed = true


func _process(delta: float) -> void:
	_t += delta
	for b in _bulbs:
		if b[2] and Settings.flashing_ok():
			b[0].light_energy = b[1] * (0.15 if randf() < 0.04 else 1.0)
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_hints(p)
	_update_press(delta, p)
	_update_vent(delta, p)
	_update_drying(delta, p)
	_update_tightness(delta, p)
	_update_seal(delta, p)
	# back in the hub: a checkpoint for every fuse you've brought back (and once the power's on)
	if p.x > -4.0 and p.x < 5.0 and p.z > -22.0 and p.z < -14.0 and Game.has_flag("comp_saw_box"):
		checkpoint_at("power" if Game.has_flag("comp_power") else ["hub", "hub1", "hub2", "hub3"][_fuses_found()])
	if _elev_open and not _elev_riding and p.z < -22.4 and p.x > 0.0 and p.x < 2.0:
		_ride()


## Tight spaces are frightening on their own.
func _update_tightness(delta: float, p: Vector3) -> void:
	_tight_t -= delta
	if _tight_t <= 0.0:
		_tight_t = 0.2
		var space := get_world_3d().direct_space_state
		var origin := p + Vector3(0, 0.9, 0)
		var total := 0.0
		for k in 6:
			var dir := Vector3(cos(k * TAU / 6.0), 0, sin(k * TAU / 6.0))
			var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.5, 1)
			var hit := space.intersect_ray(q)
			total += (origin.distance_to(hit.position) if hit else 2.5) / 2.5
		var up := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.UP * 2.0, 1)
		var uh := space.intersect_ray(up)
		var room := (total / 6.0) * 0.75 + ((origin.distance_to(uh.position) if uh else 2.0) / 2.0) * 0.25
		_tight = clampf(1.0 - room, 0.0, 1.0)
	# unsettling, but tight spaces alone never push you over the edge
	if _tight > 0.45 and Game.player.dread.fear < 55.0:
		Game.player.dread.add_fear((_tight - 0.45) * 6.0 * delta, "tight")


func _update_seal(delta: float, p: Vector3) -> void:
	if not Game.has_flag("comp_sealed"):
		if p.z < -15.5:
			_sealed_t += delta
			if _sealed_t > 4.0 and not Observation.is_observed(Vector3(0.5, 1.2, -13.9), 0.8):
				_set_body(_seal, true)
				Game.set_flag("comp_sealed")
	elif not _seal_noticed and p.distance_to(Vector3(0.5, 0, -14)) < 8.0 and Observation.is_observed(Vector3(0.5, 1.2, -13.9), 0.5):
		_seal_noticed = true
		Sfx.play("thud", -4.0, 0.7)
		Game.player.dread.add_fear(8.0, "sealed")
		Game.hud.show_thought("The corridor. The corridor I came down. It's wall.", 3.5)


var _fuse_hint := false


func _hints(p: Vector3) -> void:
	if not _fuse_hint and _fuses_found() == 2 and not Game.has_flag("comp_fuse_sheets") and p.z < -14.0:
		_fuse_hint = true
		Game.hud.show_hint("The last fuse: the DRYING ROOM.\nIts doorway is on your left as you come in from the corridor, under the sign.", 8.0)
	if _hint == 0 and _t > 2.5:
		_hint = 1
		Game.hud.show_thought("...Concrete. Pipes. A basement. It's so close in here.", 4.0)
	elif _hint == 1 and _t > 8.0:
		_hint = 2
		Game.hud.show_hint("Find a way out.\nCrouch: C / Ctrl", 7.0)
	if not Game.has_flag("comp_saw_box") and p.z < -15.0:
		_hint = maxi(_hint, 2)
		Game.set_flag("comp_saw_box")
		Game.hud.show_thought("A freight elevator. Dead. And the fuse box beside it is empty.", 4.0)


## Pipes and ducts along the walls: two runs under the ceiling with brackets, pipes dropping down the walls
## (some with valve wheels), vent grilles and junction boxes standing proud of the concrete. Just to look at:
## none of it collides, so it never makes a tight space tighter than it was built.
func _wall_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var rust := Color(0.42, 0.26, 0.16)
	var grey := Color(0.36, 0.38, 0.39)
	var green := Color(0.22, 0.3, 0.24)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for r in H:
		for c in W:
			var ch := _at(c, r)
			if not ch in [".", ",", "S", "E"]:
				continue
			var h: float = CEILING[ch]
			var cc := cell_center(c, r)
			for d: Vector2i in dirs:
				if _at(c + d.x, r + d.y) != "#":
					continue
				var n := Vector3(d.x, 0, d.y)                  # toward the wall
				var face := cc + n * 0.5
				var along_x := d.y != 0                       # the run goes along x when the wall is north/south
				var rot := Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0)
				# two horizontal runs under the ceiling
				shape_at("pipe", face - n * 0.12 + Vector3(0, h - 0.2, 0), Vector3(0.1, 1.02, 0.1), rust, false, rot, "metal")
				shape_at("pipe", face - n * 0.24 + Vector3(0, h - 0.36, 0), Vector3(0.07, 1.02, 0.07), grey, false, rot, "metal")
				if (c + r) % 2 == 0:
					# a bracket holding both
					shape_at("box", face - n * 0.15 + Vector3(0, h - 0.28, 0), (Vector3(0.04, 0.32, 0.3) if along_x else Vector3(0.3, 0.32, 0.04)), grey.darkened(0.3), false, Vector3.ZERO, "metal")
				var roll := rng.randf()
				if roll < 0.09 and ch != ",":
					# a pipe down the wall, a valve wheel on it
					shape_at("pipe", face - n * 0.1 + Vector3(0, (h - 0.2) * 0.5, 0), Vector3(0.09, h - 0.2, 0.09), green, false, Vector3.ZERO, "metal")
					var wheel_rot := Vector3(90, 0, 0) if along_x else Vector3(0, 0, 90)
					shape_at("pipe", face - n * 0.2 + Vector3(0, 1.3, 0), Vector3(0.28, 0.03, 0.28), Color(0.6, 0.12, 0.1), false, wheel_rot, "metal")
				elif roll < 0.15:
					# a vent grille, standing out from the wall, slats and all
					var vy := 0.45 if rng.randf() < 0.5 else 1.7
					var vsize := Vector3(0.6, 0.38, 0.1) if along_x else Vector3(0.1, 0.38, 0.6)
					shape_at("box", face - n * 0.05 + Vector3(0, vy, 0), vsize, grey.darkened(0.2), false, Vector3.ZERO, "metal")
					for k in 4:
						shape_at("box", face - n * 0.11 + Vector3(0, vy - 0.12 + k * 0.08, 0), (Vector3(0.52, 0.025, 0.02) if along_x else Vector3(0.02, 0.025, 0.52)), Color(0.08, 0.08, 0.08), false, Vector3.ZERO, "metal")
				elif roll < 0.19:
					# a junction box with a conduit up to the ceiling
					shape_at("box", face - n * 0.08 + Vector3(0, 1.5, 0), (Vector3(0.35, 0.45, 0.14) if along_x else Vector3(0.14, 0.45, 0.35)), Color(0.5, 0.5, 0.45), false, Vector3.ZERO, "metal")
					shape_at("pipe", face - n * 0.05 + Vector3(0, 1.73 + (h - 1.73) * 0.5, 0), Vector3(0.04, h - 1.73, 0.04), grey, false, Vector3.ZERO, "metal")


## Optional creatures (models/creatures/): rats that bolt when you come near (one runs into the vent
## ahead of you), spiders on the duct ceiling, a snake by the fuse in the drying room.
func _vermin() -> void:
	var runs := [
		[Vector3(-1.8, 0, -21.5), Vector3(-7.0, 0, -16.5)],    # hub corner -> into the vent
		[Vector3(0.5, 0, -7.0), Vector3(0.5, 0, -13.4)],       # down the corridor
		[Vector3(-4.5, 0, -14.6), Vector3(-4.5, 0, -11.3)],    # towards the drying room
		[Vector3(12.5, 0, -16.3), Vector3(6.4, 0, -19.6)],     # across the press
	]
	for r in runs:
		var rat := Critter.create(["creatures/rat"], 0.32)
		if rat:
			add_child(rat)
			rat.scurry(r[0], r[1], 3.2, 4.5)
	for r in [[Vector3(-10.5, 1.38, -19.0), Vector3(-10.5, 1.38, -25.5)], [Vector3(-9.8, 1.38, -26.5), Vector3(-5.5, 1.38, -26.5)]]:
		var spider := Critter.create(["creatures/spider"], 0.4)
		if spider:
			add_child(spider)
			spider.scurry(r[0], r[1], 1.2, 3.0)
			spider.get_child(0).rotation_degrees.z = 180.0   # on the ceiling
	var snake := Critter.create(["creatures/snake"], 1.1)
	if snake:
		add_child(snake)
		snake.idle_at(Vector3(-12.4, 0, -12.6), 200)
