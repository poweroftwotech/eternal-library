extends SceneTree
## Writes assets/textures/px/hall_frieze.png: the Hypostyle Stacks' frieze
## (hall rework step 4; your note: a geometric band after your example, not
## script). Red rules, a gold running scroll on black, and between them a cream
## field of black lozenges and orange diamonds in black frames, red points
## between. 256 x 18 px for a 4 m x 0.28 m band (16 motifs, 25 cm each); it
## tiles left to right, so bands run on from module to module. Colours bright
## (your note): it hangs 6 m up, lit only by the lamps below.
## Run: --headless --script res://tools/hall_frieze.gd

const DST: String = "res://assets/textures/px/hall_frieze.png"
const W: int = 256
const H: int = 18
const P: int = 16            # the motif's width

const RED := Color("#d02c1c")
const BLACK := Color("#24130d")
const GOLD := Color("#ffc848")
const GOLD_D := Color("#c8902c")
const CREAM := Color("#fff8e8")
const ORANGE := Color("#ffa030")


func _init() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for x: int in W:
		img.set_pixel(x, 0, RED)
		img.set_pixel(x, H - 1, RED)
		for y: int in range(1, 4):
			img.set_pixel(x, y, _scroll(x, y - 1))
			img.set_pixel(x, H - 1 - y, _scroll(x + 4, y - 1))
		img.set_pixel(x, 4, GOLD_D)
		img.set_pixel(x, H - 5, GOLD_D)
		for y: int in 8:
			img.set_pixel(x, 5 + y, _field(x % P, y))
	img.save_png(ProjectSettings.globalize_path(DST))
	print("hall_frieze -> %s" % DST)
	quit()


## The running scroll, 3 rows on black: a gold wave that curls every 8 px.
func _scroll(x: int, row: int) -> Color:
	var k: int = posmod(x, 8)
	var on: bool = false
	match row:
		0: on = k in [1, 2, 3]
		1: on = k in [0, 4, 6]
		2: on = k in [5, 6, 7]
	return GOLD if on else BLACK


## The field, 8 rows: a cream frame with an orange diamond in a black outline
## at the motif's middle, a black lozenge where motifs meet, red points above
## and below the lozenges' waists.
func _field(x: int, y: int) -> Color:
	var dx: float = absf(x + 0.5 - P / 2.0)
	var dy: float = absf(y + 0.5 - 4.0)
	var d: float = dx + dy
	if d <= 2.0:
		return ORANGE
	if d <= 3.0:
		return BLACK
	var edge: float = P / 2.0 - dx         # distance to where motifs meet
	if edge / 3.2 + dy / 4.4 <= 1.0:
		return BLACK
	if edge < 3.5 and dy > 1.5:
		return RED
	return CREAM
