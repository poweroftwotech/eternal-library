class_name Threshold
extends Area3D
## A door out of an area (phase-6-design.md 5.7.6, phase 6 step 5): walking
## into the doorway travels to area `to`, arriving at that area's door back
## (Area.arrive_from). Placed by Area.make_room on every planned connector
## capped "threshold", in the connector's frame (-Z through the door, out of
## the room).
##
## A door inside the library glows with the gorge's light beyond it (the
## exit stub's look, cooler) and is walled off just past the glow. The
## gorge's door bay (gorge_bay_doorway) gets a lit door card of the gorge's
## windows set inside its arch ring, in front of the cliff face (on some
## tiers the face stands proud of the piece's own card).
##
## A door out of the camp (phase 7 step 4) is the same glowing doorway, saved
## in the camp's scene; its door back, in the Overlook's loggia, is the bronze
## door already there (look "door": the trigger and the wall, nothing drawn).

## The area id it leads to, or "camp" (the Overlook's door back, phase 7 step 4).
@export var to: String = ""
## "glow": the glowing doorway (a door inside the library); "card": the
## gorge door bay's lit door; "door": nothing drawn (a door piece is there).
@export var look: String = "glow"

## The trigger: the doorway, from just inside it to the wall behind.
const TRIGGER := AABB(Vector3(-1.2, 0.0, -0.7), Vector3(2.4, 2.6, 1.4))
## The wall past the doorway (as the exit stub's) and the glow on it.
const WALL := AABB(Vector3(-1.8, 0.0, -1.1), Vector3(3.6, 4.0, 0.4))
## ... and the gorge door's, just behind its card.
const CARD_WALL := AABB(Vector3(-1.8, 0.0, -0.3), Vector3(3.6, 4.0, 0.4))
## ... and a door piece's (a gallery's pishtaq, its leaves 0.37 m out from the
## connector; the Overlook's bronze door): in front of the leaves.
const DOOR_WALL := AABB(Vector3(-1.8, 0.0, -0.3), Vector3(3.6, 4.0, 0.7))
const GLOW_Z: float = -1.4
const GLOW_COLOR := Color(0.5, 0.66, 0.8)
## The door card: the doorway piece's opening (its foot over the floor,
## width, height), out from the face.
const CARD := Vector3(.35, 2.4, 3.15)
const CARD_OUT: float = .2
const CARD_MAT: Material = preload("res://kit/materials/gorge_window.tres")

## Set once crossed: the travel is under way.
var crossed: bool = false


func _ready() -> void:
	monitorable = false
	collision_layer = 0
	collision_mask = 1 << 3     # the player's layer (player.gd)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = TRIGGER.size
	shape.position = TRIGGER.get_center()
	add_child(shape)
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	var ws := CollisionShape3D.new()
	var box: AABB = CARD_WALL if look == "card" else (DOOR_WALL if look == "door" else WALL)
	ws.shape = BoxShape3D.new()
	(ws.shape as BoxShape3D).size = box.size
	ws.position = box.get_center()
	wall.add_child(ws)
	add_child(wall)
	if look == "card":
		var card := QuadMesh.new()
		card.size = Vector2(CARD.y, CARD.z)
		card.material = CARD_MAT
		var ci := MeshInstance3D.new()
		ci.name = "Card"
		ci.mesh = card
		ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ci.position = Vector3(0, CARD.x + CARD.z * .5, CARD_OUT)
		add_child(ci)
	elif look == "glow":
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.BLACK
		mat.emission_enabled = true
		mat.emission = GLOW_COLOR
		mat.emission_energy_multiplier = .4
		var quad := QuadMesh.new()
		quad.size = Vector2(6, 6.5)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "Glow"
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, 2.75, GLOW_Z)
		add_child(mi)
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = GLOW_COLOR
		light.light_energy = .9
		light.omni_range = 7.0
		light.position = Vector3(0, 2.2, -1.0)
		add_child(light)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var game: Node = get_tree().current_scene if is_inside_tree() else null
	if crossed or game == null or not game.has_method("cross") or body != game.get("player"):
		return
	crossed = true
	game.call("cross", to)
