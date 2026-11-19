extends Node3D
## Script + physics cost per area, without rendering: average ms per frame of _process and
## _physics_process work (the part a slow phone CPU pays for), standing at the start.
##   godot --headless --path . res://tests/cpu_probe.tscn

const ZONES := ["city", "maze", "deep", "seabed", "abyss", "compression", "tenement", "above",
	"blackout", "stilllife", "openspace", "pattern", "quiet"]


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	print("zone           process ms  physics ms   nodes")
	for z in ZONES:
		Game.hud.close_menu()
		Game.enter_zone(z)
		Game.set_mode("game")
		await get_tree().create_timer(5.0).timeout     # (past the first seconds of loading work)
		var pr := 0.0
		var ph := 0.0
		for i in 240:
			await get_tree().process_frame
			pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		print("%-14s %10.2f %11.2f %7d" % [z, pr / 240, ph / 240, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit()
