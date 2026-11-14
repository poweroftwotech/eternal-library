class_name EelHoles
extends MultiMeshInstance3D
## Spiny eels (phase 20 step 3, C03) in one body of water: holes in the stone
## under the surface (a pier, a causeway, a channel's side), and an eel or two
## living in them. Drawn as one MultiMesh (the eels) and a child MultiMesh (the
## holes); Fauna ticks it.
##
## An eel lies in its hole with its head out (the rest of it is in the stone).
## Now and then it slides out, along the bottom to another hole, turns round
## in front of it and backs in, tail first, till only its head shows. Come
## close and it draws back in; it looks out again a while after you have gone.

enum { REST, HIDE, OUT, SWIM, TURN, BACK }

## How far its head shows out of the hole at rest (m).
const HEAD_OUT: float = 0.16
## Seconds between trips to another hole.
const STAY: Vector2 = Vector2(25.0, 70.0)
## You this close (m) and it draws in; it waits this long (s) after you leave.
const SHY_STILL: float = 1.8
const SHY_MOVING: float = 3.0
const COME_OUT: Vector2 = Vector2(4.0, 9.0)
## Holes: at most this many, this far apart (m), on stone at least WALL_DEEP
## thick (the eel's body goes in), this far over the floor (m).
const MOST_HOLES: int = 10
const APART: float = 0.9
const WALL_DEEP: float = 0.62
const OVER_FLOOR: float = 0.12

var def: CreatureDef
var body: WaterBody
## {at (the mouth, global), n (out of the stone), floor}.
var holes: Array[Dictionary] = []
var eels: Array[Dictionary] = []
var bounds: AABB
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _hole_mm: MultiMeshInstance3D
var _taken: Dictionary = {}


## Holes on the stone under `b`'s surface: walls met by level rays from the
## places a fish can be, low over the floor, thick enough to go into.
static func find_holes(b: WaterBody, space: PhysicsDirectSpaceState3D, seed_value: int, min_depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var places: PackedVector3Array = b.deep_samples(min_depth)
	if places.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = HabitatScan.WORLD_MASK
	for _t: int in mini(36, places.size()):
		if out.size() >= MOST_HOLES:
			break
		var p: Vector3 = places[rng.randi() % places.size()]
		var from := Vector3(p.x, p.y + OVER_FLOOR, p.z)
		if from.y > b.surface - 0.14:
			continue
		var turn: float = rng.randf() * TAU
		for k: int in 8:
			var dir := Vector3(cos(turn + k * TAU / 8.0), 0, sin(turn + k * TAU / 8.0))
			q.from = from
			q.to = from + dir * 1.4
			q.hit_back_faces = false
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var n: Vector3 = hit["normal"]
			if absf(n.y) > 0.35:
				continue
			n = Vector3(n.x, 0, n.z).normalized()
			var at: Vector3 = hit["position"]
			if out.any(func(h: Dictionary) -> bool: return (h["at"] as Vector3).distance_to(at) < APART):
				continue
			# Thick: from inside the stone, nothing between there and the mouth
			# (a thin wall's far face would stop the ray).
			q.from = at - n * WALL_DEEP
			q.to = at + n * 0.02
			if not space.intersect_ray(q).is_empty():
				continue
			# Open water in front of it, the eel's length.
			q.from = at + n * 0.05
			q.to = at + n * 0.7
			if not space.intersect_ray(q).is_empty():
				continue
			out.append({"at": at + n * 0.004, "n": n, "floor": p.y})
			break
	return out


func setup(d: CreatureDef, b: WaterBody, found: Array[Dictionary], count: int, seed_value: int) -> void:
	def = d
	body = b
	holes = found
	_rng.seed = seed_value
	name = "%s_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	position = Vector3(b.bounds.get_center().x, b.surface, b.bounds.get_center().z)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = Fauna.SLEEP_DISTANCE + 5.0
	bounds = b.bounds.grow(0.8)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = EelBody.mesh()
	mm.instance_count = count
	multimesh = mm
	material_override = EelBody.material(d)
	# The holes, every one, eel or not.
	_hole_mm = MultiMeshInstance3D.new()
	_hole_mm.name = "Holes"
	_hole_mm.top_level = true
	_hole_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hm := MultiMesh.new()
	hm.transform_format = MultiMesh.TRANSFORM_3D
	hm.mesh = EelBody.hole_mesh()
	hm.instance_count = holes.size()
	_hole_mm.multimesh = hm
	_hole_mm.material_override = EelBody.hole_material()
	add_child(_hole_mm)
	_hole_mm.global_position = position
	for i: int in holes.size():
		var h: Dictionary = holes[i]
		var n: Vector3 = h["n"]
		var size: float = d.length_m * 0.16 * _rng.randf_range(0.9, 1.25)
		hm.set_instance_transform(i, Transform3D(Basis.looking_at(-n, Vector3.UP).scaled(Vector3.ONE * size), (h["at"] as Vector3) + n * 0.003 - position))
	var free: Array[int] = []
	for i: int in holes.size():
		free.append(i)
	for k: int in count:
		var hi: int = free.pop_at(_rng.randi() % free.size())
		_taken[hi] = true
		var len: float = d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y)
		var e: Dictionary = {"hole": hi, "to": -1, "state": REST, "out": HEAD_OUT * _rng.randf_range(0.6, 1.0), "len": len,
			"timer": _rng.randf_range(STAY.x * 0.3, STAY.y), "pos": Vector3.ZERO, "fwd": Vector3.FORWARD, "phase": _rng.randf(), "shade": _rng.randf(),
			"swim": 0.0, "path": []}
		eels.append(e)
		_in_hole(e)
		mm.set_instance_custom_data(k, Color(e["phase"], 0.5, 0.0, e["shade"]))
	_draw_all()


func count() -> int:
	return eels.size()


## Where an eel lies in its hole, `out` m of it showing.
func _in_hole(e: Dictionary) -> void:
	var h: Dictionary = holes[int(e["hole"])]
	var n: Vector3 = h["n"]
	e["fwd"] = n
	e["pos"] = (h["at"] as Vector3) - n * (float(e["len"]) * 0.5 - float(e["out"]))


## One step. `player` is the player's feet; `moving` its speed (m/s).
func tick(delta: float, player: Vector3, moving: float) -> void:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var near_y: bool = player.y < body.surface + 2.2
	for i: int in eels.size():
		var e: Dictionary = eels[i]
		var pos: Vector3 = e["pos"]
		var flat: float = Vector2(pos.x - player.x, pos.z - player.z).length()
		var shy: bool = near_y and flat < (SHY_MOVING if moving > 0.4 else SHY_STILL)
		var state: int = e["state"]
		match state:
			REST:
				e["out"] = move_toward(float(e["out"]), HEAD_OUT, delta * 0.05)
				e["timer"] = float(e["timer"]) - delta
				if shy:
					e["state"] = HIDE
					e["timer"] = _rng.randf_range(COME_OUT.x, COME_OUT.y)
				elif float(e["timer"]) <= 0.0:
					_leave(e)
				_in_hole(e)
			HIDE:
				# In fast; out slowly once you have gone and it has waited.
				if shy:
					e["timer"] = _rng.randf_range(COME_OUT.x, COME_OUT.y)
					e["out"] = move_toward(float(e["out"]), -0.08, delta * 0.9)
				else:
					e["timer"] = float(e["timer"]) - delta
					e["out"] = move_toward(float(e["out"]), -0.08, delta * 0.9)
					if float(e["timer"]) <= 0.0:
						e["state"] = REST
						e["out"] = -0.02
						e["timer"] = _rng.randf_range(STAY.x, STAY.y)
				_in_hole(e)
			OUT, SWIM, TURN, BACK:
				_travel(e, delta, shy)
		# Its wave: slow in the hole, quick on the move.
		var swim: float = move_toward(float(e["swim"]), 1.0 if int(e["state"]) in [OUT, SWIM, TURN, BACK] else 0.0, delta * 2.0)
		e["swim"] = swim
		multimesh.set_instance_custom_data(i, Color(e["phase"], lerpf(0.45, 1.6 if shy else 1.1, swim), swim, e["shade"]))
	_draw_all()


## Off to another hole it can swim to in a line along the bottom.
func _leave(e: Dictionary) -> void:
	e["timer"] = _rng.randf_range(STAY.x, STAY.y)
	var from: Dictionary = holes[int(e["hole"])]
	var options: Array[int] = []
	for k: int in holes.size():
		if k == int(e["hole"]) or _taken.has(k):
			continue
		var a: Vector3 = (from["at"] as Vector3) + (from["n"] as Vector3) * 0.5
		var b: Vector3 = (holes[k]["at"] as Vector3) + (holes[k]["n"] as Vector3) * 0.5
		if a.distance_to(b) < 9.0 and HabitatScan.clear_path(_space, a, b):
			options.append(k)
	if options.is_empty():
		return
	var to: int = options[_rng.randi() % options.size()]
	_taken[to] = true
	e["to"] = to
	e["state"] = OUT


## Out of the hole, along the bottom, round in front of the new one, and in
## backwards. Startled on the way it hurries.
func _travel(e: Dictionary, delta: float, shy: bool) -> void:
	var speed: float = def.speed.y if shy else def.speed.x
	var len: float = e["len"]
	var from: Dictionary = holes[int(e["hole"])]
	var to: Dictionary = holes[int(e["to"])]
	var n_to: Vector3 = to["n"]
	var low: float = OVER_FLOOR * 0.4
	var front: Vector3 = (to["at"] as Vector3) + n_to * (len * 0.55)
	front.y = float(to["floor"]) + low
	var pos: Vector3 = e["pos"]
	match int(e["state"]):
		OUT:
			# Straight out of the mouth till its tail is clear, sinking to the bottom.
			var n: Vector3 = from["n"]
			pos += n * speed * delta
			pos.y = move_toward(pos.y, float(from["floor"]) + low, delta * 0.1)
			e["fwd"] = n
			if (pos - (from["at"] as Vector3)).dot(n) > len * 0.55:
				e["state"] = SWIM
				_taken.erase(int(e["hole"]))
		SWIM:
			var d: Vector3 = front - pos
			d.y = 0.0
			if d.length() < 0.06:
				e["state"] = TURN
			else:
				var fwd: Vector3 = (e["fwd"] as Vector3).slerp(d.normalized(), clampf(delta * 3.0, 0.0, 1.0)).normalized()
				e["fwd"] = fwd
				pos += fwd * minf(speed * delta, d.length())
				pos.y = move_toward(pos.y, lerpf(float(to["floor"]), float(from["floor"]), clampf(d.length() / 4.0, 0.0, 1.0)) + low, delta * 0.1)
		TURN:
			# Round to face out of the hole, swinging the tail toward it.
			var fwd: Vector3 = (e["fwd"] as Vector3).slerp(n_to, clampf(delta * 2.2, 0.0, 1.0)).normalized()
			if fwd.is_equal_approx(e["fwd"]) or fwd.dot(n_to) > 0.995:
				fwd = n_to
				e["state"] = BACK
			e["fwd"] = fwd
		BACK:
			var mouth: Vector3 = to["at"]
			var want: Vector3 = mouth - n_to * (len * 0.5 - HEAD_OUT)
			pos = pos.move_toward(want, speed * 0.6 * delta)
			e["fwd"] = n_to
			if pos.distance_to(want) < 0.01:
				e["hole"] = e["to"]
				e["to"] = -1
				e["out"] = HEAD_OUT
				e["state"] = HIDE if shy else REST
				e["timer"] = _rng.randf_range(COME_OUT.x, COME_OUT.y) if shy else _rng.randf_range(STAY.x, STAY.y)
	e["pos"] = pos


func _draw_all() -> void:
	for i: int in eels.size():
		var e: Dictionary = eels[i]
		var s: float = e["len"]
		var fwd: Vector3 = e["fwd"]
		var hidden: bool = int(e["state"]) == HIDE and float(e["out"]) < -0.05
		var basis: Basis = Basis.looking_at(fwd, Vector3.UP).scaled(Vector3.ONE * (0.0 if hidden else s))
		multimesh.set_instance_transform(i, Transform3D(basis, (e["pos"] as Vector3) - position))


## What each eel is doing, for the overlay.
func doing(i: int) -> String:
	return ["in its hole", "drawn in", "coming out", "swimming to another hole", "turning", "backing in"][int(eels[i]["state"])]
