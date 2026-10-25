extends SceneTree
## GPU pictures of one gorge bank rebuilt from kit pieces, in its place in the
## camp's view (phase-6-design.md 5.7.2, step 1's look review). Needs a
## display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/gorge_bank_preview.gd -- <out dir> <old|kit> [bank seed]
## old: the camp as it is. kit: the bank (vista.gd's seed, default 1, the near
## left one) left out of vista.gd's build and GorgeGrammar's version placed
## instead, on the gorge's render layer. gorge: the whole gorge so (every
## bank, the towers, the aqueducts, the sanctum's tiers), the waterfalls
## through the aqueducts and the rotunda generated as vista.gd does, the
## pieces drawn in batches (KitBatcher). bare: the gorge with none of its
## architecture (what the kit's pieces are measured against). Writes <old|kit>_<view>.png and
## prints the pieces placed:
##   concept  the box-art framing from the overlook (as capture.gd vista_concept)
##   walls    zoomed on the near-left tier walls (capture.gd vista_walls)
##   bank     the whole bank from the overlook

## vista.gd's banks: centre x, z, radii x, z, top, seed.
const BANKS: Array = [[-78, -84, 37, 36, 25, 1], [88, -103, 43, 40, 12, 2], [-65, -140, 32, 37, 39, 3], [67, -163, 37, 42, 35, 4],
	[-76, -204, 43, 41, 29, 5], [83, -223, 41, 41, 46, 6], [-39, -262, 43, 36, 48, 7], [60, -277, 48, 39, 53, 8]]
const EYE: Vector3 = Vector3(-1, 2.25, -27.45)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://gorge_preview"
	var mode: String = args[1] if args.size() > 1 else "kit"
	var seed_value: int = int(args[2]) if args.size() > 2 else 1
	DirAccess.make_dir_recursive_absolute(out_dir)
	var data: Array = BANKS[seed_value - 1]
	var placements: Array[Dictionary] = GorgeGrammar.new().bank(Vector2(data[0], data[1]), data[2], data[3], data[4], data[5])
	var vista: GDScript = load("res://scripts/vista.gd")
	if mode == "kit":
		vista.skip_banks = PackedInt32Array([seed_value])
		vista.extra_lamps = lamps(placements)
	if mode in ["gorge", "bare"]:
		placements = GorgeGrammar.new().gorge(load("res://gen/gorge/gorge_layout.tres")) if mode == "gorge" else ([] as Array[Dictionary])
		vista.skip_banks = PackedInt32Array([1, 2, 3, 4, 5, 6, 7, 8])
		vista.skip_bridges = true
		vista.skip_sanctum_tiers = true
		vista.extra_lamps = lamps(placements)
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.player.blocked = true
	game.hud.toast_time = 0
	game.hud.visible = false
	if mode in ["kit", "gorge"]:
		var placed: Dictionary = place(game.world, placements, mode == "gorge")
		print("gorge_bank_preview: bank %d, %s" % [seed_value, placed])
	var views: Dictionary = {
		"concept": [Vector3(5, -22, -178), 68.0],
		"walls": [Vector3(-46, 14, -84), 26.0],
		"bank": [Vector3(data[0], data[4] - 40.0, data[1]), 44.0],
	}
	for view: String in views:
		game.player.teleport(EYE)
		game.player.camera.fov = views[view][1]
		game.look_toward(views[view][0])
		game.world.elapsed = 1.3
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s/%s_%s.png" % [out_dir, mode, view]
		root.get_texture().get_image().save_png(path)
		print("  %s: %d draw calls -> %s" % [view, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), path])
	quit()


## The lamps among the placements (their glowing boxes; a pavilion's at 3 m),
## for vista_light.gd's cluster lights.
func lamps(placements: Array[Dictionary]) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Dictionary in placements:
		var path: String = p.get("scene", "")
		if path.ends_with("gorge_lamp.tscn"):
			out.append((p["xf"] as Transform3D).origin)
		elif path.contains("gorge_pavilion"):
			out.append((p["xf"] as Transform3D) * Vector3(0, 3.0, 0))
	return out


## Instances the placements under a node on the gorge's render layer; lights
## the way vista.gd's facades made them.
func place(world: Node3D, placements: Array[Dictionary], batched: bool = false) -> Dictionary:
	var holder: Node3D = KitBatcher.new() if batched else Node3D.new()
	if batched:
		(holder as KitBatcher).batch_on_ready = false
	holder.name = "KitBank"
	world.add_child(holder)
	var scenes: Dictionary = {}
	var counts: Dictionary = {"pieces": 0, "lights": 0}
	for p: Dictionary in placements:
		if p.has("light"):
			world.light(p["light"], p["color"], p["energy"], p["range"])
			counts["lights"] += 1
			continue
		if p.has("waterfall"):
			world.art.render_layer = 2
			world.vista.waterfall(p["waterfall"], p["size"], false)
			continue
		if p.has("rotunda"):
			world.art.render_layer = 2
			world.vista.rotunda(p["rotunda"], p["radius"], p["height"])
			continue
		var path: String = p["scene"]
		if not scenes.has(path):
			scenes[path] = load(path)
		var node: Node3D = (scenes[path] as PackedScene).instantiate()
		node.transform = p["xf"]
		holder.add_child(node)
		counts["pieces"] += 1
	for n: Node in holder.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = 2
	world.art.render_layer = 1
	world.art.merge_static_geometry()     # the rotunda and waterfalls, as the camp merges its own
	if batched:
		counts.merge((holder as KitBatcher).batch())
	return counts
