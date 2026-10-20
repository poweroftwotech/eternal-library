class_name LampTend
extends StaticBody3D
## What the player's ray finds on a lamp (ENVIRONMENT_PLAN.md 6.5.6): a 0.35 m
## sphere at the glass, on the interaction layer only. E lights a dark or
## failing lamp and douses a lit one. Tending is saved as the lamp's state,
## and a tended lamp no longer ages ("darkens untouched lamps only").
## An internal child of the lamp's STATE socket, outside its spawn list, so
## re-resolving the socket keeps it.

const RADIUS: float = 0.35

var room: RoomTemplate
var socket: VariantSocket


## Adds a LampTend to `s` at the middle of its lamp's glowing surfaces.
static func attach(owner_room: RoomTemplate, s: VariantSocket) -> LampTend:
	var lamp: Node = s.get_parent()
	if lamp == null or not lamp is Node3D:
		return null
	var box := AABB()
	var found: bool = false
	for inst: MeshInstance3D in WorldProp.meshes_under(lamp):
		if inst.mesh == null:
			continue
		for i: int in inst.mesh.get_surface_count():
			var mat: Material = inst.mesh.surface_get_material(i)
			if mat != null and mat.resource_name.begins_with("emit_"):
				var b: AABB = WorldProp.relative(s, inst) * inst.mesh.get_aabb()
				box = b if not found else box.merge(b)
				found = true
	if not found:
		return null
	var tend := LampTend.new()
	tend.name = "LampTend"
	tend.room = owner_room
	tend.socket = s
	tend.collision_layer = 2
	tend.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	tend.add_child(shape)
	tend.position = box.get_center()
	s.add_child(tend, false, Node.INTERNAL_MODE_FRONT)
	return tend


func is_lit() -> bool:
	return socket.picked_label() == "lit"


func interaction_prompt(_hit: Vector3) -> String:
	return "Douse the lamp" if is_lit() else "Light the lamp"


func interact(_actor: Node3D, _hit: Vector3) -> void:
	room.tend_lamp(socket, "dark" if is_lit() else "lit")
