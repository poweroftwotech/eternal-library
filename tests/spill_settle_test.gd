extends SceneTree
## Weathering slice item 0: collapsed-recess spill lands on the floor that is
## there. Every recess in the reading room is pinned to "collapsed"; after the
## physics frames, spill in front of the wall face must rest on the hall floor
## (y 0), a gallery slab (4.15), a stair, or drop from an upper recess with
## nothing in front to the floor below. Nothing floats, nothing sinks.
##   godot --headless --path . --script res://tests/spill_settle_test.gd

const ROOM: String = "res://rooms/authored/reading_room.tscn"
const GALLERY_TOP: float = 4.15
const TOL: float = 0.02

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var room: RoomTemplate = (load(ROOM) as PackedScene).instantiate()
	var lib: SocketSet = load("res://kit/sockets/recess_library.tres")
	var collapsed: int = lib.index_of("collapsed")
	var pins: Dictionary[String, int] = {}
	pins.assign(room.socket_pins)
	var recesses: Array[VariantSocket] = []
	for s: VariantSocket in room.sockets():
		if s.socket_set == lib:
			recesses.append(s)
	root.add_child(room)
	for s: VariantSocket in recesses:
		pins[room.socket_key(s)] = collapsed
	room.socket_pins = pins
	room.resolve_sockets(room.preview_seed)
	for _i: int in 6:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var landed: Dictionary = {"floor": 0, "gallery": 0, "stair": 0, "dropped a storey": 0}
	var bad: PackedStringArray = []
	var boards_settled: int = 0
	for s: VariantSocket in recesses:
		var fill: ShelfFill = null
		for c: Node in s.get_children(true):
			if c is ShelfFill:
				fill = c
		if fill == null:
			bad.append("%s: no ShelfFill after pinning collapsed" % room.socket_key(s))
			continue
		var upper: bool = s.global_position.y > 2.0
		for i: int in fill.spill_rest:
			var xf: Transform3D = fill.built_transforms[i]
			if xf.origin.z > fill.face_z:
				continue
			var bottom: Vector3 = fill.global_transform * Vector3(xf.origin.x, xf.origin.y - fill.spill_rest[i], xf.origin.z)
			# Independent check: the surface right under the book, probed from just above it.
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(bottom + Vector3.UP * 0.3, bottom + Vector3.DOWN * 0.5, 1))
			if hit.is_empty() or absf((hit["position"] as Vector3).y - bottom.y) > TOL:
				bad.append("%s book %d rests at %.2f, surface %s" % [room.socket_key(s).get_slice("/", 1), i, bottom.y,
					"none" if hit.is_empty() else "%.2f" % (hit["position"] as Vector3).y])
				continue
			if absf(bottom.y) < TOL:
				landed["dropped a storey" if upper else "floor"] += 1
			elif absf(bottom.y - GALLERY_TOP) < TOL:
				landed["gallery"] += 1
			else:
				landed["stair"] += 1
		for mesh: MeshInstance3D in fill.spill_meshes():
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				box.get_center() + Vector3.UP * 0.3, box.get_center() + Vector3.DOWN * 3.0, 1))
			if not hit.is_empty() and absf((hit["position"] as Vector3).y - box.position.y) < 0.08:
				boards_settled += 1
			else:
				bad.append("%s board %s bottom %.2f, surface %s" % [room.socket_key(s).get_slice("/", 1), mesh.name,
					box.position.y, "none" if hit.is_empty() else "%.2f" % (hit["position"] as Vector3).y])
	check(bad.is_empty(), "all spill rests on the surface below it (%d problems: %s)" % [bad.size(), bad.slice(0, 4)])
	check(landed["floor"] > 0, "lower-recess spill lies on the hall floor (%d)" % landed["floor"])
	check(landed["gallery"] > 0, "spill in front of upper recesses lies on the gallery slabs (%d)" % landed["gallery"])
	check(landed["stair"] > 0, "spill over the stairs lies on the stairs (%d)" % landed["stair"])
	check(landed["dropped a storey"] > 0, "upper recesses with nothing in front drop their spill to the floor (%d)" % landed["dropped a storey"])
	check(boards_settled >= recesses.size(), "broken floor boards settle too (%d)" % boards_settled)
	print("spill_settle_test: landed %s" % landed)
	print("spill_settle_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)
