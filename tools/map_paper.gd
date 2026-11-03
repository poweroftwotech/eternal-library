extends SceneTree
## Makes the map's sheet of paper (phase 11, Q1: the look of the mock):
## blotchy toning, fibres, foxing, water stains, a fold crease, scorched and
## torn edges, quantised to a few tones with ordered dither so it reads as
## pixel art when drawn at 2x (MapPage draws the map at half resolution).
##   godot --headless --path . --script res://tools/map_paper.gd -- [out]
## out: res://assets/textures/map_paper.png. Run --import afterwards.

const DEFAULT_OUT: String = "res://assets/textures/map_paper.png"
const W: int = 768
const H: int = 432
const TONES: Array[Color] = [
	Color("3b2a17"), Color("5e4426"), Color("7d5f37"), Color("9a7c4c"),
	Color("b39563"), Color("c6aa77"), Color("d4bb8a"), Color("dfca9c"), Color("e8d7ad"),
]
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else DEFAULT_OUT
	var err: Error = make().save_png(out)
	print("map_paper: %s (%s)" % [out, error_string(err)])
	quit(0 if err == OK else 1)


static func make() -> Image:
	var blotch := FastNoiseLite.new()
	blotch.seed = 11
	blotch.frequency = 0.0094
	blotch.fractal_octaves = 4
	var grain := FastNoiseLite.new()
	grain.seed = 3
	grain.noise_type = FastNoiseLite.TYPE_VALUE
	grain.frequency = 0.35
	var fibre := FastNoiseLite.new()
	fibre.seed = 5
	fibre.frequency = 0.04
	fibre.fractal_octaves = 2
	var edge := FastNoiseLite.new()
	edge.seed = 9
	edge.frequency = 0.05
	edge.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var spots: Array[Vector3] = []
	for i: int in 110:
		spots.append(Vector3(rng.randf() * W, rng.randf() * H, rng.randf_range(0.6, 2.6)))
	var stains: Array[Vector3] = [Vector3(W - 104, H - 64, 52), Vector3(90, 76, 32), Vector3(W * 0.55, 50, 22)]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y: int in H:
		for x: int in W:
			var v: float = 0.68
			v += blotch.get_noise_2d(x, y) * 0.22
			v += grain.get_noise_2d(x, y) * 0.07
			v += fibre.get_noise_2d(x * 0.25, y * 3.0) * 0.05          # long fibres
			# scorched edges, uneven
			var d: float = minf(minf(x, W - 1 - x), minf(y, H - 1 - y))
			var burn: float = d + edge.get_noise_2d(x, y) * 16.0
			v -= clampf(1.0 - burn / 56.0, 0.0, 1.0) * 0.45
			# a fold down the middle and a fainter one across
			var cx: float = absf(x - W * 0.5 + edge.get_noise_2d(0, y) * 2.0)
			v -= clampf(1.0 - cx / 2.5, 0.0, 1.0) * 0.16
			v += clampf(1.0 - absf(cx - 3.0) / 2.0, 0.0, 1.0) * 0.05
			var cy: float = absf(y - H * 0.36 + edge.get_noise_2d(x, 50) * 2.0)
			v -= clampf(1.0 - cy / 2.0, 0.0, 1.0) * 0.08
			for s: Vector3 in spots:     # foxing
				var sd: float = Vector2(x - s.x, y - s.y).length()
				if sd < s.z * 2.2:
					v -= clampf(1.0 - sd / (s.z * 2.2), 0.0, 1.0) * 0.22
			for s: Vector3 in stains:    # water stains: pale inside, a dark tide ring
				var r: float = Vector2(x - s.x, (y - s.y) * 1.1).length() + blotch.get_noise_2d(x * 3.0, y * 3.0) * 6.0
				if r < s.z:
					v += 0.03
				v -= clampf(1.0 - absf(r - s.z) / 2.2, 0.0, 1.0) * 0.18
			var t: float = clampf(v, 0.0, 1.0) * (TONES.size() - 1)
			var th: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			var c: Color = TONES[clampi(int(floor(t)) + (1 if fmod(t, 1.0) > th else 0), 0, TONES.size() - 1)]
			if d + edge.get_noise_2d(x * 2.0, y * 2.0) * 7.0 < 3.0:
				c.a = 0.0     # torn edge
			img.set_pixel(x, y, c)
	return img
