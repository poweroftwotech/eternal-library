extends SceneTree
## Which of the baked gorge's kit pieces no player can see (phase 6 step 6,
## the fly-mode walk: "geometry the player will never see"). Writes
## gen/gorge/hidden_pieces.json, which tools/bake_gorge.gd leaves out.
##   godot --path . --script res://tools/gorge_visibility.gd
## Needs a display (not --headless: the dummy renderer keeps no mesh data),
## and the gorge baked with everything in it first:
##   godot --headless --path . --script res://tools/bake_gorge.gd -- --no-cull
##
## Every piece of the bank, sanctum, cliff and aqueduct parts gets its own
## meshes as collision; rays go out in every direction (RAYS, turned at random
## per viewpoint so the viewpoints' rays interleave) from every place a player
## can stand in any seed: the Overlook's floors, every frontage slot's gallery
## (gen/gorge/frontage.tres) and along every link the network could build
## (gen/gorge/links.res: all seeds' spans and stairs are among them). A piece
## no ray meets is hidden, unless it's within KEEP_NEAR of a viewpoint (where
## a missed sliver would show), or small (under SMALL across: lamps, figures,
## banners, missed easily) with a seen piece within NEIGHBOUR of it.

const OUT: String = "res://gen/gorge/hidden_pieces.json"
const PARTS: Array[String] = ["bank_1", "bank_2", "bank_3", "bank_4", "bank_5", "bank_6", "bank_7", "bank_8", "sanctum", "aqueducts", "cliff"]
const RAYS: int = 6144
const REACH: float = 600.0
const EYE: float = 1.6
const KEEP_NEAR: float = 25.0
const SMALL: float = 2.5
const NEIGHBOUR: float = 4.0
## Viewpoints closer than this to one another are one.
const GRID: float = 5.0
## Never hidden: the terraces' walking surfaces and their edges. Seen from
## above (a higher gallery, or flying), a culled deck left the tier's core
## showing 0.6 m down (second fly-mode walk: "a dip in the terrace").
const KEEP: PackedStringArray = ["gorge_deck", "gorge_crown", "aqueduct_deck"]

## Piece key -> {part, aabb, small}.
var pieces: Dictionary = {}
## Body RID -> piece key.
var bodies: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


## A piece's key as bake_gorge.gd places it: its module and where it stands.
static func key(scene_path: String, origin: Vector3) -> String:
	return "%s@%s" % [scene_path.get_file().get_basename(), origin.snapped(Vector3.ONE * .01)]


func run() -> void:
	var t0: int = Time.get_ticks_msec()
	var space: RID = root.get_world_3d().space
	var shapes: Dictionary = {}     # Mesh -> Shape3D
	for part: String in PARTS:
		var holder: Node3D = (load("res://rooms/baked/gorge/%s.scn" % part) as PackedScene).instantiate()
		root.add_child(holder)
		for piece: Node in holder.get_children():
			var p := piece as Node3D
			if p == null or p.scene_file_path == "":
				continue
			var k: String = key(p.scene_file_path, p.global_position)
			var body: RID = PhysicsServer3D.body_create()
			PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_space(body, space)
			var box := AABB()
			var first: bool = true
			for m: Node in p.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.mesh == null or mi.mesh.get_surface_count() == 0:
					continue
				if not shapes.has(mi.mesh):
					shapes[mi.mesh] = mi.mesh.create_trimesh_shape()
				var shape: Shape3D = shapes[mi.mesh]
				if shape == null:
					continue
				PhysicsServer3D.body_add_shape(body, shape.get_rid(), mi.global_transform)
				var b: AABB = mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			bodies[body] = k
			pieces[k] = {"part": part, "aabb": box, "small": box.size.length() < SMALL}
		holder.queue_free()
	await physics_frame
	await physics_frame
	var points: Array[Vector3] = viewpoints()
	print("gorge_visibility: %d pieces, %d meshes as shapes, %d viewpoints (%.0f s)" % [pieces.size(), shapes.size(), points.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var seen: Dictionary = {}
	var state: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var dirs: PackedVector3Array = sphere(RAYS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var query := PhysicsRayQueryParameters3D.new()
	for i: int in points.size():
		var turn := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0, TAU))
		query.from = points[i]
		for d: Vector3 in dirs:
			query.to = points[i] + turn * d * REACH
			var hit: Dictionary = state.intersect_ray(query)
			if not hit.is_empty() and bodies.has(hit["rid"]):
				seen[bodies[hit["rid"]]] = true
		if i % 100 == 0:
			print("  %d / %d viewpoints, %d pieces seen (%.0f s)" % [i, points.size(), seen.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	# Near a viewpoint, or small beside a seen piece: kept.
	# (Both looked up in a grid of KEEP_NEAR cells, not against every point.)
	var near_points: Dictionary = {}
	for p: Vector3 in points:
		var c: Vector3i = Vector3i((p / KEEP_NEAR).floor())
		if not near_points.has(c):
			near_points[c] = []
		(near_points[c] as Array).append(p)
	var near_seen: Dictionary = {}
	for k: String in seen:
		var b: AABB = pieces[k]["aabb"]
		for c: Vector3i in cells_of(b.grow(NEIGHBOUR)):
			if not near_seen.has(c):
				near_seen[c] = []
			(near_seen[c] as Array).append(b)
	var hidden: PackedStringArray = []
	for k: String in pieces:
		if seen.has(k) or Array(KEEP).any(func(p: String) -> bool: return k.begins_with(p)):
			continue
		var box: AABB = pieces[k]["aabb"]
		var keep: bool = false
		for c: Vector3i in cells_of(box.grow(KEEP_NEAR)):
			for p: Vector3 in near_points.get(c, []):
				keep = keep or box.grow(KEEP_NEAR).has_point(p)
		if not keep and pieces[k]["small"]:
			for c: Vector3i in cells_of(box):
				for b: AABB in near_seen.get(c, []):
					keep = keep or b.grow(NEIGHBOUR).intersects(box)
		if not keep:
			hidden.append(k)
	var by_part: Dictionary = {}
	for k: String in hidden:
		by_part[pieces[k]["part"]] = int(by_part.get(pieces[k]["part"], 0)) + 1
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"made_by": "tools/gorge_visibility.gd", "viewpoints": points.size(), "rays": RAYS, "hidden": hidden}, "\t"))
	f.close()
	print("gorge_visibility: %d of %d pieces hidden %s -> %s (%.0f s)" % [hidden.size(), pieces.size(), by_part, OUT, (Time.get_ticks_msec() - t0) / 1000.0])
	for body: RID in bodies:
		PhysicsServer3D.free_rid(body)
	quit()


## Where a player's eye can be, in any seed.
func viewpoints() -> Array[Vector3]:
	var out: Array[Vector3] = []
	# The Overlook's floors: the tops of its collision boxes, every 3 m.
	var overlook: Node3D = (load("res://rooms/gorge/overlook.tscn") as PackedScene).instantiate()
	root.add_child(overlook)
	for s: Node in overlook.find_children("*", "CollisionShape3D", true, false):
		var cs := s as CollisionShape3D
		if not cs.shape is BoxShape3D:
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		if size.y > 6.0 or size.x * size.z < 4.0:
			continue     # guards and the safety floor, not floors
		for i: int in maxi(1, int(size.x / 3.0)):
			for j: int in maxi(1, int(size.z / 3.0)):
				var local := Vector3((i + .5) * size.x / maxi(1, int(size.x / 3.0)) - size.x * .5, size.y * .5 + EYE, (j + .5) * size.z / maxi(1, int(size.z / 3.0)) - size.z * .5)
				out.append(cs.global_transform * local)
	overlook.free()
	# Every frontage slot's gallery: a bay deep, at eye height, every bay.
	var frontage: Resource = load("res://gen/gorge/frontage.tres")
	for slot: Resource in frontage.get("slots"):
		for k: int in int(slot.get("width")):
			out.append((slot.get("xf") as Transform3D) * Vector3(k * 4.0 + 2.0, EYE, -2.0))
	# Along every link the network could build: over each of its boxes.
	var links: Resource = load("res://gen/gorge/links.res")
	for e: Dictionary in links.get("entries"):
		for b: AABB in e.get("boxes", []):
			var n: int = maxi(1, int(maxf(b.size.x, b.size.z) / 6.0))
			for i: int in n:
				var t: float = (i + .5) / n
				var c: Vector3 = b.get_center()
				var along := Vector3(b.size.x, 0, 0) if b.size.x > b.size.z else Vector3(0, 0, b.size.z)
				out.append(Vector3(c.x, b.end.y + .5, c.z) + along * (t - .5))
	# One per GRID cell: the links' boxes overlap (every seed's candidates), so
	# hundreds of thousands of points stood within a metre or two of others.
	var cells: Dictionary = {}
	for p: Vector3 in out:
		var c: Vector3i = Vector3i((p / GRID).floor())
		if not cells.has(c):
			cells[c] = p
	var kept: Array[Vector3] = []
	kept.assign(cells.values())
	return kept


## `n` directions spread evenly over the sphere (a Fibonacci lattice).
static func sphere(n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var golden: float = PI * (3.0 - sqrt(5.0))
	for i: int in n:
		var y: float = 1.0 - 2.0 * (i + .5) / n
		var r: float = sqrt(1.0 - y * y)
		out.append(Vector3(cos(golden * i) * r, y, sin(golden * i) * r))
	return out


## The KEEP_NEAR grid cells a box touches.
static func cells_of(box: AABB) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var lo: Vector3i = Vector3i((box.position / KEEP_NEAR).floor())
	var hi: Vector3i = Vector3i((box.end / KEEP_NEAR).floor())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				out.append(Vector3i(x, y, z))
	return out
