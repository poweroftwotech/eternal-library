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
## Lore books on this room's shelves (ENVIRONMENT_PLAN.md 6.5.4). Each recess
## used must be room-pinned to a shelf candidate (Validate Room checks).
@export var lore_books: Array[LoreBookPin] = []
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
## Set by AreaStreamer (phase-4-design.md 8.1.4): the room's sockets were
## resolved off the tree, in slices, before it entered; _ready only restores
## the save's changes.
var prepared: bool = false
## Set by AreaStreamer (phase 5 step 4): a big room enters the tree first and
## its parts after, a frame's budget at a time; the streamer restores the save's
## changes once they are all in.
var hold_restore: bool = false
var _last_seed: int = 1


func _ready() -> void:
	if not prepared:
		resolve_sockets(preview_seed if Engine.is_editor_hint() or area_seed < 0 else area_seed)
	if not hold_restore:
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
	begin_resolve(seed_value)
	resolve_next(-1)
	return _resolve_picks


# The resolve in slices (AreaStreamer, phase-4-design.md 8.1.4): begin_resolve,
# then resolve_next until it returns true. resolve_sockets does it all at once.
var _resolve_queue: Array[VariantSocket] = []
var _resolve_at: int = 0
var _resolve_picks: Dictionary = {}
var _resolve_styles: Dictionary = {}


func begin_resolve(seed_value: int) -> void:
	_last_seed = seed_value
	_resolve_picks = {}
	_resolve_styles = style_picks(seed_value)
	var all: Array[VariantSocket] = sockets()
	# Sockets gated on a sibling's look (VariantSocket.needs_look) go after the looks.
	_resolve_queue = all.filter(func(v: VariantSocket) -> bool: return v.needs_look == "") + all.filter(func(v: VariantSocket) -> bool: return v.needs_look != "")
	_resolve_at = 0


## Resolves sockets until `deadline_usec` (Time.get_ticks_usec(); -1: no
## limit), at least one. Returns true once every socket is resolved and the
## claims are applied.
func resolve_next(deadline_usec: int) -> bool:
	while _resolve_at < _resolve_queue.size():
		var s: VariantSocket = _resolve_queue[_resolve_at]
		_resolve_at += 1
		var key: String = socket_key(s)
		var group: String = s.socket_set.style_group if s.socket_set != null else ""
		var sseed: int = socket_seed(_last_seed, key)
		var world_pin: int = _world_pin(s, key, sseed, pin_for(key), _resolve_styles.get(group, -1))     # the save and the years (6.5.6)
		_resolve_picks[key] = s.resolve(sseed, world_pin if world_pin >= 0 else pin_for(key), _resolve_styles.get(group, -1))
		if deadline_usec >= 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	if _resolve_at < _resolve_queue.size():
		return false
	apply_claims()
	_resolve_queue = []
	return true


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
## Also found for a room being prepared off the tree (AreaStreamer), so its
## sockets resolve with the save and the years as a live room's do.
func world_state() -> Node:
	if Engine.is_editor_hint():
		return null
	if is_inside_tree():
		return get_node_or_null("/root/WorldState")
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("WorldState") if tree != null else null


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
	_add_lamp_tends()
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
	for fill: ShelfFill in shelf_fills():
		_restore_books(ws, fill)


## Puts one changed thing back as it was originally (WorldState.revert calls
## this; it also drops the delta). Returns whether it found the thing.
func revert_thing(id: String) -> bool:
	var path: String = id.substr(room_key().length() + 1)
	var state_socket := get_node_or_null(NodePath(path)) as VariantSocket if not path.contains("#") else null
	if state_socket != null:
		resolve_world(state_socket, true)     # a tended lamp goes back to what the years made it
		return true
	for p: WorldProp in world_props():
		if p.get_meta("world_id", "") == id:
			if p.has_meta("shelf_index") and p.get_parent() is ShelfFill:
				(p.get_parent() as ShelfFill).unhide_book(int(p.get_meta("shelf_index")))     # back on its shelf
				p.refreeze()
				p.queue_free()
				return true
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
	p.taken.connect(_on_prop_taken.bind(p))


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


# --- shelf books (ENVIRONMENT_PLAN.md 6.5.4) -----------------------------------

## The lore books pinned on the recess socket at `socket_path`.
func lore_pins_for(socket_path: String) -> Array[LoreBookPin]:
	var out: Array[LoreBookPin] = []
	for pin: LoreBookPin in lore_books:
		if pin != null and pin.socket == socket_path:
			out.append(pin)
	return out


## ShelfFills spawned by this room's recess sockets.
func shelf_fills() -> Array[ShelfFill]:
	var out: Array[ShelfFill] = []
	for s: VariantSocket in sockets():
		for n: Node in s.spawned():
			if n is ShelfFill:
				out.append(n as ShelfFill)
	return out


## A shelf book's save id: the recess socket path plus "#b<instance>", or
## "#lore:<item id>" for a lore book (its place, so a janitor knows the shelf).
func book_id(fill: ShelfFill, index: int) -> String:
	var item: ItemDef = fill.lore_item(index)
	var socket_path: String = socket_key(fill.get_parent() as VariantSocket)
	return "%s/%s#%s" % [room_key(), socket_path, "lore:%s" % item.id if item != null else "b%d" % index]


func _restore_books(ws: Node, fill: ShelfFill) -> void:
	fill.pulled.connect(_on_book_pulled.bind(fill))
	var prefix: String = "%s/%s#" % [room_key(), socket_key(fill.get_parent() as VariantSocket)]
	for id: String in ws.call("changed_ids", room_key()):
		if not id.begins_with(prefix):
			continue
		var token: String = id.substr(prefix.length())
		var index: int = int(fill.lore_index.get(StringName(token.trim_prefix("lore:")), -1)) if token.begins_with("lore:") else token.trim_prefix("b").to_int()
		if index < 0 or index >= fill.built_transforms.size() or (token.begins_with("b") and not token.trim_prefix("b").is_valid_int()):
			continue
		var d: Dictionary = ws.call("delta", id)
		ws.call("note_applied", id)
		if str(d.get("s", "")) == "taken":
			fill.hide_book(index)
			continue
		var book: WorldProp = fill.make_book(index)
		_track(book, id)
		book.global_transform = global_transform * WorldStateData.xf(d.get("xf", []))
		book.set_meta("restored", true)


## A book was pulled out: track it and remember it sticking out of the shelf.
func _on_book_pulled(book: WorldProp, index: int, fill: ShelfFill) -> void:
	_track(book, book_id(fill, index))
	_on_prop_settled(book)


func _on_prop_taken(p: WorldProp) -> void:
	var ws: Node = world_state()
	if ws == null or not p.has_meta("world_id"):
		return
	ws.call("set_delta", p.get_meta("world_id"), {"s": "taken", "item": String(p.item.id) if p.item != null else "",
		"orig": WorldStateData.arr(_original(p)), "scene": p.scene_file_path})


# --- the years: aging and tended lamps (ENVIRONMENT_PLAN.md 6.5.6) ---------------
# Pin layers, strongest first: the player's state delta (a tended lamp), then
# aging (only forward along its rule's chain, only if untouched), then the base
# pick (socket_pins, generated_pins, style, seed). Nothing about aging is
# stored: the years and a fixed draw per socket decide it.

## The index the save or the years force on a socket, or -1 to keep its pick.
func _world_pin(s: VariantSocket, key: String, sseed: int, pin: int, style: int, ignore_player: bool = false) -> int:
	var ws: Node = world_state()
	if ws == null or s.socket_set == null:
		return -1
	var id: String = room_key() + "/" + key
	var d: Dictionary = ws.call("delta", id)
	if not ignore_player and str(d.get("s", "")) == "state":
		ws.call("note_applied", id)
		return s.socket_set.index_of(str(d.get("label", "")))
	return aged_index(s, id, s.pick_index(sseed, pin, style))


## What `base` becomes after the world's years, or -1 if it doesn't age: no
## rule for its set, marked ageless, touched by the player, or not old enough.
func aged_index(s: VariantSocket, id: String, base: int) -> int:
	var ws: Node = world_state()
	if ws == null or base < 0 or is_ageless(s):
		return -1
	var rule: AgeRule = (ws.call("age_rules") as AgeRules).rule_for(s.socket_set)
	if rule == null:
		return -1
	var base_step: int = rule.chain.find(s.socket_set.entries[base].label)
	if base_step < 0:
		return -1
	for changed: String in ws.call("changed_ids", room_key()):
		if changed == id or changed.begins_with(id + "#") or changed.begins_with(id + "/"):
			return -1     # the player has touched it: only untouched things age
	var step: int = rule.step_at(float(ws.call("years")), float(ws.call("age_draw", id)))
	return s.socket_set.index_of(rule.chain[step]) if step > base_step else -1


## Re-resolves one socket with the current save and years (a lamp just
## tended, the years just moved on, or a janitor's revert).
func resolve_world(s: VariantSocket, ignore_player: bool = false) -> void:
	var key: String = socket_key(s)
	var group: String = s.socket_set.style_group if s.socket_set != null else ""
	var style: int = style_picks(current_seed()).get(group, -1) if group != "" else -1
	var sseed: int = socket_seed(current_seed(), key)
	var world_pin: int = _world_pin(s, key, sseed, pin_for(key), style, ignore_player)
	s.resolve(sseed, world_pin if world_pin >= 0 else pin_for(key), style)


## The years moved on: every socket an age rule covers looks its age now.
func refresh_aging() -> int:
	var ws: Node = world_state()
	if ws == null:
		return 0
	var n: int = 0
	for s: VariantSocket in sockets():
		if (ws.call("age_rules") as AgeRules).rule_for(s.socket_set) != null:
			resolve_world(s)
			n += 1
	return n


## Sets a lamp's state for the player (Light / Douse) and remembers it; the
## lamp no longer ages. `orig` is what it showed before (for a janitor).
func tend_lamp(s: VariantSocket, label: String) -> void:
	var ws: Node = world_state()
	if ws == null:
		return
	var before: String = s.picked_label()
	ws.call("set_delta", room_key() + "/" + socket_key(s), {"s": "state", "label": label,
		"day": float((ws.get("data") as Dictionary).get("clock_days", 0.0)), "orig": before})
	resolve_world(s)


## Lamp sockets get a reach target (LampTend) at their glass.
func _add_lamp_tends() -> void:
	var ws: Node = world_state()
	if ws == null:
		return
	for s: VariantSocket in sockets():
		if s.mode != VariantSocket.Mode.STATE or s.socket_set == null or s.socket_set.index_of("lit") < 0:
			continue
		LampTend.attach(self, s)


## A designer's "never ages": meta `ageless` on the socket or on any node
## between it and this room, such as a placed module instance (R01 marks its
## two chandeliers so the hall keeps its main light).
func is_ageless(s: Node) -> bool:
	var n: Node = s
	while n != null and n != self:
		if n.get_meta("ageless", false):
			return true
		n = n.get_parent()
	return false
