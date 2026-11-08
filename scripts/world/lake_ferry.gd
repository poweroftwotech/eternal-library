class_name LakeFerry
extends Node3D
## The Lake Landing's ferry (phase 18, R20, Q4): a railed barge you ride
## standing, poled by its ferryman between the quay's pier head and the docks
## (LakeLayout.stops()). Ask the ferryman (E) where to go; he leaves once you
## are on the deck. A bell at each stop calls the ferry to it.
##
## The barge is an AnimatableBody3D moved in the physics step, so you stand on
## it and walk about while it moves. A trip (revised phase, step 2): it backs
## off the stage, turns about, and poles out along its stop's channel. The fog
## thickens round it until there is nothing but fog (R2); under the fog the
## barge, and you on it at the same spot of the deck facing the same way (R3),
## are moved to the end of the other stop's channel, far off in the same scene.
## The fog thins as it comes in along that channel and noses into the stage.
## Only the place you are in is shown (set_place). The bow's gate closes while
## it moves; the rails keep you aboard.
##
## Saves (R4): where the ferry lies (WorldState data "lake"). Saved before the
## fog, it is put back at the stop it left, and so are you, on that stop's
## stage; in or after the fog, at the stop it was going to.

signal arrived(stop: String)
signal departed(stop: String, to: String)
## The fog has hidden the barge and it has been moved to the other channel.
signal crossed(from: String, to: String)

const HALF_LENGTH: float = 4.0
const DECK: float = 0.3
const CRUISE: float = 3.5        # m/s
const ACCEL: float = 0.45        # m/s^2
const BACK_OFF: float = 7.0      # m astern off a stage
const BACK_SPEED: float = 1.4
const TURN_RATE: float = deg_to_rad(28.0)   # per second
const APPROACH: float = 12.0     # the straight run in to a stage
## The fog round the barge: how thick at its heart, over how many metres of
## the channel it closes in (going out) and opens (coming in), and how long
## the barge drifts in it before it is moved.
const FOG_THICK: float = 2.4
const FOG_RUN: float = 22.0
const FOG_HOLD: float = 2.0
const FOG_DRIFT: float = 1.2     # m/s while held in the fog

enum Phase { DOCKED, BACK, TURN, CRUISE, FOG, ARRIVE }

## Where it lies now (or left from).
var at: String = "quay"
var to: String = ""
var phase: Phase = Phase.DOCKED
var body: AnimatableBody3D
var visual: Node3D
var gate: CollisionShape3D
## Asked to go, waiting for you to step aboard (the ferryman's answer).
var wanted: String = ""
## Called by a bell: goes there empty.
var called: bool = false
## The place shown: "quay" (the harbour) or a dock's id (LakeLayout.place_of).
var place: String = ""
var _wait: float = 0.0
var _curve: Curve3D
var _s: float = 0.0
var _speed: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _turn_t: float = 0.0
var _back_from: Vector3
var _t: float = 0.0
## 0: out along the stop's channel; 1: in along the other's (after the fog).
var _leg: int = 0
var _hold: float = 0.0
var _fog: FogVolume
var _place_check: float = 0.0
## You were aboard when it left (for the save, and for the trip's line).
var carrying: bool = false


func _ready() -> void:
	add_to_group("choice_handler")
	_build()
	var saved: Dictionary = _ws().data.get("lake", {}) if _ws() != null else {}
	var stop: String = str(saved.get("ferry_at", "quay"))
	at = stop if stop in LakeLayout.stops() else "quay"
	body.global_transform = dock_pose(at)
	if _ws() != null:
		_ws().saving.connect(_on_saving)
	for bell: Node in get_tree().get_nodes_in_group("lake_bell"):
		if owner != null and owner.is_ancestor_of(bell):
			_bell_body(bell as Node3D)
	set_place("quay")


func _build() -> void:
	body = AnimatableBody3D.new()
	body.name = "Barge"
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	visual = (load("res://kit/modules/walls/lk_ferry.tscn") as PackedScene).instantiate() as Node3D
	visual.name = "Boat"
	body.add_child(visual)
	var man: Node3D = (load("res://kit/modules/walls/lk_ferryman.tscn") as PackedScene).instantiate() as Node3D
	man.name = "Ferryman"
	man.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.35, DECK, 3.0))
	visual.add_child(man)
	# The barge moves: its textures ride with it (world-mapped ones would swim).
	WorldProp.localize_materials(visual)
	# Collision, in the barge's frame (bow toward -Z, deck top at DECK).
	_shape(Vector3(2.9, DECK + 0.3, 7.7), Vector3(0.0, (DECK - 0.3) / 2.0, 0.0))
	for s: float in [-1.0, 1.0]:
		_shape(Vector3(0.12, 1.0, 6.7), Vector3(1.42 * s, DECK + 0.5, 0.52))
		var taper := _shape(Vector3(0.12, 1.0, 1.32), Vector3(1.18 * s, DECK + 0.5, -3.38))
		taper.rotation.y = -atan2(0.47, 1.2) * s
		_shape(Vector3(0.5, 0.38, 4.4), Vector3(1.0 * s, DECK + 0.19, 0.6))     # benches
	_shape(Vector3(2.9, 1.0, 0.12), Vector3(0.0, DECK + 0.5, 3.85))           # the stern rail
	_shape(Vector3(0.7, 1.7, 0.6), Vector3(0.35, DECK + 0.85, 3.0))          # the ferryman
	gate = _shape(Vector3(1.5, 1.0, 0.12), Vector3(0.0, DECK + 0.5, -3.95))
	gate.disabled = true
	var talk := Ferryman.new()
	talk.name = "Talk"
	talk.ferry = self
	talk.collision_layer = 2
	talk.collision_mask = 0
	talk.position = Vector3(0.35, DECK + 0.9, 3.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.9, 0.9)
	shape.shape = box
	talk.add_child(shape)
	body.add_child(talk)
	# The fog that closes round the barge in the channel (R2): dark, so the
	# light falls with it; thin to nothing while docked.
	_fog = FogVolume.new()
	_fog.name = "TripFog"
	_fog.size = Vector3(16.0, 8.0, 22.0)
	_fog.position = Vector3(0.0, 1.5, 0.0)
	var fm := FogMaterial.new()
	fm.density = 0.0
	fm.albedo = Color(0.2, 0.23, 0.28)
	fm.edge_fade = 0.35
	_fog.material = fm
	_fog.visible = false
	body.add_child(_fog)


func _shape(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	return shape


func _bell_body(bell: Node3D) -> void:
	var b := Bell.new()
	b.name = "Ring"
	b.ferry = self
	b.stop = str(bell.get_meta("stop", "quay"))
	b.collision_layer = 2
	b.collision_mask = 0
	b.position = Vector3(0.45, 1.6, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.4, 0.6)
	shape.shape = box
	b.add_child(shape)
	bell.add_child(b)


# ------------------------------------------------------------------ where

## The barge's pose lying at `stop`: its bow at the stage's edge, pointing in.
static func dock_pose(stop: String) -> Transform3D:
	var d: Array = LakeLayout.stop_dock(stop)
	var dock: Vector3 = d[0]
	var out: Vector3 = d[1]
	var centre: Vector3 = Vector3(dock.x, LakeLayout.WATER, dock.z) + out * HALF_LENGTH
	return Transform3D(Basis(Vector3.UP, _yaw_of(-out)), centre)


## The yaw that points a node's -Z along `dir` (on the water's plane).
static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func moving() -> bool:
	return phase != Phase.DOCKED


func _player() -> Node3D:
	var game: Node = get_tree().current_scene
	return game.get("player") as Node3D if game != null and "player" in game else null


## The player on the deck (inside the rails).
func aboard(p: Node3D = null) -> bool:
	if p == null:
		p = _player()
	if p == null:
		return false
	var local: Vector3 = body.global_transform.affine_inverse() * p.global_position
	return absf(local.x) < 1.5 and absf(local.z) < HALF_LENGTH + 0.05 and local.y > -0.3 and local.y < 2.0


## Show only the place you are in (the brief's risk: hidden docks cost
## nothing): the harbour's parts, or one dock. Hidden, their lights are off.
func set_place(p: String) -> void:
	if p == place or owner == null:
		return
	place = p
	for n: String in ["Passage", "Cavern", "Quay", "Pier", "Boathouses", "Drips", "Water"]:
		var node: Node3D = owner.get_node_or_null(n) as Node3D
		if node != null:
			node.visible = p == "quay"
	var docks: Node = owner.get_node_or_null("Docks")
	if docks != null:
		for d: Node in docks.get_children():
			(d as Node3D).visible = String(d.name) == "Dock_" + p


# ------------------------------------------------------------------ asking

func choices() -> Array:
	var out: Array = []
	for s: String in LakeLayout.stops():
		if s != at:
			out.append({"text": "Cross to %s" % LakeLayout.stop_name(s), "action": "ferry:" + s})
	out.append({"text": "Not now", "action": "close"})
	return out


## main.gd's panel answer ("ferry:<stop>"): true if it was ours.
func handle_choice(action: String) -> bool:
	if not action.begins_with("ferry:"):
		return false
	var game: Node = get_tree().current_scene
	if game != null and game.has_method("close_panel"):
		game.close_panel()
	ask(action.trim_prefix("ferry:"))
	return true


## Go to `stop` once the player is aboard.
func ask(stop: String) -> void:
	if moving() or stop == at or not stop in LakeLayout.stops():
		return
	wanted = stop
	called = false
	_wait = 1.2
	_say("The ferryman nods toward %s. \"Step aboard; we go when you're on the deck.\"" % LakeLayout.stop_name(stop) if not aboard()
		else "The ferryman nods toward %s and leans on his pole." % LakeLayout.stop_name(stop))


## A bell rung at `stop`: the ferry comes to it, empty.
func ring(stop: String) -> void:
	if stop == at and not moving():
		_say("The ferry is here.")
		return
	if moving():
		_say("Somewhere out in the fog the ferryman calls back.")
		return
	_say("The bell's note goes out over the water and into the fog.")
	called = true
	wanted = ""
	depart(stop)


func _say(text: String) -> void:
	var game: Node = get_tree().current_scene
	var hud: Object = game.get("hud") if game != null and "hud" in game else null
	if hud != null and hud.has_method("notify"):
		hud.call("notify", text)


# ------------------------------------------------------------------ the trip

func depart(stop: String) -> void:
	if moving() or stop == at:
		return
	to = stop
	carrying = aboard()
	gate.set_deferred("disabled", false)
	phase = Phase.BACK
	_leg = 0
	_back_from = body.global_position
	departed.emit(at, to)
	var out_a: Vector3 = LakeLayout.stop_dock(at)[1]
	var start: Vector3 = _back_from + out_a * BACK_OFF
	var pts := PackedVector3Array([start])
	pts.append_array(LakeLayout.channel(at))
	_curve = _smooth_curve(pts, out_a)
	_yaw_from = body.global_rotation.y
	_yaw_to = _yaw_of((pts[1] - pts[0]).normalized())
	_s = 0.0
	_speed = 0.0
	_turn_t = 0.0


## A curve through `pts`, leaving the first along `first_dir`, its handles
## a third of the way to each neighbour.
static func _smooth_curve(pts: PackedVector3Array, first_dir: Vector3 = Vector3.ZERO, last_dir: Vector3 = Vector3.ZERO) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 0.5
	for i: int in pts.size():
		var hd: Vector3
		if i == 0:
			hd = first_dir * pts[0].distance_to(pts[1]) * 0.35 if first_dir != Vector3.ZERO else (pts[1] - pts[0]) * 0.35
		elif i == pts.size() - 1:
			hd = last_dir * pts[i].distance_to(pts[i - 1]) * 0.35 if last_dir != Vector3.ZERO else (pts[i] - pts[i - 1]) * 0.35
		else:
			hd = (pts[i + 1] - pts[i - 1]) * 0.18
		c.add_point(pts[i], -hd, hd)
	return c


## Under the fog: the barge, and you if you are on it, moved from the end of
## this channel to the end of the other's, as you stood (R3).
func _cross() -> void:
	var from_pose: Transform3D = body.global_transform
	var ch: PackedVector3Array = LakeLayout.channel(to)
	var n: int = ch.size()
	var heading: Vector3 = (ch[n - 2] - ch[n - 1]).normalized()
	var to_pose := Transform3D(Basis(Vector3.UP, _yaw_of(heading)), ch[n - 1])
	var move: Transform3D = to_pose * from_pose.affine_inverse()
	var p: Node3D = _player()
	var on: bool = p != null and aboard(p)
	body.global_transform = to_pose
	body.force_update_transform()
	if on:
		var yaw_turn: float = to_pose.basis.get_euler().y - from_pose.basis.get_euler().y
		if p.has_method("teleport"):
			var cam: Camera3D = p.get("camera") as Camera3D
			p.call("teleport", move * p.global_position, p.global_rotation.y + yaw_turn, cam.rotation.x if cam != null else 0.0)
		else:
			p.global_position = move * p.global_position
		set_place(to)
	# In along the other channel to the stage's approach run, then the stage.
	var d: Array = LakeLayout.stop_dock(to)
	var dock_b: Vector3 = Vector3((d[0] as Vector3).x, LakeLayout.WATER, (d[0] as Vector3).z)
	var out_b: Vector3 = d[1]
	var pts := PackedVector3Array()
	for i: int in range(n - 1, -1, -1):
		pts.append(ch[i])
	pts.append(dock_b + out_b * (HALF_LENGTH + APPROACH))
	pts.append(dock_b + out_b * HALF_LENGTH)
	_curve = _smooth_curve(pts, heading, -out_b)
	_s = 0.0
	_leg = 1
	phase = Phase.CRUISE
	crossed.emit(at, to)


func _physics_process(delta: float) -> void:
	_t += delta
	if visual != null:     # a gentle roll and heave on the boat, not the deck you stand on
		visual.position.y = 0.025 * sin(_t * 0.8)
		visual.rotation.z = deg_to_rad(0.5) * sin(_t * 0.62 + 1.0)
		visual.rotation.x = deg_to_rad(0.3) * sin(_t * 0.47)
	_place_check -= delta
	if _place_check <= 0.0 and phase != Phase.FOG:
		_place_check = 0.5
		var p: Node3D = _player()
		if p != null and not (moving() and carrying):
			set_place(LakeLayout.place_of(p.global_position))
	match phase:
		Phase.DOCKED:
			if wanted != "":
				if aboard():
					_wait -= delta
					if _wait <= 0.0:
						var w: String = wanted
						wanted = ""
						depart(w)
				else:
					_wait = 1.2
		Phase.BACK:
			var done: float = _back_from.distance_to(body.global_position)
			var step: float = minf(BACK_SPEED * delta * smoothstep(-0.2, 1.5, done + 0.3), BACK_OFF - done)
			var out_a: Vector3 = (LakeLayout.stop_dock(at)[1] as Vector3)
			_move_to(body.global_position + out_a * step, body.global_rotation.y)
			if BACK_OFF - done <= 0.02:
				phase = Phase.TURN
		Phase.TURN:
			var span: float = absf(wrapf(_yaw_to - _yaw_from, -PI, PI))
			var dur: float = maxf(3.0, span / TURN_RATE)
			_turn_t = minf(_turn_t + delta / dur, 1.0)
			var k: float = smoothstep(0.0, 1.0, _turn_t)
			_move_to(body.global_position, _yaw_from + wrapf(_yaw_to - _yaw_from, -PI, PI) * k)
			if _turn_t >= 1.0:
				phase = Phase.CRUISE
		Phase.CRUISE, Phase.ARRIVE:
			var length: float = _curve.get_baked_length()
			var left: float = length - _s
			# Out along the channel it keeps its pace into the fog; in, it slows to the stage.
			var want: float = CRUISE if _leg == 0 else minf(CRUISE, sqrt(2.0 * ACCEL * maxf(left, 0.0)) + 0.15)
			_speed = move_toward(_speed, want, ACCEL * delta * (2.0 if want < _speed else 1.0))
			_s = minf(_s + _speed * delta, length)
			var pos: Vector3 = _curve.sample_baked(_s)
			var ahead: Vector3 = _curve.sample_baked(minf(_s + 1.5, length))
			var dir: Vector3 = (ahead - pos)
			if _leg == 1 and _s >= length - 0.2:
				dir = -(LakeLayout.stop_dock(to)[1] as Vector3)
			dir.y = 0.0
			var yaw: float = body.global_rotation.y
			if dir.length() > 0.01:
				yaw = lerp_angle(yaw, _yaw_of(dir.normalized()), minf(1.0, delta * 2.0))
			_move_to(Vector3(pos.x, LakeLayout.WATER, pos.z), yaw)
			if _leg == 0:
				_set_fog(1.0 - smoothstep(0.0, FOG_RUN, left))
				if left <= 0.01:
					phase = Phase.FOG
					_hold = FOG_HOLD
			else:
				_set_fog(1.0 - smoothstep(0.0, FOG_RUN, _s))
				if left < APPROACH:
					phase = Phase.ARRIVE
				if left <= 0.01:
					_arrive()
		Phase.FOG:
			# Held in the fog, drifting on slowly, then moved.
			_set_fog(1.0)
			_speed = move_toward(_speed, FOG_DRIFT, ACCEL * delta * 2.0)
			_move_to(body.global_position - body.global_basis.z * _speed * delta, body.global_rotation.y)
			_hold -= delta
			if _hold <= 0.0:
				_cross()


## The fog round the barge, 0 (none) to 1 (nothing to see but fog).
func _set_fog(k: float) -> void:
	_fog.visible = k > 0.001
	(_fog.material as FogMaterial).density = FOG_THICK * k * k


func _move_to(pos: Vector3, yaw: float) -> void:
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)


func _arrive() -> void:
	body.global_transform = dock_pose(to)
	at = to
	to = ""
	phase = Phase.DOCKED
	_leg = 0
	_set_fog(0.0)
	gate.set_deferred("disabled", true)
	if carrying:
		_say("The bow bumps the stage at %s." % LakeLayout.stop_name(at))
	carrying = false
	called = false
	arrived.emit(at)


# ------------------------------------------------------------------ the save

func _on_saving() -> void:
	var ws: Node = _ws()
	var lake: Dictionary = ws.data.get("lake", {})
	# Before the fog: back where it left from; in or after it: where it was going (R4).
	var lies: String = to if moving() and (_leg == 1 or phase == Phase.FOG) else at
	lake["ferry_at"] = lies
	ws.data["lake"] = lake
	if moving() and aboard():
		var d: Array = LakeLayout.stop_dock(lies)
		var stand: Vector3 = (d[0] as Vector3) - (d[1] as Vector3) * 0.9 + Vector3(0.0, 0.05, 0.0)
		var pose: Dictionary = ws.data.get("player", {})
		pose["pos"] = [stand.x, stand.y, stand.z]
		pose["yaw"] = _yaw_of(-(d[1] as Vector3))     # facing up the steps
		pose["flying"] = false
		ws.data["player"] = pose


func _ws() -> Node:
	return get_node_or_null("/root/WorldState")


## The ferryman: what the interaction ray finds on him.
class Ferryman extends StaticBody3D:
	var ferry: LakeFerry

	func interaction_prompt(_hit: Vector3) -> String:
		if ferry.moving():
			return "The ferryman poles on, watching the water"
		if ferry.wanted != "":
			return "Step aboard; he waits"
		return "E — Ask the ferryman where he can take you"

	func interact(_actor: Node3D, _hit: Vector3) -> void:
		if ferry.moving():
			return
		var game: Node = get_tree().current_scene
		if game != null and game.has_method("open_panel"):
			game.open_panel("The ferryman", ("He leans on his pole and waits." if ferry.choices().size() > 1 else "He leans on his pole. \"The channels aren't open yet.\""), ferry.choices(), "ferry")
		elif ferry.choices().size() > 1:
			ferry.ask(str(ferry.choices()[0]["action"]).trim_prefix("ferry:"))


## A bell post's bell: ring for the ferry.
class Bell extends StaticBody3D:
	var ferry: LakeFerry
	var stop: String = "quay"

	func interaction_prompt(_hit: Vector3) -> String:
		return "The ferry is here" if ferry.at == stop and not ferry.moving() else "E — Ring the bell for the ferry"

	func interact(_actor: Node3D, _hit: Vector3) -> void:
		ferry.ring(stop)
