class_name Observer
extends Node3D
## The black silhouette. No face, no detail, no collision, no interaction.
##
## Rules he never breaks:
##  - he never moves while observed: no walking, no turning, no relocating;
##  - when unobserved he may turn to face you again, or be somewhere else entirely.
## Zones decide WHERE he should be (request_relocation / try_appear_at); this decides WHEN.

signal seen

var seen_threshold := 0.6
var seen_max_distance := 90.0

var observed := false
var observed_time := 0.0
var unobserved_time := 0.0
var _seen_reported := false
var _pending_move := false
var _pending_vanish := false
var _pending_pos := Vector3.ZERO
var _check := 0.0


func _ready() -> void:
	var m := Shapes.void_material()
	# Slightly too tall, slightly too thin, arms slightly too long. Nothing you could point at.
	var parts := [
		["cylinder", Vector3(-0.09, 0.48, 0), Vector3(0.12, 0.96, 0.12), Vector3.ZERO],
		["cylinder", Vector3(0.09, 0.48, 0), Vector3(0.12, 0.96, 0.12), Vector3.ZERO],
		["cylinder", Vector3(0, 1.28, 0), Vector3(0.34, 0.68, 0.22), Vector3.ZERO],
		["sphere", Vector3(0, 1.6, 0), Vector3(0.36, 0.18, 0.24), Vector3.ZERO],
		["cylinder", Vector3(-0.22, 1.18, 0), Vector3(0.08, 0.82, 0.08), Vector3(0, 0, -3)],
		["cylinder", Vector3(0.22, 1.18, 0), Vector3(0.08, 0.82, 0.08), Vector3(0, 0, 3)],
		["cylinder", Vector3(0, 1.72, 0), Vector3(0.09, 0.1, 0.09), Vector3.ZERO],
		["sphere", Vector3(0, 1.88, 0), Vector3(0.18, 0.26, 0.2), Vector3.ZERO],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = Shapes.mesh(p[0])
		mi.material_override = m
		mi.position = p[1]
		mi.scale = p[2]
		mi.rotation_degrees = p[3]
		add_child(mi)


func body_center(ground: Vector3) -> Vector3:
	return ground + Vector3.UP * 0.95


func _is_seen_at(ground: Vector3) -> bool:
	return Observation.is_observed(body_center(ground), 0.6, [], 14.0)


func is_present() -> bool:
	return visible


func has_pending() -> bool:
	return _pending_move or _pending_vanish


func _process(delta: float) -> void:
	var player = Game.player
	if player == null:
		return
	observed = visible and _is_seen_at(global_position)
	if observed:
		observed_time += delta
		unobserved_time = 0.0
		if not _seen_reported and observed_time >= seen_threshold and player.global_position.distance_to(global_position) <= seen_max_distance:
			_seen_reported = true
			seen.emit()
		return  # never move while watched

	observed_time = 0.0
	unobserved_time += delta
	if unobserved_time > 1.5:
		_seen_reported = false

	var to: Vector3 = player.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(to.x, to.z)

	_check += delta
	if _check < 0.2:
		return
	_check = 0.0
	if _pending_vanish:
		_pending_vanish = false
		_pending_move = false
		hide_now()
	elif _pending_move and not _is_seen_at(_pending_pos):
		_pending_move = false
		global_position = _pending_pos
		visible = true


func request_relocation(ground: Vector3) -> void:
	_pending_move = true
	_pending_vanish = false
	_pending_pos = ground


func request_vanish() -> void:
	if visible:
		_pending_vanish = true
		_pending_move = false


func try_appear_at(ground: Vector3) -> bool:
	if _is_seen_at(ground) or (visible and observed):
		return false
	_pending_move = false
	_pending_vanish = false
	global_position = ground
	visible = true
	observed_time = 0.0
	_seen_reported = false
	return true


func hide_now() -> void:
	visible = false
	observed = false
	observed_time = 0.0
