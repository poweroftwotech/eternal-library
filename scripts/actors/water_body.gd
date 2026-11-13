class_name WaterBody
extends RefCounted
## One body of still water a creature can live in (phase 19, docs/npc/phase-19-design.md
## section 3): the water surfaces of a room that touch at one height, merged.
## HabitatScan finds them from the meshes drawn with the water shader and
## sounds them with rays for where a fish can swim.

## Height of the surface (global).
var surface: float = 0.0
## Its extent (global), the planes' boxes merged.
var bounds: AABB
## The surface's triangles in x/z (global), three points each.
var tris: PackedVector2Array = PackedVector2Array()
## The water's material (its resource path, or "" for a scene's own).
var material: String = ""
## Places a fish can be: x, the floor's height under it, z. Filled by
## HabitatScan.sound(), a slice at a time.
var samples: PackedVector3Array = PackedVector3Array()
## Sounding: the grid still to test, and how far through it.
var _grid: PackedVector2Array = PackedVector2Array()
var _next: int = 0
## The collision and the meshes of the kit piece the water is part of (a
## fountain's basin and column), and whether it was sounded by them
## (HabitatScan.sound: its collision is one block over the water).
var own_bodies: Array[RID] = []
var own_meshes: Array = []
var by_sight: bool = false


## Surface area in m2 (of the triangles).
func area() -> float:
	var a: float = 0.0
	for i: int in range(0, tris.size(), 3):
		a += absf((tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i])) * 0.5
	return a


func contains_xz(p: Vector2) -> bool:
	if p.x < bounds.position.x or p.y < bounds.position.z or p.x > bounds.end.x or p.y > bounds.end.z:
		return false
	for i: int in range(0, tris.size(), 3):
		if Geometry2D.point_is_inside_triangle(p, tris[i], tris[i + 1], tris[i + 2]):
			return true
	return false


## Sounded to the end.
func sounded() -> bool:
	return _next >= _grid.size() and not _grid.is_empty()


## The mean depth of the places found (m).
func mean_depth() -> float:
	if samples.is_empty():
		return 0.0
	var d: float = 0.0
	for s: Vector3 in samples:
		d += surface - s.y
	return d / samples.size()


## Samples at least `depth` deep.
func deep_samples(depth: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: Vector3 in samples:
		if surface - s.y >= depth:
			out.append(s)
	return out
