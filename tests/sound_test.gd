extends SceneTree
## Phase 20 step 1: the sound groundwork (scripts/audio/sound.gd).
##   godot --headless --audio-driver Dummy --path . --script res://tests/sound_test.gd -- save
##   godot --headless --audio-driver Dummy --path . --script res://tests/sound_test.gd -- load
## save: checks the buses, the sounds, the reach and the voice limit, then
## sets the Music and Animals volumes to odd values. load (a fresh process):
## checks they came back from user://settings.cfg, then puts back what was
## there before the save.

const KEEP: String = "user://test/sound_test_keep.cfg"
var fails: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "save"
	await process_frame
	var s: SoundSystem = SoundSystem.it()
	check(s != null, "the Sound autoload is there")
	if s == null:
		quit(1)
		return
	if mode == "save":
		await _save(s)
	else:
		_load(s)
	print("sound_test %s: %d failed" % [mode, fails])
	quit(1 if fails > 0 else 0)


func _save(s: SoundSystem) -> void:
	check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("Animals") > 0, "Music and Animals buses exist")
	# The sounds the animals ask for.
	for stem: String in ["nightingale_song", "nightingale_call", "wings_small", "cat_mew", "bat_chitter", "rat_squeak", "fish_splash"]:
		check(not s.clips(stem).is_empty(), "%s: %d sounds load" % [stem, s.clips(stem).size()])
	check(s.clip("cat_purr") != null, "cat_purr loads")
	check(s.clip("no_such_sound") == null, "a missing sound is silence, not an error")
	# A camera to hear from.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3.ZERO
	var song: AudioStream = s.clips("nightingale_song")[0]
	check(s.play_at(song, Vector3(0, 0, -40)) == null, "nothing starts past its reach (40 m, reach 25)")
	check(s.play_at(song, Vector3(0, 0, -28), 30.0) != null, "a song with a 30 m reach starts at 28 m")
	s.stop_all()
	# The voice limit: the nearest MAX_VOICES; a nearer one takes the farthest's place.
	for k: int in SoundSystem.MAX_VOICES:
		s.play_at(song, Vector3(0, 0, -10.0 - k))
	check(s.playing() == SoundSystem.MAX_VOICES, "%d voices at most (%d playing)" % [SoundSystem.MAX_VOICES, s.playing()])
	check(s.play_at(song, Vector3(0, 0, -24)) == null, "a farther sound waits when all voices are nearer")
	var near: AudioStreamPlayer3D = s.play_at(song, Vector3(0, 0, -2))
	check(near != null and s.playing() == SoundSystem.MAX_VOICES, "a nearer sound takes the farthest voice")
	s.stop_all()
	# A wall between: quieter and muffled; in the open: clear.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 0.4)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = Vector3(0, 0, -4)
	for _i: int in 3:
		await physics_frame
	var behind: AudioStreamPlayer3D = s.play_at(song, Vector3(0, 0, -8))
	check(behind != null and s.blocked_of(behind) > 0.99 and behind.volume_db <= SoundSystem.OCCLUDED_DB + 0.01 and behind.attenuation_filter_cutoff_hz < 1000.0,
		"behind a wall: %.0f dB, muffled above %.0f Hz" % [behind.volume_db, behind.attenuation_filter_cutoff_hz])
	var open: AudioStreamPlayer3D = s.play_at(song, Vector3(6, 0, 2))
	check(open != null and s.blocked_of(open) < 0.01 and open.volume_db > -0.01, "in the open: clear (%.0f dB)" % open.volume_db)
	wall.global_position = Vector3(0, 0, 30)     # the wall goes: it clears, eased
	for _i: int in 40:
		await process_frame
	check(s.blocked_of(behind) < 0.5, "the wall moved away: the sound clears (blocked %.2f)" % s.blocked_of(behind))
	s.stop_all()
	wall.queue_free()
	# Volumes: keep what is there, then set odd values for the other process.
	var keep := ConfigFile.new()
	keep.set_value("sound", "music", s.volume("Music"))
	keep.set_value("sound", "animals", s.volume("Animals"))
	DirAccess.make_dir_recursive_absolute("user://test")
	keep.save(KEEP)
	s.set_volume("Music", 0.35)
	s.set_volume("Animals", 0.6)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music at 35% is not muted")
	s.set_volume("Animals", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Animals")), "Animals at 0% is muted")
	s.set_volume("Animals", 0.6)


func _load(s: SoundSystem) -> void:
	check(absf(s.volume("Music") - 0.35) < 0.001, "Music volume came back (%.2f)" % s.volume("Music"))
	check(absf(s.volume("Animals") - 0.6) < 0.001, "Animals volume came back (%.2f)" % s.volume("Animals"))
	var want: float = SoundSystem.BASE_DB["Music"] + linear_to_db(0.35)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - want) < 0.05, "the Music bus is at its slider's level")
	var keep := ConfigFile.new()
	if keep.load(KEEP) == OK:
		s.set_volume("Music", float(keep.get_value("sound", "music", 1.0)))
		s.set_volume("Animals", float(keep.get_value("sound", "animals", 1.0)))
