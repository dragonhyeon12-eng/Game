class_name NPC
extends StaticBody3D
## A friendly dream character. The body is a procedural Human; this adds behaviour: looking at you,
## turning to face you while talking, jogging a loop and calling out one-liners (barks) from data.

var dialogue_id := ""
var display_name := ""
var unknown_label := ""
var patrol: Array[Vector3] = []
var patrol_speed := 0.0
var frozen := false
var seated := false
var body: Human

var _talking := false
var _patrol_i := 0
var _t := 0.0
var _next_bark := 0.0
var _bark_i := 0


## look: see Human.build
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
	cap.height = 1.3 if seated else 1.76 * h
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	body = Human.new()
	add_child(body)
	body.build(look)


func get_hand() -> Node3D:
	return body.hand(1)


func set_talking(on: bool) -> void:
	_talking = on


func speak() -> void:
	body.speak(1.4)


func set_frozen(on: bool) -> void:
	frozen = on
	body.set_process(not on)


func _process(delta: float) -> void:
	_t += delta
	if frozen:
		return  # perfectly, unnaturally still
	var player = Game.player
	var ppos: Vector3 = player.global_position if player else Vector3(1e6, 0, 0)
	var dist := Vector2(ppos.x - global_position.x, ppos.z - global_position.z).length()

	body.walk_speed = 0.0
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
			body.walk_speed = patrol_speed
		if dist < 4.5:
			_bark()

	if _talking and player and not seated:
		var want := atan2(ppos.x - global_position.x, ppos.z - global_position.z)
		rotation.y = lerp_angle(rotation.y, want, clampf(delta * 4.0, 0.0, 1.0))

	body.look_target = player.camera.global_position if (player and dist < 8.0) else Vector3.INF


func _bark() -> void:
	if _t < _next_bark:
		return
	var barks: Array = Data.dialogue.get(dialogue_id, {}).get("barks", [])
	if barks.is_empty():
		return
	_next_bark = _t + 25.0
	Game.hud.show_thought("%s: \"%s\"" % [unknown_label.capitalize(), barks[_bark_i % barks.size()]], 3.0)
	body.speak(1.5)
	_bark_i += 1


# ---- interaction
func get_prompt() -> String:
	return "Talk to " + (display_name if Game.has_flag("talked_" + dialogue_id) else unknown_label)


func can_interact() -> bool:
	return not frozen and patrol.size() <= 1 and not Dialogue.is_active() and Data.dialogue.has(dialogue_id)


func interact() -> void:
	Dialogue.start(self, dialogue_id)
