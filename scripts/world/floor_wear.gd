class_name FloorWear
extends Node3D
## Walked paths polished into a room's floor (ENVIRONMENT_PLAN.md polish C
## item 9, phase 2 slice 4). Every FloorWear in the tree feeds one shared
## world-space wear map at 32 texels/m, handed to the kit_px_world shader
## through the kit_wear_* shader globals; materials with wear_strength > 0
## (floor_stone) then turn glossy along the paths. Wear is quantised to a few
## dithered steps, so each floor texel stays one flat value.
##
## The map is rebuilt once per frame after a FloorWear enters or leaves the
## tree, so a host room and a joined generated room show their wear together.
## Paths and rings are moved to world x/z before stamping, so the room may move
## and turn. The noise lattice and dither are anchored to world texels: a
## room's wear looks the same whichever other rooms are live.
##
## Coordinates are this node's local x/z.

const TEXEL: float = 32.0
const STEPS: int = 4
const BAYER: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
## Noise lattice: one value per LATTICE texels (0.25 m), hashed from its
## world cell with this seed.
const LATTICE: int = 8
const LATTICE_SEED: int = 9
## The shared map's largest side, texels (256 m).
const MAX_TEXELS: int = 8192

## Area this wear covers (x, z, size x, size z), local metres. Keep it on whole
## metres so map texels line up with the floor's texel grid.
@export var rect: Rect2 = Rect2(0, -20, 12, 20)
## Local y range that gets wear (the ground floor, not galleries above it).
@export var y_range: Vector2 = Vector2(-0.5, 0.5)
## Walked lines as polylines of x/z points.
@export var paths: Array[PackedVector2Array] = []
## Traffic per path (1 = main thoroughfare); missing entries count as 1.
@export var path_weights: PackedFloat32Array = PackedFloat32Array()
## Full-wear half width of a path and the fade beyond it, metres.
@export var half_width: float = 0.28
@export var fade: float = 0.45
## Nodes (tables, lecterns) that people stand around: a lighter ring of wear
## follows their footprint at `ring_margin`.
@export var ring_nodes: Array[NodePath] = []
@export var ring_margin: float = 0.45
@export var ring_weight: float = 0.6

## The shared map (R = wear 0..1; row 0 is the map's min world z), its world
## rect (x, z, size) and y band. Null when no FloorWear is live.
static var map: ImageTexture
static var map_image: Image
static var map_rect: Rect2 = Rect2()
static var map_y: Vector2 = Vector2.ZERO
## Milliseconds the last rebuild took.
static var last_build_ms: float = 0.0
## An Area sets the map's world x/z rect from its plan (phase-4-design.md
## 8.1.1), so the map keeps its size as rooms come and go. Empty: the map
## covers the live wears.
static var fixed_rect: Rect2 = Rect2()
static var _live: Array[FloorWear] = []
static var _queued: bool = false


func _ready() -> void:
	if not _live.has(self):
		_live.append(self)
	if fixed_rect.has_area() and map_image != null and map_rect == _whole(fixed_rect):
		queue_region(world_rect())     # an area's map exists: redraw only this room's part
		set_process(true)
		return
	set_process(fixed_rect.has_area())
	_queue_rebuild()


func _exit_tree() -> void:
	_live.erase(self)
	if _live.is_empty():
		clear_map()
	elif fixed_rect.has_area() and map_image != null:
		queue_region(world_rect())
	else:
		_live[0]._queue_rebuild()


func _process(_delta: float) -> void:
	poll()


## Rebuilds now rather than at the end of the frame (tests, captures).
static func rebuild_now() -> void:
	_queued = false
	_pending.clear()
	var live: Array[FloorWear] = _live_wears()
	if live.is_empty():
		clear_map()
		return
	var t0: int = Time.get_ticks_usec()
	var bounds := Rect2()
	for i: int in live.size():
		var r: Rect2 = live[i].world_rect()
		bounds = r if i == 0 else bounds.merge(r)
	var band: Vector2 = _band(live)
	if fixed_rect.has_area():
		# An area's map: blank, then each live wear's own part, so the cost
		# follows the rooms, not the size of the area.
		bounds = _whole(fixed_rect)
		map_image = Image.create_empty(int(bounds.size.x * TEXEL), int(bounds.size.y * TEXEL), false, Image.FORMAT_R8)
		map_rect = bounds
		for w: FloorWear in live:
			var region: Rect2 = _whole(w.world_rect()).intersection(bounds)
			if region.has_area():
				_blit(compose(live.filter(func(o: FloorWear) -> bool: return o.world_rect().intersects(region)), region), region)
		map = ImageTexture.create_from_image(map_image)
		map_y = band
		last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
		_publish()
		return
	bounds = Rect2(bounds.position.floor(), Vector2.ZERO).expand(bounds.end.ceil())
	if bounds.size.x * TEXEL > MAX_TEXELS or bounds.size.y * TEXEL > MAX_TEXELS:
		push_warning("FloorWear: the live rooms span %s m; wear is cut to %d m" % [bounds.size, MAX_TEXELS / TEXEL])
		bounds.size = bounds.size.min(Vector2.ONE * (MAX_TEXELS / TEXEL))
	map_image = compose(live, bounds)
	map = ImageTexture.create_from_image(map_image)
	map_rect = bounds
	map_y = band
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_publish()


static func _publish() -> void:
	RenderingServer.global_shader_parameter_set("kit_wear_map", map)
	RenderingServer.global_shader_parameter_set("kit_wear_rect", Vector4(map_rect.position.x, map_rect.position.y, map_rect.size.x, map_rect.size.y))
	RenderingServer.global_shader_parameter_set("kit_wear_y", map_y)


static func _live_wears() -> Array[FloorWear]:
	var live: Array[FloorWear] = []
	for w: FloorWear in _live:
		if is_instance_valid(w) and w.is_inside_tree():
			live.append(w)
	_live = live
	return live


static func _band(live: Array[FloorWear]) -> Vector2:
	var band := Vector2(INF, -INF)
	for w: FloorWear in live:
		var y0: float = w.global_position.y
		band = Vector2(minf(band.x, y0 + w.y_range.x), maxf(band.y, y0 + w.y_range.y))
	return band


## `r` grown to whole metres (map texels line up with the floor's).
static func _whole(r: Rect2) -> Rect2:
	return Rect2(r.position.floor(), Vector2.ZERO).expand(r.end.ceil())


# --- an area's map, a room at a time (phase-4-design.md 8.1.4) ---------------------
# With fixed_rect set, a room arriving or leaving redraws only its own rect:
# the live wears' strokes there are gathered on the main thread, composed on a
# worker thread, and copied into the map when done (poll(), every frame).

static var _pending: Array[Rect2] = []
static var _task: int = -1
static var _task_region: Rect2 = Rect2()
static var _task_image: Image
static var _task_started: int = 0
## Milliseconds the last region took on its worker thread, and the most yet.
static var last_region_ms: float = 0.0
static var max_region_ms: float = 0.0
## Milliseconds the last copy into the map and upload took (main thread), and the most yet.
static var last_upload_ms: float = 0.0
static var max_upload_ms: float = 0.0


## Asks for the world x/z rect `r` of the map to be redrawn from the live wears.
static func queue_region(r: Rect2) -> void:
	var region: Rect2 = _whole(r).intersection(map_rect)
	if region.has_area():
		_pending.append(region)


## True while a region is queued or being drawn.
static func busy() -> bool:
	return _task >= 0 or not _pending.is_empty()


## Copies a finished region into the map, then starts the next one. Called
## every frame by live wears in an area (and by tests).
static func poll() -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		last_region_ms = (Time.get_ticks_usec() - _task_started) / 1000.0
		max_region_ms = maxf(max_region_ms, last_region_ms)
		if map_image != null and _task_image != null:
			var t0: int = Time.get_ticks_usec()
			_blit(_task_image, _task_region)
			map.update(map_image)
			map_y = _band(_live_wears())
			_publish()
			last_upload_ms = (Time.get_ticks_usec() - t0) / 1000.0
			max_upload_ms = maxf(max_upload_ms, last_upload_ms)
		_task_image = null
	if _pending.is_empty() or map_image == null:
		return
	var region: Rect2 = _pending.pop_front()
	var items: Array = []
	for w: FloorWear in _live_wears():
		if w.world_rect().intersects(region):
			items.append(w.compose_item())
	_task_region = region
	_task_started = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(func() -> void: _task_image = compose_items(items, region), false, "FloorWear region")


## Waits for every queued region (tests, the start of an area).
static func finish_regions() -> void:
	while busy():
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task_started = Time.get_ticks_usec() - 1
		poll()


static func _blit(img: Image, region: Rect2) -> void:
	var at := Vector2i(((region.position - map_rect.position) * TEXEL).round())
	map_image.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)


static func clear_map() -> void:
	_pending.clear()
	map = null
	map_image = null
	map_rect = Rect2()
	RenderingServer.global_shader_parameter_set("kit_wear_rect", Vector4.ZERO)


## Shared wear (0..1) at a world point, 0 outside the map or its y band.
static func wear_at(world: Vector3) -> float:
	if map_image == null or world.y < map_y.x or world.y > map_y.y:
		return 0.0
	var p: Vector2i = Vector2i(((Vector2(world.x, world.z) - map_rect.position) * TEXEL).floor())
	if p.x < 0 or p.y < 0 or p.x >= map_image.get_width() or p.y >= map_image.get_height():
		return 0.0
	return map_image.get_pixel(p.x, p.y).r


## This wear's rect as an axis-aligned world x/z rect.
func world_rect() -> Rect2:
	var out := Rect2()
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in 4:
		var w: Vector3 = to_global(Vector3(corners[i].x, 0, corners[i].y))
		out = Rect2(w.x, w.z, 0, 0) if i == 0 else out.expand(Vector2(w.x, w.z))
	return out


## This wear's strokes in world x/z: [[a, b, half width, weight], ...].
func strokes() -> Array:
	var out: Array = []
	for p: int in paths.size():
		var weight: float = path_weights[p] if p < path_weights.size() else 1.0
		var line: PackedVector2Array = paths[p]
		for k: int in line.size() - 1:
			out.append([_world_xz(line[k]), _world_xz(line[k + 1]), half_width, weight])
	for path: NodePath in ring_nodes:
		var node: Node3D = get_node_or_null(path)
		if node == null:
			push_warning("FloorWear: no node at %s" % path)
			continue
		var box: AABB = footprint(node)
		if box.size == Vector3.ZERO:
			continue
		var lo := Vector2(box.position.x, box.position.z) - Vector2.ONE * ring_margin
		var hi := Vector2(box.end.x, box.end.z) + Vector2.ONE * ring_margin
		var ring := PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y), lo])
		for k: int in 4:
			out.append([ring[k], ring[k + 1], half_width * .8, ring_weight])
	return out


## The map over world rect `bounds` from every wear's strokes, clipped to each
## wear's own rect: R = wear 0..1 in STEPS dithered levels.
static func compose(wears: Array, bounds: Rect2) -> Image:
	return compose_items(wears.map(func(fw: FloorWear) -> Dictionary: return fw.compose_item()), bounds)


## What compose needs from this wear, gathered on the main thread so the
## compose itself can run on a worker thread: {rect, strokes, fade}.
func compose_item() -> Dictionary:
	return {"rect": world_rect(), "strokes": strokes(), "fade": fade}


## The map over world rect `bounds` from compose_item()s. Pure: safe on a
## worker thread.
static func compose_items(items: Array, bounds: Rect2) -> Image:
	var w: int = int(bounds.size.x * TEXEL)
	var h: int = int(bounds.size.y * TEXEL)
	var wear: PackedFloat32Array = PackedFloat32Array()
	wear.resize(w * h)
	var touched: Array[Rect2i] = []
	for item: Dictionary in items:
		var clip: Rect2i = _texels(item["rect"], bounds, w, h)
		for s: Array in item["strokes"]:
			var box: Rect2i = _stamp(wear, w, bounds, clip, s[0], s[1], s[2], item["fade"], s[3])
			if box.has_area():
				touched.append(box)
	# Break the edges up (feet don't keep to a line): value noise on a world
	# lattice, then a world-anchored Bayer dither down to STEPS levels.
	var origin: Vector2i = Vector2i((bounds.position * TEXEL).round())
	var lx0: int = floori(float(origin.x) / LATTICE)
	var ly0: int = floori(float(origin.y) / LATTICE)
	var gw: int = w / LATTICE + 3
	var gh: int = h / LATTICE + 3
	var lattice: PackedFloat32Array = PackedFloat32Array()
	lattice.resize(gw * gh)
	for gy: int in gh:
		for gx: int in gw:
			lattice[gy * gw + gx] = float(hash([LATTICE_SEED, lx0 + gx, ly0 + gy]) & 0xffff) / 65535.0
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(w * h)
	var done: PackedByteArray = PackedByteArray()
	done.resize(w * h)
	for box: Rect2i in touched:
		for y: int in range(box.position.y, box.end.y):
			var wy: int = origin.y + y
			var fy: float = float(wy) / LATTICE - ly0
			var y0: int = int(fy)
			var ty: float = smoothstep(0.0, 1.0, fy - y0)
			for x: int in range(box.position.x, box.end.x):
				var i: int = y * w + x
				if done[i] != 0:
					continue
				done[i] = 1
				var v: float = wear[i]
				if v <= 0.0:
					continue
				var wx: int = origin.x + x
				var fx: float = float(wx) / LATTICE - lx0
				var x0: int = int(fx)
				var tx: float = smoothstep(0.0, 1.0, fx - x0)
				var n: float = lerpf(lerpf(lattice[y0 * gw + x0], lattice[y0 * gw + x0 + 1], tx),
					lerpf(lattice[(y0 + 1) * gw + x0], lattice[(y0 + 1) * gw + x0 + 1], tx), ty)
				v = clampf(v * (.75 + n * .5), 0.0, 1.0)
				var d: float = BAYER[posmod(wy, 4)][posmod(wx, 4)] / 16.0 - .5
				var level: int = clampi(int(floor(v * STEPS + d * .8)), 0, STEPS)
				bytes[i] = roundi(255.0 * level / STEPS)
	return Image.create_from_data(w, h, false, Image.FORMAT_R8, bytes)


## Raises wear along a world segment: full within `half`, fading over `fade`,
## inside `clip` (texels). Returns the texel box it touched.
static func _stamp(wear: PackedFloat32Array, w: int, bounds: Rect2, clip: Rect2i, a: Vector2, b: Vector2,
		half: float, fade_m: float, weight: float) -> Rect2i:
	var reach: float = half + fade_m
	var lo: Vector2 = (a.min(b) - Vector2.ONE * reach - bounds.position) * TEXEL
	var hi: Vector2 = (a.max(b) + Vector2.ONE * reach - bounds.position) * TEXEL
	var box := Rect2i(Vector2i(lo.floor()), Vector2i.ZERO).expand(Vector2i(hi.ceil()) + Vector2i.ONE).intersection(clip)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var p: Vector2 = bounds.position + Vector2(x + .5, y + .5) / TEXEL
			var dist: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			if dist >= reach:
				continue
			var v: float = weight * (1.0 - smoothstep(half, reach, dist))
			wear[y * w + x] = maxf(wear[y * w + x], v)
	return box


## World rect `r` as a texel box of the map over `bounds`.
static func _texels(r: Rect2, bounds: Rect2, w: int, h: int) -> Rect2i:
	var lo: Vector2i = Vector2i(((r.position - bounds.position) * TEXEL).round())
	var hi: Vector2i = Vector2i(((r.end - bounds.position) * TEXEL).round())
	return Rect2i(lo, hi - lo).intersection(Rect2i(0, 0, w, h))


func _world_xz(p: Vector2) -> Vector2:
	var g: Vector3 = to_global(Vector3(p.x, 0, p.y))
	return Vector2(g.x, g.z)


## The node's visible mesh footprint as a world AABB.
func footprint(node: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child
		if mesh.mesh == null or not mesh.visible:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _queue_rebuild() -> void:
	if _queued:
		return
	_queued = true
	FloorWear._flush_queued.call_deferred()


## The deferred rebuild, skipped if rebuild_now() already ran since it was queued.
static func _flush_queued() -> void:
	if _queued:
		rebuild_now()
