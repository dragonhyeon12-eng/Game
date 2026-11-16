class_name Player
extends CharacterBody3D
## First-person dreamer: movement, look, head bob, footsteps, interaction, holds (manifest / wake),
## camera jolts and the black hands of the waking sequence. Owns the DREAD and manifestation nodes.

const EYE_HEIGHT := 1.62
const INTERACT_RANGE := 2.3
const MANIFEST_HOLD := 1.0
const WAKE_HOLD := 2.0
const GRAVITY := 18.0
const JUMP_SPEED := 4.6

var camera: Camera3D
var head: Node3D
var hold_point: Node3D
var dread: Dread
var manifestation: Manifestation
var hands: FPHands
var ray: RayCast3D

var controls_locked := true
var walk_speed := 2.6
var sprint_speed := 4.3
var surface := "concrete"   # footstep sound set, chosen by the zone
var phasing := false

var focused: Object = null
var swimming := false
var _climb_t := 0.0   # > 0 while hauling yourself out of the water onto a ledge
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
const CLIMB_TIME := 0.55
var underwater := false
## 1 = full lungs, 0 = nothing left
var breath := 1.0
const BREATH_SECONDS := 22.0
const SWIM_SPEED := 2.2
var manifest_hold := -1.0
var wake_hold := -1.0

var _pitch := 0.0
var _bob_phase := 0.0
var _bob_blend := 0.0
var _step_acc := 0.0
var _jolt := Vector3.ZERO
var _crouched := false
var _shape: CollisionShape3D
var _hands: Array[Node3D] = []
var _hands_t := -1.0
var _ankle_hands: Array[Node3D] = []
var _ankle_t := -1.0
var pulled_down := false
var _drone: AudioStreamPlayer


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 4

	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.76
	_shape.shape = cap
	_shape.position.y = 0.88
	add_child(_shape)

	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 80.0
	camera.near = 0.05
	camera.far = 800.0
	head.add_child(camera)

	hands = FPHands.new()
	hands.name = "Hands"
	camera.add_child(hands)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -INTERACT_RANGE)
	ray.collide_with_areas = true
	ray.collision_mask = 1 | 8
	camera.add_child(ray)

	dread = Dread.new()
	dread.name = "Dread"
	add_child(dread)
	manifestation = Manifestation.new()
	manifestation.name = "Manifestation"
	add_child(manifestation)

	_drone = AudioStreamPlayer.new()
	add_child(_drone)


func _ready() -> void:
	hold_point = hands.right_socket
	ray.add_exception(self)
	_drone.stream = Sfx.streams.get("drone")
	_drone.volume_db = -80.0
	_drone.play()
	_build_hands()
	Settings.changed.connect(apply_settings)
	apply_settings()


func apply_settings() -> void:
	camera.fov = Settings.fov


# ------------------------------------------------------------------ state

func set_locked(locked: bool) -> void:
	controls_locked = locked
	if locked:
		manifest_hold = -1.0
		wake_hold = -1.0
		velocity.x = 0.0
		velocity.z = 0.0
		focused = null


func teleport(xf: Transform3D) -> void:
	global_position = xf.origin
	rotation = Vector3(0, xf.basis.get_euler().y, 0)
	_pitch = xf.basis.get_euler().x
	head.rotation.x = _pitch
	velocity = Vector3.ZERO
	_jolt = Vector3.ZERO
	if _crouched:
		_set_crouch(false)


func set_movement(walk: float, sprint: float, floor_surface: String) -> void:
	walk_speed = walk
	sprint_speed = sprint
	surface = floor_surface


## Fall through the world (used when the dream drops you).
func set_phasing(on: bool) -> void:
	phasing = on
	collision_mask = 0 if on else (1 | 4)


func reset_presentation() -> void:
	hands.conjuring = false
	_ankle_t = -1.0
	pulled_down = false
	for h in _ankle_hands:
		h.visible = false
	_hands_t = -1.0
	for h in _hands:
		h.visible = false
	_jolt = Vector3.ZERO
	set_phasing(false)
	manifestation.clear_all()
	set_drone(0.0)


func jolt(kick_deg: Vector3) -> void:
	if Settings.camera_effects:
		_jolt += kick_deg


## Two black hands come up out of the floor beneath you and close around your ankles.
## The view is dragged down to look at them.
func play_ankle_grab() -> void:
	if _ankle_hands.is_empty():
		var mat := Shapes.void_material()
		for side in [-1.0, 1.0]:
			var h := Node3D.new()
			add_child(h)
			var parts := [["sphere", Vector3(0, 0, 0), Vector3(0.13, 0.05, 0.16)],
				["capsule", Vector3(0, -0.45, 0.02), Vector3(0.09, 0.45, 0.09)]]   # palm, a long forearm reaching up from below
			for f in 4:
				parts.append(["capsule", Vector3((-0.045 + f * 0.03), 0.07, -0.1), Vector3(0.022, 0.11, 0.022)])
			for pinfo in parts:
				var mi := MeshInstance3D.new()
				mi.mesh = Shapes.mesh(pinfo[0])
				mi.material_override = mat
				mi.position = pinfo[1]
				mi.scale = pinfo[2]
				h.add_child(mi)
			h.set_meta("side", side)
			_ankle_hands.append(h)
	_ankle_t = 0.0
	for h in _ankle_hands:
		h.visible = true


func play_shoulder_grab() -> void:
	_hands_t = 0.0
	for h in _hands:
		h.visible = true


func set_drone(intensity: float) -> void:
	var v := intensity * Settings.audio_intensity
	_drone.volume_db = -80.0 if v <= 0.01 else linear_to_db(v) - 6.0


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := 0.0022 * Settings.mouse_sensitivity
		rotate_y(-event.relative.x * s)
		_pitch = clampf(_pitch - event.relative.y * s * (-1.0 if Settings.invert_y else 1.0), deg_to_rad(-88), deg_to_rad(88))
		head.rotation.x = _pitch
		hands.add_sway(event.relative)
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("use_item"):
		manifestation.use_held()
	elif event.is_action_pressed("throw_item"):
		manifestation.throw_held()
	elif event.is_action_pressed("cycle_next"):
		manifestation.cycle(1)
	elif event.is_action_pressed("cycle_prev"):
		manifestation.cycle(-1)
	elif event.is_action_pressed("crouch") and not swimming:
		_set_crouch(not _crouched)
	elif event.is_action_pressed("manifest"):
		manifest_hold = 0.0
	elif event.is_action_released("manifest"):
		manifest_hold = -1.0
	elif event.is_action_pressed("wake"):
		var z = Game.zone_type
		if z == "city" or z == "maze":
			wake_hold = 0.0
	elif event.is_action_released("wake"):
		wake_hold = -1.0


func _interact() -> void:
	if focused and is_instance_valid(focused) and focused.can_interact():
		hands.reach()
		focused.interact()


func _set_crouch(on: bool) -> void:
	if not on and _crouched:
		# no standing up under a low ceiling
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.UP * 1.85, 1)
		q.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return
	_crouched = on
	var cap := _shape.shape as CapsuleShape3D
	cap.height = 1.1 if on else 1.76
	_shape.position.y = cap.height * 0.5


# ------------------------------------------------------------------ per frame

func _physics_process(delta: float) -> void:
	# gamepad look
	if not controls_locked:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.0:
			var s := 2.6 * Settings.mouse_sensitivity * delta
			rotate_y(-look.x * s)
			_pitch = clampf(_pitch - look.y * s * (-1.0 if Settings.invert_y else 1.0), deg_to_rad(-88), deg_to_rad(88))
			head.rotation.x = _pitch

	var input := Vector2.ZERO if controls_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if pulled_down:
		velocity = Vector3(0, -9.0, 0)
		global_position += velocity * delta   # straight through the floor
		_update_camera(delta)
		_update_hands(delta)
		return
	if _update_water(delta, input):
		_update_camera(delta)
		_update_holds(delta)
		_update_hands(delta)
		_update_focus()
		return
	var sprinting := Input.is_action_pressed("sprint") and not controls_locked and not _crouched
	var speed := (1.4 if _crouched else (sprint_speed if sprinting else walk_speed))
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized() * minf(input.length(), 1.0)

	var accel := 12.0 if is_on_floor() else 2.0
	var want := dir * speed
	if Game.zone and Game.zone.has_method("wind_at"):
		want += Game.zone.wind_at(global_position) * (0.0 if _crouched else 1.0)
	velocity.x = lerpf(velocity.x, want.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, want.z, clampf(accel * delta, 0.0, 1.0))
	if not is_on_floor() or phasing:
		var gs: float = Game.zone.gravity_scale_at(global_position) if Game.zone else 1.0
		velocity.y -= GRAVITY * gs * delta
		if Game.zone:
			velocity.y = maxf(velocity.y, -Game.zone.max_fall_at(global_position))
	elif Input.is_action_just_pressed("jump") and not controls_locked and not _crouched:
		velocity.y = JUMP_SPEED
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()

	_update_camera(delta)
	_update_footsteps(delta)
	_update_holds(delta)
	_update_hands(delta)
	hands.pose_right = "hold" if manifestation.held != null else "relaxed"
	hands.conjuring = manifest_hold >= 0.0 and not controls_locked
	_update_focus()


## Swimming: returns true when it handled movement this frame.
## A floor you could pull yourself onto: in front of you, just above the water, with room to stand.
func _find_ledge(level: float):
	var space := get_world_3d().direct_space_state
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for reach in [0.6, 0.9, 1.2]:
		var top: Vector3 = global_position + fwd * reach
		var q := PhysicsRayQueryParameters3D.create(Vector3(top.x, level + 2.0, top.z), Vector3(top.x, level - 0.4, top.z), 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.y < 0.7 or hit.position.y < level - 0.25:
			continue
		# headroom
		var h := PhysicsRayQueryParameters3D.create(hit.position + Vector3.UP * 0.05, hit.position + Vector3.UP * 1.8, 1)
		h.exclude = [get_rid()]
		if not space.intersect_ray(h).is_empty():
			continue
		return hit.position
	return null


func _update_water(delta: float, input: Vector2) -> bool:
	if _climb_t > 0.0:
		# up and over: rise first, then forward onto the deck
		_climb_t = maxf(_climb_t - delta, 0.0)
		var k := 1.0 - _climb_t / CLIMB_TIME
		var up := clampf(k / 0.6, 0.0, 1.0)
		var over := clampf((k - 0.4) / 0.6, 0.0, 1.0)
		global_position = Vector3(lerpf(_climb_from.x, _climb_to.x, over), lerpf(_climb_from.y, _climb_to.y + 0.05, ease(up, 0.5)), lerpf(_climb_from.z, _climb_to.z, over))
		velocity = Vector3.ZERO
		underwater = false
		swimming = false
		return true
	var level: float = Game.zone.water_level_at(global_position + Vector3.UP * 0.9) if Game.zone and not phasing else -INF
	var was := swimming
	var walking_under: bool = Game.zone != null and Game.zone.has_method("walk_underwater") and Game.zone.walk_underwater()
	swimming = global_position.y + 1.0 < level and not walking_under
	underwater = camera.global_position.y < level
	# breath
	var can_breathe: bool = Game.zone != null and Game.zone.has_method("breathable_at") and Game.zone.breathable_at(camera.global_position)
	if underwater and not can_breathe:
		breath = maxf(0.0, breath - delta / BREATH_SECONDS)
		if breath < 0.3:
			dread.add_fear((22.0 if breath <= 0.0 else 4.0) * delta, "drowning")
	else:
		if breath < 0.5 and not controls_locked and was:
			Sfx.play("whoosh", -14.0, 2.4)   # a gasp
		breath = minf(1.0, breath + delta / 3.0)
	if swimming != was:
		var cap := _shape.shape as CapsuleShape3D
		cap.height = 0.9 if swimming else (1.1 if _crouched else 1.76)
		_shape.position.y = cap.height * 0.5 + (0.4 if swimming else 0.0)
		if swimming:
			Sfx.play("splash", -6.0)
	if not swimming:
		return false

	var vert := 0.0
	if not controls_locked:
		if Input.is_action_pressed("jump"): vert += 1.0
		if Input.is_action_pressed("crouch"): vert -= 1.0
	var wish: Vector3 = camera.global_transform.basis * Vector3(input.x, 0, input.y) + Vector3.UP * vert
	var spd := minf(SWIM_SPEED, sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	var target := wish.limit_length(1.0) * spd
	var eye_depth := level - camera.global_position.y
	var drift: float = Game.zone.swim_drift_at(global_position) if Game.zone and Game.zone.has_method("swim_drift_at") else 0.8
	if drift < 0.0:
		target.y = minf(target.y, 0.0) + drift   # sinking: you cannot swim against it
	elif vert == 0.0 and input.length() < 0.1:
		target.y += drift  # you float up, slowly
	if drift >= 0.0 and eye_depth < 0.6 and not controls_locked and Input.is_action_just_pressed("jump"):
		var ledge = _find_ledge(level)
		if ledge != null:
			# haul yourself up and out over the edge
			_climb_from = global_position
			_climb_to = ledge
			_climb_t = CLIMB_TIME
			swimming = false
			var cap := _shape.shape as CapsuleShape3D
			cap.height = 1.76
			_shape.position.y = 0.88
			Sfx.play("splash", -8.0, 1.3)
			jolt(Vector3(3, 0, 0))
			return true
	if drift >= 0.0 and eye_depth < 0.35 and vert >= 0.0:
		# at the surface: keep the head out of the water
		target.y = clampf((level - 1.25 - global_position.y) * 3.0, -1.0, 1.0)
	velocity = velocity.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	move_and_slide()
	return true


func _update_camera(delta: float) -> void:
	_jolt = _jolt.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	camera.rotation_degrees = _jolt
	var flat := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and flat > 0.3 and not controls_locked
	_bob_blend = lerpf(_bob_blend, 1.0 if (moving and Settings.head_bob) else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	if moving:
		_bob_phase += delta * flat / 1.7 * PI
	var amp := _bob_blend * clampf(flat / 3.0, 0.4, 1.4) * 0.011
	var eye := (1.05 if _crouched else EYE_HEIGHT)
	head.position.y = lerpf(head.position.y, eye, clampf(delta * 10.0, 0.0, 1.0))
	camera.position = Vector3(cos(_bob_phase) * amp * 0.8, (absf(sin(_bob_phase)) * 2.0 - 1.0) * amp, 0)


func _update_ankle_hands(delta: float) -> void:
	if _ankle_t < 0.0:
		return
	_ankle_t += delta
	var a := clampf(_ankle_t / 0.7, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - a, 3.0)
	for h in _ankle_hands:
		var side: float = h.get_meta("side")
		h.position = Vector3(0.14 * side, lerpf(-1.4, 0.12, e), -0.08)
		h.rotation_degrees = Vector3(lerpf(-40.0, 10.0, e), 0, 25.0 * side * (1.0 - e))
	# the view is pulled down to see them
	_pitch = lerpf(_pitch, deg_to_rad(-72.0), clampf(delta * 3.0, 0.0, 1.0))
	head.rotation.x = _pitch


func _update_footsteps(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or flat < 0.4:
		_step_acc = minf(_step_acc, 1.2)
		return
	_step_acc += flat * delta
	var stride := 2.1 if flat > 3.5 else 1.65
	if _step_acc >= stride:
		_step_acc = 0.0
		var surf := surface
		if Game.zone and Game.zone.has_method("surface_at"):
			surf = Game.zone.surface_at(global_position)
		Sfx.play("step_%s_%d" % [surf, randi() % 4], linear_to_db(clampf(flat / 3.5, 0.5, 1.2)) - 6.0, randf_range(0.93, 1.07))


func _update_holds(delta: float) -> void:
	if controls_locked:
		return
	if manifest_hold >= 0.0:
		manifest_hold += delta / MANIFEST_HOLD
		if manifest_hold >= 1.0:
			manifest_hold = -1.0
			manifestation.try_manifest()
	if wake_hold >= 0.0:
		wake_hold += delta / WAKE_HOLD
		if wake_hold >= 1.0:
			wake_hold = -1.0
			Game.request_wake()


func _update_focus() -> void:
	focused = null
	if controls_locked:
		return
	ray.force_raycast_update()
	var hit := ray.get_collider()
	while hit != null:
		if hit.has_method("interact") and hit.has_method("get_prompt"):
			if hit.can_interact():
				focused = hit
			return
		hit = hit.get_parent() if hit is Node else null
		if hit is Zone or hit == null:
			return


func prompt() -> String:
	if focused and is_instance_valid(focused):
		return focused.get_prompt()
	return ""


# ------------------------------------------------------------------ the hands

func _build_hands() -> void:
	# Two black, slightly-too-long hands that reach over the shoulders when you "wake up".
	var mat := Shapes.void_material()
	for side in [-1.0, 1.0]:
		var hand := Node3D.new()
		hand.visible = false
		camera.add_child(hand)
		var parts := [
			["box", Vector3(0, 0, 0), Vector3(0.09, 0.025, 0.11), Vector3.ZERO],
			["cylinder", Vector3(0, 0.01, 0.22), Vector3(0.05, 0.4, 0.05), Vector3(90, 0, 0)],
		]
		for f in 4:
			parts.append(["cylinder", Vector3((-0.03 + f * 0.02) * side, -0.03, -0.09), Vector3(0.016, 0.13, 0.016), Vector3(-70, 0, 0)])
		parts.append(["cylinder", Vector3(-0.055 * side, -0.02, -0.02), Vector3(0.018, 0.08, 0.018), Vector3(-40, 0, 50 * side)])
		for p in parts:
			var mi := MeshInstance3D.new()
			mi.mesh = Shapes.mesh(p[0])
			mi.material_override = mat
			mi.position = p[1]
			mi.scale = p[2]
			mi.rotation_degrees = p[3]
			hand.add_child(mi)
		hand.set_meta("side", side)
		_hands.append(hand)


func _update_hands(delta: float) -> void:
	_update_ankle_hands(delta)
	if _hands_t < 0.0:
		return
	_hands_t += delta
	var a := clampf(_hands_t / 0.35, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - a, 3.0)
	for h in _hands:
		var side: float = h.get_meta("side")
		# from behind the shoulders, fingers curling down over them into the bottom corners of view
		var from := Vector3(0.36 * side, -0.5, 0.15)
		var to := Vector3(0.24 * side, -0.19, -0.25)
		h.position = from.lerp(to, e)
		h.rotation_degrees = Vector3(-8.0 + 20.0 * (1.0 - e), -14.0 * side, -6.0 * side)
