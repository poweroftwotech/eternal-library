class_name Resident
extends Node3D
## One resident (phase 21 steps 2-3): a body and a small mind that keeps a
## timetable (Q4). The timetable is blocks of the day in bells, each naming
## what to do; the mind finds a spot for it (SpotTable: its home's, then the
## lane's shared ones), walks there over the room's walking surface (WalkMap,
## Q5) and takes the spot's pose.
##
## It is solid (Q6): you can't walk through it. It walks round you and round
## other people where there is room; where there isn't (a doorway) it waits
## for you, and for another person a moment only. It knows nothing else of you.

## The collision layer of people's bodies (the player's mask has it).
const LAYER: int = 1 << 9
## What a block's activity shows as on the label.
const SAYS: Dictionary = {"wake": "getting up", "cook": "cooking", "eat": "eating", "door": "at the door", "sleep": "asleep",
		"sit": "sitting", "stand": "standing about", "work": "working", "water": "fetching water", "shop": "at the stall",
		"keep": "keeping the stall", "hauz": "sitting at the hauz"}
const GOING: Dictionary = {"sleep": "bed", "cook": "the hearth", "eat": "eat", "door": "the door", "wake": "get up", "water": "the hauz for water",
		"shop": "the stall", "keep": "the stall", "hauz": "the hauz", "work": "work", "sit": "sit down"}
## What an activity needs: the kinds of spot that will do, best first.
const WANTS: Dictionary = {"sleep": ["sleep"], "cook": ["cook", "stand"], "eat": ["eat", "sit", "stand"], "door": ["door"], "wake": ["stand"],
		"sit": ["sit", "eat", "stand"], "stand": ["stand"], "work": ["work", "sit", "stand"], "water": ["water", "door"], "shop": ["buy", "door"],
		"keep": ["keep", "door"], "hauz": ["bench", "door"]}
## Kinds of spot that take any number of people, side by side.
const SHARED: PackedStringArray = ["door", "stand"]
## What free time picks among.
const FREE: PackedStringArray = ["door", "sit", "hauz", "stand", "hauz"]
## Free time is picked again this often (bells).
const FREE_EVERY: float = 0.3
const WALK_SPEED: float = 1.1
const TURN_RATE: float = 6.0
## Above this clock speed a walk is skipped: they are simply there.
const SKIP_WALKS: float = 20.0
## Two people at one spot (the door) stand this far apart.
const BESIDE: float = 0.75
## A body's own half-width, for keeping clear of others.
const HALF: float = 0.28
## Blocked by another person this long (s), they go through: no lane jams for ever.
const PATIENCE: float = 2.5
## After stepping round something, the way is found again this often (s).
const REPATH_EVERY: float = 0.5
## The capsule you bump into.
const SOLID_RADIUS: float = 0.24
const SOLID_HEIGHT: float = 1.7

var body: ResidentBody
var given_name: String = ""
var trade: String = ""
## [[bell, activity], ...] in order; before the first, the last holds.
var blocks: Array = []
## This person's own lateness (bells): a lane doesn't move in step.
var shift: float = 0.0
var seed_value: int = 0
## The household's home: {spots, anchor (a point on its floor)} from SpotTable.scan_home.
var home: Dictionary = {}
## The shared spots of the lane (the hauz, the stall): Residents keeps them.
var commons: Array = []
## Their own bed (a sleep spot), if the home has one for them.
var bed: Dictionary = {}
var ways: WalkMap
## The height of the floor they walk on.
var floor_y: float = 0.0

## The timetable's activity now, and what they are doing about it.
var block: String = ""
var doing: String = ""
var spot: Dictionary = {}
var walking: bool = false
## Standing still mid-walk because someone is in the way: "" or who ("you", a name).
var waiting_for: String = ""
## Seconds (of the day) spent walking toward the present spot: a stuck check.
var walked_s: float = 0.0
## Metres walked in all (the tests).
var walked_m: float = 0.0
## The way still to walk (the overlay draws it).
var route: PackedVector3Array = PackedVector3Array()
var _end: Vector3
## The floor under them: where a way starts from (they may be up on a bed).
var _foot: Vector3
var _free_slot: int = -1
var _label: Label3D
var _solid: CollisionShape3D
var _stalled_s: float = 0.0
var _through_s: float = 0.0
var _repath_s: float = 0.0
var _strayed: bool = false


func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.pixel_size = 0.0035
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.93, 0.75)
	_label.position = Vector3(0, 2.05, 0)
	_label.visible = false
	add_child(_label)
	var solid := AnimatableBody3D.new()
	solid.name = "Solid"
	solid.sync_to_physics = false
	solid.collision_layer = LAYER
	solid.collision_mask = 0
	_solid = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = SOLID_RADIUS
	capsule.height = SOLID_HEIGHT
	_solid.shape = capsule
	_solid.position = Vector3(0, SOLID_HEIGHT * 0.5, 0)
	solid.add_child(_solid)
	add_child(solid)


## Puts them on the floor at `at` with nothing in hand (a new household).
func stand_at(at: Vector3) -> void:
	global_position = at
	_foot = at
	floor_y = at.y


## The activity the timetable gives at `bells` (0..6).
func block_at(bells: float) -> String:
	var b: float = fposmod(bells - shift, float(DayClock.BELLS))
	var out: String = str(blocks[blocks.size() - 1][1])
	for row: Array in blocks:
		if float(row[0]) <= b:
			out = str(row[1])
	return out


## What comes next and when: [activity, bell (0..6, the clock's)].
func next_block(bells: float) -> Array:
	var b: float = fposmod(bells - shift, float(DayClock.BELLS))
	for row: Array in blocks:
		if float(row[0]) > b:
			return [str(row[1]), fposmod(float(row[0]) + shift, float(DayClock.BELLS))]
	return [str(blocks[0][1]), fposmod(float(blocks[0][0]) + shift, float(DayClock.BELLS))]


## One step of their day. `others`: what is in the way just now, each
## {at: Vector3, r: float, who: Resident or null (null is you)}.
func tick(delta: float, clock: DayClock, others: Array = []) -> void:
	var bells: float = clock.bells()
	var now: String = block_at(bells)
	if now == "free":
		# Free time: one of FREE, picked again every FREE_EVERY bells.
		var slot: int = int((clock.time / DayClock.BELL_S - shift) / FREE_EVERY)
		if slot != _free_slot or block != "free":
			_free_slot = slot
			doing = FREE[posmod(hash([seed_value, slot]), FREE.size())]
			_go(doing)
	elif now != block:
		doing = now
		_go(now)
	block = now
	if walking:
		_walk(delta * clock.speed, clock.speed, others)
	_label.text = "%s, %s\n%s" % [given_name, trade, describe(bells)]


func show_label(on: bool) -> void:
	_label.visible = on


## "cooking; then eating at Second bell".
func describe(bells: float) -> String:
	var nxt: Array = next_block(bells)
	var what: String = str(SAYS.get(doing, doing))
	if walking:
		what = "going to " + str(GOING.get(doing, what))
		if waiting_for != "":
			what += " (waiting for %s)" % waiting_for
	var then: String = str(SAYS.get(nxt[0], nxt[0])) if nxt[0] != "free" else "free time"
	return "%s\nthen %s at %s" % [what, then, bell_text(float(nxt[1]))]


static func bell_text(bells: float) -> String:
	var i: int = clampi(int(bells), 0, DayClock.BELLS - 1)
	var part: float = bells - i
	return DayClock.NAMES[i] if part < 0.04 else "%s + %d min" % [DayClock.NAMES[i], int(round(part * DayClock.BELL_S / 60.0))]


# Finds a spot for `activity`, lets go of the old one, and sets off.
func _go(activity: String) -> void:
	var found: Dictionary = {}
	if activity == "sleep" and not bed.is_empty():
		found = bed
	else:
		for kind: String in WANTS.get(activity, ["stand"]):
			found = _free_spot(kind)
			if not found.is_empty():
				break
	if found.is_empty() or found == spot:
		return
	if not spot.is_empty() and spot["by"] == self:
		spot["by"] = null
	var shared: bool = found["by"] != null and found["by"] != self
	spot = found
	if not shared:
		spot["by"] = self
	_end = spot["at"]
	if shared:
		_end += Basis(Vector3.UP, float(spot["yaw"])).x * BESIDE
	_find_way()
	walking = true
	walked_s = 0.0
	waiting_for = ""
	_stalled_s = 0.0
	_through_s = 0.0
	_strayed = false
	_solid.disabled = false
	body.play("walk", 0.3, 0.0, WALK_SPEED / body.walk_speed())


# A spot of `kind` nobody else has: the home's first, then the lane's (the
# nearest of those).
func _free_spot(kind: String) -> Dictionary:
	for s: Dictionary in home["spots"]:
		if _will_do(s, kind):
			return s
	var best: Dictionary = {}
	var best_d: float = INF
	for s: Dictionary in commons:
		if not _will_do(s, kind):
			continue
		# (Hashed in so that two people don't always make for the same one.)
		var d: float = _foot.distance_to(s["at"]) + float(posmod(hash([seed_value, s["at"]]), 100)) * 0.01
		if d < best_d:
			best_d = d
			best = s
	return best


func _will_do(s: Dictionary, kind: String) -> bool:
	if s["kind"] != kind or (s["trade"] != "" and s["trade"] != trade):
		return false
	if s["by"] != null and s["by"] != self and not SHARED.has(kind):
		return false
	if kind == "sleep" and s != bed and _is_a_bed_of_another(s):
		return false
	return true


# The way to the present spot: down to the floor if they are up on something,
# over the walking surface to the floor beside the spot, then onto it.
func _find_way() -> void:
	route = PackedVector3Array()
	if global_position.distance_to(_foot) > 0.05:
		route.append(_foot)
	if ways != null:
		if not spot.has("foot"):
			var foot: Vector3 = ways.approach(spot["at"], home["anchor"])
			spot["foot"] = Vector3(foot.x, floor_y, foot.z)
		var over: PackedVector3Array = ways.path(_foot, spot["foot"])
		if over.size() > 1:
			over.remove_at(0)
		# (The surface lies a little over the floor it was made from.)
		for i: int in over.size():
			over[i].y = floor_y
		route.append_array(over)
	route.append(_end)
	# Points one on top of another give nothing to walk.
	var k: int = route.size() - 2
	while k >= 0:
		if route[k].distance_to(route[k + 1]) < 0.02:
			route.remove_at(k)
		k -= 1


## Ends a walk at once: they are at their spot (a room just built, the hour
## jumped).
func arrive_now() -> void:
	if walking and not route.is_empty():
		if route.size() > 1:
			_foot = route[route.size() - 2]
		global_position = route[route.size() - 1]
		route = PackedVector3Array()
		_arrive()


func _is_a_bed_of_another(s: Dictionary) -> bool:
	for other: Node in get_parent().get_children():
		var r := other as Resident
		if r != null and r != self and r.bed == s:
			return true
	return false


func _walk(delta: float, speed: float, others: Array) -> void:
	walked_s += delta
	if speed > SKIP_WALKS:
		arrive_now()
		return
	_through_s = maxf(0.0, _through_s - delta)
	_repath_s = maxf(0.0, _repath_s - delta)
	if _strayed and _repath_s <= 0.0 and route.size() > 1:
		# Off the line after stepping round someone: find the way from here.
		_foot = global_position
		_find_way()
		_strayed = false
		_repath_s = REPATH_EVERY
	var left: float = WALK_SPEED * delta
	while left > 0.0 and not route.is_empty():
		var last: bool = route.size() == 1
		var to: Vector3 = route[0] - global_position
		# Along the floor until the last step, which may climb onto a seat or a bed.
		if not last:
			to.y = 0.0
		var d: float = to.length()
		if d < 0.001:
			route.remove_at(0)
			continue
		var step: float = minf(d, left)
		var dir: Vector3 = to / d
		var next: Vector3 = global_position + dir * step
		var block_by: Dictionary = _in_the_way(next, dir, others, last)
		if not block_by.is_empty():
			var round_it: Vector3 = _step_round(dir, step, block_by, others) if not last else Vector3.INF
			if round_it == Vector3.INF:
				_stall(delta, block_by)
				return
			next = round_it
			dir = (next - global_position).normalized()
			_strayed = true
		_unstall()
		if not last:
			# Down off a bed or a seat to the floor (the lane's floors are level).
			next.y = move_toward(global_position.y, floor_y, step)
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, TURN_RATE * delta))
		global_position = next
		walked_m += step
		left -= step
		if not last:
			_foot = global_position
		if step >= d - 0.0005 and not _strayed:
			route.remove_at(0)
		elif _strayed:
			# A corner we were stepping round to is as good as reached from near it.
			if route.size() > 1 and Vector2(route[0].x - next.x, route[0].z - next.z).length() < 0.45:
				route.remove_at(0)
			left = 0.0
	if route.is_empty():
		_arrive()


# Who is in the way of a step to `next`, heading `dir`: {} if nobody.
func _in_the_way(next: Vector3, dir: Vector3, others: Array, last: bool) -> Dictionary:
	for o: Dictionary in others:
		if o["who"] == self:
			continue
		# The last step is onto the spot itself: only you can be standing on it.
		if o["who"] != null and (last or _through_s > 0.0):
			continue
		var d := Vector3((o["at"] as Vector3).x - next.x, 0.0, (o["at"] as Vector3).z - next.z)
		if absf((o["at"] as Vector3).y - next.y) > 1.6:
			continue
		if d.length() < float(o["r"]) + HALF and d.dot(dir) > 0.0:
			return o
	return {}


# A step that goes round `o` instead: to the side away from it, if the floor
# is there and nobody else is. Vector3.INF if there is no such step.
func _step_round(dir: Vector3, step: float, o: Dictionary, others: Array) -> Vector3:
	var to_o := Vector3((o["at"] as Vector3).x - global_position.x, 0.0, (o["at"] as Vector3).z - global_position.z)
	var side := Vector3(dir.z, 0.0, -dir.x)
	# Away from it; dead ahead, each keeps to their own right.
	var turn: float = side.dot(to_o)
	if turn > 0.02:
		side = -side
	for lean: float in [0.25, -0.15]:
		var way: Vector3 = (dir * lean + side).normalized()
		var next: Vector3 = global_position + way * step
		if ways != null and not ways.on(next, 0.08):
			continue
		var clear: bool = true
		for p: Dictionary in others:
			if p["who"] == self:
				continue
			var d := Vector2((p["at"] as Vector3).x - next.x, (p["at"] as Vector3).z - next.z)
			var was := Vector2((p["at"] as Vector3).x - global_position.x, (p["at"] as Vector3).z - global_position.z)
			# (Never closer to anyone than we already are, inside their space.)
			if d.length() < float(p["r"]) + HALF and d.length() < was.length():
				clear = false
		if clear:
			return next
	return Vector3.INF


func _stall(delta: float, o: Dictionary) -> void:
	if waiting_for == "":
		body.play("idle", 0.3)
	waiting_for = "you" if o["who"] == null else (o["who"] as Resident).given_name
	_stalled_s += delta
	if o["who"] != null and _stalled_s > PATIENCE:
		# Two people who can't pass: one goes through. Not you: they wait.
		_through_s = 2.0
		_stalled_s = 0.0


func _unstall() -> void:
	if waiting_for != "":
		waiting_for = ""
		_stalled_s = 0.0
		body.play("walk", 0.3, 0.0, WALK_SPEED / body.walk_speed())


func _arrive() -> void:
	walking = false
	waiting_for = ""
	rotation.y = float(spot["yaw"])
	var pose: String = str(spot["pose"])
	if pose == "":
		pose = body.floor_sit()
	elif pose == "sit_bench":
		global_position.y = (spot["at"] as Vector3).y - 0.42 * float(ResidentBody.SIZES[body.kind])
	if doing == "wake":
		pose = "idle"
	# Lying down, there is nothing upright to bump into.
	_solid.disabled = pose == "sleep"
	body.play(pose, 0.35, randf() * 3.0)
