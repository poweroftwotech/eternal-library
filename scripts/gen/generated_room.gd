@tool
class_name GeneratedRoom
extends RoomTemplate
## A room built from a RoomGrammar and ModuleRules (ENVIRONMENT_PLAN.md 5.5).
## It is a RoomTemplate, so sockets, pins, style groups, claims, Validate Room
## and the game's room loading work on it as on an authored room.
##
## Placed under a host room with `join_connector` set, it moves itself so its
## entry door meets that connector face to face, keeps out of the host's
## modules and takes the host's build for `inherit_style_groups`.
##
## Generated nodes carry the meta `generated` and have no owner, so they are
## never saved: the scene file holds only this node and its settings. In the
## editor, Generate rebuilds and any change to the grammar or rules
## regenerates live; Overlay shows the cell grid and edge marks.

## The entry door: the S side of cell (0, 0, 0), centred, -Z pointing out.
const ENTRY := Transform3D(Basis(Vector3.UP, PI), Vector3(2, 0, 0))
const OVERLAY_COLOURS: Dictionary = {
	CellGrid.Mark.SOLID: Color(0.62, 0.62, 0.66),
	CellGrid.Mark.OPENING: Color(0.2, 0.85, 0.8),
	CellGrid.Mark.DOOR: Color(1.0, 0.78, 0.2),
}

## The game sets this (menu reseed, `--gen-seed=N`) before loading; -1 = gen_seed.
static var seed_override: int = -1

@export var grammar: RoomGrammar:
	set(value):
		if grammar != null and grammar.changed.is_connected(_request):
			grammar.changed.disconnect(_request)
		grammar = value
		if grammar != null and Engine.is_editor_hint():
			grammar.changed.connect(_request)
		_request()
## Overrides the grammar's own rules when set.
@export var rules: ModuleRules:
	set(value):
		if rules != null and rules.changed.is_connected(_request):
			rules.changed.disconnect(_request)
		rules = value
		if rules != null and Engine.is_editor_hint():
			rules.changed.connect(_request)
		_request()
@export var gen_seed: int = 1:
	set(value):
		gen_seed = value
		_request()
## A connector under the host room's `Connectors` (e.g. SNAP_door_west).
## Empty: the room stays where it is (preview a grammar on its own).
@export var join_connector: StringName = &"":
	set(value):
		join_connector = value
		_request()
## Style groups whose pick comes from the host, so a joined room matches it.
@export var inherit_style_groups: PackedStringArray = ["gallery_build"]
@export_tool_button("Generate") var generate_action: Callable = generate
@export_tool_button("Reseed") var reseed_action: Callable = _reseed
## Draw the cell grid and edge marks (solid grey, opening teal, door gold).
@export var overlay: bool = false:
	set(value):
		overlay = value
		_draw_overlay()

var grid: CellGrid
var modules: Array[Node3D] = []
var _pending: bool = false
var _overlay_node: Node3D


func _ready() -> void:
	generate()


func effective_seed() -> int:
	if seed_override >= 0 and not Engine.is_editor_hint():
		return seed_override
	return gen_seed


func current_seed() -> int:
	return effective_seed()


## The room this one is placed in, if any.
func host_room() -> RoomTemplate:
	var p: Node = get_parent()
	while p != null:
		if p is RoomTemplate:
			return p as RoomTemplate
		p = p.get_parent()
	return null


func generate() -> void:
	_pending = false
	if not is_inside_tree():
		return
	clear_generated()
	var host: RoomTemplate = host_room()
	if host != null and join_connector != &"":
		_join(host)
	grid = CellGrid.new()
	if host != null:
		grid.blockers = _host_blockers(host)
	if grammar == null:
		push_warning("%s: no grammar" % name)
		return
	var s: int = effective_seed()
	grammar.layout(grid, s)
	for p: String in grid.check():
		push_warning("%s (seed %d): %s" % [name, s, p])
	var shell: Node3D = _group("Shell")
	_group("Sockets")
	_group("Connectors")
	modules = RoomBuilder.build(shell, grid, rules if rules != null else grammar.rules, grammar.styles, s)
	for m: Node3D in modules:
		m.set_meta("generated", true)
	_add_connectors()
	_add_safety_floor()
	style_overrides = {}
	if host != null:
		for g: String in inherit_style_groups:
			var idx: int = host.style_choice(g, host.current_seed())
			if idx >= 0:
				style_overrides[g] = idx
	resolve_sockets(s)
	_draw_overlay()


## Removes everything generate() made (found by meta, so it also works after
## an editor script reload).
func clear_generated() -> void:
	for holder: Node in [self, get_node_or_null("Shell"), get_node_or_null("Connectors")]:
		if holder == null:
			continue
		for child: Node in holder.get_children():
			if child.has_meta("generated"):
				holder.remove_child(child)
				child.queue_free()
	modules.clear()


## Bay count of the layout (0 before generate).
func bay_count() -> int:
	return grid.cells.size() if grid != null else 0


## Every placed module with its scene and transform, sorted: equal builds
## give equal signatures (tests, determinism).
func module_signature() -> String:
	var lines: PackedStringArray = []
	for m: Node3D in modules:
		lines.append("%s %s %s" % [m.name, m.scene_file_path.get_file(), m.transform.origin.snappedf(0.01)])
	lines.sort()
	return "\n".join(lines)


func _request() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _pending:
		return
	_pending = true
	generate.call_deferred()


func _reseed() -> void:
	gen_seed = randi() % 100000
	notify_property_list_changed()


## Moves this room so ENTRY meets the host connector face to face.
func _join(host: RoomTemplate) -> void:
	var conn := host.get_node_or_null(NodePath("Connectors/" + String(join_connector))) as Node3D
	if conn == null:
		push_warning("%s: %s has no connector %s" % [name, host.name, join_connector])
		return
	global_transform = conn.global_transform * Transform3D(Basis(Vector3.UP, PI)) * ENTRY.affine_inverse()


## Room-space bounds of the host's cells and walls. Free dressing is left out,
## and so are posts: they stand on grid corners, and their corbels reach into
## every neighbouring cell by design.
func _host_blockers(host: RoomTemplate) -> Array[AABB]:
	var out: Array[AABB] = []
	var found: Array[KitModule] = []
	KitValidateRoom._modules(host, found)
	var to_local: Transform3D = global_transform.affine_inverse()
	for m: KitModule in found:
		if m.shape == KitModule.Shape.FREE or m.shape == KitModule.Shape.POST:
			continue
		for node: Node in m.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				out.append((to_local * mi.global_transform) * mi.get_aabb())
	# Keep the bay outside each of the host's other doors clear for the rooms
	# that will join there (phase 4).
	var holder: Node = host.get_node_or_null("Connectors")
	if holder != null:
		for c: Node in holder.get_children():
			if c is Node3D and c.name != join_connector:
				var xf: Transform3D = to_local * (c as Node3D).global_transform
				var centre: Vector3 = xf.origin - xf.basis.z.normalized() * CellGrid.BAY * 0.5
				out.append(AABB(centre - Vector3(2, 0, 2), Vector3(4, CellGrid.CELL_HEIGHT, 4)))
	return out


func _group(group_name: String) -> Node3D:
	var node := get_node_or_null(group_name) as Node3D
	if node == null:
		node = Node3D.new()
		node.name = group_name
		node.set_meta("generated", true)
		add_child(node)
	return node


## A marker on every door edge, -Z pointing out of the room (the room
## connector convention). The host joint closes its bay for Validate Room.
func _add_connectors() -> void:
	var holder: Node3D = _group("Connectors")
	for k: String in grid.edges:
		var e: Dictionary = grid.edges[k]
		if e["mark"] != CellGrid.Mark.DOOR:
			continue
		var xf: Transform3D = CellGrid.edge_transform(e["cell"], e["side"])
		var marker := Marker3D.new()
		marker.name = "SNAP_entry" if e["host"] else "SNAP_exit_" + k
		marker.transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf.origin + xf.basis.x * CellGrid.BAY * 0.5)
		marker.set_meta("snap_kind", "door")
		if e["host"]:
			marker.set_meta("host_closes", true)
		marker.set_meta("generated", true)
		marker.add_to_group("room_connector", true)
		holder.add_child(marker)


## AGENTS.md: a temporary floor under unfinished areas (0.25 m under the
## floor, 4 m past the cells), as R01 has.
func _add_safety_floor() -> void:
	if grid.cells.is_empty():
		return
	var box := AABB()
	var first: bool = true
	for c: Vector3i in grid.cells:
		var cell := AABB(Vector3(c.x * CellGrid.BAY, c.y * CellGrid.BAY, -c.z * CellGrid.BAY - CellGrid.BAY), Vector3(CellGrid.BAY, 0, CellGrid.BAY))
		box = cell if first else box.merge(cell)
		first = false
	var body := StaticBody3D.new()
	body.name = "TempSafetyFloor"
	body.collision_mask = 0
	body.set_meta("generated", true)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(box.size.x + 8.0, 0.5, box.size.z + 8.0)
	shape.shape = b
	shape.position = Vector3(box.get_center().x, -0.5, box.get_center().z)
	body.add_child(shape)
	add_child(body)


func _draw_overlay() -> void:
	if _overlay_node != null:
		_overlay_node.queue_free()
		_overlay_node = null
	if not overlay or grid == null or not is_inside_tree():
		return
	_overlay_node = Node3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for c: Vector3i in grid.cells:       # cell outlines, inset 0.2 m
		var o: Vector3 = Vector3(c.x * CellGrid.BAY, c.y * CellGrid.BAY + 0.04, -c.z * CellGrid.BAY)
		var q: Array[Vector3] = [o + Vector3(0.2, 0, -0.2), o + Vector3(3.8, 0, -0.2), o + Vector3(3.8, 0, -3.8), o + Vector3(0.2, 0, -3.8)]
		for i: int in 4:
			mesh.surface_set_color(Color(0.3, 0.6, 1.0))
			mesh.surface_add_vertex(q[i])
			mesh.surface_set_color(Color(0.3, 0.6, 1.0))
			mesh.surface_add_vertex(q[(i + 1) % 4])
		var label := Label3D.new()
		label.text = "bay %d%s" % [grid.cells[c]["bay"], "\nlamp" if grid.lamps.has(c) else ""]
		label.position = CellGrid.cell_centre(c) + Vector3(0, 0.3, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.01
		_overlay_node.add_child(label)
	for k: String in grid.edges:         # edge marks, 0.4 m inside their cell
		var e: Dictionary = grid.edges[k]
		if not OVERLAY_COLOURS.has(e["mark"]):
			continue
		var xf: Transform3D = CellGrid.edge_transform(e["cell"], e["side"])
		var colour: Color = OVERLAY_COLOURS[e["mark"]]
		if e["mark"] == CellGrid.Mark.DOOR and e["host"]:
			colour = Color(1.0, 0.5, 0.15)
		for lift: float in [0.06, 0.12]:
			var a: Vector3 = xf * Vector3(0.3, lift, -0.4)
			var b: Vector3 = xf * Vector3(CellGrid.BAY - 0.3, lift, -0.4)
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(a)
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(b)
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	var lines := MeshInstance3D.new()
	lines.mesh = mesh
	lines.material_override = mat
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay_node.add_child(lines)
	add_child(_overlay_node, false, Node.INTERNAL_MODE_BACK)    # internal: never saved
