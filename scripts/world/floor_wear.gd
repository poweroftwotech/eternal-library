class_name FloorWear
extends Node3D
## Walked paths polished into a room's floor (ENVIRONMENT_PLAN.md polish C
## item 9). On _ready it bakes a wear map at 32 texels/m over `rect` and
## hands it to the kit_px_world shader through the kit_wear_* shader globals;
## materials with wear_strength > 0 (floor_stone) then turn glossy along the
## paths. Wear is quantised to a few dithered steps, so each floor texel stays
## one flat value. Only one room's wear is live at a time (the globals are
## shared); leaving the tree clears it.
##
## Coordinates are this node's local x/z. The room may be moved but not
## turned (the map stays axis-aligned in world space).

const TEXEL: float = 32.0
const STEPS: int = 4
const BAYER: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

## Area the map covers (x, z, size x, size z), metres. Keep it on whole metres
## so map texels line up with the floor's texel grid.
@export var rect: Rect2 = Rect2(0, -20, 12, 20)
## Local y range that gets wear (the ground floor, not galleries above it).
@export var y_range: Vector2 = Vector2(-0.5, 0.5)
## Walked lines as polylines of x/z points.
@export var paths: Array[PackedVector2Array] = []
## Traffic per path (1 = main thoroughfare); missing entries count as 1.
@export var path_weights: PackedFloat32Array = PackedFloat32Array()
## Full-wear half width of a path and the fade beyond it, metres.
@export var half_width: float = 0.28
@export var fade: float = 0.45
## Nodes (tables, lecterns) that people stand around: a lighter ring of wear
## follows their footprint at `ring_margin`.
@export var ring_nodes: Array[NodePath] = []
@export var ring_margin: float = 0.45
@export var ring_weight: float = 0.6
@export var seed_value: int = 9

var texture: ImageTexture


func _ready() -> void:
	var image: Image = bake()
	texture = ImageTexture.create_from_image(image)
	var origin: Vector3 = global_position
	RenderingServer.global_shader_parameter_set("kit_wear_map", texture)
	RenderingServer.global_shader_parameter_set("kit_wear_rect",
		Vector4(origin.x + rect.position.x, origin.z + rect.position.y, rect.size.x, rect.size.y))
	RenderingServer.global_shader_parameter_set("kit_wear_y", Vector2(origin.y + y_range.x, origin.y + y_range.y))


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("kit_wear_rect", Vector4.ZERO)


## The wear map: R = wear 0..1 in STEPS dithered levels; row 0 is rect's min z.
func bake() -> Image:
	var w: int = int(rect.size.x * TEXEL)
	var h: int = int(rect.size.y * TEXEL)
	var wear: PackedFloat32Array = PackedFloat32Array()
	wear.resize(w * h)
	for p: int in paths.size():
		var weight: float = path_weights[p] if p < path_weights.size() else 1.0
		var line: PackedVector2Array = paths[p]
		for k: int in line.size() - 1:
			stamp_segment(wear, w, h, line[k], line[k + 1], half_width, weight)
	for path: NodePath in ring_nodes:
		var node: Node3D = get_node_or_null(path)
		if node == null:
			push_warning("FloorWear: no node at %s" % path)
			continue
		var box: AABB = footprint(node)
		if box.size == Vector3.ZERO:
			continue
		var lo := Vector2(box.position.x, box.position.z) - Vector2.ONE * ring_margin
		var hi := Vector2(box.end.x, box.end.z) + Vector2.ONE * ring_margin
		var ring := PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y), lo])
		for k: int in 4:
			stamp_segment(wear, w, h, ring[k], ring[k + 1], half_width * .8, ring_weight)
	# Break the edges up: feet don't keep to a line.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lattice: PackedFloat32Array = PackedFloat32Array()
	var gw: int = w / 8 + 2
	var gh: int = h / 8 + 2
	for i: int in gw * gh:
		lattice.append(rng.randf())
	var image: Image = Image.create_empty(w, h, false, Image.FORMAT_R8)
	for y: int in h:
		for x: int in w:
			var v: float = wear[y * w + x]
			if v <= 0.0:
				continue
			var fx: float = x / 8.0
			var fy: float = y / 8.0
			var x0: int = int(fx)
			var y0: int = int(fy)
			var tx: float = smoothstep(0.0, 1.0, fx - x0)
			var ty: float = smoothstep(0.0, 1.0, fy - y0)
			var n: float = lerpf(lerpf(lattice[y0 * gw + x0], lattice[y0 * gw + x0 + 1], tx),
				lerpf(lattice[(y0 + 1) * gw + x0], lattice[(y0 + 1) * gw + x0 + 1], tx), ty)
			v = clampf(v * (.75 + n * .5), 0.0, 1.0)
			var d: float = BAYER[y % 4][x % 4] / 16.0 - .5
			var level: int = clampi(int(floor(v * STEPS + d * .8)), 0, STEPS)
			image.set_pixel(x, y, Color(float(level) / STEPS, 0, 0))
	return image


## Raises wear along a segment: full within `half`, fading over `fade`.
func stamp_segment(wear: PackedFloat32Array, w: int, h: int, a: Vector2, b: Vector2, half: float, weight: float) -> void:
	var reach: float = half + fade
	var lo: Vector2 = (a.min(b) - Vector2.ONE * reach - rect.position) * TEXEL
	var hi: Vector2 = (a.max(b) + Vector2.ONE * reach - rect.position) * TEXEL
	for y: int in range(maxi(0, int(lo.y)), mini(h, int(ceil(hi.y)) + 1)):
		for x: int in range(maxi(0, int(lo.x)), mini(w, int(ceil(hi.x)) + 1)):
			var p: Vector2 = rect.position + Vector2(x + .5, y + .5) / TEXEL
			var dist: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			var v: float = weight * (1.0 - smoothstep(half, reach, dist))
			wear[y * w + x] = maxf(wear[y * w + x], v)


## The node's visible mesh footprint in this node's space.
func footprint(node: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var to_local: Transform3D = global_transform.affine_inverse()
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child
		if mesh.mesh == null or not mesh.visible:
			continue
		var box: AABB = to_local * mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
