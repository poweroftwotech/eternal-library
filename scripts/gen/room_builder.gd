class_name RoomBuilder
extends RefCounted
## Turns a marked CellGrid into kit modules (ENVIRONMENT_PLAN.md 5.5.2-5.5.3).
## Shared by every grammar: floors and ceilings per cell, an EDGE module per
## marked edge, gables at vault ends, piers at wall corners and lamps.
## Every pick is seeded by what is being decided (slot + grid key), never by
## call order, and every node is named by its grid key, so socket paths stay
## stable for a layout.


## Adds the modules under `shell` and free dressing (grid.props) under
## `dressing` (or `shell`); returns them.
static func build(shell: Node3D, grid: CellGrid, rules: ModuleRules, styles: PackedStringArray,
		seed_value: int, dressing: Node3D = null) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if rules == null:
		push_warning("RoomBuilder: no ModuleRules")
		return out
	for c: Vector3i in grid.cells:
		var cell: Dictionary = grid.cells[c]
		var n: String = CellGrid.cell_name(c)
		_place(out, shell, rules, styles, seed_value, "cell:floor", n, "floor_" + n, CellGrid.cell_transform(c, Vector3i(0, 0, 1)))
		var ceiling: String = "cell:ceiling_cross" if cell["kind"] == "corner" else "cell:ceiling"
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
		var ends: Array[int] = CellGrid.ALL_SIDES if grid.cells[c]["kind"] == "corner" else CellGrid.run_ends(grid.cells[c]["run"])
		for side: int in ends:
			var e: Dictionary = grid.edge(c, side)
			if e.is_empty() or e["mark"] == CellGrid.Mark.OPEN or (e["mark"] == CellGrid.Mark.DOOR and e["host"]):
				continue
			var k: String = CellGrid.key(c, side)
			_place(out, shell, rules, styles, seed_value, "gable", k, "gable_" + k, CellGrid.edge_transform(c, side))
	for ck: String in posts:
		if host_corners.has(ck):
			continue          # the host's pier is already on its wall line
		_place(out, shell, rules, styles, seed_value, "post", ck, "post_" + ck, Transform3D(Basis(), posts[ck]))
	for c: Vector3i in grid.lamps:
		var n: String = CellGrid.cell_name(c)
		var at: Vector3 = CellGrid.cell_centre(c) + Vector3(0, float(grid.lamps[c]), 0)
		_place(out, shell, rules, styles, seed_value, "lamp", n, "lamp_" + n, Transform3D(Basis(), at))
	for k: String in grid.props:
		var prop: Dictionary = grid.props[k]
		_place(out, dressing if dressing != null else shell, rules, styles, seed_value, prop["slot"], k, "prop_" + k, prop["xf"])
	return out


## Node name of a grid corner at floor level (x and z in bays).
static func _corner_key(p: Vector3) -> String:
	return "%d_%d_%d" % [roundi(p.x / CellGrid.BAY), roundi(p.y / CellGrid.BAY), roundi(-p.z / CellGrid.BAY)]


static func _place(out: Array[Node3D], shell: Node3D, rules: ModuleRules, styles: PackedStringArray,
		seed_value: int, slot: String, key: String, node_name: String, xf: Transform3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, slot, key])
	var scene: PackedScene = rules.pick(slot, styles, rng)
	if scene == null:
		push_warning("RoomBuilder: no module for %s (styles %s)" % [slot, styles])
		return
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.transform = xf
	shell.add_child(node)
	out.append(node)
