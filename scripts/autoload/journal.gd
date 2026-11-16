extends Node
## The dream journal: an entry for every part of the dream you have made it through.
## Entries live in data/Journal.json; which ones you have unlocked is kept in user://journal.cfg,
## so the journal survives New Game.

const PATH := "user://journal.cfg"

var unlocked := {}


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for id in cfg.get_value("journal", "unlocked", []):
			unlocked[id] = true


## Called whenever a story flag is set. Returns true if this unlocked a new entry.
func on_flag(flag: String) -> bool:
	var added := false
	for e in Data.journal:
		if e.get("unlock", "") == flag and not unlocked.has(e.id):
			unlocked[e.id] = true
			added = true
	if added:
		var cfg := ConfigFile.new()
		cfg.set_value("journal", "unlocked", unlocked.keys())
		cfg.save(PATH)
	return added


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)
