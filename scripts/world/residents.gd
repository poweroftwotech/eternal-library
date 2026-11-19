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
## Step 3: the family's, the scholar's and the hunter's homes have people,
## only on the test lane (or with `-- --residents`). The lane also gets a
## stall, which a quarter doesn't have of its own.
##
## F6 opens the People panel (ResidentsPanel); F4 the overlay
## (ResidentsOverlay: spots, who has them, the ways people are walking).

const GROUP: StringName = &"residents"
const LANE_RECIPE: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
## Who lives in a home of each kind: trade, outfit, timetable.
const HOUSEHOLDS: Dictionary = {
	"family": [{"trade": "cook", "outfit": "house_dress", "routine": "cook"}, {"trade": "householder", "outfit": "lane_coat", "routine": "householder"}],
	"scholar": [{"trade": "scholar", "outfit": "scholar", "routine": "scholar"}],
	"hunter": [{"trade": "hunter", "outfit": "hunter", "routine": "hunter"}],
}
## The timetables (Q4): [bell, activity], the bell counted from the first (0)
## to just before the first again (6). "free" picks among the door, a seat,
## the hauz and standing about. Placeholders in code until step 4 puts them in
## files the panel edits.
const ROUTINES: Dictionary = {
	"cook": [[0.0, "wake"], [0.08, "water"], [0.2, "cook"], [0.7, "eat"], [1.1, "free"], [1.45, "shop"], [1.6, "free"], [1.86, "water"], [2.0, "cook"],
			[2.5, "eat"], [3.0, "free"], [3.86, "water"], [4.0, "cook"], [4.4, "eat"], [4.8, "door"], [5.0, "sleep"]],
	"householder": [[0.15, "wake"], [0.3, "door"], [0.7, "eat"], [1.1, "keep"], [2.5, "eat"], [3.0, "keep"], [4.4, "eat"], [4.8, "hauz"], [5.05, "sleep"]],
	"scholar": [[0.2, "wake"], [0.3, "water"], [0.42, "work"], [1.7, "shop"], [1.85, "work"], [2.6, "door"], [2.9, "work"], [4.5, "hauz"], [5.1, "sleep"]],
	"hunter": [[0.05, "wake"], [0.15, "work"], [1.25, "shop"], [1.4, "work"], [2.4, "hauz"], [2.8, "work"], [4.0, "water"], [4.12, "free"], [4.6, "hauz"],
			[4.95, "sleep"]],
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
var _rooms: Dictionary = {}     # slot -> the room node we know
var _pending: Dictionary = {}   # slot -> {room, scans: {home index: scan}} while its surface bakes


## Residents for `world` if this place has them now; else null.
static func attach(world: Node3D) -> Residents:
	var a := world as Area
	if a == null or not wanted():
		return null
	var r := Residents.new()
	r.name = "Residents"
	r.area = a
	world.add_child(r)
	return r


## Steps 2-3: on the test lane, or when asked for.
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
		ways.close()


## Whether every room that is in has its people (its walking surface is made).
func settled() -> bool:
	return _pending.is_empty() and not _rooms.is_empty()


func _process(delta: float) -> void:
	var clock: DayClock = DayClock.it()
	if clock == null:
		return
	# Rooms come and go with the streamer: start on the new, forget the gone.
	for slot: String in area.rooms:
		var room: Node3D = area.rooms[slot]
		if is_instance_valid(room) and room.is_inside_tree() and _rooms.get(slot) != room:
			_rooms[slot] = room
			_start(slot, room)
	for slot: String in _rooms.keys():
		if not is_instance_valid(_rooms[slot]):
			_rooms.erase(slot)
			_pending.erase(slot)
			households = households.filter(func(h: Dictionary) -> bool: return h["slot"] != slot)
			people = people.filter(func(p: Resident) -> bool: return is_instance_valid(p))
			var kept: Array = commons.filter(func(s: Dictionary) -> bool: return s["slot"] != slot)
			commons.clear()
			commons.append_array(kept)
			ways.tidy()
	for slot: String in _pending.keys():
		var room: Node3D = _pending[slot]["room"]
		if ways.ready_for(room):
			var scans: Dictionary = _pending[slot]["scans"]
			_pending.erase(slot)
			_fill(slot, room, scans, clock)
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
		if p.doing != "sleep" or p.walking:
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
	if plan == null or plan.grid == null or not plan.grid.meta.has("homes"):
		return
	var homes: Array = plan.grid.meta["homes"]
	var scans: Dictionary = {}
	for i: int in homes.size():
		if not HOUSEHOLDS.has(homes[i]["kind"]):
			continue
		scans[i] = SpotTable.scan_home(room, i, homes[i])
		for s: Node3D in scans[i]["statues"]:
			_put_away(s)
	if on_lane() and room.get_node_or_null("LaneStall") == null:
		var stall: Node3D = (load(STALL) as PackedScene).instantiate()
		stall.name = "LaneStall"
		room.add_child(stall)
		stall.transform = LANE_STALL
	var doors: Array = room.find_children("prop_qt_home*_door", "CollisionObject3D", true, false)
	ways.add_room(room, room.to_global(homes[0]["inside"] as Vector3), doors)
	_pending[slot] = {"room": room, "scans": scans}


# The room's surface is made: a household for each home of a kind that has one.
func _fill(slot: String, room: Node3D, scans: Dictionary, clock: DayClock) -> void:
	var plan: AreaPlan.Room = _plan_of(slot)
	var homes: Array = plan.grid.meta["homes"]
	for s: Dictionary in SpotTable.scan_commons(room):
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
		for k: int in who.size():
			var seed_value: int = hash([area.plan.area_seed, slot, i, k])
			var r := Resident.new()
			r.body = ResidentBody.dressed(str(who[k]["outfit"]), posmod(seed_value, ResidentBody.FACES.size()))
			r.add_child(r.body)
			r.trade = str(who[k]["trade"])
			var names: Array = NAMES[r.body.kind]
			r.given_name = str(names[posmod(seed_value >> 8, names.size())])
			r.name = "Resident_%s" % r.given_name
			r.blocks = ROUTINES[str(who[k]["routine"])]
			r.shift = (float(posmod(seed_value >> 4, 1000)) / 1000.0 - 0.5) * 2.0 * SHIFT
			r.seed_value = seed_value
			r.home = scan
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
