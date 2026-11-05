class_name BridgeHallLife
extends RefCounted
## Phase 12 step 3: the Bridge Hall's life and wear, added by BridgeHallBridge
## when the room is built (all in the bridge's frame: the run's start, -Z
## across the hall).
##   - hanging gardens at the lit windows (plants by light): clay pots on the
##     real sill, ivy trailing from its front edge (the
##     opening found by rays)
##   - wild herbs to pick at each cave mouth, where the bridge-end lamp
##     reaches the rock; mushrooms to pick in the passage's dark corner
##     (NicheThing "herb", "mushroom")
##   - the halfway landing on a side deck off the bridge (_add_bay_out): a
##     floor seat against its balustrade, a rug, a lamp on a stool (the
##     landing's light), the keeper's traces (a pack, a book left open)
##   - the older bridge weathered: fallen parapet bays patched with timber
##     rails, some gone, moss on its deck, ivy over its edge
##   - the sealed doors softened: ivy over the arch, moss and rubble at the foot
##   - in the dark: moss, ferns and fungus on the rock under the deck, wet from
##     the mist (scattered by rays, after the room's collision is in)
##   - mist wisps rising past the deck (BridgeHallBridge._process moves them)

const D: String = "res://kit/modules/dressing/"
const P: String = "res://kit/modules/persian/"
const HERB: String = "res://kit/dressing/forage_herb.tscn"
const MUSHROOM: String = "res://kit/dressing/forage_mushroom.tscn"
const WOOD: String = "res://assets/textures/px/persian_wood.png"
## The deck's inner balustrade face (chasm_parapet_4m is 0.38 deep at the
## deck's edge, 2 m out).
const RAIL_IN: float = 1.62


static func scene(path: String, xf: Transform3D, into: Node3D, name: String = "") -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.transform = xf
	if not name.is_empty():
		n.name = name
	into.add_child(n)
	return n


## A patch to gather: `visual` scene at `xf`, with its NicheThing (kind
## "herb" or "mushroom") over it.
static func pickable(kind: String, visual: String, xf: Transform3D, into: Node3D, name: String) -> NicheThing:
	var v: Node3D = scene(visual, xf, into, name)
	var t := NicheThing.new()
	t.name = "Take_" + name
	t.kind = kind
	t.position = xf.origin + Vector3(0, 0.2, 0)
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.45, 0.4, 0.45)
	s.shape = b
	t.add_child(s)
	into.add_child(t)
	t.visual = t.get_path_to(v)
	return t


## Wild herbs to pick where the lamp light reaches the rock: the herb (its
## NicheThing) with ferns and a tuft round it, at `xf` (on the floor).
static func herb_patch(xf: Transform3D, seed_value: int, into: Node3D, name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	pickable("herb", HERB, xf * Transform3D(Basis(), Vector3(0, 0.2, 0)), into, name)
	for j: int in 3:
		var a: float = rng.randf() * TAU
		var at := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.35, 0.6)
		scene(D + ("plant_fern.tscn" if j < 2 else "plant_crack_tuft.tscn"),
			xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 1.8)), at), into, "%s_Green_%d" % [name, j])


## The hanging gardens at each lit window (walked step 3: pots and ivy hung
## on the flat wall, off the windows): the window's opening found by rays
## into its face (its frame: the face at z 0, x 0..4, y up from the storey's
## floor, the hall toward +Z); clay pots on its real sill, ivy trailing from
## the sill's front edge at both sides (no awnings: they floated over windows
## of other heights). `room`: the
## room the faces are in; `origin`: the bridge's place in it.
static func gardens(room: Node3D, origin: Vector3, lit_windows: Array, seed_value: int, into: Node3D) -> void:
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_gardens"])
	var to_bridge := Transform3D(Basis(), -origin)
	var w: int = 0
	for face: Transform3D in lit_windows:
		var win: Dictionary = _find_window(space, room, face)
		w += 1
		if win.is_empty():
			continue
		var f: Transform3D = to_bridge * face
		var xc: float = win["x"]
		var sill: float = win["sill"]
		var front: float = win["front"]
		var half: float = win["half"]
		if rng.randf() < 0.75:
			for x: float in ([xc - 0.3, xc + 0.3] if half > 0.45 else [xc]):
				scene(D + "prop_pot.tscn", f * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, sill, win["inside"])), into, "SillPot_%d_%d" % [w, int(x * 10)])
		for x: float in [xc - half + IVY_IN, xc + half - IVY_IN]:
			if rng.randf() < 0.85:
				var s: float = rng.randf_range(1.2, 2.0)
				# Not where it would hang onto a rail or ledge below (walked step 3:
				# by the side deck it hung in the air beside the balustrade).
				var reach: float = IVY_LENGTH * s + 0.3
				if _probe(space, room, face, Vector3(x, sill - 0.1, front + 0.15), Vector3(0, -reach, 0)) < reach:
					continue
				scene(D + "plant_ivy_hang.tscn", f * Transform3D(Basis(Vector3.UP, PI + rng.randf_range(-0.1, 0.1)) * Basis.from_scale(Vector3(1.4, s, 1.4)),
					Vector3(x - IVY_CENTRE, sill + 0.02, front - IVY_OUT)), into, "Ivy_%d_%d" % [w, int(x * 10)])
## How far behind a face a ray must reach to count as the window's opening
## (a lattice stands just inside some).
const OPEN_BEHIND: float = 0.2
## plant_ivy_hang (a rail drape) turned so its flat leaves lie back on the
## sill (walked step 3: unturned they stuck out into the air like a shelf).
## Its strands hang 0.07..0.18 behind its root (x1.4 when turned), so the
## root sits IVY_OUT inside the sill's front to bring them against the face
## (walked again: 0.15 m off looked like floating). It spans x -0.28..0.14
## (-0.14..0.28 turned), so it's shifted IVY_CENTRE back to sit centred,
## IVY_IN in from the opening's edges; its strands are up to IVY_LENGTH
## long (x its height scale).
const IVY_OUT: float = 0.07
const IVY_CENTRE: float = 0.1
const IVY_IN: float = 0.25
const IVY_LENGTH: float = 1.07


## A window's opening in a face (room frame `face`): rays from 2.5 m in front
## on a grid; a hit 0.4 m or more behind the face is the opening. The widest
## run of such columns is the window: its middle x, half width, sill (the top
## of the stone under the opening, found by a ray down), the sill's front
## (where a ray just under it meets the face), how far in to stand a pot, and
## its top. {} if none.
static func _find_window(space: PhysicsDirectSpaceState3D, room: Node3D, face: Transform3D) -> Dictionary:
	var cols: Dictionary = {}       # x -> [lowest, highest] y open
	var x: float = 0.3
	while x < 3.75:
		var y: float = 0.3
		while y < 3.8:
			var d: float = _probe(space, room, face, Vector3(x, y, 2.5), Vector3(0, 0, -5.0))
			if d > 2.5 + OPEN_BEHIND:
				if not cols.has(x):
					cols[x] = [y, y]
				cols[x][0] = minf(cols[x][0], y)
				cols[x][1] = maxf(cols[x][1], y)
			y += 0.15
		x += 0.3
	# The widest run of neighbouring open columns.
	var xs: Array = cols.keys()
	xs.sort()
	var best: Array = []
	var run: Array = []
	for cx: float in xs:
		if not run.is_empty() and cx - float(run[-1]) > 0.35:
			run = []
		run.append(cx)
		if run.size() > best.size():
			best = run.duplicate()
	if best.size() < 2 or float(best[-1]) - float(best[0]) > 2.6:
		return {}
	var xc: float = (float(best[0]) + float(best[-1])) * 0.5
	var mid: float = best[best.size() / 2]
	var lo: float = cols[mid][0]
	var hi: float = cols[mid][1]
	# The sill: down from just inside the opening's foot.
	var sill: float = lo - 0.1
	var depth: float = _probe(space, room, face, Vector3(xc, lo + 0.1, 2.5), Vector3(0, 0, -5.0)) - 2.5
	var inside: float = -clampf(depth * 0.3, 0.12, 0.4)
	var dd: float = _probe(space, room, face, Vector3(xc, lo + 0.1, inside), Vector3(0, -0.8, 0))
	if dd < 0.8:
		sill = lo + 0.1 - dd
	var fd: float = _probe(space, room, face, Vector3(xc, sill - 0.05, 2.5), Vector3(0, 0, -3.0))
	var front: float = 2.5 - fd if fd < 3.0 else 0.0
	var out: Dictionary = {"x": xc, "half": (float(best[-1]) - float(best[0])) * 0.5 + 0.15, "sill": sill, "front": front, "inside": inside}
	if hi < 3.6:
		out["top"] = hi + 0.1
	return out


## The distance to the first front face along `along` from `from` (both in
## `face`'s frame), or the ray's length if nothing.
static func _probe(space: PhysicsDirectSpaceState3D, room: Node3D, face: Transform3D, from: Vector3, along: Vector3) -> float:
	var g: Transform3D = room.global_transform * face
	var a: Vector3 = g * from
	var q := PhysicsRayQueryParameters3D.create(a, g * (from + along))
	q.hit_back_faces = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return along.length()
	return a.distance_to(hit["position"])


## The halfway landing on bay `k`'s side deck (BridgeHallBridge._add_bay_out,
## off the deck's `side`, +-1 in x): a floor seat against its outer
## balustrade, a kilim rug, a cushion with a book left open, the keeper's
## pack, a lamp on a stool (the landing's light). Returns where the light goes.
static func landing(k: int, side: float, into: Node3D) -> Vector3:
	var z: float = -(k + 0.5) * BridgeHallBridge.BAY
	var back := Basis(Vector3.UP, -side * PI * 0.5)       # the seat's back (-Z) to the outer rail
	var outer_in: float = 2.0 + BridgeHallBridge.BAY_OUT - 0.38
	var seat_x: float = side * (outer_in - 0.34)
	var mid_x: float = side * (2.0 + BridgeHallBridge.BAY_OUT * 0.5)
	scene(D + "rug_kilim_small.tscn", Transform3D(Basis.from_scale(Vector3(0.82, 1, 0.9)), Vector3(mid_x, 0.0, z)), into, "LandingRug")
	scene(D + "floor_seat.tscn", Transform3D(back, Vector3(seat_x, 0.0, z)), into, "LandingSeat")
	scene(D + "floor_cushion.tscn", Transform3D(Basis(Vector3.UP, 0.4), Vector3(mid_x - side * 0.25, 0.0, z + 0.55)), into, "LandingCushion")
	scene(D + "prop_book_open.tscn", Transform3D(Basis(Vector3.UP, side * 1.2), Vector3(mid_x - side * 0.25, 0.14, z + 0.55)), into, "LandingBook")
	scene("res://kit/modules/camp/camp_pack.tscn", Transform3D(Basis(Vector3.UP, side * 0.3), Vector3(mid_x - side * 0.35, 0.0, z - 1.15)), into, "LandingPack")
	scene(D + "stack_lamp_stool.tscn", Transform3D(back, Vector3(seat_x, 0.0, z + 1.2)), into, "LandingLampStool")
	return Vector3(seat_x, 0.75, z + 1.2)


## The older bridge's wear, on its span plan before it's built: of the
## parapet bays, some fall (none left; a timber patch rails the gap) or are
## gone. Returns the patches' transforms (the parapet's frame: x 0..4 along
## it, the rail's inner face toward +Z... as chasm_parapet_4m).
static func weather(span: Dictionary, seed_value: int) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_old_wear"])
	var keep: Array = []
	var patches: Array[Transform3D] = []
	for p: Dictionary in span["pieces"]:
		if str(p["scene"]).ends_with("chasm_parapet_4m.tscn"):
			var r: float = rng.randf()
			if r < 0.3:
				patches.append(p["xf"])
				continue
			if r < 0.4:
				continue                     # gone, nothing patched
		keep.append(p)
	span["pieces"] = keep
	return patches


## A timber patch where a parapet fell: posts and two rails, a little askew.
static func timber_patch(xf: Transform3D, seed_value: int, into: Node3D, name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var holder := Node3D.new()
	holder.name = name
	holder.transform = xf
	into.add_child(holder)
	var m: Material = wood()
	for x: float in [0.45, 2.0, 3.55]:
		_box(holder, m, Vector3(0.12, 1.0, 0.12), Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08)), Vector3(x, 0.5, -0.19)))
	for y: float in [0.45, 0.92]:
		var tilt: float = rng.randf_range(-0.04, 0.04)
		_box(holder, m, Vector3(3.9, 0.09, 0.07), Transform3D(Basis(Vector3.BACK, tilt), Vector3(2.0, y, -0.12)))


static var _wood: StandardMaterial3D
static func wood() -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_texture = load(WOOD)
		_wood.albedo_color = Color(0.95, 0.88, 0.8)      # sun-bleached; unlit, darker read near black
		_wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_wood.uv1_triplanar = true
		_wood.uv1_scale = Vector3(0.5, 0.5, 0.5)
		_wood.roughness = 0.9
	return _wood


static func _box(into: Node3D, m: Material, size: Vector3, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.transform = xf
	into.add_child(mi)


## Ivy over a sealed door's arch, moss and rubble at its foot (the carved
## panel read as a slab set in the rock). `face`: the door piece's frame.
static func soften_door(face: Transform3D, seed_value: int, into: Node3D, name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for x: float in [0.55, 1.2, 2.9, 3.5]:
		var s: float = rng.randf_range(1.4, 2.4)
		scene(D + "plant_ivy_hang.tscn", face * Transform3D(Basis(Vector3.UP, PI + rng.randf_range(-0.4, 0.4)) * Basis.from_scale(Vector3(1.8, s, 1.8)),
			Vector3(x, rng.randf_range(3.6, 4.6), 0.55)), into, "%s_Ivy_%d" % [name, int(x * 10)])
	for x: float in [0.4, 1.0, 3.0, 3.6]:
		scene(D + ("plant_moss_cushion.tscn" if rng.randf() < 0.6 else "plant_fern.tscn"),
			face * Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.5, 2.5)), Vector3(x, 0.0, rng.randf_range(0.3, 0.8))), into, "%s_Moss_%d" % [name, int(x * 10)])
	for i: int in 3:
		scene(D + "debris_rubble.tscn", face * Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.5, 2.5)),
			Vector3(rng.randf_range(0.3, 3.7), 0.0, rng.randf_range(0.4, 1.0))), into, "%s_Rubble_%d" % [name, i])


## Moss, ferns and fungus on the rock in the dark under the deck: rays from
## the drop toward the long walls, the end walls and the pit floor; a hit on
## the room's shell (not a bridge) grows a plant along its normal: fungus and
## ferns on ledges and floor, moss and tufts on the steep rock.
static func dark_growth(bridge: Node3D, hall: AABB, top: float, seed_value: int, count: int) -> void:
	var space: PhysicsDirectSpaceState3D = bridge.get_world_3d().direct_space_state
	var room: Node3D = bridge.get_parent() as Node3D
	while room != null and not room is GeneratedRoom:
		room = room.get_parent() as Node3D
	if room == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_dark"])
	var holder := Node3D.new()
	holder.name = "DarkGrowth"
	bridge.add_child(holder)
	var placed: int = 0
	for _try: int in count * 4:
		if placed >= count:
			break
		var from := Vector3(rng.randf_range(hall.position.x + 3.0, hall.end.x - 3.0), rng.randf_range(BridgeHallBridge.PIT + 1.0, top),
			rng.randf_range(hall.position.z + 2.0, hall.end.z - 2.0))
		var dir: Vector3
		var r: float = rng.randf()
		if r < 0.55:
			dir = Vector3(-1.0 if rng.randf() < 0.5 else 1.0, rng.randf_range(-0.5, 0.1), rng.randf_range(-0.2, 0.2))
		elif r < 0.7:
			dir = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.4, 0.1), -1.0 if rng.randf() < 0.5 else 1.0)
		else:
			dir = Vector3(rng.randf_range(-0.3, 0.3), -1.0, rng.randf_range(-0.3, 0.3))
		var a: Vector3 = room.to_global(from)
		var q := PhysicsRayQueryParameters3D.create(a, a + room.global_basis * dir.normalized() * 30.0)
		q.hit_back_faces = false
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var c: Node = hit["collider"]
		if bridge.is_ancestor_of(c) or not room.is_ancestor_of(c) or c is NicheThing:
			continue
		var at: Vector3 = holder.to_local(hit["position"])
		if at.y < BridgeHallBridge.PIT + POOL_LEVEL + 0.15:
			continue       # under the pit's pool
		var up: Vector3 = (holder.global_basis.inverse() * (hit["normal"] as Vector3)).normalized()
		var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up, side.cross(up)).rotated(up, rng.randf() * TAU)
		var path: String
		var s: float
		if up.y > 0.7:
			var pick: float = rng.randf()
			path = P + "persian_fungus_cluster.tscn" if pick < 0.3 else (D + "plant_fern.tscn" if pick < 0.7 else D + "plant_moss_cushion.tscn")
			s = rng.randf_range(1.0, 1.6) if pick < 0.3 else rng.randf_range(2.0, 3.5)
		else:
			# Walked step 3: tufts and moss stretched across steep rock looked
			# wrong; growth keeps to ledges and the floor.
			continue
		scene(path, Transform3D(basis.scaled(Vector3.ONE * s), at), holder, "Grow_%d" % placed)
		placed += 1


## Mist wisps rising from the mist past the deck: ellipsoid fog volumes, each
## its own material so its density can swell and fade.
static func wisps(hall: AABB, origin: Vector3, top: float, count: int, seed_value: int, into: Node3D) -> Array[FogVolume]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_wisps"])
	var out: Array[FogVolume] = []
	for i: int in count:
		var f := FogVolume.new()
		f.name = "Wisp_%d" % i
		f.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		f.size = Vector3(rng.randf_range(3.0, 5.0), rng.randf_range(2.0, 3.0), rng.randf_range(3.0, 5.0))
		var m := FogMaterial.new()
		m.density = 0.0
		m.albedo = BridgeHallBridge.MIST_COLOUR
		m.emission = Color(0.05, 0.056, 0.064)
		m.edge_fade = 0.8
		f.material = m
		var x: float = rng.randf_range(hall.position.x + 3.0, hall.end.x - 3.0) - origin.x
		var z: float = rng.randf_range(hall.position.z + 3.0, hall.end.z - 3.0) - origin.z
		f.position = Vector3(x, top, z)
		f.set_meta("base", Vector3(x, top, z))
		f.set_meta("phase", rng.randf())
		f.set_meta("speed", rng.randf_range(0.035, 0.06))
		into.add_child(f)
		out.append(f)
	return out


## Moves the wisps: each rises WISP_RISE over its cycle, swelling then fading.
const WISP_RISE: float = 9.0
const WISP_DENSITY: float = 0.07
static func drift(wisps_list: Array[FogVolume], time: float) -> void:
	for f: FogVolume in wisps_list:
		var t: float = fposmod(time * float(f.get_meta("speed")) + float(f.get_meta("phase")), 1.0)
		var base: Vector3 = f.get_meta("base")
		f.position = base + Vector3(sin(time * 0.1 + base.z) * 0.8, t * WISP_RISE, 0.0)
		(f.material as FogMaterial).density = WISP_DENSITY * sin(t * PI)


## The pool in the bottom of the drop (walked step 3: the old bridge's fall
## poured onto dry rock): dark, still water at POOL_LEVEL over the pit floor,
## filling its hollows; the floor's boulders and its rising edges stand out of
## it. `hall`: the room's hall box; `origin`: the bridge's place in the room.
static func pool(hall: AABB, origin: Vector3, into: Node3D) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(hall.size.x - 2.0, hall.size.z - 2.0)
	var water := MeshInstance3D.new()
	water.name = "PitPool"
	water.mesh = plane
	water.material_override = load(POOL_MATERIAL)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c: Vector3 = hall.get_center() - origin
	water.position = Vector3(c.x, BridgeHallBridge.PIT + POOL_LEVEL, c.z)
	into.add_child(water)
	return water
## The pool's surface over the pit's floor (it's rough by +-0.3, rising 2 m
## to the walls).
const POOL_LEVEL: float = 0.35
const POOL_MATERIAL: String = "res://kit/materials/bridge_pit_water.tres"


## Where a fall lands in the pit's pool (walked step 3: "ripples/mist at the
## foot of the fall"): rings spreading on the water from a churned middle,
## and a low bank of spray. `fall`: the fall; returns the ripples' material
## (its owner drives simulation_time).
static func fall_foot(fall: GreatFall, into: Node3D, name: String) -> ShaderMaterial:
	var foot: Vector3 = into.to_local(fall.to_global(Vector3(0.0, -fall.height, fall.arc_out)))
	foot.y = BridgeHallBridge.PIT + POOL_LEVEL + 0.01
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * FOOT_RADIUS * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fall_ripples.gdshader")
	mat.set_shader_parameter("radius", FOOT_RADIUS)
	var rings := MeshInstance3D.new()
	rings.name = name + "_Ripples"
	rings.mesh = plane
	rings.material_override = mat
	rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rings.position = foot
	into.add_child(rings)
	var spray := FogVolume.new()
	spray.name = name + "_Spray"
	spray.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	spray.size = Vector3(fall.width * 1.6, 2.4, fall.width * 1.6)
	spray.position = foot + Vector3(0.0, 0.5, 0.0)
	var fm := FogMaterial.new()
	fm.density = SPRAY_DENSITY
	fm.albedo = Color("c9dde3")
	fm.emission = Color("9bc7db") * 0.03
	fm.edge_fade = 0.7
	spray.material = fm
	into.add_child(spray)
	return mat
const FOOT_RADIUS: float = 2.2
const SPRAY_DENSITY: float = 0.12


## Glowing caps round the pit's pool (walked step 3: "glowing mushrooms at
## the bottom to explain the light ... on the rocks or around the shore, but
## not in water"): rays down onto the drop's floor; caps where the hit is
## above the water and fairly flat (the shore's rise, the boulders' tops), in
## small clumps, a tall cap in half of them. The pieces' own lamps are taken
## out (one each was far too many); SHORE_LIGHTS dim teal ones stand by tall
## clumps instead.
static func shore_glow(bridge: Node3D, hall: AABB, seed_value: int, count: int) -> void:
	var space: PhysicsDirectSpaceState3D = bridge.get_world_3d().direct_space_state
	var room: Node3D = bridge.get_parent() as Node3D
	while room != null and not room is GeneratedRoom:
		room = room.get_parent() as Node3D
	if room == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_shore"])
	var holder := Node3D.new()
	holder.name = "ShoreGlow"
	bridge.add_child(holder)
	var water: float = BridgeHallBridge.PIT + POOL_LEVEL
	var placed: int = 0
	var tall: Array[Vector3] = []
	for _try: int in count * 12:
		if placed >= count:
			break
		var from := Vector3(rng.randf_range(hall.position.x + 0.5, hall.end.x - 0.5), 0.0, rng.randf_range(hall.position.z + 0.5, hall.end.z - 0.5))
		var a: Vector3 = room.to_global(from)
		a.y = bridge.global_position.y + water + 3.0
		var q := PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 4.0)
		q.hit_back_faces = false
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var c: Node = hit["collider"]
		if bridge.is_ancestor_of(c) or not room.is_ancestor_of(c) or c is NicheThing:
			continue
		var at: Vector3 = holder.to_local(hit["position"])
		var up: Vector3 = (holder.global_basis.inverse() * (hit["normal"] as Vector3)).normalized()
		if at.y < water + 0.08 or at.y > water + SHORE_HIGH or up.y < 0.6:
			continue
		var big: bool = rng.randf() < 0.5
		for j: int in rng.randi_range(1, 3):
			var off := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35)) if j > 0 else Vector3.ZERO
			scene(("res://kit/modules/persian/persian_fungus_small.tscn" if big and j == 0 else D + "stack_glowcaps.tscn"),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), at + off),
				holder, "ShoreCaps_%d_%d" % [placed, j])
		if big:
			tall.append(at)
		placed += 1
	# The pieces each carry a lamp (their LIGHT_ markers): far too many for
	# the room's budget. Theirs go; SHORE_LIGHTS dim ones stand at the first
	# tall clumps, spread apart.
	for l: Node in holder.find_children("*", "Light3D", true, false):
		l.free()
	var lit: Array[Vector3] = []
	for p: Vector3 in tall:
		if lit.size() >= SHORE_LIGHTS:
			break
		if lit.any(func(q: Vector3) -> bool: return q.distance_to(p) < 8.0):
			continue
		lit.append(p)
		var o := OmniLight3D.new()
		o.name = "ShoreLight_%d" % lit.size()
		o.light_color = Color(0.45, 0.95, 0.85)
		o.light_energy = 0.6
		o.omni_range = 6.0
		o.omni_attenuation = 1.6
		o.shadow_enabled = false
		o.light_specular = 0.2
		o.position = p + Vector3(0, 0.8, 0)
		holder.add_child(o)
## How far above the pool's surface the shore's caps grow.
const SHORE_HIGH: float = 1.6
## Lights among the shore's caps (the tall clumps'), at most.
const SHORE_LIGHTS: int = 2
