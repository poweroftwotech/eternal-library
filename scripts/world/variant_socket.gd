@tool
class_name VariantSocket
extends Node3D
## A variation point (ENVIRONMENT_PLAN.md 4.3). Instances candidates from its
## SocketSet as internal children, which are never saved into the scene; the
## pick comes from a seed, so the same seed always rebuilds the same room.
##
## Modes:
##   REPLACE  one candidate scene (recess fill, iwan centrepiece)
##   TOGGLE   like REPLACE, but present only with toggle_chance
##   SCATTER  scatter_count items inside a box on the socket's floor plane
##            (books and pots on a table); a pin makes every item that entry
##   STATE    no scene: the entry's label is a state applied to the socket's
##            parent (LampState: lit, failing, dark)
##
## Inside a RoomTemplate the room resolves its sockets (seed = room seed + this
## socket's path). Opened on its own, a socket previews with seed 0.

enum Mode { REPLACE, TOGGLE, SCATTER, STATE }

@export var socket_set: SocketSet:
	set(value):
		socket_set = value
		_editor_refresh()
@export var mode: Mode = Mode.REPLACE:
	set(value):
		mode = value
		_editor_refresh()
## TOGGLE mode: chance that the picked candidate appears at all.
@export_range(0.0, 1.0, 0.01) var toggle_chance: float = 0.5
## Force one entry (index into the set); -1 lets the seed choose.
@export var pinned: int = -1:
	set(value):
		pinned = value
		_editor_refresh()
@export_tool_button("Next candidate") var next_action: Callable = _pin_next
@export_group("Scatter")
## SCATTER: how many items, inclusive range.
@export var scatter_count: Vector2i = Vector2i(2, 5)
## SCATTER: half size of the area along local X and Z (items sit at y = 0).
@export var scatter_extent: Vector2 = Vector2(0.5, 0.5)
## SCATTER: minimum distance between item origins.
@export var scatter_spacing: float = 0.3

var last_pick: int = -1
## SCATTER: number of items placed.
var last_count: int = 0
var _seed: int = 0
## Pin set by the owning room (RoomTemplate.socket_pins); wins over `pinned`.
var room_pin: int = -1
var _children: Array[Node] = []


func _ready() -> void:
	if room() == null:
		resolve(0)


## The RoomTemplate this socket belongs to, if any.
func room() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p is RoomTemplate:
			return p
		p = p.get_parent()
	return null


func resolve(seed_value: int, room_pin_value: int = -1) -> int:
	_seed = seed_value
	room_pin = room_pin_value
	clear()
	last_count = 0
	if socket_set == null or socket_set.entries.is_empty():
		last_pick = -1
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var force: int = effective_pin()
	var idx: int = force if force >= 0 else socket_set.pick(rng)
	match mode:
		Mode.TOGGLE:
			if rng.randf() > toggle_chance:
				idx = -1
			_spawn(idx, Transform3D.IDENTITY, rng)
		Mode.SCATTER:
			_scatter(force, rng)
		Mode.STATE:
			var flicker: LampState = LampState.apply(get_parent(), socket_set.entries[idx].label if idx >= 0 else "lit")
			if flicker != null:
				add_child(flicker, false, Node.INTERNAL_MODE_BACK)
				_children.append(flicker)
		_:
			_spawn(idx, Transform3D.IDENTITY, rng)
	last_pick = idx
	return idx


func clear() -> void:
	for c: Node in _children:
		if is_instance_valid(c):
			remove_child(c)
			c.queue_free()
	_children.clear()


func picked_label() -> String:
	if mode == Mode.SCATTER:
		var pin: int = effective_pin()
		return "%d × %s" % [last_count, entry_label(pin)] if pin >= 0 else "%d items" % last_count
	return entry_label(last_pick)


func _spawn(idx: int, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	if idx < 0 or socket_set.entries[idx] == null or socket_set.entries[idx].scene == null:
		return
	var node: Node = socket_set.entries[idx].scene.instantiate()
	node.set_meta("seed", rng.randi())
	if node is Node3D:
		(node as Node3D).transform = xf
	add_child(node, false, Node.INTERNAL_MODE_BACK)
	_children.append(node)


## Rejection-sampled positions, so items keep scatter_spacing apart.
func _scatter(force: int, rng: RandomNumberGenerator) -> void:
	var want: int = rng.randi_range(scatter_count.x, maxi(scatter_count.x, scatter_count.y))
	var spots: Array[Vector3] = []
	for _try: int in want * 12:
		if spots.size() >= want:
			break
		var p := Vector3(rng.randf_range(-scatter_extent.x, scatter_extent.x), 0.0,
			rng.randf_range(-scatter_extent.y, scatter_extent.y))
		var clear_spot: bool = true
		for q: Vector3 in spots:
			if p.distance_to(q) < scatter_spacing:
				clear_spot = false
				break
		if not clear_spot:
			continue
		spots.append(p)
		var idx: int = force if force >= 0 else socket_set.pick(rng)
		_spawn(idx, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), rng)
	last_count = spots.size()


func _pin_next() -> void:
	if socket_set == null or socket_set.entries.is_empty():
		return
	pinned = (maxi(pinned, last_pick) + 1) % socket_set.entries.size()


func _editor_refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		resolve(_seed, room_pin)


## The entry this socket is forced to (room pin first, then its own), or -1.
func effective_pin() -> int:
	var n: int = socket_set.entries.size() if socket_set != null else 0
	if room_pin >= 0 and room_pin < n:
		return room_pin
	if pinned >= 0 and pinned < n:
		return pinned
	return -1


func candidate_count() -> int:
	return socket_set.entries.size() if socket_set != null else 0


func entry_label(idx: int) -> String:
	if socket_set == null or idx < 0 or idx >= socket_set.entries.size():
		return "(none)"
	var e: SocketEntry = socket_set.entries[idx]
	if e == null:
		return "(empty)"
	if e.label != "":
		return e.label
	return e.scene.resource_path.get_file().get_basename() if e.scene != null else "(no scene)"
