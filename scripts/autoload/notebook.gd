extends Node
## Notebook rule state. Definitions live in data/Notebook.json; this holds what is currently written,
## hidden, rewritten or pending, and how often each rule was broken.
## The notebook never says which rules can be trusted. It only changes.

signal rule_broken(id: String)

## id -> {written, hidden, pending, variant, breaks, reads}
var state := {}


func reset() -> void:
	state.clear()


func load_state(saved: Dictionary) -> void:
	state = saved.duplicate(true)


func get_state() -> Dictionary:
	return state.duplicate(true)


func _rule(id: String) -> Dictionary:
	if not state.has(id):
		state[id] = {"written": false, "hidden": false, "pending": false, "variant": "", "breaks": 0, "reads": 0}
	return state[id]


func _known(id: String) -> bool:
	if not Data.rules.has(id):
		push_warning("Notebook: unknown rule '%s'" % id)
		return false
	return true


func write(id: String) -> void:
	if not _known(id):
		return
	var r := _rule(id)
	r.written = true
	r.hidden = false
	r.pending = false


func reveal_on_next_open(id: String) -> void:
	if not _known(id):
		return
	var r := _rule(id)
	if not r.written or r.hidden:
		r.pending = true


func hide_rule(id: String) -> void:
	if state.has(id):
		state[id].hidden = true
		state[id].pending = false


func rewrite(id: String, variant: String) -> void:
	_rule(id).variant = variant


func break_rule(id: String) -> void:
	if not _known(id):
		return
	var r := _rule(id)
	r.breaks += 1
	var def: Dictionary = Data.rules[id]
	var effects: Array = def.get("onBreak", [])
	if r.breaks > 1 and def.has("onRepeatBreak"):
		effects = def["onRepeatBreak"]
	print("Rule broken: %s (x%d)" % [id, r.breaks])
	if id == "rule_tell" and Game.zone_type == "city":
		Game.set_flag("city_told")
	rule_broken.emit(id)
	Effects.apply_all(effects.duplicate())


## Story milestones add lines to the notebook (rules with "revealOn": flag). Returns true if any did.
func on_flag(flag: String) -> bool:
	var any := false
	for id in Data.rules:
		var def: Dictionary = Data.rules[id]
		if def.get("revealOn", "") == flag and _known(id):
			var r := _rule(id)
			if not r.written and not r.pending:
				reveal_on_next_open(id)
				any = true
	return any


## Call right before the notebook UI opens.
func on_opened() -> void:
	var reread_breaks: Array[String] = []
	for id in state:
		var r: Dictionary = state[id]
		if r.written and not r.hidden:
			if int(Data.rules.get(id, {}).get("breaksOnReread", 0)) != 0 and r.reads >= 1:
				reread_breaks.append(id)
			r.reads += 1
	# New lines appear now; this opening counts as their first reading.
	for id in state:
		var r: Dictionary = state[id]
		if r.pending:
			r.pending = false
			r.written = true
			r.hidden = false
			r.reads = 1
	for id in reread_breaks:
		break_rule(id)


func has_any_written() -> bool:
	for id in state:
		if state[id].written:
			return true
	return false


## Lines for display: [{text, style, number}], sorted by rule order.
func build_page() -> Array:
	var items := []
	for id in state:
		var r: Dictionary = state[id]
		if not r.written or r.hidden or not Data.rules.has(id):
			continue
		var def: Dictionary = Data.rules[id]
		var text: String = def.get("text", "")
		var style: String = def.get("style", "Player")
		if r.variant != "":
			for v in def.get("variants", []):
				if v.get("id", "") == r.variant:
					text = v.get("text", text)
					style = v.get("style", style)
		items.append({"order": int(def.get("order", 0)), "text": text, "style": style})
	items.sort_custom(func(a, b): return a.order < b.order)
	var n := 1
	for it in items:
		# Only the player's own rules get numbers. Other handwriting just... appears.
		if it.style == "Unknown":
			it.number = 0
		else:
			it.number = n
			n += 1
	return items
