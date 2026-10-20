@tool
class_name ShelfFill
extends MultiMeshInstance3D
## Books for a shelf recess as one MultiMesh (ENVIRONMENT_PLAN.md 4.3 SHELF_FILL).
## Origin = the recess socket (recess centre, floor level, wall boundary). The
## default shelf levels match M_wall_shelfbay_4m. Seeded by the socket via the
## "seed" meta, so a room rebuilds the same books every time.

## Top surface of each shelf board, in metres above the floor.
@export var shelf_levels: PackedFloat32Array = [0.17, 0.59, 1.01, 1.43]
@export var half_width: float = 1.44
## z of the shelf back (books stand against it) and the shelf front.
@export var back_z: float = 0.22
@export var front_z: float = -0.24
@export_range(0.0, 1.0, 0.01) var density: float = 0.9
## Collapsed recess: most books lie on the floor and spill into the room. Spill
## in front of the wall face settles onto whatever is below it after the first
## physics frames: the hall floor, a gallery slab, a stair, or the floor of
## the storey below for an upper recess with nothing in front (step 4.0 of the
## weathering slice). Child meshes named "*__spill*" (broken boards) settle too.
@export var fallen: bool = false
## Wall face in socket space (the room is -Z): only spill in front of it settles.
@export var face_z: float = -0.3
## Spill rays start this high above the socket floor and reach this far down.
@export var settle_from: float = 0.65
@export var settle_drop: float = 12.0
@export var palette: PackedColorArray = [
	Color(0.48, 0.17, 0.13), Color(0.17, 0.25, 0.42), Color(0.42, 0.29, 0.12), Color(0.18, 0.36, 0.29),
	Color(0.54, 0.42, 0.17), Color(0.29, 0.16, 0.29), Color(0.64, 0.33, 0.23), Color(0.78, 0.71, 0.54)]

static var _material: StandardMaterial3D
## Instance transforms of the last build(), kept on the CPU: MultiMesh data
## lives in the rendering server and reads back empty under the headless
## dummy renderer, so Validate Room measures these instead.
var built_transforms: Array[Transform3D] = []
## Instance colours and shelf level (-1 = spill or a lore band) of the last build().
var built_colors: Array[Color] = []
var book_levels: PackedInt32Array = []
## Spill instance index -> height of its origin above the surface it rests on.
var spill_rest: Dictionary[int, float] = {}
## Lore books on this fill (from the room's lore_books for this socket),
## appended after the random books so a pin never moves another book.
var lore: Array[LoreBookPin] = []
## Instance index of each lore book, by item id; its gilt band is the next index.
var lore_index: Dictionary = {}
## Instances taken off the shelf (index -> true): pulled out or carried away.
var hidden: Dictionary = {}

## A book was pulled half out (E) and is now a WorldProp (ENVIRONMENT_PLAN.md 6.5.4).
signal pulled(book: WorldProp, index: int)

const LORE_SIZE := Vector3(0.075, 0.34, 0.22)     # a little taller than most; the gap under a board is 0.37
## The leather map multiplies the instance colour, so the gilt band and the
## lore spine are tinted above 1 to read as gold and as a cleaner colour.
const BAND_COLOUR := Color(3.2, 2.4, 0.9)
const LORE_SHINE: float = 2.2
const HIGHLIGHT_OUT: float = 0.02
const PULL_OUT: float = 0.45      # share of a book's depth a pull slides it out

var _highlight: int = -1
var _highlight_frame: int = 0
static var _book_materials: Dictionary = {}     # colour -> object-space material


func _ready() -> void:
	var socket := get_parent() as VariantSocket
	var room: Node = socket.room() if socket != null else null
	if room is RoomTemplate and not fallen:
		lore = (room as RoomTemplate).lore_pins_for((room as RoomTemplate).socket_key(socket))
	build(int(get_meta("seed", 7)))
	if fallen:
		_settle_when_ready()
	elif not Engine.is_editor_hint():
		_add_reach()
	set_process(false)


func build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var levels: PackedInt32Array = []
	var keep: float = density * (0.25 if fallen else 1.0)
	spill_rest.clear()
	hidden.clear()
	lore_index.clear()
	for k: int in shelf_levels.size():
		var level: float = shelf_levels[k]
		var x: float = -half_width
		while x < half_width - 0.05:
			var w: float = rng.randf_range(0.04, 0.09)
			var h: float = rng.randf_range(0.24, 0.36)
			var d: float = rng.randf_range(0.17, 0.23)
			if rng.randf() > keep:
				x += w * rng.randf_range(1.0, 4.0)
				continue
			var lean: float = 0.0 if rng.randf() > 0.08 else rng.randf_range(-0.25, 0.25)
			var basis := Basis(Vector3.FORWARD, lean).scaled(Vector3(w, h, d))
			xforms.append(Transform3D(basis, Vector3(x + w * 0.5, level + h * 0.5, back_z - d * 0.5)))
			colors.append(palette[rng.randi() % palette.size()] * rng.randf_range(0.8, 1.15))
			levels.append(k)
			x += w + 0.004
	if fallen:
		# Inset by a rotated book's reach (<= 0.18 m) so spill stays inside the opening.
		var reach: float = half_width - 0.18
		for i: int in rng.randi_range(25, 45):
			var w: float = rng.randf_range(0.14, 0.24)
			var t: float = rng.randf_range(0.03, 0.07)
			var d: float = rng.randf_range(0.18, 0.26)
			# Draw order x, height, z as before, so existing seeds keep their layout.
			var px: float = rng.randf_range(-reach, reach)
			var rest: float = t * 0.5 + rng.randf() * 0.12 * float(i % 3)
			var p := Vector3(px, rest, rng.randf_range(front_z - 0.9, back_z - 0.1))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, t, d))
			spill_rest[xforms.size()] = rest
			xforms.append(Transform3D(basis, p))
			colors.append(palette[rng.randi() % palette.size()] * rng.randf_range(0.7, 1.0))
			levels.append(-1)
	for pin: LoreBookPin in lore:
		if pin == null or pin.item == null or pin.level >= shelf_levels.size():
			continue
		# Books in the lore book's slot step aside (shrunk to nothing; indices stay).
		for i: int in xforms.size():
			if levels[i] == pin.level and absf(xforms[i].origin.x - pin.x) < (xforms[i].basis.x.length() + LORE_SIZE.x) * 0.5 + 0.004:
				xforms[i] = _gone(xforms[i])
		var base := Vector3(pin.x, shelf_levels[pin.level], back_z)
		lore_index[pin.item.id] = xforms.size()
		xforms.append(Transform3D(Basis().scaled(LORE_SIZE), base + Vector3(0, LORE_SIZE.y * 0.5, -LORE_SIZE.z * 0.5)))
		colors.append(pin.item.spine_colour * LORE_SHINE)
		levels.append(pin.level)
		var band := LORE_SIZE + Vector3(0.006, -LORE_SIZE.y + 0.035, 0.006)
		xforms.append(Transform3D(Basis().scaled(band), base + Vector3(0, LORE_SIZE.y * 0.68, -LORE_SIZE.z * 0.5)))
		colors.append(BAND_COLOUR)
		levels.append(-1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	multimesh = mm
	built_transforms = xforms
	built_colors = colors
	book_levels = levels
	material_override = book_material()


static func book_material() -> StandardMaterial3D:
	if _material == null:
		var base: Material = PxMaterial.get_or_create("book_leather")
		_material = (base.duplicate() if base != null else StandardMaterial3D.new()) as StandardMaterial3D
		_material.vertex_color_use_as_albedo = true
		_material.resource_name = "book_leather_tinted"
	return _material


## Bodies join the physics space only after a physics step, so wait two.
func _settle_when_ready() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		settle()


## Rests spill in front of the wall face on the first surface below it.
## Returns how many items moved.
func settle() -> int:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var moved: int = 0
	for i: int in spill_rest:
		var xf: Transform3D = built_transforms[i]
		if xf.origin.z > face_z:
			continue      # still inside the recess
		var y: Variant = _surface_below(space, xf.origin.x, xf.origin.z)
		if y == null:
			continue
		xf.origin.y = float(y) + spill_rest[i]
		built_transforms[i] = xf
		multimesh.set_instance_transform(i, xf)
		moved += 1
	for mesh: MeshInstance3D in spill_meshes():
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		var centre: Vector3 = box.get_center()
		if centre.z > face_z:
			continue
		var y: Variant = _surface_below(space, centre.x, centre.z)
		if y == null:
			continue
		mesh.global_position += global_basis.y.normalized() * (float(y) - box.position.y)
		moved += 1
	return moved


## Meshes under this fill named "*__spill*" (floor-lying parts of a candidate).
func spill_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in find_children("*__spill*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Socket-space height of the first collision surface below (x, z), or null.
func _surface_below(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var from: Vector3 = global_transform * Vector3(x, settle_from, z)
	var to: Vector3 = global_transform * Vector3(x, -settle_drop, z)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return to_local(hit["position"]).y if not hit.is_empty() else null


# --- book promotion (ENVIRONMENT_PLAN.md 6.5.4) ----------------------------------
# A thin box per shelf on the interaction layer lets the player's ray find a
# book; nothing spawns from looking. E pulls the book half out as a frozen
# WorldProp; a lore book can then be taken, an ordinary one pulled off.

## The ray target: one box per shelf level, just over the book spines.
class Reach extends StaticBody3D:
	var fill: ShelfFill

	func interaction_prompt(hit: Vector3) -> String:
		return fill.prompt_at(hit)

	func interact(_actor: Node3D, hit: Vector3) -> void:
		var i: int = fill.book_at(hit)
		if i >= 0:
			fill.pull(i)


func _add_reach() -> void:
	var reach := Reach.new()
	reach.name = "Reach"
	reach.fill = self
	reach.collision_layer = 2      # interaction targets only: never blocks movement
	reach.collision_mask = 0
	for k: int in shelf_levels.size():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(half_width * 2.0, 0.4, back_z)
		shape.shape = box
		shape.position = Vector3(0, shelf_levels[k] + 0.2, back_z * 0.5)
		reach.add_child(shape)
	add_child(reach, false, Node.INTERNAL_MODE_FRONT)


## The book nearest a point on the shelf (global), or -1.
func book_at(hit: Vector3) -> int:
	var p: Vector3 = to_local(hit)
	var level: int = -1
	for k: int in shelf_levels.size():
		if p.y >= shelf_levels[k] - 0.02 and p.y < shelf_levels[k] + 0.42:
			level = k
	if level < 0:
		return -1
	var best: int = -1
	for i: int in built_transforms.size():
		if book_levels[i] != level or hidden.has(i) or built_transforms[i].basis.x.length() < 0.01:
			continue
		if best < 0 or absf(built_transforms[i].origin.x - p.x) < absf(built_transforms[best].origin.x - p.x):
			best = i
	return best if best >= 0 and absf(built_transforms[best].origin.x - p.x) < 0.15 else -1


## The HUD prompt for the book at `hit`; also highlights it (slid out 2 cm).
func prompt_at(hit: Vector3) -> String:
	var i: int = book_at(hit)
	_set_highlight(i)
	if i < 0:
		return ""
	var item: ItemDef = lore_item(i)
	return "Pull out %s" % item.display_name if item != null else "Pull out a book"


## The ItemDef of the lore book at instance i, or null.
func lore_item(i: int) -> ItemDef:
	for pin: LoreBookPin in lore:
		if pin != null and pin.item != null and lore_index.get(pin.item.id, -1) == i:
			return pin.item
	return null


func _set_highlight(i: int) -> void:
	_highlight_frame = Engine.get_process_frames()
	if i == _highlight:
		return
	if _highlight >= 0 and not hidden.has(_highlight):
		_place(_highlight, built_transforms[_highlight])
	_highlight = i
	if i >= 0:
		_place(i, built_transforms[i].translated(Vector3(0, 0, -HIGHLIGHT_OUT)))
	set_process(i >= 0)


func _process(_delta: float) -> void:
	if _highlight >= 0 and Engine.get_process_frames() - _highlight_frame > 1:
		_set_highlight(-1)


## Moves instance i (and a lore book's band with it) in the MultiMesh.
func _place(i: int, xf: Transform3D) -> void:
	var shift: Vector3 = xf.origin - built_transforms[i].origin
	multimesh.set_instance_transform(i, xf)
	if lore_item(i) != null:
		multimesh.set_instance_transform(i + 1, built_transforms[i + 1].translated(shift))


static func _gone(xf: Transform3D) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin)


## Takes instance i off the shelf (its index stays: it's the save id).
func hide_book(i: int) -> void:
	if i < 0 or i >= built_transforms.size():
		return
	if _highlight == i:
		_highlight = -1
	hidden[i] = true
	multimesh.set_instance_transform(i, _gone(built_transforms[i]))
	if lore_item(i) != null:
		multimesh.set_instance_transform(i + 1, _gone(built_transforms[i + 1]))


## Puts instance i back on the shelf (a janitor's revert).
func unhide_book(i: int) -> void:
	hidden.erase(i)
	_place(i, built_transforms[i])


## Replaces instance i with a frozen WorldProp in the same slot (its original
## place). The caller positions it; pull() slides it half out.
func make_book(i: int) -> WorldProp:
	var xf: Transform3D = built_transforms[i]
	var size := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
	var item: ItemDef = lore_item(i)
	var book := WorldProp.new()
	book.name = "Book%d" % i
	book.mass = 0.5
	book.item = item
	book.pull_toward = true
	book.prompt = "Pull off"
	book.set_meta("shelf_index", i)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = book_prop_material(built_colors[i])
	book.add_child(mesh)
	if item != null:
		var band := MeshInstance3D.new()
		var band_box := BoxMesh.new()
		band_box.size = built_transforms[i + 1].basis.get_scale()
		band.mesh = band_box
		band.position = built_transforms[i + 1].origin - xf.origin
		band.material_override = gilt_material()
		book.add_child(band)
	book.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	hide_book(i)
	add_child(book, false, Node.INTERNAL_MODE_BACK)
	return book


## E on a book: it slides half out over a quarter second and rests there,
## sticking out of the shelf, frozen.
func pull(i: int) -> WorldProp:
	var book: WorldProp = make_book(i)
	var out: Vector3 = book.transform.origin + Vector3(0, 0, -built_transforms[i].basis.z.length() * PULL_OUT)
	var tween: Tween = create_tween()
	tween.tween_property(book, "position", out, 0.25)
	tween.finished.connect(func() -> void: pulled.emit(book, i))
	return book


## Plain book leather in one colour, mapped in object space (a book that moves).
static func book_prop_material(colour: Color) -> StandardMaterial3D:
	var key: String = colour.to_html()
	if not _book_materials.has(key):
		var mat := book_material().duplicate() as StandardMaterial3D
		mat.vertex_color_use_as_albedo = false
		mat.albedo_color = colour
		mat.uv1_world_triplanar = false
		_book_materials[key] = mat
	return _book_materials[key]


static var _gilt: StandardMaterial3D

## A pulled lore book's gilt band: plain metallic gold (no leather map).
static func gilt_material() -> StandardMaterial3D:
	if _gilt == null:
		_gilt = StandardMaterial3D.new()
		_gilt.resource_name = "lore_gilt"
		_gilt.albedo_color = Color(0.86, 0.64, 0.25)
		_gilt.metallic = 0.2
		_gilt.roughness = 0.45
		_gilt.emission_enabled = true     # a faint glint, so it reads in a dim recess
		_gilt.emission = Color(0.86, 0.64, 0.25)
		_gilt.emission_energy_multiplier = 0.25
	return _gilt
