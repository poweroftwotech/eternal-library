extends SceneTree
## Godot port of tools/compare_concept.py (no Python needed).
## godot --headless --script res://tests/compare_concept.gd -- <capture.png> [concept.png]
## Prints mean luminance (0-255) and warmth (R-B) per region; a region passes
## within +-15% of the concept.

const REGIONS: Dictionary = {
	"whole frame": Rect2(0, 0, 1, 1),
	"centre arch / garden (hero)": Rect2(.40, .07, .19, .40),
	"hearth + pot": Rect2(.37, .52, .19, .26),
	"left foreground": Rect2(0, 0, .22, .50),
	"right archive": Rect2(.81, .09, .19, .41),
	"rug / right floor": Rect2(.56, .70, .44, .30),
}
const SAMPLE_SIZE: Vector2i = Vector2i(480, 270)

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <capture.png> [concept.png]")
		quit(2)
		return
	var concept_path: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://design/Campfire in the Eternal Library.png")
	var concept: Image = load_sample(concept_path)
	var capture: Image = load_sample(args[0])
	if concept == null or capture == null:
		quit(2)
		return
	print("%-30s %8s %8s %8s   %s" % ["region", "concept", "capture", "ratio", "warmth c/r"])
	var fails: int = 0
	for region_name: String in REGIONS:
		var a: Vector2 = stats(concept, REGIONS[region_name])
		var b: Vector2 = stats(capture, REGIONS[region_name])
		var ratio: float = b.x / maxf(a.x, 1.0)
		var ok: bool = ratio >= .85 and ratio <= 1.15
		if not ok:
			fails += 1
		print("%-30s %8.0f %8.0f %8.2f %s %6.0f/%-6.0f" % [region_name, a.x, b.x, ratio, "ok  " if ok else "MISS", a.y, b.y])
	print("%d region(s) outside +-15%%." % fails)
	quit(1 if fails > 0 else 0)

func load_sample(path: String) -> Image:
	var image: Image = Image.load_from_file(path)
	if image == null:
		push_error("cannot load " + path)
		return null
	image.convert(Image.FORMAT_RGB8)
	image.resize(SAMPLE_SIZE.x, SAMPLE_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return image

## x = mean luminance (ITU-R 601, same as PIL "L"), y = mean red minus blue.
func stats(image: Image, box: Rect2) -> Vector2:
	var x0: int = int(box.position.x * SAMPLE_SIZE.x)
	var y0: int = int(box.position.y * SAMPLE_SIZE.y)
	var x1: int = int(box.end.x * SAMPLE_SIZE.x)
	var y1: int = int(box.end.y * SAMPLE_SIZE.y)
	var lum: float = 0.0
	var warm: float = 0.0
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var c: Color = image.get_pixel(x, y)
			lum += (c.r * .299 + c.g * .587 + c.b * .114) * 255.0
			warm += (c.r - c.b) * 255.0
	var count: float = float(maxi((x1 - x0) * (y1 - y0), 1))
	return Vector2(lum / count, warm / count)
