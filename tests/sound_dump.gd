extends Node
## Writes synthesized sounds to WAV files and prints their levels:
##   godot --headless --path . res://tests/sound_dump.tscn -- <out_dir> name...   ("chase" = the chase music)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	for name in args.slice(1):
		var data: PackedFloat32Array
		if name == "chase":
			data = Sfx._track_chase()
		elif name == "stall":
			var r := RandomNumberGenerator.new()
			data = Sfx._stall_voice(r)
		else:
			data = PackedFloat32Array()
		var w: AudioStreamWAV = Sfx._to_wav(data, false) if not data.is_empty() else Sfx.streams[name]
		if data.is_empty():
			var b := w.data
			data.resize(b.size() / 2)
			for i in data.size():
				data[i] = b.decode_s16(i * 2) / 32000.0
		var peak := 0.0
		var sq := 0.0
		for v in data:
			peak = maxf(peak, absf(v))
			sq += v * v
		print("%s: %.2f s, peak %.2f, rms %.3f" % [name, data.size() / float(Sfx.RATE), peak, sqrt(sq / maxf(data.size(), 1))])
		w.save_to_wav("%s/%s.wav" % [out, name])
	get_tree().quit()
