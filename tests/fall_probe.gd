extends Node3D
## Where can you fall? For each zone: flood-fill every spot you can walk to from the start (0.5 m grid,
## stepping up at most 0.4 m, never through anything solid at knee or chest height), and report each place
## where the next step has no floor under it for 3 m or more. Run headless:
##   godot --headless --path . res://tests/fall_probe.tscn -- [zone ...]

const ZONES := ["bedroom", "city", "remember", "maze", "deep", "seabed", "abyss", "compression", "tenement", "above",
	"blackout", "stilllife", "openspace", "pattern", "quiet"]
const STEP := 0.5
const MAX_CELLS := 90000


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var only := Array(OS.get_cmdline_user_args()).filter(func(a): return not String(a).begins_with("--"))
	for z in (only if not only.is_empty() else ZONES):
		Game.hud.close_menu()
		Game.enter_zone(z)
		Game.set_mode("game")
		await get_tree().create_timer(1.0).timeout
		await get_tree().physics_frame
		_probe(z)
	get_tree().quit()


func _floor(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p + Vector3(0, -40.0, 0), 1)
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -INF


func _blocked(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var past := b + (b - a).normalized() * 0.3      # (a body is round: it can't get its middle right up to a wall)
	for h in [0.55, 1.3]:
		var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, h, 0), past + Vector3(0, h, 0), 1)
		if not space.intersect_ray(q).is_empty():
			return true
	return false


func _probe(zone: String) -> void:
	var space := get_world_3d().direct_space_state
	var start: Vector3 = Game.player.global_position
	var y0 := _floor(space, start)
	if y0 == -INF:
		print("%-12s  NO FLOOR UNDER THE START %s" % [zone, start])
		return
	var origin := Vector3(snappedf(start.x, STEP) + 0.23, 0, snappedf(start.z, STEP) + 0.27)    # (off the grid: not on the edges of things)
	var seen := {Vector2i(0, 0): y0}
	var parent := {}
	var queue := [Vector2i(0, 0)]
	var head := 0
	var falls := {}
	while head < queue.size() and seen.size() < MAX_CELLS:
		var c: Vector2i = queue[head]
		head += 1
		var y: float = seen[c]
		var here := origin + Vector3(c.x * STEP, y, c.y * STEP)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			var there := origin + Vector3(n.x * STEP, y, n.y * STEP)
			if _blocked(space, here, there):
				continue
			var ny := _floor(space, there)
			if ny - y > 0.4:
				continue          # a step too high (or a wall the rays missed)
			if ny == -INF or y - ny > 3.0:
				var k := Vector2i(floori(there.x / 4.0), floori(there.z / 4.0))
				if not falls.has(k):
					falls[k] = [there, y - ny if ny != -INF else INF, c]
				continue
			seen[n] = ny
			parent[n] = c
			queue.append(n)
	print("%-12s  %6d cells reachable%s, %d places you can fall" % [zone, seen.size(), " (capped)" if seen.size() >= MAX_CELLS else "", falls.size()])
	var list := falls.values()
	list.sort_custom(func(a, b): return a[0].z > b[0].z)
	if OS.get_cmdline_user_args().has("--path") and not list.is_empty():
		# the way to the first one: where did it get out?
		var c: Vector2i = list[0][2]
		var trail := []
		while parent.has(c):
			trail.push_front(origin + Vector3(c.x * STEP, 0, c.y * STEP))
			c = parent[c]
		var prev := Vector3.INF
		for i in trail.size():
			if i % 6 == 0 or i > trail.size() - 30:
				print("      via (%.1f, %.1f)" % [trail[i].x, trail[i].z])
	for i in mini(list.size(), 40):
		var f: Vector3 = list[i][0]
		print("    fall at (%.1f, %.1f, %.1f)  drop %s" % [f.x, f.y, f.z, "bottomless" if list[i][1] == INF else "%.1f m" % list[i][1]])
