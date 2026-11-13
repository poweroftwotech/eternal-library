class_name CatBody
extends Node3D
## A cat's body (phase 19 step 3): the rigged model from tools/creature_cat.py
## (actors/models/cat.glb), its coat and its animations. What the cat does
## (where it goes, when it sleeps) is the mind's (CatBand); this only shows it.
##
## Animations: idle, walk, sit, sleep, wash (looping), look, startle (once).
## It blinks, shuts its eyes asleep, and turns its head to `look_at_point`.
## Its motion is smooth (phase 19 Q5: the user tried stepped poses and chose
## smooth, 2026-11-09).

const MODEL: PackedScene = preload("res://actors/models/cat.glb")
const SHADER: Shader = preload("res://shaders/creature_cat.gdshader")
const MASK: Texture2D = preload("res://actors/models/cat_coat.png")
## Coats: base, stripes, pale fur, eyes, how strong the stripes are.
const COATS: Array[Dictionary] = [
	{"name": "grey tabby", "coat": Color(0.55, 0.56, 0.57), "stripe": Color(0.24, 0.24, 0.25), "pale": Color(0.85, 0.82, 0.77), "eye": Color(0.78, 0.66, 0.2), "stripes": 1.0},
	{"name": "ginger tabby", "coat": Color(0.85, 0.55, 0.26), "stripe": Color(0.6, 0.32, 0.12), "pale": Color(0.94, 0.86, 0.72), "eye": Color(0.5, 0.72, 0.3), "stripes": 1.0},
	{"name": "cream", "coat": Color(0.85, 0.8, 0.7), "stripe": Color(0.72, 0.62, 0.48), "pale": Color(0.95, 0.92, 0.86), "eye": Color(0.42, 0.62, 0.8), "stripes": 0.6},
	{"name": "black", "coat": Color(0.08, 0.075, 0.07), "stripe": Color(0.05, 0.05, 0.05), "pale": Color(0.1, 0.095, 0.09), "eye": Color(0.85, 0.72, 0.15), "stripes": 0.0},
	{"name": "brown tabby", "coat": Color(0.5, 0.4, 0.29), "stripe": Color(0.17, 0.13, 0.09), "pale": Color(0.8, 0.72, 0.58), "eye": Color(0.55, 0.65, 0.2), "stripes": 1.0},
	{"name": "white and grey", "coat": Color(0.42, 0.43, 0.45), "stripe": Color(0.42, 0.43, 0.45), "pale": Color(0.92, 0.91, 0.88), "eye": Color(0.5, 0.7, 0.35), "stripes": 0.0},
]
## How far the head and the neck each turn to look (rad), and how fast (1/s).
const LOOK_YAW: float = 0.6
const LOOK_PITCH: float = 0.3
const LOOK_RATE: float = 4.0
const BLINK_S: float = 0.13
static var _material: ShaderMaterial

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var mesh: MeshInstance3D
var coat: Dictionary = {}
## Where it is looking (global), and whether it is.
var look_at_point: Vector3 = Vector3.ZERO
var looking: bool = false
var asleep: bool = false
var _look := Vector2.ZERO          # yaw, pitch now (rad, each of head and neck)
var _blink_in: float = 3.0
var _blinking: float = 0.0
var _shut: bool = false
var _head: int = -1
var _neck: int = -1
var _turn: _Turn


## Turns the head and neck after the animation has posed them.
class _Turn extends SkeletonModifier3D:
	var body: CatBody

	func _process_modification() -> void:
		var sk: Skeleton3D = get_skeleton()
		if sk == null or body == null or body._look.length_squared() < 0.0001:
			return
		# A bone's own Z is the cat's up, its X the cat's side (Blender's
		# frame, roll 0): yaw about Z, pitch about X.
		var q := Quaternion(Vector3(0, 0, 1), body._look.x) * Quaternion(Vector3(1, 0, 0), body._look.y)
		for b: int in [body._neck, body._head]:
			if b >= 0:
				sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * q)


func _init() -> void:
	model = MODEL.instantiate() as Node3D
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	mesh = model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	mesh.material_override = material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF     # phase 19 Q12: small animals cast none
	_head = skeleton.find_bone("head")
	_neck = skeleton.find_bone("neck")
	# Its shadow on the floor under it.
	var blob: MultiMeshInstance3D = BlobShadow.many(1)
	BlobShadow.place(blob, 0, Vector3(0, 0.012, 0.03), Vector3.UP, Vector3.FORWARD, Vector2(0.6, 0.95))
	blob.custom_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 0.2, 1.2))
	add_child(blob)
	_turn = _Turn.new()
	_turn.body = self
	skeleton.add_child(_turn)
	set_coat(0)




static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("mask", MASK)
	return _material


func set_coat(index: int) -> void:
	coat = COATS[posmod(index, COATS.size())]
	for k: Array in [["coat", "coat"], ["stripe", "stripe"], ["pale", "pale"], ["eye_colour", "eye"]]:
		var c: Color = coat[k[1]]
		mesh.set_instance_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
	mesh.set_instance_shader_parameter("stripe_amount", float(coat["stripes"]))


## Plays `what` (idle, walk, sit, sleep, wash, look, startle), blending in
## over `blend` s at `rate` times its speed; `at` starts it part way (s), so
## cats side by side differ.
func play(what: String, blend: float = 0.25, at: float = 0.0, rate: float = 1.0) -> void:
	anim.speed_scale = rate
	asleep = what == "sleep"
	if anim.current_animation == what:
		return
	anim.play(what, blend)
	if at > 0.0:
		anim.seek(fmod(at, anim.get_animation(what).length), true)


## Holds a pose: `what` at `t` seconds, still (pictures).
func hold(what: String, t: float) -> void:
	asleep = what == "sleep"
	anim.play(what, 0.0)
	anim.seek(t, true)
	anim.pause()
	_set_shut(asleep)



func _set_shut(shut: bool) -> void:
	if shut != _shut:
		_shut = shut
		mesh.set_instance_shader_parameter("eyes_shut", 1.0 if shut else 0.0)


func _process(delta: float) -> void:
	# The head: toward what it looks at, eased; straight ahead otherwise.
	var want := Vector2.ZERO
	if looking and not asleep:
		var to: Vector3 = global_transform.affine_inverse() * look_at_point - Vector3(0, 0.27, 0)
		var flat: float = Vector2(to.x, to.z).length()
		if flat > 0.05:
			# The cat faces its own -Z; half the turn each for head and neck.
			want.x = clampf(atan2(-to.x, -to.z) * 0.5, -LOOK_YAW, LOOK_YAW)
			want.y = clampf(atan2(to.y, flat) * 0.5, -LOOK_PITCH, LOOK_PITCH)
	_look = _look.lerp(want, minf(1.0, LOOK_RATE * delta))
	# The eyes.
	if anim.is_playing():
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_in = randf_range(2.5, 7.0)
			_blinking = BLINK_S
		_blinking = maxf(0.0, _blinking - delta)
		_set_shut(asleep or _blinking > 0.0)
