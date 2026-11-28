class_name StillLifeZone
extends Zone
## STILL LIFE - automatonophobia. The Emporium: one long shopping arcade after closing. Polished floor,
## palms, benches, a dry fountain; shops down both sides behind show windows full of mannequins, under
## bright neon - every sign a little wrong. The music still playing for nobody. Escalators at the far end
## up to the gallery and the staff exit. The mannequins never move while you can see them.
##
##  1 The arcade        the doors lock behind you. The escalators at the end are shut behind a grille;
##                      the security kiosk is empty: "BACK SOON - AT DINNER (HOME & FAMILY)".
##  2 Home & Family     THE PERFECT FAMILY at dinner, the guard at the head of the table, his keys by the
##                      empty place. Sit with them. Then every window display steps out of its window.
##  3 The escalators    unlock the grille, climb the stopped escalator.
##  4 LIFELIKE          the gallery: figures each more real than the last, then people you know, then an
##                      empty plinth with your card. The lights fail behind you. The staff exit.

const HALF := 10.0             # the arcade is 20 m wide (x -10..10): a wide, bright, empty concourse
const SHOP_D := 10.0           # shops are 10 m deep
const SHOP_W := 12.0
const SHOP_H := 4.2
const CEIL := 9.0
const FIRST := -4.0            # z where the first shops begin
const SHOPS := 7               # per side
const END_Z := FIRST - SHOPS * SHOP_W          # -88: the escalator hall
const STOREY := 5.0            # the gallery floor
const ESC := Vector3(-1.6, 0, -86.0)          # bottom of the working escalator, climbing toward -z
const ESC_RUN := 8.66
const GAL_Z0 := ESC.z - ESC_RUN + 0.1          # gallery floor starts where the escalator arrives
const GAL_Z1 := -131.0
const EXIT := Vector3(0, STOREY, GAL_Z1 + 0.3)
const FAMILY := Vector3(-12.5, 0, -34.0)      # the table, in HOME & FAMILY
const SEAT := FAMILY + Vector3(1.4, 0, 0.6)
const KIOSK := Vector3(0, 0, -46.0)

const FLOOR := Color(0.86, 0.85, 0.82)
const TRIM := Color(0.18, 0.18, 0.2)
const WALL := Color(0.92, 0.9, 0.86)

## [name, neon colour, kind, quirk]. Left side (x < 0) first, front to back; then the right side.
const SHOP_SPECS := [
	["EVERYB DY", Color(1.0, 0.3, 0.7), "clothes", ""],
	["SMILE +", Color(0.2, 0.9, 1.0), "beauty", "smile"],
	["HOME & FAMILY", Color(1.0, 0.75, 0.35), "home", "family"],
	["FOREVER YOUNG", Color(0.7, 0.4, 1.0), "kids", ""],
	["ALWAYS OPEN", Color(1.0, 0.2, 0.15), "shut", ""],
	["LOST & FOUND", Color(0.3, 0.5, 1.0), "lost", "backs"],
	["PHOTO-ME", Color(1.0, 0.9, 0.2), "photo", ""],
	["FUN", Color(0.3, 1.0, 0.45), "sport", "fun_run"],
	["PERFECT FIT", Color(1.0, 0.55, 0.15), "tailor", ""],
	["MIRRORS", Color(0.95, 0.95, 1.0), "mirrors", ""],
	["TOYS", Color(1.0, 0.45, 0.85), "kids", ""],
	["SHOES", Color(0.2, 1.0, 0.85), "shoes", ""],
	["SALE", Color(1.0, 0.25, 0.3), "clothes", "sale_stay"],
	["GIFTS FOR YOU", Color(0.9, 0.3, 1.0), "gifts", "upside"],
]

## Checkpoints (see Zone.checkpoint_at): keys in hand; the top of the escalator.
const CHECKPOINTS := {
	"keys": [Vector3(-5.5, 0.05, -38.0), 180.0, ["sl_family", "sl_key"]],
	"gallery": [Vector3(-1.6, STOREY + 0.05, GAL_Z0 - 1.5), 0.0, ["sl_family", "sl_key", "sl_escalator", "sl_level3"]],
}

var observer: Observer
var _figures: Array[Mannequin] = []      # all of them
var _grille: StaticBody3D
var _keys: Node3D
var _family: Array[Mannequin] = []
var _sections: Array = []                # the gallery's light sections: {z, lights: [...], panels: [...], on}
var _pendants: Array = []                # [OmniLight3D, base]
var _signs: Array = []                   # [Label3D, light, base energy, quirk, alt text, normal text]
var _glass_mat: StandardMaterial3D
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
func floor_surface() -> String: return "tiles_floor"
func walk_speed() -> float: return 2.6
func sprint_speed() -> float: return 4.2


func player_start() -> Transform3D:
	return Transform3D(Basis(), Vector3(0, 0.05, -1.5))


# ------------------------------------------------------------------ build

func build() -> void:
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.55, 0.65, 0.7, 0.1)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness = 0.04
	_glass_mat.metallic_specular = 1.0
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arcade()
	for i in SHOP_SPECS.size():
		_shop(i)
	_middle()
	_escalators()
	_gallery()
	observer = Observer.new()
	add_child(observer)
	observer.hide_now()
	observer.seen_max_distance = 50.0
	observer.seen.connect(func():
		Game.set_flag("observer_store")
		Game.player.dread.add_dread(observer.spot_dread))
	observer.vanished.connect(func(): _obs_t = randf_range(30.0, 60.0))
	var env := make_env(Color(0.7, 0.68, 0.78), 0.18)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.03)
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	environment(env)
	ambient("hum", Vector3(0, 6, -30), true, -14.0, 40.0)
	ambient("hum", Vector3(0, 6, -70), true, -14.0, 40.0)
	ambient("room_tone", Vector3.ZERO, false, -12.0)


## The arcade itself: floor, the high ceiling with a skylight strip, the entrance, pendants.
func _arcade() -> void:
	var length := -GAL_Z1 + 2.0
	box(Vector3(0, -0.1, (1.0 + END_Z - 14.0) * 0.5), Vector3(HALF * 2.0 + 0.4, 0.2, -(END_Z - 14.0) + 1.0), FLOOR, true, 0.0, "tiles_floor")
	# a darker border inlaid down both sides, and a pale runner down the middle
	for s in [-1.0, 1.0]:
		box(Vector3(s * (HALF - 0.6), 0.003, (FIRST + END_Z) * 0.5), Vector3(0.3, 0.006, FIRST - END_Z), Color(0.35, 0.33, 0.32), false, 0.0, "tiles_floor")
	# ceiling, with a long skylight onto the night
	for s in [-1.0, 1.0]:
		box(Vector3(s * (HALF * 0.5 + 1.0), CEIL + 0.1, -length * 0.5 + 1.0), Vector3(HALF - 2.0, 0.2, length), Color(0.82, 0.8, 0.76), true, 0.0, "plain@0.6")
	box(Vector3(0, CEIL + 0.4, -length * 0.5 + 1.0), Vector3(4.0, 0.1, length), Color(0.02, 0.03, 0.08), true, 0.0, "glass")
	for k in int(length / 4.0):
		box(Vector3(0, CEIL + 0.2, 1.0 - k * 4.0), Vector3(4.0, 0.15, 0.12), TRIM, false, 0.0, "metal")
	# the end walls; the entrance: glass doors (locked) onto the dark street
	for s in [-1.0, 1.0]:
		box(Vector3(s * (HALF + 2.5) * 0.5, 2.0, 0.6), Vector3(HALF - 2.5, 4.0, 0.15), Color(0.3, 0.35, 0.38), true, 0.0, "glass")
	box(Vector3(0, 1.2, 0.65), Vector3(5, 2.4, 0.12), Color(0.25, 0.3, 0.32), true, 0.0, "glass")
	box(Vector3(0, (4.0 + CEIL) * 0.5, 0.6), Vector3(HALF * 2.0, CEIL - 4.0, 0.4), WALL, true, 0.0, "plain@0.45")
	label(Vector3(0, 2.6, 0.5), 180, "PUSH", 0.08, Color(0.8, 0.8, 0.8), false)
	label(Vector3(0, 5.2, 0.38), 0, "THE EMPORIUM", 0.5, Color(1.0, 0.75, 0.35), true)
	omni(Vector3(0, 5.2, -0.4), Color(1.0, 0.75, 0.35), 0.8, 7.0, false)
	# pendants: big glowing globes on long wires, every 12 m
	for k in 8:
		var z := -6.0 - k * 11.5
		part("cylinder", Vector3(0, (CEIL + 6.6) * 0.5, z), Vector3(0.02, CEIL - 6.6, 0.02), TRIM)
		part("sphere", Vector3(0, 6.4, z), Vector3.ONE * 0.55, Color(1.0, 0.95, 0.85), null, Vector3.ZERO, 3.0)
		var l := omni(Vector3(0, 6.0, z), Color(1.0, 0.92, 0.8), 1.2, 16.0, false)
		_pendants.append([l, 1.2])
	# banners from the ceiling
	for spec in [[-18.0, "SUMMER SALE", Color(0.95, 0.3, 0.35)], [-58.0, "HAVE A NICE DAY  :)", Color(1.0, 0.85, 0.2)], [-78.0, "WE'RE SO GLAD YOU'RE HERE", Color(0.3, 0.75, 1.0)]]:
		part("box", Vector3(0, 7.6, spec[0]), Vector3(6.0, 0.9, 0.04), spec[2], null, Vector3.ZERO, 0.6, "fabric")
		label(Vector3(0, 7.6, spec[0] + 0.03), 0, spec[1], 0.16, Color(1, 1, 1), false)
		label(Vector3(0, 7.6, spec[0] - 0.03), 180, spec[1], 0.16, Color(1, 1, 1), false)


## Shop `i`: a lit interior behind a show window, a doorway, a neon sign over it.
func _shop(i: int) -> void:
	var spec: Array = SHOP_SPECS[i]
	var s := -1.0 if i < SHOPS else 1.0
	var k := i % SHOPS
	var z0 := FIRST - k * SHOP_W
	var zc := z0 - SHOP_W * 0.5
	var fx := s * HALF              # the shopfront plane
	var bx := s * (HALF + SHOP_D)   # the back wall
	var neon: Color = spec[1]
	var kind: String = spec[2]
	var quirk: String = spec[3]
	var inside := Color(0.9, 0.88, 0.84) if kind != "shut" else Color(0.3, 0.3, 0.32)
	# the box of the shop: floor, ceiling, back and side walls
	box(Vector3((fx + bx) * 0.5, -0.1, zc), Vector3(SHOP_D, 0.2, SHOP_W), Color(0.75, 0.7, 0.62) if kind != "home" else Color(0.55, 0.4, 0.3), true, 0.0, "wood" if kind in ["home", "tailor", "gifts"] else "tiles_floor")
	box(Vector3((fx + bx) * 0.5, SHOP_H + 0.1, zc), Vector3(SHOP_D, 0.2, SHOP_W), inside, true, 0.0, "plain@0.6")
	box(Vector3(bx + s * 0.1, SHOP_H * 0.5, zc), Vector3(0.2, SHOP_H, SHOP_W), inside.darkened(0.05), true, 0.0, "plain@0.6")
	for z in [z0, z0 - SHOP_W]:
		box(Vector3((fx + bx) * 0.5, SHOP_H * 0.5, z), Vector3(SHOP_D, SHOP_H, 0.2), inside.darkened(0.1), true, 0.0, "plain@0.6")
	# the front: pilasters, a knee wall, the show window, the doorway, the fascia, the wall up to the roof
	box(Vector3(fx, (SHOP_H + CEIL) * 0.5, zc), Vector3(0.3, CEIL - SHOP_H, SHOP_W), WALL, true, 0.0, "plain@0.45")
	box(Vector3(fx, SHOP_H - 0.6, zc), Vector3(0.36, 1.2, SHOP_W), Color(0.08, 0.08, 0.1), false, 0.0, "metal")   # the fascia
	for z in [z0 - 0.25, z0 - SHOP_W + 0.25]:
		box(Vector3(fx, SHOP_H * 0.5, z), Vector3(0.4, SHOP_H, 0.5), Color(0.75, 0.72, 0.68), true, 0.0, "concrete")
	var win0 := z0 - 0.5
	var win1 := z0 - 8.5
	var door0 := z0 - 9.0
	var door1 := z0 - 11.5
	box(Vector3(fx, 0.2, (win0 + win1) * 0.5), Vector3(0.3, 0.4, win0 - win1), TRIM, true, 0.0, "metal")
	box(Vector3(fx, (SHOP_H - 1.2) * 0.5, (win1 + door0) * 0.5), Vector3(0.3, SHOP_H - 1.2, win1 - door0), TRIM, true, 0.0, "metal")   # (the doorway runs up to the fascia)
	if kind == "shut":
		# ALWAYS OPEN: a roller shutter, down
		box(Vector3(fx, (SHOP_H - 1.2) * 0.5, (win0 + door1) * 0.5), Vector3(0.12, SHOP_H - 1.2, win0 - door1), Color(0.45, 0.45, 0.47), true, 0.0, "metal")
		for r in 14:
			part("box", Vector3(fx - s * 0.07, 0.15 + r * 0.2, (win0 + door1) * 0.5), Vector3(0.02, 0.03, win0 - door1), Color(0.3, 0.3, 0.32), null, Vector3.ZERO, 0.0, "metal")
	else:
		# the glass: you see in, you can't walk through it
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(win0 - win1, SHOP_H - 1.2 - 0.4)
		g.mesh = q
		g.material_override = _glass_mat
		g.position = Vector3(fx, 0.4 + (SHOP_H - 1.6) * 0.5, (win0 + win1) * 0.5)
		g.rotation_degrees.y = 90.0
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		blocker(Vector3(fx, SHOP_H * 0.5, (win0 + win1) * 0.5), Vector3(0.1, SHOP_H, win0 - win1))
	# the sign
	var sign := label(Vector3(fx - s * 0.2, SHOP_H - 0.6, zc), -90.0 * s, spec[0], 0.34, neon, true)
	sign.outline_size = 18
	sign.outline_modulate = Color(neon.r, neon.g, neon.b, 0.35)
	if quirk == "upside":
		sign.rotation_degrees.z = 180.0
	var glow := omni(Vector3(fx - s * 1.2, SHOP_H - 0.6, zc), neon, 1.0, 7.0, false)
	var alt: String = {"fun_run": "RUN", "sale_stay": "STAY"}.get(quirk, "")
	_signs.append([sign, glow, 1.0, quirk, alt, spec[0]])
	# inside: a light, the window display, the stock
	if kind != "shut":
		omni(Vector3((fx + bx) * 0.5, SHOP_H - 0.4, zc), Color(1.0, 0.92, 0.82).lerp(neon, 0.25), 0.9, 9.0, false)
		if Settings.quality >= 1:      # (LOW: the shop light alone; every light is another pass over what it touches)
			omni(Vector3(fx + s * 1.2, 2.8, (win0 + win1) * 0.5), Color(1.0, 0.97, 0.92), 1.1, 6.0, false)   # the window spot
		box(Vector3(fx + s * 1.3, 0.15, (win0 + win1) * 0.5), Vector3(2.0, 0.3, win0 - win1 - 0.6), Color(0.95, 0.95, 0.95), true, 0.0, "plaster")   # the display podium
		var n := 3 if kind in ["clothes", "lost", "kids"] else 2
		for m_i in n:
			var mz := win0 - 1.3 - m_i * (win0 - win1 - 2.6) / maxf(n - 1, 1)
			var col: Color = [Color(0.9, 0.86, 0.8), Color(0.95, 0.95, 0.95), Color(0.25, 0.22, 0.2), Color(0.85, 0.72, 0.62)][(i + m_i) % 4]
			var yaw := -90.0 * s if quirk != "backs" else 90.0 * s
			var m := _mannequin(Vector3(fx + s * 1.3, 0.3, mz), yaw + randf_range(-20, 20), ["stand", "hip", "wave", "point"][(i + m_i) % 4], false,
				mini(1 + (k % 3), 2) if kind != "kids" else 0, col, 0.68 if kind == "kids" else 1.0)
			m.set_meta("window", true)
			if m_i == 0:
				m.set_meta("wakes", "sl_key")       # one from each window comes out; the rest just watch
				m.set_meta("out_to", Vector3(fx - s * 1.3, 0, mz))     # where it steps out to, through the glass
		_stock(kind, s, fx, bx, zc, neon)
	if quirk == "family":
		_family_table()


## What's on sale.
func _stock(kind: String, s: float, fx: float, bx: float, zc: float, neon: Color) -> void:
	var mid := (fx + bx) * 0.5
	match kind:
		"clothes", "kids", "sport", "lost":
			for r in 3:
				_rack(Vector3(mid + s * (r - 1) * 2.2, 0, zc + (r - 1) * 2.5), 90.0, neon)
		"beauty":
			for r in 3:
				box(Vector3(mid + s * 1.5, 0.5, zc - 3.0 + r * 3.0), Vector3(1.0, 1.0, 1.8), Color(0.95, 0.95, 0.97), true, 0.0, "glass")
				for h in 4:   # heads on stands: a row of faces
					var hp := Vector3(mid + s * 1.5, 1.2, zc - 3.6 + r * 3.0 + h * 0.4)
					shape_at("cylinder", hp, Vector3(0.04, 0.2, 0.04), Color(0.2, 0.2, 0.2))
					part("sphere", hp + Vector3(0, 0.22, 0), Vector3(0.17, 0.24, 0.19), Color(0.9, 0.82, 0.75), null, Vector3.ZERO, 0.0, 0.25)
		"tailor":
			for r in 4:   # dress forms: torsos on poles, no heads
				var tp := Vector3(mid + s * ((r % 2) * 2.0 - 1.0), 0, zc - 3.0 + r * 2.0)
				shape_at("cylinder", tp + Vector3(0, 0.6, 0), Vector3(0.04, 1.2, 0.04), Color(0.2, 0.15, 0.1))
				part("capsule", tp + Vector3(0, 1.45, 0), Vector3(0.36, 0.28, 0.24), Color(0.85, 0.8, 0.7), null, Vector3.ZERO, 0.0, "fabric")
		"mirrors":
			for r in 5:
				part("box", Vector3(bx - s * 0.12, 1.4, zc - 4.0 + r * 2.0), Vector3(0.04, 2.0, 1.2), Color(0.85, 0.9, 0.95), null, Vector3.ZERO, 0.0, "glass")
		"shoes", "gifts", "photo":
			for r in 4:
				box(Vector3(bx - s * 0.4, 1.0, zc - 4.5 + r * 3.0), Vector3(0.6, 2.0, 2.2), Color(0.85, 0.82, 0.78), true, 0.0, "wood")
				for h in 4:
					part("box", Vector3(bx - s * 0.5, 0.45 + h * 0.45, zc - 4.5 + r * 3.0), Vector3(0.3, 0.15, 0.5), neon.lerp(Color(0.9, 0.9, 0.9), 0.5), null, Vector3.ZERO, 0.0)
		"home":
			for spec in [[Vector3(mid - s * 2.5, 0, zc + 3.6), 0.0], [Vector3(mid + s * 2.0, 0, zc + 4.0), 0.0]]:
				var c: Vector3 = spec[0]
				box(c + Vector3(0, 0.45, 0), Vector3(2.4, 0.5, 0.9), Color(0.55, 0.5, 0.45), true, spec[1], "fabric")
				box(c + Vector3(0, 0.85, -0.4), Vector3(2.4, 0.5, 0.2), Color(0.5, 0.45, 0.4), true, spec[1], "fabric")


func _rack(at: Vector3, yaw: float, neon: Color) -> void:
	shape_at("cylinder", at + Vector3(0, 1.4, 0), Vector3(0.03, 0.03, 1.6), Color(0.6, 0.6, 0.62), false, Vector3(90, yaw, 0), "metal")
	for e in [-0.75, 0.75]:
		var p := at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, e)
		shape_at("cylinder", p + Vector3(0, 0.7, 0), Vector3(0.03, 1.4, 0.03), Color(0.6, 0.6, 0.62), true, Vector3.ZERO, "metal")
	for g in 7:
		var p := at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -0.6 + g * 0.2)
		box(p + Vector3(0, 1.0, 0), Vector3(0.5, 0.75, 0.04), Color(0.8, 0.75, 0.7).lerp(neon, randf() * 0.5), false, yaw + 90.0, "fabric")


## The arcade's middle: palms, benches, the directory, the security kiosk, the dry fountain.
func _middle() -> void:
	for z in [-12.0, -30.0, -64.0, -76.0]:
		for x in [-3.6, 3.6]:
			shape_at("cylinder", Vector3(x, 0.35, z), Vector3(1.3, 0.7, 1.3), Color(0.3, 0.28, 0.26), true, Vector3.ZERO, "concrete")
			if not prop("tree_young", Vector3(x, 0.7, z), randf() * 360.0, 0.55):
				shape_at("cone", Vector3(x, 2.2, z), Vector3(1.6, 2.4, 1.6), Color(0.2, 0.4, 0.2), false)
		if prop("bench", Vector3(0, 0, z + 2.5), 90.0) != null:
			blocker(Vector3(0, 0.45, z + 2.5), Vector3(0.6, 0.9, 1.9))
	# the directory, by the doors
	var dir_at := Vector3(-4.2, 0, -3.0)
	box(dir_at + Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 0.15), Color(0.08, 0.08, 0.1), true, 0.0, "metal")
	label(dir_at + Vector3(0, 1.45, 0.09), 0, "THE EMPORIUM\n\nLEFT:   EVERYBODY . SMILE . HOME & FAMILY\n        FOREVER YOUNG . LOST & FOUND\nRIGHT:  FUN . PERFECT FIT . MIRRORS . TOYS\n\nSECURITY: CENTRE COURT\nGALLERY + STAFF EXIT: UPPER LEVEL\n\nYOU ARE HERE  (STAY THERE)", 0.032, Color(0.9, 0.88, 0.8), true)
	interactable(dir_at + Vector3(0, 1.2, 0.35), Vector3(1.2, 1.4, 0.5), func(): return "Read the directory",
		func():
			Game.set_flag("sl_directory")
			Game.hud.show_thought("Staff exit: the upper level, past the gallery. Up the escalators at the end. ...'Stay there.'", 4.0))
	# the security kiosk: an island, a chair, monitors full of the arcade - and nobody
	box(KIOSK + Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 2.0), Color(0.12, 0.13, 0.16), true, 0.0, "metal")
	box(KIOSK + Vector3(0, 1.12, 0), Vector3(3.4, 0.05, 2.2), Color(0.75, 0.72, 0.68), false, 0.0, "wood")
	for k in 3:
		var mp := KIOSK + Vector3(-0.9 + k * 0.9, 1.45, -0.4)
		part("box", mp, Vector3(0.7, 0.45, 0.06), Color(0.05, 0.05, 0.06), null, Vector3(0, 0, 0), 0.0, "metal")
		part("box", mp + Vector3(0, 0, 0.035), Vector3(0.62, 0.38, 0.01), Color(0.3, 0.45, 0.4), null, Vector3.ZERO, 1.2)
	label(KIOSK + Vector3(0, 2.5, 1.12), 0, "SECURITY", 0.12, Color(0.85, 0.85, 0.9), true)
	label(KIOSK + Vector3(0, 1.16, 0.6), -90, "BACK SOON\nAT DINNER\n(HOME & FAMILY)", 0.03, Color(0.15, 0.15, 0.2), false).rotation_degrees = Vector3(-90, 0, 0)
	part("box", KIOSK + Vector3(0, 1.15, 0.6), Vector3(0.3, 0.005, 0.22), Color(1.0, 0.97, 0.7))
	interactable(KIOSK + Vector3(0, 1.3, 1.2), Vector3(3.4, 0.6, 0.6), func(): return "Read the note",
		func():
			Game.set_flag("sl_note")
			Game.hud.show_thought("'Back soon. At dinner. Home & Family.' ...A shop. He's having dinner in a shop.", 4.0))
	omni(KIOSK + Vector3(0, 2.0, 0), Color(0.5, 0.7, 0.65), 0.6, 5.0, false)
	# the fountain: dry, coins in the bottom
	var f := Vector3(0, 0, -56.0)
	shape_at("cylinder", f + Vector3(0, 0.3, 0), Vector3(5.0, 0.6, 5.0), Color(0.82, 0.8, 0.76), true, Vector3.ZERO, "concrete")
	shape_at("cylinder", f + Vector3(0, 0.55, 0), Vector3(4.4, 0.1, 4.4), Color(0.4, 0.42, 0.42), false, Vector3.ZERO, "tiles_pool")
	shape_at("cylinder", f + Vector3(0, 1.2, 0), Vector3(0.5, 1.4, 0.5), Color(0.82, 0.8, 0.76), true, Vector3.ZERO, "concrete")
	for k in 30:
		var a := randf() * TAU
		var r := randf_range(0.5, 2.0)
		shape_at("cylinder", f + Vector3(cos(a) * r, 0.61, sin(a) * r), Vector3(0.025, 0.004, 0.025), Color(0.8, 0.65, 0.3), false, Vector3.ZERO, "metal")
	trigger(KIOSK + Vector3(0, 1.2, 4.0), Vector3(10, 2.4, 2), func():
		Game.hud.show_thought("Security. Nobody at the desk. ...There's a note.", 2.5))


## THE PERFECT FAMILY at dinner, in Home & Family. The guard at the head of the table.
func _family_table() -> void:
	var t := FAMILY
	box(t + Vector3(0, 0.75, 0), Vector3(1.2, 0.06, 2.4), Color(0.45, 0.3, 0.2), true, 0.0, "wood")
	box(t + Vector3(0, 0.37, 0), Vector3(0.2, 0.74, 0.2), Color(0.35, 0.25, 0.15), false, 0.0, "wood")
	for k in 4:
		shape_at("cylinder", t + Vector3(0, 0.79, -0.9 + k * 0.6), Vector3(0.28, 0.02, 0.28), Color(0.95, 0.95, 0.92))
	for k in 3:
		part("sphere", t + Vector3(0.0, 0.85, -0.9 + k * 0.6), Vector3(0.12, 0.08, 0.12), Color(0.45, 0.3, 0.15))   # plastic food
	label(t + Vector3(-3.0, 2.6, 0), 90, "THE PERFECT FAMILY", 0.14, Color(0.6, 0.15, 0.12), false)
	# the guard (in uniform), the mother, the child; the fourth chair empty, by the aisle
	var seats := [[t + Vector3(-1.4, 0, -0.6), 90.0, 1.0, Color(0.12, 0.14, 0.25), 1], [t + Vector3(-1.4, 0, 0.6), 90.0, 0.95, Color(0.88, 0.8, 0.74), 2],
		[t + Vector3(1.4, 0, -0.6), -90.0, 0.68, Color(0.9, 0.84, 0.78), 1]]
	for s in seats:
		_chair(s[0], s[1])
		var m := _mannequin(s[0], s[1], "sit", false, s[4], s[3], s[2])
		m.set_meta("wakes", "sl_family")
		_family.append(m)
	_chair(SEAT, -90.0)
	label(SEAT + Vector3(-0.55, 0.82, 0), -90, "~ YOU ~", 0.06, Color(0.2, 0.15, 0.1), false)
	# the keys, at your place
	_keys = group(t + Vector3(0.3, 0.79, 0.6))
	if prop("key", Vector3(0, 0.006, 0), 30.0, 1.0, _keys) == null:
		part("box", Vector3.ZERO, Vector3(0.06, 0.01, 0.06), Color(0.7, 0.68, 0.6), _keys, Vector3.ZERO, 0.0, "metal")
	else:
		prop("key", Vector3(0.03, 0.012, 0.02), 75.0, 1.0, _keys)
	interactable(SEAT + Vector3(0, 0.7, 0), Vector3(0.9, 1.0, 0.9), func(): return "Sit down" if not Game.has_flag("sl_family") else "",
		func(): _sit(), func(): return not Game.has_flag("sl_family"))
	trigger(Vector3(-HALF - 1.5, 1.2, FAMILY.z), Vector3(2, 2.4, 3), func():
		Game.hud.show_thought("A family at dinner. They've laid a place for one more. ...The guard's keys are on the empty plate.", 4.0))


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
	Game.look_toward(FAMILY + Vector3(-1.4, 0.9, -0.3), 0.6)
	Sfx.play("creak", -4.0, 0.9)
	await get_tree().create_timer(1.5, false).timeout
	if t != Game._seq: return
	# the lights go, for a moment
	for l in _pendants:
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
	for l in _pendants:
		l[0].visible = true
	Sfx.play("switch", -2.0, 0.9)
	Sfx.stinger("hit", -2.0)
	Game.player.dread.add_fear(12.0, "family")
	Game.hud.show_thought("They're all looking at me. They weren't looking at me.", 3.0)
	await get_tree().create_timer(2.0, false).timeout
	if t != Game._seq: return
	_keys.visible = false
	Sfx.play("page", -4.0, 1.4)
	Game.set_flag("sl_family")
	Game.set_flag("sl_key")
	Game.hud.show_thought("The keys. Thank you for having me. ...I have to go. Every window. Don't look away from the windows.", 4.5)
	Sfx.play_music("muzak", 1.0)
	pl._set_crouch(false)
	Game.in_sequence = false
	Game.set_mode("game")
	checkpoint_at("keys")
	_wake("sl_family")
	_wake("sl_key")


# ------------------------------------------------------------------ the escalators and the gallery

func _escalators() -> void:
	# the hall at the end: a glass balustrade along the gallery's edge, the escalators side by side
	_escalator(ESC, true)
	_escalator(ESC + Vector3(3.2, 0, 0), false)
	label(Vector3(0, 7.2, END_Z + 0.1), 0, "GALLERY  .  LIFELIKE", 0.22, Color(0.95, 0.3, 0.25), true)
	omni(Vector3(0, 7.0, END_Z - 1.0), Color(0.95, 0.3, 0.25), 0.6, 8.0, false)


## A stopped escalator climbing 5 m toward -z. Only the working one has a grille (and a way up); the other is
## fenced off at the top, its steps half gone.
func _escalator(bottom: Vector3, working: bool) -> void:
	var top := bottom + Vector3(0, STOREY, -ESC_RUN)
	var mid := (bottom + top) * 0.5
	var length := Vector3(0, STOREY, ESC_RUN).length()
	if working:
		var ramp := StaticBody3D.new()
		ramp.position = mid
		ramp.rotation_degrees.x = 30.0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.4, 0.1, length + 0.4)
		cs.shape = bs
		cs.position.y = -0.05
		ramp.add_child(cs)
		add_child(ramp)
	else:
		blocker(mid + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, length))
		blocker(bottom + Vector3(0, 1.0, 0.4), Vector3(1.6, 2.0, 0.1))
	var steps := 26
	for k in steps:
		if not working and k > 18 and k % 3 != 0:
			continue
		var p := bottom.lerp(top, (k + 0.5) / steps)
		part("box", p + Vector3(0, -0.1, 0), Vector3(1.2, 0.2, ESC_RUN / steps + 0.02), Color(0.32, 0.32, 0.34), null, Vector3.ZERO, 0.0, "metal")
		part("box", p + Vector3(0, 0.005, -ESC_RUN / steps * 0.45), Vector3(1.2, 0.012, 0.03), Color(0.9, 0.75, 0.2), null, Vector3.ZERO, 0.6)   # yellow step edges
	for s in [-1.0, 1.0]:
		var side := solid_box(mid + Vector3(s * 0.75, 0.55, 0), Vector3(0.1, 1.1, length + 0.6), Color(0.75, 0.8, 0.82), null, "glass")
		side.rotation_degrees.x = 30.0
		part("box", mid + Vector3(s * 0.75, 1.13, 0), Vector3(0.12, 0.08, length + 0.6), Color(0.05, 0.05, 0.05), null, Vector3(30, 0, 0))
		part("box", mid + Vector3(s * 0.75, -0.45, 0), Vector3(0.3, 0.9, length + 0.4), Color(0.75, 0.75, 0.78), null, Vector3(30, 0, 0), 0.0, "metal")
	if working:
		_grille = solid_box(bottom + Vector3(0, 1.3, 0.6), Vector3(1.6, 2.6, 0.06), Color(0.4, 0.42, 0.44), null, "metal")
		(_grille.get_child(1) as MeshInstance3D).transparency = 0.35
		for k in 7:
			part("box", Vector3(-0.6 + k * 0.2, 0, 0.04), Vector3(0.03, 2.6, 0.04), Color(0.25, 0.25, 0.27), _grille, Vector3.ZERO, 0.0, "metal")
		label(bottom + Vector3(0, 2.0, 0.66), 0, "ESCALATOR CLOSED\nPLEASE SEE SECURITY", 0.06, Color(0.9, 0.2, 0.15), false)
		interactable(bottom + Vector3(0, 1.2, 0.9), Vector3(1.8, 2.0, 0.6),
			func(): return "Unlock the grille" if Game.has_flag("sl_key") else "Escalator grille",
			func(): _open_grille(), func(): return _grille != null)


func _open_grille() -> void:
	if not Game.has_flag("sl_key"):
		Game.hud.show_thought("Locked. 'Please see security.' ...Security's at dinner, apparently.", 3.0)
		return
	Sfx.play_at("grind", self, _grille.global_position, -4.0, 20.0)
	var g := _grille
	_grille = null
	var tw := create_tween()
	tw.tween_property(g, "position:y", g.position.y + 2.6, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(g.queue_free)
	Game.set_flag("sl_escalator")


func _gallery() -> void:
	var y := STOREY
	var gl := GAL_Z0 - GAL_Z1
	var gz := (GAL_Z0 + GAL_Z1) * 0.5
	# the floor up there, its edge over the hall, the walls and ceiling round it
	box(Vector3(0, y - 0.15, gz), Vector3(HALF * 2.0, 0.3, gl), FLOOR, true, 0.0, "tiles_floor")
	box(Vector3(0, y * 0.5, END_Z - 12.0 + 0.2), Vector3(HALF * 2.0, y, 0.4), WALL, true, 0.0, "plain@0.45")
	for s in [-1.0, 1.0]:
		box(Vector3(s * (HALF + 0.2), CEIL * 0.5, (END_Z + GAL_Z1) * 0.5), Vector3(0.4, CEIL, END_Z - GAL_Z1), WALL, true, 0.0, "plain@0.45")
	box(Vector3(0, CEIL * 0.5, GAL_Z1 - 0.2), Vector3(HALF * 2.0, CEIL, 0.4), WALL, true, 0.0, "plain@0.45")
	box(Vector3(0, y * 0.5, (END_Z - 12.0 + GAL_Z1) * 0.5), Vector3(HALF * 2.0, y, END_Z - 12.0 - GAL_Z1), Color(0.3, 0.3, 0.3), true)   # (solid under the gallery's far end)
	# the balustrade along the gallery's edge (a gap where the escalator arrives)
	for seg in [[-HALF, ESC.x - 0.8], [ESC.x + 0.8, HALF]]:
		var c := Vector3((seg[0] + seg[1]) * 0.5, y + 0.55, GAL_Z0 + 0.05)
		box(c, Vector3(seg[1] - seg[0], 1.1, 0.06), Color(0.7, 0.78, 0.8), true, 0.0, "glass")
		box(c + Vector3(0, 0.57, 0), Vector3(seg[1] - seg[0], 0.06, 0.1), TRIM, false, 0.0, "metal")
	label(Vector3(0, y + 3.4, GAL_Z0 - 0.5), 180, "LIFELIKE", 0.3, Color(0.5, 0.12, 0.1), false)
	# light sections down the gallery: these are the ones that fail
	for k in 6:
		var z := GAL_Z0 - 3.0 - k * 5.5
		var panel := part("box", Vector3(0, CEIL - 0.05, z), Vector3(5.0, 0.05, 0.6), Color(0.95, 0.97, 1.0), null, Vector3.ZERO, 2.5)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := omni(Vector3(0, CEIL - 0.6, z), Color(0.95, 0.97, 1.0), 1.2, 10.0, false)
		_sections.append({"z": z, "lights": [l], "panels": [panel], "on": true})
	# the studies: plinths in two rows, each figure more real than the last
	var rows := [-3.8, 3.8]
	for k in 4:
		var at := Vector3(rows[k % 2], y, GAL_Z0 - 4.0 - k * 3.0)
		var m := _mannequin(at, 180.0 if k % 2 == 0 else 160.0, ["stand", "hip", "point", "stand"][k], true, mini(k, 2))
		m.set_meta("wakes", "sl_lights3")
		label(at + Vector3(0, 0.3, 0.75), 0, "STUDY No. %d" % (k + 1), 0.05, Color(0.2, 0.2, 0.2), false)
	# then people. people you've met. frozen on plinths under spotlights.
	var people := [
		["MINA  (ice cream)", {"skin": Color(0.86, 0.64, 0.5), "hair": Color(0.32, 0.16, 0.07), "shirt": Color(0.95, 0.55, 0.62),
			"pants": Color(0.2, 0.25, 0.42), "apron": true, "cap": true, "cap_color": Color(0.98, 0.98, 0.95), "height": 0.95, "hair_style": "bun", "build": 0.92}],
		["MR. HALVORSEN  (pigeons)", {"skin": Color(0.84, 0.68, 0.58), "hair": Color(0.78, 0.78, 0.76), "shirt": Color(0.42, 0.47, 0.34),
			"pants": Color(0.33, 0.29, 0.24), "cap": true, "cap_color": Color(0.28, 0.28, 0.3), "sleeves": "long", "hair_style": "short", "build": 1.05}],
		["THEO  (kite)", {"skin": Color(0.58, 0.4, 0.28), "hair": Color(0.05, 0.04, 0.04), "shirt": Color(0.96, 0.8, 0.2), "pants": Color(0.25, 0.4, 0.62),
			"height": 0.68, "cap": true, "cap_color": Color(0.85, 0.15, 0.12), "hair_style": "curly", "build": 0.9}],
	]
	for k in people.size():
		var at := Vector3(rows[k % 2], y, GAL_Z0 - 17.0 - k * 4.0)
		shape_at("cylinder", at + Vector3(0, 0.06, 0), Vector3(0.9, 0.12, 0.9), TRIM, true, Vector3.ZERO, "metal")
		var hmn := Human.new()
		add_child(hmn)
		hmn.build(people[k][1])
		hmn.position = at + Vector3(0, 0.12, 0)
		hmn.rotation_degrees.y = 180.0
		hmn.set_frozen(true)
		label(at + Vector3(0, 0.3, 0.75), 0, people[k][0], 0.05, Color(0.2, 0.2, 0.2), false)
		spot(at + Vector3(0, 3.8, 1.2), at + Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.8), 3.0, 7.0, 25.0, false)
	# the last plinth: empty. your card on it.
	var last := Vector3(0, y, GAL_Z1 + 3.5)
	shape_at("cylinder", last + Vector3(0, 0.06, 0), Vector3(0.9, 0.12, 0.9), TRIM, true, Vector3.ZERO, "metal")
	label(last + Vector3(0, 0.3, 0.75), 0, "YOU  (coming soon)", 0.06, Color(0.5, 0.1, 0.08), false)
	spot(last + Vector3(0, 3.8, 1.2), last + Vector3(0, 1.0, 0), Color(1.0, 0.92, 0.8), 3.0, 7.0, 25.0, false)
	for k in 6:
		var s := -1.0 if k % 2 == 0 else 1.0
		var at := Vector3(s * (HALF - 0.8), y, GAL_Z0 - 6.0 - k * 4.5)
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
	trigger(Vector3(ESC.x, y + 1.2, GAL_Z0 - 1.0), Vector3(3, 2.4, 2), func():
		if Game.has_flag("sl_level3"):
			return
		Game.set_flag("sl_level3")
		checkpoint_at("gallery")
		Game.hud.show_thought("'LIFELIKE.' ...The exit's at the far end. Past all of them.", 3.5))
	trigger(Vector3(0, y + 1.2, GAL_Z0 - 13.0), Vector3(HALF * 2.0, 2.4, 2), func(): _begin_climax())


# ------------------------------------------------------------------ mannequins

func _mannequin(pos: Vector3, yaw: float, pose: String, stand := true, realism := 0, col := Color(0.9, 0.86, 0.8), h := 1.0) -> Mannequin:
	var m := Mannequin.new()
	add_child(m)
	m.pose = pose
	m.build(col, realism, h)
	m.position = pos
	m.rotation_degrees.y = yaw
	m.home = pos
	m.level_y = STOREY if pos.y > STOREY - 0.5 else 0.0
	if stand:
		# a round plinth; when it walks off, the plinth stays
		shape_at("cylinder", Vector3(pos.x, m.level_y + 0.06, pos.z), Vector3(0.7, 0.12, 0.7), TRIM, true, Vector3.ZERO, "metal")
		m.position.y = m.level_y + 0.12
	_figures.append(m)
	return m


func _wake(flag: String) -> void:
	for m in _figures:
		if m.get_meta("wakes", "") == flag:
			m.hunting = true


## Every one you can't see, steps. Hunting ones step toward you; the rest only change. A window display
## that wakes is first out of its window - through the glass - the moment nobody's watching.
func _update_figures(delta: float, p: Vector3) -> void:
	var on_level := STOREY if p.y > STOREY - 0.5 else 0.0
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
			if m.unseen_t > 3.0 and randf() < delta * 0.25 and m.global_position.distance_to(p) < 18.0:
				m.unseen_t = 0.0
				m.set_pose(["stand", "hip", "wave", "point"].pick_random())
				m.face_toward(p)
			continue
		if m.has_meta("out_to"):
			var near: bool = (m.get_meta("out_to") as Vector3).distance_to(p) < 22.0
			if near and m.unseen_t > 0.6 and not Observation.is_observed(m.get_meta("out_to") + Vector3(0, 1.0, 0), 0.8):
				m.global_position = m.get_meta("out_to")
				m.remove_meta("out_to")
				m.face_toward(p)
				m.set_pose("reach")
				Sfx.play_at("creak", self, m.global_position + Vector3(0, 1.0, 0), -6.0, 16.0)
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
	if pos.y < STOREY - 0.5:
		return true
	for s in _sections:
		if absf(pos.z - s.z) < 3.0:
			return s.on
	return true


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
	# a section every 2.5 s, from the top of the escalator toward the exit (never the last one, at the door)
	for k in _sections.size() - 1:
		var s: Dictionary = _sections[k]
		if s.on and _climax_t > 0.5 + k * 2.5:
			s.on = false
			for l in s.lights:
				l.visible = false
			for p in s.panels:
				p.material_override = Shapes.material(Color(0.2, 0.2, 0.2))
			Sfx.play("switch", -2.0, 0.6)


# ------------------------------------------------------------------ runtime

func on_player_entered(from_save: bool) -> void:
	give(["sl_key"])
	_t = 0.0
	_hint = 2 if from_save else 0
	# back from a checkpoint: you've had dinner, you have the keys; maybe the grille's up
	if Game.has_flag("sl_family"):
		_seated = true
		_keys.visible = false
		for m in _family:
			m.face_toward(SEAT)
		_wake("sl_family")
		_wake("sl_key")
	if Game.has_flag("sl_escalator") and _grille != null:
		_grille.queue_free()
		_grille = null


func _process(delta: float) -> void:
	_t += delta
	_update_signs(delta)
	var pl: Player = Game.player
	if pl == null or Game.in_sequence:
		return
	var p := pl.global_position
	_update_figures(delta, p)
	_update_climax(delta)
	for l in _pendants:
		if l[0].visible and randf() < 0.003 and Settings.flashing_ok():
			l[0].light_energy = l[1] * 0.2
		else:
			l[0].light_energy = move_toward(l[0].light_energy, l[1], delta * 4.0)
	if _hint == 0 and _t > 1.5:
		_hint = 1
		Sfx.play("thud", -2.0, 0.7)
		Game.hud.show_thought("The doors - they've locked. Behind me. ...A shopping arcade. Every shop lit. At this time of night.", 4.0)
	elif _hint == 1 and _t > 7.0:
		_hint = 2
		Game.hud.show_hint("They only move when you aren't looking.", 6.0)
	if not observer.visible and p.y > STOREY - 0.5:
		_obs_t -= delta
		if _obs_t <= 0.0:
			_obs_t = 12.0
			observer.try_appear_at(Vector3(randf_range(-5, 5), STOREY, randf_range(GAL_Z1 + 4.0, GAL_Z0 - 4.0)))


## The neon: buzzing, the odd letter dropping out - and the ones that read differently when you look back.
func _update_signs(delta: float) -> void:
	for s in _signs:
		var lb: Label3D = s[0]
		var quirk: String = s[3]
		if quirk in ["fun_run", "sale_stay"]:
			var seen := Observation.is_observed(lb.global_position, 1.5)
			if not seen and randf() < delta * 0.3:
				lb.text = s[4] if lb.text == s[5] else s[5]
		if Settings.flashing_ok() and randf() < delta * 0.15:
			lb.modulate.a = 0.35
			(s[1] as OmniLight3D).light_energy = s[2] * 0.3
		else:
			lb.modulate.a = move_toward(lb.modulate.a, 1.0, delta * 6.0)
			(s[1] as OmniLight3D).light_energy = move_toward((s[1] as OmniLight3D).light_energy, s[2], delta * 6.0)
