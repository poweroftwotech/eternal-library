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
	"res://kit/modules/walls/cone_garden100.tscn", "res://kit/modules/walls/cone_garden120.tscn",
	"res://kit/modules/walls/cone_vine_a.tscn", "res://kit/modules/walls/cone_vines_oculus.tscn",
	"res://kit/modules/dressing/niche_planter.tscn", "res://kit/modules/dressing/niche_urn.tscn",
	# Room rework step 6, final look: the light-well's beds, nook, glowing
	# vines, rail planters, stair-wall fills and its orosi glass (a storey
	# piece with taghcheh carries the glass's shader).
	"res://kit/modules/walls/cone_mushbed_a.tscn", "res://kit/modules/walls/cone_nook.tscn",
	"res://kit/modules/walls/cone_glowvines.tscn", "res://kit/modules/walls/cone_rail_planter.tscn",
	"res://kit/modules/dressing/stair_case_plant.tscn", "res://kit/modules/dressing/stair_case_deco.tscn",
	"res://kit/modules/dressing/cubby_vase.tscn", "res://kit/modules/dressing/cubby_fern.tscn",
	"res://kit/modules/dressing/cubby_glow.tscn", "res://kit/modules/walls/cone_c75_closed.tscn",
	# Phase 13 step 2, the Garden Court (its frame gate: entering it compiled
	# 34 pipelines in one 224 ms frame): its shell, beds, trees and dressing.
	"res://kit/modules/walls/garden_shaft_5x5.tscn", "res://kit/modules/walls/garden_iwan.tscn",
	"res://kit/modules/walls/garden_talar_bay.tscn", "res://kit/modules/walls/garden_talar_corner.tscn",
	"res://kit/modules/walls/garden_talar_door.tscn", "res://kit/modules/walls/garden_corridor_4m.tscn",
	"res://kit/modules/walls/garden_rill_4m.tscn", "res://kit/modules/walls/garden_rill_dry_4m.tscn",
	"res://kit/modules/walls/garden_bed_4m.tscn", "res://kit/modules/walls/garden_bed_wild_4m.tscn",
	"res://kit/modules/walls/garden_bed_clip_4m.tscn", "res://kit/modules/walls/garden_bed_clip_wild_4m.tscn",
	"res://kit/modules/dressing/garden_pool.tscn", "res://kit/modules/dressing/garden_pool_dry.tscn",
	"res://kit/modules/dressing/garden_tree_old.tscn", "res://kit/modules/dressing/garden_tree_old_wild.tscn",
	"res://kit/modules/dressing/garden_column.tscn", "res://kit/modules/dressing/garden_column_ivy_0.tscn",
	"res://kit/modules/dressing/garden_column_ivy_1.tscn", "res://kit/modules/dressing/garden_talar_vines.tscn",
	"res://kit/modules/dressing/garden_planter.tscn", "res://kit/modules/dressing/garden_planter_wild.tscn",
	"res://kit/modules/dressing/garden_shrub.tscn", "res://kit/modules/dressing/garden_bench.tscn",
	"res://kit/modules/dressing/garden_niche_shelves.tscn", "res://kit/modules/dressing/garden_traces.tscn",
	"res://kit/modules/dressing/garden_traces_old.tscn",
	# Phase 13 step 4, the Fungus Terraces: their shell, patches, workers and things.
	"res://kit/modules/walls/ft_row_0.tscn", "res://kit/modules/walls/ft_foot.tscn",
	"res://kit/modules/dressing/ft_patch_wild.tscn", "res://kit/modules/dressing/ft_patch_blight.tscn",
	"res://kit/modules/dressing/ft_worker_stoop.tscn", "res://kit/modules/dressing/ft_bed_tools.tscn",
	"res://kit/modules/dressing/ft_shelter.tscn",
	# Phase 14, the Domicile Quarter: its homes and people.
	"res://kit/modules/walls/qt_home_2.tscn", "res://kit/modules/walls/qt_home_leaf.tscn",
	"res://kit/modules/walls/qt_fig_stand.tscn", "res://kit/modules/walls/qt_fig_jar.tscn",
	"res://kit/modules/walls/qt_rags.tscn",
]

var _left: int = FRAMES


## Adds a warmer of SCENES under `parent`.
static func add(parent: Node) -> PipelineWarm:
	var w := PipelineWarm.new()
	w.name = "PipelineWarm"
	for path: String in SCENES:
		if not ResourceLoader.exists(path):
			continue     # a room type taken out of the game: nothing to warm
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
	for p: GPUParticles3D in ConeDrips.warm():     # the light-well's water
		p.scale = Vector3.ONE * 0.001
		w.add_child(p)
	for p: GPUParticles3D in GardenCourtLife.warm():     # the Garden Court's petals, leaves and moths
		p.scale = Vector3.ONE * 0.001
		w.add_child(p)
	for p: GPUParticles3D in FungusTerracesLife.warm():     # the Fungus Terraces' spores
		p.scale = Vector3.ONE * 0.001
		w.add_child(p)
	for p: GPUParticles3D in OssuaryLife.warm():     # the Ossuary's falling dust
		p.scale = Vector3.ONE * 0.001
		w.add_child(p)
	for p: GPUParticles3D in QuarterLife.warm():     # the Domicile Quarter's smoke
		p.scale = Vector3.ONE * 0.001
		w.add_child(p)
	for p: GPUParticles3D in BazaarLife.warm():     # the Grand Bazaar's dust
		p.scale = Vector3.ONE * 0.001
		w.add_child(p)
	parent.add_child(w)
	return w


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		global_transform = cam.global_transform.translated_local(Vector3(0, 0, -0.5))
	_left -= 1
	if _left <= 0:
		queue_free()
