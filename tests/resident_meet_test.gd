extends SceneTree
## You and the residents (phase 21 step 3, Q6): they are solid, they walk
## round you where there is room, and where there isn't (a doorway) they wait
## until you move. Headless:
##   godot --headless --audio-driver Dummy --path . --script res://tests/resident_meet_test.gd
## 1. Every spot of every home and of the lane can be walked to from the hauz.
## 2. You stand in the open square on the cook's way to the hauz: she gets
##    there all the same and never comes closer than CLEAR.
## 3. You stand in the scholar's doorway as he sets out: he waits, and says
##    so; you move, and he goes.
## 4. You can't walk through someone standing: the game's own body test.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
const STEP_S: float = 0.1
## Nearer than this, middle to middle, is walking into you.
const CLEAR: float = 0.55

var fails: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		fails.append(what)


func run() -> void:
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = 1
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	for _i: int in 30:
		await process_frame
	var area: Area = game.world
	while area.streamer.busy():
		await process_frame
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	for _i: int in 900:
		await process_frame
		if residents != null and residents.settled():
			break
	if residents == null or residents.people.is_empty():
		print("resident_meet_test: FAIL, nobody lives on the lane")
		quit(1)
		return
	var player: CharacterBody3D = game.player
	player.set_physics_process(false)
	var clock: DayClock = DayClock.it()
	clock.paused = true
	clock.speed = 1.0
	var ways: WalkMap = residents.ways
	var who: Dictionary = {}
	for p: Resident in residents.people:
		who[p.trade] = p

	# 1. Every spot can be walked to.
	var hauz: Vector3 = Vector3.ZERO
	for s: Dictionary in residents.commons:
		if s["kind"] == "water":
			hauz = s["at"]
	var spots: int = 0
	var unreached: PackedStringArray = []
	for h: Dictionary in residents.households:
		var anchor: Vector3 = ((h["members"] as Array)[0] as Resident).home["anchor"]
		for s: Dictionary in (h["spots"] as Array) + residents.commons:
			spots += 1
			var foot: Vector3 = ways.approach(s["at"], anchor)
			var off: float = Vector2(foot.x - (s["at"] as Vector3).x, foot.z - (s["at"] as Vector3).z).length()
			if ways.walk_length(hauz, foot) > 80.0 or off > 1.0:
				unreached.append("%s of home %d (%.1f m from the floor)" % [s["kind"], h["index"], off])
	check(unreached.is_empty(), "all %d spots can be walked to from the hauz, each within 1 m of floor %s" % [spots, unreached])

	# 2. In the open, they walk round you.
	var cook: Resident = who["cook"]
	player.global_position = Vector3(0, 0, 40)
	_set_off(residents, clock, cook, "water")
	check(cook.walking and cook.doing == "water", "the cook sets off for water (%s)" % cook.doing)
	var stand: Vector3 = _open_point(cook.route, hauz)
	player.global_position = stand
	var nearest: float = INF
	var took: float = 0.0
	while cook.walking and took < 120.0:
		clock.time += STEP_S
		residents.advance(STEP_S, clock)
		took += STEP_S
		nearest = minf(nearest, Vector2(cook.global_position.x - stand.x, cook.global_position.z - stand.z).length())
	check(not cook.walking, "with you standing on her way at %s she reaches the hauz (%.0f s)" % [stand.snapped(Vector3.ONE * 0.1), took])
	check(nearest >= CLEAR, "and never comes nearer you than %.2f m (%.2f)" % [CLEAR, nearest])
	check(nearest < 2.5, "(you really were on her way: she passed within %.1f m)" % nearest)

	# 3. In a doorway, they wait for you.
	var scholar: Resident = who["scholar"]
	var house: Dictionary = {}
	for h: Dictionary in residents.households:
		if (h["members"] as Array).has(scholar):
			house = h
	player.global_position = Vector3(0, 0, 40)
	_set_off(residents, clock, scholar, "work")
	scholar.arrive_now()
	player.global_position = house["doorway"]
	_set_off(residents, clock, scholar, "water")
	check(scholar.walking and scholar.doing == "water", "the scholar sets off for water (%s)" % scholar.doing)
	nearest = INF
	for _i: int in 400:
		clock.time += STEP_S
		residents.advance(STEP_S, clock)
		nearest = minf(nearest, Vector2(scholar.global_position.x - player.global_position.x, scholar.global_position.z - player.global_position.z).length())
	check(scholar.walking and scholar.waiting_for == "you", "40 s on, with you in his doorway, he is waiting for you (walking %s, waiting for '%s')" % [scholar.walking, scholar.waiting_for])
	check(nearest >= CLEAR, "and has not walked into you (%.2f m)" % nearest)
	check(scholar.describe(clock.bells()).contains("waiting for you"), "his label says so")
	player.global_position = Vector3(0, 0, 40)
	took = 0.0
	while scholar.walking and took < 60.0:
		clock.time += STEP_S
		residents.advance(STEP_S, clock)
		took += STEP_S
	check(not scholar.walking, "you move, and he goes to the hauz (%.0f s)" % took)

	# 4. Solid.
	var keeper: Resident = who["stall keeper"]
	_set_off(residents, clock, keeper, "keep")
	keeper.arrive_now()
	check((player.collision_mask & Resident.LAYER) != 0, "your body collides with the people's layer")
	var beside: Vector3 = ways.nearest(keeper.global_position + Vector3(1.2, 0.0, 0.0))
	beside.y = keeper.global_position.y + 0.1
	player.global_position = beside
	for _i: int in 4:
		await physics_frame
	var toward: Vector3 = keeper.global_position - beside
	toward.y = 0.0
	check(player.test_move(player.global_transform, toward), "walking at someone standing, you are stopped")
	check(not player.test_move(player.global_transform, -toward.normalized() * 0.2), "and walking away, you are not")
	print("resident_meet_test: %d checks, %s" % [checks, "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size()])
	main_script.room_override = ""
	quit(0 if fails.is_empty() else 1)


# Puts the clock at the start of `p`'s first block of `activity` and lets
# them set off (one tick).
func _set_off(residents: Residents, clock: DayClock, p: Resident, activity: String) -> void:
	for row: Array in p.blocks:
		if str(row[1]) == activity:
			clock.time = fposmod(float(row[0]) + p.shift, float(DayClock.BELLS)) * DayClock.BELL_S + 0.5
			break
	residents.advance(0.0, clock)


# A point of the way that is out in the open: the middle of its longest
# stretch near the hauz.
func _open_point(route: PackedVector3Array, hauz: Vector3) -> Vector3:
	var best: Vector3 = route[0]
	var best_len: float = 0.0
	for i: int in range(1, route.size() - 1):
		var mid: Vector3 = (route[i - 1] + route[i]) * 0.5
		var length: float = route[i - 1].distance_to(route[i])
		if mid.distance_to(hauz) < 9.0 and mid.distance_to(hauz) > 2.0 and length > best_len:
			best_len = length
			best = mid
	return Vector3(best.x, 0.0, best.z)
