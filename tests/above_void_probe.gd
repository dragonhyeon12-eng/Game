extends Node3D
## ABOVE: where does "over the drop" fire while you're standing on something? Samples every standable
## spot (a floor of any physics layer under a column of air) and runs the zone's own down-ray.
##   godot --headless --path . res://tests/above_void_probe.tscn

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.hud.close_menu()
	Game.enter_zone("above")
	Game.set_mode("game")
	await get_tree().create_timer(1.0).timeout
	var space := get_world_3d().direct_space_state
	var bad := {}
	var total := 0
	for x in range(-60, 140, 1):
		for z in range(-80, 80, 1):
			var from := Vector3(x + 0.5, 80.0, z + 0.5)
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 200.0, 0xFFFFFFFF)
			q.exclude = [Game.player.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			total += 1
			var feet: Vector3 = hit.position
			var q2 := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.2, feet + Vector3.DOWN * 6.0, 1)
			q2.exclude = [Game.player.get_rid()]
			if space.intersect_ray(q2).is_empty():
				var col: Object = hit.collider
				var key := "%s layer=%d" % [col.get_path() if col is Node else col, (col as CollisionObject3D).collision_layer if col is CollisionObject3D else -1]
				bad[key] = bad.get(key, []) + [Vector3i(x, roundi(feet.y), z)]
	print("standable samples: %d" % total)
	for k in bad:
		print("  over-the-drop while standing on %s: %d spots, e.g. %s" % [k, bad[k].size(), bad[k].slice(0, 3)])
	get_tree().quit()
