extends Node3D
## Progress stoppers: in every area, every interactable must be usable by a player who walks up to it - there must
## be floor to stand on nearby, room for the body (standing or crouched), and the player's interaction ray from
## the eyes must reach it before hitting anything else, within reach. (The story tests use interactables
## directly, so they can't notice one that's sunk in a wall or out of reach.)
##   godot --headless --path . res://tests/reach_test.tscn [-- zone ...]
var failures: Array[String] = []

func _ready() -> void:
	Settings.deaths_seen = 1
	Game.boot(self)
	_run.call_deferred()

func _all(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out

func _reaches(space: PhysicsDirectSpaceState3D, eye: Vector3, target: Interactable) -> bool:
	var to := target.global_position
	if eye.distance_to(to) > Player.INTERACT_RANGE - 0.05:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, eye + (to - eye).normalized() * Player.INTERACT_RANGE, 1 | 8)
	q.collide_with_areas = true
	q.exclude = [Game.player.get_rid()]
	var hit := space.intersect_ray(q)
	var n: Object = hit.get("collider")
	while n != null:
		if n == target:
			return true
		n = n.get_parent() if n is Node and not n is Zone else null
	return false

func _spot(space: PhysicsDirectSpaceState3D, it: Interactable) -> String:
	var p := it.global_position
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	for crouch in [false, true]:
		var h := 1.1 if crouch else 1.76
		var eye_h := 0.95 if crouch else Player.EYE_HEIGHT
		cap.height = h
		for r in [0.5, 0.8, 1.1, 1.4, 1.8]:
			for k in 24:
				var a := k * TAU / 24.0
				var xz := Vector3(p.x + cos(a) * r, 0, p.z + sin(a) * r)
				var down := PhysicsRayQueryParameters3D.create(Vector3(xz.x, p.y + 1.2, xz.z), Vector3(xz.x, p.y - 2.6, xz.z), 1)
				down.exclude = [Game.player.get_rid()]
				var g := space.intersect_ray(down)
				if g.is_empty() or (g.normal as Vector3).y < 0.7:
					continue
				var ground: Vector3 = g.position
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.collision_mask = 1
				q.exclude = [Game.player.get_rid()]
				q.transform = Transform3D(Basis(), ground + Vector3(0, h * 0.5 + 0.03, 0))
				if not space.intersect_shape(q, 1).is_empty():
					continue
				if _reaches(space, ground + Vector3(0, eye_h, 0), it):
					return "crouched" if crouch else "ok"
	return ""

func _can_stand_in(space: PhysicsDirectSpaceState3D, c: Vector3, size: Vector3) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.1
	for i in 7:
		for j in 7:
			var x := c.x + (i / 6.0 - 0.5) * size.x
			var z := c.z + (j / 6.0 - 0.5) * size.z
			var down := PhysicsRayQueryParameters3D.create(Vector3(x, c.y + size.y * 0.5, z), Vector3(x, c.y - size.y * 0.5 - 1.8, z), 1)
			down.exclude = [Game.player.get_rid()]
			var g := space.intersect_ray(down)
			if g.is_empty() or (g.normal as Vector3).y < 0.7:
				continue
			# the player's body has to overlap the trigger box: feet within reach of it
			if (g.position as Vector3).y > c.y + size.y * 0.5 or (g.position as Vector3).y + 1.76 < c.y - size.y * 0.5:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.collision_mask = 1
			q.exclude = [Game.player.get_rid()]
			q.transform = Transform3D(Basis(), (g.position as Vector3) + Vector3(0, 0.6, 0))
			if space.intersect_shape(q, 1).is_empty():
				return true
	return false


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	var zones: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return not String(a).begins_with("--"))
	if zones.is_empty():
		zones = Game.ZONES.duplicate()
	var total := 0
	for z in zones:
		Game.flags.clear()
		Game.enter_zone(z)
		Game.set_mode("game")
		Game.player.global_position = Vector3(0, -500, 0)    # (out of the way)
		for i in 3:
			await get_tree().physics_frame
		var space := get_world_3d().direct_space_state
		var n := 0
		var bad := []
		for c in _all(Game.zone):
			if not c is Interactable or not c.is_inside_tree():
				continue
			var prompt: String = c.prompt_fn.call() if "prompt_fn" in c and c.prompt_fn.is_valid() else ""
			n += 1
			if _spot(space, c) == "":
				bad.append("'%s' at %s" % [c.get_prompt(), c.global_position.snapped(Vector3.ONE * 0.1)])
		# story triggers: somewhere inside each one, a player has to be able to stand
		var nt := 0
		for c in _all(Game.zone):
			if not (c is Area3D) or c is Interactable or c.collision_mask != 2 or not c.is_inside_tree():
				continue
			var cs: CollisionShape3D = null
			for ch in c.get_children():
				if ch is CollisionShape3D and ch.shape is BoxShape3D:
					cs = ch
			if cs == null:
				continue
			nt += 1
			if not _can_stand_in(space, c.global_position, (cs.shape as BoxShape3D).size):
				bad.append("trigger at %s size %s" % [c.global_position.snapped(Vector3.ONE * 0.1), (cs.shape as BoxShape3D).size])
		total += n
		print("%-14s %3d interactables, %2d triggers, %d unreachable %s" % [z, n, nt, bad.size(), bad])
		for b in bad:
			failures.append(z + ": " + b)
	print("%d interactables checked" % total)
	print("REACH TEST PASSED" if failures.is_empty() else "REACH TEST FAILED (%d)" % failures.size())
	get_tree().quit()
