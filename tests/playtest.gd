extends SceneTree
## Exercises physical exploration and the small gathering/cooking scaffold.
var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle(frames: int = 4) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await settle(12)
	check(game.player.is_on_floor(),"Arrival stands on a collision-enabled floor")
	check(not game.hud.modal_open,"Environment is visible immediately on launch")
	var start: Vector3 = game.player.position
	Input.action_press("forward")
	await settle(40)
	Input.action_release("forward")
	check(game.player.position.distance_to(start)>1.2,"WASD advances the player")
	# Traverse multiple irregular rows to detect capsule snagging on new paving.
	game.player.teleport(Vector3(4.7,.20,8.5),0,0)
	await settle(12)
	Input.action_press("forward")
	await settle(110)
	Input.action_release("forward")
	await settle(8)
	check(game.player.position.z<3.0,"Player crosses uneven paving without getting stuck on slab edges")
	check(game.player.is_on_floor() and game.player.position.y<.25,"Raised paving supports the player at the surface")
	game.show_menu()
	var paused: Vector3 = game.player.position
	Input.action_press("forward")
	await settle(10)
	Input.action_release("forward")
	check(game.player.position.distance_to(paused)<.01,"Menus block player movement")
	game.close_panel()
	# Ray targets the pot's actual collision body from a usable approach.
	game.player.teleport(Vector3(.5,.08,6.6))
	game.look_toward(game.world.hearth+Vector3(0,.8,0))
	await settle()
	var target = game.player.get_target()
	check(target != null and target.get_interaction_id()=="pot","Pot is reachable by interaction ray")
	check(not game.cook("broth"),"Cooking rejects a recipe without ingredients")
	# Inspect a real ingredient patch with a downward first-person ray.
	game.player.teleport(Vector3(.6,.08,-2.5))
	game.look_toward(Vector3(.6,.4,-4.3))
	await settle()
	target = game.player.get_target()
	check(target != null and target.get_interaction_id()=="root_a","Garden ingredient is reachable by interaction ray")
	for id in ["root_a","herb_a","mushroom_a"]:
		game.interact(game.world.gatherables[id].body)
	check(game.inventory.root==1 and game.inventory.herb==1 and game.inventory.mushroom==1,"Harvesting adds the matching ingredients")
	game.interact(game.world.gatherables.root_a.body)
	check(game.inventory.root==1,"A patch cannot be harvested twice")
	check(game.world.gatherables.root_a.body.collision_layer==0,"Harvested patch no longer intercepts interaction rays")
	check(game.cook("broth"),"Root and herb produce broth")
	check(game.inventory.root==0 and game.inventory.herb==0,"Cooking consumes exactly the required ingredients")
	check(not game.cook("roast"),"Prepared meal cannot be silently overwritten")
	game.nourishment = 30
	game.warmth = 30
	check(game.eat(),"A prepared meal can be eaten")
	check(game.nourishment==70 and game.warmth==55,"Broth gives its stated nourishment and warmth")
	check(not game.eat(),"An eaten meal cannot be consumed twice")
	check(game.cook("roast") and game.eat(),"Mushrooms support the second preparation")
	# Walk up the physical stair ramp into the upper gallery.
	game.player.teleport(Vector3(2.5,.08,-2.8),0,0)
	await settle(8)
	Input.action_press("forward")
	await settle(175)
	Input.action_release("forward")
	check(game.player.position.y>2.0 and game.player.position.z< -9.3,"The upper gallery is reachable by walking up the stairs")
	check(game.visited_gallery,"Reaching the gallery records the exploration landmark")
	# Walk through the actual gallery opening and corridor, not a teleport to the vista.
	game.player.teleport(Vector3(-1,2.25,-11.1),0,0)
	await settle(6)
	Input.action_press("forward")
	await settle(270)
	Input.action_release("forward")
	check(game.player.position.z< -23 and game.player.position.y>2.1,"Gallery doorway and passage lead to the balcony on foot")
	check(game.visited_balcony,"Walking onto the balcony discovers the Eternal Library overlook")
	Input.action_press("forward")
	await settle(150)
	Input.action_press("jump")
	await settle(45)
	Input.action_release("jump")
	Input.action_release("forward")
	check(game.player.position.z> -27.7 and game.player.position.y>2,"Balcony front guard contains walking and jumping")
	game.player.teleport(Vector3(-6.5,2.25,-24),PI/2,0)
	await settle(5)
	Input.action_press("forward")
	await settle(80)
	Input.action_release("forward")
	check(game.player.position.x> -6.85,"Balcony side guard prevents leaving the playable area")
	for p in [Vector3(0,1,5),Vector3(-1,1,-4),Vector3(8,1,-5),Vector3(-1,3,-24)]:
		var query = PhysicsRayQueryParameters3D.create(p,p+Vector3(0,30,0),1)
		var hit = game.world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),"A physical ceiling closes the interior above %s" % p)
	for offset in [Vector3(10,12,0),Vector3(-15,12,0),Vector3(0,12,15),Vector3(0,12,-15)]:
		var p = Vector3(-1,1.6,-4)
		var hit = game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+offset,1))
		check(not hit.is_empty(),"Upper garden walls close the roof seam in direction %s" % offset)
	check(game.world.vista.extent>260 and game.world.vista.extent<350 and game.world.vista.bank_count==8,"Eight overlapping banks form a compact library gorge")
	check(game.world.vista.shelf_bays>600,"Inhabited ledges carry dense three-dimensional book arcades")
	check(game.world.vista.bridge_count==6 and game.world.vista.waterfall_count==4,"The exterior contains crossing bridges and four layered cascades")
	check(game.world.vista.tier_count>100 and game.world.vista.max_tier_height<12 and game.world.vista.profile_variation>5,"Short tiers change their footprints instead of forming long straight shafts")
	check(game.world.library_dressing.case_count>=15 and game.world.library_dressing.art_count>=6,"Interior walls carry high collections and framed art")
	# Check movement cannot walk through the tree's visible trunk.
	game.player.teleport(Vector3(-4,.08,-4.6),0,0)
	await settle(4)
	Input.action_press("forward")
	await settle(45)
	Input.action_release("forward")
	check(game.player.position.z> -5.6,"Tree trunk has a physical collision volume")
	game.show_notes()
	check(game.hud.modal_text.text.contains("Amberroot"),"Field notes describe ingredients and the route")
	game.close_panel()
	check(game.world.art.batch_count>3000,"Detailed books and foliage use shared instance batches")
	var merged: int = 0
	for child in game.world.get_children():
		if str(child.name).begins_with("MergedStatic_"):
			merged += 1
	# Interior, exterior and distant enclosure are separate light layers.
	# Shared materials therefore form additional groups instead of leaking fill light.
	check(merged>10 and merged<100,"Static geometry remains merged with isolated exterior light layers")
	print("Static material/layer groups: %d" % merged)
	check(game.world.get_node("ExteriorVaultBounce").light_cull_mask==2,"Vault bounce is restricted to exterior geometry")
	game.queue_free()
	await settle(20)
	if failures.is_empty():
		print("PASS: %d gameplay integration checks." % checks)
		quit(0)
	else:
		print("FAIL: %d / %d checks: %s" % [failures.size(),checks,failures])
		quit(1)
