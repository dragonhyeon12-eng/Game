extends Node
## Runs one conversation at a time from data/Dialogue.json.
## Nodes and choices carry effect strings, so story consequences live in data.

var _dialogue: Dictionary = {}
var _node: Dictionary = {}
var _visible: Array = []   # indices into _node.choices
var speaker: Node = null


func is_active() -> bool:
	return not _dialogue.is_empty()


func start(who: Node, id: String) -> bool:
	if is_active() or not Data.dialogue.has(id):
		return false
	_dialogue = Data.dialogue[id]
	speaker = who
	var entry := ""
	for e in _dialogue.get("entries", []):
		if Effects.check(e.get("ifFlag", "")):
			entry = e.get("node", "")
			break
	if entry == "" and _dialogue.get("nodes", []).size() > 0:
		entry = _dialogue.nodes[0].id
	if speaker and speaker.has_method("set_talking"):
		speaker.set_talking(true)
	Game.enter_dialogue_mode()
	_enter(entry)
	# set after choosing the entry node so "first meeting" entries work
	Game.set_flag("talked_" + id)
	Game.set_flag("talked_any")
	return true


func _find(node_id: String) -> Dictionary:
	for n in _dialogue.get("nodes", []):
		if n.get("id", "") == node_id:
			return n
	return {}


func _enter(node_id: String) -> void:
	if not is_active() or node_id == "" or node_id == "end":
		end()
		return
	_node = _find(node_id)
	if _node.is_empty():
		push_warning("Dialogue: node '%s' not found" % node_id)
		end()
		return
	Effects.apply_all(_node.get("effects", []), speaker)
	if is_active():
		_present()


func _present() -> void:
	_visible.clear()
	var labels: Array[String] = []
	var choices: Array = _node.get("choices", [])
	for i in choices.size():
		var c: Dictionary = choices[i]
		if not Effects.check(c.get("requiresFlag", "")):
			continue
		var hide_flag: String = c.get("hiddenIfFlag", "")
		if hide_flag != "" and Effects.check(hide_flag):
			continue
		_visible.append(i)
		labels.append(c.get("text", ""))
	Game.hud.show_dialogue(_node.get("speaker", ""), _node.get("text", ""), labels)


func choose(visible_index: int) -> void:
	if not is_active():
		return
	if _visible.is_empty():
		advance()
		return
	if visible_index < 0 or visible_index >= _visible.size():
		return
	var c: Dictionary = _node.choices[_visible[visible_index]]
	Effects.apply_all(c.get("effects", []), speaker)
	if is_active():
		_enter(c.get("next", ""))


func advance() -> void:
	if is_active() and _visible.is_empty():
		_enter(_node.get("next", ""))


func end() -> void:
	if not is_active():
		return
	_dialogue = {}
	_node = {}
	_visible.clear()
	if is_instance_valid(speaker) and speaker.has_method("set_talking"):
		speaker.set_talking(false)
	speaker = null
	Game.hud.hide_dialogue()
	Game.exit_dialogue_mode()
