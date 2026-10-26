extends SceneTree
## Copies the gorge's finished materials out of the camp into the kit's
## material library (phase-6-design.md 5.7.2, 5.7.10), so kit pieces modelled
## to the gorge's shapes look as the gorge does today.
##   godot --headless --path . --script res://tools/gorge_materials.gd [-- --force] [--only=<kit name>,...]
## Boots the camp (which builds the gorge with vista.gd and then runs every art
## pass over it), takes each material from the camp's factory after the passes,
## and saves it as kit/materials/<kit name>.tres. Kit names carry a gorge_
## prefix: the kit already has its own moss, wood, tile, brass and cloth. A
## material already in the library is kept (it's yours to tweak after the
## first run) unless --force. --only= copies just the named ones
## (with --force, overwriting them).

## kit material name -> the camp factory's material name.
const NAMES: Dictionary = {
	"gorge_sandstone": "sandstone",
	"gorge_faience": "exterior_faience",
	"gorge_gold": "vista_gold",
	"gorge_limestone": "limestone",
	"gorge_pier": "gorge_pier",
	"gorge_stone": "gorge_stone",
	"gorge_stone_aged": "gorge_stone_aged",
	"gorge_stone_clean": "gorge_stone_clean",
	"gorge_stacks": "gorge_stacks",
	"gorge_stacks_near": "gorge_stacks_near",
	"gorge_window": "vista_window",
	"gorge_lit_window": "lit_window",
	"gorge_portal": "gorge_portal",
	"gorge_background": "gorge_background",
	"gorge_grime": "vista_grime",
	"gorge_repair": "vista_repair",
	"gorge_moss": "moss",
	"gorge_wood": "wood",
	"gorge_rug": "rug",
	"gorge_cloth": "cloth",
	"gorge_brass": "brass",
	"gorge_tile": "tile",
	"gorge_lamp": "vista_lamp",
	"gorge_dome": "vista_dome",
	"gorge_cypress": "vista_cypress",
	"gorge_carpet": "vista_carpet",
	"gorge_relief": "wing_relief",
	"gorge_tapestry_0": "tapestry_0",
	"gorge_tapestry_1": "tapestry_1",
	"gorge_tapestry_2": "tapestry_2",
	"gorge_vine": "vine",
	"gorge_leaf": "leaf",
}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 3:
		await process_frame
	var art: Object = game.world.art
	var saved: PackedStringArray = []
	var kept: PackedStringArray = []
	var missing: PackedStringArray = []
	for kit_name: String in NAMES:
		if not only.is_empty() and not only.has(kit_name):
			continue
		var path: String = "res://kit/materials/%s.tres" % kit_name
		if ResourceLoader.exists(path) and not force:
			kept.append(kit_name)
			continue
		var source: String = NAMES[kit_name]
		if not art.materials.has(source):
			missing.append(source)
			continue
		var copy: Material = (art.materials[source] as Material).duplicate()
		copy.resource_name = kit_name
		var err: Error = ResourceSaver.save(copy, path)
		if err != OK:
			missing.append("%s (%s)" % [kit_name, error_string(err)])
			continue
		saved.append(kit_name)
	print("gorge_materials: saved %d, kept %d%s" % [saved.size(), kept.size(), "; not found: " + ", ".join(missing) if not missing.is_empty() else ""])
	quit(1 if not missing.is_empty() else 0)
