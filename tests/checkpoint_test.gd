extends Node3D
## Every mid-level checkpoint: reach it (its flags set, the checkpoint taken), die, come back - and you're
## where it said, standing on something, the world the way you left it, and still alive 10 s later.
##   godot --headless --path . res://tests/checkpoint_test.tscn

var ZONES := {"abyss": AbyssZone.CHECKPOINTS, "above": AboveZone.CHECKPOINTS, "compression": CompressionZone.CHECKPOINTS,
	"tenement": TenementZone.CHECKPOINTS, "blackout": BlackoutZone.CHECKPOINTS}
var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	for z in ZONES:
		var table: Dictionary = ZONES[z]
		for id in table:
			var cp: Array = table[id]
			print("== %s: %s" % [z, id])
			Game._cancel_sequences()
			await get_tree().create_timer(0.5).timeout
			Game.hud.close_menu()
			Game._reset_world()
			Game.enter_zone(z)
			Game.set_mode("game")
			await get_tree().create_timer(0.3).timeout
			for f in cp[2]:
				Game.set_flag(f)
			if z == "tenement":
				Game.counters["floor"] = 7 if id != "stairs" else 4
			Game.zone.checkpoint_at(id)
			check(Game.zone.checkpoint_id() == id, "checkpoint taken")
			# die
			Game.entity_death("fall")
			await get_tree().create_timer(0.5).timeout
			Game.skip_death()
			var w := 0.0
			while (Game.mode != "game" or Game.in_sequence) and w < 25.0:
				await get_tree().create_timer(0.25).timeout
				w += 0.25
			await get_tree().create_timer(1.0).timeout
			var pl: Player = Game.player
			var spawn: Vector3 = cp[0]
			check(Game.zone_type == z and Game.mode == "game" and not Game.in_sequence, "back in %s, playing" % z)
			check(pl.global_position.distance_to(spawn) < 1.0, "at the checkpoint (%s, wanted %s)" % [pl.global_position.snapped(Vector3.ONE * 0.01), spawn])
			check(pl.is_on_floor(), "standing on something")
			for f in cp[2]:
				if not Game.has_flag(f):
					check(false, "flag %s kept" % f)
			_world_checks(z, id)
			# still alive, still there, 10 s on (the dark, the drop, whatever's about)
			await get_tree().create_timer(10.0).timeout
			var drift := 4.0 if z == "above" else 2.0      # (ABOVE's wind shoves you about)
			check(Game.zone_type == z and Game.mode == "game" and not Game.in_sequence and pl.global_position.distance_to(spawn) < drift,
				"still alive and on the spot 10 s later (%s)" % pl.global_position.snapped(Vector3.ONE * 0.01))
			# and the way on is open: a couple of steps forward don't drop you (except floor 7: a step on and
			# the building starts coming down - that's the point of it)
			if id == "floor7":
				continue
			Input.action_press("move_forward")
			await get_tree().create_timer(1.0).timeout
			Input.action_release("move_forward")
			await get_tree().create_timer(0.6).timeout
			check(pl.global_position.y > spawn.y - 1.0 and Game.mode == "game", "a few steps on, still on solid ground (y %.2f)" % pl.global_position.y)
	print("CHECKPOINT TEST PASSED" if failures == 0 else "CHECKPOINT TEST FAILED (%d)" % failures)
	get_tree().quit(failures)


func _world_checks(z: String, id: String) -> void:
	var zone = Game.zone
	match z:
		"abyss":
			check(zone._bulkhead.position.y > 3.0, "the bulkhead is still open")
			if id != "bulkhead":
				check(zone._room1_open.is_empty(), "the door through the rooms is still open")
			if id == "bridge" or id == "station":
				check(zone._bridge_parts.size() > 0 and zone._bridge_parts[-1].visible, "the bridge of light is still there")
		"above":
			check(zone._beam_gone, "the beam's gone (no way back)")
		"tenement":
			check(not is_instance_valid(zone._grille_block), "the vent cover is still off")
			if id != "stairs":
				check(zone._floor_num == 7 and not is_instance_valid(zone._exit_block), "floor 7, its door open")
		"blackout":
			check(zone._living_light.on, "number 9's lamp is still on")
			if id == "garden":
				check(zone._back_block == null, "the back door is still unlocked")
