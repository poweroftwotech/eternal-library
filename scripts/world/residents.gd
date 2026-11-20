class_name Residents
extends Node
## The people of one area (phase 21 steps 2-3, docs/npc/phase-21-approval.md):
## a child of the Area, beside Fauna. As a quarter's room is built it makes the
## room's walking surface (WalkMap), and when that is in gives each lived-in
## home a household: reads the home's spots from its furniture (SpotTable),
## hides the old posed figures, and makes the residents. Each frame it ticks
## their minds against the day's clock (DayClock), tells each who is in their
## way, lights and puts out each home's hearth and lamp, and opens a door for
## whoever walks through it.
##
## Steps 3-4: the family's, the scholar's and the hunter's homes have people.
## The test lane also gets a stall, which a quarter doesn't have of its own.
## Each trade's timetable is the RoutineBook's (gen/people/routines.tres),
## which the panel edits.
##
## Step 5: every area whose recipe's `people` is over 0 has them (the share
## of its furnished homes that are lived in; the Strata Board's People). A
## bazaar's room gets a surface too, and its open shops are spots: a place to
## buy before each, and the keeper's place, where a quarter's stall keeper
## stands in for the posed figure while they keep it. Rooms' surfaces are
## joined through the doorways between them (WalkMap.join) as the rooms come,
## so someone can walk from their lane to the bazaar next door when both are
## built. People exist only while their home's room does: when it comes back
## they are put where the hour has them. Of everyone, the MAX_BODIES nearest
## the eye are drawn, and those past FAR move at a quarter of the frames.
##
## F6 opens the People panel (ResidentsPanel); F4 the overlay
## (ResidentsOverlay: spots, who has them, the ways people are walking).

const GROUP: StringName = &"residents"
const LANE_RECIPE: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
## Who lives in a home of each kind, in order: trade (its timetable is the
## RoutineBook's) and outfit. A home has as many of them as it has beds.
const HOUSEHOLDS: Dictionary = {
	"family": [{"trade": "cook", "outfit": "house_dress"}, {"trade": "stall keeper", "outfit": "merchant"}, {"trade": "lamp tender", "outfit": "lamp_tender"}],
	"scholar": [{"trade": "scholar", "outfit": "scholar"}],
	"hunter": [{"trade": "hunter", "outfit": "hunter"}],
}
const NAMES: Dictionary = {
	"man": ["Dariush", "Kaveh", "Bahram", "Farhad", "Rostam", "Siavash", "Mehrdad", "Arash"],
	"woman": ["Shirin", "Roxana", "Anahita", "Mandana", "Parisa", "Golnar", "Homa", "Tahmineh"],
}
## A person's timetable runs up to this much early or late (bells).
const SHIFT: float = 0.06
## A light this close to the hearth is its fire; the home's other lights are lamps.
const HEARTH_REACH: float = 1.8
## A banked fire's light, as a share of the burning one.
const BANKED: float = 0.18
## A door opens for someone walking within this far of its middle.
const DOOR_REACH: float = 1.3
## How much room you take up in a lane (m), for people stepping round you.
const YOUR_HALF: float = 0.4
## The test lane's stall: the scene, and where it stands in the lane's room
## (a quarter has none of its own; in the Mahaleh stalls are the bazaar's).
const STALL: String = "res://kit/modules/dressing/court_contents_stall.tscn"
## How far either side of a doorway's middle the two rooms' surfaces are joined.
const JOIN_IN: float = 1.1
## A room that is only a way through is given this long for its surface.
const GIVE_UP_MS: int = 8000
## Those making do with a second-best place look for the best this often (s).
const RETHINK_EVERY: float = 6.0
## Bodies drawn at once (the nearest), and how far off one is animated cheaply.
const MAX_BODIES: int = 24
const FAR: float = 26.0
const LANE_STALL: Transform3D = Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(-7.8, 0, -15.5))

var area: Area
var people: Array[Resident] = []
## One per lived-in home: {slot, index, kind, room, members, spots, door,
## hearth_lights, lamp_lights, hearth_on, lamp_on, door_open}.
var households: Array[Dictionary] = []
## The lane's shared spots (the hauz, the stall): SpotTable.scan_commons.
var commons: Array = []
var ways: WalkMap
var labels: bool = false
## People step round you and wait for you (the tests turn it off).
var heed_player: bool = true
var panel: ResidentsPanel
var overlay: ResidentsOverlay
## Doorways joined: "slot a|slot b" -> the WalkMap link.
var links: Dictionary = {}
## How many bodies are drawn, and how many are animated cheaply (the panel).
var drawn: int = 0
var cheap: int = 0
var _rooms: Dictionary = {}     # slot -> the room node we know
var _filled: Dictionary = {}    # slot -> true once its surface is in and its people made
var _look_s: float = 0.0
var _rethink_s: float = 0.0
var _known_ways: Dictionary = {}
var _pending: Dictionary = {}   # slot -> {room, scans: {home index: scan}} while its surface bakes


## Residents for `world` if this place has them now; else null.
static func attach(world: Node3D) -> Residents:
	var a := world as Area
	if a == null or not (wanted() or (a.recipe != null and a.recipe.people > 0.0 and _any_homes(a))):
		return null
	var r := Residents.new()
	r.name = "Residents"
	r.area = a
	world.add_child(r)
	return r


# Whether the area's plan has a home furnished to be lived in.
static func _any_homes(a: Area) -> bool:
	if a.plan == null:
		return false
	for q: AreaPlan.Room in a.plan.rooms:
		if q.grid != null and q.grid.meta.has("homes"):
			for h: Dictionary in q.grid.meta["homes"]:
				if HOUSEHOLDS.has(h["kind"]):
					return true
	return false


## The share of furnished homes that are lived in here.
func share() -> float:
	if on_lane() or area.recipe == null or OS.get_cmdline_user_args().has("--residents"):
		return 1.0
	return area.recipe.people


## Whether home `index` of the room at `slot` is one of those lived in.
func lived_in(slot: String, index: int) -> bool:
	return float(posmod(hash([area.plan.area_seed, slot, index, "lived"]), 1000)) / 1000.0 < share()


## On the test lane, or when asked for (an area's own setting apart).
static func wanted() -> bool:
	if OS.get_cmdline_user_args().has("--residents"):
		return true
	return on_lane()


static func on_lane() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var ws: Node = tree.root.get_node_or_null("WorldState") if tree != null else null
	return ws != null and str(ws.get("walk_recipe")) == LANE_RECIPE


func _ready() -> void:
	add_to_group(GROUP)
	ways = WalkMap.new()
	var clock: DayClock = DayClock.it()
	if clock != null:
		clock.bell_rang.connect(_on_bell)
	panel = ResidentsPanel.new()
	panel.name = "Panel"
	panel.residents = self
	panel.visible = false
	add_child(panel)
	labels = OS.get_cmdline_user_args().has("--people-labels")


func _exit_tree() -> void:
	if ways != null:
		for key: String in links:
			ways.unjoin(links[key])
		links.clear()
		ways.close()


## Whether every room that is in has its people (its walking surface is made).
func settled() -> bool:
	return _pending.is_empty() and not _rooms.is_empty()


## Whether rooms `a` and `b` (slots) are joined by doorways all the way.
func joined(a: String, b: String) -> bool:
	if a == b:
		return true
	var todo: Array[String] = [a]
	var seen: Dictionary = {a: true}
	while not todo.is_empty():
		var at: String = todo.pop_back()
		for key: String in links:
			if not (links[key] as RID).is_valid():
				continue
			var ends: PackedStringArray = key.split("|")
			var next: String = ends[1] if ends[0] == at else (ends[0] if ends[1] == at else "")
			if next == "" or seen.has(next):
				continue
			if next == b:
				return true
			seen[next] = true
			todo.append(next)
	return false


# Joins the surfaces of rooms that are both in through the doorway between them.
func _join() -> void:
	for e: Dictionary in area.plan.edges:
		var a: String = e["a"]
		var b: String = e["b"]
		var key: String = a + "|" + b
		if links.has(key) or not _filled.has(a) or not _filled.has(b):
			continue
		# (A connector's own +Z is into its room.)
		var xf: Transform3D = area.global_transform * (area.plan.room(a).connectors[e["a_conn"]]["xf"] as Transform3D)
		var link: RID = ways.join(xf * Vector3(0.0, 0.25, JOIN_IN), xf * Vector3(0.0, 0.25, -JOIN_IN))
		links[key] = link
	_known_ways.clear()
	# A room with somewhere better to be has come: those making do think
	# again, once the surfaces have taken the join in.
	_rethink_s = 0.4


# A room has gone: its doorways' joins, and anyone's spot that was in it.
func _unjoin(slot: String) -> void:
	for key: String in links.keys():
		if key.begins_with(slot + "|") or key.ends_with("|" + slot):
			ways.unjoin(links[key])
			links.erase(key)
	for p: Resident in people:
		if is_instance_valid(p) and not p.spot.is_empty() and str(p.spot.get("slot", p.home_slot)) == slot:
			p.drop_spot()
	_known_ways.clear()
	# (They choose again once the surfaces have taken the change in: a way
	# asked for in the same frame can run through the room that went.)
	_rethink_s = 0.4


# The nearest MAX_BODIES are drawn; those past FAR are animated cheaply.
func _look(delta: float) -> void:
	_look_s -= delta
	if _look_s > 0.0:
		return
	_look_s = 0.25
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye: Vector3 = cam.global_position
	var by_far: Array = []
	for p: Resident in people:
		if is_instance_valid(p):
			by_far.append([p.global_position.distance_to(eye), p])
	by_far.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	drawn = 0
	cheap = 0
	for i: int in by_far.size():
		var p: Resident = by_far[i][1]
		p.body.visible = i < MAX_BODIES
		var far: bool = float(by_far[i][0]) > FAR
		p.body.set_far(far)
		if p.body.visible and not p.away:
			drawn += 1
			cheap += 1 if far else 0


func _process(delta: float) -> void:
	var clock: DayClock = DayClock.it()
	if clock == null:
		return
	# Rooms come and go with the streamer: start on the new, forget the gone.
	for slot: String in area.rooms:
		var room: Node3D = area.rooms[slot]
		if is_instance_valid(room) and room.is_inside_tree() and not _rooms.has(slot):
			_rooms[slot] = room
			_start(slot, room)
	for slot: String in _rooms.keys():
		# (A room taken down is out of the area's list at once, and leaves the
		# tree over some frames after: its people go with the first.)
		if not is_instance_valid(_rooms[slot]) or area.rooms.get(slot) != _rooms[slot]:
			if is_instance_valid(_rooms[slot]):
				ways.drop(_rooms[slot])
			for p: Resident in people:
				if is_instance_valid(p) and p.home_slot == slot:
					p.leave()
			people = people.filter(func(p: Resident) -> bool: return is_instance_valid(p) and p.home_slot != slot)
			_rooms.erase(slot)
			_pending.erase(slot)
			_filled.erase(slot)
			_unjoin(slot)
			households = households.filter(func(h: Dictionary) -> bool: return h["slot"] != slot)
			people = people.filter(func(p: Resident) -> bool: return is_instance_valid(p))
			var kept: Array = commons.filter(func(s: Dictionary) -> bool: return s["slot"] != slot)
			commons.clear()
			commons.append_array(kept)
			ways.tidy()
	for slot: String in _pending.keys():
		var room: Node3D = _pending[slot]["room"]
		if not _pending[slot]["scans"].is_empty() or Time.get_ticks_msec() - int(_pending[slot]["since"]) < GIVE_UP_MS:
			pass
		elif not ways.ready_for(room):
			# No floor found where its doorway is: nobody walks through here.
			_pending.erase(slot)
			continue
		if ways.ready_for(room):
			var scans: Dictionary = _pending[slot]["scans"]
			_pending.erase(slot)
			_fill(slot, room, scans, clock)
			_filled[slot] = true
			_join()
	# A shop's posed keeper stands only while nobody keeps it.
	for s: Dictionary in commons:
		if s.has("stand_in") and is_instance_valid(s["stand_in"]):
			(s["stand_in"] as Node3D).visible = s["by"] == null or not is_instance_valid(s["by"])
	_look(delta)
	_rethink_s -= delta
	if _rethink_s <= 0.0:
		# (And every so often anyway: a shop's place may have come free.)
		_rethink_s = RETHINK_EVERY
		for p: Resident in people:
			if is_instance_valid(p):
				p.rethink()
	if not clock.paused:
		advance(delta, clock)


## One step of everyone's day: `delta` real seconds at the clock's speed.
func advance(delta: float, clock: DayClock) -> void:
	var others: Array = []
	var game: Node = get_tree().current_scene
	var player: Node3D = (game.get("player") as Node3D) if game != null else null
	if heed_player and player != null and not bool(player.get("flying")):
		others.append({"at": player.global_position, "r": YOUR_HALF, "who": null})
	for p: Resident in people:
		if (p.doing != "sleep" or p.walking) and not p.away:
			others.append({"at": p.global_position, "r": Resident.HALF, "who": p})
	for p: Resident in people:
		p.tick(delta, clock, others)
		p.show_label(labels)
	for h: Dictionary in households:
		_keep_house(h)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F6:
		panel.set_open(not panel.visible)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F4:
		# (The animals' overlay is on F4 too: one key shows both.)
		show_overlay(overlay == null or not overlay.visible)


## Turns the overlay on or off (ResidentsOverlay).
func show_overlay(on: bool) -> void:
	if on and overlay == null:
		overlay = ResidentsOverlay.new()
		overlay.name = "Overlay"
		overlay.residents = self
		add_child(overlay)
	if overlay != null:
		overlay.set_on(on)


func _plan_of(slot: String) -> AreaPlan.Room:
	for q: AreaPlan.Room in area.plan.rooms:
		if q.slot_id == slot:
			return q
	return null


# A quarter's room is in: its old figures go, its shared things come, and its
# walking surface is started. The people come when the surface is made.
func _start(slot: String, room: Node3D) -> void:
	var plan: AreaPlan.Room = _plan_of(slot)
	if plan == null or plan.grid == null:
		return
	if not plan.grid.meta.has("homes"):
		# Not a quarter: a surface to walk through it (a bazaar's shops are
		# gone to; a square or an alley is the way there). Its figures stay.
		var way_in: Variant = _way_in(plan)
		if way_in != null:
			ways.add_room(room, way_in as Vector3)
			_pending[slot] = {"room": room, "scans": {}, "since": Time.get_ticks_msec()}
		return
	var homes: Array = plan.grid.meta["homes"]
	var scans: Dictionary = {}
	for i: int in homes.size():
		if not HOUSEHOLDS.has(homes[i]["kind"]):
			continue
		var scan: Dictionary = SpotTable.scan_home(room, i, homes[i])
		for s: Node3D in scan["statues"]:
			_put_away(s)
		if lived_in(slot, i):
			scans[i] = scan
		else:
			# Furnished, and nobody home: dark, the fire banked, the door shut.
			var empty: Dictionary = {"members": [], "door": null, "doorway": Vector3.ZERO, "hearth_lights": [], "lamp_lights": [], "hearth_on": true,
					"lamp_on": true, "door_open": false}
			_find_lights(empty, room, i, homes[i])
			_keep_house(empty, true)
	# The posed figures of the lanes go too: there are people now.
	for n: Node in room.find_children("prop_qt_fig_*", "Node3D", true, false):
		if n.scene_file_path != "":
			_put_away(n as Node3D)
	if on_lane() and room.get_node_or_null("LaneStall") == null:
		var stall: Node3D = (load(STALL) as PackedScene).instantiate()
		stall.name = "LaneStall"
		room.add_child(stall)
		stall.transform = LANE_STALL
	var doors: Array = room.find_children("prop_qt_home*_door", "CollisionObject3D", true, false)
	ways.add_room(room, room.to_global(homes[0]["inside"] as Vector3), doors)
	_pending[slot] = {"room": room, "scans": scans, "since": Time.get_ticks_msec()}


# A place on the floor just inside one of the room's doorways (global), or
# null if it has none.
func _way_in(plan: AreaPlan.Room) -> Variant:
	var names: Array = plan.connectors.keys()
	if plan.connectors.has(plan.entry):
		names.push_front(plan.entry)
	for n: Variant in names:
		# (A connector's own +Z is into its room.)
		return area.global_transform * ((plan.connectors[n]["xf"] as Transform3D) * Vector3(0.0, 0.1, 1.6))
	return null


# The room's surface is made: a household for each home of a kind that has one.
func _fill(slot: String, room: Node3D, scans: Dictionary, clock: DayClock) -> void:
	var plan: AreaPlan.Room = _plan_of(slot)
	var shared: Array[Dictionary] = SpotTable.scan_commons(room)
	var homes: Array = plan.grid.meta.get("homes", [])
	if plan.grid.meta.get("bazaar", false) and not plan.grid.meta.get("deserted", false):
		shared.append_array(_shop_spots(room, plan))
	elif not homes.is_empty():
		shared.append_array(_lane_spots(room, plan, room.to_global(homes[0]["inside"] as Vector3).y))
	for s: Dictionary in shared:
		s["slot"] = slot
		commons.append(s)
	for i: int in scans:
		var home: Dictionary = homes[i]
		var scan: Dictionary = scans[i]
		var inside: Vector3 = room.to_global(home["inside"] as Vector3)
		var on_floor: Vector3 = ways.nearest(inside)
		scan["anchor"] = Vector3(on_floor.x, inside.y, on_floor.z)
		var h: Dictionary = {"slot": slot, "index": i, "kind": home["kind"], "room": room, "members": [], "spots": scan["spots"],
				"door": room.find_child("prop_qt_home%d_door" % i, true, false), "hearth_lights": [], "lamp_lights": [],
				"hearth_on": true, "lamp_on": true, "door_open": false, "doorway": room.to_global(home["front"] as Vector3)}
		_find_lights(h, room, i, home)
		var beds: Array = (scan["spots"] as Array).filter(func(s: Dictionary) -> bool: return s["kind"] == "sleep")
		var who: Array = HOUSEHOLDS[home["kind"]]
		# (One lamp tender to a lane: its first family's.)
		if people.any(func(p: Resident) -> bool: return is_instance_valid(p) and p.home_slot == slot and p.trade == "lamp tender"):
			who = who.filter(func(w: Dictionary) -> bool: return w["trade"] != "lamp tender")
		var book: RoutineBook = RoutineBook.open()
		# (As many people as beds: a home's first trade always, the rest if they can sleep.)
		for k: int in mini(who.size(), maxi(beds.size(), 1)):
			var seed_value: int = hash([area.plan.area_seed, slot, i, k])
			var r := Resident.new()
			r.body = ResidentBody.dressed(str(who[k]["outfit"]), posmod(seed_value, ResidentBody.FACES.size()))
			r.add_child(r.body)
			r.trade = str(who[k]["trade"])
			var names: Array = NAMES[r.body.kind]
			# (No two of a name in one lane; other lanes are not looked at, so a
			# person has the same name whenever their room is built.)
			var pick: int = posmod(seed_value >> 8, names.size())
			for _n: int in names.size():
				if not people.any(func(p: Resident) -> bool: return is_instance_valid(p) and p.home_slot == slot and p.given_name == str(names[pick])):
					break
				pick = (pick + 1) % names.size()
			r.given_name = str(names[pick])
			r.name = "Resident_%s" % r.given_name
			r.blocks = book.of(r.trade)
			r.shift = (float(posmod(seed_value >> 4, 1000)) / 1000.0 - 0.5) * 2.0 * SHIFT
			r.seed_value = seed_value
			r.home = scan
			r.home_slot = slot
			r.joined = joined
			r.known_ways = _known_ways
			r.commons = commons
			r.ways = ways
			if k < beds.size():
				r.bed = beds[k]
			room.add_child(r)
			r.stand_at(scan["anchor"])
			# Where the hour has them, at once.
			r.tick(0.0, clock)
			r.arrive_now()
			(h["members"] as Array).append(r)
			people.append(r)
		households.append(h)
		_keep_house(h, true)


# A bazaar's spots: before each open shop a place to buy (two can stand
# there), and its keeper's place, the posed keeper standing in until someone
# comes to keep it.
func _shop_spots(room: Node3D, plan: AreaPlan.Room) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keepers: Array[Node] = room.find_children("prop_bz_item_keeper_*", "Node3D", true, false)
	for shop: Array in plan.grid.meta.get("shops", []):
		if str(shop[2]) == "bare":
			continue
		var inside: Vector3 = room.to_global(shop[0] as Vector3)
		var street: Vector3 = room.to_global(shop[1] as Vector3)
		var into: Vector3 = (inside - street).normalized()
		var across: Vector3 = into.cross(Vector3.UP)
		var yaw_in: float = atan2(-into.x, -into.z)
		for side: float in [-0.5, 0.5]:
			out.append(SpotTable._spot("buy", street + into * 0.9 + across * side, yaw_in, "idle", null))
		var figure: Node3D = null
		for k: Node in keepers:
			if k.scene_file_path != "" and (k as Node3D).global_position.distance_to(inside) < 4.5 and (figure == null or SpotTable.box_of(k as Node3D).get_center().distance_to(inside) < SpotTable.box_of(figure).get_center().distance_to(inside)):
				figure = k as Node3D
		if figure != null:
			var c: Vector3 = SpotTable.box_of(figure).get_center()
			var keep: Dictionary = SpotTable._spot("keep", Vector3(c.x, inside.y, c.z), yaw_in + PI, "idle", null)
			keep["stand_in"] = figure
			out.append(keep)
	return out


# The lane's own spots: under each of its lamps (a lamp tender's round), and
# the way out of the lane (where someone who works away goes).
func _lane_spots(room: Node3D, plan: AreaPlan.Room, floor_y: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lamps: Array[Vector3] = []
	for n: Node in room.find_children("*", "Node3D", true, false):
		if n.scene_file_path.get_extension() == "tscn" and n.scene_file_path.get_file().get_basename() == "qt_door_lamp":
			lamps.append((n as Node3D).global_position)
	for n: Node in room.find_children("prop_exit_*", "Node3D", true, false):
		lamps.append((n as Node3D).global_position)
	var threshold: Node3D = room.find_child("Threshold_*", false, false) as Node3D
	if threshold != null and threshold.get_node_or_null("Light") != null:
		lamps.append((threshold.get_node("Light") as Node3D).global_position)
	for at: Vector3 in lamps:
		var under := Vector3(at.x, floor_y, at.z)
		var foot: Vector3 = ways.nearest(under)
		var off := Vector2(foot.x - under.x, foot.z - under.z)
		# (Not the lamps up a stair or beyond a wall.)
		if off.length() > 1.6 or absf(foot.y - floor_y) > 0.6 or ways.walk_length(ways.nearest(room.to_global(plan.grid.meta["homes"][0]["door"])), foot) > 200.0:
			continue
		var yaw: float = atan2(off.x, off.y) if off.length() > 0.05 else 0.0
		var spot: Dictionary = SpotTable._spot("lamp", Vector3(foot.x, floor_y, foot.z), yaw, "idle", null)
		out.append(spot)
	var route: Array = plan.grid.meta.get("route", [])
	if not route.is_empty():
		var gate: Vector3 = ways.nearest(room.to_global(route[0] as Vector3) + Vector3(0, 0, 0))
		if absf(gate.y - floor_y) < 0.6:
			var into: Vector3 = room.to_global(route[mini(1, route.size() - 1)] as Vector3) - room.to_global(route[0] as Vector3)
			out.append(SpotTable._spot("away", Vector3(gate.x, floor_y, gate.z), atan2(into.x, into.z), "idle", null))
	return out


# An old posed figure: out of sight and out of the way.
func _put_away(statue: Node3D) -> void:
	statue.visible = false
	for b: Node in statue.find_children("*", "CollisionObject3D", true, false):
		(b as CollisionObject3D).collision_layer = 0
		(b as CollisionObject3D).collision_mask = 0


# The home's lights: the hearth's fire, and its lamps.
func _find_lights(h: Dictionary, room: Node3D, index: int, home: Dictionary) -> void:
	var inside: Vector3 = room.to_global(home["inside"] as Vector3)
	var reach: float = 4.3 if home["deep"] else 2.7
	var hearths: Array[Vector3] = []
	for n: Node in room.find_children("prop_qt_item_%d_*" % index, "Node3D", true, false):
		if n.scene_file_path.get_file().contains("hearth"):
			hearths.append((n as Node3D).global_position)
	for n: Node in room.find_children("*", "Light3D", true, false):
		var light := n as Light3D
		var d: Vector3 = light.global_position - inside
		if Vector2(d.x, d.z).length() > reach or absf(d.y) > 3.0:
			continue
		var fire: bool = false
		for at: Vector3 in hearths:
			if light.global_position.distance_to(at) < HEARTH_REACH:
				fire = true
		(h["hearth_lights"] if fire else h["lamp_lights"]).append(light)


# The hearth burns while someone cooks or eats; the lamp while someone is up.
# The door opens for whoever walks through.
func _keep_house(h: Dictionary, force: bool = false) -> void:
	var up: bool = false
	var fire: bool = false
	var at_door: bool = false
	var door: Node3D = h["door"] as Node3D
	var doorway: Vector3 = h["doorway"]
	for m: Variant in h["members"]:
		var r := m as Resident
		if not is_instance_valid(r):
			continue
		if r.block != "sleep":
			up = true
		if r.doing in ["cook", "eat"] and not r.walking:
			fire = true
		if door != null and r.walking and r.global_position.distance_to(doorway) < DOOR_REACH:
			at_door = true
	if fire != h["hearth_on"] or force:
		h["hearth_on"] = fire
		_bank(h["hearth_lights"], fire)
	if up != h["lamp_on"] or force:
		h["lamp_on"] = up
		_switch(h["lamp_lights"], up)
	if door != null and door.has_method("set_open") and (at_door != h["door_open"]):
		h["door_open"] = at_door
		door.call("set_open", at_door)


# A lamp lit or put out: its light (which the area's light budget also leaves
# off while its lamp_state is dark) and its flame (the kit's "__glass" mesh
# beside the light).
static func _switch(lights: Array, on: bool) -> void:
	for l: Variant in lights:
		if not is_instance_valid(l):
			continue
		var light := l as Light3D
		light.set_meta("lamp_state", "lit" if on else "dark")
		light.visible = on
		for sib: Node in light.get_parent().get_children():
			if sib is MeshInstance3D and String(sib.name).ends_with("__glass"):
				(sib as MeshInstance3D).visible = on


# A hearth is never cold: between meals its fire is banked, a low glow.
static func _bank(lights: Array, burning: bool) -> void:
	for l: Variant in lights:
		if not is_instance_valid(l):
			continue
		var light := l as Light3D
		if not light.has_meta("resident_energy"):
			light.set_meta("resident_energy", light.light_energy)
		light.light_energy = float(light.get_meta("resident_energy")) * (1.0 if burning else BANKED)


func _on_bell(index: int) -> void:
	var game: Node = get_tree().current_scene
	var hud: Variant = game.get("hud") if game != null else null
	if hud != null and (hud as Object).has_method("notify"):
		(hud as Object).call("notify", DayClock.NAMES[index])


## Everyone and what they are doing, a line each (the panel, the tests).
func roll() -> PackedStringArray:
	var out := PackedStringArray()
	var clock: DayClock = DayClock.it()
	for p: Resident in people:
		if is_instance_valid(p):
			out.append("%s, %s: %s" % [p.given_name, p.trade, p.describe(clock.bells()).replace("\n", "; ")])
	return out
