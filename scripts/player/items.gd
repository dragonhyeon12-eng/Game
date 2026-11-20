class_name Items
extends Node
## The things you can carry out of the resting places, and using them (with their little animations):
##   pills       a capsule: for 10 s nothing frightens you any more than it already has
##   music_box   wind it, open it, listen: the fear goes out of you. Then it's gone (one use each)
## Counts live in Game.counters ("inv_<id>"), so they're saved at checkpoints and start empty in a new game.

signal changed

const PILL_CALM := 10.0
const NAMES := {"pills": "PILLS", "music_box": "MUSIC BOX"}
const KEYS := {"pills": "1", "music_box": "2"}

var busy := false


func count(id: String) -> int:
	return int(Game.counters.get("inv_" + id, 0))


func add(id: String, n := 1) -> void:
	Game.counters["inv_" + id] = count(id) + n
	changed.emit()


func can_use(id: String) -> bool:
	return not busy and count(id) > 0 and Game.mode == "game" and not Game.in_sequence


func use(id: String) -> void:
	if not can_use(id):
		return
	busy = true
	Game.counters["inv_" + id] = count(id) - 1
	changed.emit()
	match id:
		"pills": await _take_pill()
		"music_box": await _play_music_box()
	busy = false
	changed.emit()


## Something held up in front of the camera, for an animation: the model, or a stand-in.
func _held(slot: String, fallback: Callable) -> Node3D:
	var n := Props.instance(slot)
	if n == null:
		n = fallback.call()
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.player.camera.add_child(n)
	return n


func _take_pill() -> void:
	var pl: Player = Game.player
	var pill := _held("pill", func():
		var m := MeshInstance3D.new()
		m.mesh = Shapes.mesh("capsule")
		m.scale = Vector3(0.009, 0.014, 0.009)
		var g := Node3D.new()
		g.add_child(m)
		return g)
	# up from your hand, a turn in the fingers, to your mouth
	pill.position = Vector3(0.16, -0.2, -0.32)
	pill.rotation_degrees = Vector3(10, 40, 70)
	pill.scale = Vector3.ONE * 1.6
	var tw := create_tween()
	tw.tween_property(pill, "position", Vector3(0.05, -0.08, -0.22), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pill, "rotation_degrees", Vector3(0, 90, 0), 0.45)
	tw.tween_interval(0.25)
	tw.tween_property(pill, "position", Vector3(0.0, -0.05, -0.08), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pill, "scale", Vector3.ONE * 0.4, 0.25)
	await tw.finished
	pill.queue_free()
	Sfx.play("bite", -8.0, 0.7)
	pl.jolt(Vector3(0, 1.2, 0))
	await get_tree().create_timer(0.35, false).timeout
	Sfx.play("chime", -14.0, 0.8)
	pl.dread.calm_for(PILL_CALM)
	Game.hud.show_thought("...Slower. Everything's slower. Ten seconds, maybe.", 3.0)


func _play_music_box() -> void:
	var pl: Player = Game.player
	var box := _held("music_box", func():
		var m := MeshInstance3D.new()
		m.mesh = Shapes.mesh("box")
		m.scale = Vector3(0.16, 0.065, 0.11)
		var g := Node3D.new()
		g.add_child(m)
		return g)
	var lid: Node3D = box.find_child("Lid*", true, false) as Node3D
	box.scale = Vector3.ONE * 1.1
	box.position = Vector3(0.0, -0.5, -0.5)
	box.rotation_degrees = Vector3(28, 0, 0)          # held in both hands, tipped toward you, hinge at the back
	var tw := create_tween()
	tw.tween_property(box, "position", Vector3(0.0, -0.2, -0.46), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	# wind it: a few clicks and a little shake
	for k in 4:
		Sfx.play("switch", -18.0, 2.2 + k * 0.1)
		box.rotation_degrees.z = 2.0 if k % 2 == 0 else -2.0
		await get_tree().create_timer(0.16, false).timeout
	box.rotation_degrees.z = 0.0
	if lid:
		create_tween().tween_property(lid, "rotation_degrees:x", -105.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sfx.play("musicbox", -4.0)
	Game.hud.show_thought("That tune. I know that tune.", 3.5)
	# while it plays, the fear goes out of you
	var f0 := pl.dread.fear
	var s0 := pl.dread.stability
	var t := 0.0
	while t < 6.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / 5.0, 0.0, 1.0)
		pl.dread.set_values(lerpf(f0, pl.dread.floor_fear, k), lerpf(s0, 100.0, k))
		box.position.y = -0.2 + sin(t * 1.3) * 0.004
	if lid:
		create_tween().tween_property(lid, "rotation_degrees:x", 0.0, 0.5)
	await get_tree().create_timer(0.6, false).timeout
	Sfx.play("thud", -22.0, 2.0)
	var out := create_tween()
	out.tween_property(box, "position", Vector3(0.0, -0.55, -0.46), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out.finished
	box.queue_free()
	Game.hud.show_thought("...Better. It's gone, though. The box. Like it was never there.", 3.5)
