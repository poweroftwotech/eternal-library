extends SceneTree
## Mean and max per-channel difference between two PNGs (0-255), plus the
## share of pixels that differ by more than 8. Used to prove a refactor left a
## render unchanged; compare against the run-to-run noise of two captures.
##   godot --headless --path . --script res://tests/image_diff.gd -- <a.png> <b.png>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- <a.png> <b.png>")
		quit(2)
		return
	var a: Image = Image.load_from_file(args[0])
	var b: Image = Image.load_from_file(args[1])
	if a == null or b == null or a.get_size() != b.get_size():
		print("image_diff: cannot compare (missing or different sizes)")
		quit(2)
		return
	var total: float = 0.0
	var worst: float = 0.0
	var big: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0 * 255.0
			total += d
			worst = maxf(worst, d)
			if d > 8.0:
				big += 1
	var n: int = a.get_width() * a.get_height()
	print("image_diff: mean %.3f  max %.1f  >8: %.3f%%" % [total / n, worst, 100.0 * big / n])
	quit()
