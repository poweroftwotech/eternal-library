class_name Resident
extends Node3D
## One resident (phase 21 step 2): a body and a small mind that keeps a
## timetable (Q4). The timetable is blocks of the day in bells, each naming
## what to do; the mind finds a spot for it (SpotTable), walks there along
## the home's clear way, and takes the spot's pose. It knows nothing of you.
##
## Step 2 keeps a household inside its own home and at its door: there is no
## way-finding yet (step 3), so a walk is straight lines along the home's
## spine (the way in from the lane to the back room) and then to the spot.

## What a block's activity shows as on the label.
const SAYS: Dictionary = {"wake": "getting up", "cook": "cooking", "eat": "eating", "door": "at the door", "sleep": "asleep",
		"sit": "sitting", "stand": "standing about", "work": "working"}
## What an activity needs: the kinds of spot that will do, best first.
const WANTS: Dictionary = {"sleep": ["sleep"], "cook": ["cook", "stand"], "eat": ["eat", "sit", "stand"], "door": ["door"], "wake": ["stand"],
		"sit": ["sit", "eat", "stand"], "stand": ["stand"], "work": ["work", "sit", "stand"]}
## What free time picks among.
const FREE: PackedStringArray = ["door", "sit", "stand", "sit"]
## Free time is picked again this often (bells).
const FREE_EVERY: float = 0.3
const WALK_SPEED: float = 1.1
const TURN_RATE: float = 6.0
## Above this clock speed a walk is skipped: they are simply there.
const SKIP_WALKS: float = 20.0
## Two people at one spot (the door) stand this far apart.
const BESIDE: float = 0.75

var body: ResidentBody
var given_name: String = ""
var trade: String = ""
## [[bell, activity], ...] in order; before the first, the last holds.
var blocks: Array = []
## This person's own lateness (bells): a lane doesn't move in step.
var shift: float = 0.0
var seed_value: int = 0
## The household's home: {spots, spine} from SpotTable.scan_home.
var home: Dictionary = {}
## Their own bed (a sleep spot), if the home has one for them.
var bed: Dictionary = {}

## The timetable's activity now, and what they are doing about it.
var block: String = ""
var doing: String = ""
var spot: Dictionary = {}
var walking: bool = false
## Seconds (of the day) spent walking toward the present spot: a stuck check.
var walked_s: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _free_slot: int = -1
var _label: Label3D


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


func tick(delta: float, clock: DayClock) -> void:
	var bells: float = clock.bells()
	var now: String = block_at(bells)
	var want: String = now
	if now == "free":
		# Free time: one of FREE, picked again every FREE_EVERY bells.
		var slot: int = int((clock.time / DayClock.BELL_S - shift) / FREE_EVERY)
		if slot != _free_slot or block != "free":
			_free_slot = slot
			doing = FREE[posmod(hash([seed_value, slot]), FREE.size())]
			_go(doing)
		want = doing
	elif now != block:
		doing = now
		_go(now)
	block = now
	if walking:
		_walk(delta * clock.speed, clock.speed)
	_label.text = "%s, %s\n%s" % [given_name, trade, describe(bells)]


func show_label(on: bool) -> void:
	_label.visible = on


## "cooking; then eating at Second bell".
func describe(bells: float) -> String:
	var nxt: Array = next_block(bells)
	var what: String = str(SAYS.get(doing, doing))
	if walking:
		what = "going to " + {"sleep": "bed", "cook": "the hearth", "eat": "eat", "door": "the door", "wake": "get up"}.get(doing, what)
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
			for s: Dictionary in home["spots"]:
				if s["kind"] != kind or (s["trade"] != "" and s["trade"] != trade):
					continue
				# A door or the floor takes several; anything else, one.
				if s["by"] != null and s["by"] != self and not kind in ["door", "stand"]:
					continue
				if kind == "sleep" and s != bed and _is_a_bed_of_another(s):
					continue
				found = s
				break
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
	# The way: along the home's spine from where we are to where the spot is.
	var spine: PackedVector3Array = home["spine"]
	var a: int = _nearest_on(spine, global_position)
	var b: int = _nearest_on(spine, spot["at"])
	_path = PackedVector3Array()
	var step: int = 1 if b >= a else -1
	var i: int = a
	while true:
		_path.append(spine[i])
		if i == b:
			break
		i += step
	var end: Vector3 = spot["at"]
	if shared:
		end += Basis(Vector3.UP, float(spot["yaw"])).x * BESIDE
	_path.append(end)
	walking = true
	walked_s = 0.0
	body.play("walk", 0.3, 0.0, WALK_SPEED / body.walk_speed())


## Ends a walk at once: they are at their spot (a room just built, the hour
## jumped).
func arrive_now() -> void:
	if walking and not _path.is_empty():
		global_position = _path[_path.size() - 1]
		_path = PackedVector3Array()
		_arrive()


func _is_a_bed_of_another(s: Dictionary) -> bool:
	for other: Node in get_parent().get_children():
		var r := other as Resident
		if r != null and r != self and r.bed == s:
			return true
	return false


func _walk(delta: float, speed: float) -> void:
	walked_s += delta
	if speed > SKIP_WALKS:
		_path = PackedVector3Array([_path[_path.size() - 1]])
		global_position = _path[0]
	var left: float = WALK_SPEED * delta
	while left > 0.0 and not _path.is_empty():
		var last: bool = _path.size() == 1
		var to: Vector3 = _path[0] - global_position
		# Along the floor until the last step, which may climb onto a seat or a bed.
		if not last:
			to.y = 0.0
		var d: float = to.length()
		if d <= left:
			global_position = _path[0] if last else Vector3(_path[0].x, global_position.y, _path[0].z)
			_path.remove_at(0)
			left -= d
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, TURN_RATE * delta / maxf(speed, 1.0) * speed))
		global_position += to / d * left
		left = 0.0
	if _path.is_empty():
		_arrive()


func _arrive() -> void:
	walking = false
	rotation.y = float(spot["yaw"])
	var pose: String = str(spot["pose"])
	if pose == "":
		pose = body.floor_sit()
	elif pose == "sit_bench":
		global_position.y = (spot["at"] as Vector3).y - 0.42 * float(ResidentBody.SIZES[body.kind])
	if doing == "wake":
		pose = "idle"
	body.play(pose, 0.35, randf() * 3.0)


static func _nearest_on(spine: PackedVector3Array, at: Vector3) -> int:
	var best: int = 0
	var best_d: float = INF
	for i: int in spine.size():
		var d: float = Vector2(spine[i].x - at.x, spine[i].z - at.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best
