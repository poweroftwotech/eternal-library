extends SceneTree
## Probes each place's doors (ornate doors, 2026-11-01): stands before a
## door, captures it, and scans its opening with rays across the door's frame
## (x across, y up; the first hit's depth along -Z), printed as a depth map
## so a door piece can be sized to fill it. Needs a display.
##   godot --path . --resolution 1600x900 --script res://tests/door_probe.gd -- <out_prefix> [place ids…]
## Place ids: "camp" (its back door), "gorge" (its door to the Lower Stacks),
## or an area (its door out).

var game: Node
var main_script: GDScript = load("res://scripts/main.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var prefix: String = args[0] if args.size() > 0 else "user://probe"
	var ids: Array = args.slice(1) if args.size() > 1 else ["camp", "gorge", "lower_stacks", "library", "sanctum", "forgotten_wing"]
	for id: String in ids:
		main_script.room_override = "camp" if id == "camp" else "area:" + id
		if game != null:
			game.queue_free()
			await process_frame
		game = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		current_scene = game
		game.hud.toast_time = 0
		game.stats.visible = false
		await _frames(30)
		var at: Transform3D
		if id == "camp":
			var c: Node3D = game.world.get_node_or_null("Connectors/" + StratumPlan.CAMP_BACK_DOOR)
			at = c.global_transform
		else:
			var area := game.world as Area
			var to: String = "lower_stacks" if id == "gorge" else StratumPlan.current().outside_of(id)
			var door: Array = area.door_to(to)
			if door.is_empty():
				print("door_probe: %s: no door to %s" % [id, to])
				continue
			at = area.global_transform * ((door[0] as AreaPlan.Room).connectors[door[1]]["xf"] as Transform3D)
			area.streamer.target = game.player
			game.player.teleport(at * Vector3(0, .1, 4.0), at.basis.get_euler().y, -0.05)
			var slot: String = (door[0] as AreaPlan.Room).slot_id
			var stop: int = Time.get_ticks_msec() + 60000
			while (not area.rooms.has(slot) or area.streamer.busy()) and Time.get_ticks_msec() < stop:
				await process_frame
		game.player.blocked = true
		game.player.teleport(at * Vector3(0, .1, 4.0), at.basis.get_euler().y, -0.05)
		await _frames(120)
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, id])
		_scan(id, at, 0xFFFFFFFF ^ VISUAL)
		_meshes(at)
		await _frames(3)
		_scan(id, at, VISUAL)
	quit()


## Depth map of the first hits along -Z through the door's frame: one row per
## 0.1 m up, one column per 0.1 m across (x -2.4..2.4); the char is the hit's
## z in the frame (A = +1.0, each letter 0.1 m deeper; '.' = the door's own
## wall; ' ' = nothing). Then, per row, the opening's half width: out from the
## middle to the first hit 0.1 m nearer than the middle's.
func _scan(id: String, at: Transform3D, mask: int) -> void:
	print("door_probe: %s: door at %s, mask %d" % [id, at.origin.snapped(Vector3.ONE * .01), mask])
	for row: int in range(50, -1, -1):
		var y: float = row * .1 + .02
		var line: String = ""
		for c: int in range(-24, 25):
			var hit: Dictionary = _ray(at, c * .1, y, mask)
			if hit.is_empty():
				line += " "
			elif hit["collider"] is Threshold.Leaf:
				line += "."
			else:
				line += char(65 + clampi(int(round((1.0 - _z(at, hit)) * 10.0)), 0, 25))
		var mid: Dictionary = _ray(at, 0, y, mask)
		var half: String = "-"
		if not mid.is_empty():
			var zc: float = _z(at, mid)
			for i: int in range(1, 140):
				var h: Dictionary = _ray(at, i * .02, y, mask)
				var g: Dictionary = _ray(at, -i * .02, y, mask)
				if (not h.is_empty() and _z(at, h) > zc + .1) or (not g.is_empty() and _z(at, g) > zc + .1):
					half = "%.2f (middle at z %.2f)" % [i * .02, zc]
					break
		print("%4.1f |%s| %s" % [y, line, half])


func _ray(at: Transform3D, x: float, y: float, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(at * Vector3(x, y, 2.5), at * Vector3(x, y, -3.0), mask)
	q.exclude = [game.player.get_rid()]
	return game.player.get_world_3d().direct_space_state.intersect_ray(q)


func _z(at: Transform3D, hit: Dictionary) -> float:
	return (at.affine_inverse() * (hit["position"] as Vector3)).z


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


## Gives each mesh near the door a trimesh body on layer 20 (VISUAL), so a
## scan can measure the opening the kit piece draws, not its coarse collision.
const VISUAL: int = 1 << 19


func _meshes(at: Transform3D) -> void:
	var box := AABB(Vector3(-2.6, -0.5, -2.0), Vector3(5.2, 5.5, 4.0))
	var inv: Transform3D = at.affine_inverse()
	for n: Node in game.world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.name == "Glow":
			continue
		if not ((inv * mi.global_transform) * mi.mesh.get_aabb()).intersects(box):
			continue
		var body := StaticBody3D.new()
		body.collision_layer = VISUAL
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		body.add_child(cs)
		mi.add_child(body)
