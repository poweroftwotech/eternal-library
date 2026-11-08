extends SceneTree
## Writes the Lake Landing's warm limestone (phase 18 revised, after the
## Ali-Sadr pictures in design/reference images/caves/):
##   assets/textures/px/limestone.png (+ _normal, _rough): 64 x 160, tiling
##   both ways, for walls. Thick bands of cream, sand, ochre and rust (walk 2:
##   "thicker layers", "repeating too much"): each band's top and bottom wave
##   on their own, so the bands swell and pinch, with thin grey seams and a
##   few hairline cracks. World-mapped at 2 m across and 5 m up a tile
##   (limestone.tres uv1_scale 0.5, 0.2, 0.5), so 32 texels a metre both ways.
##   assets/textures/px/limestone_roof.png (+ _normal, _rough): 64 x 64, the
##   roof's undersides (walk 2: "sediment layers belong on the walls"):
##   cream flowstone, mottled, with soft tan patches and drip spots, no bands.
## Run: --headless --script res://tools/tile_limestone.gd

const DIR: String = "res://assets/textures/px/"
const W: int = 64
const H: int = 160
## The bands, top to bottom: [colour, height in px]. Sums to H.
const BANDS: Array = [
	[Color("e8d9b8"), 26], [Color("8f8272"), 2], [Color("d4b585"), 17], [Color("c08a4c"), 11],
	[Color("e2cda4"), 30], [Color("74685b"), 1], [Color("b5773f"), 8], [Color("dcc69e"), 22],
	[Color("978874"), 2], [Color("cda66c"), 14], [Color("a5643a"), 6], [Color("e6d6b6"), 21],
]


func _init() -> void:
	_walls()
	_roof()
	print("tile_limestone: wrote limestone, limestone_roof (+ normal, rough)")
	quit()


func _walls() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	# Each band boundary waves with its own phase and depth (whole periods
	# across the tile so it wraps): the bands swell and pinch.
	var tops: Array[float] = []
	var acc: float = 0.0
	for b: Array in BANDS:
		tops.append(acc)
		acc += float(b[1])
	var phase: Array[float] = []
	var depth: Array[float] = []
	for _i: int in BANDS.size():
		phase.append(rng.randf_range(0.0, TAU))
		depth.append(rng.randf_range(0.6, 3.2))
	for y: int in H:
		for x: int in W:
			var fx: float = float(x) / W * TAU
			var idx: int = BANDS.size() - 1
			for i: int in BANDS.size():
				var edge: float = tops[i] + depth[i] * sin(fx + phase[i]) + 0.8 * sin(2.0 * fx + phase[i] * 1.7)
				if float(y) >= edge:
					idx = i
			var col: Color = BANDS[idx][0]
			var seam: bool = int(BANDS[idx][1]) <= 2
			var fy: float = float(y) / H * TAU
			var mottle: float = 0.06 * sin(3.0 * fx + 2.0 * fy) + 0.05 * sin(5.0 * fx - 3.0 * fy + 1.3) + rng.randf_range(-0.05, 0.05)
			col = col.lightened(maxf(mottle, 0.0)).darkened(maxf(-mottle, 0.0))
			img.set_pixel(x, y, col)
			h[y * W + x] = (0.2 if seam else 0.6) + mottle
	_cracks(img, h, W, H, rng, 6, 0.45)
	_save(img, h, W, H, "limestone")


func _roof() -> void:
	var s: int = 64
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var base := Color("dcc8a2")
	var tan := Color("b8915e")
	for y: int in s:
		for x: int in s:
			var fx: float = float(x) / s * TAU
			var fy: float = float(y) / s * TAU
			# Soft tan patches (whole periods so it wraps), mottled cream.
			var patch: float = 0.5 + 0.3 * sin(fx + 0.4) * sin(fy + 1.1) + 0.2 * sin(2.0 * fx + fy + 2.0)
			var col: Color = base.lerp(tan, clampf((patch - 0.55) * 1.6, 0.0, 0.7))
			var mottle: float = 0.05 * sin(4.0 * fx + 3.0 * fy) + rng.randf_range(-0.06, 0.06)
			col = col.lightened(maxf(mottle, 0.0)).darkened(maxf(-mottle, 0.0))
			img.set_pixel(x, y, col)
			h[y * s + x] = 0.5 + patch * 0.3 + mottle
	# Drip spots: small darker rings where water gathers.
	for _d: int in 9:
		var cx: int = rng.randi_range(0, s - 1)
		var cy: int = rng.randi_range(0, s - 1)
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var px: int = (cx + dx + s) % s
				var py: int = (cy + dy + s) % s
				var c: Color = img.get_pixel(px, py)
				img.set_pixel(px, py, c.darkened(0.12 if dx != 0 or dy != 0 else 0.3))
				h[py * s + px] -= 0.15
	_cracks(img, h, s, s, rng, 2, 0.3)
	_save(img, h, s, s, "limestone_roof")


func _cracks(img: Image, h: PackedFloat32Array, w: int, ht: int, rng: RandomNumberGenerator, n: int, dark: float) -> void:
	for _c: int in n:
		var x: int = rng.randi_range(0, w - 1)
		var y: int = rng.randi_range(0, ht - 1)
		for _k: int in rng.randi_range(6, 18):
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(dark))
			h[y * w + x] = 0.05
			y = (y + 1) % ht
			x = (x + rng.randi_range(-1, 1) + w) % w


func _save(img: Image, h: PackedFloat32Array, w: int, ht: int, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(DIR + name + ".png"))
	var n := Image.create(w, ht, false, Image.FORMAT_RGB8)
	var r := Image.create(w, ht, false, Image.FORMAT_RGB8)
	for y: int in ht:
		for x: int in w:
			var hx: float = h[y * w + (x + 1) % w] - h[y * w + (x - 1 + w) % w]
			var hy: float = h[((y + 1) % ht) * w + x] - h[((y - 1 + ht) % ht) * w + x]
			var nv := Vector3(-hx * 1.6, -hy * 1.6, 1.0).normalized()
			n.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
			var g: float = clampf(0.82 - h[y * w + x] * 0.25, 0.0, 1.0)
			r.set_pixel(x, y, Color(g, g, g))
	n.save_png(ProjectSettings.globalize_path(DIR + name + "_normal.png"))
	r.save_png(ProjectSettings.globalize_path(DIR + name + "_rough.png"))
