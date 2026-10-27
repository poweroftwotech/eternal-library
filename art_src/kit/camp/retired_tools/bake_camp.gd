extends SceneTree
## Bakes the camp from kit pieces (phase 7 step 2,
## docs/environment/camp-rebuild-approval.md) to rooms/camp/camp.tscn:
##   godot --headless --path . --script res://tools/bake_camp.gd [-- --out=<path>] [--all-shadows]
## --all-shadows keeps every light's shadow as the old camp had it (to compare).
## Every piece of art_src/kit/camp/pieces.json (cut by tools/camp_extract.gd,
## kit/modules/camp/) is placed where it was cut from. The living parts are
## taken from the old camp as it builds (scripts/world.gd, without its gorge
## view) and saved as they are: the environment, the lights (at most four
## casting shadows: the fire, the garden's light and the two lanterns nearest
## the hearth, Q4), the fire's particles and the drifting leaves, the steam
## and flame cards, the water, the gatherables' plants, reflection probes.
## The root runs scripts/camp/camp_room.gd, which keeps them moving.
## The scene is yours after this: re-baking overwrites it.

const Cut = preload("res://tools/camp_cut.gd")
const World = preload("res://scripts/world.gd")
const OUT: String = "res://rooms/camp/camp.tscn"
## The lanterns allowed shadows (Q4): this many nearest the hearth.
const SHADOWED_LANTERNS: int = 2


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var all_shadows: bool = OS.get_cmdline_user_args().has("--all-shadows")
	var out: String = OUT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	World.with_gorge = false
	var world: Node3D = World.new()
	root.add_child(world)
	await process_frame
	var camp := Node3D.new()
	camp.name = "Camp"
	camp.set_script(load("res://scripts/camp/camp_room.gd"))
	camp.set("hearth", world.hearth)
	var counts: Dictionary = {}
	var pieces := _group(camp, "Pieces")
	for piece: Dictionary in Cut.load_pieces():
		if piece.get("drop", false):
			continue      # what a change covered: cut, so it's gone
		var inst: Node3D = (load("res://kit/modules/camp/%s.tscn" % piece["name"]) as PackedScene).instantiate()
		inst.name = piece["name"]
		inst.transform = Cut.frame(piece)
		pieces.add_child(inst)
		inst.owner = camp
		counts["pieces"] = int(counts.get("pieces", 0)) + 1
	_balustrades(camp, counts)
	_front_door(camp, counts)
	var env: WorldEnvironment = world.find_children("*", "WorldEnvironment", true, false)[0]
	_take(camp, camp, env, counts, "environment")
	# Lights: what the atmosphere moves, tagged for camp_room.gd.
	var atmos: Object = world.atmosphere
	var lantern_energy: Dictionary = {}
	for d: Dictionary in atmos.lanterns:
		lantern_energy[d["node"]] = [d["energy"], d["origin"]]
	var lanterns: Array = lantern_energy.keys()
	lanterns.sort_custom(func(a: Light3D, b: Light3D) -> bool: return a.global_position.distance_to(world.hearth) < b.global_position.distance_to(world.hearth))
	var lights := _group(camp, "Lights")
	for n: Node in world.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		var copy: Light3D = _take(camp, lights, l, counts, "lights")
		var shadow: bool = false
		if l == world.fire_light:
			copy.set_meta("camp_light", "fire")
			copy.set_meta("base_energy", atmos.fire_energy)
			shadow = true
		elif l == atmos.hearth_bounce:
			copy.set_meta("camp_light", "bounce")
		elif lantern_energy.has(l):
			copy.set_meta("camp_light", "lantern")
			copy.set_meta("base_energy", lantern_energy[l][0])
			copy.set_meta("origin", lantern_energy[l][1])
			shadow = lanterns.find(l) < SHADOWED_LANTERNS
		elif l == atmos.garden_light:
			copy.set_meta("camp_light", "garden")
			copy.set_meta("base_energy", atmos.garden_energy)
			copy.set_meta("origin", atmos.garden_origin)
			camp.set("garden_aim", atmos.garden_aim)
			shadow = true
		copy.shadow_enabled = l.shadow_enabled and (shadow or all_shadows)
		if copy.shadow_enabled:
			counts["shadowed"] = int(counts.get("shadowed", 0)) + 1
	var particles := _group(camp, "Particles")
	for n: Node in world.find_children("*", "GPUParticles3D", true, false):
		_take(camp, particles, n as Node3D, counts, "particles")
	var effects := _group(camp, "Effects")
	for e: Dictionary in world.effects:
		var copy: Node3D = _take(camp, effects, e["node"], counts, "effects")
		copy.set_meta("effect_kind", e["kind"])
		copy.set_meta("effect_origin", e["origin"])
		copy.set_meta("effect_phase", e["phase"])
	var water := _group(camp, "Water")
	for n: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.is_visible_in_tree() and mi.material_override is ShaderMaterial and not Cut.is_foliage(mi.material_override):
			_take(camp, water, mi, counts, "water")
	var plants := _group(camp, "Gatherables")
	for id: String in world.gatherables:
		var v: Node3D = _take(camp, plants, world.gatherables[id]["visual"], counts, "gatherables")
		v.name = id
		v.set_meta("kind", world.gatherables[id]["kind"])
	# The interactions (the pot, the patches), as they are: CampRoom.harvest
	# and main.interact use them as the old camp's.
	var acts := _group(camp, "Interactions")
	for n: Node in world.get_children():
		if n is StaticBody3D and n.has_method("get_interaction_id"):
			var b: Node = _take(camp, acts, n, counts, "interactions")
			b.name = n.name
	var probes := _group(camp, "Probes")
	for n: Node in world.find_children("*", "VisualInstance3D", true, false):
		if not n is GeometryInstance3D and not n is Light3D:
			_take(camp, probes, n as Node3D, counts, "probes")
	# The gallery's doorway onto the passage and the balcony: those stand on
	# the gorge's floor, which this camp doesn't draw (Q2: a closed door). It's
	# the door to the Gorge (step 4): it glows with the gorge's light, and
	# walking in arrives at the Overlook's door back (main.cross).
	var door := Threshold.new()
	door.name = "Threshold_gorge"
	door.to = "gorge"
	door.position = GALLERY_DOOR
	camp.add_child(door)
	door.owner = camp
	# The doorway's floor was the gorge passage's (vista.gd): a sill of the
	# gallery's stone from the slab's end (z -13.1) to the glow, under the door.
	var sill := MeshInstance3D.new()
	sill.name = "DoorwaySill"
	sill.mesh = BoxMesh.new()
	(sill.mesh as BoxMesh).size = Vector3(3.6, .4, 1.3)
	sill.material_override = load("res://kit/materials/camp_sandstone.tres")
	sill.position = GALLERY_DOOR + Vector3(0, -.2, -.1 - .65)
	var sill_body := StaticBody3D.new()
	var sill_shape := CollisionShape3D.new()
	sill_shape.shape = BoxShape3D.new()
	(sill_shape.shape as BoxShape3D).size = (sill.mesh as BoxMesh).size
	sill_body.add_child(sill_shape)
	sill.add_child(sill_body)
	camp.add_child(sill)
	for n: Node in [sill, sill_body, sill_shape]:
		n.owner = camp
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(-1.05, .08, 9.2)     # the box-art framing (main.gd's camp start)
	camp.add_child(spawn)
	spawn.owner = camp
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var packed := PackedScene.new()
	var err: Error = packed.pack(camp)
	if err == OK:
		err = ResourceSaver.save(packed, out)
	print("bake_camp: %s %s; %s" % [out, "saved" if err == OK else "FAILED " + error_string(err), counts])
	camp.free()
	quit(0 if err == OK else 1)


## The kit's balustrade (the Overlook's: balusters on a plinth under a rail,
## square newels at the ends), on the gallery's open edge and pitched along
## both sides of the stair, straddling its edges. A pitched piece keeps its
## balusters upright (its X runs up the flight); its own collision would be
## sheared, so it's taken off and a guard of the same shape stands instead.
const PARAPET: String = "res://kit/modules/walls/chasm_parapet_4m.tscn"
const PARAPET_LEN: float = 4.0
const PARAPET_H: float = 1.1
## The stair: its foot, width, run (toward -Z) and rise, as world.gd builds it.
const STAIR_FOOT := Vector3(2.5, 0, -3.4)
const STAIR_W: float = 1.8
const STAIR_RUN: float = 5.9
const STAIR_RISE: float = 2.2
const GALLERY_Y: float = 2.2
const GALLERY_EDGE_Z: float = -9.3
## Newels as the Overlook's (ChasmGrammar._newels): a post and a cap.
const NEWEL: float = .55
## The gallery's doorway (world.gd's arch), -Z out of the camp toward the gorge.
const GALLERY_DOOR := Vector3(-1.0, 2.2, -13.2)


func _balustrades(camp: Node3D, counts: Dictionary) -> void:
	var g := _group(camp, "Balustrades")
	var scene: PackedScene = load(PARAPET)
	# The gallery: from the west wall to the stair (into the newel at its top),
	# and east of the stair's top.
	for run: Vector2 in [Vector2(-9.1, -6.9), Vector2(-6.9, -2.9), Vector2(-2.9, 1.35), Vector2(3.6, 4.8)]:
		var k: float = (run.y - run.x) / PARAPET_LEN
		var xf := Transform3D(Basis().scaled(Vector3(k, 1, 1)), Vector3(run.x, GALLERY_Y, GALLERY_EDGE_Z))
		var piece: Node3D = _place(camp, g, scene, xf, is_equal_approx(k, 1.0), counts)
		if not is_equal_approx(k, 1.0):
			_guard(camp, piece, xf)     # a shortened one: its own collision would be squashed
	# The stair's sides, 0.19 out from its edges (the plinth half on the steps),
	# between the newels' faces: from the foot newels' backs to the top
	# newels' fronts, so the rail runs into a post's side, never through it.
	var slope: float = STAIR_RISE / STAIR_RUN
	var top := STAIR_FOOT + Vector3(0, STAIR_RISE, -STAIR_RUN)
	var line_z: float = GALLERY_EDGE_Z - .19     # the gallery balustrade's middle, where the top newels stand
	var lo := STAIR_FOOT + Vector3(0, NEWEL * .5 * slope, -NEWEL * .5)
	var hi := top + Vector3(0, -(line_z + NEWEL * .5 - top.z) * slope, line_z + NEWEL * .5 - top.z)
	var up := (hi - lo) / PARAPET_LEN
	var west := Vector3(-STAIR_W * .5 - .19, 0, 0)
	var east := Vector3(STAIR_W * .5 + .19, 0, 0)
	# Each runs so its -Z faces the steps: the west one down from the top, the east one up from the foot.
	var pitched: Array = [Transform3D(Basis(-up, Vector3.UP, Vector3(-1, 0, 0)), hi + west),
		Transform3D(Basis(up, Vector3.UP, Vector3(1, 0, 0)), lo + east)]
	for xf: Transform3D in pitched:
		var piece: Node3D = _place(camp, g, scene, xf, false, counts)
		_guard(camp, piece, xf)
	# Newels on the balustrades' middles (0.19 in from their outer faces). The
	# foot ones stand 0.15 taller: the rail arrives there 0.1 up the flight.
	var mid := Vector3(.19, 0, 0)
	var newels: Array[Vector3] = [Vector3(-6.9, GALLERY_Y, line_z), Vector3(-2.9, GALLERY_Y, line_z),
		Vector3(top.x - STAIR_W * .5, GALLERY_Y, line_z), Vector3(top.x + STAIR_W * .5, GALLERY_Y, line_z),
		STAIR_FOOT + west + mid + Vector3(0, .15, 0), STAIR_FOOT + east - mid + Vector3(0, .15, 0)]
	var stone: Material = load("res://kit/materials/gorge_sandstone.tres")
	var cap: Material = load("res://kit/materials/gorge_limestone.tres")
	for p: Vector3 in newels:
		var post := MeshInstance3D.new()
		post.mesh = BoxMesh.new()
		(post.mesh as BoxMesh).size = Vector3(NEWEL, 1.4, NEWEL)
		post.material_override = stone
		post.position = p + Vector3(0, .45, 0)
		var head := MeshInstance3D.new()
		head.mesh = BoxMesh.new()
		(head.mesh as BoxMesh).size = Vector3(NEWEL + .1, .1, NEWEL + .1)
		head.material_override = cap
		head.position = Vector3(0, .75, 0)
		post.add_child(head)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = (post.mesh as BoxMesh).size
		body.add_child(shape)
		post.add_child(body)
		g.add_child(post)
		for n: Node in [post, head, body, shape]:
			n.owner = camp
		counts["newels"] = int(counts.get("newels", 0)) + 1


func _place(camp: Node3D, parent: Node3D, scene: PackedScene, xf: Transform3D, collide: bool, counts: Dictionary) -> Node3D:
	var piece: Node3D = scene.instantiate()
	piece.transform = xf
	if not collide:
		for b: Node in piece.find_children("*", "CollisionObject3D", true, false):
			b.get_parent().remove_child(b)
			b.free()
	parent.add_child(piece)
	piece.owner = camp
	counts["balustrades"] = int(counts.get("balustrades", 0)) + 1
	return piece


## A pitched balustrade's guard: a convex slab over its plinth, rail high.
func _guard(camp: Node3D, piece: Node3D, xf: Transform3D) -> void:
	var pts := PackedVector3Array()
	for x: float in [0.0, PARAPET_LEN]:
		for y: float in [0.0, PARAPET_H]:
			for z: float in [-.38, 0.0]:
				pts.append(xf * Vector3(x, y, z))
	var body := StaticBody3D.new()
	body.name = "Guard"
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	shape.shape = hull
	body.add_child(shape)
	piece.get_parent().add_child(body)
	body.owner = camp
	shape.owner = camp


## The doorway in the front wall (world.gd): the glowing exit every area's
## unjoined doorway has (gen/modules/exit_glow.tscn), and a connector, so
## the camp can join another area there.
const DOORWAY := Transform3D(Basis(Vector3.UP, PI), Vector3(7.0, 0, 12.4))


func _front_door(camp: Node3D, counts: Dictionary) -> void:
	var glow: Node3D = (load("res://gen/modules/exit_glow.tscn") as PackedScene).instantiate()
	glow.name = "FrontDoorGlow"
	glow.transform = DOORWAY
	for l: Node in glow.find_children("*", "Light3D", true, false):
		(l as Light3D).shadow_enabled = false     # Q4: four shadowed lights
	glow.scene_file_path = ""     # plain nodes: an instance wouldn't keep the light's change
	camp.add_child(glow)
	glow.owner = camp
	for c: Node in glow.find_children("*", "", true, false):
		c.owner = camp
	var conns := _group(camp, "Connectors")
	var m := Marker3D.new()
	m.name = "SNAP_exit_front"
	m.transform = DOORWAY
	m.add_to_group(&"room_connector", true)
	conns.add_child(m)
	m.owner = camp
	counts["doorways"] = 1

func _group(camp: Node3D, name: String) -> Node3D:
	var g := Node3D.new()
	g.name = name
	camp.add_child(g)
	g.owner = camp
	return g


## A copy of `n` (and what's under it) under `parent`, where `n` stands.
func _take(camp: Node3D, parent: Node, n: Node, counts: Dictionary, what: String) -> Node:
	var copy: Node = n.duplicate()
	parent.add_child(copy)
	if copy is Node3D and n is Node3D:
		(copy as Node3D).global_transform = (n as Node3D).global_transform
	copy.owner = camp
	for c: Node in copy.find_children("*", "", true, false):
		c.owner = camp
	counts[what] = int(counts.get(what, 0)) + 1
	return copy
