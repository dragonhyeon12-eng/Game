class_name ManifestedObject
extends RigidBody3D
## Something pictured into existence, assembled from the shape parts in data/Manifestations.json.

var def_id := ""
var display_name := ""
var bites_left := 0
var total_bites := 0
var buoyant := false
var _visual := Node3D.new()
var _edible: Array[MeshInstance3D] = []
var _spawn := 0.0
var _age := 0.0
var released := false


func setup(def: Dictionary) -> void:
	def_id = def.get("id", "")
	display_name = def.get("name", "")
	bites_left = int(def.get("bites", 0))
	total_bites = bites_left
	buoyant = int(def.get("buoyant", 0)) != 0
	mass = float(def.get("mass", 0.3))
	collision_layer = 4
	collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(def.get("radius", 0.1))
	shape.shape = sphere
	add_child(shape)
	add_child(_visual)
	_visual.scale = Vector3.ONE * 0.01
	for part in def.get("parts", []):
		var mi := MeshInstance3D.new()
		mi.mesh = Shapes.mesh(part.get("shape", "box"))
		mi.material_override = Shapes.material(Data.col(part.get("color")), 0.55)
		mi.position = Data.vec(part.get("offset"))
		mi.rotation_degrees = Data.vec(part.get("rotation"))
		mi.scale = Data.vec(part.get("scale"), Vector3.ONE * 0.1)
		_visual.add_child(mi)
		if int(part.get("edible", 0)) != 0:
			_edible.append(mi)
	set_held(true)


func set_held(held: bool) -> void:
	released = not held
	freeze = held
	gravity_scale = -0.25 if buoyant else 1.0
	linear_damp = 2.0 if buoyant else 0.1
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = held


func release(impulse: Vector3) -> void:
	var xf := global_transform
	var world := Game.zone if Game.zone else get_tree().current_scene
	get_parent().remove_child(self)
	world.add_child(self)
	global_transform = xf
	set_held(false)
	_age = 0.0
	apply_central_impulse(impulse * mass)


## Returns true when the last bite is taken.
func bite() -> bool:
	if bites_left <= 0:
		return false
	bites_left -= 1
	var remaining := float(bites_left) / maxf(total_bites, 1)
	for p in _edible:
		p.scale *= lerpf(0.55, 0.85, remaining)
	return bites_left == 0


func _process(delta: float) -> void:
	_age += delta
	if _spawn < 1.0:
		# materialise with a soft overshoot instead of popping in
		_spawn = minf(1.0, _spawn + delta / 0.45)
		_visual.scale = Vector3.ONE * maxf(0.01, _spawn * (1.0 + 0.12 * sin(_spawn * PI)))
	if released and _age > 600.0:
		queue_free()
