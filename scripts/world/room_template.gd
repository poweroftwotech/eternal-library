@tool
class_name RoomTemplate
extends Node3D
## Root of an authored room (ENVIRONMENT_PLAN.md 4.2). Resolves every
## VariantSocket in the room from one seed: in the editor from preview_seed
## (change it, or press Reroll, to see other variants), at runtime from the
## area seed once areas exist (phase 4), otherwise from preview_seed.
##
## socket_pins holds this room's own picks for sockets that live inside
## instanced modules, keyed by socket path relative to the room. It is saved
## with the room, so pinning never needs Editable Children; the Kit dock's
## Sockets panel edits it. A room pin wins over the socket's own `pinned`.

@export var room_id: String = ""
## Shown in the HUD and menus when the room is played on its own.
@export var display_name: String = ""
@export var preview_seed: int = 1:
	set(value):
		preview_seed = value
		if Engine.is_editor_hint() and is_inside_tree():
			resolve_sockets(preview_seed)
@export_tool_button("Reroll sockets") var reroll_action: Callable = _reroll
## {socket path relative to this room: entry index}. Edit from the Kit dock.
@export var socket_pins: Dictionary[String, int] = {}:
	set(value):
		socket_pins = value
		if Engine.is_editor_hint() and is_inside_tree():
			resolve_sockets(_last_seed)
## {style group: entry index} saved with the room: a baked generated room keeps
## the host build it inherited here (ENVIRONMENT_PLAN.md 5.5.10). Checked after
## style_overrides, before the room's own roll; socket pins still win.
@export var style_pins: Dictionary[String, int] = {}:
	set(value):
		style_pins = value
		if Engine.is_editor_hint() and is_inside_tree():
			resolve_sockets(_last_seed)
## Set by the area assembler before the room enters the tree; -1 = use preview_seed.
var area_seed: int = -1
## {style group: entry index} that win over this room's own roll (pins still win
## over both). A generated room joined to a host takes the host's build here
## (GeneratedRoom.inherit_style_groups, ENVIRONMENT_PLAN.md 5.5.5).
var style_overrides: Dictionary = {}
## {socket path: entry index} a generator sets (a collapsed bay pins its
## recesses, a far lamp goes dark: ENVIRONMENT_PLAN.md 5.5.6). Never saved;
## socket_pins win over it.
var generated_pins: Dictionary = {}
var _last_seed: int = 1


func _ready() -> void:
	resolve_sockets(preview_seed if Engine.is_editor_hint() or area_seed < 0 else area_seed)
	restore_world()


func sockets() -> Array[VariantSocket]:
	var out: Array[VariantSocket] = []
	_collect(self, out)
	return out


func socket_key(s: VariantSocket) -> String:
	return str(get_path_to(s))


## The seed the room's sockets resolve from: the area seed at runtime once
## areas exist, else preview_seed. GeneratedRoom uses its generation seed.
func current_seed() -> int:
	return area_seed if area_seed >= 0 and not Engine.is_editor_hint() else preview_seed


## Returns {socket path: picked index}.
func resolve_sockets(seed_value: int) -> Dictionary:
	_last_seed = seed_value
	var picks: Dictionary = {}
	var styles: Dictionary = style_picks(seed_value)
	var all: Array[VariantSocket] = sockets()
	# Sockets gated on a sibling's look (VariantSocket.needs_look) go after the looks.
	for s: VariantSocket in all.filter(func(v: VariantSocket) -> bool: return v.needs_look == "") + all.filter(func(v: VariantSocket) -> bool: return v.needs_look != ""):
		var key: String = socket_key(s)
		var group: String = s.socket_set.style_group if s.socket_set != null else ""
		picks[key] = s.resolve(socket_seed(seed_value, key), pin_for(key), styles.get(group, -1))
	apply_claims()
	return picks


## {style group: entry index}, rolled once per room from the seed with the
## weights of the first set found in that group (SocketSet.style_group).
func style_picks(seed_value: int) -> Dictionary:
	var out: Dictionary = {}
	for s: VariantSocket in sockets():
		if s.socket_set == null or s.socket_set.style_group == "" or out.has(s.socket_set.style_group):
			continue
		if style_overrides.has(s.socket_set.style_group):
			out[s.socket_set.style_group] = style_overrides[s.socket_set.style_group]
			continue
		if style_pins.has(s.socket_set.style_group):
			out[s.socket_set.style_group] = style_pins[s.socket_set.style_group]
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = socket_seed(seed_value, "style:" + s.socket_set.style_group)
		out[s.socket_set.style_group] = s.socket_set.pick(rng)
	return out


## The entry index most of this room's sockets in `group` show (pins first,
## then the group roll), or -1 if the room has none. A joined generated room
## inherits it, so it matches what the player sees here, pins included.
func style_choice(group: String, seed_value: int) -> int:
	var rolled: int = int(style_picks(seed_value).get(group, -1))
	var counts: Dictionary = {}
	for s: VariantSocket in sockets():
		if s.socket_set == null or s.socket_set.style_group != group:
			continue
		var idx: int = pin_for(socket_key(s), s.pinned)
		if idx < 0:
			idx = rolled
		counts[idx] = int(counts.get(idx, 0)) + 1
	var best: int = -1
	for idx: int in counts:
		if best < 0 or counts[idx] > counts[best]:
			best = idx
	return best


## Picks can claim space (CLAIM_ markers: the wall base behind a masonry
## stair). Clears every other socket's items whose origin is in a claim.
## Returns how many items were cleared.
func apply_claims() -> int:
	var all: Array[VariantSocket] = sockets()
	var boxes: Dictionary = {}     # socket -> its claims, room space
	for s: VariantSocket in all:
		var c: Array[AABB] = s.claims(self)
		if not c.is_empty():
			boxes[s] = c
	var cleared: int = 0
	for s: VariantSocket in all:
		var others: Array[AABB] = []
		for owner_socket: VariantSocket in boxes:
			if owner_socket != s:
				others.append_array(boxes[owner_socket])
		if not others.is_empty():
			cleared += s.release_claimed(self, others)
	return cleared


## The room's pin for a socket: socket_pins, then generated_pins, else `fallback`.
func pin_for(key: String, fallback: int = -1) -> int:
	return socket_pins.get(key, generated_pins.get(key, fallback))


func socket_seed(seed_value: int, key: String) -> int:
	var rid: String = room_id if room_id != "" else String(name)
	return hash([seed_value, rid, key])


## Pins whose socket no longer exists (module renamed, moved or deleted).
func stale_pins() -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in socket_pins:
		if not get_node_or_null(NodePath(key)) is VariantSocket:
			out.append(key)
	return out


func _collect(node: Node, out: Array[VariantSocket]) -> void:
	for child: Node in node.get_children():
		if child is RoomTemplate:
			continue      # a room placed inside this one owns its own sockets (5.5.1)
		if child is VariantSocket:
			out.append(child as VariantSocket)
		_collect(child, out)


func _reroll() -> void:
	preview_seed = randi() % 100000
	notify_property_list_changed()


# --- the save: props and their changes (ENVIRONMENT_PLAN.md 6.5.2-6.5.3) --------
# The room is always built as authored or generated; the save's deltas are laid
# over it here. Every delta keeps the thing's original transform (room frame)
# and scene, so revert_thing() can put it back while the room is live (a future
# janitor NPC or event: WorldState.revert / revert_room).

var _world_restored: bool = false


## This room's prefix for save ids: room_id@seed (6.5.2, Q1).
func room_key() -> String:
	return "%s@%d" % [room_id if room_id != "" else String(name), current_seed()]


## The WorldState autoload, or null (in the editor, or a tool run without it).
func world_state() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_node_or_null("/root/WorldState")


## WorldProps this room owns, including socket spawns (internal children), but
## not those of a room placed inside this one.
func world_props() -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	_collect_props(self, out)
	return out


## Live broken props (Shards) of this room.
func room_shards() -> Array[Shards]:
	var out: Array[Shards] = []
	for n: Node in find_children("*", "Shards", true, false):
		if str(n.get_meta("world_id", "")).begins_with(room_key() + "/"):
			out.append(n as Shards)
	return out


## A prop's path in its save id: its node path in the room, or for a socket
## spawn the socket's path plus its spawn number ("…/SOCKET_table_props#2").
func thing_path(node: Node) -> String:
	var parent: Node = node.get_parent()
	if parent is VariantSocket:
		return "%s#%d" % [socket_key(parent as VariantSocket), (parent as VariantSocket).spawned().find(node)]
	return str(get_path_to(node))


## Lays the save's deltas over the freshly built room and starts recording
## changes. Runs once, after the sockets resolve (a GeneratedRoom after it builds).
func restore_world() -> void:
	var ws: Node = world_state()
	if ws == null or _world_restored:
		return
	_world_restored = true
	ws.call("register_room", self)
	ws.connect("saving", _flush_moving)
	for p: WorldProp in world_props():
		var id: String = room_key() + "/" + thing_path(p)
		_track(p, id)
		var d: Dictionary = ws.call("delta", id)
		if d.is_empty():
			continue
		ws.call("note_applied", id)
		match str(d.get("s", "")):
			"moved":
				_restore_moved(p, d)
			"broken":
				_restore_broken(p, id, d)


## Puts one changed thing back as it was originally (WorldState.revert calls
## this; it also drops the delta). Returns whether it found the thing.
func revert_thing(id: String) -> bool:
	for p: WorldProp in world_props():
		if p.get_meta("world_id", "") == id:
			p.refreeze()
			p.transform = p.rest_transform
			p.remove_meta("restored")
			return true
	for s: Shards in room_shards():
		if s.get_meta("world_id", "") != id:
			continue
		var p: WorldProp = (load(str(s.get_meta("prop_scene"))) as PackedScene).instantiate() as WorldProp
		p.name = str(s.get_meta("prop_name"))
		var parent: Node = get_node_or_null(s.get_meta("prop_parent") as NodePath)
		if parent == null:
			p.free()
			return false
		var ordinal: int = int(s.get_meta("socket_ordinal", -1))
		if parent is VariantSocket and ordinal >= 0:
			(parent as VariantSocket).respawn(ordinal, p)
		else:
			parent.add_child(p)
		p.global_transform = global_transform * (s.get_meta("prop_rest") as Transform3D)
		p.rest_transform = p.transform
		_track(p, id)
		s.queue_free()
		return true
	return false


func _collect_props(node: Node, out: Array[WorldProp]) -> void:
	for child: Node in node.get_children(true):
		if child is RoomTemplate:
			continue
		if child is WorldProp:
			out.append(child as WorldProp)
		_collect_props(child, out)


func _track(p: WorldProp, id: String) -> void:
	p.set_meta("world_id", id)
	p.settled.connect(_on_prop_settled.bind(p))
	p.broke.connect(_on_prop_broke.bind(p))


func _room_xf(n: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * n.global_transform


## A prop's original place in the room's frame.
func _original(p: WorldProp) -> Transform3D:
	return global_transform.affine_inverse() * (p.get_parent() as Node3D).global_transform * p.rest_transform


func _restore_moved(p: WorldProp, d: Dictionary) -> void:
	if d.has("orig") and p.get_parent() is VariantSocket:
		# A socket spawn settles onto its surface after load; the save knows where it stood.
		p.rest_transform = (p.get_parent() as Node3D).global_transform.affine_inverse() * global_transform * WorldStateData.xf(d["orig"])
	p.global_transform = global_transform * WorldStateData.xf(d.get("xf", []))
	p.set_meta("restored", true)


func _restore_broken(p: WorldProp, id: String, d: Dictionary) -> void:
	if p.broken_scene == null:
		return
	var orig: Transform3D = WorldStateData.xf(d["orig"]) if d.has("orig") else _original(p)
	var shards: Shards = p.broken_scene.instantiate() as Shards
	var parent: Node = p.get_parent()
	parent.add_child(shards)
	shards.global_transform = global_transform * orig
	var saved: Array = d.get("shards", [])
	for i: int in mini(saved.size(), shards.pieces.size()):
		shards.pieces[i].global_transform = global_transform * WorldStateData.xf(saved[i])
	shards.freeze_all()
	_mark_shards(shards, p, id, orig)
	p.broken = true
	parent.remove_child(p)
	p.queue_free()


func _mark_shards(shards: Shards, p: WorldProp, id: String, orig: Transform3D) -> void:
	var parent: Node = p.get_parent()
	shards.set_meta("world_id", id)
	shards.set_meta("prop_scene", p.scene_file_path)
	shards.set_meta("prop_name", String(p.name))
	shards.set_meta("prop_rest", orig)
	shards.set_meta("prop_parent", get_path_to(parent))
	shards.set_meta("socket_ordinal", (parent as VariantSocket).spawned().find(p) if parent is VariantSocket else -1)
	shards.settled.connect(_on_shards_settled.bind(shards))


func _on_prop_settled(p: WorldProp) -> void:
	var ws: Node = world_state()
	if ws == null or not is_instance_valid(p) or p.broken:
		return
	var id: String = p.get_meta("world_id")
	var orig: Transform3D = _original(p)
	var now: Transform3D = _room_xf(p)
	var turned: float = rad_to_deg(orig.basis.get_rotation_quaternion().angle_to(now.basis.get_rotation_quaternion()))
	if now.origin.distance_to(orig.origin) > p.settings.moved_epsilon or turned > p.settings.moved_epsilon_deg:
		ws.call("set_delta", id, {"s": "moved", "xf": WorldStateData.arr(now), "orig": WorldStateData.arr(orig), "scene": p.scene_file_path})
	else:
		ws.call("clear_delta", id)     # back where it started: nothing to remember


func _on_prop_broke(shards: Node3D, p: WorldProp) -> void:
	if shards is Shards and p.has_meta("world_id"):
		_mark_shards(shards as Shards, p, p.get_meta("world_id"), _original(p))


func _on_shards_settled(shards: Shards) -> void:
	var ws: Node = world_state()
	if ws == null or not is_instance_valid(shards):
		return
	var pieces: Array = shards.pieces.map(func(b: RigidBody3D) -> Array: return WorldStateData.arr(_room_xf(b)))
	ws.call("set_delta", shards.get_meta("world_id"), {"s": "broken", "shards": pieces,
		"orig": WorldStateData.arr(shards.get_meta("prop_rest")), "scene": shards.get_meta("prop_scene")})


## Before a save: props and shards still moving are recorded where they are now.
func _flush_moving() -> void:
	for p: WorldProp in world_props():
		if not p.freeze and not p.broken:
			_on_prop_settled(p)
	for s: Shards in room_shards():
		if not s.all_frozen:
			_on_shards_settled(s)
