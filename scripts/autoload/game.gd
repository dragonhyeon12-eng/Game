extends Node
## Story flow for the vertical slice:
##
##   Title (over the bedroom) -> Bedroom: watch the tutorial, take the notebook, sleep
##   -> Summer city: manifest, talk, notice (or not) the Observer, hold T to wake
##   -> fall through the floor -> Yellow maze: find the exit -> end of slice
##   DREAD 100 in a nightmare -> "You woke up." / "Didn't you?" -> last checkpoint
##
## Holds story flags, builds and frees zones, writes checkpoints, runs scripted sequences, owns the
## input mode (game / dialogue / overlay / menu / cinematic) and the DREAD presentation ("director").

const SAVE_PATH := "user://checkpoint.json"

var main: Node3D
var player: Player
var hud: HUD
var zone: Zone
var zone_type := ""
var flags := {}
var maze_seed := 1
var mode := "menu"
var in_sequence := false

var _seq := 0                    # bumping this cancels running sequences
var _mode_before_menu := "game"
var _smoothed_dread := 0.0
var _next_distant := 40.0
var _clock := 0.0
# session-only pause-menu horror bookkeeping (kept rare on purpose)
var corrupted_menus_shown := 0
var _last_corrupted := -1000.0
var self_unpause_used := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func boot(main_node: Node3D) -> void:
	main = main_node
	player = Player.new()
	player.name = "Player"
	main.add_child(player)
	player.dread.overwhelmed.connect(_on_overwhelmed)
	hud = HUD.new()
	main.add_child(hud)
	show_title()


# ------------------------------------------------------------------ flags

func has_flag(f: String) -> bool:
	return flags.has(f)


func set_flag(f: String) -> void:
	flags[f] = true


func clear_flag(f: String) -> void:
	flags.erase(f)


# ------------------------------------------------------------------ input modes

func set_mode(m: String) -> void:
	mode = m
	player.set_locked(m != "game")
	match m:
		"game", "cinematic":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		"dialogue", "menu":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"overlay":
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	hud.set_gameplay_visible(m == "game" or m == "dialogue")


func enter_dialogue_mode() -> void:
	set_mode("dialogue")


func exit_dialogue_mode() -> void:
	if mode == "dialogue":
		set_mode("game")


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("pause"):
		if mode in ["game", "dialogue", "cinematic"]:
			open_pause()
			get_viewport().set_input_as_handled()
	elif mode == "game" and event.is_action_pressed("notebook"):
		open_notebook()
		get_viewport().set_input_as_handled()
	elif mode == "dialogue":
		for i in 5:
			if event.is_action_pressed("choice_%d" % (i + 1)):
				Dialogue.choose(i)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
			Dialogue.advance()
			get_viewport().set_input_as_handled()
	elif mode == "game" and event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # re-capture after the window lost focus


# ------------------------------------------------------------------ sequences

## Wait inside a sequence. Returns false if the sequence was cancelled meanwhile.
func _wait(seconds: float, token: int) -> bool:
	await get_tree().create_timer(seconds, false).timeout
	return token == _seq


func _cancel_sequences() -> void:
	_seq += 1
	in_sequence = false


# ------------------------------------------------------------------ zones

func enter_zone(type: String, from_save := false, waking := false) -> void:
	player.manifestation.clear_all()
	if Dialogue.is_active():
		Dialogue.end()
	if zone:
		zone.queue_free()
		main.remove_child(zone)
		zone = null
	match type:
		"bedroom":
			var b := BedroomZone.new()
			b.waking = waking
			zone = b
		"city":
			zone = CityZone.new()
		"maze":
			var m := MazeZone.new()
			m.seed_value = maze_seed
			zone = m
		_:
			zone_type = ""
			return
	zone_type = type
	zone.name = "Zone_" + type
	main.add_child(zone)
	zone.build()
	zone.finish_batches()
	player.teleport(zone.player_start())
	player.dread.set_profile(zone.is_nightmare(), zone.fear_gain(), zone.fear_floor(), zone.fear_decay())
	player.set_movement(zone.walk_speed(), zone.sprint_speed(), zone.soft_floor())
	var pacing := zone.anomaly_pacing()
	if pacing.x >= 0.0:
		Anomalies.set_pacing(pacing.x, pacing.y)
	zone.on_player_entered(from_save)
	print("Entered zone: ", type, " (waking)" if waking else "")


func _leave_zone() -> void:
	if zone:
		zone.queue_free()
		main.remove_child(zone)
		zone = null
	zone_type = ""


# ------------------------------------------------------------------ state

func _reset_world() -> void:
	_cancel_sequences()
	flags.clear()
	Notebook.reset()
	if Dialogue.is_active():
		Dialogue.end()
	Anomalies.clear()
	_smoothed_dread = 0.0
	_next_distant = _clock + 40.0
	player.reset_presentation()
	player.dread.set_values(0.0, 100.0)
	player.manifestation.reset_unlocks()
	hud.clear_text()
	hud.close_overlay()
	hud.hide_card(0.0)
	get_tree().paused = false


func has_checkpoint() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_checkpoint() -> void:
	var data := {
		"version": 1, "zone": zone_type, "flags": flags.keys(), "seed": maze_seed,
		"notebook": Notebook.get_state(), "fear": player.dread.fear, "stability": player.dread.stability,
		"unlocked": player.manifestation.unlocked,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		print("Checkpoint saved (", zone_type, ")")


func _restore_checkpoint(fear_override := -1.0, stability_override := -1.0) -> bool:
	if not has_checkpoint():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or data.get("zone", "") == "":
		return false
	_reset_world()
	for f in data.get("flags", []):
		flags[f] = true
	maze_seed = int(data.get("seed", 1))
	Notebook.load_state(data.get("notebook", {}))
	enter_zone(data.zone, true)
	player.manifestation.unlocked = data.get("unlocked", Data.manifest_start.duplicate())
	player.dread.set_values(fear_override if fear_override >= 0.0 else float(data.get("fear", 0.0)),
		stability_override if stability_override >= 0.0 else float(data.get("stability", 100.0)))
	return true


# ------------------------------------------------------------------ flow

func show_title() -> void:
	_reset_world()
	enter_zone("bedroom")
	hud.set_fade(1.0)
	hud.fade_to(0.0, 2.0)
	set_mode("menu")
	hud.open_title(has_checkpoint())


func start_new_game() -> void:
	hud.close_menu()
	Data.reload()
	_reset_world()
	maze_seed = randi_range(1, 1 << 30)
	enter_zone("bedroom")
	save_checkpoint()
	set_mode("game")
	hud.set_fade(1.0)
	hud.fade_to(0.0, 2.5)
	var t := _seq
	if not await _wait(2.0, t): return
	hud.show_thought("Almost three in the morning. The video's still open.", 4.5)
	if not await _wait(4.0, t): return
	hud.show_hint("Mouse: look     WASD: move     Shift: run     E: interact\nEsc / P: pause", 9.0)


func continue_game() -> void:
	hud.close_menu()
	if not _restore_checkpoint():
		start_new_game()
		return
	set_mode("game")
	hud.set_fade(1.0)
	hud.fade_to(0.0, 2.0)


func return_to_title() -> void:
	hud.close_menu()
	show_title()


func quit_game() -> void:
	get_tree().quit()


# ------------------------------------------------------------------ notebook & pause

func open_notebook() -> void:
	if mode != "game":
		return
	if not has_flag("has_notebook"):
		if zone_type == "bedroom" and Notebook.has_any_written():
			hud.show_thought("It's on the desk.", 2.0)
		return
	Notebook.on_opened()
	Sfx.play("page", -3.0)
	hud.open_notebook(Data.notebook_title, Notebook.build_page())
	set_mode("overlay")


func close_notebook() -> void:
	hud.close_overlay()
	Sfx.play("page", -6.0)
	set_mode("game")


func open_pause() -> void:
	if hud.menu_open():
		return
	var corrupted := false
	var may_self := false
	var stage := player.dread.stage
	if zone and zone.is_nightmare() and Settings.menu_corruption and not in_sequence:
		var cooled := _clock - _last_corrupted > 120.0
		var scared := stage >= Dread.Stage.TERRIFIED or (stage == Dread.Stage.AFRAID and randf() < 0.35)
		if cooled and scared and corrupted_menus_shown < 3:
			corrupted = true
			corrupted_menus_shown += 1
			_last_corrupted = _clock
			may_self = Settings.self_unpause and not self_unpause_used and stage >= Dread.Stage.TERRIFIED
	_mode_before_menu = mode
	get_tree().paused = true
	set_mode("menu")
	hud.open_pause(corrupted, may_self)


func resume(self_unpause := false) -> void:
	hud.close_menu()
	get_tree().paused = false
	set_mode(_mode_before_menu if _mode_before_menu in ["game", "dialogue", "cinematic"] else "game")
	if self_unpause:
		self_unpause_used = true
		player.dread.add_fear(5.0, "self unpause")
		player.jolt(Vector3(2, -3, 0))


# ------------------------------------------------------------------ bedroom

func request_tutorial() -> void:
	hud.open_tutorial(Data.tutorial)
	set_mode("overlay")


func on_tutorial_finished() -> void:
	set_flag("tutorial_done")
	var t := _seq
	if not await _wait(0.6, t): return
	hud.close_overlay()
	set_mode("game")
	hud.show_thought("Five rules. Written down. Okay.", 3.5)
	hud.show_hint("Take the notebook from the desk, then go to bed.", 7.0)


func request_sleep() -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	hud.show_thought("I will know I'm dreaming. I will know I'm dreaming...", 5.0)
	hud.fade_to(1.0, 3.0)
	if not await _wait(4.0, t): return
	hud.show_card("3:12 AM", "", 1.0)
	if not await _wait(3.0, t): return
	hud.hide_card(1.0)
	if not await _wait(1.5, t): return
	enter_zone("city")
	save_checkpoint()
	hud.fade_to(0.0, 3.5)
	in_sequence = false
	set_mode("game")


# ------------------------------------------------------------------ waking (falling)

func request_wake() -> void:
	if in_sequence:
		return
	if zone_type == "maze":
		hud.show_thought("Wake up. Wake up. Wake up. ...Nothing.", 3.5)
		player.dread.add_fear(4.0, "can't wake")
		return
	if zone_type != "city":
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	hud.show_thought("Okay. That's enough. Wake up.", 3.0)
	if not await _wait(1.6, t): return
	# The floor simply stops being there.
	Sfx.play("thud", -2.0)
	Sfx.play("whoosh", 0.0)
	player.jolt(Vector3(-8, 0, 3))
	player.set_phasing(true)
	set_flag("fell_through")
	Notebook.reveal_on_next_open("never_twice")
	if not await _wait(1.6, t): return
	hud.fade_to(1.0, 0.6)
	if not await _wait(1.0, t): return
	player.set_phasing(false)
	enter_zone("maze")
	player.dread.set_values(maxf(player.dread.fear, 22.0), player.dread.stability)
	save_checkpoint()
	hud.fade_to(0.0, 3.0)
	in_sequence = false
	set_mode("game")


# ------------------------------------------------------------------ maze exit (end of slice)

func on_maze_exit() -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	set_flag("maze_escaped")
	hud.fade_to(1.0, 1.2)
	if not await _wait(1.5, t): return
	# Deliberate silence: everything stops at once.
	_leave_zone()
	player.set_drone(0.0)
	player.dread.set_profile(false, 0.0, 0.0, 10.0)
	player.set_physics_process(false)
	if not await _wait(3.0, t): return
	hud.show_card("Now the nightmare begins.", "End of the DREAM PROTOCOL vertical slice. Thank you for playing.", 2.0)
	if not await _wait(7.5, t): return
	hud.hide_card(1.5)
	if not await _wait(2.0, t): return
	player.set_physics_process(true)
	return_to_title()


# ------------------------------------------------------------------ death

func _on_overwhelmed() -> void:
	if in_sequence or zone == null or not zone.is_nightmare():
		return
	_death_sequence()


func _death_sequence() -> void:
	in_sequence = true
	var t := _seq
	hud.close_overlay()
	hud.clear_text()
	set_mode("cinematic")
	hud.fade_to(1.0, 0.15)
	if not await _wait(0.8, t): return
	# You seem to wake up.
	enter_zone("bedroom", false, true)
	player.dread.set_values(0.0, 100.0)
	player.set_locked(true)
	hud.fade_to(0.0, 2.5)
	if not await _wait(2.2, t): return
	hud.show_thought("...I'm awake. Okay. I'm awake.", 3.0)
	if not await _wait(3.5, t): return
	# Something, right behind you.
	var behind := player.global_position + player.global_transform.basis.z * 1.2 + Vector3.UP * 1.2
	Sfx.play_at("thud", zone, behind, 4.0, 10.0)
	if not await _wait(0.8, t): return
	player.play_shoulder_grab()
	player.jolt(Vector3(-7, 4, -3))
	hud.set_fade(0.75 * clampf(Settings.visual_intensity, 0.3, 1.0), Color(0.55, 0, 0))
	if not await _wait(0.2, t): return
	hud.fade_to(1.0, 0.2)
	if not await _wait(1.5, t): return
	hud.show_card("You woke up.", "", 1.2)
	if not await _wait(3.0, t): return
	hud.hide_card(0.8)
	if not await _wait(1.2, t): return
	hud.show_card("Didn't you?", "", 0.8)
	if not await _wait(2.8, t): return
	hud.hide_card(0.8)
	if not await _wait(1.2, t): return
	player.reset_presentation()
	if not _restore_checkpoint(30.0, 60.0):
		show_title()
		return
	hud.fade_to(0.0, 2.0)
	set_mode("game")


# ------------------------------------------------------------------ the DREAD director

func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	_clock += delta
	var d := player.dread
	_smoothed_dread = lerpf(_smoothed_dread, d.alpha(), clampf(delta * 1.5, 0.0, 1.0))
	var s := _smoothed_dread
	var v := clampf(Settings.visual_intensity, 0.0, 1.0)
	hud.set_post(0.25 + 0.75 * s * v, maxf(0.0, s - 0.25) * 0.5 * v, 0.45 * s * v, maxf(0.0, s - 0.5) * 2.0 * v)
	player.set_drone(smoothstep(0.2, 1.0, s) * 1.2 if d.nightmare else 0.0)
	if zone:
		zone.on_dread(s * 100.0, d.stage, delta)
	if not in_sequence and d.nightmare and d.stage >= Dread.Stage.UNEASY and _clock > _next_distant:
		# Something knocks, somewhere you aren't looking.
		var back := player.global_transform.basis.z.rotated(Vector3.UP, randf_range(-1.0, 1.0))
		var where := player.global_position + back * randf_range(12.0, 24.0) + Vector3.UP * 1.5
		Sfx.play_at("knock" if randf() < 0.7 else "thud", zone, where, -2.0 + 6.0 * s * Settings.audio_intensity, 40.0)
		d.notify_suspicious()
		_next_distant = _clock + lerpf(70.0, 20.0, s) * randf_range(0.8, 1.3)
