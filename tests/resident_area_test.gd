extends SceneTree
## People in a whole area (phase 21 step 5): walks the live Mahaleh's rooms in
## turn (the player set down in each), and at each says who lives there, what
## the walking surface cost, and whether everyone is where the hour has them.
##   godot --headless --audio-driver Dummy --path . --script res://tests/resident_area_test.gd -- [--area=mahaleh] [--seed=N] [--rooms=N]
## Fails if a lived-in home has nobody, if someone stands off the walking
## surface, or if the same person is not in the same place after their room
## has gone and come back at the same hour (doing the same thing; in the same
## place too if that place is in their own room: which shop of another room
## a stall keeper keeps depends on which rooms are built).

var fails: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)


func run() -> void:
	var area_id: String = "mahaleh"
	var seed_value: int = 1
	var most: int = 6
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area_id = a.trim_prefix("--area=")
		elif a.begins_with("--seed="):
			seed_value = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--rooms="):
			most = a.trim_prefix("--rooms=").to_int()
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:" + area_id
	Area.seed_override = seed_value
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	game.player.set_physics_process(false)
	for _i: int in 60:
		await process_frame
	var area: Area = game.world
	while area.streamer.busy():
		await process_frame
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	if residents == null:
		print("resident_area_test: FAIL, the area has no Residents")
		quit(1)
		return
	var came_in: Vector3 = game.player.global_position
	var clock: DayClock = DayClock.it()
	clock.paused = true
	clock.time = 2.5 * DayClock.BELL_S
	var lived: Array[AreaPlan.Room] = []
	for q: AreaPlan.Room in area.plan.rooms:
		if q.grid != null and q.grid.meta.has("homes"):
			lived.append(q)
	print("resident_area_test: %s seed %d, %d rooms, %d with homes" % [area_id, seed_value, area.plan.rooms.size(), lived.size()])
	var seen: Dictionary = {}     # name@slot -> where they stood
	var went: int = 0
	for pass_no: int in 2:
		if pass_no == 1:
			# The rooms with homes are taken down, and come back as you come to them.
			game.player.global_position = came_in
			for q: AreaPlan.Room in lived.slice(0, most):
				if area.rooms.has(q.slot_id) and q.slot_id != area.streamer.player_room:
					area.streamer.unload(q.slot_id)
			for _i: int in 600:
				await process_frame
				if not area.streamer.busy() and _i > 30:
					break
			for q: AreaPlan.Room in lived.slice(0, most):
				if not residents.households.any(func(h: Dictionary) -> bool: return h["slot"] == q.slot_id):
					went += 1
			print("  %d of %d rooms with homes went (people left: %d)" % [went, mini(most, lived.size()), residents.people.size()])
		for q: AreaPlan.Room in lived.slice(0, most):
			var homes: Array = q.grid.meta["homes"]
			game.player.global_position = q.xf * (homes[0]["door"] as Vector3) + Vector3(0, 0.2, 0)
			var worst_ms: float = 0.0
			for _i: int in 1200:
				var t0: int = Time.get_ticks_usec()
				await process_frame
				worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - t0) / 1000.0)
				if not area.streamer.busy() and residents.settled() and area.rooms.has(q.slot_id) and residents.households.any(func(h: Dictionary) -> bool: return h["slot"] == q.slot_id):
					break
			for _i: int in 45:
				await process_frame
			# Everyone to where the hour has them (walks skipped).
			clock.speed = 60.0
			for _i: int in 3:
				residents.advance(0.1, clock)
			clock.speed = 1.0
			var here: Array = residents.households.filter(func(h: Dictionary) -> bool: return h["slot"] == q.slot_id)
			var folk: int = 0
			var off: int = 0
			var moved: int = 0
			for h: Dictionary in here:
				check(not (h["members"] as Array).is_empty(), "%s home %d: nobody" % [q.slot_id, h["index"]])
				for m: Variant in h["members"]:
					var r := m as Resident
					folk += 1
					var key: String = "%s@%s/%d" % [r.given_name, q.slot_id, h["index"]]
					if not r.away and not residents.ways.on(r.stands_at() + Vector3(0, 0.25, 0), 1.6):
						off += 1
					if pass_no == 0:
						seen[key] = [r.global_position, r.doing, r.walking or str(r.spot.get("slot", r.home_slot)) != r.home_slot]
					elif seen.has(key):
						if seen[key][1] != r.doing or (not r.walking and not bool(seen[key][2]) and str(r.spot.get("slot", r.home_slot)) == r.home_slot and (seen[key][0] as Vector3).distance_to(r.global_position) > 3.0):
							moved += 1
							print("    %s (%s): was %s at %s, is %s at %s" % [key, r.trade, seen[key][1], seen[key][0], r.doing, r.global_position])
					else:
						moved += 1
						print("    %s (%s): nobody of that name was here before" % [key, r.trade])
			check(off == 0, "%s: %d of %d stand off the walking surface" % [q.slot_id, off, folk])
			if pass_no == 1:
				check(moved == 0, "%s: %d of %d are not where they were at the same hour" % [q.slot_id, moved, folk])
			var lived_in: int = homes.filter(func(h: Dictionary) -> bool: return Residents.HOUSEHOLDS.has(h["kind"])).size()
			print("  pass %d %s (%s): %d homes, %d lived in, %d households, %d people; rooms in %d, people in all %d, links %d; surface read %.1f ms, bake %.0f ms; worst frame %.0f ms" % [
					pass_no + 1, q.slot_id, q.room_type, homes.size(), lived_in, here.size(), folk, area.rooms.size(), residents.people.size(),
					residents.links.values().filter(func(l: RID) -> bool: return l.is_valid()).size(), residents.ways.last_read_ms, residents.ways.last_bake_ms, worst_ms])
	# What a frame of everyone's day costs, the clock running.
	clock.paused = false
	var t1: int = Time.get_ticks_usec()
	for _i: int in 300:
		residents.advance(1.0 / 60.0, clock)
	var each_ms: float = (Time.get_ticks_usec() - t1) / 300000.0
	clock.paused = true
	var far_slots: int = 0
	for p: Resident in residents.people:
		if not p.spot.is_empty() and str(p.spot.get("slot", p.home_slot)) != p.home_slot:
			far_slots += 1
	print("  %d people: %.2f ms a frame for their day; %d are at a spot in another room; %d drawn, %d of them cheaply" % [residents.people.size(), each_ms, far_slots, residents.drawn, residents.cheap])
	check(each_ms < 2.0, "a frame of %d people costs %.2f ms (limit 2)" % [residents.people.size(), each_ms])
	main_script.room_override = ""
	print("resident_area_test: %d checks, %s" % [checks, "PASS" if fails.is_empty() else "%d failures" % fails.size()])
	for f: String in fails:
		print("  FAIL " + f)
	quit(0 if fails.is_empty() else 1)
