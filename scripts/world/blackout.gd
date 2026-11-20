class_name BlackoutZone
extends Zone
## BLACKOUT - nyctophobia. Larkspur Lane, a cul-de-sac like the one you grew up on, after midnight, with the
## power out. Every house dark. The streetlights go out when you aren't looking at them, and the dark is not
## empty: stay in it too long and it takes you.
##
##  1 The lane        streetlight to streetlight, north. A dead lamp makes a long dark stretch: run it.
##  2 The tree        a tree down across the road, live wires sparking in it. The only way on is through number 9.
##  3 Number 9        dark rooms. A lamp in the living room. A red darkroom bulb in the garage, and under red
##                    light things are there that aren't there otherwise: writing on the wall, and the key to
##                    the padlocked back door.
##  4 The gardens     back gardens along the fence, yard lights, round to the end of the street.
##  5 The box         the junction box: every light on the street comes on - and shows you the shadows of a
##                    crowd standing in the road, with nobody there to cast them. Then the lights die, one by
##                    one, from the far end, coming for you. The night bus is waiting.

const ROAD_W := 4.0
const NORTH := -118.0
const TREE_Z := -55.0
const BOX := Vector3(-9.0, 0, -113.0)
const BUS_DOOR := Vector3(-17.5, 0, -115.6)
const DARK_LIMIT := 7.0
## Checkpoints (see Zone.checkpoint_at): number 9's lamp, the back garden.
const CHECKPOINTS := {
	"house": [Vector3(14.6, 0.05, -41.5), -90.0, ["bo_tree", "bo_inside", "bo_lamp"]],
	"garden": [Vector3(28.5, 0.05, -48.0), 0.0, ["bo_tree", "bo_inside", "bo_lamp", "bo_key", "bo_backyard"]],
}          # seconds of unbroken dark before it has you

const ASPHALT := Color(0.16, 0.16, 0.17)
const PAVEMENT := Color(0.42, 0.41, 0.4)
const GRASS := Color(0.16, 0.22, 0.12)
const SIDING := [Color(0.62, 0.6, 0.55), Color(0.5, 0.56, 0.6), Color(0.66, 0.58, 0.5), Color(0.55, 0.6, 0.52)]
const ROOF := Color(0.18, 0.16, 0.16)
const LAMP_COL := Color(1.0, 0.78, 0.5)

var observer: Observer
var _lamps: Array = []           # {pos, light, bulb, on, dead, unseen, seen, buzz, kind}
var _sources: Array = []         # {pos, r, on} - everything that counts as light
var _windows: Array[MeshInstance3D] = []
var _shadows: Array[Node3D] = []
var _crowd: Array[Node3D] = []
var _dark_t := 0.0
var _dark_warned := 0
var _t := 0.0
var _hint := 0
var _living_light: Dictionary
var _red_light: Dictionary
var _red_lamp: OmniLight3D
var _red_only: Array[Node3D] = []   # only visible under the red bulb
var _key: Node3D
var _back_block: StaticBody3D
var _back_door: Node3D
var _gate: Node3D
var _gate_block: StaticBody3D
var _wires: Array = []           # [light, spark mesh]
var _spark_t := 0.0
var _wave_t := -1.0
var _bus: Node3D
var _bus_light: Dictionary
var _obs_t := 25.0
var no_dark_death := false       # (tests and screenshots)


func zone_id() -> String: return "blackout"
func is_nightmare() -> bool: return true
func fear_floor() -> float: return 12.0
func fear_decay() -> float: return 1.5
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.6
func sprint_speed() -> float: return 4.3
## A light can be pictured here (hold Q) - a weak one: the dark still counts.
func allows_manifestation() -> bool: return true
func manifest_allowlist() -> Array: return ["flashlight"]
func flashlight_scale() -> float: return 0.4


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(1.5, 0.05, 1.0))


# ------------------------------------------------------------------ build

func build() -> void:
	_ground()
	_houses()
	_lane_lamps()
	_tree()
	_house9()
	_gardens()
	_end_of_street()
	_shadow_people()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen_max_distance = 90.0
	observer.seen.connect(func():
		Game.set_flag("observer_blackout")
		Game.player.dread.add_dread(observer.spot_dread))
	observer.vanished.connect(func(): _obs_t = randf_range(30.0, 60.0))

	var env := make_env(Color(0.25, 0.3, 0.45), 0.035)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.03)
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.025, 0.04)
	env.fog_density = 0.035
	environment(env)
	ambient("chirp", Vector3(-20, 1, -30), true, -14.0, 40.0)
	ambient("chirp", Vector3(25, 1, -90), true, -16.0, 40.0)
	ambient("wind", Vector3.ZERO, false, -26.0)
	ambient("drone", Vector3.ZERO, false, -30.0)


func _ground() -> void:
	var mid_z := (6.0 + NORTH) * 0.5
	var len_z := 6.0 - NORTH + 4.0
	box(Vector3(0, -0.05, mid_z), Vector3(ROAD_W * 2.0, 0.1, len_z), ASPHALT, true, 0.0, "asphalt")
	for s in [-1.0, 1.0]:
		box(Vector3(s * (ROAD_W + 1.0), 0.06, mid_z), Vector3(2.0, 0.12, len_z), PAVEMENT, true, 0.0, "pavers")
		box(Vector3(s * 20.0, -0.05, mid_z), Vector3(28.0, 0.1, len_z), GRASS, true, 0.0, "grass")
		# a dashed centre line, and kerbs
		box(Vector3(s * ROAD_W, 0.08, mid_z), Vector3(0.15, 0.16, len_z), PAVEMENT.darkened(0.2), false, 0.0, "concrete")
	for k in 22:
		box(Vector3(0, 0.005, 3.0 - k * 5.6), Vector3(0.12, 0.01, 2.4), Color(0.75, 0.72, 0.6), false)
	# manhole covers and drains down the road, poles and wires down the left side
	for k in 6:
		prop("manhole", Vector3(-1.2 + (k % 2) * 2.4, 0.004, -8.0 - k * 18.0), randf() * 360.0)
		for s in [-1.0, 1.0]:
			part("box", Vector3(s * (ROAD_W - 0.3), 0.004, -14.0 - k * 18.0), Vector3(0.4, 0.01, 0.9), Color(0.05, 0.05, 0.05), null, Vector3.ZERO, 0.0, "metal")
	_poles()
	# the cross street at the north end, and the turning circle at the south
	box(Vector3(-15, -0.04, NORTH + 3.0), Vector3(30, 0.1, 8), ASPHALT, true, 0.0, "asphalt")
	shape_at("cylinder", Vector3(0, -0.045, 3.0), Vector3(12, 0.1, 12), ASPHALT, true, Vector3.ZERO, "asphalt")
	# the edges of the world: fences
	_fence(Vector3(-34, 0, 6), Vector3(34, 0, 6))
	_fence(Vector3(-34, 0, 6), Vector3(-34, 0, NORTH - 2))
	_fence(Vector3(34, 0, 6), Vector3(34, 0, NORTH - 2))
	_fence(Vector3(-34, 0, NORTH - 2), Vector3(34, 0, NORTH - 2))
	label(Vector3(-6.2, 2.3, 1.5), 90, "LARKSPUR LANE", 0.12, Color(0.85, 0.85, 0.8), false)
	part("box", Vector3(-6.25, 2.3, 1.5), Vector3(0.04, 0.3, 1.6), Color(0.1, 0.3, 0.15))
	part("cylinder", Vector3(-6.3, 1.2, 1.5), Vector3(0.06, 2.4, 0.06), Color(0.4, 0.4, 0.4))
	label(Vector3(-6.2, 1.85, 1.5), 90, "NO THROUGH ROAD", 0.06, Color(0.85, 0.2, 0.15), false)


## A garden fence from a to b (straight along x or z), 1.6 m: you don't climb it.
func _fence(a: Vector3, b: Vector3, col := Color(0.32, 0.27, 0.2)) -> void:
	var c := (a + b) * 0.5
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var ln := (b - a).length()
	if Props.has("fence_panel") and ln > 0.5:
		# slatted panels between posts (one MultiMesh for all of them), and a wall you can't see to stop you
		blocker(c + Vector3(0, 0.8, 0), Vector3(ln, 1.6, 0.12) if along_x else Vector3(0.12, 1.6, ln))
		var n := maxi(1, roundi(ln / 2.4))
		var yaw := 0.0 if along_x else PI * 0.5
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			scatter("fence_panel", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(ln / n / 2.4, 1.0, 1.0)), p), col.lightened(0.6))
		return
	box(c + Vector3(0, 0.8, 0), Vector3(ln, 1.6, 0.08) if along_x else Vector3(0.08, 1.6, ln), col, true, 0.0, "wood")
	var posts := int(ln / 2.5)
	for k in posts + 1:
		var p := a.lerp(b, float(k) / maxf(posts, 1))
		box(p + Vector3(0, 0.85, 0), Vector3(0.12, 1.7, 0.12), col.darkened(0.2), false, 0.0, "wood")


func _house(center: Vector3, face: float, col: Color, number: int, solid := true) -> void:
	# face: +1 = front faces +x (left side of the road), -1 = faces -x
	if solid and _house_model(center, face, col, number):
		return
	var w := 12.0
	var d := 10.0
	if solid:
		box(center + Vector3(0, 2.6, 0), Vector3(w, 5.2, d), col, true, 0.0, "plaster")
	for s in [-1.0, 1.0]:
		var r := part("box", center + Vector3(s * w * 0.25, 5.2 + 1.3, 0), Vector3(w * 0.58, 0.25, d + 0.6), ROOF, null, Vector3(0, 0, -s * 30), 0.0, "concrete")
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# front: a door, two windows (dark) and a porch step
	var fx := center.x + face * w * 0.5
	if solid:
		part("box", Vector3(fx + face * 0.03, 1.05, center.z), Vector3(0.06, 2.1, 1.0), col.darkened(0.45), null, Vector3.ZERO, 0.0, "wood")
	box(Vector3(fx + face * 0.6, 0.1, center.z), Vector3(1.2, 0.2, 2.0), PAVEMENT, true, 0.0, "concrete")
	for wz in [-3.0, 3.0]:
		for wy in [1.6, 4.0]:
			var win := part("box", Vector3(fx + face * 0.03, wy, center.z + wz), Vector3(0.05, 1.2, 1.4), Color(0.03, 0.03, 0.04), null, Vector3.ZERO, 0.0, 0.2)
			_windows.append(win)
	label(Vector3(fx + face * 0.07, 2.4, center.z + 0.9), 90.0 * face, str(number), 0.12, Color(0.75, 0.72, 0.6), false)
	# a path across the lawn, porch to pavement
	var xa := fx + face * 1.2
	var xb := signf(center.x) * (ROAD_W + 2.0)
	box(Vector3((xa + xb) * 0.5, 0.01, center.z), Vector3(absf(xa - xb), 0.02, 1.2), PAVEMENT.darkened(0.15), false, 0.0, "concrete")


## A house from the models (tools/creatures/suburb.py): siding tinted, windows that can light up.
func _house_model(center: Vector3, face: float, col: Color, number: int) -> bool:
	var slot := "house_a" if number % 2 == 0 else "house_b"
	var h := prop(slot, center, 0.0 if face > 0 else 180.0)
	if h == null:
		return false
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name).begins_with("Windows"):
			_windows.append(m)
			continue
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat and String(mat.resource_name).contains("wall") and mat is StandardMaterial3D:
				var tinted := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				tinted.albedo_color = col
				m.set_surface_override_material(k, tinted)
	blocker(center + Vector3(0, 2.6, 0), Vector3(10.0, 5.2, 12.0))
	var fx := center.x + face * 5.0
	label(Vector3(fx + face * 0.12, 2.9, center.z + 0.9), 90.0 * face, str(number), 0.12, Color(0.85, 0.8, 0.6), false)
	var xa := fx + face * (2.6 if slot == "house_a" else 0.4)
	var xb := signf(center.x) * (ROAD_W + 2.0)
	box(Vector3((xa + xb) * 0.5, 0.01, center.z), Vector3(absf(xa - xb), 0.02, 1.4), PAVEMENT.darkened(0.15), false, 0.0, "pavers")
	prop("mailbox", Vector3(xb + face * 0.6, 0.0, center.z + 1.2), 0.0 if face > 0 else 180.0)
	if slot == "house_a":
		blocker(Vector3(fx + face * 1.1, 0.25, center.z), Vector3(2.2, 0.5, 4.4))   # the porch deck
	return true


## Wooden utility poles down the left side of the road, and the wires sagging between them.
func _poles() -> void:
	var tops: Array = []
	for k in 6:
		var z := 0.0 - k * 22.0
		if absf(z - TREE_Z) < 6.0:
			continue
		var at := Vector3(-ROAD_W - 1.7, 0, z)
		if prop("utility_pole", at, 0.0) == null:
			return
		blocker(at + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3))
		tops.append(at)
	# three wires from crossarm to crossarm, each a sagging curve of short segments
	for k in tops.size() - 1:
		var a: Vector3 = tops[k]
		var b: Vector3 = tops[k + 1]
		for off in [-1.0, 0.35, 1.0]:
			var p0 := a + Vector3(0, 7.98, -off)
			var p1 := b + Vector3(0, 7.98, -off)
			var segs := 10
			var prev := p0
			for i in range(1, segs + 1):
				var t := float(i) / segs
				var p := p0.lerp(p1, t) + Vector3(0, -1.1 * 4.0 * t * (1.0 - t), 0)
				var yv := p - prev
				var xv := yv.normalized().cross(Vector3.UP).normalized()
				var zv := xv.cross(yv.normalized())
				add_shape("pipe", Transform3D(Basis(xv * 0.015, yv, zv * 0.015), (prev + p) * 0.5), Color(0.03, 0.03, 0.03))
				prev = p


func _houses() -> void:
	# number 9 is built on its own (you go inside it); the others are solid blocks
	var lots := [-10.0, -27.0, -44.0, -68.0, -86.0, -104.0]
	var n := 1
	for i in lots.size():
		var z: float = lots[i]
		for s in [-1.0, 1.0]:
			if s > 0 and z == -44.0:
				n += 1
				continue
			if n == 9:
				n += 1        # (there's only one number 9)
			_house(Vector3(s * 18.0, 0, z), -s, SIDING[(i * 2 + (0 if s < 0 else 1)) % SIDING.size()], n)
			n += 1
			# a car in some of the driveways, a bin by the kerb
			if (i + int(s)) % 3 == 0:
				prop("car_%d" % ((i + 1) % 5), Vector3(s * 9.0, 0, z + 4.0), 90 if s < 0 else -90)
			prop("bin", Vector3(s * 6.4, 0.12, z + 2.5))
	for z in [-18.0, -36.0, -76.0, -95.0]:
		for s in [-1.0, 1.0]:
			prop(["tree_maple", "tree_elm", "tree_oak"][int(absf(z) + s) % 3], Vector3(s * 7.5, 0, z), randf() * 360.0, 0.8)
	prop("hydrant", Vector3(4.8, 0.12, -20.0))


# ------------------------------------------------------------------ light and dark

## A streetlight. kind: "street" (goes out when you aren't looking), "yard" (same), "fixed" (stays as set).
func _lamp(pos: Vector3, on := true, dead := false, kind := "street", r := 5.5) -> Dictionary:
	var model: Node3D = prop("lamp_post", pos) if kind == "street" else null
	if model == null:
		var ph := 4.8 if kind == "street" else 2.6
		shape_at("cylinder", pos + Vector3(0, ph * 0.5, 0), Vector3(0.1, ph, 0.1), Color(0.25, 0.25, 0.26), true, Vector3.ZERO, "metal")
	var head := pos + Vector3(0, 4.6 if kind == "street" else 2.6, 0)
	var bulb := part("sphere", head, Vector3(0.35, 0.18, 0.35), LAMP_COL, null, Vector3.ZERO, 3.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := spot(head + Vector3(0, -0.2, 0), pos + Vector3(0.4, -1, 0.1), LAMP_COL, 6.0, 12.0, 58.0, false)
	var src := {"pos": pos, "r": r, "on": on and not dead}
	_sources.append(src)
	var lamp := {"pos": pos, "light": l, "bulb": bulb, "on": on and not dead, "dead": dead, "unseen": 0.0, "seen": 0.0,
		"kind": kind, "src": src, "head": head}
	_set_lamp(lamp, lamp.on, true)
	_lamps.append(lamp)
	return lamp


func _set_lamp(lamp: Dictionary, on: bool, quiet := false) -> void:
	lamp.on = on
	lamp.src.on = on
	(lamp.light as Light3D).visible = on
	(lamp.bulb as MeshInstance3D).material_override = Shapes.material(LAMP_COL, 0.4, 3.0) if on else Shapes.material(Color(0.15, 0.14, 0.12))
	if not quiet:
		if on:
			Sfx.play_at("switch", self, lamp.head, -6.0, 30.0)
		else:
			Sfx.play_at("switch", self, lamp.head, -2.0, 40.0)
			Sfx.play_at("static_burst", self, lamp.head, -16.0, 25.0)


## Light that stays as it's set (a lamp in a room, a porch light, the bus).
func _fixed_light(pos: Vector3, r: float, col: Color, energy: float, on := false) -> Dictionary:
	var l := omni(pos + Vector3(0, 2.2, 0), col, energy, r * 1.6, false)
	l.visible = on
	var src := {"pos": pos, "r": r, "on": on, "light": l}
	_sources.append(src)
	return src


func _set_fixed(src: Dictionary, on: bool) -> void:
	src.on = on
	(src.light as Light3D).visible = on


func _lane_lamps() -> void:
	# south half: alternate sides, one of them dead
	var south := [[5.0, 0.0, false], [-5.0, -11.0, false], [5.0, -22.0, false], [-5.0, -33.0, true], [5.0, -43.0, false]]
	for s in south:
		_lamp(Vector3(s[0], 0.12, s[1]), true, s[2])
	var north := [[-5.0, -64.0, false], [5.0, -75.0, false], [-5.0, -86.0, true], [5.0, -97.0, false], [-5.0, -108.0, false]]
	for s in north:
		_lamp(Vector3(s[0], 0.12, s[1]), false, s[2])
	# porch light at number 4 (the long dark stretch): a switch by its gate
	var porch := _fixed_light(Vector3(-8.0, 0, -27.0), 6.0, Color(1.0, 0.85, 0.6), 2.5)
	part("box", Vector3(-6.3, 1.0, -25.6), Vector3(0.12, 0.2, 0.08), Color(0.9, 0.88, 0.8))
	interactable(Vector3(-6.3, 1.0, -25.6), Vector3(0.5, 0.5, 0.5), func(): return "Porch light" if not porch.on else "",
		func():
			_set_fixed(porch, true)
			Sfx.play("switch", -4.0)
			Game.hud.show_thought("Light. Somebody's porch light. Thank you, whoever you are.", 3.0),
		func(): return not porch.on)


func _lit(p: Vector3) -> bool:
	for s in _sources:
		if s.on and Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < s.r:
			return true
	return false


func _update_lamps(delta: float, p: Vector3) -> void:
	for lamp in _lamps:
		if lamp.dead or lamp.kind == "fixed" or _wave_t >= 0.0:
			continue
		var seen := Observation.is_observed(lamp.head, 0.6)
		var near := Vector2(p.x - lamp.pos.x, p.z - lamp.pos.z).length()
		if lamp.on:
			# unwatched (and you're not standing in it): it goes out
			if seen or near < lamp.src.r:
				lamp.unseen = 0.0
			else:
				lamp.unseen += delta
				if lamp.unseen > 1.6:
					_set_lamp(lamp, false)
		else:
			# look at it, and it comes back - if you're close enough to want it
			if seen and near < 26.0:
				lamp.seen += delta
				if lamp.seen > 0.5:
					lamp.seen = 0.0
					_set_lamp(lamp, true)
			else:
				lamp.seen = 0.0


func _update_dark(delta: float, p: Vector3) -> void:
	var dark := not _lit(p)
	var pl: Player = Game.player
	if dark:
		_dark_t += delta * (0.35 if pl.manifestation.is_holding("flashlight") else 1.0)   # a torch only buys you time
		if pl.dread.fear < 85.0:
			pl.dread.add_fear(5.0 * delta, "the dark")
		if _dark_t > 2.5 and _dark_warned == 0:
			_dark_warned = 1
			Game.hud.show_thought("Get back in the light. GET BACK IN THE LIGHT.", 2.5)
			Sfx.play("whisper", -4.0, 0.9)
		var k := clampf(_dark_t / DARK_LIMIT, 0.0, 1.0)
		Game.hud.set_post(0.35 + 0.6 * k, 0.2 + 0.4 * k, 0.6 + 0.4 * k, 1.0 + k)
		if _dark_t > DARK_LIMIT and not no_dark_death:
			Game.entity_death("shadow")
	else:
		_dark_t = maxf(0.0, _dark_t - delta * 2.5)
		if _dark_t < 0.5:
			_dark_warned = 0


# ------------------------------------------------------------------ the tree

func _tree() -> void:
	# an oak down across the road, roots torn up on the left, the crown in the right-hand garden
	var trunk := part("cylinder", Vector3(0, 0.75, TREE_Z), Vector3(1.4, 18.0, 1.4), Color(0.25, 0.19, 0.13), null, Vector3(0, 0, 88), 0.0, "wood")
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	blocker(Vector3(0, 1.3, TREE_Z), Vector3(18.0, 2.6, 1.6))
	shape_at("sphere", Vector3(-9.5, 1.2, TREE_Z), Vector3(3.0, 2.6, 2.4), Color(0.2, 0.15, 0.1), true, Vector3.ZERO, "concrete")   # the root plate
	for k in 7:
		var bx := 4.0 + k * 1.2
		part("cylinder", Vector3(bx, 1.8 + (k % 3) * 0.4, TREE_Z + (k % 2 - 0.5) * 1.6), Vector3(0.25, 3.0, 0.25), Color(0.24, 0.18, 0.12), null,
			Vector3(randf_range(-60, 60), 0, randf_range(30, 70)), 0.0, "wood")
	prop("tree_oak", Vector3(10.0, 0.3, TREE_Z), 0, 1.0)
	# fences along the line of the tree, garden to garden: no way round on the left; number 9 on the right
	_fence(Vector3(-34, 0, TREE_Z), Vector3(-ROAD_W - 2.0, 0, TREE_Z))
	_fence(Vector3(ROAD_W + 2.0, 0, TREE_Z), Vector3(8.0, 0, TREE_Z))
	# the power line it brought down, sparking
	for k in 3:
		var at := Vector3(-2.5 + k * 2.4, 0.15, TREE_Z + 1.6 + k * 0.3)
		var spark := part("sphere", at, Vector3.ONE * 0.12, Color(0.7, 0.85, 1.0), null, Vector3.ZERO, 6.0)
		var l := omni(at + Vector3(0, 0.3, 0), Color(0.6, 0.8, 1.0), 0.0, 6.0, false)
		_wires.append([l, spark])
		part("cylinder", at + Vector3(0, 2.4, 0), Vector3(0.025, 4.8, 0.025), Color(0.05, 0.05, 0.05), null, Vector3(randf_range(-25, 25), 0, randf_range(-25, 25)))
	ambient("buzz", Vector3(0, 0.5, TREE_Z + 2.0), true, -6.0, 18.0)
	trigger(Vector3(0, 1.2, TREE_Z + 5.0), Vector3(12, 2.4, 3), func():
		Game.set_flag("bo_tree")
		Game.hud.show_thought("The whole tree's come down. And the wires with it - don't touch them. ...Number 9's door is open.", 4.5))


func _update_wires(delta: float) -> void:
	_spark_t -= delta
	for w in _wires:
		(w[0] as OmniLight3D).light_energy = maxf(0.0, (w[0] as OmniLight3D).light_energy - delta * 20.0)
		(w[1] as MeshInstance3D).visible = (w[0] as OmniLight3D).light_energy > 0.2
	if _spark_t <= 0.0 and Settings.flashing_ok():
		_spark_t = randf_range(0.15, 1.4)
		var w: Array = _wires.pick_random()
		(w[0] as OmniLight3D).light_energy = randf_range(2.0, 5.0)
		Sfx.play_at("static_burst", self, (w[1] as Node3D).global_position, -10.0, 20.0)


# ------------------------------------------------------------------ number 9

func _house9() -> void:
	# x 12..24, z -39..-49. Front door (x = 12, z = -41.5) into the living room; kitchen behind it; the garage
	# along the south side; the back door out of the kitchen (x = 24).
	var col: Color = SIDING[1]
	var x0 := 12.0
	var x1 := 24.0
	var z0 := -39.0
	var z1 := -49.0
	var H := 2.8
	var wall := Color(0.55, 0.52, 0.46)
	box(Vector3(18, 0.02, -44), Vector3(12, 0.04, 10), Color(0.35, 0.28, 0.2), true, 0.0, "wood")
	box(Vector3(18, H + 0.1, -44), Vector3(12.4, 0.2, 10.4), Color(0.4, 0.38, 0.35), true, 0.0, "plaster")
	_house(Vector3(18, 0, -44), -1.0, col, 9, false)
	# outer walls, with the front door, the back door and the garage's dead roller door
	_wall_x(x0, z0, z1, [[-41.5, 1.0]], H, col)          # front
	_wall_x(x1, z0, z1, [[-41.5, 1.0]], H, col)          # back
	box(Vector3(18, H * 0.5, z0), Vector3(12, H, 0.2), col, true, 0.0, "plaster")
	box(Vector3(18, H * 0.5, z1), Vector3(12, H, 0.2), col, true, 0.0, "plaster")
	# inside: living room | kitchen (x = 18), and the garage behind a wall at z = -44
	_wall_x(18.0, z0, -44.0, [[-41.5, 1.0]], H, wall)
	_wall_z(-44.0, x0, x1, [[15.0, 1.0]], H, wall)
	# the front door stands open
	var fd := door(Vector3(x0, 0, -41.5), -90, Color(0.3, 0.2, 0.15), 0.95)
	open_door(fd, 100.0, 0.01)
	# the back door: padlocked
	_back_door = door(Vector3(x1, 0, -41.5), 90, Color(0.3, 0.2, 0.15), 0.95)
	_back_block = solid_box(Vector3(x1, 1.05, -41.5), Vector3(0.15, 2.1, 1.0), Color(0, 0, 0))
	_back_block.get_child(1).visible = false
	part("box", Vector3(x1 - 0.12, 1.05, -41.1), Vector3(0.05, 0.12, 0.08), Color(0.6, 0.55, 0.3), null, Vector3.ZERO, 0.0, "metal")
	interactable(Vector3(x1 - 0.3, 1.1, -41.5), Vector3(0.5, 1.6, 1.0),
		func(): return "Unlock the padlock" if Game.has_flag("bo_key") else "Back door",
		func(): _try_back_door(), func(): return _back_block != null)
	# the living room: a sofa, a TV, family photos with the faces gone, a lamp
	box(Vector3(13.4, 0.4, -40.2), Vector3(0.9, 0.8, 2.2), Color(0.35, 0.3, 0.45), true, 0.0, "fabric")
	box(Vector3(16.2, 0.35, -39.4), Vector3(1.4, 0.7, 0.45), Color(0.1, 0.1, 0.1), true, 0.0, "wood")
	part("box", Vector3(16.2, 1.0, -39.45), Vector3(1.0, 0.6, 0.05), Color(0.02, 0.02, 0.03), null, Vector3.ZERO, 0.0, 0.1)
	for k in 3:
		var fp := Vector3(14.0 + k * 1.2, 1.6, z0 + 0.12)
		part("box", fp, Vector3(0.5, 0.4, 0.03), Color(0.3, 0.22, 0.15))
		part("box", fp + Vector3(0, 0, 0.02), Vector3(0.42, 0.32, 0.01), Color(0.55, 0.5, 0.45))
		for f in 2:
			part("sphere", fp + Vector3(-0.08 + f * 0.16, 0.0, 0.03), Vector3(0.07, 0.08, 0.01), Color(0.02, 0.02, 0.02))
	_living_light = _fixed_light(Vector3(15.0, 0, -41.5), 4.2, Color(1.0, 0.8, 0.55), 1.2)
	shape_at("cylinder", Vector3(12.6, 0.75, -39.6), Vector3(0.05, 1.5, 0.05), Color(0.2, 0.2, 0.2))
	shape_at("cone", Vector3(12.6, 1.6, -39.6), Vector3(0.4, 0.35, 0.4), Color(0.85, 0.8, 0.65))
	interactable(Vector3(12.6, 1.2, -39.6), Vector3(0.6, 1.0, 0.6), func(): return "Switch on the lamp" if not _living_light.on else "",
		func():
			_set_fixed(_living_light, true)
			Game.set_flag("bo_lamp")
			checkpoint_at("house")
			Sfx.play("switch", -4.0)
			Game.hud.show_thought("The lamp works. The photos... they've all got their faces scratched out.", 3.5),
		func(): return not _living_light.on)
	# the kitchen: dark, a table, the fridge humming with no power
	box(Vector3(20.8, 0.4, -39.8), Vector3(1.4, 0.8, 0.9), Color(0.45, 0.35, 0.25), true, 0.0, "wood")
	box(Vector3(23.4, 0.95, -39.6), Vector3(0.7, 1.9, 0.8), Color(0.85, 0.85, 0.82), true, 0.0, "metal")
	ambient("hum", Vector3(23.4, 1.0, -39.6), true, -18.0, 6.0)
	# the garage: a darkroom in the corner, a red bulb on a pull cord
	box(Vector3(18, 0.45, -48.4), Vector3(3.0, 0.9, 0.8), Color(0.4, 0.33, 0.25), true, 0.0, "wood")
	for k in 4:
		part("box", Vector3(16.8 + k * 0.8, 1.6, -48.9), Vector3(0.6, 0.45, 0.01), Color(0.85, 0.83, 0.78))   # prints, pegged up to dry
		part("cylinder", Vector3(17.9, 1.85, -48.9), Vector3(0.008, 4.0, 0.008), Color(0.1, 0.1, 0.1), null, Vector3(0, 0, 90))
	_red_lamp = omni(Vector3(18.0, 2.3, -46.5), Color(1.0, 0.08, 0.04), 1.6, 6.0, false)
	_red_lamp.visible = false
	_red_light = {"pos": Vector3(18.0, 0, -46.5), "r": 4.0, "on": false, "light": _red_lamp}
	_sources.append(_red_light)
	part("sphere", Vector3(18.0, 2.45, -46.5), Vector3.ONE * 0.14, Color(0.4, 0.05, 0.03))
	part("cylinder", Vector3(18.0, 1.95, -46.5), Vector3(0.006, 0.9, 0.006), Color(0.6, 0.6, 0.55))
	interactable(Vector3(18.0, 1.5, -46.5), Vector3(0.4, 0.6, 0.4), func(): return "Pull the cord" if not _red_light.on else "",
		func(): _red_on(), func(): return not _red_light.on)
	# only there under the red: writing, and the key on its hook
	var words := label(Vector3(21.5, 1.6, -48.88), 0, "THE BOX AT THE END OF THE STREET.\nPUT THE LIGHTS ON.\nTHEN RUN FOR THE BUS.\nDON'T LOOK BACK.", 0.1, Color(1.0, 0.25, 0.15), true)
	words.visible = false
	_red_only.append(words)
	_key = group(Vector3(14.2, 1.5, -48.85))
	part("box", Vector3.ZERO, Vector3(0.03, 0.08, 0.02), Color(0.7, 0.6, 0.3), _key, Vector3.ZERO, 0.0, "metal")
	part("sphere", Vector3(0, 0.06, 0), Vector3(0.05, 0.05, 0.01), Color(0.7, 0.6, 0.3), _key, Vector3.ZERO, 0.0, "metal")
	_key.visible = false
	_red_only.append(_key)
	interactable(Vector3(14.2, 1.5, -48.7), Vector3(0.5, 0.5, 0.4), func(): return "Take the key",
		func():
			_key.visible = false
			_red_only.erase(_key)
			Game.set_flag("bo_key")
			Sfx.play("page", -6.0, 1.3)
			Game.hud.show_thought("A padlock key. It wasn't there with the light off. I'd have seen it. I'd have seen it.", 4.0),
		func(): return _key.visible)
	trigger(Vector3(15, 1.2, -41.5), Vector3(5, 2.4, 4), func():
		Game.set_flag("bo_inside")
		Game.hud.show_thought("Hello? ...The door was open. I'm just passing through.", 3.0))


## A wall along z at x, from z0 to z1, with doorways [[z, width], ...].
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
		if cuts[i + 1] - cuts[i] > 0.05:
			box(Vector3(x, h * 0.5, (cuts[i] + cuts[i + 1]) * 0.5), Vector3(0.2, h, cuts[i + 1] - cuts[i]), col, true, 0.0, "plaster")
	for g in gaps:
		box(Vector3(x, h - 0.3, g[0]), Vector3(0.2, 0.6, g[1] + 0.1), col, true, 0.0, "plaster")


func _wall_z(z: float, x0: float, x1: float, gaps: Array, h: float, col: Color) -> void:
	var cuts := [x0]
	for g in gaps:
		cuts.append(g[0] - g[1] * 0.5 - 0.05)
		cuts.append(g[0] + g[1] * 0.5 + 0.05)
	cuts.append(x1)
	cuts.sort()
	for i in range(0, cuts.size(), 2):
		if cuts[i + 1] - cuts[i] > 0.05:
			box(Vector3((cuts[i] + cuts[i + 1]) * 0.5, h * 0.5, z), Vector3(cuts[i + 1] - cuts[i], h, 0.2), col, true, 0.0, "plaster")
	for g in gaps:
		box(Vector3(g[0], h - 0.3, z), Vector3(g[1] + 0.1, 0.6, 0.2), col, true, 0.0, "plaster")


func _red_on() -> void:
	_set_fixed(_red_light, true)
	Sfx.play("switch", -4.0, 0.8)
	Game.player.dread.add_fear(4.0, "red")
	Game.hud.show_thought("Red. Everything's red. ...There's writing on the wall. That wasn't there.", 4.0)
	Game.set_flag("bo_red")


func _try_back_door() -> void:
	if not Game.has_flag("bo_key"):
		Sfx.play("knock", -6.0, 1.4)
		Game.hud.show_thought("Bolted, with a padlock. From the inside. Somebody wanted to keep the garden out.", 3.5)
		return
	_back_block.queue_free()
	_back_block = null
	open_door(_back_door, -100.0, 1.0)
	Sfx.play("door_creak", -4.0)
	Game.set_flag("bo_backyard")
	checkpoint_at("garden")
	Game.hud.show_thought("Out the back. The gardens run along behind the houses. Keep to the lights.", 3.5)


# ------------------------------------------------------------------ the gardens

func _gardens() -> void:
	# number 9's plot is fenced on all sides: the only way into its back garden is through the house
	_fence(Vector3(8, 0, -36), Vector3(34, 0, -36))
	_fence(Vector3(8, 0, -36), Vector3(8, 0, -40.5))
	_fence(Vector3(8, 0, -47.5), Vector3(8, 0, TREE_Z))
	_fence(Vector3(8, 0, -40.5), Vector3(12, 0, -40.5))
	_fence(Vector3(8, 0, -47.5), Vector3(12, 0, -47.5))
	_fence(Vector3(8, 0, TREE_Z), Vector3(28.6, 0, TREE_Z))
	_fence(Vector3(31.4, 0, TREE_Z), Vector3(34, 0, TREE_Z))
	_fence(Vector3(12, 0, -39), Vector3(12, 0, -36))
	_fence(Vector3(12, 0, -49), Vector3(12, 0, TREE_Z))
	# a gate in the back fence, into the next garden
	_gate = group(Vector3(28.6, 0, TREE_Z))
	if prop("gate_arch", Vector3.ZERO, 0.0, 1.0, _gate) == null:
		part("box", Vector3(1.4, 0.8, 0), Vector3(2.8, 1.6, 0.06), Color(0.3, 0.25, 0.18), _gate, Vector3.ZERO, 0.0, "wood")
	for x in [28.45, 31.55]:     # gateposts
		box(Vector3(x, 0.95, TREE_Z), Vector3(0.22, 1.9, 0.22), Color(0.88, 0.88, 0.84), true, 0.0, "wood")
	_gate_block = solid_box(Vector3(30, 0.8, TREE_Z), Vector3(2.8, 1.6, 0.1), Color(0, 0, 0))
	_gate_block.get_child(1).visible = false
	interactable(Vector3(30, 1.0, TREE_Z + 0.3), Vector3(2.8, 1.6, 0.6), func(): return "Open the gate",
		func():
			_gate_block.queue_free()
			_gate_block = null
			Game.set_flag("bo_gate")
			create_tween().tween_property(_gate, "rotation_degrees:y", -95.0, 1.0)
			Sfx.play("creak", -4.0, 1.2),
		func(): return _gate_block != null)
	# yard lights along the gardens: these go out unwatched as well
	for z in [-50.0, -62.0, -74.0, -86.0, -98.0, -109.0]:
		_lamp(Vector3(30.0, 0, z), z > -55.0, false, "yard", 5.0)
	# washing lines, a trampoline, a shed
	box(Vector3(26, 1.1, -91), Vector3(2.2, 2.2, 3.0), Color(0.35, 0.3, 0.22), true, 0.0, "wood")
	shape_at("cylinder", Vector3(31, 0.45, -80), Vector3(3.2, 0.06, 3.2), Color(0.08, 0.08, 0.1), false)
	for k in 4:
		part("cylinder", Vector3(31 + cos(k * TAU / 4.0) * 1.5, 0.22, -80 + sin(k * TAU / 4.0) * 1.5), Vector3(0.05, 0.45, 0.05), Color(0.3, 0.3, 0.3))
	trigger(Vector3(30, 1.2, -60), Vector3(8, 2.4, 3), func():
		Game.hud.show_thought("The gardens. All the way along. ...Somebody's left their swing going.", 3.0))


# ------------------------------------------------------------------ the end of the street

func _end_of_street() -> void:
	# the junction box: green metal, a big lever
	box(BOX + Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 0.6), Color(0.15, 0.3, 0.2), true, 0.0, "metal")
	label(BOX + Vector3(0, 1.4, 0.31), 0, "DANGER\nLARKSPUR LANE\nSUPPLY", 0.05, Color(0.95, 0.85, 0.2), false)
	part("box", BOX + Vector3(0.45, 1.0, 0.36), Vector3(0.06, 0.4, 0.06), Color(0.7, 0.15, 0.1), null, Vector3(-30, 0, 0), 0.0, "metal")
	interactable(BOX + Vector3(0, 1.0, 0.5), Vector3(1.4, 1.4, 0.6), func(): return "Throw the switch" if not Game.has_flag("bo_power") else "",
		func(): _power_on(), func(): return not Game.has_flag("bo_power"))
	_lamp(BOX + Vector3(-1.5, 0.12, 2.5), false, false, "street")
	# along the top of the gardens to the junction, where the back fences end
	for x in [21.0, 11.0]:
		_lamp(Vector3(x, 0, -113.0), false, false, "yard", 5.5)
	# the bus shelter, on the cross street
	var sh := BUS_DOOR + Vector3(4.0, 0, -2.8)
	box(sh + Vector3(0, 2.4, 0), Vector3(3.0, 0.1, 1.4), Color(0.2, 0.22, 0.25), true, 0.0, "metal")
	box(sh + Vector3(0, 1.2, -0.65), Vector3(3.0, 2.4, 0.05), Color(0.6, 0.7, 0.75, 0.3), true, 0.0, "glass")
	box(sh + Vector3(0, 0.45, -0.3), Vector3(2.4, 0.08, 0.45), Color(0.4, 0.3, 0.2), true, 0.0, "wood")
	label(sh + Vector3(1.6, 2.2, 0.2), 0, "N2  NIGHT BUS", 0.07, Color(0.9, 0.9, 0.85), false)
	# the street name at the junction
	label(Vector3(-6.2, 2.3, NORTH + 2.0), 90, "LARKSPUR LANE", 0.12, Color(0.85, 0.85, 0.8), false)
	part("box", Vector3(-6.25, 2.3, NORTH + 2.0), Vector3(0.04, 0.3, 1.6), Color(0.1, 0.3, 0.15))
	part("cylinder", Vector3(-6.3, 1.2, NORTH + 2.0), Vector3(0.06, 2.4, 0.06), Color(0.4, 0.4, 0.4))


func _power_on() -> void:
	Game.set_flag("bo_power")
	Sfx.play("switch", 2.0, 0.6)
	Sfx.play("thud", -2.0, 0.5)
	Sfx.stinger("riser", -4.0)
	Game.hud.show_thought("Come on. Come on...", 2.0)
	await get_tree().create_timer(1.6, false).timeout
	# every light on the street, from the box outward
	Sfx.play("hum", -6.0)
	var order := _lamps.duplicate()
	order.sort_custom(func(a, b): return a.pos.distance_to(BOX) < b.pos.distance_to(BOX))
	for lamp in order:
		lamp.dead = false
		_set_lamp(lamp, true, true)
		Sfx.play_at("switch", self, lamp.head, -10.0, 40.0)
		await get_tree().create_timer(0.08, false).timeout
	for w in _windows:
		w.material_override = Shapes.material(Color(1.0, 0.82, 0.55), 0.6, 2.0)
	Game.player.dread.add_fear(6.0, "lights")
	# ...and what the light shows: the shadows of a crowd, standing in the road, with nobody to cast them
	for s in _crowd:
		s.visible = true
	Sfx.stinger("braam", 0.0)
	Sfx.play_music("suspense", 1.0)
	observer.position = Vector3(0, 0, -20)
	observer.try_appear_at(Vector3(0, 0, -20))
	Game.hud.show_thought("Shadows. All down the road. People's shadows. There's nobody there. THERE'S NOBODY THERE.", 4.5)
	await get_tree().create_timer(4.0, false).timeout
	# the bus, and then the dark, coming back up the street from the far end
	_bus_arrives()
	_wave_t = 0.0
	Sfx.play("siren", 0.0)
	Sfx.play("static_burst", 0.0, 0.5)


func _bus_arrives() -> void:
	_bus = group(BUS_DOOR + Vector3(-30.0, 0, -1.6))
	var body := Color(0.15, 0.25, 0.45)
	part("box", Vector3(0, 1.7, 0), Vector3(11.0, 2.9, 2.5), body, _bus, Vector3.ZERO, 0.0, "metal")
	part("box", Vector3(0, 2.15, 1.26), Vector3(10.0, 0.9, 0.02), Color(1.0, 0.9, 0.65), _bus, Vector3.ZERO, 2.0)
	part("box", Vector3(5.52, 2.0, 0), Vector3(0.02, 1.2, 2.2), Color(0.1, 0.12, 0.15), _bus, Vector3.ZERO, 0.0, 0.1)
	label(BUS_DOOR + Vector3(-30.0 + 5.55, 2.85, -1.6), 90, "N2  EMPORIUM", 0.12, Color(1.0, 0.75, 0.2), true).reparent(_bus)
	for s in [-0.8, 0.8]:
		part("sphere", Vector3(5.52, 0.8, s), Vector3(0.25, 0.25, 0.1), Color(1.0, 0.95, 0.8), _bus, Vector3.ZERO, 5.0)
	for wx in [-3.5, 3.5]:
		for wz in [-1.1, 1.1]:
			part("cylinder", Vector3(wx, 0.5, wz), Vector3(1.0, 0.3, 1.0), Color(0.05, 0.05, 0.05), _bus, Vector3(90, 0, 0))
	var head := SpotLight3D.new()
	head.light_color = Color(1.0, 0.95, 0.8)
	head.light_energy = 6.0
	head.spot_range = 30.0
	head.spot_angle = 30.0
	head.position = Vector3(5.6, 0.9, 0)
	head.rotation_degrees.y = -90
	_bus.add_child(head)
	create_tween().tween_property(_bus, "position:x", BUS_DOOR.x, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("motor", -2.0, 0.7)
	_bus_light = _fixed_light(BUS_DOOR + Vector3(0, 0, -0.5), 4.5, Color(1.0, 0.9, 0.7), 1.5)
	await get_tree().create_timer(3.0, false).timeout
	_set_fixed(_bus_light, true)
	Sfx.play("whoosh", -6.0, 1.5)
	interactable(BUS_DOOR + Vector3(0, 1.2, 0), Vector3(2.0, 2.4, 1.6), func(): return "Get on the bus",
		func(): Game.on_blackout_exit())
	Game.hud.show_thought("The bus! RUN!", 2.0)


func _update_wave(delta: float) -> void:
	if _wave_t < 0.0:
		return
	_wave_t += delta
	# the dark comes north up the road at a jog: a lamp at a time, the houses with it
	var front := 6.0 - _wave_t * 6.5
	for lamp in _lamps:
		if lamp.on and lamp.pos.z > front:
			_set_lamp(lamp, false)
			lamp.dead = true
	for w in _windows:
		if w.global_position.z > front and w.material_override != null:
			w.material_override = null
	for s in _crowd:
		if s.global_position.z > front:
			s.visible = false


# ------------------------------------------------------------------ shadows

func _shadow_mesh(at: Vector3, yaw: float, parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = yaw
	(parent if parent else self).add_child(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for spec in [[Vector3(0, 0.02, 1.0), Vector3(0.55, 0.01, 1.9)], [Vector3(0, 0.02, 2.15), Vector3(0.32, 0.01, 0.38)],
			[Vector3(-0.38, 0.02, 0.9), Vector3(0.14, 0.01, 1.1)], [Vector3(0.38, 0.02, 0.9), Vector3(0.14, 0.01, 1.1)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = Shapes.mesh("sphere")
		mi.position = spec[0]
		mi.scale = spec[1]
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
	return g


func _shadow_people() -> void:
	# a few, from the start: in the lamplight, the shadow of someone who isn't standing there
	for spec in [[Vector3(3.0, 0.0, -11.5), 2.4], [Vector3(-2.5, 0.0, -22.5), -0.6], [Vector3(2.0, 0.0, -64.5), 3.4], [Vector3(-1.5, 0.0, -97.0), 1.0]]:
		_shadows.append(_shadow_mesh(spec[0] + Vector3(0, 0.03, 0), spec[1]))
	# the crowd, all facing the end of the street
	for k in 26:
		var at := Vector3(randf_range(-3.6, 3.6), 0.03, randf_range(-104.0, -62.0) if k % 2 == 0 else randf_range(-50.0, -4.0))
		var s := _shadow_mesh(at, atan2(BOX.x - at.x, BOX.z - at.z))
		s.visible = false
		_crowd.append(s)


func _update_shadows(delta: float, p: Vector3) -> void:
	# when you aren't looking, they turn to point at you, and come a little closer
	for s in _shadows:
		if Observation.is_observed(s.global_position + Vector3(0, 0.2, 1.0), 1.2):
			continue
		var to := p - s.global_position
		to.y = 0.0
		if to.length() > 3.0 and to.length() < 30.0:
			s.rotation.y = lerp_angle(s.rotation.y, atan2(to.x, to.z), clampf(delta * 3.0, 0.0, 1.0))
			s.global_position += to.normalized() * delta * 0.6


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	_t = 0.0
	_hint = 2 if from_save else 0
	_dark_t = 0.0
	# back from a checkpoint: the lamp you switched on, the door you unlocked, the gate you opened
	if Game.has_flag("bo_lamp"):
		_set_fixed(_living_light, true)
	if Game.has_flag("bo_key"):
		_key.visible = false
		_red_only.erase(_key)
	if Game.has_flag("bo_backyard") and _back_block != null:
		_back_block.queue_free()
		_back_block = null
		open_door(_back_door, -100.0, 0.01)
	if Game.has_flag("bo_gate") and _gate_block != null:
		_gate_block.queue_free()
		_gate_block = null
		_gate.rotation_degrees.y = -95.0


func _process(delta: float) -> void:
	_t += delta
	_update_wires(delta)
	for o in _red_only:
		o.visible = _red_light.on and (o != _key or not Game.has_flag("bo_key"))
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_update_lamps(delta, p)
	_update_wave(delta)
	_update_dark(delta, p)
	_update_shadows(delta, p)
	_hints(p)
	if not observer.visible and _wave_t < 0.0:
		_obs_t -= delta
		if _obs_t <= 0.0:
			_obs_t = 10.0
			var lit := _lamps.filter(func(l): return l.on and l.pos.distance_to(p) > 25.0)
			if not lit.is_empty():
				observer.try_appear_at(lit.pick_random().pos + Vector3(1.2, 0, 0.5))


func _hints(p: Vector3) -> void:
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought("Larkspur Lane. ...It looks like our old street. Every house is dark.", 4.0)
	elif _hint == 1 and _t > 7.0:
		_hint = 2
		Game.hud.show_hint("Stay in the light.\nThe streetlights only stay on while you can see them.", 7.0)
	if _hint == 2 and p.z < -28.0:
		_hint = 3
		Game.hud.show_thought("That lamp's dead. It's a long way in the dark to the next one. Don't stop.", 3.5)
