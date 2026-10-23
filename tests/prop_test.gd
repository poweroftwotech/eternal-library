extends SceneTree
## Phase 3 slice 1 gate (ENVIRONMENT_PLAN.md 6.5.8): WorldProp wake, sleep,
## re-freeze, the active-body budget, breaking, shards and props layers.
##   godot --headless --path . --script res://tests/prop_test.gd
## Builds a floor and props in memory; nothing is saved.

const VASE: String = "res://props/prop_vase_floor.tscn"
const BROKEN: String = "res://props/prop_vase_floor_broken.tscn"
const TABLE_PROPS: Array[String] = ["prop_book_stack", "prop_book_open", "prop_pot", "prop_oil_lamp", "prop_scroll", "prop_inkwell"]

var failures: PackedStringArray = []
var checks: int = 0
var stage: Node3D


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	check_scenes()
	await check_rest()
	await check_knock_over()
	await check_drops()
	await check_riders()
	await check_budget()
	print("prop_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## A fresh stage with a 20 x 20 m floor (layer 1) whose top is y = 0.
func new_stage() -> void:
	if stage != null:
		stage.queue_free()
		await process_frame
	WorldProp.awake_props.clear()
	stage = Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	stage.add_child(floor_body)


func spawn(path: String, at: Vector3) -> WorldProp:
	var p: WorldProp = (load(path) as PackedScene).instantiate() as WorldProp
	stage.add_child(p)
	p.global_position = at
	return p


func frames(n: int) -> void:
	for _i: int in n:
		await physics_frame


## Waits until `done` returns true or `limit` physics frames pass; returns whether it did.
func wait_for(done: Callable, limit: int) -> bool:
	for _i: int in limit:
		if done.call():
			return true
		await physics_frame
	return done.call()


func tilt(p: Node3D) -> float:
	return rad_to_deg(p.global_basis.y.normalized().angle_to(Vector3.UP))


func check_scenes() -> void:
	var vase: Node = (load(VASE) as PackedScene).instantiate()
	check(vase is WorldProp, "the floor vase is a WorldProp")
	if vase is WorldProp:
		var v := vase as WorldProp
		check(v.breakable and v.broken_scene != null and v.prompt == "Knock over", "the vase breaks into its shards scene and says 'Knock over'")
	vase.free()
	var shards: Node = (load(BROKEN) as PackedScene).instantiate()
	check(shards is Shards, "the broken vase is a Shards root")
	check(WorldProp.meshes_under(shards).size() == 8, "the broken vase has 8 shards (%d)" % WorldProp.meshes_under(shards).size())
	shards.free()
	var set_res: SocketSet = load("res://kit/sockets/table_props.tres")
	var all_props: bool = true
	for e: SocketEntry in set_res.entries:
		var n: Node = e.scene.instantiate()
		all_props = all_props and n is WorldProp
		n.free()
	check(all_props, "every table_props candidate is a WorldProp")


## Every prop frozen on its layers, with a hull and object-space materials, and
## still after a second at rest.
func check_rest() -> void:
	await new_stage()
	var props: Array[WorldProp] = [spawn(VASE, Vector3(0, 0, 0))]
	for i: int in TABLE_PROPS.size():
		props.append(spawn("res://props/%s.tscn" % TABLE_PROPS[i], Vector3(1.0 + i * 0.6, 0, 2)))
	await frames(2)
	for p: WorldProp in props:
		var hull: bool = p.get_children(true).any(func(c: Node) -> bool: return c is CollisionShape3D and (c as CollisionShape3D).shape is ConvexPolygonShape3D)
		check(p.freeze and p.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC, "%s is frozen static at rest" % p.name)
		check(p.collision_layer == 1 << 2 and p.collision_mask == (1 | 1 << 2), "%s is on layer 3 (props), mask world + props" % p.name)
		check(hull, "%s has a convex hull" % p.name)
		var world_mapped: PackedStringArray = WorldProp.world_mapped_materials(p)
		check(world_mapped.is_empty(), "%s has no world-mapped material %s" % [p.name, world_mapped])
	var before: Array = props.map(func(p: WorldProp) -> Transform3D: return p.global_transform)
	await frames(60)
	var after: Array = props.map(func(p: WorldProp) -> Transform3D: return p.global_transform)
	check(before == after and WorldProp.awake_props.is_empty(), "nothing moves or wakes at rest")
	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	stage.add_child(player)
	check(player.collision_layer == 1 << 3 and player.collision_mask == (1 | 1 << 2 | 1 << 7), "the player is on layer 4 and collides with the world, props and the player-only walls (8)")
	check(player.ray.collision_mask == 7, "the interaction ray sees world, interaction targets and props")


## E on the vase, aimed high, tips it over; it breaks or lies on its side, and
## everything freezes again within a few seconds.
func check_knock_over() -> void:
	await new_stage()
	var vase: WorldProp = spawn(VASE, Vector3.ZERO)
	await frames(2)
	var actor := Node3D.new()
	stage.add_child(actor)
	actor.global_position = Vector3(0, 1.62, 1.6)
	var woke: Array[bool] = [false]
	vase.woke.connect(func() -> void: woke[0] = true)
	var pieces: Array[Node3D] = [null]
	vase.broke.connect(func(s: Node3D) -> void: pieces[0] = s)
	check(vase.interaction_prompt(Vector3.ZERO) == "Knock over", "the vase prompts 'Knock over'")
	vase.interact(actor, Vector3(0, 0.75, 0.2))
	check(woke[0] and not vase.freeze, "E wakes the vase")
	var done: bool = await wait_for(func() -> bool: return pieces[0] != null or not is_instance_valid(vase) or vase.freeze, 600)
	if pieces[0] != null:
		print("prop_test: knocked over, the vase broke")
		var shards := pieces[0] as Shards
		var settled: bool = await wait_for(func() -> bool: return shards.all_frozen, 900)
		check(settled, "the shards all freeze again")
		var low: float = INF
		for b: RigidBody3D in shards.pieces:
			low = minf(low, b.global_position.y)
		check(low > -0.05, "no shard sinks into the floor (lowest centre %.3f)" % low)
	else:
		check(done and is_instance_valid(vase), "the vase settles and freezes again")
		if is_instance_valid(vase):
			print("prop_test: knocked over, the vase lies at %.0f degrees" % tilt(vase))
			check(tilt(vase) > 60.0, "one push tips the vase over (tilt %.0f)" % tilt(vase))
			check(vase.freeze and not WorldProp.awake_props.has(vase), "it leaves the awake list when it freezes")


## Dropped from 1.5 m the vase breaks; set down from 3 cm it doesn't.
func check_drops() -> void:
	await new_stage()
	var high: WorldProp = spawn(VASE, Vector3(0, 1.5, 0))
	var low: WorldProp = spawn(VASE, Vector3(3, 0.03, 0))
	await frames(2)
	var broke: Array[Node3D] = [null, null]
	high.broke.connect(func(s: Node3D) -> void: broke[0] = s)
	low.broke.connect(func(s: Node3D) -> void: broke[1] = s)
	high.wake()
	low.wake()
	await wait_for(func() -> bool: return broke[0] != null and (not is_instance_valid(low) or low.freeze), 600)
	check(broke[0] != null, "a vase dropped from 1.5 m breaks")
	check(broke[1] == null and is_instance_valid(low), "a vase set down from 3 cm doesn't")
	if broke[0] != null:
		var shards := broke[0] as Shards
		check(shards.pieces.size() == 8, "the broken vase leaves 8 pieces")
		var settled: bool = await wait_for(func() -> bool: return shards.all_frozen, 900)
		check(settled, "the dropped vase's shards freeze again")
		var near: bool = shards.pieces.all(func(b: RigidBody3D) -> bool: return Vector2(b.global_position.x, b.global_position.z).length() < 2.5 and b.global_position.y > -0.05)
		check(near, "the shards land near where the vase fell, on the floor")


## Pushing a crate wakes the pot standing on it.
func check_riders() -> void:
	await new_stage()
	var crate := WorldProp.new()
	crate.mass = 8.0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.5, 0.6)
	mesh.mesh = box
	mesh.position.y = 0.25
	crate.add_child(mesh)
	stage.add_child(crate)
	var pot: WorldProp = spawn("res://props/prop_pot.tscn", Vector3(0, 0.5, 0))
	await frames(2)
	crate.push(Vector3(1.5, 0, 0) * crate.mass, crate.global_position + Vector3(0, 0.25, 0))
	await frames(3)
	check(not pot.freeze, "pushing a crate wakes the pot on top of it")


## Past the budget, the oldest prop that is already asleep freezes early.
func check_budget() -> void:
	await new_stage()
	var tight := PropSettings.new()
	tight.active_budget = 3
	tight.sleep_refreeze_s = 100.0
	var props: Array[WorldProp] = []
	for i: int in 4:
		var p: WorldProp = (load("res://props/prop_book_stack.tscn") as PackedScene).instantiate() as WorldProp
		p.settings = tight
		stage.add_child(p)
		p.global_position = Vector3(i * 1.0, 0, 0)
		props.append(p)
	await frames(2)
	for i: int in 3:
		props[i].wake()
	var asleep: bool = await wait_for(func() -> bool: return props[0].sleeping and props[1].sleeping and props[2].sleeping, 300)
	check(asleep, "three woken props at rest go to sleep")
	check(WorldProp.awake_props.size() == 3 and props.slice(0, 3).all(func(p: WorldProp) -> bool: return not p.freeze), "three props are awake under a budget of 3")
	props[3].wake()
	check(props[0].freeze and not props[1].freeze and not props[2].freeze and not props[3].freeze,
		"waking a fourth freezes the oldest sleeping one (frozen: %s)" % [props.map(func(p: WorldProp) -> bool: return p.freeze)])
	check(WorldProp.awake_props.size() == 3, "the awake list stays at the budget (%d)" % WorldProp.awake_props.size())
