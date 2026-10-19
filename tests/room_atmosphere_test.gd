extends SceneTree
## Phase 1 step 4 gate: AtmosphereProfile and the Atmosphere node.
##   godot --headless --path . --script res://tests/room_atmosphere_test.gd
## The prototype keeping its exact look is checked on the GPU with
## tests/image_diff.gd (see ENVIRONMENT_PLAN.md step 4).

const ROOM: String = "res://rooms/authored/reading_room.tscn"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	check_prototype_profile()
	await check_room()
	await check_defers_to_world()
	print("room_atmosphere_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## prototype_v011.tres must reproduce what art_direction.gd used to set.
func check_prototype_profile() -> void:
	var p: AtmosphereProfile = load("res://kit/atmosphere/prototype_v011.tres")
	check(p != null, "prototype profile loads")
	if p == null:
		return
	var env := Environment.new()
	p.apply(env)
	var want: Dictionary = {
		"tonemap_mode": Environment.TONE_MAPPER_AGX, "tonemap_exposure": 0.97, "ambient_light_energy": 0.22,
		"glow_intensity": 0.85, "glow_bloom": 0.04, "glow_hdr_threshold": 0.95, "volumetric_fog_density": 0.003,
		"volumetric_fog_anisotropy": 0.55, "ssao_intensity": 2.2, "ssao_light_affect": 0.35,
		"adjustment_contrast": 1.06, "adjustment_saturation": 1.12, "sdfgi_enabled": true, "sdfgi_min_cell_size": 0.15}
	for key: String in want:
		var got: Variant = env.get(key)
		var ok: bool = is_equal_approx(float(got), float(want[key])) if got is float else got == want[key]
		check(ok, "prototype %s = %s (got %s)" % [key, want[key], got])
	check(env.ambient_light_color.is_equal_approx(Color("5a86a6")), "prototype ambient colour")
	check(env.get_glow_level(0) == 0.0 and env.get_glow_level(3) == 1.0 and env.get_glow_level(6) == 0.0, "prototype glow levels")
	var curve: Gradient = (env.adjustment_color_correction as GradientTexture1D).gradient
	check(curve.colors[1].is_equal_approx(Color(0.155, 0.185, 0.195)), "prototype split-tone shadows lean teal")


func check_room() -> void:
	var room: RoomTemplate = (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	var atmo: Atmosphere = room.get_node_or_null("Atmosphere")
	check(atmo != null and atmo.profile != null and atmo.profile.resource_path.ends_with("reading_room.tres"),
		"reading room has an Atmosphere with reading_room.tres")
	check(room.find_children("*", "WorldEnvironment", true, true).is_empty(), "no WorldEnvironment is saved in the room")
	if atmo == null:
		return
	check(atmo.environment() != null, "alone in the world, the room builds its own environment")
	check(room.get_world_3d().environment == atmo.environment(), "and it is the world's active environment")
	var env: Environment = atmo.environment()
	if env != null:
		check(env.adjustment_enabled and env.glow_enabled and env.volumetric_fog_enabled, "grade, glow and haze on")
		check(is_equal_approx(env.tonemap_exposure, atmo.profile.exposure), "exposure from the profile")
	# Chandeliers are pinned lit in this room; sway touches only lit lamps.
	var lit: Array[Light3D] = atmo.lit_lanterns()
	var all_lights: Array = room.find_children("*", "Light3D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("kit_light"))
	check(lit.size() >= 2 and lit.size() <= all_lights.size(), "lit lanterns found (%d of %d kit lights)" % [lit.size(), all_lights.size()])
	check(lit.all(func(l: Light3D) -> bool: return str(l.get_meta("lamp_state", "lit")) == "lit"), "only lit lamps sway")
	var sample: Light3D = lit[0] if not lit.is_empty() else null
	if sample != null:
		atmo.tick(0.0)
		var a: float = sample.light_energy
		atmo.tick(0.37)
		var b: float = sample.light_energy
		atmo.tick(0.0)
		check(not is_equal_approx(a, b) and is_equal_approx(sample.light_energy, a), "sway moves energy and is deterministic in t")
		var base: float = sample.get_meta("lamp_base_energy")
		check(absf(b / base - 1.0) <= atmo.profile.lantern_sway * 1.6, "sway stays within lantern_sway")
	var pins: Dictionary = room.socket_pins
	check(pins.keys().filter(func(k: String) -> bool: return k.contains("lantern_cluster")).size() == 2, "both chandeliers are pinned in the room")
	check(room.get_node_or_null("Lights/IwanGlow") is OmniLight3D and room.get_node_or_null("Lights/CoolFillWest") is OmniLight3D,
		"authored fills present")
	room.queue_free()
	await process_frame


## With an environment already in the world (an area, the game), the room's
## Atmosphere must not add a second one.
func check_defers_to_world() -> void:
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	root.add_child(we)
	await process_frame
	var room: RoomTemplate = (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	var atmo: Atmosphere = room.get_node("Atmosphere")
	check(atmo.environment() == null, "the room defers to an existing world environment")
	check(room.get_world_3d().environment == we.environment, "the existing environment stays active")
	room.queue_free()
	we.queue_free()
	await process_frame
