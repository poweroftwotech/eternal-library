class_name BirdBand
extends Node3D
## The nightingales of one garden (phase 20 step 1, C19), each a BirdBody and a
## small mind. Ticked by Fauna.
##
## Where it can be: perches found on what you see of the room's plants
## (find_perches): the tops of branches and stems (high), the heads of
## flowers (low). Two birds share a garden's song: one sings a phrase, the
## other answers in the pause, the way nightingales counter-sing.
##
## What it does: sings in bouts from a high perch (head up, beak working,
## throat swelling), rests between bouts (looks about in quick jerks, cocks
## its tail, hops along the branch, flies short arcs to another perch), visits
## the flowers. You: within 7 m it turns its head to you; within 3 m, or
## running within 8 m, it stops singing, gives its alarm and flies to a higher
## perch away from you, and won't sing again until you have been quiet a
## while. It never touches you and has no collision (phase 19 Q7).

enum { PERCH, FLY, PECK }

## Which parts of the plants it perches on (the kit names a piece's parts
## "<piece>__<part>"): branches and stems hold a bird; flower heads are where
## it feeds. Leaves are cards hanging in the air: never perched on.
const BRANCH_PARTS: PackedStringArray = ["__wood", "__bark", "__stems", "_figs_wood"]
const FLOWER_PARTS: PackedStringArray = ["__flowers"]
## A perch this high over the floor (m) or more is a high perch: it sings
## from there and flees up to there.
const HIGH: float = 1.4
## And no higher than this (m): up under a roof it is lost in the dark (the
## camp's tree reaches its rafters).
const TOP: float = 6.5
## Perches keep this far apart (m), and a room has at most this many.
const APART: float = 0.35
const MOST: int = 90
const MOST_FLOWERS: int = 30
## The song: heard this far (m); quieter or louder than as made (dB).
const SONG_REACH: float = 30.0
const SONG_DB: float = -3.0
const RUN_SPEED: float = 4.5
const LOOK_RADIUS: float = 7.0
## Running this near (m) silences it too, even if not this close.
const HUSH_RADIUS: float = 8.0
## Quiet this long (s), you not near or running, before it sings again.
const CALM_S: float = 6.0
const FLY_SPEED: float = 4.5

var def: CreatureDef
var bounds: AABB
var birds: Array[Dictionary] = []
## [{at: Vector3, high: bool, height: float}] (global).
var perches: Array[Dictionary] = []
var space: PhysicsDirectSpaceState3D
## The bird singing now (index), or -1: one at a time.
var singer: int = -1
var _rng := RandomNumberGenerator.new()
var _songs: Array[AudioStream] = []
var _calls: Array[AudioStream] = []
var _wings: Array[AudioStream] = []
var _last_song: int = -1


## The perches in `boxes` (Fauna's [MeshInstance3D, global AABB] of a room).
static func find_perches(boxes: Array, s: PhysicsDirectSpaceState3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = LaneGraph.WORLD     # (the camp's world is on layer 9 as well as 1)
	# Every candidate first, branches before flowers (a court's two dozen
	# shrubs would otherwise fill the room's perches before its tree is read),
	# each kind in a fixed shuffled order so they spread over the room.
	var branches: Array = []     # [point, the plant part's middle]
	var flowers: Array = []
	for e: Array in boxes:
		var m: MeshInstance3D = e[0]
		if not is_instance_valid(m) or m.mesh == null:
			continue
		var part: String = str(m.name).to_lower()
		var branch: bool = _has(part, BRANCH_PARTS)
		if not branch and not _has(part, FLOWER_PARTS):
			continue
		for local: Vector3 in _candidates(m.mesh, branch):
			(branches if branch else flowers).append([m.global_transform * local, (e[1] as AABB).get_center()])
	var flower_count: int = 0
	for pass_index: int in 2:
		var is_branch: bool = pass_index == 0
		for cand: Array in _shuffled(branches if is_branch else flowers):
			var at: Vector3 = cand[0]
			if out.size() >= (MOST - MOST_FLOWERS if is_branch else MOST) or (not is_branch and flower_count >= MOST_FLOWERS):
				break
			var near: bool = false
			for o: Dictionary in out:
				if (o["at"] as Vector3).distance_squared_to(at) < APART * APART:
					near = true
					break
			if near:
				continue
			# Its height over the floor, and room above it to stand.
			q.from = at + Vector3(0, 0.02, 0)
			q.to = at - Vector3(0, 14.0, 0)
			var down: Dictionary = s.intersect_ray(q)
			if down.is_empty():
				continue
			q.from = at + Vector3(0, 0.02, 0)
			q.to = at + Vector3(0, 0.28, 0)
			if not s.intersect_ray(q).is_empty():
				continue
			# Room round it (a branch tip pushed into a gallery's shelves, the
			# camp's, is no perch: the bird would sit inside the furniture).
			var boxed: bool = false
			var pt := PhysicsPointQueryParameters3D.new()
			pt.collision_mask = LaneGraph.WORLD
			pt.position = at + Vector3(0, 0.06, 0)
			if not s.intersect_point(pt, 1).is_empty():
				continue     # (a crown's leaf poking into a shelf: inside it)
			for k: int in 4:
				var dir := Vector3(cos(k * PI * 0.5), 0.0, sin(k * PI * 0.5))
				q.from = at + Vector3(0, 0.08, 0)
				q.to = q.from + dir * 0.3
				if not s.intersect_ray(q).is_empty():
					boxed = true
					break
			if boxed:
				continue
			var height: float = at.y - (down["position"] as Vector3).y
			if height < 0.25 or height > TOP:
				continue
			out.append({"at": at, "high": is_branch and height >= HIGH, "height": height, "flower": not is_branch, "plant": cand[1]})
			if not is_branch:
				flower_count += 1
	return out


## Candidates ([point, …]) in an order fixed by their places (the same every
## run), spread over the room.
static func _shuffled(cands: Array) -> Array:
	var out: Array = cands.duplicate()
	out.sort_custom(func(a: Array, b: Array) -> bool: return hash((a[0] as Vector3).snapped(Vector3.ONE * 0.01)) < hash((b[0] as Vector3).snapped(Vector3.ONE * 0.01)))
	return out


static func _has(part: String, keys: PackedStringArray) -> bool:
	for k: String in keys:
		if part.contains(k):
			return true
	return false


static var _cache: Dictionary = {}


## A mesh's places to stand (its own space): the tops of branches (faces
## turned up, in the upper part of the piece), or the tops of flower heads.
## Read once per mesh.
static func _candidates(mesh: Mesh, branch: bool) -> PackedVector3Array:
	var key: int = mesh.get_rid().get_id()
	if _cache.has(key):
		return _cache[key]
	var box: AABB = mesh.get_aabb()
	var floor_y: float = box.position.y + box.size.y * (0.3 if branch else 0.7)
	var pts := PackedVector3Array()
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			if v.y < floor_y:
				continue
			if branch and i < norms.size() and norms[i].y < 0.35:
				continue
			pts.append(v)
	# Spread out: at most a few per metre of the piece, in a fixed order.
	var most: int = clampi(int(maxf(box.size.x, box.size.z) / 0.5), 4, 40)
	var picked := PackedVector3Array()
	var stride: int = maxi(1, pts.size() / (most * 4))
	for i: int in range(0, pts.size(), stride):
		var p: Vector3 = pts[(i * 7919) % pts.size()]
		var ok: bool = true
		for o: Vector3 in picked:
			if o.distance_squared_to(p) < APART * APART:
				ok = false
				break
		if ok:
			picked.append(p)
			if picked.size() >= most:
				break
	_cache[key] = picked
	return picked


## Whether a room's perches make a garden for it: enough high perches to sing
## from.
static func is_garden(found: Array[Dictionary]) -> bool:
	return found.filter(func(p: Dictionary) -> bool: return bool(p["high"])).size() >= 4


func setup(d: CreatureDef, found: Array[Dictionary], count: int, seed_value: int, s: PhysicsDirectSpaceState3D) -> void:
	def = d
	perches = found
	space = s
	_rng.seed = seed_value
	name = "%s_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	var sound: SoundSystem = SoundSystem.it()
	if sound != null:
		_songs = sound.clips("nightingale_song")
		_calls = sound.clips("nightingale_call")
		_wings = sound.clips("wings_small")
	bounds = AABB(perches[0]["at"], Vector3.ZERO)
	for p: Dictionary in perches:
		bounds = bounds.expand(p["at"])
	bounds = bounds.grow(2.0)
	var highs: Array[int] = _high_perches()
	for i: int in count:
		var body := BirdBody.new()
		add_child(body)
		body.scale = Vector3.ONE * (d.length_m / BirdBody.SIZE) * _rng.randf_range(d.length_spread.x, d.length_spread.y)
		var perch: int = highs[_rng.randi() % highs.size()] if not highs.is_empty() else 0
		body.global_position = perches[perch]["at"]
		body.rotation.y = _rng.randf() * TAU
		birds.append({"body": body, "perch": perch, "state": PERCH, "timer": _rng.randf_range(1.0, 4.0),
			"rest": _rng.randf_range(2.0, 12.0), "bout": 0, "gap": 0.0, "voice": null, "song_end": 0.0, "wary": 0.0,
			"head_t": 0.0, "tail_t": _rng.randf_range(1.0, 4.0), "yaw": body.rotation.y, "fly": {}, "next_peck": false})


func count() -> int:
	return birds.size()


func _high_perches() -> Array[int]:
	var out: Array[int] = []
	for i: int in perches.size():
		if perches[i]["high"]:
			out.append(i)
	return out


func tick(delta: float, player: Vector3, moving: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if singer >= 0 and singer < birds.size() and now >= float(birds[singer]["song_end"]):
		_end_phrase(birds[singer])
	for i: int in birds.size():
		var b: Dictionary = birds[i]
		var body: BirdBody = b["body"]
		var dist: float = body.global_position.distance_to(player + Vector3(0, 1.0, 0))
		var running: bool = moving > RUN_SPEED
		# You: too close, or running near.
		if int(b["state"]) != FLY and (dist < def.startle_radius or (running and dist < HUSH_RADIUS)):
			_flush(i, player)
		if dist < def.startle_radius * 1.6 or (running and dist < HUSH_RADIUS * 1.25):
			b["wary"] = CALM_S
		else:
			b["wary"] = maxf(0.0, float(b["wary"]) - delta)
		match int(b["state"]):
			FLY:
				_fly(b, delta)
			PECK:
				_peck(b, delta, now)
			_:
				_perched(i, b, delta, now, player, dist)
		_tail(b, delta)


## Perched: sing, look about, hop, move on.
func _perched(i: int, b: Dictionary, delta: float, now: float, player: Vector3, dist: float) -> void:
	var body: BirdBody = b["body"]
	var singing: bool = singer == i
	# The song: a bout of phrases from a high perch, while all is calm.
	if singing:
		_sing_pose(b, now)
	else:
		_rest_pose(b, delta)
		if int(b["bout"]) > 0:
			b["gap"] = float(b["gap"]) - delta
			if float(b["gap"]) <= 0.0 and singer < 0 and float(b["wary"]) <= 0.0:
				_phrase(i, b, now)
				return
		elif float(b["wary"]) <= 0.0 and bool(perches[int(b["perch"])]["high"]):
			b["rest"] = float(b["rest"]) - delta
			if float(b["rest"]) <= 0.0:
				b["bout"] = _rng.randi_range(6, 16)
				b["gap"] = _rng.randf_range(0.2, 1.5)
	# Looking: quick turns of the head, toward you when you are near.
	b["head_t"] = float(b["head_t"]) - delta
	if float(b["head_t"]) <= 0.0 and not singing:
		b["head_t"] = _rng.randf_range(0.35, 1.4)
		var turn: float = _rng.randf_range(-1.1, 1.1)
		if dist < LOOK_RADIUS:
			var to: Vector3 = player - body.global_position
			var want: float = atan2(-to.x, -to.z)
			turn = clampf(wrapf(want - body.rotation.y, -PI, PI), -1.3, 1.3)
			if absf(wrapf(want - body.rotation.y, -PI, PI)) > 1.3 and _rng.randf() < 0.4:
				b["yaw"] = want     # turns its whole body round to you, now and then
		body.head.rotation.y = turn
		body.head.rotation.x = _rng.randf_range(-0.15, 0.25)
	body.rotation.y = lerp_angle(body.rotation.y, float(b["yaw"]), minf(1.0, delta * 14.0))
	# Between bouts: hop, fly to another perch, or go down to the flowers.
	if int(b["bout"]) > 0 or singing:
		return
	b["timer"] = float(b["timer"]) - delta
	if float(b["timer"]) > 0.0:
		return
	b["timer"] = _rng.randf_range(2.0, 7.0)
	var roll: float = _rng.randf()
	if roll < 0.4:
		_hop(b)
	elif roll < 0.65:
		_move_to(b, _pick(b, true, 2.0, 12.0, player), false)
	elif roll < 0.85 and float(b["wary"]) <= 0.0:
		var flower: int = _pick_flower(b, player)
		if flower >= 0:
			b["next_peck"] = true
			_move_to(b, flower, false)


## Starts a phrase of song.
func _phrase(i: int, b: Dictionary, now: float) -> void:
	if _songs.is_empty():
		b["bout"] = 0
		return
	var k: int = _rng.randi() % _songs.size()
	if k == _last_song:
		k = (k + 1) % _songs.size()
	_last_song = k
	var stream: AudioStream = _songs[k]
	var body: BirdBody = b["body"]
	b["voice"] = SoundSystem.it().play_at(stream, body.head.global_position, SONG_REACH, SONG_DB, _rng.randf_range(0.97, 1.03)) if SoundSystem.it() != null else null
	b["song_end"] = now + stream.get_length()
	b["bout"] = int(b["bout"]) - 1
	singer = i


func _end_phrase(b: Dictionary) -> void:
	singer = -1
	b["voice"] = null
	b["gap"] = _rng.randf_range(1.2, 3.8)
	if int(b["bout"]) <= 0:
		b["rest"] = _rng.randf_range(15.0, 45.0)
		b["timer"] = _rng.randf_range(0.5, 3.0)
	# The other bird answers sooner.
	for o: Dictionary in birds:
		if o != b and int(o["bout"]) > 0:
			o["gap"] = minf(float(o["gap"]), _rng.randf_range(0.4, 1.2))


## Singing: head up, beak working in quick flutters, throat swelling.
func _sing_pose(b: Dictionary, now: float) -> void:
	var body: BirdBody = b["body"]
	var t: float = now * 18.0
	body.head.rotation.x = 0.6 + 0.06 * sin(now * 3.0)
	body.head.rotation.y = 0.0
	body.jaw.rotation.x = -(0.4 + 0.25 * absf(sin(t) * sin(t * 0.37)))     # (negative: the lower beak drops)
	body.throat.scale = Vector3.ONE * (1.3 + 0.15 * absf(sin(t * 0.5)))
	body.tail.rotation.x = 0.2


func _rest_pose(b: Dictionary, delta: float) -> void:
	var body: BirdBody = b["body"]
	body.jaw.rotation.x = lerpf(body.jaw.rotation.x, 0.0, minf(1.0, delta * 20.0))
	body.throat.scale = body.throat.scale.lerp(Vector3.ONE, minf(1.0, delta * 10.0))
	body.pose_wings(0.0, 0.0)


## The tail: cocked up now and then, settling back.
func _tail(b: Dictionary, delta: float) -> void:
	var body: BirdBody = b["body"]
	if int(b["state"]) == FLY:
		return
	b["tail_t"] = float(b["tail_t"]) - delta
	if float(b["tail_t"]) <= 0.0:
		b["tail_t"] = _rng.randf_range(1.5, 6.0)
		body.tail.rotation.x = -0.7
	elif singer < 0 or birds[singer] != b:
		body.tail.rotation.x = lerpf(body.tail.rotation.x, -0.12, minf(1.0, delta * 3.0))


## You came too close: hush, alarm, and up and away.
func _flush(i: int, player: Vector3) -> void:
	var b: Dictionary = birds[i]
	if singer == i:
		var v: AudioStreamPlayer3D = b["voice"]
		if v != null and is_instance_valid(v) and v.playing:
			v.stop()
		_end_phrase(b)
		b["bout"] = 0
		b["rest"] = _rng.randf_range(10.0, 25.0)
	var body: BirdBody = b["body"]
	var sound: SoundSystem = SoundSystem.it()
	if sound != null:
		if not _wings.is_empty():
			sound.play_at(_wings[_rng.randi() % _wings.size()], body.global_position, 12.0, -6.0)
		if not _calls.is_empty() and _rng.randf() < 0.6:
			sound.play_at(_calls[_rng.randi() % _calls.size()], body.global_position, 22.0, -4.0)
	b["next_peck"] = false
	_move_to(b, _escape(b, player), true)


## The perch to flee to: higher than this one if it can, away from you.
func _escape(b: Dictionary, player: Vector3) -> int:
	var here: Vector3 = (b["body"] as BirdBody).global_position
	var best: int = int(b["perch"])
	var best_score: float = -INF
	for i: int in perches.size():
		var at: Vector3 = perches[i]["at"]
		var away: float = at.distance_to(player)
		if away < def.startle_radius * 1.8 or at.distance_to(here) > 16.0:
			continue
		var score: float = (at.y - here.y) * 1.5 + minf(away, 12.0) * 0.6 + (2.0 if perches[i]["high"] else 0.0) + _rng.randf() * 0.5
		if score > best_score and _clear(here, at):
			best_score = score
			best = i
	return best


## A perch `lo` to `hi` m away (`high`: only high ones), in clear flight.
func _pick(b: Dictionary, high: bool, lo: float, hi: float, player: Vector3) -> int:
	var here: Vector3 = (b["body"] as BirdBody).global_position
	for tries: int in 12:
		var i: int = _rng.randi() % perches.size()
		var at: Vector3 = perches[i]["at"]
		var d: float = at.distance_to(here)
		if (high and not perches[i]["high"]) or d < lo or d > hi or at.distance_to(player) < def.startle_radius * 1.8:
			continue
		if _taken(i, b) or not _clear(here, at):
			continue
		return i
	return int(b["perch"])


func _pick_flower(b: Dictionary, player: Vector3) -> int:
	var here: Vector3 = (b["body"] as BirdBody).global_position
	for tries: int in 12:
		var i: int = _rng.randi() % perches.size()
		if not perches[i]["flower"]:
			continue
		var at: Vector3 = perches[i]["at"]
		if at.distance_to(here) > 12.0 or at.distance_to(player) < LOOK_RADIUS or _taken(i, b) or not _clear(here, at):
			continue
		return i
	return -1


func _taken(i: int, me: Dictionary) -> bool:
	for o: Dictionary in birds:
		if o != me and int(o["perch"]) == i:
			return true
	return false


## Nothing solid between two points (with a little air over each).
func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = LaneGraph.WORLD
	q.from = a + Vector3(0, 0.1, 0)
	q.to = b + Vector3(0, 0.1, 0)
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(b) < 0.3


## A short hop along the same plant.
func _hop(b: Dictionary) -> void:
	var here: Vector3 = (b["body"] as BirdBody).global_position
	for tries: int in 8:
		var i: int = _rng.randi() % perches.size()
		var d: float = (perches[i]["at"] as Vector3).distance_to(here)
		if d > 0.2 and d < 1.2 and not _taken(i, b) and perches[i]["high"] == perches[int(b["perch"])]["high"]:
			_move_to(b, i, false, 0.12)
			return


## Takes off for perch `to` on an arc (`lift`: how high the arc rises, m;
## -1: by the length of the flight).
func _move_to(b: Dictionary, to: int, fast: bool, lift: float = -1.0) -> void:
	if to == int(b["perch"]) and not fast:
		return
	var body: BirdBody = b["body"]
	var from: Vector3 = body.global_position
	var end: Vector3 = perches[to]["at"]
	var d: float = from.distance_to(end)
	var up: float = lift if lift >= 0.0 else 0.25 + d * 0.18
	var dur: float = clampf(d / (FLY_SPEED * (1.4 if fast else 1.0)), 0.22, 3.5)
	b["fly"] = {"a": from, "b": end, "c1": from.lerp(end, 0.3) + Vector3(0, up + (0.4 if fast else 0.0), 0), "c2": from.lerp(end, 0.75) + Vector3(0, up * 0.7, 0),
		"t": 0.0, "dur": dur, "hop": lift >= 0.0}
	b["perch"] = to
	b["state"] = FLY


func _fly(b: Dictionary, delta: float) -> void:
	var body: BirdBody = b["body"]
	var f: Dictionary = b["fly"]
	f["t"] = float(f["t"]) + delta / float(f["dur"])
	var u: float = minf(float(f["t"]), 1.0)
	var p: Vector3 = _bezier(f, u)
	var ahead: Vector3 = _bezier(f, minf(u + 0.05, 1.0)) - p
	body.global_position = p
	if Vector2(ahead.x, ahead.z).length() > 0.001:
		body.rotation.y = atan2(-ahead.x, -ahead.z)
	if bool(f["hop"]):
		body.pose_wings(0.35, sin(u * PI))
	else:
		# Fast beats, then wings held out to brake as it lands.
		var beat: float = sin(float(f["t"]) * float(f["dur"]) * TAU * 14.0)
		body.pose_wings(1.0, beat if u < 0.85 else 0.6)
		body.rotation.x = clampf(-ahead.y * 6.0, -0.5, 0.5)
		body.tail.rotation.x = 0.1 if u < 0.85 else -0.5     # fanned up to land
	if u >= 1.0:
		body.rotation.x = 0.0
		body.pose_wings(0.0, 0.0)
		b["yaw"] = body.rotation.y
		if bool(b["next_peck"]):
			b["next_peck"] = false
			b["state"] = PECK
			b["timer"] = _rng.randf_range(3.0, 7.0)
		else:
			b["state"] = PERCH
			b["timer"] = _rng.randf_range(1.5, 5.0)


static func _bezier(f: Dictionary, u: float) -> Vector3:
	var a: Vector3 = f["a"]
	var b: Vector3 = f["b"]
	var c1: Vector3 = f["c1"]
	var c2: Vector3 = f["c2"]
	var v: float = 1.0 - u
	return a * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + b * u * u * u


## At the flowers: dipping its head in, looking up, then back up to a branch.
func _peck(b: Dictionary, delta: float, now: float) -> void:
	var body: BirdBody = b["body"]
	body.head.rotation.x = -0.7 if fmod(now * 1.3 + float(b["perch"]), 1.0) < 0.55 else 0.1
	b["timer"] = float(b["timer"]) - delta
	if float(b["timer"]) <= 0.0:
		b["state"] = PERCH
		_move_to(b, _pick(b, true, 1.0, 12.0, Vector3(0, -1000, 0)), false)
