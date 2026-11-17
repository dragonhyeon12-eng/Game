extends Node3D
## The heaviest meshes in an area (triangles x instances).  godot --headless --path . res://tests/perf_top.tscn -- deep

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _tris(m: Mesh) -> int:
	var t := 0
	if m == null:
		return 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	for z in OS.get_cmdline_user_args():
		Game.hud.close_menu()
		Game.enter_zone(z)
		await get_tree().create_timer(0.5).timeout
		var rows := []
		for n in Game.zone.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n
			rows.append([_tris(mi.mesh), String(mi.get_path()).right(60), mi.cast_shadow != 0])
		for n in Game.zone.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = n.multimesh
			rows.append([_tris(mm.mesh) * mm.instance_count, "MULTI x%d %s" % [mm.instance_count, String(n.name)], n.cast_shadow != 0])
		rows.sort_custom(func(a, b): return a[0] > b[0])
		var total := 0
		for r in rows:
			total += r[0]
		print("== ", z, ": ", total / 1000, "k triangles in the scene")
		for r in rows.slice(0, 10):
			print("  %8dk  shadow=%s  %s" % [r[0] / 1000, r[2], r[1]])
	get_tree().quit()
