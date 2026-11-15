extends Node
## Procedural audio. Every sound in the game is synthesized once at startup into an AudioStreamWAV,
## so there are no audio asset files. Loops are generated with whole cycles so they wrap cleanly.

const RATE := 22050

var streams := {}  # name -> AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _foley_pool: Array[AudioStreamPlayer] = []
var _next_foley := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	_build_all()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_foley_pool.append(p)


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
	streams["step_hard"] = _to_wav(_step(false), false)
	streams["step_soft"] = _to_wav(_step(true), false)
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


func _step(soft: bool) -> PackedFloat32Array:
	return _env_noise(0.14, 38.0 if soft else 50.0, 0.12 if soft else 0.45, 0.6 if soft else 0.4)


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
