class_name CampRoom
extends Node3D
## The camp baked from kit pieces (phase 7, docs/environment/camp-rebuild-approval.md):
## rooms/camp/camp.tscn, edited by hand since the code-built camp it was cut
## from was retired (step 4; the bake tool is in art_src/kit/camp/retired_tools/).
## The pieces are plain kit instances; this keeps the camp's living parts moving
## as the old camp's atmosphere clock did (the retired scripts/atmosphere.gd): the fire
## light's flicker and drift, the lanterns' breathing, the garden light's slow
## sway, the leaves' wind and the water's ripples on one clock, and the steam
## and flame cards rising.
##
## Lights carry what they need as metadata from the bake: "camp_light" =
## "fire", "lantern", "bounce" or "garden", with "base_energy" and "origin".
## Effect cards carry "effect_kind" ("steam" or "flame"), "effect_origin" and
## "effect_phase".

## The hearth's middle, as the old camp's (world.gd hearth).
@export var hearth: Vector3 = Vector3(-1.3, 0, 4.4)
## Where the garden light aims (atmosphere.gd garden_aim).
@export var garden_aim: Vector3 = Vector3(-1.8, 0, -4.8)

## The clock (seconds); a capture may set it (tests/capture.gd), as the old camp's.
var elapsed: float = 0.0
var _lights: Array[Light3D] = []
var _effects: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
## The camp's patches to forage (phase 7 step 3), as the old camp's
## (world.gd): id -> {kind, visual, body, taken}. Their plants are under
## "Gatherables" (named by id, meta "kind"), their bodies under "Interactions".
var gatherables: Dictionary = {}


func _ready() -> void:
	var plants: Node = get_node_or_null("Gatherables")
	var bodies: Node = get_node_or_null("Interactions")
	if plants != null and bodies != null:
		for v: Node in plants.get_children():
			var body: Node = bodies.get_node_or_null(NodePath(v.name))
			if body != null:
				gatherables[str(v.name)] = {"kind": str(v.get_meta("kind", "")), "visual": v, "body": body, "taken": false}
	_add_back_door()
	for n: Node in find_children("*", "Light3D", true, false):
		if n.has_meta("camp_light"):
			_lights.append(n as Light3D)
	for n: Node in find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("effect_kind"):
			_effects.append(n as MeshInstance3D)
	# The leaves' wind and the water's ripples: every shader material with a
	# simulation_time, the kit pieces' (shared library materials) included.
	var seen: Dictionary = {}
	for n: Node in find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var mats: Array[Material] = [g.material_override]
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			for s: int in (g as MeshInstance3D).mesh.get_surface_count():
				mats.append((g as MeshInstance3D).get_active_material(s))
		for m: Material in mats:
			if m is ShaderMaterial and not seen.has(m) and (m as ShaderMaterial).shader != null and _has_clock(m as ShaderMaterial):
				seen[m] = true
				_materials.append(m as ShaderMaterial)
	tick(0.0)



## The back door (SNAP_exit_front, its glow baked as FrontDoorGlow) opens
## onto the area the stratum plan puts behind it (StratumPlan.CAMP_BACK_DOOR;
## door travel, 2026-11-01). With none, it stays the glowing stub.
func _add_back_door() -> void:
	var plan: StratumPlan = StratumPlan.current()
	var to: String = plan.camp_back_area() if plan != null else ""
	var at: Node3D = get_node_or_null("Connectors/" + StratumPlan.CAMP_BACK_DOOR)
	if to == "" or at == null or has_node("Threshold_" + to):
		return
	var door := Threshold.new()
	door.name = "Threshold_" + to
	door.to = to
	door.to_name = plan.place_name(to)
	door.look = "ornate"
	door.arch = "camp"
	door.transform = at.transform
	add_child(door)

func _process(delta: float) -> void:
	elapsed += delta
	tick(elapsed)


## Forages a patch, as the old camp did: its plants shrink to a stub and it
## no longer takes the ray. The kind gathered, or "" (none, or taken).
func harvest(id: String) -> String:
	if not gatherables.has(id) or gatherables[id]["taken"]:
		return ""
	var data: Dictionary = gatherables[id]
	data["taken"] = true
	(data["visual"] as Node3D).scale = Vector3.ONE * .16
	(data["body"] as CollisionObject3D).collision_layer = 0
	return data["kind"]


static func _has_clock(m: ShaderMaterial) -> bool:
	for u: Dictionary in m.shader.get_shader_uniform_list():
		if u["name"] == "simulation_time":
			return true
	return false


func tick(t: float) -> void:
	var slow: float = sin(t * 2.1) * .40 + sin(t * 3.73 + .7) * .28 + sin(t * 6.21 + 1.2) * .12
	for l: Light3D in _lights:
		var base: float = l.get_meta("base_energy", l.light_energy)
		var origin: Vector3 = l.get_meta("origin", l.position)
		match str(l.get_meta("camp_light")):
			"fire":
				l.light_energy = base + slow * base * .33
				l.position = hearth + Vector3(sin(t * 2.8) * .13, .23 + sin(t * 4.1) * .025, cos(t * 2.17) * .09)
				l.light_color = Color("ff9d42").lerp(Color("ffd08a"), .48 + slow * .24)
			"bounce":
				l.light_energy = .88 + slow * .32
				l.position = hearth + Vector3(-1.1 + sin(t * 1.9) * .075, 1.65 + cos(t * 2.7) * .035, -.4 + sin(t * 2.2) * .07)
			"lantern":
				var p: float = t + origin.dot(Vector3(.7, 1.3, .9))
				l.light_energy = base * (.95 + sin(p * 2.3) * .045 + sin(p * 4.1) * .025)
				l.position = origin + Vector3(sin(p * 1.7) * .018, sin(p * 3.1) * .008, cos(p * 1.3) * .012)
			"garden":
				l.position = origin + Vector3(sin(t * .17) * .12, 0, cos(t * .13) * .10)
				l.look_at(garden_aim + Vector3(sin(t * .23) * .45, 0, cos(t * .19) * .25), Vector3.FORWARD)
				l.light_energy = base * (1.0 + sin(t * .27) * .04)
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter("simulation_time", t)
	for e: MeshInstance3D in _effects:
		var phase: float = t + float(e.get_meta("effect_phase", 0.0))
		var origin: Vector3 = e.get_meta("effect_origin", e.position)
		if e.get_meta("effect_kind") == "flame":
			e.scale = Vector3(1 + sin(phase * 9) * .12, 1 + sin(phase * 13) * .18, 1)
			e.position.x = origin.x + sin(phase * 7) * .035
		else:
			var k: float = fposmod(phase * .35, 1.0)
			e.position = origin + Vector3((sin(phase * .9) * .22 + .18) * k, k * 1.5, cos(phase * .7) * .16 * k)
			e.scale = Vector3(.6 + k * 1.5, .65 + k * .9, 1)
			var mat := e.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color.a = sin(k * PI) * .30 * (1 - k * .7)
