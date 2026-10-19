extends SceneTree
## Pixel-art materials, part 2 (ART_DIRECTION.md backlog 2). Same rules as
## tools/pixel_materials.py: 32 texels/m, 4-8 colour palettes, ordered
## dithering, baked bevels, per-texel normal and roughness. Written in GDScript
## so it runs without Python:
##   godot --headless --path . --script res://tools/pixel_materials_ext.gd
## Writes assets/textures/px/<name>{,_normal,_rough}.png and
## px/manifest_ext.json, which asset_factory.gd merges over manifest.json.
## Decal maps (weathering item 3) go to assets/textures/decals/; pass
## `-- decals` to write only those.
##
## Mappings: "world" = world triplanar at 32 texels/m (tile size in texels),
## "card" = alpha foliage card on its own UVs. Cards are 0.1-0.2 m wide, so
## they are authored at about 64 texels/m (2x the rule) to keep a readable
## leaf silhouette; that is the one documented exception.

const OUT: String = "res://assets/textures/px/"
const BAYER: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

var manifest: Dictionary = {}

func _init() -> void:
	if OS.get_cmdline_user_args().has("decals"):   # -- decals: only the decal maps
		decals()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	decals()
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
	weathered_ashlar("gorge_stone_weathered", pal(["#3a2a1d", "#4a3a2c", "#6b5038", "#8a6a4b", "#a0805c",
		"#b39570", "#c4a983", "#d4bd98"]), 81)

## Gorge tier walls (ART_DIRECTION.md section 8, slice 9): the sandstone
## ashlar coursing with rain grime baked in. One tile is 4 m (a storey), so
## each storey darkens under its ledge, fades over ~2 m and carries soot and
## drip streaks down from the top. Old but kept up: the stain stops short of
## black, the joints stay crisp and a few blocks are recent clean repairs.
## Texture v runs down the wall (world triplanar flips y), so row 0 is the top.
func weathered_ashlar(material_name: String, palette: PackedColorArray, seed_value: int) -> void:
	var w: int = 128
	var h: int = 128
	var course: int = 8
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var block_id: PackedInt32Array = PackedInt32Array()
	block_id.resize(w * h)
	var edge: PackedInt32Array = PackedInt32Array()   # 1 lit bevel, -1 shadow bevel, -2 joint
	edge.resize(w * h)
	var blocks: int = 0
	for row: int in range(h / course):
		var y0: int = row * course
		var start: int = rng.randi_range(0, 24)
		var x: int = start
		while x < start + w:
			var bw: int = rng.randi_range(14, 26)
			if start + w - x - bw < 14:
				bw = start + w - x   # close the row seamlessly
			blocks += 1
			for yy: int in range(y0, y0 + course):
				for xx: int in range(x, x + bw):
					block_id[yy * w + xx % w] = blocks
			for xx: int in range(x, x + bw):
				edge[y0 * w + xx % w] = -2
				edge[(y0 + 1) * w + xx % w] = maxi(edge[(y0 + 1) * w + xx % w], 1)
				edge[(y0 + course - 1) * w + xx % w] = -1
			for yy: int in range(y0, y0 + course):
				edge[yy * w + x % w] = -2
				if edge[yy * w + (x + 1) % w] > -2:
					edge[yy * w + (x + 1) % w] = 1
				if edge[yy * w + (x + bw - 1) % w] > -2:
					edge[yy * w + (x + bw - 1) % w] = -1
			x += bw
	var tone: PackedFloat32Array = PackedFloat32Array()
	var repaired: PackedByteArray = PackedByteArray()
	for b: int in range(blocks + 1):
		tone.append(rng.randf() * .30 - .15)
		repaired.append(1 if rng.randf() < .06 else 0)
	# Drips: soot runs from the ledge line and shorter ones from block sills.
	var streak: PackedFloat32Array = filled(w * h, 0.0)
	for k: int in range(22):
		var sx: int = rng.randi_range(0, w - 1)
		var top: int = 0 if k < 14 else rng.randi_range(2, 10) * course
		var length: int = rng.randi_range(18, 70) if k < 14 else rng.randi_range(6, 20)
		var width: int = rng.randi_range(2, 4)
		var strength: float = rng.randf_range(.26, .40)
		for yy: int in range(top, mini(top + length, h)):
			var fade: float = 1.0 - float(yy - top) / length
			# Water wanders a texel now and then as it runs down the joints.
			var wander: int = int(floor(sin(yy * .21 + k) * 1.2))
			for dx: int in range(width):
				var i: int = yy * w + posmod(sx + dx + wander, w)
				streak[i] = maxf(streak[i], strength * (.4 + .6 * fade) * (1.0 if dx > 0 and dx < width - 1 or width < 3 else .6))
	var grain: PackedFloat32Array = noise(w, h, 16, seed_value + 3)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 4, 1)
	var blotch: PackedFloat32Array = noise(w, h, 32, seed_value + 6, 2)
	var chip_field: PackedFloat32Array = noise(w, h, 3, seed_value + 9, 1)
	var n: int = palette.size()
	var lo: float = 1.0 / n
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		var t: float = float(y) / h
		# Ledge stain: heavy under the ledge, gone by mid-storey; a little
		# splash-back damp at the foot.
		var ledge: float = pow(clampf(1.0 - t / .6, 0.0, 1.0), 1.4) * .46 + pow(clampf((t - .9) / .1, 0.0, 1.0), 2.0) * .07
		for x: int in range(w):
			var i: int = y * w + x
			var g: float = grain[i] * .55 + fine[i] * .45
			var b: int = block_id[i]
			var value: float = .25 + g * .6 + tone[b]
			if edge[i] == 1:
				value += .22
			elif edge[i] == -1:
				value -= .20
			var chip: bool = chip_field[i] > .94
			if chip:
				value -= .22
			var stain: float = 0.0
			if repaired[b] == 0:
				stain = ledge * (.7 + blotch[i] * .6) + streak[i]
			else:
				value += .08
			value -= stain
			value = lo + clampf(value, 0.0, 1.0) * (1.0 - lo)
			rgb.append(palette[0] if edge[i] == -2 else quant(clampf(value, 0.0, .999), palette, x, y, .6))
			height.append(0.0 if edge[i] == -2 else .75 + g * .25 - (.3 if chip else 0.0) - streak[i] * .2 + (.05 if edge[i] == 1 else 0.0))
			# Grimy stone holds a slight film; still matte.
			rough.append(.82 + g * .15 - stain * .12)
	save(material_name, w, h, rgb, height, rough)

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

# ------------------------------------------------------------------- decals
## Weathering decals (ENVIRONMENT_PLAN.md weathering item 3) at 32 texels/m.
## The albedo alpha is what the Decal blends with, quantised to a few levels
## with ordered dithering, so edges stay pixel steps instead of soft gradients.
## Image top is the decal's -Z; wall decal scenes are turned so it is up.
const DECAL_OUT: String = "res://assets/textures/decals/"
const DECAL_ALPHA: Array[float] = [0.0, .22, .38, .54, .7, .86]

func decals() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DECAL_OUT))
	water_stain("stain_water_a", 40, 80, 301, 4)
	water_stain("stain_water_b", 40, 80, 302, 6)
	damp_moss("stain_damp_moss", 40, 80, 303)
	soot("soot_plume", 40, 40, 304)
	crack("crack_floor_a", 40, 40, 305, 2)
	crack("crack_floor_b", 40, 40, 306, 3)
	damp_floor("damp_floor", 40, 40, 307)
	moss_floor("moss_floor", 40, 40, 308)
	print("wrote 8 decal maps to %s" % DECAL_OUT)

## Alpha level for a 0..1 coverage, dithered between the DECAL_ALPHA steps.
func alpha_q(a: float, x: int, y: int) -> int:
	if a <= .02:
		return 0
	var bayer: float = BAYER[y % 4][x % 4] / 16.0 - .5
	var n: int = DECAL_ALPHA.size()
	return int(DECAL_ALPHA[clampi(int(floor(a * (n - 1) + .5 + bayer * .7)), 1, n - 1)] * 255.0)

## RGBA albedo, plus a normal map when a height field is given (edges clamp,
## decals do not tile).
func decal_save(decal_name: String, w: int, h: int, rgb: PackedColorArray, alpha: PackedByteArray,
		height: PackedFloat32Array = PackedFloat32Array(), strength: float = 2.0) -> void:
	var albedo: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		for x: int in range(w):
			var c: Color = rgb[y * w + x].clamp()
			c.a = alpha[y * w + x] / 255.0
			albedo.set_pixel(x, y, c)
	var base: String = ProjectSettings.globalize_path(DECAL_OUT + decal_name)
	albedo.save_png(base + ".png")
	if height.is_empty():
		return
	var normal: Image = Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y: int in range(h):
		for x: int in range(w):
			var dx: float = (height[y * w + mini(x + 1, w - 1)] - height[y * w + maxi(x - 1, 0)]) * strength
			var dy: float = (height[mini(y + 1, h - 1) * w + x] - height[maxi(y - 1, 0) * w + x]) * strength
			var n: Vector3 = Vector3(-dx, dy, 1.0).normalized() * .5 + Vector3.ONE * .5
			normal.set_pixel(x, y, Color(n.x, n.y, n.z))
	normal.save_png(base + "_normal.png")

## 0 at the image border, 1 from `margin` texels in: nothing is cut off square.
func border(x: int, y: int, w: int, h: int, margin: float) -> float:
	return clampf(minf(minf(x, w - 1 - x), minf(y, h - 1 - y)) / margin, 0.0, 1.0)

## True where field >= limit but a 4-neighbour is below it.
func rim(field: PackedFloat32Array, w: int, h: int, x: int, y: int, limit: float) -> bool:
	if field[y * w + x] < limit:
		return false
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + o
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or field[q.y * w + q.x] < limit:
			return true
	return false

## Water run from a leak at the top of a wall: a blotch under the source,
## drips that wander a texel and fade, a darker tide line round the wet stone
## and pale salt bloom texels along its lower edge.
func water_stain(decal_name: String, w: int, h: int, seed_value: int, drips: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var blotch: PackedFloat32Array = noise(w, h, 8, seed_value + 1, 2)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var field: PackedFloat32Array = filled(w * h, 0.0)
	var cx: float = w * rng.randf_range(.42, .58)
	var spread: float = w * rng.randf_range(.24, .34)
	var depth: float = h * rng.randf_range(.16, .26)
	for y: int in range(h):
		for x: int in range(w):
			var across: float = pow(clampf(1.0 - absf(x + .5 - cx) / spread, 0.0, 1.0), .7)
			var down: float = pow(clampf(1.0 - y / depth, 0.0, 1.0), .8)
			field[y * w + x] = across * down * (.55 + blotch[y * w + x] * .8)
	for k: int in range(drips):
		var sx: float = cx + rng.randf_range(-spread * .75, spread * .75)
		var length: int = rng.randi_range(int(h * .35), h - 5)
		var width: float = rng.randf_range(1.2, 3.2)
		var strength: float = rng.randf_range(.5, .85)
		var drift: float = rng.randf_range(-.05, .05)
		for y: int in range(int(depth * .4), length):
			var fade: float = 1.0 - float(y) / length
			var wx: float = sx + drift * y + floor(sin(y * .19 + k * 1.7) * 1.3)
			for x: int in range(int(wx - width - 1), int(wx + width + 2)):
				if x < 0 or x >= w:
					continue
				var d: float = absf(x + .5 - wx) / width
				if d < 1.0:
					field[y * w + x] = maxf(field[y * w + x], strength * (.35 + .65 * fade) * (1.0 - d * d * .5))
	# The leak comes from above: the top fades out over 8 texels, the sides and
	# foot over 3.
	for i: int in range(w * h):
		var x: int = i % w
		var y: int = i / w
		field[i] *= clampf(minf(x, w - 1 - x) / 3.0, 0.0, 1.0) * clampf((h - 1 - y) / 3.0, 0.0, 1.0) * clampf(y / 8.0, 0.0, 1.0)
	# Dark enough to read on lamp-lit sandstone (a lighter umber vanished, as in vista slice 8).
	var body: PackedColorArray = pal(["#1d1814", "#26201a", "#302820", "#3a3027"])
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var f: float = field[i]
			if f < .18:
				rgb.append(body[0])
				alpha.append(0)
			elif y > depth * .7 and rim(field, w, h, x, y, .18):   # no tide line where it seeps in
				var salt: bool = y > h * .55 and fine[i] > .6
				rgb.append(Color("cdc3ab") if salt else Color("2a211a"))
				alpha.append(alpha_q(.72 if salt else .8, x, y))
			else:
				rgb.append(quant(clampf(1.0 - f * .9, 0.0, .999), body, x, y, .5))
				alpha.append(alpha_q((.4 + f * .45) * (.85 + fine[i] * .3), x, y))
	decal_save(decal_name, w, h, rgb, alpha)

## A damp run down a wall with a moss cushion where it pools at the foot of
## the image; moss specks creep up the wet stone.
func damp_moss(decal_name: String, w: int, h: int, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var blotch: PackedFloat32Array = noise(w, h, 6, seed_value + 1, 2)
	var cx: float = w * rng.randf_range(.42, .58)
	var wet: PackedFloat32Array = filled(w * h, 0.0)
	var moss: PackedFloat32Array = filled(w * h, 0.0)
	var lumps: Array[Vector4] = []    # centre x, centre y, radius x, radius y
	for k: int in range(5):
		lumps.append(Vector4(cx + rng.randf_range(-11.0, 11.0), h - rng.randf_range(6.0, 13.0),
			rng.randf_range(5.0, 10.0), rng.randf_range(3.0, 6.5)))
	for y: int in range(h):
		var t: float = float(y) / h
		var half: float = 3.0 + t * 7.0
		for x: int in range(w):
			var i: int = y * w + x
			wet[i] = clampf(1.0 - absf(x + .5 - cx) / half, 0.0, 1.0) * (.35 + .5 * t) * (.6 + blotch[i] * .8)
			for l: Vector4 in lumps:
				var d: float = Vector2((x + .5 - l.x) / l.z, (y + .5 - l.y) / l.w).length()
				moss[i] = maxf(moss[i], 1.0 - d + (fine[i] - .5) * .5)
			var b: float = border(x, y, w, h, 2.5)
			wet[i] *= b
			moss[i] *= b
	var greens: PackedColorArray = pal(["#24331a", "#36481f", "#4a5f28", "#5f7732"])
	var damp: PackedColorArray = pal(["#2f2a22", "#3a3329", "#463d31"])
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var speck: bool = wet[i] > .3 and fine[i] > .8 and y > h * .3
			if moss[i] > 0.0 or speck:
				var lit: bool = y > 0 and moss[(y - 1) * w + x] <= 0.0 and not speck
				var shade: bool = y < h - 1 and moss[(y + 1) * w + x] <= 0.0
				var v: float = .35 + fine[i] * .4 + (.3 if lit else 0.0) - (.3 if shade else 0.0)
				rgb.append(Color("7a8f40") if lit and fine[i] > .5 else quant(clampf(v, 0.0, .999), greens, x, y, .5))
				alpha.append(alpha_q(.7 if speck else .9, x, y))
			elif wet[i] > .12:
				rgb.append(quant(clampf(1.0 - wet[i], 0.0, .999), damp, x, y, .5))
				alpha.append(alpha_q(.2 + wet[i] * .4, x, y))
			else:
				rgb.append(damp[0])
				alpha.append(0)
	decal_save(decal_name, w, h, rgb, alpha)

## Lamp soot on the surface above a lantern: densest over the flame, breaking
## up into blotches toward the edge.
func soot(decal_name: String, w: int, h: int, seed_value: int) -> void:
	var blotch: PackedFloat32Array = noise(w, h, 8, seed_value + 1, 3)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var dark: PackedColorArray = pal(["#17130f", "#211b16", "#2c241d", "#382e25"])
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var r: float = Vector2((x + .5) / w - .5, ((y + .5) / h - .5) * 1.1).length() * 2.0
			# Broad and dense: it lands on shaded wood and dark crown tiles.
			var s: float = pow(clampf(1.0 - r, 0.0, 1.0), .7) * (.75 + blotch[i] * .6) * border(x, y, w, h, 2.0)
			rgb.append(quant(clampf(1.0 - s * 1.2 + fine[i] * .1, 0.0, .999), dark, x, y, .5))
			alpha.append(alpha_q(s * 1.3, x, y) if s > .1 else 0)
	decal_save(decal_name, w, h, rgb, alpha)

## A floor crack: a wandering main line (two texels wide through the middle),
## short branches, a few spalled chips and a dirt halo. The groove is in the
## normal map, not baked as a lit bevel, because floor decals turn at random.
func crack(decal_name: String, w: int, h: int, seed_value: int, branches: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var mark: PackedInt32Array = PackedInt32Array()     # 0 none, 1 halo, 2 chip, 3 crack
	mark.resize(w * h)
	var main: Array[Vector2] = walk(rng, Vector2(4.0, h * rng.randf_range(.3, .7)), rng.randf_range(-.4, .4), w + h, w, h)
	var paths: Array = [main]
	for b: int in range(branches):
		var at: Vector2 = main[rng.randi_range(main.size() / 5, main.size() * 4 / 5)]
		var turn: float = rng.randf_range(.6, 1.2) * (1.0 if rng.randf() < .5 else -1.0)
		paths.append(walk(rng, at, turn, rng.randi_range(7, 16), w, h))
	for p: int in range(paths.size()):
		var path: Array[Vector2] = paths[p]
		for k: int in range(path.size()):
			var q: Vector2i = Vector2i(path[k])
			var wide: bool = p == 0 and k > path.size() / 4 and k < path.size() * 3 / 4
			for o: Vector2i in ([Vector2i.ZERO, Vector2i(1, 0)] if wide else [Vector2i.ZERO]):
				mark[(q.y + o.y) * w + q.x + o.x] = 3
	for k: int in range(rng.randi_range(2, 3)):
		var c: Vector2i = Vector2i(main[rng.randi_range(4, main.size() - 5)])
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0)]:
			var i: int = (c.y + o.y) * w + c.x + o.x
			if mark[i] != 3:
				mark[i] = 2
	for y: int in range(1, h - 1):
		for x: int in range(1, w - 1):
			if mark[y * w + x] == 0:
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if mark[(y + o.y) * w + x + o.x] == 3:
						mark[y * w + x] = 1
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(w * h):
		match mark[i]:
			3:
				rgb.append(Color("17130f"))
				alpha.append(alpha_q(.9, i % w, i / w))
				height.append(0.0)
			2:
				rgb.append(Color("4d4339"))
				alpha.append(alpha_q(.6, i % w, i / w))
				height.append(.5)
			1:
				rgb.append(Color("3b332b"))
				alpha.append(alpha_q(.3 if fine[i] > .4 else 0.0, i % w, i / w))
				height.append(.85)
			_:
				rgb.append(Color("3b332b"))
				alpha.append(0)
				height.append(1.0)
	decal_save(decal_name, w, h, rgb, alpha, height, 1.5)

## Random walk of whole texels from `start` along `heading` (0 = +x), kept
## three texels inside the image; up to `steps` points. It wavers but keeps
## pulling back to its heading, so cracks run across instead of curling up.
func walk(rng: RandomNumberGenerator, start: Vector2, heading: float, steps: int, w: int, h: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var p: Vector2 = start
	var angle: float = heading
	for k: int in range(steps):
		var q: Vector2 = p.floor()
		if q.x < 3 or q.y < 3 or q.x > w - 4 or q.y > h - 4:
			break
		if out.is_empty() or out[-1] != q:
			out.append(q)
		angle = lerpf(angle, heading, .3) + rng.randf_range(-.5, .5)
		p += Vector2(cos(angle), sin(angle))
	return out

## A dried puddle on the floor: tide line round a faintly darker patch, salt
## texels on the rim.
func damp_floor(decal_name: String, w: int, h: int, seed_value: int) -> void:
	var blotch: PackedFloat32Array = noise(w, h, 8, seed_value + 1, 2)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var field: PackedFloat32Array = filled(w * h, 0.0)
	for y: int in range(h):
		for x: int in range(w):
			var r: float = Vector2((x + .5) / w - .5, (y + .5) / h - .5).length() * 2.0
			field[y * w + x] = clampf(1.0 - r / (.55 + blotch[y * w + x] * .5), 0.0, 1.0) * border(x, y, w, h, 2.0)
	var body: PackedColorArray = pal(["#2f2a22", "#3a3329", "#463d31"])
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			if field[i] < .05:
				rgb.append(body[0])
				alpha.append(0)
			elif rim(field, w, h, x, y, .05):
				var salt: bool = fine[i] > .58
				rgb.append(Color("cdc3ab") if salt else Color("2a2520"))
				alpha.append(alpha_q(.6 if salt else .7, x, y))
			else:
				rgb.append(quant(clampf(.8 - field[i] * .6, 0.0, .999), body, x, y, .5))
				alpha.append(alpha_q(.25 + field[i] * .25, x, y))
	decal_save(decal_name, w, h, rgb, alpha)

## Moss lumps in a floor joint, with a damp halo.
func moss_floor(decal_name: String, w: int, h: int, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var lumps: Array[Vector3] = []
	for k: int in range(6):
		lumps.append(Vector3(w * .5 + rng.randf_range(-12.0, 12.0), h * .5 + rng.randf_range(-8.0, 8.0), rng.randf_range(3.0, 7.0)))
	var greens: PackedColorArray = pal(["#24331a", "#36481f", "#4a5f28", "#5f7732"])
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var m: float = -1.0
			for l: Vector3 in lumps:
				m = maxf(m, 1.0 - Vector2(x + .5 - l.x, y + .5 - l.y).length() / l.z + (fine[i] - .5) * .5)
			m = m * border(x, y, w, h, 2.0) if m > 0.0 else m
			if m > 0.0:
				rgb.append(quant(clampf(.3 + fine[i] * .4 + m * .3, 0.0, .999), greens, x, y, .5))
				alpha.append(alpha_q(.9, x, y))
			elif m > -.5:
				rgb.append(Color("2f2a22"))
				alpha.append(alpha_q(.3 + m * .3, x, y))
			else:
				rgb.append(Color("2f2a22"))
				alpha.append(0)
	decal_save(decal_name, w, h, rgb, alpha)
