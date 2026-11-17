class_name FPHands
extends Node3D
## The dreamer's own hands: a sculpted, rigged hand and forearm made in Blender (models/fp_hand.glb,
## tools/creatures/hands.py; the left is the right one mirrored), its finger bones driven here. Without that
## file: built procedurally (palm, knuckles, four three-jointed fingers, a thumb, nails, forearm). Poses blend smoothly:
## relaxed, holding something, reaching toward what you use, and conjuring (while picturing an object).
## Placed close to the camera (inside the player's capsule), so they never clip through walls.

const SKIN := Color(0.86, 0.66, 0.54)
const SLEEVE := Color(0.83, 0.63, 0.52)   # bare forearms: the T-shirt's sleeves end above the elbow

## Per-finger joint curl (degrees) for each pose: [base, middle, tip]
const POSES := {
	"relaxed":  {"curl": [14.0, 18.0, 12.0], "thumb": 15.0, "spread": 4.0},
	"hold":     {"curl": [55.0, 65.0, 45.0], "thumb": 45.0, "spread": 1.0},
	"reach":    {"curl": [4.0, 5.0, 4.0], "thumb": 5.0, "spread": 8.0},
	"conjure":  {"curl": [6.0, 10.0, 8.0], "thumb": 8.0, "spread": 14.0},
}

var right_socket: Node3D   # where held objects go
var pose_right := "relaxed"
var pose_left := "relaxed"
var conjuring := false

var _hands := {}           # side (+1 right / -1 left) -> {root, fingers: [[pivots]], thumb: [pivots], rest: Transform3D}
var _curl := {1.0: [14.0, 18.0, 12.0], -1.0: [14.0, 18.0, 12.0]}
var _thumb := {1.0: 15.0, -1.0: 15.0}
var _spread := {1.0: 4.0, -1.0: 4.0}
var _sway := Vector2.ZERO
var _reach := 0.0
var _t := 0.0
var _swim := 0.0          # 0..1 blend into the breaststroke
var _stroke := 0.0        # stroke cycle position

## Breaststroke keyframes: [cycle position, offset (x toward the outside for each hand), roll degrees]
const STROKE := [
	[0.0, Vector3(-0.05, 0.05, -0.16), 0.0],    # hands meeting in front
	[0.3, Vector3(-0.06, 0.07, -0.32), 0.0],    # glide, arms out straight
	[0.55, Vector3(0.16, 0.02, -0.18), 38.0],   # sweep outward, palms turned out
	[0.8, Vector3(0.02, -0.03, 0.0), 12.0],     # pull in under the chin
	[1.0, Vector3(-0.05, 0.05, -0.16), 0.0],
]


const FINGER_NAMES := ["index", "middle", "ring", "pinky"]
const MODEL_OFFSET := Vector3(0.0, 0.004, 0.072)   # the model's origin is the wrist; the hand frame's is the palm
const HAND_LAYER := 1 << 18                          # render layer 19: what the hand fill light touches


func _ready() -> void:
	var use_model := Models.find("fp_hand") != ""
	for side in [1.0, -1.0]:
		if not (use_model and _build_model(side)):
			_build(side)
	if use_model:
		# a faint fill that only lights your own hands, so they don't go black in a dark room
		var fill := OmniLight3D.new()
		fill.position = Vector3(0, 0.12, 0.05)
		fill.light_energy = 0.22
		fill.omni_range = 0.9
		fill.light_color = Color(1.0, 0.93, 0.86)
		fill.light_cull_mask = HAND_LAYER
		fill.shadow_enabled = false
		fill.light_specular = 0.2
		add_child(fill)


## The Blender hand. Returns false if the file can't be used.
func _build_model(side: float) -> bool:
	var root := _pivot(self, Vector3(0.18 * side, -0.2, -0.3), Vector3(6, -8 * side, -38 * side))
	_hands[side] = {"root": root, "rest": root.transform}
	if not _attach_model(side, "fp_hand"):
		_hands.erase(side)
		root.free()
		return false
	if side > 0.0:
		right_socket = _pivot(root, Vector3(-0.01, -0.05, -0.05))
		right_socket.basis = root.basis.inverse()
	return true


## Put a hand model (bare, or one of the gloves) on a hand, replacing the one it has.
func _attach_model(side: float, slot: String) -> bool:
	var inst := Models.instance([slot, "fp_hand"])
	if inst == null:
		return false
	var found := inst.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		inst.free()
		return false
	var hand: Dictionary = _hands[side]
	if hand.has("inst") and is_instance_valid(hand.inst):
		hand.inst.queue_free()
	var root: Node3D = hand.root
	root.add_child(inst)
	inst.position = MODEL_OFFSET
	if side < 0.0:
		inst.scale = Vector3(-1, 1, 1)    # the left hand: the right one, mirrored
	var sk: Skeleton3D = found[0]
	var ids := {}
	var rests := {}
	for i in sk.get_bone_count():
		ids[sk.get_bone_name(i)] = i
		rests[sk.get_bone_name(i)] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = 1 | HAND_LAYER
		for si in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(si)
			if mat is StandardMaterial3D:
				var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				if String(mat.resource_name).to_lower().contains("skin"):
					# light goes into skin and comes back out redder
					sm.subsurf_scatter_enabled = true
					sm.subsurf_scatter_strength = 0.35
					sm.subsurf_scatter_skin_mode = true
					sm.roughness = 0.58
					sm.rim_enabled = true
					sm.rim = 0.12
					sm.rim_tint = 0.6
					sm.normal_scale = 0.5          # pores and creases: there, not leathery
				m.set_surface_override_material(si, sm)
	hand["inst"] = inst
	hand["sk"] = sk
	hand["ids"] = ids
	hand["rests"] = rests
	hand["slot"] = slot
	return true


## What you have on your hands in each realm.
const VARIANT_BY_ZONE := {
	"maze": "fp_hand_hazmat",
	"deep": "fp_hand_diving", "seabed": "fp_hand_diving", "abyss": "fp_hand_diving",
	"compression": "fp_hand_work", "tenement": "fp_hand_work",
	"above": "fp_hand_leather",
}
var _zone_seen := "-"


func _update_variant() -> void:
	if Game.zone_type == _zone_seen:
		return
	_zone_seen = Game.zone_type
	var slot: String = VARIANT_BY_ZONE.get(_zone_seen, "fp_hand")
	for side in _hands:
		if _hands[side].has("sk") and _hands[side].get("slot", "") != slot:
			_attach_model(side, slot)


func _bone(hand: Dictionary, bone: String, curl_deg: float, spread_deg := 0.0) -> void:
	if not hand.ids.has(bone):
		return
	var q: Quaternion = hand.rests[bone] * Quaternion(Vector3.RIGHT, deg_to_rad(-curl_deg)) * Quaternion(Vector3.FORWARD, deg_to_rad(spread_deg))
	(hand.sk as Skeleton3D).set_bone_pose_rotation(hand.ids[bone], q)


func _mesh(parent: Node3D, kind: String, pos: Vector3, scl: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	return n


## Local frame: X = toward the pinky side for the right hand, Y = back of the hand, -Z = fingers.
func _build(side: float) -> void:
	var skin := Shapes.skin(SKIN)
	var knuckle_skin := Shapes.skin(SKIN.darkened(0.04))
	var nail := Shapes.material(Color(0.95, 0.8, 0.76), 0.25)
	var sleeve := Shapes.surface("fabric", SLEEVE)

	var root := _pivot(self, Vector3(0.18 * side, -0.2, -0.3), Vector3(6, -8 * side, -38 * side))
	var rest := root.transform

	# palm and the back of the hand
	_mesh(root, "sphere", Vector3(0, 0, 0), Vector3(0.088, 0.032, 0.1), skin)
	_mesh(root, "sphere", Vector3(0, 0.006, -0.01), Vector3(0.082, 0.026, 0.09), knuckle_skin)
	# wrist, forearm, sleeve, cuff
	_mesh(root, "capsule", Vector3(0, -0.002, 0.08), Vector3(0.066, 0.06, 0.05), skin, Vector3(-90, 0, 0))
	_mesh(root, "capsule", Vector3(0, -0.004, 0.17), Vector3(0.072, 0.09, 0.058), skin, Vector3(-90, 0, 0))
	_mesh(root, "capsule", Vector3(0, 0.0, 0.3), Vector3(0.1, 0.13, 0.09), sleeve, Vector3(-90, 0, 0))
	_mesh(root, "cylinder", Vector3(0, 0.0, 0.2), Vector3(0.098, 0.03, 0.088), Shapes.surface("fabric", SLEEVE.darkened(0.2)), Vector3(-90, 0, 0))

	var fingers := []
	var widths := [0.019, 0.02, 0.0185, 0.016]
	var lengths := [[0.042, 0.026, 0.021], [0.047, 0.029, 0.022], [0.044, 0.027, 0.021], [0.034, 0.021, 0.018]]
	var xs := [-0.03, -0.01, 0.01, 0.029]
	var zs := [-0.046, -0.05, -0.047, -0.04]
	for f in 4:
		var x: float = xs[f] * side
		var w: float = widths[f]
		_mesh(root, "sphere", Vector3(x, 0.008, zs[f] + 0.004), Vector3(w * 1.15, w * 0.9, w * 1.1), knuckle_skin)
		var parent := _pivot(root, Vector3(x, 0.002, zs[f]))
		var joints := []
		for seg in 3:
			var length: float = lengths[f][seg]
			var ww := w * (1.0 - seg * 0.1)
			_mesh(parent, "capsule", Vector3(0, 0, -length * 0.5), Vector3(ww, length * 0.5 + ww * 0.25, ww * 0.88), skin, Vector3(-90, 0, 0))
			if seg == 2:
				_mesh(parent, "box", Vector3(0, ww * 0.42, -length * 0.62), Vector3(ww * 0.7, 0.003, length * 0.5), nail)
			joints.append(parent)
			if seg < 2:
				parent = _pivot(parent, Vector3(0, 0, -length))
		fingers.append(joints)

	# thumb: comes off the side of the palm, angled out and forward
	var tbase := _pivot(root, Vector3(-0.045 * side, -0.008, 0.012), Vector3(0, 38 * side, -30 * side))
	_mesh(tbase, "capsule", Vector3(0, 0, -0.02), Vector3(0.026, 0.026, 0.024), skin, Vector3(-90, 0, 0))
	var t1 := _pivot(tbase, Vector3(0, 0, -0.04))
	_mesh(t1, "capsule", Vector3(0, 0, -0.016), Vector3(0.021, 0.02, 0.019), skin, Vector3(-90, 0, 0))
	var t2 := _pivot(t1, Vector3(0, 0, -0.03))
	_mesh(t2, "capsule", Vector3(0, 0, -0.013), Vector3(0.019, 0.017, 0.017), skin, Vector3(-90, 0, 0))
	_mesh(t2, "box", Vector3(0, 0.008, -0.016), Vector3(0.013, 0.003, 0.013), nail)

	if side > 0.0:
		# held objects sit in the palm, kept upright relative to the view
		right_socket = _pivot(root, Vector3(-0.01, -0.05, -0.05))
		right_socket.basis = root.basis.inverse()

	_hands[side] = {"root": root, "fingers": fingers, "thumb": [tbase, t1, t2], "rest": rest}


## Small reach toward something you just used.
func reach() -> void:
	_reach = 1.0


## Offset and roll of a hand at a point of the breaststroke cycle (smoothly between keyframes).
func _stroke_at(p: float) -> Array:
	for i in STROKE.size() - 1:
		var a: Array = STROKE[i]
		var b: Array = STROKE[i + 1]
		if p <= b[0]:
			var f := smoothstep(0.0, 1.0, (p - a[0]) / (b[0] - a[0]))
			return [(a[1] as Vector3).lerp(b[1], f), lerpf(a[2], b[2], f)]
	return [STROKE[0][1], 0.0]


## Mouse movement makes the hands lag a little behind the view.
func add_sway(mouse_delta: Vector2) -> void:
	_sway += mouse_delta * 0.00012
	_sway = _sway.limit_length(0.04)


func _process(delta: float) -> void:
	_t += delta
	_update_variant()
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	_reach = maxf(0.0, _reach - delta * 3.0)
	var player = get_parent().get_parent().get_parent() if get_parent() else null
	var speed := 0.0
	var swimming := false
	if player is CharacterBody3D:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
		swimming = bool(player.get("swimming"))
	_swim = lerpf(_swim, 1.0 if swimming else 0.0, clampf(delta * 4.0, 0.0, 1.0))
	if _swim > 0.01:
		var moving: bool = player is CharacterBody3D and player.velocity.length() > 0.4
		_stroke = fmod(_stroke + delta * (0.85 if moving else 0.4), 1.0)

	for side in _hands:
		var hand: Dictionary = _hands[side]
		var root: Node3D = hand.root
		var pose: String = pose_right if side > 0.0 else pose_left
		if conjuring:
			pose = "conjure"
		var p: Dictionary = POSES[pose]
		var k := clampf(delta * 10.0, 0.0, 1.0)
		for j in 3:
			_curl[side][j] = lerpf(_curl[side][j], p.curl[j], k)
		_thumb[side] = lerpf(_thumb[side], p.thumb, k)
		_spread[side] = lerpf(_spread[side], p.spread, k)

		if hand.has("sk"):
			for f in 4:
				var extra := f * 3.0 if pose == "relaxed" else 0.0
				for j in 3:
					_bone(hand, "%s_%d" % [FINGER_NAMES[f], j + 1], _curl[side][j] + extra, (f - 1.5) * _spread[side] if j == 0 else 0.0)
			_bone(hand, "thumb_1", _thumb[side] * 0.25)
			_bone(hand, "thumb_2", _thumb[side] * 0.6)
			_bone(hand, "thumb_3", _thumb[side])
		else:
			for f in 4:
				var joints: Array = hand.fingers[f]
				var spread_deg: float = (f - 1.5) * _spread[side] * side
				for j in 3:
					# fingers curl a bit more toward the pinky, like a real resting hand
					var extra := f * 3.0 if pose == "relaxed" else 0.0
					joints[j].rotation_degrees = Vector3(-(_curl[side][j] + extra), spread_deg if j == 0 else 0.0, 0)
			var thumb: Array = hand.thumb
			thumb[1].rotation_degrees.x = -_thumb[side] * 0.6
			thumb[2].rotation_degrees.x = -_thumb[side]

		# placement: rest + walking bob + sway + reach + conjure lift
		var rest: Transform3D = hand.rest
		var bob := Vector3(sin(_t * 9.0 + (0.0 if side > 0.0 else PI)) * 0.006, absf(cos(_t * 9.0)) * 0.008, 0) * clampf(speed / 3.0, 0.0, 1.2)
		var breathe := Vector3(0, sin(_t * 1.6) * 0.003, 0)
		var offset := bob + breathe + Vector3(-_sway.x, _sway.y, 0)
		if side > 0.0 and _reach > 0.0:
			offset += Vector3(-0.04, 0.05, -0.1) * sin(_reach * PI)
		var lift := Vector3.ZERO
		var tremble := Vector3.ZERO
		if conjuring:
			lift = Vector3(-0.05 * side, 0.08, -0.05)
			tremble = Vector3(sin(_t * 31.0), sin(_t * 27.0 + side), 0) * 0.0015
		var swim_rot := 0.0
		if _swim > 0.01 and not (side > 0.0 and pose == "hold"):
			var st := _stroke_at(_stroke)
			var o: Vector3 = st[0]
			offset += Vector3(o.x * side, o.y, o.z) * _swim * (1.0 if speed > 0.3 else 0.6)
			swim_rot = st[1] * side * _swim
		root.position = root.position.lerp(rest.origin + offset + lift + tremble, clampf(delta * 14.0, 0.0, 1.0))
		var target_rot := rest.basis.get_euler() + Vector3(0, 0, deg_to_rad(swim_rot))
		if conjuring:
			target_rot += Vector3(deg_to_rad(15), 0, deg_to_rad(30 * side))
		root.rotation = root.rotation.lerp(target_rot, clampf(delta * 10.0, 0.0, 1.0))
