class_name NPC
extends StaticBody3D
## A friendly dream character built from primitives. Breathes, looks at you when you're near, turns to
## face you while talking, can jog a loop and call out one-liners (barks) from data.

var dialogue_id := ""
var display_name := ""
var unknown_label := ""
var patrol: Array[Vector3] = []
var patrol_speed := 0.0
var frozen := false
var seated := false

var _talking := false
var _t := 0.0
var _phase := randf() * 10.0
var _torso: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _hand: Node3D
var _patrol_i := 0
var _next_bark := 0.0
var _bark_i := 0


## look keys: skin, hair, shirt, pants (Color), height (1 = ~1.75m), seated, apron, cap, cap_color
func setup(id: String, name_known: String, name_unknown: String, look: Dictionary) -> void:
	dialogue_id = id
	display_name = name_known
	unknown_label = name_unknown
	seated = look.get("seated", false)
	collision_layer = 1
	var h: float = look.get("height", 1.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.76 * h if not seated else 1.3
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	_build(look, h)


func _p(parent: Node3D, kind: String, pos: Vector3, scale: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.material_override = Shapes.material(color, 0.8)
	mi.position = pos
	mi.scale = scale
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _build(l: Dictionary, h: float) -> void:
	var skin: Color = l.get("skin", Color(0.8, 0.6, 0.48))
	var hair: Color = l.get("hair", Color(0.15, 0.1, 0.07))
	var shirt: Color = l.get("shirt", Color(0.3, 0.5, 0.8))
	var pants: Color = l.get("pants", Color(0.2, 0.2, 0.25))
	var shoes := Color(0.06, 0.05, 0.05)
	var hip := 0.46 if seated else 0.9 * h

	if seated:
		for s in [-1.0, 1.0]:
			_p(self, "cylinder", Vector3(0.1 * s, hip, 0.22), Vector3(0.14, 0.45, 0.14), pants, Vector3(90, 0, 0))
			_p(self, "cylinder", Vector3(0.1 * s, 0.24, 0.44), Vector3(0.12, 0.46, 0.12), pants)
			_p(self, "box", Vector3(0.1 * s, 0.04, 0.5), Vector3(0.12, 0.08, 0.26), shoes)
	else:
		for s in [-1.0, 1.0]:
			var leg := _pivot(self, Vector3(0.1 * s, hip, 0))
			_p(leg, "cylinder", Vector3(0, -0.44 * h, 0), Vector3(0.13, 0.88 * h, 0.13), pants)
			_p(leg, "box", Vector3(0, -0.86 * h, 0.05), Vector3(0.12, 0.08, 0.26), shoes)
			_legs.append(leg)

	_torso = _pivot(self, Vector3(0, hip, 0))
	_p(_torso, "cylinder", Vector3(0, 0.3 * h, 0), Vector3(0.36, 0.62 * h, 0.25), shirt)
	if l.get("apron", false):
		_p(_torso, "box", Vector3(0, 0.18 * h, 0.125), Vector3(0.3, 0.55 * h, 0.02), Color(0.97, 0.97, 0.95))
	for s in [-1.0, 1.0]:
		var arm := _pivot(_torso, Vector3(0.22 * s, 0.56 * h, 0))
		_p(arm, "cylinder", Vector3(0, -0.28 * h, 0), Vector3(0.09, 0.58 * h, 0.09), shirt)
		_p(arm, "sphere", Vector3(0, -0.6 * h, 0), Vector3.ONE * 0.1, skin)
		if seated:
			arm.rotation_degrees.x = 35
		_arms.append(arm)
	_hand = _pivot(_arms[1], Vector3(0, -0.62 * h, 0.08))

	_p(_torso, "cylinder", Vector3(0, 0.64 * h, 0), Vector3(0.1, 0.08, 0.1), skin)
	_head = _pivot(_torso, Vector3(0, 0.68 * h, 0))
	_p(_head, "sphere", Vector3(0, 0.12, 0), Vector3(0.19, 0.25, 0.21), skin)
	_p(_head, "sphere", Vector3(0, 0.17, -0.025), Vector3(0.205, 0.19, 0.225), hair)
	# A face. Everyone here has one.
	var eye := Color(0.03, 0.025, 0.02)
	_p(_head, "sphere", Vector3(-0.04, 0.14, 0.095), Vector3.ONE * 0.025, eye)
	_p(_head, "sphere", Vector3(0.04, 0.14, 0.095), Vector3.ONE * 0.025, eye)
	_p(_head, "box", Vector3(0, 0.08, 0.1), Vector3(0.05, 0.008, 0.01), Color(0.5, 0.25, 0.22))
	if l.get("cap", false):
		var cc: Color = l.get("cap_color", Color.RED)
		_p(_head, "cylinder", Vector3(0, 0.24, 0), Vector3(0.23, 0.07, 0.23), cc)
		_p(_head, "box", Vector3(0, 0.215, 0.13), Vector3(0.2, 0.015, 0.14), cc)


func get_hand() -> Node3D:
	return _hand


func set_talking(on: bool) -> void:
	_talking = on


func _process(delta: float) -> void:
	_t += delta
	if frozen:
		return  # perfectly, unnaturally still
	var player = Game.player
	var ppos: Vector3 = player.global_position if player else Vector3(1e6, 0, 0)
	var dist := Vector2(ppos.x - global_position.x, ppos.z - global_position.z).length()

	_torso.scale.y = 1.0 + 0.012 * sin((_t + _phase) * 1.7)

	if patrol.size() > 1 and not _talking:
		var target := patrol[_patrol_i]
		var to := target - global_position
		to.y = 0
		if to.length() < 0.4:
			_patrol_i = (_patrol_i + 1) % patrol.size()
		else:
			var d := to.normalized()
			global_position += d * patrol_speed * delta
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(delta * 5.0, 0.0, 1.0))
		var swing := sin(_t * patrol_speed * 2.5) * 32.0
		_legs[0].rotation_degrees.x = swing
		_legs[1].rotation_degrees.x = -swing
		_arms[0].rotation_degrees.x = -swing * 0.8
		_arms[1].rotation_degrees.x = swing * 0.8
		if dist < 4.5:
			_bark()

	if _talking and player and not seated:
		var want := atan2(ppos.x - global_position.x, ppos.z - global_position.z)
		rotation.y = lerp_angle(rotation.y, want, clampf(delta * 4.0, 0.0, 1.0))

	# Look at the player when nearby.
	var target_rot := Vector3.ZERO
	if player and dist < 8.0:
		var local := to_local(player.camera.global_position)
		target_rot = Vector3(clampf(-rad_to_deg(atan2(local.y - 1.5, Vector2(local.x, local.z).length())), -20, 20),
			clampf(rad_to_deg(atan2(local.x, local.z)), -65, 65), 0)
	else:
		target_rot = Vector3(0, sin((_t + _phase) * 0.3) * 25.0, 0)
	_head.rotation_degrees = _head.rotation_degrees.lerp(target_rot, clampf(delta * 3.0, 0.0, 1.0))


func _bark() -> void:
	if _t < _next_bark:
		return
	var barks: Array = Data.dialogue.get(dialogue_id, {}).get("barks", [])
	if barks.is_empty():
		return
	_next_bark = _t + 25.0
	Game.hud.show_thought("%s: \"%s\"" % [unknown_label.capitalize(), barks[_bark_i % barks.size()]], 3.0)
	_bark_i += 1


# ---- interaction
func get_prompt() -> String:
	return "Talk to " + (display_name if Game.has_flag("talked_" + dialogue_id) else unknown_label)


func can_interact() -> bool:
	return not frozen and patrol.size() <= 1 and not Dialogue.is_active() and Data.dialogue.has(dialogue_id)


func interact() -> void:
	Dialogue.start(self, dialogue_id)
