@tool
class_name WorldProp
extends RigidBody3D
## A prop you can push, knock over and break (ENVIRONMENT_PLAN.md 6.2, 6.5.1).
## Frozen (static) at rest, so a room full of props costs about what static
## meshes do. It wakes when pushed (E), walked into, hit by another body, or
## when the prop under it wakes; once it has lain still for
## PropSettings.sleep_refreeze_s it freezes again. At most
## PropSettings.active_budget props are awake: past that, the oldest one
## that is already asleep freezes early.
##
## Collision is a convex hull of the meshes under it, built at load (one per
## prop scene, cached) unless the scene has its own CollisionShape3D. Library
## materials that map world-triplanar are swapped for object-space copies, so
## a moving prop's texture moves with it.
##
## Breakable props swap to broken_scene (a Shards root holding the same prop
## cut into pieces, in place) when they lose more than break_speed in one step.

signal woke
signal settled
signal broke(shards: Node3D)
## Taken into the satchel (an item); the prop is freed.
signal taken

## Collision layer 3, props (6.4); props collide with the world and each other.
const LAYER_PROPS: int = 1 << 2
const MASK: int = 1 | LAYER_PROPS

## HUD prompt when the player aims at it.
@export var prompt: String = "Push"
@export var breakable: bool = false
@export var broken_scene: PackedScene
## Speed lost in one physics step that breaks the prop (m/s); 0 = the
## PropSettings default.
@export_range(0.0, 20.0, 0.1) var break_speed: float = 0.0
## Empty = world/props/prop_settings.tres.
@export var settings: PropSettings
## An item you can take (a lore book): E puts it in the satchel (6.5.1).
@export var item: ItemDef
## E pulls it toward you instead of pushing it away (a book on a shelf).
@export var pull_toward: bool = false

## Awake props, oldest first (the budget).
static var awake_props: Array[WorldProp] = []
static var _hulls: Dictionary = {}          # scene path -> ConvexPolygonShape3D
static var _local_materials: Dictionary = {}  # world-mapped material -> object-space copy

## Transform when the prop was placed (moved props are measured against it).
var rest_transform: Transform3D
var broken: bool = false
var _still: float = 0.0
var _prev_velocity: Vector3 = Vector3.ZERO
var _prev_angular: Vector3 = Vector3.ZERO
var _pushed_frames: int = 0
var _extent: float = 0.25


func _ready() -> void:
	if settings == null:
		settings = PropSettings.default()
	if Engine.is_editor_hint():
		ensure_collision(self, scene_file_path)     # internal: shows the hull, saves nothing
		return
	collision_layer = LAYER_PROPS
	collision_mask = MASK
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	ensure_collision(self, scene_file_path)
	localize_materials(self)
	var bounds: AABB = local_bounds(self)
	_extent = maxf(bounds.size.y * 0.5, 0.05)
	# The automatic centre of mass is the body origin, which for a prop is the
	# floor under it: a vase would never tip. Use the middle of its meshes.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = bounds.get_center()
	angular_damp = settings.roll_damp
	rest_transform = transform


# --- interaction (the player's ray, ENVIRONMENT_PLAN.md 6.5.1) ----------------

func interaction_prompt(_hit: Vector3) -> String:
	return "Take %s" % item.display_name if item != null else prompt


## E: an item goes into the satchel. Otherwise push along the view, level, at
## the point aimed at (high on a tall vase, so it tips), or pull toward you.
func interact(actor: Node3D, hit: Vector3) -> void:
	if item != null:
		take()
		return
	var dir: Vector3 = hit - actor.global_position
	dir.y = 0.0
	if dir.length_squared() < 1e-6:
		return
	if pull_toward:
		push((-dir.normalized() + Vector3(0, 0.3, 0)) * settings.push_speed * mass, hit)
	else:
		push(dir.normalized() * settings.push_speed * mass, hit)


## Puts the item in the satchel (WorldState) and removes the prop.
func take() -> bool:
	var ws: Node = get_node_or_null("/root/WorldState")
	if item == null or ws == null or broken:
		return false
	ws.call("add_item", item)
	awake_props.erase(self)
	broken = true      # gone from the world: no more pushes, breaks or saves as moved
	taken.emit()
	queue_free()
	return true


func push(impulse: Vector3, at: Vector3) -> void:
	if broken:
		return
	wake()
	_pushed_frames = 2
	apply_impulse(impulse, at - global_position)


## The player walked into it at `speed` along `dir` (level); each physics step
## closes bump_share of the gap between the two speeds.
func bump(dir: Vector3, speed: float, at: Vector3) -> void:
	if broken:
		return
	wake()
	var gap: float = speed - linear_velocity.dot(dir)
	if gap > 0.0:
		_pushed_frames = 2
		apply_impulse(dir * gap * settings.bump_share * minf(mass, settings.bump_mass_cap), at - global_position)


# --- wake and sleep -----------------------------------------------------------

func wake() -> void:
	if broken or not freeze:
		return
	freeze = false
	sleeping = false
	_still = 0.0
	_prev_velocity = Vector3.ZERO
	_prev_angular = Vector3.ZERO
	_enlist()
	_wake_riders()
	woke.emit()


func refreeze() -> void:
	if freeze:
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	awake_props.erase(self)
	settled.emit()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or freeze or broken:
		return
	var speed: float = linear_velocity.length()
	var spin: float = angular_velocity.length()
	# The jolt of one step: the change of velocity, with the change of spin
	# counted at the prop's half height. Our own pushes are skipped, so only
	# what the prop hits (or what hits it) can break it.
	var jolt: float = (linear_velocity - _prev_velocity).length() + (angular_velocity - _prev_angular).length() * _extent
	_prev_velocity = linear_velocity
	_prev_angular = angular_velocity
	if _pushed_frames > 0:
		_pushed_frames -= 1
		jolt = 0.0
	if breakable and broken_scene != null and jolt > breaking_speed():
		shatter()
		return
	if sleeping or (speed < 0.04 and spin < 0.08):
		_still += delta
		if _still >= settings.sleep_refreeze_s:
			refreeze()
	else:
		_still = 0.0


func breaking_speed() -> float:
	return break_speed if break_speed > 0.0 else settings.default_break_speed


## Swaps in the broken scene, which takes over this prop's motion.
func shatter() -> Node3D:
	if broken or broken_scene == null:
		return null
	broken = true
	awake_props.erase(self)
	var pieces: Node3D = broken_scene.instantiate() as Node3D
	get_parent().add_child(pieces)
	pieces.global_transform = global_transform
	if pieces.has_method("launch"):
		pieces.call("launch", linear_velocity, angular_velocity, global_transform * center_of_mass)
	broke.emit(pieces)
	queue_free()
	return pieces


func _enlist() -> void:
	awake_props = awake_props.filter(func(p: WorldProp) -> bool: return is_instance_valid(p) and not p.freeze)
	awake_props.append(self)
	if awake_props.size() <= settings.active_budget:
		return
	for p: WorldProp in awake_props:
		if p != self and p.sleeping:
			p.refreeze()
			return


## Wakes props resting on this one (a pot on a crate), so they fall with it.
func _wake_riders() -> void:
	if not is_inside_tree():
		return
	var box: AABB = global_transform * local_bounds(self)
	var shape := BoxShape3D.new()
	shape.size = Vector3(box.size.x, 0.12, box.size.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), Vector3(box.get_center().x, box.end.y + 0.04, box.get_center().z))
	query.collision_mask = LAYER_PROPS
	query.exclude = [get_rid()]
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var other: Object = hit.get("collider")
		if other is WorldProp:
			(other as WorldProp).call_deferred("wake")


# --- shared helpers (Shards uses them too) ------------------------------------

## Adds a convex-hull CollisionShape3D (internal, never saved) over every mesh
## under `body`, unless it already has a shape. `cache_key` shares hulls
## between instances of one scene.
static func ensure_collision(body: CollisionObject3D, cache_key: String = "") -> void:
	for child: Node in body.get_children(true):
		if child is CollisionShape3D:
			return
	var hull: ConvexPolygonShape3D = _hulls.get(cache_key) if cache_key != "" else null
	if hull == null:
		var points := PackedVector3Array()
		for inst: MeshInstance3D in meshes_under(body):
			if inst.mesh == null:
				continue
			var xf: Transform3D = relative(body, inst)
			var part: Shape3D = inst.mesh.create_convex_shape(true, false)
			if part is ConvexPolygonShape3D:
				for p: Vector3 in (part as ConvexPolygonShape3D).points:
					points.append(xf * p)
		if points.is_empty():
			return
		hull = ConvexPolygonShape3D.new()
		hull.points = points
		if cache_key != "":
			_hulls[cache_key] = hull
	var shape := CollisionShape3D.new()
	shape.name = "Hull"
	shape.shape = hull
	body.add_child(shape, false, Node.INTERNAL_MODE_FRONT)


## Swaps world-triplanar library materials for object-space copies (same
## texel density, but the texture moves with the prop: ENVIRONMENT_PLAN.md 6.2).
static func localize_materials(node: Node) -> void:
	for inst: MeshInstance3D in meshes_under(node):
		if inst.mesh == null:
			continue
		for i: int in inst.mesh.get_surface_count():
			var mat: Material = inst.get_active_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).uv1_world_triplanar:
				if not _local_materials.has(mat):
					var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					copy.uv1_world_triplanar = false
					copy.resource_name = mat.resource_name + "_local"
					_local_materials[mat] = copy
				inst.set_surface_override_material(i, _local_materials[mat])


## Materials under `node` that still map in world space (should be none on a prop).
static func world_mapped_materials(node: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for inst: MeshInstance3D in meshes_under(node):
		if inst.mesh == null:
			continue
		for i: int in inst.mesh.get_surface_count():
			var mat: Material = inst.get_active_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).uv1_world_triplanar:
				out.append("%s surface %d (%s)" % [inst.name, i, mat.resource_name])
			elif mat is ShaderMaterial:
				out.append("%s surface %d (shader %s)" % [inst.name, i, mat.resource_name])
	return out


static func meshes_under(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Merged mesh AABB in `node`'s space.
static func local_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for inst: MeshInstance3D in meshes_under(node):
		if inst.mesh == null:
			continue
		var b: AABB = relative(node, inst) * inst.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## `node`'s transform in `space`, without needing the tree.
static func relative(space: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != space:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
