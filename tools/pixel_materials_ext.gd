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
	if OS.get_cmdline_user_args().has("bazaar"):   # -- bazaar: only the Grand Bazaar's maps
		bazaar()
		print("wrote the bazaar's maps")
		quit()
		return
	if OS.get_cmdline_user_args().has("ossuary"):  # -- ossuary: only the Ossuary of Books' maps
		ossuary()
		print("wrote the ossuary's maps")
		quit()
		return
	if OS.get_cmdline_user_args().has("scriptorium"):  # -- scriptorium: only the Orosi Scriptorium's maps
		scriptorium()
		print("wrote the scriptorium's maps")
		quit()
		return
	if OS.get_cmdline_user_args().has("quarter"):  # -- quarter: only the Domicile Quarter's maps
		quarter()
		print("wrote the quarter's maps")
		quit()
		return
	if OS.get_cmdline_user_args().has("decals"):   # -- decals: only the decal maps
		decals()
		quit()
		return
	if OS.get_cmdline_user_args().has("rugs"):     # -- rugs: only the carpets, merged into the manifest
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT + "manifest_ext.json"))
		manifest = (old as Dictionary).get("materials", {}) if old is Dictionary else {}
		for entry: Dictionary in manifest.values():     # JSON reads numbers back as floats
			entry["size"] = [int(entry["size"][0]), int(entry["size"][1])]
		rugs()
		var out: FileAccess = FileAccess.open(OUT + "manifest_ext.json", FileAccess.WRITE)
		out.store_string(JSON.stringify({"texel_density": 32, "materials": manifest}, " "))
		out.close()
		print("wrote the carpets; manifest has %d pixel materials" % manifest.size())
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	decals()
	props()
	fabrics()
	books()
	architecture()
	foliage()
	kit_room()
	persian()
	quarter()
	ossuary()
	scriptorium()
	rugs()
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

# ----------------------------------------------------------------- kit room
## Kit-only variants of the R01 room maps (ENVIRONMENT_PLAN.md polish C item 7).
## kit/materials/{brick,arch_stone,floor_stone,vault_plaster}.tres point at
## these; the prototype keeps the Python-generated originals untouched. Ports
## of ashlar(), flagstones() and mottled() in tools/pixel_materials.py with the
## same palettes, parameters, texel scale and dithering (Godot's RNG differs
## from numpy's, so the block layout differs). Brick tiles at 72 texels so its
## 9-texel courses close (the .py's 64 leaves a stray row at the seam).
func kit_room() -> void:
	var sand: PackedColorArray = pal(["#3a2a1d", "#6b5038", "#8a6a4b", "#a0805c", "#b39570", "#c4a983", "#d4bd98", "#7a7266"])
	var lime: PackedColorArray = pal(["#5d5244", "#7c705f", "#968a76", "#ab9f88", "#bdb29b", "#cfc5ae", "#ddd5c0"])
	var floor_pal: PackedColorArray = pal(["#2a221b", "#4a3d31", "#5f4f40", "#72604e", "#86735e", "#9a8670", "#ad9a82"])
	var plaster: PackedColorArray = pal(["#8a7a62", "#9d8d73", "#ae9e83", "#bdae93", "#cbbda3", "#d8cbb2"])
	ashlar_kit("brick_kit", sand, 72, 9, 13, 21, 12)
	ashlar_kit("arch_stone_kit", lime, 64, 8, 10, 16, 13)
	flagstones_kit("floor_stone_kit", floor_pal, 64, 17)
	mottled_kit("vault_plaster_kit", plaster, 64, 12, 21, .7)

## Coursed blocks with baked pixel bevels (lit top-left, shadow bottom-right),
## as ashlar() in the .py.
func ashlar_kit(material_name: String, palette: PackedColorArray, size: int, course: int, min_w: int, max_w: int,
		seed_value: int, mortar_index: int = 0, chip: float = .08) -> void:
	var w: int = size
	var h: int = size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var block_id: PackedInt32Array = PackedInt32Array()
	block_id.resize(w * h)
	var edge: PackedInt32Array = PackedInt32Array()   # 1 lit bevel, -1 shadow bevel, -2 joint
	edge.resize(w * h)
	var dome: PackedFloat32Array = filled(w * h, 0.0)   # 1 at a block's centre, 0 at its arrises
	var blocks: int = 0
	for row: int in range(h / course):
		var y0: int = row * course
		var start: int = rng.randi_range(0, max_w - 1)
		var x: int = start
		while x < start + w:
			var bw: int = rng.randi_range(min_w, max_w)
			if start + w - x - bw < min_w:
				bw = start + w - x   # close the row seamlessly
			blocks += 1
			for yy: int in range(y0, y0 + course):
				var v: float = (yy - y0 + .5) / course * 2.0 - 1.0
				for xx: int in range(x, x + bw):
					block_id[yy * w + xx % w] = blocks
					var u: float = (xx - x + .5) / bw * 2.0 - 1.0
					dome[yy * w + xx % w] = (1.0 - u * u) * (1.0 - v * v)
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
	var tone_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	tone_rng.seed = seed_value + 7
	var tone: PackedFloat32Array = PackedFloat32Array()
	for b: int in range(blocks + 1):
		tone.append(tone_rng.randf() * .30 - .15)
	# Relief (polish C item 8), drawn from its own RNG so the albedo is
	# unchanged: each block bulges proud or sits a little inset, and is a touch
	# smoother or rougher than its neighbours.
	var relief_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	relief_rng.seed = seed_value + 11
	var bulge: PackedFloat32Array = PackedFloat32Array()
	var face_rough: PackedFloat32Array = PackedFloat32Array()
	for b: int in range(blocks + 1):
		bulge.append(relief_rng.randf_range(-.12, .3))
		face_rough.append(relief_rng.randf_range(-.05, .05))
	var grain: PackedFloat32Array = noise(w, h, 8, seed_value + 3)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 4, 1)
	var chip_field: PackedFloat32Array = noise(w, h, 3, seed_value + 9, 1)
	var spall_field: PackedFloat32Array = noise(w, h, 5, seed_value + 20, 2)
	var n: int = palette.size()
	var lo: float = (mortar_index + 1.0) / n
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var g: float = grain[i] * .55 + fine[i] * .45
			var value: float = .25 + g * .6 + tone[block_id[i]]
			if edge[i] == 1:
				value += .22
			elif edge[i] == -1:
				value -= .20
			var chipped: bool = chip_field[i] > 1.0 - chip
			if chipped:
				value -= .25
			value = lo + clampf(value, 0.0, 1.0) * (1.0 - lo)
			rgb.append(palette[mortar_index] if edge[i] == -2 else quant(clampf(value, 0.0, .999), palette, x, y))
			if edge[i] == -2:
				# Recessed mortar, more matte than the dressed stone.
				height.append(-.1)
				rough.append(.9 + g * .08)
				continue
			var b: int = block_id[i]
			var spalled: bool = spall_field[i] > .74 and dome[i] > .15
			var hgt: float = .75 + g * .2 + bulge[b] * dome[i]
			if edge[i] != 0:
				hgt -= .12   # worn, rounded arris
			if chipped:
				hgt -= .3
			if spalled:
				hgt -= .2
			height.append(hgt)
			rough.append((.97 if chipped or spalled else .82 + g * .15 + face_rough[b]) - maxf(bulge[b], 0.0) * dome[i] * .15)
	save(material_name, w, h, rgb, height, rough)

## Staggered flagstone courses with a joint, lit and shadow rim per stone, as
## flagstones() in the .py.
func flagstones_kit(material_name: String, palette: PackedColorArray, size: int, seed_value: int,
		rows: Vector2i = Vector2i(14, 22), cols: Vector2i = Vector2i(16, 28)) -> void:
	var w: int = size
	var h: int = size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var value: PackedFloat32Array = filled(w * h, 0.0)
	var mark: PackedInt32Array = PackedInt32Array()   # 3 joint, 1 lit rim, -1 shadow rim
	mark.resize(w * h)
	# Relief (polish C item 8) from its own RNG so the albedo is unchanged.
	# Per stone: a tilt of a few degrees, a dished centre worn by feet (and
	# polished to match), and now and then a stone sunk or lifted.
	var relief_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	relief_rng.seed = seed_value + 11
	var relief: PackedFloat32Array = filled(w * h, 0.0)   # height offset from tilt, dish and settling
	var wear: PackedFloat32Array = filled(w * h, 0.0)     # 0..1 polish from foot traffic
	var courses: Array[Vector2i] = []   # (y0, height)
	var y: int = 0
	while y < h:
		var rh: int = rng.randi_range(rows.x, rows.y - 1)
		if h - y - rh < rows.x:
			rh = h - y
		courses.append(Vector2i(y, rh))
		y += rh
	for c: Vector2i in courses:
		var offset: int = rng.randi_range(0, w - 1)
		var x: int = 0
		while x < w:
			var cw: int = rng.randi_range(cols.x, cols.y - 1)
			if w - x - cw < cols.x:
				cw = w - x
			var t: float = rng.randf() * .35 - .17
			var slope: Vector2 = Vector2.from_angle(relief_rng.randf() * TAU) * relief_rng.randf_range(.015, .035)
			var dish: float = relief_rng.randf_range(.08, .3)
			var settle: float = relief_rng.randf()
			var lift: float = -.14 if settle < .1 else (.1 if settle > .93 else 0.0)
			for yy: int in range(c.x, c.x + c.y):
				var v: float = (yy - c.x + .5) / c.y * 2.0 - 1.0
				for xx: int in range(x, x + cw):
					var i: int = yy * w + (xx + offset) % w
					var u: float = (xx - x + .5) / cw * 2.0 - 1.0
					var bowl: float = (1.0 - u * u) * (1.0 - v * v)
					relief[i] = slope.dot(Vector2(xx - x - cw * .5, yy - c.x - c.y * .5)) - dish * bowl + lift
					wear[i] = bowl * dish / .3
					value[i] = t
					if yy == c.x or xx == x:
						mark[i] = 3
					elif yy == c.x + 1 or xx == x + 1:
						mark[i] = 1
					elif yy == c.x + c.y - 1 or xx == x + cw - 1:
						mark[i] = -1
			x += cw
	var grain: PackedFloat32Array = noise(w, h, 10, seed_value + 1)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 2, 1)
	var chip_field: PackedFloat32Array = noise(w, h, 2, seed_value + 21, 1)
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for yy: int in range(h):
		for xx: int in range(w):
			var i: int = yy * w + xx
			var g: float = grain[i] * .6 + fine[i] * .4
			var v: float = .30 + g * .55 + value[i] + (.15 if mark[i] == 1 else 0.0) - (.18 if mark[i] == -1 else 0.0)
			rgb.append(palette[0] if mark[i] == 3 else quant(clampf(v, .15, .999), palette, xx, yy))
			if mark[i] == 3:
				# Deep joint; damp collects there, so it is the glossiest texel.
				height.append(-.25)
				rough.append(.42 + g * .1)
				continue
			var hgt: float = .8 + g * .12 + relief[i]
			var r: float = .8 + g * .15 - wear[i] * .45
			if mark[i] != 0:
				hgt -= .1   # rounded arris
				if chip_field[i] > .72:
					hgt -= .35   # chipped arris
					r = .95
				else:
					r = .6 + g * .1   # damp seeps up the arris
			height.append(hgt)
			rough.append(r)
	save(material_name, w, h, rgb, height, rough)

## Mottled ground as mottled() in the .py (the GDScript mottled() above is
## the props variant with its own normal strength and bands).
func mottled_kit(material_name: String, palette: PackedColorArray, size: int, cell: int, seed_value: int,
		contrast: float = 1.0, rough_base: float = .88) -> void:
	var w: int = size
	var h: int = size
	var grain: PackedFloat32Array = noise(w, h, cell, seed_value)
	var fine: PackedFloat32Array = noise(w, h, 2, seed_value + 1, 1)
	# Trowel undulation (polish C item 8): broad, shallow swells a trowel-width
	# across, with the trowelled crests a little smoother than the hollows.
	var swell: PackedFloat32Array = noise(w, h, 16, seed_value + 40, 2)
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var g: float = grain[i] * .65 + fine[i] * .35
			rgb.append(quant(clampf(.5 + (g - .5) * 1.6 * contrast, 0.0, .999), palette, x, y))
			height.append(g * .3 + swell[i] * 3.0)
			rough.append(rough_base + (g - .5) * .1 - (swell[i] - .5) * .2)
	save(material_name, w, h, rgb, height, rough)

# ---------------------------------------------------------------- persian
## The Grand Bazaar (phase 15): honey brick with pale lime joints, as in the
## Tabriz and Kerman photos; the daylight's saffron starts in the wall.
func bazaar() -> void:
	ashlar_kit("bazaar_brick", pal(["#e2d0a8", "#9a7444", "#ab8450", "#bc955e", "#cba56c", "#d8b47c", "#e2c28c"]), 64, 4, 7, 10, 311, 0, .03)
	bazaar_glass()
	bazaar_dome()
	bazaar_goods()


## The bazaar's coloured glass: the palette tools/kit_add_r04.py's panes pick from
## by UV. Three shades each of ruby, cobalt, amber and pale straw, then the lead.
func bazaar_glass() -> void:
	var shades: PackedStringArray = ["#8e1a16", "#a8231b", "#7a1612", "#1c3f94", "#2650ad", "#17337c",
		"#c98a22", "#dca033", "#b5781c", "#e6cf94", "#d9bf80", "#f0dcaa", "#120c08", "#7cc4bc", "#f0883a", "#e8907c"]
	# Each shade its own 4 x 4 block: block compression, if an import ever turns it
	# on, then can't mix neighbours (it turned the blue maroon on the first walk).
	var img: Image = Image.create(shades.size() * 4, 4, false, Image.FORMAT_RGB8)
	for i: int in shades.size():
		img.fill_rect(Rect2i(i * 4, 0, 4, 4), Color(shades[i]))
	img.save_png("res://assets/textures/px/bazaar_glass.png")


## The bazaar's spices and food: a palette tools/kit_add_r04_shops.py's goods pick
## from by UV, one 4 x 4 block a colour, two shades of each. Bright: the shops are
## lit warm and dim.
func bazaar_goods() -> void:
	var shades: PackedStringArray = ["#e8a01c", "#f2b63a", "#e8c21e", "#d6ac14", "#c8401c", "#a83214", "#a01e34", "#86182a",
		"#a8703a", "#8e5c2e", "#7a9a3c", "#688a30", "#d88a9a", "#c47486", "#5a7a48", "#4a6a3c",
		"#d8b078", "#c49a62", "#b8824a", "#a87240", "#b01e2a", "#8e1820", "#f09030", "#e07c20",
		"#5a2a6a", "#4a2258", "#6a8a3c", "#d8c86a", "#e8dcae", "#d8cc9c", "#3a3a40", "#2e2e34",
		"#8a2a24", "#6e201c", "#2a4a80", "#203a66", "#34664e", "#28503c", "#74502c", "#5a3e22"]
	var img: Image = Image.create(shades.size() * 4, 4, false, Image.FORMAT_RGB8)
	for i: int in shades.size():
		img.fill_rect(Rect2i(i * 4, 0, 4, 4), Color(shades[i]))
	img.save_png("res://assets/textures/px/bazaar_goods.png")


## The crossing's dome, painted in its own frame (tools/kit_add_r04.py dome_uv): the
## eye in the middle, distance along the curve outward, 1 at a corner of the
## vault; the walls cut it at about 0.57 on the axes. A sunburst round the eye, a
## ring of sixteen pointed arches, and brick coursed round the dome in the corners,
## with a star in each.
func bazaar_dome() -> void:
	const N: int = 1024
	const FOLDS: int = 16
	var rng := RandomNumberGenerator.new()
	rng.seed = 319
	var ink := Color("#1a120c")
	var cobalt := Color("#3a6ee0")
	var deep := Color("#2a54b8")
	var turq := Color("#3cc8d4")
	var gold := Color("#d2a03c")
	var cream := Color("#e4d4a6")
	var joint := Color("#e2d0a8")
	var bricks: Array[Color] = [Color("#ab8450"), Color("#bc955e"), Color("#cba56c"), Color("#9a7444"), Color("#d8b47c")]
	var img: Image = Image.create(N, N, true, Image.FORMAT_RGB8)
	var wedge: float = TAU / FOLDS
	for y: int in N:
		for x: int in N:
			var px: float = (x + 0.5) / N * 2.0 - 1.0
			var py: float = (y + 0.5) / N * 2.0 - 1.0
			var r: float = sqrt(px * px + py * py)
			var a: float = atan2(py, px) + PI
			var k: int = int(a / wedge) % FOLDS
			var t: float = absf(fposmod(a, wedge) / wedge - 0.5) * 2.0       # 0 down a wedge's middle, 1 at its edge
			var c: Color
			if r < 0.135:
				c = gold if r > 0.12 else ink
			elif r < 0.31:
				var s: float = (r - 0.135) / 0.175
				var ray: float = 1.0 - s
				var small: float = (1.0 - s) * 0.55
				if t < ray - 0.09:
					c = gold if k % 2 == 0 else turq
				elif t < ray:
					c = cream
				elif 1.0 - t < small:
					c = cream
				else:
					c = cobalt if s < 0.75 else deep
			elif r < 0.345:
				var edge: bool = r < 0.317 or r > 0.338
				var bead: float = absf(fposmod(a / TAU * 96.0, 1.0) - 0.5)
				c = gold if edge else (cream if bead < 0.2 else ink)
			elif r < 0.56:
				# A ring of pointed arches, their feet on the beads, tips outward.
				var s: float = (r - 0.345) / 0.215
				var arch: float = 0.97 * (1.0 - pow(s, 1.7))
				var inner: float = 0.6 * (1.0 - pow(s / 0.78, 1.7))
				if t > arch:
					c = _dome_brick(r, a, bricks, joint)
				elif t > arch - 0.12:
					c = gold
				elif s < 0.78 and t < inner - 0.1:
					c = gold if absf(s - 0.3) + t * 0.5 < 0.1 else turq
				elif s < 0.78 and t < inner:
					c = cream
				else:
					c = cobalt
			elif r < 0.585:
				c = gold if r < 0.566 or r > 0.579 else cobalt
			else:
				c = _dome_brick(r, a, bricks, joint)
				# An eight-point star over each corner: a square and a square on its point.
				var q: Vector2 = Vector2(absf(px), absf(py)) - Vector2(0.566, 0.566)
				var e: float = minf(maxf(absf(q.x), absf(q.y)), (absf(q.x) + absf(q.y)) * 0.7071)
				if e < 0.115:
					c = gold if e > 0.098 else (cream if e < 0.03 else (turq if e < 0.05 else cobalt))
			var grain: float = rng.randf() * 0.07
			img.set_pixel(x, y, c.darkened(grain))
	img.generate_mipmaps()
	img.save_png("res://assets/textures/px/bazaar_dome.png")


## Brick coursed in rings round the dome.
func _dome_brick(r: float, a: float, bricks: Array[Color], joint: Color) -> Color:
	var row: int = int(r * 90.0)
	var along: float = a / TAU * 96.0 + (row % 2) * 0.5
	if fposmod(r * 90.0, 1.0) < 0.17 or fposmod(along, 1.0) < 0.1:
		return joint.darkened(0.12)
	return bricks[(row * 7 + int(along) * 13) % bricks.size()]


## The Domicile Quarter (phase 14): rose clay in two tints, muted and dusty, and
## the lanes' rammed earth. Same grain as the Gorge's plaster.
func quarter() -> void:
	mottled_kit("quarter_plaster_rose", pal(["#785a62", "#886870", "#98767e", "#a6848b", "#b39197", "#be9ea2"]), 64, 12, 301, .3)
	mottled_kit("quarter_plaster_clay", pal(["#726068", "#826e74", "#917c80", "#9f8a8c", "#ac9797", "#b7a3a1"]), 64, 12, 302, .3)
	ashlar_kit("quarter_brick", pal(["#2e2428", "#54434a", "#655258", "#756066", "#846e72", "#927c7e", "#9f8a8a"]), 64, 4, 7, 10, 304, 0, .03)
	flat_card("quarter_cloth", 64, 32, cloth_px, 305)
	mottled_kit("quarter_hide", pal(["#4a3324", "#5c4230", "#6e523c", "#806248", "#927254"]), 32, 6, 306, .85, .9)
	mottled_kit("quarter_lane", pal(["#3e332b", "#4a3d33", "#56483c", "#625345", "#6d5e4f"]), 64, 6, 303, .8, .95)


## The Ossuary of Books (phase 16): pale limestone with a grey-green bloom, so
## the room's colour is in the stone and the candles have something to light.
func ossuary() -> void:
	ossuary_goods()
	mottled_kit("ossuary_stone", pal(["#6e7068", "#7e8076", "#8e9084", "#9ea192", "#aeb2a0", "#bcc0ae"]), 64, 9, 321, 1.1, .92)
	mottled_kit("ossuary_floor", pal(["#4e5048", "#5a5d53", "#66695e", "#72756a", "#7e8175"]), 64, 6, 322, .9, .9)


## The Orosi Scriptorium (phase 17 step 4): the grey-fawn dust lying on the
## desks nobody has come back to (the far half, and the Forgotten version).
func scriptorium() -> void:
	mottled_kit("sc_dust", pal(["#6a655a", "#777266", "#837e70", "#8f8a7b", "#9b9686", "#a6a191"]), 64, 3, 331, .7, .97)


## What lies in the ossuary's niches: a palette tools/kit_r17_goods.py picks from
## by UV, one 4 x 4 block a colour, in the order of its constants. Linen going
## grey, twine, the book bindings, pages, wraps.
func ossuary_goods() -> void:
	var shades: PackedStringArray = ["#e2dcc6", "#c8c2aa", "#a8a28c", "#8e8c7e", "#74746a", "#5a5b52", "#94805a", "#6e6450",
		"#7a5232", "#5a3c26", "#7a3028", "#4c5c46", "#465468", "#7e7666", "#d4c8a2", "#969078", "#ac9460", "#d8b860", "#9e9e90", "#5e241e"]
	var img: Image = Image.create(shades.size() * 4, 4, false, Image.FORMAT_RGB8)
	for i: int in shades.size():
		img.fill_rect(Rect2i(i * 4, 0, 4, 4), Color(shades[i]))
	img.save_png("res://assets/textures/px/ossuary_goods.png")

## Four hung cloths side by side, one per 16 columns: pale washing, indigo with
## an ochre band, rose with diamonds, ochre and green stripes. The image's top
## row is the cloth's hem (the wind moves the top of a map most), a little ragged.
func cloth_px(x: int, y: int, _w: int, _h: int, rng: RandomNumberGenerator) -> Color:
	var col: int = x / 16
	var u: int = x % 16
	if y == 0 and rng.randf() < .3:
		return Color(0, 0, 0, 0)
	if u == 0 or u == 15:
		return Color(0, 0, 0, 0)
	var shade: float = .92 + .16 * rng.randf()
	var c: Color
	match col:
		0:
			c = Color("b5aa9a") if y % 12 != 5 else Color("8e8fa6")
		1:
			c = Color("c09a52") if y >= 8 and y < 12 else (Color("c8b89a") if (y == 7 or y == 12) else Color("2f3a5e"))
		2:
			c = Color("c9a56a") if absi(u - 8) + absi(y % 12 - 6) == 4 else Color("8a4a50")
		_:
			c = Color("a8894a") if (y / 4) % 2 == 0 else Color("4e5c44")
	return Color(c.r * shade, c.g * shade, c.b * shade)


## The reusable Persian kit (phase-8-design.md 8.2): fired brick, banai brick,
## kahgel plaster in two tints, stone, dressed rock, faience, dome tile, wood,
## soil, fungus, mirror mosaic, and alpha cards for the lattice screen,
## flowers, glow moss and fungus strands; the orosi's coloured glass is a uv
## map. Glowing variants are hand-written .tres in kit/materials (emit_*).
func persian() -> void:
	var brick: PackedColorArray = pal(["#3b2618", "#6a4630", "#84583a", "#9a6a46", "#ad7b53", "#bf8c61", "#cf9f72"])
	ashlar_kit("persian_brick", brick, 64, 4, 7, 10, 91, 0, .03)
	banai("persian_banai", brick, 92)
	# The three wall tints stay in one family (your report: as far apart as
	# they were, a street read as a messy mosaic): plaster, a lighter lime,
	# and dressed rock a step darker, all warm.
	mottled_kit("persian_plaster", pal(["#765a42", "#86684e", "#957659", "#a38464", "#b0916f", "#bc9d7a"]), 64, 12, 93, .3)
	mottled_kit("persian_plaster_lime", pal(["#836c54", "#937b61", "#a28a6e", "#b0987b", "#bda587", "#c8b192"]), 64, 12, 94, .3)
	gills("persian_gills")
	ashlar_kit("persian_stone", pal(["#2e2a25", "#4d463e", "#625a50", "#766d61", "#888072", "#9a9283", "#aca595"]), 64, 8, 12, 20, 95)
	mottled_kit("persian_rock_dressed", pal(["#4a3f35", "#56493d", "#625446", "#6e5f4f", "#7a6a58", "#867562"]), 64, 10, 97, .6)
	faience("persian_tile", 99)
	mottled_kit("persian_dome_tile", pal(["#0d4446", "#125859", "#1a6d6c", "#26837f", "#369a93", "#4fb2a8"]), 32, 4, 101, .9, .55)
	mottled("persian_wood", pal(["#24150c", "#3a2414", "#50331d", "#664328", "#7c5434"]), 16, 4, 103, 1.0, 0.0,
		Color(0, 0, 0, 0), .85, 3)
	mottled_kit("persian_soil", pal(["#1a130d", "#261c13", "#33261a", "#403021", "#4c3a28"]), 32, 4, 105)
	mottled("persian_fungus_cap", pal(["#0d1a1b", "#132628", "#1a3335", "#224144", "#2b5053"]), 16, 4, 107,
		1.0, .07, Color("6fd8c6"), .7)
	mottled("persian_fungus_stalk", pal(["#3e4440", "#4f5650", "#626a62", "#768076", "#8a958a"]), 16, 4, 108,
		.9, 0.0, Color(0, 0, 0, 0), .8, 0)
	mirror("persian_mirror", 109)
	flat_card("persian_lattice", 32, 48, lattice_px, 110)
	flat_card("persian_flowers", 32, 16, flowers_px, 111)
	flat_card("persian_glowmoss", 32, 32, glowmoss_px, 112)
	flat_card("persian_strands", 16, 64, strands_px, 113)
	orosi("persian_orosi", 114)
	woven("persian_awning", pal(["#8a2f24", "#d9c39a", "#2f5a8a", "#d9c39a"]), [4, 2, 2, 2], 32, 115)

## Banai: stretcher-bond brick in regular courses with a diamond lattice of
## pale glazed bricks and a turquoise brick at each lattice's heart (the
## brick-on-brick ornament of Isfahan and Yazd, calm from a distance).
func banai(material_name: String, palette: PackedColorArray, seed_value: int) -> void:
	var w: int = 64
	var h: int = 64
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var grain: PackedFloat32Array = noise(w, h, 4, seed_value + 1)
	var glaze: Color = Color("d9c49b")
	var turq: Color = Color("2f948d")
	var tones: Dictionary = {}
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var row: int = y / 4
			var xs: int = x + (4 if row % 2 == 1 else 0)
			var col: int = (xs / 8) % 8
			var key: int = row * 16 + col
			if not tones.has(key):
				tones[key] = rng.randf() * .3 - .15
			var joint: bool = y % 4 == 0 or xs % 8 == 0
			var cx: int = (col * 8 + 4 - (4 if row % 2 == 1 else 0) + w) % w
			var cy: int = row * 4 + 2
			var d: float = absf(float(cx % 32) - 16.0) + absf(float(cy % 32) - 16.0)
			var c: Color
			var g: float = grain[y * w + x]
			if joint:
				c = palette[0]
			elif d <= 2.0:
				c = turq * (.9 + g * .2)
			elif absf(d - 12.0) <= 2.5:
				c = glaze * (.88 + g * .2)
			else:
				var v: float = .45 + (g - .5) * .5 + tones[key] + (.15 if y % 4 == 1 else (-.15 if y % 4 == 3 else 0.0))
				c = quant(clampf(v, 0.0, .999), palette, x, y)
			rgb.append(c)
			height.append(-.1 if joint else .7 + g * .2)
			rough.append(.95 if joint else (.5 if d <= 2.0 or absf(d - 12.0) <= 2.5 else .85))
	save(material_name, w, h, rgb, height, rough)

## A mushroom's gills, uv mapped round the cap's underside (u round it, v
## from the stalk out to the rim): bright teal lines with dark furrows
## between, brightest near the stalk (emissive via emit_gills).
func gills(material_name: String) -> void:
	var w: int = 64
	var h: int = 16
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		var fade: float = 1.0 - float(y) / h * .55
		for x: int in range(w):
			var furrow: bool = x % 4 == 0 or (x % 4 == 2 and y > h / 2)
			var c: Color = Color("0f3b39") if furrow else Color("7ef0dc").lerp(Color("2fa898"), float(y) / h)
			rgb.append(c * (fade if not furrow else 1.0))
			height.append(.2 if furrow else .7)
	save(material_name, w, h, rgb, height, filled(w * h, .6), "uv", 1.0)

## Mirror mosaic (aineh-kari): small facets catching light at random angles.
func mirror(material_name: String, seed_value: int) -> void:
	var w: int = 16
	var h: int = 16
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	var facet: Array = []
	for i: int in range(16):
		facet.append(rng.randf())
	for y: int in range(h):
		for x: int in range(w):
			var f: float = facet[(y / 4) * 4 + x / 4]
			var edge: bool = x % 4 == 0 or y % 4 == 0
			var v: float = .35 + f * .6
			rgb.append(Color("5a4520") if edge else Color(v, v * .98, v * .92))
			height.append(.2 if edge else .6 + f * .3)
			rough.append(.6 if edge else .08 + f * .1)
	save(material_name, w, h, rgb, height, rough, "world", 1.0)

## An alpha card from a per-texel colour function (transparent where it
## returns alpha 0): the kit's non-leaf cards.
func flat_card(material_name: String, w: int, h: int, texel: Callable, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rgb: PackedColorArray = PackedColorArray()
	var alpha: PackedByteArray = PackedByteArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var c: Color = texel.call(x, y, w, h, rng)
			alpha.append(255 if c.a > .5 else 0)
			rgb.append(Color(c.r, c.g, c.b))
			height.append(.6 if c.a > .5 else 0.0)
	save(material_name, w, h, rgb, height, filled(w * h, 1.0), "card", 1.0, alpha)

## A wooden gereh screen: an 8-texel square grid turned 45 degrees with a
## frame, bars two texels wide, lit on the top-left edge.
func lattice_px(x: int, y: int, w: int, h: int, _rng: RandomNumberGenerator) -> Color:
	var frame: bool = x < 2 or y < 2 or x >= w - 2 or y >= h - 2
	var a: int = posmod(x + y, 8)
	var b: int = posmod(x - y, 8)
	var bar: bool = a < 2 or b < 2 or (posmod(x, 16) == 8 and posmod(y, 16) < 2)
	if not (frame or bar):
		return Color(0, 0, 0, 0)
	var lit: bool = a == 0 or b == 0
	return Color("7c5434") if lit else Color("4a2f1b")

## A clump of small blossoms over leaves, for beds (top of the map is up).
func flowers_px(x: int, y: int, w: int, h: int, rng: RandomNumberGenerator) -> Color:
	var v: float = float(y) / h
	var r: float = rng.randf()
	if v > .35 and r < .55:
		return [Color("2f4a22"), Color("3c5a28"), Color("4a6a30")][int(r * 5.4) % 3]
	if v <= .55 and r < .28:
		return [Color("c8463a"), Color("e2b44a"), Color("eadfc6"), Color("a65aa0")][int(r * 13.0) % 4]
	return Color(0, 0, 0, 0)

## Glow moss: scattered specks and small rosettes (emissive via emit_glowmoss).
func glowmoss_px(x: int, y: int, w: int, h: int, rng: RandomNumberGenerator) -> Color:
	var cx: float = x - w / 2.0
	var cy: float = y - h / 2.0
	var fall: float = 1.0 - sqrt(cx * cx + cy * cy) / (w / 2.0)
	var r: float = rng.randf()
	if r < fall * .45:
		return Color("7ef0dc") if r < fall * .12 else Color("2f9e92")
	return Color(0, 0, 0, 0)

## Hanging strands of a jelly fungus: a few wavy threads fading down.
func strands_px(x: int, y: int, w: int, h: int, _rng: RandomNumberGenerator) -> Color:
	var v: float = float(y) / h
	for k: int in range(3):
		var cx: float = 2.5 + k * 5.0 + sin(v * 9.0 + k * 2.0) * 1.2
		if absf(x - cx) < 1.0 and v < .95 - k * .1:
			return Color("a0fbe9") if v < .5 else Color("4fc7b6")
	return Color(0, 0, 0, 0)

## Orosi: coloured panes in a wooden grid under a pointed head, uv mapped
## onto the window's 1 x 2 frame.
func orosi(material_name: String, seed_value: int) -> void:
	var w: int = 32
	var h: int = 64
	var colours: Array = [Color("c8463a"), Color("2f5aa8"), Color("e2b44a"), Color("3f9c6a"), Color("eadfc6")]
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var wood: bool = x % 6 == 0 or y % 7 == 0 or x >= w - 1 or y >= h - 1
			var pane: int = (x / 6 + (y / 7) * 3 + seed_value) % colours.size()
			rgb.append(Color("3a2414") if wood else colours[pane])
			height.append(.8 if wood else .4)
			rough.append(.9 if wood else .2)
	save(material_name, w, h, rgb, height, rough, "uv", 1.0)

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
# ------------------------------------------------------------------ carpets
## The Reading Room's carpets (room rework, step 1): five designs, each at the
## three rug sizes the kit's rug pieces use, one knot per texel, UV-mapped over
## the whole rug (long side along u). Named rug_<design>_<size>.
const RUG_SIZES: Dictionary = {"runner": [140, 102], "grand": [192, 112], "small": [80, 56]}
## Palette slots: 0 outline, 1 field, 2 field abrash, 3 accent, 4 second accent,
## 5 ivory, 6 border ground, 7 border motif.
const RUG_PALETTES: Dictionary = {
	"kilim": ["#1a0f0b", "#7c2a1c", "#6a2318", "#c8913f", "#2a6a6a", "#e3cf9c", "#203a5a", "#9c3a22"],
	"herati": ["#120e12", "#1d2a4a", "#18233f", "#8a2a1e", "#3c6a4a", "#e0cfa0", "#7c2a1c", "#c8913f"],
	"medallion": ["#160c0a", "#8a2a1e", "#78241a", "#1d2a4a", "#2a4a6a", "#e6d4a6", "#d8c290", "#8a2a1e"],
	"gabbeh": ["#1e140c", "#b0702c", "#9c6026", "#7c2a1c", "#3a4a5a", "#e3cf9c", "#5a1d14", "#c8913f"],
	"garden": ["#121410", "#3c5a34", "#5e7e40", "#7c2a1c", "#2a5a7a", "#e3cf9c", "#5a1d14", "#c8913f"],
	# The Hypostyle Stacks' bay carpets (hall rework step 1, your note: a red
	# carpet pattern on the floor): madder field, gold and indigo, a deep border.
	"hall": ["#1a0a08", "#8e2418", "#7e1f15", "#c8913f", "#1d2a4a", "#e3cf9c", "#5a1610", "#c8913f"],
}

func rugs() -> void:
	var k: int = 0
	for design: String in RUG_PALETTES.keys().filter(func(d: String) -> bool: return d != "hall"):
		for size: String in RUG_SIZES:
			k += 1
			carpet("rug_%s_%s" % [design, size], design, RUG_SIZES[size][0], RUG_SIZES[size][1], 300 + k)
	# One square carpet per hall bay, 3.625 m (116 knots) across, laid wall to
	# wall between the columns.
	carpet("rug_hall_bay", "hall", 116, 116, 400)
	cushions()

## The floor seating's cloths (room rework, your note after step 1: Persian
## floor seating in place of the chairs). World-mapped tiles at 32 texels/m.
##   cushion_termeh  woven termeh: rows of boteh (paisley) on madder red
##   cushion_ikat    ikat: blurred indigo / ivory / red chevrons
##   cushion_kilim   kilim bands with small diamonds (poufs)
func cushions() -> void:
	var termeh: PackedColorArray = pal(["#1c0c0a", "#7a1e18", "#68181a", "#c8913f", "#2e5a44", "#e3cf9c"])
	var ikat: PackedColorArray = pal(["#141a2e", "#1d2a4a", "#e0cfa0", "#8a2a1e", "#c8913f"])
	var kilim: PackedColorArray = pal(["#1a0f0b", "#9c3a22", "#c8913f", "#2a6a6a", "#e3cf9c", "#5a1d14"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for which: String in ["termeh", "ikat", "kilim"]:
		rng.seed = hash(which)
		var w: int = 32
		var h: int = 32
		var rgb: PackedColorArray = PackedColorArray()
		var height: PackedFloat32Array = PackedFloat32Array()
		var jitter: PackedInt32Array = PackedInt32Array()     # ikat: each row's dye bleed
		for _y: int in range(h):
			jitter.append(rng.randi_range(-1, 1))
		for y: int in range(h):
			for x: int in range(w):
				var c: Color
				match which:
					"termeh":
						# Two boteh per tile, the second row offset by half: a
						# teardrop swept up from a round base, its tip curling over.
						var p := Vector2((x + (8 if (y / 16) % 2 == 1 else 0)) % 16, y % 16)
						var inside: float = 99.0     # distance past the teardrop's edge (< 0 inside)
						for k: int in range(11):
							var t: float = k / 10.0
							var centre := Vector2(7.0 + 4.5 * sin(t * PI * 0.75), 11.0 - 8.0 * t)
							var r: float = 4.0 * pow(1.0 - t, 0.9) + 0.5
							inside = minf(inside, p.distance_to(centre) - r)
						var core: float = p.distance_to(Vector2(7.0, 11.0))
						if inside < -0.2 and core < 1.5:
							c = termeh[4]
						elif inside < -0.2 and core < 2.6:
							c = termeh[5]
						elif inside < -1.0:
							c = termeh[3]
						elif inside < 0.0:
							c = termeh[5]
						elif inside < 0.9:
							c = termeh[0]
						else:
							c = termeh[1] if (x + y) % 2 == 0 else termeh[2]
					"ikat":
						var u: int = (x + jitter[y]) % 16
						var t: float = absf(float(y % 16) - 8.0) / 8.0     # chevron
						var edge: float = absf(u - (8.0 + (t - 0.5) * 8.0))
						if edge < 2.0:
							c = ikat[2]
						elif edge < 3.0:
							c = ikat[3] if (y + x) % 3 == 0 else ikat[2]
						elif edge < 4.5:
							c = ikat[3]
						elif u == 0:
							c = ikat[4]
						else:
							c = ikat[1] if (x + y) % 2 == 0 else ikat[0]
					_:
						var band: int = (y / 8) % 4
						var bx: float = absf(float(x % 8) - 3.5) + absf(float(y % 8) - 3.5)
						if y % 8 == 0:
							c = kilim[0]
						elif bx < 1.5:
							c = kilim[4]
						elif bx < 3.0:
							c = kilim[[2, 3, 2, 5][band]]
						else:
							c = kilim[[1, 5, 3, 1][band]]
				var shade: float = 0.9 + (x % 2) * 0.08 + rng.randf() * 0.06
				rgb.append(Color(c.r * shade, c.g * shade, c.b * shade))
				height.append(0.6 + (x % 2) * 0.2 + rng.randf() * 0.15)
		save("cushion_" + which, w, h, rgb, height, filled(w * h, .95), "world", 1.0)

func carpet(material_name: String, design: String, w: int, h: int, seed_value: int) -> void:
	var p: PackedColorArray = pal(RUG_PALETTES[design])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var bw: int = clampi(h / 8, 7, 16)        # border width, guards included
	var fw: int = w - 2 * bw
	var fh: int = h - 2 * bw
	# Abrash: the field's dye lot changes in bands across the long side.
	var lot: PackedInt32Array = PackedInt32Array()
	var band: int = 1
	for x: int in range(w):
		if x % 9 == 0 and rng.randf() < 0.45:
			band = 3 - band
		lot.append(band)
	var spots: Array[Vector2i] = []           # the gabbeh's few motifs, one per jittered cell
	var gx: int = maxi(1, fw / 34)
	var gy: int = maxi(1, fh / 30)
	for i: int in range(gx):
		for j: int in range(gy):
			if rng.randf() < 0.7:
				var cx: int = (fw * (2 * i + 1)) / (2 * gx) + rng.randi_range(-4, 4)
				var cy: int = (fh * (2 * j + 1)) / (2 * gy) + rng.randi_range(-3, 3)
				spots.append(Vector2i(cx, cy))
	var rgb: PackedColorArray = PackedColorArray()
	var height: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(h):
		for x: int in range(w):
			var b: int = mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			var slot: int
			if b < 1:
				slot = 0
			elif b < 2:
				slot = 4
			elif b < bw - 2:
				var along: int = x if mini(y, h - 1 - y) == b else y
				slot = _rug_border(design, along, b - 2, bw - 4)
			elif b < bw - 1:
				slot = 0
			elif b < bw:
				slot = 7
			else:
				slot = _rug_field(design, x - bw, y - bw, fw, fh, lot[x], spots)
			var shade: float = 0.9 + (x % 2) * 0.08 + rng.randf() * 0.06
			var c: Color = p[slot]
			rgb.append(Color(c.r * shade, c.g * shade, c.b * shade))
			height.append(0.6 + (x % 2) * 0.2 + rng.randf() * 0.2)
	save(material_name, w, h, rgb, height, filled(w * h, .97), "uv", 1.0)

## The main border band: a zigzag (kilim, gabbeh), rosettes (herati, garden)
## or a running vine (medallion), on the border ground.
func _rug_border(design: String, along: int, cross: int, width: int) -> int:
	var mid: float = (width - 1) * 0.5
	match design:
		"kilim", "gabbeh":
			var t: float = absf(float(along % 10) - 5.0) / 5.0
			return 5 if absf(cross - (width - 1) * t) < 1.0 else 6
		"medallion", "hall":
			var wave: float = mid + sin(along * TAU / 14.0) * mid * 0.7
			if absf(cross - wave) < 0.8:
				return 3
			return 7 if along % 7 == 3 and absf(cross - mid) > mid * 0.5 else 6
		_:
			var d: float = absf(float(along % 10) - 4.5) + absf(cross - mid)
			if d < 1.5:
				return 5
			if d >= 2.5 and d < 3.5:
				return 7
			return 6

func _rug_field(design: String, fx: int, fy: int, fw: int, fh: int, lot: int, spots: Array[Vector2i]) -> int:
	match design:
		"kilim":
			var cx: float = ((fx + 10) % 20) - 9.5
			var cy: float = ((fy + 10) % 20) - 9.5
			var d: float = absf(cx) + absf(cy)
			if d >= 8.0 and d < 9.5:
				return 3
			if d >= 5.0 and d < 6.5:
				return 4
			if d >= 2.5 and d < 3.5:
				return 5
			return 0 if d < 1.5 else lot
		"herati":
			var cx: float = (fx % 12) - 5.5
			var cy: float = (fy % 12) - 5.5
			var d: float = absf(cx) + absf(cy)
			if d >= 5.0 and d < 6.0:
				return 3
			if d < 1.6:
				return 5
			if absf(absf(cx) - absf(cy)) < 0.8 and d >= 2.8 and d < 4.2:
				return 4
			return lot
		"medallion", "hall":
			var dx: float = absf(fx - (fw - 1) * 0.5)
			var dy: float = absf(fy - (fh - 1) * 0.5)
			var r: float = dx / (fw * 0.24) + dy / (fh * 0.4)
			if r < 1.0:
				if r < 0.22:
					return 3
				if r < 0.3 or (r >= 0.72 and r < 0.8):
					return 0
				if r < 0.72:
					return 3 if (fx + fy) % 6 == 0 and (fx - fy) % 6 == 0 else 5
				return 4
			if dy < 1.5 and dx < fw * 0.24 + 5.0:
				return 5     # the pendants
			var qx: int = mini(fx, fw - 1 - fx)
			var qy: int = mini(fy, fh - 1 - fy)
			var q: float = qx / (fw * 0.16) + qy / (fh * 0.28)
			if q < 1.0:
				return 0 if q >= 0.88 else 4
			if fx % 9 == 4 and fy % 9 == 4:
				return 5
			if (absi(fx % 9 - 4) + absi(fy % 9 - 4)) == 1:
				return 3
			return lot
		"gabbeh":
			for s: Vector2i in spots:
				var d: int = absi(fx - s.x) + absi(fy - s.y)
				if d <= 2:
					return 3
				if d == 3 or d == 7:
					return 0
				if d >= 4 and d <= 6:
					return 5 if d == 5 or (fx + fy) % 2 == 0 else 7
			return lot
		_:
			# Beds fitted to the field: whole cells only, about square.
			var ny: int = maxi(1, int(round(fh / 30.0)))
			var nx: int = maxi(1, int(round(fw * ny / float(fh))))
			var cw: float = fw / float(nx)
			var ch: float = fh / float(ny)
			var cx: float = fmod(fx, cw)
			var cy: float = fmod(fy, ch)
			if cx < 2.0 or cy < 2.0:
				return 4 if (cx < 1.0 or cy < 1.0) else 0     # the water channels
			var d: float = absf(cx - cw * 0.5) / cw + absf(cy - ch * 0.42) / ch
			if d < 0.26:
				return 5 if (int(cx) * 3 + int(cy) * 5) % 13 == 0 else 2     # the tree's crown, a few blossoms
			if absf(cx - cw * 0.5) < 0.7 and cy > ch * 0.42:
				return 0     # trunk
			if (int(cx) * 7 + int(cy) * 3) % 23 == 0:
				return 3     # flowers
			return 1

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
	# ORM (polish C item 8): the Decal blends it by the albedo alpha, so the
	# patch reads glossy where it is wet. AO 1, metal 0; roughness per texel,
	# wettest (lowest) at the centre, the salt rim stays matte.
	var orm: Image = Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y * w + x
			var r: float = .9
			if field[i] >= .05:
				r = .7 if rim(field, w, h, x, y, .05) else .3 - field[i] * .25 + (fine[i] - .5) * .1
			orm.set_pixel(x, y, Color(1.0, clampf(r, 0.0, 1.0), 0.0))
	orm.save_png(ProjectSettings.globalize_path(DECAL_OUT + decal_name + "_orm.png"))

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
