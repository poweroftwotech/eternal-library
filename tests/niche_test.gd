extends SceneTree
## Room rework step 2: the working niches, in the real game (main.tscn) on the
## Reading Room with a stack gallery off all three doors.
##   godot --headless --path . --script res://tests/niche_test.gd -- --save=user://test/niche.json --fresh
## Over seeds 1-8: the galleries' alcoves hold every niche kind (hearth,
## garden, larder, art) and the shelf bays some wall niches; a niche lamp is
## lit. In the game: E on a forage patch adds it to the satchel once and
## shrinks it; E on a hearth's pot opens the cooking panel; standing by a
## hearth warms you, and away from it does not.

const SCENE: String = "res://rooms/test/reading_room_r02_three.tscn"
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL ", what)


func run() -> void:
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = SCENE
	var kinds: Dictionary = {}          # alcove niche kinds seen
	var wall: Dictionary = {}           # wall niche (recess) kinds seen
	var tried: Dictionary = {}          # mechanics checked once each
	for s: int in SEEDS:
		GeneratedRoom.seed_override = s
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.hud.toast_time = 0
		for _i: int in 120:
			await process_frame
		var room := game.world as RoomTemplate
		for n: Node in room.find_children("prop_niche_*", "", true, false):
			kinds[n.scene_file_path.get_file().get_basename()] = true
			# A garden or larder hangs a lamp over its alcove, and it is lit.
			var lamp: Node = room.find_child("lamp_" + str(n.name).trim_prefix("prop_niche_"), true, false)
			if lamp != null:
				var lit: bool = false
				for l: Node in lamp.find_children("*", "Light3D", true, false):
					lit = lit or (l as Light3D).visible
				check(lit, "seed %d: the lamp over %s is lit" % [s, n.name])
		var things: Array[NicheThing] = []
		for n: Node in room.find_children("*", "NicheThing", true, false):
			things.append(n as NicheThing)
		for n: Node in room.find_children("recess_*", "", true, false):
			var k: String = n.scene_file_path.get_file().get_basename()
			if k in ["recess_hearth", "recess_herbs", "recess_pantry"]:
				wall[k] = true
		for t: NicheThing in things:
			if t.kind != "pot" and not tried.has(t.kind):
				tried[t.kind] = true
				var before: int = int(game.inventory[t.kind])
				game.interact(t)
				check(int(game.inventory[t.kind]) == before + 1, "seed %d: E on a %s patch adds one (%d -> %d)" % [s, t.kind, before, game.inventory[t.kind]])
				check(t.taken and t.collision_layer == 0, "seed %d: the %s patch is taken and out of reach" % [s, t.kind])
				var v := t.get_node(t.visual) as Node3D
				check(v.scale.x < 0.2, "seed %d: the %s patch shrinks to a stub" % [s, t.kind])
				game.interact(t)
				check(int(game.inventory[t.kind]) == before + 1, "seed %d: a taken %s patch gives nothing more" % [s, t.kind])
			elif t.kind == "pot" and not tried.has("pot"):
				tried["pot"] = true
				game.interact(t)
				check(game.modal_context == "pot", "seed %d: E on the pot opens the cooking panel (%s)" % [s, game.modal_context])
				game.close_panel()
				# Warmth: by the fire it rises; 6 m away it doesn't.
				game.player.global_position = t.global_position + t.global_basis.z * 1.2 - Vector3(0, t.global_position.y, 0)
				game.warmth = 50.0
				for _i: int in 60:
					await process_frame
				check(game.warmth > 50.0, "seed %d: standing by a hearth warms you (%.2f)" % [s, game.warmth])
				game.player.global_position = Vector3(6, 0, -10)
				var w: float = game.warmth
				check(not NicheThing.warmed(self, game.player.global_position), "seed %d: the middle of the hall is not by a hearth" % s)
				for _i: int in 30:
					await process_frame
				check(game.warmth <= w, "seed %d: away from a hearth warmth doesn't rise" % s)
		game.queue_free()
		for _i: int in 3:
			await process_frame
	print("niche_test: alcove niches seen %s; wall niches seen %s" % [kinds.keys(), wall.keys()])
	for k: String in ["niche_hearth", "niche_garden", "niche_larder"]:
		check(kinds.has(k), "an alcove holds a %s over seeds 1-8" % k)
	check(kinds.keys().any(func(k: String) -> bool: return k.begins_with("niche_art")), "an alcove holds art over seeds 1-8")
	check(not wall.is_empty(), "some shelf bay is a wall niche over seeds 1-8")
	for k: String in ["herb", "root", "mushroom", "pot"]:
		check(tried.has(k), "a %s was found to try" % k)
	print("niche_test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
