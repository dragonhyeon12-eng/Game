class_name Zone
extends Node3D
## A self-contained playable space: geometry, light, sky, audio, characters, anomalies and the dream
## rules that apply inside it. Exactly one zone exists at a time; Game builds it and frees it on exit.
## New realms (THE DEEP, COMPRESSION, ...) are new subclasses. No core system has to change.
##
## Static boxes are batched into one MultiMesh per shape (with per-instance colours) and one
## StaticBody3D, so a whole city costs a handful of draw calls.

# ---- dream rules (override in subclasses)
func zone_id() -> String: return ""
func is_nightmare() -> bool: return false
func allows_manifestation() -> bool: return false
func fear_gain() -> float: return 1.0
func fear_floor() -> float: return 0.0
func fear_decay() -> float: return 1.5
## Footstep sound set: concrete | wood | carpet | grass
func floor_surface() -> String: return "concrete"
func walk_speed() -> float: return 2.6
func sprint_speed() -> float: return 4.3
## True while something is chasing you: the player runs faster for as long as it lasts.
func is_chasing() -> bool: return false
## How strong a pictured flashlight is here (dark realms keep it weak, so the dark still counts).
func flashlight_scale() -> float: return 1.0
## Seconds between unobserved changes when stable / unstable. Negative = never.
func anomaly_pacing() -> Vector2: return Vector2(-1, -1)
func player_start() -> Transform3D: return Transform3D.IDENTITY

## Water surface height at a point, or -INF if there is no water there.
func water_level_at(_p: Vector3) -> float: return -INF
## Dream gravity (1 = normal).
func gravity_scale_at(_p: Vector3) -> float: return 1.0
func max_fall_at(_p: Vector3) -> float: return 60.0

func build() -> void: pass
func on_player_entered(_from_save: bool) -> void: pass
## Called every frame by Game with DREAD 0..100.
func on_dread(_dread: float, _stage: int, _delta: float) -> void: pass
## Story hook from effects ("closer" etc).
func observer_event(_event: String) -> void: pass


# ---- builder state
var _batches := {}           # shape|roughness -> Array[[Transform3D, Color]]
var _body: StaticBody3D
var _ambient: Array = []     # [player, base_db]


func _enter_tree() -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		_body.collision_layer = 1
		add_child(_body)


func _exit_tree() -> void:
	Anomalies.unregister_owner(self)


## Surface argument: a surface name ("tiles_pool", "wood", ... see Shapes.SURFACES) or a roughness float.
static func _surf(surface) -> String:
	if surface is String:
		return surface
	return "plain@%.2f" % float(surface)


## Instanced static shape. Call finish_batches() once after building.
func add_shape(kind: String, xf: Transform3D, color: Color, collide := false, surface: Variant = "plain") -> void:
	var key := "%s|%s" % [kind, _surf(surface)]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append([xf, color])
	if collide:
		var cs := CollisionShape3D.new()
		match kind:
			"sphere":
				var s := SphereShape3D.new()
				s.radius = 0.5
				cs.shape = s
			"cylinder", "cone", "pipe":
				var c := CylinderShape3D.new()
				c.radius = 0.5
				c.height = 1.0
				cs.shape = c
			_:
				var b := BoxShape3D.new()
				b.size = Vector3.ONE
				cs.shape = b
		# Collision shapes must not be scaled non-uniformly, so bake scale into box size where possible.
		if cs.shape is BoxShape3D:
			cs.shape.size = xf.basis.get_scale()
			cs.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		elif cs.shape is CylinderShape3D:
			var sc := xf.basis.get_scale()
			cs.shape.radius = 0.5 * maxf(sc.x, sc.z)
			cs.shape.height = sc.y
			cs.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		else:
			cs.shape.radius = 0.5 * xf.basis.get_scale().x
			cs.transform = Transform3D(Basis(), xf.origin)
		_body.add_child(cs)


func box(center: Vector3, size: Vector3, color: Color, collide := true, yaw_deg := 0.0, surface: Variant = "plain") -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.from_scale(size)
	add_shape("box", Transform3D(b, center), color, collide, surface)


func shape_at(kind: String, center: Vector3, scale: Vector3, color: Color, collide := false, rot_deg := Vector3.ZERO, surface: Variant = "plain") -> void:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scale)
	add_shape(kind, Transform3D(b, center), color, collide, surface)


# ---- models from tools/creatures (models/props): placed one by one, or batched

var _scatter := {}     # "slot|mesh|tint|shadow" -> [Mesh, Array[[Transform3D, Color]], cast_shadow]


## A prop model at a position (yaw in degrees, uniform scale). Null if the model is missing.
func prop(slot: String, pos: Vector3, yaw_deg := 0.0, s := 1.0, parent: Node3D = null) -> Node3D:
	var n := Props.instance(slot)
	if n == null:
		return null
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * s
	(parent if parent else self).add_child(n)
	return n


## Many copies of one mesh in a single draw (grass, building modules). False if the model is missing.
func scatter(slot: String, xf: Transform3D, color := Color.WHITE, mesh_name := "", tint := false, shadows := true) -> bool:
	var key := "%s|%s|%s|%s" % [slot, mesh_name, tint, shadows]
	if not _scatter.has(key):
		var m := Props.mesh(slot, mesh_name, tint)
		if m == null:
			return false
		_scatter[key] = [m, [], shadows]
	_scatter[key][1].append([xf, color])
	return true


## A building assembled from the facade kit: window bays on every side (shopfronts on the ground floor
## if `shops`), a cornice, a flat roof. `style` is "brick", "plaster", "modern" or "tower" (curtain wall;
## `lit` mixes in lit office windows). `from_floor` skips the lower floors (for towers that vanish into fog).
## Returns false (nothing built) if the kit is missing.
func facade_building(center: Vector3, w: float, d: float, floors: int, style: String, color: Color,
		shops := false, lit := 0.0, from_floor := 0, rng: RandomNumberGenerator = null) -> bool:
	if not Props.has("facade_kit"):
		return false
	var bay := "bay_" + style
	var ground_h := 4.2 if shops else 3.6
	var total := ground_h + floors * 3.6
	for face in 4:
		var n := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][face] as Vector3
		var length := w if face < 2 else d
		var half_other := (d if face < 2 else w) * 0.5
		var count := maxi(1, roundi(length / 3.0))
		var bw := length / count
		var basis := Basis(Vector3.UP, atan2(n.x, n.z)) * Basis.from_scale(Vector3(bw / 3.0, 1, 1))
		var along := n.cross(Vector3.UP) * -1.0
		for i in count:
			var off: float = -length * 0.5 + bw * (i + 0.5)
			var base: Vector3 = center + n * half_other + along * off
			for f in range(from_floor, floors + 1):
				var y := 0.0 if f == 0 else ground_h + (f - 1) * 3.6
				var module := bay
				if f == 0 and shops:
					module = "shop"
				elif style == "tower" and lit > 0.0 and rng and rng.randf() < lit:
					module = "bay_tower_lit"
				if f == 0 and shops:
					var sb := Basis(Vector3.UP, atan2(n.x, n.z)) * Basis.from_scale(Vector3(bw / 3.0, 1, 1))
					scatter("facade_kit", Transform3D(sb, base + Vector3(0, y, 0)), color, "shop", true)
				else:
					scatter("facade_kit", Transform3D(basis, base + Vector3(0, y, 0)), color, module, true)
			if style != "tower":
				scatter("facade_kit", Transform3D(basis, base + Vector3(0, total, 0)), color, "cornice", true)
	# the solid core (collision, roof), set back behind the modules
	box(center + Vector3(0, total * 0.5, 0), Vector3(w - 0.5, total, d - 0.5), color.darkened(0.3), true, 0.0, "concrete")
	box(center + Vector3(0, total + 0.6, 0), Vector3(w - 0.1, 0.1, d - 0.1), Color(0.35, 0.35, 0.36), false, 0.0, "concrete")
	return true


const BATCH_CELL := 64.0     # small scattered things (grass...) are split into cells this size, so the camera can cull them


## Instances [[Transform3D, Color], ...] grouped by cell.
static func _cells(list: Array, cell := BATCH_CELL) -> Dictionary:
	var out := {}
	for it in list:
		var o: Vector3 = (it[0] as Transform3D).origin
		var k := Vector2i(floori(o.x / cell + 0.5), floori(o.z / cell + 0.5))
		if not out.has(k):
			out[k] = []
		out[k].append(it)
	return out


func _multimesh(mesh: Mesh, list: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_color(i, list[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


func _finish_scatter() -> void:
	for key in _scatter:
		var e: Array = _scatter[key]
		var mesh: Mesh = e[0]
		# small things (grass, pebbles) fade out with distance; nobody sees a grass clump 80 m away
		var small := mesh != null and mesh.get_aabb().size.length() < 1.6
		for cell in _cells(e[1], BATCH_CELL if small else 32.0).values():   # (big modules: smaller cells, culled and simplified sooner)
			var mmi := _multimesh(mesh, cell)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if e[2] and not small else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not small and Settings.quality < 1:
				mmi.visibility_range_end = 150.0      # LOW: building modules etc. are left out far away
				mmi.visibility_range_end_margin = 10.0
			if small:
				mmi.visibility_range_end = 70.0 if Settings.quality >= 1 else 40.0
				mmi.visibility_range_end_margin = 10.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_scatter.clear()


const CHUNK := 24.0         # static shapes are batched per 24 m square, so the camera culls what's behind it
							# and a lamp only re-draws the shapes near it (the browser renderer draws once per light)


func finish_batches() -> void:
	_finish_scatter()
	for key in _batches:
		var parts: PackedStringArray = key.split("|", true, 1)
		var mesh := Shapes.mesh(parts[0])
		var mat := Shapes.surface(parts[1])
		var chunks := {}
		for it in _batches[key]:
			var xf: Transform3D = it[0]
			var sc := xf.basis.get_scale()
			var k := Vector3i(9999, 0, 9999)      # huge things (ground, long walls) stay together
			if maxf(sc.x, maxf(sc.y, sc.z)) < CHUNK:
				k = Vector3i(floori(xf.origin.x / CHUNK), floori(xf.origin.y / (CHUNK * 2.0)), floori(xf.origin.z / CHUNK))
			if not chunks.has(k):
				chunks[k] = []
			chunks[k].append(it)
		for k in chunks:
			var mmi := _multimesh(mesh, chunks[k])
			mmi.material_override = mat
	_batches.clear()


## LOW graphics quality: no shadows from lamps, a smaller shadow budget, lights skipped sooner.
func cheapen() -> void:
	if Settings.quality >= 1:
		return
	for l in find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			l.directional_shadow_max_distance = minf(l.directional_shadow_max_distance, 40.0)
		else:
			l.shadow_enabled = false
			if l.distance_fade_enabled:
				l.distance_fade_begin = minf(l.distance_fade_begin, 30.0)
	for e in _envs:
		e.glow_enabled = false
		e.ssao_enabled = false
		e.adjustment_enabled = false
		if e.sky:
			# a moving sky re-lights the scene every frame: do it in small steps, at low resolution
			e.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
			e.sky.radiance_size = Sky.RADIANCE_SIZE_32
			if e.sky.sky_material is ShaderMaterial:
				(e.sky.sky_material as ShaderMaterial).set_shader_parameter("octaves", 3)
	# trees and figures far away: not drawn (there are hundreds of trees, and figures are many parts each)
	for n in find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0:
			continue
		var far := 0.0
		var a: Node = gi
		while a != null and a != self:
			if a is Mannequin:
				far = 40.0
				break
			if String(a.name).to_lower().begins_with("tree"):
				far = 70.0
				break
			a = a.get_parent()
		if far > 0.0:
			gi.visibility_range_end = far
			gi.visibility_range_end_margin = 6.0


## An individual mesh (for things that change at runtime).
func part(kind: String, pos: Vector3, scale: Vector3, color: Color, parent: Node3D = null, rot_deg := Vector3.ZERO,
		emission := 0.0, surface: Variant = 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	if emission > 0.0 or not surface is String:
		mi.material_override = Shapes.material(color, 0.85 if surface is String else float(surface), emission)
	else:
		mi.material_override = Shapes.surface(surface, color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	(parent if parent else self).add_child(mi)
	return mi


## A model in place of built shapes: `slot` at pos/yaw (scale s); with a `solid` size, an invisible box of that
## size (centred `solid_at` above pos) keeps it solid. False if the model is missing: the caller builds shapes.
func furnish(slot: String, pos: Vector3, yaw_deg := 0.0, solid := Vector3.ZERO, solid_at := Vector3.ZERO, s := 1.0) -> bool:
	if prop(slot, pos, yaw_deg, s) == null:
		return false
	if solid != Vector3.ZERO:
		var b := StaticBody3D.new()
		b.collision_layer = 1
		b.position = pos + solid_at
		b.rotation_degrees.y = yaw_deg
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = solid
		cs.shape = bs
		b.add_child(cs)
		add_child(b)
	return true


## A movable solid box (own body) - for walls that come and go.
func solid_box(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null, surface := "plain") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh("box")
	mi.scale = size
	mi.material_override = Shapes.surface(surface, color)
	body.add_child(mi)
	(parent if parent else self).add_child(body)
	return body


## A proper door: frame, slab with raised panels, lever handle and kick plate.
## The door faces +Z of its yaw (handle side = +X). Returns the door's root; the moving part is its "Leaf"
## child, hinged at the -X edge of the frame (see open_door).
func door(pos: Vector3, yaw_deg: float, color: Color, width := 0.92, height := 2.05, surface := "wood") -> Node3D:
	var d := group(pos, yaw_deg)
	if _door_model(d, color, width, height):
		return d
	var frame := color.darkened(0.25)
	part("box", Vector3(-width * 0.5 - 0.04, height * 0.5, 0), Vector3(0.08, height + 0.04, 0.14), frame, d, Vector3.ZERO, 0.0, surface)
	part("box", Vector3(width * 0.5 + 0.04, height * 0.5, 0), Vector3(0.08, height + 0.04, 0.14), frame, d, Vector3.ZERO, 0.0, surface)
	part("box", Vector3(0, height + 0.04, 0), Vector3(width + 0.16, 0.08, 0.14), frame, d, Vector3.ZERO, 0.0, surface)
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-width * 0.5, 0, 0)
	d.add_child(leaf)
	var c := width * 0.5    # the leaf's own x runs from the hinge (0) to the latch (width)
	part("box", Vector3(c, height * 0.5, 0), Vector3(width, height, 0.045), color, leaf, Vector3.ZERO, 0.0, surface)
	for row in 2:
		var ph := height * (0.38 if row == 1 else 0.3)
		var py := height * (0.7 if row == 1 else 0.27)
		for col in 2:
			var px := c + (col - 0.5) * width * 0.44
			part("box", Vector3(px, py, 0.026), Vector3(width * 0.34, ph, 0.012), color.lightened(0.04), leaf, Vector3.ZERO, 0.0, surface)
			part("box", Vector3(px, py, -0.026), Vector3(width * 0.34, ph, 0.012), color.lightened(0.04), leaf, Vector3.ZERO, 0.0, surface)
	var brass := Color(0.75, 0.62, 0.35)
	for side in [1.0, -1.0]:
		part("cylinder", Vector3(c + width * 0.38, 1.0, 0.045 * side), Vector3(0.05, 0.03, 0.05), brass, leaf, Vector3(90, 0, 0), 0.0, "metal")
		part("box", Vector3(c + width * 0.38 - 0.05, 1.0, 0.07 * side), Vector3(0.12, 0.022, 0.022), brass, leaf, Vector3.ZERO, 0.0, "metal")
		part("box", Vector3(c, 0.12, 0.027 * side), Vector3(width * 0.9, 0.2, 0.006), brass.darkened(0.3), leaf, Vector3.ZERO, 0.0, "metal")
	return d


static var _door_scene: PackedScene
static var _door_checked := false


## The door from tools/creatures/items.py: its frame, and its leaf hung on a "Leaf" pivot at the hinge
## (so open_door works the same). Painted the door's colour; the frame a shade darker.
func _door_model(d: Node3D, color: Color, width: float, height: float) -> bool:
	if not _door_checked:
		_door_checked = true
		var path := Models.find("props/door_panel")
		_door_scene = load(path) as PackedScene if path != "" else null
	if _door_scene == null:
		return false
	var src := _door_scene.instantiate()
	var frame_mesh: Mesh = null
	var leaf_mesh: Mesh = null
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("Frame"):
			frame_mesh = mi.mesh
		elif String(mi.name).begins_with("Leaf"):
			leaf_mesh = mi.mesh
	src.free()
	if frame_mesh == null or leaf_mesh == null:
		return false
	var sc := Vector3(width / 0.92, height / 2.05, 1.0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.45
	var frame_paint := StandardMaterial3D.new()
	frame_paint.albedo_color = color.darkened(0.25)
	frame_paint.roughness = 0.5
	var fm := MeshInstance3D.new()
	fm.mesh = frame_mesh
	fm.scale = sc
	d.add_child(fm)
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-width * 0.5, 0, 0)
	d.add_child(leaf)
	var lm := MeshInstance3D.new()
	lm.mesh = leaf_mesh
	lm.scale = sc
	leaf.add_child(lm)
	for pair in [[fm, frame_paint], [lm, paint]]:
		var m: MeshInstance3D = pair[0]
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat and String(mat.resource_name).contains("paint"):
				m.set_surface_override_material(k, pair[1])
	return true


## Swing a door() open on its hinge. Positive degrees swing it away from the side it faces (its -Z).
func open_door(d: Node3D, degrees := 95.0, seconds := 1.4) -> void:
	var leaf := d.get_node_or_null("Leaf") as Node3D
	if leaf == null:
		return
	create_tween().tween_property(leaf, "rotation_degrees:y", degrees, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func group(pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
	return n


func omni(pos: Vector3, color: Color, energy: float, rng: float, shadows := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows and Settings.quality >= 1
	_fade_with_distance(l, rng)
	add_child(l)
	return l


## Lights far from the camera are skipped entirely (performance); shadows stop even sooner.
static func _fade_with_distance(l: Light3D, rng: float) -> void:
	l.distance_fade_enabled = true
	l.distance_fade_begin = maxf(40.0, rng * 3.0)
	l.distance_fade_length = 12.0
	l.distance_fade_shadow = 22.0


func spot(pos: Vector3, look_at_pos: Vector3, color: Color, energy: float, rng: float, angle: float, shadows := true) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	l.shadow_enabled = shadows
	_fade_with_distance(l, rng)
	l.look_at_from_position(pos, look_at_pos, Vector3.UP if absf((look_at_pos - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	return l


func label(pos: Vector3, yaw_deg: float, text: String, size: float, color := Color.WHITE, emissive := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.modulate = color
	l.outline_size = 0
	l.shaded = not emissive
	l.double_sided = false
	add_child(l)
	return l


func interactable(pos: Vector3, size: Vector3, prompt: Callable, action: Callable, can := Callable()) -> Interactable:
	var a := Interactable.create(size, prompt, action, can)
	a.position = pos
	add_child(a)
	return a


## An invisible volume that runs `fn` when the player walks into it (once, unless once = false).
## For scares, sounds and story beats placed in the world.
func trigger(center: Vector3, size: Vector3, fn: Callable, once := true) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2          # the player
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	a.add_child(cs)
	a.position = center
	add_child(a)
	a.body_entered.connect(func(body):
		if body is Player and not Game.in_sequence:
			fn.call()
			if once:
				a.queue_free())
	return a


## A scare: a sting of sound and a jolt of fear (a stinger name from Sfx, e.g. "screech", "braam", "hit").
func scare(sound: String, fear := 8.0, volume_db := 0.0, jolt := Vector3.ZERO) -> void:
	Sfx.stinger(sound, volume_db)
	if Game.player:
		Game.player.dread.add_fear(fear, "scare")
		if jolt != Vector3.ZERO:
			Game.player.jolt(jolt)


## A level painted as text: rows of characters, '#' = solid, anything else = open floor with the
## ceiling height given for that character. `origin` is the outer corner of cell (0, 0). Walls are
## only built where they touch open space, merged into runs; floors and ceilings are merged too.
func build_grid(rows: Array, origin: Vector3, cell: float, ceilings: Dictionary, wall_h: float,
		wall_col: Color, floor_col: Color, ceil_col: Color, wall_surf := "concrete", floor_surf := "concrete") -> void:
	var h := rows.size()
	var at := func(c: int, r: int) -> String:
		if r < 0 or r >= h or c < 0 or c >= (rows[r] as String).length():
			return "#"
		return (rows[r] as String)[c]
	for r in h:
		var row: String = rows[r]
		var c := 0
		while c < row.length():
			var ch: String = row[c]
			var c1 := c
			while c1 + 1 < row.length() and row[c1 + 1] == ch:
				c1 += 1
			var x0 := origin.x + c * cell
			var x1 := origin.x + (c1 + 1) * cell
			var zc := origin.z + (r + 0.5) * cell
			if ch == "#":
				# only the wall cells that face open space
				var k := c
				while k <= c1:
					var touches := false
					for dr in [-1, 0, 1]:
						for dc in [-1, 0, 1]:
							if at.call(k + dc, r + dr) != "#":
								touches = true
					if touches:
						var k1 := k
						while k1 + 1 <= c1:
							var t2 := false
							for dr in [-1, 0, 1]:
								for dc in [-1, 0, 1]:
									if at.call(k1 + 1 + dc, r + dr) != "#":
										t2 = true
							if not t2:
								break
							k1 += 1
						box(Vector3(origin.x + (k + k1 + 1) * 0.5 * cell, origin.y + wall_h * 0.5, zc), Vector3((k1 - k + 1) * cell, wall_h, cell), wall_col, true, 0.0, wall_surf)
						k = k1 + 1
					else:
						k += 1
			else:
				var ceil_h: float = ceilings.get(ch, wall_h)
				box(Vector3((x0 + x1) * 0.5, origin.y - 0.1, zc), Vector3(x1 - x0, 0.2, cell), floor_col, true, 0.0, floor_surf)
				box(Vector3((x0 + x1) * 0.5, origin.y + (ceil_h + wall_h) * 0.5 + 0.1, zc), Vector3(x1 - x0, wall_h - ceil_h + 0.2, cell), ceil_col, true, 0.0, wall_surf)
			c = c1 + 1


## Slowly drifting particles in the water around the camera ("marine snow").
func marine_snow(amount := 600, color := Color(0.7, 0.85, 0.9, 0.5)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 8, 14)
	p.direction = Vector3(0.2, -1, 0.1)
	p.spread = 30.0
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0, -0.01, 0)
	p.scale_amount_min = 0.015
	p.scale_amount_max = 0.04
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.albedo_texture = _soft_dot()
	m.disable_receive_shadows = true
	q.material = m
	p.mesh = q
	p.local_coords = false
	add_child(p)
	return p


static var _dot: GradientTexture2D

static func _soft_dot() -> Texture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = g
	return _dot


func blocker(center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	_body.add_child(cs)


func ambient(sound: String, pos: Vector3, positional: bool, volume_db: float, max_distance := 30.0) -> Node:
	var p: Node = Sfx.make_loop(sound, positional, volume_db, max_distance)
	if p is Node3D:
		p.position = pos
	add_child(p)
	return p


func environment(env: Environment) -> void:
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Common environment settings, respecting the quality setting.
func make_env(ambient_color: Color, ambient_energy: float) -> Environment:
	var e := Environment.new()
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient_color
	e.ambient_light_energy = ambient_energy
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	if Settings.quality >= 1:
		e.ssao_enabled = true
		e.ssao_intensity = 1.5
	if _envs.is_empty():
		Settings.changed.connect(apply_super_shaders)
		apply_super_shaders.call_deferred()  # after the zone has finished configuring its environments
	_envs.append(e)
	return e


var _envs: Array[Environment] = []
const _SUPER_PROPS := ["sdfgi_enabled", "ssil_enabled", "ssr_enabled", "ssao_enabled", "ssao_intensity",
	"volumetric_fog_enabled", "volumetric_fog_density", "glow_intensity", "glow_bloom", "adjustment_enabled",
	"adjustment_contrast", "adjustment_saturation"]


## "Super duper shaders": every expensive effect Godot has, on top of whatever the zone set up.
## Turning it off restores the zone's own settings.
func apply_super_shaders() -> void:
	for e in _envs:
		if not e.has_meta("base"):
			var base := {}
			for k in _SUPER_PROPS:
				base[k] = e.get(k)
			e.set_meta("base", base)
		var b: Dictionary = e.get_meta("base")
		for k in _SUPER_PROPS:
			e.set(k, b[k])
		if not Settings.super_shaders:
			continue
		e.sdfgi_enabled = true
		e.sdfgi_use_occlusion = true
		e.ssil_enabled = true
		e.ssr_enabled = true
		e.ssr_max_steps = 64
		e.ssao_enabled = true
		e.ssao_intensity = maxf(b.ssao_intensity, 2.0)
		e.volumetric_fog_enabled = true
		if not b.volumetric_fog_enabled:
			e.volumetric_fog_density = 0.004 if not e.fog_enabled else minf(e.fog_density * 0.4, 0.004)
		e.volumetric_fog_albedo = e.fog_light_color if e.fog_enabled else Color(0.9, 0.9, 0.95)
		e.glow_intensity = b.glow_intensity * 1.3
		e.glow_bloom = b.glow_bloom + 0.05
		e.adjustment_enabled = true
		e.adjustment_contrast = 1.06
		e.adjustment_saturation = 1.08


func ground_y(pos: Vector3, fallback := 0.0) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 20.0, pos + Vector3.DOWN * 50.0, 1)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else fallback


## A checkpoint: from now on, dying (or Continue) puts you back on this spot, with the story as it
## stands. Each one only fires once (by id); calling it again with the same id does nothing.
func checkpoint(id: String, pos: Vector3, yaw_deg := 0.0) -> void:
	var key := "cp_" + zone_id()
	var cur = Game.counters.get(key, {})
	if cur is Dictionary and String(cur.get("id", "")) == id:
		return
	Game.counters[key] = {"id": id, "x": pos.x, "y": pos.y, "z": pos.z, "yaw": deg_to_rad(yaw_deg)}
	Game.save_checkpoint()
	Game.hud.show_hint("Checkpoint.", 2.0)


## Where the last checkpoint in this zone put you (null if there's none).
func saved_checkpoint() -> Variant:
	var cp = Game.counters.get("cp_" + zone_id(), null)
	if not cp is Dictionary:
		return null
	var xf := Transform3D(Basis(Vector3.UP, float(cp.get("yaw", 0.0))), Vector3(float(cp.x), float(cp.y), float(cp.z)))
	return xf


func checkpoint_id() -> String:
	var cp = Game.counters.get("cp_" + zone_id(), null)
	return String(cp.get("id", "")) if cp is Dictionary else ""


## A checkpoint from the zone's CHECKPOINTS table: {id: [spawn position, yaw (deg), [flags set by then]]},
## in the order you reach them. Only ever moves forward (walking back past an earlier one doesn't count).
func checkpoint_at(id: String) -> void:
	var table: Dictionary = get("CHECKPOINTS")
	var keys := table.keys()
	if keys.find(checkpoint_id()) >= keys.find(id):
		return
	checkpoint(id, table[id][0], table[id][1])


## A checkpoint you walk into.
func checkpoint_zone(id: String, center: Vector3, size: Vector3, spawn: Vector3, yaw_deg := 0.0) -> void:
	trigger(center, size, func(): checkpoint(id, spawn, yaw_deg))
