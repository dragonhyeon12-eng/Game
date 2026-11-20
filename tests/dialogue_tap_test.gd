extends Node3D
## Answering a conversation by tapping (a phone): OPEN SPACE's phone call, every answer chosen with a
## real touch on its button - no number keys.   xvfb-run godot --path . --resolution 844x390 res://tests/dialogue_tap_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.pressed = pressed
		e.position = at
		Input.parse_input_event(e)        # goes through touch -> mouse emulation, like a phone
		await get_tree().process_frame
		await get_tree().process_frame


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	Game.enter_zone("openspace")
	Game.set_mode("game")
	await get_tree().create_timer(0.5).timeout
	check(Dialogue.start(null, "phone_mina"), "the phone call starts")
	await get_tree().create_timer(0.5).timeout
	var taps := 0
	var answered := 0
	while Dialogue.is_active() and taps < 30:
		var buttons := Game.hud._choices.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion())
		if buttons.is_empty():
			await get_tree().create_timer(0.2).timeout
			taps += 1
			continue
		var b: Button = buttons[buttons.size() - 1]     # the last answer each time
		var before: String = Game.hud._line.text
		var label := b.text
		var at: Vector2 = get_viewport().get_screen_transform() * b.get_global_transform_with_canvas() * (b.size * 0.5)
		await tap(at)
		await get_tree().create_timer(0.3).timeout
		taps += 1
		var moved := not Dialogue.is_active() or Game.hud._line.text != before
		check(moved, "tapped '%s' - the conversation moved on" % label)
		if not moved:
			break
		if not label.contains("Continue"):
			answered += 1
	check(answered > 0, "answered %d question(s) by tapping" % answered)
	check(not Dialogue.is_active(), "the call ended")
	print("DIALOGUE TAP TEST PASSED" if failures == 0 else "DIALOGUE TAP TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
