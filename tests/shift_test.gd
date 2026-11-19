extends Node3D
## THE SHIFT (prototype): the rules of the shifting rooms.
##  - nothing dissipates, rebuilds or moves while it can be seen (checked independently, every frame);
##  - every room can always be reached; you never end up inside a wall or under the floor;
##  - it really does change (stages, rebuilds, walls) - and you can still walk to the EXIT.
##   godot --headless --path . res://tests/shift_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _snapshot(z: ShiftZone) -> Dictionary:
	var segs := {}
	for r in ShiftZone.N:
		for c in ShiftZone.N:
			var s: Dictionary = z.segment(c, r)
			segs[Vector2i(c, r)] = [s.gen, s.stage, z.seg_visible(s), s.root]
	var edges := {}
	for k in z._edges:
		var mid := ShiftZone.edge_mid(k)
		var ex := z._edge_bodies(k)
		var vis := Observation.is_observed(mid + Vector3(0, 1.5, 0), 2.2, ex) or Observation.is_observed(mid + Vector3(0, 0.5, 0), 2.2, ex)
		edges[k] = [z.edge_state(k), vis]
	return {"segs": segs, "edges": edges}


func _compare(z: ShiftZone, before: Dictionary) -> int:
	var bad := 0
	for k in before.segs:
		var s: Dictionary = z.segment(k.x, k.y)
		var b: Array = before.segs[k]
		if b[2] and (s.gen != b[0] or s.stage != b[1]):
			bad += 1
			print("    seen room %s changed (gen %d->%d, stage %d->%d)" % [k, b[0], s.gen, b[1], s.stage])
	for k in before.edges:
		var b: Array = before.edges[k]
		if b[1] and z.edge_state(k) != b[0]:
			bad += 1
			print("    seen wall %s changed" % k)
	return bad


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.start_prototype()
	await get_tree().create_timer(1.0).timeout
	var z: ShiftZone = Game.zone
	var pl: Player = Game.player
	check(Game.zone_type == "shifting" and Game.mode == "game", "the prototype starts from the title")
	check(z.all_connected(), "every room can be reached at the start")

	print("== looking around for a while: nothing seen may change")
	z.speed = 8.0
	var bad := 0
	var disconnected := 0
	var t := 0.0
	while t < 40.0:
		pl.rotation.y += deg_to_rad(35.0) * get_process_delta_time()
		var snap := _snapshot(z)
		await get_tree().process_frame
		t += get_process_delta_time()
		bad += _compare(z, snap)
		if not z.all_connected():
			disconnected += 1
	check(bad == 0, "nothing changed while it was in view (%d violations)" % bad)
	check(disconnected == 0, "every room stayed reachable (%d frames not)" % disconnected)
	check(z.stats.stages > 10, "rooms dissipated out of sight (%d stage changes)" % z.stats.stages)
	check(z.stats.rebuilds > 3, "rooms rebuilt themselves (%d)" % z.stats.rebuilds)
	check(z.stats.edge_changes > 3, "walls and doorways moved (%d)" % z.stats.edge_changes)
	check(pl.global_position.y > -0.3, "still standing on the floor (y=%.2f)" % pl.global_position.y)

	print("== walking to the exit while it all shifts")
	z.speed = 3.0
	var reached := await _walk_to_exit(z, 150.0)
	check(reached, "walked to the EXIT room (%s, exit %s; rebuilt %d, walls %d, exit moved %d)" % [z.seg_at(pl.global_position), z.exit_segment(), z.stats.rebuilds, z.stats.edge_changes, z.stats.exit_moves])
	if reached:
		var it: Interactable = null
		for c in z.find_children("*", "Interactable", true, false):
			if c.get_prompt() == "Open the EXIT":
				it = c
		check(it != null, "the EXIT door can be used")
		if it:
			it.interact()
			await get_tree().create_timer(0.5).timeout
			check(Game.has_flag("shift_exit"), "out through the EXIT")
	print("SHIFT TEST PASSED" if failures == 0 else "SHIFT TEST FAILED (%d)" % failures)
	get_tree().quit(failures)


## Room to room by the open edges (re-planned every step: the walls move while you walk).
func _walk_to_exit(z: ShiftZone, timeout: float) -> bool:
	var pl: Player = Game.player
	var t := 0.0
	var stuck_t := 0.0
	var last := pl.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	while t < timeout:
		var here := z.seg_at(pl.global_position)
		var goal := z.exit_segment()
		var target: Vector3
		if here == goal:
			target = ShiftZone.center(goal.x, goal.y)
			var d := Vector2(pl.global_position.x - target.x, pl.global_position.z - target.z).length()
			if d < 1.5:
				Input.action_release("move_forward")
				Input.action_release("sprint")
				return true
		else:
			var path := _path(z, here, goal)
			if path.size() < 2:
				target = ShiftZone.center(here.x, here.y)
			else:
				# head for the doorway, lined up with it, then through
				var nxt: Vector2i = path[1]
				var mid := ShiftZone.edge_mid(ShiftZone._edge_key(here, nxt))
				var c := ShiftZone.center(here.x, here.y)
				var dirv := (ShiftZone.center(nxt.x, nxt.y) - c).normalized()
				var off := pl.global_position - mid
				var lateral := off - dirv * off.dot(dirv)
				target = mid + dirv * 1.5 if lateral.length() < 0.35 else mid - dirv * 1.2
		var to := target - pl.global_position
		to.y = 0.0
		pl.rotation.y = atan2(-to.x, -to.z)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		stuck_t += get_physics_process_delta_time()
		if stuck_t > 3.0:
			if pl.global_position.distance_to(last) < 0.5:
				print("    stuck at %s (room %s)" % [pl.global_position, z.seg_at(pl.global_position)])
			stuck_t = 0.0
			last = pl.global_position
	Input.action_release("move_forward")
	Input.action_release("sprint")
	return false


func _path(z: ShiftZone, a: Vector2i, b: Vector2i) -> Array:
	var prev := {a: a}
	var q: Array[Vector2i] = [a]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == b:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.y < 0 or nb.x >= ShiftZone.N or nb.y >= ShiftZone.N or prev.has(nb):
				continue
			if z.edge_state(ShiftZone._edge_key(cur, nb)) != ShiftZone.WALL_SOLID:
				prev[nb] = cur
				q.append(nb)
	if not prev.has(b):
		return []
	var out := [b]
	while out[0] != a:
		out.push_front(prev[out[0]])
	return out
