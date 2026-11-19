class_name ResidentBody
extends Node3D
## A resident's body (phase 21 step 1): the rigged man or woman from
## tools/resident_body.py (actors/models/<kind>.glb), dressed from the costume
## atlas (design/costume-atlas.html). The model is many pieces on one
## skeleton (garments, hair, things worn); an outfit says which show and in
## what colours. What the person does is the mind's; this only shows them.
##
## Animations (all looping): idle, walk, sit_bench (a seat 0.42 m high, times
## the body's size), sit_floor (cross-legged), sit_knees (kneeling back on the
## heels), sleep (on the back: the body lies along the node's Z, its middle
## over the origin, the head toward +Z). floor_sit() is the one of the two
## floor poses this outfit sits in. They blink.

const KINDS: PackedStringArray = ["man", "woman"]
const SHADER: Shader = preload("res://shaders/resident.gdshader")
## Dyes (the atlas: fungus violets, rusts and greys are cheap; madder and
## saffron are sun-grown and costly).
const UNDYED := Color(0.62, 0.56, 0.44)
const VIOLET := Color(0.3, 0.2, 0.38)
const RUST := Color(0.45, 0.22, 0.14)
const GREY := Color(0.3, 0.31, 0.34)
const MADDER := Color(0.5, 0.13, 0.1)
const SAFFRON := Color(0.74, 0.48, 0.1)
const INDIGO := Color(0.12, 0.18, 0.36)
const WALNUT := Color(0.3, 0.2, 0.13)
const WHITE := Color(0.8, 0.76, 0.66)
const MOSS := Color(0.27, 0.32, 0.2)
const LEATHER := Color(0.2, 0.14, 0.1)
const CREAM := Color(0.74, 0.68, 0.52)
## Glow thread, by home area.
const GLOW_MAHALEH := Color(1.0, 0.8, 0.45)
const GLOW_STACKS := Color(0.45, 0.85, 1.0)
const GLOW_TERRACES := Color(0.75, 0.55, 1.0)
const NO_GLOW := Color(0, 0, 0)
## The outfits (the atlas's plates). pieces: what shows besides `base`. A
## floor-length garment (long) has no legs piece: they are never seen, and
## would poke through the skirt when its wearer sits; its wearer kneels on
## the floor, where others sit cross-legged.
## a the main garment, b under it and leather, c sash and head cloth, d what
## is worn over; beard: the painted full beard.
const OUTFITS: Dictionary = {
	"lane_coat": {"kind": "man", "plate": "M1", "pieces": ["coat", "legs_narrow", "cap_felt", "belt_things"],
		"a": VIOLET, "b": UNDYED, "c": Color(0.42, 0.37, 0.27), "d": LEATHER, "trim": UNDYED, "glow": GLOW_MAHALEH, "beard": true},
	"scholar": {"kind": "man", "plate": "M2", "long": true, "pieces": ["robe", "fillet", "hair_curls", "beard_square"],
		"a": INDIGO, "b": WALNUT, "c": CREAM, "d": LEATHER, "trim": Color(0.8, 0.7, 0.45), "glow": GLOW_MAHALEH, "beard": true},
	"merchant": {"kind": "man", "plate": "M3", "pieces": ["caftan", "legs_baggy", "cap_tall", "belt_things"],
		"a": SAFFRON, "b": CREAM, "c": MADDER, "d": LEATHER, "trim": MADDER, "glow": GLOW_MAHALEH, "beard": true},
	"hunter": {"kind": "man", "plate": "M4", "pieces": ["coat", "legs_narrow", "hides", "hair_bushy"],
		"a": MOSS, "b": Color(0.3, 0.27, 0.2), "c": LEATHER, "d": Color(0.28, 0.21, 0.15), "trim": LEATHER, "glow": NO_GLOW, "beard": false},
	"lamp_tender": {"kind": "man", "plate": "M5", "pieces": ["coat", "legs_narrow", "cloak", "globe", "padam"],
		"a": WHITE, "b": WHITE, "c": CREAM, "d": MADDER, "trim": Color(0.8, 0.7, 0.45), "glow": GLOW_MAHALEH, "beard": false},
	"house_dress": {"kind": "woman", "plate": "W1", "long": true, "pieces": ["dress", "braid", "band"],
		"a": VIOLET, "b": UNDYED, "c": RUST, "d": UNDYED, "trim": UNDYED, "glow": GLOW_MAHALEH, "beard": false},
	"keeper": {"kind": "woman", "plate": "W2", "long": true, "pieces": ["dress", "veil", "band"],
		"a": Color(0.2, 0.22, 0.28), "b": GREY, "c": WHITE, "d": WHITE, "trim": WHITE, "glow": NO_GLOW, "beard": false},
	"bazaar_gown": {"kind": "woman", "plate": "W3", "long": true, "pieces": ["gown", "shawl", "topknot", "fillet", "belt_things"],
		"a": MADDER, "b": CREAM, "c": SAFFRON, "d": CREAM, "trim": SAFFRON, "glow": GLOW_MAHALEH, "beard": false},
	"copyist": {"kind": "woman", "plate": "W4", "pieces": ["jacket", "legs_baggy", "pinned", "belt_things"],
		"a": Color(0.7, 0.65, 0.5), "b": GREY, "c": INDIGO, "d": INDIGO, "trim": INDIGO, "glow": GLOW_STACKS, "beard": false},
}
## Skin and hair.
const FACES: Array[Dictionary] = [
	{"skin": Color(0.72, 0.52, 0.38), "hair": Color(0.07, 0.055, 0.05)},
	{"skin": Color(0.62, 0.43, 0.3), "hair": Color(0.1, 0.07, 0.05)},
	{"skin": Color(0.78, 0.6, 0.46), "hair": Color(0.2, 0.13, 0.08)},
	{"skin": Color(0.5, 0.34, 0.24), "hair": Color(0.05, 0.045, 0.04)},
	{"skin": Color(0.7, 0.5, 0.36), "hair": Color(0.5, 0.48, 0.45)},
]
## A body's size against the man's (the models' own heights).
const SIZES: Dictionary = {"man": 1.0, "woman": 0.945}
## One walk cycle covers WALK_STRIDE m (times the size) in WALK_CYCLE_S s
## (tools/resident_body.py WALK_STRIDE, WALK_FRAMES).
const WALK_STRIDE: float = 1.36
const WALK_CYCLE_S: float = 26.0 / 24.0
static var _materials: Dictionary = {}

var kind: String = "man"
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
## Piece name -> its mesh ("base", "coat", ...).
var pieces: Dictionary = {}
var outfit: String = ""
var face: Dictionary = {}
## Seconds between blinks, and how long the eyes stay shut.
const BLINK_EVERY: Vector2 = Vector2(2.0, 6.5)
const BLINK_S: float = 0.13
var _asleep: bool = false
var _blink_in: float = 3.0
var _blinking: float = 0.0


func _init(which: String = "man") -> void:
	kind = which if KINDS.has(which) else "man"
	model = (load("res://actors/models/%s.glb" % kind) as PackedScene).instantiate() as Node3D
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		m.material_override = material(kind)
		pieces[String(m.name).trim_prefix(kind + "_")] = m
	wear(outfits_of(kind)[0], 0)
	play("idle", 0.0)


static func material(of: String) -> ShaderMaterial:
	if not _materials.has(of):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("mask", load("res://actors/models/%s_mask.png" % of))
		_materials[of] = m
	return _materials[of]


## The outfits a man or a woman can wear.
static func outfits_of(of: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in OUTFITS:
		if OUTFITS[id]["kind"] == of:
			out.append(id)
	return out


## A body of the right kind for `id`, wearing it.
static func dressed(id: String, face_index: int = 0) -> ResidentBody:
	var body := ResidentBody.new(String(OUTFITS[id]["kind"]))
	body.wear(id, face_index)
	return body


## Puts on outfit `id` (a key of OUTFITS for this kind) with face `face_index`.
func wear(id: String, face_index: int = 0) -> void:
	var o: Dictionary = OUTFITS[id]
	outfit = id
	face = FACES[posmod(face_index, FACES.size())]
	var shown: Array = o["pieces"]
	for piece: String in pieces:
		var m: MeshInstance3D = pieces[piece]
		m.visible = piece == "base" or shown.has(piece)
		for k: Array in [["cloth_a", o["a"]], ["cloth_b", o["b"]], ["cloth_c", o["c"]], ["cloth_d", o["d"]], ["trim", o["trim"]],
				["glow", o["glow"]], ["skin", face["skin"]], ["hair", face["hair"]]]:
			var c: Color = k[1]
			m.set_instance_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
		m.set_instance_shader_parameter("beard", 1.0 if o["beard"] else 0.0)


## The floor pose this outfit sits in: kneeling in a floor-length garment,
## cross-legged otherwise.
func floor_sit() -> String:
	return "sit_knees" if OUTFITS[outfit].get("long", false) else "sit_floor"


## The speed (m/s) at which the walk's feet don't slide at rate 1.
func walk_speed() -> float:
	return WALK_STRIDE * float(SIZES[kind]) / WALK_CYCLE_S


## Plays `what` (idle, walk, sit_bench, sit_floor, sit_knees, sleep), blending in over
## `blend` s at `rate` times its speed; `at` starts it part way (s), so people
## side by side differ. Walking at v m/s wants rate v / walk_speed().
func play(what: String, blend: float = 0.25, at: float = 0.0, rate: float = 1.0) -> void:
	anim.speed_scale = rate
	_asleep = what == "sleep"
	set_eyes_shut(_asleep)
	if anim.current_animation == what:
		return
	anim.play(what, blend)
	if at > 0.0:
		anim.seek(fmod(at, anim.get_animation(what).length), true)


## Holds a pose: `what` at `t` seconds, still (pictures).
func hold(what: String, t: float) -> void:
	anim.play(what, 0.0)
	anim.seek(t, true)
	anim.pause()
	_asleep = what == "sleep"
	set_eyes_shut(_asleep)
	set_process(false)          # a held pose is for pictures: no blinking


## The eyes are on the base piece.
func set_eyes_shut(shut: bool) -> void:
	(pieces["base"] as MeshInstance3D).set_instance_shader_parameter("eyes_shut", 1.0 if shut else 0.0)


func _process(delta: float) -> void:
	if _asleep:
		return
	if _blinking > 0.0:
		_blinking -= delta
		if _blinking <= 0.0:
			set_eyes_shut(false)
			_blink_in = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blinking = BLINK_S
		set_eyes_shut(true)
