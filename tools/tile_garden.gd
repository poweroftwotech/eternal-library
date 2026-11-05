extends SceneTree
## Writes the Garden Court's own glazed tile (phase 13, your walk 3: "a
## different tile style for this room ... floral, leaves or nature"):
##   assets/textures/px/garden_tile.png (+ _normal): 2 x 2 glazed tiles a
##     metre, each a four-petalled flower on a deep blue ground, leaves out
##     to the corners, where quarter buds meet the next tile's; the flowers
##     alternate white and rose.
##   assets/textures/px/garden_band.png (+ _normal): a leafy vine scroll with
##     small flowers on a cream ground, twice a metre up so any band shows it.
## The materials are kit/materials/garden_tile.tres and garden_band.tres
## (tile.tres's roughness). Run: --headless --script res://tools/tile_garden.gd

const DIR: String = "res://assets/textures/px/"
const GROUT := Color("1d2430")
const GROUND := Color("1f3f7a")
const GROUND_DK := Color("173263")
const LEAF := Color("3f8a3c")
const LEAF_LT := Color("6db35a")
const STEM := Color("2d6630")
const WHITE := Color("efe6d2")
const ROSE := Color("d9738a")
const ROSE_DK := Color("a84a62")
const GOLD := Color("e8b74a")
const CREAM := Color("e9dcc0")
const CREAM_DK := Color("d6c6a4")


func _init() -> void:
	_save(_tile(), "garden_tile")
	_save(_band(), "garden_band")
	print("tile_garden: wrote garden_tile and garden_band (+ normals)")
	quit()


func _tile() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for ty: int in 2:
		for tx: int in 2:
			var petal: Color = WHITE if (tx + ty) % 2 == 0 else ROSE
			var petal_dk: Color = CREAM_DK if (tx + ty) % 2 == 0 else ROSE_DK
			for y: int in 16:
				for x: int in 16:
					var c: Color = GROUND if (x + y) % 5 != 0 else GROUND_DK
					var u: float = x - 7.5
					var v: float = y - 7.5
					var r: float = sqrt(u * u + v * v)
					var a: float = atan2(v, u)
					# Leaves on the diagonals, out from the flower to the corners.
					var d: float = absf(absf(u) - absf(v))
					if r > 3.5 and r < 7.0 and d < 2.2 - (r - 3.5) * 0.45:
						c = LEAF_LT if u * v > 0.0 else LEAF
					elif r >= 6.5 and r < 8.2 and d < 0.8:
						c = STEM
					# Quarter buds at the corners (whole where four tiles meet).
					var cu: float = minf(x, 15 - x)
					var cv: float = minf(y, 15 - y)
					if cu + cv < 2.5:
						c = petal_dk
					# The flower: four round petals and a gold heart.
					var petals: float = 3.6 + 2.2 * absf(cos(2.0 * a))
					if r < petals:
						c = petal if r > 1.6 else GOLD
						if r > petals - 0.9 and r > 1.6:
							c = petal_dk
					if x == 0 or y == 0:
						c = GROUT
					img.set_pixel(tx * 16 + x, ty * 16 + y, c)
	return img


func _band() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y: int in 32:
		for x: int in 32:
			img.set_pixel(x, y, CREAM if (x * 3 + y) % 7 != 0 else CREAM_DK)
	for block: int in 2:
		var y0: int = block * 16
		for x: int in 32:
			var s: float = 7.5 + 3.0 * sin(TAU * x / 32.0 + block * PI)
			img.set_pixel(x, y0 + int(round(s)), STEM)
			# Leaves off the stem, alternating up and down.
			if x % 8 == 2 or x % 8 == 6:
				var up: int = -1 if x % 8 == 2 else 1
				for k: int in range(1, 4):
					for w: int in range(-1, 2):
						var yy: int = y0 + int(round(s)) + up * k
						var xx: int = (x + w + k) % 32
						if absi(w) + k <= 3 and yy >= y0 and yy < y0 + 16:
							img.set_pixel(xx, yy, LEAF if k > 1 else LEAF_LT)
			# Small rose flowers at the crests.
			if x % 16 == 8:
				var cy: int = y0 + int(round(s))
				for dy: int in range(-2, 3):
					for dx: int in range(-2, 3):
						if absi(dx) + absi(dy) <= 2:
							img.set_pixel((x + dx + 32) % 32, clampi(cy + dy, y0, y0 + 15), GOLD if dx == 0 and dy == 0 else ROSE)
		for x: int in 32:
			img.set_pixel(x, y0, GROUND)
			img.set_pixel(x, y0 + 15, GROUND)
	return img


## A flat normal map with the grout (the darkest pixels) pressed in.
func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(DIR + name + ".png"))
	var n := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y: int in 32:
		for x: int in 32:
			var h: float = img.get_pixel(x, y).get_luminance()
			var hx: float = img.get_pixel((x + 1) % 32, y).get_luminance() - img.get_pixel((x + 31) % 32, y).get_luminance()
			var hy: float = img.get_pixel(x, (y + 1) % 32).get_luminance() - img.get_pixel(x, (y + 31) % 32).get_luminance()
			var nv := Vector3(-hx * 0.8, -hy * 0.8, 1.0).normalized()
			if h < 0.15:
				nv = Vector3(0, 0, 1)
			n.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	n.save_png(ProjectSettings.globalize_path(DIR + name + "_normal.png"))
