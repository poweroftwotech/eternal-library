class_name MapTrace
extends Resource
## Where you can walk in a place that isn't built from the 4 m grid (phase 11
## step 2, Q6: the Gorge and the camp), traced once by tools/map_trace.gd:
## the highest floor you can reach in each column of a `step` m grid, in the
## place's own frame (x east, z south; the map draws x, z as they are).
##
## The map draws it from two images made with it (`ink`: wash and walls,
## `pencil`: dotted walls), a tile at a time as you reveal them, so drawing
## costs nothing but the tiles.

## Metres a side of a tile: what the map reveals at a time.
const TILE: float = 8.0

## The place ("gorge", "camp").
@export var place: String = ""
## Metres (x, z) of the corner of sample (0, 0), and metres a sample.
@export var origin: Vector2 = Vector2.ZERO
@export var step: float = 0.5
@export var size: Vector2i = Vector2i.ZERO
## Height of the reachable floor per sample (row-major, x fastest; NAN = none):
## the tool's, not saved (the images carry what the map needs).
var height: PackedFloat32Array = PackedFloat32Array()
## Floors traced but not reachable from where you can stand (roofs, ledges): a count, for the tool's report.
@export var unreachable: int = 0
## Per tile (row-major): 1 if it has a floor you can reach. Only those are revealed.
@export var tiles: PackedByteArray = PackedByteArray()
## The doors out of the place: {at: Vector2 (x, z), out: Vector2 (out of the
## place), kind: "threshold" | "sealed", raw: its connector's `to`, to: the
## place it led to when traced}.
@export var doors: Array[Dictionary] = []


func sample_of(m: Vector2) -> Vector2i:
	return Vector2i(floori((m.x - origin.x) / step), floori((m.y - origin.y) / step))


func has_floor(s: Vector2i) -> bool:
	return s.x >= 0 and s.y >= 0 and s.x < size.x and s.y < size.y and not is_nan(height[s.y * size.x + s.x])


## Samples a tile side, and tiles across and down.
func tile_samples() -> int:
	return roundi(TILE / step)


func tile_count() -> Vector2i:
	var n: int = tile_samples()
	return Vector2i(ceili(float(size.x) / n), ceili(float(size.y) / n))


## The tile at metres `m` (x, z), as its index; -1 off the trace.
func tile_of(m: Vector2) -> int:
	var t := Vector2i(floori((m.x - origin.x) / TILE), floori((m.y - origin.y) / TILE))
	var n: Vector2i = tile_count()
	return t.y * n.x + t.x if t.x >= 0 and t.y >= 0 and t.x < n.x and t.y < n.y else -1


## Tiles with a floor within `radius` m of `m` (x, z).
func tiles_near(m: Vector2, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n: Vector2i = tile_count()
	var lo := Vector2i(floori((m.x - radius - origin.x) / TILE), floori((m.y - radius - origin.y) / TILE))
	var hi := Vector2i(floori((m.x + radius - origin.x) / TILE), floori((m.y + radius - origin.y) / TILE))
	for ty: int in range(maxi(lo.y, 0), mini(hi.y, n.y - 1) + 1):
		for tx: int in range(maxi(lo.x, 0), mini(hi.x, n.x - 1) + 1):
			var i: int = ty * n.x + tx
			if i >= tiles.size() or tiles[i] == 0:
				continue
			var near := Vector2(clampf(m.x, origin.x + tx * TILE, origin.x + (tx + 1) * TILE),
				clampf(m.y, origin.y + ty * TILE, origin.y + (ty + 1) * TILE))
			if near.distance_to(m) <= radius:
				out.append(i)
	return out


## The tile's rect in metres (x, z), and in samples (the images' pixels).
func tile_rect(i: int) -> Rect2:
	var n: Vector2i = tile_count()
	return Rect2(origin + Vector2(i % n.x, i / n.x) * TILE, Vector2(TILE, TILE))


func tile_pixels(i: int) -> Rect2:
	var n: Vector2i = tile_count()
	var k: int = tile_samples()
	return Rect2(Vector2(i % n.x, i / n.x) * k, Vector2(k, k))


## What the save checks the tiles against: a re-traced place may tile differently.
func stamp() -> String:
	return "%dx%d@%.1f,%.1f/%.2f" % [size.x, size.y, origin.x, origin.y, step]


static func path_of(id: String) -> String:
	return "res://gen/map/%s_trace.tres" % id


## The images the map draws: wash and walls in ink, dotted walls in pencil.
static func ink_path(id: String) -> String:
	return "res://gen/map/%s_ink.png" % id


static func pencil_path(id: String) -> String:
	return "res://gen/map/%s_pencil.png" % id
