class_name LightBudget
extends Node
## Only the nearest few lamps cast shadows (phase-4-design.md 8.1.5, Q8). A
## child of the Area; rooms' lights join as the rooms enter.
##
## Shadow-capable lights are the ones built with shadows (chandeliers,
## braziers, the exit stubs' glow); lanterns, cold lights and fills never cast
## any and aren't ranked. Every `interval_s` the lit ones are ranked by
## distance to the camera and the nearest `shadow_budget` keep their shadows.
## A light gaining or losing its shadow fades `shadow_opacity` over `fade_s`.
## Every light in the area also fades out with distance (`light_fade_m`, then
## 5 m), so far lamps cost nothing. LampState keeps control of on and off: a
## dark lamp (not visible) is simply not ranked. Phase 5 step 5: the lights of
## rooms you can't see into from the room you're in are off too (`seen_rooms`),
## a dark lamp staying dark when its room comes back into view.

## How many lights cast shadows at once (Q8).
var shadow_budget: int = 4
var interval_s: float = 0.2
var fade_s: float = 0.3
## Distance fade: lights begin fading here and are gone 5 m further.
var light_fade_m: float = 30.0
const FADE_LENGTH: float = 5.0

## Shadow-capable lights live in the area.
var lights: Array[Light3D] = []
## The lights given shadows at the last ranking, nearest first.
var shadowed: Array[Light3D] = []
## Returns the rooms whose lights are on ({slot: true}; empty: all). Area sets it.
var seen_rooms: Callable
## slot -> its rooms' lights (every one, not just the shadow-capable).
var room_lights: Dictionary = {}
var _check: float = 0.0


## A room entered: its lights fade with distance, and those built with shadows
## join the ranking (their shadows start off until ranked).
func add_room(room: Node, slot: String = "") -> void:
	var all: Array[Light3D] = []
	for n: Node in room.find_children("*", "Light3D", true, false):
		var light := n as Light3D
		all.append(light)
		light.distance_fade_enabled = true
		light.distance_fade_begin = light_fade_m
		light.distance_fade_length = FADE_LENGTH
		light.distance_fade_shadow = light_fade_m * 0.75
		if light.has_meta("light_far"):     # the light-well's oculus light and fills: seen from far below
			light.distance_fade_begin = light_fade_m * 3.0
		if light.shadow_enabled or light.has_meta("budget_shadow"):
			light.set_meta("budget_shadow", true)
			light.shadow_enabled = false
			light.shadow_opacity = 0.0
			lights.append(light)
	if slot != "":
		room_lights[slot] = all
	_check = 0.0     # rank at the next frame


## Shadow-capable lights live and lit (visible), nearest the camera first.
func ranked() -> Array[Light3D]:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var kept: Array[Light3D] = []
	var lit: Array[Light3D] = []
	for l: Variant in lights:     # a room that unloaded freed its lights
		if not is_instance_valid(l) or not (l as Light3D).is_inside_tree():
			continue
		kept.append(l)
		if (l as Light3D).is_visible_in_tree():
			lit.append(l)
	lights = kept
	if cam != null:
		var at: Vector3 = cam.global_position
		lit.sort_custom(func(a: Light3D, b: Light3D) -> bool: return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	return lit


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = interval_s
		_show_seen()
		var lit: Array[Light3D] = ranked()
		shadowed = lit.slice(0, shadow_budget)
	var step: float = delta / fade_s if fade_s > 0.0 else 1.0
	# A newcomer waits for a free slot (a shadow still fading out holds its
	# slot), so no more than shadow_budget ever cast at once.
	var slots: int = shadow_budget - casting()
	for l: Variant in lights:
		if not is_instance_valid(l):
			continue
		var light := l as Light3D
		var want: float = 1.0 if shadowed.has(light) else 0.0
		if want > 0.0 and not light.shadow_enabled:
			if slots <= 0:
				continue
			slots -= 1
			light.shadow_enabled = true
		light.shadow_opacity = move_toward(light.shadow_opacity, want, step)
		if want == 0.0 and light.shadow_opacity <= 0.0 and light.shadow_enabled:
			light.shadow_enabled = false


## How many lights cast a shadow right now (fading ones included).
func casting() -> int:
	var n: int = 0
	for l: Variant in lights:
		if is_instance_valid(l) and (l as Light3D).shadow_enabled:
			n += 1
	return n


## Lights on in the rooms you can see into, off in the rest (a dark lamp stays
## off: LampState's "lamp_state" meta).
func _show_seen() -> void:
	var seen: Dictionary = seen_rooms.call() if seen_rooms.is_valid() else {}
	for slot: String in room_lights.keys():
		var on: bool = seen.is_empty() or seen.has(slot)
		var kept: Array[Light3D] = []
		for l: Variant in room_lights[slot]:
			if not is_instance_valid(l):
				continue
			var light := l as Light3D
			kept.append(light)
			var want: bool = on and str(light.get_meta("lamp_state", "lit")) != "dark"
			if light.visible != want:
				light.visible = want
		if kept.is_empty():
			room_lights.erase(slot)
		else:
			room_lights[slot] = kept
