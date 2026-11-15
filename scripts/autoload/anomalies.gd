extends Node
## Reusable "something here may change while nobody is looking" events.
##
## Zones register anomalies (position, conditions, apply callable). This decides *when* any of them
## changes, based on dream stability. When the player later sees a changed anomaly, it counts as a
## discovered inconsistency (fear). No zone needs its own giant anomaly script.

const CHECK_INTERVAL := 0.25
const DISCOVERY_DISTANCE := 25.0

var _list: Array[Dictionary] = []
var _acc := 0.0
var _next_change := 0.0
var _stable_pacing := -1.0
var _unstable_pacing := 6.0
var total_changes := 0


## Register an anomaly. Keys:
##   id, position (Vector3) or get_position (Callable), radius (m), apply (Callable),
##   can_apply (Callable, optional), min_stage (int), min_unobserved (s), weight,
##   max_changes (-1 = unlimited), max_distance (m), discovery_fear, owner (Node)
func register(a: Dictionary) -> void:
	var d := {
		"id": "anomaly", "position": Vector3.ZERO, "radius": 1.5, "min_stage": 0, "min_unobserved": 2.0,
		"weight": 1.0, "max_changes": -1, "max_distance": 40.0, "discovery_fear": 3.0,
		"unobserved_for": 0.0, "awaiting": false, "changes": 0,
	}
	d.merge(a, true)
	_list.append(d)


func unregister_owner(owner: Node) -> void:
	_list = _list.filter(func(a): return is_instance_valid(a.get("owner")) and a.get("owner") != owner)


func clear() -> void:
	_list.clear()
	total_changes = 0
	_stable_pacing = -1.0


## Seconds between changes at full stability / at zero stability. Negative = never.
func set_pacing(stable: float, unstable: float) -> void:
	_stable_pacing = stable
	_unstable_pacing = unstable
	_next_change = _now() + maxf(8.0, stable * 0.5)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _schedule(stability: float) -> void:
	if _stable_pacing < 0.0:
		_next_change = INF
		return
	var inst := 1.0 - clampf(stability / 100.0, 0.0, 1.0)
	_next_change = _now() + lerpf(_stable_pacing, _unstable_pacing, inst * inst) * randf_range(0.7, 1.3)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < CHECK_INTERVAL or _list.is_empty():
		return
	var dt := _acc
	_acc = 0.0
	var player = Game.player
	if player == null or player.controls_locked:
		return
	var dread = player.dread
	var ppos: Vector3 = player.global_position

	for a in _list:
		if a.has("get_position"):
			a.position = a.get_position.call()
		var seen := Observation.is_observed(a.position, a.radius)
		if seen:
			a.unobserved_for = 0.0
			if a.awaiting and ppos.distance_to(a.position) < DISCOVERY_DISTANCE:
				a.awaiting = false
				dread.add_fear(a.discovery_fear, "anomaly discovered")
				dread.notify_suspicious()
		else:
			a.unobserved_for += dt

	if _now() < _next_change:
		return
	var stage: int = dread.stage
	var candidates := []
	var total := 0.0
	for a in _list:
		if stage < a.min_stage: continue
		if a.max_changes >= 0 and a.changes >= a.max_changes: continue
		if a.unobserved_for < a.min_unobserved: continue
		var dist := ppos.distance_to(a.position)
		if dist > a.max_distance or dist < a.radius + 1.2: continue
		if a.has("can_apply") and not a.can_apply.call(): continue
		candidates.append(a)
		total += a.weight
	if candidates.size() > 0:
		var pick := randf() * total
		for a in candidates:
			pick -= a.weight
			if pick <= 0.0:
				a.apply.call()
				a.changes += 1
				total_changes += 1
				a.awaiting = a.discovery_fear > 0.0
				break
	_schedule(dread.stability)
