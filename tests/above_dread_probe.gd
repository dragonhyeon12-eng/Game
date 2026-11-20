extends Node3D
## ABOVE: frighten yourself on the plank (looking straight down the drop), then step back onto the roof
## and look level: DREAD should come back down within a few seconds, not stay up.
##   godot --headless --path . res://tests/above_dread_probe.tscn

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.hud.close_menu()
	Game.enter_zone("above")
	Game.set_mode("game")
	await get_tree().create_timer(1.0).timeout
	var pl: Player = Game.player
	var az: AboveZone = Game.zone
	az._faller_t = 9999.0
	az._gust_t = 9999.0
	pl.dread.set_values(20.0, 80.0)
	pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-12.5, 0.05, -3)))
	pl._pitch = deg_to_rad(-70)
	pl.head.rotation.x = pl._pitch
	await get_tree().create_timer(8.0).timeout
	var line := "on the plank, looking down 8 s: DREAD %.0f (fear %.0f, stability %.0f)" % [pl.dread.value(), pl.dread.fear, pl.dread.stability]
	pl.teleport(Transform3D(Basis(), Vector3(0, 0.05, 1.5)))
	pl._pitch = 0.0
	pl.head.rotation.x = 0.0
	for t in [5, 10, 20, 30]:
		await get_tree().create_timer(5.0 if t == 5 else (5.0 if t == 10 else 10.0)).timeout
		line += "\n  back on the roof %2d s: DREAD %.0f (fear %.0f, stability %.0f)" % [t, pl.dread.value(), pl.dread.fear, pl.dread.stability]
	print(line)
	get_tree().quit()
