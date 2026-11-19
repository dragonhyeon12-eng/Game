extends Node3D
## Where an area's triangles come from: every mesh (and multimesh) by triangles x instances.
##   godot --headless --path . res://tests/tri_census.tscn -- city

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--low"):
		Settings.quality = 0.0
	Game.boot(self)
	_run.call_deferred()


func _tris(m: Mesh) -> int:
	if m == null:
		return 0
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var args := OS.get_cmdline_user_args()
	Game.enter_zone(args[0] if args.size() > 0 else "city")
	await get_tree().create_timer(0.5).timeout
	var rows := []
	var byname := {}
	for n in Game.zone.find_children("*", "GeometryInstance3D", true, false):
		var t := 0
		var count := 1
		var mesh: Mesh = null
		if n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
			count = n.multimesh.instance_count
		elif n is MeshInstance3D:
			mesh = n.mesh
		t = _tris(mesh)
		if args.has("--visible"):
			# only what the start camera would draw: in view, and inside its visibility range
			var cam := get_viewport().get_camera_3d()
			var gi := n as GeometryInstance3D
			if not gi.is_visible_in_tree():
				continue
			var lim := gi.visibility_range_end if gi.visibility_range_end > 0.0 else INF
			if n is MultiMeshInstance3D and n.multimesh:
				var c := 0
				for i in n.multimesh.instance_count:
					var wp: Vector3 = n.global_transform * n.multimesh.get_instance_transform(i).origin
					if cam.is_position_in_frustum(wp) and cam.global_position.distance_to(wp) < lim:
						c += 1
				count = c
			else:
				var wp2: Vector3 = gi.global_transform * gi.get_aabb().get_center()
				if not cam.is_position_in_frustum(wp2) or cam.global_position.distance_to(wp2) > lim:
					continue
		rows.append([t * count, t, count, str(n.get_parent().name) + "/" + str(n.name) + " " + (mesh.resource_path.get_file() if mesh and mesh.resource_path != "" else (mesh.get_class() if mesh else "?"))])
	for r in rows:
		var nm: String = String(r[3]).get_slice(" ", 1)
		byname[nm] = byname.get(nm, [0, 0])
		byname[nm][0] += r[0]
		byname[nm][1] += 1
	var bn := byname.keys()
	bn.sort_custom(func(a, b): return byname[a][0] > byname[b][0])
	print("by mesh:")
	for k in bn.slice(0, 12):
		print("  %9d tris  %5d nodes  %s" % [byname[k][0], byname[k][1], k])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	for r in rows:
		total += r[0]
	print("TOTAL %d tris in %d geometry nodes" % [total, rows.size()])
	for r in rows.slice(0, 12):
		print("%9d = %6d x %5d  %s" % r)
	get_tree().quit()
