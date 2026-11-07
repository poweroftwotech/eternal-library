class_name ShrineCandle
extends StaticBody3D
## The candle you can light at the R17 Ossuary's shrine (phase 16 step 4, the
## brief's Q6). E lights it; it is saved as a delta of the room and burns down
## over BURN_S seconds of play, so you can find it on a return visit, shorter or
## gone out. A burnt-out stub can be lit again. Nothing else depends on it.
##
## Its light is made here and not by a kit marker: LightBudget turns kit lights on
## and off by distance, which would relight one that had burnt out.

## Seconds of play a candle lasts.
const BURN_S: float = 1800.0
## How much of the wax is left when it goes out.
const STUB: float = 0.25
const WAX_TOP: float = 0.2
## How often the wax is measured again.
const TICK_S: float = 4.0

var _ws: Node
var _id: String = ""
var _wax: MeshInstance3D
var _flame: MeshInstance3D
var _flame_rest: Vector3
var _light: OmniLight3D
var _t: float = 0.0
var _tick: float = 0.0


func _ready() -> void:
	collision_layer = 2     # only the interaction ray: you walk past it
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.24
	shape.shape = ball
	shape.position = Vector3(0.0, 0.14, 0.0)
	add_child(shape)
	_wax = find_children("*wax*", "MeshInstance3D", true, false).front() as MeshInstance3D
	_flame = find_children("*flame*", "MeshInstance3D", true, false).front() as MeshInstance3D
	_flame_rest = _flame.position
	_ws = get_node_or_null("/root/WorldState")
	var room: RoomTemplate = _room()
	if _ws != null and room != null:
		_id = room.room_key() + "/" + room.thing_path(self)
		if not (_ws.call("delta", _id) as Dictionary).is_empty():
			_ws.call("note_applied", _id)
	_show()


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK_S
		_show()
	if _light != null:
		_light.light_energy = 0.8 + 0.1 * sin(_t * 7.3) + 0.08 * sin(_t * 13.1 + 1.0)


## How much is left to burn, 1 to 0; 0 once it is out, and 0 if never lit.
func burning() -> float:
	if _ws == null or _id == "":
		return 0.0
	var d: Dictionary = _ws.call("delta", _id)
	if d.is_empty() or float(_ws.call("years")) > float(d.get("years", 0.0)):
		return 0.0
	return clampf(1.0 - (float(_ws.call("played")) - float(d.get("at", 0.0))) / BURN_S, 0.0, 1.0)


func was_lit() -> bool:
	return _ws != null and _id != "" and not (_ws.call("delta", _id) as Dictionary).is_empty()


func _show() -> void:
	var left: float = burning()
	var lit: bool = left > 0.0
	var wax: float = lerpf(STUB, 1.0, left) if lit else (STUB if was_lit() else 1.0)
	_wax.scale.y = wax
	_flame.position = _flame_rest - Vector3(0.0, (1.0 - wax) * WAX_TOP, 0.0)
	_flame.visible = lit
	if lit and _light == null:
		_light = OmniLight3D.new()
		_light.name = "VigilLight"
		_light.position = Vector3(0.0, 0.45, 0.25)
		_light.light_color = Color(1.0, 0.72, 0.42)
		_light.omni_range = 3.2
		_light.distance_fade_enabled = true
		_light.distance_fade_begin = 20.0
		_light.distance_fade_length = 4.0
		add_child(_light)
	elif not lit and _light != null:
		_light.queue_free()
		_light = null
	set_process(lit)


func interaction_prompt(_hit: Vector3) -> String:
	if burning() > 0.0:
		return "Your candle burns"
	return "Light a new candle" if was_lit() else "Light a candle"


func interact(_actor: Node3D, _hit: Vector3) -> void:
	if burning() > 0.0 or _ws == null or _id == "":
		return
	_ws.call("set_delta", _id, {"s": "vigil", "at": _ws.call("played"), "years": _ws.call("years")})
	_tick = TICK_S
	_show()


func _room() -> RoomTemplate:
	var n: Node = get_parent()
	while n != null and not n is RoomTemplate:
		n = n.get_parent()
	return n as RoomTemplate
