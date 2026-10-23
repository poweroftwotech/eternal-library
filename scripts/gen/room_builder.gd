class_name RoomBuilder
extends RefCounted
## Turns a marked CellGrid into kit modules (ENVIRONMENT_PLAN.md 5.5.2-5.5.3).
## Shared by every grammar: floors and ceilings per cell, an EDGE module per
## marked edge, gables at vault ends, piers at wall corners and lamps.
## What a grammar doesn't say falls back to R02's gallery (phase-5-design.md
## 5.6.1): a cell's floor_slot / ceiling_slot ("" = none), its gables, a slot
## on an OPEN edge (an arcade between hall cells), grid.posts (a slot for
## a wall corner's post, or a post on any corner, even the host's) and a prop
## with "shell": true (architecture listed with the props).
## Every pick is seeded by what is being decided (slot + grid key), never by
## call order, and every node is named by its grid key, so socket paths stay
## stable for a layout.


## Adds the modules under `shell` and free dressing (grid.props) under
## `dressing` (or `shell`); returns them.
static func build(shell: Node3D, grid: CellGrid, rules: ModuleRules, styles: PackedStringArray,
		seed_value: int, dressing: Node3D = null) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for entry: Array in plan(shell, grid, rules, styles, seed_value, dressing):
		out.append(place(entry))
	return out


## Every module build() would add, in its order, as [holder, scene, node name,
## transform], nothing instantiated yet: the streamer places them a few at a
## time (place()), so a big room needn't be built in one frame.
static func plan(shell: Node3D, grid: CellGrid, rules: ModuleRules, styles: PackedStringArray,
		seed_value: int, dressing: Node3D = null) -> Array:
	var out: Array = []
	if rules == null:
		push_warning("RoomBuilder: no ModuleRules")
		return out
	for c: Vector3i in grid.cells:
		var cell: Dictionary = grid.cells[c]
		var n: String = CellGrid.cell_name(c)
		var floor_slot: String = cell.get("floor_slot", "cell:floor")
		if floor_slot != "":
			_place(out, shell, rules, styles, seed_value, floor_slot, n, "floor_" + n, CellGrid.cell_transform(c, cell.get("floor_run", Vector3i(0, 0, 1))))
		var ceiling: String = cell.get("ceiling_slot", "cell:ceiling_cross" if cell["kind"] == "corner" else "cell:ceiling")
		if ceiling != "":
			_place(out, shell, rules, styles, seed_value, ceiling, n, "vault_" + n, CellGrid.cell_transform(c, cell["run"]))
	var posts: Dictionary = {}       # corner key -> room-space point
	var host_corners: Dictionary = {}
	for k: String in grid.edges:
		var e: Dictionary = grid.edges[k]
		var mark: int = e["mark"]
		var ends: Array[Vector3] = CellGrid.edge_ends(e["cell"], e["side"])
		if mark == CellGrid.Mark.DOOR and e["host"]:
			for p: Vector3 in ends:
				host_corners[_corner_key(p)] = true
			continue          # the host's own module stands here
		if mark == CellGrid.Mark.OPEN:
			if e.get("slot", "") != "":      # an arcade between two cells of a hall
				_place(out, shell, rules, styles, seed_value, e["slot"], k, "edge_" + k, CellGrid.edge_transform(e["cell"], e["side"]))
			continue
		var slot: String = "edge:solid" if mark == CellGrid.Mark.SOLID else ("edge:opening" if mark == CellGrid.Mark.OPENING else "edge:door")
		if e.get("slot", "") != "" and rules.rule_for(e["slot"], styles) != null:
			slot = e["slot"]
		_place(out, shell, rules, styles, seed_value, slot, k, "edge_" + k, CellGrid.edge_transform(e["cell"], e["side"]))
		for p: Vector3 in ends:
			posts[_corner_key(p)] = p
	# Gables close a vault where it ends at a wall or an own door: a barrel at
	# its two ends, a groin vault (corner) on every side.
	for c: Vector3i in grid.cells:
		if not grid.cells[c].get("gables", true):
			continue
		var ends: Array[int] = CellGrid.ALL_SIDES if grid.cells[c]["kind"] == "corner" else CellGrid.run_ends(grid.cells[c]["run"])
		for side: int in ends:
			var e: Dictionary = grid.edge(c, side)
			if e.is_empty() or e["mark"] == CellGrid.Mark.OPEN or (e["mark"] == CellGrid.Mark.DOOR and e["host"]):
				continue
			var k: String = CellGrid.key(c, side)
			_place(out, shell, rules, styles, seed_value, "gable", k, "gable_" + k, CellGrid.edge_transform(c, side))
	for ck: String in grid.posts:
		if not posts.has(ck):
			posts[ck] = _corner_point(ck)     # a free-standing post (a hall's column)
	for ck: String in posts:
		if host_corners.has(ck) and not grid.posts.has(ck):
			continue          # the host's pier is already on its wall line
		_place(out, shell, rules, styles, seed_value, grid.posts.get(ck, "post"), ck, "post_" + ck, Transform3D(Basis(), posts[ck]))
	for c: Vector3i in grid.lamps:
		var n: String = CellGrid.cell_name(c)
		var at: Vector3 = CellGrid.cell_centre(c) + Vector3(0, float(grid.lamps[c]), 0)
		_place(out, shell, rules, styles, seed_value, "lamp", n, "lamp_" + n, Transform3D(Basis(), at))
	for k: String in grid.props:
		var prop: Dictionary = grid.props[k]
		var holder: Node3D = shell if prop.get("shell", false) or dressing == null else dressing     # shell: architecture placed as dressing (a hall's upper wall band)
		_place(out, holder, rules, styles, seed_value, prop["slot"], k, "prop_" + k, prop["xf"])
	return out


## Node name of a grid corner at floor level (x and z in bays).
static func _corner_key(p: Vector3) -> String:
	return "%d_%d_%d" % [roundi(p.x / CellGrid.BAY), roundi(p.y / CellGrid.BAY), roundi(-p.z / CellGrid.BAY)]


## The room-space point of a corner key.
static func _corner_point(ck: String) -> Vector3:
	var p: PackedStringArray = ck.split("_")
	return Vector3(p[0].to_int() * CellGrid.BAY, p[1].to_int() * CellGrid.BAY, -p[2].to_int() * CellGrid.BAY)


## Picks a module for `slot` (seeded by slot and key) and records it for place().
static func _place(out: Array, shell: Node3D, rules: ModuleRules, styles: PackedStringArray,
		seed_value: int, slot: String, key: String, node_name: String, xf: Transform3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, slot, key])
	var scene: PackedScene = rules.pick(slot, styles, rng)
	if scene == null:
		push_warning("RoomBuilder: no module for %s (styles %s)" % [slot, styles])
		return
	out.append([shell, scene, node_name, xf])


## Instantiates one planned module under its holder; returns it.
static func place(entry: Array) -> Node3D:
	var node := (entry[1] as PackedScene).instantiate() as Node3D
	node.name = entry[2]
	node.transform = entry[3]
	(entry[0] as Node3D).add_child(node)
	return node
