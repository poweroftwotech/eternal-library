class_name HomeDoor
extends StaticBody3D
## A house door that opens (phase 14 step 3, Q1: you walk straight into a home).
## Its origin is the hinge, the leaf along +X when shut, swinging into the house
## so it never sweeps the lane. The leaf and its shape turn inside the body: the
## body keeps the frame the room placed it in. E opens and shuts it. Doors aren't saved: they
## are as the room built them each time.

const LEAF: String = "res://kit/modules/walls/qt_home_leaf.tscn"
## The leaf's size, and how far it swings (to +Z, into the room).
const WIDTH: float = 1.3
const HEIGHT: float = 2.5
const OPEN_ANGLE: float = -88.0
const AJAR_ANGLE: float = -38.0
const SWING_TIME: float = 0.45

## Left ajar (an abandoned home).
@export var ajar: bool = false

var _open: bool = false
var _angle: float = 0.0
var _leaf: Node3D
var _shape: CollisionShape3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 1 | 2     # the world, and what the interaction ray finds
	collision_mask = 0
	_leaf = (load(LEAF) as PackedScene).instantiate()
	add_child(_leaf)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, 0.08)
	_shape.shape = box
	add_child(_shape)
	_swing(AJAR_ANGLE if ajar else 0.0)
	_open = ajar


func interaction_prompt(_hit: Vector3) -> String:
	return "Shut the door" if _open else "Open the door"


func interact(_actor: Node3D, _hit: Vector3) -> void:
	set_open(not _open)


## Swings the leaf. It doesn't block you while it moves, so it can't shut you
## in the wall.
func set_open(on: bool, at_once: bool = false) -> void:
	_open = on
	var to: float = OPEN_ANGLE if on else 0.0
	if _tween != null:
		_tween.kill()
	if at_once:
		_swing(to)
		_shape.disabled = false
		return
	_shape.disabled = true
	_tween = create_tween()
	_tween.tween_method(_swing, _angle, to, SWING_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: _shape.disabled = false)


func _swing(degrees: float) -> void:
	_angle = degrees
	var turn := Basis(Vector3.UP, deg_to_rad(degrees))
	_leaf.basis = turn
	_shape.transform = Transform3D(turn, turn * Vector3(WIDTH * 0.5, HEIGHT * 0.5, 0.0))
