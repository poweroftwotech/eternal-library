extends SceneTree
## Writes assets/textures/px/tile_hall.png: the kit's glazed tile recoloured
## for the Hypostyle Stacks' domes (hall rework step 1, your walk: "a different
## tile texture for the dome ... that plays well with the red theme"). Teal,
## green and blue glaze become madder red, the orange becomes gold; the dark
## lines and the cream keep their colour. Each pixel keeps its value, so the
## pattern and its shading stay.
## Run: --headless --script res://tools/tile_hall.gd

const SRC: String = "res://assets/textures/px/tile.png"
const DST: String = "res://assets/textures/px/tile_hall.png"
const RED_HUE: float = 0.005       # madder
const GOLD_HUE: float = 0.11


func _init() -> void:
	var img := Image.load_from_file(SRC)
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.s < 0.2 or c.v < 0.12:
				continue      # the dark lines and the cream
			if c.h > 0.3 and c.h < 0.75:      # teal, green, blue -> madder red
				img.set_pixel(x, y, Color.from_hsv(RED_HUE, clampf(c.s * 1.1, 0.0, 0.85), c.v * 0.82, c.a))
				n += 1
			elif c.h >= 0.02 and c.h <= 0.17:     # orange -> gold
				img.set_pixel(x, y, Color.from_hsv(GOLD_HUE, c.s * 0.85, c.v, c.a))
				n += 1
	img.save_png(ProjectSettings.globalize_path(DST))
	print("tile_hall: %d pixels recoloured -> %s" % [n, DST])
	quit()
