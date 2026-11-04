class_name BridgeHallBridge
extends Node3D
## The R21 Bridge Hall's bridges (BridgeHallGrammar puts this at bh:bridge, the
## run's start: the entry mouth's middle, -Z across the hall). Built from the
## room's grid.meta when the room is, with the Chasm Spans' pieces
## (ChasmGrammar.build_room): deck bays, balustrades with newels, the upper
## aqueduct arcade under each 12 m of deck down to the pit, a stepped corbel
## and pier at an end the arcades don't reach, lamps on some newels. Where
## the far door is a storey up or down (meta bridge.rise), the far arcade bay
## carries the span's flight (phase 12 Q3).
##
## Also the older bridge (Q4): scenery in the hall's other column, level, a
## storey over the deck (under it when yours climbs), with a waterfall
## pouring from a trough on one arch toward yours and a sealed ornate door
## in the carved doorway at each end; no lamps.
##
## And the fall catch (Q6): if you get over a balustrade and drop below the
## deck, you're put back at the passage you came in by.

const BAY: float = 4.0
const GROUP: int = 3
## The pit's floor under the deck (tools/kit_add_r21.py PIT_Z).
const PIT: float = -8.0
## How far under the deck counts as fallen.
const FALLEN: float = 3.0
## The carved door's opening (tools/kit_add_persian.py carved_door: half
## width, springing, rise) and how far in its timber door stands.
const DOOR_ARCH: Array = [0.72, 1.65, 0.85]
const DOOR_DEEP: float = 1.1

var _meta: Dictionary = {}
var _room: Node3D
var _player: Node3D
var _came_by: Vector3 = Vector3.INF      # room frame: where to put you back
var _walk: Array = []                     # the run's walk points (plan), for the fall catch


func _ready() -> void:
	_room = _find_room()
	if _room == null or _room.get("grid") == null:
		return
	_meta = (_room.get("grid") as CellGrid).meta
	if not _meta.has("bridge"):
		return
	var b: Dictionary = _meta["bridge"]
	var n: int = b["bays"]
	_build(self, plan(n, int(b.get("rise", 0))))
	if _meta.has("old_bridge"):
		_add_old_bridge(n, int(b.get("seed", 0)))
	_add_mist()
	_add_window_lights()


func _find_room() -> Node3D:
	var n: Node = get_parent()
	while n != null:
		if n is GeneratedRoom:
			return n as Node3D
		n = n.get_parent()
	return null


## Builds a span plan and moves its parts under `into`.
static func _build(into: Node3D, span: Dictionary) -> void:
	var built: RoomTemplate = ChasmGrammar.build_room(span)
	for c: Node in built.get_children():
		built.remove_child(c)
		into.add_child(c)
	built.free()


## The span plan (ChasmGrammar.solve's form, the run's frame) of a bridge `n`
## bays long whose far end is `rise` storeys up (1), down (-1) or level (0).
## Arcade bays of three; bays left over stand on a stepped corbel against the
## end wall, the first at the far end, then the entry end. A climb or drop is
## in the last arcade bay: a landing then the flight up, or the flight down
## then a landing, so the arcade carries the group's lower deck. `pit` is
## the drop's floor in the run's frame; `fall` the arcade bay that pours a
## waterfall (-1 none), from its +X face (fall_side 1) or -X (-1).
static func plan(n: int, rise: int = 0, pit: float = PIT, lamps: bool = true, fall: int = -1, fall_side: float = 1.0) -> Dictionary:
	var out: Dictionary = {"ok": true, "kind": "bridge", "drop": maxi(0, -rise), "bays": n, "pieces": [], "piers": [],
		"joints": [], "lamps": [], "falls": [], "connectors": {}, "walk": [], "boxes": [], "no_newels": []}
	var lead_far: int = (n % GROUP + 1) / 2
	var lead: int = n % GROUP - lead_far
	var groups: Array[int] = []
	for a: int in range(lead, n - lead_far, GROUP):
		groups.append(a)
	var fa: int = groups[-1] if rise != 0 and not groups.is_empty() else -1
	var high: float = rise * BAY
	# Each bay's deck (NAN on a flight's bays).
	var deck: Array[float] = []
	for k: int in n:
		if fa < 0 or k < fa:
			deck.append(0.0)
		elif rise > 0:
			deck.append(0.0 if k == fa else (NAN if k <= fa + 2 else high))
		else:
			deck.append(NAN if k <= fa + 1 else high)
	for k: int in n:
		if is_nan(deck[k]):
			continue
		var at := Vector3(-2, deck[k], -k * BAY)
		var corbel: bool = k < lead or k >= n - lead_far
		_piece(out, "walls/cliff_ledge_4m" if corbel else "walls/chasm_deck_4m", at)
		for side: int in [1, 3]:
			var xf: Transform3D = Transform3D(Basis(), at) * ChasmGrammar._cell_edge(side)
			(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + "walls/chasm_parapet_4m.tscn", "xf": xf})
			(out["joints"] as Array).append(xf * Vector3(0, 0, -.18))
			(out["joints"] as Array).append(xf * Vector3(4, 0, -.18))
		(out["walk"] as Array).append(at + Vector3(2, 0, -2))
		if corbel:
			var top: float = deck[k] - ChasmGrammar.CORBEL_UNDER
			(out["piers"] as Array).append({"at": Vector3(0, (top + pit) * .5, -(k + .5) * BAY),
				"size": Vector3(ChasmGrammar.CORBEL_PIER, top - pit, ChasmGrammar.CORBEL_PIER)})
	if fa >= 0:
		# The flight (tools/kit_add_r10.py: x 0..4, its top at z 0, its foot
		# 8 m on and 4 m down), turned about for a climb.
		var fxf := Transform3D(Basis(), Vector3(-2, 0, -fa * BAY)) if rise < 0 \
			else Transform3D(Basis(Vector3.UP, PI), Vector3(2, high, -(fa + 3) * BAY))
		(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + "walls/chasm_span_flight.tscn", "xf": fxf})
		for x: float in [.18, 3.82]:
			(out["joints"] as Array).append(fxf * Vector3(x, -.1, 0))
			(out["joints"] as Array).append(fxf * Vector3(x, -BAY, -2 * BAY))
		(out["walk"] as Array).append(fxf * Vector3(2, -1.0, -2))
		(out["walk"] as Array).append(fxf * Vector3(2, -3.0, -6))
	for g: int in groups.size():
		var a: int = groups[g]
		var top: float = (minf(0.0, high) if a == fa else deck[a]) - ChasmGrammar.COURSE
		_piece(out, "walls/aqueduct_upper_12m", Vector3(0, top, -a * BAY), ChasmGrammar.ARC_BASIS)
		var foot: float = top - ChasmGrammar.UPPER_H
		if foot > pit:
			_piece(out, "walls/aqueduct_lower_12m", Vector3(0, foot, -a * BAY), ChasmGrammar.ARC_BASIS)
			foot -= ChasmGrammar.LOWER_H
		(out["boxes"] as Array).append(AABB(Vector3(-ChasmGrammar.ARCADE_HALF, foot, -(a + GROUP) * BAY),
			Vector3(ChasmGrammar.ARCADE_HALF * 2, top - foot, GROUP * BAY)))
		if g == fall:
			var basis: Basis = ChasmGrammar.ARC_BASIS if fall_side > 0 else Basis(Vector3.UP, PI) * ChasmGrammar.ARC_BASIS
			var face := Transform3D(basis, Vector3(fall_side * ChasmGrammar.ARCADE_HALF, top, -(a + GROUP * .5) * BAY))
			var lip: float = (face * ChasmGrammar.FALL_FROM).y
			(out["falls"] as Array).append({"xf": face, "size": Vector2(ChasmGrammar.FALL_WIDTH, lip - pit + .5)})
	if not lamps:
		return out
	# A lamp at each end, on the newel by the mouth (opposite sides), and on
	# every third newel between, alternating sides (walked step 1: too dark);
	# none partway up a flight.
	for k: int in range(2, n - 1, GROUP):
		var y: float = _end_height(deck, k)
		if not is_nan(y):
			(out["lamps"] as Array).append(Vector3((1.82 if (k / GROUP) % 2 == 0 else -1.82), y, -(k + 1) * BAY))
	(out["lamps"] as Array).append(Vector3(1.82, 0, -.18))
	(out["lamps"] as Array).append(Vector3(-1.82, high if fa >= 0 else 0.0, -n * BAY + .18))
	return out


## The deck's height at the far end of bay k (NAN partway up a flight).
static func _end_height(deck: Array[float], k: int) -> float:
	if not is_nan(deck[k]):
		return deck[k]
	if k + 1 < deck.size() and not is_nan(deck[k + 1]):
		return deck[k + 1]
	return NAN


## The deck's height under run point z (the run's frame), for the fall catch:
## the lowest walk point within half a bay.
static func deck_at(walk: Array, z: float) -> float:
	var lo: float = 0.0
	for w: Vector3 in walk:
		if absf(w.z - z) < BAY * .5:
			lo = minf(lo, w.y)
	return lo


static func _piece(out: Dictionary, path: String, at: Vector3, basis: Basis = Basis()) -> void:
	(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + path + ".tscn", "xf": Transform3D(basis, at)})


## The older bridge (meta old_bridge): level, no lamps, a waterfall from one
## of its arches on the side toward yours, a sealed ornate door in the carved
## doorway at each end.
func _add_old_bridge(n: int, seed_value: int) -> void:
	var ob: Dictionary = _meta["old_bridge"]
	var start: Transform3D = ob["start"]
	var holder := Node3D.new()
	holder.name = "OldBridge"
	holder.position = start.origin - position
	add_child(holder)
	var groups: int = (n - n % GROUP) / GROUP
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_old"])
	var toward: float = -signf(holder.position.x)
	_build(holder, plan(n, 0, PIT - start.origin.y, false, rng.randi_range(0, maxi(groups - 1, 0)), toward))
	for i: int in (ob["doors"] as Array).size():
		var face: Transform3D = ob["doors"][i]
		var door := OrnateDoor.make(DOOR_ARCH[0], DOOR_ARCH[1], DOOR_ARCH[2])
		door.name = "SealedDoor_%d" % i
		# The carved panel's opening is centred on the piece (x 0..4).
		door.transform = Transform3D(Basis(), -position) * face * Transform3D(Basis(), Vector3(2.0, 0.0, -DOOR_DEEP))
		add_child(door)


func _physics_process(_delta: float) -> void:
	if _meta.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		var cam: Camera3D = get_viewport().get_camera_3d()
		var n: Node = cam
		while n != null and not n.has_method("teleport"):
			n = n.get_parent()
		_player = n as Node3D
		if _player == null:
			return
	var local: Vector3 = _room.to_local(_player.global_position)
	# The passage you're in is the one you came in by.
	for key: String in ["entry_cells", "far_cells"]:
		for c: Vector3i in _meta[key]:
			var q: Vector3 = CellGrid.cell_centre(c)
			if absf(local.x - q.x) < BAY * .5 and absf(local.z - q.z) < BAY * .5 and absf(local.y - q.y) < 2.0:
				_came_by = Vector3(q.x, q.y + 0.2, q.z)
	var hall: AABB = _meta["hall"]
	if not _came_by.is_finite() or local.y < PIT - 4.0 \
			or local.x < hall.position.x or local.x > hall.end.x or local.z < hall.position.z or local.z > hall.end.z:
		return
	var b: Dictionary = _meta["bridge"]
	if _walk.is_empty():
		_walk = plan(int(b["bays"]), int(b.get("rise", 0)), PIT, false)["walk"]
	var under: float = deck_at(_walk, local.z - position.z)
	if local.y < under - FALLEN:
		var back: Vector3 = _room.to_global(_came_by)
		var into: Vector3 = _room.to_global(Vector3(position.x, _came_by.y, position.z)) - back
		_player.call("teleport", back, atan2(-into.x, -into.z), 0.0)


## The mist glow from below (the room's main light, phase 12 brief): a
## luminous mist lying in the drop under the deck (the visible source), and
## cold lights in it, one per 12 m, to either side of the arcade, that light
## the pit's rock and boulders, the lower walls and the deck's underside. No
## shadows. (A glowing pool plane on the pit floor read as a flat white
## sheet from the deck at any setting, so there's none: seed 3, 2026-11-04.)
## The mist stays under the lowest deck (a dropping bridge's far half).
const MIST_COLOUR: Color = Color(0.82, 0.87, 0.92)
const MIST_LIGHT_ENERGY: float = 3.4
const MIST_LIGHT_RANGE: float = 15.0


func _add_mist() -> void:
	var hall: AABB = _meta["hall"]
	var o: Vector3 = position                 # the run's start in the room
	var cx: float = hall.get_center().x - o.x
	var cz: float = hall.get_center().z - o.z
	var w: float = hall.size.x - 3.5          # between the long walls' faces
	var l: float = hall.size.z - 1.0
	var top: float = minf(0.0, int(_meta["bridge"].get("rise", 0)) * BAY) - 2.0
	var fog := FogVolume.new()
	fog.name = "Mist"
	fog.size = Vector3(w, top - PIT, l)
	fog.position = Vector3(cx, (top + PIT) * 0.5, cz)
	var fm := FogMaterial.new()
	fm.density = 0.12
	fm.albedo = MIST_COLOUR
	fm.emission = Color(0.06, 0.068, 0.076)
	fm.height_falloff = 0.5
	fm.edge_fade = 0.3
	fog.material = fm
	add_child(fog)
	var n: int = int(_meta["bridge"]["bays"])
	var k: int = 0
	var z: float = -GROUP * BAY * 0.5
	while z > -n * BAY:
		var l3 := OmniLight3D.new()
		l3.name = "MistLight_%d" % k
		l3.light_color = MIST_COLOUR
		l3.light_energy = MIST_LIGHT_ENERGY
		l3.omni_range = MIST_LIGHT_RANGE
		l3.omni_attenuation = 0.8
		l3.shadow_enabled = false
		l3.light_specular = 0.2
		l3.light_volumetric_fog_energy = 0.2      # lit from inside, the mist read as a white sheet
		l3.position = Vector3(4.0 if k % 2 == 0 else -4.0, minf(-5.5, top - 1.0), z)
		add_child(l3)
		k += 1
		z -= GROUP * BAY


## Warm light at a few lit windows (BridgeHallGrammar picks them, spaced).
func _add_window_lights() -> void:
	var o: Vector3 = position
	var i: int = 0
	for q: Vector3 in _meta.get("window_lights", []):
		var l := OmniLight3D.new()
		l.name = "WindowLight_%d" % i
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.light_specular = 0.1
		l.position = q - o
		add_child(l)
		i += 1
