extends SceneTree
## Phase 3 step 4 gate (ENVIRONMENT_PLAN.md 6.5.6): the world clock and AgeRules.
## R01 + stack gallery (seed 7) in memory, with a scratch save.
##   godot --headless --path . --script res://tests/age_test.gd
## The two-process version (years survive a restart) is in persist_test.

var failures: PackedStringArray = []
var checks: int = 0
var ws: Node
var room: RoomTemplate


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	ws = root.get_node("WorldState")
	ws.call("forget")
	check_rule()
	GeneratedRoom.seed_override = 7
	room = (load("res://rooms/test/reading_room_r02.tscn") as PackedScene).instantiate()
	root.add_child(room)
	for _i: int in 3:
		await physics_frame
	await check_room()
	GeneratedRoom.seed_override = -1
	print("age_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func check_rule() -> void:
	var rules: AgeRules = AgeRules.default()
	var lamp: AgeRule = rules.rule_for(load("res://kit/sockets/lamp_state.tres"))
	check(lamp != null and lamp.chain == PackedStringArray(["lit", "failing", "dark"]), "stratum 1 ages lamps lit → failing → dark")
	if lamp == null:
		return
	var monotone: bool = true
	var dark_below_failing: bool = true
	for k: int in 200:
		var u: float = (k + 0.5) / 200.0
		var last: int = 0
		for y: int in 61:
			var step: int = lamp.step_at(float(y), u)
			monotone = monotone and step >= last
			last = step
	for y: int in 61:
		dark_below_failing = dark_below_failing and lamp.step_chance[1].sample(y) <= lamp.step_chance[0].sample(y) + 1e-6
	check(monotone, "more years never move a lamp back along the chain")
	check(dark_below_failing, "the chance of dark never exceeds the chance of failing")
	check(lamp.step_at(0.0, 0.001) == 0, "at year 0 nothing has aged")


## Lamp sockets of R01 and the gallery, with their room.
func lamps() -> Array:
	var out: Array = []
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		for s: VariantSocket in r.sockets():
			if s.mode == VariantSocket.Mode.STATE and s.socket_set != null and s.socket_set.index_of("lit") >= 0:
				out.append([r, s])
	return out


func step_of(s: VariantSocket) -> int:
	return ["lit", "failing", "dark"].find(s.picked_label())


func base_step(r: RoomTemplate, s: VariantSocket) -> int:
	var key: String = r.socket_key(s)
	var idx: int = s.pick_index(r.socket_seed(r.current_seed(), key), r.pin_for(key), -1)
	return ["lit", "failing", "dark"].find(s.socket_set.entries[idx].label)


func others(r: RoomTemplate) -> Dictionary:
	var out: Dictionary = {}
	for s: VariantSocket in r.sockets():
		if s.mode != VariantSocket.Mode.STATE:
			out[r.socket_key(s)] = s.last_pick
	return out


func check_room() -> void:
	var all: Array = lamps()
	check(all.size() >= 10, "R01 and the gallery have lamps (%d)" % all.size())
	var at_base: bool = all.all(func(p: Array) -> bool: return step_of(p[1]) == base_step(p[0], p[1]))
	check(at_base, "at year 0 every lamp shows its base pick")
	var tends: int = all.filter(func(p: Array) -> bool: return (p[1] as VariantSocket).get_children(true).any(func(c: Node) -> bool: return c is LampTend)).size()
	check(tends == all.size(), "every lamp has a LampTend (%d of %d)" % [tends, all.size()])
	# Tend one reachable R01 lantern: under the west gallery.
	var lantern := room.get_node("Lights/lantern_hanging3") as Node3D
	var socket: VariantSocket = lantern.find_children("SOCKET_lamp_state*", "VariantSocket", true, false).front()
	var tend: LampTend = socket.get_children(true).filter(func(c: Node) -> bool: return c is LampTend).front()
	check(tend != null and tend.global_position.y > 4.15 + 0.5 and tend.global_position.y < 4.15 + 3.0, "the lantern over the west gallery is within reach from the gallery (glass y %.2f)" % (tend.global_position.y if tend != null else -1.0))
	check(tend.collision_layer == 2 and tend.collision_mask == 0, "LampTend is on the interaction layer only")
	if not tend.is_lit():
		tend.interact(null, Vector3.ZERO)
	check(tend.is_lit() and tend.interaction_prompt(Vector3.ZERO) == "Douse the lamp", "lit, it offers 'Douse the lamp'")
	tend.interact(null, Vector3.ZERO)
	check(socket.picked_label() == "dark" and tend.interaction_prompt(Vector3.ZERO) == "Light the lamp", "doused, it's dark and offers 'Light the lamp'")
	tend.interact(null, Vector3.ZERO)
	var tended_id: String = room.room_key() + "/" + room.socket_key(socket)
	check(socket.picked_label() == "lit" and str(ws.call("delta", tended_id).get("label", "")) == "lit", "lit again, and the save remembers it")
	# Mark one other lamp ageless.
	var ageless: Array = all.filter(func(p: Array) -> bool: return p[1] != socket and not room.is_ageless(p[1]) and base_step(p[0], p[1]) == 0).front()
	(ageless[1] as VariantSocket).set_meta("ageless", true)
	var other_before: Dictionary = others(room)
	var gallery_before: Dictionary = others(room.get_node("StackGallery"))
	# 40 years.
	ws.call("advance_years", 40.0)
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		r.refresh_aging()
	var forward: bool = true
	var dark: int = 0
	var untouched: int = 0
	var states: Dictionary = {}
	for p: Array in all:
		var s: VariantSocket = p[1]
		states[(p[0] as RoomTemplate).socket_key(s) + "@" + (p[0] as RoomTemplate).room_key()] = s.picked_label()
		if s == socket or p == ageless or room.is_ageless(s):
			continue
		untouched += 1
		forward = forward and step_of(s) >= base_step(p[0], s)
		if s.picked_label() == "dark":
			dark += 1
	check(forward, "after 40 years every untouched lamp is at its base step or further along")
	check(dark * 2 >= untouched, "and at least half have gone dark (%d of %d)" % [dark, untouched])
	check(socket.picked_label() == "lit", "the tended lamp is still lit")
	check((ageless[1] as VariantSocket).picked_label() == "lit", "an ageless lamp is still lit")
	var chandeliers: Array = all.filter(func(p: Array) -> bool: return room.is_ageless(p[1]) and (p[1] as VariantSocket).has_meta("ageless") == false)
	check(chandeliers.size() == 2 and chandeliers.all(func(p: Array) -> bool: return (p[1] as VariantSocket).picked_label() == "lit"), "R01's two chandeliers (ageless in the scene) are still lit")
	check(others(room) == other_before and others(room.get_node("StackGallery")) == gallery_before, "no non-lamp socket changed")
	# The same years give the same lamps.
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		r.refresh_aging()
	var again: bool = true
	for p: Array in all:
		again = again and states[(p[0] as RoomTemplate).socket_key(p[1]) + "@" + (p[0] as RoomTemplate).room_key()] == (p[1] as VariantSocket).picked_label()
	check(again, "aging again at the same years changes nothing")
	# A janitor's revert: the tended lamp goes back to what the years made it.
	var aged_to: int = room.aged_index(socket, tended_id, base_step(room, socket))
	ws.call("revert", tended_id)
	var expect: String = socket.socket_set.entries[aged_to].label if aged_to >= 0 else ["lit", "failing", "dark"][base_step(room, socket)]
	check(socket.picked_label() == expect, "reverting a tended lamp shows its aged state (%s, expected %s)" % [socket.picked_label(), expect])
