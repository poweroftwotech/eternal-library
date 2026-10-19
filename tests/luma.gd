extends SceneTree
## Mean luminance (0-255) of a capture: whole frame and a 3 x 3 grid, plus the
## share of near-black pixels. ART_DIRECTION.md rule 4: never a black area.
##   godot --headless --path . --script res://tests/luma.gd -- <capture.png>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var img: Image = Image.load_from_file(args[0]) if not args.is_empty() else null
	if img == null:
		print("usage: -- <capture.png>")
		quit(2)
		return
	img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	var cells: Array[float] = []
	cells.resize(9)
	cells.fill(0.0)
	var total: float = 0.0
	var black: int = 0
	for y: int in 270:
		for x: int in 480:
			var c: Color = img.get_pixel(x, y)
			var l: float = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			total += l
			if l < 12.0:
				black += 1
			cells[(y * 3 / 270) * 3 + x * 3 / 480] += l
	var n: float = 480.0 * 270.0
	print("luma: whole %.1f  near-black %.1f%%" % [total / n, 100.0 * black / n])
	for row: int in 3:
		print("luma: %6.1f %6.1f %6.1f" % [cells[row * 3] / (n / 9), cells[row * 3 + 1] / (n / 9), cells[row * 3 + 2] / (n / 9)])
	quit()
