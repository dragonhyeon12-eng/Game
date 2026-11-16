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
## Seconds between unobserved changes when stable / unstable. Negative = never.
func anomaly_pacing() -> Vector2: return Vector2(-1, -1)
func player_start() -> Transform3D: return Transform3D.IDENTITY

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


## Instanced static shape. Call finish_batches() once after building.
func add_shape(kind: String, xf: Transform3D, color: Color, collide := false, roughness := 0.85) -> void:
	var key := "%s|%.2f" % [kind, roughness]
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
			"cylinder", "cone":
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


func box(center: Vector3, size: Vector3, color: Color, collide := true, yaw_deg := 0.0, roughness := 0.85) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis.from_scale(size)
	add_shape("box", Transform3D(b, center), color, collide, roughness)


func shape_at(kind: String, center: Vector3, scale: Vector3, color: Color, collide := false, rot_deg := Vector3.ZERO, roughness := 0.85) -> void:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scale)
	add_shape(kind, Transform3D(b, center), color, collide, roughness)


func finish_batches() -> void:
	for key in _batches:
		var parts: PackedStringArray = key.split("|")
		var list: Array = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Shapes.mesh(parts[0])
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Shapes.instanced_material(parts[1].to_float())
		add_child(mmi)
	_batches.clear()


## An individual mesh (for things that change at runtime).
func part(kind: String, pos: Vector3, scale: Vector3, color: Color, parent: Node3D = null, rot_deg := Vector3.ZERO,
		emission := 0.0, roughness := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.material_override = Shapes.material(color, roughness, emission)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	(parent if parent else self).add_child(mi)
	return mi


## A movable solid box (own body) - for walls that come and go.
func solid_box(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> StaticBody3D:
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
	mi.material_override = Shapes.material(color)
	body.add_child(mi)
	(parent if parent else self).add_child(body)
	return body


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
	l.shadow_enabled = shadows
	add_child(l)
	return l


func spot(pos: Vector3, look_at_pos: Vector3, color: Color, energy: float, rng: float, angle: float, shadows := true) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	l.shadow_enabled = shadows
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
	return e


func ground_y(pos: Vector3, fallback := 0.0) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 20.0, pos + Vector3.DOWN * 50.0, 1)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else fallback
