extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.world.set_process(false)
	var atmosphere = game.world.atmosphere
	var low: float = 100
	var high: float = -100
	var origin: Vector3 = game.world.fire_light.position
	var movement: float = 0
	for i in range(120):
		atmosphere.tick(i*.1)
		low = minf(low,game.world.fire_light.light_energy)
		high = maxf(high,game.world.fire_light.light_energy)
		movement = maxf(movement,origin.distance_to(game.world.fire_light.position))
	# Relative to the tuned base (art_direction.gd FIRE_ENERGY), not absolute.
	var base: float = atmosphere.fire_energy
	check(high-low>base*.25 and low>base*.55 and high<base*1.65,"Hearth variation is visible and remains bounded")
	check(movement>.08 and movement<.5,"Hearth source moves within the fire rather than across the room")
	check(game.world.fire_light.shadow_enabled and atmosphere.hearth_bounce.shadow_enabled,"Moving hearth lights cast real shadows")
	check(atmosphere.foliage_materials.size()>=3,"Tree and ground foliage use wind materials")
	check(atmosphere.water_materials.size()>=2,"Channel and cascade share the atmosphere clock")
	check(atmosphere.lanterns.size()>=3,"Lantern flames participate in the light variation")
	check(game.audio.stream is AudioStreamOggVorbis and absf(game.audio.stream.get_length()-96)<.1 and game.audio.stream.loop,"Original 96-second music stream is loaded and loops")
	game.on_choice("mute")
	check(game.mute and game.audio.volume_db<=-70,"Music can be muted")
	game.on_choice("mute")
	check(not game.mute and game.audio.volume_db>-30,"Music can be restored")
	game.queue_free()
	for i in range(4):
		await process_frame
	if failures.is_empty():
		print("PASS: %d atmosphere and music checks; hearth energy %.2f..%.2f, motion %.3fm" % [checks,low,high,movement])
	else:
		print("FAIL: "+str(failures))
	quit(0 if failures.is_empty() else 1)
