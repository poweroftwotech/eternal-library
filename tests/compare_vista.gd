extends SceneTree
## Overlook vista vs the box art (ART_DIRECTION.md section 8).
## godot --headless --script res://tests/compare_vista.gd -- <capture.png> [box_art.png]
## The box art is portrait with a title and border, so every region has its
## own rect in each image. A region may average several rects (both flanks).
## Luminance passes within +-25%; the structural checks below must hold too.

const BOX_ART: String = "res://design/box concept art/image-gen-2(2).png"
const SAMPLE_SIZE: Vector2i = Vector2i(480, 480)
const VOID_LUMINANCE: float = 12.0
## [box-art rects], [capture rects], in normalised image coordinates.
const REGIONS: Dictionary = {
	"vault (rock above)": [[Rect2(.32, .25, .14, .08)], [Rect2(.25, 0, .50, .14)]],
	"focal glow (far hall)": [[Rect2(.58, .29, .12, .13)], [Rect2(.43, .24, .14, .20)]],
	"far depth band": [[Rect2(.47, .45, .28, .27)], [Rect2(.35, .42, .30, .25)]],
	"near flanks": [[Rect2(.76, .40, .20, .45)], [Rect2(0, .15, .18, .55), Rect2(.82, .15, .18, .55)]],
	"mist floor": [[Rect2(.58, .84, .22, .12)], [Rect2(.30, .74, .40, .12)]],
}
const ILLUSTRATION: Rect2 = Rect2(.04, .24, .92, .73)

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <capture.png> [box_art.png]")
		quit(2)
		return
	var concept_path: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path(BOX_ART)
	var concept: Image = load_sample(concept_path)
	var capture: Image = load_sample(args[0])
	if concept == null or capture == null:
		quit(2)
		return
	var fails: int = 0
	var c: Dictionary = {}
	var r: Dictionary = {}
	print("%-24s %8s %8s %8s   %s" % ["region", "box art", "capture", "ratio", "warmth b/c"])
	for region_name: String in REGIONS:
		c[region_name] = stats(concept, REGIONS[region_name][0])
		r[region_name] = stats(capture, REGIONS[region_name][1])
		var ratio: float = r[region_name].x / maxf(c[region_name].x, 1.0)
		var ok: bool = ratio >= .75 and ratio <= 1.25
		if not ok:
			fails += 1
		print("%-24s %8.0f %8.0f %8.2f %s %6.0f/%-6.0f" % [region_name, c[region_name].x, r[region_name].x, ratio, "ok  " if ok else "MISS", c[region_name].y, r[region_name].y])
	var void_c: float = void_fraction(concept, ILLUSTRATION)
	var void_r: float = void_fraction(capture, Rect2(0, 0, 1, 1))
	fails += check("empty void %.1f%% (box art %.1f%%, allow +5)" % [void_r * 100, void_c * 100], void_r <= void_c + .05)
	fails += check("focal glow brighter than near flanks (%.0f vs %.0f)" % [r["focal glow (far hall)"].x, r["near flanks"].x], r["focal glow (far hall)"].x >= r["near flanks"].x)
	var split_c: float = c["near flanks"].y - c["far depth band"].y
	var split_r: float = r["near flanks"].y - r["far depth band"].y
	fails += check("warm near / cool far split %.0f (box art %.0f, need half)" % [split_r, split_c], split_r >= split_c * .5)
	print("%d check(s) failed." % fails)
	quit(1 if fails > 0 else 0)

func check(label: String, ok: bool) -> int:
	print("%s %s" % ["ok  " if ok else "MISS", label])
	return 0 if ok else 1

func load_sample(path: String) -> Image:
	var image: Image = Image.load_from_file(path)
	if image == null:
		push_error("cannot load " + path)
		return null
	image.convert(Image.FORMAT_RGB8)
	image.resize(SAMPLE_SIZE.x, SAMPLE_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return image

## x = mean luminance (ITU-R 601), y = mean red minus blue, over all rects.
func stats(image: Image, boxes: Array) -> Vector2:
	var lum: float = 0.0
	var warm: float = 0.0
	var count: int = 0
	for box: Rect2 in boxes:
		for y: int in range(int(box.position.y * SAMPLE_SIZE.y), int(box.end.y * SAMPLE_SIZE.y)):
			for x: int in range(int(box.position.x * SAMPLE_SIZE.x), int(box.end.x * SAMPLE_SIZE.x)):
				var c: Color = image.get_pixel(x, y)
				lum += (c.r * .299 + c.g * .587 + c.b * .114) * 255.0
				warm += (c.r - c.b) * 255.0
				count += 1
	return Vector2(lum, warm) / float(maxi(count, 1))

func void_fraction(image: Image, box: Rect2) -> float:
	var dark: int = 0
	var count: int = 0
	for y: int in range(int(box.position.y * SAMPLE_SIZE.y), int(box.end.y * SAMPLE_SIZE.y)):
		for x: int in range(int(box.position.x * SAMPLE_SIZE.x), int(box.end.x * SAMPLE_SIZE.x)):
			var c: Color = image.get_pixel(x, y)
			if (c.r * .299 + c.g * .587 + c.b * .114) * 255.0 < VOID_LUMINANCE:
				dark += 1
			count += 1
	return float(dark) / float(maxi(count, 1))
