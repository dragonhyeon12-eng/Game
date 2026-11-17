extends Node3D
func _ready() -> void:
	var s := Stalker.new()
	add_child(s)
	await get_tree().process_frame
	var sk: Skeleton3D = s._sk
	for spd in [0.0, 1.6, 3.7]:
		s.speed = spd
		s._held = 0.0
		s._hold_t = 99.0
		for i in 20:
			await get_tree().process_frame
		var hips := sk.get_bone_global_pose(sk.find_bone("hips")).origin
		var chest := sk.get_bone_global_pose(sk.find_bone("chest")).origin
		var head := sk.get_bone_global_pose(sk.find_bone("head")).origin
		var hand := sk.get_bone_global_pose(sk.find_bone("hand.L")).origin
		print("speed %.1f: hips %s chest %s head %s hand.L %s (forward = -Z)" % [spd, hips, chest, head, hand])
	get_tree().quit()
