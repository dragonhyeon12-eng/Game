extends Node
## Render the game's synthesized music to WAV files (the game builds it at startup; this saves it).
##   godot --headless --path . res://tools/music/export_music.tscn -- <outdir> [track ...] [--minutes N]
## Tracks: title (the title / loading screen), city, maze, deep, chase, muzak. Each is written twice:
## <track>_loop.wav (one seamless loop, as the game plays it) and <track>.wav (looped to N minutes, default 2).

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out: String = args[0] if args.size() > 0 else "user://music"
	var minutes := 2.0
	var i := args.find("--minutes")
	if i >= 0 and i + 1 < args.size():
		minutes = float(args[i + 1])
	var tracks := args.slice(1).filter(func(a): return not String(a).begins_with("--") and not String(a).is_valid_float())
	if tracks.is_empty():
		tracks = ["title"]
	DirAccess.make_dir_recursive_absolute(out)
	for t in tracks:
		var data: PackedFloat32Array
		match t:
			"title": data = Sfx._track_title()
			"city": data = Sfx._track_city()
			"maze": data = Sfx._track_maze()
			"deep": data = Sfx._track_deep()
			"chase": data = Sfx._track_chase()
			"muzak": data = Sfx._track_muzak()
			_:
				push_error("unknown track " + t)
				continue
		Sfx._to_wav(data, false).save_to_wav(out + "/" + t + "_loop.wav")
		var long := PackedFloat32Array()
		var reps := maxi(1, int(ceil(minutes * 60.0 * Sfx.RATE / data.size())))
		for r in reps:
			long.append_array(data)
		# a gentle fade at the very end, so the long version doesn't stop dead
		var fade := mini(int(4.0 * Sfx.RATE), long.size())
		for k in fade:
			long[long.size() - fade + k] *= 1.0 - float(k) / fade
		Sfx._to_wav(long, false).save_to_wav(out + "/" + t + ".wav")
		print("wrote %s/%s.wav (%.0f s) and %s_loop.wav (%.1f s)" % [out, t, long.size() / float(Sfx.RATE), t, data.size() / float(Sfx.RATE)])
	get_tree().quit()
