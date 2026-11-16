class_name Manifestation
extends Node
## Lucid-dream manifestation. Hold Q to picture the selected object; it appears in your hand.
## Only works where the zone allows it. In nightmares, nothing comes.
## Picturing too much too fast counts as "forcefully changing your surroundings" (rule 5).

const FORCE_COUNT := 6
const FORCE_WINDOW := 20.0

var unlocked: Array = []
var selected := 0
var held: ManifestedObject = null
var _spawned: Array = []
var _recent: Array[float] = []
var _thought_shown := {}
var _failed := 0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta


func reset_unlocks() -> void:
	unlocked = Data.manifest_start.duplicate()
	selected = 0
	_thought_shown.clear()
	_failed = 0


func unlock(id: String) -> void:
	if Data.manifest.has(id) and not unlocked.has(id):
		unlocked.append(id)


func selected_name() -> String:
	if selected < unlocked.size():
		return Data.manifest.get(unlocked[selected], {}).get("name", "")
	return ""


func try_manifest() -> bool:
	var zone = Game.zone
	if zone == null or not zone.allows_manifestation():
		if zone and zone.is_nightmare():
			_failed += 1
			Game.hud.show_thought("...Nothing. It worked a minute ago." if _failed == 1 else "Nothing comes.", 3.5)
			Game.player.dread.add_fear(5.0 if _failed == 1 else 2.0, "manifest failed")
		else:
			Game.hud.show_thought("Nothing happens. Of course nothing happens. You're awake.", 3.5)
		return false
	# some places only let you picture certain things
	if zone.has_method("manifest_allowlist"):
		var allow: Array = zone.manifest_allowlist()
		for id in allow:
			unlock(id)
		if not allow.has(unlocked[clampi(selected, 0, unlocked.size() - 1)]):
			selected = unlocked.find(allow[0])
	if unlocked.is_empty():
		return false
	selected = clampi(selected, 0, unlocked.size() - 1)
	var def: Dictionary = Data.manifest.get(unlocked[selected], {})
	if def.is_empty():
		return false

	if held:
		held.release(Vector3.ZERO)
		held = null
	var obj := ManifestedObject.new()
	Game.player.hold_point.add_child(obj)
	obj.setup(def)
	held = obj
	_spawned.append(obj)
	Sfx.play("chime", -4.0)

	var id: String = def.get("id", "")
	if not _thought_shown.has(id) and def.get("thought", "") != "":
		_thought_shown[id] = true
		Game.hud.show_thought(def.thought, 4.5)

	if not Game.has_flag("manifest_first"):
		Game.set_flag("manifest_first")
		for u in Data.manifest_after_first:
			unlock(u)
		if id != "flashlight":
			Game.hud.show_hint("Left mouse: take a bite    Right mouse: let go / toss\nMouse wheel: picture something else", 9.0)

	_recent.append(_t)
	_recent = _recent.filter(func(x): return _t - x <= FORCE_WINDOW)
	if _recent.size() >= FORCE_COUNT:
		_recent.clear()
		Notebook.break_rule("rule_force")
	return true


func use_held() -> void:
	if held == null or held.bites_left <= 0:
		return
	Sfx.play("bite", -2.0)
	if held.bite():
		held.queue_free()
		held = null
		if not Game.has_flag("ate_icecream"):
			Game.set_flag("ate_icecream")
			Game.hud.show_thought("Tastes exactly like summer used to.", 4.0)


func throw_held() -> void:
	if held == null:
		return
	var fwd: Vector3 = -Game.player.camera.global_transform.basis.z
	held.release(fwd * 4.2 + Vector3.UP * 1.2)
	held = null


func cycle(dir: int) -> void:
	if unlocked.size() <= 1:
		return
	selected = posmod(selected + dir, unlocked.size())
	Game.hud.show_hint("Picturing: %s  (hold Q)" % selected_name(), 2.5)


func give_held_to(hand: Node3D) -> bool:
	if held == null or hand == null:
		return false
	held.reparent(hand, false)
	held.position = Vector3(0, 0.05, 0.04)
	held = null
	return true


func is_holding(id: String) -> bool:
	return held != null and held.def_id == id


func clear_all() -> void:
	for o in _spawned:
		if is_instance_valid(o):
			o.queue_free()
	_spawned.clear()
	held = null
	_recent.clear()
