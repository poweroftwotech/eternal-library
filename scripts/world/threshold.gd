class_name Threshold
extends Area3D
## A door out of an area (phase-6-design.md 5.7.6, phase 6 step 5): you open
## it (E, aiming at it) and travel to area `to` as its own scene, arriving
## at that area's door back (Area.arrive_from; main.cross). Until door
## travel (2026-11-01) walking into the doorway travelled. Placed by Area.make_room on every planned connector
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
##
## Ornate doors (2026-11-01): every door between places is an OrnateDoor
## (look "ornate") filling its arch to the crown: a Gorge ledge's pishtaq,
## the kit's wall arch where an area's door leads out, the camp's back door
## (added by CampRoom when the stratum plan puts an area behind it).

## The area id it leads to, or "camp" (the Overlook's door back, phase 7 step 4).
@export var to: String = ""
## "glow": the glowing doorway (a door inside the library); "card": the
## gorge door bay's lit door; "door": nothing drawn (a door piece is there);
## "stub": nothing drawn, the wall where the glow's is (the camp's back door,
## its glow baked in); "ornate": an OrnateDoor fitted to `arch` (a door
## between places, ornate doors 2026-11-01).
@export var look: String = "glow"
## The opening an "ornate" door fills: a key of ARCHES.
@export var arch: String = "kit"

## Each opening an ornate door fills: [half width, springing, rise, foot]
## (the kit's pointed()) and the leaves' face, out from the connector.
const ARCHES: Dictionary = {
	# A Gorge gallery's pishtaq (tools/kit_add_gorge.py DOOR_OPEN over BASE):
	# in front of the module's own leaves and fanlight.
	"gorge": [1.15, 2.0, 1.0, 0.2, 0.5],
	# The kit's 3 m wall arch (wall_arch_3m: 3 m span, springing 1.8, k 0.6),
	# the doors out of the library's areas: mid-wall.
	"kit": [1.5, 1.8, 1.775, 0.0, 0.05],
	# The camp's back door (camp_hall_front's arch, measured by
	# tests/door_probe.gd): in its reveal.
	"camp": [1.45, 2.7, 1.7, 0.0, 0.1],
}

## The doorway, from just inside it to the wall behind (the trigger it was
## until door travel; tests still measure from it).
const TRIGGER := AABB(Vector3(-1.2, 0.0, -0.7), Vector3(2.4, 2.6, 1.4))
## The wall past the doorway (as the exit stub's) and the glow on it.
const WALL := AABB(Vector3(-1.8, 0.0, -1.1), Vector3(3.6, 4.0, 0.4))
## ... and the gorge door's, just behind its card.
const CARD_WALL := AABB(Vector3(-1.8, 0.0, -0.3), Vector3(3.6, 4.0, 0.4))
## ... and a door piece's (a gallery's pishtaq, its leaves 0.37 m out from the
## connector; the Overlook's bronze door): in front of the leaves.
const DOOR_WALL := AABB(Vector3(-1.8, 0.0, -0.3), Vector3(3.6, 4.0, 0.7))
## ... and the camp's back door's: just in front of the blocker baked with its
## glow (FrontDoorGlow), so the interaction ray finds the door first.
const STUB_WALL := AABB(Vector3(-1.8, 0.0, -0.7), Vector3(3.6, 4.0, 0.4))
const GLOW_Z: float = -1.4
const GLOW_COLOR := Color(0.5, 0.66, 0.8)
const DOOR_LAMP := Color(1.0, 0.8, 0.55)
## The door card: the doorway piece's opening (its foot over the floor,
## width, height), out from the face.
const CARD := Vector3(.35, 2.4, 3.15)
const CARD_OUT: float = .2
const CARD_MAT: Material = preload("res://kit/materials/gorge_window.tres")

## Set once opened: the travel is under way.
var crossed: bool = false
## What the door says it opens onto (the place's name); "" = `to`.
@export var to_name: String = ""


func _ready() -> void:
	monitorable = false
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	var wall := Leaf.new()
	wall.name = "Wall"
	wall.door = self
	wall.collision_layer = 1 | 2     # the world, and what the interaction ray finds
	var ws := CollisionShape3D.new()
	var box: AABB = {"card": CARD_WALL, "door": DOOR_WALL, "stub": STUB_WALL}.get(look, WALL)
	var ornate: OrnateDoor = null
	if look == "ornate":
		var a: Array = ARCHES.get(arch, ARCHES["kit"])
		ornate = OrnateDoor.make(a[0], a[1], a[2], a[3])
		ornate.name = "Door"
		ornate.position.z = a[4]
		add_child(ornate)
		box = AABB(Vector3(-a[0] - 0.1, 0.0, a[4] - OrnateDoor.THICK - 0.3), Vector3(2.0 * a[0] + 0.2, ornate.top(), OrnateDoor.THICK + 0.32))     # the leaves' face, and behind them
		if arch == "kit":
			# A lamp before a door out of the library (the glow's light, which lit
			# the doorway, warmer): the rooms are dark there.
			var lamp := OmniLight3D.new()
			lamp.name = "Light"
			lamp.light_color = DOOR_LAMP
			lamp.light_energy = .5
			lamp.omni_range = 6.0
			lamp.light_specular = 0.15     # no glints on the tympanum's tile
			lamp.position = Vector3(0, 3.0, a[4] + 2.2)
			add_child(lamp)
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


## What the HUD says, aiming at the door.
func prompt() -> String:
	return "Open the door to %s" % (to_name if to_name != "" else to.capitalize())


## Opens the door: the game travels to `to` (main.cross).
func open() -> void:
	var game: Node = get_tree().current_scene if is_inside_tree() else null
	if crossed or game == null or not game.has_method("cross"):
		return
	crossed = true
	game.call("cross", to)


## The door's wall, which the interaction ray finds (E opens it).
class Leaf extends StaticBody3D:
	var door: Threshold

	func interaction_prompt(_hit: Vector3) -> String:
		return door.prompt()

	func interact(_actor: Node3D, _hit: Vector3) -> void:
		door.open()
