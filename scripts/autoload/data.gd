extends Node
## Data-driven content: dialogue, notebook rules, manifestable objects and the tutorial video script
## live in res://data/*.json. New Game reloads them, so content can be edited while the game runs
## from the editor.

var dialogue := {}        # id -> dialogue dict
var rules := {}           # id -> rule dict
var manifest := {}        # id -> manifestation dict
var manifest_start: Array = []
var manifest_after_first: Array = []
var tutorial := {}
var journal: Array = []
var objectives := {}      # zone id -> [{flag, text, after}]
var notebook_title := ""


func _ready() -> void:
	reload()


func _load(file: String) -> Variant:
	var path := "res://data/" + file
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data: could not read " + path)
		return {}
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Data: invalid JSON in " + path)
		return {}
	return parsed


func reload() -> void:
	dialogue.clear()
	for d in _load("Dialogue.json").get("dialogues", []):
		dialogue[d["id"]] = d
	rules.clear()
	var nb = _load("Notebook.json")
	notebook_title = nb.get("title", "")
	for r in nb.get("rules", []):
		rules[r["id"]] = r
	manifest.clear()
	var m = _load("Manifestations.json")
	manifest_start = m.get("startUnlocked", [])
	manifest_after_first = m.get("unlockAfterFirst", [])
	for item in m.get("manifestations", []):
		manifest[item["id"]] = item
	tutorial = _load("Tutorial.json")
	journal = _load("Journal.json").get("entries", [])
	objectives = _load("Objectives.json")


static func vec(a, fallback := Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(a[0], a[1], a[2])
	if a is Array and a.size() == 1:
		return Vector3.ONE * a[0]
	return fallback


static func col(a, fallback := Color.WHITE) -> Color:
	if a is Array and a.size() >= 3:
		return Color(a[0], a[1], a[2])
	return fallback
