class_name CatBand
extends Node3D
## The cats of one room (phase 19 step 3): each a CatBody and a small mind.
## A cat rests somewhere (asleep on a rug, sitting, washing, watching the
## fish), then strolls the room's walked lanes (LaneGraph) to somewhere else.
## It looks at you when you are near, gets up and moves off if you all but
## step on it, and startles and trots away if you run at it. It has no
## collision: you never bump into it (phase 19 Q7). Ticked by Fauna.

enum { REST, WALK, STARTLE, FLEE }
## The walking and trotting speeds (m/s) the walk animation's rates below
## were set for; a cat's own speeds are its kind's (CreatureDef.speed).
const WALK_SPEED: float = 0.65
const WALK_RATE: float = 1.6
const TROT_SPEED: float = 2.8
const TROT_RATE: float = 4.2
const TURN_RATE: float = 7.0
## It looks at you within this far (m); you this close makes it move off.
## Faster than this (m/s) is running at it.
const RUN_SPEED: float = 4.5
const STARTLE_S: float = 0.55
## The model's own length (m); a cat is drawn at its kind's length_m over this.
const MODEL_LENGTH: float = 0.5
## A stroll goes at most this many points on (a point is 0.5 to 1 m).
const STROLL_HOPS: int = 45

var def: CreatureDef
var graph: LaneGraph
var bounds: AABB
var cats: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(d: CreatureDef, g: LaneGraph, count: int, seed_value: int, coats: Array[int] = []) -> void:
	def = d
	graph = g
	bounds = g.bounds.grow(1.0)
	_rng.seed = seed_value
	var taken: Array[int] = []
	for i: int in count:
		var node: int = _free_spot(taken)
		if node < 0:
			# No free rest spot: anywhere it lives.
			for tries: int in 12:
				node = g.home[_rng.randi() % g.home.size()]
				if not taken.has(node):
					break
		taken.append(node)
		var body := CatBody.new()
		add_child(body)
		var coat: int = _rng.randi()
		body.set_coat(coats[i] if i < coats.size() else coat)
		body.scale = Vector3.ONE * (d.length_m / MODEL_LENGTH) * _rng.randf_range(d.length_spread.x, d.length_spread.y)
		body.global_position = g.points[node]
		body.rotation.y = _rng.randf() * TAU
		var cat: Dictionary = {"body": body, "node": node, "path": PackedInt32Array(), "leg": 0, "t": 0.0, "state": REST, "timer": 0.0,
			"speed": d.speed.x, "face": null, "chain": false}
		cats.append(cat)
		_rest(cat, true)


func count() -> int:
	return cats.size()


func tick(delta: float, player: Vector3, moving: float) -> void:
	for cat: Dictionary in cats:
		var body: CatBody = cat["body"]
		var away: Vector3 = body.global_position - player
		var dist: float = away.length()
		var state: int = cat["state"]
		# You.
		if state == REST or state == WALK:
			if dist < def.startle_radius and moving > RUN_SPEED:
				cat["state"] = STARTLE
				cat["timer"] = STARTLE_S
				cat["face"] = null
				body.play("startle", 0.08)
				state = STARTLE
			elif dist < def.crowd_radius and state == REST:
				_leave(cat, player, false)
				state = cat["state"]
		var near: bool = dist < def.look_radius
		# It looks at you only while it rests: a cat walking with its head
		# turned aside reads wrong (it would only look if it were coming to you).
		if near and state == REST:
			body.looking = true
			body.look_at_point = player + Vector3(0, 1.5, 0)
		elif cat["face"] != null and state == REST:
			body.looking = true
			body.look_at_point = cat["face"]
		else:
			body.looking = false
		match state:
			REST:
				cat["timer"] = float(cat["timer"]) - delta
				if cat["face"] != null:
					_turn(body, (cat["face"] as Vector3) - body.global_position, delta * 0.4)
				if float(cat["timer"]) <= 0.0:
					_next(cat)
			STARTLE:
				cat["timer"] = float(cat["timer"]) - delta
				_turn(body, away, delta)
				if float(cat["timer"]) <= 0.0:
					_leave(cat, player, true)
			WALK, FLEE:
				_walk(cat, delta)


## Along its path; at the end, rests.
func _walk(cat: Dictionary, delta: float) -> void:
	var body: CatBody = cat["body"]
	var path: PackedInt32Array = cat["path"]
	var leg: int = cat["leg"]
	var left: float = float(cat["speed"]) * delta
	while left > 0.0 and leg < path.size() - 1:
		var a: Vector3 = graph.points[path[leg]]
		var b: Vector3 = graph.points[path[leg + 1]]
		var length: float = maxf(a.distance_to(b), 0.01)
		var t: float = float(cat["t"]) + left / length
		if t >= 1.0:
			left = (t - 1.0) * length
			leg += 1
			cat["t"] = 0.0
			cat["node"] = path[leg]
		else:
			left = 0.0
			cat["t"] = t
	cat["leg"] = leg
	if leg >= path.size() - 1:
		body.global_position = graph.points[path[path.size() - 1]]
		var fled: bool = int(cat["state"]) == FLEE
		_rest(cat, false, fled)
		return
	var from: Vector3 = graph.points[path[leg]]
	var to: Vector3 = graph.points[path[leg + 1]]
	body.global_position = from.lerp(to, float(cat["t"]))
	_turn(body, to - from, delta)


static func _turn(body: CatBody, dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	# A cat faces its own -Z.
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, TURN_RATE * delta))


## Settles where it is: on something soft it may sleep; by water it watches.
func _rest(cat: Dictionary, first: bool, wary: bool = false) -> void:
	var body: CatBody = cat["body"]
	var node: int = cat["node"]
	cat["state"] = REST
	cat["face"] = null
	cat["chain"] = false
	var roll: float = _rng.randf()
	var at: float = _rng.randf() * 3.0 if first else 0.0
	if wary:
		body.play("idle", 0.3)
		cat["timer"] = _rng.randf_range(3.0, 6.0)
		return
	for w: Dictionary in graph.watch:
		if int(w["node"]) == node:
			body.play("sit", 0.45, at)
			cat["face"] = w["at"]
			cat["timer"] = _rng.randf_range(15.0, 40.0)
			return
	if graph.spots.has(node):
		if roll < 0.5:
			body.play("sleep", 0.6, at)
			cat["timer"] = _rng.randf_range(25.0, 70.0)
		elif roll < 0.8:
			body.play("sit", 0.45, at)
			cat["timer"] = _rng.randf_range(8.0, 25.0)
			cat["chain"] = true
		else:
			body.play("wash", 0.45, at)
			cat["timer"] = _rng.randf_range(5.0, 11.0)
		return
	if roll < 0.35:
		body.play("idle", 0.35, at)
		cat["timer"] = _rng.randf_range(2.0, 5.0)
	elif roll < 0.75:
		body.play("sit", 0.45, at)
		cat["timer"] = _rng.randf_range(6.0, 18.0)
		cat["chain"] = true
	else:
		body.play("wash", 0.45, at)
		cat["timer"] = _rng.randf_range(5.0, 10.0)


## Done resting: a wash after a sit, sometimes; else off to somewhere else.
func _next(cat: Dictionary) -> void:
	var body: CatBody = cat["body"]
	if bool(cat["chain"]) and _rng.randf() < 0.35:
		cat["chain"] = false
		body.play("wash", 0.4)
		cat["timer"] = _rng.randf_range(4.0, 9.0)
		return
	var node: int = cat["node"]
	var back: PackedInt32Array = graph.reach(node, STROLL_HOPS)
	var taken: Array[int] = _others(cat)
	var open: Array[int] = []       # where it could go
	var soft: Array[int] = []
	var water: Array[int] = []
	for i: int in back.size():
		if back[i] >= 0 and i != node and not taken.has(i):
			open.append(i)
	for s: int in graph.spots:
		if open.has(s):
			soft.append(s)
	for w: Dictionary in graph.watch:
		if open.has(int(w["node"])):
			water.append(int(w["node"]))
	if open.is_empty():
		cat["timer"] = _rng.randf_range(4.0, 10.0)     # nowhere to go: stays
		return
	var roll: float = _rng.randf()
	var to: int = open[_rng.randi() % open.size()]
	if roll < 0.45 and not soft.is_empty():
		to = soft[_rng.randi() % soft.size()]
	elif roll < 0.65 and not water.is_empty():
		to = water[_rng.randi() % water.size()]
	_set_off(cat, graph.path(node, to, back), WALK, def.speed.x, WALK_RATE * def.speed.x / WALK_SPEED)


## Away from the player: at a trot when startled, else a stroll.
func _leave(cat: Dictionary, player: Vector3, startled: bool) -> void:
	var node: int = cat["node"]
	# Mid-lane when startled: from the end of the leg it is on.
	var path0: PackedInt32Array = cat["path"]
	if int(cat["leg"]) < path0.size() - 1 and float(cat["t"]) > 0.0:
		node = path0[int(cat["leg"]) + 1]
	var back: PackedInt32Array = graph.reach(node, 40 if startled else 12)
	var best: int = -1
	var best_d: float = graph.points[node].distance_to(player) + 1.0
	var taken: Array[int] = _others(cat)
	for i: int in back.size():
		if back[i] < 0 or taken.has(i):
			continue
		var d: float = graph.points[i].distance_to(player)
		if d > best_d:
			best_d = d
			best = i
	var body: CatBody = cat["body"]
	if best < 0:
		cat["state"] = REST
		cat["timer"] = _rng.randf_range(3.0, 6.0)
		body.play("idle", 0.3)
		return
	var path: PackedInt32Array = graph.path(node, best, back)
	if node != int(cat["node"]):
		path.insert(0, int(cat["node"]))
		_set_off(cat, path, FLEE if startled else WALK, def.speed.y if startled else def.speed.x, (TROT_RATE * def.speed.y / TROT_SPEED) if startled else (WALK_RATE * def.speed.x / WALK_SPEED), float(cat["t"]))
	else:
		_set_off(cat, path, FLEE if startled else WALK, def.speed.y if startled else def.speed.x, (TROT_RATE * def.speed.y / TROT_SPEED) if startled else (WALK_RATE * def.speed.x / WALK_SPEED))


func _set_off(cat: Dictionary, path: PackedInt32Array, state: int, speed: float, rate: float, t: float = 0.0) -> void:
	cat["path"] = path
	cat["leg"] = 0
	cat["t"] = t
	cat["state"] = state
	cat["speed"] = speed
	cat["face"] = null
	(cat["body"] as CatBody).play("walk", 0.3, 0.0, rate)


## Where the other cats are or are going.
func _others(cat: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for o: Dictionary in cats:
		if is_same(o, cat):
			continue
		out.append(int(o["node"]))
		var path: PackedInt32Array = o["path"]
		if int(o["state"]) != REST and not path.is_empty():
			out.append(path[path.size() - 1])
	return out


func _free_spot(taken: Array[int]) -> int:
	var free: Array[int] = []
	for s: int in graph.spots:
		if not taken.has(s):
			free.append(s)
	return free[_rng.randi() % free.size()] if not free.is_empty() else -1
