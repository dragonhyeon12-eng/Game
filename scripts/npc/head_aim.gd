class_name HeadAim
extends SkeletonModifier3D
## Turns one bone (the head) by `look` (pitch, yaw in degrees, about the body's own axes) on top of
## whatever the animation is doing. Modifier results are not kept, so it never accumulates.

var bone := -1
var look := Vector3.ZERO
var body: Node3D


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or bone < 0 or body == null or look.is_zero_approx():
		return
	# the body's up / right axes, expressed in skeleton space
	var to_skel := skel.global_transform.basis.inverse() * body.global_transform.basis
	var up := (to_skel * Vector3.UP).normalized()
	var right := (to_skel * Vector3.RIGHT).normalized()
	var turn := Basis(up, deg_to_rad(look.y)) * Basis(right, deg_to_rad(look.x))
	var g := skel.get_bone_global_pose(bone)
	var parent := skel.get_bone_parent(bone)
	var parent_basis := skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var new_global := turn * g.basis
	skel.set_bone_pose_rotation(bone, (parent_basis.orthonormalized().inverse() * new_global.orthonormalized()).get_rotation_quaternion())
