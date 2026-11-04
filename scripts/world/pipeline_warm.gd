class_name PipelineWarm
extends Node3D
## Draws pieces once while a place settles, so their shader pipelines compile
## on arrival instead of on the frame you first see one (room rework step 2:
## the working niches' camp, court and weaving materials cost 20 pipelines and
## an 8.3 ms frame in the stacks, over the 8 ms gate). Their meshes only, at
## 1/1000 scale just in front of the camera, for FRAMES frames: no lights, no
## scripts, no collision.

const FRAMES: int = 3
## What the niches and the caravanserai cells bring that the rooms around
## them don't use.
const SCENES: PackedStringArray = [
	"res://kit/dressing/niche_hearth.tscn", "res://kit/dressing/niche_garden.tscn",
	"res://kit/dressing/niche_larder.tscn", "res://kit/dressing/niche_art_0.tscn",
	"res://kit/dressing/niche_art_1.tscn", "res://kit/dressing/niche_art_2.tscn",
	"res://kit/dressing/recess_hearth.tscn", "res://kit/dressing/recess_herbs.tscn",
	"res://kit/dressing/recess_pantry.tscn",
	"res://kit/dressing/court_cell_sitting.tscn", "res://kit/dressing/court_cell_cooking.tscn",
	"res://kit/dressing/court_cell_garden.tscn", "res://kit/dressing/court_cell_reading.tscn",
	"res://kit/modules/dressing/wall_paddy.tscn", "res://kit/modules/dressing/wall_nets.tscn",
	"res://kit/modules/dressing/wall_traps.tscn", "res://kit/modules/dressing/wall_grotto.tscn",
	"res://kit/modules/dressing/glow_roots_dome.tscn",
]

var _left: int = FRAMES


## Adds a warmer of SCENES under `parent`.
static func add(parent: Node) -> PipelineWarm:
	var w := PipelineWarm.new()
	w.name = "PipelineWarm"
	for path: String in SCENES:
		var src: Node = (load(path) as PackedScene).instantiate()
		for n: Node in src.find_children("*", "MeshInstance3D", true, false):
			var m := n as MeshInstance3D
			if m.mesh == null:
				continue
			var copy := MeshInstance3D.new()
			copy.mesh = m.mesh
			copy.material_override = m.material_override
			for i: int in m.get_surface_override_material_count():
				copy.set_surface_override_material(i, m.get_surface_override_material(i))
			copy.scale = Vector3.ONE * 0.001
			w.add_child(copy)
		src.free()
	parent.add_child(w)
	return w


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		global_transform = cam.global_transform.translated_local(Vector3(0, 0, -0.5))
	_left -= 1
	if _left <= 0:
		queue_free()
