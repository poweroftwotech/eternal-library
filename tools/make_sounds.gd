extends SceneTree
## Makes the animals' sounds (phase 20 step 1, Q1: synthesized in the
## project, no recordings, nothing downloaded), as tools/compose_tar.py made
## the music. Writes assets/sounds/<name>.wav (mono, 16 bit, 44.1 kHz); run
## `godot --headless --import` after, so the game can load them.
##   godot --headless --audio-driver Dummy --path . --script res://tools/make_sounds.gd [-- only_stem ...]
##
## Every sound is drawn from its own seed, so a run makes the same files. A
## recording of the same name in assets/sounds/ can replace any of them.
##
## The nightingale (C19) is built the way its song is put together: a phrase
## is a soft lead-in, then one element repeated (the slow rising whistles,
## the fast "jug" notes, a trill, a buzz), then a quick flourish to end;
## phrases come one at a time with a pause between, which the bird keeps
## (BirdBand). Its two voices (a songbird sings with both sides of its
## syrinx) sometimes sound together.

const SR: int = 44100
const OUT: String = "res://assets/sounds/"

var only: PackedStringArray = []


func _initialize() -> void:
	only = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made: int = 0
	for k: int in 12:
		made += _make("nightingale_song_%d" % k, func(r: RandomNumberGenerator) -> PackedFloat32Array: return _nightingale_phrase(r, k), 9100 + k)
	made += _make("nightingale_call_0", _nightingale_call, 9200)
	made += _make("nightingale_call_1", _nightingale_call, 9201)
	made += _make("wings_small_0", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _wings(r, 0.55, 22.0, 0.35), 9300)
	made += _make("wings_small_1", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _wings(r, 0.4, 25.0, 0.3), 9301)
	made += _make("cat_mew_0", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _mew(r, 0.62, 830.0), 9400)     # (walk 2026-11-14 b: a bit higher)
	made += _make("cat_mew_1", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _mew(r, 0.42, 940.0), 9401)
	made += _make("cat_mew_2", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _mew(r, 0.28, 1060.0), 9402)
	made += _make("cat_purr", _purr, 9450, true)
	made += _make("bat_chitter_0", _chitter, 9500)
	made += _make("bat_chitter_1", _chitter, 9501)
	made += _make("bat_chitter_2", _chitter, 9502)
	made += _make("rat_squeak_0", _squeak, 9600)
	made += _make("rat_squeak_1", _squeak, 9601)
	made += _make("rat_scurry_0", _scurry, 9650)
	made += _make("fish_splash_0", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _splash(r, 0.7), 9700)
	made += _make("fish_splash_1", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _splash(r, 1.0), 9701)
	made += _make("fish_splash_2", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _splash(r, 0.45), 9702)
	made += _make("pigeon_coo_0", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _coo(r, 380.0), 9800)
	made += _make("pigeon_coo_1", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _coo(r, 340.0), 9801)
	made += _make("pigeon_coo_2", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _coo(r, 420.0), 9802)
	made += _make("wings_clap_0", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _flock_wings(r, 12, 1.0), 9850)
	made += _make("wings_clap_1", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _flock_wings(r, 9, 1.0), 9851)
	made += _make("wings_flock_0", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _flock_wings(r, 6, 0.35), 9860)
	made += _make("wings_flock_1", func(r: RandomNumberGenerator) -> PackedFloat32Array: return _flock_wings(r, 4, 0.35), 9861)
	print("make_sounds: %d files in %s" % [made, OUT])
	quit()


## Makes one sound unless `only` leaves it out; returns 1 if written.
func _make(name: String, maker: Callable, seed_value: int, loop: bool = false) -> int:
	if not only.is_empty():
		var wanted: bool = false
		for s: String in only:
			if name.begins_with(s):
				wanted = true
		if not wanted:
			return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buf: PackedFloat32Array = maker.call(rng)
	_finish(buf, loop, SPLASH_PEAK if name.begins_with("fish_splash") else 0.8)
	_write(name, buf)
	return 1


# --- the nightingale ------------------------------------------------------------

## One phrase, 1.2 to 3.4 s: lead-in, repeated element, flourish.
func _nightingale_phrase(r: RandomNumberGenerator, k: int) -> PackedFloat32Array:
	var buf := _silence(4.2)
	var t: float = 0.04
	# Lead-in: one to three soft high notes ("tsee"), not every phrase.
	if r.randf() < 0.7:
		for i: int in r.randi_range(1, 3):
			var f: float = r.randf_range(5200.0, 7400.0)
			_tone(buf, t, r.randf_range(0.035, 0.07), f, f * r.randf_range(0.97, 1.04), 0.18 + 0.05 * i)
			t += r.randf_range(0.09, 0.16)
		t += r.randf_range(0.05, 0.14)
	# The repeated element: the kind follows the phrase's number so the twelve
	# cover them all, its details from the seed.
	match k % 6:
		0, 3:
			t = _piu(buf, r, t)
		1:
			t = _jug(buf, r, t)
		2, 5:
			t = _trill(buf, r, t)
		4:
			t = _buzz_run(buf, r, t)
	# The flourish: a rapid up-sweep and a down-sweep, or a buzz, or a click.
	t += r.randf_range(0.03, 0.08)
	match r.randi_range(0, 2):
		0:
			_tone(buf, t, 0.045, 2400.0, 6800.0, 0.6)
			_tone(buf, t + 0.055, 0.07, 7200.0, 2900.0, 0.75)
			t += 0.14
		1:
			_buzz(buf, t, r.randf_range(0.14, 0.26), r.randf_range(2600.0, 3600.0), r.randf_range(140.0, 230.0), 0.5)
			t += 0.28
		_:
			for i: int in 2:
				_tone(buf, t, 0.018, 4800.0, 2600.0, 0.7)
				t += 0.05
	return buf.slice(0, mini(buf.size(), int((t + 0.35) * SR)))


## The slow whistles, rising in loudness: the nightingale's best-known run.
func _piu(buf: PackedFloat32Array, r: RandomNumberGenerator, t: float) -> float:
	var n: int = r.randi_range(4, 8)
	var f: float = r.randf_range(1450.0, 2300.0)
	var dur: float = r.randf_range(0.11, 0.17)
	var gap: float = r.randf_range(0.11, 0.17)
	for i: int in n:
		var loud: float = lerpf(0.22, 0.95, float(i) / maxf(n - 1, 1))
		_tone(buf, t, dur, f * 0.985, f * 1.03, loud, 2)
		if r.randf() < 0.25:     # the second voice a fifth above, faint
			_tone(buf, t + 0.01, dur * 0.8, f * 1.5, f * 1.52, loud * 0.18)
		t += dur + gap
	return t


## Fast, hard "jug" notes: short broad down-sweeps, 12 to 18 a second.
func _jug(buf: PackedFloat32Array, r: RandomNumberGenerator, t: float) -> float:
	var n: int = r.randi_range(6, 12)
	var hi: float = r.randf_range(3800.0, 4800.0)
	var step: float = 1.0 / r.randf_range(12.0, 18.0)
	for i: int in n:
		_tone(buf, t, 0.022, hi, hi * 0.45, 0.8, 3)
		_noise(buf, t, 0.012, 0.12, 2500.0)
		t += step
	return t


## A trill: one small figure (two linked sweeps) repeated quickly.
func _trill(buf: PackedFloat32Array, r: RandomNumberGenerator, t: float) -> float:
	var n: int = r.randi_range(8, 18)
	var a: float = r.randf_range(2800.0, 4200.0)
	var b: float = a * r.randf_range(1.4, 1.9)
	var el: float = r.randf_range(0.032, 0.05)
	var up: bool = r.randf() < 0.5
	for i: int in n:
		var swell: float = sin(PI * (float(i) + 0.5) / n)
		if up:
			_tone(buf, t, el * 0.55, a, b, 0.4 + 0.5 * swell)
			_tone(buf, t + el * 0.55, el * 0.4, b * 0.95, a * 1.1, 0.3 + 0.4 * swell)
		else:
			_tone(buf, t, el * 0.9, b, a, 0.4 + 0.55 * swell)
		t += el + 0.008
	return t


## A short run of buzzy notes with a clear note between.
func _buzz_run(buf: PackedFloat32Array, r: RandomNumberGenerator, t: float) -> float:
	for i: int in r.randi_range(2, 4):
		_buzz(buf, t, r.randf_range(0.12, 0.2), r.randf_range(2400.0, 3400.0), r.randf_range(110.0, 200.0), 0.7)
		t += 0.24
		_tone(buf, t, 0.05, 5200.0, 4600.0, 0.4)
		t += 0.1
	return t


## Alarm: a rising "hweet" then a dry rattle "krrr".
func _nightingale_call(r: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := _silence(0.9)
	_tone(buf, 0.02, 0.11, r.randf_range(2600.0, 3000.0), r.randf_range(4200.0, 4800.0), 0.9, 2)
	var t: float = 0.2
	for i: int in 10:
		_noise(buf, t, 0.012, 0.5, 1800.0)
		_tone(buf, t, 0.01, 1500.0, 1300.0, 0.3)
		t += 0.022
	return buf


## Small wings taking off: soft beats of air, slowing.
func _wings(r: RandomNumberGenerator, dur: float, rate: float, loud: float) -> PackedFloat32Array:
	var buf := _silence(dur + 0.1)
	var t: float = 0.0
	var beat: float = 1.0 / rate
	while t < dur:
		var fade: float = 1.0 - t / dur
		_noise(buf, t, beat * 0.6, loud * (0.4 + 0.6 * fade), 900.0 + r.randf_range(-150.0, 150.0))
		t += beat * (1.0 + t * 0.8)
	return buf


# --- the pigeon (phase 20 step 2) ---------------------------------------------------

## A rock dove's coo: low and round, three parts, "coo, roo-oo, coo". Soft
## short first note; the middle one rises and falls with a flutter in the
## throat; a long low last one. Almost a pure tone (a closed bill, the sound
## made in the inflated throat), so few and weak harmonics, a little breath.
func _coo(r: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var buf := _silence(1.5)
	# [start s, length s, pitch from, peak, to (times `pitch`), loudness, flutter Hz]
	var notes: Array = [[0.02, 0.14, 0.95, 1.0, 0.9, 0.55, 0.0],
		[0.24, 0.42, 0.9, 1.12, 0.92, 1.0, r.randf_range(22.0, 30.0)],
		[0.74, 0.5, 1.0, 1.02, 0.82, 0.8, 0.0]]
	for nt: Array in notes:
		var start: int = int(float(nt[0]) * SR)
		var n: int = int(float(nt[1]) * SR)
		var phase: float = 0.0
		var breath: float = 0.0
		for i: int in n:
			var u: float = float(i) / n
			var f: float = pitch * (lerpf(float(nt[2]), float(nt[3]), smoothstep(0.0, 0.4, u)) if u < 0.4 else lerpf(float(nt[3]), float(nt[4]), smoothstep(0.4, 1.0, u)))
			phase += TAU * f / SR
			var flutter: float = 1.0 - 0.45 * (0.5 + 0.5 * sin(TAU * float(nt[6]) * u * float(nt[1]))) if float(nt[6]) > 0.0 else 1.0
			var env: float = smoothstep(0.0, 0.12, u) * pow(1.0 - u, 0.8) * float(nt[5]) * flutter
			breath += (r.randf_range(-1.0, 1.0) - breath) * 0.05
			var s: float = sin(phase) + 0.18 * sin(phase * 2.0) + 0.05 * sin(phase * 3.0) + breath * 0.15
			buf[start + i] += s * env * 0.6
	return _lowpass(buf, 0.3)


## Pigeons going up together: `birds` each beating hard a few times, the
## first strokes clapping (the wingtips meeting over the back), then the
## whirr of beats fading as they climb away. `clap` 1: alarmed; less: calm.
func _flock_wings(r: RandomNumberGenerator, birds: int, clap: float) -> PackedFloat32Array:
	var buf := _silence(1.6)
	for b: int in birds:
		var t: float = r.randf_range(0.0, 0.25 if clap > 0.5 else 0.6)
		var rate: float = r.randf_range(8.0, 10.5)
		var beats: int = r.randi_range(6, 11)
		for k: int in beats:
			var fade: float = 1.0 - float(k) / beats
			if k < 3:
				# The clap: a short sharp crack of feathers.
				_noise(buf, t, 0.012, (0.5 + 0.5 * r.randf()) * clap * (1.0 - k * 0.3), r.randf_range(1800.0, 3200.0))
			# The stroke: a soft whump of air.
			_noise(buf, t + 0.01, 1.0 / rate * 0.6, 0.35 * fade * (0.6 + 0.4 * r.randf()), r.randf_range(500.0, 900.0), true)
			t += 1.0 / rate * r.randf_range(0.92, 1.08)
	return buf


# --- phase 19's animals ---------------------------------------------------------

## A cat's mew, "m-ee-ah-ow", by its vowels: a voice (harmonics of a pitch
## that rises to the middle and falls away) shaped by three mouth formants
## that move from a closed hum (m) to bright "ee" (high second formant),
## open "ah", and round "ow". (Walk 2026-11-14: the old one began on a low
## closed formant and read as "Wow!"; a mew must begin high and bright.)
const MEW_VOWELS: Array = [
	# [u, F1, F2, F3, loudness]
	[0.00, 300.0, 2000.0, 3300.0, 0.25],    # m: closed, nasal hum
	[0.10, 380.0, 2700.0, 3500.0, 0.75],    # ee
	[0.40, 900.0, 1900.0, 3200.0, 1.00],    # ah
	[0.75, 650.0, 1100.0, 2900.0, 0.70],    # o
	[1.00, 420.0, 800.0, 2700.0, 0.20],     # w: closing
]


func _mew(r: RandomNumberGenerator, dur: float, pitch: float) -> PackedFloat32Array:
	var buf := _silence(dur + 0.15)
	var n: int = int(dur * SR)
	var phase: float = 0.0
	var jitter: float = 0.0
	var breath_lp: float = 0.0
	for i: int in n:
		var u: float = float(i) / n
		# Pitch: up from 0.85 to 1.15 at a third of the way, down to 0.7.
		var contour: float = lerpf(0.85, 1.15, smoothstep(0.0, 0.33, u)) if u < 0.33 else lerpf(1.15, 0.7, smoothstep(0.33, 1.0, u))
		jitter = lerpf(jitter, r.randf_range(-1.0, 1.0), 0.01)
		var f0: float = pitch * contour * (1.0 + 0.01 * jitter + 0.008 * sin(TAU * 5.5 * u * dur))
		phase = fmod(phase + TAU * f0 / SR, TAU * 1000.0)
		var v: Array = _vowel_at(u)
		for k: int in 3:
			v[k] = float(v[k]) * 1.12     # (a cat's mouth is small: its formants sit higher)
		var s: float = 0.0
		for h: int in range(1, 24):
			var fh: float = f0 * h
			if fh > 9500.0:
				break
			# (The pitch itself is weak in a cat's voice: its sound is in the
			# formants, 1-3 kHz; a strong fundamental made a whistled "wow".)
			var g: float = 0.6 / (1.0 + pow((fh - float(v[0])) / 150.0, 2.0)) \
				+ 1.0 / (1.0 + pow((fh - float(v[1])) / 220.0, 2.0)) \
				+ 0.45 / (1.0 + pow((fh - float(v[2])) / 300.0, 2.0))
			var weak_low: float = 0.25 if h == 1 else 1.0
			s += sin(phase * h) * g * weak_low / sqrt(float(h)) * 2.0
		# A little breath in the voice, round the second formant.
		breath_lp += (r.randf_range(-1.0, 1.0) - breath_lp) * 0.3
		s += breath_lp * 0.04
		var env: float = float(v[3]) * minf(1.0, u * 30.0) * minf(1.0, (1.0 - u) * 10.0)
		buf[int(0.02 * SR) + i] += s * env * 0.5
	return buf


## The mouth at `u` (0..1 through the mew): [F1, F2, F3, loudness], eased
## between MEW_VOWELS.
func _vowel_at(u: float) -> Array:
	for k: int in MEW_VOWELS.size() - 1:
		var a: Array = MEW_VOWELS[k]
		var b: Array = MEW_VOWELS[k + 1]
		if u <= float(b[0]):
			var w: float = smoothstep(float(a[0]), float(b[0]), u)
			return [lerpf(a[1], b[1], w), lerpf(a[2], b[2], w), lerpf(a[3], b[3], w), lerpf(a[4], b[4], w)]
	var last: Array = MEW_VOWELS[-1]
	return [last[1], last[2], last[3], last[4]]


## A purr: a low buzz of the throat about 26 times a second, louder breathing
## out than in, about 2.6 s, made to loop.
func _purr(r: RandomNumberGenerator) -> PackedFloat32Array:
	var dur: float = 2.6
	var buf := _silence(dur)
	var n: int = int(dur * SR)
	var lp: float = 0.0
	var lp2: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		var breath: float = 0.55 + 0.45 * sin(TAU * t / 1.3)     # two breaths in the loop
		var rate: float = 24.0 + 3.0 * signf(sin(TAU * t / 1.3))     # (breathing in a little faster)
		var pulse: float = pow(maxf(0.0, sin(TAU * rate * t)), 6.0)
		var x: float = r.randf_range(-1.0, 1.0) * pulse * breath
		lp += (x - lp) * 0.04
		lp2 += (lp - lp2) * 0.06
		buf[i] = lp2 * 6.0 + sin(TAU * rate * 2.0 * t) * pulse * breath * 0.08
	return buf


## Bats: a burst of tiny, high, falling chirps (their social calls; the
## echolocation itself is too high to hear).
func _chitter(r: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := _silence(0.7)
	var t: float = 0.01
	for i: int in r.randi_range(6, 14):
		var f: float = r.randf_range(7500.0, 11000.0)
		_tone(buf, t, r.randf_range(0.006, 0.014), f, f * r.randf_range(0.55, 0.75), r.randf_range(0.4, 1.0))
		t += r.randf_range(0.018, 0.06)
		if t > 0.62:
			break
	return buf


## A rat's squeak: two or three thin notes with a fast wobble.
func _squeak(r: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := _silence(0.5)
	var t: float = 0.01
	for i: int in r.randi_range(2, 3):
		var f: float = r.randf_range(3200.0, 5200.0)
		var d: float = r.randf_range(0.05, 0.12)
		var n: int = int(d * SR)
		var phase: float = 0.0
		for s: int in n:
			var u: float = float(s) / n
			phase += TAU * f * (1.0 + 0.06 * sin(TAU * 38.0 * u * d) + 0.1 * (u - 0.5)) / SR
			var env: float = minf(1.0, u * 25.0) * minf(1.0, (1.0 - u) * 8.0)
			buf[int(t * SR) + s] += (sin(phase) + 0.2 * sin(phase * 2.0)) * env * 0.6
		t += d + r.randf_range(0.03, 0.08)
	return buf


## Small claws on stone: a run of tiny dry ticks.
func _scurry(r: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := _silence(0.6)
	var t: float = 0.0
	while t < 0.5:
		_noise(buf, t, 0.004, r.randf_range(0.2, 0.6), 4000.0)
		t += r.randf_range(0.02, 0.05)
	return buf


## A fish breaking the surface: a "plop" and a few "bloops". Rethought after
## three walks (2026-11-14: a chirp and a slap; a loud slap; "completely off
## base"). Those were noise shaped by hand. What we hear as water is mostly
## air: each pocket of air the fish pulls under rings once as it closes, a
## short note that rises as the bubble nears the surface and dies within tens
## of milliseconds (Minnaert's resonance; the bubble model of van den Doel,
## "Physically based models for liquid sounds", 2005). Its pitch is set by
## its size: 3 mm of radius rings at about 1 kHz. So: one larger bubble for
## the plop, a scatter of smaller ones after it, a soft wash of water under
## them. Listen 4: "closer, but too soft": now as loud as the other sounds,
## the plop with more body (a second big bubble, a fuller wash).
const SPLASH_PEAK: float = 0.8


func _splash(r: RandomNumberGenerator, size: float) -> PackedFloat32Array:
	var buf := _silence(0.6)
	# The plop: one big bubble, 4-8 mm (bigger fish, lower).
	_bubble(buf, 0.0, lerpf(4.5, 7.5, size) * r.randf_range(0.9, 1.1), 1.0)
	_bubble(buf, r.randf_range(0.004, 0.012), lerpf(3.5, 6.0, size) * r.randf_range(0.9, 1.1), 0.7)
	# The bloops after: smaller bubbles, 1.5-4 mm, thinning out.
	var t: float = r.randf_range(0.01, 0.03)
	for i: int in r.randi_range(3, 5) + int(size * 5.0):
		var radius: float = r.randf_range(1.5, 4.0)
		_bubble(buf, t, radius, r.randf_range(0.25, 0.6) * (radius / 4.0))
		t += r.randf_range(0.008, 0.05) * (1.0 + float(i) * 0.4)
		if t > 0.4:
			break
	# A soft wash of water under them (gentle start, dark, short).
	var low: float = 0.0
	var low2: float = 0.0
	var n: int = int((0.12 + 0.12 * size) * SR)
	for i: int in n:
		var u: float = float(i) / n
		low += (r.randf_range(-1.0, 1.0) - low) * 0.08
		low2 += (low - low2) * 0.1
		buf[i] += low2 * 2.0 * smoothstep(0.0, 0.15, u) * pow(1.0 - u, 2.0) * size
	return buf


## One bubble ringing: `radius` in mm, from `at` s. f0 = 3 kHz / radius (mm);
## it decays at d = 0.043 f0 + 0.0014 f0^1.5 per second and its pitch rises
## as it goes (f0 (1 + 0.1 d t)).
func _bubble(buf: PackedFloat32Array, at: float, radius: float, amp: float) -> void:
	var f0: float = 3000.0 / radius
	var d: float = 0.043 * f0 + 0.0014 * pow(f0, 1.5)
	var start: int = int(at * SR)
	var n: int = mini(int(6.0 / d * SR), buf.size() - start)     # rings out by e^-6
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / SR
		phase += TAU * f0 * (1.0 + 0.1 * d * t) / SR
		var attack: float = minf(1.0, t / 0.0015)     # (no click at its start)
		buf[start + i] += sin(phase) * exp(-d * t) * attack * amp


## A one-pole low-pass over the whole sound (`k` 0..1: smaller, darker).
func _lowpass(buf: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y: float = 0.0
	for i: int in buf.size():
		y += (buf[i] - y) * k
		buf[i] = y
	return buf


# --- the parts --------------------------------------------------------------------

func _silence(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * SR))
	b.fill(0.0)
	return b


## A sine note from f0 to f1 Hz (an exponential glide), `at` s for `dur` s,
## with a quick rise and a fall; `harmonics` adds faint overtones (a fuller,
## less electronic note).
func _tone(buf: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float, harmonics: int = 1) -> void:
	var start: int = int(at * SR)
	var n: int = int(dur * SR)
	var phase: float = 0.0
	var ratio: float = f1 / f0
	for i: int in n:
		var j: int = start + i
		if j >= buf.size():
			return
		var u: float = float(i) / n
		phase += TAU * f0 * pow(ratio, u) / SR
		var env: float = minf(1.0, u * 12.0) * pow(minf(1.0, (1.0 - u) * 4.0), 1.5)
		var s: float = sin(phase)
		if harmonics > 1:
			s += 0.12 * sin(phase * 2.0)
		if harmonics > 2:
			s += 0.05 * sin(phase * 3.0)
		buf[j] += s * env * amp


## A buzz: a note at `f` beaten `rate` times a second.
func _buzz(buf: PackedFloat32Array, at: float, dur: float, f: float, rate: float, amp: float) -> void:
	var start: int = int(at * SR)
	var n: int = int(dur * SR)
	for i: int in n:
		var j: int = start + i
		if j >= buf.size():
			return
		var t: float = float(i) / SR
		var u: float = float(i) / n
		var env: float = minf(1.0, u * 10.0) * minf(1.0, (1.0 - u) * 5.0)
		buf[j] += sin(TAU * f * t) * pow(0.5 + 0.5 * sin(TAU * rate * t), 3.0) * env * amp


## A burst of noise round `centre` Hz (a two-pole band), falling away
## (`slow`: a softer, longer fall, like water).
func _noise(buf: PackedFloat32Array, at: float, dur: float, amp: float, centre: float, slow: bool = false) -> void:
	var start: int = int(at * SR)
	var n: int = int(dur * SR)
	# A resonant band-pass (state-variable filter).
	var fq: float = 2.0 * sin(PI * minf(centre, SR * 0.2) / SR)
	var q: float = 0.9
	var low: float = 0.0
	var band: float = 0.0
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = hash([at, dur, centre])
	for i: int in n:
		var j: int = start + i
		if j >= buf.size():
			return
		var u: float = float(i) / n
		var x: float = seed_rng.randf_range(-1.0, 1.0)
		low += fq * band
		var high: float = x - low - q * band
		band += fq * high
		var env: float = (pow(1.0 - u, 1.5) if slow else exp(-u * 5.0)) * minf(1.0, u * 40.0)
		buf[j] += band * env * amp


## Peak to `top`, the end faded so it never clicks; a loop's two ends crossfaded.
func _finish(buf: PackedFloat32Array, loop: bool, top: float = 0.8) -> void:
	var peak: float = 0.0001
	for x: float in buf:
		peak = maxf(peak, absf(x))
	var g: float = top / peak
	for i: int in buf.size():
		buf[i] *= g
	if loop:
		var fade: int = int(0.12 * SR)
		for i: int in fade:
			var u: float = float(i) / fade
			var a: float = buf[i]
			var b: float = buf[buf.size() - fade + i]
			buf[i] = a * u + b * (1.0 - u)
		buf.resize(buf.size() - fade)
	else:
		var tail: int = mini(int(0.01 * SR), buf.size())
		for i: int in tail:
			buf[buf.size() - 1 - i] *= float(i) / tail


func _write(name: String, buf: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i: int in buf.size():
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	var err: int = wav.save_to_wav(ProjectSettings.globalize_path(OUT + name + ".wav"))
	print("  %s  %.2f s%s" % [name, float(buf.size()) / SR, "" if err == OK else "  ERROR %d" % err])
