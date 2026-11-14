extends SceneTree
## Draws a spectrogram PNG of a 16-bit mono WAV (a check on tools/make_sounds.gd
## by eye, since no one can listen headless): time across, 0-10 kHz up.
##   godot --headless --path . --script res://tools/spectrogram.gd -- <in.wav> <out.png>

const SR: int = 44100
const WIN: int = 1024
const HOP: int = 256
const TOP_HZ: float = 10000.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(args[0])
	var start: int = 44
	var n: int = (bytes.size() - start) / 2
	var x := PackedFloat32Array()
	x.resize(n)
	for i: int in n:
		x[i] = bytes.decode_s16(start + i * 2) / 32768.0
	var bins: int = int(TOP_HZ / SR * WIN)
	var cols: int = maxi(1, (n - WIN) / HOP)
	var img := Image.create(cols, bins, false, Image.FORMAT_RGB8)
	for c: int in cols:
		for b: int in bins:
			var re: float = 0.0
			var im: float = 0.0
			var w: float = TAU * b / WIN
			for k: int in range(0, WIN, 2):     # (every other sample: enough for a picture)
				var s: float = x[c * HOP + k] * (0.5 - 0.5 * cos(TAU * k / WIN))
				re += s * cos(w * k)
				im -= s * sin(w * k)
			var db: float = clampf((linear_to_db(sqrt(re * re + im * im) + 1e-6) + 20.0) / 60.0, 0.0, 1.0)
			img.set_pixel(c, bins - 1 - b, Color(db, db * db, db * 0.4 + 0.1 * (1.0 - db)))
	img.resize(cols * 2, bins * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(args[1])
	print("spectrogram %s: %d x %d" % [args[1], cols, bins])
	quit()
