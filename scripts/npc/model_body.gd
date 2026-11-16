class_name ModelBody
extends Human
## A person whose body is a real model (models/people/<id>.glb) instead of the procedural one.
## Same interface as Human, so NPC does not care which it has: walk_speed, look_target, speak(),
## hand(), set_frozen(). Plays the model's own animations when it has them (idle / walk / run /
## sit / talk, found by name), turns the head bone toward look_target, and finds the hand bones
## for things to be handed over.

var _model: Node3D
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _anims := {}              # role -> animation name
var _current := ""
var _aim: HeadAim
var _hand_nodes: Array[Node3D] = []


## Use `model` (from Models.instance) as this person's body. look: height, seated.
func use_model(model: Node3D, l: Dictionary) -> void:
	height = l.get("height", 1.0)
	seated = l.get("seated", false)
	var slot: String = model.get_meta("slot", "")
	# a seated model is measured standing up, so fit by its standing height when it has a sit pose
	_model = Models.fit(model, 1.75 * height)
	add_child(_model)
	_ap = Models.animation_player(model)
	for role in Models.ANIM_WORDS:
		var a := Models.pick_animation(_ap, role, slot)
		if a != "":
			_anims[role] = a
			if role != "talk":
				_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var skels := Models.all_of(model, "Skeleton3D")
	if not skels.is_empty():
		_skel = skels[0]
		var head_bone := _find_bone(["head"], ["end", "top", "nub"])
		if head_bone >= 0:
			_aim = HeadAim.new()
			_aim.bone = head_bone
			_aim.body = self
			_skel.add_child(_aim)
	_find_hands()
	_play("sit" if seated else "idle")


func hand(i := 1) -> Node3D:
	return _hand_nodes[clampi(i, 0, _hand_nodes.size() - 1)]


func speak(seconds := 1.6) -> void:
	_talk = seconds


func set_frozen(on: bool) -> void:
	set_process(not on)
	if _ap and on:
		_ap.pause()
	elif _ap and _current != "":
		_ap.play()


func _process(delta: float) -> void:
	_t += delta
	_talk = maxf(0.0, _talk - delta)
	var role := "idle"
	if seated:
		role = "sit"
	elif walk_speed > 3.2 and _anims.has("run"):
		role = "run"
	elif walk_speed > 0.05:
		role = "walk"
	elif _talk > 0.0 and _anims.has("talk"):
		role = "talk"
	_play(role)
	if _ap and role in ["walk", "run"]:
		_ap.speed_scale = clampf(walk_speed / (4.5 if role == "run" else 1.4), 0.5, 2.0)
	elif _ap:
		_ap.speed_scale = 1.0

	# head look, applied on top of the animation by HeadAim
	var target := Vector3.ZERO
	if look_target != Vector3.INF and is_inside_tree():
		var local := global_transform.affine_inverse() * look_target - Vector3(0, 1.6 * height, 0)
		target = Vector3(clampf(-rad_to_deg(atan2(local.y, Vector2(local.x, local.z).length())), -25, 20),
			clampf(rad_to_deg(atan2(local.x, local.z)), -70, 70), 0)
	else:
		target = Vector3(0, sin(_t * 0.3) * 20.0, 0)
	if _aim:
		_aim.look = _aim.look.lerp(target, clampf(delta * 4.0, 0.0, 1.0))


func _play(role: String) -> void:
	if _ap == null:
		return
	var a: String = _anims.get(role, _anims.get("idle", ""))
	if a == "" or a == _current:
		return
	_current = a
	_ap.play(a, 0.25)


## Index of the first bone whose name contains one of `words` and none of `not_words`; shortest wins.
func _find_bone(words: Array, not_words: Array, side := 0.0) -> int:
	var best := -1
	for i in _skel.get_bone_count():
		var low := _skel.get_bone_name(i).to_lower()
		if not words.any(func(w): return low.contains(w)):
			continue
		if not_words.any(func(w): return low.contains(w)):
			continue
		if side != 0.0:
			# which side the bone is on, measured in this body's space (+X = side 1)
			var p := _skel_to_body() * _skel.get_bone_global_rest(i).origin
			if signf(p.x) != side:
				continue
		if best < 0 or low.length() < _skel.get_bone_name(best).length():
			best = i
	return best


func _skel_to_body() -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = _skel
	while n != self and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Index 0 = the -X side, 1 = the +X side, like Human. Attached to the hand bones when there are any.
func _find_hands() -> void:
	for side in [-1.0, 1.0]:
		var node: Node3D = null
		if _skel:
			var b := _find_bone(["hand", "wrist", "palm"], ["finger", "thumb", "index", "middle", "ring", "pinky", "little", "end"], side)
			if b >= 0:
				var att := BoneAttachment3D.new()
				att.bone_name = _skel.get_bone_name(b)
				_skel.add_child(att)
				node = Node3D.new()
				att.add_child(node)
				# undo the model's scale so held things keep their real size
				node.scale = Vector3.ONE / maxf(_skel_to_body().basis.get_scale().x, 0.0001)
		if node == null:
			node = Node3D.new()
			node.position = Vector3(0.22 * side, 0.82 * height, 0.12)
			add_child(node)
		_hand_nodes.append(node)
