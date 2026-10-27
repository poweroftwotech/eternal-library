@tool
class_name GorgeLayout
extends Resource
## The gorge's plan (phase-6-design.md 5.7.2): what vista.gd hard-codes, as
## data for GorgeGrammar. The defaults are today's numbers, so the rebuilt
## gorge keeps its composition; gen/gorge/gorge_layout.tres is the instance
## the bake reads, yours to change.

## Banks of tiers: centre x, z, radii x, z, top, seed (vista.gd build()).
@export var banks: Array[PackedFloat32Array] = [
	PackedFloat32Array([-78, -84, 37, 36, 25, 1]), PackedFloat32Array([88, -103, 43, 40, 12, 2]),
	PackedFloat32Array([-65, -140, 32, 37, 39, 3]), PackedFloat32Array([67, -163, 37, 42, 35, 4]),
	PackedFloat32Array([-76, -204, 43, 41, 29, 5]), PackedFloat32Array([83, -223, 41, 41, 46, 6]),
	PackedFloat32Array([-39, -262, 43, 36, 48, 7]), PackedFloat32Array([60, -277, 48, 39, 53, 8])]
## The sanctum's foot (its tiers rise from 44 m below it).
@export var sanctum: Vector3 = Vector3(8, -13, -252)
## Aqueducts: from x, y, z, to x, y, z, then the bays a waterfall pours through.
@export var aqueducts: Array[PackedFloat32Array] = [
	PackedFloat32Array([-37, -19, -89, 41, -26, -116, 3]), PackedFloat32Array([-29, -58, -141, 34, -63, -172]),
	PackedFloat32Array([-37, -105, -91, 38, -100, -133]), PackedFloat32Array([-26, -20, -211, 30, -12, -231, 2]),
	PackedFloat32Array([-32, -132, -192, 36, -124, -222]), PackedFloat32Array([-47, 14, -205, -11, 8, -249])]
## Aqueducts (indices) the Gorge area leaves out of its scenery: a walkable
## span takes their place (phase 6 Q9; the near one, 20 m under the balcony).
## The camp's own view keeps them all.
@export var walked: PackedInt32Array = [0]
## Aqueducts left out of the Gorge altogether (fly-mode walk, 2026-10-26: the
## one into the corner by the sanctum went nowhere that made sense).
@export var removed: PackedInt32Array = [5]
