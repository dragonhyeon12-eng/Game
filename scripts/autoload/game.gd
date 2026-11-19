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
## Numbers for objective text, e.g. {"fuses": 2}
var counters := {}
var _obj_t := 0.0

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
	main.add_child(TouchControls.new())
	show_title()


# ------------------------------------------------------------------ flags

func has_flag(f: String) -> bool:
	return flags.has(f)


func set_flag(f: String) -> void:
	var fresh := not flags.has(f)
	flags[f] = true
	if fresh and hud:
		for o in Data.objectives.get(zone_type, []):
			if o.get("flag", "") == f:
				Sfx.play("chime", -16.0, 1.25)   # an objective done: a small, cold note
				break
	var journal := Journal.on_flag(f)
	var notebook := Notebook.on_flag(f)      # both, always: one must never swallow the other
	if journal and hud:
		hud.show_hint("Your dream journal has a new entry.\n(Pause > MENU > DREAM JOURNAL)", 6.0)
	elif notebook and hud:
		Sfx.play("page", -8.0, 0.9)
		hud.show_thought("...Something new in the notebook. I didn't write anything.", 3.0)


## The current zone's objectives as [[text, done], ...] (see data/Objectives.json).
func objectives() -> Array:
	var out := []
	for o in Data.objectives.get(zone_type, []):
		var done := has_flag(o.get("flag", ""))
		var after: String = o.get("after", "")
		if after != "" and not has_flag(after) and not done:
			continue
		out.append([_fill_counters(String(o.get("text", ""))), done])
	return out


var _placeholder: RegEx

## "{name}" -> the counter's value as a whole number (0 if it hasn't been counted yet; saves store floats).
func _fill_counters(text: String) -> String:
	if not text.contains("{"):
		return text
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{([a-z_]+)\\}")
	for m in _placeholder.search_all(text):
		text = text.replace(m.get_string(), str(int(counters.get(m.get_string(1), 0))))
	return text


func clear_flag(f: String) -> void:
	flags.erase(f)


# ------------------------------------------------------------------ input modes

func set_mode(m: String) -> void:
	if m == "game" and title_preview:
		_stop_title()       # however play begins, the title tour ends
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
	player.hands.visible = m == "game" or m == "dialogue"


func enter_dialogue_mode() -> void:
	set_mode("dialogue")


func exit_dialogue_mode() -> void:
	if mode == "dialogue":
		set_mode("game")


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if _death_skippable and mode == "cinematic" and (event.is_action_pressed("jump") or event.is_action_pressed("interact")):
		skip_death()
		get_viewport().set_input_as_handled()
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

const ZONES := ["bedroom", "bedroom_dream", "city", "maze", "deep", "seabed", "abyss", "compression", "tenement", "above",
	"blackout", "stilllife", "openspace", "pattern", "quiet"]


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
		"bedroom_dream":
			var bd := BedroomZone.new()
			bd.dreaming = true
			zone = bd
		"city":
			zone = CityZone.new()
		"maze":
			var m := MazeZone.new()
			m.seed_value = maze_seed
			zone = m
		"deep":
			zone = DeepZone.new()
		"seabed":
			zone = SeabedZone.new()
		"abyss":
			zone = AbyssZone.new()
		"compression":
			zone = CompressionZone.new()
		"tenement":
			zone = TenementZone.new()
		"above":
			zone = AboveZone.new()
		"blackout":
			zone = BlackoutZone.new()
		"stilllife":
			zone = StillLifeZone.new()
		"openspace":
			zone = OpenSpaceZone.new()
		"pattern":
			zone = PatternZone.new()
		"quiet":
			zone = QuietZone.new()
		"shifting":
			zone = ShiftZone.new()       # (prototype: not part of the story, never saved)
		_:
			zone_type = ""
			return
	zone_type = type
	zone.name = "Zone_" + type
	main.add_child(zone)
	zone.build()
	zone.finish_batches()
	zone.cheapen()
	player.teleport(zone.player_start())
	if from_save:
		var cp = zone.saved_checkpoint()
		if cp != null:
			player.teleport(cp)
			player.rotation.y = (cp as Transform3D).basis.get_euler().y
	player.dread.set_profile(zone.is_nightmare(), zone.fear_gain(), zone.fear_floor(), zone.fear_decay())
	player.set_movement(zone.walk_speed(), zone.sprint_speed(), zone.floor_surface())
	var pacing := zone.anomaly_pacing()
	if pacing.x >= 0.0:
		Anomalies.set_pacing(pacing.x, pacing.y)
	zone.on_player_entered(from_save)
	if title_preview:
		print("Entered zone: ", type, " (title)")
		return
	Sfx.music_gain = 1.0
	match type:
		"city": Sfx.play_music("city", 4.0)
		"bedroom_dream":
			Sfx.play_music("city", 6.0)
			Sfx.music_gain = 0.5
		"maze": Sfx.play_music("maze", 6.0)
		"deep": Sfx.play_music("deep", 8.0)
		"seabed": Sfx.play_music("deep", 4.0)
		"abyss":
			Sfx.play_music("deep", 4.0)
			Sfx.music_gain = 0.8
		"compression", "tenement": Sfx.stop_music(2.0)   # nothing but the building
		"above":
			Sfx.play_music("deep", 6.0)
			Sfx.music_gain = 0.6
		"stilllife":
			Sfx.play_music("muzak", 3.0)       # the store's own music, still playing for nobody
			Sfx.music_gain = 0.7
		"pattern":
			Sfx.play_music("maze", 5.0)
			Sfx.music_gain = 0.5
		"quiet":
			Sfx.play_music("title", 6.0)
			Sfx.music_gain = 0.35
		_: Sfx.stop_music(1.5)   # the real bedroom, the dark street, the open sky: quiet   # the real bedroom stays quiet
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
	counters.clear()
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
		"unlocked": player.manifestation.unlocked, "counters": counters,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		print("Checkpoint saved (", zone_type, ")")


func _restore_checkpoint(fear_override := -1.0, stability_override := -1.0) -> bool:
	if not has_checkpoint():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or not String(data.get("zone", "")) in ZONES:
		return false     # no save, a damaged one, or one from an area that no longer exists: start afresh
	_reset_world()
	for f in data.get("flags", []):
		flags[f] = true
	maze_seed = int(data.get("seed", 1))
	counters = data.get("counters", {})
	Notebook.load_state(data.get("notebook", {}))
	enter_zone(data.zone, true)
	player.manifestation.unlocked = data.get("unlocked", Data.manifest_start.duplicate())
	player.dread.set_values(fear_override if fear_override >= 0.0 else float(data.get("fear", 0.0)),
		stability_override if stability_override >= 0.0 else float(data.get("stability", 100.0)))
	return true


# ------------------------------------------------------------------ flow

## The title screen: behind the menu, a slow tour of where each realm begins.
const TITLE_TOUR := [["bedroom", "3:12 AM"], ["city", "THE CITY"], ["maze", "THE BACKROOMS"], ["deep", "THE DEEP"],
	["seabed", "THE DEEP  -  THE SEABED"], ["abyss", "THE DEEP  -  THE ABYSS"], ["compression", "COMPRESSION"],
	["tenement", "COMPRESSION  -  THE TENEMENT"], ["above", "ABOVE"], ["blackout", "BLACKOUT"], ["stilllife", "STILL LIFE"],
	["openspace", "OPEN SPACE"], ["pattern", "PATTERN"], ["quiet", "THE QUIET"]]
const TITLE_SHOT_SECONDS := 7.0
var title_preview := false
var _title_token := 0


func show_title() -> void:
	_reset_world()
	title_preview = true
	_title_token += 1
	enter_zone("bedroom")
	_title_shot("3:12 AM")
	hud.set_fade(1.0)
	hud.fade_to(0.0, 2.0)
	set_mode("menu")
	hud.open_title(has_checkpoint())
	Sfx.play_music("title", 3.0)
	_title_tour(_title_token)


func _title_tour(token: int) -> void:
	var i := 0
	while true:
		await get_tree().create_timer(TITLE_SHOT_SECONDS).timeout
		if token != _title_token or not title_preview or mode != "menu":
			return
		hud.fade_to(1.0, 0.9)
		await get_tree().create_timer(1.0).timeout
		if token != _title_token or not title_preview or mode != "menu":
			return
		i = (i + 1) % TITLE_TOUR.size()
		enter_zone(TITLE_TOUR[i][0])
		_title_shot(TITLE_TOUR[i][1])
		hud.fade_to(0.0, 1.4)


## A realm as a backdrop: its story asleep (no hints, no hunting, no fear), the camera at its start.
func _title_shot(caption: String) -> void:
	in_sequence = true
	hud.clear_text()
	player.dread.set_profile(false, 0.0, 0.0, 10.0)
	player.dread.set_values(0.0, 100.0)
	player.set_drone(0.0)
	player.set_locked(true)
	hud.set_title_caption(caption)


func _stop_title() -> void:
	title_preview = false
	_title_token += 1
	in_sequence = false
	hud.set_title_caption("")


func start_new_game() -> void:
	_stop_title()
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
	if TouchControls.wanted():
		hud.show_hint("Left side: drag to move     Right side: drag to look\nUSE to interact     MENU to pause", 9.0)
	else:
		hud.show_hint("Mouse: look     WASD: move     Shift: run     E: interact\nEsc / P: pause", 9.0)


func continue_game() -> void:
	_stop_title()
	hud.close_menu()
	if not _restore_checkpoint():
		start_new_game()
		return
	set_mode("game")
	hud.set_fade(1.0)
	hud.fade_to(0.0, 2.0)


## PROTOTYPE: the shifting-rooms test bed, straight from the title. Leaves your saved game alone.
func start_prototype() -> void:
	_stop_title()
	hud.close_menu()
	_reset_world()
	enter_zone("shifting")
	set_mode("game")
	hud.set_fade(1.0)
	hud.fade_to(0.0, 1.5)


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
	enter_zone("bedroom_dream")
	save_checkpoint()
	hud.fade_to(0.0, 3.5)
	in_sequence = false
	set_mode("game")


## Out of the dream bedroom into the summer city.
func leave_dream_house() -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	Sfx.play("door_creak", -6.0, 1.2)
	hud.fade_to(1.0, 0.8)
	if not await _wait(1.0, t): return
	enter_zone("city")
	save_checkpoint()
	hud.fade_to(0.0, 2.0)
	in_sequence = false
	set_mode("game")
	hud.show_thought("Warm. Bright. It smells like cut grass. This is MY dream.", 4.0)


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


# ------------------------------------------------------------------ maze exit -> THE DEEP

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
	Sfx.stop_music(0.01)
	_leave_zone()
	player.set_drone(0.0)
	player.dread.set_profile(false, 0.0, 0.0, 10.0)
	player.set_physics_process(false)
	if not await _wait(2.0, t): return
	hud.show_card("Now the nightmare begins.", "", 2.0)
	if not await _wait(4.5, t): return
	hud.hide_card(1.5)
	if not await _wait(1.5, t): return
	player.set_physics_process(true)
	enter_zone("deep")
	save_checkpoint()
	hud.fade_to(0.0, 3.0)
	in_sequence = false
	set_mode("game")


# ------------------------------------------------------------------ THE DEEP exit (end of the current build)

## Through the glowing doorway in the sea cave: deeper.
func enter_abyss() -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	set_flag("deep_doorway")
	Sfx.play("whoosh", 0.0, 0.5)
	Sfx.stinger("riser", -4.0)
	hud.fade_to(1.0, 1.0, Color(0.85, 0.95, 1.0))
	if not await _wait(1.6, t): return
	enter_zone("abyss")
	save_checkpoint()
	hud.fade_to(0.0, 2.5)
	in_sequence = false
	set_mode("game")


## The freight elevator stops. Somewhere much higher than it should.
func enter_tenement() -> void:
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	hud.fade_to(1.0, 0.6)
	if not await _wait(0.8, t): return
	Sfx.play("ding", -4.0, 0.8)
	enter_zone("tenement")
	save_checkpoint()
	if not await _wait(0.6, t): return
	hud.fade_to(0.0, 2.0)
	in_sequence = false
	set_mode("game")


func on_deep_exit() -> void:
	_realm_transition("deep_escaped", "compression", "COMPRESSION", "")


func on_compression_exit() -> void:
	_realm_transition("comp_escaped", "above", "ABOVE", "")


## Leave one realm for the next: fade, silence, a title card, the next zone, a checkpoint.
func _realm_transition(flag: String, next: String, title: String, subtitle: String) -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	set_flag(flag)
	hud.fade_to(1.0, 1.5)
	if not await _wait(1.8, t): return
	Sfx.stop_music(0.01)
	_leave_zone()
	player.set_drone(0.0)
	player.dread.set_profile(false, 0.0, 0.0, 10.0)
	player.set_physics_process(false)
	if not await _wait(2.0, t): return
	hud.show_card(title, subtitle, 2.0)
	if not await _wait(4.5, t): return
	hud.hide_card(1.5)
	if not await _wait(1.5, t): return
	player.set_physics_process(true)
	player.reset_presentation()
	enter_zone(next)
	player.dread.set_values(15.0, 100.0)
	save_checkpoint()
	hud.fade_to(0.0, 3.0)
	in_sequence = false
	set_mode("game")


func on_above_exit() -> void:
	_realm_transition("above_escaped", "blackout", "BLACKOUT", "Larkspur Lane. After midnight. The power's out.")


func on_blackout_exit() -> void:
	_realm_transition("bo_escaped", "stilllife", "STILL LIFE", "The Emporium. Open late. Nobody told the staff to go home.")


func on_stilllife_exit() -> void:
	_realm_transition("sl_escaped", "openspace", "OPEN SPACE", "Level 4. Then nothing at all, as far as you can see.")


func on_openspace_exit() -> void:
	_realm_transition("os_escaped", "pattern", "PATTERN", "Mind the gaps.")


func on_pattern_exit() -> void:
	_realm_transition("pt_escaped", "quiet", "THE QUIET", "Visiting hours.")


## End of the current build: the garden gate in THE QUIET. (THE DESTINATION is not built yet.)
func on_quiet_exit() -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	set_flag("q_escaped")
	hud.fade_to(1.0, 2.5, Color(0.95, 0.95, 0.92))
	if not await _wait(2.8, t): return
	Sfx.stop_music(0.01)
	_leave_zone()
	player.set_drone(0.0)
	player.dread.set_profile(false, 0.0, 0.0, 10.0)
	player.set_physics_process(false)
	hud.set_fade(1.0)
	if not await _wait(2.5, t): return
	hud.show_card("THE DESTINATION", "End of the current build. The last part of the dream is still being written. Thank you for playing.", 2.0)
	if not await _wait(7.5, t): return
	hud.hide_card(1.5)
	if not await _wait(2.0, t): return
	player.set_physics_process(true)
	return_to_title()


# ------------------------------------------------------------------ death

func _on_overwhelmed() -> void:
	if in_sequence or zone == null or not zone.is_nightmare():
		return
	# in the sea, it comes from below
	if zone_type == "seabed" or zone_type == "abyss" or (zone_type == "deep" and player.global_position.y < DeepZone.OCEAN_TOP):
		ankle_grab(true)
	else:
		entity_death("observer")


## Black hands rise from the sea floor and take your ankles. `death` = wake up (lose);
## otherwise this is the way down into the second part of THE DEEP.
func ankle_grab(death: bool) -> void:
	if in_sequence and death:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	hud.clear_text()
	player.play_ankle_grab()
	Sfx.play("thud", 0.0, 0.6)
	player.jolt(Vector3(-6, 0, 2))
	if not await _wait(1.0, t): return
	player.pulled_down = true
	Sfx.play("whoosh", 2.0, 0.6)
	hud.fade_to(1.0, 0.8)
	if not await _wait(1.2, t): return
	player.reset_presentation()
	if death:
		_death_sequence("wake")
		return
	set_flag("deep_grabbed")
	enter_zone("seabed")
	save_checkpoint()
	hud.fade_to(0.0, 4.0)
	in_sequence = false
	set_mode("game")


## The leviathan comes out of the dark. (Straying from the path on the seabed.)
func leviathan_kill(lev: Leviathan) -> void:
	entity_death("leviathan", lev)


## Turn the player's view toward a point over `seconds` (cutscenes).
func look_toward(point: Vector3, seconds: float) -> void:
	var to := point - player.camera.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "rotation:y", lerp_angle(player.rotation.y, yaw, 1.0), seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v): player._pitch = v; player.head.rotation.x = v, player._pitch, pitch, seconds).set_trans(Tween.TRANS_SINE)


## Each entity kills in its own way. Every one ends in the waking sequence.
func entity_death(kind: String, who: Node3D = null) -> void:
	if in_sequence:
		return
	in_sequence = true
	var t := _seq
	set_mode("cinematic")
	hud.clear_text()
	match kind:
		"stalker":
			# it is right behind you. you turn. it is already closer than that.
			var head := who.global_position + Vector3(0, 2.1, 0)
			look_toward(head, 0.25)
			Sfx.stinger("screech", 2.0)
			if not await _wait(0.3, t): return
			var cam := player.camera.global_position
			var fwd := -player.camera.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var tw := create_tween()
			tw.tween_property(who, "global_position", Vector3(cam.x, player.global_position.y, cam.z) + fwd * 0.55, 0.18)
			if not await _wait(0.2, t): return
			look_toward(who.global_position + Vector3(0, 2.25, 0), 0.35)
			Sfx.play("hit", 4.0, 0.8)
			player.jolt(Vector3(-12, 6, 8))
			hud.set_post(1.0, 0.6, 1.0, 1.0)
			if not await _wait(0.2, t): return
			await hud.jumpscare(1.7)
			if t != _seq: return
			Sfx.play("thud", 6.0, 0.6)
			hud.set_fade(1.0, Color(0.05, 0.0, 0.0))
			if not await _wait(0.8, t): return
		"sheet":
			# it was right there when you turned. the sheet comes over your face.
			var head := who.global_position + Vector3(0, 1.5, 0)
			look_toward(head, 0.25)
			Sfx.stinger("screech", -2.0)
			if not await _wait(0.4, t): return
			var cam := player.camera.global_position
			var fwd := -player.camera.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			create_tween().tween_property(who, "global_position", Vector3(cam.x, who.global_position.y, cam.z) + fwd * 0.35, 0.22)
			Sfx.play("whoosh", 0.0, 1.2)
			player.jolt(Vector3(-8, 3, 4))
			hud.fade_to(0.9, 0.35, Color(0.86, 0.85, 0.8))
			if not await _wait(0.4, t): return
			await hud.jumpscare(1.2)
			if t != _seq: return
			Sfx.play("breath", 4.0, 1.4)
			for i in 8:
				player.jolt(Vector3(randf_range(-4, -1), randf_range(-2, 2), randf_range(-2, 2)))
				Sfx.play("scrape", -10.0, randf_range(1.5, 2.0))
				if not await _wait(0.16, t): return
			Sfx.play("breath", -4.0, 0.7)
			hud.fade_to(1.0, 1.4, Color(0.08, 0.08, 0.07))
			if not await _wait(1.6, t): return
		"fall":
			# down. the wind, the lights of other buildings going up past you. then nothing.
			var pd := player.global_position + Vector3(0, -30, 0) - player.global_transform.basis.z * 6.0
			look_toward(pd, 1.2)
			Sfx.play("whoosh", 6.0, 0.4)
			Sfx.play("wind", 4.0, 1.3)
			Sfx.stinger("riser", 0.0)
			hud.show_thought("No no no no no", 1.5)
			for i in 16:
				hud.set_post(0.3 + i * 0.04, 0.2 + i * 0.03, 1.0, 1.0 + i * 0.15)
				player.jolt(Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-2, 2)))
				if not await _wait(0.12, t): return
			Sfx.play("hit", 8.0, 0.35)
			Sfx.play("thud", 8.0, 0.3)
			hud.set_fade(1.0)
			Sfx.stop_music(0.01)
			if not await _wait(1.5, t): return
		"observer":
			# the man who doesn't move. right in front of you. he's always been right in front of you.
			var fwd := -player.camera.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var o := Observer.new()
			zone.add_child(o)
			o.global_position = player.global_position + fwd * 0.75
			o.rotation.y = atan2(-fwd.x, -fwd.z)
			o.seen_threshold = 100.0
			Sfx.play("static_burst", 4.0)
			Sfx.stinger("braam", 4.0)
			player.jolt(Vector3(-6, 2, 0))
			hud.set_post(1.0, 0.8, 1.0, 2.0)
			if not await _wait(0.5, t): return
			await hud.jumpscare(1.9)
			if t != _seq: return
			Sfx.play("glitch", 4.0, 0.6)
			hud.set_fade(1.0)
			if not await _wait(0.6, t): return
		"crush":
			# the corridor folds shut on you: ceiling, walls, the light going out of the gap
			Sfx.play("grind", 6.0, 0.4)
			Sfx.play("metal_screech", 2.0, 0.5)
			Sfx.stinger("braam", 2.0)
			for i in 10:
				player.jolt(Vector3(randf_range(-6, -2), randf_range(-3, 3), randf_range(-4, 4)))
				hud.set_post(0.4 + i * 0.07, 0.3 + i * 0.05, 1.0, 1.0 + i * 0.2)
				if i == 4:
					Sfx.play("creak", 4.0, 0.4)
				if not await _wait(0.07, t): return
			player.camera.fov = maxf(player.camera.fov - 18.0, 40.0)
			Sfx.play("hit", 6.0, 0.4)
			Sfx.play("thud", 6.0, 0.35)
			player.jolt(Vector3(-16, 0, 14))
			hud.set_fade(1.0, Color(0.03, 0.02, 0.0))
			if not await _wait(1.4, t): return
		"leviathan":
			# it comes out of the dark, mouth already open. you see all of it. then the inside of it.
			var lev := who as Leviathan
			var cam := player.camera.global_position
			var fwd := -player.camera.global_transform.basis.z
			if lev.head_position().distance_to(cam) > 30.0:
				lev.place_head(cam + fwd * 30.0 + Vector3(0, 4, 0), -fwd)
			look_toward(lev.head_position(), 0.5)
			lev.rush(cam, 3.0)
			Sfx.stinger("screech", 4.0)
			Sfx.play("whoosh", 2.0, 0.4)
			player.jolt(Vector3(-4, 2, 0))
			hud.set_post(0.6, 0.3, 1.0, 1.0)
			if not await _wait(0.9, t): return
			# a heartbeat of stillness, staring into it
			Sfx.play("heartbeat", 2.0)
			for i in 12:
				look_toward(lev.head_position(), 0.08)
				if not await _wait(0.08, t): return
			lev.rush(cam, 30.0)
			for i in 30:
				if not await _wait(0.03, t): return
				if lev.head_position().distance_to(cam) < 3.5:
					break
			Sfx.play("hit", 6.0, 0.5)
			Sfx.play("thud", 6.0, 0.4)
			player.jolt(Vector3(-14, 10, -12))
			hud.set_fade(1.0, Color(0.08, 0.0, 0.0))
			if not await _wait(0.5, t): return
			Sfx.play("bubbles", 0.0, 0.6)
			Sfx.play("sub_drop", 0.0)
			if not await _wait(1.2, t): return
		"shadow":
			# the dark closes in from the edges. something cold over your eyes.
			Sfx.play("whisper", 6.0, 0.8)
			Sfx.stinger("sub_drop", 2.0)
			for i in 14:
				hud.set_post(0.5 + i * 0.04, 0.4, 1.0, 1.0 + i * 0.1)
				player.jolt(Vector3(randf_range(-1.5, 0.5), randf_range(-1, 1), 0))
				if i == 8:
					Sfx.play("breath", 4.0, 0.7)
				if not await _wait(0.09, t): return
			Sfx.play("hit", 4.0, 0.6)
			player.jolt(Vector3(-10, 0, 6))
			hud.set_fade(1.0)
			if not await _wait(1.2, t): return
		"mannequin":
			# you turn. it's already there. plastic. it doesn't have a face, and it's smiling.
			if who:
				look_toward(who.global_position + Vector3(0, 1.6, 0), 0.2)
			Sfx.play("creak", 4.0, 1.6)
			if not await _wait(0.25, t): return
			if who:
				var cam := player.camera.global_position
				var fwd := -player.camera.global_transform.basis.z
				fwd.y = 0.0
				who.global_position = Vector3(cam.x, player.global_position.y, cam.z) + fwd.normalized() * 0.5
				who.look_at(Vector3(cam.x, who.global_position.y, cam.z), Vector3.UP, true)
			Sfx.play("hit", 6.0, 1.4)
			Sfx.play("knock", 6.0, 1.8)
			player.jolt(Vector3(-12, 8, 6))
			hud.set_post(1.0, 0.6, 1.0, 1.2)
			if not await _wait(0.15, t): return
			await hud.jumpscare(1.5)
			if t != _seq: return
			hud.set_fade(1.0, Color(0.9, 0.88, 0.84))
			if not await _wait(0.4, t): return
			hud.set_fade(1.0)
			if not await _wait(0.6, t): return
		"pattern":
			# the holes. on the walls, on your hands, on the inside of your eyes.
			Sfx.play("static_burst", 2.0, 0.6)
			Sfx.stinger("riser", 0.0)
			await hud.holes_overlay(1.8)
			if t != _seq: return
			Sfx.play("hit", 4.0, 0.7)
			hud.set_fade(1.0)
			if not await _wait(0.8, t): return
		_:
			hud.fade_to(1.0, 0.3)
			if not await _wait(0.4, t): return
	_death_sequence("wake")


## Something touches you in the dark. No hands this time.
func sudden_death() -> void:
	if in_sequence:
		return
	in_sequence = true
	set_mode("cinematic")
	hud.clear_text()
	Sfx.play("static_burst", 2.0)
	Sfx.play("thud", 6.0, 0.5)
	player.jolt(Vector3(-10, 8, -6))
	hud.set_fade(1.0, Color(0.05, 0, 0))
	_death_sequence("wake")


## Falling, a long way.
func fall_death() -> void:
	entity_death("fall")


var _death_skippable := false


func _death_sequence(prelude := "fade") -> void:
	in_sequence = true
	var t := _seq
	# you've seen it before: you may skip it
	_death_skippable = Settings.deaths_seen > 0
	hud.show_skip(_death_skippable)
	Settings.set_value("deaths_seen", Settings.deaths_seen + 1)
	hud.close_overlay()
	hud.clear_text()
	set_mode("cinematic")
	if prelude == "fade":
		hud.fade_to(1.0, 0.15)
	if not await _wait(0.8, t): return
	player.reset_presentation()
	# You seem to wake up.
	enter_zone("bedroom", false, true)
	Sfx.stop_music(0.01)
	player.dread.set_values(0.0, 100.0)
	player.set_locked(true)
	hud.fade_to(0.0, 2.5)
	if not await _wait(2.2, t): return
	hud.show_thought("I'm awake. Okay. I'm awake.", 3.0)
	if not await _wait(3.5, t): return
	# Something, right behind you.
	var behind := player.global_position + player.global_transform.basis.z * 1.2 + Vector3.UP * 1.2
	Sfx.play_at("thud", zone, behind, 4.0, 10.0)
	if not await _wait(0.8, t): return
	player.play_shoulder_grab()      # (over your face now: long fingers, claws)
	player.jolt(Vector3(-7, 4, -3))
	Sfx.play("scrape", 2.0, 1.4)
	hud.clear_text()
	hud.panic_text("No. No. No no no no no NONO NO N-")
	# a moment to see them, gripping
	if not await _wait(1.6, t): return
	player.jolt(Vector3(-4, -3, 2))
	Sfx.play("thud", -2.0, 0.8)
	if not await _wait(0.35, t): return
	hud.set_fade(0.75 * clampf(Settings.visual(), 0.3, 1.0), Color(0.55, 0, 0) if Settings.flashing_ok() else Color(0.12, 0, 0))
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
	_end_death()


func _end_death() -> void:
	_death_skippable = false
	hud.show_skip(false)
	player.reset_presentation()
	if not _restore_checkpoint(30.0, 60.0):
		show_title()
		return
	hud.hide_card(0.0)
	hud.set_fade(1.0)
	hud.fade_to(0.0, 2.0)
	set_mode("game")


func skip_death() -> void:
	if not _death_skippable:
		return
	_cancel_sequences()   # stops the running sequence where it is
	Sfx.stop_music(0.01)
	_end_death()


# ------------------------------------------------------------------ the DREAD director

func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	if title_preview:
		player.rotation.y += delta * 0.025      # the backdrop turns, slowly
	_clock += delta
	var d := player.dread
	_smoothed_dread = lerpf(_smoothed_dread, d.alpha(), clampf(delta * 1.5, 0.0, 1.0))
	var s := _smoothed_dread
	var v := clampf(Settings.visual(), 0.0, 1.0)
	hud.set_post(0.25 + 0.75 * s * v, maxf(0.0, s - 0.25) * 0.5 * v, 0.45 * s * v, maxf(0.0, s - 0.5) * 2.0 * v)
	player.set_drone(smoothstep(0.2, 1.0, s) * 1.2 if d.nightmare else 0.0)
	Sfx.set_muffled(player.underwater)
	if zone_type == "maze":
		Sfx.music_gain = lerpf(0.55, 1.1, s) * lerpf(0.6, 1.0, Settings.audio_intensity)
	if zone:
		zone.on_dread(s * 100.0, d.stage, delta)
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		hud.set_objectives(objectives())
	if not in_sequence and d.nightmare and d.stage >= Dread.Stage.UNEASY and _clock > _next_distant:
		# Something knocks, somewhere you aren't looking.
		var back := player.global_transform.basis.z.rotated(Vector3.UP, randf_range(-1.0, 1.0))
		var where := player.global_position + back * randf_range(12.0, 24.0) + Vector3.UP * 1.5
		Sfx.play_at("knock" if randf() < 0.7 else "thud", zone, where, -2.0 + 6.0 * s * Settings.audio_intensity, 40.0)
		d.notify_suspicious()
		_next_distant = _clock + lerpf(70.0, 20.0, s) * randf_range(0.8, 1.3)
