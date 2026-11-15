class_name Interactable
extends Area3D
## An invisible "use" volume configured with callables by the zone that creates it
## (bed, computer, notebook, doors...). Visual meshes belong to the zone.

var prompt_fn: Callable
var action_fn: Callable
var can_fn: Callable


static func create(size: Vector3, prompt: Callable, action: Callable, can := Callable()) -> Interactable:
	var a := Interactable.new()
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	s.shape = box
	a.add_child(s)
	a.prompt_fn = prompt
	a.action_fn = action
	a.can_fn = can
	return a


func get_prompt() -> String:
	return prompt_fn.call() if prompt_fn.is_valid() else ""


func can_interact() -> bool:
	return can_fn.call() if can_fn.is_valid() else true


func interact() -> void:
	if action_fn.is_valid():
		action_fn.call()
