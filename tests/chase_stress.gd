extends Node3D
## The Backrooms chase, generated for many maze seeds and both ways back into the yellow rooms (the maintenance
## door, the service passage): every route must reach the lift through open doorways, avoid the portals and the
## big props, and stay physically walkable (a player-sized capsule swept along it) once every wall has slammed
## and every hazard has dropped.
##   godot --headless --path . res://tests/chase_stress.tscn [-- <seeds>]
var failures: Array[String] = []

func _ready() -> void:
	Settings.deaths_seen = 1
	Game.boot(self)
	_run.call_deferred()

func _portal_cells(z: MazeZone) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = z.seed_value + 808
	var out := []
	for k in 2:
		out.append(Vector2i(rng.randi_range(2, MazeZone.W - 3), rng.randi_range(2, MazeZone.H - 3)))
		rng.randi_range(2, MazeZone.W - 3)
		rng.randi_range(2, MazeZone.H - 3)
	return out

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	var n := 40
	var args := Array(OS.get_cmdline_user_args()).filter(func(a): return not String(a).begins_with("--"))
	if args.size() > 0: n = int(args[0])
	var first := int(args[1]) if args.size() > 1 else 1
	var portal_hits := 0
	var lengths := []
	for seed in range(first, n + 1):
		for entry in ["door", "passage"]:
			Game.flags.clear()
			Game.counters.clear()
			Game.maze_seed = seed
			Game.enter_zone("maze")
			Game.set_mode("game")
			var z: MazeZone = Game.zone
			z._open_maint()
			z._open_escape()
			var at: Vector3 = z._wing_xf * Vector3(-2.0, 0.05, 0) if entry == "door" else z._wing_xf * Vector3(-2.0, 0.05, 6.5 * z._side)
			Game.player.teleport(Transform3D(Basis(), at))
			await get_tree().physics_frame
			var tag := "seed %d %s" % [seed, entry]
			if not z._in_grid(at):
				failures.append(tag + ": entry not in the grid " + str(at)); continue
			z._stalker.global_position = z._wing_xf * Vector3(14.0, 0, 0)
			z._begin_chase()
			var path: Array = z._chase_path
			if not z._chase_on or path.size() < 2 or path[-1] != Vector2i(0, 0):
				failures.append(tag + ": no route (%d cells)" % path.size()); continue
			lengths.append(path.size())
			for i in path.size() - 1:
				var d: Vector2i = path[i + 1] - path[i]
				if absi(d.x) + absi(d.y) != 1:
					failures.append(tag + ": route jumps at %d" % i)
			for c in path:
				if _portal_cells(z).has(c):
					portal_hits += 1
			# everything the chase will do to the maze, all at once
			for i in path.size():
				z._seal_around(i)
			for h in z._hazards:
				if not h.built:
					z._build_hazard(h, 0.0)
			await get_tree().create_timer(0.6).timeout
			for i in path.size() - 1:
				for c in [path[i], path[i + 1]]:
					if z._passable_route_check(path[i], path[i + 1]) == false:
						failures.append(tag + ": edge %s-%s sealed" % [path[i], path[i + 1]])
						break
			# sweep a capsule along the route (hazard rooms are swept along their own waypoints, at crouch/jump height)
			var space := get_world_3d().direct_space_state
			var cap := CapsuleShape3D.new()
			cap.radius = 0.32
			cap.height = 1.0
			var pts := []
			for w in z.chase_waypoints():
				pts.append(w)
			var blocked := 0
			for i in pts.size() - 1:
				var a: Vector3 = pts[i][0]
				var b: Vector3 = pts[i + 1][0]
				var y := 0.55
				if pts[i][1] == "crouch" or pts[i][1] == "jump":
					continue      # (under the fallen wall / over the hole: not a straight walk)
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.collision_mask = 1
				q.transform = Transform3D(Basis(), Vector3(a.x, y, a.z))
				q.motion = Vector3(b.x - a.x, 0, b.z - a.z)
				q.exclude = [Game.player.get_rid()]
				var res := space.cast_motion(q)
				if res.size() > 0 and res[0] < 0.999:
					var hq := PhysicsShapeQueryParameters3D.new()
					hq.shape = cap
					hq.collision_mask = 1
					hq.exclude = [Game.player.get_rid()]
					var pa := Vector3(a.x, y, a.z).lerp(Vector3(b.x, y, b.z), minf(res[1] + 0.02, 1.0))
					hq.transform = Transform3D(Basis(), pa)
					for hit in space.intersect_shape(hq, 4):
						var o: Object = hit.collider
						var desc := str(o)
						if o is CollisionObject3D:
							var sh = o.shape_owner_get_owner(o.shape_find_owner(hit.shape))
							desc = "%s / %s at %s" % [o.name, sh.name if sh else "?", (sh as Node3D).global_position.snapped(Vector3.ONE * 0.01) if sh is Node3D else "?"]
							if sh is CollisionShape3D and sh.shape is BoxShape3D:
								desc += " size %s rot %s" % [sh.shape.size, (sh as Node3D).global_rotation_degrees.snapped(Vector3.ONE)]
						print("      HIT ", desc)
					blocked += 1
					failures.append(tag + ": blocked between %s and %s (%.0f%%)" % [a.snapped(Vector3.ONE * 0.1), b.snapped(Vector3.ONE * 0.1), res[0] * 100.0])
			print("%s: %d rooms, %d false trails, %d hazards, %s" % [tag, path.size(), z._decoys.size(), z._hazards.size(), "ok" if blocked == 0 else "%d blocked" % blocked])
	print("route lengths: min %d max %d; routes crossing a portal room: %d (portals are off during the chase)" % [lengths.min(), lengths.max(), portal_hits])
	print("CHASE STRESS PASSED" if failures.is_empty() else "CHASE STRESS FAILED (%d): %s" % [failures.size(), failures.slice(0, 30)])
	get_tree().quit()
