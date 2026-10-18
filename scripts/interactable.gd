extends StaticBody3D
var interaction_id: String = ""
var title: String = ""

func get_interaction_id() -> String:
	return interaction_id

func configure(id: String, label: String, size: Vector3) -> void:
	interaction_id = id
	title = label
	collision_layer = 2
	collision_mask = 0
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	collision.shape = box
	add_child(collision)
