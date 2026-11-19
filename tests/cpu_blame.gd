extends Node3D
## Which node's per-frame work costs the most in an area: switch each one off in turn and measure.
##   godot --headless --path . res://tests/cpu_blame.tscn -- city

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _measure(frames := 40) -> float:
	var pr := 0.0
	for i in frames:
		await get_tree().process_frame
		pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return pr / frames


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var z: String = OS.get_cmdline_user_args()[0]
	Game.hud.close_menu()
	Game.enter_zone(z)
	Game.set_mode("game")
	await get_tree().create_timer(1.0).timeout
	var base := await _measure()
	print("baseline %.2f ms" % base)
	var cands: Array[Node] = []
	for n in get_tree().root.find_children("*", "", true, false):
		if n.is_processing() or n.is_physics_processing():
			cands.append(n)
	var rows := []
	for n in cands:
		if not is_instance_valid(n):
			continue
		var a := n.is_processing()
		var b := n.is_physics_processing()
		n.set_process(false)
		n.set_physics_process(false)
		var t := await _measure(12)
		if is_instance_valid(n):
			n.set_process(a)
			n.set_physics_process(b)
			rows.append([base - t, str(n.get_path()) + " (" + n.get_class() + ((" " + n.get_script().resource_path.get_file()) if n.get_script() else "") + ")"])
	rows.sort_custom(func(p, q): return p[0] > q[0])
	for r in rows.slice(0, 12):
		print("%8.2f  %s" % r)
	get_tree().quit()
