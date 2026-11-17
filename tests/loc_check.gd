extends Node
## Spot-checks the Korean translation of text built at runtime.  godot --headless --path . res://tests/loc_check.tscn

func _ready() -> void:
	Settings.language = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	var bad := 0
	for s in ["OBJECTIVES\n[x]  Explore the neighbourhood (2/3)\n[  ]  Talk to the residents (0/3)", "[E]  Talk to Mina",
			"Talk to the ice cream vendor", "1.  Here. I made you one.", "3. Don't tell anyone you're dreaming.",
			"Get to floor 7 (now: 5)", "2. Far below, something turned toward the light.", "Breaker C (up)",
			"Picturing: an ice cream cone  (hold Q)", "%d of 3." % 2, "DREAD   UNEASY", "Locked. \"ROOF ACCESS - FLOOR 7\". This is floor 5.",
			"Your dream journal has a new entry.\n(Pause > MENU > DREAM JOURNAL)", "\"B then D. Never the other way round.\""]:
		var t := tr(s)
		print(s.c_escape(), "\n   -> ", t.c_escape())
		if t == s:
			bad += 1
	print("LOC CHECK ", "PASSED" if bad == 0 else "FAILED (%d untranslated)" % bad)
	get_tree().quit()
