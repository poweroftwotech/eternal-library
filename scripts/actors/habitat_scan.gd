class_name HabitatScan
extends RefCounted
## Finds where creatures can live in a built room by reading what is already
## there (phase 19, docs/npc/phase-19-design.md section 3), so no kit piece has
## to be re-marked. Step 1 knows water.
##
## Water: every mesh drawn with the water shader as still water (its `plane` 0;
## channels and falls run in their own planes) and lying flat. Planes at one
## height that touch are one body (the cistern's cells, a pool in pieces).
## Each body is then sounded with rays against the world (layer 1): a grid of
## points over the surface, each kept if the water is open there (not inside
## a pier or under a deck), clear of walls by WALL_CLEARANCE, with the floor
## under it found (no floor within FLOOR_REACH: open deep water).

const WATER_SHADER: String = "res://shaders/water.gdshader"
## A plane this thick or more isn't a surface.
const FLAT: float = 0.25
## Planes whose boxes come this close are one body.
const TOUCH: float = 0.3
## Planes at heights this far apart are separate bodies.
const LEVEL: float = 0.08
## The grid's spacing (m), widened so a body has at most MAX_POINTS.
const SPACING: float = 0.5
const MAX_POINTS: int = 900
## A place this close to a wall (m) at swimming depth is left out.
const WALL_CLEARANCE: float = 0.3
## Where the rays look for a floor below the surface (m).
const FLOOR_REACH: float = 6.0
## Depth taken for open water with no floor in reach.
const OPEN_DEPTH: float = 3.0
const WORLD_MASK: int = 1
## A water mesh with more corners than this is taken as its box (see step()).
const SHAPE_CORNERS: int = 256


## Water this far under anything (a slab, a basin, a deck) is covered: no fish
## there, you couldn't see them (m above the surface).
const COVER: float = 2.2

## Step 2, the air. Light profiles (tools/kit_import.gd) that are a flame,
## and those that are a natural glow (fungi). Lights with no profile (the camp,
## lights a room's Life adds) are judged by colour.
const FLAME_PROFILES: PackedStringArray = ["lantern", "brazier", "chandelier", "cluster", "desk", "lamp_dim", "redfire", "sconce", "torch",
	"candle", "candle_one", "ossuary_shrine", "ossuary_candle", "ossuary_lantern", "lake_lantern", "lake_canopy", "lake_lamp"]
const GLOW_PROFILES: PackedStringArray = ["fungus", "glowcap", "violet", "lake_glow", "ossuary_glow"]
## A roof is dark with no flame this close (m): about a bay.
const DARK_RADIUS: float = 5.0
## How far up a roof is looked for (m), and how low one may be.
const ROOF_REACH: float = 16.0
const ROOF_LOW: float = 2.0


## Finding the water in slices: begin(), step() until true, finish().
class WaterScan:
	extends RefCounted
	var nodes: Array[Node] = []
	var at: int = 0
	var planes: Array[Dictionary] = []     # {box, surface, tris, material}


## The still water under `root`, in global space, not yet sounded (all at once).
static func water_bodies(root: Node) -> Array[WaterBody]:
	var scan: WaterScan = begin(root)
	step(scan, -1)
	return finish(scan)


static func begin(root: Node) -> WaterScan:
	var scan := WaterScan.new()
	scan.nodes = root.find_children("*", "GeometryInstance3D", true, false)
	return scan


## Looks at the scan's nodes until `deadline_usec` (-1: all). True once done.
static func step(scan: WaterScan, deadline_usec: int) -> bool:
	var planes: Array[Dictionary] = scan.planes
	while scan.at < scan.nodes.size():
		var g := scan.nodes[scan.at] as GeometryInstance3D
		scan.at += 1
		if deadline_usec >= 0 and Time.get_ticks_usec() >= deadline_usec:
			scan.at -= 1
			return false
		if g == null or not is_instance_valid(g) or not g.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var mm: MultiMesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mm = (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
		if mesh == null:
			continue
		for s: int in mesh.get_surface_count():
			var mat: Material = g.material_override
			if mat == null and g is MeshInstance3D:
				mat = (g as MeshInstance3D).get_active_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			if not _still_water(mat):
				continue
			# Only water gets this far: its placements.
			var xforms: Array[Transform3D] = [g.global_transform]
			if mm != null:
				xforms.clear()
				for i: int in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
					xforms.append(g.global_transform * mm.get_instance_transform(i))
			# The surface's triangles, corner by corner. Reading a big mesh's
			# triangles costs tens of ms, so a big one counts as its box:
			# sounding drops whatever of the box isn't open water (the rim, the
			# bank).
			var corners: PackedVector3Array
			var local_box: AABB
			# A PlaneMesh (the camp, the lake) is its box anyway, and building
			# its subdivided triangles costs the same.
			if mesh is PrimitiveMesh or (mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_array_len(s) > SHAPE_CORNERS):
				local_box = mesh.get_aabb()
				var b: AABB = local_box
				var y: float = b.get_center().y
				var p0 := Vector3(b.position.x, y, b.position.z)
				var p1 := Vector3(b.end.x, y, b.position.z)
				var p2 := Vector3(b.end.x, y, b.end.z)
				var p3 := Vector3(b.position.x, y, b.end.z)
				corners = PackedVector3Array([p0, p1, p2, p0, p2, p3])
			else:
				var arrays: Array = mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var idx: Variant = arrays[Mesh.ARRAY_INDEX]
				if idx == null:
					corners = verts
				else:
					for k: int in idx:
						corners.append(verts[k])
				local_box = AABB(verts[0], Vector3.ZERO) if not verts.is_empty() else AABB()
				for v: Vector3 in verts:
					local_box = local_box.expand(v)
			if corners.is_empty():
				continue
			for xf: Transform3D in xforms:
				var box: AABB = xf * local_box
				if box.size.y >= FLAT:
					continue
				var placed: PackedVector3Array = xf * corners
				var tris := PackedVector2Array()
				tris.resize(placed.size())
				for k: int in placed.size():
					tris[k] = Vector2(placed[k].x, placed[k].z)
				planes.append({"box": box, "surface": box.get_center().y, "tris": tris, "material": mat.resource_path})
	return true


## The bodies a finished scan found: its planes that touch at one height merged.
static func finish(scan: WaterScan) -> Array[WaterBody]:
	var planes: Array[Dictionary] = scan.planes
	# Union-find.
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(planes.size())
	for i: int in planes.size():
		parent[i] = i
	for i: int in planes.size():
		for j: int in range(i + 1, planes.size()):
			if absf(float(planes[i]["surface"]) - float(planes[j]["surface"])) <= LEVEL \
					and (planes[i]["box"] as AABB).grow(TOUCH).intersects((planes[j]["box"] as AABB).grow(TOUCH)):
				var a: int = _find(parent, i)
				var b: int = _find(parent, j)
				if a != b:
					parent[b] = a
	var by_root: Dictionary = {}
	for i: int in planes.size():
		var r: int = _find(parent, i)
		var body: WaterBody = by_root.get(r)
		var p: Dictionary = planes[i]
		if body == null:
			body = WaterBody.new()
			body.bounds = p["box"]
			body.material = p["material"]
			by_root[r] = body
		else:
			body.bounds = body.bounds.merge(p["box"])
		body.tris.append_array(p["tris"])
		body.surface += float(p["surface"]) * (p["tris"] as PackedVector2Array).size()
	var out: Array[WaterBody] = []
	for b: WaterBody in by_root.values():
		b.surface /= maxf(b.tris.size(), 1)
		_lay_grid(b)
		out.append(b)
	return out


## Sounds `body` until `deadline_usec` (Time.get_ticks_usec()). True once done.
static func sound(body: WaterBody, space: PhysicsDirectSpaceState3D, deadline_usec: int) -> bool:
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = WORLD_MASK
	q.hit_back_faces = true
	while body._next < body._grid.size():
		var p: Vector2 = body._grid[body._next]
		body._next += 1
		if not body.contains_xz(p):
			continue
		var floor_y: Variant = _sound_point(space, q, Vector3(p.x, body.surface, p.y))
		if floor_y != null:
			body.samples.append(Vector3(p.x, float(floor_y), p.y))
		if Time.get_ticks_usec() >= deadline_usec:
			break
	return body._next >= body._grid.size()


## The floor's height under open water at `at` (on the surface), or null:
## something stands there, or a wall is too close.
static func _sound_point(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, at: Vector3) -> Variant:
	# Down from COVER over the surface: the first thing hit must be a floor under
	# it (not a slab, basin or deck over the water).
	q.from = at + Vector3(0, COVER, 0)
	q.to = at - Vector3(0, FLOOR_REACH, 0)
	var hit: Dictionary = space.intersect_ray(q)
	var floor_y: float = at.y - OPEN_DEPTH
	if not hit.is_empty():
		if (hit["position"] as Vector3).y > at.y - 0.1 or (hit["normal"] as Vector3).y < 0.3:
			return null     # a pier, deck, causeway or the underside of something
		floor_y = (hit["position"] as Vector3).y
	var swim: Vector3 = Vector3(at.x, lerpf(at.y, floor_y, 0.4), at.z)
	# Inside a closed shape (a pier standing in the water): a ray out hits its inside.
	q.from = swim
	q.to = swim + Vector3(8.0, 0, 0.37)
	hit = space.intersect_ray(q)
	if not hit.is_empty() and (hit["normal"] as Vector3).dot(q.to - q.from) > 0.0:
		return null
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		q.to = swim + d * WALL_CLEARANCE
		if not space.intersect_ray(q).is_empty():
			return null
	return floor_y


## The lights under `root` that are burning flames ({at, colour}) and natural
## glows ({at, colour}), global. A lamp put out (LampState "dark") is no flame;
## a lamp only switched off by the light budget still is.
static func lights(root: Node) -> Dictionary:
	var flames: Array[Dictionary] = []
	var glows: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for n: Node in root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == null or l is DirectionalLight3D or str(l.get_meta("lamp_state", "lit")) == "dark":
			continue
		var kind: String = str(l.get_meta("light_profile", ""))
		var c: Color = l.light_color
		var entry: Dictionary = {"at": l.global_position, "colour": c, "node": l}
		if FLAME_PROFILES.has(kind):
			flames.append(entry)
		elif GLOW_PROFILES.has(kind):
			glows.append(entry)
		elif kind == "" and l is OmniLight3D and not l.has_meta("light_far"):
			if c.r > 0.85 and c.b < 0.6 and (l as OmniLight3D).omni_range < 12.0:
				flames.append(entry)
			elif c.g > c.r + 0.15 or c.b > c.r + 0.15:
				glows.append(entry)
			else:
				others.append(entry)
		else:
			others.append(entry)     # daylight, window and shaft lights: not dark, no moths
	return {"flames": flames, "glows": glows, "others": others}


## Roofs over a room, found in slices: points to look up from, and what was
## found ({at: the roof, floor: y under it, height}).
class RoofScan:
	extends RefCounted
	var starts: PackedVector3Array = PackedVector3Array()
	## How many of `starts` (the first ones) stand on a floor to be found; the
	## rest are on water, whose surface is their floor.
	var on_floor: int = 0
	var roofs: Array[Dictionary] = []
	var next: int = 0
	## Collider id -> whether it is natural rock (is_rock), asked once each.
	var rock: Dictionary = {}


## Looks up from the scan's points until `deadline_usec`. True once done. A
## point first finds its floor (down from a little over it), then the first
## thing over the floor facing down within ROOF_REACH.
static func roof_step(scan: RoofScan, space: PhysicsDirectSpaceState3D, deadline_usec: int) -> bool:
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = WORLD_MASK
	while scan.next < scan.starts.size():
		var p: Vector3 = scan.starts[scan.next]
		var on_water: bool = scan.next >= scan.on_floor
		scan.next += 1
		var floor_y: float = p.y
		if not on_water:
			q.hit_back_faces = false
			q.from = p + Vector3(0, 1.0, 0)
			q.to = p - Vector3(0, 3.0, 0)
			var down: Dictionary = space.intersect_ray(q)
			if not down.is_empty():
				floor_y = (down["position"] as Vector3).y
		q.hit_back_faces = true
		q.from = Vector3(p.x, floor_y + 1.2, p.z)
		q.to = Vector3(p.x, floor_y + ROOF_REACH, p.z)
		var up: Dictionary = space.intersect_ray(q)
		if not up.is_empty() and (up["normal"] as Vector3).y < -0.3:
			var at: Vector3 = up["position"]
			if at.y - floor_y >= ROOF_LOW:
				var id: int = int(up["collider_id"])
				if not scan.rock.has(id):
					scan.rock[id] = is_rock(up["collider"])
				scan.roofs.append({"at": at, "floor": floor_y, "height": at.y - floor_y, "rock": scan.rock[id]})
		if Time.get_ticks_usec() >= deadline_usec:
			break
	return scan.next >= scan.starts.size()


## Materials of natural rock (a cave's roof), not built stone.
const ROCK_MATERIALS: PackedStringArray = ["cave_rock", "camp_cave", "limestone_roof", "gorge_limestone", "flowstone"]


## Whether a collider is natural rock: the mesh it belongs to (it, its
## parents, or their meshes) is drawn with a rock material.
static func is_rock(collider: Object) -> bool:
	var n := collider as Node
	for up: int in 3:
		if n == null:
			return false
		var meshes: Array[Node] = [n]
		if up == 0:
			meshes.append_array(n.get_children())
		for m: Node in meshes:
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for s: int in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(s)
				if mat != null and _rock_name(mat.resource_path + " " + mat.resource_name):
					return true
		n = n.get_parent()
	return false


static func _rock_name(text: String) -> bool:
	for r: String in ROCK_MATERIALS:
		if text.contains(r):
			return true
	return false


## The roof right over `p` (global) within `reach` m, or null.
static func roof_over(space: PhysicsDirectSpaceState3D, p: Vector3, reach: float = 3.0) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, reach, 0), WORLD_MASK)
	q.hit_back_faces = true
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y > -0.3:
		return null
	return hit["position"]


## Whether a roof point is dark: no flame or other light (daylight, windows)
## within `radius` (DARK_RADIUS by default) and no glow within `glow_gap`
## (glowworms keep away from fungi; bats don't mind them).
static func is_dark(at: Vector3, lights: Dictionary, glow_gap: float, radius: float = DARK_RADIUS) -> bool:
	for key: String in ["flames", "others"]:
		for f: Dictionary in lights.get(key, []):
			if (f["at"] as Vector3).distance_to(at) < radius:
				return false
	var glows: Array = lights.get("glows", [])
	for g: Dictionary in glows:
		if (g["at"] as Vector3).distance_to(at) < glow_gap:
			return false
	return true


## Whether a fish at `a` can swim straight to `b` (global, both under water).
static func clear_path(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, WORLD_MASK)
	q.hit_back_faces = true
	return space.intersect_ray(q).is_empty()


static func _still_water(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader == null or sm.shader.resource_path != WATER_SHADER:
		return false
	var plane: Variant = sm.get_shader_parameter("plane")
	return plane == null or int(plane) == 0


static func _lay_grid(b: WaterBody) -> void:
	var size := Vector2(b.bounds.size.x, b.bounds.size.z)
	var step: float = maxf(SPACING, sqrt(size.x * size.y / MAX_POINTS))
	var x: float = b.bounds.position.x + step * 0.5
	while x < b.bounds.end.x:
		var z: float = b.bounds.position.z + step * 0.5
		while z < b.bounds.end.z:
			b._grid.append(Vector2(x, z))     # tested against the triangles while sounding
			z += step
		x += step


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i
