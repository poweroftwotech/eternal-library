class_name QuietWall
extends Node3D
## A kit wall piece with the Cistern's glowing fungus taken off, for a room where
## that light doesn't belong (the hunter's home in the Domicile Quarter).

## What comes off: lights, and meshes whose names end in one of these.
const GLOW_PARTS: PackedStringArray = ["brackets", "caps", "gills", "stalks", "water", "glowcaps"]

@export var scene: PackedScene


func _ready() -> void:
	var piece: Node = scene.instantiate()
	add_child(piece)
	for n: Node in piece.find_children("*", "", true, false):
		if n is Light3D or (n is MeshInstance3D and String(n.name).get_slice("__", 1) in GLOW_PARTS):
			n.queue_free()
