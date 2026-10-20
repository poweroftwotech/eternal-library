extends SceneTree
## GPU capture of R01 with the generated R02 Stack Gallery off its west door
## (ENVIRONMENT_PLAN.md phase 2; needs a real display, not --headless).
##   godot --path . --resolution 1600x900 --script res://tests/r02_capture.gd -- <out.png> [view] [seed] [options]
## Views (camera in corridor space: x across, -z down the run, from the door):
##   door      from R01's hall through the west door down the corridor
##   corridor  in the first bay, looking down the run
##   back      near the far end, looking back toward R01
##   joint     up at the vault end against R01's wall (the slice 1 risk)
##   plan      high above, looking down (pass "overlay" to see the grid marks)
##   plan_wide the same, higher and centred further out (for winding runs)
##   corner    seed 1: down the first stretch toward its right turn
##   groin     seed 1: up into that corner's groin vault
## Views found from the layout (any seed; slice 3):
##   alcove    from across the bay, into the first side passage
##   collapsed from two bays back, at the first collapsed bay
##   exit      from two bays back, at the exit door
##   falloff   low in the entry bay, down the first stretch (lamp falloff)
##   wear      low in the entry bay, down at the floor (slice 4 FloorWear lanes)
##   wear_alcove  from across the bay, down at the first alcove's floor
## Options (fourth argument, comma separated): overlay, straight=N
## (max_straight_bays for this capture), scene=res://... (capture that scene,
## e.g. a baked room in its host, from the views of the live room of that seed).
## Option wearmap=<png> also saves the shared FloorWear map.
## Run `godot --headless --import` first.

## view -> [from, to, fov, from/to in R01 space instead of corridor space]
const VIEWS: Dictionary = {
	"door": [Vector3(5.5, 1.7, -6.0), Vector3(-30.0, 2.2, -6.0), 66.0, true],
	"corridor": [Vector3(2.0, 1.7, -1.2), Vector3(2.0, 2.4, -40.0), 70.0, false],
	"back": [Vector3(2.0, 1.7, -30.0), Vector3(2.0, 2.4, 6.0), 70.0, false],
	"joint": [Vector3(2.0, 1.5, -3.6), Vector3(2.0, 5.0, 0.2), 74.0, false],
	"plan": [Vector3(2.0, 30.0, -14.0), Vector3(2.0, 0.0, -13.99), 70.0, false],
	"corner": [Vector3(2.0, 1.7, -5.0), Vector3(3.2, 3.2, -14.0), 70.0, false],   # seed 1: down the first stretch to the right turn
	"groin": [Vector3(2.0, 1.4, -11.0), Vector3(2.4, 6.0, -14.4), 80.0, false],  # seed 1: up into the corner's groin vault
	"plan_wide": [Vector3(-8.0, 46.0, -16.0), Vector3(-8.0, 0.0, -15.99), 70.0, false],
}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://r02.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "corridor", VIEWS["corridor"])
	var options: PackedStringArray = args[3].split(",") if args.size() > 3 else PackedStringArray()
	var scene: String = "res://rooms/test/reading_room_r02.tscn"
	for o: String in options:
		if o.begins_with("scene="):
			scene = o.trim_prefix("scene=")
	# The live room (a baked scene is captured from the same views: the live
	# room of that seed places the camera, then the baked one replaces it).
	var room: RoomTemplate = (load("res://rooms/test/reading_room_r02.tscn") as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	if args.size() > 2 and args[2] != "-":
		g.gen_seed = int(args[2])
	g.overlay = options.has("overlay")
	for o: String in options:
		if o.begins_with("straight="):
			var grammar: StackGalleryGrammar = (g.grammar as StackGalleryGrammar).duplicate()
			grammar.max_straight_bays = o.trim_prefix("straight=").to_int()
			g.grammar = grammar
	root.add_child(room)
	var cam := Camera3D.new()
	cam.fov = view[2]
	cam.far = 200.0
	room.add_child(cam)
	var found: Array = layout_view(g, args[1] if args.size() > 1 else "")
	if not found.is_empty():
		view = found
		cam.fov = view[2]
	var from: Vector3 = view[0] if view[3] else g.to_global(view[0])
	var to: Vector3 = view[1] if view[3] else g.to_global(view[1])
	var info: String = "seed %d, %d bays: " % [g.effective_seed(), g.bay_count()]
	if scene != "res://rooms/test/reading_room_r02.tscn":
		root.remove_child(room)
		room.free()
		room = (load(scene) as PackedScene).instantiate()
		root.add_child(room)
		var baked: RoomTemplate = room.get_node("StackGallery")
		info = "%s (baked seed %d), " % [scene, baked.preview_seed]
		cam = Camera3D.new()
		cam.fov = view[2]
		cam.far = 200.0
		room.add_child(cam)
	cam.look_at_from_position(from, to)
	cam.current = true
	for i: int in 100:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	for o: String in options:
		if o.begins_with("wearmap=") and FloorWear.map_image != null:
			FloorWear.map_image.save_png(o.trim_prefix("wearmap="))
			info += "wear map %s m in %.0f ms, " % [FloorWear.map_rect, FloorWear.last_build_ms]
	print("r02_capture: ", info, "saved " + out if err == OK else "FAILED " + error_string(err))
	quit()


## [from, to, fov, false] in corridor space for the views that depend on the
## layout, or [] (not one of them, or the seed lacks that feature).
func layout_view(g: GeneratedRoom, view_name: String) -> Array:
	var grid: CellGrid = g.grid
	var order: Array[Vector3i] = grid.run_order()
	var eye := Vector3(0, 1.6, 0)
	match view_name:
		"alcove":
			for c: Vector3i in order:
				for a: Array in grid.alcoves_of(c):
					var into: Vector3 = CellGrid.cell_centre(a[0]) - CellGrid.cell_centre(c)
					return [CellGrid.cell_centre(c) - into * 0.4 + eye, CellGrid.cell_centre(a[0]) + into * 0.3 + Vector3(0, 1.9, 0), 72.0, false]
		"collapsed", "exit":
			for i: int in order.size():
				var c: Vector3i = order[i]
				var hit: bool = grid.cells[c]["kind"] == "collapsed" if view_name == "collapsed" else i == order.size() - 1
				if not hit:
					continue
				if view_name == "collapsed":
					# From the bay before, low and to one side, across at the other wall.
					var walls: Array[int] = StackGalleryGrammar.side_walls(grid, c)
					var wall: Transform3D = CellGrid.door_transform(c, walls[0])
					var along: Vector3 = Vector3(grid.cells[c]["run"]) * Vector3(1, 0, -1)
					var prev: Vector3 = CellGrid.cell_centre(order[maxi(i - 1, 0)])
					var from: Vector3 = prev - (wall.origin - CellGrid.cell_centre(c)) * 0.45 + Vector3(0, 1.5, 0)
					if (CellGrid.cell_centre(c) - prev).dot(along) < 0.0:
						along = -along
					return [from, wall.origin + along * 0.6 + Vector3(0, 0.7, 0), 70.0, false]
				var back: Vector3i = order[maxi(i - 2, 0)]
				var at: Vector3 = CellGrid.cell_centre(c)
				if view_name == "exit":
					for side: int in CellGrid.ALL_SIDES:
						var e: Dictionary = grid.edge(c, side)
						if not e.is_empty() and e["mark"] == CellGrid.Mark.DOOR and not e["host"]:
							at = CellGrid.door_transform(c, side).origin
				return [CellGrid.cell_centre(back) + eye, at + Vector3(0, 1.4, 0), 70.0, false]
		"wear":
			# Low in the entry bay, down at the floor of the first stretch.
			var far: Vector3i = order[mini(3, order.size() - 1)]
			return [CellGrid.cell_centre(order[0]) + Vector3(0.6, 1.0, 1.4), CellGrid.cell_centre(far) + Vector3(0, 0.2, 0), 64.0, false]
		"wear_alcove":
			# From the far side of the bay, down at the first alcove's floor.
			for c: Vector3i in order:
				for a: Array in grid.alcoves_of(c):
					var into: Vector3 = CellGrid.cell_centre(a[0]) - CellGrid.cell_centre(c)
					return [CellGrid.cell_centre(c) - into * 0.45 + Vector3(0, 1.3, 0), CellGrid.cell_centre(a[0]) + into * 0.1, 68.0, false]
		"falloff":
			var last: Vector3i = order[0]
			for c: Vector3i in order.slice(1):
				last = c
				if grid.cells[c]["kind"] == "corner":
					break
			return [CellGrid.cell_centre(order[0]) + Vector3(0, 1.2, 1.4), CellGrid.cell_centre(last) + Vector3(0, 1.8, 0), 66.0, false]
	return []
