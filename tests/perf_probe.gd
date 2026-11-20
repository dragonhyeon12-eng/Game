extends Node3D
## Rendering cost of every area, from where the player starts: draw calls, objects, triangles, lights,
## shadow-casting lights, nodes and CPU frame time. Needs a display (e.g. xvfb-run).
##   godot --path . res://tests/perf_probe.tscn

const ZONES := ["bedroom", "bedroom_dream", "city", "maze", "deep", "seabed", "abyss", "compression", "tenement", "above",
	"blackout", "stilllife", "openspace", "pattern", "quiet"]


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--low"):
		Settings.quality = 0.0
		Settings.render_scale = 0.65
		Settings.apply()
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	print("zone            draws  objects   tris(k)  omni  spot  shadowed  nodes   cpu ms")
	var only := Array(OS.get_cmdline_user_args()).filter(func(a): return not String(a).begins_with("--"))
	for z in (only if not only.is_empty() else ZONES):
		Game.hud.close_menu()
		Game.enter_zone(z)
		Game.set_mode("game")
		Game.hud.set_fade(0.0)
		await get_tree().create_timer(2.0).timeout
		var draws := 0.0
		var objs := 0.0
		var tris := 0.0
		var cpu := 0.0
		for i in 30:
			await RenderingServer.frame_post_draw
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			tris += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var shots := OS.get_cmdline_user_args().find("--shots")
		if shots >= 0:
			get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[shots + 1] + "/" + z + ".png")
		var omni := Game.zone.find_children("*", "OmniLight3D", true, false)
		var spots := Game.zone.find_children("*", "SpotLight3D", true, false)
		var shadowed := 0
		for l in omni + spots:
			if l.shadow_enabled:
				shadowed += 1
		print("%-14s %6d %8d %9.0f %5d %5d %9d %6d %8.2f" % [z, draws / 30, objs / 30, tris / 30 / 1000.0, omni.size(), spots.size(),
			shadowed, Game.zone.find_children("*", "", true, false).size(), cpu / 30])
	get_tree().quit()
