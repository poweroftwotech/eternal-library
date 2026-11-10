class_name MothSwarm
extends MultiMeshInstance3D
## Every candle moth of one room (phase 19 step 2), one MultiMesh: a few round
## each burning flame, lit in its colour, and in the Garden Court a few loose
## over the beds. All their flight is in creature_moth.gdshader; nothing
## here runs per frame. They don't mind you.

var def: CreatureDef
## Global box round all of them (Fauna's sleep test).
var bounds: AABB
## Where to look at them (tests).
var focus: Vector3


## `flames`: [{at, colour}] global. `loose`: points on the floor to wander over.
func setup(d: CreatureDef, flames: Array, loose: PackedVector3Array, rng: RandomNumberGenerator, abandoned: bool) -> void:
	def = d
	name = "%s_%d" % [d.id, rng.randi() & 0xffff]
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spots: Array[Dictionary] = []     # {at, colour, radius, loose}
	var order: Array = _seeded_order(flames, rng)
	for f: Dictionary in order:
		if rng.randf() >= d.flame_share:
			continue
		var n: int = rng.randi_range(d.group_size.x, d.group_size.y)
		if abandoned:
			n = maxi(1, n >> 1)
		for k: int in n:
			if spots.size() >= d.room_cap:
				break
			spots.append({"at": f["at"], "colour": f["colour"], "radius": rng.randf_range(0.18, 0.55), "loose": 0.0})
	for p: Vector3 in loose:
		if spots.size() >= d.room_cap:
			break
		spots.append({"at": p + Vector3(0, 1.1, 0), "colour": Color(1.0, 0.97, 0.9), "radius": rng.randf_range(2.0, 3.5), "loose": 1.0})
	if spots.is_empty():
		return
	bounds = AABB(spots[0]["at"], Vector3.ZERO)
	for s: Dictionary in spots:
		bounds = bounds.expand(s["at"])
	bounds = bounds.grow(4.0)
	position = bounds.get_center()
	focus = spots[0]["at"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = AirBody.moth_mesh()
	mm.instance_count = spots.size()
	for i: int in spots.size():
		var s: Dictionary = spots[i]
		var size: float = d.length_m * rng.randf_range(d.length_spread.x, d.length_spread.y)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), (s["at"] as Vector3) - position))
		var speed: float = rng.randf_range(d.speed.x, d.speed.y) * (1.0 if rng.randf() < 0.5 else -1.0)
		mm.set_instance_custom_data(i, Color(rng.randf(), s["radius"], speed, s["loose"]))
		mm.set_instance_color(i, s["colour"])
	multimesh = mm
	material_override = AirBody.material(d)
	custom_aabb = AABB(bounds.position - position, bounds.size)


## Nothing to think: the shader flies them.
func tick(_delta: float, _player: Vector3, _moving: float) -> void:
	pass


static func _seeded_order(items: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = items.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out
