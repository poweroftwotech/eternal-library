class_name DoorSeal
extends StaticBody3D
## Closes a doorway whose room on the far side isn't built yet
## (phase-4-design.md 8.1.4): a blocker and a dark card one metre past the
## door. With rooms loading two doorways ahead you should never reach one;
## if you do, you stop at a dark arch instead of walking into nothing.
## AreaStreamer adds and frees them; they belong to the Area, not a room.
##
## The card's mesh, material and the box are shared by every seal: a new
## material per seal cost 20-25 ms on the GPU each time one appeared.

const SIZE := Vector3(3.6, 4.0, 0.4)
const DEPTH: float = 1.0

static var _box: BoxShape3D
static var _quad: QuadMesh


## A seal on the doorway `door` (a connector of the live room: -Z points out
## of it, into the room that isn't there).
static func make(door: Transform3D) -> DoorSeal:
	if _quad == null:
		_box = BoxShape3D.new()
		_box.size = SIZE
		_quad = QuadMesh.new()
		_quad.size = Vector2(SIZE.x + 1.0, SIZE.y + 2.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.01, 0.012, 0.014)
		_quad.material = mat
	var seal := DoorSeal.new()
	seal.transform = door * Transform3D(Basis(), Vector3(0, 0, -DEPTH))
	var shape := CollisionShape3D.new()
	shape.shape = _box
	shape.position = Vector3(0, SIZE.y * 0.5, 0)
	seal.add_child(shape)
	var card := MeshInstance3D.new()
	card.mesh = _quad
	card.position = Vector3(0, _quad.size.y * 0.5, 0)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.add_child(card)
	return seal
