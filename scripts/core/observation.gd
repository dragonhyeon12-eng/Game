class_name Observation
## "Is the player looking at this?" - the foundation of every unobserved-change mechanic.
## A point is observed if a sphere around it is inside the camera frustum (with a safety margin, so
## nothing ever changes at the edge of the screen) and is not completely hidden behind geometry.

const MARGIN_DEG := 12.0


static func camera() -> Camera3D:
	if Game.player == null:
		return null
	return Game.player.camera


static func in_view(point: Vector3, radius: float, margin_deg := MARGIN_DEG) -> bool:
	var cam := camera()
	if cam == null:
		return false
	var to := point - cam.global_position
	var dist := to.length()
	if dist <= radius + 0.01:
		return true
	var basis := cam.global_transform.basis
	var fwd := -basis.z.dot(to)
	var right := basis.x.dot(to)
	var up := basis.y.dot(to)
	var ang_r := rad_to_deg(asin(clampf(radius / dist, 0.0, 1.0)))
	var vp := cam.get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_v := cam.fov * 0.5   # Godot's Camera3D.fov is vertical by default
	var half_h := rad_to_deg(atan(tan(deg_to_rad(half_v)) * aspect))
	if fwd <= 0.0:
		var behind := rad_to_deg(acos(clampf(fwd / dist, -1.0, 1.0)))
		return behind - ang_r < half_h + margin_deg
	var ah := absf(rad_to_deg(atan2(right, fwd)))
	var av := absf(rad_to_deg(atan2(up, fwd)))
	return ah - ang_r < half_h + margin_deg and av - ang_r < half_v + margin_deg


static func line_clear(from: Vector3, to: Vector3, exclude: Array = []) -> bool:
	var cam := camera()
	if cam == null:
		return false
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # world layer only
	var ex: Array[RID] = []
	if Game.player:
		ex.append(Game.player.get_rid())
	for n in exclude:
		if n is CollisionObject3D:
			ex.append(n.get_rid())
	q.exclude = ex
	return space.intersect_ray(q).is_empty()


static func is_observed(point: Vector3, radius: float, exclude: Array = [], margin_deg := MARGIN_DEG) -> bool:
	if not in_view(point, radius, margin_deg):
		return false
	var eye := camera().global_position
	for p in [point, point + Vector3.UP * radius * 0.8, point - Vector3.UP * radius * 0.6]:
		if line_clear(eye, p, exclude):
			return true
	return false


static func has_line_of_sight(point: Vector3, exclude: Array = []) -> bool:
	var cam := camera()
	return cam != null and line_clear(cam.global_position, point, exclude)
