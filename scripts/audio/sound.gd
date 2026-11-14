class_name SoundSystem
extends Node
## Sound in the game (phase 20 step 1, docs/npc/phase-20-approval.md): the
## autoload "Sound". Two volumes you set in the menu (Music, Animals), each a
## bus of its own; sounds that come from a place in the world, louder near and
## quieter far; and a limit on how many play at once (Q4: the nearest
## MAX_VOICES, none further than its reach, 25 m unless the sound says more).
##
## Animals call Sound.play_at(...) with a stream from Sound.clip(...). The
## sounds themselves are made by tools/make_sounds.gd (Q1: synthesized in the
## project, no recordings); each is a file in assets/sounds/ and can be
## swapped for a recording of the same name.
##
## Volumes live in user://settings.cfg (section "sound"), not in the save:
## they are yours, not the world's.

const SETTINGS_PATH: String = "user://settings.cfg"
const DIR: String = "res://assets/sounds/%s.wav"
const BUSES: PackedStringArray = ["Music", "Animals"]
## Each bus's level at 100% on its slider (dB): the music sits under the world.
const BASE_DB: Dictionary = {"Music": -14.0, "Animals": -4.0}
const MAX_VOICES: int = 12
## Nothing is started further than this (m), unless the call says more.
const REACH: float = 25.0
## Behind a wall (walk 2026-11-14: the nightingale came through the zoo's
## walls as if they weren't there): quieter by this (dB) and muffled, the
## high sounds gone above OCCLUDED_HZ. Checked for each voice every
## OCCLUSION_S with a ray from your ear to the sound, eased so a voice
## never jumps.
const OCCLUDED_DB: float = -12.0
const OCCLUDED_HZ: float = 900.0
const CLEAR_HZ: float = 9000.0
const OCCLUSION_S: float = 0.1

## Bus -> slider value (0..1).
var volumes: Dictionary = {"Music": 1.0, "Animals": 1.0}
## Sounds started and refused (out of reach, or nearer ones playing), for F3.
var stats: Dictionary = {"started": 0, "refused": 0, "stolen": 0}

var _voices: Array[AudioStreamPlayer3D] = []
var _clips: Dictionary = {}
## Voice -> {db: as asked, block: 0 clear .. 1 behind a wall (eased), want}.
var _occ: Dictionary = {}
var _occ_clock: float = 0.0


## The autoload, found at run time (test scripts compile before autoload
## names exist, so nothing names "Sound" directly). Null outside the game.
static func it() -> SoundSystem:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sound") as SoundSystem if tree != null else null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	# Stone rooms: a short, quiet reflection on the animals, so a song in a
	# vaulted court doesn't sound as if it were sung into a pillow.
	var animals: int = AudioServer.get_bus_index("Animals")
	if AudioServer.get_bus_effect_count(animals) == 0:
		var verb := AudioEffectReverb.new()
		verb.room_size = 0.45
		verb.damping = 0.6
		verb.spread = 0.8
		verb.wet = 0.12
		verb.dry = 1.0
		verb.predelay_msec = 18.0
		AudioServer.add_bus_effect(animals, verb)
	_load_volumes()
	for k: int in MAX_VOICES:
		var v := AudioStreamPlayer3D.new()
		v.name = "Voice%d" % k
		v.bus = "Animals"
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		v.unit_size = 3.0
		v.max_distance = REACH
		v.panning_strength = 0.8
		v.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		v.attenuation_filter_cutoff_hz = 9000.0
		v.attenuation_filter_db = -12.0
		add_child(v)
		_voices.append(v)


## The sound `name` (assets/sounds/<name>.wav), loaded once; null if it isn't
## there (a sound not made yet is silence, never an error).
func clip(name: String) -> AudioStream:
	if _clips.has(name):
		return _clips[name]
	var path: String = DIR % name
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_clips[name] = s
	return s


## Every sound whose name starts with `stem` (stem_0, stem_1 …), loaded once.
func clips(stem: String) -> Array[AudioStream]:
	var key: String = stem + "*"
	if _clips.has(key):
		return _clips[key]
	var out: Array[AudioStream] = []
	for k: int in 32:
		var s: AudioStream = clip("%s_%d" % [stem, k])
		if s == null:
			break
		out.append(s)
	_clips[key] = out
	return out


## Plays `stream` from `at` (global). `reach`: heard up to this far (m);
## `db`: louder or quieter than as made; `pitch`: 1 as made. Returns the voice
## playing it (to stop it or follow its animal), or null when it wasn't
## started: too far, or every voice is busy with a nearer sound.
func play_at(stream: AudioStream, at: Vector3, reach: float = REACH, db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var ear: Vector3 = _ear()
	var dist: float = ear.distance_to(at)
	if dist > reach:
		stats["refused"] = int(stats["refused"]) + 1
		return null
	var voice: AudioStreamPlayer3D = null
	var farthest: float = -1.0
	var far_voice: AudioStreamPlayer3D = null
	for v: AudioStreamPlayer3D in _voices:
		if not v.playing:
			voice = v
			break
		var d: float = ear.distance_to(v.global_position)
		if d > farthest:
			farthest = d
			far_voice = v
	if voice == null:
		# All busy: the farthest gives way, if it is further than this one.
		if far_voice == null or farthest <= dist:
			stats["refused"] = int(stats["refused"]) + 1
			return null
		far_voice.stop()
		voice = far_voice
		stats["stolen"] = int(stats["stolen"]) + 1
	voice.stream = stream
	voice.global_position = at
	voice.max_distance = reach
	voice.pitch_scale = pitch
	# Behind a wall from the start (a short squeak has no time to ease in).
	var blocked: float = 1.0 if _blocked(ear, at) else 0.0
	_occ[voice] = {"db": db, "block": blocked, "want": blocked}
	_apply(voice)
	voice.play()
	stats["started"] = int(stats["started"]) + 1
	return voice


## One of the sounds `stem`_0, _1 … (at random), from `at`; `chance`: how
## often it is heard at all. For an animal's moment (a rat bolting, bats
## taking off): Sound.cue("rat_squeak", where, 15.0). Safe outside the game.
static func cue(stem: String, at: Vector3, reach: float = REACH, db: float = 0.0, chance: float = 1.0, pitch_spread: float = 0.06) -> AudioStreamPlayer3D:
	var s: SoundSystem = it()
	if s == null or randf() >= chance:
		return null
	var all: Array[AudioStream] = s.clips(stem)
	var one: AudioStream = all[randi() % all.size()] if not all.is_empty() else s.clip(stem)
	return s.play_at(one, at, reach, db, 1.0 + randf_range(-pitch_spread, pitch_spread))


## Voices playing now.
func playing() -> int:
	var n: int = 0
	for v: AudioStreamPlayer3D in _voices:
		if v.playing:
			n += 1
	return n


## Stops every animal sound (a place unloading, the game quitting).
func stop_all() -> void:
	for v: AudioStreamPlayer3D in _voices:
		v.stop()


func _process(delta: float) -> void:
	_occ_clock += delta
	var check: bool = _occ_clock >= OCCLUSION_S
	if check:
		_occ_clock = 0.0
	var ear: Vector3 = _ear()
	for v: AudioStreamPlayer3D in _voices:
		if not v.playing or not _occ.has(v):
			continue
		var o: Dictionary = _occ[v]
		if check:
			o["want"] = 1.0 if _blocked(ear, v.global_position) else 0.0
		o["block"] = move_toward(float(o["block"]), float(o["want"]), delta * 4.0)
		_apply(v)


## Is there world (walls, floors, rock) between `ear` and `at`? The last
## 0.6 m at the sound's end doesn't count: an animal sits on a branch, on a
## ledge, in water, against a wall.
func _blocked(ear: Vector3, at: Vector3) -> bool:
	var world: World3D = get_viewport().world_3d if get_viewport() != null else null
	if world == null or ear.distance_to(at) < 0.8:
		return false
	var to: Vector3 = at + (ear - at).normalized() * 0.6
	var q := PhysicsRayQueryParameters3D.create(ear, to, LaneGraph.WORLD)
	return not world.direct_space_state.intersect_ray(q).is_empty()


## Sets a voice's loudness and muffling from how blocked it is.
func _apply(v: AudioStreamPlayer3D) -> void:
	var o: Dictionary = _occ[v]
	var b: float = o["block"]
	v.volume_db = float(o["db"]) + OCCLUDED_DB * b
	v.attenuation_filter_cutoff_hz = lerpf(CLEAR_HZ, OCCLUDED_HZ, b)
	v.attenuation_filter_db = lerpf(-12.0, -40.0, b)


## How blocked (0..1) the voice is, for tests and F3.
func blocked_of(v: AudioStreamPlayer3D) -> float:
	return float(_occ[v]["block"]) if _occ.has(v) else 0.0


## Where you hear from: the camera.
func _ear() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	return cam.global_position if cam != null else Vector3.ZERO


# --- volumes ---------------------------------------------------------------------

## Sets bus `bus` to `value` (0..1, the slider) and remembers it.
func set_volume(bus: String, value: float, save: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	volumes[bus] = value
	var i: int = AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_mute(i, value <= 0.001)
		AudioServer.set_bus_volume_db(i, float(BASE_DB.get(bus, 0.0)) + linear_to_db(maxf(value, 0.001)))
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)     # (other settings in the file are kept)
		cfg.set_value("sound", bus.to_lower(), value)
		cfg.save(SETTINGS_PATH)


func volume(bus: String) -> float:
	return float(volumes.get(bus, 1.0))


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for bus: String in BUSES:
		set_volume(bus, float(cfg.get_value("sound", bus.to_lower(), 1.0)), false)
