class_name Mannequin
extends Node3D
## A shop mannequin: jointed plastic, a smooth egg for a head. It never moves while you can see it.
## Its zone decides when it hunts (see StillLifeZone); this is the body and its poses.
## Origin at the feet, facing +Z.

const POSES := {
	"stand": {"sh": [8, 8], "el": [10, 10], "hip": [0, 0], "kn": [0, 0], "neck": 0, "spread": [10, 10]},
	"hip": {"sh": [-10, 8], "el": [95, 10], "hip": [4, -6], "kn": [8, 0], "neck": 10, "spread": [35, 10]},
	"wave": {"sh": [8, 150], "el": [10, 40], "hip": [0, 0], "kn": [0, 0], "neck": -8, "spread": [10, 20]},
	"point": {"sh": [8, 85], "el": [10, 5], "hip": [6, -4], "kn": [0, 10], "neck": 15, "spread": [10, 5]},
	"reach": {"sh": [80, 85], "el": [15, 10], "hip": [-8, 18], "kn": [15, 4], "neck": 20, "spread": [8, 8]},
	"lunge": {"sh": [100, 60], "el": [30, 50], "hip": [-30, 35], "kn": [50, 10], "neck": 25, "spread": [15, 20]},
	"sit": {"sh": [30, 30], "el": [60, 60], "hip": [88, 88], "kn": [-88, -88], "neck": 0, "spread": [8, 8]},
	"crouch": {"sh": [60, 50], "el": [80, 70], "hip": [100, 95], "kn": [-130, -125], "neck": 30, "spread": [15, 15]},
}

var pose := "stand"
var home := Vector3.ZERO
var hunting := false
var level_y := 0.0
var unseen_t := 0.0
var step_t := 0.0

var _plastic: Material
var _sh: Array[Node3D] = []
var _el: Array[Node3D] = []
var _hip: Array[Node3D] = []
var _kn: Array[Node3D] = []
var _neck: Node3D
var _pelvis: Node3D
var face: Node3D          # painted features, a wig... (the realistic ones)


## realism 0: blank plastic. 1: painted eyes and mouth. 2: and a wig and lips.
func build(col := Color(0.9, 0.86, 0.8), realism := 0, h := 1.0) -> void:
	_plastic = Shapes.material(col, 0.28)
	scale = Vector3.ONE * h
	_pelvis = _pivot(self, Vector3(0, 0.95, 0))
	_mesh(_pelvis, "sphere", Vector3.ZERO, Vector3(0.32, 0.2, 0.2))
	var chest := _pivot(_pelvis, Vector3(0, 0.05, 0))
	_mesh(chest, "capsule", Vector3(0, 0.27, 0), Vector3(0.3, 0.26, 0.19))
	_mesh(chest, "sphere", Vector3(0, 0.46, 0), Vector3(0.38, 0.14, 0.2))
	_neck = _pivot(chest, Vector3(0, 0.56, 0))
	_mesh(_neck, "cylinder", Vector3(0, 0.05, 0), Vector3(0.08, 0.12, 0.08))
	_mesh(_neck, "sphere", Vector3(0, 0.22, 0.01), Vector3(0.19, 0.26, 0.21))       # the egg
	face = Node3D.new()
	_neck.add_child(face)
	if realism >= 1:
		for s in [-1.0, 1.0]:
			_mesh(face, "sphere", Vector3(0.045 * s, 0.25, 0.1), Vector3(0.04, 0.022, 0.012), Shapes.material(Color(0.08, 0.06, 0.05), 0.3))
			_mesh(face, "box", Vector3(0.045 * s, 0.28, 0.1), Vector3(0.05, 0.008, 0.01), Shapes.material(Color(0.25, 0.18, 0.12)))
		_mesh(face, "box", Vector3(0, 0.155, 0.105), Vector3(0.06, 0.012, 0.01), Shapes.material(Color(0.55, 0.2, 0.2) if realism >= 2 else Color(0.3, 0.25, 0.22)))
	if realism >= 2:
		_mesh(face, "sphere", Vector3(0, 0.3, -0.02), Vector3(0.21, 0.2, 0.23), Shapes.material(Color(0.2, 0.13, 0.08), 0.7))
	for side in [-1.0, 1.0]:
		var sh := _pivot(chest, Vector3(0.2 * side, 0.44, 0))
		_mesh(sh, "sphere", Vector3.ZERO, Vector3.ONE * 0.08)
		_mesh(sh, "capsule", Vector3(0, -0.15, 0), Vector3(0.075, 0.15, 0.075))
		var el := _pivot(sh, Vector3(0, -0.3, 0))
		_mesh(el, "sphere", Vector3.ZERO, Vector3.ONE * 0.06)
		_mesh(el, "capsule", Vector3(0, -0.14, 0), Vector3(0.06, 0.14, 0.06))
		_mesh(el, "capsule", Vector3(0, -0.32, 0.01), Vector3(0.06, 0.05, 0.03))    # a hand like a paddle
		_sh.append(sh)
		_el.append(el)
		var hip := _pivot(_pelvis, Vector3(0.1 * side, -0.05, 0))
		_mesh(hip, "capsule", Vector3(0, -0.22, 0), Vector3(0.11, 0.22, 0.11))
		var kn := _pivot(hip, Vector3(0, -0.45, 0))
		_mesh(kn, "sphere", Vector3.ZERO, Vector3.ONE * 0.08)
		_mesh(kn, "capsule", Vector3(0, -0.21, 0), Vector3(0.08, 0.21, 0.08))
		_mesh(kn, "capsule", Vector3(0, -0.44, 0.05), Vector3(0.07, 0.05, 0.12))
		_hip.append(hip)
		_kn.append(kn)
	set_pose(pose)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, kind: String, pos: Vector3, s: Vector3, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.mesh(kind)
	mi.position = pos
	mi.scale = s
	mi.material_override = mat if mat else _plastic
	parent.add_child(mi)
	return mi


func set_pose(name: String) -> void:
	pose = name
	var p: Dictionary = POSES.get(name, POSES.stand)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_sh[i].rotation_degrees = Vector3(-float(p.sh[i]), 0, side * float(p.spread[i]))
		_el[i].rotation_degrees = Vector3(-float(p.el[i]), 0, 0)
		_hip[i].rotation_degrees = Vector3(-float(p.hip[i]), 0, 0)
		_kn[i].rotation_degrees = Vector3(-float(p.kn[i]), 0, 0)
	_neck.rotation_degrees = Vector3(float(p.neck), randf_range(-25, 25), randf_range(-8, 8))
	_pelvis.position.y = 0.95 if name != "crouch" else 0.5
	if name == "sit":
		_pelvis.position.y = 0.55


func head_position() -> Vector3:
	return _neck.global_position + Vector3(0, 0.2 * scale.y, 0)


func face_toward(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() > 0.05:
		rotation.y = atan2(to.x, to.z)
