extends SceneTree
## Phase 1 step 5 gate: Validate Room (KitValidateRoom). Real rooms pass with
## no errors; deliberately broken copies fail with the right message.
##   godot --headless --path . --script res://tests/validate_room_test.gd

const GRAYBOX: String = "res://rooms/test/kit_graybox.tscn"
const ROOM: String = "res://rooms/authored/reading_room.tscn"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	check_clean_rooms()
	check_missing_wall()
	check_gallery_does_not_close()
	check_missing_gable()
	check_connector_closes_half_an_opening()
	check_off_grid_connector()
	check_candidate_misfit()
	check_spill_inside_solid()
	check_spill_over_nothing()
	check_decal_second_surface()
	check_open_stairs()
	await check_in_tree()
	print("validate_room_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func fresh(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate()


func errors_of(room: Node) -> PackedStringArray:
	return KitValidateRoom.run(room)["errors"]


func check_clean_rooms() -> void:
	for path: String in [GRAYBOX, ROOM]:
		var room: Node3D = fresh(path)
		var r: Dictionary = KitValidateRoom.run(room)
		check((r["errors"] as PackedStringArray).is_empty(), "%s validates with no errors (%s)" % [path.get_file(), r["errors"]])
		var warnings: PackedStringArray = r["warnings"]
		if path == ROOM:
			check(warnings.is_empty(), "the reading room has no warnings (%s)" % [warnings])
		else:
			# Known graybox layout conflict: its side galleries run to the end wall,
			# so the slab ends pass in front of the upper end-wall recess, and a rail
			# baluster stands in reach of the upper plain end wall's stains (item 3).
			check(warnings.size() == 3 and Array(warnings).all(func(w: String) -> bool: return w.contains("gallery_slab") and (w.contains("wall_shelfbay_4m10") or w.contains("wall_plain_4m5"))),
				"graybox warns only about galleries meeting its upper end wall (%s)" % [warnings])
		room.free()


## West wall, storey 0, bay 0 of the graybox (x = 0, z -4..0).
func west_bay0(room: Node) -> Node3D:
	for m: Node in room.get_node("Shell").get_children():
		var n := m as Node3D
		if n is KitModule and (n as KitModule).shape == KitModule.Shape.EDGE \
				and n.position.is_equal_approx(Vector3(0, 0, -4)) and is_equal_approx(n.rotation_degrees.y, -90.0):
			return n
	return null


func check_missing_wall() -> void:
	var room: Node3D = fresh(GRAYBOX)
	var wall: Node3D = west_bay0(room)
	check(wall != null, "found the graybox west wall, bay 0")
	if wall != null:
		wall.get_parent().remove_child(wall)
		wall.free()
		var errs: PackedStringArray = errors_of(room)
		var open: Array = Array(errs).filter(func(e: String) -> bool: return e.begins_with("storey 0: open edge (0.0,"))
		check(open.size() == 2, "removing a 4 m wall opens two 2 m segments on storey 0 (got %s)" % [errs])
	room.free()


func check_gallery_does_not_close() -> void:
	var room: Node3D = fresh(GRAYBOX)
	var wall: Node3D = west_bay0(room)
	if wall != null:
		var xf: Transform3D = wall.transform
		wall.get_parent().remove_child(wall)
		wall.free()
		var slab: Node3D = (load("res://kit/modules/walls/gallery_slab_4m.tscn") as PackedScene).instantiate()
		slab.transform = xf
		room.get_node("Shell").add_child(slab)
		check(errors_of(room).size() == 2, "a gallery slab on that edge does not count as a wall")
	room.free()


func check_missing_gable() -> void:
	var room: Node3D = fresh(GRAYBOX)
	var gable: Node = null
	for m: Node in room.get_node("Shell").get_children():
		if m is KitModule and (m as KitModule).edge == "gable":
			gable = m
			break
	check(gable != null, "found a graybox gable")
	if gable != null:
		gable.get_parent().remove_child(gable)
		gable.free()
		var errs: PackedStringArray = errors_of(room)
		check(errs.size() == 2 and Array(errs).all(func(e: String) -> bool: return e.contains("vault end") and e.contains("no gable")),
			"removing a gable reports both 2 m halves of that vault end (got %s)" % [errs])
	room.free()


## The reading room's west door connector sits at z -6: without the arch
## module only the half it marks (z -6..-4) counts as closed.
func check_connector_closes_half_an_opening() -> void:
	var room: Node3D = fresh(ROOM)
	var arch: Node3D = null
	for m: Node in room.get_node("Shell").get_children():
		var n := m as Node3D
		if n is KitModule and (n as KitModule).edge == "opening_3m" and n.position.is_equal_approx(Vector3(0, 0, -8)):
			arch = n
	check(arch != null, "found the reading room's west door arch")
	if arch != null:
		arch.get_parent().remove_child(arch)
		arch.free()
		var errs: PackedStringArray = errors_of(room)
		check(errs.size() == 1 and errs[0].contains("(0.0, -8.0)-(0.0, -6.0)"),
			"without the arch, only the half the connector doesn't mark is open (got %s)" % [errs])
	room.free()


func check_off_grid_connector() -> void:
	var room: Node3D = fresh(ROOM)
	var m := Marker3D.new()
	m.name = "SNAP_stray"
	m.position = Vector3(1.3, 0, -2.0)
	room.get_node("Connectors").add_child(m)
	var errs: PackedStringArray = errors_of(room)
	check(Array(errs).any(func(e: String) -> bool: return e.contains("SNAP_stray") and e.contains("not on a cell boundary")),
		"an off-grid connector is reported (got %s)" % [errs])
	room.free()


func check_candidate_misfit() -> void:
	var set := SocketSet.new()
	set.slot_bounds = AABB(Vector3(-1.0, 0, -0.5), Vector3(2.0, 2.0, 0.8))
	var e := SocketEntry.new()
	e.label = "tile panel"
	e.scene = load("res://kit/modules/dressing/recess_tile_panel.tscn")
	set.entries.append(e)
	var misfits: PackedStringArray = KitValidateRoom.candidate_misfits(set)
	check(misfits.size() == 1 and misfits[0].contains("tile panel"), "a candidate larger than its slot is reported (got %s)" % [misfits])
	# The fallen books must be measured (headless, MultiMesh reads back empty;
	# step 5 missed this until the editor showed it).
	var fallen: Node = load("res://kit/dressing/recess_books_fallen.tscn").instantiate()
	var box: AABB = KitValidateRoom.visual_bounds(fallen)
	fallen.free()
	check(box.position.z < -1.0 and box.position.z > -1.35 and absf(box.position.x) <= 1.5 and box.end.x <= 1.5,
		"collapsed spill is measured and stays in its slot (%s)" % box)
	for set_name: String in ["recess_library", "iwan_centre", "table_props"]:
		var real: SocketSet = load("res://kit/sockets/%s.tres" % set_name)
		check(real.slot_bounds.has_volume() and KitValidateRoom.candidate_misfits(real).is_empty(),
			"every %s candidate fits its slot" % set_name)


## A lower west recess of the reading room (bay 0, storey 0).
func lower_west_recess(room: Node) -> Node3D:
	for m: Node in room.get_node("Shell").get_children():
		var n := m as Node3D
		if n is KitModule and n.scene_file_path.ends_with("wall_shelfbay_4m.tscn") and n.position.is_equal_approx(Vector3(0, 0, -4)):
			return n
	return null


## A pier standing in the recess's spill zone is reported; a reading table is
## not (its top is above the zone, so spill lands on the floor under it).
func check_spill_inside_solid() -> void:
	var room: Node3D = fresh(ROOM)
	check(lower_west_recess(room) != null, "found the reading room's lower west recess, bay 0")
	var table: Node3D = (load("res://kit/modules/walls/table_reading.tscn") as PackedScene).instantiate()
	table.position = Vector3(1.0, 0, -2.0)
	room.get_node("Dressing").add_child(table)
	var warnings: PackedStringArray = KitValidateRoom.run(room)["warnings"]
	check(not Array(warnings).any(func(w: String) -> bool: return w.contains("spill")),
		"a table over the spill zone is fine, spill lands under it (got %s)" % [warnings])
	table.get_parent().remove_child(table)
	table.free()
	var pier: Node3D = (load("res://kit/modules/walls/post_pier.tscn") as PackedScene).instantiate()
	pier.name = "post_pier_stray"
	pier.position = Vector3(1.0, 0, -2.0)
	room.get_node("Shell").add_child(pier)
	warnings = KitValidateRoom.run(room)["warnings"]
	check(Array(warnings).any(func(w: String) -> bool: return w.contains("items would rest inside") and w.contains("post_pier")),
		"a pier inside the spill zone is reported (got %s)" % [warnings])
	room.free()


## No floor cell in front of the recess: spill has nothing to land on.
func check_spill_over_nothing() -> void:
	var room: Node3D = fresh(ROOM)
	for m: Node in room.get_node("Shell").get_children():
		var n := m as Node3D
		if n is KitModule and n.scene_file_path.ends_with("floor_4m.tscn") and n.position.is_equal_approx(Vector3(0, 0, 0)):
			n.get_parent().remove_child(n)
			n.free()
	var warnings: PackedStringArray = KitValidateRoom.run(room)["warnings"]
	check(Array(warnings).any(func(w: String) -> bool: return w.contains("find nothing to land on")),
		"spill over a missing floor is reported (got %s)" % [warnings])
	room.free()


## Item 3: a floor raised 0.12 m into a cell's decal reach is another surface
## facing the decals, so cracks would climb onto it; level floors are fine.
func check_decal_second_surface() -> void:
	var room: Node3D = fresh(ROOM)
	var step: Node3D = (load("res://kit/modules/walls/floor_4m.tscn") as PackedScene).instantiate()
	step.name = "floor_raised"
	step.position = Vector3(5.5, 0.12, -10.0)
	room.get_node("Shell").add_child(step)
	var warnings: PackedStringArray = KitValidateRoom.run(room)["warnings"]
	check(Array(warnings).any(func(w: String) -> bool: return w.contains("floor_wear decals would also mark Shell/floor_raised")),
		"a raised floor in a cell's decal reach is reported (got %s)" % [warnings])
	room.free()


## Item 4: with both stairs pinned to the open wooden look the reading room
## validates as cleanly as with masonry (the look never touches collision).
func check_open_stairs() -> void:
	var room: RoomTemplate = fresh(ROOM)
	var lib: SocketSet = load("res://kit/sockets/stair_style.tres")
	var pins: Dictionary[String, int] = {}
	var stone: Dictionary[String, int] = {}
	pins.assign(room.socket_pins)
	stone.assign(room.socket_pins)
	var pinned: int = 0
	for key: String in room.socket_pins:
		if key.ends_with("/SOCKET_stair_style"):
			pins[key] = lib.index_of("open wood")
			stone[key] = lib.index_of("masonry")
			pinned += 1
	# Polish slice A: masonry claims its whole wall base (and, polish 1c, the
	# 0.6 m at its head where a gallery column would stand); open wood claims only
	# its low end, where nothing fits under it.
	room.socket_pins = stone
	var spans: Array = KitValidateRoom._claims(room).map(func(c: Array) -> float: return snappedf((c[1] as AABB).size.z, 0.01))
	spans.sort()
	check(spans == [0.6, 0.6, 8.0, 8.0], "masonry stairs each claim 8 m of wall base and their head (%s)" % [spans])
	room.socket_pins = pins
	spans = KitValidateRoom._claims(room).map(func(c: Array) -> float: return (c[1] as AABB).size.z)
	check(spans.size() == 2 and spans.all(func(z: float) -> bool: return is_equal_approx(z, 1.6)), "open stairs each claim only their 1.6 m low end (%s)" % [spans])
	var r: Dictionary = KitValidateRoom.run(room)
	check(pinned == 2 and (r["errors"] as PackedStringArray).is_empty() and (r["warnings"] as PackedStringArray).is_empty(),
		"with open stairs the reading room validates clean (%d pinned, %s)" % [pinned, r])
	room.free()


## Loose ends: run on R01 in the tree (sockets spawned), the corner columns'
## arches stay clear of the bay-0 recesses, so the room is as clean as unresolved.
func check_in_tree() -> void:
	var room: Node3D = fresh(ROOM)
	root.add_child(room)
	await process_frame
	var r: Dictionary = KitValidateRoom.run(room)
	check((r["errors"] as PackedStringArray).is_empty() and (r["warnings"] as PackedStringArray).is_empty(),
		"the reading room in the tree validates clean (%s)" % [r])
	room.queue_free()
	await process_frame
