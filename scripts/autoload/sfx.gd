extends Node
## Procedural audio. Every sound in the game is synthesized once at startup into an AudioStreamWAV,
## so there are no audio asset files. Loops are generated with whole cycles so they wrap cleanly.

const RATE := 22050

var streams := {}  # name -> AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _foley_pool: Array[AudioStreamPlayer] = []
var _next_foley := 0

# ---- music: generated on a background thread, crossfaded between two players
var music := {}                   # name -> AudioStreamWAV
var music_gain := 1.0             # extra multiplier (the maze raises it with DREAD)
var _music_players: Array[AudioStreamPlayer] = []
var _music_current := 0
var _music_target_name := ""
var _music_fade_speed := 0.5
var _music_levels := [0.0, 0.0]
var _music_targets := [0.0, 0.0]
var _music_thread: Thread
var _lowpass_index := -1
var _muffled := false


func set_muffled(on: bool) -> void:
	if on != _muffled and _lowpass_index >= 0:
		_muffled = on
		AudioServer.set_bus_effect_enabled(0, _lowpass_index, on)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	_build_all()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_foley_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music_players.append(m)
	if OS.has_feature("web") and not OS.has_feature("threads"):
		_build_music_stepwise()   # browsers without threads: one track at a time, between frames
	else:
		_music_thread = Thread.new()
		_music_thread.start(_build_music)
	# underwater: everything muffled
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 600.0
	AudioServer.add_bus_effect(0, lowpass)
	_lowpass_index = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _lowpass_index, false)


func _exit_tree() -> void:
	if _music_thread and _music_thread.is_started():
		_music_thread.wait_to_finish()


# ------------------------------------------------------------------ music

## Crossfade to a track ("title", "city", "maze") or "" for silence.
func play_music(track: String, fade_seconds := 2.5) -> void:
	_music_fade_speed = 1.0 / maxf(fade_seconds, 0.01)
	if track == _music_target_name and (track == "" or _music_players[_music_current].playing):
		return
	_music_target_name = track
	_music_targets[_music_current] = 0.0
	if track == "" or not music.has(track):
		return  # silence now; if the track is still being generated it starts when ready
	_music_current = 1 - _music_current
	var p := _music_players[_music_current]
	p.stream = music[track]
	p.play()
	_music_levels[_music_current] = 0.0
	_music_targets[_music_current] = 1.0


func stop_music(fade_seconds := 2.0) -> void:
	play_music("", fade_seconds)


func _music_ready(track: String, stream: AudioStreamWAV) -> void:
	music[track] = stream
	if track == _music_target_name and not _music_players[_music_current].playing:
		_music_target_name = ""
		play_music(track, 3.0)


func _process(delta: float) -> void:
	var vol := Settings.music_volume * music_gain
	for i in 2:
		_music_levels[i] = move_toward(_music_levels[i], _music_targets[i], _music_fade_speed * delta)
		var v: float = _music_levels[i] * vol
		_music_players[i].volume_db = -80.0 if v <= 0.001 else linear_to_db(v) - 8.0
		if _music_levels[i] <= 0.0 and _music_targets[i] <= 0.0 and _music_players[i].playing:
			_music_players[i].stop()


func _build_music() -> void:
	var t0 := Time.get_ticks_msec()
	call_deferred("_music_ready", "title", _to_wav(_track_title(), true))
	call_deferred("_music_ready", "city", _to_wav(_track_city(), true))
	call_deferred("_music_ready", "maze", _to_wav(_track_maze(), true))
	call_deferred("_music_ready", "deep", _to_wav(_track_deep(), true))
	call_deferred("_music_ready", "chase", _to_wav(_track_chase(), true))
	call_deferred("_music_ready", "muzak", _to_wav(_track_muzak(), true))
	print("Sfx: music generated in %d ms (background thread)" % (Time.get_ticks_msec() - t0))


## No threads (web): build the tracks on the main thread, one per pause, the title theme first.
func _build_music_stepwise() -> void:
	for track in ["title", "city", "maze", "deep", "chase", "muzak"]:
		await get_tree().create_timer(0.5 if track == "title" else 2.0, true).timeout
		var data: PackedFloat32Array
		match track:
			"title": data = _track_title()
			"city": data = _track_city()
			"maze": data = _track_maze()
			"chase": data = _track_chase()
			"muzak": data = _track_muzak()
			"home": data = _track_home()
			_: data = _track_deep()
		_music_ready(track, _to_wav(data, true))


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Adds a soft bell / celesta note into a buffer.
static func _bell(buf: PackedFloat32Array, start: float, midi: float, gain: float, length := 3.0) -> void:
	var f := _hz(midi)
	var i0 := int(start * RATE)
	var n := int(length * RATE)
	for i in n:
		var k := i0 + i
		if k >= buf.size():
			k -= buf.size()   # wrap around: the loop stays seamless
		var t := float(i) / RATE
		var env := minf(1.0, t * 300.0) * exp(-t * 1.6)
		buf[k] += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) * exp(-t * 3.0) + 0.12 * sin(TAU * f * 3.01 * t) * exp(-t * 6.0)) * env * gain


## Warm pad over a chord progression. chords: Array of Array[midi]; each chord lasts `bar` seconds.
static func _pad(buf: PackedFloat32Array, chords: Array, bar: float, gain: float) -> void:
	var n := buf.size()
	var count := chords.size()
	for i in n:
		var t := float(i) / RATE
		var idx := int(t / bar) % count
		var u := fmod(t, bar)
		var mix := smoothstep(bar - 1.6, bar, u)
		var v := 0.0
		for pass_i in 2:
			var c: Array = chords[idx if pass_i == 0 else (idx + 1) % count]
			var w := (1.0 - mix) if pass_i == 0 else mix
			if w <= 0.001:
				continue
			for m in c:
				var f := _hz(m)
				v += (sin(TAU * f * t) + sin(TAU * f * 1.004 * t) + 0.18 * sin(TAU * f * 2.0 * t)) * w
		buf[i] += v * gain * (0.85 + 0.15 * sin(TAU * t / 7.0))


func _track_city() -> PackedFloat32Array:
	var length := 32.0
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE))
	# Cmaj7 - Am7 - Fmaj7 - G6, slow and warm
	var chords := [[48, 55, 64, 71], [45, 52, 60, 67], [41, 48, 57, 64], [43, 50, 59, 64]]
	_pad(buf, chords, 8.0, 0.018)
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	var scale := [72, 74, 76, 79, 81, 84, 86, 88]   # C major pentatonic, high
	var beat := 0.0
	while beat < length:
		if r.randf() < 0.62:
			var note: int = scale[r.randi() % scale.size()]
			_bell(buf, beat, note, r.randf_range(0.05, 0.09))
		beat += [0.5, 1.0, 1.0, 1.5][r.randi() % 4]
	# a soft root bass on each chord
	for c in 4:
		_bell(buf, c * 8.0, chords[c][0] - 12, 0.12, 6.0)
	return buf


## The music box you carry: a little lullaby on a comb, high and slightly out of true, slowing at the end
## as the spring runs down.
func _musicbox() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(8.0 * RATE))
	var notes := [[0.0, 84], [0.4, 88], [0.8, 91], [1.2, 88], [1.6, 86], [2.2, 84], [2.6, 83], [3.0, 84], [3.4, 88],
		[3.8, 86], [4.3, 84], [4.9, 79], [5.6, 81], [6.4, 84]]
	for n in notes:
		_bell(buf, n[0], n[1] + 0.07, 0.16, 1.6)
		_bell(buf, n[0] + 0.003, n[1] + 12.0, 0.03, 0.6)       # the comb's bright overtone
	for i in buf.size():     # a soft mechanical tick under it
		var t := float(i) / RATE
		if fmod(t, 0.2) < 0.002 and t < 6.8:
			buf[i] += 0.04 * (randf() - 0.5)
	return buf


## The resting places: warm and slow, a few bells over a soft pad. Home.
func _track_home() -> PackedFloat32Array:
	var length := 32.0
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE))
	_pad(buf, [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]], 8.0, 0.010)
	var melody := [[0, 72], [2, 76], [4, 74], [6.5, 71], [8, 69], [10, 72], [12, 71], [14.5, 67], [16, 65], [18, 69],
		[20, 72], [22.5, 69], [24, 67], [26, 71], [28, 74], [30, 72]]
	for m in melody:
		_bell(buf, m[0], m[1], 0.05, 4.0)
	return buf


func _track_title() -> PackedFloat32Array:
	var length := 24.0
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE))
	_pad(buf, [[57, 64, 72], [53, 60, 69], [55, 62, 71], [52, 60, 67]], 6.0, 0.012)
	# a simple music-box lullaby
	var melody := [76, 74, 72, 74, 76, 79, 76, 74, 72, 69, 72, 74, 76, 74, 72, 67]
	for i in melody.size():
		_bell(buf, i * 1.5, melody[i], 0.07, 3.5)
		if i % 4 == 0:
			_bell(buf, i * 1.5 + 0.75, melody[i] + 12, 0.025, 2.5)
	return buf


## THE DEEP: slow, sinking glides far below, like something very large singing underwater.
func _track_deep() -> PackedFloat32Array:
	var length := 48.0
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / length
		var a := sin(TAU * 41.2 * t) * 0.5 + sin(TAU * 61.7 * t) * 0.3
		# a slow two-note call that slides down
		var call_env := maxf(0.0, sin(TAU * u * 2.0)) * maxf(0.0, sin(TAU * u * 2.0))
		var glide := 98.0 - 18.0 * fmod(u * 2.0, 1.0)
		a += sin(TAU * glide * t) * 0.25 * call_env
		lp += (_noise() - lp) * 0.004
		buf[i] = (a * 0.12 + lp * 0.9) * (0.7 + 0.3 * sin(TAU * u))
	# distant metallic pings
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for k in 7:
		_bell(buf, r.randf_range(0.0, length), r.randf_range(80.0, 92.0), 0.025, 5.0)
	return buf


func _track_maze() -> PackedFloat32Array:
	var length := 40.0
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		# two low notes a semitone apart beating against each other, a hollow fifth, and a thin high whine
		var swell := 0.6 + 0.4 * sin(TAU * t / length)
		var v := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 58.27 * t) * 0.35 + sin(TAU * 82.4 * t) * 0.18
		v += sin(TAU * 1396.9 * t) * 0.025 * (0.5 + 0.5 * sin(TAU * t / 10.0))
		lp += (_noise() - lp) * 0.01
		v += lp * 0.6
		buf[i] = v * 0.14 * swell
	return buf


var _oneshots := {}

## A stream for one-shot use: looping streams (grind, motor, static...) play through once.
func _oneshot(name: String) -> AudioStream:
	if not _oneshots.has(name):
		var st: AudioStream = streams[name]
		if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
			st = st.duplicate()
			(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_oneshots[name] = st
	return _oneshots[name]


## Play a non-positional one-shot (footsteps, page, chime...).
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(name):
		return
	var p := _foley_pool[_next_foley]
	_next_foley = (_next_foley + 1) % _foley_pool.size()
	p.stream = _oneshot(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Play a positional one-shot somewhere in the world.
func play_at(name: String, parent: Node, position: Vector3, volume_db := 0.0, max_distance := 40.0, pitch := 1.0) -> void:
	if not streams.has(name) or parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _oneshot(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.unit_size = 6.0
	parent.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()


static func _looping(st: AudioStream) -> AudioStream:
	if st is AudioStreamMP3 and not st.loop:
		st = st.duplicate()
		st.loop = true
	return st


## A looping ambient player. 3D if positional.
func make_loop(name: String, positional: bool, volume_db := 0.0, max_distance := 30.0) -> Node:
	var p: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = max_distance
		p3.unit_size = 5.0
		p3.volume_db = volume_db
		p3.autoplay = true
		p3.stream = _looping(streams.get(name))
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.volume_db = volume_db
		p2.autoplay = true
		p2.stream = _looping(streams.get(name))
		p = p2
	return p


# ------------------------------------------------------------------ synthesis

func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


## Crossfade the end of a noise loop into its start so the wrap is seamless.
func _seam(s: PackedFloat32Array, fade: int) -> void:
	var n := s.size()
	for i in fade:
		var t := float(i) / fade
		s[i] = s[i] * t + s[n - fade + i] * (1.0 - t)
	s.resize(n - fade)


func _build_all() -> void:
	var t0 := Time.get_ticks_msec()
	streams["room_tone"] = _to_wav(_room_tone(4.0), true)
	streams["city"] = _to_wav(_city(6.0), true)
	streams["water"] = _to_wav(_water(3.0), true)
	streams["hum"] = _to_wav(_hum(2.0), true)
	streams["drone"] = _to_wav(_drone(6.0), true)
	for surface in ["concrete", "wood", "carpet", "grass", "metal", "wet", "gravel"]:
		for v in 4:
			streams["step_%s_%d" % [surface, v]] = _to_wav(_footstep(surface, v), false)
	streams["knock"] = _to_wav(_knock(), false)
	streams["thud"] = _to_wav(_thud(), false)
	streams["chime"] = _to_wav(_chime(), false)
	streams["page"] = _to_wav(_page(), false)
	streams["whoosh"] = _to_wav(_whoosh(), false)
	streams["bite"] = _to_wav(_bite(), false)
	streams["chirp"] = _to_wav(_chirps(), false)
	streams["static"] = _to_wav(_static(2.0), true)
	streams["static_burst"] = _to_wav(_static(0.9), false)   # one-shot (the looping one would never stop)
	streams["water_lap"] = _to_wav(_water_lap(5.0), true)
	streams["gurgle"] = _to_wav(_gurgle(3.0), true)
	streams["drip"] = _to_wav(_drip(), false)
	streams["ring"] = _to_wav(_ring(), false)
	streams["splash"] = _to_wav(_splash(), false)
	streams["wind"] = _to_wav(_wind(8.0), true)
	streams["grind"] = _to_wav(_grind(2.0), true)
	streams["breath"] = _to_wav(_breath(4.0), true)
	streams["creak"] = _to_wav(_creak(), false)
	# horror cues and events
	streams["screech"] = _to_wav(_screech(), false)
	streams["jumpscare"] = _to_wav(_jumpscare(), false)
	streams["braam"] = _to_wav(_braam(), false)
	streams["riser"] = _to_wav(_riser(), false)
	streams["hit"] = _to_wav(_hit(), false)
	streams["sub_drop"] = _to_wav(_sub_drop(), false)
	streams["whisper"] = _to_wav(_whisper(), false)
	streams["scream_far"] = _to_wav(_scream_far(), false)
	streams["door_creak"] = _to_wav(_door_creak(), false)
	streams["metal_screech"] = _to_wav(_metal_screech(), false)
	streams["scrape"] = _to_wav(_scrape(), false)
	streams["heartbeat"] = _to_wav(_heartbeat(), false)
	streams["bubbles"] = _to_wav(_bubbles(), false)
	streams["glitch"] = _to_wav(_glitch(), false)
	streams["switch"] = _to_wav(_switch(), false)
	streams["ding"] = _to_wav(_ding(), false)
	streams["musicbox"] = _to_wav(_musicbox(), false)
	streams["splash_big"] = _to_wav(_splash_big(), false)
	streams["underwater"] = _to_wav(_underwater(6.0), true)
	streams["buzz"] = _to_wav(_buzz(2.0), true)
	streams["motor"] = _to_wav(_motor(3.0), true)
	streams["piston_slam"] = _to_wav(_piston_slam(), false)
	streams["stalker_step"] = _to_wav(_stalker_step(), false)
	streams["wall_grip"] = _to_wav(_wall_grip(), false)
	streams["stalker_rasp"] = _to_wav(_stalker_rasp(3.6), true)
	streams["gate_slam"] = _to_wav(_gate_slam(), false)
	streams["bars_rattle"] = _to_wav(_bars_rattle(), false)
	print("Sfx: synthesized %d sounds in %d ms" % [streams.size(), Time.get_ticks_msec() - t0])
	_load_recorded()


## Recorded sounds (assets/audio). A name already synthesized ("hit") is replaced by the recording;
## if a file is missing, the synthesized one stays.
const RECORDED := {
	"hit": "res://assets/audio/impact_hit.mp3",                  # a real horror impact
	"siren": "res://assets/audio/air_raid_siren.mp3",            # the Backrooms chase; the dark coming back in BLACKOUT
	"horror_swell": "res://assets/audio/horror_swell.mp3",       # reveals: the family at the table, the chart in Ward 6
	"dark_soundscape": "res://assets/audio/dark_soundscape.mp3", # the hive; the plaza
	"underwater_deep": "res://assets/audio/underwater_deep.mp3", # THE DEEP's seabed and abyss (loops)
}
const RECORDED_MUSIC := {"suspense": "res://assets/audio/suspense_cue.mp3"}


func _load_recorded() -> void:
	for k in RECORDED:
		var st = load(RECORDED[k])
		if st is AudioStream:
			streams[k] = st
	for k in RECORDED_MUSIC:
		var m = load(RECORDED_MUSIC[k])
		if m is AudioStreamMP3:
			m = m.duplicate()
			m.loop = true
			music[k] = m


func _room_tone(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 2000)
	var brown := 0.0
	for i in s.size():
		var t := float(i) / RATE
		brown = (brown + _noise() * 0.02) * 0.998
		s[i] = brown * 0.25 + sin(TAU * 110.0 * t) * 0.006 + sin(TAU * 220.0 * t) * 0.003
	_seam(s, 2000)
	return s


func _city(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 4000)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp1 += (_noise() - lp1) * 0.03
		lp2 += (lp1 - lp2) * 0.08
		var swell := 0.7 + 0.3 * sin(TAU * t / sec)
		s[i] = lp2 * 1.6 * swell
	_seam(s, 4000)
	return s


func _water(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 2000)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var x := _noise()
		lp += (x - lp) * 0.3
		var flutter := 0.7 + 0.3 * sin(TAU * 3.0 * t) * sin(TAU * 0.67 * t)
		s[i] = (x - lp) * 0.22 * flutter
	_seam(s, 2000)
	return s


func _hum(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)  # 2s * 120Hz = whole cycles: seamless
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var base := sin(TAU * 120.0 * t)
		var h := base * 0.5 + sin(TAU * 240.0 * t) * 0.3 + sin(TAU * 360.0 * t) * 0.15
		h += clampf(base * 4.0, -1.0, 1.0) * 0.08
		s[i] = h * 0.18 + (_noise() * 0.6 if _rng.randf() < 0.00008 else 0.0)
	return s


func _drone(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.006
		# frequencies chosen as multiples of 1/sec so the loop wraps cleanly
		var d := sin(TAU * 55.0 * t) + sin(TAU * (55.0 + 1.0 / sec * 4.0) * t) * 0.8 + sin(TAU * 82.5 * t) * 0.35
		s[i] = d * 0.12 + lp * 0.8
	return s


func _env_noise(dur: float, decay: float, smooth: float, gain: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 0.0
	for i in n:
		var t := float(i) / RATE
		f += (_noise() - f) * smooth
		s[i] = f * exp(-t * decay) * gain
	return s


## A footstep: heel thump + a surface-specific scuff, with per-variant randomness so no two match.
func _footstep(surface: String, variant: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(surface) + variant * 7919
	var dur := 0.26
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var thump_f := r.randf_range(70.0, 95.0)
	var res_f := r.randf_range(260.0, 340.0)
	var lp := 0.0
	var lp2 := 0.0
	var hp_prev := 0.0
	var heel_to_toe := r.randf_range(0.035, 0.06)   # second, softer contact
	for i in n:
		var t := float(i) / RATE
		var x := r.randf() * 2.0 - 1.0
		var v := 0.0
		match surface:
			"gravel":
				# a crunch: a dull press, then a scatter of little stones shifting under the sole
				lp += (x - lp) * 0.35
				v += sin(TAU * thump_f * 0.9 * t) * exp(-t * 40.0) * 0.35
				var grains := 0.0
				if r.randf() < 0.035 * exp(-t * 9.0):
					grains = (r.randf() * 2.0 - 1.0) * 1.6
				v += (x - lp) * exp(-t * 18.0) * 0.35 + grains
			"concrete":
				# firm heel click + gritty scrape
				lp += (x - lp) * 0.5
				var hp := x - lp
				v += sin(TAU * thump_f * t) * exp(-t * 55.0) * 0.55
				v += hp * exp(-t * 140.0) * 0.9
				var t2 := t - heel_to_toe
				if t2 > 0.0:
					v += hp * exp(-t2 * 60.0) * 0.35 + sin(TAU * thump_f * 1.3 * t2) * exp(-t2 * 70.0) * 0.25
			"wood":
				# hollow floorboard knock with a little creak resonance
				lp += (x - lp) * 0.3
				v += sin(TAU * thump_f * 1.4 * t) * exp(-t * 35.0) * 0.6
				v += sin(TAU * res_f * t) * exp(-t * 45.0) * 0.25
				v += (x - lp) * exp(-t * 160.0) * 0.5
				var t2 := t - heel_to_toe
				if t2 > 0.0:
					v += sin(TAU * res_f * 1.1 * t2) * exp(-t2 * 55.0) * 0.15
			"carpet":
				# muffled: low thud and a soft fabric brush, almost no highs
				lp += (x - lp) * 0.06
				lp2 += (lp - lp2) * 0.2
				v += sin(TAU * thump_f * 0.85 * t) * exp(-t * 38.0) * 0.6
				v += lp2 * 6.0 * exp(-t * 22.0) * minf(1.0, t * 120.0)
			"metal":
				# a steel beam or grating: a dull clang that rings on
				lp += (x - lp) * 0.4
				v += sin(TAU * thump_f * 1.6 * t) * exp(-t * 30.0) * 0.4
				v += (sin(TAU * 1230.0 * t) * 0.5 + sin(TAU * 1870.0 * t) * 0.3 + sin(TAU * 2950.0 * t) * 0.2) * exp(-t * 11.0) * 0.18
				v += (x - lp) * exp(-t * 120.0) * 0.4
			"wet":
				# bare feet on wet tile: a slap and a little squelch
				lp += (x - lp) * 0.35
				v += (x - lp) * exp(-t * 70.0) * 0.8 + sin(TAU * thump_f * 1.2 * t) * exp(-t * 60.0) * 0.4
				var t2 := t - heel_to_toe * 1.4
				if t2 > 0.0:
					v += sin(TAU * (500.0 - t2 * 900.0) * t2) * exp(-t2 * 40.0) * 0.12
			"grass":
				# crunchy grains
				lp += (x - lp) * 0.6
				var grain := (x - lp) if r.randf() < 0.25 else 0.0
				v += grain * exp(-t * 18.0) * 0.7 + sin(TAU * thump_f * t) * exp(-t * 50.0) * 0.35
		s[i] = v * 0.7
	return s


func _knock() -> PackedFloat32Array:
	var n := int(0.95 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for st in [0.0, 0.3, 0.58]:
			var k: float = t - st
			if k >= 0.0 and k < 0.25:
				v += sin(TAU * 95.0 * k) * exp(-k * 26.0) + _noise() * exp(-k * 120.0) * 0.4
		s[i] = v * 0.7
	return s


func _thud() -> PackedFloat32Array:
	var n := int(1.3 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 0.0
	for i in n:
		var t := float(i) / RATE
		f += (_noise() - f) * 0.08
		s[i] = sin(TAU * 48.0 * t) * exp(-t * 5.0) * 0.8 + f * exp(-t * 12.0) * 1.3
	return s


func _chime() -> PackedFloat32Array:
	var n := int(1.8 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 80.0) * exp(-t * 2.4)
		s[i] = (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1318.5 * t) + 0.4 * sin(TAU * 1760.0 * t)) * env * 0.22
	return s


func _page() -> PackedFloat32Array:
	var n := int(0.32 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise()
		f += (x - f) * 0.35
		s[i] = (x - f) * sin(PI * t / 0.32) * 0.35
	return s


func _whoosh() -> PackedFloat32Array:
	var dur := 2.4
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 0.0
	for i in n:
		var t := float(i) / RATE
		f += (_noise() - f) * (0.01 + 0.25 * t / dur)
		s[i] = f * sin(PI * t / dur) * 1.4
	return s


func _bite() -> PackedFloat32Array:
	var n := int(0.14 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var on := 1.0 if (t < 0.05 or (t > 0.07 and t < 0.12)) else 0.0
		s[i] = _noise() * on * 0.3
	return s


## Digital crackle: gated bursts of noise and a thin buzzing tone.
func _static(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var gate := 0.0
	var hold := 0
	for i in n:
		if hold <= 0:
			gate = 1.0 if _rng.randf() < 0.35 else 0.15
			hold = _rng.randi_range(200, 2400)
		hold -= 1
		var t := float(i) / RATE
		var buzz := signf(sin(TAU * 60.0 * t)) * 0.08
		s[i] = (_noise() * 0.35 + buzz) * gate
	return s


func _water_lap(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 3000)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.05
		lp2 += (lp - lp2) * 0.1
		var lap := maxf(0.0, sin(TAU * t * 0.7)) * maxf(0.0, sin(TAU * t * 0.23 + 1.0))
		s[i] = lp2 * (0.6 + 2.2 * lap)
	_seam(s, 3000)
	return s


func _gurgle(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 2000)
	var lp := 0.0
	var bubble_f := 300.0
	var bubble_t := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.02
		bubble_t -= 1.0 / RATE
		if bubble_t <= 0.0:
			bubble_t = _rng.randf_range(0.03, 0.15)
			bubble_f = _rng.randf_range(150.0, 500.0)
		var b := sin(TAU * bubble_f * (1.0 + t * 0.0) * bubble_t * 6.0) * exp(-bubble_t * 4.0)
		s[i] = lp * 2.0 + b * 0.15
	_seam(s, 2000)
	return s


## An office desk phone: a soft electronic trill, twice, then quiet (2.6 s: play it again for the next ring).
func _ring() -> PackedFloat32Array:
	var n := int(2.6 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := 0.0
		if t < 0.9 or (t > 1.15 and t < 2.05):
			var f := 1180.0 if int(t * 22.0) % 2 == 0 else 940.0
			ph += TAU * f / RATE
			var tt := t if t < 1.0 else t - 1.15
			var env := minf(1.0, tt * 80.0) * minf(1.0, (0.9 - tt) * 80.0)
			x = (sin(ph) * 0.6 + sin(ph * 2.0) * 0.1) * 0.3 * env
		lp += (x - lp) * 0.35      # (a small, plastic speaker)
		s[i] = lp
	return s


func _drip() -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var f0 := _rng.randf_range(900.0, 1400.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (f0 + 1400.0 * minf(t, 0.03) / 0.03) / RATE
		var hit := sin(phase) * exp(-t * 35.0) * 0.5
		# a long, hollow echo
		var echo: float = sin(phase * 0.5) * exp(-maxf(0.0, t - 0.18) * 9.0) * 0.15 * (1.0 if t > 0.18 else 0.0)
		s[i] = hit + echo
	return s


func _splash() -> PackedFloat32Array:
	var n := int(0.8 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise()
		lp += (x - lp) * (0.4 - t * 0.4)
		s[i] = lp * exp(-t * 5.0) * 0.9
	return s


func _chirps() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for c in 3:
		var start := int(c * 0.14 * RATE)
		var f0 := 2600.0 + _rng.randf() * 1500.0
		var phase := 0.0
		var dur := 0.08
		for i in int(dur * RATE):
			var t := float(i) / RATE
			phase += TAU * (f0 + 1400.0 * t / dur) / RATE
			if start + i < n:
				s[start + i] += sin(phase) * sin(PI * t / dur) * 0.18
	return s


## Wind high up: band-limited noise with slow gusting swells and a thin whistle.
func _wind(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 4000)
	var lp := 0.0
	var bp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.03
		bp += (lp - bp) * 0.2
		var swell := 0.55 + 0.45 * sin(TAU * t / sec * 2.0) * sin(TAU * t / sec * 3.0 + 1.0)
		var whistle := sin(TAU * (700.0 + 120.0 * sin(TAU * t / sec)) * t) * 0.02 * swell * swell
		s[i] = (lp * 0.9 + (lp - bp) * 1.5) * swell + whistle
	_seam(s, 4000)
	return s


## Concrete walls grinding along a floor.
func _grind(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 2000)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.08
		var stutter := 0.6 + 0.4 * absf(sin(TAU * 7.0 * t + sin(TAU * 1.5 * t) * 2.0))
		s[i] = (lp * 0.7 + sin(TAU * 38.0 * t) * 0.25) * stutter
	_seam(s, 2000)
	return s


## Someone breathing, close, in the dark: slow filtered-noise inhale/exhale.
func _breath(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var ph := fmod(t, sec * 0.5) / (sec * 0.5)
		var env := sin(PI * clampf(ph / 0.45, 0.0, 1.0)) if ph < 0.45 else sin(PI * clampf((ph - 0.5) / 0.4, 0.0, 1.0)) * 0.8
		env = maxf(env, 0.0)
		lp += (_noise() - lp) * (0.12 if ph < 0.5 else 0.07)
		s[i] = lp * env * 0.6
	return s


## A long wooden/metal creak.
func _creak() -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 90.0 + 60.0 * sin(t * 5.0) + 30.0 * _rng.randf()
		ph += f / RATE
		var pulse := 1.0 if fmod(ph, 1.0) < 0.08 else 0.0
		s[i] = (pulse * 0.5 + _noise() * 0.05) * sin(PI * t / 0.9)
	return s


# ------------------------------------------------------------------ horror cues and event sounds

func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * RATE))
	return s


## Strings scraped hard, a cluster sliding up: the classic stinger.
func _screech() -> PackedFloat32Array:
	var s := _buf(2.4)
	var ph := [0.0, 0.0, 0.0, 0.0, 0.0]
	var base := [880.0, 932.0, 1245.0, 1318.0, 1760.0]
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 30.0) * exp(-t * 1.4)
		var v := 0.0
		for k in 5:
			var f: float = base[k] * (1.0 + 0.18 * t) * (1.0 + 0.006 * sin(TAU * 6.0 * t + k))
			ph[k] = fmod(ph[k] + f / RATE, 1.0)
			v += (ph[k] * 2.0 - 1.0) * 0.18           # saw: bowed string
		v += _noise() * 0.25 * exp(-t * 4.0)           # bow noise
		s[i] = clampf(v * env * 1.4, -1.0, 1.0) * 0.8
	return s


## The jumpscare: a slam, then a shriek that stutters like the flashing - clustered saws with wild vibrato,
## sliding up and falling away, noise tearing through it, everything clipped hard.
func _jumpscare() -> PackedFloat32Array:
	var s := _buf(2.0)
	var ph := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var base := [523.0, 554.0, 740.0, 784.0, 1046.0, 1480.0]
	var boom_ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var slide := 1.0 + 0.5 * minf(t / 0.35, 1.0) - 0.45 * maxf(t - 1.2, 0.0)
		var v := 0.0
		for k in 6:
			var f: float = base[k] * slide * (1.0 + 0.035 * sin(TAU * (9.0 + k) * t + k * 1.7))
			ph[k] = fmod(ph[k] + f / RATE, 1.0)
			v += (ph[k] * 2.0 - 1.0) * 0.2
		v += _noise() * (0.55 * exp(-t * 6.0) + 0.18)
		var stutter := 0.55 + 0.45 * signf(sin(TAU * 17.0 * t))
		var env := minf(1.0, t * 80.0) * (1.0 if t < 1.4 else exp(-(t - 1.4) * 6.0))
		boom_ph = fmod(boom_ph + (55.0 * exp(-t * 3.0) + 30.0) / RATE, 1.0)
		var boom := sin(TAU * boom_ph) * exp(-t * 5.0) * 1.4
		s[i] = clampf(tanh((v * stutter * env + boom) * 2.6), -1.0, 1.0) * 0.95
	return s


## The low brass "BRAAM": detuned saws through a closing filter, overdriven.
func _braam() -> PackedFloat32Array:
	var s := _buf(3.5)
	var ph := [0.0, 0.0, 0.0, 0.0]
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in 4:
			ph[k] = fmod(ph[k] + (43.65 * (1.0 + k * 0.004) * (2.0 if k == 3 else 1.0)) / RATE, 1.0)
			v += ph[k] * 2.0 - 1.0
		var cutoff := 0.02 + 0.25 * exp(-t * 2.5)
		lp += (v * 0.3 - lp) * cutoff
		s[i] = tanh(lp * 3.0) * minf(1.0, t * 12.0) * exp(-t * 0.9) * 0.9
	return s


## Noise and a tone rising to a cut: tension before something happens.
func _riser() -> PackedFloat32Array:
	var s := _buf(3.0)
	var ph := 0.0
	var bp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / 3.0
		ph += (200.0 + 1800.0 * k * k) / RATE
		bp += (_noise() - bp) * (0.05 + 0.4 * k)
		s[i] = (sin(TAU * ph) * 0.25 + bp * 0.9) * k * k * 0.9
	return s


## A jump-scare impact: transient crack, body boom and a ringing tail.
func _hit() -> PackedFloat32Array:
	var s := _buf(2.2)
	for i in s.size():
		var t := float(i) / RATE
		var boom := sin(TAU * (60.0 - 25.0 * t) * t) * exp(-t * 3.0)
		var crack := _noise() * exp(-t * 60.0)
		var ring := (sin(TAU * 523.0 * t) + sin(TAU * 554.0 * t) * 0.7 + sin(TAU * 1108.0 * t) * 0.3) * exp(-t * 2.2) * 0.15
		s[i] = clampf((boom * 0.9 + crack * 0.8 + ring), -1.0, 1.0)
	return s


func _sub_drop() -> PackedFloat32Array:
	var s := _buf(2.5)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += (80.0 * exp(-t * 1.2) + 22.0) / RATE
		s[i] = sin(TAU * ph) * minf(1.0, t * 20.0) * exp(-t * 0.8) * 0.95
	return s


## Breathy syllables with no words in them.
func _whisper() -> PackedFloat32Array:
	var s := _buf(2.6)
	var bp := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var syl := maxf(0.0, sin(TAU * 3.1 * t + sin(TAU * 0.7 * t) * 2.0))
		var center := 0.15 + 0.12 * sin(TAU * 1.9 * t)
		lp += (_noise() - lp) * center
		bp += (lp - bp) * 0.5
		s[i] = (lp - bp) * syl * syl * minf(1.0, t * 4.0) * minf(1.0, (2.6 - t) * 3.0) * 2.2
	return s


## Far away, someone: a falling, formant-shaped wail.
func _scream_far() -> PackedFloat32Array:
	var s := _buf(3.0)
	var ph := 0.0
	var f1 := 0.0
	var f2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var pitch := 620.0 - 180.0 * t + 25.0 * sin(TAU * 5.5 * t)
		ph += pitch / RATE
		var src := (fmod(ph, 1.0) * 2.0 - 1.0) + _noise() * 0.3
		f1 += (src - f1) * 0.18
		f2 += (f1 - f2) * 0.35
		s[i] = (f1 - f2 * 0.6) * minf(1.0, t * 3.0) * exp(-t * 0.9) * 0.6
	return s


func _door_creak() -> PackedFloat32Array:
	var s := _buf(1.8)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 70.0 + 50.0 * sin(t * 3.0) + 40.0 * sin(t * 11.0) * sin(t * 2.0)
		ph += f / RATE
		var stick := 1.0 if fmod(ph, 1.0) < 0.06 else 0.0
		s[i] = (stick * 0.6 + _noise() * 0.04) * sin(PI * t / 1.8)
	return s


func _metal_screech() -> PackedFloat32Array:
	var s := _buf(2.2)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 2100.0 + 600.0 * sin(TAU * 0.6 * t) + 90.0 * sin(TAU * 13.0 * t)
		ph += f / RATE
		var v := sin(TAU * ph) * 0.5 + sin(TAU * ph * 1.51) * 0.25 + _noise() * 0.15
		s[i] = v * sin(PI * t / 2.2) * 0.6
	return s


func _scrape() -> PackedFloat32Array:
	var s := _buf(1.6)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.12
		var judder := 0.5 + 0.5 * absf(sin(TAU * 9.0 * t + sin(TAU * 2.0 * t)))
		s[i] = lp * judder * sin(PI * t / 1.6) * 1.6
	return s


func _heartbeat() -> PackedFloat32Array:
	var s := _buf(0.7)
	for i in s.size():
		var t := float(i) / RATE
		var a := sin(TAU * 55.0 * t) * exp(-t * 22.0)
		var t2 := t - 0.2
		var b: float = sin(TAU * 48.0 * t2) * exp(-t2 * 26.0) * 0.7 if t2 > 0.0 else 0.0
		s[i] = (a + b) * 0.9
	return s


func _bubbles() -> PackedFloat32Array:
	var s := _buf(1.4)
	var next := 0.0
	var f := 600.0
	var bt := 0.0
	for i in s.size():
		var t := float(i) / RATE
		if t >= next:
			next = t + _rng.randf_range(0.02, 0.12)
			f = _rng.randf_range(350.0, 1200.0)
			bt = t
		var lt := t - bt
		s[i] = sin(TAU * f * (1.0 + lt * 4.0) * lt) * exp(-lt * 35.0) * 0.45 * (1.0 - t / 1.4)
	return s


func _glitch() -> PackedFloat32Array:
	var s := _buf(0.6)
	var hold := 0.0
	var v := 0.0
	for i in s.size():
		var t := float(i) / RATE
		if _rng.randf() < 0.004:
			hold = _rng.randf_range(-0.8, 0.8)
		v = hold if _rng.randf() < 0.7 else _noise()
		s[i] = (v * 0.6 + sin(TAU * 60.0 * t) * 0.2 * sign(sin(TAU * 7.0 * t))) * (1.0 - t / 0.6)
	return s


func _switch() -> PackedFloat32Array:
	var s := _buf(0.5)
	for i in s.size():
		var t := float(i) / RATE
		var t2 := t - 0.05
		s[i] = (_noise() * exp(-t * 200.0) + sin(TAU * 140.0 * t) * exp(-t * 40.0) * 0.6
			+ (sin(TAU * 220.0 * t2) * exp(-t2 * 30.0) * 0.5 if t2 > 0.0 else 0.0)) * 0.8
	return s


func _ding() -> PackedFloat32Array:
	var s := _buf(2.0)
	for i in s.size():
		var t := float(i) / RATE
		var a := (sin(TAU * 1046.0 * t) + sin(TAU * 2093.0 * t) * 0.3) * exp(-t * 3.0)
		var t2 := t - 0.35
		var b: float = (sin(TAU * 784.0 * t2) + sin(TAU * 1568.0 * t2) * 0.3) * exp(-t2 * 2.5) if t2 > 0.0 else 0.0
		s[i] = (a + b) * 0.3
	return s


func _splash_big() -> PackedFloat32Array:
	var s := _buf(1.8)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * (0.4 * exp(-t * 2.0) + 0.05)
		s[i] = (lp * 1.4 * exp(-t * 2.2) + sin(TAU * 70.0 * t) * exp(-t * 12.0) * 0.6) * minf(1.0, t * 80.0)
	return s


## Under water: pressure, a deep slow swell, the odd far-off creak of something enormous.
func _underwater(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 3000)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.008
		var swell := 0.6 + 0.4 * sin(TAU * t / sec)
		s[i] = lp * 3.5 * swell + sin(TAU * 32.0 * t) * 0.08
	_seam(s, 3000)
	return s


## Old electrics: 60 Hz hum with harmonics and an irregular crackle.
func _buzz(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var hum: float = sin(TAU * 60.0 * t) * 0.3 + sin(TAU * 120.0 * t) * 0.25 + sign(sin(TAU * 180.0 * t)) * 0.06
		var crack: float = _noise() * 0.6 if _rng.randf() < 0.002 else 0.0
		s[i] = (hum + crack) * 0.4
	return s


func _motor(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE)
	var s := PackedFloat32Array()
	s.resize(n + 2000)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.03
		s[i] = (sin(TAU * 98.0 * t) * 0.2 + sin(TAU * 196.0 * t) * 0.1 + lp * 0.8) * 0.6
	_seam(s, 2000)
	return s


## A horror cue, slightly varied each time so repeats don't sound identical.
func stinger(name: String, volume_db := 0.0) -> void:
	play(name, volume_db + linear_to_db(maxf(Settings.audio_intensity, 0.05)), randf_range(0.94, 1.06))


# ------------------------------------------------------------------ the Backrooms chase

const CHASE_BPM := 150.0
const CHASE_BEAT := 60.0 / CHASE_BPM          # 0.4 s
const SLAM_IMPACT := 0.2                       # piston_slam: the wall lands this long after the sound starts


## Where the chase track is, in seconds (or -1 if it isn't what's playing).
func music_pos(track: String) -> float:
	if _music_target_name != track:
		return -1.0
	var p := _music_players[_music_current]
	if not p.playing:
		return -1.0
	return p.get_playback_position() + AudioServer.get_time_since_last_mix()


## Two-pole resonator (a formant): returns the new [y1, y2]; out in y1.
static func _reso(x: float, st: Array, f: float, bw: float) -> float:
	var r := exp(-PI * bw / RATE)
	var b := 2.0 * r * cos(TAU * f / RATE)
	var c := -r * r
	var y := (1.0 - b - c) * x + b * float(st[0]) + c * float(st[1])
	st[1] = st[0]
	st[0] = y
	return y


## The cockpit voice: "STALL". Flat, male, through a small speaker. Formant synthesis.
static func _stall_voice(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.56 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var f1 := [0.0, 0.0]
	var f2 := [0.0, 0.0]
	var f3 := [0.0, 0.0]
	var hs := [0.0, 0.0]
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		if t < 0.13:
			# "s": hiss, high-passed
			var x := rng.randf() * 2.0 - 1.0
			var hi := x - prev
			prev = x
			v = _reso(hi, hs, 5200.0, 2200.0) * 1.6 * minf(1.0, t * 60.0) * minf(1.0, (0.13 - t) * 50.0)
		elif t >= 0.155 and t < 0.175:
			# "t": the release
			v = (rng.randf() * 2.0 - 1.0) * 0.5 * exp(-(t - 0.155) * 200.0)
		elif t >= 0.17:
			# "aw" gliding into "l": a buzz through the vocal tract
			var u := t - 0.17
			var f0 := 118.0 - 14.0 * u
			ph = fmod(ph + f0 / RATE, 1.0)
			var src := (1.0 - ph * 2.0) * 0.6 + (0.25 if ph < 0.08 else 0.0)
			var into_l := smoothstep(0.24, 0.32, u)
			var F1 := lerpf(640.0, 360.0, into_l)
			var F2 := lerpf(950.0, 1050.0, into_l)
			var F3 := lerpf(2500.0, 2800.0, into_l)
			v = _reso(src, f1, F1, 90.0) * 1.0 + _reso(src, f2, F2, 110.0) * 0.6 + _reso(src, f3, F3, 160.0) * 0.25
			v *= minf(1.0, u * 40.0) * (1.0 - smoothstep(0.30, 0.39, u)) * lerpf(1.0, 0.55, into_l)
		# the speaker: no lows, a bit of crunch
		hp += (v - hp) * 0.06
		s[i] = tanh((v - hp) * 2.2) * 0.8
	return s


## The chase: 150 bpm, 16 bars. Drums, a driving bass, an air-raid siren, an alarm whoop, and the stall
## warning (the cricket, then "STALL, STALL") every few bars.
func _track_chase() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var beat := CHASE_BEAT
	var bars := 16
	var n := int(beat * 4.0 * bars * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var bass_notes := [33, 33, 34, 32, 33, 33, 36, 35]      # A1, A1, Bb1, Ab1, ... one per bar, cycling
	var bph := [0.0, 0.0, 0.0]
	var blp := 0.0
	var sir_ph := 0.0
	var wh_ph := 0.0
	var hat_hp := 0.0
	var hat_prev := 0.0
	var sn_lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var bt := t / beat                     # in beats
		var b := int(bt)
		var fb := bt - b                       # within the beat
		var bar := b / 4
		var v := 0.0
		# kick, every beat
		var kt := fb * beat
		v += sin(TAU * (48.0 * kt + 90.0 * (1.0 - exp(-kt * 28.0)) / 28.0)) * exp(-kt * 9.0) * 0.9
		# snare on 2 and 4 (and a fill at the end of every 4th bar)
		var x := rng.randf() * 2.0 - 1.0
		var snare_on := (b % 4 == 1 or b % 4 == 3)
		var st := kt
		if bar % 4 == 3 and b % 4 >= 2:
			snare_on = true
			st = fmod(t, beat * 0.25)
		if snare_on:
			sn_lp += (x - sn_lp) * 0.5
			v += (sn_lp * 0.7 + sin(TAU * 190.0 * st) * 0.3) * exp(-st * 22.0) * 0.55
		# hats: 16ths, open on the off-beat
		var ht := fmod(t, beat * 0.25)
		var hi := x - hat_prev
		hat_prev = x
		hat_hp += (hi - hat_hp) * 0.7
		var open := int(bt * 4.0) % 4 == 2
		v += hat_hp * exp(-ht * (18.0 if open else 70.0)) * 0.16
		# bass: 8ths, a dirty saw, octave jump on the last 8th
		var note: int = bass_notes[bar % bass_notes.size()]
		var e8 := int(bt * 2.0) % 8
		if e8 == 7:
			note += 12
		var f := _hz(note)
		var bv := 0.0
		for k in 3:
			bph[k] = fmod(bph[k] + f * (1.0 + k * 0.007) / RATE, 1.0)
			bv += bph[k] * 2.0 - 1.0
		var et := fmod(t, beat * 0.5)
		blp += (bv * 0.33 - blp) * (0.04 + 0.2 * exp(-et * 14.0))
		v += tanh(blp * 2.5) * 0.42 * (1.0 - exp(-et * 200.0)) * exp(-et * 2.0)
		# air-raid siren: wails up and down over four bars, always there
		var sw := 0.5 - 0.5 * cos(TAU * t / (beat * 16.0))
		var sf := 420.0 + 560.0 * sw
		sir_ph = fmod(sir_ph + sf / RATE, 1.0)
		var siren := sin(TAU * sir_ph) + 0.35 * sin(TAU * sir_ph * 2.0) + 0.2 * sin(TAU * sir_ph * 3.0)
		v += siren * 0.075 * (0.6 + 0.4 * sw)
		# alarm whoop (bars 9-16): a rising tone, twice a bar
		if bar >= 8:
			var wt := fmod(t, beat * 2.0)
			var wf := 500.0 + 900.0 * minf(wt / (beat * 1.6), 1.0)
			wh_ph = fmod(wh_ph + wf / RATE, 1.0)
			var sq := 1.0 if wh_ph < 0.5 else -1.0
			v += sq * 0.05 * (1.0 if wt < beat * 1.6 else 0.0)
		# stab on the one of every bar
		if b % 4 == 0:
			v += sin(TAU * _hz(note + 24) * kt) * exp(-kt * 6.0) * 0.18
		buf[i] = v * 0.62
	# the stall warning: the cricket (bars 4, 8, 12, 16 beat 1-2), then the voice on beats 3 and 4
	var voice := _stall_voice(rng)
	for bar in [3, 7, 11, 15]:
		var t0: float = bar * 4.0 * beat
		var cn := int(beat * 2.0 * RATE)
		for i in cn:
			var t := float(i) / RATE
			var chirp := fmod(t, 0.1) < 0.035
			var env := 1.0 if chirp else 0.0
			var k := int(t0 * RATE) + i
			if k < n:
				buf[k] += sin(TAU * 2800.0 * t) * sin(TAU * 3100.0 * t) * env * 0.16
		for rep in 2:
			var k0 := int((t0 + beat * (2.0 + rep)) * RATE)
			for i in voice.size():
				if k0 + i < n:
					buf[k0 + i] += voice[i] * 0.55
	for i in n:
		buf[i] = clampf(tanh(buf[i] * 1.3), -1.0, 1.0)
	return buf


## A wall dropping on a machine: a ratchet, a hiss of air, then (at SLAM_IMPACT) a steel-on-steel impact.
func _piston_slam() -> PackedFloat32Array:
	var s := _buf(1.4)
	var hp := 0.0
	var prev := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		var x := _noise()
		# ratchet: clicks, faster and faster
		if t < SLAM_IMPACT:
			var rate := 30.0 + 120.0 * t / SLAM_IMPACT
			var c := fmod(t * rate, 1.0)
			v += x * exp(-c * 40.0) * 0.45
			# pneumatic hiss
			var hi := x - prev
			hp += (hi - hp) * 0.4
			v += hp * 0.25 * t / SLAM_IMPACT
		prev = x
		if t >= SLAM_IMPACT:
			var u := t - SLAM_IMPACT
			var clang := sin(TAU * 173.0 * u) * 0.5 + sin(TAU * 431.0 * u) * 0.35 + sin(TAU * 797.0 * u) * 0.25 + sin(TAU * 1523.0 * u) * 0.12
			v += clang * exp(-u * 7.0) * 0.8
			v += sin(TAU * (55.0 * u + 60.0 * (1.0 - exp(-u * 20.0)) / 20.0)) * exp(-u * 8.0) * 1.0   # the thump
			v += x * exp(-u * 45.0) * 0.9                                                           # the crack
			# a bolt shooting home a moment later
			if u > 0.12:
				v += x * exp(-(u - 0.12) * 120.0) * 0.4 + sin(TAU * 2100.0 * u) * exp(-(u - 0.12) * 60.0) * 0.15
		s[i] = clampf(tanh(v * 1.6), -1.0, 1.0) * 0.95
	return s


## Its feet and knuckles: a wet slap with a hollow knock under it.
func _stalker_step() -> PackedFloat32Array:
	var s := _buf(0.22)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.35
		s[i] = (lp * exp(-t * 55.0) * 1.2 + sin(TAU * (90.0 - 120.0 * t) * t) * exp(-t * 30.0) * 0.8) * 0.9
	return s


## A palm slapping the wallpaper, and the nails dragging.
func _wall_grip() -> PackedFloat32Array:
	var s := _buf(0.5)
	var bp := 0.0
	var bp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var x := _noise()
		bp += (x - bp) * 0.5
		var slap := (x - bp) * exp(-t * 70.0) * 1.3
		bp2 += (x - bp2) * 0.15
		var scr := bp2 * (0.5 + 0.5 * sin(TAU * 38.0 * t)) * exp(-maxf(t - 0.06, 0.0) * 8.0) * (1.0 if t > 0.04 else 0.0) * 0.6
		s[i] = clampf(slap + scr, -1.0, 1.0) * 0.85
	return s


## Its breathing, close: a wet rasp, clicking in its throat. Loops.
func _stalker_rasp(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var bp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var cyc := fmod(t, 0.9) / 0.9                     # fast, ragged breaths
		var env := sin(PI * minf(cyc / 0.45, 1.0)) if cyc < 0.45 else 0.55 * sin(PI * (cyc - 0.45) / 0.55)
		bp += (_noise() - bp) * (0.12 if cyc < 0.45 else 0.06)
		var click := 0.0
		var ct := fmod(t, 0.075)
		if cyc > 0.5 and fmod(t * 3.7, 1.0) < 0.5:
			click = _noise() * exp(-ct * 300.0) * 0.8
		var growl := sin(TAU * 62.0 * t) * sin(TAU * 31.0 * t) * 0.4
		s[i] = clampf((bp * 1.6 + growl * 0.4) * env + click, -1.0, 1.0) * 0.7
	_seam(s, 1500)
	return s


## Steel bars dropping into their slots: a ringing clang.
func _gate_slam() -> PackedFloat32Array:
	var s := _buf(2.2)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in 6:
			var f := 210.0 * (1.0 + k * 1.37) * (1.0 + 0.01 * k)
			v += sin(TAU * f * t) * exp(-t * (1.6 + k * 0.9)) / (1.0 + k * 0.6)
		v += _noise() * exp(-t * 40.0) * 0.8 + sin(TAU * 50.0 * t) * exp(-t * 6.0) * 0.8
		s[i] = clampf(tanh(v * 1.2), -1.0, 1.0) * 0.9
	return s


## Something shaking the bars, hard.
func _bars_rattle() -> PackedFloat32Array:
	var s := _buf(0.9)
	for i in s.size():
		var t := float(i) / RATE
		var hit_t := fmod(t, 0.11)
		var v := 0.0
		for k in 4:
			v += sin(TAU * (620.0 + k * 517.0) * hit_t + k) * exp(-hit_t * (30.0 + k * 10.0))
		v += _noise() * exp(-hit_t * 90.0) * 0.6
		s[i] = clampf(v * 0.35 * (1.0 - t / 0.9 * 0.5), -1.0, 1.0)
	return s



## The Emporium's music: cheerful electric piano over a soft bossa, on a tape that's been played too many
## times - it wobbles, and now and then it drags.
func _track_muzak() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var beat := 0.5                     # 120 bpm
	var bars := 8
	var n := int(beat * 4.0 * bars * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# Fmaj7, Em7, Dm7, G7 (twice)
	var chords := [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [43, 53, 59, 62]]
	var roots := [41, 40, 38, 43]
	var melody := [72, 69, 67, 69, 72, 74, 72, 69, 67, 64, 62, 64, 67, 69, 67, 64]
	for i in n:
		var t := float(i) / RATE
		# the tape: a slow wobble in pitch, and a drag every 8 seconds
		var wow := 1.0 + 0.006 * sin(TAU * 0.55 * t) + (-0.03 * smoothstep(0.0, 0.3, fmod(t, 8.0)) * (1.0 - smoothstep(0.3, 0.9, fmod(t, 8.0))))
		var bt := t / beat
		var bar := int(bt / 4.0) % 4
		var fb := fmod(bt, 1.0) * beat
		var v := 0.0
		# chord stabs on 1 and the "and" of 2 (bossa)
		var b4 := fmod(bt, 4.0)
		for hit in [0.0, 1.5, 3.0]:
			if b4 >= hit and b4 < hit + 1.4:
				var u: float = (b4 - hit) * beat
				for m in chords[bar]:
					var f := _hz(m) * wow
					v += (sin(TAU * f * u) + 0.3 * sin(TAU * f * 2.0 * u)) * exp(-u * 3.0) * 0.07
		# bass
		var bu := fmod(bt, 2.0) * beat
		v += sin(TAU * _hz(roots[bar] + (7 if fmod(bt, 4.0) >= 2.0 else 0)) * wow * bu) * exp(-bu * 2.0) * 0.28
		# rimshot and shaker
		var x := rng.randf() * 2.0 - 1.0
		v += x * exp(-fmod(t, beat * 0.5) * 60.0) * 0.05
		if int(bt) % 4 == 3 or int(bt) % 4 == 1:
			v += x * exp(-fb * 90.0) * 0.12
		# the melody: a soft vibraphone, one note per beat
		var mi := int(bt) % melody.size()
		var mf := _hz(melody[mi]) * wow
		v += sin(TAU * mf * fb) * exp(-fb * 2.5) * 0.12 * (1.0 + 0.3 * sin(TAU * 5.0 * t))
		# hiss
		v += x * 0.006
		buf[i] = v * 0.9
	return buf
