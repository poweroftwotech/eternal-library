class_name ResidentPace
extends Node
## Walks a resident back and forth between two points (the zoo's People pen,
## phase 21 step 1): for looking at the walk, not a mind. It knows nothing of
## walls or of you. It always walks the way it faces and turns as it goes, so
## it sets off from each end in a small arc instead of spinning on the spot.

## Who walks.
var body: ResidentBody
## The two ends (global).
var a: Vector3 = Vector3.ZERO
var b: Vector3 = Vector3.ZERO
## Walking speed (m/s).
var speed: float = 1.2
## Seconds stood at each end.
var rest: float = 2.0
## How fast it turns while walking (rad/s), and how close counts as there (m).
const TURN_RATE: float = 2.2
const NEAR: float = 0.35
var _to_b: bool = true
var _wait: float = 0.0


func _ready() -> void:
	if body != null:
		body.play("walk", 0.0, 0.0, speed / body.walk_speed())


func _process(delta: float) -> void:
	if body == null:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			body.play("walk", 0.35, 0.0, speed / body.walk_speed())
		return
	var to: Vector3 = (b if _to_b else a) - body.global_position
	to.y = 0.0
	if to.length() < NEAR:
		_to_b = not _to_b
		_wait = rest
		body.play("idle", 0.35)
		return
	var want: float = atan2(-to.x, -to.z)
	var turn: float = wrapf(want - body.rotation.y, -PI, PI)
	body.rotation.y += clampf(turn, -TURN_RATE * delta, TURN_RATE * delta)
	# Slower through a tight turn, so the arc stays small.
	var pace: float = speed * lerpf(1.0, 0.55, clampf(absf(turn) / PI, 0.0, 1.0))
	body.global_position += -body.global_basis.z.normalized() * pace * delta
