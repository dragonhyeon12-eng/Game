class_name Observer
extends Node3D
## The black figure. No face, no detail, no collision, no interaction. Proportions slightly wrong:
## too tall, too thin, arms to the knees, head small and tilted. His surface glitches.
##
## Rules:
##  - he never walks: he only ever *is* somewhere else, and only while unobserved;
##  - unwatched, he turns to face you again;
##  - once you have looked at him for a moment he is "spotted" (DREAD +25), and within one or two
##    seconds he glitches out of existence. The zone decides where and when he returns.

signal seen
signal vanished

## Seconds of looking before he counts as spotted.
var seen_threshold := 0.35
## Only counts within this distance (very far away he is easy to overlook).
var seen_max_distance := 90.0
## DREAD added when spotted.
var spot_dread := 25.0
## A reflection: hangs upside down from its position (used in water).
var reflected := false

var observed := false
var observed_time := 0.0
var unobserved_time := 0.0
var spotted := false

var _vanish_after := 1.5
var _vanishing := -1.0
var _pending_move := false
var _pending_pos := Vector3.ZERO
var _check := 0.0
var _glitch := 0.15
var _mat: ShaderMaterial
var _static: AudioStreamPlayer3D
var _t := 0.0
var _body: Node3D
var _flip := 1.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/npc/observer.gdshader")
	_mat.set_shader_parameter("seed", randf() * 100.0)
	_body = Node3D.new()
	add_child(_body)
	_flip = -1.0 if reflected else 1.0
	_body.scale.y = _flip
	# a real model (models/observer.glb) can replace the built-in figure; it gets his glitch all the same
	var model := Models.instance(["observer"])
	if model:
		_use_model(model)
	else:
		var head_tilt := Vector3(14, 0, 11)
		var parts := [
			# legs: long and thin, slightly knock-kneed
			["capsule", Vector3(-0.08, 0.52, 0), Vector3(0.11, 0.53, 0.11), Vector3(0, 0, 2)],
			["capsule", Vector3(0.08, 0.52, 0), Vector3(0.11, 0.53, 0.11), Vector3(0, 0, -2)],
			# narrow torso, chest pushed forward, uneven hunched shoulders
			["capsule", Vector3(0, 1.32, 0.02), Vector3(0.3, 0.33, 0.18), Vector3(8, 0, 0)],
			["sphere", Vector3(-0.17, 1.66, 0.05), Vector3(0.16, 0.13, 0.15), Vector3.ZERO],
			["sphere", Vector3(0.18, 1.62, 0.05), Vector3(0.15, 0.12, 0.15), Vector3.ZERO],
			# arms that hang down to the knees
			["capsule", Vector3(-0.25, 1.28, 0.04), Vector3(0.07, 0.4, 0.07), Vector3(0, 0, -4)],
			["capsule", Vector3(-0.29, 0.66, 0.06), Vector3(0.06, 0.3, 0.06), Vector3(-6, 0, -3)],
			["capsule", Vector3(0.26, 1.24, 0.04), Vector3(0.07, 0.42, 0.07), Vector3(0, 0, 5)],
			["capsule", Vector3(0.31, 0.6, 0.07), Vector3(0.06, 0.31, 0.06), Vector3(-6, 0, 4)],
			# a long, thin neck; a head slightly too small, pushed forward and tilted
			["capsule", Vector3(0, 1.82, 0.08), Vector3(0.075, 0.14, 0.075), Vector3(22, 0, 6)],
			["sphere", Vector3(0.04, 2.0, 0.15), Vector3(0.17, 0.23, 0.19), head_tilt],
		]
		for p in parts:
			_part(p[0], p[1], p[2], p[3])
		# long fingers
		for side in [-1.0, 1.0]:
			var hx: float = 0.31 * side + 0.005
			for f in 4:
				_part("capsule", Vector3(hx + (f - 1.5) * 0.018 * side, 0.27 - f * 0.004, 0.08), Vector3(0.016, 0.085, 0.016), Vector3(-4, 0, (f - 1.5) * 4.0))

	_static = AudioStreamPlayer3D.new()
	_static.stream = Sfx.streams.get("static")
	_static.unit_size = 3.0
	_static.max_distance = 30.0
	_static.volume_db = -80.0
	_static.position.y = 1.5
	add_child(_static)
	_static.play()


func _part(kind: String, pos: Vector3, scl: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.material_override = _mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	if reflected:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)


func _use_model(model: Node3D) -> void:
	var fitted := Models.fit(model, 2.2)
	if not Models.options("observer").has("thin"):
		fitted.scale = Vector3(0.88, 1.0, 0.88)   # a little too thin, like the built-in one
	else:
		var thin := float(Models.options("observer")["thin"])
		fitted.scale = Vector3(thin, 1.0, thin)
	Models.override_material(fitted, _mat)
	if reflected:
		for gi in Models.all_of(fitted, "GeometryInstance3D"):
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(fitted)
	# he never walks: an idle pose (T-poses look silly), played so slowly it is almost still
	var ap := Models.animation_player(model)
	var idle := Models.pick_animation(ap, "idle", "observer")
	if idle != "":
		ap.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
		ap.play(idle)
		ap.speed_scale = 0.15


func body_center(ground: Vector3) -> Vector3:
	return ground + Vector3.UP * 1.0 * _flip


func _is_seen_at(ground: Vector3) -> bool:
	return Observation.is_observed(body_center(ground), 0.6, [], 14.0)


func is_present() -> bool:
	return visible


func has_pending() -> bool:
	return _pending_move


func _process(delta: float) -> void:
	_t += delta
	var player = Game.player
	if player == null:
		return

	if _vanishing >= 0.0:
		# glitching out of existence
		_vanishing += delta
		_glitch = 1.0
		_body.scale = Vector3(1.0 + sin(_t * 90.0) * 0.08 * _vanishing, (1.0 + _vanishing * 0.6) * _flip, 1.0)
		_apply_glitch()
		if _vanishing > 0.3:
			hide_now()
			vanished.emit()
		return

	observed = visible and _is_seen_at(global_position)
	var dist: float = player.global_position.distance_to(global_position)

	# idle glitching, worse when watched; random spikes
	var target_glitch := 0.12
	if observed:
		target_glitch = 0.45
	if randf() < delta * 0.6:
		target_glitch = 0.9
	_glitch = lerpf(_glitch, target_glitch, clampf(delta * 8.0, 0.0, 1.0))
	_apply_glitch()
	_static.volume_db = -80.0 if not visible else linear_to_db(clampf((0.25 + _glitch) * (1.0 - dist / 30.0), 0.0001, 1.0)) - 8.0

	if observed:
		observed_time += delta
		unobserved_time = 0.0
		if not spotted and observed_time >= seen_threshold and dist <= seen_max_distance:
			spotted = true
			_vanish_after = observed_time + randf_range(1.0, 2.0)
			seen.emit()
		if spotted and observed_time >= _vanish_after:
			_vanishing = 0.0
		return  # he never moves while watched

	observed_time = maxf(0.0, observed_time - delta * 0.5)
	unobserved_time += delta
	# a spotted figure always goes, even if you looked away in time
	if spotted and unobserved_time > 0.8:
		_vanishing = 0.0
		return

	var to: Vector3 = player.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(to.x, to.z)

	_check += delta
	if _check < 0.2:
		return
	_check = 0.0
	if _pending_move and not _is_seen_at(_pending_pos):
		_pending_move = false
		global_position = _pending_pos
		visible = true


func _apply_glitch() -> void:
	_mat.set_shader_parameter("glitch", _glitch * clampf(Settings.visual_intensity, 0.3, 1.0))


func request_relocation(ground: Vector3) -> void:
	if spotted:
		return
	_pending_move = true
	_pending_pos = ground


func request_vanish() -> void:
	if visible:
		_vanishing = 0.0


func try_appear_at(ground: Vector3) -> bool:
	if _is_seen_at(ground) or (visible and observed):
		return false
	_pending_move = false
	_vanishing = -1.0
	if _body:
		_body.scale = Vector3(1, _flip, 1)
	global_position = ground
	if Game.player:
		var to: Vector3 = Game.player.global_position - ground
		rotation.y = atan2(to.x, to.z)
	visible = true
	observed_time = 0.0
	unobserved_time = 0.0
	spotted = false
	return true


func hide_now() -> void:
	visible = false
	observed = false
	observed_time = 0.0
	spotted = false
	_vanishing = -1.0
	if _body:
		_body.scale = Vector3(1, _flip, 1)
	if _static:
		_static.volume_db = -80.0
