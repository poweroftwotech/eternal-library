extends SceneTree
## Pixel-art materials, part 2 (ART_DIRECTION.md backlog 2). Same rules as
## tools/pixel_materials.py: 32 texels/m, 4-8 colour palettes, ordered
## dithering, baked bevels, per-texel normal and roughness. Written in GDScript
## so it runs without Python:
##   godot --headless --path . --script res://tools/pixel_materials_ext.gd
## Writes assets/textures/px/<name>{,_normal,_rough}.png and
## px/manifest_ext.json, which asset_factory.gd merges over manifest.json.
##
## Mappings: "world" = world triplanar at 32 texels/m (tile size in texels),
## "card" = alpha foliage card on its own UVs. Cards are 0.1-0.2 m wide, so
## they are authored at about 64 texels/m (2x the rule) to keep a readable
## leaf silhouette; that is the one documented exception.

const OUT: String = "res://assets/textures/px/"
const BAYER: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

var manifest: Dictionary = {}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	props()
	fabrics()
	books()
	architecture()
	foliage()
	var file: FileAccess = FileAccess.open(OUT + "manifest_ext.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"texel_density": 32, "materials": manifest}, " "))
	file.close()
	print("wrote %d pixel materials to %s" % [manifest.size(), OUT])
	quit()

# ------------------------------------------------------------------ helpers
func pal(codes: Array) -> PackedColorArray:
	var result: PackedColorArray = PackedColorArray()
	for code: String in codes:
		result.append(Color(code))
	return result

## Tileable value noise in 0..1, smoothstep-interpolated lattice (as the .py).
func noise(w: int, h: int, cell: int, seed_value: int, octaves: int = 3) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var total: PackedFloat32Array = PackedFloat32Array()
	total.resize(w * h)
	var amp: float = 1.0
	var norm: float = 0.0
	for o: int in range(octaves):
		var c: int = maxi(1, cell >> o)
		var gw: int = maxi(1, w / c)
		var gh: int = maxi(1, h / c)
		var grid: PackedFloat32Array = PackedFloat32Array()
		grid.resize(gw * gh)
		for i: int in range(gw * gh):
			grid[i] = rng.randf()
		for y: int in range(h):
			var fy_raw: float = float(y) * gh / h
			var y0: int = int(fy_raw)
			var fy: float = fy_raw - y0
			fy = fy * fy * (3.0 - 2.0 * fy)
			for x: int in range(w):
				var fx_raw: float = float(x) * gw / w
				var x0: int = int(fx_raw)
				var fx: float = fx_raw - x0
				fx = fx * fx * (3.0 - 2.0 * fx)
				var a: float = grid[(y0 % gh) * gw + x0 % gw]
				var b: float = grid[(y0 % gh) * gw + (x0 + 1) % gw]
				var c2: float = grid[((y0 + 1) % gh) * gw + x0 % gw]
				var d: float = grid[((y0 + 1) % gh) * gw + (x0 + 1) % gw]
				total[y * w + x] += amp * (lerpf(lerpf(a, b, fx), lerpf(c2, d, fx), fy))
		norm += amp
		amp *= 0.5
	for i: int in range(w * h):
		total[i] /= norm
	return total

## Palette index for a 0..1 value with ordered dithering.
func quant(value: float, palette: PackedColorArray, x: int, y: int, dither: float = .35) -> Color:
	var n: int = palette.size()
	var bayer: float = BAYER[y % 4][x % 4] / 16.0 - .5
	return palette[clampi(int(floor(value * n + bayer * dither)), 0, n - 1)]

func save(material_name: String, w: int, h: int, rgb: PackedColorArray, height: PackedFloat32Array,
		rough: PackedFloat32Array, mapping: String = "world", strength: float = 2.0, alpha: PackedByteArray = PackedByteArray()) -> void:
	var albedo: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8 if alpha.size() > 0 else Image.FORMAT_RGB8)
	var normal: Image = Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var roughness: Image = Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var c: Color = rgb[i].clamp()
			if alpha.size() > 0:
				c.a = alpha[i] / 255.0
			albedo.set_pixel(x, y, c)
			var dx: float = (height[y * w + (x + 1) % w] - height[y * w + (x - 1 + w) % w]) * strength
			var dy: float = (height[((y + 1) % h) * w + x] - height[((y - 1 + h) % h) * w + x]) * strength
			var n: Vector3 = Vector3(-dx, dy, 1.0).normalized() * .5 + Vector3.ONE * .5
			normal.set_pixel(x, y, Color(n.x, n.y, n.z))
			var r: float = clampf(rough[i], 0.0, 1.0)
			roughness.set_pixel(x, y, Color(r, r, r))
	var base: String = ProjectSettings.globalize_path(OUT + material_name)
	albedo.save_png(base + ".png")
	normal.save_png(base + "_normal.png")
	roughness.save_png(base + "_rough.png")
	manifest[material_name] = {"size": [w, h], "mapping": mapping}

func filled(count: int, value: float) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count)
	result.fill(value)
	return result

# ---------------------------------------------------------------- generators
## Mottled surface with optional bright specks and horizontal bands
## (rings on roots, growth lines on vines).
func mottled(material_name: String, palette: PackedColorArray, size: int = 16, cell: int = 4, seed_value: int = 1,
		contrast: float = 1.0, specks: float = 0.0, speck_color: Color = Color(0, 0, 0, 0), rough_base: float = .88,
		bands: int = 0, metal: bool = false) -> void:
	var w: int = size
	var h: int = size
	var grain: PackedFloat32Array = noise(w, h, cell, seed_value)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 1, 1)
	var speck_field: PackedFloat32Array = noise(w, h, 1, seed_value + 5, 1)
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var g: float = grain[i] * .65 + fine[i] * .35
			var v: float = .5 + (g - .5) * 1.6 * contrast
			var groove: bool = bands > 0 and y % bands == 0
			if groove:
				v -= .3
			elif bands > 0 and y % bands == 1:
				v += .12
			var c: Color = quant(clampf(v, 0.0, .999), palette, x, y)
			var speck: bool = specks > 0.0 and speck_field[i] > 1.0 - specks
			if speck:
				c = speck_color if speck_color.a > 0.0 else palette[palette.size() - 1]
			rgb.append(c)
			height.append(0.0 if groove else g * .8 + (.2 if speck else 0.0))
			rough.append(rough_base + (g - .5) * (.2 if metal else .1))
	save(material_name, w, h, rgb, height, rough, "world", 1.6)

## Two-texel weave with colour stripes (wool cloth, bedroll).
func woven(material_name: String, stripes: PackedColorArray, widths: Array, size: int = 32, seed_value: int = 1) -> void:
	var w: int = size
	var h: int = size
	var grain: PackedFloat32Array = noise(w, h, 4, seed_value)
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var stripe_of_row: Array = []
	var k: int = 0
	while stripe_of_row.size() < h:
		for _r: int in range(widths[k % widths.size()]):
			stripe_of_row.append(k % stripes.size())
		k += 1
	for y: int in range(h):
		for x: int in range(w):
			var weft: bool = (x + y) % 2 == 0
			var c: Color = stripes[stripe_of_row[y]]
			var shade: float = (1.06 if weft else .9) * (.92 + grain[y * w + x] * .16)
			# One-texel shadow under each stripe change reads as a woven ridge.
			if y > 0 and stripe_of_row[y] != stripe_of_row[y - 1]:
				shade *= .78
			rgb.append(Color(c.r * shade, c.g * shade, c.b * shade))
			height.append(.6 + (.25 if weft else 0.0))
	save(material_name, w, h, rgb, height, filled(w * h, .97), "world", 1.0)

## Cobalt / turquoise faience, one tessera per texel (exterior piers).
func faience(material_name: String, seed_value: int) -> void:
	var p: PackedColorArray = pal(["#0b1a2c", "#13335a", "#1d4c82", "#2b6aa6", "#1f7470", "#2f9690", "#e2b866", "#efe0b8"])
	var w: int = 32
	var h: int = 32
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var idx: int = 2 if (x + y) % 2 == 0 else 1
			if rng.randf() < .12:
				idx = 3
			var d: float = absf((x % 16) - 7.5) + absf((y % 16) - 7.5)
			if d > 6.0 and d <= 7.5:
				idx = 6
			elif d > 3.5 and d <= 4.5:
				idx = 5
			elif d <= 2.0:
				idx = 7
			elif d <= 3.0:
				idx = 4
			if x % 16 == 0 or y % 16 == 0:
				idx = 0
			var c: Color = p[idx] * (.92 + rng.randf() * .16)
			rgb.append(c)
			height.append(.2 if idx == 0 else .8 + rng.randf() * .15)
			rough.append(.95 if idx == 0 else .38 + rng.randf() * .15)
	save(material_name, w, h, rgb, height, rough)

# ------------------------------------------------------------------ sets
func props() -> void:
	mottled("mushroom", pal(["#2a1a10", "#4a2f1c", "#6b4428", "#8a5a36", "#a8774c", "#c49a6c"]), 16, 4, 31,
		1.1, .05, Color("e0c9a0"))
	mottled("root", pal(["#5a3e24", "#7a5a38", "#a0805a", "#bfa070", "#d6bc8e", "#e8d6ae"]), 16, 4, 32,
		.9, .0, Color(0, 0, 0, 0), .9, 4)
	mottled("fruit_skin", pal(["#6a3410", "#924a16", "#b8661e", "#d8882c", "#eaa848", "#f4c870"]), 16, 4, 33,
		1.0, .04, Color("f8e0a0"), .8)
	mottled("pomegranate", pal(["#2a0808", "#4e1010", "#741a16", "#982620", "#b8402c", "#d06046"]), 16, 4, 34,
		1.0, .04, Color("e89a78"), .78)
	mottled("cut_fruit", pal(["#9a5a28", "#c07c3c", "#d8a058", "#ecc480", "#f6dca8"]), 16, 3, 35,
		.9, .12, Color("a01818"), .7)
	mottled("copper", pal(["#3a1a0c", "#5e2c14", "#86421e", "#a8582a", "#c8743a", "#e09858"]), 16, 4, 36,
		1.1, .03, Color("3a8a78"), .5, 0, true)
	mottled("brass", pal(["#3a2a12", "#5e4620", "#86662e", "#a8843e", "#c8a458", "#e0c47a"]), 16, 4, 37,
		1.0, .02, Color("f4e0a0"), .45, 0, true)
	mottled("vine", pal(["#1c2412", "#2c3a1a", "#3e4e22", "#52632c", "#6a7838"]), 16, 3, 38,
		1.1, .0, Color(0, 0, 0, 0), .9, 5)
	# Hero props (tools/build_props.py): pale cut ends, charred tips, stew.
	mottled("log_end", pal(["#6a4a2c", "#8c6a44", "#a8845a", "#c4a070", "#d8bc8c"]), 16, 3, 39,
		.9, .0, Color(0, 0, 0, 0), .9, 3)
	mottled("char", pal(["#0c0907", "#16100c", "#211812", "#2c2018", "#3a2a1e"]), 16, 3, 40,
		1.2, .05, Color("c8501c"), .95)
	mottled("stew", pal(["#5a1e0c", "#7a2c12", "#96401a", "#b05624", "#c46e30", "#d88a44"]), 16, 3, 43,
		1.0, .08, Color("5a7a2c"), .25)

func fabrics() -> void:
	# Wool throw: oatmeal/olive ground, thin madder and ochre bands.
	woven("cloth", pal(["#6a5a44", "#7a6a50", "#5a4a38", "#7c2a1c", "#7a6a50", "#c8913f"]), [6, 5, 4, 2, 5, 2], 32, 41)
	# Bedroll (concept): broad madder / cream / umber stripes.
	woven("linen", pal(["#7c2a1c", "#c8b08a", "#3a2a1e", "#9c3a22", "#c8b08a", "#5a1d14"]), [5, 3, 2, 6, 3, 3], 32, 42)

func books() -> void:
	# Leather is tinted per book by vertex colour; the map keeps the legacy
	# mean (151,124,92) with low contrast so grain never bridges books.
	mottled("book_leather", pal(["#7e6448", "#8a6e50", "#967a5a", "#a08462", "#ac8e6a"]), 16, 3, 51, .55)
	# Page block: cream with dark page-gap lines every other texel row.
	var w: int = 8
	var h: int = 8
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var p: PackedColorArray = pal(["#4a3e28", "#8a7650", "#9e8a60", "#7c6a48"])
	for y: int in range(h):
		for x: int in range(w):
			var gap: bool = y % 2 == 1
			rgb.append(p[0] if gap and (x + y / 2) % 3 != 0 else p[1 + (x * 7 + y * 3) % 3])
			height.append(.4 if gap else .8)
	save("pages", w, h, rgb, height, filled(w * h, .92), "world", 1.0)
	stack_atlas()

## Full-height book wall: 2 m tile, a shelf every 0.5 m (16 texels), books
## 1-3 texels wide, each one flat colour with a lit left edge.
func stack_atlas() -> void:
	var w: int = 64
	var h: int = 64
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 52
	var spines: PackedColorArray = pal(["#5a1d14", "#7c2a1c", "#3a2a1e", "#6a4828", "#203a5a", "#1f5a58", "#4a5a2a", "#8a6a3c", "#2a1a12", "#9c7a4a"])
	var plank: PackedColorArray = pal(["#1a110a", "#3b2716", "#6a4828"])
	var rgb: PackedColorArray = PackedColorArray()
	rgb.resize(w * h)
	var height: PackedFloat32Array = filled(w * h, .5)
	for shelf: int in range(h / 16):
		var y0: int = shelf * 16
		var x: int = 0
		while x < w:
			var bw: int = rng.randi_range(1, 3)
			var top: int = y0 + rng.randi_range(2, 5)
			var c: Color = spines[rng.randi() % spines.size()]
			for xx: int in range(x, mini(x + bw, w)):
				for yy: int in range(y0, y0 + 14):
					var i: int = yy * w + xx
					if yy < top:
						rgb[i] = Color("0c0907")   # dark gap above the book
						height[i] = 0.0
					else:
						var shade: float = 1.18 if xx == x else (.82 if xx == x + bw - 1 and bw > 1 else 1.0)
						if yy == top + 2 or yy == y0 + 11:
							shade *= .7   # gilt-less band across the spine
						rgb[i] = c * shade * 1.25
						height[i] = .8
			x += bw
		for xx: int in range(w):
			rgb[(y0 + 14) * w + xx] = plank[2]
			rgb[(y0 + 15) * w + xx] = plank[1] if xx % 16 else plank[0]
			height[(y0 + 14) * w + xx] = 1.0
			height[(y0 + 15) * w + xx] = .9
	save("stack_atlas", w, h, rgb, height, filled(w * h, .9), "world", 1.5)

func architecture() -> void:
	faience("exterior_faience", 61)

# ------------------------------------------------------------------ foliage
## Alpha card from an SDF-style inside test. Lit top-left rim, shadow
## bottom-right rim, midrib and side veins, 4-5 green tones.
func card(material_name: String, w: int, h: int, inside: Callable, seed_value: int, side_veins: bool = true) -> void:
	var p: PackedColorArray = pal(["#24331a", "#36481f", "#4a5f28", "#5f7732", "#7a8f40"])
	var vein: Color = Color("8e9a52")
	var grain: PackedFloat32Array = noise(w, h, 3, seed_value, 2)
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(h):
		for x: int in range(w):
			var u: float = (x + .5) / w
			var v: float = (y + .5) / h
			var is_in: bool = inside.call(u, v)
			alpha.append(255 if is_in else 0)
			if not is_in:
				rgb.append(p[1])
				height.append(0.0)
				continue
			var left_out: bool = not inside.call(u - 1.0 / w, v) or not inside.call(u, v - 1.0 / h)
			var right_out: bool = not inside.call(u + 1.0 / w, v) or not inside.call(u, v + 1.0 / h)
			var value: float = .35 + grain[y * w + x] * .4 + (.12 if u < .5 else -.05)
			if left_out:
				value += .3
			elif right_out:
				value -= .3
			var c: Color = quant(clampf(value, 0.0, .999), p, x, y, .5)
			var mid: bool = absf(u - .5) < .5 / w + .001 and v > .12
			var side: bool = side_veins and absf((v - .9 + absf(u - .5) * .9) * h) < .55 and absf(u - .5) > 1.5 / w and not left_out
			if (mid or side) and not right_out:
				c = vein
			rgb.append(c)
			height.append(.7 if mid else .5)
	save(material_name, w, h, rgb, height, filled(w * h, 1.0), "card", 1.0, alpha)

func foliage() -> void:
	card("ivy_leaf", 16, 16, ivy_shape, 71)
	card("tree_leaf", 16, 16, ovate_shape, 72)
	card("leaf", 8, 16, narrow_shape, 73)
	card("fern", 16, 32, fern_shape, 74, false)

## Ivy: three-lobed star, point up (legacy silhouette).
func ivy_shape(u: float, v: float) -> bool:
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return false
	var q: Vector2 = Vector2(u - .5, v - .52)
	var a: float = atan2(q.x, -q.y)
	return q.length() < .30 + .16 * absf(cos(a * 2.5))

## Tree leaf: broad ovate, tip up.
func ovate_shape(u: float, v: float) -> bool:
	return v > .02 and v < .98 and absf(u - .5) < .44 * sin(PI * pow(clampf(v, 0.0, 1.0), .8))

## Narrow leaf (herbs, garden shrubs).
func narrow_shape(u: float, v: float) -> bool:
	return v > .02 and v < .98 and absf(u - .5) < .46 * sin(PI * clampf(v, 0.0, 1.0))

## Fern frond: midrib plus angled pinnae, tapering to the tip.
func fern_shape(u: float, v: float) -> bool:
	if v < 0.0 or v > 1.0 or u < 0.0 or u > 1.0:
		return false
	var d: float = absf(u - .5)
	if d < .045 and v > .02:
		return true
	var reach: float = .48 * sin(PI * pow(clampf(v, 0.0, 1.0), 1.6))
	return d < reach and fposmod(v * 13.0 + d * 3.0, 1.0) < .5 and v > .04
