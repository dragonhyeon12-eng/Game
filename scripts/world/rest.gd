class_name RestZone
extends Zone
## A RESTING PLACE, between realms. A clean white room that feels like home, floating in a blue sky with
## white clouds drifting below. Nothing in here will hurt you. On the shelf: a few pills (each stops fear
## building for 10 s). On the little table: a music box (carry it; play it once, when it's bad, and the
## fear goes out of you). The glowing doorway takes you on.
## Three of them (index 1-3), each a little different: the walls, the furniture, the light.

const W := 8.0          # x: -4 .. 4
const D := 6.0          # z: -3 .. 3
const H := 3.0
const WALL_T := 0.2
const TINTS := [Color(0.96, 0.95, 0.92), Color(0.9, 0.94, 0.97), Color(0.94, 0.96, 0.9)]

var index := 1
var _music_box: Node3D
var _pills: Array[Node3D] = []
var _t := 0.0
var _hint := 0
var _leaving := false


func zone_id() -> String: return "rest%d" % index
func is_nightmare() -> bool: return false
func fear_floor() -> float: return 0.0
func fear_decay() -> float: return 6.0
func floor_surface() -> String: return "wood"
func walk_speed() -> float: return 2.4
func sprint_speed() -> float: return 3.8


func player_start() -> Transform3D:
	# just inside, by the window, looking into the room
	return Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(-2.6, 0.05, 0.6))


func build() -> void:
	var tint: Color = TINTS[(index - 1) % TINTS.size()]
	_room(tint)
	_doorway()
	_furnish()
	_sky()
	ambient("room_tone", Vector3.ZERO, false, -24.0)
	ambient("chirp", Vector3(0, 1.5, -6), true, -20.0, 20.0)


func _room(tint: Color) -> void:
	var floor_col := Color(0.82, 0.7, 0.55)
	box(Vector3(0, -0.1, 0), Vector3(W + 0.4, 0.2, D + 0.4), floor_col, true, 0.0, "wood")
	box(Vector3(0, H + 0.1, 0), Vector3(W + 0.4, 0.2, D + 0.4), Color(0.98, 0.98, 0.97), true, 0.0, "plain@0.8")
	# the outside of the room, seen from nowhere in particular: a white box hanging in the sky
	box(Vector3(0, -0.45, 0), Vector3(W + 0.6, 0.5, D + 0.6), Color(0.92, 0.92, 0.9), false, 0.0, "plaster")
	# north wall (z = -3): two tall windows.  south (z = +3): solid.  east (x = +4): one window.  west: the doorway
	_wall_with_windows(Vector3(0, 0, -D * 0.5), W, false, [-1.8, 1.8], tint)
	_wall_with_windows(Vector3(0, 0, D * 0.5), W, false, [], tint)
	_wall_with_windows(Vector3(W * 0.5, 0, 0), D, true, [0.0], tint)
	# west wall: a doorway in the middle
	for z in [-1.95, 1.95]:
		box(Vector3(-W * 0.5, H * 0.5, z), Vector3(WALL_T, H, 2.1), tint, true, 0.0, "plain@0.7")
	box(Vector3(-W * 0.5, (2.3 + H) * 0.5, 0), Vector3(WALL_T, H - 2.3, 1.8), tint, true, 0.0, "plain@0.7")
	# skirting and a picture rail
	for spec in [[Vector3(0, 0.06, -D * 0.5 + 0.11), Vector3(W, 0.12, 0.02)], [Vector3(0, 0.06, D * 0.5 - 0.11), Vector3(W, 0.12, 0.02)],
			[Vector3(W * 0.5 - 0.11, 0.06, 0), Vector3(0.02, 0.12, D)]]:
		box(spec[0], spec[1], Color(1, 1, 1), false, 0.0, "plaster")
	# a framed picture on the south wall: a blue sky, a tiny house
	part("box", Vector3(1.5, 1.7, D * 0.5 - 0.11), Vector3(0.9, 0.65, 0.03), Color(0.85, 0.82, 0.75), null, Vector3.ZERO, 0.0, "wood")
	part("box", Vector3(1.5, 1.7, D * 0.5 - 0.128), Vector3(0.8, 0.55, 0.005), Color(0.55, 0.72, 0.9), null, Vector3.ZERO, 0.3)
	part("box", Vector3(1.5, 1.55, D * 0.5 - 0.13), Vector3(0.12, 0.1, 0.005), Color(0.95, 0.95, 0.9), null, Vector3.ZERO, 0.3)
	# a soft overhead light, and the sun through the windows
	part("cylinder", Vector3(0.5, H - 0.03, 0), Vector3(0.5, 0.04, 0.5), Color(1, 0.97, 0.9), null, Vector3.ZERO, 1.5)
	omni(Vector3(0.5, H - 0.4, 0), Color(1.0, 0.92, 0.8), 0.6, 8.0, true)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-35, -150, 0)
	sun.shadow_enabled = true
	add_child(sun)


## A wall along x (or z, `along_z`) through `c`, `length` long, with 1.6 x 1.7 m windows at the offsets given.
func _wall_with_windows(c: Vector3, length: float, along_z: bool, windows: Array, tint: Color) -> void:
	var ww := 1.6
	var sill := 0.8
	var top := 2.5
	var cuts: Array = windows.duplicate()
	cuts.sort()
	var cur := -length * 0.5
	var segs := []
	for w in cuts:
		segs.append([cur, w - ww * 0.5])
		cur = w + ww * 0.5
	segs.append([cur, length * 0.5])
	var at := func(u: float, y: float) -> Vector3: return c + (Vector3(0, y, u) if along_z else Vector3(u, y, 0))
	var sz := func(l: float, h: float) -> Vector3: return Vector3(WALL_T, h, l) if along_z else Vector3(l, h, WALL_T)
	for s in segs:
		if s[1] - s[0] > 0.01:
			box(at.call((s[0] + s[1]) * 0.5, H * 0.5), sz.call(s[1] - s[0], H), tint, true, 0.0, "plain@0.7")
	for w in cuts:
		box(at.call(w, sill * 0.5), sz.call(ww, sill), tint, true, 0.0, "plain@0.7")
		box(at.call(w, (top + H) * 0.5), sz.call(ww, H - top), tint, true, 0.0, "plain@0.7")
		# a white frame, a cross of glazing bars, a deep sill to put things on
		var fr := Color(1, 1, 1)
		for spec in [[w, (sill + top) * 0.5, 0.06, top - sill], [w - ww * 0.5 + 0.03, (sill + top) * 0.5, 0.06, top - sill],
				[w + ww * 0.5 - 0.03, (sill + top) * 0.5, 0.06, top - sill]]:
			part("box", at.call(spec[0], spec[1]), sz.call(spec[2], spec[3]) * Vector3(0.6 if not along_z else 1, 1, 1 if not along_z else 0.6), fr, null, Vector3.ZERO, 0.0, "wood")
		part("box", at.call(w, (sill + top) * 0.5 + 0.2), sz.call(ww, 0.05) * Vector3(1 if not along_z else 0.6, 1, 0.6 if not along_z else 1), fr, null, Vector3.ZERO, 0.0, "wood")
		var inward := (Vector3(-0.12, 0, 0) if c.x > 0 else Vector3(0.12, 0, 0)) if along_z else (Vector3(0, 0, 0.12) if c.z < 0 else Vector3(0, 0, -0.12))
		part("box", at.call(w, sill + 0.02) + inward, sz.call(ww + 0.1, 0.04) + Vector3(0.12 if along_z else 0, 0, 0 if along_z else 0.12), fr, null, Vector3.ZERO, 0.0, "wood")
		# glass you can't fall through (and wouldn't want to: there's nothing under the room)
		blocker(at.call(w, (sill + top) * 0.5), sz.call(ww, top - sill))
		var glass := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(ww - 0.06, top - sill - 0.06)
		glass.mesh = q
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.85, 0.93, 1.0, 0.08)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.roughness = 0.05
		gm.metallic_specular = 1.0
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.material_override = gm
		glass.position = at.call(w, (sill + top) * 0.5)
		glass.rotation_degrees.y = 90.0 if along_z else 0.0
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glass)


func _doorway() -> void:
	var x := -W * 0.5
	# a frame, and beyond it only light
	for z in [-0.93, 0.93]:
		part("box", Vector3(x + 0.12, 1.15, z), Vector3(0.08, 2.3, 0.08), Color(1, 1, 1), null, Vector3.ZERO, 0.0, "wood")
	part("box", Vector3(x + 0.12, 2.33, 0), Vector3(0.08, 0.08, 1.94), Color(1, 1, 1), null, Vector3.ZERO, 0.0, "wood")
	part("box", Vector3(x - 0.25, 1.15, 0), Vector3(0.05, 2.3, 1.8), Color(1.0, 0.98, 0.92), null, Vector3.ZERO, 4.0)
	box(Vector3(x - 0.3, 1.15, 0), Vector3(0.1, 2.4, 2.0), Color(1, 1, 1), true)
	var glow := omni(Vector3(x + 0.6, 1.4, 0), Color(1.0, 0.96, 0.88), 2.2, 5.0, false)
	glow.name = "DoorGlow"
	interactable(Vector3(x + 0.05, 1.1, 0), Vector3(0.6, 2.2, 1.6), func(): return "Go on" if not _leaving else "",
		func(): _leave(), func(): return not _leaving)
	trigger(Vector3(x + 0.9, 1.2, 0), Vector3(1.0, 2.4, 1.8), func():
		if _t > 3.0:
			Game.hud.show_thought("Not yet. ...Just a little longer.", 2.5), false)


func _furnish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + index
	prop("rug_round", Vector3(0.6, 0.002, 0.2), 0.0)
	match index:
		1:
			prop("bed_white", Vector3(2.85, 0, -1.85), -90.0)
			prop("armchair", Vector3(-1.2, 0, -1.9), 160.0)
		2:
			prop("armchair", Vector3(-1.4, 0, -1.9), 165.0)
			prop("armchair", Vector3(1.4, 0, -1.9), 195.0)
		_:
			prop("bed_white", Vector3(2.85, 0, 1.75), -90.0)
			prop("armchair", Vector3(1.6, 0, -2.0), 200.0)
	# the shelf, against the south wall: the pills on the middle shelf, by their bottle
	var shelf_at := Vector3(-1.6, 0, D * 0.5 - 0.2)
	prop("shelf_white", shelf_at, 180.0)
	# (the back and the base only: a box over the whole shelf would hide the pills from your hand)
	blocker(shelf_at + Vector3(0, 0.8, 0.13), Vector3(1.2, 1.6, 0.14))
	blocker(shelf_at + Vector3(0, 0.27, 0.02), Vector3(1.2, 0.54, 0.32))
	prop("pill_bottle", shelf_at + Vector3(0.35, 0.58, 0.0), 30.0)
	prop("flower_vase", shelf_at + Vector3(-0.35, 1.075, 0.0), 0.0)
	shape_at("cylinder", shelf_at + Vector3(-0.08, 0.59, 0), Vector3(0.24, 0.012, 0.24), Color(0.55, 0.75, 0.9), false, Vector3.ZERO, 0.2)   # a little dish
	var n := rng.randi_range(3, 4)
	for k in n:
		var p := shelf_at + Vector3(-0.2 + k * 0.075, 0.6, -0.02 + (k % 2) * 0.03)
		var pill := prop("pill", p, rng.randf() * 360.0, 2.6)
		if pill == null:
			pill = part("capsule", p, Vector3(0.012, 0.016, 0.012), Color(0.4, 0.65, 0.9), null, Vector3(0, 0, 90))
		_pills.append(pill)
	# one easy target over the whole dish (a pill each is too small to aim at, above all on a phone): a pill per press
	var left := func() -> Array: return _pills.filter(func(x): return x.visible)
	interactable(shelf_at + Vector3(-0.08, 0.66, -0.02), Vector3(0.42, 0.22, 0.3),
		func(): return ("Take a pill (%d left)" % left.call().size()) if not left.call().is_empty() else "",
		func():
			var l: Array = left.call()
			if l.is_empty():
				return
			(l[0] as Node3D).visible = false
			Game.items.add("pills")
			Sfx.play("page", -14.0, 2.4)
			if Game.items.count("pills") == 1:
				Game.hud.show_hint("PILLS: for 10 seconds nothing frightens you more.\n" + ("Tap PILLS to take one" if TouchControls.wanted() else "Press 1 to take one"), 6.0),
		func(): return not left.call().is_empty())
	# the little table by the chair: a lamp, and the music box
	var table_at := Vector3(-0.3 if index != 2 else 0.0, 0, -2.2)
	prop("side_table", table_at, 0.0)
	blocker(table_at + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5))
	prop("table_lamp", table_at + Vector3(0.12, 0.62, 0.08), 0.0)
	omni(table_at + Vector3(0.12, 1.05, 0.08), Color(1.0, 0.82, 0.55), 0.8, 4.0, false)
	_music_box = prop("music_box", table_at + Vector3(-0.1, 0.62, -0.02), 160.0)
	if _music_box == null:
		_music_box = part("box", table_at + Vector3(-0.1, 0.655, -0.02), Vector3(0.16, 0.065, 0.11), Color(0.35, 0.2, 0.1))
	interactable(table_at + Vector3(-0.1, 0.7, -0.02), Vector3(0.3, 0.2, 0.25), func(): return "Take the music box" if _music_box.visible else "",
		func():
			_music_box.visible = false
			Game.items.add("music_box")
			Sfx.play("chime", -8.0, 1.2)
			Game.hud.show_hint("THE MUSIC BOX: play it once, when it's bad, and the fear goes.\n" + ("Tap MUSIC BOX to play it" if TouchControls.wanted() else "Press 2 to play it"), 7.0),
		func(): return _music_box.visible)


func _sky() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/world/sky.gdshader")
	sky_mat.set_shader_parameter("zenith", Color(0.22, 0.48, 0.9))
	sky_mat.set_shader_parameter("horizon", Color(0.78, 0.88, 0.97))
	sky_mat.set_shader_parameter("ground", Color(0.95, 0.96, 0.98))     # below: more cloud
	sky_mat.set_shader_parameter("cloud_cover", 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := make_env(Color(0.9, 0.92, 0.95), 0.55)
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_exposure = 0.82
	env.glow_intensity = 0.25
	environment(env)
	# the clouds the room floats over: big, soft, white, sunlit
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.95))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.6, Color(1, 1, 1, 0.6))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + index
	mm.instance_count = 90 if Settings.quality >= 1 else 40
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(14.0, 160.0)
		var y := rng.randf_range(-30.0, -4.0) if rng.randf() < 0.75 else rng.randf_range(4.0, 22.0)
		var s := rng.randf_range(10.0, 34.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s * 0.55, 1)), Vector3(cos(a) * dist, y, sin(a) * dist)))
		mm.set_instance_color(i, Color(1, 1, 1, rng.randf_range(0.6, 0.95)))
	var clouds := MultiMeshInstance3D.new()
	clouds.multimesh = mm
	clouds.material_override = mat
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)


func on_player_entered(_from_save: bool) -> void:
	_t = 0.0
	_hint = 0
	Game.player.dread.set_values(0.0, 100.0)


func _process(delta: float) -> void:
	_t += delta
	var glow := get_node_or_null("DoorGlow") as OmniLight3D
	if glow:
		glow.light_energy = 2.2 + sin(_t * 1.3) * 0.25
	if Game.in_sequence or Game.player == null:
		return
	if _hint == 0 and _t > 2.0:
		_hint = 1
		Game.hud.show_thought(["...It's quiet. It's warm. It feels like home.", "Sunlight. Real sunlight. I can breathe in here.",
			"The same room. Or one just like it. I'm glad."][(index - 1) % 3], 4.0)


func _leave() -> void:
	_leaving = true
	Sfx.play("whoosh", -8.0, 0.8)
	Game.on_rest_exit(zone_id())
