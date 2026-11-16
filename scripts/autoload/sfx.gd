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
	_music_thread = Thread.new()
	_music_thread.start(_build_music)


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
	print("Sfx: music generated in %d ms (background thread)" % (Time.get_ticks_msec() - t0))


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


## Play a non-positional one-shot (footsteps, page, chime...).
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(name):
		return
	var p := _foley_pool[_next_foley]
	_next_foley = (_next_foley + 1) % _foley_pool.size()
	p.stream = streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Play a positional one-shot somewhere in the world.
func play_at(name: String, parent: Node, position: Vector3, volume_db := 0.0, max_distance := 40.0) -> void:
	if not streams.has(name) or parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 6.0
	parent.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()


## A looping ambient player. 3D if positional.
func make_loop(name: String, positional: bool, volume_db := 0.0, max_distance := 30.0) -> Node:
	var p: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = max_distance
		p3.unit_size = 5.0
		p3.volume_db = volume_db
		p3.autoplay = true
		p3.stream = streams.get(name)
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.volume_db = volume_db
		p2.autoplay = true
		p2.stream = streams.get(name)
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
	for surface in ["concrete", "wood", "carpet", "grass"]:
		for v in 4:
			streams["step_%s_%d" % [surface, v]] = _to_wav(_footstep(surface, v), false)
	streams["knock"] = _to_wav(_knock(), false)
	streams["thud"] = _to_wav(_thud(), false)
	streams["chime"] = _to_wav(_chime(), false)
	streams["page"] = _to_wav(_page(), false)
	streams["whoosh"] = _to_wav(_whoosh(), false)
	streams["bite"] = _to_wav(_bite(), false)
	streams["chirp"] = _to_wav(_chirps(), false)
	print("Sfx: synthesized %d sounds in %d ms" % [streams.size(), Time.get_ticks_msec() - t0])


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
