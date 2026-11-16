class_name Critter
extends Node3D
## An animated creature from an optional model file (models/creatures/*, models/sea/*): rats, spiders,
## sharks, whales... Nothing appears if the file isn't there, so every use is decoration on top of
## the game, never something the game depends on.
##
## Two behaviours:
##  - ORBIT: swims (or crawls) in a slow circle around a centre, bobbing - sea creatures.
##  - SCURRY: waits at one end of a line and runs to the other end when you come close - rats.

enum Mode { ORBIT, SCURRY, IDLE }

var mode := Mode.IDLE
# orbit
var center := Vector3.ZERO
var radius := 10.0
var speed := 2.0          # m/s along the path
var bob := 0.0
var _angle := 0.0
# scurry
var point_a := Vector3.ZERO
var point_b := Vector3.ZERO
var flee_distance := 4.0
var _at_a := true
var _moving := false

var _ap: AnimationPlayer
var _anim_move := ""
var _anim_idle := ""
var _t := 0.0


## A creature from the first slot that has a model ("creatures/rat", ...), `size` metres along its
## largest side. `dark` turns it into a silhouette (things far off in deep water). Null if no model.
static func create(slots: Array, size: float, dark := false) -> Critter:
	var model := Models.instance(slots)
	if model == null:
		return null
	var c := Critter.new()
	var fitted := Models.fit(model, size, true)
	c.add_child(fitted)
	if dark:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.015, 0.025, 0.035)
		m.roughness = 1.0
		Models.override_material(fitted, m)
	c._ap = Models.animation_player(model)
	var slot: String = model.get_meta("slot")
	c._anim_move = Models.pick_animation(c._ap, "run", slot)
	if c._anim_move == "":
		c._anim_move = Models.pick_animation(c._ap, "walk", slot)
	if c._anim_move == "":
		c._anim_move = Models.pick_animation(c._ap, "swim", slot)
	c._anim_idle = Models.pick_animation(c._ap, "idle", slot)
	if c._anim_idle == "":
		c._anim_idle = c._anim_move
	for a in [c._anim_move, c._anim_idle]:
		if a != "":
			c._ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	for gi in Models.all_of(fitted, "GeometryInstance3D"):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if dark else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return c


func orbit(c: Vector3, r: float, spd: float, bob_height := 0.0, start := -1.0) -> Critter:
	mode = Mode.ORBIT
	center = c
	radius = r
	speed = spd
	bob = bob_height
	_angle = randf() * TAU if start < 0.0 else start
	_play(_anim_move)
	_place_orbit(0.0)
	return self


func scurry(a: Vector3, b: Vector3, spd := 3.0, flee := 4.0) -> Critter:
	mode = Mode.SCURRY
	point_a = a
	point_b = b
	speed = spd
	flee_distance = flee
	position = a
	_face(b - a)
	_play(_anim_idle)
	return self


func idle_at(pos: Vector3, yaw_deg := 0.0) -> Critter:
	mode = Mode.IDLE
	position = pos
	rotation_degrees.y = yaw_deg
	_play(_anim_idle)
	return self


func _play(anim: String) -> void:
	if _ap and anim != "" and _ap.current_animation != anim:
		_ap.play(anim, 0.2)


func _face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.001:
		rotation.y = atan2(dir.x, dir.z)


func _place_orbit(delta: float) -> void:
	_angle += speed / maxf(radius, 0.1) * delta
	var p := center + Vector3(cos(_angle), 0, sin(_angle)) * radius + Vector3(0, sin(_t * 0.4) * bob, 0)
	# tangent: the way it's swimming
	_face(Vector3(-sin(_angle), 0, cos(_angle)) * signf(speed))
	position = p


func _process(delta: float) -> void:
	_t += delta
	match mode:
		Mode.ORBIT:
			_place_orbit(delta)
		Mode.SCURRY:
			var target := point_b if _at_a else point_a
			if _moving:
				var to := target - position
				var step := speed * delta
				if to.length() <= step:
					position = target
					_at_a = not _at_a
					_moving = false
					_play(_anim_idle)
				else:
					position += to.normalized() * step
					_face(to)
			elif Game.player and Game.player.global_position.distance_to(global_position) < flee_distance:
				_moving = true
				_play(_anim_move)
				Sfx.play_at("knock", get_parent(), global_position, -22.0, 8.0)
